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

/* ============================================================
 *  HOOK-обёртки для известных функций (плоские C-функции,
 *  т.к. inline-hook прыгает напрямую на указатель)
 * ============================================================ */

static void (*orig_MessageManager_receiveMessage)(void *self, void *msg) = NULL;
static void my_MessageManager_receiveMessage(void *self, void *msg) {
    OXLog(@"CALL MessageManager::receiveMessage self=%p msg=%p", self, msg);
    if (orig_MessageManager_receiveMessage) orig_MessageManager_receiveMessage(self, msg);
}

static void (*orig_NativeFont_formatString)(void *self, void *str) = NULL;
static void my_NativeFont_formatString(void *self, void *str) {
    OXLog(@"CALL NativeFont::formatString self=%p", self);
    if (orig_NativeFont_formatString) orig_NativeFont_formatString(self, str);
}

static void (*orig_GameButton_ctor)(void *self) = NULL;
static void my_GameButton_ctor(void *self) {
    OXLog(@"CALL GameButton::ctor self=%p", self);
    if (orig_GameButton_ctor) orig_GameButton_ctor(self);
    uint64_t vt = OXReadPtr((uint64_t)self);
    OXLog(@"  GameButton vtable=0x%llx", vt - gSlide);
}

static void (*orig_HomePage_ctor)(void *self) = NULL;
static void my_HomePage_ctor(void *self) {
    OXLog(@"CALL HomePage::ctor self=%p", self);
    if (orig_HomePage_ctor) orig_HomePage_ctor(self);
}

static void (*orig_Stage_setViewport)(void *self, double x, double y, double w, double h) = NULL;
static void my_Stage_setViewport(void *self, double x, double y, double w, double h) {
    OXLog(@"CALL Stage::setViewport self=%p x=%f y=%f w=%f h=%f", self, x, y, w, h);
    if (orig_Stage_setViewport) orig_Stage_setViewport(self, x, y, w, h);
}

static void (*orig_LogicDataTables_initDataTable)(void *self, void *a) = NULL;
static void my_LogicDataTables_initDataTable(void *self, void *a) {
    OXLog(@"CALL LogicDataTables::initDataTable self=%p a=%p", self, a);
    if (orig_LogicDataTables_initDataTable) orig_LogicDataTables_initDataTable(self, a);
}

static void (*orig_MovieClip_setText)(void *self, void *str) = NULL;
static void my_MovieClip_setText(void *self, void *str) {
    OXLog(@"CALL MovieClip::setText self=%p", self);
    if (orig_MovieClip_setText) orig_MovieClip_setText(self, str);
}

static void (*orig_GameButton_setText)(void *self, void *str) = NULL;
static void my_GameButton_setText(void *self, void *str) {
    OXLog(@"CALL GameButton::setText self=%p", self);
    if (orig_GameButton_setText) orig_GameButton_setText(self, str);
}

static void (*orig_LogicProjectileData_getIntValueFromColumn)(void *self, int col) = NULL;
static void my_LogicProjectileData_getIntValueFromColumn(void *self, int col) {
    OXLog(@"CALL LogicProjectileData::getIntValueFromColumn self=%p col=%d", self, col);
    if (orig_LogicProjectileData_getIntValueFromColumn) orig_LogicProjectileData_getIntValueFromColumn(self, col);
}

static void (*orig_Character_updateHealthBar)(void *self) = NULL;
static void my_Character_updateHealthBar(void *self) {
    OXLog(@"CALL Character::updateHealthBar self=%p", self);
    if (orig_Character_updateHealthBar) orig_Character_updateHealthBar(self);
}

#define INSTALL_HOOK(name, vaddr) do { \
    void *orig = [gHooker hookFunctionAtVaddr:(vaddr) withReplacement:(void *)&my_##name]; \
    if (orig) { orig_##name = (void *)orig; OXLog(@"hooked %s @ 0x%llx", #name, (uint64_t)(vaddr)); } \
    else { OXLog(@"FAILED to hook %s @ 0x%llx", #name, (uint64_t)(vaddr)); } \
} while (0)

static void OXInstallKnownHooks(void) {
    INSTALL_HOOK(MessageManager_receiveMessage,          0x0075CCE0);
    INSTALL_HOOK(NativeFont_formatString,                0x00B3FDE8);
    INSTALL_HOOK(GameButton_ctor,                        0x005425B0);
    INSTALL_HOOK(HomePage_ctor,                          0x0086EB80);
    INSTALL_HOOK(Stage_setViewport,                      0x00BA17B8);
    INSTALL_HOOK(LogicDataTables_initDataTable,          0x009A8F3C);
    INSTALL_HOOK(MovieClip_setText,                      0x00B5F068);
    INSTALL_HOOK(GameButton_setText,                     0x005430A4);
    INSTALL_HOOK(LogicProjectileData_getIntValueFromColumn, 0x009CB098);
    INSTALL_HOOK(Character_updateHealthBar,              0x009E3100);
}

static void OXRunTrace(void) {
    OXLog(@"=== TITANOX TRACE v19 ===");
    OXLog(@"slide=0x%llx", gSlide);

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

    OXInstallKnownHooks();

    OXLog(@"=== TRACE READY ===");
    OXFlush();
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    gLog = [NSMutableString new];
    gLock = [NSLock new];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gSlide = [TitanoxHook getVmAddrSlideOfLibrary:"Brawl Stars"];
        gHooker = [[TitanoxHook alloc] initWithMachOName:@"Brawl Stars"];
        OXLog(@"lib=Brawl Stars slide=0x%llx hooker=%@", gSlide, gHooker);
        OXRunTrace();
    });
}