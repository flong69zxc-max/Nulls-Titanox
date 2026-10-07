#ifndef TITANOX_LEARNING_LEARN_H
#define TITANOX_LEARNING_LEARN_H

#include "core/types.h"

extern uint64_t t_bucket_abs[TNX_ADV_BUCKETS];
extern uint64_t t_learn_loss[3][3][2];
extern uint64_t t_learn_win[3][3][2];
extern int t_stat_near;
int tnx_blacklisted(float speed, float radius);
void tnx_stat_tick(float px, float py);

extern uint64_t t_learn_loss[3][3][2];
extern uint64_t t_learn_win[3][3][2];

#endif
