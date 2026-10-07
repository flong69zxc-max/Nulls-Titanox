#include "recoil.h"


uint32_t rcl_token = 0;



int rcl_dead_probe_done = 0;

int rcl_mode(void) {
    int mates = rcl_mate_n;
    int en = rcl_enemy_n;

    if (!RCL_MODE_TUNE) return 2;
    if (mates <= 0 && en <= 1) return 0;
    if (mates <= 0) return 1;
    if (mates <= 2) return 2;

    return 3;
}

float rcl_look_ms(void) {
    static const float looks[4] = { 420.0f, 550.0f, 650.0f, 800.0f };

    return looks[rcl_mode()];
}


uint64_t rcl_ctrl_dead = 0;



int rcl_ctrl_ok(uintptr_t ctrl) {
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t appX = 0;
    int32_t appY = 0;
    void *vt = NULL;

    if (!ctrl) return 0;
    if (!rcl_writable(ctrl + RCL_FLAG_OFF_2, RCL_CTRL_APPLIED_Y_OFF -
                           RCL_FLAG_OFF_2 + sizeof(int32_t))) {
        rcl_ctrl_dead++;

        return 0;
    }
    if (!rcl_writable(ctrl + RCL_CUR_X_OFF, RCL_ORG_Y_OFF -
                           RCL_CUR_X_OFF + sizeof(float))) {
        rcl_ctrl_dead++;

        return 0;
    }
    if (RCL_STALE_SIGHT && rcl_read_ptr(ctrl, &vt) && vt) {
        if ((uintptr_t)vt < rcl_base || (uintptr_t)vt >= rcl_base + RCL_IMAGE_SPAN) rcl_stale++;
    }
    if (!rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!rcl_read_int(ctrl + RCL_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!rcl_read_int(ctrl + RCL_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    if (rawX < -RCL_DEGEN || rawX > RCL_DEGEN) { rcl_ctrl_dead++; return 0; }
    if (rawY < -RCL_DEGEN || rawY > RCL_DEGEN) { rcl_ctrl_dead++; return 0; }
    if (appX < -RCL_DEGEN || appX > RCL_DEGEN) { rcl_ctrl_dead++; return 0; }
    if (appY < -RCL_DEGEN || appY > RCL_DEGEN) { rcl_ctrl_dead++; return 0; }

    return 1;
}


int rcl_body_mine = 0;

int rcl_body_enemy = 0;



int rcl_wrote_input = 0;

int rcl_engaged_frame = 0;
























int rcl_seq_before = -1;

int rcl_seq_after = -1;


int rcl_q_after = -1;






void *rcl_msg_alloc(void) {
    uintptr_t stub = rcl_entry_2(RCL_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub) {
        return ((void *(*)(size_t))stub)((size_t)RCL_MSG_SIZE);
    }

    if (rcl_base && rcl_read_ptr(rcl_base + RCL_ALLOC_GOT_RVA, (void **)&got) && got) {
        return ((void *(*)(size_t))got)((size_t)RCL_MSG_SIZE);
    }


    return NULL;
}
uintptr_t rcl_entry_2(uintptr_t rva) {
    if (!rcl_base || !rva) return 0;
    if (!rcl_callable(rva)) return 0;

    return rcl_base + rva;
}

void *rcl_manager(void) {
    uintptr_t battleFn = rcl_entry_2(RCL_GETBATTLE_RVA);
    void *battle = NULL;
    void *mgr = NULL;

    if (!battleFn) return NULL;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) return NULL;
    if (!rcl_read_ptr((uintptr_t)battle + RCL_MGR_OFF, &mgr) || !mgr) return NULL;

    return mgr;
}

int rcl_queue_count(uintptr_t *mgrOut) {
    void *mgr = rcl_manager();
    void *queue = NULL;
    int32_t count = -1;

    if (mgrOut) *mgrOut = (uintptr_t)mgr;
    if (!mgr) return -1;
    if (!rcl_read_ptr((uintptr_t)mgr + RCL_QUEUE_OFF, &queue) || !queue) return -1;
    if (!rcl_read_int((uintptr_t)queue + RCL_QUEUE_COUNT_OFF, &count)) return -1;

    return (int)count;
}

uintptr_t rcl_pred_last = 0;


int rcl_predict(int32_t x, int32_t y) {
    uintptr_t battleFn = rcl_entry_2(RCL_GETBATTLE_RVA);
    void *battle = NULL;

    if (!RCL_PREDICT) return 0;
    if (!rcl_addr_setprediction) return 0;
    if (!battleFn) return 0;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) {

        return 0;
    }

    ((void (*)(void *, int, int, int))rcl_addr_setprediction)(battle, x, y, RCL_PREDICT_FLAG);

    {
        int32_t px = 0;
        int32_t py = 0;

        rcl_read_int((uintptr_t)battle + RCL_MODE_PREDICTX_OFF, &px);
        rcl_read_int((uintptr_t)battle + RCL_MODE_PREDICTY_OFF, &py);

        if (RCL_GATE_WRITE) {
            uint8_t one = 1;
            uint8_t back = 0;

            rcl_write_bytes((uintptr_t)battle + RCL_GATE_OFF, &one, sizeof(one));

            if (rcl_read_bytes((uintptr_t)battle + RCL_GATE_OFF, &back, sizeof(back)) &&
                back == 1) {
            }
        }

        if (px == x && py == y) rcl_pred_took++;
        else rcl_pred_miss++;

    }

    rcl_pred_last = (uintptr_t)battle;


    return 1;
}
static int rcl_pred_probe(uintptr_t pred, int *alignOut, int *readOut, int *writeOut, int *vtOut) {
    void *vtRaw = NULL;
    uintptr_t vt = 0;

    if (alignOut) *alignOut = 0;
    if (readOut) *readOut = 0;
    if (writeOut) *writeOut = 0;
    if (vtOut) *vtOut = 0;

    if (!pred) return 0;
    if ((pred & 7) != 0) return 0;

    if (alignOut) *alignOut = 1;

    if (!rcl_addr_readable(pred, RCL_PRED_SPAN)) return 0;

    if (readOut) *readOut = 1;

    if (!rcl_addr_writable(pred, RCL_PRED_SPAN)) return 0;

    if (writeOut) *writeOut = 1;

    if (!rcl_read_ptr(pred, &vtRaw)) return 0;

    vt = (uintptr_t)vtRaw;

    if (!vt) return 0;

    if (vtOut) *vtOut = 1;

    return 1;
}

static int rcl_pred_ok(uintptr_t pred) {
    return rcl_pred_probe(pred, NULL, NULL, NULL, NULL);
}

int rcl_pred_set(int x, int y) {
    uintptr_t setFn = 0;
    uintptr_t pred = 0;

    if (!RCL_PRED_SET) return 0;

    if (!rcl_coord_ok) {

        return 0;
    }

    setFn = rcl_entry_2(RCL_SETINPUT_RVA);

    if (!setFn) return 0;

    pred = rcl_hop(rcl_controller(), NULL);

    if (!rcl_pred_ok(pred)) {
        return 0;
    }

    ((void (*)(uintptr_t, int, int, int))setFn)(pred, x, y, RCL_PRED_FLAG);

    return 1;
}

int rcl_qguard_probe = 0;
int rcl_qguard_skip = 0;






int rcl_enqueue_type(int x, int y, int type) {
    if (!rcl_coord_ok) {

        return 0;
    }


    uintptr_t ctorFn = rcl_entry_2(RCL_MSGCTOR_RVA);
    uintptr_t inputFn = rcl_entry_2(RCL_ADDINPUT_RVA);
    int32_t vx = x;
    int32_t vy = y;
    void *mgr = NULL;
    void *msg = NULL;

    rcl_seq_before = -1;
    rcl_seq_after = -1;
    rcl_q_after = -1;

    if (!inputFn) {

        return 0;
    }

    msg = rcl_msg_alloc();

    if (!msg) {

        return 0;
    }

    memset(msg, 0, (size_t)RCL_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, RCL_TYPE_MOVE);

    rcl_write_bytes((uintptr_t)msg + RCL_TYPE_OFF, &type, sizeof(type));
    rcl_write_bytes((uintptr_t)msg + RCL_X_OFF, &vx, sizeof(vx));
    rcl_write_bytes((uintptr_t)msg + RCL_Y_OFF, &vy, sizeof(vy));

    if (RCL_QUEUE_GUARD && rcl_qguard_probe < 1) {
        void *mvt = NULL;
        int32_t back = 0;

        rcl_qguard_probe++;

        rcl_read_ptr((uintptr_t)msg, &mvt);
        rcl_read_int((uintptr_t)msg + RCL_TYPE_OFF, &back);

    }

    {
        uintptr_t battleFn = rcl_entry_2(RCL_GETBATTLE_RVA);

        rcl_token = 0;

        if (battleFn) {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) rcl_token = rcl_ci_sign(msg, battle);
        }
    }

    if (type == (int)RCL_TYPE_MOVE) (void)rcl_pred_set(x, y);

    mgr = rcl_manager();

    if (!mgr) {

        return 0;
    }

    rcl_read_int((uintptr_t)mgr + RCL_MGR_SEQ_OFF, &rcl_seq_before);


    {
        void *mgrInner = NULL;

        if (!rcl_read_ptr((uintptr_t)mgr + RCL_CI_MGR_QUEUE_OFF, &mgrInner) || !mgrInner) {

            return 0;
        }
    }


    if (RCL_QUEUE_GUARD || RCL_QUEUE_GUARD_MGR) {
        int msgOk = rcl_instance_shaped((uintptr_t)msg);
        int mgrOk = rcl_manager_shape((uintptr_t)mgr);

        if ((RCL_QUEUE_GUARD && !msgOk) || (RCL_QUEUE_GUARD_MGR && !mgrOk)) {
            if (rcl_qguard_skip < RCL_QGUARD_LOGS) {
                void *mvt = NULL;
                void *gvt = NULL;

                rcl_qguard_skip++;

                rcl_read_ptr((uintptr_t)msg, &mvt);
                rcl_read_ptr((uintptr_t)mgr, &gvt);

            }

            return 0;
        }
    }

    ((void (*)(void *, void *))inputFn)(mgr, msg);

    rcl_seq_after = -1;
    rcl_read_int((uintptr_t)mgr + RCL_MGR_SEQ_OFF, &rcl_seq_after);
    rcl_q_after = rcl_queue_count(NULL);
    if (RCL_QUEUE) {
        if (rcl_q_after <= 0) rcl_drain++;
        if ((uint64_t)(rcl_q_after > 0 ? rcl_q_after : 0) > rcl_q_max) {
            rcl_q_max = (uint64_t)rcl_q_after;
        }
    }



    return 1;
}

int rcl_enqueue(int x, int y) {
    return rcl_enqueue_type(x, y, (int)RCL_TYPE_MOVE);
}


int rcl_move_probe_count = 0;


int rcl_move_ok = 0;





int32_t rcl_move_before_x = 0;

int32_t rcl_move_before_y = 0;

int32_t rcl_move_before_k = 0;

int32_t rcl_move_before_arm = 0;

int32_t rcl_move_after_x = 0;

int32_t rcl_move_after_y = 0;

int32_t rcl_move_after_k = 0;

int32_t rcl_move_after_arm = 0;

int rcl_move_pair_ok(uintptr_t obj, int32_t *outX, int32_t *outY) {
    int32_t ix = 0;
    int32_t iy = 0;
    int32_t key = 0;
    int32_t arm = 0;

    if (!obj) return 0;
    if (!rcl_read_int(obj + RCL_MOVE_X_OFF, &ix)) return 0;
    if (!rcl_read_int(obj + RCL_MOVE_Y_OFF, &iy)) return 0;
    if (!rcl_read_int(obj + RCL_MOVE_KEY_OFF, &key)) return 0;
    if (!rcl_read_int(obj + RCL_MOVE_ARM_OFF, &arm)) return 0;

    if (ix < -RCL_MOVE_COORD_LIMIT || ix > RCL_MOVE_COORD_LIMIT) return 0;
    if (iy < -RCL_MOVE_COORD_LIMIT || iy > RCL_MOVE_COORD_LIMIT) return 0;
    if (key < 0 || key > 1) return 0;
    if ((arm & 0xFF) > RCL_MOVE_ARM_ON) return 0;

    if (outX) *outX = ix;
    if (outY) *outY = iy;

    return 1;
}

int rcl_move_near_own(uintptr_t obj, float ox, float oy, int32_t *outX, int32_t *outY) {
    int32_t ix = 0;
    int32_t iy = 0;
    float dx = 0.0f;
    float dy = 0.0f;

    if (!rcl_move_pair_ok(obj, &ix, &iy)) return 0;

    dx = (float)ix - ox;
    dy = (float)iy - oy;

    if (!(dx > -RCL_MOVE_TOL && dx < RCL_MOVE_TOL)) return 0;
    if (!(dy > -RCL_MOVE_TOL && dy < RCL_MOVE_TOL)) return 0;

    if (outX) *outX = ix;
    if (outY) *outY = iy;

    return 1;
}
int rcl_move_read_vt(uintptr_t obj, uintptr_t *out) {
    uintptr_t vt = 0;

    if (!obj || !out) return 0;
    if (!rcl_read_ptr(obj, (void **)&vt)) return 0;
    if (vt < rcl_base || vt > rcl_base + RCL_IMAGE_SPAN) return 0;

    *out = vt;

    return 1;
}

static int rcl_joy_pair_ok(float ax, float ay, float bx, float by, int drag) {
    if (!(ax > -RCL_JOY_COORD_LIMIT && ax < RCL_JOY_COORD_LIMIT)) return 0;
    if (!(ay > -RCL_JOY_COORD_LIMIT && ay < RCL_JOY_COORD_LIMIT)) return 0;
    if (!(bx > -RCL_JOY_COORD_LIMIT && bx < RCL_JOY_COORD_LIMIT)) return 0;
    if (!(by > -RCL_JOY_COORD_LIMIT && by < RCL_JOY_COORD_LIMIT)) return 0;
    if (ax == 0.0f && ay == 0.0f && bx == 0.0f && by == 0.0f) return 0;
    if (drag != 0 && drag != 1) return 0;

    return 1;
}

static void rcl_joy_dump(const char *tag, int idx, uintptr_t obj, int deep) {
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

    if (!obj || !RCL_JOY_SCAN_ON) return;
    if (!deep) return;

    if (!rcl_read_float(obj + (uintptr_t)RCL_BS_AX, &ax)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_BS_AY, &ay)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_BS_BX, &bx)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_BS_BY, &by)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_JOY_ALT_CUR_X, &cx)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_JOY_ALT_CUR_Y, &cy)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_JOY_ALT_CEN_X, &ex)) return;
    if (!rcl_read_float(obj + (uintptr_t)RCL_JOY_ALT_CEN_Y, &ey)) return;

    rcl_read_int(obj + (uintptr_t)RCL_BS_MODE, &draga);
    rcl_read_int(obj + (uintptr_t)RCL_JOY_ALT_DRAG, &dragb);

    joya = rcl_joy_pair_ok(ax, ay, bx, by, draga & 0xFF);
    joyb = rcl_joy_pair_ok(cx, cy, ex, ey, dragb & 0xFF);

}

static void rcl_move_probe(const char *tag, int idx, uintptr_t obj, float ox, float oy) {
    uintptr_t vt = 0;
    int32_t ix = 0;
    int32_t iy = 0;
    int32_t key = 0;
    int32_t arm = 0;
    int near = 0;
    int pair = 0;

    if (!obj) return;

    near = rcl_move_near_own(obj, ox, oy, &ix, &iy);
    pair = rcl_move_pair_ok(obj, NULL, NULL);

    rcl_read_int(obj + RCL_MOVE_KEY_OFF, &key);
    rcl_read_int(obj + RCL_MOVE_ARM_OFF, &arm);

    rcl_move_read_vt(obj, &vt);

}

void rcl_move_locate(float ox, float oy) {
    uintptr_t own = rcl_own_obj();
    uintptr_t scene = rcl_client();
    uintptr_t seed[RCL_MOVE_MAX];
    uintptr_t seen[RCL_MOVE_MAX * 4];
    int seedN = 0;
    int seenN = 0;
    int i = 0;
    int k = 0;
    int hop = 0;
    int kidx = 0;

    if (rcl_move_probe_count > 0) return;

    if (rcl_ticks_a < RCL_MOVE_PROBE_TICK) return;

    rcl_move_probe_count = 1;

    seed[seedN++] = own;
    seed[seedN++] = scene;
    seed[seedN++] = rcl_scene_object;
    seed[seedN++] = rcl_joystick;

    if (scene) {
        uintptr_t hopped = 0;

        if (rcl_read_ptr(scene + RCL_MGR_OFF, (void **)&hopped) && hopped) seed[seedN++] = hopped;
    }

    for (i = 0; i < RCL_SLOT_COUNT; i++) {
        if (seedN >= RCL_MOVE_MAX - 1) break;
        if (rcl_slot_object[i]) seed[seedN++] = rcl_slot_object[i];
        if (rcl_slot_arg[i] && seedN < RCL_MOVE_MAX - 1) seed[seedN++] = rcl_slot_arg[i];
    }

    for (i = 0; i < seedN; i++) {
        rcl_move_probe("seed", i, seed[i], ox, oy);
        rcl_joy_dump("seed", i, seed[i], 1);
        seen[seenN++] = seed[i];
    }

    for (hop = 0; hop < RCL_MOVE_HOPS; hop++) {
        int limit = seenN;

        for (i = 0; i < limit && kidx < RCL_MOVE_MAX; i++) {
            uintptr_t base = seen[i];
            uintptr_t off = 0;

            if (!base) continue;

            for (off = 8; off <= RCL_MOVE_SCAN_END; off += 8) {
                uintptr_t kid = 0;
                int dup = 0;
                int j = 0;

                if (!rcl_read_ptr(base + off, (void **)&kid)) continue;
                if (kid < RCL_HEAP_MIN || kid > RCL_HEAP_MAX) continue;
                if ((kid & 7) != 0) continue;
                if (kid >= rcl_base && kid <= rcl_base + RCL_IMAGE_SPAN) continue;

                for (j = 0; j < seenN; j++) {
                    if (seen[j] == kid) {
                        dup = 1;

                        break;
                    }
                }

                if (dup) continue;
                if (seenN >= RCL_MOVE_MAX * 4) break;

                seen[seenN++] = kid;

                rcl_move_probe(hop == 0 ? "hop1" : "hop2", kidx, kid, ox, oy);
                rcl_joy_dump("hop1", kidx, kid, RCL_JOY_DEEP);

                kidx++;

                if (kidx >= RCL_MOVE_MAX) break;
            }
        }
    }
}

uintptr_t rcl_move_stick = 0;

uintptr_t rcl_move_carrier(void) {
    uintptr_t bs = rcl_bs();
    uintptr_t s = 0;
    uintptr_t r = 0;

    rcl_move_stick = 0;

    if (!bs) return 0;

    if (!rcl_read_ptr(bs + (uintptr_t)RCL_JOY_TARGET_OFF, (void **)&s) || !s) return 0;

    rcl_move_stick = s;

    r = rcl_hop(s, NULL);

    if (!r) return 0;

    return r;
}

int rcl_move_to(int32_t x, int32_t y, float ox, float oy) {
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

    rcl_move_locate(ox, oy);

    if (!RCL_MOVE_ON) return 0;
    if (x < -RCL_MOVE_COORD_LIMIT || x > RCL_MOVE_COORD_LIMIT) return 0;
    if (y < -RCL_MOVE_COORD_LIMIT || y > RCL_MOVE_COORD_LIMIT) return 0;

    fn = rcl_entry_2(RCL_MOVE_RVA);
    own = rcl_move_carrier();

    if (!fn || !own) {

        return 0;
    }

    if (!rcl_move_pair_ok(own, &pairX, &pairY)) {


        return 0;
    }


    rcl_read_int(own + RCL_MOVE_X_OFF, &rcl_move_before_x);
    rcl_read_int(own + RCL_MOVE_Y_OFF, &rcl_move_before_y);
    rcl_read_int(own + RCL_MOVE_KEY_OFF, &rcl_move_before_k);
    rcl_read_int(own + RCL_MOVE_ARM_OFF, &rcl_move_before_arm);

    ((void (*)(void *, int, int, int))fn)((void *)own, (int)x, (int)y, (int)RCL_MOVE_FLAG_10);

    rcl_read_int(own + RCL_MOVE_X_OFF, &rcl_move_after_x);
    rcl_read_int(own + RCL_MOVE_Y_OFF, &rcl_move_after_y);
    rcl_read_int(own + RCL_MOVE_KEY_OFF, &rcl_move_after_k);
    rcl_read_int(own + RCL_MOVE_ARM_OFF, &rcl_move_after_arm);

    if (rcl_move_after_x == x && rcl_move_after_y == y) rcl_move_ok = 1;

    rcl_read_byte(rcl_move_stick + 0xf78, &a78);
    rcl_read_byte(rcl_move_stick + 0xf7f, &a7f);
    rcl_read_byte(rcl_move_stick + 0xf80, &a80);
    rcl_read_byte(rcl_move_stick + 0xf9c, &a9c);
    rcl_read_byte(rcl_move_stick + 0xf9e, &a9e);
    rcl_read_int(rcl_move_stick + 0xfcc, &appX);
    rcl_read_int(rcl_move_stick + 0xfd0, &appY);


    return 1;
}









int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut) {
    uint64_t dt = 0;

    if (!p->elem || !p->hasPrev) return 0;

    dt = p->qtick - p->ptick;
    if (dt == 0 || dt > RCL_DT_MAX) dt = 1;

    *vxOut = (float)(p->x - p->px) / (float)dt;
    *vyOut = (float)(p->y - p->py) / (float)dt;

    return 1;
}

uintptr_t rcl_input_mgr(void) {
    void *mgr = NULL;

    if (!rcl_scene_object) return 0;
    if (!rcl_read_ptr(rcl_scene_object + RCL_MODE_INPUTMGR_OFF, &mgr) || !mgr) return 0;
    if (!rcl_heap_contains((uintptr_t)mgr)) return 0;

    return (uintptr_t)mgr;
}

void rcl_input_release(void) {
    uintptr_t mgr = 0;
    int32_t held[3] = { 0, 0, 0 };
    int32_t zero[3] = { 0, 0, 0 };
    int engagedLast = rcl_engaged_frame;

    rcl_engaged_frame = 0;

    if (!RCL_INPUT_MGR) return;
    if (!rcl_wrote_input) return;
    if (engagedLast) return;

    mgr = rcl_input_mgr();

    if (!mgr) return;

    rcl_read_int(mgr + 0x4, &held[0]);
    rcl_read_int(mgr + 0x8, &held[1]);
    rcl_read_int(mgr + 0xc, &held[2]);

    rcl_wrote_input = 0;

    if (held[0] == 0 && held[1] == 0 && held[2] == 0) return;

    rcl_write_bytes(mgr + 0x4, &zero[0], sizeof(zero[0]));
    rcl_write_bytes(mgr + 0x8, &zero[1], sizeof(zero[1]));
    rcl_write_bytes(mgr + 0xc, &zero[2], sizeof(zero[2]));

}

uintptr_t rcl_joystick = 0;



int rcl_stick_hold = 0;

uint64_t rcl_stick_tick = 0;

int rcl_route_seeded = 0;

int32_t rcl_last_own_x = 0;

int32_t rcl_last_own_y = 0;



int rcl_accepted = 0;












static int rcl_interp(int32_t *x, int32_t *y) {
    uintptr_t client = rcl_client();
    int32_t cx = 0;
    int32_t cy = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (!client) return 0;
    if (!rcl_read_int(client + RCL_CLIENT_POS_X_OFF, &cx)) return 0;
    if (!rcl_read_int(client + RCL_CLIENT_POS_Y_OFF, &cy)) return 0;

    if (x) *x = cx;
    if (y) *y = cy;

    return 1;
}

int rcl_witness(int32_t *x, int32_t *y) {
    int32_t wx = 0;
    int32_t wy = 0;

    if (x) *x = 0;
    if (y) *y = 0;

    if (!rcl_interp(&wx, &wy)) return 0;

    if (x) *x = wx;
    if (y) *y = wy;

    return 1;
}
