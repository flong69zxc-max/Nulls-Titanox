#ifndef TITANOX_FEATURES_WALLS_H
#define TITANOX_FEATURES_WALLS_H

#include "core/types.h"

#define TNX_MAP_BASE_OFF 0x28ULL

extern uint8_t g_grid[TNX_GRID_MAX * TNX_GRID_MAX];
extern uintptr_t g_tiles;
extern int g_w;
extern int g_h;
extern int g_cells;
extern int g_solid;
extern int g_move;
extern int g_img;
extern int g_own_tx;
extern int g_own_ty;
extern int g_own_proj;
extern int g_own_move;
extern int g_passes;
extern int g_armed;
extern int g_live;
extern int g_fail;
extern int g_seg_test;
extern int g_seg_clip;
extern int g_seg_frac;
extern int g_logs_10;
extern uint64_t g_built;

uintptr_t tnx_map_object(void);
int tnx_clip_walk(int32_t ax, int32_t ay, int32_t bx, int32_t by, int32_t cell, const uint8_t *solid, int gw, int gh, int32_t *outX, int32_t *outY);
void tnx_log_grid(int force);
int tnx_cell(int tx, int ty, int *proj, int *move);
void tnx_tile_of(float x, float y, int *tx, int *ty);
int tnx_build_2(void);
float tnx_clip_range(float ax, float ay, float dx, float dy, float rem);
void tnx_arm(float ownX, float ownY);

#endif
