#include "../recoil.h"















int rcl_prev_state = -1;



















int rcl_hop_chosen = -1;

int rcl_hop_sticky = 0;


int rcl_modesig_hits = 0;


int rcl_floor_logged = 0;

int rcl_fallback_logged = 0;














uintptr_t rcl_scan_container = 0;


int rcl_own_logged = 0;





uint64_t rcl_wrote_tick = 0;

int rcl_wrote_valid = 0;

int rcl_check_done = 0;









uint64_t rcl_pred_took = 0;

uint64_t rcl_pred_miss = 0;


int rcl_modesig_hit(uintptr_t at) {
    void *vt = NULL;
    void *mgr = NULL;
    int32_t ec = 0;
    int32_t m124 = 0;
    int32_t count = 0;

    if (!at) return 0;
    if (!rcl_read_ptr(at, &vt) || !vt) return 0;
    if (!rcl_vtable_in_image((uintptr_t)vt)) return 0;
    if (!rcl_vtable_is_data((uintptr_t)vt)) {

        return 0;
    }
    if (!rcl_read_int(at + 0x124ULL, &m124) || m124 < 0x01 || m124 > 0x80) return 0;
    if (!rcl_read_int(at + 0xecULL, &ec) || ec < -1024 || ec > 1024) return 0;
    if (!rcl_read_ptr(at + RCL_MODE_MANAGER_OFF, &mgr) || !mgr) return 0;
    if (!rcl_pointer_plausible((uintptr_t)mgr)) return 0;
    if (!rcl_read_int((uintptr_t)mgr + RCL_MGR_COUNT_OFF, &count)) return 0;
    if (count < 2 || count > RCL_MANAGER_MAX_OBJECTS) return 0;

    return 1;
}

void rcl_modesig_tick(void) {
    uintptr_t found = 0;

    if (rcl_scene_object) return;
    if (!rcl_battle_active && (rcl_ticks_b % RCL_BUCKET_TICKS_2) != 0) return;

    for (int i = 0; i < rcl_objhit_count && !found; i++) {
        if (rcl_modesig_hit(rcl_objhits[i].at)) found = rcl_objhits[i].at;
    }

    if (!found) return;

    if (rcl_sig_last == found) {
        rcl_sig_ticks++;
    } else {
        rcl_sig_last = found;
        rcl_sig_ticks = 1;

    }

    if (rcl_sig_ticks < RCL_MODESIG_TICKS) return;

    {
        void *vt = NULL;
        void *mgr = NULL;
        int32_t ec = 0;
        int32_t m124 = 0;
        int32_t count = 0;
        int32_t cap = 0;

        rcl_modesig_hits++;
        rcl_scene_object = found;
        rcl_battle_last_tick = (int)rcl_ticks_b;

        rcl_read_ptr(found, &vt);
        rcl_read_ptr(found + RCL_MODE_MANAGER_OFF, &mgr);
        rcl_read_int(found + 0xecULL, &ec);
        rcl_read_int(found + 0x124ULL, &m124);
        rcl_read_int((uintptr_t)mgr + RCL_MGR_COUNT_OFF, &count);
        rcl_read_int((uintptr_t)mgr + RCL_MGR_CAP_OFF, &cap);


        if (count >= 2 && cap >= count && cap <= RCL_MGR_CAP_MAX) {
            void *mgrArray = NULL;

            rcl_manager_count = count;

            if (rcl_read_ptr((uintptr_t)mgr + RCL_MGR_ARRAY_OFF, &mgrArray) && mgrArray) {
                rcl_publish((uintptr_t)mgr, (uintptr_t)mgrArray, count, cap, "modesig");
            }

        }
    }
}

int rcl_element_type(uintptr_t vt, uintptr_t *wordOut) {
    void *slotPtr = NULL;
    uintptr_t slot = 0;

    if (wordOut) *wordOut = 0;

    if (!vt) return -1;
    if (!rcl_read_ptr(vt + RCL_TYPE_SLOT_OFF, &slotPtr) || !slotPtr) return -1;

    slot = rcl_strip_ptr((uintptr_t)slotPtr) - rcl_base;

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



uintptr_t rcl_hop_scene = 0;

int rcl_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut,
                                    int32_t *capOut) {
    void *array = NULL;

    if (arrayOut) *arrayOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;

    if (!object) return 0;
    if (rcl_header_reason(object, countOut, capOut)) return 0;
    if (!rcl_read_ptr(object + RCL_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!rcl_heap_resident((uintptr_t)array)) return 0;

    if (arrayOut) *arrayOut = (uintptr_t)array;

    return 1;
}


int rcl_coord_logs = 0;


int32_t rcl_gid_at(uintptr_t element, uintptr_t off) {
    int32_t gid = 0;

    if (off && rcl_read_int(element + off, &gid)) return gid;

    return 0;
}

int32_t rcl_gid(uintptr_t element, int32_t *offOut) {
    int32_t gid = 0;
    int32_t alt = 0;

    if (offOut) *offOut = 0;
    if (!element) return 0;

    if (rcl_read_int(element + RCL_OBJ_GLOBALID_OFF, &gid) && gid) {
        if (offOut) *offOut = (int32_t)RCL_OBJ_GLOBALID_OFF;

        return gid;
    }

    if (rcl_read_int(element + RCL_GID_FALLBACK_OFF, &alt) && alt) {
        if (offOut) *offOut = (int32_t)RCL_GID_FALLBACK_OFF;

        return alt;
    }

    return 0;
}


int rcl_last_choice = -2;

int rcl_hop_logs = 0;


int rcl_container_score(uintptr_t container) {
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
    if (!rcl_read_ptr(container + RCL_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!rcl_read_int(container + RCL_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > RCL_COUNT_MAX) return -1;

    if (own < 0 || own >= count) soft = 1;

    for (i = 0; i < count && samples < 4; i++) {
        void *element = NULL;

        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        samples++;
        team = 0;
        px = 0;
        py = 0;

        if (rcl_element_ascii((uintptr_t)element)) asciiCount++;

        gid = rcl_gid((uintptr_t)element, NULL);
        rcl_read_int((uintptr_t)element + RCL_TEAM_OFF, &team);

        if (rcl_read_int((uintptr_t)element + RCL_OBJ_X_OFF, &px) &&
            rcl_read_int((uintptr_t)element + RCL_OBJ_Y_OFF, &py) &&
            px > -RCL_COORD_MAX && px < RCL_COORD_MAX &&
            py > -RCL_COORD_MAX && py < RCL_COORD_MAX && (px != 0 || py != 0)) {
            int dup = 0;

            posOk++;

            for (j = 0; j < i; j++) {
                void *other = NULL;

                if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)j * 8ULL, &other) || !other) continue;
                if (!rcl_read_int((uintptr_t)other + RCL_OBJ_X_OFF, &qx)) continue;
                if (!rcl_read_int((uintptr_t)other + RCL_OBJ_Y_OFF, &qy)) continue;

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

    if (samples > 0 && (asciiCount * 100) / samples > RCL_ASCII_RATIO) {

        return -1;
    }

    if (soft) {
        if (posOk < RCL_SOFT_MIN_POS || posDistinct < RCL_SOFT_MIN_DIST) {

            return -1;
        }

        score = RCL_SOFT_BASE;
    } else {
        score = 6;

        if (ownTeam >= 0 && ownTeam <= 15) score += 2;
    }

    if (gidOk) score += 1;
    if (teamOk) score += 1;
    if (count >= 3) score += 2;
    if (count >= 6) score += 1;

    score += posOk * RCL_POS_BONUS + posDistinct * RCL_DIST_BONUS;


    return score;
}
int rcl_scan_ready(int battle) {
    if (rcl_ticks_b < RCL_SCAN_FLOOR_TICKS) {
        if (!rcl_floor_logged) {
            rcl_floor_logged = 1;

        }

        return 0;
    }

    if (battle || rcl_scene_object) return 1;

    if (rcl_ticks_b < RCL_SCAN_FALLBACK_TICKS) return 0;

    if (!rcl_fallback_logged) {
        rcl_fallback_logged = 1;

    }

    return (rcl_ticks_b % RCL_BUCKET_TICKS_2) == 0;
}

void rcl_resolve_addresses(void) {
    if (!rcl_base) return;

    rcl_addr_getinstance = rcl_callable(RVA_BATTLEMODE_GETINSTANCE);
    rcl_addr_getownchar = rcl_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    rcl_addr_getteam = rcl_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    rcl_addr_getx = rcl_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    rcl_addr_gety = rcl_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);

    rcl_addr_setprediction = rcl_callable(RCL_RVA_SETPREDICTION);

    rcl_addr_battlescreen = rcl_base + RVA_BATTLESCREEN__BATTLESCREEN;
    if (!rcl_addr_readable(rcl_addr_battlescreen, sizeof(void *))) rcl_addr_battlescreen = 0;

}
void rcl_locate_battle_mode(void) {
    if (rcl_mode_strong) return;

    if (rcl_votescan_attempts >= RCL_VOTESCAN_ATTEMPTS) {


        return;
    }

    double now = CFAbsoluteTimeGetCurrent();

    if (rcl_votescan_last > 0.0 && (now - rcl_votescan_last) < RCL_VOTESCAN_INTERVAL) return;

    rcl_votescan_last = now;
    rcl_votescan_attempts++;

    if (rcl_votescan_attempts == 1) {
        rcl_heap_regions_refresh();


    }

    if ((rcl_votescan_attempts % RCL_VOTESCAN_GLOBAL_EVERY) == 1) {

        rcl_heap_regions_refresh();

    }
}

int rcl_setpred_state = -1;

int rcl_probe_done = 0;

uintptr_t rcl_probe_object = 0;

uint64_t rcl_probe_last_ms = 0;

int rcl_coord_ok = 0;

int rcl_coord_usable = 0;


int rcl_team_off = (int)RCL_OBJ_TEAM_OFF;



int rcl_map_ok = 0;




uint64_t rcl_last_write_ms = 0;



rcl_obj_t rcl_dodge_probe_list[RCL_OBJECT_MAX];

int rcl_verify_setprediction(void) {
    static const uint32_t expected[3] = { 0xb901d401u, 0xb901d802u, 0xd65f03c0u };
    uint32_t words[3] = { 0, 0, 0 };
    uintptr_t address = 0;

    if (!rcl_base) return 0;

    address = rcl_base + RCL_RVA_SETPREDICTION;

    if (!rcl_addr_readable(address, sizeof(words))) return 0;
    if (!rcl_read_bytes(address, words, sizeof(words))) return 0;

    for (int i = 0; i < 3; i++) {
        if (words[i] != expected[i]) {
            return 0;
        }
    }


    return 1;
}

void rcl_read_map(uintptr_t mode) {
    void *tileMap = NULL;
    int32_t width = 0;
    int32_t height = 0;

    rcl_map_ok = 0;

    if (!mode) return;

    tileMap = (void *)rcl_map_object();
    if (!tileMap) return;
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_WIDTH_OFF, &width)) return;
    if (!rcl_read_int((uintptr_t)tileMap + RCL_MAP_HEIGHT_OFF, &height)) return;

    rcl_map_ok = (width >= RCL_MAP_MIN && width <= RCL_MAP_MAX &&
                    height >= RCL_MAP_MIN && height <= RCL_MAP_MAX) ? 1 : 0;
}

int rcl_gidless = 0;


void rcl_gidless_scan(uintptr_t manager) {
    void *data = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int seen = 0;
    int withGid = 0;

    rcl_gidless = 0;

    if (!RCL_GIDLESS) return;
    if (!manager) return;
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &data) || !data) return;
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count)) return;

    for (i = 0; i < count && i < 8; i++) {
        void *element = NULL;

        if (!rcl_read_ptr((uintptr_t)data + (uintptr_t)i * 8ULL, &element) || !element) continue;

        seen++;

        if (rcl_gid((uintptr_t)element, NULL) != 0) withGid++;
    }

    if (seen > 0 && withGid == 0) {
        rcl_gidless = 1;


        return;
    }
}


uintptr_t rcl_list_gid_off(uintptr_t array, int32_t count) {
    uintptr_t off = RCL_OBJ_GLOBALID_OFF;
    int sawAt8 = 0;
    int sawAt50 = 0;
    int i = 0;
    int32_t v = 0;

    if (!array || count <= 0) return off;

    for (i = 0; i < count && i < 4; i++) {
        void *element = NULL;

        if (!rcl_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        if (rcl_read_int((uintptr_t)element + RCL_OBJ_GLOBALID_OFF, &v) && v != 0) sawAt8++;
        if (rcl_read_int((uintptr_t)element + RCL_GID_FALLBACK_OFF, &v) && v != 0) sawAt50++;
    }

    if (sawAt8 > 0) {
        off = RCL_OBJ_GLOBALID_OFF;
    } else if (sawAt50 > 0) {
        off = RCL_GID_FALLBACK_OFF;
    }


    return off;
}

int rcl_stage = 0;


int32_t rcl_last_x = 0;

int32_t rcl_last_y = 0;


int rcl_dead = 0;


int rcl_own_team_a = -1;

int rcl_proj_own = 0;

int rcl_proj_other = 0;

int rcl_own_team_seen = 0;





int rcl_team_other_seen = 0;


uintptr_t rcl_proj_addr = 0;

uint8_t rcl_proj_bytes[RCL_DIFF_BYTES];

int rcl_proj_have = 0;

int rcl_proj_dumps = 0;

uint64_t rcl_proj_diff_logs = 0;


void rcl_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team) {
    uint8_t now[RCL_DIFF_BYTES];
    int i;

    if (!elem) return;
    if (!rcl_read_bytes(elem, now, sizeof(now))) return;

    if (elem != rcl_proj_addr) {
        rcl_proj_addr = elem;
        memcpy(rcl_proj_bytes, now, sizeof(now));
        rcl_proj_have = 1;

        if (rcl_proj_dumps < RCL_DUMPS) {
            rcl_proj_dumps++;


            for (i = 0; i < RCL_DIFF_BYTES; i += 8) {
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

    if (!rcl_proj_have) {
        memcpy(rcl_proj_bytes, now, sizeof(now));
        rcl_proj_have = 1;

        return;
    }

    for (i = 0; i < RCL_DIFF_BYTES; i++) {
        if (rcl_proj_bytes[i] == now[i]) continue;

        rcl_proj_diff_logs++;

        if (rcl_proj_diff_logs <= RCL_DIFF_LOGS) {
            uint64_t oldQ = 0;
            uint64_t newQ = 0;
            int base = i & ~7;

            memcpy(&oldQ, rcl_proj_bytes + base, 8);
            memcpy(&newQ, now + base, 8);

        }
    }

    memcpy(rcl_proj_bytes, now, sizeof(now));
}

int rcl_mode_real(uintptr_t mode, uintptr_t *vtOut, uintptr_t *chainOut,
                             uintptr_t *innerOut) {
    void *vtable = NULL;
    void *chain = NULL;
    void *inner = NULL;
    uintptr_t rva = 0;

    if (vtOut) *vtOut = 0;
    if (chainOut) *chainOut = 0;
    if (innerOut) *innerOut = 0;

    if (!mode) return 0;
    if (!rcl_read_ptr(mode, &vtable) || !vtable) return 0;

    rva = (uintptr_t)vtable - rcl_base;

    if (vtOut) *vtOut = rva;
    if (rva < RCL_DC_RVA_LO || rva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE) return 0;

    if (!rcl_read_ptr(mode + RCL_MODE_MANAGER_OFF, &chain) || !chain) return 0;
    if (chainOut) *chainOut = (uintptr_t)chain;

    if (!rcl_players_object) return 0;
    if ((uintptr_t)chain == rcl_players_object) return 1;

    if (!rcl_read_ptr((uintptr_t)chain + RCL_CLIENT_HOP_OFF, &inner) || !inner) return 0;
    if (innerOut) *innerOut = (uintptr_t)inner;

    if ((uintptr_t)inner == rcl_players_object) return 1;

    return 0;
}







int rcl_own_logs_b = 0;

int rcl_vt_ok(uintptr_t obj, uintptr_t *vtOut) {
    void *vt = NULL;
    uintptr_t vtRva = 0;

    if (vtOut) *vtOut = 0;
    if (!obj) return 0;
    if (obj & 7) return 0;
    if (!rcl_read_ptr(obj, &vt) || !vt) return 0;
    if ((uintptr_t)vt < rcl_base) return 0;

    vtRva = (uintptr_t)vt - rcl_base;

    if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE) return 0;

    if (vtOut) *vtOut = (uintptr_t)vt;

    return 1;
}

int rcl_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut) {
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

    if (!rcl_addr_readable(cand, RCL_MIN_OBJ_BYTES)) {
        if (why) *why = "not-readable";

        return 0;
    }

    if (!rcl_vt_ok(cand, &vt)) {
        if (why) *why = "vtable-not-in-data-const";

        return 0;
    }

    if (!rcl_read_int(cand + RCL_GATE_FLAG_OFF, &gate)) {
        if (why) *why = "gate-unreadable";

        return 0;
    }

    if (why) *why = "ok";
    if (vtOut) *vtOut = vt;

    return 1;
}

uintptr_t rcl_hop(uintptr_t base, int *whyOut) {
    void *p = NULL;
    void *q = NULL;

    if (whyOut) *whyOut = 0;
    if (!base) {
        if (whyOut) *whyOut = 1;

        return 0;
    }

    if (!rcl_read_ptr(base + RCL_CTRL_MODE_OFF, &p) || !p) {
        if (whyOut) *whyOut = 2;

        return 0;
    }

    if (!rcl_read_ptr((uintptr_t)p + RCL_OWN_INNER_OFF, &q) || !q) {
        if (whyOut) *whyOut = 3;

        return 0;
    }

    return (uintptr_t)q;
}
uintptr_t rcl_client(void) {
    void *client = NULL;

    if (!rcl_scene_object) return 0;
    if (!rcl_read_ptr((uintptr_t)rcl_scene_object + RCL_CLIENT_OFF, &client)) return 0;

    return (uintptr_t)client;
}




void rcl_state_note(int state) {
    if (rcl_prev_state == 5 && state != 5) {
        rcl_own_index = -1;
        rcl_own_ptr = 0;
        rcl_own_ptr_a = 0;
        rcl_own_from_a = "v103-reset";

    }

    if (state == 5 && rcl_prev_state != 5) {

        rcl_coord_logs = 0;
        rcl_owner = 0;
        rcl_wired = 0;
    }

    rcl_prev_state = state;
}

rcl_proj_t rcl_projs[RCL_PROJ_MAX];

int rcl_side_hits = 0;

int rcl_side_projs = 0;


int rcl_proj_scan(uintptr_t manager, int32_t count) {
    void *array = NULL;
    int found = 0;
    int k;
    int32_t i;

    if (!manager || count <= 0) return 0;
    if (count > RCL_COUNT_MAX) count = RCL_COUNT_MAX;
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array) || !array) return 0;

    for (k = 0; k < RCL_PROJ_MAX; k++) {
        rcl_projs[k].classRva = (uintptr_t)-1;
    }

    rcl_proj_own = 0;
    rcl_proj_other = 0;

    for (i = 0; i < count && found < RCL_PROJ_MAX; i++) {
        void *element = NULL;
        void *vtable = NULL;
        uintptr_t vtRva = 0;
        int32_t gid = 0;
        int32_t px = 0;
        int32_t py = 0;
        int slot = -1;

        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!rcl_read_ptr((uintptr_t)element, &vtable) || !vtable) continue;

        vtRva = (uintptr_t)vtable - rcl_base;

        gid = rcl_gid((uintptr_t)element, NULL);

        if (gid < RCL_PLAYER_GID_MAX) continue;

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

        if (RCL_PROJ_CLASS_ONLY && vtRva != (uintptr_t)RCL_CLASS_PROJ_RVA) {

            continue;
        }

        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_X_OFF, &px)) continue;
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_Y_OFF, &py)) continue;

        for (k = 0; k < RCL_PROJ_MAX; k++) {
            if (rcl_projs[k].elem != (uintptr_t)element) continue;

            slot = k;

            break;
        }

        if (slot < 0) {
            for (k = 0; k < RCL_PROJ_MAX; k++) {
                if (rcl_projs[k].classRva != (uintptr_t)-1) continue;

                slot = k;

                break;
            }
        }

        if (slot < 0) continue;

        if (rcl_projs[slot].elem == (uintptr_t)element) {
            if (px != rcl_projs[slot].x || py != rcl_projs[slot].y) {
                rcl_projs[slot].px = rcl_projs[slot].x;
                rcl_projs[slot].py = rcl_projs[slot].y;
                rcl_projs[slot].ptick = rcl_projs[slot].qtick;
                rcl_projs[slot].hasPrev = 1;
            }
        } else {
            rcl_projs[slot].elem = (uintptr_t)element;
            rcl_projs[slot].px = px;
            rcl_projs[slot].py = py;
            rcl_projs[slot].spawnX = px;
            rcl_projs[slot].spawnY = py;
            rcl_projs[slot].ptick = rcl_ticks_a;
            rcl_projs[slot].hasPrev = 0;
        }

        {
            uintptr_t teamOff = (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? RCL_OBJ_TEAM_OFF
                                                                         : RCL_TEAM_OFF;
            int32_t pteam = -1;
            int attributed = 0;

            if (rcl_read_int((uintptr_t)element + teamOff, &pteam) && pteam >= 0 &&
                pteam <= RCL_OBJ_TEAM_MAX) {
                rcl_projs[slot].team = pteam;
            } else {
                int side = rcl_own_side_spawn(px, py);

                if (side == 1 && rcl_own_team_b >= 0) {
                    rcl_projs[slot].team = rcl_own_team_b;
                    attributed = 1;
                } else {
                    rcl_projs[slot].team = -1;
                }
            }

            if (rcl_projs[slot].team >= 0) {
                if (rcl_projs[slot].team == rcl_own_team_a) rcl_proj_own++;
                else rcl_proj_other++;
            }

        }

        rcl_projs[slot].classRva = vtRva;
        rcl_projs[slot].x = px;
        rcl_projs[slot].y = py;
        rcl_projs[slot].gid = gid;
        rcl_projs[slot].qtick = rcl_ticks_a;

        found++;
    }

    for (k = 0; k < RCL_PROJ_MAX; k++) {
        if (rcl_projs[k].classRva != (uintptr_t)-1) continue;

        rcl_projs[k].elem = 0;
        rcl_projs[k].hasPrev = 0;
    }

    if (rcl_proj_other > 0 && !rcl_team_other_seen) {
        rcl_team_other_seen = 1;

    }

    if (rcl_team_other_seen) rcl_own_team_seen = 1;

    return found;
}

static int rcl_ctrl_logs = 0;


static int rcl_bounds_try(uintptr_t receiver, int32_t *wOut, int32_t *hOut) {
    uintptr_t bounds = 0;
    int32_t w = 0;
    int32_t h = 0;

    if (!receiver) return 0;
    if (!rcl_pointer_plausible(receiver)) return 0;

    {
        void *box = NULL;

        if (!rcl_read_ptr(receiver + (uintptr_t)RCL_BOX_PTR_OFF, &box)) return 0;

        bounds = (uintptr_t)box;
    }

    if (!bounds || (bounds & 7)) return 0;
    if (!rcl_addr_readable(bounds, 0x100)) return 0;
    if (!rcl_read_int(bounds + RCL_BOUNDS_X_OFF, &w)) return 0;
    if (!rcl_read_int(bounds + RCL_BOUNDS_Y_OFF, &h)) return 0;
    if (w <= 3 || h <= 3 || w > 200000 || h > 200000) return 0;

    if (wOut) *wOut = w;
    if (hOut) *hOut = h;

    return 1;
}

int rcl_ctrl_bounds(uintptr_t base, int32_t *wOut, int32_t *hOut) {
    if (!base) return 0;
    if (!rcl_pointer_plausible(base)) return 0;

    return rcl_bounds_try(base, wOut, hOut);
}

uintptr_t rcl_controller(void) {
    uintptr_t client = rcl_client();
    int32_t cw = 0;
    int32_t ch = 0;

    if (client && rcl_ctrl_bounds(client, &cw, &ch)) {

        return client;
    }


    if (!rcl_ctrl_logs) {
        rcl_ctrl_logs = 1;

    }

    return client;
}

void rcl_watch(int32_t ownX, int32_t ownY) {
    if (ownX == rcl_last_x && ownY == rcl_last_y) {

        return;
    }

    rcl_last_x = ownX;
    rcl_last_y = ownY;
}


int rcl_signal_logs = 0;

void rcl_death_signals(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    static int lastDead = -999;
    static int lastOwnAlive = -999;
    static int lastCtrlAlive = -999;
    uintptr_t ctrl = 0;
    uint8_t deadByte = 0;
    int dead = -1;
    int ownAlive = -1;
    int ctrlAlive = -1;

    if (!ownElem) return;

    if (rcl_read_bytes(ownElem + RCL_DEAD_OFF, &deadByte, sizeof(deadByte))) dead = (int)deadByte;

    if (!rcl_read_int(ownElem + RCL_OWN_ALIVE_OFF, &ownAlive)) ownAlive = -1;

    ctrl = rcl_controller();

    if (ctrl && !rcl_read_int(ctrl + RCL_CTRL_ALIVE_OFF, &ctrlAlive)) ctrlAlive = -1;

    if (dead == lastDead && ownAlive == lastOwnAlive && ctrlAlive == lastCtrlAlive) return;

    lastDead = dead;
    lastOwnAlive = ownAlive;
    lastCtrlAlive = ctrlAlive;

    if (rcl_signal_logs >= 12) return;

    rcl_signal_logs++;

}

void rcl_alive(int32_t ownX, int32_t ownY) {
    if (!rcl_dead) return;

    rcl_dead = 0;

}


int32_t rcl_prev_x_3 = 0;

int32_t rcl_prev_y_3 = 0;

int rcl_prev_ok = 0;


float rcl_step(void) {

    return RCL_STEP_b;
}

void rcl_measure(void) {
    int32_t x = 0;
    int32_t y = 0;
    float d = 0.0f;

    if (!rcl_own(&x, &y)) return;

    if (rcl_prev_ok && !rcl_hold) {
        float ddx = (float)(x - rcl_prev_x_3);
        float ddy = (float)(y - rcl_prev_y_3);

        d = sqrtf(ddx * ddx + ddy * ddy);

        if (d > 0.5f) {
            float inv = 1.0f / d;

            rcl_last_x_b = ddx * inv;
            rcl_last_y_b = ddy * inv;
            rcl_last_ok = 1;
        }

        if (d > 0.5f && d < RCL_WALK_MAX * 3.0f) {
            rcl_walk_step = rcl_walk_step * (1.0f - RCL_WALK_EMA) + d * RCL_WALK_EMA;

            if (rcl_walk_step < RCL_WALK_MIN) rcl_walk_step = RCL_WALK_MIN;
            if (rcl_walk_step > RCL_WALK_MAX) rcl_walk_step = RCL_WALK_MAX;
        }
    }

    rcl_prev_x_3 = x;
    rcl_prev_y_3 = y;
    rcl_prev_ok = 1;
}




int rcl_proj_mine(const rcl_proj_t *p) {
    int i = 0;
    int bestMine = 0;
    float best = 1.0e18f;
    float sx = 0.0f;
    float sy = 0.0f;

    if (!RCL_PROJ_OWNER) return 0;
    if (!rcl_team_trust) return 0;
    if (rcl_pl_n <= 0) return 0;
    if (rcl_own_team_b >= 0 && p->team == rcl_own_team_b) return 1;
    if (!p->spawnX && !p->spawnY) return 0;

    sx = (float)p->spawnX;
    sy = (float)p->spawnY;

    for (i = 0; i < rcl_pl_n; i++) {
        float dx = sx - (float)rcl_pl_x[i];
        float dy = sy - (float)rcl_pl_y[i];
        float d = dx * dx + dy * dy;

        if (d < best) {
            best = d;
            bestMine = rcl_pl_mine[i];
        }
    }

    if (best > RCL_SPAWN_R * RCL_SPAWN_R) return 0;


    return bestMine;
}

void rcl_state(void) {


    {
        uint16_t charState = 0;
        uint16_t sceneState = 0;
        int32_t charMode = 0;

        if (rcl_own_elem_2) {
            rcl_read_bytes(rcl_own_elem_2 + RCL_JOYSTATE_OFF, &charState, sizeof(charState));
            rcl_read_int(rcl_own_elem_2 + RCL_BS_MODE, &charMode);
        }

        if (rcl_scene_object) {
            rcl_read_bytes((uintptr_t)rcl_scene_object + RCL_JOYSTATE_OFF, &sceneState,
                           sizeof(sceneState));
        }

        uint8_t gate70 = 0;

        if (rcl_pred_last) {
            rcl_read_bytes(rcl_pred_last + RCL_GATE_OFF, &gate70, sizeof(gate70));
        }

        uint16_t enState[2] = { 0, 0 };
        int32_t enMode[2] = { 0, 0 };
        int seen = 0;
        int k = 0;

        for (k = 0; k < rcl_dodge_probe_usable && seen < 2; k++) {
            const rcl_obj_t *o = &rcl_dodge_probe_list[k];
            uint16_t st = 0;
            int32_t md = 0;

            if (!o->object) continue;
            if (o->gid < RCL_PLAYER_GID) continue;
            if (o->gid >= RCL_SHOT_GID) continue;
            if (rcl_own_elem_2 && o->object == rcl_own_elem_2) continue;
            if (!rcl_read_bytes((uintptr_t)o->object + RCL_JOYSTATE_OFF, &st, sizeof(st))) continue;

            rcl_read_int((uintptr_t)o->object + RCL_BS_MODE, &md);
            enState[seen] = st;
            enMode[seen] = md;
            seen++;
        }

    }

    {
        uintptr_t st = 0;

        if (rcl_read_ptr(rcl_client() + RCL_MGR_OFF, (void **)&st) && st) {
            int32_t stx = 0;
            int32_t sty = 0;
            int32_t stk = 0;
            int32_t sta = 0;
            uintptr_t stv = 0;

            rcl_read_int(st + RCL_MOVE_X_OFF, &stx);
            rcl_read_int(st + RCL_MOVE_Y_OFF, &sty);
            rcl_read_int(st + RCL_MOVE_KEY_OFF, &stk);
            rcl_read_int(st + RCL_MOVE_ARM_OFF, &sta);
            if (rcl_read_ptr(st, (void **)&stv) && stv >= rcl_base) stv -= rcl_base;


        }
    }


}

uint64_t rcl_word_2(uintptr_t address) {
    uint64_t value = 0;

    if (!rcl_read_bytes(address, &value, sizeof(value))) return 0;

    return value;
}

const char *rcl_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (!manager) return "no-manager";
    if (manager & 7ULL) return "manager-unaligned";
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array)) return "array-unreadable";
    if (!array) return "array-null";
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count)) return "count-unreadable";
    if (count <= 0) return "count-zero";
    if (!rcl_read_int(manager + RCL_MGR_CAP_OFF, &capacity)) return "cap-unreadable";
    if (count > capacity) return "count-above-cap";
    if (capacity > RCL_MGR_CAP_MAX) return "cap-above-ceiling";
    if (count > RCL_MANAGER_MAX_OBJECTS) return "count-above-ceiling";

    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return NULL;
}

uintptr_t rcl_coord_x_off(void) {
    return RCL_OBJ_X_OFF;
}

uintptr_t rcl_coord_y_off(void) {
    return RCL_OBJ_Y_OFF;
}



const uintptr_t rcl_mode_vtables[36] = {
    0x10012c8, 0x1001318, 0x1001368, 0x10013b8,
    0x1001408, 0x1001458, 0x10014a8, 0x10014f8, 0x1001548, 0x1001598, 0x10015e8, 0x10016e0,
    0x10017d8, 0x10018c0, 0x1001908, 0x10019d0, 0x1001ac8, 0x1001bc0, 0x1001cb8, 0x1001d80,
    0x1001e48, 0x1001f10, 0x10022f0, 0x10023b8, 0x1002480, 0x1002548, 0x1002610,
    0x10026d8, 0x10027a0, 0x1002868, 0x1002930, 0x10029f8, 0x1002ac0, 0x1002b88, 0x1002d18,
    0,
};

rcl_trail_t rcl_trail[RCL_TRAIL_MAX];

void rcl_probe(uintptr_t manager, uintptr_t mode, int verbose) {
    rcl_obj_t objects[RCL_OBJECT_MAX];
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int teamsNew[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int distinctOld = 0;
    int distinctNew = 0;

    memset(objects, 0, sizeof(objects));

    rcl_probe_done = 1;

    if (mode) rcl_read_map(mode);

    {
        static int v142_walk_logs = 0;

    }

    usable = rcl_collect(manager, objects, RCL_OBJECT_MAX);

    {
        static int v142_leave_logs = 0;

    }

    for (int i = 0; i < usable; i++) {
        if (objects[i].x > -RCL_COORD_ABS_MAX && objects[i].x < RCL_COORD_ABS_MAX &&
            objects[i].y > -RCL_COORD_ABS_MAX && objects[i].y < RCL_COORD_ABS_MAX) {
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

    rcl_team_off = (int)RCL_OBJ_TEAM_OFF;

    {
        char reasons[320];

    }



    if (!RCL_DEAD_ONCE || !rcl_dead_probe_done) {
        rcl_dead_probe_done = 1;
    }

    if (verbose) {

        for (int i = 0; i < usable && i < 16; i++) {
        }
    }

    rcl_coord_usable = usable;

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


    rcl_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;


    {
        int back = 0;
        int backRead = 0;

        for (int i = 0; i < usable; i++) {
            void *backPtr = NULL;

            if (!rcl_read_ptr(objects[i].object + RCL_ELEM_BACK_OFF, &backPtr)) continue;

            backRead++;

            if ((uintptr_t)backPtr == manager) back++;
        }

    }
}

void rcl_paircal(void) {
    uintptr_t ctrl = rcl_pair_base();
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

    if ((rcl_ticks_a % 60) != 0) return;
    if (rcl_logs_a >= RCL_LOGS_a) return;
    if (rcl_stick_hold) return;
    if (!ctrl) return;
    if (!rcl_own(&ownX, &ownY)) return;
    if (!rcl_read_int(ctrl + RCL_CTRL_RAW_X_OFF, &px)) return;
    if (!rcl_read_int(ctrl + RCL_CTRL_RAW_Y_OFF, &py)) return;

    if (rcl_seeded) {
        dx = (int)(ownX - rcl_last_x_a);
        dy = (int)(ownY - rcl_last_y_a);
    }

    rcl_seeded = 1;
    rcl_last_x_a = ownX;
    rcl_last_y_a = ownY;

    pLen = sqrtf((float)(px * px + py * py));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (pLen < 1.0f || mLen < 1.0f) return;

    rcl_logs_a++;

    dot = ((float)px / pLen) * ((float)dx / mLen) + ((float)py / pLen) * ((float)dy / mLen);
    angPair = atan2f((float)py, (float)px) * 57.2958f;
    angMove = atan2f((float)dy, (float)dx) * 57.2958f;

}

uintptr_t rcl_scene_object = 0;


int rcl_team_at(const rcl_obj_t *objects, int index) {
    if (!objects || index < 0) return -1;

    return (rcl_team_off == (int)RCL_OBJ_TEAM_OFF) ? objects[index].teamOld
                                                     : objects[index].teamNew;
}

int rcl_own_ok(int32_t x, int32_t y) {
    if (x == 0 && y == 0) return 0;
    if (x < -100000 || x > 100000) return 0;
    if (y < -100000 || y > 100000) return 0;

    return 1;
}

int rcl_own_side_spawn(int32_t sx, int32_t sy) {
    int i = 0;
    int best = -1;
    float bestD = 0.0f;
    float secondD = -1.0f;

    if (rcl_own_team_b < 0) return -1;
    if (rcl_pl_n <= 0) return -1;

    for (i = 0; i < rcl_pl_n; i++) {
        float dx = (float)sx - (float)rcl_pl_x[i];
        float dy = (float)sy - (float)rcl_pl_y[i];
        float d2 = dx * dx + dy * dy;

        if (best < 0 || d2 < bestD) {
            secondD = (best < 0) ? -1.0f : bestD;
            bestD = d2;
            best = i;
        } else if (secondD < 0.0f || d2 < secondD) {
            secondD = d2;
        }
    }

    if (best < 0) return -1;
    if (bestD > RCL_ATTRIB_R) return -1;
    if (secondD >= 0.0f && bestD * RCL_ATTRIB_MARGIN > secondD) return -1;

    return (rcl_pl_team[best] == rcl_own_team_b) ? 1 : 0;
}

int rcl_enemy_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (!rcl_team_trust || rcl_enemy_n <= 0) return 0;

    for (i = 0; i < rcl_enemy_n; i++) {
        float ex = (float)rcl_enemy_x[i];
        float ey = (float)rcl_enemy_y[i];
        float dc = sqrtf((x - ex) * (x - ex) + (y - ey) * (y - ey));
        float dOwn = sqrtf((ownX - ex) * (ownX - ex) + (ownY - ey) * (ownY - ey));

        if (dc < RCL_ENEMY_HARD) return 1;
        if (dOwn > RCL_ENEMY_FAR && dc < dOwn - RCL_ENEMY_MARGIN) return 1;
    }

    return 0;
}

int rcl_mate_blocked(float x, float y) {
    int i = 0;
    float r2 = RCL_MATE_CLEAR * RCL_MATE_CLEAR;

    if (!rcl_team_trust) return 0;
    if (rcl_mate_n <= 0) return 0;

    for (i = 0; i < rcl_mate_n; i++) {
        float dx = x - (float)rcl_mate_x[i];
        float dy = y - (float)rcl_mate_y[i];

        if (dx * dx + dy * dy <= r2) return 1;
    }

    return 0;
}
void rcl_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py) {
    int i = 0;

    rcl_state_code = RCL_STATE_RESPAWN;
    rcl_respawn_tick = (int)rcl_ticks_a;

    rcl_clear_life();

    rcl_pending = 1;
    rcl_pending_tick = (int)rcl_ticks_a;

    for (i = 0; i < RCL_CAND; i++) {
        rcl_pre[i] = rcl_cand_frame[i];
        rcl_cand_changes[i] = 0;
    }

}

uintptr_t rcl_own_ptr = 0;

int rcl_own_index = -1;


const char *rcl_own_from = "none";

uint64_t rcl_tick_stamp = 0;

void rcl_own_index_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    uintptr_t array = rcl_players_array;
    int32_t count = rcl_players_count;
    int taken = 0;
    int chosen = -1;
    int b;

    if (!array || count <= 0) return;

    cand[0] = (uintptr_t)rcl_players_object;
    cand[1] = (uintptr_t)rcl_scene_object;

    for (b = 0; b < 2; b++) {
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        void *elem = NULL;
        int hit = 0;

        if (!cand[b]) continue;
        if (!rcl_read_int(cand[b] + RCL_OWNIDX_OFF, &idx)) continue;

        rcl_read_int(cand[b] + RCL_OWNTEAM_OFF, &team);

        if (idx >= 0 && idx < count) {
            if (rcl_read_ptr(array + (uintptr_t)idx * 8ULL, &elem) && elem) hit = 1;
        }

        if (hit && !taken) {
            taken = 1;
            chosen = b;
            rcl_own_index = idx;
            rcl_own_ptr = (uintptr_t)elem;
            rcl_own_from = (b == 0) ? "container+e0" : "scene+e0";
        }
    }

    if (!taken) {
        rcl_own_index = -1;
        rcl_own_ptr = 0;
        rcl_own_from = "index-miss";
    }

}

const char *rcl_own_from_b = "none";

void rcl_publish_own(uintptr_t elem, const char *from) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (!rcl_cand_ok(elem, &why, &vt)) {

        return;
    }

    rcl_own_elem = elem;
    rcl_own_stamp = rcl_tick_stamp;
    rcl_own_from_b = from ? from : "?";

    if (rcl_pub_logs < RCL_PUB_LOGS) {
        uintptr_t cls = (vt >= rcl_base) ? (vt - rcl_base) : 0;

        rcl_pub_logs++;

    }
}
int rcl_own_from_slot(uintptr_t *objectOut, int32_t *gidOut) {
    uintptr_t scene = (uintptr_t)rcl_scene_object;
    uintptr_t hop[RCL_HOPS] = { 0 };
    void *outer = NULL;
    int k;

    if (objectOut) *objectOut = 0;
    if (gidOut) *gidOut = 0;

    if (!scene) return 0;

    if (rcl_read_ptr(scene + RCL_CLIENT_OFF, &outer) && outer) {
        hop[0] = (uintptr_t)outer;

        if (rcl_read_ptr((uintptr_t)outer + RCL_CLIENT_OFF, &outer) && outer) {
            hop[1] = (uintptr_t)outer;
        }
    }

    for (k = 0; k < RCL_HOPS; k++) {
        void *array = NULL;
        void *element = NULL;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t gid = 0;

        if (!hop[k]) continue;
        if (!rcl_read_int(hop[k] + RCL_OWNIDX_OFF_2, &idx)) continue;
        if (!rcl_read_ptr(hop[k] + RCL_MGR_ARRAY_OFF, &array) || !array) continue;
        if (!rcl_read_int(hop[k] + RCL_MGR_COUNT_OFF, &count)) continue;
        if (idx < 0 || idx >= count || count <= 0) continue;
        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &element) || !element) continue;

        gid = rcl_gid((uintptr_t)element, NULL);

        if (gid < RCL_GID_FLOOR || gid >= RCL_PLAYER_GID_MAX) {
            continue;
        }


        if (objectOut) *objectOut = (uintptr_t)element;
        if (gidOut) *gidOut = gid;

        return 1;
    }

    return 0;
}

uintptr_t rcl_players_object = 0;

uintptr_t rcl_players_array = 0;

int rcl_players_count = 0;

uintptr_t rcl_own_elem_2 = 0;

int rcl_state_code = RCL_STATE_INIT;

int rcl_pl_n = 0;

int32_t rcl_pl_x[RCL_PLAYER_MAX];

int32_t rcl_pl_y[RCL_PLAYER_MAX];

int32_t rcl_pl_team[RCL_PLAYER_MAX];

int rcl_mate_n = 0;

int32_t rcl_mate_x[RCL_MATE_MAX];

int32_t rcl_mate_y[RCL_MATE_MAX];

int rcl_own_team_b = -1;

int rcl_team_trust = 1;

int32_t rcl_enemy_x[RCL_PLAYER_MAX];

int32_t rcl_enemy_y[RCL_PLAYER_MAX];

int rcl_enemy_n = 0;

void rcl_roster(uintptr_t ownElem, int ownIndex, int ownTeam,
                            const rcl_obj_t *objects, int usable) {
    int i = 0;
    int matesBefore = rcl_mate_n;
    int ownSide = 0;
    int hist[RCL_PLAYER_MAX];
    int hn = 0;

    rcl_pl_n = 0;
    rcl_mate_n = 0;
    rcl_enemy_n = 0;
    rcl_own_team_b = ownTeam;
    rcl_team_trust = 1;

    for (i = 0; i < usable && rcl_pl_n < RCL_PLAYER_MAX; i++) {
        int32_t team = 0;
        int isOwn = 0;
        int h = 0;

        if (objects[i].gid < RCL_PLAYER_GID) continue;
        if (objects[i].gid >= RCL_SHOT_GID) continue;

        team = rcl_team_at(objects, i);
        isOwn = (ownElem && objects[i].object == ownElem) ? 1
                                                          : ((!ownElem && i == ownIndex) ? 1 : 0);

        rcl_pl_x[rcl_pl_n] = objects[i].x;
        rcl_pl_y[rcl_pl_n] = objects[i].y;
        rcl_pl_team[rcl_pl_n] = team;
        rcl_pl_mine[rcl_pl_n] = isOwn;
        rcl_pl_n++;

        if (isOwn) {
            rcl_own_x = objects[i].x;
            rcl_own_y = objects[i].y;

            continue;
        }

        for (h = 0; h < hn; h++) {
            if (hist[h] == team) break;
        }

        if (h == hn && hn < RCL_PLAYER_MAX) {
            hist[hn++] = team;
        }

        if (team != ownTeam) continue;

        ownSide++;

        if (rcl_mate_n >= RCL_MATE_MAX) continue;

        rcl_mate_x[rcl_mate_n] = objects[i].x;
        rcl_mate_y[rcl_mate_n] = objects[i].y;
        rcl_mate_n++;
    }

    ownSide++;

    if (rcl_pl_n >= 4 && (ownSide > (rcl_pl_n / 2) || hn < 2)) {
        rcl_team_trust = 0;
        rcl_mate_n = 0;
    }

    {
        int ownSpawn = -1;
        int k = 0;

        for (k = 0; k < rcl_pl_n; k++) {
            if (rcl_pl_mine[k]) { ownSpawn = k; break; }
        }

        rcl_mates = 0;
        rcl_enemies = 0;

        if (ownSpawn >= 0) {
            for (k = 0; k < rcl_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (rcl_pl_mine[k]) continue;

                dx = (float)(rcl_pl_x[k] - rcl_pl_x[ownSpawn]);
                dy = (float)(rcl_pl_y[k] - rcl_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= RCL_CLUSTER) rcl_mates++;
                else rcl_enemies++;
            }
        }

        {
            int same = 1;

            for (k = 1; k < rcl_pl_n; k++) {
                if (rcl_pl_team[k] != rcl_pl_team[0]) same = 0;
            }

            if (rcl_pl_n > 1 && same && rcl_team_trust) {
                rcl_team_trust = 0;

            }
        }

        if (!rcl_team_trust) {
            int m = 0;
            int e = 0;

            rcl_mate_n = 0;
            rcl_enemy_n = 0;

            for (k = 0; k < rcl_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (rcl_pl_mine[k]) continue;

                dx = (float)(rcl_pl_x[k] - rcl_pl_x[ownSpawn]);
                dy = (float)(rcl_pl_y[k] - rcl_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= RCL_CLUSTER) {
                    if (m < RCL_MATE_MAX) {
                        rcl_mate_x[m] = rcl_pl_x[k];
                        rcl_mate_y[m] = rcl_pl_y[k];
                        m++;
                    }
                } else if (e < RCL_PLAYER_MAX) {
                    rcl_enemy_x[e] = rcl_pl_x[k];
                    rcl_enemy_y[e] = rcl_pl_y[k];
                    e++;
                }
            }

            rcl_mate_n = m;
            rcl_enemy_n = e;

        }
    }

    if (rcl_team_trust) {
        for (i = 0; i < rcl_pl_n && rcl_enemy_n < RCL_PLAYER_MAX; i++) {
            if (rcl_pl_mine[i]) continue;
            if (rcl_pl_team[i] == ownTeam) continue;

            rcl_enemy_x[rcl_enemy_n] = rcl_pl_x[i];
            rcl_enemy_y[rcl_enemy_n] = rcl_pl_y[i];
            rcl_enemy_n++;
        }
    }

    rcl_agree = (rcl_mates == rcl_mate_n && rcl_enemies == rcl_enemy_n) ? 1 : 0;


}

int rcl_cand_frame[RCL_CAND];

int rcl_cand_changes[RCL_CAND];

int rcl_dead_slot = -1;

int rcl_dead_value = 0;

int rcl_pending = 0;

int rcl_pending_tick = 0;

int rcl_pre[RCL_CAND];

int rcl_prev_valid = 0;

int rcl_respawn_tick = 0;


void rcl_clear_life(void) {
    rcl_stage = 0;
    rcl_active = 0;
    rcl_last_write_ms = 0;
    rcl_issued = 0;
    rcl_moving = 0;
    rcl_hold = 0;
    rcl_stick_hold = 0;
    rcl_stick_x = 0;
    rcl_stick_y = 0;
    rcl_prev_valid = 0;
}

int rcl_life(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    int i = 0;
    int changed = 0;
    int deadNow = 0;

    rcl_candidates(ownElem, rcl_cand_now);

    if (rcl_cand_seen) {
        for (i = 0; i < RCL_CAND; i++) {
            if (rcl_cand_now[i] != rcl_cand_frame[i]) {
                changed = 1;

                if (rcl_cand_changes[i] < 1000000) rcl_cand_changes[i]++;
            }
        }

    }

    for (i = 0; i < RCL_CAND; i++) rcl_cand_frame[i] = rcl_cand_now[i];
    rcl_cand_seen = 1;

    if (rcl_pending && ((int)rcl_ticks_a - rcl_pending_tick) >= RCL_HOLD_FRAMES) {
        int bestSlot = -1;
        int bestChanges = 0;

        rcl_pending = 0;

        for (i = 0; i < RCL_CAND; i++) {
            if (rcl_pre[i] < 0 || rcl_cand_now[i] < 0) continue;
            if (rcl_cand_now[i] == rcl_pre[i]) continue;
            if (bestSlot < 0 || rcl_cand_changes[i] < bestChanges) {
                bestSlot = i;
                bestChanges = rcl_cand_changes[i];
            }
        }

        if (bestSlot >= 0) {
            rcl_dead_slot = bestSlot;
            rcl_dead_value = rcl_pre[bestSlot];

        }
    }

    if (rcl_prev_valid && rcl_own_ok(ownX, ownY) &&
        rcl_own_ok(rcl_prev_x, rcl_prev_y)) {
        int64_t jx = (int64_t)ownX - (int64_t)rcl_prev_x;
        int64_t jy = (int64_t)ownY - (int64_t)rcl_prev_y;

        if (jx * jx + jy * jy >= (int64_t)RCL_RESPAWN_JUMP * RCL_RESPAWN_JUMP) {
            rcl_respawn_event(ownX, ownY, rcl_prev_x, rcl_prev_y);
        }
    }

    rcl_prev_x = ownX;
    rcl_prev_y = ownY;
    rcl_prev_valid = 1;

    if (rcl_state_code == RCL_STATE_INIT) rcl_state_code = RCL_STATE_ALIVE;

    if (rcl_dead_slot >= 0 &&
        rcl_cand_now[rcl_dead_slot] == rcl_dead_value) deadNow = 1;

    if (deadNow) {
        if (rcl_state_code != RCL_STATE_DEAD) {
            rcl_state_code = RCL_STATE_DEAD;

        }

        return 1;
    }

    if (rcl_state_code == RCL_STATE_DEAD) {
        rcl_clear_life();

        rcl_state_code = RCL_STATE_ALIVE;


        return 0;
    }

    if (rcl_state_code == RCL_STATE_RESPAWN &&
        ((int)rcl_ticks_a - rcl_respawn_tick) < RCL_RESPAWN_VISIBLE) {
        return 0;
    }

    rcl_state_code = RCL_STATE_ALIVE;

    return 0;
}

int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut,
                                const char **fromOut) {
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t wantGid = -1;
    uintptr_t slotOwn = 0;
    int32_t slotGid = 0;
    int hasWit = 0;
    int best = -1;
    int64_t bestD = 0;
    int i;

    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    {
        uintptr_t minOwn = 0;
        int32_t minGid = 0;


        if (rcl_own_by_min_gid(rcl_tick_array, rcl_tick_count, &minOwn, &minGid) &&
            minOwn) {
            for (i = 0; i < usable; i++) {
                if (objects[i].object != minOwn) continue;

                if (indexOut) *indexOut = i;
                if (fromOut) *fromOut = "v134-min";

                return 1;
            }
        }
    }

    if (rcl_own_from_slot(&slotOwn, &slotGid) && slotOwn) {
        for (i = 0; i < usable; i++) {
            if (objects[i].object != slotOwn) continue;
            if (objects[i].gid < RCL_GID_FLOOR || objects[i].gid >= RCL_GID_MAX) continue;

            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-slot";

            return 1;
        }
    }

    if (rcl_own_gid > 0) {
        wantGid = rcl_own_gid;
    } else if (slotGid > 0) {
        wantGid = slotGid;
    } else if (rcl_own_ptr_a) {
        wantGid = rcl_gid((uintptr_t)rcl_own_ptr_a, NULL);
    }

    for (i = 0; i < usable; i++) {
        if (objects[i].x <= -RCL_COORD_MAX || objects[i].x >= RCL_COORD_MAX) continue;
        if (objects[i].y <= -RCL_COORD_MAX || objects[i].y >= RCL_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        if (wantGid > 0 && objects[i].gid == wantGid) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-gid";


            return 1;
        }
    }

    if (rcl_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    hasWit = rcl_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {

        return 0;
    }

    for (i = 0; i < usable; i++) {
        int64_t dx = 0;
        int64_t dy = 0;
        int64_t d = 0;

        if (objects[i].x <= -RCL_COORD_MAX || objects[i].x >= RCL_COORD_MAX) continue;
        if (objects[i].y <= -RCL_COORD_MAX || objects[i].y >= RCL_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        dx = (int64_t)objects[i].x - (int64_t)wx;
        dy = (int64_t)objects[i].y - (int64_t)wy;
        d = dx * dx + dy * dy;

        if (best < 0 || d < bestD) {
            best = i;
            bestD = d;
        }
    }

    if (best < 0) return 0;

    if (indexOut) *indexOut = best;
    if (fromOut) *fromOut = "v129-near";

    return 1;
}

uintptr_t rcl_own_ptr_a = 0;



const char *rcl_own_from_a = "none";

uintptr_t rcl_own_ptr_b = 0;

int rcl_own_index_3 = -1;

int rcl_own_verdict(uintptr_t element) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int32_t gid = 0;
    int32_t x = 0;
    int32_t y = 0;
    int32_t teamOld = 0;
    int32_t teamNew = 0;
    uint8_t dead = 0;

    if (!element) return 0;
    if (rcl_element_ascii(element)) return 0;
    if (!rcl_read_ptr(element, &vtable) || !vtable) return 0;

    vtRva = (uintptr_t)vtable - rcl_base;

    if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE) return 0;

    gid = rcl_gid(element, NULL);

    if (!rcl_read_int(element + rcl_coord_x_off(), &x) ||
        !rcl_read_int(element + rcl_coord_y_off(), &y) ||
        !rcl_read_int(element + RCL_OBJ_TEAM_OFF, &teamOld) ||
        !rcl_read_int(element + RCL_TEAM_OFF, &teamNew) ||
        !rcl_read_byte(element + RCL_OBJ_DEADFLAG_OFF, &dead)) {
        return 0;
    }

    if (x <= -RCL_COORD_ABS_MAX || x >= RCL_COORD_ABS_MAX ||
        y <= -RCL_COORD_ABS_MAX || y >= RCL_COORD_ABS_MAX) {
        return 0;
    }

    return 1;
}

void rcl_own_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    int taken = 0;
    int b;

    cand[0] = (uintptr_t)rcl_players_object;
    cand[1] = (uintptr_t)rcl_scene_object;

    for (b = 0; b < 2; b++) {
        void *array = NULL;
        void *elem = NULL;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        int32_t elemGid = 0;
        int32_t gidOff = 0;
        const char *sigField = (const char *)"none";
        int sig = 0;
        int valid = 0;

        if (!cand[b]) continue;

        if (!rcl_read_ptr(cand[b] + RCL_ARRAY_OFF, &array) || !array) {
            continue;
        }

        if (!rcl_read_int(cand[b] + RCL_COUNT_OFF, &count)) count = 0;
        if (!rcl_read_int(cand[b] + RCL_OWNIDX_OFF_2, &idx)) idx = -1;
        if (!rcl_read_int(cand[b] + RCL_OWNTEAM_OFF_2, &team)) team = -1;

        if (idx >= 0 && count > 0 && idx < count) {
            if (rcl_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &elem) && elem) {
                if (rcl_read_int((uintptr_t)elem + RCL_ELEM_ID_OFF_2, &eid) &&
                    rcl_read_int((uintptr_t)elem + RCL_ELEM_TEAM_OFF_2, &eteam)) {
                    elemGid = rcl_gid((uintptr_t)elem, &gidOff);

                    if (eid == idx && eid != 0) {
                        sig = 1;
                        sigField = (const char *)"idAt48";
                    } else if (team >= 0 && team <= RCL_OBJ_TEAM_MAX && eteam == team) {
                        sig = 2;
                        sigField = (const char *)"teamAt4c";
                    } else if (idx == 0 && elemGid != 0) {
                        sig = 3;
                        sigField = (const char *)"slotZeroWithGid";
                    } else {
                        sig = 0;
                        sigField = (const char *)"none";
                    }
                }
            }
        }

        if (sig) valid = rcl_own_verdict((uintptr_t)elem);


        if (sig && valid && !taken) {
            taken = 1;
            rcl_own_ptr_a = (uintptr_t)elem;
            rcl_own_from_a = (b == 0) ? "container+e0" : "scene+e0";

        }
    }

    if (!taken) {
        rcl_own_ptr_a = 0;
        rcl_own_from_a = "v102-none";
    }
}
int rcl_own_latch(const rcl_obj_t *objects, int usable, int *indexOut,
                              const char **fromOut) {
    int i = 0;

    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";
    if (!objects || usable <= 0 || !rcl_own_elem_2) return 0;

    for (i = 0; i < usable; i++) {
        if (objects[i].object != rcl_own_elem_2) continue;
        if (objects[i].gid < RCL_GID_FLOOR || objects[i].gid >= RCL_PLAYER_GID_MAX) return 0;
        if (objects[i].teamOld < 0 || objects[i].teamOld > RCL_TEAM_MAX_2) return 0;

        if (indexOut) *indexOut = i;
        if (fromOut) *fromOut = "latched";

        return 1;
    }

    return 0;
}
uintptr_t rcl_own_elem = 0;

uint64_t rcl_own_stamp = 0;

uintptr_t rcl_own_obj(void) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (rcl_own_elem) {
        if (rcl_cand_ok(rcl_own_elem, &why, &vt)) {
            rcl_own_from_b = (rcl_own_stamp == rcl_tick_stamp) ? "published" : "published-old";

            return rcl_own_elem;
        }

    }

    {
        uintptr_t cand = rcl_hop((uintptr_t)rcl_scene_object, NULL);

        if (cand && rcl_cand_ok(cand, NULL, &vt)) {
            rcl_own_from_b = "engine-chain";

            return cand;
        }

        cand = rcl_hop((uintptr_t)rcl_players_object, NULL);

        if (cand && rcl_cand_ok(cand, NULL, &vt)) {
            rcl_own_from_b = "players-chain";

            return cand;
        }
    }

    rcl_own_from_b = "none";

    return 0;
}

int32_t rcl_own_gid = 0;

int rcl_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut,
                                   int32_t *gidOut) {
    uintptr_t best = 0;
    int32_t bestGid = 0;
    int32_t i = 0;

    if (elemOut) *elemOut = 0;
    if (gidOut) *gidOut = 0;
    if (!array || count <= 0) return 0;

    for (i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;
        int32_t team = 0;

        if (!rcl_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        gid = rcl_gid((uintptr_t)element, NULL);

        if (gid < RCL_GID_FLOOR || gid >= RCL_PLAYER_GID_MAX) continue;
        if (!rcl_read_int((uintptr_t)element + RCL_OBJ_TEAM_OFF, &team)) continue;
        if (team < 0 || team > RCL_TEAM_MAX_2) continue;

        if (!best || gid < bestGid) {
            best = (uintptr_t)element;
            bestGid = gid;
        }
    }

    if (!best) {
        return 0;
    }

    rcl_own_gid = bestGid;

    if (elemOut) *elemOut = best;
    if (gidOut) *gidOut = bestGid;

    return 1;
}

int rcl_own_from_list(const rcl_obj_t *objects, int usable, int *indexOut,
                                  const char **fromOut) {
    int best = -1;
    int32_t bestGid = 0;
    int accepted = 0;
    int i;

    if (indexOut) *indexOut = -1;
    if (!objects || usable <= 0) return 0;

    for (i = 0; i < usable; i++) {
        int32_t gid = objects[i].gid;

        if (gid < RCL_GID_FLOOR || gid >= RCL_PLAYER_GID_MAX) continue;
        if (objects[i].teamOld < 0 || objects[i].teamOld > RCL_TEAM_MAX_2) continue;

        accepted++;

        if (best < 0 || gid < bestGid) {
            best = i;
            bestGid = gid;
        }
    }


    if (best < 0) return 0;

    if (indexOut) *indexOut = best;
    if (fromOut) *fromOut = "v135-list";

    return 1;
}

int rcl_own_scan(void) {
    uintptr_t bases[RCL_SCAN_BASES];
    const char *names[RCL_SCAN_BASES] = { "mode", "client", "inputMgr" };
    uintptr_t array = rcl_players_array;
    int32_t count = rcl_players_count;
    uintptr_t client = 0;
    uintptr_t inputMgr = 0;
    void *chain = NULL;
    void *input = NULL;
    int found = 0;

    if (!rcl_scene_object) return 0;
    if (!array || count <= 0) return 0;

    bases[0] = rcl_scene_object;

    if (rcl_read_ptr(rcl_scene_object + RCL_MODE_MANAGER_OFF, &chain) && chain) {
        client = (uintptr_t)chain;
    }

    if (rcl_read_ptr(rcl_scene_object + RCL_MODE_INPUTMGR_OFF, &input) && input) {
        inputMgr = (uintptr_t)input;
    }

    bases[1] = client;
    bases[2] = inputMgr;

    rcl_own_index_probe();

    rcl_own_probe();


    if (!rcl_setpred) rcl_setpred = rcl_entry(RCL_MODEPAIRSET_RVA);


    for (int b = 0; b < RCL_SCAN_BASES; b++) {
        if (!bases[b]) continue;

        for (int i = 0; i < RCL_SCAN_QWORDS; i++) {
            uintptr_t off = (uintptr_t)i * 8ULL;
            uintptr_t value = (uintptr_t)rcl_word_2(bases[b] + off);
            uintptr_t index = 0;

            if (!value) continue;
            if (value <= array) continue;
            if (value >= array + (uintptr_t)count * 8ULL) continue;
            if ((value - array) % 8ULL) continue;

            index = (value - array) / 8ULL;

            if (!found) {
                rcl_own_ptr_b = value;
                rcl_own_index_3 = (int)index;
                found = 1;
            }

        }
    }

    if (!found && rcl_scan_container != (uintptr_t)array) {
        rcl_scan_container = (uintptr_t)array;

    }

    if (!rcl_find_joy_done) {
        rcl_find_joy_done = 1;

    }

    return found;
}

int rcl_resolve_own_2(const rcl_obj_t *objects, int usable, int *indexOut,
                               const char **fromOut) {
    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    if (rcl_own_index >= 0 && rcl_own_ptr) {
        int seen = 0;
        int i;

        for (i = 0; i < usable; i++) {
            if (objects[i].object == rcl_own_ptr) {
                seen = 1;
                break;
            }
        }

        if (seen) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = rcl_own_from;

            return 1;
        }

    }

    if (rcl_own_index_3 >= 0 && rcl_own_index_3 < usable &&
        objects[rcl_own_index_3].object == rcl_own_ptr_b) {
        if (indexOut) *indexOut = rcl_own_index_3;
        if (fromOut) *fromOut = "scan";

        return 1;
    }

    return 0;
}

int rcl_own(int32_t *xOut, int32_t *yOut) {
    uintptr_t own = rcl_own_elem_2;

    if (!own) own = (uintptr_t)rcl_own_elem;
    if (!own) return 0;
    if (!rcl_read_int(own + RCL_OBJ_X_OFF, xOut)) return 0;
    if (!rcl_read_int(own + RCL_OBJ_Y_OFF, yOut)) return 0;

    return 1;
}

int rcl_object_live(uintptr_t object) {
    int32_t gid = 0;
    int32_t team = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!rcl_gameobject_shape(object)) return 0;
    if (!rcl_read_int(object + RCL_OBJ_GLOBALID_OFF, &gid)) return 0;
    if (gid <= 0 || gid >= RCL_GID_MAX) return 0;
    if (!rcl_read_int(object + RCL_OBJ_TEAM_OFF, &team)) return 0;
    if (team < 0 || team > RCL_TEAM_MAX_2) return 0;
    if (!rcl_read_int(object + rcl_coord_x_off(), &x)) return 0;
    if (!rcl_read_int(object + rcl_coord_y_off(), &y)) return 0;
    if (x <= -RCL_COORD_MAX || x >= RCL_COORD_MAX) return 0;
    if (y <= -RCL_COORD_MAX || y >= RCL_COORD_MAX) return 0;

    return 1;
}

void rcl_candidates(uintptr_t ownElem, int *out) {
    uint8_t deadByte = 0;
    int32_t ownAlive = -1;
    int32_t ctrlAlive = -1;
    uintptr_t ctrl = rcl_controller();

    out[0] = -1;
    out[1] = -1;
    out[2] = -1;

    if (ownElem && rcl_read_bytes(ownElem + RCL_DEAD_OFF, &deadByte, sizeof(deadByte))) {
        out[0] = (int)deadByte;
    }

    if (ownElem && rcl_read_int(ownElem + RCL_OWN_ALIVE_OFF, &ownAlive)) out[1] = (int)ownAlive;

    if (ctrl && rcl_read_int(ctrl + RCL_CTRL_ALIVE_OFF, &ctrlAlive)) out[2] = (int)ctrlAlive;
}

int rcl_own_x = 0;

int rcl_own_y = 0;

int rcl_ascii_word(uintptr_t address) {
    uint8_t bytes[8];
    int printable = 0;

    if (!rcl_read_bytes(address, bytes, sizeof(bytes))) return 0;

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable == 8 ? 1 : 0;
}

int rcl_word_ascii(uint64_t value) {
    uint8_t bytes[8];
    int printable = 0;

    memcpy(bytes, &value, sizeof(bytes));

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable;
}

int rcl_element_ascii(uintptr_t element) {
    if (rcl_ascii_word(element)) return 1;

    return rcl_word_ascii((uint64_t)element) == 8 ? 1 : 0;
}
