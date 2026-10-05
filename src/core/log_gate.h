#ifndef TITANOX_CORE_LOG_GATE_H
#define TITANOX_CORE_LOG_GATE_H

#include "core/types.h"

#ifndef TNX_VERBOSE_DEFAULT
#define TNX_VERBOSE_DEFAULT 1
#endif

extern int g_tnx_verbose;

#define TNX_LOGX(...) do { if (g_tnx_verbose) tnx_logf(__VA_ARGS__); } while (0)

#endif
