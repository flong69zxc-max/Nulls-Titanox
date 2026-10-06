#include "titanox.h"

uint64_t t_stat_absorbed = 0;

uint64_t t_stat_dodged = 0;

uint64_t t_bucket_abs[TNX_ADV_BUCKETS];

uint64_t t_bucket_n[TNX_ADV_BUCKETS];

uint64_t t_learn_win[3][3][2];

uint64_t t_learn_loss[3][3][2];

int t_stat_near = 0;

int tnx_key_c(int n) {
    if (n <= 1) return 0;
    if (n <= 2) return 1;

    return 2;
}

int tnx_key_t(float tti) {
    if (tti < 300.0f) return 0;
    if (tti < 700.0f) return 1;

    return 2;
}

float tnx_learn_rate(int c, int t, int side) {
    uint64_t w = t_learn_win[c][t][side];
    uint64_t l = t_learn_loss[c][t][side];

    if (w + l == 0) return 0.5f;

    return (float)w / (float)(w + l);
}

int tnx_blacklisted(float speed, float radius) {
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

void tnx_stat_tick(float px, float py) {
    int i = 0;
    int j = 0;
    int k = 0;

    for (i = 0; i < TNX_SEG_MAX; i++) {
        int gid = t_track_gid[i];
        int live = 0;

        if (gid == 0) continue;

        for (j = 0; j < t_seg_count; j++) {
            if (t_seg[j].gid != gid) continue;

            live = 1;

            {
                float c = tnx_clear_at(px, py, j);
                float dx = t_seg[j].bx - t_seg[j].ax;
                float dy = t_seg[j].by - t_seg[j].ay;
                float cross = dx * (py - t_seg[j].ay) - dy * (px - t_seg[j].ax);

                if (c <= 0.0f) t_track_hit[i] = 1;
                if (c <= t_seg[j].inflatedR * (TNX_NEAR_MULT - 1.0f)) t_stat_near++;
                if (c < t_track_min[i]) t_track_min[i] = c;

                if (cross > 0.0f) {
                    t_track_pside[i] = 0;
                } else {
                    t_track_pside[i] = 1;
                }

                {
                    float dl = sqrtf(dx * dx + dy * dy);

                    t_track_rad[i] = t_seg[j].inflatedR;

                    if (dl > 0.001f) {
                        t_track_ux[i] = dx / dl;
                        t_track_uy[i] = dy / dl;
                    }
                }
            }
        }

        if (live) continue;

        if (t_track_hit[i]) {
            t_stat_absorbed++;

            if (t_howto_logs < TNX_HOWTO_LOGS) {
                float need = 0.0f - t_track_min[i];
                float ownSpd = TNX_DATA_SPEED / 60.0f;
                float frames = (ownSpd > 0.5f) ? (need / ownSpd) : 0.0f;
                float ux = t_track_ux[i];
                float uy = t_track_uy[i];
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

                if (w0 < 0 || w1 < 0) alt = t_track_pside[i];
                else if (w1 != 0 && w0 == 0) alt = 0;
                else if (w0 != 0 && w1 == 0) alt = 1;
                else if (c1 > c0) alt = 1;
                else alt = 0;

                t_howto_logs++;

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
                         t_track_pside[i], alt, (double)need, (double)frames, (double)ownSpd,
                         (double)t_track_min[i], (double)c0, (double)c1, w0, w1,
                         (double)t_track_rad[i], (double)need, (double)need, (double)ownSpd,
                         (double)frames);
            }
        } else {
            t_stat_dodged++;
        }

        if (t_shot_key[i] >= 0) {
            int c = t_shot_key[i] >> 2;
            int t = ((t_shot_key[i] >> 1) & 1);
            int sd = t_shot_key[i] & 1;

            if (c >= 0 && c < 3 && t >= 0 && t < 3 && sd >= 0 && sd < 2) {
                if (t_track_hit[i]) {
                    t_learn_loss[c][t][sd]++;
                } else {
                    t_learn_win[c][t][sd]++;
                }
            }
        }

        k = (int)(t_last_dist / TNX_ADV_STEP);

        if (k < 0) k = 0;
        if (k >= TNX_ADV_BUCKETS) k = TNX_ADV_BUCKETS - 1;

        t_bucket_n[k]++;

        if (t_track_hit[i]) t_bucket_abs[k]++;

        t_track_gid[i] = 0;
        t_track_hit[i] = 0;
    }

    for (i = 0; i < t_seg_count; i++) {
        int gid = t_seg[i].gid;
        int have = 0;

        if (gid == 0) continue;

        for (k = 0; k < TNX_SEG_MAX; k++) {
            if (t_track_gid[k] == gid) {
                have = 1;

                break;
            }
        }

        if (have) continue;

        for (k = 0; k < TNX_SEG_MAX; k++) {
            if (t_track_gid[k] != 0) continue;

            t_track_gid[k] = gid;
            t_track_hit[k] = 0;
            t_track_min[k] = 1.0e9f;
            t_track_pside[k] = 0;
            t_shot_key[k] = (t_pick_key_c << 2) | (t_pick_key_t << 1) | (t_side_last < 0 ? 0 : t_side_last);

            break;
        }
    }
}

void tnx_stat_report(void) {
    int b = 0;
    int best = -1;
    float bestRate = 2.0f;

    if (t_last_stat != 0 && (t_ticks_3 - t_last_stat) < (uint64_t)(TNX_STAT_SEC * 60.0f)) return;

    t_last_stat = t_ticks_3;

    TNX_LOGX("stat picks=%llu side=%llu commit=%llu absorbed=%llu dodged=%llu reactMin=%llu "
             "reactAvg=%llu reactMax=%llu near=%d resets=%llu segs=%d ownR=%.0f projR=%.0f "
             "radOff=%d clip=%d/%d - absorbed counts a shot that came body while it was alive and "
             "dodged counts one that passed without ever doing so, so that pair is the only "
             "scoreboard that matters, and react is the ticks between the threat set changing and "
             "the pick that answered it; ownR is the collision radius learned from contacts, projR "
             "is the radius read out of the shot data with radOff the offset it was found at, and "
             "clip is how many flights the tilemap shortened out of every flight tested, so clip at "
             "zero over a large test count means the wall pass is not running",
             (unsigned long long)t_stat_picks, (unsigned long long)t_stat_side,
             (unsigned long long)t_stat_commit, (unsigned long long)t_stat_absorbed,
             (unsigned long long)t_stat_dodged, (unsigned long long)t_react_min,
             (unsigned long long)(t_react_n ? (t_react_sum / t_react_n) : 0),
             (unsigned long long)t_react_max, t_stat_near, (unsigned long long)t_stat_reset,
             t_seg_count, (double)t_own_r, (double)t_rad_est, t_rad_off,
             t_clip_win, t_clip_test_win);

    t_clip_win = 0;
    t_clip_test_win = 0;

    for (b = 0; b < TNX_ADV_BUCKETS; b++) {
        float rate = 0.0f;

        if (t_bucket_n[b] < TNX_ADV_MIN) continue;

        rate = (float)t_bucket_abs[b] / (float)t_bucket_n[b];

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
                    uint64_t n = t_learn_win[c][t][sd] + t_learn_loss[c][t][sd];

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
                     (unsigned long long)(t_learn_win[wc][wt][ws] + t_learn_loss[wc][wt][ws]));
        }
    }

    TNX_LOGX("act snap=%d live=%d flip=%d sidePicks=%d wallStop=%llu radBad=%llu calMiss=%llu "
             "calOff=%#x ownR=%.0f geomOff=%#x geomR=%.0f - snap is how many calls to the engine "
             "movement apply went out, live says the last decision was applied that way, flip counts "
             "how often a stale side was turned around, wallStop is how many walks ended because a "
             "wall clipped the target, radBad is how many segments fell back to the configured band "
             "because the radii were not finite, calMiss is how many calibration sweeps ended with "
             "no offset, and calOff and geomOff being -1 means no radius was ever taken from data",
             t_snap_calls, t_snap_live, t_side_flips, t_side_picks,
             (unsigned long long)t_wall_stops, (unsigned long long)t_rad_bad,
             (unsigned long long)t_cal_miss, (unsigned int)t_cal_off_seen, (double)t_own_r,
             (unsigned int)t_rad_off, (double)t_rad_est);

    t_snap_calls = 0;
    t_side_flips = 0;
    t_side_picks = 0;
    t_rad_bad = 0;
    t_cal_miss = 0;

    if (best >= 0) {
        TNX_LOGX("advise distance=%.0f absorbed=%.2f over=%llu dodgeDist=%d commit=%d - the bucketed "
                 "scoreboard names the step that ate the fewest shots, so when that number differs "
                 "from the one in the config this is what TNX_DODGE_DIST should be set to",
                 (double)((float)best * TNX_ADV_STEP), (double)bestRate,
                 (unsigned long long)t_bucket_n[best], (int)TNX_DODGE_DIST, (int)TNX_COMMIT_MS);
    }
}
