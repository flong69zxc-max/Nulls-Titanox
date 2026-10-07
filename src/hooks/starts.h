#ifndef TITANOX_HOOKS_STARTS_H
#define TITANOX_HOOKS_STARTS_H

#include "core/types.h"

extern uintptr_t * t_starts;
extern size_t t_starts_count;
uintptr_t tnx_entry(uintptr_t rva);
int tnx_is_prologue(uint32_t w);
int tnx_is_term(uint32_t w);
void tnx_load_function_starts(void);
BOOL tnx_looks_like_start(uintptr_t address);
const char *tnx_prologue_rule(uintptr_t address);
const char *tnx_skip_compound(const char *p);
BOOL tnx_start_boundary(const uint8_t *bytes, size_t offset);
size_t tnx_start_index(uintptr_t address, BOOL *exact);
BOOL tnx_start_word(uint32_t word);
int tnx_word(uintptr_t address, uint32_t *out);

#endif
