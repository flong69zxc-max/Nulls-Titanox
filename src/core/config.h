#ifndef RECOIL_CONFIG_H
#define RECOIL_CONFIG_H

#include "core/imports.h"


#define RCL_ONESHOT 1
#define RCL_ENEMY_HARD 150.0f
#define RCL_ENEMY_FAR 400.0f
#define RCL_ENEMY_MARGIN 60.0f
#define RCL_PREDICT 0
#define RCL_BODY_CLEAR 180.0f
#define RCL_TOUCH_FLAG 1
#define RCL_STICK_WHEN_FREE 1
#define RCL_PREDICT_FLAG 1
#define RCL_STICK_SIGN 1
#define RCL_WRITE_GUARD 1
#define RCL_TEAM_STRICT 1
#define RCL_PROJ_OWNER 1
#define RCL_SPAWN_R 520.0f
#define RCL_ESCAPE 1
#define RCL_PRECISION 1
#define RCL_EVERY 60
#define RCL_LOOKAHEAD_MS 220.0f
#define RCL_PAIR_RAW 1
#define RCL_PAIR_MAX 2400.0f
#define RCL_RAGE 1
#define RCL_LOOKAHEAD_MS_2 800.0f
#define RCL_MATE_AVOID 1
#define RCL_MATE_CLEAR_2 700.0f
#define RCL_QUEUE 1
#define RCL_STEP_c 150.0f
#define RCL_DEGEN 2000000
#define RCL_SLOW_US 200
#define RCL_MODE_TUNE 1
#define RCL_GATE_WRITE 1
#define RCL_HIT_ONLY 1
#define RCL_REJECT 1
#define RCL_MIN_SPEED 220.0f
#define RCL_MAX_SPEED 9000.0f
#define RCL_BLINK_TICKS 2
#define RCL_BLINK_REM 320.0f
#define RCL_BODY_SCAN 1
#define RCL_WALK_MIN 1.0f
#define RCL_WALK_MAX 60.0f
#define RCL_WALK_EMA 0.12f
#define RCL_HORIZON 1.0f
#define RCL_BODY_W 1.0f
#define RCL_SEL_MAX 8
#define RCL_STEPS 4
#define RCL_FLEE 1
#define RCL_FLEE_STEP 150.0f
#define RCL_CLUSTER 700.0f
#define RCL_FREEST_ANGLES 32
#define RCL_FREEST_MIN 120.0f
#define SCAN_MAX 256
#define DODGE_STEP 600.0f
#define RCL_MGR_CAP_MAX 4096
#define RCL_MANAGER_MIN_OBJECTS 3
#define RCL_MANAGER_MAX_OBJECTS 96
#define RCL_DC_RVA_SIZE 0xd4000ULL
#define RCL_OWNER_VOTE_MIN 3
#define RCL_OWNER_VOTE_TEAMS_MIN 2
#define RCL_OBJ_HIT_DUMP_MAX 64
#define RCL_COORD_SOFT 0
#define RCL_WIRE_OWNER 1
#define RCL_HOPCHOSEN_DIRECT 2
#define RCL_MSG_SIZE 0x48
#define RCL_QUEUE_GUARD 0
#define RCL_QUEUE_GUARD_MGR 0
#define RCL_QGUARD_LOGS 3
#define RCL_DEAD_ONCE 1
#define RCL_TYPE_MOVE 0x2
#define RCL_GIDLESS 1
#define RCL_POS_BONUS 8
#define RCL_DIST_BONUS 6
#define RCL_SOFT_BASE 2
#define RCL_SOFT_MIN_POS 2
#define RCL_SOFT_MIN_DIST 2
#define RCL_APPLIED_IDLE (-300)
#define RCL_OBJ_TEAM_MAX 7
#define RCL_JOURNAL 24
#define RCL_STALE_SIGHT 1
#define RCL_QUIET 0
#define RCL_HUMAN 1
#define RCL_V245_STICK 0
#define RCL_RETIRE 1
#define RCL_WALL_CLIP 1
#define RCL_TILE_SIZE 300.0f
#define RCL_GRID_MAX 128
#define RCL_REBUILD_TICKS 60
#define RCL_MIN_PASSES 3
#define RCL_MIN_CLIP 60.0f
#define RCL_MIN_IMG_PCT 0
#define RCL_MAX_SOLID_PCT 60
#define RCL_MAX_CLIP_PCT 70
#define RCL_MIN_SEGS 4
#define RCL_JOY_MAG 600.0f
#define RCL_TEAM_FILTER 0
#define RCL_STEP 120.0f
#define RCL_ELEM_RESET 1
#define RCL_STAGE_POSITION 2
#define RCL_INPUT_MGR 0
#define RCL_STEP_a 150.0f
#define RCL_DEFAULT_RANGE 9000.0f
#define RCL_EXTEND_DEFAULT 60.0f
#define RCL_SEG_MAX 32


#define RCL_JOY_KNOB_ON 1
#define RCL_JOY_KNOB_MAG 30.0f
#define RCL_JOY_MIN_CENTER 50.0f
#define RCL_JOY_PAIR_Y 4
#define RCL_JOY_PAIR_CEN 8
#define RCL_JOY_PAIR_N 3
#define RCL_JOY_TARGETS 4
#define RCL_JOY_KNOB_LOGS 8
#define RCL_JOY_EPS 0.0001f



#define RCL_BS_AX 0x9b8
#define RCL_BS_AY 0x9bc
#define RCL_BS_BX 0x9c0
#define RCL_BS_BY 0x9c4
#define RCL_BS_MODE 0x8ac
#define RCL_JOY_ALT_CUR_X 0x9d0
#define RCL_JOY_ALT_CUR_Y 0x9d4
#define RCL_JOY_ALT_CEN_X 0x9d8
#define RCL_JOY_ALT_CEN_Y 0x9dc
#define RCL_JOY_ALT_DRAG 0xee8
#define RCL_JOY_DEEP 0
#define RCL_BS_COS 0x8f4
#define RCL_BS_SIN 0x8f8
#define RCL_PRED_SET 1
#define RCL_PRED_FLAG 1
#define RCL_LOGS_a 12
#define RCL_PLAYER_GID 1000000
#define RCL_SHOT_GID 2000000
#define RCL_MIN_USABLE_2 1
#define RCL_STEP_b 60.0f
#define RCL_PAIR_ONLY 0
#define RCL_STICK_ONLY 0
#define RCL_DRIVE_FROM_UPDATE 0
#define RCL_MATE_CLEAR 240.0f
#define RCL_MATE_MAX 8
#define RCL_PLAYER_MAX 12
#define RCL_ATTRIB_R (700.0f * 700.0f)
#define RCL_ATTRIB_MARGIN 1.5f
#define RCL_RESPAWN_JUMP 1200
#define RCL_RESPAWN_VISIBLE 90
#define RCL_CAND 3
#define RCL_HOLD_FRAMES 10
#define RCL_STATE_INIT 0
#define RCL_STATE_ALIVE 1
#define RCL_STATE_DEAD 2
#define RCL_STATE_RESPAWN 3
#define RCL_DRIVE_LOGS 24
#define RCL_DT_MAX 12
#define RCL_STICK_TTL 3
#define RCL_MIN_PROJ_SPEED 10.0f
#define RCL_MIN_USABLE 1
#define RCL_REACH 600.0f
#define RCL_INFLATE 350.0f
#define RCL_THREAT_MIN_MS 0
#define RCL_PUB_LOGS 10
#define RCL_MIN_OBJ_BYTES 0x118ULL
#define RCL_ARRAY_VOTE_LOGS 8
#define RCL_PROJ_MAX 16
#define RCL_DUMPS 3
#define RCL_DIFF_BYTES 0x100
#define RCL_DIFF_LOGS 48
#define RCL_COORD_ABS_MAX 1000000
#define RCL_MAP_MIN 4
#define RCL_MAP_MAX 512
#define RCL_OBJECT_MAX 64
#define RCL_DODGE_MIN_MS 0
#define RCL_REPROBE_MS 5000
#define RCL_COUNT_MAX 96
#define RCL_WALK_EVERY 5
#define RCL_SCAN_QWORDS 512
#define RCL_SCAN_BASES 3
#define RCL_VERIFY_FRAMES 3
#define RCL_POS_DUMPS 8
#define RCL_IMAGE_SPAN 0x1164000ULL
#define RCL_HEAP_MIN 0x100000000ULL
#define RCL_HEAP_MAX 0x800000000000ULL
#define RCL_HB_TICKS 5
#define RCL_BUCKET_TICKS_2 10
#define RCL_QUIET_SECS 10
#define RCL_SCAN_FLOOR_TICKS 12
#define RCL_SCAN_FALLBACK_TICKS 20
#define RCL_MODESIG_TICKS 3
#define RCL_LIVE_OBJ_MIN 3
#define RCL_LIVE_TEAM_MIN 2
#define RCL_BAR_TICKS 30
#define RCL_IDLE_TICKS 15
#define RCL_IDLE_RETRY_TICKS 300
#define RCL_OBJ_SLOTS 3
#define RCL_STATE_BATTLE 5
#define RCL_HOPS 2
#define RCL_ASCII_RATIO 30
#define RCL_TEAM_MAX_2 15
#define RCL_GID_MAX 10000000
#define RCL_GID_FLOOR 1000000
#define RCL_COORD_MAX 100000
#define RCL_PLAYER_GID_MAX 2000000
#define RCL_CALL_LOGS 4
#define RCL_CALL_EVERY 600
#define RCL_NP_DUMPS 8
#define RCL_VOTESCAN_GLOBAL_EVERY 10
#define RCL_MODE_MIN_TYPES 2
#define RCL_MODE_TYPE_MAX 16
#define RCL_SNAPSHOT_DELAY 1.2
#define RCL_VOTESCAN_INTERVAL 1.0
#define RCL_VOTESCAN_ATTEMPTS 600
#define RCL_VTABLE_SEGMENT "__DATA_CONST"
#define RCL_VTABLE_SEGMENT_ALT "__DATA"
#define RCL_SLOT_COUNT 34
#define RCL_HEAP_REGION_MAX 512
#define RCL_HEAP_REGION_MAX_SIZE 0x100000000ULL
#define RCL_TRAIL_MAX 8
#define RCL_ELEMS 8
#define RCL_WORDS_2 24
#define RCL_VALUE_MAX 1000000
#define RCL_FLOAT_MAX 10000.0f
#define RCL_TEAM_MAX 8

#define RCL_REACT_CRIT 1
#define RCL_DIR_COUNT 64

#define RCL_VIEW_RANGE 3400.0f

#define RCL_DODGE_DIST 400.0f
#define RCL_ADV_BUCKETS 8
#define RCL_ADV_STEP 50.0f

#define RCL_SKIP_UNSAFE 1
#define RCL_BLACK_SPEED_TOL 60.0f
#define RCL_BLACK_RADIUS_TOL 40.0f
#define RCL_NEAR_MULT 1.5f
#define RCL_NO_THREAT_TICKS 6

#define RCL_HOWTO_LOGS 12

#define RCL_GEOM 1
#define RCL_GEOM_LOGS 6
#define RCL_RADIUS_MIN 0.0f
#define RCL_RADIUS_MAX 600.0f
#define RCL_RADIUS_MARGIN 8.0f
#define RCL_CAL_OFF_LO 0x20
#define RCL_CAL_OFF_HI 0x120
#define RCL_CAL_STEP 4
#define RCL_CAL_TOL 0.06f
#define RCL_CONTACT_LOGS 8

#define RCL_SNAP 1
#define RCL_SNAP_MAG 600.0f
#define RCL_SNAP_LOGS 8
#define RCL_SIDE_FLIP 1
#define RCL_SIDE_STALE 45
#define RCL_CAL_TICKS 6
#define RCL_CAL_MISS 40
#define RCL_WALL_LOGS 8
#define RCL_TEAM_LOGS 6


#define RCL_JOY_KNOB_WRITE 0
#define RCL_APPLY_WRITE 0

#define RCL_STICK_PUSH 1
#define RCL_STICK_RADIUS 60.0f
#define RCL_STICK_KNOB 0
#define RCL_STICK_INPUT 0
#define RCL_STICK_HOLD 0
#define RCL_STICK_HOLD_WRITE 0




#define RCL_WALK_PUSH 1
#define RCL_WALK_KNOB 0
#define RCL_WALK_HOLD 0
#define RCL_WALK_DEAD_GAIN 1.6f
#define RCL_WALK_HOLD_GATE 1
#define RCL_WALK_DEAD_PAD 4.0f
#define RCL_WALK_STALE 3
#define RCL_WALK_GATE_LOGS 300
#define RCL_ENT_WARMUP 90
#define RCL_STATE_EVERY 240
#define RCL_WALK_LOOKUP 1
#define RCL_ENT_PROBE 1
#define RCL_ENT_PROBE_LOGS 900
#define RCL_ENT_SAMPLE 3
#define RCL_ENT_SUM_EVERY 360
#define RCL_ENT_SUM_MIN 4
#define RCL_ENT_SUM_LOGS 40
#define RCL_ENT_SLOTS 512
#define RCL_ENT_CHUNK 0x100
#define RCL_ENT_CHUNKS 8
#define RCL_WALK_HS 1
#define RCL_WALK_HS_TIMER 0.05f



#ifndef RCL_DODGE_PROJ_ONLY
#define RCL_DODGE_PROJ_ONLY 1

#ifndef RCL_PROJ_ANGLE_OFF
#define RCL_PROJ_ANGLE_OFF 0xb8

#ifndef RCL_JS_ENEMY_W
#define RCL_JS_ENEMY_W 300.0f
#endif

#endif

#ifndef RCL_JS_SPEED_FALLBACK
#define RCL_JS_SPEED_FALLBACK 1200.0f
#endif

#ifndef RCL_JS_RADIUS_FALLBACK
#define RCL_JS_RADIUS_FALLBACK 8.0f
#endif

#endif
#ifndef RCL_HIT_MARGIN
#define RCL_HIT_MARGIN 60.0f
#endif
#ifndef RCL_DODGE_CLEAR_R
#define RCL_DODGE_CLEAR_R 96.0f
#endif
#ifndef RCL_RAGE_FORCE
#define RCL_RAGE_FORCE 0
#endif
#ifndef RCL_LOOKAHEAD_MAX
#define RCL_LOOKAHEAD_MAX 400.0f
#endif
#ifndef RCL_ENGAGE_NEAR
#define RCL_ENGAGE_NEAR 24.0f
#endif
#ifndef RCL_JS_DODGE
#define RCL_JS_DODGE 1
#endif
#ifndef RCL_DIR_COUNT
#define RCL_DIR_COUNT 48
#endif
#ifndef RCL_HORIZON_S
#define RCL_HORIZON_S 1.0f
#endif
#ifndef RCL_DATA_MOMENTUM
#define RCL_DATA_MOMENTUM 300.0f
#endif
#ifndef RCL_WALL_PENALTY
#define RCL_WALL_PENALTY 9000.0f
#endif
#ifndef RCL_DATA_SPEED
#define RCL_DATA_SPEED 750.0f
#endif
#ifndef RCL_DATA_OWN_R
#define RCL_DATA_OWN_R 120.0f
#endif
#ifndef RCL_DATA_PROJ_R
#define RCL_DATA_PROJ_R 150.0f
#endif
#ifndef RCL_DATA_HOLD
#define RCL_DATA_HOLD 10
#endif
#ifndef RCL_DATA_BAND
#define RCL_DATA_BAND 300.0f
#endif
#ifndef RCL_DATA_CRIT_EVERY
#define RCL_DATA_CRIT_EVERY 4
#endif
#ifndef RCL_JS_CLEAR_STEPS
#define RCL_JS_CLEAR_STEPS 4
#endif
#ifndef RCL_PROJ_LIFE_MS
#define RCL_PROJ_LIFE_MS 1200.0f
#endif
#ifndef RCL_OVERSHOOT
#define RCL_OVERSHOOT 220.0f
#endif
#ifndef RCL_FREEST_RADII
#define RCL_FREEST_RADII 3
#endif
#ifndef RCL_FREEST_LOGS
#define RCL_FREEST_LOGS 6
#endif
#ifndef RCL_BODY_GAIN
#define RCL_BODY_GAIN 0.0f
#endif
#ifndef RCL_ETA_PENALTY
#define RCL_ETA_PENALTY 100000.0f
#endif
#ifndef RCL_JS_NOPREDICT
#define RCL_JS_NOPREDICT 0
#endif
#ifndef RCL_GEOM
#define RCL_GEOM 1
#endif
#ifndef RCL_GEOM_LOGS
#define RCL_GEOM_LOGS 6
#endif
#ifndef RCL_RADIUS_MIN
#define RCL_RADIUS_MIN 0.0f
#endif
#ifndef RCL_RADIUS_MAX
#define RCL_RADIUS_MAX 600.0f
#endif
#ifndef RCL_RADIUS_MARGIN
#define RCL_RADIUS_MARGIN 8.0f
#endif
#ifndef RCL_CAL_OFF_LO
#define RCL_CAL_OFF_LO 0x20
#endif
#ifndef RCL_CAL_OFF_HI
#define RCL_CAL_OFF_HI 0x120
#endif
#ifndef RCL_CAL_STEP
#define RCL_CAL_STEP 4
#endif
#ifndef RCL_CAL_TOL
#define RCL_CAL_TOL 0.06f
#endif
#ifndef RCL_CONTACT_LOGS
#define RCL_CONTACT_LOGS 8
#endif
#ifndef RCL_SNAP
#define RCL_SNAP 1
#endif
#ifndef RCL_SNAP_DELTA
#define RCL_SNAP_DELTA 0
#endif
#ifndef RCL_SNAP_HARD_OFF
#define RCL_SNAP_HARD_OFF 1
#endif
#ifndef RCL_SNAP_MAG
#define RCL_SNAP_MAG 600.0f
#endif
#ifndef RCL_SNAP_LOGS
#define RCL_SNAP_LOGS 8
#endif
#ifndef RCL_SIDE_FLIP
#define RCL_SIDE_FLIP 1
#endif
#ifndef RCL_SIDE_STALE
#define RCL_SIDE_STALE 45
#endif
#ifndef RCL_CAL_TICKS
#define RCL_CAL_TICKS 6
#endif
#ifndef RCL_CAL_MISS
#define RCL_CAL_MISS 40
#endif
#ifndef RCL_WALL_LOGS
#define RCL_WALL_LOGS 8
#endif
#ifndef RCL_TEAM_LOGS
#define RCL_TEAM_LOGS 6
#endif
#define RCL_CONTACT_LOGS 8
#define RCL_DATA_OWN_R 120.0f
#define RCL_GEOM 1
#define RCL_RADIUS_MAX 600.0f
#define RCL_SIDE_FLIP 1
#define RCL_SIDE_STALE 45
#ifndef RCL_DODGE_PROJ_ONLY
#define RCL_DODGE_PROJ_ONLY 1
#endif

#ifndef RCL_PROJ_ACTIVE_BYPASS
#define RCL_PROJ_ACTIVE_BYPASS 1
#endif
#ifndef RCL_JS_STICK
#define RCL_JS_STICK 1
#endif
#ifndef RCL_JS_HOLD
#define RCL_JS_HOLD 2
#endif
#ifndef RCL_STICK_RAW_WRITE
#define RCL_STICK_RAW_WRITE 0
#define RCL_PRED_SPAN 0x118
#endif
#ifndef RCL_LOG_PLANS
#define RCL_LOG_PLANS 0
#endif


#define RCL_JOY_COORD_LIMIT 20000.0f

#define RCL_PROJ_RADIUS_DEFAULT 150.0f

#define RCL_OWN_RADIUS_MIN 40.0f

#define RCL_AIM 1

#define RCL_DODGE_SPAWN_MARGIN 60.0f

#define RCL_DODGE_DETECT_SAFETY 2.5f

#define RCL_OWN_RADIUS_MAX 200.0f


#define RCL_AIM_INTERVAL 12

#define RCL_AIM_RANGE 3000.0f

#define RCL_MOVE_ON 1

#define RCL_DODGE_DETAIL_MAX 12

#define RCL_DODGE_DETAIL_EVERY 20
#define RCL_JOY_SCAN_ON 1

#define RCL_MOVE_TOL 4000.0f

#define RCL_MOVE_MAX 12

#define RCL_MOVE_HOPS 2



#define RCL_MEAS_FPS 60.0f

#define RCL_MEAS_DT_MAX 8.0f

#define RCL_MEAS_SPEED_MIN 300.0f

#define RCL_MEAS_SPEED_MAX 8500.0f




#define RCL_AIM_PRED_MAX 3

#define RCL_AIM_PRED_COEF 0.8f

#define RCL_AIM_PROJ_SPEED 3255.0f




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
} rcl_rva_entry_t;

typedef struct {
    uintptr_t at;
    uintptr_t vt;
    uintptr_t owner;
    int32_t gid;
    int32_t team;
    int32_t ownerIdx;
    int dead;
    int ownerClass;
} rcl_objhit_t;

typedef uint64_t (*rcl_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                  uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

typedef struct {
    uintptr_t low;
    uintptr_t high;
} rcl_region_t;

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
} rcl_trail_t;

typedef void (*rcl_setpred_t)(void *self, int x, int y);

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
} rcl_obj_t;

typedef struct {
    uintptr_t elem;
    uintptr_t classRva;
    int32_t x;
    int32_t y;
    int32_t px;
    int32_t py;
    int32_t team;
    int32_t spawnX;
    int32_t spawnY;
    int32_t gid;
    uint64_t ptick;
    uint64_t qtick;
    int hasPrev;
} rcl_proj_t;

typedef struct {
    float ax;
    float ay;
    float bx;
    float by;
    float speed;
    float dirX;
    float dirY;
    float inflatedR;
    float remaining;
    int32_t gid;
} rcl_seg_t;


#define RCL_LOGS_ON 0

#endif