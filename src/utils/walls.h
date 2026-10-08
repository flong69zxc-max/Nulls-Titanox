#ifndef RECOIL_UTILS_WALLS_H
#define RECOIL_UTILS_WALLS_H

#include "../core/offsets.h"
#include <stdint.h>

extern uintptr_t rcl_tiles;
extern int rcl_w;
extern int rcl_h;

#define RCL_WALL_TILE_SIZE 300.0f
#define RCL_WALL_BLOCKS_MOVEMENT 128
#define RCL_WALL_BLOCKS_PROJECTILES 64
#define RCL_WALL_TRACE_STEP 40.0f
#define RCL_WALL_TRACE_BACKOFF 75.0f
#define RCL_WALL_MAX_MAP_TILES 120
#define RCL_WALL_MAX_TOTAL_TILES (RCL_WALL_MAX_MAP_TILES * RCL_WALL_MAX_MAP_TILES)
#define RCL_WALL_RETRY_MS 2000

uintptr_t rcl_map_object(void);
int rcl_cell(int tx, int ty, int *proj, int *move);

int rcl_wall_cache_w(void);
int rcl_wall_cache_h(void);
void rcl_wall_notify_battle_mode_changed(uint64_t now_ms);
int rcl_wall_build(void);
int rcl_wall_maybe_refresh(uint64_t now_ms);
int rcl_wall_is_blocked_at(float x, float y, int mask);
int rcl_wall_is_blocked_wide(float x, float y, float r, int mask);
int rcl_wall_los(float ax, float ay, float bx, float by, int mask);
float rcl_wall_trace(float x, float y, float dx, float dy, float max_dist, int mask);

#endif
