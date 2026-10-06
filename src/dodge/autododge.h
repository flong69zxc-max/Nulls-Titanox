#ifndef TITANOX_DODGE_AUTODODGE_H
#define TITANOX_DODGE_AUTODODGE_H

#include "core/types.h"

extern uint64_t t_drop_slow;
extern uint64_t t_drop_fast;
extern uint64_t t_drop_blink;
extern uint64_t t_logs_9;
extern float t_spd_min;
extern float t_spd_max;
extern uint64_t t_gate_writes_2;
extern uint64_t t_gate_held;
extern uint64_t t_update_hits;
extern uint64_t t_move_hits;
extern uint64_t t_ticks;
extern __thread int t_in_drive;
extern uint64_t t_reentry;
extern uint64_t t_render_skip;
extern uint64_t t_update_skip;
extern int t_state;
extern int t_pl_n;
extern int32_t t_pl_x[TNX_PLAYER_MAX];
extern int32_t t_pl_y[TNX_PLAYER_MAX];
extern int32_t t_pl_team[TNX_PLAYER_MAX];
extern int32_t t_pl_mine[TNX_PLAYER_MAX];
extern int t_mate_n;
extern int32_t t_mate_x[TNX_MATE_MAX];
extern int32_t t_mate_y[TNX_MATE_MAX];
extern int t_own_x;
extern int t_own_y;
extern int t_own_team_4;
extern int t_attrib_hits;
extern int t_attrib_miss;
extern int t_attrib_logs;
extern int t_block_hits;
extern int t_label_builds;
extern int t_team_trust;
extern int32_t t_own_team_5;
extern int32_t t_enemy_x[TNX_PLAYER_MAX];
extern int32_t t_enemy_y[TNX_PLAYER_MAX];
extern int t_enemy_n;
extern int t_trust_logs;
extern int t_roster_logs;
extern int t_enemy_blocks;
extern int t_oneshot_segs;
extern uint64_t t_flees;
extern uint64_t t_dead_replaced;
extern int t_new_tick;
extern int t_prev_seg;
extern int t_logs_8;
extern uint64_t t_mate_turns;
extern uint64_t t_mate_stuck;
extern int32_t t_pl_gid[TNX_PLAYER_MAX];
extern int32_t t_pl_sx[TNX_PLAYER_MAX];
extern int32_t t_pl_sy[TNX_PLAYER_MAX];
extern int t_pl_spawned[TNX_PLAYER_MAX];
extern int t_mates;
extern int t_enemies;
extern int t_agree;
extern int t_cluster_logs;
extern uint64_t t_freest_used;
extern int t_dump_logs;
extern uint64_t t_touchid_writes;
extern uint64_t t_human;
extern uint64_t t_stick_skips;
extern uint64_t t_stuck_2;
extern int t_stuck_logs;
extern uint64_t t_gate_writes;
extern int t_flag_logs;
extern uint64_t t_dead_picks;
extern int t_prev_idx;
extern uint64_t t_hold_until;
extern uint64_t t_last_danger;
extern int32_t t_tx;
extern int32_t t_ty;
extern int t_active_2;

extern int t_js_live;

extern uint64_t t_js_tick;

int tnx_js_owns_3(void);
extern tnx_seg_t t_seg[TNX_SEG_MAX];
extern int t_seg_count;
extern int t_build_tick;
extern uint64_t t_escapes;
extern uint64_t t_logs_7;
extern uint64_t t_lookahead;
extern uint64_t t_rage_frames;
extern int t_logs_4;
extern int t_have_angle;
extern float t_angle;
extern float t_tx_2;
extern float t_ty_2;
extern int t_moving;
extern float t_start_x;
extern float t_start_y;
extern int t_picks;
extern int t_drive_ticks;
extern int t_drive_logs;
extern uint64_t t_queue_calls;
extern uint64_t t_queue_skips;
extern int32_t t_sent_dx;
extern int32_t t_sent_dy;
extern int32_t t_last_tx_2;
extern int32_t t_last_ty_2;
extern uint64_t t_last_decision;
extern int64_t t_decide_x;
extern int64_t t_decide_y;
extern int t_drift_logs;
extern uint64_t t_drift_done;
extern uint64_t t_max_frame;
extern uint64_t t_traveled;
extern float t_pair_dot_sum;
extern uint64_t t_pair_dot_n;
extern float t_last_x_3;
extern float t_last_y_3;
extern int t_last_ok;
extern uint64_t t_keeps;
extern uint64_t t_engage;
extern uint64_t t_hseed;
extern uint64_t t_evals;
extern int t_sel[TNX_SEL_MAX];
extern int t_sel_n;
extern uint64_t t_pos_skips;
extern int t_cand_now[TNX_CAND];
extern int t_cand_frame[TNX_CAND];
extern int t_cand_changes[TNX_CAND];
extern int t_cand_seen;
extern int t_dead_slot;
extern int t_dead_value;
extern int t_pending;
extern int t_pending_tick;
extern int t_pre[TNX_CAND];
extern int32_t t_prev_x;
extern int32_t t_prev_y;
extern int t_prev_valid;
extern int t_respawn_tick;
extern int t_respawns;
extern int t_life_logs;
extern int t_signal_logs_2;
extern int t_learn_logs;

const char *tnx_state_name(void);
int tnx_team_at(const tnx_obj_t *objects, int index);
void tnx_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const tnx_obj_t *objects, int usable);
int tnx_own_ok(int32_t x, int32_t y);
int tnx_enemy_blocked(float x, float y, float ownX, float ownY);
int tnx_mate_blocked(float x, float y);
int tnx_own_side_spawn(int32_t sx, int32_t sy);
extern float t_joy_drive_ax;

extern float t_joy_drive_ay;

extern float t_joy_drive_cx;

extern float t_joy_drive_cy;

extern int t_joy_drive_on;

extern int t_joy_drive_ok;

int tnx_joy_set(float dirX, float dirY, int on);

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
void tnx_build(void);
float tnx_seg_dist2(float px, float py, const tnx_seg_t *s);
int tnx_threatened(float x, float y);
float tnx_clearance_2(float x, float y);
float tnx_eta_ms(float x, float y);
int tnx_imminent(float x, float y);
int tnx_flee(float px, float py, float *tx, float *ty);
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
int tnx_freest(float px, float py, float *tx, float *ty);
int tnx_decide(int32_t ownX, int32_t ownY);
void tnx_autododge_v48(void);
void tnx_dodge_plan(uintptr_t manager, int32_t team);
void tnx_dodge_all_teams(uintptr_t manager);

extern float t_own_r;

extern int t_own_r_cfg_logs;

extern int t_own_r_logs;

extern int t_own_r_n;

extern int t_pick_key_c;

extern int t_pick_key_t;

extern int t_side_flips;

extern int t_side_last;

extern int t_side_picks;

extern int t_side_tick;

extern uint64_t t_stat_side;

extern float t_tti_min;

float tnx_clear_at(float px, float py, int i);

int tnx_key_c(int n);

int tnx_key_t(float tti);

float tnx_learn_rate(int c, int t, int side);

int tnx_ok(float v, float lo, float hi);

extern float t_last_dist;
extern float t_rad_est;
extern float t_track_min[TNX_SEG_MAX];
extern float t_track_rad[TNX_SEG_MAX];
extern float t_track_ux[TNX_SEG_MAX];
extern float t_track_uy[TNX_SEG_MAX];
extern int t_cal_miss;
extern int t_cal_off_seen;
extern int t_clip_test_win;
extern int t_clip_win;
extern int t_crit_reaction;
extern int t_rad_bad;
extern int t_rad_off;
extern int t_shot_key[TNX_SEG_MAX];
extern int t_snap_calls;
extern int t_snap_live;
extern int t_snap_logs;
extern int t_snap_off_logs;
extern int t_track_gid[TNX_SEG_MAX];
extern int t_track_hit[TNX_SEG_MAX];
extern int t_track_pside[TNX_SEG_MAX];
extern uint64_t t_howto_logs;
extern uint64_t t_last_stat;
extern uint64_t t_react_max;
extern uint64_t t_react_min;
extern uint64_t t_react_n;
extern uint64_t t_react_sum;
extern uint64_t t_stat_commit;
extern uint64_t t_stat_picks;
extern uint64_t t_stat_reset;
extern uint64_t t_wall_stops;
float tnx_all_clear(float x, float y);
int tnx_wall_blocked(float x0, float y0, float x1, float y1);

extern int t_cal_n;
extern float t_cal_rad_seen;
extern uint64_t t_commit_until;
extern uint64_t t_crit_last;
extern uint64_t t_crit_took;
extern int t_dodge_probe_usable;
extern float t_mom_live;
extern uint64_t t_no_threat_since;
extern uint64_t t_own_obj_last;
extern float t_own_vx;
extern float t_own_vy;
extern uint64_t t_prev_own_tick;
extern float t_prev_own_x;
extern float t_prev_own_y;
extern int t_proj_r_cfg_logs;
extern int t_rad_logs;
extern int t_rad_n;
extern uint64_t t_rad_test;
extern int t_released;
extern int t_scene_skip;
extern uint64_t t_shot_logs;
extern float t_shot_speed[TNX_PROJ_MAX];
extern int t_stat_skip;
extern int t_tti_logs;
int tnx_body_blocked(float x, float y, float ownX, float ownY);
void tnx_contact_note(float dist, float projR);
float tnx_own_radius(void);
float tnx_proj_radius(const tnx_proj_t *p, float speed);
float tnx_seg_dist(float ax, float ay, float bx, float by, float px, float py);
void tnx_threats(void);

#endif
