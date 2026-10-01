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
#import <libgen.h>
#import <ptrauth.h>
#import "libtitanox.h"
#import "offsets.h"

#define BCR_ON  0x1e5ULL

static uintptr_t g_base = 0;
static char g_path[512] = {0};
static FILE *g_log = NULL;

static uintptr_t g_t_stage = 0;
static uintptr_t g_t_gb = 0;
static uintptr_t g_t_recv = 0;

static volatile int g_hits_stage = 0;
static volatile int g_hits_gb = 0;
static volatile int g_hits_recv = 0;
static volatile int g_arm_count = 0;
static volatile int g_arm_fail = 0;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
static recv_fn g_orig_recv = NULL;

static void log_line(NSString *s) {
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Titanox.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (!g_log) return;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    if (d.length) {
        fwrite(d.bytes, 1, d.length, g_log);
        fputc('\n', g_log);
        fflush(g_log);
    }
}

static BOOL find_game_image(uintptr_t *out_base, char *out_path, size_t cap) {
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
        strncpy(out_path, path, cap - 1);
        return YES;
    }
    return NO;
}

static uintptr_t strip_pac(void *p) {
    if (!p) return 0;
    return (uintptr_t)ptrauth_strip(p, ptrauth_key_function_pointer);
}

static void manual_arm_all_threads(void) {
    task_t task = mach_task_self();
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(task, &threads, &count) != KERN_SUCCESS) return;

    int ok = 0, fail = 0;

    for (mach_msg_type_number_t i = 0; i < count; i++) {
        arm_debug_state64_t st;
        mach_msg_type_number_t cnt = ARM_DEBUG_STATE64_COUNT;
        memset(&st, 0, sizeof(st));

        st.__bvr[0] = (uint64_t)g_t_stage;
        st.__bcr[0] = (uint32_t)BCR_ON;
        st.__bvr[1] = (uint64_t)g_t_gb;
        st.__bcr[1] = (uint32_t)BCR_ON;
        st.__bvr[2] = (uint64_t)g_t_recv;
        st.__bcr[2] = (uint32_t)BCR_ON;

        kern_return_t kr = thread_set_state(threads[i], ARM_DEBUG_STATE64,
                                            (thread_state_t)&st, cnt);
        if (kr == KERN_SUCCESS) ok++;
        else fail++;

        mach_port_deallocate(task, threads[i]);
    }
    vm_deallocate(task, (vm_address_t)threads, count * sizeof(thread_act_t));

    g_arm_count = ok;
    g_arm_fail = fail;
}

static void stage_hook(void *self, void *a2, void *a3, void *a4) {
    g_hits_stage++;
    if (g_hits_stage <= 3 || (g_hits_stage % 300 == 0)) {
        log_line([NSString stringWithFormat:@"STAGE #%d", g_hits_stage]);
    }
}

static void gb_hook(void *self, void *a2) {
    g_hits_gb++;
    if (g_hits_gb <= 3 || (g_hits_gb % 100 == 0)) {
        log_line([NSString stringWithFormat:@"GB #%d self=%p", g_hits_gb, self]);
    }
}

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits_recv++;
    if (g_hits_recv <= 5 || (g_hits_recv % 50 == 0)) {
        log_line([NSString stringWithFormat:@"RECV #%d msg=%p", g_hits_recv, msg]);
    }
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg, a, b, c, d);
        brk_resume_self();
    }
}

static void setup(void) {
    log_line(@"=== setup ===");
    log_line([NSString stringWithFormat:@"slots=%d selftest=%d",
              brk_slot_limit(), brk_selftest()]);

    if (!find_game_image(&g_base, g_path, sizeof(g_path))) {
        log_line(@"game not found");
        return;
    }
    log_line([NSString stringWithFormat:@"base=%p path=%s", (void *)g_base, g_path]);

    g_t_stage = g_base + RVA_STAGE_SETVIEWPORT;
    g_t_gb    = g_base + RVA_GAMEBUTTON_CTOR;
    g_t_recv  = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;

    g_orig_recv = (recv_fn)brk_original_ptr((void *)g_t_recv);

    brk_install((void *)g_t_stage, (void *)&stage_hook);
    brk_install((void *)g_t_gb,    (void *)&gb_hook);
    brk_install((void *)g_t_recv,  (void *)&recv_hook);

    manual_arm_all_threads();

    log_line([NSString stringWithFormat:
        @"targets stage=%p gb=%p recv=%p manual_arm ok=%d fail=%d",
        (void *)g_t_stage, (void *)g_t_gb, (void *)g_t_recv,
        g_arm_count, g_arm_fail]);
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
            @"base: %p\nactive: %d / slots: %d\narm ok: %d fail: %d\n\n"
            @"stage: %d\ngb:    %d\nrecv:  %d\n\n"
            @"log: Documents/Titanox.log",
            (void *)g_base, brk_active_count(), brk_slot_limit(),
            g_arm_count, g_arm_fail,
            g_hits_stage, g_hits_gb, g_hits_recv];

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

        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
            manual_arm_all_threads();
        }];

        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}