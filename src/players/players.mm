#include "recoil.h"

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

        if (hit) {
            if (rcl_read_int((uintptr_t)elem + RCL_ELEM_ID_OFF, &eid) &&
                rcl_read_int((uintptr_t)elem + RCL_ELEM_TEAM_OFF, &eteam)) {
                rcl_own_idhit = (eid == idx) ? 1 : 0;
            }
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

void rcl_own_dump(uintptr_t element) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int i;

    if (!element || rcl_dump_done) return;

    rcl_dump_done = 1;

    if (rcl_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - rcl_base;


    for (i = 0; i < 13; i++) {
        uint64_t q = rcl_word_2(element + (uintptr_t)i * 8ULL);
        uint32_t lo = (uint32_t)(q & 0xffffffffULL);
        uint32_t hi = (uint32_t)(q >> 32);
        float loF = 0.0f;
        float hiF = 0.0f;

        memcpy(&loF, &lo, sizeof(loF));
        memcpy(&hiF, &hi, sizeof(hiF));

    }

}

int rcl_own_verdict(uintptr_t element, char *why, size_t whyLen) {
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

    if (rcl_element_ascii(element)) {
        if (why) snprintf(why, whyLen, "ascii");
        return 0;
    }

    if (!rcl_read_ptr(element, &vtable) || !vtable) {
        if (why) snprintf(why, whyLen, "noVtRead");
        return 0;
    }

    vtRva = (uintptr_t)vtable - rcl_base;

    if (vtRva < RCL_DC_RVA_LO || vtRva >= RCL_DC_RVA_LO + RCL_DC_RVA_SIZE) {
        if (why) snprintf(why, whyLen, "vtOutsideImage vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    gid = rcl_gid(element, NULL);

    if (!rcl_read_int(element + rcl_coord_x_off(), &x) ||
        !rcl_read_int(element + rcl_coord_y_off(), &y) ||
        !rcl_read_int(element + RCL_OBJ_TEAM_OFF, &teamOld) ||
        !rcl_read_int(element + RCL_TEAM_OFF, &teamNew) ||
        !rcl_read_byte(element + RCL_OBJ_DEADFLAG_OFF, &dead)) {
        if (why) snprintf(why, whyLen, "unreadable vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    if (x <= -RCL_COORD_ABS_MAX || x >= RCL_COORD_ABS_MAX ||
        y <= -RCL_COORD_ABS_MAX || y >= RCL_COORD_ABS_MAX) {
        if (why) snprintf(why, whyLen, "coordsOutOfRange gid=%d pos=(%d,%d)", gid, x, y);
        return 0;
    }

    if (why) {
        snprintf(why, whyLen, "ok gid=%d pos=(%d,%d) t40=%d t4c=%d dead=%d gidZeroTaken=%d",
                 gid, x, y, teamOld, teamNew, dead, gid ? 0 : 1);
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
        char why[128];
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

        if (sig) valid = rcl_own_verdict((uintptr_t)elem, why, sizeof(why));
        else snprintf(why, sizeof(why), "noSignature idx=%d eid=%d ownTeam=%d elemTeam=%d",
                      idx, eid, team, eteam);


        if (sig && valid && !taken) {
            taken = 1;
            rcl_own_ptr_a = (uintptr_t)elem;
            rcl_own_from_a = (b == 0) ? "container+e0" : "scene+e0";

            rcl_own_dump(rcl_own_ptr_a);
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
