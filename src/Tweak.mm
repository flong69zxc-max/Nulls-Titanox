#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import "libtitanox.h"

#define LOG_PATH [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"TITANOX_TRACE.txt"]

static NSMutableString *gLog = nil;
static NSLock *gLock = nil;

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

static uint64_t gSlide = 0;
static NSString *gLibName = @"Brawl Stars";

static uint64_t OXReal(uint64_t vaddr) {
    return vaddr + gSlide;
}

static uint64_t OXReadPtr(uint64_t vaddr) {
    uint64_t v = 0;
    [TitanoxHook readMemoryAt:OXReal(vaddr) buffer:(uint8_t *)&v size:8];
    return v;
}

static NSString *OXReadCString(uint64_t vaddr, int maxLen) {
    if (!vaddr) return nil;
    char buf[256];
    memset(buf, 0, sizeof(buf));
    [TitanoxHook readMemoryAt:OXReal(vaddr) buffer:(uint8_t *)buf size:maxLen < 255 ? maxLen : 255];
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

static void OXDumpVtable(uint64_t vtVaddr, const char *label) {
    NSDictionary *ti = OXGetTypeInfo(vtVaddr);
    NSString *cls = ti ? ti[@"class"] : @"unknown";
    OXLog(@"=== VT %s @ 0x%llx class=%@ ===", label, vtVaddr, cls);
    for (int i = 0; i < 256; i++) {
        uint64_t slotVaddr = vtVaddr + i * 8;
        uint64_t raw = OXReadPtr(slotVaddr);
        uint64_t fn = OXDecodeFixup(raw);
        if (fn < 0x100000000ULL || fn >= 0x100E00000ULL) break;
        OXLog(@"  [%3d] 0x%llx", i, fn);
    }
}

static NSMutableDictionary *gCallCounts = nil;

static void OXInstallVtableTrace(uint64_t vtVaddr, NSString *clsName) {
    for (int i = 0; i < 256; i++) {
        uint64_t slotVaddr = vtVaddr + i * 8;
        uint64_t raw = OXReadPtr(slotVaddr);
        uint64_t fnVaddr = OXDecodeFixup(raw);
        if (fnVaddr < 0x100000000ULL || fnVaddr >= 0x100E00000ULL) break;

        __block int slotIdx = i;
        __block NSString *cls = clsName;
        __block uint64_t fnAddr = fnVaddr;

        [TitanoxHook hookFunctionAtVaddr:fnVaddr withReplacement:^(void) {
            NSString *key = [NSString stringWithFormat:@"%@::slot[%d]", cls, slotIdx];
            @synchronized (gCallCounts) {
                NSNumber *c = gCallCounts[key] ?: @0;
                gCallCounts[key] = @(c.intValue + 1);
            }
            OXLog(@"CALL %@ fn=0x%llx", key, fnAddr);
        }];
    }
}

static void OXInstallKnownHooks(void) {
    NSDictionary *known = @{
        @"MessageManager::receiveMessage": @(0x0075CCE0),
        @"NativeFont::formatString":       @(0x00B3FDE8),
        @"GameButton::ctor":               @(0x005425B0),
        @"GameButton::setText":            @(0x005430A4),
        @"HomePage::ctor":                 @(0x0086EB80),
        @"MovieClip::setText":             @(0x00B5F068),
        @"Stage::setViewport":             @(0x00BA17B8),
        @"LogicDataTables::initDataTable": @(0x009A8F3C),
        @"LogicProjectileData::getIntValueFromColumn": @(0x009CB098),
        @"Character::updateHealthBar":     @(0x009E3100),
    };

    for (NSString *name in known) {
        uint64_t vaddr = [known[name] unsignedLongLongValue];
        [TitanoxHook hookFunctionAtVaddr:vaddr withReplacement:^(void) {
            OXLog(@"HOOK %@ vaddr=0x%llx", name, vaddr);
        }];
        OXLog(@"installed hook %@ @ 0x%llx", name, vaddr);
    }
}

static void OXRunTrace(void) {
    OXLog(@"=== TITANOX TRACE v19 ===");

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
        OXDumpVtable(vaddr, [vt[@"name"] UTF8String]);
    }

    for (NSDictionary *vt in vtList) {
        uint64_t vaddr = [vt[@"addr"] unsignedLongLongValue];
        OXInstallVtableTrace(vaddr, vt[@"name"]);
    }

    OXInstallKnownHooks();

    OXLog(@"=== TRACE READY ===");
    OXFlush();
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    gLog = [NSMutableString new];
    gLock = [NSLock new];
    gCallCounts = [NSMutableDictionary new];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gSlide = [TitanoxHook getVmAddrSlideOfLibrary:gLibName];
        OXLog(@"lib=%@ slide=0x%llx", gLibName, gSlide);
        OXRunTrace();
    });
}