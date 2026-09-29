#import <Foundation/Foundation.h>
#import "libtitanox.h"
#include "offsets.h"
#include <syslog.h>
#include <string.h>

static bool hook_getBool(void *self, const char *key) {
    if (key && (strstr(key, "Disable") || strstr(key, "isDev") ||
                strstr(key, "isDevBuild") || strstr(key, "isDeveloperBuild") ||
                strstr(key, "debug") || strstr(key, "Debug") ||
                strstr(key, "cheat") || strstr(key, "Cheat"))) {
        syslog(LOG_ERR, "Titanox: getBool(%s) -> true", key);
        return true;
    }
    return false;
}

static bool hook_isDev(void *self) {
    return true;
}

static bool hook_isDevBuild(void *self) {
    return true;
}

static bool hook_isDeveloperBuild(void *self) {
    return true;
}

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        if (!base) {
            syslog(LOG_ERR, "Titanox: base not found");
            return;
        }

        [TitanoxHook addBreakpointAtAddress:(void*)(base + RVA_GETBOOL)          withHook:(void*)hook_getBool];
        [TitanoxHook addBreakpointAtAddress:(void*)(base + RVA_ISDEV)            withHook:(void*)hook_isDev];
        [TitanoxHook addBreakpointAtAddress:(void*)(base + RVA_ISDEVBUILD)       withHook:(void*)hook_isDevBuild];
        [TitanoxHook addBreakpointAtAddress:(void*)(base + RVA_ISDEVELOPERBUILD) withHook:(void*)hook_isDeveloperBuild];

        syslog(LOG_ERR, "Titanox: 4 hooks installed, base=0x%llx", (unsigned long long)base);
    }
}