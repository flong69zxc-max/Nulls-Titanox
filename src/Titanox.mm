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
#import "lc_detect.h"

extern "C" {
bool brk_chain_active(void);
bool brk_host_is_livecontainer(void);
mach_port_t brk_previous_port(void);
uint64_t brk_chain_counters(uint64_t *fails);
void brk_teardown(void);
void brk_log_state(void);
}

#define LOG_MAX_BYTES (512 * 1024)

#define RVA_MM_RECEIVEMESSAGE        0x7bace8
#define RVA_HOMEMODE_GETINSTANCE     0x95f488
#define RVA_GUI_GETINSTANCE          0x5914b4
#define RVA_GUI_SHOWFLOATER_TEXTAT   0x591f28
#define RVA_GUI_SHOWFLOATER_DEFPOS   0x818cdc
#define RVA_SPRITE_ADDCHILD          0xc2d8c4
#define RVA_STAGE_ADDCHILD           0xc33690

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_recv = 0;
static volatile int g_hits_home = 0;
static volatile int g_hits_floater = 0;
static volatile int g_hits_floater_def = 0;
static volatile int g_hits_sprite = 0;
static volatile int g_lobby_welcome_done = 0;
static volatile int g_floater_attempts = 0;
static volatile int g_floater_success = 0;
static volatile int g_floater_fail = 0;

static uintptr_t g_addr_recv = 0;
static uintptr_t g_addr_home = 0;
static uintptr_t g_addr_gui_get = 0;
static uintptr_t g_addr_floater = 0;
static uintptr_t g_addr_floater_def = 0;
static uintptr_t g_addr_sprite_add = 0;
static uintptr_t g_addr_stage_add = 0;

static void (*g_orig_recv)(void*, void*) = NULL;
static void* (*g_orig_home)(void) = NULL;

typedef void* (*gui_get_t)(void);
typedef void  (*gui_floater_t)(void*, void*, float, float);
typedef void  (*gui_floater_def_t)(void*, float);

static gui_get_t          g_fn_gui_get = NULL;
static gui_floater_t      g_fn_floater = NULL;
static gui_floater_def_t  g_fn_floater_def = NULL;

static BOOL g_lc = NO;
static BOOL g_aggressive = YES;
static volatile int g_setup_done = 0;
static volatile int g_valid_recv = 0;
static volatile int g_valid_home = 0;
static volatile int g_valid_gui = 0;

static void tlog_raw(const char *s) {
    if (!s) return;
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
    if (!out_base) return NO;

    uint32_t count = _dyld_image_count();
    if (count > 8192) count = 8192;

    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        const struct mach_header_64 *header =
            (const struct mach_header_64 *)_dyld_get_image_header(i);

        if (!path || !header) continue;
        if (!tnx_addr_readable((uintptr_t)header, sizeof(struct mach_header_64))) continue;
        if (header->magic != MH_MAGIC_64) continue;

        if (strstr(path, "/System/")) continue;
        if (strstr(path, "/usr/lib/")) continue;
        if (strstr(path, ".framework/")) continue;
        if (strstr(path, ".dylib")) continue;
        if (tnx_name_marks_host_runtime(path)) continue;
        if (!strstr(path, ".app/")) continue;

        if (header->ncmds == 0 || header->ncmds > 4096) continue;
        if (!tnx_image_text_contains((uintptr_t)header, (uintptr_t)header + 0x4000)) continue;

        *out_base = (uintptr_t)header;
        return YES;
    }

    return NO;
}

static NSString *hexdump(uintptr_t addr, int len) {
    if (!addr || len <= 0) return @"?";
    uint8_t b[128];
    if (len > (int)sizeof(b)) len = (int)sizeof(b);
    if (!tnx_addr_readable(addr, (size_t)len)) return @"<unreadable>";

    vm_size_t got = 0;
    kern_return_t kr = vm_read_overwrite(
        mach_task_self(),
        (vm_address_t)addr,
        (vm_size_t)len,
        (vm_address_t)b,
        &got
    );

    if (kr != KERN_SUCCESS || got == 0) return @"<unreadable>";

    NSMutableString *s = [NSMutableString string];
    for (vm_size_t i = 0; i < got; i++) {
        [s appendFormat:@"%02x ", b[i]];
        if ((i + 1) % 16 == 0 && i + 1 < got) [s appendString:@"\n            "];
    }
    return s;
}

static NSString *describe_op0(uintptr_t addr) {
    if (!addr) return @"null";

    uint32_t w = 0;
    if (!tnx_read_u32(addr, &w)) return @"unreadable";

    if ((w & 0xFFE0001F) == 0xD65F0000) return @"RET";
    if (w == 0xD503201F) return @"NOP";
    if (w == 0xD503237F) return @"PACIBSP";
    if (w == 0xD503233F) return @"PACIASP";
    if ((w & 0xFFC07FFF) == 0xA9807BFD) return @"STP x29,x30,[sp,#-N]!";
    if ((w & 0xFF8003FF) == 0xD10003FF) return @"SUB sp,sp,#N";
    if ((w & 0xFC000000) == 0x14000000) return @"B imm";
    if ((w & 0xFC000000) == 0x94000000) return @"BL imm";
    if ((w & 0x9F000000) == 0x90000000) return @"ADRP";
    if ((w & 0xFFC00000) == 0xB9400000) return @"LDR w";
    if ((w & 0xFFC00000) == 0xF9400000) return @"LDR x";
    if ((w & 0xFFE0001F) == 0xD61F0000) return @"BR";
    if ((w & 0xFFE0001F) == 0xD63F0000) return @"BLR";
    if ((w & 0x7F800000) == 0x52800000) return @"MOVZ w";
    if ((w & 0x7F800000) == 0x52A00000) return @"MOVZ w (shift)";
    if ((w & 0xFF800000) == 0xAA000000) return @"ORR/MOV";
    return [NSString stringWithFormat:@"raw=0x%08x", w];
}

static NSString *dump_target(uintptr_t addr) {
    if (!addr) return @"null";

    uint32_t w[4] = {0, 0, 0, 0};

    for (int i = 0; i < 4; i++) {
        if (!tnx_read_u32(addr + (uintptr_t)(4 * i), &w[i])) return @"unreadable";
    }

    return [NSString stringWithFormat:
        @"addr=%p op=%08x %08x %08x %08x  desc=%@",
        (void*)addr, w[0], w[1], w[2], w[3], describe_op0(addr)];
}

static int read_msg_id(void *msg) {
    if (!msg) return 0;

    uintptr_t msgAddr = (uintptr_t)msg;
    if (!tnx_addr_readable(msgAddr, 0x10)) return 0;

    uintptr_t vt = 0;
    if (!tnx_read_pointer(msgAddr, &vt)) return 0;
    if (!vt) return 0;
    if (!tnx_addr_readable(vt + 0x28, sizeof(uintptr_t))) return 0;

    uintptr_t fn = 0;
    if (!tnx_read_pointer(vt + 0x28, &fn)) return 0;
    if (!fn || !tnx_addr_executable(fn)) return 0;

    typedef int (*msgid_fn_t)(void *);
    return ((msgid_fn_t)fn)(msg);
}

static void* make_sc_string(const char *utf8) {
    if (!utf8) return NULL;
    size_t blen = strlen(utf8);
    uint8_t *buf = (uint8_t*)malloc(16);
    if (!buf) return NULL;
    memset(buf, 0, 16);

    *(uint32_t*)(buf + 0) = (uint32_t)blen;
    *(uint32_t*)(buf + 4) = (uint32_t)blen;

    if (blen > 7) {
        uint8_t *data = (uint8_t*)malloc(blen + 1);
        if (!data) { free(buf); return NULL; }
        memcpy(data, utf8, blen);
        data[blen] = 0;
        *(void**)(buf + 8) = data;
    } else {
        memcpy(buf + 8, utf8, blen);
    }
    return buf;
}

static void show_floater_at(const char *text, float x, float y) {
    if (!g_aggressive) return;
    if (g_setup_done != 2) { tlog(@"FLOATER_AT skipped: setup not verified"); return; }

    g_floater_attempts++;
    if (!text) { g_floater_fail++; return; }

    tlog([NSString stringWithFormat:@"FLOATER_AT try: '%s' at (%.1f,%.1f)", text, x, y]);

    if (!g_valid_gui) { tlog(@"  fail: gui_get target rejected"); g_floater_fail++; return; }
    if (!g_fn_gui_get) { tlog(@"  fail: gui_get NULL"); g_floater_fail++; return; }

    void *gui = g_fn_gui_get();
    tlog([NSString stringWithFormat:@"  gui = %p", gui]);

    if (!tnx_object_plausible(gui)) {
        tlog(@"  fail: gui object rejected");
        g_floater_fail++;
        return;
    }

    if (!g_fn_floater) { tlog(@"  fail: floater NULL"); g_floater_fail++; return; }

    void *sc = make_sc_string(text);
    tlog([NSString stringWithFormat:@"  sc = %p", sc]);
    if (sc) {
        tlog([NSString stringWithFormat:@"  sc bytes: %@", hexdump((uintptr_t)sc, 24)]);
    }
    if (!sc) { tlog(@"  fail: sc NULL"); g_floater_fail++; return; }

    @try {
        g_fn_floater(gui, sc, x, y);
        tlog(@"  called (gui, sc, x, y)");
        g_floater_success++;
    } @catch (NSException *e) {
        tlog([NSString stringWithFormat:@"  EXCEPTION: %@", e.reason]);
        g_floater_fail++;
    }
}

static void show_floater_default(const char *text, float duration) {
    if (!g_aggressive) return;
    if (g_setup_done != 2) { tlog(@"FLOATER_DEF skipped: setup not verified"); return; }

    g_floater_attempts++;
    if (!text) { g_floater_fail++; return; }

    tlog([NSString stringWithFormat:@"FLOATER_DEF try: '%s' dur=%.1f", text, duration]);

    if (!g_fn_floater_def) { tlog(@"  fail: floater_def NULL"); g_floater_fail++; return; }

    void *sc = make_sc_string(text);
    tlog([NSString stringWithFormat:@"  sc = %p", sc]);
    if (sc) {
        tlog([NSString stringWithFormat:@"  sc bytes: %@", hexdump((uintptr_t)sc, 24)]);
    }
    if (!sc) { tlog(@"  fail: sc NULL"); g_floater_fail++; return; }

    @try {
        g_fn_floater_def(sc, duration);
        tlog(@"  called (sc, dur)");
        g_floater_success++;
    } @catch (NSException *e) {
        tlog([NSString stringWithFormat:@"  EXCEPTION: %@", e.reason]);
        g_floater_fail++;
    }
}

static void try_all_floater_variants(const char *text) {
    if (!g_aggressive) { tlog(@"try_all_floater_variants disabled"); return; }

    tlog(@"=== try_all_floater_variants ===");
    tlog(@"variant A: showFloaterTextAt(gui, text, 0, 0)");
    show_floater_at(text, 0.0f, 0.0f);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant B: showFloaterTextAt(gui, text, -1, -1)");
        show_floater_at(text, -1.0f, -1.0f);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant C: showFloaterTextAtDefaultPos(text, -1)");
        show_floater_default(text, -1.0f);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant D: showFloaterTextAtDefaultPos(text, 3.0)");
        show_floater_default(text, 3.0f);
    });
}

static void h_recv(void *self, void *msg) {
    g_hits_recv++;
    int id = read_msg_id(msg);
    int sub = -1;

    if (msg && tnx_addr_readable((uintptr_t)msg + 0x90, sizeof(int))) {
        sub = *(int *)((uint8_t *)msg + 0x90);
    }

    if (g_hits_recv <= 30) {
        tlog([NSString stringWithFormat:@"RECV #%d id=%d sub=%d",
              g_hits_recv, id, sub]);
    }
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg);
        brk_resume_self();
    }
}

static void* h_home(void) {
    g_hits_home++;
    void *res = NULL;
    if (g_orig_home) {
        brk_suspend_self();
        res = g_orig_home();
        brk_resume_self();
    }
    if (g_hits_home <= 5) {
        tlog([NSString stringWithFormat:@"HOME #%d -> %p", g_hits_home, res]);
    }
    if (!g_lobby_welcome_done) {
        g_lobby_welcome_done = 1;
        tlog(@"lobby detected");
        if (g_aggressive) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                try_all_floater_variants("Tale Stars iOS test");
            });
        }
    }
    return res;
}

static void h_floater(void) {
    g_hits_floater++;
    if (g_hits_floater <= 10) {
        tlog([NSString stringWithFormat:@"FLOATER_CALL #%d", g_hits_floater]);
    }
}

static void h_floater_def(void) {
    g_hits_floater_def++;
    if (g_hits_floater_def <= 10) {
        tlog([NSString stringWithFormat:@"FLOATER_DEF_CALL #%d", g_hits_floater_def]);
    }
}

static void h_sprite(void) {
    g_hits_sprite++;
    if (g_hits_sprite <= 10) {
        tlog([NSString stringWithFormat:@"SPRITE_ADDCHILD #%d", g_hits_sprite]);
    }
}

static BOOL arm_target(const char *label, uintptr_t address, void *replacement, BOOL *wasValid) {
    if (!address) {
        tlog([NSString stringWithFormat:@"install %-10s skipped: rva zero", label]);
        if (wasValid) *wasValid = NO;
        return NO;
    }

    BOOL valid = tnx_callable_target(g_base, address);
    if (wasValid) *wasValid = valid;

    if (!valid) {
        tlog([NSString stringWithFormat:
              @"install %-10s rejected addr=%p desc=%@",
              label, (void *)address, describe_op0(address)]);
        return NO;
    }

    BOOL ok = brk_install((void *)address, replacement) ? YES : NO;
    tlog([NSString stringWithFormat:@"install %-10s ok=%d", label, ok ? 1 : 0]);
    return ok;
}

static void setup(void) {
    tlog(@"");
    tlog(@"=== setup ===");
    tlog([NSString stringWithFormat:@"host=%@ aggressive=%d",
          tnx_host_description(), g_aggressive ? 1 : 0]);
    tlog([NSString stringWithFormat:@"brk host_lc=%d chain=%d previous_port=%u",
          brk_host_is_livecontainer() ? 1 : 0,
          brk_chain_active() ? 1 : 0,
          (unsigned)brk_previous_port()]);

    tlog([NSString stringWithFormat:@"slots=%d selftest=%d",
          brk_slot_limit(), brk_selftest()]);

    if (!g_base && !find_game_image(&g_base)) {
        tlog(@"game not found");
        return;
    }
    tlog([NSString stringWithFormat:@"base=%p", (void *)g_base]);

    g_addr_recv         = g_base + RVA_MM_RECEIVEMESSAGE;
    g_addr_home         = g_base + RVA_HOMEMODE_GETINSTANCE;
    g_addr_gui_get      = g_base + RVA_GUI_GETINSTANCE;
    g_addr_floater      = g_base + RVA_GUI_SHOWFLOATER_TEXTAT;
    g_addr_floater_def  = g_base + RVA_GUI_SHOWFLOATER_DEFPOS;
    g_addr_sprite_add   = g_base + RVA_SPRITE_ADDCHILD;
    g_addr_stage_add    = g_base + RVA_STAGE_ADDCHILD;

    tlog([NSString stringWithFormat:@"recv       %@", dump_target(g_addr_recv)]);
    tlog([NSString stringWithFormat:@"home       %@", dump_target(g_addr_home)]);
    tlog([NSString stringWithFormat:@"gui_get    %@", dump_target(g_addr_gui_get)]);
    tlog([NSString stringWithFormat:@"floater    %@", dump_target(g_addr_floater)]);
    tlog([NSString stringWithFormat:@"floaterD   %@", dump_target(g_addr_floater_def)]);
    tlog([NSString stringWithFormat:@"spriteAdd  %@", dump_target(g_addr_sprite_add)]);
    tlog([NSString stringWithFormat:@"stageAdd   %@", dump_target(g_addr_stage_add)]);

    tlog(@"hexdump recv:");
    tlog(hexdump(g_addr_recv, 32));
    tlog(@"hexdump gui_get:");
    tlog(hexdump(g_addr_gui_get, 32));

    g_fn_gui_get      = (gui_get_t)g_addr_gui_get;
    g_fn_floater      = (gui_floater_t)g_addr_floater;
    g_fn_floater_def  = (gui_floater_def_t)g_addr_floater_def;

    BOOL valid = NO;

    g_orig_recv = (void (*)(void*, void*))brk_original_ptr((void *)g_addr_recv);
    arm_target("recv", g_addr_recv, (void *)&h_recv, &valid);
    g_valid_recv = valid ? 1 : 0;

    g_orig_home = (void* (*)(void))brk_original_ptr((void *)g_addr_home);
    arm_target("home", g_addr_home, (void *)&h_home, &valid);
    g_valid_home = valid ? 1 : 0;

    arm_target("floater", g_addr_floater, (void *)&h_floater, &valid);
    arm_target("floaterD", g_addr_floater_def, (void *)&h_floater_def, &valid);
    arm_target("spriteAdd", g_addr_sprite_add, (void *)&h_sprite, &valid);

    valid = tnx_callable_target(g_base, g_addr_gui_get);
    g_valid_gui = valid ? 1 : 0;

    if (!g_valid_gui) {
        g_fn_gui_get = NULL;
        tlog(@"gui_get target rejected, diagnostics disabled");
    }

    if (!g_valid_recv && !g_valid_home) {
        tlog(@"no hook target verified, setup incomplete");
        brk_log_state();
        return;
    }

    g_setup_done = 2;
    tlog(@"setup done");
    brk_log_state();
}

static UIViewController *top_vc(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindow *w = ((UIWindowScene *)scene).keyWindow;
        if (w.rootViewController) return w.rootViewController;
    }
    return nil;
}

static void show_stats(NSString *title) {
    NSString *msg = [NSString stringWithFormat:
        @"host=%@ base=%p\nrecv=%d home=%d\nfloater=%d floaterD=%d\nsprite=%d\n"
        @"floater tries=%d ok=%d fail=%d\nslots=%d chain=%d",
        tnx_host_description(),
        (void *)g_base,
        g_hits_recv, g_hits_home,
        g_hits_floater, g_hits_floater_def,
        g_hits_sprite,
        g_floater_attempts, g_floater_success, g_floater_fail,
        brk_slot_limit(),
        brk_chain_active() ? 1 : 0];

    tlog([NSString stringWithFormat:@"STATS %@ | %@",
          title, [msg stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]);

    if (g_lc) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = top_vc();
        if (!root) return;
        if (root.presentedViewController) return;

        UIAlertController *a = [UIAlertController
            alertControllerWithTitle:title message:msg
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:a animated:YES completion:nil];
    });
}

static void poll_for_game(int tick);

static void poll_for_game(int tick) {
    if (g_setup_done) return;

    if (tick > 240) {
        tlog(@"game image never stabilised, aborting");
        return;
    }

    uintptr_t base = 0;
    BOOL found = find_game_image(&base);

    static uint32_t lastCount = 0;
    static int stableTicks = 0;

    uint32_t count = _dyld_image_count();

    if (found && count == lastCount) {
        stableTicks++;
    } else {
        stableTicks = 0;
        lastCount = count;
    }

    if (found && stableTicks >= 4) {
        g_base = base;
        setup();
        show_stats(@"armed");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(tick + 1);
    });
}

__attribute__((constructor))
static void start(void) {
    const char *aggressive = getenv("TITANOX_AGGRESSIVE");

    g_lc = tnx_host_is_livecontainer();
    g_aggressive = g_lc ? NO : YES;

    if (aggressive) {
        g_aggressive = (aggressive[0] == '1') ? YES : NO;
    }

    tlog(@"=== titanox start ===");
    tlog([NSString stringWithFormat:@"host=%@ aggressive=%d",
          tnx_host_description(), g_aggressive ? 1 : 0]);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(0);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @20s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @45s");
        brk_log_state();
    });
}
