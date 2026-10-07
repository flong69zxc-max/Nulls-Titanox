#include "recoil.h"


static float rcl_dodge_px = 0.0f;
static float rcl_dodge_py = 0.0f;
static int rcl_dodge_have = 0;
static float rcl_freest_hx = 0.0f;
static float rcl_freest_hy = 0.0f;
static int rcl_freest_have = 0;

static int rcl_dodge_is_proj(uintptr_t obj) {
    void *vt = NULL;
    intptr_t cls = 0;

    if (!obj) return 0;
    if (!rcl_read_ptr(obj, &vt) || !vt) return 0;

    cls = (intptr_t)((uintptr_t)vt - rcl_base);

#if RCL_DODGE_PROJ_ONLY
    return (cls == (intptr_t)RCL_CLASS_PROJ_RVA) ? 1 : 0;
#else
    (void)cls;

    return 1;
#endif
}

uint64_t rcl_drop_slow = 0;

uint64_t rcl_drop_fast = 0;

uint64_t rcl_drop_blink = 0;


float rcl_spd_min = 0.0f;

float rcl_spd_max = 0.0f;






__thread int rcl_in_drive = 0;




int32_t rcl_pl_mine[RCL_PLAYER_MAX];












int rcl_new_tick = -1;

int rcl_prev_seg = -1;








int rcl_mates = 0;

int rcl_enemies = 0;

int rcl_agree = -1;





uint64_t rcl_human = 0;









int32_t rcl_tx = 0;

int32_t rcl_ty = 0;

int rcl_active = 0;

int rcl_js_live = 0;

int rcl_life_now = 0;

int rcl_life_3(float px, float py) {
    uint8_t dead = 0;

    if (!rcl_manager_count) return 0;
    if (!rcl_own_elem) return 3;
    if (rcl_read_byte(rcl_own_elem + (uintptr_t)RCL_OBJ_DEADFLAG_OFF, &dead) && dead != 0) return 2;
    if (px == 0.0f && py == 0.0f) return 0;

    return 1;
}

uint64_t rcl_js_tick = 0;

int rcl_js_owns(void) {
    if (!rcl_js_live) return 0;
    if (rcl_ticks_a > rcl_js_tick && (rcl_ticks_a - rcl_js_tick) > 2) return 0;

    return 1;
}

int rcl_build_tick = -1;






int rcl_have_angle = 0;

float rcl_angle = 0.0f;

float rcl_tx_a = 0.0f;

float rcl_ty_a = 0.0f;

int rcl_moving = 0;

float rcl_start_x = 0.0f;

float rcl_start_y = 0.0f;




int rcl_drive_logs = 0;
















float rcl_last_x_b = 0.0f;

float rcl_last_y_b = 0.0f;

int rcl_last_ok = 0;


float rcl_mom_live = 0.0f;

int rcl_crit_reaction = 0;

uint64_t rcl_crit_last = 0;





float rcl_shot_speed[RCL_PROJ_MAX];








uint64_t rcl_react_min = 0;

uint64_t rcl_react_max = 0;


int rcl_track_gid[RCL_SEG_MAX];

int rcl_track_hit[RCL_SEG_MAX];

float rcl_last_dist = 0.0f;

int rcl_released = 0;

float rcl_own_vx = 0.0f;

float rcl_own_vy = 0.0f;

float rcl_prev_own_x = 0.0f;

float rcl_prev_own_y = 0.0f;

uint64_t rcl_prev_own_tick = 0;

float rcl_track_min[RCL_SEG_MAX];

int rcl_track_pside[RCL_SEG_MAX];

float rcl_track_ux[RCL_SEG_MAX];

float rcl_track_uy[RCL_SEG_MAX];


uint64_t rcl_howto_logs = 0;

int rcl_side_last = -1;

int rcl_shot_key[RCL_SEG_MAX];



uint64_t rcl_own_obj_last = 0;

uint64_t rcl_no_threat_since = 0;

int rcl_pick_key_c = 0;

int rcl_pick_key_t = 0;





int rcl_sel[RCL_SEL_MAX];

int rcl_sel_n = 0;

uint64_t rcl_pos_skips = 0;

int rcl_cand_now[RCL_CAND];

int rcl_cand_seen = 0;

int32_t rcl_prev_x = 0;

int32_t rcl_prev_y = 0;






int rcl_cal_off_seen = -1;

float rcl_cal_rad_seen = 0.0f;

int rcl_cal_n = 0;









int rcl_ok(float v, float lo, float hi) {
    if (!(v >= lo && v <= hi)) return 0;

    return 1;
}

int rcl_rad_off = -1;



float rcl_rad_est = 0.0f;


float rcl_own_r = 0.0f;



int rcl_clip_win = 0;


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

float rcl_proj_radius(const rcl_proj_t *p, float speed) {
    uintptr_t base = 0;
    int off = 0;

    if (!RCL_GEOM) return 0.0f;
    if (!p) return 0.0f;
    if (speed < 1.0f) return 0.0f;

    base = p->elem;

    {
        void *def = NULL;

        if (rcl_read_ptr(p->elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) && def)
            base = (uintptr_t)def;
    }

    if (rcl_rad_off >= 0) {
        float r = 0.0f;

        if (base && rcl_read_float(base + (uintptr_t)rcl_rad_off, &r) &&
            rcl_ok(r, RCL_RADIUS_MIN, RCL_RADIUS_MAX)) {
            rcl_rad_est = r;

            return r;
        }

        return rcl_ok(rcl_rad_est, RCL_RADIUS_MIN, RCL_RADIUS_MAX) ? rcl_rad_est : 0.0f;
    }

    if (!base) return 0.0f;

    for (off = RCL_CAL_OFF_LO; off <= RCL_CAL_OFF_HI; off += RCL_CAL_STEP) {
        float v = 0.0f;
        float r = 0.0f;
        float d = 0.0f;


        if (!rcl_read_float(base + (uintptr_t)off, &v)) continue;
        if (!rcl_ok(v, 1.0f, 1.0e6f)) continue;

        d = v - speed;
        if (d < 0.0f) d = -d;
        if (d > speed * RCL_CAL_TOL) continue;

        if (!rcl_read_float(base + (uintptr_t)off + 4, &r)) continue;
        if (!rcl_ok(r, RCL_RADIUS_MIN, RCL_RADIUS_MAX)) continue;

        if (rcl_cal_off_seen == off && rcl_ok(rcl_cal_rad_seen - r, -1.0f, 1.0f)) {
            rcl_cal_n++;
        } else {
            rcl_cal_off_seen = off;
            rcl_cal_rad_seen = r;
            rcl_cal_n = 1;
        }

        if (rcl_cal_n < RCL_CAL_TICKS) return 0.0f;

        rcl_rad_off = off + 4;
        rcl_rad_est = r;


        return r;
    }




    return RCL_DATA_PROJ_R;
}

void rcl_build(void) {
    int k;

    rcl_seg_count = 0;
    rcl_build_tick = (int)rcl_ticks_a;

    for (k = 0; k < RCL_PROJ_MAX; k++) {
        const rcl_proj_t *p = &rcl_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        float len = 0.0f;
        float speed = 0.0f;
        float rem = 0.0f;
        rcl_seg_t *s = NULL;

        if (!p->elem) continue;
        if (!p->hasPrev && !RCL_ONESHOT) continue;
        if (rcl_seg_count >= RCL_SEG_MAX) break;

        if (RCL_TEAM_FILTER && rcl_team_trust && rcl_own_team_seen &&
            p->team == rcl_own_team_a) continue;

        if (RCL_TEAM_STRICT && rcl_own_team_b >= 0 && p->team == rcl_own_team_b) continue;
        if (rcl_proj_mine(p)) continue;

        if (!p->hasPrev) {

            uint64_t age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 1;

            vx = (float)(p->x - p->spawnX) / (float)age;
            vy = (float)(p->y - p->spawnY) / (float)age;

            if (fabsf(vx) < 0.5f && fabsf(vy) < 0.5f) continue;

        } else if (!rcl_proj_vel(p, &vx, &vy)) continue;

        len = sqrtf(vx * vx + vy * vy);

        if (len < RCL_MIN_PROJ_SPEED) continue;

        speed = len * 60.0f;

        if (speed < 1.0f) speed = 1.0f;

        if (speed > rcl_shot_speed[k]) rcl_shot_speed[k] = speed;
        if (rcl_shot_speed[k] > 1.0f) speed = rcl_shot_speed[k];

        if (rcl_blacklisted(speed, 0.0f)) {

            continue;
        }

        if (rcl_spd_min < 1.0f || speed < rcl_spd_min) rcl_spd_min = speed;
        if (speed > rcl_spd_max) rcl_spd_max = speed;

        rem = speed * (RCL_PROJ_LIFE_MS / 1000.0f);

        if (rem > RCL_DEFAULT_RANGE) rem = RCL_DEFAULT_RANGE;
        if (rem < 1.0f) rem = 1.0f;

        {
            float nx = vx / len;
            float ny = vy / len;
            float px0 = rcl_dodge_have ? rcl_dodge_px : (float)rcl_own_x;
            float py0 = rcl_dodge_have ? rcl_dodge_py : (float)rcl_own_y;
            float rx = (float)p->x - px0;
            float ry = (float)p->y - py0;
            float rvx = vx - rcl_own_vx;
            float rvy = vy - rcl_own_vy;
            float rate = rx * rvx + ry * rvy;
            float denom = rvx * rvx + rvy * rvy;
            float tStar = (denom > 0.5f) ? (-rate / denom) : 0.0f;
            float cx = rx + rvx * tStar;
            float cy = ry + rvy * tStar;
            float miss = sqrtf(cx * cx + cy * cy);
            float reach = RCL_DATA_OWN_R + RCL_DATA_PROJ_R + RCL_INFLATE;
            float dist2own = sqrtf(rx * rx + ry * ry);
            float flightTicks = rem / (speed / 60.0f);
            float ix = (float)p->x + nx * speed / 60.0f * tStar;
            float iy = (float)p->y + ny * speed / 60.0f * tStar;
            int hits = (tStar >= 0.0f && tStar <= flightTicks && miss <= reach) ? 1 : 0;
            int inView = (dist2own <= RCL_VIEW_RANGE) ? 1 : 0;
            int keep = (hits || inView) ? 1 : 0;


            if (rcl_dodge_have) {
                float toOwn = (px0 - (float)p->x) * nx + (py0 - (float)p->y) * ny;

                if (toOwn < 0.0f && !keep) continue;
                if (toOwn - RCL_OVERSHOOT > rem) continue;
                if (toOwn > 0.0f && rem > toOwn + RCL_OVERSHOOT) rem = toOwn + RCL_OVERSHOOT;
            }
        }

        if (RCL_REJECT) {
            int rule = 0;

            if (speed < RCL_MIN_SPEED) rule = 1;
            else if (speed > RCL_MAX_SPEED) rule = 2;
            else if ((p->qtick > p->ptick) && (p->qtick - p->ptick) <= RCL_BLINK_TICKS &&
                     rem < RCL_BLINK_REM) rule = 3;

            if (rule) {
                if (rule == 1) rcl_drop_slow++;
                else if (rule == 2) rcl_drop_fast++;
                else rcl_drop_blink++;


                continue;
            }
        }

        {
            float rem0 = rem;

            rem = rcl_clip_range((float)p->x, (float)p->y, vx / len, vy / len, rem);


            if (rem < rem0 - 0.5f) rcl_clip_win++;
        }

        s = &rcl_seg[rcl_seg_count++];
        s->gid = p->gid;
        s->ax = (float)p->x;
        s->ay = (float)p->y;
        s->dirX = vx / len;
        s->dirY = vy / len;
        s->bx = s->ax + s->dirX * rem;
        s->by = s->ay + s->dirY * rem;
        s->speed = speed;
        s->remaining = rem;
        {
            float pr = rcl_proj_radius(p, speed);
            float orr = rcl_own_radius();
            float ir = pr + orr + RCL_RADIUS_MARGIN;

            if (!rcl_ok(pr, 0.0f, RCL_RADIUS_MAX)) pr = 0.0f;
            if (!rcl_ok(orr, 0.0f, RCL_RADIUS_MAX)) orr = 0.0f;

            ir = pr + orr + RCL_RADIUS_MARGIN;

            if (!rcl_ok(ir, 1.0f, RCL_RADIUS_MAX * 4.0f)) {
                ir = RCL_DODGE_CLEAR_R;
            }

            if (ir < RCL_DODGE_CLEAR_R) ir = RCL_DODGE_CLEAR_R;

            s->inflatedR = ir;
        }
    }

    if (rcl_seg_test > 0) rcl_seg_frac = (rcl_seg_clip * 100) / rcl_seg_test;
}

float rcl_seg_dist2(float px, float py, const rcl_seg_t *s) {
    float abx = s->bx - s->ax;
    float aby = s->by - s->ay;
    float apx = px - s->ax;
    float apy = py - s->ay;
    float denom = abx * abx + aby * aby;
    float t = 0.0f;
    float cx = 0.0f;
    float cy = 0.0f;

    if (denom > 0.0001f) t = (apx * abx + apy * aby) / denom;

    if (t < 0.0f) t = 0.0f;
    else if (t > 1.0f) t = 1.0f;

    cx = s->ax + abx * t - px;
    cy = s->ay + aby * t - py;

    return cx * cx + cy * cy;
}

int rcl_threatened(float x, float y) {
    int i;

    for (i = 0; i < rcl_seg_count; i++) {
        float d2 = rcl_seg_dist2(x, y, &rcl_seg[i]);

        if (d2 <= rcl_seg[i].inflatedR * rcl_seg[i].inflatedR) return 1;
    }

    return 0;
}

float rcl_clearance_a(float x, float y) {
    float best = 1000000.0f;
    int i;

    for (i = 0; i < rcl_seg_count; i++) {
        float d = sqrtf(rcl_seg_dist2(x, y, &rcl_seg[i])) - rcl_seg[i].inflatedR;

        if (d < best) best = d;
    }

    return best;
}

float rcl_eta_ms(float x, float y) {
    float best = 1.0e9f;
    int i = 0;

    for (i = 0; i < rcl_seg_count; i++) {
        const rcl_seg_t *s = &rcl_seg[i];
        float abx = s->bx - s->ax;
        float aby = s->by - s->ay;
        float denom = abx * abx + aby * aby;
        float len = 0.0f;
        float raw = 0.0f;
        float cx = 0.0f;
        float cy = 0.0f;
        float d = 0.0f;
        float rem = 0.0f;
        float ms = 0.0f;

        len = sqrtf(denom);

        if (len <= 0.001f) continue;
        if (s->speed <= 1.0f) continue;

        raw = ((x - s->ax) * abx + (y - s->ay) * aby) / denom;

        if (raw < 0.0f) continue;
        if (raw > 1.0f) continue;

        cx = s->ax + abx * raw - x;
        cy = s->ay + aby * raw - y;
        d = sqrtf(cx * cx + cy * cy) - s->inflatedR;

        if (d > RCL_HIT_MARGIN) continue;
        if (d < 0.0f) d = 0.0f;

        rem = (1.0f - raw) * len;
        ms = rem / s->speed * 1000.0f;

        if (ms < best) best = ms;
    }

    return best;
}

int rcl_imminent(float x, float y) {
    float look = RCL_RAGE_FORCE ? (RCL_MODE_TUNE ? rcl_look_ms() : RCL_LOOKAHEAD_MS_2)
                               : RCL_LOOKAHEAD_MS;

    if (look > RCL_LOOKAHEAD_MAX) look = RCL_LOOKAHEAD_MAX;
    if (look <= 0.0f) return 0;
    if (rcl_seg_count <= 0) return 0;

    return (rcl_eta_ms(x, y) <= look) ? 1 : 0;
}

int rcl_flee(float px, float py, float *tx, float *ty) {
    if (RCL_JS_DODGE) return 0;
    int i = 0;
    int best = -1;
    float bestMs = 1.0e9f;
    float cx = 0.0f;
    float cy = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;
    float len = 0.0f;

    if (!RCL_FLEE) return 0;
    if (rcl_seg_count <= 0) return 0;

    for (i = 0; i < rcl_seg_count; i++) {
        const rcl_seg_t *s = &rcl_seg[i];
        float abx = s->bx - s->ax;
        float aby = s->by - s->ay;
        float den = abx * abx + aby * aby;
        float t = 0.0f;
        float qx = 0.0f;
        float qy = 0.0f;
        float d = 0.0f;
        float ms = 0.0f;

        if (den > 0.0001f) t = ((px - s->ax) * abx + (py - s->ay) * aby) / den;

        if (t < 0.0f) t = 0.0f;
        if (t > 1.0f) t = 1.0f;

        qx = s->ax + abx * t;
        qy = s->ay + aby * t;
        d = sqrtf((qx - px) * (qx - px) + (qy - py) * (qy - py)) - s->inflatedR;

        if (d < 0.0f) d = 0.0f;

        ms = (s->speed > 1.0f) ? (d / s->speed * 1000.0f) : 1.0e9f;

        if (ms < bestMs) {
            bestMs = ms;
            best = i;
            cx = qx;
            cy = qy;
        }
    }

    if (best < 0) return 0;

    dx = px - cx;
    dy = py - cy;
    len = sqrtf(dx * dx + dy * dy);

    if (len < 1.0f) {
        dx = -(rcl_seg[best].by - rcl_seg[best].ay);
        dy = (rcl_seg[best].bx - rcl_seg[best].ax);
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) return 0;
    }

    *tx = px + dx / len * RCL_FLEE_STEP;
    *ty = py + dy / len * RCL_FLEE_STEP;

    return 1;
}

int rcl_body_blocked_2(float px, float py, float dirX, float dirY, float len) {
    float ex = 0.0f;
    float ey = 0.0f;
    int i = 0;

    if (!RCL_MATE_AVOID) return 0;
    if (rcl_pl_n <= 0) return 0;
    if (len < 1.0f) return 0;

    ex = px + dirX * len;
    ey = py + dirY * len;

    for (i = 0; i < rcl_pl_n; i++) {
        if (rcl_seg_dist(px, py, ex, ey, (float)rcl_pl_x[i], (float)rcl_pl_y[i]) <
            RCL_MATE_CLEAR_2) {
            return 1;
        }
    }

    return 0;
}

float rcl_body_score(float px, float py, float dirX, float dirY, float len) {
    float ex = px + dirX * len;
    float ey = py + dirY * len;
    float best = 1.0e9f;
    int i = 0;

    if (rcl_pl_n <= 0) return best;

    for (i = 0; i < rcl_pl_n; i++) {
        float d = rcl_seg_dist(px, py, ex, ey, (float)rcl_pl_x[i], (float)rcl_pl_y[i]);

        if (d < best) best = d;
    }

    return best;
}

                                                                                                                                              

float rcl_clearance_b(float px, float py, float dirX, float dirY) {
    float speed = rcl_speed();
    float best = 1.0e9f;
    int i = 0;
    int k = 0;

    for (i = 0; i < rcl_sel_n; i++) {
        const rcl_seg_t *seg = &rcl_seg[rcl_sel[i]];

        for (k = 0; k <= RCL_STEPS; k++) {
            float t = RCL_HORIZON * ((float)k / (float)RCL_STEPS);
            float qx = px + dirX * speed * t;
            float qy = py + dirY * speed * t;
            float d = rcl_seg_dist(qx, qy, seg->ax, seg->ay, seg->bx, seg->by) - seg->inflatedR;

            if (d < best) best = d;
        }
    }


    return best;
}

float rcl_score(float px, float py, float dirX, float dirY, float len) {
    rcl_select(px, py);

    return rcl_clearance_b(px, py, dirX, dirY) +
           RCL_BODY_W * rcl_body_score_2(px, py, dirX, dirY, len);
}

float rcl_body_score_2(float px, float py, float dirX, float dirY, float len) {
    float ex = px + dirX * len;
    float ey = py + dirY * len;
    float best = 1.0e9f;
    int i = 0;

    if (!RCL_BODY_SCAN) return rcl_body_score(px, py, dirX, dirY, len);
    if (rcl_dodge_probe_usable <= 0) return rcl_body_score(px, py, dirX, dirY, len);

    for (i = 0; i < rcl_dodge_probe_usable; i++) {
        const rcl_obj_t *o = &rcl_dodge_probe_list[i];
        float d = 0.0f;

        if (o->gid < RCL_PLAYER_GID) continue;
        if (o->gid >= RCL_SHOT_GID) continue;
        if (rcl_own_elem_2 && o->object == rcl_own_elem_2) continue;

        d = rcl_seg_dist(px, py, ex, ey, (float)o->x, (float)o->y);

        if (d < best) best = d;
    }

    return best;
}

void rcl_unblock(float px, float py, float len, float *dirX, float *dirY) {
    static const float rot[12] = { 15.0f, -15.0f, 30.0f, -30.0f, 45.0f, -45.0f,
                                   60.0f, -60.0f, 90.0f, -90.0f, 135.0f, -135.0f };
    const float rad = 3.14159265358979f / 180.0f;
    float base = *dirX;
    float baseY = *dirY;
    float bestScore = 0.0f;
    float baseScore = 0.0f;
    float bestX = 0.0f;
    float bestY = 0.0f;
    int i = 0;

    if (!RCL_MATE_AVOID) return;
    if (len < 1.0f) return;

    bestScore = rcl_score(px, py, base, baseY, len);
    baseScore = bestScore;
    bestX = base;
    bestY = baseY;

    if (rcl_last_ok) {
        bestScore += RCL_DATA_MOMENTUM * (base * rcl_last_x_b + baseY * rcl_last_y_b);
        baseScore = bestScore;
    }

    for (i = 0; i < 12; i++) {
        float a = rot[i] * rad;
        float c = cosf(a);
        float sn = sinf(a);
        float rx = base * c - baseY * sn;
        float ry = base * sn + baseY * c;
        float score = rcl_score(px, py, rx, ry, len);

        if (rcl_last_ok) score += RCL_DATA_MOMENTUM * (rx * rcl_last_x_b + ry * rcl_last_y_b);

        if (score > bestScore) {
            bestScore = score;
            bestX = rx;
            bestY = ry;
        }
    }

    if (rcl_last_ok && bestX != base &&
        (bestScore - (rcl_score(px, py, base, baseY, len) +
                      RCL_DATA_MOMENTUM * (base * rcl_last_x_b + baseY * rcl_last_y_b))) <
            RCL_DATA_BAND) {
        bestX = base;
        bestY = baseY;
    }

    *dirX = bestX;
    *dirY = bestY;

    if (bestX != 0.0f || bestY != 0.0f) {
        float n = sqrtf(bestX * bestX + bestY * bestY);

        if (n > 0.0001f) {
            rcl_last_x_b = bestX / n;
            rcl_last_y_b = bestY / n;
            rcl_last_ok = 1;
        }
    }

}

int rcl_valid_point(float x, float y) {
    int32_t cx = (int32_t)x;
    int32_t cy = (int32_t)y;

    rcl_clamp(&cx, &cy);

    if (cx != (int32_t)x || cy != (int32_t)y) return 0;

    if (rcl_mate_blocked(x, y)) {

        return 0;
    }

    if (rcl_body_blocked(x, y, (float)rcl_own_x, (float)rcl_own_y)) {
        return 0;
    }

    if (rcl_enemy_blocked(x, y, (float)rcl_own_x, (float)rcl_own_y)) {

        return 0;
    }

    return 1;
}

int rcl_walk_into_bullet(float px, float py, float dirX, float dirY, float travel) {
    float pvx = dirX * RCL_DATA_SPEED;
    float pvy = dirY * RCL_DATA_SPEED;
    float horizon = travel / RCL_DATA_SPEED;
    int i;

    for (i = 0; i < rcl_seg_count; i++) {
        const rcl_seg_t *s = &rcl_seg[i];
        float bvx = s->dirX * s->speed;
        float bvy = s->dirY * s->speed;
        float rpx = s->ax - px;
        float rpy = s->ay - py;
        float rvx = bvx - pvx;
        float rvy = bvy - pvy;
        float rvSq = rvx * rvx + rvy * rvy;
        float t = 0.0f;
        float sepX = 0.0f;
        float sepY = 0.0f;

        if (rpx * rvx + rpy * rvy > 0.0f) continue;
        if (rvSq < 0.0000000001f) continue;

        t = -(rpx * rvx + rpy * rvy) / rvSq;

        if (t < 0.0f) continue;
        if (t > horizon) continue;
        if (s->speed > 0.001f && t > s->remaining / s->speed) continue;

        sepX = rpx + rvx * t;
        sepY = rpy + rvy * t;

        if (sepX * sepX + sepY * sepY <= s->inflatedR * s->inflatedR) return 1;
    }

    return 0;
}

float rcl_safe_angle(float px, float py, float desiredDeg, int *ok) {
    static const float offsets[6] = { 15.0f, 30.0f, 45.0f, 60.0f, 75.0f, 90.0f };
    const float deg = 3.14159265358979f / 180.0f;
    float scan = RCL_EXTEND_DEFAULT * 1.5f;
    int i;

    *ok = 1;

    if (!rcl_walk_into_bullet(px, py, cosf(desiredDeg * deg), sinf(desiredDeg * deg), scan) &&
        !rcl_body_blocked_2(px, py, cosf(desiredDeg * deg), sinf(desiredDeg * deg), scan)) {
        return desiredDeg;
    }

    for (i = 0; i < 6; i++) {
        float a = desiredDeg + offsets[i];
        float b = desiredDeg - offsets[i];

        if (!rcl_walk_into_bullet(px, py, cosf(a * deg), sinf(a * deg), scan) &&
            !rcl_body_blocked_2(px, py, cosf(a * deg), sinf(a * deg), scan)) return a;

        if (!rcl_walk_into_bullet(px, py, cosf(b * deg), sinf(b * deg), scan) &&
            !rcl_body_blocked_2(px, py, cosf(b * deg), sinf(b * deg), scan)) return b;
    }

    *ok = 0;

    return desiredDeg;
}

int rcl_passed(float px, float py) {
    float ax = rcl_tx_a - rcl_start_x;
    float ay = rcl_ty_a - rcl_start_y;
    float len2 = ax * ax + ay * ay;
    float bx = 0.0f;
    float by = 0.0f;

    if (len2 <= 0.0f) return 1;

    bx = px - rcl_start_x;
    by = py - rcl_start_y;

    return (ax * bx + ay * by) >= len2 ? 1 : 0;
}
static float rcl_js_clear(float px, float py, float mvx, float mvy) {
    float best = 1.0e9f;
    int i = 0;
    int s = 0;

    for (i = 0; i < rcl_seg_count; i++) {
        const rcl_seg_t *sg = &rcl_seg[i];
        float maxT = RCL_HORIZON_S;

        if (sg->speed > 1.0f) {
            float life = sg->remaining / sg->speed;

            if (life > 0.0f && life < maxT) maxT = life;
        }

        for (s = 0; s <= RCL_JS_CLEAR_STEPS; s++) {
            float ts = maxT * (float)s / (float)RCL_JS_CLEAR_STEPS;
            float d = rcl_seg_dist(px + mvx * ts, py + mvy * ts, sg->ax, sg->ay, sg->bx, sg->by) -
                      sg->inflatedR;

            if (d < best) best = d;
        }
    }

    return best;
}

int rcl_freest(float px, float py, float *tx, float *ty) {
    int i = 0;
    int n = RCL_JS_DODGE ? RCL_DIR_COUNT : RCL_FREEST_ANGLES;
    float radius = RCL_JS_DODGE ? RCL_REACH : RCL_STEP_a;
    float speed = RCL_DATA_SPEED;
    float nowClear = rcl_js_clear(px, py, 0.0f, 0.0f);
    float bestScore = -1.0e18f;
    float bestEta = 0.0f;
    float bestRoom = 0.0f;
    float bestX = 0.0f;
    float bestY = 0.0f;
    int bestOk = 0;

    if (radius < 1.0f) radius = RCL_STEP_a;
    if (rcl_walk_step > 0.01f) speed = rcl_walk_step * 60.0f;
    if (speed < 120.0f) speed = 120.0f;
    if (speed > 1200.0f) speed = 1200.0f;

    for (i = 0; i < n; i++) {
        float rad = (2.0f * 3.14159265358979f * (float)i) / (float)n;
        float ux = cosf(rad);
        float uy = sinf(rad);
        float ex = px + ux * radius;
        float ey = py + uy * radius;
        float eta = 0.0f;
        float room = 1000000.0f;
        float score = 0.0f;
        int32_t cxi = (int32_t)ex;
        int32_t cyi = (int32_t)ey;
        int k = 0;

        rcl_clamp(&cxi, &cyi);

        if (rcl_walk_into_bullet(px, py, ux, uy, speed * RCL_HORIZON_S)) {

            continue;
        }

        score = rcl_js_clear(px, py, ux * speed, uy * speed);

        if (rcl_freest_have) score += rcl_mom_live * (ux * rcl_freest_hx + uy * rcl_freest_hy);
        if (rcl_clip_range(px, py, ux, uy, radius) < radius - 1.0f) score -= RCL_WALL_PENALTY;

        for (k = 0; k < rcl_pl_n; k++) {
            float d = 0.0f;

            if (rcl_pl_mine[k]) continue;

            d = rcl_seg_dist(px, py, ex, ey, (float)rcl_pl_x[k], (float)rcl_pl_y[k]);

            if (d < room) room = d;
        }

        if (room > RCL_BODY_CLEAR) room = RCL_BODY_CLEAR;

        score = score + room * RCL_BODY_GAIN;
        eta = rcl_eta_ms(ex, ey);

        if (eta > 1.0e8f) eta = 1.0e8f;

        if (score > bestScore) {
            bestScore = score;
            bestEta = eta;
            bestRoom = room;
            bestX = ex;
            bestY = ey;
            bestOk = 1;
        }
    }

    if (!bestOk) return 0;

    if (RCL_JS_DODGE) {
        rcl_freest_hx = (bestX - px) / radius;
        rcl_freest_hy = (bestY - py) / radius;
        rcl_freest_have = 1;

        if (bestScore <= nowClear) {
            if (!rcl_crit_reaction) {

                return 0;
            }

        }
    }

    if (!RCL_ESCAPE && bestRoom < RCL_FREEST_MIN) return 0;

    *tx = bestX;
    *ty = bestY;


    return 1;
}

float rcl_clear_at(float px, float py, int i) {
    return rcl_seg_dist(px, py, rcl_seg[i].ax, rcl_seg[i].ay, rcl_seg[i].bx, rcl_seg[i].by) - rcl_seg[i].inflatedR;
}

float rcl_all_clear(float x, float y) {
    int k = 0;
    float best = 1.0e9f;

    for (k = 0; k < rcl_seg_count; k++) {
        float c = rcl_clear_at(x, y, k);

        if (c < best) best = c;
    }

    return best;
}

int rcl_wall_blocked(float x0, float y0, float x1, float y1) {
    int32_t ox = (int32_t)x1;
    int32_t oy = (int32_t)y1;

    if (!rcl_live || !rcl_armed) return -1;
    if (rcl_w <= 0 || rcl_h <= 0) return -1;

    return rcl_clip_walk((int32_t)x0, (int32_t)y0, (int32_t)x1, (int32_t)y1,
                         (int32_t)RCL_TILE_SIZE, rcl_grid, rcl_w, rcl_h, &ox, &oy);
}
                                                                                                                                                                                                                                                                                                

                                                                                                                                                                                                                                                                                                                                                                                                                                       

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               

static void rcl_state_reset(void) {
    rcl_moving = 0;
    rcl_side_last = -1;
    rcl_last_dist = 0.0f;
}

static void rcl_dodge_state_tick(float px, float py) {
    uintptr_t own = rcl_own_obj();

    if (rcl_prev_own_tick != 0 && rcl_ticks_a > rcl_prev_own_tick) {
        float dt = (float)(rcl_ticks_a - rcl_prev_own_tick);

        rcl_own_vx = (px - rcl_prev_own_x) / dt;
        rcl_own_vy = (py - rcl_prev_own_y) / dt;
    }

    rcl_prev_own_x = px;
    rcl_prev_own_y = py;
    rcl_prev_own_tick = rcl_ticks_a;

    if (own != rcl_own_obj_last) {
        if (rcl_own_obj_last != 0) rcl_state_reset();

        rcl_own_obj_last = own;
        rcl_no_threat_since = 0;
        rcl_released = 0;

        return;
    }

    if (rcl_seg_count > 0) {
        rcl_no_threat_since = 0;
        rcl_released = 0;

        return;
    }

    if (rcl_moving && rcl_wall_blocked(px, py, rcl_tx_a, rcl_ty_a) == 1) {
        rcl_state_reset();

        rcl_released = 1;

        rcl_enqueue((int32_t)px, (int32_t)py);


        return;
    }

    if (rcl_released) return;

    if (rcl_no_threat_since == 0) {
        rcl_no_threat_since = rcl_ticks_a;

        return;
    }

    if ((rcl_ticks_a - rcl_no_threat_since) < (uint64_t)RCL_NO_THREAT_TICKS) return;

    rcl_state_reset();
    rcl_released = 1;

    rcl_enqueue((int32_t)px, (int32_t)py);

}

#define RCL_DODGE_SAFETY 28.0f
#define RCL_DODGE_NEAR 2500.0f
#define RCL_DODGE_T_URGENT 0.9f
#define RCL_DODGE_T_FIELD 1.8f
#define RCL_DODGE_DIRS 64
#define RCL_DODGE_PERP_W 2.4f
#define RCL_DODGE_AWAY_W 1.0f
#define RCL_DODGE_INTENT_W 1.2f
#define RCL_DODGE_CHAR_SPEED 720.0f
#define RCL_DODGE_MAX_DIST_SQ 25000000.0f
#define RCL_DODGE_INERTIA_TICKS 24
#define RCL_DODGE_CAND_MAX 160
#define RCL_DODGE_CONE 1.0f
#define RCL_DODGE_REACH 4.0f
#define RCL_DODGE_SPEED_MIN 300
#define RCL_DODGE_SPEED_MAX 8500
#define RCL_DODGE_DIRT_MIN 6.0f
#define RCL_DODGE_DIRT_SPAN 1.5f

typedef struct {
    float x;
    float y;
    float dx;
    float dy;
    float speed;
    float radius;
    int32_t gid;
} rcl_dodge_proj_t;

static int rcl_js_picked = 0;
static int rcl_dodge_foes = 0;
static int rcl_dodge_unk = 0;
static float rcl_dodge_ox = 0.0f;


uint64_t rcl_aim_frames = 0;


static float rcl_dodge_oy = 0.0f;

int32_t rcl_aim_tx = 0;

int32_t rcl_aim_ty = 0;
static int rcl_dodge_detail = 0;

static int rcl_dodge_own_pos(float *ox, float *oy) {
    int32_t x = 0;
    int32_t y = 0;

    if (!rcl_own_elem) return 0;
    if (!rcl_read_int(rcl_own_elem + (uintptr_t)OFF_GAMEOBJ_X, &x)) return 0;
    if (!rcl_read_int(rcl_own_elem + (uintptr_t)OFF_GAMEOBJ_Y, &y)) return 0;
    if (x < -200000 || x > 200000) return 0;
    if (y < -200000 || y > 200000) return 0;
    if (x == 0 && y == 0) return 0;

    *ox = (float)x;
    *oy = (float)y;

    return 1;
}

static double rcl_meas_sec = 0.0;
static uint64_t rcl_meas_tick = 0;
static float rcl_meas_tps = RCL_MEAS_FPS;

static void rcl_meas_clocks(void) {
    double now = CFAbsoluteTimeGetCurrent();

    if (rcl_meas_sec > 0.0 && rcl_ticks_a > rcl_meas_tick) {
        double span = now - rcl_meas_sec;

        if (span > 0.25) {
            float rate = (float)((double)(rcl_ticks_a - rcl_meas_tick) / span);

            if (rate > 5.0f && rate < 240.0f) rcl_meas_tps = rate;

            rcl_meas_sec = now;
            rcl_meas_tick = rcl_ticks_a;
        }
    } else {
        rcl_meas_sec = now;
        rcl_meas_tick = rcl_ticks_a;
    }
}

static rcl_dodge_proj_t rcl_dodge_projs[RCL_PROJ_MAX];
static rcl_dodge_proj_t rcl_dodge_prev[RCL_PROJ_MAX];
static int rcl_dodge_n = 0;
static float rcl_dodge_last_x = 0.0f;
static float rcl_dodge_last_y = 0.0f;
static int rcl_dodge_have_last = 0;
static uint64_t rcl_dodge_last_tick = 0;
static float rcl_dodge_dir[RCL_DODGE_DIRS][2];
static int rcl_dodge_dirs_built = 0;
static float rcl_dodge_speed = RCL_DODGE_CHAR_SPEED;

static void rcl_dodge_build_dirs(void) {
    int i;

    if (rcl_dodge_dirs_built) return;

    for (i = 0; i < RCL_DODGE_DIRS; i++) {
        float a = 6.283185307179586f * (float)i / (float)RCL_DODGE_DIRS;

        rcl_dodge_dir[i][0] = cosf(a);
        rcl_dodge_dir[i][1] = sinf(a);
    }

    rcl_dodge_dirs_built = 1;
}

static void rcl_dodge_norm(float x, float y, float *ox, float *oy) {
    float len = sqrtf(x * x + y * y);

    if (len < 1e-6f) {
        *ox = 1.0f;
        *oy = 0.0f;

        return;
    }

    *ox = x / len;
    *oy = y / len;
}

static void rcl_dodge_speed_probe(void) {
    void *def = NULL;
    int32_t raw = 0;

    if (!rcl_own_elem) return;
    if (!rcl_read_ptr(rcl_own_elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) || !def) return;
    if (!rcl_read_int((uintptr_t)def + (uintptr_t)OFF_CHARDATA_SPEED, &raw)) return;
    if (raw < RCL_DODGE_SPEED_MIN || raw > RCL_DODGE_SPEED_MAX) return;

    rcl_dodge_speed = (float)raw;
}
static int rcl_dodge_my_team(void) {
    int32_t v = 0;

    if (rcl_own_elem && rcl_read_int(rcl_own_elem + (uintptr_t)RCL_OBJ_TEAM_OFF, &v)) {
        if (v == 0 || v == 1) return v;
    }

    if (rcl_own_team_b == 0 || rcl_own_team_b == 1) return rcl_own_team_b;

    return -1;
}

static void rcl_dodge_collect(float px, float py) {
    int i;
    int n = 0;
    int myTeam = -1;

    rcl_dodge_foes = 0;
    rcl_dodge_unk = 0;
    rcl_dodge_detail = 0;

    rcl_dodge_build_dirs();
    rcl_dodge_speed_probe();
    rcl_meas_clocks();

    for (i = 0; i < RCL_PROJ_MAX; i++) {
        const rcl_proj_t *p = &rcl_projs[i];
        rcl_dodge_proj_t *q;
        uint8_t dead = 0;
        float mx;
        float my;
        float dx = 0.0f;
        float dy = 0.0f;
        float len = 0.0f;
        uint64_t dt;
        float speed;
        float pr = RCL_PROJ_RADIUS_DEFAULT;

        if (!p->elem) continue;

        if (myTeam < 0) myTeam = rcl_dodge_my_team();

        if (rcl_dodge_detail < RCL_DODGE_DETAIL_MAX && (rcl_ticks_a % RCL_DODGE_DETAIL_EVERY) == 0) {
            int32_t rawTeam = -1;
            uintptr_t rawVt = 0;

            rcl_read_int(p->elem + (uintptr_t)RCL_OBJ_TEAM_OFF, &rawTeam);
            if (rcl_read_ptr(p->elem, (void **)&rawVt) && rawVt >= rcl_base) rawVt -= rcl_base;

            rcl_dodge_detail++;

        }

        if (p->team >= 0 && (p->team == rcl_own_team_a || (myTeam >= 0 && p->team == myTeam))) {

            continue;
        }

        if (p->team == 0 || p->team == 1) rcl_dodge_foes++;
        else rcl_dodge_unk++;

        if (!rcl_read_byte(p->elem + (uintptr_t)RCL_OBJ_DEADFLAG_OFF, &dead)) continue;
        if (dead != 0) continue;

        mx = (float)p->x - px;
        my = (float)p->y - py;

        if (mx * mx + my * my > RCL_DODGE_MAX_DIST_SQ) continue;

        if (p->hasPrev) {
            dx = (float)(p->x - p->px);
            dy = (float)(p->y - p->py);
            len = sqrtf(dx * dx + dy * dy);

            if (len <= RCL_DODGE_DIRT_MIN) continue;

            dx /= len;
            dy /= len;
        } else {
            float angle = 0.0f;

            if (!rcl_read_float(p->elem + (uintptr_t)RCL_PROJ_ANGLE_OFF, &angle)) continue;
            if (!(angle > -100.0f && angle < 100.0f)) continue;

            dx = cosf(angle);
            dy = sinf(angle);
        }

        {
            float bx = (float)p->x - px;
            float by = (float)p->y - py;
            float br = rcl_own_radius();

            if (br < RCL_OWN_RADIUS_MIN) br = RCL_DATA_OWN_R;
            if (sqrtf(bx * bx + by * by) < br) continue;
        }

        {
            float lx = (float)rcl_aim_tx - px;
            float ly = (float)rcl_aim_ty - py;
            float ll = sqrtf(lx * lx + ly * ly);

            if (ll > 1.0f && sqrtf(mx * mx + my * my) < RCL_AIM_HIT_DIST) {
                float aimDot = (dx * lx + dy * ly) / ll;

            }
        }

        dt = (p->ptick > 0 && rcl_ticks_a > p->ptick) ? (rcl_ticks_a - p->ptick) : 0;

        speed = 0.0f;

        if (len > 0.0f && dt > 0 && (float)dt <= RCL_MEAS_DT_MAX) {
            speed = (len / (float)dt) * rcl_meas_tps;
        }

        if (speed < RCL_MEAS_SPEED_MIN || speed > RCL_MEAS_SPEED_MAX) speed = RCL_JS_SPEED_FALLBACK;

        if (speed < RCL_MEAS_SPEED_MIN) speed = RCL_MEAS_SPEED_MIN;
        if (speed > RCL_MEAS_SPEED_MAX) speed = RCL_MEAS_SPEED_MAX;

        {
            float rr = rcl_proj_radius(p, speed);
            float toward = 0.0f;
            float r = 0.0f;
            float lateral = 0.0f;
            float dist = 0.0f;

            if (rr > 0.0f) pr = rr;

            toward = mx * dx + my * dy;
            r = rcl_own_radius() + pr + RCL_DODGE_SAFETY * RCL_DODGE_DETECT_SAFETY;
            dist = sqrtf(mx * mx + my * my);
            lateral = mx * mx + my * my - toward * toward;

            if ((rcl_ticks_a % 5) == 0 && rcl_dodge_detail < 10) {
                const char *verdict = "hit";

                rcl_dodge_detail++;

                if (sqrtf(((float)p->spawnX - px) * ((float)p->spawnX - px) +
                          ((float)p->spawnY - py) * ((float)p->spawnY - py)) <=
                    rcl_own_radius() + RCL_DODGE_SPAWN_MARGIN) verdict = "own-spawn";
                else if (p->team >= 0 && (p->team == rcl_own_team_a || (myTeam >= 0 && p->team == myTeam))) verdict = "own-side";
                else if (toward >= 0.0f) verdict = "away";
                else if (lateral > r * r * RCL_DODGE_CONE) verdict = "wide";
                else if (dist / speed > RCL_DODGE_T_FIELD * RCL_DODGE_REACH) verdict = "far";

            }

            {
                float sx = (float)p->px - px;
                float sy = (float)p->py - py;
                float sr = rcl_own_radius();

                if (sr < RCL_OWN_RADIUS_MIN) sr = RCL_DATA_OWN_R;

                if (p->hasPrev && sqrtf(sx * sx + sy * sy) <= sr) {

                    continue;
                }
            }

            if (toward >= 0.0f) {

                continue;
            }

            if (lateral > r * r * RCL_DODGE_CONE) {

                continue;
            }

            if (dist / speed > RCL_DODGE_T_FIELD * RCL_DODGE_REACH) {

                continue;
            }
        }

        q = &rcl_dodge_projs[n];
        q->x = (float)p->x;
        q->y = (float)p->y;
        q->dx = dx;
        q->dy = dy;
        q->speed = speed;
        q->radius = pr;
        q->gid = p->gid;

        n++;
    }

    rcl_dodge_n = n;
}

static void rcl_dodge_commit(void) {

    if (rcl_dodge_n > 0) memcpy(rcl_dodge_prev, rcl_dodge_projs, (size_t)rcl_dodge_n * sizeof(rcl_dodge_proj_t));
}

static int rcl_dodge_urgent(const rcl_dodge_proj_t *p, float mx, float my, float mr) {
    float dx = mx - p->x;
    float dy = my - p->y;
    float vx = p->dx * p->speed;
    float vy = p->dy * p->speed;
    float c1 = dx * vx + dy * vy;
    float c2;
    float tHit;
    float cx;
    float cy;
    float r;
    float ddx;
    float ddy;

    if (c1 <= 0.0f) return 0;

    c2 = vx * vx + vy * vy;
    if (c2 <= 0.0f) return 0;

    tHit = c1 / c2;
    if (tHit > RCL_DODGE_T_URGENT) return 0;

    cx = p->x + vx * tHit;
    cy = p->y + vy * tHit;
    r = mr + p->radius + RCL_DODGE_SAFETY;
    ddx = mx - cx;
    ddy = my - cy;

    return (ddx * ddx + ddy * ddy) <= r * r;
}

static float rcl_dodge_score(float dx, float dy, float mx, float my, float mr,
                           int haveIntent, float ix, float iy) {
    int i;
    float score = 0.0f;

    for (i = 0; i < rcl_dodge_n; i++) {
        const rcl_dodge_proj_t *p = &rcl_dodge_projs[i];
        float r = mr + p->radius + RCL_DODGE_SAFETY;
        float vx = p->dx * p->speed - dx * rcl_dodge_speed;
        float vy = p->dy * p->speed - dy * rcl_dodge_speed;
        float rx = p->x - mx;
        float ry = p->y - my;
        float a = vx * vx + vy * vy;
        float b = 2.0f * (rx * vx + ry * vy);
        float c = rx * rx + ry * ry;
        float minD2 = c;
        float danger;

        if (a > 1e-6f) {
            float tMin = -b / (2.0f * a);

            if (tMin > 0.0f && tMin <= RCL_DODGE_T_FIELD) {
                minD2 = c + b * tMin + a * tMin * tMin;
            } else if (tMin > RCL_DODGE_T_FIELD) {
                minD2 = c + b * RCL_DODGE_T_FIELD + a * RCL_DODGE_T_FIELD * RCL_DODGE_T_FIELD;
            }
        }

        danger = (minD2 < r * r) ? 2500.0f : (r * r) / (minD2 > 50.0f ? minD2 : 50.0f);
        score += danger;
    }

    if (haveIntent && (ix != 0.0f || iy != 0.0f)) {
        score -= (dx * ix + dy * iy) * RCL_DODGE_INTENT_W * 15.0f;
    }

    if (rcl_dodge_have_last && (rcl_ticks_a - rcl_dodge_last_tick) < (uint64_t)RCL_DODGE_INERTIA_TICKS) {
        score -= (dx * rcl_dodge_last_x + dy * rcl_dodge_last_y) * 45.0f;
    }

    return score;
}

static int rcl_dodge_unsafe(float dx, float dy, float mx, float my, float mr) {
    int i;

    for (i = 0; i < rcl_dodge_n; i++) {
        const rcl_dodge_proj_t *p = &rcl_dodge_projs[i];
        float r = mr + p->radius + RCL_DODGE_SAFETY;
        float vx = p->dx * p->speed - dx * rcl_dodge_speed;
        float vy = p->dy * p->speed - dy * rcl_dodge_speed;
        float rx = p->x - mx;
        float ry = p->y - my;
        float a = vx * vx + vy * vy;
        float b = 2.0f * (rx * vx + ry * vy);
        float c = rx * rx + ry * ry - r * r;
        float disc;
        float t1;

        if (c < 0.0f) return 1;
        if (a <= 1e-6f) continue;

        disc = b * b - 4.0f * a * c;
        if (disc < 0.0f) continue;

        t1 = (-b - sqrtf(disc)) / (2.0f * a);
        if (t1 > 0.0f && t1 <= RCL_DODGE_T_FIELD) return 1;
    }

    return 0;
}

static int rcl_dodge_danger(float mx, float my, float mr) {
    int i;

    for (i = 0; i < rcl_dodge_n; i++) {
        const rcl_dodge_proj_t *p = &rcl_dodge_projs[i];
        float r = mr + p->radius + RCL_DODGE_SAFETY * 2.5f;
        float dx = mx - p->x;
        float dy = my - p->y;
        float distSq = dx * dx + dy * dy;
        float vx;
        float vy;
        float c1;
        float c2;
        float tHit;

        if (distSq <= r * r) return 1;
        if (distSq <= RCL_DODGE_NEAR * RCL_DODGE_NEAR) return 1;

        vx = p->dx * p->speed;
        vy = p->dy * p->speed;
        c1 = dx * vx + dy * vy;
        if (c1 <= 0.0f) continue;

        c2 = vx * vx + vy * vy;
        if (c2 <= 0.0f) continue;

        tHit = c1 / c2;
        if (tHit > RCL_DODGE_T_FIELD) continue;

        {
            float cx = p->x + vx * tHit;
            float cy = p->y + vy * tHit;
            float ddx = mx - cx;
            float ddy = my - cy;

            if (ddx * ddx + ddy * ddy <= r * r) return 1;
        }
    }

    return 0;
}

static int rcl_dodge_urgent_dir(float mx, float my, float mr, int haveIntent, float ix, float iy,
                              float *ox, float *oy) {
    float cand[RCL_DODGE_CAND_MAX][2];
    int n = 0;
    int urgent = 0;
    int i;
    int best = -1;
    float bestScore = 1e18f;

    for (i = 0; i < rcl_dodge_n && n + 2 < RCL_DODGE_CAND_MAX; i++) {
        const rcl_dodge_proj_t *p = &rcl_dodge_projs[i];
        float ax;
        float ay;
        float tx;
        float ty;

        if (!rcl_dodge_urgent(p, mx, my, mr)) continue;

        urgent++;

        rcl_dodge_norm(mx - p->x, my - p->y, &ax, &ay);

        tx = (-p->dy) * RCL_DODGE_PERP_W + ax * RCL_DODGE_AWAY_W + (haveIntent ? ix * 0.6f : 0.0f);
        ty = (p->dx) * RCL_DODGE_PERP_W + ay * RCL_DODGE_AWAY_W + (haveIntent ? iy * 0.6f : 0.0f);
        rcl_dodge_norm(tx, ty, &cand[n][0], &cand[n][1]);
        n++;

        tx = (p->dy) * RCL_DODGE_PERP_W + ax * RCL_DODGE_AWAY_W + (haveIntent ? ix * 0.6f : 0.0f);
        ty = (-p->dx) * RCL_DODGE_PERP_W + ay * RCL_DODGE_AWAY_W + (haveIntent ? iy * 0.6f : 0.0f);
        rcl_dodge_norm(tx, ty, &cand[n][0], &cand[n][1]);
        n++;
    }

    if (urgent == 0) return 0;

    for (i = 0; i < 16 && n < RCL_DODGE_CAND_MAX; i++) {
        float a = 6.283185307179586f * (float)i / 16.0f;

        cand[n][0] = cosf(a);
        cand[n][1] = sinf(a);
        n++;
    }

    for (i = 0; i < n; i++) {
        float s = rcl_dodge_score(cand[i][0], cand[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    if (best < 0) return urgent;

    *ox = cand[best][0];
    *oy = cand[best][1];

    return urgent;
}

static void rcl_dodge_best_dir(float mx, float my, float mr, int haveIntent, float ix, float iy,
                             float *ox, float *oy) {
    int i;
    int best = 0;
    float bestScore = 1e18f;

    for (i = 0; i < RCL_DODGE_DIRS; i++) {
        float s = rcl_dodge_score(rcl_dodge_dir[i][0], rcl_dodge_dir[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    *ox = rcl_dodge_dir[best][0];
    *oy = rcl_dodge_dir[best][1];
}

static int rcl_dodge_apply(float inX, float inY, float mx, float my, float mr, int haveIntent,
                         float ix, float iy, float *ox, float *oy) {
    int i;
    int best = -1;
    float bestScore = 1e18f;

    *ox = inX;
    *oy = inY;

    if (!rcl_dodge_unsafe(inX, inY, mx, my, mr)) return 0;

    for (i = 0; i < RCL_DODGE_DIRS; i++) {
        float s;

        if (rcl_dodge_unsafe(rcl_dodge_dir[i][0], rcl_dodge_dir[i][1], mx, my, mr)) continue;

        s = rcl_dodge_score(rcl_dodge_dir[i][0], rcl_dodge_dir[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    if (best < 0) return 2;

    *ox = rcl_dodge_dir[best][0];
    *oy = rcl_dodge_dir[best][1];

    return 1;
}

static int rcl_dodge_decide(float px, float py, float *outX, float *outY, int *urgentOut,
                          int *voOut) {
    float iX = 0.0f;
    float iY = 0.0f;
    int haveIntent = 0;
    float mr;
    float baseX = 0.0f;
    float baseY = 0.0f;
    float safeX = 0.0f;
    float safeY = 0.0f;
    int urgent;
    int vo;

    if (urgentOut) *urgentOut = 0;
    if (voOut) *voOut = 0;

    rcl_dodge_ox = px;
    rcl_dodge_oy = py;
    rcl_dodge_own_pos(&rcl_dodge_ox, &rcl_dodge_oy);

    rcl_dodge_collect(rcl_dodge_ox, rcl_dodge_oy);



    mr = rcl_own_radius();

    if (mr < RCL_OWN_RADIUS_MIN) mr = RCL_DATA_OWN_R;

    if (!rcl_dodge_danger(rcl_dodge_ox, rcl_dodge_oy, mr)) {
        rcl_dodge_commit();

        return 0;
    }

    if (rcl_have_angle) {
        iX = cosf(rcl_angle);
        iY = sinf(rcl_angle);
        haveIntent = 1;
    }

    urgent = rcl_dodge_urgent_dir(rcl_dodge_ox, rcl_dodge_oy, mr, haveIntent, iX, iY, &baseX, &baseY);

    if (urgent == 0) rcl_dodge_best_dir(rcl_dodge_ox, rcl_dodge_oy, mr, haveIntent, iX, iY, &baseX, &baseY);

    vo = rcl_dodge_apply(baseX, baseY, rcl_dodge_ox, rcl_dodge_oy, mr, haveIntent, iX, iY, &safeX, &safeY);

    rcl_dodge_last_x = safeX;
    rcl_dodge_last_y = safeY;
    rcl_dodge_have_last = 1;
    rcl_dodge_last_tick = rcl_ticks_a;

    rcl_dodge_commit();

    *outX = safeX;
    *outY = safeY;

    if (urgentOut) *urgentOut = (urgent > 0) ? 1 : 0;
    if (voOut) *voOut = vo;

    return 1;
}

int rcl_aim_ok = 0;


static int32_t rcl_aim_hx[RCL_AIM_PRED_MAX];
static int32_t rcl_aim_hy[RCL_AIM_PRED_MAX];
static uint64_t rcl_aim_ht[RCL_AIM_PRED_MAX];
static int rcl_aim_hn = 0;
static int rcl_aim_hslot = -1;

static void rcl_aim_push(int idx, int32_t x, int32_t y) {
    int i;

    if (idx != rcl_aim_hslot) {
        rcl_aim_hn = 0;
        rcl_aim_hslot = idx;
    }

    if (rcl_aim_hn >= RCL_AIM_PRED_MAX) {
        for (i = 1; i < RCL_AIM_PRED_MAX; i++) {
            rcl_aim_hx[i - 1] = rcl_aim_hx[i];
            rcl_aim_hy[i - 1] = rcl_aim_hy[i];
            rcl_aim_ht[i - 1] = rcl_aim_ht[i];
        }

        rcl_aim_hn = RCL_AIM_PRED_MAX - 1;
    }

    rcl_aim_hx[rcl_aim_hn] = x;
    rcl_aim_hy[rcl_aim_hn] = y;
    rcl_aim_ht[rcl_aim_hn] = rcl_ticks_a;

    rcl_aim_hn++;
}

static int rcl_aim_lead(int32_t *tx, int32_t *ty, float dist) {
    float vx = 0.0f;
    float vy = 0.0f;
    float wsum = 0.0f;
    float lead;
    int i;

    if (rcl_aim_hn < 2) return 0;

    for (i = 1; i < rcl_aim_hn; i++) {
        float w = (float)i;
        float dt = 0.0f;

        if (rcl_aim_ht[i] > rcl_aim_ht[i - 1]) {
            dt = (float)(rcl_aim_ht[i] - rcl_aim_ht[i - 1]) / rcl_meas_tps;
        }

        if (dt <= 0.0f) continue;

        vx += ((float)(rcl_aim_hx[i] - rcl_aim_hx[i - 1]) / dt) * w;
        vy += ((float)(rcl_aim_hy[i] - rcl_aim_hy[i - 1]) / dt) * w;
        wsum += w;
    }

    if (wsum <= 0.0f) return 0;

    vx /= wsum;
    vy /= wsum;

    lead = RCL_AIM_PRED_COEF * dist / RCL_AIM_PROJ_SPEED;

    if (!(lead > 0.0f) || lead > 4.0f) return 0;

    *tx = (int32_t)((float)rcl_aim_hx[rcl_aim_hn - 1] + vx * lead);
    *ty = (int32_t)((float)rcl_aim_hy[rcl_aim_hn - 1] + vy * lead);

    return 1;
}

int rcl_aim(void) {
    float bestD2 = RCL_AIM_RANGE * RCL_AIM_RANGE;
    int32_t mx = 0;
    int32_t my = 0;
    int best = -1;
    int i = 0;

    if (!RCL_AIM) return 0;

    rcl_aim_frames++;

    if (rcl_life_now != 1) return 0;
    if (!rcl_enemy_n) return 0;
    if ((rcl_aim_frames % RCL_AIM_INTERVAL) != 0) return 0;

    mx = (int32_t)rcl_dodge_ox;
    my = (int32_t)rcl_dodge_oy;

    if (mx == 0 && my == 0) return 0;

    for (i = 0; i < rcl_enemy_n && i < RCL_PLAYER_MAX; i++) {
        float ex = (float)(rcl_enemy_x[i] - mx);
        float ey = (float)(rcl_enemy_y[i] - my);
        float d2 = ex * ex + ey * ey;

        if (d2 < bestD2) {
            bestD2 = d2;
            best = i;
        }
    }

    if (best < 0) return 0;

    rcl_aim_push(best, rcl_enemy_x[best], rcl_enemy_y[best]);

    rcl_aim_tx = rcl_enemy_x[best];
    rcl_aim_ty = rcl_enemy_y[best];

    {
        int32_t leadX = rcl_aim_tx;
        int32_t leadY = rcl_aim_ty;

        if (rcl_aim_lead(&leadX, &leadY, sqrtf(bestD2))) {
            rcl_aim_tx = leadX;
            rcl_aim_ty = leadY;
        }
    }

    rcl_aim_ok = rcl_enqueue_type(rcl_aim_tx, rcl_aim_ty, (int)RCL_TYPE_ATTACK);


    return rcl_aim_ok;
}

int rcl_decide(int32_t ownX, int32_t ownY) {
    float px = (float)ownX;
    float py = (float)ownY;
    float tx = 0.0f;
    float ty = 0.0f;
    int picked = 0;
    int threatened = 0;
    int stick = 0;
    int safeOk = 0;
    float desiredDeg = 0.0f;

    rcl_js_live = 0;
    rcl_js_tick = rcl_ticks_a;

    rcl_life_now = rcl_life_3(px, py);


    if (rcl_life_now != 1) {
        rcl_moving = 0;
        rcl_released = 1;

        return 0;
    }

    rcl_aim();

    rcl_arm(px, py);

    rcl_dodge_px = px;
    rcl_dodge_py = py;
    rcl_dodge_have = 1;

    rcl_build();

    if (rcl_seg_count != rcl_prev_seg) {
        rcl_new_tick = (int)rcl_ticks_a;
        rcl_prev_seg = rcl_seg_count;

        if (RCL_REACT_CRIT && (rcl_ticks_a - rcl_crit_last) >= RCL_DATA_CRIT_EVERY) {
            rcl_crit_reaction = 1;
            rcl_crit_last = rcl_ticks_a;
        }
    }


    rcl_dodge_state_tick(px, py);

    rcl_stat_tick(px, py);

    threatened = rcl_threatened(px, py);

    if (rcl_seg_count > 0 && rcl_clearance_a(px, py) < RCL_ENGAGE_NEAR) {
        threatened = 1;
    }

    if (RCL_RAGE_FORCE && rcl_seg_count > 0) {
        if (!RCL_HIT_ONLY || rcl_imminent(px, py)) {
            threatened = 1;
        }
    }

    if (rcl_imminent(px, py)) {
        threatened = 1;
    }

    rcl_have_angle = 0;

    stick = rcl_joy_angle(&rcl_angle);

    if (stick) {
        rcl_have_angle = 1;
        desiredDeg = rcl_angle * 180.0f / 3.14159265358979f;
    }

    {
        int jsUrgent = 0;
        int jsVo = 0;
        float jsX = 0.0f;
        float jsY = 0.0f;

        rcl_js_picked = rcl_dodge_decide(px, py, &jsX, &jsY, &jsUrgent, &jsVo);

        if (rcl_js_picked) {
            tx = px + jsX * RCL_REACH;
            ty = py + jsY * RCL_REACH;
            picked = 1;

        }
    }

    threatened = rcl_js_picked;
    rcl_js_live = rcl_js_picked;

    if (rcl_js_picked) {
        rcl_tx_a = tx;
        rcl_ty_a = ty;
        rcl_moving = 1;
        rcl_start_x = px;
        rcl_start_y = py;

        rcl_enqueue((int32_t)tx, (int32_t)ty);
        rcl_move_to((int32_t)tx, (int32_t)ty, px, py);

        if (rcl_new_tick >= 0) {
            uint64_t react = rcl_ticks_a - (uint64_t)rcl_new_tick;

            if (rcl_react_min == 0 || react < rcl_react_min) rcl_react_min = react;
            if (react > rcl_react_max) rcl_react_max = react;
        }
    } else if (rcl_moving && rcl_passed(px, py)) {
        rcl_moving = 0;
    } else if (rcl_moving && stick) {
        float safe = rcl_safe_angle(px, py, desiredDeg, &safeOk);

        if (!safeOk && RCL_FLEE) {
            if (rcl_flee(px, py, &rcl_tx_a, &rcl_ty_a)) rcl_moving = 1;

        }

        if (safeOk) {
            float rad = safe * 3.14159265358979f / 180.0f;
            float ex = px + cosf(rad) * RCL_EXTEND_DEFAULT;
            float ey = py + sinf(rad) * RCL_EXTEND_DEFAULT;

            if (rcl_valid_point(ex, ey)) {
                rcl_tx_a = ex;
                rcl_ty_a = ey;
            }
        }
    } else if (rcl_moving) {
        rcl_tx_a = px;
        rcl_ty_a = py;
        rcl_moving = 0;
        rcl_released = 1;

        rcl_enqueue((int32_t)px, (int32_t)py);
        rcl_move_to((int32_t)px, (int32_t)py, px, py);
    } else {
        rcl_tx_a = px;
        rcl_ty_a = py;
    }

    rcl_walk_want(rcl_moving, ownX, ownY, (int32_t)rcl_tx_a, (int32_t)rcl_ty_a);




    return picked;
}

void rcl_autododge(void) {
    static int tagOnce = 0;


    if (!tagOnce) {
        tagOnce = 1;

    }

    rcl_input_release();

    rcl_stick(0, 0.0f, 0.0f);

    rcl_route(rcl_active);



    if (RCL_STATE_EVERY <= 1 || (rcl_ticks_a % (uint64_t)RCL_STATE_EVERY) == 0) rcl_state();

    rcl_paircal();

    rcl_obj_t objects[RCL_OBJECT_MAX];
    uintptr_t source = 0;
    const char *sourceKind = "none";
    int sourceIsMode = 0;
    int32_t predictX = 0;
    int32_t predictY = 0;
    int rejected = 0;
    int usable = 0;
    int ownIndex = -1;
    int32_t ownTeam = 0;
    int ownX = 0;
    int ownY = 0;
    int64_t ownBest = 0;
    float escapeX = 0.0f;
    float escapeY = 0.0f;
    int threats = 0;
    int threatsAlive = 0;

    rcl_dodge_calls++;


    if (!rcl_base) return;

    if (rcl_dodge_calls <= RCL_CALL_LOGS ||
        (rcl_dodge_calls % RCL_CALL_EVERY) == 0) {
        uintptr_t probeOwn = 0;
        int32_t probeGid = 0;
        int32_t probeTeam = 0;
        int32_t probeCount = 0;


        rcl_own_by_min_gid(rcl_tick_array, rcl_tick_count, &probeOwn, &probeGid);

        if (probeOwn) rcl_read_int(probeOwn + RCL_OBJ_TEAM_OFF, &probeTeam);
        if (rcl_players_object) rcl_read_int(rcl_players_object + RCL_MGR_COUNT_OFF, &probeCount);

        {
            int listIdx = -1;
            const char *listFrom = "none";
            int32_t listGid = -1;

            if (rcl_own_from_list(rcl_dodge_probe_list, rcl_dodge_probe_usable, &listIdx, &listFrom)) {
                listGid = rcl_dodge_probe_list[listIdx].gid;
            }

        }

    }

    sourceIsMode = (rcl_scene_object != 0);

    if (sourceIsMode) {
        source = rcl_scene_object;
        sourceKind = "mode";
    } else if (rcl_players_object) {
        source = rcl_players_object;
        sourceKind = "manager";
    } else if (rcl_objvote_best_owner && rcl_objvote_best_teamcount >= RCL_OWNER_VOTE_TEAMS_MIN &&
               rcl_objvote_max_votes >= RCL_OWNER_VOTE_MIN) {
        source = rcl_objvote_best_owner;
        sourceKind = "objvote";
    } else if (rcl_trail_count > 0 && rcl_trail_best >= 0 && rcl_trail_best < rcl_trail_count) {
        source = (uintptr_t)rcl_trail[rcl_trail_best].manager;
        sourceKind = "trail";
    }

    if (!source) {
        rcl_no_source_passes++;

        if (rcl_no_source_passes >= 5 && !rcl_route_logged) {
            rcl_route_logged = 1;

        }
    } else {
        rcl_no_source_passes = 0;
    }

    if (!sourceIsMode && !rcl_players_object && source && strcmp(sourceKind, "trail") == 0 &&
        rcl_trail_best >= 0 && rcl_trail_best < rcl_trail_count && rcl_trail[rcl_trail_best].live == 0) {
    }


    rcl_ticks_a++;

    if (rcl_wrote_valid && !rcl_check_done &&
        (rcl_ticks_a - rcl_wrote_tick) >= RCL_VERIFY_FRAMES) {
        int32_t nowX = 0;
        int32_t nowY = 0;
        int32_t ctrlX_2 = 0;
        int32_t ctrlY_2 = 0;
        int32_t mgrX_2 = 0;
        int32_t mgrY_2 = 0;
        uintptr_t ctrl_2 = 0;
        uintptr_t mgr_2 = 0;

        ctrl_2 = rcl_controller();

        if (ctrl_2) {
            rcl_read_int(ctrl_2 + RCL_MOVE_X_OFF, &ctrlX_2);
            rcl_read_int(ctrl_2 + RCL_MOVE_Y_OFF, &ctrlY_2);
        }

        if (ctrl_2 && rcl_read_ptr(ctrl_2 + RCL_MGR_OFF, (void **)&mgr_2) && mgr_2) {
            rcl_read_int(mgr_2 + RCL_MOVE_X_OFF, &mgrX_2);
            rcl_read_int(mgr_2 + RCL_MOVE_Y_OFF, &mgrY_2);
        } else {
            mgr_2 = 0;
        }

        if (rcl_scene_object && rcl_read_int(rcl_scene_object + RCL_MODE_PREDICTX_OFF, &nowX) &&
            rcl_read_int(rcl_scene_object + RCL_MODE_PREDICTY_OFF, &nowY)) {

            {
                void *array = NULL;
                int32_t count = 0;
                int shown = 0;

                if (rcl_players_object &&
                    rcl_read_ptr(rcl_players_object + RCL_MGR_ARRAY_OFF, &array) && array &&
                    rcl_read_int(rcl_players_object + RCL_MGR_COUNT_OFF, &count)) {
                    for (int32_t i = 0; i < count && shown < RCL_POS_DUMPS; i++) {
                        void *element = NULL;
                        int32_t px = 0;
                        int32_t py = 0;

                        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element)) break;
                        if (!element) continue;

                        rcl_read_int((uintptr_t)element + RCL_OBJ_X_OFF, &px);
                        rcl_read_int((uintptr_t)element + RCL_OBJ_Y_OFF, &py);

                        shown++;

                    }
                }
            }
        }

        rcl_check_done = 1;
    }

    if (!source) {
        return;
    }

    if (rcl_setpred_state < 0) {
        rcl_setpred_state = rcl_verify_setprediction();
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        void *resolved = NULL;
        int changed = (rcl_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;

        if (sourceIsMode && rcl_hop_chosen == 1 && rcl_tick_object) {
            resolved = (void *)rcl_tick_object;
        } else if (sourceIsMode) {
            if (!rcl_read_ptr(source + RCL_MODE_MANAGER_OFF, &resolved) || !resolved) {
                resolved = NULL;
            }
        } else {
            resolved = (void *)source;
        }

        managerChanged = ((uintptr_t)resolved != rcl_manager_ptr);


        {
            int32_t liveCount = 0;

            if (resolved) rcl_read_int((uintptr_t)resolved + RCL_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && rcl_hop_chosen == 1 &&
                (liveCount != rcl_walk_count ||
                 (rcl_walk_tick != rcl_ticks_b && (rcl_ticks_b % RCL_WALK_EVERY) == 0))) {
                rcl_walk_count = liveCount;
                rcl_walk_tick = rcl_ticks_b;
                periodic = 1;

            }
        }

        if (!rcl_probe_done || changed || managerChanged || periodic ||
            (!rcl_coord_ok && probeNow > rcl_probe_last_ms + RCL_REPROBE_MS)) {
            rcl_probe_object = source;
            rcl_probe_last_ms = probeNow;
            rcl_manager_ptr = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || managerChanged || !rcl_probe_done);
                    rcl_probe((uintptr_t)resolved, rcl_scene_object, loud);

                if (loud) rcl_discriminate((uintptr_t)resolved);
            } else {
            }
        }
    }


    if (!rcl_setpred_state) {
        return;
    }

    {
        int gateOpen = (rcl_coord_ok || rcl_coord_usable >= RCL_MIN_USABLE) ? 1 : 0;

        if (gateOpen != rcl_gate_last) {
            rcl_gate_last = gateOpen;

        }
    }

    if (!rcl_coord_ok && rcl_coord_usable < RCL_MIN_USABLE) return;

    if (!rcl_scene_object) {
        return;
    }

    memset(objects, 0, sizeof(objects));


    usable = rcl_collect(rcl_manager_ptr, objects, RCL_OBJECT_MAX, &rejected);

    if (usable < RCL_MIN_USABLE_2) {

        return;
    }

    if (!rcl_read_int(rcl_scene_object + RCL_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!rcl_read_int(rcl_scene_object + RCL_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    rcl_own_scan();

    {
        const char *ownFrom = "none";

        if (!rcl_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !rcl_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !rcl_resolve_own_2(objects, usable, &ownIndex, &ownFrom)) {
            return;
        }

        rcl_publish_own(objects[ownIndex].object, ownFrom);

        if (rcl_own_logs_b < 8) {
            uintptr_t ownVt = 0;
            uintptr_t ownCls = 0;

            rcl_own_logs_b++;

            rcl_vt_ok((uintptr_t)rcl_own_elem, &ownVt);

            if (ownVt >= rcl_base) ownCls = ownVt - rcl_base;

        }

        if (!rcl_own_logged) {
            rcl_own_logged = 1;

        }
    }

    rcl_own_elem_2 = objects[ownIndex].object;

    rcl_walk_ent = objects[ownIndex].object;

    rcl_walk_pump();

    ownTeam = (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                        : objects[ownIndex].teamNew;
    ownX = objects[ownIndex].x;
    ownY = objects[ownIndex].y;


    {
        int i = 0;
        int64_t bestDist = 0;
        uintptr_t bestEnemy = 0;

        for (i = 0; i < usable; i++) {
            int32_t team = 0;
            int64_t ex = 0;
            int64_t ey = 0;
            int64_t d = 0;

            if (i == ownIndex) continue;
            if (objects[i].gid < RCL_PLAYER_GID) continue;
            if (objects[i].gid >= RCL_SHOT_GID) continue;

            team = (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                            : objects[i].teamNew;

            if (team == ownTeam) continue;

            ex = (int64_t)objects[i].x - (int64_t)ownX;
            ey = (int64_t)objects[i].y - (int64_t)ownY;
            d = ex * ex + ey * ey;

            if (!bestEnemy || d < bestDist) {
                bestEnemy = objects[i].object;
                bestDist = d;
            }
        }

    }

    for (int i = 0; i < usable; i++) {
        int32_t team = 0;
        float dx = 0.0f;
        float dy = 0.0f;
        float distance = 0.0f;
        float weight = 0.0f;

        if (i == ownIndex) continue;

        team = (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                         : objects[i].teamNew;
        if (team == ownTeam) continue;

        threatsAlive++;

        if (rcl_dodge_is_proj(objects[i].object) == 0) continue;

        dx = (float)(ownX - objects[i].x);
        dy = (float)(ownY - objects[i].y);
        distance = dx * dx + dy * dy;

        if (distance < 1.0f) continue;

        weight = 1.0f / (sqrtf(distance) + 1.0f);
        escapeX += dx * weight;
        escapeY += dy * weight;
        threats++;
    }

    rcl_death_signals((ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].object : 0, ownX,
                           ownY);

    if (RCL_ELEM_RESET && ownIndex >= 0 && ownIndex < usable &&
        objects[ownIndex].object != rcl_last_own) {

        rcl_last_own = objects[ownIndex].object;
        rcl_stage = 0;
        rcl_last_write_ms = 0;
        rcl_issued = 0;
    }

    rcl_alive(ownX, ownY);


    rcl_side_hits = 0;
    rcl_side_projs = 0;

    {
        int32_t projCount = 0;
        int i = 0;

        if (rcl_manager_ptr) rcl_read_int(rcl_manager_ptr + RCL_MGR_COUNT_OFF, &projCount);

        rcl_own_team_a = (int)ownTeam;

        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= RCL_TEAM_MAX_2) rcl_own_team_seen = 1;

        rcl_roster(rcl_own_elem_2, ownIndex, (int)ownTeam, objects, usable);

        if (ownIndex < 0 || ownIndex >= usable || ownIndex >= RCL_OBJECT_MAX) {

            return;
        }


        if (rcl_life(objects[ownIndex].object, ownX, ownY)) return;

        rcl_proj_scan(rcl_manager_ptr, projCount);

        rcl_active = 0;
        rcl_side_hits = 0;

        for (i = 0; i < RCL_PROJ_MAX; i++) {
            if (rcl_projs[i].elem) rcl_side_projs++;
        }

        rcl_threats();

        if (rcl_decide(ownX, ownY)) {
            rcl_active = 1;
            rcl_side_hits = 1;
            rcl_tx = (int32_t)rcl_tx_a;
            rcl_ty = (int32_t)rcl_ty_a;
        }

        rcl_drive();

    }


    if (threats == 0 && rcl_side_hits == 0) {
        return;
    }


    {
        float length = sqrtf(escapeX * escapeX + escapeY * escapeY);
        uint64_t now = 0;
        int targetX = 0;
        int targetY = 0;
        float step = DODGE_STEP;

        if (length > 0.0001f) {
            escapeX /= length;
            escapeY /= length;
        } else if (!rcl_active) {
            return;
        }

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        targetX = ownX + (int)(escapeX * step);
        targetY = ownY + (int)(escapeY * step);

        if (rcl_active) {
            targetX = rcl_tx;
            targetY = rcl_ty;
        }

        if (RCL_STEP > 0.0f) {
            float sdx = (float)(targetX - ownX);
            float sdy = (float)(targetY - ownY);
            float slen = sqrtf(sdx * sdx + sdy * sdy);

            if (slen > RCL_STEP) {

                targetX = ownX + (int)(sdx / slen * RCL_STEP);
                targetY = ownY + (int)(sdy / slen * RCL_STEP);
            }
        }

        rcl_clamp(&targetX, &targetY);

        if (rcl_stage >= RCL_STAGE_POSITION && rcl_side_hits > 0 && rcl_issued &&
            targetX == rcl_last_tx && targetY == rcl_last_ty) {
            return;
        }

        if (now < rcl_last_write_ms + (uint64_t)(rcl_side_hits > 0
                ? RCL_THREAT_MIN_MS : RCL_DODGE_MIN_MS)) {
            return;
        }

        rcl_last_write_ms = now;

        if (rcl_side_hits > 0) {
            rcl_last_tx = targetX;
            rcl_last_ty = targetY;
            rcl_issued = 1;
        }


        if (targetX > RCL_COORD_ABS_MAX) targetX = RCL_COORD_ABS_MAX;
        if (targetX < -RCL_COORD_ABS_MAX) targetX = -RCL_COORD_ABS_MAX;
        if (targetY > RCL_COORD_ABS_MAX) targetY = RCL_COORD_ABS_MAX;
        if (targetY < -RCL_COORD_ABS_MAX) targetY = -RCL_COORD_ABS_MAX;

        {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;
            uintptr_t thisInner = 0;

            if (RCL_QUEUE_GUARD && (!rcl_instance_shaped((uintptr_t)rcl_scene_object) ||
                                    !rcl_instance_shaped((uintptr_t)rcl_own_elem))) {

                return;
            }

            if (!rcl_mode_real((uintptr_t)rcl_scene_object, &thisVt, &thisChain, &thisInner)) {
                return;
            }

        }

        rcl_watch(ownX, ownY);


        rcl_engaged_frame = 1;



        rcl_wrote_tick = rcl_ticks_a;
        rcl_wrote_valid = 1;
        rcl_check_done = 0;

    }
}

void rcl_dodge_plan(uintptr_t manager, int32_t team) {
    void *array = NULL;
    int32_t count = 0;
    int live = 0;

    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array) || !array) return;
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > RCL_MANAGER_MAX_OBJECTS) count = RCL_MANAGER_MAX_OBJECTS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;
        int32_t t = 0;
        uint8_t dead = 0;
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!rcl_gameobject_shape((uintptr_t)element)) continue;
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_GLOBALID_OFF, &gid)) continue;
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_TEAM_OFF, &t)) continue;
        if (!rcl_read_byte((uintptr_t)element + RCL_OBJ_DEADFLAG_OFF, &dead)) continue;

        live++;

    }

}

void rcl_dodge_all_teams(uintptr_t manager) {
    int32_t teams[RCL_OBJ_TEAM_MAX + 1];
    int teamCount = 0;
    void *array = NULL;
    int32_t count = 0;

    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array) || !array) return;
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > RCL_MANAGER_MAX_OBJECTS) count = RCL_MANAGER_MAX_OBJECTS;

    for (int i = 0; i <= RCL_OBJ_TEAM_MAX; i++) teams[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t t = 0;

        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_TEAM_OFF, &t)) continue;
        if (t < 0 || t > RCL_OBJ_TEAM_MAX) continue;
        if (teams[t] >= 0) continue;

        teams[t] = t;
        teamCount++;
    }

    if (teamCount == 0) return;

    {
        int planned = 0;

        for (int t = 0; t <= RCL_OBJ_TEAM_MAX && planned < 2; t++) {
            if (teams[t] < 0) continue;

            rcl_dodge_plan(manager, t);
            planned++;
        }
    }
}

int rcl_dodge_probe_usable = 0;

float rcl_speed(void) {
    float v = rcl_walk_step * 60.0f;

    if (v < 120.0f) v = 120.0f;
    if (v > 1200.0f) v = 1200.0f;

    return v;
}

float rcl_seg_dist(float ax, float ay, float bx, float by, float px, float py) {
    float vx = bx - ax;
    float vy = by - ay;
    float wx = px - ax;
    float wy = py - ay;
    float len2 = vx * vx + vy * vy;
    float t = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;

    if (len2 > 0.001f) t = (wx * vx + wy * vy) / len2;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;

    dx = px - (ax + t * vx);
    dy = py - (ay + t * vy);

    return sqrtf(dx * dx + dy * dy);
}

void rcl_threats(void) {
    int k = 0;

    if ((rcl_ticks_a % 60) != 0) return;

    for (k = 0; k < RCL_PROJ_MAX; k++) {
        const rcl_proj_t *p = &rcl_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        const char *verdict = "threat";

        if (!p->elem) continue;

        if (!rcl_proj_vel(p, &vx, &vy)) {
            verdict = p->hasPrev ? "vel-unreadable" : "one-sample";
        } else if (RCL_TEAM_FILTER && rcl_own_team_seen && p->team == rcl_own_team_a) {
            verdict = "own-team";
        } else if (sqrtf(vx * vx + vy * vy) < RCL_MIN_PROJ_SPEED) {
            verdict = "still";
        }

    }
}

int rcl_body_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (rcl_pl_n <= 0) return 0;

    for (i = 0; i < rcl_pl_n; i++) {
        float px = 0.0f;
        float py = 0.0f;

        if (rcl_pl_mine[i]) continue;

        px = (float)rcl_pl_x[i];
        py = (float)rcl_pl_y[i];

        if (rcl_seg_dist(ownX, ownY, x, y, px, py) < RCL_BODY_CLEAR) {

            if (rcl_pl_mine[i]) rcl_body_mine++;
            else rcl_body_enemy++;


            return 1;
        }
    }

    return 0;
}

float rcl_own_radius(void) {
    float r = 0.0f;

    if (!RCL_GEOM) return 0.0f;

    if (rcl_own_r > 1.0f) {
        r = rcl_own_r;

        if (r > RCL_OWN_RADIUS_MAX) r = RCL_OWN_RADIUS_MAX;
        if (r < RCL_OWN_RADIUS_MIN) r = RCL_OWN_RADIUS_MIN;

        return r;
    }


    return RCL_DATA_OWN_R;
}