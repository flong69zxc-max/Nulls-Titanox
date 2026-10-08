#include "../recoil.h"

#define RCL_STATE_EVERY 240
#define RCL_WALK_EVERY 5

__thread int rcl_in_drive = 0;

int32_t rcl_pl_mine[RCL_PLAYER_MAX];

int rcl_active = 0;

int rcl_moving = 0;

int rcl_cand_now[RCL_CAND];

int rcl_cand_seen = 0;

int32_t rcl_prev_x = 0;

int32_t rcl_prev_y = 0;

int rcl_cal_off_seen = -1;

float rcl_cal_rad_seen = 0.0f;

int rcl_cal_n = 0;

int rcl_ok(float v, float lo, float hi)
{
    if (!(v >= lo && v <= hi)) return 0;

    return 1;
}

int rcl_rad_off = -1;

float rcl_rad_est = 0.0f;

float rcl_own_r = 0.0f;

#define RCL_DODGE_CHAR_SPEED 720.0f
#define RCL_DODGE_SPEED_MIN 300
#define RCL_DODGE_SPEED_MAX 8500

static float rcl_dodge_speed = RCL_DODGE_CHAR_SPEED;
static void rcl_dodge_speed_probe(void)
{
    void *def = NULL;
    int32_t raw = 0;

    if (!rcl_own_elem) return;
    if (!rcl_read_ptr(rcl_own_elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) || !def) return;
    if (!rcl_read_int((uintptr_t)def + (uintptr_t)OFF_CHARDATA_SPEED, &raw)) return;
    if (raw < RCL_DODGE_SPEED_MIN || raw > RCL_DODGE_SPEED_MAX) return;

    rcl_dodge_speed = (float)raw;
}

#define RCL_AD_AWARE 3200.0f
#define RCL_AD_FALLBACK_RANGE 2800.0f
#define RCL_AD_TICK_MS 24
#define RCL_AD_DIR_COUNT 48
#define RCL_AD_SKIN 50.0f
#define RCL_AD_LOCK_MS 170
#define RCL_AD_REACH 600.0f
#define RCL_AD_HORIZON 1.0f
#define RCL_AD_KEEP_BAND 120.0f
#define RCL_AD_MOMENTUM 100.0f
#define RCL_AD_ENGAGE 40.0f
#define RCL_AD_GRACE_MS 120
#define RCL_AD_WALL_HIT 9000.0f
#define RCL_AD_PROBE_COUNT 3
#define RCL_AD_PROBE_STEP 0.35f
#define RCL_AD_WALL_BODY 240.0f

typedef struct
{
    float vx;
    float vy;
    float rad;
    float relx;
    float rely;
    float p0;
    float hmax;
} rcl_ad_threat_t;

#define RCL_AD_TILE_MEMO 64

static uint32_t rcl_ad_memo_gen = 1;
static uint32_t rcl_ad_memo_at[RCL_AD_TILE_MEMO];
static uint8_t rcl_ad_memo_val[RCL_AD_TILE_MEMO];

static rcl_ad_threat_t rcl_ad_threats[RCL_PROJ_MAX];
static float rcl_ad_ring[RCL_AD_DIR_COUNT][2];
static float rcl_ad_scores[RCL_AD_DIR_COUNT];
static int rcl_ad_dir_built = 0;
static int rcl_ad_threat_n = 0;
static int rcl_ad_heading = -1;
static uint64_t rcl_ad_hold_ms = 0;
static uint64_t rcl_ad_danger_ms = 0;
static uint64_t rcl_ad_tick_ms = 0;

static uint64_t rcl_ad_now_ms(void)
{
    return (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
}

static void rcl_ad_build_ring(void)
{
    int i;

    if (rcl_ad_dir_built) return;

    for (i = 0; i < RCL_AD_DIR_COUNT; i++)
    {
        float a = 6.283185307179586f * (float)i / (float)RCL_AD_DIR_COUNT;

        rcl_ad_ring[i][0] = cosf(a);
        rcl_ad_ring[i][1] = sinf(a);
    }

    rcl_ad_dir_built = 1;
}

static void rcl_ad_clear_heading(void)
{
    rcl_ad_heading = -1;
    rcl_ad_hold_ms = 0;
}

static float rcl_ad_ball_radius(const rcl_proj_t *p)
{
    float r = rcl_proj_radius(p, 1.0f);

    if (r > 0.0f) return r;

    return RCL_PROJ_RADIUS_DEFAULT;
}

static float rcl_ad_traveled(const rcl_proj_t *p)
{
    float dx;
    float dy;

    if (!p->spawnX && !p->spawnY) return 0.0f;

    dx = (float)(p->x - p->spawnX);
    dy = (float)(p->y - p->spawnY);

    return sqrtf(dx * dx + dy * dy);
}

static int rcl_ad_is_mine(const rcl_proj_t *p)
{
    if (p->team < 0) return 0;
    if (p->team == rcl_own_team_a) return 1;
    if (rcl_own_team_b >= 0 && p->team == rcl_own_team_b) return 1;

    return 0;
}

static void rcl_ad_collect(float mx, float my, float bodyR)
{
    float zone2 = RCL_AD_AWARE * RCL_AD_AWARE;
    int i;
    int n = 0;

    for (i = 0; i < RCL_PROJ_MAX; i++)
    {
        const rcl_proj_t *p = &rcl_projs[i];
        rcl_ad_threat_t *t = NULL;
        float vx = 0.0f;
        float vy = 0.0f;
        float spd = 0.0f;
        float rad = 0.0f;
        float dx = 0.0f;
        float dy = 0.0f;
        float along = 0.0f;
        float left = 0.0f;
        float gap = 0.0f;

        if (!p->elem) continue;
        if (rcl_ad_is_mine(p)) continue;
        if (!rcl_proj_vel(p, &vx, &vy)) continue;

        spd = sqrtf(vx * vx + vy * vy);
        if (spd < 1.0f) continue;

        rad = rcl_ad_ball_radius(p) + bodyR;

        dx = mx - (float)p->x;
        dy = my - (float)p->y;

        if (dx * dx + dy * dy > zone2 + rad * rad) continue;

        along = dx * (vx / spd) + dy * (vy / spd);
        if (along < -50.0f) continue;

        left = RCL_AD_FALLBACK_RANGE - rcl_ad_traveled(p);
        if (left <= 10.0f) continue;

        gap = sqrtf(dx * dx + dy * dy) - rad;
        if (gap < 0.0f) gap = 0.0f;
        if (left < 0.85f * gap) continue;

        t = &rcl_ad_threats[n];
        t->vx = vx;
        t->vy = vy;
        t->rad = rad;
        t->relx = dx;
        t->rely = dy;
        t->p0 = dx * vx + dy * vy;
        t->hmax = left / spd < RCL_AD_HORIZON ? left / spd : RCL_AD_HORIZON;

        n++;
    }

    rcl_ad_threat_n = n;
}

static float rcl_ad_clearance(float mvx, float mvy)
{
    float bestClear = 1.0e9f;
    int i;

    for (i = 0; i < rcl_ad_threat_n; i++)
    {
        const rcl_ad_threat_t *t = &rcl_ad_threats[i];
        float vrx = t->vx - mvx;
        float vry = t->vy - mvy;
        float vv = vrx * vrx + vry * vry;
        float cx;
        float cy;
        float sq;
        float thr;

        if (vv < 1e-6f)
        {
            cx = t->relx;
            cy = t->rely;
        }
        else
        {
            float ts = -(t->p0 - t->relx * mvx - t->rely * mvy) / vv;

            if (ts < 0.0f)
                ts = 0.0f;
            else if (ts > t->hmax)
                ts = t->hmax;

            cx = t->relx + vrx * ts;
            cy = t->rely + vry * ts;
        }

        sq = cx * cx + cy * cy;
        thr = bestClear + t->rad;

        if (thr > 0.0f && sq >= thr * thr) continue;

        thr = sqrtf(sq) - t->rad;

        if (thr < bestClear) bestClear = thr;
    }

    return bestClear;
}

static int rcl_ad_tile_blocked(int tx, int ty)
{
    uint32_t slot = (uint32_t)((tx * 73856093) ^ (ty * 19349663)) & (RCL_AD_TILE_MEMO - 1);
    int proj = 0;
    int move = 0;

    if (rcl_ad_memo_at[slot] == rcl_ad_memo_gen) return rcl_ad_memo_val[slot];

    rcl_ad_memo_at[slot] = rcl_ad_memo_gen;

    if (!rcl_cell(tx, ty, &proj, &move))
    {
        rcl_ad_memo_val[slot] = 0;

        return 0;
    }

    rcl_ad_memo_val[slot] = (move != 0) ? 1 : 0;

    return rcl_ad_memo_val[slot];
}

static int rcl_ad_blocked(float x, float y)
{
    int tx = 0;
    int ty = 0;

    if (x < 0.0f || y < 0.0f) return 1;
    if (!rcl_tiles) return 0;

    rcl_tile_of(x, y, &tx, &ty);

    return rcl_ad_tile_blocked(tx, ty);
}

static int rcl_ad_blocked_wide(float x, float y, float r)
{
    if (rcl_ad_blocked(x, y)) return 1;
    if (rcl_ad_blocked(x + r, y)) return 1;
    if (rcl_ad_blocked(x - r, y)) return 1;
    if (rcl_ad_blocked(x, y + r)) return 1;
    if (rcl_ad_blocked(x, y - r)) return 1;

    return 0;
}

static float rcl_ad_wall_ahead(float mx, float my, float dx, float dy, float speed)
{
    float step = speed * RCL_AD_PROBE_STEP;
    float raw = 0.0f;
    int s;

    for (s = 1; s <= RCL_AD_PROBE_COUNT; s++)
    {
        if (rcl_ad_blocked_wide(mx + dx * step * (float)s, my + dy * step * (float)s,
                                RCL_AD_WALL_BODY))
        {
            raw += RCL_AD_WALL_HIT * (float)(RCL_AD_PROBE_COUNT - s + 1);
        }
    }

    return raw;
}

static int rcl_ad_send_move(float mx, float my, float dx, float dy)
{
    int32_t tx = (int32_t)(mx + dx * RCL_AD_REACH);
    int32_t ty = (int32_t)(my + dy * RCL_AD_REACH);

    rcl_clamp(&tx, &ty);

    rcl_move_to(tx, ty, mx, my);

    return rcl_enqueue(tx, ty);
}

static int rcl_ad_update(float mx, float my)
{
    uint64_t now = rcl_ad_now_ms();
    float bodyR;
    float speed;
    float stayClear;
    float bestScore;
    int inDanger;
    int prevIdx;
    int bestIdx;
    int chosenIdx;
    int i;

    if (!rcl_own_elem) return 0;

    rcl_ad_build_ring();
    rcl_dodge_speed_probe();

    if (rcl_ad_tick_ms > 0 && (now - rcl_ad_tick_ms) < (uint64_t)RCL_AD_TICK_MS)
    {
        return rcl_ad_heading >= 0;
    }

    rcl_ad_tick_ms = now;

    if (++rcl_ad_memo_gen == 0) rcl_ad_memo_gen = 1;

    speed = rcl_dodge_speed;

    if (speed < 120.0f) speed = 120.0f;
    if (speed > 1200.0f) speed = 1200.0f;

    bodyR = rcl_own_radius();

    if (bodyR < RCL_OWN_RADIUS_MIN) bodyR = RCL_OWN_RADIUS_MIN;

    bodyR += RCL_AD_SKIN;

    rcl_ad_collect(mx, my, bodyR);

    if (rcl_ad_threat_n <= 0)
    {
        if (rcl_ad_heading >= 0 && (now - rcl_ad_danger_ms) > (uint64_t)RCL_AD_GRACE_MS)
        {
            rcl_ad_clear_heading();
        }

        return 0;
    }

    stayClear = rcl_ad_clearance(0.0f, 0.0f);
    inDanger = (stayClear < RCL_AD_ENGAGE) ? 1 : 0;

    if (inDanger) rcl_ad_danger_ms = now;

    if (!inDanger && (rcl_ad_heading < 0 || (now - rcl_ad_danger_ms) > (uint64_t)RCL_AD_GRACE_MS))
    {
        if (rcl_ad_heading >= 0) rcl_ad_clear_heading();

        return 0;
    }

    prevIdx = rcl_ad_heading;

    for (i = 0; i < RCL_AD_DIR_COUNT; i++)
    {
        float s = rcl_ad_clearance(speed * rcl_ad_ring[i][0], speed * rcl_ad_ring[i][1]);

        if (prevIdx >= 0)
        {
            s += RCL_AD_MOMENTUM * (rcl_ad_ring[i][0] * rcl_ad_ring[prevIdx][0] +
                                    rcl_ad_ring[i][1] * rcl_ad_ring[prevIdx][1]);
        }

        rcl_ad_scores[i] = s;
    }

    bestIdx = 0;
    bestScore = -1.0e18f;

    for (i = 0; i < RCL_AD_DIR_COUNT; i++)
    {
        float s = rcl_ad_scores[i];

        if (i == prevIdx || s > bestScore)
        {
            s -= rcl_ad_wall_ahead(mx, my, rcl_ad_ring[i][0], rcl_ad_ring[i][1], speed);
        }

        rcl_ad_scores[i] = s;

        if (s > bestScore)
        {
            bestScore = s;
            bestIdx = i;
        }
    }

    chosenIdx = bestIdx;

    if (prevIdx >= 0 && now < rcl_ad_hold_ms && chosenIdx != prevIdx)
    {
        if (rcl_ad_scores[prevIdx] + RCL_AD_KEEP_BAND >= rcl_ad_scores[chosenIdx])
        {
            chosenIdx = prevIdx;
        }
        else
        {
            rcl_ad_hold_ms = now + (uint64_t)RCL_AD_LOCK_MS;
        }
    }
    else if (now >= rcl_ad_hold_ms)
    {
        rcl_ad_hold_ms = now + (uint64_t)RCL_AD_LOCK_MS;
    }

    if (rcl_ad_scores[chosenIdx] <= stayClear)
    {
        if (rcl_ad_heading >= 0) rcl_ad_clear_heading();

        return 0;
    }

    rcl_ad_heading = chosenIdx;

    rcl_ad_send_move(mx, my, rcl_ad_ring[chosenIdx][0], rcl_ad_ring[chosenIdx][1]);

    return 1;
}

void rcl_autododge(void)
{
    static int tagOnce = 0;

    if (!tagOnce)
    {
        tagOnce = 1;
    }

    if (RCL_STATE_EVERY <= 1 || (rcl_ticks_a % (uint64_t)RCL_STATE_EVERY) == 0) rcl_state();

    rcl_paircal();

    rcl_obj_t objects[RCL_OBJECT_MAX];
    uintptr_t source = 0;
    int usable = 0;
    int ownIndex = -1;
    int32_t ownTeam = 0;
    int ownX = 0;
    int ownY = 0;

    if (!rcl_base) return;

    int sourceIsMode = (rcl_scene_object != 0);

    if (sourceIsMode)
    {
        source = rcl_scene_object;
    }
    else if (rcl_players_object)
    {
        source = rcl_players_object;
    }
    else if (rcl_objvote_best_owner && rcl_objvote_best_teamcount >= RCL_OWNER_VOTE_TEAMS_MIN &&
             rcl_objvote_max_votes >= RCL_OWNER_VOTE_MIN)
    {
        source = rcl_objvote_best_owner;
    }
    else if (rcl_trail_count > 0 && rcl_trail_best >= 0 && rcl_trail_best < rcl_trail_count)
    {
        source = rcl_trail[rcl_trail_best].manager;
    }
    else
    {
        rcl_no_source_passes = 0;
    }

    rcl_ticks_a++;

    if (!source)
    {
        return;
    }

    if (rcl_setpred_state < 0)
    {
        rcl_setpred_state = rcl_verify_setprediction();
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        void *resolved = NULL;
        int changed = (rcl_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;

        if (sourceIsMode && rcl_hop_chosen == 1 && rcl_tick_object)
        {
            resolved = (void *)rcl_tick_object;
        }
        else if (sourceIsMode)
        {
            if (!rcl_read_ptr(source + RCL_MODE_MANAGER_OFF, &resolved) || !resolved)
            {
                resolved = NULL;
            }
        }
        else
        {
            resolved = (void *)source;
        }

        managerChanged = ((uintptr_t)resolved != rcl_manager_ptr);

        {
            int32_t liveCount = 0;

            if (resolved) rcl_read_int((uintptr_t)resolved + RCL_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && rcl_hop_chosen == 1 &&
                (liveCount != rcl_walk_count ||
                 (rcl_walk_tick != rcl_ticks_b && (rcl_ticks_b % RCL_WALK_EVERY) == 0)))
            {
                rcl_walk_count = liveCount;
                rcl_walk_tick = rcl_ticks_b;
                periodic = 1;
            }
        }

        if (!rcl_probe_done || changed || managerChanged || periodic ||
            (!rcl_coord_ok && probeNow > rcl_probe_last_ms + RCL_REPROBE_MS))
        {
            rcl_probe_object = source;
            rcl_probe_last_ms = probeNow;
            rcl_manager_ptr = (uintptr_t)resolved;

            if (resolved)
            {
                int loud = (changed || managerChanged || !rcl_probe_done);
                rcl_probe((uintptr_t)resolved, rcl_scene_object, loud);

                if (loud) rcl_discriminate((uintptr_t)resolved);
            }
        }
    }

    if (!rcl_setpred_state)
    {
        return;
    }

    if (!rcl_coord_ok && rcl_coord_usable < RCL_MIN_USABLE) return;

    if (!rcl_scene_object)
    {
        return;
    }

    memset(objects, 0, sizeof(objects));

    usable = rcl_collect(rcl_manager_ptr, objects, RCL_OBJECT_MAX);

    if (usable < RCL_MIN_USABLE_2)
    {

        return;
    }

    rcl_own_scan();

    {
        const char *ownFrom = "none";

        if (!rcl_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !rcl_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !rcl_resolve_own_2(objects, usable, &ownIndex, &ownFrom))
        {
            return;
        }

        rcl_publish_own(objects[ownIndex].object, ownFrom);

        if (!rcl_own_logged)
        {
            rcl_own_logged = 1;
        }
    }

    rcl_own_elem_2 = objects[ownIndex].object;

    ownTeam = (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                      : objects[ownIndex].teamNew;
    ownX = objects[ownIndex].x;
    ownY = objects[ownIndex].y;

    rcl_death_signals((ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].object : 0, ownX,
                      ownY);

    rcl_alive(ownX, ownY);

    {
        int32_t projCount = 0;

        if (rcl_manager_ptr) rcl_read_int(rcl_manager_ptr + RCL_MGR_COUNT_OFF, &projCount);

        rcl_own_team_a = (int)ownTeam;

        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= RCL_TEAM_MAX_2) rcl_own_team_seen = 1;

        rcl_roster(rcl_own_elem_2, ownIndex, (int)ownTeam, objects, usable);

        if (ownIndex < 0 || ownIndex >= usable || ownIndex >= RCL_OBJECT_MAX)
        {

            return;
        }

        if (rcl_life(objects[ownIndex].object, ownX, ownY)) return;

        rcl_proj_scan(rcl_manager_ptr, projCount);

        rcl_active = rcl_ad_update((float)ownX, (float)ownY);
    }
}

int rcl_dodge_probe_usable = 0;
float rcl_own_radius(void)
{
    float r = 0.0f;

    if (!RCL_GEOM) return 0.0f;

    if (rcl_own_r > 1.0f)
    {
        r = rcl_own_r;

        if (r > RCL_OWN_RADIUS_MAX) r = RCL_OWN_RADIUS_MAX;
        if (r < RCL_OWN_RADIUS_MIN) r = RCL_OWN_RADIUS_MIN;

        return r;
    }

    return RCL_DATA_OWN_R;
}

int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut)
{
    uint64_t dt = 0;

    if (!p->elem || !p->hasPrev) return 0;

    dt = p->qtick - p->ptick;
    if (dt == 0 || dt > RCL_DT_MAX) dt = 1;

    *vxOut = (float)(p->x - p->px) / (float)dt;
    *vyOut = (float)(p->y - p->py) / (float)dt;

    return 1;
}
