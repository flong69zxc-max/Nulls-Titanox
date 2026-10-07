#ifndef TITANOX_INPUT_MOVE_H
#define TITANOX_INPUT_MOVE_H

#include "core/types.h"

extern int t_dead_probe_done;
extern uint64_t t_ctrl_dead;
extern int t_body_mine;
extern int t_body_enemy;
extern int t_wrote_input;
extern int t_engaged_frame;
extern int t_seq_before;
extern int t_seq_after;
extern int t_q_after;
extern uintptr_t t_pred_last;
extern uintptr_t t_joystick;
extern int32_t t_stick_x;
extern int32_t t_stick_y;
extern int t_stick_hold;
extern uint64_t t_stick_tick;
extern int t_engaged_ticks;
extern long long t_sum_x;
extern long long t_sum_y;
extern int t_route_seeded;
extern int32_t t_last_own_x;
extern int32_t t_last_own_y;
extern int t_accepted;

int tnx_mode(void);
float tnx_look_ms(void);
int tnx_ctrl_ok(uintptr_t ctrl);
void *tnx_msg_alloc(void);
uintptr_t tnx_entry_2(uintptr_t rva);
void *tnx_manager(void);
int tnx_queue_count(uintptr_t *mgrOut);
int tnx_predict(int32_t x, int32_t y);
int tnx_enqueue(int x, int y);

int tnx_enqueue_type(int x, int y, int type);
int tnx_move_to(int32_t x, int32_t y, float ox, float oy);
uintptr_t tnx_move_carrier(void);
void tnx_move_locate(float ox, float oy);
int tnx_move_pair_ok(uintptr_t obj, int32_t *outX, int32_t *outY);
int tnx_move_near_own(uintptr_t obj, float ox, float oy, int32_t *outX, int32_t *outY);
extern int t_move_probe;
extern int t_move_ok;
int tnx_witness(int32_t *x, int32_t *y);
int tnx_resolve_own(const tnx_obj_t *objects, int usable, int *indexOut, const char **fromOut);
float tnx_seg_dist(float ax, float ay, float bx, float by, float px, float py);
int tnx_proj_vel(const tnx_proj_t *p, float *vxOut, float *vyOut);
uintptr_t tnx_input_mgr(void);
void tnx_input_release(void);
void tnx_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY);
void tnx_stick(int engaged, float dirX, float dirY);
void tnx_route(int engaged);
void tnx_threats(void);
int tnx_body_blocked(float x, float y, float ownX, float ownY);
uintptr_t tnx_client(void);


#endif
