#ifndef RECOIL_CORE_COMMANDS_H
#define RECOIL_CORE_COMMANDS_H

#include "./types.h"
#include "./offsets.h"

int rcl_ci_load_constants(void);
uint32_t rcl_ci_sign(void *ci, void *battle);
int rcl_enqueue(int x, int y);
int rcl_enqueue_type(int x, int y, int type);

#endif
