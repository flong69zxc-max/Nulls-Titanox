#ifndef RECOIL_UTILS_STRINGS_H
#define RECOIL_UTILS_STRINGS_H

#include "../core/types.h"

extern uint64_t rcl_ticks_b;

int rcl_ascii_word(uintptr_t address);
int rcl_word_ascii(uint64_t value);
int rcl_element_ascii(uintptr_t element);
int rcl_object_live(uintptr_t object);

#endif
