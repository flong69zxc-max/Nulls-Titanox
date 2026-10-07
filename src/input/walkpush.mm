#include "titanox.h"

uintptr_t t_walk_ent_6 = 0;

uint64_t t_walk_scans_6 = 0;

uint64_t t_walk_sends_6 = 0;

uint64_t t_walk_near_6 = 0;

uint64_t t_walk_hand_6 = 0;

static uint64_t t_walk_logs_6 = 0;

static uint64_t t_walk_offlogs_6 = 0;

static int32_t t_ent_prev_6[TNX_ENT_SLOTS_6];

static int32_t t_ent_cur_6[TNX_ENT_SLOTS_6];

static uint32_t t_ent_chg_6[TNX_ENT_SLOTS_6];

static uint32_t t_ent_cd_6[TNX_ENT_SLOTS_6];

static uint32_t t_ent_co_6[TNX_ENT_SLOTS_6];

static uint8_t t_ent_seen_6[TNX_ENT_SLOTS_6];

static uint64_t t_ent_frames_6 = 0;

static uint64_t t_ent_logs_6 = 0;

static uint64_t t_ent_sums_6 = 0;

static uintptr_t t_ent_last_6 = 0;

static uintptr_t t_walk_fn_6 = 0;

static int32_t t_walk_dir_6[2] = { 0, 0 };

static int32_t t_walk_goal_6[2] = { 0, 0 };

static void tnx_ent_summary_6(void) {
    uintptr_t ent = t_ent_last_6;
    uint64_t logs = 0;
    int i = 0;

    if (!ent) return;

    TNX_LOGX("entsum begin frames=%llu ent=%p slots=%d min=%d chunk=%d - knob marks the frames the native "
             "stick was displaced and ours the frames our walk wrote the pair, so an offset the native walk "
             "moves and our walk never touches is the state we are still missing",
             (unsigned long long)t_ent_frames_6, (void *)ent, (int)TNX_ENT_SLOTS_6, (int)TNX_ENT_SUM_MIN_6,
             (int)TNX_ENT_CHUNK_6);

    for (i = 0; i < TNX_ENT_SLOTS_6; i++) {
        if (t_ent_chg_6[i] < (uint32_t)TNX_ENT_SUM_MIN_6) continue;
        if (logs >= (uint64_t)TNX_ENT_SUM_LOGS_6) break;

        logs++;

        TNX_LOGX("entsum off=+%#x chg=%llu knob=%llu ours=%llu last=%d", (unsigned)(i * 4),
                 (unsigned long long)t_ent_chg_6[i], (unsigned long long)t_ent_cd_6[i],
                 (unsigned long long)t_ent_co_6[i], t_ent_cur_6[i]);
    }

    t_ent_sums_6++;
}

void tnx_ent_probe_6(uintptr_t ent, int knob, int ours) {
    int32_t buf[TNX_ENT_CHUNK_6 / 4];
    uintptr_t base = 0;
    int32_t v = 0;
    int c = 0;
    int k = 0;
    int i = 0;

    if (!TNX_ENT_PROBE_6) return;
    if (!ent) return;

    if (ent != t_ent_last_6) {
        t_ent_last_6 = ent;

        for (i = 0; i < TNX_ENT_SLOTS_6; i++) {
            t_ent_prev_6[i] = 0;
            t_ent_cur_6[i] = 0;
            t_ent_chg_6[i] = 0;
            t_ent_cd_6[i] = 0;
            t_ent_co_6[i] = 0;
            t_ent_seen_6[i] = 0;
        }
    }

    t_ent_frames_6++;

    for (c = 0; c < TNX_ENT_CHUNKS_6; c++) {
        base = ent + (uintptr_t)(c * TNX_ENT_CHUNK_6);

        if (!tnx_read_bytes(base, buf, sizeof(buf))) continue;

        for (k = 0; k < (int)(TNX_ENT_CHUNK_6 / 4); k++) {
            i = c * (int)(TNX_ENT_CHUNK_6 / 4) + k;
            v = buf[k];

            t_ent_cur_6[i] = v;

            if (v == t_ent_prev_6[i]) continue;

            t_ent_prev_6[i] = v;
            t_ent_chg_6[i]++;

            if (knob) t_ent_cd_6[i]++;
            if (ours) t_ent_co_6[i]++;

            if (t_ent_seen_6[i] < (uint8_t)TNX_ENT_SAMPLE_6 && t_ent_logs_6 < (uint64_t)TNX_ENT_PROBE_LOGS_6) {
                t_ent_seen_6[i]++;
                t_ent_logs_6++;

                TNX_LOGX("entchg off=+%#x val=%d knob=%d ours=%d chg=%llu", (unsigned)(i * 4), v, knob, ours,
                         (unsigned long long)t_ent_chg_6[i]);
            }
        }
    }

    if ((t_ent_frames_6 % (uint64_t)TNX_ENT_SUM_EVERY_6) == 0) tnx_ent_summary_6();
}

uintptr_t tnx_walk_mgr_6(void) {
    uintptr_t bs = tnx_bs();
    uintptr_t mgr = 0;

    if (!bs) return 0;
    if (!tnx_read_ptr(bs + (uintptr_t)TNX_JOY_TARGET_OFF, (void **)&mgr) || !mgr) return 0;

    return mgr;
}

int tnx_walk_push_6(int on, int32_t px, int32_t py, int32_t tx, int32_t ty) {
    uintptr_t mgr = 0;
    uintptr_t ent = t_walk_ent_6;
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
    float knobA[2] = { 0.0f, 0.0f };
    float knobB[2] = { 0.0f, 0.0f };
    int knob = 0;
    uint8_t latchB = 0;
    uint8_t holdB = 0;
    int32_t dirtyB = 0;
    float timerB = 0.0f;
    int wrote = 0;
    int sent = 0;

    if (!TNX_WALK_PUSH_6) return 0;

    mgr = tnx_walk_mgr_6();

    if (!mgr) return 0;
    if (!ent) return 0;

    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_X_OFF, &ox)) return 0;
    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_Y_OFF, &oy)) return 0;
    if (!tnx_read_i32(ent + 0x24c, &span)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    latchB = 0;
    holdB = 0;

    tnx_read_u8(mgr + (uintptr_t)TNX_CTRL_LATCH_OFF, &latchB);
    tnx_read_u8(mgr + (uintptr_t)TNX_CTRL_ALIVE_OFF, &holdB);
    tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_DIRTY_OFF, &dirtyB);
    tnx_read_f32(mgr + (uintptr_t)TNX_MARK_OFF, &timerB);

    knob = 0;

    if (tnx_read_f32(mgr + 0xa40, &knobA[0]) && tnx_read_f32(mgr + 0xa44, &knobA[1])
        && tnx_read_f32(mgr + 0xa48, &knobB[0]) && tnx_read_f32(mgr + 0xa4c, &knobB[1])) {
        if (knobA[0] - knobB[0] > 1.0f || knobB[0] - knobA[0] > 1.0f) knob = 1;
        if (knobA[1] - knobB[1] > 1.0f || knobB[1] - knobA[1] > 1.0f) knob = 1;
    }

    if (ox - px > 250 || px - ox > 250) return 0;
    if (oy - py > 250 || py - oy > 250) return 0;

    if (!on) {
        if (rawX != 0 || rawY != 0) {
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &backX, sizeof(backX));
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &backY, sizeof(backY));

            wrote = 1;
        }

        tnx_ent_probe_6(ent, knob, 0);

        if (t_walk_offlogs_6 < TNX_WALK_OFF_LOGS_6) {
            t_walk_offlogs_6++;

            TNX_LOGX("walkpush off n=%llu mgr=%p ent=%p own=(%d,%d) raw=%d,%d wrote=%d scans=%llu sends=%llu "
                     "near=%llu - no walk this frame, the raw pair goes back to zero and nothing else is touched",
                     (unsigned long long)t_walk_offlogs_6, (void *)mgr, (void *)ent, ox, oy, rawX, rawY, wrote,
                     (unsigned long long)t_walk_scans_6, (unsigned long long)t_walk_sends_6,
                     (unsigned long long)t_walk_near_6);
        }

        return 0;
    }

    dx = (float)(tx - ox);
    dy = (float)(ty - oy);
    len = __builtin_sqrtf(dx * dx + dy * dy);

    if (len < 1.0f) return 0;

    dx /= len;
    dy /= len;

    dirX = (int32_t)(dx * TNX_WALK_PUSH_RAW_6);
    dirY = (int32_t)(dy * TNX_WALK_PUSH_RAW_6);

    if (dirX == 0 && dirY == 0) return 0;

    rad = (float)(span / 5);

    if (rad < 1.0f) return 0;

    goalX = ox + (int32_t)(dx * rad);
    goalY = oy + (int32_t)(dy * rad);

    jump = (int64_t)(goalX - appX) * (int64_t)(goalX - appX)
         + (int64_t)(goalY - appY) * (int64_t)(goalY - appY);

    t_walk_dir_6[0] = dirX;
    t_walk_dir_6[1] = dirY;
    t_walk_goal_6[0] = goalX;
    t_walk_goal_6[1] = goalY;

    tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &dirX, sizeof(dirX));
    tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &dirY, sizeof(dirY));

    wrote = 1;

    t_walk_scans_6++;

    if (jump < (int64_t)TNX_WALK_PUSH_MIN_JUMP_6 || rad < 60.0f || rad > 1500.0f) {
        t_walk_near_6++;
    } else {
        fn = t_walk_fn_6;

        if (!fn) {
            fn = tnx_entry_2(RVA_INPUT_COMMIT_6);

            if (!fn && t_base) fn = t_base + RVA_INPUT_COMMIT_6;

            t_walk_fn_6 = fn;
        }

        if (fn) {
            ((void (*)(void *, void *, void *, int))fn)((void *)mgr, (void *)ent, (void *)ent, 1);

            sent = 1;

            t_walk_sends_6++;

            if (TNX_WALK_HS_6) {
                latch = (uint8_t)TNX_CTRL_LATCH_VAL;
                dirty = (int32_t)TNX_CTRL_DIRTY_VAL;
                hold = 1;
                timer = TNX_WALK_HS_TIMER_6;

                tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_LATCH_OFF, &latch, sizeof(latch));
                tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_DIRTY_OFF, &dirty, sizeof(dirty));
                tnx_write_f32(mgr + (uintptr_t)TNX_MARK_OFF, timer);
                tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_ALIVE_OFF, &hold, sizeof(hold));

                t_walk_hand_6++;
            }
        }
    }

    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &appX)) appX = 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &appY)) appY = 0;

    tnx_ent_probe_6(ent, knob, wrote);

    if (t_walk_logs_6 < TNX_WALK_PUSH_LOGS_6) {
        t_walk_logs_6++;

        TNX_LOGX("walkpush n=%llu mgr=%p ent=%p own=(%d,%d) want=(%d,%d) dir=(%d,%d) span=%d goal=(%d,%d) "
                 "applied=(%d,%d) jump=%lld sent=%d wrote=%d fn=%p hsBefore=(%d,%d,%g,%d) hsAfter=(%d,%d,%g,%d) "
                 "scans=%llu sends=%llu near=%llu hand=%llu - the engine takes the walk direction from the raw "
                 "pair and rebuilds the target from it, and the tail of the native commit writes the latch, the "
                 "dirty word, the input timer and the hold byte, so the pair carries the same numbers the native "
                 "touch writes and the visible knob pair stays untouched",
                 (unsigned long long)t_walk_logs_6, (void *)mgr, (void *)ent, ox, oy, tx, ty,
                 t_walk_dir_6[0], t_walk_dir_6[1], span, t_walk_goal_6[0], t_walk_goal_6[1], appX, appY,
                 (long long)jump, sent, wrote, (void *)fn,
                 (int)latchB, (int)dirtyB, (double)timerB, (int)holdB,
                 (int)latch, (int)dirty, (double)timer, (int)hold,
                 (unsigned long long)t_walk_scans_6, (unsigned long long)t_walk_sends_6,
                 (unsigned long long)t_walk_near_6, (unsigned long long)t_walk_hand_6);
    }

    return sent;
}
