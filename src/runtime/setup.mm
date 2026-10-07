#include "recoil.h"

void rcl_run_autododge(int from_update) {
    if (rcl_in_drive) {

        return;
    }

    if (!RCL_DRIVE_FROM_UPDATE && from_update) {

        return;
    }

    rcl_in_drive = 1;
    rcl_time = rcl_us();
    rcl_autododge();
    rcl_in_drive = 0;
}

void rcl_run_autoaim(void) {
    if (!rcl_addr_getinstance || !rcl_addr_getownchar || !rcl_addr_battlescreen) return;

    void *battleMode = ((fn_get_inst_t)rcl_addr_getinstance)();
    if (!rcl_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)rcl_addr_getownchar)(battleMode);
    if (!rcl_object_plausible(ownChar)) return;

    int ownX = rcl_addr_getx ? ((fn_get_coord_t)rcl_addr_getx)(ownChar) : 0;
    int ownY = rcl_addr_gety ? ((fn_get_coord_t)rcl_addr_gety)(ownChar) : 0;
    int ownTeam = rcl_addr_getteam ? ((fn_get_team_t)rcl_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!rcl_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!rcl_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!rcl_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!rcl_read_int((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0) return;

    if (count > SCAN_MAX) count = SCAN_MAX;
    void *probe = NULL;

    if (!rcl_read_ptr((uintptr_t)objects, &probe)) return;
    if (count > 1 && !rcl_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return;

    float closestDistSq = 1.0e18f;
    int targetX = 0;
    int targetY = 0;
    BOOL found = NO;

    for (int i = 0; i < count; i++) {
        void *obj = objects[i];

        if (!obj || obj == ownChar) continue;
        if (!rcl_object_plausible(obj)) continue;

        uint8_t objDead = 0;
        if (!rcl_read_byte((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!rcl_read_int((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = rcl_addr_getx ? ((fn_get_coord_t)rcl_addr_getx)(obj) : 0;
        int ey = rcl_addr_gety ? ((fn_get_coord_t)rcl_addr_gety)(obj) : 0;

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
    if (!rcl_read_ptr(rcl_addr_battlescreen, &screen)) return;

    if (!rcl_object_plausible(screen)) {
        if (!rcl_aim_rejected) {
            rcl_aim_rejected = YES;
        }
        return;
    }

    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;

    if (!rcl_addr_writable(fireX, 4) || !rcl_addr_writable(fireY, 4)) {
        if (!rcl_aim_rejected) {
            rcl_aim_rejected = YES;
        }
        return;
    }

    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}

void setup(void) {
    if (rcl_setup_done) return;
    rcl_setup_done = YES;


    rcl_load_function_starts();

    rcl_resolve_addresses();

    rcl_objc_arm("MetalView", "render");
    rcl_objc_arm("NullView", "render");

    rcl_slot_hooks_install();

    int buildControls = 0;

    for (int i = 0; i < RCL_SLOT_COUNT; i++) {
        if (rcl_slot_specs[i].control) buildControls++;
    }




    rcl_start_timer();

}

__attribute__((constructor))
void start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        poll_for_game(0);
    });
}
