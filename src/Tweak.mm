#import <Foundation/Foundation.h>
#import "libtitanox.h"
#include "offsets.h"

static bool (*orig_getBool)(void*);
static bool (*orig_isDev)(void*);
static bool (*orig_isDevBuild)(void*);

static bool hook_getBool(void* self) { return true; }
static bool hook_isDev(void* self) { return true; }
static bool hook_isDevBuild(void* self) { return true; }

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        if (!base) return;
        uint64_t addr_getBool    = base + RVA_GETBOOL;
        uint64_t addr_isDev      = base + RVA_ISDEV;
        uint64_t addr_isDevBuild = base + RVA_ISDEVBUILD;
        [TitanoxHook addBreakpointAtAddress:(void*)addr_getBool    withHook:(void*)hook_getBool];
        [TitanoxHook addBreakpointAtAddress:(void*)addr_isDev      withHook:(void*)hook_isDev];
        [TitanoxHook addBreakpointAtAddress:(void*)addr_isDevBuild withHook:(void*)hook_isDevBuild];
    }
}