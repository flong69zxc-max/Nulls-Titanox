#include "../recoil.h"

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

            return 1;
        }
    }

    return 0;
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

float rcl_score(float px, float py, float dirX, float dirY, float len) {
    rcl_select(px, py);

    return rcl_clearance_b(px, py, dirX, dirY) +
           RCL_BODY_W * rcl_body_score_2(px, py, dirX, dirY, len);
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

int rcl_wall_blocked(float x0, float y0, float x1, float y1) {
    int32_t ox = (int32_t)x1;
    int32_t oy = (int32_t)y1;

    if (!rcl_live || !rcl_armed) return -1;
    if (rcl_w <= 0 || rcl_h <= 0) return -1;

    return rcl_clip_walk((int32_t)x0, (int32_t)y0, (int32_t)x1, (int32_t)y1,
                         (int32_t)RCL_TILE_SIZE, rcl_grid, rcl_w, rcl_h, &ox, &oy);
}
