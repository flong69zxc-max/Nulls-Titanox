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

static NSString *OXReadCString(uint64_t fileVaddr, int maxLen) {
    if (!fileVaddr) return nil;
    char buf[256];
    memset(buf, 0, sizeof(buf));
    size_t n = (maxLen < 255) ? maxLen : 255;
    if (!OXReadBytes(fileVaddr, buf, n)) return nil;
    if (buf[0] == 0) return nil;
    return [NSString stringWithUTF8String:buf];
}

/* vtable slot: содержит готовый runtime VA */
static uint64_t OXSlotRuntime(uint64_t vtFileVaddr, int idx) {
    return OXReadQword(vtFileVaddr + idx * 8);
}

static BOOL OXIsRuntimeFunc(uint64_t rt) {
    if (!rt) return NO;
    if ((rt & 3) != 0) return NO;
    uint64_t lo = gSlide + TEXT_FILE_LO;
    uint64_t hi = gSlide + TEXT_FILE_HI;
    return rt >= lo && rt < hi;
}

static uint64_t OXFileFromRuntime(uint64_t rt) {
    return rt - gSlide;
}

/* typeinfo: пробуем разные offset'ы назад от vt */
static NSDictionary *OXGetTypeInfo(uint64_t vtFileVaddr) {
    for (int off = 8; off <= 64; off += 8) {
        uint64_t tiRt = OXReadQword(vtFileVaddr - off);
        if (!tiRt) continue;
        if (tiRt < gSlide + FILE_LO) continue;
        uint64_t tiFile = OXFileFromRuntime(tiRt);
        if (tiFile < FILE_LO || tiFile >= FILE_HI) continue;

        for (int noff = 8; noff <= 24; noff += 8) {
            uint64_t nameRt = OXReadQword(tiFile + noff);
            if (!nameRt) continue;
            uint64_t nameFile = OXFileFromRuntime(nameRt);
            if (nameFile < FILE_LO || nameFile >= FILE_HI) continue;
            NSString *s = OXReadCString(nameFile, 160);
            if (!s || s.length == 0) continue;
            if (s.length < 2) continue;
            if (s.length > 128) continue;

            // _ZTS / _ZTI demangle
            if ([s hasPrefix:@"_ZTS"] || [s hasPrefix:@"_ZTI"]) {
                s = [s substringFromIndex:4];
            }

            NSArray *parts = nil;
            if ([s hasPrefix:@"N"] && [s hasSuffix:@"E"]) {
                NSString *inner = [s substringWithRange:NSMakeRange(1, s.length - 2)];
                NSMutableArray *arr = [NSMutableArray array];
                NSUInteger i = 0;
                while (i < inner.length) {
                    NSUInteger j = i;
                    while (j < inner.length && isdigit([inner characterAtIndex:j])) j++;
                    if (j == i) break;
                    int len = [[inner substringWithRange:NSMakeRange(i, j - i)] intValue];
                    if (len <= 0 || j + len > inner.length) break;
                    [arr addObject:[inner substringWithRange:NSMakeRange(j, len)]];
                    i = j + len;
                }
                if (arr.count) parts = arr;
            }
            if (!parts) {
                NSMutableArray *arr = [NSMutableArray array];
                NSUInteger i = 0;
                while (i < s.length && isdigit([s characterAtIndex:i])) {
                    NSUInteger j = i;
                    while (j < s.length && isdigit([s characterAtIndex:j])) j++;
                    if (j == i) break;
                    int len = [[s substringWithRange:NSMakeRange(i, j - i)] intValue];
                    if (len <= 0 || j + len > s.length) break;
                    [arr addObject:[s substringWithRange:NSMakeRange(j, len)]];
                    i = j + len;
                }
                if (arr.count) parts = arr;
            }
            if (!parts || parts.count == 0) continue;

            return @{@"class": parts.lastObject, @"raw": s,
                     @"ti_off": @(off), @"name_off": @(noff)};
        }
    }
    return nil;
}

static int OXDumpVtable(uint64_t vtFileVaddr, NSString *label) {
    NSDictionary *ti = OXGetTypeInfo(vtFileVaddr);
    NSString *cls = ti ? ti[@"class"] : @"unknown";
    uint64_t rt = vtFileVaddr + gSlide;
    THLog(@"=== VT %@ file=0x%llx rt=0x%llx class=%@ ===",
          label, vtFileVaddr, rt, cls);

    int slots = 0;
    for (int i = 0; i < 512; i++) {
        uint64_t rtFn = OXSlotRuntime(vtFileVaddr, i);
        if (!OXIsRuntimeFunc(rtFn)) break;
        uint64_t fileFn = OXFileFromRuntime(rtFn);
        THLog(@"  [%3d] rt=0x%llx file=0x%llx", i, rtFn, fileFn);
        slots++;
    }
    THLog(@"  total slots: %d", slots);
    return slots;
}

static void OXScanDataForVtables(void) {
    THLog(@"=== SCAN DATA FOR VTABLE RUNS ===");
    uint64_t totalSlots = (FILE_HI - DATA_FILE_LO) / 8;
    int runLen = 0, hits = 0;
    uint64_t runStart = 0, prevSlot = 0;

    for (uint64_t i = 0; i < totalSlots; i++) {
        uint64_t slotFile = DATA_FILE_LO + i * 8;
        uint64_t rt = OXReadQword(slotFile);
        BOOL valid = OXIsRuntimeFunc(rt);
        if (valid) {
            if (runLen == 0) { runStart = slotFile; runLen = 1; }
            else if (slotFile == prevSlot + 8) { runLen++; }
            else {
                if (runLen >= 4) {
                    NSDictionary *ti = OXGetTypeInfo(runStart);
                    THLog(@"VT file=0x%llx rt=0x%llx slots=%d class=%@",
                          runStart, runStart + gSlide, runLen,
                          ti ? ti[@"class"] : @"?");
                    hits++;
                }
                runStart = slotFile; runLen = 1;
            }
            prevSlot = slotFile;
        } else {
            if (runLen >= 4) {
                NSDictionary *ti = OXGetTypeInfo(runStart);
                THLog(@"VT file=0x%llx rt=0x%llx slots=%d class=%@",
                      runStart, runStart + gSlide, runLen,
                      ti ? ti[@"class"] : @"?");
                hits++;
            }
            runLen = 0;
        }
    }
    if (runLen >= 4) {
        NSDictionary *ti = OXGetTypeInfo(runStart);
        THLog(@"VT file=0x%llx rt=0x%llx slots=%d class=%@",
              runStart, runStart + gSlide, runLen,
              ti ? ti[@"class"] : @"?");
        hits++;
    }
    THLog(@"total vtable-like runs: %d", hits);
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        gSlide = OXFindSlide(gMainBinaryName);
        THLog(@"=== TITANOX TRACE v19 ===");
        THLog(@"main = %@ slide=0x%lx rtBase=0x%llx",
              gMainBinaryName, (long)gSlide, gSlide + FILE_LO);

        NSArray *vtList = @[
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

        for (NSDictionary *vt in vtList) {
            uint64_t vaddr = FILE_LO + [vt[@"addr"] unsignedLongLongValue];
            OXDumpVtable(vaddr, vt[@"name"]);
        }

        OXScanDataForVtables();
        THLog(@"=== TRACE READY ===");
    });
}