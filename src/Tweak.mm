#import <Foundation/Foundation.h>
#import "libtitanox.h"
#include "offsets.h"

static void TLOG(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSString *path = [NSString stringWithFormat:@"%@/Documents/titanox-debug.log", NSHomeDirectory()];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    FILE *f = fopen([path UTF8String], "a");
    if (f) { fputs([line UTF8String], f); fclose(f); }
}

static void dumpBytes(uint64_t addr) {
    uint8_t buf[32];
    if ([TitanoxHook readMemoryAt:addr buffer:buf size:sizeof(buf)]) {
        NSMutableString *hex = [NSMutableString string];
        for (int i = 0; i < 32; i++) [hex appendFormat:@"%02x ", buf[i]];
        TLOG(@"bytes @ 0x%llx: %@", (unsigned long long)addr, hex);
    } else {
        TLOG(@"read fail @ 0x%llx", (unsigned long long)addr);
    }
}

static bool hook_getBool(void* self) {
    TLOG(@"getBool called self=0x%llx", (unsigned long long)(uintptr_t)self);
    return true;
}

static bool hook_isDev(void* self) {
    TLOG(@"isDev called self=0x%llx", (unsigned long long)(uintptr_t)self);
    return true;
}

static bool hook_isDevBuild(void* self) {
    TLOG(@"isDevBuild called self=0x%llx", (unsigned long long)(uintptr_t)self);
    return true;
}

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        TLOG(@"=== Titanox init ===");
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        TLOG(@"base=0x%llx", (unsigned long long)base);
        if (!base) return;
        uint64_t a1 = base + RVA_GETBOOL;
        uint64_t a2 = base + RVA_ISDEV;
        uint64_t a3 = base + RVA_ISDEVBUILD;
        dumpBytes(a1);
        dumpBytes(a2);
        dumpBytes(a3);
        [TitanoxHook addBreakpointAtAddress:(void*)a1 withHook:(void*)hook_getBool];
        [TitanoxHook addBreakpointAtAddress:(void*)a2 withHook:(void*)hook_isDev];
        [TitanoxHook addBreakpointAtAddress:(void*)a3 withHook:(void*)hook_isDevBuild];
        TLOG(@"breakpoints installed");
    }
}