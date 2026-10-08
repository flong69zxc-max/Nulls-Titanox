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
    float x;
    float y;
    float vx;
    float vy;
    float rad;
    float path_len;
    float left;
    float until;
    float age;
    float fade_base;
    float fade_k;
    float cast_range;
    float ax;
    float ay;
    float bx;
    float by;
    int blob;
    int has_segment;
    const char *name;
    const char *owner;
} rcl_ad_hazard_t;

#define RCL_AD_HAZARD_MAX 96
#define RCL_AD_CAP_MAX 16

static rcl_ad_hazard_t rcl_ad_hazards[RCL_AD_HAZARD_MAX];
static rcl_hazard_t rcl_ad_caps[RCL_AD_CAP_MAX];
static float rcl_ad_ring[RCL_AD_DIR_COUNT][2];
static float rcl_ad_scores[RCL_AD_DIR_COUNT];
static int rcl_ad_dir_built = 0;
static int rcl_ad_hazard_n = 0;
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
    float r = p->radius;

    if (r <= 0.0f) r = rcl_proj_radius(p, 1.0f);

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

static float rcl_ad_seg_dist(float px, float py, float ax, float ay, float bx, float by)
{
    float dx = bx - ax;
    float dy = by - ay;
    float len_sq = dx * dx + dy * dy;
    float t;
    float cx;
    float cy;

    t = len_sq < 0.000001f ? 0.0f : ((px - ax) * dx + (py - ay) * dy) / len_sq;

    if (t < 0.0f)
        t = 0.0f;
    else if (t > 1.0f)
        t = 1.0f;

    cx = px - (ax + dx * t);
    cy = py - (ay + dy * t);

    return sqrtf(cx * cx + cy * cy);
}

static void rcl_ad_fade_vel(const rcl_ad_hazard_t *h, float dt, float *vxOut, float *vyOut)
{
    float vx = h->vx;
    float vy = h->vy;

    if (h->fade_base && h->fade_k)
    {
        float nowAge = h->age > 0.0f ? h->age : 0.0f;
        float laterAge = nowAge + dt * 1000.0f;
        float cur = h->fade_base * expf(h->fade_k * nowAge);
        float nxt = h->fade_base * expf(h->fade_k * laterAge);

        if (cur > 0.000001f)
        {
            float r = nxt / cur;

            vx *= r;
            vy *= r;
        }
    }

    *vxOut = vx;
    *vyOut = vy;
}

static int rcl_ad_in_aware(const rcl_ad_hazard_t *h, float mx, float my, float zoneSq)
{
    float dx;
    float dy;

    if (h->has_segment)
    {
        float d = rcl_ad_seg_dist(mx, my, h->ax, h->ay, h->bx, h->by);

        return d * d <= zoneSq;
    }

    dx = h->x - mx;
    dy = h->y - my;

    return dx * dx + dy * dy <= zoneSq;
}

static float rcl_ad_kind_reach(const rcl_proj_t *p, const rcl_kind_t *spec, float spd)
{
    float r = 0.0f;

    if (spec && spec->maxRange > 0) r = (float)spec->maxRange;

    if (spec && spec->chargedRange > 0 && spd > 3500.0f) r = (float)spec->chargedRange;

    if (r <= 0.0f && p->castRange > 0) r = (float)p->castRange;

    if (r <= 0.0f && p->isThrower && (p->targetX || p->targetY) && p->spawnX && p->spawnY)
    {
        float dx = (float)(p->targetX - p->spawnX);
        float dy = (float)(p->targetY - p->spawnY);
        float td = sqrtf(dx * dx + dy * dy);

        if (td > 0.0f) r = td;
    }

    if (r <= 0.0f) r = RCL_AD_FALLBACK_RANGE;

    if (spec && spec->reachAdj) r += (float)spec->reachAdj;

    if (r > 0.0f && r < 70000.0f) return r;

    return RCL_AD_FALLBACK_RANGE;
}

static int rcl_ad_home_pos(const rcl_proj_t *p, float *xOut, float *yOut)
{
    float tx = (float)p->ownerX;
    float ty = (float)p->ownerY;

    if (!rcl_ok(tx, -100000000.0f, 100000000.0f)) return 0;
    if (!rcl_ok(ty, -100000000.0f, 100000000.0f)) return 0;
    if (!tx && !ty) return 0;

    *xOut = tx;
    *yOut = ty;

    return 1;
}

static float rcl_ad_life_left(const rcl_proj_t *p, const rcl_kind_t *spec, float spd,
                              uint64_t nowMs)
{
    float maxR = rcl_ad_kind_reach(p, spec, spd);
    float homeX = 0.0f;
    float homeY = 0.0f;
    float left;

    if (spec && (spec->flags & RCL_K_FADE))
    {
        float spawned = p->spawnedAt ? (float)p->spawnedAt : (float)nowMs;
        float age = (float)nowMs - spawned;

        if (age < 0.0f) age = 0.0f;

        left = maxR * (1.0f - age / 1000.0f);

        return left > 0.0f ? left : 0.0f;
    }

    if (spec && (spec->flags & RCL_K_HOME) && rcl_ad_home_pos(p, &homeX, &homeY))
    {
        float dx = homeX - (float)p->x;
        float dy = homeY - (float)p->y;

        return sqrtf(dx * dx + dy * dy);
    }

    left = maxR - rcl_ad_traveled(p);

    return left > 0.0f ? left : 0.0f;
}

static void rcl_ad_collect(float mx, float my, float myRadius, uint64_t nowMs)
{
    float zoneSq = RCL_AD_AWARE * RCL_AD_AWARE;
    float bodyPad = myRadius + RCL_AD_SKIN;
    float bodyR = myRadius + RCL_AD_SKIN;
    int i;
    int c;

    rcl_ad_hazard_n = 0;

    for (i = 0; i < rcl_proj_death_n && i < RCL_PROJ_DEATH_MAX; i++)
    {
        rcl_note_burst_death(&rcl_proj_deaths[i]);
    }

    for (i = 0; i < RCL_PROJ_MAX; i++)
    {
        const rcl_proj_t *p = &rcl_projs[i];
        const rcl_kind_t *spec = NULL;
        const rcl_fit_t *fit = NULL;
        const char *name = NULL;
        int shaped = 0;
        int lockPath = 0;
        int blob = 0;
        float vx = 0.0f;
        float vy = 0.0f;
        float spd = 0.0f;
        float shotR = 0.0f;
        float rad = 0.0f;
        float ux = 0.0f;
        float uy = 0.0f;
        float playerAlong = 0.0f;
        float left = 0.0f;
        float gap = 0.0f;
        float dx = 0.0f;
        float dy = 0.0f;

        if (!p->elem) continue;
        if (rcl_ad_is_mine(p)) continue;

        shaped = rcl_shape_hazards(p, nowMs, rcl_ad_caps, RCL_AD_CAP_MAX);

        for (c = 0; c < shaped; c++)
        {
            const rcl_hazard_t *cap = &rcl_ad_caps[c];
            float until = (cap->t1 - (float)nowMs) / 1000.0f;
            rcl_ad_hazard_t *h = NULL;

            if (until <= 0.0f) continue;
            if (rcl_ad_hazard_n >= RCL_AD_HAZARD_MAX) break;

            h = &rcl_ad_hazards[rcl_ad_hazard_n];

            memset(h, 0, sizeof(*h));

            h->rad = cap->radius + bodyPad;
            h->blob = cap->has_segment ? 0 : 1;
            h->until = until;
            h->has_segment = cap->has_segment;
            h->name = p->name ? p->name : cap->name;

            if (cap->has_segment)
            {
                h->ax = cap->ax;
                h->ay = cap->ay;
                h->bx = cap->bx;
                h->by = cap->by;
            }
            else
            {
                h->x = cap->x;
                h->y = cap->y;
            }

            if (rcl_ad_in_aware(h, mx, my, zoneSq)) rcl_ad_hazard_n++;
        }

        if (shaped > 0 && rcl_blocks_linear(p->name)) continue;

        name = p->name ? p->name : "";
        spec = rcl_kind_of(name);

        if (spec && (spec->flags & RCL_K_DROP)) continue;

        dx = (float)p->x - mx;
        dy = (float)p->y - my;

        if (dx * dx + dy * dy > zoneSq) continue;

        vx = p->vx;
        vy = p->vy;

        if (vx == 0.0f && vy == 0.0f)
        {
            if (!rcl_proj_vel(p, &vx, &vy))
            {
                vx = 0.0f;
                vy = 0.0f;
            }
        }

        if (!rcl_ok(vx, -100000000.0f, 100000000.0f) || !rcl_ok(vy, -100000000.0f, 100000000.0f))
        {
            vx = 0.0f;
            vy = 0.0f;
        }

        {
            float flown = rcl_ad_traveled(p);

            if (spec && (spec->flags & RCL_K_LOCKPATH) && flown > 120.0f && p->spawnX && p->spawnY)
            {
                float base = p->speed > 0.0f ? p->speed : 1.0f;

                vx = ((float)p->x - (float)p->spawnX) / flown * base;
                vy = ((float)p->y - (float)p->spawnY) / flown * base;
            }
        }

        spd = sqrtf(vx * vx + vy * vy);

        if (spec && spec->speedMul > 0.0f && spd > 3500.0f)
        {
            vx *= spec->speedMul;
            vy *= spec->speedMul;
            spd *= spec->speedMul;
        }

        lockPath = (spec && (spec->flags & RCL_K_LOCKPATH)) || p->isBeam;
        blob = (spec && (spec->flags & RCL_K_BLOB)) ||
               (!lockPath && (p->isThrower || (p->speed > 0.0f && p->speed < 1600.0f)));
        fit = rcl_fit_of(name);
        shotR = rcl_ad_ball_radius(p) + (spec ? (float)spec->growR : 0.0f);
        rad = shotR + bodyR + fit->pad + shotR * fit->grow;

        if (spd >= 1.0f)
        {
            ux = vx / spd;
            uy = vy / spd;
        }

        if (!blob && spd >= 1.0f)
        {
            playerAlong = (mx - (float)p->x) * ux + (my - (float)p->y) * uy;

            if (playerAlong < -50.0f) continue;

            if (!p->isThrower)
            {
                float tHit = playerAlong > 0.0f ? playerAlong : 0.0f;
                float hitX = (float)p->x + ux * tHit;
                float hitY = (float)p->y + uy * tHit;

                if (!rcl_wall_los((float)p->x, (float)p->y, hitX, hitY,
                                  RCL_WALL_BLOCKS_PROJECTILES))
                {
                    continue;
                }
            }
        }

        left = rcl_ad_life_left(p, spec, spd, nowMs);

        if (left <= 10.0f) continue;

        gap = sqrtf(dx * dx + dy * dy) - bodyR - shotR;

        if (left < 0.85f * (gap > 0.0f ? gap : 0.0f)) continue;
        if (!blob && spd >= 1.0f && playerAlong > left + shotR) continue;
        if (rcl_ad_hazard_n >= RCL_AD_HAZARD_MAX) break;

        {
            rcl_ad_hazard_t *h = &rcl_ad_hazards[rcl_ad_hazard_n];

            memset(h, 0, sizeof(*h));

            h->x = (float)p->x;
            h->y = (float)p->y;
            h->vx = blob ? 0.0f : vx;
            h->vy = blob ? 0.0f : vy;
            h->rad = rad;
            h->path_len = left + shotR;
            h->left = left;
            h->name = p->name;
            h->blob = blob;
            h->cast_range = (float)p->castRange;
            h->age = (spec && (spec->flags & RCL_K_FADE))
                         ? ((float)nowMs - (float)(p->spawnedAt ? p->spawnedAt : nowMs))
                         : 0.0f;
            if (h->age < 0.0f) h->age = 0.0f;
            h->fade_base = spec ? spec->fadeBase : 0.0f;
            h->fade_k = spec ? spec->fadeK : 0.0f;

            rcl_ad_hazard_n++;
        }
    }
}

static float rcl_ad_clearance(float mx, float my, float mvx, float mvy)
{
    float minClear = 1000000000.0f;
    float horizon = RCL_AD_HORIZON;
    int i;
    int step;

    for (i = 0; i < rcl_ad_hazard_n; i++)
    {
        const rcl_ad_hazard_t *h = &rcl_ad_hazards[i];

        if (h->has_segment)
        {
            float maxT = h->until > 0.0f ? (h->until < horizon ? h->until : horizon) : horizon;

            for (step = 0; step <= 4; step++)
            {
                float ts = maxT * ((float)step / 4.0f);
                float d =
                    rcl_ad_seg_dist(mx + mvx * ts, my + mvy * ts, h->ax, h->ay, h->bx, h->by) -
                    h->rad;

                if (d < minClear) minClear = d;
            }

            continue;
        }

        {
            float velX = 0.0f;
            float velY = 0.0f;
            float spd = 0.0f;
            float maxT = horizon;
            float relx = h->x - mx;
            float rely = h->y - my;
            float vrx;
            float vry;
            float vv;
            float cx;
            float cy;
            float clear;

            rcl_ad_fade_vel(h, 0.0f, &velX, &velY);

            spd = sqrtf(velX * velX + velY * velY);

            if (spd > 1.0f)
            {
                if (h->left > 0.0f && h->left / spd < maxT) maxT = h->left / spd;
                if (h->path_len > 0.0f && h->path_len / spd < maxT) maxT = h->path_len / spd;
            }

            if (h->until > 0.0f && h->until < maxT) maxT = h->until;

            vrx = velX - mvx;
            vry = velY - mvy;
            vv = vrx * vrx + vry * vry;

            if (vv < 0.000001f)
            {
                cx = relx;
                cy = rely;
            }
            else
            {
                float ts = -(relx * vrx + rely * vry) / vv;

                if (ts < 0.0f)
                    ts = 0.0f;
                else if (ts > maxT)
                    ts = maxT;

                cx = relx + vrx * ts;
                cy = rely + vry * ts;
            }

            clear = sqrtf(cx * cx + cy * cy) - h->rad;

            if (clear < minClear) minClear = clear;
        }
    }

    return minClear;
}

static float rcl_ad_wall_ahead(float mx, float my, float dx, float dy, float speed)
{
    float step = speed * RCL_AD_PROBE_STEP;
    float raw = 0.0f;
    int s;

    for (s = 1; s <= RCL_AD_PROBE_COUNT; s++)
    {
        float px = mx + dx * step * (float)s;
        float py = my + dy * step * (float)s;

        if (rcl_wall_is_blocked_wide(px, py, RCL_AD_WALL_BODY, RCL_WALL_BLOCKS_MOVEMENT))
        {
            raw += RCL_AD_WALL_HIT * (float)(RCL_AD_PROBE_COUNT - s + 1);
        }
    }

    return raw;
}

static float rcl_ad_clamp_to_map(float v, int maxTiles)
{
    float maxV = (float)maxTiles * RCL_WALL_TILE_SIZE - 1.0f;

    if (maxV <= 0.0f) return v;
    if (v < 0.0f) return 0.0f;
    if (v > maxV) return maxV;

    return v;
}

static void rcl_ad_clamp_target(float *tx, float *ty)
{
    int w = rcl_wall_cache_w();
    int h = rcl_wall_cache_h();

    if (w <= 0 || h <= 0) return;

    *tx = rcl_ad_clamp_to_map(*tx, w);
    *ty = rcl_ad_clamp_to_map(*ty, h);
}

static int rcl_ad_send_move(float tx, float ty, float mx, float my)
{
    rcl_ad_clamp_target(&tx, &ty);

    rcl_move_to((int32_t)tx, (int32_t)ty, mx, my);

    return rcl_enqueue((int32_t)tx, (int32_t)ty);
}

static int rcl_ad_update(float mx, float my)
{
    uint64_t now = rcl_ad_now_ms();
    float speed = 0.0f;
    float myRadius = 0.0f;
    float stayClear = 0.0f;
    int inDanger = 0;
    int prevIdx = -1;
    float prevX = 0.0f;
    float prevY = 0.0f;
    float bodyR = RCL_AD_WALL_BODY;
    int bestIdx = 0;
    float bestScore = -1000000000.0f;
    int chosenIdx = 0;
    float tx = 0.0f;
    float ty = 0.0f;
    int i;

    if (!rcl_ok(mx, -100000000.0f, 100000000.0f)) return 0;
    if (!rcl_ok(my, -100000000.0f, 100000000.0f)) return 0;

    rcl_dodge_speed_probe();

    speed = rcl_dodge_speed;
    myRadius = rcl_own_radius();

    if (speed <= 0.0f) speed = 720.0f;
    if (myRadius <= 0.0f) myRadius = 60.0f;

    if (now - rcl_ad_tick_ms < (uint64_t)RCL_AD_TICK_MS) return rcl_ad_heading >= 0;

    rcl_ad_tick_ms = now;

    rcl_ad_build_ring();
    rcl_ad_collect(mx, my, myRadius, now);

    if (rcl_ad_hazard_n == 0)
    {
        if (rcl_ad_heading >= 0 && now - rcl_ad_danger_ms > (uint64_t)RCL_AD_GRACE_MS)
            rcl_ad_clear_heading();

        return 0;
    }

    stayClear = rcl_ad_clearance(mx, my, 0.0f, 0.0f);
    inDanger = stayClear < RCL_AD_ENGAGE;

    if (inDanger) rcl_ad_danger_ms = now;

    if (!inDanger && (rcl_ad_heading < 0 || now - rcl_ad_danger_ms > (uint64_t)RCL_AD_GRACE_MS))
    {
        if (rcl_ad_heading >= 0) rcl_ad_clear_heading();

        return 0;
    }

    prevIdx = (rcl_ad_heading >= 0 && rcl_ad_heading < RCL_AD_DIR_COUNT) ? rcl_ad_heading : -1;

    if (prevIdx >= 0)
    {
        prevX = rcl_ad_ring[prevIdx][0];
        prevY = rcl_ad_ring[prevIdx][1];
    }

    for (i = 0; i < RCL_AD_DIR_COUNT; i++)
    {
        float dirX = rcl_ad_ring[i][0];
        float dirY = rcl_ad_ring[i][1];
        float s = rcl_ad_clearance(mx, my, speed * dirX, speed * dirY);

        s -= rcl_ad_wall_ahead(mx, my, dirX, dirY, speed);

        if (prevIdx >= 0) s += RCL_AD_MOMENTUM * (dirX * prevX + dirY * prevY);

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
            chosenIdx = prevIdx;
        else
            rcl_ad_hold_ms = now + (uint64_t)RCL_AD_LOCK_MS;
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

    tx = roundf(mx + rcl_ad_ring[chosenIdx][0] * RCL_AD_REACH);
    ty = roundf(my + rcl_ad_ring[chosenIdx][1] * RCL_AD_REACH);

    rcl_ad_send_move(tx, ty, mx, my);

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
