#include "titanox.h"


static float t_dodge_px = 0.0f;
static float t_dodge_py = 0.0f;
static int t_dodge_have = 0;
static float t_freest_hx = 0.0f;
static float t_freest_hy = 0.0f;
static int t_freest_have = 0;

static int tnx_dodge_is_proj(uintptr_t obj) {
    void *vt = NULL;
    intptr_t cls = 0;

    if (!obj) return 0;
    if (!tnx_read_ptr(obj, &vt) || !vt) return 0;

    cls = (intptr_t)((uintptr_t)vt - t_base);

#if TNX_DODGE_PROJ_ONLY
    return (cls == (intptr_t)TNX_CLASS_PROJ_RVA) ? 1 : 0;
#else
    (void)cls;

    return 1;
#endif
}

uint64_t t_drop_slow = 0;

uint64_t t_drop_fast = 0;

uint64_t t_drop_blink = 0;


float t_spd_min = 0.0f;

float t_spd_max = 0.0f;






__thread int t_in_drive = 0;




int32_t t_pl_mine[TNX_PLAYER_MAX];












int t_new_tick = -1;

int t_prev_seg = -1;








int t_mates = 0;

int t_enemies = 0;

int t_agree = -1;





uint64_t t_human = 0;









int32_t t_tx = 0;

int32_t t_ty = 0;

int t_active = 0;

int t_js_live = 0;

int t_life = 0;

int tnx_life_3(float px, float py) {
    uint8_t dead = 0;

    if (!t_manager_count) return 0;
    if (!t_own_elem) return 3;
    if (tnx_read_byte(t_own_elem + (uintptr_t)TNX_OBJ_DEADFLAG_OFF, &dead) && dead != 0) return 2;
    if (px == 0.0f && py == 0.0f) return 0;

    return 1;
}

uint64_t t_js_tick = 0;

int tnx_js_owns(void) {
    if (!t_js_live) return 0;
    if (t_ticks_a > t_js_tick && (t_ticks_a - t_js_tick) > 2) return 0;

    return 1;
}

int t_build_tick = -1;






int t_have_angle = 0;

float t_angle = 0.0f;

float t_tx_a = 0.0f;

float t_ty_a = 0.0f;

int t_moving = 0;

float t_start_x = 0.0f;

float t_start_y = 0.0f;




int t_drive_logs = 0;
















float t_last_x_b = 0.0f;

float t_last_y_b = 0.0f;

int t_last_ok = 0;


float t_mom_live = 0.0f;

int t_crit_reaction = 0;

uint64_t t_crit_last = 0;





float t_shot_speed[TNX_PROJ_MAX];








uint64_t t_react_min = 0;

uint64_t t_react_max = 0;


int t_track_gid[TNX_SEG_MAX];

int t_track_hit[TNX_SEG_MAX];

float t_last_dist = 0.0f;

int t_released = 0;

float t_own_vx = 0.0f;

float t_own_vy = 0.0f;

float t_prev_own_x = 0.0f;

float t_prev_own_y = 0.0f;

uint64_t t_prev_own_tick = 0;

float t_track_min[TNX_SEG_MAX];

int t_track_pside[TNX_SEG_MAX];

float t_track_ux[TNX_SEG_MAX];

float t_track_uy[TNX_SEG_MAX];


uint64_t t_howto_logs = 0;

int t_side_last = -1;

int t_shot_key[TNX_SEG_MAX];



uint64_t t_own_obj_last = 0;

uint64_t t_no_threat_since = 0;

int t_pick_key_c = 0;

int t_pick_key_t = 0;





int t_sel[TNX_SEL_MAX];

int t_sel_n = 0;

uint64_t t_pos_skips = 0;

int t_cand_now[TNX_CAND];

int t_cand_seen = 0;

int32_t t_prev_x = 0;

int32_t t_prev_y = 0;






int t_cal_off_seen = -1;

float t_cal_rad_seen = 0.0f;

int t_cal_n = 0;









int tnx_ok(float v, float lo, float hi) {
    if (!(v >= lo && v <= hi)) return 0;

    return 1;
}

int t_rad_off = -1;



float t_rad_est = 0.0f;


float t_own_r = 0.0f;



int t_clip_win = 0;


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

float tnx_proj_radius(const tnx_proj_t *p, float speed) {
    uintptr_t base = 0;
    int off = 0;

    if (!TNX_GEOM) return 0.0f;
    if (!p) return 0.0f;
    if (speed < 1.0f) return 0.0f;

    base = p->elem;

    {
        void *def = NULL;

        if (tnx_read_ptr(p->elem + (uintptr_t)TNX_ELEM_DEF_OFF, &def) && def)
            base = (uintptr_t)def;
    }

    if (t_rad_off >= 0) {
        float r = 0.0f;

        if (base && tnx_read_float(base + (uintptr_t)t_rad_off, &r) &&
            tnx_ok(r, TNX_RADIUS_MIN, TNX_RADIUS_MAX)) {
            t_rad_est = r;

            return r;
        }

        return tnx_ok(t_rad_est, TNX_RADIUS_MIN, TNX_RADIUS_MAX) ? t_rad_est : 0.0f;
    }

    if (!base) return 0.0f;

    for (off = TNX_CAL_OFF_LO; off <= TNX_CAL_OFF_HI; off += TNX_CAL_STEP) {
        float v = 0.0f;
        float r = 0.0f;
        float d = 0.0f;


        if (!tnx_read_float(base + (uintptr_t)off, &v)) continue;
        if (!tnx_ok(v, 1.0f, 1.0e6f)) continue;

        d = v - speed;
        if (d < 0.0f) d = -d;
        if (d > speed * TNX_CAL_TOL) continue;

        if (!tnx_read_float(base + (uintptr_t)off + 4, &r)) continue;
        if (!tnx_ok(r, TNX_RADIUS_MIN, TNX_RADIUS_MAX)) continue;

        if (t_cal_off_seen == off && tnx_ok(t_cal_rad_seen - r, -1.0f, 1.0f)) {
            t_cal_n++;
        } else {
            t_cal_off_seen = off;
            t_cal_rad_seen = r;
            t_cal_n = 1;
        }

        if (t_cal_n < TNX_CAL_TICKS) return 0.0f;

        t_rad_off = off + 4;
        t_rad_est = r;


        return r;
    }




    return TNX_DATA_PROJ_R;
}

void tnx_build(void) {
    int k;

    t_seg_count = 0;
    t_build_tick = (int)t_ticks_a;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        const tnx_proj_t *p = &t_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        float len = 0.0f;
        float speed = 0.0f;
        float rem = 0.0f;
        tnx_seg_t *s = NULL;

        if (!p->elem) continue;
        if (!p->hasPrev && !TNX_ONESHOT) continue;
        if (t_seg_count >= TNX_SEG_MAX) break;

        if (TNX_TEAM_FILTER && t_team_trust && t_own_team_seen &&
            p->team == t_own_team_a) continue;

        if (TNX_TEAM_STRICT && t_own_team_b >= 0 && p->team == t_own_team_b) continue;
        if (tnx_proj_mine(p)) continue;

        if (!p->hasPrev) {

            uint64_t age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 1;

            vx = (float)(p->x - p->spawnX) / (float)age;
            vy = (float)(p->y - p->spawnY) / (float)age;

            if (fabsf(vx) < 0.5f && fabsf(vy) < 0.5f) continue;

        } else if (!tnx_proj_vel(p, &vx, &vy)) continue;

        len = sqrtf(vx * vx + vy * vy);

        if (len < TNX_MIN_PROJ_SPEED) continue;

        speed = len * 60.0f;

        if (speed < 1.0f) speed = 1.0f;

        if (speed > t_shot_speed[k]) t_shot_speed[k] = speed;
        if (t_shot_speed[k] > 1.0f) speed = t_shot_speed[k];

        if (tnx_blacklisted(speed, 0.0f)) {

            continue;
        }

        if (t_spd_min < 1.0f || speed < t_spd_min) t_spd_min = speed;
        if (speed > t_spd_max) t_spd_max = speed;

        rem = speed * (TNX_PROJ_LIFE_MS / 1000.0f);

        if (rem > TNX_DEFAULT_RANGE) rem = TNX_DEFAULT_RANGE;
        if (rem < 1.0f) rem = 1.0f;

        {
            float nx = vx / len;
            float ny = vy / len;
            float px0 = t_dodge_have ? t_dodge_px : (float)t_own_x;
            float py0 = t_dodge_have ? t_dodge_py : (float)t_own_y;
            float rx = (float)p->x - px0;
            float ry = (float)p->y - py0;
            float rvx = vx - t_own_vx;
            float rvy = vy - t_own_vy;
            float rate = rx * rvx + ry * rvy;
            float denom = rvx * rvx + rvy * rvy;
            float tStar = (denom > 0.5f) ? (-rate / denom) : 0.0f;
            float cx = rx + rvx * tStar;
            float cy = ry + rvy * tStar;
            float miss = sqrtf(cx * cx + cy * cy);
            float reach = TNX_DATA_OWN_R + TNX_DATA_PROJ_R + TNX_INFLATE;
            float dist2own = sqrtf(rx * rx + ry * ry);
            float flightTicks = rem / (speed / 60.0f);
            float ix = (float)p->x + nx * speed / 60.0f * tStar;
            float iy = (float)p->y + ny * speed / 60.0f * tStar;
            int hits = (tStar >= 0.0f && tStar <= flightTicks && miss <= reach) ? 1 : 0;
            int inView = (dist2own <= TNX_VIEW_RANGE) ? 1 : 0;
            int keep = (hits || inView) ? 1 : 0;


            if (t_dodge_have) {
                float toOwn = (px0 - (float)p->x) * nx + (py0 - (float)p->y) * ny;

                if (toOwn < 0.0f && !keep) continue;
                if (toOwn - TNX_OVERSHOOT > rem) continue;
                if (toOwn > 0.0f && rem > toOwn + TNX_OVERSHOOT) rem = toOwn + TNX_OVERSHOOT;
            }
        }

        if (TNX_REJECT) {
            int rule = 0;

            if (speed < TNX_MIN_SPEED) rule = 1;
            else if (speed > TNX_MAX_SPEED) rule = 2;
            else if ((p->qtick > p->ptick) && (p->qtick - p->ptick) <= TNX_BLINK_TICKS &&
                     rem < TNX_BLINK_REM) rule = 3;

            if (rule) {
                if (rule == 1) t_drop_slow++;
                else if (rule == 2) t_drop_fast++;
                else t_drop_blink++;


                continue;
            }
        }

        {
            float rem0 = rem;

            rem = tnx_clip_range((float)p->x, (float)p->y, vx / len, vy / len, rem);


            if (rem < rem0 - 0.5f) t_clip_win++;
        }

        s = &t_seg[t_seg_count++];
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
            float pr = tnx_proj_radius(p, speed);
            float orr = tnx_own_radius();
            float ir = pr + orr + TNX_RADIUS_MARGIN;

            if (!tnx_ok(pr, 0.0f, TNX_RADIUS_MAX)) pr = 0.0f;
            if (!tnx_ok(orr, 0.0f, TNX_RADIUS_MAX)) orr = 0.0f;

            ir = pr + orr + TNX_RADIUS_MARGIN;

            if (!tnx_ok(ir, 1.0f, TNX_RADIUS_MAX * 4.0f)) {
                ir = TNX_DODGE_CLEAR_R;
            }

            if (ir < TNX_DODGE_CLEAR_R) ir = TNX_DODGE_CLEAR_R;

            s->inflatedR = ir;
        }
    }

    if (t_seg_test > 0) t_seg_frac = (t_seg_clip * 100) / t_seg_test;
}

float tnx_seg_dist2(float px, float py, const tnx_seg_t *s) {
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

int tnx_threatened(float x, float y) {
    int i;

    for (i = 0; i < t_seg_count; i++) {
        float d2 = tnx_seg_dist2(x, y, &t_seg[i]);

        if (d2 <= t_seg[i].inflatedR * t_seg[i].inflatedR) return 1;
    }

    return 0;
}

float tnx_clearance_a(float x, float y) {
    float best = 1000000.0f;
    int i;

    for (i = 0; i < t_seg_count; i++) {
        float d = sqrtf(tnx_seg_dist2(x, y, &t_seg[i])) - t_seg[i].inflatedR;

        if (d < best) best = d;
    }

    return best;
}

float tnx_eta_ms(float x, float y) {
    float best = 1.0e9f;
    int i = 0;

    for (i = 0; i < t_seg_count; i++) {
        const tnx_seg_t *s = &t_seg[i];
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

        if (d > TNX_HIT_MARGIN) continue;
        if (d < 0.0f) d = 0.0f;

        rem = (1.0f - raw) * len;
        ms = rem / s->speed * 1000.0f;

        if (ms < best) best = ms;
    }

    return best;
}

int tnx_imminent(float x, float y) {
    float look = TNX_RAGE_FORCE ? (TNX_MODE_TUNE ? tnx_look_ms() : TNX_LOOKAHEAD_MS_2)
                               : TNX_LOOKAHEAD_MS;

    if (look > TNX_LOOKAHEAD_MAX) look = TNX_LOOKAHEAD_MAX;
    if (look <= 0.0f) return 0;
    if (t_seg_count <= 0) return 0;

    return (tnx_eta_ms(x, y) <= look) ? 1 : 0;
}

int tnx_flee(float px, float py, float *tx, float *ty) {
    if (TNX_JS_DODGE) return 0;
    int i = 0;
    int best = -1;
    float bestMs = 1.0e9f;
    float cx = 0.0f;
    float cy = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;
    float len = 0.0f;

    if (!TNX_FLEE) return 0;
    if (t_seg_count <= 0) return 0;

    for (i = 0; i < t_seg_count; i++) {
        const tnx_seg_t *s = &t_seg[i];
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
        dx = -(t_seg[best].by - t_seg[best].ay);
        dy = (t_seg[best].bx - t_seg[best].ax);
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) return 0;
    }

    *tx = px + dx / len * TNX_FLEE_STEP;
    *ty = py + dy / len * TNX_FLEE_STEP;

    return 1;
}

int tnx_body_blocked_2(float px, float py, float dirX, float dirY, float len) {
    float ex = 0.0f;
    float ey = 0.0f;
    int i = 0;

    if (!TNX_MATE_AVOID) return 0;
    if (t_pl_n <= 0) return 0;
    if (len < 1.0f) return 0;

    ex = px + dirX * len;
    ey = py + dirY * len;

    for (i = 0; i < t_pl_n; i++) {
        if (tnx_seg_dist(px, py, ex, ey, (float)t_pl_x[i], (float)t_pl_y[i]) <
            TNX_MATE_CLEAR_2) {
            return 1;
        }
    }

    return 0;
}

float tnx_body_score(float px, float py, float dirX, float dirY, float len) {
    float ex = px + dirX * len;
    float ey = py + dirY * len;
    float best = 1.0e9f;
    int i = 0;

    if (t_pl_n <= 0) return best;

    for (i = 0; i < t_pl_n; i++) {
        float d = tnx_seg_dist(px, py, ex, ey, (float)t_pl_x[i], (float)t_pl_y[i]);

        if (d < best) best = d;
    }

    return best;
}

                                                                                                                                              

float tnx_clearance_b(float px, float py, float dirX, float dirY) {
    float speed = tnx_speed();
    float best = 1.0e9f;
    int i = 0;
    int k = 0;

    for (i = 0; i < t_sel_n; i++) {
        const tnx_seg_t *seg = &t_seg[t_sel[i]];

        for (k = 0; k <= TNX_STEPS; k++) {
            float t = TNX_HORIZON * ((float)k / (float)TNX_STEPS);
            float qx = px + dirX * speed * t;
            float qy = py + dirY * speed * t;
            float d = tnx_seg_dist(qx, qy, seg->ax, seg->ay, seg->bx, seg->by) - seg->inflatedR;

            if (d < best) best = d;
        }
    }


    return best;
}

float tnx_score(float px, float py, float dirX, float dirY, float len) {
    tnx_select(px, py);

    return tnx_clearance_b(px, py, dirX, dirY) +
           TNX_BODY_W * tnx_body_score_2(px, py, dirX, dirY, len);
}

float tnx_body_score_2(float px, float py, float dirX, float dirY, float len) {
    float ex = px + dirX * len;
    float ey = py + dirY * len;
    float best = 1.0e9f;
    int i = 0;

    if (!TNX_BODY_SCAN) return tnx_body_score(px, py, dirX, dirY, len);
    if (t_dodge_probe_usable <= 0) return tnx_body_score(px, py, dirX, dirY, len);

    for (i = 0; i < t_dodge_probe_usable; i++) {
        const tnx_obj_t *o = &t_dodge_probe_list[i];
        float d = 0.0f;

        if (o->gid < TNX_PLAYER_GID) continue;
        if (o->gid >= TNX_SHOT_GID) continue;
        if (t_own_elem_2 && o->object == t_own_elem_2) continue;

        d = tnx_seg_dist(px, py, ex, ey, (float)o->x, (float)o->y);

        if (d < best) best = d;
    }

    return best;
}

void tnx_unblock(float px, float py, float len, float *dirX, float *dirY) {
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

    if (!TNX_MATE_AVOID) return;
    if (len < 1.0f) return;

    bestScore = tnx_score(px, py, base, baseY, len);
    baseScore = bestScore;
    bestX = base;
    bestY = baseY;

    if (t_last_ok) {
        bestScore += TNX_DATA_MOMENTUM * (base * t_last_x_b + baseY * t_last_y_b);
        baseScore = bestScore;
    }

    for (i = 0; i < 12; i++) {
        float a = rot[i] * rad;
        float c = cosf(a);
        float sn = sinf(a);
        float rx = base * c - baseY * sn;
        float ry = base * sn + baseY * c;
        float score = tnx_score(px, py, rx, ry, len);

        if (t_last_ok) score += TNX_DATA_MOMENTUM * (rx * t_last_x_b + ry * t_last_y_b);

        if (score > bestScore) {
            bestScore = score;
            bestX = rx;
            bestY = ry;
        }
    }

    if (t_last_ok && bestX != base &&
        (bestScore - (tnx_score(px, py, base, baseY, len) +
                      TNX_DATA_MOMENTUM * (base * t_last_x_b + baseY * t_last_y_b))) <
            TNX_DATA_BAND) {
        bestX = base;
        bestY = baseY;
    }

    *dirX = bestX;
    *dirY = bestY;

    if (bestX != 0.0f || bestY != 0.0f) {
        float n = sqrtf(bestX * bestX + bestY * bestY);

        if (n > 0.0001f) {
            t_last_x_b = bestX / n;
            t_last_y_b = bestY / n;
            t_last_ok = 1;
        }
    }

}

int tnx_valid_point(float x, float y) {
    int32_t cx = (int32_t)x;
    int32_t cy = (int32_t)y;

    tnx_clamp(&cx, &cy);

    if (cx != (int32_t)x || cy != (int32_t)y) return 0;

    if (tnx_mate_blocked(x, y)) {

        return 0;
    }

    if (tnx_body_blocked(x, y, (float)t_own_x, (float)t_own_y)) {
        return 0;
    }

    if (tnx_enemy_blocked(x, y, (float)t_own_x, (float)t_own_y)) {

        return 0;
    }

    return 1;
}

int tnx_walk_into_bullet(float px, float py, float dirX, float dirY, float travel) {
    float pvx = dirX * TNX_DATA_SPEED;
    float pvy = dirY * TNX_DATA_SPEED;
    float horizon = travel / TNX_DATA_SPEED;
    int i;

    for (i = 0; i < t_seg_count; i++) {
        const tnx_seg_t *s = &t_seg[i];
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

float tnx_safe_angle(float px, float py, float desiredDeg, int *ok) {
    static const float offsets[6] = { 15.0f, 30.0f, 45.0f, 60.0f, 75.0f, 90.0f };
    const float deg = 3.14159265358979f / 180.0f;
    float scan = TNX_EXTEND_DEFAULT * 1.5f;
    int i;

    *ok = 1;

    if (!tnx_walk_into_bullet(px, py, cosf(desiredDeg * deg), sinf(desiredDeg * deg), scan) &&
        !tnx_body_blocked_2(px, py, cosf(desiredDeg * deg), sinf(desiredDeg * deg), scan)) {
        return desiredDeg;
    }

    for (i = 0; i < 6; i++) {
        float a = desiredDeg + offsets[i];
        float b = desiredDeg - offsets[i];

        if (!tnx_walk_into_bullet(px, py, cosf(a * deg), sinf(a * deg), scan) &&
            !tnx_body_blocked_2(px, py, cosf(a * deg), sinf(a * deg), scan)) return a;

        if (!tnx_walk_into_bullet(px, py, cosf(b * deg), sinf(b * deg), scan) &&
            !tnx_body_blocked_2(px, py, cosf(b * deg), sinf(b * deg), scan)) return b;
    }

    *ok = 0;

    return desiredDeg;
}

int tnx_passed(float px, float py) {
    float ax = t_tx_a - t_start_x;
    float ay = t_ty_a - t_start_y;
    float len2 = ax * ax + ay * ay;
    float bx = 0.0f;
    float by = 0.0f;

    if (len2 <= 0.0f) return 1;

    bx = px - t_start_x;
    by = py - t_start_y;

    return (ax * bx + ay * by) >= len2 ? 1 : 0;
}
static float tnx_js_clear(float px, float py, float mvx, float mvy) {
    float best = 1.0e9f;
    int i = 0;
    int s = 0;

    for (i = 0; i < t_seg_count; i++) {
        const tnx_seg_t *sg = &t_seg[i];
        float maxT = TNX_HORIZON_S;

        if (sg->speed > 1.0f) {
            float life = sg->remaining / sg->speed;

            if (life > 0.0f && life < maxT) maxT = life;
        }

        for (s = 0; s <= TNX_JS_CLEAR_STEPS; s++) {
            float ts = maxT * (float)s / (float)TNX_JS_CLEAR_STEPS;
            float d = tnx_seg_dist(px + mvx * ts, py + mvy * ts, sg->ax, sg->ay, sg->bx, sg->by) -
                      sg->inflatedR;

            if (d < best) best = d;
        }
    }

    return best;
}

int tnx_freest(float px, float py, float *tx, float *ty) {
    int i = 0;
    int n = TNX_JS_DODGE ? TNX_DIR_COUNT : TNX_FREEST_ANGLES;
    float radius = TNX_JS_DODGE ? TNX_REACH : TNX_STEP_a;
    float speed = TNX_DATA_SPEED;
    float nowClear = tnx_js_clear(px, py, 0.0f, 0.0f);
    float bestScore = -1.0e18f;
    float bestEta = 0.0f;
    float bestRoom = 0.0f;
    float bestX = 0.0f;
    float bestY = 0.0f;
    int bestOk = 0;

    if (radius < 1.0f) radius = TNX_STEP_a;
    if (t_walk_step > 0.01f) speed = t_walk_step * 60.0f;
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

        tnx_clamp(&cxi, &cyi);

        if (tnx_walk_into_bullet(px, py, ux, uy, speed * TNX_HORIZON_S)) {

            continue;
        }

        score = tnx_js_clear(px, py, ux * speed, uy * speed);

        if (t_freest_have) score += t_mom_live * (ux * t_freest_hx + uy * t_freest_hy);
        if (tnx_clip_range(px, py, ux, uy, radius) < radius - 1.0f) score -= TNX_WALL_PENALTY;

        for (k = 0; k < t_pl_n; k++) {
            float d = 0.0f;

            if (t_pl_mine[k]) continue;

            d = tnx_seg_dist(px, py, ex, ey, (float)t_pl_x[k], (float)t_pl_y[k]);

            if (d < room) room = d;
        }

        if (room > TNX_BODY_CLEAR) room = TNX_BODY_CLEAR;

        score = score + room * TNX_BODY_GAIN;
        eta = tnx_eta_ms(ex, ey);

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

    if (TNX_JS_DODGE) {
        t_freest_hx = (bestX - px) / radius;
        t_freest_hy = (bestY - py) / radius;
        t_freest_have = 1;

        if (bestScore <= nowClear) {
            if (!t_crit_reaction) {

                return 0;
            }

        }
    }

    if (!TNX_ESCAPE && bestRoom < TNX_FREEST_MIN) return 0;

    *tx = bestX;
    *ty = bestY;


    return 1;
}

float tnx_clear_at(float px, float py, int i) {
    return tnx_seg_dist(px, py, t_seg[i].ax, t_seg[i].ay, t_seg[i].bx, t_seg[i].by) - t_seg[i].inflatedR;
}

float tnx_all_clear(float x, float y) {
    int k = 0;
    float best = 1.0e9f;

    for (k = 0; k < t_seg_count; k++) {
        float c = tnx_clear_at(x, y, k);

        if (c < best) best = c;
    }

    return best;
}

int tnx_wall_blocked(float x0, float y0, float x1, float y1) {
    int32_t ox = (int32_t)x1;
    int32_t oy = (int32_t)y1;

    if (!t_live || !t_armed) return -1;
    if (t_w <= 0 || t_h <= 0) return -1;

    return tnx_clip_walk((int32_t)x0, (int32_t)y0, (int32_t)x1, (int32_t)y1,
                         (int32_t)TNX_TILE_SIZE, t_grid, t_w, t_h, &ox, &oy);
}
                                                                                                                                                                                                                                                                                                

                                                                                                                                                                                                                                                                                                                                                                                                                                       

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               

static void tnx_state_reset(void) {
    t_moving = 0;
    t_side_last = -1;
    t_last_dist = 0.0f;
}

static void tnx_dodge_state_tick(float px, float py) {
    uintptr_t own = tnx_own_obj();

    if (t_prev_own_tick != 0 && t_ticks_a > t_prev_own_tick) {
        float dt = (float)(t_ticks_a - t_prev_own_tick);

        t_own_vx = (px - t_prev_own_x) / dt;
        t_own_vy = (py - t_prev_own_y) / dt;
    }

    t_prev_own_x = px;
    t_prev_own_y = py;
    t_prev_own_tick = t_ticks_a;

    if (own != t_own_obj_last) {
        if (t_own_obj_last != 0) tnx_state_reset();

        t_own_obj_last = own;
        t_no_threat_since = 0;
        t_released = 0;

        return;
    }

    if (t_seg_count > 0) {
        t_no_threat_since = 0;
        t_released = 0;

        return;
    }

    if (t_moving && tnx_wall_blocked(px, py, t_tx_a, t_ty_a) == 1) {
        tnx_state_reset();

        t_released = 1;

        tnx_enqueue((int32_t)px, (int32_t)py);


        return;
    }

    if (t_released) return;

    if (t_no_threat_since == 0) {
        t_no_threat_since = t_ticks_a;

        return;
    }

    if ((t_ticks_a - t_no_threat_since) < (uint64_t)TNX_NO_THREAT_TICKS) return;

    tnx_state_reset();
    t_released = 1;

    tnx_enqueue((int32_t)px, (int32_t)py);

}

#define TNX_DODGE_SAFETY 28.0f
#define TNX_DODGE_NEAR 2500.0f
#define TNX_DODGE_T_URGENT 0.9f
#define TNX_DODGE_T_FIELD 1.8f
#define TNX_DODGE_DIRS 64
#define TNX_DODGE_PERP_W 2.4f
#define TNX_DODGE_AWAY_W 1.0f
#define TNX_DODGE_INTENT_W 1.2f
#define TNX_DODGE_CHAR_SPEED 720.0f
#define TNX_DODGE_MAX_DIST_SQ 25000000.0f
#define TNX_DODGE_INERTIA_TICKS 24
#define TNX_DODGE_CAND_MAX 160
#define TNX_DODGE_CONE 1.0f
#define TNX_DODGE_REACH 4.0f
#define TNX_DODGE_SPEED_MIN 300
#define TNX_DODGE_SPEED_MAX 8500
#define TNX_DODGE_DIRT_MIN 6.0f
#define TNX_DODGE_DIRT_SPAN 1.5f

typedef struct {
    float x;
    float y;
    float dx;
    float dy;
    float speed;
    float radius;
    int32_t gid;
} tnx_dodge_proj_t;

static int t_js_picked = 0;
static int t_dodge_foes = 0;
static int t_dodge_unk = 0;
static float t_dodge_ox = 0.0f;


uint64_t t_aim_frames = 0;


static float t_dodge_oy = 0.0f;

int32_t t_aim_tx = 0;

int32_t t_aim_ty = 0;
static int t_dodge_detail = 0;

static int tnx_dodge_own_pos(float *ox, float *oy) {
    int32_t x = 0;
    int32_t y = 0;

    if (!t_own_elem) return 0;
    if (!tnx_read_int(t_own_elem + (uintptr_t)OFF_GAMEOBJ_X, &x)) return 0;
    if (!tnx_read_int(t_own_elem + (uintptr_t)OFF_GAMEOBJ_Y, &y)) return 0;
    if (x < -200000 || x > 200000) return 0;
    if (y < -200000 || y > 200000) return 0;
    if (x == 0 && y == 0) return 0;

    *ox = (float)x;
    *oy = (float)y;

    return 1;
}

static double t_meas_sec = 0.0;
static uint64_t t_meas_tick = 0;
static float t_meas_tps = TNX_MEAS_FPS;

static void tnx_meas_clocks(void) {
    double now = CFAbsoluteTimeGetCurrent();

    if (t_meas_sec > 0.0 && t_ticks_a > t_meas_tick) {
        double span = now - t_meas_sec;

        if (span > 0.25) {
            float rate = (float)((double)(t_ticks_a - t_meas_tick) / span);

            if (rate > 5.0f && rate < 240.0f) t_meas_tps = rate;

            t_meas_sec = now;
            t_meas_tick = t_ticks_a;
        }
    } else {
        t_meas_sec = now;
        t_meas_tick = t_ticks_a;
    }
}

static tnx_dodge_proj_t t_dodge_projs[TNX_PROJ_MAX];
static tnx_dodge_proj_t t_dodge_prev[TNX_PROJ_MAX];
static int t_dodge_n = 0;
static float t_dodge_last_x = 0.0f;
static float t_dodge_last_y = 0.0f;
static int t_dodge_have_last = 0;
static uint64_t t_dodge_last_tick = 0;
static float t_dodge_dir[TNX_DODGE_DIRS][2];
static int t_dodge_dirs_built = 0;
static float t_dodge_speed = TNX_DODGE_CHAR_SPEED;

static void tnx_dodge_build_dirs(void) {
    int i;

    if (t_dodge_dirs_built) return;

    for (i = 0; i < TNX_DODGE_DIRS; i++) {
        float a = 6.283185307179586f * (float)i / (float)TNX_DODGE_DIRS;

        t_dodge_dir[i][0] = cosf(a);
        t_dodge_dir[i][1] = sinf(a);
    }

    t_dodge_dirs_built = 1;
}

static void tnx_dodge_norm(float x, float y, float *ox, float *oy) {
    float len = sqrtf(x * x + y * y);

    if (len < 1e-6f) {
        *ox = 1.0f;
        *oy = 0.0f;

        return;
    }

    *ox = x / len;
    *oy = y / len;
}

static void tnx_dodge_speed_probe(void) {
    void *def = NULL;
    int32_t raw = 0;

    if (!t_own_elem) return;
    if (!tnx_read_ptr(t_own_elem + (uintptr_t)TNX_ELEM_DEF_OFF, &def) || !def) return;
    if (!tnx_read_int((uintptr_t)def + (uintptr_t)OFF_CHARDATA_SPEED, &raw)) return;
    if (raw < TNX_DODGE_SPEED_MIN || raw > TNX_DODGE_SPEED_MAX) return;

    t_dodge_speed = (float)raw;
}
static int tnx_dodge_my_team(void) {
    int32_t v = 0;

    if (t_own_elem && tnx_read_int(t_own_elem + (uintptr_t)TNX_OBJ_TEAM_OFF, &v)) {
        if (v == 0 || v == 1) return v;
    }

    if (t_own_team_b == 0 || t_own_team_b == 1) return t_own_team_b;

    return -1;
}

static void tnx_dodge_collect(float px, float py) {
    int i;
    int n = 0;
    int myTeam = -1;

    t_dodge_foes = 0;
    t_dodge_unk = 0;
    t_dodge_detail = 0;

    tnx_dodge_build_dirs();
    tnx_dodge_speed_probe();
    tnx_meas_clocks();

    for (i = 0; i < TNX_PROJ_MAX; i++) {
        const tnx_proj_t *p = &t_projs[i];
        tnx_dodge_proj_t *q;
        uint8_t dead = 0;
        float mx;
        float my;
        float dx = 0.0f;
        float dy = 0.0f;
        float len = 0.0f;
        uint64_t dt;
        float speed;
        float pr = TNX_PROJ_RADIUS_DEFAULT;

        if (!p->elem) continue;

        if (myTeam < 0) myTeam = tnx_dodge_my_team();

        if (t_dodge_detail < TNX_DODGE_DETAIL_MAX && (t_ticks_a % TNX_DODGE_DETAIL_EVERY) == 0) {
            int32_t rawTeam = -1;
            uintptr_t rawVt = 0;

            tnx_read_int(p->elem + (uintptr_t)TNX_OBJ_TEAM_OFF, &rawTeam);
            if (tnx_read_ptr(p->elem, (void **)&rawVt) && rawVt >= t_base) rawVt -= t_base;

            t_dodge_detail++;

        }

        if (p->team >= 0 && (p->team == t_own_team_a || (myTeam >= 0 && p->team == myTeam))) {

            continue;
        }

        if (p->team == 0 || p->team == 1) t_dodge_foes++;
        else t_dodge_unk++;

        if (!tnx_read_byte(p->elem + (uintptr_t)TNX_OBJ_DEADFLAG_OFF, &dead)) continue;
        if (dead != 0) continue;

        mx = (float)p->x - px;
        my = (float)p->y - py;

        if (mx * mx + my * my > TNX_DODGE_MAX_DIST_SQ) continue;

        if (p->hasPrev) {
            dx = (float)(p->x - p->px);
            dy = (float)(p->y - p->py);
            len = sqrtf(dx * dx + dy * dy);

            if (len <= TNX_DODGE_DIRT_MIN) continue;

            dx /= len;
            dy /= len;
        } else {
            float angle = 0.0f;

            if (!tnx_read_float(p->elem + (uintptr_t)TNX_PROJ_ANGLE_OFF, &angle)) continue;
            if (!(angle > -100.0f && angle < 100.0f)) continue;

            dx = cosf(angle);
            dy = sinf(angle);
        }

        {
            float bx = (float)p->x - px;
            float by = (float)p->y - py;
            float br = tnx_own_radius();

            if (br < TNX_OWN_RADIUS_MIN) br = TNX_DATA_OWN_R;
            if (sqrtf(bx * bx + by * by) < br) continue;
        }

        {
            float lx = (float)t_aim_tx - px;
            float ly = (float)t_aim_ty - py;
            float ll = sqrtf(lx * lx + ly * ly);

            if (ll > 1.0f && sqrtf(mx * mx + my * my) < TNX_AIM_HIT_DIST) {
                float aimDot = (dx * lx + dy * ly) / ll;

            }
        }

        dt = (p->ptick > 0 && t_ticks_a > p->ptick) ? (t_ticks_a - p->ptick) : 0;

        speed = 0.0f;

        if (len > 0.0f && dt > 0 && (float)dt <= TNX_MEAS_DT_MAX) {
            speed = (len / (float)dt) * t_meas_tps;
        }

        if (speed < TNX_MEAS_SPEED_MIN || speed > TNX_MEAS_SPEED_MAX) speed = TNX_JS_SPEED_FALLBACK;

        if (speed < TNX_MEAS_SPEED_MIN) speed = TNX_MEAS_SPEED_MIN;
        if (speed > TNX_MEAS_SPEED_MAX) speed = TNX_MEAS_SPEED_MAX;

        {
            float rr = tnx_proj_radius(p, speed);
            float toward = 0.0f;
            float r = 0.0f;
            float lateral = 0.0f;
            float dist = 0.0f;

            if (rr > 0.0f) pr = rr;

            toward = mx * dx + my * dy;
            r = tnx_own_radius() + pr + TNX_DODGE_SAFETY * TNX_DODGE_DETECT_SAFETY;
            dist = sqrtf(mx * mx + my * my);
            lateral = mx * mx + my * my - toward * toward;

            if ((t_ticks_a % 5) == 0 && t_dodge_detail < 10) {
                const char *verdict = "hit";

                t_dodge_detail++;

                if (sqrtf(((float)p->spawnX - px) * ((float)p->spawnX - px) +
                          ((float)p->spawnY - py) * ((float)p->spawnY - py)) <=
                    tnx_own_radius() + TNX_DODGE_SPAWN_MARGIN) verdict = "own-spawn";
                else if (p->team >= 0 && (p->team == t_own_team_a || (myTeam >= 0 && p->team == myTeam))) verdict = "own-side";
                else if (toward >= 0.0f) verdict = "away";
                else if (lateral > r * r * TNX_DODGE_CONE) verdict = "wide";
                else if (dist / speed > TNX_DODGE_T_FIELD * TNX_DODGE_REACH) verdict = "far";

            }

            {
                float sx = (float)p->px - px;
                float sy = (float)p->py - py;
                float sr = tnx_own_radius();

                if (sr < TNX_OWN_RADIUS_MIN) sr = TNX_DATA_OWN_R;

                if (p->hasPrev && sqrtf(sx * sx + sy * sy) <= sr) {

                    continue;
                }
            }

            if (toward >= 0.0f) {

                continue;
            }

            if (lateral > r * r * TNX_DODGE_CONE) {

                continue;
            }

            if (dist / speed > TNX_DODGE_T_FIELD * TNX_DODGE_REACH) {

                continue;
            }
        }

        q = &t_dodge_projs[n];
        q->x = (float)p->x;
        q->y = (float)p->y;
        q->dx = dx;
        q->dy = dy;
        q->speed = speed;
        q->radius = pr;
        q->gid = p->gid;

        n++;
    }

    t_dodge_n = n;
}

static void tnx_dodge_commit(void) {

    if (t_dodge_n > 0) memcpy(t_dodge_prev, t_dodge_projs, (size_t)t_dodge_n * sizeof(tnx_dodge_proj_t));
}

static int tnx_dodge_urgent(const tnx_dodge_proj_t *p, float mx, float my, float mr) {
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
    if (tHit > TNX_DODGE_T_URGENT) return 0;

    cx = p->x + vx * tHit;
    cy = p->y + vy * tHit;
    r = mr + p->radius + TNX_DODGE_SAFETY;
    ddx = mx - cx;
    ddy = my - cy;

    return (ddx * ddx + ddy * ddy) <= r * r;
}

static float tnx_dodge_score(float dx, float dy, float mx, float my, float mr,
                           int haveIntent, float ix, float iy) {
    int i;
    float score = 0.0f;

    for (i = 0; i < t_dodge_n; i++) {
        const tnx_dodge_proj_t *p = &t_dodge_projs[i];
        float r = mr + p->radius + TNX_DODGE_SAFETY;
        float vx = p->dx * p->speed - dx * t_dodge_speed;
        float vy = p->dy * p->speed - dy * t_dodge_speed;
        float rx = p->x - mx;
        float ry = p->y - my;
        float a = vx * vx + vy * vy;
        float b = 2.0f * (rx * vx + ry * vy);
        float c = rx * rx + ry * ry;
        float minD2 = c;
        float danger;

        if (a > 1e-6f) {
            float tMin = -b / (2.0f * a);

            if (tMin > 0.0f && tMin <= TNX_DODGE_T_FIELD) {
                minD2 = c + b * tMin + a * tMin * tMin;
            } else if (tMin > TNX_DODGE_T_FIELD) {
                minD2 = c + b * TNX_DODGE_T_FIELD + a * TNX_DODGE_T_FIELD * TNX_DODGE_T_FIELD;
            }
        }

        danger = (minD2 < r * r) ? 2500.0f : (r * r) / (minD2 > 50.0f ? minD2 : 50.0f);
        score += danger;
    }

    if (haveIntent && (ix != 0.0f || iy != 0.0f)) {
        score -= (dx * ix + dy * iy) * TNX_DODGE_INTENT_W * 15.0f;
    }

    if (t_dodge_have_last && (t_ticks_a - t_dodge_last_tick) < (uint64_t)TNX_DODGE_INERTIA_TICKS) {
        score -= (dx * t_dodge_last_x + dy * t_dodge_last_y) * 45.0f;
    }

    return score;
}

static int tnx_dodge_unsafe(float dx, float dy, float mx, float my, float mr) {
    int i;

    for (i = 0; i < t_dodge_n; i++) {
        const tnx_dodge_proj_t *p = &t_dodge_projs[i];
        float r = mr + p->radius + TNX_DODGE_SAFETY;
        float vx = p->dx * p->speed - dx * t_dodge_speed;
        float vy = p->dy * p->speed - dy * t_dodge_speed;
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
        if (t1 > 0.0f && t1 <= TNX_DODGE_T_FIELD) return 1;
    }

    return 0;
}

static int tnx_dodge_danger(float mx, float my, float mr) {
    int i;

    for (i = 0; i < t_dodge_n; i++) {
        const tnx_dodge_proj_t *p = &t_dodge_projs[i];
        float r = mr + p->radius + TNX_DODGE_SAFETY * 2.5f;
        float dx = mx - p->x;
        float dy = my - p->y;
        float distSq = dx * dx + dy * dy;
        float vx;
        float vy;
        float c1;
        float c2;
        float tHit;

        if (distSq <= r * r) return 1;
        if (distSq <= TNX_DODGE_NEAR * TNX_DODGE_NEAR) return 1;

        vx = p->dx * p->speed;
        vy = p->dy * p->speed;
        c1 = dx * vx + dy * vy;
        if (c1 <= 0.0f) continue;

        c2 = vx * vx + vy * vy;
        if (c2 <= 0.0f) continue;

        tHit = c1 / c2;
        if (tHit > TNX_DODGE_T_FIELD) continue;

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

static int tnx_dodge_urgent_dir(float mx, float my, float mr, int haveIntent, float ix, float iy,
                              float *ox, float *oy) {
    float cand[TNX_DODGE_CAND_MAX][2];
    int n = 0;
    int urgent = 0;
    int i;
    int best = -1;
    float bestScore = 1e18f;

    for (i = 0; i < t_dodge_n && n + 2 < TNX_DODGE_CAND_MAX; i++) {
        const tnx_dodge_proj_t *p = &t_dodge_projs[i];
        float ax;
        float ay;
        float tx;
        float ty;

        if (!tnx_dodge_urgent(p, mx, my, mr)) continue;

        urgent++;

        tnx_dodge_norm(mx - p->x, my - p->y, &ax, &ay);

        tx = (-p->dy) * TNX_DODGE_PERP_W + ax * TNX_DODGE_AWAY_W + (haveIntent ? ix * 0.6f : 0.0f);
        ty = (p->dx) * TNX_DODGE_PERP_W + ay * TNX_DODGE_AWAY_W + (haveIntent ? iy * 0.6f : 0.0f);
        tnx_dodge_norm(tx, ty, &cand[n][0], &cand[n][1]);
        n++;

        tx = (p->dy) * TNX_DODGE_PERP_W + ax * TNX_DODGE_AWAY_W + (haveIntent ? ix * 0.6f : 0.0f);
        ty = (-p->dx) * TNX_DODGE_PERP_W + ay * TNX_DODGE_AWAY_W + (haveIntent ? iy * 0.6f : 0.0f);
        tnx_dodge_norm(tx, ty, &cand[n][0], &cand[n][1]);
        n++;
    }

    if (urgent == 0) return 0;

    for (i = 0; i < 16 && n < TNX_DODGE_CAND_MAX; i++) {
        float a = 6.283185307179586f * (float)i / 16.0f;

        cand[n][0] = cosf(a);
        cand[n][1] = sinf(a);
        n++;
    }

    for (i = 0; i < n; i++) {
        float s = tnx_dodge_score(cand[i][0], cand[i][1], mx, my, mr, haveIntent, ix, iy);

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

static void tnx_dodge_best_dir(float mx, float my, float mr, int haveIntent, float ix, float iy,
                             float *ox, float *oy) {
    int i;
    int best = 0;
    float bestScore = 1e18f;

    for (i = 0; i < TNX_DODGE_DIRS; i++) {
        float s = tnx_dodge_score(t_dodge_dir[i][0], t_dodge_dir[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    *ox = t_dodge_dir[best][0];
    *oy = t_dodge_dir[best][1];
}

static int tnx_dodge_apply(float inX, float inY, float mx, float my, float mr, int haveIntent,
                         float ix, float iy, float *ox, float *oy) {
    int i;
    int best = -1;
    float bestScore = 1e18f;

    *ox = inX;
    *oy = inY;

    if (!tnx_dodge_unsafe(inX, inY, mx, my, mr)) return 0;

    for (i = 0; i < TNX_DODGE_DIRS; i++) {
        float s;

        if (tnx_dodge_unsafe(t_dodge_dir[i][0], t_dodge_dir[i][1], mx, my, mr)) continue;

        s = tnx_dodge_score(t_dodge_dir[i][0], t_dodge_dir[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    if (best < 0) return 2;

    *ox = t_dodge_dir[best][0];
    *oy = t_dodge_dir[best][1];

    return 1;
}

static int tnx_dodge_decide(float px, float py, float *outX, float *outY, int *urgentOut,
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

    t_dodge_ox = px;
    t_dodge_oy = py;
    tnx_dodge_own_pos(&t_dodge_ox, &t_dodge_oy);

    tnx_dodge_collect(t_dodge_ox, t_dodge_oy);



    mr = tnx_own_radius();

    if (mr < TNX_OWN_RADIUS_MIN) mr = TNX_DATA_OWN_R;

    if (!tnx_dodge_danger(t_dodge_ox, t_dodge_oy, mr)) {
        tnx_dodge_commit();

        return 0;
    }

    if (t_have_angle) {
        iX = cosf(t_angle);
        iY = sinf(t_angle);
        haveIntent = 1;
    }

    urgent = tnx_dodge_urgent_dir(t_dodge_ox, t_dodge_oy, mr, haveIntent, iX, iY, &baseX, &baseY);

    if (urgent == 0) tnx_dodge_best_dir(t_dodge_ox, t_dodge_oy, mr, haveIntent, iX, iY, &baseX, &baseY);

    vo = tnx_dodge_apply(baseX, baseY, t_dodge_ox, t_dodge_oy, mr, haveIntent, iX, iY, &safeX, &safeY);

    t_dodge_last_x = safeX;
    t_dodge_last_y = safeY;
    t_dodge_have_last = 1;
    t_dodge_last_tick = t_ticks_a;

    tnx_dodge_commit();

    *outX = safeX;
    *outY = safeY;

    if (urgentOut) *urgentOut = (urgent > 0) ? 1 : 0;
    if (voOut) *voOut = vo;

    return 1;
}

int t_aim_ok = 0;


static int32_t t_aim_hx[TNX_AIM_PRED_MAX];
static int32_t t_aim_hy[TNX_AIM_PRED_MAX];
static uint64_t t_aim_ht[TNX_AIM_PRED_MAX];
static int t_aim_hn = 0;
static int t_aim_hslot = -1;

static void tnx_aim_push(int idx, int32_t x, int32_t y) {
    int i;

    if (idx != t_aim_hslot) {
        t_aim_hn = 0;
        t_aim_hslot = idx;
    }

    if (t_aim_hn >= TNX_AIM_PRED_MAX) {
        for (i = 1; i < TNX_AIM_PRED_MAX; i++) {
            t_aim_hx[i - 1] = t_aim_hx[i];
            t_aim_hy[i - 1] = t_aim_hy[i];
            t_aim_ht[i - 1] = t_aim_ht[i];
        }

        t_aim_hn = TNX_AIM_PRED_MAX - 1;
    }

    t_aim_hx[t_aim_hn] = x;
    t_aim_hy[t_aim_hn] = y;
    t_aim_ht[t_aim_hn] = t_ticks_a;

    t_aim_hn++;
}

static int tnx_aim_lead(int32_t *tx, int32_t *ty, float dist) {
    float vx = 0.0f;
    float vy = 0.0f;
    float wsum = 0.0f;
    float lead;
    int i;

    if (t_aim_hn < 2) return 0;

    for (i = 1; i < t_aim_hn; i++) {
        float w = (float)i;
        float dt = 0.0f;

        if (t_aim_ht[i] > t_aim_ht[i - 1]) {
            dt = (float)(t_aim_ht[i] - t_aim_ht[i - 1]) / t_meas_tps;
        }

        if (dt <= 0.0f) continue;

        vx += ((float)(t_aim_hx[i] - t_aim_hx[i - 1]) / dt) * w;
        vy += ((float)(t_aim_hy[i] - t_aim_hy[i - 1]) / dt) * w;
        wsum += w;
    }

    if (wsum <= 0.0f) return 0;

    vx /= wsum;
    vy /= wsum;

    lead = TNX_AIM_PRED_COEF * dist / TNX_AIM_PROJ_SPEED;

    if (!(lead > 0.0f) || lead > 4.0f) return 0;

    *tx = (int32_t)((float)t_aim_hx[t_aim_hn - 1] + vx * lead);
    *ty = (int32_t)((float)t_aim_hy[t_aim_hn - 1] + vy * lead);

    return 1;
}

int tnx_aim(void) {
    float bestD2 = TNX_AIM_RANGE * TNX_AIM_RANGE;
    int32_t mx = 0;
    int32_t my = 0;
    int best = -1;
    int i = 0;

    if (!TNX_AIM) return 0;

    t_aim_frames++;

    if (t_life != 1) return 0;
    if (!t_enemy_n) return 0;
    if ((t_aim_frames % TNX_AIM_INTERVAL) != 0) return 0;

    mx = (int32_t)t_dodge_ox;
    my = (int32_t)t_dodge_oy;

    if (mx == 0 && my == 0) return 0;

    for (i = 0; i < t_enemy_n && i < TNX_PLAYER_MAX; i++) {
        float ex = (float)(t_enemy_x[i] - mx);
        float ey = (float)(t_enemy_y[i] - my);
        float d2 = ex * ex + ey * ey;

        if (d2 < bestD2) {
            bestD2 = d2;
            best = i;
        }
    }

    if (best < 0) return 0;

    tnx_aim_push(best, t_enemy_x[best], t_enemy_y[best]);

    t_aim_tx = t_enemy_x[best];
    t_aim_ty = t_enemy_y[best];

    {
        int32_t leadX = t_aim_tx;
        int32_t leadY = t_aim_ty;

        if (tnx_aim_lead(&leadX, &leadY, sqrtf(bestD2))) {
            t_aim_tx = leadX;
            t_aim_ty = leadY;
        }
    }

    t_aim_ok = tnx_enqueue_type(t_aim_tx, t_aim_ty, (int)TNX_TYPE_ATTACK);


    return t_aim_ok;
}

int tnx_decide(int32_t ownX, int32_t ownY) {
    float px = (float)ownX;
    float py = (float)ownY;
    float tx = 0.0f;
    float ty = 0.0f;
    int picked = 0;
    int threatened = 0;
    int stick = 0;
    int safeOk = 0;
    float desiredDeg = 0.0f;

    t_js_live = 0;
    t_js_tick = t_ticks_a;

    t_life = tnx_life_3(px, py);


    if (t_life != 1) {
        t_moving = 0;
        t_released = 1;

        return 0;
    }

    tnx_aim();

    tnx_arm(px, py);

    t_dodge_px = px;
    t_dodge_py = py;
    t_dodge_have = 1;

    tnx_build();

    if (t_seg_count != t_prev_seg) {
        t_new_tick = (int)t_ticks_a;
        t_prev_seg = t_seg_count;

        if (TNX_REACT_CRIT && (t_ticks_a - t_crit_last) >= TNX_DATA_CRIT_EVERY) {
            t_crit_reaction = 1;
            t_crit_last = t_ticks_a;
        }
    }


    tnx_dodge_state_tick(px, py);

    tnx_stat_tick(px, py);

    threatened = tnx_threatened(px, py);

    if (t_seg_count > 0 && tnx_clearance_a(px, py) < TNX_ENGAGE_NEAR) {
        threatened = 1;
    }

    if (TNX_RAGE_FORCE && t_seg_count > 0) {
        if (!TNX_HIT_ONLY || tnx_imminent(px, py)) {
            threatened = 1;
        }
    }

    if (tnx_imminent(px, py)) {
        threatened = 1;
    }

    t_have_angle = 0;

    stick = tnx_joy_angle(&t_angle);

    if (stick) {
        t_have_angle = 1;
        desiredDeg = t_angle * 180.0f / 3.14159265358979f;
    }

    {
        int jsUrgent = 0;
        int jsVo = 0;
        float jsX = 0.0f;
        float jsY = 0.0f;

        t_js_picked = tnx_dodge_decide(px, py, &jsX, &jsY, &jsUrgent, &jsVo);

        if (t_js_picked) {
            tx = px + jsX * TNX_REACH;
            ty = py + jsY * TNX_REACH;
            picked = 1;

        }
    }

    threatened = t_js_picked;
    t_js_live = t_js_picked;

    if (t_js_picked) {
        t_tx_a = tx;
        t_ty_a = ty;
        t_moving = 1;
        t_start_x = px;
        t_start_y = py;

        tnx_enqueue((int32_t)tx, (int32_t)ty);
        tnx_move_to((int32_t)tx, (int32_t)ty, px, py);

        if (t_new_tick >= 0) {
            uint64_t react = t_ticks_a - (uint64_t)t_new_tick;

            if (t_react_min == 0 || react < t_react_min) t_react_min = react;
            if (react > t_react_max) t_react_max = react;
        }
    } else if (t_moving && tnx_passed(px, py)) {
        t_moving = 0;
    } else if (t_moving && stick) {
        float safe = tnx_safe_angle(px, py, desiredDeg, &safeOk);

        if (!safeOk && TNX_FLEE) {
            if (tnx_flee(px, py, &t_tx_a, &t_ty_a)) t_moving = 1;

        }

        if (safeOk) {
            float rad = safe * 3.14159265358979f / 180.0f;
            float ex = px + cosf(rad) * TNX_EXTEND_DEFAULT;
            float ey = py + sinf(rad) * TNX_EXTEND_DEFAULT;

            if (tnx_valid_point(ex, ey)) {
                t_tx_a = ex;
                t_ty_a = ey;
            }
        }
    } else if (t_moving) {
        t_tx_a = px;
        t_ty_a = py;
        t_moving = 0;
        t_released = 1;

        tnx_enqueue((int32_t)px, (int32_t)py);
        tnx_move_to((int32_t)px, (int32_t)py, px, py);
    } else {
        t_tx_a = px;
        t_ty_a = py;
    }

    tnx_walk_want(t_moving, ownX, ownY, (int32_t)t_tx_a, (int32_t)t_ty_a);




    return picked;
}

void tnx_autododge(void) {
    static int tagOnce = 0;


    if (!tagOnce) {
        tagOnce = 1;

    }

    tnx_input_release();

    tnx_stick(0, 0.0f, 0.0f);

    tnx_route(t_active);



    if (TNX_STATE_EVERY <= 1 || (t_ticks_a % (uint64_t)TNX_STATE_EVERY) == 0) tnx_state();

    tnx_paircal();

    tnx_obj_t objects[TNX_OBJECT_MAX];
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

    t_dodge_calls++;


    if (!t_base) return;

    if (t_dodge_calls <= TNX_CALL_LOGS ||
        (t_dodge_calls % TNX_CALL_EVERY) == 0) {
        uintptr_t probeOwn = 0;
        int32_t probeGid = 0;
        int32_t probeTeam = 0;
        int32_t probeCount = 0;


        tnx_own_by_min_gid(t_tick_array, t_tick_count, &probeOwn, &probeGid);

        if (probeOwn) tnx_read_int(probeOwn + TNX_OBJ_TEAM_OFF, &probeTeam);
        if (t_players_object) tnx_read_int(t_players_object + TNX_MGR_COUNT_OFF, &probeCount);

        {
            int listIdx = -1;
            const char *listFrom = "none";
            int32_t listGid = -1;

            if (tnx_own_from_list(t_dodge_probe_list, t_dodge_probe_usable, &listIdx, &listFrom)) {
                listGid = t_dodge_probe_list[listIdx].gid;
            }

        }

    }

    sourceIsMode = (t_scene_object != 0);

    if (sourceIsMode) {
        source = t_scene_object;
        sourceKind = "mode";
    } else if (t_players_object) {
        source = t_players_object;
        sourceKind = "manager";
    } else if (t_objvote_best_owner && t_objvote_best_teamcount >= TNX_OWNER_VOTE_TEAMS_MIN &&
               t_objvote_max_votes >= TNX_OWNER_VOTE_MIN) {
        source = t_objvote_best_owner;
        sourceKind = "objvote";
    } else if (t_trail_count > 0 && t_trail_best >= 0 && t_trail_best < t_trail_count) {
        source = (uintptr_t)t_trail[t_trail_best].manager;
        sourceKind = "trail";
    }

    if (!source) {
        t_no_source_passes++;

        if (t_no_source_passes >= 5 && !t_route_logged) {
            t_route_logged = 1;

        }
    } else {
        t_no_source_passes = 0;
    }

    if (!sourceIsMode && !t_players_object && source && strcmp(sourceKind, "trail") == 0 &&
        t_trail_best >= 0 && t_trail_best < t_trail_count && t_trail[t_trail_best].live == 0) {
    }


    t_ticks_a++;

    if (t_wrote_valid && !t_check_done &&
        (t_ticks_a - t_wrote_tick) >= TNX_VERIFY_FRAMES) {
        int32_t nowX = 0;
        int32_t nowY = 0;
        int32_t ctrlX_2 = 0;
        int32_t ctrlY_2 = 0;
        int32_t mgrX_2 = 0;
        int32_t mgrY_2 = 0;
        uintptr_t ctrl_2 = 0;
        uintptr_t mgr_2 = 0;

        ctrl_2 = tnx_controller();

        if (ctrl_2) {
            tnx_read_int(ctrl_2 + TNX_MOVE_X_OFF, &ctrlX_2);
            tnx_read_int(ctrl_2 + TNX_MOVE_Y_OFF, &ctrlY_2);
        }

        if (ctrl_2 && tnx_read_ptr(ctrl_2 + TNX_MGR_OFF, (void **)&mgr_2) && mgr_2) {
            tnx_read_int(mgr_2 + TNX_MOVE_X_OFF, &mgrX_2);
            tnx_read_int(mgr_2 + TNX_MOVE_Y_OFF, &mgrY_2);
        } else {
            mgr_2 = 0;
        }

        if (t_scene_object && tnx_read_int(t_scene_object + TNX_MODE_PREDICTX_OFF, &nowX) &&
            tnx_read_int(t_scene_object + TNX_MODE_PREDICTY_OFF, &nowY)) {

            {
                void *array = NULL;
                int32_t count = 0;
                int shown = 0;

                if (t_players_object &&
                    tnx_read_ptr(t_players_object + TNX_MGR_ARRAY_OFF, &array) && array &&
                    tnx_read_int(t_players_object + TNX_MGR_COUNT_OFF, &count)) {
                    for (int32_t i = 0; i < count && shown < TNX_POS_DUMPS; i++) {
                        void *element = NULL;
                        int32_t px = 0;
                        int32_t py = 0;

                        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element)) break;
                        if (!element) continue;

                        tnx_read_int((uintptr_t)element + TNX_OBJ_X_OFF, &px);
                        tnx_read_int((uintptr_t)element + TNX_OBJ_Y_OFF, &py);

                        shown++;

                    }
                }
            }
        }

        t_check_done = 1;
    }

    if (!source) {
        return;
    }

    if (t_setpred_state < 0) {
        t_setpred_state = tnx_verify_setprediction();
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        void *resolved = NULL;
        int changed = (t_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;

        if (sourceIsMode && t_hop_chosen == 1 && t_tick_object) {
            resolved = (void *)t_tick_object;
        } else if (sourceIsMode) {
            if (!tnx_read_ptr(source + TNX_MODE_MANAGER_OFF, &resolved) || !resolved) {
                resolved = NULL;
            }
        } else {
            resolved = (void *)source;
        }

        managerChanged = ((uintptr_t)resolved != t_manager);


        {
            int32_t liveCount = 0;

            if (resolved) tnx_read_int((uintptr_t)resolved + TNX_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && t_hop_chosen == 1 &&
                (liveCount != t_walk_count ||
                 (t_walk_tick != t_ticks_b && (t_ticks_b % TNX_WALK_EVERY) == 0))) {
                t_walk_count = liveCount;
                t_walk_tick = t_ticks_b;
                periodic = 1;

            }
        }

        if (!t_probe_done || changed || managerChanged || periodic ||
            (!t_coord_ok && probeNow > t_probe_last_ms + TNX_REPROBE_MS)) {
            t_probe_object = source;
            t_probe_last_ms = probeNow;
            t_manager = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || managerChanged || !t_probe_done);
                    tnx_probe((uintptr_t)resolved, t_scene_object, loud);

                if (loud) tnx_discriminate((uintptr_t)resolved);
            } else {
            }
        }
    }


    if (!t_setpred_state) {
        return;
    }

    {
        int gateOpen = (t_coord_ok || t_coord_usable >= TNX_MIN_USABLE) ? 1 : 0;

        if (gateOpen != t_gate_last) {
            t_gate_last = gateOpen;

        }
    }

    if (!t_coord_ok && t_coord_usable < TNX_MIN_USABLE) return;

    if (!t_scene_object) {
        return;
    }

    memset(objects, 0, sizeof(objects));


    usable = tnx_collect(t_manager, objects, TNX_OBJECT_MAX, &rejected);

    if (usable < TNX_MIN_USABLE_2) {

        return;
    }

    if (!tnx_read_int(t_scene_object + TNX_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!tnx_read_int(t_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    tnx_own_scan();

    {
        const char *ownFrom = "none";

        if (!tnx_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_resolve_own_2(objects, usable, &ownIndex, &ownFrom)) {
            return;
        }

        tnx_publish_own(objects[ownIndex].object, ownFrom);

        if (t_own_logs_b < 8) {
            uintptr_t ownVt = 0;
            uintptr_t ownCls = 0;

            t_own_logs_b++;

            tnx_vt_ok((uintptr_t)t_own_elem, &ownVt);

            if (ownVt >= t_base) ownCls = ownVt - t_base;

        }

        if (!t_own_logged) {
            t_own_logged = 1;

        }
    }

    t_own_elem_2 = objects[ownIndex].object;

    t_walk_ent = objects[ownIndex].object;

    tnx_walk_pump();

    ownTeam = (t_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
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
            if (objects[i].gid < TNX_PLAYER_GID) continue;
            if (objects[i].gid >= TNX_SHOT_GID) continue;

            team = (t_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
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

        team = (t_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                         : objects[i].teamNew;
        if (team == ownTeam) continue;

        threatsAlive++;

        if (tnx_dodge_is_proj(objects[i].object) == 0) continue;

        dx = (float)(ownX - objects[i].x);
        dy = (float)(ownY - objects[i].y);
        distance = dx * dx + dy * dy;

        if (distance < 1.0f) continue;

        weight = 1.0f / (sqrtf(distance) + 1.0f);
        escapeX += dx * weight;
        escapeY += dy * weight;
        threats++;
    }

    tnx_death_signals((ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].object : 0, ownX,
                           ownY);

    if (TNX_ELEM_RESET && ownIndex >= 0 && ownIndex < usable &&
        objects[ownIndex].object != t_last_own) {

        t_last_own = objects[ownIndex].object;
        t_stage = 0;
        t_last_write_ms = 0;
        t_issued = 0;
    }

    tnx_alive(ownX, ownY);


    t_side_hits = 0;
    t_side_projs = 0;

    {
        int32_t projCount = 0;
        int i = 0;

        if (t_manager) tnx_read_int(t_manager + TNX_MGR_COUNT_OFF, &projCount);

        t_own_team_a = (int)ownTeam;

        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= TNX_TEAM_MAX_2) t_own_team_seen = 1;

        tnx_roster(t_own_elem_2, ownIndex, (int)ownTeam, objects, usable);

        if (ownIndex < 0 || ownIndex >= usable || ownIndex >= TNX_OBJECT_MAX) {

            return;
        }


        if (tnx_life(objects[ownIndex].object, ownX, ownY)) return;

        tnx_proj_scan(t_manager, projCount);

        t_active = 0;
        t_side_hits = 0;

        for (i = 0; i < TNX_PROJ_MAX; i++) {
            if (t_projs[i].elem) t_side_projs++;
        }

        tnx_threats();

        if (tnx_decide(ownX, ownY)) {
            t_active = 1;
            t_side_hits = 1;
            t_tx = (int32_t)t_tx_a;
            t_ty = (int32_t)t_ty_a;
        }

        tnx_drive();

    }


    if (threats == 0 && t_side_hits == 0) {
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
        } else if (!t_active) {
            return;
        }

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        targetX = ownX + (int)(escapeX * step);
        targetY = ownY + (int)(escapeY * step);

        if (t_active) {
            targetX = t_tx;
            targetY = t_ty;
        }

        if (TNX_STEP > 0.0f) {
            float sdx = (float)(targetX - ownX);
            float sdy = (float)(targetY - ownY);
            float slen = sqrtf(sdx * sdx + sdy * sdy);

            if (slen > TNX_STEP) {

                targetX = ownX + (int)(sdx / slen * TNX_STEP);
                targetY = ownY + (int)(sdy / slen * TNX_STEP);
            }
        }

        tnx_clamp(&targetX, &targetY);

        if (t_stage >= TNX_STAGE_POSITION && t_side_hits > 0 && t_issued &&
            targetX == t_last_tx && targetY == t_last_ty) {
            return;
        }

        if (now < t_last_write_ms + (uint64_t)(t_side_hits > 0
                ? TNX_THREAT_MIN_MS : TNX_DODGE_MIN_MS)) {
            return;
        }

        t_last_write_ms = now;

        if (t_side_hits > 0) {
            t_last_tx = targetX;
            t_last_ty = targetY;
            t_issued = 1;
        }


        if (targetX > TNX_COORD_ABS_MAX) targetX = TNX_COORD_ABS_MAX;
        if (targetX < -TNX_COORD_ABS_MAX) targetX = -TNX_COORD_ABS_MAX;
        if (targetY > TNX_COORD_ABS_MAX) targetY = TNX_COORD_ABS_MAX;
        if (targetY < -TNX_COORD_ABS_MAX) targetY = -TNX_COORD_ABS_MAX;

        {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;
            uintptr_t thisInner = 0;

            if (TNX_QUEUE_GUARD && (!tnx_instance_shaped((uintptr_t)t_scene_object) ||
                                    !tnx_instance_shaped((uintptr_t)t_own_elem))) {

                return;
            }

            if (!tnx_mode_real((uintptr_t)t_scene_object, &thisVt, &thisChain, &thisInner)) {
                return;
            }

        }

        tnx_watch(ownX, ownY);


        t_engaged_frame = 1;



        t_wrote_tick = t_ticks_a;
        t_wrote_valid = 1;
        t_check_done = 0;

    }
}

void tnx_dodge_plan(uintptr_t manager, int32_t team) {
    void *array = NULL;
    int32_t count = 0;
    int live = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_int(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;
        int32_t t = 0;
        uint8_t dead = 0;
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_gameobject_shape((uintptr_t)element)) continue;
        if (!tnx_read_int((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid)) continue;
        if (!tnx_read_int((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (!tnx_read_byte((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead)) continue;

        live++;

    }

}

void tnx_dodge_all_teams(uintptr_t manager) {
    int32_t teams[TNX_OBJ_TEAM_MAX + 1];
    int teamCount = 0;
    void *array = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_int(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int i = 0; i <= TNX_OBJ_TEAM_MAX; i++) teams[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t t = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_read_int((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (t < 0 || t > TNX_OBJ_TEAM_MAX) continue;
        if (teams[t] >= 0) continue;

        teams[t] = t;
        teamCount++;
    }

    if (teamCount == 0) return;

    {
        int planned = 0;

        for (int t = 0; t <= TNX_OBJ_TEAM_MAX && planned < 2; t++) {
            if (teams[t] < 0) continue;

            tnx_dodge_plan(manager, t);
            planned++;
        }
    }
}

int t_dodge_probe_usable = 0;

float tnx_speed(void) {
    float v = t_walk_step * 60.0f;

    if (v < 120.0f) v = 120.0f;
    if (v > 1200.0f) v = 1200.0f;

    return v;
}

float tnx_seg_dist(float ax, float ay, float bx, float by, float px, float py) {
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

void tnx_threats(void) {
    int k = 0;

    if ((t_ticks_a % 60) != 0) return;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        const tnx_proj_t *p = &t_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        const char *verdict = "threat";

        if (!p->elem) continue;

        if (!tnx_proj_vel(p, &vx, &vy)) {
            verdict = p->hasPrev ? "vel-unreadable" : "one-sample";
        } else if (TNX_TEAM_FILTER && t_own_team_seen && p->team == t_own_team_a) {
            verdict = "own-team";
        } else if (sqrtf(vx * vx + vy * vy) < TNX_MIN_PROJ_SPEED) {
            verdict = "still";
        }

    }
}

int tnx_body_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (t_pl_n <= 0) return 0;

    for (i = 0; i < t_pl_n; i++) {
        float px = 0.0f;
        float py = 0.0f;

        if (t_pl_mine[i]) continue;

        px = (float)t_pl_x[i];
        py = (float)t_pl_y[i];

        if (tnx_seg_dist(ownX, ownY, x, y, px, py) < TNX_BODY_CLEAR) {

            if (t_pl_mine[i]) t_body_mine++;
            else t_body_enemy++;


            return 1;
        }
    }

    return 0;
}

float tnx_own_radius(void) {
    float r = 0.0f;

    if (!TNX_GEOM) return 0.0f;

    if (t_own_r > 1.0f) {
        r = t_own_r;

        if (r > TNX_OWN_RADIUS_MAX) r = TNX_OWN_RADIUS_MAX;
        if (r < TNX_OWN_RADIUS_MIN) r = TNX_OWN_RADIUS_MIN;

        return r;
    }


    return TNX_DATA_OWN_R;
}