#ifndef RECOIL_DODGE_AUTODODGE_H
#define RECOIL_DODGE_AUTODODGE_H

#include "core/types.h"

extern uint64_t rcl_drop_slow;
extern uint64_t rcl_drop_fast;
extern uint64_t rcl_drop_blink;
extern float rcl_spd_min;
extern float rcl_spd_max;
extern __thread int rcl_in_drive;
extern int rcl_state_code;
extern int rcl_pl_n;
extern int32_t rcl_pl_x[RCL_PLAYER_MAX];
extern int32_t rcl_pl_y[RCL_PLAYER_MAX];
extern int32_t rcl_pl_team[RCL_PLAYER_MAX];
extern int32_t rcl_pl_mine[RCL_PLAYER_MAX];
extern int rcl_mate_n;
extern int32_t rcl_mate_x[RCL_MATE_MAX];
extern int32_t rcl_mate_y[RCL_MATE_MAX];
extern int rcl_own_team_b;
extern int rcl_team_trust;
extern int32_t rcl_enemy_x[RCL_PLAYER_MAX];
extern int32_t rcl_enemy_y[RCL_PLAYER_MAX];
extern int rcl_enemy_n;
extern int rcl_new_tick;
extern int rcl_prev_seg;
extern int rcl_mates;
extern int rcl_enemies;
extern int rcl_agree;
extern uint64_t rcl_human;
extern int32_t rcl_tx;
extern int32_t rcl_ty;
extern int rcl_active;

extern int rcl_js_live;

extern uint64_t rcl_js_tick;

int rcl_js_owns(void);
extern rcl_seg_t rcl_seg[RCL_SEG_MAX];
extern int rcl_seg_count;
extern int rcl_build_tick;
extern int rcl_have_angle;
extern float rcl_angle;
extern float rcl_tx_a;
extern float rcl_ty_a;
extern int rcl_moving;
extern float rcl_start_x;
extern float rcl_start_y;
extern int rcl_drive_logs;
extern float rcl_last_x_b;
extern float rcl_last_y_b;
extern int rcl_last_ok;
extern int rcl_sel[RCL_SEL_MAX];
extern int rcl_sel_n;
extern uint64_t rcl_pos_skips;
extern int rcl_cand_now[RCL_CAND];
extern int rcl_cand_frame[RCL_CAND];
extern int rcl_cand_changes[RCL_CAND];
extern int rcl_cand_seen;
extern int rcl_dead_slot;
extern int rcl_dead_value;
extern int rcl_pending;
extern int rcl_pending_tick;
extern int rcl_pre[RCL_CAND];
extern int32_t rcl_prev_x;
extern int32_t rcl_prev_y;
extern int rcl_prev_valid;
extern int rcl_respawn_tick;

int rcl_team_at(const rcl_obj_t *objects, int index);
void rcl_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const rcl_obj_t *objects, int usable);
int rcl_own_ok(int32_t x, int32_t y);
int rcl_enemy_blocked(float x, float y, float ownX, float ownY);
int rcl_mate_blocked(float x, float y);
int rcl_own_side_spawn(int32_t sx, int32_t sy);







uintptr_t rcl_bs(void);
int rcl_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by, uint32_t *mode, float *cs, float *sn);
int rcl_joy_angle(float *outAngle);
void rcl_select(float px, float py);
int rcl_drive(void);
void rcl_candidates(uintptr_t ownElem, int *out);
void rcl_clear_life(void);
void rcl_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
int rcl_life(uintptr_t ownElem, int32_t ownX, int32_t ownY);
void rcl_build(void);
float rcl_seg_dist2(float px, float py, const rcl_seg_t *s);
int rcl_threatened(float x, float y);
float rcl_clearance_a(float x, float y);
float rcl_eta_ms(float x, float y);
int rcl_imminent(float x, float y);
int rcl_flee(float px, float py, float *tx, float *ty);
void rcl_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape);
int rcl_body_blocked_2(float px, float py, float dirX, float dirY, float len);
float rcl_body_score(float px, float py, float dirX, float dirY, float len);
float rcl_speed(void);
float rcl_clearance_b(float px, float py, float dirX, float dirY);
float rcl_score(float px, float py, float dirX, float dirY, float len);
float rcl_body_score_2(float px, float py, float dirX, float dirY, float len);
void rcl_unblock(float px, float py, float len, float *dirX, float *dirY);
int rcl_valid_point(float x, float y);
int rcl_walk_into_bullet(float px, float py, float dirX, float dirY, float travel);
float rcl_safe_angle(float px, float py, float desiredDeg, int *ok);
int rcl_passed(float px, float py);
int rcl_freest(float px, float py, float *tx, float *ty);
int rcl_decide(int32_t ownX, int32_t ownY);
void rcl_autododge(void);
void rcl_dodge_plan(uintptr_t manager, int32_t team);
void rcl_dodge_all_teams(uintptr_t manager);

extern float rcl_own_r;




extern int rcl_pick_key_c;

extern int rcl_pick_key_t;


extern int rcl_side_last;





float rcl_clear_at(float px, float py, int i);




int rcl_ok(float v, float lo, float hi);

extern float rcl_last_dist;
extern float rcl_rad_est;
extern float rcl_track_min[RCL_SEG_MAX];
extern float rcl_track_ux[RCL_SEG_MAX];
extern float rcl_track_uy[RCL_SEG_MAX];
extern int rcl_cal_off_seen;
extern int rcl_clip_win;
extern int rcl_crit_reaction;
extern int rcl_rad_off;
extern int rcl_shot_key[RCL_SEG_MAX];
extern int rcl_track_gid[RCL_SEG_MAX];
extern int rcl_track_hit[RCL_SEG_MAX];
extern int rcl_track_pside[RCL_SEG_MAX];
extern uint64_t rcl_howto_logs;
extern uint64_t rcl_react_max;
extern uint64_t rcl_react_min;
float rcl_all_clear(float x, float y);
int rcl_wall_blocked(float x0, float y0, float x1, float y1);

extern int rcl_cal_n;
extern float rcl_cal_rad_seen;
extern uint64_t rcl_crit_last;
extern int rcl_dodge_probe_usable;
extern float rcl_mom_live;
extern uint64_t rcl_no_threat_since;
extern uint64_t rcl_own_obj_last;
extern float rcl_own_vx;
extern float rcl_own_vy;
extern uint64_t rcl_prev_own_tick;
extern float rcl_prev_own_x;
extern float rcl_prev_own_y;
extern int rcl_released;
extern float rcl_shot_speed[RCL_PROJ_MAX];
int rcl_body_blocked(float x, float y, float ownX, float ownY);
float rcl_own_radius(void);
float rcl_proj_radius(const rcl_proj_t *p, float speed);
float rcl_seg_dist(float ax, float ay, float bx, float by, float px, float py);
void rcl_threats(void);

#endif
