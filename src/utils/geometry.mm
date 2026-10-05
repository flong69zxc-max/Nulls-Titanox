#include "titanox.h"

int g_v95_find_joy_done = 0;

uint64_t g_v48_ticks = 0;

int g_v48_entry_logs = 0;

uintptr_t g_v48_manager = 0;

int tnx_v48_collect(uintptr_t manager, tnx_v47_obj_t *out, int capacity, int *rejected) {
    void *data = NULL;
    int32_t count = 0;
    int usable = 0;
    int bad = 0;
    uintptr_t gidOff = TNX_OBJ_GLOBALID_OFF;
    uint32_t walkSeq = 0;

    memset(&g_v50_reject, 0, sizeof(g_v50_reject));

    tnx_v127_gidless_scan(manager);

    if (rejected) *rejected = 0;

    if (!manager) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0) return 0;

    if (count > capacity) count = capacity;

    gidOff = tnx_v135_list_gid_off((uintptr_t)data, count);

    walkSeq = g_v142_seq;

    g_v142_walk_aborted = 0;
    g_v142_walk_abort_i = -1;
    g_v142_walk_arr = (uintptr_t)data;
    g_v142_walk_n = count;

    for (int32_t i = 0; i < count && usable < capacity; i++) {
        void *element = NULL;
        void *vtable = NULL;
        tnx_v47_obj_t entry;
        uintptr_t vtRva = 0;

        memset(&entry, 0, sizeof(entry));

        g_v50_reject.elementsRead++;

        if (g_v142_seq != walkSeq) {
            g_v142_walk_aborted = 1;
            g_v142_walk_abort_i = i;
            g_v142_walk_aborts++;

            if (g_v142_walk_aborts <= TNX_V142_WALK_ABORT_FULL) {
                tnx_logf("v142 walk aborted at i=%d n=%d arr=%p g_arr=%p g_n=%d aborts=%llu - the "
                         "published tuple moved during the pass, so the rest of this list is "
                         "whatever the engine put there next and the pass stops instead of "
                         "dereferencing it",
                         i, count, (void *)(uintptr_t)data, (void *)g_v142_pub_array,
                         g_v142_pub_count, (unsigned long long)g_v142_walk_aborts);
            } else if ((g_v142_walk_aborts % TNX_V142_WALK_ABORT_EVERY) == 0) {
                tnx_logf("v142 walk aborts=%llu at i=%d n=%d - the full text is printed for the "
                         "first %d only, because a reallocation burst would otherwise drown the "
                         "log the way the census did in v135",
                         (unsigned long long)g_v142_walk_aborts, i, count,
                         TNX_V142_WALK_ABORT_FULL);
            }

            break;
        }

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * sizeof(void *), &element)) {
            g_v50_reject.rejUnreadable++;
            bad++;

            continue;
        }

        if (!element) {
            g_v50_reject.rejNull++;
            bad++;

            continue;
        }

        entry.object = (uintptr_t)element;

        if (tnx_v75_element_ascii(entry.object)) {
            g_v50_reject.rejAscii++;
            g_v52_ascii_rejected++;
            bad++;

            continue;
        }

        if (!tnx_read_ptr(entry.object, &vtable) || !vtable) {
            g_v50_reject.rejUnreadable++;
            bad++;

            continue;
        }

        vtRva = (uintptr_t)vtable - g_base;

        if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
            g_v50_reject.rejNoVt++;
            bad++;

            continue;
        }

        entry.gid = tnx_v106_gid_at(entry.object, gidOff);

        {
            uintptr_t tw = 0;

            tnx_v86_element_type((uintptr_t)vtable, &tw);

            entry.typeWord = (int32_t)tw;
        }

        if (!tnx_read_i32(entry.object + tnx_v57_coord_x_off(), &entry.x) ||
            !tnx_read_i32(entry.object + tnx_v57_coord_y_off(), &entry.y) ||
            !tnx_read_i32(entry.object + TNX_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
            !tnx_read_i32(entry.object + TNX_OBJ_TEAM_OFF, &entry.teamOld) ||
            !tnx_read_i32(entry.object + TNX_V91_TEAM_OFF, &entry.teamNew) ||
            !tnx_read_u8(entry.object + TNX_OBJ_DEADFLAG_OFF, &entry.dead) ||
            !tnx_read_u8(entry.object + TNX_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag)) {
            g_v50_reject.rejUnreadable++;
            bad++;

            continue;
        }

        if (entry.gid >= TNX_V138_PLAYER_GID_MAX) {
            g_v50_reject.rejNonPlayer++;
            bad++;

            tnx_v140_proj_track(entry.object, vtRva, entry.gid, entry.teamOld);

            if (g_v138_dump_np < TNX_V138_NP_DUMPS) {
                int32_t npX = 0;
                int32_t npY = 0;
                int32_t np70 = 0;
                int32_t np74 = 0;
                float npFx = 0.0f;
                float npFy = 0.0f;
                float npF70 = 0.0f;
                float npF74 = 0.0f;
                void *np38 = NULL;
                uintptr_t npRva = vtRva;

                g_v138_dump_np++;

                tnx_read_i32(entry.object + TNX_OBJ_X_OFF, &npX);
                tnx_read_i32(entry.object + TNX_OBJ_Y_OFF, &npY);
                tnx_read_i32(entry.object + TNX_V134_V70_OFF, &np70);
                tnx_read_i32(entry.object + TNX_V134_V70_OFF + 4ULL, &np74);
                tnx_read_ptr(entry.object + TNX_V138_NP_PTR_OFF, &np38);
                if (!tnx_read_f32(entry.object + TNX_OBJ_X_OFF, &npFx)) npFx = 0.0f;
                if (!tnx_read_f32(entry.object + TNX_OBJ_Y_OFF, &npFy)) npFy = 0.0f;
                if (!tnx_read_f32(entry.object + TNX_V134_V70_OFF, &npF70)) npF70 = 0.0f;
                if (!tnx_read_f32(entry.object + TNX_V134_V70_OFF + 4ULL, &npF74)) npF74 = 0.0f;

                tnx_logf("v138 nonplayer elem=%p classRva=%#llx gid=%d team=%d x+%#llx=%d y+%#llx=%d "
                         "+%#llx=%d +%#llx=%d f32x=%g f32y=%g f32%#llx=%g f32%#llx=%g ptr+%#llx=%p - an "
                         "element outside the player id window "
                         "is named once with the fields a projectile would need, because the claim "
                         "that this class is a projectile was an analogy from its id range and not a "
                         "measurement, and a position that changes while the element exists and then "
                         "disappears is what would settle it",
                         (void *)entry.object, (unsigned long long)npRva, entry.gid, entry.teamOld,
                         (unsigned long long)TNX_OBJ_X_OFF, npX, (unsigned long long)TNX_OBJ_Y_OFF, npY,
                         (unsigned long long)TNX_V134_V70_OFF, np70,
                         (unsigned long long)(TNX_V134_V70_OFF + 4ULL), np74,
                         (double)npFx, (double)npFy, (unsigned long long)TNX_OBJ_X_OFF, (double)npF70,
                         (unsigned long long)(TNX_V134_V70_OFF + 4ULL), (double)npF74,
                         (unsigned long long)TNX_V138_NP_PTR_OFF, np38);
            }

            continue;
        }

        if (entry.gid == 0 && !g_v127_gidless) {
            g_v50_reject.rejGidZero++;
            bad++;

            continue;
        }

        if (entry.x <= -TNX_V47_COORD_ABS_MAX || entry.x >= TNX_V47_COORD_ABS_MAX ||
            entry.y <= -TNX_V47_COORD_ABS_MAX || entry.y >= TNX_V47_COORD_ABS_MAX) {
            if (g_v106_coord_logs < 6) {
                void *tvtable = NULL;
                uintptr_t tvtRva = 0;

                g_v106_coord_logs++;

                if (tnx_read_ptr(entry.object, &tvtable) && tvtable) tvtRva = (uintptr_t)tvtable - g_base;

                tnx_logf("v106 coord suspect elem=%p vtRva=%#llx +%#llx=%d +%#llx=%d gid=%d - this class "
                         "carries neither its id nor its coordinates where the walk looks for them, so "
                         "the row is dropped as rejOutOfRange and usable stays below two; turn "
                         "TNX_V106_COORD_SOFT on to let it through and let the per entry coord gate "
                         "downstream decide",
                         (void *)entry.object, (unsigned long long)tvtRva,
                         (unsigned long long)TNX_OBJ_X_OFF, entry.x,
                         (unsigned long long)TNX_OBJ_Y_OFF, entry.y, entry.gid);
            }

            if (!TNX_V106_COORD_SOFT) {
                g_v50_reject.rejOutOfRange++;
                bad++;

                continue;
            }
        }

        if (!((entry.teamOld >= 0 && entry.teamOld <= TNX_OBJ_TEAM_MAX) ||
              (entry.teamNew >= 0 && entry.teamNew <= TNX_OBJ_TEAM_MAX))) {
            g_v50_reject.rejTeamMissing++;
            bad++;

            continue;
        }

        if (entry.dead == 1) g_v50_reject.deadSeen++;

        out[usable++] = entry;
    }

    if (rejected) *rejected = bad;

    return usable;
}

int tnx_v48_small(long value) {
    return (value > -TNX_V48_VALUE_MAX && value < TNX_V48_VALUE_MAX) ? 1 : 0;
}

float tnx_v48_as_float(uint32_t bits) {
    union { uint32_t u; float f; } view;

    view.u = bits;

    return view.f;
}

void tnx_v48_discriminate(uintptr_t manager) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    uint32_t words[TNX_V48_ELEMS][TNX_V48_WORDS];
    int rejected = 0;
    int usable = 0;
    int n = 0;
    int teamOff = -1;
    int teamDistinct = 0;
    int coordOff = -1;
    int coordDistinct = 0;
    int intPairOff = -1;
    int floatPairOff = -1;

    memset(objects, 0, sizeof(objects));
    memset(words, 0, sizeof(words));

    tnx_v146_phase("walk");

    usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    g_dodge_probe_usable = usable;
    if (usable > 0) memcpy(g_dodge_probe_list, objects, (size_t)usable * sizeof(g_dodge_probe_list[0]));

    if (usable == 0) {
        char reasons[320];

        if (rejected > 0 || g_v50_reject.elementsRead > 0) {
            tnx_logf("v100 fields manager=%p usable=0 rejected=%d -- all elements rejected: %s",
                     (void *)manager, rejected, tnx_v50_reject_text(reasons, sizeof(reasons)));
        } else {
            tnx_logf("v100 fields manager=%p usable=0 rejected=0 -- no elements in container",
                     (void *)manager);
        }

        return;
    }

    if (usable == 1) {
        char reasons[320];

        tnx_logf("v100 fields manager=%p usable=1 rejected=%d -- one element is not enough to tell "
                 "one field from another: %s",
                 (void *)manager, rejected, tnx_v50_reject_text(reasons, sizeof(reasons)));

        return;
    }

    n = (usable < TNX_V48_ELEMS) ? usable : TNX_V48_ELEMS;

    for (int i = 0; i < n; i++) {
        if (!tnx_read_bytes(objects[i].object, words[i], sizeof(words[i]))) {
            tnx_logf("v100 fields element %d at %p unreadable over 0x%x bytes",
                     i, (void *)objects[i].object, (unsigned)sizeof(words[i]));
            return;
        }
    }

    tnx_logf("v100 fields manager=%p usable=%d rejected=%d sample=%d window=+0x0..+0x%x",
             (void *)manager, usable, rejected, n, (unsigned)((TNX_V48_WORDS - 1) * 4));

    for (int w = 0; w < TNX_V48_WORDS; w++) {
        int distinct = 0;
        int allSmall = 1;
        int allTiny = 1;
        int64_t minV = 0;
        int64_t maxV = 0;

        for (int i = 0; i < n; i++) {
            int32_t value = (int32_t)words[i][w];
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (words[j][w] == words[i][w]) { seen = 1; break; }
            }

            if (!seen) distinct++;

            if (i == 0) { minV = value; maxV = value; }
            if (value < minV) minV = value;
            if (value > maxV) maxV = value;

            if (!tnx_v48_small(value)) allSmall = 0;
            if (value < 0 || value > 15) allTiny = 0;
        }

        if (distinct <= 1) continue;

        tnx_logf("v100 off +0x%02x distinct=%d/%d min=%lld max=%lld small=%d tiny=%d %s%s",
                 w * 4, distinct, n, (long long)minV, (long long)maxV, allSmall, allTiny,
                 (allTiny && distinct >= 2 && distinct <= TNX_V48_TEAM_MAX) ? "TEAM? " : "",
                 (allSmall && distinct == n) ? "VARIES/PAIR-MEMBER?" : "");

        if (teamOff < 0 && allTiny && distinct >= 2 && distinct <= TNX_V48_TEAM_MAX) {
            teamOff = w * 4;
            teamDistinct = distinct;
        }

        if (coordOff < 0 && allSmall && distinct == n) {
            coordOff = w * 4;
            coordDistinct = distinct;
        }
    }

    if (teamOff == (int)TNX_OBJ_X_OFF || teamOff == (int)TNX_OBJ_Y_OFF) {
        tnx_logf("v100 walk error: teamOff=+0x%x equals the repository coordinate offset, so the "
                 "walk hit strings and not objects - the team offset is refused and left unset",
                 teamOff);

        teamOff = -1;
        teamDistinct = 0;
    }

    if (teamOff < 0) {
        tnx_logf("v100 teamOff unset after the walk, the engine's own +0x4c is used src=log-v55");
    }

    {
        int order[TNX_V48_WORDS];
        int orderCount = 0;
        int defaultWord = (int)(TNX_OBJ_X_OFF / 4);

        if (defaultWord >= 0 && defaultWord + 1 < TNX_V48_WORDS) order[orderCount++] = defaultWord;

        for (int w = 0; w + 1 < TNX_V48_WORDS; w++) {
            if (w != defaultWord) order[orderCount++] = w;
        }

        for (int k = 0; k < orderCount && intPairOff < 0; k++) {
            int w = order[k];
            int ok = 1;
            int dx = 0;
            int dy = 0;

            if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff)) continue;

            for (int i = 0; i < n && ok; i++) {
                if (!tnx_v48_small((int32_t)words[i][w])) ok = 0;
                if (!tnx_v48_small((int32_t)words[i][w + 1])) ok = 0;
            }

            if (!ok) continue;

            for (int i = 0; i < n; i++) {
                int seenX = 0;
                int seenY = 0;

                for (int j = 0; j < i; j++) {
                    if (words[j][w] == words[i][w]) seenX = 1;
                    if (words[j][w + 1] == words[i][w + 1]) seenY = 1;
                }

                if (!seenX) dx++;
                if (!seenY) dy++;
            }

            if (dx == n && dy == n) {
                intPairOff = w * 4;

                tnx_logf("v100 coord pair int32 at +0x%02x,+0x%02x all %d distinct team=+0x%x "
                         "excluded from the candidates", w * 4, (w + 1) * 4, n, teamOff);
            }
        }
    }

    for (int w = 0; w + 1 < TNX_V48_WORDS && floatPairOff < 0; w++) {
        int ok = 1;
        int anyNonZero = 0;
        int distinctPairs = 0;
        int seenAny = 0;
        float fx = 0.0f;
        float fy = 0.0f;

        if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff)) continue;

        for (int i = 0; i < n; i++) {
            float ax = tnx_v48_as_float(words[i][w]);
            float ay = tnx_v48_as_float(words[i][w + 1]);
            int seen = 0;

            if (!(ax > -TNX_V48_FLOAT_MAX && ax < TNX_V48_FLOAT_MAX)) ok = 0;
            if (!(ay > -TNX_V48_FLOAT_MAX && ay < TNX_V48_FLOAT_MAX)) ok = 0;
            if (words[i][w] != 0 || words[i][w + 1] != 0) anyNonZero = 1;

            if (i == 0) { fx = ax; fy = ay; }

            for (int j = 0; j < i; j++) {
                if (words[j][w] == words[i][w] && words[j][w + 1] == words[i][w + 1]) { seen = 1; break; }
            }

            if (!seen) { distinctPairs++; if (i > 0) seenAny = 1; }
        }

        if (!ok || !anyNonZero || !seenAny) continue;

        floatPairOff = w * 4;

        tnx_logf("v100 coord pair float32 at +0x%02x,+0x%02x first=(%.3f,%.3f) distinct=%d/%d",
                 w * 4, (w + 1) * 4, fx, fy, distinctPairs, n);
    }

    tnx_logf("v100 named teamOff=%s0x%x distinct=%d | coordOff=%s0x%x distinct=%d | "
             "intPair=%s0x%x | floatPair=%s0x%x",
             teamOff >= 0 ? "+" : "none:", teamOff >= 0 ? teamOff : 0, teamDistinct,
             coordOff >= 0 ? "+" : "none:", coordOff >= 0 ? coordOff : 0, coordDistinct,
             intPairOff >= 0 ? "+" : "none:", intPairOff >= 0 ? intPairOff : 0,
             floatPairOff >= 0 ? "+" : "none:", floatPairOff >= 0 ? floatPairOff : 0);

    g_v57_coord_off = (int)TNX_OBJ_X_OFF;

    if (!g_v89_coord_fixed_logged) {
        g_v89_coord_fixed_logged = 1;

        tnx_logf("v100 walk coord fixed +%#llx/+%#llx (was auto) - the walk reads x and y at those "
                  "two int32 and nowhere else; this block measured pair=+0x%x and single=+0x%x "
                  "and neither is applied any more, because the v88 run had the walk land on "
                  "+0x3c/+0x40 in the second battle while the same block printed +0x30/+0x34, "
                  "and that battle's pos= then read (owner index, team) as coordinates",
                 (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF,
                 intPairOff >= 0 ? intPairOff : 0, coordOff >= 0 ? coordOff : 0);
    }
}

void tnx_v48_probe(uintptr_t manager, uintptr_t mode, int verbose) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    int rejected = 0;
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int teamsNew[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int distinctOld = 0;
    int distinctNew = 0;

    memset(objects, 0, sizeof(objects));

    g_v47_probe_done = 1;

    if (mode) tnx_v47_read_map(mode);

    {
        static int v142_walk_logs = 0;

        if (v142_walk_logs < 12 || (v142_walk_logs % 128) == 0) {
            v142_walk_logs++;

            tnx_logf("v142 walk enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d manager=%p "
                     "- the walk reads the tuple the tick snapshot handed it, so this line and "
                     "the score line must print the same arr and n", (void *)g_v142_tick_array,
                     g_v142_tick_count, (void *)g_players_array, g_players_count,
                     (void *)g_v142_tick_array, g_v142_tick_count, (void *)manager);
        }
    }

    usable = tnx_v48_collect(manager, objects, TNX_V47_OBJECT_MAX, &rejected);

    {
        static int v142_leave_logs = 0;

        if (v142_leave_logs < 12 || (v142_leave_logs % 128) == 0) {
            v142_leave_logs++;

            tnx_logf("v142 walk leave arr=%p n=%d g_arr=%p g_n=%d aborted=%d abortI=%d usable=%d "
                     "rejected=%d - aborted=1 names the pass that stopped because the published "
                     "tuple moved under it, which is the case that walked a list the engine had "
                     "already replaced", (void *)g_v142_walk_arr, g_v142_walk_n,
                     (void *)g_v142_pub_array, g_v142_pub_count, g_v142_walk_aborted,
                     g_v142_walk_abort_i, usable, rejected);
        }
    }

    for (int i = 0; i < usable; i++) {
        if (objects[i].x > -TNX_V47_COORD_ABS_MAX && objects[i].x < TNX_V47_COORD_ABS_MAX &&
            objects[i].y > -TNX_V47_COORD_ABS_MAX && objects[i].y < TNX_V47_COORD_ABS_MAX) {
            inRange++;
        }

        if (objects[i].teamOld >= 0 && objects[i].teamOld < 8) teamsOld[objects[i].teamOld] = 1;
        if (objects[i].teamNew >= 0 && objects[i].teamNew < 8) teamsNew[objects[i].teamNew] = 1;

        {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].x == objects[i].x && objects[j].y == objects[i].y) { seen = 1; break; }
            }

            if (!seen) distinct++;
        }
    }

    for (int i = 0; i < 8; i++) {
        if (teamsOld[i]) distinctOld++;
        if (teamsNew[i]) distinctNew++;
    }

    g_v47_team_off = (int)TNX_OBJ_TEAM_OFF;

    {
        char reasons[320];

        tnx_logf("v100 man walk mode=%p manager=%p usable=%d rejected=%d (%s) mapOk=%d mapW=%d "
                 "mapH=%d inRange=%d distinct=%d teamsOld=%d teamsNew=%d teamOff=0x%x",
                 (void *)mode, (void *)manager, usable, rejected,
                 tnx_v50_reject_text(reasons, sizeof(reasons)), g_v47_map_ok, g_v47_map_w,
                 g_v47_map_h, inRange, distinct, distinctOld, distinctNew, g_v47_team_off);
    }

    tnx_logf("v100 walk team reverted to +0x%x with distinct(+0x40)=%d distinct(+0x4c)=%d - the "
             "v92 teamdump settled it: +0x40 is 1,1,0,0 on four elements while +0x4c reads 0,2,"
             "29535,0 and 29535 is the pair 0x5f 0x73, so +0x4c is an inline std::string and not a "
             "side; a distinct count above one is not proof, only the byte dump is",
             g_v47_team_off, distinctOld, distinctNew);

    tnx_logf("v100 walk offsets team=+0x%x distinctOld=%d distinctNew=%d coord=+0x%llx/+0x%llx "
             "usable=%d distinct=%d inRange=%d - both fixed constants, not chosen from a sample",
             g_v47_team_off, distinctOld, distinctNew,
             (unsigned long long)tnx_v57_coord_x_off(), (unsigned long long)tnx_v57_coord_y_off(),
             usable, distinct, inRange);

    if (!TNX_V113_DEAD_ONCE || !g_v113_dead_probe_done) {
        g_v113_dead_probe_done = 1;
    }

    if (verbose) {
        tnx_logf("v100 offsets obj off=0x%llx/0x%llx x=0x%llx y=0x%llx teamOld=0x%llx teamNew=0x%llx "
                 "owner=0x%llx dead=0x%llx active=0x%llx tilemap=0x%llx w=0x%llx",
                 TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF, TNX_OBJ_X_OFF, TNX_OBJ_Y_OFF,
                 TNX_OBJ_TEAM_OFF, TNX_OBJ_TEAMENGINE_OFF, TNX_OBJ_OWNERINDEX_OFF,
                 TNX_OBJ_DEADFLAG_OFF, TNX_OBJ_ACTIVEFLAG_OFF,
                 TNX_MODE_TILEMAP_OFF, TNX_TILEMAP_WIDTH_OFF);

        for (int i = 0; i < usable && i < 16; i++) {
            tnx_logf("v100 player[%02d] at=%p gid=%d pos=(%d,%d) team40=%d own=%d dead=%d active=%d "
                     "- pos is x and y read at +%#llx/+%#llx as int32, team40 is the side read at "
                     "+%#llx; neither is selected by a heuristic any more",
                     i, (void *)objects[i].object, objects[i].gid, objects[i].x, objects[i].y,
                     objects[i].teamOld, objects[i].ownerIndex, objects[i].dead,
                     objects[i].activeFlag & 1, (unsigned long long)TNX_OBJ_X_OFF,
                     (unsigned long long)TNX_OBJ_Y_OFF, (unsigned long long)TNX_OBJ_TEAM_OFF);
        }
    }

    g_v47_coord_usable = usable;
    g_v47_coord_distinct = distinct;

    {
        int unique = 0;

        for (int i = 0; i < usable; i++) {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].gid == objects[i].gid) {
                    seen = 1;
                    break;
                }
            }

            if (!seen) unique++;
        }

        tnx_logf("v100 gid unique=%d of usable=%d distinct=%d - below usable means the container "
                 "carries duplicate ids and anything grouped by gid groups the wrong elements",
                 unique, usable, distinct);
    }

    tnx_v92_team_dump(objects, usable);
    tnx_v93_class_dump(objects, usable);

    g_v47_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;

    tnx_logf("v100 coords ok=%d (need >=2 objects, all in range, >=2 distinct positions, "
             "and a team field that splits them)",
             g_v47_coord_ok);

    {
        int back = 0;
        int backRead = 0;

        for (int i = 0; i < usable; i++) {
            void *backPtr = NULL;

            if (!tnx_read_ptr(objects[i].object + TNX_V88_ELEM_BACK_OFF, &backPtr)) continue;

            backRead++;

            if ((uintptr_t)backPtr == manager) back++;
        }

        tnx_logf("v100 membership manager=%p usable=%d back=%d read=%d - [elem+%#llx] is the "
                 "membership test now: an element whose word there names the container belongs to "
                 "it, and the owner chain through owner+0 and owner+%#llx is no longer consulted",
                 (void *)manager, usable, back, backRead,
                 (unsigned long long)TNX_V88_ELEM_BACK_OFF,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);
    }
}

int tnx_v95_finite(float v) {
    if (v != v) return 0;
    if (v <= -1.0e9f) return 0;
    if (v >= 1.0e9f) return 0;

    return 1;
}

int g_v162_logs = 0;

int32_t g_v162_max_x = 0;

int32_t g_v162_max_y = 0;

uintptr_t tnx_v162_bounds_obj(uintptr_t receiver) {
    uintptr_t out = 0;

    if (!receiver) return 0;
    if (!tnx_callable(TNX_V162_BOUNDS_RVA)) return 0;

    out = ((uintptr_t (*)(uintptr_t))(g_base + TNX_V162_BOUNDS_RVA))(receiver);

    if (!out || (out & 7)) return 0;
    if (!tnx_addr_readable(out, 0x100)) return 0;

    return out;
}

int tnx_v162_clamp(int32_t *x, int32_t *y) {
    uintptr_t receiver = tnx_v144_hop(tnx_v150_controller(), NULL);
    uintptr_t bounds = tnx_v162_bounds_obj(receiver);
    int32_t maxX = 0;
    int32_t maxY = 0;
    int32_t ox = *x;
    int32_t oy = *y;

    if (!bounds) {
        if (g_v162_logs < TNX_V162_LOGS) {
            g_v162_logs++;

            tnx_logf("v162 clamp skipped receiver=%p - the bounds accessor returned nothing, so the "
                     "target is sent unchanged", (void *)receiver);
        }

        return 0;
    }

    if (!tnx_read_i32(bounds + TNX_V162_BOUNDS_X_OFF, &maxX)) return 0;
    if (!tnx_read_i32(bounds + TNX_V162_BOUNDS_Y_OFF, &maxY)) return 0;

    if (maxX <= 3 || maxY <= 3 || maxX > 200000 || maxY > 200000) {
        if (g_v162_logs < TNX_V162_LOGS) {
            g_v162_logs++;

            tnx_logf("v162 clamp skipped max=(%d,%d) receiver=%p bounds=%p - the bounds were read but "
                     "are not a playable extent, so the target is sent unchanged rather than clamped "
                     "to a wrong box", maxX, maxY, (void *)receiver, (void *)bounds);
        }

        return 0;
    }

    g_v162_max_x = maxX;
    g_v162_max_y = maxY;

    tnx_v163_map_dump(bounds);

    if (*x > maxX - 2) *x = maxX - 2;
    if (*y > maxY - 2) *y = maxY - 2;
    if (*x <= 1) *x = 0;
    if (*y <= 1) *y = 0;

    if (g_v162_logs < TNX_V162_LOGS) {
        g_v162_logs++;

        tnx_logf("v162 clamp max=(%d,%d) target=(%d,%d)->(%d,%d) receiver=%p bounds=%p - the bounds "
                 "come from the engine accessor at %#llx on the actuator receiver read at +%#llx and "
                 "+%#llx, and the clamp applies the same rule the input path applies before it queues "
                 "the move, so a destination outside the arena is never sent",
                 maxX, maxY, ox, oy, *x, *y, (void *)receiver, (void *)bounds,
                 (unsigned long long)TNX_V162_BOUNDS_RVA,
                 (unsigned long long)TNX_V162_BOUNDS_X_OFF,
                 (unsigned long long)TNX_V162_BOUNDS_Y_OFF);
    }

    return 1;
}

uint64_t g_v213_dec_us = 0;

uint64_t g_v213_dec_us_max = 0;

uint64_t tnx_v213_us(void) {
    static mach_timebase_info_data_t tb;
    static int ready = 0;
    uint64_t t = 0;

    if (!ready) {
        ready = 1;
        mach_timebase_info(&tb);
    }

    t = mach_absolute_time();

    if (tb.denom == 0) return t / 1000ULL;

    return (t / (uint64_t)tb.denom) * (uint64_t)tb.numer / 1000ULL;
}

int g_v177_logs = 0;

int g_v177_seeded = 0;

int32_t g_v177_last_x = 0;

int32_t g_v177_last_y = 0;

void tnx_v177_paircal(void) {
    uintptr_t ctrl = tnx_v150_controller();
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t px = 0;
    int32_t py = 0;
    int dx = 0;
    int dy = 0;
    float pLen = 0.0f;
    float mLen = 0.0f;
    float dot = 0.0f;
    float angPair = 0.0f;
    float angMove = 0.0f;

    if ((g_v48_ticks % 60) != 0) return;
    if (g_v177_logs >= TNX_V177_LOGS) return;
    if (g_v174_stick_hold) return;
    if (!ctrl) return;
    if (!tnx_v178_own(&ownX, &ownY)) return;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_X_OFF, &px)) return;
    if (!tnx_read_i32(ctrl + TNX_V128_CTRL_RAW_Y_OFF, &py)) return;

    if (g_v177_seeded) {
        dx = (int)(ownX - g_v177_last_x);
        dy = (int)(ownY - g_v177_last_y);
    }

    g_v177_seeded = 1;
    g_v177_last_x = ownX;
    g_v177_last_y = ownY;

    pLen = sqrtf((float)(px * px + py * py));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (pLen < 1.0f || mLen < 1.0f) return;

    g_v177_logs++;

    dot = ((float)px / pLen) * ((float)dx / mLen) + ((float)py / pLen) * ((float)dy / mLen);
    angPair = atan2f((float)py, (float)px) * 57.2958f;
    angMove = atan2f((float)dy, (float)dx) * 57.2958f;

    tnx_logf("v177 paircal pair=(%d,%d) len=%.0f move=(%d,%d) len=%.0f dot=%+.2f angPair=%.1f "
             "angMove=%.1f angDelta=%.1f own=(%d,%d) - the engine writes the pair at ctrl+%#llx itself "
             "when the player drags, so this line pairs its vector with the heading the character "
             "really travelled in the same second; angDelta is the rotation between the screen space "
             "the pair lives in and the world space the character moves in, and a handful of samples "
             "in different directions is enough to write the pair for a chosen world heading, which is "
             "what the walk cycle needs",
             px, py, (double)pLen, dx, dy, (double)mLen, (double)dot, (double)angPair, (double)angMove,
             (double)(angMove - angPair), ownX, ownY,
             (unsigned long long)TNX_V128_CTRL_RAW_X_OFF);
}
