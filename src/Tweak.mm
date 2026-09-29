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

static bool hook_getBool(void* self) {
    TLOG(@"getBool called self=0x%llx -> true", (unsigned long long)(uintptr_t)self);
    return true;
}

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        TLOG(@"=== Titanox init ===");
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        TLOG(@"base=0x%llx", (unsigned long long)base);
        if (!base) return;

        uint64_t getBoolAddr = base + RVA_GETBOOL;
        [TitanoxHook addBreakpointAtAddress:(void*)getBoolAddr withHook:(void*)hook_getBool];
        TLOG(@"breakpoint getBool @ 0x%llx", (unsigned long long)getBoolAddr);

        uint64_t isDevAddr = base + RVA_ISDEV;
        uint64_t isDevBuildAddr = base + RVA_ISDEVBUILD;
        uint8_t trueByte = 1;
        [TitanoxHook writeMemoryAt:isDevAddr data:&trueByte size:1];
        [TitanoxHook writeMemoryAt:isDevBuildAddr data:&trueByte size:1];
        TLOG(@"patched isDev @ 0x%llx = 1", (unsigned long long)isDevAddr);
        TLOG(@"patched isDevBuild @ 0x%llx = 1", (unsigned long long)isDevBuildAddr);
    }
}