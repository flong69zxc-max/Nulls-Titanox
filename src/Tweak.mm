#import <Foundation/Foundation.h>
#import "libtitanox.h"
#include "offsets.h"

static bool hook_getBool(void* self) { return true; }
static bool hook_isDev(void* self) { return true; }
static bool hook_isDevBuild(void* self) { return true; }

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        if (!base) return;
        [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_GETBOOL)     withHook:(void *)hook_getBool];
        [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_ISDEV)       withHook:(void *)hook_isDev];
        [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_ISDEVBUILD)  withHook:(void *)hook_isDevBuild];
    }
}