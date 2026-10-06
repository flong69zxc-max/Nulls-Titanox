#ifndef TITANOX_INPUT_DRIVE_H
#define TITANOX_INPUT_DRIVE_H

#include "core/types.h"

extern int t_engaged_ticks;
extern tnx_seg_t t_seg[TNX_SEG_MAX];
extern int t_seg_count;
extern int32_t t_stick_x;
extern int32_t t_stick_y;
extern uint64_t t_ticks_3;
extern float t_walk_step;
uintptr_t tnx_bs(void);
void tnx_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY);
int tnx_drive(void);
int tnx_joy_angle(float *outAngle);
int tnx_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by, uint32_t *mode, float *cs, float *sn);
void tnx_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape);
void tnx_route(int engaged);
void tnx_select(float px, float py);
float tnx_speed(void);
void tnx_stick(int engaged, float dirX, float dirY);

extern long long t_sum_x;
extern long long t_sum_y;

#endif
