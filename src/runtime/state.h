#ifndef TITANOX_RUNTIME_STATE_H
#define TITANOX_RUNTIME_STATE_H

#include "core/types.h"

extern uint64_t t_ticks_4;
int tnx_battle_gate_2(int v63);
int tnx_scan_allowed(uint64_t fired, uint64_t total);
void tnx_start_timer(void);
int tnx_state_tick(void);
int tnx_vtable_is_data(uintptr_t vtable);

#endif
