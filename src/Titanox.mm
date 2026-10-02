#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import <stdarg.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import "offsets.h"
#import "lc_detect.h"

#include "hook.h"

#if __has_include(<ptrauth.h>)
#import <ptrauth.h>
#endif

#define LOG_MAX_BYTES (512 * 1024)
#define OBJC_HOOK_MAX 32
#define WANTED_MAX 4
#define SCAN_MAX 256

#define TNX_RVA_GETTEXTFIELDBYNAME_A 0xc1d7b0ULL
#define TNX_RVA_GETTEXTFIELDBYNAME_B 0xc1d550ULL
#define TNX_RVA_SETTEXT_A 0x990c20ULL
#define TNX_RVA_SETTEXT_B 0xc4a978ULL
#define TNX_RVA_SETXY_A 0xc16b54ULL
#define TNX_RVA_SETXY_B 0xc16b4cULL

#define TNX_LABEL "Titanox v1.0 [Zero-Latency]"
#define TNX_CLIP_FILE "sc/ui.sc"
#define TNX_CLIP_NAME "textbox_1"
#define TNX_CLIP_TEXT "txt"

#define DODGE_RANGE_SQ (1800.0f * 1800.0f)
#define DODGE_THREAT 320.0f
#define DODGE_STEP 600.0f

typedef void (*fn_void_2_t)(void *, void *);
typedef void *(*fn_ptr_2_t)(void *, void *);
typedef void (*fn_settext_t)(void *, void *, int, int);
typedef void (*fn_setxy_t)(void *, float, float);
typedef void (*fn_send_movement_t)(void *, float, float);
typedef void (*fn_set_prediction_t)(void *, int, int);
typedef void *(*fn_get_inst_t)(void);
typedef void *(*fn_get_own_char_t)(void *);
typedef int (*fn_get_team_t)(void *);
typedef int (*fn_get_coord_t)(void *);

typedef struct {
    const char *name;
    uintptr_t rva;
} tnx_rva_entry_t;

static const char *g_image_names[] = {
    "Nulls Brawl",
    "Laser",
    "NB.app",
    NULL
};

static const char *g_probe_classes[] = {
    "MetalView",
    "NullView",
    "AppController",
    NULL
};

static const tnx_rva_entry_t g_rvas[] = {
    { "RVA_BATTLEMODE_GETINSTANCE", RVA_BATTLEMODE_GETINSTANCE },
    { "RVA_BATTLESCREEN__BATTLESCREEN", RVA_BATTLESCREEN__BATTLESCREEN },
    { "RVA_BATTLESCREEN__UPDATEMOVEMENT", RVA_BATTLESCREEN__UPDATEMOVEMENT },
    { "RVA_BATTLESCREEN__UPDATEAUTOSHOOT", RVA_BATTLESCREEN__UPDATEAUTOSHOOT },
    { "RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT", RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT },
    { "RVA_BATTLESCREEN__TRYTOACTIVATESKILL", RVA_BATTLESCREEN__TRYTOACTIVATESKILL },
    { "RVA_LOGICBATTLEMODECLIENT_UPDATE", RVA_LOGICBATTLEMODECLIENT_UPDATE },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER", RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM", RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM },
    { "RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO", RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETDATA", RVA_LOGICGAMEOBJECTCLIENT_GETDATA },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID", RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETX", RVA_LOGICGAMEOBJECTCLIENT_GETX },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETY", RVA_LOGICGAMEOBJECTCLIENT_GETY },
    { "RVA_LOGICPROJECTILEDATA_GETSPEED", RVA_LOGICPROJECTILEDATA_GETSPEED },
    { "RVA_LOGICPROJECTILEDATA_GETRADIUS", RVA_LOGICPROJECTILEDATA_GETRADIUS },
    { "RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR", RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR },
    { "RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION", RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION },
    { "RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT", RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT },
    { "RVA_STAGE_ADDCHILD", RVA_STAGE_ADDCHILD },
    { "RVA_STRINGTABLE_GETMOVIECLIP", RVA_STRINGTABLE_GETMOVIECLIP },
    { "RVA_MOVIECLIP__GETTEXTFIELDBYNAME", RVA_MOVIECLIP__GETTEXTFIELDBYNAME },
    { "RVA_TEXTFIELD_SETTEXT", RVA_TEXTFIELD_SETTEXT },
    { "RVA_DISPLAYOBJECT__SETXY", RVA_DISPLAYOBJECT__SETXY },
    { "RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS", RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS },
    { "RVA_BATTLESCREEN_FIREWRAPPERFN", RVA_BATTLESCREEN_FIREWRAPPERFN },
    { "RVA_BATTLESCREEN_ACTIVATESKILL", RVA_BATTLESCREEN_ACTIVATESKILL },
    { "RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS", RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS },
    { "RVA_MESSAGEMANAGER__RECEIVEMESSAGE", RVA_MESSAGEMANAGER__RECEIVEMESSAGE },
    { "RVA_COMBATHUD__SETMOVESTICKSTATE", RVA_COMBATHUD__SETMOVESTICKSTATE },
    { "RVA_COMBATHUD__SETSHOOTSTICKSTATE", RVA_COMBATHUD__SETSHOOTSTICKSTATE },
    { NULL, 0 }
};

typedef struct {
    __unsafe_unretained Class cls;
    __unsafe_unretained Class wanted[WANTED_MAX];
    int wantedCount;
    SEL sel;
    IMP original;
    IMP replacement;
    const char *selName;
    const char *signature;
    int hits;
    BOOL used;
} tnx_objc_hook_t;

static uintptr_t g_base = 0;
static uintptr_t *g_starts = NULL;
static size_t g_starts_count = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;
static BOOL g_setup_done = NO;
static BOOL g_wm_failed = NO;
static BOOL g_wm_ready = NO;
static BOOL g_aim_rejected = NO;

static __thread BOOL g_inside_hook = NO;

#define TNX_MODE_MANAGER_OFF 0x28ULL
#define TNX_MGR_ARRAY_OFF 0x0ULL
#define TNX_MGR_COUNT_OFF 0xcULL

#define TNX_MGR_CAP_OFF 0x8ULL
#define TNX_MGR_CAP_MAX 4096

#define TNX_MODE_INPUTMGR_OFF 0x58ULL
#define TNX_INPUT_X_OFF 0xcULL
#define TNX_INPUT_Y_OFF 0x10ULL

#define TNX_MANAGER_MIN_OBJECTS 3

#define TNX_MANAGER_MAX_OBJECTS 96

#define TNX_MANAGER_PROBE_LIMIT 65536

#define TNX_CHAIN_PROBE_LIMIT 65536

#define TNX_DC_RVA_LO 0xf74000ULL
#define TNX_DC_RVA_SIZE 0xd4000ULL

#define TNX_VTPROBE_COUNT 9

static const uintptr_t g_vtprobe_rva[TNX_VTPROBE_COUNT] = {
    0x1002548,
    0xff5148, 0xff51f8, 0xff5500, 0xff5648, 0xff5720, 0xff57f8, 0xff58c8,
    0x1008d30,
};

#define TNX_OWNER_VOTE_MAX 128
#define TNX_OWNER_VOTE_MIN 3
#define TNX_OWNER_VOTE_GID_MAX 64
#define TNX_OWNER_VOTE_VT_MAX 4

#define TNX_OWNER_VOTE_TEAMS_MIN 2
#define TNX_OBJ_OWNERIDX_MAX 0xff

#define TNX_OWNER_VOTE_CONFIRM 1

#define TNX_OWNER_VOTE_DETAIL_MAX 12

#define TNX_OBJ_HIT_DUMP_MAX 64
#define TNX_OBJ_HIT_PRINT_MAX 24

#define TNX_VTCENSUS_MAX 384
#define TNX_VTCENSUS_PRINT 16
#define TNX_VTCENSUS_SLOTS 12

#define TNX_V50_WATCH_RVA 0x1009290ULL
#define TNX_VTCENSUS_INST 4

#define TNX_HEAP_SCAN_BUDGET_MAX (768ull * 1024ull * 1024ull)

#define TNX_OBJ_GLOBALID_OFF 0x8ULL

#define TNX_OBJ_TEAM_OFF 0x40ULL
#define TNX_OBJ_OWNERINDEX_OFF 0x3cULL
#define TNX_OBJ_DEADFLAG_OFF 0xd0ULL

#define TNX_OBJ_TEAM_MAX 7

#define TNX_OBJ_GETX_SLOT 0x88ULL
#define TNX_OBJ_GETY_SLOT 0x90ULL
#define TNX_MODE_MODEVAR_OFF 0x124ULL

#define TNX_MODE_PREDICTX_OFF 0x1d4ULL
#define TNX_MODE_PREDICTY_OFF 0x1d8ULL
#define TNX_MODE_STARS0_OFF 0x1e8ULL
#define TNX_MODE_STARS1_OFF 0x1ecULL
#define TNX_MODE_SLOT_A 0x218ULL
#define TNX_MODE_SLOT_B 0x220ULL
#define TNX_MODE_SLOT_C 0x228ULL

#define TNX_SLOT_BRIDGE_OFF 0x8ULL

#define TNX_SLOT_OWNER_OFF 0x20ULL
#define TNX_SLOT_LIST_OFF 0x80ULL
#define TNX_SLOT_LISTCOUNT_OFF 0x8cULL

#define TNX_BUILD_TAG "titanox_65"

#define TNX_RVA_SETPREDICTION 0x00ac3f20ULL
#define TNX_OBJ_X_OFF 0x30ULL
#define TNX_OBJ_Y_OFF 0x34ULL
#define TNX_OBJ_TEAMENGINE_OFF 0x4cULL
#define TNX_OBJ_ACTIVEFLAG_OFF 0x1e8ULL
#define TNX_MODE_TILEMAP_OFF 0xf8ULL
#define TNX_TILEMAP_WIDTH_OFF 0xc4ULL
#define TNX_TILEMAP_HEIGHT_OFF 0xc8ULL

#define TNX_V47_COORD_ABS_MAX 1000000
#define TNX_V47_MAP_MIN 4
#define TNX_V47_MAP_MAX 512
#define TNX_V47_OBJECT_MAX 64
#define TNX_V47_DODGE_MIN_MS 100
#define TNX_V47_LOG_FIRST 12
#define TNX_V47_LOG_EVERY 64

#define TNX_V47_REPROBE_MS 5000

#define TNX_V56_COUNT_MAX 96
#define TNX_V56_WALK_STEP 40
#define TNX_V56_MODE_WAIT_TICKS 30
#define TNX_V56_ROUTE_WAIT_TICKS 60

#define TNX_V57_GETOWN_RVA 0x00b90a28ULL

#define TNX_V57_MODE_REVERIFY_TICKS 2
#define TNX_V57_STALE_MAX 3
#define TNX_V57_REJECT_MAX 8
#define TNX_V57_ASCII_WINDOW 32

#define TNX_V59_CHAIN_MIN_TICKS 2
#define TNX_V59_SLOT_WIDE 100
#define TNX_V59_DROP_TICKS 60
#define TNX_V59_TAG_MAX 24

#define TNX_V60_IMAGE_SPAN 0x1164000ULL

#define TNX_V61_CHAIN_STABLE_TICKS 3

#define TNX_V63_HB_TICKS 5
#define TNX_V63_BUCKET_TICKS 10
#define TNX_V63_D6_WAIT_SECS 15
#define TNX_V63_QUIET_SECS 10
#define TNX_V63_KNOWN_VT_COUNT 4

#define TNX_V65_MODESIG_TICKS 3

#define TNX_V47_OWN_MAX_SQ 100000000LL

#define TNX_CAVE_MIN_RUN 96
#define TNX_CAVE_PAGE_LIMIT 64

#define TNX_TEXT_RVA_LO 0x4000ULL
#define TNX_TEXT_RVA_SIZE 0xf70000U

#define TNX_RVA_ADDGAMEOBJECT 0x00a278a8ULL
#define TNX_AG_OBJECT_MAX 16

#define TNX_RVA_CAVE_WINDOW 0x00dc0000ULL
#define TNX_CAVE_WINDOW_SIZE 0x10000U

#define TNX_VOTESCAN_GLOBAL_EVERY 10

#define TNX_MODE_MIN_TYPES 2
#define TNX_MODE_TYPE_MAX 16

#define TNX_SNAPSHOT_OBJECTS 12
#define TNX_SNAPSHOT_BYTES 0x140
#define TNX_SNAPSHOT_DELAY 1.2
#define TNX_VOTESCAN_INTERVAL 1.0
#define TNX_VOTESCAN_ATTEMPTS 600

#define TNX_HEAP_SCAN_BUDGET (512ull * 1024ull * 1024ull)

#define TNX_VOTESCAN_HEAP_EVERY 5

#define TNX_MODE_MIN_OBJECTS 3
#define TNX_VOTESCAN_HEARTBEAT 30
#define TNX_HEAP_CHUNK (8u * 1024u * 1024u)

#define TNX_VTABLE_SEGMENT "__DATA_CONST"
#define TNX_VTABLE_SEGMENT_ALT "__DATA"

static const uintptr_t g_mode_vtables_verified[] = { 0x1002548, 0xff5720, 0 };

#define TNX_MODE_VTABLE_PRIMARY 0x1002548ULL

static int tnx_verified_vtable(uintptr_t vtable) {
    if (!g_base || vtable <= g_base) return -1;

    uintptr_t rva = vtable - g_base;

    for (int i = 0; g_mode_vtables_verified[i]; i++) {
        if (rva == g_mode_vtables_verified[i]) return i;
    }

    return -1;
}

static uintptr_t g_mode_object = 0;
static BOOL g_mode_strong = NO;
static int g_mode_best_objects = 0;
static int g_mode_last_types = 0;
static int g_mode_verified_hits = 0;
static uintptr_t g_manager_object = 0;
static int g_manager_count = 0;
static int g_manager_probes = 0;
static int g_manager_probes_total = 0;
static int g_manager_skipped = 0;
static int g_manager_last_live = 0;
static int g_manager_last_nonempty = 0;
static int g_manager_last_capacity = 0;
static int g_manager_saw_cap = 0;
static int g_manager_loose_count = 0;
static int g_manager_window_rejects = 0;

static int g_chain_checks = 0;
static int g_chain_ready = 0;
static int g_chain_probes = 0;
static int g_chain_skipped = 0;
static int g_chain_best_live = 0;
static int g_chain_best_own = 0;
static int g_chain_best_gid = 0;
static int g_seen_stable = 0;
static uintptr_t g_chain_vtable = 0;
static unsigned long long g_vtprobe_hits[TNX_VTPROBE_COUNT];

typedef struct {
    uintptr_t owner;
    int votes;
    int teamMask;
    int deadOk;
    int vtCount;
    uintptr_t vt[TNX_OWNER_VOTE_VT_MAX];
    uint32_t gidSeen[TNX_OWNER_VOTE_GID_MAX];
    int gidSeenCount;
    int gidFull;
} tnx_owner_vote_t;

static tnx_owner_vote_t g_owner_votes[TNX_OWNER_VOTE_MAX];
static int g_owner_vote_count = 0;
static unsigned long long g_objvote_hits = 0;
static unsigned long long g_objvote_skipped = 0;
static int g_objvote_dead_seen = 0;
static uintptr_t g_objvote_best_owner = 0;
static int g_objvote_best_gids = 0;
static uintptr_t g_objvote_prev_owner = 0;
static int g_objvote_confirm = 0;
static BOOL g_objvote_owner_ok = NO;

static unsigned long long g_objvote_owner_img = 0;
static unsigned long long g_objvote_obj_img = 0;
static int g_objvote_best_teamcount = 0;
static int g_objvote_best_gids_full = 0;
static int g_objvote_single_team_logs = 0;
static int g_heap_img_skip = 0;

typedef struct {
    uintptr_t at;
    uintptr_t vt;
    uintptr_t owner;
    int32_t gid;
    int32_t team;
    int32_t ownerIdx;
    int dead;
    int ownerClass;
} tnx_objhit_t;

static tnx_objhit_t g_objhits[TNX_OBJ_HIT_DUMP_MAX];
static int g_objhit_count = 0;
static int g_objhit_full = 0;
static unsigned long long g_objvote_owner_reg = 0;

static unsigned long long g_objvote_owner_above_win = 0;
static int g_objvote_max_votes = 0;
static uintptr_t g_objvote_top_owner = 0;

static unsigned long long g_objvote_shaped = 0;

typedef struct {
    uintptr_t rva;
    int seg;
    unsigned long long count;
    unsigned long long shaped;
    unsigned long long ownerEqVt;
    uintptr_t first;
    uintptr_t inst[TNX_VTCENSUS_INST];
    int instCount;
} tnx_vtcensus_t;

static tnx_vtcensus_t g_vtcensus[TNX_VTCENSUS_MAX];
static int g_vtcensus_used = 0;
static unsigned long long g_vtcensus_total = 0;
static unsigned long long g_vtcensus_spill = 0;
static uintptr_t g_vtcensus_dc_lo = 0;
static uintptr_t g_vtcensus_dc_hi = 0;
static uintptr_t g_vtcensus_d_lo = 0;
static uintptr_t g_vtcensus_d_hi = 0;

static unsigned long long g_vtprobe_pass[TNX_VTPROBE_COUNT];
static uintptr_t g_vtprobe_first[TNX_VTPROBE_COUNT];

static int g_heap_ro_skip = 0;
static int g_heap_big_skip = 0;
static unsigned long long g_heap_big_bytes = 0;
static int g_heap_huge_skip = 0;
static int g_heap_region_capped = 0;

static uintptr_t g_img_span_lo = 0;
static uintptr_t g_img_span_hi = 0;
static int g_img_span_ok = 0;

static int g_trail_best = 0;
static int g_manager_cap_rejects = 0;
static int g_manager_best_count = 0;
static int g_manager_best_live = 0;
static int g_heap_passes = 0;
static unsigned long long g_heap_covered = 0;
static uintptr_t g_heap_scan_next = 0;
static int g_scan_sig[2] = { -1, -1 };
static uintptr_t g_mode_source = 0;
static int g_mode_matches = 0;
static BOOL g_mode_scanned = NO;
static int g_mode_relaxed = 0;
static int g_mode_strict_logs = 0;
static int g_mode_near_logs = 0;
static int g_mode_relaxed_logs = 0;
static int g_votescan_attempts = 0;
static double g_votescan_last = 0.0;
static BOOL g_snapshot_first = NO;
static BOOL g_snapshot_second = NO;
static double g_snapshot_start = 0.0;

static tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];
static int g_objc_armed = 0;

static uintptr_t g_addr_getinstance = 0;
static uintptr_t g_addr_getownchar = 0;
static uintptr_t g_addr_getteam = 0;
static uintptr_t g_addr_getx = 0;
static uintptr_t g_addr_gety = 0;
static uintptr_t g_addr_setprediction = 0;
static uintptr_t g_addr_sendmovement = 0;
static uintptr_t g_addr_getclip = 0;
static uintptr_t g_addr_gettf = 0;
static uintptr_t g_addr_settext = 0;
static uintptr_t g_addr_setxy = 0;
static uintptr_t g_addr_addchild = 0;
static uintptr_t g_addr_battlescreen = 0;

static void *g_label_clip = NULL;
static void *g_label_tf = NULL;
static void *g_label_sc = NULL;
static char g_label_text[64] = {0};
static int g_label_updates = 0;

static uintptr_t tnx_strip_imp(IMP imp) {
#if defined(__has_feature)
#if __has_feature(ptrauth_calls)
    return (uintptr_t)ptrauth_strip((void *)imp, ptrauth_key_function_pointer);
#endif
#endif
    return (uintptr_t)imp;
}

static FILE *g_battle_log = NULL;
static BOOL g_battle_capture = NO;
static BOOL g_battle_header = NO;

static void tnx_battle_write(const char *utf8, size_t len) {
    if (!g_battle_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

        if (paths.count == 0) return;

        NSString *path = [paths[0] stringByAppendingPathComponent:@"Titanox.battle.log"];
        g_battle_log = fopen(path.UTF8String, "a");
    }

    if (!g_battle_log) return;

    if (!g_battle_header) {
        g_battle_header = YES;

        const char *header = "---- battle capture started ----\n";
        fwrite(header, 1, strlen(header), g_battle_log);
    }

    fwrite(utf8, 1, len, g_battle_log);
    fflush(g_battle_log);
}

static FILE *tnx_log_handle(void) {
    if (!g_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"Titanox.log"];
            g_log = fopen(logPath.UTF8String, "a");
        }
    }

    return g_log;
}

static void tnx_write_line(const char *text) {
    FILE *handle = tnx_log_handle();

    if (!handle || !text) return;
    if (g_log_written >= LOG_MAX_BYTES) return;

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *ts = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %s\n", ts, text];
    const char *utf8 = line.UTF8String;
    size_t len = strlen(utf8);

    fwrite(utf8, 1, len, handle);
    fflush(handle);

    g_log_written += (long)len;

    if (g_battle_capture && g_log_written < LOG_MAX_BYTES) {
        tnx_battle_write(utf8, len);
    }
}

static void tlog(NSString *msg) {
    if (!msg) return;

    tnx_write_line(msg.UTF8String);
}

static void tnx_logf(const char *format, ...) {
    if (!format) return;

    char buffer[2048];
    va_list args;

    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    tnx_write_line(buffer);
}

static void tnx_battle_begin(const char *why) {
    if (g_battle_capture) return;

    g_battle_capture = YES;

    tnx_logf("battle capture ON (%s) -> Documents/Titanox.battle.log", why ? why : "?");
}

#define TNX_SLOT_COUNT 19
#define TNX_SLOT_CLASSIC_COUNT 7
#define TNX_ALERT_SIGHTINGS 2
#define TNX_V52_ASCII_MIN 3

typedef uint64_t (*tnx_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                  uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

static tnx_slot_fn_t g_slot_orig[TNX_SLOT_COUNT] = { NULL };
static uintptr_t g_slot_object[TNX_SLOT_COUNT] = { 0 };

static uintptr_t g_slot_arg1[TNX_SLOT_COUNT] = { 0 };
static uint64_t g_slot_hits[TNX_SLOT_COUNT] = { 0 };
static uint64_t g_slot_hits_total = 0;
static int g_slot_installed[TNX_SLOT_COUNT] = { -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1 };
static int g_slot_slots[TNX_SLOT_COUNT] = { 0 };

static uint64_t g_v52_weak_rejected = 0;
static int g_v52_weak_logs = 0;
static int g_v55_chain_rej[20] = { 0 };
static int g_v55_chain_pass = -1;
static int g_v55_chain_probes_pass = 0;
static int g_v55_layout_logs = 0;
static int g_v55_adopt_refusals = 0;
static int g_v54_no_source_passes = 0;
static int g_v54_route_logged = 0;
static uint64_t g_v52_setpred_calls = 0;
static uintptr_t g_v52_setpred_this = 0;
static float g_v52_setpred_x = 0.0f;
static float g_v52_setpred_y = 0.0f;
static uint64_t g_v52_stringy_rejected = 0;
static int g_v52_stringy_logs = 0;
static int g_v52_low_votes_logs = 0;
static uint64_t g_v52_ascii_rejected = 0;
static uint32_t g_slot_reported_mask = 0;
static uint64_t g_slot_first_tick[TNX_SLOT_COUNT] = { 0 };
static uint32_t g_v50_never_dispatched_mask = 0;

static uint64_t g_v50_ticks = 0;
static uintptr_t g_slot_adopted = 0;
static int g_ag_adopted = 0;

static int g_v56_mode_ticks = 0;
static int g_v56_capture_done = 0;
static int g_v56_array_logged = 0;
static int g_v56_walk_last = -1;
static int g_v56_route_done = 0;
static int g_v56_objhit_logged = 0;
static uintptr_t g_v56_manager = 0;
static uintptr_t g_v56_array = 0;
static int g_v56_count = 0;
static uintptr_t g_v56_player = 0;
static int32_t g_v56_px = 0;
static int32_t g_v56_py = 0;
static int32_t g_v56_team = 0;
static int32_t g_v56_enemy_x[TNX_V56_COUNT_MAX] = { 0 };
static int32_t g_v56_enemy_y[TNX_V56_COUNT_MAX] = { 0 };
static int32_t g_v56_enemy_count = 0;

static int g_v57_cand_ticks = 0;
static uintptr_t g_v57_cand_this = 0;
static uintptr_t g_v57_cand_vt = 0;
static int g_v57_capture_rejects = 0;
static int g_v57_stale_ticks = 0;
static uintptr_t g_v57_rejected[TNX_V57_REJECT_MAX] = { 0 };
static int g_v57_rejected_count = 0;
static int g_v57_reject_logs = 0;
static int g_v57_coord_off = -1;
static int g_v57_stringy_slot = -1;
static uintptr_t g_v57_getown = 0;
static int g_v57_getown_logged = 0;
static int g_v59_chain_hits = 0;
static int g_v59_chain_stable = 0;
static uintptr_t g_v59_chain_mode = 0;
static uintptr_t g_v59_chain_vt = 0;
static uintptr_t g_v59_chain_mgr = 0;
static int g_v59_mode_from_chain = 0;
static int g_v59_idle_probe_logged = 0;
static uintptr_t g_v59_last_cand = 0;
static uintptr_t g_v59_last_vt = 0;
static char g_v59_last_why[96] = { 0 };
static char g_v59_drop_tags[TNX_V59_TAG_MAX][8];
static int g_v59_drop_count = 0;
static char g_v59_keep_tags[TNX_V59_TAG_MAX][8];
static int g_v59_keep_count = 0;
static int g_v60_class_rejects = 0;
static int g_v61_class_logs = 0;
static int g_v61_class_rejects = 0;
static int g_v61_weak_logs = 0;
static int g_v64_modesig_hits = 0;
static int g_v64_modesig_logs = 0;
static int g_v64_modesig_notfound = 0;
static int g_v65_sig_ticks = 0;
static int g_v65_sig_logs = 0;
static uintptr_t g_v65_sig_last = 0;
static int g_v62_class_pass = 0;
static int g_v62_alert_shown = 0;
static int g_v62_alerts_off = 0;
static const char *g_v62_mode_source = "none";
static const uintptr_t g_v63_known_vt[TNX_V63_KNOWN_VT_COUNT] = { 0xf924d0ULL, 0xf92538ULL,
                                                                  0xf92808ULL, 0xf92898ULL };
static int g_v63_hb_sig_prev = 0;
static int g_v63_d6_notdispatched = 0;
static int g_v63_bucket = 0;
static int g_v63_image_count = 0;
static uintptr_t g_v63_image_top_mgr = 0;
static int32_t g_v63_image_top_count = 0;
static int g_v63_image_first = 0;
static int g_v63_chain_vtchanged = 0;
static int g_v63_chain_stable_logged = 0;
static int g_v63_stringy_logs = 0;
static int g_v63_battle_active = 0;
static int g_v63_battle_last_tick = 0;
static const char *g_v63_battle_reason = "none";
static int g_v63_reason_logged = 0;
static uint64_t g_v57_last_arg1 = 0;
static uint64_t g_v57_last_arg2 = 0;

static void tnx_slot_diag(const char *why);
static void tnx_slot_fired_report(void);
static void tnx_v56_mode_capture(uintptr_t candidate);
static void tnx_v56_dodge_tick(void);
static const char *tnx_v57_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut);
static int tnx_v57_class_slot_ok(uintptr_t vtable);
static int tnx_v57_is_fn_start(uintptr_t address);
static int tnx_v57_owner_rejected(uintptr_t owner);
static void tnx_v57_owner_reject(uintptr_t owner);
static void tnx_v57_hook_triage(int index);
static void tnx_v57_drop_hook(int index);
static void tnx_v59_chain_capture(uintptr_t modeObject, uintptr_t vtable, uintptr_t manager);
static void tnx_v62_alert_menu(NSString *info);
static void tnx_v64_modesig_tick(void);
static BOOL tnx_v56_vtable_in_image(uintptr_t vtable);
static uintptr_t tnx_v60_strip_ptr(uintptr_t value);
static int tnx_v59_container_at(uintptr_t object, int32_t *countOut, int32_t *capOut, char *why,
                                size_t whyLen);
static int tnx_v60_container_resolve(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                     int32_t *capOut, char *why, size_t whyLen);
static int tnx_v63_battle_gate(void);
static void tnx_v63_log_heartbeat(void);
static void tnx_v59_hook_note(int index);
static void tnx_v59_hook_summary(void);
static uintptr_t tnx_v57_coord_x_off(void);
static uintptr_t tnx_v57_coord_y_off(void);
static BOOL tnx_read_ptr(uintptr_t address, void **out);

static BOOL tnx_obj_slot_fn(uintptr_t object, uintptr_t slot, uintptr_t *rvaOut);
static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty);
static void tnx_trail_dump(void);
static void tnx_best_candidate_dump(void);

static void tnx_report_manager(const char *tag, uintptr_t manager);
static int tnx_object_detail_readonly(uintptr_t manager, int limit);

static void tnx_autododge_v48(void);

static void tnx_slot_note(int index, void *self, uint64_t arg1) {
    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_first_tick[index]) g_slot_first_tick[index] = g_v50_ticks;

    if (!g_slot_object[index] && self) g_slot_object[index] = (uintptr_t)self;

    if (!g_slot_arg1[index] && arg1) g_slot_arg1[index] = (uintptr_t)arg1;
}

static uint64_t tnx_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(0, a0, a1);

    if (g_slot_orig[0]) return g_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(1, a0, a1);

    if (g_slot_orig[1]) return g_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(2, a0, a1);

    if (g_slot_orig[2]) return g_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(3, a0, a1);

    if (g_slot_orig[3]) return g_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(4, a0, a1);

    if (g_slot_orig[4]) return g_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(5, a0, a1);

    if (g_slot_orig[5]) return g_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(6, a0, a1);

    if (g_slot_orig[6]) return g_slot_orig[6](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(7, a0, a1);

    if (g_slot_orig[7]) return g_slot_orig[7](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(8, a0, a1);

    if (g_slot_orig[8]) return g_slot_orig[8](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(9, a0, a1);

    if (g_slot_orig[9]) return g_slot_orig[9](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(10, a0, a1);

    if (g_slot_orig[10]) return g_slot_orig[10](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(11, a0, a1);

    if (g_slot_orig[11]) return g_slot_orig[11](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(12, a0, a1);

    if (g_slot_orig[12]) return g_slot_orig[12](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(13, a0, a1);

    if (g_slot_orig[13]) return g_slot_orig[13](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(14, a0, a1);

    if (g_slot_orig[14]) return g_slot_orig[14](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(15, a0, a1);

    if (g_slot_orig[15]) return g_slot_orig[15](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(16, a0, a1);

    if (g_slot_orig[16]) return g_slot_orig[16](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(17, a0, a1);

    if (g_slot_orig[17]) return g_slot_orig[17](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(18, a0, a1);

    if (g_slot_orig[18]) return g_slot_orig[18](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static const struct {
    const char *tag;
    const char *shortTag;
    uintptr_t rva;
    uintptr_t slotRva;
    tnx_slot_fn_t replacement;
    int control;
} g_slot_specs[TNX_SLOT_COUNT] = {

    { "A1/vt1002548+10/ad4ed0", "A1", 0x00ad4ed0ULL, 0x01002598ULL, tnx_slot_repl_0, 0 },
    { "A2/vt1002548+07/ad521c", "A2", 0x00ad521cULL, 0x01002580ULL, tnx_slot_repl_1, 0 },

    { "B1/vt0ff5720+05/a2e5b8", "B1", 0x00a2e5b8ULL, 0x00ff5748ULL, tnx_slot_repl_2, 0 },

    { "B2/vt0ff5720+03/a2d250 setOwner", "B2", 0x00a2d250ULL, 0x00ff5738ULL, tnx_slot_repl_3, 0 },
    { "B3/vt0ff5720+07/a2d6ac", "B3", 0x00a2d6acULL, 0x00ff5758ULL, tnx_slot_repl_4, 0 },

    { "C1/Stage::addChild @c33690", "C1", 0x00c33690ULL, 0x01011f50ULL, tnx_slot_repl_5, 1 },
    { "C2/hotflag @b9dc24", "C2", 0x00b9dc24ULL, 0, tnx_slot_repl_6, 1 },

    { "D1/table10078b8 slot0 @b73424", "D1", 0x00b73424ULL, 0, tnx_slot_repl_7, 0 },
    { "D2/table10086c0 slot0 @b8ae70", "D2", 0x00b8ae70ULL, 0, tnx_slot_repl_8, 0 },
    { "D3/table10086c0 slot1 @b8ae74", "D3", 0x00b8ae74ULL, 0, tnx_slot_repl_9, 0 },
    { "D4/table1008c28 slot0 @b9afa8", "D4", 0x00b9afa8ULL, 0, tnx_slot_repl_10, 0 },
    { "D5/table1009290 slot0 @bad4e8", "D5", 0x00bad4e8ULL, 0, tnx_slot_repl_11, 0 },
    { "D6/table1009290 slot1 @bad4ec", "D6", 0x00000000ULL, 0, tnx_slot_repl_12, 1 },

    { "E1/table100a770 slot0 @bcfbe8", "E1", 0x00bcfbe8ULL, 0, tnx_slot_repl_13, 0 },
    { "E2/table100a770 slot1 @bcfc28", "E2", 0x00bcfc28ULL, 0, tnx_slot_repl_14, 0 },
    { "E3/table1008d30 slot0 @b9b85c", "E3", 0x00b9b85cULL, 0, tnx_slot_repl_15, 0 },
    { "E4/table1008d30 slot1 @b9b918", "E4", 0x00b9b918ULL, 0, tnx_slot_repl_16, 0 },
    { "E5/setClientPredictionMoveTo @b90b8c", "E5", 0x00b90b8cULL, 0, tnx_slot_repl_17, 1 },
    { "E6/sendMovement @7c13dc", "E6", 0x007c13dcULL, 0, tnx_slot_repl_18, 1 },
};

static void tnx_slot_fired_report(void) {
    uint64_t total = 0;
    int armedCount = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        const char *state = "not-attempted";
        void *current = NULL;
        int armed = 0;

        if (g_slot_installed[i] == 1) {
            armed = 1;
            armedCount++;
            state = (g_slot_slots[i] > 0) ? "armed-pointer" : "armed-noslot";

            if (g_slot_specs[i].slotRva &&
                tnx_read_ptr(g_base + g_slot_specs[i].slotRva, &current)) {
                if ((uintptr_t)current != (uintptr_t)g_slot_specs[i].replacement) {
                    state = "armed-REVERTED";
                }
            }
        } else if (g_slot_installed[i] == 0) {
            state = "install-failed";
        }

        total += g_slot_hits[i];

        tnx_logf("v55 hook %s %s armed=%d slots=%d slotRva=%#llx this=%p arg1=%p firstCallTick=%llu "
                 "hits=%llu tick=%llu",
                 g_slot_specs[i].shortTag, state, armed, g_slot_slots[i],
                 (unsigned long long)g_slot_specs[i].slotRva, (void *)g_slot_object[i],
                 (void *)g_slot_arg1[i], (unsigned long long)g_slot_first_tick[i],
                 (unsigned long long)g_slot_hits[i], (unsigned long long)g_v50_ticks);

        if (i == 6 && g_slot_installed[i] == 1 && g_slot_slots[i] < 100) {
            tnx_logf("v55 hook C2 weak: slots=%d where the 22:36 run had 443 - the target moved or "
                     "the table was rebuilt", g_slot_slots[i]);
        }

        if (i == 12 && g_v52_setpred_calls) {
            tnx_logf("v55 setprediction seen: calls=%llu this=%p target=(%.2f,%.2f)",
                     (unsigned long long)g_v52_setpred_calls, (void *)g_v52_setpred_this,
                     g_v52_setpred_x, g_v52_setpred_y);
        }

        if (g_slot_hits[i] == 0 && g_v50_ticks >= 30 && g_slot_installed[i] == 1) {
            if (!(g_v50_never_dispatched_mask & (1u << (unsigned)i))) {
                if (g_slot_slots[i] > TNX_V59_SLOT_WIDE && g_v50_ticks <= TNX_V59_DROP_TICKS) {
                    continue;
                }

                g_v50_never_dispatched_mask |= (1u << (unsigned)i);

                tnx_v59_hook_note(i);
            }
        }
    }

    tnx_v59_hook_summary();

    tnx_logf("v55 hooks total fired=%llu armed=%d of %d slots at tick=%llu", (unsigned long long)total,
             armedCount, TNX_SLOT_COUNT, (unsigned long long)g_v50_ticks);
}

static tnx_slot_fn_t g_ag_orig = NULL;
static int g_ag_installed = -1;
static uint64_t g_ag_hits = 0;
static uintptr_t g_ag_manager = 0;
static uintptr_t g_ag_objects[TNX_AG_OBJECT_MAX] = { 0 };
static int g_ag_objectCount = 0;

static void tnx_make_rwx(uintptr_t address, size_t length) {
    uintptr_t page = address & ~(uintptr_t)0x3fff;
    uintptr_t last = (address + length + 0x3fff) & ~(uintptr_t)0x3fff;
    kern_return_t result = vm_protect(mach_task_self(), (vm_address_t)page,
                                      (vm_size_t)(last - page), FALSE,
                                      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    tnx_logf("rwx %p..%p kr=%d", (void *)page, (void *)last, (int)result);
}

static int tnx_arm_cave_pages(void) {
    static uint8_t buffer[0x4000];
    uintptr_t first = g_base + TNX_TEXT_RVA_LO;
    uintptr_t last = first + TNX_TEXT_RVA_SIZE;
    int armed = 0;

    for (uintptr_t page = first; page + 0x4000 <= last; page += 0x4000) {
        vm_size_t got = 0;
        int best = 0;
        int run = 0;

        if (armed >= TNX_CAVE_PAGE_LIMIT) break;

        if (vm_read_overwrite(mach_task_self(), (vm_address_t)page, 0x4000,
                              (vm_address_t)buffer, &got) != KERN_SUCCESS) continue;

        if (got != 0x4000) continue;

        for (int i = 0; i + 4 <= 0x4000; i += 4) {
            uint32_t word = (uint32_t)buffer[i] | ((uint32_t)buffer[i + 1] << 8) |
                            ((uint32_t)buffer[i + 2] << 16) | ((uint32_t)buffer[i + 3] << 24);

            if (word == 0x00000000 || word == 0xd503201f) {
                run += 4;

                if (run > best) best = run;
            } else {
                run = 0;
            }
        }

        if (best < TNX_CAVE_MIN_RUN) continue;

        tnx_logf("cave page rva=%#llx run=%d", (unsigned long long)(page - g_base), best);

        tnx_make_rwx(page, 0x4000);

        armed++;
    }

    tnx_logf("cave pages armed=%d of limit=%d", armed, TNX_CAVE_PAGE_LIMIT);

    return armed;
}

static uint64_t tnx_ag_repl(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                            uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    g_ag_hits++;

    if (a0 && !g_ag_manager) g_ag_manager = (uintptr_t)a0;

    if (a1 && g_ag_objectCount < TNX_AG_OBJECT_MAX) {
        uintptr_t object = (uintptr_t)a1;
        BOOL known = NO;

        for (int i = 0; i < g_ag_objectCount; i++) {
            if (g_ag_objects[i] == object) {
                known = YES;
                break;
            }
        }

        if (!known) g_ag_objects[g_ag_objectCount++] = object;
    }

    if (g_ag_orig) return g_ag_orig(a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static void tnx_inline_install(uintptr_t rva, const char *tag, void *replacement,
                               tnx_slot_fn_t *original, int *status) {
    uintptr_t target = g_base + rva;

    *status = 0;

    if (!target) return;

    tnx_make_rwx(target, 0x4000);
    tnx_make_rwx(g_base + TNX_RVA_CAVE_WINDOW, TNX_CAVE_WINDOW_SIZE);

    if (!brk_install((void *)target, replacement)) {
        tnx_logf("inline %s: install failed target=%p (%s)", tag, (void *)target,
                 hook_last_error() ? hook_last_error() : "-");

        return;
    }

    *original = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    *status = 1;

    tnx_logf("inline %s: installed target=%p trampoline=%p", tag, (void *)target,
             (void *)*original);
}

static void tnx_slot_install_one(int index) {
    uintptr_t target = 0;
    int slots = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_installed[index] = 0;
    g_slot_slots[index] = 0;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    target = g_base + g_slot_specs[index].rva;

    if (!target) return;

    slots = hook_probe(target);

    if (slots <= 0) {
        tnx_logf("slot %s: not-found target=%p slots=0 in __DATA_CONST/__DATA - runtime inline "
                 "patching is not supported, so this target needs a data slot (%s)",
                 g_slot_specs[index].tag, (void *)target,
                 hook_last_error() ? hook_last_error() : "-");

        return;
    }

    if (!brk_install((void *)target, (void *)g_slot_specs[index].replacement)) {
        tnx_logf("slot %s: install failed target=%p (%s)", g_slot_specs[index].tag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    g_slot_orig[index] = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    g_slot_installed[index] = 1;
    g_slot_slots[index] = slots;

    tnx_logf("slot %s: installed target=%p original=%p mode=pointer slots=%d liveSlots=%d",
             g_slot_specs[index].tag, (void *)target, (void *)g_slot_orig[index], slots,
             brk_live_slot_count());
}

static void tnx_slot_hooks_install(void) {
    const char *flag = NULL;

    if (!g_base) return;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    flag = getenv("TITANOX_ALLOW_CODE_PATCH");

    tnx_logf("slot hooks: codePatch=%d flag=%s pointerSlots=%d limit=%d live=%d",
             hook_code_patch_allowed() ? 1 : 0, flag ? flag : "-",
             hook_pointer_count(), brk_slot_limit(), brk_live_slot_count());

    for (int i = 0; i < TNX_SLOT_COUNT; i++) tnx_slot_install_one(i);

    tnx_slot_diag("install");
}

static BOOL tnx_query_region(uintptr_t address,
                             vm_prot_t *protection,
                             vm_prot_t *maxProtection,
                             mach_vm_size_t *regionSize,
                             uintptr_t *regionStart) {
    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;

    kern_return_t result = vm_region_64(
        mach_task_self(),
        &regionAddress,
        &size,
        VM_REGION_BASIC_INFO_64,
        (vm_region_info_t)&info,
        &infoCount,
        &objectName
    );

    if (objectName != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), objectName);
    }

    if (result != KERN_SUCCESS || size == 0) return NO;
    if ((uintptr_t)regionAddress + (uintptr_t)size <= address) return NO;

    if (protection) *protection = info.protection;
    if (maxProtection) *maxProtection = info.max_protection;
    if (regionSize) *regionSize = (mach_vm_size_t)size;
    if (regionStart) *regionStart = (uintptr_t)regionAddress;

    return YES;
}

static BOOL tnx_addr_writable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if (size == 0 || size > 0x10000000ULL) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;

        uintptr_t next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

static BOOL tnx_read_bytes(uintptr_t address, void *out, size_t length) {
    if (!out || !length) return NO;
    if (!address) return NO;

    vm_size_t got = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)address,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)out,
        &got
    );

    return result == KERN_SUCCESS && got == (vm_size_t)length;
}

static BOOL tnx_pointer_plausible(uintptr_t value) {
    if (value < 0x10000) return NO;
    if (value & 7) return NO;

    return YES;
}

static BOOL tnx_read_u8(uintptr_t address, uint8_t *out) {
    return tnx_read_bytes(address, out, 1);
}

static BOOL tnx_read_i32(uintptr_t address, int32_t *out) {
    if (!out) return NO;
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

static BOOL tnx_read_f32(uintptr_t address, float *out) {
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

static BOOL tnx_read_ptr(uintptr_t address, void **out) {
    if (!out) return NO;
    if (address & 7) return NO;

    return tnx_read_bytes(address, out, sizeof(void *));
}

static void *tnx_read_global_ptr(uintptr_t rva) {
    if (!g_base || !rva) return NULL;

    void *value = NULL;

    if (!tnx_read_ptr(g_base + rva, &value)) return NULL;

    return value;
}

static const char *tnx_prologue_rule(uintptr_t address) {
    uint32_t first = 0;

    if (!tnx_read_u32(address, &first)) return "unreadable";

    if (first == 0xD503233F) return "paciasp";
    if (first == 0xD503237F) return "pacibsp";
    if ((first & 0xFFFFFF1F) == 0xD503241F) return "bti";

    if ((first & 0xFF800000u) == 0xA9800000u && ((first >> 5) & 31u) == 31u) return "stppre";
    if ((first & 0xFF8003FFu) == 0xD10003FFu) return "subsp";

    if (address >= 4) {
        uint32_t previous = 0;
        if (tnx_read_u32(address - 4, &previous) && previous == 0xD65F03C0) return "afterret";
    }

    return "none";
}

static BOOL tnx_looks_like_start(uintptr_t address) {
    const char *rule = tnx_prologue_rule(address);

    if (!rule) return NO;

    return strcmp(rule, "none") != 0 && strcmp(rule, "unreadable") != 0;
}

static size_t tnx_start_index(uintptr_t address, BOOL *exact) {
    size_t index = (size_t)-1;

    if (exact) *exact = NO;
    if (!g_starts || !g_starts_count) return index;

    size_t low = 0;
    size_t high = g_starts_count;

    while (low < high) {
        size_t mid = low + (high - low) / 2;

        if (g_starts[mid] <= address) low = mid + 1;
        else high = mid;
    }

    if (low == 0) return index;

    index = low - 1;

    if (exact) *exact = (g_starts[index] == address);

    return index;
}

static uintptr_t tnx_callable(uintptr_t rva) {
    if (!g_base || !rva) return 0;

    uintptr_t address = g_base + rva;

    if (!tnx_addr_executable(address)) return 0;
    if (!tnx_image_text_contains(g_base, address)) return 0;

    BOOL exact = NO;

    tnx_start_index(address, &exact);

    if (exact) return address;
    if (tnx_looks_like_start(address)) return address;

    return 0;
}

static uintptr_t tnx_pick(uintptr_t rvaA, uintptr_t rvaB) {
    uintptr_t a = tnx_callable(rvaA);
    if (a) return a;

    return tnx_callable(rvaB);
}

static void tnx_log_words(uintptr_t address, uint32_t *out, size_t count) {
    if (!out || !count) return;

    size_t bytes = count * sizeof(uint32_t);

    if (!tnx_read_bytes(address, out, bytes)) {
        memset(out, 0, bytes);
        return;
    }
}

static uintptr_t tnx_linkedit(uintptr_t fileOffset, uint64_t size) {
    if (!g_base) return 0;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return 0;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return 0;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return 0;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return 0;
        if (cursor + command->cmdsize > limit) return 0;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__LINKEDIT") == 0) {
                if (fileOffset < segment->fileoff) return 0;

                uint64_t delta = (uint64_t)fileOffset - segment->fileoff;

                if (delta > segment->filesize) return 0;
                if (size > segment->filesize - delta) return 0;
                if (delta > segment->vmsize) return 0;
                if (size > segment->vmsize - delta) return 0;

                return slide + (uintptr_t)segment->vmaddr + (uintptr_t)delta;
            }
        }

        cursor += command->cmdsize;
    }

    return 0;
}

static BOOL tnx_read_uleb(const uint8_t *bytes, size_t size, size_t *offset, uint64_t *value) {
    if (!bytes || !offset || !value) return NO;

    *value = 0;

    for (unsigned shift = 0; shift <= 63; shift += 7) {
        if (*offset >= size) return NO;

        uint8_t byte = bytes[(*offset)++];
        uint64_t payload = byte & 0x7f;

        if (shift == 63 && payload > 1) return NO;

        *value |= payload << shift;

        if (!(byte & 0x80)) return YES;
    }

    return NO;
}

static BOOL tnx_copy(uintptr_t source, void *destination, size_t length) {
    if (!source || !destination || !length) return NO;
    if (!tnx_addr_readable(source, length)) return NO;

    vm_size_t copied = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)source,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)destination,
        &copied
    );

    return result == KERN_SUCCESS && copied == (vm_size_t)length;
}

static BOOL tnx_text_section(uintptr_t *address, uint64_t *size) {
    if (!g_base) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__TEXT") == 0) {
                uint64_t room = (uint64_t)command->cmdsize - sizeof(struct segment_command_64);
                uint64_t count = room / sizeof(struct section_64);

                if (count > segment->nsects) count = segment->nsects;

                const struct section_64 *sections = (const struct section_64 *)(segment + 1);

                for (uint64_t s = 0; s < count; s++) {
                    if (strcmp(sections[s].sectname, "__text") != 0) continue;
                    if (!sections[s].size) continue;

                    if (address) *address = slide + (uintptr_t)sections[s].addr;
                    if (size) *size = sections[s].size;

                    return YES;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static BOOL tnx_start_word(uint32_t word) {
    if (word == 0xD503233F || word == 0xD503237F) return YES;
    if ((word & 0xFFFFFF1Fu) == 0xD503241Fu) return YES;
    if ((word & 0xFF800000u) == 0xA9800000u && ((word >> 5) & 31u) == 31u) return YES;
    if ((word & 0xFF8003FFu) == 0xD10003FFu) return YES;

    return NO;
}

static BOOL tnx_start_boundary(const uint8_t *bytes, size_t offset) {
    if (offset < 4) return NO;

    for (size_t back = 4, seen = 0; back <= offset && seen < 8; back += 4, seen++) {
        uint32_t word = 0;

        memcpy(&word, bytes + offset - back, 4);

        if (word == 0xD65F03C0) return YES;

        if (word == 0xD503201F) continue;
        if ((word & 0xFFFFFF1Fu) == 0xD503241Fu) continue;

        return NO;
    }

    return NO;
}

static void tnx_load_function_starts(void) {
    if (g_starts || !g_base) return;

    uintptr_t textAddress = 0;
    uint64_t textSize = 0;

    if (!tnx_text_section(&textAddress, &textSize)) {
        tnx_logf("starts no text section");
        return;
    }

    if (textSize < 64 || textSize > (64ull * 1024ull * 1024ull)) {
        tnx_logf("starts bad text size=%llu", (unsigned long long)textSize);
        return;
    }

    uint8_t *bytes = (uint8_t *)malloc((size_t)textSize);

    if (!bytes) {
        tnx_logf("starts alloc failed size=%llu", (unsigned long long)textSize);
        return;
    }

    if (!tnx_copy(textAddress, bytes, (size_t)textSize)) {
        free(bytes);
        tnx_logf("starts read failed");
        return;
    }

    size_t capacity = 32768;
    uintptr_t *starts = (uintptr_t *)malloc(capacity * sizeof(uintptr_t));

    if (!starts) {
        free(bytes);
        return;
    }

    size_t count = 0;

    for (size_t offset = 4; offset + 4 <= (size_t)textSize; offset += 4) {
        uint32_t word = 0;

        memcpy(&word, bytes + offset, 4);

        if (!tnx_start_word(word)) continue;
        if (!tnx_start_boundary(bytes, offset)) continue;

        if (count >= capacity) {
            size_t grown = capacity * 2;
            uintptr_t *larger = (uintptr_t *)realloc(starts, grown * sizeof(uintptr_t));

            if (!larger) break;

            starts = larger;
            capacity = grown;
        }

        starts[count++] = textAddress + offset;
    }

    free(bytes);

    if (!count) {
        free(starts);
        tnx_logf("starts scan empty");
        return;
    }

    g_starts = starts;
    g_starts_count = count;

    tnx_logf("starts scanned=%zu text=%p size=%llu first=%p last=%p",
             count, (void *)textAddress, (unsigned long long)textSize,
             (void *)starts[0], (void *)starts[count - 1]);
}

static BOOL tnx_valid_header(uintptr_t base) {
    if (!base) return NO;
    struct mach_header_64 header;

    if (!tnx_pointer_plausible(base)) return NO;
    if (!tnx_read_bytes(base, &header, sizeof(header))) return NO;

    if (header.magic != MH_MAGIC_64) return NO;
    if (header.ncmds == 0 || header.ncmds > 4096) return NO;
    if (header.sizeofcmds == 0) return NO;
    if (header.sizeofcmds > (4u * 1024u * 1024u)) return NO;
    if (!tnx_image_text_contains(base, base + 0x4000)) return NO;

    return YES;
}

static BOOL find_game_image(uintptr_t *out_base) {
    if (!out_base) return NO;

    uint32_t count = _dyld_image_count();
    if (count > 8192) count = 8192;

    uintptr_t fallback = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        uintptr_t base = (uintptr_t)_dyld_get_image_header(i);

        if (!path || !base) continue;
        if (!strstr(path, ".app/")) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "/usr/lib/")) continue;
        if (strstr(path, ".framework/")) continue;
        if (strstr(path, ".dylib")) continue;
        if (tnx_name_marks_host_runtime(path)) continue;
        if (!tnx_valid_header(base)) continue;

        BOOL matched = NO;

        for (int n = 0; g_image_names[n]; n++) {
            if (strstr(path, g_image_names[n])) {
                matched = YES;
                break;
            }
        }

        if (matched) {
            *out_base = base;
            return YES;
        }

        if (!fallback) fallback = base;
    }

    if (fallback) {
        *out_base = fallback;
        return YES;
    }

    return NO;
}

static void *tnx_sc_string(const char *utf8) {
    if (!utf8) return NULL;

    size_t blen = strlen(utf8);

    uint8_t *buf = (uint8_t *)malloc(16);
    if (!buf) return NULL;

    memset(buf, 0, 16);

    *(uint32_t *)(buf + 0) = (uint32_t)blen;
    *(uint32_t *)(buf + 4) = (uint32_t)blen;

    if (blen > 7) {
        uint8_t *data = (uint8_t *)malloc(blen + 1);
        if (!data) {
            free(buf);
            return NULL;
        }

        memcpy(data, utf8, blen);
        data[blen] = 0;

        *(void **)(buf + 8) = data;
    } else {
        memcpy(buf + 8, utf8, blen);
    }

    return buf;
}

static const char *tnx_skip_compound(const char *p) {
    char open = *p;
    char close = (open == '{') ? '}' : ((open == '(') ? ')' : ']');
    int depth = 0;

    while (*p) {
        if (*p == open) {
            depth++;
        } else if (*p == close) {
            depth--;
            if (depth == 0) {
                p++;
                break;
            }
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
        if (method_getName(list[i]) == sel) {
            found = YES;
            break;
        }
    }

    free(list);

    return found;
}

static Class tnx_owner_class(Class cls, SEL sel) {
    if (!cls || !sel) return Nil;

    for (Class c = cls; c; c = class_getSuperclass(c)) {
        if (tnx_class_owns_method(c, sel)) return c;
    }

    return Nil;
}

static tnx_objc_hook_t *tnx_objc_find(id self, SEL _cmd) {
    Class start = object_getClass(self);

    if (!start) return NULL;

    tnx_objc_hook_t *bySelector = NULL;
    int bySelectorCount = 0;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        tnx_objc_hook_t *hook = &g_objc_hooks[i];

        if (!hook->used || hook->sel != _cmd) continue;

        bySelector = hook;
        bySelectorCount++;

        for (Class c = start; c; c = class_getSuperclass(c)) {
            if (c == hook->cls) return hook;
        }
    }

    if (bySelectorCount == 1) return bySelector;

    return NULL;
}

static BOOL tnx_objc_targets(id self, tnx_objc_hook_t *hook) {
    if (!hook || hook->wantedCount <= 0) return NO;

    Class start = object_getClass(self);

    if (!start) return NO;

    for (int i = 0; i < hook->wantedCount; i++) {
        Class wanted = hook->wanted[i];

        if (!wanted) continue;

        for (Class c = start; c; c = class_getSuperclass(c)) {
            if (c == wanted) return YES;
        }
    }

    return NO;
}

static void tnx_objc_add_wanted(tnx_objc_hook_t *hook, Class cls) {
    if (!hook || !cls) return;

    for (int i = 0; i < hook->wantedCount; i++) {
        if (hook->wanted[i] == cls) return;
    }

    if (hook->wantedCount >= WANTED_MAX) return;

    hook->wanted[hook->wantedCount++] = cls;
}

static void tnx_run_autododge_legacy(void) {
    if (!g_addr_getinstance || !g_addr_getownchar) return;

    void *battleMode = ((fn_get_inst_t)g_addr_getinstance)();
    if (!tnx_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)g_addr_getownchar)(battleMode);
    if (!tnx_object_plausible(ownChar)) return;

    uint8_t ownDead = 0;
    if (!tnx_read_u8((uintptr_t)ownChar + OFF_GAMEOBJ_DEADFLAG, &ownDead)) return;
    if (ownDead) return;

    int ownX = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(ownChar) : 0;
    int ownY = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(ownChar) : 0;
    int ownTeam = g_addr_getteam ? ((fn_get_team_t)g_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!tnx_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!tnx_read_i32((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0) return;

    if (count > SCAN_MAX) count = SCAN_MAX;
    void *probe = NULL;

    if (!tnx_read_ptr((uintptr_t)objects, &probe)) return;
    if (count > 1 && !tnx_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return;

    float dodgeX = 0.0f;
    float dodgeY = 0.0f;
    BOOL danger = NO;

    for (int i = 0; i < count; i++) {
        void *obj = objects[i];

        if (!obj || obj == ownChar) continue;
        if (!tnx_object_plausible(obj)) continue;

        uint8_t objDead = 0;
        if (!tnx_read_u8((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!tnx_read_i32((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(obj) : 0;
        int ey = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(obj) : 0;

        float dx = (float)(ownX - ex);
        float dy = (float)(ownY - ey);
        float distSq = dx * dx + dy * dy;

        if (distSq > DODGE_RANGE_SQ || distSq < 1.0f) continue;

        float angle = 0.0f;
        if (!tnx_read_f32((uintptr_t)obj + OFF_PROJECTILE_SPAWNANGLE, &angle)) continue;
        if (!isfinite(angle)) continue;

        float vx = cosf(angle);
        float vy = sinf(angle);

        float dot = dx * vx + dy * vy;
        if (dot <= 0.0f) continue;

        float perpDist = fabsf(dx * vy - dy * vx);

        if (perpDist < DODGE_THREAT) {
            float nx = -vy;
            float ny = vx;

            if ((dx * nx + dy * ny) < 0.0f) {
                nx = -nx;
                ny = -ny;
            }

            float weight = 1.0f / (perpDist + 1.0f);
            dodgeX += nx * weight;
            dodgeY += ny * weight;
            danger = YES;
        }
    }

    if (!danger) return;

    float len = sqrtf(dodgeX * dodgeX + dodgeY * dodgeY);
    if (len <= 0.0001f) return;

    dodgeX /= len;
    dodgeY /= len;

    if (g_addr_setprediction) {
        int targetX = ownX + (int)(dodgeX * DODGE_STEP);
        int targetY = ownY + (int)(dodgeY * DODGE_STEP);
        ((fn_set_prediction_t)g_addr_setprediction)(battleMode, targetX, targetY);
    }

    if (!g_addr_sendmovement) return;

    void *inputMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_CLIENTINPUTMANAGER, &inputMgr)) return;
    if (!inputMgr) return;

    ((fn_send_movement_t)g_addr_sendmovement)(inputMgr, dodgeX, dodgeY);
}

static void tnx_run_autododge(void) {
    tnx_autododge_v48();
}

static void tnx_run_autoaim(void) {
    if (!g_addr_getinstance || !g_addr_getownchar || !g_addr_battlescreen) return;

    void *battleMode = ((fn_get_inst_t)g_addr_getinstance)();
    if (!tnx_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)g_addr_getownchar)(battleMode);
    if (!tnx_object_plausible(ownChar)) return;

    int ownX = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(ownChar) : 0;
    int ownY = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(ownChar) : 0;
    int ownTeam = g_addr_getteam ? ((fn_get_team_t)g_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!tnx_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!tnx_read_i32((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0) return;

    if (count > SCAN_MAX) count = SCAN_MAX;
    void *probe = NULL;

    if (!tnx_read_ptr((uintptr_t)objects, &probe)) return;
    if (count > 1 && !tnx_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return;

    float closestDistSq = 1.0e18f;
    int targetX = 0;
    int targetY = 0;
    BOOL found = NO;

    for (int i = 0; i < count; i++) {
        void *obj = objects[i];

        if (!obj || obj == ownChar) continue;
        if (!tnx_object_plausible(obj)) continue;

        uint8_t objDead = 0;
        if (!tnx_read_u8((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!tnx_read_i32((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(obj) : 0;
        int ey = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(obj) : 0;

        float dx = (float)(ex - ownX);
        float dy = (float)(ey - ownY);
        float distSq = dx * dx + dy * dy;

        if (distSq > 1.0f && distSq < closestDistSq) {
            closestDistSq = distSq;
            targetX = ex;
            targetY = ey;
            found = YES;
        }
    }

    if (!found) return;

    void *screen = NULL;
    if (!tnx_read_ptr(g_addr_battlescreen, &screen)) return;

    if (!tnx_object_plausible(screen)) {
        if (!g_aim_rejected) {
            g_aim_rejected = YES;
            tlog(@"autofire disabled: RVA_BATTLESCREEN__BATTLESCREEN is not a valid instance slot");
        }
        return;
    }

    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;

    if (!tnx_addr_writable(fireX, 4) || !tnx_addr_writable(fireY, 4)) {
        if (!g_aim_rejected) {
            g_aim_rejected = YES;
            tlog(@"autofire disabled: target offsets are not writable");
        }
        return;
    }

    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}

static UILabel *g_overlay = NULL;
static double g_overlay_last = 0.0;
static int g_scan_ticks = 0;

static void tnx_overlay_attach(NSString *text) {
    UIWindow *window = nil;

    for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
        if (candidate.isKeyWindow) {
            window = candidate;
            break;
        }
    }

    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;

    if (g_overlay && g_overlay.superview != window) {
        [g_overlay removeFromSuperview];
        g_overlay = nil;
    }

    if (!g_overlay) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 44.0, 520.0, 36.0)];

        label.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightBold];
        label.textColor = [UIColor colorWithRed:1.0 green:0.32 blue:0.32 alpha:1.0];
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
        label.userInteractionEnabled = NO;
        label.numberOfLines = 2;

        g_overlay = label;
    }

    g_overlay.text = text;

    if (!g_overlay.superview) [window addSubview:g_overlay];

    [g_overlay.superview bringSubviewToFront:g_overlay];
}

static void tnx_overlay_update(void) {
    char text[192];
    double now = CFAbsoluteTimeGetCurrent();

    if (g_overlay) {
        UILabel *stale = g_overlay;

        g_overlay = NULL;

        dispatch_async(dispatch_get_main_queue(), ^{
            [stale removeFromSuperview];
        });
    }

    return;

    if (now - g_overlay_last < 0.4) return;

    g_overlay_last = now;

    uint64_t slotHits = 0;
    uint64_t slotControl = 0;
    int slotInstalled = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) slotControl += g_slot_hits[i];
        else slotHits += g_slot_hits[i];

        if (g_slot_installed[i] == 1) slotInstalled++;
    }

    snprintf(text, sizeof(text), "%sTNX %s t=%d a=%d/%d hp=%d\nmx=%d ty=%d sl=%llu/%d ctl=%llu obj=%d",
             g_slot_adopted ? "*** BATTLE FOUND ***\n" : "", TNX_BUILD_TAG,
             g_scan_ticks, g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_mode_best_objects, g_mode_last_types, (unsigned long long)slotHits,
             slotInstalled, (unsigned long long)slotControl, g_mode_object ? 1 : 0);

    NSString *string = [NSString stringWithUTF8String:text];

    dispatch_async(dispatch_get_main_queue(), ^{
        tnx_overlay_attach(string);
    });
}

static int g_alert_shown = 0;
static uint64_t g_alert_cleared_ms = 0;

static void tnx_alert_show(NSString *title, NSString *message) {

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        UIViewController *host = nil;

        for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }

        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;

        host = window.rootViewController;

        if (!host) return;

        while (host.presentedViewController) host = host.presentedViewController;

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:title
                                               message:message
                                        preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        [host presentViewController:alert animated:YES completion:nil];
    });
}

static void tnx_v62_alert_menu(NSString *info) {
    NSString *text = [info copy];

    if (g_v62_alert_shown || g_v62_alerts_off) return;

    g_v62_alert_shown = 1;

    tnx_logf("v65 battle entry alert shown src=D");

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        UIViewController *host = nil;

        for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }

        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;

        host = window.rootViewController;
        if (!host) return;

        while (host.presentedViewController) host = host.presentedViewController;

        UIAlertController *menu =
            [UIAlertController alertControllerWithTitle:@"Titanox v62"
                                                message:text
                                         preferredStyle:UIAlertControllerStyleAlert];

        [menu addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Состояние"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            g_v62_alert_shown = 0;

            tnx_v62_alert_menu([NSString stringWithFormat:
                @"mode=%p source=%s sigHits=%d\nchainHits=%d classesPass=%d\nmgr=%p count=%d",
                (void *)g_mode_object, g_v62_mode_source, g_v64_modesig_hits, g_v59_chain_hits,
                g_v62_class_pass, (void *)g_manager_object, g_manager_count]);
        }]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Скрыть алерты"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
            g_v62_alerts_off = 1;
        }]];

        [host presentViewController:menu animated:YES completion:nil];
    });
}

static int tnx_v64_modesig_hit(uintptr_t at) {
    void *vt = NULL;
    void *mgr = NULL;
    int32_t ec = 0;
    int32_t m124 = 0;
    int32_t count = 0;

    if (!at) return 0;
    if (!tnx_read_ptr(at, &vt) || !vt) return 0;
    if (!tnx_v56_vtable_in_image((uintptr_t)vt)) return 0;
    if (!tnx_read_i32(at + 0x124ULL, &m124) || m124 < 0x01 || m124 > 0x80) return 0;
    if (!tnx_read_i32(at + 0xecULL, &ec) || ec < -1024 || ec > 1024) return 0;
    if (!tnx_read_ptr(at + TNX_MODE_MANAGER_OFF, &mgr) || !mgr) return 0;
    if (!tnx_pointer_plausible((uintptr_t)mgr)) return 0;
    if (!tnx_read_i32((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count < 2 || count > TNX_MANAGER_MAX_OBJECTS) return 0;

    return 1;
}

static void tnx_v64_modesig_tick(void) {
    uintptr_t found = 0;

    if (g_mode_object) return;
    if (!g_v63_battle_active && (g_v50_ticks % TNX_V63_BUCKET_TICKS) != 0) return;

    for (int i = 0; i < g_objhit_count && !found; i++) {
        if (tnx_v64_modesig_hit(g_objhits[i].at)) found = g_objhits[i].at;
    }

    if (!found) return;

    if (g_v65_sig_last == found) {
        g_v65_sig_ticks++;
    } else {
        g_v65_sig_last = found;
        g_v65_sig_ticks = 1;

        if (g_v65_sig_logs < 12) {
            g_v65_sig_logs++;

            tnx_logf("v65 modesig hit obj=%p sighting=1/%d - a new address, the stability counter "
                     "restarts", (void *)found, TNX_V65_MODESIG_TICKS);
        }
    }

    if (g_v65_sig_ticks < TNX_V65_MODESIG_TICKS) return;

    {
        void *vt = NULL;
        void *mgr = NULL;
        int32_t ec = 0;
        int32_t m124 = 0;
        int32_t count = 0;
        int32_t cap = 0;

        g_v64_modesig_hits++;
        g_mode_object = found;
        g_v62_mode_source = "modesig";
        g_v63_battle_last_tick = (int)g_v50_ticks;

        tnx_read_ptr(found, &vt);
        tnx_read_ptr(found + TNX_MODE_MANAGER_OFF, &mgr);
        tnx_read_i32(found + 0xecULL, &ec);
        tnx_read_i32(found + 0x124ULL, &m124);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_CAP_OFF, &cap);

        tnx_logf("v65 modesig accepted obj=%p vt=%#llx ec=%d m124=%#x mgr=%p count=%d ticks=%d "
                 "src=SIG", (void *)found, (unsigned long long)(uintptr_t)vt, ec, (unsigned)m124,
                 mgr, count, g_v65_sig_ticks);

        if (count >= 2 && cap >= count && cap <= TNX_MGR_CAP_MAX) {
            g_manager_object = (uintptr_t)mgr;
            g_manager_count = count;

            tnx_logf("v65 modesig container obj=%p mgr=%p count=%d cap=%d src=SIG", (void *)found,
                     mgr, count, cap);
        }
    }
}

static void tnx_v63_flush_buckets(void) {
    if (g_v63_image_count > 0) {
        tnx_logf("v65 image-resident: %d rejections in last %ds (top mgr=%p count=%d)",
                 g_v63_image_count, TNX_V63_BUCKET_TICKS, (void *)g_v63_image_top_mgr,
                 g_v63_image_top_count);

        g_v63_image_count = 0;
        g_v63_image_top_mgr = 0;
        g_v63_image_top_count = 0;
    }

    tnx_logf("v65 chain: hits=%d vtableChanged=%d classPass=%d", g_v59_chain_hits,
             g_v63_chain_vtchanged, g_v62_class_pass);

    g_v63_chain_vtchanged = 0;
    g_v63_chain_stable_logged = 0;
}

static int tnx_v63_battle_gate(void) {
    int sigGrew = g_v64_modesig_hits > g_v63_hb_sig_prev;

    if (sigGrew) {
        g_v63_battle_last_tick = (int)g_v50_ticks;

        if (!g_v63_battle_active) {
            g_v63_battle_active = 1;
            g_v63_battle_reason = "modesig";

            tnx_logf("v65 battle state: inactive -> active reason=%s", g_v63_battle_reason);

            if (!g_v62_alert_shown && !g_v62_alerts_off) {
                NSString *info =
                    [NSString stringWithFormat:@"mode=%p mgr=%p count=%d\nsigHits=%d",
                                               (void *)g_mode_object, (void *)g_manager_object,
                                               g_manager_count, g_v64_modesig_hits];

                tnx_logf("v65 alert shown at first battle entry src=%s", g_v63_battle_reason);

                tnx_v62_alert_menu(info);
            }
        }
    } else if (g_v63_battle_active &&
               ((int)g_v50_ticks - g_v63_battle_last_tick) >= TNX_V63_QUIET_SECS) {
        g_v63_battle_active = 0;

        tnx_logf("v65 battle state: active -> inactive reason=quiet-10s");
    }

    return g_v63_battle_active;
}

static void tnx_v63_log_heartbeat(void) {
    int sigDelta = g_v64_modesig_hits - g_v63_hb_sig_prev;

    tnx_logf("v65 hb tick=%llu battle=%d modesigHits=%d sigLast=%d chainHits=%d classesPass=%d "
             "g_mode=%p src=%s mgr=%p count=%d", (unsigned long long)g_v50_ticks,
             g_v63_battle_active, g_v64_modesig_hits, sigDelta, g_v59_chain_hits, g_v62_class_pass,
             (void *)g_mode_object, g_v62_mode_source, (void *)g_manager_object, g_manager_count);

    g_v63_hb_sig_prev = g_v64_modesig_hits;

    if ((g_v50_ticks % TNX_V63_BUCKET_TICKS) == 0) tnx_v63_flush_buckets();

    if (g_v64_modesig_hits == 0 && g_v50_ticks >= TNX_V63_D6_WAIT_SECS &&
        !g_v64_modesig_notfound) {
        g_v64_modesig_notfound = 1;

        tnx_logf("v65 modesig not-found at t=%ds - the mode signature did not match", 
                 TNX_V63_D6_WAIT_SECS);
    }
}

typedef struct {
    int elements;
    int live;
    int teamCount;
    int distinctGids;
    int deadOk;
    uintptr_t vt0;
} tnx_v50_facts_t;

#define TNX_V50_GID_SEEN 64

static void tnx_v50_container_facts(uintptr_t manager, tnx_v50_facts_t *facts) {
    void *array = NULL;
    int32_t count = 0;
    uint64_t teamMask = 0;
    int32_t gids[TNX_V50_GID_SEEN];
    int gidCount = 0;

    if (!facts) return;

    memset(facts, 0, sizeof(*facts));

    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;

    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;
        int32_t gid = 0;
        int32_t team = 0;
        uint8_t dead = 0;
        uintptr_t rva = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        facts->elements++;

        if (!tnx_read_ptr((uintptr_t)element, &vtable) || !vtable) continue;

        rva = (uintptr_t)vtable - g_base;

        if (rva < TNX_DC_RVA_LO || rva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) continue;

        facts->live++;

        if (!facts->vt0) facts->vt0 = rva;

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        if (team >= 0 && team <= TNX_OBJ_TEAM_MAX) teamMask |= (1ull << team);

        if (dead <= 1) facts->deadOk++;

        {
            int known = 0;

            for (int j = 0; j < gidCount; j++) {
                if (gids[j] == gid) {
                    known = 1;

                    break;
                }
            }

            if (!known && gidCount < TNX_V50_GID_SEEN) gids[gidCount++] = gid;
        }
    }

    facts->distinctGids = gidCount;

    for (int t = 0; t <= TNX_OBJ_TEAM_MAX; t++) {
        if (teamMask & (1ull << t)) facts->teamCount++;
    }
}

static int g_v50_alert_streak = 0;
static uintptr_t g_v50_alert_streak_ptr = 0;
static uint64_t g_v50_alert_calls = 0;
static int g_v50_alert_withheld_logs = 0;

static void tnx_alert_battle_check(void) {
    uintptr_t candidate = 0;
    tnx_v50_facts_t facts;
    uint64_t now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
    int armed = 0;
    int withheld = 0;
    int counted = 0;
    const char *why = "no candidate";

    memset(&facts, 0, sizeof(facts));

    g_v50_alert_calls++;

    if (g_mode_object) candidate = g_mode_object;
    else if (g_manager_object) candidate = g_manager_object;

    if (!candidate) {
        why = "mode=0 and manager=0 (the scanner's hit is not a container)";
    } else {
        tnx_v50_container_facts(candidate, &facts);

        if (facts.live < 2) {
            why = "live<2";
        } else if (facts.teamCount < 2) {
            why = "teamCount<2";
        } else {

            if (g_v50_alert_streak_ptr == candidate) g_v50_alert_streak++;
            else {
                g_v50_alert_streak_ptr = candidate;
                g_v50_alert_streak = 1;
            }

            counted = 1;

            if (g_v50_alert_streak < TNX_ALERT_SIGHTINGS) {
                why = "sightings<3";
            } else {
                armed = 1;
            }
        }
    }

    if (!counted) {
        g_v50_alert_streak = 0;
        g_v50_alert_streak_ptr = 0;
    }

    if (!armed) withheld = 1;

    if (withheld) {

        if (g_v50_alert_withheld_logs < 5 || (g_v50_alert_calls % 1800) == 0) {
            g_v50_alert_withheld_logs++;

            tnx_logf("v55 alert withheld: %s bestLive=%d bestCount=%d mode=%p manager=%p "
                     "candidate=%p live=%d elements=%d teamCount=%d distinctGids=%d deadOk=%d "
                     "vt0=%#llx sightings=%d",
                     why, g_manager_best_live, g_manager_best_count, (void *)g_mode_object,
                     (void *)g_manager_object, (void *)candidate, facts.live, facts.elements,
                     facts.teamCount, facts.distinctGids, facts.deadOk,
                     (unsigned long long)facts.vt0, g_v50_alert_streak);
        }

        if (g_alert_shown) {
            if (g_alert_cleared_ms == 0) g_alert_cleared_ms = now;
            else if (now > g_alert_cleared_ms + 5000) {
                g_alert_shown = 0;
                g_alert_cleared_ms = 0;
            }
        }

        return;
    }

    g_alert_cleared_ms = 0;

    if (!g_alert_shown && now > 3000) {
        g_alert_shown = 1;

        tnx_logf("v55 battle entry: live=%d teamCount=%d distinctGids=%d deadOk=%d vt0=%#llx "
                 "sightings=%d bestLive=%d bestCount=%d mode=%p manager=%p candidate=%p -- showing "
                 "alert",
                 facts.live, facts.teamCount, facts.distinctGids, facts.deadOk,
                 (unsigned long long)facts.vt0, g_v50_alert_streak, g_manager_best_live,
                 g_manager_best_count, (void *)g_mode_object, (void *)g_manager_object,
                 (void *)candidate);

        tnx_alert_show(@"Titanox", @"Вход в бой обнаружен");
    }
}

static dispatch_source_t g_scan_timer = NULL;

static void tnx_render_watermark(void) {
    if (!g_base || g_wm_failed) return;

    if (!g_wm_ready) {
        if (!g_addr_getclip || !g_addr_gettf || !g_addr_settext || !g_addr_setxy || !g_addr_addchild) {
            g_wm_failed = YES;
            tlog(@"watermark disabled: unresolved address");
            return;
        }

        void *stage = tnx_read_global_ptr(OFF_STAGEINSTANCEGLOBALPTR);
        if (!tnx_object_plausible(stage)) return;

        void *scFile = tnx_sc_string(TNX_CLIP_FILE);
        void *scName = tnx_sc_string(TNX_CLIP_NAME);
        void *scText = tnx_sc_string(TNX_CLIP_TEXT);

        if (!scFile || !scName || !scText) return;

        void *clip = ((fn_ptr_2_t)g_addr_getclip)(scFile, scName);
        if (!tnx_object_plausible(clip)) return;

        void *tf = ((fn_ptr_2_t)g_addr_gettf)(clip, scText);
        if (!tnx_object_plausible(tf)) return;

        ((fn_setxy_t)g_addr_setxy)(clip, 60536.0f, 60536.0f);
        ((fn_void_2_t)g_addr_addchild)(stage, clip);

        g_label_clip = clip;
        g_label_tf = tf;
        g_wm_ready = YES;

        tlog([NSString stringWithFormat:@"watermark ready stage=%p clip=%p tf=%p", stage, clip, tf]);
    }

    if (!g_label_clip || !g_label_tf) return;

    if (strcmp(g_label_text, TNX_LABEL) != 0) {
        void *sc = tnx_sc_string(TNX_LABEL);
        if (!sc) return;

        g_label_sc = sc;
        snprintf(g_label_text, sizeof(g_label_text), "%s", TNX_LABEL);
    }

    if (!g_label_sc) return;

    ((fn_settext_t)g_addr_settext)(g_label_tf, g_label_sc, 4, 0);
    g_label_updates++;
}

static void tnx_locate_battle_mode(void);
static void tnx_slot_pump(void);

static void tnx_start_timer(void) {
    if (g_scan_timer) return;

    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    if (!timer) return;

    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);

    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval),
                              interval, (uint64_t)(0.25 * NSEC_PER_SEC));

    dispatch_source_set_event_handler(timer, ^{
        tnx_slot_pump();

        if (tnx_v63_battle_gate() || (g_v50_ticks % TNX_V63_BUCKET_TICKS) == 0) {
            tnx_locate_battle_mode();
        }

        tnx_v64_modesig_tick();
        tnx_v56_dodge_tick();

        g_scan_ticks++;
        g_v50_ticks++;

        if ((g_v50_ticks % TNX_V63_HB_TICKS) == 0) tnx_v63_log_heartbeat();

        if ((g_v50_ticks % 10) == 0) tnx_slot_fired_report();

        tnx_overlay_update();
    });

    dispatch_resume(timer);

    g_scan_timer = timer;

    tnx_logf("scan timer started (1 Hz, render hook no longer drives the scan)");

    tnx_v63_log_heartbeat();
}
static void tnx_dump_mode_objects(const char *tag);

static void tnx_run_workload(void) {
    tnx_locate_battle_mode();

    if (g_mode_object) {
        if (!g_snapshot_first) {
            g_snapshot_first = YES;
            g_snapshot_start = CFAbsoluteTimeGetCurrent();
            tnx_dump_mode_objects("a");
        } else if (!g_snapshot_second) {
            if (CFAbsoluteTimeGetCurrent() > (g_snapshot_start + TNX_SNAPSHOT_DELAY)) {
                g_snapshot_second = YES;
                tnx_dump_mode_objects("b");
            }
        }
    }

    tnx_run_autododge();
    tnx_run_autoaim();
    tnx_render_watermark();
    tnx_overlay_update();

    tnx_alert_battle_check();
}

static void tnx_objc_rep0(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook) hook->hits++;

    if (hook && !g_inside_hook && tnx_objc_targets(self, hook)) {
        g_inside_hook = YES;
        tnx_run_workload();
        g_inside_hook = NO;
    }

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL)>(hook->original)(self, _cmd);
    }
}

static void tnx_objc_rep1(id self, SEL _cmd, id a1) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, id)>(hook->original)(self, _cmd, a1);
    }
}

static void tnx_objc_rep1b(id self, SEL _cmd, BOOL a1) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, BOOL)>(hook->original)(self, _cmd, a1);
    }
}

static void tnx_objc_rep2(id self, SEL _cmd, id a1, id a2) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, id, id)>(hook->original)(self, _cmd, a1, a2);
    }
}

static int tnx_objc_arm(const char *clsName, const char *selName) {
    Class wanted = objc_getClass(clsName);

    if (!wanted) return 0;
    if (!tnx_image_owns_address(g_base, (uintptr_t)wanted)) return 0;

    SEL sel = sel_registerName(selName);

    Class owner = tnx_owner_class(wanted, sel);

    if (!owner) return 0;
    if (!tnx_image_owns_address(g_base, (uintptr_t)owner)) return 0;

    Method method = class_getInstanceMethod(owner, sel);

    if (!method) return 0;
    if (!sel_isEqual(method_getName(method), sel)) return 0;

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
        if (g_objc_hooks[i].cls != owner || g_objc_hooks[i].sel != sel) continue;

        tnx_objc_add_wanted(&g_objc_hooks[i], wanted);
        tlog([NSString stringWithFormat:@"objc hook %s -%s joined via %s", clsName, selName, class_getName(owner)]);
        return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (g_objc_hooks[i].used) continue;

        IMP previous = method_setImplementation(method, replacement);

        if (!previous) return 0;

        if (tnx_strip_imp(previous) == tnx_strip_imp(replacement)) {
            method_setImplementation(method, previous);
            tlog([NSString stringWithFormat:@"objc hook %s -%s rejected: original is self", clsName, selName]);
            return 0;
        }

        g_objc_hooks[i].used = YES;
        g_objc_hooks[i].cls = owner;
        g_objc_hooks[i].sel = sel;
        g_objc_hooks[i].original = previous;
        g_objc_hooks[i].replacement = replacement;
        g_objc_hooks[i].selName = selName;
        g_objc_hooks[i].signature = types;
        g_objc_hooks[i].hits = 0;
        g_objc_hooks[i].wantedCount = 0;

        tnx_objc_add_wanted(&g_objc_hooks[i], wanted);

        g_objc_armed++;

        tlog([NSString stringWithFormat:@"objc hook %s -%s armed via %s sig=%s orig=%p repl=%p",
              clsName, selName, class_getName(owner), types, (void *)previous, (void *)replacement]);

        uintptr_t originalRaw = tnx_strip_imp(previous);

        rt_dump_target(clsName, originalRaw);

        BOOL originalExact = NO;
        size_t originalIndex = tnx_start_index(originalRaw, &originalExact);

        tnx_logf("origCheck %s prologue=%s start=%d index=%d exec=%d text=%d",
                 clsName,
                 tnx_prologue_rule(originalRaw),
                 originalExact ? 1 : 0,
                 originalIndex == (size_t)-1 ? -1 : (int)originalIndex,
                 tnx_addr_executable(originalRaw) ? 1 : 0,
                 tnx_image_text_contains(g_base, originalRaw) ? 1 : 0);

        return 1;
    }

    return 0;
}

static void tnx_resolve_addresses(void) {
    if (!g_base) return;

    g_addr_getinstance = tnx_callable(RVA_BATTLEMODE_GETINSTANCE);
    g_addr_getownchar = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    g_addr_getteam = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    g_addr_getx = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    g_addr_gety = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);
    g_addr_setprediction = tnx_callable(RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO);
    g_addr_sendmovement = tnx_callable(RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT);
    g_addr_getclip = tnx_callable(RVA_STRINGTABLE_GETMOVIECLIP);
    g_addr_addchild = tnx_callable(RVA_STAGE_ADDCHILD);

    g_addr_gettf = tnx_pick(TNX_RVA_GETTEXTFIELDBYNAME_A, TNX_RVA_GETTEXTFIELDBYNAME_B);
    g_addr_settext = tnx_pick(TNX_RVA_SETTEXT_A, TNX_RVA_SETTEXT_B);
    g_addr_setxy = tnx_pick(TNX_RVA_SETXY_A, TNX_RVA_SETXY_B);

    g_addr_battlescreen = g_base + RVA_BATTLESCREEN__BATTLESCREEN;
    if (!tnx_addr_readable(g_addr_battlescreen, sizeof(void *))) g_addr_battlescreen = 0;

    tlog([NSString stringWithFormat:
          @"resolve aim=%d input=%d dodge=%d wm=%d screen=%d",
          (g_addr_getinstance && g_addr_getownchar && g_addr_getx && g_addr_gety && g_addr_getteam) ? 1 : 0,
          g_addr_sendmovement ? 1 : 0,
          g_addr_setprediction ? 1 : 0,
          (g_addr_getclip && g_addr_gettf && g_addr_settext && g_addr_setxy && g_addr_addchild) ? 1 : 0,
          g_addr_battlescreen ? 1 : 0]);
}

static void tnx_dump_rvas(void) {
    if (!g_base) return;

    tnx_logf("rva table image=%p", (void *)g_base);

    for (int i = 0; g_rvas[i].name; i++) {
        uintptr_t address = g_base + g_rvas[i].rva;
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uint32_t words[4] = {0, 0, 0, 0};

        BOOL region = tnx_query_region(address, &protection, NULL, &size, NULL);
        BOOL exact = NO;
        size_t index = tnx_start_index(address, &exact);
        uintptr_t nearest = (index != (size_t)-1) ? g_starts[index] : 0;
        uintptr_t next = (index != (size_t)-1 && (index + 1) < g_starts_count) ? g_starts[index + 1] : 0;
        unsigned long long into = nearest ? (unsigned long long)(address - nearest) : 0;

        tnx_log_words(address, words, 4);

        tnx_logf("rva %-48s off=0x%08llx addr=%p start=%d into=0x%llx near=%p next=%p prologue=%-8s callable=%d prot=%d words=%08x %08x %08x %08x",
                 g_rvas[i].name,
                 (unsigned long long)g_rvas[i].rva,
                 (void *)address,
                 exact ? 1 : 0,
                 into,
                 (void *)nearest,
                 (void *)next,
                 tnx_prologue_rule(address),
                 tnx_callable_target(g_base, address) ? 1 : 0,
                 region ? (int)protection : -1,
                 words[0], words[1], words[2], words[3]);
    }
}

static void tnx_probe_classes(void) {
    SEL sel = sel_registerName("render");

    for (int i = 0; g_probe_classes[i]; i++) {
        Class cls = objc_getClass(g_probe_classes[i]);

        if (!cls) {
            tnx_logf("probe class %-14s missing", g_probe_classes[i]);
            continue;
        }

        Method method = class_getInstanceMethod(cls, sel);
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        Class owner = tnx_owner_class(cls, sel);

        tnx_logf("probe class %-14s inImage=%d owns=%d method=%d owner=%s types=%s",
                 g_probe_classes[i],
                 tnx_image_owns_address(g_base, (uintptr_t)cls) ? 1 : 0,
                 tnx_class_owns_method(cls, sel) ? 1 : 0,
                 method ? 1 : 0,
                 owner ? class_getName(owner) : "-",
                 types ? types : "-");
    }
}

static const tnx_rva_entry_t g_verified[] = {
    { "-[MetalView render]", 0xd5646c },
    { "MessageManager::receiveMessage", 0x75d20c },
    { "LogicGameObjectManager::addGameObject", 0xa278a8 },
    { "LogicGameObjectManager::generateGameObjectGlobalID", 0xa27b98 },
    { "LogicBattleModeClient::getTeamStars", 0xac3cfc },
    { "LogicProjectileData::getColumnValue", 0x9cd5e0 },
    { "LogicBattleModeClient::slotA (this+0x218)", 0xac40d8 },
    { "LogicBattleModeClient::slotB (this+0x220)", 0xac40e8 },
    { "LogicBattleModeClient::slotC (this+0x228)", 0xac40f8 },
    { "LogicBattleModeClient::getInt (this+0xec)", 0xac3500 },
    { "LogicBattleModeClient::findOwningTeam (mgr+0x28,team@0x40)", 0xac3ddc },
    { "LogicBattleModeClient::findOwningTeam2 (mgr+0x28)", 0xac3e74 },
    { "LogicBattleModeClient::managerProgress (mgr+0x8c/0x90)", 0xac3f2c },
    { "GameObj::setOwner (this+0x20 = manager) [slot 0xff5738]", 0xa2d250 },
    { "LogicBattleModeClient::setPredictionXY (this+0x1d4/0x1d8)", 0xac3f20 },
    { "LogicGameObjectManager::findByTeam (mgr+0x0/+0xc)", 0xac3d80 },
    { "LogicGameObjectManager::addGameObject", 0xa278a8 },
    { "LogicGameObjectManager::generateGameObjectGlobalID", 0xa27b98 },
    { "LogicProjectileData::getColumnValue", 0x9cd5e0 },
    { "GameObj::setOwner (this+0x20 = manager)", 0xa2d250 },
    { "Array<T>::append (header layout source)", 0x46aefc },
    { "LogicGameObjectClient data accessor", 0x382cc8 },
    { "LogicBattleModeClient::getInt (+0xec)", 0xac3500 },
    { "LogicBattleModeClient::get 0x218", 0xac40d8 },
    { "LogicBattleModeClient::get 0x220", 0xac40e8 },
    { "LogicBattleModeClient::get 0x228", 0xac40f8 },
    { "TABLE_RVA_MESSAGEMANAGER__RECEIVEMESSAGE", 0x7bace8 },
    { NULL, 0 }
};

static void tnx_dump_structs(void) {
    tnx_logf("structs mode+0x%llx=manager mgr+0x%llx=array mgr+0x%llx=count obj+0x%llx=gid obj+0x%llx=team mode+0x%llx=modeVar mode+0x%llx/0x%llx=stars slots=0x%llx/0x%llx/0x%llx",
             TNX_MODE_MANAGER_OFF, TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF,
             TNX_OBJ_GLOBALID_OFF, TNX_OBJ_TEAM_OFF, TNX_MODE_MODEVAR_OFF,
             TNX_MODE_STARS0_OFF, TNX_MODE_STARS1_OFF,
             TNX_MODE_SLOT_A, TNX_MODE_SLOT_B, TNX_MODE_SLOT_C);
}

static void tnx_dump_verified(void) {
    if (!g_base) return;

    tnx_logf("verified anchors image=%p", (void *)g_base);

    for (int i = 0; g_verified[i].name; i++) {
        uintptr_t address = g_base + g_verified[i].rva;
        uint32_t words[4] = {0, 0, 0, 0};
        BOOL exact = NO;

        tnx_start_index(address, &exact);
        tnx_log_words(address, words, 4);

        tnx_logf("verified %-52s off=0x%08llx start=%d prologue=%-8s callable=%d words=%08x %08x %08x %08x",
                 g_verified[i].name,
                 (unsigned long long)g_verified[i].rva,
                 exact ? 1 : 0,
                 tnx_prologue_rule(address),
                 tnx_callable_target(g_base, address) ? 1 : 0,
                 words[0], words[1], words[2], words[3]);
    }
}

static BOOL tnx_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi) {
    if (!g_base || !name) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, name) == 0) {
                if (lo) *lo = slide + (uintptr_t)segment->vmaddr;
                if (hi) *hi = slide + (uintptr_t)segment->vmaddr + (uintptr_t)segment->vmsize;

                return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static BOOL tnx_image_contains(uintptr_t value) {
    if (!g_base || !value) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static void tnx_image_span_refresh(void) {
    g_img_span_lo = 0;
    g_img_span_hi = 0;
    g_img_span_ok = 0;

    if (!g_base || !tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) break;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) break;
        if (cursor + command->cmdsize > limit) break;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;
                uintptr_t end = start + (uintptr_t)segment->vmsize;

                if (!g_img_span_lo || start < g_img_span_lo) g_img_span_lo = start;
                if (end > g_img_span_hi) g_img_span_hi = end;
            }
        }

        cursor += command->cmdsize;
    }

    g_img_span_ok = (g_img_span_hi > g_img_span_lo) ? 1 : 0;
}

static BOOL tnx_in_image_span(uintptr_t value) {
    if (!value) return NO;
    if (!g_img_span_ok) return tnx_image_contains(value);

    return (value >= g_img_span_lo && value < g_img_span_hi) ? YES : NO;
}

static const char *tnx_image_segment_name(uintptr_t value) {
    if (!g_base || !value) return NULL;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NULL;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NULL;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NULL;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NULL;
        if (cursor + command->cmdsize > limit) return NULL;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) {
                    return segment->segname;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NULL;
}

#define TNX_HEAP_REGION_MAX 512
#define TNX_HEAP_REGION_MAX_SIZE 0x100000000ULL

typedef struct {
    uintptr_t low;
    uintptr_t high;
} tnx_region_t;

static tnx_region_t g_heap_regions[TNX_HEAP_REGION_MAX];
static int g_heap_region_count = 0;
static uintptr_t g_heap_window_low = 0;
static uintptr_t g_heap_window_high = 0;
static int g_heap_window_ok = 0;

static void tnx_heap_regions_refresh(void) {
    uintptr_t cursor = 0x10000;
    uintptr_t lowest = 0;
    uintptr_t highest = 0;
    int count = 0;

    for (int guard = 0; guard < 8192 && count < TNX_HEAP_REGION_MAX; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) break;
        if (size == 0) break;

        next = start + (uintptr_t)size;
        if (next <= cursor) break;

        if ((protection & VM_PROT_WRITE) &&
            size <= TNX_HEAP_REGION_MAX_SIZE &&
            start >= 0x10000 &&
            !tnx_image_segment_name(start)) {
            g_heap_regions[count].low = start;
            g_heap_regions[count].high = next;
            count++;

            if (!lowest || start < lowest) lowest = start;
            if (next > highest) highest = next;
        }

        cursor = next;
    }

    g_heap_region_count = count;
    g_heap_window_low = lowest;
    g_heap_window_high = highest;
    g_heap_window_ok = count > 0 ? 1 : 0;

    g_heap_region_capped = (count >= TNX_HEAP_REGION_MAX) ? 1 : 0;

    tnx_image_span_refresh();
}

static BOOL tnx_heap_window_shaped(uintptr_t value) {
    if (!value) return NO;
    if (!g_heap_window_ok) return YES;
    if (value < g_heap_window_low) return NO;
    if (value >= g_heap_window_high) return NO;

    return YES;
}

static BOOL tnx_heap_contains(uintptr_t value) {
    int lo = 0;
    int hi = g_heap_region_count - 1;

    if (!value) return NO;

    if (!g_heap_region_count) return tnx_image_segment_name(value) ? NO : YES;

    if (value < g_heap_window_low || value >= g_heap_window_high) return NO;

    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;

        if (value < g_heap_regions[mid].low) {
            hi = mid - 1;
        } else if (value >= g_heap_regions[mid].high) {
            lo = mid + 1;
        } else {
            return YES;
        }
    }

    return NO;
}

static BOOL tnx_vtable_shaped(uintptr_t value) {
    const char *segment = tnx_image_segment_name(value);

    if (!segment) return NO;
    if (value % 8) return NO;

    if (strcmp(segment, TNX_VTABLE_SEGMENT) == 0) return YES;
    if (strcmp(segment, TNX_VTABLE_SEGMENT_ALT) == 0) return YES;

    return NO;
}

static BOOL tnx_heap_resident(uintptr_t value) {
    if (!value) return NO;

    return tnx_image_segment_name(value) ? NO : YES;
}

static BOOL tnx_owner_is_heap(uintptr_t owner) {
    if (!owner) return NO;
    if (tnx_in_image_span(owner)) return NO;
    if (!tnx_heap_resident(owner)) return NO;

    return tnx_heap_contains(owner);
}

static BOOL tnx_gameobject_shape(uintptr_t object) {
    void *vtable = NULL;
    int32_t team = 0;
    uint8_t dead = 0;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;
    if (!tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team)) return NO;
    if (team < 0 || team > TNX_OBJ_TEAM_MAX) return NO;
    if (!tnx_read_u8(object + TNX_OBJ_DEADFLAG_OFF, &dead)) return NO;
    if (dead > 1) return NO;

    return YES;
}

static BOOL tnx_instance_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;
    if ((uintptr_t)vtable == object) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;

    return YES;
}

static BOOL tnx_object_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;

    return tnx_image_contains((uintptr_t)vtable);
}

static BOOL tnx_manager_shape(uintptr_t manager) {
    void *array = NULL;
    void *probe = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!tnx_heap_resident(manager)) return NO;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return NO;
    if (count < 0 || count > TNX_MANAGER_MAX_OBJECTS) return NO;

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return NO;

    if (array && !tnx_heap_resident((uintptr_t)array)) return NO;

    if (count > 0) {
        if (!array) return NO;
        if (!tnx_read_ptr((uintptr_t)array, &probe)) return NO;
        if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        if (count > 1) {
            if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return NO;
            if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        }
    }

    return YES;
}

static int tnx_mode_score(uintptr_t mode) {
    void *manager = NULL;
    void *array = NULL;
    int32_t variation = 0;
    int32_t count = 0;

    if (!tnx_instance_shaped(mode)) return 0;

    if (!tnx_read_i32(mode + TNX_MODE_MODEVAR_OFF, &variation)) return 0;
    if (variation < 0 || variation > 400) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &manager)) return 0;
    if (!manager) return 0;
    if (!tnx_manager_shape((uintptr_t)manager)) return 0;

    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;

    if (count > g_mode_best_objects) g_mode_best_objects = count;

    if (count < TNX_MODE_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;
    if (!array || !tnx_heap_resident((uintptr_t)array)) return 0;

    int verified = 0;
    int live = 0;
    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_heap_resident((uintptr_t)element)) continue;

        live++;

        if (tnx_gameobject_shape((uintptr_t)element)) verified++;

        void *elementVtable = NULL;

        if (!tnx_read_ptr((uintptr_t)element, &elementVtable)) continue;
        if ((uintptr_t)elementVtable <= g_base) continue;

        uintptr_t elementRva = (uintptr_t)elementVtable - g_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    g_mode_last_types = typeCount;

    if (live < TNX_MODE_MIN_OBJECTS) return 0;
    if (verified < TNX_MODE_MIN_OBJECTS) return 1;

    return (typeCount >= TNX_MODE_MIN_TYPES) ? 2 : 1;
}

static const uintptr_t g_mode_vtables[] = {
    0x10012c8, 0x1001318, 0x1001368, 0x10013b8,
    0x1001408, 0x1001458, 0x10014a8, 0x10014f8, 0x1001548, 0x1001598, 0x10015e8, 0x10016e0,
    0x10017d8, 0x10018c0, 0x1001908, 0x10019d0, 0x1001ac8, 0x1001bc0, 0x1001cb8, 0x1001d80,
    0x1001e48, 0x1001f10, 0x10022f0, 0x10023b8, 0x1002480, 0x1002548, 0x1002610,
    0x10026d8, 0x10027a0, 0x1002868, 0x1002930, 0x10029f8, 0x1002ac0, 0x1002b88, 0x1002d18,
    0,
};

static BOOL tnx_is_mode_vtable(uintptr_t value, uintptr_t *rvaOut) {
    if (!g_base || !value) return NO;

    for (int i = 0; g_mode_vtables[i]; i++) {
        if (value != (g_base + g_mode_vtables[i])) continue;

        if (rvaOut) *rvaOut = g_mode_vtables[i];

        return YES;
    }

    return NO;
}

static void tnx_report_mode_hit(const char *tag, uintptr_t slot, uintptr_t object) {
    uint32_t words[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    uintptr_t vtableRva = 0;
    uintptr_t managerVtableRva = 0;
    uintptr_t vtableOff = 0;
    const char *modeSeg = NULL;
    const char *vtableSeg = NULL;
    int score = 0;
    void *vtable = NULL;
    void *manager = NULL;
    void *managerVtable = NULL;
    void *array = NULL;
    void *entry = NULL;
    int32_t variation = 0;
    int32_t count = 0;

    tnx_read_ptr(object, &vtable);
    tnx_is_mode_vtable((uintptr_t)vtable, &vtableRva);

    if (g_base && (uintptr_t)vtable > g_base) vtableOff = (uintptr_t)vtable - g_base;

    modeSeg = tnx_image_segment_name(object);
    vtableSeg = tnx_image_segment_name((uintptr_t)vtable);
    score = tnx_mode_score(object);

    tnx_read_i32(object + TNX_MODE_MODEVAR_OFF, &variation);
    tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &manager);
    tnx_read_ptr((uintptr_t)manager, &managerVtable);
    tnx_is_mode_vtable((uintptr_t)managerVtable, &managerVtableRva);
    tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count);
    tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array);
    tnx_read_ptr((uintptr_t)array, &entry);
    tnx_read_bytes(object, words, sizeof(words));

    tnx_logf("modehit[%s] slot=%p mode=%p mdSeg=%s vt=%p vtSeg=%s vtOff=%#llx inList=%d primary=%d score=%d types=%d var=%d mgr=%p mgr0Rva=%#llx mgrShape=%d array=%p entry0=%p count=%d",
             tag, (void *)slot, (void *)object, modeSeg ? modeSeg : "-",
             vtable, vtableSeg ? vtableSeg : "-", (unsigned long long)vtableOff,
             tnx_is_mode_vtable((uintptr_t)vtable, NULL) ? 1 : 0,
             tnx_verified_vtable((uintptr_t)vtable) >= 0 ? 1 : 0,
             score, g_mode_last_types, variation,
             manager, (unsigned long long)managerVtableRva,
             tnx_manager_shape((uintptr_t)manager) ? 1 : 0, array, entry, count);

    for (int i = 0; i < 2; i++) {
        tnx_logf("modehit[%s] +%02x %08x %08x %08x %08x", tag, i * 16,
                 words[i * 4], words[i * 4 + 1], words[i * 4 + 2], words[i * 4 + 3]);
    }
}

static void tnx_adopt_mode(uintptr_t object, BOOL strong, const char *tag) {
    if (!object) return;
    if (g_mode_strong) return;
    if (g_mode_object == object && strong == g_mode_strong) return;
    if (g_mode_object && !strong) return;

    if (g_mode_object != object) {
        g_snapshot_first = NO;
        g_snapshot_second = NO;
        g_snapshot_start = 0.0;
    }

    g_mode_object = object;
    g_mode_source = 0;

    if (strong) g_mode_strong = YES;

    tnx_battle_begin(tag);

    tnx_logf("mode adopt tag=%s object=%p strong=%d maxObj=%d",
             tag, (void *)object, strong ? 1 : 0, g_mode_best_objects);

    tnx_report_mode_hit(tag, 0, object);
}

static void tnx_dump_protocol_methods(const char *name) {
    Protocol *protocol = objc_getProtocol(name);

    if (!protocol) {
        tnx_logf("proto %s absent", name);
        return;
    }

    unsigned required = 0;
    unsigned optional = 0;
    struct objc_method_description *req = protocol_copyMethodDescriptionList(protocol, YES, YES, &required);
    struct objc_method_description *opt = protocol_copyMethodDescriptionList(protocol, NO, YES, &optional);

    tnx_logf("proto %s required=%u optional=%u", name, required, optional);

    for (unsigned i = 0; req && i < required && i < 48; i++) {
        tnx_logf("proto %s req -%s types=%s", name, sel_getName(req[i].name),
                 req[i].types ? req[i].types : "-");
    }

    for (unsigned i = 0; opt && i < optional && i < 48; i++) {
        tnx_logf("proto %s opt -%s types=%s", name, sel_getName(opt[i].name),
                 opt[i].types ? opt[i].types : "-");
    }

    if (req) free(req);
    if (opt) free(opt);
}

static void tnx_dump_protocols(void) {
    unsigned total = 0;
    Protocol *__unsafe_unretained *list = objc_copyProtocolList(&total);
    int named = 0;

    for (unsigned i = 0; list && i < total; i++) {
        const char *name = protocol_getName(list[i]);

        if (!name) continue;

        if (strstr(name, "itan") || strstr(name, "attle") || strstr(name, "Titan") ||
            strstr(name, "Hook") || strstr(name, "View") || strstr(name, "Game")) {
            if (named++ < 60) tnx_logf("proto found %s", name);
        }
    }

    tnx_logf("proto total=%u interesting=%d", total, named);

    if (list) free(list);

    static const char *const classes[] = { "MetalView", "NullView", NULL };

    for (int i = 0; classes[i]; i++) {
        Class cls = objc_getClass(classes[i]);

        if (!cls) continue;

        objc_property_t property = class_getProperty(cls, "titanDelegate");

        tnx_logf("prop %s titanDelegate attrs=%s", classes[i],
                 property ? (property_getAttributes(property) ? property_getAttributes(property) : "-") : "absent");
    }

    static const char *const protocols[] = { "TitanViewDelegate", NULL };

    for (int i = 0; protocols[i]; i++) tnx_dump_protocol_methods(protocols[i]);
}

static void tnx_dump_hex(const char *tag, uintptr_t address, size_t bytes) {
    uint8_t buffer[0x100];

    if (bytes > sizeof(buffer)) bytes = sizeof(buffer);

    for (size_t offset = 0; offset + 16 <= bytes; offset += 16) {
        uint32_t words[4] = { 0, 0, 0, 0 };

        if (!tnx_copy(address + offset, buffer, 16)) break;

        memcpy(words, buffer, sizeof(words));

        tnx_logf("%s +%02zx %08x %08x %08x %08x", tag, offset, words[0], words[1], words[2], words[3]);
    }
}

static void tnx_dump_manager(uintptr_t manager, int count) {
    void *array = NULL;

    tnx_logf("mgr[dump] manager=%p count=%d", (void *)manager, count);
    tnx_dump_hex("mgr", manager, 0x40);

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return;
    if (!array) return;

    tnx_dump_hex("mgrArr", (uintptr_t)array, 0x40);

    for (int i = 0; i < count && i < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) return;
        if (!element) continue;

        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        uint8_t dead = 0;
        int32_t x = 0;
        int32_t y = 0;

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETY_SLOT, &s90);

        tnx_logf("mgr[%d] element=%p gameobj=%d gid=%d team=%d own=%d dead=%d "
                 "s88=%#llx s90=%#llx",
                 i, element, tnx_gameobject_shape((uintptr_t)element) ? 1 : 0,
                 globalId, team, owner, dead,
                 (unsigned long long)s88, (unsigned long long)s90);

        tnx_dump_hex("mgrObj", (uintptr_t)element, 0x100);
    }
}

static int tnx_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int live = 0;

    g_manager_last_capacity = 0;
    g_manager_last_live = 0;
    g_manager_last_nonempty = 0;

    if (!tnx_pointer_plausible(manager)) return 0;
    if (!tnx_heap_contains(manager)) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;

    g_manager_last_capacity = capacity;
    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;
    if (!array) return 0;
    if (!tnx_heap_contains((uintptr_t)array)) return 0;
    if ((uintptr_t)array & 0xf) return 0;

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return 0;

    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;
    int nonEmpty = 0;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        nonEmpty++;

        if (!tnx_heap_resident((uintptr_t)element)) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;
        if (!vtable) continue;
        if (!tnx_vtable_shaped((uintptr_t)vtable)) continue;

        if (!tnx_gameobject_shape((uintptr_t)element)) continue;

        live++;

        uintptr_t elementRva = (uintptr_t)vtable - g_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    if (typeCount < TNX_MODE_MIN_TYPES) return 0;

    g_manager_last_live = live;
    g_manager_last_nonempty = nonEmpty;

    if (live < TNX_MANAGER_MIN_OBJECTS || live * 4 < nonEmpty * 3) {
        g_manager_last_live = live;
        g_manager_last_nonempty = nonEmpty;
        g_manager_last_capacity = capacity;
        return 0;
    }

    g_manager_last_live = live;
    g_manager_last_nonempty = nonEmpty;
    g_manager_last_capacity = capacity;

    return live;
}

static unsigned int tnx_v52_byte(uintptr_t address, uintptr_t offset) {
    uint8_t value = 0;

    tnx_read_u8(address + offset, &value);

    return (unsigned int)value;
}

static int tnx_v52_ascii_word(uintptr_t address) {
    uint8_t bytes[8];
    int printable = 0;

    if (!tnx_read_bytes(address, bytes, sizeof(bytes))) return 0;

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable == 8 ? 1 : 0;
}

static int tnx_v52_stringy(uintptr_t manager, int32_t count) {
    void *array = NULL;
    int inspected = 0;
    int ascii = 0;

    if (count <= 0) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;

    if (count > TNX_V57_ASCII_WINDOW) count = TNX_V57_ASCII_WINDOW;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        inspected++;

        if (tnx_v52_ascii_word((uintptr_t)element)) {
            ascii++;

            g_v57_stringy_slot = (int)i;

            break;
        }
    }

    if (inspected < TNX_V52_ASCII_MIN) return 0;

    return ascii >= 1 ? 1 : 0;
}

static void tnx_probe_manager(uintptr_t cursor, size_t offset, const uint8_t *buffer, size_t chunk) {
    uint64_t arrayValue = 0;
    uint32_t count = 0;
    uintptr_t candidate = 0;
    int live = 0;

    if (g_mode_strong) return;
    if (offset + 0x10 > chunk) return;

    uint32_t capacity = 0;

    memcpy(&arrayValue, buffer + offset, sizeof(arrayValue));
    memcpy(&capacity, buffer + offset + TNX_MGR_CAP_OFF, sizeof(capacity));
    memcpy(&count, buffer + offset + 0xc, sizeof(count));

    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return;

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) {
        g_manager_saw_cap++;
        g_manager_cap_rejects++;
        return;
    }

    if (capacity > count * 2) {
        g_manager_saw_cap++;
        g_manager_cap_rejects++;
        return;
    }

    g_manager_saw_cap++;

    if (!tnx_pointer_plausible((uintptr_t)arrayValue)) return;

    if ((uintptr_t)arrayValue & 0xf) return;

    if (!tnx_heap_window_shaped((uintptr_t)arrayValue)) {
        g_manager_window_rejects++;
        return;
    }

    if (!tnx_heap_contains((uintptr_t)arrayValue)) {
        g_manager_window_rejects++;
        return;
    }

    g_manager_loose_count++;

    if (g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) {
        g_manager_skipped++;
        return;
    }

    g_manager_probes++;
    g_manager_probes_total++;

    candidate = cursor + offset;
    live = tnx_manager_live_count(candidate);

    if ((int)count > g_manager_best_count) g_manager_best_count = (int)count;
    if (live > g_manager_best_live) g_manager_best_live = live;

    if (tnx_v52_stringy(candidate, (int32_t)count)) {
        g_v52_stringy_rejected++;

        g_v63_stringy_logs++;

        if (g_v63_stringy_logs <= 2) {
            tnx_logf("v65 trail: stringy container refused before scoring mgr=%p count=%u live=%d "
                     "nonEmpty=%d firstTextSlot=%d - text never reaches the top eight",
                     (void *)candidate, count, g_manager_last_live, g_manager_last_nonempty,
                     g_v57_stringy_slot);
        } else if ((g_v63_stringy_logs % 10) == 0) {
            tnx_logf("v65 trail: stringy refused total=%d", g_v63_stringy_logs);
        }

        return;
    }

    if (live > 0 && live * 2 < (int)count) {
        g_v52_weak_rejected++;

        if (g_v52_weak_logs < 4) {
            g_v52_weak_logs++;

            tnx_logf("v55 trail: weak container refused mgr=%p count=%u live=%d nonEmpty=%d - "
                     "under half of its elements are objects, so it is not the array the dodge "
                     "needs", (void *)candidate, count, live, g_manager_last_nonempty);
        }

        return;
    }

    if (live < TNX_MANAGER_MIN_OBJECTS) {
        tnx_trail_note(candidate, (int32_t)count, g_manager_last_capacity,
                       g_manager_last_live, g_manager_last_nonempty);
        return;
    }

    if (!g_manager_object && !g_objvote_owner_ok) {
        g_manager_object = candidate;
        g_manager_count = (int)count;

        tnx_logf("MANAGER candidate object=%p count=%u live=%d recorded, NOT adopted",
                 (void *)candidate, count, live);

        tnx_dump_manager(candidate, (int)count);
    }
}

static int tnx_v55_container_ok(uintptr_t manager, int32_t *countOut) {
    void *array = NULL;
    int32_t count = 0;

    if (countOut) *countOut = 0;
    if (!manager) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0 || count > TNX_MANAGER_MAX_OBJECTS) return 0;

    if (countOut) *countOut = count;

    return 1;
}

static void tnx_v55_layout_dump(const char *tag, uintptr_t address, int words) {
    for (int base = 0; base < words; base += 4) {
        uintptr_t word[4] = { 0, 0, 0, 0 };
        char verdict[4][40];

        for (int k = 0; k < 4; k++) {
            void *array = NULL;
            int32_t count = 0;

            snprintf(verdict[k], sizeof(verdict[k]), "-");

            if (!tnx_read_ptr(address + (uintptr_t)(base + k) * 8, (void**)&word[k])) continue;

            if (!tnx_pointer_plausible(word[k])) continue;

            if (tnx_read_ptr(word[k] + TNX_MGR_ARRAY_OFF, &array) && array &&
                tnx_read_i32(word[k] + TNX_MGR_COUNT_OFF, &count) && count > 0 &&
                count <= TNX_MANAGER_MAX_OBJECTS) {
                snprintf(verdict[k], sizeof(verdict[k]), "ARRAYHDR count=%d", count);

                continue;
            }

            if (tnx_heap_window_shaped(word[k])) {
                snprintf(verdict[k], sizeof(verdict[k]), "heap");
            }
        }

        tnx_logf("v55 %s+%02x: %#llx %#llx %#llx %#llx | %s | %s | %s | %s", tag, base * 8,
                 (unsigned long long)word[0], (unsigned long long)word[1],
                 (unsigned long long)word[2], (unsigned long long)word[3], verdict[0], verdict[1],
                 verdict[2], verdict[3]);
    }
}

static void tnx_probe_mode_chain(uintptr_t cursor, size_t offset, const uint8_t *buffer,
                                 size_t chunk, uintptr_t dcLo, uintptr_t dcHi) {
    uintptr_t vtable = 0;
    uintptr_t manager = 0;
    uintptr_t input = 0;
    int32_t variation = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t count = 0;
    void *array = NULL;

    if (g_mode_strong) return;

    if (g_v55_chain_pass != g_heap_passes) {
        g_v55_chain_pass = g_heap_passes;
        g_v55_chain_probes_pass = g_chain_probes;
        g_chain_probes = 0;
    }

    if (offset + TNX_MODE_PREDICTY_OFF + 4 > chunk) return;

    memcpy(&vtable, buffer + offset, sizeof(vtable));

    if (!vtable || (vtable & 0x7)) { g_v55_chain_rej[0]++; return; }
    if (vtable < dcLo || vtable >= dcHi) { g_v55_chain_rej[1]++; return; }

    g_chain_checks++;

    memcpy(&manager, buffer + offset + TNX_MODE_MANAGER_OFF, sizeof(manager));

    if (!manager || (manager & 0xf)) { g_v55_chain_rej[2]++; return; }
    if (!tnx_pointer_plausible(manager)) { g_v55_chain_rej[3]++; return; }
    if (!tnx_heap_window_shaped(manager)) { g_v55_chain_rej[4]++; return; }

    if (!g_v63_battle_active) return;

    tnx_v59_chain_capture(cursor + offset, vtable, manager);

    memcpy(&variation, buffer + offset + TNX_MODE_MODEVAR_OFF, sizeof(variation));

    if (variation < 0 || variation > 400) { g_v55_chain_rej[5]++; return; }

    memcpy(&px, buffer + offset + TNX_MODE_PREDICTX_OFF, sizeof(px));
    memcpy(&py, buffer + offset + TNX_MODE_PREDICTY_OFF, sizeof(py));

    if (px < -0x100000 || px > 0x100000) { g_v55_chain_rej[6]++; return; }
    if (py < -0x100000 || py > 0x100000) { g_v55_chain_rej[7]++; return; }

    memcpy(&input, buffer + offset + TNX_MODE_INPUTMGR_OFF, sizeof(input));

    if (input && !tnx_heap_window_shaped(input)) { g_v55_chain_rej[8]++; return; }

    g_chain_ready++;

    if (g_chain_probes >= TNX_CHAIN_PROBE_LIMIT) {
        g_chain_skipped++;
        return;
    }

    g_chain_probes++;

    if (!tnx_manager_shape(manager)) { g_v55_chain_rej[9]++; return; }
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) { g_v55_chain_rej[10]++; return; }
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) { g_v55_chain_rej[11]++; return; }
    if (!array) { g_v55_chain_rej[12]++; return; }
    if (count < TNX_MODE_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) {
        g_v55_chain_rej[13]++;

        return;
    }

    int live = 0;
    int ownMatch = 0;
    int gidDistinct = 0;
    int32_t gids[TNX_MODE_TYPE_MAX];

    for (int i = 0; i < TNX_MODE_TYPE_MAX; i++) gids[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *owner = NULL;
        int32_t gid = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_gameobject_shape((uintptr_t)element)) continue;

        live++;

        if (tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid)) {
            BOOL known = NO;

            for (int k = 0; k < gidDistinct; k++) {
                if (gids[k] == gid) {
                    known = YES;
                    break;
                }
            }

            if (!known && gidDistinct < TNX_MODE_TYPE_MAX) gids[gidDistinct++] = gid;
        }

        if (tnx_read_ptr((uintptr_t)element + TNX_SLOT_OWNER_OFF, &owner)) {
            if ((uintptr_t)owner == manager) ownMatch++;
        }
    }

    if (live > g_chain_best_live) g_chain_best_live = live;
    if (ownMatch > g_chain_best_own) g_chain_best_own = ownMatch;
    if (gidDistinct > g_chain_best_gid) g_chain_best_gid = gidDistinct;

    uintptr_t object = cursor + offset;

    tnx_logf("chain cand mode=%p vt=%#llx mgr=%p count=%d live=%d ownMatch=%d gidDistinct=%d "
             "var=%d input=%p",
             (void *)object, (unsigned long long)(vtable - g_base), (void *)manager, count,
             live, ownMatch, gidDistinct, variation, (void *)input);

    if (live < TNX_MODE_MIN_OBJECTS) { g_v55_chain_rej[14]++; return; }
    if (ownMatch < 1) { g_v55_chain_rej[15]++; return; }
    if (gidDistinct < 2) { g_v55_chain_rej[16]++; return; }

    g_chain_vtable = vtable;

    tnx_adopt_mode(object, YES, "chain");
}

static void tnx_vtprobe_note(uintptr_t vtable, uintptr_t absolute) {
    uintptr_t rva = 0;

    if (!vtable || !g_base) return;
    if (absolute & 0xf) return;
    if (vtable < g_base + TNX_DC_RVA_LO) return;
    if (vtable >= g_base + TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return;

    rva = vtable - g_base;

    for (int k = 0; k < TNX_VTPROBE_COUNT; k++) {
        if (rva == g_vtprobe_rva[k]) {
            g_vtprobe_hits[k]++;

            if (!g_vtprobe_first[k]) g_vtprobe_first[k] = absolute;

            return;
        }
    }
}

static int tnx_vtcensus_seg(uintptr_t value) {
    if (!value || !g_base) return -1;
    if (g_vtcensus_dc_lo && value >= g_vtcensus_dc_lo && value < g_vtcensus_dc_hi) return 0;
    if (g_vtcensus_d_lo && value >= g_vtcensus_d_lo && value < g_vtcensus_d_hi) return 1;

    return -1;
}

static void tnx_vtcensus_reset(void) {
    g_vtcensus_used = 0;
    g_vtcensus_total = 0;
    g_vtcensus_spill = 0;

    memset(g_vtcensus, 0, sizeof(g_vtcensus));
}

static tnx_vtcensus_t *tnx_vtcensus_entry(uintptr_t rva, int seg, int create) {
    for (int i = 0; i < g_vtcensus_used; i++) {
        if (g_vtcensus[i].rva == rva && g_vtcensus[i].seg == seg) return &g_vtcensus[i];
    }

    if (!create) return NULL;
    if (g_vtcensus_used >= TNX_VTCENSUS_MAX) {
        g_vtcensus_spill++;

        return NULL;
    }

    tnx_vtcensus_t *entry = &g_vtcensus[g_vtcensus_used++];

    memset(entry, 0, sizeof(*entry));
    entry->rva = rva;
    entry->seg = seg;

    return entry;
}

static void tnx_vtcensus_note(uintptr_t vtable, uintptr_t absolute, const uint8_t *buffer,
                              size_t offset, size_t chunk) {
    if (absolute & 0xf) return;
    if (vtable & 7) return;

    int seg = tnx_vtcensus_seg(vtable);

    if (seg < 0) return;

    tnx_vtcensus_t *entry = tnx_vtcensus_entry(vtable - g_base, seg, 1);

    if (!entry) return;

    entry->count++;
    g_vtcensus_total++;

    if (!entry->first) entry->first = absolute;

    if (entry->instCount < TNX_VTCENSUS_INST) entry->inst[entry->instCount++] = absolute;

    if (offset + TNX_SLOT_OWNER_OFF + sizeof(uintptr_t) <= chunk) {
        uintptr_t w20 = 0;

        memcpy(&w20, buffer + offset + TNX_SLOT_OWNER_OFF, sizeof(w20));

        if (w20 == vtable) entry->ownerEqVt++;
    }
}

static void tnx_vtcensus_shaped(uintptr_t vtable) {
    int seg = tnx_vtcensus_seg(vtable);

    if (seg < 0) return;

    tnx_vtcensus_t *entry = tnx_vtcensus_entry(vtable - g_base, seg, 0);

    if (entry) entry->shaped++;
}

static int tnx_vtcensus_top(int byShaped) {
    int best = -1;

    for (int i = 0; i < g_vtcensus_used; i++) {
        unsigned long long here = byShaped ? g_vtcensus[i].shaped : g_vtcensus[i].count;

        if (!here) continue;

        if (best < 0) {
            best = i;

            continue;
        }

        unsigned long long there = byShaped ? g_vtcensus[best].shaped : g_vtcensus[best].count;

        if (here > there) best = i;
    }

    return best;
}

static void tnx_v50_table_probe(const tnx_vtcensus_t *entry) {
    int shaped = 0;
    int sameGid = 1;
    int32_t firstGid = 0;

    if (!entry) return;
    if (entry->rva != TNX_V50_WATCH_RVA) return;

    tnx_logf("v55 table probe rva=%#llx seg=%c count=%llu shaped=%llu instances=%d -- before this "
             "table is hooked",
             (unsigned long long)entry->rva, entry->seg ? 'D' : 'C', entry->count, entry->shaped,
             entry->instCount);

    for (int i = 0; i < entry->instCount; i++) {
        uintptr_t object = entry->inst[i];
        void *vtable = NULL;
        void *owner = NULL;
        int32_t gid = 0;
        int32_t team = 0;
        int32_t teamEngine = 0;
        int32_t ownIndex = 0;
        int32_t w08 = 0;
        int32_t w40 = 0;
        int32_t w4c = 0;
        int32_t wd0 = 0;
        uint8_t dead = 0;
        int isShaped = 0;

        if (!tnx_read_ptr(object, &vtable)) {
            tnx_logf("v55 table elem[%d] %p unreadable - no verdict from this element",
                     i, (void *)object);

            continue;
        }

        tnx_read_i32(object + TNX_OBJ_GLOBALID_OFF, &gid);
        tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32(object + TNX_OBJ_TEAMENGINE_OFF, &teamEngine);
        tnx_read_i32(object + TNX_OBJ_OWNERINDEX_OFF, &ownIndex);
        tnx_read_u8(object + TNX_OBJ_DEADFLAG_OFF, &dead);
        tnx_read_ptr(object + TNX_SLOT_OWNER_OFF, &owner);
        tnx_read_i32(object + 0x08, &w08);
        tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &w40);
        tnx_read_i32(object + TNX_OBJ_TEAMENGINE_OFF, &w4c);
        tnx_read_i32(object + TNX_OBJ_DEADFLAG_OFF, &wd0);

        isShaped = tnx_gameobject_shape(object) ? 1 : 0;
        if (isShaped) shaped++;

        if (i == 0) firstGid = gid;
        else if (gid != firstGid) sameGid = 0;

        tnx_logf("v55 table elem[%d] %p vt=%#llx gid=%d team=%d team4c=%d own=%d dead=%d owner=%p "
                 "w08=%d w40=%d w4c=%d wd0=%d shape=%d",
                 i, (void *)object, (unsigned long long)((uintptr_t)vtable - g_base), gid, team,
                 teamEngine,
                 ownIndex, dead, (void *)owner, w08, w40, w4c, wd0, isShaped);
    }

    if (entry->instCount >= 2 && sameGid) {
        tnx_logf("v55 table verdict rva=%#llx: all %d instances share gid=%d - this is a proxy or a "
                 "cache, NOT a battle container; hooking it would be pointless",
                 (unsigned long long)entry->rva, entry->instCount, firstGid);
    } else if (entry->instCount >= 1) {
        tnx_logf("v55 table verdict rva=%#llx: shaped=%d instances=%d and the ids differ - a real "
                 "object family, safe to hook",
                 (unsigned long long)entry->rva, shaped, entry->instCount);
    }
}

static void tnx_vtcensus_slots(const tnx_vtcensus_t *entry) {
    uint8_t bytes[TNX_VTCENSUS_SLOTS * sizeof(uintptr_t)];
    char listed[512];
    int used = 0;

    if (!entry) return;
    if (!tnx_copy(g_base + entry->rva, bytes, sizeof(bytes))) {
        tnx_logf("vtslots rva=%#llx seg=%c unreadable - the table moved or is not mapped",
                 (unsigned long long)entry->rva, entry->seg ? 'D' : 'C');

        return;
    }

    for (int i = 0; i < TNX_VTCENSUS_SLOTS; i++) {
        uintptr_t slot = 0;

        memcpy(&slot, bytes + (size_t)i * sizeof(uintptr_t), sizeof(slot));

        if (used > (int)sizeof(listed) - 24) break;

        used += snprintf(listed + used, sizeof(listed) - (size_t)used, "%s%#llx", i ? "," : "",
                         (unsigned long long)(slot > g_base ? slot - g_base : 0));
    }

    tnx_logf("vtslots rva=%#llx seg=%c count=%llu shaped=%llu slotRvas=%s",
             (unsigned long long)entry->rva, entry->seg ? 'D' : 'C', entry->count, entry->shaped,
             listed);

    tnx_v50_table_probe(entry);
}

static void tnx_vtcensus_dump(void) {
    int chosen[TNX_VTCENSUS_PRINT];
    int nchosen = 0;

    tnx_logf("vtcensus pass=%d distinct=%d%s total=%llu spill=%llu dc=%p..%p data=%p..%p",
             g_heap_passes, g_vtcensus_used, g_vtcensus_spill ? "+" : "", g_vtcensus_total,
             g_vtcensus_spill, (void *)g_vtcensus_dc_lo, (void *)g_vtcensus_dc_hi,
             (void *)g_vtcensus_d_lo, (void *)g_vtcensus_d_hi);

    for (int k = 0; k < TNX_VTCENSUS_PRINT; k++) {
        int best = -1;

        for (int i = 0; i < g_vtcensus_used; i++) {
            int taken = 0;

            for (int j = 0; j < nchosen; j++) {
                if (chosen[j] == i) {
                    taken = 1;

                    break;
                }
            }

            if (taken) continue;
            if (best < 0 || g_vtcensus[i].count > g_vtcensus[best].count) best = i;
        }

        if (best < 0) break;

        chosen[nchosen++] = best;

        const tnx_vtcensus_t *entry = &g_vtcensus[best];

        tnx_logf("vtcensus #%d rva=%#llx seg=%c count=%llu shaped=%llu ownerEqVt=%llu first=%p", k,
                 (unsigned long long)entry->rva, entry->seg ? 'D' : 'C', entry->count,
                 entry->shaped, entry->ownerEqVt, (void *)entry->first);
    }

    int most = tnx_vtcensus_top(0);
    int mostShaped = tnx_vtcensus_top(1);

    if (most >= 0) tnx_vtcensus_slots(&g_vtcensus[most]);
    if (mostShaped >= 0 && mostShaped != most) tnx_vtcensus_slots(&g_vtcensus[mostShaped]);
}

static tnx_owner_vote_t *tnx_owner_vote_slot(uintptr_t owner) {
    for (int i = 0; i < g_owner_vote_count; i++) {
        if (g_owner_votes[i].owner == owner) return &g_owner_votes[i];
    }

    if (g_owner_vote_count >= TNX_OWNER_VOTE_MAX) return NULL;

    tnx_owner_vote_t *entry = &g_owner_votes[g_owner_vote_count++];

    memset(entry, 0, sizeof(*entry));
    entry->owner = owner;

    return entry;
}

static void tnx_owner_vote_note(tnx_owner_vote_t *entry, int32_t gid, int32_t team, int deadOk,
                                uintptr_t vtable) {
    BOOL known = NO;

    entry->votes++;

    for (int i = 0; i < entry->gidSeenCount; i++) {
        if (entry->gidSeen[i] == (uint32_t)gid) {
            known = YES;
            break;
        }
    }

    if (!known) {
        if (entry->gidSeenCount < TNX_OWNER_VOTE_GID_MAX) {
            entry->gidSeen[entry->gidSeenCount++] = (uint32_t)gid;
        } else {

            entry->gidFull = 1;
        }
    }

    if (team >= 0 && team < 32) entry->teamMask |= (1 << team);
    if (deadOk) entry->deadOk++;

    if (vtable) {
        BOOL have = NO;

        for (int i = 0; i < entry->vtCount; i++) {
            if (entry->vt[i] == vtable) {
                have = YES;
                break;
            }
        }

        if (!have && entry->vtCount < TNX_OWNER_VOTE_VT_MAX) entry->vt[entry->vtCount++] = vtable;
    }
}

static void tnx_objhit_note(uintptr_t at, uintptr_t vt, uintptr_t owner, int32_t gid, int32_t team,
                            int32_t ownerIdx, int dead, int ownerClass) {
    if (g_objhit_count >= TNX_OBJ_HIT_DUMP_MAX) {
        g_objhit_full = 1;

        return;
    }

    tnx_objhit_t *hit = &g_objhits[g_objhit_count++];

    hit->at = at;
    hit->vt = vt;
    hit->owner = owner;
    hit->gid = gid;
    hit->team = team;
    hit->ownerIdx = ownerIdx;
    hit->dead = dead;
    hit->ownerClass = ownerClass;
}

static void tnx_objhit_dump(void) {
    static const char *const names[4] = { "heap", "image", "noRegion", "aboveWin" };
    int printed = 0;

    if (!g_objhit_count) return;

    for (int want = 0; want < 4 && printed < TNX_OBJ_HIT_PRINT_MAX; want++) {
        for (int i = 0; i < g_objhit_count && printed < TNX_OBJ_HIT_PRINT_MAX; i++) {
            const tnx_objhit_t *hit = &g_objhits[i];

            if (hit->ownerClass != want) continue;

            {
                int32_t hx = 0;
                int32_t hy = 0;

                tnx_read_i32(hit->at + TNX_OBJ_X_OFF, &hx);
                tnx_read_i32(hit->at + TNX_OBJ_Y_OFF, &hy);

                tnx_logf("objhit pass=%d #%d at=%p vt=%#llx gid=%d team=%d own=%d dead=%d pos=(%d,%d) "
                         "owner=%p ownerClass=%s",
                         g_heap_passes, printed, (void *)hit->at,
                         (unsigned long long)(hit->vt > g_base ? hit->vt - g_base : 0), hit->gid,
                         hit->team, hit->ownerIdx, hit->dead, hx, hy, (void *)hit->owner,
                         names[want]);
            }

            printed++;
        }
    }

    if (g_objhit_full || printed < g_objhit_count) {
        tnx_logf("objhit truncated: shown=%d recorded=%d%s - the real number of shaped words is the "
                 "objvote line's hits+skipped+ownerImg+ownerNoRegion+ownerAboveWin", printed,
                 g_objhit_count,
                 g_objhit_full ? "+" : "");
    }
}

static void tnx_probe_object_vote(uintptr_t cursor, size_t offset, const uint8_t *buffer,
                                  size_t chunk, uintptr_t dcLo, uintptr_t dcHi) {
    uintptr_t absolute = cursor + offset;
    uintptr_t vtable = 0;
    uintptr_t owner = 0;
    int32_t gid = 0;
    int32_t team = 0;
    int32_t ownerIdx = 0;
    int deadOk = 0;
    int ownerClass = 0;

    if (g_mode_strong) return;

    if (absolute & 0xf) return;
    if (offset + TNX_OBJ_DEADFLAG_OFF + 1 > chunk) return;

    if (tnx_in_image_span(absolute)) {
        g_objvote_obj_img++;
        return;
    }

    memcpy(&vtable, buffer + offset, sizeof(vtable));

    if (vtable < dcLo || vtable >= dcHi) return;
    if (vtable & 7) return;

    memcpy(&gid, buffer + offset + TNX_OBJ_GLOBALID_OFF, sizeof(gid));

    if (gid <= 0) return;

    memcpy(&team, buffer + offset + TNX_OBJ_TEAM_OFF, sizeof(team));

    if (team < 0 || team > TNX_OBJ_TEAM_MAX) return;

    memcpy(&ownerIdx, buffer + offset + TNX_OBJ_OWNERINDEX_OFF, sizeof(ownerIdx));

    if (ownerIdx < 0 || ownerIdx > TNX_OBJ_OWNERIDX_MAX) return;

    memcpy(&owner, buffer + offset + TNX_SLOT_OWNER_OFF, sizeof(owner));

    if (!owner || (owner & 0xf)) return;

    deadOk = (buffer[offset + TNX_OBJ_DEADFLAG_OFF] <= 1) ? 1 : 0;

    ownerClass = tnx_owner_is_heap(owner) ? 0 : (tnx_in_image_span(owner) ? 1 : 2);

    if (ownerClass == 2 && g_heap_window_high && owner >= g_heap_window_high) ownerClass = 3;

    if (ownerClass == 1) g_objvote_owner_img++;
    else if (ownerClass == 2) g_objvote_owner_reg++;
    else if (ownerClass == 3) g_objvote_owner_above_win++;

    tnx_objhit_note(absolute, vtable, owner, gid, team, ownerIdx, deadOk, ownerClass);

    g_objvote_shaped++;

    tnx_vtcensus_shaped(vtable);

    if (ownerClass != 0) return;

    tnx_owner_vote_t *entry = tnx_owner_vote_slot(owner);

    if (!entry) {
        g_objvote_skipped++;
        return;
    }

    if (deadOk) g_objvote_dead_seen++;

    g_objvote_hits++;
    tnx_owner_vote_note(entry, gid, team, deadOk, vtable);
}

static int tnx_team_count(int mask) {
    int n = 0;

    for (int i = 0; i < 32; i++) {
        if (mask & (1 << i)) n++;
    }

    return n;
}

static int tnx_owner_vote_better(int a, int b) {
    int ta = tnx_team_count(g_owner_votes[a].teamMask);
    int tb = tnx_team_count(g_owner_votes[b].teamMask);

    if (ta != tb) return ta > tb;

    if (g_owner_votes[a].gidSeenCount != g_owner_votes[b].gidSeenCount) {
        return g_owner_votes[a].gidSeenCount > g_owner_votes[b].gidSeenCount;
    }

    return g_owner_votes[a].votes > g_owner_votes[b].votes;
}

static void tnx_object_vote_finish(void) {
    int best = -1;
    int top = -1;

    for (int i = 0; i < g_owner_vote_count; i++) {
        if (g_owner_votes[i].gidSeenCount < TNX_OWNER_VOTE_MIN) continue;
        if (tnx_v57_owner_rejected(g_owner_votes[i].owner)) continue;
        if (best < 0 || tnx_owner_vote_better(i, best)) best = i;
    }

    for (int i = 0; i < g_owner_vote_count; i++) {
        if (top < 0 || g_owner_votes[i].votes > g_owner_votes[top].votes) top = i;
    }

    g_objvote_max_votes = top >= 0 ? g_owner_votes[top].votes : 0;
    g_objvote_top_owner = top >= 0 ? g_owner_votes[top].owner : 0;

    tnx_owner_vote_t *entry = NULL;

    if (best < 0) {
        g_objvote_confirm = 0;
        g_objvote_best_teamcount = 0;
        g_objvote_best_gids_full = 0;
    } else {
        entry = &g_owner_votes[best];

        if (entry->owner == g_objvote_prev_owner) g_objvote_confirm++;
        else g_objvote_confirm = 0;

        g_objvote_prev_owner = entry->owner;
        g_objvote_best_owner = entry->owner;
        g_objvote_best_gids = entry->gidSeenCount;
        g_objvote_best_gids_full = entry->gidFull;
        g_objvote_best_teamcount = tnx_team_count(entry->teamMask);
    }

    tnx_logf("objvote pass=%d hits=%llu skipped=%llu owners=%d deadOk=%d best=%p gids=%d%s "
             "confirm=%d teamCount=%d ownerImg=%llu ownerNoRegion=%llu ownerAboveWin=%llu "
             "objImg=%llu objShaped=%llu "
             "objhitRec=%d%s "
             "maxVotes=%d topOwner=%p teamsMin=%d",
             g_heap_passes, g_objvote_hits, g_objvote_skipped, g_owner_vote_count,
             g_objvote_dead_seen, (void *)g_objvote_best_owner, g_objvote_best_gids,
             g_objvote_best_gids_full ? "+" : "", g_objvote_confirm, g_objvote_best_teamcount,
             g_objvote_owner_img, g_objvote_owner_reg, g_objvote_owner_above_win, g_objvote_obj_img,
             g_objvote_shaped,
             g_objhit_count, g_objhit_full ? "+" : "", g_objvote_max_votes, (void *)g_objvote_top_owner,
             TNX_OWNER_VOTE_TEAMS_MIN);

    tnx_objhit_dump();

    if (!entry) return;

    tnx_logf("objvote owner=%p distinctGids=%d%s votes=%d teams=%#x teamCount=%d deadOk=%d "
             "vtCount=%d vt0=%#llx vt1=%#llx vt2=%#llx vt3=%#llx",
             (void *)entry->owner, entry->gidSeenCount, entry->gidFull ? "+" : "", entry->votes,
             entry->teamMask, g_objvote_best_teamcount, entry->deadOk, entry->vtCount,
             (unsigned long long)(entry->vt[0] > g_base ? entry->vt[0] - g_base : 0),
             (unsigned long long)(entry->vt[1] > g_base ? entry->vt[1] - g_base : 0),
             (unsigned long long)(entry->vt[2] > g_base ? entry->vt[2] - g_base : 0),
             (unsigned long long)(entry->vt[3] > g_base ? entry->vt[3] - g_base : 0));

    if (g_objvote_owner_ok) return;

    if (g_objvote_best_teamcount >= TNX_OWNER_VOTE_TEAMS_MIN) {
        if (entry->votes < TNX_OWNER_VOTE_MIN) {
            if (g_v52_low_votes_logs < 4) {
                g_v52_low_votes_logs++;

                tnx_logf("v55 objvote two teams but %d objects on owner=%p - not adopted yet",
                         entry->votes, (void *)entry->owner);
            }

            return;
        }

        {
            int32_t owned = 0;
            int32_t ownedCap = 0;
            const char *reason = tnx_v57_header_reason(entry->owner, &owned, &ownedCap);

            if (reason) {
                tnx_v57_owner_reject(entry->owner);

                if (g_v57_reject_logs < 8) {
                    g_v57_reject_logs++;

                    tnx_logf("v65 adopt refused owner=%p teams=%#x votes=%d distinctGids=%d "
                             "reason=%s count=%d cap=%d - the owner is excluded and the vote moves "
                             "to the next one", (void *)entry->owner, entry->teamMask, entry->votes,
                             entry->gidSeenCount, reason, owned, ownedCap);
                }

                return;
            }
        }

        tnx_logf("v55 objvote adopt owner=%p teams=%#x teamCount=%d votes=%d distinctGids=%d%s - a "
                 "two-team owner is a battle container on its own, and waiting for consecutive "
                 "passes is what kept the v51 run from ever naming it",
                 (void *)entry->owner, entry->teamMask, g_objvote_best_teamcount, entry->votes,
                 entry->gidSeenCount, entry->gidFull ? "+" : "");

        tnx_battle_begin("objvote");

        g_objvote_owner_ok = YES;
        g_manager_object = entry->owner;
        g_manager_count = entry->gidSeenCount;

        tnx_report_manager("objvote", entry->owner);
        tnx_object_detail_readonly(entry->owner, TNX_OWNER_VOTE_DETAIL_MAX);

        return;
    }

    g_objvote_confirm = 0;

    if (g_objvote_single_team_logs < 4) {
        g_objvote_single_team_logs++;

        tnx_logf("v55 objvote singleTeam owner=%p teamCount=%d teams=%#x distinctGids=%d%s votes=%d "
                 "deadOk=%d vt0=%#llx - held back: a battle container carries both teams, and a "
                 "table that merely looks like one repeats a single team value",
                 (void *)entry->owner, g_objvote_best_teamcount, entry->teamMask,
                 entry->gidSeenCount, entry->gidFull ? "+" : "", entry->votes, entry->deadOk,
                 (unsigned long long)(entry->vt[0] > g_base ? entry->vt[0] - g_base : 0));
    }
}

static void tnx_slot_diag(const char *why) {
    char buf[320];
    int used = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        const char *state = "n/a";
        void *current = NULL;

        if (g_slot_specs[i].slotRva && g_slot_installed[i] == 1) {
            state = "unreadable";

            if (tnx_read_ptr(g_base + g_slot_specs[i].slotRva, &current)) {
                state = ((uintptr_t)current == (uintptr_t)g_slot_specs[i].replacement)
                            ? "held" : "LOST";
            }
        }

        if (used > (int)sizeof(buf) - 40) break;

        used += snprintf(buf + used, sizeof(buf) - (size_t)used, "%s=%llu/%s ",
                         g_slot_specs[i].shortTag, (unsigned long long)g_slot_hits[i], state);
    }

    tnx_logf("slotdiag(%s) %s AG=%llu/i%d agmgr=%p objs=%d", why ? why : "?", buf,
             (unsigned long long)g_ag_hits, g_ag_installed, (void *)g_ag_manager,
             g_ag_objectCount);

    if (g_ag_objectCount > 0 && !g_ag_adopted) {
        g_ag_adopted = 1;

        tnx_logf("AG dump manager=%p objects=%d", (void *)g_ag_manager, g_ag_objectCount);

        for (int i = 0; i < g_ag_objectCount; i++) {
            tnx_logf("AG obj[%d]=%p", i, (void *)g_ag_objects[i]);
            tnx_dump_hex("AGobj", g_ag_objects[i], 0x80);
        }
    }
}

static void tnx_diag_report(const char *why) {
    const char *verdict = "no battle-shaped structure in the memory scanned so far";

    char verdictBuf[512] = {0};

    if (g_heap_passes == 0) {
        verdict = "no heap pass completed yet";
    } else if (g_mode_strong) {
        verdict = "MODE ADOPTED through the mode -> manager -> array chain, fields only, nothing called";
    } else if (g_objvote_owner_ok && g_manager_object && g_ag_manager && g_ag_objectCount > 0) {
        verdict = "OWNER CAPTURED - the vote adopted an owner and the manager walk holds objects";
    } else if (g_objvote_owner_ok) {
        verdict = "OWNER CANDIDATE, not adopted - the vote named an owner but the manager walk "
                  "holds no objects";
    } else if (g_objvote_best_gids >= TNX_OWNER_VOTE_MIN &&
               g_objvote_best_teamcount < TNX_OWNER_VOTE_TEAMS_MIN) {

        verdict = "OBJECT VOTE found a heap owner with many distinct ids but ONE team only - a battle container carries both teams, so it is held back, not adopted";
    } else if (g_objvote_best_gids >= TNX_OWNER_VOTE_MIN) {
        verdict = "OBJECT VOTE sees game objects under one owner, but it has not won two passes in a row yet";
    } else if (g_objvote_hits > 0 && g_objvote_max_votes <= 1) {

        int cidx = tnx_vtcensus_top(1);

        if (cidx < 0) cidx = tnx_vtcensus_top(0);

        if (cidx >= 0) {
            snprintf(verdictBuf, sizeof(verdictBuf),
                     "OBJECT VOTE matched real objects but +0x20 never repeated (%d owners for %llu "
                     "objects), so +0x20 is not the shared owning manager on this build. The class "
                     "tables the live heap really carries are in the vtcensus lines; the one with the "
                     "most game-object-shaped instances is RVA %#llx (%llu instances, %llu shaped) "
                     "and its first slot RVAs are on the vtslots line - that is where the next hook "
                     "goes",
                     g_owner_vote_count, g_objvote_hits,
                     (unsigned long long)g_vtcensus[cidx].rva, g_vtcensus[cidx].count,
                     g_vtcensus[cidx].shaped);
            verdict = verdictBuf;
        } else {
            verdict = "OBJECT VOTE matched real objects but +0x20 never repeated - almost as many owners as objects, so +0x20 is not the shared owning manager on this build; and no table of theirs survived in the census, which is itself the finding - read the objhit dump for the class tables the live objects carry";
        }
    } else if (g_objvote_hits > 0) {
        verdict = "OBJECT VOTE matched object-shaped words but no owner reached the distinct-id minimum - the layout is partly recognised";
    } else if (g_mode_object) {
        verdict = "an object was adopted but the chain is not fully confirmed";
    } else if (g_manager_loose_count == 0 && g_manager_saw_cap == 0) {
        verdict = "NO ARRAY-SHAPED WORD ANYWHERE - the header test itself matched nothing";
    } else if (g_manager_skipped > 0 || g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) {
        verdict = "ARRAY TEST BLIND - its probe budget was exhausted; the object vote is the channel that still covered the whole pass";
    } else if (g_chain_skipped > 0 && !g_mode_object && !g_manager_object) {
        verdict = "CHAIN BLIND - the chain probe hit its limit before the heap was covered, and it found nothing before that; this run proves nothing about the mode";
    } else if (g_manager_best_live >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "a container passed the array test and was recorded, NOT adopted - the chain never matched";
    } else if (g_manager_best_live >= 1) {
        verdict = "manager-shaped array seen, but too few live instances -> not a battle";
    } else if (g_manager_best_count >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "count at +0xc is in range but entries are not C++ instances -> wrong layout";
    } else if (g_manager_skipped > 0) {
        verdict = "probe budget exhausted -> the pass was blind after that point, raise the limit";
    } else if (g_manager_probes_total == 0 && g_heap_passes > 0) {
        verdict = "no manager-like count at +0xc anywhere -> layout @+0xc wrong, or coverage short";
    } else if (!g_manager_object && g_mode_best_objects < TNX_MANAGER_MIN_OBJECTS &&
               g_heap_passes > 0) {
        verdict = "NO BATTLE IN WINDOW - nothing battle-shaped existed, this says nothing about the layout";
    }

    g_slot_hits_total = 0;
    for (int i = 0; i < TNX_SLOT_COUNT; i++) g_slot_hits_total += (uint64_t)g_slot_hits[i];

    tnx_logf("hooks fired=%llu of %d slots (A1=%llu A2=%llu B1=%llu B2=%llu B3=%llu C1=%llu C2=%llu)",
             (unsigned long long)g_slot_hits_total, TNX_SLOT_COUNT,
             (unsigned long long)g_slot_hits[0], (unsigned long long)g_slot_hits[1],
             (unsigned long long)g_slot_hits[2], (unsigned long long)g_slot_hits[3],
             (unsigned long long)g_slot_hits[4], (unsigned long long)g_slot_hits[5],
             (unsigned long long)g_slot_hits[6]);

    if (g_slot_hits_total == 0 && g_heap_passes > 0) {

        tnx_logf("DIAG note: none of the seven slots was ever dispatched - which is NOT the same as "
                 "the seven classes being absent. The 20:22 run measured a pass from 0x0 and a pass "
                 "from the window low, both cut off by the same byte budget, and the ninth vtprobe "
                 "counter read 0 on the first and 92502 on the second. A zero counts only when that "
                 "pass reports budgetHit=0, which is why the pass line now carries budget=, "
                 "budgetHit= and readTo= beside scanned= and winSpan=. `vtprobePass=` is this pass, "
                 "`vtprobeAll=` the running total, `vtprobeFirst=` the address behind each non-zero "
                 "counter. The classes that DO exist are enumerated by the `vtcensus` lines: "
                 "`count=` is live instances, `shaped=` how many of them also passed the full object "
                 "record layout, and `vtslots` gives the first slot RVAs of the two most interesting "
                 "tables - that is where the next hook goes");
    }

    tnx_trail_dump();

    tnx_best_candidate_dump();

    tnx_logf("v55 chain gates: vtBad=%d vtNotDC=%d mgrBad=%d mgrNotPlausible=%d mgrNotHeap=%d "
             "varBad=%d pxBad=%d pyBad=%d inputBad=%d shapeBad=%d arrayRead=%d countRead=%d "
             "arrayNull=%d countRange=%d live=%d own=%d gid=%d tested=%d logged=%d",
             g_v55_chain_rej[0], g_v55_chain_rej[1], g_v55_chain_rej[2], g_v55_chain_rej[3],
             g_v55_chain_rej[4], g_v55_chain_rej[5], g_v55_chain_rej[6], g_v55_chain_rej[7],
             g_v55_chain_rej[8], g_v55_chain_rej[9], g_v55_chain_rej[10], g_v55_chain_rej[11],
             g_v55_chain_rej[12], g_v55_chain_rej[13], g_v55_chain_rej[14], g_v55_chain_rej[15],
             g_v55_chain_rej[16], g_chain_probes, g_v55_layout_logs);

    tnx_logf("DIAG(%s) attempts=%d/%d heapPasses=%d covered=%lluMB probes=%d/%d skipped=%d "
             "capRej=%d/%d bestCount=%d bestLive=%d mgr=%p adopted=%d vfx=%d mx=%d "
             "chain=%d/%d chainPass=%d chainSkip=%d stable=%d own=%d gid=%d "
             "objvote=%llu skipped=%llu owners=%d best=%p gids=%d%s confirm=%d teamCount=%d "
             "deadOk=%d ownerImg=%llu ownerNoRegion=%llu ownerAboveWin=%llu objImg=%llu "
             "objShaped=%llu maxVotes=%d "
             "bigSkip=%d vtcensus=%d/%llu",
             why ? why : "?", g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_heap_covered / (1024ull * 1024ull), g_manager_probes_total, TNX_MANAGER_PROBE_LIMIT,
             g_manager_skipped, g_manager_cap_rejects, g_manager_saw_cap,
             g_manager_best_count, g_manager_best_live, (void *)g_manager_object,
             g_mode_strong ? 1 : 0, g_mode_verified_hits, g_mode_best_objects,
             g_chain_checks, g_chain_probes, g_v55_chain_probes_pass, g_chain_skipped,
             g_seen_stable,
             g_chain_best_own, g_chain_best_gid,
             g_objvote_hits, g_objvote_skipped, g_owner_vote_count,
             (void *)g_objvote_best_owner, g_objvote_best_gids,
             g_objvote_best_gids_full ? "+" : "", g_objvote_confirm, g_objvote_best_teamcount,
              g_objvote_dead_seen, g_objvote_owner_img, g_objvote_owner_reg,
              g_objvote_owner_above_win, g_objvote_obj_img,
              g_objvote_shaped, g_objvote_max_votes, g_heap_big_skip,
              g_vtcensus_used, g_vtcensus_total);

    tnx_logf("DIAG verdict: %s", verdict);

    tnx_slot_diag(why);
}

static void tnx_scan_globals_for_mode(const char *name) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;

    if (!tnx_segment_range(name, &lo, &hi)) {
        tnx_logf("votescan %s missing", name);
        return;
    }

    size_t span = (size_t)(hi - lo);

    if (span < 0x1000 || span > (16u * 1024u * 1024u)) {
        tnx_logf("votescan %s bad span=%zu", name, span);
        return;
    }

    uint8_t *bytes = (uint8_t *)malloc(span);

    if (!bytes) {
        tnx_logf("votescan %s alloc failed", name);
        return;
    }

    if (!tnx_copy(lo, bytes, span)) {
        free(bytes);
        tnx_logf("votescan %s read failed", name);
        return;
    }

    int hits = 0;
    int vtHits = 0;
    int shapeHits = 0;
    int strongHits = 0;
    int nearMiss = 0;
    int verifiedHits = 0;

    for (size_t offset = 0; offset + sizeof(void *) <= span; offset += sizeof(void *)) {
        uintptr_t object = 0;
        void *vtable = NULL;
        BOOL vtMatch = NO;
        int score = 0;
        int vfx = -1;

        memcpy(&object, bytes + offset, sizeof(object));

        if (!tnx_pointer_plausible(object)) continue;
        if (!tnx_heap_resident(object)) continue;
        if (!tnx_read_ptr(object, &vtable)) continue;
        if (!vtable) continue;

        vtMatch = tnx_is_mode_vtable((uintptr_t)vtable, NULL);
        vfx = tnx_verified_vtable((uintptr_t)vtable);

        if (vfx >= 0 || vtMatch || tnx_vtable_shaped((uintptr_t)vtable)) score = tnx_mode_score(object);

        if (score == 0 && !vtMatch && vfx < 0) {

            if (tnx_object_shaped(object)) {
                nearMiss++;

                if (g_mode_near_logs < 3) {
                    g_mode_near_logs++;
                    tnx_report_mode_hit("near", lo + offset, object);
                }
            }

            continue;
        }

        hits++;
        g_mode_matches++;

        if (vfx >= 0) {
            g_mode_verified_hits++;
            verifiedHits++;

            tnx_battle_begin("globals");
        }
        if (vtMatch) vtHits++;
        if (score >= 1) shapeHits++;
        if (score >= 2) strongHits++;

        if (g_mode_strict_logs < 6 || vfx >= 0) {
            g_mode_strict_logs++;
            tnx_report_mode_hit(vfx >= 0 ? "cap" : (score >= 2 ? "strong" : (score == 1 ? "weak" : "vt")),
                                lo + offset, object);
        }

        if (vfx >= 0) {

            tnx_adopt_mode(object, YES, "verified");
        } else if (score >= 2) {
            tnx_adopt_mode(object, YES, "strong");
        } else if (score == 1) {
            tnx_adopt_mode(object, NO, "container");
        }
    }

    free(bytes);

    {
        int index = (strcmp(name, "__DATA_CONST") == 0) ? 1 : 0;
        int sig = hits * 31 + shapeHits * 131 + strongHits * 1313 + verifiedHits * 131313;

        if (sig != g_scan_sig[index] || (g_votescan_attempts % 30) == 0) {
            g_scan_sig[index] = sig;

            tnx_logf("votescan %s hits=%d vt=%d shape=%d strong=%d near=%d vfx=%d",
                     name, hits, vtHits, shapeHits, strongHits, nearMiss, verifiedHits);
        }
    }
}

static void tnx_scan_heap_for_mode(void) {
    uintptr_t startAddress = g_heap_scan_next;
    vm_address_t address = (vm_address_t)startAddress;
    size_t scanned = 0;

    g_manager_probes = 0;

    g_owner_vote_count = 0;
    g_objvote_hits = 0;
    g_objvote_skipped = 0;
    g_objvote_dead_seen = 0;
    g_objvote_owner_img = 0;
    g_objvote_owner_reg = 0;
    g_objvote_owner_above_win = 0;
    g_objvote_obj_img = 0;
    g_objvote_max_votes = 0;
    g_objvote_top_owner = 0;
    g_objhit_count = 0;
    g_objhit_full = 0;
    g_objvote_shaped = 0;
    g_heap_img_skip = 0;
    g_heap_ro_skip = 0;
    g_heap_big_skip = 0;
    g_heap_big_bytes = 0;
    g_heap_huge_skip = 0;

    tnx_vtcensus_reset();

    for (int k = 0; k < TNX_VTPROBE_COUNT; k++) g_vtprobe_pass[k] = g_vtprobe_hits[k];

    uintptr_t winLo = g_heap_window_low;
    uintptr_t winHi = g_heap_window_high;

    uint64_t budgetNow = (winHi > winLo ? (uint64_t)(winHi - winLo) : 0) + (64ull << 20);

    if (budgetNow < TNX_HEAP_SCAN_BUDGET) budgetNow = TNX_HEAP_SCAN_BUDGET;
    if (budgetNow > TNX_HEAP_SCAN_BUDGET_MAX) budgetNow = TNX_HEAP_SCAN_BUDGET_MAX;

    uintptr_t dcLo = 0;
    uintptr_t dcHi = 0;
    BOOL haveDC = tnx_segment_range("__DATA_CONST", &dcLo, &dcHi);

    g_vtcensus_dc_lo = dcLo;
    g_vtcensus_dc_hi = dcHi;
    g_vtcensus_d_lo = 0;
    g_vtcensus_d_hi = 0;
    tnx_segment_range("__DATA", &g_vtcensus_d_lo, &g_vtcensus_d_hi);

    g_heap_passes++;
    int regions = 0;
    int hits = 0;
    int shapeHits = 0;
    int strongHits = 0;
    int verifiedHits = 0;

    uintptr_t readStop = 0;
    size_t words = 0;

    while (regions < 8192 && scanned < budgetNow) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t objectName = MACH_PORT_NULL;

        kern_return_t result = vm_region_64(
            mach_task_self(),
            &address,
            &size,
            VM_REGION_BASIC_INFO_64,
            (vm_region_info_t)&info,
            &infoCount,
            &objectName
        );

        if (objectName != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), objectName);
        if (result != KERN_SUCCESS || size == 0) break;

        if (size > (1ull << 30)) {
            uintptr_t beyond = (uintptr_t)address + (uintptr_t)size;

            if (beyond <= (uintptr_t)address) break;

            if ((info.protection & VM_PROT_WRITE) != 0) {
                g_heap_big_skip++;
                g_heap_big_bytes += (unsigned long long)size;
            } else {
                g_heap_huge_skip++;
            }

            address = (vm_address_t)beyond;

            continue;
        }

        regions++;

        if (tnx_image_segment_name((uintptr_t)address)) {
            g_heap_img_skip++;
        } else if ((info.protection & VM_PROT_WRITE) != 0 && size >= 0x1000) {
            uint64_t remaining = (uint64_t)size;
            uintptr_t cursor = (uintptr_t)address;

            while (remaining >= 16 && scanned < budgetNow) {
                size_t chunk = (size_t)(remaining < TNX_HEAP_CHUNK ? remaining : (uint64_t)TNX_HEAP_CHUNK);
                uint8_t *buffer = (uint8_t *)malloc(chunk);

                if (!buffer) break;

                if (tnx_copy(cursor, buffer, chunk)) {
                    for (size_t offset = 0; offset + sizeof(uintptr_t) <= chunk; offset += sizeof(uintptr_t)) {
                        uintptr_t vtable = 0;

                        memcpy(&vtable, buffer + offset, sizeof(vtable));

                        tnx_probe_manager(cursor, offset, buffer, chunk);

                        tnx_vtprobe_note(vtable, cursor + offset);

                        tnx_vtcensus_note(vtable, cursor + offset, buffer, offset, chunk);

                        if (haveDC) {
                            tnx_probe_mode_chain(cursor, offset, buffer, chunk, dcLo, dcHi);

                            tnx_probe_object_vote(cursor, offset, buffer, chunk, dcLo, dcHi);
                        }

                        if (!tnx_is_mode_vtable(vtable, NULL) && tnx_verified_vtable(vtable) < 0) continue;

                        hits++;
                        g_mode_matches++;

                        uintptr_t object = cursor + offset;
                        int vfx = tnx_verified_vtable(vtable);
                        int score = tnx_mode_score(object);

                        if (vfx >= 0) {
                            g_mode_verified_hits++;
                            verifiedHits++;

                            tnx_battle_begin("heap");
                        }

                        if (score == 0 && vfx < 0) continue;

                        shapeHits++;
                        if (score >= 2) strongHits++;

                        if (g_mode_relaxed_logs < 8 || vfx >= 0) {
                            g_mode_relaxed_logs++;
                            tnx_report_mode_hit(vfx >= 0 ? "heap-cap" : (score >= 2 ? "heap+" : "heapw"), 0, object);
                        }

                        if (vfx >= 0) {
                            tnx_adopt_mode(object, YES, "heap-verified");
                        } else if (score >= 2) {
                            tnx_adopt_mode(object, YES, "heap-strong");
                        } else if (score == 1) {
                            tnx_adopt_mode(object, NO, "heap-container");
                        }
                    }
                }

                free(buffer);

                size_t step = chunk - sizeof(uintptr_t);

                if (step == 0) break;

                scanned += step;
                cursor += step;
                remaining -= step;
                words += chunk / sizeof(uintptr_t);
            }

            if (scanned >= budgetNow && remaining >= 16) readStop = cursor;
        } else {

            g_heap_ro_skip++;
        }

        uintptr_t next = (uintptr_t)address + (uintptr_t)size;
        if (next <= (uintptr_t)address) break;

        address = (vm_address_t)next;
    }

    uintptr_t nextAddress = readStop ? readStop : (uintptr_t)address;

    if (regions >= 8192 || (g_heap_window_high && nextAddress >= g_heap_window_high)) {
        g_heap_scan_next = g_heap_window_low;
    } else if (nextAddress <= startAddress) {

        uintptr_t jump = startAddress + (1ull << 30);

        g_heap_scan_next = (g_heap_window_high && jump >= g_heap_window_high) ? g_heap_window_low
                                                                             : jump;
    } else {
        g_heap_scan_next = nextAddress;
    }

    g_heap_covered += (unsigned long long)scanned;

    char vtbuf[160];
    char vtpass[160];
    int vused = 0;
    int pused = 0;

    for (int k = 0; k < TNX_VTPROBE_COUNT; k++) {
        if (vused > (int)sizeof(vtbuf) - 24 || pused > (int)sizeof(vtpass) - 24) break;

        vused += snprintf(vtbuf + vused, sizeof(vtbuf) - (size_t)vused, "%s%llu", k ? "," : "",
                          g_vtprobe_hits[k]);
        pused += snprintf(vtpass + pused, sizeof(vtpass) - (size_t)pused, "%s%llu", k ? "," : "",
                          g_vtprobe_hits[k] - g_vtprobe_pass[k]);
    }

    tnx_object_vote_finish();
    tnx_vtcensus_dump();

    tnx_logf("votescan heap pass=%d from=%p scanned=%zu words=%zu regions=%d imgSkip=%d roSkip=%d "
             "bigSkip=%d "
             "bigBytes=%lluMB hugeSkip=%d budget=%lluMB budgetHit=%d readTo=%p hits=%d vfx=%d mgr=%p "
             "probes=%d/%d skipped=%d cap=%d/%d loose=%d window=%d bestCount=%d bestLive=%d "
             "trailBest=%d stable=%d chain=%d/%d ready=%d skip=%d live=%d own=%d gid=%d "
             "vtprobePass=%s vtprobeAll=%s vtcensus=%d/%llu vtSpill=%llu "
             "next=%p win=%p..%p winSpan=%lluMB",
             g_heap_passes, (void *)startAddress, scanned, words, regions, g_heap_img_skip,
             g_heap_ro_skip,
             g_heap_big_skip, g_heap_big_bytes / (1024ull * 1024ull), g_heap_huge_skip,
             budgetNow / (1024ull * 1024ull), readStop ? 1 : 0, (void *)readStop, hits,
             verifiedHits,
             (void *)g_manager_object, g_manager_probes, TNX_MANAGER_PROBE_LIMIT,
             g_manager_skipped, g_manager_cap_rejects, g_manager_saw_cap,
             g_manager_loose_count, g_manager_window_rejects,
             g_manager_best_count, g_manager_best_live, g_trail_best, g_seen_stable,
             g_chain_checks, g_chain_probes, g_chain_ready, g_chain_skipped,
             g_chain_best_live, g_chain_best_own, g_chain_best_gid, vtpass, vtbuf,
             g_vtcensus_used, g_vtcensus_total, g_vtcensus_spill,
             (void *)g_heap_scan_next, (void *)winLo, (void *)winHi,
             (unsigned long long)(winHi > winLo ? (winHi - winLo) / (1024ull * 1024ull) : 0));

    {
        char firsts[320];
        int fused = 0;

        for (int k = 0; k < TNX_VTPROBE_COUNT; k++) {
            if (!g_vtprobe_first[k]) continue;
            if (fused > (int)sizeof(firsts) - 40) break;

            fused += snprintf(firsts + fused, sizeof(firsts) - (size_t)fused, "%s%d@%p",
                              fused ? " " : "", k, (void *)g_vtprobe_first[k]);
        }

        if (fused) tnx_logf("vtprobeFirst pass=%d %s", g_heap_passes, firsts);
    }
}

static void tnx_locate_battle_mode(void) {
    if (g_mode_strong) return;

    if (g_votescan_attempts >= TNX_VOTESCAN_ATTEMPTS) {

        tnx_diag_report("exhausted");

        return;
    }

    double now = CFAbsoluteTimeGetCurrent();

    if (g_votescan_last > 0.0 && (now - g_votescan_last) < TNX_VOTESCAN_INTERVAL) return;

    g_votescan_last = now;
    g_votescan_attempts++;

    if (g_votescan_attempts == 1) {
        tnx_heap_regions_refresh();

    tnx_logf("heapwin regions=%d lo=%p hi=%p winSpan=%lluMB capped=%d",
             g_heap_region_count, (void *)g_heap_window_low, (void *)g_heap_window_high,
             (unsigned long long)((g_heap_window_high - g_heap_window_low) / (1024ull * 1024ull)),
             g_heap_region_capped);

    tnx_logf("votescan candidates=%d interval=%.1f attempts=%d heapEvery=%d",
                 (int)(sizeof(g_mode_vtables) / sizeof(g_mode_vtables[0]) - 1),
                 (double)TNX_VOTESCAN_INTERVAL, TNX_VOTESCAN_ATTEMPTS, TNX_VOTESCAN_HEAP_EVERY);
    }

    if ((g_votescan_attempts % TNX_VOTESCAN_GLOBAL_EVERY) == 1) {

        tnx_heap_regions_refresh();

        tnx_scan_globals_for_mode("__DATA");

        if (!g_mode_strong) tnx_scan_globals_for_mode("__DATA_CONST");
    }

    if (!g_mode_strong && (g_votescan_attempts % TNX_VOTESCAN_HEAP_EVERY) == 1) tnx_scan_heap_for_mode();

    if (g_mode_strong) {
        tnx_logf("votescan SUCCESS attempt=%d object=%p global=%p",
                 g_votescan_attempts, (void *)g_mode_object, (void *)g_mode_source);
        tnx_report_mode_hit("found", g_mode_source, g_mode_object);
    } else if ((g_votescan_attempts % TNX_VOTESCAN_HEARTBEAT) == 0) {
        tnx_diag_report("heartbeat");
    }
}

static uintptr_t tnx_vtable_rva(void *object) {
    void *vtable = NULL;

    if (!object) return 0;
    if (!tnx_read_ptr((uintptr_t)object, &vtable)) return 0;
    if (!vtable) return 0;
    if ((uintptr_t)vtable < g_base) return 0;

    return (uintptr_t)vtable - g_base;
}

static void tnx_dump_mode_refs(const char *tag) {
    if (!g_mode_object) return;

    tnx_logf("moderef[%s] mode=%p vt=%#llx", tag, (void *)g_mode_object,
             (unsigned long long)tnx_vtable_rva((void *)g_mode_object));

    int altHits = 0;

    for (uint32_t off = 0; off < 0x100 && altHits < 4; off += 8) {
        void *field = NULL;

        if (!tnx_read_ptr(g_mode_object + off, &field)) continue;
        if (!field) continue;
        if ((uintptr_t)field < 0x10000) continue;

        int32_t probe = 0;
        tnx_read_i32((uintptr_t)field + TNX_MODE_MODEVAR_OFF, &probe);

        altHits++;

        tnx_logf("v65 modeAlt +%02x -> %p vt=%#llx int124=%d src=A", off, field,
                 (unsigned long long)tnx_vtable_rva(field), probe);
    }

    for (int i = 0; i < 3; i++) {
        uint32_t off = (uint32_t)(TNX_MODE_SLOT_A + i * 8);
        void *slot = NULL;

        if (!tnx_read_ptr(g_mode_object + off, &slot)) continue;
        if (!slot) continue;

        tnx_logf("moderef[%s] sl%c +%x -> %p vt=%#llx",
                 tag, (char)('A' + i), off, slot, (unsigned long long)tnx_vtable_rva(slot));
    }
}

static BOOL tnx_obj_slot_fn(uintptr_t object, uintptr_t slot, uintptr_t *rvaOut) {
    void *vtable = NULL;
    void *function = NULL;

    if (rvaOut) *rvaOut = 0;

    if (!object) return NO;
    if (!tnx_read_ptr(object, &vtable) || !vtable) return NO;
    if (!tnx_read_ptr((uintptr_t)vtable + slot, &function) || !function) return NO;
    if ((uintptr_t)function < g_base) return NO;
    if ((uintptr_t)function >= g_base + 0xf74000) return NO;

    if (rvaOut) *rvaOut = (uintptr_t)function - g_base;

    return YES;
}

static void tnx_dump_mode_objects(const char *tag) {
    if (!g_mode_object) return;

    tnx_dump_mode_refs(tag);

    void *manager = NULL;
    void *array = NULL;
    int32_t count = 0;
    int32_t variation = 0;

    if (!tnx_read_ptr(g_mode_object + TNX_MODE_MANAGER_OFF, &manager)) return;
    if (!tnx_read_i32(g_mode_object + TNX_MODE_MODEVAR_OFF, &variation)) return;
    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array)) return;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return;

    tnx_logf("mode[%s] object=%p variation=%d manager=%p array=%p count=%d",
             tag, (void *)g_mode_object, variation, manager, array, count);

    if (!array || count <= 0) return;

    int limit = count < TNX_SNAPSHOT_OBJECTS ? count : TNX_SNAPSHOT_OBJECTS;

    for (int i = 0; i < limit; i++) {
        void *object = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &object)) continue;
        if (!object) continue;
        if (!tnx_pointer_plausible((uintptr_t)object)) continue;

        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        uint8_t dead = 0;
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_read_i32((uintptr_t)object + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)object + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)object + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)object + TNX_OBJ_DEADFLAG_OFF, &dead);

        tnx_obj_slot_fn((uintptr_t)object, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)object, TNX_OBJ_GETY_SLOT, &s90);

        tnx_logf("obj[%s][%d] %p vt=%#llx gid=%d team=%d own=%d dead=%d s88=%#llx s90=%#llx",
                 tag, i, object, (unsigned long long)tnx_vtable_rva(object), globalId, team,
                 owner, dead, (unsigned long long)s88, (unsigned long long)s90);

        for (uint32_t off = 0; off + 32 <= TNX_SNAPSHOT_BYTES; off += 32) {
            uint32_t words[8] = {0, 0, 0, 0, 0, 0, 0, 0};

            if (!tnx_read_bytes((uintptr_t)object + off, words, sizeof(words))) break;

            tnx_logf("obj[%s][%d] +%03x %08x %08x %08x %08x %08x %08x %08x %08x",
                     tag, i, off, words[0], words[1], words[2], words[3],
                     words[4], words[5], words[6], words[7]);
        }
    }
}

static void tnx_report_manager(const char *tag, uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!tnx_pointer_plausible(manager)) return;

    if (!tnx_owner_is_heap(manager)) {
        tnx_logf("%s mgr=%p rejected: not a heap allocation", tag, (void *)manager);
        return;
    }

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) {
        tnx_logf("%s mgr=%p unreadable", tag, (void *)manager);
        return;
    }
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return;

    tnx_logf("%s mgr=%p array=%p count=%d cap=%d live=%d%s", tag, (void *)manager, array,
             count, capacity, tnx_manager_live_count(manager),
             (capacity >= count && capacity <= TNX_MGR_CAP_MAX) ? "" : " CAP-VIOLATION");

    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return;
    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return;

    tnx_dump_manager(manager, (int)count);
}

#define TNX_DODGE_RADIUS 320
#define TNX_DODGE_STEP 600
#define TNX_DODGE_SCALE 4096
#define TNX_OBJECT_DETAIL_MAX 8
#define TNX_TRAIL_MAX 8
#define TNX_BEST_DETAIL_MAX 12

typedef struct {
    uintptr_t manager;
    int32_t count;
    int32_t capacity;
    int live;
    int nonEmpty;
    int stable;
} tnx_trail_t;

static tnx_trail_t g_trail[TNX_TRAIL_MAX];
static int g_trail_count = 0;
static uint64_t g_trail_total = 0;

#define TNX_SEEN_MAX 512

typedef struct {
    uintptr_t address;
    int32_t count;
    int pass;
} tnx_seen_t;

static tnx_seen_t g_seen[TNX_SEEN_MAX];

static BOOL tnx_candidate_is_stable(uintptr_t address, int32_t count) {
    size_t slot = (size_t)((address >> 4) % (uintptr_t)TNX_SEEN_MAX);
    tnx_seen_t *entry = &g_seen[slot];

    if (entry->address && entry->address == address) {
        BOOL stable = (entry->count == count && entry->pass != g_heap_passes);

        entry->count = count;
        entry->pass = g_heap_passes;

        if (stable) g_seen_stable++;

        return stable;
    }

    if (!entry->address || entry->pass != g_heap_passes) {
        entry->address = address;
        entry->count = count;
        entry->pass = g_heap_passes;
    }

    return NO;
}

static int tnx_trail_beats_slot(int live, int nonEmpty, int32_t count, int slot) {
    if (live != g_trail[slot].live) return live > g_trail[slot].live;
    if (nonEmpty != g_trail[slot].nonEmpty) return nonEmpty > g_trail[slot].nonEmpty;

    return count > g_trail[slot].count;
}

static int tnx_trail_ranked(int *out, int max) {
    uint8_t used[TNX_TRAIL_MAX];
    int count = 0;

    memset(used, 0, sizeof(used));

    for (int k = 0; k < max; k++) {
        int best = -1;

        for (int i = 0; i < g_trail_count; i++) {
            if (used[i]) continue;
            if (best < 0) {
                best = i;

                continue;
            }

            if (tnx_trail_beats_slot(g_trail[i].live, g_trail[i].nonEmpty, g_trail[i].count, best)) {
                best = i;
            }
        }

        if (best < 0) break;

        used[best] = 1;
        out[count++] = best;
    }

    return count;
}

static void tnx_trail_rebest(void) {
    int rank[TNX_TRAIL_MAX];
    int n = tnx_trail_ranked(rank, TNX_TRAIL_MAX);

    g_trail_best = (n > 0) ? rank[0] : -1;
}

static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty) {
    int slot = -1;
    int stable = tnx_candidate_is_stable(manager, count) ? 1 : 0;

    g_trail_total++;

    if (live > g_manager_best_live) g_manager_best_live = live;

    for (int i = 0; i < g_trail_count; i++) {
        if (g_trail[i].manager == manager) {
            g_trail[i].count = count;
            g_trail[i].capacity = capacity;
            g_trail[i].live = live;
            g_trail[i].nonEmpty = nonEmpty;
            g_trail[i].stable = stable;
            slot = i;

            goto ranked;
        }
    }

    if (g_trail_count < TNX_TRAIL_MAX) {
        slot = g_trail_count++;
    } else {
        int worst = 0;

        for (int i = 1; i < TNX_TRAIL_MAX; i++) {
            if (tnx_trail_beats_slot(g_trail[worst].live, g_trail[worst].nonEmpty,
                                     g_trail[worst].count, i)) {
                worst = i;
            }
        }

        if (!tnx_trail_beats_slot(live, nonEmpty, count, worst)) return;

        slot = worst;
    }

    g_trail[slot].manager = manager;
    g_trail[slot].count = count;
    g_trail[slot].capacity = capacity;
    g_trail[slot].live = live;
    g_trail[slot].nonEmpty = nonEmpty;
    g_trail[slot].stable = stable;

ranked:
    tnx_trail_rebest();
}

static void tnx_trail_dump(void) {
    int rank[TNX_TRAIL_MAX];
    int n = tnx_trail_ranked(rank, TNX_TRAIL_MAX);

    tnx_logf("trail: %llu candidates passed the array header, top eight by (live, nonEmpty, count)",
             (unsigned long long)g_trail_total);

    for (int k = 0; k < n; k++) {
        int i = rank[k];

        tnx_logf("trail[%d] rank=%d mgr=%p count=%d cap=%d live=%d nonEmpty=%d ratio=%d%% "
                 "stable=%d%s",
                 i, k, (void *)g_trail[i].manager, g_trail[i].count, g_trail[i].capacity,
                 g_trail[i].live, g_trail[i].nonEmpty,
                 g_trail[i].count > 0 ? (g_trail[i].live * 100) / g_trail[i].count : 0,
                 g_trail[i].stable, (k == 0) ? " <- best" : "");
    }
}

static void tnx_slot_table_dump(void) {
    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        tnx_logf("hook[%d] %-4s target=%#llx slotRva=%#llx repl=%p control=%d",
                 i, g_slot_specs[i].shortTag,
                 (unsigned long long)g_slot_specs[i].rva,
                 (unsigned long long)g_slot_specs[i].slotRva,
                 (void *)g_slot_specs[i].replacement,
                 g_slot_specs[i].control ? 1 : 0);
    }
}

static void tnx_raw_object_hex(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > limit) count = limit;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        tnx_dump_hex("rawObj", (uintptr_t)element, 0x40);
        tnx_dump_hex("rawObjB", (uintptr_t)element + 0xc0, 0x20);
    }
}

typedef struct {
    const char *label;
    const char *value;
    const char *provenance;
} tnx_fact_t;

static const tnx_fact_t g_tnx_facts[] = {
    { "mode+0x28 = object manager", "0x28", "engine code at 0xac3ddc loads it here" },
    { "manager+0x0 = object array", "0x0", "engine append routine 0x46aefc" },
    { "manager+0x8 = capacity", "0x8", "engine append routine 0x46aefc" },
    { "manager+0xc = count", "0xc", "engine append routine 0x46aefc" },
    { "array stride", "8", "64-bit targets" },
    { "object+0x8 = global id", "0x8", "addGameObject writes it at 0xa278e4" },
    { "object+0x20 = owning manager", "0x20", "setOwner is str x1,[x0,#0x20]" },
    { "object+0x3c = owner index", "0x3c", "REvengeBS" },
    { "object+0x40 = team", "0x40", "two independent loops in the class code" },
    { "object+0xd0 = dead flag, byte", "0xd0", "REvengeBS reads uint8_t" },
    { "slot +0x18 = setOwner", "0x18", "addGameObject calls it with the manager in x1" },
    { "slot +0x88 = not getX", "0x88", "call site 0xae48f0 loads an int argument before blr" },
    { "slot +0x90 = getY", "0x90", "eight bytes after getX" },
    { "count ceiling", "96", "a real battle holds tens of entities" },
    { "capacity ceiling", "4096", "no real array is allocated four billion entries" },
    { "live ratio", "3/4", "string tables decode as instances in a couple of slots" },
    { "manager probe budget", "65536", "the 2048 of titanox_35 went blind in seconds" },
    { NULL, NULL, NULL }
};

static void tnx_struct_map_dump(void) {
    tnx_logf("contract: %d invariants, offsets below are the ones actually in use",
             (int)(sizeof(g_tnx_facts) / sizeof(g_tnx_facts[0])) - 1);

    for (int i = 0; g_tnx_facts[i].label; i++) {
        tnx_logf("contract %-30s %-6s %s", g_tnx_facts[i].label, g_tnx_facts[i].value,
                 g_tnx_facts[i].provenance);
    }

    tnx_logf("contract numbers mode+0x28=%#llx mgr array=%#llx cap=%#llx count=%#llx "
             "obj team=%#llx dead=%#llx gid=%#llx own=%#llx",
             (unsigned long long)TNX_MODE_MANAGER_OFF,
             (unsigned long long)TNX_MGR_ARRAY_OFF,
             (unsigned long long)TNX_MGR_CAP_OFF,
             (unsigned long long)TNX_MGR_COUNT_OFF,
             (unsigned long long)TNX_OBJ_TEAM_OFF,
             (unsigned long long)TNX_OBJ_DEADFLAG_OFF,
             (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_OBJ_OWNERINDEX_OFF);

    tnx_logf("contract slots s88=%#llx s90=%#llx owner=%#llx list=%#llx listCount=%#llx",
             (unsigned long long)TNX_OBJ_GETX_SLOT,
             (unsigned long long)TNX_OBJ_GETY_SLOT,
             (unsigned long long)TNX_SLOT_OWNER_OFF,
             (unsigned long long)TNX_SLOT_LIST_OFF,
             (unsigned long long)TNX_SLOT_LISTCOUNT_OFF);
}

static int64_t tnx_isqrt(int64_t value) {
    int64_t guess = 0;

    if (value <= 0) return 0;
    if (value > (int64_t)1 << 62) return (int64_t)1 << 31;

    guess = value;

    for (int i = 0; i < 64; i++) {
        int64_t next = (guess + value / (guess > 0 ? guess : 1)) / 2;

        if (next >= guess) break;
        guess = next;
    }

    return guess;
}

static int tnx_object_detail(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int shown = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;
    if (count <= 0) return 0;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;
    if (limit > 0 && count > limit) count = limit;

    tnx_logf("objtable array=%p count=%d cap=%d", array, count, capacity);

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;
        void *slotOwner = NULL;
        void *slotAlive = NULL;
        void *slotKind = NULL;
        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        int32_t x = 0;
        int32_t y = 0;
        uint8_t dead = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        shown++;

        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;

        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_OWNER_OFF, &slotOwner);
        tnx_read_ptr((uintptr_t)vtable + 0x28, &slotAlive);
        tnx_read_ptr((uintptr_t)vtable + 0x48, &slotKind);

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETY_SLOT, &s90);

        tnx_logf("obj[%02d] %p vt=%#llx gid=%d team=%d own=%d dead=%d s88=%#llx s90=%#llx "
                 "s18=%#llx s28=%#llx s48=%#llx shape=%d",
                 i, element, (unsigned long long)tnx_vtable_rva(element), globalId, team, owner,
                 dead, (unsigned long long)s88, (unsigned long long)s90,
                 (unsigned long long)(slotOwner ? (uintptr_t)slotOwner - g_base : 0),
                 (unsigned long long)(slotAlive ? (uintptr_t)slotAlive - g_base : 0),
                 (unsigned long long)(slotKind ? (uintptr_t)slotKind - g_base : 0),
                 tnx_gameobject_shape((uintptr_t)element) ? 1 : 0);
    }

    return shown;
}

static int tnx_object_detail_readonly(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int shown = 0;
    int instances = 0;
    int teams[TNX_OBJ_TEAM_MAX + 1];
    int noArray = 0;
    int noCount = 0;
    int unreadable = 0;
    int noVt = 0;
    int noTeam = 0;
    int allDead = 0;
    int outOfRange = 0;

    for (int i = 0; i <= TNX_OBJ_TEAM_MAX; i++) teams[i] = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) {
        noArray = 1;

        goto summary;
    }

    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) {
        noCount = 1;

        goto summary;
    }

    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) {
        noCount = 1;

        goto summary;
    }

    if (count <= 0) {
        noCount = 1;

        goto summary;
    }

    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;
    if (limit > 0 && count > limit) count = limit;

    tnx_logf("best array=%p count=%d cap=%d", array, count, capacity);

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;
        void *slotOwner = NULL;
        void *slotAlive = NULL;
        void *slotKind = NULL;
        void *slotX = NULL;
        void *slotY = NULL;
        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        uint8_t dead = 0;
        int shaped = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) {
            unreadable++;

            break;
        }

        if (!element) continue;

        if (!tnx_read_ptr((uintptr_t)element, &vtable) || !vtable) {
            noVt++;

            continue;
        }

        {
            uintptr_t vtRva = (uintptr_t)vtable - g_base;

            if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
                noVt++;

                continue;
            }
        }

        shaped = tnx_gameobject_shape((uintptr_t)element) ? 1 : 0;
        if (shaped) instances++;

        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_OWNER_OFF, &slotOwner);
        tnx_read_ptr((uintptr_t)vtable + 0x28, &slotAlive);
        tnx_read_ptr((uintptr_t)vtable + 0x48, &slotKind);
        tnx_read_ptr((uintptr_t)vtable + TNX_OBJ_GETX_SLOT, &slotX);
        tnx_read_ptr((uintptr_t)vtable + TNX_OBJ_GETY_SLOT, &slotY);

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        if (team < 0 || team > TNX_OBJ_TEAM_MAX) noTeam++;
        if (dead > 1) allDead++;

        {
            int32_t px = 0;
            int32_t py = 0;

            tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px);
            tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py);

            if (px <= -TNX_V47_COORD_ABS_MAX || px >= TNX_V47_COORD_ABS_MAX ||
                py <= -TNX_V47_COORD_ABS_MAX || py >= TNX_V47_COORD_ABS_MAX) outOfRange++;
        }

        if (team >= 0 && team <= TNX_OBJ_TEAM_MAX) teams[team]++;

        tnx_logf("best[%02d] %p vt=%#llx gid=%d team=%d own=%d dead=%d shape=%d "
                 "s18=%#llx s28=%#llx s48=%#llx s88=%#llx s90=%#llx",
                 i, element, (unsigned long long)tnx_vtable_rva(element), globalId, team, owner,
                 dead, shaped,
                 (unsigned long long)(slotOwner ? (uintptr_t)slotOwner - g_base : 0),
                 (unsigned long long)(slotAlive ? (uintptr_t)slotAlive - g_base : 0),
                 (unsigned long long)(slotKind ? (uintptr_t)slotKind - g_base : 0),
                 (unsigned long long)(slotX ? (uintptr_t)slotX - g_base : 0),
                 (unsigned long long)(slotY ? (uintptr_t)slotY - g_base : 0));

        shown++;
    }

summary:
    tnx_logf("v55 best summary shown=%d instances=%d teams=%d/%d/%d/%d reasons: noArray=%d "
             "noCount=%d unreadable=%d noVt=%d noTeam=%d allDead=%d outOfRange=%d",
             shown, instances, teams[0], teams[1], teams[2], teams[3], noArray, noCount,
             unreadable, noVt, noTeam, allDead, outOfRange);

    return shown;
}

static void tnx_best_candidate_dump(void) {
    int rank[TNX_TRAIL_MAX];
    int n = tnx_trail_ranked(rank, TNX_TRAIL_MAX);
    int chosen = -1;

    if (g_trail_count <= 0 || n <= 0) return;

    for (int k = 0; k < n; k++) {
        int i = rank[k];
        int shown = tnx_object_detail_readonly(g_trail[i].manager, TNX_BEST_DETAIL_MAX);

        if (shown > 0) {
            chosen = i;

            break;
        }
    }

    if (chosen < 0) {
        g_trail_best = -1;

        tnx_logf("v55 best not chosen: none of the %d recorded candidates yielded a single instance "
                 "- the reason is in the summary lines above", n);

        return;
    }

    if (chosen != g_trail_best) {
        tnx_logf("v55 best moved from index %d to index %d: the higher-ranked candidate's summary "
                 "extracted nothing", g_trail_best, chosen);
    }

    g_trail_best = chosen;

    tnx_logf("v55 best candidate index=%d mgr=%p count=%d cap=%d live=%d nonEmpty=%d",
             g_trail_best, (void *)g_trail[g_trail_best].manager,
             g_trail[g_trail_best].count, g_trail[g_trail_best].capacity,
             g_trail[g_trail_best].live, g_trail[g_trail_best].nonEmpty);
}

typedef void (*tnx_v47_setpred_t)(void *self, int x, int y);

typedef struct {
    uintptr_t object;
    int32_t   gid;
    int32_t   x;
    int32_t   y;
    int32_t   ownerIndex;
    int32_t   teamOld;
    int32_t   teamNew;
    uint8_t   dead;
    uint8_t   activeFlag;
} tnx_v47_obj_t;

static uintptr_t g_v47_setpred = 0;
static int g_v47_setpred_state = -1;
static int g_v47_probe_done = 0;

static uintptr_t g_v47_probe_object = 0;
static uint64_t g_v47_probe_last_ms = 0;
static int g_v47_coord_ok = 0;
static int g_v47_coord_usable = 0;
static int g_v47_coord_distinct = 0;
static int g_v47_team_off = 0x4c;
static int g_v47_map_w = 0;
static int g_v47_map_h = 0;
static int g_v47_map_ok = 0;
static uint64_t g_v47_ticks = 0;
static uint64_t g_v47_threat_ticks = 0;
static uint64_t g_v47_writes = 0;
static uint64_t g_v47_last_write_ms = 0;
static int g_v47_giveup_logs = 0;

static uint64_t g_v48_ticks = 0;
static int g_v48_entry_logs = 0;
static uintptr_t g_v48_manager = 0;

static int tnx_v47_verify_setprediction(void) {
    static const uint32_t expected[3] = { 0xb901d401u, 0xb901d802u, 0xd65f03c0u };
    uint32_t words[3] = { 0, 0, 0 };
    uintptr_t address = 0;

    if (!g_base) return 0;

    address = g_base + TNX_RVA_SETPREDICTION;

    if (!tnx_addr_readable(address, sizeof(words))) return 0;
    if (!tnx_read_bytes(address, words, sizeof(words))) return 0;

    for (int i = 0; i < 3; i++) {
        if (words[i] != expected[i]) {
            tnx_logf("v55 setprediction fingerprint MISMATCH word[%d]=%08x expected=%08x at %#llx",
                     i, words[i], expected[i], (unsigned long long)TNX_RVA_SETPREDICTION);
            return 0;
        }
    }

    tnx_logf("v55 setprediction fingerprint verified at %#llx (str w1,[x0,#0x1d4]; str w2,[x0,#0x1d8]; "
             "ret) - the BYTES match; nothing has been written yet",
             (unsigned long long)TNX_RVA_SETPREDICTION);

    return 1;
}

static void tnx_v47_read_map(uintptr_t mode) {
    void *tileMap = NULL;
    int32_t width = 0;
    int32_t height = 0;

    g_v47_map_ok = 0;
    g_v47_map_w = 0;
    g_v47_map_h = 0;

    if (!tnx_read_ptr(mode + TNX_MODE_TILEMAP_OFF, &tileMap) || !tileMap) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_WIDTH_OFF, &width)) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_HEIGHT_OFF, &height)) return;

    g_v47_map_w = width;
    g_v47_map_h = height;
    g_v47_map_ok = (width >= TNX_V47_MAP_MIN && width <= TNX_V47_MAP_MAX &&
                    height >= TNX_V47_MAP_MIN && height <= TNX_V47_MAP_MAX) ? 1 : 0;
}

typedef struct {
    int elementsRead;
    int rejNull;
    int rejUnreadable;
    int rejAscii;
    int rejNoVt;
    int rejGidZero;
    int rejOutOfRange;
    int rejTeamMissing;
    int deadSeen;
} tnx_v50_reject_t;

static tnx_v50_reject_t g_v50_reject;

static const char *tnx_v50_reject_text(char *buf, size_t size) {
    snprintf(buf, size,
             "elements=%d rejNull=%d rejUnreadable=%d rejAscii=%d rejNoVt=%d rejGidZero=%d "
             "rejOutOfRange=%d rejTeamMissing=%d deadSeen=%d",
             g_v50_reject.elementsRead, g_v50_reject.rejNull, g_v50_reject.rejUnreadable,
             g_v50_reject.rejAscii, g_v50_reject.rejNoVt, g_v50_reject.rejGidZero,
             g_v50_reject.rejOutOfRange, g_v50_reject.rejTeamMissing, g_v50_reject.deadSeen);

    return buf;
}

static int tnx_v48_collect(uintptr_t manager, tnx_v47_obj_t *out, int capacity, int *rejected) {
    void *data = NULL;
    int32_t count = 0;
    int usable = 0;
    int bad = 0;

    memset(&g_v50_reject, 0, sizeof(g_v50_reject));

    if (rejected) *rejected = 0;

    if (!manager) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0) return 0;

    if (count > capacity) count = capacity;

    for (int32_t i = 0; i < count && usable < capacity; i++) {
        void *element = NULL;
        void *vtable = NULL;
        tnx_v47_obj_t entry;
        uintptr_t vtRva = 0;

        memset(&entry, 0, sizeof(entry));

        g_v50_reject.elementsRead++;

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * sizeof(void *), &element)) {
            g_v50_reject.rejUnreadable++;
            bad++;

            continue;
        }

        if (!element) {
            g_v50_reject.rejNull++;
            bad++;

            continue;
        }

        entry.object = (uintptr_t)element;

        if (tnx_v52_ascii_word(entry.object)) {
            g_v50_reject.rejAscii++;
            g_v52_ascii_rejected++;
            bad++;

            continue;
        }

        if (!tnx_read_ptr(entry.object, &vtable) || !vtable) {
            g_v50_reject.rejUnreadable++;
            bad++;

            continue;
        }

        vtRva = (uintptr_t)vtable - g_base;

        if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
            g_v50_reject.rejNoVt++;
            bad++;

            continue;
        }

        if (!tnx_read_i32(entry.object + TNX_OBJ_GLOBALID_OFF, &entry.gid) ||
            !tnx_read_i32(entry.object + tnx_v57_coord_x_off(), &entry.x) ||
            !tnx_read_i32(entry.object + tnx_v57_coord_y_off(), &entry.y) ||
            !tnx_read_i32(entry.object + TNX_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
            !tnx_read_i32(entry.object + TNX_OBJ_TEAM_OFF, &entry.teamOld) ||
            !tnx_read_i32(entry.object + TNX_OBJ_TEAMENGINE_OFF, &entry.teamNew) ||
            !tnx_read_u8(entry.object + TNX_OBJ_DEADFLAG_OFF, &entry.dead) ||
            !tnx_read_u8(entry.object + TNX_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag)) {
            g_v50_reject.rejUnreadable++;
            bad++;

            continue;
        }

        if (entry.gid == 0) {
            g_v50_reject.rejGidZero++;
            bad++;

            continue;
        }

        if (entry.x <= -TNX_V47_COORD_ABS_MAX || entry.x >= TNX_V47_COORD_ABS_MAX ||
            entry.y <= -TNX_V47_COORD_ABS_MAX || entry.y >= TNX_V47_COORD_ABS_MAX) {
            g_v50_reject.rejOutOfRange++;
            bad++;

            continue;
        }

        if (!((entry.teamOld >= 0 && entry.teamOld <= TNX_OBJ_TEAM_MAX) ||
              (entry.teamNew >= 0 && entry.teamNew <= TNX_OBJ_TEAM_MAX))) {
            g_v50_reject.rejTeamMissing++;
            bad++;

            continue;
        }

        if (entry.dead == 1) g_v50_reject.deadSeen++;

        out[usable++] = entry;
    }

    if (rejected) *rejected = bad;

    return usable;
}

#define TNX_V48_ELEMS 8
#define TNX_V48_WORDS 24
#define TNX_V48_VALUE_MAX 1000000
#define TNX_V48_FLOAT_MAX 10000.0f
#define TNX_V48_TEAM_MAX 8

static int tnx_v48_small(long value) {
    return (value > -TNX_V48_VALUE_MAX && value < TNX_V48_VALUE_MAX) ? 1 : 0;
}

static float tnx_v48_as_float(uint32_t bits) {
    union { uint32_t u; float f; } view;

    view.u = bits;

    return view.f;
}

static void tnx_v48_discriminate(uintptr_t manager) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    uint32_t words[TNX_V48_ELEMS][TNX_V48_WORDS];
    int rejected = 0;
    int usable = 0;
    int n = 0;
    int teamOff = -1;
    int teamDistinct = 0;
    int coordOff = -1;
    int coordDistinct = 0;
    int intPairOff = -1;
    int floatPairOff = -1;

    memset(objects, 0, sizeof(objects));
    memset(words, 0, sizeof(words));

    usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    if (usable == 0) {
        char reasons[320];

        if (rejected > 0 || g_v50_reject.elementsRead > 0) {
            tnx_logf("v55 fields manager=%p usable=0 rejected=%d -- all elements rejected: %s",
                     (void *)manager, rejected, tnx_v50_reject_text(reasons, sizeof(reasons)));
        } else {
            tnx_logf("v55 fields manager=%p usable=0 rejected=0 -- no elements in container",
                     (void *)manager);
        }

        return;
    }

    if (usable == 1) {
        char reasons[320];

        tnx_logf("v55 fields manager=%p usable=1 rejected=%d -- one element is not enough to tell "
                 "one field from another: %s",
                 (void *)manager, rejected, tnx_v50_reject_text(reasons, sizeof(reasons)));

        return;
    }

    n = (usable < TNX_V48_ELEMS) ? usable : TNX_V48_ELEMS;

    for (int i = 0; i < n; i++) {
        if (!tnx_read_bytes(objects[i].object, words[i], sizeof(words[i]))) {
            tnx_logf("v55 fields element %d at %p unreadable over 0x%x bytes",
                     i, (void *)objects[i].object, (unsigned)sizeof(words[i]));
            return;
        }
    }

    tnx_logf("v55 fields manager=%p usable=%d rejected=%d sample=%d window=+0x0..+0x%x",
             (void *)manager, usable, rejected, n, (unsigned)((TNX_V48_WORDS - 1) * 4));

    for (int w = 0; w < TNX_V48_WORDS; w++) {
        int distinct = 0;
        int allSmall = 1;
        int allTiny = 1;
        int64_t minV = 0;
        int64_t maxV = 0;

        for (int i = 0; i < n; i++) {
            int32_t value = (int32_t)words[i][w];
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (words[j][w] == words[i][w]) { seen = 1; break; }
            }

            if (!seen) distinct++;

            if (i == 0) { minV = value; maxV = value; }
            if (value < minV) minV = value;
            if (value > maxV) maxV = value;

            if (!tnx_v48_small(value)) allSmall = 0;
            if (value < 0 || value > 15) allTiny = 0;
        }

        if (distinct <= 1) continue;

        tnx_logf("v55 off +0x%02x distinct=%d/%d min=%lld max=%lld small=%d tiny=%d %s%s",
                 w * 4, distinct, n, (long long)minV, (long long)maxV, allSmall, allTiny,
                 (allTiny && distinct >= 2 && distinct <= TNX_V48_TEAM_MAX) ? "TEAM? " : "",
                 (allSmall && distinct == n) ? "VARIES/PAIR-MEMBER?" : "");

        if (teamOff < 0 && allTiny && distinct >= 2 && distinct <= TNX_V48_TEAM_MAX) {
            teamOff = w * 4;
            teamDistinct = distinct;
        }

        if (coordOff < 0 && allSmall && distinct == n) {
            coordOff = w * 4;
            coordDistinct = distinct;
        }
    }

    if (teamOff == (int)TNX_OBJ_X_OFF || teamOff == (int)TNX_OBJ_Y_OFF) {
        tnx_logf("v65 walk error: teamOff=+0x%x equals the repository coordinate offset, so the "
                 "walk hit strings and not objects - the team offset is refused and left unset",
                 teamOff);

        teamOff = -1;
        teamDistinct = 0;
    }

    if (teamOff < 0) {
        tnx_logf("v65 teamOff unset after the walk, the engine's own +0x4c is used src=log-v55");
    }

    {
        int order[TNX_V48_WORDS];
        int orderCount = 0;
        int defaultWord = (int)(TNX_OBJ_X_OFF / 4);

        if (defaultWord >= 0 && defaultWord + 1 < TNX_V48_WORDS) order[orderCount++] = defaultWord;

        for (int w = 0; w + 1 < TNX_V48_WORDS; w++) {
            if (w != defaultWord) order[orderCount++] = w;
        }

        for (int k = 0; k < orderCount && intPairOff < 0; k++) {
            int w = order[k];
            int ok = 1;
            int dx = 0;
            int dy = 0;

            if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff)) continue;

            for (int i = 0; i < n && ok; i++) {
                if (!tnx_v48_small((int32_t)words[i][w])) ok = 0;
                if (!tnx_v48_small((int32_t)words[i][w + 1])) ok = 0;
            }

            if (!ok) continue;

            for (int i = 0; i < n; i++) {
                int seenX = 0;
                int seenY = 0;

                for (int j = 0; j < i; j++) {
                    if (words[j][w] == words[i][w]) seenX = 1;
                    if (words[j][w + 1] == words[i][w + 1]) seenY = 1;
                }

                if (!seenX) dx++;
                if (!seenY) dy++;
            }

            if (dx == n && dy == n) {
                intPairOff = w * 4;

                tnx_logf("v65 coord pair int32 at +0x%02x,+0x%02x all %d distinct team=+0x%x "
                         "excluded from the candidates", w * 4, (w + 1) * 4, n, teamOff);
            }
        }
    }

    for (int w = 0; w + 1 < TNX_V48_WORDS && floatPairOff < 0; w++) {
        int ok = 1;
        int anyNonZero = 0;
        int distinctPairs = 0;
        int seenAny = 0;
        float fx = 0.0f;
        float fy = 0.0f;

        if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff)) continue;

        for (int i = 0; i < n; i++) {
            float ax = tnx_v48_as_float(words[i][w]);
            float ay = tnx_v48_as_float(words[i][w + 1]);
            int seen = 0;

            if (!(ax > -TNX_V48_FLOAT_MAX && ax < TNX_V48_FLOAT_MAX)) ok = 0;
            if (!(ay > -TNX_V48_FLOAT_MAX && ay < TNX_V48_FLOAT_MAX)) ok = 0;
            if (words[i][w] != 0 || words[i][w + 1] != 0) anyNonZero = 1;

            if (i == 0) { fx = ax; fy = ay; }

            for (int j = 0; j < i; j++) {
                if (words[j][w] == words[i][w] && words[j][w + 1] == words[i][w + 1]) { seen = 1; break; }
            }

            if (!seen) { distinctPairs++; if (i > 0) seenAny = 1; }
        }

        if (!ok || !anyNonZero || !seenAny) continue;

        floatPairOff = w * 4;

        tnx_logf("v55 coord pair float32 at +0x%02x,+0x%02x first=(%.3f,%.3f) distinct=%d/%d",
                 w * 4, (w + 1) * 4, fx, fy, distinctPairs, n);
    }

    tnx_logf("v55 named teamOff=%s0x%x distinct=%d | coordOff=%s0x%x distinct=%d | "
             "intPair=%s0x%x | floatPair=%s0x%x",
             teamOff >= 0 ? "+" : "none:", teamOff >= 0 ? teamOff : 0, teamDistinct,
             coordOff >= 0 ? "+" : "none:", coordOff >= 0 ? coordOff : 0, coordDistinct,
             intPairOff >= 0 ? "+" : "none:", intPairOff >= 0 ? intPairOff : 0,
             floatPairOff >= 0 ? "+" : "none:", floatPairOff >= 0 ? floatPairOff : 0);

    if (intPairOff >= 0) {
        if (g_v57_coord_off != intPairOff) {
            g_v57_coord_off = intPairOff;

            if ((uintptr_t)intPairOff == TNX_OBJ_X_OFF) {
                tnx_logf("v65 coord pair chosen=+0x%x,+0x%x (%d distinct) = repository default, "
                         "team=+0x%x excluded", intPairOff, intPairOff + 4, n, teamOff);
            } else {
                tnx_logf("v65 coord pair chosen=+0x%x,+0x%x (%d distinct), repository default "
                         "+0x%llx/+0x%llx did not pass, team=+0x%x excluded", intPairOff,
                         intPairOff + 4, n, (unsigned long long)TNX_OBJ_X_OFF,
                         (unsigned long long)TNX_OBJ_Y_OFF, teamOff);
            }
        }
    } else if (coordOff >= 0 && g_v57_coord_off != coordOff) {
        g_v57_coord_off = coordOff;

        tnx_logf("v65 coord offset chosen=+0x%x (%d distinct) single int32, team=+0x%x excluded",
                 coordOff, coordDistinct, teamOff);
    }
}

#define TNX_V50_RAW_ELEMS 4

static void tnx_v50_raw_team_probe(uintptr_t manager) {
    void *data = NULL;
    int32_t count = 0;
    int shown = 0;
    int32_t oldSeen[TNX_V50_RAW_ELEMS];
    int32_t newSeen[TNX_V50_RAW_ELEMS];
    int oldDistinct = 0;
    int newDistinct = 0;

    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;

    if (count > TNX_V50_RAW_ELEMS) count = TNX_V50_RAW_ELEMS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t plus40 = 0;
        int32_t plus4c = 0;
        int32_t gid = 0;
        uint8_t dead = 0;
        int seenOld = 0;
        int seenNew = 0;

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * sizeof(void *), &element) || !element) {
            tnx_logf("v55 raw[%d] element unreadable - the container cannot be walked at all", i);

            continue;
        }

        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &plus40);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAMENGINE_OFF, &plus4c);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        tnx_logf("v55 raw[%d] %p gid=%d plus40=%d plus4c=%d dead=%d", i, (void *)element, gid,
                 plus40, plus4c, dead);

        for (int j = 0; j < shown; j++) {
            if (oldSeen[j] == plus40) seenOld = 1;
            if (newSeen[j] == plus4c) seenNew = 1;
        }

        if (!seenOld) oldDistinct++;
        if (!seenNew) newDistinct++;

        oldSeen[shown] = plus40;
        newSeen[shown] = plus4c;
        shown++;
    }

    if (shown <= 0) return;

    tnx_logf("v55 team probe raw=%d distinct(+0x40)=%d distinct(+0x4c)=%d", shown, oldDistinct,
             newDistinct);
}

static void tnx_v52_dead_probe(uintptr_t manager) {
    static uint64_t calls = 0;
    void *array = NULL;
    int32_t count = 0;
    int zero = 0;
    int one = 0;
    int other = 0;
    int shown = 0;

    calls++;

    if ((calls % 5) != 1) return;
    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;

    if (count > TNX_V50_RAW_ELEMS) count = TNX_V50_RAW_ELEMS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        uint8_t d0 = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element) || !element) {
            continue;
        }

        if (!tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &d0)) continue;

        if (d0 == 0) zero++;
        else if (d0 == 1) one++;
        else other++;

        shown++;

        tnx_logf("v55 dead probe elem[%d] %p c8=%02x cc=%02x d0=%02x d4=%02x d8=%02x", i,
                 (void *)element, tnx_v52_byte((uintptr_t)element, 0xc8),
                 tnx_v52_byte((uintptr_t)element, 0xcc), d0,
                 tnx_v52_byte((uintptr_t)element, 0xd4),
                 tnx_v52_byte((uintptr_t)element, 0xd8));
    }

    if (!shown) return;

    tnx_logf("v55 dead probe window: d0zero=%d d0one=%d d0other=%d of %d - if d0other is not zero the "
             "byte at %#llx is not a dead flag and must not be used as one", zero, one, other, shown,
             (unsigned long long)TNX_OBJ_DEADFLAG_OFF);
}

static void tnx_v48_probe(uintptr_t manager, uintptr_t mode, int verbose) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    int rejected = 0;
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int teamsNew[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int distinctOld = 0;
    int distinctNew = 0;

    memset(objects, 0, sizeof(objects));

    g_v47_probe_done = 1;

    if (mode) tnx_v47_read_map(mode);

    usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    for (int i = 0; i < usable; i++) {
        if (objects[i].x > -TNX_V47_COORD_ABS_MAX && objects[i].x < TNX_V47_COORD_ABS_MAX &&
            objects[i].y > -TNX_V47_COORD_ABS_MAX && objects[i].y < TNX_V47_COORD_ABS_MAX) {
            inRange++;
        }

        if (objects[i].teamOld >= 0 && objects[i].teamOld < 8) teamsOld[objects[i].teamOld] = 1;
        if (objects[i].teamNew >= 0 && objects[i].teamNew < 8) teamsNew[objects[i].teamNew] = 1;

        {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].x == objects[i].x && objects[j].y == objects[i].y) { seen = 1; break; }
            }

            if (!seen) distinct++;
        }
    }

    for (int i = 0; i < 8; i++) {
        if (teamsOld[i]) distinctOld++;
        if (teamsNew[i]) distinctNew++;
    }

    g_v47_team_off = (distinctOld > distinctNew) ? (int)TNX_OBJ_TEAM_OFF : (int)TNX_OBJ_TEAMENGINE_OFF;

    {
        char reasons[320];

        tnx_logf("v55 man walk mode=%p manager=%p usable=%d rejected=%d (%s) mapOk=%d mapW=%d "
                 "mapH=%d inRange=%d distinct=%d teamsOld=%d teamsNew=%d teamOff=0x%x",
                 (void *)mode, (void *)manager, usable, rejected,
                 tnx_v50_reject_text(reasons, sizeof(reasons)), g_v47_map_ok, g_v47_map_w,
                 g_v47_map_h, inRange, distinct, distinctOld, distinctNew, g_v47_team_off);
    }

    tnx_logf("v55 teamOff chosen=+0x%x because distinct(+0x40)=%d distinct(+0x4c)=%d (the field "
             "that splits the elements into more sides wins; a tie keeps the engine's own +0x4c, which is "
             "the offset the engine itself reads)",
             g_v47_team_off, distinctOld, distinctNew);

    tnx_logf("v65 walk offsets team=+0x%x distinctOld=%d distinctNew=%d coord=+0x%llx/+0x%llx "
             "usable=%d distinct=%d inRange=%d - chosen from the measurements, not from a constant",
             g_v47_team_off, distinctOld, distinctNew,
             (unsigned long long)tnx_v57_coord_x_off(), (unsigned long long)tnx_v57_coord_y_off(),
             usable, distinct, inRange);

    tnx_v50_raw_team_probe(manager);
    tnx_v52_dead_probe(manager);

    if (verbose) {
        tnx_logf("v55 offsets obj off=0x%llx/0x%llx x=0x%llx y=0x%llx teamOld=0x%llx teamNew=0x%llx "
                 "owner=0x%llx dead=0x%llx active=0x%llx tilemap=0x%llx w=0x%llx",
                 TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF, TNX_OBJ_X_OFF, TNX_OBJ_Y_OFF,
                 TNX_OBJ_TEAM_OFF, TNX_OBJ_TEAMENGINE_OFF, TNX_OBJ_OWNERINDEX_OFF,
                 TNX_OBJ_DEADFLAG_OFF, TNX_OBJ_ACTIVEFLAG_OFF,
                 TNX_MODE_TILEMAP_OFF, TNX_TILEMAP_WIDTH_OFF);

        for (int i = 0; i < usable && i < 16; i++) {
            tnx_logf("v55 obj[%02d] at=%p gid=%d pos=(%d,%d) own=%d teamOld=%d teamNew=%d "
                     "dead=%d active=%d",
                     i, (void *)objects[i].object, objects[i].gid, objects[i].x, objects[i].y,
                     objects[i].ownerIndex, objects[i].teamOld, objects[i].teamNew,
                     objects[i].dead, objects[i].activeFlag & 1);
        }
    }

    g_v47_coord_usable = usable;
    g_v47_coord_distinct = distinct;

    g_v47_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;

    tnx_logf("v55 coords ok=%d (need >=2 objects, all in range, >=2 distinct positions, "
             "and a team field that splits them)",
             g_v47_coord_ok);
}

static int g_v50_setpred_blocked_logs = 0;

static int tnx_v50_mode_is_real(uintptr_t mode, uintptr_t expectedManager, uintptr_t *vtOut,
                                uintptr_t *chainOut) {
    void *vtable = NULL;
    void *chain = NULL;
    uintptr_t rva = 0;

    if (vtOut) *vtOut = 0;
    if (chainOut) *chainOut = 0;

    if (!mode) return 0;

    if (!tnx_read_ptr(mode, &vtable) || !vtable) return 0;

    rva = (uintptr_t)vtable - g_base;

    if (vtOut) *vtOut = rva;

    if (rva < TNX_DC_RVA_LO || rva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &chain)) return 0;
    if (chainOut) *chainOut = (uintptr_t)chain;

    if (expectedManager && (uintptr_t)chain != expectedManager) return 0;

    return 1;
}

static void tnx_autododge_v48(void) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    uintptr_t source = 0;
    const char *sourceKind = "none";
    int sourceIsMode = 0;
    int32_t predictX = 0;
    int32_t predictY = 0;
    int rejected = 0;
    int usable = 0;
    int ownIndex = -1;
    int32_t ownTeam = 0;
    int ownX = 0;
    int ownY = 0;
    int64_t ownBest = 0;
    float escapeX = 0.0f;
    float escapeY = 0.0f;
    int threats = 0;
    int threatsAlive = 0;

    if (!g_base) return;

    sourceIsMode = (g_mode_object != 0);

    if (sourceIsMode) {
        source = g_mode_object;
        sourceKind = "mode";
    } else if (g_manager_object) {
        source = g_manager_object;
        sourceKind = "manager";
    } else if (g_objvote_best_owner && g_objvote_best_teamcount >= TNX_OWNER_VOTE_TEAMS_MIN &&
               g_objvote_max_votes >= TNX_OWNER_VOTE_MIN) {
        source = g_objvote_best_owner;
        sourceKind = "objvote";
    } else if (g_trail_count > 0 && g_trail_best >= 0 && g_trail_best < g_trail_count) {
        source = (uintptr_t)g_trail[g_trail_best].manager;
        sourceKind = "trail";
    }

    if (!source) {
        g_v54_no_source_passes++;

        if (g_v54_no_source_passes >= 5 && !g_v54_route_logged) {
            g_v54_route_logged = 1;

            tnx_logf("v55 route: five passes with no source at all - mode=%p manager=%p "
                     "objvote=%p trailBest=%p; the remaining path is the ClientInput route, and its "
                     "hooks report separately (E5 setClientPredictionMoveTo, E6 sendMovement)",
                     (void *)g_mode_object, (void *)g_manager_object, (void *)g_objvote_best_owner,
                     (void *)((g_trail_best >= 0 && g_trail_best < g_trail_count)
                                  ? g_trail[g_trail_best].manager
                                  : 0));
        }
    } else {
        g_v54_no_source_passes = 0;
    }

    if (!sourceIsMode && !g_manager_object && source && strcmp(sourceKind, "trail") == 0 &&
        g_trail_best >= 0 && g_trail_best < g_trail_count && g_trail[g_trail_best].live == 0) {
        if ((g_v48_ticks % 900) == 1) {
            tnx_logf("v55 dodge idle ticks=%llu: best trail candidate has live=0, waiting "
                     "(trailBest=%p nonEmpty=%d count=%d stable=%d)",
                     (unsigned long long)g_v48_ticks, (void *)source,
                     g_trail[g_trail_best].nonEmpty, g_trail[g_trail_best].count,
                     g_trail[g_trail_best].stable);
        }
    }

    g_v48_ticks++;

    if (g_v48_entry_logs < 3) {
        g_v48_entry_logs++;
        tnx_logf("v55 dodge ENTERED ticks=%llu mode=%p manager=%p trailBest=%p source=%p kind=%s "
                 "setpredFn=%d writes=%llu",
                 (unsigned long long)g_v48_ticks, (void *)g_mode_object,
                 (void *)g_manager_object,
                 (g_trail_count > 0 && g_trail_best >= 0 && g_trail_best < g_trail_count)
                     ? (void *)g_trail[g_trail_best].manager : (void *)0,
                 (void *)source,
                 sourceKind, g_v47_setpred_state, (unsigned long long)g_v47_writes);
    }

    if (!source) {
        if ((g_v48_ticks % 900) == 1) {
            tnx_logf("v55 dodge idle ticks=%llu: no mode, no manager and no trail candidate yet "
                     "(bestLive=%d bestCount=%d) setpred=%d",
                     (unsigned long long)g_v48_ticks, g_manager_best_live,
                     g_manager_best_count, g_v47_setpred_state);
        }
        return;
    }

    if (g_v47_setpred_state < 0) {
        g_v47_setpred_state = tnx_v47_verify_setprediction();
        g_v47_setpred = g_v47_setpred_state ? (g_base + TNX_RVA_SETPREDICTION) : 0;
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        int changed = (g_v47_probe_object != source);

        if (!g_v47_probe_done || changed ||
            (!g_v47_coord_ok && probeNow > g_v47_probe_last_ms + TNX_V47_REPROBE_MS)) {
            void *resolved = NULL;

            g_v47_probe_object = source;
            g_v47_probe_last_ms = probeNow;

            if (sourceIsMode) {
                if (!tnx_read_ptr(source + TNX_MODE_MANAGER_OFF, &resolved) || !resolved) resolved = NULL;
            } else {
                resolved = (void *)source;
            }

            g_v48_manager = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || !g_v47_probe_done);

                tnx_v48_probe((uintptr_t)resolved, g_mode_object, loud);

                if (loud) tnx_v48_discriminate((uintptr_t)resolved);
            } else {
                tnx_logf("v55 probe skipped: source %p (%s) has no manager at +0x%llx",
                         (void *)source, sourceIsMode ? "mode" : "manager",
                         (unsigned long long)TNX_MODE_MANAGER_OFF);
            }
        }
    }

    g_v47_ticks++;

    if (!g_v47_setpred_state) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v55 dodge idle: no verified actuator (fingerprint state=%d -- this is the "
                     "byte check of the function, not a write)", g_v47_setpred_state);
        }
        return;
    }

    if (!g_v47_coord_ok) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v55 dodge idle: coordinates not confirmed (usable=%d distinct=%d) -- "
                     "read-only until they are", g_v47_coord_usable, g_v47_coord_distinct);
        }
        return;
    }

    if (!g_mode_object) {
        if (g_v47_giveup_logs < 9) {
            g_v47_giveup_logs++;
            tnx_logf("v55 dodge idle: coordinates confirmed but the mode is unknown, so the "
                     "actuator has no `this` -- nothing written");

            if (!g_v59_idle_probe_logged) {
                g_v59_idle_probe_logged = 1;

                tnx_logf("v65 dodge idle probe modeCandidate=%p vt=%#llx whyRejected=%s hits=%d "
                         "fromChain=%d", (void *)g_v59_last_cand,
                         (unsigned long long)g_v59_last_vt,
                         g_v59_last_why[0] ? g_v59_last_why : "none-seen", g_v59_chain_hits,
                         g_v59_mode_from_chain);
            }
        }
        return;
    }

    memset(objects, 0, sizeof(objects));

    usable = tnx_v48_collect(g_v48_manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    if (usable < 2) return;

    if (!tnx_read_i32(g_mode_object + TNX_MODE_PREDICTX_OFF, &predictX)) return;
    if (!tnx_read_i32(g_mode_object + TNX_MODE_PREDICTY_OFF, &predictY)) return;

    if (predictX <= -TNX_V47_COORD_ABS_MAX || predictX >= TNX_V47_COORD_ABS_MAX) return;
    if (predictY <= -TNX_V47_COORD_ABS_MAX || predictY >= TNX_V47_COORD_ABS_MAX) return;
    if (predictX == 0 && predictY == 0) return;

    for (int i = 0; i < usable; i++) {
        int64_t dx = (int64_t)objects[i].x - (int64_t)predictX;
        int64_t dy = (int64_t)objects[i].y - (int64_t)predictY;
        int64_t distance = dx * dx + dy * dy;

        if (ownIndex < 0 || distance < ownBest) {
            ownIndex = i;
            ownBest = distance;
        }
    }

    if (ownIndex < 0) return;

    if (ownBest > TNX_V47_OWN_MAX_SQ) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v55 dodge idle: prediction (%d,%d) is not near any object -- nearest "
                     "squared distance %lld -- so +0x30/+0x34 are not positions",
                     predictX, predictY, (long long)ownBest);
        }
        return;
    }

    if (objects[ownIndex].dead) return;

    ownTeam = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                        : objects[ownIndex].teamNew;
    ownX = objects[ownIndex].x;
    ownY = objects[ownIndex].y;

    for (int i = 0; i < usable; i++) {
        int32_t team = 0;
        float dx = 0.0f;
        float dy = 0.0f;
        float distance = 0.0f;
        float weight = 0.0f;

        if (i == ownIndex) continue;
        if (objects[i].dead) continue;

        team = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                         : objects[i].teamNew;
        if (team == ownTeam) continue;

        threatsAlive++;

        if ((objects[i].activeFlag & 1) == 0) continue;

        dx = (float)(ownX - objects[i].x);
        dy = (float)(ownY - objects[i].y);
        distance = dx * dx + dy * dy;

        if (distance > DODGE_RANGE_SQ || distance < 1.0f) continue;

        weight = 1.0f / (sqrtf(distance) + 1.0f);
        escapeX += dx * weight;
        escapeY += dy * weight;
        threats++;
    }

    if (threats == 0) {
        if (g_v47_ticks % 256 == 0) {
            tnx_logf("v55 live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
                     "enemiesActive=%d enemiesInRange=0 writes=%llu threatsTotal=%llu",
                     (unsigned long long)g_v47_ticks, ownX, ownY, ownTeam, predictX, predictY,
                     threatsAlive, threats, (unsigned long long)g_v47_writes,
                     (unsigned long long)g_v47_threat_ticks);
        }
        return;
    }

    g_v47_threat_ticks++;

    {
        float length = sqrtf(escapeX * escapeX + escapeY * escapeY);
        uint64_t now = 0;
        int targetX = 0;
        int targetY = 0;

        if (length <= 0.0001f) return;

        escapeX /= length;
        escapeY /= length;

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        if (now < g_v47_last_write_ms + (uint64_t)TNX_V47_DODGE_MIN_MS) return;

        g_v47_last_write_ms = now;

        targetX = ownX + (int)(escapeX * DODGE_STEP);
        targetY = ownY + (int)(escapeY * DODGE_STEP);

        if (targetX > TNX_V47_COORD_ABS_MAX) targetX = TNX_V47_COORD_ABS_MAX;
        if (targetX < -TNX_V47_COORD_ABS_MAX) targetX = -TNX_V47_COORD_ABS_MAX;
        if (targetY > TNX_V47_COORD_ABS_MAX) targetY = TNX_V47_COORD_ABS_MAX;
        if (targetY < -TNX_V47_COORD_ABS_MAX) targetY = -TNX_V47_COORD_ABS_MAX;

        {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;

            if (!tnx_v50_mode_is_real((uintptr_t)g_mode_object, g_v48_manager, &thisVt,
                                      &thisChain)) {
                if (g_v50_setpred_blocked_logs < 6) {
                    g_v50_setpred_blocked_logs++;

                    tnx_logf("v55 setprediction BLOCKED: this=%p vt=%#llx chain[this+0x%llx]=%p "
                             "!= manager=%p -- not the battle mode, nothing written",
                             (void *)g_mode_object, (unsigned long long)thisVt,
                             (unsigned long long)TNX_MODE_MANAGER_OFF, (void *)thisChain,
                             (void *)g_v48_manager);
                }

                return;
            }

            if (g_v47_writes == 0) {
                tnx_logf("v55 setprediction about to write: this=%p vt=%#llx chain=%p manager=%p "
                         "target=(%d,%d)", (void *)g_mode_object, (unsigned long long)thisVt,
                         (void *)thisChain, (void *)g_v48_manager, targetX, targetY);
            }
        }

        ((tnx_v47_setpred_t)g_v47_setpred)((void *)g_mode_object, targetX, targetY);

        g_v47_writes++;

        if (g_v47_writes <= TNX_V47_LOG_FIRST || (g_v47_writes % TNX_V47_LOG_EVERY) == 0) {
            tnx_logf("v55 write #%llu own=(%d,%d) team=%d hostilesAlive=%d enemiesInRange=%d "
                     "step=(%d,%d) target=(%d,%d) predBefore=(%d,%d)",
                     (unsigned long long)g_v47_writes, ownX, ownY, ownTeam,
                     threatsAlive, threats, (int)(escapeX * DODGE_STEP),
                     (int)(escapeY * DODGE_STEP), targetX, targetY, predictX, predictY);
        }
    }
}

static void tnx_dodge_plan(uintptr_t manager, int32_t team) {
    void *array = NULL;
    int32_t count = 0;
    int live = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;
        int32_t t = 0;
        uint8_t dead = 0;
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_gameobject_shape((uintptr_t)element)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (!tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead)) continue;

        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETY_SLOT, &s90);

        live++;

        tnx_logf("dodge team=%d i=%d obj=%p gid=%d team=%d dead=%d s88=%#llx s90=%#llx",
                 team, i, element, gid, t, dead,
                 (unsigned long long)s88, (unsigned long long)s90);
    }

    tnx_logf("dodge team=%d live=%d DISABLED - no coordinate source: slot 0x88 takes an "
             "argument at 0xae48f0, so it is not getX; the RVAs above identify the class",
             team, live);
}
static void tnx_dodge_all_teams(uintptr_t manager) {
    int32_t teams[TNX_OBJ_TEAM_MAX + 1];
    int teamCount = 0;
    void *array = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int i = 0; i <= TNX_OBJ_TEAM_MAX; i++) teams[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t t = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (t < 0 || t > TNX_OBJ_TEAM_MAX) continue;
        if (teams[t] >= 0) continue;

        teams[t] = t;
        teamCount++;
    }

    if (teamCount == 0) return;

    {
        int planned = 0;

        for (int t = 0; t <= TNX_OBJ_TEAM_MAX && planned < 2; t++) {
            if (teams[t] < 0) continue;

            tnx_dodge_plan(manager, t);
            planned++;
        }
    }
}

static BOOL tnx_v56_vtable_in_image(uintptr_t vtable) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;

    if (!vtable) return NO;
    if (vtable >= g_base + TNX_DC_RVA_LO && vtable < g_base + TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        return YES;
    }

    if (tnx_segment_range(TNX_VTABLE_SEGMENT_ALT, &lo, &hi) && vtable >= lo && vtable < hi) {
        return YES;
    }

    return NO;
}

static int tnx_v59_container_at(uintptr_t object, int32_t *countOut, int32_t *capOut, char *why,
                                size_t whyLen) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (why && whyLen) why[0] = 0;

    if (!object) {
        if (why) snprintf(why, whyLen, "object-null");

        return 0;
    }

    if (!tnx_read_ptr(object + TNX_MGR_ARRAY_OFF, &array) || !array) {
        if (why) snprintf(why, whyLen, "array-null-or-unreadable");

        return 0;
    }

    if (!tnx_read_i32(object + TNX_MGR_COUNT_OFF, &count)) {
        if (why) snprintf(why, whyLen, "count-unreadable");

        return 0;
    }

    if (count <= 0 || count > TNX_MANAGER_MAX_OBJECTS) {
        if (why) snprintf(why, whyLen, "count=%d-out-of-range", count);

        return 0;
    }

    if (!tnx_read_i32(object + TNX_MGR_CAP_OFF, &capacity)) {
        if (why) snprintf(why, whyLen, "cap-unreadable");

        return 0;
    }

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) {
        if (why) snprintf(why, whyLen, "cap=%d-against-count=%d", capacity, count);

        return 0;
    }

    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return 1;
}

static int tnx_v60_container_resolve(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                     int32_t *capOut, char *why, size_t whyLen) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    uintptr_t arrayBase = 0;

    if (containerOut) *containerOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (why && whyLen) why[0] = 0;

    if (!manager) {
        if (why) snprintf(why, whyLen, "manager-null");

        return 0;
    }

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) {
        if (why) snprintf(why, whyLen, "array-null-src=A+B");

        return 0;
    }

    arrayBase = (uintptr_t)array;

    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) {
        if (why) snprintf(why, whyLen, "count-unreadable-src=B");

        return 0;
    }

    if (count > TNX_MANAGER_MAX_OBJECTS) {
        if (why) {
            snprintf(why, whyLen, "count=%d-above-%d-src=B", count, TNX_MANAGER_MAX_OBJECTS);
        }

        return 0;
    }

    if (count < 2) {
        if (arrayBase >= g_base && arrayBase < g_base + TNX_V60_IMAGE_SPAN) {
            g_v63_image_count++;

            if (!g_v63_image_first) {
                g_v63_image_first = 1;

                tnx_logf("v65 container image-resident count=%d reject-as-static-array mgr=%p "
                         "array=%p src=B", count, (void *)manager, (void *)arrayBase);
            }

            g_v63_image_top_mgr = (uintptr_t)manager;
            g_v63_image_top_count = count;
        }

        if (why) snprintf(why, whyLen, "count=%d-static-array-src=B", count);

        return 0;
    }

    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) {
        if (why) snprintf(why, whyLen, "cap-unreadable-src=B");

        return 0;
    }

    if (capacity < count) {
        if (why) snprintf(why, whyLen, "cap=%d-against-count=%d-src=B", capacity, count);

        return 0;
    }

    if (containerOut) *containerOut = manager;
    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return 1;
}

static void tnx_v59_chain_capture(uintptr_t modeObject, uintptr_t vtable, uintptr_t manager) {
    void *vtRead = NULL;
    uintptr_t container = 0;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!modeObject) return;
    if (g_mode_object || g_mode_strong) return;

    g_v59_chain_hits++;

    if (!tnx_read_ptr(modeObject, &vtRead) || (uintptr_t)vtRead != vtable) {
        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "vtable-changed");

        g_v63_chain_vtchanged++;

        return;
    }

    if (!tnx_v57_class_slot_ok(vtable)) {
        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "not-a-class-table");

        tnx_logf("v65 chain reject mode=%p vt=%#llx whyRejected=not-a-class-table",
                 (void *)modeObject, (unsigned long long)vtable);

        return;
    }

    if (!tnx_v60_container_resolve(manager, &container, &count, &capacity, g_v59_last_why,
                                   sizeof(g_v59_last_why))) {
        if (g_v59_chain_hits <= 8) {
            tnx_logf("v65 chain reject mode=%p vt=%#llx manager=%p whyRejected=%s src=A",
                     (void *)modeObject, (unsigned long long)vtable, (void *)manager,
                     g_v59_last_why[0] ? g_v59_last_why : "unknown");
        }

        return;
    }

    if (g_v59_chain_vt == vtable && g_v59_chain_mgr == manager) {
        g_v59_chain_stable++;

        if (g_v59_chain_stable == TNX_V61_CHAIN_STABLE_TICKS && !g_v63_chain_stable_logged) {
            g_v63_chain_stable_logged = 1;

            tnx_logf("v65 chain stable vt=%#llx mgr=%p sighting=%d/%d", (unsigned long long)vtable,
                     (void *)manager, g_v59_chain_stable, TNX_V61_CHAIN_STABLE_TICKS);
        }
    } else {
        g_v59_chain_mode = modeObject;
        g_v59_chain_vt = vtable;
        g_v59_chain_mgr = manager;
        g_v59_chain_stable = 1;
    }

    if (g_v59_chain_stable < TNX_V61_CHAIN_STABLE_TICKS) return;

    if (count < 2) {
        if (g_v61_weak_logs < 6) {
            g_v61_weak_logs++;

            tnx_logf("v65 chain would-capture-but-weak vt=%#llx mgr=%p count=%d -> diag only",
                     (unsigned long long)vtable, (void *)manager, count);
        }

        g_v59_chain_stable = 0;

        return;
    }

    tnx_logf("v65 chain would-capture vt=%#llx mgr=%p array=%p count=%d cap=%d - diagnostics only, "
             "the mode comes from D6", (unsigned long long)vtable, (void *)manager,
             (void *)container, count, capacity);

    g_v59_chain_stable = 0;
}

static const char *tnx_v57_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (!manager) return "no-manager";
    if (manager & 7ULL) return "manager-unaligned";
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return "array-unreadable";
    if (!array) return "array-null";
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return "count-unreadable";
    if (count <= 0) return "count-zero";
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return "cap-unreadable";
    if (count > capacity) return "count-above-cap";
    if (capacity > TNX_MGR_CAP_MAX) return "cap-above-ceiling";
    if (count > TNX_MANAGER_MAX_OBJECTS) return "count-above-ceiling";

    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return NULL;
}

static int tnx_v57_is_fn_start(uintptr_t address) {
    uint32_t previous = 0;

    if (!address || (address & 3ULL)) return 0;
    if (!tnx_read_bytes(address - 4ULL, &previous, sizeof(previous))) return 0;
    if (previous == 0xd65f03c0U) return 1;
    if ((previous & 0xfc000000U) == 0x14000000U) return 1;

    return 0;
}

static uintptr_t tnx_v60_strip_ptr(uintptr_t value) {
    uintptr_t stripped = value;

#if __has_feature(ptrauth_calls)
    stripped = (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_function_pointer);
#endif

    if (stripped >= g_base && stripped < g_base + TNX_V60_IMAGE_SPAN) return stripped;

    if ((stripped & 0xffffffffULL) < TNX_V60_IMAGE_SPAN) {
        uintptr_t viaLow = g_base + (stripped & 0xffffffffULL);

        if (viaLow >= g_base && viaLow < g_base + TNX_V60_IMAGE_SPAN) return viaLow;
    }

    return stripped;
}

static int tnx_v57_class_slot_ok(uintptr_t vtable) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;
    void *raw = NULL;
    uintptr_t raw0 = 0;
    uintptr_t raw8 = 0;
    uintptr_t rva = 0;
    int inText = 0;

    if (!vtable || (vtable & 7ULL)) return 0;
    if (!tnx_v56_vtable_in_image(vtable)) return 0;
    if (!tnx_segment_range("__TEXT", &lo, &hi)) return 0;

    rva = vtable - g_base;

    for (int i = 0; i < 8; i++) {
        uintptr_t stripped = 0;

        if (!tnx_read_ptr(vtable + (uintptr_t)i * 8ULL, &raw) || !raw) continue;

        stripped = tnx_v60_strip_ptr((uintptr_t)raw);

        if (i == 0) raw0 = (uintptr_t)raw;
        if (i == 1) raw8 = (uintptr_t)raw;

        if (stripped >= lo && stripped < hi) inText++;
    }

    if (inText >= 2) {
        g_v62_class_pass++;

        if (g_v61_class_logs < 4) {
            g_v61_class_logs++;

            tnx_logf("v65 class-slot vt=%p rva=%#llx inText=%d/8 raw0=%#llx raw8=%#llx -> pass "
                     "src=A", (void *)vtable, (unsigned long long)rva, inText,
                     (unsigned long long)raw0, (unsigned long long)raw8);
        }

        return 1;
    }

    if (g_v61_class_rejects < 3) {
        g_v61_class_rejects++;

        tnx_logf("v65 class-slot vt=%p rva=%#llx inText=%d/8 raw0=%#llx raw8=%#llx -> reject "
                 "reason=slots-in-text=%d/8 src=A", (void *)vtable, (unsigned long long)rva, inText,
                 (unsigned long long)raw0, (unsigned long long)raw8, inText);
    }

    return 0;
}

static int tnx_v57_owner_rejected(uintptr_t owner) {
    for (int i = 0; i < g_v57_rejected_count; i++) {
        if (g_v57_rejected[i] == owner) return 1;
    }

    return 0;
}

static void tnx_v57_owner_reject(uintptr_t owner) {
    if (!owner) return;
    if (tnx_v57_owner_rejected(owner)) return;
    if (g_v57_rejected_count >= TNX_V57_REJECT_MAX) return;

    g_v57_rejected[g_v57_rejected_count++] = owner;
}

static uintptr_t tnx_v57_coord_x_off(void) {
    return g_v57_coord_off >= 0 ? (uintptr_t)g_v57_coord_off : TNX_OBJ_X_OFF;
}

static uintptr_t tnx_v57_coord_y_off(void) {
    return g_v57_coord_off >= 0 ? (uintptr_t)g_v57_coord_off + 4ULL : TNX_OBJ_Y_OFF;
}

static void tnx_v57_mode_drop(void) {
    tnx_logf("v65 mode dropped this=%p - %d ticks without a class table and a manager, so it is "
             "not the battle mode", (void *)g_mode_object, g_v57_stale_ticks);

    g_mode_object = 0;
    g_v56_capture_done = 0;
    g_v56_array_logged = 0;
    g_v56_walk_last = -1;
    g_v57_cand_this = 0;
    g_v57_cand_vt = 0;
    g_v57_cand_ticks = 0;
    g_v57_stale_ticks = 0;
}

static int tnx_v57_mode_reverify(void) {
    void *vtable = NULL;
    void *managerPtr = NULL;

    if (!g_mode_object) return 0;

    if ((tnx_read_ptr(g_mode_object, &vtable) && vtable &&
         tnx_v57_class_slot_ok((uintptr_t)vtable)) &&
        (tnx_read_ptr(g_mode_object + TNX_MODE_MANAGER_OFF, &managerPtr) && managerPtr &&
         tnx_v57_header_reason((uintptr_t)managerPtr, NULL, NULL) == NULL)) {
        g_v57_stale_ticks = 0;

        return 1;
    }

    g_v57_stale_ticks++;

    if (g_v57_stale_ticks >= TNX_V57_STALE_MAX) tnx_v57_mode_drop();

    return 0;
}

static void tnx_v56_mode_capture(uintptr_t candidate) {
    void *vtable = NULL;
    void *managerPtr = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!candidate) return;
    if (g_mode_object) return;
    if (!tnx_read_ptr(candidate, &vtable) || !vtable) {
        g_v59_last_cand = candidate;
        g_v59_last_vt = 0;
        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "vtable-unreadable");

        return;
    }

    g_v59_last_cand = candidate;
    g_v59_last_vt = (uintptr_t)vtable;

    if (!tnx_v57_class_slot_ok((uintptr_t)vtable)) {
        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "not-a-class-table");

        if (g_v57_capture_rejects < 4) {
            g_v57_capture_rejects++;

            tnx_logf("v65 mode reject this=%p vt=%#llx - not a class table in __DATA_CONST or "
                     "__DATA with two code entries", (void *)candidate,
                     (unsigned long long)(uintptr_t)vtable);
        }

        return;
    }

    if (!tnx_read_ptr(candidate + TNX_MODE_MANAGER_OFF, &managerPtr) || !managerPtr) {
        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "no-manager-at-0x28");

        return;
    }

    {
        const char *headerWhy = tnx_v57_header_reason((uintptr_t)managerPtr, &count, &capacity);

        if (headerWhy) {
            snprintf(g_v59_last_why, sizeof(g_v59_last_why), "manager-%s", headerWhy);

            return;
        }
    }

    if (g_v57_cand_this == candidate && g_v57_cand_vt == (uintptr_t)vtable) {
        g_v57_cand_ticks++;
    } else {
        g_v57_cand_this = candidate;
        g_v57_cand_vt = (uintptr_t)vtable;
        g_v57_cand_ticks = 1;

        tnx_logf("v65 mode candidate this=%p vt=%#llx manager=%p count=%d cap=%d - it needs %d "
                 "matching ticks before it becomes the mode", (void *)candidate,
                 (unsigned long long)(uintptr_t)vtable, managerPtr, count, capacity,
                 TNX_V57_MODE_REVERIFY_TICKS);

        return;
    }

    if (g_v57_cand_ticks < TNX_V57_MODE_REVERIFY_TICKS) return;

    g_mode_object = candidate;
    g_v56_capture_done = 1;
    g_v56_mode_ticks = 0;
    g_v56_array_logged = 0;
    g_v56_walk_last = -1;
    g_v56_route_done = 0;
    g_v57_stale_ticks = 0;

    tnx_battle_begin("setpred");

    tnx_logf("v65 mode captured this=%p vt=%#llx manager=%p count=%d cap=%d ticks=%d",
             (void *)candidate, (unsigned long long)(uintptr_t)vtable, managerPtr, count,
             capacity, g_v57_cand_ticks);
}

static void tnx_v59_tag(char tags[][8], int *count, const char *tag) {
    if (!tag) return;
    if (*count >= TNX_V59_TAG_MAX) return;

    snprintf(tags[*count], 8, "%s", tag);
    (*count)++;
}

static void tnx_v59_join(char tags[][8], int count, char *out, size_t outSize) {
    size_t used = 0;

    out[0] = 0;

    for (int i = 0; i < count; i++) {
        if (used + strlen(tags[i]) + 2 >= outSize) break;

        if (used) {
            out[used++] = ',';
            out[used] = 0;
        }

        strncat(out, tags[i], outSize - used - 1);
        used = strlen(out);
    }
}

static void tnx_v59_hook_summary(void) {
    static int printed = -1;
    char drops[192];
    char keeps[192];

    if (g_v59_drop_count + g_v59_keep_count == printed) return;

    printed = g_v59_drop_count + g_v59_keep_count;

    tnx_v59_join(g_v59_drop_tags, g_v59_drop_count, drops, sizeof(drops));
    tnx_v59_join(g_v59_keep_tags, g_v59_keep_count, keeps, sizeof(keeps));

    tnx_logf("v65 hooks dropped: %s reason=zero-entries-in-30-ticks", drops[0] ? drops : "none");
    tnx_logf("v65 hooks kept: %s reason=real-pointer-slot-or-wide", keeps[0] ? keeps : "none");
}

static void tnx_v59_hook_note(int index) {
    if (index < 0 || index >= TNX_SLOT_COUNT) return;
    if (g_slot_specs[index].control) {
        tnx_v59_tag(g_v59_drop_tags, &g_v59_drop_count, g_slot_specs[index].shortTag);
        tnx_v57_drop_hook(index);

        return;
    }

    if (g_slot_specs[index].slotRva) {
        tnx_v59_tag(g_v59_keep_tags, &g_v59_keep_count, g_slot_specs[index].shortTag);

        return;
    }

    if (g_slot_slots[index] > TNX_V59_SLOT_WIDE) {
        if (g_v50_ticks <= TNX_V59_DROP_TICKS) {
            tnx_v59_tag(g_v59_keep_tags, &g_v59_keep_count, g_slot_specs[index].shortTag);

            return;
        }

        tnx_v59_tag(g_v59_drop_tags, &g_v59_drop_count, g_slot_specs[index].shortTag);
        tnx_v57_drop_hook(index);

        tnx_logf("v65 hook %s dropped reason=60-ticks-zero-hits", g_slot_specs[index].shortTag);

        return;
    }

    tnx_v59_tag(g_v59_drop_tags, &g_v59_drop_count, g_slot_specs[index].shortTag);
    tnx_v57_drop_hook(index);
}

static void tnx_v57_drop_hook(int index) {
    uintptr_t target = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;
    if (g_slot_installed[index] != 1) return;

    target = g_base + g_slot_specs[index].rva;

    if (!target) return;
    if (!brk_remove((void *)target)) {
        tnx_logf("v65 hook %s drop failed target=%p %s", g_slot_specs[index].shortTag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    g_slot_installed[index] = 0;
}

static void tnx_v57_hook_triage(int index) {
    if (index < 0 || index >= TNX_SLOT_COUNT) return;
    if (g_slot_installed[index] != 1) return;

    if (g_slot_specs[index].control) {
        tnx_v57_drop_hook(index);

        return;
    }

    if (g_slot_specs[index].slotRva) {
        tnx_logf("v65 hook %s kept: slotRva=%#llx is a real pointer slot (%d slot(s)) and the "
                 "function is simply not reached in this scenario - no re-slot needed",
                 g_slot_specs[index].shortTag, (unsigned long long)g_slot_specs[index].slotRva,
                 g_slot_slots[index]);

        return;
    }

    tnx_v57_drop_hook(index);
}

static int tnx_v56_refresh_array(void) {
    void *manager = NULL;
    void *array = NULL;
    int32_t count = 0;

    if (!g_mode_object) return 0;
    if (!tnx_read_ptr(g_mode_object + TNX_MODE_MANAGER_OFF, &manager) || !manager) return 0;

    if ((uintptr_t)manager != g_v56_manager) {
        g_v56_manager = (uintptr_t)manager;
        g_v56_array = 0;
        g_v56_count = 0;
    }

    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;

    if (count <= 0 || count > TNX_V56_COUNT_MAX) {
        int32_t alt = 0;

        if (tnx_read_i32((uintptr_t)manager + 0x8ULL, &alt) && alt > 0 &&
            alt <= TNX_V56_COUNT_MAX) {
            count = alt;
        } else if (tnx_read_i32((uintptr_t)manager + 0x10ULL, &alt) && alt > 0 &&
                   alt <= TNX_V56_COUNT_MAX) {
            count = alt;
        } else {
            return 0;
        }
    }

    g_v56_array = (uintptr_t)array;
    g_v56_count = count;

    if (!g_v56_array_logged) {
        g_v56_array_logged = 1;

        tnx_logf("v56 array ready mode=%p manager=%p array=%p count=%d", (void *)g_mode_object,
                 manager, array, count);
    }

    return 1;
}

static int tnx_v56_man_walk(void) {
    int32_t enemies = 0;

    g_v56_enemy_count = 0;

    if (!g_v56_array || g_v56_count <= 0) return 0;

    if (!g_v57_getown) {
        uintptr_t candidate = g_base + TNX_V57_GETOWN_RVA;

        if (tnx_v57_is_fn_start(candidate)) {
            g_v57_getown = candidate;

            tnx_logf("v65 getown resolved at %#llx, function start confirmed",
                     (unsigned long long)g_v57_getown);
        }
    }

    if (!g_v57_getown) {
        if (!g_v57_getown_logged) {
            g_v57_getown_logged = 1;

            tnx_logf("v65 man walk blocked: getOwnCharacter candidate %#llx is not a function "
                     "start - resolve the real entry from xrefs before calling it",
                     (unsigned long long)(g_base + TNX_V57_GETOWN_RVA));
        }

        return 0;
    }

    g_v56_player = (uintptr_t)((void *(*)(void *))g_v57_getown)((void *)g_mode_object);
    if (!g_v56_player) return 0;
    if (!tnx_read_i32(g_v56_player + tnx_v57_coord_x_off(), &g_v56_px)) return 0;
    if (!tnx_read_i32(g_v56_player + tnx_v57_coord_y_off(), &g_v56_py)) return 0;
    if (!tnx_read_i32(g_v56_player + TNX_OBJ_TEAM_OFF, &g_v56_team)) return 0;

    for (int32_t i = 0; i < g_v56_count && i < TNX_V56_COUNT_MAX; i++) {
        uintptr_t slot = g_v56_array + (uintptr_t)i * sizeof(void *);
        void *obj = NULL;
        int32_t x = 0;
        int32_t y = 0;
        int32_t team = 0;
        uint8_t dead = 0;

        if (!tnx_read_ptr(slot, &obj) || !obj) continue;
        if ((uintptr_t)obj == g_v56_player) continue;
        if (!tnx_read_i32((uintptr_t)obj + tnx_v57_coord_x_off(), &x)) continue;
        if (!tnx_read_i32((uintptr_t)obj + tnx_v57_coord_y_off(), &y)) continue;
        if (x == 0 && y == 0) continue;
        if (!tnx_read_i32((uintptr_t)obj + TNX_OBJ_TEAM_OFF, &team)) continue;
        if (team == g_v56_team) continue;
        if (!tnx_read_bytes((uintptr_t)obj + TNX_OBJ_DEADFLAG_OFF, &dead, sizeof(dead))) continue;
        if (dead) continue;

        g_v56_enemy_x[g_v56_enemy_count] = x;
        g_v56_enemy_y[g_v56_enemy_count] = y;
        g_v56_enemy_count++;
        enemies++;
    }

    if (enemies != g_v56_walk_last) {
        g_v56_walk_last = enemies;

        tnx_logf("v56 walk player=(%d,%d) team=%d enemies=%d", g_v56_px, g_v56_py, g_v56_team,
                 enemies);
    }

    return enemies;
}

static int tnx_v56_objhit_walk(void) {
    int n = 0;

    for (int i = 0; i < g_objhit_count; i++) {
        int32_t x = 0;
        int32_t y = 0;

        if (!g_objhits[i].at) continue;
        if (!tnx_read_i32(g_objhits[i].at + tnx_v57_coord_x_off(), &x)) continue;
        if (!tnx_read_i32(g_objhits[i].at + tnx_v57_coord_y_off(), &y)) continue;
        if (x == 0 && y == 0) continue;

        n++;
    }

    return n;
}

static void tnx_v56_route_clientinput(void) {
    uintptr_t thisPtr = g_slot_object[12];
    uint64_t result = 0;

    if (g_v56_route_done) return;
    if (!g_addr_setprediction) return;

    for (int i = 0; !thisPtr && i < TNX_SLOT_COUNT; i++) {
        thisPtr = g_slot_object[i];
    }

    if (!thisPtr) return;

    g_v56_route_done = 1;

    result = ((uint64_t (*)(void *, int, int))g_addr_setprediction)((void *)thisPtr, 0, 0);

    tnx_logf("v56 route clientinput returned=%llu", (unsigned long long)result);
}

static void tnx_v56_dodge_tick(void) {
    static uintptr_t setpredFn = 0;
    int best = -1;
    int64_t bestDist = 0;

    if (!g_base) return;

    if (g_mode_object && !tnx_v57_mode_reverify()) return;

    if (!g_mode_object) {
        g_v56_mode_ticks++;

        if (g_v56_mode_ticks == TNX_V56_MODE_WAIT_TICKS && !g_v56_objhit_logged) {
            g_v56_objhit_logged = 1;

            tnx_logf("v56 dodge from objhit list n=%d", tnx_v56_objhit_walk());
        }

        if (g_v56_mode_ticks == TNX_V56_ROUTE_WAIT_TICKS) tnx_v56_route_clientinput();

        return;
    }

    g_v56_mode_ticks = 0;

    if (!tnx_v56_refresh_array()) {
        if (!g_v56_objhit_logged) {
            g_v56_objhit_logged = 1;

            tnx_logf("v56 dodge from objhit list n=%d", tnx_v56_objhit_walk());
        }

        return;
    }

    if (tnx_v56_man_walk() <= 0) return;

    for (int32_t i = 0; i < g_v56_enemy_count; i++) {
        int64_t dx = (int64_t)g_v56_enemy_x[i] - (int64_t)g_v56_px;
        int64_t dy = (int64_t)g_v56_enemy_y[i] - (int64_t)g_v56_py;
        int64_t dist = dx * dx + dy * dy;

        if (best < 0 || dist < bestDist) {
            best = i;
            bestDist = dist;
        }
    }

    if (best < 0) return;

    {
        float dx = (float)(g_v56_enemy_x[best] - g_v56_px);
        float dy = (float)(g_v56_enemy_y[best] - g_v56_py);
        float len = sqrtf(dx * dx + dy * dy);
        float perpX = 0.0f;
        float perpY = 0.0f;
        int newX = 0;
        int newY = 0;

        if (len <= 0.0001f) return;

        perpX = -dy / len;
        perpY = dx / len;
        newX = g_v56_px + (int)(perpX * (float)TNX_V56_WALK_STEP);
        newY = g_v56_py + (int)(perpY * (float)TNX_V56_WALK_STEP);

        if (!setpredFn) setpredFn = g_base + TNX_RVA_SETPREDICTION;

        ((tnx_v47_setpred_t)setpredFn)((void *)g_mode_object, newX, newY);

        tnx_logf("v56 dodge write=(%d,%d) from=(%d,%d) near=(%d,%d) enemies=%d", newX, newY,
                 g_v56_px, g_v56_py, g_v56_enemy_x[best], g_v56_enemy_y[best],
                 g_v56_enemy_count);
    }
}

static void tnx_slot_pump(void) {
    int first = -1;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        uint32_t bit = (uint32_t)(1u << i);

        if (!g_slot_object[i]) continue;

        if (!g_slot_specs[i].control && first < 0) first = i;

        if (g_slot_reported_mask & bit) continue;

        g_slot_reported_mask |= bit;

        tnx_logf("slot %s: captured this=%p arg1=%p hits=%llu%s", g_slot_specs[i].tag,
                 (void *)g_slot_object[i], (void *)g_slot_arg1[i],
                 (unsigned long long)g_slot_hits[i],
                 g_slot_specs[i].control ? " CONTROL" : "");
    }

    if (first < 0) return;

    uintptr_t object = g_slot_object[first];

    if (g_slot_adopted == object) return;

    g_slot_adopted = object;

    int installed = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_installed[i] == 1) installed++;
    }

    tnx_logf("slot pump object=%p source=%s installed=%d/%d",
             (void *)object, g_slot_specs[first].tag, installed, TNX_SLOT_COUNT);

    {
        void *vtable = NULL;
        void *manager = NULL;
        const char *reason = "vtable-not-in-image";

        if (tnx_read_ptr(object, &vtable) && vtable &&
            tnx_v56_vtable_in_image((uintptr_t)vtable)) {
            reason = (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &manager) && manager)
                         ? "adopt-from-slot-banned"
                         : "no-manager-at-0x28";
        } else if (!tnx_pointer_plausible((uintptr_t)vtable)) {
            reason = "vtable-garbage";
        }

        tnx_logf("v65 slot %s reject reason=%s this=%p vt=%p", g_slot_specs[first].shortTag, reason,
                 (void *)object, vtable);

        if (strcmp(reason, "vtable-garbage") == 0) return;
    }

    tnx_dump_hex("slotObj", object, 0x100);

    void *bridge = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_BRIDGE_OFF, &bridge) && bridge) {
        void *bridgeManager = NULL;

        tnx_logf("slot +08 bridge=%p vt=%#llx", bridge,
                 (unsigned long long)tnx_vtable_rva(bridge));

        if (tnx_read_ptr((uintptr_t)bridge + TNX_MGR_ARRAY_OFF, &bridgeManager) && bridgeManager) {
            tnx_logf("slot bridgeMgr=%p vt=%#llx", bridgeManager,
                     (unsigned long long)tnx_vtable_rva(bridgeManager));

            tnx_dump_hex("slotMgrA", (uintptr_t)bridgeManager, 0x40);
        }
    }

    void *list = NULL;
    int32_t listCount = 0;

    if (tnx_read_ptr(object + TNX_SLOT_LIST_OFF, &list) &&
        tnx_read_i32(object + TNX_SLOT_LISTCOUNT_OFF, &listCount)) {
        tnx_logf("slot +80 list=%p count=%d", list, listCount);
    }

    void *modeManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &modeManager) && modeManager) {
        void *modeArray = NULL;
        int32_t modeCount = 0;

        tnx_logf("slot +28 mgr=%p vt=%#llx", modeManager,
                 (unsigned long long)tnx_vtable_rva(modeManager));

        if (tnx_read_ptr((uintptr_t)modeManager + TNX_MGR_ARRAY_OFF, &modeArray) &&
            tnx_read_i32((uintptr_t)modeManager + TNX_MGR_COUNT_OFF, &modeCount)) {
            tnx_logf("slot +28 arr=%p count=%d live=%d", modeArray, modeCount,
                     tnx_manager_live_count((uintptr_t)modeManager));
        }

        tnx_dump_hex("slotMgr28", (uintptr_t)modeManager, 0x40);
    }

    void *inputManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_INPUTMGR_OFF, &inputManager) && inputManager) {
        tnx_logf("slot +58 inputMgr=%p vt=%#llx", inputManager,
                 (unsigned long long)tnx_vtable_rva(inputManager));

        tnx_dump_hex("slotInMgr", (uintptr_t)inputManager, 0x40);
    }

    if (g_slot_arg1[first]) {
        tnx_report_manager("slot arg1", g_slot_arg1[first]);
    }

    void *ownerField = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_OWNER_OFF, &ownerField) && ownerField &&
        (uintptr_t)ownerField != g_slot_arg1[first]) {
        tnx_report_manager("slot +20", (uintptr_t)ownerField);
    }

    {
        uintptr_t plan = g_slot_arg1[first] ? g_slot_arg1[first] : (uintptr_t)ownerField;

        if (plan && tnx_manager_live_count(plan) >= TNX_MANAGER_MIN_OBJECTS) {
            int detailed = tnx_object_detail(plan, TNX_OBJECT_DETAIL_MAX);

            tnx_raw_object_hex(plan, 2);

            if (detailed > 0) tnx_dodge_all_teams(plan);
        }
    }

    void *slotTable = NULL;

    if (tnx_read_ptr(object, &slotTable) && slotTable) {
        tnx_logf("slot vtable=%p", slotTable);

        for (int k = 0; k < 40; k += 4) {
            void *entry[4] = { NULL, NULL, NULL, NULL };

            for (int j = 0; j < 4; j++) {
                tnx_read_ptr((uintptr_t)slotTable + (uintptr_t)(k + j) * sizeof(void *), &entry[j]);
            }

            tnx_logf("slot vt[%02d..%02d] %#llx %#llx %#llx %#llx", k, k + 3,
                     (unsigned long long)(uintptr_t)entry[0],
                     (unsigned long long)(uintptr_t)entry[1],
                     (unsigned long long)(uintptr_t)entry[2],
                     (unsigned long long)(uintptr_t)entry[3]);
        }
    }

    tnx_dump_mode_objects("slot");
}

static void tnx_dump_objc_inventory(const char *tag) {
    int total = objc_getClassList(NULL, 0);

    if (total <= 0) {
        tnx_logf("objc[%s] no classes", tag ? tag : "?");
        return;
    }

    if (total > 200000) total = 200000;

    Class *classes = (Class *)malloc(sizeof(Class) * (size_t)total);

    if (!classes) return;

    static const char *noise[] = {
        "Sentry", "Firebase", "AppsFlyer", "GUL", "Zendesk", "sczendesk", "Helpshift",
        "SKAdNetwork", "GAD", "FIR", "nanopb", "GTM", "GSDK", "UI", "NS", "WK", "CA",
        "CL", "CN", "AV", "MTL", "LS", "__", NULL
    };

    static const char *gameplay[] = {
        "Joy", "Stick", "Input", "Touch", "Aim", "Target", "Fire", "Shoot", "Move",
        "Character", "Object", "Manager", "Battle", "Logic", "Player", "Unit",
        "Hud", "HUD", "Screen", "View", "Render", "Stage", "Sprite", "Scene",
        "Mode", "Game", "State", "Resource", "Text", "Label", "Button", "Node", NULL
    };

    int count = objc_getClassList(classes, total);
    int inImage = 0;
    int named = 0;
    int detailed = 0;

    tnx_logf("objc[%s] classes=%d", tag ? tag : "?", count);

    for (int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);

        if (!name) continue;
        if (!tnx_image_owns_address(g_base, (uintptr_t)classes[i])) continue;

        inImage++;

        BOOL skip = NO;

        for (int n = 0; noise[n]; n++) {
            if (strncmp(name, noise[n], strlen(noise[n])) == 0) {
                skip = YES;
                break;
            }
        }

        if (skip) continue;

        if (named < 800) {
            tnx_logf("objc[%s] cls %s", tag ? tag : "?", name);
            named++;
        }

        BOOL interesting = NO;

        for (int g = 0; gameplay[g]; g++) {
            if (strstr(name, gameplay[g])) {
                interesting = YES;
                break;
            }
        }

        if (!interesting || detailed >= 80) continue;

        detailed++;

        unsigned mcount = 0;
        Method *methods = class_copyMethodList(classes[i], &mcount);

        tnx_logf("objc[%s] == %s methods=%u", tag ? tag : "?", name, mcount);

        if (methods) {
            for (unsigned m = 0; m < mcount && m < 24; m++) {
                const char *sel = sel_getName(method_getName(methods[m]));
                const char *types = method_getTypeEncoding(methods[m]);

                tnx_logf("objc[%s]    -[%s %s] %s",
                         tag ? tag : "?", name, sel ? sel : "?", types ? types : "?");
            }

            if (mcount > 24) tnx_logf("objc[%s]    ... %u more", tag ? tag : "?", mcount - 24);

            free(methods);
        }
    }

    tnx_logf("objc[%s] total=%d inImage=%d named=%d detailed=%d",
             tag ? tag : "?", count, inImage, named, detailed);

    free(classes);
}

static void setup(void) {
    if (g_setup_done) return;
    g_setup_done = YES;

    tlog([NSString stringWithFormat:@"setup base=%p", (void *)g_base]);

    image_ref_t ref;
    ref.base = g_base;
    ref.hdr = (const struct mach_header_64 *)g_base;

    rt_dump_image(ref);

    tnx_load_function_starts();

    tnx_resolve_addresses();
    tnx_dump_structs();
    tnx_dump_verified();
    tnx_dump_rvas();
    tnx_probe_classes();
    tnx_dump_protocols();

    tnx_objc_arm("MetalView", "render");
    tnx_objc_arm("NullView", "render");

    tnx_slot_hooks_install();

    int buildControls = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) buildControls++;
    }

    tnx_slot_table_dump();
    tnx_struct_map_dump();

    tnx_logf("build=%s slots=%d control=%d types>=%d scanEvery=%d heapEvery=%d attempts=%d "
             "arrayProbeLimit=%d chainProbeLimit=%d voteMin=%d voteConfirm=%d voteTeamsMin=%d "
             "ownerVoteMax=%d gidMax=%d objhitDump=%d censusMax=%d censusPrint=%d censusSlots=%d "
             "budgetMin=%lluMB budgetMax=%lluMB",
             TNX_BUILD_TAG, TNX_SLOT_COUNT - buildControls, buildControls, TNX_MODE_MIN_TYPES,
             TNX_VOTESCAN_GLOBAL_EVERY, TNX_VOTESCAN_HEAP_EVERY, TNX_VOTESCAN_ATTEMPTS,
             TNX_MANAGER_PROBE_LIMIT, TNX_CHAIN_PROBE_LIMIT, TNX_OWNER_VOTE_MIN,
             TNX_OWNER_VOTE_CONFIRM, TNX_OWNER_VOTE_TEAMS_MIN, TNX_OWNER_VOTE_MAX,
             TNX_OWNER_VOTE_GID_MAX, TNX_OBJ_HIT_PRINT_MAX, TNX_VTCENSUS_MAX, TNX_VTCENSUS_PRINT,
             TNX_VTCENSUS_SLOTS, TNX_HEAP_SCAN_BUDGET / (1024ull * 1024ull),
             TNX_HEAP_SCAN_BUDGET_MAX / (1024ull * 1024ull));

    tnx_logf("plan v49: (1) the left-hand panel is REMOVED -- the overlay draws nothing now -- "
             "and replaced by a UIAlertController shown once per battle; (2) the dodge also "
             "takes the scan's best trail candidate as its source, which is the one it was "
             "missing: v48 printed manager=0x0 in both runs while a candidate with live objects "
             "sat unread in the trail; (3) heap passes go from every 30 s to every 5 s, because "
             "both logs show the first real container arriving 60+ s in and the log window "
             "closing before that; (4) the dodge logs its OWN ENTRY unconditionally, so 'did it run' is "
             "printed rather than inferred; (2) the probe runs from whichever of mode/manager "
             "exists, because the array hangs off the MANAGER and only the actuator needs the "
             "mode; (3) a new field report walks a window of the elements and prints, per "
             "four-byte offset, how many DISTINCT values appear, naming the team offset (the "
             "one that splits them) and the position pair (two adjacent offsets, all values "
             "small, all elements different) without assuming either -- the 20:51 dump shows "
             "why that is needed: on its four objects +0x40 ran 0,1,2,3 which is a slot index "
             "and not a team, +0xd0 was 0 on all four, and the repository's +0x30/+0x34 read "
             "as a heap pointer and a 1; (4) the actuator is still pinned to its three "
             "instructions and still gated, but 'no mode' and 'no coordinates' are now "
             "reported as the different failures they are");

    tnx_logf("plan v50: nine requirements from the 21:39 run, in priority order: (1) the alert is "
             "gated on mode!=0 || manager!=0 AND live>=2 AND teamCount>=2 AND three consecutive "
             "sightings of the SAME container, and every refusal prints why "
             "(`v50 alert withheld: ... live= teamCount= distinctGids= deadOk= vt0= sightings=`); "
             "(2) the trail is ranked by (live, nonEmpty, count) and its stability flag is a field "
             "again, not a gate -- `worst eight` became `top eight`, the best entry is marked "
             "`<- best`, and an empty best is named `best trail candidate has live=0, waiting`; "
             "(3) every rejected element carries a reason (rejNull/rejUnreadable/rejNoVt/"
             "rejGidZero/rejOutOfRange/rejTeamMissing) and `dead` is counted but never rejected; "
             "(4) both team offsets are printed on the raw elements with their distinct counts and "
             "the choice is justified; (5) every hook prints armed/slotRva/liveSlots/"
             "firstCallTick/hits every tenth tick, and a slot with no hit after 30 ticks says "
             "`never dispatched`; (6) the 0x1009290 table is interrogated -- four of its instances, "
             "their ids, teams, dead bytes, owners and the words at +0x08/+0x40/+0x4c/+0xd0 -- and "
             "four identical ids veto the hook; (7) best and summary are one decision: the first "
             "ranked candidate whose summary yields an instance is the best, and the summary now "
             "says WHY it extracted nothing; (8) the actuator's `this` must pass the mode test "
             "(class table in __DATA_CONST and [this+0x28] == the walked manager) before any "
             "write, and `setpred=` is renamed `setpredFn=` because it was always a fingerprint, "
             "not a store; (9) `no elements in container` and `all elements rejected` are "
             "different sentences, and the second one prints the reasons");

    tnx_logf("plan v52: (1) text tables are refused by the trail before they are scored - the v51 log "
             "shows why (raw[0]=FutureGi, raw[1]=rlMainAt, raw[0]=TID_BOT_), and the "
             "walk now counts them as rejAscii; (2) a slot that was installed through pointer slots "
             "reports armed=1 with the slot count instead of armed=0 because its spec has no slotRva "
             "of its own; (3) six direct hooks are added on functions the engine itself calls "
             "(getTeamStars, addGameObject, generateGameObjectGlobalID, findOwningTeam2, "
             "MessageManager::receiveMessage, setPredictionXY), installed through pointer slots "
             "only -- runtime inline patching is not supported, so a target that no data slot "
             "points at reports not-found instead of pretending to be armed; (4) the owner vote is ranked by team count first, so a text table with sixteen "
             "ids can no longer beat the container that carries two teams, and a two-team owner is "
             "adopted on the pass it appears; (5) the dodge falls back to that owner instead of an "
             "empty trail; (6) the dead byte at +0xd0 is measured - zero, one, other - and the "
             "decision to use it is deferred until the measurement says it is a flag");

    tnx_logf("plan v54: (1) the census tables that actually carry instances (0x100a770, 0x1008d30) "
             "are hook targets too, through the slot RVAs the census printed (E1-E4), so the "
             "question of who fires is asked of the classes the game uses; (2) the ClientInput route "
             "is armed as E5/E6 (setClientPredictionMoveTo, sendMovement) and announces itself when "
             "five passes find no source at all; (3) a container must be half objects to enter the "
             "trail - under that it is refused as weak and the ratio is printed on every trail "
             "line; (4) C2 reports weak when its slot count falls below a hundred, where the 22:36 "
             "run had 443; runtime inline patching is not supported, so every one of these is a "
             "data slot or nothing");

    tnx_logf("plan v55, from the 23:05-23:09 v53 run: (1) the six direct targets are removed - all "
             "six reported slots=0, so no data slot anywhere points at them and runtime inline is "
             "not supported; their rows now hold slots of the class tables that really carry "
             "instances (0x10078b8, 0x10086c0, 0x1008c28, 0x1009290); (2) the owner the vote adopted "
             "(0x11ee08890, two teams, 21 objects) has an EMPTY array header (array=0x107fc8a88 "
             "count=0), so adoption now has to pass that test and a refusal says which container to "
             "hunt for instead; (3) the chain probe never logged one candidate and its budget was "
             "spent (chain=10740163/65536 chainSkip=1883557) - it counts which gate rejects each "
             "candidate, resets its budget on every pass, and prints the first four near misses with "
             "the mode and manager windows so the next log shows the real offsets; (4) objhit lines "
             "carry pos=(x,y), the field the dodge cannot work without");

    tnx_logf("plan: the v45 log answered the question v45 was built for and broke one assumption "
             "underneath it. ANSWERED, from the objhit dump: the live objects carry class tables of "
             "their own - 0x100a770 under three heap-owned objects, plus 0xf923e0, 0xf92468, "
             "0x1014f70, 0x1008be0, 0x1009290 - and none of them is in the nine-entry vtprobe list, "
             "which is the whole explanation of hooks fired=0 of 7. Also answered: +0x20 never "
             "repeats (maxVotes=1 in all three passes, a different topOwner each time), so no vote "
             "can ever name the manager through that field, and the 0x1008d30 family that fooled the "
             "19:51 run is now correctly classified image instead of becoming a capture. BROKEN: the "
             "20:06 conclusion that vtprobe=0 was measured over a COMPLETE sweep. Both 20:22 passes "
             "scanned ~540 MB and both were cut off by the fixed 512 MB budget, but pass 1 started "
             "at 0x0 (mostly memory BELOW the window) and pass 3 at the window low, so they were cut "
             "off over different memory - and the ninth counter duly read 0 on the first and 92502 "
             "on the second. So v46 (1) makes the budget follow the window and prints budget=/"
             "budgetHit=/readTo=, (2) resumes a budget-cut pass at the exact address it stopped "
             "instead of past the whole region, (3) splits the accumulated vtprobe= into "
             "vtprobePass=/vtprobeAll= and names the first address behind each non-zero counter, and "
             "(4) replaces the nine-name list with a census: every 16-byte aligned word pointing into "
             "__DATA_CONST or __DATA is counted per class table, with the number of instances, how "
             "many of them passed the full object record layout (shaped=), and how many read the same "
             "at +0x00 and +0x20 (ownerEqVt=, the 19:51 signature as a count). vtslots then prints "
             "the first slot RVAs of the two most interesting tables - the hook targets for v47. And "
             "(5) one more split, because the 20:22 run put 398 of its 597 shaped words in "
             "ownerNoRegion and that number has two opposite explanations: the window is rebuilt "
             "every tenth attempt and it SHRANK during that run from 7776 MB to 567 MB, so an owner "
             "above the window high is a WINDOW problem while an owner in no region at all is a "
             "REGION problem. They are now ownerAboveWin= and ownerNoRegion=, and objShaped= is "
             "counted uncapped so the identity hits+skipped+ownerImg+ownerNoRegion+ownerAboveWin = "
             "objShaped can actually be checked - v45 printed the dump's capped count there, which "
             "made the check impossible exactly when there was something to check");

    tnx_start_timer();

    tlog([NSString stringWithFormat:@"setup completed successfully armed=%d", g_objc_armed]);
}

static void poll_for_game(int tick) {
    if (g_setup_done) return;
    if (tick > 1200) return;

    uintptr_t base = 0;

    if (find_game_image(&base)) {
        g_base = base;
        setup();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(tick + 1);
    });
}

__attribute__((constructor))
static void start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        tlog(@"=== titanox started (zero latency mode) ===");
        poll_for_game(0);
    });
}
