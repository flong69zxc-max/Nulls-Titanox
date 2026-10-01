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

#define TITANOX_BUILD_TAG "brk-b2 2026-10-02 cave-need48"

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
static volatile int g_gui_ok = 0;
static volatile int g_label_state = 0;
static volatile int g_label_updates = 0;
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

static BOOL tnx_op_is_strong_prologue(uint32_t word) {
    if (word == 0xD503233F) return YES;
    if (word == 0xD503237F) return YES;
    if ((word & 0xFFFFFF1F) == 0xD503241F) return YES;

    uint32_t registers = (word >> 5) & 0x1Fu;
    uint32_t spRelative = (registers == 31u) ? YES : NO;

    if ((word & 0xFFC00000u) == 0xA9800000u && spRelative) return YES;
    if ((word & 0xFFE00C00u) == 0xF8000C00u && spRelative) return YES;
    if ((word & 0xFFE00C00u) == 0xF8000000u && spRelative) {
        uint32_t offset = (word >> 12) & 0x1FFu;

        if (offset & 0x100u) return YES;
    }

    if ((word & 0xFF8003FFu) == 0xD10003FFu) return YES;

    return NO;
}

static BOOL tnx_op_is_terminator(uint32_t word) {
    if ((word & 0xFFFFFC1Fu) == 0xD65F0000u) return YES;
    if ((word & 0xFC000000u) == 0x14000000u) return YES;
    if ((word & 0xFFE0001Fu) == 0xD4200000u) return YES;

    return NO;
}

static BOOL tnx_addr_is_entry(uintptr_t address) {
    if (!address) return NO;

    uint32_t word = 0;

    if (!tnx_read_u32(address, &word)) return NO;
    if (tnx_op_is_strong_prologue(word)) return YES;

    uintptr_t probe = address - 4;

    for (int step = 0; step < 12; step++) {
        uint32_t previous = 0;

        if (!tnx_read_u32(probe, &previous)) return NO;
        if (previous == 0xD503201F) { probe -= 4; continue; }

        return tnx_op_is_terminator(previous) ? YES : NO;
    }

    return NO;
}

static uintptr_t tnx_function_entry(uintptr_t address, uintptr_t *outDelta) {
    if (outDelta) *outDelta = 0;
    if (!address) return 0;

    if (tnx_addr_is_entry(address)) return address;

    uintptr_t limit = (address > 0x800) ? (address - 0x800) : 0;

    for (uintptr_t probe = address - 4; probe > limit; probe -= 4) {
        uint32_t candidate = 0;

        if (!tnx_read_u32(probe, &candidate)) break;
        if (!tnx_op_is_strong_prologue(candidate)) continue;

        if (outDelta) *outDelta = address - probe;

        return probe;
    }

    return 0;
}

static void tnx_report_entry(const char *label, uintptr_t address) {
    uintptr_t delta = 0;
    uintptr_t entry = tnx_function_entry(address, &delta);

    tlog([NSString stringWithFormat:
          @"rva %-10s addr=%p entry=%p delta=0x%llx exact=%d desc=%@",
          label,
          (void *)address,
          (void *)entry,
          (unsigned long long)delta,
          (entry == address) ? 1 : 0,
          describe_op0(address)]);
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
            g_gui_ok++;
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
    if (!tnx_addr_is_entry(g_addr_gui_pos)) return NO;

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

    if (!call) {
        if (!tnx_addr_is_entry(g_addr_floater_def)) {
            tlog([NSString stringWithFormat:
                  @"  fail: floater_def rva=0x%x is not a function entry desc=%@",
                  RVA_GUI_SHOWFLOATER_DEFPOS, describe_op0(g_addr_floater_def)]);
            g_floater_fail++;
            return;
        }

        call = (fn_gui_def_t)g_addr_floater_def;
    }

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

    if (!call) {
        if (!tnx_addr_is_entry(g_addr_floater)) {
            tlog([NSString stringWithFormat:
                  @"  fail: floater rva=0x%x is not a function entry desc=%@",
                  RVA_GUI_SHOWFLOATER_TEXTAT, describe_op0(g_addr_floater)]);
            g_floater_fail++;
            return;
        }

        call = (fn_gui_at_t)g_addr_floater;
    }

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

static void floater_demo_tick(int attempt);

static void floater_demo_tick(int attempt) {
    if (!g_aggressive) { tlog(@"floater demo disabled"); return; }
    if (g_floater_success > 0) { tlog(@"floater demo done"); return; }

    if (g_setup_done != 2) {
        tlog([NSString stringWithFormat:@"floater demo waiting: setup=%d", g_setup_done]);
    } else if (!g_addr_gui_get_primary) {
        tlog(@"floater demo skipped: Gui::getInstance rva is not a callable function entry");
        return;
    } else if (attempt >= 8) {
        tlog(@"floater demo gave up");
        return;
    } else {
        tlog([NSString stringWithFormat:@"floater demo attempt %d gui_ok=%d",
              attempt + 1, g_gui_ok]);
        try_all_floater_variants("Tale Stars iOS test");
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        floater_demo_tick(attempt + 1);
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
    { "DisplayObject_setXY",                  0xC16B54 },
    { "DisplayObject_removeFromParent",       0xC16EA8 },
    { "MovieClipHelper_setTextAndScale",      0x990C20 },
    { "MovieClip_getTextFieldByName",         0xC1D7B0 },
    { "MovieClip_getChildByName",             0xC1D550 },
    { "movieClip_setText",                    0xC4ED90 },
    { "StringTable_getMovieClip",             0xBECE60 },
    { "gotoAndStop",                          0xC1C90C },
    { "setInteractiveRecursive",              0xC1CFE0 },
    { "Stage_addChild_js",                    0xC336A0 },
    { "Sprite_ctor",                          0xC2D684 },
    { "GameButton_ctor",                      0x597C48 },
    { "GameButton_setText",                   0x598298 },
    { "CustomButton_buttonPressed",           0xC4DFCC },
    { "dropCtor",                             0x59908C },
    { "dropGUIContainer_addGameButton",       0x599508 },
    { "DecoratedTextField_setupDecorated",    0x58E7BC },
    { "stringCtor",                           0xDCF8F0 },
    { "operator_new",                         0x10EFAF0 },
    { "LogicDataTables_getColorGradient",     0xA5B9A0 },
    { "TextField_reset",                      0xC49844 },
    { "GenericPopup_GenericPopup",            0x6C38B8 },
    { "GenericPopup_addPopupButton",          0x6C442C },
    { "GameInputField_ctor",                  0x599EF4 },
    { "GameInputField_setMaxTextLength",      0xE12BCC },
    { "GameSliderComponent_ctor",             0x59C004 },
    { "GameSliderComponent_setBounds",        0x59C808 },
    { "GameSlider_refreshLogic",              0x59C428 },
    { "GameSlider_update",                    0x59C6BC },
    { "GameMain_update_a",                    0x4B4B7C },
    { "StartSpectateMessage_ctor",            0xB754A4 },
    { "BattleMode_getInstance",               0x954EE0 },
    { "BattleScreen_getLogicBattleModeClient",0x809348 },
    { "LogicBattleModeClient_getOwnCharacter",0xB90A28 },
    { "LogicBattleModeClient_isUltiReady",    0x818BCC },
    { "LogicBattleModeClient_update",         0xB8EEE0 },
    { "BattleScreen_autoShoot",               0xB90C04 },
    { "BattleScreen_tryToActivateSkill",      0x802960 },
    { "BattleScreen_updateMovement",          0x809348 },
    { "BattleScreen_convertToControlScheme",  0x80D758 },
    { "BattleScreen_getClosestTarget",        0x8151E0 },
    { "Character_getUltiSkillServer",         0x80D758 },
    { "Character_getPrimarySkillServer",      0xAB73A4 },
    { "LogicSkillData_getCastingRange",       0xAB4390 },
    { "isImmuneAndBulletsGoThrough",          0xA94114 },
    { "hasAmmo",                              0xAB4E60 },
    { "getSkillRechargeMs",                   0xAB4E14 },
    { "LogicGameObjectClient_getX",           0xAE4A1C },
    { "LogicGameObjectClient_getY",           0xAE4A24 },
    { "LogicGameObjectClient_getGlobalID",    0xAE49C8 },
    { "LogicSkillData_getProjectile",         0xA9434C },
    { "LogicProjectileData_getSpeed",         0xA815CC },
    { "LogicProjectileData_getRadius",        0xA8164C },
    { "MessageManager__receiveMessage",       0x7BACE8 },
    { "Stage_addChild_ios",                   0xC33690 },
    { "home",                                 0x95F488 },
    { "guiGet",                               0x591644 },
    { "floater",                              0x591F28 },
    { "floaterDefPos",                        0x818CDC },
    { "guiPos",                               0x591DA0 },
    { "spriteAdd",                            0xC2D8C4 },
    { "isState",                              0x95E7C0 }
};

static void probe_reference_targets(void) {
    const unsigned long total = sizeof(TITANOX_PROBE_LIST) / sizeof(TITANOX_PROBE_LIST[0]);
    int withSlots = 0;

    tlog(@"=== probe: which target addresses appear in writable data ===");

    for (unsigned long i = 0; i < total; i++) {
        uintptr_t address = g_base + TITANOX_PROBE_LIST[i].rva;
        BOOL entry = tnx_addr_is_entry(address);
        int hits = entry ? hook_probe(address) : 0;

        tnx_report_entry(TITANOX_PROBE_LIST[i].name, address);

        if (hits > 0) withSlots++;

        tlog([NSString stringWithFormat:@"probe %-34s rva=0x%06x entry=%d slots=%d",
              TITANOX_PROBE_LIST[i].name, TITANOX_PROBE_LIST[i].rva, entry ? 1 : 0, hits]);
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

#define OBJC_HOOK_MAX 32

typedef struct {
    Class cls;
    SEL sel;
    IMP original;
    IMP replacement;
    const char *clsName;
    const char *selName;
    const char *signature;
    volatile int hits;
    bool used;
} tnx_objc_hook_t;

static tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];
static volatile int g_objc_armed = 0;
static volatile int g_objc_hits_total = 0;

static const char *TITANOX_OBJC_CLASSES[] = {
    "AppController",
    "GameViewController",
    "MetalView",
    "NullView",
    "KeyboardNativeTextfield",
    "WebViewController",
    "ExternalWebViewController",
    "StoreProductViewController",
    "scWKWebView",
    NULL
};

static const char *TITANOX_OBJC_SELECTORS[] = {
    "render",
    "processInput",
    "loadView",
    "viewDidLoad",
    "initGame",
    "didMoveToWindow",
    "layoutSubviews",
    "viewWillAppear:",
    "viewDidAppear:",
    "viewWillDisappear:",
    "viewDidDisappear:",
    "viewWillLayoutSubviews",
    "viewDidLayoutSubviews",
    "setPaused:",
    "pauseUpdates:",
    "didEnterBackground:",
    "willEnterForeground:",
    "applicationDidBecomeActive:",
    "applicationWillResignActive:",
    "applicationDidEnterBackground:",
    "applicationWillEnterForeground:",
    "touchesBegan:withEvent:",
    "touchesEnded:withEvent:",
    "touchesCancelled:withEvent:",
    "pressesBegan:withEvent:",
    "pressesEnded:withEvent:",
    "swipeRight",
    "onNavigationBack",
    "onNavigationClose",
    "close",
    "invalidateTimer",
    "onTimeout",
    "show",
    "hide",
    "sendText",
    NULL
};

static const char *tnx_skip_compound(const char *p) {
    char open = *p;
    char close = (open == '{') ? '}' : ((open == '(') ? ')' : ']');
    int depth = 0;

    while (*p) {
        if (*p == open) {
            depth++;
        } else if (*p == close) {
            depth--;
            if (depth == 0) { p++; break; }
        }

        p++;
    }

    return p;
}

static int tnx_objc_arg_types(const char *types, char *out, size_t capacity) {
    if (!types || !out || capacity < 8) return -1;

    size_t used = 0;
    const char *p = types;

    while (*p && (used + 1) < capacity) {
        while (*p >= '0' && *p <= '9') p++;
        if (!*p) break;

        char c = *p;

        if (c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V') {
            p++;
            continue;
        }

        if (c == '^') {
            p++;
            if (*p == '{' || *p == '(' || *p == '[') p = tnx_skip_compound(p);
            out[used++] = '^';
            continue;
        }

        if (c == '{' || c == '(' || c == '[') {
            p = tnx_skip_compound(p);
            out[used++] = 'X';
            continue;
        }

        out[used++] = c;
        p++;
    }

    out[used] = 0;

    return (int)used;
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

static tnx_objc_hook_t *tnx_objc_note(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_lookup(self, _cmd);

    if (!hook) return NULL;

    hook->hits++;
    g_objc_hits_total++;

    if (hook->hits <= 4 || (hook->hits % 300) == 0) {
        tlog([NSString stringWithFormat:@"OBJC_HIT -[%s %s] %s #%d self=%p",
              hook->clsName, hook->selName, hook->signature, hook->hits, self]);
    }

    return hook;
}

static void tnx_objc_rep0(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_note(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL)>(hook->original)(self, _cmd);
    }
}

static void tnx_objc_rep1(id self, SEL _cmd, id a1) {
    tnx_objc_hook_t *hook = tnx_objc_note(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, id)>(hook->original)(self, _cmd, a1);
    }
}

static void tnx_objc_rep1b(id self, SEL _cmd, BOOL a1) {
    tnx_objc_hook_t *hook = tnx_objc_note(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, BOOL)>(hook->original)(self, _cmd, a1);
    }
}

static void tnx_objc_rep2(id self, SEL _cmd, id a1, id a2) {
    tnx_objc_hook_t *hook = tnx_objc_note(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, id, id)>(hook->original)(self, _cmd, a1, a2);
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

    const char *types = method_getTypeEncoding(method);

    if (!types) return 0;

    char args[10];
    int argc = tnx_objc_arg_types(types, args, sizeof(args));

    if (argc < 3) return 0;
    if (args[0] != 'v') return 0;

    IMP replacement = NULL;

    if (argc == 3) {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep0);
    } else if (argc == 4 && args[3] == '@') {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep1);
    } else if (argc == 4 && args[3] == 'B') {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep1b);
    } else if (argc == 5 && args[3] == '@' && args[4] == '@') {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep2);
    } else {
        return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        if (g_objc_hooks[i].cls == cls && g_objc_hooks[i].sel == sel) return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (g_objc_hooks[i].used) continue;

        IMP previous = method_setImplementation(method, replacement);

        if (!previous) return 0;

        g_objc_hooks[i].used = true;
        g_objc_hooks[i].cls = cls;
        g_objc_hooks[i].sel = sel;
        g_objc_hooks[i].original = previous;
        g_objc_hooks[i].replacement = replacement;
        g_objc_hooks[i].clsName = clsName;
        g_objc_hooks[i].selName = selName;
        g_objc_hooks[i].signature = types;

        g_objc_armed++;

        tlog([NSString stringWithFormat:@"objc hook %s -%s sig=%s repl=%p orig=%p status=1",
              clsName, selName, types, (void *)replacement, (void *)previous]);

        return 1;
    }

    return 0;
}

static void tnx_objc_install_all(void) {
    int tried = 0;

    tlog(@"=== objc hooks ===");

    for (int s = 0; TITANOX_OBJC_SELECTORS[s]; s++) {
        for (int c = 0; TITANOX_OBJC_CLASSES[c]; c++) {
            tried++;
            tnx_objc_arm(TITANOX_OBJC_CLASSES[c], TITANOX_OBJC_SELECTORS[s]);
        }
    }

    tlog([NSString stringWithFormat:@"objc hooks armed=%d tried=%d", g_objc_armed, tried]);

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;

        tlog([NSString stringWithFormat:@"objc armed -[%s %s] %s",
              g_objc_hooks[i].clsName, g_objc_hooks[i].selName, g_objc_hooks[i].signature]);
    }
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

    if (!tnx_addr_is_entry(address)) {
        uintptr_t delta = 0;
        uintptr_t entry = tnx_function_entry(address, &delta);

        tlog([NSString stringWithFormat:
              @"install %-10s rejected: not a function entry addr=%p candidate=%p delta=0x%llx desc=%@",
              label, (void *)address, (void *)entry, (unsigned long long)delta, describe_op0(address)]);

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
    uintptr_t delta = 0;
    uintptr_t entry = tnx_function_entry(address, &delta);

    tnx_report_entry("gui_get", address);

    if (tnx_patchable_target(g_base, address) && entry == address) {
        g_addr_gui_get_primary = address;
        tlog([NSString stringWithFormat:@"gui_get accepted rva=0x%x exact entry", RVA_GUI_GETINSTANCE]);
    } else {
        tlog([NSString stringWithFormat:
              @"gui_get NOT callable rva=0x%x candidate=%p delta=0x%llx (calling it would jump mid-function)",
              RVA_GUI_GETINSTANCE, (void *)entry, (unsigned long long)delta]);
    }

    if (g_addr_gui_pos && !tnx_addr_is_entry(g_addr_gui_pos)) {
        tlog([NSString stringWithFormat:@"guiPos NOT callable rva=0x%x", RVA_GUI_GETDEFAULTFLOATERPOS]);
        g_addr_gui_pos = 0;
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

    tnx_report_entry("recv", g_addr_recv);
    tnx_report_entry("home", g_addr_home);
    tnx_report_entry("floater", g_addr_floater);
    tnx_report_entry("floaterD", g_addr_floater_def);
    tnx_report_entry("guiPos", g_addr_gui_pos);
    tnx_report_entry("spriteAdd", g_addr_sprite_add);
    tnx_report_entry("stageAdd", g_addr_stage_add);
    tnx_report_entry("isState", g_addr_isstate);

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

    tlog([NSString stringWithFormat:@"gui: ok=%d failures=%d", g_gui_ok, g_gui_rejections]);

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

static int tnx_objc_hits_prefix(const char *prefix) {
    size_t length = prefix ? strlen(prefix) : 0;
    int total = 0;

    if (!length) return 0;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        if (strncmp(g_objc_hooks[i].selName, prefix, length) != 0) continue;

        total += g_objc_hooks[i].hits;
    }

    return total;
}

static UILabel *g_overlay = nil;

static void overlay_tick(int attempt);

static void overlay_tick(int attempt) {
    if (attempt > 90) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_overlay) {
            UIViewController *root = top_vc();

            if (!root || !root.view) {
                if ((attempt % 5) == 0) tlog(@"overlay: no root view yet");
                return;
            }

            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8.0, 60.0, 10.0, 10.0)];

            label.textColor = UIColor.whiteColor;
            label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
            label.font = [UIFont monospacedSystemFontOfSize:10.0 weight:UIFontWeightRegular];
            label.numberOfLines = 0;
            label.textAlignment = NSTextAlignmentLeft;
            label.userInteractionEnabled = NO;

            UIView *host = root.view.window ? root.view.window : root.view;

            [host addSubview:label];

            g_overlay = label;

            tlog([NSString stringWithFormat:@"overlay created on %@ host=%@ frame=%@",
                  NSStringFromClass(root.class),
                  NSStringFromClass(host.class),
                  NSStringFromCGRect(host.bounds)]);
        }

        g_overlay.text = [NSString stringWithFormat:
            @"Titanox %s\n"
            @"objc armed=%d hits=%d\n"
            @"render=%d proc=%d\n"
            @"touch=%d press=%d\n"
            @"ptr slots=%d/%d stage=%d\n"
            @"gui=%d floater=%d/%d\n"
            @"glabel=%d upd=%d",
            TITANOX_BUILD_TAG,
            g_objc_armed, g_objc_hits_total,
            tnx_objc_hits_prefix("render"), tnx_objc_hits_prefix("processInput"),
            tnx_objc_hits_prefix("touches"), tnx_objc_hits_prefix("presses"),
            hook_pointer_slots(), hook_pointer_count(), g_hits_stage,
            g_gui_ok, g_floater_success, g_floater_attempts,
            g_label_state, g_label_updates];

        [g_overlay sizeToFit];

        CGRect frame = g_overlay.frame;
        frame.origin.x = 8.0;
        frame.origin.y = 60.0;
        g_overlay.frame = frame;
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        overlay_tick(attempt + 1);
    });
}

static void tnx_objc_report(const char *tag) {
    int armed = 0;
    int live = 0;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        armed++;
        if (g_objc_hooks[i].hits > 0) live++;
    }

    tlog([NSString stringWithFormat:@"objc[%s] armed=%d live=%d total=%d",
          tag ? tag : "?", armed, live, g_objc_hits_total]);

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;

        tlog([NSString stringWithFormat:@"objc[%s] -[%s %s] hits=%d",
              tag ? tag : "?",
              g_objc_hooks[i].clsName,
              g_objc_hooks[i].selName,
              g_objc_hooks[i].hits]);
    }
}

#define TNX_RVA_STRINGTABLE_GETMOVIECLIP  0xBECE60
#define TNX_RVA_MC_GETTEXTFIELDBYNAME     0xC1D7B0
#define TNX_RVA_MCH_SETTEXT               0x990C20
#define TNX_RVA_DO_SETXY                  0xC16B54
#define TNX_RVA_STAGE_ADDCHILD            0xC33690
#define TNX_RVA_STAGE_INSTANCE            0x12393E0

typedef void   (*tnx_fn_void2_t)(void *a, void *b);
typedef void * (*tnx_fn_ptr2_t)(void *a, void *b);
typedef void   (*tnx_fn_settext_t)(void *textField, void *scText, int a3, int a4);
typedef void   (*tnx_fn_setxy_t)(void *obj, float x, float y);

static void *g_label_clip = NULL;
static void *g_label_tf = NULL;
static int g_label_last_frames = 0;

static void *tnx_read_global_ptr(uint32_t rva) {
    void *value = NULL;

    if (!g_base) return NULL;

    memcpy(&value, (const void *)(g_base + rva), sizeof(value));

    return value;
}

static void tnx_game_label_text(NSString *text) {
    if (!g_label_tf || !g_base) return;

    void *sc = make_sc_string([text UTF8String]);

    if (!sc) return;

    ((tnx_fn_settext_t)(g_base + TNX_RVA_MCH_SETTEXT))(g_label_tf, sc, 4, 0);
}

static void tnx_game_label_tick(int attempt);

static void tnx_game_label_tick(int attempt) {
    if (attempt > 600) return;
    if (!g_aggressive) return;

    if (!g_base) {
        tlog(@"glabel: no base yet");
    } else if (!g_label_clip) {
        uintptr_t getClip  = g_base + TNX_RVA_STRINGTABLE_GETMOVIECLIP;
        uintptr_t getTf    = g_base + TNX_RVA_MC_GETTEXTFIELDBYNAME;
        uintptr_t setXy    = g_base + TNX_RVA_DO_SETXY;
        uintptr_t addChild = g_base + TNX_RVA_STAGE_ADDCHILD;

        if (!tnx_addr_is_entry(getClip) || !tnx_addr_is_entry(getTf) ||
            !tnx_addr_is_entry(setXy) || !tnx_addr_is_entry(addChild)) {
            tlog([NSString stringWithFormat:
                  @"glabel: offsets rejected getClip=%d getTf=%d setXY=%d addChild=%d",
                  tnx_addr_is_entry(getClip) ? 1 : 0,
                  tnx_addr_is_entry(getTf) ? 1 : 0,
                  tnx_addr_is_entry(setXy) ? 1 : 0,
                  tnx_addr_is_entry(addChild) ? 1 : 0]);
            return;
        }

        void *stage = tnx_read_global_ptr(TNX_RVA_STAGE_INSTANCE);

        if (!stage) {
            if ((attempt % 5) == 0) tlog(@"glabel: stage not ready");
        } else {
            void *scUi  = make_sc_string("sc/ui.sc");
            void *scBox = make_sc_string("textbox_1");
            void *scTxt = make_sc_string("txt");

            if (!scUi || !scBox || !scTxt) {
                tlog(@"glabel: sc string alloc failed");
            } else {
                tlog(@"glabel step1 StringTable_getMovieClip(sc/ui.sc, textbox_1)");

                void *clip = ((tnx_fn_ptr2_t)getClip)(scUi, scBox);

                if (!clip) {
                    tlog(@"glabel: clip NULL");
                } else {
                    tlog([NSString stringWithFormat:@"glabel step2 clip=%p getTextFieldByName(txt)", clip]);

                    void *tf = ((tnx_fn_ptr2_t)getTf)(clip, scTxt);

                    if (!tf) {
                        tlog(@"glabel: textField NULL");
                    } else {
                        tlog([NSString stringWithFormat:@"glabel step3 tf=%p setXY + addChild", tf]);

                        ((tnx_fn_setxy_t)setXy)(clip, 60536.0f, 60536.0f);
                        ((tnx_fn_void2_t)addChild)(stage, clip);

                        g_label_clip = clip;
                        g_label_tf = tf;
                        g_label_state = 2;

                        tlog([NSString stringWithFormat:@"glabel ready stage=%p clip=%p tf=%p",
                              stage, clip, tf]);
                    }
                }
            }
        }
    } else {
        int frames = g_objc_hits_total;
        int fps = frames - g_label_last_frames;

        g_label_last_frames = frames;
        g_label_updates++;
        g_label_state = 3;

        tnx_game_label_text([NSString stringWithFormat:
            @"Titanox %s\nFPS %d\nhooks %d/%d\nupd %d",
            TITANOX_BUILD_TAG, fps, g_objc_armed, frames, g_label_updates]);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tnx_game_label_tick(attempt + 1);
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        overlay_tick(0);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tnx_game_label_tick(0);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        floater_demo_tick(0);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tnx_objc_report("12s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        tnx_objc_report("35s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @20s");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        show_stats(@"stats @45s");
        tnx_objc_report("45s");
        brk_log_state();
    });
}
