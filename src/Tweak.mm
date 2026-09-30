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

static intptr_t  gSlide = 0;
static NSString *gMainBinaryName = nil;
static NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *gAdrpAddMap = nil;

static uint64_t gPatchOffsets[] = {
    0x5425b0,
    0x86eb80,
    0x9e3100,
    0x9a4cbc,
    0x9cb098,
    0x75bb1c,
    0xb5f028,
    0xb3ec50,
    0xb9ee6c,
    0x75cce0,
    0x9a8f3c,
    0xba17b8,
};

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        if (base.length) return base;
    }
    return [TitanoxHook findExecInBundle:nil];
}

static BOOL OXBinaryHasTitanoxSegment(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || data.length < 32) return NO;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    uint32_t magic = 0;
    memcpy(&magic, bytes, 4);
    if (magic != 0xfeedfacf) return NO;
    uint32_t ncmds = 0, sizeofcmds = 0;
    memcpy(&ncmds,     bytes + 16, 4);
    memcpy(&sizeofcmds, bytes + 20, 4);
    if (sizeofcmds > data.length - 32) return NO;
    const uint8_t *p = bytes + 32;
    for (uint32_t i = 0; i < ncmds; i++) {
        if ((uintptr_t)(p - bytes) + 8 > data.length) break;
        uint32_t cmd = 0, cmdsize = 0;
        memcpy(&cmd,     p,     4);
        memcpy(&cmdsize, p + 4, 4);
        if (cmdsize < 8) break;
        if (cmd == 0x19) {
            if ((uintptr_t)(p - bytes) + 24 <= data.length) {
                char segname[17];
                memcpy(segname, p + 8, 16);
                segname[16] = 0;
                if (strcmp(segname, "__TITANOX_HOOK") == 0) return YES;
            }
        }
        p += cmdsize;
    }
    return NO;
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

static void OXFindCtorsForKnown(void) {
    NSArray *known = @[
        @{@"name": @"Character",          @"vt": @(0x00FF45C0)},
        @{@"name": @"GameButton",         @"vt": @(0x00F9B0F8)},
        @{@"name": @"HomePage",           @"vt": @(0x00FE4008)},
        @{@"name": @"LogicDataTables",    @"vt": @(0x00FF2478)},
        @{@"name": @"LogicProjectileData",@"vt": @(0x00FF3AA0)},
        @{@"name": @"MessageManager",     @"vt": @(0x00FD57E8)},
        @{@"name": @"MovieClip",          @"vt": @(0x01006150)},
        @{@"name": @"NativeFont",         @"vt": @(0x01005858)},
        @{@"name": @"Stage",              @"vt": @(0x010091B0)},
    ];

    THLog(@"=== CTOR SCAN ===");
    for (NSDictionary *vt in known) {
        uint64_t vaddr = FILE_LO + [vt[@"vt"] unsignedLongLongValue];
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
            THLog(@"[ctor] %@ ctor=0x%llx", vt[@"name"], func);
        }
    }
}

static void OXPreparePatches(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];

    if (exePath && OXBinaryHasTitanoxSegment(exePath)) {
        THLog(@"[patch] .app binary is ALREADY PATCHED, skip");
        THLog(@"[patch] to repatch, restore original first");
        return;
    }

    NSString *patchedPath = [NSHomeDirectory() stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"Documents/titanox-hook/%@", gMainBinaryName]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:patchedPath]) {
        THLog(@"[patch] output already exists: %@", patchedPath);
        THLog(@"[patch] sign with zsign and replace in .app");
        return;
    }

    TitanoxHook *hooker = [[TitanoxHook alloc] initWithMachOName:gMainBinaryName];
    if (!hooker) {
        THLog(@"[patch] hooker init FAILED");
        return;
    }
    THLog(@"=== PATCHING BINARY ===");
    size_t count = sizeof(gPatchOffsets) / sizeof(gPatchOffsets[0]);
    for (size_t i = 0; i < count; i++) {
        uint64_t off = gPatchOffsets[i];
        uint64_t fullAddr = FILE_LO + off;
        NSString *res = [hooker applyPatchAtVaddr:fullAddr patchBytes:@""];
        THLog(@"[patch] 0x%llx -> %@", off, res ?: @"(nil)");
    }
    THLog(@"=== PATCH DONE ===");
    THLog(@"[patch] output: %@", patchedPath);
    THLog(@"[patch] sign manually, then replace in .app");
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        gSlide = OXFindSlide(gMainBinaryName);
        THLog(@"=== TITANOX PATCHER v19 ===");
        THLog(@"main=%@ slide=0x%lx", gMainBinaryName, (long)gSlide);

        OXBuildAdrpAddMap();
        OXFindCtorsForKnown();
        OXPreparePatches();

        THLog(@"=== DONE ===");
    });
}