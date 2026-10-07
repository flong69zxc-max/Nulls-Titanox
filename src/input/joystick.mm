#include "recoil.h"

void rcl_applied(int32_t ax, int32_t ay);

rcl_seg_t rcl_seg[RCL_SEG_MAX];

int rcl_seg_count = 0;

uintptr_t rcl_bs(void) {
    return rcl_client();
}

int rcl_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by,
                             uint32_t *mode, float *cs, float *sn) {
    int32_t m = 0;

    if (!bs) return 0;

    if (!rcl_read_float(bs + RCL_BS_AX, ax)) return 0;
    if (!rcl_read_float(bs + RCL_BS_AY, ay)) return 0;
    if (!rcl_read_float(bs + RCL_BS_BX, bx)) return 0;
    if (!rcl_read_float(bs + RCL_BS_BY, by)) return 0;

    *mode = 0;

    if (rcl_read_int(bs + RCL_BS_MODE, &m)) *mode = (uint32_t)m;

    if (!rcl_read_float(bs + RCL_BS_COS, cs)) *cs = 1.0f;
    if (!rcl_read_float(bs + RCL_BS_SIN, sn)) *sn = 0.0f;

    return 1;
}







int rcl_joy_angle(float *outAngle) {
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

    if (!rcl_joy_read(rcl_bs(), &ax, &ay, &bx, &by, &mode, &cs, &sn)) return 0;
    if (mode != 2 && mode != 3) return 0;

    rx = (ax - bx) * cs + (ay - by) * sn;
    ry = (ay - by) * cs - (ax - bx) * sn;

    len = sqrtf(rx * rx + ry * ry);

    if (len < 0.001f) return 0;

    *outAngle = atan2f(-ry, rx);

    return 1;
}

void rcl_select(float px, float py) {
    float speed = rcl_walk_step * 60.0f;
    float reach = 0.0f;
    int i = 0;

    if (speed < 120.0f) speed = 120.0f;
    if (speed > 1200.0f) speed = 1200.0f;

    reach = speed * RCL_HORIZON;
    rcl_sel_n = 0;

    for (i = 0; i < rcl_seg_count && rcl_sel_n < RCL_SEL_MAX; i++) {
        const rcl_seg_t *seg = &rcl_seg[i];
        float d = rcl_seg_dist(px, py, seg->ax, seg->ay, seg->bx, seg->by);

        if (d > reach + seg->inflatedR) continue;

        rcl_sel[rcl_sel_n++] = i;
    }
}

int rcl_drive(void) {
    uintptr_t ctrl = rcl_controller();

    rcl_measure();
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

    if (rcl_active) {
        rcl_tx_b = rcl_tx;
        rcl_ty_b = rcl_ty;
        rcl_hold = rcl_ticks_a;
        held = 1;
    } else if (!rcl_crit_reaction && rcl_hold && (rcl_ticks_a - rcl_hold) <= RCL_DATA_HOLD) {
        held = 1;
    }

    if (!held) {
        float escapeX = 0.0f;
        float escapeY = 0.0f;

        if (!RCL_ESCAPE) {
            rcl_stick(0, 0.0f, 0.0f);

            return 0;
        }

        if (!rcl_own(&ownX, &ownY)) return 0;
        if (!rcl_own_ok(ownX, ownY)) return 0;

        if (!rcl_threatened((float)ownX, (float)ownY)) {
            rcl_stick(0, 0.0f, 0.0f);

            return 0;
        }

        if (!rcl_freest((float)ownX, (float)ownY, &escapeX, &escapeY)) {
            rcl_stick(0, 0.0f, 0.0f);

            return 0;
        }

        dx = escapeX - (float)ownX;
        dy = escapeY - (float)ownY;
        len = sqrtf(dx * dx + dy * dy);

        if (len < 0.0001f) {
            rcl_stick(0, 0.0f, 0.0f);

            return 0;
        }

        rcl_stick(1, (float)RCL_STICK_SIGN * dx, (float)RCL_STICK_SIGN * dy);
        rcl_precision(ownX, ownY, dx, dy, 1);

        return 1;
    }

    if (!rcl_own(&ownX, &ownY)) return 0;
    if (!rcl_own_ok(ownX, ownY)) return 0;

    dx = (float)(rcl_tx_b - ownX);
    dy = (float)(rcl_ty_b - ownY);
    len = sqrtf(dx * dx + dy * dy);

    if (len >= 0.0001f) {
        dx /= len;
        dy /= len;
        rcl_unblock((float)ownX, (float)ownY,
                        rcl_step(), &dx, &dy);
        dx *= len;
        dy *= len;
    }

    {
        float step = RCL_STEP_c;

        step = rcl_step();

        if (len > step) {
            dx = dx / len * step;
            dy = dy / len * step;
            len = step;
        }
    }

    if (len < 0.0001f) {
        rcl_stick(0, 0.0f, 0.0f);
        rcl_applied(RCL_APPLIED_IDLE, RCL_APPLIED_IDLE);
        rcl_joy_knob(0.0f, 0.0f, 0);

        return 0;
    }

    {
        uintptr_t hctrl = rcl_controller();
        uint8_t hgate = 0;
        int32_t hid = -1;
        int human = 0;
        int threat = 0;

        if (hctrl) {
            rcl_read_bytes(hctrl + RCL_TOUCH_GATE_OFF, &hgate, sizeof(hgate));
            rcl_read_int(hctrl + RCL_TOUCH_ID_OFF, &hid);
        }

        human = (hgate == 1 || hid >= 0) ? 1 : 0;

        if (RCL_HUMAN && rcl_human_2) human = 1;

        threat = rcl_active ? 1 : 0;

        if (human) rcl_human++;

        if (threat || !human || !RCL_STICK_WHEN_FREE) {
            rcl_stick(1, (float)RCL_STICK_SIGN * dx, (float)RCL_STICK_SIGN * dy);
        } else {
        }
    }

    rcl_precision(ownX, ownY, dx, dy, 0);

    tx = ownX + (int32_t)((double)dx / (double)len * (double)RCL_REACH);
    ty = ownY + (int32_t)((double)dy / (double)len * (double)RCL_REACH);

    if (RCL_QUIET) {
        rcl_queue_skips++;
    } else if (!RCL_PAIR_ONLY) {
        if (RCL_STICK_ONLY) rcl_pos_skips++;
        else if (rcl_js_owns()) rcl_queue_skips++;
        else rcl_enqueue(tx, ty);
    } else {
    }

    if (!RCL_STICK_ONLY && !RCL_JS_NOPREDICT && !rcl_js_owns()) {
        rcl_predict(tx, ty);
    }

    rcl_applied(tx, ty);

    rcl_joy_knob(dx, dy, 1);

    if (RCL_TOUCH_FLAG && ctrl) {
        uint8_t gateNow = 0;
        int32_t stateNow = 0;
        int32_t idNow = 0;

        rcl_read_bytes(ctrl + RCL_TOUCH_GATE_OFF, &gateNow, sizeof(gateNow));
        rcl_read_int(ctrl + RCL_TOUCH_STATE_OFF, &stateNow);
        rcl_read_int(ctrl + RCL_TOUCH_ID_OFF, &idNow);

    }

    if (ctrl) {
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_X_OFF, &appX);
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_Y_OFF, &appY);
        rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &pairX);
        rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &pairY);

    }





    if (rcl_drive_logs < RCL_DRIVE_LOGS ||
        ((rcl_ticks_a % 60) == 0 && rcl_drive_logs < 240)) {
        rcl_drive_logs++;

    }

    return 1;
}
void rcl_precision(int32_t ownX, int32_t ownY, float dirX, float dirY, int escape) {
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

    if (!RCL_PRECISION) return;
    if (RCL_EVERY > 0 && (rcl_ticks_a % (uint64_t)RCL_EVERY) != 0) return;

    ctrl = rcl_controller();

    if (ctrl) {
        rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &ax);
        rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &ay);
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_X_OFF, &appX);
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (rcl_joystick) rcl_read_int(rcl_joystick + RCL_BS_MODE, &mode);

    if (rcl_pred_last) {
        rcl_read_int(rcl_pred_last + RCL_MODE_PREDICTX_OFF, &predX);
        rcl_read_int(rcl_pred_last + RCL_MODE_PREDICTY_OFF, &predY);
    }

    eta = rcl_eta_ms((float)ownX, (float)ownY);

    if (rcl_time) {
        uint64_t now = rcl_us();

        rcl_dec_us = (now >= rcl_time) ? (now - rcl_time) : 0;

        if (rcl_dec_us > rcl_dec_us_max) rcl_dec_us_max = rcl_dec_us;
        if (rcl_dec_us > RCL_SLOW_US) rcl_slow++;
    }

    if (rcl_build_tick >= 0) lag = (int)((int64_t)rcl_ticks_a - (int64_t)rcl_build_tick);

    {
        uintptr_t wrap = (uintptr_t)rcl_scene_object;
        uintptr_t cli = rcl_client();
        int32_t wAx = 0;
        int32_t wAy = 0;
        int32_t cAx = 0;
        int32_t cAy = 0;

        if (wrap) {
            rcl_read_int(wrap + RCL_CTRL_APPLIED_X_OFF, &wAx);
            rcl_read_int(wrap + RCL_CTRL_APPLIED_Y_OFF, &wAy);
        }

        if (cli) {
            rcl_read_int(cli + RCL_CTRL_APPLIED_X_OFF, &cAx);
            rcl_read_int(cli + RCL_CTRL_APPLIED_Y_OFF, &cAy);
        }

    }

}

int32_t rcl_stick_x = 0;

int32_t rcl_stick_y = 0;

int rcl_engaged_ticks = 0;

void rcl_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY) {
    (void)engaged;
    (void)haveOwn;
    (void)ownX;
    (void)ownY;
    (void)dirX;
    (void)dirY;
}

uintptr_t rcl_joy_knob_obj = 0;

uintptr_t rcl_joy_knob_pair = 0;



int rcl_joy_knob_logs = 0;

int rcl_joy_knob_on = 0;

static int rcl_joy_knob_miss = 0;

static uint8_t rcl_joy_knob_state_a = 0;

static uint8_t rcl_joy_knob_state_b = 0;

static int rcl_joy_knob_saved = 0;

static int rcl_joy_pair_read(uintptr_t obj, uintptr_t pair, float *kx, float *ky, float *cx, float *cy) {
    if (!obj) return 0;
    if (!rcl_read_float(obj + pair, kx)) return 0;
    if (!rcl_read_float(obj + pair + RCL_JOY_PAIR_Y, ky)) return 0;
    if (!rcl_read_float(obj + pair + RCL_JOY_PAIR_CEN, cx)) return 0;
    if (!rcl_read_float(obj + pair + RCL_JOY_PAIR_CEN + RCL_JOY_PAIR_Y, cy)) return 0;
    if (!(*kx > -RCL_JOY_COORD_LIMIT && *kx < RCL_JOY_COORD_LIMIT)) return 0;
    if (!(*ky > -RCL_JOY_COORD_LIMIT && *ky < RCL_JOY_COORD_LIMIT)) return 0;
    if (!(*cx > -RCL_JOY_COORD_LIMIT && *cx < RCL_JOY_COORD_LIMIT)) return 0;
    if (!(*cy > -RCL_JOY_COORD_LIMIT && *cy < RCL_JOY_COORD_LIMIT)) return 0;
    if (fabsf(*cx) < RCL_JOY_MIN_CENTER && fabsf(*cy) < RCL_JOY_MIN_CENTER) return 0;

    return 1;
}

static uintptr_t rcl_joy_knob_target(uintptr_t *pairOut, float *cx, float *cy, float *kx, float *ky) {
    uintptr_t base = rcl_bs();
    uintptr_t scene = (uintptr_t)rcl_scene_object;
    uintptr_t hop = 0;
    uintptr_t list[RCL_JOY_TARGETS];
    uintptr_t pair[RCL_JOY_PAIR_N];
    int i = 0;
    int j = 0;

    list[0] = scene;
    list[1] = 0;
    list[2] = base;
    list[3] = 0;

    if (scene && rcl_read_ptr(scene + RCL_OFF_BATTLE_SCREEN, (void **)&hop) && hop) list[1] = hop;
    if (base && rcl_read_ptr(base + RCL_JOY_TARGET_OFF, (void **)&hop) && hop) list[3] = hop;

    pair[0] = RCL_JOY_PAIR_a;
    pair[1] = RCL_JOY_PAIR_b;
    pair[2] = RCL_JOY_PAIR_c;

    for (i = 0; i < RCL_JOY_TARGETS; i++) {
        if (!list[i]) continue;

        for (j = 0; j < RCL_JOY_PAIR_N; j++) {
            if (!rcl_joy_pair_read(list[i], pair[j], kx, ky, cx, cy)) continue;

            *pairOut = pair[j];

            return list[i];
        }
    }

    return 0;
}

void rcl_joy_knob(float dirX, float dirY, int on) {
    uintptr_t obj = 0;
    uintptr_t pair = 0;
    float kx = 0.0f;
    float ky = 0.0f;
    float cx = 0.0f;
    float cy = 0.0f;
    float len = 0.0f;
    uint8_t one = 1;

    if (!RCL_JOY_KNOB_ON) return;

    if (rcl_joy_knob_obj && !rcl_joy_pair_read(rcl_joy_knob_obj, rcl_joy_knob_pair, &kx, &ky, &cx, &cy)) {
        rcl_joy_knob_obj = 0;
    }

    if (!rcl_joy_knob_obj) {
        obj = rcl_joy_knob_target(&pair, &cx, &cy, &kx, &ky);

        if (!obj) {
            if (rcl_joy_knob_miss < RCL_JOY_KNOB_LOGS) {
                uintptr_t b = rcl_bs();
                uintptr_t s = (uintptr_t)rcl_scene_object;
                uintptr_t h = 0;

                rcl_joy_knob_miss++;

                if (b) rcl_read_ptr(b + RCL_JOY_TARGET_OFF, (void **)&h);

            }

            return;
        }

        rcl_joy_knob_obj = obj;
        rcl_joy_knob_pair = pair;
    } else {
        obj = rcl_joy_knob_obj;
        pair = rcl_joy_knob_pair;
    }

    len = sqrtf(dirX * dirX + dirY * dirY);

    if (on && len > RCL_JOY_EPS) {
        kx = cx + dirX / len * RCL_JOY_KNOB_MAG;
        ky = cy + dirY / len * RCL_JOY_KNOB_MAG;
    } else {
        kx = cx;
        ky = cy;
    }

    if (!RCL_JOY_KNOB_WRITE) {

        return;
    }

    if (!rcl_write_float(obj + pair, kx)) return;

    rcl_write_float(obj + pair + RCL_JOY_PAIR_Y, ky);

    if (!rcl_joy_knob_saved) {
        rcl_read_bytes(obj + RCL_JOY_DRAG_OFF, &rcl_joy_knob_state_a, sizeof(rcl_joy_knob_state_a));
        rcl_read_bytes(obj + RCL_JOY_DRAG2_OFF, &rcl_joy_knob_state_b, sizeof(rcl_joy_knob_state_b));
        rcl_joy_knob_saved = 1;
    }

    if (on) {
        rcl_write_bytes(obj + RCL_JOY_DRAG_OFF, &one, sizeof(one));
        rcl_write_bytes(obj + RCL_JOY_DRAG2_OFF, &one, sizeof(one));
    } else {
        rcl_write_bytes(obj + RCL_JOY_DRAG_OFF, &rcl_joy_knob_state_a, sizeof(rcl_joy_knob_state_a));
        rcl_write_bytes(obj + RCL_JOY_DRAG2_OFF, &rcl_joy_knob_state_b, sizeof(rcl_joy_knob_state_b));
    }

    rcl_joy_knob_on = on;

    if (rcl_joy_knob_logs < RCL_JOY_KNOB_LOGS) {
        float bx = 0.0f;
        float by = 0.0f;
        uint8_t s1 = 0;
        uint8_t s2 = 0;

        rcl_joy_knob_logs++;

        rcl_read_float(obj + pair, &bx);
        rcl_read_float(obj + pair + RCL_JOY_PAIR_Y, &by);
        rcl_read_bytes(obj + RCL_JOY_DRAG_OFF, &s1, sizeof(s1));
        rcl_read_bytes(obj + RCL_JOY_DRAG2_OFF, &s2, sizeof(s2));


    }
}

void rcl_applied(int32_t ax, int32_t ay) {
    if (!RCL_APPLY_WRITE) return;
    uintptr_t ctrl = rcl_controller();
    int32_t backX = 0;
    int32_t backY = 0;

    if (!ctrl) return;

    if (!rcl_write_bytes(ctrl + RCL_CTRL_APPLIED_X_OFF, &ax, sizeof(ax))) return;

    {
        uint8_t latch = (uint8_t)RCL_CTRL_LATCH_VAL;
        int32_t dirty = (int32_t)RCL_CTRL_DIRTY_VAL;

        rcl_write_bytes(ctrl + RCL_CTRL_APPLIED_Y_OFF, &ay, sizeof(ay));
        rcl_write_bytes(ctrl + RCL_CTRL_LATCH_OFF, &latch, sizeof(latch));
        rcl_write_bytes(ctrl + RCL_CTRL_DIRTY_OFF, &dirty, sizeof(dirty));
    }


    if (rcl_read_int(ctrl + RCL_CTRL_APPLIED_X_OFF, &backX) &&
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_Y_OFF, &backY) &&
        backX == ax && backY == ay) {
    } else {
    }
}


static void rcl_stick_push(int engaged, float dirX, float dirY) {
    uintptr_t bs = rcl_bs();
    uintptr_t bsm = 0;
    float ox = 0.0f;
    float oy = 0.0f;
    float len = 0.0f;
    float nx = 0.0f;
    float ny = 0.0f;
    float backX = 0.0f;
    float backY = 0.0f;

    if (!RCL_STICK_PUSH) return;
    if (!bs) return;
    if (!rcl_read_ptr(bs + RCL_JOY_TARGET_OFF, (void **)&bsm) || !bsm) return;
    if (!rcl_read_float(bsm + 0xa48, &ox)) return;
    if (!rcl_read_float(bsm + 0xa4c, &oy)) return;

    if (!engaged) return;

    if (RCL_STICK_HOLD) {
        float hx = 0.0f;
        float hy = 0.0f;

        if (!rcl_read_float(bsm + 0xa40, &hx)) return;
        if (!rcl_read_float(bsm + 0xa44, &hy)) return;
        if (__builtin_fabsf(hx - ox) < 0.5f && __builtin_fabsf(hy - oy) < 0.5f) return;
    }

    if (engaged) {
        len = __builtin_sqrtf(dirX * dirX + dirY * dirY);

        if (len > 0.0001f) {
            nx = dirX / len;
            ny = dirY / len;
        }
    }

    {
        float kx = 0.0f;
        float ky = 0.0f;
        float bx = 0.0f;
        float by = 0.0f;

        if (RCL_STICK_INPUT && rcl_read_float(bsm + 0x9d8, &kx) && rcl_read_float(bsm + 0x9dc, &ky)) {
            float ix = kx + nx * RCL_STICK_RADIUS;
            float iy = ky + ny * RCL_STICK_RADIUS;

            rcl_write_float(bsm + 0x9d0, ix);
            rcl_write_float(bsm + 0x9d4, iy);
        }

        if (RCL_STICK_KNOB) {
            rcl_write_float(bsm + 0xa40, ox + nx * RCL_STICK_RADIUS);
            rcl_write_float(bsm + 0xa44, oy + ny * RCL_STICK_RADIUS);
        }

        rcl_read_float(bsm + 0x9d0, &bx);
        rcl_read_float(bsm + 0x9d4, &by);

    }

    if (RCL_STICK_HOLD_WRITE) {
        uint8_t held = 1;

        rcl_write_bytes(bsm + 0xf78, &held, sizeof(held));
        rcl_write_bytes(bsm + 0xf80, &held, sizeof(held));
        rcl_write_bytes(bsm + 0xf9c, &held, sizeof(held));
        rcl_write_bytes(bsm + 0xf9e, &held, sizeof(held));
    }

}

void rcl_stick(int engaged, float dirX, float dirY) {
    rcl_stick_push(engaged, dirX, dirY);

    if (!RCL_V245_STICK && !RCL_JS_STICK) return;
    uintptr_t ctrl = rcl_controller();
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t ownX = 0;
    int32_t ownY = 0;
    int want = 0;
    int haveOwn = 0;
    float len = 0.0f;

    haveOwn = rcl_own(&ownX, &ownY);
    rcl_drag(engaged, haveOwn, ownX, ownY, dirX, dirY);

    if (!RCL_STICK_RAW_WRITE) return;
    if (!rcl_ctrl_ok(ctrl)) return;

    if (engaged) {
        len = sqrtf(dirX * dirX + dirY * dirY);

        if (len >= 0.0001f) {
            want = 1;

            if (RCL_PAIR_RAW && !RCL_JS_STICK) {
                double scale = 1.0;

                if ((double)len > (double)RCL_PAIR_MAX) {
                    scale = (double)RCL_PAIR_MAX / (double)len;
                }

                wx = (int32_t)((double)dirX * scale);
                wy = (int32_t)((double)dirY * scale);
            } else {
                wx = (int32_t)((double)dirX / (double)len * (double)RCL_JOY_MAG);
                wy = (int32_t)((double)dirY / (double)len * (double)RCL_JOY_MAG);
            }

            rcl_stick_hold = 1;
            rcl_stick_tick = rcl_ticks_a;
            rcl_engaged_ticks++;
            rcl_sum_x += wx;
            rcl_sum_y += wy;
        }
    }

    if (!want) {
        uintptr_t relCtrl = rcl_controller();
        int32_t relX = 0;
        int32_t relY = 0;

        if (!rcl_stick_hold) return;
        if (RCL_JS_STICK && rcl_ticks_a < rcl_stick_tick + RCL_JS_HOLD) return;
        if (!RCL_RAGE && rcl_stick_tick + RCL_STICK_TTL > rcl_ticks_a) return;

        rcl_stick_hold = 0;

        if (relCtrl && rcl_read_int(relCtrl + RCL_CTRL_RAW_X_OFF, &relX) &&
            rcl_read_int(relCtrl + RCL_CTRL_RAW_Y_OFF, &relY)) {
            if (relX != rcl_stick_x || relY != rcl_stick_y) return;
        }
    }

    rcl_stick_x = wx;
    rcl_stick_y = wy;

    if (RCL_STICK_RAW_WRITE && !(RCL_RETIRE && rcl_accepted && !RCL_JS_STICK)) {
        if (!rcl_write_bytes(ctrl + RCL_CTRL_RAW_X_OFF, &wx, sizeof(wx))) return;

        rcl_write_bytes(ctrl + RCL_CTRL_RAW_Y_OFF, &wy, sizeof(wy));


        if (want) {
            rcl_joy_knob(dirX, dirY, 1);
        } else if (rcl_joy_knob_on) {
            rcl_joy_knob(0.0f, 0.0f, 0);
        }
    }

    {
        static int stickLogs = 0;

        if (stickLogs < RCL_DRIVE_LOGS) {
            int32_t backX = 0;
            int32_t backY = 0;
            int32_t appX = 0;
            int32_t appY = 0;
            uint8_t mv = 0;
            uint8_t al = 0;
            uint8_t lt = 0;
            uint8_t dt = 0;

            stickLogs++;

            rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &backX);
            rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &backY);
            rcl_read_int(ctrl + RCL_CTRL_APPLIED_X_OFF, &appX);
            rcl_read_int(ctrl + RCL_CTRL_APPLIED_Y_OFF, &appY);
            rcl_read_bytes(ctrl + RCL_CTRL_MOVE_OFF, &mv, sizeof(mv));
            rcl_read_bytes(ctrl + RCL_CTRL_ALIVE_OFF, &al, sizeof(al));
            rcl_read_bytes(ctrl + RCL_CTRL_LATCH_OFF, &lt, sizeof(lt));
            rcl_read_bytes(ctrl + RCL_CTRL_DIRTY_OFF, &dt, sizeof(dt));

        }
    }
}

void rcl_route(int engaged) {
    uintptr_t ctrl = rcl_controller();
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t backX = 0;
    int32_t backY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    int dx = 0;
    int dy = 0;
    int moved = 0;
    int ours = rcl_engaged_ticks;
    long long sumX = 0;
    long long sumY = 0;
    float sLen = 0.0f;
    float mLen = 0.0f;
    float dot = 0.0f;
    const char *align = "no-move";

    if ((rcl_ticks_a % 60) != 0) return;
    if (!rcl_own(&ownX, &ownY)) return;

    rcl_engaged_ticks = 0;

    if (ctrl) {
        rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &backX);
        rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &backY);
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_X_OFF, &appX);
        rcl_read_int(ctrl + RCL_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (rcl_route_seeded) {
        dx = (int)(ownX - rcl_last_own_x);
        dy = (int)(ownY - rcl_last_own_y);

        moved = (int)sqrtf((float)(dx * dx + dy * dy));
    }

    sumX = rcl_sum_x;
    sumY = rcl_sum_y;
    rcl_sum_x = 0;
    rcl_sum_y = 0;

    sLen = sqrtf((float)(sumX * sumX + sumY * sumY));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (sLen > 0.5f && mLen > 0.5f) {
        dot = ((float)sumX / sLen) * ((float)dx / mLen) + ((float)sumY / sLen) * ((float)dy / mLen);

        if (dot > 0.7f) align = "same";
        else if (dot < -0.7f) align = "opposite";
        else align = "unrelated";
    }

    static int rcl_route_engaged_prev = -1;
    rcl_route_seeded = 1;
    rcl_last_own_x = ownX;
    rcl_last_own_y = ownY;

    {
        if (engaged != rcl_route_engaged_prev) {
            rcl_route_engaged_prev = engaged;

        }
    }
}

float rcl_walk_step = RCL_STEP_b;

uint64_t rcl_ticks_a = 0;

long long rcl_sum_x = 0;

long long rcl_sum_y = 0;
