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

#define LOG_MAX_BYTES (100 * 1024)
#define RVA_MESSAGEMANAGER_RECEIVEMESSAGE 0x7bace8

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_recv = 0;

static uintptr_t g_addr_recv = 0;
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

static void h_recv(void *self, void *msg) {
    g_hits_recv++;
    if (g_hits_recv <= 100) {
        uint32_t raw0 = 0;
        if (msg) memcpy(&raw0, msg, 4);
        tlog([NSString stringWithFormat:@"RECV #%d self=%p msg=%p raw=0x%x",
              g_hits_recv, self, msg, raw0]);
    }
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg);
        brk_resume_self();
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

    g_addr_recv = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;

    uint32_t w[4] = {0};
    memcpy(w, (void *)g_addr_recv, sizeof(w));
    tlog([NSString stringWithFormat:@"recv=%p prologue=%08x %08x %08x %08x",
          (void *)g_addr_recv, w[0], w[1], w[2], w[3]]);

    if (g_addr_recv) {
        g_orig_recv = (void (*)(void *, void *))brk_original_ptr((void *)g_addr_recv);
        bool ok = brk_install((void *)g_addr_recv, (void *)&h_recv);
        tlog([NSString stringWithFormat:@"installed RECV ok=%d orig=%p",
              ok ? 1 : 0, (void *)g_orig_recv]);
    }

    tlog(@"setup done");
}

__attribute__((constructor))
static void start(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        setup();
    });
}