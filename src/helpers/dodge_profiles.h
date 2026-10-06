#ifndef TITANOX_HELPERS_DODGE_PROFILES_H
#define TITANOX_HELPERS_DODGE_PROFILES_H

#include "core/types.h"

#define TNX_SHAPE_NONE (-1)
#define TNX_SHAPE_MAX 64

#define TNX_SHAPE_VARIANT_NONE 0
#define TNX_SHAPE_VARIANT_STRAIGHT 1
#define TNX_SHAPE_VARIANT_CURVE 2

#define TNX_SHAPE_CROSS 2
#define TNX_SHAPE_SPOKES 6
#define TNX_SHAPE_ARC_N 7
#define TNX_SHAPE_STRAIGHT_ARMS 3

#define TNX_SHAPE_LOGIC_TICK_MS 50
#define TNX_SHAPE_TRACE_STEP 40.0f
#define TNX_SHAPE_TRACE_BACKOFF 75.0f
#define TNX_SHAPE_SPIKE_RADIUS 50.0f
#define TNX_SHAPE_SPIKE_SPAWN_OFFSET 200.0f
#define TNX_SHAPE_SPIKE_CHILD_TRAVEL 1100.0f
#define TNX_SHAPE_SPIKE_FLIGHT_DIST 2035.0f
#define TNX_SHAPE_SPIKE_FLIGHT_MS 963.0f
#define TNX_SHAPE_SPIKE_BURST_MS 360.0f
#define TNX_SHAPE_SPIKE_BLAST_MS 700.0f
#define TNX_SHAPE_SPIKE_CURVE_DEG 22.0f
#define TNX_SHAPE_SPIKE_ARM (TNX_SHAPE_SPIKE_SPAWN_OFFSET + TNX_SHAPE_SPIKE_CHILD_TRAVEL)
#define TNX_SHAPE_MAX_COORD 1000000.0f
#define TNX_SHAPE_PI 3.14159265358979323846f
#define TNX_SHAPE_RAD (TNX_SHAPE_PI / 180.0f)

typedef struct {
    int isSeg;
    float ax;
    float ay;
    float bx;
    float by;
    float radius;
    uint64_t t0;
    uint64_t t1;
} tnx_shape_t;

typedef struct {
    const char *name;
    int32_t x;
    int32_t y;
    int32_t spawnX;
    int32_t spawnY;
    int32_t targetX;
    int32_t targetY;
    float angle;
    uint64_t spawnedAt;
    float spawnAreaRadius;
    float spawnAreaActiveTime;
} tnx_shape_in_t;

int tnx_shape_hazards(const tnx_shape_in_t *in, uint64_t nowMs, tnx_shape_t *out, int maxOut);
int tnx_shape_blocks_linear(const char *name);
void tnx_shape_note_death(const char *name, int32_t x, int32_t y, int32_t spawnX, int32_t spawnY,
                          float angleDeg);
void tnx_shape_reset(void);
int tnx_shape_variant(void);
float tnx_shape_trace(float wx, float wy, float dirX, float dirY, float maxDist);

#endif
