#ifndef RECOIL_FEATURES_AUTODODGE_AUTODODGE_H
#define RECOIL_FEATURES_AUTODODGE_AUTODODGE_H

#include "../core/offsets.h"

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
extern int rcl_active;

extern int rcl_moving;
extern float rcl_last_x_b;
extern float rcl_last_y_b;
extern int rcl_last_ok;
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

int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut);
void rcl_candidates(uintptr_t ownElem, int *out);
void rcl_clear_life(void);
void rcl_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
int rcl_life(uintptr_t ownElem, int32_t ownX, int32_t ownY);
void rcl_autododge(void);

extern float rcl_own_r;

int rcl_ok(float v, float lo, float hi);

extern float rcl_rad_est;
extern int rcl_cal_off_seen;
extern int rcl_rad_off;

extern int rcl_cal_n;
extern float rcl_cal_rad_seen;
extern int rcl_dodge_probe_usable;
float rcl_own_radius(void);

extern uint64_t rcl_bucket_abs[RCL_ADV_BUCKETS];
extern uint64_t rcl_learn_loss[3][3][2];
extern uint64_t rcl_learn_win[3][3][2];

extern uint64_t rcl_learn_loss[3][3][2];
extern uint64_t rcl_learn_win[3][3][2];

#endif
