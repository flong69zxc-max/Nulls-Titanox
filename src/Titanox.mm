#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach/arm/thread_status.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <unistd.h>
#import <time.h>
#import <math.h>
#import <libgen.h>
#import "libtitanox.h"
#import "offsets.h"
#import "lc_detect.h"

extern "C" {
bool brk_install(void *target, void *replacement);
void *brk_original_ptr(void *target);
bool brk_remove(void *target);
bool brk_selftest(void);
bool brk_selftest_at(uintptr_t hint);
int brk_slot_limit(void);
int brk_active_count(void);
void brk_log_state(void);
void hook_note_hit(void *target);
bool hook_verify_encryption(void *image);
void hook_log_prot(const char *label, uintptr_t address);
void hook_set_error(const char *format, ...);
const char *hook_last_error(void);
bool brk_host_is_livecontainer(void);
void brk_teardown(void);
void brk_diag_log(const char *format, ...);
bool hook_code_patch_allowed(void);
int hook_pointer_count(void);
int hook_pointer_slots(void);
int hook_probe(uintptr_t target);
}

#define LOG_MAX_BYTES (512 * 1024)

#define TITANOX_BUILD_TAG "brk-a4 2026-10-02 ptrwide+pac+objchooks"

#define RVA_MM_RECEIVEMESSAGE            0x7bace8
#define RVA_HOMEMODE_GETINSTANCE         0x95f488
#define RVA_GAMESTATEMANAGER_GETINSTANCE 0x95dae4
#define RVA_GAMESTATEMANAGER_ISSTATE     0x95e7c0
#define RVA_GUI_GETINSTANCE              0x591644
#define RVA_GUI_SHOWFLOATER_TEXTAT       0x591f28
#define RVA_GUI_SHOWFLOATER_DEFPOS       0x818cdc
#define RVA_GUI_GETDEFAULTFLOATERPOS     0x591da0
#define RVA_GUI_SHOWPOPUP                0x592c24
#define RVA_SPRITE_ADDCHILD              0xc2d8c4
#define RVA_SPRITE_ADDCHILDAT            0xc2d8cc
#define RVA_SPRITE_REMOVECHILD           0xc2db9c
#define RVA_STAGE_ADDCHILD               0xc33690
#define RVA_TEXTFIELD_SETTEXT            0xc4a978

#define GUI_RETRY_COUNT 3
#define GUI_RETRY_NS 1000000L
#define GUI_LOG_LIMIT 20
#define GAME_POLL_MAX_TICKS 1200
#define GAME_POLL_STABLE_TICKS 3

typedef void  (*fn_msg_t)(void *, void *);
typedef void *(*fn_void_ret_t)(void);
typedef void *(*gui_get_t)(void);
typedef void  (*fn_gui_at_t)(void *, void *, float, float);
typedef void  (*fn_gui_def_t)(void *, void *, float);
typedef void  (*fn_sprite_t)(void *, void *);
typedef BOOL  (*fn_isstate_t)(void *, int);
typedef struct { float x; float y; } tnx_vec2_t;
typedef tnx_vec2_t (*fn_gui_pos_t)(void *);

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;

static volatile int g_hits_recv = 0;
static volatile int g_hits_home = 0;
static volatile int g_hits_floater = 0;
static volatile int g_hits_floater_def = 0;
static volatile int g_hits_sprite = 0;
static volatile int g_hits_stage = 0;
static volatile int g_hits_isstate = 0;
static volatile int g_lobby_welcome_done = 0;
static volatile int g_floater_attempts = 0;
static volatile int g_floater_success = 0;
static volatile int g_floater_fail = 0;
static volatile int g_gui_logged = 0;
static volatile int g_gui_generation = 0;
static volatile int g_gui_rejections = 0;
static volatile int g_last_game_state = -1;
static volatile int g_selftest_ok = 0;

static uintptr_t g_addr_recv = 0;
static uintptr_t g_addr_home = 0;
static uintptr_t g_addr_gui_get_primary = 0;
static uintptr_t g_addr_gui_get_alt = 0;
static uintptr_t g_addr_floater = 0;
static uintptr_t g_addr_floater_def = 0;
static uintptr_t g_addr_gui_pos = 0;
static uintptr_t g_addr_sprite_add = 0;
static uintptr_t g_addr_stage_add = 0;
static uintptr_t g_addr_isstate = 0;

static fn_msg_t      g_orig_recv = NULL;
static fn_void_ret_t g_orig_home = NULL;
static fn_gui_at_t   g_orig_floater = NULL;
static fn_gui_def_t  g_orig_floater_def = NULL;
static fn_sprite_t   g_orig_sprite = NULL;
static fn_sprite_t   g_orig_stage = NULL;
static fn_isstate_t  g_orig_isstate = NULL;

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

static volatile int g_reject_logged = 0;

static void note_reject(const char *path, const char *reason) {
    if (g_reject_logged >= 4) return;
    g_reject_logged++;
    tlog([NSString stringWithFormat:@"image candidate rejected: %s (%s)",
          path ? path : "?", reason]);
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
        if (!strstr(path, ".app/")) continue;
        if (strstr(path, "/System/")) { note_reject(path, "system"); continue; }
        if (strstr(path, "/usr/lib/")) { note_reject(path, "usr-lib"); continue; }
        if (strstr(path, ".framework/")) { note_reject(path, "framework"); continue; }
        if (strstr(path, ".dylib")) { note_reject(path, "dylib"); continue; }
        if (tnx_name_marks_host_runtime(path)) { note_reject(path, "host-runtime"); continue; }
        if (!tnx_addr_readable((uintptr_t)header, sizeof(struct mach_header_64))) {
            note_reject(path, "header-unreadable");
            continue;
        }
        if (header->magic != MH_MAGIC_64) { note_reject(path, "bad-magic"); continue; }
        if (header->ncmds == 0 || header->ncmds > 4096) { note_reject(path, "bad-ncmds"); continue; }

        uintptr_t slide = tnx_image_slide((uintptr_t)header);

        if (!tnx_image_text_contains((uintptr_t)header, (uintptr_t)header + 0x4000)) {
            note_reject(path, "text-check");
            continue;
        }

        tlog([NSString stringWithFormat:@"image accepted: %s base=%p slide=0x%llx",
              path, (void *)header, (unsigned long long)slide]);

        *out_base = (uintptr_t)header;
        return YES;
    }

    return NO;
}

static NSString *describe_op0(uintptr_t addr) {
    if (!addr) return @"null";

    uint32_t w = 0;
    if (!tnx_read_u32(addr, &w)) return @"unreadable";

    if ((w & 0xFFFFFC1F) == 0xD65F0000) return @"RET";
    if (w == 0xD503201F) return @"NOP";
    if (w == 0xD503237F) return @"PACIBSP";
    if (w == 0xD503233F) return @"PACIASP";
    if ((w & 0xFFC07FFF) == 0xA9807BFD) return @"STP x29,x30,[sp,#-N]!";
    if ((w & 0xFF8003FF) == 0xD10003FF) return @"SUB sp,sp,#N";
    if ((w & 0xFC000000) == 0x14000000) return @"B imm";
    if ((w & 0xFC000000) == 0x94000000) return @"BL imm";
    if ((w & 0x9F000000) == 0x90000000) return @"ADRP";
    if ((w & 0x9F000000) == 0x10000000) return @"ADR";
    if ((w & 0xFF000010) == 0x54000000) return @"B.cond";
    if ((w & 0x3B000000) == 0x18000000) return @"LDR literal";
    if ((w & 0xFFC00000) == 0xB9400000) return @"LDR w";
    if ((w & 0xFFC00000) == 0xF9400000) return @"LDR x";
    if ((w & 0xFFFFFC1F) == 0xD61F0000) return @"BR";
    if ((w & 0xFFFFFC1F) == 0xD63F0000) return @"BLR";
    if ((w & 0x7F800000) == 0x52800000) return @"MOVZ w";
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

static void log_gui_sample(void *gui) {
    int index = g_gui_logged;
    if (index >= GUI_LOG_LIMIT) return;
    g_gui_logged = index + 1;

    NSString *name = tnx_object_class_name(gui);
    uintptr_t isa = 0;
    tnx_read_pointer((uintptr_t)gui, &isa);

    tlog([NSString stringWithFormat:
          @"gui[%d] obj=%p class=%@ isa=%p owner=%@ gen=%d",
          index + 1,
          gui,
          name ? name : @"<nil>",
          (void *)isa,
          tnx_isa_owner_description(g_base, gui),
          g_gui_generation]);
}

static BOOL gui_validate(void *gui, NSString **outReason) {
    NSString *reason = nil;

    do {
        if (!gui) { reason = @"null"; break; }
        if (!tnx_object_plausible(gui)) { reason = @"implausible"; break; }

        Class cls = tnx_object_class(gui);
        if (!cls) { reason = @"no-class"; break; }

        const char *name = class_getName(cls);
        if (!name) { reason = @"no-name"; break; }
        if (strcmp(name, "Gui") != 0) {
            reason = [NSString stringWithFormat:@"class=%s", name];
            break;
        }

        uintptr_t isa = 0;
        if (!tnx_read_pointer((uintptr_t)gui, &isa)) { reason = @"isa-unreadable"; break; }
        if (!isa) { reason = @"isa-null"; break; }
        if (!tnx_image_owns_address(g_base, isa)) { reason = @"isa-foreign-image"; break; }
        if (!tnx_isa_in_image_data(g_base, isa)) { reason = @"isa-not-data"; break; }
    } while (0);

    if (reason) {
        g_gui_rejections++;
        if (outReason) *outReason = reason;
        return NO;
    }

    return YES;
}

static void *gui_fetch_raw(int *outWhich) {
    gui_get_t getters[2] = { NULL, NULL };
    uintptr_t addrs[2] = { 0, 0 };
    int total = 0;

    if (g_addr_gui_get_primary) {
        getters[total] = (gui_get_t)g_addr_gui_get_primary;
        addrs[total] = g_addr_gui_get_primary;
        total++;
    }
    if (g_addr_gui_get_alt && g_addr_gui_get_alt != g_addr_gui_get_primary) {
        getters[total] = (gui_get_t)g_addr_gui_get_alt;
        addrs[total] = g_addr_gui_get_alt;
        total++;
    }

    for (int i = 0; i < total; i++) {
        void *result = NULL;
        @try {
            result = getters[i]();
        } @catch (NSException *e) {
            tlog([NSString stringWithFormat:@"  gui_get %p raised %@", (void *)addrs[i], e.reason]);
            result = NULL;
        }
        if (result) {
            if (outWhich) *outWhich = i;
            return result;
        }
    }

    if (outWhich) *outWhich = -1;
    return NULL;
}

static void *gui_acquire(int *outAttempts, int *outWhich, NSString **outReason) {
    for (int attempt = 0; attempt < GUI_RETRY_COUNT; attempt++) {
        int which = -1;
        void *gui = gui_fetch_raw(&which);

        if (gui_validate(gui, outReason)) {
            if (outAttempts) *outAttempts = attempt + 1;
            if (outWhich) *outWhich = which;
            return gui;
        }

        if (attempt + 1 < GUI_RETRY_COUNT) {
            struct timespec ts;
            ts.tv_sec = 0;
            ts.tv_nsec = GUI_RETRY_NS;
            nanosleep(&ts, NULL);
        }
    }

    if (outAttempts) *outAttempts = GUI_RETRY_COUNT;
    return NULL;
}

static BOOL gui_default_position(void *gui, float *outX, float *outY) {
    if (!g_addr_gui_pos) return NO;

    tnx_vec2_t value = { 0.0f, 0.0f };

    @try {
        value = ((fn_gui_pos_t)g_addr_gui_pos)(gui);
    } @catch (NSException *e) {
        return NO;
    }

    if (!isfinite(value.x) || !isfinite(value.y)) return NO;
    if (fabsf(value.x) > 100000.0f || fabsf(value.y) > 100000.0f) return NO;

    if (outX) *outX = value.x;
    if (outY) *outY = value.y;

    return YES;
}

static void *make_sc_string(const char *utf8) {
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

static void show_floater_default(const char *text, float duration) {
    if (!g_aggressive) return;
    if (g_setup_done != 2) { tlog(@"FLOATER_DEF skipped: setup not verified"); return; }
    if (!text) { g_floater_fail++; return; }

    g_floater_attempts++;
    tlog([NSString stringWithFormat:@"FLOATER_DEF try: '%s' dur=%.1f", text, duration]);

    fn_gui_def_t call = g_orig_floater_def;
    if (!call) call = (fn_gui_def_t)g_addr_floater_def;

    if (!call) { tlog(@"  fail: floater_def address unresolved"); g_floater_fail++; return; }

    int attempts = 0;
    NSString *reason = nil;
    void *gui = gui_acquire(&attempts, NULL, &reason);

    if (!gui) {
        tlog([NSString stringWithFormat:@"  fail: gui invalid after %d attempts (%@)", attempts, reason]);
        g_floater_fail++;
        return;
    }

    log_gui_sample(gui);

    void *sc = make_sc_string(text);
    if (!sc) { tlog(@"  fail: sc NULL"); g_floater_fail++; return; }

    @try {
        call(gui, sc, duration);
        tlog([NSString stringWithFormat:@"  called defaultPos(gui, sc, %.1f) attempts=%d", duration, attempts]);
        g_floater_success++;
    } @catch (NSException *e) {
        tlog([NSString stringWithFormat:@"  EXCEPTION: %@", e.reason]);
        g_floater_fail++;
    }
}

static void show_floater_at_default_pos(const char *text) {
    if (!g_aggressive) return;
    if (g_setup_done != 2) { tlog(@"FLOATER_AT skipped: setup not verified"); return; }
    if (!text) { g_floater_fail++; return; }

    g_floater_attempts++;
    tlog([NSString stringWithFormat:@"FLOATER_AT try: '%s' at native default position", text]);

    fn_gui_at_t call = g_orig_floater;
    if (!call) call = (fn_gui_at_t)g_addr_floater;

    if (!call) { tlog(@"  fail: floater address unresolved"); g_floater_fail++; return; }

    int attempts = 0;
    NSString *reason = nil;
    void *gui = gui_acquire(&attempts, NULL, &reason);

    if (!gui) {
        tlog([NSString stringWithFormat:@"  fail: gui invalid after %d attempts (%@)", attempts, reason]);
        g_floater_fail++;
        return;
    }

    log_gui_sample(gui);

    float x = 0.0f;
    float y = 0.0f;

    if (!gui_default_position(gui, &x, &y)) {
        tlog(@"  fail: default floater position unavailable");
        g_floater_fail++;
        return;
    }

    void *sc = make_sc_string(text);
    if (!sc) { tlog(@"  fail: sc NULL"); g_floater_fail++; return; }

    @try {
        call(gui, sc, x, y);
        tlog([NSString stringWithFormat:@"  called showFloaterTextAt(gui, sc, %.1f, %.1f) attempts=%d", x, y, attempts]);
        g_floater_success++;
    } @catch (NSException *e) {
        tlog([NSString stringWithFormat:@"  EXCEPTION: %@", e.reason]);
        g_floater_fail++;
    }
}

static void try_all_floater_variants(const char *text) {
    if (!g_aggressive) { tlog(@"try_all_floater_variants disabled"); return; }

    tlog(@"=== try_all_floater_variants ===");

    tlog(@"variant A: showFloaterTextAtDefaultPos(gui, text, -1)");
    show_floater_default(text, -1.0f);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant B: showFloaterTextAt(gui, text, defaultPos)");
        show_floater_at_default_pos(text);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tlog(@"variant C: showFloaterTextAtDefaultPos(gui, text, 3.0)");
        show_floater_default(text, 3.0f);
    });
}

static void h_recv(void *self, void *msg) {
    g_hits_recv++;
    hook_note_hit((void *)g_addr_recv);

    if (g_hits_recv <= 20) {
        tlog([NSString stringWithFormat:@"RECV #%d", g_hits_recv]);
    }

    if (g_orig_recv) g_orig_recv(self, msg);
}

static void *h_home(void) {
    g_hits_home++;
    hook_note_hit((void *)g_addr_home);

    void *res = NULL;
    if (g_orig_home) res = g_orig_home();

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

static void h_floater(void *self, void *text, float x, float y) {
    g_hits_floater++;
    hook_note_hit((void *)g_addr_floater);

    if (g_hits_floater <= 10) {
        tlog([NSString stringWithFormat:@"FLOATER_CALL #%d x=%.1f y=%.1f", g_hits_floater, x, y]);
    }

    if (g_orig_floater) g_orig_floater(self, text, x, y);
}

static void h_floater_def(void *self, void *text, float duration) {
    g_hits_floater_def++;
    hook_note_hit((void *)g_addr_floater_def);

    if (g_hits_floater_def <= 10) {
        tlog([NSString stringWithFormat:@"FLOATER_DEF_CALL #%d dur=%.1f", g_hits_floater_def, duration]);
    }

    if (g_orig_floater_def) g_orig_floater_def(self, text, duration);
}

static void h_sprite(void *self, void *child) {
    g_hits_sprite++;
    hook_note_hit((void *)g_addr_sprite_add);

    if (g_hits_sprite <= 10) {
        tlog([NSString stringWithFormat:@"SPRITE_ADDCHILD #%d self=%p child=%p",
              g_hits_sprite, self, child]);
    }

    if (g_orig_sprite) g_orig_sprite(self, child);
}

static void h_stage(void *self, void *child) {
    g_hits_stage++;
    hook_note_hit((void *)g_addr_stage_add);

    if (g_hits_stage <= 10) {
        tlog([NSString stringWithFormat:@"STAGE_ADDCHILD #%d self=%p child=%p",
              g_hits_stage, self, child]);
    }

    if (g_orig_stage) g_orig_stage(self, child);
}

static BOOL h_isstate(void *self, int state) {
    g_hits_isstate++;
    hook_note_hit((void *)g_addr_isstate);

    BOOL result = g_orig_isstate ? g_orig_isstate(self, state) : NO;

    if (state != g_last_game_state) {
        g_last_game_state = state;
        g_gui_generation++;
        tlog([NSString stringWithFormat:
              @"GAME_STATE isState(%d)=%d gen=%d gui-cache-reset",
              state, result ? 1 : 0, g_gui_generation]);
    }

    return result;
}

static const struct { const char *name; uint32_t rva; } TITANOX_PROBE_LIST[] = {
    { "Projectile__update",              0x5158f8 },
    { "Projectile_ctor",                 0x514f88 },
    { "DisplayObject__removeFromParent", 0xc16ea8 },
    { "DisplayObject__setXY",            0xc16b4c },
    { "MovieClip__gotoAndStopFrameIndex",0xc1c90c },
    { "MovieClip__setChildVisible",      0xc1dd48 },
    { "MovieClip__getTextFieldByName",   0xc1d550 },
    { "TextField_setText",               0xc4a978 },
    { "ScrollArea__scrollTo",            0xbe15e8 },
    { "BattleScreen__update",            0x56fa80 },
    { "CombatHUD__update",               0x579fcc },
    { "Character__updateHealthBar",      0x57647c },
    { "GameMain__draw",                  0x4b63a0 },
    { "ClientInputManager_addInput",     0x79bf3c },
    { "LogicGameObjectClient_getX",      0xae4a1c },
    { "GUI__showFloaterTextAt",          0x591f28 },
    { "Gui_showFloaterTextAtDefaultPos", 0x818cdc },
    { "Sprite__addChild",                0xc2d8c4 },
    { "Stage_addChild",                  0xc33690 },
    { "MessageManager__receiveMessage",  0x7bace8 }
};

static void probe_reference_targets(void) {
    const unsigned long total = sizeof(TITANOX_PROBE_LIST) / sizeof(TITANOX_PROBE_LIST[0]);
    int withSlots = 0;

    tlog(@"=== probe: which target addresses appear in writable data ===");

    for (unsigned long i = 0; i < total; i++) {
        uintptr_t address = g_base + TITANOX_PROBE_LIST[i].rva;
        int hits = hook_probe(address);

        if (hits > 0) withSlots++;

        tlog([NSString stringWithFormat:@"probe %-34s rva=0x%06x slots=%d",
              TITANOX_PROBE_LIST[i].name, TITANOX_PROBE_LIST[i].rva, hits]);
    }

    tlog([NSString stringWithFormat:@"probe done: %d of %lu targets referenced by data",
          withSlots, total]);
}

static void dump_objc_inventory(const char *tag) {
    int total = objc_getClassList(NULL, 0);

    if (total <= 0) {
        tlog(@"objc: no classes visible");
        return;
    }

    if (total > 200000) total = 200000;

    Class *classes = (Class *)malloc(sizeof(Class) * (size_t)total);
    if (!classes) return;

    static const char *noise[] = {
        "Sentry", "_TtC6Sentry", "_TtCC6Sentry", "Firebase", "AppsFlyer",
        "GUL", "Zendesk", "sczendesk", "Helpshift", "laser", "SKAdNetwork",
        "GAD", "FIR", "nanopb", "GTM", "GSDK", "UI", "NS", "WK", "CA",
        "CL", "CN", "AV", "MTL", "LS", "__", NULL
    };

    static const char *gameplay[] = {
        "Gui", "Home", "Float", "Sprite", "Scene", "Messenger", "Logic",
        "Fight", "Lobby", "Battle", "Card", "Player", "Unit", "Menu",
        "Render", "Node", "View", "Screen", "Popup", "Dialog", "Resource",
        "Game", "State", "Mode", "Widget", "Button", "Label", "Text",
        NULL
    };

    int count = objc_getClassList(classes, total);
    int inGame = 0;
    int listed = 0;
    int detailed = 0;

    tlog([NSString stringWithFormat:@"objc[%s] ===== class name map =====", tag ? tag : "?"]);

    for (int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;

        uintptr_t cls = (uintptr_t)classes[i];

        if (!tnx_image_owns_address(g_base, cls)) continue;

        inGame++;

        BOOL skip = NO;
        for (int n = 0; noise[n]; n++) {
            if (strncmp(name, noise[n], strlen(noise[n])) == 0) { skip = YES; break; }
        }
        if (skip) continue;

        if (listed < 700) {
            tlog([NSString stringWithFormat:@"objc[%s] cls %s", tag ? tag : "?", name]);
            listed++;
        }

        BOOL interesting = NO;
        for (int g = 0; gameplay[g]; g++) {
            if (strstr(name, gameplay[g])) { interesting = YES; break; }
        }

        if (!interesting || detailed >= 60) continue;

        detailed++;

        unsigned mcount = 0;
        Method *methods = class_copyMethodList(classes[i], &mcount);

        tlog([NSString stringWithFormat:@"objc[%s] == %s methods=%u",
              tag ? tag : "?", name, mcount]);

        if (methods) {
            for (unsigned m = 0; m < mcount && m < 24; m++) {
                const char *sel = sel_getName(method_getName(methods[m]));
                const char *types = method_getTypeEncoding(methods[m]);
                tlog([NSString stringWithFormat:@"objc[%s]     -[%s %s] %s",
                      tag ? tag : "?", name, sel ? sel : "?", types ? types : "?"]);
            }

            if (mcount > 24) {
                tlog([NSString stringWithFormat:@"objc[%s]     ... %u more", tag ? tag : "?", mcount - 24]);
            }

            free(methods);
        }
    }

    tlog([NSString stringWithFormat:@"objc[%s]: %d classes, %d in game image, %d named, %d detailed",
          tag ? tag : "?", count, inGame, listed, detailed]);

    free(classes);
}

#define OBJC_HOOK_MAX 24

typedef struct {
    Class cls;
    SEL sel;
    IMP original;
    const char *clsName;
    const char *selName;
    volatile int hits;
    bool used;
} tnx_objc_hook_t;

static tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];
static volatile int g_objc_armed = 0;
static volatile int g_objc_hits_total = 0;

static const char *TITANOX_OBJC_CLASSES[] = {
    "AppController",
    "GameViewController",
    "RootViewController",
    "MainViewController",
    "WebViewController",
    "MetalView",
    "NullView",
    "KeyboardNativeTextfield",
    "scWKWebView",
    NULL
};

static const char *TITANOX_OBJC_SELECTORS[] = {
    "viewDidLoad",
    "viewWillAppear:",
    "viewDidAppear:",
    "viewWillDisappear:",
    "viewDidDisappear:",
    "viewWillLayoutSubviews",
    "viewDidLayoutSubviews",
    "didMoveToWindow",
    "layoutSubviews",
    "applicationDidBecomeActive:",
    "applicationWillResignActive:",
    "applicationDidEnterBackground:",
    "applicationWillEnterForeground:",
    NULL
};

static BOOL tnx_encoding_void_noargs(const char *types) {
    if (!types) return NO;
    if (types[0] != 'v') return NO;

    int i = 1;
    int digitsBefore = 0;
    int digitsAfter = 0;

    while (types[i] >= '0' && types[i] <= '9') { i++; digitsBefore++; }
    if (types[i] != '@') return NO;
    i++;
    while (types[i] >= '0' && types[i] <= '9') i++;
    if (types[i] != ':') return NO;
    i++;
    while (types[i] >= '0' && types[i] <= '9') { i++; digitsAfter++; }
    if (types[i] != 0) return NO;
    if (digitsBefore == 0 && digitsAfter == 0) return YES;
    if (digitsBefore > 0 && digitsAfter > 0) return YES;

    return NO;
}

static BOOL tnx_class_owns_method(Class cls, SEL sel) {
    if (!cls || !sel) return NO;

    unsigned count = 0;
    Method *list = class_copyMethodList(cls, &count);

    if (!list) return NO;

    BOOL found = NO;

    for (unsigned i = 0; i < count; i++) {
        if (method_getName(list[i]) == sel) { found = YES; break; }
    }

    free(list);

    return found;
}

static tnx_objc_hook_t *tnx_objc_lookup(id self, SEL _cmd) {
    Class start = object_getClass(self);

    if (!start) return NULL;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        tnx_objc_hook_t *hook = &g_objc_hooks[i];

        if (!hook->used || hook->sel != _cmd) continue;

        for (Class c = start; c; c = class_getSuperclass(c)) {
            if (c == hook->cls) return hook;
        }
    }

    return NULL;
}

typedef void (*tnx_objc_imp_t)(id, SEL);

static void tnx_objc_replacement(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_lookup(self, _cmd);

    if (hook) {
        hook->hits++;
        g_objc_hits_total++;

        if (hook->hits <= 8) {
            tlog([NSString stringWithFormat:@"OBJC_HIT -[%s %s] #%d self=%p",
                  hook->clsName, hook->selName, hook->hits, self]);
        }
    }

    if (hook && hook->original) {
        reinterpret_cast<tnx_objc_imp_t>(hook->original)(self, _cmd);
    }
}

static int tnx_objc_arm(const char *clsName, const char *selName) {
    Class cls = objc_getClass(clsName);

    if (!cls) return 0;
    if (!tnx_image_owns_address(g_base, (uintptr_t)cls)) return 0;

    SEL sel = sel_registerName(selName);

    if (!tnx_class_owns_method(cls, sel)) return 0;

    Method method = class_getInstanceMethod(cls, sel);

    if (!method) return 0;

    if (!tnx_encoding_void_noargs(method_getTypeEncoding(method))) return 0;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        if (g_objc_hooks[i].cls == cls && g_objc_hooks[i].sel == sel) return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (g_objc_hooks[i].used) continue;

        IMP previous = method_setImplementation(method, reinterpret_cast<IMP>(tnx_objc_replacement));

        if (!previous) return 0;

        g_objc_hooks[i].used = true;
        g_objc_hooks[i].cls = cls;
        g_objc_hooks[i].sel = sel;
        g_objc_hooks[i].original = previous;
        g_objc_hooks[i].clsName = clsName;
        g_objc_hooks[i].selName = selName;

        g_objc_armed++;

        tlog([NSString stringWithFormat:@"objc hook %s -%s orig=%p status=1",
              clsName, selName, (void *)previous]);

        return 1;
    }

    return 0;
}

static void tnx_objc_install_all(void) {
    int tried = 0;

    tlog(@"=== objc hooks ===");

    for (int c = 0; TITANOX_OBJC_CLASSES[c]; c++) {
        for (int s = 0; TITANOX_OBJC_SELECTORS[s]; s++) {
            tried++;
            tnx_objc_arm(TITANOX_OBJC_CLASSES[c], TITANOX_OBJC_SELECTORS[s]);
        }
    }

    tlog([NSString stringWithFormat:@"objc hooks armed=%d tried=%d", g_objc_armed, tried]);
}

static BOOL arm_target(const char *label, uintptr_t address, void *replacement, void **outOriginal) {
    if (outOriginal) *outOriginal = NULL;

    if (!address) {
        tlog([NSString stringWithFormat:@"install %-10s skipped: rva zero", label]);
        return NO;
    }

    if (!tnx_patchable_target(g_base, address)) {
        tlog([NSString stringWithFormat:@"install %-10s rejected addr=%p desc=%@",
              label, (void *)address, describe_op0(address)]);
        return NO;
    }

    BOOL ok = brk_install((void *)address, replacement) ? YES : NO;
    void *tramp = ok ? brk_original_ptr((void *)address) : NULL;

    tlog([NSString stringWithFormat:@"install %-10s target=%p tramp=%p status=%d",
          label, (void *)address, tramp, ok ? 1 : 0]);

    if (!ok) {
        tlog([NSString stringWithFormat:@"install %-10s error=%s",
              label, hook_last_error()]);
        return NO;
    }

    if (outOriginal) *outOriginal = tramp;
    return YES;
}

static void resolve_gui_getters(void) {
    uintptr_t address = g_base + RVA_GUI_GETINSTANCE;

    if (tnx_patchable_target(g_base, address)) {
        g_addr_gui_get_primary = address;
        tlog([NSString stringWithFormat:@"gui_get=%p rva=0x%x desc=%@",
              (void *)address, RVA_GUI_GETINSTANCE, describe_op0(address)]);
    } else {
        tlog([NSString stringWithFormat:@"gui_get rejected rva=0x%x desc=%@",
              RVA_GUI_GETINSTANCE, describe_op0(address)]);
    }

    g_valid_gui = g_addr_gui_get_primary ? 1 : 0;
}

static void setup(void) {
    tlog(@"");
    tlog(@"=== setup ===");
    tlog([NSString stringWithFormat:@"build=%s", TITANOX_BUILD_TAG]);
    tlog([NSString stringWithFormat:@"host=%@ aggressive=%d",
          tnx_host_description(), g_aggressive ? 1 : 0]);

    if (!g_base && !find_game_image(&g_base)) {
        tlog(@"game not found");
        return;
    }

    tlog([NSString stringWithFormat:@"base=%p", (void *)g_base]);

    hook_verify_encryption((void *)g_base);

    g_selftest_ok = brk_selftest_at(g_base) ? 1 : 0;

    tlog([NSString stringWithFormat:@"slots=%d selftest=%d",
          brk_slot_limit(), g_selftest_ok]);

    g_addr_recv         = g_base + RVA_MM_RECEIVEMESSAGE;
    g_addr_home         = g_base + RVA_HOMEMODE_GETINSTANCE;
    g_addr_floater      = g_base + RVA_GUI_SHOWFLOATER_TEXTAT;
    g_addr_floater_def  = g_base + RVA_GUI_SHOWFLOATER_DEFPOS;
    g_addr_gui_pos      = g_base + RVA_GUI_GETDEFAULTFLOATERPOS;
    g_addr_sprite_add   = g_base + RVA_SPRITE_ADDCHILD;
    g_addr_stage_add    = g_base + RVA_STAGE_ADDCHILD;
    g_addr_isstate      = g_base + RVA_GAMESTATEMANAGER_ISSTATE;

    tlog([NSString stringWithFormat:@"recv       %@", dump_target(g_addr_recv)]);
    tlog([NSString stringWithFormat:@"home       %@", dump_target(g_addr_home)]);
    tlog([NSString stringWithFormat:@"floater    %@", dump_target(g_addr_floater)]);
    tlog([NSString stringWithFormat:@"floaterD   %@", dump_target(g_addr_floater_def)]);
    tlog([NSString stringWithFormat:@"guiPos     %@", dump_target(g_addr_gui_pos)]);
    tlog([NSString stringWithFormat:@"spriteAdd  %@", dump_target(g_addr_sprite_add)]);
    tlog([NSString stringWithFormat:@"stageAdd   %@", dump_target(g_addr_stage_add)]);
    tlog([NSString stringWithFormat:@"isState    %@", dump_target(g_addr_isstate)]);

    hook_log_prot("region recv", g_addr_recv);
    hook_log_prot("region home", g_addr_home);
    hook_log_prot("region floaterD", g_addr_floater_def);
    hook_log_prot("region spriteAdd", g_addr_sprite_add);

    dump_objc_inventory("early");

    tnx_objc_install_all();

    resolve_gui_getters();

    BOOL ok = YES;

    if (!arm_target("recv", g_addr_recv, (void *)&h_recv, (void **)&g_orig_recv)) ok = NO;
    else g_valid_recv = 1;

    if (!arm_target("home", g_addr_home, (void *)&h_home, (void **)&g_orig_home)) ok = NO;
    else g_valid_home = 1;

    if (!arm_target("floater", g_addr_floater, (void *)&h_floater, (void **)&g_orig_floater)) ok = NO;
    if (!arm_target("floaterD", g_addr_floater_def, (void *)&h_floater_def, (void **)&g_orig_floater_def)) ok = NO;
    if (!arm_target("spriteAdd", g_addr_sprite_add, (void *)&h_sprite, (void **)&g_orig_sprite)) ok = NO;
    if (!arm_target("stageAdd", g_addr_stage_add, (void *)&h_stage, (void **)&g_orig_stage)) ok = NO;
    if (!arm_target("isState", g_addr_isstate, (void *)&h_isstate, (void **)&g_orig_isstate)) ok = NO;

    probe_reference_targets();

    tlog([NSString stringWithFormat:@"slots=%d live=%d selftest=%d installed=%d",
          brk_slot_limit(), brk_active_count(), g_selftest_ok ? 1 : 0, ok ? 1 : 0]);

    tlog([NSString stringWithFormat:@"mode: code_patch=%d ptr_hooks=%d ptr_slots=%d",
          hook_code_patch_allowed() ? 1 : 0, hook_pointer_count(), hook_pointer_slots()]);

    tlog([NSString stringWithFormat:@"objc: armed=%d hits=%d", g_objc_armed, g_objc_hits_total]);

    tlog([NSString stringWithFormat:@"last error: %s", hook_last_error()]);

    brk_log_state();

    g_setup_done = 2;
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
    NSString *msg = [NSString stringWithFormat:
        @"host=%@ base=%p\nrecv=%d home=%d\nfloater=%d floaterD=%d\nisState=%d sprite=%d stage=%d\n"
        @"floater tries=%d ok=%d fail=%d\nslots=%d live=%d selftest=%d\n"
        @"objc armed=%d hits=%d\nptr hooks=%d slots=%d\nimages=%u",
        tnx_host_description(),
        (void *)g_base,
        g_hits_recv, g_hits_home,
        g_hits_floater, g_hits_floater_def,
        g_hits_isstate, g_hits_sprite, g_hits_stage,
        g_floater_attempts, g_floater_success, g_floater_fail,
        brk_slot_limit(), brk_active_count(), g_selftest_ok,
        g_objc_armed, g_objc_hits_total,
        hook_pointer_count(), hook_pointer_slots(),
        (unsigned)_dyld_image_count()];

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

    if (tick > GAME_POLL_MAX_TICKS) {
        tlog([NSString stringWithFormat:@"game image not found after %d polls (images=%u)",
              GAME_POLL_MAX_TICKS, (unsigned)_dyld_image_count()]);
        return;
    }

    uintptr_t base = 0;
    BOOL found = find_game_image(&base);

    static int stableTicks = 0;

    if (found) {
        stableTicks++;
    } else {
        stableTicks = 0;
    }

    if (found && stableTicks >= GAME_POLL_STABLE_TICKS) {
        g_base = base;
        setup();
        show_stats(@"armed");
        return;
    }

    if (!found && (tick % 40) == 0) {
        tlog([NSString stringWithFormat:@"poll %d: no game image yet (images=%u)",
              tick, (unsigned)_dyld_image_count()]);
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
    g_aggressive = YES;

    if (aggressive) {
        g_aggressive = (aggressive[0] == '1') ? YES : NO;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        tlog(@"=== titanox start ===");
        tlog([NSString stringWithFormat:@"build=%s", TITANOX_BUILD_TAG]);
        tlog([NSString stringWithFormat:@"host=%@ aggressive=%d",
              tnx_host_description(), g_aggressive ? 1 : 0]);
        poll_for_game(0);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (g_base) dump_objc_inventory("10s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (g_base) dump_objc_inventory("35s");
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
