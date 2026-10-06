#ifndef TITANOX_RUNTIME_SCENE_H
#define TITANOX_RUNTIME_SCENE_H

#include "core/types.h"

uintptr_t tnx_battle_global(void);
void tnx_chain(void);
uintptr_t tnx_mode_ptr(uintptr_t off);
int tnx_pair(uintptr_t obj, int32_t *x, int32_t *y);
void tnx_run_workload(void);
int tnx_src(uintptr_t off, int32_t *x, int32_t *y, int *flag);
int tnx_weq(int32_t a, int32_t b, int32_t out, int32_t d);

#endif
