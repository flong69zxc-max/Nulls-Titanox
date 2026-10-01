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
#import <ptrauth.h>
#import "libtitanox.h"
#import "offsets.h"

#define LOG_MAX_BYTES (100 * 1024)

static uintptr_t g_base = 0;
static char g_path[512] = {0};
static FILE *g_log = NULL;
static long g_log_written = 0;

static uintptr_t g_stage_real = 0;
static uintptr_t g_recv_real = 0;
static uintptr_t g_ldt_init_real = 0;
static uintptr_t g_char_ctor_real = 0;
static uintptr_t g_font_fmt_real = 0;
static uintptr_t g_mc_ctor_real = 0;

static volatile int g_hits_stage = 0;
static volatile int g_hits_recv = 0;
static volatile int g_hits_ldt_init = 0;
static volatile int g_hits_char_ctor = 0;
static volatile int g_hits_font_fmt = 0;
static volatile int g_hits_mc_ctor = 0;
static volatile int g_installed = 0;

static void log_raw(const char *s) {
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

static void log_line(NSString *s) {
    if (!s) return;
    log_raw(s.UTF8String);
}

static uintptr_t decode_bl(uintptr_t thunk_addr, uint32_t opcode) {
    if ((opcode & 0xFC000000) != 0x94000000) return 0;
    int32_t imm26 = opcode & 0x03FFFFFF;
    int64_t offset = (int64_t)(imm26 << 2);
    if (offset & (1LL << 27)) offset |= ~((1LL << 28) - 1);
    return (uintptr_t)((int64_t)thunk_addr + offset);
}

static uintptr_t resolve_thunk(uintptr_t base, uint64_t rva, const char *name) {
    uintptr_t thunk = base + rva;
    uint32_t op2 = *(volatile uint32_t *)(thunk + 8);
    uintptr_t real = decode_bl(thunk + 8, op2);
    if (real) {
        log_line([NSString stringWithFormat:@"%s thunk=%p real=%p",
                  name, (void *)thunk, (void *)real]);
        return real;
    }
    log_line([NSString stringWithFormat:@"%s rva=0x%llx not a thunk", name, rva]);
    return thunk;
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

static void log_target_info(const char *name, uintptr_t addr) {
    uint32_t op0 = *(volatile uint32_t *)addr;
    uint32_t op1 = *(volatile uint32_t *)(addr + 4);
    log_line([NSString stringWithFormat:
              @"%@ addr=%p op0=%08x op1=%08x",
              [NSString stringWithUTF8String:name],
              (void *)addr, op0, op1]);
}

static void h_stage(void *a, void *b, void *c, void *d) {
    g_hits_stage++;
    log_line([NSString stringWithFormat:@"STAGE #%d self=%p", g_hits_stage, a]);
}
static void h_ldt_init(void *a, int b, void *c) {
    g_hits_ldt_init++;
    log_line([NSString stringWithFormat:@"LDT_INIT #%d idx=%d", g_hits_ldt_init, b]);
}
static void h_char_ctor(void *a, void *b, void *c, void *d) {
    g_hits_char_ctor++;
    log_line([NSString stringWithFormat:@"CHAR #%d self=%p", g_hits_char_ctor, a]);
}
static void h_font_fmt(void *a, void *b, void *c) {
    g_hits_font_fmt++;
    log_line([NSString stringWithFormat:@"FMT #%d self=%p", g_hits_font_fmt, a]);
}
static void h_mc_ctor(void *a, void *b) {
    g_hits_mc_ctor++;
    log_line([NSString stringWithFormat:@"MC #%d self=%p", g_hits_mc_ctor, a]);
}
static void h_recv(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits_recv++;
    uint32_t msgId = 0;
    if (msg) memcpy(&msgId, msg, 4);
    log_line([NSString stringWithFormat:@"RECV #%d msg=%p id=0x%x",
              g_hits_recv, msg, msgId]);
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

    g_stage_real     = resolve_thunk(g_base, RVA_STAGE_SETVIEWPORT, "stage");
    g_recv_real      = resolve_thunk(g_base, RVA_MESSAGEMANAGER_RECEIVEMESSAGE, "recv");
    g_ldt_init_real  = resolve_thunk(g_base, RVA_LOGICDATATABLES_INITDATATABLE, "ldt_init");
    g_char_ctor_real = resolve_thunk(g_base, RVA_CHARACTER_CTOR, "char_ctor");
    g_font_fmt_real  = resolve_thunk(g_base, RVA_NATIVEFONT_FORMATSTRING, "font_fmt");
    g_mc_ctor_real   = resolve_thunk(g_base, RVA_MOVIECLIP_CTOR, "mc_ctor");

    log_target_info("stage", g_stage_real);
    log_target_info("recv", g_recv_real);
    log_target_info("ldt_init", g_ldt_init_real);
    log_target_info("char_ctor", g_char_ctor_real);
    log_target_info("font_fmt", g_font_fmt_real);
    log_target_info("mc_ctor", g_mc_ctor_real);

    int ok = 0;
    if (brk_install((void *)g_stage_real, (void *)&h_stage)) { ok++; log_line(@"i stage"); } else log_line(@"x stage");
    if (brk_install((void *)g_recv_real, (void *)&h_recv)) { ok++; log_line(@"i recv"); } else log_line(@"x recv");
    if (brk_install((void *)g_ldt_init_real, (void *)&h_ldt_init)) { ok++; log_line(@"i ldt_init"); } else log_line(@"x ldt_init");
    if (brk_install((void *)g_char_ctor_real, (void *)&h_char_ctor)) { ok++; log_line(@"i char_ctor"); } else log_line(@"x char_ctor");
    if (brk_install((void *)g_font_fmt_real, (void *)&h_font_fmt)) { ok++; log_line(@"i font_fmt"); } else log_line(@"x font_fmt");
    if (brk_install((void *)g_mc_ctor_real, (void *)&h_mc_ctor)) { ok++; log_line(@"i mc_ctor"); } else log_line(@"x mc_ctor");

    g_installed = ok;
    log_line([NSString stringWithFormat:@"installed %d/6", ok]);
    log_line(@"setup done");
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
            @"installed: %d/6\n\n"
            @"stage:    %d\nrecv:     %d\nldt_init: %d\nchar:     %d\nfmt:      %d\nmc:       %d\n\n"
            @"log: %ld / %d B\n\n"
            @"log: Documents/Titanox.log",
            g_installed,
            g_hits_stage, g_hits_recv, g_hits_ldt_init,
            g_hits_char_ctor, g_hits_font_fmt, g_hits_mc_ctor,
            g_log_written, LOG_MAX_BYTES];

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
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}