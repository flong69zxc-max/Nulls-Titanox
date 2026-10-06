#ifndef TITANOX_DIAG_DIAG_H
#define TITANOX_DIAG_DIAG_H

#include "core/types.h"

/* dumps, probes and reports; nothing here decides anything */

extern int g_active;
extern uintptr_t g_ag_manager;
extern int g_ag_objectCount;
extern uintptr_t g_base;
extern int64_t g_elem_moves;
extern uint64_t g_engage_writes;
extern int g_enq_x;
extern int g_enq_y;
extern uint64_t g_gate_writes;
extern uint64_t g_human_live;
extern int64_t g_moves;
extern int32_t g_own_team_5;
extern int g_own_x;
extern int g_own_y;
extern uint64_t g_pred_calls;
extern uint64_t g_pred_fails;
extern int g_readback;
extern uintptr_t g_scene_object;
extern uint64_t g_slot_hits[TNX_SLOT_COUNT];
extern int g_test_state_2;
extern int g_tested_2;
extern uint64_t g_tick_2;
extern tnx_vtcensus_t g_vtcensus[TNX_VTCENSUS_MAX];
extern int g_vtcensus_used;
extern uintptr_t g_wit_elem;
extern int32_t g_wit_x0;
extern int32_t g_wit_x1;
extern int32_t g_wit_y0;
extern int32_t g_wit_y1;
void tnx_audit_all(void);
const char *tnx_cand_name(int slot);
void tnx_candidates(uintptr_t ownElem, int *out);
void tnx_class_dump(const tnx_obj_t *objects, int usable);
void tnx_core(void);
void tnx_diag_report(const char *why);
void tnx_drift(void);
void tnx_dump(void);
void tnx_engage_report(const char *why);
int tnx_fields(void);
int tnx_fields_pair(uintptr_t *srcOut, int32_t *xOut, int32_t *yOut);
void tnx_frame_window(void);
void tnx_gate_report(int slotHit);
uint64_t tnx_hook_dispatches(void);
void tnx_hop_dump(uintptr_t client, uintptr_t inner);
void tnx_map_dump(uintptr_t bounds);
int tnx_object_detail(uintptr_t manager, int limit);
uint64_t tnx_object_dispatches(void);
void tnx_players_dump(uintptr_t players, uintptr_t array, int32_t count, int32_t capacity);
void tnx_pos_trace(const tnx_obj_t *objects, int usable);
void tnx_probe_2(void);
void tnx_queue_line(void);
void tnx_readback(int plus);
void tnx_receiver_line(const char *name, uintptr_t holder);
void tnx_receiver_probe(void);
void tnx_report_manager(const char *tag, uintptr_t manager);
void tnx_report_mode_hit(const char *tag, uintptr_t slot, uintptr_t object);
void tnx_slot_diag(const char *why);
void tnx_slot_line(const char *name, const tnx_win_t *w, int slot, uint32_t before, uint32_t after);
int tnx_slot_probe(void);
void tnx_slot_table_dump(void);
void tnx_statics(void);
void tnx_team_dump(const tnx_obj_t *objects, int usable);
void tnx_test(const tnx_obj_t *objects, int usable, int ownIndex);
void tnx_trail_dump(void);
int tnx_trail_verdict(const tnx_trail_t *entry, char *buf, size_t size);
int tnx_vtcensus_top(int byShaped);
void tnx_window(int plus);
int tnx_witness(int32_t *x, int32_t *y);
void tnx_witness_line(int plus);
void tnx_write_test(const tnx_obj_t *objects, int usable, int ownIndex);

#endif
