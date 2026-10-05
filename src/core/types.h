#ifndef TITANOX_TYPES_H
#define TITANOX_TYPES_H

#include "config.h"

typedef void (*fn_void_2_t)(void *, void *);

typedef void *(*fn_ptr_2_t)(void *, void *);

typedef void (*fn_settext_t)(void *, void *, int, int);

typedef void (*fn_setxy_t)(void *, float, float);

typedef void (*fn_send_movement_t)(void *, float, float);

typedef void (*fn_set_prediction_t)(void *, int, int);

typedef void *(*fn_get_inst_t)(void);

typedef void *(*fn_get_own_char_t)(void *);

typedef int (*fn_get_team_t)(void *);

typedef int (*fn_get_coord_t)(void *);

typedef struct {
    const char *name;

typedef struct {
    __unsafe_unretained Class cls;

typedef struct {
    uintptr_t at;

typedef struct {
    uintptr_t rva;

typedef uint64_t (*tnx_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                  uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

typedef struct {
    uintptr_t base;

typedef struct {
    int sampled;

typedef struct {
    int elements;

typedef struct {
    uintptr_t low;

typedef struct {
    uintptr_t manager;

typedef struct {
    uintptr_t address;

typedef struct {
    const char *label;

typedef void (*tnx_v47_setpred_t)(void *self, int x, int y);

typedef struct {
    uintptr_t object;

typedef struct {
    int elementsRead;

typedef struct {
    uintptr_t elem;

typedef struct {
    float ax;

typedef struct {
    uintptr_t base;

#endif
