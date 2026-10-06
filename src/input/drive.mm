#include "titanox.h"

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
        else tnx_enqueue(tx, ty);
        t_queue_calls++;
    } else {
        t_queue_skips++;
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

int tnx_snap(float dx, float dy) {
    static int off_logs = 0;

#if TNX_SNAP_HARD_OFF
    if (off_logs < 4) {
        off_logs++;

        TNX_LOGX("snap off v36 dir=(%.0f,%.0f) - the call is not made at all in this build and no pair "
                 "leaves it: the crash address was exactly the pair this function handed the engine, "
                 "with pc and lr both inside the game, so the engine stored our vector in a slot of the "
                 "container element and its own code later read that slot back as a pointer; the move "
                 "is carried by the prediction call on the logic client and by the input message, which "
                 "run on the same frame, and the flag sits at the top of the function so a define from "
                 "outside cannot turn it back on",
                 (double)dx, (double)dy);
    }

    (void)dx;
    (void)dy;

    return 0;
#else
    uintptr_t fn = tnx_entry_2(TNX_SETPRED4_RVA);
    uintptr_t own = tnx_own_obj();
    uintptr_t dst = tnx_controller();
    float len = sqrtf(dx * dx + dy * dy);
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t vx = 0;
    int32_t vy = 0;

    t_snap_live = 0;

    if (!TNX_SNAP) {
        if (t_snap_off_logs < 4) {
            t_snap_off_logs++;

            TNX_LOGX("snap off elem=%p client=%p mag=%.0f - this was the only call that handed the "
                     "engine move function the container element as the receiver together with a "
                     "direction of magnitude %.0f, and the crash addresses carried exactly that value "
                     "in one half of a pointer, so the move is left to tnx_pred_set alone, which is "
                     "the same engine call made on the logic client with a destination, so one frame "
                     "carries two actions instead of three",
                     (void *)own, (void *)tnx_controller(), (double)TNX_SNAP_MAG,
                     (double)TNX_SNAP_MAG);
        }

        return 0;
    }

    if (!fn || !dst || !own) return 0;
    if (!tnx_ok(len, 0.001f, 1.0e9f)) return 0;
    if (!tnx_own(&ownX, &ownY)) return 0;

#if TNX_SNAP_DELTA
    vx = (int32_t)((double)dx / (double)len * (double)TNX_SNAP_MAG);
    vy = (int32_t)((double)dy / (double)len * (double)TNX_SNAP_MAG);
#else
    vx = ownX + (int32_t)((double)dx / (double)len * (double)tnx_step());
    vy = ownY + (int32_t)((double)dy / (double)len * (double)tnx_step());
#endif

    if (!tnx_valid_point((float)vx, (float)vy)) return 0;

    ((void (*)(uintptr_t, int, int, int))fn)(dst, vx, vy, TNX_SETFLAG);

    t_snap_calls++;
    t_snap_live = 1;

    if (t_snap_logs < TNX_SNAP_LOGS || (t_ticks_3 % 180) == 0) {
        t_snap_logs++;

        TNX_LOGX("snap dst=%p sent=(%d,%d) own=(%d,%d) dir=(%.0f,%.0f) len=%.0f step=%.0f delta=%d "
                 "elem=%p mag=%.0f - the receiver is the logic client the prediction call uses and the "
                 "argument is a destination in the same units as the pick, while the previous form "
                 "handed the same function the container element and a %.0f unit delta: the crash "
                 "address was exactly that pair with pc and lr both inside the game, so the engine "
                 "wrote our vector into a slot of the element and its own code read that slot back as "
                 "a pointer, which is what the receiver change removes; delta=1 restores the old form",
                 (void *)dst, vx, vy, ownX, ownY, (double)dx, (double)dy, (double)len,
                 (double)tnx_step(), (int)TNX_SNAP_DELTA, (void *)own, (double)TNX_SNAP_MAG,
                 (double)TNX_SNAP_MAG);
    }

    return 1;
#endif
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

    if (t_logs_8 >= TNX_LOGS_4) return;
    if (TNX_EVERY_2 > 0 && (t_ticks_3 % (uint64_t)TNX_EVERY_2) != 0) return;

    for (i = 0; i < t_seg_count; i++) {
        const tnx_seg_t *s = &t_seg[i];
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

    if (t_new_tick >= 0) react = (int)((int64_t)t_ticks_3 - (int64_t)t_new_tick);

    t_logs_8++;

    if (best < 0) {
        TNX_LOGX("predict tick=%llu own=(%d,%d) tgt=(%.0f,%.0f) threats=0 react=%d flees=%llu - "
                 "no segment is live, so there is nothing to lead and the pick is a plain step",
                 (unsigned long long)t_ticks_3, ownX, ownY, (double)tx, (double)ty, react,
                 (unsigned long long)t_flees);

        return;
    }

    d = sqrtf((qx - px) * (qx - px) + (qy - py) * (qy - py));

    TNX_LOGX("predict tick=%llu own=(%d,%d) tgt=(%.0f,%.0f) threats=%d react=%d gid=%d "
             "impact=(%.0f,%.0f) lead=(%.0f,%.0f) d=%.0f eta=%.0fms spd=%.0f ms=%.0f - impact is the "
             "closest point of the nearest flight to own, lead is the offset own has to clear, and a "
             "react above one tick means the pick was made a frame or more after the threat appeared",
             (unsigned long long)t_ticks_3, ownX, ownY, (double)tx, (double)ty, t_seg_count,
             react, t_seg[best].gid, (double)qx, (double)qy, (double)(qx - px), (double)(qy - py),
             (double)d, (double)bestMs, (double)t_seg[best].speed, (double)(d / (t_seg[best].speed > 1.0f ? t_seg[best].speed : 1.0f) * 1000.0f));
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

void tnx_stick(int engaged, float dirX, float dirY) {
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

    if (!TNX_RAW_STICK) return;
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

    if (TNX_STICK_RAW_WRITE && !(TNX_RETIRE && t_accepted && !TNX_JS_STICK)) {
        if (!tnx_write_bytes(ctrl + TNX_CTRL_RAW_X_OFF, &wx, sizeof(wx))) return;

        tnx_write_bytes(ctrl + TNX_CTRL_RAW_Y_OFF, &wy, sizeof(wy));
    }

    {
        static int stickLogs = 0;

        if (stickLogs < 6) {
            int32_t backX = 0;
            int32_t backY = 0;

            stickLogs++;

            tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &backX);
            tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &backY);

            TNX_LOGX("stick write #%d ctrl=%p want=(%d,%d) back=(%d,%d) kept=%d engaged=%d",
                     stickLogs, (void *)ctrl, wx, wy, backX, backY,
                     (backX == wx && backY == wy) ? 1 : 0, want);
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
