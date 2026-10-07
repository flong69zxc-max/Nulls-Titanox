#ifndef RECOIL_RUNTIME_SLOTS_H
#define RECOIL_RUNTIME_SLOTS_H

#include "core/config.h"
#include "hook.h"

void rcl_slot_note(int index, void *self, uint64_t arg1);
uint64_t rcl_hook_dispatches(void);
uint64_t rcl_object_dispatches(void);
int rcl_manager_live_count(uintptr_t manager);

extern int rcl_bar_logged;
extern int rcl_fb_logged;
extern int rcl_fb_on;
extern int rcl_idle_logged;
extern uint64_t rcl_idle_start;
extern int rcl_live_objs;
extern int rcl_live_teams;
extern unsigned long long rcl_obj_prev;
extern int rcl_own_idhit;
extern uintptr_t rcl_pub_array;
extern int32_t rcl_pub_count;
extern int rcl_pub_logs;
extern uintptr_t rcl_pub_object;
extern int rcl_scan_armed;
extern volatile uint32_t rcl_seq;
extern uintptr_t rcl_setpred;
extern uintptr_t rcl_site;
extern rcl_slot_fn_t rcl_slot_orig[RCL_SLOT_COUNT];
extern const rcl_hook_t rcl_slot_specs[RCL_SLOT_COUNT];
extern int rcl_state_2;
extern uintptr_t rcl_tick_array;
extern int32_t rcl_tick_count;
extern uintptr_t rcl_tick_object;
extern const int rcl_object_slots[RCL_OBJ_SLOTS];
void rcl_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap, const char *why);
void rcl_slot_hooks_install(void);
void rcl_slot_pump(void);
uint64_t rcl_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_32(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
int rcl_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut);
void rcl_tick_begin(void);


extern rcl_slot_fn_t rcl_slot_orig[RCL_SLOT_COUNT];
extern uintptr_t rcl_slot_object[RCL_SLOT_COUNT];
extern uintptr_t rcl_slot_arg[RCL_SLOT_COUNT];
extern uint64_t rcl_slot_hits[RCL_SLOT_COUNT];
extern uintptr_t rcl_slot_adopted;
extern const rcl_hook_t rcl_slot_specs[RCL_SLOT_COUNT];
uint64_t rcl_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_32(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);
uint64_t rcl_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

#endif
