#import <Foundation/Foundation.h>
#import "libtitanox.h"
#include "offsets.h"

#define TLOG(fmt, ...) do { \
    NSString *_s = [NSString stringWithFormat:fmt, ##__VA_ARGS__]; \
    [TitanoxHook log:@"%@", _s]; \
    NSLog(@"[Titanox] %@", _s); \
} while(0)

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
        if (!base) {
            TLOG(@"base not found, abort");
            return;
        }
        uint64_t a1 = base + RVA_GETBOOL;
        uint64_t a2 = base + RVA_ISDEV;
        uint64_t a3 = base + RVA_ISDEVBUILD;
        TLOG(@"addr getBool=0x%llx isDev=0x%llx isDevBuild=0x%llx",
             (unsigned long long)a1, (unsigned long long)a2, (unsigned long long)a3);
        [TitanoxHook addBreakpointAtAddress:(void*)a1 withHook:(void*)hook_getBool];
        [TitanoxHook addBreakpointAtAddress:(void*)a2 withHook:(void*)hook_isDev];
        [TitanoxHook addBreakpointAtAddress:(void*)a3 withHook:(void*)hook_isDevBuild];
        TLOG(@"breakpoints installed");
    }
}