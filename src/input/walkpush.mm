#include "titanox.h"

uintptr_t t_walk_ent_10 = 0;

uint64_t t_walk_scans_10 = 0;

uint64_t t_walk_sends_10 = 0;

uint64_t t_walk_near_10 = 0;

uint64_t t_walk_hand_10 = 0;

static uint64_t t_walk_logs_10 = 0;

static uint64_t t_walk_offlogs_10 = 0;

static uintptr_t t_walk_lookup_fn_10 = 0;

static uintptr_t t_walk_entb_10 = 0;

static uintptr_t t_walk_entc_10 = 0;

static int t_walk_on_10 = 0;

static int32_t t_walk_px_10 = 0;

static int32_t t_walk_py_10 = 0;

static int32_t t_walk_tx_10 = 0;

static int32_t t_walk_ty_10 = 0;

static uint64_t t_walk_stamp_10 = 0;

static uint64_t t_walk_frames_10 = 0;

static uint8_t t_walk_knob_own_10 = 0;

static float t_walk_knob_x_10 = 0.0f;

static float t_walk_knob_y_10 = 0.0f;

static uint64_t t_walk_knob_writes_10 = 0;

static uint64_t t_walk_knob_restores_10 = 0;

static uint8_t t_walk_save_f78_10 = 0;

static uint8_t t_walk_save_f7f_10 = 0;

static uint64_t t_walk_gate_logs_10 = 0;

static uintptr_t t_walk_mode_fn_10 = 0;

static int32_t t_ent_prev_10[TNX_ENT_SLOTS_10];

static int32_t t_ent_cur_10[TNX_ENT_SLOTS_10];

static uint32_t t_ent_chg_10[TNX_ENT_SLOTS_10];

static uint32_t t_ent_cd_10[TNX_ENT_SLOTS_10];

static uint32_t t_ent_co_10[TNX_ENT_SLOTS_10];

static uint8_t t_ent_seen_10[TNX_ENT_SLOTS_10];

static uint64_t t_ent_frames_10 = 0;

static uint64_t t_ent_logs_10 = 0;

static uint64_t t_ent_sums_10 = 0;

static uintptr_t t_ent_last_10 = 0;

static uintptr_t t_walk_fn_10 = 0;

static int32_t t_walk_dir_10[2] = { 0, 0 };

static int32_t t_walk_goal_10[2] = { 0, 0 };

static void tnx_ent_summary_10(void) {
    uintptr_t ent = t_ent_last_10;
    uint64_t logs = 0;
    int i = 0;

    if (!ent) return;

    TNX_LOGX("entsum begin frames=%llu ent=%p slots=%d min=%d chunk=%d - knob marks the frames the native "
             "stick was displaced and ours the frames our walk wrote the pair, so an offset the native walk "
             "moves and our walk never touches is the state we are still missing",
             (unsigned long long)t_ent_frames_10, (void *)ent, (int)TNX_ENT_SLOTS_10, (int)TNX_ENT_SUM_MIN_10,
             (int)TNX_ENT_CHUNK_10);

    for (i = 0; i < TNX_ENT_SLOTS_10; i++) {
        if (t_ent_chg_10[i] < (uint32_t)TNX_ENT_SUM_MIN_10) continue;
        if (logs >= (uint64_t)TNX_ENT_SUM_LOGS_10) break;

        logs++;

        TNX_LOGX("entsum off=+%#x chg=%llu knob=%llu ours=%llu last=%d", (unsigned)(i * 4),
                 (unsigned long long)t_ent_chg_10[i], (unsigned long long)t_ent_cd_10[i],
                 (unsigned long long)t_ent_co_10[i], t_ent_cur_10[i]);
    }

    t_ent_sums_10++;
}

void tnx_ent_probe_10(uintptr_t ent, int knob, int ours) {
    int32_t buf[TNX_ENT_CHUNK_10 / 4];
    uintptr_t base = 0;
    int32_t v = 0;
    int c = 0;
    int k = 0;
    int i = 0;

    if (!TNX_ENT_PROBE_10) return;
    if (!ent) return;

    if (ent != t_ent_last_10) {
        t_ent_last_10 = ent;

        for (i = 0; i < TNX_ENT_SLOTS_10; i++) {
            t_ent_prev_10[i] = 0;
            t_ent_cur_10[i] = 0;
            t_ent_chg_10[i] = 0;
            t_ent_cd_10[i] = 0;
            t_ent_co_10[i] = 0;
            t_ent_seen_10[i] = 0;
        }
    }

    t_ent_frames_10++;

    if (t_ent_frames_10 <= (uint64_t)TNX_ENT_WARMUP_10) {
        for (i = 0; i < TNX_ENT_SLOTS_10; i++) t_ent_seen_10[i] = 0;

        return;
    }

    for (c = 0; c < TNX_ENT_CHUNKS_10; c++) {
        base = ent + (uintptr_t)(c * TNX_ENT_CHUNK_10);

        if (!tnx_read_bytes(base, buf, sizeof(buf))) continue;

        for (k = 0; k < (int)(TNX_ENT_CHUNK_10 / 4); k++) {
            i = c * (int)(TNX_ENT_CHUNK_10 / 4) + k;
            v = buf[k];

            t_ent_cur_10[i] = v;

            if (v == t_ent_prev_10[i]) continue;

            t_ent_prev_10[i] = v;
            t_ent_chg_10[i]++;

            if (knob) t_ent_cd_10[i]++;
            if (ours) t_ent_co_10[i]++;

            if (t_ent_seen_10[i] < (uint8_t)TNX_ENT_SAMPLE_10 && t_ent_logs_10 < (uint64_t)TNX_ENT_PROBE_LOGS_10) {
                t_ent_seen_10[i]++;
                t_ent_logs_10++;

                TNX_LOGX("entchg off=+%#x val=%d knob=%d ours=%d chg=%llu", (unsigned)(i * 4), v, knob, ours,
                         (unsigned long long)t_ent_chg_10[i]);
            }
        }
    }

    if ((t_ent_frames_10 % (uint64_t)TNX_ENT_SUM_EVERY_10) == 0) tnx_ent_summary_10();
}

static uintptr_t tnx_walk_lookup_10(uintptr_t mgr, uintptr_t ent) {
    uintptr_t col = 0;
    uintptr_t inner = 0;
    uintptr_t fn = 0;
    uintptr_t res = 0;
    uintptr_t arr = 0;
    int32_t cnt = 0;
    int32_t ex = 0;
    int32_t ey = 0;
    int32_t rx = 0;
    int32_t ry = 0;

    if (!TNX_WALK_LOOKUP_10) return 0;
    if (!mgr || !ent) return 0;

    if (!tnx_read_ptr(mgr + (uintptr_t)TNX_CI_MGR_OBJLIST_OFF, (void **)&col) || !col) return 0;
    if (!tnx_read_ptr(col + 8, (void **)&inner) || !inner) return 0;

    if (!tnx_read_i32(inner + 0xc, &cnt)) return 0;
    if (cnt < 1 || cnt > 64) return 0;
    if (!tnx_read_ptr(inner, (void **)&arr) || !arr) return 0;

    fn = t_walk_lookup_fn_10;

    if (!fn) {
        fn = tnx_entry_2(RVA_MGR_OBJ_LOOKUP_10);

        if (!fn && t_base) fn = t_base + RVA_MGR_OBJ_LOOKUP_10;

        t_walk_lookup_fn_10 = fn;
    }

    if (!fn) return 0;

    res = ((uintptr_t (*)(void *, void *, int))fn)((void *)inner, (void *)ent, -1);

    if (!res) return 0;

    if (!tnx_read_i32(res + (uintptr_t)TNX_OBJ_X_OFF, &rx)) return 0;
    if (!tnx_read_i32(res + (uintptr_t)TNX_OBJ_Y_OFF, &ry)) return 0;
    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_X_OFF, &ex)) return 0;
    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_Y_OFF, &ey)) return 0;

    if (rx - ex > 400 || ex - rx > 400) return 0;
    if (ry - ey > 400 || ey - ry > 400) return 0;

    return res;
}

uintptr_t tnx_walk_mgr_10(void) {
    uintptr_t bs = tnx_bs();
    uintptr_t mgr = 0;

    if (!bs) return 0;
    if (!tnx_read_ptr(bs + (uintptr_t)TNX_JOY_TARGET_OFF, (void **)&mgr) || !mgr) return 0;

    return mgr;
}

void tnx_walk_want_10(int on, int32_t px, int32_t py, int32_t tx, int32_t ty) {
    t_walk_on_10 = on ? 1 : 0;
    t_walk_px_10 = px;
    t_walk_py_10 = py;
    t_walk_tx_10 = tx;
    t_walk_ty_10 = ty;
    t_walk_stamp_10 = t_walk_frames_10;
}

static uintptr_t tnx_walk_flip_10(void) {
    uint8_t flip = 0;
    uintptr_t addr = 0;

    addr = t_base + (uintptr_t)RVA_JOY_FLIP_10;

    if (!t_base) return 0;
    if (!tnx_read_u8(addr, &flip)) return 0;

    return flip ? 1 : 0;
}

void tnx_walk_pump_10(void) {
    uintptr_t mgr = 0;
    uintptr_t ent = t_walk_ent_10;
    uintptr_t fn = 0;
    int32_t ox = 0;
    int32_t oy = 0;
    int32_t span = 0;
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    int32_t dirX = 0;
    int32_t dirY = 0;
    int32_t goalX = 0;
    int32_t goalY = 0;
    int32_t backX = 0;
    int32_t backY = 0;
    int64_t jump = 0;
    float dx = 0.0f;
    float dy = 0.0f;
    float len = 0.0f;
    float rad = 0.0f;
    float timer = 0.0f;
    uint8_t latch = 0;
    uint8_t hold = 0;
    int32_t dirty = 0;
    uintptr_t mgrB = 0;
    int32_t mgrBrawX = 0;
    int32_t mgrBrawY = 0;
    int32_t mgrBappX = 0;
    int32_t mgrBappY = 0;
    uint8_t flagUsed = 0;
    uint8_t flagOwn = 0;
    float knobA[2] = { 0.0f, 0.0f };
    float knobB[2] = { 0.0f, 0.0f };
    int knob = 0;
    uint8_t latchB = 0;
    uint8_t holdB = 0;
    int32_t dirtyB = 0;
    float timerB = 0.0f;
    int wrote = 0;
    int sent = 0;
    int on = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t tx = 0;
    int32_t ty = 0;
    int knobOk = 0;
    int knobWrote = 0;
    int knobRestored = 0;
    int knobHeld = 0;
    uintptr_t flip = 0;
    float orgX = 0.0f;
    float orgY = 0.0f;
    float curX = 0.0f;
    float curY = 0.0f;
    float knobX = 0.0f;
    float knobY = 0.0f;
    float sign = 1.0f;
    float curBefore = 0.0f;
    uint8_t gF78 = 0;
    uint8_t one = 1;
    uint8_t gF9E = 0;
    uint8_t gF7F = 0;
    uint8_t gF80 = 0;
    uint8_t g1041 = 0;
    uint8_t g1042 = 0;
    uint8_t gE32A = 0;
    uint8_t gE240 = 0;
    int32_t gE13C = 0;
    int32_t gMode = -1;
    uintptr_t gObj = 0;
    uintptr_t gFn = 0;

    t_walk_frames_10++;

    if (!TNX_WALK_PUSH_10) return;

    on = t_walk_on_10;
    px = t_walk_px_10;
    py = t_walk_py_10;
    tx = t_walk_tx_10;
    ty = t_walk_ty_10;

    if (t_walk_frames_10 - t_walk_stamp_10 > (uint64_t)TNX_WALK_STALE_10) on = 0;

    mgr = tnx_walk_mgr_10();

    if (!mgr) return;
    if (!ent) return;

    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_X_OFF, &ox)) return;
    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_Y_OFF, &oy)) return;
    if (!tnx_read_i32(ent + 0x24c, &span)) return;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &rawX)) return;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &rawY)) return;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &appX)) return;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &appY)) return;
    tnx_read_u8(mgr + (uintptr_t)TNX_CTRL_MOVE_OFF, &gF78);
    tnx_read_u8(mgr + (uintptr_t)TNX_TOUCH_GATE_OFF, &gF7F);

    latchB = 0;
    holdB = 0;

    tnx_read_u8(mgr + (uintptr_t)TNX_CTRL_LATCH_OFF, &latchB);
    tnx_read_u8(mgr + (uintptr_t)TNX_CTRL_ALIVE_OFF, &holdB);
    tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_DIRTY_OFF, &dirtyB);
    tnx_read_f32(mgr + (uintptr_t)TNX_MARK_OFF, &timerB);

    mgrB = (uintptr_t)tnx_manager();

    if (mgrB) {
        tnx_read_i32(mgrB + (uintptr_t)TNX_CTRL_RAW_X_OFF, &mgrBrawX);
        tnx_read_i32(mgrB + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &mgrBrawY);
        tnx_read_i32(mgrB + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &mgrBappX);
        tnx_read_i32(mgrB + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &mgrBappY);
    }

    knob = 0;

    if (tnx_read_f32(mgr + 0xa40, &knobA[0]) && tnx_read_f32(mgr + 0xa44, &knobA[1])
        && tnx_read_f32(mgr + 0xa48, &knobB[0]) && tnx_read_f32(mgr + 0xa4c, &knobB[1])) {
        if (knobA[0] - knobB[0] > 1.0f || knobB[0] - knobA[0] > 1.0f) knob = 1;
        if (knobA[1] - knobB[1] > 1.0f || knobB[1] - knobA[1] > 1.0f) knob = 1;
    }

    t_walk_entb_10 = ent;
    t_walk_entc_10 = tnx_walk_lookup_10(mgr, ent);

    if (t_walk_entc_10 && t_walk_entc_10 != ent) {
        int32_t ux = 0;
        int32_t uy = 0;

        if (tnx_read_i32(t_walk_entc_10 + (uintptr_t)TNX_OBJ_X_OFF, &ux)
            && tnx_read_i32(t_walk_entc_10 + (uintptr_t)TNX_OBJ_Y_OFF, &uy)) {
            if (ux - ox <= 400 && ox - ux <= 400 && uy - oy <= 400 && oy - uy <= 400) {
                ent = t_walk_entc_10;
                ox = ux;
                oy = uy;
            }
        }
    }

    if (ox - px > 250 || px - ox > 250) return;
    if (oy - py > 250 || py - oy > 250) return;

    if (!on) {
        if (t_walk_knob_own_10) {
            float rx = 0.0f;
            float ry = 0.0f;
            float cx = 0.0f;
            float cy = 0.0f;

            if (tnx_read_f32(mgr + (uintptr_t)TNX_JOY_ORG_X_OFF, &rx)
                && tnx_read_f32(mgr + (uintptr_t)TNX_JOY_ORG_Y_OFF, &ry)
                && tnx_read_f32(mgr + (uintptr_t)TNX_JOY_CUR_X_OFF, &cx)
                && tnx_read_f32(mgr + (uintptr_t)TNX_JOY_CUR_Y_OFF, &cy)) {
                float ax = t_walk_knob_x_10 - cx;
                float ay = t_walk_knob_y_10 - cy;

                if (ax <= 0.5f && ax >= -0.5f && ay <= 0.5f && ay >= -0.5f) {
                    tnx_write_f32(mgr + (uintptr_t)TNX_JOY_CUR_X_OFF, rx);
                    tnx_write_f32(mgr + (uintptr_t)TNX_JOY_CUR_Y_OFF, ry);
                }

                if (TNX_WALK_HOLD_10) {
                    tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_MOVE_OFF, &t_walk_save_f78_10, sizeof(t_walk_save_f78_10));
                    tnx_write_bytes(mgr + (uintptr_t)TNX_TOUCH_GATE_OFF, &t_walk_save_f7f_10, sizeof(t_walk_save_f7f_10));
                }

                t_walk_knob_own_10 = 0;
                t_walk_knob_restores_10++;
                knobRestored = 1;
            }
        }

        if (rawX != 0 || rawY != 0) {
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &backX, sizeof(backX));
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &backY, sizeof(backY));

            wrote = 1;
        }

        tnx_ent_probe_10(ent, knob, 0);

        if (t_walk_offlogs_10 < TNX_WALK_OFF_LOGS_10) {
            t_walk_offlogs_10++;

            TNX_LOGX("walkpush off n=%llu mgr=%p ent=%p own=(%d,%d) raw=%d,%d wrote=%d knobOwn=%d "
                     "knobBack=%d knobWrites=%llu knobBacks=%llu scans=%llu sends=%llu near=%llu - no walk this "
                     "frame, the raw pair goes back to zero and a stick we displaced is put back on its centre",
                     (unsigned long long)t_walk_offlogs_10, (void *)mgr, (void *)ent, ox, oy, rawX, rawY, wrote,
                     (int)t_walk_knob_own_10, knobRestored,
                     (unsigned long long)t_walk_knob_writes_10, (unsigned long long)t_walk_knob_restores_10,
                     (unsigned long long)t_walk_scans_10, (unsigned long long)t_walk_sends_10,
                     (unsigned long long)t_walk_near_10);
        }

        return;
    }

    dx = (float)(tx - ox);
    dy = (float)(ty - oy);
    len = __builtin_sqrtf(dx * dx + dy * dy);

    if (len < 1.0f) return;

    dx /= len;
    dy /= len;

    dirX = (int32_t)(dx * TNX_WALK_PUSH_RAW_10);
    dirY = (int32_t)(dy * TNX_WALK_PUSH_RAW_10);

    if (dirX == 0 && dirY == 0) return;

    rad = (float)(span / 5);

    if (rad < 1.0f) return;

    goalX = ox + (int32_t)(dx * rad);
    goalY = oy + (int32_t)(dy * rad);

    jump = (int64_t)(goalX - appX) * (int64_t)(goalX - appX)
         + (int64_t)(goalY - appY) * (int64_t)(goalY - appY);

    t_walk_dir_10[0] = dirX;
    t_walk_dir_10[1] = dirY;
    t_walk_goal_10[0] = goalX;
    t_walk_goal_10[1] = goalY;

    knobOk = 0;

    if (TNX_WALK_KNOB_10) {
        if (tnx_read_f32(mgr + (uintptr_t)TNX_JOY_ORG_X_OFF, &orgX)
            && tnx_read_f32(mgr + (uintptr_t)TNX_JOY_ORG_Y_OFF, &orgY)
            && tnx_read_f32(mgr + (uintptr_t)TNX_JOY_CUR_X_OFF, &curX)
            && tnx_read_f32(mgr + (uintptr_t)TNX_JOY_CUR_Y_OFF, &curY)) knobOk = 1;
    }

    curBefore = curX;

    if (knobOk) {
        knobX = curX - orgX;
        knobY = curY - orgY;

        if (knobX > 1.0f || knobX < -1.0f || knobY > 1.0f || knobY < -1.0f) knobHeld = 1;
    }

    if (knobOk) {
        flip = tnx_walk_flip_10();
        sign = flip ? -1.0f : 1.0f;

        knobX = orgX + dx * sign * TNX_WALK_KNOB_RADIUS_10;
        knobY = orgY + dy * sign * TNX_WALK_KNOB_RADIUS_10;

        if (!t_walk_knob_own_10) {
            t_walk_save_f78_10 = gF78;
            t_walk_save_f7f_10 = gF7F;
        }

        if (TNX_WALK_HOLD_10) {
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_MOVE_OFF, &one, sizeof(one));
            tnx_write_bytes(mgr + (uintptr_t)TNX_TOUCH_GATE_OFF, &one, sizeof(one));
        }

        tnx_write_f32(mgr + (uintptr_t)TNX_JOY_CUR_X_OFF, knobX);
        tnx_write_f32(mgr + (uintptr_t)TNX_JOY_CUR_Y_OFF, knobY);

        t_walk_knob_own_10 = 1;
        t_walk_knob_x_10 = knobX;
        t_walk_knob_y_10 = knobY;

        t_walk_knob_writes_10++;
        knobWrote = 1;
    } else {
        tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &dirX, sizeof(dirX));
        tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &dirY, sizeof(dirY));

        wrote = 1;
    }

    t_walk_scans_10++;

    if (knobWrote) {
        sent = 1;
    } else if (jump < (int64_t)TNX_WALK_PUSH_MIN_JUMP_10 || rad < 60.0f || rad > 1500.0f) {
        t_walk_near_10++;
    } else {
        fn = t_walk_fn_10;

        if (!fn) {
            fn = tnx_entry_2(RVA_INPUT_COMMIT_10);

            if (!fn && t_base) fn = t_base + RVA_INPUT_COMMIT_10;

            t_walk_fn_10 = fn;
        }

        if (fn) {
            ((void (*)(void *, void *, void *, int))fn)((void *)mgr, (void *)ent, (void *)ent, 1);

            sent = 1;

            t_walk_sends_10++;

            if (TNX_WALK_HS_10) {
                latch = (uint8_t)TNX_CTRL_LATCH_VAL;
                dirty = (int32_t)TNX_CTRL_DIRTY_VAL;
                hold = 1;
                timer = TNX_WALK_HS_TIMER_10;

                tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_LATCH_OFF, &latch, sizeof(latch));
                tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_DIRTY_OFF, &dirty, sizeof(dirty));
                tnx_write_f32(mgr + (uintptr_t)TNX_MARK_OFF, timer);
                tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_ALIVE_OFF, &hold, sizeof(hold));

                t_walk_hand_10++;
            }
        }
    }

    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &appX)) appX = 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &appY)) appY = 0;

    tnx_ent_probe_10(ent, knob, (wrote || knobWrote) ? 1 : 0);

    if (t_walk_logs_10 < TNX_WALK_PUSH_LOGS_10) {
        t_walk_logs_10++;

        TNX_LOGX("walkpush n=%llu mgr=%p ent=%p own=(%d,%d) want=(%d,%d) dir=(%d,%d) span=%d goal=(%d,%d) "
                 "applied=(%d,%d) jump=%lld sent=%d wrote=%d knobWrote=%d knobHeld=%d flip=%llu "
                 "curBefore=%g org=(%g,%g) cur=(%g,%g) hold=%d/%d sav=%d/%d hsBefore=(%d,%d,%g,%d) hsAfter=(%d,%d,%g,%d) scans=%llu "
                 "sends=%llu near=%llu hand=%llu knobWrites=%llu knobBacks=%llu - while the touch pair is at rest "
                 "it is displaced so the engine walk routine reads the wanted direction itself, and when the "
                 "finger already holds the pair the raw pair and the commit are used instead, and the sign comes "
                 "from the byte the walk routine multiplies the delta with",
                 (unsigned long long)t_walk_logs_10, (void *)mgr, (void *)ent, ox, oy, tx, ty,
                 t_walk_dir_10[0], t_walk_dir_10[1], span, t_walk_goal_10[0], t_walk_goal_10[1], appX, appY,
                 (long long)jump, sent, wrote, knobWrote, knobHeld, (unsigned long long)flip,
                 (double)curBefore, (double)orgX, (double)orgY, (double)curX, (double)curY,
                 (int)gF78, (int)gF7F, (int)t_walk_save_f78_10, (int)t_walk_save_f7f_10,
                 (int)latchB, (int)dirtyB, (double)timerB, (int)holdB,
                 (int)latch, (int)dirty, (double)timer, (int)hold,
                 (unsigned long long)t_walk_scans_10, (unsigned long long)t_walk_sends_10,
                 (unsigned long long)t_walk_near_10, (unsigned long long)t_walk_hand_10,
                 (unsigned long long)t_walk_knob_writes_10, (unsigned long long)t_walk_knob_restores_10);
    }

    if (t_walk_gate_logs_10 < (uint64_t)TNX_WALK_GATE_LOGS_10) {
        t_walk_gate_logs_10++;

        gObj = 0;
        gMode = -1;

        tnx_read_u8(mgr + 0xf78, &gF78);
        tnx_read_u8(mgr + 0xf9e, &gF9E);
        tnx_read_u8(mgr + 0xf7f, &gF7F);
        tnx_read_u8(mgr + 0xf80, &gF80);
        tnx_read_u8(mgr + 0x1041, &g1041);
        tnx_read_u8(mgr + 0x1042, &g1042);

        if (ent) {
            tnx_read_u8(ent + 0x32a, &gE32A);
            tnx_read_u8(ent + 0x240, &gE240);
            tnx_read_i32(ent + 0x13c, &gE13C);
        }

        if (tnx_read_ptr(mgr + (uintptr_t)TNX_WALK_OBJ_OFF, (void **)&gObj) && gObj) {
            gFn = t_walk_mode_fn_10;

            if (!gFn) {
                gFn = tnx_entry_2(RVA_WALK_MODE_10);

                if (!gFn && t_base) gFn = t_base + RVA_WALK_MODE_10;

                t_walk_mode_fn_10 = gFn;
            }

            if (gFn) gMode = ((int (*)(void *))gFn)((void *)gObj);
        }

        TNX_LOGX("walkgate n=%llu mgr=%p ent=%p knobWrote=%d on=%d f78=%d f9e=%d f7f=%d f80=%d a08=%p mode=%d "
                 "e32a=%d e240=%d e13c=%d m1041=%d m1042=%d - these are the exact conditions the per frame walk "
                 "routine checks before it reads the touch pair, so whichever one is off is what keeps the "
                 "engine from committing the step",
                 (unsigned long long)t_walk_gate_logs_10, (void *)mgr, (void *)ent, knobWrote, on,
                 (int)gF78, (int)gF9E, (int)gF7F, (int)gF80, (void *)gObj, gMode,
                 (int)gE32A, (int)gE240, gE13C, (int)g1041, (int)g1042);
    }

    if (t_walk_logs_10 < (uint64_t)TNX_WALK_PUSH_LOGS_10) {
        flagUsed = 0;
        flagOwn = 0;

        tnx_read_u8(ent + (uintptr_t)TNX_LOCAL_ENT_FLAG_OFF, &flagUsed);

        if (t_walk_entb_10) tnx_read_u8(t_walk_entb_10 + (uintptr_t)TNX_LOCAL_ENT_FLAG_OFF, &flagOwn);

        TNX_LOGX("walkent used=%p own=%p found=%p flagUsed=%d flagOwn=%d mgrA=%p mgrB=%p mgrBraw=%d,%d "
                 "mgrBapp=%d,%d - the engine takes the local object for the input call out of the manager "
                 "collection, so the entity handed to the commit has to be that one and not the one the "
                 "scanner reads out of the battle array", (void *)ent, (void *)t_walk_entb_10,
                 (void *)t_walk_entc_10, (int)flagUsed, (int)flagOwn, (void *)mgr, (void *)mgrB,
                 mgrBrawX, mgrBrawY, mgrBappX, mgrBappY);
    }

    return;
}
