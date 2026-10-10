#ifndef RECOIL_HELPERS_ASSIST_ASSIST_H
#define RECOIL_HELPERS_ASSIST_ASSIST_H

#include "../core/offsets.h"
#include <stdint.h>

#define RCL_ASSIST_TILE 300
#define RCL_ASSIST_TILE_MIN 1
#define RCL_ASSIST_TILE_MAX 64
#define RCL_ASSIST_STICKY 200
#define RCL_ASSIST_INTERVAL 1000
#define RCL_ASSIST_INTERVAL_MIN 100
#define RCL_ASSIST_INTERVAL_MAX 10000
#define RCL_ASSIST_SPEED_MIN 100
#define RCL_ASSIST_SPEED_MAX 20000
#define RCL_ASSIST_LINKED_BEHAVIOR 3
#define RCL_ASSIST_TARGET_MAX 64
#define RCL_ASSIST_COORD_MAX 200000.0f
#define RCL_ASSIST_LEAD_TMAX 2.5f
#define RCL_ASSIST_LATENCY 0.033f
#define RCL_ASSIST_ITER 4

typedef struct
{
    uintptr_t object;
    int32_t gid;
    int32_t x;
    int32_t y;
    float distanceSq;
} rcl_assist_target_t;

void rcl_assist_reset(void);
uintptr_t rcl_assist_own(void);
void *rcl_assist_skill(uintptr_t elem);
int rcl_assist_range(uintptr_t elem, const char *code);
int rcl_assist_interval(uintptr_t elem);
int rcl_assist_speed(uintptr_t elem, const char *code);
int rcl_assist_pick(uintptr_t elem, int32_t myX, int32_t myY, int range, rcl_assist_target_t *out);
int rcl_assist_aim(uintptr_t screen, int32_t aimX, int32_t aimY);
int rcl_assist_cast(uintptr_t elem, int32_t dx, int32_t dy);
void rcl_run_assist(void);

#endif
