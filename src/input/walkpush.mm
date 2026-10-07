#include "titanox.h"

uintptr_t t_walk_ent_4 = 0;

uint64_t t_walk_scans_4 = 0;

uint64_t t_walk_sends_4 = 0;

uint64_t t_walk_near_4 = 0;

static uint64_t t_walk_logs_4 = 0;

static uintptr_t t_walk_fn_4 = 0;

static int32_t t_walk_dir_4[2] = { 0, 0 };

static int32_t t_walk_goal_4[2] = { 0, 0 };

uintptr_t tnx_walk_mgr_4(void) {
    uintptr_t bs = tnx_bs();
    uintptr_t mgr = 0;

    if (!bs) return 0;
    if (!tnx_read_ptr(bs + (uintptr_t)TNX_JOY_TARGET_OFF, (void **)&mgr) || !mgr) return 0;

    return mgr;
}

int tnx_walk_push_4(int on, int32_t px, int32_t py, int32_t tx, int32_t ty) {
    uintptr_t mgr = 0;
    uintptr_t ent = t_walk_ent_4;
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
    int wrote = 0;
    int sent = 0;

    if (!TNX_WALK_PUSH_4) return 0;

    mgr = tnx_walk_mgr_4();

    if (!mgr) return 0;
    if (!ent) return 0;

    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_X_OFF, &ox)) return 0;
    if (!tnx_read_i32(ent + (uintptr_t)TNX_OBJ_Y_OFF, &oy)) return 0;
    if (!tnx_read_i32(ent + 0x24c, &span)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &rawX)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &rawY)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &appX)) return 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &appY)) return 0;

    if (ox - px > 250 || px - ox > 250) return 0;
    if (oy - py > 250 || py - oy > 250) return 0;

    if (!on) {
        if (rawX != 0 || rawY != 0) {
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &backX, sizeof(backX));
            tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &backY, sizeof(backY));

            wrote = 1;
        }

        if (t_walk_logs_4 < TNX_WALK_PUSH_LOGS_4) {
            t_walk_logs_4++;

            TNX_LOGX("walkpush off n=%llu mgr=%p ent=%p own=(%d,%d) raw=%d,%d wrote=%d scans=%llu sends=%llu "
                     "near=%llu - no walk this frame, the raw pair goes back to zero and nothing else is touched",
                     (unsigned long long)t_walk_logs_4, (void *)mgr, (void *)ent, ox, oy, rawX, rawY, wrote,
                     (unsigned long long)t_walk_scans_4, (unsigned long long)t_walk_sends_4,
                     (unsigned long long)t_walk_near_4);
        }

        return 0;
    }

    dx = (float)(tx - ox);
    dy = (float)(ty - oy);
    len = __builtin_sqrtf(dx * dx + dy * dy);

    if (len < 1.0f) return 0;

    dx /= len;
    dy /= len;

    dirX = (int32_t)(dx * TNX_WALK_PUSH_RAW_4);
    dirY = (int32_t)(dy * TNX_WALK_PUSH_RAW_4);

    if (dirX == 0 && dirY == 0) return 0;

    rad = (float)(span / 5);

    if (rad < 1.0f) return 0;

    goalX = ox + (int32_t)(dx * rad);
    goalY = oy + (int32_t)(dy * rad);

    jump = (int64_t)(goalX - appX) * (int64_t)(goalX - appX)
         + (int64_t)(goalY - appY) * (int64_t)(goalY - appY);

    t_walk_dir_4[0] = dirX;
    t_walk_dir_4[1] = dirY;
    t_walk_goal_4[0] = goalX;
    t_walk_goal_4[1] = goalY;

    tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_X_OFF, &dirX, sizeof(dirX));
    tnx_write_bytes(mgr + (uintptr_t)TNX_CTRL_RAW_Y_OFF, &dirY, sizeof(dirY));

    wrote = 1;

    t_walk_scans_4++;

    if (jump < (int64_t)TNX_WALK_PUSH_MIN_JUMP_4 || rad < 60.0f || rad > 1500.0f) {
        t_walk_near_4++;
    } else {
        fn = t_walk_fn_4;

        if (!fn) {
            fn = tnx_entry_2(RVA_INPUT_COMMIT_4);

            if (!fn && t_base) fn = t_base + RVA_INPUT_COMMIT_4;

            t_walk_fn_4 = fn;
        }

        if (fn) {
            ((void (*)(void *, void *, void *, int))fn)((void *)mgr, (void *)ent, (void *)ent, 1);

            sent = 1;

            t_walk_sends_4++;
        }
    }

    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_X_OFF, &appX)) appX = 0;
    if (!tnx_read_i32(mgr + (uintptr_t)TNX_CTRL_APPLIED_Y_OFF, &appY)) appY = 0;

    if (t_walk_logs_4 < TNX_WALK_PUSH_LOGS_4) {
        t_walk_logs_4++;

        TNX_LOGX("walkpush n=%llu mgr=%p ent=%p own=(%d,%d) want=(%d,%d) dir=(%d,%d) span=%d goal=(%d,%d) "
                 "applied=(%d,%d) jump=%lld sent=%d wrote=%d fn=%p scans=%llu sends=%llu near=%llu - the engine "
                 "takes the walk direction from the raw pair and rebuilds the target from it, so the pair carries "
                 "the same numbers the native touch writes and the visible knob pair stays untouched",
                 (unsigned long long)t_walk_logs_4, (void *)mgr, (void *)ent, ox, oy, tx, ty,
                 t_walk_dir_4[0], t_walk_dir_4[1], span, t_walk_goal_4[0], t_walk_goal_4[1], appX, appY,
                 (long long)jump, sent, wrote, (void *)fn,
                 (unsigned long long)t_walk_scans_4, (unsigned long long)t_walk_sends_4,
                 (unsigned long long)t_walk_near_4);
    }

    return sent;
}
