#include "../../recoil.h"

int rcl_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell,
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

uint8_t rcl_grid[RCL_GRID_MAX * RCL_GRID_MAX] = { 0 };

uintptr_t rcl_tiles = 0;

int rcl_w = 0;

int rcl_h = 0;

int rcl_cells = 0;

int rcl_solid = 0;


int rcl_img = 0;

int rcl_own_tx = -1;

int rcl_own_ty = -1;

int rcl_own_proj = -1;


int rcl_passes = 0;

int rcl_armed = 0;

int rcl_live = 0;


int rcl_seg_test = 0;

int rcl_seg_clip = 0;

int rcl_seg_frac = 0;


uint64_t rcl_built = 0;

uintptr_t rcl_map_object(void) {
    void *client = NULL;
    void *map = NULL;

    if (!rcl_scene_object) return 0;
    if (!rcl_read_ptr((uintptr_t)rcl_scene_object + RCL_MAP_BASE_OFF, &client) || !client) return 0;
    if (!rcl_read_ptr((uintptr_t)client + RCL_MAP_PTR_OFF, &map) || !map) return 0;

    return (uintptr_t)map;
}

int rcl_cell(int tx, int ty, int *proj, int *move) {
    void *tile = NULL;
    void *type = NULL;
    uint8_t bm = 0;
    uint8_t bp = 0;

    *proj = -1;
    *move = -1;

    if (!rcl_tiles) return 0;
    if (tx < 0 || ty < 0 || tx >= rcl_w || ty >= rcl_h) return 0;
    if (!rcl_read_ptr(rcl_tiles + (uintptr_t)(ty * rcl_w + tx) * (uintptr_t)RCL_TILE_PTR_STRIDE, &tile)) return 0;

    if (!tile) {
        *proj = 0;
        *move = 0;

        return 1;
    }

    if (!rcl_read_ptr((uintptr_t)tile, &type) || !type) return 0;
    if (!rcl_read_bytes((uintptr_t)type + RCL_TILE_TYPE_MOVE_OFF, &bm, 1)) return 0;
    if (!rcl_read_bytes((uintptr_t)type + RCL_TILE_TYPE_PROJ_OFF, &bp, 1)) return 0;

    *proj = (int)bp;
    *move = (int)bm;

    return 1;
}

void rcl_tile_of(float x, float y, int *tx, int *ty) {
    if (x < 0.0f || y < 0.0f) {
        *tx = -1;
        *ty = -1;

        return;
    }

    *tx = (int)(x / RCL_TILE_SIZE);
    *ty = (int)(y / RCL_TILE_SIZE);
}

int rcl_build_2(void) {
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

    rcl_tiles = 0;
    rcl_w = 0;
    rcl_h = 0;
    rcl_cells = 0;
    rcl_solid = 0;
    rcl_img = 0;

    if (!rcl_scene_object) return 0;
    if (!rcl_read_ptr((uintptr_t)rcl_scene_object + RCL_MAP_BASE_OFF, &client) || !client) return 0;
    if (!rcl_read_ptr((uintptr_t)client + RCL_MAP_PTR_OFF, &tileMap) || !tileMap) return 0;
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_WIDTH_OFF, &w)) return 0;
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_HEIGHT_OFF, &h)) return 0;
    if (w < RCL_MAP_MIN || h < RCL_MAP_MIN) return 0;
    if (w > RCL_GRID_MAX || h > RCL_GRID_MAX) return 0;
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_COUNT_OFF, &count)) return 0;
    if (count < w * h) return 0;
    if (!rcl_read_ptr((uintptr_t)tileMap + RCL_MAP_TILES_OFF, &tiles) || !tiles) return 0;

    cells = w * h;

    memset(rcl_grid, 0, (size_t)cells);

    for (i = 0; i < cells; i++) {
        void *tile = NULL;
        void *type = NULL;
        uint8_t bm = 0;
        uint8_t bp = 0;

        if (!rcl_read_ptr((uintptr_t)tiles + (uintptr_t)i * (uintptr_t)RCL_TILE_PTR_STRIDE, &tile) || !tile) continue;
        if (!rcl_read_ptr((uintptr_t)tile, &type) || !type) continue;
        if ((uintptr_t)type >= rcl_base && (uintptr_t)type < rcl_base + RCL_IMAGE_SPAN) img++;
        if (!rcl_read_bytes((uintptr_t)type + RCL_TILE_TYPE_MOVE_OFF, &bm, 1)) continue;
        if (!rcl_read_bytes((uintptr_t)type + RCL_TILE_TYPE_PROJ_OFF, &bp, 1)) continue;

        if (bm) move++;
        if (bp) {
            solid++;
            rcl_grid[i] = 1;
        }
    }

    rcl_tiles = (uintptr_t)tiles;
    rcl_w = w;
    rcl_h = h;
    rcl_cells = cells;
    rcl_solid = solid;
    rcl_img = img;

    return 1;
}

float rcl_clip_range(float ax, float ay, float dx, float dy, float rem) {
    int32_t ox = 0;
    int32_t oy = 0;
    float hx = 0.0f;
    float hy = 0.0f;
    float d = 0.0f;

    if (!rcl_live) return rem;

    rcl_seg_test++;

    if (!rcl_clip_walk((int32_t)ax, (int32_t)ay, (int32_t)(ax + dx * rem), (int32_t)(ay + dy * rem),
                       (int32_t)RCL_TILE_SIZE, rcl_grid, rcl_w, rcl_h, &ox, &oy)) {
        return rem;
    }

    hx = (float)ox;
    hy = (float)oy;
    d = sqrtf((hx - ax) * (hx - ax) + (hy - ay) * (hy - ay));

    if (d < RCL_MIN_CLIP) d = RCL_MIN_CLIP;

    rcl_seg_clip++;

    return d;
}

void rcl_arm(float ownX, float ownY) {
    int tx = -1;
    int ty = -1;
    int proj = -1;
    int move = -1;
    int solidPct = 0;
    int imgPct = 0;
    int wasArmed = rcl_armed;
    int gate = 1;

    if (rcl_seg_test >= RCL_MIN_SEGS && rcl_seg_frac > RCL_MAX_CLIP_PCT) {
        rcl_armed = 0;
        rcl_passes = 0;
    }

    rcl_live = 0;
    rcl_seg_test = 0;
    rcl_seg_clip = 0;
    rcl_seg_frac = 0;

    if (!RCL_WALL_CLIP) return;

    if (rcl_armed && (rcl_ticks_a - rcl_built) < RCL_REBUILD_TICKS) {
        rcl_tile_of(ownX, ownY, &tx, &ty);

        if (tx == rcl_own_tx && ty == rcl_own_ty && rcl_own_proj == 0) {
            rcl_live = 1;
        } else if (rcl_cell(tx, ty, &proj, &move) && proj == 0) {
            rcl_own_tx = tx;
            rcl_own_ty = ty;
            rcl_own_proj = proj;
            rcl_live = 1;
        } else {
            rcl_armed = 0;
            rcl_passes = 0;
        }

        return;
    }

    if (!rcl_build_2()) {
        rcl_armed = 0;
        rcl_passes = 0;

        return;
    }

    rcl_built = rcl_ticks_a;

    rcl_tile_of(ownX, ownY, &tx, &ty);
    rcl_cell(tx, ty, &proj, &move);

    rcl_own_tx = tx;
    rcl_own_ty = ty;
    rcl_own_proj = proj;

    solidPct = (rcl_solid * 100) / rcl_cells;
    imgPct = (rcl_img * 100) / rcl_cells;

    if (tx < 0 || ty < 0 || tx >= rcl_w || ty >= rcl_h) gate = 0;
    if (proj != 0) gate = 0;
    if (solidPct > RCL_MAX_SOLID_PCT) gate = 0;
    if (imgPct < RCL_MIN_IMG_PCT) gate = 0;

    if (gate) {
        if (rcl_passes < RCL_MIN_PASSES) rcl_passes++;
        if (rcl_passes >= RCL_MIN_PASSES) rcl_armed = 1;
    } else {
        rcl_armed = 0;
        rcl_passes = 0;
    }

    if (rcl_armed) rcl_live = 1;

}
