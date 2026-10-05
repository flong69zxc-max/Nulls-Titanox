#include "titanox.h"

uint64_t g_v227_drop_slow = 0;

uint64_t g_v227_drop_fast = 0;

uint64_t g_v227_drop_blink = 0;

uint64_t g_v227_logs = 0;

float g_v227_spd_min = 0.0f;

float g_v227_spd_max = 0.0f;

uint64_t g_v226_gate_writes = 0;

uint64_t g_v226_gate_held = 0;

uint64_t g_v237_update_hits = 0;

uint64_t g_v237_move_hits = 0;

uint64_t g_v237_ticks = 0;

__thread int g_v238_in_drive = 0;

uint64_t g_v238_reentry = 0;

uint64_t g_v238_render_skip = 0;

uint64_t g_v238_update_skip = 0;

int g_v189_state = TNX_V189_STATE_INIT;

int g_v189_pl_n = 0;

int32_t g_v189_pl_x[TNX_V189_PLAYER_MAX];

int32_t g_v189_pl_y[TNX_V189_PLAYER_MAX];

int32_t g_v189_pl_team[TNX_V189_PLAYER_MAX];

int32_t g_v189_pl_mine[TNX_V189_PLAYER_MAX];

int g_v189_mate_n = 0;

int32_t g_v189_mate_x[TNX_V189_MATE_MAX];

int32_t g_v189_mate_y[TNX_V189_MATE_MAX];

int g_v189_own_x = 0;

int g_v189_own_y = 0;

int g_v189_own_team = -1;

int g_v189_attrib_hits = 0;

int g_v189_attrib_miss = 0;

int g_v189_attrib_logs = 0;

int g_v189_block_hits = 0;

int g_v189_label_builds = 0;

int g_v191_team_trust = 1;

int32_t g_v191_own_team = -1;

int32_t g_v191_enemy_x[TNX_V189_PLAYER_MAX];

int32_t g_v191_enemy_y[TNX_V189_PLAYER_MAX];

int g_v191_enemy_n = 0;

int g_v191_trust_logs = 0;

int g_v191_roster_logs = 0;

int g_v191_enemy_blocks = 0;

int g_v191_oneshot_segs = 0;

uint64_t g_v216_flees = 0;

uint64_t g_v216_dead_replaced = 0;

int g_v216_new_tick = -1;

int g_v216_prev_seg = -1;

int g_v216_logs = 0;

uint64_t g_v214_mate_turns = 0;

uint64_t g_v214_mate_stuck = 0;

int32_t g_v196_pl_gid[TNX_V189_PLAYER_MAX];

int32_t g_v196_pl_sx[TNX_V189_PLAYER_MAX];

int32_t g_v196_pl_sy[TNX_V189_PLAYER_MAX];

int g_v196_pl_spawned[TNX_V189_PLAYER_MAX];

int g_v196_mates = 0;

int g_v196_enemies = 0;

int g_v196_agree = -1;

int g_v196_cluster_logs = 0;

uint64_t g_v196_freest_used = 0;

int g_v196_dump_logs = 0;

uint64_t g_v196_touchid_writes = 0;

uint64_t g_v197_human = 0;

uint64_t g_v197_stick_skips = 0;

uint64_t g_v197_stuck = 0;

int g_v197_stuck_logs = 0;

uint64_t g_v193_gate_writes = 0;

int g_v193_flag_logs = 0;

uint64_t g_v193_dead_picks = 0;

const char *tnx_v189_state_name(void) {
    if (g_v189_state == TNX_V189_STATE_DEAD) return "DEAD";
    if (g_v189_state == TNX_V189_STATE_RESPAWN) return "respawn";
    if (g_v189_state == TNX_V189_STATE_ALIVE) return "alive";

    return "init";
}

int tnx_v189_team_at(const tnx_v47_obj_t *objects, int index) {
    if (!objects || index < 0) return -1;

    return (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[index].teamOld
                                                     : objects[index].teamNew;
}

void tnx_v189_roster(uintptr_t ownElem, int ownIndex, int ownTeam,
                            const tnx_v47_obj_t *objects, int usable) {
    int i = 0;
    int matesBefore = g_v189_mate_n;
    int ownSide = 0;
    int hist[TNX_V189_PLAYER_MAX];
    int hn = 0;

    g_v189_pl_n = 0;
    g_v189_mate_n = 0;
    g_v191_enemy_n = 0;
    g_v189_own_team = ownTeam;
    g_v191_own_team = ownTeam;
    g_v191_team_trust = 1;

    for (i = 0; i < usable && g_v189_pl_n < TNX_V189_PLAYER_MAX; i++) {
        int32_t team = 0;
        int isOwn = 0;
        int h = 0;

        if (objects[i].gid < TNX_V179_PLAYER_GID) continue;
        if (objects[i].gid >= TNX_V179_SHOT_GID) continue;

        team = tnx_v189_team_at(objects, i);
        isOwn = (ownElem && objects[i].object == ownElem) ? 1
                                                          : ((!ownElem && i == ownIndex) ? 1 : 0);

        g_v189_pl_x[g_v189_pl_n] = objects[i].x;
        g_v189_pl_y[g_v189_pl_n] = objects[i].y;
        g_v189_pl_team[g_v189_pl_n] = team;
        g_v189_pl_mine[g_v189_pl_n] = isOwn;
        g_v196_pl_gid[g_v189_pl_n] = objects[i].gid;
        g_v196_pl_sx[g_v189_pl_n] = objects[i].x;
        g_v196_pl_sy[g_v189_pl_n] = objects[i].y;
        g_v196_pl_spawned[g_v189_pl_n] = 0;
        g_v189_pl_n++;

        if (isOwn) {
            g_v189_own_x = objects[i].x;
            g_v189_own_y = objects[i].y;

            continue;
        }

        for (h = 0; h < hn; h++) {
            if (hist[h] == team) break;
        }

        if (h == hn && hn < TNX_V189_PLAYER_MAX) {
            hist[hn++] = team;
        }

        if (team != ownTeam) continue;

        ownSide++;

        if (g_v189_mate_n >= TNX_V189_MATE_MAX) continue;

        g_v189_mate_x[g_v189_mate_n] = objects[i].x;
        g_v189_mate_y[g_v189_mate_n] = objects[i].y;
        g_v189_mate_n++;
    }

    ownSide++;

    if (g_v189_pl_n >= 4 && (ownSide > (g_v189_pl_n / 2) || hn < 2)) {
        g_v191_team_trust = 0;
        g_v189_mate_n = 0;
    }

    {
        int ownSpawn = -1;
        int k = 0;

        for (k = 0; k < g_v189_pl_n; k++) {
            if (g_v189_pl_mine[k]) { ownSpawn = k; break; }
        }

        g_v196_mates = 0;
        g_v196_enemies = 0;

        if (ownSpawn >= 0) {
            for (k = 0; k < g_v189_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (g_v189_pl_mine[k]) continue;

                dx = (float)(g_v189_pl_x[k] - g_v189_pl_x[ownSpawn]);
                dy = (float)(g_v189_pl_y[k] - g_v189_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_V196_CLUSTER) g_v196_mates++;
                else g_v196_enemies++;
            }
        }

        if (!g_v191_team_trust) {
            int m = 0;
            int e = 0;

            g_v189_mate_n = 0;
            g_v191_enemy_n = 0;

            for (k = 0; k < g_v189_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (g_v189_pl_mine[k]) continue;

                dx = (float)(g_v189_pl_x[k] - g_v189_pl_x[ownSpawn]);
                dy = (float)(g_v189_pl_y[k] - g_v189_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_V196_CLUSTER) {
                    if (m < TNX_V189_MATE_MAX) {
                        g_v189_mate_x[m] = g_v189_pl_x[k];
                        g_v189_mate_y[m] = g_v189_pl_y[k];
                        m++;
                    }
                } else if (e < TNX_V189_PLAYER_MAX) {
                    g_v191_enemy_x[e] = g_v189_pl_x[k];
                    g_v191_enemy_y[e] = g_v189_pl_y[k];
                    e++;
                }
            }

            g_v189_mate_n = m;
            g_v191_enemy_n = e;

            if (g_v196_cluster_logs < TNX_V191_TRUST_LOGS) {
                g_v196_cluster_logs++;

                tnx_logf("v196 side by cluster players=%d ownSpawn=(%d,%d) mates=%d enemies=%d "
                         "byteMates=%d byteEnemies=%d radius=%.0f - the team byte is not believed, so "
                         "the side comes from where the players came from: a team spawns together and "
                         "the two spawn areas are far apart, which is a signal that does not depend on "
                         "a field the engine may not even set in this mode",
                         g_v189_pl_n, g_v189_pl_x[ownSpawn], g_v189_pl_y[ownSpawn], m, e,
                         ownSide - 1, g_v189_pl_n - ownSide, (double)TNX_V196_CLUSTER);
            }
        } else if (g_v196_cluster_logs < TNX_V191_TRUST_LOGS) {
            g_v196_cluster_logs++;

            tnx_logf("v196 side agreement byte=%d/%d cluster=%d/%d agree=%d players=%d - both answers "
                     "are printed every time the roster changes, so a byte that drifts and a cluster "
                     "that misreads are told apart instead of guessed at", g_v189_mate_n,
                     g_v191_enemy_n, g_v196_mates, g_v196_enemies, g_v196_agree, g_v189_pl_n);
        }
    }

    if (g_v191_team_trust) {
        for (i = 0; i < g_v189_pl_n && g_v191_enemy_n < TNX_V189_PLAYER_MAX; i++) {
            if (g_v189_pl_mine[i]) continue;
            if (g_v189_pl_team[i] == ownTeam) continue;

            g_v191_enemy_x[g_v191_enemy_n] = g_v189_pl_x[i];
            g_v191_enemy_y[g_v191_enemy_n] = g_v189_pl_y[i];
            g_v191_enemy_n++;
        }
    }

    g_v196_agree = (g_v196_mates == g_v189_mate_n && g_v196_enemies == g_v191_enemy_n) ? 1 : 0;

    if (g_v189_mate_n != matesBefore || g_v191_roster_logs < TNX_V191_ROSTER_LOGS) {
        g_v191_roster_logs++;

        tnx_logf("v191 roster players=%d mates=%d enemies=%d teams=%d/%d/%d/%d/%d/%d own=(%d,%d) "
                 "ownMatched=%d ownTeam=%d trust=%d blocked=%d - the raw table is printed because "
                 "the previous line printed only the counts and a 3v3 came back as five teammates "
                 "with own at the origin: players=6 mates=5 ownTeam=0 own=(0,0). own is matched by "
                 "element now, and the side is only believed when it is a minority of the container, "
                 "because a team is a minority in a team match; when it is not, trust goes to zero "
                 "and both the mate block and the own shot filter stand down, so a broken team byte "
                 "can no longer leave the ring with only the enemy to run into",
                 g_v189_pl_n, g_v189_mate_n, g_v191_enemy_n,
                 g_v189_pl_team[0], g_v189_pl_team[1], g_v189_pl_team[2], g_v189_pl_team[3],
                 g_v189_pl_team[4], g_v189_pl_team[5], g_v189_own_x, g_v189_own_y,
                 g_v189_pl_mine[0] | g_v189_pl_mine[1] | g_v189_pl_mine[2] | g_v189_pl_mine[3] |
                     g_v189_pl_mine[4] | g_v189_pl_mine[5],
                 g_v191_own_team, g_v191_team_trust, g_v189_block_hits);
    }

    if (g_v191_trust_logs < TNX_V191_TRUST_LOGS && !g_v191_team_trust) {
        g_v191_trust_logs++;

        tnx_logf("v191 side read distrusted players=%d ownSide=%d distinctTeams=%d - more than half "
                 "of the players came back on own's side, or every player came back on one team, "
                 "which no real match produces; the mate block is off and the own shot filter is off "
                 "until the next roster, so the dodge reacts to every moving shot and refuses no "
                 "ground, instead of refusing all of it", g_v189_pl_n, ownSide, hn);
    }
}

int tnx_v191_own_ok(int32_t x, int32_t y) {
    if (x == 0 && y == 0) return 0;
    if (x < -100000 || x > 100000) return 0;
    if (y < -100000 || y > 100000) return 0;

    return 1;
}

int tnx_v191_enemy_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (!g_v191_team_trust || g_v191_enemy_n <= 0) return 0;

    for (i = 0; i < g_v191_enemy_n; i++) {
        float ex = (float)g_v191_enemy_x[i];
        float ey = (float)g_v191_enemy_y[i];
        float dc = sqrtf((x - ex) * (x - ex) + (y - ey) * (y - ey));
        float dOwn = sqrtf((ownX - ex) * (ownX - ex) + (ownY - ey) * (ownY - ey));

        if (dc < TNX_V191_ENEMY_HARD) return 1;
        if (dOwn > TNX_V191_ENEMY_FAR && dc < dOwn - TNX_V191_ENEMY_MARGIN) return 1;
    }

    return 0;
}

int tnx_v189_mate_blocked(float x, float y) {
    int i = 0;
    float r2 = TNX_V189_MATE_CLEAR * TNX_V189_MATE_CLEAR;

    if (!g_v191_team_trust) return 0;
    if (g_v189_mate_n <= 0) return 0;

    for (i = 0; i < g_v189_mate_n; i++) {
        float dx = x - (float)g_v189_mate_x[i];
        float dy = y - (float)g_v189_mate_y[i];

        if (dx * dx + dy * dy <= r2) return 1;
    }

    return 0;
}

int tnx_v189_own_side_spawn(int32_t sx, int32_t sy) {
    int i = 0;
    int best = -1;
    float bestD = 0.0f;
    float secondD = -1.0f;

    if (g_v189_own_team < 0) return -1;
    if (g_v189_pl_n <= 0) return -1;

    for (i = 0; i < g_v189_pl_n; i++) {
        float dx = (float)sx - (float)g_v189_pl_x[i];
        float dy = (float)sy - (float)g_v189_pl_y[i];
        float d2 = dx * dx + dy * dy;

        if (best < 0 || d2 < bestD) {
            secondD = (best < 0) ? -1.0f : bestD;
            bestD = d2;
            best = i;
        } else if (secondD < 0.0f || d2 < secondD) {
            secondD = d2;
        }
    }

    if (best < 0) return -1;
    if (bestD > TNX_V189_ATTRIB_R2) return -1;
    if (secondD >= 0.0f && bestD * TNX_V189_ATTRIB_MARGIN > secondD) return -1;

    return (g_v189_pl_team[best] == g_v189_own_team) ? 1 : 0;
}

int g_v160_prev_idx = -1;

uint64_t g_v160_hold_until = 0;

uint64_t g_v160_last_danger = 0;

int32_t g_v160_tx = 0;

int32_t g_v160_ty = 0;

int g_v160_active = 0;

} tnx_v172_seg_t;

tnx_v172_seg_t g_v172_seg[TNX_V172_SEG_MAX];

int g_v172_seg_count = 0;

int g_v172_build_tick = -1;

uint64_t g_v206_escapes = 0;

uint64_t g_v207_logs = 0;

uint64_t g_v209_lookahead = 0;

uint64_t g_v212_rage_frames = 0;

int g_v172_logs = 0;

int g_v172_probe_logs = 0;

int g_v172_own_logs = 0;

int g_v172_have_angle = 0;

float g_v172_angle = 0.0f;

float g_v172_tx = 0.0f;

float g_v172_ty = 0.0f;

int g_v172_moving = 0;

float g_v172_start_x = 0.0f;

float g_v172_start_y = 0.0f;

int g_v172_picks = 0;

uintptr_t tnx_v172_bs(void) {
    return (uintptr_t)g_scene_object;
}

int tnx_v172_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by,
                             uint32_t *mode, float *cs, float *sn) {
    int32_t m = 0;

    if (!bs) return 0;

    if (!tnx_read_f32(bs + TNX_V172_BS_AX, ax)) return 0;
    if (!tnx_read_f32(bs + TNX_V172_BS_AY, ay)) return 0;
    if (!tnx_read_f32(bs + TNX_V172_BS_BX, bx)) return 0;
    if (!tnx_read_f32(bs + TNX_V172_BS_BY, by)) return 0;

    *mode = 0;

    if (tnx_read_i32(bs + TNX_V172_BS_MODE, &m)) *mode = (uint32_t)m;

    if (!tnx_read_f32(bs + TNX_V172_BS_COS, cs)) *cs = 1.0f;
    if (!tnx_read_f32(bs + TNX_V172_BS_SIN, sn)) *sn = 0.0f;

    return 1;
}

int tnx_v172_joy_angle(float *outAngle) {
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float cs = 1.0f;
    float sn = 0.0f;
    float rx = 0.0f;
    float ry = 0.0f;
    float len = 0.0f;
    uint32_t mode = 0;

    if (!tnx_v172_joy_read(tnx_v172_bs(), &ax, &ay, &bx, &by, &mode, &cs, &sn)) return 0;
    if (mode != 2 && mode != 3) return 0;

    rx = (ax - bx) * cs + (ay - by) * sn;
    ry = (ay - by) * cs - (ax - bx) * sn;

    len = sqrtf(rx * rx + ry * ry);

    if (len < 0.001f) return 0;

    *outAngle = atan2f(-ry, rx);

    return 1;
}

int g_v189_drive_ticks = 0;

int g_v189_drive_logs = 0;

uint64_t g_v189_queue_calls = 0;

uint64_t g_v189_queue_skips = 0;

int32_t g_v189_sent_dx = 0;

int32_t g_v189_sent_dy = 0;

int32_t g_v189_last_tx = 0;

int32_t g_v189_last_ty = 0;

uint64_t g_v189_last_decision = 0;

int64_t g_v189_decide_x = 0;

int64_t g_v189_decide_y = 0;

int g_v189_drift_logs = 0;

uint64_t g_v189_drift_done = 0;

uint64_t g_v191_max_frame = 0;

uint64_t g_v191_traveled = 0;

float g_v191_pair_dot_sum = 0.0f;

uint64_t g_v191_pair_dot_n = 0;

float g_v233_last_x = 0.0f;

float g_v233_last_y = 0.0f;

int g_v233_last_ok = 0;

uint64_t g_v233_keeps = 0;

uint64_t g_v233_engage = 0;

uint64_t g_v234_hseed = 0;

uint64_t g_v235_evals = 0;

int g_v240_sel[TNX_V240_SEL_MAX];

int g_v240_sel_n = 0;

void tnx_v240_select(float px, float py) {
    float speed = g_v231_walk_step * 60.0f;
    float reach = 0.0f;
    int i = 0;

    if (speed < 120.0f) speed = 120.0f;
    if (speed > 1200.0f) speed = 1200.0f;

    reach = speed * TNX_V235_HORIZON;
    g_v240_sel_n = 0;

    for (i = 0; i < g_v172_seg_count && g_v240_sel_n < TNX_V240_SEL_MAX; i++) {
        const tnx_v172_seg_t *seg = &g_v172_seg[i];
        float d = tnx_v192_seg_dist(px, py, seg->ax, seg->ay, seg->bx, seg->by);

        if (d > reach + seg->inflatedR) continue;

        g_v240_sel[g_v240_sel_n++] = i;
    }
}

uint64_t g_v236_pos_skips = 0;

int tnx_v189_drive(void) {
    uintptr_t ctrl = tnx_v150_controller();

    tnx_v231_measure();
    tnx_v243_snapshot();
    int32_t ownX = 0;
    int32_t ownY = 0;
    float dx = 0.0f;
    float dy = 0.0f;
    float len = 0.0f;
    int held = 0;
    int32_t tx = 0;
    int32_t ty = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    int32_t pairX = 0;
    int32_t pairY = 0;

    if (g_v160_active) {
        g_v180_tx = g_v160_tx;
        g_v180_ty = g_v160_ty;
        g_v180_hold = g_v48_ticks;
        held = 1;
    } else if (g_v180_hold && (g_v48_ticks - g_v180_hold) <= TNX_V189_HOLD_TICKS) {
        held = 1;
    }

    if (!held) {
        float escapeX = 0.0f;
        float escapeY = 0.0f;

        if (!TNX_V206_ESCAPE) {
            tnx_v174_stick(0, 0.0f, 0.0f);

            return 0;
        }

        if (!tnx_v178_own(&ownX, &ownY)) return 0;
        if (!tnx_v191_own_ok(ownX, ownY)) return 0;

        if (!tnx_v172_threatened((float)ownX, (float)ownY)) {
            tnx_v174_stick(0, 0.0f, 0.0f);

            return 0;
        }

        if (!tnx_v196_freest((float)ownX, (float)ownY, &escapeX, &escapeY)) {
            tnx_v174_stick(0, 0.0f, 0.0f);

            return 0;
        }

        dx = escapeX - (float)ownX;
        dy = escapeY - (float)ownY;
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) {
            g_v193_dead_picks++;
            tnx_v174_stick(0, 0.0f, 0.0f);

            return 0;
        }

        g_v206_escapes++;
        tnx_v174_stick(1, (float)TNX_V199_STICK_SIGN * dx, (float)TNX_V199_STICK_SIGN * dy);
        tnx_v207_precision(ownX, ownY, dx, dy, 1);

        return 1;
    }

    if (!tnx_v178_own(&ownX, &ownY)) return 0;
    if (!tnx_v191_own_ok(ownX, ownY)) return 0;

    dx = (float)(g_v180_tx - ownX);
    dy = (float)(g_v180_ty - ownY);
    len = sqrtf(dx * dx + dy * dy);

    if (len >= 0.0001f) {
        dx /= len;
        dy /= len;
        tnx_v218_unblock((float)ownX, (float)ownY,
                        tnx_v231_step(), &dx, &dy);
        dx *= len;
        dy *= len;
    }

    {
        float step = TNX_V220_STEP;

        step = tnx_v231_step();

        if (len > step) {
            dx = dx / len * step;
            dy = dy / len * step;
            len = step;
            g_v220_clamped++;
        }
    }

    if (len < 0.0001f) {
        g_v193_dead_picks++;
        tnx_v174_stick(0, 0.0f, 0.0f);

        return 0;
    }

    {
        uintptr_t hctrl = tnx_v150_controller();
        uint8_t hgate = 0;
        int32_t hid = -1;
        int human = 0;
        int threat = 0;

        if (hctrl) {
            tnx_read_bytes(hctrl + TNX_V193_TOUCH_GATE_OFF, &hgate, sizeof(hgate));
            tnx_read_i32(hctrl + TNX_V193_TOUCH_ID_OFF, &hid);
        }

        human = (hgate == 1 || hid >= 0) ? 1 : 0;

        if (TNX_V244_HUMAN && g_v244_human) human = 1;

        threat = g_v160_active ? 1 : 0;

        if (human) g_v197_human++;

        if (threat || !human || !TNX_V197_STICK_WHEN_FREE) {
            tnx_v174_stick(1, (float)TNX_V199_STICK_SIGN * dx, (float)TNX_V199_STICK_SIGN * dy);
        } else {
            g_v197_stick_skips++;
        }
    }

    tnx_v205_walk(dx, dy);
    tnx_v207_precision(ownX, ownY, dx, dy, 0);

    tx = ownX + (int32_t)((double)dx / (double)len * (double)tnx_v231_step());
    ty = ownY + (int32_t)((double)dy / (double)len * (double)tnx_v231_step());

    if (TNX_V244_QUIET) {
        g_v244_queue_skips++;
        g_v189_queue_calls++;
    } else if (!TNX_V189_PAIR_ONLY) {
        if (TNX_V236_STICK_ONLY) g_v236_pos_skips++;
        else tnx_v113_enqueue(tx, ty);
        g_v189_queue_calls++;
    } else {
        g_v189_queue_skips++;
    }

    if (!TNX_V236_STICK_ONLY) {
        tnx_v192_predict(tx, ty);
    }

    if (TNX_V193_TOUCH_FLAG && ctrl) {
        uint8_t gateNow = 0;
        int32_t stateNow = 0;
        int32_t idNow = 0;

        tnx_read_bytes(ctrl + TNX_V193_TOUCH_GATE_OFF, &gateNow, sizeof(gateNow));
        tnx_read_i32(ctrl + TNX_V193_TOUCH_STATE_OFF, &stateNow);
        tnx_read_i32(ctrl + TNX_V193_TOUCH_ID_OFF, &idNow);

        if (g_v193_flag_logs < TNX_V193_FLAG_LOGS) {
            g_v193_flag_logs++;

            tnx_logf("v196 touch gate=%d state=%d id=%d writes=%llu idWrites=%llu own=(%d,%d) applied=(%d,%d) - "
                      "gate is the byte the engine's own move function tests first, and this build reads "
                      "it but never writes it any more: setting it sends the engine down the touch "
                      "branch, which returns before the branch that reads the drag, so claiming a drag "
                      "was the opposite of driving one, state and id are the rest of the touch "
                      "bookkeeping, and applied is now only read back so this line can show the engine "
                      "moving it instead of this build",
                     gateNow, stateNow, idNow, (unsigned long long)g_v193_gate_writes,
                     (unsigned long long)g_v196_touchid_writes, ownX, ownY, appX, appY);
        }
    }

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &appY);
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &pairX);
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &pairY);

        if (TNX_V190_APPLIED) {
            tnx_write_bytes(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &tx, sizeof(tx));
            tnx_write_bytes(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &ty, sizeof(ty));
            g_v190_applied_writes++;
        }
    }

    if (g_v197_stuck_logs < TNX_V197_STUCK_LOG && g_v190_engage_writes > 20 && !g_v190_move_tick) {
        int i = 0;
        int near = -1;
        int within = 0;
        float nd = 1000000.0f;
        float slen = sqrtf(dx * dx + dy * dy);
        float dot = 0.0f;

        for (i = 0; i < g_v189_pl_n; i++) {
            float bx = 0.0f;
            float by = 0.0f;
            float d = 0.0f;

            if (g_v189_pl_mine[i]) continue;

            bx = (float)g_v189_pl_x[i] - (float)ownX;
            by = (float)g_v189_pl_y[i] - (float)ownY;
            d = sqrtf(bx * bx + by * by);

            if (d < nd) {
                nd = d;
                near = i;
            }

            if (d < slen) within++;
        }

        if (near >= 0 && slen > 1.0f) {
            float bx = (float)g_v189_pl_x[near] - (float)ownX;
            float by = (float)g_v189_pl_y[near] - (float)ownY;

            dot = (bx * dx + by * dy) / (sqrtf(bx * bx + by * by) * slen);
        }

        g_v197_stuck++;
        g_v197_stuck_logs++;

        tnx_logf("v197 stuck writes=%llu own=(%d,%d) step=%.0f nearestBody=%.0f dot=%+.2f mine=%d "
                 "withinStep=%d pick=(%d,%d) - the body does not move although this build keeps "
                 "writing, which is what a character pressed against another player looks like: dot "
                 "near +1 means the step points at that body, withinStep counts the bodies closer "
                 "than the step", (unsigned long long)g_v190_engage_writes, ownX, ownY, (double)slen,
                 (double)nd, (double)dot, (near >= 0) ? g_v189_pl_mine[near] : -1, within, g_v180_tx,
                 g_v180_ty);
    }

    g_v189_sent_dx = tx - ownX;
    g_v189_sent_dy = ty - ownY;
    g_v189_last_tx = tx;
    g_v189_last_ty = ty;
    g_v189_drive_ticks++;

    tnx_v190_drive_note(ownX, ownY, tx, ty, appX, appY, pairX, pairY);

    if (g_v160_active) {
        g_v189_last_decision = g_v48_ticks;
        g_v189_decide_x = ownX;
        g_v189_decide_y = ownY;
    }

    if (g_v189_drive_logs < TNX_V189_DRIVE_LOGS ||
        ((g_v48_ticks % 60) == 0 && g_v189_drive_logs < 240)) {
        g_v189_drive_logs++;

        tnx_logf("v189 drive held=%d engaged=%d own=(%d,%d) pick=(%d,%d) sent=(%d,%d) step=%.0f "
                 "pair=(%d,%d) queue=%llu skipped=%llu pairOnly=%d holdTicks=%d - the step handed "
                 "to the client input is one frame of travel and not the pick, so the body is "
                 "walked instead of carried; a sent distance that has grown back to the pick means "
                 "something below put the uncapped target back", held, g_v160_active, ownX, ownY,
                 g_v180_tx, g_v180_ty, tx, ty,
                 (double)sqrtf((float)(g_v189_sent_dx * g_v189_sent_dx +
                                       g_v189_sent_dy * g_v189_sent_dy)),
                 g_v174_stick_x, g_v174_stick_y, (unsigned long long)g_v189_queue_calls,
                 (unsigned long long)g_v189_queue_skips, TNX_V189_PAIR_ONLY, TNX_V189_HOLD_TICKS);
    }

    return 1;
}

int g_v189_cand_now[TNX_V189_CAND];

int g_v189_cand_frame[TNX_V189_CAND];

int g_v189_cand_changes[TNX_V189_CAND];

int g_v189_cand_seen = 0;

int g_v189_dead_slot = -1;

int g_v189_dead_value = 0;

int g_v189_pending = 0;

int g_v189_pending_tick = 0;

int g_v189_pre[TNX_V189_CAND];

int32_t g_v189_prev_x = 0;

int32_t g_v189_prev_y = 0;

int g_v189_prev_valid = 0;

int g_v189_respawn_tick = 0;

int g_v189_respawns = 0;

int g_v189_life_logs = 0;

int g_v189_signal_logs = 0;

int g_v189_learn_logs = 0;

void tnx_v189_candidates(uintptr_t ownElem, int *out) {
    uint8_t deadByte = 0;
    int32_t ownAlive = -1;
    int32_t ctrlAlive = -1;
    uintptr_t ctrl = tnx_v150_controller();

    out[0] = -1;
    out[1] = -1;
    out[2] = -1;

    if (ownElem && tnx_read_bytes(ownElem + TNX_V91_DEAD_OFF, &deadByte, sizeof(deadByte))) {
        out[0] = (int)deadByte;
    }

    if (ownElem && tnx_read_i32(ownElem + TNX_V127_OWN_ALIVE_OFF, &ownAlive)) out[1] = (int)ownAlive;

    if (ctrl && tnx_read_i32(ctrl + TNX_V128_CTRL_ALIVE_OFF, &ctrlAlive)) out[2] = (int)ctrlAlive;
}

const char *tnx_v189_cand_name(int slot) {
    if (slot == 0) return "own+d4";
    if (slot == 1) return "own+140";
    if (slot == 2) return "ctrl+f80";

    return "none";
}

void tnx_v189_clear_life(void) {
    g_v167_stage = 0;
    g_v167_stuck = 0;
    g_v160_active = 0;
    g_v160_prev_idx = -1;
    g_v160_hold_until = 0;
    g_v160_last_danger = 0;
    g_v47_last_write_ms = 0;
    g_v152_issued = 0;
    g_v172_moving = 0;
    g_v180_hold = 0;
    g_v174_stick_hold = 0;
    g_v174_stick_x = 0;
    g_v174_stick_y = 0;
    g_v189_prev_valid = 0;
}

void tnx_v189_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py) {
    int i = 0;

    g_v189_respawns++;
    g_v189_state = TNX_V189_STATE_RESPAWN;
    g_v189_respawn_tick = (int)g_v48_ticks;

    {
        uintptr_t ctrl = tnx_v150_controller();
        int32_t pairX = 0;
        int32_t pairY = 0;

        if (ctrl && g_v174_stick_hold &&
            tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &pairX) &&
            tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &pairY) &&
            pairX == g_v174_stick_x && pairY == g_v174_stick_y) {
            int32_t zero = 0;

            tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_X_OFF, &zero, sizeof(zero));
            tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &zero, sizeof(zero));
        }
    }

    tnx_v189_clear_life();

    g_v189_pending = 1;
    g_v189_pending_tick = (int)g_v48_ticks;

    for (i = 0; i < TNX_V189_CAND; i++) {
        g_v189_pre[i] = g_v189_cand_frame[i];
        g_v189_cand_changes[i] = 0;
    }

    if (g_v189_life_logs < TNX_V189_LIFE_MAX_LOGS) {
        g_v189_life_logs++;

        tnx_logf("v189 RESPAWN #%d own=(%d,%d) from=(%d,%d) jump=%d cand=(%d,%d,%d) learned=%s=%d - "
                 "the character was teleported, which a walk cannot do, so this is the one life "
                 "event established without trusting a flag; the per life state is cleared here and "
                 "the candidates are held for %d frames to see which changed across the event",
                 g_v189_respawns, x, y, px, py,
                 (int)sqrtf((float)((x - px) * (x - px) + (y - py) * (y - py))),
                 g_v189_pre[0], g_v189_pre[1], g_v189_pre[2],
                 tnx_v189_cand_name(g_v189_dead_slot), g_v189_dead_value, TNX_V189_HOLD_FRAMES);
    }
}

int tnx_v189_life(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    int i = 0;
    int changed = 0;
    int deadNow = 0;

    tnx_v189_candidates(ownElem, g_v189_cand_now);

    if (g_v189_cand_seen) {
        for (i = 0; i < TNX_V189_CAND; i++) {
            if (g_v189_cand_now[i] != g_v189_cand_frame[i]) {
                changed = 1;

                if (g_v189_cand_changes[i] < 1000000) g_v189_cand_changes[i]++;
            }
        }

        if (changed && g_v189_signal_logs < TNX_V189_LIFE_MAX_LOGS) {
            g_v189_signal_logs++;

            tnx_logf("v189 signals own=(%d,%d) own+d4=%d own+140=%d ctrl+f80=%d learned=%s=%d - "
                     "printed on every change of any candidate, so a run that carries a death names "
                     "the flag even if the respawn learning never fires", ownX, ownY,
                     g_v189_cand_now[0], g_v189_cand_now[1], g_v189_cand_now[2],
                     tnx_v189_cand_name(g_v189_dead_slot), g_v189_dead_value);
        }
    }

    for (i = 0; i < TNX_V189_CAND; i++) g_v189_cand_frame[i] = g_v189_cand_now[i];
    g_v189_cand_seen = 1;

    if (g_v189_pending && ((int)g_v48_ticks - g_v189_pending_tick) >= TNX_V189_HOLD_FRAMES) {
        int bestSlot = -1;
        int bestChanges = 0;

        g_v189_pending = 0;

        for (i = 0; i < TNX_V189_CAND; i++) {
            if (g_v189_pre[i] < 0 || g_v189_cand_now[i] < 0) continue;
            if (g_v189_cand_now[i] == g_v189_pre[i]) continue;
            if (bestSlot < 0 || g_v189_cand_changes[i] < bestChanges) {
                bestSlot = i;
                bestChanges = g_v189_cand_changes[i];
            }
        }

        if (bestSlot >= 0) {
            g_v189_dead_slot = bestSlot;
            g_v189_dead_value = g_v189_pre[bestSlot];

            if (g_v189_learn_logs < TNX_V189_LEARN_LOGS) {
                g_v189_learn_logs++;

                tnx_logf("v189 death flag learned slot=%d %s dead=%d alive=%d changes=%d from the "
                         "respawn at tick=%d - this candidate changed across the teleport, held its "
                         "new value for %d frames, and moved %d times in this life, fewer than any "
                         "rival, so it is the flag a guard may use; until this line exists no guard "
                         "runs at all and nothing is held on a guess", bestSlot,
                         tnx_v189_cand_name(bestSlot), g_v189_pre[bestSlot],
                         g_v189_cand_now[bestSlot], bestChanges, g_v189_pending_tick,
                         TNX_V189_HOLD_FRAMES, bestChanges);
            }
        }
    }

    if (g_v189_prev_valid && tnx_v191_own_ok(ownX, ownY) &&
        tnx_v191_own_ok(g_v189_prev_x, g_v189_prev_y)) {
        int64_t jx = (int64_t)ownX - (int64_t)g_v189_prev_x;
        int64_t jy = (int64_t)ownY - (int64_t)g_v189_prev_y;

        if (jx * jx + jy * jy >= (int64_t)TNX_V189_RESPAWN_JUMP * TNX_V189_RESPAWN_JUMP) {
            tnx_v189_respawn_event(ownX, ownY, g_v189_prev_x, g_v189_prev_y);
        }
    }

    g_v189_prev_x = ownX;
    g_v189_prev_y = ownY;
    g_v189_prev_valid = 1;

    if (g_v189_state == TNX_V189_STATE_INIT) g_v189_state = TNX_V189_STATE_ALIVE;

    if (g_v189_dead_slot >= 0 &&
        g_v189_cand_now[g_v189_dead_slot] == g_v189_dead_value) deadNow = 1;

    if (deadNow) {
        if (g_v189_state != TNX_V189_STATE_DEAD) {
            g_v189_state = TNX_V189_STATE_DEAD;

            if (g_v189_life_logs < TNX_V189_LIFE_MAX_LOGS) {
                g_v189_life_logs++;

                tnx_logf("v189 own is DEAD own=(%d,%d) %s=%d - the learned flag says so, so the "
                         "dodge is held and nothing is written until it clears; the label carries "
                         "the same state on screen", ownX, ownY, tnx_v189_cand_name(g_v189_dead_slot),
                         g_v189_dead_value);
            }
        }

        return 1;
    }

    if (g_v189_state == TNX_V189_STATE_DEAD) {
        tnx_v189_clear_life();

        g_v189_state = TNX_V189_STATE_ALIVE;

        if (g_v189_life_logs < TNX_V189_LIFE_MAX_LOGS) {
            g_v189_life_logs++;

            tnx_logf("v189 own is alive again own=(%d,%d) %s=%d - the learned candidate left its "
                     "dead value, so the dodge resumes on a cleared life and cleared heading", ownX,
                     ownY, tnx_v189_cand_name(g_v189_dead_slot),
                     g_v189_cand_now[g_v189_dead_slot]);
        }

        return 0;
    }

    if (g_v189_state == TNX_V189_STATE_RESPAWN &&
        ((int)g_v48_ticks - g_v189_respawn_tick) < TNX_V189_RESPAWN_VISIBLE) {
        return 0;
    }

    g_v189_state = TNX_V189_STATE_ALIVE;

    return 0;
}

void tnx_v189_drift(void) {
    int32_t ownX = 0;
    int32_t ownY = 0;

    if (!g_v189_last_decision) return;
    if (g_v189_drift_done == g_v189_last_decision) return;
    if ((g_v48_ticks - g_v189_last_decision) < 60) return;
    if ((g_v48_ticks - g_v189_last_decision) > 240) return;
    if (!tnx_v178_own(&ownX, &ownY)) return;
    if (g_v189_drift_logs >= TNX_V190_DRIVE_LOGS) return;

    g_v189_drift_logs++;
    g_v189_drift_done = g_v189_last_decision;

    tnx_logf("v189 drift after the last decision: frames=%d traveled=%d from=(%d,%d) own=(%d,%d) "
             "lastSent=(%d,%d) sentStep=%.0f holdTicks=%d - this is the distance covered in the "
             "second after the dodge stopped choosing, so a traveled distance near the walk speed of "
             "780 means the body is still riding the last target, and one near zero means the writes "
             "and not the engine were pacing it",
             (int)(g_v48_ticks - g_v189_last_decision),
             (int)sqrtf((float)((ownX - g_v189_decide_x) * (ownX - g_v189_decide_x) +
                                (ownY - g_v189_decide_y) * (ownY - g_v189_decide_y))),
             (int)g_v189_decide_x, (int)g_v189_decide_y, ownX, ownY, g_v189_last_tx,
             g_v189_last_ty, (double)TNX_V189_STEP, TNX_V189_HOLD_TICKS);
}

void tnx_v196_dump(void) {
    int i = 0;

    if (!TNX_V196_DUMP) return;
    if ((g_v48_ticks % TNX_V196_DUMP_EVERY) != 0) return;
    if (g_v196_dump_logs >= TNX_V196_DUMP_LOGS) return;

    g_v196_dump_logs++;

    tnx_logf("v196 dump own pos=(%d,%d) ok=%d team=%d trust=%d mates=%d enemies=%d cluster=%d/%d "
             "agree=%d players=%d segs=%d engaged=%d pick=(%d,%d) bodyMine=%d bodyEnemy=%d freest=%llu "
             "gate=%llu pred=%llu/%llu",
             g_v189_own_x, g_v189_own_y, tnx_v191_own_ok(g_v189_own_x, g_v189_own_y),
             g_v191_own_team, g_v191_team_trust, g_v189_mate_n, g_v191_enemy_n, g_v196_mates,
             g_v196_enemies, g_v196_agree, g_v189_pl_n, g_v172_seg_count, g_v160_active,
             g_v160_tx, g_v160_ty, g_v192_body_mine, g_v192_body_enemy,
             (unsigned long long)g_v196_freest_used, (unsigned long long)g_v193_gate_writes,
             (unsigned long long)g_v192_pred_calls, (unsigned long long)g_v192_pred_fails);

    for (i = 0; i < g_v189_pl_n && i < 6; i++) {
        tnx_logf("v196 dump p%d gid=%d pos=(%d,%d) spawn=(%d,%d) team=%d mine=%d",
                 i, g_v196_pl_gid[i], g_v189_pl_x[i], g_v189_pl_y[i], g_v196_pl_sx[i],
                 g_v196_pl_sy[i], g_v189_pl_team[i], g_v189_pl_mine[i]);
    }

    for (i = 0; i < TNX_V140_PROJ_MAX; i++) {
        tnx_v140_proj_t *p = &g_v140_projs[i];
        uint64_t age = 0;

        if (p->classRva == (uintptr_t)-1) continue;
        if (!p->hasPrev) age = 0;
        else age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 0;

        tnx_logf("v196 dump j%d gid=%d pos=(%d,%d) prev=(%d,%d) spawn=(%d,%d) team=%d dt=%llu",
                 i, p->gid, p->x, p->y, p->px, p->py, p->spawnX, p->spawnY, p->team,
                 (unsigned long long)age);
    }
}

void tnx_v193_core(void) {
    if ((g_v48_ticks % 60) != 0) return;

    tnx_logf("v193 core tick=%llu own=(%d,%d) ownOk=%d team=%d mates=%d enemies=%d trust=%d "
             "players=%d segs=%d trackedOwn=%d trackedOther=%d oneshot=%d body=%d enemyBlock=%d "
             "mateBlock=%d gate=%llu pred=%llu/%llu deadPick=%llu human=%llu driveWrites=%llu "
             "stickSkips=%llu stuck=%llu",
             (unsigned long long)g_v48_ticks, g_v189_own_x, g_v189_own_y,
             tnx_v191_own_ok(g_v189_own_x, g_v189_own_y), g_v191_own_team, g_v189_mate_n,
             g_v191_enemy_n, g_v191_team_trust, g_v189_pl_n, g_v172_seg_count, g_v167_proj_own,
             g_v167_proj_other, g_v191_oneshot_segs, g_v192_body_blocks, g_v191_enemy_blocks,
             g_v189_block_hits, (unsigned long long)g_v193_gate_writes,
             (unsigned long long)g_v192_pred_calls, (unsigned long long)g_v192_pred_fails,
             (unsigned long long)g_v193_dead_picks, (unsigned long long)g_v192_human_live,
             (unsigned long long)g_v190_engage_writes, (unsigned long long)g_v197_stick_skips,
             (unsigned long long)g_v197_stuck);
}

void tnx_v172_probe(void) {
    uintptr_t bs = tnx_v172_bs();
    void *vt = NULL;
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float cs = 0.0f;
    float sn = 0.0f;
    uint32_t mode = 0;
    unsigned long long vtRva = 0;

    tnx_v173_scan();

    if (!bs) return;

    if (g_v172_probe_logs < 1) {
        g_v172_probe_logs++;

        if (tnx_read_ptr(bs, &vt) && (uintptr_t)vt > g_base) {
            vtRva = (unsigned long long)((uintptr_t)vt - g_base);
        }

        tnx_logf("v173 bs live scene=%p bs=%p ctrl=%p classRva=%#llx - the one-shot waits for a live "
                 "scene now, so the class word is read from the object the dodge really uses and not "
                 "from a null pointer, which is what the previous run printed as scene=0x0 and "
                 "classRva=0; updateMovement cannot be hooked on this target - a scan of every "
                 "eight-byte word of __DATA_CONST and __DATA found no slot pointing at it and inline "
                 "patching is not supported - so the BattleScreen object is the scene this file "
                 "already resolves and the joystick is searched in its window by the v173 scanner. "
                 "The class word 0xfe9d00 is the identity the earlier note names",
                 (void *)g_scene_object, (void *)bs, (void *)tnx_v150_controller(), vtRva);
    }

    if (g_v172_own_logs < 20 && (g_v48_ticks % 60) == 0) {
        g_v172_own_logs++;

        tnx_logf("v172 own check ownElem=%p ownFrom=%s - the same object the dodge reads its position "
                 "from, printed next to the element lines so the two own sources in the log can be "
                 "told apart instead of being read as a disagreement",
                 (void *)g_v144_own_elem, g_v145_own_from);
    }

    if (g_v172_probe_logs < 22 && (g_v48_ticks % 60) == 0) {
        g_v172_probe_logs++;

        if (!tnx_v172_joy_read(bs, &ax, &ay, &bx, &by, &mode, &cs, &sn)) return;

        tnx_logf("v172 joyprobe bs=%p ax=%+.4f ay=%+.4f bx=%+.4f by=%+.4f mode=%u cos=%+.4f sin=%+.4f "
                 "- read only, nothing is written in this build; move the stick by hand and if these "
                 "move and mode reads 2 or 3 this is the joystick, otherwise this class keeps the "
                 "stick elsewhere and the window diff below is the way to it",
                 (void *)bs, (double)ax, (double)ay, (double)bx, (double)by, mode, (double)cs,
                 (double)sn);
    }
}

void tnx_v172_build(void) {
    int k;

    g_v172_seg_count = 0;
    g_v172_build_tick = (int)g_v48_ticks;

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        const tnx_v140_proj_t *p = &g_v140_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        float len = 0.0f;
        float speed = 0.0f;
        float rem = 0.0f;
        tnx_v172_seg_t *s = NULL;

        if (!p->elem) continue;
        if (!p->hasPrev && !TNX_V191_ONESHOT) continue;
        if (g_v172_seg_count >= TNX_V172_SEG_MAX) break;

        if (TNX_V167_TEAM_FILTER && g_v191_team_trust && g_v167_own_team_seen &&
            p->team == g_v167_own_team) continue;

        if (TNX_V202_TEAM_STRICT && g_v189_own_team >= 0 && p->team == g_v189_own_team) continue;
        if (tnx_v204_proj_mine(p)) continue;

        if (!p->hasPrev) {

            uint64_t age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 1;

            vx = (float)(p->x - p->spawnX) / (float)age;
            vy = (float)(p->y - p->spawnY) / (float)age;

            if (fabsf(vx) < 0.5f && fabsf(vy) < 0.5f) continue;

            g_v191_oneshot_segs++;
        } else if (!tnx_v174_proj_vel(p, &vx, &vy)) continue;

        len = sqrtf(vx * vx + vy * vy);

        if (len < TNX_V174_MIN_PROJ_SPEED) continue;

        speed = len * 60.0f;

        if (speed < 1.0f) speed = 1.0f;

        if (g_v227_spd_min < 1.0f || speed < g_v227_spd_min) g_v227_spd_min = speed;
        if (speed > g_v227_spd_max) g_v227_spd_max = speed;

        rem = speed * ((float)TNX_V172_MAX_LIFETIME_MS / 1000.0f);

        if (rem > TNX_V172_DEFAULT_RANGE) rem = TNX_V172_DEFAULT_RANGE;
        if (rem < 1.0f) rem = 1.0f;

        if (TNX_V227_REJECT) {
            int rule = 0;

            if (speed < TNX_V227_MIN_SPEED) rule = 1;
            else if (speed > TNX_V227_MAX_SPEED) rule = 2;
            else if ((p->qtick > p->ptick) && (p->qtick - p->ptick) <= TNX_V227_BLINK_TICKS &&
                     rem < TNX_V227_BLINK_REM) rule = 3;

            if (rule) {
                if (rule == 1) g_v227_drop_slow++;
                else if (rule == 2) g_v227_drop_fast++;
                else g_v227_drop_blink++;

                if (g_v227_logs < TNX_V227_LOGS) {
                    g_v227_logs++;

                    tnx_logf("v227 drop rule=%d gid=%d speed=%.0f age=%llu rem=%.0f team=%d - a shot of "
                             "this shape cannot be walked out of, so reacting to it only spends "
                             "movement and hides the ones that can be dodged",
                             rule, p->gid, (double)speed,
                             (unsigned long long)((p->qtick > p->ptick) ? (p->qtick - p->ptick) : 0),
                             (double)rem, p->team);
                }

                continue;
            }
        }

        rem = tnx_v242_clip_range((float)p->x, (float)p->y, vx / len, vy / len, rem);

        s = &g_v172_seg[g_v172_seg_count++];
        s->gid = p->gid;
        s->ax = (float)p->x;
        s->ay = (float)p->y;
        s->dirX = vx / len;
        s->dirY = vy / len;
        s->bx = s->ax + s->dirX * rem;
        s->by = s->ay + s->dirY * rem;
        s->speed = speed;
        s->remaining = rem;
        s->inflatedR = TNX_V172_PROJ_RADIUS + TNX_V172_PLAYER_RADIUS + TNX_V172_SAFETY_MARGIN;
    }

    if (g_v242_seg_test > 0) g_v242_seg_frac = (g_v242_seg_clip * 100) / g_v242_seg_test;
}

float tnx_v172_seg_dist2(float px, float py, const tnx_v172_seg_t *s) {
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

int tnx_v172_threatened(float x, float y) {
    int i;

    for (i = 0; i < g_v172_seg_count; i++) {
        float d2 = tnx_v172_seg_dist2(x, y, &g_v172_seg[i]);

        if (d2 <= g_v172_seg[i].inflatedR * g_v172_seg[i].inflatedR) return 1;
    }

    return 0;
}

float tnx_v172_clearance(float x, float y) {
    float best = 1000000.0f;
    int i;

    for (i = 0; i < g_v172_seg_count; i++) {
        float d = sqrtf(tnx_v172_seg_dist2(x, y, &g_v172_seg[i])) - g_v172_seg[i].inflatedR;

        if (d < best) best = d;
    }

    return best;
}

float tnx_v207_eta_ms(float x, float y) {
    float best = 1.0e9f;
    int i = 0;

    for (i = 0; i < g_v172_seg_count; i++) {
        const tnx_v172_seg_t *s = &g_v172_seg[i];
        float abx = s->bx - s->ax;
        float aby = s->by - s->ay;
        float denom = abx * abx + aby * aby;
        float t = 0.0f;
        float cx = 0.0f;
        float cy = 0.0f;
        float d = 0.0f;
        float ms = 0.0f;

        if (denom > 0.0001f) {
            t = ((x - s->ax) * abx + (y - s->ay) * aby) / denom;
        }

        if (t < 0.0f) t = 0.0f;
        if (t > 1.0f) t = 1.0f;

        cx = s->ax + abx * t - x;
        cy = s->ay + aby * t - y;
        d = sqrtf(cx * cx + cy * cy) - s->inflatedR;

        if (d < 0.0f) d = 0.0f;
        if (s->speed <= 1.0f) continue;

        ms = d / s->speed * 1000.0f;

        if (ms < best) best = ms;
    }

    return best;
}

int tnx_v209_imminent(float x, float y) {
    float look = TNX_V212_RAGE ? (TNX_V225_MODE_TUNE ? tnx_v225_look_ms() : TNX_V212_LOOKAHEAD_MS)
                               : TNX_V209_LOOKAHEAD_MS;

    if (look <= 0.0f) return 0;
    if (g_v172_seg_count <= 0) return 0;

    return (tnx_v207_eta_ms(x, y) <= look) ? 1 : 0;
}

int tnx_v216_flee(float px, float py, float *tx, float *ty) {
    int i = 0;
    int best = -1;
    float bestMs = 1.0e9f;
    float cx = 0.0f;
    float cy = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;
    float len = 0.0f;

    if (!TNX_V216_FLEE) return 0;
    if (g_v172_seg_count <= 0) return 0;

    for (i = 0; i < g_v172_seg_count; i++) {
        const tnx_v172_seg_t *s = &g_v172_seg[i];
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
        dx = -(g_v172_seg[best].by - g_v172_seg[best].ay);
        dy = (g_v172_seg[best].bx - g_v172_seg[best].ax);
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) return 0;
    }

    *tx = px + dx / len * TNX_V216_FLEE_STEP;
    *ty = py + dy / len * TNX_V216_FLEE_STEP;
    g_v216_flees++;

    return 1;
}

void tnx_v216_predict(int32_t ownX, int32_t ownY, float tx, float ty) {
    int i = 0;
    int best = -1;
    float px = (float)ownX;
    float py = (float)ownY;
    float bestMs = 1.0e9f;
    float qx = 0.0f;
    float qy = 0.0f;
    float d = 0.0f;
    int react = -1;

    if (g_v216_logs >= TNX_V216_LOGS) return;
    if (TNX_V216_EVERY > 0 && (g_v48_ticks % (uint64_t)TNX_V216_EVERY) != 0) return;

    for (i = 0; i < g_v172_seg_count; i++) {
        const tnx_v172_seg_t *s = &g_v172_seg[i];
        float abx = s->bx - s->ax;
        float aby = s->by - s->ay;
        float den = abx * abx + aby * aby;
        float t = 0.0f;
        float ms = 0.0f;

        if (den > 0.0001f) t = ((px - s->ax) * abx + (py - s->ay) * aby) / den;

        if (t < 0.0f) t = 0.0f;
        if (t > 1.0f) t = 1.0f;

        ms = sqrtf((s->ax + abx * t - px) * (s->ax + abx * t - px) +
                   (s->ay + aby * t - py) * (s->ay + aby * t - py)) - s->inflatedR;

        if (ms < 0.0f) ms = 0.0f;
        if (s->speed > 1.0f) ms = ms / s->speed * 1000.0f;

        if (ms < bestMs) {
            bestMs = ms;
            best = i;
            qx = s->ax + abx * t;
            qy = s->ay + aby * t;
        }
    }

    if (g_v216_new_tick >= 0) react = (int)((int64_t)g_v48_ticks - (int64_t)g_v216_new_tick);

    g_v216_logs++;

    if (best < 0) {
        tnx_logf("v216 predict tick=%llu own=(%d,%d) tgt=(%.0f,%.0f) threats=0 react=%d flees=%llu - "
                 "no segment is live, so there is nothing to lead and the pick is a plain step",
                 (unsigned long long)g_v48_ticks, ownX, ownY, (double)tx, (double)ty, react,
                 (unsigned long long)g_v216_flees);

        return;
    }

    d = sqrtf((qx - px) * (qx - px) + (qy - py) * (qy - py));

    tnx_logf("v216 predict tick=%llu own=(%d,%d) tgt=(%.0f,%.0f) threats=%d react=%d gid=%d "
             "impact=(%.0f,%.0f) lead=(%.0f,%.0f) d=%.0f eta=%.0fms spd=%.0f ms=%.0f - impact is the "
             "closest point of the nearest flight to own, lead is the offset own has to clear, and a "
             "react above one tick means the pick was made a frame or more after the threat appeared",
             (unsigned long long)g_v48_ticks, ownX, ownY, (double)tx, (double)ty, g_v172_seg_count,
             react, g_v172_seg[best].gid, (double)qx, (double)qy, (double)(qx - px), (double)(qy - py),
             (double)d, (double)bestMs, (double)g_v172_seg[best].speed, (double)(d / (g_v172_seg[best].speed > 1.0f ? g_v172_seg[best].speed : 1.0f) * 1000.0f));
}

void tnx_v207_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape) {
    uintptr_t ctrl = 0;
    int32_t ax = 0;
    int32_t ay = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    int32_t predX = 0;
    int32_t predY = 0;
    int32_t mode = 0;
    float eta = 0.0f;
    int lag = -1;

    if (!TNX_V207_PRECISION) return;
    if (TNX_V207_EVERY > 0 && (g_v48_ticks % (uint64_t)TNX_V207_EVERY) != 0) return;

    g_v207_logs++;
    ctrl = tnx_v150_controller();

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &ax);
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &ay);
        tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (g_v205_joystick) tnx_read_i32(g_v205_joystick + TNX_V172_BS_MODE, &mode);

    if (g_v192_pred_last) {
        tnx_read_i32(g_v192_pred_last + TNX_MODE_PREDICTX_OFF, &predX);
        tnx_read_i32(g_v192_pred_last + TNX_MODE_PREDICTY_OFF, &predY);
    }

    eta = tnx_v207_eta_ms((float)ownX, (float)ownY);

    if (g_v224_t0) {
        uint64_t now = tnx_v213_us();

        g_v213_dec_us = (now >= g_v224_t0) ? (now - g_v224_t0) : 0;

        if (g_v213_dec_us > g_v213_dec_us_max) g_v213_dec_us_max = g_v213_dec_us;
        if (g_v213_dec_us > TNX_V224_SLOW_US) g_v224_slow++;
    }

    if (g_v172_build_tick >= 0) lag = (int)((int64_t)g_v48_ticks - (int64_t)g_v172_build_tick);

    tnx_logf("v207 precision tick=%llu own=(%d,%d) dir=(%.0f,%.0f) escape=%d pair=(%d,%d) "
             "applied=(%d,%d) mode=%d joy=%p threats=%d eta=%.0fms buildLag=%d pred=(%d,%d) "
             "took=%llu denied=%llu - eta is the time the nearest bullet needs to reach own at its "
             "own speed, so any decision later than eta is a decision after the hit, and buildLag is "
             "the ticks between rebuilding the threat list and writing the stick",
             (unsigned long long)g_v48_ticks, ownX, ownY, (double)dirX, (double)dirY, escape, ax, ay,
             appX, appY, mode, (void *)g_v205_joystick, g_v172_seg_count, (double)eta, lag, predX,
             predY, (unsigned long long)g_v205_joystick_took,
             (unsigned long long)g_v201_write_denied);
}

int tnx_v218_body_blocked(float px, float py, float dirX, float dirY, float len) {
    float ex = 0.0f;
    float ey = 0.0f;
    int i = 0;

    if (!TNX_V214_MATE_AVOID) return 0;
    if (g_v189_pl_n <= 0) return 0;
    if (len < 1.0f) return 0;

    ex = px + dirX * len;
    ey = py + dirY * len;

    for (i = 0; i < g_v189_pl_n; i++) {
        if (tnx_v192_seg_dist(px, py, ex, ey, (float)g_v189_pl_x[i], (float)g_v189_pl_y[i]) <
            TNX_V214_MATE_CLEAR) {
            return 1;
        }
    }

    return 0;
}

float tnx_v218_body_score(float px, float py, float dirX, float dirY, float len) {
    float ex = px + dirX * len;
    float ey = py + dirY * len;
    float best = 1.0e9f;
    int i = 0;

    if (g_v189_pl_n <= 0) return best;

    for (i = 0; i < g_v189_pl_n; i++) {
        float d = tnx_v192_seg_dist(px, py, ex, ey, (float)g_v189_pl_x[i], (float)g_v189_pl_y[i]);

        if (d < best) best = d;
    }

    return best;
}

float tnx_v235_speed(void) {
    float v = g_v231_walk_step * 60.0f;

    if (v < 120.0f) v = 120.0f;
    if (v > 1200.0f) v = 1200.0f;

    return v;
}

float tnx_v235_clearance(float px, float py, float dirX, float dirY) {
    float speed = tnx_v235_speed();
    float best = 1.0e9f;
    int i = 0;
    int k = 0;

    for (i = 0; i < g_v240_sel_n; i++) {
        const tnx_v172_seg_t *seg = &g_v172_seg[g_v240_sel[i]];

        for (k = 0; k <= TNX_V240_STEPS; k++) {
            float t = TNX_V235_HORIZON * ((float)k / (float)TNX_V240_STEPS);
            float qx = px + dirX * speed * t;
            float qy = py + dirY * speed * t;
            float d = tnx_v192_seg_dist(qx, qy, seg->ax, seg->ay, seg->bx, seg->by) - seg->inflatedR;

            if (d < best) best = d;
        }
    }

    g_v235_evals++;

    return best;
}

float tnx_v235_score(float px, float py, float dirX, float dirY, float len) {
    tnx_v240_select(px, py);

    return tnx_v235_clearance(px, py, dirX, dirY) +
           TNX_V235_BODY_W * tnx_v228_body_score(px, py, dirX, dirY, len);
}

float tnx_v228_body_score(float px, float py, float dirX, float dirY, float len) {
    float ex = px + dirX * len;
    float ey = py + dirY * len;
    float best = 1.0e9f;
    int i = 0;

    if (!TNX_V228_BODY_SCAN) return tnx_v218_body_score(px, py, dirX, dirY, len);
    if (g_dodge_probe_usable <= 0) return tnx_v218_body_score(px, py, dirX, dirY, len);

    for (i = 0; i < g_dodge_probe_usable; i++) {
        const tnx_v47_obj_t *o = &g_dodge_probe_list[i];
        float d = 0.0f;

        if (o->gid < TNX_V179_PLAYER_GID) continue;
        if (o->gid >= TNX_V179_SHOT_GID) continue;
        if (g_v182_own_elem && o->object == g_v182_own_elem) continue;

        d = tnx_v192_seg_dist(px, py, ex, ey, (float)o->x, (float)o->y);

        if (d < best) best = d;
    }

    return best;
}

void tnx_v218_unblock(float px, float py, float len, float *dirX, float *dirY) {
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

    if (!TNX_V214_MATE_AVOID) return;
    if (len < 1.0f) return;

    bestScore = tnx_v235_score(px, py, base, baseY, len);
    baseScore = bestScore;
    bestX = base;
    bestY = baseY;

    if (g_v233_last_ok) {
        bestScore += TNX_V233_MOMENTUM * (base * g_v233_last_x + baseY * g_v233_last_y);
        baseScore = bestScore;
    }

    for (i = 0; i < 12; i++) {
        float a = rot[i] * rad;
        float c = cosf(a);
        float sn = sinf(a);
        float rx = base * c - baseY * sn;
        float ry = base * sn + baseY * c;
        float score = tnx_v235_score(px, py, rx, ry, len);

        if (g_v233_last_ok) score += TNX_V233_MOMENTUM * (rx * g_v233_last_x + ry * g_v233_last_y);

        if (score > bestScore) {
            bestScore = score;
            bestX = rx;
            bestY = ry;
        }
    }

    if (g_v233_last_ok && bestX != base &&
        (bestScore - (tnx_v235_score(px, py, base, baseY, len) +
                      TNX_V233_MOMENTUM * (base * g_v233_last_x + baseY * g_v233_last_y))) <
            TNX_V233_KEEP_BAND) {
        bestX = base;
        bestY = baseY;
        g_v233_keeps++;
    }

    *dirX = bestX;
    *dirY = bestY;

    if (bestX != 0.0f || bestY != 0.0f) {
        float n = sqrtf(bestX * bestX + bestY * bestY);

        if (n > 0.0001f) {
            g_v233_last_x = bestX / n;
            g_v233_last_y = bestY / n;
            g_v233_last_ok = 1;
        }
    }

    if (bestScore > baseScore) {
        g_v214_mate_turns++;
    } else {
        g_v214_mate_stuck++;
    }
}

int tnx_v172_valid_point(float x, float y) {
    int32_t cx = (int32_t)x;
    int32_t cy = (int32_t)y;

    tnx_v162_clamp(&cx, &cy);

    if (cx != (int32_t)x || cy != (int32_t)y) return 0;

    if (tnx_v189_mate_blocked(x, y)) {
        g_v189_block_hits++;

        return 0;
    }

    if (tnx_v192_body_blocked(x, y, (float)g_v189_own_x, (float)g_v189_own_y)) {
        return 0;
    }

    if (tnx_v191_enemy_blocked(x, y, (float)g_v189_own_x, (float)g_v189_own_y)) {
        g_v191_enemy_blocks++;

        return 0;
    }

    return 1;
}

int tnx_v172_walk_into_bullet(float px, float py, float dirX, float dirY, float travel) {
    float pvx = dirX * TNX_V172_PLAYER_SPEED;
    float pvy = dirY * TNX_V172_PLAYER_SPEED;
    float horizon = travel / TNX_V172_PLAYER_SPEED;
    int i;

    for (i = 0; i < g_v172_seg_count; i++) {
        const tnx_v172_seg_t *s = &g_v172_seg[i];
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

float tnx_v172_safe_angle(float px, float py, float desiredDeg, int *ok) {
    static const float offsets[6] = { 15.0f, 30.0f, 45.0f, 60.0f, 75.0f, 90.0f };
    const float deg = 3.14159265358979f / 180.0f;
    float scan = TNX_V172_EXTEND_DEFAULT * 1.5f;
    int i;

    *ok = 1;

    if (!tnx_v172_walk_into_bullet(px, py, cosf(desiredDeg * deg), sinf(desiredDeg * deg), scan) &&
        !tnx_v218_body_blocked(px, py, cosf(desiredDeg * deg), sinf(desiredDeg * deg), scan)) {
        return desiredDeg;
    }

    for (i = 0; i < 6; i++) {
        float a = desiredDeg + offsets[i];
        float b = desiredDeg - offsets[i];

        if (!tnx_v172_walk_into_bullet(px, py, cosf(a * deg), sinf(a * deg), scan) &&
            !tnx_v218_body_blocked(px, py, cosf(a * deg), sinf(a * deg), scan)) return a;

        if (!tnx_v172_walk_into_bullet(px, py, cosf(b * deg), sinf(b * deg), scan) &&
            !tnx_v218_body_blocked(px, py, cosf(b * deg), sinf(b * deg), scan)) return b;
    }

    *ok = 0;

    return desiredDeg;
}

int tnx_v172_passed(float px, float py) {
    float ax = g_v172_tx - g_v172_start_x;
    float ay = g_v172_ty - g_v172_start_y;
    float len2 = ax * ax + ay * ay;
    float bx = 0.0f;
    float by = 0.0f;

    if (len2 <= 0.0f) return 1;

    bx = px - g_v172_start_x;
    by = py - g_v172_start_y;

    return (ax * bx + ay * by) >= len2 ? 1 : 0;
}

int tnx_v172_best(float px, float py, float *tx, float *ty) {
    const float tau = 2.0f * 3.14159265358979f;
    float bestDist = 0.0f;
    float bestClear = 0.0f;
    float minSafe = 1000000.0f;
    int found = 0;
    int i;

    for (i = 0; i < TNX_V172_NUM_ANGLES; i++) {
        int idx = i;
        float angle = 0.0f;
        float dx = 0.0f;
        float dy = 0.0f;
        float d = 0.0f;

        if (g_v172_have_angle) {
            int base = (int)roundf(g_v172_angle / tau * (float)TNX_V172_NUM_ANGLES);
            int span = (i + 1) / 2;
            int sign = (i % 2) ? -1 : 1;

            idx = base + sign * span;

            while (idx < 0) idx += TNX_V172_NUM_ANGLES;

            idx %= TNX_V172_NUM_ANGLES;
        }

        angle = tau * (float)idx / (float)TNX_V172_NUM_ANGLES;
        dx = cosf(angle);
        dy = sinf(angle);

        for (d = TNX_V172_STEP; d <= TNX_V172_MAX_DIST; d += TNX_V172_STEP) {
            float cx = px + dx * d;
            float cy = py + dy * d;
            float clear = 0.0f;

            if (found && d > minSafe) break;

            if (!tnx_v172_valid_point(cx, cy)) break;

            if (tnx_v172_threatened(cx, cy)) continue;

            clear = tnx_v172_clearance(cx, cy);

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

int tnx_v172_write(float dirX, float dirY) {
    uintptr_t bs = tnx_v172_bs();
    float len = sqrtf(dirX * dirX + dirY * dirY);
    float nx = 0.0f;
    float ny = 0.0f;
    int32_t two = 2;

    if (len < 0.001f) return 0;
    if (!bs) return 0;

    nx = dirX / len * TNX_V172_JOY_SCALE;
    ny = dirY / len * TNX_V172_JOY_SCALE;

    if (!tnx_write_f32(bs + TNX_V172_BS_AX, nx)) return 0;
    if (!tnx_write_f32(bs + TNX_V172_BS_AY, ny)) return 0;
    if (!tnx_write_f32(bs + TNX_V172_BS_BX, nx)) return 0;
    if (!tnx_write_f32(bs + TNX_V172_BS_BY, ny)) return 0;

    tnx_write_bytes(bs + TNX_V172_BS_MODE, &two, sizeof(two));

    return 1;
}

int tnx_v196_freest(float px, float py, float *tx, float *ty) {
    int pass = 0;
    int i = 0;
    int bestOk = 0;
    float bestRoom = -1.0f;
    float bestX = 0.0f;
    float bestY = 0.0f;

    for (pass = 0; pass < 2; pass++) {
        for (i = 0; i < TNX_V196_FREEST_ANGLES; i++) {
            float rad = (2.0f * 3.14159265358979f * (float)i) / (float)TNX_V196_FREEST_ANGLES;
            float ex = px + cosf(rad) * TNX_V172_STEP;
            float ey = py + sinf(rad) * TNX_V172_STEP;
            float room = 1000000.0f;
            int32_t cxi = (int32_t)ex;
            int32_t cyi = (int32_t)ey;
            int k = 0;

            tnx_v162_clamp(&cxi, &cyi);

            if (cxi != (int32_t)ex || cyi != (int32_t)ey) continue;
            if (pass == 0 && tnx_v172_threatened(ex, ey)) continue;

            for (k = 0; k < g_v189_pl_n; k++) {
                float d = 0.0f;

                if (g_v189_pl_mine[k]) continue;

                d = tnx_v192_seg_dist(px, py, ex, ey, (float)g_v189_pl_x[k], (float)g_v189_pl_y[k]);

                if (d < room) room = d;
            }

            if (room > bestRoom) {
                bestRoom = room;
                bestX = ex;
                bestY = ey;
                bestOk = 1;
            }
        }

        if (bestOk) break;
    }

    if (!bestOk) return 0;
    if (!TNX_V206_ESCAPE && bestRoom < TNX_V196_FREEST_MIN) return 0;

    *tx = bestX;
    *ty = bestY;
    g_v196_freest_used++;

    return 1;
}

int tnx_v172_decide(int32_t ownX, int32_t ownY) {
    float px = (float)ownX;
    float py = (float)ownY;
    float tx = 0.0f;
    float ty = 0.0f;
    int picked = 0;
    int threatened = 0;
    int stick = 0;
    int safeOk = 0;
    float desiredDeg = 0.0f;

    tnx_v242_arm(px, py);
    tnx_v246_stats();

    tnx_v172_build();

    if (g_v172_seg_count != g_v216_prev_seg) {
        g_v216_new_tick = (int)g_v48_ticks;
        g_v216_prev_seg = g_v172_seg_count;
    }

    threatened = tnx_v172_threatened(px, py);

    if (g_v172_seg_count > 0 && tnx_v172_clearance(px, py) < TNX_V233_ENGAGE) {
        threatened = 1;
        g_v233_engage++;
    }

    if (TNX_V212_RAGE && g_v172_seg_count > 0) {
        if (!TNX_V226_HIT_ONLY || tnx_v209_imminent(px, py)) {
            threatened = 1;
            g_v212_rage_frames++;
        }
    }

    if (tnx_v209_imminent(px, py)) {
        threatened = 1;
        g_v209_lookahead++;
    }

    g_v172_have_angle = 0;

    stick = tnx_v172_joy_angle(&g_v172_angle);

    if (stick) {
        g_v172_have_angle = 1;
        desiredDeg = g_v172_angle * 180.0f / 3.14159265358979f;
    }

    if (threatened) {
        picked = tnx_v172_best(px, py, &tx, &ty);

        if (!picked) picked = tnx_v196_freest(px, py, &tx, &ty);
        if (!picked && TNX_V216_FLEE) picked = tnx_v216_flee(px, py, &tx, &ty);

        if (picked) {
            if ((tx - px) * (tx - px) + (ty - py) * (ty - py) < 1.0f &&
                tnx_v216_flee(px, py, &tx, &ty)) {
                g_v216_dead_replaced++;
            }

            g_v172_tx = tx;
            g_v172_ty = ty;
            g_v172_moving = 1;
            g_v172_start_x = px;
            g_v172_start_y = py;
            g_v172_picks++;

            if (TNX_V172_JOY_WRITE) tnx_v172_write(tx - px, ty - py);
        }
    } else if (g_v172_moving && tnx_v172_passed(px, py)) {
        g_v172_moving = 0;
    } else if (g_v172_moving && stick) {
        float safe = tnx_v172_safe_angle(px, py, desiredDeg, &safeOk);

        if (!safeOk && TNX_V216_FLEE) {
            if (tnx_v216_flee(px, py, &g_v172_tx, &g_v172_ty)) g_v172_moving = 1;
        }

        if (safeOk) {
            float rad = safe * 3.14159265358979f / 180.0f;
            float ex = px + cosf(rad) * TNX_V172_EXTEND_DEFAULT;
            float ey = py + sinf(rad) * TNX_V172_EXTEND_DEFAULT;

            if (tnx_v172_valid_point(ex, ey)) {
                g_v172_tx = ex;
                g_v172_ty = ey;

                if (TNX_V172_JOY_WRITE) tnx_v172_write(cosf(rad), sinf(rad));
            }
        }
    }

    if (g_v172_logs < 24 && (g_v48_ticks % 60) == 0) {
        g_v172_logs++;

        tnx_logf("v172 dodge segs=%d threatened=%d picked=%d target=(%.0f,%.0f) dist=%.0f stick=%d "
                 "angle=%.1f write=%d moving=%d - the threat segments start where each shot is NOW "
                 "and run along its own flight, so a shot that already passed is behind the segment "
                 "and not a reason to run; the directions are walked outward from the stick angle so "
                 "a safe heading near the one the player holds wins; every write is off in this build",
                 g_v172_seg_count, threatened, picked, (double)g_v172_tx, (double)g_v172_ty,
                 (double)sqrtf((g_v172_tx - px) * (g_v172_tx - px) +
                               (g_v172_ty - py) * (g_v172_ty - py)),
                 stick, (double)desiredDeg, TNX_V172_JOY_WRITE, g_v172_moving);
    }

    tnx_v216_predict(ownX, ownY, g_v172_tx, g_v172_ty);

    return picked;
}

void tnx_autododge_v48(void) {
    tnx_v146_phase("dodge-enter");

    tnx_v171_input_release();

    tnx_v174_stick(0, 0.0f, 0.0f);

    tnx_v174_route(g_v160_active);

    tnx_v189_drift();

    tnx_v198_state();

    if (TNX_V225_DIAG_EVERY <= 0 || (g_v48_ticks % (uint64_t)TNX_V225_DIAG_EVERY) == 0) {
        uint64_t diag0 = tnx_v213_us();

        uint64_t slot = (g_v48_ticks / (uint64_t)TNX_V225_DIAG_EVERY) % 4;

        if (slot == 0) tnx_v193_core();
        else if (slot == 1) tnx_v196_dump();
        else if (slot == 2) tnx_v179_census();
        else tnx_v172_probe();

        g_v225_diag_us = tnx_v213_us() - diag0;

        if (g_v225_diag_us > g_v225_diag_max_us) g_v225_diag_max_us = g_v225_diag_us;
    }

    tnx_v177_paircal();

    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
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

    g_v138_dodge_calls++;

    if (g_v138_dodge_calls <= TNX_V138_CALL_LOGS ||
        (g_v138_dodge_calls % TNX_V138_CALL_EVERY) == 0) {
        tnx_logf("v138 dodge CALLED n=%llu base=%p scene=%p container=%p array=%p count=%d hop=%d "
                 "gidFloor=%d gidMax=%d playerMax=%d - printed before every early return and keyed "
                 "on the number of calls and not on a tick counter, because the v137 run printed no "
                 "probe line at all and the two possible reasons, a gate before the line and a "
                 "counter that never advanced, cannot be told apart from the absence of a line",
                 (unsigned long long)g_v138_dodge_calls, (void *)g_base, (void *)g_scene_object,
                 (void *)g_players_object, (void *)g_players_array, g_players_count, g_v82_hop_chosen,
                 TNX_V75_GID_FLOOR, TNX_V75_GID_MAX, TNX_V138_PLAYER_GID_MAX);
    }

    if (!g_base) return;

    if (g_v138_dodge_calls <= TNX_V138_CALL_LOGS ||
        (g_v138_dodge_calls % TNX_V138_CALL_EVERY) == 0) {
        uintptr_t probeOwn = 0;
        int32_t probeGid = 0;
        int32_t probeTeam = 0;
        int32_t probeCount = 0;

        g_v135_probe_tick = g_v50_ticks;

        tnx_v134_own_by_min_gid(g_v142_tick_array, g_v142_tick_count, &probeOwn, &probeGid);

        if (probeOwn) tnx_read_i32(probeOwn + TNX_OBJ_TEAM_OFF, &probeTeam);
        if (g_players_object) tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &probeCount);

        {
            int listIdx = -1;
            const char *listFrom = "none";
            int32_t listGid = -1;

            if (tnx_v134_own_from_list(g_dodge_probe_list, g_dodge_probe_usable, &listIdx, &listFrom)) {
                listGid = g_dodge_probe_list[listIdx].gid;
            }

            tnx_logf("v135 dodge list usable=%d from=%s idx=%d gid=%d minGidSeen=%d chosenGid=%d "
                     "chosenIdx=%d - the resolver runs on the very array the walk collected and "
                     "reports which entry it picked, so a disagreement between the smallest id seen "
                     "and the id chosen is visible in one line instead of being inferred",
                     g_dodge_probe_usable, listFrom, listIdx, listGid, probeGid, listGid, listIdx);
        }

        tnx_logf("v135 dodge probe tick=%llu frames=%llu scene=%p container=%p array=%p count=%d "
                 "hop=%d own=%p ownGid=%d ownTeam=%d coordOk=%d coordUsable=%d writeTest=%d - this "
                 "line is printed before every early return of the dodge, so 'the dodge did not run' "
                 "can never again be concluded from the absence of a log line; in the v134 run the "
                 "dodge wrote nothing and said nothing, and it took a manual read of the resolver to "
                 "learn that the container globals and the walked list disagreed",
                 (unsigned long long)g_v50_ticks, (unsigned long long)g_v48_ticks,
                 (void *)g_scene_object, (void *)g_players_object, (void *)g_players_array,
                 probeCount, g_v82_hop_chosen, (void *)probeOwn, probeGid, probeTeam,
                 g_v47_coord_ok, g_v47_coord_usable, TNX_V129_MODE);
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
        g_v54_no_source_passes++;

        if (g_v54_no_source_passes >= 5 && !g_v54_route_logged) {
            g_v54_route_logged = 1;

            tnx_logf("v100 route: five passes with no source at all - mode=%p manager=%p "
                     "objvote=%p trailBest=%p; the remaining path is the ClientInput route, and its "
                     "hooks report separately (E5 setClientPredictionMoveTo, E6 sendMovement)",
                     (void *)g_scene_object, (void *)g_players_object, (void *)g_objvote_best_owner,
                     (void *)((g_trail_best >= 0 && g_trail_best < g_trail_count)
                                  ? g_trail[g_trail_best].manager
                                  : 0));
        }
    } else {
        g_v54_no_source_passes = 0;
    }

    if (!sourceIsMode && !g_players_object && source && strcmp(sourceKind, "trail") == 0 &&
        g_trail_best >= 0 && g_trail_best < g_trail_count && g_trail[g_trail_best].live == 0) {
        if ((g_v48_ticks % 900) == 1) {
            tnx_logf("v100 dodge idle ticks=%llu: best trail candidate has live=0, waiting "
                     "(trailBest=%p nonEmpty=%d count=%d stable=%d)",
                     (unsigned long long)g_v48_ticks, (void *)source,
                     g_trail[g_trail_best].nonEmpty, g_trail[g_trail_best].count,
                     g_trail[g_trail_best].stable);
        }
    }

    tnx_v113_frame_window();
    tnx_v116_frame();

    g_v48_ticks++;

    if (g_v92_wrote_valid && !g_v92_check_done &&
        (g_v48_ticks - g_v92_wrote_tick) >= TNX_V92_VERIFY_FRAMES) {
        int32_t nowX = 0;
        int32_t nowY = 0;

        if (g_scene_object && tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &nowX) &&
            tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &nowY)) {
            tnx_logf("v100 write verify: wrote=(%d,%d) now=(%d,%d) %s frames=%d testWrites=%llu - "
                     "kept means the engine left the two words alone, overwritten means the input "
                     "path rewrites them before anything is sent",
                     g_v92_wrote_x, g_v92_wrote_y, nowX, nowY,
                     (nowX == g_v92_wrote_x && nowY == g_v92_wrote_y) ? "kept" : "overwritten",
                     (int)(g_v48_ticks - g_v92_wrote_tick),
                     (unsigned long long)g_v93_test_writes);

            {
                void *array = NULL;
                int32_t count = 0;
                int shown = 0;

                if (g_players_object &&
                    tnx_read_ptr(g_players_object + TNX_MGR_ARRAY_OFF, &array) && array &&
                    tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &count)) {
                    for (int32_t i = 0; i < count && shown < TNX_V93_POS_DUMPS; i++) {
                        void *element = NULL;
                        int32_t px = 0;
                        int32_t py = 0;

                        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element)) break;
                        if (!element) continue;

                        tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px);
                        tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py);

                        shown++;

                        tnx_logf("v100 verify pos elem[%d] %p pos=(%d,%d)", i, element, px, py);
                    }
                }
            }
        }

        g_v92_check_done = 1;
    }

    if (g_v89_enter_tick != g_v50_ticks && (g_v50_ticks < 5 || (g_v50_ticks % 5) == 0)) {
        g_v89_enter_tick = g_v50_ticks;
        g_v48_entry_logs++;

        {
            int32_t oix = 0;
            int32_t oiy = 0;

            tnx_v116_interp(&oix, &oiy);

            tnx_logf("v116 dodge ENTERED tick=%llu frames=%llu mode=%p manager=%p hop=%d source=%p "
                     "kind=%s setpredFn=%d coordOk=%d usable=%d writes=%llu ownInterpX=%d ownInterpY=%d "
                     "modeVar=%d gate1=%d gate2=%d - ownInterpX/Y is the live own position read from "
                     "client+%#llx/+%#llx, so a dodge line with coordOk=0 can still carry a moving own "
                     "position",
                     (unsigned long long)g_v50_ticks, (unsigned long long)g_v48_ticks,
                     (void *)g_scene_object, (void *)g_players_object, g_v82_hop_chosen, (void *)source,
                     sourceKind, g_v47_setpred_state, g_v47_coord_ok, g_v47_coord_usable,
                     (unsigned long long)g_v47_writes, oix, oiy, tnx_v115_mode(),
                     (tnx_v115_mode() == TNX_V115_MODE_TARGET) ? 1 : 0, (tnx_v115_inner() == 1) ? 1 : 0,
                     (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
                     (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);
        }

        tnx_v116_interp_line();
        tnx_v90_gate_report(tnx_v90_slot_probe());
    }

    if (TNX_V93_TEST_WRITE && g_v47_setpred_state == 1 && g_scene_object && g_players_object) {
        int32_t cnt = 0;

        tnx_read_i32(g_players_object + TNX_MGR_COUNT_OFF, &cnt);

        if (cnt >= 2 && g_v93_test_tick != g_v50_ticks) {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;
            uintptr_t thisInner = 0;

            if (tnx_v91_mode_real((uintptr_t)g_scene_object, &thisVt, &thisChain, &thisInner)) {
                g_v93_test_tick = g_v50_ticks;
                g_v93_test_writes++;

                ((tnx_v47_setpred_t)g_v47_setpred)((void *)g_scene_object, TNX_V93_TEST_X,
                                                   TNX_V93_TEST_Y);

                g_v92_wrote_x = TNX_V93_TEST_X;
                g_v92_wrote_y = TNX_V93_TEST_Y;
                g_v92_own_pos_x = 0;
                g_v92_own_pos_y = 0;
                g_v92_wrote_tick = g_v48_ticks;
                g_v92_wrote_valid = 1;
                g_v92_check_done = 0;

                tnx_logf("v100 test write #%llu this=%p vt=%#llx chain=%p inner=%p container=%p "
                         "count=%d target=(%d,%d) - written without an own element, because the "
                         "question this run must answer is whether the actuator moves anything at "
                         "all", (unsigned long long)g_v93_test_writes, (void *)g_scene_object,
                         (unsigned long long)thisVt, (void *)thisChain, (void *)thisInner,
                         (void *)g_players_object, cnt, TNX_V93_TEST_X, TNX_V93_TEST_Y);

                return;
            }
        }
    }

    if (!source) {
        if ((g_v48_ticks % 900) == 1) {
            tnx_logf("v100 dodge idle ticks=%llu: no mode, no manager and no trail candidate yet "
                     "(bestLive=%d bestCount=%d) setpred=%d",
                     (unsigned long long)g_v48_ticks, g_manager_best_live,
                     g_manager_best_count, g_v47_setpred_state);
        }
        return;
    }

    if (g_v47_setpred_state < 0) {
        g_v47_setpred_state = tnx_v47_verify_setprediction();
        g_v47_setpred = g_v47_setpred_state ? (g_base + TNX_RVA_SETPREDICTION) : 0;
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        void *resolved = NULL;
        int changed = (g_v47_probe_object != source);
        int managerChanged = 0;
        int periodic = 0;

        if (sourceIsMode && g_v82_hop_chosen == 1 && g_v142_tick_object) {
            resolved = (void *)g_v142_tick_object;
        } else if (sourceIsMode) {
            if (!tnx_read_ptr(source + TNX_MODE_MANAGER_OFF, &resolved) || !resolved) {
                resolved = NULL;
            }
        } else {
            resolved = (void *)source;
        }

        managerChanged = ((uintptr_t)resolved != g_v48_manager);

        if (managerChanged && g_v88_walk_relogs < 6) {
            g_v88_walk_relogs++;

            tnx_logf("v100 walk manager=%p hop=%d source=%p kind=%s - the container is re-read from "
                     "the chain globals on this tick, so the walk follows scene+0x28 -> +%#llx "
                     "instead of stopping on the client", resolved, g_v82_hop_chosen,
                     (void *)source, sourceKind, (unsigned long long)TNX_V82_CLIENT_HOP_OFF);
        }

        {
            int32_t liveCount = 0;

            if (resolved) tnx_read_i32((uintptr_t)resolved + TNX_MGR_COUNT_OFF, &liveCount);

            if (resolved && liveCount > 0 && g_v82_hop_chosen == 1 &&
                (liveCount != g_v89_walk_count ||
                 (g_v89_walk_tick != g_v50_ticks && (g_v50_ticks % TNX_V89_WALK_EVERY) == 0))) {
                g_v89_walk_count = liveCount;
                g_v89_walk_tick = g_v50_ticks;
                periodic = 1;

                tnx_logf("v100 walk tick=%llu manager=%p count=%d - the walk is driven by the tick "
                         "and by the count, not by the array, so it reports every %d ticks while "
                         "the hop is %d even when the container itself has not changed",
                         (unsigned long long)g_v50_ticks, resolved, liveCount, TNX_V89_WALK_EVERY,
                         g_v82_hop_chosen);
            }
        }

        if (!g_v47_probe_done || changed || managerChanged || periodic ||
            (!g_v47_coord_ok && probeNow > g_v47_probe_last_ms + TNX_V47_REPROBE_MS)) {
            g_v47_probe_object = source;
            g_v47_probe_last_ms = probeNow;
            g_v48_manager = (uintptr_t)resolved;

            if (resolved) {
                int loud = (changed || managerChanged || !g_v47_probe_done);

                tnx_v48_probe((uintptr_t)resolved, g_scene_object, loud);

                if (loud) tnx_v48_discriminate((uintptr_t)resolved);
            } else {
                tnx_logf("v100 probe skipped: source %p (%s) has no manager at +0x%llx and hop=%d",
                         (void *)source, sourceIsMode ? "mode" : "manager",
                         (unsigned long long)TNX_MODE_MANAGER_OFF, g_v82_hop_chosen);
            }
        }
    }

    g_v47_ticks++;

    if (!g_v47_setpred_state) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v100 dodge idle: no verified actuator (fingerprint state=%d -- this is the "
                     "byte check of the function, not a write)", g_v47_setpred_state);
        }
        return;
    }

    {
        int gateOpen = (g_v47_coord_ok || g_v47_coord_usable >= TNX_V176_MIN_USABLE) ? 1 : 0;

        if (gateOpen != g_v176_gate_last) {
            g_v176_gate_last = gateOpen;
            g_v176_gate_logs++;

            if (g_v176_gate_logs <= 16) {
                tnx_logf("v176 gate %s: coord_ok=%d usable=%d distinct=%d minUsable=%d - the dodge runs "
                         "on usable objects now, because a container that holds only the player still "
                         "carries the player's own coordinates and the whole threat list, while the old "
                         "gate was coord_ok alone: the 17:12 run shows it going false for five seconds "
                         "in the middle of a firefight (usable=1 at 37.219, 39.020 and 40.401) with no "
                         "dodge line in exactly those seconds, and shots do not count because they are "
                         "rejected as non-players",
                         gateOpen ? "open" : "shut", g_v47_coord_ok, g_v47_coord_usable,
                         g_v47_coord_distinct, TNX_V176_MIN_USABLE);
            }
        }
    }

    if (!g_v47_coord_ok && g_v47_coord_usable < TNX_V176_MIN_USABLE) return;

    if (!g_scene_object) {
        if (g_v47_giveup_logs < 9) {
            g_v47_giveup_logs++;
            tnx_logf("v100 dodge idle: coordinates confirmed but the mode is unknown, so the "
                     "actuator has no `this` -- nothing written");

            if (!g_v59_idle_probe_logged) {
                g_v59_idle_probe_logged = 1;

                tnx_logf("v100 dodge idle probe modeCandidate=%p vt=%#llx whyRejected=%s hits=%d "
                         "fromChain=%d", (void *)g_v59_last_cand,
                         (unsigned long long)g_v59_last_vt,
                         g_v59_last_why[0] ? g_v59_last_why : "none-seen", g_v59_chain_hits,
                         g_v59_mode_from_chain);
            }
        }
        return;
    }

    memset(objects, 0, sizeof(objects));

    tnx_v146_phase("collect");

    usable = tnx_v48_collect(g_v48_manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    if (usable < TNX_V186_MIN_USABLE) {
        if ((g_v48_ticks % 60) == 0) {
            tnx_logf("v186 dodge idle: %d usable object(s) and this build needs %d - the old floor was "
                     "two, so a container holding only the player switched the dodge off completely "
                     "while shots were in the air, which is the 19:18 run where the census reads "
                     "players=1 shots=6 with no dodge line at all", usable, TNX_V186_MIN_USABLE);
        }

        return;
    }

    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &predictX)) predictX = 0;
    if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) predictY = 0;

    tnx_v91_own_scan();

    {
        const char *ownFrom = "none";

        if (!tnx_v183_own_latch(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_v128_resolve_own(objects, usable, &ownIndex, &ownFrom) &&
            !tnx_v91_resolve_own(objects, usable, &ownIndex, &ownFrom)) {
            if (g_v47_giveup_logs < 6 || (g_v48_ticks % 60) == 0) {
                g_v47_giveup_logs++;

                tnx_logf("v100 dodge idle: no own element - the scan found nothing at scanIndex=%d "
                         "scanPtr=%p and the prediction fallback (%d,%d) found nothing either, "
                         "usable=%d", g_v91_own_index, (void *)g_v91_own_ptr, predictX, predictY,
                         usable);
            }

            return;
        }

        tnx_v145_publish_own(objects[ownIndex].object, ownFrom);

        if (g_v144_own_logs < 8) {
            uintptr_t ownVt = 0;
            uintptr_t ownCls = 0;

            g_v144_own_logs++;

            tnx_v144_vt_ok((uintptr_t)g_v144_own_elem, &ownVt);

            if (ownVt >= g_base) ownCls = ownVt - g_base;

            tnx_logf("v144 dodge own elem=%p vt=%p classRva=%#llx from=%s index=%d pos=(%d,%d) - "
                     "classRva is what the census classRva of the same element index has to match, "
                     "and the actuator uses this exact element or nothing",
                     (void *)g_v144_own_elem, (void *)ownVt, (unsigned long long)ownCls, ownFrom,
                     ownIndex, objects[ownIndex].x, objects[ownIndex].y);
        }

        if (!g_v91_own_logged) {
            g_v91_own_logged = 1;

            tnx_logf("v100 dodge own resolved from %s at +%#llx index=%d object=%p pos=(%d,%d) - "
                     "the scan is tried first and the prediction pair is only the fallback, so "
                     "the dodge and the gate line name the same element", ownFrom,
                     (unsigned long long)g_v91_own_off, ownIndex, objects[ownIndex].object,
                     objects[ownIndex].x, objects[ownIndex].y);
        }
    }

    if (TNX_V93_DEAD_FILTER && objects[ownIndex].dead) return;

    g_v182_own_elem = objects[ownIndex].object;

    ownTeam = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
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
            if (objects[i].gid < TNX_V179_PLAYER_GID) continue;
            if (objects[i].gid >= TNX_V179_SHOT_GID) continue;

            team = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
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

        g_v185_enemy_elem = bestEnemy;
    }

    for (int i = 0; i < usable; i++) {
        int32_t team = 0;
        float dx = 0.0f;
        float dy = 0.0f;
        float distance = 0.0f;
        float weight = 0.0f;

        if (i == ownIndex) continue;
        if (TNX_V93_DEAD_FILTER && objects[i].dead) continue;

        team = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                         : objects[i].teamNew;
        if (team == ownTeam) continue;

        threatsAlive++;

        if ((objects[i].activeFlag & 1) == 0) continue;

        dx = (float)(ownX - objects[i].x);
        dy = (float)(ownY - objects[i].y);
        distance = dx * dx + dy * dy;

        if (distance > DODGE_RANGE_SQ || distance < 1.0f) continue;

        weight = 1.0f / (sqrtf(distance) + 1.0f);
        escapeX += dx * weight;
        escapeY += dy * weight;
        threats++;
    }

    tnx_v169_death_signals((ownIndex >= 0 && ownIndex < usable) ? objects[ownIndex].object : 0, ownX,
                           ownY);

    if (TNX_V170_ELEM_RESET && ownIndex >= 0 && ownIndex < usable &&
        objects[ownIndex].object != g_v170_last_own) {
        if (g_v170_last_own && g_v170_elem_logs < 4) {
            g_v170_elem_logs++;

            tnx_logf("v170 own element changed %p -> %p at (%d,%d): the ladder, the heading, the write "
                     "clock and the issued flag are cleared, because a respawn or a different element "
                     "carries none of the state the last life built",
                     (void *)g_v170_last_own, (void *)objects[ownIndex].object, ownX, ownY);
        }

        g_v170_last_own = objects[ownIndex].object;
        g_v167_stage = 0;
        g_v167_stuck = 0;
        g_v160_prev_idx = -1;
        g_v160_hold_until = 0;
        g_v160_last_danger = 0;
        g_v47_last_write_ms = 0;
        g_v152_issued = 0;
    }

    tnx_v167_alive(ownX, ownY);

    tnx_v146_phase("sidestep");

    g_v140_side_hits = 0;
    g_v140_side_projs = 0;

    {
        int32_t projCount = 0;
        int i = 0;

        if (g_v48_manager) tnx_read_i32(g_v48_manager + TNX_MGR_COUNT_OFF, &projCount);

        g_v167_own_team = (int)ownTeam;

        if (ownIndex >= 0 && ownTeam >= 0 && ownTeam <= TNX_V75_TEAM_MAX) g_v167_own_team_seen = 1;

        tnx_v189_roster(g_v182_own_elem, ownIndex, (int)ownTeam, objects, usable);

        if (tnx_v189_life(objects[ownIndex].object, ownX, ownY)) return;

        tnx_v140_proj_scan(g_v48_manager, projCount);

        g_v160_active = 0;
        g_v140_side_hits = 0;

        for (i = 0; i < TNX_V140_PROJ_MAX; i++) {
            if (g_v140_projs[i].elem) g_v140_side_projs++;
        }

        tnx_v174_threats();

        if (tnx_v172_decide(ownX, ownY)) {
            g_v160_active = 1;
            g_v140_side_hits = 1;
            g_v160_tx = (int32_t)g_v172_tx;
            g_v160_ty = (int32_t)g_v172_ty;
            g_v165_dir_x = g_v172_tx - (float)ownX;
            g_v165_dir_y = g_v172_ty - (float)ownY;
        }

        tnx_v189_drive();

        if (g_v160_active && g_v151_logs < TNX_V151_LOGS) {
            g_v151_logs++;

            tnx_logf("v160 dodge own=(%d,%d) target=(%d,%d) projectiles=%d liveThreats=%d dirIdx=%d "
                     "reach=%.0f engage=%.0f - %d directions are scored by the closest approach of the threat "
                     "against a point moving at the character speed along that direction, the score "
                     "carries a momentum term toward the previous direction, and the chosen heading "
                     "is locked for %d ms inside a band of %.0f, which is what stops the character "
                     "sliding between two nearly equal directions",
                     ownX, ownY, g_v160_tx, g_v160_ty, g_v140_side_projs, g_v167_live_threats,
                     g_v160_prev_idx, (double)TNX_V160_REACH, (double)TNX_V160_ENGAGE, TNX_V160_DIRS,
                     TNX_V160_LOCK_MS, (double)TNX_V160_KEEP_BAND);
        }
    }

    if (!g_v140_side_hits && (g_v167_proj_own + g_v167_proj_other) > 0 && (g_v48_ticks % 240) == 0) {
        tnx_logf("v169 no shot survived the filters: tracked=%d ownTeam=%d flewAway=%d cannotReach=%d - "
                 "the ring had nothing left to dodge, so a dodge that stops while shots are in the "
                 "air is read from this line first", g_v167_proj_own + g_v167_proj_other,
                 g_v167_proj_own, g_v167_drop_along, g_v167_drop_reach);
    }

    if (threats == 0 && g_v140_side_hits == 0) {
        if (g_v47_ticks % 256 == 0) {
            tnx_logf("v100 live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
                     "enemiesActive=%d enemiesInRange=0 projSeen=%d projOnRay=0 writes=%llu "
                     "threatsTotal=%llu",
                     (unsigned long long)g_v47_ticks, ownX, ownY, ownTeam, predictX, predictY,
                     threatsAlive, threats, g_v140_side_projs, (unsigned long long)g_v47_writes,
                     (unsigned long long)g_v47_threat_ticks);
        }
        return;
    }

    g_v47_threat_ticks++;

    {
        float length = sqrtf(escapeX * escapeX + escapeY * escapeY);
        uint64_t now = 0;
        int targetX = 0;
        int targetY = 0;
        float step = DODGE_STEP;

        if (length > 0.0001f) {
            escapeX /= length;
            escapeY /= length;
        } else if (!g_v160_active) {
            return;
        }

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        targetX = ownX + (int)(escapeX * step);
        targetY = ownY + (int)(escapeY * step);

        if (g_v160_active) {
            targetX = g_v160_tx;
            targetY = g_v160_ty;
        }

        if (TNX_V170_STEP > 0.0f) {
            float sdx = (float)(targetX - ownX);
            float sdy = (float)(targetY - ownY);
            float slen = sqrtf(sdx * sdx + sdy * sdy);

            if (slen > TNX_V170_STEP) {
                if (g_v170_step_logs < 1) {
                    g_v170_step_logs++;

                    tnx_logf("v178 step cut to %.0f units: the request was %.0f units away; a distance "
                             "to a point is not a per frame step and the engine walks toward its target "
                             "at its own speed, so the old cap of twenty was six times smaller than the "
                             "request the dodge itself makes and left the engine almost nothing to walk "
                             "toward - which is the barely moving slide the user reports - while the cap "
                             "itself stays so that a far pick cannot turn into a glide; the 17:45 run "
                             "shows the character covering about thirteen units in sixteen milliseconds, "
                             "so a full walk is near %.0f units a second at sixty frames and this cap "
                             "sits just inside that",
                             (double)TNX_V170_STEP, (double)slen, (double)(13.0f * 60.0f));
                }

                targetX = ownX + (int)(sdx / slen * TNX_V170_STEP);
                targetY = ownY + (int)(sdy / slen * TNX_V170_STEP);
            }
        }

        tnx_v162_clamp(&targetX, &targetY);

        if (g_v167_stage >= TNX_V171_STAGE_POSITION && g_v140_side_hits > 0 && g_v152_issued &&
            targetX == g_v152_last_tx && targetY == g_v152_last_ty) {
            return;
        }

        if (now < g_v47_last_write_ms + (uint64_t)(g_v140_side_hits > 0
                ? TNX_V151_THREAT_MIN_MS : TNX_V47_DODGE_MIN_MS)) {
            return;
        }

        g_v47_last_write_ms = now;

        if (g_v140_side_hits > 0) {
            g_v152_last_tx = targetX;
            g_v152_last_ty = targetY;
            g_v152_issued = 1;
        }

        if (g_v140_side_hits > 0 && g_v151_logs < TNX_V151_LOGS) {
            g_v151_logs++;

            tnx_logf("v151 threat write own=(%d,%d) target=(%d,%d) onRay=%d step=%.0f gap=%d of "
                     "shots dropped: %d flew away, %d could not reach - the escape is the heading "
                     "the ring scored best against the live threats, and the two counts are the "
                     "shots the reference's own filters removed before scoring",
                     ownX, ownY, targetX, targetY, g_v140_side_hits, (double)step,
                     TNX_V151_THREAT_MIN_MS, g_v167_drop_along, g_v167_drop_reach);

            tnx_logf("v160 write target=(%d,%d) own=(%d,%d) held=%d dirIdx=%d - the "
                     "heading and the target are one decision, the target is only reissued when "
                     "the locked heading changes, so the input stream carries one direction "
                     "instead of a per frame corrected position", targetX, targetY, ownX, ownY,
                     g_v160_active, g_v160_prev_idx);

        }

        if (targetX > TNX_V47_COORD_ABS_MAX) targetX = TNX_V47_COORD_ABS_MAX;
        if (targetX < -TNX_V47_COORD_ABS_MAX) targetX = -TNX_V47_COORD_ABS_MAX;
        if (targetY > TNX_V47_COORD_ABS_MAX) targetY = TNX_V47_COORD_ABS_MAX;
        if (targetY < -TNX_V47_COORD_ABS_MAX) targetY = -TNX_V47_COORD_ABS_MAX;

        {
            uintptr_t thisVt = 0;
            uintptr_t thisChain = 0;
            uintptr_t thisInner = 0;

            if (!tnx_v91_mode_real((uintptr_t)g_scene_object, &thisVt, &thisChain, &thisInner)) {
                if (g_v50_setpred_blocked_logs < 6) {
                    g_v50_setpred_blocked_logs++;

                    tnx_logf("v100 setprediction BLOCKED: this=%p vt=%#llx [this+%#llx]=%p "
                             "[chain+%#llx]=%p container=%p -- the chain does not reach the walked "
                             "container, nothing written", (void *)g_scene_object,
                             (unsigned long long)thisVt, (unsigned long long)TNX_MODE_MANAGER_OFF,
                             (void *)thisChain, (unsigned long long)TNX_V82_CLIENT_HOP_OFF,
                             (void *)thisInner, (void *)g_players_object);
                }

                return;
            }

            if (g_v47_writes == 0) {
                tnx_logf("v140 about to write: scene=%p vt=%#llx chain=%p manager=%p target=(%d,%d) "
                         "mode=%p actRva=%#llx leafRva=%#llx - the leaf %#llx is only a fallback, its "
                         "only caller in the image is the deserializer at 0xa26520, so a write that "
                         "lands there is stored and never consumed",
                         (void *)g_scene_object, (unsigned long long)thisVt, (void *)thisChain,
                         (void *)g_v48_manager, targetX, targetY, (void *)g_v144_own_elem,
                         (unsigned long long)TNX_V140_MODEPAIR_RVA,
                         (unsigned long long)TNX_RVA_SETPREDICTION,
                         (unsigned long long)TNX_RVA_SETPREDICTION);
            }
        }

        tnx_v146_phase("mode-write");

        tnx_v148_receiver_probe();

        if (!g_v160_active) {
            g_v165_dir_x = escapeX;
            g_v165_dir_y = escapeY;
        }

        tnx_v167_watch(ownX, ownY);

        g_v171_engaged_frame = 1;

        tnx_v171_write_input(g_v165_dir_x, g_v165_dir_y);

        if (g_v167_logs < 1) {
            g_v167_logs++;

            tnx_logf("v171 order: the engine input at scene+%#llx is the move now - type %d and the "
                     "sidestep vector written into the record the user named - so the walk cycle comes "
                     "from the stick and not from a position the renderer has to lerp towards. The raw "
                     "pair at +%#llx arrives at stage %d, and the applied pair plus the mode function "
                     "at stage %d, because those two start a new interpolation every frame and that is "
                     "the slide; own=(%d,%d) target=(%d,%d) skipped=%d",
                     (unsigned long long)TNX_MODE_INPUTMGR_OFF, TNX_V171_INPUT_TYPE,
                     (unsigned long long)TNX_V128_CTRL_RAW_X_OFF, TNX_V171_STAGE_STICK,
                     TNX_V171_STAGE_POSITION, ownX, ownY, targetX, targetY, g_v171_input_skips);
        }

        g_v47_writes++;

        g_v92_wrote_x = targetX;
        g_v92_wrote_y = targetY;
        g_v92_own_pos_x = ownX;
        g_v92_own_pos_y = ownY;
        g_v92_wrote_tick = g_v48_ticks;
        g_v92_wrote_valid = 1;
        g_v92_check_done = 0;

        if (g_v47_writes <= TNX_V47_LOG_FIRST || (g_v47_writes % TNX_V47_LOG_EVERY) == 0) {
            tnx_logf("v100 write #%llu own=(%d,%d) team=%d hostilesAlive=%d enemiesInRange=%d "
                     "step=(%d,%d) target=(%d,%d) predBefore=(%d,%d)",
                     (unsigned long long)g_v47_writes, ownX, ownY, ownTeam,
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

        tnx_logf("dodge team=%d i=%d obj=%p gid=%d team=%d dead=%d s88=%#llx s90=%#llx",
                 team, i, element, gid, t, dead,
                 (unsigned long long)s88, (unsigned long long)s90);
    }

    tnx_logf("dodge team=%d live=%d DISABLED - no coordinate source: slot 0x88 takes an "
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
