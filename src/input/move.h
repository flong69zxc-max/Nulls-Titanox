#ifndef RECOIL_INPUT_MOVE_H
#define RECOIL_INPUT_MOVE_H

#include "../core/types.h"

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
int rcl_pred_set(int x, int y);

int rcl_move_to(int32_t x, int32_t y, float ox, float oy);
uintptr_t rcl_move_carrier(void);
void rcl_move_locate(float ox, float oy);
int rcl_move_pair_ok(uintptr_t obj, int32_t *outX, int32_t *outY);
int rcl_move_near_own(uintptr_t obj, float ox, float oy, int32_t *outX, int32_t *outY);
extern int rcl_move_probe_count;
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


#define RCL_PREDICT 0
#define RCL_TOUCH_FLAG 1
#define RCL_STICK_WHEN_FREE 1
#define RCL_PREDICT_FLAG 1
#define RCL_STICK_SIGN 1
#define RCL_PRECISION 1
#define RCL_EVERY 60
#define RCL_PAIR_RAW 1
#define RCL_PAIR_MAX 2400.0f
#define RCL_RAGE 1
#define RCL_QUEUE 1
#define RCL_STEP_c 150.0f
#define RCL_DEGEN 2000000
#define RCL_SLOW_US 200
#define RCL_GATE_WRITE 1
#define RCL_MSG_SIZE 0x48
#define RCL_QUEUE_GUARD_MGR 0
#define RCL_QGUARD_LOGS 3
#define RCL_TYPE_MOVE 0x2
#define RCL_APPLIED_IDLE (-300)
#define RCL_STALE_SIGHT 1
#define RCL_QUIET 0
#define RCL_HUMAN 1
#define RCL_V245_STICK 0
#define RCL_RETIRE 1
#define RCL_JOY_MAG 600.0f
#define RCL_INPUT_MGR 0
#define RCL_JOY_KNOB_ON 1
#define RCL_JOY_KNOB_MAG 30.0f
#define RCL_JOY_MIN_CENTER 50.0f
#define RCL_JOY_PAIR_Y 4
#define RCL_JOY_PAIR_CEN 8
#define RCL_JOY_PAIR_N 3
#define RCL_JOY_TARGETS 4
#define RCL_JOY_KNOB_LOGS 8
#define RCL_JOY_EPS 0.0001f
#define RCL_BS_AX 0x9b8
#define RCL_BS_AY 0x9bc
#define RCL_BS_BX 0x9c0
#define RCL_BS_BY 0x9c4
#define RCL_JOY_ALT_CUR_X 0x9d0
#define RCL_JOY_ALT_CUR_Y 0x9d4
#define RCL_JOY_ALT_CEN_X 0x9d8
#define RCL_JOY_ALT_CEN_Y 0x9dc
#define RCL_JOY_ALT_DRAG 0xee8
#define RCL_JOY_DEEP 0
#define RCL_BS_COS 0x8f4
#define RCL_BS_SIN 0x8f8
#define RCL_PRED_SET 1
#define RCL_PRED_FLAG 1
#define RCL_PAIR_ONLY 0
#define RCL_STICK_ONLY 0
#define RCL_DRIVE_LOGS 24
#define RCL_DT_MAX 12
#define RCL_STICK_TTL 3
#define RCL_HEAP_MIN 0x100000000ULL
#define RCL_HEAP_MAX 0x800000000000ULL
#define RCL_JOY_KNOB_WRITE 0
#define RCL_APPLY_WRITE 0
#define RCL_STICK_PUSH 1
#define RCL_STICK_RADIUS 60.0f
#define RCL_STICK_KNOB 0
#define RCL_STICK_INPUT 0
#define RCL_STICK_HOLD 0
#define RCL_STICK_HOLD_WRITE 0
#define RCL_WALK_PUSH 1
#define RCL_WALK_KNOB 0
#define RCL_WALK_HOLD 0
#define RCL_WALK_DEAD_GAIN 1.6f
#define RCL_WALK_HOLD_GATE 1
#define RCL_WALK_DEAD_PAD 4.0f
#define RCL_WALK_STALE 3
#define RCL_WALK_GATE_LOGS 300
#define RCL_ENT_WARMUP 90
#define RCL_WALK_LOOKUP 1
#define RCL_ENT_PROBE 1
#define RCL_ENT_PROBE_LOGS 900
#define RCL_ENT_SAMPLE 3
#define RCL_ENT_SUM_EVERY 360
#define RCL_ENT_SUM_MIN 4
#define RCL_ENT_SUM_LOGS 40
#define RCL_ENT_SLOTS 512
#define RCL_ENT_CHUNK 0x100
#define RCL_ENT_CHUNKS 8
#define RCL_WALK_HS 1
#define RCL_WALK_HS_TIMER 0.05f
#define RCL_JOY_COORD_LIMIT 20000.0f
#define RCL_MOVE_ON 1
#define RCL_JOY_SCAN_ON 1
#define RCL_MOVE_TOL 4000.0f
#define RCL_MOVE_MAX 12
#define RCL_MOVE_HOPS 2

#endif
