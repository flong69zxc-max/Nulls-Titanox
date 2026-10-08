#ifndef RCL_TYPES_H
#define RCL_TYPES_H

#include <stdint.h>
#include <stddef.h>

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

typedef struct
{
    uintptr_t at;
    uintptr_t vt;
    uintptr_t owner;
    int32_t gid;
    int32_t team;
    int32_t ownerIdx;
    int dead;
    int ownerClass;
} rcl_objhit_t;

typedef uint64_t (*rcl_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4,
                                  uint64_t a5, uint64_t a6, uint64_t a7);

typedef struct
{
    uintptr_t low;
    uintptr_t high;
} rcl_region_t;

typedef struct
{
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

typedef struct
{
    uintptr_t object;
    int32_t gid;
    int32_t x;
    int32_t y;
    int32_t ownerIndex;
    int32_t teamOld;
    int32_t teamNew;
    int32_t typeWord;
    uint8_t dead;
    uint8_t activeFlag;
} rcl_obj_t;

typedef struct
{
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
    const char *name;
    const char *ownerName;
    int32_t targetX;
    int32_t targetY;
    int32_t ownerX;
    int32_t ownerY;
    float speed;
    float radius;
    float angle;
    uint64_t spawnedAt;
    float vx;
    float vy;
    int isThrower;
    int isBeam;
    int32_t spawnAreaRadius;
    int32_t spawnAreaActiveTime;
    int32_t castRange;
} rcl_proj_t;

typedef struct
{
    const char *name;
    float angle;
    int32_t spawnX;
    int32_t spawnY;
    int32_t x;
    int32_t y;
} rcl_proj_death_t;

#endif
