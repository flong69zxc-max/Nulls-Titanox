#ifndef RECOIL_UTILS_GEOMETRY_H
#define RECOIL_UTILS_GEOMETRY_H

#include "core/types.h"

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

#endif
