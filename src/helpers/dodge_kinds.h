#ifndef RECOIL_HELPERS_DODGE_KINDS_H
#define RECOIL_HELPERS_DODGE_KINDS_H

#include "../core/types.h"

int rcl_dodge_is_proj(uintptr_t obj);
float rcl_proj_radius(const rcl_proj_t *p, float speed);

#endif
