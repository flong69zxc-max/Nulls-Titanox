#ifndef TITANOX_UTILS_GEOMETRY_H
#define TITANOX_UTILS_GEOMETRY_H

#include "core/types.h"

extern int t_find_joy_done;
extern uint64_t t_ticks_3;
extern int t_entry_logs;
extern uintptr_t t_manager;
extern int t_logs_2;
extern int32_t t_max_x;
extern int32_t t_max_y;
extern uint64_t t_dec_us;
extern uint64_t t_dec_us_max;
extern int t_logs_5;
extern int t_seeded;
extern int32_t t_last_x_2;
extern int32_t t_last_y_2;

int tnx_collect(uintptr_t manager, tnx_obj_t *out, int capacity, int *rejected);
int tnx_small(long value);
float tnx_as_float(uint32_t bits);
void tnx_discriminate(uintptr_t manager);
void tnx_probe_3(uintptr_t manager, uintptr_t mode, int verbose);
uintptr_t tnx_bounds_obj(uintptr_t receiver);
int tnx_clamp(int32_t *x, int32_t *y);
uint64_t tnx_us(void);
void tnx_paircal(void);

#endif
