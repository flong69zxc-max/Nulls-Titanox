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

#define LOG_MAX_BYTES (200 * 1024)

#define RVA_MM_RECEIVE_A 0x75cce0
#define RVA_MM_RECEIVE_B 0x75c508

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_a = 0;
static volatile int g_hits_b = 0;
static volatile int g_font_hits = 0;

static uintptr_t g_addr_a = 0;
static uintptr_t g_addr_b = 0;
static uintptr_t g_addr_font = 0;

static void (*g_orig_a)(void *, void *) = NULL;
static void (*g_orig_b)(void *, void *) = NULL;

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

static NSString *hex_dump(void *p, int len) {
    if (!p) return @"null";
    const uint8_t *b = (const uint8_t *)p;
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < len; i++) {
        [s appendFormat:@"%02x ", b[i]];
        if ((i + 1) % 16 == 0) [s appendString:@"\n                "];
    }
    return s;
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

static void h_recv_a(void *self, void *msg) {
    g_hits_a++;
    if (g_hits_a <= 100) {
        int id = read_msg_id(msg);
        int sub = msg ? *(int *)((uint8_t *)msg + 0x90) : -1;
        NSMutableString *line = [NSMutableString string];
        [line appendFormat:@"RECV_A #%d self=%p msg=%p id=%d sub=%d",
              g_hits_a, self, msg, id, sub];
        if (msg) {
            [line appendFormat:@"\n  head: %@", hex_dump(msg, 32)];
        }
        tlog(line);
        if (id == 20103 && sub == 8) {
            tlog(@"*** RECV_A got 20103/sub8 ***");
        }
    }
    if (g_orig_a) {
        brk_suspend_self();
        g_orig_a(self, msg);
        brk_resume_self();
    }
}

static void h_recv_b(void *self, void *msg) {
    g_hits_b++;
    if (g_hits_b <= 100) {
        int id = read_msg_id(msg);
        int sub = msg ? *(int *)((uint8_t *)msg + 0x90) : -1;
        NSMutableString *line = [NSMutableString string];
        [line appendFormat:@"RECV_B #%d self=%p msg=%p id=%d sub=%d",
              g_hits_b, self, msg, id, sub];
        if (msg) {
            [line appendFormat:@"\n  head: %@", hex_dump(msg, 32)];
        }
        tlog(line);
        if (id == 20103 && sub == 8) {
            tlog(@"*** RECV_B got 20103/sub8 ***");
        }
    }
    if (g_orig_b) {
        brk_suspend_self();
        g_orig_b(self, msg);
        brk_resume_self();
    }
}

static void h_font(void) {
    g_font_hits++;
    if (g_font_hits <= 3) {
        tlog([NSString stringWithFormat:@"FONT #%d", g_font_hits]);
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

    g_addr_a    = g_base + RVA_MM_RECEIVE_A;
    g_addr_b    = g_base + RVA_MM_RECEIVE_B;
    g_addr_font = g_base + RVA_NATIVEFONT_FORMATSTRING;

    dump_target("A(0x75cce0)", g_addr_a);
    dump_target("B(0x7bace8)", g_addr_b);
    dump_target("F(font)    ", g_addr_font);

    g_orig_a = (void (*)(void *, void *))brk_original_ptr((void *)g_addr_a);
    bool ok_a = brk_install((void *)g_addr_a, (void *)&h_recv_a);
    tlog([NSString stringWithFormat:@"install A ok=%d orig=%p",
          ok_a ? 1 : 0, (void *)g_orig_a]);

    g_orig_b = (void (*)(void *, void *))brk_original_ptr((void *)g_addr_b);
    bool ok_b = brk_install((void *)g_addr_b, (void *)&h_recv_b);
    tlog([NSString stringWithFormat:@"install B ok=%d orig=%p",
          ok_b ? 1 : 0, (void *)g_orig_b]);

    bool ok_f = brk_install((void *)g_addr_font, (void *)&h_font);
    tlog([NSString stringWithFormat:@"install F ok=%d", ok_f ? 1 : 0]);

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
            @"base=%p\nA(0x75cce0)=%d\nB(0x7bace8)=%d\nF(font)=%d\nslots=%d",
            (void *)g_base, g_hits_a, g_hits_b, g_font_hits, brk_slot_limit()];
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 35 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @30s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 65 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @60s");
    });
}