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

static uintptr_t g_t_stage_real = 0;
static uintptr_t g_t_stage_thunk = 0;
static uintptr_t g_t_gb = 0;
static uintptr_t g_t_recv = 0;
static uintptr_t g_t_getpid = 0;
static uintptr_t g_t_malloc = 0;

static volatile int g_hits_stage_real = 0;
static volatile int g_hits_stage_thunk = 0;
static volatile int g_hits_gb = 0;
static volatile int g_hits_recv = 0;
static volatile int g_hits_getpid = 0;
static volatile int g_hits_malloc = 0;
static volatile int g_arm_ok = 0;
static volatile int g_arm_fail = 0;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
typedef pid_t (*getpid_fn)(void);
typedef void *(*malloc_fn)(size_t);
static recv_fn g_orig_recv = NULL;
static getpid_fn g_orig_getpid = NULL;
static malloc_fn g_orig_malloc = NULL;

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

        int slot = 0;
        if (g_t_stage_real)  { st.__bvr[slot] = g_t_stage_real;  st.__bcr[slot] = (uint32_t)BCR_ON; slot++; }
        if (g_t_stage_thunk) { st.__bvr[slot] = g_t_stage_thunk; st.__bcr[slot] = (uint32_t)BCR_ON; slot++; }
        if (g_t_recv)        { st.__bvr[slot] = g_t_recv;        st.__bcr[slot] = (uint32_t)BCR_ON; slot++; }
        if (g_t_getpid)      { st.__bvr[slot] = g_t_getpid;      st.__bcr[slot] = (uint32_t)BCR_ON; slot++; }
        if (g_t_malloc)      { st.__bvr[slot] = g_t_malloc;      st.__bcr[slot] = (uint32_t)BCR_ON; slot++; }
        if (slot >= 6) break;

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

static uintptr_t decode_bl(uintptr_t thunk_addr, uint32_t opcode) {
    if ((opcode & 0xFC000000) != 0x94000000) return 0;
    int32_t imm26 = opcode & 0x03FFFFFF;
    int64_t offset = (int64_t)(imm26 << 2);
    if (offset & (1LL << 27)) {
        offset |= ~((1LL << 28) - 1);
    }
    return (uintptr_t)((int64_t)thunk_addr + offset);
}

static void log_thunk_analysis(const char *name, uintptr_t thunk_addr) {
    uint32_t op0 = *(volatile uint32_t *)thunk_addr;
    uint32_t op1 = *(volatile uint32_t *)(thunk_addr + 4);
    uint32_t op2 = *(volatile uint32_t *)(thunk_addr + 8);
    uint32_t op3 = *(volatile uint32_t *)(thunk_addr + 12);

    log_line([NSString stringWithFormat:
        @"%@ thunk=%p ops: %08x %08x %08x %08x",
        [NSString stringWithUTF8String:name],
        (void *)thunk_addr, op0, op1, op2, op3]);

    uintptr_t real = decode_bl(thunk_addr + 8, op2);
    if (real) {
        uint32_t r0 = *(volatile uint32_t *)real;
        uint32_t r1 = *(volatile uint32_t *)(real + 4);
        log_line([NSString stringWithFormat:
            @"%@ REAL target=%p ops: %08x %08x",
            [NSString stringWithUTF8String:name],
            (void *)real, r0, r1]);
    }
}

static void stage_real_hook(void *self, void *a2, void *a3, void *a4) {
    g_hits_stage_real++;
}
static void stage_thunk_hook(void *self, void *a2, void *a3, void *a4) {
    g_hits_stage_thunk++;
}
static void gb_hook(void *self, void *a2) { g_hits_gb++; }

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits_recv++;
    if (g_hits_recv <= 5) log_line([NSString stringWithFormat:@"RECV #%d", g_hits_recv]);
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg, a, b, c, d);
        brk_resume_self();
    }
}

static pid_t getpid_hook(void) {
    g_hits_getpid++;
    if (g_hits_getpid <= 5 || (g_hits_getpid % 500 == 0)) {
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

static void *malloc_hook(size_t sz) {
    g_hits_malloc++;
    if (g_hits_malloc <= 5 || (g_hits_malloc % 500 == 0)) {
        log_line([NSString stringWithFormat:@"MALLOC #%d size=%zu", g_hits_malloc, sz]);
    }
    if (g_orig_malloc) {
        brk_suspend_self();
        void *r = g_orig_malloc(sz);
        brk_resume_self();
        return r;
    }
    return NULL;
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

    g_t_stage_thunk = g_base + RVA_STAGE_SETVIEWPORT;
    g_t_gb          = g_base + RVA_GAMEBUTTON_CTOR;
    g_t_recv        = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;

    log_thunk_analysis("stage", g_t_stage_thunk);
    log_thunk_analysis("gb",    g_t_gb);
    log_thunk_analysis("recv",  g_t_recv);

    uint32_t stage_op2 = *(volatile uint32_t *)(g_t_stage_thunk + 8);
    g_t_stage_real = decode_bl(g_t_stage_thunk + 8, stage_op2);

    void *getpid_addr = dlsym(RTLD_DEFAULT, "getpid");
    void *malloc_addr = dlsym(RTLD_DEFAULT, "malloc");
    g_t_getpid = (uintptr_t)getpid_addr;
    g_t_malloc = (uintptr_t)malloc_addr;

    g_orig_recv   = (recv_fn)brk_original_ptr((void *)g_t_recv);
    g_orig_getpid = (getpid_fn)brk_original_ptr(getpid_addr);
    g_orig_malloc = (malloc_fn)brk_original_ptr(malloc_addr);

    if (g_t_stage_real) brk_install((void *)g_t_stage_real, (void *)&stage_real_hook);
    brk_install((void *)g_t_stage_thunk, (void *)&stage_thunk_hook);
    brk_install((void *)g_t_recv,        (void *)&recv_hook);
    brk_install(getpid_addr,             (void *)&getpid_hook);
    brk_install(malloc_addr,             (void *)&malloc_hook);

    manual_arm();

    log_line([NSString stringWithFormat:
        @"stage_thunk=%p stage_real=%p recv=%p getpid=%p malloc=%p arm ok=%d fail=%d",
        (void *)g_t_stage_thunk, (void *)g_t_stage_real,
        (void *)g_t_recv, getpid_addr, malloc_addr,
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

        NSString *msg = [NSString stringWithFormat:
            @"arm: %d ok / %d fail\n\n"
            @"getpid: %d\nmalloc: %d\n\n"
            @"stage_real:  %d\nstage_thunk: %d\ngb:          %d\nrecv:        %d\n\n"
            @"real=%p\n\nlog: Documents/Titanox.log",
            g_arm_ok, g_arm_fail,
            g_hits_getpid, g_hits_malloc,
            g_hits_stage_real, g_hits_stage_thunk,
            g_hits_gb, g_hits_recv,
            (void *)g_t_stage_real];

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