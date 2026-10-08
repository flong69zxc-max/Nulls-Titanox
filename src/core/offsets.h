#ifndef OFFSETS_H
#define OFFSETS_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach/mach_time.h>
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
#import "./offsets.h"
#include "hook.h"
#if __has_include(<ptrauth.h>)
#import <ptrauth.h>
#endif

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

#define RVA_BATTLEMODE_GETINSTANCE 0ULL
#define RVA_BATTLESCREEN__BATTLESCREEN 0ULL
#define RVA_BATTLESCREEN__UPDATEMOVEMENT 0x7a60f4ULL
#define RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER 0ULL
#define RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM 0ULL
#define RVA_LOGICBATTLEMODECLIENT_UPDATE 0ULL
#define RVA_LOGICGAMEOBJECTCLIENT_GETX 0ULL
#define RVA_LOGICGAMEOBJECTCLIENT_GETY 0ULL

#define OFF_BATTLEMODE_OBJECTMANAGERPTR 0x28ULL
#define OFF_BATTLESCREEN_AUTOFIREX 0xe6cULL
#define OFF_BATTLESCREEN_AUTOFIREY 0xe70ULL
#define OFF_CHARDATA_SPEED 0x1c4ULL
#define OFF_GAMEOBJ_DEADFLAG 0xd0ULL
#define OFF_GAMEOBJ_TEAM 0x40ULL
#define OFF_OBJECTMANAGER_COUNT 0xcULL
#define OFF_OBJECTMANAGER_OBJECTSARRAY 0x0ULL
#define OFF_OBJECTMANAGER_PTRSTRIDE 0x8ULL

#define RCL_JOYSTATE_OFF 0xed7ULL
#define RCL_GATE_OFF 0x70ULL
#define RCL_MODE_MANAGER_OFF 0x28ULL
#define RCL_MGR_ARRAY_OFF 0x0ULL
#define RCL_MGR_COUNT_OFF 0xcULL
#define RCL_MGR_CAP_OFF 0x8ULL
#define RCL_MODE_INPUTMGR_OFF 0x58ULL
#define RCL_DC_RVA_LO 0xf74000ULL
#define RCL_OBJ_GLOBALID_OFF 0x8ULL
#define RCL_GID_FALLBACK_OFF 0x50ULL
#define RCL_SETINPUT_RVA 0xac3a58ULL
#define RCL_MOVE_RVA 0xac3a58ULL
#define RCL_MOVE_FLAG_10 1
#define RCL_MOVE_X_OFF 0x10cULL
#define RCL_MOVE_Y_OFF 0x110ULL
#define RCL_MOVE_KEY_OFF 0x114ULL
#define RCL_MOVE_ARM_OFF 0xacULL
#define RCL_MOVE_COORD_LIMIT 200000
#define RCL_ALLOC_RVA 0x00d8da2cULL
#define RCL_MSGCTOR_RVA 0x00a95798ULL
#define RCL_CI_MGR_QUEUE_OFF 0x20ULL

#define RCL_ADDINPUT_RVA 0x74675cULL
#define RCL_GETBATTLE_RVA 0x008c5130ULL
#define RCL_MGR_OFF 0x58ULL
#define RCL_QUEUE_OFF 0x20ULL
#define RCL_QUEUE_COUNT_OFF 0xcULL
#define RCL_TYPE_OFF 0x08ULL
#define RCL_X_OFF 0x0cULL
#define RCL_Y_OFF 0x10ULL
#define RCL_ALLOC_GOT_RVA 0x00f78180ULL
#define RCL_OWN_INNER_OFF 0x28ULL
#define RCL_BOX_PTR_OFF 0xf8ULL
#define RCL_MGR_SEQ_OFF 0x0cULL
#define RCL_OWN_ALIVE_OFF 0x140ULL
#define RCL_GATE_FLAG_OFF 0xacULL
#define RCL_CTRL_RAW_X_OFF 0xfa4ULL
#define RCL_CTRL_RAW_Y_OFF 0xfa8ULL
#define RCL_CTRL_ALIVE_OFF 0xf80ULL

#define RCL_BATTLE_RVA 0x1123e58ULL
#define RCL_JOY_TARGET_OFF 0x58ULL
#define RCL_CLIENT_OFF 0x28ULL
#define RCL_CLIENT_POS_X_OFF 0x80ULL
#define RCL_CLIENT_POS_Y_OFF 0x84ULL
#define RCL_OBJ_TEAM_OFF 0x40ULL
#define RCL_OBJ_OWNERINDEX_OFF 0x3cULL
#define RCL_OBJ_DEADFLAG_OFF 0xd0ULL
#define RCL_TILES_OFF 0x20ULL
#define RCL_TYPE_MOVE_OFF 0x56ULL
#define RCL_TYPE_PROJ_OFF 0x57ULL
#define RCL_BOUNDS_X_OFF 0xccULL
#define RCL_BOUNDS_Y_OFF 0xd0ULL
#define RCL_CTRL_MODE_OFF 0x918ULL
#define RCL_RVA_SETPREDICTION 0x00ac3f20ULL
#define RCL_OBJ_X_OFF 0x30ULL
#define RCL_OBJ_Y_OFF 0x34ULL
#define RCL_OBJ_ACTIVEFLAG_OFF 0x1e8ULL
#define RCL_MODE_TILEMAP_OFF 0xf8ULL
#define RCL_TILEMAP_WIDTH_OFF 0xc4ULL
#define RCL_TILEMAP_HEIGHT_OFF 0xc8ULL
#define RCL_TYPE_SLOT_OFF 0x28ULL
#define RCL_ELEM_BACK_OFF 0x18ULL
#define RCL_TEAM_OFF 0x4cULL
#define RCL_DEAD_OFF 0xd4ULL
#define RCL_ELEM_ID_OFF_2 0x48ULL
#define RCL_ELEM_TEAM_OFF_2 0x4cULL
#define RCL_ARRAY_OFF 0x0ULL
#define RCL_COUNT_OFF_4 0xdcULL

#define RCL_COUNT_OFF 0xcULL
#define RCL_OWNIDX_OFF_2 0xe0ULL
#define RCL_OWNTEAM_OFF_2 0xe4ULL
#define RCL_OWNIDX_OFF 0xe0ULL
#define RCL_OWNTEAM_OFF 0xe4ULL
#define RCL_MODEPAIRSET_RVA RCL_SETINPUT_RVA
#define RCL_STATE_RVA 0x1123e58ULL
#define RCL_STATE_ENUM_OFF 0x50ULL
#define RCL_SCENE_OFF 0x48ULL
#define RCL_CLIENT_HOP_OFF 0x28ULL
#define RCL_ELEM_DEF_OFF 0x10ULL
#define RCL_OFF 0x70ULL
#define RCL_NP_PTR_OFF 0x38ULL

#define RCL_MAP_BASE_OFF RCL_MODE_MANAGER_OFF
#define RCL_MAP_PTR_OFF RCL_MODE_TILEMAP_OFF
#define RCL_MAP_WIDTH_OFF RCL_TILEMAP_WIDTH_OFF
#define RCL_MAP_HEIGHT_OFF RCL_TILEMAP_HEIGHT_OFF
#define RCL_TILE_PTR_STRIDE OFF_OBJECTMANAGER_PTRSTRIDE
#define RCL_TILE_TYPE_MOVE_OFF RCL_TYPE_MOVE_OFF
#define RCL_TILE_TYPE_PROJ_OFF RCL_TYPE_PROJ_OFF

#define RCL_STATE_BATTLE 5

#define RCL_CI_TYPE_TABLE_RVA 0x00e1e058ULL
#define RCL_CI_TABLE_TYPES 0x17ULL
#define RCL_CI_MAX_TABLE_TYPE 0x16UL
#define RCL_CI_FALLBACK_TYPE_CONST 0xdeadbeefUL
#define RCL_CI_HASH_MASK_SIZE 0x10UL
#define RCL_CI_HASH_PAD_INNER 0x36
#define RCL_CI_HASH_PAD_OUTER 0x5c
#define RCL_CI_HASH_INNER_MASK_RVA 0x00e1bbd0ULL
#define RCL_CI_HASH_OUTER_MASK_RVA 0x00e1bbf0ULL
#define RCL_BM_HASH_ENABLED_OFF 0x70ULL
#define RCL_BM_HASH_KEY_OFF 0x60ULL
#define RCL_CI_TOKEN_OFF 0x34UL
#define RCL_CI_TOKEN_READ_OFF 0x4UL
#define RCL_CI_TOKEN_READ_LEN 0x10UL
#define RCL_CI_TOKEN_MSG_LEN 0x14UL
#define RCL_CI_TOKEN_MASK 0x7fUL
#define RCL_CI_TOKEN_MIN 1UL

#define RCL_IMAGE_TEXT_WINDOW 0x4000ULL
#define RCL_CLASS_PROJ_RVA 0x000ff57b0ULL
#define RCL_PROJ_CLASS_ONLY 1

#define RCL_WRITE_GUARD 1
#define RCL_MGR_CAP_MAX 4096
#define RCL_MANAGER_MAX_OBJECTS 96
#define RCL_DC_RVA_SIZE 0xd4000ULL
#define RCL_OBJ_HIT_DUMP_MAX 64
#define RCL_QUEUE_GUARD 0

#define RCL_DT_MAX 12

#define RCL_OBJ_TEAM_MAX 7
#define RCL_JOURNAL 24
#define RCL_TILE_SIZE 300.0f
#define RCL_BS_MODE 0x8ac
#define RCL_PLAYER_GID 1000000
#define RCL_SHOT_GID 2000000
#define RCL_MATE_MAX 8
#define RCL_PLAYER_MAX 12
#define RCL_CAND 3
#define RCL_PROJ_MAX 16
#define RCL_DIFF_BYTES 0x100
#define RCL_COORD_ABS_MAX 1000000
#define RCL_OBJECT_MAX 64
#define RCL_IMAGE_SPAN 0x1164000ULL
#define RCL_OBJ_SLOTS 3
#define RCL_HOPS 2
#define RCL_TEAM_MAX_2 15
#define RCL_PLAYER_GID_MAX 2000000
#define RCL_VTABLE_SEGMENT "__DATA_CONST"
#define RCL_VTABLE_SEGMENT_ALT "__DATA"
#define RCL_SLOT_COUNT 34
#define RCL_HEAP_REGION_MAX 512
#define RCL_HEAP_REGION_MAX_SIZE 0x100000000ULL
#define RCL_TRAIL_MAX 8
#define RCL_GEOM 1
#define RCL_RADIUS_MIN 0.0f
#define RCL_RADIUS_MAX 600.0f
#define RCL_CAL_OFF_LO 0x20
#define RCL_CAL_OFF_HI 0x120
#define RCL_CAL_STEP 4
#define RCL_CAL_TOL 0.06f
#define RCL_CAL_TICKS 6
#ifndef RCL_DODGE_PROJ_ONLY

#ifndef RCL_PROJ_ANGLE_OFF

#ifndef RCL_JS_ENEMY_W
#endif

#endif

#ifndef RCL_JS_SPEED_FALLBACK
#endif

#ifndef RCL_JS_RADIUS_FALLBACK
#endif

#endif
#ifndef RCL_HIT_MARGIN
#endif
#ifndef RCL_DODGE_CLEAR_R
#endif
#ifndef RCL_RAGE_FORCE
#endif
#ifndef RCL_LOOKAHEAD_MAX
#endif
#ifndef RCL_ENGAGE_NEAR
#endif
#ifndef RCL_JS_DODGE
#endif
#ifndef RCL_DIR_COUNT
#endif
#ifndef RCL_HORIZON_S
#endif
#ifndef RCL_DATA_MOMENTUM
#endif
#ifndef RCL_WALL_PENALTY
#endif
#ifndef RCL_DATA_SPEED
#endif
#ifndef RCL_DATA_OWN_R
#define RCL_DATA_OWN_R 120.0f
#endif
#ifndef RCL_DATA_PROJ_R
#define RCL_DATA_PROJ_R 150.0f
#endif
#ifndef RCL_DATA_HOLD
#endif
#ifndef RCL_DATA_BAND
#endif
#ifndef RCL_DATA_CRIT_EVERY
#endif
#ifndef RCL_JS_CLEAR_STEPS
#endif
#ifndef RCL_PROJ_LIFE_MS
#endif
#ifndef RCL_OVERSHOOT
#endif
#ifndef RCL_FREEST_RADII
#endif
#ifndef RCL_FREEST_LOGS
#endif
#ifndef RCL_BODY_GAIN
#endif
#ifndef RCL_ETA_PENALTY
#endif
#ifndef RCL_JS_NOPREDICT
#endif
#ifndef RCL_GEOM
#define RCL_GEOM 1
#endif
#ifndef RCL_GEOM_LOGS
#endif
#ifndef RCL_RADIUS_MIN
#define RCL_RADIUS_MIN 0.0f
#endif
#ifndef RCL_RADIUS_MAX
#define RCL_RADIUS_MAX 600.0f
#endif
#ifndef RCL_RADIUS_MARGIN
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
#endif
#ifndef RCL_SNAP
#endif
#ifndef RCL_SNAP_DELTA
#endif
#ifndef RCL_SNAP_HARD_OFF
#endif
#ifndef RCL_SNAP_MAG
#endif
#ifndef RCL_SNAP_LOGS
#endif
#ifndef RCL_SIDE_FLIP
#endif
#ifndef RCL_SIDE_STALE
#endif
#ifndef RCL_CAL_TICKS
#define RCL_CAL_TICKS 6
#endif
#ifndef RCL_CAL_MISS
#endif
#ifndef RCL_WALL_LOGS
#endif
#ifndef RCL_TEAM_LOGS
#endif
#define RCL_DATA_OWN_R 120.0f
#define RCL_GEOM 1
#define RCL_RADIUS_MAX 600.0f
#ifndef RCL_DODGE_PROJ_ONLY
#endif
#ifndef RCL_PROJ_ACTIVE_BYPASS
#endif
#ifndef RCL_JS_STICK
#endif
#ifndef RCL_JS_HOLD
#endif
#ifndef RCL_STICK_RAW_WRITE
#define RCL_PRED_SPAN 0x118
#endif
#ifndef RCL_LOG_PLANS
#endif

#endif
