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

static bool (*orig_getBool)(void*);
static bool (*orig_isDev)(void*);
static bool (*orig_isDevBuild)(void*);

static bool hook_getBool(void* self) {
    TLOG(@"getBool called -> true");
    return true;
}

static bool hook_isDev(void* self) {
    TLOG(@"isDev called -> true");
    return true;
}

static bool hook_isDevBuild(void* self) {
    TLOG(@"isDevBuild called -> true");
    return true;
}

__attribute__((constructor))
static void init() {
    @autoreleasepool {
        TLOG(@"=== Titanox init ===");

        [TitanoxHook hookStaticFunction:"_ZN10SCIDConfig7getBoolEPKc"
                        withReplacement:(void*)hook_getBool
                            inLibrary:"Nulls Brawl"
                       outOldFunction:(void**)&orig_getBool];
        TLOG(@"hooked getBool (fishhook)");

        [TitanoxHook hookStaticFunction:"_ZN12LogicVersion5isDevEv"
                        withReplacement:(void*)hook_isDev
                            inLibrary:"Nulls Brawl"
                       outOldFunction:(void**)&orig_isDev];
        TLOG(@"hooked isDev (fishhook)");

        [TitanoxHook hookStaticFunction:"_ZN12LogicVersion12isDevBuildEv"
                        withReplacement:(void*)hook_isDevBuild
                            inLibrary:"Nulls Brawl"
                       outOldFunction:(void**)&orig_isDevBuild];
        TLOG(@"hooked isDevBuild (fishhook)");
    }
}