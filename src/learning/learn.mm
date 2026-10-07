#include "recoil.h"



uint64_t rcl_bucket_abs[RCL_ADV_BUCKETS];


uint64_t rcl_learn_win[3][3][2];

uint64_t rcl_learn_loss[3][3][2];

int rcl_stat_near = 0;
int rcl_blacklisted(float speed, float radius) {
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

    if (!RCL_SKIP_UNSAFE) return 0;

    for (i = 0; i < 10; i++) {
        float ds = speed - bl[i][0];
        float dr = radius - bl[i][1];

        if (ds < 0.0f) ds = -ds;
        if (dr < 0.0f) dr = -dr;

        if (ds <= RCL_BLACK_SPEED_TOL && dr <= RCL_BLACK_RADIUS_TOL) return 1;
    }

    return 0;
}

void rcl_stat_tick(float px, float py) {
    int i = 0;
    int j = 0;
    int k = 0;

    for (i = 0; i < RCL_SEG_MAX; i++) {
        int gid = rcl_track_gid[i];
        int live = 0;

        if (gid == 0) continue;

        for (j = 0; j < rcl_seg_count; j++) {
            if (rcl_seg[j].gid != gid) continue;

            live = 1;

            {
                float c = rcl_clear_at(px, py, j);
                float dx = rcl_seg[j].bx - rcl_seg[j].ax;
                float dy = rcl_seg[j].by - rcl_seg[j].ay;
                float cross = dx * (py - rcl_seg[j].ay) - dy * (px - rcl_seg[j].ax);

                if (c <= 0.0f) rcl_track_hit[i] = 1;
                if (c <= rcl_seg[j].inflatedR * (RCL_NEAR_MULT - 1.0f)) rcl_stat_near++;
                if (c < rcl_track_min[i]) rcl_track_min[i] = c;

                if (cross > 0.0f) {
                    rcl_track_pside[i] = 0;
                } else {
                    rcl_track_pside[i] = 1;
                }

                {
                    float dl = sqrtf(dx * dx + dy * dy);


                    if (dl > 0.001f) {
                        rcl_track_ux[i] = dx / dl;
                        rcl_track_uy[i] = dy / dl;
                    }
                }
            }
        }

        if (live) continue;

        if (rcl_track_hit[i]) {

            if (rcl_howto_logs < RCL_HOWTO_LOGS) {
                float need = 0.0f - rcl_track_min[i];
                float ownSpd = RCL_DATA_SPEED / 60.0f;
                float frames = (ownSpd > 0.5f) ? (need / ownSpd) : 0.0f;
                float ux = rcl_track_ux[i];
                float uy = rcl_track_uy[i];
                float dist = RCL_DODGE_DIST;
                float ax0 = px - uy * dist;
                float ay0 = py + ux * dist;
                float ax1 = px + uy * dist;
                float ay1 = py - ux * dist;
                float c0 = rcl_all_clear(ax0, ay0);
                float c1 = rcl_all_clear(ax1, ay1);
                int w0 = rcl_wall_blocked(px, py, ax0, ay0);
                int w1 = rcl_wall_blocked(px, py, ax1, ay1);
                int alt = 0;

                if (w0 < 0 || w1 < 0) alt = rcl_track_pside[i];
                else if (w1 != 0 && w0 == 0) alt = 0;
                else if (w0 != 0 && w1 == 0) alt = 1;
                else if (c1 > c0) alt = 1;
                else alt = 0;

                rcl_howto_logs++;

            }
        } else {
        }

        if (rcl_shot_key[i] >= 0) {
            int c = rcl_shot_key[i] >> 2;
            int t = ((rcl_shot_key[i] >> 1) & 1);
            int sd = rcl_shot_key[i] & 1;

            if (c >= 0 && c < 3 && t >= 0 && t < 3 && sd >= 0 && sd < 2) {
                if (rcl_track_hit[i]) {
                    rcl_learn_loss[c][t][sd]++;
                } else {
                    rcl_learn_win[c][t][sd]++;
                }
            }
        }

        k = (int)(rcl_last_dist / RCL_ADV_STEP);

        if (k < 0) k = 0;
        if (k >= RCL_ADV_BUCKETS) k = RCL_ADV_BUCKETS - 1;


        if (rcl_track_hit[i]) rcl_bucket_abs[k]++;

        rcl_track_gid[i] = 0;
        rcl_track_hit[i] = 0;
    }

    for (i = 0; i < rcl_seg_count; i++) {
        int gid = rcl_seg[i].gid;
        int have = 0;

        if (gid == 0) continue;

        for (k = 0; k < RCL_SEG_MAX; k++) {
            if (rcl_track_gid[k] == gid) {
                have = 1;

                break;
            }
        }

        if (have) continue;

        for (k = 0; k < RCL_SEG_MAX; k++) {
            if (rcl_track_gid[k] != 0) continue;

            rcl_track_gid[k] = gid;
            rcl_track_hit[k] = 0;
            rcl_track_min[k] = 1.0e9f;
            rcl_track_pside[k] = 0;
            rcl_shot_key[k] = (rcl_pick_key_c << 2) | (rcl_pick_key_t << 1) | (rcl_side_last < 0 ? 0 : rcl_side_last);

            break;
        }
    }
}