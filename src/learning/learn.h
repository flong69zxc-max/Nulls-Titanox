#ifndef TITANOX_LEARNING_LEARN_H
#define TITANOX_LEARNING_LEARN_H

#include "core/types.h"

extern uint64_t g_bucket_abs[TNX_ADV_BUCKETS];
extern uint64_t g_bucket_n[TNX_ADV_BUCKETS];
extern uint64_t g_learn_loss[3][3][2];
extern uint64_t g_learn_win[3][3][2];
extern uint64_t g_stat_absorbed;
extern uint64_t g_stat_dodged;
extern int g_stat_near;
int tnx_blacklisted(float speed, float radius);
int tnx_key_c(int n);
int tnx_key_t(float tti);
float tnx_learn_rate(int c, int t, int side);
void tnx_stat_report(void);
void tnx_stat_tick(float px, float py);

#endif
