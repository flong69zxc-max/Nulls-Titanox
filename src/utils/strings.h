#ifndef TITANOX_UTILS_STRINGS_H
#define TITANOX_UTILS_STRINGS_H

#include "core/types.h"

extern uint64_t t_ticks_b;
extern tnx_reject_t t_reject;

int tnx_ascii_word(uintptr_t address);
int tnx_word_ascii(uint64_t value);
int tnx_element_ascii(uintptr_t element);
int tnx_object_live(uintptr_t object);

#endif
