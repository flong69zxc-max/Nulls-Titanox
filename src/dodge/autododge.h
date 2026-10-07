#ifndef TITANOX_DODGE_AUTODODGE_H
#define TITANOX_DODGE_AUTODODGE_H

#include "core/types.h"

extern uint64_t t_drop_slow;
extern uint64_t t_drop_fast;
extern uint64_t t_drop_blink;
extern float t_spd_min;
extern float t_spd_max;
extern __thread int t_in_drive;
extern int t_state;
extern int t_pl_n;
extern int32_t t_pl_x[TNX_PLAYER_MAX];
extern int32_t t_pl_y[TNX_PLAYER_MAX];
extern int32_t t_pl_team[TNX_PLAYER_MAX];
extern int32_t t_pl_mine[TNX_PLAYER_MAX];
extern int t_mate_n;
extern int32_t t_mate_x[TNX_MATE_MAX];
extern int32_t t_mate_y[TNX_MATE_MAX];
extern int t_own_team_b;
extern int t_team_trust;
extern int32_t t_enemy_x[TNX_PLAYER_MAX];
extern int32_t t_enemy_y[TNX_PLAYER_MAX];
extern int t_enemy_n;
extern int t_new_tick;
extern int t_prev_seg;
extern int t_mates;
extern int t_enemies;
extern int t_agree;
extern uint64_t t_human;
extern int32_t t_tx;
extern int32_t t_ty;
extern int t_active;

extern int t_js_live;

extern uint64_t t_js_tick;

int tnx_js_owns(void);
extern tnx_seg_t t_seg[TNX_SEG_MAX];
extern int t_seg_count;
extern int t_build_tick;
extern int t_have_angle;
extern float t_angle;
extern float t_tx_a;
extern float t_ty_a;
extern int t_moving;
extern float t_start_x;
extern float t_start_y;
extern int t_drive_logs;
extern float t_last_x_b;
extern float t_last_y_b;
extern int t_last_ok;
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
void tnx_clear_life(void);
void tnx_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
int tnx_life(uintptr_t ownElem, int32_t ownX, int32_t ownY);
void tnx_build(void);
float tnx_seg_dist2(float px, float py, const tnx_seg_t *s);
int tnx_threatened(float x, float y);
float tnx_clearance_a(float x, float y);
float tnx_eta_ms(float x, float y);
int tnx_imminent(float x, float y);
int tnx_flee(float px, float py, float *tx, float *ty);
void tnx_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape);
int tnx_body_blocked_2(float px, float py, float dirX, float dirY, float len);
float tnx_body_score(float px, float py, float dirX, float dirY, float len);
float tnx_speed(void);
float tnx_clearance_b(float px, float py, float dirX, float dirY);
float tnx_score(float px, float py, float dirX, float dirY, float len);
float tnx_body_score_2(float px, float py, float dirX, float dirY, float len);
void tnx_unblock(float px, float py, float len, float *dirX, float *dirY);
int tnx_valid_point(float x, float y);
int tnx_walk_into_bullet(float px, float py, float dirX, float dirY, float travel);
float tnx_safe_angle(float px, float py, float desiredDeg, int *ok);
int tnx_passed(float px, float py);
int tnx_freest(float px, float py, float *tx, float *ty);
int tnx_decide(int32_t ownX, int32_t ownY);
void tnx_autododge(void);
void tnx_dodge_plan(uintptr_t manager, int32_t team);
void tnx_dodge_all_teams(uintptr_t manager);

extern float t_own_r;




extern int t_pick_key_c;

extern int t_pick_key_t;


extern int t_side_last;





float tnx_clear_at(float px, float py, int i);




int tnx_ok(float v, float lo, float hi);

extern float t_last_dist;
extern float t_rad_est;
extern float t_track_min[TNX_SEG_MAX];
extern float t_track_ux[TNX_SEG_MAX];
extern float t_track_uy[TNX_SEG_MAX];
extern int t_cal_off_seen;
extern int t_clip_win;
extern int t_crit_reaction;
extern int t_rad_off;
extern int t_shot_key[TNX_SEG_MAX];
extern int t_track_gid[TNX_SEG_MAX];
extern int t_track_hit[TNX_SEG_MAX];
extern int t_track_pside[TNX_SEG_MAX];
extern uint64_t t_howto_logs;
extern uint64_t t_react_max;
extern uint64_t t_react_min;
float tnx_all_clear(float x, float y);
int tnx_wall_blocked(float x0, float y0, float x1, float y1);

extern int t_cal_n;
extern float t_cal_rad_seen;
extern uint64_t t_crit_last;
extern int t_dodge_probe_usable;
extern float t_mom_live;
extern uint64_t t_no_threat_since;
extern uint64_t t_own_obj_last;
extern float t_own_vx;
extern float t_own_vy;
extern uint64_t t_prev_own_tick;
extern float t_prev_own_x;
extern float t_prev_own_y;
extern int t_released;
extern float t_shot_speed[TNX_PROJ_MAX];
int tnx_body_blocked(float x, float y, float ownX, float ownY);
float tnx_own_radius(void);
float tnx_proj_radius(const tnx_proj_t *p, float speed);
float tnx_seg_dist(float ax, float ay, float bx, float by, float px, float py);
void tnx_threats(void);

#endif
