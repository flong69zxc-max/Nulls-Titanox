#ifndef TITANOX_LEARNING_REPORT_H
#define TITANOX_LEARNING_REPORT_H

#include "core/types.h"

extern uint64_t g_applied_writes;
extern uint64_t g_applied_live;
extern uint64_t g_applied_stale;
extern int32_t g_hp;
extern int32_t g_hpmax;
extern uint64_t g_hits;
extern uint64_t g_hit_engaged;
extern uint64_t g_hit_idle;
extern uint64_t g_hp_lost;
extern uint64_t g_episodes;
extern uint64_t g_clean;
extern uint64_t g_eaten;
extern uint64_t g_engaged_frames;
extern uint64_t g_threat_frames;
extern int g_ep_open;
extern int g_ep_dirty;
extern int g_logs_12;
extern int g_clean_seen;

void tnx_log(const char *event);
void tnx_stats(void);

#endif
