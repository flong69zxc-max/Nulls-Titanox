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

static bool hook_getBool(void *self) {
    TLOG(@"getBool called");
    return true;
}

static bool hook_isDev(void *self) {
    TLOG(@"isDev called");
    return true;
}

static bool hook_isDevBuild(void *self) {
    TLOG(@"isDevBuild called");
    return true;
}

static bool hook_isDeveloperBuild(void *self) {
    TLOG(@"isDeveloperBuild called");
    return true;
}

static void hook_loadResources(void *self) {
    TLOG(@"loadResources called");
}

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        TLOG(@"=== Titanox init ===");
        uint64_t base = [TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        TLOG(@"base=0x%llx", (unsigned long long)base);
        if (!base) return;

        uint64_t a_getBool           = base + RVA_GETBOOL;
        uint64_t a_isDev             = base + RVA_ISDEV;
        uint64_t a_isDevBuild        = base + RVA_ISDEVBUILD;
        uint64_t a_isDeveloperBuild  = base + RVA_ISDEVELOPERBUILD;
        uint64_t a_loadResources     = base + RVA_LOADRESOURCES;

        [TitanoxHook addBreakpointAtAddress:(void*)a_getBool          withHook:(void*)hook_getBool];
        [TitanoxHook addBreakpointAtAddress:(void*)a_isDev            withHook:(void*)hook_isDev];
        [TitanoxHook addBreakpointAtAddress:(void*)a_isDevBuild       withHook:(void*)hook_isDevBuild];
        [TitanoxHook addBreakpointAtAddress:(void*)a_isDeveloperBuild withHook:(void*)hook_isDeveloperBuild];
        [TitanoxHook addBreakpointAtAddress:(void*)a_loadResources    withHook:(void*)hook_loadResources];

        TLOG(@"bp getBool=0x%llx isDev=0x%llx isDevBuild=0x%llx isDeveloperBuild=0x%llx loadResources=0x%llx",
             (unsigned long long)a_getBool,
             (unsigned long long)a_isDev,
             (unsigned long long)a_isDevBuild,
             (unsigned long long)a_isDeveloperBuild,
             (unsigned long long)a_loadResources);
    }
}