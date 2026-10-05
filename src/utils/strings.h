#ifndef TITANOX_UTILS_STRINGS_H
#define TITANOX_UTILS_STRINGS_H

#include "core/types.h"

extern uint64_t g_v52_setpred_calls;
extern uintptr_t g_v52_setpred_this;
extern float g_v52_setpred_x;
extern float g_v52_setpred_y;
extern uint64_t g_v52_ascii_rejected;
extern uint32_t g_v50_never_dispatched_mask;
extern uint64_t g_v50_ticks;
extern int g_v75_ascii_refused;
extern int g_v75_best_wait_logs;
extern int g_v50_alert_streak;
extern uintptr_t g_v50_alert_streak_ptr;
extern uint64_t g_v50_alert_calls;
extern int g_v50_alert_withheld_logs;
extern tnx_v50_reject_t g_v50_reject;
extern int g_v50_setpred_blocked_logs;

int tnx_v52_ascii_word(uintptr_t address);
int tnx_v75_word_ascii(uint64_t value);
int tnx_v75_element_ascii(uintptr_t element);
int tnx_v75_object_live(uintptr_t object);
void tnx_v75_measure(uintptr_t manager, int32_t count, tnx_v75_measure_t *out);
void tnx_v75_append(char *buf, size_t size, size_t *used, const char *token);
int tnx_v75_trail_verdict(const tnx_trail_t *entry, char *buf, size_t size);
const char *tnx_v50_reject_text(char *buf, size_t size);

#endif
