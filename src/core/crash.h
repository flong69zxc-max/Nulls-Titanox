#ifndef TITANOX_CORE_CRASH_H
#define TITANOX_CORE_CRASH_H

#include "core/types.h"

extern char g_phase[48];
extern char g_hist[8][48];
extern volatile int g_hist_n;
extern volatile int g_fd;
extern volatile uint64_t g_stage_ticks;
extern int g_installed;

void tnx_phase(const char *p);
void tnx_crash(int sig, siginfo_t *info, void *ctx);
void tnx_install(void);
__attribute__((constructor)) static void start(void);

#endif
