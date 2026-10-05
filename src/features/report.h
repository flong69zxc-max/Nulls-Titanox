#ifndef TITANOX_FEATURES_REPORT_H
#define TITANOX_FEATURES_REPORT_H

#include "core/types.h"

extern uint64_t g_v211_applied_writes;
extern uint64_t g_v211_applied_live;
extern uint64_t g_v211_applied_stale;
extern int32_t g_v246_hp;
extern int32_t g_v246_hpmax;
extern uint64_t g_v246_hits;
extern uint64_t g_v246_hit_engaged;
extern uint64_t g_v246_hit_idle;
extern uint64_t g_v246_hp_lost;
extern uint64_t g_v246_episodes;
extern uint64_t g_v246_clean;
extern uint64_t g_v246_eaten;
extern uint64_t g_v246_engaged_frames;
extern uint64_t g_v246_threat_frames;
extern int g_v246_ep_open;
extern int g_v246_ep_dirty;
extern int g_v246_logs;
extern int g_v246_clean_seen;

void tnx_v246_log(const char *event);
void tnx_v246_stats(void);

#endif
