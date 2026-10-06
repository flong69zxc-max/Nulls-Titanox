#ifndef TITANOX_DODGE_AUTODODGE_H
#define TITANOX_DODGE_AUTODODGE_H

#include "core/types.h"

extern uint64_t g_drop_slow;
extern uint64_t g_drop_fast;
extern uint64_t g_drop_blink;
extern uint64_t g_logs_9;
extern float g_spd_min;
extern float g_spd_max;
extern uint64_t g_gate_writes_2;
extern uint64_t g_gate_held;
extern uint64_t g_update_hits;
extern uint64_t g_move_hits;
extern uint64_t g_ticks;
extern __thread int g_in_drive;
extern uint64_t g_reentry;
extern uint64_t g_render_skip;
extern uint64_t g_update_skip;
extern int g_state;
extern int g_pl_n;
extern int32_t g_pl_x[TNX_PLAYER_MAX];
extern int32_t g_pl_y[TNX_PLAYER_MAX];
extern int32_t g_pl_team[TNX_PLAYER_MAX];
extern int32_t g_pl_mine[TNX_PLAYER_MAX];
extern int g_mate_n;
extern int32_t g_mate_x[TNX_MATE_MAX];
extern int32_t g_mate_y[TNX_MATE_MAX];
extern int g_own_x;
extern int g_own_y;
extern int g_own_team_4;
extern int g_attrib_hits;
extern int g_attrib_miss;
extern int g_attrib_logs;
extern int g_block_hits;
extern int g_label_builds;
extern int g_team_trust;
extern int32_t g_own_team_5;
extern int32_t g_enemy_x[TNX_PLAYER_MAX];
extern int32_t g_enemy_y[TNX_PLAYER_MAX];
extern int g_enemy_n;
extern int g_trust_logs;
extern int g_roster_logs;
extern int g_enemy_blocks;
extern int g_oneshot_segs;
extern uint64_t g_flees;
extern uint64_t g_dead_replaced;
extern int g_new_tick;
extern int g_prev_seg;
extern int g_logs_8;
extern uint64_t g_mate_turns;
extern uint64_t g_mate_stuck;
extern int32_t g_pl_gid[TNX_PLAYER_MAX];
extern int32_t g_pl_sx[TNX_PLAYER_MAX];
extern int32_t g_pl_sy[TNX_PLAYER_MAX];
extern int g_pl_spawned[TNX_PLAYER_MAX];
extern int g_mates;
extern int g_enemies;
extern int g_agree;
extern int g_cluster_logs;
extern uint64_t g_freest_used;
extern int g_dump_logs;
extern uint64_t g_touchid_writes;
extern uint64_t g_human;
extern uint64_t g_stick_skips;
extern uint64_t g_stuck_2;
extern int g_stuck_logs;
extern uint64_t g_gate_writes;
extern int g_flag_logs;
extern uint64_t g_dead_picks;
extern int g_prev_idx;
extern uint64_t g_hold_until;
extern uint64_t g_last_danger;
extern int32_t g_tx;
extern int32_t g_ty;
extern int g_active_2;
extern tnx_seg_t g_seg[TNX_SEG_MAX];
extern int g_seg_count;
extern int g_build_tick;
extern uint64_t g_escapes;
extern uint64_t g_logs_7;
extern uint64_t g_lookahead;
extern uint64_t g_rage_frames;
extern int g_logs_4;
extern int g_probe_logs_2;
extern int g_own_logs_7;
extern int g_have_angle;
extern float g_angle;
extern float g_tx_2;
extern float g_ty_2;
extern int g_moving;
extern float g_start_x;
extern float g_start_y;
extern int g_picks;
extern int g_drive_ticks;
extern int g_drive_logs;
extern uint64_t g_queue_calls;
extern uint64_t g_queue_skips;
extern int32_t g_sent_dx;
extern int32_t g_sent_dy;
extern int32_t g_last_tx_2;
extern int32_t g_last_ty_2;
extern uint64_t g_last_decision;
extern int64_t g_decide_x;
extern int64_t g_decide_y;
extern int g_drift_logs;
extern uint64_t g_drift_done;
extern uint64_t g_max_frame;
extern uint64_t g_traveled;
extern float g_pair_dot_sum;
extern uint64_t g_pair_dot_n;
extern float g_last_x_3;
extern float g_last_y_3;
extern int g_last_ok;
extern uint64_t g_keeps;
extern uint64_t g_engage;
extern uint64_t g_hseed;
extern uint64_t g_evals;
extern int g_sel[TNX_SEL_MAX];
extern int g_sel_n;
extern uint64_t g_pos_skips;
extern int g_cand_now[TNX_CAND];
extern int g_cand_frame[TNX_CAND];
extern int g_cand_changes[TNX_CAND];
extern int g_cand_seen;
extern int g_dead_slot;
extern int g_dead_value;
extern int g_pending;
extern int g_pending_tick;
extern int g_pre[TNX_CAND];
extern int32_t g_prev_x;
extern int32_t g_prev_y;
extern int g_prev_valid;
extern int g_respawn_tick;
extern int g_respawns;
extern int g_life_logs;
extern int g_signal_logs_2;
extern int g_learn_logs;

const char *tnx_state_name(void);
int tnx_team_at(const tnx_obj_t *objects, int index);
void tnx_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const tnx_obj_t *objects, int usable);
int tnx_own_ok(int32_t x, int32_t y);
int tnx_enemy_blocked(float x, float y, float ownX, float ownY);
int tnx_mate_blocked(float x, float y);
int tnx_own_side_spawn(int32_t sx, int32_t sy);
uintptr_t tnx_bs(void);
int tnx_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by, uint32_t *mode, float *cs, float *sn);
int tnx_joy_angle(float *outAngle);
void tnx_select(float px, float py);
int tnx_drive(void);
void tnx_candidates(uintptr_t ownElem, int *out);
const char *tnx_cand_name(int slot);
void tnx_clear_life(void);
void tnx_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
int tnx_life(uintptr_t ownElem, int32_t ownX, int32_t ownY);
void tnx_drift(void);
void tnx_dump(void);
void tnx_core(void);
void tnx_probe_2(void);
void tnx_build(void);
float tnx_seg_dist2(float px, float py, const tnx_seg_t *s);
int tnx_threatened(float x, float y);
float tnx_clearance_2(float x, float y);
float tnx_eta_ms(float x, float y);
int tnx_imminent(float x, float y);
int tnx_flee(float px, float py, float *tx, float *ty);
void tnx_predict_2(int32_t ownX, int32_t ownY, float tx, float ty);
void tnx_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape);
int tnx_body_blocked_2(float px, float py, float dirX, float dirY, float len);
float tnx_body_score(float px, float py, float dirX, float dirY, float len);
float tnx_speed(void);
float tnx_clearance_3(float px, float py, float dirX, float dirY);
float tnx_score(float px, float py, float dirX, float dirY, float len);
float tnx_body_score_2(float px, float py, float dirX, float dirY, float len);
void tnx_unblock(float px, float py, float len, float *dirX, float *dirY);
int tnx_valid_point(float x, float y);
int tnx_walk_into_bullet(float px, float py, float dirX, float dirY, float travel);
float tnx_safe_angle(float px, float py, float desiredDeg, int *ok);
int tnx_passed(float px, float py);
int tnx_best(float px, float py, float *tx, float *ty);
int tnx_write(float dirX, float dirY);
int tnx_freest(float px, float py, float *tx, float *ty);
int tnx_decide(int32_t ownX, int32_t ownY);
void tnx_autododge_v48(void);
void tnx_dodge_plan(uintptr_t manager, int32_t team);
void tnx_dodge_all_teams(uintptr_t manager);

extern float g_own_r;

extern int g_own_r_cfg_logs;

extern int g_own_r_logs;

extern int g_own_r_n;

extern int g_pick_key_c;

extern int g_pick_key_t;

extern int g_side_flips;

extern int g_side_last;

extern int g_side_picks;

extern int g_side_tick;

extern uint64_t g_stat_side;

extern float g_tti_min;

float tnx_clear_at(float px, float py, int i);

int tnx_key_c(int n);

int tnx_key_t(float tti);

float tnx_learn_rate(int c, int t, int side);

int tnx_ok(float v, float lo, float hi);

extern float g_last_dist;
extern float g_rad_est;
extern float g_track_min[TNX_SEG_MAX];
extern float g_track_rad[TNX_SEG_MAX];
extern float g_track_ux[TNX_SEG_MAX];
extern float g_track_uy[TNX_SEG_MAX];
extern int g_cal_miss;
extern int g_cal_off_seen;
extern int g_clip_test_win;
extern int g_clip_win;
extern int g_crit_reaction;
extern int g_rad_bad;
extern int g_rad_off;
extern int g_shot_key[TNX_SEG_MAX];
extern int g_snap_calls;
extern int g_snap_live;
extern int g_snap_logs;
extern int g_snap_off_logs;
extern int g_track_gid[TNX_SEG_MAX];
extern int g_track_hit[TNX_SEG_MAX];
extern int g_track_pside[TNX_SEG_MAX];
extern uint64_t g_howto_logs;
extern uint64_t g_last_stat;
extern uint64_t g_react_max;
extern uint64_t g_react_min;
extern uint64_t g_react_n;
extern uint64_t g_react_sum;
extern uint64_t g_stat_commit;
extern uint64_t g_stat_picks;
extern uint64_t g_stat_reset;
extern uint64_t g_wall_stops;
float tnx_all_clear(float x, float y);
int tnx_wall_blocked(float x0, float y0, float x1, float y1);

#endif
