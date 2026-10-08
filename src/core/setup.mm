#include "../recoil.h"

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

void rcl_run_autododge(int from_update) {
    if (!rcl_flag_state("autododge")) return;

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

static void rcl_objc_body(void) {
    if (rcl_inside_hook) return;

    rcl_inside_hook = YES;
    rcl_run_workload();
    rcl_inside_hook = NO;
}

void setup(void) {
    if (rcl_setup_done) return;
    rcl_setup_done = YES;

    rcl_log_set_enabled(RCL_LOGS_ON);
    rcl_flag_set("logs", RCL_LOGS_ON);
    rcl_log_info("setup base=%#llx", (unsigned long long)rcl_base);

    rcl_load_function_starts();

    rcl_resolve_addresses();

    rcl_objc_arm(rcl_base, "MetalView", "render", rcl_objc_body);
    rcl_objc_arm(rcl_base, "NullView", "render", rcl_objc_body);

    rcl_feature_setup("slot hooks", rcl_slot_hooks_install);

    rcl_start_timer();

}

__attribute__((constructor))
void start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        poll_for_game(0);
    });
}
