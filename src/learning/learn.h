#ifndef RECOIL_LEARNING_LEARN_H
#define RECOIL_LEARNING_LEARN_H

#include "core/types.h"

extern uint64_t rcl_bucket_abs[RCL_ADV_BUCKETS];
extern uint64_t rcl_learn_loss[3][3][2];
extern uint64_t rcl_learn_win[3][3][2];
extern int rcl_stat_near;
int rcl_blacklisted(float speed, float radius);
void rcl_stat_tick(float px, float py);

extern uint64_t rcl_learn_loss[3][3][2];
extern uint64_t rcl_learn_win[3][3][2];

#endif
