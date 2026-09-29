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
        TitanoxHook *hooker = [[TitanoxHook alloc] initWithMachOName:@"Nulls Brawl"];
        if (!hooker) return;
        orig_getBool = (bool(*)(void*))[hooker hookFunctionAtVaddr:base + RVA_GETBOOL withReplacement:(void*)hook_getBool];
        orig_isDev = (bool(*)(void*))[hooker hookFunctionAtVaddr:base + RVA_ISDEV withReplacement:(void*)hook_isDev];
        orig_isDevBuild = (bool(*)(void*))[hooker hookFunctionAtVaddr:base + RVA_ISDEVBUILD withReplacement:(void*)hook_isDevBuild];
    }
}
