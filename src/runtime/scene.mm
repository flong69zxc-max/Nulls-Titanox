#include "titanox.h"

void tnx_run_workload(void) {

    tnx_tick_begin("pre-locate");

    tnx_phase("locate");

    tnx_locate_battle_mode();

    tnx_tick_begin("post-locate");

    if (t_scene_object) {
        if (!t_snapshot_first) {
            t_snapshot_first = YES;
            t_snapshot_start = CFAbsoluteTimeGetCurrent();
        } else if (!t_snapshot_second) {
            if (CFAbsoluteTimeGetCurrent() > (t_snapshot_start + TNX_SNAPSHOT_DELAY)) {
                t_snapshot_second = YES;
            }
        }
    }

    tnx_phase("autododge");
    tnx_run_autododge(0);
    tnx_phase("autoaim");
    tnx_run_autoaim();
    tnx_phase("watermark");
    tnx_render_watermark();
    tnx_phase("overlay");
    tnx_overlay_update();

    tnx_phase("tick-end");
}

uintptr_t tnx_battle_global(void) {
    return (uintptr_t)tnx_read_global_ptr(TNX_BATTLE_RVA);
}

void tnx_chain(void) {
    static int done = 0;
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t battle = tnx_battle_global();
    void *holder = NULL;
    uintptr_t own = 0;
    uintptr_t slotOwn = 0;
    int32_t slotGid = 0;
    void *slot = NULL;
    int32_t rawX = 0;
    int32_t rawY = 0;
    int32_t ownX = 0;
    int32_t ownY = 0;
    int rawOk = 0;
    int ownOk = 0;
    int inHop0 = -1;
    int inHop1 = -1;
    void *hop0 = NULL;
    void *hop1 = NULL;

    if (done) return;
    if (!scene) return;

    done = 1;

    if (tnx_read_ptr(scene + TNX_OWN_OFF, &slot) && slot) {
        if (!tnx_read_ptr((uintptr_t)slot + TNX_OWN_INNER_OFF, &holder)) holder = 0;
    }

    own = tnx_own_obj();

    tnx_own_from_slot(&slotOwn, &slotGid);

    rawOk = tnx_read_i32(scene + TNX_CTRL_RAW_X_OFF, &rawX) &&
            tnx_read_i32(scene + TNX_CTRL_RAW_Y_OFF, &rawY);
    ownOk = own && tnx_read_i32(own + TNX_INPUT_X_OFF, &ownX) &&
            tnx_read_i32(own + TNX_INPUT_Y_OFF, &ownY);

    tnx_logf("ownchain scene=%p [scene+%#llx]=%p +%#llx=%p %s=%p same=%d "
             "battleGlobal=[%#llx]=%p | slotOwn=%p slotIdx=%d slotGid=%d expect=%d | "
             "raw+%#llx ok=%d raw=(%d,%d) slotOk=%d own+%#llx/%#llx ok=%d own=(%d,%d) | "
             "scene=[manager+%#llx] manager=[%#llx] getBattleTail=%#llx managerGetter=%#llx - the scene "
             "was built by the engine as [manager+%#llx] where the manager comes from the global %#llx, "
             "and the same object is what its constructor caches into %#llx and what the input "
             "dispatch reads back at %#llx, so same=1 means the pair at scene+%#llx is the very input "
             "the battle update clamps and the write is aimed at the right object; the slot element is "
             "the engine's own index into hop0 and the only name of own that is not a guess",
             (void *)scene, (unsigned long long)TNX_OWN_OFF, slot,
             (unsigned long long)TNX_OWN_INNER_OFF, holder,
             ((uintptr_t)holder == own) ? "holder" : "own", (void *)own, (own == scene) ? 1 : 0,
             (unsigned long long)TNX_BATTLE_RVA, (void *)battle,
             (void *)slotOwn, t_own_slot_idx, slotGid, TNX_OWN_EXPECT_GID,
             (unsigned long long)TNX_CTRL_RAW_X_OFF, rawOk, rawX, rawY, t_own_slot_ok,
             (unsigned long long)TNX_INPUT_X_OFF, (unsigned long long)TNX_INPUT_Y_OFF, ownOk,
             ownX, ownY, (unsigned long long)TNX_SCENE_OFF,
             (unsigned long long)TNX_STATE_RVA, (unsigned long long)0x8ce9d8ULL,
             (unsigned long long)0x8cdfd4ULL, (unsigned long long)TNX_SCENE_OFF,
             (unsigned long long)TNX_STATE_RVA, (unsigned long long)TNX_BATTLE_RVA,
             (unsigned long long)0x7afba8ULL, (unsigned long long)TNX_CTRL_RAW_X_OFF);

    if (tnx_read_ptr(scene + TNX_CLIENT_OFF, &hop0) && hop0) {
        inHop0 = tnx_container_has((uintptr_t)hop0, own);

        if (tnx_read_ptr((uintptr_t)hop0 + TNX_CLIENT_OFF, &hop1) && hop1) {
            inHop1 = tnx_container_has((uintptr_t)hop1, own);
        }
    }

    tnx_logf("ownchain2 own=%p inHop0=%d inHop1=%d slotOwn=%p slotGid=%d - inHop is the slot the "
             "own pointer occupies in each hop list, and -1 means the list does not contain it at all, "
             "which is the case a coordinate list falls into and the reason own has to be named by the "
             "slot element instead", (void *)own, inHop0, inHop1, (void *)slotOwn, slotGid);
}

int tnx_pair(uintptr_t obj, int32_t *x, int32_t *y) {
    if (x) *x = 0;
    if (y) *y = 0;
    if (!obj) return 0;
    if (!tnx_read_i32(obj + TNX_CLIENT_POS_X_OFF, x)) return 0;
    if (!tnx_read_i32(obj + TNX_CLIENT_POS_Y_OFF, y)) return 0;

    return 1;
}

int tnx_src(uintptr_t off, int32_t *x, int32_t *y, int *flag) {
    void *o = NULL;
    uint8_t b = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (flag) *flag = -1;
    if (!t_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)t_scene_object + off, &o) || !o) return 0;
    if (flag && tnx_read_u8((uintptr_t)o + TNX_GATE_BYTE_OFF, &b)) *flag = (int)b;

    return tnx_pair((uintptr_t)o, x, y);
}

int tnx_weq(int32_t a, int32_t b, int32_t out, int32_t d) {
    if (d == 0) return -1;

    return (int)(((int64_t)(out - b) * 1000) / (int64_t)d);
}

uintptr_t tnx_mode_ptr(uintptr_t off) {
    void *o = NULL;

    if (!t_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)t_scene_object + off, &o)) return 0;

    return (uintptr_t)o;
}
