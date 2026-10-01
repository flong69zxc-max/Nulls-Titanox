#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <libgen.h>
#import "libtitanox.h"
#import "offsets.h"

static uintptr_t g_base = 0;
static char g_path[512] = {0};
static FILE *g_log = NULL;

static volatile int g_hits_stage = 0;
static volatile int g_hits_gb = 0;
static volatile int g_hits_font = 0;
static volatile int g_hits_fmt = 0;
static volatile int g_hits_recv = 0;

static uintptr_t g_t_stage = 0;
static uintptr_t g_t_gb = 0;
static uintptr_t g_t_font = 0;
static uintptr_t g_t_fmt = 0;
static uintptr_t g_t_recv = 0;

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

static uint64_t text_vmaddr(uintptr_t base) {
    const struct mach_header_64 *h = (const struct mach_header_64 *)base;
    uint32_t nc = h->ncmds > 1024 ? 1024 : h->ncmds;
    const struct load_command *cmd =
        (const struct load_command *)((const uint8_t *)h + sizeof(struct mach_header_64));
    for (uint32_t c = 0; c < nc; c++) {
        if (cmd->cmdsize < sizeof(struct load_command)) break;
        if (cmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)cmd;
            if (strcmp(seg->segname, "__TEXT") == 0) return seg->vmaddr;
        }
        cmd = (const struct load_command *)((const uint8_t *)cmd + cmd->cmdsize);
    }
    return 0;
}

static void dump_segments(uintptr_t base) {
    const struct mach_header_64 *h = (const struct mach_header_64 *)base;
    uint32_t nc = h->ncmds > 1024 ? 1024 : h->ncmds;
    const struct load_command *cmd =
        (const struct load_command *)((const uint8_t *)h + sizeof(struct mach_header_64));
    for (uint32_t c = 0; c < nc; c++) {
        if (cmd->cmdsize < sizeof(struct load_command)) break;
        if (cmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)cmd;
            log_line([NSString stringWithFormat:
                @"seg %-16s vmaddr=0x%llx vmsize=0x%llx prot=%c%c%c",
                seg->segname,
                seg->vmaddr, seg->vmsize,
                (seg->initprot & VM_PROT_READ) ? 'r' : '-',
                (seg->initprot & VM_PROT_WRITE) ? 'w' : '-',
                (seg->initprot & VM_PROT_EXECUTE) ? 'x' : '-']);
        }
        cmd = (const struct load_command *)((const uint8_t *)cmd + cmd->cmdsize);
    }
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

static void font_hook(void *self, void *a2) {
    g_hits_font++;
    if (g_hits_font <= 3 || (g_hits_font % 100 == 0)) {
        log_line([NSString stringWithFormat:@"FONT #%d self=%p", g_hits_font, self]);
    }
}

static void fmt_hook(void *self, void *out, void *fmt) {
    g_hits_fmt++;
    if (g_hits_fmt <= 3 || (g_hits_fmt % 100 == 0)) {
        log_line([NSString stringWithFormat:@"FMT #%d self=%p", g_hits_fmt, self]);
    }
}

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits_recv++;
    if (g_hits_recv <= 3 || (g_hits_recv % 100 == 0)) {
        log_line([NSString stringWithFormat:@"RECV #%d msg=%p", g_hits_recv, msg]);
    }
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg, a, b, c, d);
        brk_resume_self();
    }
}

static void install_all(void) {
    log_line(@"=== arm ===");
    log_line([NSString stringWithFormat:@"slots=%d selftest=%d",
              brk_slot_limit(), brk_selftest()]);

    if (!find_game_image(&g_base, g_path, sizeof(g_path))) {
        log_line(@"game not found");
        return;
    }
    log_line([NSString stringWithFormat:@"base=%p path=%s", (void *)g_base, g_path]);

    uint64_t tv = text_vmaddr(g_base);
    log_line([NSString stringWithFormat:@"__TEXT.vmaddr=0x%llx", tv]);
    dump_segments(g_base);

    g_t_stage = g_base + RVA_STAGE_SETVIEWPORT;
    g_t_gb    = g_base + RVA_GAMEBUTTON_CTOR;
    g_t_font  = g_base + RVA_NATIVEFONT_CTOR;
    g_t_fmt   = g_base + RVA_NATIVEFONT_FORMATSTRING;
    g_t_recv  = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;

    g_orig_recv = (recv_fn)brk_original_ptr((void *)g_t_recv);

    int ok = 0;
    if (brk_install((void *)g_t_stage, (void *)&stage_hook))  { ok++; log_line(@"i stage ok"); }
    else log_line(@"i stage FAIL");
    if (brk_install((void *)g_t_gb,    (void *)&gb_hook))     { ok++; log_line(@"i gb ok"); }
    else log_line(@"i gb FAIL");
    if (brk_install((void *)g_t_font,  (void *)&font_hook))   { ok++; log_line(@"i font ok"); }
    else log_line(@"i font FAIL");
    if (brk_install((void *)g_t_fmt,   (void *)&fmt_hook))    { ok++; log_line(@"i fmt ok"); }
    else log_line(@"i fmt FAIL");
    if (brk_install((void *)g_t_recv,  (void *)&recv_hook))   { ok++; log_line(@"i recv ok"); }
    else log_line(@"i recv FAIL");

    log_line([NSString stringWithFormat:@"installed %d of 5 active=%d",
              ok, brk_active_count()]);

    log_line([NSString stringWithFormat:
        @"targets stage=%p gb=%p font=%p fmt=%p recv=%p",
        (void *)g_t_stage, (void *)g_t_gb, (void *)g_t_font,
        (void *)g_t_fmt, (void *)g_t_recv]);
}

static void rearm_tick(void) {
    if (!g_base) return;
    brk_install((void *)g_t_stage, (void *)&stage_hook);
    brk_install((void *)g_t_gb,    (void *)&gb_hook);
    brk_install((void *)g_t_font,  (void *)&font_hook);
    brk_install((void *)g_t_fmt,   (void *)&fmt_hook);
    brk_install((void *)g_t_recv,  (void *)&recv_hook);
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
            @"base: %p\npath: %s\nactive: %d / slots: %d\n\n"
            @"stage: %d\ngb:    %d\nfont:  %d\nfmt:   %d\nrecv:  %d\n\n"
            @"log: Documents/Titanox.log",
            (void *)g_base, basename(g_path),
            brk_active_count(), brk_slot_limit(),
            g_hits_stage, g_hits_gb, g_hits_font, g_hits_fmt, g_hits_recv];

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
        install_all();
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
            rearm_tick();
        }];
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}