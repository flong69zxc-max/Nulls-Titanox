#include "../../recoil.h"

int rcl_find_joy_done = 0;


uintptr_t rcl_manager_ptr = 0;

int rcl_collect(uintptr_t manager, rcl_obj_t *out, int capacity) {
    void *data = NULL;
    int32_t count = 0;
    int usable = 0;
    uintptr_t gidOff = RCL_OBJ_GLOBALID_OFF;
    uint32_t walkSeq = 0;


    rcl_gidless_scan(manager);


    if (!manager) return 0;
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &data) || !data) return 0;
    if (!rcl_read_int((uintptr_t)manager + RCL_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0) return 0;

    if (count > capacity) count = capacity;

    gidOff = rcl_list_gid_off((uintptr_t)data, count);

    walkSeq = rcl_seq;


    for (int32_t i = 0; i < count && usable < capacity; i++) {
        void *element = NULL;
        void *vtable = NULL;
        rcl_obj_t entry;
        uintptr_t vtRva = 0;

        memset(&entry, 0, sizeof(entry));


        if (rcl_seq != walkSeq) {

            break;
        }

        if (!rcl_read_ptr((uintptr_t)data + (uintptr_t)i * sizeof(void *), &element)) {

            continue;
        }

        if (!element) {

            continue;
        }

        entry.object = (uintptr_t)element;

        if (rcl_element_ascii(entry.object)) {

            continue;
        }

        if (!rcl_read_ptr(entry.object, &vtable) || !vtable) {

            continue;
        }

        vtRva = (uintptr_t)vtable - rcl_base;

        if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE) {

            continue;
        }

        entry.gid = rcl_gid_at(entry.object, gidOff);

        {
            uintptr_t tw = 0;

            rcl_element_type((uintptr_t)vtable, &tw);

            entry.typeWord = (int32_t)tw;
        }

        if (!rcl_read_int(entry.object + rcl_coord_x_off(), &entry.x) ||
            !rcl_read_int(entry.object + rcl_coord_y_off(), &entry.y) ||
            !rcl_read_int(entry.object + RCL_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
            !rcl_read_int(entry.object + RCL_OBJ_TEAM_OFF, &entry.teamOld) ||
            !rcl_read_int(entry.object + RCL_TEAM_OFF, &entry.teamNew) ||
            !rcl_read_byte(entry.object + RCL_OBJ_DEADFLAG_OFF, &entry.dead) ||
            !rcl_read_byte(entry.object + RCL_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag)) {

            continue;
        }

        if (entry.gid >= RCL_PLAYER_GID_MAX) {

            rcl_proj_track(entry.object, vtRva, entry.gid, entry.teamOld);

            if (rcl_dump_np < RCL_NP_DUMPS) {
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

                rcl_dump_np++;

                rcl_read_int(entry.object + RCL_OBJ_X_OFF, &npX);
                rcl_read_int(entry.object + RCL_OBJ_Y_OFF, &npY);
                rcl_read_int(entry.object + RCL_OFF, &np70);
                rcl_read_int(entry.object + RCL_OFF + 4ULL, &np74);
                rcl_read_ptr(entry.object + RCL_NP_PTR_OFF, &np38);
                if (!rcl_read_float(entry.object + RCL_OBJ_X_OFF, &npFx)) npFx = 0.0f;
                if (!rcl_read_float(entry.object + RCL_OBJ_Y_OFF, &npFy)) npFy = 0.0f;
                if (!rcl_read_float(entry.object + RCL_OFF, &npF70)) npF70 = 0.0f;
                if (!rcl_read_float(entry.object + RCL_OFF + 4ULL, &npF74)) npF74 = 0.0f;

            }

            continue;
        }

        if (entry.gid == 0 && !rcl_gidless) {

            continue;
        }

        if (entry.x <= -RCL_COORD_ABS_MAX || entry.x >= RCL_COORD_ABS_MAX ||
            entry.y <= -RCL_COORD_ABS_MAX || entry.y >= RCL_COORD_ABS_MAX) {
            if (rcl_coord_logs < 6) {
                void *tvtable = NULL;
                uintptr_t tvtRva = 0;

                rcl_coord_logs++;

                if (rcl_read_ptr(entry.object, &tvtable) && tvtable) tvtRva = (uintptr_t)tvtable - rcl_base;

            }

            if (!RCL_COORD_SOFT) {

                continue;
            }
        }

        if (!((entry.teamOld >= 0 && entry.teamOld <= RCL_OBJ_TEAM_MAX) ||
              (entry.teamNew >= 0 && entry.teamNew <= RCL_OBJ_TEAM_MAX))) {

            continue;
        }


        out[usable++] = entry;
    }


    return usable;
}

int rcl_small(long value) {
    return (value > -RCL_VALUE_MAX && value < RCL_VALUE_MAX) ? 1 : 0;
}

float rcl_as_float(uint32_t bits) {
    union { uint32_t u; float f; } view;

    view.u = bits;

    return view.f;
}

void rcl_discriminate(uintptr_t manager) {
    rcl_obj_t objects[RCL_OBJECT_MAX];
    uint32_t words[RCL_ELEMS][RCL_WORDS_2];
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


    usable = rcl_collect(manager, objects, RCL_OBJECT_MAX);

    rcl_dodge_probe_usable = usable;
    if (usable > 0) memcpy(rcl_dodge_probe_list, objects, (size_t)usable * sizeof(rcl_dodge_probe_list[0]));

    if (usable == 0) {
        char reasons[320];


        return;
    }

    if (usable == 1) {
        char reasons[320];


        return;
    }

    n = (usable < RCL_ELEMS) ? usable : RCL_ELEMS;

    for (int i = 0; i < n; i++) {
        if (!rcl_read_bytes(objects[i].object, words[i], sizeof(words[i]))) {
            return;
        }
    }


    for (int w = 0; w < RCL_WORDS_2; w++) {
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

            if (!rcl_small(value)) allSmall = 0;
            if (value < 0 || value > 15) allTiny = 0;
        }

        if (distinct <= 1) continue;


        if (teamOff < 0 && allTiny && distinct >= 2 && distinct <= RCL_TEAM_MAX) {
            teamOff = w * 4;
            teamDistinct = distinct;
        }

        if (coordOff < 0 && allSmall && distinct == n) {
            coordOff = w * 4;
            coordDistinct = distinct;
        }
    }

    if (teamOff == (int)RCL_OBJ_X_OFF || teamOff == (int)RCL_OBJ_Y_OFF) {

        teamOff = -1;
        teamDistinct = 0;
    }


    {
        int order[RCL_WORDS_2];
        int orderCount = 0;
        int defaultWord = (int)(RCL_OBJ_X_OFF / 4);

        if (defaultWord >= 0 && defaultWord + 1 < RCL_WORDS_2) order[orderCount++] = defaultWord;

        for (int w = 0; w + 1 < RCL_WORDS_2; w++) {
            if (w != defaultWord) order[orderCount++] = w;
        }

        for (int k = 0; k < orderCount && intPairOff < 0; k++) {
            int w = order[k];
            int ok = 1;
            int dx = 0;
            int dy = 0;

            if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff)) continue;

            for (int i = 0; i < n && ok; i++) {
                if (!rcl_small((int32_t)words[i][w])) ok = 0;
                if (!rcl_small((int32_t)words[i][w + 1])) ok = 0;
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

            }
        }
    }

    for (int w = 0; w + 1 < RCL_WORDS_2 && floatPairOff < 0; w++) {
        int ok = 1;
        int anyNonZero = 0;
        int distinctPairs = 0;
        int seenAny = 0;
        float fx = 0.0f;
        float fy = 0.0f;

        if (teamOff >= 0 && (w * 4 == teamOff || (w + 1) * 4 == teamOff)) continue;

        for (int i = 0; i < n; i++) {
            float ax = rcl_as_float(words[i][w]);
            float ay = rcl_as_float(words[i][w + 1]);
            int seen = 0;

            if (!(ax > -RCL_FLOAT_MAX && ax < RCL_FLOAT_MAX)) ok = 0;
            if (!(ay > -RCL_FLOAT_MAX && ay < RCL_FLOAT_MAX)) ok = 0;
            if (words[i][w] != 0 || words[i][w + 1] != 0) anyNonZero = 1;

            if (i == 0) { fx = ax; fy = ay; }

            for (int j = 0; j < i; j++) {
                if (words[j][w] == words[i][w] && words[j][w + 1] == words[i][w + 1]) { seen = 1; break; }
            }

            if (!seen) { distinctPairs++; if (i > 0) seenAny = 1; }
        }

        if (!ok || !anyNonZero || !seenAny) continue;

        floatPairOff = w * 4;

    }



    if (!rcl_coord_fixed_logged) {
        rcl_coord_fixed_logged = 1;

    }
}




uintptr_t rcl_bounds_obj(uintptr_t receiver) {
    void *out = NULL;

    if (!receiver) return 0;
    if (!rcl_pointer_plausible(receiver)) return 0;
    if (!rcl_read_ptr(receiver + (uintptr_t)RCL_BOX_PTR_OFF, &out)) return 0;
    if (!out) return 0;
    if (((uintptr_t)out & 7) != 0) return 0;
    if (!rcl_addr_readable((uintptr_t)out, 0x100)) return 0;

    return (uintptr_t)out;
}

int rcl_clamp(int32_t *x, int32_t *y) {
    uintptr_t receiver = rcl_controller();
    uintptr_t bounds = rcl_bounds_obj(receiver);
    int32_t maxX = 0;
    int32_t maxY = 0;
    int32_t ox = *x;
    int32_t oy = *y;

    if (!bounds) {

        return 0;
    }

    if (!rcl_read_int(bounds + RCL_BOUNDS_X_OFF, &maxX)) return 0;
    if (!rcl_read_int(bounds + RCL_BOUNDS_Y_OFF, &maxY)) return 0;

    if (maxX <= 3 || maxY <= 3 || maxX > 200000 || maxY > 200000) {

        return 0;
    }



    if (*x > maxX - 2) *x = maxX - 2;
    if (*y > maxY - 2) *y = maxY - 2;
    if (*x <= 1) *x = 0;
    if (*y <= 1) *y = 0;


    return 1;
}

uint64_t rcl_dec_us = 0;

uint64_t rcl_dec_us_max = 0;

uint64_t rcl_us(void) {
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

int rcl_logs_a = 0;

int rcl_seeded = 0;

int32_t rcl_last_x_a = 0;

int32_t rcl_last_y_a = 0;

uintptr_t rcl_pair_base(void) {
    void *battleRaw = NULL;
    uintptr_t battle = 0;
    uintptr_t alt = rcl_controller();

    if (rcl_base && rcl_read_ptr(rcl_base + RCL_BATTLE_RVA, &battleRaw)) {
        battle = (uintptr_t)battleRaw;
    }

    if (battle) {
        if (rcl_hop(battle, NULL)) return battle;
    }

    return alt;
}
