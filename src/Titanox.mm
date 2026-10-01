#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import "libtitanox.h"
#import "offsets.h"

static uintptr_t g_base = 0;
static uintptr_t g_target = 0;
static volatile int g_hits = 0;
static volatile int g_matches = 0;
static NSString *g_status = @"";
static FILE *g_log = NULL;
static BOOL g_alert_shown = NO;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
typedef int  (*vfunc_id_t)(void *);

static recv_fn g_orig = NULL;

static void log_line(NSString *s) {
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Titanox.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (!g_log) return;
    fprintf(g_log, "%s\n", s.UTF8String);
    fflush(g_log);
}

static int read_msg_id(void *msg) {
    if (!msg) return 0;
    void **vtable = *(void ***)msg;
    if (!vtable) return 0;
    void *fn = *(void **)((uint8_t *)vtable + 0x28);
    if (!fn) return 0;
    return ((vfunc_id_t)fn)(msg);
}

static void patch_msg(void *msg) {
    if (!msg) return;

    int id = read_msg_id(msg);
    if (id != 20103) return;

    int sub = *(int *)((uint8_t *)msg + 144);
    if (sub != 8) return;

    g_matches++;

    void *title = strdup("Join t.me/talebrawl for new Tale Stars update!");
    void *link  = strdup("t.me/talebrawl");

    *(void **)((uint8_t *)msg + 192) = title;
    *(void **)((uint8_t *)msg + 184) = link;

    log_line([NSString stringWithFormat:
        @"patched msg=%p id=%d sub=%d title=%p link=%p",
        msg, id, sub, title, link]);
}

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits++;

    if (g_hits <= 5 || (g_hits % 100 == 0)) {
        int id = read_msg_id(msg);
        int sub = msg ? *(int *)((uint8_t *)msg + 144) : 0;
        log_line([NSString stringWithFormat:
            @"recv #%d msg=%p id=%d sub=%d", g_hits, msg, id, sub]);
    }

    patch_msg(msg);

    if (g_orig) {
        brk_suspend_self();
        g_orig(self, msg, a, b, c, d);
        brk_resume_self();
    }
}

static uintptr_t image_for_rva(uint64_t rva) {
    Dl_info info;
    uintptr_t mine = 0;
    if (dladdr((void *)&recv_hook, &info)) mine = (uintptr_t)info.dli_fbase;

    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *path = _dyld_get_image_name(i);
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!path || !hdr || hdr->magic != MH_MAGIC_64) continue;
        if ((uintptr_t)hdr == mine) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "LiveContainer")) continue;
        if (strstr(path, "TweakLoader")) continue;
        if (strstr(path, ".dylib")) continue;

        uint32_t nc = hdr->ncmds > 1024 ? 1024 : hdr->ncmds;
        const struct load_command *cmd =
            (const struct load_command *)((const uint8_t *)hdr + sizeof(struct mach_header_64));
        uint64_t origin = 0;
        bool have_origin = false;
        for (uint32_t c = 0; c < nc; c++) {
            if (cmd->cmdsize < sizeof(struct load_command)) break;
            if (cmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (const struct segment_command_64 *)cmd;
                if (!have_origin) { origin = seg->vmaddr; have_origin = true; }
                uint64_t rel = seg->vmaddr - origin;
                if ((seg->initprot & VM_PROT_EXECUTE) && rva >= rel && rva < rel + seg->vmsize) {
                    return (uintptr_t)hdr;
                }
            }
            cmd = (const struct load_command *)((const uint8_t *)cmd + cmd->cmdsize);
        }
    }
    return 0;
}

static NSString *arm_hook(void) {
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:@"slots: %d\n", brk_slot_limit()];
    [out appendFormat:@"selftest: %s\n", brk_selftest() ? "pass" : "fail"];

    g_base = image_for_rva(RVA_MESSAGEMANAGER_RECEIVEMESSAGE);
    if (!g_base) {
        [out appendString:@"game not found"];
        return out;
    }

    g_target = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;
    [out appendFormat:@"base: %p\ntarget: %p\n", (void *)g_base, (void *)g_target];

    g_orig = (recv_fn)brk_original_ptr((void *)g_target);

    bool ok = brk_install((void *)g_target, (void *)&recv_hook);
    [out appendFormat:@"install: %s\n", ok ? @"OK" : @"FAIL"];
    [out appendString:ok ? @"waiting for msgs" : @"no slots"];

    log_line([NSString stringWithFormat:@"=== armed ===\n%@", out]);
    return out;
}

static UIViewController *top_vc(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindow *w = ((UIWindowScene *)scene).keyWindow;
        if (w.rootViewController) return w.rootViewController;
    }
    return nil;
}

static void show_alert_once(void) {
    if (g_alert_shown) return;
    g_alert_shown = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = top_vc();
        if (!root) return;

        NSString *msg = [NSString stringWithFormat:
            @"%@\n\nslots: %d\ntarget: %p\n\nlog: Documents/Titanox.log",
            g_status, brk_slot_limit(), (void *)g_target];

        UIAlertController *a = [UIAlertController
            alertControllerWithTitle:@"Titanox armed" message:msg
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
        g_status = arm_hook();
        show_alert_once();
    });
}