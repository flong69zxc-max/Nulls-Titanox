#include "titanox.h"

void tnx_run_workload(void) {

    tnx_tick_begin("pre-locate");


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

    tnx_run_autododge(0);
    tnx_run_autoaim();

}