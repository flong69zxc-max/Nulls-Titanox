#ifndef RECOIL_CORE_STARTS_H
#define RECOIL_CORE_STARTS_H

#include "types.h"

extern uintptr_t * rcl_starts;
extern size_t rcl_starts_count;
uintptr_t rcl_entry(uintptr_t rva);
int rcl_is_prologue(uint32_t w);
int rcl_is_term(uint32_t w);
void rcl_load_function_starts(void);
BOOL rcl_looks_like_start(uintptr_t address);
const char *rcl_prologue_rule(uintptr_t address);
BOOL rcl_start_boundary(const uint8_t *bytes, size_t offset);
size_t rcl_start_index(uintptr_t address, BOOL *exact);
BOOL rcl_start_word(uint32_t word);
int rcl_word(uintptr_t address, uint32_t *out);

#endif
