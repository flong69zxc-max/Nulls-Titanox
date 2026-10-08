#ifndef RECOIL_UTILS_WALLS_H
#define RECOIL_UTILS_WALLS_H

#include "../core/offsets.h"

extern uintptr_t rcl_tiles;
extern int rcl_w;
extern int rcl_h;

uintptr_t rcl_map_object(void);
int rcl_cell(int tx, int ty, int *proj, int *move);
void rcl_tile_of(float x, float y, int *tx, int *ty);

#endif
