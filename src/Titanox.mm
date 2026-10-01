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

#define LOG_MAX_BYTES (512 * 1024)

#define RVA_MM_RECEIVEMESSAGE        0x7bace8
#define RVA_HOMEMODE_GETINSTANCE     0x95f488
#define RVA_GUI_GETINSTANCE          0x5914b4
#define RVA_GUI_SHOWFLOATER_TEXTAT   0x591f28
#define RVA_GUI_SHOWFLOATER_DEFPOS   0x818cdc
#define RVA_GUI_GETFLOATER_DEFPOS    0x591d34
#define RVA_SPRITE_ADDCHILD          0xc2d8c4
#define RVA_STAGE_ADDCHILD           0xc33690

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_recv = 0;
static volatile int g_hits_home = 0;
static volatile int g_hits_floater = 0;
static volatile int g_hits_floater_def = 0;
static volatile int g_hits_floater_pos = 0;
static volatile int g_hits_sprite = 0;
static volatile int g_hits_stage = 0;
static volatile int g_lobby_welcome_done = 0;
static volatile int g_floater_attempts = 0;
static volatile int g_floater_success = 0;
static volatile int g_floater_fail = 0;

static uintptr_t g_addr_recv = 0;
static uintptr_t g_addr_home = 0;
static uintptr_t g_addr_gui_get = 0;
static uintptr_t g_addr_floater = 0;
static uintptr_t g_addr_floater_def = 0;
static uintptr_t g_addr_floater_pos = 0;
static uintptr_t g_addr_sprite_add = 0;
static uintptr_t g_addr_stage_add = 0;

static void (*g_orig_recv)(void*, void*) = NULL;
static void* (*g_orig_home)(void) = NULL;

typedef void* (*gui_get_t)(void);
typedef void  (*gui_floater_t)(void*, void*, float, float);
typedef void  (*gui_floater_def_t)(void*, float);
typedef void* (*gui_defpos_t)(void*);

static gui_get_t          g_fn_gui_get = NULL;
static gui_floater_t      g_fn_floater = NULL;
static gui_floater_def_t  g_fn_floater_def = NULL;
static gui_defpos_t       g_fn_floater_pos = NULL;

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
        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
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

static NSString *hexdump(uintptr_t addr, int len) {
    if (!addr || len <= 0) return @"?";
    uint8_t b[128];
    if (len > (int)sizeof(b)) len = (int)sizeof(b);
    memcpy(b, (void*)addr, len);
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < len; i++) {
        [s appendFormat:@"%02x ", b[i]];
        if ((i + 1) % 16 == 0 && i + 1 < len) [s appendString:@"\n            "];
    }
    return s;
}

static NSString *describe_op0(uintptr_t addr) {
    if (!addr) return @"null";
    uint32_t w = *(uint32_t*)addr;
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
    uint32_t w0 = *(uint32_t*)addr;
    uint32_t w1 = *(uint32_t*)(addr + 4);
    uint32_t w2 = *(uint32_t*)(addr + 8);
    uint32_t w3 = *(uint32_t*)(addr + 12);
    return [NSString stringWithFormat:
        @"addr=%p op=%08x %08x %08x %08x  desc=%@",
        (void*)addr, w0, w1, w2, w3, describe_op0(addr)];
}

static int read_msg_id(void *msg) {
    if (!msg) return 0;
    void **vt = *(void ***)msg;
    if (!vt) return 0;
    void *fn = *(void **)((uint8_t *)vt + 0x28);
    if (!fn) return 0;
    typedef int (*msgid_fn_t)(void *);
    return ((msgid_fn_t)fn)(msg);
}

static void* make_sc_string(const char *utf8) {
    if (!utf8) return NULL;
    size_t blen = strlen(utf8);
    uint8_t *buf = (uint8_t*)malloc(40);
    if (!buf) return NULL;
    memset(buf, 0, 40);
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
    g_floater_attempts++;
    if (!text) { g_floater_fail++; return; }

    tlog([NSString stringWithFormat:@"FLOATER_AT try: '%s' at (%.1f,%.1f)", text, x, y]);

    if (!g_fn_gui_get) { tlog(@"  fail: gui_get NULL"); g_floater_fail++; return; }
    if (!g_fn_floater) { tlog(@"  fail: floater NULL"); g_floater_fail++; return; }

    void *gui = g_fn_gui_get();
    tlog([NSString stringWithFormat:@"  gui = %p", gui]);
    if (!gui) { tlog(@"  fail: gui NULL"); g_floater_fail++; return; }

    void *sc = make_sc_string(text);
    tlog([NSString stringWithFormat:@"  sc = %p", sc]);
    if (!sc) { tlog(@"  fail: sc NULL");  g_floater_fail++; return; }

    @try2 {
        g_fn_floater(gui, * sc, x, y);
        tlog(@" NS  called (gui, sc, x, yEC)");
        g_floater_success++;
    } @catch (NSException *e) {
        tlog([NSString stringWithFormat:@"  EXCEPTION: %@_PER", e.reason]);
        g_floater_fail++;
    }
}

static void show_floater_default(const char *text, float duration) {
    g_floater_attempts++;
    if (!text) { g_floater_fail++; return; }

    tlog([NSString stringWithFormat:@"FLOATER_DEF try: '%s' dur=%.1f", text, duration]);

    if (!g_fn_floater_def) { tlog(@"  fail: floater_def NULL"); g_floater_fail++; return; }

    void *sc = make_sc_string(text);
    tlog([NSString stringWithFormat:@"  sc = %p", sc]);
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
    tlog(@"=== try_all_floater_variants ===");
    tlog(@"variant A: showFloaterTextAt(gui, text, 0, 0)");
    show_floater_at(text, 0.0f, 0.0f);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,_SEC),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant B: showFloaterTextAt(gui, text, -1, -1)");
        show_floater_at(text, -1.0f, -1.0f);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant C: showFloaterTextAtDefaultPos(text, -1)");
        show_floater_default(text, -1.0f);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant D: showFloaterTextAtDefaultPos(text, 3.0)");
        show_floater_default(text, 3.0f);
    });
}

static void h_recv(void *self, void *msg) {
    g_hits_recv++;
    int id = read_msg_id(msg);
    int sub = msg ? *(int *)((uint8_t *)msg + 0x90) : -1;
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
        tlog(@"lobby detected, firing floater test");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            try_all_floater_variants("Tale Stars iOS test");
        });
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

static void h_floater_pos(void) {
    g_hits_floater_pos++;
    if (g_hits_floater_pos <= 10) {
        tlog([NSString stringWithFormat:@"FLOATER_POS_CALL #%d", g_hits_floater_pos]);
    }
}

static void h_sprite(void) {
    g_hits_sprite++;
    if (g_hits_sprite <= 10) {
        tlog([NSString stringWithFormat:@"SPRITE_ADDCHILD #%d", g_hits_sprite]);
    }
}

static void h_stage(void) {
    g_hits_stage++;
    if (g_hits_stage <= 10) {
        tlog([NSString stringWithFormat:@"STAGE_ADDCHILD #%d", g_hits_stage]);
    }
}

static void setup(void) {
    tlog(@"");
    tlog(@"=== setup ===");
    tlog([NSString stringWithFormat:@"slots=%d selftest=%d",
          brk_slot_limit(), brk_selftest()]);

    if (!find_game_image(&g_base)) {
        tlog(@"game not found");
        return;
    }
    tlog([NSString stringWithFormat:@"base=%p", (void *)g_base]);

    g_addr_recv         = g_base + RVA_MM_RECEIVEMESSAGE;
    g_addr_home         = g_base + RVA_HOMEMODE_GETINSTANCE;
    g_addr_gui_get      = g_base + RVA_GUI_GETINSTANCE;
    g_addr_floater      = g_base + RVA_GUI_SHOWFLOATER_TEXTAT;
    g_addr_floater_def  = g_base + RVA_GUI_SHOWFLOATER_DEFPOS;
    g_addr_floater_pos  = g_base + RVA_GUI_GETFLOATER_DEFPOS;
    g_addr_sprite_add   = g_base + RVA_SPRITE_ADDCHILD;
    g_addr_stage_add    = g_base + RVA_STAGE_ADDCHILD;

    tlog([NSString stringWithFormat:@"recv       %@", dump_target(g_addr_recv)]);
    tlog([NSString stringWithFormat:@"home       %@", dump_target(g_addr_home)]);
    tlog([NSString stringWithFormat:@"gui_get    %@", dump_target(g_addr_gui_get)]);
    tlog([NSString stringWithFormat:@"floater    %@", dump_target(g_addr_floater)]);
    tlog([NSString stringWithFormat:@"floaterD   %@", dump_target(g_addr_floater_def)]);
    tlog([NSString stringWithFormat:@"floaterPos %@", dump_target(g_addr_floater_pos)]);
    tlog([NSString stringWithFormat:@"spriteAdd  %@", dump_target(g_addr_sprite_add)]);
    tlog([NSString stringWithFormat:@"stageAdd   %@", dump_target(g_addr_stage_add)]);

    tlog(@"hexdump recv:");
    tlog(hexdump(g_addr_recv, 32));
    tlog(@"hexdump gui_get:");
    tlog(hexdump(g_addr_gui_get, 32));
    tlog(@"hexdump floater:");
    tlog(hexdump(g_addr_floater, 32));
    tlog(@"hexdump floaterD:");
    tlog(hexdump(g_addr_floater_def, 32));

    g_fn_gui_get      = (gui_get_t)g_addr_gui_get;
    g_fn_floater      = (gui_floater_t)g_addr_floater;
    g_fn_floater_def  = (gui_floater_def_t)g_addr_floater_def;
    g_fn_floater_pos  = (gui_defpos_t)g_addr_floater_pos;

    g_orig_recv = (void (*)(void*, void*))brk_original_ptr((void *)g_addr_recv);
    bool ok1 = brk_install((void *)g_addr_recv, (void *)&h_recv);
    tlog([NSString stringWithFormat:@"install recv       ok=%d", ok1 ? 1 : 0]);

    g_orig_home = (void* (*)(void))brk_original_ptr((void *)g_addr_home);
    bool ok2 = brk_install((void *)g_addr_home, (void *)&h_home);
    tlog([NSString stringWithFormat:@"install home       ok=%d", ok2 ? 1 : 0]);

    bool ok3 = brk_install((void *)g_addr_floater, (void *)&h_floater);
    tlog([NSString stringWithFormat:@"install floater    ok=%d", ok3 ? 1 : 0]);

    bool ok4 = brk_install((void *)g_addr_floater_def, (void *)&h_floater_def);
    tlog([NSString stringWithFormat:@"install floaterD   ok=%d", ok4 ? 1 : 0]);

    bool ok5 = brk_install((void *)g_addr_sprite_add, (void *)&h_sprite);
    tlog([NSString stringWithFormat:@"install spriteAdd  ok=%d", ok5 ? 1 : 0]);

    tlog(@"setup done");
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
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = top_vc();
        if (!root) return;
        NSString *msg = [NSString stringWithFormat:
            @"base=%p\nrecv=%d home=%d\nfloater=%d floaterD=%d pos=%d\n"
            @"sprite=%d stage=%d\n"
            @"floater tries=%d ok=%d fail=%d\nslots=%d",
            (void *)g_base,
            g_hits_recv, g_hits_home,
            g_hits_floater, g_hits_floater_def, g_hits_floater_pos,
            g_hits_sprite, g_hits_stage,
            g_floater_attempts, g_floater_success, g_floater_fail,
            brk_slot_limit()];
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
        setup();
        show_stats(@"armed");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @10s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        tlog(@"forced variant test at 25s");
        try_all_floater_variants("Forced Test");
        show_stats(@"stats @25s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @55s");
    });
}