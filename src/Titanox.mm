#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdio.h>
#import "libtitanox.h"
#import "offsets.h"

static uintptr_t g_base = 0;
static uintptr_t g_target = 0;
static volatile int g_hits = 0;
static NSString *g_status = @"";
static FILE *g_log = NULL;
static UILabel *g_toast = nil;
static BOOL g_alert_shown = NO;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
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

static void show_toast(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)s; break; }
        }
        if (!scene) return;

        if (!g_toast) {
            g_toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, 300, 44)];
            g_toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            g_toast.textColor = [UIColor systemGreenColor];
            g_toast.font = [UIFont boldSystemFontOfSize:18];
            g_toast.textAlignment = NSTextAlignmentCenter;
            g_toast.layer.cornerRadius = 10;
            g_toast.clipsToBounds = YES;
            g_toast.userInteractionEnabled = NO;
            [scene.keyWindow addSubview:g_toast];
        }
        g_toast.center = CGPointMake(scene.keyWindow.center.x, 120);
        g_toast.text = text;
        g_toast.alpha = 1.0;
        [scene.keyWindow bringSubviewToFront:g_toast];

        [UIView animateWithDuration:0.3 delay:1.5 options:0 animations:^{
            g_toast.alpha = 0;
        } completion:nil];
    });
}

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits++;
    uint32_t msgId = 0;
    if (msg) memcpy(&msgId, msg, 4);
    log_line([NSString stringWithFormat:@"hit #%d self=%p msg=%p id=0x%x",
              g_hits, self, msg, msgId]);
    show_toast([NSString stringWithFormat:@"привет  (%d)", g_hits]);
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

    int slots = brk_slot_limit();
    [out appendFormat:@"slots: %d\n", slots];
    [out appendFormat:@"selftest: %s\n", brk_selftest() ? "pass" : "fail"];

    g_base = image_for_rva(RVA_MESSAGEMANAGER_RECEIVEMESSAGE);
    if (!g_base) {
        [out appendString:@"game image not found"];
        return out;
    }

    g_target = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;
    [out appendFormat:@"base: %p\ntarget: %p\n", (void *)g_base, (void *)g_target];

    g_orig = (recv_fn)brk_original_ptr((void *)g_target);

    bool ok = brk_install((void *)g_target, (void *)&recv_hook);
    [out appendFormat:@"install: %s\n", ok ? "OK" : "FAIL"];
    [out appendString:ok ? @"send a packet in game" : @"no slots or bad target"];

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

        NSString *title = g_hits > 0 ? @"HOOK FIRED" : @"Hook armed";
        NSString *msg = [NSString stringWithFormat:
            @"%@\n\nslots: %d\ntarget: %p\nhits: %d\norig: %p\n\nlog: Documents/Titanox.log",
            g_status, brk_slot_limit(), (void *)g_target, g_hits, (void *)g_orig];

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
        g_status = arm_hook();
        show_alert_once();
    });
}