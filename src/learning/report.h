#ifndef TITANOX_LEARNING_REPORT_H
#define TITANOX_LEARNING_REPORT_H

#include "core/types.h"

extern uint64_t t_applied_writes;
extern uint64_t t_applied_live;
extern uint64_t t_applied_stale;
extern int32_t t_hp;
extern int32_t t_hpmax;
extern uint64_t t_hits;
extern uint64_t t_hit_engaged;
extern uint64_t t_hit_idle;
extern uint64_t t_hp_lost;
extern uint64_t t_episodes;
extern uint64_t t_clean;
extern uint64_t t_eaten;
extern uint64_t t_engaged_frames;
extern uint64_t t_threat_frames;
extern int t_ep_open;
extern int t_ep_dirty;
extern int t_logs_12;
extern int t_clean_seen;

void tnx_log(const char *event);
void tnx_stats(void);

#endif
