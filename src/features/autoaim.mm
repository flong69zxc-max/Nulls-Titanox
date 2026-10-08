#include "../recoil.h"

#define RCL_AIM_HIST 10
#define RCL_AIM_SHOT_SPEED_FALLBACK 2600.0f
#define RCL_AIM_SHOT_SPEED_MIN 400.0f
#define RCL_AIM_SHOT_SPEED_MAX 12000.0f
#define RCL_AIM_LEAD_MAX 1400.0f
#define RCL_AIM_VEL_DEAD 14.0f
#define RCL_AIM_T_MAX 1.20f
#define RCL_AIM_COORD_MAX 200000.0f
#define RCL_AIM_CONF_MIN 0.20f

static uintptr_t rcl_aim_hist_id = 0;
static int rcl_aim_hist_n = 0;
static int rcl_aim_hist_at = 0;
static float rcl_aim_hist_x[RCL_AIM_HIST];
static float rcl_aim_hist_y[RCL_AIM_HIST];
static uint64_t rcl_aim_hist_ms[RCL_AIM_HIST];

static float rcl_aim_shot_speed(void)
{
    float sum = 0.0f;
    int n = 0;
    int i;

    for (i = 0; i < 16; i++)
    {
        const rcl_proj_t *p = &rcl_projs[i];
        float spd;

        if (!p->elem)
        {
            continue;
        }

        spd = sqrtf(p->vx * p->vx + p->vy * p->vy);

        if (spd < RCL_AIM_SHOT_SPEED_MIN || spd > RCL_AIM_SHOT_SPEED_MAX)
        {
            continue;
        }

        sum += spd;
        n++;
    }

    if (n > 0)
    {
        float avg = sum / (float)n;

        if (avg >= RCL_AIM_SHOT_SPEED_MIN && avg <= RCL_AIM_SHOT_SPEED_MAX)
        {
            return avg;
        }
    }

    return RCL_AIM_SHOT_SPEED_FALLBACK;
}

static void rcl_aim_hist_reset(uintptr_t id)
{
    rcl_aim_hist_id = id;
    rcl_aim_hist_n = 0;
    rcl_aim_hist_at = 0;
}

static void rcl_aim_hist_push(float x, float y)
{
    uint64_t now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

    rcl_aim_hist_x[rcl_aim_hist_at] = x;
    rcl_aim_hist_y[rcl_aim_hist_at] = y;
    rcl_aim_hist_ms[rcl_aim_hist_at] = now;

    rcl_aim_hist_at = (rcl_aim_hist_at + 1) % RCL_AIM_HIST;

    if (rcl_aim_hist_n < RCL_AIM_HIST)
    {
        rcl_aim_hist_n++;
    }
}

static int rcl_aim_target_vel(float *vxOut, float *vyOut, float *confOut)
{
    float tvx = 0.0f;
    float tvy = 0.0f;
    float wsum = 0.0f;
    float lvx = 0.0f;
    float lvy = 0.0f;
    float agree;
    float lmag;
    int i;

    *vxOut = 0.0f;
    *vyOut = 0.0f;
    *confOut = 0.0f;

    if (rcl_aim_hist_n < 2)
    {
        return 0;
    }

    for (i = 1; i < rcl_aim_hist_n; i++)
    {
        int a = (rcl_aim_hist_at - i - 1 + RCL_AIM_HIST * 2) % RCL_AIM_HIST;
        int b = (rcl_aim_hist_at - i + RCL_AIM_HIST * 2) % RCL_AIM_HIST;
        float dt = (float)(rcl_aim_hist_ms[b] - rcl_aim_hist_ms[a]) / 1000.0f;
        float w = (float)(rcl_aim_hist_n - i);
        float sx;
        float sy;

        if (dt <= 0.0f)
        {
            continue;
        }

        sx = (rcl_aim_hist_x[b] - rcl_aim_hist_x[a]) / dt;
        sy = (rcl_aim_hist_y[b] - rcl_aim_hist_y[a]) / dt;

        tvx += sx * w;
        tvy += sy * w;
        wsum += w;

        if (i == 1)
        {
            lvx = sx;
            lvy = sy;
        }
    }

    if (wsum <= 0.0f)
    {
        return 0;
    }

    tvx /= wsum;
    tvy /= wsum;

    if (tvx * tvx + tvy * tvy < RCL_AIM_VEL_DEAD * RCL_AIM_VEL_DEAD)
    {
        return 0;
    }

    lmag = sqrtf(lvx * lvx + lvy * lvy);

    if (lmag < RCL_AIM_VEL_DEAD)
    {
        return 0;
    }

    agree = (lvx * tvx + lvy * tvy) / (lmag * sqrtf(tvx * tvx + tvy * tvy));

    if (agree < RCL_AIM_CONF_MIN)
    {
        return 0;
    }

    *vxOut = tvx;
    *vyOut = tvy;
    *confOut = agree;

    return 1;
}

static float rcl_aim_intercept(float px, float py, float tvx, float tvy, float shot)
{
    float a = tvx * tvx + tvy * tvy - shot * shot;
    float b = 2.0f * (px * tvx + py * tvy);
    float c = px * px + py * py;
    float disc;
    float t1;
    float t2;

    if (shot <= 1.0f)
    {
        return -1.0f;
    }
    if (fabsf(a) < 0.0001f)
    {
        return -1.0f;
    }

    disc = b * b - 4.0f * a * c;

    if (disc < 0.0f)
    {
        return -1.0f;
    }

    disc = sqrtf(disc);

    t1 = (-b - disc) / (2.0f * a);
    t2 = (-b + disc) / (2.0f * a);

    if (t1 > 0.0f && (t2 <= 0.0f || t1 < t2))
    {
        return t1;
    }
    if (t2 > 0.0f)
    {
        return t2;
    }

    return -1.0f;
}

static int rcl_aim_lead(float px, float py, float *ox, float *oy)
{
    float tvx = 0.0f;
    float tvy = 0.0f;
    float conf = 0.0f;
    float shot;
    float dist;
    float t;
    float lead;

    *ox = 0.0f;
    *oy = 0.0f;

    if (!rcl_aim_target_vel(&tvx, &tvy, &conf))
    {
        return 0;
    }

    shot = rcl_aim_shot_speed();
    dist = sqrtf(px * px + py * py);
    t = rcl_aim_intercept(px, py, tvx, tvy, shot);

    if (t < 0.0f)
    {
        t = dist / shot;
    }

    t *= conf;

    if (t < 0.0f)
    {
        t = 0.0f;
    }
    if (t > RCL_AIM_T_MAX)
    {
        t = RCL_AIM_T_MAX;
    }

    *ox = tvx * t;
    *oy = tvy * t;

    lead = sqrtf((*ox) * (*ox) + (*oy) * (*oy));

    if (lead > RCL_AIM_LEAD_MAX)
    {
        *ox = (*ox) / lead * RCL_AIM_LEAD_MAX;
        *oy = (*oy) / lead * RCL_AIM_LEAD_MAX;
    }

    return 1;
}

void rcl_run_autoaim(void)
{
    if (!rcl_flag_state("aimbot"))
    {
        return;
    }

    if (!rcl_addr_getinstance || !rcl_addr_getownchar || !rcl_addr_battlescreen)
    {
        return;
    }

    void *battleMode = ((fn_get_inst_t)rcl_addr_getinstance)();
    if (!rcl_object_plausible(battleMode))
    {
        return;
    }

    void *ownChar = ((fn_get_own_char_t)rcl_addr_getownchar)(battleMode);
    if (!rcl_object_plausible(ownChar))
    {
        return;
    }

    int ownX = rcl_addr_getx ? ((fn_get_coord_t)rcl_addr_getx)(ownChar) : 0;
    int ownY = rcl_addr_gety ? ((fn_get_coord_t)rcl_addr_gety)(ownChar) : 0;
    int ownTeam = rcl_addr_getteam ? ((fn_get_team_t)rcl_addr_getteam)(battleMode) : 0;

    void *objMgr = nullptr;
    if (!rcl_read_ptr((uintptr_t)battleMode + RCL_MODE_MANAGER_OFF, &objMgr))
    {
        return;
    }
    if (!rcl_object_plausible(objMgr))
    {
        return;
    }

    void *rawObjects = nullptr;
    int32_t count = 0;

    if (!rcl_read_ptr((uintptr_t)objMgr + RCL_MGR_ARRAY_OFF, &rawObjects))
    {
        return;
    }
    if (!rcl_read_int((uintptr_t)objMgr + RCL_MGR_COUNT_OFF, &count))
    {
        return;
    }

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0)
    {
        return;
    }

    if (count > SCAN_MAX)
    {
        count = SCAN_MAX;
    }
    void *probe = nullptr;

    if (!rcl_read_ptr((uintptr_t)objects, &probe))
    {
        return;
    }
    if (count > 1 && !rcl_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe))
    {
        return;
    }

    float closestDistSq = 1.0e18f;
    float closestDistSqBlind = 1.0e18f;
    int targetX = 0;
    int targetY = 0;
    int blindX = 0;
    int blindY = 0;
    void *bestObj = nullptr;
    void *blindObj = nullptr;
    BOOL found = NO;

    for (int i = 0; i < count; i++)
    {
        void *obj = objects[i];

        if (!obj || obj == ownChar)
        {
            continue;
        }
        if (!rcl_object_plausible(obj))
        {
            continue;
        }

        uint8_t objDead = 0;
        if (!rcl_read_byte((uintptr_t)obj + RCL_OBJ_DEADFLAG_OFF, &objDead))
        {
            continue;
        }
        if (objDead)
        {
            continue;
        }

        int32_t team = 0;
        if (!rcl_read_int((uintptr_t)obj + RCL_OBJ_TEAM_OFF, &team))
        {
            continue;
        }
        if (team == ownTeam)
        {
            continue;
        }

        int ex = rcl_addr_getx ? ((fn_get_coord_t)rcl_addr_getx)(obj) : 0;
        int ey = rcl_addr_gety ? ((fn_get_coord_t)rcl_addr_gety)(obj) : 0;

        float dx = (float)(ex - ownX);
        float dy = (float)(ey - ownY);
        float distSq = dx * dx + dy * dy;

        if (distSq > 1.0f && distSq < closestDistSqBlind)
        {
            closestDistSqBlind = distSq;
            blindX = ex;
            blindY = ey;
            blindObj = obj;
        }

        if (distSq <= 1.0f || distSq >= closestDistSq)
        {
            continue;
        }
        if (!rcl_wall_los((float)ownX, (float)ownY, (float)ex, (float)ey, RCL_WALL_BLOCKS_PROJECTILES))
        {
            continue;
        }

        closestDistSq = distSq;
        targetX = ex;
        targetY = ey;
        bestObj = obj;
        found = YES;
    }

    if (!found && closestDistSqBlind < 1.0e18f)
    {
        targetX = blindX;
        targetY = blindY;
        bestObj = blindObj;
        found = YES;
    }

    if (!found)
    {
        return;
    }

    {
        float px = (float)(targetX - ownX);
        float py = (float)(targetY - ownY);
        float lx = 0.0f;
        float ly = 0.0f;

        if ((uintptr_t)bestObj != rcl_aim_hist_id)
        {
            rcl_aim_hist_reset((uintptr_t)bestObj);
        }

        rcl_aim_hist_push((float)targetX, (float)targetY);

        if (rcl_aim_lead(px, py, &lx, &ly))
        {
            targetX += (int)lx;
            targetY += (int)ly;
        }
    }

    if (!rcl_ok((float)targetX, -RCL_AIM_COORD_MAX, RCL_AIM_COORD_MAX) ||
        !rcl_ok((float)targetY, -RCL_AIM_COORD_MAX, RCL_AIM_COORD_MAX))
    {
        return;
    }

    void *screen = nullptr;
    if (!rcl_read_ptr(rcl_addr_battlescreen, &screen))
    {
        return;
    }

    if (!rcl_object_plausible(screen))
    {
        if (!rcl_aim_rejected)
        {
            rcl_aim_rejected = YES;
        }
        return;
    }

    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;

    if (!rcl_addr_writable(fireX, 4) || !rcl_addr_writable(fireY, 4))
    {
        if (!rcl_aim_rejected)
        {
            rcl_aim_rejected = YES;
        }
        return;
    }

    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}
