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

#define TNX_MANAGER_PROBE_LIMIT 131072

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
#define TNX_V106_GID_FALLBACK_OFF 0x50ULL
#define TNX_V106_COORD_SOFT 0
#define TNX_V107_INNER_OFF 0x70ULL
#define TNX_V108_OWNER_MAX 8
#define TNX_V109_MAX 16
#define TNX_V110_WIRE_OWNER 1
#define TNX_V110_WIRE_MIN_COUNT 6
#define TNX_V110_HOPCHOSEN_DIRECT 2
#define TNX_V109_PROXY_VT 0x1009290ULL
#define TNX_V109_SELFREF_VT 0xf97a28ULL
#define TNX_V109_COMBAT_VT_A 0xff57b0ULL
#define TNX_V109_COMBAT_VT_B 0xff5440ULL
#define TNX_V109_COMBAT_VT_C 0xff5100ULL
#define TNX_V108_OWNER_LOGS 16
#define TNX_V107_SCAN_FROM 0x00
#define TNX_V107_SCAN_TO 0x124
#define TNX_V107_SCAN_MAX 6

#define TNX_V112_FLAG_OFF 0xacULL
#define TNX_V112_INPUT_X_OFF 0x10cULL
#define TNX_V112_INPUT_Y_OFF 0x110ULL
#define TNX_V112_INPUT_K_OFF 0x114ULL
#define TNX_V112_INNER_OFF 0x70ULL
#define TNX_V112_ELEM40_OFF 0x40ULL
#define TNX_V112_POS_X_OFF 0x10ULL
#define TNX_V112_POS_Y_OFF 0x1cULL
#define TNX_V112_POS2_X_OFF 0x20ULL
#define TNX_V112_POS2_Y_OFF 0x24ULL
#define TNX_V112_GETX_SLOT 0x88ULL
#define TNX_V112_GETY_SLOT 0x90ULL
#define TNX_V112_DEREF_QWORDS 64
#define TNX_V112_FLAG_MAX_TICKS 6
#define TNX_V112_POS_EVERY 30
#define TNX_V112_INDEX_OFF 0x48ULL
#define TNX_V112_TEAM_OFF2 0x4cULL
#define TNX_V112_DEAD_OFF 0xd0ULL
#define TNX_V112_GID_OFF 0x50ULL
#define TNX_V112_ELEM_VT_RVA 0xf9e248ULL
#define TNX_V112_SETPRED4_RVA 0xac3a58ULL
#define TNX_V112_READER_RVA 0xac3424ULL

#define TNX_V113_READER_RVA 0x00ac3424ULL
#define TNX_V113_ALLOC_RVA 0x00d8da2cULL
#define TNX_V113_MSGCTOR_RVA 0x00a95798ULL
#define TNX_V113_ADDINPUT_RVA 0x0074675cULL
#define TNX_V113_GETBATTLE_RVA 0x008c5130ULL
#define TNX_V113_MGR_OFF 0x58ULL
#define TNX_V113_QUEUE_OFF 0x20ULL
#define TNX_V113_QUEUE_COUNT_OFF 0xcULL
#define TNX_V113_MSG_SIZE 0x48
#define TNX_V113_TYPE_OFF 0x08ULL
#define TNX_V113_X_OFF 0x0cULL
#define TNX_V113_Y_OFF 0x10ULL
#define TNX_V113_SEQ_OFF 0x00ULL
#define TNX_V113_TYPE_MOVE 2
#define TNX_V113_TEST_STEP 300
#define TNX_V113_WAIT_TICKS 3
#define TNX_V113_LONG_TICKS 10
#define TNX_V113_HOP2_OWNER_OFF 0x28ULL
#define TNX_V113_HOP2_INNER_OFF 0x28ULL
#define TNX_V113_HOP2_WAIT 60
#define TNX_V113_QUEUE_EVERY 5
#define TNX_V113_ALERT_WITHHELD 0
#define TNX_V113_DEAD_ONCE 1
#define TNX_V113_FRAME_WINDOW 12
#define TNX_V113_READER_ENTRY_RVA 0x00ac1ee8ULL
#define TNX_V113_READER_CALLER_RVA 0x008cc004ULL
#define TNX_V113_X_OFF_SCENE 0x10cULL
#define TNX_V113_Y_OFF_SCENE 0x110ULL

#define TNX_V115_MODE_OFF 0x124ULL
#define TNX_V115_MODE_TARGET 7
#define TNX_V115_GATE_PTR_OFF 0x30ULL
#define TNX_V117_GATE3_PTR_OFF 0x38ULL
#define TNX_V119_ELIG_OFF 0x1fdULL
#define TNX_V119_PROP_214_OFF 0x214ULL
#define TNX_V119_PROP_220_OFF 0x220ULL
#define TNX_V119_PROP_224_OFF 0x224ULL
#define TNX_V119_DENOM_MIN 4
#define TNX_V119_TEST_ENABLE 0
#define TNX_V120_FROM_OFF 0x138ULL
#define TNX_V120_TO_OFF 0x13cULL
#define TNX_V120_ENTITY_GETTER_RVA 0x1c1c0ULL
#define TNX_V120_HOLDER_CTOR_RVA 0xafcc84ULL
#define TNX_V120_HOLDER_SIZE 0x20
#define TNX_V120_HOLDER_VT_RVA 0x1003628ULL
#define TNX_V121_TRAJ_ARR_OFF 0x70ULL
#define TNX_V121_TRAJ_COUNT_OFF 0x7cULL
#define TNX_V121_TRAJ_TIME_OFF 0xb8ULL
#define TNX_V121_TRAJ_TIME_MUL_OFF 0xbcULL
#define TNX_V121_ENTRY_SEQ_OFF 0x98ULL
#define TNX_V121_ENTRY_BLOCK_OFF 0x90ULL
#define TNX_V121_NOOP_PUSH 1
#define TNX_V121_WIN1_FRAMES 30
#define TNX_V121_WIN2_FRAMES 120
#define TNX_V122_BOUND_X_OFF 0xccULL
#define TNX_V122_BOUND_Y_OFF 0xd0ULL
#define TNX_V122_POS_X_OFF 0x80ULL
#define TNX_V122_POS_Y_OFF 0x84ULL
#define TNX_V122_RESOLVE_SELF_RVA 0x991440ULL
#define TNX_V122_OWN_GETTER_RVA 0x7b9050ULL
#define TNX_V122_PRE_FRAMES 300
#define TNX_V123_MAX_SLOTS 32
#define TNX_V123_HOP2_DEFER 1
#define TNX_V123_WRITE_WAIT 5
#define TNX_V123_STEP 10
#define TNX_V123_OWN_IDX_OFF 0xe0ULL
#define TNX_V125_HEAP_LO 0x100000000ULL
#define TNX_V125_HEAP_HI 0x300000000ULL

#define TNX_V126_ALLOC_GOT_RVA 0x00f78180ULL
#define TNX_V126_TYPE_MOVE 0xa
#define TNX_V126_OWN_OFF 0x918ULL
#define TNX_V126_OWN_INNER_OFF 0x28ULL
#define TNX_V126_BOX_PTR_OFF 0xf8ULL
#define TNX_V126_BOX_MIN_OFF 0xccULL
#define TNX_V126_MGR_SEQ_OFF 0x14ULL
#define TNX_V126_PUSH_X 1500
#define TNX_V126_PUSH_Y 1500
#define TNX_V126_WTEST_H1 0
#define TNX_V126_CHAIN_EVERY 20
#define TNX_V126_CHAIN_LOGS 10
#define TNX_V126_WATCH_TICKS 600
#define TNX_V126_WATCH_EVERY 30
#define TNX_V126_WATCH_LOGS 20

static int g_v123_defer_logs = 0;
#define TNX_V115_GATE_BYTE_OFF 0x7aULL
#define TNX_V115_CLIENT_OFF 0x28ULL
#define TNX_V115_CLIENT_POS_X_OFF 0x80ULL
#define TNX_V115_CLIENT_POS_Y_OFF 0x84ULL
#define TNX_V115_MODE_WAIT 1200
#define TNX_V115_REQUIRE_GATE 0
#define TNX_V115_TEST_ENABLE 1

#define TNX_V116_HIST_MODES 16
#define TNX_V116_INTERP_TICKS 25
#define TNX_V116_HIST_TICKS 25
#define TNX_V116_HIST_LOGS 60

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

#define TNX_BUILD_TAG "titanox_126"

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
#define TNX_V59_REJECT_VTS 8
#define TNX_V59_REJECT_LOG_EVERY 10000
#define TNX_V85_ELEM_DUMPS 3
#define TNX_V85_ELEM_QWORDS 96
#define TNX_V86_TYPE_SLOT_OFF 0x28ULL
#define TNX_V86_ELEM_QWORDS 9
#define TNX_V86_ELEM_DUMPS 4
#define TNX_V86_HYP_TEAM_OFF 0x4cULL
#define TNX_V86_HYP_BYTE_OFF 0x48ULL
#define TNX_V86_DEF_68_OFF 0x68ULL
#define TNX_V86_TYPE3_CLASS_RVA 0x00fd4840ULL
#define TNX_V87_FLOAT_LO 0x10ULL
#define TNX_V87_FLOAT_LO2 0x1cULL
#define TNX_V87_FLOAT_HI 0x100ULL
#define TNX_V87_FLOAT_HI2 0x104ULL
#define TNX_V88_TYPE3_CODE 3
#define TNX_V88_ELEMCLASS_RVA 0x00ff5440ULL
#define TNX_V88_ELEM_BACK_OFF 0x18ULL
#define TNX_V88_ELEM_INT_A 0x30ULL
#define TNX_V88_ELEM_INT_B 0x34ULL
#define TNX_V88_ELEM_QWORDS 96
#define TNX_V88_DEF_QWORDS 32
#define TNX_V88_ELEM_DUMPS 1
#define TNX_V88_BACK_MIN 2
#define TNX_V89_WALK_EVERY 5
#define TNX_V90_SLOTS 3
#define TNX_V91_TEAM_OFF 0x4cULL
#define TNX_V91_DEAD_OFF 0xd4ULL
#define TNX_V99_SCAN_QWORDS 512
#define TNX_V99_SCAN_BASES 3

static void tnx_v103_state_note(int state);
static void tnx_v112_deref_dump(uintptr_t element);

static uintptr_t g_v103_sp4 = 0;
static uintptr_t g_v103_sp2 = 0;
static uintptr_t g_v103_addinput = 0;
static uintptr_t g_v103_mgr = 0;
static int g_v103_armed = 0;
static int g_v103_mgr_logs = 0;
static int g_v103_test_state = 0;
static uint64_t g_v103_test_tick = 0;
static int g_v103_test_before_x = 0;
static int g_v103_test_before_y = 0;
static int g_v103_test_after_x = 0;
static int g_v103_test_after_y = 0;
static int g_v103_moved = 0;
static int g_v103_moved2 = 0;
static int g_v103_kept = 0;
static int g_v103_tested = 0;
static int g_v103_ok = 0;
static uint64_t g_v103_writes = 0;
static int g_v103_last_x = 0;
static int g_v103_last_y = 0;
static uint64_t g_v103_tick = 0;
static int g_v103_attempt = 0;
static int g_v103_prev_state = -1;
static int g_v103_other_logs = 0;
static int g_v103_other_detail = 0;

#define TNX_V103_SETPRED4_RVA 0xac3a58ULL
#define TNX_V103_SETPRED2_RVA 0xac3f20ULL
#define TNX_V103_ADDINPUT_RVA 0x74675cULL
#define TNX_V103_GETBATTLE_RVA 0x8c5130ULL
#define TNX_V103_INPUTMGR_OFF 0x58ULL
#define TNX_V103_MGR_QUEUE_OFF 0x20ULL
#define TNX_V103_KEY_TABLE_VM 0x100e1d9a8ULL
#define TNX_V103_KEY_TABLE_N 21
#define TNX_V103_TEST_STEP 300
#define TNX_V103_TEST_WAIT 3
#define TNX_V103_TEST_WAIT_LONG 10
#define TNX_V103_LOG_EVERY 10
#define TNX_V103_OTHER_ELEM_OFF 0x18ULL
#define TNX_V103_OTHER_DETAIL 2
#define TNX_V103_MAX_OTHERS 16
#define TNX_V103_SEND_TEST 0
#define TNX_V103_USE_PRED2 0
#define TNX_V103_ACTUATOR_FLAG 1
#define TNX_V103_DODGE_USE_PRED4 1

static uintptr_t g_v102_own_ptr = 0;
static int g_v102_own_index = -1;
static int g_v102_own_team = -1;
static int g_v102_own_base = -1;
static int g_v102_own_logs = 0;
static int g_v102_audited = 0;
static int g_v102_inject_logs = 0;
static const char *g_v102_own_from = "none";
static uint64_t g_v102_tick = 0;
static uint64_t g_v102_write_last = 0;
static int g_v102_write_phase = 0;
static int g_v102_write_count = 0;
static int g_v102_write_base_ok = 0;
static int g_v102_write_base_x = 0;
static int g_v102_write_base_y = 0;
static int g_v102_trace_logs = 0;
static int g_v102_trace_n = 0;
static uintptr_t g_v102_trace_obj[TNX_V47_OBJECT_MAX];
static int g_v102_trace_x[TNX_V47_OBJECT_MAX];
static int g_v102_trace_y[TNX_V47_OBJECT_MAX];

#define TNX_V102_WRITE_TEST 0
#define TNX_V102_WRITE_STEP 48
#define TNX_V102_WRITE_EVERY 20
#define TNX_V102_WRITE_TICKS 6
#define TNX_V102_TRACE_MAX 32
#define TNX_V102_ELEM_ID_OFF 0x48ULL
#define TNX_V102_ELEM_TEAM_OFF 0x4cULL
#define TNX_V102_ARRAY_OFF 0x0ULL
#define TNX_V102_COUNT_OFF 0xcULL
#define TNX_V102_OWNIDX_OFF 0xe0ULL
#define TNX_V102_OWNTEAM_OFF 0xe4ULL
#define TNX_V102_GETTEAMSTARS_RVA 0xac3cfcULL
#define TNX_V102_SETPRED_RVA 0xac3f20ULL
#define TNX_V102_MODEPAIRSET_RVA 0xac3a58ULL
#define TNX_V102_TILELOOKUP_RVA 0xac3f48ULL
#define TNX_V102_SUBGETTER_RVA 0xac3f2cULL

static uintptr_t g_v101_own_ptr = 0;
static int g_v101_own_index = -1;
static int g_v101_own_team = 0;
static int g_v101_own_idhit = 0;
static uintptr_t g_v101_setpred = 0;
static int g_v101_audited = 0;
static int g_v101_own_logs = 0;
static int g_v101_head_logs = 0;
static int g_v101_wide_runs = 0;
static int g_v101_wide_hits = 0;
static int g_v101_miss_logs = 0;
static const char *g_v101_own_from = "none";

#define TNX_V101_OWNIDX_OFF 0xe0ULL
#define TNX_V101_OWNTEAM_OFF 0xe4ULL
#define TNX_V101_ELEM_ID_OFF 0x48ULL
#define TNX_V101_ELEM_TEAM_OFF 0x4cULL
#define TNX_V101_GETTEAMSTARS_RVA 0xac3cfcULL
#define TNX_V101_MODEPAIRSET_RVA 0xac3a58ULL
#define TNX_V101_WIDE_QWORDS 4096
#define TNX_V101_WIDE_ATTEMPTS 2
#define TNX_V101_OWN_LOGS 12
#define TNX_V101_DELTA_TICKS 60
#define TNX_V101_ACTUATOR 0
#define TNX_V101_ACTUATOR_STEP 40
#define TNX_V99_INPUTMGR_WRITE 0
#define TNX_V99_INPUTMGR_COS_OFF 0x8ULL
#define TNX_V99_INPUTMGR_SIN_OFF 0xcULL
#define TNX_V99_INPUTMGR_WRITE_X 0.7071
#define TNX_V99_INPUTMGR_WRITE_Y 0.7071
#define TNX_V99_ADOPT_REJECT_LOGS 8
#define TNX_V92_TEAM_DUMPS 4
#define TNX_V92_VERIFY_FRAMES 3
#define TNX_V93_TEST_WRITE 0
#define TNX_V93_DEAD_FILTER 0
#define TNX_V93_TEST_X 2000
#define TNX_V93_TEST_Y 2000
#define TNX_V93_POS_DUMPS 8
#define TNX_V93_CLASS_QWORDS 4
#define TNX_V93_CLASS_DUMPS 2
#define TNX_V96_BASES 24
#define TNX_V99_SPAN 0x1000
#define TNX_V99_FLOATS (TNX_V99_SPAN / 4)
#define TNX_V96_LINES 12
#define TNX_V96_DETAIL_MAX 16
#define TNX_V97_MOVE_MAX 96
#define TNX_V97_CHANGED_MAX 128
#define TNX_V97_GROUP_MIN 2
#define TNX_V97_GROUP_GAP 1
#define TNX_V97_QUIET 8
#define TNX_V97_GROUPS 6
#define TNX_V97_GROUPS_MAXLEN 8
#define TNX_V97_COSSIN_TOL 0.05f
#define TNX_V98_FORCE_SECS 30
#define TNX_V98_CLIP_SELFTEST 1
#define TNX_V98_GRID 8
#define TNX_V85_FIELD_QWORDS 8
#define TNX_V85_FIELD_SCANS 1
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
#define TNX_V76_SCAN_FLOOR_TICKS 12
#define TNX_V76_SCAN_FALLBACK_TICKS 20
#define TNX_V63_KNOWN_VT_COUNT 4

#define TNX_V65_MODESIG_TICKS 3
#define TNX_V77_LIVE_OBJ_MIN 3
#define TNX_V77_LIVE_TEAM_MIN 2
#define TNX_V77_TEAM_SLOTS 16
#define TNX_V77_BAR_TICKS 30
#define TNX_V78_IDLE_TICKS 15
#define TNX_V78_IDLE_RETRY_TICKS 300
#define TNX_V79_OBJCLASS_RVA 0xff5720ULL
#define TNX_V79_PROBE_TRIES 3
#define TNX_V79_OBJ_SLOTS 3
#define TNX_V79_KIND_OFF 0x35cULL
#define TNX_V79_FIELD_LO 0x20ULL
#define TNX_V79_FIELD_HI 0x300ULL
#define TNX_V79_SIBLINGS 4
#define TNX_V80_STATE_RVA 0x1123e58ULL
#define TNX_V80_STATE_ENUM_OFF 0x50ULL
#define TNX_V80_SCENE_OFF 0x48ULL
#define TNX_V80_STATE_BATTLE 5

#define TNX_V81_SCENE_CLASS_RVA 0xfe9d00ULL
#define TNX_V81_SCENE_CTX_OFF 0x10ULL
#define TNX_V81_SCENE_COUNT_OFF 0xcULL
#define TNX_V81_PLAYERS_NEXT_OFF 0xf8ULL
#define TNX_V81_NEXT_MEMBER_OFF 0x68ULL
#define TNX_V81_DUMP_QWORDS 32
#define TNX_V81_VT_MAX 24
#define TNX_V81_CENSUS_MAX 6
#define TNX_V81_PLAYERS_DUMPS 4
#define TNX_V81_KIND_MAX 0x1000

#define TNX_V82_CLIENT_HOP_OFF 0x28ULL
#define TNX_V82_ELEM_DEF_OFF 0x10ULL
#define TNX_V82_ELEMCLASS_RVA 0xf9e248ULL
#define TNX_V82_ELEMCLASS_SUB_RVA 0xf9e268ULL
#define TNX_V82_ELEMCLASS_SLOTS 6
#define TNX_V82_CONTAINER_TEAMS 16
#define TNX_V82_KIND_MAX 0x1000
#define TNX_V82_HOPS 2
#define TNX_V82_HOP_DUMPS 4
#define TNX_V67_OWNER_RETRY_TICKS 20
#define TNX_V68_PENDING_MAX 8
#define TNX_V68_PENDING_RETRY_TICKS 5
#define TNX_V71_PENDING_MAX_ATTEMPTS 3
#define TNX_V71_ARRAY_PROBE 8
#define TNX_V71_ARRAY_MIN_OBJS 2

#define TNX_V75_ASCII_WINDOW 32
#define TNX_V75_ASCII_RATIO 30
#define TNX_V75_TEAM_MAX 15
#define TNX_V75_GID_MAX 1000000
#define TNX_V75_COORD_MAX 100000
#define TNX_V75_GID_DISTINCT_MIN 2

#define TNX_V72_OWNERCHAIN_PROBE 12
#define TNX_V72_DEAD_PROBE_COUNT 5
#define TNX_V73_STATE_DROPPED (-2)
#define TNX_V73_INST_SLOTS 8

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

static uintptr_t g_scene_object = 0;
static BOOL g_mode_strong = NO;
static int g_mode_best_objects = 0;
static int g_mode_last_types = 0;
static int g_mode_verified_hits = 0;
static uintptr_t g_players_object = 0;
static int g_v82_hop_chosen = -1;
static int g_v82_hop_sticky = 0;
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

#define TNX_SLOT_COUNT 32
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
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1 };
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
static uintptr_t g_v59_reject_vts[TNX_V59_REJECT_VTS] = { 0 };
static int g_v59_reject_vt_count = 0;
static uint64_t g_v59_reject_total = 0;
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
static int g_v66_trail_refusals = 0;
static int g_v67_rejected_tick[TNX_V57_REJECT_MAX] = { 0 };
static int g_v67_retry_logged = 0;
static int g_v67_layout_used = 0xc;
static int g_v67_layout_logs = 0;
static uintptr_t g_v68_pending[TNX_V68_PENDING_MAX] = { 0 };
static int g_v68_pending_tick[TNX_V68_PENDING_MAX] = { 0 };
static int g_v68_pending_count = 0;
static int g_v68_probe_logs = 0;
static int g_v68_gate_logs = 0;
static int g_v68_dump_logs = 0;
static int g_v71_pending_attempts[TNX_V68_PENDING_MAX] = { 0 };
static int g_v71_pending_evicted = 0;
static int g_v71_head_reject_logs = 0;
static int g_v71_array_reject_logs = 0;
static int g_v71_modewindow_logs = 0;
static int g_v72_trail_refusals = 0;
static int g_v75_ascii_refused = 0;
static int g_v75_ascii_refusals = 0;
static int g_v75_best_wait_logs = 0;
static int g_v75_gid_veto_logs = 0;
static int g_v76_floor_logged = 0;
static int g_v76_fallback_logged = 0;
static int g_v77_live_objs = 0;
static int g_v77_live_teams = 0;
static int g_v77_fb_on = 0;
static int g_v77_fb_logged = 0;
static int g_v77_bar_logged = 0;
static unsigned g_v77_vt_text_rejects = 0;
static unsigned long long g_v79_obj_prev = 0;
static int g_v79_probe_done = 0;
static int g_v79_probe_tries = 0;
static uintptr_t g_v80_site = 0;
static int g_v80_state = -1;
static int g_v80_scan_armed = -1;
static int g_v80_novt_logs = 0;
static uintptr_t g_players_array = 0;
static int g_players_count = 0;
static int g_players_cap = 0;
static int g_v81_prev_have_scene = 0;
static int g_v81_census_logs = 0;
static int g_v85_elem_dumps = 0;
static int g_v85_field_scans = 0;
static int g_v86_elem_dumps = 0;
static int g_v86_hop2_census = 0;
static int g_v86_type3_floats = 0;
static uintptr_t g_v88_census_container = 0;
static int g_v88_elem_full_dumps = 0;
static int g_v88_walk_relogs = 0;
static uint64_t g_v89_walk_tick = 0;
static uint64_t g_v89_enter_tick = 0;
static int g_v89_walk_count = -1;
static int g_v89_coord_fixed_logged = 0;
static int g_v90_slot_dumped = 0;
static int g_v90_gate_calls = 0;
static uintptr_t g_v91_own_ptr = 0;
static int g_v91_own_index = -1;
static int g_v91_own_src = -1;
static uintptr_t g_v91_own_off = 0;
static uintptr_t g_v91_scan_container = 0;
static int g_v91_scan_logs = 0;
static int g_v91_own_logged = 0;
static int32_t g_v92_wrote_x = 0;
static int32_t g_v92_wrote_y = 0;
static int32_t g_v92_own_pos_x = 0;
static int32_t g_v92_own_pos_y = 0;
static uint64_t g_v92_wrote_tick = 0;
static int g_v92_wrote_valid = 0;
static int g_v92_check_done = 0;
static uint64_t g_v93_test_tick = 0;
static uint64_t g_v93_test_writes = 0;
static int g_v93_class_dumps = 0;
static int g_v95_find_joy_done = 0;

typedef struct {
    uintptr_t base;
    int used;
    int have;
    uint32_t prev[TNX_V99_FLOATS];
} tnx_v96_slot_t;

static tnx_v96_slot_t g_v96[TNX_V96_BASES];
static int g_v96_lines = 0;
static int g_v97_pos_x[TNX_V97_MOVE_MAX];
static int g_v97_pos_y[TNX_V97_MOVE_MAX];
static int g_v97_pos_n = -1;
static int g_v97_held = 0;
static uint64_t g_v98_last_sample = 0;
static int g_v98_force_due = 0;
static int g_v98_clip_pass = 0;
static int g_v98_clip_fail = 0;
static int g_v99_inputmgr_logs = 0;
static int g_v99_adopt_reject_logs = 0;
static uint64_t g_v99_static_samples = 0;
static uint64_t g_v99_inputmgr_writes = 0;
static uint64_t g_v99_inputmgr_last_tick = 0;
static const char *g_v91_own_from = "none";
static int g_v81_players_dumps = 0;
static int g_v82_hop_dumps = 0;
static uintptr_t g_v81_vt_seen[TNX_V81_VT_MAX] = { 0 };
static int g_v81_vt_live[TNX_V81_VT_MAX] = { 0 };
static int g_v81_vt_used = 0;
static uint64_t g_v78_idle_start = 0;
static int g_v78_idle_on = 0;
static int g_v78_idle_logged = 0;
static int g_v78_idle_skips = 0;
static uint32_t g_v73_inst_mask = 0;
static int g_v73_inst_slots = 0;
static int g_v73_inst_positive = 0;
static int g_v73_inst_summary = 0;
static int g_v71_head_ok = 0;
static int g_v71_head_rejected = 0;
static int g_v71_head_veto = 0;
static int g_v71_head_veto_logs = 0;
static unsigned long long g_v71_pending_pushed = 0;
static int g_v71_pending_seen = 0;
static int g_v71_pending_q_log = 0;
static int g_v71_modehit_dump = 0;
static int g_v71_teamhist_logs = 0;
static int g_v71_ownerchain_logs = 0;
static int g_v62_class_pass = 0;
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
static void tnx_v96_tick(void);
static void tnx_v99_inputmgr_probe(void);
static const char *tnx_v57_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut);
static int tnx_v57_class_slot_ok(uintptr_t vtable);
static int tnx_v57_is_fn_start(uintptr_t address);
static int tnx_v57_owner_rejected(uintptr_t owner);
static void tnx_v57_owner_reject(uintptr_t owner);
static void tnx_v57_hook_triage(int index);
static void tnx_v57_drop_hook(int index);
static void tnx_v73_instance_probe(int index, void *self, uint64_t arg1);
static uint64_t tnx_v79_object_dispatches(void);
static void tnx_v79_object_probe(void);
static BOOL tnx_heap_resident(uintptr_t value);
static int tnx_v80_state_tick(void);
static void tnx_v81_global_dump(uintptr_t slot);
static void tnx_v81_scene_dump(uintptr_t scene);
static void tnx_v81_players_dump(uintptr_t players, uintptr_t array, int32_t count,
                                 int32_t capacity);
static void tnx_v81_container_census(uintptr_t array, int32_t count, uintptr_t container);
static void tnx_v88_element_full(uintptr_t element, uintptr_t def, uintptr_t container);
static void tnx_v81_scene_reset(const char *why);
static void tnx_v81_alert_edge(uintptr_t scene, uintptr_t players, int32_t count, int32_t state);
static int tnx_v81_is_battle_object(uintptr_t object, char *why, size_t whyLen);
static int tnx_v82_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut,
                                    int32_t *capOut, char *why, size_t whyLen);
static void tnx_v82_hop_dump(uintptr_t client, uintptr_t inner);
static void tnx_v81_vt_note(uintptr_t vt);
static char tnx_v72_seg_code(uintptr_t value);
static const char *tnx_image_segment_name(uintptr_t value);
static void tnx_v59_chain_capture(uintptr_t modeObject, uintptr_t vtable, uintptr_t manager);
static void tnx_v62_alert_menu(NSString *info);
static void tnx_v64_modesig_tick(void);
static BOOL tnx_v56_vtable_in_image(uintptr_t vtable);
static uintptr_t tnx_v60_strip_ptr(uintptr_t value);
static int tnx_v59_container_at(uintptr_t object, int32_t *countOut, int32_t *capOut, char *why,
                                size_t whyLen);
static uint64_t tnx_v68_word(uintptr_t address);
static int tnx_v60_container_resolve(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                     int32_t *capOut, char *why, size_t whyLen);
static int tnx_v68_container_gate(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                  int32_t *capOut, char *why, size_t whyLen);

static int tnx_v60_container_resolve(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                     int32_t *capOut, char *why, size_t whyLen);
static int tnx_v63_battle_gate(int scene);
static void tnx_v63_log_heartbeat(void);
static void tnx_v59_hook_note(int index);
static void tnx_v59_hook_summary(void);
static int tnx_v68_container_gate(uintptr_t manager, uintptr_t *containerOut,
                                  int32_t *countOut, int32_t *capOut, char *why,
                                  size_t whyLen);
static uint64_t tnx_v68_word(uintptr_t address);
static void tnx_v68_pending_push(uintptr_t owner, const char *reason);
static void tnx_v68_pending_tick(void);
static void tnx_v68_multiteam_dump(uintptr_t owner, uint32_t teamMask,
                                   int teamCount);
static int tnx_v71_manager_head_ok(uintptr_t owner);
static int tnx_v71_array_probe(uintptr_t array, int32_t count, char *why, size_t whyLen);
static void tnx_v71_modewindow_dump(uintptr_t mode);
static void tnx_v71_owner_chain_dump(uintptr_t container);
static void tnx_v71_owner_team_dump(uintptr_t owner, uint32_t teamMask, int teamCount);
static uintptr_t tnx_v57_coord_x_off(void);
static uintptr_t tnx_v57_coord_y_off(void);
static BOOL tnx_read_ptr(uintptr_t address, void **out);

typedef struct {
    int sampled;
    int ascii;
    int noVt;
    int teamDistinct;
    int posDistinct;
} tnx_v75_measure_t;

static int tnx_v75_element_ascii(uintptr_t element);
static int tnx_v75_object_live(uintptr_t object);
static void tnx_v75_measure(uintptr_t manager, int32_t count, tnx_v75_measure_t *out);

static BOOL tnx_obj_slot_fn(uintptr_t object, uintptr_t slot, uintptr_t *rvaOut);
static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty, int ascii, int sampled, int noVt, int teamDistinct,
                           int posDistinct, int refused);
static void tnx_trail_dump(void);
static void tnx_best_candidate_dump(void);

static void tnx_report_manager(const char *tag, uintptr_t manager);
static int tnx_object_detail_readonly(uintptr_t manager, int limit);

static void tnx_autododge_v48(void);

static void tnx_slot_note(int index, void *self, uint64_t arg1) {
    uint32_t bit = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_first_tick[index]) g_slot_first_tick[index] = g_v50_ticks;

    if (!g_slot_object[index] && self) g_slot_object[index] = (uintptr_t)self;

    if (!g_slot_arg1[index] && arg1) g_slot_arg1[index] = (uintptr_t)arg1;

    bit = (uint32_t)(1u << (unsigned)index);

    if (self && !(g_v73_inst_mask & bit)) tnx_v73_instance_probe(index, self, arg1);
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

static uint64_t tnx_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(19, a0, a1);

    if (g_slot_orig[19]) return g_slot_orig[19](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(20, a0, a1);

    if (g_slot_orig[20]) return g_slot_orig[20](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(21, a0, a1);

    if (g_slot_orig[21]) return g_slot_orig[21](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(22, a0, a1);

    if (g_slot_orig[22]) return g_slot_orig[22](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(23, a0, a1);

    if (g_slot_orig[23]) return g_slot_orig[23](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(24, a0, a1);

    if (g_slot_orig[24]) return g_slot_orig[24](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(25, a0, a1);

    if (g_slot_orig[25]) return g_slot_orig[25](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(26, a0, a1);

    if (g_slot_orig[26]) return g_slot_orig[26](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(27, a0, a1);

    if (g_slot_orig[27]) return g_slot_orig[27](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(28, a0, a1);

    if (g_slot_orig[28]) return g_slot_orig[28](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(29, a0, a1);

    if (g_slot_orig[29]) return g_slot_orig[29](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(30, a0, a1);

    if (g_slot_orig[30]) return g_slot_orig[30](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(31, a0, a1);

    if (g_slot_orig[31]) return g_slot_orig[31](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static int g_v113_dead_probe_done = 0;

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

    { "P1/disabled-no-data-slot", "P1", 0, 0, tnx_slot_repl_7, 0 },
    { "D2/disabled-fewer-noisy-slots", "D2", 0, 0, tnx_slot_repl_8, 0 },
    { "P2/disabled-no-data-slot", "P2", 0, 0, tnx_slot_repl_9, 0 },
    { "D4/disabled-fewer-noisy-slots", "D4", 0, 0, tnx_slot_repl_10, 0 },
    { "V6/vt0fe9d00+68/8c7fbc", "V6", 0x008c7fbcULL, 0x00fe9d68ULL, tnx_slot_repl_11, 0 },
    { "D6/table1009290 slot1 @bad4ec", "D6", 0x00000000ULL, 0, tnx_slot_repl_12, 1 },

    { "E1/table100a770 slot0 @bcfbe8", "E1", 0x00bcfbe8ULL, 0, tnx_slot_repl_13, 0 },
    { "E2/table100a770 slot1 @bcfc28", "E2", 0x00bcfc28ULL, 0, tnx_slot_repl_14, 0 },
    { "V1/disabled-fewer-noisy-slots", "V1", 0, 0, tnx_slot_repl_15, 0 },
    { "V2/vt0fe9d00+40/8c6150", "V2", 0x008c6150ULL, 0x00fe9d40ULL, tnx_slot_repl_16, 0 },
    { "E5/setClientPredictionMoveTo @b90b8c", "E5", 0x00b90b8cULL, 0, tnx_slot_repl_17, 1 },
    { "E6/sendMovement @7c13dc", "E6", 0x007c13dcULL, 0, tnx_slot_repl_18, 1 },

    { "D7/table10086c0 slot2 @b8ae88", "D7", 0x00b8ae88ULL, 0, tnx_slot_repl_19, 0 },
    { "D8/table10086c0 slot3 @b8ac7c", "D8", 0x00b8ac7cULL, 0, tnx_slot_repl_20, 0 },
    { "D9/disabled-fewer-noisy-slots", "D9", 0, 0, tnx_slot_repl_21, 0 },
    { "D10/disabled-fewer-noisy-slots", "D10", 0, 0, tnx_slot_repl_22, 0 },
    { "D11/table10086c0 slot8 @b85fe0", "D11", 0x00b85fe0ULL, 0, tnx_slot_repl_23, 0 },
    { "D12/table10086c0 slot9 @b867d8", "D12", 0x00b867d8ULL, 0, tnx_slot_repl_24, 0 },
    { "D13/table10086c0 slot10 @b9e188", "D13", 0x00b9e188ULL, 0, tnx_slot_repl_25, 0 },
    { "D14/table10086c0 slot11 @b9dc8c", "D14", 0x00b9dc8cULL, 0, tnx_slot_repl_26, 0 },

    { "V3/disabled-fewer-noisy-slots", "V3", 0, 0, tnx_slot_repl_27, 0 },
    { "V4/vt0fe9d00+50/8c7f9c", "V4", 0x008c7f9cULL, 0x00fe9d50ULL, tnx_slot_repl_28, 0 },
    { "V5/vt0fe9d00+58/8c7fac", "V5", 0x008c7facULL, 0x00fe9d58ULL, tnx_slot_repl_29, 0 },
    { "D15/table10086c0 slot21 @b898e8", "D15", 0x00b898e8ULL, 0, tnx_slot_repl_30, 0 },
    { "D16/table10086c0 slot23 @b89c10", "D16", 0x00b89c10ULL, 0, tnx_slot_repl_31, 0 },
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
        } else if (g_slot_installed[i] == TNX_V73_STATE_DROPPED) {
            state = "dropped";
        } else if (g_slot_installed[i] == 0) {
            state = (g_slot_slots[i] > 0) ? "install-failed" : "not-found";
        }

        total += g_slot_hits[i];

        tnx_logf("v100 hook %s %s armed=%d slots=%d slotRva=%#llx this=%p arg1=%p firstCallTick=%llu "
                 "hits=%llu tick=%llu",
                 g_slot_specs[i].shortTag, state, armed, g_slot_slots[i],
                 (unsigned long long)g_slot_specs[i].slotRva, (void *)g_slot_object[i],
                 (void *)g_slot_arg1[i], (unsigned long long)g_slot_first_tick[i],
                 (unsigned long long)g_slot_hits[i], (unsigned long long)g_v50_ticks);

        if (i == 6 && g_slot_installed[i] == 1 && g_slot_slots[i] < 100) {
            tnx_logf("v100 hook C2 weak: slots=%d where the 22:36 run had 443 - the target moved or "
                     "the table was rebuilt", g_slot_slots[i]);
        }

        if (i == 12 && g_v52_setpred_calls) {
            tnx_logf("v100 setprediction seen: calls=%llu this=%p target=(%.2f,%.2f)",
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

    tnx_logf("v100 hooks total fired=%llu armed=%d of %d slots at tick=%llu", (unsigned long long)total,
             armedCount, TNX_SLOT_COUNT, (unsigned long long)g_v50_ticks);

    tnx_logf("v100 trail refusals: stringy=%d image-resident=%d - the two counters replace the line "
             "that printed on every tenth refusal and flooded the v72 log with 964 of them; the "
             "denominator is the candidate count already printed on the trail line",
             g_v63_stringy_logs, g_v72_trail_refusals);
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

    if (!g_slot_specs[index].rva && !g_slot_specs[index].slotRva) return;

    target = g_base + g_slot_specs[index].rva;

    if (!target) return;

    slots = hook_probe(target);

    if (slots > TNX_V123_MAX_SLOTS) {
        tnx_logf("slot %s: reject-bulk target=%p slots=%d - that many identical copies means the address is "
                 "a shared constant duplicated across class tables and not a vtable entry, so redirecting "
                 "it would send every original caller into a stub with the wrong arguments",
                 g_slot_specs[index].tag, (void *)target, slots);

        return;
    }

    {
        uint32_t w = 0;
        int prologue = 0;

        if (tnx_read_u32(target, &w)) {
            if ((w & 0xFFC003FFu) == 0xD10003FFu) prologue = 1;
            if ((w & 0xFF4003E0u) == 0xA90003E0u) prologue = 1;
            if ((w & 0xFF4003E0u) == 0xA80003E0u) prologue = 1;
            if (w == 0xD503237Fu) prologue = 1;
            if (w == 0xD503245Fu) prologue = 1;
            if (w == 0xD65F03C0u) prologue = 1;
            if (w == 0x910003FDu) prologue = 1;
            if ((w & 0xFF000000u) == 0x14000000u) prologue = 1;
            if ((w & 0x9F000000u) == 0x10000000u) prologue = 1;
        }

        if (!prologue) {
            tnx_logf("slot %s: reject-nonfunc target=%p firstWord=%#x - the first instruction is not a "
                     "prologue, a leaf return, a branch or an adrp, so this is not a function entry and a "
                     "stub placed here would be entered with the caller's scratch registers intact",
                     g_slot_specs[index].tag, (void *)target, (unsigned)w);

            return;
        }
    }

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

static BOOL tnx_write_bytes(uintptr_t address, const void *src, size_t length) {
    if (!src || !length) return NO;
    if (!address) return NO;

    /* The write is a plain store and not a mach call. The v99 build reached for mach_vm_write,
       which the iOS SDK declares in mach/mach_vm.h and this file does not include - vm_map.h
       carries vm_read_overwrite but not mach_vm_write, so the CI compile stopped on it. The
       target here is heap memory that the same run has already read back as finite floats, so it
       is mapped and writable and a store needs no new SDK symbol; what the call would have
       returned on failure is replaced by reading the two words back after the store, which the
       probe does and reports. */
    memcpy((void *)address, src, length);

    return YES;
}

static BOOL tnx_write_f32(uintptr_t address, float value) {
    if (address & 3) return NO;

    return tnx_write_bytes(address, &value, sizeof(value));
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
             slotInstalled, (unsigned long long)slotControl, g_scene_object ? 1 : 0);

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

    if (g_v62_alerts_off) return;

    tnx_logf("v100 scene-mode alert shown - the latch that made the alert a once-per-process event "
             "is gone, the edge on the scene pointer is what limits it now");

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
            tnx_v62_alert_menu([NSString stringWithFormat:
                @"scene=%p source=%s sigHits=%d\nchainHits=%d classesPass=%d\nplayers=%p count=%d",
                (void *)g_scene_object, g_v62_mode_source, g_v64_modesig_hits, g_v59_chain_hits,
                g_v62_class_pass, (void *)g_players_object, g_manager_count]);
        }]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Скрыть алерты"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
            g_v62_alerts_off = 1;
        }]];

        [host presentViewController:menu animated:YES completion:nil];
    });
}

static int tnx_v77_vtable_is_data(uintptr_t vtable) {
    const char *segment = tnx_image_segment_name(vtable);

    if (!segment) return 0;
    if (strcmp(segment, "__DATA_CONST") == 0) return 1;
    if (strcmp(segment, "__DATA") == 0) return 1;

    return 0;
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
    if (!tnx_v77_vtable_is_data((uintptr_t)vt)) {
        if (g_v77_vt_text_rejects < 12) {
            g_v77_vt_text_rejects++;

            tnx_logf("v100 modesig reject at=%p vt=%p vtSeg=%s - a class table lives in "
                     "__DATA_CONST, and an in-image word outside the data segments is code",
                     (void *)at, vt, tnx_image_segment_name((uintptr_t)vt));
        }

        return 0;
    }
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

    if (g_scene_object) return;
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

            tnx_logf("v100 modesig hit obj=%p sighting=1/%d - a new address, the stability counter "
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
        g_scene_object = found;
        g_v62_mode_source = "modesig";
        g_v63_battle_last_tick = (int)g_v50_ticks;

        tnx_read_ptr(found, &vt);
        tnx_read_ptr(found + TNX_MODE_MANAGER_OFF, &mgr);
        tnx_read_i32(found + 0xecULL, &ec);
        tnx_read_i32(found + 0x124ULL, &m124);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_CAP_OFF, &cap);

        tnx_logf("v100 modesig accepted obj=%p vt=%#llx ec=%d m124=%#x mgr=%p count=%d ticks=%d "
                 "src=SIG", (void *)found, (unsigned long long)(uintptr_t)vt, ec, (unsigned)m124,
                 mgr, count, g_v65_sig_ticks);

        tnx_v71_modewindow_dump(found);

        if (count >= 2 && cap >= count && cap <= TNX_MGR_CAP_MAX) {
            g_players_object = (uintptr_t)mgr;
            g_manager_count = count;

            tnx_logf("v100 modesig container obj=%p mgr=%p count=%d cap=%d src=SIG", (void *)found,
                     mgr, count, cap);
        }
    }
}

static void tnx_v63_flush_buckets(void) {
    if (g_v63_image_count > 0) {
        tnx_logf("v100 image-resident: %d rejections in last %ds (top mgr=%p count=%d)",
                 g_v63_image_count, TNX_V63_BUCKET_TICKS, (void *)g_v63_image_top_mgr,
                 g_v63_image_top_count);

        g_v63_image_count = 0;
        g_v63_image_top_mgr = 0;
        g_v63_image_top_count = 0;
    }

    tnx_logf("v100 chain: hits=%d vtableChanged=%d classPass=%d", g_v59_chain_hits,
             g_v63_chain_vtchanged, g_v62_class_pass);

    g_v63_chain_vtchanged = 0;
    g_v63_chain_stable_logged = 0;
}

static void tnx_v81_global_dump(uintptr_t slot) {
    if (!slot) return;

    tnx_logf("v100 [G] dump slot=%p - every qword of the __common word the engine reads in "
             "0x8cdfd4; the scene is the pointer at +%#llx and the state enum the dword at +%#llx",
             (void *)slot, (unsigned long long)TNX_V80_SCENE_OFF,
             (unsigned long long)TNX_V80_STATE_ENUM_OFF);

    for (int i = 0; i < TNX_V81_DUMP_QWORDS; i++) {
        uintptr_t at = slot + (uintptr_t)i * 8;
        uint64_t word = tnx_v68_word(at);
        const char *seg = tnx_image_segment_name((uintptr_t)word);

        tnx_logf("v100 [G] +%02x = %#018llx seg=%s", i * 8, (unsigned long long)word,
                 seg ? seg : "-");
    }
}

static void tnx_v81_scene_dump(uintptr_t scene) {
    void *vt = NULL;

    if (!scene) return;

    tnx_read_ptr(scene, &vt);

    tnx_logf("v100 scene dump scene=%p vt=%p seg=%s - class %#llx: +%#llx is the dword the scene's "
             "own slots +0x50 and +0x68 compare against 7, +%#llx is the object those slots "
             "forward to at virtual 0x328..0x340, +%#llx is the container and +%#llx the "
             "mode variation",
             (void *)scene, vt, tnx_image_segment_name((uintptr_t)vt),
             (unsigned long long)TNX_V81_SCENE_CLASS_RVA,
             (unsigned long long)TNX_V81_SCENE_COUNT_OFF,
             (unsigned long long)TNX_V81_SCENE_CTX_OFF,
             (unsigned long long)TNX_MODE_MANAGER_OFF,
             (unsigned long long)TNX_MODE_MODEVAR_OFF);

    for (int i = 0; i < TNX_V81_DUMP_QWORDS; i++) {
        uintptr_t at = scene + (uintptr_t)i * 8;
        uint64_t word = tnx_v68_word(at);
        const char *seg = tnx_image_segment_name((uintptr_t)word);

        tnx_logf("v100 scene +%02x = %#018llx seg=%s", i * 8, (unsigned long long)word,
                 seg ? seg : "-");
    }
}

static void tnx_v81_players_dump(uintptr_t players, uintptr_t array, int32_t count,
                                 int32_t capacity) {
    if (!players) return;

    tnx_logf("v100 players dump players=%p array=%p count=%d cap=%d - this is the object the engine "
             "passes to 0x991440 after reading scene+%#llx", (void *)players, (void *)array, count,
             capacity, (unsigned long long)TNX_MODE_MANAGER_OFF);

    for (int i = 0; i < TNX_V81_DUMP_QWORDS; i++) {
        uintptr_t at = players + (uintptr_t)i * 8;
        uint64_t word = tnx_v68_word(at);
        const char *seg = tnx_image_segment_name((uintptr_t)word);

        tnx_logf("v100 players +%02x = %#018llx seg=%s", i * 8, (unsigned long long)word,
                 seg ? seg : "-");
    }

    tnx_logf("v100 players+%#llx is not followed any more - the chain through 0x991440 (ldr "
             "x0,[x0,%#llx]) and then +%#llx dead-ends in a block whose first word is itself and "
             "whose rest is zero, so the object container is players+%#llx and nothing is read "
             "past it", (unsigned long long)TNX_V81_PLAYERS_NEXT_OFF,
             (unsigned long long)TNX_V81_PLAYERS_NEXT_OFF,
             (unsigned long long)TNX_V81_NEXT_MEMBER_OFF, (unsigned long long)TNX_MGR_ARRAY_OFF);
}

static void tnx_v85_qword_dump(const char *what, uintptr_t base, int qwords) {
    for (int i = 0; i < qwords; i++) {
        uint64_t word = tnx_v68_word(base + (uintptr_t)i * 8);
        const char *seg = tnx_image_segment_name((uintptr_t)word);

        tnx_logf("v100 %s @%p +%02x = %#018llx seg=%s", what, (void *)base, i * 8,
                 (unsigned long long)word, seg ? seg : "-");
    }
}

static void tnx_v85_ptr_field_dump(const char *tag, uintptr_t object, uintptr_t off, int qwords) {
    void *ptr = NULL;
    int32_t count = 0;
    int32_t cap = 0;
    const char *seg = NULL;
    const char *header = NULL;

    if (!tnx_read_ptr(object + off, &ptr) || !ptr) return;

    seg = tnx_image_segment_name((uintptr_t)ptr);
    header = tnx_v57_header_reason((uintptr_t)ptr, &count, &cap);

    tnx_logf("v100 %s+%#llx = %p seg=%s header=%s count=%d cap=%d - a heap pointer here whose "
             "header passes is another container, which is where the projectiles would live",
             tag, (unsigned long long)off, ptr, seg ? seg : "-", header ? header : "ok", count, cap);

    if (!tnx_heap_resident((uintptr_t)ptr)) return;

    tnx_v85_qword_dump(tag, (uintptr_t)ptr, qwords);
}

static void tnx_v81_vt_note(uintptr_t vt) {
    uintptr_t rva = tnx_v60_strip_ptr(vt);

    if (!rva) return;
    if (!tnx_v77_vtable_is_data(rva)) return;
    if (rva >= g_base) rva -= g_base;

    for (int i = 0; i < g_v81_vt_used; i++) {
        if (g_v81_vt_seen[i] == rva) {
            g_v81_vt_live[i]++;

            return;
        }
    }

    if (g_v81_vt_used >= TNX_V81_VT_MAX) return;

    g_v81_vt_seen[g_v81_vt_used] = rva;
    g_v81_vt_live[g_v81_vt_used] = 1;

    tnx_logf("v100 container vt[%d] rva=%#llx at=%p - the class table every element of this "
             "container carries", g_v81_vt_used, (unsigned long long)rva, (void *)vt);

    g_v81_vt_used++;
}

static int tnx_v81_is_battle_object(uintptr_t object, char *why, size_t whyLen) {
    void *vt = NULL;
    void *def = NULL;
    int32_t gid = 0;
    int32_t team = 0;
    int32_t kind = 0;
    uint8_t dead = 0;

    if (!object) {
        snprintf(why, whyLen, "null");
        return 0;
    }

    if (!tnx_heap_resident(object)) {
        snprintf(why, whyLen, "not-heap");
        return 0;
    }

    if (!tnx_read_ptr(object, &vt) || !vt) {
        snprintf(why, whyLen, "no-vt");
        return 0;
    }

    if (!tnx_v77_vtable_is_data((uintptr_t)vt)) {
        const char *seg = tnx_image_segment_name((uintptr_t)vt);

        snprintf(why, whyLen, "vt-not-data seg=%s", seg ? seg : "-");
        return 0;
    }

    tnx_read_i32(object + TNX_OBJ_GLOBALID_OFF, &gid);
    tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team);
    tnx_read_u8(object + TNX_OBJ_DEADFLAG_OFF, &dead);

    if (!tnx_read_ptr(object + TNX_V82_ELEM_DEF_OFF, &def) || !def) {
        const char *seg = tnx_image_segment_name((uintptr_t)def);

        snprintf(why, whyLen, "no-def at +%#llx seg=%s - 0x382cc8 is ldr x0,[x0,%#llx], the engine "
                 "reaches every element's definition through it and reads the kind there",
                 (unsigned long long)TNX_V82_ELEM_DEF_OFF, seg ? seg : "-",
                 (unsigned long long)TNX_V82_ELEM_DEF_OFF);
        return 0;
    }

    tnx_read_i32((uintptr_t)def + TNX_V79_KIND_OFF, &kind);

    if (gid > 0 && gid < TNX_V75_GID_MAX) {
        snprintf(why, whyLen, "gid=%d team=%d def=%p defKind=%d dead=%d", gid, team, def, kind,
                 dead);
        return 1;
    }

    if (kind <= 0 || kind > TNX_V82_KIND_MAX) {
        snprintf(why, whyLen, "gid=0 and defKind=%d at def+%#llx - no global id on the element and "
                 "no kind on the definition it points to, so nothing here identifies a game "
                 "object", kind, (unsigned long long)TNX_V79_KIND_OFF);
        return 0;
    }

    if (team < 0 || team > TNX_V75_TEAM_MAX) {
        snprintf(why, whyLen, "defKind=%d but team=%d is outside 0..%d", kind, team,
                 TNX_V75_TEAM_MAX);
        return 0;
    }

    snprintf(why, whyLen, "defKind=%d team=%d def=%p dead=%d gid=0 - accepted on the kind the "
             "engine itself reads, at [[element+%#llx]+%#llx]",
             kind, team, def, dead, (unsigned long long)TNX_V82_ELEM_DEF_OFF,
             (unsigned long long)TNX_V79_KIND_OFF);

    return 1;
}

static int tnx_v86_element_type(uintptr_t vt, uintptr_t *wordOut) {
    void *slotPtr = NULL;
    uintptr_t slot = 0;

    if (wordOut) *wordOut = 0;

    if (!vt) return -1;
    if (!tnx_read_ptr(vt + TNX_V86_TYPE_SLOT_OFF, &slotPtr) || !slotPtr) return -1;

    slot = tnx_v60_strip_ptr((uintptr_t)slotPtr) - g_base;

    if (wordOut) *wordOut = slot;

    switch (slot) {
        case 0x0014c81cULL: return 0;
        case 0x00a31768ULL: return 1;
        case 0x009f4ec8ULL: return 2;
        case 0x00314ca0ULL: return 3;
        case 0x00490b54ULL: return 4;
        case 0x0086f494ULL: return 5;
        case 0x00370688ULL: return 6;
        case 0x00490d94ULL: return 8;
        default: return -1;
    }
}

static void tnx_v88_element_full(uintptr_t element, uintptr_t def, uintptr_t container) {
    int32_t intA = 0;
    int32_t intB = 0;
    void *backPtr = NULL;
    int back = 0;

    if (!element) return;

    tnx_read_i32(element + TNX_V88_ELEM_INT_A, &intA);
    tnx_read_i32(element + TNX_V88_ELEM_INT_B, &intB);

    if (tnx_read_ptr(element + TNX_V88_ELEM_BACK_OFF, &backPtr) &&
        (uintptr_t)backPtr == container) {
        back = 1;
    }

    tnx_logf("v100 element full dump elem=%p class=%#llx def=%p container=%p - +0x00..+0x%x as "
             "qwords, then the definition the engine reaches through elem+%#llx over +0x00..+0x%x; "
             "the field that splits the elements into sides is dumped here and not assumed",
             (void *)element, (unsigned long long)TNX_V88_ELEMCLASS_RVA, (void *)def,
             (void *)container, (unsigned)(TNX_V88_ELEM_QWORDS * 8),
             (unsigned long long)TNX_V82_ELEM_DEF_OFF, (unsigned)(TNX_V88_DEF_QWORDS * 8));

    tnx_v85_qword_dump("elemfull", element, TNX_V88_ELEM_QWORDS);

    if (def) tnx_v85_qword_dump("deffull", def, TNX_V88_DEF_QWORDS);

    tnx_logf("v100 element pair elem=%p int32 +%#llx=%d int32 +%#llx=%d back=%d [elem+%#llx]=%p "
             "container=%p - the two int32 are printed as signed integers because those offsets "
             "only ever appeared as raw words", (void *)element,
             (unsigned long long)TNX_V88_ELEM_INT_A, intA,
             (unsigned long long)TNX_V88_ELEM_INT_B, intB, back,
             (unsigned long long)TNX_V88_ELEM_BACK_OFF, backPtr, (void *)container);
}

static void tnx_v81_container_census(uintptr_t array, int32_t count, uintptr_t container) {
    int accepted = 0;
    int typed = 0;
    int types = 0;
    int typeMask = 0;
    int teams = 0;
    int teamMask = 0;
    int gidSeen = 0;
    int classSeen = -1;
    int back = 0;

    if (!array || count <= 0) return;
    if (container == g_v88_census_container) return;

    if (count > TNX_V81_DUMP_QWORDS) count = TNX_V81_DUMP_QWORDS;

    for (int32_t i = 0; i < count; i++) {
        uintptr_t at = array + (uintptr_t)i * sizeof(void *);
        void *element = NULL;
        void *vt = NULL;
        void *def = NULL;
        char why[160] = { 0 };
        char typeText[16] = { 0 };
        uintptr_t classRva = 0;
        uintptr_t typeWord = 0;
        int32_t team = 0;
        int32_t gid = 0;
        int32_t kind = 0;
        int32_t kind68 = 0;
        int32_t teamHyp = 0;
        int32_t byte48 = 0;
        void *backPtr = NULL;
        int elementBack = 0;
        int type = -1;
        int ok = 0;

        if (!tnx_read_ptr(at, &element) || !element) {
            tnx_logf("v100 container elem[%d] at %p unreadable - no verdict from this slot", i,
                     (void *)at);
            continue;
        }

        ok = tnx_v81_is_battle_object((uintptr_t)element, why, sizeof(why));

        tnx_read_ptr((uintptr_t)element, &vt);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);
        tnx_read_i32((uintptr_t)element + TNX_V86_HYP_TEAM_OFF, &teamHyp);
        tnx_read_i32((uintptr_t)element + TNX_V86_HYP_BYTE_OFF, &byte48);
        if (tnx_read_ptr((uintptr_t)element + TNX_V88_ELEM_BACK_OFF, &backPtr) &&
            (uintptr_t)backPtr == container) {
            elementBack = 1;
            back++;
        }
        if (tnx_read_ptr((uintptr_t)element + TNX_V82_ELEM_DEF_OFF, &def) && def) {
            tnx_read_i32((uintptr_t)def + TNX_V79_KIND_OFF, &kind);
            tnx_read_i32((uintptr_t)def + TNX_V86_DEF_68_OFF, &kind68);
        }
        tnx_v81_vt_note((uintptr_t)vt);

        type = tnx_v86_element_type((uintptr_t)vt, &typeWord);

        if (type < 0) snprintf(typeText, sizeof(typeText), "unknown");
        else snprintf(typeText, sizeof(typeText), "%d", type);

        classRva = tnx_v60_strip_ptr((uintptr_t)vt) - g_base;

        if (classSeen < 0) classSeen = (int)classRva;
        else if (classSeen != (int)classRva) classSeen = -2;

        if (i == 0 && type == TNX_V88_TYPE3_CODE) g_v86_type3_floats = 1;

        if (ok) accepted++;

        if (type >= 0) {
            typed++;

            if (type < 32 && !(typeMask & (1 << type))) {
                typeMask |= (1 << type);
                types++;
            }
        }

        if (teamHyp >= 0 && teamHyp < TNX_V77_TEAM_SLOTS && !(teamMask & (1 << teamHyp))) {
            teamMask |= (1 << teamHyp);
            teams++;
        }

        if (gid > 0) gidSeen++;

        tnx_logf("v100 container elem[%d] at %p vt=%p classRva=%#llx type=%s typeWord=%#llx def=%p "
                 "def35c=%d def68=%d | gid8=%d team40=%d team4c=%d byte48=%d | back=%d accept=%d "
                 "(%s)", i, (void *)element, vt, (unsigned long long)classRva, typeText,
                 (unsigned long long)typeWord, def, kind, kind68, gid, team, teamHyp, byte48,
                 elementBack, ok, why);

        if (type == TNX_V88_TYPE3_CODE) {
            float f10 = 0.0f;
            float f1c = 0.0f;
            float f100 = 0.0f;
            float f104 = 0.0f;

            tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_LO, &f10);
            tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_LO2, &f1c);
            tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_HI, &f100);
            tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_HI2, &f104);

            tnx_logf("v100 container elem[%d] as floats +%#llx=%.4f +%#llx=%.4f +%#llx=%.4f "
                     "+%#llx=%.4f - classRva is %#llx, whose own table exposes exactly these four "
                     "as float getters in slots 0x1b0/0x1b8 and 0x1c8/0x1d0, so a pair among them "
                     "is the coordinate pair", i, (unsigned long long)TNX_V87_FLOAT_LO, f10,
                     (unsigned long long)TNX_V87_FLOAT_LO2, f1c,
                     (unsigned long long)TNX_V87_FLOAT_HI, f100,
                     (unsigned long long)TNX_V87_FLOAT_HI2, f104,
                     (unsigned long long)TNX_V86_TYPE3_CLASS_RVA);
        }

        if (g_v86_elem_dumps < TNX_V86_ELEM_DUMPS) {
            g_v86_elem_dumps++;

            tnx_logf("v100 element head dump elem=%p vt=%p type=%s - +0x00..+0x%x, so the log shows "
                     "whether +%#llx holds a definition pointer that makes def35c and def68 "
                     "readable, or a float pair that means this is not a game object at all",
                     (void *)element, vt, typeText, (unsigned)(TNX_V86_ELEM_QWORDS * 8),
                     (unsigned long long)TNX_V82_ELEM_DEF_OFF);

            tnx_v85_qword_dump("elem", (uintptr_t)element, TNX_V86_ELEM_QWORDS);

            if (type == TNX_V88_TYPE3_CODE) {
                float h10 = 0.0f;
                float h1c = 0.0f;
                float h100 = 0.0f;
                float h104 = 0.0f;

                tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_LO, &h10);
                tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_LO2, &h1c);
                tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_HI, &h100);
                tnx_read_f32((uintptr_t)element + TNX_V87_FLOAT_HI2, &h104);

                tnx_logf("v100 element head floats elem=%p +%#llx=%.4f +%#llx=%.4f +%#llx=%.4f "
                         "+%#llx=%.4f - the same element as the qwords above, read as single "
                         "precision, which is the form type %d's own getters use; this line is "
                         "printed for type %d only, because for any other type +%#llx is the "
                         "definition pointer and not a float", (void *)element,
                         (unsigned long long)TNX_V87_FLOAT_LO, h10,
                         (unsigned long long)TNX_V87_FLOAT_LO2, h1c,
                         (unsigned long long)TNX_V87_FLOAT_HI, h100,
                         (unsigned long long)TNX_V87_FLOAT_HI2, h104, TNX_V88_TYPE3_CODE,
                         TNX_V88_TYPE3_CODE, (unsigned long long)TNX_V82_ELEM_DEF_OFF);
            }
        }

        if (classRva == TNX_V88_ELEMCLASS_RVA && g_v88_elem_full_dumps < TNX_V88_ELEM_DUMPS) {
            g_v88_elem_full_dumps++;

            tnx_v88_element_full((uintptr_t)element, (uintptr_t)def, container);
        }
    }

    g_v81_census_logs++;
    g_v88_census_container = container;

    tnx_logf("v100 container census hop=%d container=%p typed=%d of %d types=%d typeMask=%#x "
             "teamsHyp=%d gidSeen=%d back=%d of %d oldAccept=%d classRva=%#llx - the type is the "
             "engine's own discriminator, the word at [vt+%#llx] matched against the getters "
             "0x14c81c/0xa31768/0x9f4ec8/0x314ca0/0x490b54/0x86f494/0x370688/0x490d94, so an "
             "element whose slot is not in that list is printed as type=unknown with its raw word "
             "instead of being rejected; the id is read at +%#llx and the +0x50 word is gone from "
             "the code and from this line, and back counts the elements whose +%#llx names this "
             "very container", g_v82_hop_chosen, (void *)container, typed, count, types,
             (unsigned)typeMask, teams, gidSeen, back, count, accepted,
             (unsigned long long)(classSeen < 0 ? 0 : classSeen),
             (unsigned long long)TNX_V86_TYPE_SLOT_OFF,
             (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_V88_ELEM_BACK_OFF);
}

static void tnx_v81_scene_reset(const char *why) {
    if (!g_scene_object && !g_players_object && !g_players_array && !g_players_count &&
        !g_players_cap) {
        return;
    }

    tnx_logf("v100 scene reset (%s): scene=%p players=%p array=%p count=%d cap=%d - the five chain "
             "globals move together with the hop choice, so a second battle cannot inherit the "
             "first battle's container or its sticky hop", why ? why : "?", (void *)g_scene_object,
             (void *)g_players_object, (void *)g_players_array, g_players_count, g_players_cap);

    g_scene_object = 0;
    g_players_object = 0;
    g_players_array = 0;
    g_players_count = 0;
    g_players_cap = 0;
    g_v82_hop_sticky = 0;
    g_v82_hop_chosen = -1;
    g_v86_hop2_census = 0;
    g_v88_census_container = 0;
    g_v88_elem_full_dumps = 0;
    g_v88_walk_relogs = 0;
    g_v89_walk_count = -1;
    g_v89_walk_tick = 0;
    g_v90_slot_dumped = 0;
    g_v91_own_ptr = 0;
    g_v91_own_index = -1;
    g_v91_own_src = -1;
    g_v91_own_off = 0;
    g_v91_scan_container = 0;
    g_v91_scan_logs = 0;
    g_v91_own_logged = 0;
    g_v91_own_from = "none";
    g_manager_count = 0;
    g_v81_vt_used = 0;
    g_v81_census_logs = 0;
    g_v81_players_dumps = 0;
    g_v56_capture_done = 0;
    g_v56_array_logged = 0;
    g_v56_walk_last = -1;
    g_v57_cand_this = 0;
    g_v57_cand_vt = 0;
    g_v57_cand_ticks = 0;
    g_v57_stale_ticks = 0;

    memset(g_v81_vt_live, 0, sizeof(g_v81_vt_live));
}

static void tnx_v81_alert_edge(uintptr_t scene, uintptr_t players, int32_t count, int32_t state) {
    int have = scene ? 1 : 0;

    if (have && !g_v81_prev_have_scene && state == TNX_V80_STATE_BATTLE && !g_v62_alerts_off) {
        NSString *info = [NSString stringWithFormat:
            @"scene=%p players=%p count=%d\nstate=%d slot=%p", (void *)scene, (void *)players,
            count, state, (void *)g_v80_site];

        tnx_logf("v100 scene-mode-appeared scene=%p players=%p count=%d state=%d - the edge is the "
                 "scene pointer going from null to non-null at state==%d, read from the engine's "
                 "own global, so every new battle raises its own alert",
                 (void *)scene, (void *)players, count, state, TNX_V80_STATE_BATTLE);

        tnx_v62_alert_menu(info);
    }

    g_v81_prev_have_scene = have;
}

static uintptr_t g_v82_hop_scene = 0;

static int tnx_v82_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut,
                                    int32_t *capOut, char *why, size_t whyLen) {
    const char *reason = NULL;
    void *array = NULL;

    if (arrayOut) *arrayOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;

    if (!object) {
        snprintf(why, whyLen, "null");
        return 0;
    }

    reason = tnx_v57_header_reason(object, countOut, capOut);

    if (reason) {
        snprintf(why, whyLen, "%s", reason);
        return 0;
    }

    if (!tnx_read_ptr(object + TNX_MGR_ARRAY_OFF, &array) || !array) {
        snprintf(why, whyLen, "array-null");
        return 0;
    }

    if (!tnx_heap_resident((uintptr_t)array)) {
        snprintf(why, whyLen, "array-not-heap");
        return 0;
    }

    if (arrayOut) *arrayOut = (uintptr_t)array;

    snprintf(why, whyLen, "ok array=%p count=%d cap=%d", array,
             countOut ? *countOut : 0, capOut ? *capOut : 0);

    return 1;
}

static void tnx_v82_hop_dump(uintptr_t client, uintptr_t inner) {
    struct {
        const char *what;
        uintptr_t object;
    } hop[TNX_V82_HOPS] = { { 0, 0 }, { 0, 0 } };

    if (g_v82_hop_dumps >= TNX_V82_HOP_DUMPS) return;

    g_v82_hop_dumps++;

    hop[0].what = "client scene+0x28";
    hop[0].object = client;
    hop[1].what = "inner client+0x28";
    hop[1].object = inner;

    for (int h = 0; h < TNX_V82_HOPS; h++) {
        void *vt = NULL;
        int32_t count = 0;
        int32_t cap = 0;
        const char *reason = NULL;

        if (!hop[h].object) continue;

        tnx_read_ptr(hop[h].object, &vt);

        reason = tnx_v57_header_reason(hop[h].object, &count, &cap);

        tnx_logf("v100 hopdump %s object=%p vt=%p seg=%s header=%s count=%d cap=%d - the two hops "
                 "differ by exactly one +%#llx dereference, so the vt tells which of them is a "
                 "heterogeneous client and which is a container",
                 hop[h].what, (void *)hop[h].object, vt,
                 tnx_image_segment_name((uintptr_t)vt), reason ? reason : "ok", count, cap,
                 (unsigned long long)TNX_V82_CLIENT_HOP_OFF);

        for (int i = 0; i < 16; i++) {
            uintptr_t at = hop[h].object + (uintptr_t)i * 8;
            uint64_t word = tnx_v68_word(at);
            const char *seg = tnx_image_segment_name((uintptr_t)word);

            tnx_logf("v100 hopdump %s +%02x = %#018llx seg=%s", hop[h].what, i * 8,
                     (unsigned long long)word, seg ? seg : "-");
        }
    }
}

static int32_t tnx_v106_gid(uintptr_t element, int32_t *offOut);

static uintptr_t g_v108_owner = 0;
static int g_v109_done = 0;
static uintptr_t g_v110_owner = 0;
static int g_v110_wired = 0;

static void tnx_v109_owner_probe(uintptr_t client, uintptr_t inner) {
    uintptr_t cand[TNX_V109_MAX];
    int freq[TNX_V109_MAX];
    int32_t cnt[TNX_V109_MAX];
    int32_t cap[TNX_V109_MAX];
    uintptr_t vt0[TNX_V109_MAX];
    void *elem0p[TNX_V109_MAX];
    int comb[TNX_V109_MAX];
    int rank[TNX_V109_MAX];
    char why[TNX_V109_MAX][64];
    int nc = 0;
    int badptr = 0;
    int best = -1;
    int i;
    int j;
    int k;

    if (g_v109_done) return;
    if (!g_objhit_count) return;

    g_v109_done = 1;

    for (i = 0; i < g_objhit_count; i++) {
        uintptr_t owner = g_objhits[i].owner;

        if (!owner) continue;

        if (owner < 0x100000000ULL || owner >= 0x800000000ULL) {
            badptr++;
            continue;
        }

        for (j = 0; j < nc; j++) {
            if (cand[j] == owner) break;
        }

        if (j < nc) {
            freq[j]++;
            continue;
        }

        if (nc >= TNX_V109_MAX) continue;

        cand[nc] = owner;
        freq[nc] = 1;
        cnt[nc] = 0;
        cap[nc] = 0;
        vt0[nc] = 0;
        comb[nc] = 0;
        elem0p[nc] = NULL;
        why[nc][0] = 0;
        nc++;
    }

    for (j = 0; j < nc; j++) {
        uintptr_t array = 0;
        int32_t count = 0;
        int32_t capacity = 0;
        void *elem0 = NULL;
        void *vt = NULL;
        int combat = 0;
        int e;
        int ok = tnx_v82_container_header(cand[j], &array, &count, &capacity, why[j], sizeof(why[j]));

        cnt[j] = count;
        cap[j] = capacity;

        if (ok) {
            for (e = 0; e < 3; e++) {
                void *ep = NULL;
                void *vtp = NULL;

                if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)e * 8ULL, &ep) || !ep) continue;
                if (!tnx_read_ptr((uintptr_t)ep, &vtp) || !vtp) continue;

                if (e == 0) {
                    elem0 = ep;
                    vt = vtp;
                    vt0[j] = (uintptr_t)vtp - g_base;
                }

                if ((uintptr_t)vtp - g_base == TNX_V109_COMBAT_VT_A ||
                    (uintptr_t)vtp - g_base == TNX_V109_COMBAT_VT_B ||
                    (uintptr_t)vtp - g_base == TNX_V109_COMBAT_VT_C) combat = 1;
            }

            if (vt0[j] == TNX_V109_PROXY_VT) {
                ok = 0;
                snprintf(why[j], sizeof(why[j]), "proxy-class-veto");
            } else if (vt0[j] == TNX_V109_SELFREF_VT) {
                ok = 0;
                snprintf(why[j], sizeof(why[j]), "selfref-class-veto");
            } else {
                snprintf(why[j], sizeof(why[j]), "ok combat=%d", combat);
            }
        }

        comb[j] = combat;
        elem0p[j] = elem0;

        if (ok) {
            if (best < 0) best = j;
            else if (freq[j] > freq[best]) best = j;
            else if (freq[j] == freq[best] && combat > 0) best = j;
        }
    }

    for (j = 0; j < nc; j++) rank[j] = j;

    for (j = 0; j + 1 < nc; j++) {
        for (k = 0; k + 1 < nc - j; k++) {
            if (freq[rank[k]] < freq[rank[k + 1]]) {
                int t = rank[k];

                rank[k] = rank[k + 1];
                rank[k + 1] = t;
            }
        }
    }

    for (j = 0; j < nc && j < 4; j++) {
        uintptr_t owner = cand[rank[j]];
        int chain = (owner == client || owner == inner || owner == (uintptr_t)g_players_object) ? 1 : 0;

        tnx_logf("v108 ownerprobe %s: owner=%p freq=%d/%d header=%s count=%d cap=%d elem0vt=%#llx "
                 "chain-match=%d found-via=objhit badptr=%d - the owner is chosen by how often the live "
                 "battle objects name it and not by which candidate passed the header first",
                 (j == 0) ? "top" : "runner-up", (void *)owner, freq[rank[j]], g_objhit_count,
                 why[rank[j]], cnt[rank[j]], cap[rank[j]], (unsigned long long)vt0[rank[j]], chain,
                 badptr);
    }

    if (best >= 0) {
        const char *wireWhy = (const char *)"not-wired";
        void *wireArray = NULL;
        int32_t wireCount = 0;
        int wire = 0;

        g_v108_owner = cand[best];

        if (!tnx_read_ptr(cand[best] + TNX_MGR_ARRAY_OFF, &wireArray)) wireArray = NULL;
        if (!tnx_read_i32(cand[best] + TNX_MGR_COUNT_OFF, &wireCount)) wireCount = 0;

        if (!TNX_V110_WIRE_OWNER) wireWhy = (const char *)"flag-off";
        else if (!comb[best]) wireWhy = (const char *)"not-combat-class";
        else if (!elem0p[best]) wireWhy = (const char *)"elem0-null";
        else if (cnt[best] < TNX_V110_WIRE_MIN_COUNT) wireWhy = (const char *)"count-below-floor";
        else if (!wireArray) wireWhy = (const char *)"array-null";
        else if (wireCount <= 0) wireWhy = (const char *)"count-unreadable";
        else wire = 1;

        if (wire) {
            g_v110_owner = cand[best];

            tnx_logf("v109 owner wired into walk owner=%p count-at-probe=%d count-at-wire=%d cap=%d array=%p "
                     "elem0=%p elem0vt=%#llx - the owner that ownerprobe picked is written into the walk globals "
                     "in this same run and the hop selection is marked %d so the chain cannot overwrite it",
                     (void *)cand[best], cnt[best], wireCount, cap[best], wireArray, elem0p[best],
                     (unsigned long long)vt0[best], TNX_V110_HOPCHOSEN_DIRECT);
        } else {
            tnx_logf("v109 owner NOT wired reason=%s owner=%p comb=%d count-at-probe=%d count-at-wire=%d "
                     "elem0=%p elem0vt=%#llx - the walk stays on the hop path for this run and the ownerprobe "
                     "table above is what to read",
                     wireWhy, (void *)cand[best], comb[best], cnt[best], wireCount, elem0p[best],
                     (unsigned long long)vt0[best]);
        }
    }
}

static int g_v107_cand_logs = 0;
static int g_v107_scan_logs = 0;
static int g_v107_deref_logs = 0;

static void tnx_v112_deref_dump(uintptr_t element) {
    void *inner = NULL;
    void *vt = NULL;
    uintptr_t vtRva = 0;
    uint64_t raw40 = 0;
    float fx = 0.0f;
    float fy = 0.0f;
    float f2x = 0.0f;
    float f2y = 0.0f;
    float gx = 0.0f;
    float gy = 0.0f;
    int gxOk = 0;
    int gyOk = 0;
    int i;

    if (!element) return;
    if (g_v107_deref_logs >= 4) return;

    g_v107_deref_logs++;

    if (tnx_read_ptr(element, &vt) && vt) vtRva = (uintptr_t)vt - g_base;

    tnx_read_f32(element + TNX_V112_POS_X_OFF, &fx);
    tnx_read_f32(element + TNX_V112_POS_Y_OFF, &fy);
    tnx_read_f32(element + TNX_V112_POS2_X_OFF, &f2x);
    tnx_read_f32(element + TNX_V112_POS2_Y_OFF, &f2y);

    if (vtRva == TNX_V112_ELEM_VT_RVA) {
        void *fn = NULL;

        if (tnx_read_ptr((uintptr_t)vt + TNX_V112_GETX_SLOT, &fn) && fn) {
            gx = ((float (*)(void *))fn)((void *)element);
            gxOk = 1;
        }

        fn = NULL;

        if (tnx_read_ptr((uintptr_t)vt + TNX_V112_GETY_SLOT, &fn) && fn) {
            gy = ((float (*)(void *))fn)((void *)element);
            gyOk = 1;
        }
    }

    raw40 = tnx_v68_word(element + (uintptr_t)TNX_V112_ELEM40_OFF);

    tnx_logf("v112 elem pos elem=%p vtRva=%#llx f10=%.4f f1c=%.4f f20=%.4f f24=%.4f getX=%.4f getY=%.4f "
             "getXOk=%d getYOk=%d q40=%#018llx - the class table slots at +%#llx and +%#llx are ldr s0 "
             "from +%#llx and +%#llx, so this class keeps its position as floats and the int pair the "
             "walk reads at +%#llx/+%#llx is zero by design and never was the coordinate",
             (void *)element, (unsigned long long)vtRva, fx, fy, f2x, f2y, gx, gy, gxOk, gyOk,
             (unsigned long long)raw40, (unsigned long long)TNX_V112_GETX_SLOT,
             (unsigned long long)TNX_V112_GETY_SLOT, (unsigned long long)TNX_V112_POS_X_OFF,
             (unsigned long long)TNX_V112_POS_Y_OFF, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF);

    if (!tnx_read_ptr(element + TNX_V112_INNER_OFF, &inner) || !inner) {
        tnx_logf("v112 deref elem=%p +%#llx is null or unreadable - the own element keeps nothing behind "
                 "that pointer", (void *)element, (unsigned long long)TNX_V112_INNER_OFF);

        return;
    }

    tnx_logf("v112 deref elem=%p inner=+%#llx->%p qwords=%d - the dump is widened from sixteen words to "
             "sixty four because a float pair past the first sixteen is what the earlier run could not "
             "see", (void *)element, (unsigned long long)TNX_V112_INNER_OFF, inner,
             TNX_V112_DEREF_QWORDS);

    for (i = 0; i < TNX_V112_DEREF_QWORDS; i++) {
        uint64_t q = tnx_v68_word((uintptr_t)inner + (uintptr_t)i * 8ULL);
        uint32_t lo = (uint32_t)(q & 0xffffffffULL);
        uint32_t hi = (uint32_t)(q >> 32);
        float loF = 0.0f;
        float hiF = 0.0f;

        memcpy(&loF, &lo, sizeof(loF));
        memcpy(&hiF, &hi, sizeof(hiF));

        tnx_logf("v112 deref +%#04x = %#018llx lo=%d hi=%d loF=%.3f hiF=%.3f", i * 8,
                 (unsigned long long)q, (int32_t)lo, (int32_t)hi, loF, hiF);
    }
}

static void tnx_v107_cand_probe(const char *tag, uintptr_t container) {
    void *array = NULL;
    int32_t count = 0;
    int32_t own = -1;
    int32_t ownTeam = -1;
    uintptr_t vt0 = 0;
    uintptr_t vt1 = 0;
    int samples = 0;
    int gidOk = 0;
    int teamOk = 0;
    int coordOk = 0;
    int i;

    if (!container) return;
    if (g_v107_cand_logs >= 24) return;

    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) {
        g_v107_cand_logs++;

        tnx_logf("v107 cand tag=%-8s at=%p array=+%#llx is null - the candidate carries no list at all",
                 tag, (void *)container, (unsigned long long)TNX_MGR_ARRAY_OFF);

        return;
    }

    tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count);
    tnx_read_i32(container + TNX_V102_OWNIDX_OFF, &own);
    tnx_read_i32(container + TNX_V102_OWNTEAM_OFF, &ownTeam);

    for (i = 0; i < count && i < 6; i++) {
        void *element = NULL;
        void *vtable = NULL;
        int32_t gid = 0;
        int32_t team = 0;
        int32_t x = 0;
        int32_t y = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        samples++;

        if (tnx_read_ptr((uintptr_t)element, &vtable) && vtable) {
            if (i == 0) vt0 = (uintptr_t)vtable - g_base;
            if (i == 1) vt1 = (uintptr_t)vtable - g_base;
        }

        gid = tnx_v106_gid((uintptr_t)element, NULL);
        tnx_read_i32((uintptr_t)element + TNX_V91_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &x);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &y);

        if (gid) gidOk++;
        if (team >= 0 && team <= 7) teamOk++;
        if (x > -TNX_V47_COORD_ABS_MAX && x < TNX_V47_COORD_ABS_MAX &&
            y > -TNX_V47_COORD_ABS_MAX && y < TNX_V47_COORD_ABS_MAX) coordOk++;
    }

    g_v107_cand_logs++;

    tnx_logf("v107 cand tag=%-8s at=%p array=%p count=%d own=%d ownTeam=%d samples=%d gidOk=%d teamOk=%d "
             "coordOk=%d vt0=%#llx vt1=%#llx ownSlot=%s - every candidate is reported and not only the "
             "winner, so a list that carries real coordinates and real teams can be told apart from the "
             "slot table that carries only the own index",
             tag, (void *)container, array, count, own, ownTeam, samples, gidOk, teamOk, coordOk,
             (unsigned long long)vt0, (unsigned long long)vt1,
             (own >= 0 && own < count) ? "valid" : "invalid");
}

static void tnx_v107_coord_scan(uintptr_t container) {
    void *array = NULL;
    void *e0 = NULL;
    void *e1 = NULL;
    int32_t count = 0;
    char buf[256];
    size_t used = 0;
    int found = 0;
    int gidPairOnly = 1;
    int off;

    if (!container) return;
    if (g_v107_scan_logs >= 8) return;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count) || count < 2) return;
    if (!tnx_read_ptr((uintptr_t)array, &e0) || !e0) return;
    if (!tnx_read_ptr((uintptr_t)array + 8ULL, &e1) || !e1) return;

    buf[0] = 0;

    for (off = TNX_V107_SCAN_FROM; off + 4 <= TNX_V107_SCAN_TO; off += 4) {
        int32_t a = 0;
        int32_t b = 0;

        if (!tnx_read_i32((uintptr_t)e0 + (uintptr_t)off, &a)) continue;
        if (!tnx_read_i32((uintptr_t)e1 + (uintptr_t)off, &b)) continue;
        if (a == b) continue;
        if (a < 0 || a > 10000 || b < 0 || b > 10000) continue;
        if (found >= TNX_V107_SCAN_MAX) break;

        if (off != (int)TNX_OBJ_GLOBALID_OFF && off != (int)TNX_V106_GID_FALLBACK_OFF &&
            off != (int)TNX_V112_INDEX_OFF && off != (int)TNX_V112_TEAM_OFF2 &&
            off != (int)TNX_V112_DEAD_OFF && off != (int)TNX_V102_OWNIDX_OFF &&
            off != (int)TNX_V102_OWNTEAM_OFF) gidPairOnly = 0;

        found++;
        used += (size_t)snprintf(buf + used, sizeof(buf) - used, "(%#x,%d,%d)", off, a, b);
        if (used >= sizeof(buf) - 48) break;
    }

    g_v107_scan_logs++;

    tnx_logf("v112 coord scan container=%p elem0=%p elem1=%p pairs=%d gidPairOnly=%d [%s] - the index at "
             "+%#x, the team at +%#x, the dead byte at +%#x and the own pair at +%#x/+%#x are counted as "
             "known non coordinate fields now, because a slot index of 0..5 differs between two elements "
             "and used to clear gidPairOnly on its own, so the earlier scan reported (0x48,0,1) as a "
             "candidate pair while only the id slots at +%#llx/+%#llx remain as ids",
             (void *)container, e0, e1, found, gidPairOnly, buf,
             (unsigned)TNX_V112_INDEX_OFF, (unsigned)TNX_V112_TEAM_OFF2, (unsigned)TNX_V112_DEAD_OFF,
             (unsigned)TNX_V102_OWNIDX_OFF, (unsigned)TNX_V102_OWNTEAM_OFF,
             (unsigned long long)TNX_OBJ_GLOBALID_OFF, (unsigned long long)TNX_V106_GID_FALLBACK_OFF);
}

static int g_v106_gid_logs = 0;
static int g_v106_coord_logs = 0;
static int g_v106_dump_done = 0;

static int32_t tnx_v106_gid(uintptr_t element, int32_t *offOut) {
    int32_t gid = 0;
    int32_t alt = 0;

    if (offOut) *offOut = 0;
    if (!element) return 0;

    if (tnx_read_i32(element + TNX_OBJ_GLOBALID_OFF, &gid) && gid) {
        if (offOut) *offOut = (int32_t)TNX_OBJ_GLOBALID_OFF;

        return gid;
    }

    if (tnx_read_i32(element + TNX_V106_GID_FALLBACK_OFF, &alt) && alt) {
        if (offOut) *offOut = (int32_t)TNX_V106_GID_FALLBACK_OFF;

        if (g_v106_gid_logs < 6) {
            void *vtable = NULL;
            uintptr_t vtRva = 0;

            g_v106_gid_logs++;

            if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - g_base;

            tnx_logf("v106 gid fallback element=%p vtRva=%#llx +%#llx=0 +%#llx=%d - the walk used to "
                     "reject this row as rejGidZero by reading the wrong field, so every usable count "
                     "came out short",
                     (void *)element, (unsigned long long)vtRva,
                     (unsigned long long)TNX_OBJ_GLOBALID_OFF,
                     (unsigned long long)TNX_V106_GID_FALLBACK_OFF, alt);
        }

        return alt;
    }

    return 0;
}

static void tnx_v106_own_dump(uintptr_t element) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int i;

    if (!element || g_v106_dump_done) return;

    g_v106_dump_done = 1;

    if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - g_base;

    tnx_logf("v106 own dump elem=%p vtRva=%#llx - raw qwords of the own element, because this class "
             "keeps its id at +%#llx and not at +%#llx, so the walk can no longer assume that the "
             "coordinate pair sits at +%#llx/+%#llx either; a pair of small integers in the same "
             "neighbourhood is the pair to use",
             (void *)element, (unsigned long long)vtRva,
             (unsigned long long)TNX_V106_GID_FALLBACK_OFF, (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

    for (i = 0; i < 13; i++) {
        uint64_t q = tnx_v68_word(element + (uintptr_t)i * 8ULL);
        uint32_t lo = (uint32_t)(q & 0xffffffffULL);
        uint32_t hi = (uint32_t)(q >> 32);
        float loF = 0.0f;
        float hiF = 0.0f;

        memcpy(&loF, &lo, sizeof(loF));
        memcpy(&hiF, &hi, sizeof(hiF));

        tnx_logf("v106 own dump +%#04x = %#018llx lo=%d hi=%d loF=%.3f hiF=%.3f", i * 8,
                 (unsigned long long)q, (int32_t)lo, (int32_t)hi, loF, hiF);
    }

    tnx_v112_deref_dump(element);
}

static void tnx_v106_cand_dump(uintptr_t c0, uintptr_t c1, int s0, int s1, int chosen) {
    int32_t n0 = 0;
    int32_t o0 = -1;
    int32_t n1 = 0;
    int32_t o1 = -1;

    if (c0) {
        tnx_read_i32(c0 + TNX_MGR_COUNT_OFF, &n0);
        tnx_read_i32(c0 + TNX_V102_OWNIDX_OFF, &o0);
    }

    if (c1) {
        tnx_read_i32(c1 + TNX_MGR_COUNT_OFF, &n1);
        tnx_read_i32(c1 + TNX_V102_OWNIDX_OFF, &o1);
    }

    tnx_logf("v106 hop candidates chosen=%d score0=%d score1=%d count0=%d own0=%d count1=%d own1=%d - "
             "both hops are printed while the chosen list is short, because a container with a larger "
             "count and a valid own slot is the one the hop has to prefer",
             chosen, s0, s1, n0, o0, n1, o1);
}

static int g_v105_score_logs = 0;
static int g_v105_last_choice = -2;
static int g_v105_hop_logs = 0;
static int g_v105_start_logged = 0;

static int tnx_v105_container_score(uintptr_t container) {
    void *array = NULL;
    int32_t count = 0;
    int32_t own = -1;
    int32_t ownTeam = -1;
    int32_t gid = 0;
    int32_t team = 0;
    int samples = 0;
    int gidOk = 0;
    int teamOk = 0;
    int score = 0;
    int i;

    if (!container) return -1;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > TNX_V56_COUNT_MAX) return -1;
    if (!tnx_read_i32(container + TNX_V102_OWNIDX_OFF, &own)) return -1;

    tnx_read_i32(container + TNX_V102_OWNTEAM_OFF, &ownTeam);

    if (own < 0 || own >= count) return -1;

    score = 6;

    if (ownTeam >= 0 && ownTeam <= 15) score += 2;

    for (i = 0; i < count && samples < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        samples++;
        team = 0;
        gid = tnx_v106_gid((uintptr_t)element, NULL);
        tnx_read_i32((uintptr_t)element + TNX_V91_TEAM_OFF, &team);
        if (gid) gidOk++;
        if (team >= 0 && team <= 7) teamOk++;
    }

    if (gidOk) score += 3;
    if (teamOk) score += 1;
    if (count >= 3) score += 2;
    if (count >= 6) score += 2;

    if (g_v105_score_logs < 12) {
        g_v105_score_logs++;

        tnx_logf("v105 score container=%p array=%p count=%d own=%d ownTeam=%d gidOk=%d teamOk=%d "
                 "samples=%d score=%d - a container only counts as the player list while its own slot "
                 "is a valid index into its own array, the same field the engine indexes at rva "
                 "0xac3910, so a list whose +0xe0 is garbage can never win the hop",
                 (void *)container, array, count, own, ownTeam, gidOk, teamOk, samples, score);
    }

    return score;
}

static int tnx_v105_own_verdict(uintptr_t element, char *why, size_t whyLen) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int32_t gid = 0;
    int32_t x = 0;
    int32_t y = 0;
    int32_t teamOld = 0;
    int32_t teamNew = 0;
    uint8_t dead = 0;

    if (why) why[0] = 0;
    if (!element) {
        if (why) snprintf(why, whyLen, "null");
        return 0;
    }

    if (tnx_v75_element_ascii(element)) {
        if (why) snprintf(why, whyLen, "ascii");
        return 0;
    }

    if (!tnx_read_ptr(element, &vtable) || !vtable) {
        if (why) snprintf(why, whyLen, "noVtRead");
        return 0;
    }

    vtRva = (uintptr_t)vtable - g_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        if (why) snprintf(why, whyLen, "vtOutsideImage vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    gid = tnx_v106_gid(element, NULL);

    if (!tnx_read_i32(element + tnx_v57_coord_x_off(), &x) ||
        !tnx_read_i32(element + tnx_v57_coord_y_off(), &y) ||
        !tnx_read_i32(element + TNX_OBJ_TEAM_OFF, &teamOld) ||
        !tnx_read_i32(element + TNX_V91_TEAM_OFF, &teamNew) ||
        !tnx_read_u8(element + TNX_OBJ_DEADFLAG_OFF, &dead)) {
        if (why) snprintf(why, whyLen, "unreadable vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    if (x <= -TNX_V47_COORD_ABS_MAX || x >= TNX_V47_COORD_ABS_MAX ||
        y <= -TNX_V47_COORD_ABS_MAX || y >= TNX_V47_COORD_ABS_MAX) {
        if (why) snprintf(why, whyLen, "coordsOutOfRange gid=%d pos=(%d,%d)", gid, x, y);
        return 0;
    }

    if (why) {
        snprintf(why, whyLen, "ok gid=%d pos=(%d,%d) t40=%d t4c=%d dead=%d gidZeroTaken=%d",
                 gid, x, y, teamOld, teamNew, dead, gid ? 0 : 1);
    }

    return 1;
}

static int tnx_v80_state_tick(void) {
    uintptr_t slot = (uintptr_t)tnx_read_global_ptr(TNX_V80_STATE_RVA);
    int32_t state = -1;
    void *value = NULL;
    uintptr_t scene = 0;
    uintptr_t client = 0;
    uintptr_t inner = 0;
    uintptr_t players = 0;
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    uintptr_t hopArray[TNX_V82_HOPS] = { 0 };
    int32_t hopCount[TNX_V82_HOPS] = { 0 };
    int32_t hopCap[TNX_V82_HOPS] = { 0 };
    int hopOk[TNX_V82_HOPS] = { 0 };
    int score[TNX_V82_HOPS];
    char hopWhy[TNX_V82_HOPS][96] = { { 0 } };
    int chosen = -1;

    if (slot) tnx_read_i32(slot + TNX_V80_STATE_ENUM_OFF, &state);

    if (slot != g_v80_site || state != g_v80_state) {
        tnx_v103_state_note(state);
        tnx_logf("v100 state slot=%p state=%d - the engine loads this word in 0x8cdfd4, tests "
                 "[slot+%#llx] against %d in 0x8c5130 and only then returns [slot+%#llx]; the "
                 "state that passes that test is the one in which the engine itself calls the "
                 "object the battle scene", (void *)slot, state,
                 (unsigned long long)TNX_V80_STATE_ENUM_OFF, TNX_V80_STATE_BATTLE,
                 (unsigned long long)TNX_V80_SCENE_OFF);

        g_v80_site = slot;
        g_v80_state = state;

        tnx_v81_global_dump(slot);
    }

    if (!slot) return 0;

    if (state != TNX_V80_STATE_BATTLE) {
        tnx_v81_scene_reset("state-left-battle");
        tnx_v81_alert_edge(0, 0, 0, state);

        return 0;
    }

    if (!tnx_read_ptr(slot + TNX_V80_SCENE_OFF, &value) || !value) return 0;

    scene = (uintptr_t)value;

    if (scene != g_scene_object) {
        tnx_v81_scene_reset("scene-changed");
        g_scene_object = scene;

        tnx_logf("v100 scene=%p from slot+%#llx at state=%d - the screen factory 0x8ce048 builds "
                 "state %d as new(0x98) plus the constructor 0x8c51f8, which stores %#llx at [+0], "
                 "so this object IS the battle screen and its own slot +0xb0 logs \"No battle "
                 "client\" when [+%#llx] is null; the client is therefore scene+%#llx, one hop "
                 "above the object container",
                 (void *)scene, (unsigned long long)TNX_V80_SCENE_OFF, state,
                 TNX_V80_STATE_BATTLE, (unsigned long long)TNX_V81_SCENE_CLASS_RVA,
                 (unsigned long long)TNX_MODE_MANAGER_OFF,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);

        tnx_v81_scene_dump(scene);
    }

    if (!tnx_read_ptr(scene + TNX_MODE_MANAGER_OFF, &value) || !value) {
        tnx_logf("v100 scene+%#llx holds no battle client at state=%d - the pointer is read again "
                 "next tick and the scene is kept, because the engine's global is the authority "
                 "and a null here is a not-yet-filled field, not a wrong scene",
                 (unsigned long long)TNX_MODE_MANAGER_OFF, state);

        tnx_v81_alert_edge(scene, 0, 0, state);

        return 1;
    }

    client = (uintptr_t)value;

    if (!tnx_read_ptr(client + TNX_V82_CLIENT_HOP_OFF, &value) || !value) {
        tnx_logf("v100 client=%p carries no pointer at +%#llx yet - that field is what "
                 "findOwningTeam 0xac3ddc dereferences before it walks anything, so the second "
                 "hop is retried next tick rather than filled in from the client's own fields",
                 (void *)client, (unsigned long long)TNX_V82_CLIENT_HOP_OFF);

        tnx_v81_alert_edge(scene, client, 0, state);

        return 1;
    }

    inner = (uintptr_t)value;

    hopOk[0] = tnx_v82_container_header(client, &hopArray[0], &hopCount[0], &hopCap[0], hopWhy[0],
                                        sizeof(hopWhy[0]));
    hopOk[1] = tnx_v82_container_header(inner, &hopArray[1], &hopCount[1], &hopCap[1], hopWhy[1],
                                        sizeof(hopWhy[1]));

    score[0] = hopOk[0] ? tnx_v105_container_score(client) : -1;
    score[1] = hopOk[1] ? tnx_v105_container_score(inner) : -1;

    if (score[1] > score[0]) {
        chosen = 1;
        g_v82_hop_sticky = 1;
    } else if (score[0] > score[1]) {
        chosen = 0;
        g_v82_hop_sticky = 0;
    } else {
        chosen = hopOk[1] ? 1 : (hopOk[0] && !g_v82_hop_sticky ? 0 : -1);
    }

    if (chosen != g_v105_last_choice) {
        g_v105_last_choice = chosen;

        tnx_logf("v105 hop-select chosen=%d score0=%d score1=%d hopOk=%d/%d sticky=%d - the hop is "
                 "re-decided every tick from the own slot inside each candidate, so it can leave the "
                 "object that carried a header first and go back to the client hop",
                 chosen, score[0], score[1], hopOk[0], hopOk[1], g_v82_hop_sticky);
    } else if (g_v105_hop_logs < 6) {
        g_v105_hop_logs++;

        tnx_v106_cand_dump((uintptr_t)client, (uintptr_t)inner, score[0], score[1], chosen);
    }

    if (g_v103_tick < 4 || (g_v103_tick % 90) == 0) {
        tnx_v109_owner_probe((uintptr_t)client, (uintptr_t)inner);
        tnx_v107_cand_probe((const char *)"client", (uintptr_t)client);
        tnx_v107_cand_probe((const char *)"inner", (uintptr_t)inner);
        tnx_v107_cand_probe((const char *)"owner", g_v108_owner);
        tnx_v107_coord_scan((uintptr_t)g_players_object);
        tnx_v107_coord_scan(g_v108_owner);
    }

    if (scene != g_v82_hop_scene) {
        g_v82_hop_scene = scene;

        tnx_logf("v100 hop1 scene+%#llx=%p client hop2 client+%#llx=%p inner hop1test=%d (%s) "
                 "hop2test=%d (%s) chosen=%d - findOwningTeam reads +0x28 off its receiver and "
                 "then +0x0/+0xc off the result, so only the hop that carries the header is the "
                 "object container",
                 (unsigned long long)TNX_MODE_MANAGER_OFF, (void *)client,
                 (unsigned long long)TNX_V82_CLIENT_HOP_OFF, (void *)inner,
                 hopOk[0], hopWhy[0], hopOk[1], hopWhy[1], chosen);

        tnx_v82_hop_dump(client, inner);

        if (g_v85_field_scans < TNX_V85_FIELD_SCANS) {
            g_v85_field_scans++;

            tnx_v85_ptr_field_dump("scene", scene, TNX_MODE_MANAGER_OFF, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("scene", scene, 0x30ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("scene", scene, 0x38ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("scene", scene, 0x40ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("scene", scene, 0x58ULL, TNX_V85_FIELD_QWORDS);

            tnx_v85_ptr_field_dump("client", client, 0x18ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x20ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x30ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x38ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x40ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x58ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x68ULL, TNX_V85_FIELD_QWORDS);
            tnx_v85_ptr_field_dump("client", client, 0x80ULL, TNX_V85_FIELD_QWORDS);
        }
    }

    if (TNX_V110_WIRE_OWNER && g_v110_owner) {
        void *directArray = NULL;
        int32_t directCount = 0;

        if (tnx_read_ptr(g_v110_owner + TNX_MGR_ARRAY_OFF, &directArray) && directArray &&
            tnx_read_i32(g_v110_owner + TNX_MGR_COUNT_OFF, &directCount) && directCount > 0) {
            g_players_object = g_v110_owner;
            g_players_array = (uintptr_t)directArray;
            g_players_count = directCount;
            g_v82_hop_chosen = TNX_V110_HOPCHOSEN_DIRECT;

            if (!g_v110_wired) {
                g_v110_wired = 1;

                tnx_logf("v109 owner wired route=direct owner=%p array=%p count-at-wire=%d chosen=%d - the walk "
                         "reads the owner list from this tick on; the array and the count are re-read from the "
                         "owner on every tick, and chosen stays above one because a negative value already means "
                         "no container elsewhere in the engine path",
                         (void *)g_v110_owner, (void *)directArray, directCount,
                         TNX_V110_HOPCHOSEN_DIRECT);
            }

            return 0;
        }
    }

    if (chosen < 0) {
        tnx_logf("v100 chain rejected: neither hop carries an array/count/cap header (hop1 %s, "
                 "hop2 %s, sticky=%d) - nothing is published this tick, and once hop2 has ever "
                 "passed the choice stays on it instead of falling back to the client, so the "
                 "last good container is what the walk keeps reading", hopWhy[0], hopWhy[1],
                 g_v82_hop_sticky);

        tnx_v81_alert_edge(scene, client, 0, state);

        return 1;
    }

    players = (chosen == 1) ? inner : client;
    array = (void *)hopArray[chosen];
    count = hopCount[chosen];
    capacity = hopCap[chosen];

    g_v82_hop_chosen = chosen;

    if (chosen == 1 && TNX_V123_HOP2_DEFER) {
        if (g_v123_defer_logs < 4) {
            g_v123_defer_logs++;

            tnx_logf("v123 hop2 defer container=%p count=%d cap=%d array=%p - the fresh hop2 container is "
                     "logged and not adopted in this build: adopting it means the walk reads class %#llx "
                     "elements and a single bad field in one of them is enough to take the stub path into "
                     "a bad pointer, so hop1 stays the walk source until the hop2 dump proves the layout",
                     (void *)players, count, capacity, array, (unsigned long long)0xff5440ULL);
        }

        return 1;
    }

    if (players != g_players_object) {
        g_players_object = players;
        g_players_array = (uintptr_t)array;
        g_players_count = count;
        g_players_cap = capacity;

        tnx_logf("v100 container=%p hop=%d count=%d cap=%d array=%p - read straight out of the "
                 "engine's own global chain with no scan; hop %d is the field the engine walks "
                 "after 0xac3ddc reads it",
                 (void *)players, chosen, count, capacity, array, chosen);

        if (g_v81_players_dumps < TNX_V81_PLAYERS_DUMPS) {
            g_v81_players_dumps++;

            tnx_v81_players_dump(players, (uintptr_t)array, count, capacity);
        }
    }

    g_manager_count = count;

    if (count > 0 && count <= TNX_MANAGER_MAX_OBJECTS && capacity > 0 &&
        capacity <= TNX_MGR_CAP_MAX && array) {
        tnx_v68_pending_push(players, "v82-scene-chain");

        if (g_v82_hop_chosen == 1) {
            if (!g_v86_hop2_census && players != g_v88_census_container) {
                g_v86_hop2_census = 1;

                tnx_logf("v100 census armed on hop2: hop=%d container=%p count=%d array=%p - the "
                         "census is taken once per container and only on the hop the engine "
                         "walks; the dedup key is the container and not the array, because the "
                         "array pointer moves when it is reallocated and the v88 run took a "
                         "second census of the same manager for that reason",
                         g_v82_hop_chosen, (void *)players, count, (void *)array);
            }

            tnx_v81_container_census((uintptr_t)array, count, players);
        }
    }

    tnx_v81_alert_edge(scene, players, count, state);

    return 1;
}

static int tnx_v63_battle_gate(int scene) {
    unsigned long long objFired = tnx_v79_object_dispatches();
    int objGrew = objFired > g_v79_obj_prev;
    int sigGrew = g_v64_modesig_hits > g_v63_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;

    g_v79_obj_prev = objFired;

    if (sigGrew || objGrew || sceneGrew) {
        g_v63_battle_last_tick = (int)g_v50_ticks;

        if (!g_v63_battle_active) {
            g_v63_battle_active = 1;
            g_v63_battle_reason = sceneGrew ? "scene" : (objGrew ? "objslot" : "modesig");

            tnx_logf("v100 battle state: inactive -> active reason=%s state=%d objFired=%llu "
                     "sigHits=%d", g_v63_battle_reason, g_v80_state, objFired, g_v64_modesig_hits);
        }
    } else if (g_v63_battle_active &&
               ((int)g_v50_ticks - g_v63_battle_last_tick) >= TNX_V63_QUIET_SECS) {
        g_v63_battle_active = 0;

        tnx_logf("v100 battle state: active -> inactive reason=quiet-10s");
    }

    return g_v63_battle_active;
}

static uint64_t tnx_v78_hook_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) total += g_slot_hits[i];

    return total;
}

static const int tnx_v79_object_slots[TNX_V79_OBJ_SLOTS] = { 2, 3, 4 };

static uint64_t tnx_v79_object_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < TNX_V79_OBJ_SLOTS; i++) total += g_slot_hits[tnx_v79_object_slots[i]];

    return total;
}

static void tnx_v79_object_probe(void) {
    uintptr_t object = g_slot_object[2];
    void *vt = NULL;
    void *def = NULL;
    int32_t gid = 0;
    int32_t team = 0;
    int32_t kind = 0;

    if (g_v79_probe_done) return;
    if (g_v79_probe_tries >= TNX_V79_PROBE_TRIES) return;
    if (!object || !tnx_pointer_plausible(object)) return;
    if (!tnx_read_ptr(object, &vt) || !vt) return;

    g_v79_probe_tries++;

    if ((uintptr_t)vt != g_base + TNX_V79_OBJCLASS_RVA) {
        tnx_logf("v100 objprobe attempt %d: object=%p vt=%c%#llx is not the class table %#llx, so "
                 "slot %s handed us a receiver of another type and the answer is retried rather "
                 "than recorded as a negative", g_v79_probe_tries, (void *)object,
                 tnx_v72_seg_code((uintptr_t)vt), (unsigned long long)(uintptr_t)vt,
                 (unsigned long long)TNX_V79_OBJCLASS_RVA, g_slot_specs[2].shortTag);

        return;
    }

    g_v79_probe_done = 1;

    tnx_read_i32(object + TNX_OBJ_GLOBALID_OFF, &gid);
    tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team);
    if (tnx_read_ptr(object + TNX_V82_ELEM_DEF_OFF, &def) && def)
        tnx_read_i32((uintptr_t)def + TNX_V79_KIND_OFF, &kind);

    tnx_logf("v100 objprobe object=%p vt=%c%#llx objTable=1 gid=%d team=%d def=%p defKind=%d - "
             "slot %s fired on a live member of the class the constructor at 0xa2e2f4 installs, "
             "which stores this table at [+0] right after its base constructor, and whose [+0x18] "
             "is the very method addGameObject calls on every object it accepts, setOwner at "
             "0xa2d250", (void *)object,
             tnx_v72_seg_code((uintptr_t)vt), (unsigned long long)(uintptr_t)vt, gid, team, def,
             kind, g_slot_specs[2].shortTag);

    for (uintptr_t off = TNX_V79_FIELD_LO; off <= TNX_V79_FIELD_HI; off += sizeof(void *)) {
        void *field = NULL;
        int32_t count = 0;
        int32_t cap = 0;
        int32_t window = 0;
        int siblings = 0;
        int sampled = 0;

        if (!tnx_read_ptr(object + off, &field)) continue;
        if (!field || !tnx_pointer_plausible((uintptr_t)field)) continue;
        if (tnx_v57_header_reason((uintptr_t)field, &count, &cap) != NULL) continue;

        window = count;

        if (window > TNX_V79_SIBLINGS) window = TNX_V79_SIBLINGS;

        for (int32_t i = 0; i < window; i++) {
            void *element = NULL;
            void *elementVt = NULL;

            if (!tnx_read_ptr((uintptr_t)field + (uintptr_t)i * sizeof(void *), &element)) break;
            if (!element) continue;

            sampled++;

            if (!tnx_read_ptr((uintptr_t)element, &elementVt)) continue;
            if (vt && elementVt == vt) siblings++;
        }

        if (sampled <= 0 || siblings <= 0) continue;

        tnx_logf("v100 objprobe container at object+%#llx=%p count=%d cap=%d siblings=%d/%d share "
                 "the object's class table - the mode is that address minus %#llx",
                 (unsigned long long)off, field, count, cap, siblings, sampled,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);

        tnx_v68_pending_push((uintptr_t)field, "v79-object-field");

        return;
    }

    tnx_logf("v100 objprobe no container field in object+%#llx..%#llx - the live object holds no "
             "pointer to the container, so the mode still has to be located by scan",
             (unsigned long long)TNX_V79_FIELD_LO, (unsigned long long)TNX_V79_FIELD_HI);
}

static int tnx_v78_scan_allowed(uint64_t fired, uint64_t total) {
    if (fired > 0) {
        if (g_v78_idle_on) {
            tnx_logf("v100 scan resumed at tick=%llu objFired=%llu total=%llu - the object-class "
                     "slots are being dispatched again after %d parked ticks",
                     (unsigned long long)g_v50_ticks, (unsigned long long)fired,
                     (unsigned long long)total, g_v78_idle_skips);
        }

        g_v78_idle_on = 0;
        g_v78_idle_start = 0;
        g_v78_idle_logged = 0;
        g_v78_idle_skips = 0;

        return 1;
    }

    if (g_v78_idle_start == 0) g_v78_idle_start = g_v50_ticks;

    g_v78_idle_on = 1;

    if (!g_v78_idle_logged && (g_v50_ticks - g_v78_idle_start) >= TNX_V78_IDLE_TICKS) {
        g_v78_idle_logged = 1;

        tnx_logf("v100 scan parked at tick=%llu: none of the %d object-class slots has been "
                 "dispatched in %llu ticks while the %d armed slots together reached %llu, so "
                 "the app is drawing UI and not a battle and the heap walk has no mode to find; "
                 "it resumes on the first object-class dispatch and is retried every %d parked "
                 "ticks", (unsigned long long)g_v50_ticks, TNX_V79_OBJ_SLOTS,
                 (unsigned long long)(g_v50_ticks - g_v78_idle_start), TNX_SLOT_COUNT,
                 (unsigned long long)total, TNX_V78_IDLE_RETRY_TICKS);
    }

    if ((g_v50_ticks - g_v78_idle_start) < TNX_V78_IDLE_RETRY_TICKS) {
        g_v78_idle_skips++;

        return 0;
    }

    g_v78_idle_start = g_v50_ticks;
    g_v78_idle_skips = 0;

    return 1;
}

static int tnx_v77_battle_gate(int v63) {
    int liveEnough = (g_v77_live_objs >= TNX_V77_LIVE_OBJ_MIN &&
                      g_v77_live_teams >= TNX_V77_LIVE_TEAM_MIN);

    g_v77_fb_on = (v63 || liveEnough) ? 1 : 0;

    if (!g_v77_fb_on) {
        if (!g_v77_bar_logged && g_v50_ticks >= TNX_V77_BAR_TICKS) {
            g_v77_bar_logged = 1;

            tnx_logf("v100 gate fallback OFF v63=%d liveObjs=%d liveTeams=%d need=%d/%d - the "
                     "objhit set holds no live objects over two teams, so nothing here claims "
                     "a battle the mode signature cannot see", v63, g_v77_live_objs,
                     g_v77_live_teams, TNX_V77_LIVE_OBJ_MIN, TNX_V77_LIVE_TEAM_MIN);
        }

        return 0;
    }

    if (v63) return 1;

    if (!g_v77_fb_logged) {
        g_v77_fb_logged = 1;

        tnx_logf("v100 gate fallback ON liveObjs=%d liveTeams=%d - v63 cannot see a mode, but "
                 "the objhit set holds live objects over two teams, which is the weaker "
                 "signal the trail itself uses", g_v77_live_objs, g_v77_live_teams);
    }

    return 1;
}

static int tnx_v76_scan_ready(int battle) {
    if (g_v50_ticks < TNX_V76_SCAN_FLOOR_TICKS) {
        if (!g_v76_floor_logged) {
            g_v76_floor_logged = 1;

            tnx_logf("v100 scan held to tick=%d battle=%d mode=%p - the lobby scan is what "
                     "raised the TID_SHOP trail candidate", TNX_V76_SCAN_FLOOR_TICKS, battle,
                     (void *)g_scene_object);
        }

        return 0;
    }

    if (battle || g_scene_object) return 1;

    if (g_v50_ticks < TNX_V76_SCAN_FALLBACK_TICKS) return 0;

    if (!g_v76_fallback_logged) {
        g_v76_fallback_logged = 1;

        tnx_logf("v100 scan fallback at tick=%llu battle=%d mode=%p - no battle seen, resuming "
                 "on the %ds bucket", (unsigned long long)g_v50_ticks, battle,
                 (void *)g_scene_object, TNX_V63_BUCKET_TICKS);
    }

    return (g_v50_ticks % TNX_V63_BUCKET_TICKS) == 0;
}

static void tnx_v63_log_heartbeat(void) {
    int sigDelta = g_v64_modesig_hits - g_v63_hb_sig_prev;

    tnx_logf("v100 hb tick=%llu battle=%d reason=%s slot=%p state=%d objFired=%llu "
             "modesigHits=%d sigLast=%d chainHits=%d classesPass=%d g_mode=%p src=%s mgr=%p "
             "count=%d fb=%d liveObjs=%d liveTeams=%d parked=%d",
             (unsigned long long)g_v50_ticks,
             g_v63_battle_active, g_v63_battle_reason, (void *)g_v80_site, g_v80_state,
             (unsigned long long)tnx_v79_object_dispatches(), g_v64_modesig_hits, sigDelta,
             g_v59_chain_hits, g_v62_class_pass,
             (void *)g_scene_object, g_v62_mode_source, (void *)g_players_object, g_manager_count,
             g_v77_fb_on, g_v77_live_objs, g_v77_live_teams, g_v78_idle_on);

    g_v63_hb_sig_prev = g_v64_modesig_hits;

    if ((g_v50_ticks % TNX_V63_BUCKET_TICKS) == 0) tnx_v63_flush_buckets();

    if (g_v64_modesig_hits == 0 && g_v50_ticks >= TNX_V63_D6_WAIT_SECS &&
        !g_v64_modesig_notfound) {
        g_v64_modesig_notfound = 1;

        tnx_logf("v100 modesig not-found at t=%ds - the mode signature did not match, while the "
                 "%d object-class slots have fired %llu times", TNX_V63_D6_WAIT_SECS,
                 TNX_V79_OBJ_SLOTS, (unsigned long long)tnx_v79_object_dispatches());
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

    if (g_scene_object) candidate = g_scene_object;
    else if (g_players_object) candidate = g_players_object;

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

        if (TNX_V113_ALERT_WITHHELD && (g_v50_alert_withheld_logs < 5 || (g_v50_alert_calls % 1800) == 0)) {
            g_v50_alert_withheld_logs++;

            tnx_logf("v100 alert withheld: %s bestLive=%d bestCount=%d mode=%p manager=%p "
                     "candidate=%p live=%d elements=%d teamCount=%d distinctGids=%d deadOk=%d "
                     "vt0=%#llx sightings=%d",
                     why, g_manager_best_live, g_manager_best_count, (void *)g_scene_object,
                     (void *)g_players_object, (void *)candidate, facts.live, facts.elements,
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

        tnx_logf("v100 battle entry: live=%d teamCount=%d distinctGids=%d deadOk=%d vt0=%#llx "
                 "sightings=%d bestLive=%d bestCount=%d mode=%p manager=%p candidate=%p -- showing "
                 "alert",
                 facts.live, facts.teamCount, facts.distinctGids, facts.deadOk,
                 (unsigned long long)facts.vt0, g_v50_alert_streak, g_manager_best_live,
                 g_manager_best_count, (void *)g_scene_object, (void *)g_players_object,
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

        int scene = tnx_v80_state_tick();
        int gate = tnx_v63_battle_gate(scene);
        int battle = gate || scene;
        int fallback = tnx_v77_battle_gate(battle);

        int ready = tnx_v76_scan_ready(battle || fallback);
        int needScan = !scene && !g_players_object;

        tnx_v79_object_probe();

        if (needScan != g_v80_scan_armed) {
            g_v80_scan_armed = needScan;

            tnx_logf("v100 heap walk %s - the scene chain %s, so the walk is %s",
                     needScan ? "armed" : "parked",
                     g_players_object ? "delivered the container" : "has not delivered yet",
                     needScan ? "the only remaining source" : "not needed this tick");
        }

        if (needScan && ready &&
            tnx_v78_scan_allowed((unsigned long long)tnx_v79_object_dispatches(),
                                 tnx_v78_hook_dispatches())) {
            tnx_locate_battle_mode();
        }

        tnx_v64_modesig_tick();
        tnx_v68_pending_tick();
        tnx_v96_tick();
        tnx_v99_inputmgr_probe();
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

    if (g_scene_object) {
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

static char tnx_v72_seg_code(uintptr_t value) {
    const char *segment = NULL;

    if (!value) return '.';

    segment = tnx_image_segment_name(value);

    if (segment) {
        if (strcmp(segment, "__TEXT") == 0) return 'T';
        if (strcmp(segment, "__DATA_CONST") == 0) return 'C';
        if (strcmp(segment, "__DATA") == 0) return 'D';

        return 'I';
    }

    if (tnx_heap_contains(value)) return 'H';

    return 'W';
}

static BOOL tnx_v72_image_resident(uintptr_t value) {
    char code = tnx_v72_seg_code(value);

    return (code == 'T' || code == 'C' || code == 'D' || code == 'I') ? YES : NO;
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

    tnx_logf("modehit[%s] slot=%p mode=%p mdSeg=%s vt=%p vtSeg=%s vtOff=%#llx inList=%d primary=%d score=%d types=%d var=%d mgr=%p mgr0Rva=%#llx mgrShape=%d array=%p entry0=%p count=%d",
             tag, (void *)slot, (void *)object, modeSeg ? modeSeg : "-",
             vtable, vtableSeg ? vtableSeg : "-", (unsigned long long)vtableOff,
             tnx_is_mode_vtable((uintptr_t)vtable, NULL) ? 1 : 0,
             tnx_verified_vtable((uintptr_t)vtable) >= 0 ? 1 : 0,
             score, g_mode_last_types, variation,
             manager, (unsigned long long)managerVtableRva,
             tnx_manager_shape((uintptr_t)manager) ? 1 : 0, array, entry, count);

    if (g_v71_modehit_dump >= 8) return;

    g_v71_modehit_dump++;

    for (int i = 0; i < 5; i++) {
        uint32_t w4[4] = { 0, 0, 0, 0 };

        tnx_read_bytes((uintptr_t)object - 0x10ULL + (uintptr_t)i * 16ULL, w4, sizeof(w4));

        tnx_logf("modehit[%s] off=%+d %08x %08x %08x %08x", tag, i * 16 - 16, w4[0], w4[1], w4[2],
                 w4[3]);
    }

    {
        void *before = NULL;
        void *tableHead = NULL;
        uintptr_t tableRva = 0;

        tnx_read_ptr((uintptr_t)object - 0x8ULL, &before);

        if (before && tnx_v56_vtable_in_image((uintptr_t)before) &&
            tnx_read_ptr((uintptr_t)before, &tableHead) && tableHead) {
            if ((uintptr_t)tableHead > g_base) tableRva = (uintptr_t)tableHead - g_base;

            tnx_logf("modehit[%s] classtable m-08=%p inImage=1 vt0=%p vt0rva=%#llx", tag,
                     before, tableHead, (unsigned long long)tableRva);
        } else {
            tnx_logf("modehit[%s] classtable m-08=%p not-a-class-table", tag, before);
        }
    }
}

static void tnx_adopt_mode(uintptr_t object, BOOL strong, const char *tag) {
    if (!object) return;

    {
        void *vt = NULL;

        if (!tnx_read_ptr(object, &vt) || !vt || !tnx_v56_vtable_in_image((uintptr_t)vt)) {
            if (g_v99_adopt_reject_logs < TNX_V99_ADOPT_REJECT_LOGS) {
                g_v99_adopt_reject_logs++;

                tnx_logf("v100 adopt rejected tag=%s object=%p vt=%p - a watched word whose first "
                         "slot is not a class table inside the image cannot name the mode, so the "
                         "garbage that E2 reads as its vtable is refused here and no longer "
                         "reaches the scene", tag, (void *)object, vt);
            }

            return;
        }
    }

    if (g_mode_strong) return;
    if (g_scene_object == object && strong == g_mode_strong) return;
    if (g_scene_object && !strong) return;

    if (g_scene_object != object) {
        g_snapshot_first = NO;
        g_snapshot_second = NO;
        g_snapshot_start = 0.0;
    }

    g_scene_object = object;
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

        if (!tnx_v75_object_live((uintptr_t)element)) continue;

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

static int tnx_v52_ascii_word(uintptr_t address) {
    uint8_t bytes[8];
    int printable = 0;

    if (!tnx_read_bytes(address, bytes, sizeof(bytes))) return 0;

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable == 8 ? 1 : 0;
}

static int tnx_v75_word_ascii(uint64_t value) {
    uint8_t bytes[8];
    int printable = 0;

    memcpy(bytes, &value, sizeof(bytes));

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable;
}

static int tnx_v75_element_ascii(uintptr_t element) {
    if (tnx_v52_ascii_word(element)) return 1;

    return tnx_v75_word_ascii((uint64_t)element) == 8 ? 1 : 0;
}

static int tnx_v75_object_live(uintptr_t object) {
    int32_t gid = 0;
    int32_t team = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_gameobject_shape(object)) return 0;
    if (!tnx_read_i32(object + TNX_OBJ_GLOBALID_OFF, &gid)) return 0;
    if (gid <= 0 || gid >= TNX_V75_GID_MAX) return 0;
    if (!tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team)) return 0;
    if (team < 0 || team > TNX_V75_TEAM_MAX) return 0;
    if (!tnx_read_i32(object + tnx_v57_coord_x_off(), &x)) return 0;
    if (!tnx_read_i32(object + tnx_v57_coord_y_off(), &y)) return 0;
    if (x <= -TNX_V75_COORD_MAX || x >= TNX_V75_COORD_MAX) return 0;
    if (y <= -TNX_V75_COORD_MAX || y >= TNX_V75_COORD_MAX) return 0;

    return 1;
}

static void tnx_v75_measure(uintptr_t manager, int32_t count, tnx_v75_measure_t *out) {
    void *array = NULL;
    uint32_t teams = 0;
    int32_t posX[TNX_V75_ASCII_WINDOW];
    int32_t posY[TNX_V75_ASCII_WINDOW];
    int posCount = 0;

    memset(out, 0, sizeof(*out));

    if (!manager || count <= 0) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;

    if (count > TNX_V75_ASCII_WINDOW) count = TNX_V75_ASCII_WINDOW;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t team = 0;
        int32_t x = 0;
        int32_t y = 0;
        int seen = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        out->sampled++;

        if (tnx_v75_element_ascii((uintptr_t)element)) out->ascii++;

        {
            void *elementVt = NULL;

            if (!tnx_read_ptr((uintptr_t)element, &elementVt) || !elementVt ||
                !tnx_v77_vtable_is_data((uintptr_t)elementVt)) {
                out->noVt++;
            }
        }

        if (!tnx_v75_object_live((uintptr_t)element)) continue;

        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);

        teams |= (uint32_t)(1u << (unsigned)team);

        tnx_read_i32((uintptr_t)element + tnx_v57_coord_x_off(), &x);
        tnx_read_i32((uintptr_t)element + tnx_v57_coord_y_off(), &y);

        for (int k = 0; k < posCount; k++) {
            if (posX[k] == x && posY[k] == y) {
                seen = 1;

                break;
            }
        }

        if (!seen && posCount < TNX_V75_ASCII_WINDOW) {
            posX[posCount] = x;
            posY[posCount] = y;
            posCount++;
        }
    }

    for (int t = 0; t <= TNX_V75_TEAM_MAX; t++) {
        if (teams & (uint32_t)(1u << (unsigned)t)) out->teamDistinct++;
    }

    out->posDistinct = posCount;
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

        if (tnx_v75_element_ascii((uintptr_t)element)) {
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
    int refused = 0;
    tnx_v75_measure_t measure;

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

    tnx_v75_measure(candidate, (int32_t)count, &measure);

    if (measure.sampled >= TNX_V52_ASCII_MIN && measure.noVt == measure.sampled) {
        refused = 3;

        g_v52_stringy_rejected++;
        g_v63_stringy_logs++;

        if (g_v80_novt_logs < 4) {
            g_v80_novt_logs++;

            tnx_logf("v100 trail: container mgr=%p count=%u has no class table behind any of its "
                     "%d sampled elements (ascii=%d) - an element whose first word is not a "
                     "table in __DATA_CONST or __DATA is text or a plain scalar, so this array "
                     "is not an object container", (void *)candidate, count, measure.sampled,
                     measure.ascii);
        }
    } else if (measure.sampled >= TNX_V52_ASCII_MIN &&
               (measure.ascii * 100) / measure.sampled > TNX_V75_ASCII_RATIO) {
        refused = 1;

        g_v52_stringy_rejected++;
        g_v63_stringy_logs++;
        g_v75_ascii_refused++;

        if (g_v75_ascii_refusals < 4) {
            g_v75_ascii_refusals++;

            tnx_logf("v100 trail: text container mgr=%p count=%u ascii=%d/%d(%d%%) live=%d "
                     "nonEmpty=%d firstTextSlot=%d - inline strings are counted as text before "
                     "the score and never become the best candidate", (void *)candidate, count,
                     measure.ascii, measure.sampled, (measure.ascii * 100) / measure.sampled,
                     g_manager_last_live, g_manager_last_nonempty, g_v57_stringy_slot);
        }
    } else if (live > 0 && live * 2 < (int)count) {
        refused = 2;

        g_v52_weak_rejected++;

        if (g_v52_weak_logs < 4) {
            g_v52_weak_logs++;

            tnx_logf("v100 trail: weak container mgr=%p count=%u live=%d nonEmpty=%d - under "
                     "half of its elements are objects, so it is not the array the dodge needs",
                     (void *)candidate, count, live, g_manager_last_nonempty);
        }
    }

    tnx_trail_note(candidate, (int32_t)count, g_manager_last_capacity, g_manager_last_live,
                   g_manager_last_nonempty, measure.ascii, measure.sampled, measure.noVt,
                   measure.teamDistinct, measure.posDistinct, refused);

    if (refused) return;

    if (live < TNX_MANAGER_MIN_OBJECTS) return;

    if (!g_players_object && !g_objvote_owner_ok) {
        uintptr_t container = 0;
        int32_t resolved = 0;
        int32_t resolvedCap = 0;
        char why[64] = { 0 };

        if (!tnx_v60_container_resolve(candidate, &container, &resolved, &resolvedCap, why,
                                       sizeof(why))) {
            if (g_v66_trail_refusals < 6) {
                g_v66_trail_refusals++;

                tnx_logf("v100 trail adoption refused mgr=%p count=%u live=%d reason=%s src=B",
                         (void *)candidate, count, live, why[0] ? why : "unresolved");
            }

            return;
        }

        if (tnx_v52_stringy(candidate, resolved)) {
            if (g_v66_trail_refusals < 6) {
                g_v66_trail_refusals++;

                tnx_logf("v100 trail adoption refused mgr=%p count=%d reason=stringy src=B",
                         (void *)candidate, resolved);
            }

            return;
        }

        g_players_object = (uintptr_t)container;
        g_manager_count = resolved;

        tnx_logf("v100 manager adopted mgr=%p count=%d cap=%d live=%d layout=+0x%x src=B",
                 (void *)container, resolved, resolvedCap, live, g_v67_layout_used);

        tnx_dump_manager(container, resolved);
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

        tnx_logf("v100 %s+%02x: %#llx %#llx %#llx %#llx | %s | %s | %s | %s", tag, base * 8,
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

    tnx_logf("v100 table probe rva=%#llx seg=%c count=%llu shaped=%llu instances=%d -- before this "
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
            tnx_logf("v100 table elem[%d] %p unreadable - no verdict from this element",
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

        tnx_logf("v100 table elem[%d] %p vt=%#llx gid=%d team=%d team4c=%d own=%d dead=%d owner=%p "
                 "w08=%d w40=%d w4c=%d wd0=%d shape=%d",
                 i, (void *)object, (unsigned long long)((uintptr_t)vtable - g_base), gid, team,
                 teamEngine,
                 ownIndex, dead, (void *)owner, w08, w40, w4c, wd0, isShaped);
    }

    if (entry->instCount >= 2 && sameGid) {
        tnx_logf("v100 table verdict rva=%#llx: all %d instances share gid=%d - this is a proxy or a "
                 "cache, NOT a battle container; hooking it would be pointless",
                 (unsigned long long)entry->rva, entry->instCount, firstGid);
    } else if (entry->instCount >= 1) {
        tnx_logf("v100 table verdict rva=%#llx: shaped=%d instances=%d and the ids differ - a real "
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
        const char *mark = "";

        memcpy(&slot, bytes + (size_t)i * sizeof(uintptr_t), sizeof(slot));

        for (int k = 0; k < TNX_SLOT_COUNT; k++) {
            if (slot && slot == (uintptr_t)g_slot_specs[k].replacement) mark = "self:";
        }

        if (used > (int)sizeof(listed) - 32) break;

        used += snprintf(listed + used, sizeof(listed) - (size_t)used, "%s%s%#llx", i ? "," : "",
                         mark, (unsigned long long)(slot > g_base ? slot - g_base : 0));
    }

    tnx_logf("vtslots rva=%#llx seg=%c count=%llu shaped=%llu slotRvas=%s (self: is this tweak's "
             "own replacement, not a class method)", (unsigned long long)entry->rva,
             entry->seg ? 'D' : 'C', entry->count, entry->shaped, listed);

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

    {
        int live = 0;
        int teams = 0;
        int teamSeen[TNX_V77_TEAM_SLOTS];

        for (int i = 0; i < TNX_V77_TEAM_SLOTS; i++) teamSeen[i] = 0;

        for (int i = 0; i < g_objhit_count; i++) {
            const tnx_objhit_t *hit = &g_objhits[i];
            int32_t team = 0;

            if (!tnx_v75_object_live(hit->at)) continue;

            live++;

            if (!tnx_read_i32(hit->at + TNX_OBJ_TEAM_OFF, &team)) continue;
            if (team < 0 || team >= TNX_V77_TEAM_SLOTS) continue;
            if (teamSeen[team]) continue;

            teamSeen[team] = 1;
            teams++;
        }

        g_v77_live_objs = live;
        g_v77_live_teams = teams;
    }

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
                         "owner=%p o20=%#llx o20Heap=%d ownerClass=%s",
                         g_heap_passes, printed, (void *)hit->at,
                         (unsigned long long)(hit->vt > g_base ? hit->vt - g_base : 0), hit->gid,
                         hit->team, hit->ownerIdx, hit->dead, hx, hy, (void *)hit->owner,
                         (unsigned long long)tnx_v68_word(hit->at + TNX_SLOT_OWNER_OFF),
                         (int)tnx_heap_contains((uintptr_t)hit->owner), names[want]);
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

    if (!tnx_v71_manager_head_ok(owner)) {
        g_v71_head_veto++;

        if (g_v71_head_veto_logs < 4) {
            uintptr_t head = (uintptr_t)tnx_v68_word(owner);

            g_v71_head_veto_logs++;

            tnx_logf("v100 objvote veto owner=%p ownSeg=%c head=%#llx headSeg=%c img=%d heap=%d "
                     "src=B", (void *)owner, tnx_v72_seg_code(owner), (unsigned long long)head,
                     tnx_v72_seg_code(head), (int)tnx_in_image_span(head),
                     (int)tnx_heap_contains(head));
        }

        return;
    }

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

    for (int i = 0; i < g_owner_vote_count; i++) {
        if (g_owner_votes[i].gidSeenCount < TNX_OWNER_VOTE_MIN) continue;

        tnx_v71_owner_team_dump(g_owner_votes[i].owner, g_owner_votes[i].teamMask,
                                tnx_team_count(g_owner_votes[i].teamMask));
    }

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
        if (entry->gidSeenCount < TNX_V75_GID_DISTINCT_MIN) {
            if (g_v75_gid_veto_logs < 4) {
                g_v75_gid_veto_logs++;

                tnx_logf("v100 objvote veto owner=%p distinctGids=%d votes=%d teamCount=%d - a container "
                         "whose elements repeat one id is a cache or a proxy, not a battle container",
                         (void *)entry->owner, entry->gidSeenCount, entry->votes,
                         g_objvote_best_teamcount);
            }

            return;
        }

        if (entry->votes < TNX_OWNER_VOTE_MIN) {
            if (g_v52_low_votes_logs < 4) {
                g_v52_low_votes_logs++;

                tnx_logf("v100 objvote two teams but %d objects on owner=%p - not adopted yet",
                         entry->votes, (void *)entry->owner);
            }

            return;
        }

        {
            uintptr_t container = 0;
            int32_t owned = 0;
            int32_t ownedCap = 0;
            char gateWhy[64] = { 0 };

            if (!tnx_v71_manager_head_ok(entry->owner)) {
                if (g_v71_head_reject_logs < 8) {
                    g_v71_head_reject_logs++;

                    tnx_logf("v100 objvote head refused owner=%p head=%#llx votes=%d gids=%d src=B",
                             (void *)entry->owner,
                             (unsigned long long)tnx_v68_word(entry->owner + TNX_MGR_ARRAY_OFF),
                             entry->votes, entry->gidSeenCount);
                }

                return;
            }

            tnx_v68_multiteam_dump(entry->owner, entry->teamMask, g_objvote_best_teamcount);

            if (!tnx_v68_container_gate(entry->owner, &container, &owned, &ownedCap, gateWhy,
                                        sizeof(gateWhy))) {
                tnx_v68_pending_push(entry->owner, gateWhy);

                if (g_v57_reject_logs < 8) {
                    g_v57_reject_logs++;

                    tnx_logf("v100 adopt refused owner=%p teams=%#x votes=%d distinctGids=%d "
                             "reason=%s count=%d cap=%d - queued for retry instead of excluded",
                             (void *)entry->owner, entry->teamMask, entry->votes,
                             entry->gidSeenCount, gateWhy[0] ? gateWhy : "unknown", owned,
                             ownedCap);
                }

                return;
            }

            entry->owner = container;
        }

        tnx_logf("v100 objvote adopt owner=%p teams=%#x teamCount=%d votes=%d distinctGids=%d%s - a "
                 "two-team owner is a battle container on its own, and waiting for consecutive "
                 "passes is what kept the v51 run from ever naming it",
                 (void *)entry->owner, entry->teamMask, g_objvote_best_teamcount, entry->votes,
                 entry->gidSeenCount, entry->gidFull ? "+" : "");

        tnx_battle_begin("objvote");

        g_objvote_owner_ok = YES;
        g_players_object = entry->owner;
        g_manager_count = entry->gidSeenCount;

        tnx_report_manager("objvote", entry->owner);
        tnx_object_detail_readonly(entry->owner, TNX_OWNER_VOTE_DETAIL_MAX);

        return;
    }

    g_objvote_confirm = 0;

    if (g_objvote_single_team_logs < 4) {
        g_objvote_single_team_logs++;

        tnx_logf("v100 objvote singleTeam owner=%p teamCount=%d teams=%#x distinctGids=%d%s votes=%d "
                 "deadOk=%d vt0=%#llx - held back: a battle container carries both teams, and a "
                 "table that merely looks like one repeats a single team value",
                 (void *)entry->owner, g_objvote_best_teamcount, entry->teamMask,
                 entry->gidSeenCount, entry->gidFull ? "+" : "", entry->votes, entry->deadOk,
                 (unsigned long long)(entry->vt[0] > g_base ? entry->vt[0] - g_base : 0));
    }
}

static void tnx_slot_diag(const char *why) {
    char buf[1024];
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
    } else if (g_objvote_owner_ok && g_players_object && g_ag_manager && g_ag_objectCount > 0) {
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
    } else if (g_scene_object) {
        verdict = "an object was adopted but the chain is not fully confirmed";
    } else if (g_manager_loose_count == 0 && g_manager_saw_cap == 0) {
        verdict = "NO ARRAY-SHAPED WORD ANYWHERE - the header test itself matched nothing";
    } else if (g_manager_skipped > 0 || g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) {
        verdict = "ARRAY TEST BLIND - its probe budget was exhausted; the object vote is the channel that still covered the whole pass";
    } else if (g_chain_skipped > 0 && !g_scene_object && !g_players_object) {
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
    } else if (!g_players_object && g_mode_best_objects < TNX_MANAGER_MIN_OBJECTS &&
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

    tnx_logf("v100 chain gates: vtBad=%d vtNotDC=%d mgrBad=%d mgrNotPlausible=%d mgrNotHeap=%d "
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
             g_manager_best_count, g_manager_best_live, (void *)g_players_object,
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
             (void *)g_players_object, g_manager_probes, TNX_MANAGER_PROBE_LIMIT,
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
                 g_votescan_attempts, (void *)g_scene_object, (void *)g_mode_source);
        tnx_report_mode_hit("found", g_mode_source, g_scene_object);
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
    if (!g_scene_object) return;

    tnx_logf("moderef[%s] mode=%p vt=%#llx", tag, (void *)g_scene_object,
             (unsigned long long)tnx_vtable_rva((void *)g_scene_object));

    int altHits = 0;

    for (uint32_t off = 0; off < 0x100 && altHits < 4; off += 8) {
        void *field = NULL;

        if (!tnx_read_ptr(g_scene_object + off, &field)) continue;
        if (!field) continue;
        if ((uintptr_t)field < 0x10000) continue;

        int32_t probe = 0;
        tnx_read_i32((uintptr_t)field + TNX_MODE_MODEVAR_OFF, &probe);

        altHits++;

        tnx_logf("v100 modeAlt +%02x -> %p vt=%#llx int124=%d src=A", off, field,
                 (unsigned long long)tnx_vtable_rva(field), probe);
    }

    for (int i = 0; i < 3; i++) {
        uint32_t off = (uint32_t)(TNX_MODE_SLOT_A + i * 8);
        void *slot = NULL;

        if (!tnx_read_ptr(g_scene_object + off, &slot)) continue;
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
    if (!g_scene_object) return;

    tnx_dump_mode_refs(tag);

    void *manager = NULL;
    void *array = NULL;
    int32_t count = 0;
    int32_t variation = 0;

    if (!tnx_read_ptr(g_scene_object + TNX_MODE_MANAGER_OFF, &manager)) return;
    if (!tnx_read_i32(g_scene_object + TNX_MODE_MODEVAR_OFF, &variation)) return;
    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array)) return;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return;

    tnx_logf("mode[%s] object=%p variation=%d manager=%p array=%p count=%d",
             tag, (void *)g_scene_object, variation, manager, array, count);

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
    int rawOk;
    char rawSeg;
    int ascii;
    int sampled;
    int noVt;
    int teamDistinct;
    int posDistinct;
    int refused;
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

static int tnx_trail_qualifies(int slot) {
    if (slot < 0 || slot >= g_trail_count) return 0;
    if (!g_trail[slot].rawOk) return 0;
    if (g_trail[slot].refused) return 0;
    if (g_trail[slot].sampled > 0 && g_trail[slot].noVt == g_trail[slot].sampled) return 0;
    if (g_trail[slot].teamDistinct < 2) return 0;
    if (g_trail[slot].posDistinct < 2) return 0;

    return 1;
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
    int best = -1;

    for (int k = 0; k < n; k++) {
        if (tnx_trail_qualifies(rank[k])) {
            best = rank[k];

            break;
        }
    }

    g_trail_best = best;

    if (best < 0 && n > 0 && g_v75_best_wait_logs < 4) {
        int top = rank[0];

        g_v75_best_wait_logs++;

        tnx_logf("v100 trail: best has teamDistinct=%d posDistinct=%d ascii=%d/%d - not a battle "
                 "container, waiting for two teams and two positions", g_trail[top].teamDistinct,
                 g_trail[top].posDistinct, g_trail[top].ascii, g_trail[top].sampled);
    }
}

static void tnx_v75_append(char *buf, size_t size, size_t *used, const char *token) {
    size_t len = strlen(token);

    if (*used && *used + 1 < size) buf[(*used)++] = '+';

    if (*used + len >= size) len = (*used + 1 < size) ? size - *used - 1 : 0;

    memcpy(buf + *used, token, len);

    *used += len;
    buf[*used] = 0;
}

static int tnx_v75_trail_verdict(const tnx_trail_t *entry, char *buf, size_t size) {
    char parts[64];
    size_t used = 0;

    parts[0] = 0;

    if (!entry->rawOk) tnx_v75_append(parts, sizeof(parts), &used, "image");
    if (entry->refused == 1) tnx_v75_append(parts, sizeof(parts), &used, "ascii");
    if (entry->refused == 2) tnx_v75_append(parts, sizeof(parts), &used, "weak");
    if (entry->refused == 3) tnx_v75_append(parts, sizeof(parts), &used, "noVt");
    if (entry->teamDistinct < 2) tnx_v75_append(parts, sizeof(parts), &used, "noTeam");
    if (entry->posDistinct < 2) tnx_v75_append(parts, sizeof(parts), &used, "noPos");

    if (!used) return 1;

    snprintf(buf, size, "%s", parts);

    return 0;
}

static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty, int ascii, int sampled, int noVt, int teamDistinct,
                           int posDistinct, int refused) {
    int slot = -1;
    int stable = tnx_candidate_is_stable(manager, count) ? 1 : 0;
    void *raw = NULL;
    char rawSeg = '.';
    int rawOk = 1;

    tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &raw);

    rawSeg = tnx_v72_seg_code((uintptr_t)raw);
    rawOk = tnx_v72_image_resident((uintptr_t)raw) ? 0 : 1;

    g_trail_total++;

    if (live > g_manager_best_live) g_manager_best_live = live;

    for (int i = 0; i < g_trail_count; i++) {
        if (g_trail[i].manager == manager) {
            g_trail[i].count = count;
            g_trail[i].capacity = capacity;
            g_trail[i].live = live;
            g_trail[i].nonEmpty = nonEmpty;
            g_trail[i].stable = stable;
            g_trail[i].rawOk = rawOk;
            g_trail[i].rawSeg = rawSeg;
            g_trail[i].ascii = ascii;
            g_trail[i].sampled = sampled;
            g_trail[i].noVt = noVt;
            g_trail[i].teamDistinct = teamDistinct;
            g_trail[i].posDistinct = posDistinct;
            g_trail[i].refused = refused;
            slot = i;

            goto ranked;
        }
    }

    if (g_trail_count < TNX_TRAIL_MAX) {
        slot = g_trail_count++;
    } else {
        int worst = -1;

        for (int i = 0; i < TNX_TRAIL_MAX; i++) {
            if (!tnx_trail_qualifies(i)) {
                worst = i;

                break;
            }
        }

        if (worst < 0) {
            if (!rawOk || refused) return;

            worst = 0;

            for (int i = 1; i < TNX_TRAIL_MAX; i++) {
                if (tnx_trail_beats_slot(g_trail[worst].live, g_trail[worst].nonEmpty,
                                         g_trail[worst].count, i)) {
                    worst = i;
                }
            }

            if (!tnx_trail_beats_slot(live, nonEmpty, count, worst)) return;
        }

        slot = worst;
    }

    g_trail[slot].manager = manager;
    g_trail[slot].count = count;
    g_trail[slot].capacity = capacity;
    g_trail[slot].live = live;
    g_trail[slot].nonEmpty = nonEmpty;
    g_trail[slot].stable = stable;
    g_trail[slot].rawOk = rawOk;
    g_trail[slot].rawSeg = rawSeg;
    g_trail[slot].ascii = ascii;
    g_trail[slot].sampled = sampled;
    g_trail[slot].noVt = noVt;
    g_trail[slot].teamDistinct = teamDistinct;
    g_trail[slot].posDistinct = posDistinct;
    g_trail[slot].refused = refused;

    if (!rawOk && g_v72_trail_refusals < 6) {
        g_v72_trail_refusals++;

        tnx_logf("v100 trail: image-resident container refused raw=%c mgr=%p count=%d live=%d - "
                 "raw[0] sits in the image, so this is a text table and never a battle container",
                 rawSeg, (void *)manager, count, live);
    }

ranked:
    tnx_trail_rebest();
}

static void tnx_trail_dump(void) {
    int rank[TNX_TRAIL_MAX];
    int n = tnx_trail_ranked(rank, TNX_TRAIL_MAX);

    tnx_logf("trail: %llu candidates passed the array header, %d recorded, %d refused as inline "
             "text, ordered by (live, nonEmpty, count); the best needs teamDistinct>=2 and "
             "posDistinct>=2", (unsigned long long)g_trail_total, g_trail_count, g_v75_ascii_refused);

    for (int k = 0; k < n; k++) {
        int i = rank[k];
        char reason[64] = { 0 };
        int accepted = tnx_v75_trail_verdict(&g_trail[i], reason, sizeof(reason));

        tnx_logf("trail[%d] rank=%d mgr=%p count=%d cap=%d live=%d nonEmpty=%d ascii=%d/%d(%d%%) "
                 "teamDistinct=%d posDistinct=%d stable=%d raw=%c -> %s%s%s",
                 i, k, (void *)g_trail[i].manager, g_trail[i].count, g_trail[i].capacity,
                 g_trail[i].live, g_trail[i].nonEmpty, g_trail[i].ascii, g_trail[i].sampled,
                 g_trail[i].sampled > 0 ? (g_trail[i].ascii * 100) / g_trail[i].sampled : 0,
                 g_trail[i].teamDistinct, g_trail[i].posDistinct, g_trail[i].stable,
                 g_trail[i].rawSeg, accepted ? "ACCEPTED" : "REFUSED reason=",
                 accepted ? "" : reason, (i == g_trail_best) ? " <- best" : "");
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
    { "object+0x8 = global id (hypothesis)", "0x8", "addGameObject writes it; hop1 dump says +0x50" },
    { "object+0x20 = owner, 0xff5720 family only", "0x20", "setOwner is str x1,[x0,#0x20]; zero on 0xf9e248 elements, never identity" },
    { "object+0x3c = owner index", "0x3c", "REvengeBS" },
    { "object+0x40 = team (hypothesis)", "0x40", "engine loops read it; hop1 dump says +0x4c" },
    { "object+0xd0 = NOT a dead flag", "0xd0", "dump: 0..5 repeats +0x48, meaning unknown" },
    { "slot +0x18 = setOwner", "0x18", "addGameObject calls it with the manager in x1" },
    { "slot +0x28 = element type code", "0x28", "mov w0,#N; ret: 0/1/2/3/4/5/6/8 seen, the engine compares it" },
    { "slot +0x88 = float getter [x0+0x10]", "0x88", "ldr s0,[x0,#0x10]; ret, setter in slot +0x70" },
    { "slot +0x90 = float getter [x0+0x1c]", "0x90", "ldr s0,[x0,#0x1c]; ret, setter in slot +0x80" },
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
             "obj team=%#llx d0=%#llx gid=%#llx own=%#llx",
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
    tnx_logf("v100 best summary shown=%d instances=%d teams=%d/%d/%d/%d reasons: noArray=%d "
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
        int shown = 0;

        if (!tnx_trail_qualifies(i)) continue;

        shown = tnx_object_detail_readonly(g_trail[i].manager, TNX_BEST_DETAIL_MAX);

        if (shown > 0) {
            chosen = i;

            break;
        }
    }

    if (chosen < 0) {
        g_trail_best = -1;

        tnx_logf("v100 best not chosen: none of the %d recorded candidates both carries two teams and "
                 "two positions and yields a single instance - the reason is in the trail lines above",
                 n);

        return;
    }

    if (chosen != g_trail_best) {
        tnx_logf("v100 best moved from index %d to index %d: the higher-ranked candidate's summary "
                 "extracted nothing", g_trail_best, chosen);
    }

    g_trail_best = chosen;

    tnx_logf("v100 best candidate index=%d mgr=%p count=%d cap=%d live=%d nonEmpty=%d",
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
            tnx_logf("v100 setprediction fingerprint MISMATCH word[%d]=%08x expected=%08x at %#llx",
                     i, words[i], expected[i], (unsigned long long)TNX_RVA_SETPREDICTION);
            return 0;
        }
    }

    tnx_logf("v100 setprediction fingerprint verified at %#llx (str w1,[x0,#0x1d4]; str w2,[x0,#0x1d8]; "
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

        if (tnx_v75_element_ascii(entry.object)) {
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

        entry.gid = tnx_v106_gid(entry.object, NULL);

        if (!tnx_read_i32(entry.object + tnx_v57_coord_x_off(), &entry.x) ||
            !tnx_read_i32(entry.object + tnx_v57_coord_y_off(), &entry.y) ||
            !tnx_read_i32(entry.object + TNX_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
            !tnx_read_i32(entry.object + TNX_OBJ_TEAM_OFF, &entry.teamOld) ||
            !tnx_read_i32(entry.object + TNX_V91_TEAM_OFF, &entry.teamNew) ||
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
            if (g_v106_coord_logs < 6) {
                void *tvtable = NULL;
                uintptr_t tvtRva = 0;

                g_v106_coord_logs++;

                if (tnx_read_ptr(entry.object, &tvtable) && tvtable) tvtRva = (uintptr_t)tvtable - g_base;

                tnx_logf("v106 coord suspect elem=%p vtRva=%#llx +%#llx=%d +%#llx=%d gid=%d - this class "
                         "carries neither its id nor its coordinates where the walk looks for them, so "
                         "the row is dropped as rejOutOfRange and usable stays below two; turn "
                         "TNX_V106_COORD_SOFT on to let it through and let the per entry coord gate "
                         "downstream decide",
                         (void *)entry.object, (unsigned long long)tvtRva,
                         (unsigned long long)TNX_OBJ_X_OFF, entry.x,
                         (unsigned long long)TNX_OBJ_Y_OFF, entry.y, entry.gid);
            }

            if (!TNX_V106_COORD_SOFT) {
                g_v50_reject.rejOutOfRange++;
                bad++;

                continue;
            }
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
            tnx_logf("v100 fields manager=%p usable=0 rejected=%d -- all elements rejected: %s",
                     (void *)manager, rejected, tnx_v50_reject_text(reasons, sizeof(reasons)));
        } else {
            tnx_logf("v100 fields manager=%p usable=0 rejected=0 -- no elements in container",
                     (void *)manager);
        }

        return;
    }

    if (usable == 1) {
        char reasons[320];

        tnx_logf("v100 fields manager=%p usable=1 rejected=%d -- one element is not enough to tell "
                 "one field from another: %s",
                 (void *)manager, rejected, tnx_v50_reject_text(reasons, sizeof(reasons)));

        return;
    }

    n = (usable < TNX_V48_ELEMS) ? usable : TNX_V48_ELEMS;

    for (int i = 0; i < n; i++) {
        if (!tnx_read_bytes(objects[i].object, words[i], sizeof(words[i]))) {
            tnx_logf("v100 fields element %d at %p unreadable over 0x%x bytes",
                     i, (void *)objects[i].object, (unsigned)sizeof(words[i]));
            return;
        }
    }

    tnx_logf("v100 fields manager=%p usable=%d rejected=%d sample=%d window=+0x0..+0x%x",
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

        tnx_logf("v100 off +0x%02x distinct=%d/%d min=%lld max=%lld small=%d tiny=%d %s%s",
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
        tnx_logf("v100 walk error: teamOff=+0x%x equals the repository coordinate offset, so the "
                 "walk hit strings and not objects - the team offset is refused and left unset",
                 teamOff);

        teamOff = -1;
        teamDistinct = 0;
    }

    if (teamOff < 0) {
        tnx_logf("v100 teamOff unset after the walk, the engine's own +0x4c is used src=log-v55");
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

                tnx_logf("v100 coord pair int32 at +0x%02x,+0x%02x all %d distinct team=+0x%x "
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

        tnx_logf("v100 coord pair float32 at +0x%02x,+0x%02x first=(%.3f,%.3f) distinct=%d/%d",
                 w * 4, (w + 1) * 4, fx, fy, distinctPairs, n);
    }

    tnx_logf("v100 named teamOff=%s0x%x distinct=%d | coordOff=%s0x%x distinct=%d | "
             "intPair=%s0x%x | floatPair=%s0x%x",
             teamOff >= 0 ? "+" : "none:", teamOff >= 0 ? teamOff : 0, teamDistinct,
             coordOff >= 0 ? "+" : "none:", coordOff >= 0 ? coordOff : 0, coordDistinct,
             intPairOff >= 0 ? "+" : "none:", intPairOff >= 0 ? intPairOff : 0,
             floatPairOff >= 0 ? "+" : "none:", floatPairOff >= 0 ? floatPairOff : 0);

    g_v57_coord_off = (int)TNX_OBJ_X_OFF;

    if (!g_v89_coord_fixed_logged) {
        g_v89_coord_fixed_logged = 1;

        tnx_logf("v100 walk coord fixed +%#llx/+%#llx (was auto) - the walk reads x and y at those "
                  "two int32 and nowhere else; this block measured pair=+0x%x and single=+0x%x "
                  "and neither is applied any more, because the v88 run had the walk land on "
                  "+0x3c/+0x40 in the second battle while the same block printed +0x30/+0x34, "
                  "and that battle's pos= then read (owner index, team) as coordinates",
                 (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF,
                 intPairOff >= 0 ? intPairOff : 0, coordOff >= 0 ? coordOff : 0);
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
            tnx_logf("v100 raw[%d] element unreadable - the container cannot be walked at all", i);

            continue;
        }

        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &plus40);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAMENGINE_OFF, &plus4c);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        {
            uint8_t b_d4 = 0;

            tnx_read_u8((uintptr_t)element + TNX_V91_DEAD_OFF, &b_d4);

            tnx_logf("v100 raw[%d] %p gid=%d plus40=%d plus4c=%d d0=%u d4=%u - the two candidate "
                     "dead bytes side by side, so the run shows which one is 0/1 and which is 63",
                     i, (void *)element, gid, plus40, plus4c, (unsigned)dead, (unsigned)b_d4);
        }

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

    tnx_logf("v100 team probe raw=%d distinct(+0x40)=%d distinct(+0x4c)=%d", shown, oldDistinct,
             newDistinct);
}

static void tnx_v52_dead_probe(uintptr_t manager) {
    static const uintptr_t offsets[TNX_V72_DEAD_PROBE_COUNT] = { 0xc8, 0xcc, 0xd0, 0xd4, 0xd8 };
    static uint64_t calls = 0;
    void *array = NULL;
    int32_t count = 0;
    int zero[TNX_V72_DEAD_PROBE_COUNT] = { 0 };
    int one[TNX_V72_DEAD_PROBE_COUNT] = { 0 };
    int other[TNX_V72_DEAD_PROBE_COUNT] = { 0 };
    int bad[TNX_V72_DEAD_PROBE_COUNT] = { 0 };
    int skipped = 0;
    int shown = 0;
    int flag = -1;

    calls++;

    if ((calls % 5) != 1) return;
    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;

    if (count > TNX_V50_RAW_ELEMS) count = TNX_V50_RAW_ELEMS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        unsigned int bytes[TNX_V72_DEAD_PROBE_COUNT] = { 0 };

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element) || !element) {
            skipped++;

            continue;
        }

        if (!tnx_pointer_plausible((uintptr_t)element)) {
            skipped++;

            continue;
        }

        for (int k = 0; k < TNX_V72_DEAD_PROBE_COUNT; k++) {
            uint8_t byte = 0;

            if (!tnx_read_u8((uintptr_t)element + offsets[k], &byte)) {
                bad[k]++;

                continue;
            }

            bytes[k] = byte;

            if (byte == 0) zero[k]++;
            else if (byte == 1) one[k]++;
            else other[k]++;
        }

        shown++;

        tnx_logf("v100 dead probe elem[%d] %p c8=%02x cc=%02x d0=%02x d4=%02x d8=%02x", i,
                 (void *)element, bytes[0], bytes[1], bytes[2], bytes[3], bytes[4]);
    }

    if (!shown) {
        tnx_logf("v100 dead probe window: nothing measured - %d of %d elements are not plausible "
                 "pointers, so this container is not an object array and its byte columns mean "
                 "nothing", skipped, count);

        return;
    }

    tnx_logf("v100 dead probe window c8=%d/%d/%d/%d cc=%d/%d/%d/%d d0=%d/%d/%d/%d d4=%d/%d/%d/%d "
             "d8=%d/%d/%d/%d zero/one/other/unreadable of %d readable pointers src=B",
             zero[0], one[0], other[0], bad[0], zero[1], one[1], other[1], bad[1], zero[2], one[2],
             other[2], bad[2], zero[3], one[3], other[3], bad[3], zero[4], one[4], other[4], bad[4],
             shown);

    for (int k = 0; k < TNX_V72_DEAD_PROBE_COUNT; k++) {
        if (bad[k] == 0 && other[k] == 0 && one[k] > 0 && zero[k] > 0) flag = k;
    }

    if (flag >= 0) {
        tnx_logf("v100 dead probe verdict offset=%#llx splits %d readable pointers into %d zero and "
                 "%d one with no other value - this is the dead flag and it may be used",
                 (unsigned long long)offsets[flag], shown, zero[flag], one[flag]);
    } else {
        tnx_logf("v100 dead probe verdict: no offset at c8/cc/d0/d4/d8 behaves like a flag - each "
                 "one is either constant or takes values other than 0 and 1, so +0xd0 must not be "
                 "used as one and the dead byte is not in this window");
    }
}

static void tnx_v92_team_dump(const tnx_v47_obj_t *objects, int usable) {
    int limit = usable < TNX_V92_TEAM_DUMPS ? usable : TNX_V92_TEAM_DUMPS;

    for (int i = 0; i < limit; i++) {
        uint8_t bytes[16];
        int32_t i32_40 = 0;
        int32_t i32_44 = 0;
        int32_t i32_48 = 0;
        int32_t i32_4c = 0;

        if (!tnx_read_bytes(objects[i].object + TNX_OBJ_TEAM_OFF, bytes, sizeof(bytes))) continue;

        memcpy(&i32_40, bytes + 0, 4);
        memcpy(&i32_44, bytes + 4, 4);
        memcpy(&i32_48, bytes + 8, 4);
        memcpy(&i32_4c, bytes + 12, 4);

        tnx_logf("v100 teamdump elem[%d] +40..+50 = %02x %02x %02x %02x | %02x %02x %02x %02x | "
                 "%02x %02x %02x %02x | %02x %02x %02x %02x  i32: 40=%d 44=%d 48=%d 4c=%d  "
                 "byte@40=%u byte@48=%u byte@4c=%u byte@4d=%u",
                 i, bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14],
                 bytes[15], i32_40, i32_44, i32_48, i32_4c, (unsigned)bytes[0], (unsigned)bytes[8],
                 (unsigned)bytes[12], (unsigned)bytes[13]);
    }
}

static void tnx_v93_class_dump(const tnx_v47_obj_t *objects, int usable) {
    uintptr_t classes[TNX_V93_CLASS_DUMPS];
    int classCount = 0;

    if (g_v93_class_dumps >= TNX_V93_CLASS_DUMPS) return;

    for (int i = 0; i < usable && classCount < TNX_V93_CLASS_DUMPS; i++) {
        void *vt = NULL;
        uintptr_t rva = 0;
        int known = 0;

        if (!tnx_read_ptr(objects[i].object, &vt) || !vt) continue;
        if ((uintptr_t)vt < g_base) continue;

        rva = (uintptr_t)vt - g_base;

        for (int k = 0; k < classCount; k++) {
            if (classes[k] == rva) known = 1;
        }

        if (!known) classes[classCount++] = rva;
    }

    for (int c = 0; c < classCount; c++) {
        int shown = 0;

        g_v93_class_dumps++;

        for (int i = 0; i < usable && shown < 4; i++) {
            void *vt = NULL;
            uint64_t words[TNX_V93_CLASS_QWORDS];

            if (!tnx_read_ptr(objects[i].object, &vt) || !vt) continue;
            if ((uintptr_t)vt < g_base) continue;
            if ((uintptr_t)vt - g_base != classes[c]) continue;
            if (!tnx_read_bytes(objects[i].object + 0xc0ULL, words, sizeof(words))) continue;

            shown++;

            tnx_logf("v100 classdump class=%#llx elem[%d] gid=%d +c0=%#llx +c8=%#llx +d0=%#llx "
                     "+d8=%#llx - each class is dumped on its own line, so a projectile cannot "
                     "supply the value that decides whether a player is dead",
                     (unsigned long long)classes[c], i, objects[i].gid,
                     (unsigned long long)words[0], (unsigned long long)words[1],
                     (unsigned long long)words[2], (unsigned long long)words[3]);
        }

        if (!shown) {
            tnx_logf("v100 classdump class=%#llx has no element readable in this container",
                     (unsigned long long)classes[c]);
        }
    }
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

    g_v47_team_off = (int)TNX_OBJ_TEAM_OFF;

    {
        char reasons[320];

        tnx_logf("v100 man walk mode=%p manager=%p usable=%d rejected=%d (%s) mapOk=%d mapW=%d "
                 "mapH=%d inRange=%d distinct=%d teamsOld=%d teamsNew=%d teamOff=0x%x",
                 (void *)mode, (void *)manager, usable, rejected,
                 tnx_v50_reject_text(reasons, sizeof(reasons)), g_v47_map_ok, g_v47_map_w,
                 g_v47_map_h, inRange, distinct, distinctOld, distinctNew, g_v47_team_off);
    }

    tnx_logf("v100 walk team reverted to +0x%x with distinct(+0x40)=%d distinct(+0x4c)=%d - the "
             "v92 teamdump settled it: +0x40 is 1,1,0,0 on four elements while +0x4c reads 0,2,"
             "29535,0 and 29535 is the pair 0x5f 0x73, so +0x4c is an inline std::string and not a "
             "side; a distinct count above one is not proof, only the byte dump is",
             g_v47_team_off, distinctOld, distinctNew);

    tnx_logf("v100 walk offsets team=+0x%x distinctOld=%d distinctNew=%d coord=+0x%llx/+0x%llx "
             "usable=%d distinct=%d inRange=%d - both fixed constants, not chosen from a sample",
             g_v47_team_off, distinctOld, distinctNew,
             (unsigned long long)tnx_v57_coord_x_off(), (unsigned long long)tnx_v57_coord_y_off(),
             usable, distinct, inRange);

    tnx_v50_raw_team_probe(manager);

    if (!TNX_V113_DEAD_ONCE || !g_v113_dead_probe_done) {
        g_v113_dead_probe_done = 1;
        tnx_v52_dead_probe(manager);
    }

    if (verbose) {
        tnx_logf("v100 offsets obj off=0x%llx/0x%llx x=0x%llx y=0x%llx teamOld=0x%llx teamNew=0x%llx "
                 "owner=0x%llx dead=0x%llx active=0x%llx tilemap=0x%llx w=0x%llx",
                 TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF, TNX_OBJ_X_OFF, TNX_OBJ_Y_OFF,
                 TNX_OBJ_TEAM_OFF, TNX_OBJ_TEAMENGINE_OFF, TNX_OBJ_OWNERINDEX_OFF,
                 TNX_OBJ_DEADFLAG_OFF, TNX_OBJ_ACTIVEFLAG_OFF,
                 TNX_MODE_TILEMAP_OFF, TNX_TILEMAP_WIDTH_OFF);

        for (int i = 0; i < usable && i < 16; i++) {
            tnx_logf("v100 player[%02d] at=%p gid=%d pos=(%d,%d) team40=%d own=%d dead=%d active=%d "
                     "- pos is x and y read at +%#llx/+%#llx as int32, team40 is the side read at "
                     "+%#llx; neither is selected by a heuristic any more",
                     i, (void *)objects[i].object, objects[i].gid, objects[i].x, objects[i].y,
                     objects[i].teamOld, objects[i].ownerIndex, objects[i].dead,
                     objects[i].activeFlag & 1, (unsigned long long)TNX_OBJ_X_OFF,
                     (unsigned long long)TNX_OBJ_Y_OFF, (unsigned long long)TNX_OBJ_TEAM_OFF);
        }
    }

    g_v47_coord_usable = usable;
    g_v47_coord_distinct = distinct;

    {
        int unique = 0;

        for (int i = 0; i < usable; i++) {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].gid == objects[i].gid) {
                    seen = 1;
                    break;
                }
            }

            if (!seen) unique++;
        }

        tnx_logf("v100 gid unique=%d of usable=%d distinct=%d - below usable means the container "
                 "carries duplicate ids and anything grouped by gid groups the wrong elements",
                 unique, usable, distinct);
    }

    tnx_v92_team_dump(objects, usable);
    tnx_v93_class_dump(objects, usable);

    g_v47_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;

    tnx_logf("v100 coords ok=%d (need >=2 objects, all in range, >=2 distinct positions, "
             "and a team field that splits them)",
             g_v47_coord_ok);

    {
        int back = 0;
        int backRead = 0;

        for (int i = 0; i < usable; i++) {
            void *backPtr = NULL;

            if (!tnx_read_ptr(objects[i].object + TNX_V88_ELEM_BACK_OFF, &backPtr)) continue;

            backRead++;

            if ((uintptr_t)backPtr == manager) back++;
        }

        tnx_logf("v100 membership manager=%p usable=%d back=%d read=%d - [elem+%#llx] is the "
                 "membership test now: an element whose word there names the container belongs to "
                 "it, and the owner chain through owner+0 and owner+%#llx is no longer consulted",
                 (void *)manager, usable, back, backRead,
                 (unsigned long long)TNX_V88_ELEM_BACK_OFF,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);
    }
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

static int tnx_v90_slot_probe(void) {
    static const uintptr_t slots[TNX_V90_SLOTS] = { TNX_MODE_SLOT_A, TNX_MODE_SLOT_B,
                                                    TNX_MODE_SLOT_C };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    int hit = -1;

    if (!g_scene_object) return -1;
    if (!array || count <= 0) return -1;

    for (int i = 0; i < TNX_V90_SLOTS; i++) {
        void *value = NULL;
        void *vt = NULL;
        uintptr_t rva = 0;
        int inArray = 0;

        if (!tnx_read_ptr(g_scene_object + slots[i], &value) || !value) {
            if (!g_v90_slot_dumped) {
                tnx_logf("v100 modeslot +%#llx=null array=%p count=%d - the three words the mode "
                         "carries at +%#llx/+%#llx/+%#llx are tested against the container on "
                         "every tick until one of them points at an element",
                         (unsigned long long)slots[i], (void *)array, count,
                         (unsigned long long)TNX_MODE_SLOT_A, (unsigned long long)TNX_MODE_SLOT_B,
                         (unsigned long long)TNX_MODE_SLOT_C);
            }

            continue;
        }

        if ((uintptr_t)value > array && (uintptr_t)value < array + (uintptr_t)count * 8ULL) {
            inArray = 1;
            hit = i;
        }

        if (g_base && tnx_read_ptr((uintptr_t)value, &vt) && (uintptr_t)vt > g_base) {
            rva = (uintptr_t)vt - g_base;
        }

        if (!g_v90_slot_dumped) {
            tnx_logf("v100 modeslot +%#llx=%p vt=%#llx inArray=%d array=%p count=%d - inArray=1 "
                     "means this word is one of the container's own elements and so is the local "
                     "player, which is the own element the dodge has been unable to name",
                     (unsigned long long)slots[i], (void *)value, (unsigned long long)rva, inArray,
                     (void *)array, count);
        }
    }

    g_v90_slot_dumped = 1;

    return hit;
}

static int tnx_v91_mode_real(uintptr_t mode, uintptr_t *vtOut, uintptr_t *chainOut,
                             uintptr_t *innerOut) {
    void *vtable = NULL;
    void *chain = NULL;
    void *inner = NULL;
    uintptr_t rva = 0;

    if (vtOut) *vtOut = 0;
    if (chainOut) *chainOut = 0;
    if (innerOut) *innerOut = 0;

    if (!mode) return 0;
    if (!tnx_read_ptr(mode, &vtable) || !vtable) return 0;

    rva = (uintptr_t)vtable - g_base;

    if (vtOut) *vtOut = rva;
    if (rva < TNX_DC_RVA_LO || rva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &chain) || !chain) return 0;
    if (chainOut) *chainOut = (uintptr_t)chain;

    if (!g_players_object) return 0;
    if ((uintptr_t)chain == g_players_object) return 1;

    if (!tnx_read_ptr((uintptr_t)chain + TNX_V82_CLIENT_HOP_OFF, &inner) || !inner) return 0;
    if (innerOut) *innerOut = (uintptr_t)inner;

    if ((uintptr_t)inner == g_players_object) return 1;

    return 0;
}

static int tnx_v95_finite(float v) {
    if (v != v) return 0;
    if (v <= -1.0e9f) return 0;
    if (v >= 1.0e9f) return 0;

    return 1;
}

static void tnx_v95_joy_dump(uintptr_t base, const char *what) {
    float a8ac = 0.0f;
    float cosv = 0.0f;
    float sinv = 0.0f;
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    uint8_t raw[2];
    unsigned state = 0;

    if (!base) return;

    tnx_read_f32(base + 0x8acULL, &a8ac);
    tnx_read_f32(base + 0x8f4ULL, &cosv);
    tnx_read_f32(base + 0x8f8ULL, &sinv);
    tnx_read_f32(base + 0x9b8ULL, &ax);
    tnx_read_f32(base + 0x9bcULL, &ay);
    tnx_read_f32(base + 0x9c0ULL, &bx);
    tnx_read_f32(base + 0x9c4ULL, &by);

    if (tnx_read_bytes(base + 0xed7ULL, raw, sizeof(raw))) {
        state = (unsigned)(raw[0] | ((uint16_t)raw[1] << 8));
    }

    tnx_logf("v100 joy %s=%p a8ac=%.3f cos=%.3f sin=%.3f A=(%.3f,%.3f) B=(%.3f,%.3f) state=%u - "
             "the offsets the JS build reads are read here on this object as floats, so a run "
             "shows whether this build keeps the joystick in the same window", what, (void *)base,
             a8ac, cosv, sinv, ax, ay, bx, by, state);
}

static void tnx_v95_find_joy(uintptr_t scene) {
    if (!scene) return;

    for (uintptr_t off = 0; off < 0x1000; off += 8) {
        void *child = NULL;
        float ax = 0.0f;
        float ay = 0.0f;
        float bx = 0.0f;
        float by = 0.0f;
        float cosv = 0.0f;
        float sinv = 0.0f;

        if (!tnx_read_ptr(scene + off, &child) || !child) continue;
        if (!tnx_heap_contains((uintptr_t)child)) continue;
        if (!tnx_read_f32((uintptr_t)child + 0x9b8ULL, &ax)) continue;
        if (!tnx_read_f32((uintptr_t)child + 0x9bcULL, &ay)) continue;
        if (!tnx_read_f32((uintptr_t)child + 0x9c0ULL, &bx)) continue;
        if (!tnx_read_f32((uintptr_t)child + 0x9c4ULL, &by)) continue;
        if (!tnx_read_f32((uintptr_t)child + 0x8f4ULL, &cosv)) continue;
        if (!tnx_read_f32((uintptr_t)child + 0x8f8ULL, &sinv)) continue;

        if (!tnx_v95_finite(ax) || !tnx_v95_finite(ay)) continue;
        if (!tnx_v95_finite(bx) || !tnx_v95_finite(by)) continue;
        if (!tnx_v95_finite(cosv) || !tnx_v95_finite(sinv)) continue;

        tnx_logf("v100 findjoy scene+%#llx -> %p A=(%.3f,%.3f) B=(%.3f,%.3f) cos=%.3f sin=%.3f - a "
                 "heap pointer of the scene whose joystick window reads as finite floats, which "
                 "is the object the JS build writes", (unsigned long long)off, child, ax, ay, bx,
                 by, cosv, sinv);
    }
}

static int tnx_v98_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell,
                             const uint8_t *solid, int gw, int gh, int32_t *outX, int32_t *outY) {
    int32_t cx = 0;
    int32_t cy = 0;
    int32_t stepX = 0;
    int32_t stepY = 0;
    int32_t spanX = 0;
    int32_t spanY = 0;
    float tDeltaX = 0.0f;
    float tDeltaY = 0.0f;
    float tMaxX = 2.0f;
    float tMaxY = 2.0f;

    if (outX) *outX = bx;
    if (outY) *outY = by;

    /* cell is divided before it was ever checked in v98, and the check four lines below was dead
       for that parameter: a caller that passes a zero cell divided by zero first. The guard now
       runs before the divisions, which is the only order in which it guards anything. */
    if (!solid || cell <= 0) return 0;

    cx = ax / cell;
    cy = ay / cell;
    stepX = (bx > ax) ? 1 : ((bx < ax) ? -1 : 0);
    stepY = (by > ay) ? 1 : ((by < ay) ? -1 : 0);
    spanX = (bx > ax) ? (bx - ax) : (ax - bx);
    spanY = (by > ay) ? (by - ay) : (ay - by);

    if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) return 0;

    if (solid[cx + cy * gw]) {
        if (outX) *outX = ax;
        if (outY) *outY = ay;

        return 1;
    }

    if (stepX != 0 && spanX > 0) {
        tDeltaX = (float)cell / (float)spanX;
        tMaxX = (float)((stepX > 0) ? ((cx + 1) * cell - ax) : (ax - cx * cell)) / (float)spanX;
    }

    if (stepY != 0 && spanY > 0) {
        tDeltaY = (float)cell / (float)spanY;
        tMaxY = (float)((stepY > 0) ? ((cy + 1) * cell - ay) : (ay - cy * cell)) / (float)spanY;
    }

    for (int guard = 0; guard < 4096; guard++) {
        float t = (tMaxX < tMaxY) ? tMaxX : tMaxY;

        if (t > 1.0f) break;

        if (tMaxX < tMaxY) {
            cx += stepX;
            tMaxX += tDeltaX;
        } else {
            cy += stepY;
            tMaxY += tDeltaY;
        }

        if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) break;

        if (solid[cx + cy * gw]) {
            if (outX) *outX = ax + (int32_t)((float)(bx - ax) * t);
            if (outY) *outY = ay + (int32_t)((float)(by - ay) * t);

            return 1;
        }
    }

    return 0;
}

static void tnx_v98_clip_selftest(void) {
    uint8_t grid[TNX_V98_GRID * TNX_V98_GRID];
    int32_t ox = 0;
    int32_t oy = 0;
    int hit = 0;

    memset(grid, 0, sizeof(grid));

    for (int i = 0; i < TNX_V98_GRID; i++) grid[3 + i * TNX_V98_GRID] = 1;

    hit = tnx_v98_clip_walk(100, 100, 700, 100, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 1 && ox == 300 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case1 hit=%d out=(%d,%d) want=(300,100) - a segment crossing one wall cell "
             "must stop on its near edge", hit, ox, oy);

    hit = tnx_v98_clip_walk(500, 100, 700, 100, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 0 && ox == 700 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case2 hit=%d out=(%d,%d) want=(700,100) - a segment that meets no wall must "
             "keep its far end", hit, ox, oy);

    hit = tnx_v98_clip_walk(350, 100, 700, 100, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 1 && ox == 350 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case3 hit=%d out=(%d,%d) want=(350,100) - a segment starting inside a wall "
             "must clip to its own start", hit, ox, oy);

    hit = tnx_v98_clip_walk(100, 100, 100, 700, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 0 && ox == 100 && oy == 700) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case4 hit=%d out=(%d,%d) want=(100,700) - a vertical segment away from the "
             "wall must not be clipped", hit, ox, oy);

    ox = 0;
    oy = 0;

    hit = tnx_v98_clip_walk(100, 100, 700, 100, 0, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 0 && ox == 700 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case5 hit=%d out=(%d,%d) want=(700,100) - a zero cell must return before "
             "anything is divided by it and leave the far end in place, which is the guard v98 "
             "placed after the division it guards", hit, ox, oy);

    tnx_logf("v100 clip selftest pass=%d fail=%d - the clipping that the threat segment needs is "
             "exercised on a synthetic grid before it is ever pointed at the real tilemap, so a "
             "clipped range can be trusted the day an actuator exists", g_v98_clip_pass,
             g_v98_clip_fail);
}

static int tnx_v97_moved(void) {
    void *array = NULL;
    int32_t count = 0;
    int moved = 0;

    if (!g_players_object) return 0;
    if (!tnx_read_ptr(g_players_object + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0) return 0;
    if (count > TNX_V97_MOVE_MAX) count = TNX_V97_MOVE_MAX;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t x = 0;
        int32_t y = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &x)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &y)) continue;

        if (g_v97_pos_n == (int)count) {
            if (g_v97_pos_x[i] != x || g_v97_pos_y[i] != y) moved++;
        }

        g_v97_pos_x[i] = x;
        g_v97_pos_y[i] = y;
    }

    if (g_v97_pos_n != (int)count) g_v97_pos_n = (int)count;

    return moved;
}

static void tnx_v97_group(uintptr_t base, const uint32_t *now, const uint32_t *prev,
                          const int *spots, int from, int to, int *budget) {
    float f0 = 0.0f;
    float f1 = 0.0f;
    int start = spots[from];
    int end = spots[to];
    int len = to - from + 1;
    int quiet = 1;

    float first = 0.0f;
    float last = 0.0f;
    uint32_t a = prev[start];
    uint32_t b = now[start];

    memcpy(&f0, &a, 4);
    memcpy(&f1, &b, 4);
    memcpy(&first, &prev[start], 4);
    memcpy(&last, &now[start], 4);

    for (int k = 1; k <= TNX_V97_QUIET; k++) {
        if (start - k < 0) break;
        if (now[start - k] != prev[start - k]) quiet = 0;
    }

    for (int k = 1; k <= TNX_V97_QUIET; k++) {
        if (end + k >= TNX_V99_FLOATS) break;
        if (now[end + k] != prev[end + k]) quiet = 0;
    }

    if (*budget <= 0) return;

    *budget -= 1;

    tnx_logf("v100 group base=%p start=+%#x len=%d quiet=%d first %.4f -> %.4f last %.4f -> %.4f - "
             "a run of adjacent slots that moved, and quiet means the %d slots on both sides stood "
             "still, which is what separates a vector from a buffer", (void *)base, start * 4, len,
             quiet, first, last, f0, f1, TNX_V97_QUIET);

    if (len >= 2 && len <= TNX_V97_GROUPS_MAXLEN) {
        for (int k = from; k + 1 <= to; k++) {
            float x0 = 0.0f;
            float y0 = 0.0f;
            float sum = 0.0f;
            int i = spots[k];

            if (spots[k + 1] != i + 1) continue;

            memcpy(&x0, &now[i], 4);
            memcpy(&y0, &now[i + 1], 4);
            if (!tnx_v95_finite(x0) || !tnx_v95_finite(y0)) continue;

            sum = x0 * x0 + y0 * y0;

            if (sum > 1.0f - TNX_V97_COSSIN_TOL && sum < 1.0f + TNX_V97_COSSIN_TOL) {
                tnx_logf("v100 rotation base=%p +%#x +%#x cos=%.4f sin=%.4f sum=%.4f - the pair is "
                         "two CHANGED slots that are strictly adjacent, so a normalised vector "
                         "elsewhere in the window cannot raise this line",
                         (void *)base, i * 4, (i + 1) * 4, x0, y0, sum);
            }
        }
    }
}

static void tnx_v96_tick(void) {
    uintptr_t bases[TNX_V96_BASES];
    int baseCount = 0;
    int moved = 0;

    if (!g_scene_object) return;

    moved = tnx_v97_moved();

    if (moved <= 0 && g_v98_force_due == 0 && g_v50_ticks != 0 &&
        (g_v50_ticks - g_v98_last_sample) >= TNX_V98_FORCE_SECS) {
        g_v98_force_due = 1;

        tnx_logf("v100 forced sample after %llu seconds without movement - a player holding the "
                 "stick into a wall does not move, and the joystick state is at its most "
                 "interesting exactly then", (unsigned long long)(g_v50_ticks - g_v98_last_sample));
    }

    if (moved <= 0 && !g_v98_force_due) {
        if (!g_v97_held) {
            g_v97_held = 1;

            tnx_logf("v100 sample held: no element of the container moved since the previous "
                     "sample, so the windows are not compared this tick - a clock does not prove "
                     "that a still window is not the joystick");
        }

        return;
    }

    if (g_v97_held) {
        g_v97_held = 0;
        g_v98_force_due = 0;

        for (int i = 0; i < TNX_V96_BASES; i++) g_v96[i].have = 0;

        tnx_logf("v100 sample resumed with %d elements having moved: every snapshot is dropped, so "
                 "the next comparison is against a fresh baseline and not against a window that is "
                 "N seconds old", moved);
    }

    g_v98_last_sample = g_v50_ticks;

    bases[baseCount++] = g_scene_object;

    {
        void *client = NULL;

        if (tnx_read_ptr(g_scene_object + TNX_MODE_MANAGER_OFF, &client) && client) {
            bases[baseCount++] = (uintptr_t)client;
        }
    }

    {
        void *inputMgr = NULL;

        if (tnx_read_ptr(g_scene_object + TNX_MODE_INPUTMGR_OFF, &inputMgr) && inputMgr &&
            tnx_heap_contains((uintptr_t)inputMgr)) {
            int known = 0;

            for (int k = 0; k < baseCount; k++) {
                if (bases[k] == (uintptr_t)inputMgr) known = 1;
            }

            if (!known && baseCount < TNX_V96_BASES) {
                bases[baseCount++] = (uintptr_t)inputMgr;

                if (g_v99_inputmgr_logs < 4) {
                    g_v99_inputmgr_logs++;

                    tnx_logf("v100 inputmgr base=%p vt=%#llx from scene+%#llx is base[%d] of %d - the "
                             "manager the movement command is sent through is sampled as its own "
                             "window, because the v98 rotation pair landed on it and not on the "
                             "scene", inputMgr,
                             (unsigned long long)tnx_vtable_rva(inputMgr),
                             (unsigned long long)TNX_MODE_INPUTMGR_OFF, baseCount - 1,
                             TNX_V96_BASES);
                }
            }
        }
    }

    for (int i = 0; i < TNX_SLOT_COUNT && baseCount < TNX_V96_BASES; i++) {
        uintptr_t self = g_slot_object[i];
        int known = 0;

        if (!self) continue;
        if (!g_slot_specs[i].shortTag) continue;
        if (g_slot_specs[i].shortTag[0] != 'V') continue;
        if (!tnx_heap_contains(self)) continue;

        for (int k = 0; k < baseCount; k++) {
            if (bases[k] == self) known = 1;
        }

        if (!known) bases[baseCount++] = self;
    }

    for (uintptr_t off = 0; off < 0x800 && baseCount < TNX_V96_BASES; off += 8) {
        void *child = NULL;
        int known = 0;

        if (!tnx_read_ptr(g_scene_object + off, &child) || !child) continue;
        if (!tnx_heap_contains((uintptr_t)child)) continue;

        for (int i = 0; i < baseCount; i++) {
            if (bases[i] == (uintptr_t)child) known = 1;
        }

        if (!known) bases[baseCount++] = (uintptr_t)child;
    }

    g_v96_lines = 0;

    {
        int sampledBases = 0;
        int changedBases = 0;

    for (int b = 0; b < baseCount; b++) {
        tnx_v96_slot_t *slot = NULL;
        uint32_t now[TNX_V99_FLOATS];
        int spots[TNX_V97_CHANGED_MAX];
        int changed = 0;
        int groups = 0;

        for (int i = 0; i < TNX_V96_BASES; i++) {
            if (g_v96[i].used && g_v96[i].base == bases[b]) slot = &g_v96[i];
        }

        if (!slot) {
            for (int i = 0; i < TNX_V96_BASES; i++) {
                if (g_v96[i].used) continue;

                g_v96[i].used = 1;
                g_v96[i].base = bases[b];
                g_v96[i].have = 0;
                slot = &g_v96[i];

                break;
            }
        }

        if (!slot) break;
        if (!tnx_read_bytes(bases[b], now, sizeof(now))) continue;

        if (!slot->have) {
            memcpy(slot->prev, now, sizeof(now));
            slot->have = 1;

            continue;
        }

        sampledBases++;

        for (int i = 0; i < TNX_V99_FLOATS; i++) {
            if (now[i] == slot->prev[i]) continue;

            if (changed < TNX_V97_CHANGED_MAX) spots[changed] = i;

            changed++;
        }

        if (changed == 0) {
            memcpy(slot->prev, now, sizeof(now));

            continue;
        }

        {
            int budget = TNX_V97_GROUPS;
            int from = 0;

            for (int k = 1; k <= (changed < TNX_V97_CHANGED_MAX ? changed : TNX_V97_CHANGED_MAX);
                 k++) {
                int total = (changed < TNX_V97_CHANGED_MAX) ? changed : TNX_V97_CHANGED_MAX;
                int boundary = (k == total);

                if (!boundary) {
                    if (spots[k] - spots[k - 1] <= TNX_V97_GROUP_GAP + 1) continue;
                }

                if (k - from >= TNX_V97_GROUP_MIN) {
                    groups++;

                    tnx_v97_group(bases[b], now, slot->prev, spots, from, k - 1, &budget);
                }

                from = k;
            }
        }

        if (changed > 0) changedBases++;

        if (changed > 0 && g_v96_lines < TNX_V96_LINES) {
            g_v96_lines++;

            tnx_logf("v100 window base=%p span=%#x changed=%d groups=%d first=+%#x moved=%d - the "
                     "sample is taken only while the container moves, so a still window here means "
                     "here means the state is not in this object, not that the player was idle",
                     (void *)bases[b], (unsigned)TNX_V99_SPAN, changed, groups,
                     (changed > 0 && changed < TNX_V97_CHANGED_MAX) ? spots[0] * 4 : 0, moved);
        }

        memcpy(slot->prev, now, sizeof(now));
    }

        if (sampledBases > 0 && changedBases == 0) {
            g_v99_static_samples++;

            if (g_v99_static_samples <= TNX_V96_LINES) {
                tnx_logf("v100 sample static bases=%d of %d moved=%d forced=%d tick=%llu - every "
                         "compared window is byte-identical this second, and this line is the only "
                         "place that says so, because a base with changed=0 prints no window line "
                         "at all: a static second was invisible in the v98 log",
                         sampledBases, baseCount, moved, g_v98_force_due,
                         (unsigned long long)g_v50_ticks);
            }
        }
    }
}

static void tnx_v99_inputmgr_probe(void) {
    void *inputMgr = NULL;
    float wasX = 0.0f;
    float wasY = 0.0f;
    float nowX = 0.0f;
    float nowY = 0.0f;

    if (!TNX_V99_INPUTMGR_WRITE) return;
    if (!g_scene_object) return;
    if (g_v99_inputmgr_last_tick == g_v50_ticks) return;

    if (!tnx_read_ptr(g_scene_object + TNX_MODE_INPUTMGR_OFF, &inputMgr) || !inputMgr) return;
    if (!tnx_heap_contains((uintptr_t)inputMgr)) return;

    tnx_read_f32((uintptr_t)inputMgr + TNX_V99_INPUTMGR_COS_OFF, &wasX);
    tnx_read_f32((uintptr_t)inputMgr + TNX_V99_INPUTMGR_SIN_OFF, &wasY);

    if (!tnx_v95_finite(wasX) || !tnx_v95_finite(wasY)) return;

    g_v99_inputmgr_last_tick = g_v50_ticks;

    if (!tnx_write_f32((uintptr_t)inputMgr + TNX_V99_INPUTMGR_COS_OFF,
                       (float)TNX_V99_INPUTMGR_WRITE_X) ||
        !tnx_write_f32((uintptr_t)inputMgr + TNX_V99_INPUTMGR_SIN_OFF,
                       (float)TNX_V99_INPUTMGR_WRITE_Y)) {
        return;
    }

    g_v99_inputmgr_writes++;

    tnx_read_f32((uintptr_t)inputMgr + TNX_V99_INPUTMGR_COS_OFF, &nowX);
    tnx_read_f32((uintptr_t)inputMgr + TNX_V99_INPUTMGR_SIN_OFF, &nowY);

    {
        int kept = (nowX == (float)TNX_V99_INPUTMGR_WRITE_X &&
                    nowY == (float)TNX_V99_INPUTMGR_WRITE_Y) ? 1 : 0;

        tnx_logf("v100 inputmgr write #%llu inputMgr=%p +%#llx %+.4f -> %+.4f, +%#llx %+.4f -> "
                 "%+.4f kept=%d - the pair the v98 rotation line landed on is written here by a "
                 "plain store, because the mach call the v99 build used is declared in a header "
                 "this file does not include and broke the CI compile; kept is the read-back of the "
                 "two words and is the only failure signal a store can give, and the answer to the "
                 "real question is in the next sample resumed line of this run: an element that "
                 "moves afterwards makes this the actuator, and a container that stays put makes it "
                 "a read-only copy",
                 (unsigned long long)g_v99_inputmgr_writes, inputMgr,
                 (unsigned long long)TNX_V99_INPUTMGR_COS_OFF, wasX, nowX,
                 (unsigned long long)TNX_V99_INPUTMGR_SIN_OFF, wasY, nowY, kept);
    }
}

static void tnx_v91_scalar_dump(uintptr_t mode, uintptr_t client) {
    int32_t variation = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t ec = 0;

    if (g_v91_scan_container != (uintptr_t)g_players_array) return;
    if (!mode) return;

    tnx_read_i32(mode + TNX_MODE_MODEVAR_OFF, &variation);
    tnx_read_i32(mode + TNX_MODE_PREDICTX_OFF, &px);
    tnx_read_i32(mode + TNX_MODE_PREDICTY_OFF, &py);
    tnx_read_i32(mode + 0xecULL, &ec);

    tnx_logf("v100 scalars mode+%#llx=%d mode+%#llx=%d mode+%#llx=%d mode+0xec=%d client=%p "
             "container=%p - the mode variation, the prediction pair and the mode int the sig walk "
             "compares, printed in the same run as the own scan",
             (unsigned long long)TNX_MODE_MODEVAR_OFF, variation,
             (unsigned long long)TNX_MODE_PREDICTX_OFF, px,
             (unsigned long long)TNX_MODE_PREDICTY_OFF, py, ec, (void *)client,
             (void *)g_players_object);
}


static int tnx_v101_word(uintptr_t address, uint32_t *out) {
    if (!out) return 0;
    if (address & 3ULL) return 0;

    return tnx_read_bytes(address, out, sizeof(*out)) ? 1 : 0;
}

static int tnx_v101_is_term(uint32_t w) {
    if ((w & 0xFFFFFC1Fu) == 0xD65F0000u) return 1;
    if ((w & 0xFFFFFC1Fu) == 0xD61F0000u) return 1;
    if (w == 0xD69F03E0u) return 1;
    if ((w & 0xFC000000u) == 0x14000000u) return 1;

    return 0;
}

static int tnx_v101_is_prologue(uint32_t w) {
    if (w == 0xD503237Fu || w == 0xD503233Fu) return 1;
    if ((w & 0xFFFFFF1Fu) == 0xD503241Fu) return 1;
    if ((w & 0xFF800000u) == 0xA9800000u && ((w >> 5) & 31u) == 31u) return 1;
    if ((w & 0xFF8003FFu) == 0xD10003FFu) return 1;

    return 0;
}

static uintptr_t tnx_v101_entry(uintptr_t rva) {
    uint32_t self = 0;
    uint32_t prev = 0;

    if (!g_base || !rva) return 0;
    if (!tnx_v101_word(g_base + rva, &self)) return 0;
    if (self == 0) return 0;

    if (tnx_v101_is_prologue(self)) return g_base + rva;
    if (!tnx_v101_word(g_base + rva - 4, &prev)) return 0;
    if (tnx_v101_is_term(prev)) return g_base + rva;

    return 0;
}

static void tnx_v101_rva_audit(void) {
    static const struct { const char *name; uintptr_t rva; } t[] = {
        { "getTeamStars", TNX_V101_GETTEAMSTARS_RVA },
        { "modePairSetter", TNX_V101_MODEPAIRSET_RVA },
        { "getOwnCharacter", RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER },
        { "getOwnPlayerTeam", RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM },
        { "setClientPredictionMoveTo", RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO },
        { "objMgrClient_getGameObjects", RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS },
        { "objMgrClient_findGameObject", RVA_LOGICGAMEOBJECTMANAGERCLIENT__FINDGAMEOBJECT },
        { "objClient_getGlobalID", RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID },
        { "objClient_getX", RVA_LOGICGAMEOBJECTCLIENT_GETX },
        { "objClient_getY", RVA_LOGICGAMEOBJECTCLIENT_GETY },
        { "battleMode_getInstance", RVA_BATTLEMODE_GETINSTANCE },
        { "gameStateManager_isState", RVA_GAMESTATEMANAGER__ISSTATE },
        { "messageManager_receiveMessage", RVA_MESSAGEMANAGER__RECEIVEMESSAGE },
        { "stage_addChild", RVA_STAGE_ADDCHILD },
        { NULL, 0 }
    };
    int i;

    if (g_v101_audited || !g_base) return;

    g_v101_audited = 1;

    tnx_logf("v101 rva audit: word is the four bytes at the rva, prev the four bytes before it - "
             "prologue says whether that word opens a frame, term says whether prev ends the "
             "previous function, entry means either of the two holds, callable is the engine's own "
             "stricter test, so a row with entry=yes callable=no is a leaf function the engine "
             "refuses and a row with entry=no is an rva inside another function that no call can "
             "ever reach");

    for (i = 0; t[i].name; i++) {
        uintptr_t a = g_base + t[i].rva;
        uint32_t w = 0;
        uint32_t wm = 0;
        const char *rule = tnx_prologue_rule(a);

        tnx_v101_word(a, &w);
        tnx_v101_word(a - 4, &wm);

        tnx_logf("v101 rva audit %-26s rva=%#llx word=%#x prev=%#x prologue=%s term=%d "
                 "entry=%s callable=%s",
                 t[i].name, (unsigned long long)t[i].rva, (unsigned)w, (unsigned)wm,
                 rule ? rule : "?", tnx_v101_is_term(wm),
                 tnx_v101_entry(t[i].rva) ? "yes" : "no",
                 (tnx_callable(t[i].rva) && tnx_looks_like_start(a)) ? "yes" : "no");
    }
}

static void tnx_v101_head_dump(void) {
    int i;

    if (g_v101_head_logs || !g_players_object) return;

    g_v101_head_logs = 1;

    tnx_logf("v101 head dump container=%p - the five floats the group walk reported as a rising "
             "run are read here as qwords and as float pairs so the timer verdict is not taken "
             "from a single reading",
             (void *)g_players_object);

    for (i = 0; i < 5; i++) {
        uint64_t q = tnx_v68_word(g_players_object + 0x80ULL + (uintptr_t)i * 8ULL);
        uint32_t lo = (uint32_t)(q & 0xffffffffULL);
        uint32_t hi = (uint32_t)(q >> 32);
        float flo = 0.0f;
        float fhi = 0.0f;

        memcpy(&flo, &lo, sizeof(flo));
        memcpy(&fhi, &hi, sizeof(fhi));

        tnx_logf("v101 head dump +%#x qword=%#llx lo=%#x hi=%#x asfloat=(%.4f, %.4f)",
                 0x80 + i * 8, (unsigned long long)q, (unsigned)lo, (unsigned)hi, flo, fhi);
    }
}

static void tnx_v101_actuator(uintptr_t mode, int x, int y);

static void tnx_v101_own_index_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    int taken = 0;
    int chosen = -1;
    int b;

    if (!array || count <= 0) return;

    cand[0] = (uintptr_t)g_players_object;
    cand[1] = (uintptr_t)g_scene_object;

    for (b = 0; b < 2; b++) {
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        void *elem = NULL;
        int hit = 0;

        if (!cand[b]) continue;
        if (!tnx_read_i32(cand[b] + TNX_V101_OWNIDX_OFF, &idx)) continue;

        tnx_read_i32(cand[b] + TNX_V101_OWNTEAM_OFF, &team);

        if (idx >= 0 && idx < count) {
            if (tnx_read_ptr(array + (uintptr_t)idx * 8ULL, &elem) && elem) hit = 1;
        }

        if (hit) {
            if (tnx_read_i32((uintptr_t)elem + TNX_V101_ELEM_ID_OFF, &eid) &&
                tnx_read_i32((uintptr_t)elem + TNX_V101_ELEM_TEAM_OFF, &eteam)) {
                g_v101_own_idhit = (eid == idx) ? 1 : 0;
            }
        }

        if (g_v101_own_logs < TNX_V101_OWN_LOGS) {
            g_v101_own_logs++;

            tnx_logf("v101 own-index base=%-9s at=%p +%#llx=%d +%#llx=%d count=%d array=%p "
                     "elem=%p elem+%#llx=%d elem+%#llx=%d idHit=%d verdict=%s - the class that "
                     "owns the object array keeps the own slot as an int, indexes its own array "
                     "with it and resets it to -1, so no pointer into the array has to exist in "
                     "any field for own to be resolvable",
                     cname[b], (void *)cand[b], (unsigned long long)TNX_V101_OWNIDX_OFF, idx,
                     (unsigned long long)TNX_V101_OWNTEAM_OFF, team, count, (void *)array, elem,
                     (unsigned long long)TNX_V101_ELEM_ID_OFF, eid,
                     (unsigned long long)TNX_V101_ELEM_TEAM_OFF, eteam, g_v101_own_idhit,
                     hit ? "index-taken" : "index-rejected");
        }

        if (hit && !taken) {
            taken = 1;
            chosen = b;
            g_v101_own_index = idx;
            g_v101_own_ptr = (uintptr_t)elem;
            g_v101_own_team = team;
            g_v101_own_from = (b == 0) ? "container+e0" : "scene+e0";
        }
    }

    if (!taken) {
        g_v101_own_index = -1;
        g_v101_own_ptr = 0;
        g_v101_own_from = "index-miss";
    }

    tnx_v101_head_dump();

    if (TNX_V101_ACTUATOR && taken) {
        tnx_v101_actuator(chosen == 0 ? (uintptr_t)g_players_object : (uintptr_t)g_scene_object,
                          0, 0);
    }
}

static void tnx_v101_wide_scan(void) {
    uintptr_t bases[4];
    static const char *names[4] = { "container", "mode", "client", "inputMgr" };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    int b;
    int i;

    if (!array || count <= 0) return;
    if (g_v101_wide_runs >= TNX_V101_WIDE_ATTEMPTS) return;

    g_v101_wide_runs++;

    bases[0] = g_players_object;
    bases[1] = (uintptr_t)g_scene_object;
    bases[2] = 0;
    bases[3] = 0;

    if (g_scene_object) {
        void *hop = NULL;

        if (tnx_read_ptr((uintptr_t)g_scene_object + TNX_MODE_MANAGER_OFF, &hop) && hop) {
            bases[2] = (uintptr_t)hop;
        }

        hop = NULL;

        if (tnx_read_ptr((uintptr_t)g_scene_object + TNX_MODE_INPUTMGR_OFF, &hop) && hop) {
            bases[3] = (uintptr_t)hop;
        }
    }

    tnx_logf("v101 wide scan run=%d window=%#x bases container=%p mode=%p client=%p inputMgr=%p "
             "array=%p count=%d - the container itself is scanned too and the window is the one "
             "the v100 run asked for instead of %#x",
             g_v101_wide_runs, TNX_V101_WIDE_QWORDS * 8, (void *)bases[0], (void *)bases[1],
             (void *)bases[2], (void *)bases[3], (void *)array, count, TNX_V99_SCAN_QWORDS * 8);

    for (b = 0; b < 4; b++) {
        if (!bases[b]) continue;

        for (i = 0; i < TNX_V101_WIDE_QWORDS; i++) {
            uintptr_t off = (uintptr_t)i * 8ULL;
            uintptr_t value = (uintptr_t)tnx_v68_word(bases[b] + off);
            uintptr_t index = 0;

            if (!value) continue;
            if (value <= array) continue;
            if (value >= array + (uintptr_t)count * 8ULL) continue;
            if ((value - array) % 8ULL) continue;

            index = (value - array) / 8ULL;
            g_v101_wide_hits++;

            if (g_v101_wide_hits <= 8) {
                tnx_logf("v101 wide scan %s+%#llx = %p is element[%llu] of array=%p count=%d - a "
                         "word that points into the container, taken only after the narrow pass "
                         "came back empty",
                         names[b], (unsigned long long)off, (void *)value,
                         (unsigned long long)index, (void *)array, count);
            }

            if (g_v101_own_index < 0) {
                g_v101_own_index = (int)index;
                g_v101_own_ptr = value;
                g_v101_own_from = "wide";
            }
        }
    }

    if (!g_v101_wide_hits && !g_v101_miss_logs) {
        g_v101_miss_logs = 1;

        tnx_logf("v101 wide scan nothing in container+0x00..+%#x, mode+0x00..+%#x, "
                 "client+0x00..+%#x or inputMgr+0x00..+%#x points into array=%p count=%d - own is "
                 "then not reachable as a pointer at all and only the index route at +%#llx can "
                 "name it",
                 TNX_V101_WIDE_QWORDS * 8, TNX_V101_WIDE_QWORDS * 8, TNX_V101_WIDE_QWORDS * 8,
                 TNX_V101_WIDE_QWORDS * 8, (void *)array, count,
                 (unsigned long long)TNX_V101_OWNIDX_OFF);
    }
}

static void tnx_v101_actuator(uintptr_t mode, int x, int y) {
    if (!TNX_V101_ACTUATOR) return;
    if (!mode || !g_v101_setpred) return;

    ((void (*)(void *, int, int, int))g_v101_setpred)((void *)mode, x, y, 1);
}


static int tnx_write_i32(uintptr_t address, int32_t value) {
    if (address & 3) return 0;

    return tnx_write_bytes(address, &value, sizeof(value)) ? 1 : 0;
}

static int tnx_v102_elem_verdict(uintptr_t elem, char *why, size_t whyLen) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int32_t gid = 0;
    int32_t x = 0;
    int32_t y = 0;
    int32_t teamOld = 0;
    int32_t teamNew = 0;
    uint8_t dead = 0;

    if (why) why[0] = 0;
    if (!elem) {
        if (why) snprintf(why, whyLen, "null");
        return 0;
    }

    if (tnx_v75_element_ascii(elem)) {
        if (why) snprintf(why, whyLen, "ascii");
        return 0;
    }

    if (!tnx_read_ptr(elem, &vtable) || !vtable) {
        if (why) snprintf(why, whyLen, "noVtRead");
        return 0;
    }

    vtRva = (uintptr_t)vtable - g_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        if (why) snprintf(why, whyLen, "rejNoVt vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    if (!tnx_read_i32(elem + TNX_OBJ_GLOBALID_OFF, &gid) ||
        !tnx_read_i32(elem + tnx_v57_coord_x_off(), &x) ||
        !tnx_read_i32(elem + tnx_v57_coord_y_off(), &y) ||
        !tnx_read_i32(elem + TNX_OBJ_TEAM_OFF, &teamOld) ||
        !tnx_read_i32(elem + TNX_V91_TEAM_OFF, &teamNew) ||
        !tnx_read_u8(elem + TNX_OBJ_DEADFLAG_OFF, &dead)) {
        if (why) snprintf(why, whyLen, "unreadable vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    if (gid == 0) {
        if (why) snprintf(why, whyLen, "rejGidZero vtRva=%#llx pos=(%d,%d)",
                          (unsigned long long)vtRva, x, y);
        return 0;
    }

    if (x <= -TNX_V47_COORD_ABS_MAX || x >= TNX_V47_COORD_ABS_MAX ||
        y <= -TNX_V47_COORD_ABS_MAX || y >= TNX_V47_COORD_ABS_MAX) {
        if (why) snprintf(why, whyLen, "rejOutOfRange gid=%d pos=(%d,%d)", gid, x, y);
        return 0;
    }

    if (!((teamOld >= 0 && teamOld <= TNX_OBJ_TEAM_MAX) ||
          (teamNew >= 0 && teamNew <= TNX_OBJ_TEAM_MAX))) {
        if (why) snprintf(why, whyLen, "rejTeamMissing gid=%d t40=%d t4c=%d",
                          gid, teamOld, teamNew);
        return 0;
    }

    if (why) snprintf(why, whyLen, "ok vtRva=%#llx gid=%d pos=(%d,%d) t40=%d t4c=%d dead=%d",
                      (unsigned long long)vtRva, gid, x, y, teamOld, teamNew, dead);
    return 1;
}

static void tnx_v102_own_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    int taken = 0;
    int b;

    cand[0] = (uintptr_t)g_players_object;
    cand[1] = (uintptr_t)g_scene_object;

    for (b = 0; b < 2; b++) {
        void *array = NULL;
        void *elem = NULL;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        int32_t elemGid = 0;
        int32_t gidOff = 0;
        const char *sigField = (const char *)"none";
        char why[128];
        int sig = 0;
        int valid = 0;

        if (!cand[b]) continue;

        if (!tnx_read_ptr(cand[b] + TNX_V102_ARRAY_OFF, &array) || !array) {
            if (g_v102_own_logs < 10) {
                g_v102_own_logs++;
                tnx_logf("v102 own base=%-9s at=%p has no array at +%#llx, the global array is %p "
                         "- the base and the array must come from the same object or an index "
                         "read off one object is applied to the wrong list",
                         cname[b], (void *)cand[b], (unsigned long long)TNX_V102_ARRAY_OFF,
                         (void *)g_players_array);
            }
            continue;
        }

        if (!tnx_read_i32(cand[b] + TNX_V102_COUNT_OFF, &count)) count = 0;
        if (!tnx_read_i32(cand[b] + TNX_V102_OWNIDX_OFF, &idx)) idx = -1;
        if (!tnx_read_i32(cand[b] + TNX_V102_OWNTEAM_OFF, &team)) team = -1;

        if (idx >= 0 && count > 0 && idx < count) {
            if (tnx_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &elem) && elem) {
                if (tnx_read_i32((uintptr_t)elem + TNX_V102_ELEM_ID_OFF, &eid) &&
                    tnx_read_i32((uintptr_t)elem + TNX_V102_ELEM_TEAM_OFF, &eteam)) {
                    elemGid = tnx_v106_gid((uintptr_t)elem, &gidOff);

                    if (eid == idx && eid != 0) {
                        sig = 1;
                        sigField = (const char *)"idAt48";
                    } else if (team >= 0 && team <= TNX_OBJ_TEAM_MAX && eteam == team) {
                        sig = 2;
                        sigField = (const char *)"teamAt4c";
                    } else if (idx == 0 && elemGid != 0) {
                        sig = 3;
                        sigField = (const char *)"slotZeroWithGid";
                    } else {
                        sig = 0;
                        sigField = (const char *)"none";
                    }
                }
            }
        }

        if (sig) valid = tnx_v105_own_verdict((uintptr_t)elem, why, sizeof(why));
        else snprintf(why, sizeof(why), "noSignature idx=%d eid=%d ownTeam=%d elemTeam=%d",
                      idx, eid, team, eteam);

        if (g_v102_own_logs < 10) {
            g_v102_own_logs++;
            tnx_logf("v102 own base=%-9s at=%p count=+%#llx->%d idx=+%#llx->%d ownTeam=+%#llx->%d "
                     "elem=%p elemId=+%#llx->%d elemTeam=+%#llx->%d elemGid=+%#llx->%d sig=%d "
                     "sigField=%s collector=%s",
                     cname[b], (void *)cand[b], (unsigned long long)TNX_V102_COUNT_OFF, count,
                     (unsigned long long)TNX_V102_OWNIDX_OFF, idx,
                     (unsigned long long)TNX_V102_OWNTEAM_OFF, team, elem,
                     (unsigned long long)TNX_V102_ELEM_ID_OFF, eid,
                     (unsigned long long)TNX_V102_ELEM_TEAM_OFF, eteam,
                     (unsigned long long)(uintptr_t)gidOff, elemGid, sig, sigField, why);
        }

        if (sig && valid && !taken) {
            taken = 1;
            g_v102_own_ptr = (uintptr_t)elem;
            g_v102_own_index = idx;
            g_v102_own_team = team;
            g_v102_own_base = b;
            g_v102_own_from = (b == 0) ? "container+e0" : "scene+e0";

            tnx_v106_own_dump(g_v102_own_ptr);
        }
    }

    if (!taken) {
        g_v102_own_ptr = 0;
        g_v102_own_index = -1;
        g_v102_own_from = "v102-none";
    }
}

static int tnx_v102_inject_own(tnx_v47_obj_t *objects, int usable, int capacity) {
    tnx_v47_obj_t entry;
    int i;

    if (!g_v102_own_ptr || !objects) return usable;
    if (usable >= capacity) return usable;

    for (i = 0; i < usable; i++) {
        if (objects[i].object == g_v102_own_ptr) return usable;
    }

    memset(&entry, 0, sizeof(entry));
    entry.object = g_v102_own_ptr;

    entry.gid = tnx_v106_gid(entry.object, NULL);

    if (!tnx_read_i32(entry.object + tnx_v57_coord_x_off(), &entry.x) ||
        !tnx_read_i32(entry.object + tnx_v57_coord_y_off(), &entry.y) ||
        !tnx_read_i32(entry.object + TNX_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
        !tnx_read_i32(entry.object + TNX_OBJ_TEAM_OFF, &entry.teamOld) ||
        !tnx_read_i32(entry.object + TNX_V91_TEAM_OFF, &entry.teamNew)) {
        tnx_logf("v102 inject own=%p unreadable - the own element cannot be added to the list",
                 (void *)entry.object);
        return usable;
    }

    tnx_read_u8(entry.object + TNX_OBJ_DEADFLAG_OFF, &entry.dead);
    tnx_read_u8(entry.object + TNX_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag);

    objects[usable] = entry;

    if (g_v102_inject_logs < 8) {
        g_v102_inject_logs++;
        tnx_logf("v102 inject own=%p appended as objects[%d] gid=%d pos=(%d,%d) t40=%d t4c=%d "
                 "ownerIdx=%d - the own element was not in the collected list, so the list is "
                 "rebuilt with it instead of dropping the whole dodge",
                 (void *)entry.object, usable, entry.gid, entry.x, entry.y, entry.teamOld,
                 entry.teamNew, entry.ownerIndex);
    }

    return usable + 1;
}

static int tnx_v102_take_own(const tnx_v47_obj_t *objects, int usable, int *indexOut,
                             const char **fromOut) {
    int i;

    if (!objects || usable <= 0) return 0;
    if (!g_v102_own_ptr) return 0;

    for (i = 0; i < usable; i++) {
        if (objects[i].object == g_v102_own_ptr) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = g_v102_own_from;

            return 1;
        }
    }

    if (g_v102_inject_logs < 8) {
        g_v102_inject_logs++;
        tnx_logf("v102 own=%p slot=%d is neither in the collected list nor measurable - every "
                 "field read off it failed the collector test, so the element is not a battle "
                 "object at all",
                 (void *)g_v102_own_ptr, g_v102_own_index);
    }

    return 0;
}

static void tnx_v102_pos_trace(const tnx_v47_obj_t *objects, int usable) {
    int i;

    if (!objects || usable <= 0) return;
    if (usable > TNX_V47_OBJECT_MAX) usable = TNX_V47_OBJECT_MAX;

    for (i = 0; i < g_v102_trace_n && i < usable; i++) {
        if (g_v102_trace_obj[i] != objects[i].object) continue;
        if (g_v102_trace_x[i] == objects[i].x && g_v102_trace_y[i] == objects[i].y) continue;

        if (g_v102_trace_logs < TNX_V102_TRACE_MAX) {
            g_v102_trace_logs++;
            tnx_logf("v102 pos gid=%d d=(%+d,%+d) from=(%d,%d) to=(%d,%d) own=%d",
                     objects[i].gid, objects[i].x - g_v102_trace_x[i],
                     objects[i].y - g_v102_trace_y[i], g_v102_trace_x[i], g_v102_trace_y[i],
                     objects[i].x, objects[i].y,
                     (objects[i].object == g_v102_own_ptr) ? 1 : 0);
        }
    }

    g_v102_trace_n = usable;

    for (i = 0; i < usable; i++) {
        g_v102_trace_obj[i] = objects[i].object;
        g_v102_trace_x[i] = objects[i].x;
        g_v102_trace_y[i] = objects[i].y;
    }
}

static void tnx_v102_write_test(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    int32_t curX = 0;
    int32_t curY = 0;
    int wantX = 0;
    int wantY = 0;

    g_v102_tick++;

    if (!TNX_V102_WRITE_TEST) return;
    if (!g_scene_object) return;

    tnx_v102_pos_trace(objects, usable);

    if (g_v102_write_count >= TNX_V102_WRITE_TICKS) return;
    if (g_v102_tick - g_v102_write_last < TNX_V102_WRITE_EVERY) return;

    g_v102_write_last = g_v102_tick;

    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTX_OFF, &curX) ||
        !tnx_read_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTY_OFF, &curY)) {
        tnx_logf("v102 wtest cannot read mode+%#llx/+%#llx",
                 (unsigned long long)TNX_MODE_PREDICTX_OFF,
                 (unsigned long long)TNX_MODE_PREDICTY_OFF);
        return;
    }

    if (!g_v102_write_base_ok && curX != 0 && curY != 0) {
        g_v102_write_base_ok = 1;
        g_v102_write_base_x = curX;
        g_v102_write_base_y = curY;
    }

    g_v102_write_phase = g_v102_write_phase ? 0 : 1;
    wantX = (g_v102_write_base_ok ? g_v102_write_base_x : curX) +
            (g_v102_write_phase ? TNX_V102_WRITE_STEP : 0);
    wantY = (g_v102_write_base_ok ? g_v102_write_base_y : curY) +
            (g_v102_write_phase ? TNX_V102_WRITE_STEP : 0);

    if (g_v47_setpred) {
        ((void (*)(void *, int, int))g_v47_setpred)((void *)g_scene_object, wantX, wantY);
    } else {
        tnx_write_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTX_OFF, wantX);
        tnx_write_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTY_OFF, wantY);
    }

    g_v102_write_count++;

    tnx_logf("v102 wtest #%d mode=%p phase=%d base=(%d,%d) read=(%d,%d) wrote=(%d,%d) own=%d "
             "setpred=%p - the write goes through the verified leaf setter at rva %#llx that "
             "stores straight into +%#llx and +%#llx",
             g_v102_write_count, (void *)g_scene_object, g_v102_write_phase,
             g_v102_write_base_x, g_v102_write_base_y, curX, curY, wantX, wantY, ownIndex,
             (void *)g_v47_setpred, (unsigned long long)TNX_V102_SETPRED_RVA,
             (unsigned long long)TNX_MODE_PREDICTX_OFF,
             (unsigned long long)TNX_MODE_PREDICTY_OFF);
}

static void tnx_v102_audit_all(void) {
    int i;

    if (g_v102_audited || !g_base) return;

    g_v102_audited = 1;

    tnx_logf("v102 audit tag=%s entries=%d - every row of the rva table the engine can reach is "
             "tested here, entry means the four bytes at the rva open a frame or the word before "
             "them is a return, callable is the engine test that a call site needs",
             TNX_BUILD_TAG, (int)(sizeof(g_rvas) / sizeof(g_rvas[0])) - 1);

    for (i = 0; g_rvas[i].name; i++) {
        uintptr_t a = g_base + g_rvas[i].rva;
        uint32_t w = 0;
        uint32_t wm = 0;
        const char *rule = tnx_prologue_rule(a);

        tnx_v101_word(a, &w);
        tnx_v101_word(a - 4, &wm);

        tnx_logf("v102 audit %-52s rva=%#llx word=%#x prev=%#x rule=%-9s entry=%s callable=%s",
                 g_rvas[i].name, (unsigned long long)g_rvas[i].rva, (unsigned)w, (unsigned)wm,
                 rule ? rule : "?", tnx_v101_entry(g_rvas[i].rva) ? "yes" : "no",
                 (tnx_callable(g_rvas[i].rva) && tnx_looks_like_start(a)) ? "yes" : "no");
    }

    tnx_logf("v102 anchors getTeamStars=%#llx setpred=%#llx modePairSet=%#llx tileLookup=%#llx "
             "subGetter=%#llx - these five are the ones the disassembly of this build confirmed",
             (unsigned long long)TNX_V102_GETTEAMSTARS_RVA,
             (unsigned long long)TNX_V102_SETPRED_RVA,
             (unsigned long long)TNX_V102_MODEPAIRSET_RVA,
             (unsigned long long)TNX_V102_TILELOOKUP_RVA,
             (unsigned long long)TNX_V102_SUBGETTER_RVA);
}


static void tnx_v103_arm(void) {
    if (g_v103_armed || !g_base) return;

    g_v103_armed = 1;

    g_v103_sp4 = tnx_v101_entry(TNX_V103_SETPRED4_RVA);
    g_v103_sp2 = tnx_v101_entry(TNX_V103_SETPRED2_RVA);
    g_v103_addinput = tnx_v101_entry(TNX_V103_ADDINPUT_RVA);

    tnx_logf("v103 rva audit tag=%s setPredMoveTo4 rva=%#llx entry=%s callable=%s | setter2 "
             "rva=%#llx entry=%s callable=%s | addInput rva=%#llx entry=%s callable=%s",
             TNX_BUILD_TAG,
             (unsigned long long)TNX_V103_SETPRED4_RVA, g_v103_sp4 ? "yes" : "no",
             tnx_callable(TNX_V103_SETPRED4_RVA) ? "yes" : "no",
             (unsigned long long)TNX_V103_SETPRED2_RVA, g_v103_sp2 ? "yes" : "no",
             tnx_callable(TNX_V103_SETPRED2_RVA) ? "yes" : "no",
             (unsigned long long)TNX_V103_ADDINPUT_RVA, g_v103_addinput ? "yes" : "no",
             tnx_callable(TNX_V103_ADDINPUT_RVA) ? "yes" : "no");

    tnx_logf("v103 rva bodies 0xac3a58 = str w1,[x0,#0x10c]; str w2,[x0,#0x110]; strb w3,[x0,#0x114]; "
             "mov w8,#1; strb w8,[x0,#0xac]; ret, four arguments and it is called by the battle "
             "update at 0x79de14 and 0x7a7270 right after the input message is enqueued; "
             "0xac3f20 = str w1,[x0,#0x1d4]; str w2,[x0,#0x1d8]; ret, the two argument pair the "
             "v102 run wrote and the game never read back; 0x74675c = enqueue, it maps message+0x8 "
             "through the 21 entry table at %#llx and pushes the pointer into the queue at "
             "manager+0x20, then stamps a sequence number into message+0x0",
             (unsigned long long)TNX_V103_KEY_TABLE_VM);

    tnx_logf("plan v103, breakthrough from the v102 run and the Frida reference:");
    tnx_logf("the dodge now has both ends. own resolved from scene+e0 at +0 index=1");
    tnx_logf("object=0x131d7c600, target=0x14900a1c0, vector=(1050,3750),");
    tnx_logf("actuatorReached=1 and the only closed door is prediction, which stays");
    tnx_logf("zero on every tick (mode+0x1d4=0 mode+0x1d8=0). The reason chain ends");
    tnx_logf("at predictionZero, which is exactly the last of the five gates, so");
    tnx_logf("everything before it passed. The Frida reference (a mod for a different");
    tnx_logf("build) shows the actuator is NOT a store into scene+0x58+8: movement");
    tnx_logf("is a NEW 200-byte ClientInput message with type=2 at +0x4, x at +0x8,");
    tnx_logf("y at +0xc, handed to ClientInputManager::addInput(*(scene+0x58), msg).");
    tnx_logf("So v103 (1) resolves ClientInput::ctor and ClientInputManager::addInput");
    tnx_logf("in THIS binary via radare2 before the build; (2) replaces the");
    tnx_logf("prediction write with a real addInput call; (3) validates with a");
    tnx_logf("single test move and a read-back of own.pos on the next tick; (4) only");
    tnx_logf("then enables the threat walk and the clip; (5) prints the inputmgr");
    tnx_logf("chain and the addInput result every tenth tick.");

    tnx_logf("plan v103 revision after the static pass on the attached binary - "
             "addInput IS found and it is %#llx: first argument is the manager, second the message, "
             "it maps message+0x8 through the 21 entry table at %#llx, pushes the pointer into the "
             "queue at manager+0x20 (array at +0x0, count at +0xc) and stamps a sequence number into "
             "message+0x0. The message layout of the reference does NOT hold in this build: "
             "message+0x8 is the dedup key, so type and x/y are not at +0x4/+0x8/+0xc and a hand "
             "built message would be enqueued as garbage and later freed. What the same battle "
             "update calls immediately after the enqueue is the four argument setter %#llx "
             "(str w1,[x0,#0x10c]; str w2,[x0,#0x110]; strb w3,[x0,#0x114]; strb 1,[x0,#0xac]; ret) "
             "at 0x79de14 and 0x7a7270, so v103 drives that first and keeps the message route until "
             "the ctor of this build is located",
             (unsigned long long)TNX_V103_ADDINPUT_RVA, (unsigned long long)TNX_V103_KEY_TABLE_VM,
             (unsigned long long)TNX_V103_SETPRED4_RVA);
}

static int g_v112_flag_arm = 0;
static int g_v112_flag_logs = 0;
static uint64_t g_v112_flag_tick = 0;
static int g_v112_flag_before = -1;
static int g_v112_flag_after = -1;
static int g_v112_flag_consumed = -1;
static int g_v112_flag_ticks = -1;
static int g_v112_pos_logs = 0;
static uint64_t g_v112_pos_tick = 0;

static int tnx_v112_read_flag(void) {
    uint8_t b = 0;

    if (!g_scene_object) return -1;
    if (!tnx_read_u8((uintptr_t)g_scene_object + TNX_V112_FLAG_OFF, &b)) return -1;

    return (int)b;
}

static void tnx_v112_flag_arm(void) {
    g_v112_flag_before = tnx_v112_read_flag();
    g_v112_flag_tick = g_v103_tick;
    g_v112_flag_after = -1;
    g_v112_flag_consumed = -1;
    g_v112_flag_ticks = -1;
    g_v112_flag_arm = 1;
}

static void tnx_v112_flagwatch(void) {
    int now;

    if (!g_v112_flag_arm) return;

    now = tnx_v112_read_flag();

    if (g_v112_flag_after < 0) g_v112_flag_after = now;

    if (g_v112_flag_consumed < 0) {
        if (now == 0) {
            g_v112_flag_consumed = 1;
            g_v112_flag_ticks = (int)(g_v103_tick - g_v112_flag_tick);
        } else if (g_v103_tick - g_v112_flag_tick >= TNX_V112_FLAG_MAX_TICKS) {
            g_v112_flag_consumed = 0;
            g_v112_flag_ticks = (int)(g_v103_tick - g_v112_flag_tick);
        }
    }

    if (g_v112_flag_consumed < 0) return;
    if (g_v112_flag_logs >= 4) return;

    g_v112_flag_logs++;
    g_v112_flag_arm = 0;

    tnx_logf("v112 flagwatch scene=%p ac_before=%d ac_after=%d ac_final=%d ticks=%d consumed=%d "
             "setterRva=%#llx readerRva=%#llx - the byte at +%#llx is raised by the setter and the class "
             "update reads it with ldrb then clears it with strb wzr before it forwards the movement, so "
             "consumed=1 means the write entered the pipeline and consumed=0 means the byte was left "
             "standing and the setter is bookkeeping",
             (void *)g_scene_object, g_v112_flag_before, g_v112_flag_after, now, g_v112_flag_ticks,
             g_v112_flag_consumed, (unsigned long long)TNX_V112_SETPRED4_RVA,
             (unsigned long long)TNX_V112_READER_RVA, (unsigned long long)TNX_V112_FLAG_OFF);
}

static void tnx_v112_pos_watch(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    uintptr_t element = 0;
    void *vt = NULL;
    uintptr_t vtRva = 0;
    float fx = 0.0f;
    float fy = 0.0f;
    float f2x = 0.0f;
    float f2y = 0.0f;
    float gx = 0.0f;
    float gy = 0.0f;
    int gxOk = 0;
    int gyOk = 0;

    if (!objects || ownIndex < 0 || ownIndex >= usable) return;
    if (g_v103_tick < TNX_V112_POS_EVERY) return;
    if (g_v103_tick - g_v112_pos_tick < TNX_V112_POS_EVERY) return;
    if (g_v112_pos_logs >= 24) return;

    g_v112_pos_tick = g_v103_tick;
    g_v112_pos_logs++;

    element = objects[ownIndex].object;

    if (!element) return;

    if (tnx_read_ptr(element, &vt) && vt) vtRva = (uintptr_t)vt - g_base;

    tnx_read_f32(element + TNX_V112_POS_X_OFF, &fx);
    tnx_read_f32(element + TNX_V112_POS_Y_OFF, &fy);
    tnx_read_f32(element + TNX_V112_POS2_X_OFF, &f2x);
    tnx_read_f32(element + TNX_V112_POS2_Y_OFF, &f2y);

    if (vtRva == TNX_V112_ELEM_VT_RVA) {
        void *fn = NULL;

        if (tnx_read_ptr((uintptr_t)vt + TNX_V112_GETX_SLOT, &fn) && fn) {
            gx = ((float (*)(void *))fn)((void *)element);
            gxOk = 1;
        }

        fn = NULL;

        if (tnx_read_ptr((uintptr_t)vt + TNX_V112_GETY_SLOT, &fn) && fn) {
            gy = ((float (*)(void *))fn)((void *)element);
            gyOk = 1;
        }
    }

    tnx_logf("v112 poswatch elem=%p vtRva=%#llx f10=%.4f f1c=%.4f f20=%.4f f24=%.4f getX=%.4f getY=%.4f "
             "getXOk=%d getYOk=%d int30=%d int34=%d gid=%d tick=%llu - the class keeps its position as "
             "the float pair at +%#llx/+%#llx behind getX and getY, sampled every %d ticks so a move "
             "during the battle shows even while the int pair the walk reads stays zero",
             (void *)element, (unsigned long long)vtRva, fx, fy, f2x, f2y, gx, gy, gxOk, gyOk,
             objects[ownIndex].x, objects[ownIndex].y, objects[ownIndex].gid,
             (unsigned long long)g_v103_tick, (unsigned long long)TNX_V112_POS_X_OFF,
             (unsigned long long)TNX_V112_POS_Y_OFF, TNX_V112_POS_EVERY);
}

static int g_v113_test_state = 0;
static uint64_t g_v113_test_tick = 0;
static int g_v113_test_before_x = 0;
static int g_v113_test_before_y = 0;
static int g_v113_test_after_x = 0;
static int g_v113_test_after_y = 0;
static int g_v113_moved = 0;
static int g_v113_moved2 = 0;
static int g_v113_kept = 0;
static int g_v113_tested = 0;
static uint64_t g_v113_enqueues = 0;
static int g_v113_enq_x = 0;
static int g_v113_enq_y = 0;
static int g_v113_q_before = -1;
static int g_v113_q_after = -1;
static int g_v113_readback = -1;
static int g_v113_readback_tick = -1;
static int g_v113_hop2_logs = 0;
static int g_v113_hop2_filled = 0;
static uintptr_t g_v113_hop2 = 0;
static int g_v113_queue_logs = 0;
static int g_v113_window_logs = 0;
static uint64_t g_v113_push_frame = 0;
static int g_v113_frame_logs = 0;
static int g_v115_mode_wait_logs = 0;
static int g_v115_mode_seen7 = 0;
static int g_v115_mode_max = 0;
static int g_v115_gate_seen = 0;
static uint64_t g_v113_test_tickbase = 0;

static int g_v126_enq_ok = 0;
static const char *g_v126_alloc_how = "none";
static void *g_v126_msg = NULL;
static int g_v126_seq_before = -1;
static int g_v126_seq_after = -1;
static int g_v126_q_before = -1;
static int g_v126_q_after = -1;
static void *g_v126_q_last = NULL;
static int32_t g_v126_scene_before_x = 0;
static int32_t g_v126_scene_before_y = 0;
static int g_v126_wtest_h1_off = 0;
static int g_v126_chain_logs = 0;
static uint64_t g_v126_watch_from = 0;
static int g_v126_watch_logs = 0;
static int g_v126_own_ok = 0;
static int32_t g_v126_own_x = 0;
static int32_t g_v126_own_y = 0;
static int32_t g_v126_box_lo = 0;
static int32_t g_v126_box_hi = 0;
static const char *g_v126_own_tag = "none";
static int g_v126_ownmatch_logs = 0;

static uintptr_t tnx_v113_entry(uintptr_t rva);
static void *tnx_v113_manager(void);

static void *tnx_v126_msg_alloc(void) {
    uintptr_t stub = tnx_v113_entry(TNX_V113_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub) {
        g_v126_alloc_how = "stub";
        return ((void *(*)(size_t))stub)((size_t)TNX_V113_MSG_SIZE);
    }

    if (g_base && tnx_read_ptr(g_base + TNX_V126_ALLOC_GOT_RVA, (void **)&got) && got) {
        g_v126_alloc_how = "got";
        return ((void *(*)(size_t))got)((size_t)TNX_V113_MSG_SIZE);
    }

    g_v126_alloc_how = "malloc";

    return malloc((size_t)TNX_V113_MSG_SIZE);
}

static void *tnx_v126_q_last(void) {
    void *mgr = tnx_v113_manager();
    void *queue = NULL;
    void *arr = NULL;
    int32_t count = 0;
    void *e = NULL;

    if (!mgr) return NULL;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_V113_QUEUE_OFF, &queue) || !queue) return NULL;
    if (!tnx_read_i32((uintptr_t)queue + TNX_V113_QUEUE_COUNT_OFF, &count) || count <= 0) return NULL;
    if (!tnx_read_ptr((uintptr_t)queue, &arr) || !arr) return NULL;
    if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)(count - 1) * 8ULL, &e)) return NULL;

    return e;
}

static uintptr_t tnx_v113_entry(uintptr_t rva) {
    if (!g_base || !rva) return 0;
    if (!tnx_callable(rva)) return 0;

    return g_base + rva;
}

static void *tnx_v113_manager(void) {
    uintptr_t battleFn = tnx_v113_entry(TNX_V113_GETBATTLE_RVA);
    void *battle = NULL;
    void *mgr = NULL;

    if (!battleFn) return NULL;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) return NULL;
    if (!tnx_read_ptr((uintptr_t)battle + TNX_V113_MGR_OFF, &mgr) || !mgr) return NULL;

    return mgr;
}

static int tnx_v113_queue_count(uintptr_t *mgrOut) {
    void *mgr = tnx_v113_manager();
    void *queue = NULL;
    int32_t count = -1;

    if (mgrOut) *mgrOut = (uintptr_t)mgr;
    if (!mgr) return -1;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_V113_QUEUE_OFF, &queue) || !queue) return -1;
    if (!tnx_read_i32((uintptr_t)queue + TNX_V113_QUEUE_COUNT_OFF, &count)) return -1;

    return (int)count;
}

static int tnx_v113_enqueue(int x, int y) {
    uintptr_t ctorFn = tnx_v113_entry(TNX_V113_MSGCTOR_RVA);
    uintptr_t inputFn = tnx_v113_entry(TNX_V113_ADDINPUT_RVA);
    int32_t vx = x;
    int32_t vy = y;
    int32_t type = TNX_V126_TYPE_MOVE;
    void *mgr = NULL;
    void *msg = NULL;

    g_v126_enq_ok = 0;
    g_v126_msg = NULL;
    g_v126_q_last = NULL;
    g_v126_seq_before = -1;
    g_v126_seq_after = -1;
    g_v126_q_before = -1;
    g_v126_q_after = -1;

    if (!inputFn) return 0;

    msg = tnx_v126_msg_alloc();

    if (!msg) return 0;

    memset(msg, 0, (size_t)TNX_V113_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, TNX_V126_TYPE_MOVE);

    tnx_write_bytes((uintptr_t)msg + TNX_V113_TYPE_OFF, &type, sizeof(type));
    tnx_write_bytes((uintptr_t)msg + TNX_V113_X_OFF, &vx, sizeof(vx));
    tnx_write_bytes((uintptr_t)msg + TNX_V113_Y_OFF, &vy, sizeof(vy));

    mgr = tnx_v113_manager();

    if (!mgr) {
        tnx_logf("v126 queuePush aborted x=%d y=%d msg=%p alloc=%s - battle+%#llx is null, so the "
                 "message was built but not pushed and is left allocated on purpose rather than freed "
                 "through a pointer the queue never saw",
                 x, y, msg, g_v126_alloc_how, (unsigned long long)TNX_V113_MGR_OFF);

        return 0;
    }

    tnx_read_i32((uintptr_t)mgr + TNX_V126_MGR_SEQ_OFF, &g_v126_seq_before);

    g_v126_q_before = tnx_v113_queue_count(NULL);

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    g_v126_seq_after = -1;
    tnx_read_i32((uintptr_t)mgr + TNX_V126_MGR_SEQ_OFF, &g_v126_seq_after);
    g_v126_q_after = tnx_v113_queue_count(NULL);
    g_v126_q_last = tnx_v126_q_last();
    g_v126_msg = msg;
    g_v126_enq_ok = 1;
    g_v113_enqueues++;
    g_v113_push_frame = g_v48_ticks;

    tnx_logf("v126 queuePush tick=%llu type=%d x=%d y=%d msg=%p mgr=%p alloc=%s seqBefore=%d "
             "seqAfter=%d qBefore=%d qAfter=%d qLast=%p - the movement message of this build is the one "
             "the battle update builds at %#llx: size %#x, the ctor %#llx stores the type at +%#llx with "
             "w1 loaded with %d and not 2, the clamped pair goes to +%#llx as two int32, and the push is "
             "addInput %#llx with the manager read as %#llx+%#llx; the allocator used here is %s because "
             "the stub %#llx opens with adrp and the callable gate refuses it, so the GOT slot %#llx is "
             "read and malloc is the last resort, and manager+%#llx is the sequence counter addInput "
             "increments, so seqAfter above seqBefore is proof the call ran at all",
             (unsigned long long)g_v103_tick, TNX_V126_TYPE_MOVE, x, y, msg, mgr, g_v126_alloc_how,
             g_v126_seq_before, g_v126_seq_after, g_v126_q_before, g_v126_q_after, g_v126_q_last,
             (unsigned long long)0x79de88ULL, (unsigned)TNX_V113_MSG_SIZE,
             (unsigned long long)TNX_V113_MSGCTOR_RVA, (unsigned long long)TNX_V113_TYPE_OFF,
             TNX_V126_TYPE_MOVE, (unsigned long long)TNX_V113_X_OFF,
             (unsigned long long)TNX_V113_ADDINPUT_RVA, (unsigned long long)TNX_V113_GETBATTLE_RVA,
             (unsigned long long)TNX_V113_MGR_OFF, g_v126_alloc_how,
             (unsigned long long)TNX_V113_ALLOC_RVA, (unsigned long long)TNX_V126_ALLOC_GOT_RVA,
             (unsigned long long)TNX_V126_MGR_SEQ_OFF);

    return 1;
}

static const char *tnx_v113_state_x(int32_t v) {
    if (v == g_v113_enq_x) return "MATCH";
    if (v == -1) return "RESET";
    if (v == 0) return "DEFAULT";

    return "other";
}

static const char *tnx_v113_state_y(int32_t v) {
    if (v == g_v113_enq_y && g_v113_enq_y != 0) return "MATCH";
    if (v == -1) return "RESET";
    if (v == 0) return (g_v113_enq_y == 0) ? "MATCH=DEFAULT" : "DEFAULT";

    return "other";
}

static int tnx_v115_mode(void) {
    int32_t mode = -1;

    if (!g_scene_object) return -1;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V115_MODE_OFF, &mode)) return -1;

    return (int)mode;
}

static int tnx_v115_inner(void) {
    void *holder = NULL;
    uint8_t b = 0;

    if (!g_scene_object) return -1;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V115_GATE_PTR_OFF, &holder) || !holder) return -1;
    if (!tnx_read_u8((uintptr_t)holder + TNX_V115_GATE_BYTE_OFF, &b)) return -1;

    return (int)b;
}

static int tnx_v115_gate(void) {
    int mode = tnx_v115_mode();

    if (mode < 0) return -1;
    if (mode != TNX_V115_MODE_TARGET) return 0;
    if (tnx_v115_inner() != 1) return 0;

    return 1;
}

static uintptr_t tnx_v115_client(void) {
    void *client = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V115_CLIENT_OFF, &client)) return 0;

    return (uintptr_t)client;
}


static uint32_t g_v116_mode_hist[TNX_V116_HIST_MODES];
static int64_t g_v116_last_mode = -1;
static int32_t g_v116_interp_prev_x = 0;
static int32_t g_v116_interp_prev_y = 0;
static int g_v116_interp_have = 0;
static uint64_t g_v116_interp_moves = 0;
static uint64_t g_v116_interp_checks = 0;
static uint64_t g_v116_interp_tick = 0;
static int g_v116_hist_logs = 0;

static int tnx_v116_interp(int32_t *x, int32_t *y) {
    uintptr_t client = tnx_v115_client();
    int32_t cx = 0;
    int32_t cy = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (!client) return 0;
    if (!tnx_read_i32(client + TNX_V115_CLIENT_POS_X_OFF, &cx)) return 0;
    if (!tnx_read_i32(client + TNX_V115_CLIENT_POS_Y_OFF, &cy)) return 0;

    if (x) *x = cx;
    if (y) *y = cy;

    return 1;
}


static int g_v117_match_idx = -1;
static int g_v117_match_gid = -1;
static int g_v117_match_streak = 0;
static int g_v117_gate2_seen = 0;
static int g_v117_gate3_seen = 0;

static int tnx_v117_pair(uintptr_t obj, int32_t *x, int32_t *y) {
    if (x) *x = 0;
    if (y) *y = 0;
    if (!obj) return 0;
    if (!tnx_read_i32(obj + TNX_V115_CLIENT_POS_X_OFF, x)) return 0;
    if (!tnx_read_i32(obj + TNX_V115_CLIENT_POS_Y_OFF, y)) return 0;

    return 1;
}

static int tnx_v117_src(uintptr_t off, int32_t *x, int32_t *y, int *flag) {
    void *o = NULL;
    uint8_t b = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (flag) *flag = -1;
    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + off, &o) || !o) return 0;
    if (flag && tnx_read_u8((uintptr_t)o + TNX_V115_GATE_BYTE_OFF, &b)) *flag = (int)b;

    return tnx_v117_pair((uintptr_t)o, x, y);
}


static int32_t g_v118_src30_prev_x = 0;
static int32_t g_v118_src30_prev_y = 0;
static int32_t g_v118_src38_prev_x = 0;
static int32_t g_v118_src38_prev_y = 0;
static int g_v118_src30_have = 0;
static int g_v118_src38_have = 0;
static uint64_t g_v118_src30_moves = 0;
static uint64_t g_v118_src38_moves = 0;
static int g_v118_w_eq_x = 0;
static int g_v118_w_eq_y = 0;

static int tnx_v118_weq(int32_t a, int32_t b, int32_t out, int32_t d) {
    if (d == 0) return -1;

    return (int)(((int64_t)(out - b) * 1000) / (int64_t)d);
}

static uintptr_t tnx_v118_mode_ptr(uintptr_t off) {
    void *o = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + off, &o)) return 0;

    return (uintptr_t)o;
}


static uint64_t g_v119_gate1_tick = 0;
static uint64_t g_v119_gate2_tick = 0;
static uint64_t g_v119_gate3_tick = 0;
static int g_v119_elig_logs = 0;
static int g_v119_elig_any = 0;
static uint64_t g_v119_pin_done = 0;

static void tnx_v119_gate_ticks(void) {
    if (!g_v119_gate1_tick && tnx_v115_mode() == TNX_V115_MODE_TARGET) g_v119_gate1_tick = g_v103_tick;
    if (!g_v119_gate2_tick && tnx_v115_inner() == 1) g_v119_gate2_tick = g_v103_tick;

    if (!g_v119_gate3_tick) {
        int f = -1;

        if (tnx_v117_src(TNX_V117_GATE3_PTR_OFF, NULL, NULL, &f) && f >= 0) g_v119_gate3_tick = g_v103_tick;
    }
}

static void tnx_v119_elements(void) {
    tnx_v47_obj_t objs[8];
    int rej = 0;
    int n = 0;
    int i;
    char buf[320];
    char posBuf[96];
    size_t used = 0;
    size_t posUsed = 0;
    int any = 0;

    posBuf[0] = 0;

    if (!g_players_object) return;
    if (g_v119_elig_logs >= 30) return;
    if (g_v103_tick % 25) return;

    n = tnx_v48_collect((uintptr_t)g_players_object, objs, 8, &rej);

    if (n <= 0) return;

    g_v119_elig_logs++;

    for (i = 0; i < n; i++) {
        uint8_t elig = 0;
        int32_t p214 = 0;
        int32_t p220 = 0;
        int32_t p224 = 0;

        tnx_read_u8(objs[i].object + TNX_V119_ELIG_OFF, &elig);
        tnx_read_i32(objs[i].object + TNX_V119_PROP_214_OFF, &p214);
        tnx_read_i32(objs[i].object + TNX_V119_PROP_220_OFF, &p220);
        tnx_read_i32(objs[i].object + TNX_V119_PROP_224_OFF, &p224);

        if (elig == 1) {
            any++;
            posUsed += (size_t)snprintf(posBuf + posUsed, sizeof(posBuf) - posUsed, "%d,", i);
        }

        used += (size_t)snprintf(buf + used, sizeof(buf) - used, "[%d gid=%d elig=%d p214=%d p220=%d p224=%d]",
                                 i, objs[i].gid, (int)elig, p214, p220, p224);
        if (used >= sizeof(buf) - 96) break;
    }

    if (any) g_v119_elig_any = 1;

    {
        uint8_t ownB = 0;

        if (g_players_object) {
            tnx_v47_obj_t ownObjs[8];
            int ownRej = 0;

            if (tnx_v48_collect((uintptr_t)g_players_object, ownObjs, 8, &ownRej) > 0) {
                tnx_read_u8(ownObjs[0].object + TNX_V119_ELIG_OFF, &ownB);
            }
        }

        tnx_logf("v122 eligible own_elig=%d own_byte1fd=%#x pos=%s n=%d anyElig=%d anyEver=%d %s - the "
                 "interpolation filter",
                 (int)ownB, (unsigned)ownB, posBuf, n, any, g_v119_elig_any, buf);
    }

    tnx_logf("v119 eligibleNote the filter at %#x takes an element "
             "only when the virtual slot +0x28 returns 1 and the byte at +%#llx is 1, and that byte is "
             "loaded from the property list index %#x by the loader at %#llx which is reached from the "
             "message path %#llx, so an element with elig=0 is dropped before the lerp no matter what any "
             "writer or queue does",
             (unsigned long long)0xac22c4, (unsigned long long)TNX_V119_ELIG_OFF,
             (unsigned)0x1e2, (unsigned long long)0xa30b30ULL, (unsigned long long)0x7b322cULL);
}

static void tnx_v119_pin(void) {
    tnx_v47_obj_t objs[8];
    int rej = 0;
    int n = 0;
    int i;

    if (!TNX_V119_TEST_ENABLE) return;
    if (g_v119_pin_done) return;
    if (!g_players_object) return;
    if (tnx_v115_mode() != TNX_V115_MODE_TARGET) return;

    n = tnx_v48_collect((uintptr_t)g_players_object, objs, 8, &rej);

    if (n <= 0) return;

    g_v119_pin_done = 1;

    for (i = 0; i < n; i++) {
        uint8_t b = 1;

        tnx_write_bytes(objs[i].object + TNX_V119_ELIG_OFF, &b, sizeof(b));
    }

    tnx_logf("v119 pin set elig=1 on %d elements at +%#llx - this is the cheap test that does not need the "
             "message ctor or the queue: if the loader at %#llx refreshes the byte on the next packet the "
             "pin dies, and if it survives and client+%#llx starts moving then eligibility was the only "
             "blocker", n, (unsigned long long)TNX_V119_ELIG_OFF, (unsigned long long)0xa30b30ULL,
             (unsigned long long)TNX_V115_CLIENT_POS_X_OFF);
}


static int32_t g_v120_f138_prev = 0;
static int32_t g_v120_f13c_prev = 0;
static int g_v120_f_have = 0;
static uint64_t g_v120_reloads = 0;
static int g_v120_holder_logged = 0;
static int g_v120_ent_logs = 0;

static void tnx_v120_thermometer(void) {
    int32_t from = 0;
    int32_t to = 0;

    if (!g_scene_object) return;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V120_FROM_OFF, &from)) return;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V120_TO_OFF, &to)) return;

    if (g_v120_f_have && (from != g_v120_f138_prev || to != g_v120_f13c_prev)) g_v120_reloads++;

    g_v120_f138_prev = from;
    g_v120_f13c_prev = to;
    g_v120_f_have = 1;
}

static void tnx_v120_holder_note(void) {
    if (g_v120_holder_logged) return;
    if (g_v103_tick < 10) return;

    g_v120_holder_logged = 1;

    tnx_logf("v122 holder=unavail lifetime=per-frame reason=scratch classRva=%#llx - the property holder cannot be used as a "
             "network thermometer: the mode update allocates two %#x byte holders with %#llx every frame at "
             "%#x and %#x, stores them only in stack slots, fills them through the loader %#llx and drops "
             "them, so nothing persistent carries the packets; the readable proxy is the last loaded "
             "from/to pair at mode+%#llx/+%#llx, which is exactly the pair that gates the snapshot reload",
             (unsigned long long)TNX_V120_HOLDER_VT_RVA, (unsigned)TNX_V120_HOLDER_SIZE,
             (unsigned long long)TNX_V120_HOLDER_CTOR_RVA,
             (unsigned)0xac2104, (unsigned)0xac2114, (unsigned long long)0xa24278ULL,
             (unsigned long long)TNX_V120_FROM_OFF, (unsigned long long)TNX_V120_TO_OFF);
}

static void tnx_v120_entities(void) {
    uintptr_t getter = tnx_v113_entry(TNX_V120_ENTITY_GETTER_RVA);
    void *obj = NULL;
    void *container = NULL;
    int32_t count = -1;
    char buf[280];
    size_t used = 0;
    int i;

    if (!g_scene_object || !getter) return;
    if (g_v120_ent_logs >= 30) return;
    if (g_v103_tick % 25) return;

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V117_GATE3_PTR_OFF, &obj) || !obj) return;

    container = ((void *(*)(void *))getter)(obj);

    if (!container) return;

    tnx_read_i32((uintptr_t)container + 0xc, &count);

    if (count < 0) return;

    if (count > 12) count = 12;

    g_v120_ent_logs++;

    for (i = 0; i < count; i++) {
        void *e = NULL;
        void *vt = NULL;
        uintptr_t r = 0;
        uint8_t el = 0;

        if (!tnx_read_ptr((uintptr_t)container + (uintptr_t)i * 8ULL, &e) || !e) continue;

        if (tnx_read_ptr((uintptr_t)e, &vt) && vt) r = (uintptr_t)vt - g_base;

        tnx_read_u8((uintptr_t)e + TNX_V119_ELIG_OFF, &el);

        used += (size_t)snprintf(buf + used, sizeof(buf) - used, "[%d vt=%#llx elig=%d]", i,
                                 (unsigned long long)r, (int)el);
        if (used >= sizeof(buf) - 64) break;
    }

    tnx_logf("v120 entities node=%p list=%p count=%d %s - this is the real candidate list taken as "
             "mode+%#llx through the getter %#llx, so an entry here with vtable %#llx is a live brawler and "
             "an entry with another vtable is a lobby or roster slot; logInterp=%d - it needs the getter "
             "call because the mode holds the node and not the array",
             obj, container, count, buf, (unsigned long long)TNX_V117_GATE3_PTR_OFF,
             (unsigned long long)TNX_V120_ENTITY_GETTER_RVA, (unsigned long long)0xff5440ULL,
             (tnx_v115_mode() == TNX_V115_MODE_TARGET && tnx_v115_inner() == 1) ? 1 : 0);
}


static uint64_t g_v122_prev_win_reloads = 0;
static uint64_t g_v122_win_mark = 0;
static uint64_t g_v122_pre_reloads = 0;
static uint64_t g_v122_pre_frames = 0;
static int g_v122_pre_logged = 0;
static int g_v122_ent2_logs = 0;

static uint64_t g_v121_push_frame = 0;
static uint64_t g_v121_win_reloads = 0;
static int g_v121_win_stage = 0;
static uint64_t g_v121_traj_logs = 0;
static uint64_t g_v121_rate_marks = 0;

static uint64_t g_v121_rate_prev = 0;

static void tnx_v121_traj(void) {
    void *arr = NULL;
    int32_t count = 0;
    int32_t tnow = 0;
    char buf[300];
    size_t used = 0;
    int i;
    int32_t seqA = 0;
    int32_t seqB = 0;

    if (!g_scene_object) return;
    if (g_v121_traj_logs >= 30) return;
    if (g_v103_tick % 25) return;

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V121_TRAJ_ARR_OFF, &arr) || !arr) return;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V121_TRAJ_COUNT_OFF, &count)) return;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V121_TRAJ_TIME_OFF, &tnow)) return;

    g_v121_traj_logs++;

    for (i = 0; i < count && i < 10; i++) {
        void *e = NULL;
        int32_t seq = 0;
        void *blk = NULL;

        if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)i * 8ULL, &e) || !e) continue;
        tnx_read_i32((uintptr_t)e + TNX_V121_ENTRY_SEQ_OFF, &seq);
        tnx_read_ptr((uintptr_t)e + TNX_V121_ENTRY_BLOCK_OFF, &blk);

        if (i == 0) seqA = seq;
        if (i == 1) seqB = seq;

        used += (size_t)snprintf(buf + used, sizeof(buf) - used, "[%d seq=%d blk=%p]", i, seq, blk);
        if (used >= sizeof(buf) - 64) break;
    }

    {
        int cadence = 0;
        int stale = 0;

        if (count >= 2 && seqB > seqA) cadence = ((seqB - seqA) / (count - 1)) * 50;
        stale = (tnow - seqA) * 50;

        tnx_logf("v122 traj count=%d time=%d seqHead=%d seqTail=%d cadenceMs=%d stalenessMs=%d arr=%p "
                 "seq0=%d seq1=%d ", count, tnow, seqA, seqB, cadence, stale, arr, seqA, seqB);
    }

    tnx_logf("v122 trajdetail arr=%p count=%d time=%d seq0=%d seq1=%d %s - this list at mode+%#llx with count at "
             "+%#llx is the interpolation source: the update brackets the current time %d between two "
             "entries, takes the block at entry+%#llx and lerps it into the client pair, while entry+%#llx "
             "is the entry time, so a growing seq spacing is the packet cadence and a frozen list means "
             "the server sent nothing new",
             arr, count, tnow, seqA, seqB, buf,
             (unsigned long long)TNX_V121_TRAJ_ARR_OFF,
             (unsigned long long)TNX_V121_TRAJ_COUNT_OFF, tnow,
             (unsigned long long)TNX_V121_ENTRY_BLOCK_OFF,
             (unsigned long long)TNX_V121_ENTRY_SEQ_OFF);
}

static void tnx_v121_window(void) {
    uint64_t d;

    if (g_v121_rate_marks == 0 || (g_v48_ticks - g_v121_rate_marks) >= 300) {
        g_v121_rate_marks = g_v48_ticks;

        tnx_logf("v121 reloadRate reloads=%llu delta=%llu per5s=%llu - an absolute reload count says "
                 "nothing because the gate only fires when the cached from/to pair changes, so a standing "
                 "player produces zero reloads even with a perfect connection and only the rate over a "
                 "window is meaningful",
                 (unsigned long long)g_v120_reloads,
                 (unsigned long long)(g_v120_reloads - g_v121_rate_prev),
                 (unsigned long long)(g_v120_reloads - g_v121_rate_prev));

        g_v121_rate_prev = g_v120_reloads;
    }

    if (!g_v121_push_frame) return;

    d = g_v48_ticks - g_v121_push_frame;

    if (g_v121_win_stage == 0 && !g_v122_pre_logged && d >= 1) {
        g_v122_pre_logged = 1;

        tnx_logf("v122 winPre preFrames=%llu preReloads=%llu preRate5s=%llu - the baseline is taken from the "
                 "rolling %d frame window and not from a lifetime count, because the reload gate fires only "
                 "when the cached timestamp pair changes",
                 (unsigned long long)(g_v122_pre_frames - g_v122_win_mark),
                 (unsigned long long)g_v122_pre_reloads, (unsigned long long)g_v122_prev_win_reloads,
                 TNX_V122_PRE_FRAMES);
    }

    if (g_v121_win_stage == 0 && d > TNX_V121_WIN1_FRAMES) {
        g_v121_win_stage = 1;

        tnx_logf("v122 winA push+0..%dF reloads=%llu rate=%llu per %dF - a round trip of 50 to 150 ms lands "
                 "here on a fast connection, so a jump against winPre means the server answered",
                 TNX_V121_WIN1_FRAMES, (unsigned long long)(g_v120_reloads - g_v121_win_reloads),
                 (unsigned long long)(g_v120_reloads - g_v121_win_reloads), TNX_V121_WIN1_FRAMES);

        g_v121_win_reloads = g_v120_reloads;
    }

    if (g_v121_win_stage == 1 && d > TNX_V121_WIN2_FRAMES) {
        g_v121_win_stage = 2;

        tnx_logf("v122 winB push+%d..%dF reloads=%llu rate=%llu per %dF - second window, so a slow answer "
                 "is separated from no answer instead of being lumped into one verdict",
                 TNX_V121_WIN1_FRAMES, TNX_V121_WIN2_FRAMES,
                 (unsigned long long)(g_v120_reloads - g_v121_win_reloads),
                 (unsigned long long)(g_v120_reloads - g_v121_win_reloads),
                 (TNX_V121_WIN2_FRAMES - TNX_V121_WIN1_FRAMES));
    }
}



static void tnx_v122_prewin(void) {
    if (g_v122_win_mark == 0 || (g_v48_ticks - g_v122_win_mark) >= TNX_V122_PRE_FRAMES) {
        g_v122_win_mark = g_v48_ticks;
        g_v122_prev_win_reloads = g_v120_reloads;
    }
}

static uint64_t g_v125_calls_to_991440 = 0;

static int tnx_is_heap(uintptr_t v) {
    return (v >= TNX_V125_HEAP_LO && v < TNX_V125_HEAP_HI && (v & 0x7) == 0) ? 1 : 0;
}

static void tnx_v125_bounds(uintptr_t own) {
    int32_t bx = 0;
    int32_t by = 0;

    if (!own) return;
    if (!tnx_is_heap(own)) {
        tnx_logf("v125 bounds skip own=%p notHeap=1 - the element pointer failed the heap and alignment "
                 "guard, so the two word read is skipped instead of dereferencing it", (void *)own);

        return;
    }

    if (!tnx_read_i32(own + TNX_V122_BOUND_X_OFF, &bx)) return;
    if (!tnx_read_i32(own + TNX_V122_BOUND_Y_OFF, &by)) return;

    tnx_logf("v125 bounds own=%p bx=%d by=%d calls991440=%llu - the box comes from the walked element "
             "itself now; the old route called the getter %#llx and then %#llx on whatever it returned, "
             "and that is the call that crashed with x0=%#llx because x0+%#x is exactly the reported FAR",
             (void *)own, bx, by, (unsigned long long)g_v125_calls_to_991440,
             (unsigned long long)TNX_V122_OWN_GETTER_RVA,
             (unsigned long long)TNX_V122_RESOLVE_SELF_RVA, (unsigned long long)0x100010055ULL,
             (unsigned)0xf8);
}

static void tnx_v122_entities2(void) {
    uintptr_t getter = tnx_v113_entry(TNX_V120_ENTITY_GETTER_RVA);
    void *obj = NULL;
    void *container = NULL;
    char buf[340];
    size_t used = 0;
    int32_t count = -1;
    int i;

    if (!g_scene_object || !getter) return;
    if (g_v122_ent2_logs >= 12) return;
    if (g_v103_tick % 50) return;

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V117_GATE3_PTR_OFF, &obj) || !obj) return;

    container = ((void *(*)(void *))getter)(obj);

    if (!container) return;

    tnx_read_i32((uintptr_t)container + 0xc, &count);

    if (count <= 0) return;

    if (count > 8) count = 8;

    g_v122_ent2_logs++;

    for (i = 0; i < count; i++) {
        void *e = NULL;
        void *vt = NULL;
        uintptr_t r = 0;
        uint8_t el = 0;
        int32_t px = 0;
        int32_t py = 0;
        int32_t gid = 0;

        if (!tnx_read_ptr((uintptr_t)container + (uintptr_t)i * 8ULL, &e) || !e) continue;

        if (tnx_read_ptr((uintptr_t)e, &vt) && vt) r = (uintptr_t)vt - g_base;

        tnx_read_u8((uintptr_t)e + TNX_V119_ELIG_OFF, &el);
        tnx_read_i32((uintptr_t)e + TNX_V122_POS_X_OFF, &px);
        tnx_read_i32((uintptr_t)e + TNX_V122_POS_Y_OFF, &py);
        tnx_read_i32((uintptr_t)e + TNX_V112_GID_OFF, &gid);

        used += (size_t)snprintf(buf + used, sizeof(buf) - used,
                                 "[%d vt=%#llx elig=%d pos=(%d,%d) gid=%d]", i,
                                 (unsigned long long)r, (int)el, px, py, gid);
        if (used >= sizeof(buf) - 64) break;
    }

    tnx_logf("v122 entities2 count=%d %s - vt %#llx is a brawler and %#llx is a lobby or roster slot, so "
             "this line decides whether the interpolation list carries live units or UI rows",
             count, buf, (unsigned long long)0xff5440ULL, (unsigned long long)0xf9e248ULL);
}


static int g_v123_dump_done = 0;
static uintptr_t g_v123_w1_elem = 0;
static int32_t g_v123_w1_x = 0;
static int32_t g_v123_w1_y = 0;
static int32_t g_v123_w1_was_x = 0;
static int32_t g_v123_w1_was_y = 0;
static uint64_t g_v123_w1_frame = 0;
static int g_v123_w1_state = 0;
static uintptr_t g_v123_w2_elem = 0;
static int32_t g_v123_w2_x = 0;
static int32_t g_v123_w2_y = 0;
static int32_t g_v123_w2_was_x = 0;
static int32_t g_v123_w2_was_y = 0;
static uint64_t g_v123_w2_frame = 0;
static int g_v123_w2_state = 0;

static int tnx_v123_hop2_arr(void **containerOut, void **arrOut, int32_t *countOut) {
    void *outer = NULL;
    void *container = NULL;
    void *arr = NULL;
    int32_t count = 0;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V115_CLIENT_OFF, &outer) || !outer) return 0;
    if (!tnx_read_ptr((uintptr_t)outer + TNX_V115_CLIENT_OFF, &container) || !container) return 0;
    if (!tnx_read_ptr((uintptr_t)container + TNX_MGR_ARRAY_OFF, &arr) || !arr) return 0;
    if (!tnx_read_i32((uintptr_t)container + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0 || count > 16) return 0;

    if (containerOut) *containerOut = container;
    if (arrOut) *arrOut = arr;
    if (countOut) *countOut = count;

    return 1;
}

static void tnx_v123_hop2dump(void) {
    void *container = NULL;
    void *arr = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int ownIdx = -1;
    int ownGid = -1;
    void *h1arr = NULL;
    int32_t h1count = 0;

    if (g_v123_dump_done) return;
    if (g_v103_tick < 2) return;
    if (!tnx_v123_hop2_arr(&container, &arr, &count)) return;

    g_v123_dump_done = 1;

    if (g_players_object) {
        void *piece = NULL;

        if (tnx_read_ptr((uintptr_t)g_players_object + TNX_MGR_ARRAY_OFF, &piece)) h1arr = piece;

        tnx_read_i32((uintptr_t)g_players_object + TNX_MGR_COUNT_OFF, &h1count);
        tnx_read_i32((uintptr_t)g_players_object + TNX_V123_OWN_IDX_OFF, &ownIdx);

        if (h1arr && ownIdx >= 0 && ownIdx < h1count) {
            void *e = NULL;

            if (tnx_read_ptr((uintptr_t)h1arr + (uintptr_t)ownIdx * 8ULL, &e) && e) {
                tnx_read_i32((uintptr_t)e + TNX_V112_GID_OFF, &ownGid);
            }
        }
    }

    tnx_logf("v125 hop2 use ptr=%p arr=%p count=%d ownIdxHop1=%d ownGid=%d isHeap=%d caller=%#llx - this "
             "line runs before anything else reads the fresh list and isHeap gates every later use",
             container, arr, count, ownIdx, ownGid, tnx_is_heap((uintptr_t)container),
             (unsigned long long)0xa24278ULL);

    tnx_logf("v123 hop2dump container=%p arr=%p count=%d ownIdxHop1=%d ownGid=%d - the fresh hop2 list is "
             "read only, never adopted in this build, and own is looked up by gid and not by pointer",
             container, arr, count, ownIdx, ownGid);

    for (i = 0; i < count && i < 12; i++) {
        void *e = NULL;
        void *vt = NULL;
        uintptr_t r = 0;
        int32_t gid = 0;
        int32_t team = 0;
        int32_t x = 0;
        int32_t y = 0;
        uint8_t h1 = 0;
        uint8_t h7 = 0;
        int isOwn = 0;

        if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)i * 8ULL, &e) || !e) continue;

        if (tnx_read_ptr((uintptr_t)e, &vt) && vt) r = (uintptr_t)vt - g_base;

        tnx_read_i32((uintptr_t)e + TNX_V112_GID_OFF, &gid);
        tnx_read_i32((uintptr_t)e + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)e + TNX_OBJ_X_OFF, &x);
        tnx_read_i32((uintptr_t)e + TNX_OBJ_Y_OFF, &y);
        tnx_read_u8((uintptr_t)e + TNX_V119_ELIG_OFF, &h1);
        tnx_read_u8((uintptr_t)e + TNX_V115_GATE_BYTE_OFF, &h7);

        if (ownGid >= 0 && gid == ownGid) isOwn = 1;

        tnx_logf("v123 hop2[%d] p=%p vt=%#llx gid50=%d t40=%d xy=(%d,%d) h1fd=%d h7a=%d own=%d",
                 i, e, (unsigned long long)r, gid, team, x, y, (int)h1, (int)h7, isOwn);
    }
}

static void tnx_v123_writes(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    if (usable <= 0 || !objects) return;

    if (!TNX_V126_WTEST_H1) {
        if (!g_v126_wtest_h1_off) {
            g_v126_wtest_h1_off = 1;

            tnx_logf("v126 wtestH1 off - the hop1 int pair at +%#llx/+%#llx was proven writable with held=1 "
                     "in the v125 run, but hop1 is a roster whose elements carry no coordinates at all, so "
                     "that write put (1,1) into the walked own element and turned the coordinate census it "
                     "was meant to help into evidence of its own injection: the v125 run reported "
                     "distinct=2 and coords ok=1 on a list whose own element had been moved by this test, "
                     "and the readback of the enqueue test then matched that injected pair instead of the "
                     "pushed one",
                     (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);
        }

        g_v123_w1_state = 2;
    } else if (g_v123_w1_state == 0) {
        uintptr_t e = objects[(ownIndex >= 0 && ownIndex < usable) ? ownIndex : 0].object;
        int32_t vx = 0;
        int32_t vy = 0;

        if (!e) return;

        tnx_read_i32(e + TNX_OBJ_X_OFF, &g_v123_w1_was_x);
        tnx_read_i32(e + TNX_OBJ_Y_OFF, &g_v123_w1_was_y);

        g_v123_w1_x = g_v123_w1_was_x + 1;
        g_v123_w1_y = g_v123_w1_was_y + 1;
        vx = g_v123_w1_x;
        vy = g_v123_w1_y;

        tnx_write_bytes(e + TNX_OBJ_X_OFF, &vx, sizeof(vx));
        tnx_write_bytes(e + TNX_OBJ_Y_OFF, &vy, sizeof(vy));

        g_v123_w1_elem = e;
        g_v123_w1_frame = g_v48_ticks;
        g_v123_w1_state = 1;

        tnx_logf("v123 wtestH1 wrote elem=%p x=%d y=%d was=(%d,%d) - a hop1 slot takes one synthetic write "
                 "in the int pair to prove whether that pair is writable at all, before any network route "
                 "is trusted",
                 (void *)e, g_v123_w1_x, g_v123_w1_y, g_v123_w1_was_x, g_v123_w1_was_y);
    } else if (g_v123_w1_state == 1 && (g_v48_ticks - g_v123_w1_frame) >= TNX_V123_WRITE_WAIT) {
        int32_t x = 0;
        int32_t y = 0;

        g_v123_w1_state = 2;

        tnx_read_i32(g_v123_w1_elem + TNX_OBJ_X_OFF, &x);
        tnx_read_i32(g_v123_w1_elem + TNX_OBJ_Y_OFF, &y);

        tnx_logf("v123 wtestH1 held=%d now=(%d,%d) want=(%d,%d) frames=%llu - held=0 means something else "
                 "wrote the pair back, held=1 means the write survives and the int pair is a plain store",
                 (x == g_v123_w1_x && y == g_v123_w1_y) ? 1 : 0, x, y, g_v123_w1_x, g_v123_w1_y,
                 (unsigned long long)(g_v48_ticks - g_v123_w1_frame));
    }

    if (g_v123_w2_state == 0) {
        void *container = NULL;
        void *arr = NULL;
        int32_t count = 0;
        void *e = NULL;
        int32_t vx = 0;
        int32_t vy = 0;

        if (!tnx_v123_hop2_arr(&container, &arr, &count)) return;
        if (!tnx_read_ptr((uintptr_t)arr, &e) || !e) return;

        tnx_read_i32((uintptr_t)e + TNX_OBJ_X_OFF, &g_v123_w2_was_x);
        tnx_read_i32((uintptr_t)e + TNX_OBJ_Y_OFF, &g_v123_w2_was_y);

        g_v123_w2_x = g_v123_w2_was_x + TNX_V123_STEP;
        g_v123_w2_y = g_v123_w2_was_y + TNX_V123_STEP;
        vx = g_v123_w2_x;
        vy = g_v123_w2_y;

        tnx_write_bytes((uintptr_t)e + TNX_OBJ_X_OFF, &vx, sizeof(vx));
        tnx_write_bytes((uintptr_t)e + TNX_OBJ_Y_OFF, &vy, sizeof(vy));

        g_v123_w2_elem = (uintptr_t)e;
        g_v123_w2_frame = g_v48_ticks;
        g_v123_w2_state = 1;

        tnx_logf("v123 wtestH2 wrote elem[0]=%p x=%d y=%d was=(%d,%d) - this is the hop2 element in class "
                 "%#llx and the answer is binary: if the pair holds, element+%#llx is writable and the "
                 "actuator is a plain store, if it snaps back the int pair is engine owned",
                 e, g_v123_w2_x, g_v123_w2_y, g_v123_w2_was_x, g_v123_w2_was_y,
                 (unsigned long long)0xff5440ULL, (unsigned long long)TNX_OBJ_X_OFF);
    } else if (g_v123_w2_state == 1 && (g_v48_ticks - g_v123_w2_frame) >= TNX_V123_WRITE_WAIT) {
        int32_t x = 0;
        int32_t y = 0;

        g_v123_w2_state = 2;

        tnx_read_i32(g_v123_w2_elem + TNX_OBJ_X_OFF, &x);
        tnx_read_i32(g_v123_w2_elem + TNX_OBJ_Y_OFF, &y);

        tnx_logf("v123 wtestH2 held=%d now=(%d,%d) want=(%d,%d) frames=%llu",
                 (x == g_v123_w2_x && y == g_v123_w2_y) ? 1 : 0, x, y, g_v123_w2_x, g_v123_w2_y,
                 (unsigned long long)(g_v48_ticks - g_v123_w2_frame));
    }
}

static void *tnx_v126_battle(void) {
    uintptr_t fn = tnx_v113_entry(TNX_V113_GETBATTLE_RVA);

    if (!fn) return NULL;

    return ((void *(*)(void))fn)();
}

static int tnx_v126_plausible(int32_t v) {
    if (v <= 0) return 0;
    if (v > 100000) return 0;

    return 1;
}

static void tnx_v126_ownmatch(void) {
    void *container = NULL;
    void *arr = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int hit = -1;
    int32_t team = 0;
    int32_t hx = 0;
    int32_t hy = 0;

    if (!g_v126_own_ok) return;
    if (g_v126_ownmatch_logs >= 4) return;
    if (!tnx_v123_hop2_arr(&container, &arr, &count)) return;

    for (i = 0; i < count && i < 16; i++) {
        void *e = NULL;
        int32_t x = 0;
        int32_t y = 0;

        if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)i * 8ULL, &e) || !e) continue;

        tnx_read_i32((uintptr_t)e + TNX_OBJ_X_OFF, &x);
        tnx_read_i32((uintptr_t)e + TNX_OBJ_Y_OFF, &y);

        if (x == g_v126_own_x && y == g_v126_own_y) {
            hit = (int)i;
            hx = x;
            hy = y;

            tnx_read_i32((uintptr_t)e + TNX_OBJ_TEAM_OFF, &team);

            break;
        }
    }

    g_v126_ownmatch_logs++;

    tnx_logf("v126 ownmatch tag=%s own=(%d,%d) box=(%d,%d) hop2Index=%d team=%d elem=(%d,%d) - own is taken "
             "from the membership chain and then matched into the brawler list by its coordinate pair, "
             "which is the index the dodge needs: the hop1 list names own by the gid at +%#llx and the "
             "slot index at +%#llx but carries no position at all, and the hop2 list carries the positions "
             "but a zero id on every element, so the pair is the only key the two lists share",
             g_v126_own_tag, g_v126_own_x, g_v126_own_y, g_v126_box_lo, g_v126_box_hi, hit, team, hx, hy,
             (unsigned long long)TNX_V112_GID_OFF, (unsigned long long)TNX_V123_OWN_IDX_OFF);
}

static void tnx_v126_chain_one(const char *tag, uintptr_t base) {
    void *p = NULL;
    void *q = NULL;
    void *box = NULL;
    void *vt = NULL;
    uintptr_t vtq = 0;
    uintptr_t vtr = 0;
    uint32_t raw = 0;
    int32_t qx = -1;
    int32_t qy = -1;
    int32_t inA = -1;
    int32_t inB = -1;
    int32_t boxLo = -1;
    int32_t boxHi = -1;

    if (!base) return;

    tnx_read_u32(base + TNX_V126_OWN_OFF, &raw);

    if (!tnx_read_ptr(base + TNX_V126_OWN_OFF, &p) || !p) {
        tnx_logf("v126 chain %-7s base=%p +%#llx raw=%#x p=0 - nothing readable behind the one field "
                 "getOwnCharacter %#llx dereferences, so this object is not a receiver that chain accepts",
                 tag, (void *)base, (unsigned long long)TNX_V126_OWN_OFF, raw,
                 (unsigned long long)0x7b9050ULL);

        return;
    }

    if (!tnx_read_ptr((uintptr_t)p + TNX_V126_OWN_INNER_OFF, &q) || !q) {
        tnx_logf("v126 chain %-7s base=%p p=%p inner=0 - the first hop reads but its +%#llx is null, so "
                 "the own character is not behind this base this tick",
                 tag, (void *)base, p, (unsigned long long)TNX_V126_OWN_INNER_OFF);

        return;
    }

    if (tnx_read_ptr((uintptr_t)q, &vt) && vt) vtq = (uintptr_t)vt - g_base;

    tnx_read_i32((uintptr_t)q + TNX_OBJ_X_OFF, &qx);
    tnx_read_i32((uintptr_t)q + TNX_OBJ_Y_OFF, &qy);
    tnx_read_i32((uintptr_t)q + TNX_V112_INPUT_X_OFF, &inA);
    tnx_read_i32((uintptr_t)q + TNX_V112_INPUT_Y_OFF, &inB);

    if (tnx_read_ptr((uintptr_t)q + TNX_V126_BOX_PTR_OFF, &box) && box) {
        vtr = (uintptr_t)box - g_base;

        tnx_read_i32((uintptr_t)box + TNX_V126_BOX_MIN_OFF, &boxLo);
        tnx_read_i32((uintptr_t)box + TNX_V126_BOX_MIN_OFF + 4, &boxHi);
    }

    if (!g_v126_own_ok && vtq && tnx_v126_plausible(boxLo) && tnx_v126_plausible(boxHi) &&
        qx > -TNX_V75_COORD_MAX && qx < TNX_V75_COORD_MAX &&
        qy > -TNX_V75_COORD_MAX && qy < TNX_V75_COORD_MAX) {
        g_v126_own_ok = 1;
        g_v126_own_x = qx;
        g_v126_own_y = qy;
        g_v126_box_lo = boxLo;
        g_v126_box_hi = boxHi;
        g_v126_own_tag = tag;
    }

    tnx_logf("v126 chain %-7s base=%p +%#llx raw=%#x p=%p q=%p vtq=%#llx pos=(%d,%d) in10c=%d in110=%d "
             "box=%p vtr=%#llx bounds=(%d,%d) - this is the chain the battle update walks at %#llx: "
             "getOwnCharacter reads the word at +%#llx off its receiver, the own character is that "
             "object's +%#llx, the own position is the int pair at +%#llx/+%#llx, the input the setter "
             "%#llx stores lives at +%#llx/+%#llx on the same object, and the clamp box is +%#llx of the "
             "object the own character holds at +%#llx, so a line whose bounds reads as a plausible map "
             "size at once names the receiver and the own position of this battle",
             tag, (void *)base, (unsigned long long)TNX_V126_OWN_OFF, raw, p, q,
             (unsigned long long)vtq, qx, qy, inA, inB, box, (unsigned long long)vtr, boxLo, boxHi,
             (unsigned long long)0x79de48ULL, (unsigned long long)TNX_V126_OWN_OFF,
             (unsigned long long)TNX_V126_OWN_INNER_OFF, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF, (unsigned long long)TNX_V112_SETPRED4_RVA,
             (unsigned long long)TNX_V112_INPUT_X_OFF, (unsigned long long)TNX_V112_INPUT_Y_OFF,
             (unsigned long long)TNX_V126_BOX_MIN_OFF, (unsigned long long)TNX_V126_BOX_PTR_OFF);
}

static void tnx_v126_chain(void) {
    void *container = NULL;
    void *arr = NULL;
    int32_t count = 0;

    if (g_v126_chain_logs >= TNX_V126_CHAIN_LOGS) return;
    if (g_v103_tick % TNX_V126_CHAIN_EVERY) return;

    g_v126_chain_logs++;

    tnx_v126_chain_one("scene", (uintptr_t)g_scene_object);
    tnx_v126_chain_one("player", (uintptr_t)g_players_object);
    tnx_v126_chain_one("battle", (uintptr_t)tnx_v126_battle());
    tnx_v126_chain_one("input", (uintptr_t)tnx_v113_manager());

    if (tnx_v123_hop2_arr(&container, &arr, &count)) {
        tnx_v126_chain_one("hop2", (uintptr_t)container);
    }

    tnx_v126_ownmatch();
}

static void tnx_v126_watch(void) {
    void *container = NULL;
    void *arr = NULL;
    int32_t count = 0;
    uint64_t d = 0;
    char buf[320];
    size_t used = 0;
    int32_t i = 0;

    if (!g_v126_enq_ok) return;
    if (g_v126_watch_logs >= TNX_V126_WATCH_LOGS) return;
    if (!g_v126_watch_from) g_v126_watch_from = g_v48_ticks;

    d = g_v48_ticks - g_v126_watch_from;

    if (d > TNX_V126_WATCH_TICKS) return;
    if (d % TNX_V126_WATCH_EVERY) return;
    if (!tnx_v123_hop2_arr(&container, &arr, &count)) return;

    g_v126_watch_logs++;
    buf[0] = '\0';

    for (i = 0; i < count && i < 8; i++) {
        void *e = NULL;
        int32_t x = 0;
        int32_t y = 0;

        if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)i * 8ULL, &e) || !e) continue;

        tnx_read_i32((uintptr_t)e + TNX_OBJ_X_OFF, &x);
        tnx_read_i32((uintptr_t)e + TNX_OBJ_Y_OFF, &y);

        used += (size_t)snprintf(buf + used, sizeof(buf) - used, "[%d (%d,%d)]", (int)i, x, y);

        if (used >= sizeof(buf) - 40) break;
    }

    tnx_logf("v126 watch t=+%llu msg=%p %s - the brawler list is sampled after the real enqueue, so the "
             "pair that changes is the object the pushed input reached, and that identifies own and proves "
             "the actuator without a readback on an object this build cannot yet name",
             (unsigned long long)d, g_v126_msg, buf);
}

static void tnx_v117_match(int32_t ix, int32_t iy) {
    tnx_v47_obj_t objs[8];
    int rej = 0;
    int n = 0;
    int best = -1;
    int bestGid = -1;
    int64_t bestd = 0;
    int i;

    if (!g_players_object) return;

    n = tnx_v48_collect((uintptr_t)g_players_object, objs, 8, &rej);

    if (n <= 0) return;

    for (i = 0; i < n; i++) {
        int32_t ex = 0;
        int32_t ey = 0;
        int64_t d;

        if (!tnx_v117_pair(objs[i].object, &ex, &ey)) continue;

        d = (int64_t)(ex - ix) * (int64_t)(ex - ix) + (int64_t)(ey - iy) * (int64_t)(ey - iy);

        if (best < 0 || d < bestd) {
            best = i;
            bestd = d;
            bestGid = objs[i].gid;
        }
    }

    if (best < 0) return;

    g_v117_match_streak = (best == g_v117_match_idx) ? g_v117_match_streak + 1 : 0;
    g_v117_match_idx = best;
    g_v117_match_gid = bestGid;

    tnx_logf("v117 ownInterp matchElem=%d matchGid=%d streak=%d dist2=%lld n=%d own=(%d,%d) mode=%d "
             "gate1=%d gate2=%d gate3=%d - the nearest element is matched on its own pair at +%#llx/+%#llx, "
             "so a stable index with a rising streak is hypothesis H1, the client pair is that element's own "
             "position, while an index that keeps changing means H2, the pair is a screen space or camera "
             "target that drifts between elements",
             best, bestGid, g_v117_match_streak, (long long)bestd, n, ix, iy, tnx_v115_mode(),
             (tnx_v115_mode() == TNX_V115_MODE_TARGET) ? 1 : 0,
             (tnx_v115_inner() == 1) ? 1 : 0, (tnx_v115_inner() == 1) ? 1 : 0,
             (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);
}

static void tnx_v116_frame(void) {
    int mode = tnx_v115_mode();

    if (mode >= 0 && mode < TNX_V116_HIST_MODES) g_v116_mode_hist[mode]++;

    tnx_v119_gate_ticks();
    tnx_v120_thermometer();
    tnx_v121_window();
    tnx_v122_prewin();
    if (tnx_v115_inner() == 1 && mode == TNX_V115_MODE_TARGET) g_v117_gate2_seen++;
    if (tnx_v117_src(TNX_V117_GATE3_PTR_OFF, NULL, NULL, NULL)) g_v117_gate3_seen++;

    if (mode != g_v116_last_mode) {
        if (g_v116_hist_logs < TNX_V116_HIST_LOGS) {
            g_v116_hist_logs++;

            {
                int32_t e0 = -1;

                if (g_scene_object) {
                    tnx_read_i32((uintptr_t)g_scene_object + 0xe0, &e0);
                }

                tnx_logf("v117 mode change tick=%llu frames=%llu mode: %lld -> %d e0=%d from=unavail - "
                         "this line fires the moment setMode ran, so a momentary 7 in a transition frame "
                         "is caught instead of being averaged away by mode_max; the caller cannot be "
                         "named because setMode %#llx and its two sites %#llx and %#llx have no data slot "
                         "in __DATA_CONST or __DATA, so only the +0xe0 side effect is left as a "
                         "discriminator and e0=0 right at a change points at the %#llx site",
                         (unsigned long long)g_v103_tick, (unsigned long long)g_v48_ticks,
                         (long long)g_v116_last_mode, mode, e0, (unsigned long long)0xac3a70ULL,
                         (unsigned long long)0x760cdcULL, (unsigned long long)0x764350ULL,
                         (unsigned long long)0x764350ULL);
            }
        }

        g_v116_last_mode = mode;
    }
}

static void tnx_v116_interp_line(void) {
    int32_t x = 0;
    int32_t y = 0;
    int moved = 0;

    if (!tnx_v116_interp(&x, &y)) return;
    if (g_v103_tick - g_v116_interp_tick < TNX_V116_INTERP_TICKS) return;

    g_v116_interp_tick = g_v103_tick;
    g_v116_interp_checks++;

    if (g_v116_interp_have) moved = (x != g_v116_interp_prev_x || y != g_v116_interp_prev_y) ? 1 : 0;
    if (moved) g_v116_interp_moves++;

    tnx_v117_match(x, y);

    {
        int32_t s30x = 0;
        int32_t s30y = 0;
        int f30 = -1;
        int32_t s38x = 0;
        int32_t s38y = 0;
        int f38 = -1;

        tnx_v117_src(TNX_V115_GATE_PTR_OFF, &s30x, &s30y, &f30);
        tnx_v117_src(TNX_V117_GATE3_PTR_OFF, &s38x, &s38y, &f38);

        uintptr_t p30 = tnx_v118_mode_ptr(TNX_V115_GATE_PTR_OFF);
        uintptr_t p38 = tnx_v118_mode_ptr(TNX_V117_GATE3_PTR_OFF);
        int32_t dx = s30x - s38x;
        int32_t dy = s30y - s38y;
        int s30moved = 0;
        int s38moved = 0;

        if (g_v118_src30_have) s30moved = (s30x != g_v118_src30_prev_x || s30y != g_v118_src30_prev_y) ? 1 : 0;
        if (g_v118_src38_have) s38moved = (s38x != g_v118_src38_prev_x || s38y != g_v118_src38_prev_y) ? 1 : 0;
        if (s30moved) g_v118_src30_moves++;
        if (s38moved) g_v118_src38_moves++;

        if (dx < 0) dx = -dx;
        if (dy < 0) dy = -dy;

        g_v118_w_eq_x = (dx < TNX_V119_DENOM_MIN) ? -999 : tnx_v118_weq(s30x, s38x, x, (s30x - s38x));
        g_v118_w_eq_y = (dy < TNX_V119_DENOM_MIN) ? -999 : tnx_v118_weq(s30y, s38y, y, (s30y - s38y));

        tnx_logf("v119 src30=(%d,%d) f30=%d src38=(%d,%d) f38=%d srcEq=%d denomX=%d denomY=%d dCX=%d dCY=%d d38X=%d "
                 "d38Y=%d wEqX=%d wEqY=%d "
                 "s30moved=%d s38moved=%d src30Moves=%llu src38Moves=%llu client=(%d,%d) gate2Seen=%d "
                 "gate3Seen=%d - w28 itself is a register inside the mode update and no hook can reach it "
                 "because %#llx has no data slot, but the effective weight is recoverable from the three "
                 "pairs: wEq~1000 means the client sits on src30, wEq~0 means it sits on src38, wEq=-999 means denom "
                 "was under %d so no weight is claimed at all, and the raw dC/d38 columns are printed so "
                 "a real 500 cannot be mistaken for rounding noise; srcEq=1 makes the lerp meaningless "
                 "because both ends are one pointer",
                 s30x, s30y, f30, s38x, s38y, f38, (p30 == p38) ? 1 : 0, dx, dy, x - s30x, y - s30y,
                 x - s38x, y - s38y, g_v118_w_eq_x, g_v118_w_eq_y, s30moved, s38moved,
                 (unsigned long long)g_v118_src30_moves, (unsigned long long)g_v118_src38_moves, x, y,
                 g_v117_gate2_seen, g_v117_gate3_seen, (unsigned long long)0xa26890ULL,
                 TNX_V119_DENOM_MIN);

        g_v118_src30_prev_x = s30x;
        g_v118_src30_prev_y = s30y;
        g_v118_src38_prev_x = s38x;
        g_v118_src38_prev_y = s38y;
        g_v118_src30_have = 1;
        g_v118_src38_have = 1;
    }

    tnx_logf("v116 ownInterp prev=(%d,%d) now=(%d,%d) delta=%d moves=%llu checks=%llu mode=%d gate=%d - "
             "the pair at client+%#llx/+%#llx is written every frame by %#llx inside the mode gate, so it "
             "is the live own position: delta=1 with no test at all already means the engine moves own and "
             "the walk pair at +%#llx/+%#llx was never the position",
             g_v116_interp_prev_x, g_v116_interp_prev_y, x, y, moved,
             (unsigned long long)g_v116_interp_moves, (unsigned long long)g_v116_interp_checks,
             tnx_v115_mode(), tnx_v115_gate(), (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF, (unsigned long long)0xa26890ULL,
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

    g_v116_interp_prev_x = x;
    g_v116_interp_prev_y = y;
    g_v116_interp_have = 1;
}

static void tnx_v116_hist_line(void) {
    uint32_t rest = 0;
    int i;

    if (g_v103_tick % TNX_V116_HIST_TICKS) return;
    if (g_v116_hist_logs >= TNX_V116_HIST_LOGS) return;

    for (i = 8; i < TNX_V116_HIST_MODES; i++) rest += g_v116_mode_hist[i];

    g_v116_hist_logs++;

    tnx_logf("v117 modeHist m0=%u m1=%u m2=%u m3=%u m4=%u m5=%u m6=%u m7=%u rest=%u gate1=%d gate2=%d "
             "gate3=%d g1t=%llu g2t=%llu g3t=%llu anyElig=%d f138=%d f13c=%d snapStampF138=%d snapStampF13c=%d reloads=%llu interpMoves=%llu - the histogram separates a momentary mode 7 in a transition frame from a "
             "mode that never reaches 7 at all, which a single binary saw7 flag cannot do",
             g_v116_mode_hist[0], g_v116_mode_hist[1], g_v116_mode_hist[2], g_v116_mode_hist[3],
             g_v116_mode_hist[4], g_v116_mode_hist[5], g_v116_mode_hist[6], g_v116_mode_hist[7], rest,
             (tnx_v115_mode() == TNX_V115_MODE_TARGET) ? 1 : 0, (tnx_v115_inner() == 1) ? 1 : 0,
             g_v117_gate3_seen, (unsigned long long)g_v119_gate1_tick,
             (unsigned long long)g_v119_gate2_tick, (unsigned long long)g_v119_gate3_tick,
             g_v119_elig_any, g_v120_f138_prev, g_v120_f13c_prev, g_v120_f138_prev, g_v120_f13c_prev,
             (unsigned long long)g_v120_reloads, (unsigned long long)g_v116_interp_moves);
}

static int tnx_v113_fields(void) {
    int32_t x = 0;
    int32_t y = 0;

    if (!g_scene_object) return -1;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &x)) return -1;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &y)) return -1;

    return (x == g_v113_enq_x) ? 1 : 0;
}

static void tnx_v113_frame_window(void) {
    uint64_t d = 0;
    int32_t inX = 0;
    int32_t inY = 0;

    if (!g_v113_push_frame) return;

    d = g_v48_ticks - g_v113_push_frame;

    if (d > TNX_V113_FRAME_WINDOW) return;
    if (g_v113_frame_logs >= 40) return;

    g_v113_frame_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
    }

    {
        uintptr_t client = tnx_v115_client();
        int32_t cx = 0;
        int32_t cy = 0;
        int32_t ck = 0;

        if (client) {
            tnx_read_i32(client + TNX_V115_CLIENT_POS_X_OFF, &cx);
            tnx_read_i32(client + TNX_V115_CLIENT_POS_Y_OFF, &cy);
        }

        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &ck);

        tnx_logf("v117 frame tick=%llu frame=+%llu qcount=%d mode=%d gate=%d inner=%d in10c=%d(%s) "
                 "in110=%d(%s) in114=%d client80=%d client84=%d - the window carries the mode id because "
                 "three different causes leave the same empty readback: the queue not being consumed, "
                 "the queue consumed while the +%#llx branch is gated because mode != %d, and the branch "
                 "running while the apply path never touches +%#llx; gate=1 means mode == %d and "
                 "(*[mode+%#llx])+%#x == 1; client80/client84 is the pair %#llx writes on the client at "
                 "client+%#llx, which is the interpolation output and the sharpest position signal here",
                 (unsigned long long)g_v103_tick, (unsigned long long)d, tnx_v113_queue_count(NULL),
                 tnx_v115_mode(), tnx_v115_gate(), tnx_v115_inner(), inX, tnx_v113_state_x(inX),
                 inY, tnx_v113_state_y(inY), ck, cx, cy, (unsigned long long)TNX_V113_READER_RVA,
                 TNX_V115_MODE_TARGET, (unsigned long long)TNX_V112_INPUT_X_OFF, TNX_V115_MODE_TARGET,
                 (unsigned long long)TNX_V115_GATE_PTR_OFF, (unsigned)TNX_V115_GATE_BYTE_OFF,
                 (unsigned long long)0xa26890ULL, (unsigned long long)TNX_V115_CLIENT_POS_X_OFF);
    }
}

static void tnx_v113_window(int plus) {
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (g_v113_window_logs >= 12) return;

    g_v113_window_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &inK);
    }

    tnx_logf("v113 window tick=+%d qcount=%d in10c=%d in110=%d in114=%d want=(%d,%d) match=%d - logged "
             "tick by tick because addInput evicts an older entry that carries the same key, so a count "
             "that rises and falls inside these ticks is our message eaten by a game message of the same "
             "type rather than by the consumer",
             plus, tnx_v113_queue_count(NULL), inX, inY, inK, g_v113_enq_x, g_v113_enq_y,
             tnx_v113_fields());
}

static void tnx_v113_test(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    int32_t x = 0;
    int32_t y = 0;
    int qnow = -1;
    const char *verdict = "readback-unreadable";

    if (!objects || ownIndex < 0 || ownIndex >= usable) return;
    if (g_v113_test_state >= 4) return;
    if (!g_scene_object) return;

    if (!g_v113_test_tickbase) g_v113_test_tickbase = g_v103_tick;

    {
        int mode = tnx_v115_mode();

        if (mode > g_v115_mode_max) g_v115_mode_max = mode;
        if (mode == TNX_V115_MODE_TARGET) g_v115_mode_seen7 = 1;
        if (tnx_v115_gate() == 1) g_v115_gate_seen = 1;
    }

    if (!TNX_V115_TEST_ENABLE) {
        if (g_v113_test_state == 0 && (g_v103_tick - g_v113_test_tickbase) >= TNX_V115_MODE_WAIT) {
            g_v113_test_state = 4;
            g_v113_tested = 1;

            tnx_logf("v115 notest mode_max=%d saw7=%d gateSeen=%d gate=%d - the build ran without the "
                     "enqueue test and this line is the mode census: with saw7=0 the +%#llx branch is "
                     "unreachable in this battle because the mode id never reaches %d, so the whole "
                     "+0xac pipeline, %#llx and the client pair write belong to that mode alone",
                     g_v115_mode_max, g_v115_mode_seen7, g_v115_gate_seen, tnx_v115_gate(),
                     (unsigned long long)TNX_V113_READER_RVA, TNX_V115_MODE_TARGET,
                     (unsigned long long)0xa26890ULL);
        }

        return;
    }

    if (g_v113_test_state == 0) {
        if (TNX_V115_REQUIRE_GATE && tnx_v115_gate() != 1) {
            if (g_v115_mode_wait_logs < 2) {
                g_v115_mode_wait_logs++;

                tnx_logf("v115 modewait tick=%llu mode=%d target=%d inner=%d gate=%d - the test is held "
                         "until the reader gate opens, because the +%#llx branch answers only when the "
                         "mode id at +%#llx is %d and (*[mode+%#llx])+%#x is 1; pushing before that would "
                         "book a false empty readback as enqueue-ok-not-consumed",
                         (unsigned long long)g_v103_tick, tnx_v115_mode(), TNX_V115_MODE_TARGET,
                         tnx_v115_inner(), tnx_v115_gate(), (unsigned long long)TNX_V113_READER_RVA,
                         (unsigned long long)TNX_V115_MODE_OFF, TNX_V115_MODE_TARGET,
                         (unsigned long long)TNX_V115_GATE_PTR_OFF, (unsigned)TNX_V115_GATE_BYTE_OFF);
            }

            if (g_v103_tick - g_v113_test_tickbase < TNX_V115_MODE_WAIT) return;

            g_v113_test_state = 4;
            g_v113_tested = 1;

            tnx_logf("v115 modewait NEVER OPENED after %d ticks mode_max=%d saw7=%d inner=%d - the gate "
                     "never opened, so the +%#llx branch, %#llx and the client pair write were never in "
                     "play and the enqueue was not attempted at all; this is reader-gated and it means "
                     "the actuator of this battle is elsewhere, not the +0xac pipeline",
                     TNX_V115_MODE_WAIT, g_v115_mode_max, g_v115_mode_seen7, tnx_v115_inner(),
                     (unsigned long long)TNX_V113_READER_RVA, (unsigned long long)0xa26890ULL);

            return;
        }

        g_v113_test_state = 1;
        g_v113_test_tick = g_v103_tick;
        g_v113_test_before_x = objects[ownIndex].x;
        g_v113_test_before_y = objects[ownIndex].y;
        g_v113_enq_x = TNX_V126_PUSH_X;
        g_v113_enq_y = TNX_V126_PUSH_Y;

        g_v126_scene_before_x = 0;
        g_v126_scene_before_y = 0;

        if (g_scene_object) {
            tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &g_v126_scene_before_x);
            tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &g_v126_scene_before_y);
        }

        g_v126_watch_from = 0;
        g_v126_watch_logs = 0;

        g_v122_pre_reloads = g_v120_reloads;
        g_v122_pre_frames = g_v48_ticks;

        tnx_v125_bounds(objects[ownIndex].object);

        g_v121_push_frame = g_v48_ticks;
        g_v121_win_stage = 0;
        g_v121_win_reloads = g_v120_reloads;

        tnx_v113_enqueue(g_v113_enq_x, g_v113_enq_y);

        g_v113_q_before = g_v126_q_before;
        g_v113_q_after = g_v126_q_after;

        tnx_logf("v126 test push=(%d,%d) type=%d alloc=%s ok=%d enqueues=%llu seq %d->%d q %d->%d qLast=%p "
                 "ownElem=(%d,%d) scene10c was=(%d,%d) - the push is a REAL displacement and no longer the "
                 "own pair, because the own pair of the walked list is (0,0) and the previous no-op read "
                 "scene+%#llx back as 0 and called it a match; ok=1 with seq after the push means the "
                 "engine ran addInput, and qLast naming msg means the queue really holds our pointer",
                 g_v113_enq_x, g_v113_enq_y, TNX_V126_TYPE_MOVE, g_v126_alloc_how, g_v126_enq_ok,
                 (unsigned long long)g_v113_enqueues, g_v126_seq_before, g_v126_seq_after,
                 g_v126_q_before, g_v126_q_after, g_v126_q_last, g_v113_test_before_x,
                 g_v113_test_before_y, g_v126_scene_before_x, g_v126_scene_before_y,
                 (unsigned long long)TNX_V112_INPUT_X_OFF);

        tnx_v113_window(0);

        return;
    }

    if (g_v113_test_state == 1) {
        int plus = (int)(g_v103_tick - g_v113_test_tick);

        if (g_v113_readback < 0 && tnx_v113_fields() == 1) {
            g_v113_readback = 1;
            g_v113_readback_tick = plus;
        }

        if (plus <= TNX_V113_WAIT_TICKS) {
            tnx_v113_window(plus);

            return;
        }

        g_v113_test_state = 2;

        if (g_v113_readback < 0) g_v113_readback = 0;

        qnow = tnx_v113_queue_count(NULL);

        tnx_logf("v113 test short before=(%d,%d) after=(%d,%d) qAfter=%d qNow=%d readback=%d atTick=%d "
                 "- readback=1 means the consumer ran on this object and the setter wrote our pair back "
                 "into the scene, readback=0 with a grown queue means the enqueue landed but the apply "
                 "path did not run for this object",
                 g_v113_test_before_x, g_v113_test_before_y, objects[ownIndex].x, objects[ownIndex].y,
                 g_v113_q_after, qnow, g_v113_readback, g_v113_readback_tick);

        return;
    }

    if (g_v103_tick - g_v113_test_tick < TNX_V113_LONG_TICKS) return;

    g_v113_test_state = 4;
    g_v113_tested = 1;

    x = objects[ownIndex].x;
    y = objects[ownIndex].y;
    g_v113_test_after_x = x;
    g_v113_test_after_y = y;
    g_v113_moved = (x != g_v113_test_before_x || y != g_v113_test_before_y) ? 1 : 0;
    g_v113_moved2 = g_v113_moved;
    g_v113_kept = (g_v113_readback == 1 && tnx_v113_fields() == 1) ? 1 : 0;

    if (tnx_v113_fields() < 0) {
        verdict = "readback-unreadable";
    } else if (g_v113_q_before >= 0 && g_v113_q_after >= 0 && g_v113_q_after <= g_v113_q_before) {
        verdict = "enqueue-failed";
    } else if (g_v113_readback == 0 && g_v115_gate_seen == 0) {
        verdict = "reader-gated";
    } else if (g_v113_readback == 0) {
        verdict = "enqueue-ok-not-consumed";
    } else if (g_v113_readback == 1 && !g_v113_kept) {
        verdict = "client-only";
    } else if (g_v113_readback == 1 && g_v113_kept) {
        verdict = "real";
    }

    tnx_logf("v115 test long before=(%d,%d) after2=(%d,%d) moved=%d kept=%d verdict=%s mode_max=%d "
             "saw7=%d gateSeen=%d gate1=%d gate2=%d qBefore=%d "
             "qAfter=%d qNow=%d readback=%d atTick=%d rowCount=%d - verdict=real means the pair survived "
             "the long check, client-only means it was read back and then reset, enqueue-ok-not-consumed "
             "means the count grew while the pair never appeared, enqueue-failed means the count never "
             "grew so addInput or the manager is wrong, readback-unreadable means the scene words could "
             "not be read at all",
             g_v113_test_before_x, g_v113_test_before_y, x, y, g_v113_moved, g_v113_kept, verdict,
             g_v115_mode_max, g_v115_mode_seen7, g_v115_gate_seen,
             (tnx_v115_mode() == TNX_V115_MODE_TARGET) ? 1 : 0, (tnx_v115_inner() == 1) ? 1 : 0,
             g_v113_q_before, g_v113_q_after, tnx_v113_queue_count(NULL), g_v113_readback,
             g_v113_readback_tick, usable);
}

static void tnx_v113_queue_line(void) {
    uintptr_t mgr = 0;
    int count = tnx_v113_queue_count(&mgr);
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (g_v103_tick % TNX_V113_QUEUE_EVERY) return;
    if (g_v113_queue_logs >= 240) return;

    g_v113_queue_logs++;

    if (g_v113_queue_logs == 1) {
        tnx_logf("v113 statics: reader branch %#llx sits in the mode update %#llx which is a per frame "
                 "update called from exactly one site %#llx as mode->update(dt, elapsed) with x0 = "
                 "[obj+0x28], so the +0xac branch is not dead code and consumed=0 can only mean the "
                 "branch gates closed on this object; the object forwarded to %#llx is the loop body at "
                 "0xac277c stored to the local [sp+0x40] and reloaded into x22 and then x25, so it is the "
                 "iterated battle entity and not a fixed offset on the scene",
                 (unsigned long long)TNX_V113_READER_RVA,
                 (unsigned long long)TNX_V113_READER_ENTRY_RVA,
                 (unsigned long long)TNX_V113_READER_CALLER_RVA,
                 (unsigned long long)0x9fe350ULL);
    }

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &inK);
    }

    tnx_logf("v115 queue tick=%llu count=%d mode=%d gate=%d mgr=%p sceneState=%d flags=%llu ac=%d "
             "in10c=%d in110=%d in114=%d resetSentinel=%d - the count is printed every tick because the "
             "verdict of this run is whether it rises after the push and falls after the consumer ran, "
             "and the reader at %#llx and addInput at %#llx have no data slot so no hook can count them; "
             "in110=-1 marks the reset path, while the apply target of the consumer is a larger object "
             "because %#x is written on it",
             (unsigned long long)g_v103_tick, count, tnx_v115_mode(), tnx_v115_gate(), (void *)mgr,
             g_v103_prev_state, (unsigned long long)g_v113_enqueues, tnx_v112_read_flag(), inX, inY, inK,
             (inY == -1) ? 1 : 0, (unsigned long long)TNX_V113_READER_RVA,
             (unsigned long long)TNX_V113_ADDINPUT_RVA, (unsigned)0x528);
}

static void tnx_v113_hop2(void) {
    void *outer = NULL;
    void *inner = NULL;
    void *list = NULL;
    void *e0 = NULL;
    void *vt0 = NULL;
    uintptr_t vt0Rva = 0;
    int32_t count = 0;

    if (!g_scene_object) return;
    if (g_v113_hop2_filled) return;

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V113_HOP2_OWNER_OFF, &outer) || !outer) return;
    if (!tnx_read_ptr((uintptr_t)outer + TNX_V113_HOP2_INNER_OFF, &inner) || !inner) return;

    g_v113_hop2 = (uintptr_t)inner;

    if (!tnx_read_ptr((uintptr_t)inner + TNX_MGR_ARRAY_OFF, &list) || !list) {
        if (g_v103_tick % 10 != 0) return;
        if (g_v103_tick > TNX_V113_HOP2_WAIT) return;
        if (g_v113_hop2_logs >= 6) return;

        g_v113_hop2_logs++;

        tnx_logf("v113 hop2 tick=%llu at=%p array=null - [[scene+%#llx]+%#llx] resolves but its list is "
                 "not filled yet, so the wait runs to %d ticks before hop1 is trusted again",
                 (unsigned long long)g_v103_tick, inner,
                 (unsigned long long)TNX_V113_HOP2_OWNER_OFF,
                 (unsigned long long)TNX_V113_HOP2_INNER_OFF, TNX_V113_HOP2_WAIT);

        return;
    }

    g_v113_hop2_filled = 1;
    tnx_read_i32((uintptr_t)inner + TNX_MGR_COUNT_OFF, &count);

    if (tnx_read_ptr((uintptr_t)list, &e0) && e0) {
        if (tnx_read_ptr((uintptr_t)e0, &vt0) && vt0) vt0Rva = (uintptr_t)vt0 - g_base;
    }

    tnx_logf("v113 hop2 FILLED tick=%llu container=%p count=%d elem0=%p elem0vt=%#llx - this is the list "
             "that carried a team split in the earlier run, so the walk should be retargeted here and "
             "[[scene+%#llx]+%#llx] kept as the hop, with hop1 only a log fallback",
             (unsigned long long)g_v103_tick, inner, count, e0, (unsigned long long)vt0Rva,
             (unsigned long long)TNX_V113_HOP2_OWNER_OFF,
             (unsigned long long)TNX_V113_HOP2_INNER_OFF);

    if (e0 && vt0Rva == TNX_V112_ELEM_VT_RVA) tnx_v112_deref_dump((uintptr_t)e0);
}

static void tnx_v103_read_mgr(void) {
    void *mgr = NULL;
    void *queue = NULL;
    int32_t count = 0;

    if (!g_scene_object) {
        g_v103_mgr = 0;
        return;
    }

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V103_INPUTMGR_OFF, &mgr) || !mgr) {
        g_v103_mgr = 0;
        return;
    }

    g_v103_mgr = (uintptr_t)mgr;

    if (!g_v105_start_logged && g_v103_prev_state == 5) {
        g_v105_start_logged = 1;

        tnx_logf("v105 battle-start scene=%p mgr=%p attempt=%d tick=%llu - logged once the scene and "
                 "the manager word are both live, because on the state edge the scene is still null",
                 (void *)g_scene_object, (void *)g_v103_mgr, g_v103_attempt,
                 (unsigned long long)g_v103_tick);
    }

    if (tnx_read_ptr((uintptr_t)mgr + TNX_V103_MGR_QUEUE_OFF, &queue) && queue) {
        tnx_read_i32((uintptr_t)queue + 0xc, &count);
    }

    if (g_v103_mgr_logs < 4) {
        g_v103_mgr_logs++;

        tnx_logf("v103 inputmgr scene=%p mgr=+%#llx->%p queue=+%#llx->%p count=+0xc->%d - the engine "
                 "loads this exact word in the battle update: bl %#llx; ldr x0,[x0,#0x58]; mov x1,msg; "
                 "bl %#llx, so this object is the first argument of the enqueue",
                 (void *)g_scene_object, (unsigned long long)TNX_V103_INPUTMGR_OFF, mgr,
                 (unsigned long long)TNX_V103_MGR_QUEUE_OFF, queue, count,
                 (unsigned long long)TNX_V103_GETBATTLE_RVA,
                 (unsigned long long)TNX_V103_ADDINPUT_RVA);
    }
}

static int tnx_v103_send(int32_t x, int32_t y) {
    if (!g_scene_object) return 0;

    if (g_v103_sp4) {
        ((void (*)(void *, int, int, int))g_v103_sp4)((void *)g_scene_object, x, y,
                                                     TNX_V103_ACTUATOR_FLAG);
        g_v103_writes++;
        g_v103_last_x = x;
        g_v103_last_y = y;

        return 1;
    }

    if (TNX_V103_USE_PRED2 && g_v103_sp2) {
        ((void (*)(void *, int, int))g_v103_sp2)((void *)g_scene_object, x, y);
        g_v103_writes++;
        g_v103_last_x = x;
        g_v103_last_y = y;

        return 1;
    }

    return 0;
}

static void tnx_v103_test(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    int32_t x = 0;
    int32_t y = 0;

    if (!TNX_V103_SEND_TEST) return;
    if (!objects || ownIndex < 0 || ownIndex >= usable) return;
    if (!g_v103_mgr) return;
    if (g_v103_test_state >= 3) return;

    if (g_v103_test_state == 0) {
        g_v103_test_state = 1;
        g_v103_test_tick = g_v103_tick;
        g_v103_test_before_x = objects[ownIndex].x;
        g_v103_test_before_y = objects[ownIndex].y;

        tnx_v103_send(objects[ownIndex].x + TNX_V103_TEST_STEP, objects[ownIndex].y);
        tnx_v112_flag_arm();

        tnx_logf("v103 inputmgr test sent=(%d,%d) from own=(%d,%d) gid=%d step=%d short=%d long=%d "
                 "writes=%llu - one test move through the four argument setter, own position is read "
                 "back twice because a client only prediction gets rolled back by the server one or "
                 "more ticks later",
                 objects[ownIndex].x + TNX_V103_TEST_STEP, objects[ownIndex].y,
                 g_v103_test_before_x, g_v103_test_before_y, objects[ownIndex].gid,
                 TNX_V103_TEST_STEP, TNX_V103_TEST_WAIT, TNX_V103_TEST_WAIT_LONG,
                 (unsigned long long)g_v103_writes);

        return;
    }

    if (g_v103_test_state == 1) {
        if (g_v103_tick - g_v103_test_tick < TNX_V103_TEST_WAIT) return;

        g_v103_test_state = 2;
        g_v103_test_after_x = objects[ownIndex].x;
        g_v103_test_after_y = objects[ownIndex].y;
        g_v103_moved = (g_v103_test_after_x != g_v103_test_before_x ||
                        g_v103_test_after_y != g_v103_test_before_y) ? 1 : 0;

        tnx_logf("v103 inputmgr test short before=(%d,%d) after=(%d,%d) moved=%d wait=%d writes=%llu",
                 g_v103_test_before_x, g_v103_test_before_y, g_v103_test_after_x,
                 g_v103_test_after_y, g_v103_moved, TNX_V103_TEST_WAIT,
                 (unsigned long long)g_v103_writes);

        return;
    }

    if (g_v103_tick - g_v103_test_tick < TNX_V103_TEST_WAIT_LONG) return;

    g_v103_test_state = 3;
    g_v103_tested = 1;

    x = objects[ownIndex].x;
    y = objects[ownIndex].y;
    g_v103_moved2 = (x != g_v103_test_before_x || y != g_v103_test_before_y) ? 1 : 0;
    g_v103_kept = (g_v103_moved && x == g_v103_test_after_x && y == g_v103_test_after_y) ? 1 : 0;
    g_v103_ok = (g_v103_moved && g_v103_kept) ? 1 : 0;

    tnx_logf("v103 inputmgr test long before=(%d,%d) after=(%d,%d) after2=(%d,%d) moved=%d moved2=%d "
             "kept=%d verdict=%s writes=%llu - kept needs the short shift to have happened and the "
             "long read to still hold it, verdict=real means the four argument setter drives the "
             "character, verdict=client-only means the shift was rolled back and the message route "
             "at rva %#llx is next, verdict=dead means this setter is not the actuator either",
             g_v103_test_before_x, g_v103_test_before_y, g_v103_test_after_x, g_v103_test_after_y,
             x, y, g_v103_moved, g_v103_moved2, g_v103_kept,
             (g_v103_moved && g_v103_kept) ? "real" : (g_v103_moved ? "client-only" : "dead"),
             (unsigned long long)g_v103_writes, (unsigned long long)TNX_V103_ADDINPUT_RVA);
}

static void tnx_v103_log(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    if (g_v103_tick % TNX_V103_LOG_EVERY) return;

    tnx_logf("v103 inputmgr: scene=%p mgr=%p test=%d writes=%llu last=(%d,%d) own=%d,%d channel=%s "
             "tick=%llu",
             (void *)g_scene_object, (void *)g_v103_mgr, g_v103_tested,
             (unsigned long long)g_v103_writes, g_v103_last_x, g_v103_last_y,
             (objects && ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].x : 0,
             (objects && ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].y : 0,
             g_v103_sp4 ? "setPredMoveTo4" : (g_v103_sp2 ? "setPred2" : "none"),
             (unsigned long long)g_v103_tick);
}

static void tnx_v103_other_containers(const tnx_v47_obj_t *objects, int usable) {
    uintptr_t others[TNX_V103_MAX_OTHERS];
    int counts[TNX_V103_MAX_OTHERS];
    int n = 0;
    int i;
    int j;

    if (!objects || usable <= 0) return;

    for (i = 0; i < usable && i < TNX_V47_OBJECT_MAX; i++) {
        void *other = NULL;
        uintptr_t obj = (uintptr_t)objects[i].object;

        if (!obj) continue;
        if (!tnx_read_ptr(obj + TNX_V103_OTHER_ELEM_OFF, &other) || !other) continue;
        if (other == (void *)g_players_object) continue;
        if (other == (void *)g_players_array) continue;

        for (j = 0; j < n; j++) {
            if (others[j] == (uintptr_t)other) break;
        }

        if (j < n) {
            counts[j]++;
            continue;
        }

        if (n < TNX_V103_MAX_OTHERS) {
            others[n] = (uintptr_t)other;
            counts[n] = 1;
            n++;
        }
    }

    if (!n) return;

    if (g_v103_other_logs < 4) {
        g_v103_other_logs++;

        for (i = 0; i < n; i++) {
            tnx_logf("v103 other container=%p elements=%d at elem+%#llx - a second list the battle "
                     "objects point at, the projectile list the dodge needs has to live here",
                     (void *)others[i], counts[i], (unsigned long long)TNX_V103_OTHER_ELEM_OFF);
        }
    }

    if (g_v103_other_detail >= TNX_V103_OTHER_DETAIL) return;

    for (i = 0; i < n; i++) {
        void *array = NULL;
        int32_t count = 0;
        int shown = 0;
        int k;

        if (!tnx_read_ptr(others[i], &array) || !array) continue;
        if (!tnx_read_i32(others[i] + 0xc, &count)) continue;
        if (count <= 0 || count > 4096) continue;

        g_v103_other_detail++;

        tnx_logf("v103 other detail container=%p array=%p count=%d - walking it with the same header "
                 "probe the container census uses",
                 (void *)others[i], array, count);

        for (k = 0; k < count && k < 64 && shown < 8; k++) {
            void *p = NULL;
            int32_t gid = 0;
            int32_t team = 0;
            int32_t px = 0;
            int32_t py = 0;

            if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)k * 8ULL, &p) || !p) continue;
            if (tnx_v75_element_ascii((uintptr_t)p)) continue;

            tnx_read_i32((uintptr_t)p + TNX_OBJ_GLOBALID_OFF, &gid);
            tnx_read_i32((uintptr_t)p + tnx_v57_coord_x_off(), &px);
            tnx_read_i32((uintptr_t)p + tnx_v57_coord_y_off(), &py);
            tnx_read_i32((uintptr_t)p + TNX_V91_TEAM_OFF, &team);

            if (!gid) continue;

            shown++;
            tnx_logf("v103 other[%d] elem=%p gid=%d pos=(%d,%d) team=%d own=%d", k, p, gid, px, py,
                     team, ((uintptr_t)p == g_v102_own_ptr) ? 1 : 0);
        }

        return;
    }
}

static void tnx_v103_state_note(int state) {
    if (g_v103_prev_state == 5 && state != 5) {
        g_v103_ok = 0;
        g_v103_tested = 0;
        g_v103_test_state = 0;
        g_v103_moved = 0;
        g_v103_moved2 = 0;
        g_v103_kept = 0;
        g_v103_test_after_x = 0;
        g_v103_test_after_y = 0;
        g_v103_mgr = 0;
        g_v103_mgr_logs = 0;
        g_v103_other_logs = 0;
        g_v103_other_detail = 0;
        g_v101_wide_runs = 0;
        g_v101_own_index = -1;
        g_v101_own_ptr = 0;
        g_v102_own_ptr = 0;
        g_v102_own_index = -1;
        g_v102_own_from = "v103-reset";

        tnx_logf("v103 chain reset reason=state-left-5 prev=%d state=%d writes=%llu tested=%d - every "
                 "pointer cached from the finished battle is dropped so the next battle resolves "
                 "scene, manager, own and the containers again from scratch",
                 g_v103_prev_state, state, (unsigned long long)g_v103_writes, g_v103_tested);
    }

    if (state == 5 && g_v103_prev_state != 5) {
        g_v103_attempt++;

        g_v105_start_logged = 0;
        g_v106_dump_done = 0;
        g_v106_coord_logs = 0;
        g_v109_done = 0;
        g_v108_owner = 0;
        g_v110_owner = 0;
        g_v110_wired = 0;
    }

    g_v103_prev_state = state;
}

static int tnx_v91_own_scan(void) {
    uintptr_t bases[TNX_V99_SCAN_BASES];
    const char *names[TNX_V99_SCAN_BASES] = { "mode", "client", "inputMgr" };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    uintptr_t client = 0;
    uintptr_t inputMgr = 0;
    void *chain = NULL;
    void *input = NULL;
    int found = 0;

    if (!g_scene_object) return 0;
    if (!array || count <= 0) return 0;

    bases[0] = g_scene_object;

    if (tnx_read_ptr(g_scene_object + TNX_MODE_MANAGER_OFF, &chain) && chain) {
        client = (uintptr_t)chain;
    }

    if (tnx_read_ptr(g_scene_object + TNX_MODE_INPUTMGR_OFF, &input) && input) {
        inputMgr = (uintptr_t)input;
    }

    bases[1] = client;
    bases[2] = inputMgr;

    tnx_v101_rva_audit();
    tnx_v101_own_index_probe();

    tnx_v102_own_probe();
    tnx_v102_audit_all();

    g_v103_tick++;
    tnx_v103_arm();
    tnx_v103_read_mgr();
    tnx_v112_flagwatch();
    tnx_v113_queue_line();

    if (!g_v101_setpred) g_v101_setpred = tnx_v101_entry(TNX_V101_MODEPAIRSET_RVA);

    if (!g_v101_setpred && g_v101_own_logs < 2) {
        tnx_logf("v101 setter candidate rva=%#llx is not an entry point on this build - the leaf "
                 "setter the audit names starts with a store and carries no frame, so its call "
                 "cannot be armed and the actuator has to go through the input manager instead",
                 (unsigned long long)TNX_V101_MODEPAIRSET_RVA);
    }

    if (g_v101_own_index < 0) tnx_v101_wide_scan();

    for (int b = 0; b < TNX_V99_SCAN_BASES; b++) {
        if (!bases[b]) continue;

        for (int i = 0; i < TNX_V99_SCAN_QWORDS; i++) {
            uintptr_t off = (uintptr_t)i * 8ULL;
            uintptr_t value = (uintptr_t)tnx_v68_word(bases[b] + off);
            uintptr_t index = 0;

            if (!value) continue;
            if (value <= array) continue;
            if (value >= array + (uintptr_t)count * 8ULL) continue;
            if ((value - array) % 8ULL) continue;

            index = (value - array) / 8ULL;

            if (!found) {
                g_v91_own_ptr = value;
                g_v91_own_index = (int)index;
                g_v91_own_src = b;
                g_v91_own_off = off;
                g_v91_own_from = names[b];
                found = 1;
            }

            if (g_v91_scan_logs < 8) {
                g_v91_scan_logs++;

                tnx_logf("v100 ownscan %s+%#llx = %p is element[%llu] of array=%p count=%d - a word "
                         "that points into the container names the local player, which is the "
                         "operation no single field of the mode performed",
                         names[b], (unsigned long long)off, (void *)value,
                         (unsigned long long)index, (void *)array, count);
            }
        }
    }

    if (!found && g_v91_scan_container != (uintptr_t)array) {
        g_v91_scan_container = (uintptr_t)array;

        tnx_logf("v100 ownscan found nothing in mode(%p)+0x00..+0x%x, client(%p)+0x00..+0x%x or "
                 "inputMgr(%p)+0x00..+0x%x that points into array=%p count=%d - none of the three "
                 "objects holds the own element, so the window is %#x on each and not the 0x300 "
                 "the v98 run covered",
                 (void *)bases[0], (unsigned)(TNX_V99_SCAN_QWORDS * 8), (void *)client,
                 (unsigned)(TNX_V99_SCAN_QWORDS * 8), (void *)inputMgr,
                 (unsigned)(TNX_V99_SCAN_QWORDS * 8), (void *)array, count,
                 (unsigned)(TNX_V99_SCAN_QWORDS * 8));
    }

    tnx_v91_scalar_dump(g_scene_object, client);

    tnx_v95_joy_dump(g_scene_object, "scene");
    tnx_v95_joy_dump(client, "client");

    if (!g_v95_find_joy_done) {
        g_v95_find_joy_done = 1;

        tnx_v95_find_joy(g_scene_object);
    }

    return found;
}

static int tnx_v91_resolve_own(const tnx_v47_obj_t *objects, int usable, int *indexOut,
                               const char **fromOut) {
    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    if (g_v101_own_index >= 0 && g_v101_own_ptr) {
        int seen = 0;
        int i;

        for (i = 0; i < usable; i++) {
            if (objects[i].object == g_v101_own_ptr) {
                seen = 1;
                break;
            }
        }

        if (seen) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = g_v101_own_from;

            return 1;
        }

        if (g_v101_miss_logs < 4) {
            g_v101_miss_logs++;

            tnx_logf("v101 own-index element %p, slot %d of %d, is not in the collected list of "
                     "%d objects - the index names an object the collector drops or reorders, so "
                     "the slot number from the container cannot be used as an index into this "
                     "list and the element has to be matched by pointer or by global id",
                     (void *)g_v101_own_ptr, g_v101_own_index, g_players_count, usable);
        }
    }

    if (g_v91_own_index >= 0 && g_v91_own_index < usable &&
        objects[g_v91_own_index].object == g_v91_own_ptr) {
        if (indexOut) *indexOut = g_v91_own_index;
        if (fromOut) *fromOut = "scan";

        return 1;
    }

    return 0;
}

static void tnx_v90_gate_report(int slotHit) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    uintptr_t manager = (uintptr_t)g_players_object;
    int rejected = 0;
    int usable = 0;
    int ownIndex = -1;
    int targetIndex = -1;
    int32_t predictX = 0;
    int32_t predictY = 0;
    int ownX = 0;
    int ownY = 0;
    int targetX = 0;
    int targetY = 0;
    int vectorX = 0;
    int vectorY = 0;
    int stepX = 0;
    int stepY = 0;
    int ownTeam = -1;
    int64_t ownBest = 0;
    int64_t targetBest = 0;
    int ownFound = 0;
    int targetFound = 0;
    int threats = 0;
    int inRange = 0;
    int distinct = 0;
    int degenerate = 0;
    int contributors = 0;
    int modeReal = 0;
    int predictZero = 0;
    int vectorZero = 0;
    uintptr_t modeVt = 0;
    uintptr_t modeChain = 0;
    uintptr_t modeInner = 0;
    const char *ownFrom = "none";
    const char *reason = "none";

    memset(objects, 0, sizeof(objects));

    g_v90_gate_calls++;

    if (g_scene_object) {
        modeReal = tnx_v91_mode_real((uintptr_t)g_scene_object, &modeVt, &modeChain, &modeInner);
    }

    tnx_v91_own_scan();

    if (!g_scene_object) {
        reason = "noScene";
    } else if (!manager || !g_players_array || g_players_count <= 0) {
        reason = "noContainer";
    } else {
        usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);
        usable = tnx_v102_inject_own(objects, usable, TNX_V47_OBJECT_MAX);

        if (usable < 2) {
            reason = "usableBelowTwo";
        } else {
            for (int i = 0; i < usable; i++) {
                int seen = 0;

                if (objects[i].x > -TNX_V75_COORD_MAX && objects[i].x < TNX_V75_COORD_MAX &&
                    objects[i].y > -TNX_V75_COORD_MAX && objects[i].y < TNX_V75_COORD_MAX) {
                    inRange++;
                }

                for (int j = 0; j < i; j++) {
                    if (objects[j].x == objects[i].x && objects[j].y == objects[i].y) {
                        seen = 1;
                        break;
                    }
                }

                if (!seen) distinct++;
            }

            degenerate = (distinct < inRange) ? 1 : 0;

            if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &predictX) ||
                !tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) {
                predictZero = 0;
            } else if (predictX == 0 && predictY == 0) {
                predictZero = 1;
            }

            ownFound = tnx_v91_resolve_own(objects, usable, &ownIndex, &ownFrom);

            if (!ownFound) ownFound = tnx_v102_take_own(objects, usable, &ownIndex, &ownFrom);

            tnx_v102_write_test(objects, usable, ownFound ? ownIndex : -1);

            tnx_v103_test(objects, usable, ownFound ? ownIndex : -1);
            tnx_v103_log(objects, usable, ownFound ? ownIndex : -1);
            tnx_v103_other_containers(objects, usable);
            tnx_v112_pos_watch(objects, usable, ownFound ? ownIndex : -1);
            tnx_v113_hop2();
            tnx_v113_test(objects, usable, ownFound ? ownIndex : -1);
            tnx_v123_hop2dump();
            tnx_v123_writes(objects, usable, ownFound ? ownIndex : -1);
            tnx_v126_chain();
            tnx_v126_watch();
        }
    }

    if (ownFound) {
        ownX = objects[ownIndex].x;
        ownY = objects[ownIndex].y;
        ownTeam = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                           : objects[ownIndex].teamNew;

        for (int i = 0; i < usable; i++) {
            int team = 0;
            int64_t edx = 0;
            int64_t edy = 0;
            int64_t ed = 0;

            if (i == ownIndex) continue;
            if (TNX_V93_DEAD_FILTER && objects[i].dead) continue;

            team = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                            : objects[i].teamNew;
            if (team == ownTeam) continue;

            edx = (int64_t)objects[i].x - (int64_t)ownX;
            edy = (int64_t)objects[i].y - (int64_t)ownY;
            ed = edx * edx + edy * edy;
            threats++;

            if (!targetFound || ed < targetBest) {
                targetFound = 1;
                targetBest = ed;
                targetIndex = i;
            }
        }

        if (targetFound) {
            float escapeX = 0.0f;
            float escapeY = 0.0f;

            targetX = objects[targetIndex].x;
            targetY = objects[targetIndex].y;
            vectorX = targetX - ownX;
            vectorY = targetY - ownY;

            for (int i = 0; i < usable; i++) {
                int team = 0;
                float fdx = 0.0f;
                float fdy = 0.0f;
                float fd = 0.0f;

                if (i == ownIndex) continue;
                if (TNX_V93_DEAD_FILTER && objects[i].dead) continue;

                team = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                                : objects[i].teamNew;
                if (team == ownTeam) continue;
                if ((objects[i].activeFlag & 1) == 0) continue;

                fdx = (float)(ownX - objects[i].x);
                fdy = (float)(ownY - objects[i].y);
                fd = fdx * fdx + fdy * fdy;

                if (fd > DODGE_RANGE_SQ || fd < 1.0f) continue;

                escapeX += fdx / (sqrtf(fd) + 1.0f);
                escapeY += fdy / (sqrtf(fd) + 1.0f);
                contributors++;
            }

            if (contributors > 0) {
                float length = sqrtf(escapeX * escapeX + escapeY * escapeY);

                if (length <= 0.0001f) {
                    vectorZero = 1;
                } else {
                    escapeX /= length;
                    escapeY /= length;

                    stepX = ownX + (int)(escapeX * DODGE_STEP);
                    stepY = ownY + (int)(escapeY * DODGE_STEP);
                }
            }
        }
    }

    if (strcmp(reason, "none") == 0 && !g_v103_mgr) {
        reason = "noInputMgr";
    } else if (strcmp(reason, "none") == 0 && !ownFound) {
        reason = "noOwn";
    } else if (strcmp(reason, "none") == 0 && !g_v103_tested) {
        reason = "actuatorNotTested";
    } else if (strcmp(reason, "none") == 0 && !targetFound) {
        reason = "noTarget";
    } else if (strcmp(reason, "none") == 0 && !modeReal) {
        reason = "modeGuard";
    } else if (strcmp(reason, "none") == 0 && !g_v47_coord_ok) {
        reason = "noCoords";
    } else if (strcmp(reason, "none") == 0 && !g_v47_setpred_state) {
        reason = "noActuator";
    } else if (strcmp(reason, "none") == 0 && predictZero) {
        reason = "predictionZero";
    } else if (strcmp(reason, "none") == 0 && contributors <= 0) {
        reason = "noThreat";
    } else if (strcmp(reason, "none") == 0 && vectorZero) {
        reason = "degenerateVector";
    } else if (strcmp(reason, "none") == 0) {
        reason = "ready";
    }

    tnx_logf("v100 dodge gates: ownFound=%d own=%p ownFrom=%s ownOff=%#llx ownTeam=%d "
             "targetFound=%d target=%p selfPos=(%d,%d) targetPos=(%d,%d) vector=(%d,%d) "
             "clamped=(%d,%d) actuatorReached=%d reason=%s usable=%d rejected=%d threats=%d "
             "contributors=%d inRange=%d distinct=%d degenerate=%d slotHit=%d hop=%d "
             "modeReal=%d modeVt=%#llx modeChain=%p modeInner=%p deadF=%d teamOff=%#llx "
             "testWrites=%llu writes=%llu - the reason is assigned in the order own, target, "
             "guard, coords, actuator, prediction, so a writes=0 names the first gate that is "
             "closed instead of reporting the last one, and deadF tells whether the dead filter is "
             "applied at all",
             ownFound, (void *)(ownFound ? objects[ownIndex].object : 0), ownFrom,
             (unsigned long long)g_v91_own_off, ownTeam, targetFound,
             (void *)(targetFound ? objects[targetIndex].object : 0), ownX, ownY, targetX, targetY,
             vectorX, vectorY, stepX, stepY, g_v47_setpred_state == 1 ? 1 : 0, reason, usable,
             rejected, threats, contributors, inRange, distinct, degenerate, slotHit,
             g_v82_hop_chosen, modeReal, (unsigned long long)modeVt, (void *)modeChain,
             (void *)modeInner, TNX_V93_DEAD_FILTER, (unsigned long long)g_v47_team_off,
             (unsigned long long)g_v93_test_writes, (unsigned long long)g_v47_writes);
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

    sourceIsMode = (g_scene_object != 0);

    if (sourceIsMode) {
        source = g_scene_object;
        sourceKind = "mode";
    } else if (g_players_object) {
        source = g_players_object;
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

            tnx_logf("v100 route: five passes with no source at all - mode=%p manager=%p "
                     "objvote=%p trailBest=%p; the remaining path is the ClientInput route, and its "
                     "hooks report separately (E5 setClientPredictionMoveTo, E6 sendMovement)",
                     (void *)g_scene_object, (void *)g_players_object, (void *)g_objvote_best_owner,
                     (void *)((g_trail_best >= 0 && g_trail_best < g_trail_count)
                                  ? g_trail[g_trail_best].manager
                                  : 0));
        }
    } else {
        g_v54_no_source_passes = 0;
    }

    if (!sourceIsMode && !g_players_object && source && strcmp(sourceKind, "trail") == 0 &&
        g_trail_best >= 0 && g_trail_best < g_trail_count && g_trail[g_trail_best].live == 0) {
        if ((g_v48_ticks % 900) == 1) {
            tnx_logf("v100 dodge idle ticks=%llu: best trail candidate has live=0, waiting "
                     "(trailBest=%p nonEmpty=%d count=%d stable=%d)",
                     (unsigned long long)g_v48_ticks, (void *)source,
                     g_trail[g_trail_best].nonEmpty, g_trail[g_trail_best].count,
                     g_trail[g_trail_best].stable);
        }
    }

    tnx_v113_frame_window();
    tnx_v116_frame();

    g_v48_ticks++;

    if (g_v92_wrote_valid && !g_v92_check_done &&
        (g_v48_ticks - g_v92_wrote_tick) >= TNX_V92_VERIFY_FRAMES) {
        int32_t nowX = 0;
        int32_t nowY = 0;

        if (g_scene_object && tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &nowX) &&
            tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &nowY)) {
            tnx_logf("v100 write verify: wrote=(%d,%d) now=(%d,%d) %s frames=%d testWrites=%llu - "
                     "kept means the engine left the two words alone, overwritten means the input "
                     "path rewrites them before anything is sent",
                     g_v92_wrote_x, g_v92_wrote_y, nowX, nowY,
                     (nowX == g_v92_wrote_x && nowY == g_v92_wrote_y) ? "kept" : "overwritten",
                     (int)(g_v48_ticks - g_v92_wrote_tick),
                     (unsigned long long)g_v93_test_writes);

            {
                void *array = NULL;
                int32_t count = 0;
                int shown = 0;

                if (g_players_object &&
                    tnx_read_ptr(g_players_object + TNX_MGR_ARRAY_OFF, &array) && array &&
                    tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &count)) {
                    for (int32_t i = 0; i < count && shown < TNX_V93_POS_DUMPS; i++) {
                        void *element = NULL;
                        int32_t px = 0;
                        int32_t py = 0;

                        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element)) break;
                        if (!element) continue;

                        tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px);
                        tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py);

                        shown++;

                        tnx_logf("v100 verify pos elem[%d] %p pos=(%d,%d)", i, element, px, py);
                    }
                }
            }
        }

        g_v92_check_done = 1;
    }

    if (g_v89_enter_tick != g_v50_ticks && (g_v50_ticks < 5 || (g_v50_ticks % 5) == 0)) {
        g_v89_enter_tick = g_v50_ticks;
        g_v48_entry_logs++;

        {
            int32_t oix = 0;
            int32_t oiy = 0;

            tnx_v116_interp(&oix, &oiy);

            tnx_logf("v116 dodge ENTERED tick=%llu frames=%llu mode=%p manager=%p hop=%d source=%p "
                     "kind=%s setpredFn=%d coordOk=%d usable=%d writes=%llu ownInterpX=%d ownInterpY=%d "
                     "modeVar=%d gate1=%d gate2=%d - ownInterpX/Y is the live own position read from "
                     "client+%#llx/+%#llx, so a dodge line with coordOk=0 can still carry a moving own "
                     "position",
                     (unsigned long long)g_v50_ticks, (unsigned long long)g_v48_ticks,
                     (void *)g_scene_object, (void *)g_players_object, g_v82_hop_chosen, (void *)source,
                     sourceKind, g_v47_setpred_state, g_v47_coord_ok, g_v47_coord_usable,
                     (unsigned long long)g_v47_writes, oix, oiy, tnx_v115_mode(),
                     (tnx_v115_mode() == TNX_V115_MODE_TARGET) ? 1 : 0, (tnx_v115_inner() == 1) ? 1 : 0,
                     (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
                     (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);
        }

        tnx_v116_interp_line();
        tnx_v116_hist_line();
        tnx_v119_elements();
        tnx_v119_pin();
        tnx_v120_holder_note();
        tnx_v120_entities();
        tnx_v121_traj();
        tnx_v122_entities2();
        tnx_v90_gate_report(tnx_v90_slot_probe());
    }

    if (TNX_V93_TEST_WRITE && g_v47_setpred_state == 1 && g_scene_object && g_players_object) {
        int32_t cnt = 0;

        tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &cnt);

        if (cnt >= 2 && g_v93_test_tick != g_v50_ticks) {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;
            uintptr_t thisInner = 0;

            if (tnx_v91_mode_real((uintptr_t)g_scene_object, &thisVt, &thisChain, &thisInner)) {
                g_v93_test_tick = g_v50_ticks;
                g_v93_test_writes++;

                ((tnx_v47_setpred_t)g_v47_setpred)((void *)g_scene_object, TNX_V93_TEST_X,
                                                   TNX_V93_TEST_Y);

                g_v92_wrote_x = TNX_V93_TEST_X;
                g_v92_wrote_y = TNX_V93_TEST_Y;
                g_v92_own_pos_x = 0;
                g_v92_own_pos_y = 0;
                g_v92_wrote_tick = g_v48_ticks;
                g_v92_wrote_valid = 1;
                g_v92_check_done = 0;

                tnx_logf("v100 test write #%llu this=%p vt=%#llx chain=%p inner=%p container=%p "
                         "count=%d target=(%d,%d) - written without an own element, because the "
                         "question this run must answer is whether the actuator moves anything at "
                         "all", (unsigned long long)g_v93_test_writes, (void *)g_scene_object,
                         (unsigned long long)thisVt, (void *)thisChain, (void *)thisInner,
                         (void *)g_players_object, cnt, TNX_V93_TEST_X, TNX_V93_TEST_Y);

                return;
            }
        }
    }

    if (!source) {
        if ((g_v48_ticks % 900) == 1) {
            tnx_logf("v100 dodge idle ticks=%llu: no mode, no manager and no trail candidate yet "
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
        void *resolved = NULL;
        int changed = (g_v47_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;

        if (sourceIsMode && g_v82_hop_chosen == 1 && g_players_object) {
            resolved = (void *)g_players_object;
        } else if (sourceIsMode) {
            if (!tnx_read_ptr(source + TNX_MODE_MANAGER_OFF, &resolved) || !resolved) {
                resolved = NULL;
            }
        } else {
            resolved = (void *)source;
        }

        managerChanged = ((uintptr_t)resolved != g_v48_manager);

        if (managerChanged && g_v88_walk_relogs < 6) {
            g_v88_walk_relogs++;

            tnx_logf("v100 walk manager=%p hop=%d source=%p kind=%s - the container is re-read from "
                     "the chain globals on this tick, so the walk follows scene+0x28 -> +%#llx "
                     "instead of stopping on the client", resolved, g_v82_hop_chosen,
                     (void *)source, sourceKind, (unsigned long long)TNX_V82_CLIENT_HOP_OFF);
        }

        {
            int32_t liveCount = 0;

            if (resolved) tnx_read_i32((uintptr_t)resolved + TNX_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && g_v82_hop_chosen == 1 &&
                (liveCount != g_v89_walk_count ||
                 (g_v89_walk_tick != g_v50_ticks && (g_v50_ticks % TNX_V89_WALK_EVERY) == 0))) {
                g_v89_walk_count = liveCount;
                g_v89_walk_tick = g_v50_ticks;
                periodic = 1;

                tnx_logf("v100 walk tick=%llu manager=%p count=%d - the walk is driven by the tick "
                         "and by the count, not by the array, so it reports every %d ticks while "
                         "the hop is %d even when the container itself has not changed",
                         (unsigned long long)g_v50_ticks, resolved, liveCount, TNX_V89_WALK_EVERY,
                         g_v82_hop_chosen);
            }
        }

        if (!g_v47_probe_done || changed || managerChanged || periodic ||
            (!g_v47_coord_ok && probeNow > g_v47_probe_last_ms + TNX_V47_REPROBE_MS)) {
            g_v47_probe_object = source;
            g_v47_probe_last_ms = probeNow;
            g_v48_manager = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || managerChanged || !g_v47_probe_done);

                tnx_v48_probe((uintptr_t)resolved, g_scene_object, loud);

                if (loud) tnx_v48_discriminate((uintptr_t)resolved);
            } else {
                tnx_logf("v100 probe skipped: source %p (%s) has no manager at +0x%llx and hop=%d",
                         (void *)source, sourceIsMode ? "mode" : "manager",
                         (unsigned long long)TNX_MODE_MANAGER_OFF, g_v82_hop_chosen);
            }
        }
    }

    g_v47_ticks++;

    if (!g_v47_setpred_state) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v100 dodge idle: no verified actuator (fingerprint state=%d -- this is the "
                     "byte check of the function, not a write)", g_v47_setpred_state);
        }
        return;
    }

    if (!g_v47_coord_ok) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v100 dodge idle: coordinates not confirmed (usable=%d distinct=%d) -- "
                     "read-only until they are", g_v47_coord_usable, g_v47_coord_distinct);
        }
        return;
    }

    if (!g_scene_object) {
        if (g_v47_giveup_logs < 9) {
            g_v47_giveup_logs++;
            tnx_logf("v100 dodge idle: coordinates confirmed but the mode is unknown, so the "
                     "actuator has no `this` -- nothing written");

            if (!g_v59_idle_probe_logged) {
                g_v59_idle_probe_logged = 1;

                tnx_logf("v100 dodge idle probe modeCandidate=%p vt=%#llx whyRejected=%s hits=%d "
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

    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    tnx_v91_own_scan();

    {
        const char *ownFrom = "none";

        if (!tnx_v91_resolve_own(objects, usable, &ownIndex, &ownFrom)) {
            if (g_v47_giveup_logs < 6) {
                g_v47_giveup_logs++;

                tnx_logf("v100 dodge idle: no own element - the scan found nothing at scanIndex=%d "
                         "scanPtr=%p and the prediction fallback (%d,%d) found nothing either, "
                         "usable=%d", g_v91_own_index, (void *)g_v91_own_ptr, predictX, predictY,
                         usable);
            }

            return;
        }

        if (!g_v91_own_logged) {
            g_v91_own_logged = 1;

            tnx_logf("v100 dodge own resolved from %s at +%#llx index=%d object=%p pos=(%d,%d) - "
                     "the scan is tried first and the prediction pair is only the fallback, so "
                     "the dodge and the gate line name the same element", ownFrom,
                     (unsigned long long)g_v91_own_off, ownIndex, objects[ownIndex].object,
                     objects[ownIndex].x, objects[ownIndex].y);
        }
    }

    if (TNX_V93_DEAD_FILTER && objects[ownIndex].dead) return;

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
        if (TNX_V93_DEAD_FILTER && objects[i].dead) continue;

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
            tnx_logf("v100 live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
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
            uintptr_t thisInner = 0;

            if (!tnx_v91_mode_real((uintptr_t)g_scene_object, &thisVt, &thisChain, &thisInner)) {
                if (g_v50_setpred_blocked_logs < 6) {
                    g_v50_setpred_blocked_logs++;

                    tnx_logf("v100 setprediction BLOCKED: this=%p vt=%#llx [this+%#llx]=%p "
                             "[chain+%#llx]=%p container=%p -- the chain does not reach the walked "
                             "container, nothing written", (void *)g_scene_object,
                             (unsigned long long)thisVt, (unsigned long long)TNX_MODE_MANAGER_OFF,
                             (void *)thisChain, (unsigned long long)TNX_V82_CLIENT_HOP_OFF,
                             (void *)thisInner, (void *)g_players_object);
                }

                return;
            }

            if (g_v47_writes == 0) {
                tnx_logf("v100 setprediction about to write: this=%p vt=%#llx chain=%p manager=%p "
                         "target=(%d,%d)", (void *)g_scene_object, (unsigned long long)thisVt,
                         (void *)thisChain, (void *)g_v48_manager, targetX, targetY);
            }
        }

        ((tnx_v47_setpred_t)g_v47_setpred)((void *)g_scene_object, targetX, targetY);

        g_v47_writes++;

        g_v92_wrote_x = targetX;
        g_v92_wrote_y = targetY;
        g_v92_own_pos_x = ownX;
        g_v92_own_pos_y = ownY;
        g_v92_wrote_tick = g_v48_ticks;
        g_v92_wrote_valid = 1;
        g_v92_check_done = 0;

        if (g_v47_writes <= TNX_V47_LOG_FIRST || (g_v47_writes % TNX_V47_LOG_EVERY) == 0) {
            tnx_logf("v100 write #%llu own=(%d,%d) team=%d hostilesAlive=%d enemiesInRange=%d "
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

static int tnx_v73_inst_is_manager(uintptr_t value, uintptr_t *arrayOut, int32_t *countOut) {
    void *array = NULL;
    int32_t count = 0;

    if (!value) return 0;
    if (!tnx_manager_shape(value)) return 0;
    if (!tnx_read_ptr(value + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(value + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;

    if (arrayOut) *arrayOut = (uintptr_t)array;
    if (countOut) *countOut = count;

    return 1;
}

static void tnx_v73_inst_report(int index, const char *which, uintptr_t value) {
    uintptr_t array = 0;
    void *vtable = NULL;
    void *manager = NULL;
    int32_t count = 0;
    int isManager = 0;
    int isMode = 0;

    if (!value) return;

    isManager = tnx_v73_inst_is_manager(value, &array, &count);

    if (tnx_read_ptr(value, &vtable) && vtable && tnx_v56_vtable_in_image((uintptr_t)vtable) &&
        tnx_read_ptr(value + TNX_MODE_MANAGER_OFF, &manager) && manager &&
        tnx_v73_inst_is_manager((uintptr_t)manager, NULL, NULL)) {
        isMode = 1;

        if (tnx_v73_inst_is_manager((uintptr_t)manager, &array, &count)) isManager = 1;
    }

    if (!isManager && !isMode) return;

    g_v73_inst_positive++;

    tnx_logf("v100 inst %s %s=%p seg=%c isManager=%d isMode=%d vt=%p mgr=%p array=%p count=%d "
             "live=%d - a hooked engine instance is itself a container",
             g_slot_specs[index].shortTag, which, (void *)value, tnx_v72_seg_code(value), isManager,
             isMode, vtable, manager, (void *)array, count,
             tnx_manager_live_count(isMode ? (uintptr_t)manager : value));
}

static void tnx_v73_instance_probe(int index, void *self, uint64_t arg1) {
    uint32_t bit = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    bit = (uint32_t)(1u << (unsigned)index);
    if (g_v73_inst_mask & bit) return;

    g_v73_inst_mask |= bit;
    g_v73_inst_slots++;

    tnx_v73_inst_report(index, "this", (uintptr_t)self);
    tnx_v73_inst_report(index, "arg1", (uintptr_t)arg1);

    if (!g_v73_inst_summary && (g_v73_inst_slots >= TNX_V73_INST_SLOTS || g_v50_ticks >= 30)) {
        g_v73_inst_summary = 1;

        tnx_logf("v100 instprobe done: slots=%d positive=%d - a positive means the hook handed us a "
                 "mode or a container directly; zero means neither this nor arg1 of any hot slot "
                 "is one, so the container must keep being found by scan", g_v73_inst_slots,
                 g_v73_inst_positive);
    }
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

static uint64_t tnx_v68_word(uintptr_t address) {
    uint64_t value = 0;

    if (!tnx_read_bytes(address, &value, sizeof(value))) return 0;

    return value;
}

static int tnx_v71_manager_head_ok(uintptr_t owner) {
    uintptr_t head = 0;

    if (!owner) return 0;

    head = (uintptr_t)tnx_v68_word(owner + TNX_MGR_ARRAY_OFF);

    if (!head) {
        g_v71_head_rejected++;

        return 0;
    }

    if (tnx_in_image_span(head)) {
        g_v71_head_rejected++;

        return 0;
    }

    if (!tnx_heap_contains(head) && !tnx_heap_window_shaped(head)) {
        g_v71_head_rejected++;

        return 0;
    }

    g_v71_head_ok++;

    return 1;
}

static int tnx_v71_array_probe(uintptr_t array, int32_t count, char *why, size_t whyLen) {
    int probe = 0;
    int valid = 0;

    if (!array) {
        if (why) snprintf(why, whyLen, "array-null");

        return 0;
    }

    if (tnx_in_image_span(array) || (!tnx_heap_contains(array) && !tnx_heap_window_shaped(array))) {
        if (why) snprintf(why, whyLen, "head-not-heap=%p", (void *)array);

        return 0;
    }

    probe = count < TNX_V71_ARRAY_PROBE ? count : TNX_V71_ARRAY_PROBE;

    for (int i = 0; i < probe; i++) {
        void *element = NULL;
        void *vtable = NULL;
        int32_t team = 0;

        if (!tnx_read_ptr(array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_heap_contains((uintptr_t)element)) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable) || !vtable) continue;
        if (!tnx_v56_vtable_in_image((uintptr_t)vtable)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team)) continue;
        if (team < 0 || team > TNX_OBJ_TEAM_MAX) continue;

        valid++;
    }

    if (valid < TNX_V71_ARRAY_MIN_OBJS) {
        if (why) snprintf(why, whyLen, "elements=%d-of-%d", valid, probe);

        return 0;
    }

    return valid;
}

static void tnx_v71_modewindow_dump(uintptr_t mode) {
    void *before = NULL;
    void *tableHead = NULL;

    if (!mode) return;
    if (g_v71_modewindow_logs >= 2) return;

    g_v71_modewindow_logs++;

    tnx_logf("v100 modewindow mode=%p m-10=%#llx m-08=%#llx m-00=%#llx m+08=%#llx src=SIG",
             (void *)mode, (unsigned long long)tnx_v68_word(mode - 0x10ULL),
             (unsigned long long)tnx_v68_word(mode - 0x8ULL),
             (unsigned long long)tnx_v68_word(mode),
             (unsigned long long)tnx_v68_word(mode + 0x8ULL));

    tnx_logf("v100 modewindow mode=%p m+10=%#llx m+18=%#llx m+20=%#llx m+28=%#llx src=SIG",
             (void *)mode, (unsigned long long)tnx_v68_word(mode + 0x10ULL),
             (unsigned long long)tnx_v68_word(mode + 0x18ULL),
             (unsigned long long)tnx_v68_word(mode + 0x20ULL),
             (unsigned long long)tnx_v68_word(mode + 0x28ULL));

    tnx_logf("v100 modewindow mode=%p m+30=%#llx m+38=%#llx m+40=%#llx m+48=%#llx src=SIG",
             (void *)mode, (unsigned long long)tnx_v68_word(mode + 0x30ULL),
             (unsigned long long)tnx_v68_word(mode + 0x38ULL),
             (unsigned long long)tnx_v68_word(mode + 0x40ULL),
             (unsigned long long)tnx_v68_word(mode + 0x48ULL));

    tnx_read_ptr(mode - 0x8ULL, &before);

    if (!before) {
        tnx_logf("v100 classtable mode=%p m-08=null src=SIG", (void *)mode);

        return;
    }

    if (!tnx_v56_vtable_in_image((uintptr_t)before)) {
        tnx_logf("v100 classtable mode=%p m-08=%p not-in-image src=SIG", (void *)mode, before);

        return;
    }

    if (!tnx_read_ptr((uintptr_t)before, &tableHead) || !tableHead) {
        tnx_logf("v100 classtable mode=%p m-08=%p vt0=null src=SIG", (void *)mode, before);

        return;
    }

    {
        uintptr_t tableRva = (uintptr_t)tableHead > g_base ? (uintptr_t)tableHead - g_base : 0;

        tnx_logf("v100 classtable mode=%p m-08=%p vt0=%p vt0InImage=%d vt0rva=%#llx src=SIG",
                 (void *)mode, before, tableHead,
                 (int)tnx_v56_vtable_in_image((uintptr_t)tableHead), (unsigned long long)tableRva);
    }
}

static void tnx_v71_owner_chain_dump(uintptr_t container) {
    void *array = NULL;
    int32_t count = 0;
    int probe = 0;
    int heapOwners = 0;
    int notHeap = 0;
    int backs = 0;

    if (!container) return;
    if (g_v71_ownerchain_logs >= 4) return;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count)) return;

    probe = count < TNX_V72_OWNERCHAIN_PROBE ? count : TNX_V72_OWNERCHAIN_PROBE;
    if (probe <= 0) return;

    g_v71_ownerchain_logs++;

    tnx_logf("v100 ownerchain container=%p array=%p seg=%c count=%d probe=%d src=B",
             (void *)container, array, tnx_v72_seg_code((uintptr_t)array), count, probe);

    for (int i = 0; i < probe; i++) {
        void *object = NULL;
        uintptr_t owner = 0;
        uintptr_t own0 = 0;
        uintptr_t own28 = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &object) || !object) continue;

        owner = (uintptr_t)tnx_v68_word((uintptr_t)object + TNX_SLOT_OWNER_OFF);

        if (!tnx_heap_contains(owner)) {
            notHeap++;

            tnx_logf("v100 ownerchain obj=%p owner=%p not-heap seg=%c src=B", object, (void *)owner,
                     tnx_v72_seg_code(owner));

            continue;
        }

        heapOwners++;

        own0 = (uintptr_t)tnx_v68_word(owner);
        own28 = (uintptr_t)tnx_v68_word(owner + TNX_MODE_MANAGER_OFF);

        if (own28 == container || own0 == container) backs++;

        tnx_logf("v100 ownerchain obj=%p owner=%p owner+00=%#llx owner+28=%#llx back=%d src=B",
                 object, (void *)owner, (unsigned long long)own0, (unsigned long long)own28,
                 (own28 == container || own0 == container) ? 1 : 0);
    }

    tnx_logf("v100 ownerchain summary probe=%d heapOwners=%d notHeap=%d back=%d of count=%d - a "
             "real owner element is the one whose owner+00 or owner+28 names the container",
             probe, heapOwners, notHeap, backs, count);
}

static void tnx_v71_owner_team_dump(uintptr_t owner, uint32_t teamMask, int teamCount) {
    void *array = NULL;
    int32_t count = 0;
    int t0 = 0;
    int t1 = 0;
    int t2 = 0;
    int t3 = 0;
    int other = 0;
    int seen = 0;

    if (!owner || teamCount < 1) return;
    if (g_v71_teamhist_logs >= 6) return;
    if (!tnx_read_ptr(owner + TNX_MGR_ARRAY_OFF, &array) || !array) return;

    tnx_read_i32(owner + TNX_MGR_COUNT_OFF, &count);
    if (count > 32) count = 32;

    for (int i = 0; i < count; i++) {
        void *element = NULL;
        int32_t team = -1;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team)) continue;

        seen++;

        if (team == 0) t0++;
        else if (team == 1) t1++;
        else if (team == 2) t2++;
        else if (team == 3) t3++;
        else other++;
    }

    g_v71_teamhist_logs++;

    tnx_logf("v100 teamHist owner=%p teamCount=%d teams=%#x n=%d t0=%d t1=%d t2=%d t3=%d other=%d "
             "src=B", (void *)owner, teamCount, teamMask, seen, t0, t1, t2, t3, other);
}

static int tnx_v68_container_gate(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                  int32_t *capOut, char *why, size_t whyLen) {
    uintptr_t array = 0;
    int32_t w8 = 0;
    int32_t wc = 0;
    int32_t w10 = 0;
    int32_t count = 0;
    int32_t capacity = 0;
    char probe[96] = { 0 };

    if (containerOut) *containerOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (why && whyLen) why[0] = 0;

    if (!manager) {
        if (why) snprintf(why, whyLen, "no-manager");

        return 0;
    }

    if (g_v68_probe_logs < 8) {
        g_v68_probe_logs++;

        tnx_read_i32(manager + TNX_MGR_CAP_OFF, &w8);
        tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &wc);
        tnx_read_i32(manager + 0x10ULL, &w10);

        tnx_logf("v100 gate touch mgr=%p cap+%#x=%d count+%#x=%d +0x10=%d src=B", (void *)manager,
                 (unsigned)TNX_MGR_CAP_OFF, w8, (unsigned)TNX_MGR_COUNT_OFF, wc, w10);
    }

    if (!tnx_v82_container_header(manager, &array, &count, &capacity, why, whyLen)) return 0;

    if (!tnx_v71_array_probe(array, count, probe, sizeof(probe)) && g_v71_array_reject_logs < 8) {
        g_v71_array_reject_logs++;

        tnx_logf("v100 gate probe disagrees mgr=%p array=%p count=%d probe=%s src=B - this gate now "
                 "runs the header test the hop test runs, so a probe verdict is recorded and not "
                 "obeyed", (void *)manager, (void *)array, count, probe[0] ? probe : "unknown");
    }

    if (containerOut) *containerOut = manager;
    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    if (g_v68_gate_logs < 12) {
        g_v68_gate_logs++;

        tnx_read_i32(manager + TNX_MGR_CAP_OFF, &w8);
        tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &wc);

        tnx_logf("v100 gate mgr=%p array=%p count=%d cap=%d cap+%#x=%d count+%#x=%d -> accept src=B",
                 (void *)manager, (void *)array, count, capacity, (unsigned)TNX_MGR_CAP_OFF, w8,
                 (unsigned)TNX_MGR_COUNT_OFF, wc);
    }

    return 1;
}

static void tnx_v68_pending_push(uintptr_t owner, const char *why) {
    if (!owner) return;

    for (int i = 0; i < g_v68_pending_count; i++) {
        if (g_v68_pending[i] == owner) {
            g_v68_pending_tick[i] = (int)g_v50_ticks;

            return;
        }
    }

    if (g_v68_pending_count >= TNX_V68_PENDING_MAX) return;

    g_v68_pending_tick[g_v68_pending_count] = (int)g_v50_ticks;
    g_v71_pending_attempts[g_v68_pending_count] = 0;
    g_v68_pending[g_v68_pending_count++] = owner;
    g_v71_pending_pushed++;

    tnx_logf("v100 pending push owner=%p reason=%s size=%d src=B", (void *)owner,
             why ? why : "-", g_v68_pending_count);
}

static void tnx_v68_multiteam_dump(uintptr_t owner, uint32_t teamMask, int teamCount) {
    void *array = NULL;
    int32_t count = 0;
    int t0 = 0;
    int t1 = 0;
    int t2 = 0;
    int t3 = 0;
    int other = 0;
    int seen = 0;

    if (g_v68_dump_logs >= 4) return;
    if (teamCount < TNX_OWNER_VOTE_TEAMS_MIN) return;

    g_v68_dump_logs++;

    tnx_logf("v100 multiteam owner=%p teams=%#x teamCount=%d src=B", (void *)owner, teamMask,
             teamCount);

    tnx_logf("v100 dump owner=%p +00=%#llx +08=%#llx +10=%#llx +18=%#llx src=B", (void *)owner,
             (unsigned long long)tnx_v68_word(owner + 0x0ULL),
             (unsigned long long)tnx_v68_word(owner + 0x8ULL),
             (unsigned long long)tnx_v68_word(owner + 0x10ULL),
             (unsigned long long)tnx_v68_word(owner + 0x18ULL));

    tnx_logf("v100 dump owner=%p +20=%#llx +28=%#llx +30=%#llx +38=%#llx src=B", (void *)owner,
             (unsigned long long)tnx_v68_word(owner + 0x20ULL),
             (unsigned long long)tnx_v68_word(owner + 0x28ULL),
             (unsigned long long)tnx_v68_word(owner + 0x30ULL),
             (unsigned long long)tnx_v68_word(owner + 0x38ULL));

    tnx_logf("v100 dump owner=%p +40=%#llx +48=%#llx +50=%#llx +58=%#llx src=B", (void *)owner,
             (unsigned long long)tnx_v68_word(owner + 0x40ULL),
             (unsigned long long)tnx_v68_word(owner + 0x48ULL),
             (unsigned long long)tnx_v68_word(owner + 0x50ULL),
             (unsigned long long)tnx_v68_word(owner + 0x58ULL));

    tnx_logf("v100 dump owner=%p +60=%#llx +68=%#llx +70=%#llx +78=%#llx src=B", (void *)owner,
             (unsigned long long)tnx_v68_word(owner + 0x60ULL),
             (unsigned long long)tnx_v68_word(owner + 0x68ULL),
             (unsigned long long)tnx_v68_word(owner + 0x70ULL),
             (unsigned long long)tnx_v68_word(owner + 0x78ULL));

    {
        uintptr_t head = (uintptr_t)tnx_v68_word(owner + TNX_MGR_ARRAY_OFF);
        uintptr_t word20 = (uintptr_t)tnx_v68_word(owner + TNX_SLOT_OWNER_OFF);

        tnx_logf("v100 head owner=%p head=%#llx headImg=%d headHeap=%d headWin=%d +20=%#llx "
                 "+20Heap=%d src=B", (void *)owner, (unsigned long long)head,
                 (int)tnx_in_image_span(head), (int)tnx_heap_contains(head),
                 (int)tnx_heap_window_shaped(head), (unsigned long long)word20,
                 (int)tnx_heap_contains(word20));
    }

    if (!tnx_read_ptr(owner + TNX_MGR_ARRAY_OFF, &array) || !array) return;

    tnx_read_i32(owner + TNX_MGR_COUNT_OFF, &count);
    if (count > 32) count = 32;

    for (int i = 0; i < count; i++) {
        void *element = NULL;
        int32_t team = -1;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team)) continue;

        seen++;

        if (team == 0) t0++;
        else if (team == 1) t1++;
        else if (team == 2) t2++;
        else if (team == 3) t3++;
        else other++;
    }

    tnx_logf("v100 teamHist owner=%p n=%d t0=%d t1=%d t2=%d t3=%d other=%d src=B", (void *)owner,
             seen, t0, t1, t2, t3, other);
}

static void tnx_v68_pending_tick(void) {
    if (!g_v71_pending_seen) {
        g_v71_pending_seen = 1;

        tnx_logf("v100 pending wired q=%d pushed=%llu evicted=%d src=B", g_v68_pending_count,
                 g_v71_pending_pushed, g_v71_pending_evicted);
    }

    if (g_players_object || g_objvote_owner_ok) return;

    if (g_v71_pending_q_log != g_v68_pending_count) {
        g_v71_pending_q_log = g_v68_pending_count;

        tnx_logf("v100 pending q=%d pushed=%llu evicted=%d src=B", g_v68_pending_count,
                 g_v71_pending_pushed, g_v71_pending_evicted);
    }

    for (int i = 0; i < g_v68_pending_count; i++) {
        uintptr_t owner = g_v68_pending[i];
        uintptr_t container = 0;
        int32_t count = 0;
        int32_t cap = 0;
        char why[64] = { 0 };
        int age = (int)g_v50_ticks - g_v68_pending_tick[i];

        if (age < TNX_V68_PENDING_RETRY_TICKS) continue;
        if (!owner) continue;

        g_v68_pending_tick[i] = (int)g_v50_ticks;
        g_v71_pending_attempts[i]++;

        tnx_logf("v100 pending retry owner=%p age=%d attempt=%d src=B", (void *)owner, age,
                 g_v71_pending_attempts[i]);

        if (tnx_v68_container_gate(owner, &container, &count, &cap, why, sizeof(why))) {
            g_players_object = container;
            g_manager_count = count;

            tnx_logf("v100 pending adopted owner=%p count=%d cap=%d src=B", (void *)owner, count,
                     cap);

            return;
        }

        if (g_v71_pending_attempts[i] >= TNX_V71_PENDING_MAX_ATTEMPTS) {
            tnx_logf("v100 pending evict owner=%p attempts=%d src=B", (void *)owner,
                     g_v71_pending_attempts[i]);

            g_v71_pending_evicted++;

            for (int k = i; k + 1 < g_v68_pending_count; k++) {
                g_v68_pending[k] = g_v68_pending[k + 1];
                g_v68_pending_tick[k] = g_v68_pending_tick[k + 1];
                g_v71_pending_attempts[k] = g_v71_pending_attempts[k + 1];
            }

            g_v68_pending_count--;

            return;
        }

        if (g_v68_dump_logs < 4 && why[0]) {
            tnx_logf("v100 pending still refused owner=%p reason=%s src=B", (void *)owner, why);
        }

        return;
    }
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

    g_v67_layout_used = 0xc;

    if (count < 2) {
        int32_t alt = 0;
        int32_t at8 = 0;
        int32_t at10 = 0;

        tnx_read_i32(manager + 0x8ULL, &at8);
        tnx_read_i32(manager + 0x10ULL, &at10);

        if (at8 >= 2 && at8 <= TNX_MANAGER_MAX_OBJECTS) {
            alt = at8;
            g_v67_layout_used = 0x8;
        } else if (at10 >= 2 && at10 <= TNX_MANAGER_MAX_OBJECTS) {
            alt = at10;
            g_v67_layout_used = 0x10;
        }

        if (alt >= 2) {
            count = alt;
            capacity = alt;

            if (g_v67_layout_logs < 8) {
                g_v67_layout_logs++;

                tnx_logf("v100 container alt layout count=%d at +0x%x (the primary +0xc read %d) "
                         "mgr=%p array=%p src=B", count, g_v67_layout_used, at8 == count ? at8 : 0,
                         (void *)manager, (void *)arrayBase);
            }

            if (containerOut) *containerOut = manager;
            if (countOut) *countOut = count;
            if (capOut) *capOut = capacity;

            return 1;
        }

        if (arrayBase >= g_base && arrayBase < g_base + TNX_V60_IMAGE_SPAN) {
            g_v63_image_count++;

            if (!g_v63_image_first) {
                g_v63_image_first = 1;

                tnx_logf("v100 container image-resident count=%d reject-as-static-array mgr=%p "
                         "array=%p src=B", count, (void *)manager, (void *)arrayBase);
            }

            g_v63_image_top_mgr = (uintptr_t)manager;
            g_v63_image_top_count = count;
        }

        if (why) {
            snprintf(why, whyLen, "count=%d-tried+0x8=%d,+0x10=%d-src=B", count, at8, at10);
        }

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
    if (g_scene_object || g_mode_strong) return;

    g_v59_chain_hits++;

    if (!tnx_read_ptr(modeObject, &vtRead) || (uintptr_t)vtRead != vtable) {
        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "vtable-changed");

        g_v63_chain_vtchanged++;

        return;
    }

    if (!tnx_v57_class_slot_ok(vtable)) {
        int known = 0;

        snprintf(g_v59_last_why, sizeof(g_v59_last_why), "not-a-class-table");

        g_v59_reject_total++;

        for (int i = 0; i < g_v59_reject_vt_count; i++) {
            if (g_v59_reject_vts[i] == vtable) {
                known = 1;

                break;
            }
        }

        if (!known) {
            if (g_v59_reject_vt_count < TNX_V59_REJECT_VTS) {
                g_v59_reject_vts[g_v59_reject_vt_count] = vtable;
                g_v59_reject_vt_count++;
            }

            tnx_logf("v100 chain reject mode=%p vt=%#llx whyRejected=not-a-class-table listed=%d "
                     "total=%llu - this vt is on the reject list now and only the counter moves",
                     (void *)modeObject, (unsigned long long)vtable, g_v59_reject_vt_count,
                     (unsigned long long)g_v59_reject_total);
        } else if (g_v59_reject_total % TNX_V59_REJECT_LOG_EVERY == 0) {
            tnx_logf("v100 chain reject repeated vt=%#llx total=%llu - one hot vt is sighted "
                     "thousands of times per tick, so repeats are counted and not printed",
                     (unsigned long long)vtable, (unsigned long long)g_v59_reject_total);
        }

        return;
    }

    if (!tnx_v60_container_resolve(manager, &container, &count, &capacity, g_v59_last_why,
                                   sizeof(g_v59_last_why))) {
        if (g_v59_chain_hits <= 8) {
            tnx_logf("v100 chain reject mode=%p vt=%#llx manager=%p whyRejected=%s src=A",
                     (void *)modeObject, (unsigned long long)vtable, (void *)manager,
                     g_v59_last_why[0] ? g_v59_last_why : "unknown");
        }

        return;
    }

    if (g_v59_chain_vt == vtable && g_v59_chain_mgr == manager) {
        g_v59_chain_stable++;

        if (g_v59_chain_stable == TNX_V61_CHAIN_STABLE_TICKS && !g_v63_chain_stable_logged) {
            g_v63_chain_stable_logged = 1;

            tnx_logf("v100 chain stable vt=%#llx mgr=%p sighting=%d/%d", (unsigned long long)vtable,
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

            tnx_logf("v100 chain would-capture-but-weak vt=%#llx mgr=%p count=%d -> diag only",
                     (unsigned long long)vtable, (void *)manager, count);
        }

        g_v59_chain_stable = 0;

        return;
    }

    tnx_logf("v100 chain would-capture vt=%#llx mgr=%p array=%p count=%d cap=%d - diagnostics only, "
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

            tnx_logf("v100 class-slot vt=%p rva=%#llx inText=%d/8 raw0=%#llx raw8=%#llx -> pass "
                     "src=A", (void *)vtable, (unsigned long long)rva, inText,
                     (unsigned long long)raw0, (unsigned long long)raw8);
        }

        return 1;
    }

    if (g_v61_class_rejects < 3) {
        g_v61_class_rejects++;

        tnx_logf("v100 class-slot vt=%p rva=%#llx inText=%d/8 raw0=%#llx raw8=%#llx -> reject "
                 "reason=slots-in-text=%d/8 src=A", (void *)vtable, (unsigned long long)rva, inText,
                 (unsigned long long)raw0, (unsigned long long)raw8, inText);
    }

    return 0;
}

static int tnx_v57_owner_rejected(uintptr_t owner) {
    for (int i = 0; i < g_v57_rejected_count; i++) {
        if (g_v57_rejected[i] != owner) continue;

        if (((int)g_v50_ticks - g_v67_rejected_tick[i]) < TNX_V67_OWNER_RETRY_TICKS) return 1;

        if (!g_v67_retry_logged) {
            g_v67_retry_logged = 1;

            tnx_logf("v100 owner retry owner=%p after %d ticks - the container may have been filled "
                     "since the refusal", (void *)owner, TNX_V67_OWNER_RETRY_TICKS);
        }

        return 0;
    }

    return 0;
}

static void tnx_v57_owner_reject(uintptr_t owner) {
    if (!owner) return;

    for (int i = 0; i < g_v57_rejected_count; i++) {
        if (g_v57_rejected[i] == owner) {
            g_v67_rejected_tick[i] = (int)g_v50_ticks;

            return;
        }
    }

    if (g_v57_rejected_count >= TNX_V57_REJECT_MAX) return;

    g_v67_rejected_tick[g_v57_rejected_count] = (int)g_v50_ticks;
    g_v57_rejected[g_v57_rejected_count++] = owner;
}

static uintptr_t tnx_v57_coord_x_off(void) {
    return TNX_OBJ_X_OFF;
}

static uintptr_t tnx_v57_coord_y_off(void) {
    return TNX_OBJ_Y_OFF;
}

static int tnx_v57_mode_reverify(void) {
    void *vtable = NULL;
    void *managerPtr = NULL;

    if (!g_scene_object) return 0;

    if ((tnx_read_ptr(g_scene_object, &vtable) && vtable &&
         tnx_v57_class_slot_ok((uintptr_t)vtable)) &&
        (tnx_read_ptr(g_scene_object + TNX_MODE_MANAGER_OFF, &managerPtr) && managerPtr &&
         tnx_v57_header_reason((uintptr_t)managerPtr, NULL, NULL) == NULL)) {
        g_v57_stale_ticks = 0;

        return 1;
    }

    g_v57_stale_ticks++;

    if (g_v57_stale_ticks == TNX_V57_STALE_MAX) {
        tnx_logf("v100 scene kept at this=%p after %d ticks: vt=%p players=%p - the scene comes "
                 "from the engine's own global while state==%d, so a null class table here is a "
                 "read failure and not a verdict, and the v57 drop-after-3-ticks is off; the scene "
                 "is released only when the state leaves battle or the pointer itself changes",
                 (void *)g_scene_object, g_v57_stale_ticks, vtable, managerPtr,
                 TNX_V80_STATE_BATTLE);
    }

    return 1;
}

static void tnx_v56_mode_capture(uintptr_t candidate) {
    void *vtable = NULL;
    void *managerPtr = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!candidate) return;
    if (g_scene_object) return;
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

            tnx_logf("v100 mode reject this=%p vt=%#llx - not a class table in __DATA_CONST or "
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

        tnx_logf("v100 mode candidate this=%p vt=%#llx manager=%p count=%d cap=%d - it needs %d "
                 "matching ticks before it becomes the mode", (void *)candidate,
                 (unsigned long long)(uintptr_t)vtable, managerPtr, count, capacity,
                 TNX_V57_MODE_REVERIFY_TICKS);

        return;
    }

    if (g_v57_cand_ticks < TNX_V57_MODE_REVERIFY_TICKS) return;

    g_scene_object = candidate;
    g_v56_capture_done = 1;
    g_v56_mode_ticks = 0;
    g_v56_array_logged = 0;
    g_v56_walk_last = -1;
    g_v56_route_done = 0;
    g_v57_stale_ticks = 0;

    tnx_battle_begin("setpred");

    tnx_logf("v100 mode captured this=%p vt=%#llx manager=%p count=%d cap=%d ticks=%d",
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

    tnx_logf("v100 hooks dropped: %s reason=zero-entries-in-30-ticks", drops[0] ? drops : "none");
    tnx_logf("v100 hooks kept: %s reason=real-pointer-slot-or-wide", keeps[0] ? keeps : "none");
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

        tnx_logf("v100 hook %s dropped reason=60-ticks-zero-hits", g_slot_specs[index].shortTag);

        return;
    }

    tnx_v59_tag(g_v59_keep_tags, &g_v59_keep_count, g_slot_specs[index].shortTag);

    tnx_logf("v100 hook %s kept: %d slot(s), narrow and silent - a one-slot hook costs one "
             "comparison per call site, and the v72 log shows this rule throwing away ten of them "
             "at tick 30 with no way back, including C1 Stage::addChild",
             g_slot_specs[index].shortTag, g_slot_slots[index]);
}

static void tnx_v57_drop_hook(int index) {
    uintptr_t target = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;
    if (g_slot_installed[index] != 1) return;

    target = g_base + g_slot_specs[index].rva;

    if (!target) return;
    if (!brk_remove((void *)target)) {
        tnx_logf("v100 hook %s drop failed target=%p %s", g_slot_specs[index].shortTag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    g_slot_installed[index] = TNX_V73_STATE_DROPPED;
}

static void tnx_v57_hook_triage(int index) {
    if (index < 0 || index >= TNX_SLOT_COUNT) return;
    if (g_slot_installed[index] != 1) return;

    if (g_slot_specs[index].control) {
        tnx_v57_drop_hook(index);

        return;
    }

    if (g_slot_specs[index].slotRva) {
        tnx_logf("v100 hook %s kept: slotRva=%#llx is a real pointer slot (%d slot(s)) and the "
                 "function is simply not reached in this scenario - no re-slot needed",
                 g_slot_specs[index].shortTag, (unsigned long long)g_slot_specs[index].slotRva,
                 g_slot_slots[index]);

        return;
    }

    tnx_logf("v100 hook %s kept: %d slot(s), narrow and silent - this second copy of the triage is "
             "not called from anywhere; it now carries the same policy as the live one so that "
             "wiring it up cannot re-introduce the tick-30 drop", g_slot_specs[index].shortTag,
             g_slot_slots[index]);
}

static int tnx_v56_refresh_array(void) {
    void *manager = (void *)g_players_object;
    void *array = NULL;
    int32_t count = 0;

    if (g_v82_hop_chosen < 0 || !manager) {
        g_v56_manager = 0;
        g_v56_array = 0;
        g_v56_count = 0;

        return 0;
    }

    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array) || !array) {
        g_v56_manager = 0;
        g_v56_array = 0;
        g_v56_count = 0;

        return 0;
    }

    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) {
        g_v56_manager = 0;
        g_v56_array = 0;
        g_v56_count = 0;

        return 0;
    }

    if (count <= 0 || count > TNX_V56_COUNT_MAX) {
        g_v56_manager = 0;
        g_v56_array = 0;
        g_v56_count = 0;

        return 0;
    }

    g_v56_manager = (uintptr_t)manager;
    g_v56_array = (uintptr_t)array;
    g_v56_count = count;

    if (!g_v56_array_logged) {
        g_v56_array_logged = 1;

        tnx_logf("v100 array ready scene=%p manager=%p hop=%d array=%p count=%d - the array and the "
                 "count are re-read from the manager on every tick, so the walk follows the hop "
                 "the chain chose instead of the one it had when the array first appeared",
                 (void *)g_scene_object, manager, g_v82_hop_chosen, array, count);
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

            tnx_logf("v100 getown resolved at %#llx, function start confirmed",
                     (unsigned long long)g_v57_getown);
        }
    }

    if (!g_v57_getown) {
        if (!g_v57_getown_logged) {
            g_v57_getown_logged = 1;

            tnx_logf("v100 man walk blocked: getOwnCharacter candidate %#llx is not a function "
                     "start - resolve the real entry from xrefs before calling it",
                     (unsigned long long)(g_base + TNX_V57_GETOWN_RVA));
        }

        return 0;
    }

    g_v56_player = (uintptr_t)((void *(*)(void *))g_v57_getown)((void *)g_scene_object);
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

        tnx_logf("v100 walk player=(%d,%d) team=%d enemies=%d", g_v56_px, g_v56_py, g_v56_team,
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

    tnx_logf("v100 route clientinput returned=%llu", (unsigned long long)result);
}

static void tnx_v56_dodge_tick(void) {
    static uintptr_t setpredFn = 0;
    int best = -1;
    int64_t bestDist = 0;

    if (!g_base) return;

    if (g_scene_object && !tnx_v57_mode_reverify()) return;

    if (!g_scene_object) {
        g_v56_mode_ticks++;

        if (g_v56_mode_ticks == TNX_V56_MODE_WAIT_TICKS && !g_v56_objhit_logged) {
            g_v56_objhit_logged = 1;

            tnx_logf("v100 dodge from objhit list n=%d", tnx_v56_objhit_walk());
        }

        if (g_v56_mode_ticks == TNX_V56_ROUTE_WAIT_TICKS) tnx_v56_route_clientinput();

        return;
    }

    g_v56_mode_ticks = 0;

    if (!tnx_v56_refresh_array()) {
        if (!g_v56_objhit_logged) {
            g_v56_objhit_logged = 1;

            tnx_logf("v100 dodge from objhit list n=%d", tnx_v56_objhit_walk());
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

        if (g_v103_sp4 && TNX_V103_DODGE_USE_PRED4) {
            tnx_v103_send(newX, newY);
        } else {
            if (!setpredFn) setpredFn = g_base + TNX_RVA_SETPREDICTION;

            ((tnx_v47_setpred_t)setpredFn)((void *)g_scene_object, newX, newY);
        }

        tnx_logf("v103 dodge channel=%s write=(%d,%d) from=(%d,%d) near=(%d,%d) enemies=%d writes=%llu",
                 (g_v103_sp4 && TNX_V103_DODGE_USE_PRED4) ? "predMoveTo4" : "pred2", newX, newY,
                 g_v56_px, g_v56_py, g_v56_enemy_x[best], g_v56_enemy_y[best],
                 g_v56_enemy_count, (unsigned long long)g_v103_writes);
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

        tnx_logf("v100 slot %s reject reason=%s this=%p vt=%p", g_slot_specs[first].shortTag, reason,
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

    if (TNX_V98_CLIP_SELFTEST) tnx_v98_clip_selftest();

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

    tnx_logf("plan v75, from the v74 run: the trail's best candidate was a STRING TABLE "
             "(mgr=0x101d65f58, count=25, live=10) whose raw elements are TID_SHOP and _LEGENDARY, "
             "while the walk reported rejAscii=0 on those very elements - so the ASCII test was the "
             "first bug: it read the WORD AT an element and demanded eight printable bytes there, "
             "which can never hold for an element that IS the text. v75 therefore (1) tests the "
             "element's own eight bytes as well, (2) measures the text share over the first 32 "
             "elements of every array-header candidate BEFORE it is scored and records the container "
             "as refused when more than 30%% of them are text, (3) counts an element as live only "
             "when its id is non-zero and below one million, its team is inside 0..15 and both "
             "coordinates are inside +/-100000, (4) lets the best candidate be only a container with "
             "at least two distinct teams and two distinct positions, so a text table can no longer "
             "win on live alone, (5) prints ascii=, asciiRatio=, teamDistinct= and posDistinct= plus "
             "a REFUSED reason= on every trail line, (6) vetoes any object-vote owner whose elements "
             "repeat a single id, and (7) doubles the array probe budget to 131072 so the pass is no "
             "longer cut off before the battle container appears");

    tnx_logf("plan v76, from the binary audit of the proposed v76 plan: two of its three "
             "offset/hook premises fail against bin/NullsBrawl, so v76 (1) keeps the owner "
             "offset at +0x20, because setOwner at 0xa2d250 really does str x1,[x0,0x20] at "
             "0xa2d268 and the v74 objhit lines already agreed with it, (2) keeps coordinates "
             "on the virtual slots 0x88/0x90, because the plan getX 0xae4a1c and getY "
             "0xae4a24 are not accessors at all but one mid-function ldr x8,[x8,0x88] / blr x8 "
             "dispatch, (3) does not hook table 0x10086f8, because 0x10086f8 = 0x10086c0 + "
             "0x38, i.e. slot 7 of the table already armed as D10, and 0x1008d30 slot0/slot1 "
             "are already E3/E4, (4) arms instead the five slots that are both "
             "class-specific and still unhooked - 0x10086c0 slot21/slot23 and 0x1008d30 "
             "slot2/slot3/slot7, all verified function starts with exactly one vtable "
             "reference each, while the plan 0xb854a8..0xb85a80 were dropped because each "
             "carries 448+ references in other tables, (5) holds the vote scan for the first "
             "12 s and stops scanning the lobby, resuming from 20 s on the 10 s bucket, so a "
             "lobby run can no longer raise a TID_SHOP trail candidate");

    tnx_logf("plan v77, from the v76 run: the scan was never blocked - v76 scan held to tick=12 "
             "and v76 scan fallback at tick=20 both fired and seventeen heap passes ran - so "
             "the gate is not what stopped the trail. The gate is a pure function of "
             "g_v64_modesig_hits, and that counter stayed 0 for 150 ticks, which means the mode "
             "signature matched nothing, not that the detector was bypassed. v77 (1) raises "
             "TNX_MANAGER_PROBE_LIMIT from 131072 to 1048576 because the run reported "
             "loose=1213951 candidates against a cap of 131072 and skipped=814613, and the "
             "engine itself printed ARRAY TEST BLIND - only one candidate in seven was ever "
             "measured, which is enough to explain live=0 on all eight recorded trail "
             "candidates, (2) tightens the mode signature to a class table in __DATA_CONST or "
             "__DATA, because all three modehit[near] lines carried vtSeg=__TEXT and an "
             "in-image word outside the data segments is code, not a class, (3) adds a battle "
             "fallback that can fire only on objects passing tnx_v75_object_live, counted over "
             "the whole 64-entry objhit set rather than the 24 printed lines - the plan wanted "
             "the fallback on raw objhit counts, and the run shows why that would misfire: "
             "the team=4/5 objects it cites are class 0x100a770 instances whose gid reads "
             "1187333632, far outside the 1..999999 the tweak calls live, and the vtcensus "
             "reports ownerEqVt=2446 of count=2597 for that class, so +0x20 there is the "
             "object own class table and not a manager, (4) prints fb=liveObjs=liveTeams= on "
             "the heartbeat and one OFF line at tick 30 so the log answers whether the "
             "fallback declined rather than leaving it to be inferred, and (5) does not group "
             "by +0x3c, because own is 0 or 1 on exactly those 0x100a770 objects and would "
             "group 2696 lobby instances into two fake teams");

    tnx_logf("plan v78, from the v77 run: v77 made the scan heavier and the log says so. Not one "
             "votescan heap pass completed in the whole 61 s run - the only votescan lines are "
             "the two __DATA/__DATA_CONST ones at t=0.3 s - while the refusal counter climbed "
             "82000 -> 402536 by tick 60, against 259807 at tick 100 in v76. That is the ARRAY "
             "TEST BLIND trade going the wrong way: eight times the measured candidates costs "
             "eight times the walk, in a process that has no scene loaded. So v78 (1) puts "
             "TNX_MANAGER_PROBE_LIMIT back to 131072, (2) parks the heap walk while the armed "
             "set is silent - the run reports hooks total fired=0 armed=29 of 32 slots at every "
             "reported tick from 10 to 60, which is the cheapest proof available that no hooked "
             "class is being dispatched, and the same counter read 2016345 at tick 100 in v76, "
             "so it does separate the two states, (3) resumes on the first dispatch and retries "
             "once every 300 parked ticks, so a container that only a scan can find stays "
             "reachable, and (4) prints parked= on the heartbeat plus one line per park and "
             "resume, so the next log shows the decision instead of leaving it to be inferred");
 
    tnx_logf("plan v81, from the v80 run and the binary audit of the proposed plan: (1) the scene "
             "pointer the engine itself returns from 0x8c5130 is now an EDGE - the alert fires when "
             "the pointer goes from null to non-null at state==5, so a second battle raises a "
             "second alert; the once-per-process latch is deleted, (2) the chain globals are reset "
             "together, in one function, whenever the state leaves battle or the pointer changes, "
             "so nothing can be inherited, (3) mode is renamed scene and manager is renamed "
             "players, because 0xac3e74 receives the scene and reads players from scene+0x28, "
             "(4) the drop-after-3-silent-ticks is deleted - the engine's global is the authority "
             "and a missing class table is a read failure, not a verdict - and (5) the six hook "
             "targets that sat on the two RENDER classes 0x1008d30/0x1009290 are replaced by six "
             "class-specific slots of the scene's OWN class table 0xfe9d00, which the constructor "
             "at 0x8c5184 installs and whose neighbours 0x8c5130/0x8cdfd4 are the very functions "
             "the engine uses to reach the scene; the container's elements are then judged by "
              "tnx_v81_is_battle_object, which accepts a data class table plus a kind at +0x35c "
              "instead of demanding a global id that the container does not carry");

    tnx_logf("plan v82, from the v81 run and the binary audit of the chain it walked: the scene "
             "chain WORKS - scene=%%p style lines appear with no scan - but the object at "
             "scene+0x28 is the battle CLIENT and not the container. The binary says so twice: "
             "0x8ce048 is a screen factory that builds state 5 as new(0x98) plus 0x8c51f8, whose "
             "constructor stores 0xfe9d00 at [+0] (so the scene class is right), and the scene's "
             "own slot +0xb0 at 0x8cc6dc null-checks [+0x28] and logs \"Init. No battle client\" "
             "when it is empty - so [+0x28] is a client object with fields at +0x7c, +0x108 and "
             "+0x1a0, not a vector header. findOwningTeam 0xac3ddc reads [+0x28] off ITS receiver "
             "and only then [+0x0]/[+0xc] off the result, so the chain needs one more hop: "
             "container = [[scene+0x28]+0x28]. v81 stopped one hop short, which is why count=6 "
             "came out of a client field and the six \"elements\" were the client's own leading "
             "pointers. Therefore v82 (1) reads both hops, tests each with the same "
             "array/count/cap header, publishes only the one that passes and dumps both once per "
             "scene with a segment code per qword, (2) reads the element kind where the engine "
             "reads it - 0x382cc8 is ldr x0,[x0,0x10], so the kind lives at [[element+0x10]+0x35c] "
             "and never at [element+0x35c], which is the arithmetic error that made every v81 "
             "element report kind=0, (3) retargets B1/B2/B3 from the 0xff5720 slots, which "
             "recorded zero hits in two whole runs, onto three class-specific slots of the class "
             "table 0xf9e248 the container's own elements carry (+0x28 @568d0c, +0x40 @569694, "
             "+0x08 @568bf4, one data reference each), because 0xf9e248+0x28 is the dispatch "
             "findOwningTeam performs on every element of every walk, and (4) records that "
             "0xf9e248 is NOT unreferenced: coderef.py matched only a single add after adrp and "
             "missed the split immediate the constructor emits at 0x5652dc/0x564d44/0x568c08 "
             "(adrp; add #0x238; add #0x10), so every earlier zero-reference verdict on this "
              "table is a tool artefact and not a fact about the binary");

    tnx_logf("plan v83, from the v82 binary re-audit: the two-hop chain is RIGHT, the hook retarget "
             "that came with it is not. Re-read from the code, not from the plan: the battle "
             "function at 0x52b2a0 takes the scene with bl 0x8c5130 and at 0x52b180 does "
             "ldr x24,[x0,0x28], then reads the mode variation at [x24+0x124] and walks [x24+0x28] "
             "with the count at [+0xc] and the array at [+0x0] - so the receiver of those walks is "
             "the CLIENT, not the scene, and findOwningTeam2's only caller 0x52b864 passes that "
             "same x24. container = [[scene+0x28]+0x28] therefore stands and v81's count=6 was a "
             "client field. Note also that the call those walks make between the load and the "
             "count, 0x1c1c0, is a bare ret in this image, so the address the count is read from "
             "is exactly the one loaded. The kind is confirmed the same way: 0x382cc8 is b "
             "0x117050 = ldr x0,[x0,0x10], findOwningTeam reads [def+0x35c] against 0x1a, and "
             "both the battle walk and findOwningTeam2 read [def+0x68] against 0x36/0x38, so "
             "[def+0x68] is a second per-type field that this run prints only through the census. "
             "B1/B2/B3 go BACK to the 0xff5720 slots (+0x28 @0xa2e5b8, +0x18 @0xa2d250 setOwner, "
             "+0x38 @0xa2d6ac) because the v82 retarget rested on a misreading of 0xf9e248+0x28: "
             "that word is 0x568d0c, which str's the table 0xf9e268 into [+0] and calls an "
             "imported function - destructor-shaped, returning void - and it cannot be the slot "
             "the engine calls and compares against 3 on every container element; 0xff5720 by "
             "contrast is installed by the constructor at 0xa2e2f4, which stores it at [+0] right "
             "after its base constructor, and its [+0x18] is the exact method addGameObject "
             "dispatches. No slot is claimed for the element class until the census prints the "
             "class the elements really carry, which is what hypoElem= now reports. v83 also "
             "fixes a compile error that neither gate sees: tnx_v81_container_census read def "
             "without declaring it");

    tnx_logf("plan v84, from the v83 run: the chain delivered a real container. On the second "
             "scene hop1 0x118033980 and hop2 0x11e595880 BOTH carried a header, chosen=1, and the "
             "census on it read accepted=2 of 16 with teams=2 gidSeen=2 classRva=0xff57b0 "
             "hypoElem=0 - so the elements carry 0xff57b0 and 0xff5440 and the 0xf9e248 hypothesis "
             "is retired; on the first scene, where hop2 was still array-null, hop1 was chosen and "
             "its six elements reported classRva=0xf9e248, which is what made that table look like "
             "an object class in the first place. Three fixes: (1) the walk now takes the chosen "
             "hop - tnx_v56_refresh_array adopts the published g_players_object/array/count and "
             "g_v82_hop_chosen instead of re-deriving scene+%#llx one hop, which is exactly why "
             "array ready printed manager=0x118033980 count=6 (the client) while the census "
             "measured 0x11e595880 count=16, and it clears the array when no hop passed so the "
             "dodge falls back to the objhit list rather than walking a stale container, (2) the "
             "pending gate now runs the very header test the hop test runs, "
             "tnx_v82_container_header - array at +0x0 heap-resident, count at +0x%#llx, cap at "
             "+0x%#llx, count<=cap<=ceiling - instead of guessing a count among +0xc/+0x8/+0x10 "
             "with a 2..N window, which is why 0x135eef1e0 was refused with count=1 while the hop "
             "test accepts that same shape, and the array probe is now recorded and not obeyed, "
             "(3) the not-a-class-table reject prints one line per vt plus a counter, because "
             "hotflag 0x109bd86c0 arrives from the 435 slots of D13 and filled the log with tens "
             "of thousands of identical lines. Also confirmed once more: +0xd0 is not a dead flag "
             "and +0x20 is not the owner, so neither may be used as object identity",
             (unsigned long long)TNX_MODE_MANAGER_OFF, (unsigned long long)TNX_MGR_COUNT_OFF,
             (unsigned long long)TNX_MGR_CAP_OFF);

    tnx_logf("plan v85, from the v84 run: the container is real and it is polymorphic - its "
             "elements carried 0xff5440 with gid 1000009/1000011, and 0xff57b0 and 0xff5100 beside "
             "it, so three classes live in one array. Four changes. (1) The hop choice is sticky: "
             "once hop2 passes the header test it is kept and the client is never chosen again, "
             "because on the first scene hop2 was array-null, the fallback took hop1, and hop1's "
             "own six elements reported classRva=0xf9e248 - which is the whole origin of the "
             "retired 0xf9e248 reading; the sticky flag and the chosen hop are cleared by the "
             "scene reset together with the other chain globals. (2) man walk and census read one "
             "container: tnx_v56_refresh_array takes the published globals, and with (1) the hop "
             "it takes cannot be a different hop from the one the census measured. (3) The third "
             "hop through 0x991440 - players+%#llx and then +%#llx - is deleted: it dead-ends in a "
             "block whose first word is itself and whose rest is zero, so nothing is read past the "
             "container. (4) New instruments for the offsets that are still unknown: a full "
             "+0x00..+0x%x dump of one accepted element (up to %d of them) plus 16 qwords of the "
             "objects held at elem+%#llx, which is the definition the engine reads in 0x382cc8, "
             "and at elem+0x40, plus 8 qwords of every heap pointer at scene+0x28/+0x30/+0x38/"
             "+0x40/+0x58 and client+0x18/+0x20/+0x30/+0x38/+0x40/+0x58/+0x68/+0x80, each with "
             "the container-header verdict, so a second container - where the projectiles would "
             "have to be - is recognisable from the log alone. Still NOT known and not to be "
             "assumed: the element's coordinates (no float pair at +0x30/+0x34/+0x80), its own "
             "character pointer, or whether this array ever holds projectiles at all. The element "
             "offsets are disputed - +0x4c/+0x48/+0x50 for team/index/gid against the contract's "
             "+0x40 and +0x8 - so the dump is the instrument that settles it, not another offset "
             "change", (unsigned long long)TNX_V81_PLAYERS_NEXT_OFF,
             (unsigned long long)TNX_V81_NEXT_MEMBER_OFF, (unsigned)(TNX_V85_ELEM_QWORDS * 8),
             TNX_V85_ELEM_DUMPS, (unsigned long long)TNX_V82_ELEM_DEF_OFF);

    tnx_logf("plan v86, from the v85 run and the vtable audit: the container's element type is the "
             "WORD at [vt+%#llx], a two-instruction getter of the form mov w0,#N; ret, and that is "
             "what the engine itself compares - findOwningTeam skips every element whose w0 is not "
             "0 and the battle walk plus findOwningTeam2 take only w0==3, which is why the same "
             "slot looked contradictory when it was read as one predicate. Five changes. (1) The "
             "census classifies by that word: 0x14c81c is 0, 0xa31768 is 1, 0x9f4ec8 is 2, "
             "0x314ca0 is 3, 0x490b54 is 4, 0x86f494 is 5, 0x370688 is 6, 0x490d94 is 8, and "
             "anything else prints type=unknown with the raw word instead of rejecting the "
             "element, so a type outside that list can never turn into accepted=0 again; the old "
             "gid/kind rule survives only as the accept= field and filters nothing. (2) The census "
             "is forced onto hop2: its budget is reset the first time hop2 is the chosen hop, "
             "because in the v85 run hop2 filled at tick 39 with count=8 long after the census had "
             "been spent on hop1, whose class 0xf9e248 has no type getter at all. (3) Each element "
             "line carries def35c and def68 - the two fields the engine reads at [[elem+%#llx]+"
             "%#llx] and [[elem+%#llx]+%#llx] - next to the hypotheses team4c/gid50/byte48 and the "
             "contract readings team40/gid8, and the head dump covers +0x00..+0x%x for the first "
             "four elements so the log shows whether +%#llx is a definition pointer or a float "
             "pair. (4) The contract drops +0xd0 as a dead flag and no longer treats +0x20 as "
             "object identity, and it records +0x88/+0x90 as what they are: float getters reading "
             "+0x10 and +0x1c, with setters in slots +0x70 and +0x80. (5) No hook is armed on the "
             "type getters here: they are two instructions and would fire on every dispatch, "
             "0x14c81c must never be armed, and 0xb90a28 must never be called because no bl "
             "anywhere in __TEXT reaches it. For v87: the type-3 class table 0xfd4840 carries "
             "float getters at +0x10/+0x1c and at +0x100/+0x104 with matching setters (slots "
             "0x1b0/0x1b8/0x1c8/0x1d0), which is where the coordinates have to be read, while "
             "0xffb4c8 has the same type-3 getter but no float accessor and six other type codes, "
             "so it is a descriptor block and not the class vtable",
             (unsigned long long)TNX_V86_TYPE_SLOT_OFF, (unsigned long long)TNX_V82_ELEM_DEF_OFF,
             (unsigned long long)TNX_V79_KIND_OFF, (unsigned long long)TNX_V82_ELEM_DEF_OFF,
             (unsigned long long)TNX_V86_DEF_68_OFF, (unsigned)(TNX_V86_ELEM_QWORDS * 8),
             (unsigned long long)TNX_V82_ELEM_DEF_OFF);

    tnx_logf("plan v87, from the v86 build: one type error and nothing else - tnx_v86_element_type "
             "read the type slot into a uintptr_t while tnx_read_ptr takes a void**, so it now "
             "reads into a void* and strips that, with no change to what it computes. The run has "
             "exactly one question to answer, the classRva and the type of the FIRST element of "
             "hop2, so the census is now taken only while hop=%d is the chosen hop and only once "
             "hop2 carries a count above zero - it waits instead of measuring an array-null hop - "
             "and the summary line prints hop= so the hop cannot be inferred, with a one-shot line "
             "saying the census was forced on hop2. Every element of that census also prints its "
             "four float fields read as single precision at +%#llx, +%#llx, +%#llx and +%#llx once "
             "the first element's classRva is %#llx, because that class exposes exactly those as "
             "float getters in its slots 0x1b0/0x1b8 and 0x1c8/0x1d0, and the head dump prints the "
             "same element twice in one pass, as raw qwords over +0x00..+0x40 and as those four "
             "floats. No census is taken on hop1 in this run at all: 0xf9e248 has no type getter at "
             "[vt+%#llx] and can only produce type=unknown",
             1, (unsigned long long)TNX_V87_FLOAT_LO, (unsigned long long)TNX_V87_FLOAT_LO2,
             (unsigned long long)TNX_V87_FLOAT_HI, (unsigned long long)TNX_V87_FLOAT_HI2,
              (unsigned long long)TNX_V86_TYPE3_CLASS_RVA,
              (unsigned long long)TNX_V86_TYPE_SLOT_OFF);

    tnx_logf("plan v88, from the v87 run: six fixes, and the first is what made the run "
             "unreadable. (1) The walk and the census read different containers because the "
             "dodge resolved its manager as scene+0x28 once and kept it: the probe now "
             "recomputes the container from g_v82_hop_chosen and g_players_object on EVERY "
             "tick, re-probes when that pointer changes, and refresh_array re-reads the array "
             "and the count from the manager instead of taking the cached pair, so the hop "
             "switch at t=42 s cannot leave the walk on the client. (2) The element id is read "
             "at +%#llx and the +0x50 word is deleted from the code and from the census line; "
             "rejGidZero and the gidSeen counter both count that offset and nothing else. "
             "(3) One element of class %#llx is dumped in full - +0x00..+0x%x of the element "
             "and +0x00..+0x%x of the definition it points at through elem+%#llx - with +%#llx "
             "and +%#llx printed as two signed int32, so the field that splits four players "
             "into two sides is read out of the log instead of guessed. (4) Membership is "
             "[elem+%#llx] == container, counted as back= on the census and on the walk; the "
             "owner chain through owner+0 and owner+%#llx that reported back=0 is no longer "
             "consulted. (5) The float block and the head-floats line are printed for type %d "
             "only: the v87 gate tested the CLASS RVA of the first element, which is why the "
             "line still appeared for a type-0 element whose +%#llx is a definition pointer. "
             "(6) The census is taken once per container - an array address is remembered, so "
             "a repeat census needs a different container, not a different tick - which is "
             "what turned one hop2 container into four censuses with counts 4, 21, 7 and 8",
             (unsigned long long)TNX_OBJ_GLOBALID_OFF, (unsigned long long)TNX_V88_ELEMCLASS_RVA,
             (unsigned)(TNX_V88_ELEM_QWORDS * 8), (unsigned)(TNX_V88_DEF_QWORDS * 8),
             (unsigned long long)TNX_V82_ELEM_DEF_OFF, (unsigned long long)TNX_V88_ELEM_INT_A,
             (unsigned long long)TNX_V88_ELEM_INT_B, (unsigned long long)TNX_V88_ELEM_BACK_OFF,
             (unsigned long long)TNX_MODE_MANAGER_OFF, TNX_V88_TYPE3_CODE,
             (unsigned long long)TNX_V82_ELEM_DEF_OFF);

    tnx_logf("plan v89, from the v88 run: the hop fix holds - the walk switched from hop1 to hop2 "
             "on both battles and hop2 read usable=6 rejected=0 - and four things are fixed on top "
             "of it. (1) The coordinate pair is a CONSTANT now: x at +%#llx and y at +%#llx, "
             "int32, and the auto choice is deleted, because the same analysis block that printed "
             "coord pair chosen=+0x30,+0x34 in the first battle let the walk take +0x3c/+0x40 in "
             "the second, where pos= then showed the owner index and the team. The team field is "
             "pinned the same way - +%#llx, the field the run confirms as the side - for the "
             "same reason, since that rule picks a field from a sample too. (2) The census is "
             "deduplicated by container and not by array: the array pointer moves when the "
             "object array is reallocated, which is why one manager was censused twice with "
             "counts 12 and 9. (3) The walk is driven by the tick and by the count instead of by "
             "the array: while hop=%d and the count is above zero it re-probes every %d ticks "
             "and on every change of count, and the run that had four heartbeats with count=12 "
             "and no walk line at all is what that fixes. (4) dodge ENTERED is printed once per "
             "second unconditionally, with hop, coordOk and usable on the line, because in the "
             "v88 run the dodge announced itself three times at start-up and then never again, "
             "which left it unknown whether it ran after the walk handed it coordinates",
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF,
             (unsigned long long)TNX_OBJ_TEAM_OFF, 1, TNX_V89_WALK_EVERY);

    tnx_logf("plan v89 confirmed offsets: elem+%#llx gid, elem+%#llx def, elem+%#llx back, "
             "elem+%#llx x, elem+%#llx y, elem+%#llx team, elem+%#llx owner index; +0x4c is a byte "
             "that is not a team and +0xd0 is not a flag",
             (unsigned long long)TNX_OBJ_GLOBALID_OFF, (unsigned long long)TNX_V82_ELEM_DEF_OFF,
             (unsigned long long)TNX_V88_ELEM_BACK_OFF, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF, (unsigned long long)TNX_OBJ_TEAM_OFF,
             (unsigned long long)TNX_OBJ_OWNERINDEX_OFF);

    tnx_logf("plan v90, from the v89 run: the run confirmed the v89 fixes - walk coord fixed and "
             "walk team fixed appear once, hop2 then reads usable=20..29 with inRange equal to "
             "usable and rejGidZero=0 on both sides - and the dodge now enters every second with "
             "coordOk=1 and setpredFn=1 while writes stays 0. One symptom, five possible causes, "
             "and the ENTERED line could not tell them apart, so this build moves nothing in the "
             "dodge and only makes the refusal say which gate it was. (1) A gate line is printed "
             "beside ENTERED on the same tick with ownFound, own, ownTeam, targetFound, target, "
             "selfPos, targetPos, vector, clamped, actuatorReached and a single reason word, so "
             "noOwn, noTarget, noThreat, predictionZero, noActuator and degenerateVector are "
             "distinguishable in one run instead of five. (2) The three words the mode carries at "
             "+%#llx, +%#llx and +%#llx are read on every tick and logged the first time a "
             "container exists: a word that lies inside array..array+count*8 is one of the "
             "container's own elements and therefore the local player, which is the own element "
             "the dodge cannot name. (3) degenerate=%d is printed when fewer distinct positions "
             "appear than in-range elements, because the run had distinct=4 against inRange=5 and "
             "a zero vector is what two elements in one cell would produce; the dodge still "
             "computes and the flag only records it. (4) A sixth gate is reported that the plan "
             "did not ask for, because it is read from the dodge's own code and not guessed: "
             "before the store the dodge checks that the word at mode+0x28 equals the manager the "
             "walk uses and returns without writing when they differ, and since the walk was moved "
             "to the second hop while that word still names the client, this guard refuses every "
             "store and only ever logs its first six refusals - modeReal and modeChain show it",

             (unsigned long long)TNX_MODE_SLOT_A, (unsigned long long)TNX_MODE_SLOT_B,
             (unsigned long long)TNX_MODE_SLOT_C, 1);

    tnx_logf("plan v91, from the v90 run: four fixes. (1) The side is read at +%#llx and not at "
             "+0x40, because the run printed distinct(+0x40)=1 against distinct(+0x4c)=2..4 with "
             "raw elements showing plus40=1 and plus4c=-1/0/1, and the dead byte sits at +%#llx, "
             "because the run's own probe said offset=0xd4 splits four readable pointers into two "
             "zero and two one while +0xd0 is 63 on every element; a dead byte of 63 is truthy, so "
             "until this fix every element was treated as dead by the dodge. (2) The mode guard no "
             "longer compares mode+0x28 with the container the walk uses: it requires the mode's "
             "class table to be a data table and the chain mode+0x28 then +%#llx to reach that "
             "container, so hop %d stops blocking its own store. (3) The own element is searched "
             "for: every qword of mode+0x00..+0x%x and of client+0x00..+0x%x is tested against "
             "array..array+count*8, and a word that lands inside names the local player, with the "
             "offset and the element index logged; the prediction pair is only the fallback, and "
             "the dodge and the gate line call the same resolver so they cannot name different "
             "elements. (4) The reason order is corrected: noOwn is reported before noTarget, both "
             "before modeGuard, then coords and the actuator, and predictionZero is last, because "
             "the v90 run reported predictionZero while ownFound and targetFound were both zero",
             (unsigned long long)TNX_V91_TEAM_OFF, (unsigned long long)TNX_V91_DEAD_OFF,
             (unsigned long long)TNX_V82_CLIENT_HOP_OFF, 1,
             (unsigned)(TNX_V99_SCAN_QWORDS * 8), (unsigned)(TNX_V99_SCAN_QWORDS * 8));

    tnx_logf("plan v92, from the v91 build failure and the binary read: (0) v91 did not compile; "
             "the cause was ordering and not a missing helper - tnx_v91_mode_real, own_scan "
             "and tnx_v91_resolve_own were defined below tnx_v90_gate_report, which calls them, so "
             "all three now sit above it; the check that should have caught this reported zero "
             "because it treated a file-level closing brace as the start of a statement and "
             "swallowed every declaration after it, and with that fixed it reports exactly the "
             "three lines the compiler reported. (1) The binary answers the actuator question: "
             "%#llx is not a function start but a shared tail of the function at %#llx, three "
             "instructions that store and return, and exactly one bl in the whole __TEXT reaches "
             "it, at %#x - so the field is written by real code and the store is callable. (2) The "
             "tweaks E6 candidate %#x is two instructions, add sp,sp,#0x30 then ret, which is an "
             "epilogue and not a send, and E5 %#x is mid-function as well, so neither is a route. "
             "(3) No store to +0x1d4 or +0x1d8 anywhere in __TEXT lies inside a method of the mode "
             "class table, so those two words are only written from outside it. (4) The side is "
             "dumped as bytes and as int32 at +0x40..+0x50 on the first %d elements, the two dead "
             "candidates are printed side by side, gid uniqueness is counted, and the written "
             "prediction is read back %d frames later as kept or overwritten",
             (unsigned long long)TNX_RVA_SETPREDICTION, (unsigned long long)0xac3e74ULL, 0xa26520,
             (unsigned long long)0x7c13dcULL, (unsigned long long)0xb90b8cULL, TNX_V92_TEAM_DUMPS,
             TNX_V92_VERIFY_FRAMES);

    tnx_logf("plan v93, from the v92 run: (A) the side goes back to +0x%#llx, because the team "
             "dump printed 1,1,0,0 at +0x40 and 0,2,29535,0 at +0x4c and 29535 is the byte pair "
             "0x5f 0x73, an inline string - the distinct count said +0x4c was the busier field and "
             "the busier field was a string. (B) The dead byte is not +0xd4 either: the probe read "
             "0,2,0,0 in one run and 0,0,0x0c,0 in another and called the second one a flag when "
             "0x0c is just another field, so no dead offset is used and the filter is off "
             "(deadF=%d) until a byte is proven, and the dump is split per class (classdump) "
             "because players and projectiles were being averaged together. (C) The own scan no "
             "longer accepts value==array: client+0x00 is the vector header itself and the run "
             "reported it as element[0]. (D) The actuator is finally tested on its own: with a "
             "container of two or more and the mode guard satisfied, (%d,%d) is written once a "
             "second with no own element, no target and no threat logic, and three frames later "
             "the two words are read back and every container position is printed, which answers "
             "moved - not moved - overwritten without knowing who the local player is",
             (unsigned long long)TNX_OBJ_TEAM_OFF, TNX_V93_DEAD_FILTER, TNX_V93_TEST_X,
             TNX_V93_TEST_Y);

    tnx_logf("plan v94, from the v93 verdict and the binary read: prediction is rejected as an "
             "actuator - the value was written fifteen times, every write came back kept, and no "
             "element ever moved towards it - so the test write is off and the own fallback that "
             "picked an element by proximity to that dead pair is deleted: when the scan finds no "
             "own element the dodge now reports noOwn instead of naming a projectile. The binary "
             "closes the three candidate routes. (1) There is no position setter to call: a store "
             "to +0x30 immediately followed by a store to +0x34 on the same base register occurs "
             "NOWHERE in __TEXT, and the 714 and 435 raw matches were dominated by sp-relative "
             "stores, which the first pass counted as object writes. (2) The enclosing function of "
             "the E5 candidate %#x has no caller and no __DATA_CONST slot, and E6 %#x is an "
             "epilogue inside a 172-byte function that also has no slot, so neither can be reached "
             "through the only mechanism this tweak has. (3) setMoveStickState %#x is a real "
             "function but it too has no slot and no caller outside itself. (4) The one and only "
             "caller of the prediction setter is the loader at %#x, which fills fields from "
             "resource ids, so those two words belong to object construction. What is left is the "
             "client input route - the manager at mode+%#llx and the 60-byte input record whose "
             "fields are type at +0x4, x at +0x8 and y at +0xc - and that is the next thing to "
             "read out of the binary, not another guess",
             (unsigned long long)0xb90b8cULL, (unsigned long long)0x7c13dcULL,
             (unsigned long long)0x5857ecULL, (unsigned long long)0xa24278ULL,
             (unsigned long long)TNX_MODE_INPUTMGR_OFF);

    tnx_logf("plan v95, from the JS dodge and the binary: the JS build moves the character by "
             "writing a joystick that lives in the BattleScreen object, and it names eight fields - "
             "A=(+0x9b8,+0x9bc), B=(+0x9c0,+0x9c4), mode +0x8ac, state +0xed7, cos and sin at "
             "+0x8f4 and +0x8f8. Those offsets do not exist on our path: they are read here only "
             "on the scene and on its client, once a second, so a run says whether this build "
             "keeps the joystick in the same window, and a one-off scan walks every heap pointer "
             "in the first 0x1000 bytes of the scene and reports any object whose window reads as "
             "finite floats, which is the object to write. The binary says the same thing from the "
             "other side: +0x9b8, +0x9c0, +0x9c4 and +0xed7 appear ZERO times as an immediate "
             "anywhere in __TEXT, and the function that contains the tweaks own UPDATEMOVEMENT "
             "address reads only +0x4..+0x140 with no float cluster, so those offsets belong to "
             "another build and another object and are not ported as they stand. The target is "
             "still a read-out, not a guess");

    tnx_logf("plan v96, from the pointer-slot check the plan asked for: there is NO slot for any "
             "of the candidates - a direct scan of every eight-byte word of __DATA_CONST and "
             "__DATA, in all three encodings, finds nothing pointing at setMoveStickState %#llx, "
             "at getClosestAnyCollision %#llx, at the E5 or E6 addresses, or at the updateMovement "
             "candidate, and fixups.json agrees with zero entries for each. Both callable routes "
             "are therefore closed for the same reason as before: this tweak installs hooks only "
             "through a data slot, and there is none to install into. What is left is the third "
             "route, and it needs no slot: every second the scene, its client and every heap "
             "pointer found in the first 0x800 bytes of the scene are read as a %#x-byte float "
             "window, compared with the window of the previous second, and only the offsets that "
             "changed are printed. A joystick is a handful of adjacent floats that move while the "
             "rest of the window stands still, so the object and the offset fall out of one run "
             "without a hook and without assuming the JS layout",
             (unsigned long long)0x5857ecULL, (unsigned long long)0xbd55c4ULL,
             (unsigned)TNX_V99_SPAN);

    tnx_logf("plan v97, from the three blind spots of the v96 detector: (1) the sample is taken "
             "only while the battle is live - the container is walked every tick and if no element "
             "changed its position the windows are not compared and one line says the sample is "
             "held, because at one hertz a joystick returns to neutral between two samples and a "
             "still window would then read as absence when it is only idleness. (2) A big count is "
             "no longer a dead end: the changed slots are collected and split into runs of "
             "adjacent slots with a gap of at most %d, and each run is printed with its start, its "
             "length, its first and last value, and quiet=%d, which says whether the %d slots on "
             "both sides stood still - that is what separates a vector from a buffer of counters. "
             "(3) Two free signatures run on the same data: a run of two to %d adjacent "
             "pair satisfies cos squared plus sin squared is one within %d is printed as rotation, "
             "and a short run inside a quiet window is printed as a candidate. The whole window is "
             "now compared as raw words rather than filtered to finite floats, so a state kept as "
             "an int, which the JS build has as a halfword, is caught by the same pass. Clipping "
             "stays out of the port until there is an actuator, but the note is recorded here: the "
             "threat segment has to end where the projectile hits a wall, because a range that "
             "runs to its theoretical end makes the dodge flee a bullet that cannot reach the "
             "point, and that is correctness and not an optimisation",
             TNX_V97_GROUP_GAP + 1, 1, TNX_V97_QUIET, TNX_V97_GROUPS_MAXLEN,
             (int)(TNX_V97_COSSIN_TOL * 1000.0f));

    tnx_logf("plan v98, from the review of v97 before its run: (1) the rotation signature now tests "
             "the changed array and not the span - only two CHANGED slots that are strictly "
             "adjacent are paired, so a normalised vector anywhere else in the same window cannot "
             "raise the line, which was a real false positive in v97. (2) The receivers of the six "
             "V slots are added to the bases: those slots land on the scene object itself (class "
             "0xfe9d00, the object the JS build calls BattleScreen), while the A and B slots land "
             "on elements, which is the wrong level for a joystick. (3) Two sampling fixes: on "
             "resume every snapshot is dropped, so the first comparison after a hold is against a "
             "fresh baseline instead of a window that is N seconds old, and a forced sample fires "
             "after %d seconds without movement, because a player holding the stick into a wall "
             "does not move and that is exactly when the joystick state is most informative. (4) "
             "The wall clipping is written now rather than when the actuator arrives, and it is "
             "already exercised: four synthetic segments run against an eight by eight grid with "
             "one wall column at start-up and report pass and fail, so the clipped range, the "
             "remaining range and the time to hit can be trusted before they are ever pointed at "
             "the real tilemap", TNX_V98_FORCE_SECS);

    tnx_logf("plan v99, from the v98 run and the corrections to its reading: (1) the sampling window "
             "grows from 0x600 to %#x bytes, so the generic diff now covers +0x8ac, +0x8f4, +0x8f8 "
             "and +0x9b8 of every base, which the v98 window stopped short of; the joy probe already "
             "read those offsets directly and without any window, so the window was never what hid "
             "them - what it hid is the same offsets from the group and the rotation analysis. (2) "
             "The input manager at scene+%#llx is added as a base of its own, ahead of the V slots "
             "and the heap children, because the only normalised pair of the v98 run was found on it "
             "and not on the scene, and a list capped at %d bases can starve a late addition. (3) "
             "The own scan covers %#x bytes on each of three objects instead of 0x300 on two: the "
             "the v98 log proves the container, the coordinates and the team are real, so the one "
             "missing fact is which element is the local player. (4) The input manager can be "
             "driven as an actuator: the pair at +%#llx and +%#llx is written once a second behind "
             "TNX_V99_INPUTMGR_WRITE, which is off by default, and the sample resumed line of the "
             "same run answers whether an element moved - the same shape as the prediction test, "
             "which came back kept and moved nothing. (5) Adoption refuses an object whose first "
             "word is not a class table inside the image, so the ASCII word that E2 reports as its "
             "vtable cannot become the scene. (6) A static second is visible: a base with changed=0 "
             "prints no window line at all, so the run now reports when every compared base was "
             "byte-identical, which the v98 log could not tell apart from a second that was never "
             "sampled. (7) The one real division hazard of the clip walk is closed: the cell was "
             "divided before it was checked, so a caller passing a zero cell divided by zero first "
             "and the guard four lines below it could not have caught that - the guard now runs "
             "before both divisions and a fifth selftest case passes cell=0. No guard is added for "
             "a division by a remaining range, because nothing in this build computes a time to "
             "hit: that phrase in the v98 plan is prose about a future actuator and is not a symbol "
             "anywhere in the code", (unsigned)TNX_V99_SPAN,
             (unsigned long long)TNX_MODE_INPUTMGR_OFF, TNX_V96_BASES,
             (unsigned)(TNX_V99_SCAN_QWORDS * 8), (unsigned long long)TNX_V99_INPUTMGR_COS_OFF,
             (unsigned long long)TNX_V99_INPUTMGR_SIN_OFF);

    tnx_logf("plan v100, from the first CI build of v99, which did not compile: (1) the write path "
             "reached for mach_vm_write, and the iOS SDK declares that function in mach/mach_vm.h "
             "while this file imports mach/mach.h and mach/vm_map.h - vm_map.h carries "
             "vm_read_overwrite and the mach_vm_* TYPES come from vm_types.h, which is why the "
             "reads compiled and the write did not; the error was 'use of undeclared identifier "
             "mach_vm_write; did you mean mach_vm_range'. (2) The local compile gate could not have "
             "caught it: the gate compiles against hand-written stub headers and declares whatever "
             "the source calls, so it marked the call clean while the SDK had no such declaration "
             "in scope, and that is the one class of error a stub prelude cannot see. (3) The write "
             "no longer needs a mach call at all: the target is heap memory that the same run has "
             "already read back as finite floats, so it is mapped and writable, and a plain store "
             "closes the same hole with no SDK symbol; the read-back of the two words after the "
             "store is printed as kept=%%d and is the failure signal a store can give. (4) The gate "
             "now audits the mach and vm calls in the source against the set that the last green "
             "build used - vm_read_overwrite, vm_protect, vm_region_64, mach_task_self, "
             "mach_port_deallocate - and reports any call outside it as a header question, so "
             "mach_vm_write is named as a foreign call instead of passing as clean");

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