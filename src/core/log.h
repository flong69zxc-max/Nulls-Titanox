#ifndef TITANOX_CORE_LOG_H
#define TITANOX_CORE_LOG_H

#include "core/types.h"

extern const char *g_v190_log_drop[67];
extern const char *g_v190_log_keep[19];
extern uint64_t g_v190_drop_counts[64];
extern uint64_t g_v190_dropped;
extern uint64_t g_v190_kept;
extern uint64_t g_v190_log_rolls;
extern int g_v63_hb_sig_prev;
extern int g_v63_image_count;
extern uintptr_t g_v63_image_top_mgr;
extern int32_t g_v63_image_top_count;
extern int g_v63_image_first;
extern int g_v63_chain_vtchanged;
extern int g_v63_chain_stable_logged;
extern int g_v63_stringy_logs;
extern int g_v63_battle_active;
extern int g_v63_battle_last_tick;
extern const char *g_v63_battle_reason;
extern uint32_t g_v116_mode_hist[TNX_V116_HIST_MODES];
extern int64_t g_v116_last_mode;
extern int32_t g_v116_interp_prev_x;
extern int32_t g_v116_interp_prev_y;
extern int g_v116_interp_have;
extern uint64_t g_v116_interp_moves;
extern uint64_t g_v116_interp_checks;
extern uint64_t g_v116_interp_tick;
extern int g_v116_hist_logs;
extern uint64_t g_v190_engage_start;
extern uint64_t g_v190_engage_last;
extern uint64_t g_v190_engage_writes;
extern uint64_t g_v190_move_tick;
extern uint64_t g_v190_applied_match;
extern uint64_t g_v190_applied_miss;
extern int32_t g_v190_own_x;
extern int32_t g_v190_own_y;
extern int32_t g_v190_prev_x;
extern int32_t g_v190_prev_y;
extern int32_t g_v190_pick_x;
extern int32_t g_v190_pick_y;
extern int g_v190_engaged;
extern int g_v190_prev_valid;
extern int g_v190_logs;
extern uint64_t g_v190_lifetime;
extern uint64_t g_v190_applied_writes;
extern uint64_t g_v190_applied_idle;

FILE *tnx_log_handle(void);
int tnx_v190_keep_line(const char *text);
void tnx_v190_log_census(void);
void tnx_v190_log_roll(void);
void tnx_write_line(const char *text);
void tlog(NSString *msg);
void tnx_logf(const char *format, ...);
void tnx_slot_note(int index, void *self, uint64_t arg1);
void tnx_slot_fired_report(void);
void tnx_v63_flush_buckets(void);
int tnx_v63_battle_gate(int scene);
void tnx_v63_log_heartbeat(void);
void tnx_report_mode_hit(const char *tag, uintptr_t slot, uintptr_t object);
int tnx_manager_live_count(uintptr_t manager);
int tnx_vtcensus_top(int byShaped);
void tnx_slot_diag(const char *why);
void tnx_diag_report(const char *why);
void tnx_report_manager(const char *tag, uintptr_t manager);
void tnx_trail_dump(void);
void tnx_slot_table_dump(void);
int tnx_object_detail(uintptr_t manager, int limit);
int tnx_v116_interp(int32_t *x, int32_t *y);
void tnx_v116_frame(void);
void tnx_v116_interp_line(void);
void tnx_v190_engage_report(const char *why);
void tnx_v190_drive_note(int32_t ownX, int32_t ownY, int32_t tx, int32_t ty, int32_t appX, int32_t appY, int32_t pairX, int32_t pairY);

#endif
