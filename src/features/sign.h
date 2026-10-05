#ifndef TITANOX_FEATURES_SIGN_H
#define TITANOX_FEATURES_SIGN_H

#include "core/types.h"
#include "core/offsets.h"

extern int g_ci_sign_on;
extern uint32_t g_ci_tokens;
extern uint32_t g_ci_sign_fails;

int tnx_ci_load_constants(void);
void *tnx_ci_new(int cmdType);
uint32_t tnx_ci_sign(void *ci, void *battle);
int tnx_ci_push(void *ci);
int tnx_ci_send(int cmdType);

#endif
