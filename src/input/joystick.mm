#include "titanox.h"

void tnx_applied(int32_t ax, int32_t ay);

tnx_seg_t t_seg[TNX_SEG_MAX];

int t_seg_count = 0;

uintptr_t tnx_bs(void) {
    return tnx_client();
}

int tnx_joy_read(uintptr_t bs, float *ax, float *ay, float *bx, float *by,
                             uint32_t *mode, float *cs, float *sn) {
    int32_t m = 0;

    if (!bs) return 0;

    if (!tnx_read_float(bs + TNX_BS_AX, ax)) return 0;
    if (!tnx_read_float(bs + TNX_BS_AY, ay)) return 0;
    if (!tnx_read_float(bs + TNX_BS_BX, bx)) return 0;
    if (!tnx_read_float(bs + TNX_BS_BY, by)) return 0;

    *mode = 0;

    if (tnx_read_int(bs + TNX_BS_MODE, &m)) *mode = (uint32_t)m;

    if (!tnx_read_float(bs + TNX_BS_COS, cs)) *cs = 1.0f;
    if (!tnx_read_float(bs + TNX_BS_SIN, sn)) *sn = 0.0f;

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

void tnx_select(float px, float py) {
    float speed = t_walk_step * 60.0f;
    float reach = 0.0f;
    int i = 0;

    if (speed < 120.0f) speed = 120.0f;
    if (speed > 1200.0f) speed = 1200.0f;

    reach = speed * TNX_HORIZON;
    t_sel_n = 0;

    for (i = 0; i < t_seg_count && t_sel_n < TNX_SEL_MAX; i++) {
        const tnx_seg_t *seg = &t_seg[i];
        float d = tnx_seg_dist(px, py, seg->ax, seg->ay, seg->bx, seg->by);

        if (d > reach + seg->inflatedR) continue;

        t_sel[t_sel_n++] = i;
    }
}

int tnx_drive(void) {
    uintptr_t ctrl = tnx_controller();

    tnx_measure();
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

    if (t_active) {
        t_tx_b = t_tx;
        t_ty_b = t_ty;
        t_hold = t_ticks_a;
        held = 1;
    } else if (!t_crit_reaction && t_hold && (t_ticks_a - t_hold) <= TNX_DATA_HOLD) {
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
            tnx_stick(0, 0.0f, 0.0f);

            return 0;
        }

        tnx_stick(1, (float)TNX_STICK_SIGN * dx, (float)TNX_STICK_SIGN * dy);
        tnx_precision(ownX, ownY, dx, dy, 1);

        return 1;
    }

    if (!tnx_own(&ownX, &ownY)) return 0;
    if (!tnx_own_ok(ownX, ownY)) return 0;

    dx = (float)(t_tx_b - ownX);
    dy = (float)(t_ty_b - ownY);
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
        float step = TNX_STEP_c;

        step = tnx_step();

        if (len > step) {
            dx = dx / len * step;
            dy = dy / len * step;
            len = step;
        }
    }

    if (len < 0.0001f) {
        tnx_stick(0, 0.0f, 0.0f);
        tnx_applied(TNX_APPLIED_IDLE, TNX_APPLIED_IDLE);
        tnx_joy_knob(0.0f, 0.0f, 0);

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
            tnx_read_int(hctrl + TNX_TOUCH_ID_OFF, &hid);
        }

        human = (hgate == 1 || hid >= 0) ? 1 : 0;

        if (TNX_HUMAN && t_human_2) human = 1;

        threat = t_active ? 1 : 0;

        if (human) t_human++;

        if (threat || !human || !TNX_STICK_WHEN_FREE) {
            tnx_stick(1, (float)TNX_STICK_SIGN * dx, (float)TNX_STICK_SIGN * dy);
        } else {
        }
    }

    tnx_precision(ownX, ownY, dx, dy, 0);

    tx = ownX + (int32_t)((double)dx / (double)len * (double)TNX_REACH);
    ty = ownY + (int32_t)((double)dy / (double)len * (double)TNX_REACH);

    if (TNX_QUIET) {
        t_queue_skips++;
    } else if (!TNX_PAIR_ONLY) {
        if (TNX_STICK_ONLY) t_pos_skips++;
        else if (tnx_js_owns()) t_queue_skips++;
        else tnx_enqueue(tx, ty);
    } else {
    }

    if (!TNX_STICK_ONLY && !TNX_JS_NOPREDICT && !tnx_js_owns()) {
        tnx_predict(tx, ty);
    }

    tnx_applied(tx, ty);

    tnx_joy_knob(dx, dy, 1);

    if (TNX_TOUCH_FLAG && ctrl) {
        uint8_t gateNow = 0;
        int32_t stateNow = 0;
        int32_t idNow = 0;

        tnx_read_bytes(ctrl + TNX_TOUCH_GATE_OFF, &gateNow, sizeof(gateNow));
        tnx_read_int(ctrl + TNX_TOUCH_STATE_OFF, &stateNow);
        tnx_read_int(ctrl + TNX_TOUCH_ID_OFF, &idNow);

    }

    if (ctrl) {
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
        tnx_read_int(ctrl + TNX_CTRL_RAW_X_OFF, &pairX);
        tnx_read_int(ctrl + TNX_CTRL_RAW_Y_OFF, &pairY);

    }





    if (t_drive_logs < TNX_DRIVE_LOGS ||
        ((t_ticks_a % 60) == 0 && t_drive_logs < 240)) {
        t_drive_logs++;

    }

    return 1;
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
    if (TNX_EVERY > 0 && (t_ticks_a % (uint64_t)TNX_EVERY) != 0) return;

    ctrl = tnx_controller();

    if (ctrl) {
        tnx_read_int(ctrl + TNX_CTRL_RAW_X_OFF, &ax);
        tnx_read_int(ctrl + TNX_CTRL_RAW_Y_OFF, &ay);
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (t_joystick) tnx_read_int(t_joystick + TNX_BS_MODE, &mode);

    if (t_pred_last) {
        tnx_read_int(t_pred_last + TNX_MODE_PREDICTX_OFF, &predX);
        tnx_read_int(t_pred_last + TNX_MODE_PREDICTY_OFF, &predY);
    }

    eta = tnx_eta_ms((float)ownX, (float)ownY);

    if (t_time) {
        uint64_t now = tnx_us();

        t_dec_us = (now >= t_time) ? (now - t_time) : 0;

        if (t_dec_us > t_dec_us_max) t_dec_us_max = t_dec_us;
        if (t_dec_us > TNX_SLOW_US) t_slow++;
    }

    if (t_build_tick >= 0) lag = (int)((int64_t)t_ticks_a - (int64_t)t_build_tick);

    {
        uintptr_t wrap = (uintptr_t)t_scene_object;
        uintptr_t cli = tnx_client();
        int32_t wAx = 0;
        int32_t wAy = 0;
        int32_t cAx = 0;
        int32_t cAy = 0;

        if (wrap) {
            tnx_read_int(wrap + TNX_CTRL_APPLIED_X_OFF, &wAx);
            tnx_read_int(wrap + TNX_CTRL_APPLIED_Y_OFF, &wAy);
        }

        if (cli) {
            tnx_read_int(cli + TNX_CTRL_APPLIED_X_OFF, &cAx);
            tnx_read_int(cli + TNX_CTRL_APPLIED_Y_OFF, &cAy);
        }

    }

}

int32_t t_stick_x = 0;

int32_t t_stick_y = 0;

int t_engaged_ticks = 0;

void tnx_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY) {
    (void)engaged;
    (void)haveOwn;
    (void)ownX;
    (void)ownY;
    (void)dirX;
    (void)dirY;
}

uintptr_t t_joy_knob_obj = 0;

uintptr_t t_joy_knob_pair = 0;


int t_joy_knob_ok = 0;

int t_joy_knob_logs = 0;

int t_joy_knob_on = 0;

static int t_joy_knob_miss = 0;

static uint8_t t_joy_knob_state_a = 0;

static uint8_t t_joy_knob_state_b = 0;

static int t_joy_knob_saved = 0;

static int tnx_joy_pair_read(uintptr_t obj, uintptr_t pair, float *kx, float *ky, float *cx, float *cy) {
    if (!obj) return 0;
    if (!tnx_read_float(obj + pair, kx)) return 0;
    if (!tnx_read_float(obj + pair + TNX_JOY_PAIR_Y, ky)) return 0;
    if (!tnx_read_float(obj + pair + TNX_JOY_PAIR_CEN, cx)) return 0;
    if (!tnx_read_float(obj + pair + TNX_JOY_PAIR_CEN + TNX_JOY_PAIR_Y, cy)) return 0;
    if (!(*kx > -TNX_JOY_COORD_LIMIT && *kx < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(*ky > -TNX_JOY_COORD_LIMIT && *ky < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(*cx > -TNX_JOY_COORD_LIMIT && *cx < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(*cy > -TNX_JOY_COORD_LIMIT && *cy < TNX_JOY_COORD_LIMIT)) return 0;
    if (fabsf(*cx) < TNX_JOY_MIN_CENTER && fabsf(*cy) < TNX_JOY_MIN_CENTER) return 0;

    return 1;
}

static uintptr_t tnx_joy_knob_target(uintptr_t *pairOut, float *cx, float *cy, float *kx, float *ky) {
    uintptr_t base = tnx_bs();
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t hop = 0;
    uintptr_t list[TNX_JOY_TARGETS];
    uintptr_t pair[TNX_JOY_PAIR_N];
    int i = 0;
    int j = 0;

    list[0] = scene;
    list[1] = 0;
    list[2] = base;
    list[3] = 0;

    if (scene && tnx_read_ptr(scene + TNX_OFF_BATTLE_SCREEN, (void **)&hop) && hop) list[1] = hop;
    if (base && tnx_read_ptr(base + TNX_JOY_TARGET_OFF, (void **)&hop) && hop) list[3] = hop;

    pair[0] = TNX_JOY_PAIR_a;
    pair[1] = TNX_JOY_PAIR_b;
    pair[2] = TNX_JOY_PAIR_c;

    for (i = 0; i < TNX_JOY_TARGETS; i++) {
        if (!list[i]) continue;

        for (j = 0; j < TNX_JOY_PAIR_N; j++) {
            if (!tnx_joy_pair_read(list[i], pair[j], kx, ky, cx, cy)) continue;

            *pairOut = pair[j];

            return list[i];
        }
    }

    return 0;
}

void tnx_joy_knob(float dirX, float dirY, int on) {
    uintptr_t obj = 0;
    uintptr_t pair = 0;
    float kx = 0.0f;
    float ky = 0.0f;
    float cx = 0.0f;
    float cy = 0.0f;
    float len = 0.0f;
    uint8_t one = 1;

    if (!TNX_JOY_KNOB_ON) return;

    if (t_joy_knob_obj && !tnx_joy_pair_read(t_joy_knob_obj, t_joy_knob_pair, &kx, &ky, &cx, &cy)) {
        t_joy_knob_obj = 0;
    }

    if (!t_joy_knob_obj) {
        obj = tnx_joy_knob_target(&pair, &cx, &cy, &kx, &ky);

        if (!obj) {
            if (t_joy_knob_miss < TNX_JOY_KNOB_LOGS) {
                uintptr_t b = tnx_bs();
                uintptr_t s = (uintptr_t)t_scene_object;
                uintptr_t h = 0;

                t_joy_knob_miss++;

                if (b) tnx_read_ptr(b + TNX_JOY_TARGET_OFF, (void **)&h);

            }

            return;
        }

        t_joy_knob_obj = obj;
        t_joy_knob_pair = pair;
    } else {
        obj = t_joy_knob_obj;
        pair = t_joy_knob_pair;
    }

    len = sqrtf(dirX * dirX + dirY * dirY);

    if (on && len > TNX_JOY_EPS) {
        kx = cx + dirX / len * TNX_JOY_KNOB_MAG;
        ky = cy + dirY / len * TNX_JOY_KNOB_MAG;
    } else {
        kx = cx;
        ky = cy;
    }

    if (!TNX_JOY_KNOB_WRITE) {

        return;
    }

    if (!tnx_write_float(obj + pair, kx)) return;

    tnx_write_float(obj + pair + TNX_JOY_PAIR_Y, ky);

    if (!t_joy_knob_saved) {
        tnx_read_bytes(obj + TNX_JOY_DRAG_OFF, &t_joy_knob_state_a, sizeof(t_joy_knob_state_a));
        tnx_read_bytes(obj + TNX_JOY_DRAG2_OFF, &t_joy_knob_state_b, sizeof(t_joy_knob_state_b));
        t_joy_knob_saved = 1;
    }

    if (on) {
        tnx_write_bytes(obj + TNX_JOY_DRAG_OFF, &one, sizeof(one));
        tnx_write_bytes(obj + TNX_JOY_DRAG2_OFF, &one, sizeof(one));
    } else {
        tnx_write_bytes(obj + TNX_JOY_DRAG_OFF, &t_joy_knob_state_a, sizeof(t_joy_knob_state_a));
        tnx_write_bytes(obj + TNX_JOY_DRAG2_OFF, &t_joy_knob_state_b, sizeof(t_joy_knob_state_b));
    }

    t_joy_knob_on = on;

    if (t_joy_knob_logs < TNX_JOY_KNOB_LOGS) {
        float bx = 0.0f;
        float by = 0.0f;
        uint8_t s1 = 0;
        uint8_t s2 = 0;

        t_joy_knob_logs++;

        tnx_read_float(obj + pair, &bx);
        tnx_read_float(obj + pair + TNX_JOY_PAIR_Y, &by);
        tnx_read_bytes(obj + TNX_JOY_DRAG_OFF, &s1, sizeof(s1));
        tnx_read_bytes(obj + TNX_JOY_DRAG2_OFF, &s2, sizeof(s2));

        if (bx == kx && by == ky) t_joy_knob_ok++;

    }
}

void tnx_applied(int32_t ax, int32_t ay) {
    if (!TNX_APPLY_WRITE) return;
    uintptr_t ctrl = tnx_controller();
    int32_t backX = 0;
    int32_t backY = 0;

    if (!ctrl) return;

    if (!tnx_write_bytes(ctrl + TNX_CTRL_APPLIED_X_OFF, &ax, sizeof(ax))) return;

    {
        uint8_t latch = (uint8_t)TNX_CTRL_LATCH_VAL;
        int32_t dirty = (int32_t)TNX_CTRL_DIRTY_VAL;

        tnx_write_bytes(ctrl + TNX_CTRL_APPLIED_Y_OFF, &ay, sizeof(ay));
        tnx_write_bytes(ctrl + TNX_CTRL_LATCH_OFF, &latch, sizeof(latch));
        tnx_write_bytes(ctrl + TNX_CTRL_DIRTY_OFF, &dirty, sizeof(dirty));
    }


    if (tnx_read_int(ctrl + TNX_CTRL_APPLIED_X_OFF, &backX) &&
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_Y_OFF, &backY) &&
        backX == ax && backY == ay) {
    } else {
    }
}


static void tnx_stick_push(int engaged, float dirX, float dirY) {
    uintptr_t bs = tnx_bs();
    uintptr_t bsm = 0;
    float ox = 0.0f;
    float oy = 0.0f;
    float len = 0.0f;
    float nx = 0.0f;
    float ny = 0.0f;
    float backX = 0.0f;
    float backY = 0.0f;

    if (!TNX_STICK_PUSH) return;
    if (!bs) return;
    if (!tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&bsm) || !bsm) return;
    if (!tnx_read_float(bsm + 0xa48, &ox)) return;
    if (!tnx_read_float(bsm + 0xa4c, &oy)) return;

    if (!engaged) return;

    if (TNX_STICK_HOLD) {
        float hx = 0.0f;
        float hy = 0.0f;

        if (!tnx_read_float(bsm + 0xa40, &hx)) return;
        if (!tnx_read_float(bsm + 0xa44, &hy)) return;
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

        if (TNX_STICK_INPUT && tnx_read_float(bsm + 0x9d8, &kx) && tnx_read_float(bsm + 0x9dc, &ky)) {
            float ix = kx + nx * TNX_STICK_RADIUS;
            float iy = ky + ny * TNX_STICK_RADIUS;

            tnx_write_float(bsm + 0x9d0, ix);
            tnx_write_float(bsm + 0x9d4, iy);
        }

        if (TNX_STICK_KNOB) {
            tnx_write_float(bsm + 0xa40, ox + nx * TNX_STICK_RADIUS);
            tnx_write_float(bsm + 0xa44, oy + ny * TNX_STICK_RADIUS);
        }

        tnx_read_float(bsm + 0x9d0, &bx);
        tnx_read_float(bsm + 0x9d4, &by);

    }

    if (TNX_STICK_HOLD_WRITE) {
        uint8_t held = 1;

        tnx_write_bytes(bsm + 0xf78, &held, sizeof(held));
        tnx_write_bytes(bsm + 0xf80, &held, sizeof(held));
        tnx_write_bytes(bsm + 0xf9c, &held, sizeof(held));
        tnx_write_bytes(bsm + 0xf9e, &held, sizeof(held));
    }

}

void tnx_stick(int engaged, float dirX, float dirY) {
    tnx_stick_push(engaged, dirX, dirY);

    if (!TNX_V245_STICK && !TNX_JS_STICK) return;
    uintptr_t ctrl = tnx_controller();
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t ownX = 0;
    int32_t ownY = 0;
    int want = 0;
    int haveOwn = 0;
    float len = 0.0f;

    haveOwn = tnx_own(&ownX, &ownY);
    tnx_drag(engaged, haveOwn, ownX, ownY, dirX, dirY);

    if (!TNX_STICK_RAW_WRITE) return;
    if (!tnx_ctrl_ok(ctrl)) return;

    if (engaged) {
        len = sqrtf(dirX * dirX + dirY * dirY);

        if (len >= 0.0001f) {
            want = 1;

            if (TNX_PAIR_RAW && !TNX_JS_STICK) {
                double scale = 1.0;

                if ((double)len > (double)TNX_PAIR_MAX) {
                    scale = (double)TNX_PAIR_MAX / (double)len;
                }

                wx = (int32_t)((double)dirX * scale);
                wy = (int32_t)((double)dirY * scale);
            } else {
                wx = (int32_t)((double)dirX / (double)len * (double)TNX_JOY_MAG);
                wy = (int32_t)((double)dirY / (double)len * (double)TNX_JOY_MAG);
            }

            t_stick_hold = 1;
            t_stick_tick = t_ticks_a;
            t_engaged_ticks++;
            t_sum_x += wx;
            t_sum_y += wy;
        }
    }

    if (!want) {
        uintptr_t relCtrl = tnx_controller();
        int32_t relX = 0;
        int32_t relY = 0;

        if (!t_stick_hold) return;
        if (TNX_JS_STICK && t_ticks_a < t_stick_tick + TNX_JS_HOLD) return;
        if (!TNX_RAGE && t_stick_tick + TNX_STICK_TTL > t_ticks_a) return;

        t_stick_hold = 0;

        if (relCtrl && tnx_read_int(relCtrl + TNX_CTRL_RAW_X_OFF, &relX) &&
            tnx_read_int(relCtrl + TNX_CTRL_RAW_Y_OFF, &relY)) {
            if (relX != t_stick_x || relY != t_stick_y) return;
        }
    }

    t_stick_x = wx;
    t_stick_y = wy;

    if (TNX_STICK_RAW_WRITE && !(TNX_RETIRE && t_accepted && !TNX_JS_STICK)) {
        if (!tnx_write_bytes(ctrl + TNX_CTRL_RAW_X_OFF, &wx, sizeof(wx))) return;

        tnx_write_bytes(ctrl + TNX_CTRL_RAW_Y_OFF, &wy, sizeof(wy));


        if (want) {
            tnx_joy_knob(dirX, dirY, 1);
        } else if (t_joy_knob_on) {
            tnx_joy_knob(0.0f, 0.0f, 0);
        }
    }

    {
        static int stickLogs = 0;

        if (stickLogs < TNX_DRIVE_LOGS) {
            int32_t backX = 0;
            int32_t backY = 0;
            int32_t appX = 0;
            int32_t appY = 0;
            uint8_t mv = 0;
            uint8_t al = 0;
            uint8_t lt = 0;
            uint8_t dt = 0;

            stickLogs++;

            tnx_read_int(ctrl + TNX_CTRL_RAW_X_OFF, &backX);
            tnx_read_int(ctrl + TNX_CTRL_RAW_Y_OFF, &backY);
            tnx_read_int(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
            tnx_read_int(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
            tnx_read_bytes(ctrl + TNX_CTRL_MOVE_OFF, &mv, sizeof(mv));
            tnx_read_bytes(ctrl + TNX_CTRL_ALIVE_OFF, &al, sizeof(al));
            tnx_read_bytes(ctrl + TNX_CTRL_LATCH_OFF, &lt, sizeof(lt));
            tnx_read_bytes(ctrl + TNX_CTRL_DIRTY_OFF, &dt, sizeof(dt));

        }
    }
}

void tnx_route(int engaged) {
    uintptr_t ctrl = tnx_controller();
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t backX = 0;
    int32_t backY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    int dx = 0;
    int dy = 0;
    int moved = 0;
    int ours = t_engaged_ticks;
    long long sumX = 0;
    long long sumY = 0;
    float sLen = 0.0f;
    float mLen = 0.0f;
    float dot = 0.0f;
    const char *align = "no-move";

    if ((t_ticks_a % 60) != 0) return;
    if (!tnx_own(&ownX, &ownY)) return;

    t_engaged_ticks = 0;

    if (ctrl) {
        tnx_read_int(ctrl + TNX_CTRL_RAW_X_OFF, &backX);
        tnx_read_int(ctrl + TNX_CTRL_RAW_Y_OFF, &backY);
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_int(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (t_route_seeded) {
        dx = (int)(ownX - t_last_own_x);
        dy = (int)(ownY - t_last_own_y);

        moved = (int)sqrtf((float)(dx * dx + dy * dy));
    }

    sumX = t_sum_x;
    sumY = t_sum_y;
    t_sum_x = 0;
    t_sum_y = 0;

    sLen = sqrtf((float)(sumX * sumX + sumY * sumY));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (sLen > 0.5f && mLen > 0.5f) {
        dot = ((float)sumX / sLen) * ((float)dx / mLen) + ((float)sumY / sLen) * ((float)dy / mLen);

        if (dot > 0.7f) align = "same";
        else if (dot < -0.7f) align = "opposite";
        else align = "unrelated";
    }

    static int t_route_engaged_prev = -1;
    t_route_seeded = 1;
    t_last_own_x = ownX;
    t_last_own_y = ownY;

    {
        if (engaged != t_route_engaged_prev) {
            t_route_engaged_prev = engaged;

        }
    }
}

float t_walk_step = TNX_STEP_b;

uint64_t t_ticks_a = 0;

long long t_sum_x = 0;

long long t_sum_y = 0;
