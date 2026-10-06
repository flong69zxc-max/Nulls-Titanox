#ifndef TITANOX_INPUT_SIGN_H
#define TITANOX_INPUT_SIGN_H

#include "core/types.h"
#include "core/offsets.h"

extern int t_ci_sign_on;
extern uint32_t t_ci_tokens;
extern uint32_t t_ci_sign_fails;

int tnx_ci_load_constants(void);
uint32_t tnx_ci_sign(void *ci, void *battle);

#endif
