#include "titanox.h"

int tnx_vtable_is_data(uintptr_t vtable) {
    const char *segment = tnx_image_segment_name(vtable);

    if (!segment) return 0;
    if (strcmp(segment, "__DATA_CONST") == 0) return 1;
    if (strcmp(segment, "__DATA") == 0) return 1;

    return 0;
}

int tnx_state_tick(void) {
    uintptr_t slot = (uintptr_t)tnx_read_global_ptr(TNX_STATE_RVA);
    int32_t state = -1;
    void *value = NULL;
    uintptr_t scene = 0;
    uintptr_t client = 0;
    uintptr_t inner = 0;
    uintptr_t players = 0;
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    uintptr_t hopArray[TNX_HOPS] = { 0 };
    int32_t hopCount[TNX_HOPS] = { 0 };
    int32_t hopCap[TNX_HOPS] = { 0 };
    int hopOk[TNX_HOPS] = { 0 };
    int score[TNX_HOPS];
    char hopWhy[TNX_HOPS][96] = { { 0 } };
    int chosen = -1;

    if (slot) tnx_read_int(slot + TNX_STATE_ENUM_OFF, &state);

    if (slot != t_site || state != t_state_2) {
        tnx_state_note(state);

        t_site = slot;
        t_state_2 = state;

    }

    if (!slot) return 0;

    if (state != TNX_STATE_BATTLE) {

        return 0;
    }

    if (!tnx_read_ptr(slot + TNX_SCENE_OFF, &value) || !value) return 0;

    scene = (uintptr_t)value;

    if (scene != t_scene_object) {
        uintptr_t scenePrev = t_scene_object;

        t_scene_object = scene;


    }

    if (!tnx_read_ptr(scene + TNX_MODE_MANAGER_OFF, &value) || !value) {

        return 1;
    }

    client = (uintptr_t)value;

    if (!tnx_read_ptr(client + TNX_CLIENT_HOP_OFF, &value) || !value) {

        return 1;
    }

    inner = (uintptr_t)value;

    hopOk[0] = tnx_container_header(client, &hopArray[0], &hopCount[0], &hopCap[0], hopWhy[0],
                                        sizeof(hopWhy[0]));
    hopOk[1] = tnx_container_header(inner, &hopArray[1], &hopCount[1], &hopCap[1], hopWhy[1],
                                        sizeof(hopWhy[1]));

    score[0] = hopOk[0] ? tnx_container_score(client) : -1;
    score[1] = hopOk[1] ? tnx_container_score(inner) : -1;

    if (score[1] > score[0]) {
        chosen = 1;
        t_hop_sticky = 1;
    } else if (score[0] > score[1]) {
        chosen = 0;
        t_hop_sticky = 0;
    } else {
        chosen = hopOk[1] ? 1 : (hopOk[0] && !t_hop_sticky ? 0 : -1);
    }

    if (chosen != t_last_choice) {
        t_last_choice = chosen;

    } else if (t_hop_logs < 6) {
        t_hop_logs++;

    }


    if (scene != t_hop_scene) {
        t_hop_scene = scene;



    }

    if (TNX_WIRE_OWNER && t_owner) {
        void *directArray = NULL;
        int32_t directCount = 0;

        if (tnx_read_ptr(t_owner + TNX_MGR_ARRAY_OFF, &directArray) && directArray &&
            tnx_read_int(t_owner + TNX_MGR_COUNT_OFF, &directCount) && directCount > 0) {
            t_players_object = t_owner;
            t_players_array = (uintptr_t)directArray;
            t_players_count = directCount;
            t_hop_chosen = TNX_HOPCHOSEN_DIRECT;

            if (!t_wired) {
                t_wired = 1;

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

    t_hop_chosen = chosen;

    {
        static int v141_array_vote_logs = 0;

        if ((uintptr_t)array != t_pub_array && (uintptr_t)players == t_pub_object &&
            v141_array_vote_logs < TNX_ARRAY_VOTE_LOGS) {
            v141_array_vote_logs++;

        }
    }

    if ((uintptr_t)players != t_pub_object || (uintptr_t)array != t_pub_array ||
        count != t_pub_count) {
        tnx_publish((uintptr_t)players, (uintptr_t)array, count, capacity, "hop-adopt");


    }

    t_manager_count = count;

    if (count > 0 && count <= TNX_MANAGER_MAX_OBJECTS && capacity > 0 &&
        capacity <= TNX_MGR_CAP_MAX && array) {

        if (t_hop_chosen == 1) {
            if (!t_hop2_census && players != t_census_container) {
                t_hop2_census = 1;

            }

            tnx_container_census((uintptr_t)array, count, players);
        }
    }

    return 1;
}

int tnx_scan_allowed(uint64_t fired, uint64_t total) {
    if (fired > 0) {

        t_idle_start = 0;
        t_idle_logged = 0;

        return 1;
    }

    if (t_idle_start == 0) t_idle_start = t_ticks_b;


    if (!t_idle_logged && (t_ticks_b - t_idle_start) >= TNX_IDLE_TICKS) {
        t_idle_logged = 1;

    }

    if ((t_ticks_b - t_idle_start) < TNX_IDLE_RETRY_TICKS) {

        return 0;
    }

    t_idle_start = t_ticks_b;

    return 1;
}

int tnx_battle_gate_2(int v63) {
    int liveEnough = (t_live_objs >= TNX_LIVE_OBJ_MIN &&
                      t_live_teams >= TNX_LIVE_TEAM_MIN);

    t_fb_on = (v63 || liveEnough) ? 1 : 0;

    if (!t_fb_on) {
        if (!t_bar_logged && t_ticks_b >= TNX_BAR_TICKS) {
            t_bar_logged = 1;

        }

        return 0;
    }

    if (v63) return 1;

    if (!t_fb_logged) {
        t_fb_logged = 1;

    }

    return 1;
}

void tnx_start_timer(void) {
    if (t_scan_timer) return;

    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    if (!timer) return;

    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);

    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval),
                              interval, (uint64_t)(0.25 * NSEC_PER_SEC));

    dispatch_source_set_event_handler(timer, ^{
        tnx_slot_pump();

        int scene = tnx_state_tick();
        int gate = tnx_battle_gate(scene);
        int battle = gate || scene;
        int fallback = tnx_battle_gate_2(battle);

        int ready = tnx_scan_ready(battle || fallback);
        int needScan = !scene && !t_players_object;

        if (needScan != t_scan_armed) {
            t_scan_armed = needScan;

        }

        if (needScan && ready &&
            tnx_scan_allowed((unsigned long long)tnx_object_dispatches(),
                                 tnx_hook_dispatches())) {
            tnx_locate_battle_mode();
        }

        tnx_modesig_tick();

        t_ticks_b++;

        if ((t_ticks_b % TNX_HB_TICKS) == 0) t_hb_sig_prev = t_modesig_hits;

    });

    dispatch_resume(timer);

    t_scan_timer = timer;


}

uint64_t t_ticks_b = 0;

int t_hb_sig_prev = 0;

int t_battle_active = 0;

int t_battle_last_tick = 0;

int tnx_battle_gate(int scene) {
    unsigned long long objFired = tnx_object_dispatches();
    int objGrew = objFired > t_obj_prev;
    int sigGrew = t_modesig_hits > t_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;

    t_obj_prev = objFired;

    if (sigGrew || objGrew || sceneGrew) {
        t_battle_last_tick = (int)t_ticks_b;

        if (!t_battle_active) {
            t_battle_active = 1;
        }
    } else if (t_battle_active &&
               ((int)t_ticks_b - t_battle_last_tick) >= TNX_QUIET_SECS) {
        t_battle_active = 0;
    }

    return t_battle_active;
}
