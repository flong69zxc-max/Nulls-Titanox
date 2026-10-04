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
 

#import <signal.h>
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

#define TNX_OWNER_VOTE_MIN 3

#define TNX_OWNER_VOTE_TEAMS_MIN 2

#define TNX_OWNER_VOTE_CONFIRM 1


#define TNX_OBJ_HIT_DUMP_MAX 64
#define TNX_OBJ_HIT_PRINT_MAX 24

#define TNX_VTCENSUS_MAX 384
#define TNX_VTCENSUS_PRINT 16
#define TNX_VTCENSUS_SLOTS 12

#define TNX_VTCENSUS_INST 4

#define TNX_HEAP_SCAN_BUDGET_MAX (768ull * 1024ull * 1024ull)

#define TNX_OBJ_GLOBALID_OFF 0x8ULL
#define TNX_V106_GID_FALLBACK_OFF 0x50ULL
#define TNX_V106_COORD_SOFT 0
#define TNX_V110_WIRE_OWNER 1
#define TNX_V110_HOPCHOSEN_DIRECT 2

#define TNX_V112_FLAG_OFF 0xacULL
#define TNX_V112_INPUT_X_OFF 0x10cULL
#define TNX_V112_INPUT_Y_OFF 0x110ULL
#define TNX_V112_INPUT_K_OFF 0x114ULL
#define TNX_V112_SETPRED4_RVA 0xac3a58ULL

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

#define TNX_V115_MODE_OFF 0x124ULL
#define TNX_V115_MODE_TARGET 7
#define TNX_V115_GATE_PTR_OFF 0x30ULL
#define TNX_V117_GATE3_PTR_OFF 0x38ULL
#define TNX_V119_DENOM_MIN 4
#define TNX_V123_MAX_SLOTS 32
#define TNX_V123_HOP2_DEFER 0

#define TNX_V126_ALLOC_GOT_RVA 0x00f78180ULL
#define TNX_V126_TYPE_MOVE 0xa
#define TNX_V126_OWN_OFF 0x918ULL
#define TNX_V126_OWN_INNER_OFF 0x28ULL
#define TNX_V126_BOX_PTR_OFF 0xf8ULL
#define TNX_V126_MGR_SEQ_OFF 0x14ULL

#define TNX_V127_GIDLESS 1
#define TNX_V127_ACT_SETTER 0
#define TNX_V127_ACT_ELEM 0
#define TNX_V127_DX_SETTER 600
#define TNX_V127_DX_ELEM 900
#define TNX_V127_DY_SETTER 120
#define TNX_V127_DY_ELEM 240
#define TNX_V127_READBACK_TICKS 6
#define TNX_V127_READBACK_LOGS 8
#define TNX_V127_FRAME_EVERY 2
#define TNX_V127_SETFLAG 1
#define TNX_V127_OWN_ALIVE_OFF 0x140ULL
#define TNX_V127_GATE_FLAG_OFF 0xacULL
#define TNX_V127_GATE_X_OFF 0x10cULL
#define TNX_V127_GATE_Y_OFF 0x110ULL

#define TNX_V128_POS_BONUS 8
#define TNX_V128_DIST_BONUS 6
#define TNX_V128_SOFT_BASE 2
#define TNX_V128_SOFT_MIN_POS 2
#define TNX_V128_SOFT_MIN_DIST 2
#define TNX_V128_RAW_X 900
#define TNX_V128_RAW_Y -300
#define TNX_V128_CTRL_RAW_X_OFF 0xfa4ULL
#define TNX_V128_CTRL_RAW_Y_OFF 0xfa8ULL
#define TNX_V128_CTRL_DIRTY_OFF 0xfa0ULL
#define TNX_V128_CTRL_ALIVE_OFF 0xf80ULL
#define TNX_V128_CTRL_ID_OFF 0xf84ULL
#define TNX_V128_CTRL_GATE_OFF 0xf9eULL
#define TNX_V128_CTRL_APPLIED_X_OFF 0xfccULL
#define TNX_V128_CTRL_APPLIED_Y_OFF 0xfd0ULL
#define TNX_V128_ACT_LOGS 8
#define TNX_V128_WIT_LOGS 24
#define TNX_V128_OWN_LOGS 8

#define TNX_V129_MODE 1
#define TNX_V129_MODE_CHAIN 0
#define TNX_V129_MODE_WRITE 1
#define TNX_V129_MODE_SETTER 2
#define TNX_V129_MODE_BOTH 3
#define TNX_V129_DX 30
#define TNX_V129_DY 9
#define TNX_V129_BATTLE_RVA 0x1123b48ULL
#define TNX_V129_OWN_EXPECT_GID 1000001
#define TNX_V129_CHAIN_LOGS 8
#define TNX_V129_ASCII_LOGS 6

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
#define TNX_V116_HIST_LOGS 60

#define TNX_OBJ_TEAM_OFF 0x40ULL
#define TNX_OBJ_OWNERINDEX_OFF 0x3cULL
#define TNX_OBJ_DEADFLAG_OFF 0xd0ULL

#define TNX_OBJ_TEAM_MAX 7

#define TNX_MODE_MODEVAR_OFF 0x124ULL

#define TNX_MODE_PREDICTX_OFF 0x1d4ULL
#define TNX_MODE_PREDICTY_OFF 0x1d8ULL
#define TNX_MODE_SLOT_A 0x218ULL
#define TNX_MODE_SLOT_B 0x220ULL
#define TNX_MODE_SLOT_C 0x228ULL

#define TNX_SLOT_BRIDGE_OFF 0x8ULL

#define TNX_SLOT_OWNER_OFF 0x20ULL
#define TNX_SLOT_LIST_OFF 0x80ULL
#define TNX_SLOT_LISTCOUNT_OFF 0x8cULL

#define TNX_BUILD_TAG "titanox_155"

#define TNX_V155_PROGRESS 20.0f
#define TNX_V155_STALL_TICKS 10
#define TNX_V155_BLOCK_TICKS 90
#define TNX_V155_BLOCK_WIDTH 0.16f
#define TNX_V155_MAX_DIST 900.0f
#define TNX_V155_LOGS 24


#define TNX_V154_STEP 150.0f
#define TNX_V154_MAX_DIST 1500.0f
#define TNX_V154_ANGLES 24
#define TNX_V154_INFLATE 300.0f
#define TNX_V154_ARRIVE 40.0f
#define TNX_V154_LOGS 24


#define TNX_V153_THREAT_TICKS 40
#define TNX_V153_EXIT_DIST 520.0f
#define TNX_V153_LOGS 24


#define TNX_V151_THREAT_MIN_MS 0
#define TNX_V151_THREAT_STEP_MULT 1.5f
#define TNX_V151_LOGS 24


#define TNX_V150_ACT_WRITE 1

#define TNX_V147_ACT_WRITE 0
#define TNX_V148_PROBE_LOGS 6

 

















#define TNX_V145_PUB_LOGS 10

 




















#define TNX_V144_MIN_OBJ_BYTES 0x118ULL
#define TNX_V144_CAND_LOGS 12

 










 












#define TNX_V142_WALK_ABORT_FULL 5
#define TNX_V142_WALK_ABORT_EVERY 64

 
















#define TNX_V141_ARRAY_VOTE_LOGS 8

 







#define TNX_V140_MODEPAIR_RVA 0x00ac3a58ULL
#define TNX_V140_MODEPAIR_FLAG 0
#define TNX_V140_CTRL_MODE_OFF 0x918ULL
#define TNX_V140_PROJ_MAX 8
#define TNX_V140_DUMPS 3
#define TNX_V140_DIFF_BYTES 0x100
#define TNX_V140_DIFF_LOGS 48
#define TNX_V140_SIDE_WEIGHT 3.0f
#define TNX_V140_THREAT_RADIUS 260.0f
#define TNX_V140_THREAT_TICKS 12.0f
#define TNX_V140_SIDE_LOGS 24
#define TNX_V140_WRITE_LOGS 24

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
#define TNX_V89_WALK_EVERY 5
#define TNX_V90_SLOTS 3
#define TNX_V91_TEAM_OFF 0x4cULL
#define TNX_V91_DEAD_OFF 0xd4ULL
#define TNX_V99_SCAN_QWORDS 512
#define TNX_V99_SCAN_BASES 3

static void tnx_v103_state_note(int state);

static uintptr_t g_v103_mgr = 0;
static int g_v103_mgr_logs = 0;
static int g_v103_test_state = 0;
static int g_v103_test_after_x = 0;
static int g_v103_test_after_y = 0;
static int g_v103_moved = 0;
static int g_v103_moved2 = 0;
static int g_v103_kept = 0;
static int g_v103_tested = 0;
static int g_v103_ok = 0;
static uint64_t g_v103_writes = 0;
static uint64_t g_v103_tick = 0;
static uint64_t g_v138_dodge_calls = 0;
static uint64_t g_v138_render_calls = 0;
static int g_v138_dump_np = 0;
static uintptr_t g_v138_prev_scene = 0;
static int g_v103_attempt = 0;
static int g_v103_prev_state = -1;
static int g_v103_other_logs = 0;
static int g_v103_other_detail = 0;


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
static int g_v101_own_logs = 0;
static int g_v101_wide_runs = 0;
static int g_v101_miss_logs = 0;
static const char *g_v101_own_from = "none";

#define TNX_V101_OWNIDX_OFF 0xe0ULL
#define TNX_V101_OWNTEAM_OFF 0xe4ULL
#define TNX_V101_ELEM_ID_OFF 0x48ULL
#define TNX_V101_ELEM_TEAM_OFF 0x4cULL
#define TNX_V101_MODEPAIRSET_RVA 0xac3a58ULL
#define TNX_V101_OWN_LOGS 12
#define TNX_V101_ACTUATOR 0
#define TNX_V99_INPUTMGR_WRITE 0
#define TNX_V99_INPUTMGR_COS_OFF 0x8ULL
#define TNX_V99_INPUTMGR_SIN_OFF 0xcULL
#define TNX_V99_INPUTMGR_WRITE_X 0.7071
#define TNX_V99_INPUTMGR_WRITE_Y 0.7071
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
#define TNX_V97_MOVE_MAX 96
#define TNX_V97_GROUP_GAP 1
#define TNX_V97_QUIET 8
#define TNX_V97_GROUPS_MAXLEN 8
#define TNX_V97_COSSIN_TOL 0.05f
#define TNX_V98_FORCE_SECS 30
#define TNX_V98_CLIP_SELFTEST 1
#define TNX_V98_GRID 8
#define TNX_V85_FIELD_SCANS 1


#define TNX_V57_REJECT_MAX 8

#define TNX_V59_SLOT_WIDE 100
#define TNX_V59_DROP_TICKS 60
#define TNX_V59_TAG_MAX 24

#define TNX_V60_IMAGE_SPAN 0x1164000ULL


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
#define TNX_V79_OBJ_SLOTS 3
#define TNX_V79_KIND_OFF 0x35cULL
#define TNX_V80_STATE_RVA 0x1123e58ULL
#define TNX_V80_STATE_ENUM_OFF 0x50ULL
#define TNX_V80_SCENE_OFF 0x48ULL
#define TNX_V80_STATE_BATTLE 5

#define TNX_V81_SCENE_CLASS_RVA 0xfe9d00ULL
#define TNX_V81_PLAYERS_NEXT_OFF 0xf8ULL
#define TNX_V81_NEXT_MEMBER_OFF 0x68ULL
#define TNX_V81_DUMP_QWORDS 32
#define TNX_V81_VT_MAX 24
#define TNX_V81_PLAYERS_DUMPS 4

#define TNX_V82_CLIENT_HOP_OFF 0x28ULL
#define TNX_V82_ELEM_DEF_OFF 0x10ULL
#define TNX_V82_HOPS 2
#define TNX_V82_HOP_DUMPS 4
#define TNX_V68_PENDING_MAX 8
#define TNX_V71_ARRAY_PROBE 8
#define TNX_V71_ARRAY_MIN_OBJS 2

#define TNX_V75_ASCII_WINDOW 32
#define TNX_V75_ASCII_RATIO 30
#define TNX_V75_TEAM_MAX 15
#define TNX_V75_GID_MAX 10000000
#define TNX_V75_GID_FLOOR 1000000
#define TNX_V75_COORD_MAX 100000


#define TNX_V134_HIST_MAX 8
#define TNX_V134_V70_OFF 0x70ULL
#define TNX_V134_OWN_LOGS 6
#define TNX_V134_ALERT_GAP_MS 20000
#define TNX_V135_OWN_LOGS 6
#define TNX_V138_PLAYER_GID_MAX 2000000
#define TNX_V138_CENSUS_MS 30000
#define TNX_V138_CALL_LOGS 4
#define TNX_V138_CALL_EVERY 600
#define TNX_V138_NP_DUMPS 8
#define TNX_V138_NP_PTR_OFF 0x38ULL
#define TNX_V135_GIDOFF_LOGS 6
#define TNX_V134_CENSUS_DELTA 5

#define TNX_V73_STATE_DROPPED (-2)




#define TNX_AG_OBJECT_MAX 16


#define TNX_VOTESCAN_GLOBAL_EVERY 10

#define TNX_MODE_MIN_TYPES 2
#define TNX_MODE_TYPE_MAX 16

#define TNX_SNAPSHOT_DELAY 1.2
#define TNX_VOTESCAN_INTERVAL 1.0
#define TNX_VOTESCAN_ATTEMPTS 600

#define TNX_HEAP_SCAN_BUDGET (512ull * 1024ull * 1024ull)

#define TNX_VOTESCAN_HEAP_EVERY 5

#define TNX_MODE_MIN_OBJECTS 3
#define TNX_VOTESCAN_HEARTBEAT 30

#define TNX_VTABLE_SEGMENT "__DATA_CONST"
#define TNX_VTABLE_SEGMENT_ALT "__DATA"

static const uintptr_t g_mode_vtables_verified[] = { 0x1002548, 0xff5720, 0 };


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

static int g_chain_checks = 0;
static int g_chain_probes = 0;
static int g_chain_skipped = 0;
static int g_chain_best_own = 0;
static int g_chain_best_gid = 0;
static int g_seen_stable = 0;
static unsigned long long g_vtprobe_hits[TNX_VTPROBE_COUNT];

static int g_owner_vote_count = 0;
static unsigned long long g_objvote_hits = 0;
static unsigned long long g_objvote_skipped = 0;
static int g_objvote_dead_seen = 0;
static uintptr_t g_objvote_best_owner = 0;
static int g_objvote_best_gids = 0;
static int g_objvote_confirm = 0;
static BOOL g_objvote_owner_ok = NO;

static unsigned long long g_objvote_owner_img = 0;
static unsigned long long g_objvote_obj_img = 0;
static int g_objvote_best_teamcount = 0;
static int g_objvote_best_gids_full = 0;

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
static unsigned long long g_objvote_owner_reg = 0;

static unsigned long long g_objvote_owner_above_win = 0;
static int g_objvote_max_votes = 0;

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

static unsigned long long g_vtprobe_pass[TNX_VTPROBE_COUNT];
static uintptr_t g_vtprobe_first[TNX_VTPROBE_COUNT];

static int g_heap_big_skip = 0;
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
static int g_scan_sig[2] = { -1, -1 };
static uintptr_t g_mode_source = 0;
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

 










static char g_v146_phase[48] = "boot";
static char g_v146_hist[8][48];
static volatile int g_v146_hist_n = 0;
static volatile int g_v146_fd = -1;
static volatile uint64_t g_v146_stage_ticks = 0;
static int g_v146_installed = 0;

static void tnx_v146_phase(const char *p) {
    int n;

    if (!p) return;

    strncpy(g_v146_phase, p, sizeof(g_v146_phase) - 1);
    g_v146_phase[sizeof(g_v146_phase) - 1] = '\0';

    n = g_v146_hist_n;

    if (n < 0) n = 0;
    if (n > 7) n = 7;

    strncpy(g_v146_hist[n], p, sizeof(g_v146_hist[0]) - 1);
    g_v146_hist[n][sizeof(g_v146_hist[0]) - 1] = '\0';

    g_v146_hist_n = (n + 1) & 7;
    g_v146_stage_ticks++;

    if (g_v146_fd < 0) {
        FILE *h = tnx_log_handle();

        if (h) g_v146_fd = fileno(h);
    }
}

static void tnx_v146_crash(int sig, siginfo_t *info, void *ctx) {
    char buf[768];
    void *fault = (info && info->si_addr) ? info->si_addr : (void *)0;
    int n;

    (void)ctx;

    n = snprintf(buf, sizeof(buf),
                 "\n[CRASH] sig=%d fault=%p phase=%s stages=%llu h0=%s h1=%s h2=%s h3=%s "
                 "h4=%s h5=%s h6=%s h7=%s - phase is the stage that was running when the "
                 "signal arrived, the rest are the stages before it in arrival order, and this "
                 "line is written with write(2) so the log cap cannot drop it\n",
                 sig, fault, g_v146_phase, (unsigned long long)g_v146_stage_ticks,
                 g_v146_hist[0], g_v146_hist[1], g_v146_hist[2], g_v146_hist[3],
                 g_v146_hist[4], g_v146_hist[5], g_v146_hist[6], g_v146_hist[7]);

    if (n > 0 && g_v146_fd >= 0) {
        ssize_t ignored = write((int)g_v146_fd, buf, (size_t)n);

        (void)ignored;
    }

    signal(sig, SIG_DFL);
    raise(sig);
}

static void tnx_v146_install(void) {
    struct sigaction sa;
    int sigs[5] = { SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE };
    FILE *h = tnx_log_handle();
    int i;

    if (g_v146_installed) return;

    g_v146_installed = 1;

    if (h) g_v146_fd = fileno(h);

    memset(&sa, 0, sizeof(sa));

    sa.sa_sigaction = tnx_v146_crash;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;

    sigemptyset(&sa.sa_mask);

    for (i = 0; i < 5; i++) sigaction(sigs[i], &sa, NULL);

    tnx_logf("v146 crash locator armed fd=%d sigs=5 - the next signal writes the running stage "
             "and the eight before it to that descriptor, so a crash names itself instead of "
             "ending the log", (int)g_v146_fd);
}

#define TNX_SLOT_COUNT 32
#define TNX_ALERT_SIGHTINGS 2

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

static int g_v55_chain_rej[20] = { 0 };
static int g_v55_chain_probes_pass = 0;
static int g_v55_layout_logs = 0;
static int g_v54_no_source_passes = 0;
static int g_v54_route_logged = 0;
static uint64_t g_v52_setpred_calls = 0;
static uintptr_t g_v52_setpred_this = 0;
static float g_v52_setpred_x = 0.0f;
static float g_v52_setpred_y = 0.0f;
static uint64_t g_v52_ascii_rejected = 0;
static uint32_t g_slot_reported_mask = 0;
static uint64_t g_slot_first_tick[TNX_SLOT_COUNT] = { 0 };
static uint32_t g_v50_never_dispatched_mask = 0;

static uint64_t g_v50_ticks = 0;
static uintptr_t g_slot_adopted = 0;
static int g_ag_adopted = 0;

static int32_t g_v56_enemy_x[TNX_V56_COUNT_MAX] = { 0 };
static int32_t g_v56_enemy_y[TNX_V56_COUNT_MAX] = { 0 };

static uintptr_t g_v57_rejected[TNX_V57_REJECT_MAX] = { 0 };
static int g_v57_coord_off = -1;
static int g_v59_chain_hits = 0;
static uintptr_t g_v59_reject_vts[TNX_V59_REJECT_VTS] = { 0 };
static int g_v59_mode_from_chain = 0;
static int g_v59_idle_probe_logged = 0;
static uintptr_t g_v59_last_cand = 0;
static uintptr_t g_v59_last_vt = 0;
static char g_v59_last_why[96] = { 0 };
static char g_v59_drop_tags[TNX_V59_TAG_MAX][8];
static char g_v59_keep_tags[TNX_V59_TAG_MAX][8];
static int g_v64_modesig_hits = 0;
static int g_v64_modesig_notfound = 0;
static int g_v65_sig_ticks = 0;
static int g_v65_sig_logs = 0;
static uintptr_t g_v65_sig_last = 0;
static int g_v67_rejected_tick[TNX_V57_REJECT_MAX] = { 0 };
static int g_v67_layout_used = 0xc;
static int g_v67_layout_logs = 0;
static uintptr_t g_v68_pending[TNX_V68_PENDING_MAX] = { 0 };
static int g_v68_pending_tick[TNX_V68_PENDING_MAX] = { 0 };
static int g_v68_probe_logs = 0;
static int g_v68_gate_logs = 0;
static int g_v68_dump_logs = 0;
static int g_v71_pending_attempts[TNX_V68_PENDING_MAX] = { 0 };
static int g_v71_array_reject_logs = 0;
static int g_v72_trail_refusals = 0;
static int g_v75_ascii_refused = 0;
static int g_v75_best_wait_logs = 0;
static int g_v76_floor_logged = 0;
static int g_v76_fallback_logged = 0;
static int g_v77_live_objs = 0;
static int g_v77_live_teams = 0;
static int g_v77_fb_on = 0;
static int g_v77_fb_logged = 0;
static int g_v77_bar_logged = 0;
static unsigned g_v77_vt_text_rejects = 0;
static unsigned long long g_v79_obj_prev = 0;
static uintptr_t g_v80_site = 0;
static int g_v80_state = -1;
static int g_v80_scan_armed = -1;
static uintptr_t g_players_array = 0;

static int g_players_count = 0;
static int g_players_cap = 0;

 









static volatile uint32_t g_v142_seq = 0;
static uintptr_t g_v142_pub_object = 0;
static uintptr_t g_v142_pub_array = 0;
static int32_t g_v142_pub_count = 0;
static int32_t g_v142_pub_cap = 0;
static int g_v142_pub_logs = 0;

static uintptr_t g_v142_tick_object = 0;
static uintptr_t g_v142_tick_array = 0;
static int32_t g_v142_tick_count = 0;
static uint64_t g_v142_tick_stamp = 0;
static uint64_t g_v142_tick_logs = 0;
static int g_v142_score_logs = 0;
static uint64_t g_v142_walk_aborts = 0;

static void tnx_v142_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap,
                             const char *why) {
    __sync_synchronize();

    g_v142_seq++;

    __sync_synchronize();

    g_v142_pub_object = object;
    g_v142_pub_array = array;
    g_v142_pub_count = count;
    g_v142_pub_cap = cap;

    g_players_object = object;
    g_players_array = array;
    g_players_count = count;
    g_players_cap = cap;

    __sync_synchronize();

    g_v142_seq++;

    __sync_synchronize();

    if (g_v142_pub_logs < 12) {
        g_v142_pub_logs++;

        tnx_logf("v142 publish why=%s object=%p array=%p count=%d cap=%d seq=%u - the whole triple "
                 "moves under one sequence, so no reader can take the new array with the old "
                 "count", why ? why : "?", (void *)object, (void *)array, count, cap,
                 (unsigned)g_v142_seq);
    }
}

static int tnx_v142_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut) {
    int tries;

    for (tries = 0; tries < 8; tries++) {
        uint32_t s1 = g_v142_seq;
        uintptr_t o;
        uintptr_t a;
        int32_t c;

        if (s1 & 1u) continue;

        o = g_v142_pub_object;
        a = g_v142_pub_array;
        c = g_v142_pub_count;

        __sync_synchronize();

        if (g_v142_seq != s1) continue;

        if (objectOut) *objectOut = o;
        if (arrayOut) *arrayOut = a;
        if (countOut) *countOut = c;

        return 1;
    }

    return 0;
}

static void tnx_v142_tick_begin(const char *phase) {
    uintptr_t o = 0;
    uintptr_t a = 0;
    int32_t c = 0;

    if (!tnx_v142_snapshot(&o, &a, &c)) return;

    g_v142_tick_object = o;
    g_v142_tick_array = a;
    g_v142_tick_count = c;
    g_v142_tick_stamp++;

    if (g_v142_tick_logs < 12) {
        g_v142_tick_logs++;

        tnx_logf("v142 tick enter phase=%s object=%p array=%p count=%d stamp=%llu - the snapshot is "
                 "taken before any stage reads it and is what the walk, the census and the "
                 "resolver all use, so a publish from the scan timer cannot split them",
                 phase ? phase : "?", (void *)o, (void *)a, c,
                 (unsigned long long)g_v142_tick_stamp);
    }
}
static int g_v81_census_logs = 0;
static int g_v85_field_scans = 0;
static int g_v86_elem_dumps = 0;
static int g_v86_hop2_census = 0;
static int g_v86_type3_floats = 0;
static uintptr_t g_v134_census_container = 0;
static int32_t g_v134_census_count = 0;
static uintptr_t g_v134_census_array = 0;
static uintptr_t g_v134_census_first = 0;
static uint64_t g_v134_census_ms = 0;
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
static int g_v97_pos_x[TNX_V97_MOVE_MAX];
static int g_v97_pos_y[TNX_V97_MOVE_MAX];
static int g_v98_clip_pass = 0;
static int g_v98_clip_fail = 0;
static uint64_t g_v99_inputmgr_writes = 0;
static uint64_t g_v99_inputmgr_last_tick = 0;
static const char *g_v91_own_from = "none";
static int g_v81_players_dumps = 0;
static int g_v82_hop_dumps = 0;
static uintptr_t g_v81_vt_seen[TNX_V81_VT_MAX] = { 0 };
static int g_v81_vt_live[TNX_V81_VT_MAX] = { 0 };
static uint64_t g_v78_idle_start = 0;
static int g_v78_idle_on = 0;
static int g_v78_idle_logged = 0;
static int g_v78_idle_skips = 0;
static int g_v71_modehit_dump = 0;
static int g_v62_class_pass = 0;
static int g_v62_alerts_off = 0;
static const char *g_v62_mode_source = "none";
static const uintptr_t g_v63_known_vt[TNX_V63_KNOWN_VT_COUNT] = { 0xf924d0ULL, 0xf92538ULL,
                                                                  0xf92808ULL, 0xf92898ULL };
static int g_v63_hb_sig_prev = 0;
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

static void tnx_slot_diag(const char *why);
static void tnx_slot_fired_report(void);
static void tnx_v99_inputmgr_probe(void);
static const char *tnx_v57_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut);
static uint64_t tnx_v79_object_dispatches(void);
static BOOL tnx_heap_resident(uintptr_t value);
static int tnx_v80_state_tick(void);
static void tnx_v81_players_dump(uintptr_t players, uintptr_t array, int32_t count,
                                 int32_t capacity);
static void tnx_v81_container_census(uintptr_t array, int32_t count, uintptr_t container);
static int tnx_v82_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut,
                                    int32_t *capOut, char *why, size_t whyLen);
static void tnx_v82_hop_dump(uintptr_t client, uintptr_t inner);
static char tnx_v72_seg_code(uintptr_t value);
static const char *tnx_image_segment_name(uintptr_t value);
static void tnx_v62_alert_menu(NSString *info);
static NSString *tnx_v132_status_text(void);
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
static int tnx_v68_container_gate(uintptr_t manager, uintptr_t *containerOut,
                                  int32_t *countOut, int32_t *capOut, char *why,
                                  size_t whyLen);
static uint64_t tnx_v68_word(uintptr_t address);
static void tnx_v68_multiteam_dump(uintptr_t owner, uint32_t teamMask,
                                   int teamCount);
static int tnx_v71_array_probe(uintptr_t array, int32_t count, char *why, size_t whyLen);
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

static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty, int ascii, int sampled, int noVt, int teamDistinct,
                           int posDistinct, int refused);
static void tnx_trail_dump(void);

static void tnx_report_manager(const char *tag, uintptr_t manager);

static void tnx_autododge_v48(void);

static void tnx_slot_note(int index, void *self, uint64_t arg1) {
    uint32_t bit = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_first_tick[index]) g_slot_first_tick[index] = g_v50_ticks;

    if (!g_slot_object[index] && self) g_slot_object[index] = (uintptr_t)self;

    if (!g_slot_arg1[index] && arg1) g_slot_arg1[index] = (uintptr_t)arg1;

    bit = (uint32_t)(1u << (unsigned)index);

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

    { "B1/off-vt0ff5720-no-data-slot", "B1", 0, 0, tnx_slot_repl_2, 0 },

    { "B2/off-vt0ff5720-no-data-slot", "B2", 0, 0, tnx_slot_repl_3, 0 },
    { "B3/off-vt0ff5720-no-data-slot", "B3", 0, 0, tnx_slot_repl_4, 0 },

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

            }
        }
    }


    tnx_logf("v100 hooks total fired=%llu armed=%d of %d slots at tick=%llu", (unsigned long long)total,
             armedCount, TNX_SLOT_COUNT, (unsigned long long)g_v50_ticks);

    tnx_logf("v100 trail refusals: stringy=%d image-resident=%d - the two counters replace the line "
             "that printed on every tenth refusal and flooded the v72 log with 964 of them; the "
             "denominator is the candidate count already printed on the trail line",
             g_v63_stringy_logs, g_v72_trail_refusals);
}

static int g_ag_installed = -1;
static uint64_t g_ag_hits = 0;
static uintptr_t g_ag_manager = 0;
static uintptr_t g_ag_objects[TNX_AG_OBJECT_MAX] = { 0 };
static int g_ag_objectCount = 0;





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
            [UIAlertController alertControllerWithTitle:@"Titanox"
                                                message:text
                                         preferredStyle:UIAlertControllerStyleAlert];

        [menu addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Состояние"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            tnx_v62_alert_menu(tnx_v132_status_text());
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


        if (count >= 2 && cap >= count && cap <= TNX_MGR_CAP_MAX) {
            void *mgrArray = NULL;

            g_manager_count = count;

             





            if (tnx_read_ptr((uintptr_t)mgr + TNX_MGR_ARRAY_OFF, &mgrArray) && mgrArray) {
                tnx_v142_publish((uintptr_t)mgr, (uintptr_t)mgrArray, count, cap, "modesig");
            }

            tnx_logf("v142 modesig container obj=%p mgr=%p array=%p count=%d cap=%d src=SIG - read "
                     "and published as one tuple under the seqlock, or not at all",
                     (void *)found, mgr, mgrArray, count, cap);
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




static int32_t g_v132_gid_lo = 0;
static int32_t g_v132_gid_hi = 0;
static uintptr_t g_v132_alert_scene = 0;
static uint64_t g_v132_alert_ms = 0;



static void tnx_v132_battle_alert(uintptr_t scene, uintptr_t scenePrev) {
    uint64_t now = 0;

    if (!scene) return;
    if (g_v62_alerts_off) return;
    if (scene == g_v132_alert_scene) return;

    now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

    if (g_v132_alert_ms && now - g_v132_alert_ms < TNX_V134_ALERT_GAP_MS) {
        tnx_logf("v135 alert withheld prev=%p now=%p sinceMs=%llu nowMs=%llu gapMs=%d - the alert "
                 "call moved off the container change and onto the scene edge, because the v134 run "
                 "showed the menu ten times in ten seconds while the scene pointer in the heartbeat "
                 "never moved: the call sat in the container-change block, so every hop flip looked "
                 "like a battle entry; prev and now are printed so a real repeat is distinguishable "
                 "from the old misfire",
                 (void *)scenePrev, (void *)scene, (unsigned long long)g_v132_alert_ms,
                 (unsigned long long)now, TNX_V134_ALERT_GAP_MS);

        return;
    }

    g_v132_alert_scene = scene;
    g_v132_alert_ms = now;

    tnx_logf("v138 alert shown prev=%p now=%p edgePrev=%p sinceMs=%llu gapMs=%d - printed after both "
             "gates, so the menu line that follows cannot be mistaken for a call that skipped them; "
             "edgePrev is the scene the edge detector itself last held, so a repeat that reaches this "
             "line with edgePrev equal to now is an edge misfire and not a real battle entry, which is "
             "exactly what the v137 run could not be asked",
             (void *)scenePrev, (void *)scene, (void *)g_v138_prev_scene,
             (unsigned long long)g_v132_alert_ms, TNX_V134_ALERT_GAP_MS);

    g_v138_prev_scene = scene;

    tnx_v62_alert_menu([NSString stringWithFormat:
        @"Вход в бой\nscene=%p (было %p)\ncontainer=%p count=%d\ngid=%d..%d\nown=min gid",
        (void *)scene, (void *)scenePrev, (void *)g_players_object, g_players_count,
        g_v132_gid_lo, g_v132_gid_hi]);
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
    uintptr_t histRva[TNX_V134_HIST_MAX];
    uintptr_t histWord[TNX_V134_HIST_MAX];
    int histCount[TNX_V134_HIST_MAX];
    int histN = 0;
    int32_t v70lo = 0;
    int32_t v70hi = 0;
    int v70n = 0;
    char histText[768];
    int h = 0;

    if (!array || count <= 0) return;

    {
        void *firstPtr = NULL;
        uintptr_t first = 0;
        uint64_t nowMs = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        int same = (container == g_v134_census_container &&
                    (uintptr_t)array == g_v134_census_array);
        int firstChanged = 0;

        if (tnx_read_ptr(array, &firstPtr) && firstPtr) first = (uintptr_t)firstPtr;
        firstChanged = (first != g_v134_census_first);

        if (same && !firstChanged && g_v134_census_ms &&
            nowMs - g_v134_census_ms < TNX_V138_CENSUS_MS) {
            return;
        }

        if (same) {
            tnx_logf("v138 census rearmed container=%p array=%p count=%d lastCount=%d first=%p "
                     "lastFirst=%p firstChanged=%d sinceMs=%llu - the count delta rule of v135 fired "
                     "on every second of the battle because this vector is the object registry and "
                     "it grows and shrinks with projectiles, so the census printed twenty times and "
                     "the log drowned; it is now taken when the first element changes or after %d ms",
                     (void *)container, (void *)array, count, g_v134_census_count, (void *)first,
                     (void *)g_v134_census_first, firstChanged,
                     (unsigned long long)(g_v134_census_ms ? nowMs - g_v134_census_ms : 0),
                     TNX_V138_CENSUS_MS);
        }

        g_v134_census_container = container;
        g_v134_census_count = count;
        g_v134_census_array = (uintptr_t)array;
        g_v134_census_first = (uintptr_t)first;
        g_v134_census_ms = nowMs;
    }

    if (count > TNX_V81_DUMP_QWORDS) count = TNX_V81_DUMP_QWORDS;

    for (h = 0; h < TNX_V134_HIST_MAX; h++) {
        histRva[h] = 0;
        histWord[h] = 0;
        histCount[h] = 0;
    }

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

        tnx_read_ptr((uintptr_t)element, &vt);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);

        if (gid >= TNX_V75_GID_FLOOR && gid < TNX_V138_PLAYER_GID_MAX &&
            team >= 0 && team <= TNX_V75_TEAM_MAX) {
            ok = 1;
            snprintf(why, sizeof(why), "gid=%d in [%d,%d) and team=%d in range - accepted on the id "
                     "the engine itself assigns, with no definition pointer read at all",
                     gid, TNX_V75_GID_FLOOR, TNX_V75_GID_MAX, team);
        } else {
            ok = 0;
            snprintf(why, sizeof(why), "gid=%d outside [%d,%d) or team=%d outside 0..%d - refused "
                     "with no definition pointer read at all, because the v127 run showed the def "
                     "field empty at the moment the census looks at it and every element was called "
                     "unaccepted on that empty field while carrying a real id",
                     gid, TNX_V75_GID_FLOOR, TNX_V75_GID_MAX, team, TNX_V75_TEAM_MAX);
        }
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

        type = tnx_v86_element_type((uintptr_t)vt, &typeWord);

        if (type < 0) snprintf(typeText, sizeof(typeText), "unknown");
        else snprintf(typeText, sizeof(typeText), "%d", type);

        classRva = tnx_v60_strip_ptr((uintptr_t)vt) - g_base;

        if (classSeen < 0) classSeen = (int)classRva;
        else if (classSeen != (int)classRva) classSeen = -2;

        for (h = 0; h < histN; h++) {
            if (histRva[h] == classRva) break;
        }

        if (h < histN) {
            histCount[h]++;
        } else if (histN < TNX_V134_HIST_MAX) {
            histRva[histN] = classRva;
            histWord[histN] = typeWord;
            histCount[histN] = 1;
            histN++;
        }

        if (ok) {
            int32_t v70 = 0;

            if (tnx_read_i32((uintptr_t)element + TNX_V134_V70_OFF, &v70)) {
                if (v70 != 0 && v70 > -TNX_V75_COORD_MAX && v70 < TNX_V75_COORD_MAX) {
                    if (v70n == 0 || v70 < v70lo) v70lo = v70;
                    if (v70n == 0 || v70 > v70hi) v70hi = v70;
                    v70n++;
                }
            }

            if (gid > 0) {
                if (g_v132_gid_lo == 0 || gid < g_v132_gid_lo) g_v132_gid_lo = gid;
                if (gid > g_v132_gid_hi) g_v132_gid_hi = gid;
            }
        }

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

        }
    }

    g_v81_census_logs++;
    g_v134_census_container = container;

    histText[0] = 0;

    for (h = 0; h < histN; h++) {
        char one[96];
        const char *seg = tnx_image_segment_name(g_base + histRva[h]);

        snprintf(one, sizeof(one), "%s%#llx(%s)x%d word=%#llx", h ? " " : "",
                 (unsigned long long)histRva[h], seg ? seg : "-", histCount[h],
                 (unsigned long long)histWord[h]);

        strncat(histText, one, sizeof(histText) - strlen(histText) - 1);
    }

    tnx_logf("v134 classHist container=%p n=%d %s | v70=%d..%d n=%d - every class table the "
             "container holds is listed with how many elements carry it and the word its own slot "
             "+%#llx returns, because the v132 run put four elements of class 0xff56d8 with "
             "typeWord 0xa2e094 inside the player container and a single classRva of the first "
             "element could not separate them; the class is the discriminator and the team is only "
             "the second one, since the projectile class carries team -1 as well. The v70 pair is "
             "the one live offset left in the window after +%#llx/+%#llx took the coordinates: it "
             "is printed as a range over the accepted elements and is a candidate for velocity or "
             "facing, not a position",
             (void *)container, histN, histText, v70n ? v70lo : 0, v70n ? v70hi : 0, v70n,
             (unsigned long long)TNX_V86_TYPE_SLOT_OFF, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF);

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






static int g_v106_gid_logs = 0;
static int g_v106_coord_logs = 0;
static int g_v106_dump_done = 0;

static int32_t tnx_v106_gid_at(uintptr_t element, uintptr_t off) {
    int32_t gid = 0;

    if (off && tnx_read_i32(element + off, &gid)) return gid;

    return 0;
}

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

}


static int g_v105_score_logs = 0;
static int g_v105_last_choice = -2;
static int g_v105_hop_logs = 0;
static int g_v105_start_logged = 0;
static int g_v129_ascii_logs = 0;

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
    int posOk = 0;
    int posDistinct = 0;
    int asciiCount = 0;
    int soft = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t qx = 0;
    int32_t qy = 0;
    int score = 0;
    int i;
    int j;

    if (!container) return -1;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > TNX_V56_COUNT_MAX) return -1;

     




    if (own < 0 || own >= count) soft = 1;

    for (i = 0; i < count && samples < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        samples++;
        team = 0;
        px = 0;
        py = 0;

        if (tnx_v75_element_ascii((uintptr_t)element)) asciiCount++;

        gid = tnx_v106_gid((uintptr_t)element, NULL);
        tnx_read_i32((uintptr_t)element + TNX_V91_TEAM_OFF, &team);

        if (tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px) &&
            tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py) &&
            px > -TNX_V75_COORD_MAX && px < TNX_V75_COORD_MAX &&
            py > -TNX_V75_COORD_MAX && py < TNX_V75_COORD_MAX && (px != 0 || py != 0)) {
            int dup = 0;

            posOk++;

            for (j = 0; j < i; j++) {
                void *other = NULL;

                if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)j * 8ULL, &other) || !other) continue;
                if (!tnx_read_i32((uintptr_t)other + TNX_OBJ_X_OFF, &qx)) continue;
                if (!tnx_read_i32((uintptr_t)other + TNX_OBJ_Y_OFF, &qy)) continue;

                if (qx == px && qy == py) {
                    dup = 1;

                    break;
                }
            }

            if (!dup) posDistinct++;
        }

        if (gid) gidOk++;
        if (team >= 0 && team <= 7) teamOk++;
    }

    if (samples > 0 && (asciiCount * 100) / samples > TNX_V75_ASCII_RATIO) {
        if (g_v129_ascii_logs < TNX_V129_ASCII_LOGS) {
            g_v129_ascii_logs++;

            tnx_logf("v129 ascii-reject container=%p array=%p count=%d own=%d ascii=%d/%d(%d%%) "
                     "posOk=%d posDistinct=%d - the same rule the trail path applies at %#llx is "
                     "applied here before any weight, because a text container whose bytes read as an "
                     "in-range int pair at +%#llx/+%#llx would otherwise be counted as coordinates and "
                     "the soft own slot added in v128 would let it take the hop off a real list",
                     (void *)container, array, count, own, asciiCount, samples,
                     (asciiCount * 100) / samples, posOk, posDistinct,
                     (unsigned long long)TNX_V75_ASCII_RATIO, (unsigned long long)TNX_OBJ_X_OFF,
                     (unsigned long long)TNX_OBJ_Y_OFF);
        }

        return -1;
    }

    if (soft) {
        if (posOk < TNX_V128_SOFT_MIN_POS || posDistinct < TNX_V128_SOFT_MIN_DIST) {
            if (g_v105_score_logs < 12) {
                g_v105_score_logs++;

                tnx_logf("v128 score-reject container=%p array=%p count=%d own=%d posOk=%d "
                         "posDistinct=%d samples=%d - a list whose own slot at +%#llx is not an index "
                         "into its own array is refused unless it proves itself by carrying at least "
                         "%d in-range non-zero coordinate pairs of which at least %d differ; the v127 "
                         "run lost the hop exactly here, where the id list won on ids and the brawler "
                         "list that carries every real position was returned as -1 before its pairs "
                         "were ever counted",
                         (void *)container, array, count, own, posOk, posDistinct, samples,
                         (unsigned long long)TNX_V102_OWNIDX_OFF, TNX_V128_SOFT_MIN_POS,
                         TNX_V128_SOFT_MIN_DIST);
            }

            return -1;
        }

        score = TNX_V128_SOFT_BASE;
    } else {
        score = 6;

        if (ownTeam >= 0 && ownTeam <= 15) score += 2;
    }

    if (gidOk) score += 1;
    if (teamOk) score += 1;
    if (count >= 3) score += 2;
    if (count >= 6) score += 1;

    score += posOk * TNX_V128_POS_BONUS + posDistinct * TNX_V128_DIST_BONUS;

    if (g_v105_score_logs < 12) {
        g_v105_score_logs++;

        tnx_logf("v129 score container=%p array=%p count=%d own=%d ownTeam=%d soft=%d gidOk=%d "
                 "teamOk=%d posOk=%d posDistinct=%d ascii=%d/%d samples=%d score=%d - posOk counts sampled "
                 "elements whose int pair at +%#llx/+%#llx is in range and not both zero, posDistinct "
                 "counts how many of those pairs differ from every earlier one, and the pair is "
                 "weighted %d plus %d per distinct value while an id is still worth one, so a list "
                 "that carries twelve different positions cannot lose to a list that carries four "
                 "ids and reads (0,0) everywhere, which is the exact tie the v127 run lost",
                 (void *)container, array, count, own, ownTeam, soft, gidOk, teamOk, posOk, posDistinct,
                 asciiCount, samples, samples, score, (unsigned long long)TNX_OBJ_X_OFF,
                 (unsigned long long)TNX_OBJ_Y_OFF, TNX_V128_POS_BONUS, TNX_V128_DIST_BONUS);
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

static NSString *tnx_v132_status_text(void) {
    return [NSString stringWithFormat:
        @"scene=%p\ncontainer=%p count=%d hop=%d\narray=%p cap=%d\ngid=%d..%d live=%d\n"
        @"slots=%d alerts=%s",
        (void *)g_scene_object, (void *)g_players_object, g_players_count, g_v105_last_choice,
        (void *)g_players_array, g_players_cap, g_v132_gid_lo, g_v132_gid_hi, g_manager_last_live,
        TNX_SLOT_COUNT, g_v62_alerts_off ? @"выкл" : @"вкл"];
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

    }

    if (!slot) return 0;

    if (state != TNX_V80_STATE_BATTLE) {

        return 0;
    }

    if (!tnx_read_ptr(slot + TNX_V80_SCENE_OFF, &value) || !value) return 0;

    scene = (uintptr_t)value;

    if (scene != g_scene_object) {
        uintptr_t scenePrev = g_scene_object;

        g_scene_object = scene;
        tnx_v132_battle_alert(scene, scenePrev);

        tnx_logf("v100 scene=%p from slot+%#llx at state=%d - the screen factory 0x8ce048 builds "
                 "state %d as new(0x98) plus the constructor 0x8c51f8, which stores %#llx at [+0], "
                 "so this object IS the battle screen and its own slot +0xb0 logs \"No battle "
                 "client\" when [+%#llx] is null; the client is therefore scene+%#llx, one hop "
                 "above the object container",
                 (void *)scene, (unsigned long long)TNX_V80_SCENE_OFF, state,
                 TNX_V80_STATE_BATTLE, (unsigned long long)TNX_V81_SCENE_CLASS_RVA,
                 (unsigned long long)TNX_MODE_MANAGER_OFF,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);

    }

    if (!tnx_read_ptr(scene + TNX_MODE_MANAGER_OFF, &value) || !value) {
        tnx_logf("v100 scene+%#llx holds no battle client at state=%d - the pointer is read again "
                 "next tick and the scene is kept, because the engine's global is the authority "
                 "and a null here is a not-yet-filled field, not a wrong scene",
                 (unsigned long long)TNX_MODE_MANAGER_OFF, state);


        return 1;
    }

    client = (uintptr_t)value;

    if (!tnx_read_ptr(client + TNX_V82_CLIENT_HOP_OFF, &value) || !value) {
        tnx_logf("v100 client=%p carries no pointer at +%#llx yet - that field is what "
                 "findOwningTeam 0xac3ddc dereferences before it walks anything, so the second "
                 "hop is retried next tick rather than filled in from the client's own fields",
                 (void *)client, (unsigned long long)TNX_V82_CLIENT_HOP_OFF);


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

    }

    if (g_v103_tick < 4 || (g_v103_tick % 90) == 0) {
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

    {
        static int v141_array_vote_logs = 0;

        if ((uintptr_t)array != g_v142_pub_array && (uintptr_t)players == g_v142_pub_object &&
            v141_array_vote_logs < TNX_V141_ARRAY_VOTE_LOGS) {
            v141_array_vote_logs++;

            tnx_logf("v141 array moved without the container container=%p hop=%d oldArray=%p "
                     "newArray=%p count=%d - the pair is republished on the array alone, because "
                     "the container can stay equal while the engine reallocates or swaps the "
                     "list, and that difference is what made the resolver read a foreign array",
                     (void *)players, chosen, (void *)g_v142_pub_array, array, count);
        }
    }

    if ((uintptr_t)players != g_v142_pub_object || (uintptr_t)array != g_v142_pub_array ||
        count != g_v142_pub_count) {
        tnx_v142_publish((uintptr_t)players, (uintptr_t)array, count, capacity, "hop-adopt");

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

        if (g_v82_hop_chosen == 1) {
            if (!g_v86_hop2_census && players != g_v134_census_container) {
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

        tnx_v132_battle_alert(g_scene_object, 0);
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
        tnx_v99_inputmgr_probe();

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

static void tnx_run_workload(void) {
     



    tnx_v142_tick_begin("pre-locate");

    tnx_v146_phase("locate");

    tnx_locate_battle_mode();

     

    tnx_v142_tick_begin("post-locate");

    if (g_scene_object) {
        if (!g_snapshot_first) {
            g_snapshot_first = YES;
            g_snapshot_start = CFAbsoluteTimeGetCurrent();
        } else if (!g_snapshot_second) {
            if (CFAbsoluteTimeGetCurrent() > (g_snapshot_start + TNX_SNAPSHOT_DELAY)) {
                g_snapshot_second = YES;
            }
        }
    }

    tnx_v146_phase("autododge");
    tnx_run_autododge();
    tnx_v146_phase("autoaim");
    tnx_run_autoaim();
    tnx_v146_phase("watermark");
    tnx_render_watermark();
    tnx_v146_phase("overlay");
    tnx_overlay_update();

    tnx_v146_phase("alert");
    tnx_alert_battle_check();

    tnx_v146_phase("tick-end");
}

static void tnx_objc_rep0(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    g_v138_render_calls++;

    if (hook) hook->hits++;

    if (g_v138_render_calls <= TNX_V138_CALL_LOGS ||
        (g_v138_render_calls % TNX_V138_CALL_EVERY) == 0) {
        tnx_logf("v141 render CALLED n=%llu self=%p hook=%p wanted=%d targets=%d inHook=%d "
                 "base=%p scene=%p - the workload runs on exactly this condition, so hook=0 or "
                 "targets=0 is the whole reason a dodge line does not exist; inHook is read "
                 "before it is set and is 0 on the outermost call by construction, it is not the "
                 "gate; the v138 line above ",
                 (unsigned long long)g_v138_render_calls, (__bridge void *)self, (void *)hook,
                 hook ? hook->wantedCount : -1, tnx_objc_targets(self, hook) ? 1 : 0,
                 g_inside_hook, (void *)g_base, (void *)g_scene_object);

        tnx_logf("v138 render CALLED n=%llu self=%p inHook=%d base=%p scene=%p - the dodge is driven "
                 "from this callback and nothing else, so this line is the first thing to check when "
                 "the dodge prints nothing: if it is absent the whole workload is never entered and "
                 "the state has nothing to do with the dodge's own gates",
                 (unsigned long long)g_v138_render_calls, (__bridge void *)self, g_inside_hook, (void *)g_base,
                 (void *)g_scene_object);
    }

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

         





        g_objc_hooks[i].wanted[0] = owner;
        g_objc_hooks[i].wantedCount = 1;


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


    }


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

}

#define TNX_OBJECT_DETAIL_MAX 8
#define TNX_TRAIL_MAX 8

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



typedef void (*tnx_v47_setpred_t)(void *self, int x, int y);

typedef struct {
    uintptr_t object;
    int32_t   gid;
    int32_t   x;
    int32_t   y;
    int32_t   ownerIndex;
    int32_t   teamOld;
    int32_t   teamNew;
    int32_t   typeWord;
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
static uint64_t g_v135_probe_tick = 0;
static tnx_v47_obj_t g_dodge_probe_list[TNX_V47_OBJECT_MAX];
static int g_dodge_probe_usable = 0;
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
    int rejNonPlayer;
    int rejOutOfRange;
    int rejTeamMissing;
    int deadSeen;
} tnx_v50_reject_t;

static tnx_v50_reject_t g_v50_reject;

static const char *tnx_v50_reject_text(char *buf, size_t size) {
    snprintf(buf, size,
             "elements=%d rejNull=%d rejUnreadable=%d rejAscii=%d rejNoVt=%d rejGidZero=%d "
             "rejNonPlayer=%d rejOutOfRange=%d rejTeamMissing=%d deadSeen=%d",
             g_v50_reject.elementsRead, g_v50_reject.rejNull, g_v50_reject.rejUnreadable,
             g_v50_reject.rejAscii, g_v50_reject.rejNoVt, g_v50_reject.rejGidZero,
             g_v50_reject.rejNonPlayer,
             g_v50_reject.rejOutOfRange, g_v50_reject.rejTeamMissing, g_v50_reject.deadSeen);

    return buf;
}

static int g_v127_gidless = 0;
static int g_v127_gidless_logs = 0;

static void tnx_v127_gidless_scan(uintptr_t manager) {
    void *data = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int seen = 0;
    int withGid = 0;

    g_v127_gidless = 0;

    if (!TNX_V127_GIDLESS) return;
    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;

    for (i = 0; i < count && i < 8; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * 8ULL, &element) || !element) continue;

        seen++;

        if (tnx_v106_gid((uintptr_t)element, NULL) != 0) withGid++;
    }

    if (seen > 0 && withGid == 0) {
        g_v127_gidless = 1;

        if (g_v127_gidless_logs < 2) {
            g_v127_gidless_logs++;

            tnx_logf("v127 gidless container=%p seen=%d withGid=0 - every sampled element of this list "
                     "has no global id at either +%#llx or +%#llx, which is the brawler class %#llx and "
                     "not the roster class %#llx, so rejGidZero is switched off for this container and "
                     "an element with gid 0 is kept: the id is what made the hop prefer the roster, and "
                     "the roster is the list that carries no coordinates at all",
                     (void *)manager, seen, (unsigned long long)TNX_OBJ_GLOBALID_OFF,
                     (unsigned long long)TNX_V106_GID_FALLBACK_OFF, (unsigned long long)0xff5440ULL,
                     (unsigned long long)0xf9e248ULL);
        }

        return;
    }
}

static int g_v135_gidoff_logs = 0;

static uintptr_t tnx_v135_list_gid_off(uintptr_t array, int32_t count) {
    uintptr_t off = TNX_OBJ_GLOBALID_OFF;
    int sawAt8 = 0;
    int sawAt50 = 0;
    int i = 0;
    int32_t v = 0;

    if (!array || count <= 0) return off;

    for (i = 0; i < count && i < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        if (tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &v) && v != 0) sawAt8++;
        if (tnx_read_i32((uintptr_t)element + TNX_V106_GID_FALLBACK_OFF, &v) && v != 0) sawAt50++;
    }

    if (sawAt8 > 0) {
        off = TNX_OBJ_GLOBALID_OFF;
    } else if (sawAt50 > 0) {
        off = TNX_V106_GID_FALLBACK_OFF;
    }

    if (g_v135_gidoff_logs < TNX_V135_GIDOFF_LOGS) {
        g_v135_gidoff_logs++;

        tnx_logf("v135 gid-off array=%p count=%d chosen=+%#llx sawAt+%#llx=%d sawAt+%#llx=%d - the id "
                 "offset is chosen ONCE for the whole list from its first four elements and not per "
                 "element, because a per-element choice would read the roster class (id at +%#llx) "
                 "and the player class (id at +%#llx) with different offsets inside one list and the "
                 "smallest id would then be meaningless",
                 (void *)array, count, (unsigned long long)off,
                 (unsigned long long)TNX_OBJ_GLOBALID_OFF, sawAt8,
                 (unsigned long long)TNX_V106_GID_FALLBACK_OFF, sawAt50,
                 (unsigned long long)TNX_V106_GID_FALLBACK_OFF,
                 (unsigned long long)TNX_OBJ_GLOBALID_OFF);
    }

    return off;
}

 







static uintptr_t g_v140_proj_addr = 0;
static uint8_t g_v140_proj_bytes[TNX_V140_DIFF_BYTES];
static int g_v140_proj_have = 0;
static int g_v140_proj_dumps = 0;
static uint64_t g_v140_proj_diff_logs = 0;
static uint64_t g_v140_proj_firsts = 0;

static int g_v150_logs = 0;
static int g_v151_logs = 0;
static int g_v153_best_k = -1;
static float g_v153_best_t = 0.0f;
static int g_v153_side = 0;
static int g_v153_logs = 0;
static int32_t g_v152_last_tx = 0;
static int32_t g_v152_last_ty = 0;
static int g_v152_issued = 0;
static float g_v151_best_x = 0.0f;
static float g_v151_best_y = 0.0f;
static float g_v151_best_dist = -1.0f;
static int g_v151_best_hit = 0;
static int32_t g_v154_tx = 0;
static int32_t g_v154_ty = 0;
static int g_v154_have = 0;
static uint64_t g_v154_reuse = 0;
static uint64_t g_v154_searches = 0;
static int g_v154_logs = 0;


 


static int g_v142_walk_aborted = 0;
static int g_v142_walk_abort_i = -1;
static uintptr_t g_v142_walk_arr = 0;
static int32_t g_v142_walk_n = 0;

static void tnx_v140_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team) {
    uint8_t now[TNX_V140_DIFF_BYTES];
    int i;

    if (!elem) return;
    if (!tnx_read_bytes(elem, now, sizeof(now))) return;

    if (elem != g_v140_proj_addr) {
        g_v140_proj_firsts++;
        g_v140_proj_addr = elem;
        memcpy(g_v140_proj_bytes, now, sizeof(now));
        g_v140_proj_have = 1;

        if (g_v140_proj_dumps < TNX_V140_DUMPS) {
            g_v140_proj_dumps++;

            tnx_logf("v140 proj FIRST elem=%p classRva=%#llx gid=%d team=%d firsts=%llu - the element "
                     "id changed, so this is either a fresh spawn or the same slot reused; the whole "
                     "first %#x bytes follow one qword per line",
                     (void *)elem, (unsigned long long)classRva, gid, team,
                     (unsigned long long)g_v140_proj_firsts, TNX_V140_DIFF_BYTES);

            for (i = 0; i < TNX_V140_DIFF_BYTES; i += 8) {
                uint64_t q = 0;
                int32_t lo = 0;
                int32_t hi = 0;
                float loF = 0.0f;
                float hiF = 0.0f;

                memcpy(&q, now + i, 8);
                memcpy(&lo, now + i, 4);
                memcpy(&hi, now + i + 4, 4);
                memcpy(&loF, now + i, 4);
                memcpy(&hiF, now + i + 4, 4);

                tnx_logf("v140 proj FIRST +%02x = %#018llx lo=%d hi=%d loF=%.3f hiF=%.3f",
                         i, (unsigned long long)q, lo, hi, (double)loF, (double)hiF);
            }
        }

        return;
    }

    if (!g_v140_proj_have) {
        memcpy(g_v140_proj_bytes, now, sizeof(now));
        g_v140_proj_have = 1;

        return;
    }

    for (i = 0; i < TNX_V140_DIFF_BYTES; i++) {
        if (g_v140_proj_bytes[i] == now[i]) continue;

        g_v140_proj_diff_logs++;

        if (g_v140_proj_diff_logs <= TNX_V140_DIFF_LOGS) {
            uint64_t oldQ = 0;
            uint64_t newQ = 0;
            int base = i & ~7;

            memcpy(&oldQ, g_v140_proj_bytes + base, 8);
            memcpy(&newQ, now + base, 8);

            tnx_logf("v140 proj DIFF +%02x old=%02x new=%02x gid=%d q_old=%#018llx q_new=%#018llx - "
                     "a byte that changes between two ticks while the address stays the same is a "
                     "field of the moving object; a position pair is the first int32/int32 or "
                     "float/float that walks",
                     i, g_v140_proj_bytes[i], now[i], gid, (unsigned long long)oldQ,
                     (unsigned long long)newQ);
        }
    }

    memcpy(g_v140_proj_bytes, now, sizeof(now));
}

static int tnx_v48_collect(uintptr_t manager, tnx_v47_obj_t *out, int capacity, int *rejected) {
    void *data = NULL;
    int32_t count = 0;
    int usable = 0;
    int bad = 0;
    uintptr_t gidOff = TNX_OBJ_GLOBALID_OFF;
    uint32_t walkSeq = 0;

    memset(&g_v50_reject, 0, sizeof(g_v50_reject));

    tnx_v127_gidless_scan(manager);

    if (rejected) *rejected = 0;

    if (!manager) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0) return 0;

    if (count > capacity) count = capacity;

    gidOff = tnx_v135_list_gid_off((uintptr_t)data, count);

     



    walkSeq = g_v142_seq;

    g_v142_walk_aborted = 0;
    g_v142_walk_abort_i = -1;
    g_v142_walk_arr = (uintptr_t)data;
    g_v142_walk_n = count;

    for (int32_t i = 0; i < count && usable < capacity; i++) {
        void *element = NULL;
        void *vtable = NULL;
        tnx_v47_obj_t entry;
        uintptr_t vtRva = 0;

        memset(&entry, 0, sizeof(entry));

        g_v50_reject.elementsRead++;

         

        if (g_v142_seq != walkSeq) {
            g_v142_walk_aborted = 1;
            g_v142_walk_abort_i = i;
            g_v142_walk_aborts++;

            if (g_v142_walk_aborts <= TNX_V142_WALK_ABORT_FULL) {
                tnx_logf("v142 walk aborted at i=%d n=%d arr=%p g_arr=%p g_n=%d aborts=%llu - the "
                         "published tuple moved during the pass, so the rest of this list is "
                         "whatever the engine put there next and the pass stops instead of "
                         "dereferencing it",
                         i, count, (void *)(uintptr_t)data, (void *)g_v142_pub_array,
                         g_v142_pub_count, (unsigned long long)g_v142_walk_aborts);
            } else if ((g_v142_walk_aborts % TNX_V142_WALK_ABORT_EVERY) == 0) {
                tnx_logf("v142 walk aborts=%llu at i=%d n=%d - the full text is printed for the "
                         "first %d only, because a reallocation burst would otherwise drown the "
                         "log the way the census did in v135",
                         (unsigned long long)g_v142_walk_aborts, i, count,
                         TNX_V142_WALK_ABORT_FULL);
            }

            break;
        }

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

        entry.gid = tnx_v106_gid_at(entry.object, gidOff);

        {
            uintptr_t tw = 0;

            tnx_v86_element_type((uintptr_t)vtable, &tw);

            entry.typeWord = (int32_t)tw;
        }

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

        if (entry.gid >= TNX_V138_PLAYER_GID_MAX) {
            g_v50_reject.rejNonPlayer++;
            bad++;

            tnx_v140_proj_track(entry.object, vtRva, entry.gid, entry.teamOld);

            if (g_v138_dump_np < TNX_V138_NP_DUMPS) {
                int32_t npX = 0;
                int32_t npY = 0;
                int32_t np70 = 0;
                int32_t np74 = 0;
                float npFx = 0.0f;
                float npFy = 0.0f;
                float npF70 = 0.0f;
                float npF74 = 0.0f;
                void *np38 = NULL;
                uintptr_t npRva = vtRva;

                g_v138_dump_np++;

                tnx_read_i32(entry.object + TNX_OBJ_X_OFF, &npX);
                tnx_read_i32(entry.object + TNX_OBJ_Y_OFF, &npY);
                tnx_read_i32(entry.object + TNX_V134_V70_OFF, &np70);
                tnx_read_i32(entry.object + TNX_V134_V70_OFF + 4ULL, &np74);
                tnx_read_ptr(entry.object + TNX_V138_NP_PTR_OFF, &np38);
                if (!tnx_read_f32(entry.object + TNX_OBJ_X_OFF, &npFx)) npFx = 0.0f;
                if (!tnx_read_f32(entry.object + TNX_OBJ_Y_OFF, &npFy)) npFy = 0.0f;
                if (!tnx_read_f32(entry.object + TNX_V134_V70_OFF, &npF70)) npF70 = 0.0f;
                if (!tnx_read_f32(entry.object + TNX_V134_V70_OFF + 4ULL, &npF74)) npF74 = 0.0f;

                tnx_logf("v138 nonplayer elem=%p classRva=%#llx gid=%d team=%d x+%#llx=%d y+%#llx=%d "
                         "+%#llx=%d +%#llx=%d f32x=%g f32y=%g f32%#llx=%g f32%#llx=%g ptr+%#llx=%p - an "
                         "element outside the player id window "
                         "is named once with the fields a projectile would need, because the claim "
                         "that this class is a projectile was an analogy from its id range and not a "
                         "measurement, and a position that changes while the element exists and then "
                         "disappears is what would settle it",
                         (void *)entry.object, (unsigned long long)npRva, entry.gid, entry.teamOld,
                         (unsigned long long)TNX_OBJ_X_OFF, npX, (unsigned long long)TNX_OBJ_Y_OFF, npY,
                         (unsigned long long)TNX_V134_V70_OFF, np70,
                         (unsigned long long)(TNX_V134_V70_OFF + 4ULL), np74,
                         (double)npFx, (double)npFy, (unsigned long long)TNX_OBJ_X_OFF, (double)npF70,
                         (unsigned long long)(TNX_V134_V70_OFF + 4ULL), (double)npF74,
                         (unsigned long long)TNX_V138_NP_PTR_OFF, np38);
            }

            continue;
        }

        if (entry.gid == 0 && !g_v127_gidless) {
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

    tnx_v146_phase("walk");

    usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    g_dodge_probe_usable = usable;
    if (usable > 0) memcpy(g_dodge_probe_list, objects, (size_t)usable * sizeof(g_dodge_probe_list[0]));

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

    {
        static int v142_walk_logs = 0;

        if (v142_walk_logs < 12 || (v142_walk_logs % 128) == 0) {
            v142_walk_logs++;

            tnx_logf("v142 walk enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d manager=%p "
                     "- the walk reads the tuple the tick snapshot handed it, so this line and "
                     "the score line must print the same arr and n", (void *)g_v142_tick_array,
                     g_v142_tick_count, (void *)g_players_array, g_players_count,
                     (void *)g_v142_tick_array, g_v142_tick_count, (void *)manager);
        }
    }

    usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    {
        static int v142_leave_logs = 0;

        if (v142_leave_logs < 12 || (v142_leave_logs % 128) == 0) {
            v142_leave_logs++;

            tnx_logf("v142 walk leave arr=%p n=%d g_arr=%p g_n=%d aborted=%d abortI=%d usable=%d "
                     "rejected=%d - aborted=1 names the pass that stopped because the published "
                     "tuple moved under it, which is the case that walked a list the engine had "
                     "already replaced", (void *)g_v142_walk_arr, g_v142_walk_n,
                     (void *)g_v142_pub_array, g_v142_pub_count, g_v142_walk_aborted,
                     g_v142_walk_abort_i, usable, rejected);
        }
    }

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


    if (!TNX_V113_DEAD_ONCE || !g_v113_dead_probe_done) {
        g_v113_dead_probe_done = 1;
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


    if (TNX_V101_ACTUATOR && taken) {
        tnx_v101_actuator(chosen == 0 ? (uintptr_t)g_players_object : (uintptr_t)g_scene_object,
                          0, 0);
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




static int tnx_v112_read_flag(void) {
    uint8_t b = 0;

    if (!g_scene_object) return -1;
    if (!tnx_read_u8((uintptr_t)g_scene_object + TNX_V112_FLAG_OFF, &b)) return -1;

    return (int)b;
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
static uint64_t g_v126_watch_from = 0;
static int g_v126_watch_logs = 0;

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

static uintptr_t g_v127_own_obj = 0;
static uintptr_t g_v127_elem = 0;
static int32_t g_v127_elem_x0 = 0;
static int32_t g_v127_elem_y0 = 0;
static int32_t g_v127_own_before_x = 0;
static int32_t g_v127_own_before_y = 0;
static int g_v127_setter_called = 0;
static int g_v127_elem_called = 0;
static int g_v127_rb_logs = 0;

 







static uintptr_t g_v144_own_elem = 0;
static uint64_t g_v144_own_stamp = 0;
static int g_v144_own_logs = 0;
static uint64_t g_v144_cand_logs = 0;
static uint64_t g_v144_raw_writes = 0;
static uint64_t g_v144_raw_skips = 0;

static int tnx_v144_vt_ok(uintptr_t obj, uintptr_t *vtOut) {
    void *vt = NULL;
    uintptr_t vtRva = 0;

    if (vtOut) *vtOut = 0;
    if (!obj) return 0;
    if (obj & 7) return 0;
    if (!tnx_read_ptr(obj, &vt) || !vt) return 0;
    if ((uintptr_t)vt < g_base) return 0;

    vtRva = (uintptr_t)vt - g_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (vtOut) *vtOut = (uintptr_t)vt;

    return 1;
}

static int tnx_v144_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut) {
    uintptr_t vt = 0;
    int32_t gate = 0;

    if (vtOut) *vtOut = 0;

    if (!cand) {
        if (why) *why = "null";

        return 0;
    }

    if (cand & 7) {
        if (why) *why = "unaligned";

        return 0;
    }

    if (!tnx_addr_readable(cand, TNX_V144_MIN_OBJ_BYTES)) {
        if (why) *why = "not-readable";

        return 0;
    }

    if (!tnx_v144_vt_ok(cand, &vt)) {
        if (why) *why = "vtable-not-in-data-const";

        return 0;
    }

    if (!tnx_read_i32(cand + TNX_V127_GATE_FLAG_OFF, &gate)) {
        if (why) *why = "gate-unreadable";

        return 0;
    }

    if (why) *why = "ok";
    if (vtOut) *vtOut = vt;

    return 1;
}

static uintptr_t tnx_v144_hop(uintptr_t base, int *whyOut) {
    void *p = NULL;
    void *q = NULL;

    if (whyOut) *whyOut = 0;
    if (!base) {
        if (whyOut) *whyOut = 1;

        return 0;
    }

    if (!tnx_read_ptr(base + TNX_V140_CTRL_MODE_OFF, &p) || !p) {
        if (whyOut) *whyOut = 2;

        return 0;
    }

    if (!tnx_read_ptr((uintptr_t)p + TNX_V126_OWN_INNER_OFF, &q) || !q) {
        if (whyOut) *whyOut = 3;

        return 0;
    }

    return (uintptr_t)q;
}

static const char *g_v145_own_from = "none";
static int g_v147_dry_logs = 0;
static int g_v145_pub_logs = 0;
static int g_v145_stale_logs = 0;
static int g_v145_actuate_logs = 0;

static void tnx_v145_publish_own(uintptr_t elem, const char *from) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (!tnx_v144_cand_ok(elem, &why, &vt)) {
        if (g_v145_pub_logs < TNX_V145_PUB_LOGS) {
            g_v145_pub_logs++;

            tnx_logf("v145 own publish REJECT from=%s elem=%p vt=%p reason=%s - nothing is published, "
                     "so the actuator falls back to the engine chain or skips; a reject here is not "
                     "a v135 failure, it is a tick where the resolver named nothing usable",
                     from ? from : "?", (void *)elem, (void *)vt, why);
        }

        return;
    }

    g_v144_own_elem = elem;
    g_v144_own_stamp = g_v142_tick_stamp;
    g_v145_own_from = from ? from : "?";

    if (g_v145_pub_logs < TNX_V145_PUB_LOGS) {
        uintptr_t cls = (vt >= g_base) ? (vt - g_base) : 0;

        g_v145_pub_logs++;

        tnx_logf("v145 own publish from=%s elem=%p vt=%p classRva=%#llx stamp=%llu - classRva is the "
                 "value to line up against the census classRva of the same element index; the guard "
                 "accepts on aligned+readable+vtable-in-__DATA_CONST and this line names the class "
                 "that passed it", from ? from : "?", (void *)elem, (void *)vt,
                 (unsigned long long)cls, (unsigned long long)g_v144_own_stamp);
    }
}

static uintptr_t tnx_v127_own_obj(void) {
    uintptr_t vt = 0;
    const char *why = "?";

     




    if (g_v144_own_elem) {
        if (g_v144_own_stamp == g_v142_tick_stamp &&
            tnx_v144_cand_ok(g_v144_own_elem, &why, &vt)) {
            g_v145_own_from = "published";

            return g_v144_own_elem;
        }

        if (g_v145_stale_logs < 6) {
            g_v145_stale_logs++;

            tnx_logf("v145 own not used elem=%p stamp=%llu tick=%llu reason=%s - an element from "
                     "another tick is not accepted even though the address is a live heap object, "
                     "so the engine chain is tried instead and may legitimately resolve to 0",
                     (void *)g_v144_own_elem, (unsigned long long)g_v144_own_stamp,
                     (unsigned long long)g_v142_tick_stamp, why);
        }
    }

    {
        uintptr_t cand = tnx_v144_hop((uintptr_t)g_scene_object, NULL);

         


        if (cand && tnx_v144_cand_ok(cand, NULL, &vt)) {
            g_v145_own_from = "engine-chain";

            return cand;
        }

        cand = tnx_v144_hop((uintptr_t)g_players_object, NULL);

        if (cand && tnx_v144_cand_ok(cand, NULL, &vt)) {
            g_v145_own_from = "players-chain";

            return cand;
        }
    }

    g_v145_own_from = "none";

    return 0;
}

static void tnx_v127_setter(int32_t vx, int32_t vy) {
    uintptr_t fn = tnx_v113_entry(TNX_V112_SETPRED4_RVA);
    uintptr_t own = tnx_v127_own_obj();
    int32_t alive = 0;

    g_v127_setter_called = 0;

    if (!TNX_V127_ACT_SETTER) return;
    if (!fn || !own) return;
    if (!tnx_read_i32(own + TNX_V127_GATE_X_OFF, &g_v127_own_before_x)) return;
    if (!tnx_read_i32(own + TNX_V127_GATE_Y_OFF, &g_v127_own_before_y)) return;
    if (!tnx_read_i32(own + TNX_V127_OWN_ALIVE_OFF, &alive)) return;

    g_v127_own_obj = own;

    ((void (*)(void *, int, int, int))fn)((void *)own, vx, vy, TNX_V127_SETFLAG);

    g_v127_setter_called = 1;

    tnx_logf("v127 setter own=%p x=%d y=%d flag=%d in10c was=%d in110 was=%d alive140=%d - this is the "
             "exact call the engine makes for itself at %#llx, where it passes the getOwnCharacter "
             "result and the clamped stick pair; the receiver is read the same way here (%#llx then its "
             "+%#llx) and never guessed, and the pair is never (0,0) because the apply path has to see a "
             "movement and not a release",
             (void *)own, vx, vy, TNX_V127_SETFLAG, g_v127_own_before_x, g_v127_own_before_y, alive,
             (unsigned long long)0x79de14ULL, (unsigned long long)TNX_V126_OWN_OFF,
             (unsigned long long)TNX_V126_OWN_INNER_OFF);
}

static void tnx_v127_elem_write(uintptr_t element, int32_t vx, int32_t vy) {
    int32_t was = 0;

    g_v127_elem_called = 0;

    if (!TNX_V127_ACT_ELEM) return;
    if (!element) return;
    if (!tnx_read_i32(element + TNX_OBJ_X_OFF, &g_v127_elem_x0)) return;
    if (!tnx_read_i32(element + TNX_OBJ_Y_OFF, &g_v127_elem_y0)) return;

    g_v127_elem = element;
    was = g_v127_elem_x0;

    if (!tnx_write_bytes(element + TNX_OBJ_X_OFF, &vx, sizeof(vx))) return;
    if (!tnx_write_bytes(element + TNX_OBJ_Y_OFF, &vy, sizeof(vy))) return;

    g_v127_elem_called = 1;

    tnx_logf("v127 elemwrite elem=%p x=%d y=%d was=(%d,%d) - the int pair at +%#llx/+%#llx of the walked "
             "element is written directly and read back a whole second later, because the v123 probe read "
             "through four frames and a server that reconciles on a 50 ms cadence would still look "
             "successful there; the difference between a local shadow and an authoritative position is "
             "exactly whether the pair is still ours a second later",
             (void *)element, vx, vy, was, g_v127_elem_y0, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF);
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


static uintptr_t g_v128_wit_elem = 0;
static int32_t g_v128_wit_x0 = 0;
static int32_t g_v128_wit_y0 = 0;
static int32_t g_v128_wit_x1 = 0;
static int32_t g_v128_wit_y1 = 0;
static int32_t g_v128_own_held_x = 0;
static int32_t g_v128_own_held_y = 0;
static int32_t g_v128_own_flag = -1;
static int g_v128_have_wit = 0;
static int g_v128_active = 0;
static int g_v128_calls = 0;
static int g_v128_act_logs = 0;
static int g_v128_wit_logs = 0;
static int g_v128_own_logs = 0;
static int g_v128_probe_done = 0;
static int64_t g_v128_moves = 0;
static int64_t g_v128_elem_moves = 0;

static int tnx_v128_witness(int32_t *x, int32_t *y) {
    int32_t wx = 0;
    int32_t wy = 0;

    if (x) *x = 0;
    if (y) *y = 0;

    if (!tnx_v116_interp(&wx, &wy)) return 0;

    if (x) *x = wx;
    if (y) *y = wy;

    return 1;
}

static uintptr_t g_v129_own_slot = 0;
static int32_t g_v129_own_slot_idx = -1;
static int32_t g_v129_own_slot_gid = 0;
static int g_v129_own_slot_ok = 0;
static int g_v129_own_slot_logs = 0;

static uintptr_t tnx_v129_battle_global(void) {
    return (uintptr_t)tnx_read_global_ptr(TNX_V129_BATTLE_RVA);
}

static int tnx_v129_container_has(uintptr_t container, uintptr_t own) {
    void *array = NULL;
    int32_t count = 0;
    int i;

    if (!container || !own) return -1;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > TNX_V56_COUNT_MAX) return -1;

    for (i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        if ((uintptr_t)element == own) return i;
    }

    return -1;
}

static int tnx_v129_own_from_slot(uintptr_t *objectOut, int32_t *gidOut) {
    uintptr_t scene = (uintptr_t)g_scene_object;
    uintptr_t hop[TNX_V82_HOPS] = { 0 };
    void *outer = NULL;
    int k;

    if (objectOut) *objectOut = 0;
    if (gidOut) *gidOut = 0;

    if (!scene) return 0;

    if (tnx_read_ptr(scene + TNX_V115_CLIENT_OFF, &outer) && outer) {
        hop[0] = (uintptr_t)outer;

        if (tnx_read_ptr((uintptr_t)outer + TNX_V115_CLIENT_OFF, &outer) && outer) {
            hop[1] = (uintptr_t)outer;
        }
    }

    for (k = 0; k < TNX_V82_HOPS; k++) {
        void *array = NULL;
        void *element = NULL;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t gid = 0;

        if (!hop[k]) continue;
        if (!tnx_read_i32(hop[k] + TNX_V102_OWNIDX_OFF, &idx)) continue;
        if (!tnx_read_ptr(hop[k] + TNX_MGR_ARRAY_OFF, &array) || !array) continue;
        if (!tnx_read_i32(hop[k] + TNX_MGR_COUNT_OFF, &count)) continue;
        if (idx < 0 || idx >= count || count <= 0) continue;
        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &element) || !element) continue;

        gid = tnx_v106_gid((uintptr_t)element, NULL);

         



        if (gid < TNX_V75_GID_FLOOR || gid >= TNX_V138_PLAYER_GID_MAX) {
            if (g_v129_own_slot_logs < TNX_V129_CHAIN_LOGS) {
                g_v129_own_slot_logs++;

                tnx_logf("v140 own-slot REJECT hop=%d container=%p ownIdx+%#llx=%d count=%d elem=%p "
                         "gid=%d window=[%d,%d) - the slot resolves to an element outside the player "
                         "id window, so it is not own and the chain moves on",
                         k, (void *)hop[k], (unsigned long long)TNX_V102_OWNIDX_OFF, idx, count,
                         element, gid, TNX_V75_GID_FLOOR, TNX_V138_PLAYER_GID_MAX);
            }

            continue;
        }

        if (g_v129_own_slot_logs < TNX_V129_CHAIN_LOGS) {
            g_v129_own_slot_logs++;

            tnx_logf("v129 own-slot hop=%d container=%p ownIdx+%#llx=%d count=%d elem=%p gid=%d "
                     "expect=%d match=%d - own is taken from the slot the engine itself indexes, the "
                     "same field the hop used to be judged on, so a list whose own slot is the index "
                     "\"1\" and whose element carries gid %d names own without any proximity guess",
                     k, (void *)hop[k], (unsigned long long)TNX_V102_OWNIDX_OFF, idx, count, element,
                     gid, TNX_V129_OWN_EXPECT_GID, gid == TNX_V129_OWN_EXPECT_GID,
                     TNX_V129_OWN_EXPECT_GID);
        }

        g_v129_own_slot = (uintptr_t)element;
        g_v129_own_slot_idx = idx;
        g_v129_own_slot_gid = gid;
        g_v129_own_slot_ok = 1;

        if (objectOut) *objectOut = (uintptr_t)element;
        if (gidOut) *gidOut = gid;

        return 1;
    }

    return 0;
}

static void tnx_v129_chain(void) {
    static int done = 0;
    uintptr_t scene = (uintptr_t)g_scene_object;
    uintptr_t battle = tnx_v129_battle_global();
    void *holder = NULL;
    uintptr_t own = 0;
    uintptr_t slotOwn = 0;
    int32_t slotGid = 0;
    void *slot = NULL;
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t ownX = 0;
    int32_t ownY = 0;
    int rawOk = 0;
    int ownOk = 0;
    int inHop0 = -1;
    int inHop1 = -1;
    void *hop0 = NULL;
    void *hop1 = NULL;

    if (done) return;
    if (!scene) return;

    done = 1;

    if (tnx_read_ptr(scene + TNX_V126_OWN_OFF, &slot) && slot) {
        if (!tnx_read_ptr((uintptr_t)slot + TNX_V126_OWN_INNER_OFF, &holder)) holder = 0;
    }

    own = tnx_v127_own_obj();

    tnx_v129_own_from_slot(&slotOwn, &slotGid);

    rawOk = tnx_read_i32(scene + TNX_V128_CTRL_RAW_X_OFF, &rawX) &&
            tnx_read_i32(scene + TNX_V128_CTRL_RAW_Y_OFF, &rawY);
    ownOk = own && tnx_read_i32(own + TNX_V112_INPUT_X_OFF, &ownX) &&
            tnx_read_i32(own + TNX_V112_INPUT_Y_OFF, &ownY);

    tnx_logf("v129 ownchain scene=%p [scene+%#llx]=%p +%#llx=%p %s=%p same=%d "
             "battleGlobal=[%#llx]=%p | slotOwn=%p slotIdx=%d slotGid=%d expect=%d | "
             "raw+%#llx ok=%d raw=(%d,%d) slotOk=%d own+%#llx/%#llx ok=%d own=(%d,%d) | "
             "scene=[manager+%#llx] manager=[%#llx] getBattleTail=%#llx managerGetter=%#llx - the scene "
             "was built by the engine as [manager+%#llx] where the manager comes from the global %#llx, "
             "and the same object is what its constructor caches into %#llx and what the input "
             "dispatch reads back at %#llx, so same=1 means the pair at scene+%#llx is the very input "
             "the battle update clamps and the write is aimed at the right object; the slot element is "
             "the engine's own index into hop0 and the only name of own that is not a guess",
             (void *)scene, (unsigned long long)TNX_V126_OWN_OFF, slot,
             (unsigned long long)TNX_V126_OWN_INNER_OFF, holder,
             ((uintptr_t)holder == own) ? "holder" : "own", (void *)own, (own == scene) ? 1 : 0,
             (unsigned long long)TNX_V129_BATTLE_RVA, (void *)battle,
             (void *)slotOwn, g_v129_own_slot_idx, slotGid, TNX_V129_OWN_EXPECT_GID,
             (unsigned long long)TNX_V128_CTRL_RAW_X_OFF, rawOk, rawX, rawY, g_v129_own_slot_ok,
             (unsigned long long)TNX_V112_INPUT_X_OFF, (unsigned long long)TNX_V112_INPUT_Y_OFF, ownOk,
             ownX, ownY, (unsigned long long)TNX_V80_SCENE_OFF,
             (unsigned long long)TNX_V80_STATE_RVA, (unsigned long long)0x8ce9d8ULL,
             (unsigned long long)0x8cdfd4ULL, (unsigned long long)TNX_V80_SCENE_OFF,
             (unsigned long long)TNX_V80_STATE_RVA, (unsigned long long)TNX_V129_BATTLE_RVA,
             (unsigned long long)0x7afba8ULL, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF);

    if (tnx_read_ptr(scene + TNX_V115_CLIENT_OFF, &hop0) && hop0) {
        inHop0 = tnx_v129_container_has((uintptr_t)hop0, own);

        if (tnx_read_ptr((uintptr_t)hop0 + TNX_V115_CLIENT_OFF, &hop1) && hop1) {
            inHop1 = tnx_v129_container_has((uintptr_t)hop1, own);
        }
    }

    tnx_logf("v129 ownchain2 own=%p inHop0=%d inHop1=%d slotOwn=%p slotGid=%d - inHop is the slot the "
             "own pointer occupies in each hop list, and -1 means the list does not contain it at all, "
             "which is the case a coordinate list falls into and the reason own has to be named by the "
             "slot element instead", (void *)own, inHop0, inHop1, (void *)slotOwn, slotGid);
}

static void tnx_v128_probe(void) {
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    uintptr_t own = tnx_v127_own_obj();
    void *container = NULL;
    void *hop = NULL;
    int32_t raw_x = 0;
    int32_t raw_y = 0;
    int32_t dirty = 0;
    int32_t alive = 0;
    int32_t id = 0;
    int32_t gate = 0;
    int32_t app_x = 0;
    int32_t app_y = 0;
    int32_t own_flag = -1;
    int32_t own_mode = -1;

    if (g_v128_probe_done) return;
    if (!ctrl) return;

    g_v128_probe_done = 1;

    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_DIRTY_OFF, &dirty)) dirty = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_ALIVE_OFF, &alive)) alive = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_ID_OFF, &id)) id = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_GATE_OFF, &gate)) gate = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &app_x)) app_x = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &app_y)) app_y = 0;

    if (own) {
        if (!tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &own_flag)) own_flag = -1;
        if (!tnx_read_i32(own + TNX_V115_MODE_OFF, &own_mode)) own_mode = -1;
    }

    if (tnx_read_ptr(ctrl + TNX_V115_CLIENT_OFF, &container) && container) {
        tnx_read_ptr((uintptr_t)container + TNX_V115_CLIENT_OFF, &hop);
    }

    tnx_logf("v128 probe scene=%p own=%p hop0=%p hop1=%p raw+%#llx=(%d,%d) dirty+%#llx=%d "
             "alive+%#llx=%d id+%#llx=%d gate+%#llx=%d applied+%#llx=(%d,%d) ownFlag+%#llx=%d "
             "ownMode+%#llx=%d - %#llx reads the pair it clamps out of the object it is handed in x0 "
             "as 'ldr w0,[x19,+%#llx]; ldr w1,[x19,+%#llx]' and the same object answers %#llx, so this "
             "line says whether the scene the walk already holds is that object: with a non-zero pair "
             "here and applied+%#llx moving while the raw pair is held, the input of this battle is a "
             "pair on the scene and not a message",
             (void *)ctrl, (void *)own, container, hop, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
             raw_x, raw_y, (unsigned long long)TNX_V128_CTRL_DIRTY_OFF, dirty,
             (unsigned long long)TNX_V128_CTRL_ALIVE_OFF, alive,
             (unsigned long long)TNX_V128_CTRL_ID_OFF, id,
             (unsigned long long)TNX_V128_CTRL_GATE_OFF, gate,
             (unsigned long long)TNX_V128_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_V127_GATE_FLAG_OFF, own_flag,
             (unsigned long long)TNX_V115_MODE_OFF, own_mode, (unsigned long long)0x79d594ULL,
             (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
             (unsigned long long)TNX_V128_CTRL_RAW_Y_OFF, (unsigned long long)0x7b9050ULL,
             (unsigned long long)TNX_V128_CTRL_APPLIED_X_OFF);
}

static uintptr_t g_v134_own_ptr = 0;
static int32_t g_v134_own_gid = 0;
static int g_v134_own_logs = 0;

static int tnx_v134_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut,
                                   int32_t *gidOut) {
    uintptr_t best = 0;
    int32_t bestGid = 0;
    int32_t i = 0;

    if (elemOut) *elemOut = 0;
    if (gidOut) *gidOut = 0;
    if (!array || count <= 0) return 0;

    for (i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;
        int32_t team = 0;

        if (!tnx_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        gid = tnx_v106_gid((uintptr_t)element, NULL);

        if (gid < TNX_V75_GID_FLOOR || gid >= TNX_V138_PLAYER_GID_MAX) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team)) continue;
        if (team < 0 || team > TNX_V75_TEAM_MAX) continue;

        if (!best || gid < bestGid) {
            best = (uintptr_t)element;
            bestGid = gid;
        }
    }

    if (!best) {
        if (g_v134_own_logs < TNX_V134_OWN_LOGS) {
            g_v134_own_logs++;

            tnx_logf("v134 own-min-gid array=%p count=%d none - no element passed the id window "
                     "[%d,%d) and the team window 0..%d at the same time, so own cannot be named by "
                     "the smallest id this tick; the id at +%#llx and the team at +%#llx are the two "
                     "fields the census accepts on",
                     (void *)array, count, TNX_V75_GID_FLOOR, TNX_V75_GID_MAX, TNX_V75_TEAM_MAX,
                     (unsigned long long)TNX_OBJ_GLOBALID_OFF,
                     (unsigned long long)TNX_OBJ_TEAM_OFF);
        }

        return 0;
    }

    if (g_v134_own_logs < TNX_V134_OWN_LOGS) {
        g_v134_own_logs++;

        tnx_logf("v134 own-min-gid array=%p count=%d own=%p gid=%d - own is the accepted element "
                 "carrying the smallest id, which the three battles of the v132 run agree on: the "
                 "element with gid 1000000 was the local player in the 3v3, in the solo training "
                 "and in the third battle, while the team field moved between 1, 0 and 1 and the "
                 "own slot at +%#llx of a hop container did not name it at all",
                 (void *)array, count, (void *)best, bestGid,
                 (unsigned long long)TNX_V102_OWNIDX_OFF);
    }

    g_v134_own_ptr = best;
    g_v134_own_gid = bestGid;

    if (elemOut) *elemOut = best;
    if (gidOut) *gidOut = bestGid;

    return 1;
}

static int g_v135_own_logs = 0;

static int tnx_v134_own_from_list(const tnx_v47_obj_t *objects, int usable, int *indexOut,
                                  const char **fromOut) {
    int best = -1;
    int32_t bestGid = 0;
    int accepted = 0;
    int i;

    if (indexOut) *indexOut = -1;
    if (!objects || usable <= 0) return 0;

    for (i = 0; i < usable; i++) {
        int32_t gid = objects[i].gid;

        if (gid < TNX_V75_GID_FLOOR || gid >= TNX_V138_PLAYER_GID_MAX) continue;
        if (objects[i].teamOld < 0 || objects[i].teamOld > TNX_V75_TEAM_MAX) continue;

        accepted++;

        if (best < 0 || gid < bestGid) {
            best = i;
            bestGid = gid;
        }
    }

    if (g_v135_own_logs < TNX_V135_OWN_LOGS) {
        g_v135_own_logs++;

        tnx_logf("v135 own-list usable=%d accepted=%d best=%d bestGid=%d floor=%d max=%d teamMax=%d - "
                 "own is chosen out of the SAME list the walk collected, so the index it returns is "
                 "always valid for that list; the v134 run resolved own out of the container globals "
                 "and then looked the element up in the collected list, which let the +%#llx slot "
                 "path run when the two disagreed and returned a heap pointer as an index",
                 usable, accepted, best, bestGid, TNX_V75_GID_FLOOR, TNX_V75_GID_MAX,
                 TNX_V75_TEAM_MAX, (unsigned long long)TNX_V102_OWNIDX_OFF);
    }

    if (best < 0) return 0;

    if (indexOut) *indexOut = best;
    if (fromOut) *fromOut = "v135-list";

    return 1;
}

static int tnx_v128_resolve_own(const tnx_v47_obj_t *objects, int usable, int *indexOut,
                                const char **fromOut) {
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t wantGid = -1;
    uintptr_t slotOwn = 0;
    int32_t slotGid = 0;
    int hasWit = 0;
    int best = -1;
    int64_t bestD = 0;
    int i;

    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    if (tnx_v134_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    {
        uintptr_t minOwn = 0;
        int32_t minGid = 0;

        if (g_v142_score_logs < 8) {
            g_v142_score_logs++;

            tnx_logf("v142 score enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d - own is "
                     "looked for on the tick snapshot and never on the live globals, so this line "
                     "and the walk line must print the same arr and n in the same tick",
                     (void *)g_v142_tick_array, g_v142_tick_count, (void *)g_players_array,
                     g_players_count, (void *)g_v142_tick_array, g_v142_tick_count);
        }

        if (tnx_v134_own_by_min_gid(g_v142_tick_array, g_v142_tick_count, &minOwn, &minGid) &&
            minOwn) {
            for (i = 0; i < usable; i++) {
                if (objects[i].object != minOwn) continue;

                if (indexOut) *indexOut = i;
                if (fromOut) *fromOut = "v134-min";

                return 1;
            }
        }
    }

    if (tnx_v129_own_from_slot(&slotOwn, &slotGid) && slotOwn) {
        for (i = 0; i < usable; i++) {
            if (objects[i].object != slotOwn) continue;
            if (objects[i].gid < TNX_V75_GID_FLOOR || objects[i].gid >= TNX_V75_GID_MAX) continue;

            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-slot";

            return 1;
        }
    }

    if (g_v134_own_gid > 0) {
        wantGid = g_v134_own_gid;
    } else if (slotGid > 0) {
        wantGid = slotGid;
    } else if (g_v102_own_ptr) {
        wantGid = tnx_v106_gid((uintptr_t)g_v102_own_ptr, NULL);
    }

    for (i = 0; i < usable; i++) {
        if (objects[i].x <= -TNX_V75_COORD_MAX || objects[i].x >= TNX_V75_COORD_MAX) continue;
        if (objects[i].y <= -TNX_V75_COORD_MAX || objects[i].y >= TNX_V75_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        if (wantGid > 0 && objects[i].gid == wantGid) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-gid";

            tnx_logf("v129 own-gid idx=%d gid=%d pos=(%d,%d) wantGid=%d slotIdx=%d - own is named by the "
                     "id the slot element of hop0 carries, which is the engine's own index and not a "
                     "distance, because the interpolated pair is not a position when the mode never "
                     "reaches the lerp branch",
                     i, objects[i].gid, objects[i].x, objects[i].y, wantGid, g_v129_own_slot_idx);

            return 1;
        }
    }

    hasWit = tnx_v128_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {
        tnx_logf("v129 own-none usable=%d wantGid=%d slotOwn=%p slotIdx=%d interpUnusable=1 - neither "
                 "the slot element nor an element with the slot id is in the collected list and the "
                 "interpolated pair is (0,0), so own is left unresolved instead of being taken from a "
                 "witness that this mode never updates",
                 usable, wantGid, (void *)slotOwn, g_v129_own_slot_idx);

        return 0;
    }

    for (i = 0; i < usable; i++) {
        int64_t dx = 0;
        int64_t dy = 0;
        int64_t d = 0;

        if (objects[i].x <= -TNX_V75_COORD_MAX || objects[i].x >= TNX_V75_COORD_MAX) continue;
        if (objects[i].y <= -TNX_V75_COORD_MAX || objects[i].y >= TNX_V75_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        dx = (int64_t)objects[i].x - (int64_t)wx;
        dy = (int64_t)objects[i].y - (int64_t)wy;
        d = dx * dx + dy * dy;

        if (best < 0 || d < bestD) {
            best = i;
            bestD = d;
        }
    }

    if (best < 0) return 0;

    if (indexOut) *indexOut = best;
    if (fromOut) *fromOut = "v129-near";

    if (g_v128_own_logs < TNX_V128_OWN_LOGS) {
        g_v128_own_logs++;

        tnx_logf("v129 own-near idx=%d gid=%d pos=(%d,%d) interp=(%d,%d) d2=%lld wantGid=%d - own is "
                 "the list element closest to the pair read from client+%#llx/+%#llx only after the "
                 "slot element and the slot id both missed, and this line is the one that has to be "
                 "watched for a wrong gid being chosen",
                 best, objects[best].gid, objects[best].x, objects[best].y, wx, wy, (long long)bestD,
                 wantGid, (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
                 (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);
    }

    return 1;
}

static void tnx_v128_actuate(void) {
    uintptr_t own = tnx_v127_own_obj();
    uintptr_t ownVt = 0;
    uintptr_t ownCls = 0;
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    uintptr_t fn = tnx_v113_entry(TNX_V112_SETPRED4_RVA);
    int32_t raw_x = TNX_V129_DX;
    int32_t raw_y = TNX_V129_DY;
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t flagAfter = -1;
    int32_t modeBefore = -1;
    int32_t modeAfter = -1;
    int32_t raw_keep_x = 0;
    int32_t raw_keep_y = 0;
    int32_t pairBeforeX = 0;
    int32_t pairBeforeY = 0;
    int32_t pairBeforeK = 0;
    int32_t pairAfterX = 0;
    int32_t pairAfterY = 0;
    int32_t pairAfterK = 0;
    int32_t gateBefore = -1;
    int32_t gateAfter = -1;
    int setterRan = 0;
    int doWrite = (TNX_V129_MODE == TNX_V129_MODE_WRITE ||
                   TNX_V129_MODE == TNX_V129_MODE_BOTH) ? 1 : 0;
    int doSetter = (TNX_V129_MODE == TNX_V129_MODE_SETTER ||
                    TNX_V129_MODE == TNX_V129_MODE_BOTH) ? 1 : 0;

    if (!g_v128_active) return;
    if (!doWrite && !doSetter) return;

    g_v128_calls++;

    tnx_v128_probe();

    if (!tnx_v128_witness(&wx, &wy)) {
        wx = g_v128_wit_x0;
        wy = g_v128_wit_y0;
    } else {
        g_v128_have_wit = 1;
    }

     



    if (TNX_V147_ACT_WRITE && doWrite && ctrl &&
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_keep_x) &&
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_keep_y)) {
        if (raw_keep_x != raw_x || raw_keep_y != raw_y) {
            tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_x, sizeof(raw_x));
            tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_y, sizeof(raw_y));

            g_v144_raw_writes++;
        } else {
            g_v144_raw_skips++;
        }
    }

    if (doSetter && fn && own) {
        if (tnx_read_i32(own + TNX_V112_INPUT_X_OFF, &pairBeforeX)) {
            tnx_read_i32(own + TNX_V112_INPUT_Y_OFF, &pairBeforeY);
            tnx_read_i32(own + TNX_V112_INPUT_K_OFF, &pairBeforeK);
            tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &gateBefore);
            tnx_read_i32(own + TNX_V115_MODE_OFF, &modeBefore);
        }

        tnx_logf("v129 setter-before x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d "
                 "mode+%#llx=%d call=%d - the receiver of %#llx is the own object and never the scene, "
                 "because %#llx stores on the getOwnCharacter result and the reader reads the same "
                 "object, so a call with the scene as x0 would store where nothing reads",
                 (void *)own, (unsigned long long)TNX_V112_INPUT_X_OFF, pairBeforeX,
                 (unsigned long long)TNX_V112_INPUT_Y_OFF, pairBeforeY,
                 (unsigned long long)TNX_V112_INPUT_K_OFF, pairBeforeK,
                 (unsigned long long)TNX_V127_GATE_FLAG_OFF, gateBefore,
                 (unsigned long long)TNX_V115_MODE_OFF, modeBefore, g_v128_calls,
                 (unsigned long long)TNX_V112_SETPRED4_RVA, (unsigned long long)0x79de14ULL);

        ((void (*)(void *, int, int, int))fn)((void *)own, wx + TNX_V129_DX, wy + TNX_V129_DY,
                                              TNX_V127_SETFLAG);

        setterRan = 1;

        tnx_read_i32(own + TNX_V112_INPUT_X_OFF, &pairAfterX);
        tnx_read_i32(own + TNX_V112_INPUT_Y_OFF, &pairAfterY);
        tnx_read_i32(own + TNX_V112_INPUT_K_OFF, &pairAfterK);
        tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &gateAfter);
        tnx_read_i32(own + TNX_V115_MODE_OFF, &modeAfter);

        tnx_logf("v129 setter-after x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d "
                 "mode=%d wrote=%d want=(%d,%d) - the four words are read on the very receiver the call "
                 "was made on, so this line names where the store landed; +%#llx=1 means the producer "
                 "half of the pair %#llx consumes is in place, and a word that reads back as want=(%d,%d) "
                 "is the only proof the call ran at all",
                 (void *)own, (unsigned long long)TNX_V112_INPUT_X_OFF, pairAfterX,
                 (unsigned long long)TNX_V112_INPUT_Y_OFF, pairAfterY,
                 (unsigned long long)TNX_V112_INPUT_K_OFF, pairAfterK,
                 (unsigned long long)TNX_V127_GATE_FLAG_OFF, gateAfter, modeAfter, 1,
                 wx + TNX_V129_DX, wy + TNX_V129_DY, (unsigned long long)TNX_V127_GATE_FLAG_OFF,
                 (unsigned long long)0xac3424ULL, wx + TNX_V129_DX, wy + TNX_V129_DY);

        g_v128_own_held_x = pairAfterX;
        g_v128_own_held_y = pairAfterY;
        g_v128_own_flag = gateAfter;
    }

    (void)raw_keep_x;
    (void)raw_keep_y;

    if (own && !doSetter) {
        tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &flagAfter);

        if (!tnx_read_i32(own + TNX_V127_GATE_X_OFF, &g_v128_own_held_x)) g_v128_own_held_x = 0;
        if (!tnx_read_i32(own + TNX_V127_GATE_Y_OFF, &g_v128_own_held_y)) g_v128_own_held_y = 0;

        g_v128_own_flag = flagAfter;
    }

    if (g_v128_act_logs < TNX_V128_ACT_LOGS) {
        g_v128_act_logs++;

        tnx_v144_vt_ok(own, &ownVt);

        if (ownVt >= g_base) ownCls = ownVt - g_base;

        if (g_v145_actuate_logs < 8) {
            g_v145_actuate_logs++;

            tnx_logf("v145 actuate own=%p ownFrom=%s ownClassRva=%#llx valid=%d - this is the same "
                     "value the gate line and the dodge block read, so own here and ownFound there "
                     "have to point at one element in one tick or the split is still open",
                     (void *)own, g_v145_own_from, (unsigned long long)ownCls, own ? 1 : 0);
        }

        tnx_logf("v129 actuate mode=%d call=%d doWrite=%d doSetter=%d own=%p ownFrom=%s "
                 "ownClassRva=%#llx scene=%p wrote raw+%#llx "
                 "(%d,%d) over (%d,%d) on the scene, setterRan=%d, wouldCall %#llx(own,%d,%d,%d) from "
                 "the witness "
                 "(%d,%d) - mode %d is chain-only and never reaches this line, %d writes only the raw "
                 "pair the battle update clamps for itself, %d calls only the setter and %d does both; "
                 "the pair is %d,%d and not the old %d,%d, because the message carries clamp(position + "
                 "step) and a step of hundreds is a teleport the server has no reason to accept",
                 TNX_V129_MODE, g_v128_calls, doWrite, doSetter, (void *)own, g_v145_own_from,
                 (unsigned long long)ownCls, (void *)ctrl,
                 (unsigned long long)TNX_V128_CTRL_RAW_X_OFF, raw_x, raw_y, raw_keep_x, raw_keep_y,
                 setterRan, (unsigned long long)TNX_V112_SETPRED4_RVA, wx + TNX_V129_DX,
                 wy + TNX_V129_DY,
                 TNX_V127_SETFLAG, wx, wy, TNX_V129_MODE_CHAIN, TNX_V129_MODE_WRITE,
                 TNX_V129_MODE_SETTER, TNX_V129_MODE_BOTH, TNX_V129_DX, TNX_V129_DY,
                 TNX_V128_RAW_X, TNX_V128_RAW_Y);
    }
}

static void tnx_v128_witness_line(int plus) {
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t ex = -1;
    int32_t ey = -1;
    int32_t app_x = -1;
    int32_t app_y = -1;
    int32_t raw_x = 0;
    int32_t raw_y = 0;
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    int moved = 0;
    int elemMoved = 0;

    if (!g_v128_active) return;
    if (g_v128_wit_logs >= TNX_V128_WIT_LOGS) return;

    g_v128_wit_logs++;

    tnx_v128_witness(&wx, &wy);

    if (g_v128_wit_elem) {
        if (!tnx_read_i32(g_v128_wit_elem + TNX_OBJ_X_OFF, &ex)) ex = -1;
        if (!tnx_read_i32(g_v128_wit_elem + TNX_OBJ_Y_OFF, &ey)) ey = -1;
    }

    if (ctrl) {
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &app_x)) app_x = -1;
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &app_y)) app_y = -1;
    }

    moved = (wx != g_v128_wit_x0 || wy != g_v128_wit_y0) ? 1 : 0;
    elemMoved = (ex != g_v128_wit_x1 || ey != g_v128_wit_y1) ? 1 : 0;

    if (moved) g_v128_moves++;
    if (elemMoved) g_v128_elem_moves++;

    tnx_logf("v128 witness +%d interp=(%d,%d) was=(%d,%d) moved=%d moves=%lld | elem=%p pos=(%d,%d) "
             "was=(%d,%d) elemMoved=%d elemMoves=%lld | scene raw+%#llx=(%d,%d) applied+%#llx=(%d,%d) "
             "- neither the interp pair at client+%#llx/+%#llx nor the walked element pair is written "
             "by this build any more, so a moved=1 here is the engine moving own after the injected "
             "pair and not a read back of our own store, which is the mistake the v127 direct element "
             "write made when it scored moved=1 on the very pair it had just written",
             plus, wx, wy, g_v128_wit_x0, g_v128_wit_y0, moved, (long long)g_v128_moves,
             (void *)g_v128_wit_elem, ex, ey, g_v128_wit_x1, g_v128_wit_y1, elemMoved,
             (long long)g_v128_elem_moves, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF, raw_x, raw_y,
             (unsigned long long)TNX_V128_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);

    g_v128_wit_x0 = wx;
    g_v128_wit_y0 = wy;
    g_v128_wit_x1 = ex;
    g_v128_wit_y1 = ey;
}


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







static uint64_t g_v120_reloads = 0;





static uint64_t g_v122_pre_reloads = 0;
static uint64_t g_v122_pre_frames = 0;

static uint64_t g_v121_push_frame = 0;
static uint64_t g_v121_win_reloads = 0;
static int g_v121_win_stage = 0;























static void tnx_v116_frame(void) {
    int mode = tnx_v115_mode();

    if (mode >= 0 && mode < TNX_V116_HIST_MODES) g_v116_mode_hist[mode]++;

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


static int tnx_v113_fields_pair(uintptr_t *srcOut, int32_t *xOut, int32_t *yOut) {
    uintptr_t own = tnx_v127_own_obj();
    uintptr_t src = own ? own : (uintptr_t)g_scene_object;
    int32_t x = 0;
    int32_t y = 0;

    if (srcOut) *srcOut = 0;
    if (xOut) *xOut = 0;
    if (yOut) *yOut = 0;

    if (!src) return 0;
    if (!tnx_read_i32(src + TNX_V112_INPUT_X_OFF, &x)) return 0;
    if (!tnx_read_i32(src + TNX_V112_INPUT_Y_OFF, &y)) return 0;

    if (srcOut) *srcOut = src;
    if (xOut) *xOut = x;
    if (yOut) *yOut = y;

    return 1;
}

static int tnx_v113_fields(void) {
    uintptr_t src = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_v113_fields_pair(&src, &x, &y)) return -1;

    return (x == g_v113_enq_x && y == g_v113_enq_y) ? 1 : 0;
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

    if (plus % TNX_V127_FRAME_EVERY) return;
    if (g_v113_window_logs >= 12) return;

    g_v113_window_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &inK);
    }

    tnx_logf("v113 window tick=+%d qcount=%d in10c=%d in110=%d in114=%d want=(%d,%d) match=%d - the "
             "window is one line every %d ticks instead of one per tick, because the queue drain was "
             "already shown to be steady and the per tick line only spent the log budget",
             plus, tnx_v113_queue_count(NULL), inX, inY, inK, g_v113_enq_x, g_v113_enq_y,
             tnx_v113_fields(), TNX_V127_FRAME_EVERY);
}

static void tnx_v127_statics(void) {
    static int done = 0;

    if (done) return;

    done = 1;

    tnx_logf("v127 statics, read out of the binary instead of assumed: the apply gate the queue feeds is "
             "NOT a mode id - %#llx is 'ldrb w8,[rcv+%#llx]; cmp w8,#1; b.ne' and the flag it tests is "
             "written by the setter %#llx itself as 'strb 1', so path (b) opens that door by construction "
             "while a queue message never reaches it; the applier behind the gate is %#llx, which reads "
             "the pair from +%#llx/+%#llx, takes the target from [rcv+%#llx] and calls %#llx; the "
             "cmp-against-7 that the plan hunted lives in the SCENE class %#llx slots +0x50 and +0x68 "
             "(%#llx and %#llx read [this+%#llx] against 7) and has nothing to do with the input path; "
             "the queue drain %#llx pops the tail while msg[+%#llx] <= manager+%#llx and then frees the "
             "message through %#llx without applying it, so the queue is the buffer that goes out to the "
             "server and never the local apply path; the second setter %#llx has exactly one caller, "
             "%#llx, which is the resource loader, so it is construction state and not an actuator",
             (unsigned long long)TNX_V113_READER_RVA, (unsigned long long)TNX_V127_GATE_FLAG_OFF,
             (unsigned long long)TNX_V112_SETPRED4_RVA, (unsigned long long)0x9fe350ULL,
             (unsigned long long)TNX_V127_GATE_X_OFF, (unsigned long long)TNX_V127_GATE_Y_OFF,
             (unsigned long long)TNX_V126_BOX_PTR_OFF, (unsigned long long)0x9fe4a4ULL,
             (unsigned long long)0xfe9d00ULL, (unsigned long long)0x8c7f9cULL,
             (unsigned long long)0x8c7fbcULL, (unsigned long long)0xcULL,
             (unsigned long long)0x746d18ULL, (unsigned long long)TNX_V113_SEQ_OFF,
             (unsigned long long)0x10ULL, (unsigned long long)0xd8d9f0ULL,
             (unsigned long long)0xac3f20ULL, (unsigned long long)0xa26520ULL);
}

static void tnx_v127_readback(int plus) {
    uintptr_t elem = g_v127_elem;
    int32_t elemX = -1;
    int32_t elemY = -1;
    int32_t ownX = -1;
    int32_t ownY = -1;
    int32_t ownF = -1;
    int32_t sceneX = -1;
    int32_t sceneY = -1;
    int32_t gate = -1;
    int elemHeld = 0;
    int ownHeld = 0;
    int fldHeld = 0;

    if (g_v127_rb_logs >= TNX_V127_READBACK_LOGS) return;

    g_v127_rb_logs++;

    if (elem && tnx_read_i32(elem + TNX_OBJ_X_OFF, &elemX) &&
        tnx_read_i32(elem + TNX_OBJ_Y_OFF, &elemY)) {
        elemHeld = (elemX == g_v113_enq_x + TNX_V127_DX_ELEM &&
                    elemY == g_v113_enq_y + TNX_V127_DY_ELEM) ? 1 : 0;
    }

    if (g_v127_own_obj) {
        tnx_read_i32(g_v127_own_obj + TNX_V127_GATE_X_OFF, &ownX);
        tnx_read_i32(g_v127_own_obj + TNX_V127_GATE_Y_OFF, &ownY);
        tnx_read_i32(g_v127_own_obj + TNX_V127_GATE_FLAG_OFF, &gate);
        tnx_read_i32(g_v127_own_obj + TNX_V126_OWN_OFF, &ownF);
        ownHeld = (ownX == g_v113_enq_x + TNX_V127_DX_SETTER &&
                   ownY == g_v113_enq_y + TNX_V127_DY_SETTER) ? 1 : 0;
    }

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &sceneX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &sceneY);
    }

    fldHeld = tnx_v113_fields();

    if (g_v113_readback < 0) g_v113_readback = 0;

    tnx_logf("v127 readback +%d elem=%p held=%d now=(%d,%d) want=(%d,%d) was=(%d,%d) | own=%p "
             "in10c=%d in110=%d held=%d flag%#llx=%d | scene10c=%d scene110=%d fld=%d | q=%d - read a "
             "whole second after the three writes and not four frames later, because a server that "
             "reconciles the position on a short cadence turns a four frame probe into a false success: "
             "elemHeld names path (c) the direct element pair, ownHeld names path (b) the setter %#llx "
             "store on the getOwnCharacter receiver, and the queue count together with the seq counter "
             "names path (a) the message; whichever of the three holds after a second is the actuator",
             plus, (void *)elem, elemHeld, elemX, elemY, g_v113_enq_x + TNX_V127_DX_ELEM,
             g_v113_enq_y + TNX_V127_DY_ELEM, g_v127_elem_x0, g_v127_elem_y0, (void *)g_v127_own_obj,
             ownX, ownY, ownHeld, (unsigned long long)TNX_V127_GATE_FLAG_OFF, gate, sceneX, sceneY,
             fldHeld, tnx_v113_queue_count(NULL), (unsigned long long)TNX_V112_SETPRED4_RVA);

    (void)ownF;
}

static void tnx_v113_test(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    int32_t x = 0;
    int32_t y = 0;
    int qnow = -1;
    const char *verdict = "readback-unreadable";

    if (!objects || usable <= 0) return;
    if (g_v113_test_state >= 4) return;
    if (!g_scene_object) return;

    if (ownIndex < 0 || ownIndex >= usable) ownIndex = 0;

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

        tnx_v129_chain();

        if (!tnx_v128_witness(&g_v128_wit_x0, &g_v128_wit_y0)) {
            g_v128_wit_x0 = objects[ownIndex].x;
            g_v128_wit_y0 = objects[ownIndex].y;
        } else {
            g_v128_have_wit = 1;
        }

        g_v128_wit_elem = objects[ownIndex].object;
        g_v128_wit_x1 = objects[ownIndex].x;
        g_v128_wit_y1 = objects[ownIndex].y;
        g_v128_calls = 0;
        g_v128_moves = 0;
        g_v128_elem_moves = 0;

        g_v113_enq_x = g_v128_wit_x0 + TNX_V129_DX;
        g_v113_enq_y = g_v128_wit_y0 + TNX_V129_DY;

        if (TNX_V129_MODE == TNX_V129_MODE_CHAIN) {
            g_v113_test_state = 4;
            g_v113_tested = 1;

            tnx_logf("v129 chain-only mode=%d own=%p ownFromWitness=(%d,%d) elem=%p elemPos=(%d,%d) "
                     "slotOwn=%p slotIdx=%d slotGid=%d expect=%d queue=%d - nothing is written in this "
                     "mode on purpose: the chain check has to answer whether the scene the walk holds "
                     "is the object whose +%#llx the battle update clamps, and whether own is an "
                     "element of hop0, before any write is allowed to look like a result",
                     TNX_V129_MODE, (void *)tnx_v127_own_obj(), g_v128_wit_x0, g_v128_wit_y0,
                     (void *)g_v128_wit_elem, g_v128_wit_x1, g_v128_wit_y1, (void *)g_v129_own_slot,
                     g_v129_own_slot_idx, g_v129_own_slot_gid, TNX_V129_OWN_EXPECT_GID,
                     tnx_v113_queue_count(NULL), (unsigned long long)TNX_V128_CTRL_RAW_X_OFF);

            return;
        }

        g_v128_active = 1;

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


        g_v121_push_frame = g_v48_ticks;
        g_v121_win_stage = 0;
        g_v121_win_reloads = g_v120_reloads;

        if (TNX_V129_MODE == TNX_V129_MODE_BOTH) {
            tnx_v113_enqueue(g_v113_enq_x, g_v113_enq_y);

            g_v113_q_before = g_v126_q_before;
            g_v113_q_after = g_v126_q_after;
        }

        tnx_v127_setter(g_v113_enq_x + TNX_V127_DX_SETTER, g_v113_enq_y + TNX_V127_DY_SETTER);
        tnx_v127_elem_write(objects[ownIndex].object,
                            g_v113_enq_x + TNX_V127_DX_ELEM, g_v113_enq_y + TNX_V127_DY_ELEM);

        tnx_v128_probe();
        tnx_v128_actuate();

        tnx_logf("v129 test mode=%d pair=(%d,%d) enum dest=(%d,%d) enq=%d seq %d->%d q %d->%d qLast=%p "
                 "| write=%d setter=%d scene=%p rawOff=%#llx setterFn=%#llx own=%p | witnesses elem=%p "
                 "(%d,%d) interp=(%d,%d) - the three channels are no longer fired together: %d only "
                 "writes the raw pair on the scene, %d only calls the setter on own, %d does both and "
                 "also pushes the nearby destination so the queue is measured apart from the two local "
                 "channels, and the walked element is written by none of them",
                 TNX_V129_MODE, g_v113_enq_x, g_v113_enq_y, g_v128_wit_x0, g_v128_wit_y0,
                 g_v128_wit_x0 + TNX_V129_DX, g_v128_wit_y0 + TNX_V129_DY,
                 g_v126_enq_ok, g_v126_seq_before, g_v126_seq_after, g_v126_q_before, g_v126_q_after,
                 g_v126_q_last, (void *)g_scene_object,
                 (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
                 (unsigned long long)TNX_V112_SETPRED4_RVA, (void *)tnx_v127_own_obj(),
                 (void *)g_v128_wit_elem, g_v128_wit_x1, g_v128_wit_y1, g_v128_wit_x0, g_v128_wit_y0,
                 TNX_V129_MODE_WRITE, TNX_V129_MODE_SETTER, TNX_V129_MODE_BOTH);

        tnx_v113_window(0);

        return;
    }

    if (g_v113_test_state == 1) {
        int plus = (int)(g_v103_tick - g_v113_test_tick);

        tnx_v128_actuate();
        tnx_v128_witness_line(plus);

        if (g_v113_readback < 0 && tnx_v113_fields() == 1) {
            g_v113_readback = 1;
            g_v113_readback_tick = plus;
        }

        if (plus < TNX_V127_READBACK_TICKS) {
            tnx_v113_window(plus);

            return;
        }

        tnx_v127_readback(plus);

        g_v113_test_state = 2;

        if (g_v113_readback < 0) g_v113_readback = 0;

        qnow = tnx_v113_queue_count(NULL);

        tnx_logf("v127 test short before=(%d,%d) after=(%d,%d) qAfter=%d qNow=%d readback=%d atTick=%d - "
                 "the walked element is a hop2 brawler in this build, so before and after here are its "
                 "int pair at +%#llx/+%#llx and not a roster slot: the hop2 list is adopted because the "
                 "roster wins on ids while every one of its positions is (0,0), and an id is worth "
                 "nothing to a dodge that needs coordinates",
                 g_v113_test_before_x, g_v113_test_before_y, objects[ownIndex].x, objects[ownIndex].y,
                 g_v113_q_after, qnow, g_v113_readback, g_v113_readback_tick,
                 (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

        return;
    }

    if (g_v103_tick - g_v113_test_tick < TNX_V113_LONG_TICKS) {
        tnx_v128_actuate();
        tnx_v128_witness_line((int)(g_v103_tick - g_v113_test_tick));

        return;
    }

    g_v113_test_state = 4;
    g_v113_tested = 1;
    g_v128_active = 0;

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

    tnx_logf("v128 summary calls=%d haveWit=%d interp=(%d,%d) interpMoves=%lld elem=%p elemPos=(%d,%d) "
             "elemMoves=%lld ownFlag=%d ownPair=(%d,%d) - the verdict below is computed from the walked "
             "element, but that element is not written anywhere in this build, so it can only change if "
             "the engine moved own; the interp pair at client+%#llx/+%#llx is the second witness and "
             "the own pair is the field the setter %#llx stores, which the engine is expected to "
             "rewrite on its own events and therefore never to survive a whole second",
             g_v128_calls, g_v128_have_wit, g_v128_wit_x0, g_v128_wit_y0, (long long)g_v128_moves,
             (void *)g_v128_wit_elem, g_v128_wit_x1, g_v128_wit_y1, (long long)g_v128_elem_moves,
             g_v128_own_flag, g_v128_own_held_x, g_v128_own_held_y,
             (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF,
             (unsigned long long)TNX_V112_SETPRED4_RVA);

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

    tnx_v101_own_index_probe();

    tnx_v102_own_probe();
    tnx_v102_audit_all();

    g_v103_tick++;
    tnx_v113_queue_line();

    if (!g_v101_setpred) g_v101_setpred = tnx_v101_entry(TNX_V101_MODEPAIRSET_RVA);

    if (!g_v101_setpred && g_v101_own_logs < 2) {
        tnx_logf("v101 setter candidate rva=%#llx is not an entry point on this build - the leaf "
                 "setter the audit names starts with a store and carries no frame, so its call "
                 "cannot be armed and the actuator has to go through the input manager instead",
                 (unsigned long long)TNX_V101_MODEPAIRSET_RVA);
    }


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



    if (!g_v95_find_joy_done) {
        g_v95_find_joy_done = 1;

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
    tnx_v129_chain();

    if (TNX_V129_MODE == TNX_V129_MODE_CHAIN) {
        g_v113_test_state = 4;
        g_v113_tested = 1;
    }

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

            ownFound = tnx_v128_resolve_own(objects, usable, &ownIndex, &ownFrom);

            if (!ownFound) ownFound = tnx_v91_resolve_own(objects, usable, &ownIndex, &ownFrom);

            if (!ownFound) ownFound = tnx_v102_take_own(objects, usable, &ownIndex, &ownFrom);

             


            if (ownFound && ownIndex >= 0 && ownIndex < usable) {
                tnx_v146_phase("own");

        tnx_v145_publish_own(objects[ownIndex].object, ownFrom);
            }

            tnx_v102_write_test(objects, usable, ownFound ? ownIndex : -1);

            tnx_v113_hop2();
            tnx_v113_test(objects, usable, ownFound ? ownIndex : -1);
            tnx_v127_statics();
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

 










typedef struct {
    uintptr_t elem;
    uintptr_t classRva;
    int32_t x;
    int32_t y;
    int32_t px;
    int32_t py;
    int hasPrev;
} tnx_v140_proj_t;

static tnx_v140_proj_t g_v140_projs[TNX_V140_PROJ_MAX];
static int g_v140_side_hits = 0;
static int g_v140_side_projs = 0;
static int g_v140_side_logs = 0;
static int g_v140_write_logs = 0;

static int tnx_v140_proj_scan(uintptr_t manager, int32_t count) {
    void *array = NULL;
    int found = 0;
    int k;
    int32_t i;

    if (!manager || count <= 0) return 0;
    if (count > TNX_V56_COUNT_MAX) count = TNX_V56_COUNT_MAX;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        g_v140_projs[k].classRva = (uintptr_t)-1;
    }

    for (i = 0; i < count && found < TNX_V140_PROJ_MAX; i++) {
        void *element = NULL;
        void *vtable = NULL;
        uintptr_t vtRva = 0;
        int32_t gid = 0;
        int32_t px = 0;
        int32_t py = 0;
        int slot = -1;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable) || !vtable) continue;

        vtRva = (uintptr_t)vtable - g_base;

        gid = tnx_v106_gid((uintptr_t)element, NULL);

        if (gid < TNX_V138_PLAYER_GID_MAX) continue;

         





        {
            static uintptr_t seenCls[4] = { 0, 0, 0, 0 };
            static int seenClsN = 0;
            int si;
            int known = 0;

            for (si = 0; si < seenClsN; si++) {
                if (seenCls[si] == vtRva) {
                    known = 1;

                    break;
                }
            }

            if (!known && seenClsN < 4) {
                seenCls[seenClsN++] = vtRva;

                tnx_logf("v142 proj class seen classRva=%#llx gid=%d classes=%d/4 - every class "
                         "named here is fed to the threat test, and one whose pair at +%#llx/+%#llx "
                         "does not move drops out on its own",
                         (unsigned long long)vtRva, gid, seenClsN,
                         (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);
            }
        }

        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py)) continue;

         



        for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
            if (g_v140_projs[k].elem != (uintptr_t)element) continue;

            slot = k;

            break;
        }

        if (slot < 0) {
            for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
                if (g_v140_projs[k].classRva != (uintptr_t)-1) continue;

                slot = k;

                break;
            }
        }

        if (slot < 0) continue;

        if (g_v140_projs[slot].elem == (uintptr_t)element) {
            g_v140_projs[slot].px = g_v140_projs[slot].x;
            g_v140_projs[slot].py = g_v140_projs[slot].y;
            g_v140_projs[slot].hasPrev = 1;
        } else {
            g_v140_projs[slot].elem = (uintptr_t)element;
            g_v140_projs[slot].px = px;
            g_v140_projs[slot].py = py;
            g_v140_projs[slot].hasPrev = 0;
        }

        g_v140_projs[slot].classRva = vtRva;
        g_v140_projs[slot].x = px;
        g_v140_projs[slot].y = py;

        found++;
    }

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        if (g_v140_projs[k].classRva != (uintptr_t)-1) continue;

        g_v140_projs[k].elem = 0;
        g_v140_projs[k].hasPrev = 0;
    }


    return found;
}

static float tnx_v153_clearance(float px, float py, int skipK) {
    float best = 100000.0f;
    int k;

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        const tnx_v140_proj_t *p = &g_v140_projs[k];
        float dx;
        float dy;
        float dd;
        float rx;
        float ry;
        float t;
        float hx;
        float hy;
        float ax;
        float ay;
        float d;

        if (k == skipK) continue;
        if (!p->elem || !p->hasPrev) continue;

        dx = (float)(p->x - p->px);
        dy = (float)(p->y - p->py);
        dd = dx * dx + dy * dy;

        if (dd < 1.0f) continue;

        rx = px - (float)p->x;
        ry = py - (float)p->y;

        t = (rx * dx + ry * dy) / dd;

        if (t < 0.0f || t > TNX_V153_THREAT_TICKS) continue;

        hx = (float)p->x + dx * t;
        hy = (float)p->y + dy * t;
        ax = px - hx;
        ay = py - hy;
        d = sqrtf(ax * ax + ay * ay);

        if (d < best) best = d;
    }

    return best;
}

static int tnx_v140_sidestep(int32_t ox, int32_t oy, float *sumX, float *sumY, int *hitsOut,
                             int *seenOut) {
    float sx = 0.0f;
    float sy = 0.0f;
    int hits = 0;
    int seen = 0;
    int k;

    if (sumX) *sumX = 0.0f;
    if (sumY) *sumY = 0.0f;
    if (hitsOut) *hitsOut = 0;
    if (seenOut) *seenOut = 0;

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        const tnx_v140_proj_t *p = &g_v140_projs[k];
        float dx;
        float dy;
        float dd;
        float vx;
        float vy;
        float t;
        float hx;
        float hy;
        float ex;
        float ey;
        float dist;
        float len;
        float ux;
        float uy;
        float side;
        float w;

        if (!p->elem || !p->hasPrev) continue;

        seen++;

        dx = (float)(p->x - p->px);
        dy = (float)(p->y - p->py);
        dd = dx * dx + dy * dy;

        if (dd < 1.0f) continue;

        vx = (float)(ox - p->x);
        vy = (float)(oy - p->y);

        t = (vx * dx + vy * dy) / dd;

        if (t < 0.0f) continue;
        if (t > TNX_V153_THREAT_TICKS) continue;

        hx = (float)p->x + dx * t;
        hy = (float)p->y + dy * t;

        ex = (float)ox - hx;
        ey = (float)oy - hy;
        dist = sqrtf(ex * ex + ey * ey);

        if (dist > TNX_V140_THREAT_RADIUS) continue;

        len = sqrtf(dd);
        ux = -dy / len;
        uy = dx / len;

        side = ((vx * ux + vy * uy) > 0.0f) ? 1.0f : -1.0f;
        w = (TNX_V140_THREAT_RADIUS - dist) / TNX_V140_THREAT_RADIUS;

        sx += ux * side * w;
        sy += uy * side * w;
        hits++;

        if (g_v151_best_dist < 0.0f || t < g_v153_best_t) {
            g_v151_best_dist = dist;
            g_v153_best_t = t;
            g_v151_best_x = ux * side;
            g_v151_best_y = uy * side;
            g_v153_best_k = k;
        }
    }

    if (g_v151_best_dist >= 0.0f && g_v153_best_k >= 0) {
        const tnx_v140_proj_t *b = &g_v140_projs[g_v153_best_k];
        float bdx = (float)(b->x - b->px);
        float bdy = (float)(b->y - b->py);
        float blen = sqrtf(bdx * bdx + bdy * bdy);

        if (blen >= 1.0f) {
            float bux = -bdy / blen;
            float buy = bdx / blen;
            float exit = TNX_V153_EXIT_DIST;
            float cPlus = tnx_v153_clearance((float)b->x + bux * exit, (float)b->y + buy * exit,
                                             g_v153_best_k);
            float cMinus = tnx_v153_clearance((float)b->x - bux * exit, (float)b->y - buy * exit,
                                              g_v153_best_k);
            float chosen = (cPlus >= cMinus) ? 1.0f : -1.0f;

            if (cPlus == cMinus) {
                chosen = (((float)(ox - b->x) * bux + (float)(oy - b->y) * buy) > 0.0f) ? 1.0f : -1.0f;
            }

            g_v151_best_x = bux * chosen;
            g_v151_best_y = buy * chosen;
            g_v153_side = (chosen > 0.0f) ? 1 : -1;

            if (g_v153_logs < TNX_V153_LOGS) {
                g_v153_logs++;

                tnx_logf("v153 side pick bestDist=%.0f bestT=%.1f plus=%.0f minus=%.0f chosen=%d "
                         "tmax=%d - both exit points are tested against every other projectile on "
                         "a ray and the side with the larger clearance wins, because the old rule "
                         "took the side the character already stood on and could step straight "
                         "into a second shot", (double)g_v151_best_dist, (double)g_v153_best_t,
                         (double)cPlus, (double)cMinus, g_v153_side, TNX_V153_THREAT_TICKS);
            }
        }
    }

    if (sumX) *sumX = sx;
    if (sumY) *sumY = sy;
    if (hitsOut) *hitsOut = hits;
    if (seenOut) *seenOut = seen;

    g_v151_best_hit = hits;

    return hits;
}

static int g_v148_probe_logs = 0;

static uintptr_t tnx_v148_cls(uintptr_t obj) {
    uintptr_t vt = 0;

    if (!tnx_v144_vt_ok(obj, &vt)) return 0;

    return (vt >= g_base) ? (vt - g_base) : 0;
}

static void tnx_v148_receiver_line(const char *name, uintptr_t holder) {
    void *wrap = NULL;
    void *inner = NULL;
    int32_t rawX = -1;
    int32_t rawY = -1;
    int32_t dirty = -1;
    int32_t appX = -1;
    int32_t appY = -1;
    int32_t gate = -1;
    int32_t gx = -1;
    int32_t gy = -1;
    int32_t gk = -1;
    int innerOk = 0;

    if (holder) {
        tnx_read_i32(holder + TNX_V128_CTRL_RAW_X_OFF, &rawX);
        tnx_read_i32(holder + TNX_V128_CTRL_RAW_Y_OFF, &rawY);
        tnx_read_i32(holder + TNX_V128_CTRL_DIRTY_OFF, &dirty);
        tnx_read_i32(holder + TNX_V128_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(holder + TNX_V128_CTRL_APPLIED_Y_OFF, &appY);
        tnx_read_ptr(holder + TNX_V140_CTRL_MODE_OFF, &wrap);
    }

    if (wrap) tnx_read_ptr((uintptr_t)wrap + TNX_V126_OWN_INNER_OFF, &inner);

    if (inner) {
        innerOk = tnx_v144_vt_ok((uintptr_t)inner, NULL);
        tnx_read_i32((uintptr_t)inner + TNX_V127_GATE_FLAG_OFF, &gate);
        tnx_read_i32((uintptr_t)inner + TNX_V127_GATE_X_OFF, &gx);
        tnx_read_i32((uintptr_t)inner + TNX_V127_GATE_Y_OFF, &gy);
        tnx_read_i32((uintptr_t)inner + TNX_V112_INPUT_K_OFF, &gk);
    }

    tnx_logf("v148 receiver %s holder=%p holderCls=%#llx raw=(%d,%d) dirty=%d applied=(%d,%d) "
             "wrap=[+%#llx]=%p wrapCls=%#llx inner=[wrap+%#llx]=%p innerCls=%#llx innerOk=%d "
             "gate=%d pair=(%d,%d,%d) - the engine reaches the actuator receiver by dereferencing "
             "the hop field of one holder and taking the inner slot of the result, so the holder "
             "whose inner is non null with a class in __DATA_CONST is the one to call and every "
             "other holder is named here to be excluded; battle-global comes from %#llx",
             name, (void *)holder, (unsigned long long)tnx_v148_cls(holder), rawX, rawY, dirty,
             appX, appY, (unsigned long long)TNX_V140_CTRL_MODE_OFF, (void *)wrap,
             (unsigned long long)tnx_v148_cls((uintptr_t)wrap),
             (unsigned long long)TNX_V126_OWN_INNER_OFF, (void *)inner,
             (unsigned long long)tnx_v148_cls((uintptr_t)inner), innerOk, gate, gx, gy, gk,
             (unsigned long long)TNX_V129_BATTLE_RVA);
}

static void tnx_v148_receiver_probe(void) {
    uintptr_t battle = 0;
    void *battleRaw = NULL;

    if (g_v148_probe_logs >= TNX_V148_PROBE_LOGS) return;

    g_v148_probe_logs++;

    tnx_v148_receiver_line("scene", (uintptr_t)g_scene_object);
    tnx_v148_receiver_line("players", g_players_object);

    if (g_base && tnx_read_ptr(g_base + TNX_V129_BATTLE_RVA, &battleRaw)) {
        battle = (uintptr_t)battleRaw;
    }

    tnx_v148_receiver_line("battle-global", battle);
}

static uintptr_t tnx_v150_qword(uintptr_t addr) {
    int32_t lo = 0;
    int32_t hi = 0;

    tnx_read_i32(addr, &lo);
    tnx_read_i32(addr + 4, &hi);

    return ((uintptr_t)(uint32_t)lo) | ((uintptr_t)(uint32_t)hi << 32);
}

static uintptr_t tnx_v150_controller(void) {
    void *raw = NULL;

    if (!g_base) return 0;
    if (!tnx_read_ptr(g_base + TNX_V129_BATTLE_RVA, &raw) || !raw) return 0;
    if (((uintptr_t)raw & 7) != 0) return 0;
    if (!tnx_addr_readable((uintptr_t)raw, 0x1000)) return 0;

    return (uintptr_t)raw;
}

static int tnx_v150_pointer_like(uintptr_t v) {
    return (v >= 0x100000000ULL && v < 0x200000000ULL && (v & 7) == 0);
}

static int tnx_v150_obj_ok(uintptr_t cand) {
    if (!cand) return 0;
    if (cand & 7) return 0;
    if (!tnx_addr_readable(cand, 0x120)) return 0;

    return 1;
}

static int tnx_v150_safe_to_write(uintptr_t obj) {
    if (tnx_v150_pointer_like(tnx_v150_qword(obj + 0x108))) return 0;
    if (tnx_v150_pointer_like(tnx_v150_qword(obj + 0x118))) return 0;

    return 1;
}

static uintptr_t tnx_v144_mode_pick(uintptr_t *vtOut, const char **whoOut, const char **whyOut) {
    uintptr_t cand[3];
    const char *names[3] = { "controller-hop", "scene-hop", "players-hop" };
    uintptr_t ctrl = tnx_v150_controller();
    int i;

    cand[0] = ctrl ? tnx_v144_hop(ctrl, NULL) : 0;
    cand[1] = tnx_v144_hop((uintptr_t)g_scene_object, NULL);
    cand[2] = tnx_v144_hop((uintptr_t)g_players_object, NULL);

    if (vtOut) *vtOut = 0;
    if (whoOut) *whoOut = "none";
    if (whyOut) *whyOut = "none-ok";

    for (i = 0; i < 3; i++) {
        const char *why = "not-readable";
        uintptr_t vt = 0;
        int ok = 0;

        if (i == 0) {
            ok = tnx_v150_obj_ok(cand[i]);
        } else {
            ok = tnx_v144_cand_ok(cand[i], &why, &vt);
        }

        if (ok) {
            if (vtOut) *vtOut = vt;
            if (whoOut) *whoOut = names[i];
            if (whyOut) *whyOut = why;

            return cand[i];
        }

        if (g_v144_cand_logs < TNX_V144_CAND_LOGS) {
            g_v144_cand_logs++;

            tnx_logf("v150 candidate #%d %s ptr=%p vt=%p reject=%s ctrl=%p wrap=%p - the controller "
                     "hop is tried first because the battle object at %#llx carries the live raw "
                     "pair and its hop slot holds the wrapper whose inner slot mirrors the applied "
                     "pair, so the inner of that hop is the object the engine passes to the "
                     "actuator and the other candidates are named to be excluded",
                     i, names[i], (void *)cand[i], (void *)vt, why, (void *)ctrl,
                     ctrl ? (void *)tnx_v144_hop(ctrl, NULL) : (void *)0,
                     (unsigned long long)TNX_V129_BATTLE_RVA);
        }
    }

    return 0;
}

static int tnx_v144_mode_write(int x, int y, int flag) {
    uintptr_t fn = tnx_v113_entry(TNX_V140_MODEPAIR_RVA);
    uintptr_t vt = 0;
    const char *who = "none";
    const char *why = "none-ok";
    uintptr_t mode = 0;
    int32_t beforeGate = -1;
    int32_t beforeX = 0;
    int32_t beforeY = 0;
    int32_t beforeK = 0;
    int32_t afterGate = -1;
    int32_t afterX = 0;
    int32_t afterY = 0;
    int32_t afterK = 0;
    int kept = 0;

    if (!fn || !tnx_callable(TNX_V140_MODEPAIR_RVA)) {
        if (g_v140_write_logs < TNX_V140_WRITE_LOGS) {
            g_v140_write_logs++;

            tnx_logf("v144 actuate skip: actuator not callable fn=%p rva=%#llx scene=%p", (void *)fn,
                     (unsigned long long)TNX_V140_MODEPAIR_RVA, (void *)g_scene_object);
        }

        return 0;
    }

    tnx_v146_phase("mode-pick");

    mode = tnx_v144_mode_pick(&vt, &who, &why);

    if (!mode) {
        if (g_v140_write_logs < TNX_V140_WRITE_LOGS) {
            g_v140_write_logs++;

            tnx_logf("v144 actuate skip: no valid this why=%s scene=%p players=%p listOwn=%p "
                     "sceneMode=%p playersMode=%p - the call is not made at all rather than made "
                     "with an unchecked pointer, and the reject reason names the check that failed",
                     why, (void *)g_scene_object, (void *)g_players_object, (void *)g_v144_own_elem,
                     (void *)tnx_v144_hop((uintptr_t)g_scene_object, NULL),
                     (void *)tnx_v144_hop((uintptr_t)g_players_object, NULL));
        }

        return 0;
    }

    if (!tnx_v150_safe_to_write(mode)) {
        if (g_v150_logs < 8) {
            g_v150_logs++;

            tnx_logf("v150 actuate refuse obj=%p q108=%#llx q118=%#llx - a pointer shaped qword sits "
                     "next to the pair offsets on this object, and the same layout on the container "
                     "element is what aborted the 146 run, so nothing is written and the next tick "
                     "is free to try again", (void *)mode,
                     (unsigned long long)tnx_v150_qword(mode + 0x108),
                     (unsigned long long)tnx_v150_qword(mode + 0x118));
        }

        return 0;
    }

    tnx_read_i32(mode + TNX_V127_GATE_FLAG_OFF, &beforeGate);
    tnx_read_i32(mode + TNX_V127_GATE_X_OFF, &beforeX);
    tnx_read_i32(mode + TNX_V127_GATE_Y_OFF, &beforeY);
    tnx_read_i32(mode + TNX_V112_INPUT_K_OFF, &beforeK);

    if (g_v140_write_logs < TNX_V140_WRITE_LOGS) {
        g_v140_write_logs++;

        tnx_logf("v144 actuate own=%p vt=%p from=%s want=(%d,%d) flag=%d gateBefore=%d - vt has to be "
                 "compared against the element classes the census prints (0xff57b0 for the moving "
                 "ones) to settle whether the actuator receiver is the element or the mode object",
                 (void *)mode, (void *)vt, who, x, y, flag, beforeGate);
    }

    tnx_v146_phase("mode-call");

    ((void (*)(void *, int, int, int))fn)((void *)mode, x, y, flag);

    tnx_v146_phase("mode-readback");

    tnx_read_i32(mode + TNX_V127_GATE_FLAG_OFF, &afterGate);
    kept = (tnx_read_i32(mode + TNX_V127_GATE_X_OFF, &afterX) && afterX == x) ? 1 : 0;
    tnx_read_i32(mode + TNX_V127_GATE_Y_OFF, &afterY);
    tnx_read_i32(mode + TNX_V112_INPUT_K_OFF, &afterK);

    if (g_v140_write_logs < TNX_V140_WRITE_LOGS) {
        g_v140_write_logs++;

        tnx_logf("v144 mode-write own=%p vt=%p from=%s want=(%d,%d) flag=%d gateBefore=%d "
                 "gateAfter=%d before=(%d,%d,%d) after=(%d,%d,%d) kept=%d - kept is the read back of "
                 "the pair the engine consumes at 0xac3424, so gateAfter=1 with kept=1 is the only "
                 "combination that means the next logic tick has a destination",
                 (void *)mode, (void *)vt, who, x, y, flag, beforeGate, afterGate, beforeX, beforeY,
                 beforeK, afterX, afterY, afterK, kept);
    }

    return kept;
}

static float tnx_v154_clearance(float px, float py) {
    float best = 1000000.0f;
    int k;

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        const tnx_v140_proj_t *p = &g_v140_projs[k];
        float dx;
        float dy;
        float dd;
        float rx;
        float ry;
        float t;
        float hx;
        float hy;
        float ax;
        float ay;
        float d;

        if (!p->elem || !p->hasPrev) continue;

        dx = (float)(p->x - p->px);
        dy = (float)(p->y - p->py);
        dd = dx * dx + dy * dy;

        if (dd < 1.0f) continue;

        rx = px - (float)p->x;
        ry = py - (float)p->y;

        t = (rx * dx + ry * dy) / dd;

        if (t < 0.0f) t = 0.0f;
        if (t > (float)TNX_V153_THREAT_TICKS) t = (float)TNX_V153_THREAT_TICKS;

        hx = (float)p->x + dx * t;
        hy = (float)p->y + dy * t;
        ax = px - hx;
        ay = py - hy;
        d = sqrtf(ax * ax + ay * ay) - TNX_V154_INFLATE;

        if (d < best) best = d;
    }

    return best;
}

static int tnx_v154_threatened(float px, float py) {
    return tnx_v154_clearance(px, py) < 0.0f;
}

static float g_v155_block_ang[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
static uint64_t g_v155_block_until[4] = { 0, 0, 0, 0 };
static int g_v155_block_next = 0;
static float g_v155_prev_dist = 0.0f;
static int g_v155_stall = 0;
static uint64_t g_v155_stalls = 0;
static int g_v155_logs = 0;

static int tnx_v155_is_blocked(float ang) {
    int i;

    for (i = 0; i < 4; i++) {
        float d;

        if (g_v155_block_until[i] <= g_v47_ticks) continue;

        d = ang - g_v155_block_ang[i];

        while (d > (float)M_PI) d -= 2.0f * (float)M_PI;
        while (d < -(float)M_PI) d += 2.0f * (float)M_PI;

        if (d > -TNX_V155_BLOCK_WIDTH && d < TNX_V155_BLOCK_WIDTH) return 1;
    }

    return 0;
}

static void tnx_v155_block(float ang) {
    g_v155_block_ang[g_v155_block_next] = ang;
    g_v155_block_until[g_v155_block_next] = g_v47_ticks + TNX_V155_BLOCK_TICKS;
    g_v155_block_next = (g_v155_block_next + 1) & 3;
    g_v155_stalls++;

    if (g_v155_logs < TNX_V155_LOGS) {
        g_v155_logs++;

        tnx_logf("v155 direction blocked ang=%.2f for %d ticks stalls=%llu - a held target that "
                 "the character stops getting closer to is not reachable, the destination was "
                 "accepted by the engine and the walk did not happen, so the bearing to it is "
                 "remembered and the next search skips it instead of reissuing the same pointless "
                 "destination", (double)ang, TNX_V155_BLOCK_TICKS, (unsigned long long)g_v155_stalls);
    }
}

static int tnx_v154_best(int32_t px, int32_t py, float desX, float desY, int32_t *txOut,
                         int32_t *tyOut) {
    float base = 0.0f;
    float bestClear = -1000000.0f;
    float bestDist = 1000000.0f;
    int32_t bestX = 0;
    int32_t bestY = 0;
    int found = 0;
    int i;

    g_v154_searches++;

    if (desX != 0.0f || desY != 0.0f) {
        base = atan2f(desY, desX);
    } else if (g_v151_best_x != 0.0f || g_v151_best_y != 0.0f) {
        base = atan2f(g_v151_best_y, g_v151_best_x);
    }

    for (i = 0; i < TNX_V154_ANGLES; i++) {
        int order = (i + 1) / 2;
        float sign = (i % 2 == 0) ? 1.0f : -1.0f;
        float ang = base + sign * (float)order * (2.0f * (float)M_PI / (float)TNX_V154_ANGLES);
        float ux = cosf(ang);
        float uy = sinf(ang);
        float lastSafe = 0.0f;
        float lastClear = 0.0f;
        float d;

        if (tnx_v155_is_blocked(ang)) continue;

        for (d = TNX_V154_STEP; d <= TNX_V155_MAX_DIST; d += TNX_V154_STEP) {
            float cx = (float)px + ux * d;
            float cy = (float)py + uy * d;
            float clear = tnx_v154_clearance(cx, cy);

            if (clear < 0.0f) break;

            lastSafe = d;
            lastClear = clear;
        }

        if (lastSafe <= 0.0f) continue;

        if (!found || lastClear > bestClear || (lastClear == bestClear && lastSafe > bestDist)) {
            bestClear = lastClear;
            bestDist = lastSafe;
            bestX = (int32_t)((float)px + ux * lastSafe);
            bestY = (int32_t)((float)py + uy * lastSafe);
            found = 1;
        }
    }

    if (!found) return 0;

    if (txOut) *txOut = bestX;
    if (tyOut) *tyOut = bestY;

    return 1;
}

static void tnx_autododge_v48(void) {
    tnx_v146_phase("dodge-enter");

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

    g_v138_dodge_calls++;

    if (g_v138_dodge_calls <= TNX_V138_CALL_LOGS ||
        (g_v138_dodge_calls % TNX_V138_CALL_EVERY) == 0) {
        tnx_logf("v138 dodge CALLED n=%llu base=%p scene=%p container=%p array=%p count=%d hop=%d "
                 "gidFloor=%d gidMax=%d playerMax=%d - printed before every early return and keyed "
                 "on the number of calls and not on a tick counter, because the v137 run printed no "
                 "probe line at all and the two possible reasons, a gate before the line and a "
                 "counter that never advanced, cannot be told apart from the absence of a line",
                 (unsigned long long)g_v138_dodge_calls, (void *)g_base, (void *)g_scene_object,
                 (void *)g_players_object, (void *)g_players_array, g_players_count, g_v82_hop_chosen,
                 TNX_V75_GID_FLOOR, TNX_V75_GID_MAX, TNX_V138_PLAYER_GID_MAX);
    }

    if (!g_base) return;

    if (g_v138_dodge_calls <= TNX_V138_CALL_LOGS ||
        (g_v138_dodge_calls % TNX_V138_CALL_EVERY) == 0) {
        uintptr_t probeOwn = 0;
        int32_t probeGid = 0;
        int32_t probeTeam = 0;
        int32_t probeCount = 0;

        g_v135_probe_tick = g_v50_ticks;

        tnx_v134_own_by_min_gid(g_v142_tick_array, g_v142_tick_count, &probeOwn, &probeGid);

        if (probeOwn) tnx_read_i32(probeOwn + TNX_OBJ_TEAM_OFF, &probeTeam);
        if (g_players_object) tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &probeCount);

        {
            int listIdx = -1;
            const char *listFrom = "none";
            int32_t listGid = -1;

            if (tnx_v134_own_from_list(g_dodge_probe_list, g_dodge_probe_usable, &listIdx, &listFrom)) {
                listGid = g_dodge_probe_list[listIdx].gid;
            }

            tnx_logf("v135 dodge list usable=%d from=%s idx=%d gid=%d minGidSeen=%d chosenGid=%d "
                     "chosenIdx=%d - the resolver runs on the very array the walk collected and "
                     "reports which entry it picked, so a disagreement between the smallest id seen "
                     "and the id chosen is visible in one line instead of being inferred",
                     g_dodge_probe_usable, listFrom, listIdx, listGid, probeGid, listGid, listIdx);
        }

        tnx_logf("v135 dodge probe tick=%llu frames=%llu scene=%p container=%p array=%p count=%d "
                 "hop=%d own=%p ownGid=%d ownTeam=%d coordOk=%d coordUsable=%d writeTest=%d - this "
                 "line is printed before every early return of the dodge, so 'the dodge did not run' "
                 "can never again be concluded from the absence of a log line; in the v134 run the "
                 "dodge wrote nothing and said nothing, and it took a manual read of the resolver to "
                 "learn that the container globals and the walked list disagreed",
                 (unsigned long long)g_v50_ticks, (unsigned long long)g_v48_ticks,
                 (void *)g_scene_object, (void *)g_players_object, (void *)g_players_array,
                 probeCount, g_v82_hop_chosen, (void *)probeOwn, probeGid, probeTeam,
                 g_v47_coord_ok, g_v47_coord_usable, TNX_V129_MODE);
    }

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

         


        if (sourceIsMode && g_v82_hop_chosen == 1 && g_v142_tick_object) {
            resolved = (void *)g_v142_tick_object;
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

    tnx_v146_phase("collect");

    usable = tnx_v48_collect(g_v48_manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    if (usable < 2) return;

    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    tnx_v91_own_scan();

    {
        const char *ownFrom = "none";

        if (!tnx_v128_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_v91_resolve_own(objects, usable, &ownIndex, &ownFrom)) {
            if (g_v47_giveup_logs < 6) {
                g_v47_giveup_logs++;

                tnx_logf("v100 dodge idle: no own element - the scan found nothing at scanIndex=%d "
                         "scanPtr=%p and the prediction fallback (%d,%d) found nothing either, "
                         "usable=%d", g_v91_own_index, (void *)g_v91_own_ptr, predictX, predictY,
                         usable);
            }

            return;
        }

         


         



        tnx_v145_publish_own(objects[ownIndex].object, ownFrom);

        if (g_v144_own_logs < 8) {
            uintptr_t ownVt = 0;
            uintptr_t ownCls = 0;

            g_v144_own_logs++;

            tnx_v144_vt_ok((uintptr_t)g_v144_own_elem, &ownVt);

            if (ownVt >= g_base) ownCls = ownVt - g_base;

            tnx_logf("v144 dodge own elem=%p vt=%p classRva=%#llx from=%s index=%d pos=(%d,%d) - "
                     "classRva is what the census classRva of the same element index has to match, "
                     "and the actuator uses this exact element or nothing",
                     (void *)g_v144_own_elem, (void *)ownVt, (unsigned long long)ownCls, ownFrom,
                     ownIndex, objects[ownIndex].x, objects[ownIndex].y);
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

     


    tnx_v146_phase("sidestep");

    g_v140_side_hits = 0;
    g_v140_side_projs = 0;

    {
        int32_t projCount = 0;
        float sideX = 0.0f;
        float sideY = 0.0f;

        if (g_v48_manager) tnx_read_i32(g_v48_manager + TNX_MGR_COUNT_OFF, &projCount);

        g_v151_best_dist = -1.0f;
        g_v151_best_x = 0.0f;
        g_v151_best_y = 0.0f;
        g_v153_best_t = 1.0e9f;
        g_v153_best_k = -1;
        g_v153_side = 0;

        tnx_v140_proj_scan(g_v48_manager, projCount);
        tnx_v140_sidestep(ownX, ownY, &sideX, &sideY, &g_v140_side_hits, &g_v140_side_projs);

        if (g_v140_side_hits > 0 && (g_v151_best_x != 0.0f || g_v151_best_y != 0.0f)) {
            escapeX = g_v151_best_x * TNX_V140_SIDE_WEIGHT;
            escapeY = g_v151_best_y * TNX_V140_SIDE_WEIGHT;
        }

        if (g_v140_side_hits > 0) {
            escapeX += sideX * TNX_V140_SIDE_WEIGHT;
            escapeY += sideY * TNX_V140_SIDE_WEIGHT;

            if (g_v140_side_logs < TNX_V140_SIDE_LOGS) {
                g_v140_side_logs++;

                tnx_logf("v140 threat detected own=(%d,%d) projectiles=%d onRay=%d side=(%.2f,%.2f) "
                         "hostilesInRange=%d - the slope is the per tick delta of the pair at "
                         "+%#llx/+%#llx, so a projectile only counts once two ticks were seen; the "
                         "weight %g lets this dominate a repulsion sum whose terms are all below 1",
                         ownX, ownY, g_v140_side_projs, g_v140_side_hits, (double)sideX,
                         (double)sideY, threats, (unsigned long long)TNX_OBJ_X_OFF,
                         (unsigned long long)TNX_OBJ_Y_OFF, (double)TNX_V140_SIDE_WEIGHT);
            }
        }
    }

    if (threats == 0 && g_v140_side_hits == 0) {
        if (g_v47_ticks % 256 == 0) {
            tnx_logf("v100 live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
                     "enemiesActive=%d enemiesInRange=0 projSeen=%d projOnRay=0 writes=%llu "
                     "threatsTotal=%llu",
                     (unsigned long long)g_v47_ticks, ownX, ownY, ownTeam, predictX, predictY,
                     threatsAlive, threats, g_v140_side_projs, (unsigned long long)g_v47_writes,
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
        float step = DODGE_STEP;

        if (length <= 0.0001f) return;

        escapeX /= length;
        escapeY /= length;

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        step = DODGE_STEP;

        if (g_v140_side_hits > 0 && g_v151_best_dist >= 0.0f) {
            float urgency = (TNX_V140_THREAT_RADIUS - g_v151_best_dist) / TNX_V140_THREAT_RADIUS;

            if (urgency < 0.0f) urgency = 0.0f;
            if (urgency > 1.0f) urgency = 1.0f;

            step = DODGE_STEP * (1.0f + urgency * (TNX_V151_THREAT_STEP_MULT - 1.0f));
        }

        targetX = ownX + (int)(escapeX * step);
        targetY = ownY + (int)(escapeY * step);

        if (g_v140_side_hits > 0) {
            float desX = 0.0f;
            float desY = 0.0f;
            uintptr_t ctl = tnx_v150_controller();

            if (ctl) {
                int32_t rx = 0;
                int32_t ry = 0;

                if (tnx_read_i32(ctl + TNX_V128_CTRL_RAW_X_OFF, &rx) &&
                    tnx_read_i32(ctl + TNX_V128_CTRL_RAW_Y_OFF, &ry)) {
                    desX = (float)rx;
                    desY = (float)ry;
                }
            }

            if (g_v154_have && !tnx_v154_threatened((float)g_v154_tx, (float)g_v154_ty)) {
                float ddx = (float)(g_v154_tx - ownX);
                float ddy = (float)(g_v154_ty - ownY);
                float dist = sqrtf(ddx * ddx + ddy * ddy);

                if (dist <= TNX_V154_ARRIVE) {
                    g_v154_have = 0;
                    g_v155_prev_dist = 0.0f;
                    g_v155_stall = 0;
                } else if (g_v155_prev_dist > 0.0f && dist > g_v155_prev_dist - TNX_V155_PROGRESS) {
                    g_v155_stall++;

                    if (g_v155_stall > TNX_V155_STALL_TICKS) {
                        tnx_v155_block(atan2f(ddy, ddx));

                        g_v155_stall = 0;
                        g_v155_prev_dist = 0.0f;
                        g_v154_have = 0;
                    } else {
                        targetX = g_v154_tx;
                        targetY = g_v154_ty;
                        g_v154_reuse++;
                    }
                } else {
                    g_v155_stall = 0;
                    g_v155_prev_dist = dist;
                    targetX = g_v154_tx;
                    targetY = g_v154_ty;
                    g_v154_reuse++;
                }
            } else {
                int32_t vtx = 0;
                int32_t vty = 0;

                g_v154_have = 0;

                if (tnx_v154_best(ownX, ownY, desX, desY, &vtx, &vty)) {
                    float ddx = (float)(vtx - ownX);
                    float ddy = (float)(vty - ownY);

                    targetX = vtx;
                    targetY = vty;
                    g_v154_tx = vtx;
                    g_v154_ty = vty;
                    g_v154_have = 1;
                    g_v155_prev_dist = sqrtf(ddx * ddx + ddy * ddy);
                    g_v155_stall = 0;
                }
            }
        } else {
            g_v154_have = 0;
            g_v155_prev_dist = 0.0f;
            g_v155_stall = 0;
        }

        if (g_v140_side_hits > 0 && g_v152_issued && targetX == g_v152_last_tx &&
            targetY == g_v152_last_ty) {
            return;
        }

        if (now < g_v47_last_write_ms + (uint64_t)(g_v140_side_hits > 0
                ? TNX_V151_THREAT_MIN_MS : TNX_V47_DODGE_MIN_MS)) {
            return;
        }

        g_v47_last_write_ms = now;

        if (g_v140_side_hits > 0) {
            g_v152_last_tx = targetX;
            g_v152_last_ty = targetY;
            g_v152_issued = 1;
        }

        if (g_v140_side_hits > 0 && g_v151_logs < TNX_V151_LOGS) {
            g_v151_logs++;

            tnx_logf("v151 threat write own=(%d,%d) target=(%d,%d) onRay=%d bestDist=%.0f "
                     "best=(%.2f,%.2f) step=%.0f gap=%d - the escape is the perpendicular of the "
                     "single closest projectile on the ray, not a sum over all of them, because a "
                     "sum lets two shots from opposite sides cancel and leaves the character "
                     "standing in both lanes",
                     ownX, ownY, targetX, targetY, g_v140_side_hits,
                     (double)g_v151_best_dist, (double)g_v151_best_x, (double)g_v151_best_y,
                     (double)step, TNX_V151_THREAT_MIN_MS);

            tnx_logf("v154 search target=(%d,%d) own=(%d,%d) held=%d reuse=%llu searches=%llu "
                     "arrive=%.0f step=%.0f inflate=%.0f - the target is chosen by walking %d "
                     "directions outward in %.0f unit steps from the joystick direction and taking "
                     "the first point whose clearance to every projectile line is positive, then "
                     "keeping the point with the largest clearance, and the previous target is held "
                     "while it stays clear so the character walks one line instead of wiggling "
                     "between two",
                     targetX, targetY, ownX, ownY, g_v154_have, (unsigned long long)g_v154_reuse,
                     (unsigned long long)g_v154_searches, (double)TNX_V154_ARRIVE,
                     (double)TNX_V154_STEP, (double)TNX_V154_INFLATE, TNX_V154_ANGLES,
                     (double)TNX_V154_STEP);
        }

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
                tnx_logf("v140 about to write: scene=%p vt=%#llx chain=%p manager=%p target=(%d,%d) "
                         "mode=%p actRva=%#llx leafRva=%#llx - the leaf %#llx is only a fallback, its "
                         "only caller in the image is the deserializer at 0xa26520, so a write that "
                         "lands there is stored and never consumed",
                         (void *)g_scene_object, (unsigned long long)thisVt, (void *)thisChain,
                         (void *)g_v48_manager, targetX, targetY, (void *)g_v144_own_elem,
                         (unsigned long long)TNX_V140_MODEPAIR_RVA,
                         (unsigned long long)TNX_RVA_SETPREDICTION,
                         (unsigned long long)TNX_RVA_SETPREDICTION);
            }
        }

        tnx_v146_phase("mode-write");

        tnx_v148_receiver_probe();

        if (!TNX_V150_ACT_WRITE) {
            if (g_v147_dry_logs < 8) {
                g_v147_dry_logs++;

                tnx_logf("v147 actuate write disabled target=(%d,%d) own=(%d,%d) ownFrom=%s - the "
                         "candidate list no longer carries the container element: writing the pair "
                         "at +0x10c on it clobbers the high half of the 8 byte pointer at +0x108 "
                         "that the game frees at rva 0x9fd390, and free() rejecting that pointer is "
                         "the SIGABRT of the 146 run", targetX, targetY, ownX, ownY,
                         g_v145_own_from);
            }
        } else if (!tnx_v144_mode_write(targetX, targetY, TNX_V140_MODEPAIR_FLAG)) {
             


            if (g_v47_setpred) {
                ((tnx_v47_setpred_t)g_v47_setpred)((void *)g_scene_object, targetX, targetY);
            }
        }

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

static uint64_t tnx_v68_word(uintptr_t address) {
    uint64_t value = 0;

    if (!tnx_read_bytes(address, &value, sizeof(value))) return 0;

    return value;
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




static uintptr_t tnx_v57_coord_x_off(void) {
    return TNX_OBJ_X_OFF;
}

static uintptr_t tnx_v57_coord_y_off(void) {
    return TNX_OBJ_Y_OFF;
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


    void *bridge = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_BRIDGE_OFF, &bridge) && bridge) {
        void *bridgeManager = NULL;

        tnx_logf("slot +08 bridge=%p vt=%#llx", bridge,
                 (unsigned long long)tnx_vtable_rva(bridge));

        if (tnx_read_ptr((uintptr_t)bridge + TNX_MGR_ARRAY_OFF, &bridgeManager) && bridgeManager) {
            tnx_logf("slot bridgeMgr=%p vt=%#llx", bridgeManager,
                     (unsigned long long)tnx_vtable_rva(bridgeManager));

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

    }

    void *inputManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_INPUTMGR_OFF, &inputManager) && inputManager) {
        tnx_logf("slot +58 inputMgr=%p vt=%#llx", inputManager,
                 (unsigned long long)tnx_vtable_rva(inputManager));

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


    tnx_objc_arm("MetalView", "render");
    tnx_objc_arm("NullView", "render");

    tnx_slot_hooks_install();

    int buildControls = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) buildControls++;
    }

    tnx_slot_table_dump();

    tnx_logf("build=%s slots=%d control=%d types>=%d scanEvery=%d heapEvery=%d attempts=%d "
             "arrayProbeLimit=%d chainProbeLimit=%d voteMin=%d voteConfirm=%d voteTeamsMin=%d "
             "gidFloor=%d gidMax=%d objhitDump=%d censusMax=%d censusPrint=%d censusSlots=%d "
             "budgetMin=%lluMB budgetMax=%lluMB",
             TNX_BUILD_TAG, TNX_SLOT_COUNT - buildControls, buildControls, TNX_MODE_MIN_TYPES,
             TNX_VOTESCAN_GLOBAL_EVERY, TNX_VOTESCAN_HEAP_EVERY, TNX_VOTESCAN_ATTEMPTS,
             TNX_MANAGER_PROBE_LIMIT, TNX_CHAIN_PROBE_LIMIT, TNX_OWNER_VOTE_MIN,
             TNX_OWNER_VOTE_CONFIRM, TNX_OWNER_VOTE_TEAMS_MIN,
             TNX_V75_GID_FLOOR, TNX_V75_GID_MAX, TNX_OBJ_HIT_PRINT_MAX, TNX_VTCENSUS_MAX,
             TNX_VTCENSUS_PRINT, TNX_VTCENSUS_SLOTS,
             TNX_HEAP_SCAN_BUDGET / (1024ull * 1024ull),
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
     
    tnx_v146_install();

    dispatch_async(dispatch_get_main_queue(), ^{
        tlog(@"=== titanox started (zero latency mode) ===");
        poll_for_game(0);
    });
}
