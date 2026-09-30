#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import "libtitanox.h"

#define LOG_PATH [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"TITANOX_TRACE.txt"]

static NSMutableString *gLog = nil;
static NSLock *gLock = nil;
static TitanoxHook *gHooker = nil;
static intptr_t gSlide = 0;

static void OXLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [gLock lock];
    [gLog appendFormat:@"%@\n", s];
    [gLock unlock];
}

static void OXFlush(void) {
    [gLock lock];
    [gLog writeToFile:LOG_PATH atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [gLock unlock];
}

static uint64_t OXReal(uint64_t vaddr) {
    return vaddr + gSlide;
}

static uint64_t OXReadPtr(uint64_t vaddr) {
    uint64_t v = 0;
    [TitanoxHook readMemoryAt:OXReal(vaddr) buffer:(void *)&v size:8];
    return v;
}

static NSString *OXReadCString(uint64_t vaddr, int maxLen) {
    if (!vaddr) return nil;
    char buf[256];
    memset(buf, 0, sizeof(buf));
    [TitanoxHook readMemoryAt:OXReal(vaddr) buffer:(void *)buf size:maxLen < 255 ? maxLen : 255];
    if (buf[0] == 0) return nil;
    return [NSString stringWithUTF8String:buf];
}

static uint64_t OXDecodeFixup(uint64_t raw) {
    uint64_t t43 = raw & 0x7FFFFFFFFFFULL;
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
    if (!tiVaddr || tiVaddr < 0x100000000ULL) return nil;
    uint64_t nameRaw = OXReadPtr(tiVaddr + 8);
    if (!nameRaw) return nil;
    uint64_t nameVaddr = OXDecodeFixup(nameRaw);
    if (!nameVaddr || nameVaddr < 0x100000000ULL) return nil;
    NSString *rawStr = OXReadCString(nameVaddr, 160);
    if (!rawStr || rawStr.length == 0) return nil;
    NSArray *parts = OXSplitMangled(rawStr);
    if (!parts || parts.count == 0) return nil;
    return @{@"class": parts.lastObject, @"raw": rawStr};
}

static void OXDumpVtable(uint64_t vtVaddr, NSString *label) {
    NSDictionary *ti = OXGetTypeInfo(vtVaddr);
    NSString *cls = ti ? ti[@"class"] : @"unknown";
    OXLog(@"=== VT %@ @ 0x%llx class=%@ ===", label, vtVaddr, cls);
    for (int i = 0; i < 256; i++) {
        uint64_t slotVaddr = vtVaddr + i * 8;
        uint64_t raw = OXReadPtr(slotVaddr);
        uint64_t fn = OXDecodeFixup(raw);
        if (fn < 0x100000000ULL || fn >= 0x100E00000ULL) break;
        OXLog(@"  [%3d] 0x%llx", i, fn);
    }
}

static void OXScanVtableRuns(void) {
    OXLog(@"=== SCAN ALL VTABLE-LIKE RUNS ===");
    uint64_t dataStart = 0x100F74000ULL;
    uint64_t dataEnd   = 0x101170000ULL;
    uint64_t totalSlots = (dataEnd - dataStart) / 8;

    int runLen = 0;
    uint64_t runStart = 0;
    uint64_t prevSlot = 0;

    for (uint64_t i = 0; i < totalSlots; i++) {
        uint64_t slot = dataStart + i * 8;
        uint64_t raw = OXReadPtr(slot);
        uint64_t fn = OXDecodeFixup(raw);
        BOOL valid = (fn >= 0x100000000ULL && fn < 0x100E00000ULL && (fn & 3) == 0);
        if (valid) {
            if (runLen == 0) {
                runStart = slot;
                runLen = 1;
            } else if (slot == prevSlot + 8) {
                runLen++;
            } else {
                if (runLen >= 4) {
                    NSDictionary *ti = OXGetTypeInfo(runStart);
                    OXLog(@"VT 0x%llx slots=%d class=%@",
                          runStart, runLen, ti ? ti[@"class"] : @"?");
                }
                runStart = slot;
                runLen = 1;
            }
            prevSlot = slot;
        } else {
            if (runLen >= 4) {
                NSDictionary *ti = OXGetTypeInfo(runStart);
                OXLog(@"VT 0x%llx slots=%d class=%@",
                      runStart, runLen, ti ? ti[@"class"] : @"?");
            }
            runLen = 0;
        }
    }
    if (runLen >= 4) {
        NSDictionary *ti = OXGetTypeInfo(runStart);
        OXLog(@"VT 0x%llx slots=%d class=%@",
              runStart, runLen, ti ? ti[@"class"] : @"?");
    }
}

/* ============================================================
 *  brk-hooks (до 6 штук). Каждый хук — плоская C-функция.
 *  ВАЖНО: адрес передаётся РЕАЛЬНЫЙ (base+slide+offset),
 *  т.к. addBreakpointAtAddress работает с runtime-адресом.
 * ============================================================ */

static void hook_MessageManager_receiveMessage(void *self, void *msg) {
    OXLog(@"[BRK] MessageManager::receiveMessage self=%p msg=%p", self, msg);
    OXFlush();
}

static void hook_GameButton_ctor(void *self) {
    OXLog(@"[BRK] GameButton::ctor self=%p", self);
    uint64_t vt = OXReadPtr((uint64_t)self);
    OXLog(@"      GameButton vtable runtime=0x%llx  offset=0x%llx",
          vt, vt - gSlide);
    OXFlush();
}

static void hook_NativeFont_formatString(void *self, void *str) {
    OXLog(@"[BRK] NativeFont::formatString self=%p str=%p", self, str);
    OXFlush();
}

static void hook_HomePage_ctor(void *self) {
    OXLog(@"[BRK] HomePage::ctor self=%p", self);
    OXFlush();
}

static void hook_Stage_setViewport(void *self, double x, double y, double w, double h) {
    OXLog(@"[BRK] Stage::setViewport self=%p x=%f y=%f w=%f h=%f", self, x, y, w, h);
    OXFlush();
}

static void hook_MovieClip_setText(void *self, void *str) {
    OXLog(@"[BRK] MovieClip::setText self=%p str=%p", self, str);
    OXFlush();
}

#define INSTALL_BRK_HOOK(offset, funcName) do { \
    void *target = (void *)(gSlide + (offset)); \
    if ([TitanoxHook addBreakpointAtAddress:target withHook:(void *)&funcName]) { \
        OXLog(@"brk-hook installed: %s @ runtime=0x%llx (off=0x%llx)", \
              #funcName, (uint64_t)target, (uint64_t)(offset)); \
    } else { \
        OXLog(@"brk-hook FAILED: %s @ runtime=0x%llx", \
              #funcName, (uint64_t)target); \
    } \
} while (0)

static void OXInstallBrkHooks(void) {
    OXLog(@"=== INSTALL BRK HOOKS ===");
    INSTALL_BRK_HOOK(0x0075CCE0, hook_MessageManager_receiveMessage);
    INSTALL_BRK_HOOK(0x005425B0, hook_GameButton_ctor);
    INSTALL_BRK_HOOK(0x00B3FDE8, hook_NativeFont_formatString);
    INSTALL_BRK_HOOK(0x0086EB80, hook_HomePage_ctor);
    INSTALL_BRK_HOOK(0x00BA17B8, hook_Stage_setViewport);
    INSTALL_BRK_HOOK(0x00B5F068, hook_MovieClip_setText);
    OXFlush();
}

static void OXRunTrace(void) {
    OXLog(@"=== TITANOX TRACE v19 ===");
    OXLog(@"slide=0x%llx", (uint64_t)gSlide);

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
        uint64_t vaddr = [vt[@"addr"] unsignedLongLongValue];
        OXDumpVtable(vaddr, vt[@"name"]);
    }

    OXScanVtableRuns();
    OXInstallBrkHooks();

    OXLog(@"=== TRACE READY ===");
    OXFlush();
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    gLog = [NSMutableString new];
    gLock = [NSLock new];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gSlide = [TitanoxHook getVmAddrSlideOfLibrary:"Brawl Stars"];
        gHooker = [[TitanoxHook alloc] initWithMachOName:@"Brawl Stars"];
        OXLog(@"lib=Brawl Stars slide=0x%llx hooker=%@", (uint64_t)gSlide, gHooker ? @"ok" : @"nil");
        OXRunTrace();
    });
}