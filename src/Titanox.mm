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

#define BCR_ON 0x1e5ULL

static uintptr_t g_base = 0;
static char g_path[512] = {0};
static FILE *g_log = NULL;

static uintptr_t g_t_stage = 0;
static uintptr_t g_t_gb = 0;
static uintptr_t g_t_recv = 0;
static uintptr_t g_t_getpid = 0;

static volatile int g_hits_stage = 0;
static volatile int g_hits_gb = 0;
static volatile int g_hits_recv = 0;
static volatile int g_hits_getpid = 0;
static volatile int g_arm_ok = 0;
static volatile int g_arm_fail = 0;
static volatile int g_frida_images = 0;
static volatile int g_bp_ports = 0;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
typedef pid_t (*getpid_fn)(void);
static recv_fn g_orig_recv = NULL;
static getpid_fn g_orig_getpid = NULL;

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

static void scan_frida(void) {
    g_frida_images = 0;
    uint32_t n = _dyld_image_count();
    log_line([NSString stringWithFormat:@"--- dyld scan (%u) ---", n]);
    for (uint32_t i = 0; i < n; i++) {
        const char *path = _dyld_get_image_name(i);
        if (!path) continue;
        if (strcasestr(path, "frida") ||
            strcasestr(path, "Frida")) {
            g_frida_images++;
            log_line([NSString stringWithFormat:@"[FRIDA] %s", path]);
        }
        if (strcasestr(path, "Titanox") ||
            strcasestr(path, "ellekit") ||
            strcasestr(path, "substrate") ||
            strcasestr(path, "substitute")) {
            log_line([NSString stringWithFormat:@"[HOOKER] %s", path]);
        }
    }
    log_line([NSString stringWithFormat:@"frida_images=%d", g_frida_images]);
}

static void check_bp_ports(void) {
    mach_port_t ports[EXC_TYPES_COUNT];
    mach_msg_type_number_t cnt = EXC_TYPES_COUNT;
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    memset(ports, 0, sizeof(ports));

    kern_return_t kr = task_get_exception_ports(mach_task_self(),
        EXC_MASK_BREAKPOINT, masks, &cnt, ports, behaviors, flavors);

    g_bp_ports = (kr == KERN_SUCCESS) ? (int)cnt : -1;

    log_line([NSString stringWithFormat:
        @"--- EXC_MASK_BREAKPOINT: kr=%d count=%u ---", kr, cnt]);

    for (uint32_t i = 0; i < cnt; i++) {
        Dl_info di = {0};
        const char *owner = "?";
        if (dladdr((void *)(uintptr_t)ports[i], &di) && di.dli_fname) {
            owner = basename((char *)di.dli_fname);
        }
        log_line([NSString stringWithFormat:
            @"  port[%u]=%u behavior=0x%x owner=%s",
            i, ports[i], behaviors[i], owner]);
    }
}

static void manual_arm(void) {
    task_t task = mach_task_self();
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(task, &threads, &count) != KERN_SUCCESS) return;

    int ok = 0, fail = 0;

    for (mach_msg_type_number_t i = 0; i < count; i++) {
        arm_debug_state64_t st;
        mach_msg_type_number_t cnt = ARM_DEBUG_STATE64_COUNT;
        memset(&st, 0, sizeof(st));

        st.__bvr[0] = (uint64_t)g_t_stage;  st.__bcr[0] = (uint32_t)BCR_ON;
        st.__bvr[1] = (uint64_t)g_t_gb;     st.__bcr[1] = (uint32_t)BCR_ON;
        st.__bvr[2] = (uint64_t)g_t_recv;   st.__bcr[2] = (uint32_t)BCR_ON;
        st.__bvr[3] = (uint64_t)g_t_getpid; st.__bcr[3] = (uint32_t)BCR_ON;

        kern_return_t kr = thread_set_state(threads[i], ARM_DEBUG_STATE64,
                                            (thread_state_t)&st, cnt);
        if (kr == KERN_SUCCESS) ok++;
        else fail++;

        mach_port_deallocate(task, threads[i]);
    }
    vm_deallocate(task, (vm_address_t)threads, count * sizeof(thread_act_t));

    g_arm_ok = ok;
    g_arm_fail = fail;
}

static void stage_hook(void *self, void *a2, void *a3, void *a4) { g_hits_stage++; }
static void gb_hook(void *self, void *a2) { g_hits_gb++; }

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

static pid_t getpid_hook(void) {
    g_hits_getpid++;
    if (g_hits_getpid <= 5 || (g_hits_getpid % 100 == 0)) {
        log_line([NSString stringWithFormat:@"GETPID #%d", g_hits_getpid]);
    }
    if (g_orig_getpid) {
        brk_suspend_self();
        pid_t r = g_orig_getpid();
        brk_resume_self();
        return r;
    }
    return 0;
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

    scan_frida();
    check_bp_ports();

    g_t_stage = g_base + RVA_STAGE_SETVIEWPORT;
    g_t_gb    = g_base + RVA_GAMEBUTTON_CTOR;
    g_t_recv  = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;

    void *getpid_addr = dlsym(RTLD_DEFAULT, "getpid");
    g_t_getpid = (uintptr_t)getpid_addr;

    g_orig_recv   = (recv_fn)brk_original_ptr((void *)g_t_recv);
    g_orig_getpid = (getpid_fn)brk_original_ptr(getpid_addr);

    brk_install((void *)g_t_stage, (void *)&stage_hook);
    brk_install((void *)g_t_gb,    (void *)&gb_hook);
    brk_install((void *)g_t_recv,  (void *)&recv_hook);
    brk_install(getpid_addr,       (void *)&getpid_hook);

    manual_arm();

    log_line([NSString stringWithFormat:
        @"targets stage=%p gb=%p recv=%p getpid=%p arm ok=%d fail=%d",
        (void *)g_t_stage, (void *)g_t_gb, (void *)g_t_recv, getpid_addr,
        g_arm_ok, g_arm_fail]);
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

        NSString *frida = g_frida_images > 0
            ? [NSString stringWithFormat:@"⚠️ %d (still loaded)", g_frida_images]
            : @"clean";

        NSString *msg = [NSString stringWithFormat:
            @"base: %p\narm: %d ok / %d fail\n"
            @"bp ports: %d\nfrida: %@\n\n"
            @"getpid: %d\nstage:  %d\ngb:     %d\nrecv:   %d\n\n"
            @"log: Documents/Titanox.log",
            (void *)g_base, g_arm_ok, g_arm_fail,
            g_bp_ports, frida,
            g_hits_getpid, g_hits_stage, g_hits_gb, g_hits_recv];

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

        [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *t) {
            manual_arm();
        }];
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}