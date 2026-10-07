#include "titanox.h"



uint64_t t_bucket_abs[TNX_ADV_BUCKETS];


uint64_t t_learn_win[3][3][2];

uint64_t t_learn_loss[3][3][2];

int t_stat_near = 0;int tnx_blacklisted(float speed, float radius) {
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


                    if (dl > 0.001f) {
                        t_track_ux[i] = dx / dl;
                        t_track_uy[i] = dy / dl;
                    }
                }
            }
        }

        if (live) continue;

        if (t_track_hit[i]) {

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

            }
        } else {
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