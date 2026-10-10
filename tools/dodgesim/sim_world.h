#ifndef SIM_WORLD_H
#define SIM_WORLD_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define SIM_CTRL 0x100000UL
#define SIM_DEF 0x200000UL
#define SIM_ELEM 0x300000UL
#define SIM_CHAR_SPEED 720
#define SIM_WALL_MAX 16

typedef struct
{
    float x;
    float y;
    float r;
    int enabled;
} sim_wall_t;

typedef struct
{
    double nowMs;
    float myX;
    float myY;
    float rawX;
    float rawY;
    int mapW;
    int mapH;
    int wallN;
    sim_wall_t walls[SIM_WALL_MAX];
    int moveCalls;
    int enqueueCalls;
    float lastTx;
    float lastTy;
    float prevTx;
    float prevTy;
    int dodgeTicks;
    int coastTicks;
    float cornerDist;
} sim_world_t;

extern sim_world_t g_sim;

void sim_reset(void);
void sim_set_own(float x, float y);
void sim_set_teams(int ownTeam, int teamSeen);
void sim_add_mate(float x, float y);
void sim_clear_projs(void);
void sim_clear_walls(void);
void sim_add_wall(float x, float y, float r);
int sim_add_proj(const char *name, int team, float x, float y, float vx, float vy, float radius);
void sim_tick(double dtMs);

#endif

BOOL rcl_addr_readable(uintptr_t address, size_t length);
BOOL rcl_pointer_plausible(uintptr_t address);
BOOL rcl_region_flags(uintptr_t address, vm_prot_t *flags);
int rcl_ok(float v, float lo, float hi);
