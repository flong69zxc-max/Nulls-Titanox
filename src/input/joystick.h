#ifndef RECOIL_INPUT_DRIVE_H
#define RECOIL_INPUT_DRIVE_H

#include "core/config.h"

extern int rcl_engaged_ticks;
extern rcl_seg_t rcl_seg[RCL_SEG_MAX];
extern int rcl_seg_count;
extern int32_t rcl_stick_x;
extern int32_t rcl_stick_y;
extern uint64_t rcl_ticks_a;
extern float rcl_walk_step;
uintptr_t rcl_bs(void);
void rcl_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY);
int rcl_drive(void);
int rcl_joy_angle(float *outAngle);






void rcl_joy_knob(float dirX, float dirY, int on);



uintptr_t rcl_walk_mgr(void);

void rcl_walk_want(int on, int32_t px, int32_t py, int32_t tx, int32_t ty);

void rcl_walk_pump(void);

extern uintptr_t rcl_walk_ent;






int rcl_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by, uint32_t *mode, float *cs, float *sn);
void rcl_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape);
void rcl_select(float px, float py);
float rcl_speed(void);

extern long long rcl_sum_x;
extern long long rcl_sum_y;

#endif
