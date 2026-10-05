#include "titanox.h"

uint64_t g_v225_diag_us = 0;

uint64_t g_v225_diag_max_us = 0;

int g_v113_dead_probe_done = 0;

int tnx_v225_mode(void) {
    int mates = g_v189_mate_n;
    int en = g_v191_enemy_n;

    if (!TNX_V225_MODE_TUNE) return 2;
    if (mates <= 0 && en <= 1) return 0;
    if (mates <= 0) return 1;
    if (mates <= 2) return 2;

    return 3;
}

float tnx_v225_look_ms(void) {
    static const float looks[4] = { 420.0f, 550.0f, 650.0f, 800.0f };

    return looks[tnx_v225_mode()];
}

uint64_t g_v220_clamped = 0;

uint64_t g_v220_ctrl_dead = 0;

uint64_t g_v221_stuck = 0;

uint64_t g_v221_mask_before = 0;

int tnx_v220_ctrl_ok(uintptr_t ctrl) {
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    void *vt = NULL;

    if (!ctrl) return 0;
    if (!tnx_v201_writable(ctrl + TNX_V211_FLAG_OFF, TNX_V128_CTRL_APPLIED_Y_OFF -
                           TNX_V211_FLAG_OFF + sizeof(int32_t))) {
        g_v220_ctrl_dead++;

        return 0;
    }
    if (!tnx_v201_writable(ctrl + TNX_V243_CUR_X_OFF, TNX_V243_ORG_Y_OFF -
                           TNX_V243_CUR_X_OFF + sizeof(float))) {
        g_v220_ctrl_dead++;

        return 0;
    }
    if (TNX_V245_STALE_SIGHT && tnx_read_ptr(ctrl, &vt) && vt) {
        if ((uintptr_t)vt < g_base || (uintptr_t)vt >= g_base + TNX_V60_IMAGE_SPAN) g_v245_stale++;
    }
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    if (rawX < -TNX_V223_DEGEN || rawX > TNX_V223_DEGEN) { g_v220_ctrl_dead++; return 0; }
    if (rawY < -TNX_V223_DEGEN || rawY > TNX_V223_DEGEN) { g_v220_ctrl_dead++; return 0; }
    if (appX < -TNX_V223_DEGEN || appX > TNX_V223_DEGEN) { g_v220_ctrl_dead++; return 0; }
    if (appY < -TNX_V223_DEGEN || appY > TNX_V223_DEGEN) { g_v220_ctrl_dead++; return 0; }

    return 1;
}

int g_v192_body_blocks = 0;

int g_v192_body_mine = 0;

int g_v192_body_enemy = 0;

int g_v192_body_logs = 0;

uint64_t g_v192_human_live = 0;

int g_v171_input_writes = 0;

int g_v171_input_skips = 0;

int g_v171_input_logs = 0;

int g_v171_mgr_logs = 0;

int g_v171_wrote_input = 0;

int g_v171_engaged_frame = 0;

int g_v171_neutral_logs = 0;

int g_v113_test_state = 0;

uint64_t g_v113_test_tick = 0;

int g_v113_test_before_x = 0;

int g_v113_test_before_y = 0;

int g_v113_test_after_x = 0;

int g_v113_test_after_y = 0;

int g_v113_moved = 0;

int g_v113_moved2 = 0;

int g_v113_kept = 0;

int g_v113_tested = 0;

uint64_t g_v113_enqueues = 0;

int g_v113_enq_x = 0;

int g_v113_enq_y = 0;

int g_v113_q_before = -1;

int g_v113_q_after = -1;

int g_v113_readback = -1;

int g_v113_readback_tick = -1;

int g_v113_hop2_logs = 0;

int g_v113_hop2_filled = 0;

uintptr_t g_v113_hop2 = 0;

int g_v113_queue_logs = 0;

int g_v113_window_logs = 0;

uint64_t g_v113_push_frame = 0;

int g_v113_frame_logs = 0;

uint64_t g_v113_test_tickbase = 0;

int g_v126_enq_ok = 0;

const char *g_v126_alloc_how = "none";

void *g_v126_msg = NULL;

int g_v126_seq_before = -1;

int g_v126_seq_after = -1;

int g_v126_q_before = -1;

int g_v126_q_after = -1;

void *g_v126_q_last = NULL;

int32_t g_v126_scene_before_x = 0;

int32_t g_v126_scene_before_y = 0;

uint64_t g_v126_watch_from = 0;

int g_v126_watch_logs = 0;

void *tnx_v126_msg_alloc(void) {
    uintptr_t stub = tnx_v113_entry(TNX_V113_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub) {
        g_v126_alloc_how = "stub";
        return ((void *(*)(size_t))stub)((size_t)TNX_V113_MSG_SIZE);
    }

    if (g_base && tnx_read_ptr(g_base + TNX_V126_ALLOC_GOT_RVA, (void **)&got) && got) {
        g_v126_alloc_how = "got";
        return ((void *(*)(size_t))got)((size_t)TNX_V113_MSG_SIZE);
    }

    g_v126_alloc_how = "malloc";

    return malloc((size_t)TNX_V113_MSG_SIZE);
}

void *tnx_v126_q_last(void) {
    void *mgr = tnx_v113_manager();
    void *queue = NULL;
    void *arr = NULL;
    int32_t count = 0;
    void *e = NULL;

    if (!mgr) return NULL;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_V113_QUEUE_OFF, &queue) || !queue) return NULL;
    if (!tnx_read_i32((uintptr_t)queue + TNX_V113_QUEUE_COUNT_OFF, &count) || count <= 0) return NULL;
    if (!tnx_read_ptr((uintptr_t)queue, &arr) || !arr) return NULL;
    if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)(count - 1) * 8ULL, &e)) return NULL;

    return e;
}

uintptr_t tnx_v113_entry(uintptr_t rva) {
    if (!g_base || !rva) return 0;
    if (!tnx_callable(rva)) return 0;

    return g_base + rva;
}

void *tnx_v113_manager(void) {
    uintptr_t battleFn = tnx_v113_entry(TNX_V113_GETBATTLE_RVA);
    void *battle = NULL;
    void *mgr = NULL;

    if (!battleFn) return NULL;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) return NULL;
    if (!tnx_read_ptr((uintptr_t)battle + TNX_V113_MGR_OFF, &mgr) || !mgr) return NULL;

    return mgr;
}

int tnx_v113_queue_count(uintptr_t *mgrOut) {
    void *mgr = tnx_v113_manager();
    void *queue = NULL;
    int32_t count = -1;

    if (mgrOut) *mgrOut = (uintptr_t)mgr;
    if (!mgr) return -1;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_V113_QUEUE_OFF, &queue) || !queue) return -1;
    if (!tnx_read_i32((uintptr_t)queue + TNX_V113_QUEUE_COUNT_OFF, &count)) return -1;

    return (int)count;
}

uintptr_t g_v192_pred_last = 0;

int g_v192_predict_logs = 0;

uint64_t g_v192_pred_calls = 0;

uint64_t g_v192_pred_fails = 0;

int tnx_v192_predict(int32_t x, int32_t y) {
    uintptr_t battleFn = tnx_v113_entry(TNX_V113_GETBATTLE_RVA);
    void *battle = NULL;

    if (!TNX_V192_PREDICT) return 0;
    if (!g_addr_setprediction) return 0;
    if (!battleFn) return 0;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) {
        g_v192_pred_fails++;

        return 0;
    }

    ((void (*)(void *, int, int, int))g_addr_setprediction)(battle, x, y, TNX_V197_PREDICT_FLAG);

    {
        int32_t px = 0;
        int32_t py = 0;

        tnx_read_i32((uintptr_t)battle + TNX_MODE_PREDICTX_OFF, &px);
        tnx_read_i32((uintptr_t)battle + TNX_MODE_PREDICTY_OFF, &py);

        if (TNX_V226_GATE_WRITE) {
            uint8_t one = 1;
            uint8_t back = 0;

            tnx_write_bytes((uintptr_t)battle + TNX_V222_GATE_OFF, &one, sizeof(one));
            g_v226_gate_writes++;

            if (tnx_read_bytes((uintptr_t)battle + TNX_V222_GATE_OFF, &back, sizeof(back)) &&
                back == 1) {
                g_v226_gate_held++;
            }
        }

        if (px == x && py == y) g_v198_pred_took++;
        else g_v198_pred_miss++;

        if (g_v198_pred_logs < TNX_V198_PRED_LOGS) {
            g_v198_pred_logs++;

            tnx_logf("v198 predict battle=%p sent=(%d,%d) read=(%d,%d) took=%llu miss=%llu - the pair "
                     "the call writes is read straight back, so a call landing on the wrong object "
                     "cannot look like a working prediction", battle, x, y, px, py,
                     (unsigned long long)g_v198_pred_took, (unsigned long long)g_v198_pred_miss);
        }
    }

    g_v192_pred_last = (uintptr_t)battle;
    g_v192_pred_calls++;

    if (g_v192_predict_logs < TNX_V192_PREDICT_LOGS) {
        g_v192_predict_logs++;

        tnx_logf("v192 predict call=%llu battle=%p target=(%d,%d) fn=%p - the same object whose "
                 "+%#llx holds the input manager, so this is the battle client the manager belongs "
                 "to and the prediction is stored on it; the reference script calls exactly this "
                 "with its new position on every frame it moves, which is the step that makes the "
                 "game walk the character instead of carrying it",
                 (unsigned long long)g_v192_pred_calls, battle, x, y, (void *)g_addr_setprediction,
                 (unsigned long long)TNX_V113_MGR_OFF);
    }

    return 1;
}

int tnx_v221_pending(int want, uint64_t *mask) {
    void *mgr = NULL;
    void *list = NULL;
    void *arr = NULL;
    int32_t count = 0;
    int found = 0;
    int i = 0;

    if (mask) *mask = 0;

    mgr = tnx_v113_manager();

    if (!mgr) return 0;
    if (!tnx_read_ptr((uintptr_t)mgr + TNX_V221_LIST_OFF, &list) || !list) return 0;
    if (!tnx_read_i32((uintptr_t)list + TNX_V221_COUNT_OFF, &count)) return 0;
    if (count <= 0 || count > 64) return 0;
    if (!tnx_read_ptr((uintptr_t)list, &arr) || !arr) return 0;

    for (i = 0; i < count; i++) {
        void *el = NULL;
        int32_t t = -1;

        if (!tnx_read_ptr((uintptr_t)arr + (uintptr_t)i * sizeof(void *), &el) || !el) continue;
        if (!tnx_read_i32((uintptr_t)el + TNX_V113_TYPE_OFF, &t)) continue;
        if (mask && t >= 0 && t < 21) *mask |= (1ULL << t);
        if (t == want) found = 1;
    }

    return found;
}

int tnx_v113_enqueue(int x, int y) {
    uintptr_t ctorFn = tnx_v113_entry(TNX_V113_MSGCTOR_RVA);
    uintptr_t inputFn = tnx_v113_entry(TNX_V113_ADDINPUT_RVA);
    int32_t vx = x;
    int32_t vy = y;
    int32_t type = TNX_V126_TYPE_MOVE;
    void *mgr = NULL;
    void *msg = NULL;

    g_v126_enq_ok = 0;
    g_v126_msg = NULL;
    g_v126_q_last = NULL;
    g_v126_seq_before = -1;
    g_v126_seq_after = -1;
    g_v126_q_before = -1;
    g_v126_q_after = -1;

    if (!inputFn) return 0;

    msg = tnx_v126_msg_alloc();

    if (!msg) return 0;

    memset(msg, 0, (size_t)TNX_V113_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, TNX_V126_TYPE_MOVE);

    tnx_write_bytes((uintptr_t)msg + TNX_V113_TYPE_OFF, &type, sizeof(type));
    tnx_write_bytes((uintptr_t)msg + TNX_V113_X_OFF, &vx, sizeof(vx));
    tnx_write_bytes((uintptr_t)msg + TNX_V113_Y_OFF, &vy, sizeof(vy));

    mgr = tnx_v113_manager();

    if (!mgr) {
        tnx_logf("v126 queuePush aborted x=%d y=%d msg=%p alloc=%s - battle+%#llx is null, so the "
                 "message was built but not pushed and is left allocated on purpose rather than freed "
                 "through a pointer the queue never saw",
                 x, y, msg, g_v126_alloc_how, (unsigned long long)TNX_V113_MGR_OFF);

        return 0;
    }

    tnx_read_i32((uintptr_t)mgr + TNX_V126_MGR_SEQ_OFF, &g_v126_seq_before);

    g_v126_q_before = tnx_v113_queue_count(NULL);

    if (tnx_v221_pending(TNX_V126_TYPE_MOVE, &g_v221_mask_before)) {
        g_v221_stuck++;
    }

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    g_v126_seq_after = -1;
    tnx_read_i32((uintptr_t)mgr + TNX_V126_MGR_SEQ_OFF, &g_v126_seq_after);
    g_v126_q_after = tnx_v113_queue_count(NULL);
    g_v126_q_last = tnx_v126_q_last();
    g_v126_msg = msg;
    g_v126_enq_ok = 1;

    if (TNX_V219_QUEUE) {
        if (g_v126_q_after <= 0) g_v219_drain++;
        if ((uint64_t)(g_v126_q_after > 0 ? g_v126_q_after : 0) > g_v219_q_max) {
            g_v219_q_max = (uint64_t)g_v126_q_after;
        }
    }
    g_v113_enqueues++;
    g_v113_push_frame = g_v48_ticks;

    if (g_v156_push_logs < TNX_V156_PUSH_LOGS || (g_v156_push_logs % 64) == 0) {
        tnx_logf("v126 queuePush tick=%llu type=%d x=%d y=%d msg=%p mgr=%p alloc=%s seqBefore=%d "
                 "seqAfter=%d qBefore=%d qAfter=%d qLast=%p - the movement message of this build is the one "
                 "the battle update builds at %#llx: size %#x, the ctor %#llx stores the type at +%#llx with "
                 "w1 loaded with %d and not 2, the clamped pair goes to +%#llx as two int32, and the push is "
                 "addInput %#llx with the manager read as %#llx+%#llx; the allocator used here is %s because "
                 "the stub %#llx opens with adrp and the callable gate refuses it, so the GOT slot %#llx is "
                 "read and malloc is the last resort, and manager+%#llx is the sequence counter addInput "
                 "increments, so seqAfter above seqBefore is proof the call ran at all",
                 (unsigned long long)g_v103_tick, TNX_V126_TYPE_MOVE, x, y, msg, mgr, g_v126_alloc_how,
                 g_v126_seq_before, g_v126_seq_after, g_v126_q_before, g_v126_q_after, g_v126_q_last,
                 (unsigned long long)0x79de88ULL, (unsigned)TNX_V113_MSG_SIZE,
                 (unsigned long long)TNX_V113_MSGCTOR_RVA, (unsigned long long)TNX_V113_TYPE_OFF,
                 TNX_V126_TYPE_MOVE, (unsigned long long)TNX_V113_X_OFF,
                 (unsigned long long)TNX_V113_ADDINPUT_RVA, (unsigned long long)TNX_V113_GETBATTLE_RVA,
                 (unsigned long long)TNX_V113_MGR_OFF, g_v126_alloc_how,
                 (unsigned long long)TNX_V113_ALLOC_RVA, (unsigned long long)TNX_V126_ALLOC_GOT_RVA,
                 (unsigned long long)TNX_V126_MGR_SEQ_OFF);
    }

    g_v156_push_logs++;

    return 1;
}

const char *tnx_v113_state_x(int32_t v) {
    if (v == g_v113_enq_x) return "MATCH";
    if (v == -1) return "RESET";
    if (v == 0) return "DEFAULT";

    return "other";
}

const char *tnx_v113_state_y(int32_t v) {
    if (v == g_v113_enq_y && g_v113_enq_y != 0) return "MATCH";
    if (v == -1) return "RESET";
    if (v == 0) return (g_v113_enq_y == 0) ? "MATCH=DEFAULT" : "DEFAULT";

    return "other";
}

uintptr_t g_v128_wit_elem = 0;

int32_t g_v128_wit_x0 = 0;

int32_t g_v128_wit_y0 = 0;

int32_t g_v128_wit_x1 = 0;

int32_t g_v128_wit_y1 = 0;

int32_t g_v128_own_held_x = 0;

int32_t g_v128_own_held_y = 0;

int32_t g_v128_own_flag = -1;

int g_v128_have_wit = 0;

int g_v128_active = 0;

int g_v128_calls = 0;

int g_v128_act_logs = 0;

int g_v128_wit_logs = 0;

int g_v128_own_logs = 0;

int g_v128_probe_done = 0;

int64_t g_v128_moves = 0;

int64_t g_v128_elem_moves = 0;

int tnx_v128_witness(int32_t *x, int32_t *y) {
    int32_t wx = 0;
    int32_t wy = 0;

    if (x) *x = 0;
    if (y) *y = 0;

    if (!tnx_v116_interp(&wx, &wy)) return 0;

    if (x) *x = wx;
    if (y) *y = wy;

    return 1;
}

void tnx_v128_probe(void) {
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    uintptr_t own = tnx_v127_own_obj();
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

    if (g_v128_probe_done) return;
    if (!ctrl) return;

    g_v128_probe_done = 1;

    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_DIRTY_OFF, &dirty)) dirty = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_ALIVE_OFF, &alive)) alive = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_ID_OFF, &id)) id = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_GATE_OFF, &gate)) gate = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &app_x)) app_x = 0;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &app_y)) app_y = 0;

    if (own) {
        if (!tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &own_flag)) own_flag = -1;
        if (!tnx_read_i32(own + TNX_V115_MODE_OFF, &own_mode)) own_mode = -1;
    }

    if (tnx_read_ptr(ctrl + TNX_V115_CLIENT_OFF, &container) && container) {
        tnx_read_ptr((uintptr_t)container + TNX_V115_CLIENT_OFF, &hop);
    }

    tnx_logf("v128 probe scene=%p own=%p hop0=%p hop1=%p raw+%#llx=(%d,%d) dirty+%#llx=%d "
             "alive+%#llx=%d id+%#llx=%d gate+%#llx=%d applied+%#llx=(%d,%d) ownFlag+%#llx=%d "
             "ownMode+%#llx=%d - %#llx reads the pair it clamps out of the object it is handed in x0 "
             "as 'ldr w0,[x19,+%#llx]; ldr w1,[x19,+%#llx]' and the same object answers %#llx, so this "
             "line says whether the scene the walk already holds is that object: with a non-zero pair "
             "here and applied+%#llx moving while the raw pair is held, the input of this battle is a "
             "pair on the scene and not a message",
             (void *)ctrl, (void *)own, container, hop, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
             raw_x, raw_y, (unsigned long long)TNX_V128_CTRL_DIRTY_OFF, dirty,
             (unsigned long long)TNX_V128_CTRL_ALIVE_OFF, alive,
             (unsigned long long)TNX_V128_CTRL_ID_OFF, id,
             (unsigned long long)TNX_V128_CTRL_GATE_OFF, gate,
             (unsigned long long)TNX_V128_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_V127_GATE_FLAG_OFF, own_flag,
             (unsigned long long)TNX_V115_MODE_OFF, own_mode, (unsigned long long)0x79d594ULL,
             (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
             (unsigned long long)TNX_V128_CTRL_RAW_Y_OFF, (unsigned long long)0x7b9050ULL,
             (unsigned long long)TNX_V128_CTRL_APPLIED_X_OFF);
}

int tnx_v128_resolve_own(const tnx_v47_obj_t *objects, int usable, int *indexOut,
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

        if (g_v142_score_logs < 8) {
            g_v142_score_logs++;

            tnx_logf("v142 score enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d - own is "
                     "looked for on the tick snapshot and never on the live globals, so this line "
                     "and the walk line must print the same arr and n in the same tick",
                     (void *)g_v142_tick_array, g_v142_tick_count, (void *)g_players_array,
                     g_players_count, (void *)g_v142_tick_array, g_v142_tick_count);
        }

        if (tnx_v134_own_by_min_gid(g_v142_tick_array, g_v142_tick_count, &minOwn, &minGid) &&
            minOwn) {
            for (i = 0; i < usable; i++) {
                if (objects[i].object != minOwn) continue;

                if (indexOut) *indexOut = i;
                if (fromOut) *fromOut = "v134-min";

                return 1;
            }
        }
    }

    if (tnx_v129_own_from_slot(&slotOwn, &slotGid) && slotOwn) {
        for (i = 0; i < usable; i++) {
            if (objects[i].object != slotOwn) continue;
            if (objects[i].gid < TNX_V75_GID_FLOOR || objects[i].gid >= TNX_V75_GID_MAX) continue;

            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-slot";

            return 1;
        }
    }

    if (g_v134_own_gid > 0) {
        wantGid = g_v134_own_gid;
    } else if (slotGid > 0) {
        wantGid = slotGid;
    } else if (g_v102_own_ptr) {
        wantGid = tnx_v106_gid((uintptr_t)g_v102_own_ptr, NULL);
    }

    for (i = 0; i < usable; i++) {
        if (objects[i].x <= -TNX_V75_COORD_MAX || objects[i].x >= TNX_V75_COORD_MAX) continue;
        if (objects[i].y <= -TNX_V75_COORD_MAX || objects[i].y >= TNX_V75_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        if (wantGid > 0 && objects[i].gid == wantGid) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-gid";

            tnx_logf("v129 own-gid idx=%d gid=%d pos=(%d,%d) wantGid=%d slotIdx=%d - own is named by the "
                     "id the slot element of hop0 carries, which is the engine's own index and not a "
                     "distance, because the interpolated pair is not a position when the mode never "
                     "reaches the lerp branch",
                     i, objects[i].gid, objects[i].x, objects[i].y, wantGid, g_v129_own_slot_idx);

            return 1;
        }
    }

    if (tnx_v134_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    hasWit = tnx_v128_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {
        tnx_logf("v129 own-none usable=%d wantGid=%d slotOwn=%p slotIdx=%d interpUnusable=1 - neither "
                 "the slot element nor an element with the slot id is in the collected list and the "
                 "interpolated pair is (0,0), so own is left unresolved instead of being taken from a "
                 "witness that this mode never updates",
                 usable, wantGid, (void *)slotOwn, g_v129_own_slot_idx);

        return 0;
    }

    for (i = 0; i < usable; i++) {
        int64_t dx = 0;
        int64_t dy = 0;
        int64_t d = 0;

        if (objects[i].x <= -TNX_V75_COORD_MAX || objects[i].x >= TNX_V75_COORD_MAX) continue;
        if (objects[i].y <= -TNX_V75_COORD_MAX || objects[i].y >= TNX_V75_COORD_MAX) continue;
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

    if (g_v128_own_logs < TNX_V128_OWN_LOGS) {
        g_v128_own_logs++;

        tnx_logf("v129 own-near idx=%d gid=%d pos=(%d,%d) interp=(%d,%d) d2=%lld wantGid=%d - own is "
                 "the list element closest to the pair read from client+%#llx/+%#llx only after the "
                 "slot element and the slot id both missed, and this line is the one that has to be "
                 "watched for a wrong gid being chosen",
                 best, objects[best].gid, objects[best].x, objects[best].y, wx, wy, (long long)bestD,
                 wantGid, (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
                 (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);
    }

    return 1;
}

void tnx_v128_actuate(void) {
    uintptr_t own = tnx_v127_own_obj();
    uintptr_t ownVt = 0;
    uintptr_t ownCls = 0;
    uintptr_t ctrl = (uintptr_t)g_scene_object;
    uintptr_t fn = tnx_v113_entry(TNX_V112_SETPRED4_RVA);
    int32_t raw_x = TNX_V129_DX;
    int32_t raw_y = TNX_V129_DY;
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
    int doWrite = (TNX_V129_MODE == TNX_V129_MODE_WRITE ||
                   TNX_V129_MODE == TNX_V129_MODE_BOTH) ? 1 : 0;
    int doSetter = (TNX_V129_MODE == TNX_V129_MODE_SETTER ||
                    TNX_V129_MODE == TNX_V129_MODE_BOTH) ? 1 : 0;

    if (!g_v128_active) return;
    if (!doWrite && !doSetter) return;

    g_v128_calls++;

    tnx_v128_probe();

    if (!tnx_v128_witness(&wx, &wy)) {
        wx = g_v128_wit_x0;
        wy = g_v128_wit_y0;
    } else {
        g_v128_have_wit = 1;
    }

    if (TNX_V147_ACT_WRITE && doWrite && ctrl &&
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_keep_x) &&
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_keep_y)) {
        if (raw_keep_x != raw_x || raw_keep_y != raw_y) {
            tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_x, sizeof(raw_x));
            tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_y, sizeof(raw_y));

            g_v144_raw_writes++;
        } else {
            g_v144_raw_skips++;
        }
    }

    if (doSetter && fn && own) {
        if (tnx_read_i32(own + TNX_V112_INPUT_X_OFF, &pairBeforeX)) {
            tnx_read_i32(own + TNX_V112_INPUT_Y_OFF, &pairBeforeY);
            tnx_read_i32(own + TNX_V112_INPUT_K_OFF, &pairBeforeK);
            tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &gateBefore);
            tnx_read_i32(own + TNX_V115_MODE_OFF, &modeBefore);
        }

        tnx_logf("v129 setter-before x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d "
                 "mode+%#llx=%d call=%d - the receiver of %#llx is the own object and never the scene, "
                 "because %#llx stores on the getOwnCharacter result and the reader reads the same "
                 "object, so a call with the scene as x0 would store where nothing reads",
                 (void *)own, (unsigned long long)TNX_V112_INPUT_X_OFF, pairBeforeX,
                 (unsigned long long)TNX_V112_INPUT_Y_OFF, pairBeforeY,
                 (unsigned long long)TNX_V112_INPUT_K_OFF, pairBeforeK,
                 (unsigned long long)TNX_V127_GATE_FLAG_OFF, gateBefore,
                 (unsigned long long)TNX_V115_MODE_OFF, modeBefore, g_v128_calls,
                 (unsigned long long)TNX_V112_SETPRED4_RVA, (unsigned long long)0x79de14ULL);

        ((void (*)(void *, int, int, int))fn)((void *)own, wx + TNX_V129_DX, wy + TNX_V129_DY,
                                              TNX_V127_SETFLAG);

        setterRan = 1;

        tnx_read_i32(own + TNX_V112_INPUT_X_OFF, &pairAfterX);
        tnx_read_i32(own + TNX_V112_INPUT_Y_OFF, &pairAfterY);
        tnx_read_i32(own + TNX_V112_INPUT_K_OFF, &pairAfterK);
        tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &gateAfter);
        tnx_read_i32(own + TNX_V115_MODE_OFF, &modeAfter);

        tnx_logf("v129 setter-after x0=%p [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d [x0+%#llx]=%d "
                 "mode=%d wrote=%d want=(%d,%d) - the four words are read on the very receiver the call "
                 "was made on, so this line names where the store landed; +%#llx=1 means the producer "
                 "half of the pair %#llx consumes is in place, and a word that reads back as want=(%d,%d) "
                 "is the only proof the call ran at all",
                 (void *)own, (unsigned long long)TNX_V112_INPUT_X_OFF, pairAfterX,
                 (unsigned long long)TNX_V112_INPUT_Y_OFF, pairAfterY,
                 (unsigned long long)TNX_V112_INPUT_K_OFF, pairAfterK,
                 (unsigned long long)TNX_V127_GATE_FLAG_OFF, gateAfter, modeAfter, 1,
                 wx + TNX_V129_DX, wy + TNX_V129_DY, (unsigned long long)TNX_V127_GATE_FLAG_OFF,
                 (unsigned long long)0xac3424ULL, wx + TNX_V129_DX, wy + TNX_V129_DY);

        g_v128_own_held_x = pairAfterX;
        g_v128_own_held_y = pairAfterY;
        g_v128_own_flag = gateAfter;
    }

    (void)raw_keep_x;
    (void)raw_keep_y;

    if (own && !doSetter) {
        tnx_read_i32(own + TNX_V127_GATE_FLAG_OFF, &flagAfter);

        if (!tnx_read_i32(own + TNX_V127_GATE_X_OFF, &g_v128_own_held_x)) g_v128_own_held_x = 0;
        if (!tnx_read_i32(own + TNX_V127_GATE_Y_OFF, &g_v128_own_held_y)) g_v128_own_held_y = 0;

        g_v128_own_flag = flagAfter;
    }

    if (g_v128_act_logs < TNX_V128_ACT_LOGS) {
        g_v128_act_logs++;

        tnx_v144_vt_ok(own, &ownVt);

        if (ownVt >= g_base) ownCls = ownVt - g_base;

        if (g_v145_actuate_logs < 8) {
            g_v145_actuate_logs++;

            tnx_logf("v145 actuate own=%p ownFrom=%s ownClassRva=%#llx valid=%d - this is the same "
                     "value the gate line and the dodge block read, so own here and ownFound there "
                     "have to point at one element in one tick or the split is still open",
                     (void *)own, g_v145_own_from, (unsigned long long)ownCls, own ? 1 : 0);
        }

        tnx_logf("v129 actuate mode=%d call=%d doWrite=%d doSetter=%d own=%p ownFrom=%s "
                 "ownClassRva=%#llx scene=%p wrote raw+%#llx "
                 "(%d,%d) over (%d,%d) on the scene, setterRan=%d, wouldCall %#llx(own,%d,%d,%d) from "
                 "the witness "
                 "(%d,%d) - mode %d is chain-only and never reaches this line, %d writes only the raw "
                 "pair the battle update clamps for itself, %d calls only the setter and %d does both; "
                 "the pair is %d,%d and not the old %d,%d, because the message carries clamp(position + "
                 "step) and a step of hundreds is a teleport the server has no reason to accept",
                 TNX_V129_MODE, g_v128_calls, doWrite, doSetter, (void *)own, g_v145_own_from,
                 (unsigned long long)ownCls, (void *)ctrl,
                 (unsigned long long)TNX_V128_CTRL_RAW_X_OFF, raw_x, raw_y, raw_keep_x, raw_keep_y,
                 setterRan, (unsigned long long)TNX_V112_SETPRED4_RVA, wx + TNX_V129_DX,
                 wy + TNX_V129_DY,
                 TNX_V127_SETFLAG, wx, wy, TNX_V129_MODE_CHAIN, TNX_V129_MODE_WRITE,
                 TNX_V129_MODE_SETTER, TNX_V129_MODE_BOTH, TNX_V129_DX, TNX_V129_DY,
                 TNX_V128_RAW_X, TNX_V128_RAW_Y);
    }
}

void tnx_v128_witness_line(int plus) {
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

    if (!g_v128_active) return;
    if (g_v128_wit_logs >= TNX_V128_WIT_LOGS) return;

    g_v128_wit_logs++;

    tnx_v128_witness(&wx, &wy);

    if (g_v128_wit_elem) {
        if (!tnx_read_i32(g_v128_wit_elem + TNX_OBJ_X_OFF, &ex)) ex = -1;
        if (!tnx_read_i32(g_v128_wit_elem + TNX_OBJ_Y_OFF, &ey)) ey = -1;
    }

    if (ctrl) {
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &app_x)) app_x = -1;
        if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &app_y)) app_y = -1;
    }

    moved = (wx != g_v128_wit_x0 || wy != g_v128_wit_y0) ? 1 : 0;
    elemMoved = (ex != g_v128_wit_x1 || ey != g_v128_wit_y1) ? 1 : 0;

    if (moved) g_v128_moves++;
    if (elemMoved) g_v128_elem_moves++;

    tnx_logf("v128 witness +%d interp=(%d,%d) was=(%d,%d) moved=%d moves=%lld | elem=%p pos=(%d,%d) "
             "was=(%d,%d) elemMoved=%d elemMoves=%lld | scene raw+%#llx=(%d,%d) applied+%#llx=(%d,%d) "
             "- neither the interp pair at client+%#llx/+%#llx nor the walked element pair is written "
             "by this build any more, so a moved=1 here is the engine moving own after the injected "
             "pair and not a read back of our own store, which is the mistake the v127 direct element "
             "write made when it scored moved=1 on the very pair it had just written",
             plus, wx, wy, g_v128_wit_x0, g_v128_wit_y0, moved, (long long)g_v128_moves,
             (void *)g_v128_wit_elem, ex, ey, g_v128_wit_x1, g_v128_wit_y1, elemMoved,
             (long long)g_v128_elem_moves, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF, raw_x, raw_y,
             (unsigned long long)TNX_V128_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF);

    g_v128_wit_x0 = wx;
    g_v128_wit_y0 = wy;
    g_v128_wit_x1 = ex;
    g_v128_wit_y1 = ey;
}

int tnx_v113_fields_pair(uintptr_t *srcOut, int32_t *xOut, int32_t *yOut) {
    uintptr_t own = tnx_v127_own_obj();
    uintptr_t src = own ? own : (uintptr_t)g_scene_object;
    int32_t x = 0;
    int32_t y = 0;

    if (srcOut) *srcOut = 0;
    if (xOut) *xOut = 0;
    if (yOut) *yOut = 0;

    if (!src) return 0;
    if (!tnx_read_i32(src + TNX_V112_INPUT_X_OFF, &x)) return 0;
    if (!tnx_read_i32(src + TNX_V112_INPUT_Y_OFF, &y)) return 0;

    if (srcOut) *srcOut = src;
    if (xOut) *xOut = x;
    if (yOut) *yOut = y;

    return 1;
}

int tnx_v113_fields(void) {
    uintptr_t src = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_v113_fields_pair(&src, &x, &y)) return -1;

    return (x == g_v113_enq_x && y == g_v113_enq_y) ? 1 : 0;
}

void tnx_v113_frame_window(void) {
    uint64_t d = 0;
    int32_t inX = 0;
    int32_t inY = 0;

    if (!g_v113_push_frame) return;

    d = g_v48_ticks - g_v113_push_frame;

    if (d > TNX_V113_FRAME_WINDOW) return;
    if (g_v113_frame_logs >= 40) return;

    g_v113_frame_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
    }

    {
        uintptr_t client = tnx_v115_client();
        int32_t cx = 0;
        int32_t cy = 0;
        int32_t ck = 0;

        if (client) {
            tnx_read_i32(client + TNX_V115_CLIENT_POS_X_OFF, &cx);
            tnx_read_i32(client + TNX_V115_CLIENT_POS_Y_OFF, &cy);
        }

        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &ck);

        tnx_logf("v117 frame tick=%llu frame=+%llu qcount=%d mode=%d gate=%d inner=%d in10c=%d(%s) "
                 "in110=%d(%s) in114=%d client80=%d client84=%d - the window carries the mode id because "
                 "three different causes leave the same empty readback: the queue not being consumed, "
                 "the queue consumed while the +%#llx branch is gated because mode != %d, and the branch "
                 "running while the apply path never touches +%#llx; gate=1 means mode == %d and "
                 "(*[mode+%#llx])+%#x == 1; client80/client84 is the pair %#llx writes on the client at "
                 "client+%#llx, which is the interpolation output and the sharpest position signal here",
                 (unsigned long long)g_v103_tick, (unsigned long long)d, tnx_v113_queue_count(NULL),
                 tnx_v115_mode(), tnx_v115_gate(), tnx_v115_inner(), inX, tnx_v113_state_x(inX),
                 inY, tnx_v113_state_y(inY), ck, cx, cy, (unsigned long long)TNX_V113_READER_RVA,
                 TNX_V115_MODE_TARGET, (unsigned long long)TNX_V112_INPUT_X_OFF, TNX_V115_MODE_TARGET,
                 (unsigned long long)TNX_V115_GATE_PTR_OFF, (unsigned)TNX_V115_GATE_BYTE_OFF,
                 (unsigned long long)0xa26890ULL, (unsigned long long)TNX_V115_CLIENT_POS_X_OFF);
    }
}

void tnx_v113_window(int plus) {
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (plus % TNX_V127_FRAME_EVERY) return;
    if (g_v113_window_logs >= 12) return;

    g_v113_window_logs++;

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &inK);
    }

    tnx_logf("v113 window tick=+%d qcount=%d in10c=%d in110=%d in114=%d want=(%d,%d) match=%d - the "
             "window is one line every %d ticks instead of one per tick, because the queue drain was "
             "already shown to be steady and the per tick line only spent the log budget",
             plus, tnx_v113_queue_count(NULL), inX, inY, inK, g_v113_enq_x, g_v113_enq_y,
             tnx_v113_fields(), TNX_V127_FRAME_EVERY);
}

void tnx_v113_test(const tnx_v47_obj_t *objects, int usable, int ownIndex) {
    int32_t x = 0;
    int32_t y = 0;
    int qnow = -1;
    const char *verdict = "readback-unreadable";

    if (!objects || usable <= 0) return;
    if (g_v113_test_state >= 4) return;
    if (!g_scene_object) return;

    if (ownIndex < 0 || ownIndex >= usable) ownIndex = 0;

    if (!g_v113_test_tickbase) g_v113_test_tickbase = g_v103_tick;

    {
        int mode = tnx_v115_mode();

        if (mode > g_v115_mode_max) g_v115_mode_max = mode;
        if (mode == TNX_V115_MODE_TARGET) g_v115_mode_seen7 = 1;
        if (tnx_v115_gate() == 1) g_v115_gate_seen = 1;
    }

    if (!TNX_V115_TEST_ENABLE) {
        if (g_v113_test_state == 0 && (g_v103_tick - g_v113_test_tickbase) >= TNX_V115_MODE_WAIT) {
            g_v113_test_state = 4;
            g_v113_tested = 1;

            tnx_logf("v115 notest mode_max=%d saw7=%d gateSeen=%d gate=%d - the build ran without the "
                     "enqueue test and this line is the mode census: with saw7=0 the +%#llx branch is "
                     "unreachable in this battle because the mode id never reaches %d, so the whole "
                     "+0xac pipeline, %#llx and the client pair write belong to that mode alone",
                     g_v115_mode_max, g_v115_mode_seen7, g_v115_gate_seen, tnx_v115_gate(),
                     (unsigned long long)TNX_V113_READER_RVA, TNX_V115_MODE_TARGET,
                     (unsigned long long)0xa26890ULL);
        }

        return;
    }

    if (g_v113_test_state == 0) {
        if (TNX_V115_REQUIRE_GATE && tnx_v115_gate() != 1) {
            if (g_v115_mode_wait_logs < 2) {
                g_v115_mode_wait_logs++;

                tnx_logf("v115 modewait tick=%llu mode=%d target=%d inner=%d gate=%d - the test is held "
                         "until the reader gate opens, because the +%#llx branch answers only when the "
                         "mode id at +%#llx is %d and (*[mode+%#llx])+%#x is 1; pushing before that would "
                         "book a false empty readback as enqueue-ok-not-consumed",
                         (unsigned long long)g_v103_tick, tnx_v115_mode(), TNX_V115_MODE_TARGET,
                         tnx_v115_inner(), tnx_v115_gate(), (unsigned long long)TNX_V113_READER_RVA,
                         (unsigned long long)TNX_V115_MODE_OFF, TNX_V115_MODE_TARGET,
                         (unsigned long long)TNX_V115_GATE_PTR_OFF, (unsigned)TNX_V115_GATE_BYTE_OFF);
            }

            if (g_v103_tick - g_v113_test_tickbase < TNX_V115_MODE_WAIT) return;

            g_v113_test_state = 4;
            g_v113_tested = 1;

            tnx_logf("v115 modewait NEVER OPENED after %d ticks mode_max=%d saw7=%d inner=%d - the gate "
                     "never opened, so the +%#llx branch, %#llx and the client pair write were never in "
                     "play and the enqueue was not attempted at all; this is reader-gated and it means "
                     "the actuator of this battle is elsewhere, not the +0xac pipeline",
                     TNX_V115_MODE_WAIT, g_v115_mode_max, g_v115_mode_seen7, tnx_v115_inner(),
                     (unsigned long long)TNX_V113_READER_RVA, (unsigned long long)0xa26890ULL);

            return;
        }

        g_v113_test_state = 1;
        g_v113_test_tick = g_v103_tick;
        g_v113_test_before_x = objects[ownIndex].x;
        g_v113_test_before_y = objects[ownIndex].y;

        tnx_v129_chain();

        if (!tnx_v128_witness(&g_v128_wit_x0, &g_v128_wit_y0)) {
            g_v128_wit_x0 = objects[ownIndex].x;
            g_v128_wit_y0 = objects[ownIndex].y;
        } else {
            g_v128_have_wit = 1;
        }

        g_v128_wit_elem = objects[ownIndex].object;
        g_v128_wit_x1 = objects[ownIndex].x;
        g_v128_wit_y1 = objects[ownIndex].y;
        g_v128_calls = 0;
        g_v128_moves = 0;
        g_v128_elem_moves = 0;

        g_v113_enq_x = g_v128_wit_x0 + TNX_V129_DX;
        g_v113_enq_y = g_v128_wit_y0 + TNX_V129_DY;

        if (TNX_V129_MODE == TNX_V129_MODE_CHAIN) {
            g_v113_test_state = 4;
            g_v113_tested = 1;

            tnx_logf("v129 chain-only mode=%d own=%p ownFromWitness=(%d,%d) elem=%p elemPos=(%d,%d) "
                     "slotOwn=%p slotIdx=%d slotGid=%d expect=%d queue=%d - nothing is written in this "
                     "mode on purpose: the chain check has to answer whether the scene the walk holds "
                     "is the object whose +%#llx the battle update clamps, and whether own is an "
                     "element of hop0, before any write is allowed to look like a result",
                     TNX_V129_MODE, (void *)tnx_v127_own_obj(), g_v128_wit_x0, g_v128_wit_y0,
                     (void *)g_v128_wit_elem, g_v128_wit_x1, g_v128_wit_y1, (void *)g_v129_own_slot,
                     g_v129_own_slot_idx, g_v129_own_slot_gid, TNX_V129_OWN_EXPECT_GID,
                     tnx_v113_queue_count(NULL), (unsigned long long)TNX_V128_CTRL_RAW_X_OFF);

            return;
        }

        g_v128_active = 1;

        g_v126_scene_before_x = 0;
        g_v126_scene_before_y = 0;

        if (g_scene_object) {
            tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &g_v126_scene_before_x);
            tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &g_v126_scene_before_y);
        }

        g_v126_watch_from = 0;
        g_v126_watch_logs = 0;

        g_v122_pre_reloads = g_v120_reloads;
        g_v122_pre_frames = g_v48_ticks;

        g_v121_push_frame = g_v48_ticks;
        g_v121_win_stage = 0;
        g_v121_win_reloads = g_v120_reloads;

        if (TNX_V129_MODE == TNX_V129_MODE_BOTH) {
            tnx_v113_enqueue(g_v113_enq_x, g_v113_enq_y);

            g_v113_q_before = g_v126_q_before;
            g_v113_q_after = g_v126_q_after;
        }

        tnx_v127_setter(g_v113_enq_x + TNX_V127_DX_SETTER, g_v113_enq_y + TNX_V127_DY_SETTER);
        tnx_v127_elem_write(objects[ownIndex].object,
                            g_v113_enq_x + TNX_V127_DX_ELEM, g_v113_enq_y + TNX_V127_DY_ELEM);

        tnx_v128_probe();
        tnx_v128_actuate();

        tnx_logf("v129 test mode=%d pair=(%d,%d) enum dest=(%d,%d) enq=%d seq %d->%d q %d->%d qLast=%p "
                 "| write=%d setter=%d scene=%p rawOff=%#llx setterFn=%#llx own=%p | witnesses elem=%p "
                 "(%d,%d) interp=(%d,%d) - the three channels are no longer fired together: %d only "
                 "writes the raw pair on the scene, %d only calls the setter on own, %d does both and "
                 "also pushes the nearby destination so the queue is measured apart from the two local "
                 "channels, and the walked element is written by none of them",
                 TNX_V129_MODE, g_v113_enq_x, g_v113_enq_y, g_v128_wit_x0, g_v128_wit_y0,
                 g_v128_wit_x0 + TNX_V129_DX, g_v128_wit_y0 + TNX_V129_DY,
                 g_v126_enq_ok, g_v126_seq_before, g_v126_seq_after, g_v126_q_before, g_v126_q_after,
                 g_v126_q_last, (void *)g_scene_object,
                 (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
                 (unsigned long long)TNX_V112_SETPRED4_RVA, (void *)tnx_v127_own_obj(),
                 (void *)g_v128_wit_elem, g_v128_wit_x1, g_v128_wit_y1, g_v128_wit_x0, g_v128_wit_y0,
                 TNX_V129_MODE_WRITE, TNX_V129_MODE_SETTER, TNX_V129_MODE_BOTH);

        tnx_v113_window(0);

        return;
    }

    if (g_v113_test_state == 1) {
        int plus = (int)(g_v103_tick - g_v113_test_tick);

        tnx_v128_actuate();
        tnx_v128_witness_line(plus);

        if (g_v113_readback < 0 && tnx_v113_fields() == 1) {
            g_v113_readback = 1;
            g_v113_readback_tick = plus;
        }

        if (plus < TNX_V127_READBACK_TICKS) {
            tnx_v113_window(plus);

            return;
        }

        tnx_v127_readback(plus);

        g_v113_test_state = 2;

        if (g_v113_readback < 0) g_v113_readback = 0;

        qnow = tnx_v113_queue_count(NULL);

        tnx_logf("v127 test short before=(%d,%d) after=(%d,%d) qAfter=%d qNow=%d readback=%d atTick=%d - "
                 "the walked element is a hop2 brawler in this build, so before and after here are its "
                 "int pair at +%#llx/+%#llx and not a roster slot: the hop2 list is adopted because the "
                 "roster wins on ids while every one of its positions is (0,0), and an id is worth "
                 "nothing to a dodge that needs coordinates",
                 g_v113_test_before_x, g_v113_test_before_y, objects[ownIndex].x, objects[ownIndex].y,
                 g_v113_q_after, qnow, g_v113_readback, g_v113_readback_tick,
                 (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

        return;
    }

    if (g_v103_tick - g_v113_test_tick < TNX_V113_LONG_TICKS) {
        tnx_v128_actuate();
        tnx_v128_witness_line((int)(g_v103_tick - g_v113_test_tick));

        return;
    }

    g_v113_test_state = 4;
    g_v113_tested = 1;
    g_v128_active = 0;

    x = objects[ownIndex].x;
    y = objects[ownIndex].y;
    g_v113_test_after_x = x;
    g_v113_test_after_y = y;
    g_v113_moved = (x != g_v113_test_before_x || y != g_v113_test_before_y) ? 1 : 0;
    g_v113_moved2 = g_v113_moved;
    g_v113_kept = (g_v113_readback == 1 && tnx_v113_fields() == 1) ? 1 : 0;

    if (tnx_v113_fields() < 0) {
        verdict = "readback-unreadable";
    } else if (g_v113_q_before >= 0 && g_v113_q_after >= 0 && g_v113_q_after <= g_v113_q_before) {
        verdict = "enqueue-failed";
    } else if (g_v113_readback == 0 && g_v115_gate_seen == 0) {
        verdict = "reader-gated";
    } else if (g_v113_readback == 0) {
        verdict = "enqueue-ok-not-consumed";
    } else if (g_v113_readback == 1 && !g_v113_kept) {
        verdict = "client-only";
    } else if (g_v113_readback == 1 && g_v113_kept) {
        verdict = "real";
    }

    tnx_logf("v128 summary calls=%d haveWit=%d interp=(%d,%d) interpMoves=%lld elem=%p elemPos=(%d,%d) "
             "elemMoves=%lld ownFlag=%d ownPair=(%d,%d) - the verdict below is computed from the walked "
             "element, but that element is not written anywhere in this build, so it can only change if "
             "the engine moved own; the interp pair at client+%#llx/+%#llx is the second witness and "
             "the own pair is the field the setter %#llx stores, which the engine is expected to "
             "rewrite on its own events and therefore never to survive a whole second",
             g_v128_calls, g_v128_have_wit, g_v128_wit_x0, g_v128_wit_y0, (long long)g_v128_moves,
             (void *)g_v128_wit_elem, g_v128_wit_x1, g_v128_wit_y1, (long long)g_v128_elem_moves,
             g_v128_own_flag, g_v128_own_held_x, g_v128_own_held_y,
             (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF,
             (unsigned long long)TNX_V112_SETPRED4_RVA);

    tnx_logf("v115 test long before=(%d,%d) after2=(%d,%d) moved=%d kept=%d verdict=%s mode_max=%d "
             "saw7=%d gateSeen=%d gate1=%d gate2=%d qBefore=%d "
             "qAfter=%d qNow=%d readback=%d atTick=%d rowCount=%d - verdict=real means the pair survived "
             "the long check, client-only means it was read back and then reset, enqueue-ok-not-consumed "
             "means the count grew while the pair never appeared, enqueue-failed means the count never "
             "grew so addInput or the manager is wrong, readback-unreadable means the scene words could "
             "not be read at all",
             g_v113_test_before_x, g_v113_test_before_y, x, y, g_v113_moved, g_v113_kept, verdict,
             g_v115_mode_max, g_v115_mode_seen7, g_v115_gate_seen,
             (tnx_v115_mode() == TNX_V115_MODE_TARGET) ? 1 : 0, (tnx_v115_inner() == 1) ? 1 : 0,
             g_v113_q_before, g_v113_q_after, tnx_v113_queue_count(NULL), g_v113_readback,
             g_v113_readback_tick, usable);
}

void tnx_v113_queue_line(void) {
    uintptr_t mgr = 0;
    int count = tnx_v113_queue_count(&mgr);
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (g_v103_tick % TNX_V113_QUEUE_EVERY) return;
    if (g_v113_queue_logs >= 240) return;

    g_v113_queue_logs++;

    if (g_v113_queue_logs == 1) {
        tnx_logf("v113 statics: reader branch %#llx sits in the mode update %#llx which is a per frame "
                 "update called from exactly one site %#llx as mode->update(dt, elapsed) with x0 = "
                 "[obj+0x28], so the +0xac branch is not dead code and consumed=0 can only mean the "
                 "branch gates closed on this object; the object forwarded to %#llx is the loop body at "
                 "0xac277c stored to the local [sp+0x40] and reloaded into x22 and then x25, so it is the "
                 "iterated battle entity and not a fixed offset on the scene",
                 (unsigned long long)TNX_V113_READER_RVA,
                 (unsigned long long)TNX_V113_READER_ENTRY_RVA,
                 (unsigned long long)TNX_V113_READER_CALLER_RVA,
                 (unsigned long long)0x9fe350ULL);
    }

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_X_OFF, &inX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_Y_OFF, &inY);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_V112_INPUT_K_OFF, &inK);
    }

    tnx_logf("v115 queue tick=%llu count=%d mode=%d gate=%d mgr=%p sceneState=%d flags=%llu ac=%d "
             "in10c=%d in110=%d in114=%d resetSentinel=%d - the count is printed every tick because the "
             "verdict of this run is whether it rises after the push and falls after the consumer ran, "
             "and the reader at %#llx and addInput at %#llx have no data slot so no hook can count them; "
             "in110=-1 marks the reset path, while the apply target of the consumer is a larger object "
             "because %#x is written on it",
             (unsigned long long)g_v103_tick, count, tnx_v115_mode(), tnx_v115_gate(), (void *)mgr,
             g_v103_prev_state, (unsigned long long)g_v113_enqueues, tnx_v112_read_flag(), inX, inY, inK,
             (inY == -1) ? 1 : 0, (unsigned long long)TNX_V113_READER_RVA,
             (unsigned long long)TNX_V113_ADDINPUT_RVA, (unsigned)0x528);
}

void tnx_v113_hop2(void) {
    void *outer = NULL;
    void *inner = NULL;
    void *list = NULL;
    void *e0 = NULL;
    void *vt0 = NULL;
    uintptr_t vt0Rva = 0;
    int32_t count = 0;

    if (!g_scene_object) return;
    if (g_v113_hop2_filled) return;

    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_V113_HOP2_OWNER_OFF, &outer) || !outer) return;
    if (!tnx_read_ptr((uintptr_t)outer + TNX_V113_HOP2_INNER_OFF, &inner) || !inner) return;

    g_v113_hop2 = (uintptr_t)inner;

    if (!tnx_read_ptr((uintptr_t)inner + TNX_MGR_ARRAY_OFF, &list) || !list) {
        if (g_v103_tick % 10 != 0) return;
        if (g_v103_tick > TNX_V113_HOP2_WAIT) return;
        if (g_v113_hop2_logs >= 6) return;

        g_v113_hop2_logs++;

        tnx_logf("v113 hop2 tick=%llu at=%p array=null - [[scene+%#llx]+%#llx] resolves but its list is "
                 "not filled yet, so the wait runs to %d ticks before hop1 is trusted again",
                 (unsigned long long)g_v103_tick, inner,
                 (unsigned long long)TNX_V113_HOP2_OWNER_OFF,
                 (unsigned long long)TNX_V113_HOP2_INNER_OFF, TNX_V113_HOP2_WAIT);

        return;
    }

    g_v113_hop2_filled = 1;
    tnx_read_i32((uintptr_t)inner + TNX_MGR_COUNT_OFF, &count);

    if (tnx_read_ptr((uintptr_t)list, &e0) && e0) {
        if (tnx_read_ptr((uintptr_t)e0, &vt0) && vt0) vt0Rva = (uintptr_t)vt0 - g_base;
    }

    tnx_logf("v113 hop2 FILLED tick=%llu container=%p count=%d elem0=%p elem0vt=%#llx - this is the list "
             "that carried a team split in the earlier run, so the walk should be retargeted here and "
             "[[scene+%#llx]+%#llx] kept as the hop, with hop1 only a log fallback",
             (unsigned long long)g_v103_tick, inner, count, e0, (unsigned long long)vt0Rva,
             (unsigned long long)TNX_V113_HOP2_OWNER_OFF,
             (unsigned long long)TNX_V113_HOP2_INNER_OFF);

}

float tnx_v192_seg_dist(float ax, float ay, float bx, float by, float px, float py) {
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

int tnx_v174_proj_vel(const tnx_v140_proj_t *p, float *vxOut, float *vyOut) {
    uint64_t dt = 0;

    if (!p->elem || !p->hasPrev) return 0;

    dt = p->qtick - p->ptick;
    if (dt == 0 || dt > TNX_V174_DT_MAX) dt = 1;

    *vxOut = (float)(p->x - p->px) / (float)dt;
    *vyOut = (float)(p->y - p->py) / (float)dt;

    return 1;
}

uintptr_t tnx_v171_input_mgr(void) {
    void *mgr = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr(g_scene_object + TNX_MODE_INPUTMGR_OFF, &mgr) || !mgr) return 0;
    if (!tnx_heap_contains((uintptr_t)mgr)) return 0;

    return (uintptr_t)mgr;
}

void tnx_v171_write_input(float dirX, float dirY) {
    uintptr_t mgr = 0;
    int32_t want[3] = { 0, 0, 0 };
    int32_t before[3] = { 0, 0, 0 };
    int32_t after[3] = { 0, 0, 0 };
    int kept = 0;

    if (!TNX_V171_INPUT_MGR) return;

    want[0] = TNX_V171_INPUT_TYPE;
    want[1] = (int32_t)((double)dirX * (double)TNX_V171_INPUT_MAG);
    want[2] = (int32_t)((double)dirY * (double)TNX_V171_INPUT_MAG);

    mgr = tnx_v171_input_mgr();

    if (!mgr) {
        if (g_v171_mgr_logs < 4) {
            g_v171_mgr_logs++;

            tnx_logf("v171 no input manager yet: scene=%p +%#llx reads nothing, so the sidestep has no "
                     "engine input to write and only the position channels are left",
                     (void *)g_scene_object, (unsigned long long)TNX_MODE_INPUTMGR_OFF);
        }

        return;
    }

    tnx_read_i32(mgr + 0x4, &before[0]);
    tnx_read_i32(mgr + 0x8, &before[1]);
    tnx_read_i32(mgr + 0xc, &before[2]);

    if (TNX_V171_INPUT_CHANGE_GATE && before[0] == want[0] && before[1] == want[1] &&
        before[2] == want[2]) {
        g_v171_input_skips++;

        return;
    }

    tnx_write_bytes(mgr + 0x4, &want[0], sizeof(want[0]));
    tnx_write_bytes(mgr + 0x8, &want[1], sizeof(want[1]));
    tnx_write_bytes(mgr + 0xc, &want[2], sizeof(want[2]));

    g_v171_input_writes++;

    g_v171_wrote_input = 1;

    tnx_read_i32(mgr + 0x4, &after[0]);
    tnx_read_i32(mgr + 0x8, &after[1]);
    tnx_read_i32(mgr + 0xc, &after[2]);

    kept = (after[0] == want[0] && after[1] == want[1] && after[2] == want[2]) ? 1 : 0;

    if (g_v171_input_logs < 12) {
        g_v171_input_logs++;

        tnx_logf("v171 input write #%d inputMgr=%p want=(%d,%d,%d) before=(%d,%d,%d) after=(%d,%d,%d) "
                 "kept=%d skips=%d - the engine's own movement input, the record the user named: type "
                 "at +%#x, x at +%#x, y at +%#x, all int32, movement type %d. The before triple is what "
                 "the game itself leaves in the record, so a before of zeros while the player runs and "
                 "a before that tracks a real stick are both readable from this one line. The raw pair "
                 "at +%#llx is now stage %d and identical writes there are skipped",
                 g_v171_input_writes, (void *)mgr, want[0], want[1], want[2], before[0], before[1],
                 before[2], after[0], after[1], after[2], kept, g_v171_input_skips, 0x4, 0x8, 0xc,
                 TNX_V171_INPUT_TYPE, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
                 TNX_V171_STAGE_STICK);
    }
}

void tnx_v171_input_release(void) {
    uintptr_t mgr = 0;
    int32_t held[3] = { 0, 0, 0 };
    int32_t zero[3] = { 0, 0, 0 };
    int engagedLast = g_v171_engaged_frame;

    g_v171_engaged_frame = 0;

    if (!TNX_V171_INPUT_MGR) return;
    if (!g_v171_wrote_input) return;
    if (engagedLast) return;

    mgr = tnx_v171_input_mgr();

    if (!mgr) return;

    tnx_read_i32(mgr + 0x4, &held[0]);
    tnx_read_i32(mgr + 0x8, &held[1]);
    tnx_read_i32(mgr + 0xc, &held[2]);

    g_v171_wrote_input = 0;

    if (held[0] == 0 && held[1] == 0 && held[2] == 0) return;

    tnx_write_bytes(mgr + 0x4, &zero[0], sizeof(zero[0]));
    tnx_write_bytes(mgr + 0x8, &zero[1], sizeof(zero[1]));
    tnx_write_bytes(mgr + 0xc, &zero[2], sizeof(zero[2]));

    if (g_v171_neutral_logs < 4) {
        g_v171_neutral_logs++;

        tnx_logf("v171 input released: the record held (%d,%d,%d) and the previous frame was the last one this "
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

uintptr_t g_v205_joystick = 0;

int g_v205_joystick_logs = 0;

uint64_t g_v205_joystick_writes = 0;

uint64_t g_v205_joystick_took = 0;

int32_t g_v174_stick_x = 0;

int32_t g_v174_stick_y = 0;

int g_v174_stick_hold = 0;

uint64_t g_v174_stick_tick = 0;

int g_v174_engaged_ticks = 0;

long long g_v174_sum_x = 0;

long long g_v174_sum_y = 0;

int g_v174_route_seeded = 0;

int32_t g_v174_last_own_x = 0;

int32_t g_v174_last_own_y = 0;

uint64_t g_v243_drag_writes = 0;

uint64_t g_v243_back_ok = 0;

uint64_t g_v243_back_bad = 0;

int g_v243_precond = -1;

int g_v243_gate = -1;

int g_v243_accepted = 0;

int g_v243_proofs = 0;

int g_v243_drove = 0;

uint64_t g_v243_drive_tick = 0;

float g_v243_mark = 0.0f;

float g_v243_dot = 0.0f;

float g_v243_last_dx = 0.0f;

float g_v243_last_dy = 0.0f;

int32_t g_v243_raw_x = 0;

int32_t g_v243_raw_y = 0;

int32_t g_v243_app_x = 0;

int32_t g_v243_app_y = 0;

int tnx_v243_sign(void) {
    uint8_t b = 0;

    if (!g_base) return 1;
    if (!tnx_read_bytes(g_base + TNX_V243_SIGN_RVA, &b, 1)) return 1;

    return b ? 1 : -1;
}

void tnx_v243_snapshot(void) {
    uintptr_t ctrl = tnx_v150_controller();
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

    if (!TNX_V243_DRAG) return;
    if (!ctrl) return;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &rawX)) return;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &rawY)) return;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &appX)) return;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &appY)) return;
    if (!tnx_read_bytes(ctrl + TNX_V243_PRECOND_OFF, &precond, sizeof(precond))) return;
    if (!tnx_read_bytes(ctrl + TNX_V243_GATE_OFF, &gate, sizeof(gate))) return;

    tnx_read_f32(ctrl + TNX_V243_MARK_OFF, &mark);

    g_v243_raw_x = rawX;
    g_v243_raw_y = rawY;
    g_v243_app_x = appX;
    g_v243_app_y = appY;
    g_v243_precond = (int)precond;
    g_v243_gate = (int)(gate & 1);
    g_v243_mark = mark;

    if (!TNX_V244_HUMAN) return;

    if (!tnx_read_f32(ctrl + TNX_V243_CUR_X_OFF, &dragX) || !tnx_read_f32(ctrl + TNX_V243_CUR_Y_OFF, &dragY)) return;
    if (!tnx_read_f32(ctrl + TNX_V243_ORG_X_OFF, &dragOx) || !tnx_read_f32(ctrl + TNX_V243_ORG_Y_OFF, &dragOy)) return;
    if (!tnx_read_bytes(ctrl + TNX_V193_TOUCH_GATE_OFF, &touch, sizeof(touch))) return;

    g_v244_moved = 0;

    if (fabsf(dragX - g_v244_cur_x) > TNX_V244_EPS) g_v244_moved = 1;
    if (fabsf(dragY - g_v244_cur_y) > TNX_V244_EPS) g_v244_moved = 1;
    if (fabsf(dragOx - g_v244_org_x) > TNX_V244_EPS) g_v244_moved = 1;
    if (fabsf(dragOy - g_v244_org_y) > TNX_V244_EPS) g_v244_moved = 1;

    g_v244_touch = (int)(touch & 1);
    g_v244_human = (g_v244_touch || g_v244_moved) ? 1 : 0;

    if (g_v243_drove && g_v243_drive_tick + 1 < g_v48_ticks && !g_v244_human) {
        tnx_write_f32(ctrl + TNX_V243_CUR_X_OFF, g_v244_org_x);
        tnx_write_f32(ctrl + TNX_V243_CUR_Y_OFF, g_v244_org_y);
        g_v244_cur_x = g_v244_org_x;
        g_v244_cur_y = g_v244_org_y;
        g_v243_drove = 0;
        g_v244_stops++;
    }

    if (!g_v243_drove) return;
    if (g_v243_last_dx == 0.0f && g_v243_last_dy == 0.0f) return;

    len = sqrtf((float)(rawX * rawX + rawY * rawY));

    if (len < 1.0f) return;

    dot = ((float)rawX * g_v243_last_dx + (float)rawY * g_v243_last_dy) / len;
    g_v243_dot = dot;

    if (fabsf(dot) < TNX_V243_ALIGN) {
        g_v243_proofs = 0;

        return;
    }

    if (g_v243_proofs < TNX_V243_PROOF) g_v243_proofs++;

    if (g_v243_proofs >= TNX_V243_PROOF) g_v243_accepted = 1;
}

void tnx_v243_drag(int engaged, int haveOwn, int32_t ownX, int32_t ownY, float dirX, float dirY) {
    uintptr_t ctrl = tnx_v150_controller();
    float len = 0.0f;
    float ox = 0.0f;
    float oy = 0.0f;
    float cx = 0.0f;
    float cy = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    int sign = 0;

    if (!TNX_V243_DRAG) return;
    if (!engaged || !haveOwn) return;
    if (!tnx_v220_ctrl_ok(ctrl)) return;

    sign = tnx_v243_sign();
    len = sqrtf(dirX * dirX + dirY * dirY);

    if (len < 0.0001f) return;

    ox = (float)ownX;
    oy = (float)ownY;
    cx = ox + dirX / len * TNX_V243_DRAG_MAG * (float)sign;
    cy = oy + dirY / len * TNX_V243_DRAG_MAG * (float)sign;

    tnx_write_f32(ctrl + TNX_V243_ORG_X_OFF, ox);
    tnx_write_f32(ctrl + TNX_V243_ORG_Y_OFF, oy);
    tnx_write_f32(ctrl + TNX_V243_CUR_X_OFF, cx);
    tnx_write_f32(ctrl + TNX_V243_CUR_Y_OFF, cy);

    g_v244_org_x = ox;
    g_v244_org_y = oy;
    g_v244_cur_x = cx;
    g_v244_cur_y = cy;
    g_v243_last_dx = dirX / len * (float)sign;
    g_v243_last_dy = dirY / len * (float)sign;
    g_v243_drove = 1;
    g_v243_drive_tick = g_v48_ticks;
    g_v243_drag_writes++;

    if (tnx_read_f32(ctrl + TNX_V243_CUR_X_OFF, &bx) && tnx_read_f32(ctrl + TNX_V243_CUR_Y_OFF, &by) &&
        fabsf(bx - cx) < 1.0f && fabsf(by - cy) < 1.0f) {
        g_v243_back_ok++;
    } else {
        g_v243_back_bad++;
    }

    if (g_v244_logs < TNX_V244_LOGS) {
        g_v244_logs++;

        tnx_logf("v244 drag ctrl=%p engaged=%d haveOwn=%d own=(%d,%d) wrote cur=(%.0f,%.0f) org=(%.0f,%.0f) "
                 "back=(%.0f,%.0f) ok=%llu bad=%llu writes=%llu stops=%llu quiet=%llu touch=%d moved=%d "
                 "human=%d sign=%d mark=%.3f precond=%d gate=%d raw=(%d,%d) applied=(%d,%d) dot=%+.2f "
                 "proofs=%d accepted=%d - the engine builds its move vector as the pair at +%#llx/+%#llx "
                 "minus the drag origin at +%#llx/+%#llx, so that pair is the input and this build writes "
                 "it only while it drives: stops counts the single write that puts the current point back "
                 "on the origin when a drive ends, which is the stop a body that slid could not get, and "
                 "quiet counts the frames the movement push was skipped because the push at +%#llx fed a "
                 "queue the engine never drained, so the body went on moving on its own after this build "
                 "stopped asking; moved is the drag pair differing from what this build wrote, which is "
                 "the finger, and human is that or the touch bit, so human near zero while a finger is "
                 "down means the finger test is still blind; the pair at +%#llx is engine state this "
                 "build no longer writes, sign is the byte at %#llx the mover flips the delta with, mark "
                 "at +%#llx is written by the engine's own apply path, and dot is the alignment between "
                 "the pair the engine wrote and the drag this build wrote",
                 (void *)ctrl, engaged, haveOwn, ownX, ownY, (double)cx, (double)cy, (double)ox, (double)oy,
                 (double)bx, (double)by, (unsigned long long)g_v243_back_ok,
                 (unsigned long long)g_v243_back_bad, (unsigned long long)g_v243_drag_writes,
                 (unsigned long long)g_v244_stops, (unsigned long long)g_v244_queue_skips,
                 g_v244_touch, g_v244_moved, g_v244_human, sign, (double)g_v243_mark,
                 g_v243_precond, g_v243_gate, g_v243_raw_x, g_v243_raw_y, g_v243_app_x, g_v243_app_y,
                 (double)g_v243_dot, g_v243_proofs, g_v243_accepted,
                 (unsigned long long)TNX_V243_CUR_X_OFF, (unsigned long long)TNX_V243_CUR_Y_OFF,
                 (unsigned long long)TNX_V243_ORG_X_OFF, (unsigned long long)TNX_V243_ORG_Y_OFF,
                 (unsigned long long)TNX_V113_QUEUE_OFF, (unsigned long long)TNX_V128_CTRL_RAW_X_OFF,
                 (unsigned long long)TNX_V243_SIGN_RVA, (unsigned long long)TNX_V243_MARK_OFF);
    }
}

void tnx_v174_stick(int engaged, float dirX, float dirY) {
    uintptr_t ctrl = tnx_v150_controller();
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t ownX = 0;
    int32_t ownY = 0;
    int want = 0;
    int haveOwn = 0;
    float len = 0.0f;

    haveOwn = tnx_v178_own(&ownX, &ownY);
    tnx_v243_drag(engaged, haveOwn, ownX, ownY, dirX, dirY);

    if (!TNX_V174_RAW_STICK) return;
    if (!tnx_v220_ctrl_ok(ctrl)) return;

    if (engaged) {
        len = sqrtf(dirX * dirX + dirY * dirY);

        if (len >= 0.0001f) {
            want = 1;

            if (TNX_V209_PAIR_RAW) {
                double scale = 1.0;

                if ((double)len > (double)TNX_V209_PAIR_MAX) {
                    scale = (double)TNX_V209_PAIR_MAX / (double)len;
                }

                wx = (int32_t)((double)dirX * scale);
                wy = (int32_t)((double)dirY * scale);
            } else {
                wx = (int32_t)((double)dirX / (double)len * (double)TNX_V165_JOY_MAG);
                wy = (int32_t)((double)dirY / (double)len * (double)TNX_V165_JOY_MAG);
            }

            g_v174_stick_hold = 1;
            g_v174_stick_tick = g_v48_ticks;
            g_v174_engaged_ticks++;
            g_v174_sum_x += wx;
            g_v174_sum_y += wy;
        }
    }

    if (!want) {
        uintptr_t relCtrl = tnx_v150_controller();
        int32_t relX = 0;
        int32_t relY = 0;

        if (!g_v174_stick_hold) return;
        if (!TNX_V212_RAGE && g_v174_stick_tick + TNX_V174_STICK_TTL > g_v48_ticks) return;

        g_v174_stick_hold = 0;

        if (relCtrl && tnx_read_i32(relCtrl + TNX_V128_CTRL_RAW_X_OFF, &relX) &&
            tnx_read_i32(relCtrl + TNX_V128_CTRL_RAW_Y_OFF, &relY)) {
            if (relX != g_v174_stick_x || relY != g_v174_stick_y) return;
        }
    }

    g_v174_stick_x = wx;
    g_v174_stick_y = wy;

    if (!(TNX_V243_RETIRE && g_v243_accepted)) {
        if (!tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_X_OFF, &wx, sizeof(wx))) return;

        tnx_write_bytes(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &wy, sizeof(wy));
    }

    {
        static int stickLogs = 0;

        if (stickLogs < 6) {
            int32_t backX = 0;
            int32_t backY = 0;

            stickLogs++;

            tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &backX);
            tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &backY);

            tnx_logf("v175 stick write #%d ctrl=%p want=(%d,%d) back=(%d,%d) kept=%d engaged=%d - the "
                     "pair is the one the touch handler writes and the battle update reads, and the "
                     "read back is the only proof the store landed; a kept=0 means the engine rewrote "
                     "the pair between our store and the read, which names a different writer",
                     stickLogs, (void *)ctrl, wx, wy, backX, backY,
                     (backX == wx && backY == wy) ? 1 : 0, want);
        }
    }
}

void tnx_v174_route(int engaged) {
    uintptr_t ctrl = tnx_v150_controller();
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t backX = 0;
    int32_t backY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    int dx = 0;
    int dy = 0;
    int moved = 0;
    int ours = g_v174_engaged_ticks;
    long long sumX = 0;
    long long sumY = 0;
    float sLen = 0.0f;
    float mLen = 0.0f;
    float dot = 0.0f;
    const char *align = "no-move";

    if ((g_v48_ticks % 60) != 0) return;
    if (!tnx_v178_own(&ownX, &ownY)) return;

    g_v174_engaged_ticks = 0;

    if (ctrl) {
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &backX);
        tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &backY);
        tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(ctrl + TNX_V128_CTRL_APPLIED_Y_OFF, &appY);
    }

    if (g_v174_route_seeded) {
        dx = (int)(ownX - g_v174_last_own_x);
        dy = (int)(ownY - g_v174_last_own_y);

        moved = (int)sqrtf((float)(dx * dx + dy * dy));
    }

    sumX = g_v174_sum_x;
    sumY = g_v174_sum_y;
    g_v174_sum_x = 0;
    g_v174_sum_y = 0;

    sLen = sqrtf((float)(sumX * sumX + sumY * sumY));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (sLen > 0.5f && mLen > 0.5f) {
        dot = ((float)sumX / sLen) * ((float)dx / mLen) + ((float)sumY / sLen) * ((float)dy / mLen);

        if (dot > 0.7f) align = "same";
        else if (dot < -0.7f) align = "opposite";
        else align = "unrelated";
    }

    g_v174_route_seeded = 1;
    g_v174_last_own_x = ownX;
    g_v174_last_own_y = ownY;

    tnx_logf("v181 route engaged=%d stick=(%d,%d) back=(%d,%d) applied=(%d,%d) own=(%d,%d) "
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
             engaged, g_v174_stick_x, g_v174_stick_y, backX, backY, appX, appY, ownX, ownY, moved,
             sumX, sumY,
             (double)(sLen > 0.5f ? (float)sumX / sLen : 0.0f),
             (double)(sLen > 0.5f ? (float)sumY / sLen : 0.0f),
             (double)(mLen > 0.5f ? (float)dx / mLen : 0.0f),
             (double)(mLen > 0.5f ? (float)dy / mLen : 0.0f),
             (double)dot, align, ours, tnx_v113_queue_count(NULL));
}

void tnx_v174_threats(void) {
    int k = 0;

    if ((g_v48_ticks % 60) != 0) return;

    for (k = 0; k < TNX_V140_PROJ_MAX; k++) {
        const tnx_v140_proj_t *p = &g_v140_projs[k];
        float vx = 0.0f;
        float vy = 0.0f;
        const char *verdict = "threat";

        if (!p->elem) continue;

        if (!tnx_v174_proj_vel(p, &vx, &vy)) {
            verdict = p->hasPrev ? "vel-unreadable" : "one-sample";
        } else if (TNX_V167_TEAM_FILTER && g_v167_own_team_seen && p->team == g_v167_own_team) {
            verdict = "own-team";
        } else if (sqrtf(vx * vx + vy * vy) < TNX_V174_MIN_PROJ_SPEED) {
            verdict = "still";
        }

        tnx_logf("v174 threat gid=%d elem=%p at=(%d,%d) prev=(%d,%d) dt=%llu vel=(%.1f,%.1f) team=%d "
                 "verdict=%s ownTeam=%d armed=%d - one line per tracked projectile with the verdict the "
                 "threat list gives it, so a list that comes out empty names the filter that emptied it "
                 "instead of leaving 'no shot survived' to be inferred",
                 p->gid, (void *)p->elem, p->x, p->y, p->px, p->py,
                 (unsigned long long)(p->qtick - p->ptick), (double)vx, (double)vy, p->team, verdict,
                 g_v167_own_team, g_v167_own_team_seen);
    }
}

int tnx_v192_body_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (g_v189_pl_n <= 0) return 0;

    for (i = 0; i < g_v189_pl_n; i++) {
        float px = 0.0f;
        float py = 0.0f;

        if (g_v189_pl_mine[i]) continue;

        px = (float)g_v189_pl_x[i];
        py = (float)g_v189_pl_y[i];

        if (tnx_v192_seg_dist(ownX, ownY, x, y, px, py) < TNX_V192_BODY_CLEAR) {
            g_v192_body_blocks++;

            if (g_v189_pl_mine[i]) g_v192_body_mine++;
            else g_v192_body_enemy++;

            if (g_v192_body_logs < TNX_V192_BODY_LOGS) {
                g_v192_body_logs++;

                tnx_logf("v192 body in the way body=(%d,%d) mine=%d own=(%d,%d) candidate=(%d,%d) "
                         "off=%d blocks=%d - a heading whose path runs through another player is "
                         "refused outright, so the walk cannot be aimed through a teammate; the "
                         "distance is measured to the segment and not to its end, which is what the "
                         "v189 test got wrong", (int)px, (int)py, g_v189_pl_mine[i], (int)ownX,
                         (int)ownY, (int)x, (int)y,
                         (int)tnx_v192_seg_dist(ownX, ownY, x, y, px, py), g_v192_body_blocks);
            }

            return 1;
        }
    }

    return 0;
}

int tnx_v205_holds(uintptr_t target) {
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    int32_t mode = 0;

    if (!target) return 0;
    if (!tnx_read_i32(target + TNX_V172_BS_MODE, &mode)) return 0;
    if (mode < 0 || mode > 3) return 0;
    if (!tnx_read_f32(target + TNX_V172_BS_AX, &ax)) return 0;
    if (!tnx_read_f32(target + TNX_V172_BS_AY, &ay)) return 0;
    if (!tnx_read_f32(target + TNX_V172_BS_BX, &bx)) return 0;
    if (!tnx_read_f32(target + TNX_V172_BS_BY, &by)) return 0;
    if (!tnx_v95_finite(ax) || !tnx_v95_finite(ay)) return 0;
    if (!tnx_v95_finite(bx) || !tnx_v95_finite(by)) return 0;

    return 1;
}

void tnx_v205_select(void) {
    uintptr_t ctrl = tnx_v150_controller();
    uintptr_t scene = (uintptr_t)g_scene_object;
    uintptr_t chr = g_v182_own_elem;

    if (g_v205_joystick &&
        !tnx_v201_writable(g_v205_joystick + TNX_V172_BS_AX, 4 * sizeof(int32_t))) {
        g_v205_joystick = 0;
    }

    if (g_v205_joystick) return;

    if (tnx_v205_holds(ctrl)) g_v205_joystick = ctrl;
    else if (tnx_v205_holds(scene)) g_v205_joystick = scene;
    else if (tnx_v205_holds(chr)) g_v205_joystick = chr;
    else if (ctrl) g_v205_joystick = ctrl;

    if (g_v205_joystick_logs < TNX_V205_LOGS) {
        g_v205_joystick_logs++;

        tnx_logf("v205 joystick=%p ctrl=%p scene=%p character=%p - the block at +%#llx is the drag "
                 "the walk cycle is built from: ax and ay are the touch origin, bx and by the touch "
                 "now, mode 2 opens the drag, and an equal pair is a body that slides with no cycle",
                 (void *)g_v205_joystick, (void *)ctrl, (void *)scene, (void *)chr,
                 (unsigned long long)TNX_V172_BS_AX);
    }
}

int tnx_v205_walk(float dirX, float dirY) {
    uintptr_t own = 0;
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t targetX = 0;
    int32_t targetY = 0;
    int32_t two = 2;
    uint16_t on = 1;
    float len = sqrtf(dirX * dirX + dirY * dirY);

    if (!TNX_V205_JOYSTICK) return 0;
    if (len < 0.001f) return 0;
    if (!g_v180_hold) return 0;
    if (!tnx_v178_own(&ownX, &ownY)) return 0;

    if (!g_v198_probe_done) {
        g_v198_probe_done = 1;

        tnx_v198_probe((uintptr_t)g_scene_object, "scene");
        tnx_v198_probe(g_v182_own_elem, "character");
        tnx_v198_probe(tnx_v150_controller(), "ctrl");

        tnx_logf("v205 objects scene=%p character=%p battle=%p - the candidates for the object that "
                 "carries the drag block, printed once so a log says which one holds it",
                 (void *)(uintptr_t)g_scene_object, (void *)g_v182_own_elem,
                 (void *)g_v192_pred_last);
    }

    tnx_v205_select();

    own = g_v205_joystick;

    if (!own) return 0;

    targetX = g_v180_tx;
    targetY = g_v180_ty;

    if (targetX == ownX && targetY == ownY) return 0;

    if (TNX_V217_DRAG_SPACE) {
        float cam = 1.0f;
        float camS = 0.0f;
        float ox = 0.0f;
        float oy = 0.0f;
        float wx = (float)(targetX - ownX);
        float wy = (float)(targetY - ownY);
        float dx = 0.0f;
        float dy = 0.0f;

        if (!tnx_read_f32(own + TNX_V205_JOY_AB_OFF, &cam) ||
            !tnx_read_f32(own + TNX_V205_JOY_AA_OFF, &camS) ||
            !(cam * cam + camS * camS > 0.25f)) {
            cam = 1.0f;
            camS = 0.0f;
        }

        if (!tnx_read_f32(own + TNX_V172_BS_BX, &ox) ||
            !tnx_read_f32(own + TNX_V172_BS_BY, &oy)) {
            ox = 0.0f;
            oy = 0.0f;
        }

        dx = cam * wx - camS * wy;
        dy = camS * wx + cam * wy;

        tnx_write_f32(own + TNX_V172_BS_BX, ox);
        tnx_write_f32(own + TNX_V172_BS_BY, oy);
        tnx_write_f32(own + TNX_V172_BS_AX, ox + dx);
        tnx_write_f32(own + TNX_V172_BS_AY, oy + dy);
        g_v217_drag_writes++;
    } else {
        tnx_write_f32(own + TNX_V172_BS_AX, (float)targetX);
        tnx_write_f32(own + TNX_V172_BS_AY, (float)targetY);
        tnx_write_f32(own + TNX_V172_BS_BX, (float)ownX);
        tnx_write_f32(own + TNX_V172_BS_BY, (float)ownY);
    }
    tnx_write_bytes(own + TNX_V172_BS_MODE, &two, sizeof(two));
    tnx_write_bytes(own + TNX_V205_JOY_STATE_OFF, &on, sizeof(on));

    {
        float one = 1.0f;
        float zero = 0.0f;
        float aa = 0.0f;
        float ab = 0.0f;
        int readable = tnx_read_f32(own + TNX_V205_JOY_AA_OFF, &aa) &&
                       tnx_read_f32(own + TNX_V205_JOY_AB_OFF, &ab);

        if (!readable || !(aa * aa + ab * ab > 0.25f)) {
            tnx_write_f32(own + TNX_V205_JOY_AA_OFF, one);
            tnx_write_f32(own + TNX_V205_JOY_AB_OFF, zero);
        }
    }

    g_v205_joystick_writes++;

    {
        float backAx = 0.0f;
        float backBx = 0.0f;

        tnx_read_f32(own + TNX_V172_BS_AX, &backAx);
        tnx_read_f32(own + TNX_V172_BS_BX, &backBx);

        if (tnx_v95_finite(backAx) && tnx_v95_finite(backBx)) {
            g_v217_drag_back += (backAx - backBx) * (backAx - backBx) > 1.0f ? 1 : 0;
        }
    }

    tnx_v198_settle(own, "joystick", (float)targetX, (float)targetY, &g_v205_joystick_took);

    return 1;
}
