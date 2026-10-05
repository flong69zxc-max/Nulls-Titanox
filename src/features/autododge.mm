#include "titanox.h"
#include "data/chars_data.h"

#ifndef TNX_DODGE_PROJ_ONLY
#define TNX_DODGE_PROJ_ONLY 1
#endif

#ifndef TNX_HIT_MARGIN
#define TNX_HIT_MARGIN 60.0f
#endif

#ifndef TNX_DODGE_CLEAR_R
#define TNX_DODGE_CLEAR_R 96.0f
#endif

#ifndef TNX_RAGE_FORCE
#define TNX_RAGE_FORCE 0
#endif

#ifndef TNX_LOOKAHEAD_MAX
#define TNX_LOOKAHEAD_MAX 400.0f
#endif

#ifndef TNX_ENGAGE_NEAR
#define TNX_ENGAGE_NEAR 24.0f
#endif

#ifndef TNX_JS_DODGE
#define TNX_JS_DODGE 1
#endif

#ifndef TNX_DIR_COUNT
#define TNX_DIR_COUNT 48
#endif

#ifndef TNX_HORIZON_S
#define TNX_HORIZON_S 1.0f
#endif

#ifndef TNX_MOMENTUM
#define TNX_MOMENTUM 100.0f
#endif

#ifndef TNX_WALL_PENALTY
#define TNX_WALL_PENALTY 9000.0f
#endif

#ifndef TNX_JS_CLEAR_STEPS
#define TNX_JS_CLEAR_STEPS 4
#endif

#ifndef TNX_PROJ_LIFE_MS
#define TNX_PROJ_LIFE_MS 1200.0f
#endif

#ifndef TNX_OVERSHOOT
#define TNX_OVERSHOOT 220.0f
#endif

#ifndef TNX_FREEST_RADII
#define TNX_FREEST_RADII 3
#endif

#ifndef TNX_FREEST_LOGS
#define TNX_FREEST_LOGS 6
#endif

#ifndef TNX_BODY_GAIN
#define TNX_BODY_GAIN 0.0f
#endif

#ifndef TNX_ETA_PENALTY
#define TNX_ETA_PENALTY 100000.0f
#endif

#ifndef TNX_JS_NOPREDICT
#define TNX_JS_NOPREDICT 0
#endif

#ifndef TNX_GEOM
#define TNX_GEOM 1
#endif

#ifndef TNX_GEOM_LOGS
#define TNX_GEOM_LOGS 6
#endif

#ifndef TNX_RADIUS_MIN
#define TNX_RADIUS_MIN 0.0f
#endif

#ifndef TNX_RADIUS_MAX
#define TNX_RADIUS_MAX 600.0f
#endif

#ifndef TNX_RADIUS_MARGIN
#define TNX_RADIUS_MARGIN 8.0f
#endif

#ifndef TNX_CAL_OFF_LO
#define TNX_CAL_OFF_LO 0x20
#endif

#ifndef TNX_CAL_OFF_HI
#define TNX_CAL_OFF_HI 0x120
#endif

#ifndef TNX_CAL_STEP
#define TNX_CAL_STEP 4
#endif

#ifndef TNX_CAL_TOL
#define TNX_CAL_TOL 0.06f
#endif

#ifndef TNX_CONTACT_LOGS
#define TNX_CONTACT_LOGS 8
#endif

#ifndef TNX_SNAP
#define TNX_SNAP 1
#endif

#ifndef TNX_SNAP_MAG
#define TNX_SNAP_MAG 600.0f
#endif

#ifndef TNX_SNAP_LOGS
#define TNX_SNAP_LOGS 8
#endif

#ifndef TNX_SIDE_FLIP
#define TNX_SIDE_FLIP 1
#endif

#ifndef TNX_SIDE_STALE
#define TNX_SIDE_STALE 45
#endif

#ifndef TNX_CAL_TICKS
#define TNX_CAL_TICKS 6
#endif

#ifndef TNX_CAL_MISS
#define TNX_CAL_MISS 40
#endif

#ifndef TNX_WALL_LOGS
#define TNX_WALL_LOGS 8
#endif

#ifndef TNX_TEAM_LOGS
#define TNX_TEAM_LOGS 6
#endif

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

int g_state = TNX_STATE_INIT;

int g_pl_n = 0;

int32_t g_pl_x[TNX_PLAYER_MAX];

int32_t g_pl_y[TNX_PLAYER_MAX];

int32_t g_pl_team[TNX_PLAYER_MAX];

int32_t g_pl_mine[TNX_PLAYER_MAX];

int g_mate_n = 0;

int32_t g_mate_x[TNX_MATE_MAX];

int32_t g_mate_y[TNX_MATE_MAX];

int g_own_x = 0;

int g_own_y = 0;

int g_own_team_4 = -1;

int g_attrib_hits = 0;

int g_attrib_miss = 0;

int g_attrib_logs = 0;

int g_block_hits = 0;

int g_label_builds = 0;

int g_team_trust = 1;

int32_t g_own_team_5 = -1;

int32_t g_enemy_x[TNX_PLAYER_MAX];

int32_t g_enemy_y[TNX_PLAYER_MAX];

int g_enemy_n = 0;

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

uint64_t g_gate_writes = 0;

int g_flag_logs = 0;

uint64_t g_dead_picks = 0;

const char *tnx_state_name(void) {
    if (g_state == TNX_STATE_DEAD) return "DEAD";
    if (g_state == TNX_STATE_RESPAWN) return "respawn";
    if (g_state == TNX_STATE_ALIVE) return "alive";

    return "init";
}

int tnx_team_at(const tnx_obj_t *objects, int index) {
    if (!objects || index < 0) return -1;

    return (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[index].teamOld
                                                     : objects[index].teamNew;
}

void tnx_roster(uintptr_t ownElem, int ownIndex, int ownTeam,
                            const tnx_obj_t *objects, int usable) {
    int i = 0;
    int matesBefore = g_mate_n;
    int ownSide = 0;
    int hist[TNX_PLAYER_MAX];
    int hn = 0;

    g_pl_n = 0;
    g_mate_n = 0;
    g_enemy_n = 0;
    g_own_team_4 = ownTeam;
    g_own_team_5 = ownTeam;
    g_team_trust = 1;

    for (i = 0; i < usable && g_pl_n < TNX_PLAYER_MAX; i++) {
        int32_t team = 0;
        int isOwn = 0;
        int h = 0;

        if (objects[i].gid < TNX_PLAYER_GID) continue;
        if (objects[i].gid >= TNX_SHOT_GID) continue;

        team = tnx_team_at(objects, i);
        isOwn = (ownElem && objects[i].object == ownElem) ? 1
                                                          : ((!ownElem && i == ownIndex) ? 1 : 0);

        g_pl_x[g_pl_n] = objects[i].x;
        g_pl_y[g_pl_n] = objects[i].y;
        g_pl_team[g_pl_n] = team;
        g_pl_mine[g_pl_n] = isOwn;
        g_pl_gid[g_pl_n] = objects[i].gid;
        g_pl_sx[g_pl_n] = objects[i].x;
        g_pl_sy[g_pl_n] = objects[i].y;
        g_pl_spawned[g_pl_n] = 0;
        g_pl_n++;

        if (isOwn) {
            g_own_x = objects[i].x;
            g_own_y = objects[i].y;

            continue;
        }

        for (h = 0; h < hn; h++) {
            if (hist[h] == team) break;
        }

        if (h == hn && hn < TNX_PLAYER_MAX) {
            hist[hn++] = team;
        }

        if (team != ownTeam) continue;

        ownSide++;

        if (g_mate_n >= TNX_MATE_MAX) continue;

        g_mate_x[g_mate_n] = objects[i].x;
        g_mate_y[g_mate_n] = objects[i].y;
        g_mate_n++;
    }

    ownSide++;

    if (g_pl_n >= 4 && (ownSide > (g_pl_n / 2) || hn < 2)) {
        g_team_trust = 0;
        g_mate_n = 0;
    }

    {
        int ownSpawn = -1;
        int k = 0;

        for (k = 0; k < g_pl_n; k++) {
            if (g_pl_mine[k]) { ownSpawn = k; break; }
        }

        g_mates = 0;
        g_enemies = 0;

        if (ownSpawn >= 0) {
            for (k = 0; k < g_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (g_pl_mine[k]) continue;

                dx = (float)(g_pl_x[k] - g_pl_x[ownSpawn]);
                dy = (float)(g_pl_y[k] - g_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_CLUSTER) g_mates++;
                else g_enemies++;
            }
        }

        {
            int same = 1;

            for (k = 1; k < g_pl_n; k++) {
                if (g_pl_team[k] != g_pl_team[0]) same = 0;
            }

            if (g_pl_n > 1 && same && g_team_trust) {
                g_team_trust = 0;

                if (g_roster_logs < TNX_TEAM_LOGS) {
                    TNX_LOGX("teambyte players=%d value=%d same=%d trust=%d - every player carries "
                             "the same team byte, so that field holds no side information in this "
                             "mode and one player being read as a mate is not evidence of anything; "
                             "the byte is dropped and the side is taken from the spawn cluster "
                             "instead, which is the same rule the byte-only path uses when it "
                             "already distrusts itself",
                             g_pl_n, g_pl_team[0], same, g_team_trust);
                }
            }
        }

        if (!g_team_trust) {
            int m = 0;
            int e = 0;

            g_mate_n = 0;
            g_enemy_n = 0;

            for (k = 0; k < g_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (g_pl_mine[k]) continue;

                dx = (float)(g_pl_x[k] - g_pl_x[ownSpawn]);
                dy = (float)(g_pl_y[k] - g_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_CLUSTER) {
                    if (m < TNX_MATE_MAX) {
                        g_mate_x[m] = g_pl_x[k];
                        g_mate_y[m] = g_pl_y[k];
                        m++;
                    }
                } else if (e < TNX_PLAYER_MAX) {
                    g_enemy_x[e] = g_pl_x[k];
                    g_enemy_y[e] = g_pl_y[k];
                    e++;
                }
            }

            g_mate_n = m;
            g_enemy_n = e;

            if (g_cluster_logs < TNX_TRUST_LOGS) {
                g_cluster_logs++;

                TNX_LOGX("side by cluster players=%d ownSpawn=(%d,%d) mates=%d enemies=%d "
                         "byteMates=%d byteEnemies=%d radius=%.0f - the team byte is not believed, so "
                         "the side comes from where the players came from: a team spawns together and "
                         "the two spawn areas are far apart, which is a signal that does not depend on "
                         "a field the engine may not even set in this mode",
                         g_pl_n, g_pl_x[ownSpawn], g_pl_y[ownSpawn], m, e,
                         ownSide - 1, g_pl_n - ownSide, (double)TNX_CLUSTER);
            }
        } else if (g_cluster_logs < TNX_TRUST_LOGS) {
            g_cluster_logs++;

            TNX_LOGX("side agreement byte=%d/%d cluster=%d/%d agree=%d players=%d - both answers "
                     "are printed every time the roster changes, so a byte that drifts and a cluster "
                     "that misreads are told apart instead of guessed at", g_mate_n,
                     g_enemy_n, g_mates, g_enemies, g_agree, g_pl_n);
        }
    }

    if (g_team_trust) {
        for (i = 0; i < g_pl_n && g_enemy_n < TNX_PLAYER_MAX; i++) {
            if (g_pl_mine[i]) continue;
            if (g_pl_team[i] == ownTeam) continue;

            g_enemy_x[g_enemy_n] = g_pl_x[i];
            g_enemy_y[g_enemy_n] = g_pl_y[i];
            g_enemy_n++;
        }
    }

    g_agree = (g_mates == g_mate_n && g_enemies == g_enemy_n) ? 1 : 0;

    if (g_mate_n != matesBefore || g_roster_logs < TNX_ROSTER_LOGS) {
        g_roster_logs++;

        TNX_LOGX("roster players=%d mates=%d enemies=%d teams=%d/%d/%d/%d/%d/%d own=(%d,%d) "
                 "ownMatched=%d ownTeam=%d trust=%d blocked=%d - the raw table is printed because "
                 "the previous line printed only the counts and a 3v3 came back as five teammates "
                 "with own at the origin: players=6 mates=5 ownTeam=0 own=(0,0). own is matched by "
                 "element now, and the side is only believed when it is a minority of the container, "
                 "because a team is a minority in a team match; when it is not, trust goes to zero "
                 "and both the mate block and the own shot filter stand down, so a broken team byte "
                 "can no longer leave the ring with only the enemy to run into",
                 g_pl_n, g_mate_n, g_enemy_n,
                 g_pl_team[0], g_pl_team[1], g_pl_team[2], g_pl_team[3],
                 g_pl_team[4], g_pl_team[5], g_own_x, g_own_y,
                 g_pl_mine[0] | g_pl_mine[1] | g_pl_mine[2] | g_pl_mine[3] |
                     g_pl_mine[4] | g_pl_mine[5],
                 g_own_team_5, g_team_trust, g_block_hits);
    }

    if (g_trust_logs < TNX_TRUST_LOGS && !g_team_trust) {
        g_trust_logs++;

        TNX_LOGX("side read distrusted players=%d ownSide=%d distinctTeams=%d - more than half "
                 "of the players came back on own's side, or every player came back on one team, "
                 "which no real match produces; the mate block is off and the own shot filter is off "
                 "until the next roster, so the dodge reacts to every moving shot and refuses no "
                 "ground, instead of refusing all of it", g_pl_n, ownSide, hn);
    }
}

int tnx_own_ok(int32_t x, int32_t y) {
    if (x == 0 && y == 0) return 0;
    if (x < -100000 || x > 100000) return 0;
    if (y < -100000 || y > 100000) return 0;

    return 1;
}

int tnx_enemy_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (!g_team_trust || g_enemy_n <= 0) return 0;

    for (i = 0; i < g_enemy_n; i++) {
        float ex = (float)g_enemy_x[i];
        float ey = (float)g_enemy_y[i];
        float dc = sqrtf((x - ex) * (x - ex) + (y - ey) * (y - ey));
        float dOwn = sqrtf((ownX - ex) * (ownX - ex) + (ownY - ey) * (ownY - ey));

        if (dc < TNX_ENEMY_HARD) return 1;
        if (dOwn > TNX_ENEMY_FAR && dc < dOwn - TNX_ENEMY_MARGIN) return 1;
    }

    return 0;
}

int tnx_mate_blocked(float x, float y) {
    int i = 0;
    float r2 = TNX_MATE_CLEAR * TNX_MATE_CLEAR;

    if (!g_team_trust) return 0;
    if (g_mate_n <= 0) return 0;

    for (i = 0; i < g_mate_n; i++) {
        float dx = x - (float)g_mate_x[i];
        float dy = y - (float)g_mate_y[i];

        if (dx * dx + dy * dy <= r2) return 1;
    }

    return 0;
}

int tnx_own_side_spawn(int32_t sx, int32_t sy) {
    int i = 0;
    int best = -1;
    float bestD = 0.0f;
    float secondD = -1.0f;

    if (g_own_team_4 < 0) return -1;
    if (g_pl_n <= 0) return -1;

    for (i = 0; i < g_pl_n; i++) {
        float dx = (float)sx - (float)g_pl_x[i];
        float dy = (float)sy - (float)g_pl_y[i];
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
    if (bestD > TNX_ATTRIB_R2) return -1;
    if (secondD >= 0.0f && bestD * TNX_ATTRIB_MARGIN > secondD) return -1;

    return (g_pl_team[best] == g_own_team_4) ? 1 : 0;
}

int g_prev_idx = -1;

uint64_t g_hold_until = 0;

uint64_t g_last_danger = 0;

int32_t g_tx = 0;

int32_t g_ty = 0;

int g_active_2 = 0;

tnx_seg_t g_seg[TNX_SEG_MAX];

int g_seg_count = 0;

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

uintptr_t tnx_bs(void) {
    return tnx_client();
}

int tnx_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by,
                             uint32_t *mode, float *cs, float *sn) {
    int32_t m = 0;

    if (!bs) return 0;

    if (!tnx_read_f32(bs + TNX_BS_AX, ax)) return 0;
    if (!tnx_read_f32(bs + TNX_BS_AY, ay)) return 0;
    if (!tnx_read_f32(bs + TNX_BS_BX, bx)) return 0;
    if (!tnx_read_f32(bs + TNX_BS_BY, by)) return 0;

    *mode = 0;

    if (tnx_read_i32(bs + TNX_BS_MODE, &m)) *mode = (uint32_t)m;

    if (!tnx_read_f32(bs + TNX_BS_COS, cs)) *cs = 1.0f;
    if (!tnx_read_f32(bs + TNX_BS_SIN, sn)) *sn = 0.0f;

    return 1;
}

int tnx_joy_angle(float *outAngle) {
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

    if (!tnx_joy_read(tnx_bs(), &ax, &ay, &bx, &by, &mode, &cs, &sn)) return 0;
    if (mode != 2 && mode != 3) return 0;

    rx = (ax - bx) * cs + (ay - by) * sn;
    ry = (ay - by) * cs - (ax - bx) * sn;

    len = sqrtf(rx * rx + ry * ry);

    if (len < 0.001f) return 0;

    *outAngle = atan2f(-ry, rx);

    return 1;
}

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

float g_tti_min = 0.0f;

uint64_t g_crit_took = 0;

float g_shot_speed[TNX_PROJ_MAX];

uint64_t g_shot_logs = 0;

uint64_t g_commit_until = 0;

uint64_t g_stat_picks = 0;

uint64_t g_stat_side = 0;

uint64_t g_stat_commit = 0;

uint64_t g_stat_absorbed = 0;

uint64_t g_stat_dodged = 0;

uint64_t g_react_n = 0;

uint64_t g_react_sum = 0;

uint64_t g_react_min = 0;

uint64_t g_react_max = 0;

uint64_t g_last_stat = 0;

int g_track_gid[TNX_SEG_MAX];

int g_track_hit[TNX_SEG_MAX];

uint64_t g_bucket_abs[TNX_ADV_BUCKETS];

uint64_t g_bucket_n[TNX_ADV_BUCKETS];

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

uint64_t g_learn_win[3][3][2];

uint64_t g_learn_loss[3][3][2];

int g_shot_key[TNX_SEG_MAX];

int g_stat_near = 0;

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

void tnx_select(float px, float py) {
    float speed = g_walk_step * 60.0f;
    float reach = 0.0f;
    int i = 0;

    if (speed < 120.0f) speed = 120.0f;
    if (speed > 1200.0f) speed = 1200.0f;

    reach = speed * TNX_HORIZON;
    g_sel_n = 0;

    for (i = 0; i < g_seg_count && g_sel_n < TNX_SEL_MAX; i++) {
        const tnx_seg_t *seg = &g_seg[i];
        float d = tnx_seg_dist(px, py, seg->ax, seg->ay, seg->bx, seg->by);

        if (d > reach + seg->inflatedR) continue;

        g_sel[g_sel_n++] = i;
    }
}

uint64_t g_pos_skips = 0;

int tnx_drive(void) {
    uintptr_t ctrl = tnx_controller();

    tnx_measure();
    tnx_snapshot_3();
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

    if (g_active_2) {
        g_tx_3 = g_tx;
        g_ty_3 = g_ty;
        g_hold = g_ticks_3;
        held = 1;
    } else if (!g_crit_reaction && g_hold && (g_ticks_3 - g_hold) <= TNX_HOLD_TICKS) {
        held = 1;
    }

    if (!held) {
        float escapeX = 0.0f;
        float escapeY = 0.0f;

        if (!TNX_ESCAPE) {
            tnx_stick(0, 0.0f, 0.0f);

            return 0;
        }

        if (!tnx_own(&ownX, &ownY)) return 0;
        if (!tnx_own_ok(ownX, ownY)) return 0;

        if (!tnx_threatened((float)ownX, (float)ownY)) {
            tnx_stick(0, 0.0f, 0.0f);

            return 0;
        }

        if (!tnx_freest((float)ownX, (float)ownY, &escapeX, &escapeY)) {
            tnx_stick(0, 0.0f, 0.0f);

            return 0;
        }

        dx = escapeX - (float)ownX;
        dy = escapeY - (float)ownY;
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) {
            g_dead_picks++;
            tnx_stick(0, 0.0f, 0.0f);

            return 0;
        }

        g_escapes++;
        tnx_stick(1, (float)TNX_STICK_SIGN * dx, (float)TNX_STICK_SIGN * dy);
        tnx_precision(ownX, ownY, dx, dy, 1);

        return 1;
    }

    if (!tnx_own(&ownX, &ownY)) return 0;
    if (!tnx_own_ok(ownX, ownY)) return 0;

    dx = (float)(g_tx_3 - ownX);
    dy = (float)(g_ty_3 - ownY);
    len = sqrtf(dx * dx + dy * dy);

    if (len >= 0.0001f) {
        dx /= len;
        dy /= len;
        tnx_unblock((float)ownX, (float)ownY,
                        tnx_step(), &dx, &dy);
        dx *= len;
        dy *= len;
    }

    {
        float step = TNX_STEP_4;

        step = tnx_step();

        if (len > step) {
            dx = dx / len * step;
            dy = dy / len * step;
            len = step;
            g_clamped++;
        }
    }

    if (len < 0.0001f) {
        g_dead_picks++;
        tnx_stick(0, 0.0f, 0.0f);

        return 0;
    }

    {
        uintptr_t hctrl = tnx_controller();
        uint8_t hgate = 0;
        int32_t hid = -1;
        int human = 0;
        int threat = 0;

        if (hctrl) {
            tnx_read_bytes(hctrl + TNX_TOUCH_GATE_OFF, &hgate, sizeof(hgate));
            tnx_read_i32(hctrl + TNX_TOUCH_ID_OFF, &hid);
        }

        human = (hgate == 1 || hid >= 0) ? 1 : 0;

        if (TNX_HUMAN && g_human_2) human = 1;

        threat = g_active_2 ? 1 : 0;

        if (human) g_human++;

        if (threat || !human || !TNX_STICK_WHEN_FREE) {
            tnx_stick(1, (float)TNX_STICK_SIGN * dx, (float)TNX_STICK_SIGN * dy);
        } else {
            g_stick_skips++;
        }
    }

    tnx_precision(ownX, ownY, dx, dy, 0);

    tx = ownX + (int32_t)((double)dx / (double)len * (double)tnx_step());
    ty = ownY + (int32_t)((double)dy / (double)len * (double)tnx_step());

    if (TNX_QUIET) {
        g_queue_skips_2++;
        g_queue_calls++;
    } else if (!TNX_PAIR_ONLY) {
        if (TNX_STICK_ONLY) g_pos_skips++;
        else tnx_enqueue(tx, ty);
        g_queue_calls++;
    } else {
        g_queue_skips++;
    }

    if (!TNX_STICK_ONLY && !TNX_JS_NOPREDICT) {
        tnx_predict(tx, ty);
    }

    if (TNX_TOUCH_FLAG && ctrl) {
        uint8_t gateNow = 0;
        int32_t stateNow = 0;
        int32_t idNow = 0;

        tnx_read_bytes(ctrl + TNX_TOUCH_GATE_OFF, &gateNow, sizeof(gateNow));
        tnx_read_i32(ctrl + TNX_TOUCH_STATE_OFF, &stateNow);
        tnx_read_i32(ctrl + TNX_TOUCH_ID_OFF, &idNow);

        if (g_flag_logs < TNX_FLAG_LOGS) {
            g_flag_logs++;

            TNX_LOGX("touch gate=%d state=%d id=%d writes=%llu idWrites=%llu own=(%d,%d) applied=(%d,%d) - "
                      "gate is the byte the engine's own move function tests first, and this build reads "
                      "it but never writes it any more: setting it sends the engine down the touch "
                      "branch, which returns before the branch that reads the drag, so claiming a drag "
                      "was the opposite of driving one, state and id are the rest of the touch "
                      "bookkeeping, and applied is now only read back so this line can show the engine "
                      "moving it instead of this build",
                     gateNow, stateNow, idNow, (unsigned long long)g_gate_writes,
                     (unsigned long long)g_touchid_writes, ownX, ownY, appX, appY);
        }
    }

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &pairX);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &pairY);

    }

    if (g_stuck_logs < TNX_STUCK_LOG && g_engage_writes > 20 && !g_move_tick) {
        int i = 0;
        int near = -1;
        int within = 0;
        float nd = 1000000.0f;
        float slen = sqrtf(dx * dx + dy * dy);
        float dot = 0.0f;

        for (i = 0; i < g_pl_n; i++) {
            float bx = 0.0f;
            float by = 0.0f;
            float d = 0.0f;

            if (g_pl_mine[i]) continue;

            bx = (float)g_pl_x[i] - (float)ownX;
            by = (float)g_pl_y[i] - (float)ownY;
            d = sqrtf(bx * bx + by * by);

            if (d < nd) {
                nd = d;
                near = i;
            }

            if (d < slen) within++;
        }

        if (near >= 0 && slen > 1.0f) {
            float bx = (float)g_pl_x[near] - (float)ownX;
            float by = (float)g_pl_y[near] - (float)ownY;

            dot = (bx * dx + by * dy) / (sqrtf(bx * bx + by * by) * slen);
        }

        g_stuck_2++;
        g_stuck_logs++;

        TNX_LOGX("stuck writes=%llu own=(%d,%d) step=%.0f nearestBody=%.0f dot=%+.2f mine=%d "
                 "withinStep=%d pick=(%d,%d) - the body does not move although this build keeps "
                 "writing, which is what a character pressed against another player looks like: dot "
                 "near +1 means the step points at that body, withinStep counts the bodies closer "
                 "than the step", (unsigned long long)g_engage_writes, ownX, ownY, (double)slen,
                 (double)nd, (double)dot, (near >= 0) ? g_pl_mine[near] : -1, within, g_tx_3,
                 g_ty_3);
    }

    g_sent_dx = tx - ownX;
    g_sent_dy = ty - ownY;
    g_last_tx_2 = tx;
    g_last_ty_2 = ty;
    g_drive_ticks++;

    tnx_drive_note(ownX, ownY, tx, ty, appX, appY, pairX, pairY);

    if (g_active_2) {
        g_last_decision = g_ticks_3;
        g_decide_x = ownX;
        g_decide_y = ownY;
    }

    if (g_drive_logs < TNX_DRIVE_LOGS ||
        ((g_ticks_3 % 60) == 0 && g_drive_logs < 240)) {
        g_drive_logs++;

        TNX_LOGX("drive held=%d engaged=%d own=(%d,%d) pick=(%d,%d) sent=(%d,%d) step=%.0f "
                 "pair=(%d,%d) queue=%llu skipped=%llu pairOnly=%d holdTicks=%d - the step handed "
                 "to the client input is one frame of travel and not the pick, so the body is "
                 "walked instead of carried; a sent distance that has grown back to the pick means "
                 "something below put the uncapped target back", held, g_active_2, ownX, ownY,
                 g_tx_3, g_ty_3, tx, ty,
                 (double)sqrtf((float)(g_sent_dx * g_sent_dx +
                                       g_sent_dy * g_sent_dy)),
                 g_stick_x, g_stick_y, (unsigned long long)g_queue_calls,
                 (unsigned long long)g_queue_skips, TNX_PAIR_ONLY, TNX_HOLD_TICKS);
    }

    return 1;
}

int g_cand_now[TNX_CAND];

int g_cand_frame[TNX_CAND];

int g_cand_changes[TNX_CAND];

int g_cand_seen = 0;

int g_dead_slot = -1;

int g_dead_value = 0;

int g_pending = 0;

int g_pending_tick = 0;

int g_pre[TNX_CAND];

int32_t g_prev_x = 0;

int32_t g_prev_y = 0;

int g_prev_valid = 0;

int g_respawn_tick = 0;

int g_respawns = 0;

int g_life_logs = 0;

int g_signal_logs_2 = 0;

int g_learn_logs = 0;

void tnx_candidates(uintptr_t ownElem, int *out) {
    uint8_t deadByte = 0;
    int32_t ownAlive = -1;
    int32_t ctrlAlive = -1;
    uintptr_t ctrl = tnx_controller();

    out[0] = -1;
    out[1] = -1;
    out[2] = -1;

    if (ownElem && tnx_read_bytes(ownElem + TNX_DEAD_OFF, &deadByte, sizeof(deadByte))) {
        out[0] = (int)deadByte;
    }

    if (ownElem && tnx_read_i32(ownElem + TNX_OWN_ALIVE_OFF, &ownAlive)) out[1] = (int)ownAlive;

    if (ctrl && tnx_read_i32(ctrl + TNX_CTRL_ALIVE_OFF, &ctrlAlive)) out[2] = (int)ctrlAlive;
}

const char *tnx_cand_name(int slot) {
    if (slot == 0) return "own+d4";
    if (slot == 1) return "own+140";
    if (slot == 2) return "ctrl+f80";

    return "none";
}

void tnx_clear_life(void) {
    g_stage = 0;
    g_stuck = 0;
    g_active_2 = 0;
    g_prev_idx = -1;
    g_hold_until = 0;
    g_last_danger = 0;
    g_last_write_ms = 0;
    g_issued = 0;
    g_moving = 0;
    g_hold = 0;
    g_stick_hold = 0;
    g_stick_x = 0;
    g_stick_y = 0;
    g_prev_valid = 0;
}

void tnx_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py) {
    int i = 0;

    g_respawns++;
    g_state = TNX_STATE_RESPAWN;
    g_respawn_tick = (int)g_ticks_3;

    tnx_clear_life();

    g_pending = 1;
    g_pending_tick = (int)g_ticks_3;

    for (i = 0; i < TNX_CAND; i++) {
        g_pre[i] = g_cand_frame[i];
        g_cand_changes[i] = 0;
    }

    if (g_life_logs < TNX_LIFE_MAX_LOGS) {
        g_life_logs++;

        TNX_LOGX("RESPAWN #%d own=(%d,%d) from=(%d,%d) jump=%d cand=(%d,%d,%d) learned=%s=%d - "
                 "the character was teleported, which a walk cannot do, so this is the one life "
                 "event established without trusting a flag; the per life state is cleared here and "
                 "the candidates are held for %d frames to see which changed across the event",
                 g_respawns, x, y, px, py,
                 (int)sqrtf((float)((x - px) * (x - px) + (y - py) * (y - py))),
                 g_pre[0], g_pre[1], g_pre[2],
                 tnx_cand_name(g_dead_slot), g_dead_value, TNX_HOLD_FRAMES);
    }
}

int tnx_life(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    int i = 0;
    int changed = 0;
    int deadNow = 0;

    tnx_candidates(ownElem, g_cand_now);

    if (g_cand_seen) {
        for (i = 0; i < TNX_CAND; i++) {
            if (g_cand_now[i] != g_cand_frame[i]) {
                changed = 1;

                if (g_cand_changes[i] < 1000000) g_cand_changes[i]++;
            }
        }

        if (changed && g_signal_logs_2 < TNX_LIFE_MAX_LOGS) {
            g_signal_logs_2++;

            TNX_LOGX("signals own=(%d,%d) own+d4=%d own+140=%d ctrl+f80=%d learned=%s=%d - "
                     "printed on every change of any candidate, so a run that carries a death names "
                     "the flag even if the respawn learning never fires", ownX, ownY,
                     g_cand_now[0], g_cand_now[1], g_cand_now[2],
                     tnx_cand_name(g_dead_slot), g_dead_value);
        }
    }

    for (i = 0; i < TNX_CAND; i++) g_cand_frame[i] = g_cand_now[i];
    g_cand_seen = 1;

    if (g_pending && ((int)g_ticks_3 - g_pending_tick) >= TNX_HOLD_FRAMES) {
        int bestSlot = -1;
        int bestChanges = 0;

        g_pending = 0;

        for (i = 0; i < TNX_CAND; i++) {
            if (g_pre[i] < 0 || g_cand_now[i] < 0) continue;
            if (g_cand_now[i] == g_pre[i]) continue;
            if (bestSlot < 0 || g_cand_changes[i] < bestChanges) {
                bestSlot = i;
                bestChanges = g_cand_changes[i];
            }
        }

        if (bestSlot >= 0) {
            g_dead_slot = bestSlot;
            g_dead_value = g_pre[bestSlot];

            if (g_learn_logs < TNX_LEARN_LOGS) {
                g_learn_logs++;

                TNX_LOGX("death flag learned slot=%d %s dead=%d alive=%d changes=%d from the "
                         "respawn at tick=%d - this candidate changed across the teleport, held its "
                         "new value for %d frames, and moved %d times in this life, fewer than any "
                         "rival, so it is the flag a guard may use; until this line exists no guard "
                         "runs at all and nothing is held on a guess", bestSlot,
                         tnx_cand_name(bestSlot), g_pre[bestSlot],
                         g_cand_now[bestSlot], bestChanges, g_pending_tick,
                         TNX_HOLD_FRAMES, bestChanges);
            }
        }
    }

    if (g_prev_valid && tnx_own_ok(ownX, ownY) &&
        tnx_own_ok(g_prev_x, g_prev_y)) {
        int64_t jx = (int64_t)ownX - (int64_t)g_prev_x;
        int64_t jy = (int64_t)ownY - (int64_t)g_prev_y;

        if (jx * jx + jy * jy >= (int64_t)TNX_RESPAWN_JUMP * TNX_RESPAWN_JUMP) {
            tnx_respawn_event(ownX, ownY, g_prev_x, g_prev_y);
        }
    }

    g_prev_x = ownX;
    g_prev_y = ownY;
    g_prev_valid = 1;

    if (g_state == TNX_STATE_INIT) g_state = TNX_STATE_ALIVE;

    if (g_dead_slot >= 0 &&
        g_cand_now[g_dead_slot] == g_dead_value) deadNow = 1;

    if (deadNow) {
        if (g_state != TNX_STATE_DEAD) {
            g_state = TNX_STATE_DEAD;

            if (g_life_logs < TNX_LIFE_MAX_LOGS) {
                g_life_logs++;

                TNX_LOGX("own is DEAD own=(%d,%d) %s=%d - the learned flag says so, so the "
                         "dodge is held and nothing is written until it clears; the label carries "
                         "the same state on screen", ownX, ownY, tnx_cand_name(g_dead_slot),
                         g_dead_value);
            }
        }

        return 1;
    }

    if (g_state == TNX_STATE_DEAD) {
        tnx_clear_life();

        g_state = TNX_STATE_ALIVE;

        if (g_life_logs < TNX_LIFE_MAX_LOGS) {
            g_life_logs++;

            TNX_LOGX("own is alive again own=(%d,%d) %s=%d - the learned candidate left its "
                     "dead value, so the dodge resumes on a cleared life and cleared heading", ownX,
                     ownY, tnx_cand_name(g_dead_slot),
                     g_cand_now[g_dead_slot]);
        }

        return 0;
    }

    if (g_state == TNX_STATE_RESPAWN &&
        ((int)g_ticks_3 - g_respawn_tick) < TNX_RESPAWN_VISIBLE) {
        return 0;
    }

    g_state = TNX_STATE_ALIVE;

    return 0;
}

void tnx_drift(void) {
    int32_t ownX = 0;
    int32_t ownY = 0;

    if (!g_last_decision) return;
    if (g_drift_done == g_last_decision) return;
    if ((g_ticks_3 - g_last_decision) < 60) return;
    if ((g_ticks_3 - g_last_decision) > 240) return;
    if (!tnx_own(&ownX, &ownY)) return;
    if (g_drift_logs >= TNX_DRIVE_LOGS_2) return;

    g_drift_logs++;
    g_drift_done = g_last_decision;

    TNX_LOGX("drift after the last decision: frames=%d traveled=%d from=(%d,%d) own=(%d,%d) "
             "lastSent=(%d,%d) sentStep=%.0f holdTicks=%d - this is the distance covered in the "
             "second after the dodge stopped choosing, so a traveled distance near the walk speed of "
             "780 means the body is still riding the last target, and one near zero means the writes "
             "and not the engine were pacing it",
             (int)(g_ticks_3 - g_last_decision),
             (int)sqrtf((float)((ownX - g_decide_x) * (ownX - g_decide_x) +
                                (ownY - g_decide_y) * (ownY - g_decide_y))),
             (int)g_decide_x, (int)g_decide_y, ownX, ownY, g_last_tx_2,
             g_last_ty_2, (double)TNX_STEP_3, TNX_HOLD_TICKS);
}

void tnx_dump(void) {
    int i = 0;

    if (!TNX_DUMP) return;
    if ((g_ticks_3 % TNX_DUMP_EVERY) != 0) return;
    if (g_dump_logs >= TNX_DUMP_LOGS) return;

    g_dump_logs++;

    TNX_LOGX("dump own pos=(%d,%d) ok=%d team=%d trust=%d mates=%d enemies=%d cluster=%d/%d "
             "agree=%d players=%d segs=%d engaged=%d pick=(%d,%d) bodyMine=%d bodyEnemy=%d freest=%llu "
             "gate=%llu pred=%llu/%llu",
             g_own_x, g_own_y, tnx_own_ok(g_own_x, g_own_y),
             g_own_team_5, g_team_trust, g_mate_n, g_enemy_n, g_mates,
             g_enemies, g_agree, g_pl_n, g_seg_count, g_active_2,
             g_tx, g_ty, g_body_mine, g_body_enemy,
             (unsigned long long)g_freest_used, (unsigned long long)g_gate_writes,
             (unsigned long long)g_pred_calls, (unsigned long long)g_pred_fails);

    for (i = 0; i < g_pl_n && i < 6; i++) {
        TNX_LOGX("dump p%d gid=%d pos=(%d,%d) spawn=(%d,%d) team=%d mine=%d",
                 i, g_pl_gid[i], g_pl_x[i], g_pl_y[i], g_pl_sx[i],
                 g_pl_sy[i], g_pl_team[i], g_pl_mine[i]);
    }

    for (i = 0; i < TNX_PROJ_MAX; i++) {
        tnx_proj_t *p = &g_projs[i];
        uint64_t age = 0;

        if (p->classRva == (uintptr_t)-1) continue;
        if (!p->hasPrev) age = 0;
        else age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 0;

        TNX_LOGX("dump j%d gid=%d pos=(%d,%d) prev=(%d,%d) spawn=(%d,%d) team=%d dt=%llu",
                 i, p->gid, p->x, p->y, p->px, p->py, p->spawnX, p->spawnY, p->team,
                 (unsigned long long)age);
    }
}

void tnx_core(void) {
    if ((g_ticks_3 % 60) != 0) return;

    TNX_LOGX("core tick=%llu own=(%d,%d) ownOk=%d team=%d mates=%d enemies=%d trust=%d "
             "players=%d segs=%d trackedOwn=%d trackedOther=%d oneshot=%d body=%d enemyBlock=%d "
             "mateBlock=%d gate=%llu pred=%llu/%llu deadPick=%llu human=%llu driveWrites=%llu "
             "stickSkips=%llu stuck=%llu",
             (unsigned long long)g_ticks_3, g_own_x, g_own_y,
             tnx_own_ok(g_own_x, g_own_y), g_own_team_5, g_mate_n,
             g_enemy_n, g_team_trust, g_pl_n, g_seg_count, g_proj_own,
             g_proj_other, g_oneshot_segs, g_body_blocks, g_enemy_blocks,
             g_block_hits, (unsigned long long)g_gate_writes,
             (unsigned long long)g_pred_calls, (unsigned long long)g_pred_fails,
             (unsigned long long)g_dead_picks, (unsigned long long)g_human_live,
             (unsigned long long)g_engage_writes, (unsigned long long)g_stick_skips,
             (unsigned long long)g_stuck_2);
}

static int tnx_key_c(int n) {
    if (n <= 1) return 0;
    if (n <= 2) return 1;

    return 2;
}

static int tnx_key_t(float tti) {
    if (tti < 300.0f) return 0;
    if (tti < 700.0f) return 1;

    return 2;
}

static float tnx_learn_rate(int c, int t, int side) {
    uint64_t w = g_learn_win[c][t][side];
    uint64_t l = g_learn_loss[c][t][side];

    if (w + l == 0) return 0.5f;

    return (float)w / (float)(w + l);
}

static int tnx_blacklisted(float speed, float radius) {
    static const float bl[][2] = {
        { 3100.0f, 0.0f },
        { 4130.0f, 50.0f },
        { 3261.0f, 150.0f },
        { 5000.0f, 150.0f },
        { 6000.0f, 250.0f },
        { 1500.0f, 200.0f },
        { 4000.0f, 250.0f },
        { 3500.0f, 300.0f },
        { 840.0f, 0.0f },
        { 2853.0f, 0.0f }
    };
    int i = 0;

    if (!TNX_SKIP_UNSAFE) return 0;

    for (i = 0; i < 10; i++) {
        float ds = speed - bl[i][0];
        float dr = radius - bl[i][1];

        if (ds < 0.0f) ds = -ds;
        if (dr < 0.0f) dr = -dr;

        if (ds <= TNX_BLACK_SPEED_TOL && dr <= TNX_BLACK_RADIUS_TOL) return 1;
    }

    return 0;
}

int g_rad_bad = 0;

int g_cal_miss = 0;

int g_cal_off_seen = -1;

float g_cal_rad_seen = 0.0f;

int g_cal_n = 0;

int g_snap_calls = 0;

int g_snap_live = 0;

int g_snap_logs = 0;

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

float tnx_own_radius(void) {
    if (!TNX_GEOM) return 0.0f;
    if (g_own_r > 1.0f) return g_own_r;

    return 0.0f;
}

void tnx_contact_note(float dist, float projR) {
    float r = dist - projR;

    if (!TNX_GEOM) return;
    if (!tnx_ok(r, 10.0f, TNX_RADIUS_MAX)) return;

    if (g_own_r_n == 0) g_own_r = r;
    else g_own_r = g_own_r * 0.75f + r * 0.25f;

    g_own_r_n++;

    if (g_own_r_logs < TNX_CONTACT_LOGS) {
        g_own_r_logs++;

        TNX_LOGX("contact dist=%.0f projR=%.0f ownR=%.0f n=%d - own took a body while the nearest "
                 "live shot was this far from its centre, so subtracting the projectile radius "
                 "read out of that shot leaves own collision radius: the value kept is an average "
                 "over every contact seen and it is what the hit test inflates with from now on",
                 (double)dist, (double)projR, (double)g_own_r, g_own_r_n);
    }
}

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

    return 0.0f;
}

int tnx_snap(float dx, float dy) {
    uintptr_t fn = tnx_entry_2(TNX_SETPRED4_RVA);
    uintptr_t own = tnx_own_obj();
    float len = sqrtf(dx * dx + dy * dy);
    int32_t vx = 0;
    int32_t vy = 0;

    g_snap_live = 0;

    if (!TNX_SNAP) return 0;
    if (!fn || !own) return 0;
    if (!tnx_ok(len, 0.001f, 1.0e9f)) return 0;

    vx = (int32_t)((double)dx / (double)len * (double)TNX_SNAP_MAG);
    vy = (int32_t)((double)dy / (double)len * (double)TNX_SNAP_MAG);

    ((void (*)(void *, int, int, int))fn)((void *)own, vx, vy, TNX_SETFLAG);

    g_snap_calls++;
    g_snap_live = 1;

    if (g_snap_logs < TNX_SNAP_LOGS || (g_ticks_3 % 180) == 0) {
        g_snap_logs++;

        TNX_LOGX("snap own=%p pair=(%d,%d) dir=(%.0f,%.0f) len=%.0f mag=%.0f fn=%#llx flag=%d - "
                 "this is the same call the engine makes for itself, so the direction is applied in "
                 "the frame it was chosen: the stick is not written and the input queue is not used, "
                 "which is why the move keeps meaning what the pick computed and why there is no "
                 "queue hop between the decision and the motion",
                 (void *)own, vx, vy, (double)dx, (double)dy, (double)len,
                 (double)TNX_SNAP_MAG, (unsigned long long)TNX_SETPRED4_RVA, (int)TNX_SETFLAG);
    }

    return 1;
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
            float reach = TNX_PLAYER_RADIUS + TNX_PROJ_RADIUS + TNX_INFLATE;
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

void tnx_predict_2(int32_t ownX, int32_t ownY, float tx, float ty) {
    int i = 0;
    int best = -1;
    float px = (float)ownX;
    float py = (float)ownY;
    float bestMs = 1.0e9f;
    float qx = 0.0f;
    float qy = 0.0f;
    float d = 0.0f;
    int react = -1;

    if (g_logs_8 >= TNX_LOGS_4) return;
    if (TNX_EVERY_2 > 0 && (g_ticks_3 % (uint64_t)TNX_EVERY_2) != 0) return;

    for (i = 0; i < g_seg_count; i++) {
        const tnx_seg_t *s = &g_seg[i];
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

    if (g_new_tick >= 0) react = (int)((int64_t)g_ticks_3 - (int64_t)g_new_tick);

    g_logs_8++;

    if (best < 0) {
        TNX_LOGX("predict tick=%llu own=(%d,%d) tgt=(%.0f,%.0f) threats=0 react=%d flees=%llu - "
                 "no segment is live, so there is nothing to lead and the pick is a plain step",
                 (unsigned long long)g_ticks_3, ownX, ownY, (double)tx, (double)ty, react,
                 (unsigned long long)g_flees);

        return;
    }

    d = sqrtf((qx - px) * (qx - px) + (qy - py) * (qy - py));

    TNX_LOGX("predict tick=%llu own=(%d,%d) tgt=(%.0f,%.0f) threats=%d react=%d gid=%d "
             "impact=(%.0f,%.0f) lead=(%.0f,%.0f) d=%.0f eta=%.0fms spd=%.0f ms=%.0f - impact is the "
             "closest point of the nearest flight to own, lead is the offset own has to clear, and a "
             "react above one tick means the pick was made a frame or more after the threat appeared",
             (unsigned long long)g_ticks_3, ownX, ownY, (double)tx, (double)ty, g_seg_count,
             react, g_seg[best].gid, (double)qx, (double)qy, (double)(qx - px), (double)(qy - py),
             (double)d, (double)bestMs, (double)g_seg[best].speed, (double)(d / (g_seg[best].speed > 1.0f ? g_seg[best].speed : 1.0f) * 1000.0f));
}

void tnx_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape) {
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

    if (!TNX_PRECISION) return;
    if (TNX_EVERY > 0 && (g_ticks_3 % (uint64_t)TNX_EVERY) != 0) return;

    g_logs_7++;
    ctrl = tnx_controller();

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &ax);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &ay);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (g_joystick) tnx_read_i32(g_joystick + TNX_BS_MODE, &mode);

    if (g_pred_last) {
        tnx_read_i32(g_pred_last + TNX_MODE_PREDICTX_OFF, &predX);
        tnx_read_i32(g_pred_last + TNX_MODE_PREDICTY_OFF, &predY);
    }

    eta = tnx_eta_ms((float)ownX, (float)ownY);

    if (g_t0) {
        uint64_t now = tnx_us();

        g_dec_us = (now >= g_t0) ? (now - g_t0) : 0;

        if (g_dec_us > g_dec_us_max) g_dec_us_max = g_dec_us;
        if (g_dec_us > TNX_SLOW_US) g_slow++;
    }

    if (g_build_tick >= 0) lag = (int)((int64_t)g_ticks_3 - (int64_t)g_build_tick);

    {
        uintptr_t wrap = (uintptr_t)g_scene_object;
        uintptr_t cli = tnx_client();
        int32_t wAx = 0;
        int32_t wAy = 0;
        int32_t cAx = 0;
        int32_t cAy = 0;

        if (wrap) {
            tnx_read_i32(wrap + TNX_CTRL_APPLIED_X_OFF, &wAx);
            tnx_read_i32(wrap + TNX_CTRL_APPLIED_Y_OFF, &wAy);
        }

        if (cli) {
            tnx_read_i32(cli + TNX_CTRL_APPLIED_X_OFF, &cAx);
            tnx_read_i32(cli + TNX_CTRL_APPLIED_Y_OFF, &cAy);
        }

        TNX_LOGX("ctrlsrc wrap=%p wrapApplied=(%d,%d) client=%p clientApplied=(%d,%d) - drag the joystick "
                 "by hand while this prints: the engine writes applied into whichever of the two is the real "
                 "battle screen, so the pair that moves is the object this build has to write into",
                 (void *)wrap, wAx, wAy, (void *)cli, cAx, cAy);
    }

    TNX_LOGX("precision tick=%llu own=(%d,%d) dir=(%.0f,%.0f) escape=%d pair=(%d,%d) "
             "applied=(%d,%d) mode=%d joy=%p threats=%d eta=%.0fms buildLag=%d pred=(%d,%d) "
             "took=%llu denied=%llu - eta is the time the nearest bullet needs to reach own at its "
             "own speed, so any decision later than eta is a decision after the hit, and buildLag is "
             "the ticks between rebuilding the threat list and writing the stick",
             (unsigned long long)g_ticks_3, ownX, ownY, (double)dirX, (double)dirY, escape, ax, ay,
             appX, appY, mode, (void *)g_joystick, g_seg_count, (double)eta, lag, predX,
             predY, (unsigned long long)g_joystick_took,
             (unsigned long long)g_write_denied);
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

float tnx_speed(void) {
    float v = g_walk_step * 60.0f;

    if (v < 120.0f) v = 120.0f;
    if (v > 1200.0f) v = 1200.0f;

    return v;
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
        bestScore += TNX_MOMENTUM * (base * g_last_x_3 + baseY * g_last_y_3);
        baseScore = bestScore;
    }

    for (i = 0; i < 12; i++) {
        float a = rot[i] * rad;
        float c = cosf(a);
        float sn = sinf(a);
        float rx = base * c - baseY * sn;
        float ry = base * sn + baseY * c;
        float score = tnx_score(px, py, rx, ry, len);

        if (g_last_ok) score += TNX_MOMENTUM * (rx * g_last_x_3 + ry * g_last_y_3);

        if (score > bestScore) {
            bestScore = score;
            bestX = rx;
            bestY = ry;
        }
    }

    if (g_last_ok && bestX != base &&
        (bestScore - (tnx_score(px, py, base, baseY, len) +
                      TNX_MOMENTUM * (base * g_last_x_3 + baseY * g_last_y_3))) <
            TNX_KEEP_BAND_2) {
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
    float pvx = dirX * (float)tnx_hero_speed();
    float pvy = dirY * (float)tnx_hero_speed();
    float horizon = travel / (float)tnx_hero_speed();
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

    if (TNX_REACT_CRIT && best < TNX_CRITICAL_MS) g_crit_reaction = 1;

    g_mom_live = g_crit_reaction ? 0.0f : TNX_MOMENTUM;

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
    float speed = (float)tnx_hero_speed();
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


static float tnx_clear_at(float px, float py, int i) {
    return tnx_seg_dist(px, py, g_seg[i].ax, g_seg[i].ay, g_seg[i].bx, g_seg[i].by) - g_seg[i].inflatedR;
}

static float tnx_all_clear(float x, float y) {
    int k = 0;
    float best = 1.0e9f;

    for (k = 0; k < g_seg_count; k++) {
        float c = tnx_clear_at(x, y, k);

        if (c < best) best = c;
    }

    return best;
}

static int tnx_wall_blocked(float x0, float y0, float x1, float y1) {
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

static int tnx_side_near(float px, float py) {
    int i = 0;
    int near = -1;
    float nd = 1.0e9f;

    for (i = 0; i < g_seg_count; i++) {
        float c = tnx_clear_at(px, py, i);

        if (c < nd) {
            nd = c;
            near = i;
        }
    }

    return near;
}

static float tnx_side_score(float px, float py, float x, float y, int near) {
    int i = 0;
    float s = 0.0f;
    float own = sqrtf((x - px) * (x - px) + (y - py) * (y - py));

    for (i = 0; i < g_seg_count; i++) {
        float c = tnx_clear_at(x, y, i);

        if (c < 0.0f) c = c * 4.0f;

        s += ((i == near) ? TNX_SIDE_W_PRIME : TNX_SIDE_W_OTHER) * c;
    }

    s += TNX_SIDE_W_OWN * own;

    return s;
}

static int tnx_side_pick(float px, float py, float *outX, float *outY) {
    int near = tnx_side_near(px, py);
    float nx = 0.0f;
    float ny = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;
    float dl = 0.0f;
    float dist = TNX_DODGE_DIST;
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float sa = 0.0f;
    float sb = 0.0f;
    float toShot = 0.0f;
    float adaptive = 0.0f;

    if (near < 0) return 0;

    nx = g_seg[near].ax;
    ny = g_seg[near].ay;
    dx = g_seg[near].bx - nx;
    dy = g_seg[near].by - ny;
    dl = sqrtf(dx * dx + dy * dy);

    if (dl < 1.0f) return 0;

    dx /= dl;
    dy /= dl;

    toShot = sqrtf((nx - px) * (nx - px) + (ny - py) * (ny - py));
    adaptive = toShot * TNX_DIST_FACTOR;

    if (adaptive > 1.0f && adaptive < dist) dist = adaptive;
    if (dist < TNX_STEP) dist = TNX_STEP;

    ax = px - dy * dist;
    ay = py + dx * dist;
    bx = px + dy * dist;
    by = py - dx * dist;

    {
        int c = tnx_key_c(g_seg_count);
        int t = tnx_key_t(g_tti_min);

        sa = tnx_valid_point(ax, ay) ? tnx_side_score(px, py, ax, ay, near) : -1.0e9f;
        sb = tnx_valid_point(bx, by) ? tnx_side_score(px, py, bx, by, near) : -1.0e9f;

        sa += TNX_LEARN_W * (tnx_learn_rate(c, t, 0) - 0.5f);
        sb += TNX_LEARN_W * (tnx_learn_rate(c, t, 1) - 0.5f);

        {
            int stale = 0;

            if (TNX_SIDE_FLIP && g_side_tick != 0 &&
                (g_ticks_3 - (uint64_t)g_side_tick) > (uint64_t)TNX_SIDE_STALE) stale = 1;

            if (stale) {
                g_side_flips++;

                if (g_side_last == 0 && sb > -1.0e8f) sb += TNX_LEARN_W * TNX_SIDE_MARGIN;
                if (g_side_last == 1 && sa > -1.0e8f) sa += TNX_LEARN_W * TNX_SIDE_MARGIN;
            } else {
                if (g_side_last == 0 && sa > -1.0e8f) sa += TNX_LEARN_W * TNX_SIDE_MARGIN;
                if (g_side_last == 1 && sb > -1.0e8f) sb += TNX_LEARN_W * TNX_SIDE_MARGIN;
            }
        }

        if (sa < -1.0e8f && sb < -1.0e8f) return 0;

        if (sa >= sb) {
            *outX = ax;
            *outY = ay;
            g_side_last = 0;
        } else {
            *outX = bx;
            *outY = by;
            g_side_last = 1;
        }

        g_side_tick = (int)g_ticks_3;
        g_side_picks++;

        g_pick_key_c = c;
        g_pick_key_t = t;
        g_stat_side++;
    }

    return 1;
}

static void tnx_stat_tick(float px, float py) {
    int i = 0;
    int j = 0;
    int k = 0;

    for (i = 0; i < TNX_SEG_MAX; i++) {
        int gid = g_track_gid[i];
        int live = 0;

        if (gid == 0) continue;

        for (j = 0; j < g_seg_count; j++) {
            if (g_seg[j].gid != gid) continue;

            live = 1;

            {
                float c = tnx_clear_at(px, py, j);
                float dx = g_seg[j].bx - g_seg[j].ax;
                float dy = g_seg[j].by - g_seg[j].ay;
                float cross = dx * (py - g_seg[j].ay) - dy * (px - g_seg[j].ax);

                if (c <= 0.0f) g_track_hit[i] = 1;
                if (c <= g_seg[j].inflatedR * (TNX_NEAR_MULT - 1.0f)) g_stat_near++;
                if (c < g_track_min[i]) g_track_min[i] = c;

                if (cross > 0.0f) {
                    g_track_pside[i] = 0;
                } else {
                    g_track_pside[i] = 1;
                }

                {
                    float dl = sqrtf(dx * dx + dy * dy);

                    g_track_rad[i] = g_seg[j].inflatedR;

                    if (dl > 0.001f) {
                        g_track_ux[i] = dx / dl;
                        g_track_uy[i] = dy / dl;
                    }
                }
            }
        }

        if (live) continue;

        if (g_track_hit[i]) {
            g_stat_absorbed++;

            if (g_howto_logs < TNX_HOWTO_LOGS) {
                float need = 0.0f - g_track_min[i];
                float ownSpd = TNX_PLAYER_SPEED / 60.0f;
                float frames = (ownSpd > 0.5f) ? (need / ownSpd) : 0.0f;
                float ux = g_track_ux[i];
                float uy = g_track_uy[i];
                float dist = TNX_DODGE_DIST;
                float ax0 = px - uy * dist;
                float ay0 = py + ux * dist;
                float ax1 = px + uy * dist;
                float ay1 = py - ux * dist;
                float c0 = tnx_all_clear(ax0, ay0);
                float c1 = tnx_all_clear(ax1, ay1);
                int w0 = tnx_wall_blocked(px, py, ax0, ay0);
                int w1 = tnx_wall_blocked(px, py, ax1, ay1);
                int alt = 0;

                if (w0 < 0 || w1 < 0) alt = g_track_pside[i];
                else if (w1 != 0 && w0 == 0) alt = 0;
                else if (w0 != 0 && w1 == 0) alt = 1;
                else if (c1 > c0) alt = 1;
                else alt = 0;

                g_howto_logs++;

                TNX_LOGX("howto side=%d alt=%d need=%.0f units frames=%.0f ownSpd=%.0f "
                         "minClear=%.0f clear0=%.0f clear1=%.0f wall0=%d wall1=%d radius=%.0f - "
                         "the closest approach on this shot stayed %.0f units inside the contact "
                         "boundary, so clearing it needed %.0f units of lateral movement, and at "
                         "%.0f units a frame that is %.0f frames: those frames are what says "
                         "whether the miss was scheduling or arithmetically impossible. clear0 and "
                         "clear1 are the room left on each perpendicular of the shot against every "
                         "other live flight, wall0 and wall1 say whether the tilemap clips the run "
                         "to that point on each side, and alt is the side this arithmetic says "
                         "should have been taken",
                         g_track_pside[i], alt, (double)need, (double)frames, (double)ownSpd,
                         (double)g_track_min[i], (double)c0, (double)c1, w0, w1,
                         (double)g_track_rad[i], (double)need, (double)need, (double)ownSpd,
                         (double)frames);
            }
        } else {
            g_stat_dodged++;
        }

        if (g_shot_key[i] >= 0) {
            int c = g_shot_key[i] >> 2;
            int t = ((g_shot_key[i] >> 1) & 1);
            int sd = g_shot_key[i] & 1;

            if (c >= 0 && c < 3 && t >= 0 && t < 3 && sd >= 0 && sd < 2) {
                if (g_track_hit[i]) {
                    g_learn_loss[c][t][sd]++;
                } else {
                    g_learn_win[c][t][sd]++;
                }
            }
        }

        k = (int)(g_last_dist / TNX_ADV_STEP);

        if (k < 0) k = 0;
        if (k >= TNX_ADV_BUCKETS) k = TNX_ADV_BUCKETS - 1;

        g_bucket_n[k]++;

        if (g_track_hit[i]) g_bucket_abs[k]++;

        g_track_gid[i] = 0;
        g_track_hit[i] = 0;
    }

    for (i = 0; i < g_seg_count; i++) {
        int gid = g_seg[i].gid;
        int have = 0;

        if (gid == 0) continue;

        for (k = 0; k < TNX_SEG_MAX; k++) {
            if (g_track_gid[k] == gid) {
                have = 1;

                break;
            }
        }

        if (have) continue;

        for (k = 0; k < TNX_SEG_MAX; k++) {
            if (g_track_gid[k] != 0) continue;

            g_track_gid[k] = gid;
            g_track_hit[k] = 0;
            g_track_min[k] = 1.0e9f;
            g_track_pside[k] = 0;
            g_shot_key[k] = (g_pick_key_c << 2) | (g_pick_key_t << 1) | (g_side_last < 0 ? 0 : g_side_last);

            break;
        }
    }
}

static void tnx_stat_report(void) {
    int b = 0;
    int best = -1;
    float bestRate = 2.0f;

    if (g_last_stat != 0 && (g_ticks_3 - g_last_stat) < (uint64_t)(TNX_STAT_SEC * 60.0f)) return;

    g_last_stat = g_ticks_3;

    TNX_LOGX("stat picks=%llu side=%llu commit=%llu absorbed=%llu dodged=%llu reactMin=%llu "
             "reactAvg=%llu reactMax=%llu near=%d resets=%llu segs=%d ownR=%.0f projR=%.0f "
             "radOff=%d clip=%d/%d - absorbed counts a shot that came body while it was alive and "
             "dodged counts one that passed without ever doing so, so that pair is the only "
             "scoreboard that matters, and react is the ticks between the threat set changing and "
             "the pick that answered it; ownR is the collision radius learned from contacts, projR "
             "is the radius read out of the shot data with radOff the offset it was found at, and "
             "clip is how many flights the tilemap shortened out of every flight tested, so clip at "
             "zero over a large test count means the wall pass is not running",
             (unsigned long long)g_stat_picks, (unsigned long long)g_stat_side,
             (unsigned long long)g_stat_commit, (unsigned long long)g_stat_absorbed,
             (unsigned long long)g_stat_dodged, (unsigned long long)g_react_min,
             (unsigned long long)(g_react_n ? (g_react_sum / g_react_n) : 0),
             (unsigned long long)g_react_max, g_stat_near, (unsigned long long)g_stat_reset,
             g_seg_count, (double)g_own_r, (double)g_rad_est, g_rad_off,
             g_clip_win, g_clip_test_win);

    g_clip_win = 0;
    g_clip_test_win = 0;

    for (b = 0; b < TNX_ADV_BUCKETS; b++) {
        float rate = 0.0f;

        if (g_bucket_n[b] < TNX_ADV_MIN) continue;

        rate = (float)g_bucket_abs[b] / (float)g_bucket_n[b];

        if (rate < bestRate) {
            bestRate = rate;
            best = b;
        }
    }

    {
        int c = 0;
        int t = 0;
        int sd = 0;
        int wc = -1;
        int wt = 0;
        int ws = 0;
        float wr = 2.0f;

        for (c = 0; c < 3; c++) {
            for (t = 0; t < 3; t++) {
                for (sd = 0; sd < 2; sd++) {
                    uint64_t n = g_learn_win[c][t][sd] + g_learn_loss[c][t][sd];

                    if (n < 3) continue;

                    if (tnx_learn_rate(c, t, sd) < wr) {
                        wr = tnx_learn_rate(c, t, sd);
                        wc = c;
                        wt = t;
                        ws = sd;
                    }
                }
            }
        }

        if (wc >= 0) {
            TNX_LOGX("hint threats=%d tti=%d side=%d rate=%.2f over=%llu - this is the case the "
                     "memory loses most often, so the pick in exactly that situation is what to "
                     "change first: side 0 is the left hand option and side 1 the right one, and "
                     "tti buckets are under 300ms, under 700ms and the rest",
                     wc + 1, wt, ws, (double)wr,
                     (unsigned long long)(g_learn_win[wc][wt][ws] + g_learn_loss[wc][wt][ws]));
        }
    }

    TNX_LOGX("act snap=%d live=%d flip=%d sidePicks=%d wallStop=%llu radBad=%llu calMiss=%llu "
             "calOff=%#x ownR=%.0f geomOff=%#x geomR=%.0f - snap is how many calls to the engine "
             "movement apply went out, live says the last decision was applied that way, flip counts "
             "how often a stale side was turned around, wallStop is how many walks ended because a "
             "wall clipped the target, radBad is how many segments fell back to the configured band "
             "because the radii were not finite, calMiss is how many calibration sweeps ended with "
             "no offset, and calOff and geomOff being -1 means no radius was ever taken from data",
             g_snap_calls, g_snap_live, g_side_flips, g_side_picks,
             (unsigned long long)g_wall_stops, (unsigned long long)g_rad_bad,
             (unsigned long long)g_cal_miss, (unsigned int)g_cal_off_seen, (double)g_own_r,
             (unsigned int)g_rad_off, (double)g_rad_est);

    g_snap_calls = 0;
    g_side_flips = 0;
    g_side_picks = 0;
    g_rad_bad = 0;
    g_cal_miss = 0;

    if (best >= 0) {
        TNX_LOGX("advise distance=%.0f absorbed=%.2f over=%llu dodgeDist=%d commit=%d - the bucketed "
                 "scoreboard names the step that ate the fewest shots, so when that number differs "
                 "from the one in the config this is what TNX_DODGE_DIST should be set to",
                 (double)((float)best * TNX_ADV_STEP), (double)bestRate,
                 (unsigned long long)g_bucket_n[best], (int)TNX_DODGE_DIST, (int)TNX_COMMIT_MS);
    }
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

        if (TNX_REACT_CRIT) g_crit_reaction = 1;
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
    tnx_phase("dodge-enter");

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
        else tnx_probe_2();

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

    tnx_frame_window();
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
                     TNX_LOCK_MS, (double)TNX_KEEP_BAND, (int)TNX_CRITICAL_MS,
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

        tnx_receiver_probe();

        if (!g_active_2) {
            g_dir_x = escapeX;
            g_dir_y = escapeY;
        }

        tnx_watch(ownX, ownY);

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

void tnx_probe_2(void) {
    uintptr_t bs = tnx_bs();
    void *vt = NULL;
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float cs = 0.0f;
    float sn = 0.0f;
    uint32_t mode = 0;
    unsigned long long vtRva = 0;

    tnx_scan();

    if (!bs) return;

    if (g_probe_logs_2 < 1) {
        g_probe_logs_2++;

        if (tnx_read_ptr(bs, &vt) && (uintptr_t)vt > g_base) {
            vtRva = (unsigned long long)((uintptr_t)vt - g_base);
        }

        TNX_LOGX("bs live scene=%p bs=%p ctrl=%p classRva=%#llx - the one-shot waits for a live "
                 "scene now, so the class word is read from the object the dodge really uses and not "
                 "from a null pointer, which is what the previous run printed as scene=0x0 and "
                 "classRva=0; updateMovement cannot be hooked on this target - a scan of every "
                 "eight-byte word of __DATA_CONST and __DATA found no slot pointing at it and inline "
                 "patching is not supported - so the BattleScreen object is the scene this file "
                 "already resolves and the joystick is searched in its window by the v173 scanner. "
                 "The class word 0xfe9d00 is the identity the earlier note names",
                 (void *)g_scene_object, (void *)bs, (void *)tnx_controller(), vtRva);
    }

    if (g_own_logs_7 < 20 && (g_ticks_3 % 60) == 0) {
        g_own_logs_7++;

        TNX_LOGX("own check ownElem=%p ownFrom=%s - the same object the dodge reads its position "
                 "from, printed next to the element lines so the two own sources in the log can be "
                 "told apart instead of being read as a disagreement",
                 (void *)g_own_elem, g_own_from_3);
    }

    if (g_probe_logs_2 < 22 && (g_ticks_3 % 60) == 0) {
        g_probe_logs_2++;

        if (!tnx_joy_read(bs, &ax, &ay, &bx, &by, &mode, &cs, &sn)) return;

        TNX_LOGX("joyprobe bs=%p ax=%+.4f ay=%+.4f bx=%+.4f by=%+.4f mode=%u cos=%+.4f sin=%+.4f "
                 "- read only, nothing is written in this build; move the stick by hand and if these "
                 "move and mode reads 2 or 3 this is the joystick, otherwise this class keeps the "
                 "stick elsewhere and the window diff below is the way to it",
                 (void *)bs, (double)ax, (double)ay, (double)bx, (double)by, mode, (double)cs,
                 (double)sn);
    }
}
int tnx_write(float dirX, float dirY) {
    uintptr_t bs = tnx_bs();
    float len = sqrtf(dirX * dirX + dirY * dirY);
    float nx = 0.0f;
    float ny = 0.0f;
    int32_t two = 2;

    if (len < 0.001f) return 0;
    if (!bs) return 0;

    nx = dirX / len * TNX_JOY_SCALE;
    ny = dirY / len * TNX_JOY_SCALE;

    if (!tnx_write_f32(bs + TNX_BS_AX, nx)) return 0;
    if (!tnx_write_f32(bs + TNX_BS_AY, ny)) return 0;
    if (!tnx_write_f32(bs + TNX_BS_BX, nx)) return 0;
    if (!tnx_write_f32(bs + TNX_BS_BY, ny)) return 0;

    tnx_write_bytes(bs + TNX_BS_MODE, &two, sizeof(two));

    return 1;
}
