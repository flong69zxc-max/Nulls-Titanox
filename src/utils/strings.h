#ifndef TITANOX_UTILS_STRINGS_H
#define TITANOX_UTILS_STRINGS_H

#include "core/types.h"

extern uint64_t t_setpred_calls;
extern uintptr_t t_setpred_this;
extern float t_setpred_x;
extern float t_setpred_y;
extern uint64_t t_ascii_rejected;
extern uint32_t t_never_dispatched_mask;
extern uint64_t t_ticks_4;
extern int t_ascii_refused;
extern int t_alert_streak;
extern uintptr_t t_alert_streak_ptr;
extern uint64_t t_alert_calls;
extern tnx_reject_t t_reject;
extern int t_setpred_blocked_logs;

int tnx_ascii_word(uintptr_t address);
int tnx_word_ascii(uint64_t value);
int tnx_element_ascii(uintptr_t element);
int tnx_object_live(uintptr_t object);
void tnx_append(char *buf, size_t size, size_t *used, const char *token);
int tnx_trail_verdict(const tnx_trail_t *entry, char *buf, size_t size);
const char *tnx_reject_text(char *buf, size_t size);

#endif
