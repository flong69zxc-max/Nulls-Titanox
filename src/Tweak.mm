#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <libgen.h>
#import "libtitanox.h"

#define FILE_LO       0x100000000ULL
#define FILE_HI       0x101170000ULL
#define TEXT_FILE_LO  0x100004000ULL
#define TEXT_FILE_HI  0x100D8AF60ULL
#define DATA_FILE_LO  0x100F74000ULL

static intptr_t  gSlide = 0;
static NSString *gMainBinaryName = nil;
static NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *gAdrpAddMap = nil;

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        if (base.length) return base;
    }
    return [TitanoxHook findExecInBundle:nil];
}

static intptr_t OXFindSlide(NSString *name) {
    const char *target = name.UTF8String;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        const char *base = basename((char *)imgName);
        if (strcmp(base, target) != 0) continue;
        const struct mach_header *hdr = _dyld_get_image_header(i);
        uint32_t magic = 0;
        if (hdr) memcpy(&magic, hdr, 4);
        if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

static BOOL OXReadBytes(uint64_t fileVaddr, void *buf, size_t size) {
    if (fileVaddr < FILE_LO) return NO;
    if (fileVaddr + size < fileVaddr) return NO;
    if (fileVaddr + size > FILE_HI) return NO;
    uint64_t runtime = fileVaddr + gSlide;
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)runtime,
                                         (vm_size_t)size,
                                         (vm_address_t)buf,
                                         &outSize);
    if (kr == KERN_SUCCESS && outSize == size) return YES;
    memcpy(buf, (void *)runtime, size);
    return YES;
}

static uint64_t OXReadQword(uint64_t fileVaddr) {
    uint64_t v = 0;
    OXReadBytes(fileVaddr, &v, 8);
    return v;
}

static BOOL OXIsRuntimeFunc(uint64_t rt) {
    if (!rt || (rt & 3) != 0) return NO;
    uint64_t lo = gSlide + TEXT_FILE_LO;
    uint64_t hi = gSlide + TEXT_FILE_HI;
    return rt >= lo && rt < hi;
}

static void OXBuildAdrpAddMap(void) {
    gAdrpAddMap = [NSMutableDictionary dictionary];
    uint64_t size = TEXT_FILE_HI - TEXT_FILE_LO;
    const uint64_t CHUNK = 0x100000;
    uint8_t *buf = (uint8_t *)malloc(CHUNK);
    if (!buf) return;
    uint64_t prevPc = 0;
    uint32_t prevRd = 0;
    uint64_t prevPage = 0;

    for (uint64_t off = 0; off < size; off += CHUNK) {
        uint64_t n = (size - off < CHUNK) ? (size - off) : CHUNK;
        if (!OXReadBytes(TEXT_FILE_LO + off, buf, n)) break;
        for (uint64_t i = 0; i + 4 <= n; i += 4) {
            uint64_t pcFile = TEXT_FILE_LO + off + i;
            uint32_t w = *(uint32_t *)(buf + i);
            if ((w & 0x9F000000) == 0x90000000) {
                prevPc = pcFile;
                prevRd = w & 0x1F;
                uint32_t immlo = (w >> 29) & 3;
                uint32_t immhi = (w >> 5) & 0x7FFFF;
                int64_t imm = ((int64_t)immhi << 2) | immlo;
                if (imm & (1 << 20)) imm -= (1 << 21);
                prevPage = (pcFile & ~0xFFFULL) + (imm << 12);
                continue;
            }
            if (prevPc != 0 && (w & 0xFF800000) == 0x91000000) {
                uint32_t rd = w & 0x1F;
                uint32_t rn = (w >> 5) & 0x1F;
                uint32_t imm12 = (w >> 10) & 0xFFF;
                uint32_t sh = (w >> 22) & 1;
                if (sh) imm12 <<= 12;
                if (rd == prevRd && rn == prevRd) {
                    uint64_t target = prevPage + imm12;
                    if (target >= FILE_LO && target < FILE_HI) {
                        NSNumber *key = @(target);
                        NSMutableArray *arr = gAdrpAddMap[key];
                        if (!arr) { arr = [NSMutableArray array]; gAdrpAddMap[key] = arr; }
                        if (arr.count < 16) [arr addObject:@(prevPc)];
                    }
                }
            }
            prevPc = 0;
        }
    }
    free(buf);
    THLog(@"[adrp] map entries=%d", (int)gAdrpAddMap.count);
}

static uint64_t OXFindPrologueBackward(uint64_t pcFile) {
    uint64_t start = (pcFile > 0x10000) ? pcFile - 0x10000 : TEXT_FILE_LO;
    if (start < TEXT_FILE_LO) start = TEXT_FILE_LO;
    uint32_t w;
    for (uint64_t p = pcFile; p >= start; p -= 4) {
        if (!OXReadBytes(p, &w, 4)) break;
        if ((w & 0xFFC07FFF) == 0xA9807BFD) return p;
        if (w == 0xD503237F || w == 0xD503233F) return p;
        if (p < start + 4) break;
    }
    return pcFile;
}

static NSString *OXStringInFunc(uint64_t funcFile, uint64_t maxScan) {
    uint64_t end = funcFile + maxScan;
    if (end > TEXT_FILE_HI) end = TEXT_FILE_HI;
    for (uint64_t pc = funcFile; pc + 8 <= end; pc += 4) {
        uint32_t w;
        if (!OXReadBytes(pc, &w, 4)) continue;
        if ((w & 0x9F000000) != 0x90000000) continue;
        uint32_t rd = w & 0x1F;
        uint32_t immlo = (w >> 29) & 3;
        uint32_t immhi = (w >> 5) & 0x7FFFF;
        int64_t imm = ((int64_t)immhi << 2) | immlo;
        if (imm & (1 << 20)) imm -= (1 << 21);
        uint64_t page = (pc & ~0xFFFULL) + (imm << 12);
        for (int j = 1; j <= 4 && pc + j * 4 + 4 <= end; j++) {
            uint32_t w2;
            if (!OXReadBytes(pc + j * 4, &w2, 4)) break;
            if ((w2 & 0xFF800000) == 0x91000000) {
                uint32_t rd2 = w2 & 0x1F;
                uint32_t rn2 = (w2 >> 5) & 0x1F;
                uint32_t imm12 = (w2 >> 10) & 0xFFF;
                uint32_t sh = (w2 >> 22) & 1;
                if (sh) imm12 <<= 12;
                if (rd2 == rd && rn2 == rd) {
                    uint64_t target = page + imm12;
                    if (target >= FILE_LO && target < FILE_HI) {
                        char str[96];
                        memset(str, 0, sizeof(str));
                        if (!OXReadBytes(target, str, 95)) break;
                        if (str[0] >= 0x20 && str[0] < 0x7F) {
                            BOOL printable = YES;
                            size_t len = strnlen(str, 95);
                            if (len < 5) break;
                            for (size_t k = 0; k < len; k++) {
                                if (str[k] < 0x20 || str[k] > 0x7E) { printable = NO; break; }
                            }
                            if (printable) return [NSString stringWithUTF8String:str];
                        }
                    }
                    break;
                }
            }
        }
    }
    return nil;
}

static void OXFindCtorsForKnown(void) {
    NSArray *known = @[
        @{@"name": @"Character",          @"addr": @(0x00FF45C0)},
        @{@"name": @"GameButton",         @"addr": @(0x00F9B0F8)},
        @{@"name": @"HomePage",           @"addr": @(0x00FE4008)},
        @{@"name": @"LogicDataTables",    @"addr": @(0x00FF2478)},
        @{@"name": @"LogicProjectileData",@"addr": @(0x00FF3AA0)},
        @{@"name": @"MessageManager",     @"addr": @(0x00FD57E8)},
        @{@"name": @"MovieClip",          @"addr": @(0x01006150)},
        @{@"name": @"NativeFont",         @"addr": @(0x01005858)},
        @{@"name": @"Stage",              @"addr": @(0x010091B0)},
    ];

    THLog(@"=== CTOR SCAN (9 known vtables) ===");
    for (NSDictionary *vt in known) {
        uint64_t vaddr = FILE_LO + [vt[@"addr"] unsignedLongLongValue];
        NSArray *refs = gAdrpAddMap[@(vaddr)];
        if (!refs || refs.count == 0) {
            THLog(@"[ctor] %@ no refs", vt[@"name"]);
            continue;
        }
        NSMutableSet *uniqCtors = [NSMutableSet set];
        for (NSNumber *pcNum in refs) {
            uint64_t func = OXFindPrologueBackward([pcNum unsignedLongLongValue]);
            [uniqCtors addObject:@(func)];
        }
        for (NSNumber *funcNum in uniqCtors) {
            uint64_t func = [funcNum unsignedLongLongValue];
            NSString *str = OXStringInFunc(func, 0x800);
            THLog(@"[ctor] %@ ctor=0x%llx str=%@",
                  vt[@"name"], func, str ?: @"(none)");
        }
    }
}

static void OXScanVtableRunsAndCtors(void) {
    THLog(@"=== VTABLE RUNS + CTORS ===");
    uint64_t totalSlots = (FILE_HI - DATA_FILE_LO) / 8;
    int runLen = 0;
    uint64_t runStart = 0;
    uint64_t prevSlot = 0;
    int totalRuns = 0;
    int resolvedCtors = 0;

    for (uint64_t i = 0; i <= totalSlots; i++) {
        uint64_t slotFile = DATA_FILE_LO + i * 8;
        uint64_t rt = (i < totalSlots) ? OXReadQword(slotFile) : 0;
        BOOL valid = (i < totalSlots) && OXIsRuntimeFunc(rt);
        if (valid) {
            if (runLen == 0) { runStart = slotFile; runLen = 1; }
            else if (slotFile == prevSlot + 8) { runLen++; }
            else {
                if (runLen >= 4) {
                    totalRuns++;
                    NSArray *refs = gAdrpAddMap[@(runStart)];
                    if (refs && refs.count > 0) {
                        NSMutableSet *uniqCtors = [NSMutableSet set];
                        for (NSNumber *pcNum in refs) {
                            uint64_t func = OXFindPrologueBackward([pcNum unsignedLongLongValue]);
                            [uniqCtors addObject:@(func)];
                        }
                        for (NSNumber *funcNum in uniqCtors) {
                            uint64_t func = [funcNum unsignedLongLongValue];
                            NSString *str = OXStringInFunc(func, 0x600);
                            if (str) {
                                resolvedCtors++;
                                THLog(@"VT 0x%llx slots=%d ctor=0x%llx str=%@",
                                      runStart, runLen, func, str);
                                break;
                            }
                        }
                    }
                }
                runStart = slotFile; runLen = 1;
            }
            prevSlot = slotFile;
        } else {
            if (runLen >= 4) {
                totalRuns++;
                NSArray *refs = gAdrpAddMap[@(runStart)];
                if (refs && refs.count > 0) {
                    NSMutableSet *uniqCtors = [NSMutableSet set];
                    for (NSNumber *pcNum in refs) {
                        uint64_t func = OXFindPrologueBackward([pcNum unsignedLongLongValue]);
                        [uniqCtors addObject:@(func)];
                    }
                    for (NSNumber *funcNum in uniqCtors) {
                        uint64_t func = [funcNum unsignedLongLongValue];
                        NSString *str = OXStringInFunc(func, 0x600);
                        if (str) {
                            resolvedCtors++;
                            THLog(@"VT 0x%llx slots=%d ctor=0x%llx str=%@",
                                  runStart, runLen, func, str);
                            break;
                        }
                    }
                }
            }
            runLen = 0;
        }
    }
    THLog(@"[summary] total runs=%d with named ctor=%d", totalRuns, resolvedCtors);
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        gSlide = OXFindSlide(gMainBinaryName);
        THLog(@"=== TITANOX TRACE v19 ===");
        THLog(@"main=%@ slide=0x%lx", gMainBinaryName, (long)gSlide);

        OXBuildAdrpAddMap();
        OXFindCtorsForKnown();
        OXScanVtableRunsAndCtors();

        THLog(@"=== DONE ===");
    });
}