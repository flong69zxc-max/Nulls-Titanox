#include "titanox.h"

#ifndef TNX_LOG_PLANS
#define TNX_LOG_PLANS 0
#endif

int g_own_team = 0;

int g_own_idhit = 0;

uintptr_t g_setpred = 0;

int g_wide_runs = 0;

int g_miss_logs = 0;

int g_live_objs = 0;

int g_live_teams = 0;

int g_fb_on = 0;

int g_fb_logged = 0;

int g_bar_logged = 0;

unsigned g_vt_text_rejects = 0;

unsigned long long g_obj_prev = 0;

uintptr_t g_site = 0;

int g_state_2 = -1;

int g_scan_armed = -1;

volatile uint32_t g_seq = 0;

uintptr_t g_pub_object = 0;

uintptr_t g_pub_array = 0;

int32_t g_pub_count = 0;

int32_t g_pub_cap = 0;

int g_pub_logs = 0;

uintptr_t g_tick_object = 0;

uintptr_t g_tick_array = 0;

int32_t g_tick_count = 0;

uint64_t g_tick_logs = 0;

int g_score_logs_2 = 0;

uint64_t g_walk_aborts = 0;

void tnx_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap,
                             const char *why) {
    __sync_synchronize();

    g_seq++;

    __sync_synchronize();

    g_pub_object = object;
    g_pub_array = array;
    g_pub_count = count;
    g_pub_cap = cap;

    g_players_object = object;
    g_players_array = array;
    g_players_count = count;
    g_players_cap = cap;

    __sync_synchronize();

    g_seq++;

    __sync_synchronize();

    if (g_pub_logs < 12) {
        g_pub_logs++;

        tnx_logf("publish why=%s object=%p array=%p count=%d cap=%d seq=%u - the whole triple "
                 "moves under one sequence, so no reader can take the new array with the old "
                 "count", why ? why : "?", (void *)object, (void *)array, count, cap,
                 (unsigned)g_seq);
    }
}

int tnx_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut) {
    int tries;

    for (tries = 0; tries < 8; tries++) {
        uint32_t s1 = g_seq;
        uintptr_t o;
        uintptr_t a;
        int32_t c;

        if (s1 & 1u) continue;

        o = g_pub_object;
        a = g_pub_array;
        c = g_pub_count;

        __sync_synchronize();

        if (g_seq != s1) continue;

        if (objectOut) *objectOut = o;
        if (arrayOut) *arrayOut = a;
        if (countOut) *countOut = c;

        return 1;
    }

    return 0;
}

void tnx_tick_begin(const char *phase) {
    uintptr_t o = 0;
    uintptr_t a = 0;
    int32_t c = 0;

    if (!tnx_snapshot(&o, &a, &c)) return;

    g_tick_object = o;
    g_tick_array = a;
    g_tick_count = c;
    g_tick_stamp++;

    if (g_tick_logs < 12) {
        g_tick_logs++;

        tnx_logf("tick enter phase=%s object=%p array=%p count=%d stamp=%llu - the snapshot is "
                 "taken before any stage reads it and is what the walk, the census and the "
                 "resolver all use, so a publish from the scan timer cannot split them",
                 phase ? phase : "?", (void *)o, (void *)a, c,
                 (unsigned long long)g_tick_stamp);
    }
}

uint64_t g_idle_start = 0;

int g_idle_on = 0;

int g_idle_logged = 0;

int g_idle_skips = 0;

void tnx_slot_install_one(int index) {
    uintptr_t target = 0;
    int slots = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_installed[index] = 0;
    g_slot_slots[index] = 0;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    if (!g_slot_specs[index].rva && !g_slot_specs[index].slotRva) return;

    target = g_base + g_slot_specs[index].rva;

    if (!target) return;

    slots = hook_probe(target);

    if (slots > TNX_MAX_SLOTS) {
        tnx_logf("slot %s: reject-bulk target=%p slots=%d - that many identical copies means the address is "
                 "a shared constant duplicated across class tables and not a vtable entry, so redirecting "
                 "it would send every original caller into a stub with the wrong arguments",
                 g_slot_specs[index].tag, (void *)target, slots);

        return;
    }

    {
        uint32_t w = 0;
        int prologue = 0;

        if (tnx_read_u32(target, &w)) {
            if ((w & 0xFFC003FFu) == 0xD10003FFu) prologue = 1;
            if ((w & 0xFF4003E0u) == 0xA90003E0u) prologue = 1;
            if ((w & 0xFF4003E0u) == 0xA80003E0u) prologue = 1;
            if (w == 0xD503237Fu) prologue = 1;
            if (w == 0xD503245Fu) prologue = 1;
            if (w == 0xD65F03C0u) prologue = 1;
            if (w == 0x910003FDu) prologue = 1;
            if ((w & 0xFF000000u) == 0x14000000u) prologue = 1;
            if ((w & 0x9F000000u) == 0x10000000u) prologue = 1;
        }

        if (!prologue) {
            tnx_logf("slot %s: reject-nonfunc target=%p firstWord=%#x - the first instruction is not a "
                     "prologue, a leaf return, a branch or an adrp, so this is not a function entry and a "
                     "stub placed here would be entered with the caller's scratch registers intact",
                     g_slot_specs[index].tag, (void *)target, (unsigned)w);

            return;
        }
    }

    if (slots <= 0) {
        tnx_logf("slot %s: not-found target=%p slots=0 in __DATA_CONST/__DATA - runtime inline "
                 "patching is not supported, so this target needs a data slot (%s)",
                 g_slot_specs[index].tag, (void *)target,
                 hook_last_error() ? hook_last_error() : "-");

        return;
    }

    if (!brk_install((void *)target, (void *)g_slot_specs[index].replacement)) {
        tnx_logf("slot %s: install failed target=%p (%s)", g_slot_specs[index].tag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    g_slot_orig[index] = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    g_slot_installed[index] = 1;
    g_slot_slots[index] = slots;

    tnx_logf("slot %s: installed target=%p original=%p mode=pointer slots=%d liveSlots=%d",
             g_slot_specs[index].tag, (void *)target, (void *)g_slot_orig[index], slots,
             brk_live_slot_count());
}

void tnx_slot_hooks_install(void) {
    const char *flag = NULL;

    if (!g_base) return;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    flag = getenv("TITANOX_ALLOW_CODE_PATCH");

    tnx_logf("slot hooks: codePatch=%d flag=%s pointerSlots=%d limit=%d live=%d",
             hook_code_patch_allowed() ? 1 : 0, flag ? flag : "-",
             hook_pointer_count(), brk_slot_limit(), brk_live_slot_count());

    for (int i = 0; i < TNX_SLOT_COUNT; i++) tnx_slot_install_one(i);

    tnx_slot_diag("install");
}

void tnx_run_autododge(int from_update) {
    if (g_in_drive) {
        g_reentry++;

        return;
    }

    if (!TNX_DRIVE_FROM_UPDATE && from_update) {
        g_update_skip++;

        return;
    }

    g_in_drive = 1;
    g_t0 = tnx_us();
    tnx_autododge_v48();
    g_in_drive = 0;
}

void tnx_run_autoaim(void) {
    if (!g_addr_getinstance || !g_addr_getownchar || !g_addr_battlescreen) return;

    void *battleMode = ((fn_get_inst_t)g_addr_getinstance)();
    if (!tnx_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)g_addr_getownchar)(battleMode);
    if (!tnx_object_plausible(ownChar)) return;

    int ownX = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(ownChar) : 0;
    int ownY = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(ownChar) : 0;
    int ownTeam = g_addr_getteam ? ((fn_get_team_t)g_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!tnx_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!tnx_read_i32((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

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
        if (!tnx_read_u8((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!tnx_read_i32((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(obj) : 0;
        int ey = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(obj) : 0;

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
    if (!tnx_read_ptr(g_addr_battlescreen, &screen)) return;

    if (!tnx_object_plausible(screen)) {
        if (!g_aim_rejected) {
            g_aim_rejected = YES;
            tlog(@"autofire disabled: RVA_BATTLESCREEN__BATTLESCREEN is not a valid instance slot");
        }
        return;
    }

    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;

    if (!tnx_addr_writable(fireX, 4) || !tnx_addr_writable(fireY, 4)) {
        if (!g_aim_rejected) {
            g_aim_rejected = YES;
            tlog(@"autofire disabled: target offsets are not writable");
        }
        return;
    }

    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}

int tnx_vtable_is_data(uintptr_t vtable) {
    const char *segment = tnx_image_segment_name(vtable);

    if (!segment) return 0;
    if (strcmp(segment, "__DATA_CONST") == 0) return 1;
    if (strcmp(segment, "__DATA") == 0) return 1;

    return 0;
}

int g_ascii_logs = 0;

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

    if (slot != g_site || state != g_state_2) {
        tnx_state_note(state);
        tnx_logf("state slot=%p state=%d - the engine loads this word in 0x8cdfd4, tests "
                 "[slot+%#llx] against %d in 0x8c5130 and only then returns [slot+%#llx]; the "
                 "state that passes that test is the one in which the engine itself calls the "
                 "object the battle scene", (void *)slot, state,
                 (unsigned long long)TNX_STATE_ENUM_OFF, TNX_STATE_BATTLE,
                 (unsigned long long)TNX_SCENE_OFF);

        g_site = slot;
        g_state_2 = state;

    }

    if (!slot) return 0;

    if (state != TNX_STATE_BATTLE) {

        return 0;
    }

    if (!tnx_read_ptr(slot + TNX_SCENE_OFF, &value) || !value) return 0;

    scene = (uintptr_t)value;

    if (scene != g_scene_object) {
        uintptr_t scenePrev = g_scene_object;

        g_scene_object = scene;
        tnx_battle_alert(scene, scenePrev);

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
        g_hop_sticky = 1;
    } else if (score[0] > score[1]) {
        chosen = 0;
        g_hop_sticky = 0;
    } else {
        chosen = hopOk[1] ? 1 : (hopOk[0] && !g_hop_sticky ? 0 : -1);
    }

    if (chosen != g_last_choice) {
        g_last_choice = chosen;

        tnx_logf("hop-select chosen=%d score0=%d score1=%d hopOk=%d/%d sticky=%d - the hop is "
                 "re-decided every tick from the own slot inside each candidate, so it can leave the "
                 "object that carried a header first and go back to the client hop",
                 chosen, score[0], score[1], hopOk[0], hopOk[1], g_hop_sticky);
    } else if (g_hop_logs < 6) {
        g_hop_logs++;

    }

    if (g_tick_2 < 4 || (g_tick_2 % 90) == 0) {
    }

    if (scene != g_hop_scene) {
        g_hop_scene = scene;

        tnx_logf("hop1 scene+%#llx=%p client hop2 client+%#llx=%p inner hop1test=%d (%s) "
                 "hop2test=%d (%s) chosen=%d - findOwningTeam reads +0x28 off its receiver and "
                 "then +0x0/+0xc off the result, so only the hop that carries the header is the "
                 "object container",
                 (unsigned long long)TNX_MODE_MANAGER_OFF, (void *)client,
                 (unsigned long long)TNX_CLIENT_HOP_OFF, (void *)inner,
                 hopOk[0], hopWhy[0], hopOk[1], hopWhy[1], chosen);

        tnx_hop_dump(client, inner);

        if (g_field_scans < TNX_FIELD_SCANS) {
            g_field_scans++;

        }
    }

    if (TNX_WIRE_OWNER && g_owner_2) {
        void *directArray = NULL;
        int32_t directCount = 0;

        if (tnx_read_ptr(g_owner_2 + TNX_MGR_ARRAY_OFF, &directArray) && directArray &&
            tnx_read_i32(g_owner_2 + TNX_MGR_COUNT_OFF, &directCount) && directCount > 0) {
            g_players_object = g_owner_2;
            g_players_array = (uintptr_t)directArray;
            g_players_count = directCount;
            g_hop_chosen = TNX_HOPCHOSEN_DIRECT;

            if (!g_wired) {
                g_wired = 1;

                tnx_logf("owner wired route=direct owner=%p array=%p count-at-wire=%d chosen=%d - the walk "
                         "reads the owner list from this tick on; the array and the count are re-read from the "
                         "owner on every tick, and chosen stays above one because a negative value already means "
                         "no container elsewhere in the engine path",
                         (void *)g_owner_2, (void *)directArray, directCount,
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
                 g_hop_sticky);

        return 1;
    }

    players = (chosen == 1) ? inner : client;
    array = (void *)hopArray[chosen];
    count = hopCount[chosen];
    capacity = hopCap[chosen];

    g_hop_chosen = chosen;

    {
        static int v141_array_vote_logs = 0;

        if ((uintptr_t)array != g_pub_array && (uintptr_t)players == g_pub_object &&
            v141_array_vote_logs < TNX_ARRAY_VOTE_LOGS) {
            v141_array_vote_logs++;

            tnx_logf("array moved without the container container=%p hop=%d oldArray=%p "
                     "newArray=%p count=%d - the pair is republished on the array alone, because "
                     "the container can stay equal while the engine reallocates or swaps the "
                     "list, and that difference is what made the resolver read a foreign array",
                     (void *)players, chosen, (void *)g_pub_array, array, count);
        }
    }

    if ((uintptr_t)players != g_pub_object || (uintptr_t)array != g_pub_array ||
        count != g_pub_count) {
        tnx_publish((uintptr_t)players, (uintptr_t)array, count, capacity, "hop-adopt");

        tnx_logf("container=%p hop=%d count=%d cap=%d array=%p - read straight out of the "
                 "engine's own global chain with no scan; hop %d is the field the engine walks "
                 "after 0xac3ddc reads it",
                 (void *)players, chosen, count, capacity, array, chosen);

        if (g_players_dumps < TNX_PLAYERS_DUMPS) {
            g_players_dumps++;

            tnx_players_dump(players, (uintptr_t)array, count, capacity);
        }
    }

    g_manager_count = count;

    if (count > 0 && count <= TNX_MANAGER_MAX_OBJECTS && capacity > 0 &&
        capacity <= TNX_MGR_CAP_MAX && array) {

        if (g_hop_chosen == 1) {
            if (!g_hop2_census && players != g_census_container) {
                g_hop2_census = 1;

                tnx_logf("census armed on hop2: hop=%d container=%p count=%d array=%p - the "
                         "census is taken once per container and only on the hop the engine "
                         "walks; the dedup key is the container and not the array, because the "
                         "array pointer moves when it is reallocated and the v88 run took a "
                         "second census of the same manager for that reason",
                         g_hop_chosen, (void *)players, count, (void *)array);
            }

            tnx_container_census((uintptr_t)array, count, players);
        }
    }

    return 1;
}

const int tnx_object_slots[TNX_OBJ_SLOTS] = { 2, 3, 4 };

int tnx_scan_allowed(uint64_t fired, uint64_t total) {
    if (fired > 0) {
        if (g_idle_on) {
            tnx_logf("scan resumed at tick=%llu objFired=%llu total=%llu - the object-class "
                     "slots are being dispatched again after %d parked ticks",
                     (unsigned long long)g_ticks_4, (unsigned long long)fired,
                     (unsigned long long)total, g_idle_skips);
        }

        g_idle_on = 0;
        g_idle_start = 0;
        g_idle_logged = 0;
        g_idle_skips = 0;

        return 1;
    }

    if (g_idle_start == 0) g_idle_start = g_ticks_4;

    g_idle_on = 1;

    if (!g_idle_logged && (g_ticks_4 - g_idle_start) >= TNX_IDLE_TICKS) {
        g_idle_logged = 1;

        tnx_logf("scan parked at tick=%llu: none of the %d object-class slots has been "
                 "dispatched in %llu ticks while the %d armed slots together reached %llu, so "
                 "the app is drawing UI and not a battle and the heap walk has no mode to find; "
                 "it resumes on the first object-class dispatch and is retried every %d parked "
                 "ticks", (unsigned long long)g_ticks_4, TNX_OBJ_SLOTS,
                 (unsigned long long)(g_ticks_4 - g_idle_start), TNX_SLOT_COUNT,
                 (unsigned long long)total, TNX_IDLE_RETRY_TICKS);
    }

    if ((g_ticks_4 - g_idle_start) < TNX_IDLE_RETRY_TICKS) {
        g_idle_skips++;

        return 0;
    }

    g_idle_start = g_ticks_4;
    g_idle_skips = 0;

    return 1;
}

int tnx_battle_gate_2(int v63) {
    int liveEnough = (g_live_objs >= TNX_LIVE_OBJ_MIN &&
                      g_live_teams >= TNX_LIVE_TEAM_MIN);

    g_fb_on = (v63 || liveEnough) ? 1 : 0;

    if (!g_fb_on) {
        if (!g_bar_logged && g_ticks_4 >= TNX_BAR_TICKS) {
            g_bar_logged = 1;

            tnx_logf("gate fallback OFF v63=%d liveObjs=%d liveTeams=%d need=%d/%d - the "
                     "objhit set holds no live objects over two teams, so nothing here claims "
                     "a battle the mode signature cannot see", v63, g_live_objs,
                     g_live_teams, TNX_LIVE_OBJ_MIN, TNX_LIVE_TEAM_MIN);
        }

        return 0;
    }

    if (v63) return 1;

    if (!g_fb_logged) {
        g_fb_logged = 1;

        tnx_logf("gate fallback ON liveObjs=%d liveTeams=%d - v63 cannot see a mode, but "
                 "the objhit set holds live objects over two teams, which is the weaker "
                 "signal the trail itself uses", g_live_objs, g_live_teams);
    }

    return 1;
}

void tnx_start_timer(void) {
    if (g_scan_timer) return;

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
        int needScan = !scene && !g_players_object;

        if (needScan != g_scan_armed) {
            g_scan_armed = needScan;

            tnx_logf("heap walk %s - the scene chain %s, so the walk is %s",
                     needScan ? "armed" : "parked",
                     g_players_object ? "delivered the container" : "has not delivered yet",
                     needScan ? "the only remaining source" : "not needed this tick");
        }

        if (needScan && ready &&
            tnx_scan_allowed((unsigned long long)tnx_object_dispatches(),
                                 tnx_hook_dispatches())) {
            tnx_locate_battle_mode();
        }

        tnx_modesig_tick();

        g_scan_ticks++;
        g_ticks_4++;

        if ((g_ticks_4 % TNX_HB_TICKS) == 0) tnx_log_heartbeat();

        if ((g_ticks_4 % 10) == 0) tnx_slot_fired_report();

        tnx_overlay_update();
    });

    dispatch_resume(timer);

    g_scan_timer = timer;

    tnx_logf("scan timer started (1 Hz, render hook no longer drives the scan)");

    tnx_log_heartbeat();
}

void tnx_run_workload(void) {

    tnx_tick_begin("pre-locate");

    tnx_phase("locate");

    tnx_locate_battle_mode();

    tnx_tick_begin("post-locate");

    if (g_scene_object) {
        if (!g_snapshot_first) {
            g_snapshot_first = YES;
            g_snapshot_start = CFAbsoluteTimeGetCurrent();
        } else if (!g_snapshot_second) {
            if (CFAbsoluteTimeGetCurrent() > (g_snapshot_start + TNX_SNAPSHOT_DELAY)) {
                g_snapshot_second = YES;
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

    tnx_phase("alert");
    tnx_alert_battle_check();

    tnx_phase("tick-end");
}

int g_walk_aborted = 0;

int g_walk_abort_i = -1;

uintptr_t g_walk_arr = 0;

int32_t g_walk_n = 0;

int g_pub_logs_2 = 0;

int g_stale_logs = 0;

int g_actuate_logs = 0;

uintptr_t g_own_slot = 0;

int32_t g_own_slot_gid = 0;

int g_own_slot_ok = 0;

int g_own_slot_logs = 0;

uintptr_t tnx_battle_global(void) {
    return (uintptr_t)tnx_read_global_ptr(TNX_BATTLE_RVA);
}

void tnx_chain(void) {
    static int done = 0;
    uintptr_t scene = (uintptr_t)g_scene_object;
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
             (void *)slotOwn, g_own_slot_idx, slotGid, TNX_OWN_EXPECT_GID,
             (unsigned long long)TNX_CTRL_RAW_X_OFF, rawOk, rawX, rawY, g_own_slot_ok,
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

int g_gate2_seen = 0;

int g_gate3_seen = 0;

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
    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + off, &o) || !o) return 0;
    if (flag && tnx_read_u8((uintptr_t)o + TNX_GATE_BYTE_OFF, &b)) *flag = (int)b;

    return tnx_pair((uintptr_t)o, x, y);
}

int32_t g_src30_prev_x = 0;

int32_t g_src30_prev_y = 0;

int32_t g_src38_prev_x = 0;

int32_t g_src38_prev_y = 0;

int g_src30_have = 0;

int g_src38_have = 0;

uint64_t g_src30_moves = 0;

uint64_t g_src38_moves = 0;

int g_w_eq_x = 0;

int g_w_eq_y = 0;

int tnx_weq(int32_t a, int32_t b, int32_t out, int32_t d) {
    if (d == 0) return -1;

    return (int)(((int64_t)(out - b) * 1000) / (int64_t)d);
}

uintptr_t tnx_mode_ptr(uintptr_t off) {
    void *o = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + off, &o)) return 0;

    return (uintptr_t)o;
}

int g_probe_logs = 0;

uintptr_t tnx_cls(uintptr_t obj) {
    uintptr_t vt = 0;

    if (!tnx_vt_ok(obj, &vt)) return 0;

    return (vt >= g_base) ? (vt - g_base) : 0;
}

void tnx_slot_pump(void) {
    int first = -1;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        uint32_t bit = (uint32_t)(1u << i);

        if (!g_slot_object[i]) continue;

        if (!g_slot_specs[i].control && first < 0) first = i;

        if (g_slot_reported_mask & bit) continue;

        g_slot_reported_mask |= bit;

        tnx_logf("slot %s: captured this=%p arg1=%p hits=%llu%s", g_slot_specs[i].tag,
                 (void *)g_slot_object[i], (void *)g_slot_arg1[i],
                 (unsigned long long)g_slot_hits[i],
                 g_slot_specs[i].control ? " CONTROL" : "");
    }

    if (first < 0) return;

    uintptr_t object = g_slot_object[first];

    if (g_slot_adopted == object) return;

    g_slot_adopted = object;

    int installed = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_installed[i] == 1) installed++;
    }

    tnx_logf("slot pump object=%p source=%s installed=%d/%d",
             (void *)object, g_slot_specs[first].tag, installed, TNX_SLOT_COUNT);

    {
        void *vtable = NULL;
        void *manager = NULL;
        const char *reason = "vtable-not-in-image";

        if (tnx_read_ptr(object, &vtable) && vtable &&
            tnx_vtable_in_image((uintptr_t)vtable)) {
            reason = (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &manager) && manager)
                         ? "adopt-from-slot-banned"
                         : "no-manager-at-0x28";
        } else if (!tnx_pointer_plausible((uintptr_t)vtable)) {
            reason = "vtable-garbage";
        }

        tnx_logf("slot %s reject reason=%s this=%p vt=%p", g_slot_specs[first].shortTag, reason,
                 (void *)object, vtable);

        if (strcmp(reason, "vtable-garbage") == 0) return;
    }

    void *bridge = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_BRIDGE_OFF, &bridge) && bridge) {
        void *bridgeManager = NULL;

        tnx_logf("slot +08 bridge=%p vt=%#llx", bridge,
                 (unsigned long long)tnx_vtable_rva(bridge));

        if (tnx_read_ptr((uintptr_t)bridge + TNX_MGR_ARRAY_OFF, &bridgeManager) && bridgeManager) {
            tnx_logf("slot bridgeMgr=%p vt=%#llx", bridgeManager,
                     (unsigned long long)tnx_vtable_rva(bridgeManager));

        }
    }

    void *list = NULL;
    int32_t listCount = 0;

    if (tnx_read_ptr(object + TNX_SLOT_LIST_OFF, &list) &&
        tnx_read_i32(object + TNX_SLOT_LISTCOUNT_OFF, &listCount)) {
        tnx_logf("slot +80 list=%p count=%d", list, listCount);
    }

    void *modeManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &modeManager) && modeManager) {
        void *modeArray = NULL;
        int32_t modeCount = 0;

        tnx_logf("slot +28 mgr=%p vt=%#llx", modeManager,
                 (unsigned long long)tnx_vtable_rva(modeManager));

        if (tnx_read_ptr((uintptr_t)modeManager + TNX_MGR_ARRAY_OFF, &modeArray) &&
            tnx_read_i32((uintptr_t)modeManager + TNX_MGR_COUNT_OFF, &modeCount)) {
            tnx_logf("slot +28 arr=%p count=%d live=%d", modeArray, modeCount,
                     tnx_manager_live_count((uintptr_t)modeManager));
        }

    }

    void *inputManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_INPUTMGR_OFF, &inputManager) && inputManager) {
        tnx_logf("slot +58 inputMgr=%p vt=%#llx", inputManager,
                 (unsigned long long)tnx_vtable_rva(inputManager));

    }

    if (g_slot_arg1[first]) {
        tnx_report_manager("slot arg1", g_slot_arg1[first]);
    }

    void *ownerField = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_OWNER_OFF, &ownerField) && ownerField &&
        (uintptr_t)ownerField != g_slot_arg1[first]) {
        tnx_report_manager("slot +20", (uintptr_t)ownerField);
    }

    {
        uintptr_t plan = g_slot_arg1[first] ? g_slot_arg1[first] : (uintptr_t)ownerField;

        if (plan && tnx_manager_live_count(plan) >= TNX_MANAGER_MIN_OBJECTS) {
            int detailed = tnx_object_detail(plan, TNX_OBJECT_DETAIL_MAX);

            if (detailed > 0) tnx_dodge_all_teams(plan);
        }
    }

    void *slotTable = NULL;

    if (tnx_read_ptr(object, &slotTable) && slotTable) {
        tnx_logf("slot vtable=%p", slotTable);

        for (int k = 0; k < 40; k += 4) {
            void *entry[4] = { NULL, NULL, NULL, NULL };

            for (int j = 0; j < 4; j++) {
                tnx_read_ptr((uintptr_t)slotTable + (uintptr_t)(k + j) * sizeof(void *), &entry[j]);
            }

            tnx_logf("slot vt[%02d..%02d] %#llx %#llx %#llx %#llx", k, k + 3,
                     (unsigned long long)(uintptr_t)entry[0],
                     (unsigned long long)(uintptr_t)entry[1],
                     (unsigned long long)(uintptr_t)entry[2],
                     (unsigned long long)(uintptr_t)entry[3]);
        }
    }

}

void setup(void) {
    if (g_setup_done) return;
    g_setup_done = YES;

    tlog([NSString stringWithFormat:@"setup base=%p", (void *)g_base]);

    image_ref_t ref;
    ref.base = g_base;
    ref.hdr = (const struct mach_header_64 *)g_base;

    rt_dump_image(ref);

    tnx_load_function_starts();

    tnx_resolve_addresses();

    tnx_objc_arm("MetalView", "render");
    tnx_objc_arm("NullView", "render");

    tnx_slot_hooks_install();

    int buildControls = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) buildControls++;
    }

    tnx_slot_table_dump();

    tnx_logf("build=%s slots=%d control=%d types>=%d scanEvery=%d heapEvery=%d attempts=%d "
             "arrayProbeLimit=%d chainProbeLimit=%d voteMin=%d voteConfirm=%d voteTeamsMin=%d "
             "gidFloor=%d gidMax=%d objhitDump=%d censusMax=%d censusPrint=%d censusSlots=%d "
             "budgetMin=%lluMB budgetMax=%lluMB",
             TNX_BUILD_TAG, TNX_SLOT_COUNT - buildControls, buildControls, TNX_MODE_MIN_TYPES,
             TNX_VOTESCAN_GLOBAL_EVERY, TNX_VOTESCAN_HEAP_EVERY, TNX_VOTESCAN_ATTEMPTS,
             TNX_MANAGER_PROBE_LIMIT, TNX_CHAIN_PROBE_LIMIT, TNX_OWNER_VOTE_MIN,
             TNX_OWNER_VOTE_CONFIRM, TNX_OWNER_VOTE_TEAMS_MIN,
             TNX_GID_FLOOR, TNX_GID_MAX, TNX_OBJ_HIT_PRINT_MAX, TNX_VTCENSUS_MAX,
             TNX_VTCENSUS_PRINT, TNX_VTCENSUS_SLOTS,
             TNX_HEAP_SCAN_BUDGET / (1024ull * 1024ull),
             TNX_HEAP_SCAN_BUDGET_MAX / (1024ull * 1024ull));

    if (TNX_LOG_PLANS) {
tnx_logf("plan v49: (1) the left-hand panel is REMOVED -- the overlay draws nothing now -- "
             "and replaced by a UIAlertController shown once per battle; (2) the dodge also "
             "takes the scan's best trail candidate as its source, which is the one it was "
             "missing: v48 printed manager=0x0 in both runs while a candidate with live objects "
             "sat unread in the trail; (3) heap passes go from every 30 s to every 5 s, because "
             "both logs show the first real container arriving 60+ s in and the log window "
             "closing before that; (4) the dodge logs its OWN ENTRY unconditionally, so 'did it run' is "
             "printed rather than inferred; (2) the probe runs from whichever of mode/manager "
             "exists, because the array hangs off the MANAGER and only the actuator needs the "
             "mode; (3) a new field report walks a window of the elements and prints, per "
             "four-byte offset, how many DISTINCT values appear, naming the team offset (the "
             "one that splits them) and the position pair (two adjacent offsets, all values "
             "small, all elements different) without assuming either -- the 20:51 dump shows "
             "why that is needed: on its four objects +0x40 ran 0,1,2,3 which is a slot index "
             "and not a team, +0xd0 was 0 on all four, and the repository's +0x30/+0x34 read "
             "as a heap pointer and a 1; (4) the actuator is still pinned to its three "
             "instructions and still gated, but 'no mode' and 'no coordinates' are now "
             "reported as the different failures they are");

    tnx_logf("plan v50: nine requirements from the 21:39 run, in priority order: (1) the alert is "
             "gated on mode!=0 || manager!=0 AND live>=2 AND teamCount>=2 AND three consecutive "
             "sightings of the SAME container, and every refusal prints why "
             "(`v50 alert withheld: ... live= teamCount= distinctGids= deadOk= vt0= sightings=`); "
             "(2) the trail is ranked by (live, nonEmpty, count) and its stability flag is a field "
             "again, not a gate -- `worst eight` became `top eight`, the best entry is marked "
             "`<- best`, and an empty best is named `best trail candidate has live=0, waiting`; "
             "(3) every rejected element carries a reason (rejNull/rejUnreadable/rejNoVt/"
             "rejGidZero/rejOutOfRange/rejTeamMissing) and `dead` is counted but never rejected; "
             "(4) both team offsets are printed on the raw elements with their distinct counts and "
             "the choice is justified; (5) every hook prints armed/slotRva/liveSlots/"
             "firstCallTick/hits every tenth tick, and a slot with no hit after 30 ticks says "
             "`never dispatched`; (6) the 0x1009290 table is interrogated -- four of its instances, "
             "their ids, teams, dead bytes, owners and the words at +0x08/+0x40/+0x4c/+0xd0 -- and "
             "four identical ids veto the hook; (7) best and summary are one decision: the first "
             "ranked candidate whose summary yields an instance is the best, and the summary now "
             "says WHY it extracted nothing; (8) the actuator's `this` must pass the mode test "
             "(class table in __DATA_CONST and [this+0x28] == the walked manager) before any "
             "write, and `setpred=` is renamed `setpredFn=` because it was always a fingerprint, "
             "not a store; (9) `no elements in container` and `all elements rejected` are "
             "different sentences, and the second one prints the reasons");

    tnx_logf("plan v52: (1) text tables are refused by the trail before they are scored - the v51 log "
             "shows why (raw[0]=FutureGi, raw[1]=rlMainAt, raw[0]=TID_BOT_), and the "
             "walk now counts them as rejAscii; (2) a slot that was installed through pointer slots "
             "reports armed=1 with the slot count instead of armed=0 because its spec has no slotRva "
             "of its own; (3) six direct hooks are added on functions the engine itself calls "
             "(getTeamStars, addGameObject, generateGameObjectGlobalID, findOwningTeam2, "
             "MessageManager::receiveMessage, setPredictionXY), installed through pointer slots "
             "only -- runtime inline patching is not supported, so a target that no data slot "
             "points at reports not-found instead of pretending to be armed; (4) the owner vote is ranked by team count first, so a text table with sixteen "
             "ids can no longer beat the container that carries two teams, and a two-team owner is "
             "adopted on the pass it appears; (5) the dodge falls back to that owner instead of an "
             "empty trail; (6) the dead byte at +0xd0 is measured - zero, one, other - and the "
             "decision to use it is deferred until the measurement says it is a flag");

    tnx_logf("plan v54: (1) the census tables that actually carry instances (0x100a770, 0x1008d30) "
             "are hook targets too, through the slot RVAs the census printed (E1-E4), so the "
             "question of who fires is asked of the classes the game uses; (2) the ClientInput route "
             "is armed as E5/E6 (setClientPredictionMoveTo, sendMovement) and announces itself when "
             "five passes find no source at all; (3) a container must be half objects to enter the "
             "trail - under that it is refused as weak and the ratio is printed on every trail "
             "line; (4) C2 reports weak when its slot count falls below a hundred, where the 22:36 "
             "run had 443; runtime inline patching is not supported, so every one of these is a "
             "data slot or nothing");

    tnx_logf("plan v55, from the 23:05-23:09 v53 run: (1) the six direct targets are removed - all "
             "six reported slots=0, so no data slot anywhere points at them and runtime inline is "
             "not supported; their rows now hold slots of the class tables that really carry "
             "instances (0x10078b8, 0x10086c0, 0x1008c28, 0x1009290); (2) the owner the vote adopted "
             "(0x11ee08890, two teams, 21 objects) has an EMPTY array header (array=0x107fc8a88 "
             "count=0), so adoption now has to pass that test and a refusal says which container to "
             "hunt for instead; (3) the chain probe never logged one candidate and its budget was "
             "spent (chain=10740163/65536 chainSkip=1883557) - it counts which gate rejects each "
             "candidate, resets its budget on every pass, and prints the first four near misses with "
             "the mode and manager windows so the next log shows the real offsets; (4) objhit lines "
             "carry pos=(x,y), the field the dodge cannot work without");

    tnx_logf("plan: the v45 log answered the question v45 was built for and broke one assumption "
             "underneath it. ANSWERED, from the objhit dump: the live objects carry class tables of "
             "their own - 0x100a770 under three heap-owned objects, plus 0xf923e0, 0xf92468, "
             "0x1014f70, 0x1008be0, 0x1009290 - and none of them is in the nine-entry vtprobe list, "
             "which is the whole explanation of hooks fired=0 of 7. Also answered: +0x20 never "
             "repeats (maxVotes=1 in all three passes, a different topOwner each time), so no vote "
             "can ever name the manager through that field, and the 0x1008d30 family that fooled the "
             "19:51 run is now correctly classified image instead of becoming a capture. BROKEN: the "
             "20:06 conclusion that vtprobe=0 was measured over a COMPLETE sweep. Both 20:22 passes "
             "scanned ~540 MB and both were cut off by the fixed 512 MB budget, but pass 1 started "
             "at 0x0 (mostly memory BELOW the window) and pass 3 at the window low, so they were cut "
             "off over different memory - and the ninth counter duly read 0 on the first and 92502 "
             "on the second. So v46 (1) makes the budget follow the window and prints budget=/"
             "budgetHit=/readTo=, (2) resumes a budget-cut pass at the exact address it stopped "
             "instead of past the whole region, (3) splits the accumulated vtprobe= into "
             "vtprobePass=/vtprobeAll= and names the first address behind each non-zero counter, and "
             "(4) replaces the nine-name list with a census: every 16-byte aligned word pointing into "
             "__DATA_CONST or __DATA is counted per class table, with the number of instances, how "
             "many of them passed the full object record layout (shaped=), and how many read the same "
             "at +0x00 and +0x20 (ownerEqVt=, the 19:51 signature as a count). vtslots then prints "
             "the first slot RVAs of the two most interesting tables - the hook targets for v47. And "
             "(5) one more split, because the 20:22 run put 398 of its 597 shaped words in "
             "ownerNoRegion and that number has two opposite explanations: the window is rebuilt "
             "every tenth attempt and it SHRANK during that run from 7776 MB to 567 MB, so an owner "
             "above the window high is a WINDOW problem while an owner in no region at all is a "
             "REGION problem. They are now ownerAboveWin= and ownerNoRegion=, and objShaped= is "
             "counted uncapped so the identity hits+skipped+ownerImg+ownerNoRegion+ownerAboveWin = "
             "objShaped can actually be checked - v45 printed the dump's capped count there, which "
              "made the check impossible exactly when there was something to check");

    tnx_logf("plan v75, from the v74 run: the trail's best candidate was a STRING TABLE "
             "(mgr=0x101d65f58, count=25, live=10) whose raw elements are TID_SHOP and _LEGENDARY, "
             "while the walk reported rejAscii=0 on those very elements - so the ASCII test was the "
             "first bug: it read the WORD AT an element and demanded eight printable bytes there, "
             "which can never hold for an element that IS the text. v75 therefore (1) tests the "
             "element's own eight bytes as well, (2) measures the text share over the first 32 "
             "elements of every array-header candidate BEFORE it is scored and records the container "
             "as refused when more than 30%% of them are text, (3) counts an element as live only "
             "when its id is non-zero and below one million, its team is inside 0..15 and both "
             "coordinates are inside +/-100000, (4) lets the best candidate be only a container with "
             "at least two distinct teams and two distinct positions, so a text table can no longer "
             "win on live alone, (5) prints ascii=, asciiRatio=, teamDistinct= and posDistinct= plus "
             "a REFUSED reason= on every trail line, (6) vetoes any object-vote owner whose elements "
             "repeat a single id, and (7) doubles the array probe budget to 131072 so the pass is no "
             "longer cut off before the battle container appears");

    tnx_logf("plan v76, from the binary audit of the proposed v76 plan: two of its three "
             "offset/hook premises fail against bin/NullsBrawl, so v76 (1) keeps the owner "
             "offset at +0x20, because setOwner at 0xa2d250 really does str x1,[x0,0x20] at "
             "0xa2d268 and the v74 objhit lines already agreed with it, (2) keeps coordinates "
             "on the virtual slots 0x88/0x90, because the plan getX 0xae4a1c and getY "
             "0xae4a24 are not accessors at all but one mid-function ldr x8,[x8,0x88] / blr x8 "
             "dispatch, (3) does not hook table 0x10086f8, because 0x10086f8 = 0x10086c0 + "
             "0x38, i.e. slot 7 of the table already armed as D10, and 0x1008d30 slot0/slot1 "
             "are already E3/E4, (4) arms instead the five slots that are both "
             "class-specific and still unhooked - 0x10086c0 slot21/slot23 and 0x1008d30 "
             "slot2/slot3/slot7, all verified function starts with exactly one vtable "
             "reference each, while the plan 0xb854a8..0xb85a80 were dropped because each "
             "carries 448+ references in other tables, (5) holds the vote scan for the first "
             "12 s and stops scanning the lobby, resuming from 20 s on the 10 s bucket, so a "
             "lobby run can no longer raise a TID_SHOP trail candidate");

    tnx_logf("plan v77, from the v76 run: the scan was never blocked - v76 scan held to tick=12 "
             "and v76 scan fallback at tick=20 both fired and seventeen heap passes ran - so "
             "the gate is not what stopped the trail. The gate is a pure function of "
             "g_modesig_hits, and that counter stayed 0 for 150 ticks, which means the mode "
             "signature matched nothing, not that the detector was bypassed. v77 (1) raises "
             "TNX_MANAGER_PROBE_LIMIT from 131072 to 1048576 because the run reported "
             "loose=1213951 candidates against a cap of 131072 and skipped=814613, and the "
             "engine itself printed ARRAY TEST BLIND - only one candidate in seven was ever "
             "measured, which is enough to explain live=0 on all eight recorded trail "
             "candidates, (2) tightens the mode signature to a class table in __DATA_CONST or "
             "__DATA, because all three modehit[near] lines carried vtSeg=__TEXT and an "
             "in-image word outside the data segments is code, not a class, (3) adds a battle "
             "fallback that can fire only on objects passing tnx_object_live, counted over "
             "the whole 64-entry objhit set rather than the 24 printed lines - the plan wanted "
             "the fallback on raw objhit counts, and the run shows why that would misfire: "
             "the team=4/5 objects it cites are class 0x100a770 instances whose gid reads "
             "1187333632, far outside the 1..999999 the tweak calls live, and the vtcensus "
             "reports ownerEqVt=2446 of count=2597 for that class, so +0x20 there is the "
             "object own class table and not a manager, (4) prints fb=liveObjs=liveTeams= on "
             "the heartbeat and one OFF line at tick 30 so the log answers whether the "
             "fallback declined rather than leaving it to be inferred, and (5) does not group "
             "by +0x3c, because own is 0 or 1 on exactly those 0x100a770 objects and would "
             "group 2696 lobby instances into two fake teams");

    tnx_logf("plan v78, from the v77 run: v77 made the scan heavier and the log says so. Not one "
             "votescan heap pass completed in the whole 61 s run - the only votescan lines are "
             "the two __DATA/__DATA_CONST ones at t=0.3 s - while the refusal counter climbed "
             "82000 -> 402536 by tick 60, against 259807 at tick 100 in v76. That is the ARRAY "
             "TEST BLIND trade going the wrong way: eight times the measured candidates costs "
             "eight times the walk, in a process that has no scene loaded. So v78 (1) puts "
             "TNX_MANAGER_PROBE_LIMIT back to 131072, (2) parks the heap walk while the armed "
             "set is silent - the run reports hooks total fired=0 armed=29 of 32 slots at every "
             "reported tick from 10 to 60, which is the cheapest proof available that no hooked "
             "class is being dispatched, and the same counter read 2016345 at tick 100 in v76, "
             "so it does separate the two states, (3) resumes on the first dispatch and retries "
             "once every 300 parked ticks, so a container that only a scan can find stays "
             "reachable, and (4) prints parked= on the heartbeat plus one line per park and "
             "resume, so the next log shows the decision instead of leaving it to be inferred");

    tnx_logf("plan v81, from the v80 run and the binary audit of the proposed plan: (1) the scene "
             "pointer the engine itself returns from 0x8c5130 is now an EDGE - the alert fires when "
             "the pointer goes from null to non-null at state==5, so a second battle raises a "
             "second alert; the once-per-process latch is deleted, (2) the chain globals are reset "
             "together, in one function, whenever the state leaves battle or the pointer changes, "
             "so nothing can be inherited, (3) mode is renamed scene and manager is renamed "
             "players, because 0xac3e74 receives the scene and reads players from scene+0x28, "
             "(4) the drop-after-3-silent-ticks is deleted - the engine's global is the authority "
             "and a missing class table is a read failure, not a verdict - and (5) the six hook "
             "targets that sat on the two RENDER classes 0x1008d30/0x1009290 are replaced by six "
             "class-specific slots of the scene's OWN class table 0xfe9d00, which the constructor "
             "at 0x8c5184 installs and whose neighbours 0x8c5130/0x8cdfd4 are the very functions "
             "the engine uses to reach the scene; the container's elements are then judged by "
              "tnx_is_battle_object, which accepts a data class table plus a kind at +0x35c "
              "instead of demanding a global id that the container does not carry");

    tnx_logf("plan v82, from the v81 run and the binary audit of the chain it walked: the scene "
             "chain WORKS - scene=%%p style lines appear with no scan - but the object at "
             "scene+0x28 is the battle CLIENT and not the container. The binary says so twice: "
             "0x8ce048 is a screen factory that builds state 5 as new(0x98) plus 0x8c51f8, whose "
             "constructor stores 0xfe9d00 at [+0] (so the scene class is right), and the scene's "
             "own slot +0xb0 at 0x8cc6dc null-checks [+0x28] and logs \"Init. No battle client\" "
             "when it is empty - so [+0x28] is a client object with fields at +0x7c, +0x108 and "
             "+0x1a0, not a vector header. findOwningTeam 0xac3ddc reads [+0x28] off ITS receiver "
             "and only then [+0x0]/[+0xc] off the result, so the chain needs one more hop: "
             "container = [[scene+0x28]+0x28]. v81 stopped one hop short, which is why count=6 "
             "came out of a client field and the six \"elements\" were the client's own leading "
             "pointers. Therefore v82 (1) reads both hops, tests each with the same "
             "array/count/cap header, publishes only the one that passes and dumps both once per "
             "scene with a segment code per qword, (2) reads the element kind where the engine "
             "reads it - 0x382cc8 is ldr x0,[x0,0x10], so the kind lives at [[element+0x10]+0x35c] "
             "and never at [element+0x35c], which is the arithmetic error that made every v81 "
             "element report kind=0, (3) retargets B1/B2/B3 from the 0xff5720 slots, which "
             "recorded zero hits in two whole runs, onto three class-specific slots of the class "
             "table 0xf9e248 the container's own elements carry (+0x28 @568d0c, +0x40 @569694, "
             "+0x08 @568bf4, one data reference each), because 0xf9e248+0x28 is the dispatch "
             "findOwningTeam performs on every element of every walk, and (4) records that "
             "0xf9e248 is NOT unreferenced: coderef.py matched only a single add after adrp and "
             "missed the split immediate the constructor emits at 0x5652dc/0x564d44/0x568c08 "
             "(adrp; add #0x238; add #0x10), so every earlier zero-reference verdict on this "
              "table is a tool artefact and not a fact about the binary");

    tnx_logf("plan v83, from the v82 binary re-audit: the two-hop chain is RIGHT, the hook retarget "
             "that came with it is not. Re-read from the code, not from the plan: the battle "
             "function at 0x52b2a0 takes the scene with bl 0x8c5130 and at 0x52b180 does "
             "ldr x24,[x0,0x28], then reads the mode variation at [x24+0x124] and walks [x24+0x28] "
             "with the count at [+0xc] and the array at [+0x0] - so the receiver of those walks is "
             "the CLIENT, not the scene, and findOwningTeam2's only caller 0x52b864 passes that "
             "same x24. container = [[scene+0x28]+0x28] therefore stands and v81's count=6 was a "
             "client field. Note also that the call those walks make between the load and the "
             "count, 0x1c1c0, is a bare ret in this image, so the address the count is read from "
             "is exactly the one loaded. The kind is confirmed the same way: 0x382cc8 is b "
             "0x117050 = ldr x0,[x0,0x10], findOwningTeam reads [def+0x35c] against 0x1a, and "
             "both the battle walk and findOwningTeam2 read [def+0x68] against 0x36/0x38, so "
             "[def+0x68] is a second per-type field that this run prints only through the census. "
             "B1/B2/B3 go BACK to the 0xff5720 slots (+0x28 @0xa2e5b8, +0x18 @0xa2d250 setOwner, "
             "+0x38 @0xa2d6ac) because the v82 retarget rested on a misreading of 0xf9e248+0x28: "
             "that word is 0x568d0c, which str's the table 0xf9e268 into [+0] and calls an "
             "imported function - destructor-shaped, returning void - and it cannot be the slot "
             "the engine calls and compares against 3 on every container element; 0xff5720 by "
             "contrast is installed by the constructor at 0xa2e2f4, which stores it at [+0] right "
             "after its base constructor, and its [+0x18] is the exact method addGameObject "
             "dispatches. No slot is claimed for the element class until the census prints the "
             "class the elements really carry, which is what hypoElem= now reports. v83 also "
             "fixes a compile error that neither gate sees: tnx_container_census read def "
             "without declaring it");

    tnx_logf("plan v84, from the v83 run: the chain delivered a real container. On the second "
             "scene hop1 0x118033980 and hop2 0x11e595880 BOTH carried a header, chosen=1, and the "
             "census on it read accepted=2 of 16 with teams=2 gidSeen=2 classRva=0xff57b0 "
             "hypoElem=0 - so the elements carry 0xff57b0 and 0xff5440 and the 0xf9e248 hypothesis "
             "is retired; on the first scene, where hop2 was still array-null, hop1 was chosen and "
             "its six elements reported classRva=0xf9e248, which is what made that table look like "
             "an object class in the first place. Three fixes: (1) the walk now takes the chosen "
             "hop - tnx_refresh_array adopts the published g_players_object/array/count and "
             "g_hop_chosen instead of re-deriving scene+%#llx one hop, which is exactly why "
             "array ready printed manager=0x118033980 count=6 (the client) while the census "
             "measured 0x11e595880 count=16, and it clears the array when no hop passed so the "
             "dodge falls back to the objhit list rather than walking a stale container, (2) the "
             "pending gate now runs the very header test the hop test runs, "
             "tnx_container_header - array at +0x0 heap-resident, count at +0x%#llx, cap at "
             "+0x%#llx, count<=cap<=ceiling - instead of guessing a count among +0xc/+0x8/+0x10 "
             "with a 2..N window, which is why 0x135eef1e0 was refused with count=1 while the hop "
             "test accepts that same shape, and the array probe is now recorded and not obeyed, "
             "(3) the not-a-class-table reject prints one line per vt plus a counter, because "
             "hotflag 0x109bd86c0 arrives from the 435 slots of D13 and filled the log with tens "
             "of thousands of identical lines. Also confirmed once more: +0xd0 is not a dead flag "
             "and +0x20 is not the owner, so neither may be used as object identity",
             (unsigned long long)TNX_MODE_MANAGER_OFF, (unsigned long long)TNX_MGR_COUNT_OFF,
             (unsigned long long)TNX_MGR_CAP_OFF);

    tnx_logf("plan v85, from the v84 run: the container is real and it is polymorphic - its "
             "elements carried 0xff5440 with gid 1000009/1000011, and 0xff57b0 and 0xff5100 beside "
             "it, so three classes live in one array. Four changes. (1) The hop choice is sticky: "
             "once hop2 passes the header test it is kept and the client is never chosen again, "
             "because on the first scene hop2 was array-null, the fallback took hop1, and hop1's "
             "own six elements reported classRva=0xf9e248 - which is the whole origin of the "
             "retired 0xf9e248 reading; the sticky flag and the chosen hop are cleared by the "
             "scene reset together with the other chain globals. (2) man walk and census read one "
             "container: tnx_refresh_array takes the published globals, and with (1) the hop "
             "it takes cannot be a different hop from the one the census measured. (3) The third "
             "hop through 0x991440 - players+%#llx and then +%#llx - is deleted: it dead-ends in a "
             "block whose first word is itself and whose rest is zero, so nothing is read past the "
             "container. (4) New instruments for the offsets that are still unknown: a full "
             "+0x00..+0x%x dump of one accepted element (up to %d of them) plus 16 qwords of the "
             "objects held at elem+%#llx, which is the definition the engine reads in 0x382cc8, "
             "and at elem+0x40, plus 8 qwords of every heap pointer at scene+0x28/+0x30/+0x38/"
             "+0x40/+0x58 and client+0x18/+0x20/+0x30/+0x38/+0x40/+0x58/+0x68/+0x80, each with "
             "the container-header verdict, so a second container - where the projectiles would "
             "have to be - is recognisable from the log alone. Still NOT known and not to be "
             "assumed: the element's coordinates (no float pair at +0x30/+0x34/+0x80), its own "
             "character pointer, or whether this array ever holds projectiles at all. The element "
             "offsets are disputed - +0x4c/+0x48/+0x50 for team/index/gid against the contract's "
             "+0x40 and +0x8 - so the dump is the instrument that settles it, not another offset "
             "change", (unsigned long long)TNX_PLAYERS_NEXT_OFF,
             (unsigned long long)TNX_NEXT_MEMBER_OFF, (unsigned)(TNX_ELEM_QWORDS * 8),
             TNX_ELEM_DUMPS, (unsigned long long)TNX_ELEM_DEF_OFF);

    tnx_logf("plan v86, from the v85 run and the vtable audit: the container's element type is the "
             "WORD at [vt+%#llx], a two-instruction getter of the form mov w0,#N; ret, and that is "
             "what the engine itself compares - findOwningTeam skips every element whose w0 is not "
             "0 and the battle walk plus findOwningTeam2 take only w0==3, which is why the same "
             "slot looked contradictory when it was read as one predicate. Five changes. (1) The "
             "census classifies by that word: 0x14c81c is 0, 0xa31768 is 1, 0x9f4ec8 is 2, "
             "0x314ca0 is 3, 0x490b54 is 4, 0x86f494 is 5, 0x370688 is 6, 0x490d94 is 8, and "
             "anything else prints type=unknown with the raw word instead of rejecting the "
             "element, so a type outside that list can never turn into accepted=0 again; the old "
             "gid/kind rule survives only as the accept= field and filters nothing. (2) The census "
             "is forced onto hop2: its budget is reset the first time hop2 is the chosen hop, "
             "because in the v85 run hop2 filled at tick 39 with count=8 long after the census had "
             "been spent on hop1, whose class 0xf9e248 has no type getter at all. (3) Each element "
             "line carries def35c and def68 - the two fields the engine reads at [[elem+%#llx]+"
             "%#llx] and [[elem+%#llx]+%#llx] - next to the hypotheses team4c/gid50/byte48 and the "
             "contract readings team40/gid8, and the head dump covers +0x00..+0x%x for the first "
             "four elements so the log shows whether +%#llx is a definition pointer or a float "
             "pair. (4) The contract drops +0xd0 as a dead flag and no longer treats +0x20 as "
             "object identity, and it records +0x88/+0x90 as what they are: float getters reading "
             "+0x10 and +0x1c, with setters in slots +0x70 and +0x80. (5) No hook is armed on the "
             "type getters here: they are two instructions and would fire on every dispatch, "
             "0x14c81c must never be armed, and 0xb90a28 must never be called because no bl "
             "anywhere in __TEXT reaches it. For v87: the type-3 class table 0xfd4840 carries "
             "float getters at +0x10/+0x1c and at +0x100/+0x104 with matching setters (slots "
             "0x1b0/0x1b8/0x1c8/0x1d0), which is where the coordinates have to be read, while "
             "0xffb4c8 has the same type-3 getter but no float accessor and six other type codes, "
             "so it is a descriptor block and not the class vtable",
             (unsigned long long)TNX_TYPE_SLOT_OFF, (unsigned long long)TNX_ELEM_DEF_OFF,
             (unsigned long long)TNX_KIND_OFF, (unsigned long long)TNX_ELEM_DEF_OFF,
             (unsigned long long)TNX_DEF_68_OFF, (unsigned)(TNX_ELEM_QWORDS_2 * 8),
             (unsigned long long)TNX_ELEM_DEF_OFF);

    tnx_logf("plan v87, from the v86 build: one type error and nothing else - tnx_element_type "
             "read the type slot into a uintptr_t while tnx_read_ptr takes a void**, so it now "
             "reads into a void* and strips that, with no change to what it computes. The run has "
             "exactly one question to answer, the classRva and the type of the FIRST element of "
             "hop2, so the census is now taken only while hop=%d is the chosen hop and only once "
             "hop2 carries a count above zero - it waits instead of measuring an array-null hop - "
             "and the summary line prints hop= so the hop cannot be inferred, with a one-shot line "
             "saying the census was forced on hop2. Every element of that census also prints its "
             "four float fields read as single precision at +%#llx, +%#llx, +%#llx and +%#llx once "
             "the first element's classRva is %#llx, because that class exposes exactly those as "
             "float getters in its slots 0x1b0/0x1b8 and 0x1c8/0x1d0, and the head dump prints the "
             "same element twice in one pass, as raw qwords over +0x00..+0x40 and as those four "
             "floats. No census is taken on hop1 in this run at all: 0xf9e248 has no type getter at "
             "[vt+%#llx] and can only produce type=unknown",
             1, (unsigned long long)TNX_FLOAT_LO, (unsigned long long)TNX_FLOAT_LO2,
             (unsigned long long)TNX_FLOAT_HI, (unsigned long long)TNX_FLOAT_HI2,
              (unsigned long long)TNX_TYPE3_CLASS_RVA,
              (unsigned long long)TNX_TYPE_SLOT_OFF);

    tnx_logf("plan v88, from the v87 run: six fixes, and the first is what made the run "
             "unreadable. (1) The walk and the census read different containers because the "
             "dodge resolved its manager as scene+0x28 once and kept it: the probe now "
             "recomputes the container from g_hop_chosen and g_players_object on EVERY "
             "tick, re-probes when that pointer changes, and refresh_array re-reads the array "
             "and the count from the manager instead of taking the cached pair, so the hop "
             "switch at t=42 s cannot leave the walk on the client. (2) The element id is read "
             "at +%#llx and the +0x50 word is deleted from the code and from the census line; "
             "rejGidZero and the gidSeen counter both count that offset and nothing else. "
             "(3) One element of class %#llx is dumped in full - +0x00..+0x%x of the element "
             "and +0x00..+0x%x of the definition it points at through elem+%#llx - with +%#llx "
             "and +%#llx printed as two signed int32, so the field that splits four players "
             "into two sides is read out of the log instead of guessed. (4) Membership is "
             "[elem+%#llx] == container, counted as back= on the census and on the walk; the "
             "owner chain through owner+0 and owner+%#llx that reported back=0 is no longer "
             "consulted. (5) The float block and the head-floats line are printed for type %d "
             "only: the v87 gate tested the CLASS RVA of the first element, which is why the "
             "line still appeared for a type-0 element whose +%#llx is a definition pointer. "
             "(6) The census is taken once per container - an array address is remembered, so "
             "a repeat census needs a different container, not a different tick - which is "
             "what turned one hop2 container into four censuses with counts 4, 21, 7 and 8",
             (unsigned long long)TNX_OBJ_GLOBALID_OFF, (unsigned long long)TNX_ELEMCLASS_RVA,
             (unsigned)(TNX_ELEM_QWORDS_3 * 8), (unsigned)(TNX_DEF_QWORDS * 8),
             (unsigned long long)TNX_ELEM_DEF_OFF, (unsigned long long)TNX_ELEM_INT_A,
             (unsigned long long)TNX_ELEM_INT_B, (unsigned long long)TNX_ELEM_BACK_OFF,
             (unsigned long long)TNX_MODE_MANAGER_OFF, TNX_TYPE3_CODE,
             (unsigned long long)TNX_ELEM_DEF_OFF);

    tnx_logf("plan v89, from the v88 run: the hop fix holds - the walk switched from hop1 to hop2 "
             "on both battles and hop2 read usable=6 rejected=0 - and four things are fixed on top "
             "of it. (1) The coordinate pair is a CONSTANT now: x at +%#llx and y at +%#llx, "
             "int32, and the auto choice is deleted, because the same analysis block that printed "
             "coord pair chosen=+0x30,+0x34 in the first battle let the walk take +0x3c/+0x40 in "
             "the second, where pos= then showed the owner index and the team. The team field is "
             "pinned the same way - +%#llx, the field the run confirms as the side - for the "
             "same reason, since that rule picks a field from a sample too. (2) The census is "
             "deduplicated by container and not by array: the array pointer moves when the "
             "object array is reallocated, which is why one manager was censused twice with "
             "counts 12 and 9. (3) The walk is driven by the tick and by the count instead of by "
             "the array: while hop=%d and the count is above zero it re-probes every %d ticks "
             "and on every change of count, and the run that had four heartbeats with count=12 "
             "and no walk line at all is what that fixes. (4) dodge ENTERED is printed once per "
             "second unconditionally, with hop, coordOk and usable on the line, because in the "
             "run the dodge announced itself three times at start-up and then never again, "
             "which left it unknown whether it ran after the walk handed it coordinates",
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF,
             (unsigned long long)TNX_OBJ_TEAM_OFF, 1, TNX_WALK_EVERY);

    tnx_logf("plan v89 confirmed offsets: elem+%#llx gid, elem+%#llx def, elem+%#llx back, "
             "elem+%#llx x, elem+%#llx y, elem+%#llx team, elem+%#llx owner index; +0x4c is a byte "
             "that is not a team and +0xd0 is not a flag",
             (unsigned long long)TNX_OBJ_GLOBALID_OFF, (unsigned long long)TNX_ELEM_DEF_OFF,
             (unsigned long long)TNX_ELEM_BACK_OFF, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF, (unsigned long long)TNX_OBJ_TEAM_OFF,
             (unsigned long long)TNX_OBJ_OWNERINDEX_OFF);

    tnx_logf("plan v90, from the v89 run: the run confirmed the v89 fixes - walk coord fixed and "
             "walk team fixed appear once, hop2 then reads usable=20..29 with inRange equal to "
             "usable and rejGidZero=0 on both sides - and the dodge now enters every second with "
             "coordOk=1 and setpredFn=1 while writes stays 0. One symptom, five possible causes, "
             "and the ENTERED line could not tell them apart, so this build moves nothing in the "
             "dodge and only makes the refusal say which gate it was. (1) A gate line is printed "
             "beside ENTERED on the same tick with ownFound, own, ownTeam, targetFound, target, "
             "selfPos, targetPos, vector, clamped, actuatorReached and a single reason word, so "
             "noOwn, noTarget, noThreat, predictionZero, noActuator and degenerateVector are "
             "distinguishable in one run instead of five. (2) The three words the mode carries at "
             "+%#llx, +%#llx and +%#llx are read on every tick and logged the first time a "
             "container exists: a word that lies inside array..array+count*8 is one of the "
             "container's own elements and therefore the local player, which is the own element "
             "the dodge cannot name. (3) degenerate=%d is printed when fewer distinct positions "
             "appear than in-range elements, because the run had distinct=4 against inRange=5 and "
             "a zero vector is what two elements in one cell would produce; the dodge still "
             "computes and the flag only records it. (4) A sixth gate is reported that the plan "
             "did not ask for, because it is read from the dodge's own code and not guessed: "
             "before the store the dodge checks that the word at mode+0x28 equals the manager the "
             "walk uses and returns without writing when they differ, and since the walk was moved "
             "to the second hop while that word still names the client, this guard refuses every "
             "store and only ever logs its first six refusals - modeReal and modeChain show it",

             (unsigned long long)TNX_MODE_SLOT_A, (unsigned long long)TNX_MODE_SLOT_B,
             (unsigned long long)TNX_MODE_SLOT_C, 1);

    tnx_logf("plan v91, from the v90 run: four fixes. (1) The side is read at +%#llx and not at "
             "+0x40, because the run printed distinct(+0x40)=1 against distinct(+0x4c)=2..4 with "
             "raw elements showing plus40=1 and plus4c=-1/0/1, and the dead byte sits at +%#llx, "
             "because the run's own probe said offset=0xd4 splits four readable pointers into two "
             "zero and two one while +0xd0 is 63 on every element; a dead byte of 63 is truthy, so "
             "until this fix every element was treated as dead by the dodge. (2) The mode guard no "
             "longer compares mode+0x28 with the container the walk uses: it requires the mode's "
             "class table to be a data table and the chain mode+0x28 then +%#llx to reach that "
             "container, so hop %d stops blocking its own store. (3) The own element is searched "
             "for: every qword of mode+0x00..+0x%x and of client+0x00..+0x%x is tested against "
             "array..array+count*8, and a word that lands inside names the local player, with the "
             "offset and the element index logged; the prediction pair is only the fallback, and "
             "the dodge and the gate line call the same resolver so they cannot name different "
             "elements. (4) The reason order is corrected: noOwn is reported before noTarget, both "
             "before modeGuard, then coords and the actuator, and predictionZero is last, because "
             "the v90 run reported predictionZero while ownFound and targetFound were both zero",
             (unsigned long long)TNX_TEAM_OFF, (unsigned long long)TNX_DEAD_OFF,
             (unsigned long long)TNX_CLIENT_HOP_OFF, 1,
             (unsigned)(TNX_SCAN_QWORDS * 8), (unsigned)(TNX_SCAN_QWORDS * 8));

    tnx_logf("plan v92, from the v91 build failure and the binary read: (0) v91 did not compile; "
             "the cause was ordering and not a missing helper - tnx_mode_real, own_scan "
             "and tnx_resolve_own_2 were defined below tnx_gate_report, which calls them, so "
             "all three now sit above it; the check that should have caught this reported zero "
             "because it treated a file-level closing brace as the start of a statement and "
             "swallowed every declaration after it, and with that fixed it reports exactly the "
             "three lines the compiler reported. (1) The binary answers the actuator question: "
             "%#llx is not a function start but a shared tail of the function at %#llx, three "
             "instructions that store and return, and exactly one bl in the whole __TEXT reaches "
             "it, at %#x - so the field is written by real code and the store is callable. (2) The "
             "tweaks E6 candidate %#x is two instructions, add sp,sp,#0x30 then ret, which is an "
             "epilogue and not a send, and E5 %#x is mid-function as well, so neither is a route. "
             "(3) No store to +0x1d4 or +0x1d8 anywhere in __TEXT lies inside a method of the mode "
             "class table, so those two words are only written from outside it. (4) The side is "
             "dumped as bytes and as int32 at +0x40..+0x50 on the first %d elements, the two dead "
             "candidates are printed side by side, gid uniqueness is counted, and the written "
             "prediction is read back %d frames later as kept or overwritten",
             (unsigned long long)TNX_RVA_SETPREDICTION, (unsigned long long)0xac3e74ULL, 0xa26520,
             (unsigned long long)0x7c13dcULL, (unsigned long long)0xb90b8cULL, TNX_TEAM_DUMPS,
             TNX_VERIFY_FRAMES);

    tnx_logf("plan v93, from the v92 run: (A) the side goes back to +0x%#llx, because the team "
             "dump printed 1,1,0,0 at +0x40 and 0,2,29535,0 at +0x4c and 29535 is the byte pair "
             "0x5f 0x73, an inline string - the distinct count said +0x4c was the busier field and "
             "the busier field was a string. (B) The dead byte is not +0xd4 either: the probe read "
             "0,2,0,0 in one run and 0,0,0x0c,0 in another and called the second one a flag when "
             "0x0c is just another field, so no dead offset is used and the filter is off "
             "(deadF=%d) until a byte is proven, and the dump is split per class (classdump) "
             "because players and projectiles were being averaged together. (C) The own scan no "
             "longer accepts value==array: client+0x00 is the vector header itself and the run "
             "reported it as element[0]. (D) The actuator is finally tested on its own: with a "
             "container of two or more and the mode guard satisfied, (%d,%d) is written once a "
             "second with no own element, no target and no threat logic, and three frames later "
             "the two words are read back and every container position is printed, which answers "
             "moved - not moved - overwritten without knowing who the local player is",
             (unsigned long long)TNX_OBJ_TEAM_OFF, TNX_DEAD_FILTER, TNX_TEST_X,
             TNX_TEST_Y);

    tnx_logf("plan v94, from the v93 verdict and the binary read: prediction is rejected as an "
             "actuator - the value was written fifteen times, every write came back kept, and no "
             "element ever moved towards it - so the test write is off and the own fallback that "
             "picked an element by proximity to that dead pair is deleted: when the scan finds no "
             "own element the dodge now reports noOwn instead of naming a projectile. The binary "
             "closes the three candidate routes. (1) There is no position setter to call: a store "
             "to +0x30 immediately followed by a store to +0x34 on the same base register occurs "
             "NOWHERE in __TEXT, and the 714 and 435 raw matches were dominated by sp-relative "
             "stores, which the first pass counted as object writes. (2) The enclosing function of "
             "the E5 candidate %#x has no caller and no __DATA_CONST slot, and E6 %#x is an "
             "epilogue inside a 172-byte function that also has no slot, so neither can be reached "
             "through the only mechanism this tweak has. (3) setMoveStickState %#x is a real "
             "function but it too has no slot and no caller outside itself. (4) The one and only "
             "caller of the prediction setter is the loader at %#x, which fills fields from "
             "resource ids, so those two words belong to object construction. What is left is the "
             "client input route - the manager at mode+%#llx and the 60-byte input record whose "
             "fields are type at +0x4, x at +0x8 and y at +0xc - and that is the next thing to "
             "read out of the binary, not another guess",
             (unsigned long long)0xb90b8cULL, (unsigned long long)0x7c13dcULL,
             (unsigned long long)0x5857ecULL, (unsigned long long)0xa24278ULL,
             (unsigned long long)TNX_MODE_INPUTMGR_OFF);

    tnx_logf("plan v95, from the JS dodge and the binary: the JS build moves the character by "
             "writing a joystick that lives in the BattleScreen object, and it names eight fields - "
             "A=(+0x9b8,+0x9bc), B=(+0x9c0,+0x9c4), mode +0x8ac, state +0xed7, cos and sin at "
             "+0x8f4 and +0x8f8. Those offsets do not exist on our path: they are read here only "
             "on the scene and on its client, once a second, so a run says whether this build "
             "keeps the joystick in the same window, and a one-off scan walks every heap pointer "
             "in the first 0x1000 bytes of the scene and reports any object whose window reads as "
             "finite floats, which is the object to write. The binary says the same thing from the "
             "other side: +0x9b8, +0x9c0, +0x9c4 and +0xed7 appear ZERO times as an immediate "
             "anywhere in __TEXT, and the function that contains the tweaks own UPDATEMOVEMENT "
             "address reads only +0x4..+0x140 with no float cluster, so those offsets belong to "
             "another build and another object and are not ported as they stand. The target is "
             "still a read-out, not a guess");

    tnx_logf("plan v96, from the pointer-slot check the plan asked for: there is NO slot for any "
             "of the candidates - a direct scan of every eight-byte word of __DATA_CONST and "
             "__DATA, in all three encodings, finds nothing pointing at setMoveStickState %#llx, "
             "at getClosestAnyCollision %#llx, at the E5 or E6 addresses, or at the updateMovement "
             "candidate, and fixups.json agrees with zero entries for each. Both callable routes "
             "are therefore closed for the same reason as before: this tweak installs hooks only "
             "through a data slot, and there is none to install into. What is left is the third "
             "route, and it needs no slot: every second the scene, its client and every heap "
             "pointer found in the first 0x800 bytes of the scene are read as a %#x-byte float "
             "window, compared with the window of the previous second, and only the offsets that "
             "changed are printed. A joystick is a handful of adjacent floats that move while the "
             "rest of the window stands still, so the object and the offset fall out of one run "
             "without a hook and without assuming the JS layout",
             (unsigned long long)0x5857ecULL, (unsigned long long)0xbd55c4ULL,
             (unsigned)TNX_SPAN);

    tnx_logf("plan v97, from the three blind spots of the v96 detector: (1) the sample is taken "
             "only while the battle is live - the container is walked every tick and if no element "
             "changed its position the windows are not compared and one line says the sample is "
             "held, because at one hertz a joystick returns to neutral between two samples and a "
             "still window would then read as absence when it is only idleness. (2) A big count is "
             "no longer a dead end: the changed slots are collected and split into runs of "
             "adjacent slots with a gap of at most %d, and each run is printed with its start, its "
             "length, its first and last value, and quiet=%d, which says whether the %d slots on "
             "both sides stood still - that is what separates a vector from a buffer of counters. "
             "(3) Two free signatures run on the same data: a run of two to %d adjacent "
             "pair satisfies cos squared plus sin squared is one within %d is printed as rotation, "
             "and a short run inside a quiet window is printed as a candidate. The whole window is "
             "now compared as raw words rather than filtered to finite floats, so a state kept as "
             "an int, which the JS build has as a halfword, is caught by the same pass. Clipping "
             "stays out of the port until there is an actuator, but the note is recorded here: the "
             "threat segment has to end where the projectile hits a wall, because a range that "
             "runs to its theoretical end makes the dodge flee a bullet that cannot reach the "
             "point, and that is correctness and not an optimisation",
             TNX_GROUP_GAP + 1, 1, TNX_QUIET_2, TNX_GROUPS_MAXLEN,
             (int)(TNX_COSSIN_TOL * 1000.0f));

    tnx_logf("plan v98, from the review of v97 before its run: (1) the rotation signature now tests "
             "the changed array and not the span - only two CHANGED slots that are strictly "
             "adjacent are paired, so a normalised vector anywhere else in the same window cannot "
             "raise the line, which was a real false positive in v97. (2) The receivers of the six "
             "V slots are added to the bases: those slots land on the scene object itself (class "
             "0xfe9d00, the object the JS build calls BattleScreen), while the A and B slots land "
             "on elements, which is the wrong level for a joystick. (3) Two sampling fixes: on "
             "resume every snapshot is dropped, so the first comparison after a hold is against a "
             "fresh baseline instead of a window that is N seconds old, and a forced sample fires "
             "after %d seconds without movement, because a player holding the stick into a wall "
             "does not move and that is exactly when the joystick state is most informative. (4) "
             "The wall clipping is written now rather than when the actuator arrives, and it is "
             "already exercised: four synthetic segments run against an eight by eight grid with "
             "one wall column at start-up and report pass and fail, so the clipped range, the "
             "remaining range and the time to hit can be trusted before they are ever pointed at "
             "the real tilemap", TNX_FORCE_SECS);

    tnx_logf("plan v99, from the v98 run and the corrections to its reading: (1) the sampling window "
             "grows from 0x600 to %#x bytes, so the generic diff now covers +0x8ac, +0x8f4, +0x8f8 "
             "and +0x9b8 of every base, which the v98 window stopped short of; the joy probe already "
             "read those offsets directly and without any window, so the window was never what hid "
             "them - what it hid is the same offsets from the group and the rotation analysis. (2) "
             "The input manager at scene+%#llx is added as a base of its own, ahead of the V slots "
             "and the heap children, because the only normalised pair of the v98 run was found on it "
             "and not on the scene, and a list capped at %d bases can starve a late addition. (3) "
             "The own scan covers %#x bytes on each of three objects instead of 0x300 on two: the "
             "the v98 log proves the container, the coordinates and the team are real, so the one "
             "missing fact is which element is the local player. (4) The input manager can be "
             "driven as an actuator: the pair at +%#llx and +%#llx is written once a second behind "
             "TNX_INPUTMGR_WRITE, which is off by default, and the sample resumed line of the "
             "same run answers whether an element moved - the same shape as the prediction test, "
             "which came back kept and moved nothing. (5) Adoption refuses an object whose first "
             "word is not a class table inside the image, so the ASCII word that E2 reports as its "
             "vtable cannot become the scene. (6) A static second is visible: a base with changed=0 "
             "prints no window line at all, so the run now reports when every compared base was "
             "byte-identical, which the v98 log could not tell apart from a second that was never "
             "sampled. (7) The one real division hazard of the clip walk is closed: the cell was "
             "divided before it was checked, so a caller passing a zero cell divided by zero first "
             "and the guard four lines below it could not have caught that - the guard now runs "
             "before both divisions and a fifth selftest case passes cell=0. No guard is added for "
             "a division by a remaining range, because nothing in this build computes a time to "
             "hit: that phrase in the v98 plan is prose about a future actuator and is not a symbol "
             "anywhere in the code", (unsigned)TNX_SPAN,
             (unsigned long long)TNX_MODE_INPUTMGR_OFF, TNX_BASES_2,
             (unsigned)(TNX_SCAN_QWORDS * 8), (unsigned long long)TNX_INPUTMGR_COS_OFF,
             (unsigned long long)TNX_INPUTMGR_SIN_OFF);

    tnx_logf("plan v100, from the first CI build of v99, which did not compile: (1) the write path "
             "reached for mach_vm_write, and the iOS SDK declares that function in mach/mach_vm.h "
             "while this file imports mach/mach.h and mach/vm_map.h - vm_map.h carries "
             "vm_read_overwrite and the mach_vm_* TYPES come from vm_types.h, which is why the "
             "reads compiled and the write did not; the error was 'use of undeclared identifier "
             "mach_vm_write; did you mean mach_vm_range'. (2) The local compile gate could not have "
             "caught it: the gate compiles against hand-written stub headers and declares whatever "
             "the source calls, so it marked the call clean while the SDK had no such declaration "
             "in scope, and that is the one class of error a stub prelude cannot see. (3) The write "
             "no longer needs a mach call at all: the target is heap memory that the same run has "
             "already read back as finite floats, so it is mapped and writable, and a plain store "
             "closes the same hole with no SDK symbol; the read-back of the two words after the "
             "store is printed as kept=%%d and is the failure signal a store can give. (4) The gate "
             "now audits the mach and vm calls in the source against the set that the last green "
             "build used - vm_read_overwrite, vm_protect, vm_region_64, mach_task_self, "
             "mach_port_deallocate - and reports any call outside it as a header question, so "
             "mach_vm_write is named as a foreign call instead of passing as clean");

    tnx_logf("plan v166, from the 15:18 run: (1) the slide is the v164 write. That log has the "
             "joystick pair written every frame and kept by the game (v165 want=(500,0) after=(500,0)) "
             "while v164 pushes the APPLIED pair from own=(1869,6166) to (2555,5588) in one step, so "
             "the body is carried and the run cycle never starts. The applied pair and the pair at "
             "+0x10c are therefore not written while the stick answers, and the stick - not a "
             "position - is what the client consumes, which is what makes the walk read as player "
             "input. The threat path now feeds the stick as well, so both paths move through it. "
             "(2) The delays are gone: the dodge interval 100 ms to %d, the heading lock 60 ms to %d "
             "and the release 120 ms to %d, so a new heading is taken on the frame it is better "
             "instead of after a hold. (3) The dodge engages far earlier: the engage radius 200 to "
             "%.0f against a threat the scoring already inflates by %.0f, which is roughly a second "
             "and three quarters of travel at %.0f units per second instead of the last moment. (4) A "
             "watchdog watches own while the stick is engaged: %d frames without movement and the "
             "direct pair is turned back on for the run, so a cosmetic stick cannot leave the "
             "character standing still; the v167 ladder below replaced that single fallback with one "
             "channel per step", TNX_DODGE_MIN_MS, TNX_LOCK_MS,
             TNX_RELEASE_MS, (double)TNX_ENGAGE, (double)TNX_INFLATE,
             (double)TNX_SPEED, TNX_STUCK_FRAMES);

    tnx_logf("plan v167, from the 15:30 run and the reference implementation: (1) the move is the "
             "client input command plus the mode function %#llx, which is exactly the pair the "
             "REvengeBS autododge sends - setClientPredictionMoveTo(logic, tx, ty, 1) and a type 2 "
             "client input - and no joystick pair and no applied pair are written, because a field "
             "write carries the body while the engine's own function carries the walk. The 15:30 run "
             "proves the command lands: queuePush shows seqBefore 37 seqAfter 38 and qBefore 0 "
             "qAfter 1, so the queue takes it. (2) The joystick pair and the applied pair are still "
             "written, but only after own has stood still for %d frames of live threat, one channel "
             "per step, so the log names the route that actually moves the character instead of "
             "guessing. (3) Own-team shots no longer count as threats: the projectile now carries its "
             "team and is dropped when the same frame shows shots on both sides, because a field that "
             "never differs cannot tell a teammate's shot from an enemy's. (4) While own is dead the "
             "dodge is held and the joystick pair is neutralised once, so a corpse is not steered and "
             "the next life starts on the input route with the heading, the write clock and the "
             "ladder cleared", (unsigned long long)TNX_MODEPAIR_RVA, TNX_STUCK_FRAMES);

    tnx_logf("plan v168, from the v167 CI failure: (1) the build died on an undeclared "
             "TNX_STUCK_FRAMES, a name the watchdog used and the same edit never defined, so "
             "this file is now checked for used-but-undeclared TNX_* and g_* identifiers before it "
             "is written and the define is present. (2) Dead code removed: the v147 dry branch, "
             "unreachable once the leaf setter was re-enabled; the v166 fallback block whose flag no "
             "code could set; and the three v151 best globals that nothing assigned while the log "
             "printed them as measurements. (3) The threat list uses the reference's own two "
             "filters: a shot flying away is dropped and a shot that cannot close on the character "
             "is dropped, and the range each one is judged against is learned per projectile class "
             "from the distance that class has actually flown, with a %.0f fallback until a class "
             "has been seen %d times. (4) A heading whose walk target leaves the map loses %.0f of "
             "score, the shape of the reference's wall penalty, using the clamp this file already "
             "had rather than a tile lookup whose signature is unverified; the wall count and the "
             "learned ranges are printed so the next log carries the numbers",
             (double)TNX_THREAT_RANGE, TNX_RANGE_MIN_SAMPLES, (double)TNX_WALL_HIT);

    tnx_logf("plan v169, from the 16:01 run: the dodge did not move once - no v151 write, no v160 "
             "write, no joystick pair - and the log says why in four lines: 'own is dead' at 16:02:07 "
             "and 'own is alive again' at 16:02:31, so the v167 death guard was holding nearly the "
             "whole run. Its signal is the byte the walk reads at +%#llx, and that byte reads 0, 1 and "
             "63 on live objects in the same log, so it is not a death flag; the guard is now off and "
             "the three candidates - that byte, own+0x140 and ctrl+0xf80 - are printed every time one "
             "of them changes, so the next log names the one to guard on. A second line reports a "
             "threat list that the new filters emptied, because those two states looked identical "
             "from the outside. The learned range is floored at %.0f and can only raise the reach, so "
             "a class first met in a short fight cannot teach the filter to ignore its real shots",
             (unsigned long long)TNX_DEAD_OFF, (double)TNX_THREAT_RANGE);

    tnx_logf("plan v170, from the 16:10 run: (1) every write in that log says dirIdx=0 and "
             "target=own+(600,0), a fixed east heading whatever the shots were doing. The cause is an "
             "empty threat list: with the v167 filters dropping all of it, the clearance returns its "
             "constant for all %d directions, the momentum term locks the first index and the dodge "
             "engages anyway, so the character walks east into what is coming. The ring now refuses to "
             "score when no shot survived the filters. (2) The step it issues is capped at %.0f units "
             "instead of %.0f: asking for 600 units on every frame is 36000 units per second and no "
             "walk cycle can express it, which is the slide; the reference caps its step at speed/10 "
             "and reissues it every ten milliseconds. (3) The team filter arms as soon as one "
             "enemy-team shot has been seen, instead of asking for both sides in the same frame, which "
             "never happened while the writes kept reporting five of the player's own shots dropped. "
             "(4) A new own element clears the ladder, the heading, the write clock and the issued "
             "flag, so a respawn does not inherit the last life's state",
             TNX_DIRS, (double)TNX_STEP, (double)DODGE_STEP);

    tnx_logf("plan v171, from the user's reading of the v119 numbers: a written position is lerped - "
             "src30, denomX and d38X in that log are the interpolation between the old and the new "
             "place - so a new target every frame restarts that interpolation and the body rides; and "
             "the walk cycle hangs on the stick, not on the position, so a position write leaves the "
             "engine certain the player is standing while the body moves. The move is therefore the "
             "engine's own input record at *(scene + %#llx): type %d at +%#x, x at +%#x, y at +%#x, all "
             "int32, written with the sidestep vector and skipped when the value has not changed, so "
             "the same input is not poked into the engine twice, and released with zeros the moment "
             "this build stops being the writer of it. The v99 probe wrote those same two fields as "
             "floats with a unit vector, which read as int32 is garbage, and that is why the earlier "
             "attempt moved nothing. The position channels stay, but only as ladder stages: the raw "
             "pair at +%#llx at stage %d, and the applied pair with the mode function at stage %d, "
             "which is exactly where that lerp comes from", (unsigned long long)TNX_MODE_INPUTMGR_OFF,
             TNX_INPUT_TYPE, 0x4, 0x8, 0xc, (unsigned long long)TNX_CTRL_RAW_X_OFF,
             TNX_STAGE_STICK, TNX_STAGE_POSITION);

    tnx_logf("plan v172, from the 16:2x log and the user's reading of it: (1) the v167 and v168 "
             "filters are removed - tracked=1 against flewAway=8 cannotReach=96 in that log means the "
             "threat list was emptied before the ring ever saw it, so no direction could be scored and "
             "the heading stood still. (2) The decision is the reference algorithm again: a segment per "
             "shot from where it is NOW to the end of its flight, inflated by %.0f, 24 directions at "
             "%.0f steps out to %.0f, ordered outward from the player's own stick angle so a safe "
             "heading near the one already held wins, nearest safe point per direction, then nearest "
             "distance and largest clearance, and a kinematic walk-into-it test for the no-threat case "
             "with a %.0f degree outward scan. (3) The stick is the BattleScreen object and this build "
             "only READS it: the joy fields at +%#x/+%#x/+%#x/+%#x, mode +%#x, cos and sin at +%#x "
             "and +%#x are printed once a second so one run with the stick moved by hand answers "
             "whether this build keeps the joystick there. updateMovement has no data slot to hook - "
             "a previous scan of every eight-byte word of __DATA_CONST and __DATA found none - and "
             "inline patching is not supported, so the object comes from the scene pointer this file "
             "already resolves. (4) Every movement write is off in this run: the queue push, the "
             "applied pair, the raw pair, the mode function and the v171 input manager (whose fields "
             "are float, which is why before read 1065353216 - that is 1.0f, and the int32 write was "
             "garbage). The dodge computes and logs its choice and nothing touches the character, so "
             "the stick can be tested by hand without the build fighting the player",
             (double)(TNX_PROJ_RADIUS + TNX_PLAYER_RADIUS + TNX_SAFETY_MARGIN),
             (double)TNX_STEP_2, (double)TNX_MAX_DIST, (double)90.0f, TNX_BS_AX,
             TNX_BS_AY, TNX_BS_BX, TNX_BS_BY, TNX_BS_MODE, TNX_BS_COS,
             TNX_BS_SIN);

    tnx_logf("plan v173, from the 16:42 run: (1) the way back to movement is the engine's own client "
             "input queue at battle+%#llx. Nothing in that build writes - every flag is off - so the "
             "only movement in the log is the player's own hand, and the queue count printed every "
             "five ticks is 0 up to tick 480 and 1 from tick 485 on, which is exactly the shape of a "
             "live move request; the 15:30 run had already shown our own push landing there as qBefore "
             "0 qAfter 1. TNX_QUEUE_MOVE is back on and the dodge's own target is what goes into "
             "the record. (2) The joystick pair stays off: all 21 probes of that run read ax=ay=bx=by=0 "
             "mode=0 cos=sin=0, so +%#x, +%#x, +%#x, +%#x, +%#x, +%#x and +%#x are not the stick in "
             "this build, and writing a field that reads zero for everyone is writing into nothing. "
             "(3) The stick is searched instead of guessed: once a second a %#x byte window is "
             "snapshotted on the scene, on the mode object at scene+%#llx and on the controller, and "
             "every slot that differs from the previous second is printed with its float and int "
             "reading and with a hot count - how many snapshots it has moved in while its base stayed "
             "the same - and the hottest slots are printed first, so a stick that snaps back to "
             "neutral between two samples still ranks above scenery. (4) The bs check one-shot now "
             "waits for a live scene instead of firing on a null pointer, which is what it printed as "
             "scene=0x0 classRva=0 in that run",
             (unsigned long long)TNX_MGR_OFF, TNX_BS_AX, TNX_BS_AY, TNX_BS_BX,
             TNX_BS_BY, TNX_BS_MODE, TNX_BS_COS, TNX_BS_SIN,
             (unsigned)TNX_WIN, (unsigned long long)TNX_MODE_MANAGER_OFF);

    tnx_logf("plan v174, from the 16:56 run and the user's report: (1) the slide is the queue push. That "
             "log has the queue carrying the body - own walks from (2297,6753) to (2601,6750) with "
             "TNX_QUEUE_MOVE 1 - and the type %d message is a POSITION, so the body is lerped there "
             "while the engine never starts the run cycle. The pair at ctrl+%#llx and ctrl+%#llx is the "
             "one the touch handler writes and the battle update reads, and the same log shows it "
             "holding (390,-456) while the player steers by hand, so the walk is that pair: "
             "TNX_RAW_STICK writes the chosen heading into it as a unit vector scaled by %.0f and "
             "zeros it once when the dodge lets go, and the queue push is off. (2) The threat list came "
             "out empty because a projectile's velocity was one tick of difference with the previous "
             "sample overwritten on every scan, so a projectile whose position had not changed between "
             "two scans read as standing still and dropped out of both the ring and the segment builder; "
             "the previous sample is kept until it really differs and the velocity is divided by the "
             "ticks between the two differing samples. (3) The team filter never armed in that run - the "
             "arming test asked for our team and another team inside ONE scan, and its line is absent "
             "from the log - so the ring spent itself on our own bullets, which is the 'it only dodges "
             "while I shoot' report; the latch now closes on the first shot of another team and stays "
             "closed. (4) Every tracked projectile prints its own verdict once a second, so an empty "
             "threat list names the filter that emptied it instead of being inferred",
             TNX_TYPE_MOVE, (unsigned long long)TNX_CTRL_RAW_X_OFF,
             (unsigned long long)TNX_CTRL_RAW_Y_OFF, (double)TNX_JOY_MAG);

    tnx_logf("plan v175, from the 17:12 run: (1) the threat list is cured - that log reads segs=2 then "
             "segs=7 with threatened=1 picked=1 and a target 300 units away, and its enemy shots arrive as "
             "team=1 with verdict=threat and real velocities of (35,60) to (49,55) per frame, so shots "
             "are recognised and the segment builder walks them. (2) The stick writer flickered: its "
             "first six writes alternate (-433,250) and (0,0) because the release call at the top of the "
             "dodge fired on every frame while the write block re-engaged in the same frame, so the "
             "engine could read a zero for half of the frames it updated in; the pair is now released "
             "only when %d ticks have passed since the last write. (3) The movement in that run "
             "contradicts the heading we wrote - own walked (2642,6687) to (2665,6549), which is "
             "(+0.16,-0.99), while the stick was (-433,250), which is (-0.87,+0.50) - so the pair did "
             "not drive the walk in that window; either the engine rewrites the pair from the real touch "
             "every frame and the player was touching, or the pair is not the mover. The route line now "
             "prints the dot product between the heading we wrote and the heading the character actually "
             "travelled in the same second, together with how many ticks of that second we held the "
             "pair, so the next run settles it - and the test has to be made with the screen untouched, "
             "or the two writers cannot be told apart. (4) one-sample was %d of 21 verdicts while the "
             "container held 12 elements, two players and ten shots, against a table of eight slots, so "
             "shots churned through the slots; the table is %d now. (5) A projectile moving (0.6,1.0) "
             "per frame was accepted as a threat while real shots move about 73 per frame, so the "
             "threshold is no longer 1 but %.0f",
             TNX_STICK_TTL, 10, TNX_PROJ_MAX, (double)TNX_MIN_PROJ_SPEED);

    tnx_logf("plan v176, from the 17:12 run: the dodge was dead for five seconds in the middle of the "
             "fight and the log names the gate. coords ok=0 at 17:12:37.219, 39.020 and 40.401, and "
             "those are exactly the seconds without a v172 dodge line, which comes back at 42.453 one "
             "second after coords ok=1 at 41.837. The flag is g_coord_ok = usable >= 2 && inRange "
             "== usable && distinct >= 2 && a team field that splits them, and usable counts PLAYERS "
             "only - the ten shots sitting in that same container are rejected as non-players - so a "
             "container that holds one player yields usable=1 and switches the whole dodge off, shots "
             "in the air or not. That is the 'after a death it only works while I shoot' report: the "
             "dodge returns when the second player is standing again, not when the shooting starts. It "
             "now runs on %d usable object, because with only the player present it still has the "
             "player's own coordinates and the whole threat list, and with no threat the ring picks "
             "nothing and nothing is written. Every opening and closing of the gate is logged once, so "
             "a silence can never again be read as the dodge being bypassed",
             TNX_MIN_USABLE);

    tnx_logf("plan v177, from the JS recipe and the 17:29 run, with both checked against the image. "
             "(1) The JS addresses are NOT this build. 0x818F4C and 0xB55168 are both inside functions: "
             "the word before 0x818F4C is ldr w8,[x19,0x41d2] and it flows into cmp w8,4, and 0xB55168 "
             "uses x20/x22/x21 with no prologue and reaches its epilogue at 0xB55218. No ldr or str "
             "anywhere in the 18 MB image touches +0x2A0C or +0x2A10 - those offsets are four aligned "
             "and below 0x3FFC, so a field there would be reached by a direct offset and would show up - "
             "and the immediates 0x2A0C and 0xDB40 never appear at all. Calling them would enter the "
             "middle of unrelated functions. (2) The idea is already in this file: at 0x7A64F0 the "
             "engine's OWN touch handler writes the pair at ctrl+%#llx from the touch minus the control "
             "centre, then mov w0,0x48, malloc, mov w1,2, bl %#llx and stp of the target pair at +0xc - "
             "byte for byte the message this file builds, so v126 is not a server packet, it IS the "
             "engine's local input. TNX_ADDINPUT_RVA 0x74675c is a real function start whose "
             "prologue stores the message and reads its type at [msg+8]. (3) The measurement agrees: "
             "with the message route the character covers 152 units a second while the player's own "
             "walking in the same logs is about 650, and with the pair route alone, in the 17:29 run, "
             "the movement was exactly 0 over 74 ticks of writing. (4) The pair is SCREEN space - it is "
             "the touch position minus the control centre, and the handler only writes it when the "
             "squared distance passes %d squared - so a world heading put there is in the wrong space, "
             "which is why v176 moved nothing. The message route is back on, the pair is no longer "
             "written and no longer zeroed, and every second the engine's own pair is paired with the "
             "heading the character really travelled in that same second, so the screen to world "
             "rotation is read off the log instead of guessed and the pair can then be written for a "
             "chosen world heading - which is what the walk cycle needs",
             (unsigned long long)TNX_CTRL_RAW_X_OFF,
             (unsigned long long)TNX_MSGCTOR_RVA, 225);

    tnx_logf("plan v178, from the 17:45 run: (1) the barely moving slide has a line in that log - step "
             "cut to %d units, the request was 150 units away - and the old reasoning behind the cut was "
             "wrong: a distance to a point is not a per frame step, the engine walks toward the target at "
             "its own speed and reissuing the same target every frame is exactly what a held stick does. "
             "The cap of twenty left the engine almost nothing to walk toward, and that is the slide. It "
             "is %.0f now, which is inside the walk itself: that run shows the character covering about "
             "thirteen units in sixteen milliseconds, so a full walk is near %.0f units a second at "
             "sixty frames and a request of %.0f units asks for about that much per frame through the "
             "engine's own response, while a far pick still cannot become a glide. (2) Both measuring "
             "instruments were unreachable: the route line and the pair calibration sat inside the write "
             "block, and that block returns early unless a threat is live, so in the 17:45 run it was "
             "reached ten times and the calibration produced ZERO samples - the one measurement that "
             "says whether the pair drives the walk was gated behind the success path, which is the same "
             "mistake as the v72 dead probe. Both now read the character's own coordinates themselves "
             "and run at the top of the dodge once a second whatever the threat list says, so the next "
             "run either shows the rotation between the pair and the world heading or shows that the "
             "engine never writes the pair at all",
             (int)20.0f, (double)TNX_STEP, (double)(13.0f * 60.0f), (double)TNX_STEP);

    tnx_logf("plan v179, from the 17:53 run, which finally carries the calibration. (1) The pair at "
             "ctrl+0xfa4 points the SAME way as the world movement: five samples taken while the player "
             "dragged the stick read dot +1.00, +0.99, +0.97, +0.94 and +1.00, with angDelta +2.2, +6.5, "
             "+14.7, -20.0 and -0.9 degrees, so there is no rotation between the pair's space and the "
             "world, and the screen space the disassembly shows - touch minus the control centre - is "
             "axis aligned with the world at this camera angle. The magnitude the engine itself writes "
             "is 601, 600, 600, 599 and 601, so it pushes the stick out to its own radius of about %.0f; "
             "TNX_JOY_MAG is %.0f instead of 500 and the pair is written again. (2) Both halves are "
             "needed in the same frame: with the message alone the character covered 152 units a second "
             "against the player's %d, and with the pair alone it covered exactly 0, while the engine's "
             "own handler writes both in one block - so v179 turns both on, the pair from the same "
             "heading the message carries. (3) The 17:53 run also shows what the dodge had to work with: "
             "the container held only players and two objects in the four million gid band, one standing "
             "still and one moving at two units a frame, so segs=0 is the correct answer for that run "
             "and not a gate - the single gate line reads open. The new census line splits the container "
             "by gid band every second, so a silent dodge always names its own emptiness",
             (double)TNX_JOY_MAG, (double)TNX_JOY_MAG, 780);

    tnx_logf("plan v180, from the 18:02 run: the pair works and the log proves it - route lines with "
             "engagedTicks=23 and 26 read dot +1.00 with aligned=same, so the heading written into "
             "ctrl+0xfa4 is the heading the character walks, and the same run reaches 769 units a "
             "second against the player's 780. What is left is that the writes sat AFTER the gate "
             "that returns when there are no threats, so the pair and the message were only sent on "
             "the frames a threat was live: engagedTicks was 23 and 26 out of 60, and the character "
             "walked in bursts instead of continuously - which is exactly what reads as sliding. Both "
             "writes now happen right after the dodge decides a heading, before that gate, and the "
             "heading and the target are held for %d more ticks after the last decision so the walk "
             "does not stop between two shots. The gate still stops the writes when the dodge has no "
             "heading at all, so a character that has nothing to dodge still stands still",
             30);

    tnx_logf("plan v181, from the 18:10 run and the engine's own handler, disassembled. (1) The walk "
             "cycle has no separate field to write: the handler at 0x7A64F0 writes the pair at "
             "ctrl+0xfa4 and ctrl+0xfa8 and then builds the message, and the block that follows it is "
             "the deterministic spin logic, not a movement state. So the two fallbacks the recipe "
             "offers - a stick state field and a movement type field - have no target in this build, "
             "and the only thing left to settle is whether the engine consumes a raw store into the "
             "pair or reads it only on its own input path. The route line now reads the ENGINE's own "
             "applied pair at ctrl+%#llx next to ours, which answers it: applied that follows our "
             "store means the engine is reading us and the animation is keyed elsewhere, while an "
             "applied that stays at the player's own last drag means a raw store can never animate and "
             "the engine's input handler has to be called instead. (2) The 18:10 run is one long "
             "nothing-to-dodge: its census reads players only with shots=0 for thirteen of fourteen "
             "seconds and the segments appear in the last second, right when gid 2000003 with team 1 "
             "arrives - so 'after a death it only works after a shot' is the threat list doing its job, "
             "not a gate, and the census column is the thing to watch. (3) The only non-player that is "
             "always present, gid 4000000 at (3150,4950), is respawned every second (its element "
             "address changes) and never moves, which is why it always reads one-sample",
             (unsigned long long)TNX_CTRL_APPLIED_X_OFF);

    tnx_logf("plan v182, from the 18:14 run. (1) The team reports are one bug, not two: g_team_off "
             "started life at 0x4c, and the file's own teamdump already settled what that is - four "
             "elements read 1,1,0,0 through +0x40 against 0,2,29535,0 through +0x4c, and 29535 is the "
             "two bytes of an inline string, so +0x4c is a std::string body and not a side. Only the "
             "walk forces the offset back to +%#x, so between a scene appearing and the first walk of "
             "that life every team is read four bytes off. The run shows exactly that and its "
             "consequence: v100 dodge gates at 18:21:17 reads own=0x117638c00 ownTeam=1 with "
             "teamOff=0x4c, and for the next two seconds every verdict is inverted - shots with team 0 "
             "report threat and shots with team 1 report own-team. That is the whole of 'it reacts to "
             "teammates' and 'after a death it only works once I shoot': the filter is inverted until "
             "the walk runs, so it drops the enemy and keeps our own side. The offset now starts at "
             "+%#x, the value the walk itself reverts to, so the wrong side is never live. (2) The "
             "instruments were reading a different object: the 18:14 route lines show own=(2550,9750) "
             "with movedLastSecond=0 for the whole run while the player was walking, so g_own_elem "
             "is not the character the dodge walks. g_own_elem_2 is now published from "
             "objects[ownIndex] in the very block that reads ownTeam and the position, and every "
             "instrument prefers it, so the route and paircal lines measure the character in control",
             (unsigned)TNX_OBJ_TEAM_OFF, (unsigned)TNX_OBJ_TEAM_OFF);

    tnx_logf("plan v183, from the 18:44 run. The team side is now stable - teamOff reads +%#x in every "
             "line but one and ownTeam never flips - and what is left is that the dodge was not looking "
             "at the player. Its own gate line says ownFound=0 for forty straight seconds while the "
             "census counted four players, and in the seconds it did resolve it says "
             "ownFrom=v135-list own=0x15b0cd800 selfPos=(2550,9750) against targetPos=(2250,1950): a "
             "fixed point the character never stood on. So every heading it computed came from somebody "
             "else's position, which is 'after a death it does not work at all' and 'it reacts very "
             "slowly' at the same time. The reason is the first rule of the resolver: "
             "tnx_own_from_list picks the player with the SMALLEST gid, so any player with a lower "
             "gid becomes own. Two changes. (1) The character the dodge used on the previous tick is "
             "taken again whenever it is still in the container with a plausible gid and team, and that "
             "attempt now runs before the heuristics, so own stops changing owners between ticks and "
             "changes only when it really leaves the container - ownFrom=latched in the log. (2) The "
             "published own is accepted whenever the object itself validates, instead of only when its "
             "stamp equals the current tick: the run prints v145 own not used elem=0x15b0cd800 "
             "stamp=7860 tick=7862, a two tick old element thrown away even though its address is a "
             "live heap object, which is what pushed the resolver into the list in the first place",
             (unsigned)TNX_OBJ_TEAM_OFF);

    tnx_logf("plan v184, from the 18:58 run and the three reports. (1) 'It walks at the enemy through "
             "him after I shoot' is the team filter being unarmed, and the geometry says why that is "
             "lethal: own team's own bullet starts at the character's own body, so its closest approach "
             "to own is at time zero and distance zero, which makes it the single most threatening "
             "segment on the board - the dodge then walks along that bullet's path, which is straight "
             "at the enemy. The filter only armed after it had seen a shot of ANOTHER team, and the run "
             "never had one: every threat line reads armed=0 while the census holds shots=0 and one "
             "second of shots=1, and that one shot is own's. The filter is now armed as soon as own's "
             "own team is readable, so a shot of own's side is dropped whether or not another side has "
             "fired yet. (2) The reaction window was a quarter of a second: the threat radius is "
             "proj+player+safety = %.0f units and the safety part was 35, so a shot had to be inside "
             "%.0f units before it counted - at the measured 780 units a second walk that is 0.25 s. "
             "The safety margin is %.0f, so a shot is a threat from %.0f units out, about 0.7 s of "
             "walk, which is the 'react at zero' the user asks for without inventing a faster clock. "
             "(3) The dump he asked for is in: the window scanner has a fourth base, the character "
             "itself, named char, so the slots that move while the PLAYER walks and the slots that move "
             "while the DODGE drives can be diffed from the same log - the field that only moves for "
             "the player's own input is the animation state we cannot write yet. (4) Own's latch now "
             "runs before the heuristics instead of behind them: in the 18:58 run the smallest gid list "
             "still won 22 of 39 resolutions because it is the first rule inside the resolver, which is "
             "why the route lines still read own=(2550,9750); the list is now the last named rule and "
             "the latch is tried first",
             (double)(TNX_PROJ_RADIUS + TNX_PLAYER_RADIUS + 35.0f),
             (double)(TNX_PROJ_RADIUS + TNX_PLAYER_RADIUS + 35.0f),
             (double)TNX_SAFETY_MARGIN,
             (double)(TNX_PROJ_RADIUS + TNX_PLAYER_RADIUS + TNX_SAFETY_MARGIN));

    tnx_logf("plan v185, first the build. The team arming line went into tnx_autododge_v48, where "
             "ownFound does not exist - it is a local of the walk - and the compiler said so at "
             "13066. The dodge's own resolution result is ownIndex, which is -1 until a resolver "
             "fills it, so that is the test there now. Note this is the one class of error the local "
             "gates cannot see: typecheck and earlyuse do not compile, and a stub compile of an "
             "extracted statement cannot see the scope it was pasted into, so every injected "
             "statement now gets an explicit check that each identifier it names is declared in that "
             "same function or at file scope. (1) Latency: the safety margin is %.0f now, so a shot is "
             "a threat from %.0f units, about 1.2 s of walking at the measured 780 units a second. The "
             "floor under that is not ours to remove - a projectile is only a projectile once it has "
             "moved, which costs one tick, and the decision itself is one tick, so about 32 ms is the "
             "hard limit for a bullet that already exists. (2) Below that floor the only way is to "
             "dodge the AIM instead of the bullet, which is the 0 ms route and needs a field on the "
             "enemy object. That field is what the dump is for: the window scanner has a fifth base, "
             "the nearest enemy player, published from the same loop that reads own, so the slots that "
             "move on an enemy while he aims and fires can be read straight off the log instead of "
             "recalled. (3) For the slide the fourth base, char, gives the other half of the same "
             "diff: the slots that move while the PLAYER walks against the slots that move while the "
             "DODGE drives; the field that only moves for the player's own input is the animation "
             "state this build cannot write yet",
             (double)TNX_SAFETY_MARGIN,
             (double)(TNX_PROJ_RADIUS + TNX_PLAYER_RADIUS + TNX_SAFETY_MARGIN));

    tnx_logf("plan v186, from the 19:18 run, and the 19:18 run says the dodge was off exactly while it "
             "was needed. Its census climbs to players=1 shots=6 and then players=1 shots=7, and in "
             "those same seconds there is no v172 dodge line at all while the route and census lines "
             "keep printing - so the dodge returned between the census at the top and the scan. The "
             "line that does it is `if (usable < 2) return;`: with the enemies dead the container holds "
             "only the player, usable is one, and the whole dodge switches off with seven of their "
             "shots in the air. That is the same class as the coord_ok floor fixed in v176 - a floor of "
             "two where one is enough - and this one was never touched. It is %d now, and it says so "
             "once a second while it is shut. (1) The dodge's own resolution chain did not contain the "
             "latch: it still ran v128 then v91, so own could still be the smallest-gid player, and the "
             "walk has a second chain without the latch as well. Both start with the latch now, so the "
             "character the dodge used last tick wins in every path. (2) For the close range the angles "
             "go from %d to %d, so the escape direction is chosen twice as finely when a shot is "
             "already near. (3) One correction to the instrument itself: ctrl+%#llx is NOT the applied "
             "stick, it is the engine's applied POSITION - the run prints applied=(2584,8692) then "
             "(2612,8011), (2645,7088), (2669,6399) against own=(2568,9191), (2597,8434), (2625,7663), "
             "(2650,6899), so it tracks the character's own coordinates and extrapolates them. It is "
             "still worth printing as a second opinion on where the character is, but it cannot answer "
             "whether the engine consumed the pair",
             TNX_MIN_USABLE_2, (int)24.0f, TNX_NUM_ANGLES,
             (unsigned long long)TNX_CTRL_APPLIED_X_OFF);

    tnx_logf("plan v187, from the 19:29 run. (1) Reports 2 and 4 are one missing test: the segment "
             "builder never filtered by team. The verdict line does label own's shots - it prints "
             "gid=2000000 team=0 verdict=own-team armed=1 - but tnx_build took every tracked shot "
             "with a velocity and made it a segment, so the dodge's own input was a bullet of the "
             "player's own, which leaves the player's own body and therefore has its closest approach "
             "at time zero and distance zero. The ring then walks along that bullet's path, which is "
             "straight at the enemy and through him. The builder now carries the same test "
             "tnx_clearance already had, so the filter is applied where the decision is made and "
             "not only where it is printed. (2) Report 1: the drive reads the pair before it writes and "
             "stands down for the tick when the pair holds a value this build did not write, so a held "
             "stick is never overwritten by a heading or by a zero. (3) Report 3, and the character "
             "window has finally named the animation: a triplet at +%#x / +%#x / +%#x runs 0.60 -> "
             "7.1358 and wraps to zero once a second WHILE THE CHARACTER STANDS STILL, so it is the "
             "animation clock and not the walk; +0x600 reads down 40.25 -> 39.75 and a small state int "
             "at +0xa8 walks 4 -> 0 -> 1. Only +0x28 and +0x2c move while moving and never while "
             "standing (203 -> 220 -> 238 -> 258 and 218 -> 232 -> 250 -> 271), a small integer pair "
             "sitting just under the coordinate pair, so it is the previous position and not a walk "
             "flag. There is no separate walk state in the first 0x1000 bytes of the character. The "
             "dodge drove for zero ticks in this run - engaged=0 in all 14 route lines - so the "
             "dodge-driven sample is still missing, and with the two fixes above it will drive on real "
             "enemy shots and the next log carries it. (4) Correction to my own earlier note: "
             "own=(2550,9750) is the spawn point and a real position - the character stands there with "
             "movedLastSecond=0 and at 19:30:07 jumps to (2301,9324) with the window going to "
             "changed=61. It was never a bogus fixed point",
             (unsigned)0x4e8, (unsigned)0x520, (unsigned)0x524);

    tnx_logf("plan v188: v187's stand down killed the dodge. It skipped the write whenever the pair held "
             "anything this build did not write, and the pair keeps the player's last touch value "
             "indefinitely, so the condition was true on every tick - the log has one line of "
             "drive stands down with the pair at (-593,97) and nothing else happens. The dodge "
             "drives again while the joystick is held, and the release is the only thing that changed: "
             "it zeroes the pair only when the pair still holds the value this build wrote, so a held "
              "stick is never stopped or overwritten");

    tnx_logf("plan v189, three reports and no device in the loop. (1) 3v3, and the report is that the "
             "character goes through its teammates instead of dodging. The cause is not the team "
             "offset, which reads +%#x with a stable value: it is that nothing in this file ever "
             "used the players of own's own side. The ring scored a heading against threat segments "
             "only, so a heading through a teammate's body scored exactly like open ground, the "
             "engine's own collision stopped the character there and the shot it was dodging went "
             "through; and a teammate's shot, whose own team byte can be unreadable, survived every "
             "filter and became the most threatening segment on the board, because a segment that "
             "starts on own's own body has its closest approach at time zero and distance zero. "
             "There is now one roster pass a tick: it publishes own, own's side and the players of "
             "that side, the ring refuses any candidate point within %.0f units of a teammate, and a "
             "shot whose team byte is unreadable has its side taken from its spawn point - a "
             "projectile leaves its owner's body, so the nearest player wins, and an ambiguous or "
             "distant spawn stays unknown and stays a threat rather than being called ours. Both "
             "counts are printed, so a 3v3 log says whether the roster found the two teammates it "
             "must find. (2) Own death and respawn. v167 held the dodge on the byte at own+%#llx and "
             "that byte reads 0, 1 and 63 on live objects, so the guard held while the player was "
             "alive and the run was read as a wrong offset; v169 turned the guard off and this file "
             "has not known its own life state since, while the attached log carries no death at "
             "all. What is provable from the client side is the respawn: the character is teleported "
             "by a jump of thousands of units between two frames where a walk covers about thirteen, "
             "and that event is now the positive control for the flag - the three candidates are "
             "sampled every frame, and the one that changed across a respawn and then held its new "
             "value for %d frames is the flag, with the value it held before the event as the dead "
             "value. Only a learned candidate may hold the dodge, so a wrong guess can never leave "
             "the character standing, which is exactly how v167 failed. A respawn also clears the "
             "per life state - the ladder, the heading, the write clock, the issued flag, the held "
             "target - and zeroes the pair only when the pair still holds what this build wrote, so a "
             "held stick survives it. The state is on screen, not only in the log: the watermark "
             "label now reads the build tag and the state, and the status text carries life, own's "
             "position, own's side and the teammate count. (3) The slide. v180 sent the ring's own "
             "pick as the destination of the type %d client input, and that pick is a point up to "
             "%.0f units away; the input is a POSITION, and this file's own note from v170 names the "
             "consequence - a step larger than a walk cycle can express is not a walk but a lerp of "
             "the body. The cap that says so is %.0f and it was only ever applied in the legacy "
             "write path, which the v180 drive bypasses. The drive sends one frame of travel now and "
             "reissues it every frame while it is engaged, which is what a held stick does, and it "
             "holds the heading for %d ticks instead of %d: at the measured 780 units a second the "
             "old hold kept walking the character for half a second after the last decision, which is "
             "the other half of the same report. TNX_PAIR_ONLY=%d writes only the pair - exactly "
             "what the engine's own touch handler writes - and is the one switch still needing a "
             "device, because the animation question is the one thing this side cannot settle: v179 "
             "measured the pair alone as moving nothing, v180 measured the pair plus the message as "
             "full speed, and neither run wrote the pair on frames without a threat. A log with the "
             "pair only, and a log with the capped step, answer it between them. The distance the "
             "character covers in the second after the last decision is printed as v189 drift, "
             "against the 780 units a second a real walk covers, so the next run measures the slide "
             "instead of describing it",
             (unsigned)TNX_OBJ_TEAM_OFF, (double)TNX_MATE_CLEAR,
             (unsigned long long)TNX_DEAD_OFF, TNX_HOLD_FRAMES, TNX_TYPE_MOVE,
             (double)TNX_MAX_DIST, (double)TNX_STEP_3, TNX_HOLD_TICKS, 30,
              TNX_PAIR_ONLY);

    tnx_logf("plan v190, five reports from a run this build cannot see yet. (1) The log always stopped "
             "at the same size and the answer is arithmetic: the file sent in is %d bytes, %d of them "
             "written here and %d by the hook library plus one byte of newline each, because this "
             "file's budget of %d counts its own bytes including the timestamps and returns the moment "
             "they run out while the library keeps appending its own "
             "share on top. It was a hard stop, not a rotation, so a log always ended in the middle of "
             "whatever was happening - the run sent in ends twelve milliseconds after the dodge first "
             "engaged, one drive frame and no evidence about anything the report mentions. The budget "
             "is %d bytes now and the writer rolls: the file is truncated, a marker line goes into it, "
             "and the newest window takes the place of the oldest. (2) A line has to pass a filter to "
             "be written at all. %d of the 3068 lines of that run were the hook library's per slot dry "
             "run, one line per matching slot on every probe, and most of the rest were diagnostics "
             "whose questions were answered versions ago; the library prints its first %d dry run "
             "lines now and its count line still carries the total, and the writer drops %d legacy "
             "prefixes while anything not listed is kept by default, so no line can go missing "
             "quietly. (3) The dead code is gone rather than switched off: %d lines, being the "
             "position write path that no longer runs because the drive replaced it - the raw stick "
             "write, the mark applied, the mode write, the prediction actuator and the queue push of "
             "the legacy branch - together with the %d functions, %d globals and %d constants that "
             "nothing referenced once that path went. Every deletion is a zero reference deletion, so "
             "nothing still called was touched, and the compiler, the counter set and the brace "
             "balance all confirm it. (4) The delay is a number now: an engagement is a run of writes, "
             "the first write is the decision and the tick own's position first moves is the reaction, "
             "so the report carries the frames between them, the frames the run lasted and whether the "
             "body moved at all. (5) The slide: the drift line never printed in the last build, "
             "because it waited for a frame counter inside a forty five frame window and one frame in "
             "sixty satisfied that; it fires once per decision now. With it comes the applied world "
             "target at ctrl+%#llx, because the engine's own tracked branch stores the touch into that "
             "pair, a real walk leaves it a few hundred units ahead of own and its no touch value is "
             "the sentinel %d,%d - so writing the step there as well as sending it is what a drag of "
             "the stick does, and an applied pair still reading the sentinel while this build writes "
             "every frame means the send is not reaching the movement code at all",
             644349, 522880, 118401, 512 * 1024, 4 * 1024 * 1024, 1343, 8, 59, 599, 13, 36, 31,
              (unsigned long long)TNX_CTRL_APPLIED_X_OFF, TNX_APPLIED_IDLE,
              TNX_APPLIED_IDLE);

    tnx_logf("plan v191, and the 20:46 run answers both reports in one line: v189 roster players=%d "
             "mates=%d ownTeam=%d own=(0,0) in a 3v3. Own was not matched by index at all, own's side "
             "was then taken from the wrong element, and five of the six players were adopted as "
             "teammates. A ring that refuses every point within %.0f units of five phantom teammates "
             "has one direction left, which is the enemy - that is 'it runs straight at the "
             "opponents' - and a shot filter that calls every enemy bullet own-side leaves the ring "
             "nothing to dodge - that is 'it does not react'. One defect, both reports. (1) Own is "
             "matched by element now, and the side is only believed when it divides the container, "
             "because a side is a minority in a team match: more than half the players on own's side, "
             "or one team value across four or more players, means the field is not the team, and "
             "then the mate block and the own shot filter stand down together and say so in the log. "
             "The roster line prints the raw table - six team values and whether own was matched - "
             "because the previous line printed only counts and that is how this survived a whole "
             "build. (2) No candidate point that walks own towards an enemy: %d units of hard radius, "
             "or %d units closer to an enemy than own already is, once own is %d units out. The ring "
             "scored against threat segments only, so the point on the enemy's side of own scored "
             "like open ground. (3) A projectile seen ONCE is a threat now. Its bearing is the chord "
             "from where it was first seen to where it is, divided by the ticks that took, and it "
             "needs no second sample: that run had %d one-sample lines against %d verdicts of threat, "
             "so two thirds of everything that flew was invisible to the ring, and the one tick a "
             "second sample costs is one tick of the reaction the report is about. (4) The applied "
             "world target is retired as a lead: that run walked the character at %d units a second "
             "on frames where the applied pair still read the engine's no touch sentinel, so it is "
             "not the field the movement reads and writing it changes nothing. (5) The delay "
             "measurement was wrong: it counted a frame as movement only past twenty units, which "
             "only a teleport reaches, so runs that read movedAfter=0 were walking at %d to %d units "
             "a second. The threshold is %d units a frame now, and the report carries the whole path "
             "covered and the angle between that path and the stick this build wrote - %+.2f is the "
             "body walking the way it was told, near zero is the slide. Own's own reading is checked "
             "before it is used, because that log holds own=(0,0) and own=(142428352,1), and the "
             "first of those produced a respawn event with a jump of %d units from the origin",
             6, 5, 0, (double)TNX_MATE_CLEAR, TNX_ENEMY_HARD, TNX_ENEMY_MARGIN,
             TNX_ENEMY_FAR, 655, 341, 1157, 441, 1157, TNX_MOVE_MIN, 1.0, 2554);

    tnx_logf("plan v192, and the reference script that walks properly is the missing recipe. It moves "
             "with three calls per frame and all three are the game's own: it builds the input with "
             "the ctor and stores the target into it, it stores the same target into the CLIENT "
             "PREDICTION, and it hands the input to the input manager. This build had the ctor, the "
             "target and the manager add already; the prediction was fingerprinted at boot and never "
             "called, and the mode's pair at +%#llx was only ever read back as a probe. The prediction "
             "is the engine's own local movement, so leaving it out is exactly what leaves the body "
             "carried by the input queue instead of walked by the movement code, which is the slide "
             "report. It is called now, with the same one frame step that goes into the input, on "
             "every frame this build drives. (2) The teammate report: the v189 test looked only at the "
             "END of the path, so a candidate beyond a teammate was accepted and the character walked "
             "through him. The test now runs along the whole segment from own to the candidate and it "
             "uses every other player, not the side read, so a team byte that reads 0 for everyone - "
             "which the 21:04 log shows it does for two players in one container - can no longer hide "
             "a body: %d units of clearance. The side only changes the destination test. (3) The "
             "engage report carries human=%llu, the frames the player's own finger was on the stick "
             "while this build drove, because the complaint is that the dodge does nothing while the "
             "stick is held and works while standing; a run with human at its maximum and traveled at "
             "walk speed is coexistence, and a run with human high and traveled at zero says the "
             "player's own input wins. The reference settles that case by pushing from inside the "
             "game's own movement update and by redirecting the player's direction rather than adding "
             "a second input, which is the next move if the counter says it is still needed. (4) The "
             "21:04 log also shows the roster reading the truth once the guard is in: players=%d "
             "mates=%d enemies=%d teams=0/1/0/1/0/1 trust=%d, and trust going to zero on the "
             "four-player read where own's side came back as three", (unsigned long long)TNX_MODE_PREDICTX_OFF,
             (int)TNX_BODY_CLEAR, 0, 6, 2, 3, 1);

    tnx_logf("plan v193, from the 21:17 run and from offsets.h being audited against the binary. (1) The "
             "prediction call never fired: g_addr_setprediction was resolved from "
             "RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO, which reads 0xb90b8c in offsets.h and "
             "is the middle of another function in this image, so the callable refused it and the log "
             "had no line about it at all. 134 of that header's 146 RVA entries are not function starts "
             "in this image; the confirmed prediction is 0xac3f20, whose fingerprint is the three "
             "instructions b901d401 b901d802 d65f03c0, and the header now carries only entries that "
             "land on a start, with the rest named instead of left to look plausible. A guard that "
             "cannot fire silently is the same trap as a probe behind an early return: the caller now "
             "prints a line when the address does not resolve. (2) The engine's touch bookkeeping is "
             "written while this build drives. Every v190 line showed applied=(-300,-300) - the "
             "sentinel its own touch handler writes when it believes nothing is held - on frames where "
             "the character walked at 1157 units a second, so the movement was coming through the "
             "input queue and not from the stick the game animates. The byte at ctrl+%#llx is what its "
             "handler tests before it applies the stick, and it is set here with state and id read "
             "back beside it: the sentinel going away is the engine taking this build's stick as a real "
             "drag, which is the difference between a body that slides and a body that walks. (3) One "
             "line a second, v193 core, carries own, validity, side, mates, enemies, trust, the ring's "
             "segment count, the tracker's split, the oneshot count, the body and enemy blocks, the "
             "touch gate writes, the prediction calls and refusals, the degenerate picks and the human "
             "stick frames. The per object probes are out of the file and out of the log: 1177 v174 "
             "lines in the last run said the same thing five times a shot, and the question they were "
             "meant to answer - what is the ring dodging - needs a count, not a transcript. (4) What "
             "the last run said about the reports: the side read is right in a 3v3 (players=6 mates=2 "
             "enemies=3 teams=1/1/1/0/0/0 trust=1) and the trust guard fired %d times on reads where "
             "own's side came back as the majority; the write to movement delay is one frame "
             "(movedAfter=1 in most runs) but several runs travelled two to three units over eight or "
             "nine frames, which are the frames that look like a dodge doing nothing, and they are "
             "counted as deadPick now; and 44 real threats against 446 own team shots and 674 one "
             "sample lines says the ring was mostly watching objects that never move",
             (unsigned long long)TNX_TOUCH_GATE_OFF, 8);

    tnx_logf("plan v198. The slide has one cause and it is in this file: tnx_write writes the "
             "engine's own move state - ax %#x, ay %#x, bx %#x, by %#x and mode 2 at %#x, the same "
             "fields the reference reads to answer 'is the character moving' - and nothing in the "
             "build ever called it, so the body was carried by the input queue for revision after "
             "revision. It is called every frame the dodge drives now, on both candidate objects, "
             "because which of them carries that struct is not known yet, and every write is read "
             "back: stook and ctook count the frames the engine still held this build's value with "
             "mode at 2, which is the positive test for a stick the game believes. The prediction is "
             "read back the same way, so a call that lands on the wrong object cannot pass for a "
             "working one. The reference's own movement is a single call, setClientPredictionMoveTo of "
             "the logic battle with the target and a true flag - four arguments, and this build now "
             "passes the fourth - and it pushes the same type 2 input through the same manager at "
             "battle+%#x that this build uses. What is left different is where the call comes from: "
             "its scripts write from inside the game's own update and this build writes from the "
             "render hook, and that is the next thing to move if the read backs come back empty",
             TNX_BS_AX, TNX_BS_AY, TNX_BS_BX, TNX_BS_BY, TNX_BS_MODE,
             (unsigned long long)TNX_MGR_OFF);
    }

    tnx_start_timer();

    tlog([NSString stringWithFormat:@"setup completed successfully armed=%d", g_objc_armed]);
}
