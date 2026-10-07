#ifndef TITANOX_SCAN_WALLS_H
#define TITANOX_SCAN_WALLS_H

#include "core/types.h"
#include "core/config.h"
#include "core/offsets.h"

extern uint8_t t_grid[TNX_GRID_MAX * TNX_GRID_MAX];
extern uintptr_t t_tiles;
extern int t_w;
extern int t_h;
extern int t_cells;
extern int t_solid;
extern int t_img;
extern int t_own_tx;
extern int t_own_ty;
extern int t_own_proj;
extern int t_passes;
extern int t_armed;
extern int t_live;
extern int t_seg_test;
extern int t_seg_clip;
extern int t_seg_frac;
extern int t_logs_b;
extern uint64_t t_built;

uintptr_t tnx_map_object(void);
int tnx_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell, const uint8_t *solid, int gw, int gh, int32_t *outX, int32_t *outY);
void tnx_log_grid(int force);
int tnx_cell(int tx, int ty, int *proj, int *move);
void tnx_tile_of(float x, float y, int *tx, int *ty);
int tnx_build_2(void);
float tnx_clip_range(float ax, float ay, float dx, float dy, float rem);
void tnx_arm(float ownX, float ownY);

#endif
