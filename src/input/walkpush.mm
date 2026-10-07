#include "recoil.h"

uintptr_t rcl_walk_ent = 0;







static uintptr_t rcl_walk_lookup_fn = 0;


static uintptr_t rcl_walk_entc = 0;

static int rcl_walk_on = 0;

static int32_t rcl_walk_px = 0;

static int32_t rcl_walk_py = 0;

static int32_t rcl_walk_tx = 0;

static int32_t rcl_walk_ty = 0;

static uint64_t rcl_walk_stamp = 0;

static uint64_t rcl_walk_frames = 0;

static uint8_t rcl_walk_knob_own = 0;

static float rcl_walk_knob_x = 0.0f;

static float rcl_walk_knob_y = 0.0f;



static uint8_t rcl_walk_save_f = 0;

static uint8_t rcl_walk_save_f7f = 0;

static uint64_t rcl_walk_gate_logs = 0;

static uintptr_t rcl_walk_mode_fn = 0;

static float rcl_walk_dead = 0.0f;

static uintptr_t rcl_walk_dead_a = 0;

static uintptr_t rcl_walk_dead_b = 0;

static int32_t rcl_ent_prev[RCL_ENT_SLOTS];


static uint32_t rcl_ent_chg[RCL_ENT_SLOTS];

static uint32_t rcl_ent_cd[RCL_ENT_SLOTS];

static uint32_t rcl_ent_co[RCL_ENT_SLOTS];

static uint8_t rcl_ent_seen[RCL_ENT_SLOTS];

static uint64_t rcl_ent_frames = 0;

static uint64_t rcl_ent_logs = 0;


static uintptr_t rcl_ent_last = 0;

static uintptr_t rcl_walk_fn = 0;



static void rcl_ent_summary(void) {
    uintptr_t ent = rcl_ent_last;
    uint64_t logs = 0;
    int i = 0;

    if (!ent) return;


    for (i = 0; i < RCL_ENT_SLOTS; i++) {
        if (rcl_ent_chg[i] < (uint32_t)RCL_ENT_SUM_MIN) continue;
        if (logs >= (uint64_t)RCL_ENT_SUM_LOGS) break;

        logs++;

    }

}

void rcl_ent_probe(uintptr_t ent, int knob, int ours) {
    int32_t buf[RCL_ENT_CHUNK / 4];
    uintptr_t base = 0;
    int32_t v = 0;
    int c = 0;
    int k = 0;
    int i = 0;

    if (!RCL_ENT_PROBE) return;
    if (!ent) return;

    if (ent != rcl_ent_last) {
        rcl_ent_last = ent;

        for (i = 0; i < RCL_ENT_SLOTS; i++) {
            rcl_ent_prev[i] = 0;
            rcl_ent_chg[i] = 0;
            rcl_ent_cd[i] = 0;
            rcl_ent_co[i] = 0;
            rcl_ent_seen[i] = 0;
        }
    }

    rcl_ent_frames++;

    if (rcl_ent_frames <= (uint64_t)RCL_ENT_WARMUP) {
        for (i = 0; i < RCL_ENT_SLOTS; i++) rcl_ent_seen[i] = 0;

        return;
    }

    for (c = 0; c < RCL_ENT_CHUNKS; c++) {
        base = ent + (uintptr_t)(c * RCL_ENT_CHUNK);

        if (!rcl_read_bytes(base, buf, sizeof(buf))) continue;

        for (k = 0; k < (int)(RCL_ENT_CHUNK / 4); k++) {
            i = c * (int)(RCL_ENT_CHUNK / 4) + k;
            v = buf[k];


            if (v == rcl_ent_prev[i]) continue;

            rcl_ent_prev[i] = v;
            rcl_ent_chg[i]++;

            if (knob) rcl_ent_cd[i]++;
            if (ours) rcl_ent_co[i]++;

            if (rcl_ent_seen[i] < (uint8_t)RCL_ENT_SAMPLE && rcl_ent_logs < (uint64_t)RCL_ENT_PROBE_LOGS) {
                rcl_ent_seen[i]++;
                rcl_ent_logs++;

            }
        }
    }

    if ((rcl_ent_frames % (uint64_t)RCL_ENT_SUM_EVERY) == 0) rcl_ent_summary();
}

static uintptr_t rcl_walk_lookup(uintptr_t mgr, uintptr_t ent) {
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

    if (!RCL_WALK_LOOKUP) return 0;
    if (!mgr || !ent) return 0;

    if (!rcl_read_ptr(mgr + (uintptr_t)RCL_CI_MGR_OBJLIST_OFF, (void **)&col) || !col) return 0;
    if (!rcl_read_ptr(col + 8, (void **)&inner) || !inner) return 0;

    if (!rcl_read_int(inner + 0xc, &cnt)) return 0;
    if (cnt < 1 || cnt > 64) return 0;
    if (!rcl_read_ptr(inner, (void **)&arr) || !arr) return 0;

    fn = rcl_walk_lookup_fn;

    if (!fn) {
        fn = rcl_entry_2(RVA_MGR_OBJ_LOOKUP_10);

        if (!fn && rcl_base) fn = rcl_base + RVA_MGR_OBJ_LOOKUP_10;

        rcl_walk_lookup_fn = fn;
    }

    if (!fn) return 0;

    res = ((uintptr_t (*)(void *, void *, int))fn)((void *)inner, (void *)ent, -1);

    if (!res) return 0;

    if (!rcl_read_int(res + (uintptr_t)RCL_OBJ_X_OFF, &rx)) return 0;
    if (!rcl_read_int(res + (uintptr_t)RCL_OBJ_Y_OFF, &ry)) return 0;
    if (!rcl_read_int(ent + (uintptr_t)RCL_OBJ_X_OFF, &ex)) return 0;
    if (!rcl_read_int(ent + (uintptr_t)RCL_OBJ_Y_OFF, &ey)) return 0;

    if (rx - ex > 400 || ex - rx > 400) return 0;
    if (ry - ey > 400 || ey - ry > 400) return 0;

    return res;
}

uintptr_t rcl_walk_mgr(void) {
    uintptr_t bs = rcl_bs();
    uintptr_t mgr = 0;

    if (!bs) return 0;
    if (!rcl_read_ptr(bs + (uintptr_t)RCL_JOY_TARGET_OFF, (void **)&mgr) || !mgr) return 0;

    return mgr;
}

void rcl_walk_want(int on, int32_t px, int32_t py, int32_t tx, int32_t ty) {
    rcl_walk_on = on ? 1 : 0;
    rcl_walk_px = px;
    rcl_walk_py = py;
    rcl_walk_tx = tx;
    rcl_walk_ty = ty;
    rcl_walk_stamp = rcl_walk_frames;
}

static uintptr_t rcl_walk_flip(void) {
    uint8_t flip = 0;
    uintptr_t addr = 0;

    addr = rcl_base + (uintptr_t)RVA_JOY_FLIP_10;

    if (!rcl_base) return 0;
    if (!rcl_read_byte(addr, &flip)) return 0;

    return flip ? 1 : 0;
}

void rcl_walk_pump(void) {
    uintptr_t mgr = 0;
    uintptr_t ent = rcl_walk_ent;
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
    float knobR = 0.0f;
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

    rcl_walk_frames++;

    if (!RCL_WALK_PUSH) return;

    on = rcl_walk_on;
    px = rcl_walk_px;
    py = rcl_walk_py;
    tx = rcl_walk_tx;
    ty = rcl_walk_ty;

    if (rcl_walk_frames - rcl_walk_stamp > (uint64_t)RCL_WALK_STALE) on = 0;

    mgr = rcl_walk_mgr();

    if (!mgr) return;
    if (!ent) return;

    if (!rcl_read_int(ent + (uintptr_t)RCL_OBJ_X_OFF, &ox)) return;
    if (!rcl_read_int(ent + (uintptr_t)RCL_OBJ_Y_OFF, &oy)) return;
    if (!rcl_read_int(ent + 0x24c, &span)) return;
    if (!rcl_read_int(mgr + (uintptr_t)RCL_CTRL_RAW_X_OFF, &rawX)) return;
    if (!rcl_read_int(mgr + (uintptr_t)RCL_CTRL_RAW_Y_OFF, &rawY)) return;
    if (!rcl_read_int(mgr + (uintptr_t)RCL_CTRL_APPLIED_X_OFF, &appX)) return;
    if (!rcl_read_int(mgr + (uintptr_t)RCL_CTRL_APPLIED_Y_OFF, &appY)) return;
    rcl_read_byte(mgr + (uintptr_t)RCL_CTRL_MOVE_OFF, &gF78);
    rcl_read_byte(mgr + (uintptr_t)RCL_TOUCH_GATE_OFF, &gF7F);

    latchB = 0;
    holdB = 0;

    rcl_read_byte(mgr + (uintptr_t)RCL_CTRL_LATCH_OFF, &latchB);
    rcl_read_byte(mgr + (uintptr_t)RCL_CTRL_ALIVE_OFF, &holdB);
    rcl_read_int(mgr + (uintptr_t)RCL_CTRL_DIRTY_OFF, &dirtyB);
    rcl_read_float(mgr + (uintptr_t)RCL_MARK_OFF, &timerB);

    mgrB = (uintptr_t)rcl_manager();

    if (mgrB) {
        rcl_read_int(mgrB + (uintptr_t)RCL_CTRL_RAW_X_OFF, &mgrBrawX);
        rcl_read_int(mgrB + (uintptr_t)RCL_CTRL_RAW_Y_OFF, &mgrBrawY);
        rcl_read_int(mgrB + (uintptr_t)RCL_CTRL_APPLIED_X_OFF, &mgrBappX);
        rcl_read_int(mgrB + (uintptr_t)RCL_CTRL_APPLIED_Y_OFF, &mgrBappY);
    }

    knob = 0;

    if (rcl_read_float(mgr + 0xa40, &knobA[0]) && rcl_read_float(mgr + 0xa44, &knobA[1])
        && rcl_read_float(mgr + 0xa48, &knobB[0]) && rcl_read_float(mgr + 0xa4c, &knobB[1])) {
        if (knobA[0] - knobB[0] > 1.0f || knobB[0] - knobA[0] > 1.0f) knob = 1;
        if (knobA[1] - knobB[1] > 1.0f || knobB[1] - knobA[1] > 1.0f) knob = 1;
    }

    rcl_walk_entc = rcl_walk_lookup(mgr, ent);

    if (rcl_walk_entc && rcl_walk_entc != ent) {
        int32_t ux = 0;
        int32_t uy = 0;

        if (rcl_read_int(rcl_walk_entc + (uintptr_t)RCL_OBJ_X_OFF, &ux)
            && rcl_read_int(rcl_walk_entc + (uintptr_t)RCL_OBJ_Y_OFF, &uy)) {
            if (ux - ox <= 400 && ox - ux <= 400 && uy - oy <= 400 && oy - uy <= 400) {
                ent = rcl_walk_entc;
                ox = ux;
                oy = uy;
            }
        }
    }

    if (ox - px > 250 || px - ox > 250) return;
    if (oy - py > 250 || py - oy > 250) return;

    if (!on) {
        if (rcl_walk_knob_own) {
            float rx = 0.0f;
            float ry = 0.0f;
            float cx = 0.0f;
            float cy = 0.0f;

            if (rcl_read_float(mgr + (uintptr_t)RCL_JOY_ORG_X_OFF, &rx)
                && rcl_read_float(mgr + (uintptr_t)RCL_JOY_ORG_Y_OFF, &ry)
                && rcl_read_float(mgr + (uintptr_t)RCL_JOY_CUR_X_OFF, &cx)
                && rcl_read_float(mgr + (uintptr_t)RCL_JOY_CUR_Y_OFF, &cy)) {
                float ax = rcl_walk_knob_x - cx;
                float ay = rcl_walk_knob_y - cy;

                if (ax <= 0.5f && ax >= -0.5f && ay <= 0.5f && ay >= -0.5f) {
                    rcl_write_float(mgr + (uintptr_t)RCL_JOY_CUR_X_OFF, rx);
                    rcl_write_float(mgr + (uintptr_t)RCL_JOY_CUR_Y_OFF, ry);
                }

                if (RCL_WALK_HOLD) {
                    rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_MOVE_OFF, &rcl_walk_save_f, sizeof(rcl_walk_save_f));
                    rcl_write_bytes(mgr + (uintptr_t)RCL_TOUCH_GATE_OFF, &rcl_walk_save_f7f, sizeof(rcl_walk_save_f7f));
                }

                rcl_walk_knob_own = 0;
                knobRestored = 1;
            }
        }

        if (rawX != 0 || rawY != 0) {
            rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_RAW_X_OFF, &backX, sizeof(backX));
            rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_RAW_Y_OFF, &backY, sizeof(backY));

            wrote = 1;
        }

        rcl_ent_probe(ent, knob, 0);


        return;
    }

    dx = (float)(tx - ox);
    dy = (float)(ty - oy);
    len = __builtin_sqrtf(dx * dx + dy * dy);

    if (len < 1.0f) return;

    dx /= len;
    dy /= len;

    dirX = (int32_t)(dx * RCL_WALK_PUSH_RAW);
    dirY = (int32_t)(dy * RCL_WALK_PUSH_RAW);

    if (dirX == 0 && dirY == 0) return;

    rad = (float)(span / 5);

    if (rad < 1.0f) return;

    goalX = ox + (int32_t)(dx * rad);
    goalY = oy + (int32_t)(dy * rad);

    jump = (int64_t)(goalX - appX) * (int64_t)(goalX - appX)
         + (int64_t)(goalY - appY) * (int64_t)(goalY - appY);


    knobOk = 0;

    if (RCL_WALK_KNOB) {
        if (rcl_read_float(mgr + (uintptr_t)RCL_JOY_ORG_X_OFF, &orgX)
            && rcl_read_float(mgr + (uintptr_t)RCL_JOY_ORG_Y_OFF, &orgY)
            && rcl_read_float(mgr + (uintptr_t)RCL_JOY_CUR_X_OFF, &curX)
            && rcl_read_float(mgr + (uintptr_t)RCL_JOY_CUR_Y_OFF, &curY)) knobOk = 1;
    }

    curBefore = curX;

    if (knobOk) {
        knobX = curX - orgX;
        knobY = curY - orgY;

        if (knobX > 1.0f || knobX < -1.0f || knobY > 1.0f || knobY < -1.0f) knobHeld = 1;
    }

    if (knobOk) {
        flip = rcl_walk_flip();
        sign = flip ? -1.0f : 1.0f;

        if (rcl_walk_dead <= 0.0f) {
            int da = 0;
            int db = 0;

            if (!rcl_walk_dead_a) {
                rcl_walk_dead_a = rcl_entry_2(RVA_DEAD_A_11);

                if (!rcl_walk_dead_a && rcl_base) rcl_walk_dead_a = rcl_base + RVA_DEAD_A_11;
            }

            if (!rcl_walk_dead_b) {
                rcl_walk_dead_b = rcl_entry_2(RVA_DEAD_B_11);

                if (!rcl_walk_dead_b && rcl_base) rcl_walk_dead_b = rcl_base + RVA_DEAD_B_11;
            }

            if (rcl_walk_dead_a && rcl_walk_dead_b) {
                da = ((int (*)(void))rcl_walk_dead_a)();
                db = ((int (*)(void))rcl_walk_dead_b)();
            }

            if (da > 0 && db > 0) rcl_walk_dead = RCL_DEAD_CONST / (1.0f + (float)da / (float)db);
            else rcl_walk_dead = 12.0f;
        }

        knobR = rcl_walk_dead * RCL_WALK_DEAD_GAIN + RCL_WALK_DEAD_PAD;

        if (knobR < 10.0f) knobR = 10.0f;
        if (knobR > 60.0f) knobR = 60.0f;

        knobX = orgX + dx * sign * knobR;
        knobY = orgY + dy * sign * knobR;

        if (!rcl_walk_knob_own) {
            rcl_walk_save_f = gF78;
            rcl_walk_save_f7f = gF7F;
        }

        if (RCL_WALK_HOLD) {
            rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_MOVE_OFF, &one, sizeof(one));

            if (RCL_WALK_HOLD_GATE) rcl_write_bytes(mgr + (uintptr_t)RCL_TOUCH_GATE_OFF, &one, sizeof(one));
        }

        rcl_write_float(mgr + (uintptr_t)RCL_JOY_CUR_X_OFF, knobX);
        rcl_write_float(mgr + (uintptr_t)RCL_JOY_CUR_Y_OFF, knobY);

        rcl_walk_knob_own = 1;
        rcl_walk_knob_x = knobX;
        rcl_walk_knob_y = knobY;

        knobWrote = 1;
    } else {
        rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_RAW_X_OFF, &dirX, sizeof(dirX));
        rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_RAW_Y_OFF, &dirY, sizeof(dirY));

        wrote = 1;
    }


    if (knobWrote) {
        sent = 1;
    } else if (jump < (int64_t)RCL_WALK_PUSH_MIN_JUMP || rad < 60.0f || rad > 1500.0f) {
    } else {
        fn = rcl_walk_fn;

        if (!fn) {
            fn = rcl_entry_2(RVA_INPUT_COMMIT_10);

            if (!fn && rcl_base) fn = rcl_base + RVA_INPUT_COMMIT_10;

            rcl_walk_fn = fn;
        }

        if (fn) {
            ((void (*)(void *, void *, void *, int))fn)((void *)mgr, (void *)ent, (void *)ent, 1);

            sent = 1;


            if (RCL_WALK_HS) {
                latch = (uint8_t)RCL_CTRL_LATCH_VAL;
                dirty = (int32_t)RCL_CTRL_DIRTY_VAL;
                hold = 1;
                timer = RCL_WALK_HS_TIMER;

                rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_LATCH_OFF, &latch, sizeof(latch));
                rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_DIRTY_OFF, &dirty, sizeof(dirty));
                rcl_write_float(mgr + (uintptr_t)RCL_MARK_OFF, timer);
                rcl_write_bytes(mgr + (uintptr_t)RCL_CTRL_ALIVE_OFF, &hold, sizeof(hold));

            }
        }
    }

    if (!rcl_read_int(mgr + (uintptr_t)RCL_CTRL_APPLIED_X_OFF, &appX)) appX = 0;
    if (!rcl_read_int(mgr + (uintptr_t)RCL_CTRL_APPLIED_Y_OFF, &appY)) appY = 0;

    rcl_ent_probe(ent, knob, (wrote || knobWrote) ? 1 : 0);

    if (rcl_walk_gate_logs < (uint64_t)RCL_WALK_GATE_LOGS) {
        rcl_walk_gate_logs++;

        gObj = 0;
        gMode = -1;

        rcl_read_byte(mgr + 0xf78, &gF78);
        rcl_read_byte(mgr + 0xf9e, &gF9E);
        rcl_read_byte(mgr + 0xf7f, &gF7F);
        rcl_read_byte(mgr + 0xf80, &gF80);
        rcl_read_byte(mgr + 0x1041, &g1041);
        rcl_read_byte(mgr + 0x1042, &g1042);

        if (ent) {
            rcl_read_byte(ent + 0x32a, &gE32A);
            rcl_read_byte(ent + 0x240, &gE240);
            rcl_read_int(ent + 0x13c, &gE13C);
        }

        if (rcl_read_ptr(mgr + (uintptr_t)RCL_WALK_OBJ_OFF, (void **)&gObj) && gObj) {
            gFn = rcl_walk_mode_fn;

            if (!gFn) {
                gFn = rcl_entry_2(RVA_WALK_MODE_10);

                if (!gFn && rcl_base) gFn = rcl_base + RVA_WALK_MODE_10;

                rcl_walk_mode_fn = gFn;
            }

            if (gFn) gMode = ((int (*)(void *))gFn)((void *)gObj);
        }

    }

    return;
}
