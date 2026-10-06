#ifndef TITANOX_LEARNING_SD_H
#define TITANOX_LEARNING_SD_H

#include "core/types.h"
#include "core/offsets.h"

extern uint64_t g_sd_logs;
extern uint64_t g_sd_no_mgr;
extern uint64_t g_sd_no_enable;
extern uint64_t g_sd_no_cooldown;
extern uint64_t g_sd_ack_eq_seq;

void tnx_sd_log(void);

#endif
