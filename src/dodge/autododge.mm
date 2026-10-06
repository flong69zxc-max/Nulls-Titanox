#include "titanox.h"

static float t_dodge_px = 0.0f;
static float t_dodge_py = 0.0f;
static int t_dodge_have = 0;
static uint64_t t_freest_bullet = 0;
static int t_freest_logs = 0;
static float t_freest_hx = 0.0f;
static float t_freest_hy = 0.0f;
static int t_freest_have = 0;
static uint64_t t_freest_hold = 0;

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

uint64_t t_logs_9 = 0;

float t_spd_min = 0.0f;

float t_spd_max = 0.0f;

uint64_t t_gate_writes_2 = 0;

uint64_t t_gate_held = 0;

uint64_t t_update_hits = 0;

uint64_t t_move_hits = 0;

uint64_t t_ticks = 0;

__thread int t_in_drive = 0;

uint64_t t_reentry = 0;

uint64_t t_render_skip = 0;

uint64_t t_update_skip = 0;

int32_t t_pl_mine[TNX_PLAYER_MAX];

int t_attrib_hits = 0;

int t_attrib_miss = 0;

int t_attrib_logs = 0;

int t_block_hits = 0;

int t_label_builds = 0;

int t_trust_logs = 0;

int t_roster_logs = 0;

int t_enemy_blocks = 0;

int t_oneshot_segs = 0;

uint64_t t_flees = 0;

uint64_t t_dead_replaced = 0;

int t_new_tick = -1;

int t_prev_seg = -1;

int t_logs_8 = 0;

uint64_t t_mate_turns = 0;

uint64_t t_mate_stuck = 0;

int32_t t_pl_gid[TNX_PLAYER_MAX];

int32_t t_pl_sx[TNX_PLAYER_MAX];

int32_t t_pl_sy[TNX_PLAYER_MAX];

int t_pl_spawned[TNX_PLAYER_MAX];

int t_mates = 0;

int t_enemies = 0;

int t_agree = -1;

int t_cluster_logs = 0;

uint64_t t_freest_used = 0;

int t_dump_logs = 0;

uint64_t t_touchid_writes = 0;

uint64_t t_human = 0;

uint64_t t_stick_skips = 0;

uint64_t t_stuck_2 = 0;

int t_stuck_logs = 0;

int t_flag_logs = 0;

uint64_t t_dead_picks = 0;

int t_prev_idx = -1;

uint64_t t_hold_until = 0;

uint64_t t_last_danger = 0;

int32_t t_tx = 0;

int32_t t_ty = 0;

int t_active_2 = 0;

int t_build_tick = -1;

uint64_t t_escapes = 0;

uint64_t t_logs_7 = 0;

uint64_t t_lookahead = 0;

uint64_t t_rage_frames = 0;

int t_logs_4 = 0;

int t_have_angle = 0;

float t_angle = 0.0f;

float t_tx_2 = 0.0f;

float t_ty_2 = 0.0f;

int t_moving = 0;

float t_start_x = 0.0f;

float t_start_y = 0.0f;

int t_picks = 0;

int t_scene_skip = 0;

int t_drive_ticks = 0;

int t_drive_logs = 0;

uint64_t t_queue_calls = 0;

uint64_t t_queue_skips = 0;

int32_t t_sent_dx = 0;

int32_t t_sent_dy = 0;

int32_t t_last_tx_2 = 0;

int32_t t_last_ty_2 = 0;

uint64_t t_last_decision = 0;

int64_t t_decide_x = 0;

int64_t t_decide_y = 0;

int t_drift_logs = 0;

uint64_t t_drift_done = 0;

uint64_t t_max_frame = 0;

uint64_t t_traveled = 0;

float t_pair_dot_sum = 0.0f;

uint64_t t_pair_dot_n = 0;

float t_last_x_3 = 0.0f;

float t_last_y_3 = 0.0f;

int t_last_ok = 0;

uint64_t t_keeps = 0;

float t_mom_live = 0.0f;

int t_crit_reaction = 0;

uint64_t t_crit_last = 0;

int t_own_r_cfg_logs = 0;

int t_proj_r_cfg_logs = 0;

float t_tti_min = 0.0f;

uint64_t t_crit_took = 0;

float t_shot_speed[TNX_PROJ_MAX];

uint64_t t_shot_logs = 0;

uint64_t t_commit_until = 0;

uint64_t t_stat_picks = 0;

uint64_t t_stat_side = 0;

uint64_t t_stat_commit = 0;

uint64_t t_react_n = 0;

uint64_t t_react_sum = 0;

uint64_t t_react_min = 0;

uint64_t t_react_max = 0;

uint64_t t_last_stat = 0;

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

float t_track_rad[TNX_SEG_MAX];

uint64_t t_howto_logs = 0;

int t_side_last = -1;

int t_shot_key[TNX_SEG_MAX];

int t_stat_skip = 0;

uint64_t t_stat_reset = 0;

uint64_t t_own_obj_last = 0;

uint64_t t_no_threat_since = 0;

int t_pick_key_c = 0;

int t_pick_key_t = 0;

int t_tti_logs = 0;

uint64_t t_engage = 0;

uint64_t t_hseed = 0;

uint64_t t_evals = 0;

int t_sel[TNX_SEL_MAX];

int t_sel_n = 0;

uint64_t t_pos_skips = 0;

int t_cand_now[TNX_CAND];

int t_cand_seen = 0;

int32_t t_prev_x = 0;

int32_t t_prev_y = 0;

int t_respawns = 0;

int t_signal_logs_2 = 0;

int t_learn_logs = 0;

int t_rad_bad = 0;

int t_cal_miss = 0;

int t_cal_off_seen = -1;

float t_cal_rad_seen = 0.0f;

int t_cal_n = 0;

int t_snap_calls = 0;

int t_snap_live = 0;

int t_snap_logs = 0;

int t_snap_off_logs = 0;

int t_side_tick = 0;

int t_side_flips = 0;

int t_side_picks = 0;

uint64_t t_wall_stops = 0;

int tnx_ok(float v, float lo, float hi) {
    if (!(v >= lo && v <= hi)) return 0;

    return 1;
}

int t_rad_off = -1;

int t_rad_n = 0;

int t_rad_logs = 0;

float t_rad_est = 0.0f;

uint64_t t_rad_test = 0;

float t_own_r = 0.0f;

int t_own_r_n = 0;

int t_own_r_logs = 0;

int t_clip_win = 0;

int t_clip_test_win = 0;

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

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

        if (base && tnx_read_f32(base + (uintptr_t)t_rad_off, &r) &&
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

        t_rad_test++;

        if (!tnx_read_f32(base + (uintptr_t)off, &v)) continue;
        if (!tnx_ok(v, 1.0f, 1.0e6f)) continue;

        d = v - speed;
        if (d < 0.0f) d = -d;
        if (d > speed * TNX_CAL_TOL) continue;

        if (!tnx_read_f32(base + (uintptr_t)off + 4, &r)) continue;
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
        t_rad_n++;
        t_rad_est = r;

        if (t_rad_logs < TNX_GEOM_LOGS) {
            t_rad_logs++;

            TNX_LOGX("geom speedOff=%#x radOff=%#x r=%.0f speed=%.0f tol=%.0f%% held=%d tests=%llu - the "
                     "field holding a value within tolerance of the speed measured from the "
                     "position delta is the speed field, so the radius is the float right after "
                     "it; tests is how many offsets were read before the match, and once locked "
                     "every shot is read through that offset instead of the config constant",
                     off, off + 4, (double)r, (double)speed, (double)(TNX_CAL_TOL * 100.0f),
                     t_cal_n, (unsigned long long)t_rad_test);
        }

        return r;
    }

    t_cal_miss++;

    if (t_cal_miss == TNX_CAL_MISS && t_rad_logs < TNX_GEOM_LOGS) {
        t_rad_logs++;

        TNX_LOGX("geom no speed=%.0f tests=%llu range=%#x..%#x step=%d - no offset in that range "
                 "held a value within tolerance of the measured speed for %d frames running, so no "
                 "radius was taken and the hit test stays on the configured value; the counter only "
                 "prints once because forty misses already say the search does not apply to this "
                 "build, and a repeated line would be noise",
                 (double)speed, (unsigned long long)t_rad_test, TNX_CAL_OFF_LO, TNX_CAL_OFF_HI,
                 TNX_CAL_STEP, (int)TNX_CAL_TICKS);
    }

    if (t_proj_r_cfg_logs < 4) {
        t_proj_r_cfg_logs++;

        TNX_LOGX("proj radius cfg=%.0f - the offset search did not find the radius in the shot object, "
                 "so the advertised fallback is used instead of zero: the projectile table gives 150 as "
                 "the median radius over 505 projectiles, 100 for 73 of them and 50 for 65",
                 (double)TNX_DATA_PROJ_R);
    }

    return TNX_DATA_PROJ_R;
}

void tnx_build(void) {
    int k;

    t_seg_count = 0;
    t_build_tick = (int)t_ticks_3;

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
            p->team == t_own_team_3) continue;

        if (TNX_TEAM_STRICT && t_own_team_4 >= 0 && p->team == t_own_team_4) continue;
        if (tnx_proj_mine(p)) continue;

        if (!p->hasPrev) {

            uint64_t age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 1;

            vx = (float)(p->x - p->spawnX) / (float)age;
            vy = (float)(p->y - p->spawnY) / (float)age;

            if (fabsf(vx) < 0.5f && fabsf(vy) < 0.5f) continue;

            t_oneshot_segs++;
        } else if (!tnx_proj_vel(p, &vx, &vy)) continue;

        len = sqrtf(vx * vx + vy * vy);

        if (len < TNX_MIN_PROJ_SPEED) continue;

        speed = len * 60.0f;

        if (speed < 1.0f) speed = 1.0f;

        if (speed > t_shot_speed[k]) t_shot_speed[k] = speed;
        if (t_shot_speed[k] > 1.0f) speed = t_shot_speed[k];

        if (tnx_blacklisted(speed, 0.0f)) {
            if (t_stat_skip < 4) {
                t_stat_skip++;

                TNX_LOGX("skip speed=%.0f gid=%d - this projectile is on the do not dodge list, so it "
                         "is not counted as a threat and no commit is spent on it",
                         (double)speed, p->gid);
            }

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

            if (t_shot_logs < TNX_SHOT_LOGS) {
                t_shot_logs++;

                TNX_LOGX("shot gid=%d dir=(%.2f,%.2f) speed=%.0f eta=%.0fms miss=%.0f hits=%d inView=%d "
                         "impact=(%.0f,%.0f) own=(%.0f,%.0f) age=%llu - eta is the time from now to the "
                         "closest approach of this flight to own, miss how far off own that approach "
                         "passes, impact the world point where that happens, so hits means the line "
                         "crosses own body while the shot still has flight left, and inView keeps a "
                         "shot that has already gone past on the books while it is still inside the "
                         "view range, which is what lets the dodge keep leading a live bullet "
                         "instead of forgetting it the frame it passes",
                         p->gid, (double)nx, (double)ny, (double)speed,
                         (double)(tStar * 1000.0f / 60.0f), (double)miss, hits, inView,
                         (double)ix, (double)iy, (double)px0, (double)py0,
                         (unsigned long long)(p->qtick > p->ptick ? p->qtick - p->ptick : 0));
            }

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

                if (t_logs_9 < TNX_LOGS_5) {
                    t_logs_9++;

                    TNX_LOGX("drop rule=%d gid=%d speed=%.0f age=%llu rem=%.0f team=%d - a shot of "
                             "this shape cannot be walked out of, so reacting to it only spends "
                             "movement and hides the ones that can be dodged",
                             rule, p->gid, (double)speed,
                             (unsigned long long)((p->qtick > p->ptick) ? (p->qtick - p->ptick) : 0),
                             (double)rem, p->team);
                }

                continue;
            }
        }

        {
            float rem0 = rem;

            rem = tnx_clip_range((float)p->x, (float)p->y, vx / len, vy / len, rem);

            t_clip_test_win++;

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
                t_rad_bad++;
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

float tnx_clearance_2(float x, float y) {
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
    t_flees++;

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

                                                                                                                                              

float tnx_clearance_3(float px, float py, float dirX, float dirY) {
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

    t_evals++;

    return best;
}

float tnx_score(float px, float py, float dirX, float dirY, float len) {
    tnx_select(px, py);

    return tnx_clearance_3(px, py, dirX, dirY) +
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
        bestScore += TNX_DATA_MOMENTUM * (base * t_last_x_3 + baseY * t_last_y_3);
        baseScore = bestScore;
    }

    for (i = 0; i < 12; i++) {
        float a = rot[i] * rad;
        float c = cosf(a);
        float sn = sinf(a);
        float rx = base * c - baseY * sn;
        float ry = base * sn + baseY * c;
        float score = tnx_score(px, py, rx, ry, len);

        if (t_last_ok) score += TNX_DATA_MOMENTUM * (rx * t_last_x_3 + ry * t_last_y_3);

        if (score > bestScore) {
            bestScore = score;
            bestX = rx;
            bestY = ry;
        }
    }

    if (t_last_ok && bestX != base &&
        (bestScore - (tnx_score(px, py, base, baseY, len) +
                      TNX_DATA_MOMENTUM * (base * t_last_x_3 + baseY * t_last_y_3))) <
            TNX_DATA_BAND) {
        bestX = base;
        bestY = baseY;
        t_keeps++;
    }

    *dirX = bestX;
    *dirY = bestY;

    if (bestX != 0.0f || bestY != 0.0f) {
        float n = sqrtf(bestX * bestX + bestY * bestY);

        if (n > 0.0001f) {
            t_last_x_3 = bestX / n;
            t_last_y_3 = bestY / n;
            t_last_ok = 1;
        }
    }

    if (bestScore > baseScore) {
        t_mate_turns++;
    } else {
        t_mate_stuck++;
    }
}

int tnx_valid_point(float x, float y) {
    int32_t cx = (int32_t)x;
    int32_t cy = (int32_t)y;

    tnx_clamp(&cx, &cy);

    if (cx != (int32_t)x || cy != (int32_t)y) return 0;

    if (tnx_mate_blocked(x, y)) {
        t_block_hits++;

        return 0;
    }

    if (tnx_body_blocked(x, y, (float)t_own_x, (float)t_own_y)) {
        return 0;
    }

    if (tnx_enemy_blocked(x, y, (float)t_own_x, (float)t_own_y)) {
        t_enemy_blocks++;

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
    float ax = t_tx_2 - t_start_x;
    float ay = t_ty_2 - t_start_y;
    float len2 = ax * ax + ay * ay;
    float bx = 0.0f;
    float by = 0.0f;

    if (len2 <= 0.0f) return 1;

    bx = px - t_start_x;
    by = py - t_start_y;

    return (ax * bx + ay * by) >= len2 ? 1 : 0;
}

int tnx_best(float px, float py, float *tx, float *ty) {
    const float tau = 2.0f * 3.14159265358979f;

    if (TNX_JS_DODGE) return 0;

    float bestDist = 0.0f;
    float bestClear = 0.0f;
    float minSafe = 1000000.0f;
    int found = 0;
    int i;

    for (i = 0; i < TNX_NUM_ANGLES; i++) {
        int idx = i;
        float angle = 0.0f;
        float dx = 0.0f;
        float dy = 0.0f;
        float d = 0.0f;

        if (t_have_angle) {
            int base = (int)roundf(t_angle / tau * (float)TNX_NUM_ANGLES);
            int span = (i + 1) / 2;
            int sign = (i % 2) ? -1 : 1;

            idx = base + sign * span;

            while (idx < 0) idx += TNX_NUM_ANGLES;

            idx %= TNX_NUM_ANGLES;
        }

        angle = tau * (float)idx / (float)TNX_NUM_ANGLES;
        dx = cosf(angle);
        dy = sinf(angle);

        for (d = TNX_STEP_2; d <= TNX_MAX_DIST; d += TNX_STEP_2) {
            float cx = px + dx * d;
            float cy = py + dy * d;
            float clear = 0.0f;

            if (found && d > minSafe) break;

            if (!tnx_valid_point(cx, cy)) break;

            if (tnx_threatened(cx, cy)) continue;

            if (tnx_walk_into_bullet(px, py, dx, dy, d)) {
                t_freest_bullet++;

                break;
            }

            clear = tnx_clearance_2(cx, cy);

            if (!found || d < bestDist || (d == bestDist && clear > bestClear)) {
                bestDist = d;
                bestClear = clear;
                *tx = cx;
                *ty = cy;
                found = 1;
            }

            if (d < minSafe) minSafe = d;

            break;
        }
    }

    return found;
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
    float radius = TNX_JS_DODGE ? TNX_REACH : TNX_STEP_2;
    float speed = TNX_DATA_SPEED;
    float nowClear = tnx_js_clear(px, py, 0.0f, 0.0f);
    float bestScore = -1.0e18f;
    float bestEta = 0.0f;
    float bestRoom = 0.0f;
    float bestX = 0.0f;
    float bestY = 0.0f;
    int bestOk = 0;

    if (radius < 1.0f) radius = TNX_STEP_2;
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
            t_freest_bullet++;

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
                t_freest_hold++;

                return 0;
            }

            t_crit_took++;
        }
    }

    if (!TNX_ESCAPE && bestRoom < TNX_FREEST_MIN) return 0;

    *tx = bestX;
    *ty = bestY;
    t_freest_used++;

    if (t_freest_logs < TNX_FREEST_LOGS) {
        t_freest_logs++;

        TNX_LOGX("freest own=(%.0f,%.0f) pick=(%.0f,%.0f) eta=%.0f nowEta=%.0f room=%.0f segs=%d "
                 "score=%.0f nowClear=%.0f bullets=%llu hold=%llu - the pick is the direction with the "
                 "largest clearance along the path it would walk in one second, and the body stays put "
                 "when no direction beats standing still; bullets counts the headings refused because "
                 "walking them would put the body in front of a shot",
                 (double)px, (double)py, (double)bestX, (double)bestY, (double)bestEta,
                 (double)nowClear, (double)bestRoom, t_seg_count,
                 (double)bestScore, (double)nowClear,
                 (unsigned long long)t_freest_bullet, (unsigned long long)t_freest_hold);
    }

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

static int tnx_point_clear(float px, float py, float x, float y) {
    int i = 0;
    float mx = (px + x) * 0.5f;
    float my = (py + y) * 0.5f;

    if (!tnx_valid_point(x, y)) return 0;

    for (i = 0; i < t_seg_count; i++) {
        if (tnx_clear_at(px, py, i) < 0.0f) return 0;
        if (tnx_clear_at(x, y, i) < 0.0f) return 0;
        if (tnx_clear_at(mx, my, i) < 0.0f) return 0;
    }

    return 1;
}

                                                                                                                                                                                                                                                                                                

                                                                                                                                                                                                                                                                                                                                                                                                                                       

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               

static void tnx_state_reset(void) {
    t_commit_until = 0;
    t_moving = 0;
    t_side_last = -1;
    t_last_dist = 0.0f;
    t_stat_reset++;
}

static void tnx_dodge_state_tick(float px, float py) {
    uintptr_t own = tnx_own_obj();

    if (t_prev_own_tick != 0 && t_ticks_3 > t_prev_own_tick) {
        float dt = (float)(t_ticks_3 - t_prev_own_tick);

        t_own_vx = (px - t_prev_own_x) / dt;
        t_own_vy = (py - t_prev_own_y) / dt;
    }

    t_prev_own_x = px;
    t_prev_own_y = py;
    t_prev_own_tick = t_ticks_3;

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

    if (t_moving && tnx_wall_blocked(px, py, t_tx_2, t_ty_2) == 1) {
        tnx_state_reset();

        t_released = 1;
        t_wall_stops++;

        tnx_enqueue((int32_t)px, (int32_t)py);

        if (t_wall_stops <= TNX_WALL_LOGS) {
            TNX_LOGX("wallstop own=(%.0f,%.0f) target=(%.0f,%.0f) segs=%d stops=%llu - the tilemap "
                     "clips the run to the target that is still being walked, so the target is "
                     "replaced by own position in that frame instead of waiting for the no threat "
                     "timer: without this the character keeps pushing along the last heading and "
                     "stands in the wall until something else changes the target",
                     (double)px, (double)py, (double)t_tx_2, (double)t_ty_2, t_seg_count,
                     (unsigned long long)t_wall_stops);
        }

        return;
    }

    if (t_released) return;

    if (t_no_threat_since == 0) {
        t_no_threat_since = t_ticks_3;

        return;
    }

    if ((t_ticks_3 - t_no_threat_since) < (uint64_t)TNX_NO_THREAT_TICKS) return;

    tnx_state_reset();
    t_released = 1;

    tnx_enqueue((int32_t)px, (int32_t)py);

    TNX_LOGX("release own=(%.0f,%.0f) - with no threat left the engine would keep walking to the "
             "last target written, so the target is set to own position, which is what stops the "
             "character instead of leaving it to run on into whatever was in front of it",
             (double)px, (double)py);
}

#define TNX_JS3_SAFETY 28.0f
#define TNX_JS3_T_URGENT 0.9f
#define TNX_JS3_T_FIELD 1.8f
#define TNX_JS3_DIRS 64
#define TNX_JS3_PERP_W 2.4f
#define TNX_JS3_AWAY_W 1.0f
#define TNX_JS3_INTENT_W 1.2f
#define TNX_JS3_CHAR_SPEED 720.0f
#define TNX_JS3_MAX_DIST_SQ 25000000.0f
#define TNX_JS3_INERTIA_TICKS 24
#define TNX_JS3_CAND_MAX 160
#define TNX_JS3_SPEED_MIN 300
#define TNX_JS3_SPEED_MAX 8500
#define TNX_JS3_DIRT_MIN 6.0f
#define TNX_JS3_DIRT_SPAN 1.5f

typedef struct {
    float x;
    float y;
    float dx;
    float dy;
    float speed;
    float radius;
    int32_t gid;
} tnx_js3_proj_t;

static int t_js_picked = 0;
static int t_js_urgent = 0;
static int t_js_vo = 0;
static int t_js_n = 0;
static uint64_t t_js_picks = 0;

static tnx_js3_proj_t t_js3_projs[TNX_PROJ_MAX];
static tnx_js3_proj_t t_js3_prev[TNX_PROJ_MAX];
static int t_js3_n = 0;
static int t_js3_prev_n = 0;
static float t_js3_last_x = 0.0f;
static float t_js3_last_y = 0.0f;
static int t_js3_have_last = 0;
static uint64_t t_js3_last_tick = 0;
static float t_js3_dir[TNX_JS3_DIRS][2];
static int t_js3_dirs_built = 0;
static float t_js3_speed = TNX_JS3_CHAR_SPEED;

static void tnx_js3_build_dirs(void) {
    int i;

    if (t_js3_dirs_built) return;

    for (i = 0; i < TNX_JS3_DIRS; i++) {
        float a = 6.283185307179586f * (float)i / (float)TNX_JS3_DIRS;

        t_js3_dir[i][0] = cosf(a);
        t_js3_dir[i][1] = sinf(a);
    }

    t_js3_dirs_built = 1;
}

static void tnx_js3_norm(float x, float y, float *ox, float *oy) {
    float len = sqrtf(x * x + y * y);

    if (len < 1e-6f) {
        *ox = 1.0f;
        *oy = 0.0f;

        return;
    }

    *ox = x / len;
    *oy = y / len;
}

static void tnx_js3_speed_probe(void) {
    void *def = NULL;
    int32_t raw = 0;

    if (!t_own_elem) return;
    if (!tnx_read_ptr(t_own_elem + (uintptr_t)TNX_ELEM_DEF_OFF, &def) || !def) return;
    if (!tnx_read_i32((uintptr_t)def + (uintptr_t)OFF_CHARDATA_SPEED, &raw)) return;
    if (raw < TNX_JS3_SPEED_MIN || raw > TNX_JS3_SPEED_MAX) return;

    t_js3_speed = (float)raw;
}

static int tnx_js3_prev_slot(int32_t gid) {
    int i;

    if (gid == 0) return -1;

    for (i = 0; i < t_js3_prev_n; i++) {
        if (t_js3_prev[i].gid == gid) return i;
    }

    return -1;
}

static void tnx_js3_collect(float px, float py) {
    int i;
    int n = 0;

    tnx_js3_build_dirs();
    tnx_js3_speed_probe();

    for (i = 0; i < TNX_PROJ_MAX; i++) {
        const tnx_proj_t *p = &t_projs[i];
        tnx_js3_proj_t *q;
        uint8_t dead = 0;
        int slot;
        float mx;
        float my;
        float dx = 0.0f;
        float dy = 0.0f;
        float len = 0.0f;
        uint64_t dt;
        float speed;

        if (!p->elem) continue;
        if (t_own_team_4 >= 0 && p->team == t_own_team_4) continue;

        if (!tnx_read_u8(p->elem + (uintptr_t)TNX_OBJ_DEADFLAG_OFF, &dead)) continue;
        if (dead != 0) continue;

        mx = (float)p->x - px;
        my = (float)p->y - py;

        if (mx * mx + my * my > TNX_JS3_MAX_DIST_SQ) continue;

        slot = tnx_js3_prev_slot(p->gid);

        if (p->hasPrev) {
            dx = (float)(p->x - p->px);
            dy = (float)(p->y - p->py);
            len = sqrtf(dx * dx + dy * dy);
        }

        if (len > TNX_JS3_DIRT_MIN) {
            dx /= len;
            dy /= len;
        } else if (slot >= 0) {
            dx = t_js3_prev[slot].dx;
            dy = t_js3_prev[slot].dy;
        } else {
            float ang = 0.0f;

            if (tnx_read_f32(p->elem + (uintptr_t)TNX_PROJ_ANGLE_OFF, &ang) &&
                ang >= -7.0f && ang <= 7.0f) {
                dx = cosf(ang);
                dy = sinf(ang);
            } else {
                dx = 0.0f;
                dy = 0.0f;
            }
        }

        if (dx == 0.0f && dy == 0.0f) continue;

        dt = (p->ptick > 0 && t_ticks_3 > p->ptick) ? (t_ticks_3 - p->ptick) : 1;

        speed = (len > TNX_JS3_DIRT_SPAN) ? ((len / (float)dt) * 60.0f)
                                          : TNX_JS_SPEED_FALLBACK;

        if (speed < 1.0f) speed = TNX_JS_SPEED_FALLBACK;

        q = &t_js3_projs[n];
        q->x = (float)p->x;
        q->y = (float)p->y;
        q->dx = dx;
        q->dy = dy;
        q->speed = speed;
        q->radius = TNX_JS_RADIUS_FALLBACK;
        q->gid = p->gid;

        {
            float rr = tnx_proj_radius(p, speed);

            if (rr > 0.0f) q->radius = rr;
        }

        n++;
    }

    t_js3_n = n;
    t_js_n = n;
}

static void tnx_js3_commit(void) {
    t_js3_prev_n = t_js3_n;

    if (t_js3_n > 0) memcpy(t_js3_prev, t_js3_projs, (size_t)t_js3_n * sizeof(tnx_js3_proj_t));
}

static int tnx_js3_urgent(const tnx_js3_proj_t *p, float mx, float my, float mr) {
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
    if (tHit > TNX_JS3_T_URGENT) return 0;

    cx = p->x + vx * tHit;
    cy = p->y + vy * tHit;
    r = mr + p->radius + TNX_JS3_SAFETY;
    ddx = mx - cx;
    ddy = my - cy;

    return (ddx * ddx + ddy * ddy) <= r * r;
}

static float tnx_js3_score(float dx, float dy, float mx, float my, float mr,
                           int haveIntent, float ix, float iy) {
    int i;
    float score = 0.0f;

    for (i = 0; i < t_js3_n; i++) {
        const tnx_js3_proj_t *p = &t_js3_projs[i];
        float r = mr + p->radius + TNX_JS3_SAFETY;
        float vx = p->dx * p->speed - dx * t_js3_speed;
        float vy = p->dy * p->speed - dy * t_js3_speed;
        float rx = p->x - mx;
        float ry = p->y - my;
        float a = vx * vx + vy * vy;
        float b = 2.0f * (rx * vx + ry * vy);
        float c = rx * rx + ry * ry;
        float minD2 = c;
        float danger;

        if (a > 1e-6f) {
            float tMin = -b / (2.0f * a);

            if (tMin > 0.0f && tMin <= TNX_JS3_T_FIELD) {
                minD2 = c + b * tMin + a * tMin * tMin;
            } else if (tMin > TNX_JS3_T_FIELD) {
                minD2 = c + b * TNX_JS3_T_FIELD + a * TNX_JS3_T_FIELD * TNX_JS3_T_FIELD;
            }
        }

        danger = (minD2 < r * r) ? 2500.0f : (r * r) / (minD2 > 50.0f ? minD2 : 50.0f);
        score += danger;
    }

    if (haveIntent && (ix != 0.0f || iy != 0.0f)) {
        score -= (dx * ix + dy * iy) * TNX_JS3_INTENT_W * 15.0f;
    }

    if (t_js3_have_last && (t_ticks_3 - t_js3_last_tick) < (uint64_t)TNX_JS3_INERTIA_TICKS) {
        score -= (dx * t_js3_last_x + dy * t_js3_last_y) * 45.0f;
    }

    return score;
}

static int tnx_js3_unsafe(float dx, float dy, float mx, float my, float mr) {
    int i;

    for (i = 0; i < t_js3_n; i++) {
        const tnx_js3_proj_t *p = &t_js3_projs[i];
        float r = mr + p->radius + TNX_JS3_SAFETY;
        float vx = p->dx * p->speed - dx * t_js3_speed;
        float vy = p->dy * p->speed - dy * t_js3_speed;
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
        if (t1 > 0.0f && t1 <= TNX_JS3_T_FIELD) return 1;
    }

    return 0;
}

static int tnx_js3_danger(float mx, float my, float mr) {
    int i;

    for (i = 0; i < t_js3_n; i++) {
        const tnx_js3_proj_t *p = &t_js3_projs[i];
        float r = mr + p->radius + TNX_JS3_SAFETY * 2.5f;
        float dx = mx - p->x;
        float dy = my - p->y;
        float distSq = dx * dx + dy * dy;
        float vx;
        float vy;
        float c1;
        float c2;
        float tHit;

        if (distSq <= r * r) return 1;

        vx = p->dx * p->speed;
        vy = p->dy * p->speed;
        c1 = dx * vx + dy * vy;
        if (c1 <= 0.0f) continue;

        c2 = vx * vx + vy * vy;
        if (c2 <= 0.0f) continue;

        tHit = c1 / c2;
        if (tHit > TNX_JS3_T_FIELD) continue;

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

static int tnx_js3_urgent_dir(float mx, float my, float mr, int haveIntent, float ix, float iy,
                              float *ox, float *oy) {
    float cand[TNX_JS3_CAND_MAX][2];
    int n = 0;
    int urgent = 0;
    int i;
    int best = -1;
    float bestScore = 1e18f;

    for (i = 0; i < t_js3_n && n + 2 < TNX_JS3_CAND_MAX; i++) {
        const tnx_js3_proj_t *p = &t_js3_projs[i];
        float ax;
        float ay;
        float tx;
        float ty;

        if (!tnx_js3_urgent(p, mx, my, mr)) continue;

        urgent++;

        tnx_js3_norm(mx - p->x, my - p->y, &ax, &ay);

        tx = (-p->dy) * TNX_JS3_PERP_W + ax * TNX_JS3_AWAY_W + (haveIntent ? ix * 0.6f : 0.0f);
        ty = (p->dx) * TNX_JS3_PERP_W + ay * TNX_JS3_AWAY_W + (haveIntent ? iy * 0.6f : 0.0f);
        tnx_js3_norm(tx, ty, &cand[n][0], &cand[n][1]);
        n++;

        tx = (p->dy) * TNX_JS3_PERP_W + ax * TNX_JS3_AWAY_W + (haveIntent ? ix * 0.6f : 0.0f);
        ty = (-p->dx) * TNX_JS3_PERP_W + ay * TNX_JS3_AWAY_W + (haveIntent ? iy * 0.6f : 0.0f);
        tnx_js3_norm(tx, ty, &cand[n][0], &cand[n][1]);
        n++;
    }

    if (urgent == 0) return 0;

    for (i = 0; i < 16 && n < TNX_JS3_CAND_MAX; i++) {
        float a = 6.283185307179586f * (float)i / 16.0f;

        cand[n][0] = cosf(a);
        cand[n][1] = sinf(a);
        n++;
    }

    for (i = 0; i < n; i++) {
        float s = tnx_js3_score(cand[i][0], cand[i][1], mx, my, mr, haveIntent, ix, iy);

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

static void tnx_js3_best_dir(float mx, float my, float mr, int haveIntent, float ix, float iy,
                             float *ox, float *oy) {
    int i;
    int best = 0;
    float bestScore = 1e18f;

    for (i = 0; i < TNX_JS3_DIRS; i++) {
        float s = tnx_js3_score(t_js3_dir[i][0], t_js3_dir[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    *ox = t_js3_dir[best][0];
    *oy = t_js3_dir[best][1];
}

static int tnx_js3_apply(float inX, float inY, float mx, float my, float mr, int haveIntent,
                         float ix, float iy, float *ox, float *oy) {
    int i;
    int best = -1;
    float bestScore = 1e18f;

    *ox = inX;
    *oy = inY;

    if (!tnx_js3_unsafe(inX, inY, mx, my, mr)) return 0;

    for (i = 0; i < TNX_JS3_DIRS; i++) {
        float s;

        if (tnx_js3_unsafe(t_js3_dir[i][0], t_js3_dir[i][1], mx, my, mr)) continue;

        s = tnx_js3_score(t_js3_dir[i][0], t_js3_dir[i][1], mx, my, mr, haveIntent, ix, iy);

        if (s < bestScore) {
            bestScore = s;
            best = i;
        }
    }

    if (best < 0) return 2;

    *ox = t_js3_dir[best][0];
    *oy = t_js3_dir[best][1];

    return 1;
}

static int tnx_js3_decide(float px, float py, float *outX, float *outY, int *urgentOut,
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

    tnx_js3_collect(px, py);

    mr = tnx_own_radius();

    if (mr <= 0.0f) mr = TNX_DATA_OWN_R;

    if (!tnx_js3_danger(px, py, mr)) {
        tnx_js3_commit();

        return 0;
    }

    if (t_have_angle) {
        iX = cosf(t_angle);
        iY = sinf(t_angle);
        haveIntent = 1;
    }

    urgent = tnx_js3_urgent_dir(px, py, mr, haveIntent, iX, iY, &baseX, &baseY);

    if (urgent == 0) tnx_js3_best_dir(px, py, mr, haveIntent, iX, iY, &baseX, &baseY);

    vo = tnx_js3_apply(baseX, baseY, px, py, mr, haveIntent, iX, iY, &safeX, &safeY);

    t_js3_last_x = safeX;
    t_js3_last_y = safeY;
    t_js3_have_last = 1;
    t_js3_last_tick = t_ticks_3;

    tnx_js3_commit();

    *outX = safeX;
    *outY = safeY;

    if (urgentOut) *urgentOut = (urgent > 0) ? 1 : 0;
    if (voOut) *voOut = vo;

    return 1;
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

    tnx_arm(px, py);
    tnx_stats();

    t_dodge_px = px;
    t_dodge_py = py;
    t_dodge_have = 1;

    tnx_build();

    if (t_seg_count != t_prev_seg) {
        t_new_tick = (int)t_ticks_3;
        t_prev_seg = t_seg_count;

        if (TNX_REACT_CRIT && (t_ticks_3 - t_crit_last) >= TNX_DATA_CRIT_EVERY) {
            t_crit_reaction = 1;
            t_crit_last = t_ticks_3;
        }
    }

    tnx_crit_probe(px, py);

    tnx_dodge_state_tick(px, py);

    tnx_stat_tick(px, py);

    threatened = tnx_threatened(px, py);

    if (t_seg_count > 0 && tnx_clearance_2(px, py) < TNX_ENGAGE_NEAR) {
        threatened = 1;
        t_engage++;
    }

    if (TNX_RAGE_FORCE && t_seg_count > 0) {
        if (!TNX_HIT_ONLY || tnx_imminent(px, py)) {
            threatened = 1;
            t_rage_frames++;
        }
    }

    if (tnx_imminent(px, py)) {
        threatened = 1;
        t_lookahead++;
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

        t_js_picked = tnx_js3_decide(px, py, &jsX, &jsY, &jsUrgent, &jsVo);

        if (t_js_picked) {
            tx = px + jsX * TNX_REACH;
            ty = py + jsY * TNX_REACH;
            picked = 1;
            t_js_urgent = jsUrgent;
            t_js_vo = jsVo;
            t_js_picks++;
        }
    }

    threatened = t_js_picked;

    if (t_js_picked) {
        t_tx_2 = tx;
        t_ty_2 = ty;
        t_moving = 1;
        t_start_x = px;
        t_start_y = py;
        t_picks++;
        t_stat_picks++;
        t_commit_until = t_ticks_3;

        tnx_enqueue((int32_t)tx, (int32_t)ty);

        if (t_new_tick >= 0) {
            uint64_t react = t_ticks_3 - (uint64_t)t_new_tick;

            t_react_n++;
            t_react_sum += react;
            if (t_react_min == 0 || react < t_react_min) t_react_min = react;
            if (react > t_react_max) t_react_max = react;
        }
    } else if (t_moving && tnx_passed(px, py)) {
        t_moving = 0;
    } else if (t_moving && stick) {
        float safe = tnx_safe_angle(px, py, desiredDeg, &safeOk);

        if (!safeOk && TNX_FLEE) {
            if (tnx_flee(px, py, &t_tx_2, &t_ty_2)) t_moving = 1;
        }

        if (safeOk) {
            float rad = safe * 3.14159265358979f / 180.0f;
            float ex = px + cosf(rad) * TNX_EXTEND_DEFAULT;
            float ey = py + sinf(rad) * TNX_EXTEND_DEFAULT;

            if (tnx_valid_point(ex, ey)) {
                t_tx_2 = ex;
                t_ty_2 = ey;
            }
        }
    } else if (t_moving) {
        t_tx_2 = px;
        t_ty_2 = py;
        t_moving = 0;
        t_released = 1;

        tnx_enqueue((int32_t)px, (int32_t)py);
    }

    if (t_logs_4 < 24 && (t_ticks_3 % 60) == 0) {
        t_logs_4++;

        TNX_LOGX("dodge segs=%d threatened=%d picked=%d jsProj=%d jsUrgent=%d jsVo=%d target=(%.0f,%.0f) dist=%.0f way=%.0f "
                 "stick=%d angle=%.1f joyw=%d snap=%d moving=%d - the threat segments start where "
                 "each shot is NOW and run along its own flight, so a shot that already passed is "
                 "behind the segment and not a reason to run; the directions are walked outward from "
                 "the stick angle so a safe heading near the one the player holds wins; way is the "
                 "heading actually written towards in degrees, counted from the positive x axis, so "
                 "two consecutive lines with the same way is the character holding one direction",
                 t_seg_count, threatened, picked, t_js_n, t_js_urgent, t_js_vo,
                 (double)t_tx_2, (double)t_ty_2,
                 (double)sqrtf((t_tx_2 - px) * (t_tx_2 - px) +
                               (t_ty_2 - py) * (t_ty_2 - py)),
                 (double)(atan2f(t_ty_2 - py, t_tx_2 - px) * 180.0f / 3.14159265358979f),
                 stick, (double)desiredDeg, TNX_JOY_WRITE, t_snap_live, t_moving);
    }

    if (t_moving) tnx_snap(t_tx_2 - px, t_ty_2 - py);

    tnx_predict_2(ownX, ownY, t_tx_2, t_ty_2);

    tnx_stat_report();

    return picked;
}

void tnx_autododge_v48(void) {
    static int tagOnce = 0;

    tnx_phase("dodge-enter");

    if (!tagOnce) {
        tagOnce = 1;

        TNX_LOGX("build v37 hardOff=%d speed=%.0f ownR=%.0f projR=%.0f momentum=%.0f hold=%d band=%.0f "
                 "critEvery=%d dirs=%d reach=%.0f step=%.0f - every setting printed here is taken from "
                 "the game tables rather than from a hardcoded guess: speed 750 is what 61 of the 127 "
                 "heroes move at, ownR 120 is the collision radius of 101 of 127, projR 150 is the "
                 "median over 505 projectiles, while momentum, hold and critEvery exist because the "
                 "critical path used to drop the momentum and bypass the hold on nearly every frame, "
                 "which let the ring pick a fresh heading forty-eight ways each frame and that is what "
                 "made the body twitch in place",
                 (int)TNX_SNAP_HARD_OFF, (double)TNX_DATA_SPEED, (double)TNX_DATA_OWN_R,
                 (double)TNX_DATA_PROJ_R, (double)TNX_DATA_MOMENTUM, (int)TNX_DATA_HOLD,
                 (double)TNX_DATA_BAND, (int)TNX_DATA_CRIT_EVERY, (int)TNX_DIR_COUNT,
                 (double)TNX_REACH, (double)DODGE_STEP);
    }

    tnx_input_release();

    tnx_stick(0, 0.0f, 0.0f);

    tnx_route(t_active_2);

    tnx_drift();

    tnx_state();

    if (TNX_DIAG_EVERY <= 0 || (t_ticks_3 % (uint64_t)TNX_DIAG_EVERY) == 0) {
        uint64_t diag0 = tnx_us();

        uint64_t slot = (t_ticks_3 / (uint64_t)TNX_DIAG_EVERY) % 4;

        if (slot == 0) tnx_core();
        else if (slot == 1) tnx_dump();
        else if (slot == 2) tnx_census();

        t_diag_us = tnx_us() - diag0;

        if (t_diag_us > t_diag_max_us) t_diag_max_us = t_diag_us;
    }

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

    if (t_dodge_calls <= TNX_CALL_LOGS ||
        (t_dodge_calls % TNX_CALL_EVERY) == 0) {
        TNX_LOGX("dodge CALLED n=%llu base=%p scene=%p container=%p array=%p count=%d hop=%d "
                 "gidFloor=%d gidMax=%d playerMax=%d - printed before every early return and keyed "
                 "on the number of calls and not on a tick counter, because the v137 run printed no "
                 "probe line at all and the two possible reasons, a gate before the line and a "
                 "counter that never advanced, cannot be told apart from the absence of a line",
                 (unsigned long long)t_dodge_calls, (void *)t_base, (void *)t_scene_object,
                 (void *)t_players_object, (void *)t_players_array, t_players_count, t_hop_chosen,
                 TNX_GID_FLOOR, TNX_GID_MAX, TNX_PLAYER_GID_MAX);
    }

    if (!t_base) return;

    if (t_dodge_calls <= TNX_CALL_LOGS ||
        (t_dodge_calls % TNX_CALL_EVERY) == 0) {
        uintptr_t probeOwn = 0;
        int32_t probeGid = 0;
        int32_t probeTeam = 0;
        int32_t probeCount = 0;

        t_probe_tick = t_ticks_4;

        tnx_own_by_min_gid(t_tick_array, t_tick_count, &probeOwn, &probeGid);

        if (probeOwn) tnx_read_i32(probeOwn + TNX_OBJ_TEAM_OFF, &probeTeam);
        if (t_players_object) tnx_read_i32(t_players_object + TNX_MGR_COUNT_OFF, &probeCount);

        {
            int listIdx = -1;
            const char *listFrom = "none";
            int32_t listGid = -1;

            if (tnx_own_from_list(t_dodge_probe_list, t_dodge_probe_usable, &listIdx, &listFrom)) {
                listGid = t_dodge_probe_list[listIdx].gid;
            }

            TNX_LOGX("dodge list usable=%d from=%s idx=%d gid=%d minGidSeen=%d chosenGid=%d "
                     "chosenIdx=%d - the resolver runs on the very array the walk collected and "
                     "reports which entry it picked, so a disagreement between the smallest id seen "
                     "and the id chosen is visible in one line instead of being inferred",
                     t_dodge_probe_usable, listFrom, listIdx, listGid, probeGid, listGid, listIdx);
        }

        TNX_LOGX("dodge probe tick=%llu frames=%llu scene=%p container=%p array=%p count=%d "
                 "hop=%d own=%p ownGid=%d ownTeam=%d coordOk=%d coordUsable=%d writeTest=%d - this "
                 "line is printed before every early return of the dodge, so 'the dodge did not run' "
                 "can never again be concluded from the absence of a log line; in the v134 run the "
                 "dodge wrote nothing and said nothing, and it took a manual read of the resolver to "
                 "learn that the container globals and the walked list disagreed",
                 (unsigned long long)t_ticks_4, (unsigned long long)t_ticks_3,
                 (void *)t_scene_object, (void *)t_players_object, (void *)t_players_array,
                 probeCount, t_hop_chosen, (void *)probeOwn, probeGid, probeTeam,
                 t_coord_ok, t_coord_usable, TNX_MODE);
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

            TNX_LOGX("route: five passes with no source at all - mode=%p manager=%p "
                     "objvote=%p trailBest=%p; the remaining path is the ClientInput route, and its "
                     "hooks report separately (E5 setClientPredictionMoveTo, E6 sendMovement)",
                     (void *)t_scene_object, (void *)t_players_object, (void *)t_objvote_best_owner,
                     (void *)((t_trail_best >= 0 && t_trail_best < t_trail_count)
                                  ? t_trail[t_trail_best].manager
                                  : 0));
        }
    } else {
        t_no_source_passes = 0;
    }

    if (!sourceIsMode && !t_players_object && source && strcmp(sourceKind, "trail") == 0 &&
        t_trail_best >= 0 && t_trail_best < t_trail_count && t_trail[t_trail_best].live == 0) {
        if ((t_ticks_3 % 900) == 1) {
            TNX_LOGX("dodge idle ticks=%llu: best trail candidate has live=0, waiting "
                     "(trailBest=%p nonEmpty=%d count=%d stable=%d)",
                     (unsigned long long)t_ticks_3, (void *)source,
                     t_trail[t_trail_best].nonEmpty, t_trail[t_trail_best].count,
                     t_trail[t_trail_best].stable);
        }
    }

    tnx_frame();

    t_ticks_3++;

    if (t_wrote_valid && !t_check_done &&
        (t_ticks_3 - t_wrote_tick) >= TNX_VERIFY_FRAMES) {
        int32_t nowX = 0;
        int32_t nowY = 0;

        if (t_scene_object && tnx_read_i32(t_scene_object + TNX_MODE_PREDICTX_OFF, &nowX) &&
            tnx_read_i32(t_scene_object + TNX_MODE_PREDICTY_OFF, &nowY)) {
            TNX_LOGX("write verify: wrote=(%d,%d) now=(%d,%d) %s frames=%d testWrites=%llu - "
                     "kept means the engine left the two words alone, overwritten means the input "
                     "path rewrites them before anything is sent",
                     t_wrote_x, t_wrote_y, nowX, nowY,
                     (nowX == t_wrote_x && nowY == t_wrote_y) ? "kept" : "overwritten",
                     (int)(t_ticks_3 - t_wrote_tick),
                     (unsigned long long)t_test_writes);

            {
                void *array = NULL;
                int32_t count = 0;
                int shown = 0;

                if (t_players_object &&
                    tnx_read_ptr(t_players_object + TNX_MGR_ARRAY_OFF, &array) && array &&
                    tnx_read_i32(t_players_object + TNX_MGR_COUNT_OFF, &count)) {
                    for (int32_t i = 0; i < count && shown < TNX_POS_DUMPS; i++) {
                        void *element = NULL;
                        int32_t px = 0;
                        int32_t py = 0;

                        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element)) break;
                        if (!element) continue;

                        tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px);
                        tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py);

                        shown++;

                        TNX_LOGX("verify pos elem[%d] %p pos=(%d,%d)", i, element, px, py);
                    }
                }
            }
        }

        t_check_done = 1;
    }

    if (t_enter_tick != t_ticks_4 && (t_ticks_4 < 5 || (t_ticks_4 % 5) == 0)) {
        t_enter_tick = t_ticks_4;
        t_entry_logs++;

        {
            int32_t oix = 0;
            int32_t oiy = 0;

            tnx_interp(&oix, &oiy);

            TNX_LOGX("dodge ENTERED tick=%llu frames=%llu mode=%p manager=%p hop=%d source=%p "
                     "kind=%s setpredFn=%d coordOk=%d usable=%d writes=%llu ownInterpX=%d ownInterpY=%d "
                     "modeVar=%d gate1=%d gate2=%d - ownInterpX/Y is the live own position read from "
                     "client+%#llx/+%#llx, so a dodge line with coordOk=0 can still carry a moving own "
                     "position",
                     (unsigned long long)t_ticks_4, (unsigned long long)t_ticks_3,
                     (void *)t_scene_object, (void *)t_players_object, t_hop_chosen, (void *)source,
                     sourceKind, t_setpred_state, t_coord_ok, t_coord_usable,
                     (unsigned long long)t_writes_3, oix, oiy, tnx_mode(),
                     (tnx_mode() == TNX_MODE_TARGET) ? 1 : 0, (tnx_inner() == 1) ? 1 : 0,
                     (unsigned long long)TNX_CLIENT_POS_X_OFF,
                     (unsigned long long)TNX_CLIENT_POS_Y_OFF);
        }

        tnx_interp_line();
        tnx_gate_report(tnx_slot_probe());
    }

    if (!source) {
        if ((t_ticks_3 % 900) == 1) {
            TNX_LOGX("dodge idle ticks=%llu: no mode, no manager and no trail candidate yet "
                     "(bestLive=%d bestCount=%d) setpred=%d",
                     (unsigned long long)t_ticks_3, t_manager_best_live,
                     t_manager_best_count, t_setpred_state);
        }
        return;
    }

    if (t_setpred_state < 0) {
        t_setpred_state = tnx_verify_setprediction();
        t_setpred_2 = t_setpred_state ? (t_base + TNX_RVA_SETPREDICTION) : 0;
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

        if (managerChanged && t_walk_relogs < 6) {
            t_walk_relogs++;

            TNX_LOGX("walk manager=%p hop=%d source=%p kind=%s - the container is re-read from "
                     "the chain globals on this tick, so the walk follows scene+0x28 -> +%#llx "
                     "instead of stopping on the client", resolved, t_hop_chosen,
                     (void *)source, sourceKind, (unsigned long long)TNX_CLIENT_HOP_OFF);
        }

        {
            int32_t liveCount = 0;

            if (resolved) tnx_read_i32((uintptr_t)resolved + TNX_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && t_hop_chosen == 1 &&
                (liveCount != t_walk_count ||
                 (t_walk_tick != t_ticks_4 && (t_ticks_4 % TNX_WALK_EVERY) == 0))) {
                t_walk_count = liveCount;
                t_walk_tick = t_ticks_4;
                periodic = 1;

                TNX_LOGX("walk tick=%llu manager=%p count=%d - the walk is driven by the tick "
                         "and by the count, not by the array, so it reports every %d ticks while "
                         "the hop is %d even when the container itself has not changed",
                         (unsigned long long)t_ticks_4, resolved, liveCount, TNX_WALK_EVERY,
                         t_hop_chosen);
            }
        }

        if (!t_probe_done_2 || changed || managerChanged || periodic ||
            (!t_coord_ok && probeNow > t_probe_last_ms + TNX_REPROBE_MS)) {
            t_probe_object = source;
            t_probe_last_ms = probeNow;
            t_manager = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || managerChanged || !t_probe_done_2);
                    tnx_probe_3((uintptr_t)resolved, t_scene_object, loud);

                if (loud) tnx_discriminate((uintptr_t)resolved);
            } else {
                TNX_LOGX("probe skipped: source %p (%s) has no manager at +0x%llx and hop=%d",
                         (void *)source, sourceIsMode ? "mode" : "manager",
                         (unsigned long long)TNX_MODE_MANAGER_OFF, t_hop_chosen);
            }
        }
    }

    t_ticks_2++;

    if (!t_setpred_state) {
        if (t_giveup_logs < 3) {
            t_giveup_logs++;
            TNX_LOGX("dodge idle: no verified actuator (fingerprint state=%d -- this is the "
                     "byte check of the function, not a write)", t_setpred_state);
        }
        return;
    }

    {
        int gateOpen = (t_coord_ok || t_coord_usable >= TNX_MIN_USABLE) ? 1 : 0;

        if (gateOpen != t_gate_last) {
            t_gate_last = gateOpen;
            t_gate_logs++;

            if (t_gate_logs <= 16) {
                TNX_LOGX("gate %s: coord_ok=%d usable=%d distinct=%d minUsable=%d - the dodge runs "
                         "on usable objects now, because a container that holds only the player still "
                         "carries the player's own coordinates and the whole threat list, while the old "
                         "gate was coord_ok alone: the 17:12 run shows it going false for five seconds "
                         "in the middle of a firefight (usable=1 at 37.219, 39.020 and 40.401) with no "
                         "dodge line in exactly those seconds, and shots do not count because they are "
                         "rejected as non-players",
                         gateOpen ? "open" : "shut", t_coord_ok, t_coord_usable,
                         t_coord_distinct, TNX_MIN_USABLE);
            }
        }
    }

    if (!t_coord_ok && t_coord_usable < TNX_MIN_USABLE) return;

    if (!t_scene_object) {
        if (t_giveup_logs < 9) {
            t_giveup_logs++;
            TNX_LOGX("dodge idle: coordinates confirmed but the mode is unknown, so the "
                     "actuator has no `this` -- nothing written");

            if (!t_idle_probe_logged) {
                t_idle_probe_logged = 1;

                TNX_LOGX("dodge idle probe modeCandidate=%p vt=%#llx whyRejected=%s hits=%d "
                         "fromChain=%d", (void *)t_last_cand,
                         (unsigned long long)t_last_vt,
                         t_last_why[0] ? t_last_why : "none-seen", t_chain_hits,
                         t_mode_from_chain);
            }
        }
        return;
    }

    memset(objects, 0, sizeof(objects));

    tnx_phase("collect");

    usable = tnx_collect(t_manager, objects, TNX_OBJECT_MAX, &rejected);

    if (usable < TNX_MIN_USABLE_2) {
        if ((t_ticks_3 % 60) == 0) {
            TNX_LOGX("dodge idle: %d usable object(s) and this build needs %d - the old floor was "
                     "two, so a container holding only the player switched the dodge off completely "
                     "while shots were in the air, which is the 19:18 run where the census reads "
                     "players=1 shots=6 with no dodge line at all", usable, TNX_MIN_USABLE_2);
        }

        return;
    }

    if (!tnx_read_i32(t_scene_object + TNX_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!tnx_read_i32(t_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    tnx_own_scan();

    {
        const char *ownFrom = "none";

        if (!tnx_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_resolve_own_2(objects, usable, &ownIndex, &ownFrom)) {
            if (t_giveup_logs < 6 || (t_ticks_3 % 60) == 0) {
                t_giveup_logs++;

                TNX_LOGX("dodge idle: no own element - the scan found nothing at scanIndex=%d "
                         "scanPtr=%p and the prediction fallback (%d,%d) found nothing either, "
                         "usable=%d", t_own_index_3, (void *)t_own_ptr_4, predictX, predictY,
                         usable);
            }

            return;
        }

        tnx_publish_own(objects[ownIndex].object, ownFrom);

        if (t_own_logs_6 < 8) {
            uintptr_t ownVt = 0;
            uintptr_t ownCls = 0;

            t_own_logs_6++;

            tnx_vt_ok((uintptr_t)t_own_elem, &ownVt);

            if (ownVt >= t_base) ownCls = ownVt - t_base;

            TNX_LOGX("dodge own elem=%p vt=%p classRva=%#llx from=%s index=%d pos=(%d,%d) - "
                     "classRva is what the census classRva of the same element index has to match, "
                     "and the actuator uses this exact element or nothing",
                     (void *)t_own_elem, (void *)ownVt, (unsigned long long)ownCls, ownFrom,
                     ownIndex, objects[ownIndex].x, objects[ownIndex].y);
        }

        if (!t_own_logged) {
            t_own_logged = 1;

            TNX_LOGX("dodge own resolved from %s at +%#llx index=%d object=%p pos=(%d,%d) - "
                     "the scan is tried first and the prediction pair is only the fallback, so "
                     "the dodge and the gate line name the same element", ownFrom,
                     (unsigned long long)t_own_off, ownIndex, objects[ownIndex].object,
                     objects[ownIndex].x, objects[ownIndex].y);
        }
    }

    t_own_elem_2 = objects[ownIndex].object;

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

        t_enemy_elem = bestEnemy;
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
        if (t_last_own && t_elem_logs < 4) {
            t_elem_logs++;

            TNX_LOGX("own element changed %p -> %p at (%d,%d): the ladder, the heading, the write "
                     "clock and the issued flag are cleared, because a respawn or a different element "
                     "carries none of the state the last life built",
                     (void *)t_last_own, (void *)objects[ownIndex].object, ownX, ownY);
        }

        t_last_own = objects[ownIndex].object;
        t_stage = 0;
        t_stuck = 0;
        t_prev_idx = -1;
        t_hold_until = 0;
        t_last_danger = 0;
        t_last_write_ms = 0;
        t_issued = 0;
    }

    tnx_alive(ownX, ownY);

    tnx_phase("sidestep");

    t_side_hits = 0;
    t_side_projs = 0;

    {
        int32_t projCount = 0;
        int i = 0;

        if (t_manager) tnx_read_i32(t_manager + TNX_MGR_COUNT_OFF, &projCount);

        t_own_team_3 = (int)ownTeam;

        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= TNX_TEAM_MAX_2) t_own_team_seen = 1;

        tnx_roster(t_own_elem_2, ownIndex, (int)ownTeam, objects, usable);

        if (ownIndex < 0 || ownIndex >= usable || ownIndex >= TNX_OBJECT_MAX) {
            TNX_LOGX("sidestep aborted: ownIndex=%d usable=%d max=%d", ownIndex, usable,
                     TNX_OBJECT_MAX);

            return;
        }

        TNX_LOGX("sidestep own=%p index=%d usable=%d projCount=%d",
                 (void *)objects[ownIndex].object, ownIndex, usable, projCount);

        if (tnx_life(objects[ownIndex].object, ownX, ownY)) return;

        tnx_proj_scan(t_manager, projCount);

        t_active_2 = 0;
        t_side_hits = 0;

        for (i = 0; i < TNX_PROJ_MAX; i++) {
            if (t_projs[i].elem) t_side_projs++;
        }

        tnx_threats();

        if (tnx_decide(ownX, ownY)) {
            t_active_2 = 1;
            t_side_hits = 1;
            t_tx = (int32_t)t_tx_2;
            t_ty = (int32_t)t_ty_2;
            t_dir_x = t_tx_2 - (float)ownX;
            t_dir_y = t_ty_2 - (float)ownY;
        }

        tnx_drive();

        if (t_active_2 && t_logs < TNX_LOGS) {
            t_logs++;

            TNX_LOGX("dodge own=(%d,%d) target=(%d,%d) projectiles=%d liveThreats=%d dirIdx=%d "
                     "reach=%.0f engage=%.0f - %d directions are scored by the closest approach of the threat "
                     "against a point moving at the character speed along that direction, the score "
                     "carries a momentum term toward the previous direction, and the chosen heading "
                     "is locked for %d ms inside a band of %.0f, which is what stops the character "
                     "sliding between two nearly equal directions, and crit is set when the impact "
                     "of the nearest live segment is inside %d ms or the threat set changed on this "
                     "frame: tti=%.0fms crit=%d criticalPicks=%llu",
                     ownX, ownY, t_tx, t_ty, t_side_projs, t_live_threats,
                     t_prev_idx, (double)TNX_REACH, (double)TNX_ENGAGE, TNX_DIRS,
                     TNX_LOCK_MS, (double)TNX_DATA_BAND, (int)TNX_CRITICAL_MS,
                     (double)t_tti_min, t_crit_reaction, (unsigned long long)t_crit_took);
        }
    }

    if (!t_side_hits && (t_proj_own + t_proj_other) > 0 && (t_ticks_3 % 240) == 0) {
        TNX_LOGX("no shot survived the filters: tracked=%d ownTeam=%d flewAway=%d cannotReach=%d - "
                 "the ring had nothing left to dodge, so a dodge that stops while shots are in the "
                 "air is read from this line first", t_proj_own + t_proj_other,
                 t_proj_own, t_drop_along, t_drop_reach);
    }

    if (threats == 0 && t_side_hits == 0) {
        if (t_ticks_2 % 256 == 0) {
            TNX_LOGX("live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
                     "enemiesActive=%d enemiesInRange=0 projSeen=%d projOnRay=0 writes=%llu "
                     "threatsTotal=%llu",
                     (unsigned long long)t_ticks_2, ownX, ownY, ownTeam, predictX, predictY,
                     threatsAlive, threats, t_side_projs, (unsigned long long)t_writes_3,
                     (unsigned long long)t_threat_ticks);
        }
        return;
    }

    t_threat_ticks++;

    {
        float length = sqrtf(escapeX * escapeX + escapeY * escapeY);
        uint64_t now = 0;
        int targetX = 0;
        int targetY = 0;
        float step = DODGE_STEP;

        if (length > 0.0001f) {
            escapeX /= length;
            escapeY /= length;
        } else if (!t_active_2) {
            return;
        }

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        targetX = ownX + (int)(escapeX * step);
        targetY = ownY + (int)(escapeY * step);

        if (t_active_2) {
            targetX = t_tx;
            targetY = t_ty;
        }

        if (TNX_STEP > 0.0f) {
            float sdx = (float)(targetX - ownX);
            float sdy = (float)(targetY - ownY);
            float slen = sqrtf(sdx * sdx + sdy * sdy);

            if (slen > TNX_STEP) {
                if (t_step_logs < 1) {
                    t_step_logs++;

                    TNX_LOGX("step cut to %.0f units: the request was %.0f units away; a distance "
                             "to a point is not a per frame step and the engine walks toward its target "
                             "at its own speed, so the old cap of twenty was six times smaller than the "
                             "request the dodge itself makes and left the engine almost nothing to walk "
                             "toward - which is the barely moving slide the user reports - while the cap "
                             "itself stays so that a far pick cannot turn into a glide; the 17:45 run "
                             "shows the character covering about thirteen units in sixteen milliseconds, "
                             "so a full walk is near %.0f units a second at sixty frames and this cap "
                             "sits just inside that",
                             (double)TNX_STEP, (double)slen, (double)(13.0f * 60.0f));
                }

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

        if (t_side_hits > 0 && t_logs < TNX_LOGS) {
            t_logs++;

            TNX_LOGX("threat write own=(%d,%d) target=(%d,%d) onRay=%d step=%.0f gap=%d of "
                     "shots dropped: %d flew away, %d could not reach - the escape is the heading "
                     "the ring scored best against the live threats, and the two counts are the "
                     "shots the reference's own filters removed before scoring",
                     ownX, ownY, targetX, targetY, t_side_hits, (double)step,
                     TNX_THREAT_MIN_MS, t_drop_along, t_drop_reach);

            TNX_LOGX("write target=(%d,%d) own=(%d,%d) held=%d dirIdx=%d - the "
                     "heading and the target are one decision, the target is only reissued when "
                     "the locked heading changes, so the input stream carries one direction "
                     "instead of a per frame corrected position", targetX, targetY, ownX, ownY,
                     t_active_2, t_prev_idx);

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
                if (t_scene_skip < TNX_QGUARD_LOGS) {
                    t_scene_skip++;

                    TNX_LOGX("modeSkip scene=%p sceneShaped=%d elem=%p elemShaped=%d tick=%llu - the "
                             "object this frame is about to receive the mode pair is not a live "
                             "object any more, so nothing is written; the page guard cannot see "
                             "this because a freed block stays readable and writable",
                             (void *)t_scene_object,
                             (int)tnx_instance_shaped((uintptr_t)t_scene_object),
                             (void *)t_own_elem,
                             (int)tnx_instance_shaped((uintptr_t)t_own_elem),
                             (unsigned long long)t_ticks_3);
                }

                return;
            }

            if (!tnx_mode_real((uintptr_t)t_scene_object, &thisVt, &thisChain, &thisInner)) {
                if (t_setpred_blocked_logs < 6) {
                    t_setpred_blocked_logs++;

                    TNX_LOGX("setprediction BLOCKED: this=%p vt=%#llx [this+%#llx]=%p "
                             "[chain+%#llx]=%p container=%p -- the chain does not reach the walked "
                             "container, nothing written", (void *)t_scene_object,
                             (unsigned long long)thisVt, (unsigned long long)TNX_MODE_MANAGER_OFF,
                             (void *)thisChain, (unsigned long long)TNX_CLIENT_HOP_OFF,
                             (void *)thisInner, (void *)t_players_object);
                }

                return;
            }

            if (t_writes_3 == 0) {
                TNX_LOGX("about to write: scene=%p vt=%#llx chain=%p manager=%p target=(%d,%d) "
                         "mode=%p actRva=%#llx leafRva=%#llx - the leaf %#llx is only a fallback, its "
                         "only caller in the image is the deserializer at 0xa26520, so a write that "
                         "lands there is stored and never consumed",
                         (void *)t_scene_object, (unsigned long long)thisVt, (void *)thisChain,
                         (void *)t_manager, targetX, targetY, (void *)t_own_elem,
                         (unsigned long long)TNX_MODEPAIR_RVA,
                         (unsigned long long)TNX_RVA_SETPREDICTION,
                         (unsigned long long)TNX_RVA_SETPREDICTION);
            }
        }

        tnx_phase("mode-write");
        tnx_watch(ownX, ownY);

        if (!t_active_2) {
            t_dir_x = escapeX;
            t_dir_y = escapeY;
        }

        t_engaged_frame = 1;

        if (t_logs_3 < 1) {
            t_logs_3++;

            TNX_LOGX("order: the engine input at scene+%#llx is the move now - type %d and the "
                     "sidestep vector written into the record the user named - so the walk cycle comes "
                     "from the stick and not from a position the renderer has to lerp towards. The raw "
                     "pair at +%#llx arrives at stage %d, and the applied pair plus the mode function "
                     "at stage %d, because those two start a new interpolation every frame and that is "
                     "the slide; own=(%d,%d) target=(%d,%d) skipped=%d",
                     (unsigned long long)TNX_MODE_INPUTMGR_OFF, TNX_INPUT_TYPE,
                     (unsigned long long)TNX_CTRL_RAW_X_OFF, TNX_STAGE_STICK,
                     TNX_STAGE_POSITION, ownX, ownY, targetX, targetY, t_input_skips);
        }

        t_writes_3++;

        t_wrote_x = targetX;
        t_wrote_y = targetY;
        t_own_pos_x = ownX;
        t_own_pos_y = ownY;
        t_wrote_tick = t_ticks_3;
        t_wrote_valid = 1;
        t_check_done = 0;

        if (t_writes_3 <= TNX_LOG_FIRST || (t_writes_3 % TNX_LOG_EVERY) == 0) {
            TNX_LOGX("write #%llu own=(%d,%d) team=%d hostilesAlive=%d enemiesInRange=%d "
                     "step=(%d,%d) target=(%d,%d) predBefore=(%d,%d)",
                     (unsigned long long)t_writes_3, ownX, ownY, ownTeam,
                     threatsAlive, threats, (int)(escapeX * DODGE_STEP),
                     (int)(escapeY * DODGE_STEP), targetX, targetY, predictX, predictY);
        }
    }
}

void tnx_dodge_plan(uintptr_t manager, int32_t team) {
    void *array = NULL;
    int32_t count = 0;
    int live = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
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
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (!tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead)) continue;

        live++;

        TNX_LOGX("dodge team=%d i=%d obj=%p gid=%d team=%d dead=%d s88=%#llx s90=%#llx",
                 team, i, element, gid, t, dead,
                 (unsigned long long)s88, (unsigned long long)s90);
    }

    TNX_LOGX("dodge team=%d live=%d DISABLED - no coordinate source: slot 0x88 takes an "
             "argument at 0xae48f0, so it is not getX; the RVAs above identify the class",
             team, live);
}

void tnx_dodge_all_teams(uintptr_t manager) {
    int32_t teams[TNX_OBJ_TEAM_MAX + 1];
    int teamCount = 0;
    void *array = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int i = 0; i <= TNX_OBJ_TEAM_MAX; i++) teams[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t t = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
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

    if ((t_ticks_3 % 60) != 0) return;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        const tnx_proj_t *p = &t_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        const char *verdict = "threat";

        if (!p->elem) continue;

        if (!tnx_proj_vel(p, &vx, &vy)) {
            verdict = p->hasPrev ? "vel-unreadable" : "one-sample";
        } else if (TNX_TEAM_FILTER && t_own_team_seen && p->team == t_own_team_3) {
            verdict = "own-team";
        } else if (sqrtf(vx * vx + vy * vy) < TNX_MIN_PROJ_SPEED) {
            verdict = "still";
        }

        TNX_LOGX("threat gid=%d elem=%p at=(%d,%d) prev=(%d,%d) dt=%llu vel=(%.1f,%.1f) team=%d verdict=%s ownTeam=%d armed=%d",
                 p->gid, (void *)p->elem, p->x, p->y, p->px, p->py,
                 (unsigned long long)(p->qtick - p->ptick), (double)vx, (double)vy, p->team, verdict,
                 t_own_team_3, t_own_team_seen);
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
            t_body_blocks++;

            if (t_pl_mine[i]) t_body_mine++;
            else t_body_enemy++;

            if (t_body_logs < TNX_BODY_LOGS) {
                t_body_logs++;

                TNX_LOGX("body in the way body=(%d,%d) mine=%d own=(%d,%d) candidate=(%d,%d) off=%d blocks=%d", (int)px, (int)py, t_pl_mine[i], (int)ownX,
                         (int)ownY, (int)x, (int)y,
                         (int)tnx_seg_dist(ownX, ownY, x, y, px, py), t_body_blocks);
            }

            return 1;
        }
    }

    return 0;
}

float tnx_own_radius(void) {
    if (!TNX_GEOM) return 0.0f;
    if (t_own_r > 1.0f) return t_own_r;

    if (t_own_r_cfg_logs < 4) {
        t_own_r_cfg_logs++;

        TNX_LOGX("own radius cfg=%.0f - the contact average has not produced a value yet, so the hit "
                 "test uses the radius taken from the character table instead of zero: the table gives "
                 "120 for 101 of 127 heroes and 145 for 20, and a zero here makes every shot pass at a "
                 "distance no smaller than the shot itself",
                 (double)TNX_DATA_OWN_R);
    }

    return TNX_DATA_OWN_R;
}

void tnx_contact_note(float dist, float projR) {
    float r = dist - projR;

    if (!TNX_GEOM) return;
    if (!tnx_ok(r, 10.0f, TNX_RADIUS_MAX)) return;

    if (t_own_r_n == 0) t_own_r = r;
    else t_own_r = t_own_r * 0.75f + r * 0.25f;

    t_own_r_n++;

    if (t_own_r_logs < TNX_CONTACT_LOGS) {
        t_own_r_logs++;

        TNX_LOGX("contact dist=%.0f projR=%.0f ownR=%.0f n=%d - own took a body while the nearest "
                 "live shot was this far from its centre, so subtracting the projectile radius "
                 "read out of that shot leaves own collision radius: the value kept is an average "
                 "over every contact seen and it is what the hit test inflates with from now on",
                 (double)dist, (double)projR, (double)t_own_r, t_own_r_n);
    }
}
