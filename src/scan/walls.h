#ifndef RECOIL_SCAN_WALLS_H
#define RECOIL_SCAN_WALLS_H

#include "core/types.h"
#include "core/config.h"
#include "core/offsets.h"

extern uint8_t rcl_grid[RCL_GRID_MAX * RCL_GRID_MAX];
extern uintptr_t rcl_tiles;
extern int rcl_w;
extern int rcl_h;
extern int rcl_cells;
extern int rcl_solid;
extern int rcl_img;
extern int rcl_own_tx;
extern int rcl_own_ty;
extern int rcl_own_proj;
extern int rcl_passes;
extern int rcl_armed;
extern int rcl_live;
extern int rcl_seg_test;
extern int rcl_seg_clip;
extern int rcl_seg_frac;
extern uint64_t rcl_built;

uintptr_t rcl_map_object(void);
int rcl_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell, const uint8_t *solid, int gw, int gh, int32_t *outX, int32_t *outY);
int rcl_cell(int tx, int ty, int *proj, int *move);
void rcl_tile_of(float x, float y, int *tx, int *ty);
int rcl_build_2(void);
float rcl_clip_range(float ax, float ay, float dx, float dy, float rem);
void rcl_arm(float ownX, float ownY);

#endif
