#include "titanox.h"

#ifndef TNX_JS_STICK
#define TNX_JS_STICK 1
#endif

#ifndef TNX_JS_HOLD
#define TNX_JS_HOLD 2
#endif

#ifndef TNX_STICK_RAW_WRITE
#define TNX_STICK_RAW_WRITE 0
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

            TNX_LOGX("predict battle=%p sent=(%d,%d) read=(%d,%d) took=%llu miss=%llu - the pair "
                     "the call writes is read straight back, so a call landing on the wrong object "
                     "cannot look like a working prediction", battle, x, y, px, py,
                     (unsigned long long)g_pred_took, (unsigned long long)g_pred_miss);
        }
    }

    g_pred_last = (uintptr_t)battle;
    g_pred_calls++;

    if (g_predict_logs < TNX_PREDICT_LOGS) {
        g_predict_logs++;

        TNX_LOGX("predict call=%llu battle=%p target=(%d,%d) fn=%p - the same object whose "
                 "+%#llx holds the input manager, so this is the battle client the manager belongs "
                 "to and the prediction is stored on it; the reference script calls exactly this "
                 "with its new position on every frame it moves, which is the step that makes the "
                 "game walk the character instead of carrying it",
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

    if (!inputFn) return 0;

    msg = tnx_msg_alloc();

    if (!msg) return 0;

    memset(msg, 0, (size_t)TNX_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, TNX_TYPE_MOVE);

    tnx_write_bytes((uintptr_t)msg + TNX_TYPE_OFF, &type, sizeof(type));
    tnx_write_bytes((uintptr_t)msg + TNX_X_OFF, &vx, sizeof(vx));
    tnx_write_bytes((uintptr_t)msg + TNX_Y_OFF, &vy, sizeof(vy));

    {
        uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
        uintptr_t ctrl = tnx_controller();
        int32_t ownX = 0;
        int32_t ownY = 0;

        g_token_2 = 0;
        g_raw_x = 0;
        g_raw_y = 0;

        if (ctrl && tnx_own(&ownX, &ownY)) {
            int32_t rawX = vx - ownX;
            int32_t rawY = vy - ownY;

            if (tnx_write_bytes(ctrl + TNX_CTRL_RAW_X_OFF, &rawX, sizeof(rawX))) {
                tnx_write_bytes(ctrl + TNX_CTRL_RAW_Y_OFF, &rawY, sizeof(rawY));
            }

            g_raw_x = rawX;
            g_raw_y = rawY;
        }

        if (battleFn) {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) g_token_2 = tnx_ci_sign(msg, battle);
        }
    }

    mgr = tnx_manager();

    if (!mgr) {
        TNX_LOGX("queuePush aborted x=%d y=%d msg=%p alloc=%s - battle+%#llx is null, so the "
                 "message was built but not pushed and is left allocated on purpose rather than freed "
                 "through a pointer the queue never saw",
                 x, y, msg, g_alloc_how, (unsigned long long)TNX_MGR_OFF);

        return 0;
    }

    tnx_read_i32((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &g_seq_before);

    g_q_before_2 = tnx_queue_count(NULL);

    if (tnx_pending(TNX_TYPE_MOVE, &g_mask_before)) {
        g_stuck_3++;
    }

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    {
        uintptr_t ctrl = tnx_controller();
        uint8_t latch = TNX_CTRL_LATCH_VAL;
        int32_t dirty = TNX_CTRL_DIRTY_VAL;

        if (ctrl) {
            tnx_write_bytes(ctrl + TNX_CTRL_APPLIED_X_OFF, &vx, sizeof(vx));
            tnx_write_bytes(ctrl + TNX_CTRL_APPLIED_Y_OFF, &vy, sizeof(vy));
            tnx_write_bytes(ctrl + TNX_CTRL_LATCH_OFF, &latch, sizeof(latch));
            tnx_write_bytes(ctrl + TNX_CTRL_DIRTY_OFF, &dirty, sizeof(dirty));

            g_app_x = vx;
            g_app_y = vy;
            g_applied_writes++;
        }
    }

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
        TNX_LOGX("queuePush tick=%llu type=%d x=%d y=%d msg=%p mgr=%p alloc=%s seqBefore=%d "
                 "seqAfter=%d qBefore=%d qAfter=%d qLast=%p - the movement message of this build is the one "
                 "the battle update builds at %#llx: size %#x, the ctor %#llx stores the type at +%#llx with "
                 "w1 loaded with %d and not 2, the clamped pair goes to +%#llx as two int32, and the push is "
                 "addInput %#llx with the manager read as %#llx+%#llx; the allocator used here is %s because "
                 "the stub %#llx opens with adrp and the callable gate refuses it, so the GOT slot %#llx is "
                 "read and malloc is the last resort, and manager+%#llx is the sequence counter addInput "
                 "increments, so seqAfter above seqBefore is proof the call ran at all",
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

int tnx_witness(int32_t *x, int32_t *y) {
    int32_t wx = 0;
    int32_t wy = 0;

    if (x) *x = 0;
    if (y) *y = 0;

    if (!tnx_interp(&wx, &wy)) return 0;

    if (x) *x = wx;
    if (y) *y = wy;

    return 1;
}

void tnx_probe(void) {
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    uintptr_t own = tnx_own_obj();
    void *container = NULL;
    void *hop = NULL;
    int32_t raw_x = 0;
    int32_t raw_y = 0;
    int32_t dirty = 0;
    int32_t alive = 0;
    int32_t id = 0;
    int32_t gate = 0;
    int32_t app_x = 0;
    int32_t app_y = 0;
    int32_t own_flag = -1;
    int32_t own_mode = -1;

    if (g_probe_done) return;
    if (!ctrl) return;

    g_probe_done = 1;

    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_DIRTY_OFF, &dirty)) dirty = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_ALIVE_OFF, &alive)) alive = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_ID_OFF, &id)) id = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_GATE_OFF, &gate)) gate = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &app_x)) app_x = 0;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &app_y)) app_y = 0;

    if (own) {
        if (!tnx_read_i32(own + TNX_GATE_FLAG_OFF, &own_flag)) own_flag = -1;
        if (!tnx_read_i32(own + TNX_MODE_OFF, &own_mode)) own_mode = -1;
    }

    if (tnx_read_ptr(ctrl + TNX_CLIENT_OFF, &container) && container) {
        tnx_read_ptr((uintptr_t)container + TNX_CLIENT_OFF, &hop);
    }

    TNX_LOGX("probe scene=%p own=%p hop0=%p hop1=%p raw+%#llx=(%d,%d) dirty+%#llx=%d "
             "alive+%#llx=%d id+%#llx=%d gate+%#llx=%d applied+%#llx=(%d,%d) ownFlag+%#llx=%d "
             "ownMode+%#llx=%d - %#llx reads the pair it clamps out of the object it is handed in x0 "
             "as 'ldr w0,[x19,+%#llx]; ldr w1,[x19,+%#llx]' and the same object answers %#llx, so this "
             "line says whether the scene the walk already holds is that object: with a non-zero pair "
             "here and applied+%#llx moving while the raw pair is held, the input of this battle is a "
             "pair on the scene and not a message",
             (void *)ctrl, (void *)own, container, hop, (unsigned long long)TNX_CTRL_RAW_X_OFF,
             raw_x, raw_y, (unsigned long long)TNX_CTRL_DIRTY_OFF, dirty,
             (unsigned long long)TNX_CTRL_ALIVE_OFF, alive,
             (unsigned long long)TNX_CTRL_ID_OFF, id,
             (unsigned long long)TNX_CTRL_GATE_OFF, gate,
             (unsigned long long)TNX_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_GATE_FLAG_OFF, own_flag,
             (unsigned long long)TNX_MODE_OFF, own_mode, (unsigned long long)0x79d594ULL,
             (unsigned long long)TNX_CTRL_RAW_X_OFF,
             (unsigned long long)TNX_CTRL_RAW_Y_OFF, (unsigned long long)0x7b9050ULL,
             (unsigned long long)TNX_CTRL_APPLIED_X_OFF);
}

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

            TNX_LOGX("score enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d - own is "
                     "looked for on the tick snapshot and never on the live globals, so this line "
                     "and the walk line must print the same arr and n in the same tick",
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

            TNX_LOGX("own-gid idx=%d gid=%d pos=(%d,%d) wantGid=%d slotIdx=%d - own is named by the "
                     "id the slot element of hop0 carries, which is the engine's own index and not a "
                     "distance, because the interpolated pair is not a position when the mode never "
                     "reaches the lerp branch",
                     i, objects[i].gid, objects[i].x, objects[i].y, wantGid, g_own_slot_idx);

            return 1;
        }
    }

    if (tnx_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    hasWit = tnx_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {
        TNX_LOGX("own-none usable=%d wantGid=%d slotOwn=%p slotIdx=%d interpUnusable=1 - neither "
                 "the slot element nor an element with the slot id is in the collected list and the "
                 "interpolated pair is (0,0), so own is left unresolved instead of being taken from a "
                 "witness that this mode never updates",
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

        TNX_LOGX("own-near idx=%d gid=%d pos=(%d,%d) interp=(%d,%d) d2=%lld wantGid=%d - own is "
                 "the list element closest to the pair read from client+%#llx/+%#llx only after the "
                 "slot element and the slot id both missed, and this line is the one that has to be "
                 "watched for a wrong gid being chosen",
                 best, objects[best].gid, objects[best].x, objects[best].y, wx, wy, (long long)bestD,
                 wantGid, (unsigned long long)TNX_CLIENT_POS_X_OFF,
                 (unsigned long long)TNX_CLIENT_POS_Y_OFF);
    }

    return 1;
}

void tnx_actuate(void) {
    uintptr_t own = tnx_own_obj();
    uintptr_t ownVt = 0;
    uintptr_t ownCls = 0;
    uintptr_t ctrl = (uintptr_t)g_scene_object;
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

    if (!g_active) return;
    if (!doWrite && !doSetter) return;

    g_calls++;

    tnx_probe();

    if (!tnx_witness(&wx, &wy)) {
        wx = g_wit_x0;
        wy = g_wit_y0;
    } else {
        g_have_wit = 1;
    }

    if (doSetter && fn && own) {
        if (tnx_read_i32(own + TNX_INPUT_X_OFF, &pairBeforeX)) {
            tnx_read_i32(own + TNX_INPUT_Y_OFF, &pairBeforeY);
            tnx_read_i32(own + TNX_INPUT_K_OFF, &pairBeforeK);
            tnx_read_i32(own + TNX_GATE_FLAG_OFF, &gateBefore);
            tnx_read_i32(own + TNX_MODE_OFF, &modeBefore);
        }

        TNX_LOGX("setter-before x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d "
                 "mode+%#llx=%d call=%d - the receiver of %#llx is the own object and never the scene, "
                 "because %#llx stores on the getOwnCharacter result and the reader reads the same "
                 "object, so a call with the scene as x0 would store where nothing reads",
                 (void *)own, (unsigned long long)TNX_INPUT_X_OFF, pairBeforeX,
                 (unsigned long long)TNX_INPUT_Y_OFF, pairBeforeY,
                 (unsigned long long)TNX_INPUT_K_OFF, pairBeforeK,
                 (unsigned long long)TNX_GATE_FLAG_OFF, gateBefore,
                 (unsigned long long)TNX_MODE_OFF, modeBefore, g_calls,
                 (unsigned long long)TNX_SETPRED4_RVA, (unsigned long long)0x79de14ULL);

        ((void (*)(void *, int, int, int))fn)((void *)own, wx + TNX_DX, wy + TNX_DY,
                                              TNX_SETFLAG);

        setterRan = 1;

        tnx_read_i32(own + TNX_INPUT_X_OFF, &pairAfterX);
        tnx_read_i32(own + TNX_INPUT_Y_OFF, &pairAfterY);
        tnx_read_i32(own + TNX_INPUT_K_OFF, &pairAfterK);
        tnx_read_i32(own + TNX_GATE_FLAG_OFF, &gateAfter);
        tnx_read_i32(own + TNX_MODE_OFF, &modeAfter);

        TNX_LOGX("setter-after x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d "
                 "mode=%d wrote=%d want=(%d,%d) - the four words are read on the very receiver the call "
                 "was made on, so this line names where the store landed; +%#llx=1 means the producer "
                 "half of the pair %#llx consumes is in place, and a word that reads back as want=(%d,%d) "
                 "is the only proof the call ran at all",
                 (void *)own, (unsigned long long)TNX_INPUT_X_OFF, pairAfterX,
                 (unsigned long long)TNX_INPUT_Y_OFF, pairAfterY,
                 (unsigned long long)TNX_INPUT_K_OFF, pairAfterK,
                 (unsigned long long)TNX_GATE_FLAG_OFF, gateAfter, modeAfter, 1,
                 wx + TNX_DX, wy + TNX_DY, (unsigned long long)TNX_GATE_FLAG_OFF,
                 (unsigned long long)0xac3424ULL, wx + TNX_DX, wy + TNX_DY);

        g_own_held_x = pairAfterX;
        g_own_held_y = pairAfterY;
        g_own_flag = gateAfter;
    }

    (void)raw_keep_x;
    (void)raw_keep_y;

    if (own && !doSetter) {
        tnx_read_i32(own + TNX_GATE_FLAG_OFF, &flagAfter);

        if (!tnx_read_i32(own + TNX_GATE_X_OFF, &g_own_held_x)) g_own_held_x = 0;
        if (!tnx_read_i32(own + TNX_GATE_Y_OFF, &g_own_held_y)) g_own_held_y = 0;

        g_own_flag = flagAfter;
    }

    if (g_act_logs < TNX_ACT_LOGS) {
        g_act_logs++;

        tnx_vt_ok(own, &ownVt);

        if (ownVt >= g_base) ownCls = ownVt - g_base;

        if (g_actuate_logs < 8) {
            g_actuate_logs++;

            TNX_LOGX("actuate own=%p ownFrom=%s ownClassRva=%#llx valid=%d - this is the same "
                     "value the gate line and the dodge block read, so own here and ownFound there "
                     "have to point at one element in one tick or the split is still open",
                     (void *)own, g_own_from_3, (unsigned long long)ownCls, own ? 1 : 0);
        }

        TNX_LOGX("actuate mode=%d call=%d doWrite=%d doSetter=%d own=%p ownFrom=%s "
                 "ownClassRva=%#llx scene=%p wrote raw+%#llx "
                 "(%d,%d) over (%d,%d) on the scene, setterRan=%d, wouldCall %#llx(own,%d,%d,%d) from "
                 "the witness "
                 "(%d,%d) - mode %d is chain-only and never reaches this line, %d writes only the raw "
                 "pair the battle update clamps for itself, %d calls only the setter and %d does both; "
                 "the pair is %d,%d and not the old %d,%d, because the message carries clamp(position + "
                 "step) and a step of hundreds is a teleport the server has no reason to accept",
                 TNX_MODE, g_calls, doWrite, doSetter, (void *)own, g_own_from_3,
                 (unsigned long long)ownCls, (void *)ctrl,
                 (unsigned long long)TNX_CTRL_RAW_X_OFF, raw_x, raw_y, raw_keep_x, raw_keep_y,
                 setterRan, (unsigned long long)TNX_SETPRED4_RVA, wx + TNX_DX,
                 wy + TNX_DY,
                 TNX_SETFLAG, wx, wy, TNX_MODE_CHAIN, TNX_MODE_WRITE,
                 TNX_MODE_SETTER, TNX_MODE_BOTH, TNX_DX, TNX_DY,
                 TNX_RAW_X, TNX_RAW_Y);
    }
}

void tnx_witness_line(int plus) {
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t ex = -1;
    int32_t ey = -1;
    int32_t app_x = -1;
    int32_t app_y = -1;
    int32_t raw_x = 0;
    int32_t raw_y = 0;
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    int moved = 0;
    int elemMoved = 0;

    if (!g_active) return;
    if (g_wit_logs >= TNX_WIT_LOGS) return;

    g_wit_logs++;

    tnx_witness(&wx, &wy);

    if (g_wit_elem) {
        if (!tnx_read_i32(g_wit_elem + TNX_OBJ_X_OFF, &ex)) ex = -1;
        if (!tnx_read_i32(g_wit_elem + TNX_OBJ_Y_OFF, &ey)) ey = -1;
    }

    if (ctrl) {
        if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
        if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
        if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &app_x)) app_x = -1;
        if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &app_y)) app_y = -1;
    }

    moved = (wx != g_wit_x0 || wy != g_wit_y0) ? 1 : 0;
    elemMoved = (ex != g_wit_x1 || ey != g_wit_y1) ? 1 : 0;

    if (moved) g_moves++;
    if (elemMoved) g_elem_moves++;

    TNX_LOGX("witness +%d interp=(%d,%d) was=(%d,%d) moved=%d moves=%lld | elem=%p pos=(%d,%d) "
             "was=(%d,%d) elemMoved=%d elemMoves=%lld | scene raw+%#llx=(%d,%d) applied+%#llx=(%d,%d) "
             "- neither the interp pair at client+%#llx/+%#llx nor the walked element pair is written "
             "by this build any more, so a moved=1 here is the engine moving own after the injected "
             "pair and not a read back of our own store, which is the mistake the v127 direct element "
             "write made when it scored moved=1 on the very pair it had just written",
             plus, wx, wy, g_wit_x0, g_wit_y0, moved, (long long)g_moves,
             (void *)g_wit_elem, ex, ey, g_wit_x1, g_wit_y1, elemMoved,
             (long long)g_elem_moves, (unsigned long long)TNX_CTRL_RAW_X_OFF, raw_x, raw_y,
             (unsigned long long)TNX_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_CLIENT_POS_Y_OFF);

    g_wit_x0 = wx;
    g_wit_y0 = wy;
    g_wit_x1 = ex;
    g_wit_y1 = ey;
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

void tnx_frame_window(void) {
    uint64_t d = 0;
    int32_t inX = 0;
    int32_t inY = 0;

    if (!g_push_frame) return;

    d = g_ticks_3 - g_push_frame;

    if (d > TNX_FRAME_WINDOW) return;
    if (g_frame_logs >= 40) return;

    g_frame_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_Y_OFF, &inY);
    }

    {
        uintptr_t client = tnx_client();
        int32_t cx = 0;
        int32_t cy = 0;
        int32_t ck = 0;

        if (client) {
            tnx_read_i32(client + TNX_CLIENT_POS_X_OFF, &cx);
            tnx_read_i32(client + TNX_CLIENT_POS_Y_OFF, &cy);
        }

        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_K_OFF, &ck);

        TNX_LOGX("frame tick=%llu frame=+%llu qcount=%d mode=%d gate=%d inner=%d in10c=%d(%s) "
                 "in110=%d(%s) in114=%d client80=%d client84=%d - the window carries the mode id because "
                 "three different causes leave the same empty readback: the queue not being consumed, "
                 "the queue consumed while the +%#llx branch is gated because mode != %d, and the branch "
                 "running while the apply path never touches +%#llx; gate=1 means mode == %d and "
                 "(*[mode+%#llx])+%#x == 1; client80/client84 is the pair %#llx writes on the client at "
                 "client+%#llx, which is the interpolation output and the sharpest position signal here",
                 (unsigned long long)g_tick_2, (unsigned long long)d, tnx_queue_count(NULL),
                 tnx_mode(), tnx_gate(), tnx_inner(), inX, tnx_state_x(inX),
                 inY, tnx_state_y(inY), ck, cx, cy, (unsigned long long)TNX_READER_RVA,
                 TNX_MODE_TARGET, (unsigned long long)TNX_INPUT_X_OFF, TNX_MODE_TARGET,
                 (unsigned long long)TNX_GATE_PTR_OFF, (unsigned)TNX_GATE_BYTE_OFF,
                 (unsigned long long)0xa26890ULL, (unsigned long long)TNX_CLIENT_POS_X_OFF);
    }
}

void tnx_window(int plus) {
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (plus % TNX_FRAME_EVERY) return;
    if (g_window_logs >= 12) return;

    g_window_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_K_OFF, &inK);
    }

    TNX_LOGX("window tick=+%d qcount=%d in10c=%d in110=%d in114=%d want=(%d,%d) match=%d - the "
             "window is one line every %d ticks instead of one per tick, because the queue drain was "
             "already shown to be steady and the per tick line only spent the log budget",
             plus, tnx_queue_count(NULL), inX, inY, inK, g_enq_x, g_enq_y,
             tnx_fields(), TNX_FRAME_EVERY);
}

void tnx_test(const tnx_obj_t *objects, int usable, int ownIndex) {
    int32_t x = 0;
    int32_t y = 0;
    int qnow = -1;
    const char *verdict = "readback-unreadable";

    if (!objects || usable <= 0) return;
    if (g_test_state_2 >= 4) return;
    if (!g_scene_object) return;

    if (ownIndex < 0 || ownIndex >= usable) ownIndex = 0;

    if (!g_test_tickbase) g_test_tickbase = g_tick_2;

    {
        int mode = tnx_mode();

        if (mode > g_mode_max) g_mode_max = mode;
        if (mode == TNX_MODE_TARGET) g_mode_seen7 = 1;
        if (tnx_gate() == 1) g_gate_seen = 1;
    }

    if (!TNX_TEST_ENABLE) {
        if (g_test_state_2 == 0 && (g_tick_2 - g_test_tickbase) >= TNX_MODE_WAIT) {
            g_test_state_2 = 4;
            g_tested_2 = 1;

            TNX_LOGX("notest mode_max=%d saw7=%d gateSeen=%d gate=%d - the build ran without the "
                     "enqueue test and this line is the mode census: with saw7=0 the +%#llx branch is "
                     "unreachable in this battle because the mode id never reaches %d, so the whole "
                     "+0xac pipeline, %#llx and the client pair write belong to that mode alone",
                     g_mode_max, g_mode_seen7, g_gate_seen, tnx_gate(),
                     (unsigned long long)TNX_READER_RVA, TNX_MODE_TARGET,
                     (unsigned long long)0xa26890ULL);
        }

        return;
    }

    if (g_test_state_2 == 0) {

        g_test_state_2 = 1;
        g_test_tick = g_tick_2;
        g_test_before_x = objects[ownIndex].x;
        g_test_before_y = objects[ownIndex].y;

        tnx_chain();

        if (!tnx_witness(&g_wit_x0, &g_wit_y0)) {
            g_wit_x0 = objects[ownIndex].x;
            g_wit_y0 = objects[ownIndex].y;
        } else {
            g_have_wit = 1;
        }

        g_wit_elem = objects[ownIndex].object;
        g_wit_x1 = objects[ownIndex].x;
        g_wit_y1 = objects[ownIndex].y;
        g_calls = 0;
        g_moves = 0;
        g_elem_moves = 0;

        g_enq_x = g_wit_x0 + TNX_DX;
        g_enq_y = g_wit_y0 + TNX_DY;

        if (TNX_MODE == TNX_MODE_CHAIN) {
            g_test_state_2 = 4;
            g_tested_2 = 1;

            TNX_LOGX("chain-only mode=%d own=%p ownFromWitness=(%d,%d) elem=%p elemPos=(%d,%d) "
                     "slotOwn=%p slotIdx=%d slotGid=%d expect=%d queue=%d - nothing is written in this "
                     "mode on purpose: the chain check has to answer whether the scene the walk holds "
                     "is the object whose +%#llx the battle update clamps, and whether own is an "
                     "element of hop0, before any write is allowed to look like a result",
                     TNX_MODE, (void *)tnx_own_obj(), g_wit_x0, g_wit_y0,
                     (void *)g_wit_elem, g_wit_x1, g_wit_y1, (void *)g_own_slot,
                     g_own_slot_idx, g_own_slot_gid, TNX_OWN_EXPECT_GID,
                     tnx_queue_count(NULL), (unsigned long long)TNX_CTRL_RAW_X_OFF);

            return;
        }

        g_active = 1;

        g_scene_before_x = 0;
        g_scene_before_y = 0;

        if (g_scene_object) {
            tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_X_OFF, &g_scene_before_x);
            tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_Y_OFF, &g_scene_before_y);
        }

        g_watch_from = 0;
        g_watch_logs = 0;

        g_pre_reloads = g_reloads;
        g_pre_frames = g_ticks_3;

        g_push_frame_2 = g_ticks_3;
        g_win_stage = 0;
        g_win_reloads = g_reloads;

        if (TNX_MODE == TNX_MODE_BOTH) {
            tnx_enqueue(g_enq_x, g_enq_y);

            g_q_before = g_q_before_2;
            g_q_after = g_q_after_2;
        }

        tnx_setter(g_enq_x + TNX_DX_SETTER, g_enq_y + TNX_DY_SETTER);
        tnx_elem_write(objects[ownIndex].object,
                            g_enq_x + TNX_DX_ELEM, g_enq_y + TNX_DY_ELEM);

        tnx_probe();
        tnx_actuate();

        TNX_LOGX("test mode=%d pair=(%d,%d) enum dest=(%d,%d) enq=%d seq %d->%d q %d->%d qLast=%p "
                 "| write=%d setter=%d scene=%p rawOff=%#llx setterFn=%#llx own=%p | witnesses elem=%p "
                 "(%d,%d) interp=(%d,%d) - the three channels are no longer fired together: %d only "
                 "writes the raw pair on the scene, %d only calls the setter on own, %d does both and "
                 "also pushes the nearby destination so the queue is measured apart from the two local "
                 "channels, and the walked element is written by none of them",
                 TNX_MODE, g_enq_x, g_enq_y, g_wit_x0, g_wit_y0,
                 g_wit_x0 + TNX_DX, g_wit_y0 + TNX_DY,
                 g_enq_ok, g_seq_before, g_seq_after, g_q_before_2, g_q_after_2,
                 g_q_last, (void *)g_scene_object,
                 (unsigned long long)TNX_CTRL_RAW_X_OFF,
                 (unsigned long long)TNX_SETPRED4_RVA, (void *)tnx_own_obj(),
                 (void *)g_wit_elem, g_wit_x1, g_wit_y1, g_wit_x0, g_wit_y0,
                 TNX_MODE_WRITE, TNX_MODE_SETTER, TNX_MODE_BOTH);

        tnx_window(0);

        return;
    }

    if (g_test_state_2 == 1) {
        int plus = (int)(g_tick_2 - g_test_tick);

        tnx_actuate();
        tnx_witness_line(plus);

        if (g_readback < 0 && tnx_fields() == 1) {
            g_readback = 1;
            g_readback_tick = plus;
        }

        if (plus < TNX_READBACK_TICKS) {
            tnx_window(plus);

            return;
        }

        tnx_readback(plus);

        g_test_state_2 = 2;

        if (g_readback < 0) g_readback = 0;

        qnow = tnx_queue_count(NULL);

        TNX_LOGX("test short before=(%d,%d) after=(%d,%d) qAfter=%d qNow=%d readback=%d atTick=%d - "
                 "the walked element is a hop2 brawler in this build, so before and after here are its "
                 "int pair at +%#llx/+%#llx and not a roster slot: the hop2 list is adopted because the "
                 "roster wins on ids while every one of its positions is (0,0), and an id is worth "
                 "nothing to a dodge that needs coordinates",
                 g_test_before_x, g_test_before_y, objects[ownIndex].x, objects[ownIndex].y,
                 g_q_after, qnow, g_readback, g_readback_tick,
                 (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

        return;
    }

    if (g_tick_2 - g_test_tick < TNX_LONG_TICKS) {
        tnx_actuate();
        tnx_witness_line((int)(g_tick_2 - g_test_tick));

        return;
    }

    g_test_state_2 = 4;
    g_tested_2 = 1;
    g_active = 0;

    x = objects[ownIndex].x;
    y = objects[ownIndex].y;
    g_test_after_x_2 = x;
    g_test_after_y_2 = y;
    g_moved_2 = (x != g_test_before_x || y != g_test_before_y) ? 1 : 0;
    g_moved2_2 = g_moved_2;
    g_kept_2 = (g_readback == 1 && tnx_fields() == 1) ? 1 : 0;

    if (tnx_fields() < 0) {
        verdict = "readback-unreadable";
    } else if (g_q_before >= 0 && g_q_after >= 0 && g_q_after <= g_q_before) {
        verdict = "enqueue-failed";
    } else if (g_readback == 0 && g_gate_seen == 0) {
        verdict = "reader-gated";
    } else if (g_readback == 0) {
        verdict = "enqueue-ok-not-consumed";
    } else if (g_readback == 1 && !g_kept_2) {
        verdict = "client-only";
    } else if (g_readback == 1 && g_kept_2) {
        verdict = "real";
    }

    TNX_LOGX("summary calls=%d haveWit=%d interp=(%d,%d) interpMoves=%lld elem=%p elemPos=(%d,%d) "
             "elemMoves=%lld ownFlag=%d ownPair=(%d,%d) - the verdict below is computed from the walked "
             "element, but that element is not written anywhere in this build, so it can only change if "
             "the engine moved own; the interp pair at client+%#llx/+%#llx is the second witness and "
             "the own pair is the field the setter %#llx stores, which the engine is expected to "
             "rewrite on its own events and therefore never to survive a whole second",
             g_calls, g_have_wit, g_wit_x0, g_wit_y0, (long long)g_moves,
             (void *)g_wit_elem, g_wit_x1, g_wit_y1, (long long)g_elem_moves,
             g_own_flag, g_own_held_x, g_own_held_y,
             (unsigned long long)TNX_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_CLIENT_POS_Y_OFF,
             (unsigned long long)TNX_SETPRED4_RVA);

    TNX_LOGX("test long before=(%d,%d) after2=(%d,%d) moved=%d kept=%d verdict=%s mode_max=%d "
             "saw7=%d gateSeen=%d gate1=%d gate2=%d qBefore=%d "
             "qAfter=%d qNow=%d readback=%d atTick=%d rowCount=%d - verdict=real means the pair survived "
             "the long check, client-only means it was read back and then reset, enqueue-ok-not-consumed "
             "means the count grew while the pair never appeared, enqueue-failed means the count never "
             "grew so addInput or the manager is wrong, readback-unreadable means the scene words could "
             "not be read at all",
             g_test_before_x, g_test_before_y, x, y, g_moved_2, g_kept_2, verdict,
             g_mode_max, g_mode_seen7, g_gate_seen,
             (tnx_mode() == TNX_MODE_TARGET) ? 1 : 0, (tnx_inner() == 1) ? 1 : 0,
             g_q_before, g_q_after, tnx_queue_count(NULL), g_readback,
             g_readback_tick, usable);
}

void tnx_queue_line(void) {
    uintptr_t mgr = 0;
    int count = tnx_queue_count(&mgr);
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (g_tick_2 % TNX_QUEUE_EVERY) return;
    if (g_queue_logs >= 240) return;

    g_queue_logs++;

    if (g_queue_logs == 1) {
        TNX_LOGX("statics: reader branch %#llx sits in the mode update %#llx which is a per frame "
                 "update called from exactly one site %#llx as mode->update(dt, elapsed) with x0 = "
                 "[obj+0x28], so the +0xac branch is not dead code and consumed=0 can only mean the "
                 "branch gates closed on this object; the object forwarded to %#llx is the loop body at "
                 "0xac277c stored to the local [sp+0x40] and reloaded into x22 and then x25, so it is the "
                 "iterated battle entity and not a fixed offset on the scene",
                 (unsigned long long)TNX_READER_RVA,
                 (unsigned long long)TNX_READER_ENTRY_RVA,
                 (unsigned long long)TNX_READER_CALLER_RVA,
                 (unsigned long long)0x9fe350ULL);
    }

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_K_OFF, &inK);
    }

    TNX_LOGX("queue tick=%llu count=%d mode=%d gate=%d mgr=%p sceneState=%d flags=%llu ac=%d "
             "in10c=%d in110=%d in114=%d resetSentinel=%d - the count is printed every tick because the "
             "verdict of this run is whether it rises after the push and falls after the consumer ran, "
             "and the reader at %#llx and addInput at %#llx have no data slot so no hook can count them; "
             "in110=-1 marks the reset path, while the apply target of the consumer is a larger object "
             "because %#x is written on it",
             (unsigned long long)g_tick_2, count, tnx_mode(), tnx_gate(), (void *)mgr,
             g_prev_state, (unsigned long long)g_enqueues, tnx_read_flag(), inX, inY, inK,
             (inY == -1) ? 1 : 0, (unsigned long long)TNX_READER_RVA,
             (unsigned long long)TNX_ADDINPUT_RVA, (unsigned)0x528);
}

void tnx_hop2(void) {
    void *outer = NULL;
    void *inner = NULL;
    void *list = NULL;
    void *e0 = NULL;
    void *vt0 = NULL;
    uintptr_t vt0Rva = 0;
    int32_t count = 0;

    if (!g_scene_object) return;
    if (g_hop2_filled) return;

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_HOP2_OWNER_OFF, &outer) || !outer) return;
    if (!tnx_read_ptr((uintptr_t)outer + TNX_HOP2_INNER_OFF, &inner) || !inner) return;

    g_hop2 = (uintptr_t)inner;

    if (!tnx_read_ptr((uintptr_t)inner + TNX_MGR_ARRAY_OFF, &list) || !list) {
        if (g_tick_2 % 10 != 0) return;
        if (g_tick_2 > TNX_HOP2_WAIT) return;
        if (g_hop2_logs >= 6) return;

        g_hop2_logs++;

        TNX_LOGX("hop2 tick=%llu at=%p array=null - [[scene+%#llx]+%#llx] resolves but its list is "
                 "not filled yet, so the wait runs to %d ticks before hop1 is trusted again",
                 (unsigned long long)g_tick_2, inner,
                 (unsigned long long)TNX_HOP2_OWNER_OFF,
                 (unsigned long long)TNX_HOP2_INNER_OFF, TNX_HOP2_WAIT);

        return;
    }

    g_hop2_filled = 1;
    tnx_read_i32((uintptr_t)inner + TNX_MGR_COUNT_OFF, &count);

    if (tnx_read_ptr((uintptr_t)list, &e0) && e0) {
        if (tnx_read_ptr((uintptr_t)e0, &vt0) && vt0) vt0Rva = (uintptr_t)vt0 - g_base;
    }

    TNX_LOGX("hop2 FILLED tick=%llu container=%p count=%d elem0=%p elem0vt=%#llx - this is the list "
             "that carried a team split in the earlier run, so the walk should be retargeted here and "
             "[[scene+%#llx]+%#llx] kept as the hop, with hop1 only a log fallback",
             (unsigned long long)g_tick_2, inner, count, e0, (unsigned long long)vt0Rva,
             (unsigned long long)TNX_HOP2_OWNER_OFF,
             (unsigned long long)TNX_HOP2_INNER_OFF);

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

        TNX_LOGX("input released: the record held (%d,%d,%d) and the previous frame was the last one this "
                 "build wrote, so it is zeroed now - a release at the start of a frame that is about to "
                 "write would blank the input and write it again in the same tick, and that flicker is "
                 "what the character would show instead of its walk. An input left behind would keep the "
                 "character walking on its own, and the release only runs at all when this build was "
                 "the writer, so the player's own stick is never touched"
                 "writing it, so it is set to zero once - an input left behind would keep the character "
                 "walking on its own. The release only runs when this build wrote the record, so the "
                 "player's own stick is never touched", held[0], held[1], held[2]);
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

int tnx_sign(void) {
    uint8_t b = 0;

    if (!g_base) return 1;
    if (!tnx_read_bytes(g_base + TNX_SIGN_RVA, &b, 1)) return 1;

    return b ? 1 : -1;
}

void tnx_snapshot_3(void) {
    uintptr_t ctrl = tnx_controller();
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    uint8_t precond = 0;
    uint8_t gate = 0;
    uint8_t touch = 0;
    float mark = 0.0f;
    float len = 0.0f;
    float dot = 0.0f;
    float dragX = 0.0f;
    float dragY = 0.0f;
    float dragOx = 0.0f;
    float dragOy = 0.0f;

    if (!TNX_DRAG) return;
    if (!ctrl) return;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &rawX)) return;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &rawY)) return;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX)) return;
    if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY)) return;
    if (!tnx_read_bytes(ctrl + TNX_PRECOND_OFF, &precond, sizeof(precond))) return;
    if (!tnx_read_bytes(ctrl + TNX_GATE_OFF_2, &gate, sizeof(gate))) return;

    tnx_read_f32(ctrl + TNX_MARK_OFF, &mark);

    g_raw_x = rawX;
    g_raw_y = rawY;
    g_app_x = appX;
    g_app_y = appY;
    g_precond = (int)precond;
    g_gate = (int)(gate & 1);
    g_mark = mark;

    if (!TNX_HUMAN) return;

    if (!tnx_read_f32(ctrl + TNX_CUR_X_OFF, &dragX) || !tnx_read_f32(ctrl + TNX_CUR_Y_OFF, &dragY)) return;
    if (!tnx_read_f32(ctrl + TNX_ORG_X_OFF, &dragOx) || !tnx_read_f32(ctrl + TNX_ORG_Y_OFF, &dragOy)) return;
    if (!tnx_read_bytes(ctrl + TNX_TOUCH_GATE_OFF, &touch, sizeof(touch))) return;

    g_moved_3 = 0;

    if (fabsf(dragX - g_cur_x) > TNX_EPS) g_moved_3 = 1;
    if (fabsf(dragY - g_cur_y) > TNX_EPS) g_moved_3 = 1;
    if (fabsf(dragOx - g_org_x) > TNX_EPS) g_moved_3 = 1;
    if (fabsf(dragOy - g_org_y) > TNX_EPS) g_moved_3 = 1;

    g_touch = (int)(touch & 1);
    g_human_2 = (g_touch || g_moved_3) ? 1 : 0;

    if (g_drove && g_drive_tick + 1 < g_ticks_3 && !g_human_2) {
        tnx_write_f32(ctrl + TNX_CUR_X_OFF, g_org_x);
        tnx_write_f32(ctrl + TNX_CUR_Y_OFF, g_org_y);
        g_cur_x = g_org_x;
        g_cur_y = g_org_y;
        g_drove = 0;
        g_stops++;
    }

    if (!g_drove) return;
    if (g_last_dx == 0.0f && g_last_dy == 0.0f) return;

    len = sqrtf((float)(rawX * rawX + rawY * rawY));

    if (len < 1.0f) return;

    dot = ((float)rawX * g_last_dx + (float)rawY * g_last_dy) / len;
    g_dot = dot;

    if (fabsf(dot) < TNX_ALIGN) {
        g_proofs = 0;

        return;
    }

    if (g_proofs < TNX_PROOF) g_proofs++;

    if (g_proofs >= TNX_PROOF) g_accepted = 1;
}

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

            TNX_LOGX("stick write #%d ctrl=%p want=(%d,%d) back=(%d,%d) kept=%d engaged=%d - the "
                     "pair is the one the touch handler writes and the battle update reads, and the "
                     "read back is the only proof the store landed; a kept=0 means the engine rewrote "
                     "the pair between our store and the read, which names a different writer",
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

    TNX_LOGX("route engaged=%d stick=(%d,%d) back=(%d,%d) applied=(%d,%d) own=(%d,%d) "
             "movedLastSecond=%d stickSum=(%lld,%lld) stickDir=(%.2f,%.2f) moveDir=(%.2f,%.2f) "
             "dot=%+.2f aligned=%s engagedTicks=%d queue=%d - back is the pair this build wrote and "
             "applied is the pair the ENGINE computes from what it read, so the two together decide the "
             "animation question: when our pair is non zero, applied follows it and the character "
             "moves but stands, then the engine is consuming our store and the walk cycle is keyed off "
             "something else in the same object; when applied stays at whatever the player's own drag "
             "left behind, the engine is reading the pair only on its own input path and a raw store "
             "into the field can never animate, which leaves calling the engine's input handler as the "
             "only route; the dot compares the heading we wrote, summed over the second, with the "
             "heading the character really travelled in that same second, and engagedTicks says how "
             "much of that second was ours",
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

        TNX_LOGX("threat gid=%d elem=%p at=(%d,%d) prev=(%d,%d) dt=%llu vel=(%.1f,%.1f) team=%d "
                 "verdict=%s ownTeam=%d armed=%d - one line per tracked projectile with the verdict the "
                 "threat list gives it, so a list that comes out empty names the filter that emptied it "
                 "instead of leaving 'no shot survived' to be inferred",
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

                TNX_LOGX("body in the way body=(%d,%d) mine=%d own=(%d,%d) candidate=(%d,%d) "
                         "off=%d blocks=%d - a heading whose path runs through another player is "
                         "refused outright, so the walk cannot be aimed through a teammate; the "
                         "distance is measured to the segment and not to its end, which is what the "
                         "test got wrong", (int)px, (int)py, g_pl_mine[i], (int)ownX,
                         (int)ownY, (int)x, (int)y,
                         (int)tnx_seg_dist(ownX, ownY, x, y, px, py), g_body_blocks);
            }

            return 1;
        }
    }

    return 0;
}
