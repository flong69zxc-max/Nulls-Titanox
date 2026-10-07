#include "../../recoil.h"

void rcl_run_workload(void) {

    rcl_tick_begin();


    rcl_locate_battle_mode();

    rcl_tick_begin();

    if (rcl_scene_object) {
        if (!rcl_snapshot_first) {
            rcl_snapshot_first = YES;
            rcl_snapshot_start = CFAbsoluteTimeGetCurrent();
        } else if (!rcl_snapshot_second) {
            if (CFAbsoluteTimeGetCurrent() > (rcl_snapshot_start + RCL_SNAPSHOT_DELAY)) {
                rcl_snapshot_second = YES;
            }
        }
    }

    rcl_run_autododge(0);
    rcl_run_autoaim();

}