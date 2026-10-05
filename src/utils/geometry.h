#ifndef TITANOX_UTILS_GEOMETRY_H
#define TITANOX_UTILS_GEOMETRY_H

#include "core/types.h"

extern int g_v95_find_joy_done;
extern uint64_t g_v48_ticks;
extern int g_v48_entry_logs;
extern uintptr_t g_v48_manager;
extern int g_v162_logs;
extern int32_t g_v162_max_x;
extern int32_t g_v162_max_y;
extern uint64_t g_v213_dec_us;
extern uint64_t g_v213_dec_us_max;
extern int g_v177_logs;
extern int g_v177_seeded;
extern int32_t g_v177_last_x;
extern int32_t g_v177_last_y;

int tnx_v48_collect(uintptr_t manager, tnx_v47_obj_t *out, int capacity, int *rejected);
int tnx_v48_small(long value);
float tnx_v48_as_float(uint32_t bits);
void tnx_v48_discriminate(uintptr_t manager);
void tnx_v48_probe(uintptr_t manager, uintptr_t mode, int verbose);
int tnx_v95_finite(float v);
uintptr_t tnx_v162_bounds_obj(uintptr_t receiver);
int tnx_v162_clamp(int32_t *x, int32_t *y);
uint64_t tnx_v213_us(void);
void tnx_v177_paircal(void);

#endif
