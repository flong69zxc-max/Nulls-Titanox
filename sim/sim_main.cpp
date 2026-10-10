#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <ctime>
#include <string>
#include <vector>
#include <algorithm>

#include "../src/recoil.h"
#include "../src/features/autododge.mm"
#include "../src/helpers/dodge_kinds.mm"
#include "../src/helpers/dodge_profiles.mm"

#define SIM_W 25
#define SIM_H 25
#define SIM_BLOCK ((uint8_t)(RCL_WALL_BLOCKS_MOVEMENT | RCL_WALL_BLOCKS_PROJECTILES))
#define SIM_TICK_MS 16.6667
#define SIM_DT 0.0166667f
#define SIM_CH_SPEED 720.0f

static uint8_t g_grid[SIM_W * SIM_H];
static uint64_t g_now_ms = 0;

extern "C" double CFAbsoluteTimeGetCurrent(void)
{
    return (double)g_now_ms / 1000.0;
}

static uint8_t sim_cell(int tx, int ty)
{
    if (tx < 0 || ty < 0 || tx >= SIM_W || ty >= SIM_H)
    {
        return SIM_BLOCK;
    }
    return g_grid[ty * SIM_W + tx];
}

int rcl_wall_cache_w(void)
{
    return SIM_W;
}

int rcl_wall_cache_h(void)
{
    return SIM_H;
}

int rcl_wall_is_blocked_at(float x, float y, int mask)
{
    return (sim_cell((int)floorf(x / RCL_WALL_TILE_SIZE), (int)floorf(y / RCL_WALL_TILE_SIZE)) & mask) ? 1 : 0;
}

int rcl_wall_is_blocked_wide(float x, float y, float r, int mask)
{
    if (rcl_wall_is_blocked_at(x, y, mask))
    {
        return 1;
    }
    if (rcl_wall_is_blocked_at(x + r, y, mask) || rcl_wall_is_blocked_at(x - r, y, mask))
    {
        return 1;
    }
    if (rcl_wall_is_blocked_at(x, y + r, mask) || rcl_wall_is_blocked_at(x, y - r, mask))
    {
        return 1;
    }
    return 0;
}

int rcl_wall_los(float ax, float ay, float bx, float by, int mask)
{
    int cx = (int)floorf(ax / RCL_WALL_TILE_SIZE);
    int cy = (int)floorf(ay / RCL_WALL_TILE_SIZE);
    int tx = (int)floorf(bx / RCL_WALL_TILE_SIZE);
    int ty = (int)floorf(by / RCL_WALL_TILE_SIZE);
    int dx;
    int dy;
    int sx;
    int sy;
    int err;
    int steps;
    int n;
    if (cx == tx && cy == ty)
    {
        return 1;
    }
    dx = tx - cx;
    if (dx < 0)
    {
        dx = -dx;
    }
    dy = ty - cy;
    if (dy < 0)
    {
        dy = -dy;
    }
    dy = -dy;
    sx = cx < tx ? 1 : -1;
    sy = cy < ty ? 1 : -1;
    err = dx + dy;
    steps = dx - dy + 2;
    for (n = 0; n < steps; n++)
    {
        int e2 = 2 * err;
        if (e2 >= dy)
        {
            err += dy;
            cx += sx;
        }
        if (e2 <= dx)
        {
            err += dx;
            cy += sy;
        }
        if (cx == tx && cy == ty)
        {
            return 1;
        }
        if (sim_cell(cx, cy) & mask)
        {
            return 0;
        }
    }
    return 1;
}

float rcl_wall_trace(float x, float y, float dx, float dy, float max_dist, int mask)
{
    float dist = 0.0f;
    if (max_dist <= 0.0f)
    {
        return max_dist;
    }
    while (dist < max_dist)
    {
        int tx;
        int ty;
        dist += RCL_WALL_TRACE_STEP;
        if (dist > max_dist)
        {
            dist = max_dist;
        }
        tx = (int)floorf((x + dx * dist) / RCL_WALL_TILE_SIZE);
        ty = (int)floorf((y + dy * dist) / RCL_WALL_TILE_SIZE);
        if (tx < 0 || tx >= SIM_W || ty < 0 || ty >= SIM_H)
        {
            float hit = dist - RCL_WALL_TRACE_BACKOFF;
            return hit > 0.0f ? hit : 0.0f;
        }
        if (sim_cell(tx, ty) & mask)
        {
            float hit = dist - RCL_WALL_TRACE_BACKOFF;
            return hit > 0.0f ? hit : 0.0f;
        }
    }
    return max_dist;
}

int rcl_wall_build(void)
{
    return 1;
}

int rcl_wall_maybe_refresh(uint64_t now_ms)
{
    (void)now_ms;
    return 1;
}

void rcl_wall_notify_battle_mode_changed(uint64_t now_ms)
{
    (void)now_ms;
}

BOOL rcl_read_float(uintptr_t address, float *out)
{
    (void)address;
    if (out)
    {
        *out = 0.0f;
    }
    return 0;
}

BOOL rcl_read_int(uintptr_t address, int32_t *out)
{
    (void)address;
    if (out)
    {
        *out = 0;
    }
    return 0;
}

BOOL rcl_read_ptr(uintptr_t address, void **out)
{
    (void)address;
    if (out)
    {
        *out = nullptr;
    }
    return 0;
}

BOOL rcl_read_bytes(uintptr_t address, void *out, size_t n)
{
    (void)address;
    if (out)
    {
        memset(out, 0, n);
    }
    return 0;
}

BOOL rcl_write_bytes(uintptr_t address, const void *in, size_t n)
{
    (void)address;
    (void)in;
    (void)n;
    return 0;
}

BOOL rcl_addr_writable(uintptr_t address, size_t n)
{
    (void)address;
    (void)n;
    return 0;
}

uintptr_t rcl_entry_2(uintptr_t rva)
{
    (void)rva;
    return 0;
}

uintptr_t rcl_hop(uintptr_t base, int *whyOut)
{
    (void)base;
    if (whyOut)
    {
        *whyOut = 0;
    }
    return 0;
}

uintptr_t rcl_controller(void)
{
    return 0;
}

void *rcl_manager(void)
{
    return 0;
}

uintptr_t rcl_move_carrier(void)
{
    return 0;
}

int rcl_move_pair_ok(uintptr_t own, const void *a, const void *b)
{
    (void)own;
    (void)a;
    (void)b;
    return 0;
}

int rcl_ctrl_bounds(uintptr_t ctrl, void *a, void *b)
{
    (void)ctrl;
    (void)a;
    (void)b;
    return 0;
}

uintptr_t rcl_own_radius_holder(void);

int rcl_pred_set(int x, int y)
{
    (void)x;
    (void)y;
    return 1;
}

static float g_cmd_x = 0.0f;
static float g_cmd_y = 0.0f;
static int g_cmd_n = 0;
static float g_cmd_age_s = 0.0f;

int rcl_move_to(int32_t x, int32_t y, float ox, float oy)
{
    (void)ox;
    (void)oy;
    g_cmd_x = (float)x;
    g_cmd_y = (float)y;
    g_cmd_n++;
    return 1;
}

int rcl_enqueue(int x, int y)
{
    (void)x;
    (void)y;
    return 1;
}

int rcl_enqueue_type(int x, int y, int type)
{
    (void)x;
    (void)y;
    (void)type;
    return 1;
}

int rcl_enqueue_skill(int x, int y, int type, void *skillData)
{
    (void)x;
    (void)y;
    (void)type;
    (void)skillData;
    return 1;
}

void rcl_probe(uintptr_t manager, uintptr_t scene, int loud)
{
    (void)manager;
    (void)scene;
    (void)loud;
}

void rcl_paircal(void)
{
}

void rcl_alive(int32_t x, int32_t y)
{
    (void)x;
    (void)y;
}

int rcl_life(uintptr_t object, int32_t x, int32_t y)
{
    (void)object;
    (void)x;
    (void)y;
    return 0;
}

void rcl_death_signals(uintptr_t object, int32_t x, int32_t y)
{
    (void)object;
    (void)x;
    (void)y;
}

void rcl_roster(uintptr_t element, int index, int team, const rcl_obj_t *objects, int usable)
{
    (void)element;
    (void)index;
    (void)team;
    (void)objects;
    (void)usable;
}

int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut)
{
    (void)objects;
    (void)usable;
    (void)indexOut;
    (void)fromOut;
    return 0;
}

int rcl_resolve_own_2(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut)
{
    (void)objects;
    (void)usable;
    (void)indexOut;
    (void)fromOut;
    return 0;
}

void rcl_publish_own(uintptr_t elem, const char *from)
{
    (void)elem;
    (void)from;
}

int rcl_proj_scan(uintptr_t manager, int32_t count)
{
    (void)manager;
    (void)count;
    return 1;
}

int rcl_collect(uintptr_t manager, rcl_obj_t *out, int capacity)
{
    (void)manager;
    (void)out;
    (void)capacity;
    return 0;
}

void rcl_discriminate(uintptr_t manager)
{
    (void)manager;
}


uintptr_t rcl_base = 1;
uintptr_t rcl_players_object = 0;
uintptr_t rcl_scene_object = 0;
uintptr_t rcl_tick_object = 0;
uintptr_t rcl_probe_object = 0;
int rcl_probe_done = 0;
uint64_t rcl_probe_last_ms = 0;
uintptr_t rcl_manager_ptr = 0;
uintptr_t rcl_objvote_best_owner = 0;
int rcl_objvote_best_teamcount = 0;
int rcl_objvote_max_votes = 0;
int rcl_trail_best = -1;
int rcl_trail_count = 0;
rcl_trail_t rcl_trail[8];
int rcl_coord_ok = 0;
int rcl_coord_usable = 0;
int rcl_hop_chosen = 0;
int rcl_no_source_passes = 0;
int rcl_team_off = 0;
uint64_t rcl_ticks_a = 0;
uint64_t rcl_ticks_b = 0;
uint64_t rcl_walk_tick = 0;
int rcl_walk_count = 0;
int rcl_dead = 0;
uintptr_t rcl_own_elem = 0x1000;
uintptr_t rcl_own_elem_2 = 0x1000;
uintptr_t rcl_pub_object = 0;
int32_t rcl_pub_count = 0;
int rcl_own_logged = 0;
int rcl_own_team_seen = 1;
int rcl_own_team_a = 0;
int rcl_own_team_b = -1;
int rcl_mate_n = 0;
int32_t rcl_mate_x[8];
int32_t rcl_mate_y[8];
rcl_proj_t rcl_projs[16];
rcl_proj_death_t rcl_proj_deaths[16];
int rcl_proj_death_n = 0;

int rcl_own_scan(void)
{
    return 0;
}

int rcl_own_latch(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut)
{
    (void)objects;
    (void)usable;
    (void)indexOut;
    (void)fromOut;
    return 0;
}

BOOL rcl_query_region(uintptr_t address, vm_prot_t *protection, vm_prot_t *maxProtection, mach_vm_size_t *regionSize,
                      mach_vm_address_t *regionBase)
{
    if (protection)
    {
        *protection = VM_PROT_READ | VM_PROT_WRITE;
    }
    if (maxProtection)
    {
        *maxProtection = VM_PROT_READ | VM_PROT_WRITE;
    }
    if (regionSize)
    {
        *regionSize = 0x100000000ull;
    }
    if (regionBase)
    {
        *regionBase = (mach_vm_address_t)address;
    }
    return YES;
}

uintptr_t rcl_entry_lookup(uintptr_t rva)
{
    (void)rva;
    return 0;
}

extern "C" mach_port_t mach_task_self(void)
{
    return 1;
}

extern "C" kern_return_t mach_port_deallocate(mach_port_t task, mach_port_t name)
{
    (void)task;
    (void)name;
    return KERN_SUCCESS;
}

extern "C" kern_return_t vm_region_64(mach_port_t task, vm_address_t *address, vm_size_t *size, int flavor,
                                      vm_region_info_t info, mach_msg_type_number_t *count, mach_port_t *object_name)
{
    (void)task;
    (void)flavor;
    (void)info;
    (void)count;
    if (address)
    {
        *address = (vm_address_t)(*address);
    }
    if (size)
    {
        *size = 0x100000000ull;
    }
    if (object_name)
    {
        *object_name = 0;
    }
    return KERN_SUCCESS;
}

extern "C" kern_return_t vm_read_overwrite(mach_port_t task, vm_address_t address, vm_size_t size, vm_address_t data,
                                           vm_size_t *out_size)
{
    (void)task;
    (void)address;
    (void)size;
    (void)data;
    if (out_size)
    {
        *out_size = 0;
    }
    return KERN_INVALID_ADDRESS;
}

extern "C" uint64_t mach_absolute_time(void)
{
    return g_now_ms * 1000000ull;
}

extern "C" int mach_timebase_info(mach_timebase_info_t info)
{
    (void)info;
    return 0;
}

static uint32_t rng_state = 1u;

static uint32_t rng_next(void)
{
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

static float rng_unit(void)
{
    return (float)(rng_next() & 0xFFFFFFu) / (float)0xFFFFFF;
}

static float rng_range(float lo, float hi)
{
    return lo + (hi - lo) * rng_unit();
}

#define SIM_MAX_CH 20
#define SIM_MAX_PRJ 256
#define SIM_SUB 0.004f
#define SIM_AIM_HORIZON 1.8f
#define SIM_AWARE 3200.0f

static const char *SIM_KINDS[5] = {"ElectroSniperProjectile", "CactusProjectile", "AlternatorDamageProjectile",
                                   "ElectroSniperProjectile", "CactusProjectile"};
static const float SIM_KIND_SPEED[5] = {2400.0f, 3000.0f, 2200.0f, 3200.0f, 2000.0f};
static const float SIM_KIND_RAD[5] = {80.0f, 70.0f, 90.0f, 60.0f, 70.0f};

struct SimChar
{
    float x;
    float y;
    int team;
    float rad;
    const char *kind;
    float range;
    float pspeed;
    float prad;
    float cadence;
    float cool;
};

struct SimProj
{
    int alive;
    float x;
    float y;
    float vx;
    float vy;
    int team;
    const char *kind;
    float rad;
    float born_ms;
    float sx;
    float sy;
    float travelled;
};

struct SimMetrics
{
    long hits;
    long ticks;
    long cmdTicks;
    long wallTicks;
    long jerks;
    long noInc;
    long mateFalse;
    long towardEnemy;
    long staleWalk;
    long staleToward;
    long stopCmd;
    long fired;
    long aimedTicks;
    double maxTurn;
    double path;
    double minEnemyDist;
    double avgEnemyDist;
    double cpuUs;
};

static SimChar g_ch[SIM_MAX_CH];
static int g_ch_n = 0;
static SimProj g_prj[SIM_MAX_PRJ];
static unsigned g_atk_n = 0;
static long g_fired = 0;

static void map_build(int seed)
{
    uint32_t s = (uint32_t)(seed * 2654435761u + 1u);
    memset(g_grid, 0, sizeof(g_grid));
    rng_state = (uint32_t)(seed * 2246822519u + 7u);
    for (int gy = 2; gy + 2 < SIM_H; gy += 5)
    {
        for (int gx = 2; gx + 2 < SIM_W; gx += 5)
        {
            s = s * 1103515245u + 12345u;
            int pick = (int)((s >> 15) & 7u);
            int bw = (pick & 1) ? 2 : 1;
            int bh = (pick & 2) ? 2 : 1;
            if (pick == 0)
            {
                continue;
            }
            if (gx + bw >= SIM_W || gy + bh >= SIM_H)
            {
                continue;
            }
            for (int y = gy; y < gy + bh; y++)
            {
                for (int x = gx; x < gx + bw; x++)
                {
                    g_grid[y * SIM_W + x] = SIM_BLOCK;
                }
            }
        }
    }
    for (int i = 0; i < SIM_W; i++)
    {
        g_grid[i] = SIM_BLOCK;
        g_grid[(SIM_H - 1) * SIM_W + i] = SIM_BLOCK;
        g_grid[i * SIM_W] = SIM_BLOCK;
        g_grid[i * SIM_W + SIM_W - 1] = SIM_BLOCK;
    }
}

static int free_spot(float *x, float *y)
{
    int tries;
    for (tries = 0; tries < 400; tries++)
    {
        float tx = rng_range(2.0f * RCL_WALL_TILE_SIZE, (float)(SIM_W - 2) * RCL_WALL_TILE_SIZE);
        float ty = rng_range(2.0f * RCL_WALL_TILE_SIZE, (float)(SIM_H - 2) * RCL_WALL_TILE_SIZE);
        if (!rcl_wall_is_blocked_at(tx, ty, RCL_WALL_BLOCKS_MOVEMENT))
        {
            *x = tx;
            *y = ty;
            return 1;
        }
    }
    return 0;
}

static float dist2(float ax, float ay, float bx, float by)
{
    float dx = ax - bx;
    float dy = ay - by;
    return dx * dx + dy * dy;
}

static int seg_hit(float ax, float ay, float bx, float by, float cx, float cy, float r)
{
    float dx = bx - ax;
    float dy = by - ay;
    float fx = ax - cx;
    float fy = ay - cy;
    float a = dx * dx + dy * dy;
    float t = 0.0f;
    float px;
    float py;
    if (a > 1e-6f)
    {
        t = -(fx * dx + fy * dy) / a;
        if (t < 0.0f)
        {
            t = 0.0f;
        }
        if (t > 1.0f)
        {
            t = 1.0f;
        }
    }
    px = fx + dx * t;
    py = fy + dy * t;
    return (px * px + py * py) <= r * r;
}

static int proj_aims_at(const SimProj *p, float cx, float cy, float r)
{
    float t = SIM_AIM_HORIZON;
    float ex;
    float ey;
    if (!p->alive)
    {
        return 0;
    }
    ex = p->x + p->vx * t;
    ey = p->y + p->vy * t;
    if (!rcl_wall_los(p->x, p->y, ex, ey, RCL_WALL_BLOCKS_PROJECTILES))
    {
        return 0;
    }
    return seg_hit(p->x, p->y, ex, ey, cx, cy, r + p->rad);
}

static void spawn_proj(int team, float x, float y, float vx, float vy, int kindIdx, float rad)
{
    int i;
    for (i = 0; i < SIM_MAX_PRJ; i++)
    {
        if (!g_prj[i].alive)
        {
            g_prj[i].alive = 1;
            g_prj[i].x = x;
            g_prj[i].y = y;
            g_prj[i].vx = vx;
            g_prj[i].vy = vy;
            g_prj[i].team = team;
            g_prj[i].kind = SIM_KINDS[kindIdx];
            g_prj[i].rad = rad;
            g_prj[i].born_ms = (float)g_now_ms;
            g_prj[i].sx = x;
            g_prj[i].sy = y;
            g_prj[i].travelled = 0.0f;
            g_atk_n++;
            g_fired++;
            return;
        }
    }
}

static void move_char(SimChar *c, float dx, float dy, float step)
{
    float nx = c->x + dx * step;
    float ny = c->y + dy * step;
    if (!rcl_wall_is_blocked_wide(nx, ny, c->rad, RCL_WALL_BLOCKS_MOVEMENT))
    {
        c->x = nx;
        c->y = ny;
    }
}

static void ai_step(SimChar *c, float tx, float ty, float lo, float hi, float dt)
{
    float dx = tx - c->x;
    float dy = ty - c->y;
    float d = sqrtf(dx * dx + dy * dy);
    float ux;
    float uy;
    float want;
    float sx;
    float sy;
    float mx;
    float my;
    float mlen;
    int k;
    if (d < 1.0f)
    {
        return;
    }
    ux = dx / d;
    uy = dy / d;
    want = 0.0f;
    if (d > hi)
    {
        want = 1.0f;
    }
    if (d < lo)
    {
        want = -1.0f;
    }
    sx = -uy;
    sy = ux;
    mx = ux * want + sx * rng_range(-0.7f, 0.7f);
    my = uy * want + sy * rng_range(-0.7f, 0.7f);
    mlen = sqrtf(mx * mx + my * my);
    if (mlen < 1e-4f)
    {
        return;
    }
    mx /= mlen;
    my /= mlen;
    for (k = 0; k < 8; k++)
    {
        float a = (float)k * 0.7853981634f;
        float cx = mx * cosf(a) - my * sinf(a);
        float cy = mx * sinf(a) + my * cosf(a);
        float nx = c->x + cx * SIM_CH_SPEED * dt;
        float ny = c->y + cy * SIM_CH_SPEED * dt;
        if (!rcl_wall_is_blocked_wide(nx, ny, c->rad, RCL_WALL_BLOCKS_MOVEMENT))
        {
            c->x = nx;
            c->y = ny;
            return;
        }
    }
}

static void dodge_reset(void)
{
    int i;
    rcl_bdc_have_last = 0;
    rcl_bdc_last_x = 0.0f;
    rcl_bdc_last_y = 0.0f;
    rcl_bdc_last_ms = 0;
    rcl_bdc_sel_n = 0;
    rcl_ad_hazard_n = 0;
    rcl_proj_death_n = 0;
    rcl_ticks_a = 0;
    rcl_ticks_b = 0;
    rcl_walk_tick = 0;
    rcl_walk_count = 0;
    rcl_bd_threat_n = 0;
    rcl_rad_off = -1;
    rcl_own_r = 60.0f;
    rcl_own_team_seen = 1;
    rcl_own_team_a = 0;
    rcl_own_team_b = -1;
    rcl_dead = 0;
    for (i = 0; i < 16; i++)
    {
        memset(&rcl_projs[i], 0, sizeof(rcl_projs[i]));
        rcl_projs[i].name = nullptr;
    }
    for (i = 0; i < SIM_MAX_PRJ; i++)
    {
        g_prj[i].alive = 0;
    }
    g_cmd_n = 0;
    g_fired = 0;
    g_cmd_x = 0.0f;
    g_cmd_y = 0.0f;
    g_cmd_age_s = 0.0f;
    g_now_ms = 0;
}


static void sim_explain(const rcl_proj_t *pp, float mx, float my, float myR)
{
    float bodyR = myR + RCL_AD_SKIN;
    float zoneSq = RCL_AD_AWARE * RCL_AD_AWARE;
    const rcl_kind_t *spec = rcl_kind_of(pp->name ? pp->name : "");
    float vx = pp->vx;
    float vy = pp->vy;
    float spd = sqrtf(vx * vx + vy * vy);
    float dx = (float)pp->x - mx;
    float dy = (float)pp->y - my;
    float shotR = rcl_ad_ball_radius(pp) + (spec ? (float)spec->growR : 0.0f);
    float left = rcl_ad_life_left(pp, spec, spd, g_now_ms);
    float gap = sqrtf(dx * dx + dy * dy) - bodyR - shotR;
    float along = 0.0f;
    int shaped;
    if (spd >= 1.0f)
    {
        along = (mx - (float)pp->x) * (vx / spd) + (my - (float)pp->y) * (vy / spd);
    }
    shaped = rcl_shape_hazards(pp, g_now_ms, rcl_ad_caps, RCL_AD_CAP_MAX);
    fprintf(stderr,
            "   EXPLAIN elem=%d readable=%d mine=%d crosses=%d shaped=%d blocksLinear=%d dist2=%.0f zone=%.0f spec=%d "
            "spd=%.0f left=%.0f gap=%.0f along=%.0f skip(pAlong>left+shotR)=%d\n",
            (int)(pp->elem != 0), rcl_addr_readable((uintptr_t)pp->name, 1), rcl_ad_is_mine(pp, mx, my),
            rcl_ad_crosses_me(pp, mx, my, bodyR), shaped, rcl_blocks_linear(pp->name ? pp->name : ""),
            dx * dx + dy * dy, zoneSq, spec ? 1 : 0, spd, left, gap, along, (along > left + shotR) ? 1 : 0);
}

static void feed_projs(void)
{
    int i;
    int n = 0;
    for (i = 0; i < 16; i++)
    {
        memset(&rcl_projs[i], 0, sizeof(rcl_projs[i]));
        rcl_projs[i].name = nullptr;
    }
    for (i = 0; i < SIM_MAX_PRJ && n < 16; i++)
    {
        rcl_proj_t *p;
        if (!g_prj[i].alive)
        {
            continue;
        }
        p = &rcl_projs[n];
        p->elem = (uintptr_t)(0x2000 + n);
        p->x = (int32_t)g_prj[i].x;
        p->y = (int32_t)g_prj[i].y;
        p->px = p->x;
        p->py = p->y;
        p->vx = g_prj[i].vx;
        p->vy = g_prj[i].vy;
        p->team = g_prj[i].team;
        p->name = g_prj[i].kind;
        p->radius = g_prj[i].rad;
        p->angle = atan2f(g_prj[i].vy, g_prj[i].vx);
        p->spawnedAt = (uint64_t)g_prj[i].born_ms;
        p->pms = g_now_ms;
        p->qms = g_now_ms;
        p->hasPrev = 1;
        p->spawnX = (int32_t)g_prj[i].sx;
        p->spawnY = (int32_t)g_prj[i].sy;
        p->ownerX = (int32_t)g_prj[i].sx;
        p->ownerY = (int32_t)g_prj[i].sy;
        p->gid = (int32_t)n;
        p->castRange = 2800;
        p->spawnAreaRadius = 0;
        p->spawnAreaActiveTime = 0;
        n++;
    }
}

static int place_away(float *x, float *y, float fromX, float fromY, float minD)
{
    int tries;
    for (tries = 0; tries < 400; tries++)
    {
        float tx;
        float ty;
        if (!free_spot(&tx, &ty))
        {
            return 0;
        }
        if (dist2(tx, ty, fromX, fromY) >= minD * minD)
        {
            *x = tx;
            *y = ty;
            return 1;
        }
    }
    return 0;
}

static void run_config(int nEnemies, int nMates, int mapSeed, int aiSeed, int ticks, SimMetrics *out)
{
    int i;
    int t;
    SimChar *me;
    float lastDirX = 0.0f;
    float lastDirY = 0.0f;
    int haveDir = 0;
    float minDist = 1.0e9f;
    double distSum = 0.0;
    SimMetrics m;
    memset(out, 0, sizeof(*out));
    memset(&m, 0, sizeof(m));
    map_build(mapSeed);
    rng_state = (uint32_t)(aiSeed * 1013904223u + mapSeed * 1664525u + 3u);
    g_ch_n = 0;
    if (!free_spot(&g_ch[0].x, &g_ch[0].y))
    {
        return;
    }
    g_ch[0].team = 0;
    g_ch[0].rad = 60.0f;
    g_ch[0].kind = "Hero";
    g_ch[0].range = 0.0f;
    g_ch[0].pspeed = 0.0f;
    g_ch[0].prad = 0.0f;
    g_ch[0].cadence = 0.0f;
    g_ch[0].cool = 0.0f;
    g_ch_n = 1;
    for (i = 0; i < nMates; i++)
    {
        SimChar *c = &g_ch[g_ch_n];
        if (!place_away(&c->x, &c->y, g_ch[0].x, g_ch[0].y, 500.0f))
        {
            continue;
        }
        c->team = 0;
        c->rad = 60.0f;
        c->kind = "Mate";
        c->range = 2600.0f;
        c->pspeed = SIM_KIND_SPEED[i % 5];
        c->prad = SIM_KIND_RAD[i % 5];
        c->cadence = rng_range(1.2f, 2.0f);
        c->cool = rng_range(0.0f, 1.0f);
        g_ch_n++;
    }
    for (i = 0; i < nEnemies; i++)
    {
        SimChar *c = &g_ch[g_ch_n];
        if (!place_away(&c->x, &c->y, g_ch[0].x, g_ch[0].y, 1200.0f))
        {
            continue;
        }
        c->team = 1;
        c->rad = 60.0f;
        c->kind = SIM_KINDS[i % 5];
        {
            const rcl_kind_t *ks = rcl_kind_of(c->kind);
            c->range = (ks && ks->maxRange > 0) ? (float)ks->maxRange : 2800.0f;
        }
        c->pspeed = SIM_KIND_SPEED[i % 5];
        c->prad = SIM_KIND_RAD[i % 5];
        c->cadence = rng_range(0.9f, 1.7f);
        c->cool = rng_range(0.2f, 0.9f);
        g_ch_n++;
    }
    me = &g_ch[0];
    dodge_reset();
    for (t = 0; t < ticks; t++)
    {
        int cmdBefore;
        int cmdNow;
        int aimed = 0;
        int mateNear = 0;
        float dirX = 0.0f;
        float dirY = 0.0f;
        float dlen = 0.0f;
        double turn = 0.0;
        struct timespec ta;
        struct timespec tb;
        float preX;
        float preY;
        g_now_ms = (uint64_t)llround((double)t * SIM_TICK_MS);
        rcl_ticks_b++;
        rcl_mate_n = 0;
        for (i = 1; i < g_ch_n && rcl_mate_n < 8; i++)
        {
            if (g_ch[i].team == 0)
            {
                rcl_mate_x[rcl_mate_n] = (int32_t)g_ch[i].x;
                rcl_mate_y[rcl_mate_n] = (int32_t)g_ch[i].y;
                rcl_mate_n++;
            }
        }
        for (i = 1; i < g_ch_n; i++)
        {
            SimChar *c = &g_ch[i];
            float tx = me->x;
            float ty = me->y;
            if (c->team == 0)
            {
                int e;
                float bestD = 1.0e9f;
                for (e = 0; e < g_ch_n; e++)
                {
                    float dd;
                    if (g_ch[e].team != 1)
                    {
                        continue;
                    }
                    dd = dist2(g_ch[e].x, g_ch[e].y, c->x, c->y);
                    if (dd < bestD)
                    {
                        bestD = dd;
                        tx = g_ch[e].x;
                        ty = g_ch[e].y;
                    }
                }
            }
            if (c->team == 1)
            {
                int losNow = rcl_wall_los(c->x, c->y, tx, ty, RCL_WALL_BLOCKS_PROJECTILES);
                ai_step(c, tx, ty, losNow ? 250.0f : 60.0f, losNow ? 700.0f : 200.0f, SIM_DT);
            }
            else
            {
                ai_step(c, g_ch[0].x + 900.0f, g_ch[0].y + 900.0f, 400.0f, 1200.0f, SIM_DT);
            }
            c->cool -= SIM_DT;
            if (c->cool <= 0.0f)
            {
                float dx = tx - c->x;
                float dy = ty - c->y;
                float d = sqrtf(dx * dx + dy * dy);
                int hasLos = rcl_wall_los(c->x, c->y, tx, ty, RCL_WALL_BLOCKS_PROJECTILES);
                if (d > 1.0f && d < c->range * 0.6f && d < 1400.0f && hasLos)
                {
                    float px = tx;
                    float py = ty;
                    float ax = px - c->x;
                    float ay = py - c->y;
                    float al = sqrtf(ax * ax + ay * ay);
                    if (al > 1.0f)
                    {
                        ax /= al;
                        ay /= al;
                    }
                    c->cool = c->cadence * rng_range(0.85f, 1.15f);
                    m.avgEnemyDist += 1.0;
                    spawn_proj(c->team, c->x + ax * 80.0f, c->y + ay * 80.0f, ax * c->pspeed, ay * c->pspeed,
                               (int)(i % 5), c->prad);
                }
                else
                {
                    c->cool = 0.15f;
                }
            }
        }
        cmdBefore = g_cmd_n;
        feed_projs();
        clock_gettime(CLOCK_MONOTONIC, &ta);
        rcl_ad_update(me->x, me->y);
        clock_gettime(CLOCK_MONOTONIC, &tb);
        m.cpuUs += (double)(tb.tv_sec - ta.tv_sec) * 1.0e6 + (double)(tb.tv_nsec - ta.tv_nsec) / 1.0e3;
        if (getenv("SIM_DEBUG"))
        {
            int k;
            int aliveN = 0;
            for (k = 0; k < SIM_MAX_PRJ; k++)
            {
                if (g_prj[k].alive)
                {
                    aliveN++;
                }
            }
            {
                float sox = 0.0f;
                float soy = 0.0f;
                float six = 0.0f;
                float siy = 0.0f;
                float myR = rcl_own_radius();
                int hy;
                int th;
                int sel;
                rcl_ad_collect(me->x, me->y, myR, g_now_ms);
                hy = rcl_ad_hazard_n;
                rcl_bd_build_threats();
                th = rcl_bd_threat_n;
                rcl_bd_intent(&six, &siy);
                rcl_bdc_pick(me->x, me->y, myR, six, siy, rcl_dodge_speed, &sox, &soy);
                sel = rcl_bdc_sel_n;
                {
                    const rcl_proj_t *qp = nullptr;
                    int ql;
                    float qspd = 0.0f;
                    float qalong = 0.0f;
                    float qleft = 0.0f;
                    float qshot = 0.0f;
                    float qdist = 0.0f;
                    int qlos = 0;
                    for (ql = 0; ql < 16; ql++)
                    {
                        if (rcl_projs[ql].elem)
                        {
                            qp = &rcl_projs[ql];
                            break;
                        }
                    }
                    if (qp)
                    {
                        const rcl_kind_t *qspec = rcl_kind_of(qp->name);
                        qspd = sqrtf(qp->vx * qp->vx + qp->vy * qp->vy);
                        qdist = sqrtf(dist2((float)qp->x, (float)qp->y, me->x, me->y));
                        if (qspd >= 1.0f)
                        {
                            qalong = (me->x - (float)qp->x) * (qp->vx / qspd) + (me->y - (float)qp->y) * (qp->vy / qspd);
                        }
                        qleft = rcl_ad_life_left(qp, qspec, qspd, g_now_ms);
                        qshot = rcl_ad_ball_radius(qp) + (qspec ? (float)qspec->growR : 0.0f);
                        qlos = rcl_wall_los((float)qp->x, (float)qp->y, (float)qp->x + qp->vx / (qspd + 1e-6f) * qalong,
                                            (float)qp->y + qp->vy / (qspd + 1e-6f) * qalong, RCL_WALL_BLOCKS_PROJECTILES);
                    }
                    if (qp)
                    {
                        sim_explain(qp, me->x, me->y, rcl_own_radius());
                    }
                    fprintf(stderr,
                            "   sync hazard=%d threat=%d sel=%d out=(%.3f,%.3f) mine=%d name=%s dist=%.0f spd=%.0f along=%.0f "
                            "left=%.0f shotR=%.0f los=%d elem=%d\n",
                            hy, th, sel, sox, soy, qp ? rcl_ad_is_mine(qp, me->x, me->y) : -1,
                            qp && qp->name ? qp->name : "(none)", qdist, qspd, qalong, qleft, qshot, qlos,
                            qp ? (int)qp->elem : 0);
                }
            }
            {
                static int dbgBudget = 0;
                if (dbgBudget < 500)
                {
                    dbgBudget++;
                }
                else
                {
                    aliveN = 0;
                }
            }
            if (aliveN > 0)
            {
                fprintf(stderr,
                        "t=%d alive=%d hazard_n=%d threat_n=%d sel_n=%d cmd_n=%d cmd=(%.0f,%.0f) me=(%.0f,%.0f)\n",
                        t, aliveN, rcl_ad_hazard_n, rcl_bd_threat_n, rcl_bdc_sel_n, g_cmd_n, g_cmd_x, g_cmd_y, me->x,
                        me->y);
                {
                    const rcl_proj_t *pp = nullptr;
                    int sl;
                    for (sl = 0; sl < 16; sl++)
                    {
                        if (rcl_projs[sl].elem)
                        {
                            pp = &rcl_projs[sl];
                            break;
                        }
                    }
                    if (!pp)
                    {
                        pp = &rcl_projs[0];
                    }
                    const rcl_kind_t *sp = rcl_kind_of(pp->name);
                    const rcl_fit_t *ft = rcl_fit_of(pp->name);
                    float spd = sqrtf(pp->vx * pp->vx + pp->vy * pp->vy);
                    float dx = (float)pp->x - me->x;
                    float dy = (float)pp->y - me->y;
                    float tHit = 0.0f;
                    rcl_bd_threat_t th;
                    float d2;
                    memset(&th, 0, sizeof(th));
                    th.x = (float)pp->x;
                    th.y = (float)pp->y;
                    th.vx = pp->vx;
                    th.vy = pp->vy;
                    th.rad = pp->radius;
                    th.hitr = pp->radius;
                    d2 = rcl_bd_impact_d2(&th, me->x, me->y, &tHit);
                    fprintf(stderr,
                            "   diag fired=%ld me_x=%.0f me_y=%.0f rcl_elem0=%d rcl_elem1=%d name=%s team=%d mine=%d elem=%d spec=%p maxRange=%d flags=%d fit=%p pad=%.2f grow=%.2f\n",
                            m.fired, me->x, me->y, (int)rcl_projs[0].elem, (int)rcl_projs[1].elem,
                            pp->name ? pp->name : "(null)", pp->team, rcl_ad_is_mine(pp, me->x, me->y),
                            (int)(pp->elem != 0), (const void *)sp, sp ? sp->maxRange : -1, sp ? sp->flags : -1,
                            (const void *)ft, ft ? ft->pad : -1.0f, ft ? ft->grow : -1.0f);
                    fprintf(stderr,
                            "   diag spd=%.0f dist2=%.0f zone2=%.0f traveled=%.0f reach=%.0f left=%.0f shotR=%.0f d2=%.0f aimed=%d shaped=%d\n",
                            spd, dx * dx + dy * dy, RCL_AD_AWARE * RCL_AD_AWARE, rcl_ad_traveled(pp),
                            rcl_ad_kind_reach(pp, sp, spd), rcl_ad_life_left(pp, sp, spd, g_now_ms),
                            rcl_ad_ball_radius(pp), d2, (d2 <= (me->rad + pp->radius) * (me->rad + pp->radius)),
                            rcl_shape_hazards(pp, g_now_ms, rcl_ad_caps, RCL_AD_CAP_MAX));
                }
            }
        }
        for (i = 0; i < SIM_MAX_PRJ; i++)
        {
            if (!g_prj[i].alive)
            {
                continue;
            }
            if (g_prj[i].team != 0)
            {
                if (proj_aims_at(&g_prj[i], me->x, me->y, me->rad))
                {
                    aimed = 1;
                }
            }
            else if (dist2(g_prj[i].x, g_prj[i].y, me->x, me->y) <= SIM_AWARE * SIM_AWARE)
            {
                mateNear = 1;
            }
        }
        preX = me->x;
        preY = me->y;
        cmdNow = 0;
        {
            SimChar *c = me;
            float dx = g_cmd_x - c->x;
            float dy = g_cmd_y - c->y;
            float d = sqrtf(dx * dx + dy * dy);
            if (g_cmd_n > 0 && d > 1.0f)
            {
                float step = SIM_CH_SPEED * SIM_DT;
                if (step > d)
                {
                    step = d;
                }
                move_char(c, dx / d, dy / d, step);
            }
        }
        {
            float dx = g_cmd_x - preX;
            float dy = g_cmd_y - preY;
            dlen = sqrtf(dx * dx + dy * dy);
        }
        if (g_cmd_n != cmdBefore)
        {
            cmdNow = 1;
        }
        if (cmdNow && dlen > 1.0f)
        {
            float dx = rcl_bdc_last_x;
            float dy = rcl_bdc_last_y;
            m.cmdTicks++;
            if (haveDir && (lastDirX != 0.0f || lastDirY != 0.0f))
            {
                float dot = dx * lastDirX + dy * lastDirY;
                if (dot > 1.0f)
                {
                    dot = 1.0f;
                }
                if (dot < -1.0f)
                {
                    dot = -1.0f;
                }
                turn = (double)acosf(dot) * 57.2957795;
                if (turn > m.maxTurn)
                {
                    m.maxTurn = turn;
                }
                if (turn > 40.0)
                {
                    static int jerkLog = 0;
                    m.jerks++;
                    if (getenv("SIM_JERK") && jerkLog < 8)
                    {
                        jerkLog++;
                        fprintf(stderr,
                                "TURN t=%d turn=%.1f prev=(%.3f,%.3f) new=(%.3f,%.3f) dodge_last=(%.3f,%.3f) target=(%.0f,%.0f) dlen=%.0f "
                                "threat_n=%d have_last=%d aimed=%d stopCmdPrev=%d\n",
                                t, turn, lastDirX, lastDirY, dx, dy, rcl_bdc_last_x, rcl_bdc_last_y, g_cmd_x, g_cmd_y, dlen, rcl_bd_threat_n,
                                rcl_bdc_have_last, aimed, (int)m.stopCmd);
                    }
                }
            }
            if (!aimed)
            {
                float bx = g_ch[1].x - preX;
                float by = g_ch[1].y - preY;
                float bl = sqrtf(bx * bx + by * by);
                m.noInc++;
                if (mateNear && haveDir && turn > 20.0)
                {
                    m.mateFalse++;
                }
                if (bl > 1.0f && g_ch_n > 1)
                {
                    float dot = (dx * bx + dy * by) / bl;
                    if (dot > 0.766f)
                    {
                        m.towardEnemy++;
                    }
                }
            }
            if (rcl_wall_is_blocked_wide(preX + dx * 120.0f, preY + dy * 120.0f, 60.0f, RCL_WALL_BLOCKS_MOVEMENT))
            {
                m.wallTicks++;
            }
            lastDirX = dx;
            lastDirY = dy;
            haveDir = 1;
        }
        else if (cmdNow && dlen <= 1.0f)
        {
            m.stopCmd++;
        }
        else if (!aimed && g_cmd_n > 0)
        {
            float stx = g_cmd_x - me->x;
            float sty = g_cmd_y - me->y;
            float stl = sqrtf(stx * stx + sty * sty);
            m.staleWalk++;
            if (stl > 1.0f && g_ch_n > 1)
            {
                float bx = g_ch[1].x - me->x;
                float by = g_ch[1].y - me->y;
                float bl = sqrtf(bx * bx + by * by);
                if (bl > 1.0f && ((stx / stl) * (bx / bl) + (sty / stl) * (by / bl)) > 0.766f)
                {
                    m.staleToward++;
                }
            }
        }
        {
            int subs = (int)ceilf(SIM_DT / SIM_SUB);
            float sdt = SIM_DT / (float)subs;
            int s2;
            for (s2 = 0; s2 < subs; s2++)
            {
                for (i = 0; i < SIM_MAX_PRJ; i++)
                {
                    SimProj *p = &g_prj[i];
                    float nx;
                    float ny;
                    int hit = 0;
                    int j;
                    if (!p->alive)
                    {
                        continue;
                    }
                    nx = p->x + p->vx * sdt;
                    ny = p->y + p->vy * sdt;
                    if (!rcl_wall_los(p->x, p->y, nx, ny, RCL_WALL_BLOCKS_PROJECTILES))
                    {
                        p->alive = 0;
                        continue;
                    }
                    p->travelled += sqrtf((nx - p->x) * (nx - p->x) + (ny - p->y) * (ny - p->y));
                    if (p->team != 0 && seg_hit(p->x, p->y, nx, ny, me->x, me->y, me->rad + p->rad))
                    {
                        m.hits++;
                        p->alive = 0;
                        continue;
                    }
                    for (j = 1; j < g_ch_n; j++)
                    {
                        if (g_ch[j].team == p->team)
                        {
                            continue;
                        }
                        if (seg_hit(p->x, p->y, nx, ny, g_ch[j].x, g_ch[j].y, g_ch[j].rad + p->rad))
                        {
                            p->alive = 0;
                            hit = 1;
                            break;
                        }
                    }
                    if (hit)
                    {
                        continue;
                    }
                    p->x = nx;
                    p->y = ny;
                    if (p->travelled > 2800.0f)
                    {
                        p->alive = 0;
                    }
                }
            }
        }
        {
            float best = 1.0e9f;
            for (i = 1; i < g_ch_n; i++)
            {
                if (g_ch[i].team != 1)
                {
                    continue;
                }
                {
                    float d = sqrtf(dist2(g_ch[i].x, g_ch[i].y, me->x, me->y));
                    if (d < best)
                    {
                        best = d;
                    }
                }
            }
            if (best < minDist)
            {
                minDist = best;
            }
            distSum += (double)best;
        }
        m.ticks++;
        if (aimed)
        {
            m.aimedTicks++;
        }
        m.path += (double)sqrtf(dist2(me->x, me->y, preX, preY));
    }
    m.fired = g_fired;
    m.minEnemyDist = (double)minDist;
    m.avgEnemyDist = distSum / (double)(ticks > 0 ? ticks : 1);
    *out = m;
}

int main(int argc, char **argv)
{
    int maps[3] = {1, 2, 3};
    int ais[3] = {7, 21, 99};
    int ticks = (argc > 1) ? atoi(argv[1]) : 1200;
    int s;
    int mi;
    int ai;
    printf("# harness sim/sim_main.cpp  walk_every=%d turn_max=%.2f reach=%.0f gain_min=%.0f\n", RCL_WALK_EVERY,
           RCL_BDC_TURN_MAX, RCL_AD_REACH, RCL_BDC_GAIN_MIN);
    printf("scenario,map,ai,ticks,fired,aimedTicks,hits,jerks,maxTurnDeg,walls,noInc,mateFalse,stopCmd,staleWalk,staleToward,cpuUs/tick,path,minEnemyDist\n");
    {
        const char *names[4] = {"1v1", "1v3", "1v9", "9v9"};
        int enemies[4] = {1, 3, 9, 9};
        int mates[4] = {0, 0, 0, 8};
        long totHits[4] = {0, 0, 0, 0};
        long totFired[4] = {0, 0, 0, 0};
        long totAimed[4] = {0, 0, 0, 0};
        long totJerks[4] = {0, 0, 0, 0};
        long totWalls[4] = {0, 0, 0, 0};
        long totNoInc[4] = {0, 0, 0, 0};
        long totMate[4] = {0, 0, 0, 0};
        long totToward[4] = {0, 0, 0, 0};
        long totStale[4] = {0, 0, 0, 0};
        long totStaleTow[4] = {0, 0, 0, 0};
        long totStop[4] = {0, 0, 0, 0};
        double totTurn[4] = {0, 0, 0, 0};
        double totCpu[4] = {0, 0, 0, 0};
        double totPath[4] = {0, 0, 0, 0};
        long totTicks[4] = {0, 0, 0, 0};
        double worstMinDist[4] = {1e9, 1e9, 1e9, 1e9};
        for (s = 0; s < 4; s++)
        {
            for (mi = 0; mi < 3; mi++)
            {
                for (ai = 0; ai < 3; ai++)
                {
                    SimMetrics m;
                    run_config(enemies[s], mates[s], maps[mi], ais[ai], ticks, &m);
                    printf("%s,%d,%d,%ld,%ld,%ld,%ld,%ld,%.1f,%ld,%ld,%ld,%ld,%ld,%ld,%.6f,%.0f,%.0f\n", names[s], maps[mi], ais[ai],
                           m.ticks, m.fired, m.aimedTicks, m.hits, m.jerks, m.maxTurn, m.wallTicks, m.noInc, m.mateFalse, m.stopCmd,
                           m.staleWalk, m.staleToward, m.cpuUs / (double)(m.ticks > 0 ? m.ticks : 1), m.path, m.minEnemyDist);
                    totHits[s] += m.hits;
                    totFired[s] += m.fired;
                    totAimed[s] += m.aimedTicks;
                    totJerks[s] += m.jerks;
                    totWalls[s] += m.wallTicks;
                    totNoInc[s] += m.noInc;
                    totMate[s] += m.mateFalse;
                    totToward[s] += m.towardEnemy;
                    totStale[s] += m.staleWalk;
                    totStaleTow[s] += m.staleToward;
                    totStop[s] += m.stopCmd;
                    totTicks[s] += m.ticks;
                    if (m.maxTurn > totTurn[s])
                    {
                        totTurn[s] = m.maxTurn;
                    }
                    totCpu[s] += m.cpuUs;
                    totPath[s] += m.path;
                    if (m.minEnemyDist < worstMinDist[s])
                    {
                        worstMinDist[s] = m.minEnemyDist;
                    }
                }
            }
        }
        printf("\nscenario,ticks,fired,aimedTicks,hits,jerks,maxTurnDeg,walls,noInc,mateFalse,stopCmd,staleWalk,staleToward,cpuUs/tick,path,worstMinEnemyDist\n");
        for (s = 0; s < 4; s++)
        {
            printf("%s,%ld,%ld,%ld,%ld,%ld,%.1f,%ld,%ld,%ld,%ld,%ld,%ld,%.6f,%.0f,%.0f\n", names[s], totTicks[s], totFired[s], totAimed[s], totHits[s],
                   totJerks[s], totTurn[s], totWalls[s], totNoInc[s], totMate[s], totStop[s], totStale[s], totStaleTow[s],
                   totCpu[s] / (double)(totTicks[s] > 0 ? totTicks[s] : 1), totPath[s], worstMinDist[s]);
        }
    }
    return 0;
}
