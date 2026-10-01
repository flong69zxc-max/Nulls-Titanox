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

typedef struct {
    uintptr_t base;
    const struct mach_header_64 *hdr;
} image_ref_t;

extern uintptr_t rt_resolve_method(image_ref_t, const char *, const char *,
                                    uintptr_t *, size_t, uintptr_t *);

#define LOG_MAX_BYTES (100 * 1024)

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_stage = 0;
static volatile int g_hits_recv = 0;
static volatile int g_hits_fmt = 0;
static volatile int g_hits_mc = 0;
static volatile int g_hits_getpid = 0;

static uintptr_t g_addr_stage = 0;
static uintptr_t g_addr_recv = 0;
static uintptr_t g_addr_fmt = 0;
static uintptr_t g_addr_mc = 0;

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
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
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

static void h_getpid(void) {
    g_hits_getpid++;
    if (g_hits_getpid <= 3 || g_hits_getpid % 5000 == 0) {
        tlog([NSString stringWithFormat:@"GETPID #%d", g_hits_getpid]);
    }
}

static void h_stage(void *a, void *b, void *c, void *d) {
    g_hits_stage++;
    tlog([NSString stringWithFormat:@"STAGE #%d self=%p", g_hits_stage, a]);
}

static void h_recv(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits_recv++;
    uint32_t msgId = 0;
    if (msg) memcpy(&msgId, msg, 4);
    tlog([NSString stringWithFormat:@"RECV #%d msg=%p id=0x%x",
          g_hits_recv, msg, msgId]);
}

static void h_fmt(void *a, void *b, void *c) {
    g_hits_fmt++;
    if (g_hits_fmt <= 3 || g_hits_fmt % 5000 == 0) {
        tlog([NSString stringWithFormat:@"FMT #%d", g_hits_fmt]);
    }
}

static void h_mc(void *a, void *b) {
    g_hits_mc++;
    if (g_hits_mc <= 3 || g_hits_mc % 500 == 0) {
        tlog([NSString stringWithFormat:@"MC #%d", g_hits_mc]);
    }
}

static void setup(void) {
    tlog(@"=== setup ===");
    tlog([NSString stringWithFormat:@"slots=%d selftest=%d",
          brk_slot_limit(), brk_selftest()]);

    if (!find_game_image(&g_base)) {
        tlog(@"game not found");
        return;
    }
    tlog([NSString stringWithFormat:@"base=%p", (void *)g_base]);

    image_ref_t img = { .base = g_base, .hdr = (const struct mach_header_64 *)g_base };
    uintptr_t xref = 0;

    g_addr_stage = rt_resolve_method(img, "Stage", "setViewport", NULL, 0, &xref);
    g_addr_recv  = rt_resolve_method(img, "MessageManager", "receiveMessage", NULL, 0, &xref);
    g_addr_fmt   = rt_resolve_method(img, "NativeFont", "formatString", NULL, 0, &xref);
    g_addr_mc    = rt_resolve_method(img, "MovieClip", "MovieClip", NULL, 0, &xref);

    tlog([NSString stringWithFormat:@"resolved stage=%p recv=%p fmt=%p mc=%p",
          (void *)g_addr_stage, (void *)g_addr_recv,
          (void *)g_addr_fmt, (void *)g_addr_mc]);

    void *getpid_addr = dlsym(RTLD_DEFAULT, "getpid");

    if (g_addr_stage) brk_install((void *)g_addr_stage, (void *)&h_stage);
    if (g_addr_recv)  brk_install((void *)g_addr_recv,  (void *)&h_recv);
    if (g_addr_fmt)   brk_install((void *)g_addr_fmt,   (void *)&h_fmt);
    if (g_addr_mc)    brk_install((void *)g_addr_mc,    (void *)&h_mc);
    if (getpid_addr)  brk_install(getpid_addr,          (void *)&h_getpid);

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

static void show_alert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = top_vc();
        if (!root) return;
        NSString *msg = [NSString stringWithFormat:
            @"slots=%d\n\n"
            @"getpid: %d\n"
            @"stage:  %d\nrecv:   %d\nfmt:    %d\nmc:     %d\n\n"
            @"stage=%p\nrecv=%p\nfmt=%p\nmc=%p\n\n"
            @"log: %ld / %d B\n"
            @"Documents/Titanox.log",
            brk_slot_limit(),
            g_hits_getpid,
            g_hits_stage, g_hits_recv, g_hits_fmt, g_hits_mc,
            (void *)g_addr_stage, (void *)g_addr_recv,
            (void *)g_addr_fmt, (void *)g_addr_mc,
            g_log_written, LOG_MAX_BYTES];

        UIAlertController *a = [UIAlertController
            alertControllerWithTitle:@"Titanox diag" message:msg
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
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}