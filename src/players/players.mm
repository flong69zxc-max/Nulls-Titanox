#include "titanox.h"

int tnx_team_at(const tnx_obj_t *objects, int index) {
    if (!objects || index < 0) return -1;

    return (t_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[index].teamOld
                                                     : objects[index].teamNew;
}

int tnx_own_ok(int32_t x, int32_t y) {
    if (x == 0 && y == 0) return 0;
    if (x < -100000 || x > 100000) return 0;
    if (y < -100000 || y > 100000) return 0;

    return 1;
}

int tnx_own_side_spawn(int32_t sx, int32_t sy) {
    int i = 0;
    int best = -1;
    float bestD = 0.0f;
    float secondD = -1.0f;

    if (t_own_team_b < 0) return -1;
    if (t_pl_n <= 0) return -1;

    for (i = 0; i < t_pl_n; i++) {
        float dx = (float)sx - (float)t_pl_x[i];
        float dy = (float)sy - (float)t_pl_y[i];
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
    if (bestD > TNX_ATTRIB_R) return -1;
    if (secondD >= 0.0f && bestD * TNX_ATTRIB_MARGIN > secondD) return -1;

    return (t_pl_team[best] == t_own_team_b) ? 1 : 0;
}

int tnx_enemy_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (!t_team_trust || t_enemy_n <= 0) return 0;

    for (i = 0; i < t_enemy_n; i++) {
        float ex = (float)t_enemy_x[i];
        float ey = (float)t_enemy_y[i];
        float dc = sqrtf((x - ex) * (x - ex) + (y - ey) * (y - ey));
        float dOwn = sqrtf((ownX - ex) * (ownX - ex) + (ownY - ey) * (ownY - ey));

        if (dc < TNX_ENEMY_HARD) return 1;
        if (dOwn > TNX_ENEMY_FAR && dc < dOwn - TNX_ENEMY_MARGIN) return 1;
    }

    return 0;
}

int tnx_mate_blocked(float x, float y) {
    int i = 0;
    float r2 = TNX_MATE_CLEAR * TNX_MATE_CLEAR;

    if (!t_team_trust) return 0;
    if (t_mate_n <= 0) return 0;

    for (i = 0; i < t_mate_n; i++) {
        float dx = x - (float)t_mate_x[i];
        float dy = y - (float)t_mate_y[i];

        if (dx * dx + dy * dy <= r2) return 1;
    }

    return 0;
}
void tnx_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py) {
    int i = 0;

    t_state = TNX_STATE_RESPAWN;
    t_respawn_tick = (int)t_ticks_a;

    tnx_clear_life();

    t_pending = 1;
    t_pending_tick = (int)t_ticks_a;

    for (i = 0; i < TNX_CAND; i++) {
        t_pre[i] = t_cand_frame[i];
        t_cand_changes[i] = 0;
    }

}

uintptr_t t_own_ptr = 0;

int t_own_index = -1;


const char *t_own_from = "none";

uint64_t t_tick_stamp = 0;

void tnx_own_index_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    uintptr_t array = t_players_array;
    int32_t count = t_players_count;
    int taken = 0;
    int chosen = -1;
    int b;

    if (!array || count <= 0) return;

    cand[0] = (uintptr_t)t_players_object;
    cand[1] = (uintptr_t)t_scene_object;

    for (b = 0; b < 2; b++) {
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        void *elem = NULL;
        int hit = 0;

        if (!cand[b]) continue;
        if (!tnx_read_int(cand[b] + TNX_OWNIDX_OFF, &idx)) continue;

        tnx_read_int(cand[b] + TNX_OWNTEAM_OFF, &team);

        if (idx >= 0 && idx < count) {
            if (tnx_read_ptr(array + (uintptr_t)idx * 8ULL, &elem) && elem) hit = 1;
        }

        if (hit) {
            if (tnx_read_int((uintptr_t)elem + TNX_ELEM_ID_OFF, &eid) &&
                tnx_read_int((uintptr_t)elem + TNX_ELEM_TEAM_OFF, &eteam)) {
                t_own_idhit = (eid == idx) ? 1 : 0;
            }
        }


        if (hit && !taken) {
            taken = 1;
            chosen = b;
            t_own_index = idx;
            t_own_ptr = (uintptr_t)elem;
            t_own_from = (b == 0) ? "container+e0" : "scene+e0";
        }
    }

    if (!taken) {
        t_own_index = -1;
        t_own_ptr = 0;
        t_own_from = "index-miss";
    }

}

const char *t_own_from_b = "none";

void tnx_publish_own(uintptr_t elem, const char *from) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (!tnx_cand_ok(elem, &why, &vt)) {

        return;
    }

    t_own_elem = elem;
    t_own_stamp = t_tick_stamp;
    t_own_from_b = from ? from : "?";

    if (t_pub_logs < TNX_PUB_LOGS) {
        uintptr_t cls = (vt >= t_base) ? (vt - t_base) : 0;

        t_pub_logs++;

    }
}
int tnx_own_from_slot(uintptr_t *objectOut, int32_t *gidOut) {
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t hop[TNX_HOPS] = { 0 };
    void *outer = NULL;
    int k;

    if (objectOut) *objectOut = 0;
    if (gidOut) *gidOut = 0;

    if (!scene) return 0;

    if (tnx_read_ptr(scene + TNX_CLIENT_OFF, &outer) && outer) {
        hop[0] = (uintptr_t)outer;

        if (tnx_read_ptr((uintptr_t)outer + TNX_CLIENT_OFF, &outer) && outer) {
            hop[1] = (uintptr_t)outer;
        }
    }

    for (k = 0; k < TNX_HOPS; k++) {
        void *array = NULL;
        void *element = NULL;
        int32_t count = 0;
        int32_t idx = -1;
        int32_t gid = 0;

        if (!hop[k]) continue;
        if (!tnx_read_int(hop[k] + TNX_OWNIDX_OFF_2, &idx)) continue;
        if (!tnx_read_ptr(hop[k] + TNX_MGR_ARRAY_OFF, &array) || !array) continue;
        if (!tnx_read_int(hop[k] + TNX_MGR_COUNT_OFF, &count)) continue;
        if (idx < 0 || idx >= count || count <= 0) continue;
        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &element) || !element) continue;

        gid = tnx_gid((uintptr_t)element, NULL);

        if (gid < TNX_GID_FLOOR || gid >= TNX_PLAYER_GID_MAX) {
            continue;
        }


        if (objectOut) *objectOut = (uintptr_t)element;
        if (gidOut) *gidOut = gid;

        return 1;
    }

    return 0;
}

uintptr_t t_players_object = 0;

uintptr_t t_players_array = 0;

int t_players_count = 0;

uintptr_t t_own_elem_2 = 0;

int t_state = TNX_STATE_INIT;

int t_pl_n = 0;

int32_t t_pl_x[TNX_PLAYER_MAX];

int32_t t_pl_y[TNX_PLAYER_MAX];

int32_t t_pl_team[TNX_PLAYER_MAX];

int t_mate_n = 0;

int32_t t_mate_x[TNX_MATE_MAX];

int32_t t_mate_y[TNX_MATE_MAX];

int t_own_team_b = -1;

int t_team_trust = 1;

int32_t t_enemy_x[TNX_PLAYER_MAX];

int32_t t_enemy_y[TNX_PLAYER_MAX];

int t_enemy_n = 0;

void tnx_roster(uintptr_t ownElem, int ownIndex, int ownTeam,
                            const tnx_obj_t *objects, int usable) {
    int i = 0;
    int matesBefore = t_mate_n;
    int ownSide = 0;
    int hist[TNX_PLAYER_MAX];
    int hn = 0;

    t_pl_n = 0;
    t_mate_n = 0;
    t_enemy_n = 0;
    t_own_team_b = ownTeam;
    t_team_trust = 1;

    for (i = 0; i < usable && t_pl_n < TNX_PLAYER_MAX; i++) {
        int32_t team = 0;
        int isOwn = 0;
        int h = 0;

        if (objects[i].gid < TNX_PLAYER_GID) continue;
        if (objects[i].gid >= TNX_SHOT_GID) continue;

        team = tnx_team_at(objects, i);
        isOwn = (ownElem && objects[i].object == ownElem) ? 1
                                                          : ((!ownElem && i == ownIndex) ? 1 : 0);

        t_pl_x[t_pl_n] = objects[i].x;
        t_pl_y[t_pl_n] = objects[i].y;
        t_pl_team[t_pl_n] = team;
        t_pl_mine[t_pl_n] = isOwn;
        t_pl_n++;

        if (isOwn) {
            t_own_x = objects[i].x;
            t_own_y = objects[i].y;

            continue;
        }

        for (h = 0; h < hn; h++) {
            if (hist[h] == team) break;
        }

        if (h == hn && hn < TNX_PLAYER_MAX) {
            hist[hn++] = team;
        }

        if (team != ownTeam) continue;

        ownSide++;

        if (t_mate_n >= TNX_MATE_MAX) continue;

        t_mate_x[t_mate_n] = objects[i].x;
        t_mate_y[t_mate_n] = objects[i].y;
        t_mate_n++;
    }

    ownSide++;

    if (t_pl_n >= 4 && (ownSide > (t_pl_n / 2) || hn < 2)) {
        t_team_trust = 0;
        t_mate_n = 0;
    }

    {
        int ownSpawn = -1;
        int k = 0;

        for (k = 0; k < t_pl_n; k++) {
            if (t_pl_mine[k]) { ownSpawn = k; break; }
        }

        t_mates = 0;
        t_enemies = 0;

        if (ownSpawn >= 0) {
            for (k = 0; k < t_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (t_pl_mine[k]) continue;

                dx = (float)(t_pl_x[k] - t_pl_x[ownSpawn]);
                dy = (float)(t_pl_y[k] - t_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_CLUSTER) t_mates++;
                else t_enemies++;
            }
        }

        {
            int same = 1;

            for (k = 1; k < t_pl_n; k++) {
                if (t_pl_team[k] != t_pl_team[0]) same = 0;
            }

            if (t_pl_n > 1 && same && t_team_trust) {
                t_team_trust = 0;

            }
        }

        if (!t_team_trust) {
            int m = 0;
            int e = 0;

            t_mate_n = 0;
            t_enemy_n = 0;

            for (k = 0; k < t_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (t_pl_mine[k]) continue;

                dx = (float)(t_pl_x[k] - t_pl_x[ownSpawn]);
                dy = (float)(t_pl_y[k] - t_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_CLUSTER) {
                    if (m < TNX_MATE_MAX) {
                        t_mate_x[m] = t_pl_x[k];
                        t_mate_y[m] = t_pl_y[k];
                        m++;
                    }
                } else if (e < TNX_PLAYER_MAX) {
                    t_enemy_x[e] = t_pl_x[k];
                    t_enemy_y[e] = t_pl_y[k];
                    e++;
                }
            }

            t_mate_n = m;
            t_enemy_n = e;

        }
    }

    if (t_team_trust) {
        for (i = 0; i < t_pl_n && t_enemy_n < TNX_PLAYER_MAX; i++) {
            if (t_pl_mine[i]) continue;
            if (t_pl_team[i] == ownTeam) continue;

            t_enemy_x[t_enemy_n] = t_pl_x[i];
            t_enemy_y[t_enemy_n] = t_pl_y[i];
            t_enemy_n++;
        }
    }

    t_agree = (t_mates == t_mate_n && t_enemies == t_enemy_n) ? 1 : 0;


}

int t_cand_frame[TNX_CAND];

int t_cand_changes[TNX_CAND];

int t_dead_slot = -1;

int t_dead_value = 0;

int t_pending = 0;

int t_pending_tick = 0;

int t_pre[TNX_CAND];

int t_prev_valid = 0;

int t_respawn_tick = 0;


void tnx_clear_life(void) {
    t_stage = 0;
    t_active = 0;
    t_last_write_ms = 0;
    t_issued = 0;
    t_moving = 0;
    t_hold = 0;
    t_stick_hold = 0;
    t_stick_x = 0;
    t_stick_y = 0;
    t_prev_valid = 0;
}

int tnx_life(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    int i = 0;
    int changed = 0;
    int deadNow = 0;

    tnx_candidates(ownElem, t_cand_now);

    if (t_cand_seen) {
        for (i = 0; i < TNX_CAND; i++) {
            if (t_cand_now[i] != t_cand_frame[i]) {
                changed = 1;

                if (t_cand_changes[i] < 1000000) t_cand_changes[i]++;
            }
        }

    }

    for (i = 0; i < TNX_CAND; i++) t_cand_frame[i] = t_cand_now[i];
    t_cand_seen = 1;

    if (t_pending && ((int)t_ticks_a - t_pending_tick) >= TNX_HOLD_FRAMES) {
        int bestSlot = -1;
        int bestChanges = 0;

        t_pending = 0;

        for (i = 0; i < TNX_CAND; i++) {
            if (t_pre[i] < 0 || t_cand_now[i] < 0) continue;
            if (t_cand_now[i] == t_pre[i]) continue;
            if (bestSlot < 0 || t_cand_changes[i] < bestChanges) {
                bestSlot = i;
                bestChanges = t_cand_changes[i];
            }
        }

        if (bestSlot >= 0) {
            t_dead_slot = bestSlot;
            t_dead_value = t_pre[bestSlot];

        }
    }

    if (t_prev_valid && tnx_own_ok(ownX, ownY) &&
        tnx_own_ok(t_prev_x, t_prev_y)) {
        int64_t jx = (int64_t)ownX - (int64_t)t_prev_x;
        int64_t jy = (int64_t)ownY - (int64_t)t_prev_y;

        if (jx * jx + jy * jy >= (int64_t)TNX_RESPAWN_JUMP * TNX_RESPAWN_JUMP) {
            tnx_respawn_event(ownX, ownY, t_prev_x, t_prev_y);
        }
    }

    t_prev_x = ownX;
    t_prev_y = ownY;
    t_prev_valid = 1;

    if (t_state == TNX_STATE_INIT) t_state = TNX_STATE_ALIVE;

    if (t_dead_slot >= 0 &&
        t_cand_now[t_dead_slot] == t_dead_value) deadNow = 1;

    if (deadNow) {
        if (t_state != TNX_STATE_DEAD) {
            t_state = TNX_STATE_DEAD;

        }

        return 1;
    }

    if (t_state == TNX_STATE_DEAD) {
        tnx_clear_life();

        t_state = TNX_STATE_ALIVE;


        return 0;
    }

    if (t_state == TNX_STATE_RESPAWN &&
        ((int)t_ticks_a - t_respawn_tick) < TNX_RESPAWN_VISIBLE) {
        return 0;
    }

    t_state = TNX_STATE_ALIVE;

    return 0;
}

int tnx_resolve_own(const tnx_obj_t *objects, int usable, int *indexOut,
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


        if (tnx_own_by_min_gid(t_tick_array, t_tick_count, &minOwn, &minGid) &&
            minOwn) {
            for (i = 0; i < usable; i++) {
                if (objects[i].object != minOwn) continue;

                if (indexOut) *indexOut = i;
                if (fromOut) *fromOut = "v134-min";

                return 1;
            }
        }
    }

    if (tnx_own_from_slot(&slotOwn, &slotGid) && slotOwn) {
        for (i = 0; i < usable; i++) {
            if (objects[i].object != slotOwn) continue;
            if (objects[i].gid < TNX_GID_FLOOR || objects[i].gid >= TNX_GID_MAX) continue;

            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-slot";

            return 1;
        }
    }

    if (t_own_gid > 0) {
        wantGid = t_own_gid;
    } else if (slotGid > 0) {
        wantGid = slotGid;
    } else if (t_own_ptr_a) {
        wantGid = tnx_gid((uintptr_t)t_own_ptr_a, NULL);
    }

    for (i = 0; i < usable; i++) {
        if (objects[i].x <= -TNX_COORD_MAX || objects[i].x >= TNX_COORD_MAX) continue;
        if (objects[i].y <= -TNX_COORD_MAX || objects[i].y >= TNX_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        if (wantGid > 0 && objects[i].gid == wantGid) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-gid";


            return 1;
        }
    }

    if (tnx_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    hasWit = tnx_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {

        return 0;
    }

    for (i = 0; i < usable; i++) {
        int64_t dx = 0;
        int64_t dy = 0;
        int64_t d = 0;

        if (objects[i].x <= -TNX_COORD_MAX || objects[i].x >= TNX_COORD_MAX) continue;
        if (objects[i].y <= -TNX_COORD_MAX || objects[i].y >= TNX_COORD_MAX) continue;
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

uintptr_t t_own_ptr_a = 0;



const char *t_own_from_a = "none";

uintptr_t t_own_ptr_b = 0;

int t_own_index_3 = -1;

void tnx_own_dump(uintptr_t element) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int i;

    if (!element || t_dump_done) return;

    t_dump_done = 1;

    if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - t_base;


    for (i = 0; i < 13; i++) {
        uint64_t q = tnx_word_2(element + (uintptr_t)i * 8ULL);
        uint32_t lo = (uint32_t)(q & 0xffffffffULL);
        uint32_t hi = (uint32_t)(q >> 32);
        float loF = 0.0f;
        float hiF = 0.0f;

        memcpy(&loF, &lo, sizeof(loF));
        memcpy(&hiF, &hi, sizeof(hiF));

    }

}

int tnx_own_verdict(uintptr_t element, char *why, size_t whyLen) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int32_t gid = 0;
    int32_t x = 0;
    int32_t y = 0;
    int32_t teamOld = 0;
    int32_t teamNew = 0;
    uint8_t dead = 0;

    if (why) why[0] = 0;
    if (!element) {
        if (why) snprintf(why, whyLen, "null");
        return 0;
    }

    if (tnx_element_ascii(element)) {
        if (why) snprintf(why, whyLen, "ascii");
        return 0;
    }

    if (!tnx_read_ptr(element, &vtable) || !vtable) {
        if (why) snprintf(why, whyLen, "noVtRead");
        return 0;
    }

    vtRva = (uintptr_t)vtable - t_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        if (why) snprintf(why, whyLen, "vtOutsideImage vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    gid = tnx_gid(element, NULL);

    if (!tnx_read_int(element + tnx_coord_x_off(), &x) ||
        !tnx_read_int(element + tnx_coord_y_off(), &y) ||
        !tnx_read_int(element + TNX_OBJ_TEAM_OFF, &teamOld) ||
        !tnx_read_int(element + TNX_TEAM_OFF, &teamNew) ||
        !tnx_read_byte(element + TNX_OBJ_DEADFLAG_OFF, &dead)) {
        if (why) snprintf(why, whyLen, "unreadable vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    if (x <= -TNX_COORD_ABS_MAX || x >= TNX_COORD_ABS_MAX ||
        y <= -TNX_COORD_ABS_MAX || y >= TNX_COORD_ABS_MAX) {
        if (why) snprintf(why, whyLen, "coordsOutOfRange gid=%d pos=(%d,%d)", gid, x, y);
        return 0;
    }

    if (why) {
        snprintf(why, whyLen, "ok gid=%d pos=(%d,%d) t40=%d t4c=%d dead=%d gidZeroTaken=%d",
                 gid, x, y, teamOld, teamNew, dead, gid ? 0 : 1);
    }

    return 1;
}

void tnx_own_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    int taken = 0;
    int b;

    cand[0] = (uintptr_t)t_players_object;
    cand[1] = (uintptr_t)t_scene_object;

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
        char why[128];
        int sig = 0;
        int valid = 0;

        if (!cand[b]) continue;

        if (!tnx_read_ptr(cand[b] + TNX_ARRAY_OFF, &array) || !array) {
            continue;
        }

        if (!tnx_read_int(cand[b] + TNX_COUNT_OFF, &count)) count = 0;
        if (!tnx_read_int(cand[b] + TNX_OWNIDX_OFF_2, &idx)) idx = -1;
        if (!tnx_read_int(cand[b] + TNX_OWNTEAM_OFF_2, &team)) team = -1;

        if (idx >= 0 && count > 0 && idx < count) {
            if (tnx_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &elem) && elem) {
                if (tnx_read_int((uintptr_t)elem + TNX_ELEM_ID_OFF_2, &eid) &&
                    tnx_read_int((uintptr_t)elem + TNX_ELEM_TEAM_OFF_2, &eteam)) {
                    elemGid = tnx_gid((uintptr_t)elem, &gidOff);

                    if (eid == idx && eid != 0) {
                        sig = 1;
                        sigField = (const char *)"idAt48";
                    } else if (team >= 0 && team <= TNX_OBJ_TEAM_MAX && eteam == team) {
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

        if (sig) valid = tnx_own_verdict((uintptr_t)elem, why, sizeof(why));
        else snprintf(why, sizeof(why), "noSignature idx=%d eid=%d ownTeam=%d elemTeam=%d",
                      idx, eid, team, eteam);


        if (sig && valid && !taken) {
            taken = 1;
            t_own_ptr_a = (uintptr_t)elem;
            t_own_from_a = (b == 0) ? "container+e0" : "scene+e0";

            tnx_own_dump(t_own_ptr_a);
        }
    }

    if (!taken) {
        t_own_ptr_a = 0;
        t_own_from_a = "v102-none";
    }
}
int tnx_own_latch(const tnx_obj_t *objects, int usable, int *indexOut,
                              const char **fromOut) {
    int i = 0;

    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";
    if (!objects || usable <= 0 || !t_own_elem_2) return 0;

    for (i = 0; i < usable; i++) {
        if (objects[i].object != t_own_elem_2) continue;
        if (objects[i].gid < TNX_GID_FLOOR || objects[i].gid >= TNX_PLAYER_GID_MAX) return 0;
        if (objects[i].teamOld < 0 || objects[i].teamOld > TNX_TEAM_MAX_2) return 0;

        if (indexOut) *indexOut = i;
        if (fromOut) *fromOut = "latched";

        return 1;
    }

    return 0;
}
uintptr_t t_own_elem = 0;

uint64_t t_own_stamp = 0;

uintptr_t tnx_own_obj(void) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (t_own_elem) {
        if (tnx_cand_ok(t_own_elem, &why, &vt)) {
            t_own_from_b = (t_own_stamp == t_tick_stamp) ? "published" : "published-old";

            return t_own_elem;
        }

    }

    {
        uintptr_t cand = tnx_hop((uintptr_t)t_scene_object, NULL);

        if (cand && tnx_cand_ok(cand, NULL, &vt)) {
            t_own_from_b = "engine-chain";

            return cand;
        }

        cand = tnx_hop((uintptr_t)t_players_object, NULL);

        if (cand && tnx_cand_ok(cand, NULL, &vt)) {
            t_own_from_b = "players-chain";

            return cand;
        }
    }

    t_own_from_b = "none";

    return 0;
}

int32_t t_own_gid = 0;

int tnx_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut,
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

        if (!tnx_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        gid = tnx_gid((uintptr_t)element, NULL);

        if (gid < TNX_GID_FLOOR || gid >= TNX_PLAYER_GID_MAX) continue;
        if (!tnx_read_int((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team)) continue;
        if (team < 0 || team > TNX_TEAM_MAX_2) continue;

        if (!best || gid < bestGid) {
            best = (uintptr_t)element;
            bestGid = gid;
        }
    }

    if (!best) {
        return 0;
    }

    t_own_gid = bestGid;

    if (elemOut) *elemOut = best;
    if (gidOut) *gidOut = bestGid;

    return 1;
}

int tnx_own_from_list(const tnx_obj_t *objects, int usable, int *indexOut,
                                  const char **fromOut) {
    int best = -1;
    int32_t bestGid = 0;
    int accepted = 0;
    int i;

    if (indexOut) *indexOut = -1;
    if (!objects || usable <= 0) return 0;

    for (i = 0; i < usable; i++) {
        int32_t gid = objects[i].gid;

        if (gid < TNX_GID_FLOOR || gid >= TNX_PLAYER_GID_MAX) continue;
        if (objects[i].teamOld < 0 || objects[i].teamOld > TNX_TEAM_MAX_2) continue;

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

int tnx_own_scan(void) {
    uintptr_t bases[TNX_SCAN_BASES];
    const char *names[TNX_SCAN_BASES] = { "mode", "client", "inputMgr" };
    uintptr_t array = t_players_array;
    int32_t count = t_players_count;
    uintptr_t client = 0;
    uintptr_t inputMgr = 0;
    void *chain = NULL;
    void *input = NULL;
    int found = 0;

    if (!t_scene_object) return 0;
    if (!array || count <= 0) return 0;

    bases[0] = t_scene_object;

    if (tnx_read_ptr(t_scene_object + TNX_MODE_MANAGER_OFF, &chain) && chain) {
        client = (uintptr_t)chain;
    }

    if (tnx_read_ptr(t_scene_object + TNX_MODE_INPUTMGR_OFF, &input) && input) {
        inputMgr = (uintptr_t)input;
    }

    bases[1] = client;
    bases[2] = inputMgr;

    tnx_own_index_probe();

    tnx_own_probe();


    if (!t_setpred) t_setpred = tnx_entry(TNX_MODEPAIRSET_RVA);


    for (int b = 0; b < TNX_SCAN_BASES; b++) {
        if (!bases[b]) continue;

        for (int i = 0; i < TNX_SCAN_QWORDS; i++) {
            uintptr_t off = (uintptr_t)i * 8ULL;
            uintptr_t value = (uintptr_t)tnx_word_2(bases[b] + off);
            uintptr_t index = 0;

            if (!value) continue;
            if (value <= array) continue;
            if (value >= array + (uintptr_t)count * 8ULL) continue;
            if ((value - array) % 8ULL) continue;

            index = (value - array) / 8ULL;

            if (!found) {
                t_own_ptr_b = value;
                t_own_index_3 = (int)index;
                found = 1;
            }

        }
    }

    if (!found && t_scan_container != (uintptr_t)array) {
        t_scan_container = (uintptr_t)array;

    }

    if (!t_find_joy_done) {
        t_find_joy_done = 1;

    }

    return found;
}

int tnx_resolve_own_2(const tnx_obj_t *objects, int usable, int *indexOut,
                               const char **fromOut) {
    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    if (t_own_index >= 0 && t_own_ptr) {
        int seen = 0;
        int i;

        for (i = 0; i < usable; i++) {
            if (objects[i].object == t_own_ptr) {
                seen = 1;
                break;
            }
        }

        if (seen) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = t_own_from;

            return 1;
        }

    }

    if (t_own_index_3 >= 0 && t_own_index_3 < usable &&
        objects[t_own_index_3].object == t_own_ptr_b) {
        if (indexOut) *indexOut = t_own_index_3;
        if (fromOut) *fromOut = "scan";

        return 1;
    }

    return 0;
}

int tnx_own(int32_t *xOut, int32_t *yOut) {
    uintptr_t own = t_own_elem_2;

    if (!own) own = (uintptr_t)t_own_elem;
    if (!own) return 0;
    if (!tnx_read_int(own + TNX_OBJ_X_OFF, xOut)) return 0;
    if (!tnx_read_int(own + TNX_OBJ_Y_OFF, yOut)) return 0;

    return 1;
}

int tnx_object_live(uintptr_t object) {
    int32_t gid = 0;
    int32_t team = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_gameobject_shape(object)) return 0;
    if (!tnx_read_int(object + TNX_OBJ_GLOBALID_OFF, &gid)) return 0;
    if (gid <= 0 || gid >= TNX_GID_MAX) return 0;
    if (!tnx_read_int(object + TNX_OBJ_TEAM_OFF, &team)) return 0;
    if (team < 0 || team > TNX_TEAM_MAX_2) return 0;
    if (!tnx_read_int(object + tnx_coord_x_off(), &x)) return 0;
    if (!tnx_read_int(object + tnx_coord_y_off(), &y)) return 0;
    if (x <= -TNX_COORD_MAX || x >= TNX_COORD_MAX) return 0;
    if (y <= -TNX_COORD_MAX || y >= TNX_COORD_MAX) return 0;

    return 1;
}

void tnx_candidates(uintptr_t ownElem, int *out) {
    uint8_t deadByte = 0;
    int32_t ownAlive = -1;
    int32_t ctrlAlive = -1;
    uintptr_t ctrl = tnx_controller();

    out[0] = -1;
    out[1] = -1;
    out[2] = -1;

    if (ownElem && tnx_read_bytes(ownElem + TNX_DEAD_OFF, &deadByte, sizeof(deadByte))) {
        out[0] = (int)deadByte;
    }

    if (ownElem && tnx_read_int(ownElem + TNX_OWN_ALIVE_OFF, &ownAlive)) out[1] = (int)ownAlive;

    if (ctrl && tnx_read_int(ctrl + TNX_CTRL_ALIVE_OFF, &ctrlAlive)) out[2] = (int)ctrlAlive;
}

int t_own_x = 0;

int t_own_y = 0;
