#include "titanox.h"

void tnx_applied_2(int32_t ax, int32_t ay);

tnx_seg_t t_seg[TNX_SEG_MAX];

int t_seg_count = 0;

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

float t_joy_drive_ax = 0.0f;

float t_joy_drive_ay = 0.0f;

float t_joy_drive_cx = 0.0f;

float t_joy_drive_cy = 0.0f;

int t_joy_drive_on = 0;

int t_joy_drive_ok = 0;

int tnx_joy_set(float dirX, float dirY, int on) {
    uintptr_t bs = tnx_bs();
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    int ok = 0;

    if (!TNX_JOY_DRIVE) return 0;
    if (!bs) return 0;
    if (!tnx_read_f32(bs + TNX_BS_AX, &ax)) return 0;
    if (!tnx_read_f32(bs + TNX_BS_AY, &ay)) return 0;
    if (!tnx_read_f32(bs + TNX_BS_BX, &bx)) return 0;
    if (!tnx_read_f32(bs + TNX_BS_BY, &by)) return 0;
    if (!(bx > -TNX_JOY_COORD_LIMIT && bx < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(by > -TNX_JOY_COORD_LIMIT && by < TNX_JOY_COORD_LIMIT)) return 0;
    if (bx == 0.0f && by == 0.0f) return 0;

    if (on) {
        ax = bx + dirX * TNX_JOY_RADIUS;
        ay = by + dirY * TNX_JOY_RADIUS;
    } else {
        ax = bx;
        ay = by;
    }

    ok = tnx_write_f32(bs + TNX_BS_AX, ax);
    ok = ok && tnx_write_f32(bs + TNX_BS_AY, ay);
    ok = ok && tnx_write_i32(bs + TNX_BS_MODE, on ? TNX_JOY_MODE_ON : TNX_JOY_MODE_OFF);

    t_joy_drive_ax = ax;
    t_joy_drive_ay = ay;
    t_joy_drive_cx = bx;
    t_joy_drive_cy = by;
    t_joy_drive_on = on;
    t_joy_drive_ok = ok ? 1 : 0;

    return t_joy_drive_ok;
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

    if (t_active_2) {
        t_tx_3 = t_tx;
        t_ty_3 = t_ty;
        t_hold = t_ticks_3;
        held = 1;
    } else if (!t_crit_reaction && t_hold && (t_ticks_3 - t_hold) <= TNX_DATA_HOLD) {
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
            t_dead_picks++;
            tnx_stick(0, 0.0f, 0.0f);

            return 0;
        }

        t_escapes++;
        tnx_stick(1, (float)TNX_STICK_SIGN * dx, (float)TNX_STICK_SIGN * dy);
        tnx_precision(ownX, ownY, dx, dy, 1);

        return 1;
    }

    if (!tnx_own(&ownX, &ownY)) return 0;
    if (!tnx_own_ok(ownX, ownY)) return 0;

    dx = (float)(t_tx_3 - ownX);
    dy = (float)(t_ty_3 - ownY);
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
            t_clamped++;
        }
    }

    if (len < 0.0001f) {
        t_dead_picks++;
        tnx_stick(0, 0.0f, 0.0f);
        tnx_applied_2(TNX_APPLIED_IDLE, TNX_APPLIED_IDLE);
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
            tnx_read_i32(hctrl + TNX_TOUCH_ID_OFF, &hid);
        }

        human = (hgate == 1 || hid >= 0) ? 1 : 0;

        if (TNX_HUMAN && t_human_2) human = 1;

        threat = t_active_2 ? 1 : 0;

        if (human) t_human++;

        if (threat || !human || !TNX_STICK_WHEN_FREE) {
            tnx_stick(1, (float)TNX_STICK_SIGN * dx, (float)TNX_STICK_SIGN * dy);
        } else {
            t_stick_skips++;
        }
    }

    tnx_precision(ownX, ownY, dx, dy, 0);

    tx = ownX + (int32_t)((double)dx / (double)len * (double)TNX_REACH);
    ty = ownY + (int32_t)((double)dy / (double)len * (double)TNX_REACH);

    if (TNX_QUIET) {
        t_queue_skips_2++;
        t_queue_calls++;
    } else if (!TNX_PAIR_ONLY) {
        if (TNX_STICK_ONLY) t_pos_skips++;
        else if (tnx_js_owns_3()) t_queue_skips_2++;
        else tnx_enqueue(tx, ty);
        t_queue_calls++;
    } else {
        t_queue_skips++;
    }

    if (!TNX_STICK_ONLY && !TNX_JS_NOPREDICT && !tnx_js_owns_3()) {
        tnx_predict(tx, ty);
    }

    tnx_applied_2(tx, ty);

    tnx_joy_knob(dx, dy, 1);

    if (TNX_TOUCH_FLAG && ctrl) {
        uint8_t gateNow = 0;
        int32_t stateNow = 0;
        int32_t idNow = 0;

        tnx_read_bytes(ctrl + TNX_TOUCH_GATE_OFF, &gateNow, sizeof(gateNow));
        tnx_read_i32(ctrl + TNX_TOUCH_STATE_OFF, &stateNow);
        tnx_read_i32(ctrl + TNX_TOUCH_ID_OFF, &idNow);

        if (t_flag_logs < TNX_FLAG_LOGS) {
            t_flag_logs++;

            TNX_LOGX("touch gate=%d state=%d id=%d writes=%llu idWrites=%llu own=(%d,%d) applied=(%d,%d) - "
                      "gate is the byte the engine's own move function tests first, and this build reads "
                      "it but never writes it any more: setting it sends the engine down the touch "
                      "branch, which returns before the branch that reads the drag, so claiming a drag "
                      "was the opposite of driving one, state and id are the rest of the touch "
                      "bookkeeping, and applied is now only read back so this line can show the engine "
                      "moving it instead of this build",
                     gateNow, stateNow, idNow, (unsigned long long)t_gate_writes,
                     (unsigned long long)t_touchid_writes, ownX, ownY, appX, appY);
        }
    }

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &pairX);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &pairY);

    }

    if (t_stuck_logs < TNX_STUCK_LOG && t_engage_writes > 20 && !t_move_tick) {
        int i = 0;
        int near = -1;
        int within = 0;
        float nd = 1000000.0f;
        float slen = sqrtf(dx * dx + dy * dy);
        float dot = 0.0f;

        for (i = 0; i < t_pl_n; i++) {
            float bx = 0.0f;
            float by = 0.0f;
            float d = 0.0f;

            if (t_pl_mine[i]) continue;

            bx = (float)t_pl_x[i] - (float)ownX;
            by = (float)t_pl_y[i] - (float)ownY;
            d = sqrtf(bx * bx + by * by);

            if (d < nd) {
                nd = d;
                near = i;
            }

            if (d < slen) within++;
        }

        if (near >= 0 && slen > 1.0f) {
            float bx = (float)t_pl_x[near] - (float)ownX;
            float by = (float)t_pl_y[near] - (float)ownY;

            dot = (bx * dx + by * dy) / (sqrtf(bx * bx + by * by) * slen);
        }

        t_stuck_2++;
        t_stuck_logs++;

        TNX_LOGX("stuck writes=%llu own=(%d,%d) step=%.0f nearestBody=%.0f dot=%+.2f mine=%d "
                 "withinStep=%d pick=(%d,%d) - the body does not move although this build keeps "
                 "writing, which is what a character pressed against another player looks like: dot "
                 "near +1 means the step points at that body, withinStep counts the bodies closer "
                 "than the step", (unsigned long long)t_engage_writes, ownX, ownY, (double)slen,
                 (double)nd, (double)dot, (near >= 0) ? t_pl_mine[near] : -1, within, t_tx_3,
                 t_ty_3);
    }

    t_sent_dx = tx - ownX;
    t_sent_dy = ty - ownY;
    t_last_tx_2 = tx;
    t_last_ty_2 = ty;
    t_drive_ticks++;

    tnx_drive_note(ownX, ownY, tx, ty, appX, appY, pairX, pairY);

    if (t_active_2) {
        t_last_decision = t_ticks_3;
        t_decide_x = ownX;
        t_decide_y = ownY;
    }

    if (t_drive_logs < TNX_DRIVE_LOGS ||
        ((t_ticks_3 % 60) == 0 && t_drive_logs < 240)) {
        t_drive_logs++;

        TNX_LOGX("drive held=%d engaged=%d own=(%d,%d) pick=(%d,%d) sent=(%d,%d) step=%.0f "
                 "pair=(%d,%d) queue=%llu skipped=%llu pairOnly=%d holdTicks=%d - the step handed "
                 "to the client input is one frame of travel and not the pick, so the body is "
                 "walked instead of carried; a sent distance that has grown back to the pick means "
                 "something below put the uncapped target back", held, t_active_2, ownX, ownY,
                 t_tx_3, t_ty_3, tx, ty,
                 (double)sqrtf((float)(t_sent_dx * t_sent_dx +
                                       t_sent_dy * t_sent_dy)),
                 t_stick_x, t_stick_y, (unsigned long long)t_queue_calls,
                 (unsigned long long)t_queue_skips, TNX_PAIR_ONLY, TNX_DATA_HOLD);
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
    if (TNX_EVERY > 0 && (t_ticks_3 % (uint64_t)TNX_EVERY) != 0) return;

    t_logs_7++;
    ctrl = tnx_controller();

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &ax);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &ay);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (t_joystick) tnx_read_i32(t_joystick + TNX_BS_MODE, &mode);

    if (t_pred_last) {
        tnx_read_i32(t_pred_last + TNX_MODE_PREDICTX_OFF, &predX);
        tnx_read_i32(t_pred_last + TNX_MODE_PREDICTY_OFF, &predY);
    }

    eta = tnx_eta_ms((float)ownX, (float)ownY);

    if (t_t0) {
        uint64_t now = tnx_us();

        t_dec_us = (now >= t_t0) ? (now - t_t0) : 0;

        if (t_dec_us > t_dec_us_max) t_dec_us_max = t_dec_us;
        if (t_dec_us > TNX_SLOW_US) t_slow++;
    }

    if (t_build_tick >= 0) lag = (int)((int64_t)t_ticks_3 - (int64_t)t_build_tick);

    {
        uintptr_t wrap = (uintptr_t)t_scene_object;
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
             (unsigned long long)t_ticks_3, ownX, ownY, (double)dirX, (double)dirY, escape, ax, ay,
             appX, appY, mode, (void *)t_joystick, t_seg_count, (double)eta, lag, predX,
             predY, (unsigned long long)t_joystick_took,
             (unsigned long long)t_write_denied);
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

int t_joy_knob_n = 0;

int t_joy_knob_ok = 0;

int t_joy_knob_logs = 0;

int t_joy_knob_on = 0;

static int t_joy_knob_miss = 0;

static uint8_t t_joy_knob_state_1 = 0;

static uint8_t t_joy_knob_state_2 = 0;

static int t_joy_knob_saved = 0;

static int tnx_joy_pair_read(uintptr_t obj, uintptr_t pair, float *kx, float *ky, float *cx, float *cy) {
    if (!obj) return 0;
    if (!tnx_read_f32(obj + pair, kx)) return 0;
    if (!tnx_read_f32(obj + pair + TNX_JOY_PAIR_Y, ky)) return 0;
    if (!tnx_read_f32(obj + pair + TNX_JOY_PAIR_CEN, cx)) return 0;
    if (!tnx_read_f32(obj + pair + TNX_JOY_PAIR_CEN + TNX_JOY_PAIR_Y, cy)) return 0;
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

    pair[0] = TNX_JOY_PAIR_1;
    pair[1] = TNX_JOY_PAIR_2;
    pair[2] = TNX_JOY_PAIR_3;

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

                TNX_LOGX("joyknobmiss bs=%p scene=%p hop=%p - the joystick pair is the layout the "
                         "reference build drives (float current at +0x9d0/+0x9d4 against the float "
                         "centre at +0x9d8/+0x9dc with the drag byte at +0xee8), so a miss here means "
                         "none of the candidate objects carries it", (void *)b, (void *)s, (void *)h);
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

    if (!TNX_JOY_KNOB_WRITE_2) {
        if (t_joy_knob_logs < TNX_JOY_KNOB_LOGS) {
            t_joy_knob_logs++;

            TNX_LOGX("joyknobread obj=%p pair=%#llx on=%d cen=(%.1f,%.1f) want=(%.1f,%.1f) - writes "
                     "are off, so this only names the object and the pair the old code would have "
                     "written into: on this object those two words are not a joystick, and the bytes "
                     "just past them belong to whatever the game keeps there",
                     (void *)obj, (unsigned long long)pair, on, (double)cx, (double)cy,
                     (double)kx, (double)ky);
        }

        return;
    }

    if (!tnx_write_f32(obj + pair, kx)) return;

    tnx_write_f32(obj + pair + TNX_JOY_PAIR_Y, ky);

    if (!t_joy_knob_saved) {
        tnx_read_bytes(obj + TNX_JOY_DRAG_OFF, &t_joy_knob_state_1, sizeof(t_joy_knob_state_1));
        tnx_read_bytes(obj + TNX_JOY_DRAG2_OFF, &t_joy_knob_state_2, sizeof(t_joy_knob_state_2));
        t_joy_knob_saved = 1;
    }

    if (on) {
        tnx_write_bytes(obj + TNX_JOY_DRAG_OFF, &one, sizeof(one));
        tnx_write_bytes(obj + TNX_JOY_DRAG2_OFF, &one, sizeof(one));
    } else {
        tnx_write_bytes(obj + TNX_JOY_DRAG_OFF, &t_joy_knob_state_1, sizeof(t_joy_knob_state_1));
        tnx_write_bytes(obj + TNX_JOY_DRAG2_OFF, &t_joy_knob_state_2, sizeof(t_joy_knob_state_2));
    }

    t_joy_knob_n++;
    t_joy_knob_on = on;

    if (t_joy_knob_logs < TNX_JOY_KNOB_LOGS) {
        float bx = 0.0f;
        float by = 0.0f;
        uint8_t s1 = 0;
        uint8_t s2 = 0;

        t_joy_knob_logs++;

        tnx_read_f32(obj + pair, &bx);
        tnx_read_f32(obj + pair + TNX_JOY_PAIR_Y, &by);
        tnx_read_bytes(obj + TNX_JOY_DRAG_OFF, &s1, sizeof(s1));
        tnx_read_bytes(obj + TNX_JOY_DRAG2_OFF, &s2, sizeof(s2));

        if (bx == kx && by == ky) t_joy_knob_ok++;

        TNX_LOGX("joyknob n=%d obj=%p pair=%#llx on=%d cen=(%.1f,%.1f) want=(%.1f,%.1f) "
                 "back=(%.1f,%.1f) s1=%d s2=%d ok=%d",
                 t_joy_knob_n, (void *)obj, (unsigned long long)pair, on, (double)cx, (double)cy,
                 (double)kx, (double)ky, (double)bx, (double)by, (int)s1, (int)s2, t_joy_knob_ok);
    }
}

void tnx_applied_2(int32_t ax, int32_t ay) {
    if (!TNX_APPLY_WRITE_2) return;
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

    t_applied_writes++;

    if (tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &backX) &&
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &backY) &&
        backX == ax && backY == ay) {
        t_applied_live++;
    } else {
        t_applied_stale++;
    }
}

uint64_t t_stick_push_6 = 0;

static void tnx_stick_push_6(int engaged, float dirX, float dirY) {
    uintptr_t bs = tnx_bs();
    uintptr_t bsm = 0;
    float ox = 0.0f;
    float oy = 0.0f;
    float len = 0.0f;
    float nx = 0.0f;
    float ny = 0.0f;
    float backX = 0.0f;
    float backY = 0.0f;

    if (!TNX_STICK_PUSH_2) return;
    if (!bs) return;
    if (!tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&bsm) || !bsm) return;
    if (!tnx_read_f32(bsm + 0xa48, &ox)) return;
    if (!tnx_read_f32(bsm + 0xa4c, &oy)) return;

    if (!engaged) return;

    if (TNX_STICK_HOLD_2) {
        float hx = 0.0f;
        float hy = 0.0f;

        if (!tnx_read_f32(bsm + 0xa40, &hx)) return;
        if (!tnx_read_f32(bsm + 0xa44, &hy)) return;
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

        if (TNX_STICK_INPUT_2 && tnx_read_f32(bsm + 0x9d8, &kx) && tnx_read_f32(bsm + 0x9dc, &ky)) {
            float ix = kx + nx * TNX_STICK_RADIUS_2;
            float iy = ky + ny * TNX_STICK_RADIUS_2;

            tnx_write_f32(bsm + 0x9d0, ix);
            tnx_write_f32(bsm + 0x9d4, iy);
        }

        if (TNX_STICK_KNOB_3) {
            tnx_write_f32(bsm + 0xa40, ox + nx * TNX_STICK_RADIUS_2);
            tnx_write_f32(bsm + 0xa44, oy + ny * TNX_STICK_RADIUS_2);
        }

        tnx_read_f32(bsm + 0x9d0, &bx);
        tnx_read_f32(bsm + 0x9d4, &by);

        if (t_stick_push_6 <= 200) {
            TNX_LOGX("stickpush n=%llu bsm=%p engaged=%d org=(%.2f,%.2f) cen=(%.2f,%.2f) "
                     "in=(%.2f,%.2f) knob=%d knobWant=(%.2f,%.2f) - the input pair carries the "
                     "direction and the knob pair only paints it, so the input pair is the one to "
                     "drive and the knob pair stays untouched unless the flag says otherwise",
                     (unsigned long long)t_stick_push_6, (void *)bsm, engaged,
                     (double)ox, (double)oy, (double)kx, (double)ky, (double)bx, (double)by,
                     (int)TNX_STICK_KNOB_3,
                     (double)(ox + nx * TNX_STICK_RADIUS_2), (double)(oy + ny * TNX_STICK_RADIUS_2));
        }
    }

    {
        uint8_t held = 1;

        tnx_write_bytes(bsm + 0xf78, &held, sizeof(held));
        tnx_write_bytes(bsm + 0xf80, &held, sizeof(held));
        tnx_write_bytes(bsm + 0xf9c, &held, sizeof(held));
        tnx_write_bytes(bsm + 0xf9e, &held, sizeof(held));
    }

    t_stick_push_6++;
}

void tnx_stick(int engaged, float dirX, float dirY) {
    tnx_stick_push_6(engaged, dirX, dirY);

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

    if (!TNX_STICK_RAW_WRITE_2) return;
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
            t_stick_tick = t_ticks_3;
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
        if (TNX_JS_STICK && t_ticks_3 < t_stick_tick + TNX_JS_HOLD) return;
        if (!TNX_RAGE && t_stick_tick + TNX_STICK_TTL > t_ticks_3) return;

        t_stick_hold = 0;

        if (relCtrl && tnx_read_i32(relCtrl + TNX_CTRL_RAW_X_OFF, &relX) &&
            tnx_read_i32(relCtrl + TNX_CTRL_RAW_Y_OFF, &relY)) {
            if (relX != t_stick_x || relY != t_stick_y) return;
        }
    }

    t_stick_x = wx;
    t_stick_y = wy;

    if (TNX_STICK_RAW_WRITE_2 && !(TNX_RETIRE && t_accepted && !TNX_JS_STICK)) {
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

            tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &backX);
            tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &backY);
            tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
            tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
            tnx_read_bytes(ctrl + TNX_CTRL_MOVE_OFF, &mv, sizeof(mv));
            tnx_read_bytes(ctrl + TNX_CTRL_ALIVE_OFF, &al, sizeof(al));
            tnx_read_bytes(ctrl + TNX_CTRL_LATCH_OFF, &lt, sizeof(lt));
            tnx_read_bytes(ctrl + TNX_CTRL_DIRTY_OFF, &dt, sizeof(dt));

            TNX_LOGX("stick write #%d ctrl=%p want=(%d,%d) back=(%d,%d) kept=%d engaged=%d "
                     "applied=(%d,%d) move=%d alive=%d latch=%d dirty=%d - the raw pair is only a "
                     "request until the engine commits it, and the commit is the latch byte at %#llx "
                     "set with the dirty byte at %#llx cleared, which this build had reserved and "
                     "never written, so applied stayed at its old value while the body glided on the "
                     "message path alone",
                     stickLogs, (void *)ctrl, wx, wy, backX, backY,
                     (backX == wx && backY == wy) ? 1 : 0, want, appX, appY, (int)mv, (int)al,
                     (int)lt, (int)dt, (unsigned long long)TNX_CTRL_LATCH_OFF,
                     (unsigned long long)TNX_CTRL_DIRTY_OFF);
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

    if ((t_ticks_3 % 60) != 0) return;
    if (!tnx_own(&ownX, &ownY)) return;

    t_engaged_ticks = 0;

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &backX);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &backY);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
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

    TNX_LOGX("route engaged=%d stick=(%d,%d) back=(%d,%d) applied=(%d,%d) own=(%d,%d) movedLastSecond=%d stickSum=(%lld,%lld) stickDir=(%.2f,%.2f) moveDir=(%.2f,%.2f) dot=%+.2f aligned=%s engagedTicks=%d queue=%d",
             engaged, t_stick_x, t_stick_y, backX, backY, appX, appY, ownX, ownY, moved,
             sumX, sumY,
             (double)(sLen > 0.5f ? (float)sumX / sLen : 0.0f),
             (double)(sLen > 0.5f ? (float)sumY / sLen : 0.0f),
             (double)(mLen > 0.5f ? (float)dx / mLen : 0.0f),
             (double)(mLen > 0.5f ? (float)dy / mLen : 0.0f),
             (double)dot, align, ours, tnx_queue_count(NULL));
        }
    }
}

float t_walk_step = TNX_STEP_3;

uint64_t t_ticks_3 = 0;

long long t_sum_x = 0;

long long t_sum_y = 0;
