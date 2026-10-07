#include "recoil.h"

int rcl_vtable_is_data(uintptr_t vtable) {
    const char *segment = rcl_image_segment_name(vtable);

    if (!segment) return 0;
    if (strcmp(segment, "__DATA_CONST") == 0) return 1;
    if (strcmp(segment, "__DATA") == 0) return 1;

    return 0;
}

int rcl_state_tick(void) {
    uintptr_t slot = (uintptr_t)rcl_read_global_ptr(RCL_STATE_RVA);
    int32_t state = -1;
    void *value = NULL;
    uintptr_t scene = 0;
    uintptr_t client = 0;
    uintptr_t inner = 0;
    uintptr_t players = 0;
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    uintptr_t hopArray[RCL_HOPS] = { 0 };
    int32_t hopCount[RCL_HOPS] = { 0 };
    int32_t hopCap[RCL_HOPS] = { 0 };
    int hopOk[RCL_HOPS] = { 0 };
    int score[RCL_HOPS];
    int chosen = -1;

    if (slot) rcl_read_int(slot + RCL_STATE_ENUM_OFF, &state);

    if (slot != rcl_site || state != rcl_state_2) {
        rcl_state_note(state);

        rcl_site = slot;
        rcl_state_2 = state;

    }

    if (!slot) return 0;

    if (state != RCL_STATE_BATTLE) {

        return 0;
    }

    if (!rcl_read_ptr(slot + RCL_SCENE_OFF, &value) || !value) return 0;

    scene = (uintptr_t)value;

    if (scene != rcl_scene_object) {
        uintptr_t scenePrev = rcl_scene_object;

        rcl_scene_object = scene;


    }

    if (!rcl_read_ptr(scene + RCL_MODE_MANAGER_OFF, &value) || !value) {

        return 1;
    }

    client = (uintptr_t)value;

    if (!rcl_read_ptr(client + RCL_CLIENT_HOP_OFF, &value) || !value) {

        return 1;
    }

    inner = (uintptr_t)value;

    hopOk[0] = rcl_container_header(client, &hopArray[0], &hopCount[0], &hopCap[0]);
    hopOk[1] = rcl_container_header(inner, &hopArray[1], &hopCount[1], &hopCap[1]);

    score[0] = hopOk[0] ? rcl_container_score(client) : -1;
    score[1] = hopOk[1] ? rcl_container_score(inner) : -1;

    if (score[1] > score[0]) {
        chosen = 1;
        rcl_hop_sticky = 1;
    } else if (score[0] > score[1]) {
        chosen = 0;
        rcl_hop_sticky = 0;
    } else {
        chosen = hopOk[1] ? 1 : (hopOk[0] && !rcl_hop_sticky ? 0 : -1);
    }

    if (chosen != rcl_last_choice) {
        rcl_last_choice = chosen;

    } else if (rcl_hop_logs < 6) {
        rcl_hop_logs++;

    }


    if (scene != rcl_hop_scene) {
        rcl_hop_scene = scene;



    }

    if (RCL_WIRE_OWNER && rcl_owner) {
        void *directArray = NULL;
        int32_t directCount = 0;

        if (rcl_read_ptr(rcl_owner + RCL_MGR_ARRAY_OFF, &directArray) && directArray &&
            rcl_read_int(rcl_owner + RCL_MGR_COUNT_OFF, &directCount) && directCount > 0) {
            rcl_players_object = rcl_owner;
            rcl_players_array = (uintptr_t)directArray;
            rcl_players_count = directCount;
            rcl_hop_chosen = RCL_HOPCHOSEN_DIRECT;

            if (!rcl_wired) {
                rcl_wired = 1;

            }

            return 0;
        }
    }

    if (chosen < 0) {

        return 1;
    }

    players = (chosen == 1) ? inner : client;
    array = (void *)hopArray[chosen];
    count = hopCount[chosen];
    capacity = hopCap[chosen];

    rcl_hop_chosen = chosen;

    {
        static int v141_array_vote_logs = 0;

        if ((uintptr_t)array != rcl_pub_array && (uintptr_t)players == rcl_pub_object &&
            v141_array_vote_logs < RCL_ARRAY_VOTE_LOGS) {
            v141_array_vote_logs++;

        }
    }

    if ((uintptr_t)players != rcl_pub_object || (uintptr_t)array != rcl_pub_array ||
        count != rcl_pub_count) {
        rcl_publish((uintptr_t)players, (uintptr_t)array, count, capacity, "hop-adopt");


    }

    rcl_manager_count = count;

    if (count > 0 && count <= RCL_MANAGER_MAX_OBJECTS && capacity > 0 &&
        capacity <= RCL_MGR_CAP_MAX && array) {

    }

    return 1;
}

int rcl_scan_allowed(uint64_t fired, uint64_t total) {
    if (fired > 0) {

        rcl_idle_start = 0;
        rcl_idle_logged = 0;

        return 1;
    }

    if (rcl_idle_start == 0) rcl_idle_start = rcl_ticks_b;


    if (!rcl_idle_logged && (rcl_ticks_b - rcl_idle_start) >= RCL_IDLE_TICKS) {
        rcl_idle_logged = 1;

    }

    if ((rcl_ticks_b - rcl_idle_start) < RCL_IDLE_RETRY_TICKS) {

        return 0;
    }

    rcl_idle_start = rcl_ticks_b;

    return 1;
}

int rcl_battle_gate_2(int v63) {
    int liveEnough = (rcl_live_objs >= RCL_LIVE_OBJ_MIN &&
                      rcl_live_teams >= RCL_LIVE_TEAM_MIN);

    rcl_fb_on = (v63 || liveEnough) ? 1 : 0;

    if (!rcl_fb_on) {
        if (!rcl_bar_logged && rcl_ticks_b >= RCL_BAR_TICKS) {
            rcl_bar_logged = 1;

        }

        return 0;
    }

    if (v63) return 1;

    if (!rcl_fb_logged) {
        rcl_fb_logged = 1;

    }

    return 1;
}

void rcl_start_timer(void) {
    if (rcl_scan_timer) return;

    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    if (!timer) return;

    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);

    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval),
                              interval, (uint64_t)(0.25 * NSEC_PER_SEC));

    dispatch_source_set_event_handler(timer, ^{
        rcl_slot_pump();

        int scene = rcl_state_tick();
        int gate = rcl_battle_gate(scene);
        int battle = gate || scene;
        int fallback = rcl_battle_gate_2(battle);

        int ready = rcl_scan_ready(battle || fallback);
        int needScan = !scene && !rcl_players_object;

        if (needScan != rcl_scan_armed) {
            rcl_scan_armed = needScan;

        }

        if (needScan && ready &&
            rcl_scan_allowed((unsigned long long)rcl_object_dispatches(),
                                 rcl_hook_dispatches())) {
            rcl_locate_battle_mode();
        }

        rcl_modesig_tick();

        rcl_ticks_b++;

        if ((rcl_ticks_b % RCL_HB_TICKS) == 0) rcl_hb_sig_prev = rcl_modesig_hits;

    });

    dispatch_resume(timer);

    rcl_scan_timer = timer;


}

uint64_t rcl_ticks_b = 0;

int rcl_hb_sig_prev = 0;

int rcl_battle_active = 0;

int rcl_battle_last_tick = 0;

int rcl_battle_gate(int scene) {
    unsigned long long objFired = rcl_object_dispatches();
    int objGrew = objFired > rcl_obj_prev;
    int sigGrew = rcl_modesig_hits > rcl_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;

    rcl_obj_prev = objFired;

    if (sigGrew || objGrew || sceneGrew) {
        rcl_battle_last_tick = (int)rcl_ticks_b;

        if (!rcl_battle_active) {
            rcl_battle_active = 1;
        }
    } else if (rcl_battle_active &&
               ((int)rcl_ticks_b - rcl_battle_last_tick) >= RCL_QUIET_SECS) {
        rcl_battle_active = 0;
    }

    return rcl_battle_active;
}
