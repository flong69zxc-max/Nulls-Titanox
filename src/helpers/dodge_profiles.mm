#include "titanox.h"

static const float g_shape_arc[TNX_SHAPE_ARC_N][3] = {
    { 0.0f, 200.0f, 0.0f },
    { 110.0f, 515.0f, 32.0f },
    { 207.0f, 797.0f, 216.0f },
    { 312.0f, 999.0f, 519.0f },
    { 411.0f, 1066.0f, 930.0f },
    { 513.0f, 995.0f, 1377.0f },
    { 557.0f, 883.0f, 1611.0f },
};

static const float g_shape_cross[TNX_SHAPE_CROSS][5] = {
    { 125.0f, 3000.0f, 200.0f, 800.0f, 1015.0f },
    { 375.0f, 3000.0f, 100.0f, 1600.0f, 1115.0f },
};

static int g_shape_variant = TNX_SHAPE_VARIANT_NONE;

int tnx_shape_variant(void) {
    return g_shape_variant;
}

void tnx_shape_reset(void) {
    g_shape_variant = TNX_SHAPE_VARIANT_NONE;
}

float tnx_shape_trace(float wx, float wy, float dirX, float dirY, float maxDist) {
    float dist = 0.0f;

    if (maxDist <= 0.0f) return maxDist;
    if (g_w <= 0 || g_h <= 0) return maxDist;

    while (dist < maxDist) {
        int tx = 0;
        int ty = 0;
        int proj = -1;
        int move = -1;

        dist += TNX_SHAPE_TRACE_STEP;
        if (dist > maxDist) dist = maxDist;

        tx = (int)((wx + dirX * dist) / TNX_TILE_SIZE);
        ty = (int)((wy + dirY * dist) / TNX_TILE_SIZE);

        if (tx < 0 || tx >= g_w || ty < 0 || ty >= g_h) {
            float hit = dist - TNX_SHAPE_TRACE_BACKOFF;

            return hit > 0.0f ? hit : 0.0f;
        }

        if (tnx_cell(tx, ty, &proj, &move) && proj != 0) {
            float hit = dist - TNX_SHAPE_TRACE_BACKOFF;

            return hit > 0.0f ? hit : 0.0f;
        }
    }

    return maxDist;
}

static int tnx_shape_cross(int index, const tnx_shape_in_t *in, uint64_t nowMs, tnx_shape_t *out,
                           int maxOut) {
    float arm = 0.0f;
    float burstLife = 0.0f;
    uint64_t landAt = 0;
    uint64_t t0 = 0;
    uint64_t t1 = 0;
    float cx = 0.0f;
    float cy = 0.0f;

    if (index < 0 || index >= TNX_SHAPE_CROSS) return TNX_SHAPE_NONE;
    if (!out || maxOut < 2) return TNX_SHAPE_NONE;

    cx = (float)in->targetX;
    cy = (float)in->targetY;

    if (cx != cx || cy != cy) return TNX_SHAPE_NONE;
    if (cx == 0.0f || cy == 0.0f) return TNX_SHAPE_NONE;
    if (fabsf(cx) > TNX_SHAPE_MAX_COORD || fabsf(cy) > TNX_SHAPE_MAX_COORD) {
        return TNX_SHAPE_NONE;
    }

    arm = g_shape_cross[index][2] + g_shape_cross[index][3];
    burstLife = g_shape_cross[index][3] / g_shape_cross[index][1] * 1000.0f;
    landAt = (in->spawnedAt ? in->spawnedAt : nowMs) + (uint64_t)g_shape_cross[index][4];
    t0 = landAt > (uint64_t)TNX_SHAPE_LOGIC_TICK_MS ? landAt - (uint64_t)TNX_SHAPE_LOGIC_TICK_MS
                                                    : 0;
    t1 = landAt + (uint64_t)burstLife + (uint64_t)TNX_SHAPE_LOGIC_TICK_MS;

    out[0].isSeg = 1;
    out[0].ax = cx - arm;
    out[0].ay = cy;
    out[0].bx = cx + arm;
    out[0].by = cy;
    out[0].radius = g_shape_cross[index][0];
    out[0].t0 = t0;
    out[0].t1 = t1;

    out[1].isSeg = 1;
    out[1].ax = cx;
    out[1].ay = cy - arm;
    out[1].bx = cx;
    out[1].by = cy + arm;
    out[1].radius = g_shape_cross[index][0];
    out[1].t0 = t0;
    out[1].t1 = t1;

    return 2;
}

static int tnx_shape_cactus(const tnx_shape_in_t *in, uint64_t nowMs, tnx_shape_t *out,
                            int maxOut) {
    float rad = 0.0f;
    float dirX = 0.0f;
    float dirY = 0.0f;
    float dist = 0.0f;
    float endX = 0.0f;
    float endY = 0.0f;
    uint64_t burstAt = 0;
    int n = 0;
    int s = 0;
    int k = 0;

    if (g_shape_variant == TNX_SHAPE_VARIANT_NONE) return TNX_SHAPE_NONE;
    if (!out || maxOut <= 0) return TNX_SHAPE_NONE;

    rad = in->angle * TNX_SHAPE_RAD;
    dirX = cosf(rad);
    dirY = sinf(rad);
    dist = tnx_shape_trace((float)in->spawnX, (float)in->spawnY, dirX, dirY,
                           TNX_SHAPE_SPIKE_FLIGHT_DIST);
    endX = (float)in->spawnX + dirX * dist;
    endY = (float)in->spawnY + dirY * dist;
    burstAt = (in->spawnedAt ? in->spawnedAt : nowMs) +
              (uint64_t)(TNX_SHAPE_SPIKE_FLIGHT_MS * (dist / TNX_SHAPE_SPIKE_FLIGHT_DIST));

    if (in->spawnAreaRadius > 0.0f && n < maxOut) {
        out[n].isSeg = 0;
        out[n].ax = endX;
        out[n].ay = endY;
        out[n].bx = endX;
        out[n].by = endY;
        out[n].radius = in->spawnAreaRadius;
        out[n].t0 = burstAt;
        out[n].t1 = burstAt + (uint64_t)(in->spawnAreaActiveTime > 0.0f ? in->spawnAreaActiveTime
                                                                       : TNX_SHAPE_SPIKE_BLAST_MS);
        n++;
    }

    if (g_shape_variant == TNX_SHAPE_VARIANT_STRAIGHT) {
        uint64_t t0 = burstAt > (uint64_t)TNX_SHAPE_LOGIC_TICK_MS
                          ? burstAt - (uint64_t)TNX_SHAPE_LOGIC_TICK_MS
                          : 0;
        uint64_t t1 = burstAt + (uint64_t)TNX_SHAPE_SPIKE_BURST_MS +
                      (uint64_t)TNX_SHAPE_LOGIC_TICK_MS;

        for (k = 0; k < TNX_SHAPE_STRAIGHT_ARMS && n < maxOut; k++) {
            float a = (float)k * (TNX_SHAPE_PI / 3.0f);
            float dx = cosf(a) * TNX_SHAPE_SPIKE_ARM;
            float dy = sinf(a) * TNX_SHAPE_SPIKE_ARM;

            out[n].isSeg = 1;
            out[n].ax = endX - dx;
            out[n].ay = endY - dy;
            out[n].bx = endX + dx;
            out[n].by = endY + dy;
            out[n].radius = TNX_SHAPE_SPIKE_RADIUS;
            out[n].t0 = t0;
            out[n].t1 = t1;
            n++;
        }

        return n;
    }

    for (s = 0; s < TNX_SHAPE_SPOKES; s++) {
        float rot = (float)s * (2.0f * TNX_SHAPE_PI / (float)TNX_SHAPE_SPOKES);
        float cr = cosf(rot);
        float sr = sinf(rot);

        for (k = 0; k + 1 < TNX_SHAPE_ARC_N && n < maxOut; k++) {
            float ta = g_shape_arc[k][0];
            float ax = g_shape_arc[k][1];
            float ay = g_shape_arc[k][2];
            float tb = g_shape_arc[k + 1][0];
            float bx = g_shape_arc[k + 1][1];
            float by = g_shape_arc[k + 1][2];

            out[n].isSeg = 1;
            out[n].ax = endX + ax * cr - ay * sr;
            out[n].ay = endY + ax * sr + ay * cr;
            out[n].bx = endX + bx * cr - by * sr;
            out[n].by = endY + bx * sr + by * cr;
            out[n].radius = TNX_SHAPE_SPIKE_RADIUS;
            out[n].t0 = burstAt + (uint64_t)ta;
            out[n].t1 = burstAt + (uint64_t)tb;
            n++;
        }
    }

    return n;
}

int tnx_shape_hazards(const tnx_shape_in_t *in, uint64_t nowMs, tnx_shape_t *out, int maxOut) {
    if (!in || !in->name || !out || maxOut <= 0) return TNX_SHAPE_NONE;

    if (strcmp(in->name, "CrossBomberProjectile") == 0) {
        return tnx_shape_cross(0, in, nowMs, out, maxOut);
    }

    if (strcmp(in->name, "CrossBomberUltiProjectile") == 0) {
        return tnx_shape_cross(1, in, nowMs, out, maxOut);
    }

    if (strcmp(in->name, "CactusProjectile") == 0) {
        return tnx_shape_cactus(in, nowMs, out, maxOut);
    }

    if (strcmp(in->name, "CactusSpike") == 0) {
        return g_shape_variant != TNX_SHAPE_VARIANT_NONE ? 0 : TNX_SHAPE_NONE;
    }

    return TNX_SHAPE_NONE;
}

int tnx_shape_blocks_linear(const char *name) {
    if (!name) return 0;

    if (strcmp(name, "CrossBomberProjectile") == 0) return 1;
    if (strcmp(name, "CrossBomberUltiProjectile") == 0) return 1;
    if (strcmp(name, "CactusSpike") == 0) return 1;

    return 0;
}

void tnx_shape_note_death(const char *name, int32_t x, int32_t y, int32_t spawnX, int32_t spawnY,
                          float angleDeg) {
    float dx = 0.0f;
    float dy = 0.0f;
    float chord = 0.0f;
    float deviation = 0.0f;

    if (g_shape_variant != TNX_SHAPE_VARIANT_NONE) return;
    if (!name || strcmp(name, "CactusProjectile") != 0) return;

    dx = (float)(x - spawnX);
    dy = (float)(y - spawnY);

    if (dx * dx + dy * dy < 1.0f) return;

    chord = atan2f(dy, dx) / TNX_SHAPE_RAD;
    deviation = fmodf(fmodf(chord - angleDeg, 360.0f) + 540.0f, 360.0f) - 180.0f;
    if (deviation < 0.0f) deviation = -deviation;

    g_shape_variant = deviation > TNX_SHAPE_SPIKE_CURVE_DEG ? TNX_SHAPE_VARIANT_CURVE
                                                           : TNX_SHAPE_VARIANT_STRAIGHT;
}
