#include "titanox.h"

int g_v98_clip_pass = 0;

int g_v98_clip_fail = 0;

int tnx_v98_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell,
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

void tnx_v98_clip_selftest(void) {
    uint8_t grid[TNX_V98_GRID * TNX_V98_GRID];
    int32_t ox = 0;
    int32_t oy = 0;
    int hit = 0;

    memset(grid, 0, sizeof(grid));

    for (int i = 0; i < TNX_V98_GRID; i++) grid[3 + i * TNX_V98_GRID] = 1;

    hit = tnx_v98_clip_walk(100, 100, 700, 100, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 1 && ox == 300 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case1 hit=%d out=(%d,%d) want=(300,100) - a segment crossing one wall cell "
             "must stop on its near edge", hit, ox, oy);

    hit = tnx_v98_clip_walk(500, 100, 700, 100, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 0 && ox == 700 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case2 hit=%d out=(%d,%d) want=(700,100) - a segment that meets no wall must "
             "keep its far end", hit, ox, oy);

    hit = tnx_v98_clip_walk(350, 100, 700, 100, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 1 && ox == 350 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case3 hit=%d out=(%d,%d) want=(350,100) - a segment starting inside a wall "
             "must clip to its own start", hit, ox, oy);

    hit = tnx_v98_clip_walk(100, 100, 100, 700, 100, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 0 && ox == 100 && oy == 700) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case4 hit=%d out=(%d,%d) want=(100,700) - a vertical segment away from the "
             "wall must not be clipped", hit, ox, oy);

    ox = 0;
    oy = 0;

    hit = tnx_v98_clip_walk(100, 100, 700, 100, 0, grid, TNX_V98_GRID, TNX_V98_GRID, &ox, &oy);

    if (hit == 0 && ox == 700 && oy == 100) g_v98_clip_pass++;
    else g_v98_clip_fail++;

    tnx_logf("v100 clip case5 hit=%d out=(%d,%d) want=(700,100) - a zero cell must return before "
             "anything is divided by it and leave the far end in place, which is the guard v98 "
             "placed after the division it guards", hit, ox, oy);

    tnx_logf("v100 clip selftest pass=%d fail=%d - the clipping that the threat segment needs is "
             "exercised on a synthetic grid before it is ever pointed at the real tilemap, so a "
             "clipped range can be trusted the day an actuator exists", g_v98_clip_pass,
             g_v98_clip_fail);
}

uint8_t g_v242_grid[TNX_V242_GRID_MAX * TNX_V242_GRID_MAX] = { 0 };

uintptr_t g_v242_tiles = 0;

int g_v242_w = 0;

int g_v242_h = 0;

int g_v242_cells = 0;

int g_v242_solid = 0;

int g_v242_move = 0;

int g_v242_img = 0;

int g_v242_own_tx = -1;

int g_v242_own_ty = -1;

int g_v242_own_proj = -1;

int g_v242_own_move = -1;

int g_v242_passes = 0;

int g_v242_armed = 0;

int g_v242_live = 0;

int g_v242_fail = 0;

int g_v242_seg_test = 0;

int g_v242_seg_clip = 0;

int g_v242_seg_frac = 0;

int g_v242_logs = 0;

uint64_t g_v242_built = 0;

void tnx_v242_log_grid(int force) {
    char mask[16];
    int ix = 0;
    int iy = 0;
    int n = 0;

    if (!force && g_v242_logs >= TNX_V242_LOGS) return;

    g_v242_logs++;

    for (iy = g_v242_own_ty - 1; iy <= g_v242_own_ty + 1; iy++) {
        if (iy > g_v242_own_ty - 1) mask[n++] = '/';

        for (ix = g_v242_own_tx - 1; ix <= g_v242_own_tx + 1; ix++) {
            if (ix < 0 || iy < 0 || ix >= g_v242_w || iy >= g_v242_h) mask[n++] = '?';
            else mask[n++] = g_v242_grid[iy * g_v242_w + ix] ? '#' : '.';
        }
    }

    mask[n] = 0;

    tnx_logf("v242 grid w=%d h=%d cells=%d proj=%d move=%d img=%d own=(%d,%d) ownProj=%d ownMove=%d "
             "mask=%s passes=%d armed=%d live=%d fail=%d tested=%d clipped=%d frac=%d - the tile map is "
             "read the way the reference reads it: the array at +%#llx holds %d pointers indexed width*y+x, "
             "the type is the pointer at tile+0, and its packed pair is movement at +%#llx and projectiles "
             "at +%#llx, which the two one instruction getters in this image confirm. ownProj must read 0 "
             "because a character cannot stand inside a wall, and proj above %d percent or a clip fraction "
             "above %d percent means the layout or the tile scale is wrong, so the clip stays off and this "
             "line names the gate that held it off",
             g_v242_w, g_v242_h, g_v242_cells, g_v242_solid, g_v242_move, g_v242_img,
             g_v242_own_tx, g_v242_own_ty, g_v242_own_proj, g_v242_own_move, mask,
             g_v242_passes, g_v242_armed, g_v242_live, g_v242_fail,
             g_v242_seg_test, g_v242_seg_clip, g_v242_seg_frac,
             (unsigned long long)TNX_V242_TILES_OFF, g_v242_cells,
             (unsigned long long)TNX_V242_TYPE_MOVE_OFF, (unsigned long long)TNX_V242_TYPE_PROJ_OFF,
             TNX_V242_MAX_SOLID_PCT, TNX_V242_MAX_CLIP_PCT);
}

int tnx_v242_cell(int tx, int ty, int *proj, int *move) {
    void *tile = NULL;
    void *type = NULL;
    uint8_t bm = 0;
    uint8_t bp = 0;

    *proj = -1;
    *move = -1;

    if (!g_v242_tiles) return 0;
    if (tx < 0 || ty < 0 || tx >= g_v242_w || ty >= g_v242_h) return 0;
    if (!tnx_read_ptr(g_v242_tiles + (uintptr_t)(ty * g_v242_w + tx) * (uintptr_t)sizeof(void *), &tile)) return 0;

    if (!tile) {
        *proj = 0;
        *move = 0;

        return 1;
    }

    if (!tnx_read_ptr((uintptr_t)tile, &type) || !type) return 0;
    if (!tnx_read_bytes((uintptr_t)type + TNX_V242_TYPE_MOVE_OFF, &bm, 1)) return 0;
    if (!tnx_read_bytes((uintptr_t)type + TNX_V242_TYPE_PROJ_OFF, &bp, 1)) return 0;

    *proj = (int)bp;
    *move = (int)bm;

    return 1;
}

void tnx_v242_tile_of(float x, float y, int *tx, int *ty) {
    if (x < 0.0f || y < 0.0f) {
        *tx = -1;
        *ty = -1;

        return;
    }

    *tx = (int)(x / TNX_V242_TILE_SIZE);
    *ty = (int)(y / TNX_V242_TILE_SIZE);
}

int tnx_v242_build(void) {
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

    g_v242_tiles = 0;
    g_v242_w = 0;
    g_v242_h = 0;
    g_v242_cells = 0;
    g_v242_solid = 0;
    g_v242_move = 0;
    g_v242_img = 0;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr(g_scene_object + TNX_MODE_TILEMAP_OFF, &tileMap) || !tileMap) return 0;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_WIDTH_OFF, &w)) return 0;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_HEIGHT_OFF, &h)) return 0;
    if (w < TNX_V47_MAP_MIN || h < TNX_V47_MAP_MIN) return 0;
    if (w > TNX_V242_GRID_MAX || h > TNX_V242_GRID_MAX) return 0;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_V242_COUNT_OFF, &count)) return 0;
    if (count < w * h) return 0;
    if (!tnx_read_ptr((uintptr_t)tileMap + TNX_V242_TILES_OFF, &tiles) || !tiles) return 0;

    cells = w * h;

    memset(g_v242_grid, 0, (size_t)cells);

    for (i = 0; i < cells; i++) {
        void *tile = NULL;
        void *type = NULL;
        uint8_t bm = 0;
        uint8_t bp = 0;

        if (!tnx_read_ptr((uintptr_t)tiles + (uintptr_t)i * (uintptr_t)sizeof(void *), &tile) || !tile) continue;
        if (!tnx_read_ptr((uintptr_t)tile, &type) || !type) continue;
        if ((uintptr_t)type >= g_base && (uintptr_t)type < g_base + TNX_V60_IMAGE_SPAN) img++;
        if (!tnx_read_bytes((uintptr_t)type + TNX_V242_TYPE_MOVE_OFF, &bm, 1)) continue;
        if (!tnx_read_bytes((uintptr_t)type + TNX_V242_TYPE_PROJ_OFF, &bp, 1)) continue;

        if (bm) move++;
        if (bp) {
            solid++;
            g_v242_grid[i] = 1;
        }
    }

    g_v242_tiles = (uintptr_t)tiles;
    g_v242_w = w;
    g_v242_h = h;
    g_v242_cells = cells;
    g_v242_solid = solid;
    g_v242_move = move;
    g_v242_img = img;

    return 1;
}

float tnx_v242_clip_range(float ax, float ay, float dx, float dy, float rem) {
    int32_t ox = 0;
    int32_t oy = 0;
    float hx = 0.0f;
    float hy = 0.0f;
    float d = 0.0f;

    if (!g_v242_live) return rem;

    g_v242_seg_test++;

    if (!tnx_v98_clip_walk((int32_t)ax, (int32_t)ay, (int32_t)(ax + dx * rem), (int32_t)(ay + dy * rem),
                           (int32_t)TNX_V242_TILE_SIZE, g_v242_grid, g_v242_w, g_v242_h, &ox, &oy)) {
        return rem;
    }

    hx = (float)ox;
    hy = (float)oy;
    d = sqrtf((hx - ax) * (hx - ax) + (hy - ay) * (hy - ay));

    if (d < TNX_V242_MIN_CLIP) d = TNX_V242_MIN_CLIP;

    g_v242_seg_clip++;

    return d;
}

void tnx_v242_arm(float ownX, float ownY) {
    int tx = -1;
    int ty = -1;
    int proj = -1;
    int move = -1;
    int solidPct = 0;
    int imgPct = 0;
    int wasArmed = g_v242_armed;
    int gate = 1;

    if (g_v242_seg_test >= TNX_V242_MIN_SEGS && g_v242_seg_frac > TNX_V242_MAX_CLIP_PCT) {
        g_v242_armed = 0;
        g_v242_passes = 0;
        g_v242_fail++;
    }

    g_v242_live = 0;
    g_v242_seg_test = 0;
    g_v242_seg_clip = 0;
    g_v242_seg_frac = 0;

    if (!TNX_V242_WALL_CLIP) return;

    if (g_v242_armed && (g_v48_ticks - g_v242_built) < TNX_V242_REBUILD_TICKS) {
        tnx_v242_tile_of(ownX, ownY, &tx, &ty);

        if (tx == g_v242_own_tx && ty == g_v242_own_ty && g_v242_own_proj == 0) {
            g_v242_live = 1;
        } else if (tnx_v242_cell(tx, ty, &proj, &move) && proj == 0) {
            g_v242_own_tx = tx;
            g_v242_own_ty = ty;
            g_v242_own_proj = proj;
            g_v242_own_move = move;
            g_v242_live = 1;
        } else {
            g_v242_armed = 0;
            g_v242_passes = 0;
            g_v242_fail++;
            tnx_v242_log_grid(1);
        }

        return;
    }

    if (!tnx_v242_build()) {
        g_v242_armed = 0;
        g_v242_passes = 0;
        g_v242_fail++;
        tnx_v242_log_grid(1);

        return;
    }

    g_v242_built = g_v48_ticks;

    tnx_v242_tile_of(ownX, ownY, &tx, &ty);
    tnx_v242_cell(tx, ty, &proj, &move);

    g_v242_own_tx = tx;
    g_v242_own_ty = ty;
    g_v242_own_proj = proj;
    g_v242_own_move = move;

    solidPct = (g_v242_solid * 100) / g_v242_cells;
    imgPct = (g_v242_img * 100) / g_v242_cells;

    if (tx < 0 || ty < 0 || tx >= g_v242_w || ty >= g_v242_h) gate = 0;
    if (proj != 0) gate = 0;
    if (solidPct > TNX_V242_MAX_SOLID_PCT) gate = 0;
    if (imgPct < TNX_V242_MIN_IMG_PCT) gate = 0;

    if (gate) {
        if (g_v242_passes < TNX_V242_MIN_PASSES) g_v242_passes++;
        if (g_v242_passes >= TNX_V242_MIN_PASSES) g_v242_armed = 1;
    } else {
        g_v242_armed = 0;
        g_v242_passes = 0;
        g_v242_fail++;
    }

    if (g_v242_armed) g_v242_live = 1;

    tnx_v242_log_grid((g_v242_armed != wasArmed) ? 1 : 0);
}
