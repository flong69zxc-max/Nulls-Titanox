#include "titanox.h"















int t_prev_state = -1;



















int t_hop_chosen = -1;

int t_hop_sticky = 0;


int t_modesig_hits = 0;


int t_floor_logged = 0;

int t_fallback_logged = 0;


int t_elem_dumps = 0;

int t_hop2_census = 0;

int t_type3_floats = 0;

uintptr_t t_census_container = 0;


uintptr_t t_census_array = 0;

uintptr_t t_census_first = 0;

uint64_t t_census_ms = 0;





uintptr_t t_scan_container = 0;


int t_own_logged = 0;





uint64_t t_wrote_tick = 0;

int t_wrote_valid = 0;

int t_check_done = 0;









uint64_t t_pred_took = 0;

uint64_t t_pred_miss = 0;


int tnx_modesig_hit(uintptr_t at) {
    void *vt = NULL;
    void *mgr = NULL;
    int32_t ec = 0;
    int32_t m124 = 0;
    int32_t count = 0;

    if (!at) return 0;
    if (!tnx_read_ptr(at, &vt) || !vt) return 0;
    if (!tnx_vtable_in_image((uintptr_t)vt)) return 0;
    if (!tnx_vtable_is_data((uintptr_t)vt)) {

        return 0;
    }
    if (!tnx_read_int(at + 0x124ULL, &m124) || m124 < 0x01 || m124 > 0x80) return 0;
    if (!tnx_read_int(at + 0xecULL, &ec) || ec < -1024 || ec > 1024) return 0;
    if (!tnx_read_ptr(at + TNX_MODE_MANAGER_OFF, &mgr) || !mgr) return 0;
    if (!tnx_pointer_plausible((uintptr_t)mgr)) return 0;
    if (!tnx_read_int((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count < 2 || count > TNX_MANAGER_MAX_OBJECTS) return 0;

    return 1;
}

void tnx_modesig_tick(void) {
    uintptr_t found = 0;

    if (t_scene_object) return;
    if (!t_battle_active && (t_ticks_b % TNX_BUCKET_TICKS_2) != 0) return;

    for (int i = 0; i < t_objhit_count && !found; i++) {
        if (tnx_modesig_hit(t_objhits[i].at)) found = t_objhits[i].at;
    }

    if (!found) return;

    if (t_sig_last == found) {
        t_sig_ticks++;
    } else {
        t_sig_last = found;
        t_sig_ticks = 1;

    }

    if (t_sig_ticks < TNX_MODESIG_TICKS) return;

    {
        void *vt = NULL;
        void *mgr = NULL;
        int32_t ec = 0;
        int32_t m124 = 0;
        int32_t count = 0;
        int32_t cap = 0;

        t_modesig_hits++;
        t_scene_object = found;
        t_battle_last_tick = (int)t_ticks_b;

        tnx_read_ptr(found, &vt);
        tnx_read_ptr(found + TNX_MODE_MANAGER_OFF, &mgr);
        tnx_read_int(found + 0xecULL, &ec);
        tnx_read_int(found + 0x124ULL, &m124);
        tnx_read_int((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count);
        tnx_read_int((uintptr_t)mgr + TNX_MGR_CAP_OFF, &cap);


        if (count >= 2 && cap >= count && cap <= TNX_MGR_CAP_MAX) {
            void *mgrArray = NULL;

            t_manager_count = count;

            if (tnx_read_ptr((uintptr_t)mgr + TNX_MGR_ARRAY_OFF, &mgrArray) && mgrArray) {
                tnx_publish((uintptr_t)mgr, (uintptr_t)mgrArray, count, cap, "modesig");
            }

        }
    }
}

int tnx_element_type(uintptr_t vt, uintptr_t *wordOut) {
    void *slotPtr = NULL;
    uintptr_t slot = 0;

    if (wordOut) *wordOut = 0;

    if (!vt) return -1;
    if (!tnx_read_ptr(vt + TNX_TYPE_SLOT_OFF, &slotPtr) || !slotPtr) return -1;

    slot = tnx_strip_ptr((uintptr_t)slotPtr) - t_base;

    if (wordOut) *wordOut = slot;

    switch (slot) {
        case 0x0014c81cULL: return 0;
        case 0x00a31768ULL: return 1;
        case 0x009f4ec8ULL: return 2;
        case 0x00314ca0ULL: return 3;
        case 0x00490b54ULL: return 4;
        case 0x0086f494ULL: return 5;
        case 0x00370688ULL: return 6;
        case 0x00490d94ULL: return 8;
        default: return -1;
    }
}

void tnx_container_census(uintptr_t array, int32_t count, uintptr_t container) {
    int accepted = 0;
    int typed = 0;
    int types = 0;
    int typeMask = 0;
    int teams = 0;
    int teamMask = 0;
    int gidSeen = 0;
    int classSeen = -1;
    int back = 0;
    uintptr_t histRva[TNX_HIST_MAX];
    uintptr_t histWord[TNX_HIST_MAX];
    int histCount[TNX_HIST_MAX];
    int histN = 0;
    int32_t v70lo = 0;
    int32_t v70hi = 0;
    int v70n = 0;
    char histText[768];
    int h = 0;

    if (!array || count <= 0) return;

    {
        void *firstPtr = NULL;
        uintptr_t first = 0;
        uint64_t nowMs = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        int same = (container == t_census_container &&
                    (uintptr_t)array == t_census_array);
        int firstChanged = 0;

        if (tnx_read_ptr(array, &firstPtr) && firstPtr) first = (uintptr_t)firstPtr;
        firstChanged = (first != t_census_first);

        if (same && !firstChanged && t_census_ms &&
            nowMs - t_census_ms < TNX_CENSUS_MS) {
            return;
        }


        t_census_container = container;
        t_census_array = (uintptr_t)array;
        t_census_first = (uintptr_t)first;
        t_census_ms = nowMs;
    }

    if (count > TNX_DUMP_QWORDS) count = TNX_DUMP_QWORDS;

    for (h = 0; h < TNX_HIST_MAX; h++) {
        histRva[h] = 0;
        histWord[h] = 0;
        histCount[h] = 0;
    }

    for (int32_t i = 0; i < count; i++) {
        uintptr_t at = array + (uintptr_t)i * sizeof(void *);
        void *element = NULL;
        void *vt = NULL;
        void *def = NULL;
        char why[160] = { 0 };
        char typeText[16] = { 0 };
        uintptr_t classRva = 0;
        uintptr_t typeWord = 0;
        int32_t team = 0;
        int32_t gid = 0;
        int32_t kind = 0;
        int32_t kind68 = 0;
        int32_t teamHyp = 0;
        int32_t byte48 = 0;
        void *backPtr = NULL;
        int elementBack = 0;
        int type = -1;
        int ok = 0;

        if (!tnx_read_ptr(at, &element) || !element) {
            continue;
        }

        tnx_read_ptr((uintptr_t)element, &vt);
        tnx_read_int((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_int((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);

        if (gid >= TNX_GID_FLOOR && gid < TNX_PLAYER_GID_MAX &&
            team >= 0 && team <= TNX_TEAM_MAX_2) {
            ok = 1;
            snprintf(why, sizeof(why), "gid=%d in [%d,%d) and team=%d in range - accepted on the id "
                     "the engine itself assigns, with no definition pointer read at all",
                     gid, TNX_GID_FLOOR, TNX_GID_MAX, team);
        } else {
            ok = 0;
            snprintf(why, sizeof(why), "gid=%d outside [%d,%d) or team=%d outside 0..%d - refused "
                     "with no definition pointer read at all, because the v127 run showed the def "
                     "field empty at the moment the census looks at it and every element was called "
                     "unaccepted on that empty field while carrying a real id",
                     gid, TNX_GID_FLOOR, TNX_GID_MAX, team, TNX_TEAM_MAX_2);
        }
        tnx_read_int((uintptr_t)element + TNX_HYP_TEAM_OFF, &teamHyp);
        tnx_read_int((uintptr_t)element + TNX_HYP_BYTE_OFF, &byte48);
        if (tnx_read_ptr((uintptr_t)element + TNX_ELEM_BACK_OFF, &backPtr) &&
            (uintptr_t)backPtr == container) {
            elementBack = 1;
            back++;
        }
        if (tnx_read_ptr((uintptr_t)element + TNX_ELEM_DEF_OFF, &def) && def) {
            tnx_read_int((uintptr_t)def + TNX_KIND_OFF, &kind);
            tnx_read_int((uintptr_t)def + TNX_DEF_68_OFF, &kind68);
        }

        type = tnx_element_type((uintptr_t)vt, &typeWord);

        if (type < 0) snprintf(typeText, sizeof(typeText), "unknown");
        else snprintf(typeText, sizeof(typeText), "%d", type);

        classRva = tnx_strip_ptr((uintptr_t)vt) - t_base;

        if (classSeen < 0) classSeen = (int)classRva;
        else if (classSeen != (int)classRva) classSeen = -2;

        for (h = 0; h < histN; h++) {
            if (histRva[h] == classRva) break;
        }

        if (h < histN) {
            histCount[h]++;
        } else if (histN < TNX_HIST_MAX) {
            histRva[histN] = classRva;
            histWord[histN] = typeWord;
            histCount[histN] = 1;
            histN++;
        }

        if (ok) {
            int32_t v70 = 0;

            if (tnx_read_int((uintptr_t)element + TNX_OFF, &v70)) {
                if (v70 != 0 && v70 > -TNX_COORD_MAX && v70 < TNX_COORD_MAX) {
                    if (v70n == 0 || v70 < v70lo) v70lo = v70;
                    if (v70n == 0 || v70 > v70hi) v70hi = v70;
                    v70n++;
                }
            }

            if (gid > 0) {
                if (t_gid_lo == 0 || gid < t_gid_lo) t_gid_lo = gid;
                if (gid > t_gid_hi) t_gid_hi = gid;
            }
        }

        if (i == 0 && type == TNX_TYPE3_CODE) t_type3_floats = 1;

        if (ok) accepted++;

        if (type >= 0) {
            typed++;

            if (type < 32 && !(typeMask & (1 << type))) {
                typeMask |= (1 << type);
                types++;
            }
        }

        if (teamHyp >= 0 && teamHyp < TNX_TEAM_SLOTS && !(teamMask & (1 << teamHyp))) {
            teamMask |= (1 << teamHyp);
            teams++;
        }

        if (gid > 0) gidSeen++;


        if (type == TNX_TYPE3_CODE) {
            float f10 = 0.0f;
            float f1c = 0.0f;
            float f100 = 0.0f;
            float f104 = 0.0f;

            tnx_read_float((uintptr_t)element + TNX_FLOAT_LO, &f10);
            tnx_read_float((uintptr_t)element + TNX_FLOAT_LO2, &f1c);
            tnx_read_float((uintptr_t)element + TNX_FLOAT_HI, &f100);
            tnx_read_float((uintptr_t)element + TNX_FLOAT_HI2, &f104);

        }

        if (t_elem_dumps < TNX_ELEM_DUMPS_2) {
            t_elem_dumps++;


            if (type == TNX_TYPE3_CODE) {
                float h10 = 0.0f;
                float h1c = 0.0f;
                float h100 = 0.0f;
                float h104 = 0.0f;

                tnx_read_float((uintptr_t)element + TNX_FLOAT_LO, &h10);
                tnx_read_float((uintptr_t)element + TNX_FLOAT_LO2, &h1c);
                tnx_read_float((uintptr_t)element + TNX_FLOAT_HI, &h100);
                tnx_read_float((uintptr_t)element + TNX_FLOAT_HI2, &h104);

            }
        }

    }

    t_census_container = container;

    histText[0] = 0;

    for (h = 0; h < histN; h++) {
        char one[96];
        const char *seg = tnx_image_segment_name(t_base + histRva[h]);

        snprintf(one, sizeof(one), "%s%#llx(%s)x%d word=%#llx", h ? " " : "",
                 (unsigned long long)histRva[h], seg ? seg : "-", histCount[h],
                 (unsigned long long)histWord[h]);

        strncat(histText, one, sizeof(histText) - strlen(histText) - 1);
    }


}

uintptr_t t_hop_scene = 0;

int tnx_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut,
                                    int32_t *capOut, char *why, size_t whyLen) {
    const char *reason = NULL;
    void *array = NULL;

    if (arrayOut) *arrayOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;

    if (!object) {
        snprintf(why, whyLen, "null");
        return 0;
    }

    reason = tnx_header_reason(object, countOut, capOut);

    if (reason) {
        snprintf(why, whyLen, "%s", reason);
        return 0;
    }

    if (!tnx_read_ptr(object + TNX_MGR_ARRAY_OFF, &array) || !array) {
        snprintf(why, whyLen, "array-null");
        return 0;
    }

    if (!tnx_heap_resident((uintptr_t)array)) {
        snprintf(why, whyLen, "array-not-heap");
        return 0;
    }

    if (arrayOut) *arrayOut = (uintptr_t)array;

    snprintf(why, whyLen, "ok array=%p count=%d cap=%d", array,
             countOut ? *countOut : 0, capOut ? *capOut : 0);

    return 1;
}

int t_gid_logs = 0;

int t_coord_logs = 0;

int t_dump_done = 0;

int32_t tnx_gid_at(uintptr_t element, uintptr_t off) {
    int32_t gid = 0;

    if (off && tnx_read_int(element + off, &gid)) return gid;

    return 0;
}

int32_t tnx_gid(uintptr_t element, int32_t *offOut) {
    int32_t gid = 0;
    int32_t alt = 0;

    if (offOut) *offOut = 0;
    if (!element) return 0;

    if (tnx_read_int(element + TNX_OBJ_GLOBALID_OFF, &gid) && gid) {
        if (offOut) *offOut = (int32_t)TNX_OBJ_GLOBALID_OFF;

        return gid;
    }

    if (tnx_read_int(element + TNX_GID_FALLBACK_OFF, &alt) && alt) {
        if (offOut) *offOut = (int32_t)TNX_GID_FALLBACK_OFF;

        if (t_gid_logs < 6) {
            void *vtable = NULL;
            uintptr_t vtRva = 0;

            t_gid_logs++;

            if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - t_base;

        }

        return alt;
    }

    return 0;
}


int t_last_choice = -2;

int t_hop_logs = 0;


int tnx_container_score(uintptr_t container) {
    void *array = NULL;
    int32_t count = 0;
    int32_t own = -1;
    int32_t ownTeam = -1;
    int32_t gid = 0;
    int32_t team = 0;
    int samples = 0;
    int gidOk = 0;
    int teamOk = 0;
    int posOk = 0;
    int posDistinct = 0;
    int asciiCount = 0;
    int soft = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t qx = 0;
    int32_t qy = 0;
    int score = 0;
    int i;
    int j;

    if (!container) return -1;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!tnx_read_int(container + TNX_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > TNX_COUNT_MAX) return -1;

    if (own < 0 || own >= count) soft = 1;

    for (i = 0; i < count && samples < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        samples++;
        team = 0;
        px = 0;
        py = 0;

        if (tnx_element_ascii((uintptr_t)element)) asciiCount++;

        gid = tnx_gid((uintptr_t)element, NULL);
        tnx_read_int((uintptr_t)element + TNX_TEAM_OFF, &team);

        if (tnx_read_int((uintptr_t)element + TNX_OBJ_X_OFF, &px) &&
            tnx_read_int((uintptr_t)element + TNX_OBJ_Y_OFF, &py) &&
            px > -TNX_COORD_MAX && px < TNX_COORD_MAX &&
            py > -TNX_COORD_MAX && py < TNX_COORD_MAX && (px != 0 || py != 0)) {
            int dup = 0;

            posOk++;

            for (j = 0; j < i; j++) {
                void *other = NULL;

                if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)j * 8ULL, &other) || !other) continue;
                if (!tnx_read_int((uintptr_t)other + TNX_OBJ_X_OFF, &qx)) continue;
                if (!tnx_read_int((uintptr_t)other + TNX_OBJ_Y_OFF, &qy)) continue;

                if (qx == px && qy == py) {
                    dup = 1;

                    break;
                }
            }

            if (!dup) posDistinct++;
        }

        if (gid) gidOk++;
        if (team >= 0 && team <= 7) teamOk++;
    }

    if (samples > 0 && (asciiCount * 100) / samples > TNX_ASCII_RATIO) {

        return -1;
    }

    if (soft) {
        if (posOk < TNX_SOFT_MIN_POS || posDistinct < TNX_SOFT_MIN_DIST) {

            return -1;
        }

        score = TNX_SOFT_BASE;
    } else {
        score = 6;

        if (ownTeam >= 0 && ownTeam <= 15) score += 2;
    }

    if (gidOk) score += 1;
    if (teamOk) score += 1;
    if (count >= 3) score += 2;
    if (count >= 6) score += 1;

    score += posOk * TNX_POS_BONUS + posDistinct * TNX_DIST_BONUS;


    return score;
}
int tnx_scan_ready(int battle) {
    if (t_ticks_b < TNX_SCAN_FLOOR_TICKS) {
        if (!t_floor_logged) {
            t_floor_logged = 1;

        }

        return 0;
    }

    if (battle || t_scene_object) return 1;

    if (t_ticks_b < TNX_SCAN_FALLBACK_TICKS) return 0;

    if (!t_fallback_logged) {
        t_fallback_logged = 1;

    }

    return (t_ticks_b % TNX_BUCKET_TICKS_2) == 0;
}

void tnx_resolve_addresses(void) {
    if (!t_base) return;

    t_addr_getinstance = tnx_callable(RVA_BATTLEMODE_GETINSTANCE);
    t_addr_getownchar = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    t_addr_getteam = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    t_addr_getx = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    t_addr_gety = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);

    t_addr_setprediction = tnx_callable(TNX_RVA_SETPREDICTION);

    t_addr_battlescreen = t_base + RVA_BATTLESCREEN__BATTLESCREEN;
    if (!tnx_addr_readable(t_addr_battlescreen, sizeof(void *))) t_addr_battlescreen = 0;

}
void tnx_locate_battle_mode(void) {
    if (t_mode_strong) return;

    if (t_votescan_attempts >= TNX_VOTESCAN_ATTEMPTS) {


        return;
    }

    double now = CFAbsoluteTimeGetCurrent();

    if (t_votescan_last > 0.0 && (now - t_votescan_last) < TNX_VOTESCAN_INTERVAL) return;

    t_votescan_last = now;
    t_votescan_attempts++;

    if (t_votescan_attempts == 1) {
        tnx_heap_regions_refresh();


    }

    if ((t_votescan_attempts % TNX_VOTESCAN_GLOBAL_EVERY) == 1) {

        tnx_heap_regions_refresh();

    }
}

int t_setpred_state = -1;

int t_probe_done = 0;

uintptr_t t_probe_object = 0;

uint64_t t_probe_last_ms = 0;

int t_coord_ok = 0;

int t_coord_usable = 0;


int t_team_off = (int)TNX_OBJ_TEAM_OFF;



int t_map_ok = 0;




uint64_t t_last_write_ms = 0;



tnx_obj_t t_dodge_probe_list[TNX_OBJECT_MAX];

int tnx_verify_setprediction(void) {
    static const uint32_t expected[3] = { 0xb901d401u, 0xb901d802u, 0xd65f03c0u };
    uint32_t words[3] = { 0, 0, 0 };
    uintptr_t address = 0;

    if (!t_base) return 0;

    address = t_base + TNX_RVA_SETPREDICTION;

    if (!tnx_addr_readable(address, sizeof(words))) return 0;
    if (!tnx_read_bytes(address, words, sizeof(words))) return 0;

    for (int i = 0; i < 3; i++) {
        if (words[i] != expected[i]) {
            return 0;
        }
    }


    return 1;
}

void tnx_read_map(uintptr_t mode) {
    void *tileMap = NULL;
    int32_t width = 0;
    int32_t height = 0;

    t_map_ok = 0;

    if (!mode) return;

    tileMap = (void *)tnx_map_object();
    if (!tileMap) return;
    if (!tnx_read_int((uintptr_t)tileMap + TNX_MAP_WIDTH_OFF, &width)) return;
    if (!tnx_read_int((uintptr_t)tileMap + TNX_MAP_HEIGHT_OFF, &height)) return;

    t_map_ok = (width >= TNX_MAP_MIN && width <= TNX_MAP_MAX &&
                    height >= TNX_MAP_MIN && height <= TNX_MAP_MAX) ? 1 : 0;
}

int t_gidless = 0;


void tnx_gidless_scan(uintptr_t manager) {
    void *data = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int seen = 0;
    int withGid = 0;

    t_gidless = 0;

    if (!TNX_GIDLESS) return;
    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return;
    if (!tnx_read_int(manager + TNX_MGR_COUNT_OFF, &count)) return;

    for (i = 0; i < count && i < 8; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * 8ULL, &element) || !element) continue;

        seen++;

        if (tnx_gid((uintptr_t)element, NULL) != 0) withGid++;
    }

    if (seen > 0 && withGid == 0) {
        t_gidless = 1;


        return;
    }
}


uintptr_t tnx_list_gid_off(uintptr_t array, int32_t count) {
    uintptr_t off = TNX_OBJ_GLOBALID_OFF;
    int sawAt8 = 0;
    int sawAt50 = 0;
    int i = 0;
    int32_t v = 0;

    if (!array || count <= 0) return off;

    for (i = 0; i < count && i < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        if (tnx_read_int((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &v) && v != 0) sawAt8++;
        if (tnx_read_int((uintptr_t)element + TNX_GID_FALLBACK_OFF, &v) && v != 0) sawAt50++;
    }

    if (sawAt8 > 0) {
        off = TNX_OBJ_GLOBALID_OFF;
    } else if (sawAt50 > 0) {
        off = TNX_GID_FALLBACK_OFF;
    }


    return off;
}

int t_stage = 0;


int32_t t_last_x = 0;

int32_t t_last_y = 0;


int t_dead = 0;


int t_own_team_a = -1;

int t_proj_own = 0;

int t_proj_other = 0;

int t_own_team_seen = 0;





int t_team_other_seen = 0;


uintptr_t t_proj_addr = 0;

uint8_t t_proj_bytes[TNX_DIFF_BYTES];

int t_proj_have = 0;

int t_proj_dumps = 0;

uint64_t t_proj_diff_logs = 0;


void tnx_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team) {
    uint8_t now[TNX_DIFF_BYTES];
    int i;

    if (!elem) return;
    if (!tnx_read_bytes(elem, now, sizeof(now))) return;

    if (elem != t_proj_addr) {
        t_proj_addr = elem;
        memcpy(t_proj_bytes, now, sizeof(now));
        t_proj_have = 1;

        if (t_proj_dumps < TNX_DUMPS) {
            t_proj_dumps++;


            for (i = 0; i < TNX_DIFF_BYTES; i += 8) {
                uint64_t q = 0;
                int32_t lo = 0;
                int32_t hi = 0;
                float loF = 0.0f;
                float hiF = 0.0f;

                memcpy(&q, now + i, 8);
                memcpy(&lo, now + i, 4);
                memcpy(&hi, now + i + 4, 4);
                memcpy(&loF, now + i, 4);
                memcpy(&hiF, now + i + 4, 4);

            }
        }

        return;
    }

    if (!t_proj_have) {
        memcpy(t_proj_bytes, now, sizeof(now));
        t_proj_have = 1;

        return;
    }

    for (i = 0; i < TNX_DIFF_BYTES; i++) {
        if (t_proj_bytes[i] == now[i]) continue;

        t_proj_diff_logs++;

        if (t_proj_diff_logs <= TNX_DIFF_LOGS) {
            uint64_t oldQ = 0;
            uint64_t newQ = 0;
            int base = i & ~7;

            memcpy(&oldQ, t_proj_bytes + base, 8);
            memcpy(&newQ, now + base, 8);

        }
    }

    memcpy(t_proj_bytes, now, sizeof(now));
}

int tnx_mode_real(uintptr_t mode, uintptr_t *vtOut, uintptr_t *chainOut,
                             uintptr_t *innerOut) {
    void *vtable = NULL;
    void *chain = NULL;
    void *inner = NULL;
    uintptr_t rva = 0;

    if (vtOut) *vtOut = 0;
    if (chainOut) *chainOut = 0;
    if (innerOut) *innerOut = 0;

    if (!mode) return 0;
    if (!tnx_read_ptr(mode, &vtable) || !vtable) return 0;

    rva = (uintptr_t)vtable - t_base;

    if (vtOut) *vtOut = rva;
    if (rva < TNX_DC_RVA_LO || rva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &chain) || !chain) return 0;
    if (chainOut) *chainOut = (uintptr_t)chain;

    if (!t_players_object) return 0;
    if ((uintptr_t)chain == t_players_object) return 1;

    if (!tnx_read_ptr((uintptr_t)chain + TNX_CLIENT_HOP_OFF, &inner) || !inner) return 0;
    if (innerOut) *innerOut = (uintptr_t)inner;

    if ((uintptr_t)inner == t_players_object) return 1;

    return 0;
}







int t_own_logs_b = 0;

int tnx_vt_ok(uintptr_t obj, uintptr_t *vtOut) {
    void *vt = NULL;
    uintptr_t vtRva = 0;

    if (vtOut) *vtOut = 0;
    if (!obj) return 0;
    if (obj & 7) return 0;
    if (!tnx_read_ptr(obj, &vt) || !vt) return 0;
    if ((uintptr_t)vt < t_base) return 0;

    vtRva = (uintptr_t)vt - t_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (vtOut) *vtOut = (uintptr_t)vt;

    return 1;
}

int tnx_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut) {
    uintptr_t vt = 0;
    int32_t gate = 0;

    if (vtOut) *vtOut = 0;

    if (!cand) {
        if (why) *why = "null";

        return 0;
    }

    if (cand & 7) {
        if (why) *why = "unaligned";

        return 0;
    }

    if (!tnx_addr_readable(cand, TNX_MIN_OBJ_BYTES)) {
        if (why) *why = "not-readable";

        return 0;
    }

    if (!tnx_vt_ok(cand, &vt)) {
        if (why) *why = "vtable-not-in-data-const";

        return 0;
    }

    if (!tnx_read_int(cand + TNX_GATE_FLAG_OFF, &gate)) {
        if (why) *why = "gate-unreadable";

        return 0;
    }

    if (why) *why = "ok";
    if (vtOut) *vtOut = vt;

    return 1;
}

uintptr_t tnx_hop(uintptr_t base, int *whyOut) {
    void *p = NULL;
    void *q = NULL;

    if (whyOut) *whyOut = 0;
    if (!base) {
        if (whyOut) *whyOut = 1;

        return 0;
    }

    if (!tnx_read_ptr(base + TNX_CTRL_MODE_OFF, &p) || !p) {
        if (whyOut) *whyOut = 2;

        return 0;
    }

    if (!tnx_read_ptr((uintptr_t)p + TNX_OWN_INNER_OFF, &q) || !q) {
        if (whyOut) *whyOut = 3;

        return 0;
    }

    return (uintptr_t)q;
}
uintptr_t tnx_client(void) {
    void *client = NULL;

    if (!t_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)t_scene_object + TNX_CLIENT_OFF, &client)) return 0;

    return (uintptr_t)client;
}




void tnx_state_note(int state) {
    if (t_prev_state == 5 && state != 5) {
        t_own_index = -1;
        t_own_ptr = 0;
        t_own_ptr_a = 0;
        t_own_from_a = "v103-reset";

    }

    if (state == 5 && t_prev_state != 5) {

        t_dump_done = 0;
        t_coord_logs = 0;
        t_owner = 0;
        t_wired = 0;
    }

    t_prev_state = state;
}

tnx_proj_t t_projs[TNX_PROJ_MAX];

int t_side_hits = 0;

int t_side_projs = 0;


int tnx_proj_scan(uintptr_t manager, int32_t count) {
    void *array = NULL;
    int found = 0;
    int k;
    int32_t i;

    if (!manager || count <= 0) return 0;
    if (count > TNX_COUNT_MAX) count = TNX_COUNT_MAX;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        t_projs[k].classRva = (uintptr_t)-1;
    }

    t_proj_own = 0;
    t_proj_other = 0;

    for (i = 0; i < count && found < TNX_PROJ_MAX; i++) {
        void *element = NULL;
        void *vtable = NULL;
        uintptr_t vtRva = 0;
        int32_t gid = 0;
        int32_t px = 0;
        int32_t py = 0;
        int slot = -1;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable) || !vtable) continue;

        vtRva = (uintptr_t)vtable - t_base;

        gid = tnx_gid((uintptr_t)element, NULL);

        if (gid < TNX_PLAYER_GID_MAX) continue;

        {
            static uintptr_t seenCls[4] = { 0, 0, 0, 0 };
            static int seenClsN = 0;
            int si;
            int known = 0;

            for (si = 0; si < seenClsN; si++) {
                if (seenCls[si] == vtRva) {
                    known = 1;

                    break;
                }
            }

            if (!known && seenClsN < 4) {
                seenCls[seenClsN++] = vtRva;

            }
        }

        if (TNX_PROJ_CLASS_ONLY && vtRva != (uintptr_t)TNX_CLASS_PROJ_RVA) {

            continue;
        }

        if (!tnx_read_int((uintptr_t)element + TNX_OBJ_X_OFF, &px)) continue;
        if (!tnx_read_int((uintptr_t)element + TNX_OBJ_Y_OFF, &py)) continue;

        for (k = 0; k < TNX_PROJ_MAX; k++) {
            if (t_projs[k].elem != (uintptr_t)element) continue;

            slot = k;

            break;
        }

        if (slot < 0) {
            for (k = 0; k < TNX_PROJ_MAX; k++) {
                if (t_projs[k].classRva != (uintptr_t)-1) continue;

                slot = k;

                break;
            }
        }

        if (slot < 0) continue;

        if (t_projs[slot].elem == (uintptr_t)element) {
            if (px != t_projs[slot].x || py != t_projs[slot].y) {
                t_projs[slot].px = t_projs[slot].x;
                t_projs[slot].py = t_projs[slot].y;
                t_projs[slot].ptick = t_projs[slot].qtick;
                t_projs[slot].hasPrev = 1;
            }
        } else {
            t_projs[slot].elem = (uintptr_t)element;
            t_projs[slot].px = px;
            t_projs[slot].py = py;
            t_projs[slot].spawnX = px;
            t_projs[slot].spawnY = py;
            t_projs[slot].ptick = t_ticks_a;
            t_projs[slot].hasPrev = 0;
        }

        {
            uintptr_t teamOff = (t_team_off == (int)TNX_OBJ_TEAM_OFF) ? TNX_OBJ_TEAM_OFF
                                                                         : TNX_TEAM_OFF;
            int32_t pteam = -1;
            int attributed = 0;

            if (tnx_read_int((uintptr_t)element + teamOff, &pteam) && pteam >= 0 &&
                pteam <= TNX_OBJ_TEAM_MAX) {
                t_projs[slot].team = pteam;
            } else {
                int side = tnx_own_side_spawn(px, py);

                if (side == 1 && t_own_team_b >= 0) {
                    t_projs[slot].team = t_own_team_b;
                    attributed = 1;
                } else {
                    t_projs[slot].team = -1;
                }
            }

            if (t_projs[slot].team >= 0) {
                if (t_projs[slot].team == t_own_team_a) t_proj_own++;
                else t_proj_other++;
            }

        }

        t_projs[slot].classRva = vtRva;
        t_projs[slot].x = px;
        t_projs[slot].y = py;
        t_projs[slot].gid = gid;
        t_projs[slot].qtick = t_ticks_a;

        found++;
    }

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        if (t_projs[k].classRva != (uintptr_t)-1) continue;

        t_projs[k].elem = 0;
        t_projs[k].hasPrev = 0;
    }

    if (t_proj_other > 0 && !t_team_other_seen) {
        t_team_other_seen = 1;

    }

    if (t_team_other_seen) t_own_team_seen = 1;

    return found;
}

static int t_ctrl_logs = 0;


static int tnx_bounds_try(uintptr_t receiver, int32_t *wOut, int32_t *hOut) {
    uintptr_t bounds = 0;
    int32_t w = 0;
    int32_t h = 0;

    if (!receiver) return 0;
    if (!tnx_pointer_plausible(receiver)) return 0;

    {
        void *box = NULL;

        if (!tnx_read_ptr(receiver + (uintptr_t)TNX_BOX_PTR_OFF, &box)) return 0;

        bounds = (uintptr_t)box;
    }

    if (!bounds || (bounds & 7)) return 0;
    if (!tnx_addr_readable(bounds, 0x100)) return 0;
    if (!tnx_read_int(bounds + TNX_BOUNDS_X_OFF, &w)) return 0;
    if (!tnx_read_int(bounds + TNX_BOUNDS_Y_OFF, &h)) return 0;
    if (w <= 3 || h <= 3 || w > 200000 || h > 200000) return 0;

    if (wOut) *wOut = w;
    if (hOut) *hOut = h;

    return 1;
}

int tnx_ctrl_bounds(uintptr_t base, int32_t *wOut, int32_t *hOut) {
    if (!base) return 0;
    if (!tnx_pointer_plausible(base)) return 0;

    return tnx_bounds_try(base, wOut, hOut);
}

uintptr_t tnx_controller(void) {
    uintptr_t client = tnx_client();
    int32_t cw = 0;
    int32_t ch = 0;

    if (client && tnx_ctrl_bounds(client, &cw, &ch)) {

        return client;
    }


    if (!t_ctrl_logs) {
        t_ctrl_logs = 1;

    }

    return client;
}

void tnx_watch(int32_t ownX, int32_t ownY) {
    if (ownX == t_last_x && ownY == t_last_y) {

        return;
    }

    t_last_x = ownX;
    t_last_y = ownY;
}


int t_signal_logs = 0;

void tnx_death_signals(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    static int lastDead = -999;
    static int lastOwnAlive = -999;
    static int lastCtrlAlive = -999;
    uintptr_t ctrl = 0;
    uint8_t deadByte = 0;
    int dead = -1;
    int ownAlive = -1;
    int ctrlAlive = -1;

    if (!ownElem) return;

    if (tnx_read_bytes(ownElem + TNX_DEAD_OFF, &deadByte, sizeof(deadByte))) dead = (int)deadByte;

    if (!tnx_read_int(ownElem + TNX_OWN_ALIVE_OFF, &ownAlive)) ownAlive = -1;

    ctrl = tnx_controller();

    if (ctrl && !tnx_read_int(ctrl + TNX_CTRL_ALIVE_OFF, &ctrlAlive)) ctrlAlive = -1;

    if (dead == lastDead && ownAlive == lastOwnAlive && ctrlAlive == lastCtrlAlive) return;

    lastDead = dead;
    lastOwnAlive = ownAlive;
    lastCtrlAlive = ctrlAlive;

    if (t_signal_logs >= 12) return;

    t_signal_logs++;

}

void tnx_alive(int32_t ownX, int32_t ownY) {
    if (!t_dead) return;

    t_dead = 0;

}


int32_t t_prev_x_3 = 0;

int32_t t_prev_y_3 = 0;

int t_prev_ok = 0;


float tnx_step(void) {

    return TNX_STEP_b;
}

void tnx_measure(void) {
    int32_t x = 0;
    int32_t y = 0;
    float d = 0.0f;

    if (!tnx_own(&x, &y)) return;

    if (t_prev_ok && !t_hold) {
        float ddx = (float)(x - t_prev_x_3);
        float ddy = (float)(y - t_prev_y_3);

        d = sqrtf(ddx * ddx + ddy * ddy);

        if (d > 0.5f) {
            float inv = 1.0f / d;

            t_last_x_b = ddx * inv;
            t_last_y_b = ddy * inv;
            t_last_ok = 1;
        }

        if (d > 0.5f && d < TNX_WALK_MAX * 3.0f) {
            t_walk_step = t_walk_step * (1.0f - TNX_WALK_EMA) + d * TNX_WALK_EMA;

            if (t_walk_step < TNX_WALK_MIN) t_walk_step = TNX_WALK_MIN;
            if (t_walk_step > TNX_WALK_MAX) t_walk_step = TNX_WALK_MAX;
        }
    }

    t_prev_x_3 = x;
    t_prev_y_3 = y;
    t_prev_ok = 1;
}




int tnx_proj_mine(const tnx_proj_t *p) {
    int i = 0;
    int bestMine = 0;
    float best = 1.0e18f;
    float sx = 0.0f;
    float sy = 0.0f;

    if (!TNX_PROJ_OWNER) return 0;
    if (!t_team_trust) return 0;
    if (t_pl_n <= 0) return 0;
    if (t_own_team_b >= 0 && p->team == t_own_team_b) return 1;
    if (!p->spawnX && !p->spawnY) return 0;

    sx = (float)p->spawnX;
    sy = (float)p->spawnY;

    for (i = 0; i < t_pl_n; i++) {
        float dx = sx - (float)t_pl_x[i];
        float dy = sy - (float)t_pl_y[i];
        float d = dx * dx + dy * dy;

        if (d < best) {
            best = d;
            bestMine = t_pl_mine[i];
        }
    }

    if (best > TNX_SPAWN_R * TNX_SPAWN_R) return 0;


    return bestMine;
}

void tnx_state(void) {
    t_census_container = 0;
    t_census_array = 0;
    t_census_first = 0;
    t_census_ms = 0;


    {
        uint16_t charState = 0;
        uint16_t sceneState = 0;
        int32_t charMode = 0;

        if (t_own_elem_2) {
            tnx_read_bytes(t_own_elem_2 + TNX_JOYSTATE_OFF, &charState, sizeof(charState));
            tnx_read_int(t_own_elem_2 + TNX_BS_MODE, &charMode);
        }

        if (t_scene_object) {
            tnx_read_bytes((uintptr_t)t_scene_object + TNX_JOYSTATE_OFF, &sceneState,
                           sizeof(sceneState));
        }

        uint8_t gate70 = 0;

        if (t_pred_last) {
            tnx_read_bytes(t_pred_last + TNX_GATE_OFF, &gate70, sizeof(gate70));
        }

        uint16_t enState[2] = { 0, 0 };
        int32_t enMode[2] = { 0, 0 };
        int seen = 0;
        int k = 0;

        for (k = 0; k < t_dodge_probe_usable && seen < 2; k++) {
            const tnx_obj_t *o = &t_dodge_probe_list[k];
            uint16_t st = 0;
            int32_t md = 0;

            if (!o->object) continue;
            if (o->gid < TNX_PLAYER_GID) continue;
            if (o->gid >= TNX_SHOT_GID) continue;
            if (t_own_elem_2 && o->object == t_own_elem_2) continue;
            if (!tnx_read_bytes((uintptr_t)o->object + TNX_JOYSTATE_OFF, &st, sizeof(st))) continue;

            tnx_read_int((uintptr_t)o->object + TNX_BS_MODE, &md);
            enState[seen] = st;
            enMode[seen] = md;
            seen++;
        }

    }

    {
        uintptr_t st = 0;

        if (tnx_read_ptr(tnx_client() + TNX_MGR_OFF, (void **)&st) && st) {
            int32_t stx = 0;
            int32_t sty = 0;
            int32_t stk = 0;
            int32_t sta = 0;
            uintptr_t stv = 0;

            tnx_read_int(st + TNX_MOVE_X_OFF, &stx);
            tnx_read_int(st + TNX_MOVE_Y_OFF, &sty);
            tnx_read_int(st + TNX_MOVE_KEY_OFF, &stk);
            tnx_read_int(st + TNX_MOVE_ARM_OFF, &sta);
            if (tnx_read_ptr(st, (void **)&stv) && stv >= t_base) stv -= t_base;


        }
    }


}

uint64_t tnx_word_2(uintptr_t address) {
    uint64_t value = 0;

    if (!tnx_read_bytes(address, &value, sizeof(value))) return 0;

    return value;
}

const char *tnx_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (!manager) return "no-manager";
    if (manager & 7ULL) return "manager-unaligned";
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return "array-unreadable";
    if (!array) return "array-null";
    if (!tnx_read_int(manager + TNX_MGR_COUNT_OFF, &count)) return "count-unreadable";
    if (count <= 0) return "count-zero";
    if (!tnx_read_int(manager + TNX_MGR_CAP_OFF, &capacity)) return "cap-unreadable";
    if (count > capacity) return "count-above-cap";
    if (capacity > TNX_MGR_CAP_MAX) return "cap-above-ceiling";
    if (count > TNX_MANAGER_MAX_OBJECTS) return "count-above-ceiling";

    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return NULL;
}

uintptr_t tnx_coord_x_off(void) {
    return TNX_OBJ_X_OFF;
}

uintptr_t tnx_coord_y_off(void) {
    return TNX_OBJ_Y_OFF;
}

int32_t t_gid_lo = 0;

int32_t t_gid_hi = 0;

const uintptr_t t_mode_vtables[36] = {
    0x10012c8, 0x1001318, 0x1001368, 0x10013b8,
    0x1001408, 0x1001458, 0x10014a8, 0x10014f8, 0x1001548, 0x1001598, 0x10015e8, 0x10016e0,
    0x10017d8, 0x10018c0, 0x1001908, 0x10019d0, 0x1001ac8, 0x1001bc0, 0x1001cb8, 0x1001d80,
    0x1001e48, 0x1001f10, 0x10022f0, 0x10023b8, 0x1002480, 0x1002548, 0x1002610,
    0x10026d8, 0x10027a0, 0x1002868, 0x1002930, 0x10029f8, 0x1002ac0, 0x1002b88, 0x1002d18,
    0,
};

tnx_trail_t t_trail[TNX_TRAIL_MAX];

void tnx_probe(uintptr_t manager, uintptr_t mode, int verbose) {
    tnx_obj_t objects[TNX_OBJECT_MAX];
    int rejected = 0;
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int teamsNew[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int distinctOld = 0;
    int distinctNew = 0;

    memset(objects, 0, sizeof(objects));

    t_probe_done = 1;

    if (mode) tnx_read_map(mode);

    {
        static int v142_walk_logs = 0;

    }

    usable = tnx_collect(manager, objects, TNX_OBJECT_MAX, &rejected);

    {
        static int v142_leave_logs = 0;

    }

    for (int i = 0; i < usable; i++) {
        if (objects[i].x > -TNX_COORD_ABS_MAX && objects[i].x < TNX_COORD_ABS_MAX &&
            objects[i].y > -TNX_COORD_ABS_MAX && objects[i].y < TNX_COORD_ABS_MAX) {
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

    t_team_off = (int)TNX_OBJ_TEAM_OFF;

    {
        char reasons[320];

    }



    if (!TNX_DEAD_ONCE || !t_dead_probe_done) {
        t_dead_probe_done = 1;
    }

    if (verbose) {

        for (int i = 0; i < usable && i < 16; i++) {
        }
    }

    t_coord_usable = usable;

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

    }


    t_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;


    {
        int back = 0;
        int backRead = 0;

        for (int i = 0; i < usable; i++) {
            void *backPtr = NULL;

            if (!tnx_read_ptr(objects[i].object + TNX_ELEM_BACK_OFF, &backPtr)) continue;

            backRead++;

            if ((uintptr_t)backPtr == manager) back++;
        }

    }
}

void tnx_paircal(void) {
    uintptr_t ctrl = tnx_pair_base();
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

    if ((t_ticks_a % 60) != 0) return;
    if (t_logs_a >= TNX_LOGS_a) return;
    if (t_stick_hold) return;
    if (!ctrl) return;
    if (!tnx_own(&ownX, &ownY)) return;
    if (!tnx_read_int(ctrl + TNX_CTRL_RAW_X_OFF, &px)) return;
    if (!tnx_read_int(ctrl + TNX_CTRL_RAW_Y_OFF, &py)) return;

    if (t_seeded) {
        dx = (int)(ownX - t_last_x_a);
        dy = (int)(ownY - t_last_y_a);
    }

    t_seeded = 1;
    t_last_x_a = ownX;
    t_last_y_a = ownY;

    pLen = sqrtf((float)(px * px + py * py));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (pLen < 1.0f || mLen < 1.0f) return;

    t_logs_a++;

    dot = ((float)px / pLen) * ((float)dx / mLen) + ((float)py / pLen) * ((float)dy / mLen);
    angPair = atan2f((float)py, (float)px) * 57.2958f;
    angMove = atan2f((float)dy, (float)dx) * 57.2958f;

}

uintptr_t t_scene_object = 0;
