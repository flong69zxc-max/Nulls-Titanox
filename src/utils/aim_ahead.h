#ifndef RECOIL_UTILS_AIM_AHEAD_H
#define RECOIL_UTILS_AIM_AHEAD_H

#include "../core/offsets.h"
#include "./brawlers.h"
#include <stdint.h>

/* 1 tile, same scale as RCL_WALL_TILE_SIZE. */
#define RCL_AIM_AHEAD_TILE 300

/* Nominal enemy move speed the ahead10 column was computed against, units/s. */
#define RCL_AIM_AHEAD_ENEMY_SPEED 750

/* How the main attack delivers its damage at range. */
#define RCL_AIM_AHEAD_LOBBED 0x01 /* indirect arc shot: shotSpeed is not a horizontal velocity */
#define RCL_AIM_AHEAD_BEAM 0x02   /* hitscan, lands the same tick (above RCL_AIM_SHOT_SPEED_MAX) */
#define RCL_AIM_AHEAD_MELEE 0x04  /* no main-attack projectile at all */

/* Median of the direct-fire rows, tenths of a tile. */
#define RCL_AIM_AHEAD_DEFAULT 17

typedef struct
{
    const char *code;
    int16_t shotSpeed; /* main-attack projectile speed, units/s; 0 = melee or unknown */
    int16_t range;     /* main-attack range, units; 0 = unknown */
    int16_t flightMs;  /* flight time to that range, ms; 0 = unknown */
    int16_t ahead10;   /* tiles to aim ahead at max range, x10; 0 = none needed */
    uint8_t flags;     /* RCL_AIM_AHEAD_* */
} rcl_aim_ahead_t;

/* Looks a brawler up by any name rcl_brawler_canon accepts. NULL if unknown. */
const rcl_aim_ahead_t *rcl_aim_ahead_of(const char *name);

/* ahead10 for a brawler, or RCL_AIM_AHEAD_DEFAULT when unknown. */
int rcl_aim_ahead_tiles10(const char *name);

/* Measured main-attack projectile speed, or 0 when unknown/melee. */
int rcl_aim_ahead_speed(const char *name);

/* Looks a row up from a live projectile class name (rcl_proj_t::name). NULL if the
   projectile is not a brawler's main attack. */
const rcl_aim_ahead_t *rcl_aim_ahead_by_projectile(const char *projName);

#endif
