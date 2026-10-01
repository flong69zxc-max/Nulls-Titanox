#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/arm/thread_status.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <unistd.h>
#import <libgen.h>
#import "libtitanox.h"
#import "offsets.h"

#define LOG_MAX_BYTES (300 * 1024)

#define RVA_MM_RECEIVEMESSAGE        0x7bace8
#define RVA_HOMEMODE_GETINSTANCE     0x95f488
#define RVA_GUI_GETINSTANCE          0x5914b4
#define RVA_GUI_SHOWFLOATER_TEXTAT   0x591f28
#define RVA_GUI_SHOWFLOATER_DEFPOS   0x818cdc
#define RVA_STRING_CTOR              0xdcf8f0

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_recv = 0;
static volatile int g_hits_home = 0;
static volatile int g_hits_floater = 0;
static volatile int g_hits_floater_def = 0;
static volatile int g_lobby_welcome_done = 0;
static volatile int g_floater_fail_count = 0;

static uintptr_t g_addr_recv = 0;
static uintptr_t g_addr_home = 0;
static uintptr_t g_addr_gui = 0;
static uintptr_t g_addr_floater = 0;
static uintptr_t g_addr_floater_def = 0;
static uintptr_t g_addr_str_ctor = 0;

static void (*g_orig_recv)(void*, void*) = NULL;
static void* (*g_orig_home)(void) = NULL;

typedef void* (*gui_get_t)(void);
typedef void  (*gui_floater_t)(void*, void*, float, int);
typedef void* (*str_ctor_t)(void*, const char*);

static gui_get_t     g_fn_gui_get = NULL;
static gui_floater_t g_fn_floater = NULL;
static str_ctor_t    g_fn_str_ctor = NULL;

static void tlog_raw(const char *s) {
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Titanox.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (!g_log) return;
    if (g_log_written >= LOG_MAX_BYTES) return;
    size_t len = strlen(s);
    fwrite(s, 1, len, g_log);
    fputc('\n', g_log);
    fflush(g_log);
    g_log_written += (long)len + 1;
}

static void tlog(NSString *s) {
    if (!s) return;
    tlog_raw(s.UTF8String);
}

static BOOL find_game_image(uintptr_t *out_base) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *path = _dyld_get_image_name(i);
        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!path || !hdr || hdr->magic != MH_MAGIC_64) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "LiveContainer")) continue;
        if (strstr(path, "TweakLoader")) continue;
        if (strstr(path, "CydiaSubstrate")) continue;
        if (strstr(path, "libellekit")) continue;
        NSString *ns = [NSString stringWithUTF8String:path];
        if (![ns containsString:@".app/"]) continue;
        *out_base = (uintptr_t)hdr;
        return YES;
    }
    return NO;
}

static int read_msg_id(void *msg) {
    if (!msg) return 0;
    void **vt = *(void ***)msg;
    if (!vt) return 0;
    void *fn = *(void **)((uint8_t *)vt + 0x28);
    if (!fn) return 0;
    typedef int (*msgid_fn_t)(void *);
    return ((msgid_fn_t)fn)(msg);
}

static void show_floater(const char *text) {
    if (!text) return;
    if (!g_fn_gui_get || !g_fn_floater || !g_fn_str_ctor) {
        tlog(@"show_floater: missing func ptrs");
        g_floater_fail_count++;
        return;
    }

    void *gui = g_fn_gui_get();
    if (!gui) {
        tlog(@"show_floater: gui null");
        g_floater_fail_count++;
        return;
    }

    void *sc = malloc(40);
    if (!sc) {
        tlog(@"show_floater: malloc fail");
        g_floater_fail_count++;
        return;
    }
    memset(sc, 0, 40);
    g_fn_str_ctor(sc, text);

    g_fn_floater(gui, sc, 0.0f, -1);

    tlog([NSString stringWithFormat:@"FLOATER shown: '%s'", text]);
}

static void schedule_floater(const char *text, int delay_ms) {
    NSString *s = [NSString stringWithUTF8String:text];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay_ms * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        show_floater([s UTF8String]);
    });
}

static void h_recv(void *self, void *msg) {
    g_hits_recv++;
    int id = read_msg_id(msg);
    int sub = msg ? *(int *)((uint8_t *)msg + 0x90) : -1;

    if (g_hits_recv <= 30) {
        tlog([NSString stringWithFormat:@"RECV #%d id=%d sub=%d",
              g_hits_recv, id, sub]);
    }

    if (id == 20103 && sub == 8) {
        tlog(@"*** 20103/sub8 caught ***");
        schedule_floater("Tale Stars: update available!", 100);
    }

    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg);
        brk_resume_self();
    }
}

static void* h_home(void) {
    g_hits_home++;
    void *res = NULL;
    if (g_orig_home) {
        brk_suspend_self();
        res = g_orig_home();
        brk_resume_self();
    }

    if (!g_lobby_welcome_done && res) {
        g_lobby_welcome_done = 1;
        tlog(@"lobby detected, scheduling welcome floater");
        schedule_floater("Tale Stars loaded on iOS!", 1500);
    }
    return res;
}

static void h_floater(void) {
    g_hits_floater++;
    if (g_hits_floater <= 5) {
        tlog([NSString stringWithFormat:@"FLOATER_CALL #%d", g_hits_floater]);
    }
}

static void h_floater_def(void) {
    g_hits_floater_def++;
    if (g_hits_floater_def <= 5) {
        tlog([NSString stringWithFormat:@"FLOATER_DEF_CALL #%d", g_hits_floater_def]);
    }
}

static void dump_target(const char *name, uintptr_t addr) {
    if (!addr) return;
    uint32_t w[4] = {0};
    memcpy(w, (void *)addr, sizeof(w));
    tlog([NSString stringWithFormat:@"%s=%p prologue=%08x %08x %08x %08x",
          name, (void *)addr, w[0], w[1], w[2], w[3]]);
}

static void setup(void) {
    tlog(@"");
    tlog(@"=== setup ===");
    tlog([NSString stringWithFormat:@"slots=%d selftest=%d",
          brk_slot_limit(), brk_selftest()]);

    if (!find_game_image(&g_base)) {
        tlog(@"game not found");
        return;
    }
    tlog([NSString stringWithFormat:@"base=%p", (void *)g_base]);

    g_addr_recv        = g_base + RVA_MM_RECEIVEMESSAGE;
    g_addr_home        = g_base + RVA_HOMEMODE_GETINSTANCE;
    g_addr_gui         = g_base + RVA_GUI_GETINSTANCE;
    g_addr_floater     = g_base + RVA_GUI_SHOWFLOATER_TEXTAT;
    g_addr_floater_def = g_base + RVA_GUI_SHOWFLOATER_DEFPOS;
    g_addr_str_ctor    = g_base + RVA_STRING_CTOR;

    dump_target("recv",    g_addr_recv);
    dump_target("home",    g_addr_home);
    dump_target("gui",     g_addr_gui);
    dump_target("floater", g_addr_floater);
    dump_target("floaterD",g_addr_floater_def);
    dump_target("strctor", g_addr_str_ctor);

    g_fn_gui_get  = (gui_get_t)g_addr_gui;
    g_fn_floater  = (gui_floater_t)g_addr_floater;
    g_fn_str_ctor = (str_ctor_t)g_addr_str_ctor;

    g_orig_recv = (void (*)(void*, void*))brk_original_ptr((void *)g_addr_recv);
    bool ok1 = brk_install((void *)g_addr_recv, (void *)&h_recv);
    tlog([NSString stringWithFormat:@"install recv ok=%d", ok1 ? 1 : 0]);

    g_orig_home = (void* (*)(void))brk_original_ptr((void *)g_addr_home);
    bool ok2 = brk_install((void *)g_addr_home, (void *)&h_home);
    tlog([NSString stringWithFormat:@"install home ok=%d", ok2 ? 1 : 0]);

    bool ok3 = brk_install((void *)g_addr_floater, (void *)&h_floater);
    tlog([NSString stringWithFormat:@"install floater ok=%d", ok3 ? 1 : 0]);

    bool ok4 = brk_install((void *)g_addr_floater_def, (void *)&h_floater_def);
    tlog([NSString stringWithFormat:@"install floater_def ok=%d", ok4 ? 1 : 0]);

    tlog(@"setup done");
}

static UIViewController *top_vc(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindow *w = ((UIWindowScene *)scene).keyWindow;
        if (w.rootViewController) return w.rootViewController;
    }
    return nil;
}

static void show_stats(NSString *title) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = top_vc();
        if (!root) return;
        NSString *msg = [NSString stringWithFormat:
            @"base=%p\nrecv=%d\nhome=%d\nfloater=%d\nfloaterD=%d\nfail=%d\nslots=%d",
            (void *)g_base, g_hits_recv, g_hits_home,
            g_hits_floater, g_hits_floater_def,
            g_floater_fail_count, brk_slot_limit()];
        UIAlertController *a = [UIAlertController
            alertControllerWithTitle:title message:msg
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:a animated:YES completion:nil];
    });
}

__attribute__((constructor))
static void start(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        setup();
        show_stats(@"armed");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        if (!g_lobby_welcome_done) {
            g_lobby_welcome_done = 1;
            tlog(@"timed fallback, showing floater");
            show_floater("Tale Stars loaded on iOS!");
        }
        show_stats(@"stats @15s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @40s");
    });
}