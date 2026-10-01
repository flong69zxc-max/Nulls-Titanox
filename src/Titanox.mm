#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>

#include "hook.h"
#include "offsets.h"

typedef pid_t (*getpid_fn_t)(void);

static image_ref_t g_image = {};
static uintptr_t g_targets[4] = {};
static uintptr_t g_xrefs[4] = {};

static const char *g_classes[4] = {
    "Stage",
    "MessageManager",
    "NativeFont",
    "MovieClip"
};

static const char *g_methods[4] = {
    "setViewport",
    "receiveMessage",
    "formatString",
    "MovieClip"
};

static getpid_fn_t g_getpid = nullptr;

static bool find_game_image(image_ref_t *out)
{
    NSString *executable = NSBundle.mainBundle.executablePath;

    brk_diag_log(
        "bundle executable=%s bundle=%s",
        executable.UTF8String ?: "?",
        NSBundle.mainBundle.bundleIdentifier.UTF8String ?: "?"
    );

    const char *wanted = executable.UTF8String;

    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char *path = _dyld_get_image_name(i);
        const mach_header *header = _dyld_get_image_header(i);

        if (!path || !header || header->magic != MH_MAGIC_64) continue;

        if (strstr(path, ".app/")) {
            brk_diag_log(
                "image_candidate path=%s header=%p slide=0x%llx",
                path,
                header,
                (unsigned long long)(uintptr_t)
                    _dyld_get_image_vmaddr_slide(i)
            );
        }

        if (wanted && strcmp(path, wanted) == 0) {
            out->base = (uintptr_t)header;
            out->hdr = (const mach_header_64 *)header;
            return true;
        }
    }

    brk_diag_log("game_image_exact_match_missing");

    return false;
}

static void *getpid_worker(void *arg)
{
    usleep(350000);

    pid_t value = g_getpid();

    brk_diag_log(
        "getpid_test thread=worker result=%d hits=%llu",
        value,
        (unsigned long long)brk_hits((void *)g_getpid)
    );

    return nullptr;
}

static void test_getpid(void)
{
    g_getpid = (getpid_fn_t)dlsym(RTLD_DEFAULT, "getpid");

    if (!g_getpid) {
        brk_diag_log("getpid_dlsym_failed");
        return;
    }

    rt_dump_target("getpid", (uintptr_t)g_getpid);

    bool installed = brk_observe((void *)g_getpid);

    brk_diag_log(
        "getpid_test thread=main installed=%d",
        installed
    );

    if (installed) {
        pid_t value = g_getpid();

        brk_diag_log(
            "getpid_test thread=main result=%d hits=%llu",
            value,
            (unsigned long long)brk_hits((void *)g_getpid)
        );

        brk_remove((void *)g_getpid);
    }

    installed = brk_observe((void *)g_getpid);

    brk_diag_log(
        "getpid_test thread=worker installed=%d",
        installed
    );

    if (installed) {
        pthread_t worker;

        if (pthread_create(&worker, nullptr, getpid_worker, nullptr) == 0) {
            pthread_join(worker, nullptr);
        } else {
            brk_diag_log("getpid_worker_create_failed");
        }

        brk_remove((void *)g_getpid);
    }
}

static void arm_game_targets(void)
{
    if (!find_game_image(&g_image)) return;

    rt_dump_image(g_image);

    for (size_t i = 0; i < 4; ++i) {
        g_targets[i] = rt_resolve_method(
            g_image,
            g_classes[i],
            g_methods[i],
            nullptr,
            0,
            &g_xrefs[i]
        );

        brk_diag_log(
            "game_target class=%s method=%s target=%p xref=%p",
            g_classes[i],
            g_methods[i],
            (void *)g_targets[i],
            (void *)g_xrefs[i]
        );

        if (!g_targets[i]) continue;

        if (!rt_is_code(g_image, g_targets[i])) {
            brk_diag_log(
                "game_target_rejected class=%s method=%s reason=not_code",
                g_classes[i],
                g_methods[i]
            );

            continue;
        }

        rt_dump_target(g_methods[i], g_targets[i]);

        bool installed = brk_observe((void *)g_targets[i]);

        brk_diag_log(
            "game_observation class=%s method=%s installed=%d",
            g_classes[i],
            g_methods[i],
            installed
        );
    }

    brk_log_state();
}

static void setup(void)
{
    brk_diag_log("setup begin");

    bool calibrated = brk_calibrate_slots();
    bool selftest = calibrated && brk_selftest();

    brk_diag_log(
        "setup calibrated=%d live_slots=%d selftest=%d",
        calibrated,
        brk_live_slot_count(),
        selftest
    );

    if (!selftest) {
        brk_log_state();
        brk_diag_log("setup aborted");
        return;
    }

    test_getpid();
    arm_game_targets();

    static dispatch_source_t timer;

    timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER,
        0,
        0,
        dispatch_get_main_queue()
    );

    dispatch_source_set_timer(
        timer,
        dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC),
        5ULL * NSEC_PER_SEC,
        100ULL * NSEC_PER_MSEC
    );

    dispatch_source_set_event_handler(timer, ^{
        for (size_t i = 0; i < 4; ++i) {
            brk_diag_log(
                "game_hits class=%s method=%s target=%p hits=%llu",
                g_classes[i],
                g_methods[i],
                (void *)g_targets[i],
                (unsigned long long)brk_hits((void *)g_targets[i])
            );
        }

        brk_log_state();
    });

    dispatch_resume(timer);

    brk_diag_log("setup complete");
}

__attribute__((constructor))
static void start(void)
{
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC),
        dispatch_get_main_queue(),
        ^{
            setup();
        }
    );
}