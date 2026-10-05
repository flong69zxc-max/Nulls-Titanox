#ifndef TITANOX_FEATURES_WALLS_H
#define TITANOX_FEATURES_WALLS_H

#include "core/types.h"

extern int g_v98_clip_pass;
extern int g_v98_clip_fail;
extern uint8_t g_v242_grid[TNX_V242_GRID_MAX * TNX_V242_GRID_MAX];
extern uintptr_t g_v242_tiles;
extern int g_v242_w;
extern int g_v242_h;
extern int g_v242_cells;
extern int g_v242_solid;
extern int g_v242_move;
extern int g_v242_img;
extern int g_v242_own_tx;
extern int g_v242_own_ty;
extern int g_v242_own_proj;
extern int g_v242_own_move;
extern int g_v242_passes;
extern int g_v242_armed;
extern int g_v242_live;
extern int g_v242_fail;
extern int g_v242_seg_test;
extern int g_v242_seg_clip;
extern int g_v242_seg_frac;
extern int g_v242_logs;
extern uint64_t g_v242_built;

int tnx_v98_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell, const uint8_t *solid, int gw, int gh, int32_t *outX, int32_t *outY);
void tnx_v98_clip_selftest(void);
void tnx_v242_log_grid(int force);
int tnx_v242_cell(int tx, int ty, int *proj, int *move);
void tnx_v242_tile_of(float x, float y, int *tx, int *ty);
int tnx_v242_build(void);
float tnx_v242_clip_range(float ax, float ay, float dx, float dy, float rem);
void tnx_v242_arm(float ownX, float ownY);

#endif
