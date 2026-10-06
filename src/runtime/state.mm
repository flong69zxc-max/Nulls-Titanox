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

    if (slot) tnx_read_i32(slot + TNX_STATE_ENUM_OFF, &state);

    if (slot != t_site || state != t_state_2) {
        tnx_state_note(state);
        tnx_logf("state slot=%p state=%d - the engine loads this word in 0x8cdfd4, tests "
                 "[slot+%#llx] against %d in 0x8c5130 and only then returns [slot+%#llx]; the "
                 "state that passes that test is the one in which the engine itself calls the "
                 "object the battle scene", (void *)slot, state,
                 (unsigned long long)TNX_STATE_ENUM_OFF, TNX_STATE_BATTLE,
                 (unsigned long long)TNX_SCENE_OFF);

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

        tnx_logf("scene=%p from slot+%#llx at state=%d - the screen factory 0x8ce048 builds "
                 "state %d as new(0x98) plus the constructor 0x8c51f8, which stores %#llx at [+0], "
                 "so this object IS the battle screen and its own slot +0xb0 logs \"No battle "
                 "client\" when [+%#llx] is null; the client is therefore scene+%#llx, one hop "
                 "above the object container",
                 (void *)scene, (unsigned long long)TNX_SCENE_OFF, state,
                 TNX_STATE_BATTLE, (unsigned long long)TNX_SCENE_CLASS_RVA,
                 (unsigned long long)TNX_MODE_MANAGER_OFF,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);

    }

    if (!tnx_read_ptr(scene + TNX_MODE_MANAGER_OFF, &value) || !value) {
        tnx_logf("scene+%#llx holds no battle client at state=%d - the pointer is read again "
                 "next tick and the scene is kept, because the engine's global is the authority "
                 "and a null here is a not-yet-filled field, not a wrong scene",
                 (unsigned long long)TNX_MODE_MANAGER_OFF, state);

        return 1;
    }

    client = (uintptr_t)value;

    if (!tnx_read_ptr(client + TNX_CLIENT_HOP_OFF, &value) || !value) {
        tnx_logf("client=%p carries no pointer at +%#llx yet - that field is what "
                 "findOwningTeam 0xac3ddc dereferences before it walks anything, so the second "
                 "hop is retried next tick rather than filled in from the client's own fields",
                 (void *)client, (unsigned long long)TNX_CLIENT_HOP_OFF);

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

        tnx_logf("hop-select chosen=%d score0=%d score1=%d hopOk=%d/%d sticky=%d - the hop is "
                 "re-decided every tick from the own slot inside each candidate, so it can leave the "
                 "object that carried a header first and go back to the client hop",
                 chosen, score[0], score[1], hopOk[0], hopOk[1], t_hop_sticky);
    } else if (t_hop_logs < 6) {
        t_hop_logs++;

    }

    if (t_tick_2 < 4 || (t_tick_2 % 90) == 0) {
    }

    if (scene != t_hop_scene) {
        t_hop_scene = scene;

        tnx_logf("hop1 scene+%#llx=%p client hop2 client+%#llx=%p inner hop1test=%d (%s) "
                 "hop2test=%d (%s) chosen=%d - findOwningTeam reads +0x28 off its receiver and "
                 "then +0x0/+0xc off the result, so only the hop that carries the header is the "
                 "object container",
                 (unsigned long long)TNX_MODE_MANAGER_OFF, (void *)client,
                 (unsigned long long)TNX_CLIENT_HOP_OFF, (void *)inner,
                 hopOk[0], hopWhy[0], hopOk[1], hopWhy[1], chosen);

        tnx_hop_dump(client, inner);

        if (t_field_scans < TNX_FIELD_SCANS) {
            t_field_scans++;

        }
    }

    if (TNX_WIRE_OWNER && t_owner_2) {
        void *directArray = NULL;
        int32_t directCount = 0;

        if (tnx_read_ptr(t_owner_2 + TNX_MGR_ARRAY_OFF, &directArray) && directArray &&
            tnx_read_i32(t_owner_2 + TNX_MGR_COUNT_OFF, &directCount) && directCount > 0) {
            t_players_object = t_owner_2;
            t_players_array = (uintptr_t)directArray;
            t_players_count = directCount;
            t_hop_chosen = TNX_HOPCHOSEN_DIRECT;

            if (!t_wired) {
                t_wired = 1;

                tnx_logf("owner wired route=direct owner=%p array=%p count-at-wire=%d chosen=%d - the walk "
                         "reads the owner list from this tick on; the array and the count are re-read from the "
                         "owner on every tick, and chosen stays above one because a negative value already means "
                         "no container elsewhere in the engine path",
                         (void *)t_owner_2, (void *)directArray, directCount,
                         TNX_HOPCHOSEN_DIRECT);
            }

            return 0;
        }
    }

    if (chosen < 0) {
        tnx_logf("chain rejected: neither hop carries an array/count/cap header (hop1 %s, "
                 "hop2 %s, sticky=%d) - nothing is published this tick, and once hop2 has ever "
                 "passed the choice stays on it instead of falling back to the client, so the "
                 "last good container is what the walk keeps reading", hopWhy[0], hopWhy[1],
                 t_hop_sticky);

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

            tnx_logf("array moved without the container container=%p hop=%d oldArray=%p "
                     "newArray=%p count=%d - the pair is republished on the array alone, because "
                     "the container can stay equal while the engine reallocates or swaps the "
                     "list, and that difference is what made the resolver read a foreign array",
                     (void *)players, chosen, (void *)t_pub_array, array, count);
        }
    }

    if ((uintptr_t)players != t_pub_object || (uintptr_t)array != t_pub_array ||
        count != t_pub_count) {
        tnx_publish((uintptr_t)players, (uintptr_t)array, count, capacity, "hop-adopt");

        tnx_logf("container=%p hop=%d count=%d cap=%d array=%p - read straight out of the "
                 "engine's own global chain with no scan; hop %d is the field the engine walks "
                 "after 0xac3ddc reads it",
                 (void *)players, chosen, count, capacity, array, chosen);

        if (t_players_dumps < TNX_PLAYERS_DUMPS) {
            t_players_dumps++;

            tnx_players_dump(players, (uintptr_t)array, count, capacity);
        }
    }

    t_manager_count = count;

    if (count > 0 && count <= TNX_MANAGER_MAX_OBJECTS && capacity > 0 &&
        capacity <= TNX_MGR_CAP_MAX && array) {

        if (t_hop_chosen == 1) {
            if (!t_hop2_census && players != t_census_container) {
                t_hop2_census = 1;

                tnx_logf("census armed on hop2: hop=%d container=%p count=%d array=%p - the "
                         "census is taken once per container and only on the hop the engine "
                         "walks; the dedup key is the container and not the array, because the "
                         "array pointer moves when it is reallocated and the v88 run took a "
                         "second census of the same manager for that reason",
                         t_hop_chosen, (void *)players, count, (void *)array);
            }

            tnx_container_census((uintptr_t)array, count, players);
        }
    }

    return 1;
}

int tnx_scan_allowed(uint64_t fired, uint64_t total) {
    if (fired > 0) {
        if (t_idle_on) {
            tnx_logf("scan resumed at tick=%llu objFired=%llu total=%llu - the object-class "
                     "slots are being dispatched again after %d parked ticks",
                     (unsigned long long)t_ticks_4, (unsigned long long)fired,
                     (unsigned long long)total, t_idle_skips);
        }

        t_idle_on = 0;
        t_idle_start = 0;
        t_idle_logged = 0;
        t_idle_skips = 0;

        return 1;
    }

    if (t_idle_start == 0) t_idle_start = t_ticks_4;

    t_idle_on = 1;

    if (!t_idle_logged && (t_ticks_4 - t_idle_start) >= TNX_IDLE_TICKS) {
        t_idle_logged = 1;

        tnx_logf("scan parked at tick=%llu: none of the %d object-class slots has been "
                 "dispatched in %llu ticks while the %d armed slots together reached %llu, so "
                 "the app is drawing UI and not a battle and the heap walk has no mode to find; "
                 "it resumes on the first object-class dispatch and is retried every %d parked "
                 "ticks", (unsigned long long)t_ticks_4, TNX_OBJ_SLOTS,
                 (unsigned long long)(t_ticks_4 - t_idle_start), TNX_SLOT_COUNT,
                 (unsigned long long)total, TNX_IDLE_RETRY_TICKS);
    }

    if ((t_ticks_4 - t_idle_start) < TNX_IDLE_RETRY_TICKS) {
        t_idle_skips++;

        return 0;
    }

    t_idle_start = t_ticks_4;
    t_idle_skips = 0;

    return 1;
}

int tnx_battle_gate_2(int v63) {
    int liveEnough = (t_live_objs >= TNX_LIVE_OBJ_MIN &&
                      t_live_teams >= TNX_LIVE_TEAM_MIN);

    t_fb_on = (v63 || liveEnough) ? 1 : 0;

    if (!t_fb_on) {
        if (!t_bar_logged && t_ticks_4 >= TNX_BAR_TICKS) {
            t_bar_logged = 1;

            tnx_logf("gate fallback OFF v63=%d liveObjs=%d liveTeams=%d need=%d/%d - the "
                     "objhit set holds no live objects over two teams, so nothing here claims "
                     "a battle the mode signature cannot see", v63, t_live_objs,
                     t_live_teams, TNX_LIVE_OBJ_MIN, TNX_LIVE_TEAM_MIN);
        }

        return 0;
    }

    if (v63) return 1;

    if (!t_fb_logged) {
        t_fb_logged = 1;

        tnx_logf("gate fallback ON liveObjs=%d liveTeams=%d - v63 cannot see a mode, but "
                 "the objhit set holds live objects over two teams, which is the weaker "
                 "signal the trail itself uses", t_live_objs, t_live_teams);
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

            tnx_logf("heap walk %s - the scene chain %s, so the walk is %s",
                     needScan ? "armed" : "parked",
                     t_players_object ? "delivered the container" : "has not delivered yet",
                     needScan ? "the only remaining source" : "not needed this tick");
        }

        if (needScan && ready &&
            tnx_scan_allowed((unsigned long long)tnx_object_dispatches(),
                                 tnx_hook_dispatches())) {
            tnx_locate_battle_mode();
        }

        tnx_modesig_tick();

        t_scan_ticks++;
        t_ticks_4++;

        if ((t_ticks_4 % TNX_HB_TICKS) == 0) tnx_log_heartbeat();

        if ((t_ticks_4 % 10) == 0) tnx_slot_fired_report();

        tnx_overlay_update();
    });

    dispatch_resume(timer);

    t_scan_timer = timer;

    tnx_logf("scan timer started (1 Hz, render hook no longer drives the scan)");

    tnx_log_heartbeat();
}

uint64_t t_ticks_4 = 0;
