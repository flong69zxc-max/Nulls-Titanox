#include "../recoil.h"

#if RCL_CI_HASH_INNER_MASK_RVA && RCL_CI_HASH_OUTER_MASK_RVA && RCL_BM_HASH_ENABLED_OFF &&         \
    RCL_BM_HASH_KEY_OFF
#define RCL_CI_SIGNING_ON 1
#else
#define RCL_CI_SIGNING_ON 0
#endif

int rcl_seq_before = -1;
int rcl_seq_after = -1;
int rcl_q_after = -1;

int rcl_qguard_probe = 0;
int rcl_qguard_skip = 0;

static uint32_t rcl_ci_table[RCL_CI_TABLE_TYPES];

static uint8_t rcl_ci_inner[RCL_CI_HASH_MASK_SIZE];

static uint8_t rcl_ci_outer[RCL_CI_HASH_MASK_SIZE];

static int rcl_ci_ready = 0;

int rcl_ci_load_constants(void)
{
    int i = 0;

    if (rcl_ci_ready) return 1;
    if (!rcl_base) return 0;

    for (i = 0; i < (int)RCL_CI_TABLE_TYPES; i++)
    {
        if (!rcl_read_bytes(rcl_base + RCL_CI_TYPE_TABLE_RVA + (uintptr_t)i * 4ULL,
                            &rcl_ci_table[i], sizeof(uint32_t)))
        {
            return 0;
        }
    }

    if (!rcl_read_bytes(rcl_base + RCL_CI_HASH_INNER_MASK_RVA, rcl_ci_inner, RCL_CI_HASH_MASK_SIZE))
        return 0;
    if (!rcl_read_bytes(rcl_base + RCL_CI_HASH_OUTER_MASK_RVA, rcl_ci_outer, RCL_CI_HASH_MASK_SIZE))
        return 0;

    rcl_ci_ready = 1;

    return 1;
}

uint32_t rcl_ci_sign(void *ci, void *battle)
{
#if RCL_CI_SIGNING_ON
    uint8_t key[RCL_CI_HASH_MASK_SIZE];
    uint8_t cmd[RCL_CI_TOKEN_READ_LEN];
    uint8_t enabled = 0;
    uint32_t token = 0;

    if (!ci || !battle) return 0;
    if (!rcl_read_bytes((uintptr_t)battle + RCL_BM_HASH_ENABLED_OFF, &enabled, 1)) return 0;
    if (enabled == 0) return 0;
    if (!rcl_ci_load_constants()) return 0;
    if (!rcl_read_bytes((uintptr_t)battle + RCL_BM_HASH_KEY_OFF, key, RCL_CI_HASH_MASK_SIZE))
        return 0;
    if (!rcl_read_bytes((uintptr_t)ci + RCL_CI_TOKEN_READ_OFF, cmd, RCL_CI_TOKEN_READ_LEN))
        return 0;

    token = rcl_ci_compute_token(key, cmd, rcl_ci_table, rcl_ci_inner, rcl_ci_outer);

    if (!rcl_write_bytes((uintptr_t)ci + RCL_CI_TOKEN_OFF, &token, sizeof(token)))
    {

        return 0;
    }

    return token;
#else
    (void)ci;
    (void)battle;

    return 0;
#endif
}

int rcl_enqueue_type(int x, int y, int type)
{
    if (!rcl_coord_ok)
    {

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

    if (!inputFn)
    {

        return 0;
    }

    msg = rcl_msg_alloc();

    if (!msg)
    {

        return 0;
    }

    memset(msg, 0, (size_t)RCL_MSG_SIZE);

    if (ctorFn) ((void (*)(void *, int))ctorFn)(msg, RCL_TYPE_MOVE);

    rcl_write_bytes((uintptr_t)msg + RCL_TYPE_OFF, &type, sizeof(type));
    rcl_write_bytes((uintptr_t)msg + RCL_X_OFF, &vx, sizeof(vx));
    rcl_write_bytes((uintptr_t)msg + RCL_Y_OFF, &vy, sizeof(vy));

    if (RCL_QUEUE_GUARD && rcl_qguard_probe < 1)
    {
        void *mvt = NULL;
        int32_t back = 0;

        rcl_qguard_probe++;

        rcl_read_ptr((uintptr_t)msg, &mvt);
        rcl_read_int((uintptr_t)msg + RCL_TYPE_OFF, &back);
    }

    {
        uintptr_t battleFn = rcl_entry_2(RCL_GETBATTLE_RVA);

        if (battleFn)
        {
            void *battle = ((void *(*)(void))battleFn)();

            if (battle) rcl_ci_sign(msg, battle);
        }
    }

    if (type == (int)RCL_TYPE_MOVE) (void)rcl_pred_set(x, y);

    mgr = rcl_manager();

    if (!mgr)
    {

        return 0;
    }

    rcl_read_int((uintptr_t)mgr + RCL_MGR_SEQ_OFF, &rcl_seq_before);

    {
        void *mgrInner = NULL;

        if (!rcl_read_ptr((uintptr_t)mgr + RCL_CI_MGR_QUEUE_OFF, &mgrInner) || !mgrInner)
        {

            return 0;
        }
    }

    if (RCL_QUEUE_GUARD || RCL_QUEUE_GUARD_MGR)
    {
        int msgOk = rcl_instance_shaped((uintptr_t)msg);
        int mgrOk = rcl_manager_shape((uintptr_t)mgr);

        if ((RCL_QUEUE_GUARD && !msgOk) || (RCL_QUEUE_GUARD_MGR && !mgrOk))
        {
            if (rcl_qguard_skip < RCL_QGUARD_LOGS)
            {
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
    if (RCL_QUEUE)
    {
        if ((uint64_t)(rcl_q_after > 0 ? rcl_q_after : 0) > rcl_q_max)
        {
            rcl_q_max = (uint64_t)rcl_q_after;
        }
    }

    return 1;
}

int rcl_enqueue(int x, int y)
{
    return rcl_enqueue_type(x, y, (int)RCL_TYPE_MOVE);
}

static int rcl_pred_probe(uintptr_t pred, int *alignOut, int *readOut, int *writeOut, int *vtOut)
{
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

static int rcl_pred_ok(uintptr_t pred)
{
    return rcl_pred_probe(pred, NULL, NULL, NULL, NULL);
}

static int rcl_move_pair_ok(uintptr_t obj, int32_t *outX, int32_t *outY)
{
    int32_t ix = 0;
    int32_t iy = 0;

    if (!obj) return 0;
    if (!rcl_read_int(obj + RCL_MOVE_X_OFF, &ix)) return 0;
    if (!rcl_read_int(obj + RCL_MOVE_Y_OFF, &iy)) return 0;

    if (ix < -RCL_MOVE_COORD_LIMIT || ix > RCL_MOVE_COORD_LIMIT) return 0;
    if (iy < -RCL_MOVE_COORD_LIMIT || iy > RCL_MOVE_COORD_LIMIT) return 0;

    if (outX) *outX = ix;
    if (outY) *outY = iy;

    return 1;
}

static int rcl_move_obj_ok(uintptr_t obj)
{
    if (!obj) return 0;
    if (!rcl_instance_shaped(obj)) return 0;
    if (!rcl_move_pair_ok(obj, NULL, NULL)) return 0;

    return 1;
}

static uintptr_t rcl_move_carrier(void)
{
    uintptr_t ctrl = rcl_controller();
    uintptr_t mover = 0;
    void *mgr = NULL;

    if (ctrl)
    {
        mover = rcl_hop(ctrl, NULL);

        if (mover && rcl_pointer_plausible(mover)) return mover;

        if (rcl_read_ptr(ctrl + (uintptr_t)RCL_MGR_OFF, &mgr) && mgr)
        {
            mover = rcl_hop((uintptr_t)mgr, NULL);

            if (rcl_move_obj_ok(mover)) return mover;
        }

        if (rcl_move_obj_ok(ctrl)) return ctrl;
    }

    if (rcl_scene_object)
    {
        mover = rcl_hop(rcl_scene_object, NULL);

        if (rcl_move_obj_ok(mover)) return mover;

        if (rcl_move_obj_ok(rcl_scene_object)) return rcl_scene_object;
    }

    return 0;
}

uintptr_t rcl_entry_2(uintptr_t rva)
{
    if (!rcl_base || !rva) return 0;
    if (!rcl_callable(rva)) return 0;

    return rcl_base + rva;
}

void *rcl_msg_alloc(void)
{
    uintptr_t stub = rcl_entry_2(RCL_ALLOC_RVA);
    uintptr_t got = 0;

    if (stub)
    {
        return ((void *(*)(size_t))stub)((size_t)RCL_MSG_SIZE);
    }

    if (rcl_base && rcl_read_ptr(rcl_base + RCL_ALLOC_GOT_RVA, (void **)&got) && got)
    {
        return ((void *(*)(size_t))got)((size_t)RCL_MSG_SIZE);
    }

    return NULL;
}

void *rcl_manager(void)
{
    uintptr_t battleFn = rcl_entry_2(RCL_GETBATTLE_RVA);
    void *battle = NULL;
    void *mgr = NULL;

    if (!battleFn) return NULL;

    battle = ((void *(*)(void))battleFn)();

    if (!battle) return NULL;
    if (!rcl_read_ptr((uintptr_t)battle + RCL_MGR_OFF, &mgr) || !mgr) return NULL;

    return mgr;
}

int rcl_queue_count(uintptr_t *mgrOut)
{
    void *mgr = rcl_manager();
    void *queue = NULL;
    int32_t count = -1;

    if (mgrOut) *mgrOut = (uintptr_t)mgr;
    if (!mgr) return -1;
    if (!rcl_read_ptr((uintptr_t)mgr + RCL_QUEUE_OFF, &queue) || !queue) return -1;
    if (!rcl_read_int((uintptr_t)queue + RCL_QUEUE_COUNT_OFF, &count)) return -1;

    return (int)count;
}

int rcl_pred_set(int x, int y)
{
    uintptr_t setFn = 0;
    uintptr_t pred = 0;

    if (!RCL_PRED_SET) return 0;

    if (!rcl_coord_ok)
    {

        return 0;
    }

    setFn = rcl_entry_2(RCL_SETINPUT_RVA);

    if (!setFn) return 0;

    pred = rcl_hop(rcl_controller(), NULL);

    if (!rcl_pred_ok(pred))
    {
        return 0;
    }

    ((void (*)(uintptr_t, int, int, int))setFn)(pred, x, y, RCL_PRED_FLAG);

    return 1;
}

int rcl_move_to(int32_t x, int32_t y, float ox, float oy)
{
    uintptr_t fn = 0;
    uintptr_t own = 0;

    (void)ox;
    (void)oy;

    if (!RCL_MOVE_ON) return 0;
    if (x < -RCL_MOVE_COORD_LIMIT || x > RCL_MOVE_COORD_LIMIT) return 0;
    if (y < -RCL_MOVE_COORD_LIMIT || y > RCL_MOVE_COORD_LIMIT) return 0;

    fn = rcl_entry_2(RCL_MOVE_RVA);
    own = rcl_move_carrier();

    if (!fn || !own) return 0;

    if (!rcl_move_pair_ok(own, NULL, NULL)) return 0;

    ((void (*)(void *, int, int, int))fn)((void *)own, (int)x, (int)y, (int)RCL_MOVE_FLAG_10);

    return 1;
}

uintptr_t rcl_pred_last = 0;
