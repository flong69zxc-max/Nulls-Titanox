#include "titanox.h"

int tnx_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell,
                  const uint8_t *solid, int gw, int gh, int32_t *outX, int32_t *outY) {
    int32_t cx = 0;
    int32_t cy = 0;
    int32_t stepX = 0;
    int32_t stepY = 0;
    int32_t spanX = 0;
    int32_t spanY = 0;
    float tDeltaX = 0.0f;
    float tDeltaY = 0.0f;
    float tMaxX = 2.0f;
    float tMaxY = 2.0f;

    if (outX) *outX = bx;
    if (outY) *outY = by;

    if (!solid || cell <= 0) return 0;

    cx = ax / cell;
    cy = ay / cell;
    stepX = (bx > ax) ? 1 : ((bx < ax) ? -1 : 0);
    stepY = (by > ay) ? 1 : ((by < ay) ? -1 : 0);
    spanX = (bx > ax) ? (bx - ax) : (ax - bx);
    spanY = (by > ay) ? (by - ay) : (ay - by);

    if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) return 0;

    if (solid[cx + cy * gw]) {
        if (outX) *outX = ax;
        if (outY) *outY = ay;

        return 1;
    }

    if (stepX != 0 && spanX > 0) {
        tDeltaX = (float)cell / (float)spanX;
        tMaxX = (float)((stepX > 0) ? ((cx + 1) * cell - ax) : (ax - cx * cell)) / (float)spanX;
    }

    if (stepY != 0 && spanY > 0) {
        tDeltaY = (float)cell / (float)spanY;
        tMaxY = (float)((stepY > 0) ? ((cy + 1) * cell - ay) : (ay - cy * cell)) / (float)spanY;
    }

    for (int guard = 0; guard < 4096; guard++) {
        float t = (tMaxX < tMaxY) ? tMaxX : tMaxY;

        if (t > 1.0f) break;

        if (tMaxX < tMaxY) {
            cx += stepX;
            tMaxX += tDeltaX;
        } else {
            cy += stepY;
            tMaxY += tDeltaY;
        }

        if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) break;

        if (solid[cx + cy * gw]) {
            if (outX) *outX = ax + (int32_t)((float)(bx - ax) * t);
            if (outY) *outY = ay + (int32_t)((float)(by - ay) * t);

            return 1;
        }
    }

    return 0;
}

uint8_t g_grid[TNX_GRID_MAX * TNX_GRID_MAX] = { 0 };

uintptr_t g_tiles = 0;

int g_w = 0;

int g_h = 0;

int g_cells = 0;

int g_solid = 0;

int g_move = 0;

int g_img = 0;

int g_own_tx = -1;

int g_own_ty = -1;

int g_own_proj = -1;

int g_own_move = -1;

int g_passes = 0;

int g_armed = 0;

int g_live = 0;

int g_fail = 0;

int g_seg_test = 0;

int g_seg_clip = 0;

int g_seg_frac = 0;

int g_logs_10 = 0;

uint64_t g_built = 0;

uintptr_t tnx_map_object(void) {
    void *client = NULL;
    void *map = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_MAP_BASE_OFF, &client) || !client) return 0;
    if (!tnx_read_ptr((uintptr_t)client + TNX_MODE_TILEMAP_OFF, &map) || !map) return 0;

    return (uintptr_t)map;
}

void tnx_log_grid(int force) {
    char mask[16];
    int ix = 0;
    int iy = 0;
    int n = 0;

    if (!force && g_logs_10 >= TNX_LOGS_6) return;

    g_logs_10++;

    for (iy = g_own_ty - 1; iy <= g_own_ty + 1; iy++) {
        if (iy > g_own_ty - 1) mask[n++] = '/';

        for (ix = g_own_tx - 1; ix <= g_own_tx + 1; ix++) {
            if (ix < 0 || iy < 0 || ix >= g_w || iy >= g_h) mask[n++] = '?';
            else mask[n++] = g_grid[iy * g_w + ix] ? '#' : '.';
        }
    }

    mask[n] = 0;

    tnx_logf("grid w=%d h=%d cells=%d proj=%d move=%d img=%d own=(%d,%d) ownProj=%d ownMove=%d "
             "mask=%s passes=%d armed=%d live=%d fail=%d tested=%d clipped=%d frac=%d",
             g_w, g_h, g_cells, g_solid, g_move, g_img,
             g_own_tx, g_own_ty, g_own_proj, g_own_move, mask,
             g_passes, g_armed, g_live, g_fail,
             g_seg_test, g_seg_clip, g_seg_frac);
}

int tnx_cell(int tx, int ty, int *proj, int *move) {
    void *tile = NULL;
    void *type = NULL;
    uint8_t bm = 0;
    uint8_t bp = 0;

    *proj = -1;
    *move = -1;

    if (!g_tiles) return 0;
    if (tx < 0 || ty < 0 || tx >= g_w || ty >= g_h) return 0;
    if (!tnx_read_ptr(g_tiles + (uintptr_t)(ty * g_w + tx) * (uintptr_t)sizeof(void *), &tile)) return 0;

    if (!tile) {
        *proj = 0;
        *move = 0;

        return 1;
    }

    if (!tnx_read_ptr((uintptr_t)tile, &type) || !type) return 0;
    if (!tnx_read_bytes((uintptr_t)type + TNX_TYPE_MOVE_OFF, &bm, 1)) return 0;
    if (!tnx_read_bytes((uintptr_t)type + TNX_TYPE_PROJ_OFF, &bp, 1)) return 0;

    *proj = (int)bp;
    *move = (int)bm;

    return 1;
}

void tnx_tile_of(float x, float y, int *tx, int *ty) {
    if (x < 0.0f || y < 0.0f) {
        *tx = -1;
        *ty = -1;

        return;
    }

    *tx = (int)(x / TNX_TILE_SIZE);
    *ty = (int)(y / TNX_TILE_SIZE);
}

int tnx_build_2(void) {
    void *client = NULL;
    void *tileMap = NULL;
    void *tiles = NULL;
    int32_t w = 0;
    int32_t h = 0;
    int32_t count = 0;
    int32_t cells = 0;
    int32_t i = 0;
    int solid = 0;
    int move = 0;
    int img = 0;

    g_tiles = 0;
    g_w = 0;
    g_h = 0;
    g_cells = 0;
    g_solid = 0;
    g_move = 0;
    g_img = 0;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_MAP_BASE_OFF, &client) || !client) return 0;
    if (!tnx_read_ptr((uintptr_t)client + TNX_MODE_TILEMAP_OFF, &tileMap) || !tileMap) return 0;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_WIDTH_OFF, &w)) return 0;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_HEIGHT_OFF, &h)) return 0;
    if (w < TNX_MAP_MIN || h < TNX_MAP_MIN) return 0;
    if (w > TNX_GRID_MAX || h > TNX_GRID_MAX) return 0;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_COUNT_OFF_3, &count)) return 0;
    if (count < w * h) return 0;
    if (!tnx_read_ptr((uintptr_t)tileMap + TNX_TILES_OFF, &tiles) || !tiles) return 0;

    cells = w * h;

    memset(g_grid, 0, (size_t)cells);

    for (i = 0; i < cells; i++) {
        void *tile = NULL;
        void *type = NULL;
        uint8_t bm = 0;
        uint8_t bp = 0;

        if (!tnx_read_ptr((uintptr_t)tiles + (uintptr_t)i * (uintptr_t)sizeof(void *), &tile) || !tile) continue;
        if (!tnx_read_ptr((uintptr_t)tile, &type) || !type) continue;
        if ((uintptr_t)type >= g_base && (uintptr_t)type < g_base + TNX_IMAGE_SPAN) img++;
        if (!tnx_read_bytes((uintptr_t)type + TNX_TYPE_MOVE_OFF, &bm, 1)) continue;
        if (!tnx_read_bytes((uintptr_t)type + TNX_TYPE_PROJ_OFF, &bp, 1)) continue;

        if (bm) move++;
        if (bp) {
            solid++;
            g_grid[i] = 1;
        }
    }

    g_tiles = (uintptr_t)tiles;
    g_w = w;
    g_h = h;
    g_cells = cells;
    g_solid = solid;
    g_move = move;
    g_img = img;

    return 1;
}

float tnx_clip_range(float ax, float ay, float dx, float dy, float rem) {
    int32_t ox = 0;
    int32_t oy = 0;
    float hx = 0.0f;
    float hy = 0.0f;
    float d = 0.0f;

    if (!g_live) return rem;

    g_seg_test++;

    if (!tnx_clip_walk((int32_t)ax, (int32_t)ay, (int32_t)(ax + dx * rem), (int32_t)(ay + dy * rem),
                       (int32_t)TNX_TILE_SIZE, g_grid, g_w, g_h, &ox, &oy)) {
        return rem;
    }

    hx = (float)ox;
    hy = (float)oy;
    d = sqrtf((hx - ax) * (hx - ax) + (hy - ay) * (hy - ay));

    if (d < TNX_MIN_CLIP) d = TNX_MIN_CLIP;

    g_seg_clip++;

    return d;
}

void tnx_arm(float ownX, float ownY) {
    int tx = -1;
    int ty = -1;
    int proj = -1;
    int move = -1;
    int solidPct = 0;
    int imgPct = 0;
    int wasArmed = g_armed;
    int gate = 1;

    if (g_seg_test >= TNX_MIN_SEGS && g_seg_frac > TNX_MAX_CLIP_PCT) {
        g_armed = 0;
        g_passes = 0;
        g_fail++;
    }

    g_live = 0;
    g_seg_test = 0;
    g_seg_clip = 0;
    g_seg_frac = 0;

    if (!TNX_WALL_CLIP) return;

    if (g_armed && (g_ticks_3 - g_built) < TNX_REBUILD_TICKS) {
        tnx_tile_of(ownX, ownY, &tx, &ty);

        if (tx == g_own_tx && ty == g_own_ty && g_own_proj == 0) {
            g_live = 1;
        } else if (tnx_cell(tx, ty, &proj, &move) && proj == 0) {
            g_own_tx = tx;
            g_own_ty = ty;
            g_own_proj = proj;
            g_own_move = move;
            g_live = 1;
        } else {
            g_armed = 0;
            g_passes = 0;
            g_fail++;
            tnx_log_grid(1);
        }

        return;
    }

    if (!tnx_build_2()) {
        g_armed = 0;
        g_passes = 0;
        g_fail++;
        tnx_log_grid(1);

        return;
    }

    g_built = g_ticks_3;

    tnx_tile_of(ownX, ownY, &tx, &ty);
    tnx_cell(tx, ty, &proj, &move);

    g_own_tx = tx;
    g_own_ty = ty;
    g_own_proj = proj;
    g_own_move = move;

    solidPct = (g_solid * 100) / g_cells;
    imgPct = (g_img * 100) / g_cells;

    if (tx < 0 || ty < 0 || tx >= g_w || ty >= g_h) gate = 0;
    if (proj != 0) gate = 0;
    if (solidPct > TNX_MAX_SOLID_PCT) gate = 0;
    if (imgPct < TNX_MIN_IMG_PCT) gate = 0;

    if (gate) {
        if (g_passes < TNX_MIN_PASSES) g_passes++;
        if (g_passes >= TNX_MIN_PASSES) g_armed = 1;
    } else {
        g_armed = 0;
        g_passes = 0;
        g_fail++;
    }

    if (g_armed) g_live = 1;

    tnx_log_grid((g_armed != wasArmed) ? 1 : 0);
}
