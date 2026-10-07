#include "titanox.h"


uint32_t t_token = 0;



int t_dead_probe_done = 0;

int tnx_mode(void) {
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

    return looks[tnx_mode()];
}


uint64_t t_ctrl_dead = 0;



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
    if (!tnx_read_int(ctrl + TNX_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!tnx_read_int(ctrl + TNX_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!tnx_read_int(ctrl + TNX_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!tnx_read_int(ctrl + TNX_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    if (rawX < -TNX_DEGEN || rawX > TNX_DEGEN) { t_ctrl_dead++; return 0; }
    if (rawY < -TNX_DEGEN || rawY > TNX_DEGEN) { t_ctrl_dead++; return 0; }
    if (appX < -TNX_DEGEN || appX > TNX_DEGEN) { t_ctrl_dead++; return 0; }
    if (appY < -TNX_DEGEN || appY > TNX_DEGEN) { t_ctrl_dead++; return 0; }

    return 1;
}


int t_body_mine = 0;

int t_body_enemy = 0;



int t_wrote_input = 0;

int t_engaged_frame = 0;
























int t_seq_before = -1;

int t_seq_after = -1;


int t_q_after = -1;






void *tnx_msg_alloc(void) {
    uintptr_t stub = tnx_entry_2(TNX_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub) {
        return ((void *(*)(size_t))stub)((size_t)TNX_MSG_SIZE);
    }

    if (t_base && tnx_read_ptr(t_base + TNX_ALLOC_GOT_RVA, (void **)&got) && got) {
        return ((void *(*)(size_t))got)((size_t)TNX_MSG_SIZE);
    }


    return NULL;
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
    if (!tnx_read_int((uintptr_t)queue + TNX_QUEUE_COUNT_OFF, &count)) return -1;

    return (int)count;
}

uintptr_t t_pred_last = 0;


int tnx_predict(int32_t x, int32_t y) {
    uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
    void *battle = NULL;

    if (!TNX_PREDICT) return 0;
    if (!t_addr_setprediction) return 0;
    if (!battleFn) return 0;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) {

        return 0;
    }

    ((void (*)(void *, int, int, int))t_addr_setprediction)(battle, x, y, TNX_PREDICT_FLAG);

    {
        int32_t px = 0;
        int32_t py = 0;

        tnx_read_int((uintptr_t)battle + TNX_MODE_PREDICTX_OFF, &px);
        tnx_read_int((uintptr_t)battle + TNX_MODE_PREDICTY_OFF, &py);

        if (TNX_GATE_WRITE) {
            uint8_t one = 1;
            uint8_t back = 0;

            tnx_write_bytes((uintptr_t)battle + TNX_GATE_OFF, &one, sizeof(one));

            if (tnx_read_bytes((uintptr_t)battle + TNX_GATE_OFF, &back, sizeof(back)) &&
                back == 1) {
            }
        }

        if (px == x && py == y) t_pred_took++;
        else t_pred_miss++;

    }

    t_pred_last = (uintptr_t)battle;


    return 1;
}
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

    if (!t_coord_ok) {

        return 0;
    }

    setFn = tnx_entry_2(TNX_SETINPUT_RVA);

    if (!setFn) return 0;

    pred = tnx_hop(tnx_controller(), NULL);

    if (!tnx_pred_ok(pred)) {
        return 0;
    }

    ((void (*)(uintptr_t, int, int, int))setFn)(pred, x, y, TNX_PRED_FLAG);

    return 1;
}

int t_qguard_probe = 0;
int t_qguard_skip = 0;






int tnx_enqueue_type(int x, int y, int type) {
    if (!t_coord_ok) {

        return 0;
    }


    uintptr_t ctorFn = tnx_entry_2(TNX_MSGCTOR_RVA);
    uintptr_t inputFn = tnx_entry_2(TNX_ADDINPUT_RVA);
    int32_t vx = x;
    int32_t vy = y;
    void *mgr = NULL;
    void *msg = NULL;

    t_seq_before = -1;
    t_seq_after = -1;
    t_q_after = -1;

    if (!inputFn) {

        return 0;
    }

    msg = tnx_msg_alloc();

    if (!msg) {

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
        tnx_read_int((uintptr_t)msg + TNX_TYPE_OFF, &back);

    }

    {
        uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);

        t_token = 0;

        if (battleFn) {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) t_token = tnx_ci_sign(msg, battle);
        }
    }

    if (type == (int)TNX_TYPE_MOVE) (void)tnx_pred_set(x, y);

    mgr = tnx_manager();

    if (!mgr) {

        return 0;
    }

    tnx_read_int((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &t_seq_before);


    {
        void *mgrInner = NULL;

        if (!tnx_read_ptr((uintptr_t)mgr + TNX_CI_MGR_QUEUE_OFF, &mgrInner) || !mgrInner) {

            return 0;
        }
    }


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

            }

            return 0;
        }
    }

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    t_seq_after = -1;
    tnx_read_int((uintptr_t)mgr + TNX_MGR_SEQ_OFF, &t_seq_after);
    t_q_after = tnx_queue_count(NULL);
    if (TNX_QUEUE) {
        if (t_q_after <= 0) t_drain++;
        if ((uint64_t)(t_q_after > 0 ? t_q_after : 0) > t_q_max) {
            t_q_max = (uint64_t)t_q_after;
        }
    }



    return 1;
}

int tnx_enqueue(int x, int y) {
    return tnx_enqueue_type(x, y, (int)TNX_TYPE_MOVE);
}


int t_move_probe = 0;


int t_move_ok = 0;





int32_t t_move_before_x = 0;

int32_t t_move_before_y = 0;

int32_t t_move_before_k = 0;

int32_t t_move_before_arm = 0;

int32_t t_move_after_x = 0;

int32_t t_move_after_y = 0;

int32_t t_move_after_k = 0;

int32_t t_move_after_arm = 0;

int tnx_move_pair_ok(uintptr_t obj, int32_t *outX, int32_t *outY) {
    int32_t ix = 0;
    int32_t iy = 0;
    int32_t key = 0;
    int32_t arm = 0;

    if (!obj) return 0;
    if (!tnx_read_int(obj + TNX_MOVE_X_OFF, &ix)) return 0;
    if (!tnx_read_int(obj + TNX_MOVE_Y_OFF, &iy)) return 0;
    if (!tnx_read_int(obj + TNX_MOVE_KEY_OFF, &key)) return 0;
    if (!tnx_read_int(obj + TNX_MOVE_ARM_OFF, &arm)) return 0;

    if (ix < -TNX_MOVE_COORD_LIMIT || ix > TNX_MOVE_COORD_LIMIT) return 0;
    if (iy < -TNX_MOVE_COORD_LIMIT || iy > TNX_MOVE_COORD_LIMIT) return 0;
    if (key < 0 || key > 1) return 0;
    if ((arm & 0xFF) > TNX_MOVE_ARM_ON) return 0;

    if (outX) *outX = ix;
    if (outY) *outY = iy;

    return 1;
}

int tnx_move_near_own(uintptr_t obj, float ox, float oy, int32_t *outX, int32_t *outY) {
    int32_t ix = 0;
    int32_t iy = 0;
    float dx = 0.0f;
    float dy = 0.0f;

    if (!tnx_move_pair_ok(obj, &ix, &iy)) return 0;

    dx = (float)ix - ox;
    dy = (float)iy - oy;

    if (!(dx > -TNX_MOVE_TOL && dx < TNX_MOVE_TOL)) return 0;
    if (!(dy > -TNX_MOVE_TOL && dy < TNX_MOVE_TOL)) return 0;

    if (outX) *outX = ix;
    if (outY) *outY = iy;

    return 1;
}
int tnx_move_read_vt(uintptr_t obj, uintptr_t *out) {
    uintptr_t vt = 0;

    if (!obj || !out) return 0;
    if (!tnx_read_ptr(obj, (void **)&vt)) return 0;
    if (vt < t_base || vt > t_base + TNX_IMAGE_SPAN) return 0;

    *out = vt;

    return 1;
}

static int tnx_joy_pair_ok(float ax, float ay, float bx, float by, int drag) {
    if (!(ax > -TNX_JOY_COORD_LIMIT && ax < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(ay > -TNX_JOY_COORD_LIMIT && ay < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(bx > -TNX_JOY_COORD_LIMIT && bx < TNX_JOY_COORD_LIMIT)) return 0;
    if (!(by > -TNX_JOY_COORD_LIMIT && by < TNX_JOY_COORD_LIMIT)) return 0;
    if (ax == 0.0f && ay == 0.0f && bx == 0.0f && by == 0.0f) return 0;
    if (drag != 0 && drag != 1) return 0;

    return 1;
}

static void tnx_joy_dump(const char *tag, int idx, uintptr_t obj, int deep) {
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float cx = 0.0f;
    float cy = 0.0f;
    float ex = 0.0f;
    float ey = 0.0f;
    int32_t draga = -1;
    int32_t dragb = -1;
    int joya = 0;
    int joyb = 0;

    if (!obj || !TNX_JOY_SCAN_ON) return;
    if (!deep) return;

    if (!tnx_read_float(obj + (uintptr_t)TNX_BS_AX, &ax)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_BS_AY, &ay)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_BS_BX, &bx)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_BS_BY, &by)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_JOY_ALT_CUR_X, &cx)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_JOY_ALT_CUR_Y, &cy)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_JOY_ALT_CEN_X, &ex)) return;
    if (!tnx_read_float(obj + (uintptr_t)TNX_JOY_ALT_CEN_Y, &ey)) return;

    tnx_read_int(obj + (uintptr_t)TNX_BS_MODE, &draga);
    tnx_read_int(obj + (uintptr_t)TNX_JOY_ALT_DRAG, &dragb);

    joya = tnx_joy_pair_ok(ax, ay, bx, by, draga & 0xFF);
    joyb = tnx_joy_pair_ok(cx, cy, ex, ey, dragb & 0xFF);

}

static void tnx_move_probe(const char *tag, int idx, uintptr_t obj, float ox, float oy) {
    uintptr_t vt = 0;
    int32_t ix = 0;
    int32_t iy = 0;
    int32_t key = 0;
    int32_t arm = 0;
    int near = 0;
    int pair = 0;

    if (!obj) return;

    near = tnx_move_near_own(obj, ox, oy, &ix, &iy);
    pair = tnx_move_pair_ok(obj, NULL, NULL);

    tnx_read_int(obj + TNX_MOVE_KEY_OFF, &key);
    tnx_read_int(obj + TNX_MOVE_ARM_OFF, &arm);

    tnx_move_read_vt(obj, &vt);

}

void tnx_move_locate(float ox, float oy) {
    uintptr_t own = tnx_own_obj();
    uintptr_t scene = tnx_client();
    uintptr_t seed[TNX_MOVE_MAX];
    uintptr_t seen[TNX_MOVE_MAX * 4];
    int seedN = 0;
    int seenN = 0;
    int i = 0;
    int k = 0;
    int hop = 0;
    int kidx = 0;

    if (t_move_probe > 0) return;

    if (t_ticks_a < TNX_MOVE_PROBE_TICK) return;

    t_move_probe = 1;

    seed[seedN++] = own;
    seed[seedN++] = scene;
    seed[seedN++] = t_scene_object;
    seed[seedN++] = t_joystick;

    if (scene) {
        uintptr_t hopped = 0;

        if (tnx_read_ptr(scene + TNX_MGR_OFF, (void **)&hopped) && hopped) seed[seedN++] = hopped;
    }

    for (i = 0; i < TNX_SLOT_COUNT; i++) {
        if (seedN >= TNX_MOVE_MAX - 1) break;
        if (t_slot_object[i]) seed[seedN++] = t_slot_object[i];
        if (t_slot_arg[i] && seedN < TNX_MOVE_MAX - 1) seed[seedN++] = t_slot_arg[i];
    }

    for (i = 0; i < seedN; i++) {
        tnx_move_probe("seed", i, seed[i], ox, oy);
        tnx_joy_dump("seed", i, seed[i], 1);
        seen[seenN++] = seed[i];
    }

    for (hop = 0; hop < TNX_MOVE_HOPS; hop++) {
        int limit = seenN;

        for (i = 0; i < limit && kidx < TNX_MOVE_MAX; i++) {
            uintptr_t base = seen[i];
            uintptr_t off = 0;

            if (!base) continue;

            for (off = 8; off <= TNX_MOVE_SCAN_END; off += 8) {
                uintptr_t kid = 0;
                int dup = 0;
                int j = 0;

                if (!tnx_read_ptr(base + off, (void **)&kid)) continue;
                if (kid < TNX_HEAP_MIN || kid > TNX_HEAP_MAX) continue;
                if ((kid & 7) != 0) continue;
                if (kid >= t_base && kid <= t_base + TNX_IMAGE_SPAN) continue;

                for (j = 0; j < seenN; j++) {
                    if (seen[j] == kid) {
                        dup = 1;

                        break;
                    }
                }

                if (dup) continue;
                if (seenN >= TNX_MOVE_MAX * 4) break;

                seen[seenN++] = kid;

                tnx_move_probe(hop == 0 ? "hop1" : "hop2", kidx, kid, ox, oy);
                tnx_joy_dump("hop1", kidx, kid, TNX_JOY_DEEP);

                kidx++;

                if (kidx >= TNX_MOVE_MAX) break;
            }
        }
    }
}

uintptr_t t_move_stick = 0;

uintptr_t tnx_move_carrier(void) {
    uintptr_t bs = tnx_bs();
    uintptr_t s = 0;
    uintptr_t r = 0;

    t_move_stick = 0;

    if (!bs) return 0;

    if (!tnx_read_ptr(bs + (uintptr_t)TNX_JOY_TARGET_OFF, (void **)&s) || !s) return 0;

    t_move_stick = s;

    r = tnx_hop(s, NULL);

    if (!r) return 0;

    return r;
}

int tnx_move_to(int32_t x, int32_t y, float ox, float oy) {
    uintptr_t fn = 0;
    uintptr_t own = 0;
    int32_t pairX = 0;
    int32_t pairY = 0;
    uint8_t a78 = 0;
    uint8_t a7f = 0;
    uint8_t a80 = 0;
    uint8_t a9c = 0;
    uint8_t a9e = 0;
    int32_t appX = 0;
    int32_t appY = 0;

    tnx_move_locate(ox, oy);

    if (!TNX_MOVE_ON) return 0;
    if (x < -TNX_MOVE_COORD_LIMIT || x > TNX_MOVE_COORD_LIMIT) return 0;
    if (y < -TNX_MOVE_COORD_LIMIT || y > TNX_MOVE_COORD_LIMIT) return 0;

    fn = tnx_entry_2(TNX_MOVE_RVA);
    own = tnx_move_carrier();

    if (!fn || !own) {

        return 0;
    }

    if (!tnx_move_pair_ok(own, &pairX, &pairY)) {


        return 0;
    }


    tnx_read_int(own + TNX_MOVE_X_OFF, &t_move_before_x);
    tnx_read_int(own + TNX_MOVE_Y_OFF, &t_move_before_y);
    tnx_read_int(own + TNX_MOVE_KEY_OFF, &t_move_before_k);
    tnx_read_int(own + TNX_MOVE_ARM_OFF, &t_move_before_arm);

    ((void (*)(void *, int, int, int))fn)((void *)own, (int)x, (int)y, (int)TNX_MOVE_FLAG_10);

    tnx_read_int(own + TNX_MOVE_X_OFF, &t_move_after_x);
    tnx_read_int(own + TNX_MOVE_Y_OFF, &t_move_after_y);
    tnx_read_int(own + TNX_MOVE_KEY_OFF, &t_move_after_k);
    tnx_read_int(own + TNX_MOVE_ARM_OFF, &t_move_after_arm);

    if (t_move_after_x == x && t_move_after_y == y) t_move_ok = 1;

    tnx_read_byte(t_move_stick + 0xf78, &a78);
    tnx_read_byte(t_move_stick + 0xf7f, &a7f);
    tnx_read_byte(t_move_stick + 0xf80, &a80);
    tnx_read_byte(t_move_stick + 0xf9c, &a9c);
    tnx_read_byte(t_move_stick + 0xf9e, &a9e);
    tnx_read_int(t_move_stick + 0xfcc, &appX);
    tnx_read_int(t_move_stick + 0xfd0, &appY);


    return 1;
}









int t_own_logs_a = 0;
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

    tnx_read_int(mgr + 0x4, &held[0]);
    tnx_read_int(mgr + 0x8, &held[1]);
    tnx_read_int(mgr + 0xc, &held[2]);

    t_wrote_input = 0;

    if (held[0] == 0 && held[1] == 0 && held[2] == 0) return;

    tnx_write_bytes(mgr + 0x4, &zero[0], sizeof(zero[0]));
    tnx_write_bytes(mgr + 0x8, &zero[1], sizeof(zero[1]));
    tnx_write_bytes(mgr + 0xc, &zero[2], sizeof(zero[2]));

}

uintptr_t t_joystick = 0;



int t_stick_hold = 0;

uint64_t t_stick_tick = 0;

int t_route_seeded = 0;

int32_t t_last_own_x = 0;

int32_t t_last_own_y = 0;



int t_accepted = 0;












static int tnx_interp(int32_t *x, int32_t *y) {
    uintptr_t client = tnx_client();
    int32_t cx = 0;
    int32_t cy = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (!client) return 0;
    if (!tnx_read_int(client + TNX_CLIENT_POS_X_OFF, &cx)) return 0;
    if (!tnx_read_int(client + TNX_CLIENT_POS_Y_OFF, &cy)) return 0;

    if (x) *x = cx;
    if (y) *y = cy;

    return 1;
}

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
