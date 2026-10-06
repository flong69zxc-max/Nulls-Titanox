#include "titanox.h"

int t_pred_blocked = 0;

uint32_t t_token_2 = 0;

uint64_t t_diag_us = 0;

uint64_t t_diag_max_us = 0;

int t_dead_probe_done = 0;

int tnx_mode_2(void) {
    int mates = t_mate_n;
    int en = t_enemy_n;

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

uint64_t t_clamped = 0;

uint64_t t_ctrl_dead = 0;

uint64_t t_stuck_3 = 0;

uint64_t t_mask_before = 0;

int tnx_ctrl_ok(uintptr_t ctrl) {
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    void *vt = NULL;

    if (!ctrl) return 0;
    if (!tnx_writable(ctrl + TNX_FLAG_OFF_2, TNX_CTRL_APPLIED_Y_OFF -
                           TNX_FLAG_OFF_2 + sizeof(int32_t))) {
        t_ctrl_dead++;

        return 0;
    }
    if (!tnx_writable(ctrl + TNX_CUR_X_OFF, TNX_ORG_Y_OFF -
                           TNX_CUR_X_OFF + sizeof(float))) {
        t_ctrl_dead++;

        return 0;
    }
    if (TNX_STALE_SIGHT && tnx_read_ptr(ctrl, &vt) && vt) {
        if ((uintptr_t)vt < t_base || (uintptr_t)vt >= t_base + TNX_IMAGE_SPAN) t_stale++;
    }
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    if (rawX < -TNX_DEGEN || rawX > TNX_DEGEN) { t_ctrl_dead++; return 0; }
    if (rawY < -TNX_DEGEN || rawY > TNX_DEGEN) { t_ctrl_dead++; return 0; }
    if (appX < -TNX_DEGEN || appX > TNX_DEGEN) { t_ctrl_dead++; return 0; }
    if (appY < -TNX_DEGEN || appY > TNX_DEGEN) { t_ctrl_dead++; return 0; }

    return 1;
}

int t_body_blocks = 0;

int t_body_mine = 0;

int t_body_enemy = 0;

int t_body_logs = 0;

int t_input_skips = 0;

int t_wrote_input = 0;

int t_engaged_frame = 0;

int t_neutral_logs = 0;

uint64_t t_test_tick = 0;

int t_test_before_x = 0;

int t_test_before_y = 0;

int t_test_after_x_2 = 0;

int t_test_after_y_2 = 0;

int t_moved_2 = 0;

int t_moved2_2 = 0;

int t_kept_2 = 0;

uint64_t t_enqueues = 0;

int t_q_before = -1;

int t_q_after = -1;

int t_readback_tick = -1;

int t_hop2_logs = 0;

int t_hop2_filled = 0;

uintptr_t t_hop2 = 0;

int t_queue_logs = 0;

int t_window_logs = 0;

uint64_t t_push_frame = 0;

uint64_t t_test_tickbase = 0;

int t_enq_ok = 0;

const char *t_alloc_how = "none";

void *t_msg = NULL;

int t_seq_before = -1;

int t_seq_after = -1;

int t_q_before_2 = -1;

int t_q_after_2 = -1;

void *t_q_last = NULL;

int32_t t_scene_before_x = 0;

int32_t t_scene_before_y = 0;

uint64_t t_watch_from = 0;

int t_watch_logs = 0;

void *tnx_msg_alloc(void) {
    uintptr_t stub = tnx_entry_2(TNX_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub) {
        t_alloc_how = "stub";
        return ((void *(*)(size_t))stub)((size_t)TNX_MSG_SIZE);
    }

    if (t_base && tnx_read_ptr(t_base + TNX_ALLOC_GOT_RVA, (void **)&got) && got) {
        t_alloc_how = "got";
        return ((void *(*)(size_t))got)((size_t)TNX_MSG_SIZE);
    }

    t_alloc_how = "none";

    return NULL;
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
    if (!t_base || !rva) return 0;
    if (!tnx_callable(rva)) return 0;

    return t_base + rva;
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

uintptr_t t_pred_last = 0;

int t_predict_logs = 0;

int tnx_predict(int32_t x, int32_t y) {
    uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
    void *battle = NULL;

    if (!TNX_PREDICT) return 0;
    if (!t_addr_setprediction) return 0;
    if (!battleFn) return 0;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) {
        t_pred_fails++;

        return 0;
    }

    ((void (*)(void *, int, int, int))t_addr_setprediction)(battle, x, y, TNX_PREDICT_FLAG);

    {
        int32_t px = 0;
        int32_t py = 0;

        tnx_read_i32((uintptr_t)battle + TNX_MODE_PREDICTX_OFF, &px);
        tnx_read_i32((uintptr_t)battle + TNX_MODE_PREDICTY_OFF, &py);

        if (TNX_GATE_WRITE) {
            uint8_t one = 1;
            uint8_t back = 0;

            tnx_write_bytes((uintptr_t)battle + TNX_GATE_OFF, &one, sizeof(one));
            t_gate_writes_2++;

            if (tnx_read_bytes((uintptr_t)battle + TNX_GATE_OFF, &back, sizeof(back)) &&
                back == 1) {
                t_gate_held++;
            }
        }

        if (px == x && py == y) t_pred_took++;
        else t_pred_miss++;

        if (t_pred_logs < TNX_PRED_LOGS) {
            t_pred_logs++;

            TNX_LOGX("predict battle=%p sent=(%d,%d) read=(%d,%d) took=%llu miss=%llu", battle, x, y, px, py,
                     (unsigned long long)t_pred_took, (unsigned long long)t_pred_miss);
        }
    }

    t_pred_last = (uintptr_t)battle;
    t_pred_calls++;

    if (t_predict_logs < TNX_PREDICT_LOGS) {
        t_predict_logs++;

        TNX_LOGX("predict call=%llu battle=%p target=(%d,%d) fn=%p",
                 (unsigned long long)t_pred_calls, battle, x, y, (void *)t_addr_setprediction,
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

static int t_pred_ok = 0;

static int tnx_pred_ok(uintptr_t pred) {
    return tnx_pred_probe(pred, NULL, NULL, NULL, NULL);
}

int tnx_pred_set(int x, int y) {
    uintptr_t setFn = 0;
    uintptr_t pred = 0;

    if (!TNX_PRED_SET) return 0;

    if (!t_coord_ok) {
        if (t_pred_blocked < TNX_QGUARD_LOGS) {
            t_pred_blocked++;

            TNX_LOGX("predSkip x=%d y=%d coordOk=%d usable=%d tick=%llu - the prediction is only"
                     " written once the coordinates are calibrated, otherwise the first frames of a"
                     " battle command the character to the origin",
                     x, y, t_coord_ok, t_coord_usable, (unsigned long long)t_ticks_3);
        }

        return 0;
    }

    setFn = tnx_entry_2(TNX_SETINPUT_RVA);

    if (!setFn) return 0;

    pred = tnx_controller();

    if (!tnx_pred_ok(pred)) {
        if (t_pred_ok < 4) {
            TNX_LOGX("predMiss pred=%p - the receiver is the logic client itself, no hop, and a "
                     "receiver that fails here is one the write cannot land on, so nothing of the "
                     "local prediction follows the dodge on this frame", (void *)pred);
            t_pred_ok++;
        }

        return 0;
    }

    ((void (*)(uintptr_t, int, int, int))setFn)(pred, x, y, TNX_PRED_FLAG);

    if (t_pred_ok < 4) {
        TNX_LOGX("predSet pred=%p x=%d y=%d flag=%d", (void *)pred, x, y, (int)TNX_PRED_FLAG);
        t_pred_ok++;
    }

    return 1;
}

int t_qguard_probe = 0;
int t_qguard_skip = 0;

int t_enq_stop_1 = 0;

int t_enq_stop_2 = 0;

int t_enq_stop_3 = 0;

int t_enq_stop_4 = 0;

int t_enq_stop_5 = 0;

int tnx_enqueue_type_4(int x, int y, int type) {
    if (!t_coord_ok) {
        if (t_enq_stop_5 < 8) {
            t_enq_stop_5++;

            TNX_LOGX("enqueueStop coords gate ok=%d usable=%d x=%d y=%d tick=%llu - the push is "
                     "refused before anything is allocated or signed, and until now this return had "
                     "no counter and no line, so a run in which every push died here looked exactly "
                     "like a run in which the push succeeded and the engine ignored it",
                     t_coord_ok, t_coord_usable, x, y, (unsigned long long)t_ticks_3);
        }

        return 0;
    }


    uintptr_t ctorFn = tnx_entry_2(TNX_MSGCTOR_RVA);
    uintptr_t inputFn = tnx_entry_2(TNX_ADDINPUT_RVA);
    int32_t vx = x;
    int32_t vy = y;
    void *mgr = NULL;
    void *msg = NULL;

    t_enq_ok = 0;
    t_msg = NULL;
    t_q_last = NULL;
    t_seq_before = -1;
    t_seq_after = -1;
    t_q_before_2 = -1;
    t_q_after_2 = -1;

    if (!inputFn) {
        if (t_enq_stop_1 < 8) {
            t_enq_stop_1++;

            TNX_LOGX("enqueueStop addInput rva=%#llx base=%p callable=0",
                     (unsigned long long)TNX_ADDINPUT_RVA, (void *)t_base);
        }

        return 0;
    }

    msg = tnx_msg_alloc();

    if (!msg) {
        if (t_enq_stop_2 < 8) {
            t_enq_stop_2++;

            TNX_LOGX("enqueueStop alloc how=%s size=%#llx", t_alloc_how,
                     (unsigned long long)TNX_MSG_SIZE, (unsigned long long)TNX_MSG_SIZE);
        }

        return 0;
    }

    memset(msg, 0, (size_t)TNX_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, TNX_TYPE_MOVE);

    tnx_write_bytes((uintptr_t)msg + TNX_TYPE_OFF, &type, sizeof(type));
    tnx_write_bytes((uintptr_t)msg + TNX_X_OFF, &vx, sizeof(vx));
    tnx_write_bytes((uintptr_t)msg + TNX_Y_OFF, &vy, sizeof(vy));

    if (TNX_QUEUE_GUARD && t_qguard_probe < 1) {
        void *mvt = NULL;
        int32_t back = 0;

        t_qguard_probe++;

        tnx_read_ptr((uintptr_t)msg, &mvt);
        tnx_read_i32((uintptr_t)msg + TNX_TYPE_OFF, &back);

        TNX_LOGX("msgProbe msg=%p vtable=%p vtableRva=%#llx typeWritten=%d typeRead=%d shaped=%d "
                 "size=%#llx - vtableRva=0 and shaped=0 mean the constructor did not build the "
                 "object and the push is what kills the frame; vtableRva!=0 with shaped=1 means "
                 "the message is fine and the manager is the one to look at",
                 (void *)msg, mvt,
                 (unsigned long long)(t_base && (uintptr_t)mvt > t_base ? (uintptr_t)mvt - t_base : 0),
                 (int)type, (int)back, (int)tnx_instance_shaped((uintptr_t)msg),
                 (unsigned long long)TNX_MSG_SIZE);
    }

    {
        uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);

        t_token_2 = 0;
        t_raw_x = 0;
        t_raw_y = 0;

        if (battleFn) {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) t_token_2 = tnx_ci_sign(msg, battle);
        }
    }

    if (type == (int)TNX_TYPE_MOVE) (void)tnx_pred_set(x, y);

    mgr = tnx_manager();

    if (!mgr) {
        TNX_LOGX("queuePush aborted x=%d y=%d msg=%p alloc=%s",
                 x, y, msg, t_alloc_how, (unsigned long long)TNX_MGR_OFF);

        return 0;
    }

    tnx_read_i32((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &t_seq_before);

    t_q_before_2 = tnx_queue_count(NULL);

    if (tnx_pending(TNX_TYPE_MOVE, &t_mask_before)) {
        t_stuck_3++;
    }

    {
        void *mgrInner = NULL;

        if (!tnx_read_ptr((uintptr_t)mgr + TNX_CI_MGR_QUEUE_OFF, &mgrInner) || !mgrInner) {
            if (t_enq_stop_3 < 8) {
                t_enq_stop_3++;

                TNX_LOGX("enqueueStop queueSlot mgr=%p slot+%#llx=%p", (void *)mgr,
                         (unsigned long long)TNX_CI_MGR_QUEUE_OFF, (void *)mgrInner);
            }

            return 0;
        }
    }

    t_enq_stop_4++;

    if (TNX_QUEUE_GUARD || TNX_QUEUE_GUARD_MGR) {
        int msgOk = tnx_instance_shaped((uintptr_t)msg);
        int mgrOk = tnx_manager_shape((uintptr_t)mgr);

        if ((TNX_QUEUE_GUARD && !msgOk) || (TNX_QUEUE_GUARD_MGR && !mgrOk)) {
            if (t_qguard_skip < TNX_QGUARD_LOGS) {
                void *mvt = NULL;
                void *gvt = NULL;

                t_qguard_skip++;

                tnx_read_ptr((uintptr_t)msg, &mvt);
                tnx_read_ptr((uintptr_t)mgr, &gvt);

                TNX_LOGX("queueSkip msg=%p msgVt=%p msgShaped=%d mgr=%p mgrVt=%p mgrShaped=%d "
                         "tick=%llu - the object we are about to hand to the engine is not shaped "
                         "like the thing it must be, so the push is skipped; the page-writable "
                         "guard cannot see this, a readable freed block passes it",
                         (void *)msg, mvt, msgOk, (void *)mgr, gvt, mgrOk,
                         (unsigned long long)t_ticks_3);
            }

            return 0;
        }
    }

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    t_seq_after = -1;
    tnx_read_i32((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &t_seq_after);
    t_q_after_2 = tnx_queue_count(NULL);
    t_q_last = tnx_q_last();
    t_msg = msg;
    t_enq_ok = 1;

    if (TNX_QUEUE) {
        if (t_q_after_2 <= 0) t_drain++;
        if ((uint64_t)(t_q_after_2 > 0 ? t_q_after_2 : 0) > t_q_max) {
            t_q_max = (uint64_t)t_q_after_2;
        }
    }
    t_enqueues++;
    t_push_frame = t_ticks_3;

    if (t_push_logs < TNX_PUSH_LOGS || (t_push_logs % 64) == 0) {
        TNX_LOGX("queuePush tick=%llu type=%d x=%d y=%d msg=%p mgr=%p alloc=%s seqBefore=%d seqAfter=%d qBefore=%d qAfter=%d qLast=%p",
                 (unsigned long long)t_tick_2, TNX_TYPE_MOVE, x, y, msg, mgr, t_alloc_how,
                 t_seq_before, t_seq_after, t_q_before_2, t_q_after_2, t_q_last,
                 (unsigned long long)0x79de88ULL, (unsigned)TNX_MSG_SIZE,
                 (unsigned long long)TNX_MSGCTOR_RVA, (unsigned long long)TNX_TYPE_OFF,
                 TNX_TYPE_MOVE, (unsigned long long)TNX_X_OFF,
                 (unsigned long long)TNX_ADDINPUT_RVA, (unsigned long long)TNX_GETBATTLE_RVA,
                 (unsigned long long)TNX_MGR_OFF, t_alloc_how,
                 (unsigned long long)TNX_ALLOC_RVA, (unsigned long long)TNX_ALLOC_GOT_RVA,
                 (unsigned long long)TNX_MGR_SEQ_OFF);
    }

    t_push_logs++;

    return 1;
}

int tnx_enqueue(int x, int y) {
    return tnx_enqueue_type_4(x, y, (int)TNX_TYPE_MOVE);
}


int32_t t_own_held_x = 0;

int32_t t_own_held_y = 0;

int32_t t_own_flag = -1;

int t_have_wit = 0;

int t_calls = 0;

int t_act_logs = 0;

int t_wit_logs = 0;

int t_own_logs_3 = 0;

int t_probe_done = 0;

void tnx_actuate(void) {
    uintptr_t own = tnx_own_obj();
    uintptr_t ownVt = 0;
    uintptr_t ownCls = 0;
    uintptr_t ctrl = tnx_client();
    uintptr_t fn = tnx_entry_2(TNX_SETPRED4_RVA);
    int32_t raw_x = TNX_DX;
    int32_t raw_y = TNX_DY;
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t flagAfter = -1;
    int32_t modeBefore = -1;
    int32_t modeAfter = -1;
    int32_t raw_keep_x = 0;
    int32_t raw_keep_y = 0;
    int32_t pairBeforeX = 0;
    int32_t pairBeforeY = 0;
    int32_t pairBeforeK = 0;
    int32_t pairAfterX = 0;
    int32_t pairAfterY = 0;
    int32_t pairAfterK = 0;
    int32_t gateBefore = -1;
    int32_t gateAfter = -1;
    int setterRan = 0;
    int doWrite = (TNX_MODE == TNX_MODE_WRITE ||
                   TNX_MODE == TNX_MODE_BOTH) ? 1 : 0;
    int doSetter = (TNX_MODE == TNX_MODE_SETTER ||
                    TNX_MODE == TNX_MODE_BOTH) ? 1 : 0;

    if (!t_active) return;
    if (!doWrite && !doSetter) return;

    t_calls++;

    tnx_probe();

    if (!tnx_witness(&wx, &wy)) {
        wx = t_wit_x0;
        wy = t_wit_y0;
    } else {
        t_have_wit = 1;
    }

    if (doSetter && fn && own) {
        if (tnx_read_i32(own + TNX_INPUT_X_OFF, &pairBeforeX)) {
            tnx_read_i32(own + TNX_INPUT_Y_OFF, &pairBeforeY);
            tnx_read_i32(own + TNX_INPUT_K_OFF, &pairBeforeK);
            tnx_read_i32(own + TNX_GATE_FLAG_OFF, &gateBefore);
            tnx_read_i32(own + TNX_MODE_OFF, &modeBefore);
        }

        TNX_LOGX("setter-before x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d mode+%#llx=%d call=%d",
                 (void *)own, (unsigned long long)TNX_INPUT_X_OFF, pairBeforeX,
                 (unsigned long long)TNX_INPUT_Y_OFF, pairBeforeY,
                 (unsigned long long)TNX_INPUT_K_OFF, pairBeforeK,
                 (unsigned long long)TNX_GATE_FLAG_OFF, gateBefore,
                 (unsigned long long)TNX_MODE_OFF, modeBefore, t_calls,
                 (unsigned long long)TNX_SETPRED4_RVA, (unsigned long long)0x79de14ULL);

        ((void (*)(void *, int, int, int))fn)((void *)own, wx + TNX_DX, wy + TNX_DY,
                                              TNX_SETFLAG);

        setterRan = 1;

        tnx_read_i32(own + TNX_INPUT_X_OFF, &pairAfterX);
        tnx_read_i32(own + TNX_INPUT_Y_OFF, &pairAfterY);
        tnx_read_i32(own + TNX_INPUT_K_OFF, &pairAfterK);
        tnx_read_i32(own + TNX_GATE_FLAG_OFF, &gateAfter);
        tnx_read_i32(own + TNX_MODE_OFF, &modeAfter);

        TNX_LOGX("setter-after x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d mode=%d wrote=%d want=(%d,%d)",
                 (void *)own, (unsigned long long)TNX_INPUT_X_OFF, pairAfterX,
                 (unsigned long long)TNX_INPUT_Y_OFF, pairAfterY,
                 (unsigned long long)TNX_INPUT_K_OFF, pairAfterK,
                 (unsigned long long)TNX_GATE_FLAG_OFF, gateAfter, modeAfter, 1,
                 wx + TNX_DX, wy + TNX_DY, (unsigned long long)TNX_GATE_FLAG_OFF,
                 (unsigned long long)0xac3424ULL, wx + TNX_DX, wy + TNX_DY);

        t_own_held_x = pairAfterX;
        t_own_held_y = pairAfterY;
        t_own_flag = gateAfter;
    }

    (void)raw_keep_x;
    (void)raw_keep_y;

    if (own && !doSetter) {
        tnx_read_i32(own + TNX_GATE_FLAG_OFF, &flagAfter);

        if (!tnx_read_i32(own + TNX_GATE_X_OFF, &t_own_held_x)) t_own_held_x = 0;
        if (!tnx_read_i32(own + TNX_GATE_Y_OFF, &t_own_held_y)) t_own_held_y = 0;

        t_own_flag = flagAfter;
    }

    if (t_act_logs < TNX_ACT_LOGS) {
        t_act_logs++;

        tnx_vt_ok(own, &ownVt);

        if (ownVt >= t_base) ownCls = ownVt - t_base;

        if (t_actuate_logs < 8) {
            t_actuate_logs++;

            TNX_LOGX("actuate own=%p ownFrom=%s ownClassRva=%#llx valid=%d",
                     (void *)own, t_own_from_3, (unsigned long long)ownCls, own ? 1 : 0);
        }

        TNX_LOGX("actuate mode=%d call=%d doWrite=%d doSetter=%d own=%p ownFrom=%s ownClassRva=%#llx scene=%p wrote raw+%#llx (%d,%d) over (%d,%d) on the scene, setterRan=%d, wouldCall %#llx(own,%d,%d,%d) from the witness (%d,%d)",
                 TNX_MODE, t_calls, doWrite, doSetter, (void *)own, t_own_from_3,
                 (unsigned long long)ownCls, (void *)ctrl,
                 (unsigned long long)TNX_CTRL_RAW_X_OFF, raw_x, raw_y, raw_keep_x, raw_keep_y,
                 setterRan, (unsigned long long)TNX_SETPRED4_RVA, wx + TNX_DX,
                 wy + TNX_DY,
                 TNX_SETFLAG, wx, wy, TNX_MODE_CHAIN, TNX_MODE_WRITE,
                 TNX_MODE_SETTER, TNX_MODE_BOTH, TNX_DX, TNX_DY,
                 TNX_RAW_X, TNX_RAW_Y);
    }
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

    if (!t_scene_object) return 0;
    if (!tnx_read_ptr(t_scene_object + TNX_MODE_INPUTMGR_OFF, &mgr) || !mgr) return 0;
    if (!tnx_heap_contains((uintptr_t)mgr)) return 0;

    return (uintptr_t)mgr;
}

void tnx_input_release(void) {
    uintptr_t mgr = 0;
    int32_t held[3] = { 0, 0, 0 };
    int32_t zero[3] = { 0, 0, 0 };
    int engagedLast = t_engaged_frame;

    t_engaged_frame = 0;

    if (!TNX_INPUT_MGR) return;
    if (!t_wrote_input) return;
    if (engagedLast) return;

    mgr = tnx_input_mgr();

    if (!mgr) return;

    tnx_read_i32(mgr + 0x4, &held[0]);
    tnx_read_i32(mgr + 0x8, &held[1]);
    tnx_read_i32(mgr + 0xc, &held[2]);

    t_wrote_input = 0;

    if (held[0] == 0 && held[1] == 0 && held[2] == 0) return;

    tnx_write_bytes(mgr + 0x4, &zero[0], sizeof(zero[0]));
    tnx_write_bytes(mgr + 0x8, &zero[1], sizeof(zero[1]));
    tnx_write_bytes(mgr + 0xc, &zero[2], sizeof(zero[2]));

    if (t_neutral_logs < 4) {
        t_neutral_logs++;

        TNX_LOGX("input released: the record held (%d,%d,%d) and the previous frame was the last one this build wrote, so it is zeroed now", held[0], held[1], held[2]);
    }
}

uintptr_t t_joystick = 0;

uint64_t t_joystick_writes = 0;

uint64_t t_joystick_took = 0;

int t_stick_hold = 0;

uint64_t t_stick_tick = 0;

int t_route_seeded = 0;

int32_t t_last_own_x = 0;

int32_t t_last_own_y = 0;

int t_precond = -1;

int t_gate = -1;

int t_accepted = 0;

int t_proofs = 0;

int t_drove = 0;

uint64_t t_drive_tick = 0;

float t_mark = 0.0f;

float t_dot = 0.0f;

float t_last_dx = 0.0f;

float t_last_dy = 0.0f;

int32_t t_raw_x = 0;

int32_t t_raw_y = 0;

int32_t t_app_x = 0;

int32_t t_app_y = 0;
