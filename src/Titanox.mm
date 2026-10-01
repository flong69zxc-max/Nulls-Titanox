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

extern uintptr_t rt_resolve_method(image_ref_t, const char *, const char *,
                                    uintptr_t *, size_t, uintptr_t *);

#define LOG_MAX_BYTES (200 * 1024)

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_recv_begin = 0;
static volatile int g_hits_recv_xref = 0;
static volatile int g_hits_getpid = 0;

static uintptr_t g_addr_begin = 0;
static uintptr_t g_addr_xref = 0;
static uintptr_t g_addr_getpid = 0;

static void (*g_orig_recv)(void *, void *) = NULL;

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

static void h_recv_begin(void *self, void *msg) {
    g_hits_recv_begin++;
    tlog([NSString stringWithFormat:@"RECV_BEGIN #%d self=%p msg=%p",
          g_hits_recv_begin, self, msg]);
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg);
        brk_resume_self();
    }
}

static void h_recv_xref(void) {
    g_hits_recv_xref++;
    tlog([NSString stringWithFormat:@"RECV_XREF #%d", g_hits_recv_xref]);
}

static pid_t (*g_orig_getpid)(void) = NULL;

static pid_t h_getpid(void) {
    g_hits_getpid++;
    if (g_hits_getpid <= 3 || g_hits_getpid % 5000 == 0) {
        tlog([NSString stringWithFormat:@"GETPID #%d", g_hits_getpid]);
    }
    if (g_orig_getpid) {
        brk_suspend_self();
        pid_t r = g_orig_getpid();
        brk_resume_self();
        return r;
    }
    return 0;
}

static void dump_threads(void) {
    task_t task = mach_task_self();
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(task, &threads, &count) != KERN_SUCCESS) return;

    int with_bvr = 0;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        arm_debug_state64_t st;
        mach_msg_type_number_t cnt = ARM_DEBUG_STATE64_COUNT;
        if (thread_get_state(threads[i], ARM_DEBUG_STATE64,
                             (thread_state_t)&st, &cnt) == KERN_SUCCESS) {
            int has = 0;
            for (int s = 0; s < 3; s++) {
                if ((st.__bcr[s] & 1) && st.__bvr[s]) has = 1;
            }
            if (has) with_bvr++;
        }
        mach_port_deallocate(task, threads[i]);
    }
    vm_deallocate(task, (vm_address_t)threads, count * sizeof(thread_act_t));

    tlog([NSString stringWithFormat:@"THREADS total=%u with_bvr=%d",
          count, with_bvr]);
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
    uintptr_t xref_out = 0;

    g_addr_begin = rt_resolve_method(img, "MessageManager", "receiveMessage", NULL, 0, &xref_out);
    g_addr_xref  = xref_out;
    g_addr_getpid = (uintptr_t)dlsym(RTLD_DEFAULT, "getpid");

    tlog([NSString stringWithFormat:@"begin=%p xref=%p getpid=%p",
          (void *)g_addr_begin, (void *)g_addr_xref, (void *)g_addr_getpid]);

    if (g_addr_getpid) {
        g_orig_getpid = (pid_t(*)(void))g_addr_getpid;
        brk_install((void *)g_addr_getpid, (void *)&h_getpid);
        tlog(@"installed GETPID");
    }

    if (g_addr_begin) {
        g_orig_recv = (void (*)(void *, void *))g_addr_begin;
        brk_install((void *)g_addr_begin, (void *)&h_recv_begin);
        tlog(@"installed RECV_BEGIN");
    }

    if (g_addr_xref) {
        brk_install((void *)g_addr_xref, (void *)&h_recv_xref);
        tlog(@"installed RECV_XREF");
    }

    tlog(@"setup done");
}

__attribute__((constructor))
static void start(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        setup();
        [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer *t) {
            dump_threads();
        }];
    });
}