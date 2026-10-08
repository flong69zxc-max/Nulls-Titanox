#ifndef RECOIL_CORE_STATE_H
#define RECOIL_CORE_STATE_H

#include "./types.h"

extern int rcl_battle_active;
extern int rcl_battle_last_tick;
extern int rcl_hb_sig_prev;
int rcl_battle_gate(int scene);

extern uint64_t rcl_ticks_b;
int rcl_battle_gate_2(int v63);
int rcl_scan_allowed(uint64_t fired, uint64_t total);
void rcl_start_timer(void);
int rcl_state_tick(void);
int rcl_vtable_is_data(uintptr_t vtable);

#endif
