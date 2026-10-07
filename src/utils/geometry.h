#ifndef RECOIL_UTILS_GEOMETRY_H
#define RECOIL_UTILS_GEOMETRY_H

#include "../core/types.h"

extern int rcl_find_joy_done;
extern uint64_t rcl_ticks_a;
extern uintptr_t rcl_manager_ptr;
extern uint64_t rcl_dec_us;
extern uint64_t rcl_dec_us_max;
extern int rcl_logs_a;
extern int rcl_seeded;
extern int32_t rcl_last_x_a;
extern int32_t rcl_last_y_a;

int rcl_collect(uintptr_t manager, rcl_obj_t *out, int capacity);
int rcl_small(long value);
float rcl_as_float(uint32_t bits);
void rcl_discriminate(uintptr_t manager);
void rcl_probe(uintptr_t manager, uintptr_t mode, int verbose);
uintptr_t rcl_bounds_obj(uintptr_t receiver);
int rcl_clamp(int32_t *x, int32_t *y);
uint64_t rcl_us(void);
void rcl_paircal(void);

uintptr_t rcl_pair_base(void);

#define RCL_COORD_SOFT 0
#define RCL_WALL_CLIP 1
#define RCL_REBUILD_TICKS 60
#define RCL_MIN_PASSES 3
#define RCL_MIN_CLIP 60.0f
#define RCL_MIN_IMG_PCT 0
#define RCL_MAX_SOLID_PCT 60
#define RCL_MAX_CLIP_PCT 70
#define RCL_MIN_SEGS 4
#define RCL_NP_DUMPS 8
#define RCL_ELEMS 8
#define RCL_WORDS_2 24
#define RCL_VALUE_MAX 1000000
#define RCL_FLOAT_MAX 10000.0f
#define RCL_TEAM_MAX 8

#endif
