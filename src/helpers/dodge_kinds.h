#ifndef RECOIL_HELPERS_DODGE_KINDS_H
#define RECOIL_HELPERS_DODGE_KINDS_H

#include "../core/offsets.h"
#include "../core/rcl_types.h"

#define RCL_FIT_COUNT 9
#define RCL_KIND_COUNT 117

#define RCL_FIT_FALLBACK 8

#define RCL_K_BLOB 0x01
#define RCL_K_LOCKPATH 0x02
#define RCL_K_DROP 0x04
#define RCL_K_FADE 0x08
#define RCL_K_HOME 0x10

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
