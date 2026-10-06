#ifndef TITANOX_CORE_CRASH_H
#define TITANOX_CORE_CRASH_H

#include "core/types.h"

extern char t_phase[48];
extern char t_hist[8][48];
extern volatile int t_hist_n;
extern volatile int t_fd;
extern volatile uint64_t t_stage_ticks;
extern int t_installed;

void tnx_phase(const char *p);
void tnx_crash(int sig, siginfo_t *info, void *ctx);
void tnx_install(void);
__attribute__((constructor)) static void start(void);

#endif
