#ifndef TITANOX_UTILS_GEOMETRY_H
#define TITANOX_UTILS_GEOMETRY_H

#include "core/types.h"

extern int t_find_joy_done;
extern uint64_t t_ticks_a;
extern uintptr_t t_manager;
extern uint64_t t_dec_us;
extern uint64_t t_dec_us_max;
extern int t_logs_a;
extern int t_seeded;
extern int32_t t_last_x_a;
extern int32_t t_last_y_a;

int tnx_collect(uintptr_t manager, tnx_obj_t *out, int capacity, int *rejected);
int tnx_small(long value);
float tnx_as_float(uint32_t bits);
void tnx_discriminate(uintptr_t manager);
void tnx_probe(uintptr_t manager, uintptr_t mode, int verbose);
uintptr_t tnx_bounds_obj(uintptr_t receiver);
int tnx_clamp(int32_t *x, int32_t *y);
uint64_t tnx_us(void);
void tnx_paircal(void);

uintptr_t tnx_pair_base(void);

#endif
