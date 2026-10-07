#ifndef RECOIL_INPUT_MOVE_H
#define RECOIL_INPUT_MOVE_H

#include "core/config.h"

extern int rcl_dead_probe_done;
extern uint64_t rcl_ctrl_dead;
extern int rcl_body_mine;
extern int rcl_body_enemy;
extern int rcl_wrote_input;
extern int rcl_engaged_frame;
extern int rcl_seq_before;
extern int rcl_seq_after;
extern int rcl_q_after;
extern uintptr_t rcl_pred_last;
extern uintptr_t rcl_joystick;
extern int32_t rcl_stick_x;
extern int32_t rcl_stick_y;
extern int rcl_stick_hold;
extern uint64_t rcl_stick_tick;
extern int rcl_engaged_ticks;
extern long long rcl_sum_x;
extern long long rcl_sum_y;
extern int rcl_route_seeded;
extern int32_t rcl_last_own_x;
extern int32_t rcl_last_own_y;
extern int rcl_accepted;

int rcl_mode(void);
float rcl_look_ms(void);
int rcl_ctrl_ok(uintptr_t ctrl);
void *rcl_msg_alloc(void);
uintptr_t rcl_entry_2(uintptr_t rva);
void *rcl_manager(void);
int rcl_queue_count(uintptr_t *mgrOut);
int rcl_predict(int32_t x, int32_t y);
int rcl_enqueue(int x, int y);

int rcl_enqueue_type(int x, int y, int type);
int rcl_move_to(int32_t x, int32_t y, float ox, float oy);
uintptr_t rcl_move_carrier(void);
void rcl_move_locate(float ox, float oy);
int rcl_move_pair_ok(uintptr_t obj, int32_t *outX, int32_t *outY);
int rcl_move_near_own(uintptr_t obj, float ox, float oy, int32_t *outX, int32_t *outY);
extern int rcl_move_probe_count;
extern int rcl_move_ok;
int rcl_witness(int32_t *x, int32_t *y);
int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
float rcl_seg_dist(float ax, float ay, float bx, float by, float px, float py);
int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut);
uintptr_t rcl_input_mgr(void);
void rcl_input_release(void);
void rcl_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY);
void rcl_stick(int engaged, float dirX, float dirY);
void rcl_route(int engaged);
void rcl_threats(void);
int rcl_body_blocked(float x, float y, float ownX, float ownY);
uintptr_t rcl_client(void);


#endif
