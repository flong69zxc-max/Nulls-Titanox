#ifndef RECOIL_FEATURES_AUTOAIM_AUTOAIM_H
#define RECOIL_FEATURES_AUTOAIM_AUTOAIM_H

#include "../core/offsets.h"

typedef void *(*fn_get_inst_t)(void);

typedef void *(*fn_get_own_char_t)(void *);

typedef int (*fn_get_team_t)(void *);

typedef int (*fn_get_coord_t)(void *);

void rcl_run_autoaim(void);

#endif
