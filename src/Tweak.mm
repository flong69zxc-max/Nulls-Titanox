#import <Foundation/Foundation.h>
#import "libtitanox.h"
#include "offsets.h"

static bool hook_getBool(void* self) {
    [TitanoxHook log:@"getBool self=%p -> true", self];
    return true;
}

static bool hook_isDev(void* self) {
    [TitanoxHook log:@"isDev self=%p -> true", self];
    return true;
}

static bool hook_isDevBuild(void* self) {
    [TitanoxHook log:@"isDevBuild self=%p -> true", self];
    return true;
}

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        [TitanoxHook log:@"=== Titanox init ==="];
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        [TitanoxHook log:@"base=%p", (void*)base];
        if (!base) {
            [TitanoxHook log:@"base not found, abort"];
            return;
        }
        void* a1 = (void*)(base + RVA_GETBOOL);
        void* a2 = (void*)(base + RVA_ISDEV);
        void* a3 = (void*)(base + RVA_ISDEVBUILD);
        [TitanoxHook log:@"target getBool=%p isDev=%p isDevBuild=%p", a1, a2, a3];
        BOOL r1 = [TitanoxHook addBreakpointAtAddress:a1 withHook:(void*)hook_getBool];
        BOOL r2 = [TitanoxHook addBreakpointAtAddress:a2 withHook:(void*)hook_isDev];
        BOOL r3 = [TitanoxHook addBreakpointAtAddress:a3 withHook:(void*)hook_isDevBuild];
        [TitanoxHook log:@"installed getBool=%d isDev=%d isDevBuild=%d", r1, r2, r3];
    }
}