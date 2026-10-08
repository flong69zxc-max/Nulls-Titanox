#ifndef RECOIL_HELPERS_DODGE_KINDS_H
#define RECOIL_HELPERS_DODGE_KINDS_H

#include "../core/offsets.h"

#define RCL_FIT_COUNT 9
#define RCL_KIND_COUNT 117

#define RCL_FIT_ORBIT 0
#define RCL_FIT_LONG 1
#define RCL_FIT_THICK 2
#define RCL_FIT_BROAD 3
#define RCL_FIT_HALF 4
#define RCL_FIT_PLAIN 5
#define RCL_FIT_RAY 6
#define RCL_FIT_THIN 7
#define RCL_FIT_FALLBACK 8
#define RCL_FIT_NONE -1

#define RCL_K_BLOB 0x01
#define RCL_K_LOCKPATH 0x02
#define RCL_K_DROP 0x04
#define RCL_K_FADE 0x08
#define RCL_K_HOME 0x10
#define RCL_K_STRIP 0x20
#define RCL_K_BLAST 0x40

typedef struct
{
    float grow;
    float pad;
} rcl_fit_t;

typedef struct
{
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
} rcl_kind_t;

float rcl_proj_radius(const rcl_proj_t *p, float speed);
int rcl_kind_index(const char *name);
const rcl_kind_t *rcl_kind_of(const char *name);
const rcl_fit_t *rcl_fit_of(const char *name);

#endif
