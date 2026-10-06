#ifndef TITANOX_HELPERS_DODGE_KINDS_H
#define TITANOX_HELPERS_DODGE_KINDS_H

#include "core/types.h"

#define TNX_KIND_COUNT 117
#define TNX_FIT_COUNT 9

#define TNX_FIT_ORBIT 0
#define TNX_FIT_LONG 1
#define TNX_FIT_THICK 2
#define TNX_FIT_BROAD 3
#define TNX_FIT_HALF 4
#define TNX_FIT_PLAIN 5
#define TNX_FIT_RAY 6
#define TNX_FIT_THIN 7
#define TNX_FIT_FALLBACK 8

#define TNX_K_BLOB 0x01
#define TNX_K_LOCKPATH 0x02
#define TNX_K_DROP 0x04
#define TNX_K_FADE 0x08
#define TNX_K_HOME 0x10
#define TNX_K_STRIP 0x20
#define TNX_K_BLAST 0x40

typedef struct {
    float grow;
    float pad;
} tnx_fit_t;

typedef struct {
    const char *name;
    int8_t fit;
    uint8_t flags;
    int16_t reachAdj;
    int32_t maxRange;
    int32_t chargedRange;
    int32_t growR;
    float speedMul;
    float fadeBase;
    float fadeK;
} tnx_kind_t;

int tnx_kind_index(const char *name);
const tnx_kind_t *tnx_kind(const char *name);
const tnx_fit_t *tnx_kind_fit(const char *name);

#endif
