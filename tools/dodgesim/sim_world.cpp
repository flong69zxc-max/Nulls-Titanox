#include "build/src/recoil.h"

sim_world_t g_sim;

uintptr_t rcl_base = 0x104000000UL;
uintptr_t rcl_players_object = 0;
uintptr_t rcl_objvote_best_owner = 0;
int rcl_objvote_best_teamcount = 0;
int rcl_objvote_max_votes = 0;
int rcl_trail_best = -1;
int rcl_trail_count = 0;
int rcl_no_source_passes = 0;
uint64_t rcl_walk_tick = 0;
int rcl_walk_count = 0;
rcl_trail_t rcl_trail[8];
uintptr_t rcl_own_elem_2 = 0;
uint64_t rcl_ticks_a = 0;
uint64_t rcl_ticks_b = 0;
uintptr_t rcl_manager_ptr = 0;
uintptr_t rcl_own_elem = SIM_ELEM;
int rcl_own_team_a = -1;
int rcl_own_team_b = -1;
int rcl_own_team_seen = 0;
int rcl_team_off = 0x40;
int rcl_mate_n = 0;
int32_t rcl_mate_x[8];
int32_t rcl_mate_y[8];
int rcl_proj_death_n = 0;
int rcl_own_logged = 0;

int rcl_probe_done = 0;
int rcl_hop_chosen = 0;
uint64_t rcl_probe_last_ms = 0;
uintptr_t rcl_probe_object = 0;
uintptr_t rcl_tick_object = 0;
uintptr_t rcl_scene_object = 0;
rcl_proj_death_t rcl_proj_deaths[16];
rcl_proj_t rcl_projs[16];
int rcl_coord_ok = 0;
int rcl_coord_usable = 0;

double CFAbsoluteTimeGetCurrent(void)
{
    return g_sim.nowMs / 1000.0;
}

void sim_reset(void)
{
    memset(&g_sim, 0, sizeof(g_sim));
    g_sim.mapW = 40;
    g_sim.mapH = 40;
    g_sim.myX = 4000.0f;
    g_sim.myY = 4000.0f;
    memset(rcl_projs, 0, sizeof(rcl_projs));
    memset(rcl_proj_deaths, 0, sizeof(rcl_proj_deaths));
    rcl_proj_death_n = 0;
    rcl_mate_n = 0;
    rcl_own_elem = SIM_ELEM;
    rcl_own_team_a = -1;
    rcl_own_team_b = -1;
    rcl_own_team_seen = 0;
}

void sim_set_own(float x, float y)
{
    g_sim.myX = x;
    g_sim.myY = y;
}

void sim_set_teams(int ownTeam, int teamSeen)
{
    rcl_own_team_b = ownTeam;
    rcl_own_team_a = teamSeen ? ownTeam : -1;
    rcl_own_team_seen = teamSeen;
}

void sim_add_mate(float x, float y)
{
    if (rcl_mate_n >= 8)
    {
        return;
    }
    rcl_mate_x[rcl_mate_n] = (int32_t)x;
    rcl_mate_y[rcl_mate_n] = (int32_t)y;
    rcl_mate_n++;
}

void sim_clear_projs(void)
{
    memset(rcl_projs, 0, sizeof(rcl_projs));
}

void sim_clear_walls(void)
{
    g_sim.wallN = 0;
}

void sim_add_wall(float x, float y, float r)
{
    if (g_sim.wallN >= SIM_WALL_MAX)
    {
        return;
    }
    g_sim.walls[g_sim.wallN].x = x;
    g_sim.walls[g_sim.wallN].y = y;
    g_sim.walls[g_sim.wallN].r = r;
    g_sim.walls[g_sim.wallN].enabled = 1;
    g_sim.wallN++;
}

int sim_add_proj(const char *name, int team, float x, float y, float vx, float vy, float radius)
{
    int i;
    for (i = 0; i < 16; i++)
    {
        rcl_proj_t *p = &rcl_projs[i];
        if (p->elem)
        {
            continue;
        }
        memset(p, 0, sizeof(*p));
        p->elem = SIM_ELEM + 0x1000 + (uintptr_t)i;
        p->name = name;
        p->team = team;
        p->x = (int32_t)x;
        p->y = (int32_t)y;
        p->spawnX = (int32_t)x;
        p->spawnY = (int32_t)y;
        p->ownerX = (int32_t)x;
        p->ownerY = (int32_t)y;
        p->radius = radius;
        p->vx = vx;
        p->vy = vy;
        p->pms = (uint64_t)g_sim.nowMs;
        p->qms = (uint64_t)g_sim.nowMs;
        p->hasPrev = 0;
        return 1;
    }
    return 0;
}

BOOL rcl_read_int(uintptr_t address, int32_t *out)
{
    if (!out)
    {
        return 0;
    }
    if (address == SIM_DEF + (uintptr_t)OFF_CHARDATA_SPEED)
    {
        *out = SIM_CHAR_SPEED;
        return 1;
    }
    if (address == SIM_CTRL + (uintptr_t)RCL_CTRL_RAW_X_OFF)
    {
        *out = (int32_t)g_sim.rawX;
        return 1;
    }
    if (address == SIM_CTRL + (uintptr_t)RCL_CTRL_RAW_Y_OFF)
    {
        *out = (int32_t)g_sim.rawY;
        return 1;
    }
    return 0;
}

BOOL rcl_read_float(uintptr_t address, float *out)
{
    if (!out)
    {
        return 0;
    }
    if (address == SIM_CTRL + (uintptr_t)RCL_CTRL_RAW_X_OFF)
    {
        *out = g_sim.rawX;
        return 1;
    }
    if (address == SIM_CTRL + (uintptr_t)RCL_CTRL_RAW_Y_OFF)
    {
        *out = g_sim.rawY;
        return 1;
    }
    return 0;
}

BOOL rcl_read_ptr(uintptr_t address, void **out)
{
    if (!out)
    {
        return 0;
    }
    if (address == SIM_ELEM + (uintptr_t)RCL_ELEM_DEF_OFF)
    {
        *out = (void *)SIM_DEF;
        return 1;
    }
    return 0;
}

uintptr_t rcl_controller(void)
{
    return SIM_CTRL;
}

int rcl_move_to(int32_t x, int32_t y, float ox, float oy)
{
    (void)ox;
    (void)oy;
    g_sim.prevTx = g_sim.lastTx;
    g_sim.prevTy = g_sim.lastTy;
    g_sim.lastTx = (float)x;
    g_sim.lastTy = (float)y;
    g_sim.moveCalls++;
    g_sim.enqueueCalls++;
    return 1;
}

int rcl_enqueue(int x, int y)
{
    (void)x;
    (void)y;
    return 1;
}

int rcl_wall_cache_w(void)
{
    return g_sim.mapW;
}

int rcl_wall_cache_h(void)
{
    return g_sim.mapH;
}

int rcl_wall_is_blocked_wide(float x, float y, float r, int mask)
{
    int i;
    (void)mask;
    for (i = 0; i < g_sim.wallN; i++)
    {
        const sim_wall_t *w = &g_sim.walls[i];
        float dx;
        float dy;
        if (!w->enabled)
        {
            continue;
        }
        dx = x - w->x;
        dy = y - w->y;
        if (dx * dx + dy * dy <= (w->r + r) * (w->r + r))
        {
            return 1;
        }
    }
    return 0;
}

int rcl_wall_los(float ax, float ay, float bx, float by, int mask)
{
    int i;
    for (i = 1; i < 8; i++)
    {
        float t = (float)i / 8.0f;
        float x = ax + (bx - ax) * t;
        float y = ay + (by - ay) * t;
        if (rcl_wall_is_blocked_wide(x, y, 0.0f, mask))
        {
            return 0;
        }
    }
    return 1;
}


void sim_tick(double dtMs)
{
    int i;
    for (i = 0; i < 16; i++)
    {
        rcl_proj_t *p = &rcl_projs[i];
        if (!p->elem)
        {
            continue;
        }
        if (p->vx != 0.0f || p->vy != 0.0f)
        {
            p->px = p->x;
            p->py = p->y;
            p->pms = p->qms;
            p->qms = (uint64_t)g_sim.nowMs;
            p->hasPrev = 1;
            p->x = (int32_t)((float)p->x + p->vx * (float)dtMs / 1000.0f);
            p->y = (int32_t)((float)p->y + p->vy * (float)dtMs / 1000.0f);
        }
        if (p->x < -1000 || p->y < -1000 || p->x > 40000 || p->y > 40000)
        {
            p->elem = 0;
        }
    }
    g_sim.nowMs += dtMs;
    g_sim.moveCalls = 0;
    g_sim.enqueueCalls = 0;
}

BOOL rcl_addr_readable(uintptr_t address, size_t length)
{
    (void)length;
    return address ? 1 : 0;
}

BOOL rcl_pointer_plausible(uintptr_t address)
{
    return address ? 1 : 0;
}

BOOL rcl_region_flags(uintptr_t address, vm_prot_t *flags)
{
    (void)address;
    if (flags)
    {
        *flags = 3;
    }
    return 1;
}


uintptr_t rcl_tiles = 0;
int rcl_tile_w = 0;
int rcl_tile_h = 0;

int32_t rcl_enemy_x[12];
int32_t rcl_enemy_y[12];
int rcl_enemy_n = 0;

float rcl_wall_trace(float x, float y, float dx, float dy, float max_dist, int mask)
{
    int i;
    int steps = 16;
    for (i = 1; i <= steps; i++)
    {
        float t = max_dist * (float)i / (float)steps;
        if (rcl_wall_is_blocked_wide(x + dx * t, y + dy * t, 0.0f, mask))
        {
            return t;
        }
    }
    return max_dist;
}
