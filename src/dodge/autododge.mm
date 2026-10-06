#include "titanox.h"

static float g_dodge_px = 0.0f;
static float g_dodge_py = 0.0f;
static int g_dodge_have = 0;
static uint64_t g_freest_bullet = 0;
static int g_freest_logs = 0;
static float g_freest_hx = 0.0f;
static float g_freest_hy = 0.0f;
static int g_freest_have = 0;
static uint64_t g_freest_hold = 0;

static int tnx_dodge_is_proj(uintptr_t obj) {
    void *vt = NULL;
    intptr_t cls = 0;

    if (!obj) return 0;
    if (!tnx_read_ptr(obj, &vt) || !vt) return 0;

    cls = (intptr_t)((uintptr_t)vt - g_base);

#if TNX_DODGE_PROJ_ONLY
    return (cls == (intptr_t)TNX_CLASS_PROJ_RVA) ? 1 : 0;
#else
    (void)cls;

    return 1;
#endif
}

uint64_t g_drop_slow = 0;

uint64_t g_drop_fast = 0;

uint64_t g_drop_blink = 0;

uint64_t g_logs_9 = 0;

float g_spd_min = 0.0f;

float g_spd_max = 0.0f;

uint64_t g_gate_writes_2 = 0;

uint64_t g_gate_held = 0;

uint64_t g_update_hits = 0;

uint64_t g_move_hits = 0;

uint64_t g_ticks = 0;

__thread int g_in_drive = 0;

uint64_t g_reentry = 0;

uint64_t g_render_skip = 0;

uint64_t g_update_skip = 0;

int32_t g_pl_mine[TNX_PLAYER_MAX];

int g_attrib_hits = 0;

int g_attrib_miss = 0;

int g_attrib_logs = 0;

int g_block_hits = 0;

int g_label_builds = 0;

int g_trust_logs = 0;

int g_roster_logs = 0;

int g_enemy_blocks = 0;

int g_oneshot_segs = 0;

uint64_t g_flees = 0;

uint64_t g_dead_replaced = 0;

int g_new_tick = -1;

int g_prev_seg = -1;

int g_logs_8 = 0;

uint64_t g_mate_turns = 0;

uint64_t g_mate_stuck = 0;

int32_t g_pl_gid[TNX_PLAYER_MAX];

int32_t g_pl_sx[TNX_PLAYER_MAX];

int32_t g_pl_sy[TNX_PLAYER_MAX];

int g_pl_spawned[TNX_PLAYER_MAX];

int g_mates = 0;

int g_enemies = 0;

int g_agree = -1;

int g_cluster_logs = 0;

uint64_t g_freest_used = 0;

int g_dump_logs = 0;

uint64_t g_touchid_writes = 0;

uint64_t g_human = 0;

uint64_t g_stick_skips = 0;

uint64_t g_stuck_2 = 0;

int g_stuck_logs = 0;

int g_flag_logs = 0;

uint64_t g_dead_picks = 0;

const char *tnx_state_name(void) {
    if (g_state == TNX_STATE_DEAD) return "DEAD";
    if (g_state == TNX_STATE_RESPAWN) return "respawn";
    if (g_state == TNX_STATE_ALIVE) return "alive";

    return "init";
}

                                                                                                                                                                                                                                                            

int g_prev_idx = -1;

uint64_t g_hold_until = 0;

uint64_t g_last_danger = 0;

int32_t g_tx = 0;

int32_t g_ty = 0;

int g_active_2 = 0;

int g_build_tick = -1;

uint64_t g_escapes = 0;

uint64_t g_logs_7 = 0;

uint64_t g_lookahead = 0;

uint64_t g_rage_frames = 0;

int g_logs_4 = 0;

int g_probe_logs_2 = 0;

int g_own_logs_7 = 0;

int g_have_angle = 0;

float g_angle = 0.0f;

float g_tx_2 = 0.0f;

float g_ty_2 = 0.0f;

int g_moving = 0;

float g_start_x = 0.0f;

float g_start_y = 0.0f;

int g_picks = 0;

int g_scene_skip = 0;

int g_drive_ticks = 0;

int g_drive_logs = 0;

uint64_t g_queue_calls = 0;

uint64_t g_queue_skips = 0;

int32_t g_sent_dx = 0;

int32_t g_sent_dy = 0;

int32_t g_last_tx_2 = 0;

int32_t g_last_ty_2 = 0;

uint64_t g_last_decision = 0;

int64_t g_decide_x = 0;

int64_t g_decide_y = 0;

int g_drift_logs = 0;

uint64_t g_drift_done = 0;

uint64_t g_max_frame = 0;

uint64_t g_traveled = 0;

float g_pair_dot_sum = 0.0f;

uint64_t g_pair_dot_n = 0;

float g_last_x_3 = 0.0f;

float g_last_y_3 = 0.0f;

int g_last_ok = 0;

uint64_t g_keeps = 0;

float g_mom_live = 0.0f;

int g_crit_reaction = 0;

uint64_t g_crit_last = 0;

int g_own_r_cfg_logs = 0;

int g_proj_r_cfg_logs = 0;

float g_tti_min = 0.0f;

uint64_t g_crit_took = 0;

float g_shot_speed[TNX_PROJ_MAX];

uint64_t g_shot_logs = 0;

uint64_t g_commit_until = 0;

uint64_t g_stat_picks = 0;

uint64_t g_stat_side = 0;

uint64_t g_stat_commit = 0;

uint64_t g_react_n = 0;

uint64_t g_react_sum = 0;

uint64_t g_react_min = 0;

uint64_t g_react_max = 0;

uint64_t g_last_stat = 0;

int g_track_gid[TNX_SEG_MAX];

int g_track_hit[TNX_SEG_MAX];

float g_last_dist = 0.0f;

int g_released = 0;

float g_own_vx = 0.0f;

float g_own_vy = 0.0f;

float g_prev_own_x = 0.0f;

float g_prev_own_y = 0.0f;

uint64_t g_prev_own_tick = 0;

float g_track_min[TNX_SEG_MAX];

int g_track_pside[TNX_SEG_MAX];

float g_track_ux[TNX_SEG_MAX];

float g_track_uy[TNX_SEG_MAX];

float g_track_rad[TNX_SEG_MAX];

uint64_t g_howto_logs = 0;

int g_side_last = -1;

int g_shot_key[TNX_SEG_MAX];

int g_stat_skip = 0;

uint64_t g_stat_reset = 0;

uint64_t g_own_obj_last = 0;

uint64_t g_no_threat_since = 0;

int g_pick_key_c = 0;

int g_pick_key_t = 0;

int g_tti_logs = 0;

uint64_t g_engage = 0;

uint64_t g_hseed = 0;

uint64_t g_evals = 0;

int g_sel[TNX_SEL_MAX];

int g_sel_n = 0;

uint64_t g_pos_skips = 0;

int g_cand_now[TNX_CAND];

int g_cand_seen = 0;

int32_t g_prev_x = 0;

int32_t g_prev_y = 0;

int g_respawns = 0;

int g_signal_logs_2 = 0;

int g_learn_logs = 0;

int g_rad_bad = 0;

int g_cal_miss = 0;

int g_cal_off_seen = -1;

float g_cal_rad_seen = 0.0f;

int g_cal_n = 0;

int g_snap_calls = 0;

int g_snap_live = 0;

int g_snap_logs = 0;

int g_snap_off_logs = 0;

int g_side_tick = 0;

int g_side_flips = 0;

int g_side_picks = 0;

uint64_t g_wall_stops = 0;

int tnx_ok(float v, float lo, float hi) {
    if (!(v >= lo && v <= hi)) return 0;

    return 1;
}

int g_rad_off = -1;

int g_rad_n = 0;

int g_rad_logs = 0;

float g_rad_est = 0.0f;

uint64_t g_rad_test = 0;

float g_own_r = 0.0f;

int g_own_r_n = 0;

int g_own_r_logs = 0;

int g_clip_win = 0;

int g_clip_test_win = 0;

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      

float tnx_proj_radius(const tnx_proj_t *p, float speed) {
    uintptr_t base = 0;
    int off = 0;

    if (!TNX_GEOM) return 0.0f;
    if (!p) return 0.0f;
    if (speed < 1.0f) return 0.0f;

    base = p->elem;

    if (g_rad_off >= 0) {
        float r = 0.0f;

        if (base && tnx_read_f32(base + (uintptr_t)g_rad_off, &r) &&
            tnx_ok(r, TNX_RADIUS_MIN, TNX_RADIUS_MAX)) {
            g_rad_est = r;

            return r;
        }

        return tnx_ok(g_rad_est, TNX_RADIUS_MIN, TNX_RADIUS_MAX) ? g_rad_est : 0.0f;
    }

    if (!base) return 0.0f;

    for (off = TNX_CAL_OFF_LO; off <= TNX_CAL_OFF_HI; off += TNX_CAL_STEP) {
        float v = 0.0f;
        float r = 0.0f;
        float d = 0.0f;

        g_rad_test++;

        if (!tnx_read_f32(base + (uintptr_t)off, &v)) continue;
        if (!tnx_ok(v, 1.0f, 1.0e6f)) continue;

        d = v - speed;
        if (d < 0.0f) d = -d;
        if (d > speed * TNX_CAL_TOL) continue;

        if (!tnx_read_f32(base + (uintptr_t)off + 4, &r)) continue;
        if (!tnx_ok(r, TNX_RADIUS_MIN, TNX_RADIUS_MAX)) continue;

        if (g_cal_off_seen == off && tnx_ok(g_cal_rad_seen - r, -1.0f, 1.0f)) {
            g_cal_n++;
        } else {
            g_cal_off_seen = off;
            g_cal_rad_seen = r;
            g_cal_n = 1;
        }

        if (g_cal_n < TNX_CAL_TICKS) return 0.0f;

        g_rad_off = off + 4;
        g_rad_n++;
        g_rad_est = r;

        if (g_rad_logs < TNX_GEOM_LOGS) {
            g_rad_logs++;

            TNX_LOGX("geom speedOff=%#x radOff=%#x r=%.0f speed=%.0f tol=%.0f%% held=%d tests=%llu - the "
                     "field holding a value within tolerance of the speed measured from the "
                     "position delta is the speed field, so the radius is the float right after "
                     "it; tests is how many offsets were read before the match, and once locked "
                     "every shot is read through that offset instead of the config constant",
                     off, off + 4, (double)r, (double)speed, (double)(TNX_CAL_TOL * 100.0f),
                     g_cal_n, (unsigned long long)g_rad_test);
        }

        return r;
    }

    g_cal_miss++;

    if (g_cal_miss == TNX_CAL_MISS && g_rad_logs < TNX_GEOM_LOGS) {
        g_rad_logs++;

        TNX_LOGX("geom no speed=%.0f tests=%llu range=%#x..%#x step=%d - no offset in that range "
                 "held a value within tolerance of the measured speed for %d frames running, so no "
                 "radius was taken and the hit test stays on the configured value; the counter only "
                 "prints once because forty misses already say the search does not apply to this "
                 "build, and a repeated line would be noise",
                 (double)speed, (unsigned long long)g_rad_test, TNX_CAL_OFF_LO, TNX_CAL_OFF_HI,
                 TNX_CAL_STEP, (int)TNX_CAL_TICKS);
    }

    if (g_proj_r_cfg_logs < 4) {
        g_proj_r_cfg_logs++;

        TNX_LOGX("proj radius cfg=%.0f - the offset search did not find the radius in the shot object, "
                 "so the advertised fallback is used instead of zero: the projectile table gives 150 as "
                 "the median radius over 505 projectiles, 100 for 73 of them and 50 for 65",
                 (double)TNX_DATA_PROJ_R);
    }

    return TNX_DATA_PROJ_R;
}

void tnx_build(void) {
    int k;

    g_seg_count = 0;
    g_build_tick = (int)g_ticks_3;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        const tnx_proj_t *p = &g_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        float len = 0.0f;
        float speed = 0.0f;
        float rem = 0.0f;
        tnx_seg_t *s = NULL;

        if (!p->elem) continue;
        if (!p->hasPrev && !TNX_ONESHOT) continue;
        if (g_seg_count >= TNX_SEG_MAX) break;

        if (TNX_TEAM_FILTER && g_team_trust && g_own_team_seen &&
            p->team == g_own_team_3) continue;

        if (TNX_TEAM_STRICT && g_own_team_4 >= 0 && p->team == g_own_team_4) continue;
        if (tnx_proj_mine(p)) continue;

        if (!p->hasPrev) {

            uint64_t age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 1;

            vx = (float)(p->x - p->spawnX) / (float)age;
            vy = (float)(p->y - p->spawnY) / (float)age;

            if (fabsf(vx) < 0.5f && fabsf(vy) < 0.5f) continue;

            g_oneshot_segs++;
        } else if (!tnx_proj_vel(p, &vx, &vy)) continue;

        len = sqrtf(vx * vx + vy * vy);

        if (len < TNX_MIN_PROJ_SPEED) continue;

        speed = len * 60.0f;

        if (speed < 1.0f) speed = 1.0f;

        if (speed > g_shot_speed[k]) g_shot_speed[k] = speed;
        if (g_shot_speed[k] > 1.0f) speed = g_shot_speed[k];

        if (tnx_blacklisted(speed, 0.0f)) {
            if (g_stat_skip < 4) {
                g_stat_skip++;

                TNX_LOGX("skip speed=%.0f gid=%d - this projectile is on the do not dodge list, so it "
                         "is not counted as a threat and no commit is spent on it",
                         (double)speed, p->gid);
            }

            continue;
        }

        if (g_spd_min < 1.0f || speed < g_spd_min) g_spd_min = speed;
        if (speed > g_spd_max) g_spd_max = speed;

        rem = speed * (TNX_PROJ_LIFE_MS / 1000.0f);

        if (rem > TNX_DEFAULT_RANGE) rem = TNX_DEFAULT_RANGE;
        if (rem < 1.0f) rem = 1.0f;

        {
            float nx = vx / len;
            float ny = vy / len;
            float px0 = g_dodge_have ? g_dodge_px : (float)g_own_x;
            float py0 = g_dodge_have ? g_dodge_py : (float)g_own_y;
            float rx = (float)p->x - px0;
            float ry = (float)p->y - py0;
            float rvx = vx - g_own_vx;
            float rvy = vy - g_own_vy;
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

            if (g_shot_logs < TNX_SHOT_LOGS) {
                g_shot_logs++;

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

            if (g_dodge_have) {
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
                if (rule == 1) g_drop_slow++;
                else if (rule == 2) g_drop_fast++;
                else g_drop_blink++;

                if (g_logs_9 < TNX_LOGS_5) {
                    g_logs_9++;

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

            g_clip_test_win++;

            if (rem < rem0 - 0.5f) g_clip_win++;
        }

        s = &g_seg[g_seg_count++];
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
                g_rad_bad++;
            }

            if (ir < TNX_DODGE_CLEAR_R) ir = TNX_DODGE_CLEAR_R;

            s->inflatedR = ir;
        }
    }

    if (g_seg_test > 0) g_seg_frac = (g_seg_clip * 100) / g_seg_test;
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

    for (i = 0; i < g_seg_count; i++) {
        float d2 = tnx_seg_dist2(x, y, &g_seg[i]);

        if (d2 <= g_seg[i].inflatedR * g_seg[i].inflatedR) return 1;
    }

    return 0;
}

float tnx_clearance_2(float x, float y) {
    float best = 1000000.0f;
    int i;

    for (i = 0; i < g_seg_count; i++) {
        float d = sqrtf(tnx_seg_dist2(x, y, &g_seg[i])) - g_seg[i].inflatedR;

        if (d < best) best = d;
    }

    return best;
}

float tnx_eta_ms(float x, float y) {
    float best = 1.0e9f;
    int i = 0;

    for (i = 0; i < g_seg_count; i++) {
        const tnx_seg_t *s = &g_seg[i];
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
    if (g_seg_count <= 0) return 0;

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
    if (g_seg_count <= 0) return 0;

    for (i = 0; i < g_seg_count; i++) {
        const tnx_seg_t *s = &g_seg[i];
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
        dx = -(g_seg[best].by - g_seg[best].ay);
        dy = (g_seg[best].bx - g_seg[best].ax);
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) return 0;
    }

    *tx = px + dx / len * TNX_FLEE_STEP;
    *ty = py + dy / len * TNX_FLEE_STEP;
    g_flees++;

    return 1;
}

int tnx_body_blocked_2(float px, float py, float dirX, float dirY, float len) {
    float ex = 0.0f;
    float ey = 0.0f;
    int i = 0;

    if (!TNX_MATE_AVOID) return 0;
    if (g_pl_n <= 0) return 0;
    if (len < 1.0f) return 0;

    ex = px + dirX * len;
    ey = py + dirY * len;

    for (i = 0; i < g_pl_n; i++) {
        if (tnx_seg_dist(px, py, ex, ey, (float)g_pl_x[i], (float)g_pl_y[i]) <
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

    if (g_pl_n <= 0) return best;

    for (i = 0; i < g_pl_n; i++) {
        float d = tnx_seg_dist(px, py, ex, ey, (float)g_pl_x[i], (float)g_pl_y[i]);

        if (d < best) best = d;
    }

    return best;
}

                                                                                                                                              

float tnx_clearance_3(float px, float py, float dirX, float dirY) {
    float speed = tnx_speed();
    float best = 1.0e9f;
    int i = 0;
    int k = 0;

    for (i = 0; i < g_sel_n; i++) {
        const tnx_seg_t *seg = &g_seg[g_sel[i]];

        for (k = 0; k <= TNX_STEPS; k++) {
            float t = TNX_HORIZON * ((float)k / (float)TNX_STEPS);
            float qx = px + dirX * speed * t;
            float qy = py + dirY * speed * t;
            float d = tnx_seg_dist(qx, qy, seg->ax, seg->ay, seg->bx, seg->by) - seg->inflatedR;

            if (d < best) best = d;
        }
    }

    g_evals++;

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
    if (g_dodge_probe_usable <= 0) return tnx_body_score(px, py, dirX, dirY, len);

    for (i = 0; i < g_dodge_probe_usable; i++) {
        const tnx_obj_t *o = &g_dodge_probe_list[i];
        float d = 0.0f;

        if (o->gid < TNX_PLAYER_GID) continue;
        if (o->gid >= TNX_SHOT_GID) continue;
        if (g_own_elem_2 && o->object == g_own_elem_2) continue;

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

    if (g_last_ok) {
        bestScore += TNX_DATA_MOMENTUM * (base * g_last_x_3 + baseY * g_last_y_3);
        baseScore = bestScore;
    }

    for (i = 0; i < 12; i++) {
        float a = rot[i] * rad;
        float c = cosf(a);
        float sn = sinf(a);
        float rx = base * c - baseY * sn;
        float ry = base * sn + baseY * c;
        float score = tnx_score(px, py, rx, ry, len);

        if (g_last_ok) score += TNX_DATA_MOMENTUM * (rx * g_last_x_3 + ry * g_last_y_3);

        if (score > bestScore) {
            bestScore = score;
            bestX = rx;
            bestY = ry;
        }
    }

    if (g_last_ok && bestX != base &&
        (bestScore - (tnx_score(px, py, base, baseY, len) +
                      TNX_DATA_MOMENTUM * (base * g_last_x_3 + baseY * g_last_y_3))) <
            TNX_DATA_BAND) {
        bestX = base;
        bestY = baseY;
        g_keeps++;
    }

    *dirX = bestX;
    *dirY = bestY;

    if (bestX != 0.0f || bestY != 0.0f) {
        float n = sqrtf(bestX * bestX + bestY * bestY);

        if (n > 0.0001f) {
            g_last_x_3 = bestX / n;
            g_last_y_3 = bestY / n;
            g_last_ok = 1;
        }
    }

    if (bestScore > baseScore) {
        g_mate_turns++;
    } else {
        g_mate_stuck++;
    }
}

int tnx_valid_point(float x, float y) {
    int32_t cx = (int32_t)x;
    int32_t cy = (int32_t)y;

    tnx_clamp(&cx, &cy);

    if (cx != (int32_t)x || cy != (int32_t)y) return 0;

    if (tnx_mate_blocked(x, y)) {
        g_block_hits++;

        return 0;
    }

    if (tnx_body_blocked(x, y, (float)g_own_x, (float)g_own_y)) {
        return 0;
    }

    if (tnx_enemy_blocked(x, y, (float)g_own_x, (float)g_own_y)) {
        g_enemy_blocks++;

        return 0;
    }

    return 1;
}

int tnx_walk_into_bullet(float px, float py, float dirX, float dirY, float travel) {
    float pvx = dirX * TNX_DATA_SPEED;
    float pvy = dirY * TNX_DATA_SPEED;
    float horizon = travel / TNX_DATA_SPEED;
    int i;

    for (i = 0; i < g_seg_count; i++) {
        const tnx_seg_t *s = &g_seg[i];
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
    float ax = g_tx_2 - g_start_x;
    float ay = g_ty_2 - g_start_y;
    float len2 = ax * ax + ay * ay;
    float bx = 0.0f;
    float by = 0.0f;

    if (len2 <= 0.0f) return 1;

    bx = px - g_start_x;
    by = py - g_start_y;

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

        if (g_have_angle) {
            int base = (int)roundf(g_angle / tau * (float)TNX_NUM_ANGLES);
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
                g_freest_bullet++;

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

    for (i = 0; i < g_seg_count; i++) {
        const tnx_seg_t *sg = &g_seg[i];
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

void tnx_crit_probe(float px, float py) {
    float best = 1.0e9f;
    int i = 0;

    g_crit_reaction = 0;
    g_tti_min = best;

    for (i = 0; i < g_seg_count; i++) {
        const tnx_seg_t *s = &g_seg[i];
        float d = 0.0f;
        float ms = 0.0f;

        if (s->speed <= 1.0f) continue;

        d = tnx_seg_dist(px, py, s->ax, s->ay, s->bx, s->by) - s->inflatedR;

        if (d < 0.0f) d = 0.0f;

        ms = d / s->speed * 1000.0f;

        if (ms < best) best = ms;
    }

    g_tti_min = best;

    if (TNX_REACT_CRIT && best < TNX_CRITICAL_MS && (g_ticks_3 - g_crit_last) >= TNX_DATA_CRIT_EVERY) {
        g_crit_reaction = 1;
        g_crit_last = g_ticks_3;
    }

    g_mom_live = g_crit_reaction ? 0.0f : TNX_DATA_MOMENTUM;

    if (g_crit_reaction && g_tti_logs < TNX_SEG_TTI_LOGS) {
        g_tti_logs++;

        TNX_LOGX("crit tti=%.0fms segs=%d own=(%.0f,%.0f) - an impact inside %dms drops the "
                 "momentum term and takes the best heading even when it does not beat standing "
                 "still, because on these frames the point is leaving the line now rather than "
                 "holding a heading that is already the wrong one",
                 (double)best, g_seg_count, (double)px, (double)py, (int)TNX_CRITICAL_MS);
    }
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
    if (g_walk_step > 0.01f) speed = g_walk_step * 60.0f;
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
            g_freest_bullet++;

            continue;
        }

        score = tnx_js_clear(px, py, ux * speed, uy * speed);

        if (g_freest_have) score += g_mom_live * (ux * g_freest_hx + uy * g_freest_hy);
        if (tnx_clip_range(px, py, ux, uy, radius) < radius - 1.0f) score -= TNX_WALL_PENALTY;

        for (k = 0; k < g_pl_n; k++) {
            float d = 0.0f;

            if (g_pl_mine[k]) continue;

            d = tnx_seg_dist(px, py, ex, ey, (float)g_pl_x[k], (float)g_pl_y[k]);

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
        g_freest_hx = (bestX - px) / radius;
        g_freest_hy = (bestY - py) / radius;
        g_freest_have = 1;

        if (bestScore <= nowClear) {
            if (!g_crit_reaction) {
                g_freest_hold++;

                return 0;
            }

            g_crit_took++;
        }
    }

    if (!TNX_ESCAPE && bestRoom < TNX_FREEST_MIN) return 0;

    *tx = bestX;
    *ty = bestY;
    g_freest_used++;

    if (g_freest_logs < TNX_FREEST_LOGS) {
        g_freest_logs++;

        TNX_LOGX("freest own=(%.0f,%.0f) pick=(%.0f,%.0f) eta=%.0f nowEta=%.0f room=%.0f segs=%d "
                 "score=%.0f nowClear=%.0f bullets=%llu hold=%llu - the pick is the direction with the "
                 "largest clearance along the path it would walk in one second, and the body stays put "
                 "when no direction beats standing still; bullets counts the headings refused because "
                 "walking them would put the body in front of a shot",
                 (double)px, (double)py, (double)bestX, (double)bestY, (double)bestEta,
                 (double)nowClear, (double)bestRoom, g_seg_count,
                 (double)bestScore, (double)nowClear,
                 (unsigned long long)g_freest_bullet, (unsigned long long)g_freest_hold);
    }

    return 1;
}

float tnx_clear_at(float px, float py, int i) {
    return tnx_seg_dist(px, py, g_seg[i].ax, g_seg[i].ay, g_seg[i].bx, g_seg[i].by) - g_seg[i].inflatedR;
}

float tnx_all_clear(float x, float y) {
    int k = 0;
    float best = 1.0e9f;

    for (k = 0; k < g_seg_count; k++) {
        float c = tnx_clear_at(x, y, k);

        if (c < best) best = c;
    }

    return best;
}

int tnx_wall_blocked(float x0, float y0, float x1, float y1) {
    int32_t ox = (int32_t)x1;
    int32_t oy = (int32_t)y1;

    if (!g_live || !g_armed) return -1;
    if (g_w <= 0 || g_h <= 0) return -1;

    return tnx_clip_walk((int32_t)x0, (int32_t)y0, (int32_t)x1, (int32_t)y1,
                         (int32_t)TNX_TILE_SIZE, g_grid, g_w, g_h, &ox, &oy);
}

static int tnx_point_clear(float px, float py, float x, float y) {
    int i = 0;
    float mx = (px + x) * 0.5f;
    float my = (py + y) * 0.5f;

    if (!tnx_valid_point(x, y)) return 0;

    for (i = 0; i < g_seg_count; i++) {
        if (tnx_clear_at(px, py, i) < 0.0f) return 0;
        if (tnx_clear_at(x, y, i) < 0.0f) return 0;
        if (tnx_clear_at(mx, my, i) < 0.0f) return 0;
    }

    return 1;
}

                                                                                                                                                                                                                                                                                                

                                                                                                                                                                                                                                                                                                                                                                                                                                       

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               

static void tnx_state_reset(void) {
    g_commit_until = 0;
    g_moving = 0;
    g_side_last = -1;
    g_last_dist = 0.0f;
    g_stat_reset++;
}

static void tnx_state_tick(float px, float py) {
    uintptr_t own = tnx_own_obj();

    if (g_prev_own_tick != 0 && g_ticks_3 > g_prev_own_tick) {
        float dt = (float)(g_ticks_3 - g_prev_own_tick);

        g_own_vx = (px - g_prev_own_x) / dt;
        g_own_vy = (py - g_prev_own_y) / dt;
    }

    g_prev_own_x = px;
    g_prev_own_y = py;
    g_prev_own_tick = g_ticks_3;

    if (own != g_own_obj_last) {
        if (g_own_obj_last != 0) tnx_state_reset();

        g_own_obj_last = own;
        g_no_threat_since = 0;
        g_released = 0;

        return;
    }

    if (g_seg_count > 0) {
        g_no_threat_since = 0;
        g_released = 0;

        return;
    }

    if (g_moving && tnx_wall_blocked(px, py, g_tx_2, g_ty_2) == 1) {
        tnx_state_reset();

        g_released = 1;
        g_wall_stops++;

        tnx_enqueue((int32_t)px, (int32_t)py);

        if (g_wall_stops <= TNX_WALL_LOGS) {
            TNX_LOGX("wallstop own=(%.0f,%.0f) target=(%.0f,%.0f) segs=%d stops=%llu - the tilemap "
                     "clips the run to the target that is still being walked, so the target is "
                     "replaced by own position in that frame instead of waiting for the no threat "
                     "timer: without this the character keeps pushing along the last heading and "
                     "stands in the wall until something else changes the target",
                     (double)px, (double)py, (double)g_tx_2, (double)g_ty_2, g_seg_count,
                     (unsigned long long)g_wall_stops);
        }

        return;
    }

    if (g_released) return;

    if (g_no_threat_since == 0) {
        g_no_threat_since = g_ticks_3;

        return;
    }

    if ((g_ticks_3 - g_no_threat_since) < (uint64_t)TNX_NO_THREAT_TICKS) return;

    tnx_state_reset();
    g_released = 1;

    tnx_enqueue((int32_t)px, (int32_t)py);

    TNX_LOGX("release own=(%.0f,%.0f) - with no threat left the engine would keep walking to the "
             "last target written, so the target is set to own position, which is what stops the "
             "character instead of leaving it to run on into whatever was in front of it",
             (double)px, (double)py);
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

    g_dodge_px = px;
    g_dodge_py = py;
    g_dodge_have = 1;

    tnx_build();

    if (g_seg_count != g_prev_seg) {
        g_new_tick = (int)g_ticks_3;
        g_prev_seg = g_seg_count;

        if (TNX_REACT_CRIT && (g_ticks_3 - g_crit_last) >= TNX_DATA_CRIT_EVERY) {
            g_crit_reaction = 1;
            g_crit_last = g_ticks_3;
        }
    }

    tnx_crit_probe(px, py);

    tnx_state_tick(px, py);

    tnx_stat_tick(px, py);

    threatened = tnx_threatened(px, py);

    if (g_seg_count > 0 && tnx_clearance_2(px, py) < TNX_ENGAGE_NEAR) {
        threatened = 1;
        g_engage++;
    }

    if (TNX_RAGE_FORCE && g_seg_count > 0) {
        if (!TNX_HIT_ONLY || tnx_imminent(px, py)) {
            threatened = 1;
            g_rage_frames++;
        }
    }

    if (tnx_imminent(px, py)) {
        threatened = 1;
        g_lookahead++;
    }

    g_have_angle = 0;

    stick = tnx_joy_angle(&g_angle);

    if (stick) {
        g_have_angle = 1;
        desiredDeg = g_angle * 180.0f / 3.14159265358979f;
    }

    if (threatened) {
        picked = tnx_best(px, py, &tx, &ty);

        if (!picked) picked = tnx_freest(px, py, &tx, &ty);
        if (!picked && TNX_FLEE) picked = tnx_flee(px, py, &tx, &ty);

        if (picked) {
            float sx = tx;
            float sy = ty;
            int commit = 0;

            if (g_commit_until > g_ticks_3 && g_moving && tnx_point_clear(px, py, g_tx_2, g_ty_2)) {
                sx = g_tx_2;
                sy = g_ty_2;
                commit = 1;
                g_stat_commit++;
            } else if (g_seg_count >= (int)TNX_MULTI_THREAT && tnx_side_pick(px, py, &sx, &sy)) {
                commit = 0;
            }

            tx = sx;
            ty = sy;

            if ((tx - px) * (tx - px) + (ty - py) * (ty - py) < 1.0f &&
                tnx_flee(px, py, &tx, &ty)) {
                g_dead_replaced++;
            }

            g_last_dist = sqrtf((tx - px) * (tx - px) + (ty - py) * (ty - py));

            if (!commit || tx != g_tx_2 || ty != g_ty_2) {
                float hold = TNX_COMMIT_MS * (1.0f + TNX_COMMIT_GROW * (float)(g_seg_count - 1));

                g_commit_until = g_ticks_3 + (uint64_t)(hold * 60.0f / 1000.0f);
            }

            g_tx_2 = tx;
            g_ty_2 = ty;
            g_moving = 1;
            g_start_x = px;
            g_start_y = py;
            g_picks++;
            g_stat_picks++;

            if (g_new_tick >= 0) {
                uint64_t react = g_ticks_3 - (uint64_t)g_new_tick;

                g_react_n++;
                g_react_sum += react;
                if (g_react_min == 0 || react < g_react_min) g_react_min = react;
                if (react > g_react_max) g_react_max = react;
            }
        }
    } else if (g_moving && tnx_passed(px, py)) {
        g_moving = 0;
    } else if (g_moving && stick) {
        float safe = tnx_safe_angle(px, py, desiredDeg, &safeOk);

        if (!safeOk && TNX_FLEE) {
            if (tnx_flee(px, py, &g_tx_2, &g_ty_2)) g_moving = 1;
        }

        if (safeOk) {
            float rad = safe * 3.14159265358979f / 180.0f;
            float ex = px + cosf(rad) * TNX_EXTEND_DEFAULT;
            float ey = py + sinf(rad) * TNX_EXTEND_DEFAULT;

            if (tnx_valid_point(ex, ey)) {
                g_tx_2 = ex;
                g_ty_2 = ey;

            }
        }
    }

    if (g_logs_4 < 24 && (g_ticks_3 % 60) == 0) {
        g_logs_4++;

        TNX_LOGX("dodge segs=%d threatened=%d picked=%d target=(%.0f,%.0f) dist=%.0f way=%.0f "
                 "stick=%d angle=%.1f joyw=%d snap=%d moving=%d - the threat segments start where "
                 "each shot is NOW and run along its own flight, so a shot that already passed is "
                 "behind the segment and not a reason to run; the directions are walked outward from "
                 "the stick angle so a safe heading near the one the player holds wins; way is the "
                 "heading actually written towards in degrees, counted from the positive x axis, so "
                 "two consecutive lines with the same way is the character holding one direction",
                 g_seg_count, threatened, picked, (double)g_tx_2, (double)g_ty_2,
                 (double)sqrtf((g_tx_2 - px) * (g_tx_2 - px) +
                               (g_ty_2 - py) * (g_ty_2 - py)),
                 (double)(atan2f(g_ty_2 - py, g_tx_2 - px) * 180.0f / 3.14159265358979f),
                 stick, (double)desiredDeg, TNX_JOY_WRITE, g_snap_live, g_moving);
    }

    if (g_moving) tnx_snap(g_tx_2 - px, g_ty_2 - py);

    tnx_predict_2(ownX, ownY, g_tx_2, g_ty_2);

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

    tnx_route(g_active_2);

    tnx_drift();

    tnx_state();

    if (TNX_DIAG_EVERY <= 0 || (g_ticks_3 % (uint64_t)TNX_DIAG_EVERY) == 0) {
        uint64_t diag0 = tnx_us();

        uint64_t slot = (g_ticks_3 / (uint64_t)TNX_DIAG_EVERY) % 4;

        if (slot == 0) tnx_core();
        else if (slot == 1) tnx_dump();
        else if (slot == 2) tnx_census();

        g_diag_us = tnx_us() - diag0;

        if (g_diag_us > g_diag_max_us) g_diag_max_us = g_diag_us;
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

    g_dodge_calls++;

    if (g_dodge_calls <= TNX_CALL_LOGS ||
        (g_dodge_calls % TNX_CALL_EVERY) == 0) {
        TNX_LOGX("dodge CALLED n=%llu base=%p scene=%p container=%p array=%p count=%d hop=%d "
                 "gidFloor=%d gidMax=%d playerMax=%d - printed before every early return and keyed "
                 "on the number of calls and not on a tick counter, because the v137 run printed no "
                 "probe line at all and the two possible reasons, a gate before the line and a "
                 "counter that never advanced, cannot be told apart from the absence of a line",
                 (unsigned long long)g_dodge_calls, (void *)g_base, (void *)g_scene_object,
                 (void *)g_players_object, (void *)g_players_array, g_players_count, g_hop_chosen,
                 TNX_GID_FLOOR, TNX_GID_MAX, TNX_PLAYER_GID_MAX);
    }

    if (!g_base) return;

    if (g_dodge_calls <= TNX_CALL_LOGS ||
        (g_dodge_calls % TNX_CALL_EVERY) == 0) {
        uintptr_t probeOwn = 0;
        int32_t probeGid = 0;
        int32_t probeTeam = 0;
        int32_t probeCount = 0;

        g_probe_tick = g_ticks_4;

        tnx_own_by_min_gid(g_tick_array, g_tick_count, &probeOwn, &probeGid);

        if (probeOwn) tnx_read_i32(probeOwn + TNX_OBJ_TEAM_OFF, &probeTeam);
        if (g_players_object) tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &probeCount);

        {
            int listIdx = -1;
            const char *listFrom = "none";
            int32_t listGid = -1;

            if (tnx_own_from_list(g_dodge_probe_list, g_dodge_probe_usable, &listIdx, &listFrom)) {
                listGid = g_dodge_probe_list[listIdx].gid;
            }

            TNX_LOGX("dodge list usable=%d from=%s idx=%d gid=%d minGidSeen=%d chosenGid=%d "
                     "chosenIdx=%d - the resolver runs on the very array the walk collected and "
                     "reports which entry it picked, so a disagreement between the smallest id seen "
                     "and the id chosen is visible in one line instead of being inferred",
                     g_dodge_probe_usable, listFrom, listIdx, listGid, probeGid, listGid, listIdx);
        }

        TNX_LOGX("dodge probe tick=%llu frames=%llu scene=%p container=%p array=%p count=%d "
                 "hop=%d own=%p ownGid=%d ownTeam=%d coordOk=%d coordUsable=%d writeTest=%d - this "
                 "line is printed before every early return of the dodge, so 'the dodge did not run' "
                 "can never again be concluded from the absence of a log line; in the v134 run the "
                 "dodge wrote nothing and said nothing, and it took a manual read of the resolver to "
                 "learn that the container globals and the walked list disagreed",
                 (unsigned long long)g_ticks_4, (unsigned long long)g_ticks_3,
                 (void *)g_scene_object, (void *)g_players_object, (void *)g_players_array,
                 probeCount, g_hop_chosen, (void *)probeOwn, probeGid, probeTeam,
                 g_coord_ok, g_coord_usable, TNX_MODE);
    }

    sourceIsMode = (g_scene_object != 0);

    if (sourceIsMode) {
        source = g_scene_object;
        sourceKind = "mode";
    } else if (g_players_object) {
        source = g_players_object;
        sourceKind = "manager";
    } else if (g_objvote_best_owner && g_objvote_best_teamcount >= TNX_OWNER_VOTE_TEAMS_MIN &&
               g_objvote_max_votes >= TNX_OWNER_VOTE_MIN) {
        source = g_objvote_best_owner;
        sourceKind = "objvote";
    } else if (g_trail_count > 0 && g_trail_best >= 0 && g_trail_best < g_trail_count) {
        source = (uintptr_t)g_trail[g_trail_best].manager;
        sourceKind = "trail";
    }

    if (!source) {
        g_no_source_passes++;

        if (g_no_source_passes >= 5 && !g_route_logged) {
            g_route_logged = 1;

            TNX_LOGX("route: five passes with no source at all - mode=%p manager=%p "
                     "objvote=%p trailBest=%p; the remaining path is the ClientInput route, and its "
                     "hooks report separately (E5 setClientPredictionMoveTo, E6 sendMovement)",
                     (void *)g_scene_object, (void *)g_players_object, (void *)g_objvote_best_owner,
                     (void *)((g_trail_best >= 0 && g_trail_best < g_trail_count)
                                  ? g_trail[g_trail_best].manager
                                  : 0));
        }
    } else {
        g_no_source_passes = 0;
    }

    if (!sourceIsMode && !g_players_object && source && strcmp(sourceKind, "trail") == 0 &&
        g_trail_best >= 0 && g_trail_best < g_trail_count && g_trail[g_trail_best].live == 0) {
        if ((g_ticks_3 % 900) == 1) {
            TNX_LOGX("dodge idle ticks=%llu: best trail candidate has live=0, waiting "
                     "(trailBest=%p nonEmpty=%d count=%d stable=%d)",
                     (unsigned long long)g_ticks_3, (void *)source,
                     g_trail[g_trail_best].nonEmpty, g_trail[g_trail_best].count,
                     g_trail[g_trail_best].stable);
        }
    }

    tnx_frame();

    g_ticks_3++;

    if (g_wrote_valid && !g_check_done &&
        (g_ticks_3 - g_wrote_tick) >= TNX_VERIFY_FRAMES) {
        int32_t nowX = 0;
        int32_t nowY = 0;

        if (g_scene_object && tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &nowX) &&
            tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &nowY)) {
            TNX_LOGX("write verify: wrote=(%d,%d) now=(%d,%d) %s frames=%d testWrites=%llu - "
                     "kept means the engine left the two words alone, overwritten means the input "
                     "path rewrites them before anything is sent",
                     g_wrote_x, g_wrote_y, nowX, nowY,
                     (nowX == g_wrote_x && nowY == g_wrote_y) ? "kept" : "overwritten",
                     (int)(g_ticks_3 - g_wrote_tick),
                     (unsigned long long)g_test_writes);

            {
                void *array = NULL;
                int32_t count = 0;
                int shown = 0;

                if (g_players_object &&
                    tnx_read_ptr(g_players_object + TNX_MGR_ARRAY_OFF, &array) && array &&
                    tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &count)) {
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

        g_check_done = 1;
    }

    if (g_enter_tick != g_ticks_4 && (g_ticks_4 < 5 || (g_ticks_4 % 5) == 0)) {
        g_enter_tick = g_ticks_4;
        g_entry_logs++;

        {
            int32_t oix = 0;
            int32_t oiy = 0;

            tnx_interp(&oix, &oiy);

            TNX_LOGX("dodge ENTERED tick=%llu frames=%llu mode=%p manager=%p hop=%d source=%p "
                     "kind=%s setpredFn=%d coordOk=%d usable=%d writes=%llu ownInterpX=%d ownInterpY=%d "
                     "modeVar=%d gate1=%d gate2=%d - ownInterpX/Y is the live own position read from "
                     "client+%#llx/+%#llx, so a dodge line with coordOk=0 can still carry a moving own "
                     "position",
                     (unsigned long long)g_ticks_4, (unsigned long long)g_ticks_3,
                     (void *)g_scene_object, (void *)g_players_object, g_hop_chosen, (void *)source,
                     sourceKind, g_setpred_state, g_coord_ok, g_coord_usable,
                     (unsigned long long)g_writes_3, oix, oiy, tnx_mode(),
                     (tnx_mode() == TNX_MODE_TARGET) ? 1 : 0, (tnx_inner() == 1) ? 1 : 0,
                     (unsigned long long)TNX_CLIENT_POS_X_OFF,
                     (unsigned long long)TNX_CLIENT_POS_Y_OFF);
        }

        tnx_interp_line();
        tnx_gate_report(tnx_slot_probe());
    }

    if (!source) {
        if ((g_ticks_3 % 900) == 1) {
            TNX_LOGX("dodge idle ticks=%llu: no mode, no manager and no trail candidate yet "
                     "(bestLive=%d bestCount=%d) setpred=%d",
                     (unsigned long long)g_ticks_3, g_manager_best_live,
                     g_manager_best_count, g_setpred_state);
        }
        return;
    }

    if (g_setpred_state < 0) {
        g_setpred_state = tnx_verify_setprediction();
        g_setpred_2 = g_setpred_state ? (g_base + TNX_RVA_SETPREDICTION) : 0;
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        void *resolved = NULL;
        int changed = (g_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;

        if (sourceIsMode && g_hop_chosen == 1 && g_tick_object) {
            resolved = (void *)g_tick_object;
        } else if (sourceIsMode) {
            if (!tnx_read_ptr(source + TNX_MODE_MANAGER_OFF, &resolved) || !resolved) {
                resolved = NULL;
            }
        } else {
            resolved = (void *)source;
        }

        managerChanged = ((uintptr_t)resolved != g_manager);

        if (managerChanged && g_walk_relogs < 6) {
            g_walk_relogs++;

            TNX_LOGX("walk manager=%p hop=%d source=%p kind=%s - the container is re-read from "
                     "the chain globals on this tick, so the walk follows scene+0x28 -> +%#llx "
                     "instead of stopping on the client", resolved, g_hop_chosen,
                     (void *)source, sourceKind, (unsigned long long)TNX_CLIENT_HOP_OFF);
        }

        {
            int32_t liveCount = 0;

            if (resolved) tnx_read_i32((uintptr_t)resolved + TNX_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && g_hop_chosen == 1 &&
                (liveCount != g_walk_count ||
                 (g_walk_tick != g_ticks_4 && (g_ticks_4 % TNX_WALK_EVERY) == 0))) {
                g_walk_count = liveCount;
                g_walk_tick = g_ticks_4;
                periodic = 1;

                TNX_LOGX("walk tick=%llu manager=%p count=%d - the walk is driven by the tick "
                         "and by the count, not by the array, so it reports every %d ticks while "
                         "the hop is %d even when the container itself has not changed",
                         (unsigned long long)g_ticks_4, resolved, liveCount, TNX_WALK_EVERY,
                         g_hop_chosen);
            }
        }

        if (!g_probe_done_2 || changed || managerChanged || periodic ||
            (!g_coord_ok && probeNow > g_probe_last_ms + TNX_REPROBE_MS)) {
            g_probe_object = source;
            g_probe_last_ms = probeNow;
            g_manager = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || managerChanged || !g_probe_done_2);
                    tnx_probe_3((uintptr_t)resolved, g_scene_object, loud);

                if (loud) tnx_discriminate((uintptr_t)resolved);
            } else {
                TNX_LOGX("probe skipped: source %p (%s) has no manager at +0x%llx and hop=%d",
                         (void *)source, sourceIsMode ? "mode" : "manager",
                         (unsigned long long)TNX_MODE_MANAGER_OFF, g_hop_chosen);
            }
        }
    }

    g_ticks_2++;

    if (!g_setpred_state) {
        if (g_giveup_logs < 3) {
            g_giveup_logs++;
            TNX_LOGX("dodge idle: no verified actuator (fingerprint state=%d -- this is the "
                     "byte check of the function, not a write)", g_setpred_state);
        }
        return;
    }

    {
        int gateOpen = (g_coord_ok || g_coord_usable >= TNX_MIN_USABLE) ? 1 : 0;

        if (gateOpen != g_gate_last) {
            g_gate_last = gateOpen;
            g_gate_logs++;

            if (g_gate_logs <= 16) {
                TNX_LOGX("gate %s: coord_ok=%d usable=%d distinct=%d minUsable=%d - the dodge runs "
                         "on usable objects now, because a container that holds only the player still "
                         "carries the player's own coordinates and the whole threat list, while the old "
                         "gate was coord_ok alone: the 17:12 run shows it going false for five seconds "
                         "in the middle of a firefight (usable=1 at 37.219, 39.020 and 40.401) with no "
                         "dodge line in exactly those seconds, and shots do not count because they are "
                         "rejected as non-players",
                         gateOpen ? "open" : "shut", g_coord_ok, g_coord_usable,
                         g_coord_distinct, TNX_MIN_USABLE);
            }
        }
    }

    if (!g_coord_ok && g_coord_usable < TNX_MIN_USABLE) return;

    if (!g_scene_object) {
        if (g_giveup_logs < 9) {
            g_giveup_logs++;
            TNX_LOGX("dodge idle: coordinates confirmed but the mode is unknown, so the "
                     "actuator has no `this` -- nothing written");

            if (!g_idle_probe_logged) {
                g_idle_probe_logged = 1;

                TNX_LOGX("dodge idle probe modeCandidate=%p vt=%#llx whyRejected=%s hits=%d "
                         "fromChain=%d", (void *)g_last_cand,
                         (unsigned long long)g_last_vt,
                         g_last_why[0] ? g_last_why : "none-seen", g_chain_hits,
                         g_mode_from_chain);
            }
        }
        return;
    }

    memset(objects, 0, sizeof(objects));

    tnx_phase("collect");

    usable = tnx_collect(g_manager, objects, TNX_OBJECT_MAX, &rejected);

    if (usable < TNX_MIN_USABLE_2) {
        if ((g_ticks_3 % 60) == 0) {
            TNX_LOGX("dodge idle: %d usable object(s) and this build needs %d - the old floor was "
                     "two, so a container holding only the player switched the dodge off completely "
                     "while shots were in the air, which is the 19:18 run where the census reads "
                     "players=1 shots=6 with no dodge line at all", usable, TNX_MIN_USABLE_2);
        }

        return;
    }

    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    tnx_own_scan();

    {
        const char *ownFrom = "none";

        if (!tnx_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_resolve_own_2(objects, usable, &ownIndex, &ownFrom)) {
            if (g_giveup_logs < 6 || (g_ticks_3 % 60) == 0) {
                g_giveup_logs++;

                TNX_LOGX("dodge idle: no own element - the scan found nothing at scanIndex=%d "
                         "scanPtr=%p and the prediction fallback (%d,%d) found nothing either, "
                         "usable=%d", g_own_index_3, (void *)g_own_ptr_4, predictX, predictY,
                         usable);
            }

            return;
        }

        tnx_publish_own(objects[ownIndex].object, ownFrom);

        if (g_own_logs_6 < 8) {
            uintptr_t ownVt = 0;
            uintptr_t ownCls = 0;

            g_own_logs_6++;

            tnx_vt_ok((uintptr_t)g_own_elem, &ownVt);

            if (ownVt >= g_base) ownCls = ownVt - g_base;

            TNX_LOGX("dodge own elem=%p vt=%p classRva=%#llx from=%s index=%d pos=(%d,%d) - "
                     "classRva is what the census classRva of the same element index has to match, "
                     "and the actuator uses this exact element or nothing",
                     (void *)g_own_elem, (void *)ownVt, (unsigned long long)ownCls, ownFrom,
                     ownIndex, objects[ownIndex].x, objects[ownIndex].y);
        }

        if (!g_own_logged) {
            g_own_logged = 1;

            TNX_LOGX("dodge own resolved from %s at +%#llx index=%d object=%p pos=(%d,%d) - "
                     "the scan is tried first and the prediction pair is only the fallback, so "
                     "the dodge and the gate line name the same element", ownFrom,
                     (unsigned long long)g_own_off, ownIndex, objects[ownIndex].object,
                     objects[ownIndex].x, objects[ownIndex].y);
        }
    }

    g_own_elem_2 = objects[ownIndex].object;

    ownTeam = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
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

            team = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
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

        g_enemy_elem = bestEnemy;
    }

    for (int i = 0; i < usable; i++) {
        int32_t team = 0;
        float dx = 0.0f;
        float dy = 0.0f;
        float distance = 0.0f;
        float weight = 0.0f;

        if (i == ownIndex) continue;

        team = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
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
        objects[ownIndex].object != g_last_own) {
        if (g_last_own && g_elem_logs < 4) {
            g_elem_logs++;

            TNX_LOGX("own element changed %p -> %p at (%d,%d): the ladder, the heading, the write "
                     "clock and the issued flag are cleared, because a respawn or a different element "
                     "carries none of the state the last life built",
                     (void *)g_last_own, (void *)objects[ownIndex].object, ownX, ownY);
        }

        g_last_own = objects[ownIndex].object;
        g_stage = 0;
        g_stuck = 0;
        g_prev_idx = -1;
        g_hold_until = 0;
        g_last_danger = 0;
        g_last_write_ms = 0;
        g_issued = 0;
    }

    tnx_alive(ownX, ownY);

    tnx_phase("sidestep");

    g_side_hits = 0;
    g_side_projs = 0;

    {
        int32_t projCount = 0;
        int i = 0;

        if (g_manager) tnx_read_i32(g_manager + TNX_MGR_COUNT_OFF, &projCount);

        g_own_team_3 = (int)ownTeam;

        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= TNX_TEAM_MAX_2) g_own_team_seen = 1;

        tnx_roster(g_own_elem_2, ownIndex, (int)ownTeam, objects, usable);

        if (ownIndex < 0 || ownIndex >= usable || ownIndex >= TNX_OBJECT_MAX) {
            TNX_LOGX("sidestep aborted: ownIndex=%d usable=%d max=%d", ownIndex, usable,
                     TNX_OBJECT_MAX);

            return;
        }

        TNX_LOGX("sidestep own=%p index=%d usable=%d projCount=%d",
                 (void *)objects[ownIndex].object, ownIndex, usable, projCount);

        if (tnx_life(objects[ownIndex].object, ownX, ownY)) return;

        tnx_proj_scan(g_manager, projCount);

        g_active_2 = 0;
        g_side_hits = 0;

        for (i = 0; i < TNX_PROJ_MAX; i++) {
            if (g_projs[i].elem) g_side_projs++;
        }

        tnx_threats();

        if (tnx_decide(ownX, ownY)) {
            g_active_2 = 1;
            g_side_hits = 1;
            g_tx = (int32_t)g_tx_2;
            g_ty = (int32_t)g_ty_2;
            g_dir_x = g_tx_2 - (float)ownX;
            g_dir_y = g_ty_2 - (float)ownY;
        }

        tnx_drive();

        if (g_active_2 && g_logs < TNX_LOGS) {
            g_logs++;

            TNX_LOGX("dodge own=(%d,%d) target=(%d,%d) projectiles=%d liveThreats=%d dirIdx=%d "
                     "reach=%.0f engage=%.0f - %d directions are scored by the closest approach of the threat "
                     "against a point moving at the character speed along that direction, the score "
                     "carries a momentum term toward the previous direction, and the chosen heading "
                     "is locked for %d ms inside a band of %.0f, which is what stops the character "
                     "sliding between two nearly equal directions, and crit is set when the impact "
                     "of the nearest live segment is inside %d ms or the threat set changed on this "
                     "frame: tti=%.0fms crit=%d criticalPicks=%llu",
                     ownX, ownY, g_tx, g_ty, g_side_projs, g_live_threats,
                     g_prev_idx, (double)TNX_REACH, (double)TNX_ENGAGE, TNX_DIRS,
                     TNX_LOCK_MS, (double)TNX_DATA_BAND, (int)TNX_CRITICAL_MS,
                     (double)g_tti_min, g_crit_reaction, (unsigned long long)g_crit_took);
        }
    }

    if (!g_side_hits && (g_proj_own + g_proj_other) > 0 && (g_ticks_3 % 240) == 0) {
        TNX_LOGX("no shot survived the filters: tracked=%d ownTeam=%d flewAway=%d cannotReach=%d - "
                 "the ring had nothing left to dodge, so a dodge that stops while shots are in the "
                 "air is read from this line first", g_proj_own + g_proj_other,
                 g_proj_own, g_drop_along, g_drop_reach);
    }

    if (threats == 0 && g_side_hits == 0) {
        if (g_ticks_2 % 256 == 0) {
            TNX_LOGX("live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
                     "enemiesActive=%d enemiesInRange=0 projSeen=%d projOnRay=0 writes=%llu "
                     "threatsTotal=%llu",
                     (unsigned long long)g_ticks_2, ownX, ownY, ownTeam, predictX, predictY,
                     threatsAlive, threats, g_side_projs, (unsigned long long)g_writes_3,
                     (unsigned long long)g_threat_ticks);
        }
        return;
    }

    g_threat_ticks++;

    {
        float length = sqrtf(escapeX * escapeX + escapeY * escapeY);
        uint64_t now = 0;
        int targetX = 0;
        int targetY = 0;
        float step = DODGE_STEP;

        if (length > 0.0001f) {
            escapeX /= length;
            escapeY /= length;
        } else if (!g_active_2) {
            return;
        }

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        targetX = ownX + (int)(escapeX * step);
        targetY = ownY + (int)(escapeY * step);

        if (g_active_2) {
            targetX = g_tx;
            targetY = g_ty;
        }

        if (TNX_STEP > 0.0f) {
            float sdx = (float)(targetX - ownX);
            float sdy = (float)(targetY - ownY);
            float slen = sqrtf(sdx * sdx + sdy * sdy);

            if (slen > TNX_STEP) {
                if (g_step_logs < 1) {
                    g_step_logs++;

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

        if (g_stage >= TNX_STAGE_POSITION && g_side_hits > 0 && g_issued &&
            targetX == g_last_tx && targetY == g_last_ty) {
            return;
        }

        if (now < g_last_write_ms + (uint64_t)(g_side_hits > 0
                ? TNX_THREAT_MIN_MS : TNX_DODGE_MIN_MS)) {
            return;
        }

        g_last_write_ms = now;

        if (g_side_hits > 0) {
            g_last_tx = targetX;
            g_last_ty = targetY;
            g_issued = 1;
        }

        if (g_side_hits > 0 && g_logs < TNX_LOGS) {
            g_logs++;

            TNX_LOGX("threat write own=(%d,%d) target=(%d,%d) onRay=%d step=%.0f gap=%d of "
                     "shots dropped: %d flew away, %d could not reach - the escape is the heading "
                     "the ring scored best against the live threats, and the two counts are the "
                     "shots the reference's own filters removed before scoring",
                     ownX, ownY, targetX, targetY, g_side_hits, (double)step,
                     TNX_THREAT_MIN_MS, g_drop_along, g_drop_reach);

            TNX_LOGX("write target=(%d,%d) own=(%d,%d) held=%d dirIdx=%d - the "
                     "heading and the target are one decision, the target is only reissued when "
                     "the locked heading changes, so the input stream carries one direction "
                     "instead of a per frame corrected position", targetX, targetY, ownX, ownY,
                     g_active_2, g_prev_idx);

        }

        if (targetX > TNX_COORD_ABS_MAX) targetX = TNX_COORD_ABS_MAX;
        if (targetX < -TNX_COORD_ABS_MAX) targetX = -TNX_COORD_ABS_MAX;
        if (targetY > TNX_COORD_ABS_MAX) targetY = TNX_COORD_ABS_MAX;
        if (targetY < -TNX_COORD_ABS_MAX) targetY = -TNX_COORD_ABS_MAX;

        {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;
            uintptr_t thisInner = 0;

            if (TNX_QUEUE_GUARD && (!tnx_instance_shaped((uintptr_t)g_scene_object) ||
                                    !tnx_instance_shaped((uintptr_t)g_own_elem))) {
                if (g_scene_skip < TNX_QGUARD_LOGS) {
                    g_scene_skip++;

                    TNX_LOGX("modeSkip scene=%p sceneShaped=%d elem=%p elemShaped=%d tick=%llu - the "
                             "object this frame is about to receive the mode pair is not a live "
                             "object any more, so nothing is written; the page guard cannot see "
                             "this because a freed block stays readable and writable",
                             (void *)g_scene_object,
                             (int)tnx_instance_shaped((uintptr_t)g_scene_object),
                             (void *)g_own_elem,
                             (int)tnx_instance_shaped((uintptr_t)g_own_elem),
                             (unsigned long long)g_ticks_3);
                }

                return;
            }

            if (!tnx_mode_real((uintptr_t)g_scene_object, &thisVt, &thisChain, &thisInner)) {
                if (g_setpred_blocked_logs < 6) {
                    g_setpred_blocked_logs++;

                    TNX_LOGX("setprediction BLOCKED: this=%p vt=%#llx [this+%#llx]=%p "
                             "[chain+%#llx]=%p container=%p -- the chain does not reach the walked "
                             "container, nothing written", (void *)g_scene_object,
                             (unsigned long long)thisVt, (unsigned long long)TNX_MODE_MANAGER_OFF,
                             (void *)thisChain, (unsigned long long)TNX_CLIENT_HOP_OFF,
                             (void *)thisInner, (void *)g_players_object);
                }

                return;
            }

            if (g_writes_3 == 0) {
                TNX_LOGX("about to write: scene=%p vt=%#llx chain=%p manager=%p target=(%d,%d) "
                         "mode=%p actRva=%#llx leafRva=%#llx - the leaf %#llx is only a fallback, its "
                         "only caller in the image is the deserializer at 0xa26520, so a write that "
                         "lands there is stored and never consumed",
                         (void *)g_scene_object, (unsigned long long)thisVt, (void *)thisChain,
                         (void *)g_manager, targetX, targetY, (void *)g_own_elem,
                         (unsigned long long)TNX_MODEPAIR_RVA,
                         (unsigned long long)TNX_RVA_SETPREDICTION,
                         (unsigned long long)TNX_RVA_SETPREDICTION);
            }
        }

        tnx_phase("mode-write");
        tnx_watch(ownX, ownY);

        if (!g_active_2) {
            g_dir_x = escapeX;
            g_dir_y = escapeY;
        }

        g_engaged_frame = 1;

        if (g_logs_3 < 1) {
            g_logs_3++;

            TNX_LOGX("order: the engine input at scene+%#llx is the move now - type %d and the "
                     "sidestep vector written into the record the user named - so the walk cycle comes "
                     "from the stick and not from a position the renderer has to lerp towards. The raw "
                     "pair at +%#llx arrives at stage %d, and the applied pair plus the mode function "
                     "at stage %d, because those two start a new interpolation every frame and that is "
                     "the slide; own=(%d,%d) target=(%d,%d) skipped=%d",
                     (unsigned long long)TNX_MODE_INPUTMGR_OFF, TNX_INPUT_TYPE,
                     (unsigned long long)TNX_CTRL_RAW_X_OFF, TNX_STAGE_STICK,
                     TNX_STAGE_POSITION, ownX, ownY, targetX, targetY, g_input_skips);
        }

        g_writes_3++;

        g_wrote_x = targetX;
        g_wrote_y = targetY;
        g_own_pos_x = ownX;
        g_own_pos_y = ownY;
        g_wrote_tick = g_ticks_3;
        g_wrote_valid = 1;
        g_check_done = 0;

        if (g_writes_3 <= TNX_LOG_FIRST || (g_writes_3 % TNX_LOG_EVERY) == 0) {
            TNX_LOGX("write #%llu own=(%d,%d) team=%d hostilesAlive=%d enemiesInRange=%d "
                     "step=(%d,%d) target=(%d,%d) predBefore=(%d,%d)",
                     (unsigned long long)g_writes_3, ownX, ownY, ownTeam,
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
