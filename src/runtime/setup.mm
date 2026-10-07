#include "titanox.h"

void tnx_run_autododge(int from_update) {
    if (t_in_drive) {

        return;
    }

    if (!TNX_DRIVE_FROM_UPDATE && from_update) {

        return;
    }

    t_in_drive = 1;
    t_time = tnx_us();
    tnx_autododge();
    t_in_drive = 0;
}

void tnx_run_autoaim(void) {
    if (!t_addr_getinstance || !t_addr_getownchar || !t_addr_battlescreen) return;

    void *battleMode = ((fn_get_inst_t)t_addr_getinstance)();
    if (!tnx_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)t_addr_getownchar)(battleMode);
    if (!tnx_object_plausible(ownChar)) return;

    int ownX = t_addr_getx ? ((fn_get_coord_t)t_addr_getx)(ownChar) : 0;
    int ownY = t_addr_gety ? ((fn_get_coord_t)t_addr_gety)(ownChar) : 0;
    int ownTeam = t_addr_getteam ? ((fn_get_team_t)t_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!tnx_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!tnx_read_int((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0) return;

    if (count > SCAN_MAX) count = SCAN_MAX;
    void *probe = NULL;

    if (!tnx_read_ptr((uintptr_t)objects, &probe)) return;
    if (count > 1 && !tnx_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return;

    float closestDistSq = 1.0e18f;
    int targetX = 0;
    int targetY = 0;
    BOOL found = NO;

    for (int i = 0; i < count; i++) {
        void *obj = objects[i];

        if (!obj || obj == ownChar) continue;
        if (!tnx_object_plausible(obj)) continue;

        uint8_t objDead = 0;
        if (!tnx_read_byte((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!tnx_read_int((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = t_addr_getx ? ((fn_get_coord_t)t_addr_getx)(obj) : 0;
        int ey = t_addr_gety ? ((fn_get_coord_t)t_addr_gety)(obj) : 0;

        float dx = (float)(ex - ownX);
        float dy = (float)(ey - ownY);
        float distSq = dx * dx + dy * dy;

        if (distSq > 1.0f && distSq < closestDistSq) {
            closestDistSq = distSq;
            targetX = ex;
            targetY = ey;
            found = YES;
        }
    }

    if (!found) return;

    void *screen = NULL;
    if (!tnx_read_ptr(t_addr_battlescreen, &screen)) return;

    if (!tnx_object_plausible(screen)) {
        if (!t_aim_rejected) {
            t_aim_rejected = YES;
        }
        return;
    }

    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;

    if (!tnx_addr_writable(fireX, 4) || !tnx_addr_writable(fireY, 4)) {
        if (!t_aim_rejected) {
            t_aim_rejected = YES;
        }
        return;
    }

    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}

void setup(void) {
    if (t_setup_done) return;
    t_setup_done = YES;


    image_ref_t ref;
    ref.base = t_base;
    ref.hdr = (const struct mach_header_64 *)t_base;

    rt_dump_image(ref);

    tnx_load_function_starts();

    tnx_resolve_addresses();

    tnx_objc_arm("MetalView", "render");
    tnx_objc_arm("NullView", "render");

    tnx_slot_hooks_install();

    int buildControls = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (t_slot_specs[i].control) buildControls++;
    }




    tnx_start_timer();

}

__attribute__((constructor))
void start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        poll_for_game(0);
    });
}
