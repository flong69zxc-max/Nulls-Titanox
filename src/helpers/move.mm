#include "titanox.h"

#ifndef TNX_JS_STICK
#define TNX_JS_STICK 1
#endif

#ifndef TNX_JS_HOLD
#define TNX_JS_HOLD 2
#endif

#ifndef TNX_STICK_RAW_WRITE
#define TNX_STICK_RAW_WRITE 1
#define TNX_PRED_SPAN 0x118
#endif

uint32_t g_token_2 = 0;

uint64_t g_diag_us = 0;

uint64_t g_diag_max_us = 0;

int g_dead_probe_done = 0;

int tnx_mode_2(void) {
    int mates = g_mate_n;
    int en = g_enemy_n;

    if (!TNX_MODE_TUNE) return 2;
    if (mates <= 0 && en <= 1) return 0;
    if (mates <= 0) return 1;
    if (mates <= 2) return 2;

    return 3;
}

float tnx_look_ms(void) {
    static const float looks[4] = { 420.0f, 550.0f, 650.0f, 800.0f };

    return looks[tnx_mode_2()];
}

uint64_t g_clamped = 0;

uint64_t g_ctrl_dead = 0;

uint64_t g_stuck_3 = 0;

uint64_t g_mask_before = 0;

int tnx_ctrl_ok(uintptr_t ctrl) {
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    void *vt = NULL;

    if (!ctrl) return 0;
    if (!tnx_writable(ctrl + TNX_FLAG_OFF_2, TNX_CTRL_APPLIED_Y_OFF -
                           TNX_FLAG_OFF_2 + sizeof(int32_t))) {
        g_ctrl_dead++;

        return 0;
    }
    if (!tnx_writable(ctrl + TNX_CUR_X_OFF, TNX_ORG_Y_OFF -
                           TNX_CUR_X_OFF + sizeof(float))) {
        g_ctrl_dead++;

        return 0;
    }
    if (TNX_STALE_SIGHT && tnx_read_ptr(ctrl, &vt) && vt) {
        if ((uintptr_t)vt < g_base || (uintptr_t)vt >= g_base + TNX_IMAGE_SPAN) g_stale++;
    }
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    if (rawX < -TNX_DEGEN || rawX > TNX_DEGEN) { g_ctrl_dead++; return 0; }
    if (rawY < -TNX_DEGEN || rawY > TNX_DEGEN) { g_ctrl_dead++; return 0; }
    if (appX < -TNX_DEGEN || appX > TNX_DEGEN) { g_ctrl_dead++; return 0; }
    if (appY < -TNX_DEGEN || appY > TNX_DEGEN) { g_ctrl_dead++; return 0; }

    return 1;
}

int g_body_blocks = 0;

int g_body_mine = 0;

int g_body_enemy = 0;

int g_body_logs = 0;

uint64_t g_human_live = 0;

int g_input_skips = 0;

int g_wrote_input = 0;

int g_engaged_frame = 0;

int g_neutral_logs = 0;

int g_test_state_2 = 0;

uint64_t g_test_tick = 0;

int g_test_before_x = 0;

int g_test_before_y = 0;

int g_test_after_x_2 = 0;

int g_test_after_y_2 = 0;

int g_moved_2 = 0;

int g_moved2_2 = 0;

int g_kept_2 = 0;

int g_tested_2 = 0;

uint64_t g_enqueues = 0;

int g_enq_x = 0;

int g_enq_y = 0;

int g_q_before = -1;

int g_q_after = -1;

int g_readback = -1;

int g_readback_tick = -1;

int g_hop2_logs = 0;

int g_hop2_filled = 0;

uintptr_t g_hop2 = 0;

int g_queue_logs = 0;

int g_window_logs = 0;

uint64_t g_push_frame = 0;

int g_frame_logs = 0;

uint64_t g_test_tickbase = 0;

int g_enq_ok = 0;

const char *g_alloc_how = "none";

void *g_msg = NULL;

int g_seq_before = -1;

int g_seq_after = -1;

int g_q_before_2 = -1;

int g_q_after_2 = -1;

void *g_q_last = NULL;

int32_t g_scene_before_x = 0;

int32_t g_scene_before_y = 0;

uint64_t g_watch_from = 0;

int g_watch_logs = 0;

void *tnx_msg_alloc(void) {
    uintptr_t stub = tnx_entry_2(TNX_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub) {
        g_alloc_how = "stub";
        return ((void *(*)(size_t))stub)((size_t)TNX_MSG_SIZE);
    }

    if (g_base && tnx_read_ptr(g_base + TNX_ALLOC_GOT_RVA, (void **)&got) && got) {
        g_alloc_how = "got";
        return ((void *(*)(size_t))got)((size_t)TNX_MSG_SIZE);
    }

    g_alloc_how = "malloc";

    return malloc((size_t)TNX_MSG_SIZE);
}

void *tnx_q_last(void) {
    void *mgr = tnx_manager();
    void *queue = NULL;
    void *arr = NULL;
    int32_t count = 0;
    void *e = NULL;

    if (!mgr) return NULL;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_QUEUE_OFF, &queue) || !queue) return NULL;
    if (!tnx_read_i32((uintptr_t)queue + TNX_QUEUE_COUNT_OFF, &count) || count <= 0) return NULL;
    if (!tnx_read_ptr((uintptr_t)queue, &arr) || !arr) return NULL;
    if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)(count - 1) * 8ULL, &e)) return NULL;

    return e;
}

uintptr_t tnx_entry_2(uintptr_t rva) {
    if (!g_base || !rva) return 0;
    if (!tnx_callable(rva)) return 0;

    return g_base + rva;
}

void *tnx_manager(void) {
    uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
    void *battle = NULL;
    void *mgr = NULL;

    if (!battleFn) return NULL;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) return NULL;
    if (!tnx_read_ptr((uintptr_t)battle + TNX_MGR_OFF, &mgr) || !mgr) return NULL;

    return mgr;
}

int tnx_queue_count(uintptr_t *mgrOut) {
    void *mgr = tnx_manager();
    void *queue = NULL;
    int32_t count = -1;

    if (mgrOut) *mgrOut = (uintptr_t)mgr;
    if (!mgr) return -1;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_QUEUE_OFF, &queue) || !queue) return -1;
    if (!tnx_read_i32((uintptr_t)queue + TNX_QUEUE_COUNT_OFF, &count)) return -1;

    return (int)count;
}

uintptr_t g_pred_last = 0;

int g_predict_logs = 0;

uint64_t g_pred_calls = 0;

uint64_t g_pred_fails = 0;

int tnx_predict(int32_t x, int32_t y) {
    uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
    void *battle = NULL;

    if (!TNX_PREDICT) return 0;
    if (!g_addr_setprediction) return 0;
    if (!battleFn) return 0;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) {
        g_pred_fails++;

        return 0;
    }

    ((void (*)(void *, int, int, int))g_addr_setprediction)(battle, x, y, TNX_PREDICT_FLAG);

    {
        int32_t px = 0;
        int32_t py = 0;

        tnx_read_i32((uintptr_t)battle + TNX_MODE_PREDICTX_OFF, &px);
        tnx_read_i32((uintptr_t)battle + TNX_MODE_PREDICTY_OFF, &py);

        if (TNX_GATE_WRITE) {
            uint8_t one = 1;
            uint8_t back = 0;

            tnx_write_bytes((uintptr_t)battle + TNX_GATE_OFF, &one, sizeof(one));
            g_gate_writes_2++;

            if (tnx_read_bytes((uintptr_t)battle + TNX_GATE_OFF, &back, sizeof(back)) &&
                back == 1) {
                g_gate_held++;
            }
        }

        if (px == x && py == y) g_pred_took++;
        else g_pred_miss++;

        if (g_pred_logs < TNX_PRED_LOGS) {
            g_pred_logs++;

            TNX_LOGX("predict battle=%p sent=(%d,%d) read=(%d,%d) took=%llu miss=%llu", battle, x, y, px, py,
                     (unsigned long long)g_pred_took, (unsigned long long)g_pred_miss);
        }
    }

    g_pred_last = (uintptr_t)battle;
    g_pred_calls++;

    if (g_predict_logs < TNX_PREDICT_LOGS) {
        g_predict_logs++;

        TNX_LOGX("predict call=%llu battle=%p target=(%d,%d) fn=%p",
                 (unsigned long long)g_pred_calls, battle, x, y, (void *)g_addr_setprediction,
                 (unsigned long long)TNX_MGR_OFF);
    }

    return 1;
}

int tnx_pending(int want, uint64_t *mask) {
    void *mgr = NULL;
    void *list = NULL;
    void *arr = NULL;
    int32_t count = 0;
    int found = 0;
    int i = 0;

    if (mask) *mask = 0;

    mgr = tnx_manager();

    if (!mgr) return 0;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_LIST_OFF, &list) || !list) return 0;
    if (!tnx_read_i32((uintptr_t)list + TNX_COUNT_OFF_2, &count)) return 0;
    if (count <= 0 || count > 64) return 0;
    if (!tnx_read_ptr((uintptr_t)list, &arr) || !arr) return 0;

    for (i = 0; i < count; i++) {
        void *el = NULL;
        int32_t t = -1;

        if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)i * sizeof(void *), &el) || !el) continue;
        if (!tnx_read_i32((uintptr_t)el + TNX_TYPE_OFF, &t)) continue;
        if (mask && t >= 0 && t < 21) *mask |= (1ULL << t);
        if (t == want) found = 1;
    }

    return found;
}

static int g_pred_ok = 0;

static int tnx_pred_probe(uintptr_t pred, int *alignOut, int *readOut, int *writeOut, int *vtOut) {
    void *vtRaw = NULL;
    uintptr_t vt = 0;

    if (alignOut) *alignOut = 0;
    if (readOut) *readOut = 0;
    if (writeOut) *writeOut = 0;
    if (vtOut) *vtOut = 0;

    if (!pred) return 0;
    if ((pred & 7) != 0) return 0;

    if (alignOut) *alignOut = 1;

    if (!tnx_addr_readable(pred, TNX_PRED_SPAN)) return 0;

    if (readOut) *readOut = 1;

    if (!tnx_addr_writable(pred, TNX_PRED_SPAN)) return 0;

    if (writeOut) *writeOut = 1;

    if (!tnx_read_ptr(pred, &vtRaw)) return 0;

    vt = (uintptr_t)vtRaw;

    if (!vt) return 0;

    if (vtOut) *vtOut = 1;

    return 1;
}

static int tnx_pred_ok(uintptr_t pred) {
    return tnx_pred_probe(pred, NULL, NULL, NULL, NULL);
}

int tnx_pred_set(int x, int y) {
    uintptr_t setFn = 0;
    uintptr_t pred = 0;

    if (!TNX_PRED_SET) return 0;

    setFn = tnx_entry_2(TNX_SETINPUT_RVA);

    if (!setFn) return 0;

    pred = tnx_controller();

    if (!tnx_pred_ok(pred)) {
        if (g_pred_ok < 4) {
            TNX_LOGX("predMiss pred=%p - the receiver is the logic client itself, no hop, and a "
                     "receiver that fails here is one the write cannot land on, so nothing of the "
                     "local prediction follows the dodge on this frame", (void *)pred);
            g_pred_ok++;
        }

        return 0;
    }

    ((void (*)(uintptr_t, int, int, int))setFn)(pred, x, y, TNX_PRED_FLAG);

    if (g_pred_ok < 4) {
        TNX_LOGX("predSet pred=%p x=%d y=%d flag=%d", (void *)pred, x, y, (int)TNX_PRED_FLAG);
        g_pred_ok++;
    }

    return 1;
}

int g_enq_stop_1 = 0;

int g_enq_stop_2 = 0;

int g_enq_stop_3 = 0;

int g_enq_stop_4 = 0;

int tnx_enqueue(int x, int y) {

    uintptr_t ctorFn = tnx_entry_2(TNX_MSGCTOR_RVA);
    uintptr_t inputFn = tnx_entry_2(TNX_ADDINPUT_RVA);
    int32_t vx = x;
    int32_t vy = y;
    int32_t type = TNX_TYPE_MOVE;
    void *mgr = NULL;
    void *msg = NULL;

    g_enq_ok = 0;
    g_msg = NULL;
    g_q_last = NULL;
    g_seq_before = -1;
    g_seq_after = -1;
    g_q_before_2 = -1;
    g_q_after_2 = -1;

    if (!inputFn) {
        if (g_enq_stop_1 < 8) {
            g_enq_stop_1++;

            TNX_LOGX("enqueueStop addInput rva=%#llx base=%p callable=0",
                     (unsigned long long)TNX_ADDINPUT_RVA, (void *)g_base);
        }

        return 0;
    }

    msg = tnx_msg_alloc();

    if (!msg) {
        if (g_enq_stop_2 < 8) {
            g_enq_stop_2++;

            TNX_LOGX("enqueueStop alloc how=%s size=%#llx", g_alloc_how,
                     (unsigned long long)TNX_MSG_SIZE, (unsigned long long)TNX_MSG_SIZE);
        }

        return 0;
    }

    memset(msg, 0, (size_t)TNX_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, TNX_TYPE_MOVE);

    tnx_write_bytes((uintptr_t)msg + TNX_TYPE_OFF, &type, sizeof(type));
    tnx_write_bytes((uintptr_t)msg + TNX_X_OFF, &vx, sizeof(vx));
    tnx_write_bytes((uintptr_t)msg + TNX_Y_OFF, &vy, sizeof(vy));

    {
        uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);

        g_token_2 = 0;
        g_raw_x = 0;
        g_raw_y = 0;

        if (battleFn) {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) g_token_2 = tnx_ci_sign(msg, battle);
        }
    }

    (void)tnx_pred_set(x, y);

    mgr = tnx_manager();

    if (!mgr) {
        TNX_LOGX("queuePush aborted x=%d y=%d msg=%p alloc=%s",
                 x, y, msg, g_alloc_how, (unsigned long long)TNX_MGR_OFF);

        return 0;
    }

    tnx_read_i32((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &g_seq_before);

    g_q_before_2 = tnx_queue_count(NULL);

    if (tnx_pending(TNX_TYPE_MOVE, &g_mask_before)) {
        g_stuck_3++;
    }

    {
        void *mgrInner = NULL;

        if (!tnx_read_ptr((uintptr_t)mgr + TNX_CI_MGR_QUEUE_OFF, &mgrInner) || !mgrInner) {
            if (g_enq_stop_3 < 8) {
                g_enq_stop_3++;

                TNX_LOGX("enqueueStop queueSlot mgr=%p slot+%#llx=%p", (void *)mgr,
                         (unsigned long long)TNX_CI_MGR_QUEUE_OFF, (void *)mgrInner);
            }

            return 0;
        }
    }

    g_enq_stop_4++;

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    g_seq_after = -1;
    tnx_read_i32((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &g_seq_after);
    g_q_after_2 = tnx_queue_count(NULL);
    g_q_last = tnx_q_last();
    g_msg = msg;
    g_enq_ok = 1;

    if (TNX_QUEUE) {
        if (g_q_after_2 <= 0) g_drain++;
        if ((uint64_t)(g_q_after_2 > 0 ? g_q_after_2 : 0) > g_q_max) {
            g_q_max = (uint64_t)g_q_after_2;
        }
    }
    g_enqueues++;
    g_push_frame = g_ticks_3;

    if (g_push_logs < TNX_PUSH_LOGS || (g_push_logs % 64) == 0) {
        TNX_LOGX("queuePush tick=%llu type=%d x=%d y=%d msg=%p mgr=%p alloc=%s seqBefore=%d seqAfter=%d qBefore=%d qAfter=%d qLast=%p",
                 (unsigned long long)g_tick_2, TNX_TYPE_MOVE, x, y, msg, mgr, g_alloc_how,
                 g_seq_before, g_seq_after, g_q_before_2, g_q_after_2, g_q_last,
                 (unsigned long long)0x79de88ULL, (unsigned)TNX_MSG_SIZE,
                 (unsigned long long)TNX_MSGCTOR_RVA, (unsigned long long)TNX_TYPE_OFF,
                 TNX_TYPE_MOVE, (unsigned long long)TNX_X_OFF,
                 (unsigned long long)TNX_ADDINPUT_RVA, (unsigned long long)TNX_GETBATTLE_RVA,
                 (unsigned long long)TNX_MGR_OFF, g_alloc_how,
                 (unsigned long long)TNX_ALLOC_RVA, (unsigned long long)TNX_ALLOC_GOT_RVA,
                 (unsigned long long)TNX_MGR_SEQ_OFF);
    }

    g_push_logs++;

    return 1;
}

const char *tnx_state_x(int32_t v) {
    if (v == g_enq_x) return "MATCH";
    if (v == -1) return "RESET";
    if (v == 0) return "DEFAULT";

    return "other";
}

const char *tnx_state_y(int32_t v) {
    if (v == g_enq_y && g_enq_y != 0) return "MATCH";
    if (v == -1) return "RESET";
    if (v == 0) return (g_enq_y == 0) ? "MATCH=DEFAULT" : "DEFAULT";

    return "other";
}

uintptr_t g_wit_elem = 0;

int32_t g_wit_x0 = 0;

int32_t g_wit_y0 = 0;

int32_t g_wit_x1 = 0;

int32_t g_wit_y1 = 0;

int32_t g_own_held_x = 0;

int32_t g_own_held_y = 0;

int32_t g_own_flag = -1;

int g_have_wit = 0;

int g_active = 0;

int g_calls = 0;

int g_act_logs = 0;

int g_wit_logs = 0;

int g_own_logs_3 = 0;

int g_probe_done = 0;

int64_t g_moves = 0;

int64_t g_elem_moves = 0;

int tnx_resolve_own(const tnx_obj_t *objects, int usable, int *indexOut,
                                const char **fromOut) {
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t wantGid = -1;
    uintptr_t slotOwn = 0;
    int32_t slotGid = 0;
    int hasWit = 0;
    int best = -1;
    int64_t bestD = 0;
    int i;

    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    {
        uintptr_t minOwn = 0;
        int32_t minGid = 0;

        if (g_score_logs_2 < 8) {
            g_score_logs_2++;

            TNX_LOGX("score enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d",
                     (void *)g_tick_array, g_tick_count, (void *)g_players_array,
                     g_players_count, (void *)g_tick_array, g_tick_count);
        }

        if (tnx_own_by_min_gid(g_tick_array, g_tick_count, &minOwn, &minGid) &&
            minOwn) {
            for (i = 0; i < usable; i++) {
                if (objects[i].object != minOwn) continue;

                if (indexOut) *indexOut = i;
                if (fromOut) *fromOut = "v134-min";

                return 1;
            }
        }
    }

    if (tnx_own_from_slot(&slotOwn, &slotGid) && slotOwn) {
        for (i = 0; i < usable; i++) {
            if (objects[i].object != slotOwn) continue;
            if (objects[i].gid < TNX_GID_FLOOR || objects[i].gid >= TNX_GID_MAX) continue;

            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-slot";

            return 1;
        }
    }

    if (g_own_gid > 0) {
        wantGid = g_own_gid;
    } else if (slotGid > 0) {
        wantGid = slotGid;
    } else if (g_own_ptr_2) {
        wantGid = tnx_gid((uintptr_t)g_own_ptr_2, NULL);
    }

    for (i = 0; i < usable; i++) {
        if (objects[i].x <= -TNX_COORD_MAX || objects[i].x >= TNX_COORD_MAX) continue;
        if (objects[i].y <= -TNX_COORD_MAX || objects[i].y >= TNX_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        if (wantGid > 0 && objects[i].gid == wantGid) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-gid";

            TNX_LOGX("own-gid idx=%d gid=%d pos=(%d,%d) wantGid=%d slotIdx=%d",
                     i, objects[i].gid, objects[i].x, objects[i].y, wantGid, g_own_slot_idx);

            return 1;
        }
    }

    if (tnx_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    hasWit = tnx_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {
        TNX_LOGX("own-none usable=%d wantGid=%d slotOwn=%p slotIdx=%d interpUnusable=1",
                 usable, wantGid, (void *)slotOwn, g_own_slot_idx);

        return 0;
    }

    for (i = 0; i < usable; i++) {
        int64_t dx = 0;
        int64_t dy = 0;
        int64_t d = 0;

        if (objects[i].x <= -TNX_COORD_MAX || objects[i].x >= TNX_COORD_MAX) continue;
        if (objects[i].y <= -TNX_COORD_MAX || objects[i].y >= TNX_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        dx = (int64_t)objects[i].x - (int64_t)wx;
        dy = (int64_t)objects[i].y - (int64_t)wy;
        d = dx * dx + dy * dy;

        if (best < 0 || d < bestD) {
            best = i;
            bestD = d;
        }
    }

    if (best < 0) return 0;

    if (indexOut) *indexOut = best;
    if (fromOut) *fromOut = "v129-near";

    if (g_own_logs_3 < TNX_OWN_LOGS_2) {
        g_own_logs_3++;

        TNX_LOGX("own-near idx=%d gid=%d pos=(%d,%d) interp=(%d,%d) d2=%lld wantGid=%d",
                 best, objects[best].gid, objects[best].x, objects[best].y, wx, wy, (long long)bestD,
                 wantGid, (unsigned long long)TNX_CLIENT_POS_X_OFF,
                 (unsigned long long)TNX_CLIENT_POS_Y_OFF);
    }

    return 1;
}

int tnx_fields_pair(uintptr_t *srcOut, int32_t *xOut, int32_t *yOut) {
    uintptr_t own = tnx_own_obj();
    uintptr_t src = own ? own : (uintptr_t)g_scene_object;
    int32_t x = 0;
    int32_t y = 0;

    if (srcOut) *srcOut = 0;
    if (xOut) *xOut = 0;
    if (yOut) *yOut = 0;

    if (!src) return 0;
    if (!tnx_read_i32(src + TNX_INPUT_X_OFF, &x)) return 0;
    if (!tnx_read_i32(src + TNX_INPUT_Y_OFF, &y)) return 0;

    if (srcOut) *srcOut = src;
    if (xOut) *xOut = x;
    if (yOut) *yOut = y;

    return 1;
}

int tnx_fields(void) {
    uintptr_t src = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_fields_pair(&src, &x, &y)) return -1;

    return (x == g_enq_x && y == g_enq_y) ? 1 : 0;
}

float tnx_seg_dist(float ax, float ay, float bx, float by, float px, float py) {
    float vx = bx - ax;
    float vy = by - ay;
    float wx = px - ax;
    float wy = py - ay;
    float len2 = vx * vx + vy * vy;
    float t = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;

    if (len2 > 0.001f) t = (wx * vx + wy * vy) / len2;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;

    dx = px - (ax + t * vx);
    dy = py - (ay + t * vy);

    return sqrtf(dx * dx + dy * dy);
}

int tnx_proj_vel(const tnx_proj_t *p, float *vxOut, float *vyOut) {
    uint64_t dt = 0;

    if (!p->elem || !p->hasPrev) return 0;

    dt = p->qtick - p->ptick;
    if (dt == 0 || dt > TNX_DT_MAX) dt = 1;

    *vxOut = (float)(p->x - p->px) / (float)dt;
    *vyOut = (float)(p->y - p->py) / (float)dt;

    return 1;
}

uintptr_t tnx_input_mgr(void) {
    void *mgr = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr(g_scene_object + TNX_MODE_INPUTMGR_OFF, &mgr) || !mgr) return 0;
    if (!tnx_heap_contains((uintptr_t)mgr)) return 0;

    return (uintptr_t)mgr;
}

void tnx_input_release(void) {
    uintptr_t mgr = 0;
    int32_t held[3] = { 0, 0, 0 };
    int32_t zero[3] = { 0, 0, 0 };
    int engagedLast = g_engaged_frame;

    g_engaged_frame = 0;

    if (!TNX_INPUT_MGR) return;
    if (!g_wrote_input) return;
    if (engagedLast) return;

    mgr = tnx_input_mgr();

    if (!mgr) return;

    tnx_read_i32(mgr + 0x4, &held[0]);
    tnx_read_i32(mgr + 0x8, &held[1]);
    tnx_read_i32(mgr + 0xc, &held[2]);

    g_wrote_input = 0;

    if (held[0] == 0 && held[1] == 0 && held[2] == 0) return;

    tnx_write_bytes(mgr + 0x4, &zero[0], sizeof(zero[0]));
    tnx_write_bytes(mgr + 0x8, &zero[1], sizeof(zero[1]));
    tnx_write_bytes(mgr + 0xc, &zero[2], sizeof(zero[2]));

    if (g_neutral_logs < 4) {
        g_neutral_logs++;

        TNX_LOGX("input released: the record held (%d,%d,%d) and the previous frame was the last one this build wrote, so it is zeroed now", held[0], held[1], held[2]);
    }
}

uintptr_t g_joystick = 0;

uint64_t g_joystick_writes = 0;

uint64_t g_joystick_took = 0;

int32_t g_stick_x = 0;

int32_t g_stick_y = 0;

int g_stick_hold = 0;

uint64_t g_stick_tick = 0;

int g_engaged_ticks = 0;

long long g_sum_x = 0;

long long g_sum_y = 0;

int g_route_seeded = 0;

int32_t g_last_own_x = 0;

int32_t g_last_own_y = 0;

uint64_t g_drag_writes_2 = 0;

uint64_t g_back_ok = 0;

uint64_t g_back_bad = 0;

int g_precond = -1;

int g_gate = -1;

int g_accepted = 0;

int g_proofs = 0;

int g_drove = 0;

uint64_t g_drive_tick = 0;

float g_mark = 0.0f;

float g_dot = 0.0f;

float g_last_dx = 0.0f;

float g_last_dy = 0.0f;

int32_t g_raw_x = 0;

int32_t g_raw_y = 0;

int32_t g_app_x = 0;

int32_t g_app_y = 0;

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

            g_stick_hold = 1;
            g_stick_tick = g_ticks_3;
            g_engaged_ticks++;
            g_sum_x += wx;
            g_sum_y += wy;
        }
    }

    if (!want) {
        uintptr_t relCtrl = tnx_controller();
        int32_t relX = 0;
        int32_t relY = 0;

        if (!g_stick_hold) return;
        if (TNX_JS_STICK && g_ticks_3 < g_stick_tick + TNX_JS_HOLD) return;
        if (!TNX_RAGE && g_stick_tick + TNX_STICK_TTL > g_ticks_3) return;

        g_stick_hold = 0;

        if (relCtrl && tnx_read_i32(relCtrl + TNX_CTRL_RAW_X_OFF, &relX) &&
            tnx_read_i32(relCtrl + TNX_CTRL_RAW_Y_OFF, &relY)) {
            if (relX != g_stick_x || relY != g_stick_y) return;
        }
    }

    g_stick_x = wx;
    g_stick_y = wy;

    if (TNX_STICK_RAW_WRITE && !(TNX_RETIRE && g_accepted && !TNX_JS_STICK)) {
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
    int ours = g_engaged_ticks;
    long long sumX = 0;
    long long sumY = 0;
    float sLen = 0.0f;
    float mLen = 0.0f;
    float dot = 0.0f;
    const char *align = "no-move";

    if ((g_ticks_3 % 60) != 0) return;
    if (!tnx_own(&ownX, &ownY)) return;

    g_engaged_ticks = 0;

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &backX);
        tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &backY);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (g_route_seeded) {
        dx = (int)(ownX - g_last_own_x);
        dy = (int)(ownY - g_last_own_y);

        moved = (int)sqrtf((float)(dx * dx + dy * dy));
    }

    sumX = g_sum_x;
    sumY = g_sum_y;
    g_sum_x = 0;
    g_sum_y = 0;

    sLen = sqrtf((float)(sumX * sumX + sumY * sumY));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (sLen > 0.5f && mLen > 0.5f) {
        dot = ((float)sumX / sLen) * ((float)dx / mLen) + ((float)sumY / sLen) * ((float)dy / mLen);

        if (dot > 0.7f) align = "same";
        else if (dot < -0.7f) align = "opposite";
        else align = "unrelated";
    }

    g_route_seeded = 1;
    g_last_own_x = ownX;
    g_last_own_y = ownY;

    TNX_LOGX("route engaged=%d stick=(%d,%d) back=(%d,%d) applied=(%d,%d) own=(%d,%d) movedLastSecond=%d stickSum=(%lld,%lld) stickDir=(%.2f,%.2f) moveDir=(%.2f,%.2f) dot=%+.2f aligned=%s engagedTicks=%d queue=%d",
             engaged, g_stick_x, g_stick_y, backX, backY, appX, appY, ownX, ownY, moved,
             sumX, sumY,
             (double)(sLen > 0.5f ? (float)sumX / sLen : 0.0f),
             (double)(sLen > 0.5f ? (float)sumY / sLen : 0.0f),
             (double)(mLen > 0.5f ? (float)dx / mLen : 0.0f),
             (double)(mLen > 0.5f ? (float)dy / mLen : 0.0f),
             (double)dot, align, ours, tnx_queue_count(NULL));
}

void tnx_threats(void) {
    int k = 0;

    if ((g_ticks_3 % 60) != 0) return;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        const tnx_proj_t *p = &g_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        const char *verdict = "threat";

        if (!p->elem) continue;

        if (!tnx_proj_vel(p, &vx, &vy)) {
            verdict = p->hasPrev ? "vel-unreadable" : "one-sample";
        } else if (TNX_TEAM_FILTER && g_own_team_seen && p->team == g_own_team_3) {
            verdict = "own-team";
        } else if (sqrtf(vx * vx + vy * vy) < TNX_MIN_PROJ_SPEED) {
            verdict = "still";
        }

        TNX_LOGX("threat gid=%d elem=%p at=(%d,%d) prev=(%d,%d) dt=%llu vel=(%.1f,%.1f) team=%d verdict=%s ownTeam=%d armed=%d",
                 p->gid, (void *)p->elem, p->x, p->y, p->px, p->py,
                 (unsigned long long)(p->qtick - p->ptick), (double)vx, (double)vy, p->team, verdict,
                 g_own_team_3, g_own_team_seen);
    }
}

int tnx_body_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (g_pl_n <= 0) return 0;

    for (i = 0; i < g_pl_n; i++) {
        float px = 0.0f;
        float py = 0.0f;

        if (g_pl_mine[i]) continue;

        px = (float)g_pl_x[i];
        py = (float)g_pl_y[i];

        if (tnx_seg_dist(ownX, ownY, x, y, px, py) < TNX_BODY_CLEAR) {
            g_body_blocks++;

            if (g_pl_mine[i]) g_body_mine++;
            else g_body_enemy++;

            if (g_body_logs < TNX_BODY_LOGS) {
                g_body_logs++;

                TNX_LOGX("body in the way body=(%d,%d) mine=%d own=(%d,%d) candidate=(%d,%d) off=%d blocks=%d", (int)px, (int)py, g_pl_mine[i], (int)ownX,
                         (int)ownY, (int)x, (int)y,
                         (int)tnx_seg_dist(ownX, ownY, x, y, px, py), g_body_blocks);
            }

            return 1;
        }
    }

    return 0;
}
