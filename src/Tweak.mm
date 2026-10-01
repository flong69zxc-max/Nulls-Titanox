#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
#import <string.h>
#import "libtitanox.h"
#import "offsets.h"

static uintptr_t g_base = 0;
static uintptr_t g_target = 0;
static volatile int g_hits = 0;
static unsigned char g_bytes[4] = {0, 0, 0, 0};
static NSString *g_status = @"";
static bool g_presented = false;
static bool g_reported_hit = false;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
static recv_fn g_orig = NULL;

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits++;
    if (g_orig == NULL) {
        return;
    }
    [TitanoxHook suspendBreakpoints];
    g_orig(self, msg, a, b, c, d);
    [TitanoxHook resumeBreakpoints];
}

static uintptr_t own_image(void) {
    Dl_info info;
    if (dladdr((void *)&recv_hook, &info) == 0) {
        return 0;
    }
    return (uintptr_t)info.dli_fbase;
}

static uintptr_t image_for_rva(uint64_t rva) {
    uintptr_t mine = own_image();
    uint32_t image_count = _dyld_image_count();
    for (uint32_t i = 0; i < image_count; i++) {
        const char *path = _dyld_get_image_name(i);
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (path == NULL || hdr == NULL || hdr->magic != MH_MAGIC_64) {
            continue;
        }
        if ((uintptr_t)hdr == mine) {
            continue;
        }
        if (strstr(path, "/System/") || strstr(path, "LiveContainer") || strstr(path, "TweakLoader")) {
            continue;
        }
        if (strstr(path, ".dylib") != NULL) {
            continue;
        }
        uint32_t cmd_count = hdr->ncmds;
        if (cmd_count > 1024) {
            cmd_count = 1024;
        }
        const struct load_command *cmd =
            (const struct load_command *)((const uint8_t *)hdr + sizeof(struct mach_header_64));
        uint64_t origin = 0;
        bool have_origin = false;
        for (uint32_t c = 0; c < cmd_count; c++) {
            if (cmd->cmdsize < sizeof(struct load_command)) {
                break;
            }
            if (cmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (const struct segment_command_64 *)cmd;
                if (!have_origin) {
                    origin = seg->vmaddr;
                    have_origin = true;
                }
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

    [out appendFormat:@"hw breakpoints: %d\n", [TitanoxHook breakpointSlotLimit]];
    [out appendFormat:@"selftest: %s\n", [TitanoxHook breakpointSelfTest] ? "pass" : "fail"];

    g_base = image_for_rva(RVA_MESSAGEMANAGER_RECEIVEMESSAGE);
    if (g_base == 0) {
        [out appendString:@"game image not found"];
        return out;
    }

    g_target = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;
    [out appendFormat:@"base: %p\ntarget: %p\n", (void *)g_base, (void *)g_target];

    if (![TitanoxHook readMemoryAt:g_target buffer:g_bytes size:sizeof(g_bytes)]) {
        [out appendString:@"target is not readable"];
        return out;
    }
    [out appendFormat:@"bytes: %02x %02x %02x %02x\n",
                      g_bytes[0], g_bytes[1], g_bytes[2], g_bytes[3]];

    g_orig = (recv_fn)[TitanoxHook originalPointerForBreakpoint:(void *)g_target];

    BOOL installed = [TitanoxHook addBreakpointAtAddress:(void *)g_target withHook:(void *)&recv_hook];
    [out appendFormat:@"hook: %s\n", installed ? "installed" : "failed"];
    [out appendString:installed ? @"send a packet in game" : @"no free slots or bad target"];

    return out;
}

static UIViewController *top_controller(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        UIWindow *window = ((UIWindowScene *)scene).keyWindow;
        if (window.rootViewController != nil) {
            return window.rootViewController;
        }
    }
    return nil;
}

static void show_status(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_hits > 0 && g_reported_hit) {
            return;
        }
        if (g_hits == 0 && g_presented) {
            return;
        }
        if (g_hits > 0) {
            g_reported_hit = true;
        }
        g_presented = true;

        UIViewController *root = top_controller();
        if (root == nil) {
            return;
        }

        for (UIViewController *vc in root.presentedViewControllers) {
            if ([vc isKindOfClass:UIAlertController.class]) {
                [(UIAlertController *)vc dismissViewControllerAnimated:NO completion:nil];
            }
        }

        NSString *title = g_hits > 0 ? @"Hook fired" : @"Hook armed";
        NSString *message = [NSString stringWithFormat:
            @"%@\n\nhw bp: %d\ntarget: %p\nbytes: %02x %02x %02x %02x\nhits: %d\noriginal: %s",
            g_status, [TitanoxHook breakpointSlotLimit], (void *)g_target,
            g_bytes[0], g_bytes[1], g_bytes[2], g_bytes[3],
            g_hits, g_orig != NULL ? "wired" : "missing"];

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:title
            message:message
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

__attribute__((constructor))
static void tweak_start(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        g_status = arm_hook();
        show_status();
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
            show_status();
        }];
    });
}
