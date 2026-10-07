#include "../recoil.h"

#if RCL_CI_HASH_INNER_MASK_RVA && RCL_CI_HASH_OUTER_MASK_RVA && RCL_BM_HASH_ENABLED_OFF && RCL_BM_HASH_KEY_OFF
#define RCL_CI_SIGNING_ON 1
#else
#define RCL_CI_SIGNING_ON 0
#endif




int rcl_qguard_probe = 0;
int rcl_qguard_skip = 0;

static uint32_t rcl_ci_table[RCL_CI_TABLE_TYPES];

static uint8_t rcl_ci_inner[RCL_CI_HASH_MASK_SIZE];

static uint8_t rcl_ci_outer[RCL_CI_HASH_MASK_SIZE];

static int rcl_ci_ready = 0;

int rcl_ci_load_constants(void) {
    int i = 0;

    if (rcl_ci_ready) return 1;
    if (!rcl_base) return 0;

    for (i = 0; i < (int)RCL_CI_TABLE_TYPES; i++) {
        if (!rcl_read_bytes(rcl_base + RCL_CI_TYPE_TABLE_RVA + (uintptr_t)i * 4ULL,
                            &rcl_ci_table[i], sizeof(uint32_t))) {
            return 0;
        }
    }

    if (!rcl_read_bytes(rcl_base + RCL_CI_HASH_INNER_MASK_RVA, rcl_ci_inner, RCL_CI_HASH_MASK_SIZE)) return 0;
    if (!rcl_read_bytes(rcl_base + RCL_CI_HASH_OUTER_MASK_RVA, rcl_ci_outer, RCL_CI_HASH_MASK_SIZE)) return 0;

    rcl_ci_ready = 1;

    return 1;
}

uint32_t rcl_ci_sign(void *ci, void *battle) {
#if RCL_CI_SIGNING_ON
    uint8_t key[RCL_CI_HASH_MASK_SIZE];
    uint8_t cmd[RCL_CI_TOKEN_READ_LEN];
    uint8_t enabled = 0;
    uint32_t token = 0;

    if (!ci || !battle) return 0;
    if (!rcl_read_bytes((uintptr_t)battle + RCL_BM_HASH_ENABLED_OFF, &enabled, 1)) return 0;
    if (enabled == 0) return 0;
    if (!rcl_ci_load_constants()) return 0;
    if (!rcl_read_bytes((uintptr_t)battle + RCL_BM_HASH_KEY_OFF, key, RCL_CI_HASH_MASK_SIZE)) return 0;
    if (!rcl_read_bytes((uintptr_t)ci + RCL_CI_TOKEN_READ_OFF, cmd, RCL_CI_TOKEN_READ_LEN)) return 0;

    token = rcl_ci_compute_token(key, cmd, rcl_ci_table, rcl_ci_inner, rcl_ci_outer);

    if (!rcl_write_bytes((uintptr_t)ci + RCL_CI_TOKEN_OFF, &token, sizeof(token))) {

        return 0;
    }


    return token;
#else
    (void)ci;
    (void)battle;

    return 0;
#endif
}


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


        if (battleFn) {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) rcl_ci_sign(msg, battle);
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
        if ((uint64_t)(rcl_q_after > 0 ? rcl_q_after : 0) > rcl_q_max) {
            rcl_q_max = (uint64_t)rcl_q_after;
        }
    }



    return 1;
}

int rcl_enqueue(int x, int y) {
    return rcl_enqueue_type(x, y, (int)RCL_TYPE_MOVE);
}

