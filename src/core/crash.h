#ifndef TITANOX_CORE_CRASH_H
#define TITANOX_CORE_CRASH_H

#include "core/types.h"

extern char g_v146_phase[48];
extern char g_v146_hist[8][48];
extern volatile int g_v146_hist_n;
extern volatile int g_v146_fd;
extern volatile uint64_t g_v146_stage_ticks;
extern int g_v146_installed;

void tnx_v146_phase(const char *p);
void tnx_v146_crash(int sig, siginfo_t *info, void *ctx);
void tnx_v146_install(void);
__attribute__((constructor)) static void start(void);

#endif
