#include "../recoil.h"

uintptr_t rcl_tiles = 0;

int rcl_w = 0;

int rcl_h = 0;

uintptr_t rcl_map_object(void)
{
    void *client = NULL;
    void *map = NULL;

    if (!rcl_scene_object) return 0;
    if (!rcl_read_ptr((uintptr_t)rcl_scene_object + RCL_MAP_BASE_OFF, &client) || !client) return 0;
    if (!rcl_read_ptr((uintptr_t)client + RCL_MAP_PTR_OFF, &map) || !map) return 0;

    return (uintptr_t)map;
}

int rcl_cell(int tx, int ty, int *proj, int *move)
{
    void *tile = NULL;
    void *type = NULL;
    uint8_t bm = 0;
    uint8_t bp = 0;

    *proj = -1;
    *move = -1;

    if (!rcl_tiles) return 0;
    if (tx < 0 || ty < 0 || tx >= rcl_w || ty >= rcl_h) return 0;
    if (!rcl_read_ptr(rcl_tiles + (uintptr_t)(ty * rcl_w + tx) * (uintptr_t)RCL_TILE_PTR_STRIDE,
                      &tile))
        return 0;

    if (!tile)
    {
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

void rcl_tile_of(float x, float y, int *tx, int *ty)
{
    if (x < 0.0f || y < 0.0f)
    {
        *tx = -1;
        *ty = -1;

        return;
    }

    *tx = (int)(x / RCL_TILE_SIZE);
    *ty = (int)(y / RCL_TILE_SIZE);
}
