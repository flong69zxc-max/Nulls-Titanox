#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <libgen.h>
#import "libtitanox.h"

#define IMAGE_BASE   0x100000000ULL
#define TEXT_START   0x100004000ULL
#define TEXT_END     0x100D8AF60ULL
#define DATA_START   0x100F74000ULL
#define DATA_END     0x101170000ULL

static intptr_t   gSlide = 0;
static NSString  *gMainBinaryName = nil;

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        THLog(@"[detect] executablePath=%@ -> base=%@", exePath, base);
        if (base.length) return base;
    }
    NSString *found = [TitanoxHook findExecInBundle:nil];
    if (found.length) {
        THLog(@"[detect] findExecInBundle=%@", found);
        return found;
    }
    return nil;
}

static intptr_t OXFindSlideForName(NSString *name) {
    if (!name.length) return 0;
    const char *target = name.UTF8String;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        const char *base = basename((char *)imgName);
        if (strcmp(base, target) == 0) {
            intptr_t s = _dyld_get_image_vmaddr_slide(i);
            THLog(@"[slide] image[%u] %s -> 0x%lx", i, imgName, (long)s);
            return s;
        }
    }
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (imgName && strstr(imgName, target)) {
            intptr_t s = _dyld_get_image_vmaddr_slide(i);
            THLog(@"[slide] image[%u] %s -> 0x%lx (substr)", i, imgName, (long)s);
            return s;
        }
    }
    THLog(@"[slide] NOT FOUND for name=%@", name);
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        THLog(@"  [%u] %s", i, _dyld_get_image_name(i));
    }
    return 0;
}

static uint64_t OXReadPtr(uint64_t fileVaddr) {
    uint64_t real = fileVaddr + gSlide;
    uint64_t v = 0;
    BOOL ok = [TitanoxHook readMemoryAt:real buffer:(void *)&v size:8];
    return ok ? v : 0;
}

static NSString *OXReadCString(uint64_t fileVaddr, int maxLen) {
    if (!fileVaddr) return nil;
    uint64_t real = fileVaddr + gSlide;
    char buf[256];
    memset(buf, 0, sizeof(buf));
    BOOL ok = [TitanoxHook readMemoryAt:real buffer:(void *)buf
                                   size:(maxLen < 255 ? maxLen : 255)];
    if (!ok || buf[0] == 0) return nil;
    return [NSString stringWithUTF8String:buf];
}

static uint64_t OXDecodeFixup(uint64_t raw) {
    uint64_t t43   = raw & 0x7FFFFFFFFFFULL;
    uint64_t high8 = (raw >> 43) & 0xFFULL;
    if (high8) return (high8 << 56) | t43;
    return t43;
}

static NSArray<NSString *> *OXSplitMangled(NSString *raw) {
    if (!raw || raw.length < 2) return nil;
    if ([raw hasPrefix:@"N"] && [raw hasSuffix:@"E"]) {
        NSString *inner = [raw substringWithRange:NSMakeRange(1, raw.length - 2)];
        NSMutableArray *parts = [NSMutableArray array];
        NSUInteger i = 0;
        while (i < inner.length) {
            NSUInteger j = i;
            while (j < inner.length && isdigit([inner characterAtIndex:j])) j++;
            if (j == i) break;
            int len = [[inner substringWithRange:NSMakeRange(i, j - i)] intValue];
            if (len <= 0 || j + len > inner.length) break;
            [parts addObject:[inner substringWithRange:NSMakeRange(j, len)]];
            i = j + len;
        }
        if (parts.count) return parts;
    }
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger i = 0;
    while (i < raw.length && isdigit([raw characterAtIndex:i])) {
        NSUInteger j = i;
        while (j < raw.length && isdigit([raw characterAtIndex:j])) j++;
        if (j == i) break;
        int len = [[raw substringWithRange:NSMakeRange(i, j - i)] intValue];
        if (len <= 0 || j + len > raw.length) break;
        [parts addObject:[raw substringWithRange:NSMakeRange(j, len)]];
        i = j + len;
    }
    if (parts.count) return parts;
    return nil;
}

static NSDictionary *OXGetTypeInfo(uint64_t vtVaddr) {
    uint64_t raw = OXReadPtr(vtVaddr - 8);
    if (!raw) return nil;
    uint64_t tiVaddr = OXDecodeFixup(raw);
    if (!tiVaddr || tiVaddr < IMAGE_BASE) return nil;
    uint64_t nameRaw = OXReadPtr(tiVaddr + 8);
    if (!nameRaw) return nil;
    uint64_t nameVaddr = OXDecodeFixup(nameRaw);
    if (!nameVaddr || nameVaddr < IMAGE_BASE) return nil;
    NSString *rawStr = OXReadCString(nameVaddr, 160);
    if (!rawStr || rawStr.length == 0) return nil;
    NSArray *parts = OXSplitMangled(rawStr);
    if (!parts || parts.count == 0) return nil;
    return @{@"class": parts.lastObject, @"raw": rawStr};
}

static void OXDumpVtable(uint64_t vtFileVaddr, NSString *label) {
    NSDictionary *ti = OXGetTypeInfo(vtFileVaddr);
    NSString *cls = ti ? ti[@"class"] : @"unknown";
    THLog(@"=== VT %@ @ 0x%llx class=%@ ===", label, vtFileVaddr, cls);
    for (int i = 0; i < 256; i++) {
        uint64_t slotVaddr = vtFileVaddr + i * 8;
        uint64_t raw = OXReadPtr(slotVaddr);
        uint64_t fn = OXDecodeFixup(raw);
        if (fn < TEXT_START || fn >= TEXT_END) break;
        THLog(@"  [%3d] 0x%llx", i, fn);
    }
}

static void OXScanDataForVtables(void) {
    THLog(@"=== SCAN DATA FOR VTABLE RUNS ===");
    uint64_t totalSlots = (DATA_END - DATA_START) / 8;
    int runLen = 0;
    uint64_t runStart = 0;
    uint64_t prevSlot = 0;
    int hits = 0;

    for (uint64_t i = 0; i < totalSlots; i++) {
        uint64_t slot = DATA_START + i * 8;
        uint64_t raw = OXReadPtr(slot);
        uint64_t fn = OXDecodeFixup(raw);
        BOOL valid = (fn >= TEXT_START && fn < TEXT_END && (fn & 3) == 0);
        if (valid) {
            if (runLen == 0) { runStart = slot; runLen = 1; }
            else if (slot == prevSlot + 8) { runLen++; }
            else {
                if (runLen >= 4) {
                    NSDictionary *ti = OXGetTypeInfo(runStart);
                    THLog(@"VT 0x%llx slots=%d class=%@",
                          runStart, runLen, ti ? ti[@"class"] : @"?");
                    hits++;
                }
                runStart = slot; runLen = 1;
            }
            prevSlot = slot;
        } else {
            if (runLen >= 4) {
                NSDictionary *ti = OXGetTypeInfo(runStart);
                THLog(@"VT 0x%llx slots=%d class=%@",
                      runStart, runLen, ti ? ti[@"class"] : @"?");
                hits++;
            }
            runLen = 0;
        }
    }
    if (runLen >= 4) {
        NSDictionary *ti = OXGetTypeInfo(runStart);
        THLog(@"VT 0x%llx slots=%d class=%@",
              runStart, runLen, ti ? ti[@"class"] : @"?");
        hits++;
    }
    THLog(@"total vtable-like runs: %d", hits);
}

static void brk_MessageManager_receiveMessage(void *self, void *msg) {
    THLog(@"[BRK] MessageManager::receiveMessage self=%p msg=%p", self, msg);
}

static void brk_GameButton_ctor(void *self) {
    THLog(@"[BRK] GameButton::ctor self=%p", self);
    uint64_t vt = 0;
    [TitanoxHook readMemoryAt:(uint64_t)self buffer:&vt size:8];
    THLog(@"      self->vtable runtime=0x%llx file=0x%llx", vt, vt - gSlide);
}

static void brk_NativeFont_formatString(void *self, void *str) {
    THLog(@"[BRK] NativeFont::formatString self=%p str=%p", self, str);
}

static void brk_HomePage_ctor(void *self) {
    THLog(@"[BRK] HomePage::ctor self=%p", self);
}

static void brk_Stage_setViewport(void *self, double x, double y, double w, double h) {
    THLog(@"[BRK] Stage::setViewport self=%p x=%f y=%f w=%f h=%f", self, x, y, w, h);
}

static void brk_MovieClip_setText(void *self, void *str) {
    THLog(@"[BRK] MovieClip::setText self=%p str=%p", self, str);
}

#define INSTALL_BRK(fileOff, fn) do { \
    void *real = (void *)(IMAGE_BASE + (fileOff) + gSlide); \
    if ([TitanoxHook addBreakpointAtAddress:real withHook:(void *)&fn]) { \
        THLog(@"brk OK: %s file=0x%llx runtime=%p", #fn, (uint64_t)(fileOff), real); \
    } else { \
        THLog(@"brk FAIL: %s file=0x%llx runtime=%p", #fn, (uint64_t)(fileOff), real); \
    } \
} while (0)

static void OXInstallBrkHooks(void) {
    THLog(@"=== BRK HOOKS (one-shot, max 6) ===");
    INSTALL_BRK(0x0075CCE0, brk_MessageManager_receiveMessage);
    INSTALL_BRK(0x005425B0, brk_GameButton_ctor);
    INSTALL_BRK(0x00B3FDE8, brk_NativeFont_formatString);
    INSTALL_BRK(0x0086EB80, brk_HomePage_ctor);
    INSTALL_BRK(0x00BA17B8, brk_Stage_setViewport);
    INSTALL_BRK(0x00B5F068, brk_MovieClip_setText);
}

static void OXRunTrace(void) {
    THLog(@"=== TITANOX TRACE v19 ===");
    THLog(@"main binary = %@", gMainBinaryName);
    THLog(@"slide        = 0x%lx", (long)gSlide);

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
        uint64_t vaddr = IMAGE_BASE + [vt[@"addr"] unsignedLongLongValue];
        OXDumpVtable(vaddr, vt[@"name"]);
    }

    OXScanDataForVtables();
    OXInstallBrkHooks();

    THLog(@"=== TRACE READY ===");
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        THLog(@"main binary detected: %@", gMainBinaryName);
        gSlide = OXFindSlideForName(gMainBinaryName);
        THLog(@"slide=0x%lx", (long)gSlide);
        OXRunTrace();
    });
}