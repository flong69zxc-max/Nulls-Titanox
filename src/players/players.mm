#include "titanox.h"

int tnx_team_at(const tnx_obj_t *objects, int index) {
    if (!objects || index < 0) return -1;

    return (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[index].teamOld
                                                     : objects[index].teamNew;
}

int tnx_own_ok(int32_t x, int32_t y) {
    if (x == 0 && y == 0) return 0;
    if (x < -100000 || x > 100000) return 0;
    if (y < -100000 || y > 100000) return 0;

    return 1;
}

float tnx_own_radius(void) {
    if (!TNX_GEOM) return 0.0f;
    if (g_own_r > 1.0f) return g_own_r;

    if (g_own_r_cfg_logs < 4) {
        g_own_r_cfg_logs++;

        TNX_LOGX("own radius cfg=%.0f - the contact average has not produced a value yet, so the hit "
                 "test uses the radius taken from the character table instead of zero: the table gives "
                 "120 for 101 of 127 heroes and 145 for 20, and a zero here makes every shot pass at a "
                 "distance no smaller than the shot itself",
                 (double)TNX_DATA_OWN_R);
    }

    return TNX_DATA_OWN_R;
}

int tnx_own_side_spawn(int32_t sx, int32_t sy) {
    int i = 0;
    int best = -1;
    float bestD = 0.0f;
    float secondD = -1.0f;

    if (g_own_team_4 < 0) return -1;
    if (g_pl_n <= 0) return -1;

    for (i = 0; i < g_pl_n; i++) {
        float dx = (float)sx - (float)g_pl_x[i];
        float dy = (float)sy - (float)g_pl_y[i];
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
    if (bestD > TNX_ATTRIB_R2) return -1;
    if (secondD >= 0.0f && bestD * TNX_ATTRIB_MARGIN > secondD) return -1;

    return (g_pl_team[best] == g_own_team_4) ? 1 : 0;
}

int tnx_enemy_blocked(float x, float y, float ownX, float ownY) {
    int i = 0;

    if (!g_team_trust || g_enemy_n <= 0) return 0;

    for (i = 0; i < g_enemy_n; i++) {
        float ex = (float)g_enemy_x[i];
        float ey = (float)g_enemy_y[i];
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

    if (!g_team_trust) return 0;
    if (g_mate_n <= 0) return 0;

    for (i = 0; i < g_mate_n; i++) {
        float dx = x - (float)g_mate_x[i];
        float dy = y - (float)g_mate_y[i];

        if (dx * dx + dy * dy <= r2) return 1;
    }

    return 0;
}

int tnx_side_near(float px, float py) {
    int i = 0;
    int near = -1;
    float nd = 1.0e9f;

    for (i = 0; i < g_seg_count; i++) {
        float c = tnx_clear_at(px, py, i);

        if (c < nd) {
            nd = c;
            near = i;
        }
    }

    return near;
}

float tnx_side_score(float px, float py, float x, float y, int near) {
    int i = 0;
    float s = 0.0f;
    float own = sqrtf((x - px) * (x - px) + (y - py) * (y - py));

    for (i = 0; i < g_seg_count; i++) {
        float c = tnx_clear_at(x, y, i);

        if (c < 0.0f) c = c * 4.0f;

        s += ((i == near) ? TNX_SIDE_W_PRIME : TNX_SIDE_W_OTHER) * c;
    }

    s += TNX_SIDE_W_OWN * own;

    return s;
}

int tnx_side_pick(float px, float py, float *outX, float *outY) {
    int near = tnx_side_near(px, py);
    float nx = 0.0f;
    float ny = 0.0f;
    float dx = 0.0f;
    float dy = 0.0f;
    float dl = 0.0f;
    float dist = TNX_DODGE_DIST;
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float sa = 0.0f;
    float sb = 0.0f;
    float toShot = 0.0f;
    float adaptive = 0.0f;

    if (near < 0) return 0;

    nx = g_seg[near].ax;
    ny = g_seg[near].ay;
    dx = g_seg[near].bx - nx;
    dy = g_seg[near].by - ny;
    dl = sqrtf(dx * dx + dy * dy);

    if (dl < 1.0f) return 0;

    dx /= dl;
    dy /= dl;

    toShot = sqrtf((nx - px) * (nx - px) + (ny - py) * (ny - py));
    adaptive = toShot * TNX_DIST_FACTOR;

    if (adaptive > 1.0f && adaptive < dist) dist = adaptive;
    if (dist < TNX_STEP) dist = TNX_STEP;

    ax = px - dy * dist;
    ay = py + dx * dist;
    bx = px + dy * dist;
    by = py - dx * dist;

    {
        int c = tnx_key_c(g_seg_count);
        int t = tnx_key_t(g_tti_min);

        sa = tnx_valid_point(ax, ay) ? tnx_side_score(px, py, ax, ay, near) : -1.0e9f;
        sb = tnx_valid_point(bx, by) ? tnx_side_score(px, py, bx, by, near) : -1.0e9f;

        sa += TNX_LEARN_W * (tnx_learn_rate(c, t, 0) - 0.5f);
        sb += TNX_LEARN_W * (tnx_learn_rate(c, t, 1) - 0.5f);

        {
            int stale = 0;

            if (TNX_SIDE_FLIP && g_side_tick != 0 &&
                (g_ticks_3 - (uint64_t)g_side_tick) > (uint64_t)TNX_SIDE_STALE) stale = 1;

            if (stale) {
                g_side_flips++;

                if (g_side_last == 0 && sb > -1.0e8f) sb += TNX_LEARN_W * TNX_SIDE_MARGIN;
                if (g_side_last == 1 && sa > -1.0e8f) sa += TNX_LEARN_W * TNX_SIDE_MARGIN;
            } else {
                if (g_side_last == 0 && sa > -1.0e8f) sa += TNX_LEARN_W * TNX_SIDE_MARGIN;
                if (g_side_last == 1 && sb > -1.0e8f) sb += TNX_LEARN_W * TNX_SIDE_MARGIN;
            }
        }

        if (sa < -1.0e8f && sb < -1.0e8f) return 0;

        if (sa >= sb) {
            *outX = ax;
            *outY = ay;
            g_side_last = 0;
        } else {
            *outX = bx;
            *outY = by;
            g_side_last = 1;
        }

        g_side_tick = (int)g_ticks_3;
        g_side_picks++;

        g_pick_key_c = c;
        g_pick_key_t = t;
        g_stat_side++;
    }

    return 1;
}

void tnx_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py) {
    int i = 0;

    g_respawns++;
    g_state = TNX_STATE_RESPAWN;
    g_respawn_tick = (int)g_ticks_3;

    tnx_clear_life();

    g_pending = 1;
    g_pending_tick = (int)g_ticks_3;

    for (i = 0; i < TNX_CAND; i++) {
        g_pre[i] = g_cand_frame[i];
        g_cand_changes[i] = 0;
    }

    if (g_life_logs < TNX_LIFE_MAX_LOGS) {
        g_life_logs++;

        TNX_LOGX("RESPAWN #%d own=(%d,%d) from=(%d,%d) jump=%d cand=(%d,%d,%d) learned=%s=%d - "
                 "the character was teleported, which a walk cannot do, so this is the one life "
                 "event established without trusting a flag; the per life state is cleared here and "
                 "the candidates are held for %d frames to see which changed across the event",
                 g_respawns, x, y, px, py,
                 (int)sqrtf((float)((x - px) * (x - px) + (y - py) * (y - py))),
                 g_pre[0], g_pre[1], g_pre[2],
                 tnx_cand_name(g_dead_slot), g_dead_value, TNX_HOLD_FRAMES);
    }
}

void tnx_contact_note(float dist, float projR) {
    float r = dist - projR;

    if (!TNX_GEOM) return;
    if (!tnx_ok(r, 10.0f, TNX_RADIUS_MAX)) return;

    if (g_own_r_n == 0) g_own_r = r;
    else g_own_r = g_own_r * 0.75f + r * 0.25f;

    g_own_r_n++;

    if (g_own_r_logs < TNX_CONTACT_LOGS) {
        g_own_r_logs++;

        TNX_LOGX("contact dist=%.0f projR=%.0f ownR=%.0f n=%d - own took a body while the nearest "
                 "live shot was this far from its centre, so subtracting the projectile radius "
                 "read out of that shot leaves own collision radius: the value kept is an average "
                 "over every contact seen and it is what the hit test inflates with from now on",
                 (double)dist, (double)projR, (double)g_own_r, g_own_r_n);
    }
}

uintptr_t g_own_ptr = 0;

int g_own_index = -1;

int g_own_logs = 0;

const char *g_own_from = "none";

uint64_t g_tick_stamp = 0;

void tnx_own_index_probe(void) {
    uintptr_t cand[2];
    static const char *cname[2] = { "container", "scene" };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    int taken = 0;
    int chosen = -1;
    int b;

    if (!array || count <= 0) return;

    cand[0] = (uintptr_t)g_players_object;
    cand[1] = (uintptr_t)g_scene_object;

    for (b = 0; b < 2; b++) {
        int32_t idx = -1;
        int32_t team = -1;
        int32_t eid = 0;
        int32_t eteam = 0;
        void *elem = NULL;
        int hit = 0;

        if (!cand[b]) continue;
        if (!tnx_read_i32(cand[b] + TNX_OWNIDX_OFF, &idx)) continue;

        tnx_read_i32(cand[b] + TNX_OWNTEAM_OFF, &team);

        if (idx >= 0 && idx < count) {
            if (tnx_read_ptr(array + (uintptr_t)idx * 8ULL, &elem) && elem) hit = 1;
        }

        if (hit) {
            if (tnx_read_i32((uintptr_t)elem + TNX_ELEM_ID_OFF, &eid) &&
                tnx_read_i32((uintptr_t)elem + TNX_ELEM_TEAM_OFF, &eteam)) {
                g_own_idhit = (eid == idx) ? 1 : 0;
            }
        }

        if (g_own_logs < TNX_OWN_LOGS) {
            g_own_logs++;

            tnx_logf("own-index base=%-9s at=%p +%#llx=%d +%#llx=%d count=%d array=%p "
                     "elem=%p elem+%#llx=%d elem+%#llx=%d idHit=%d verdict=%s - the class that "
                     "owns the object array keeps the own slot as an int, indexes its own array "
                     "with it and resets it to -1, so no pointer into the array has to exist in "
                     "any field for own to be resolvable",
                     cname[b], (void *)cand[b], (unsigned long long)TNX_OWNIDX_OFF, idx,
                     (unsigned long long)TNX_OWNTEAM_OFF, team, count, (void *)array, elem,
                     (unsigned long long)TNX_ELEM_ID_OFF, eid,
                     (unsigned long long)TNX_ELEM_TEAM_OFF, eteam, g_own_idhit,
                     hit ? "index-taken" : "index-rejected");
        }

        if (hit && !taken) {
            taken = 1;
            chosen = b;
            g_own_index = idx;
            g_own_ptr = (uintptr_t)elem;
            g_own_team = team;
            g_own_from = (b == 0) ? "container+e0" : "scene+e0";
        }
    }

    if (!taken) {
        g_own_index = -1;
        g_own_ptr = 0;
        g_own_from = "index-miss";
    }

}

const char *g_own_from_3 = "none";

void tnx_publish_own(uintptr_t elem, const char *from) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (!tnx_cand_ok(elem, &why, &vt)) {
        if (g_pub_logs_2 < TNX_PUB_LOGS) {
            g_pub_logs_2++;

            tnx_logf("own publish REJECT from=%s elem=%p vt=%p reason=%s - nothing is published, "
                     "so the actuator falls back to the engine chain or skips; a reject here is not "
                     "a v135 failure, it is a tick where the resolver named nothing usable",
                     from ? from : "?", (void *)elem, (void *)vt, why);
        }

        return;
    }

    g_own_elem = elem;
    g_own_stamp = g_tick_stamp;
    g_own_from_3 = from ? from : "?";

    if (g_pub_logs_2 < TNX_PUB_LOGS) {
        uintptr_t cls = (vt >= g_base) ? (vt - g_base) : 0;

        g_pub_logs_2++;

        tnx_logf("own publish from=%s elem=%p vt=%p classRva=%#llx stamp=%llu - classRva is the "
                 "value to line up against the census classRva of the same element index; the guard "
                 "accepts on aligned+readable+vtable-in-__DATA_CONST and this line names the class "
                 "that passed it", from ? from : "?", (void *)elem, (void *)vt,
                 (unsigned long long)cls, (unsigned long long)g_own_stamp);
    }
}

int32_t g_own_slot_idx = -1;

int tnx_container_has(uintptr_t container, uintptr_t own) {
    void *array = NULL;
    int32_t count = 0;
    int i;

    if (!container || !own) return -1;
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > TNX_COUNT_MAX) return -1;

    for (i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        if ((uintptr_t)element == own) return i;
    }

    return -1;
}

int tnx_own_from_slot(uintptr_t *objectOut, int32_t *gidOut) {
    uintptr_t scene = (uintptr_t)g_scene_object;
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
        if (!tnx_read_i32(hop[k] + TNX_OWNIDX_OFF_2, &idx)) continue;
        if (!tnx_read_ptr(hop[k] + TNX_MGR_ARRAY_OFF, &array) || !array) continue;
        if (!tnx_read_i32(hop[k] + TNX_MGR_COUNT_OFF, &count)) continue;
        if (idx < 0 || idx >= count || count <= 0) continue;
        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &element) || !element) continue;

        gid = tnx_gid((uintptr_t)element, NULL);

        if (gid < TNX_GID_FLOOR || gid >= TNX_PLAYER_GID_MAX) {
            if (g_own_slot_logs < TNX_CHAIN_LOGS) {
                g_own_slot_logs++;

                tnx_logf("own-slot REJECT hop=%d container=%p ownIdx+%#llx=%d count=%d elem=%p "
                         "gid=%d window=[%d,%d) - the slot resolves to an element outside the player "
                         "id window, so it is not own and the chain moves on",
                         k, (void *)hop[k], (unsigned long long)TNX_OWNIDX_OFF_2, idx, count,
                         element, gid, TNX_GID_FLOOR, TNX_PLAYER_GID_MAX);
            }

            continue;
        }

        if (g_own_slot_logs < TNX_CHAIN_LOGS) {
            g_own_slot_logs++;

            tnx_logf("own-slot hop=%d container=%p ownIdx+%#llx=%d count=%d elem=%p gid=%d "
                     "expect=%d match=%d - own is taken from the slot the engine itself indexes, the "
                     "same field the hop used to be judged on, so a list whose own slot is the index "
                     "\"1\" and whose element carries gid %d names own without any proximity guess",
                     k, (void *)hop[k], (unsigned long long)TNX_OWNIDX_OFF_2, idx, count, element,
                     gid, TNX_OWN_EXPECT_GID, gid == TNX_OWN_EXPECT_GID,
                     TNX_OWN_EXPECT_GID);
        }

        g_own_slot = (uintptr_t)element;
        g_own_slot_idx = idx;
        g_own_slot_gid = gid;
        g_own_slot_ok = 1;

        if (objectOut) *objectOut = (uintptr_t)element;
        if (gidOut) *gidOut = gid;

        return 1;
    }

    return 0;
}

uintptr_t g_players_object = 0;

uintptr_t g_players_array = 0;

int g_players_count = 0;

uintptr_t g_own_elem_2 = 0;

int g_state = TNX_STATE_INIT;

int g_pl_n = 0;

int32_t g_pl_x[TNX_PLAYER_MAX];

int32_t g_pl_y[TNX_PLAYER_MAX];

int32_t g_pl_team[TNX_PLAYER_MAX];

int g_mate_n = 0;

int32_t g_mate_x[TNX_MATE_MAX];

int32_t g_mate_y[TNX_MATE_MAX];

int g_own_team_4 = -1;

int g_team_trust = 1;

int32_t g_enemy_x[TNX_PLAYER_MAX];

int32_t g_enemy_y[TNX_PLAYER_MAX];

int g_enemy_n = 0;

void tnx_roster(uintptr_t ownElem, int ownIndex, int ownTeam,
                            const tnx_obj_t *objects, int usable) {
    int i = 0;
    int matesBefore = g_mate_n;
    int ownSide = 0;
    int hist[TNX_PLAYER_MAX];
    int hn = 0;

    g_pl_n = 0;
    g_mate_n = 0;
    g_enemy_n = 0;
    g_own_team_4 = ownTeam;
    g_own_team_5 = ownTeam;
    g_team_trust = 1;

    for (i = 0; i < usable && g_pl_n < TNX_PLAYER_MAX; i++) {
        int32_t team = 0;
        int isOwn = 0;
        int h = 0;

        if (objects[i].gid < TNX_PLAYER_GID) continue;
        if (objects[i].gid >= TNX_SHOT_GID) continue;

        team = tnx_team_at(objects, i);
        isOwn = (ownElem && objects[i].object == ownElem) ? 1
                                                          : ((!ownElem && i == ownIndex) ? 1 : 0);

        g_pl_x[g_pl_n] = objects[i].x;
        g_pl_y[g_pl_n] = objects[i].y;
        g_pl_team[g_pl_n] = team;
        g_pl_mine[g_pl_n] = isOwn;
        g_pl_gid[g_pl_n] = objects[i].gid;
        g_pl_sx[g_pl_n] = objects[i].x;
        g_pl_sy[g_pl_n] = objects[i].y;
        g_pl_spawned[g_pl_n] = 0;
        g_pl_n++;

        if (isOwn) {
            g_own_x = objects[i].x;
            g_own_y = objects[i].y;

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

        if (g_mate_n >= TNX_MATE_MAX) continue;

        g_mate_x[g_mate_n] = objects[i].x;
        g_mate_y[g_mate_n] = objects[i].y;
        g_mate_n++;
    }

    ownSide++;

    if (g_pl_n >= 4 && (ownSide > (g_pl_n / 2) || hn < 2)) {
        g_team_trust = 0;
        g_mate_n = 0;
    }

    {
        int ownSpawn = -1;
        int k = 0;

        for (k = 0; k < g_pl_n; k++) {
            if (g_pl_mine[k]) { ownSpawn = k; break; }
        }

        g_mates = 0;
        g_enemies = 0;

        if (ownSpawn >= 0) {
            for (k = 0; k < g_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (g_pl_mine[k]) continue;

                dx = (float)(g_pl_x[k] - g_pl_x[ownSpawn]);
                dy = (float)(g_pl_y[k] - g_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_CLUSTER) g_mates++;
                else g_enemies++;
            }
        }

        {
            int same = 1;

            for (k = 1; k < g_pl_n; k++) {
                if (g_pl_team[k] != g_pl_team[0]) same = 0;
            }

            if (g_pl_n > 1 && same && g_team_trust) {
                g_team_trust = 0;

                if (g_roster_logs < TNX_TEAM_LOGS) {
                    TNX_LOGX("teambyte players=%d value=%d same=%d trust=%d - every player carries "
                             "the same team byte, so that field holds no side information in this "
                             "mode and one player being read as a mate is not evidence of anything; "
                             "the byte is dropped and the side is taken from the spawn cluster "
                             "instead, which is the same rule the byte-only path uses when it "
                             "already distrusts itself",
                             g_pl_n, g_pl_team[0], same, g_team_trust);
                }
            }
        }

        if (!g_team_trust) {
            int m = 0;
            int e = 0;

            g_mate_n = 0;
            g_enemy_n = 0;

            for (k = 0; k < g_pl_n; k++) {
                float dx = 0.0f;
                float dy = 0.0f;

                if (g_pl_mine[k]) continue;

                dx = (float)(g_pl_x[k] - g_pl_x[ownSpawn]);
                dy = (float)(g_pl_y[k] - g_pl_y[ownSpawn]);

                if (sqrtf(dx * dx + dy * dy) <= TNX_CLUSTER) {
                    if (m < TNX_MATE_MAX) {
                        g_mate_x[m] = g_pl_x[k];
                        g_mate_y[m] = g_pl_y[k];
                        m++;
                    }
                } else if (e < TNX_PLAYER_MAX) {
                    g_enemy_x[e] = g_pl_x[k];
                    g_enemy_y[e] = g_pl_y[k];
                    e++;
                }
            }

            g_mate_n = m;
            g_enemy_n = e;

            if (g_cluster_logs < TNX_TRUST_LOGS) {
                g_cluster_logs++;

                TNX_LOGX("side by cluster players=%d ownSpawn=(%d,%d) mates=%d enemies=%d "
                         "byteMates=%d byteEnemies=%d radius=%.0f - the team byte is not believed, so "
                         "the side comes from where the players came from: a team spawns together and "
                         "the two spawn areas are far apart, which is a signal that does not depend on "
                         "a field the engine may not even set in this mode",
                         g_pl_n, g_pl_x[ownSpawn], g_pl_y[ownSpawn], m, e,
                         ownSide - 1, g_pl_n - ownSide, (double)TNX_CLUSTER);
            }
        } else if (g_cluster_logs < TNX_TRUST_LOGS) {
            g_cluster_logs++;

            TNX_LOGX("side agreement byte=%d/%d cluster=%d/%d agree=%d players=%d - both answers "
                     "are printed every time the roster changes, so a byte that drifts and a cluster "
                     "that misreads are told apart instead of guessed at", g_mate_n,
                     g_enemy_n, g_mates, g_enemies, g_agree, g_pl_n);
        }
    }

    if (g_team_trust) {
        for (i = 0; i < g_pl_n && g_enemy_n < TNX_PLAYER_MAX; i++) {
            if (g_pl_mine[i]) continue;
            if (g_pl_team[i] == ownTeam) continue;

            g_enemy_x[g_enemy_n] = g_pl_x[i];
            g_enemy_y[g_enemy_n] = g_pl_y[i];
            g_enemy_n++;
        }
    }

    g_agree = (g_mates == g_mate_n && g_enemies == g_enemy_n) ? 1 : 0;

    if (g_mate_n != matesBefore || g_roster_logs < TNX_ROSTER_LOGS) {
        g_roster_logs++;

        TNX_LOGX("roster players=%d mates=%d enemies=%d teams=%d/%d/%d/%d/%d/%d own=(%d,%d) "
                 "ownMatched=%d ownTeam=%d trust=%d blocked=%d - the raw table is printed because "
                 "the previous line printed only the counts and a 3v3 came back as five teammates "
                 "with own at the origin: players=6 mates=5 ownTeam=0 own=(0,0). own is matched by "
                 "element now, and the side is only believed when it is a minority of the container, "
                 "because a team is a minority in a team match; when it is not, trust goes to zero "
                 "and both the mate block and the own shot filter stand down, so a broken team byte "
                 "can no longer leave the ring with only the enemy to run into",
                 g_pl_n, g_mate_n, g_enemy_n,
                 g_pl_team[0], g_pl_team[1], g_pl_team[2], g_pl_team[3],
                 g_pl_team[4], g_pl_team[5], g_own_x, g_own_y,
                 g_pl_mine[0] | g_pl_mine[1] | g_pl_mine[2] | g_pl_mine[3] |
                     g_pl_mine[4] | g_pl_mine[5],
                 g_own_team_5, g_team_trust, g_block_hits);
    }

    if (g_trust_logs < TNX_TRUST_LOGS && !g_team_trust) {
        g_trust_logs++;

        TNX_LOGX("side read distrusted players=%d ownSide=%d distinctTeams=%d - more than half "
                 "of the players came back on own's side, or every player came back on one team, "
                 "which no real match produces; the mate block is off and the own shot filter is off "
                 "until the next roster, so the dodge reacts to every moving shot and refuses no "
                 "ground, instead of refusing all of it", g_pl_n, ownSide, hn);
    }
}

int g_cand_frame[TNX_CAND];

int g_cand_changes[TNX_CAND];

int g_dead_slot = -1;

int g_dead_value = 0;

int g_pending = 0;

int g_pending_tick = 0;

int g_pre[TNX_CAND];

int g_prev_valid = 0;

int g_respawn_tick = 0;

int g_life_logs = 0;

void tnx_clear_life(void) {
    g_stage = 0;
    g_stuck = 0;
    g_active_2 = 0;
    g_prev_idx = -1;
    g_hold_until = 0;
    g_last_danger = 0;
    g_last_write_ms = 0;
    g_issued = 0;
    g_moving = 0;
    g_hold = 0;
    g_stick_hold = 0;
    g_stick_x = 0;
    g_stick_y = 0;
    g_prev_valid = 0;
}

int tnx_life(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    int i = 0;
    int changed = 0;
    int deadNow = 0;

    tnx_candidates(ownElem, g_cand_now);

    if (g_cand_seen) {
        for (i = 0; i < TNX_CAND; i++) {
            if (g_cand_now[i] != g_cand_frame[i]) {
                changed = 1;

                if (g_cand_changes[i] < 1000000) g_cand_changes[i]++;
            }
        }

        if (changed && g_signal_logs_2 < TNX_LIFE_MAX_LOGS) {
            g_signal_logs_2++;

            TNX_LOGX("signals own=(%d,%d) own+d4=%d own+140=%d ctrl+f80=%d learned=%s=%d - "
                     "printed on every change of any candidate, so a run that carries a death names "
                     "the flag even if the respawn learning never fires", ownX, ownY,
                     g_cand_now[0], g_cand_now[1], g_cand_now[2],
                     tnx_cand_name(g_dead_slot), g_dead_value);
        }
    }

    for (i = 0; i < TNX_CAND; i++) g_cand_frame[i] = g_cand_now[i];
    g_cand_seen = 1;

    if (g_pending && ((int)g_ticks_3 - g_pending_tick) >= TNX_HOLD_FRAMES) {
        int bestSlot = -1;
        int bestChanges = 0;

        g_pending = 0;

        for (i = 0; i < TNX_CAND; i++) {
            if (g_pre[i] < 0 || g_cand_now[i] < 0) continue;
            if (g_cand_now[i] == g_pre[i]) continue;
            if (bestSlot < 0 || g_cand_changes[i] < bestChanges) {
                bestSlot = i;
                bestChanges = g_cand_changes[i];
            }
        }

        if (bestSlot >= 0) {
            g_dead_slot = bestSlot;
            g_dead_value = g_pre[bestSlot];

            if (g_learn_logs < TNX_LEARN_LOGS) {
                g_learn_logs++;

                TNX_LOGX("death flag learned slot=%d %s dead=%d alive=%d changes=%d from the "
                         "respawn at tick=%d - this candidate changed across the teleport, held its "
                         "new value for %d frames, and moved %d times in this life, fewer than any "
                         "rival, so it is the flag a guard may use; until this line exists no guard "
                         "runs at all and nothing is held on a guess", bestSlot,
                         tnx_cand_name(bestSlot), g_pre[bestSlot],
                         g_cand_now[bestSlot], bestChanges, g_pending_tick,
                         TNX_HOLD_FRAMES, bestChanges);
            }
        }
    }

    if (g_prev_valid && tnx_own_ok(ownX, ownY) &&
        tnx_own_ok(g_prev_x, g_prev_y)) {
        int64_t jx = (int64_t)ownX - (int64_t)g_prev_x;
        int64_t jy = (int64_t)ownY - (int64_t)g_prev_y;

        if (jx * jx + jy * jy >= (int64_t)TNX_RESPAWN_JUMP * TNX_RESPAWN_JUMP) {
            tnx_respawn_event(ownX, ownY, g_prev_x, g_prev_y);
        }
    }

    g_prev_x = ownX;
    g_prev_y = ownY;
    g_prev_valid = 1;

    if (g_state == TNX_STATE_INIT) g_state = TNX_STATE_ALIVE;

    if (g_dead_slot >= 0 &&
        g_cand_now[g_dead_slot] == g_dead_value) deadNow = 1;

    if (deadNow) {
        if (g_state != TNX_STATE_DEAD) {
            g_state = TNX_STATE_DEAD;

            if (g_life_logs < TNX_LIFE_MAX_LOGS) {
                g_life_logs++;

                TNX_LOGX("own is DEAD own=(%d,%d) %s=%d - the learned flag says so, so the "
                         "dodge is held and nothing is written until it clears; the label carries "
                         "the same state on screen", ownX, ownY, tnx_cand_name(g_dead_slot),
                         g_dead_value);
            }
        }

        return 1;
    }

    if (g_state == TNX_STATE_DEAD) {
        tnx_clear_life();

        g_state = TNX_STATE_ALIVE;

        if (g_life_logs < TNX_LIFE_MAX_LOGS) {
            g_life_logs++;

            TNX_LOGX("own is alive again own=(%d,%d) %s=%d - the learned candidate left its "
                     "dead value, so the dodge resumes on a cleared life and cleared heading", ownX,
                     ownY, tnx_cand_name(g_dead_slot),
                     g_cand_now[g_dead_slot]);
        }

        return 0;
    }

    if (g_state == TNX_STATE_RESPAWN &&
        ((int)g_ticks_3 - g_respawn_tick) < TNX_RESPAWN_VISIBLE) {
        return 0;
    }

    g_state = TNX_STATE_ALIVE;

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

        if (g_score_logs_2 < 8) {
            g_score_logs_2++;

            TNX_LOGX("score enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d",
                     (void *)g_tick_array, g_tick_count, (void *)g_players_array,
                     g_players_count, (void *)g_tick_array, g_tick_count);
        }

        if (tnx_own_by_min_gid(g_tick_array, g_tick_count, &minOwn, &minGid) &&
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

    if (g_own_gid > 0) {
        wantGid = g_own_gid;
    } else if (slotGid > 0) {
        wantGid = slotGid;
    } else if (g_own_ptr_2) {
        wantGid = tnx_gid((uintptr_t)g_own_ptr_2, NULL);
    }

    for (i = 0; i < usable; i++) {
        if (objects[i].x <= -TNX_COORD_MAX || objects[i].x >= TNX_COORD_MAX) continue;
        if (objects[i].y <= -TNX_COORD_MAX || objects[i].y >= TNX_COORD_MAX) continue;
        if (objects[i].x == 0 && objects[i].y == 0) continue;

        if (wantGid > 0 && objects[i].gid == wantGid) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = "v129-gid";

            TNX_LOGX("own-gid idx=%d gid=%d pos=(%d,%d) wantGid=%d slotIdx=%d",
                     i, objects[i].gid, objects[i].x, objects[i].y, wantGid, g_own_slot_idx);

            return 1;
        }
    }

    if (tnx_own_from_list(objects, usable, indexOut, fromOut)) return 1;

    hasWit = tnx_witness(&wx, &wy) && !(wx == 0 && wy == 0);

    if (!hasWit) {
        TNX_LOGX("own-none usable=%d wantGid=%d slotOwn=%p slotIdx=%d interpUnusable=1",
                 usable, wantGid, (void *)slotOwn, g_own_slot_idx);

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

    if (g_own_logs_3 < TNX_OWN_LOGS_2) {
        g_own_logs_3++;

        TNX_LOGX("own-near idx=%d gid=%d pos=(%d,%d) interp=(%d,%d) d2=%lld wantGid=%d",
                 best, objects[best].gid, objects[best].x, objects[best].y, wx, wy, (long long)bestD,
                 wantGid, (unsigned long long)TNX_CLIENT_POS_X_OFF,
                 (unsigned long long)TNX_CLIENT_POS_Y_OFF);
    }

    return 1;
}

uintptr_t g_own_ptr_2 = 0;

int g_own_index_2 = -1;

int g_inject_logs = 0;

const char *g_own_from_2 = "none";

uintptr_t g_own_ptr_4 = 0;

int g_own_index_3 = -1;

void tnx_own_dump(uintptr_t element) {
    void *vtable = NULL;
    uintptr_t vtRva = 0;
    int i;

    if (!element || g_dump_done) return;

    g_dump_done = 1;

    if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - g_base;

    TNX_LOGX("own dump elem=%p vtRva=%#llx - raw qwords of the own element, because this class "
             "keeps its id at +%#llx and not at +%#llx, so the walk can no longer assume that the "
             "coordinate pair sits at +%#llx/+%#llx either; a pair of small integers in the same "
             "neighbourhood is the pair to use",
             (void *)element, (unsigned long long)vtRva,
             (unsigned long long)TNX_GID_FALLBACK_OFF, (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

    for (i = 0; i < 13; i++) {
        uint64_t q = tnx_word_2(element + (uintptr_t)i * 8ULL);
        uint32_t lo = (uint32_t)(q & 0xffffffffULL);
        uint32_t hi = (uint32_t)(q >> 32);
        float loF = 0.0f;
        float hiF = 0.0f;

        memcpy(&loF, &lo, sizeof(loF));
        memcpy(&hiF, &hi, sizeof(hiF));

        TNX_LOGX("own dump +%#04x = %#018llx lo=%d hi=%d loF=%.3f hiF=%.3f", i * 8,
                 (unsigned long long)q, (int32_t)lo, (int32_t)hi, loF, hiF);
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

    vtRva = (uintptr_t)vtable - g_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        if (why) snprintf(why, whyLen, "vtOutsideImage vtRva=%#llx", (unsigned long long)vtRva);
        return 0;
    }

    gid = tnx_gid(element, NULL);

    if (!tnx_read_i32(element + tnx_coord_x_off(), &x) ||
        !tnx_read_i32(element + tnx_coord_y_off(), &y) ||
        !tnx_read_i32(element + TNX_OBJ_TEAM_OFF, &teamOld) ||
        !tnx_read_i32(element + TNX_TEAM_OFF, &teamNew) ||
        !tnx_read_u8(element + TNX_OBJ_DEADFLAG_OFF, &dead)) {
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

    cand[0] = (uintptr_t)g_players_object;
    cand[1] = (uintptr_t)g_scene_object;

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
            if (g_own_logs_2 < 10) {
                g_own_logs_2++;
                TNX_LOGX("own base=%-9s at=%p has no array at +%#llx, the global array is %p "
                         "- the base and the array must come from the same object or an index "
                         "read off one object is applied to the wrong list",
                         cname[b], (void *)cand[b], (unsigned long long)TNX_ARRAY_OFF,
                         (void *)g_players_array);
            }
            continue;
        }

        if (!tnx_read_i32(cand[b] + TNX_COUNT_OFF, &count)) count = 0;
        if (!tnx_read_i32(cand[b] + TNX_OWNIDX_OFF_2, &idx)) idx = -1;
        if (!tnx_read_i32(cand[b] + TNX_OWNTEAM_OFF_2, &team)) team = -1;

        if (idx >= 0 && count > 0 && idx < count) {
            if (tnx_read_ptr((uintptr_t)array + (uintptr_t)idx * 8ULL, &elem) && elem) {
                if (tnx_read_i32((uintptr_t)elem + TNX_ELEM_ID_OFF_2, &eid) &&
                    tnx_read_i32((uintptr_t)elem + TNX_ELEM_TEAM_OFF_2, &eteam)) {
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

        if (g_own_logs_2 < 10) {
            g_own_logs_2++;
            TNX_LOGX("own base=%-9s at=%p count=+%#llx->%d idx=+%#llx->%d ownTeam=+%#llx->%d "
                     "elem=%p elemId=+%#llx->%d elemTeam=+%#llx->%d elemGid=+%#llx->%d sig=%d "
                     "sigField=%s collector=%s",
                     cname[b], (void *)cand[b], (unsigned long long)TNX_COUNT_OFF, count,
                     (unsigned long long)TNX_OWNIDX_OFF_2, idx,
                     (unsigned long long)TNX_OWNTEAM_OFF_2, team, elem,
                     (unsigned long long)TNX_ELEM_ID_OFF_2, eid,
                     (unsigned long long)TNX_ELEM_TEAM_OFF_2, eteam,
                     (unsigned long long)(uintptr_t)gidOff, elemGid, sig, sigField, why);
        }

        if (sig && valid && !taken) {
            taken = 1;
            g_own_ptr_2 = (uintptr_t)elem;
            g_own_index_2 = idx;
            g_own_team_2 = team;
            g_own_base = b;
            g_own_from_2 = (b == 0) ? "container+e0" : "scene+e0";

            tnx_own_dump(g_own_ptr_2);
        }
    }

    if (!taken) {
        g_own_ptr_2 = 0;
        g_own_index_2 = -1;
        g_own_from_2 = "v102-none";
    }
}

int tnx_inject_own(tnx_obj_t *objects, int usable, int capacity) {
    tnx_obj_t entry;
    int i;

    if (!g_own_ptr_2 || !objects) return usable;
    if (usable >= capacity) return usable;

    for (i = 0; i < usable; i++) {
        if (objects[i].object == g_own_ptr_2) return usable;
    }

    memset(&entry, 0, sizeof(entry));
    entry.object = g_own_ptr_2;

    entry.gid = tnx_gid(entry.object, NULL);

    if (!tnx_read_i32(entry.object + tnx_coord_x_off(), &entry.x) ||
        !tnx_read_i32(entry.object + tnx_coord_y_off(), &entry.y) ||
        !tnx_read_i32(entry.object + TNX_OBJ_OWNERINDEX_OFF, &entry.ownerIndex) ||
        !tnx_read_i32(entry.object + TNX_OBJ_TEAM_OFF, &entry.teamOld) ||
        !tnx_read_i32(entry.object + TNX_TEAM_OFF, &entry.teamNew)) {
        TNX_LOGX("inject own=%p unreadable - the own element cannot be added to the list",
                 (void *)entry.object);
        return usable;
    }

    tnx_read_u8(entry.object + TNX_OBJ_DEADFLAG_OFF, &entry.dead);
    tnx_read_u8(entry.object + TNX_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag);

    objects[usable] = entry;

    if (g_inject_logs < 8) {
        g_inject_logs++;
        TNX_LOGX("inject own=%p appended as objects[%d] gid=%d pos=(%d,%d) t40=%d t4c=%d "
                 "ownerIdx=%d - the own element was not in the collected list, so the list is "
                 "rebuilt with it instead of dropping the whole dodge",
                 (void *)entry.object, usable, entry.gid, entry.x, entry.y, entry.teamOld,
                 entry.teamNew, entry.ownerIndex);
    }

    return usable + 1;
}

int tnx_own_latch(const tnx_obj_t *objects, int usable, int *indexOut,
                              const char **fromOut) {
    int i = 0;

    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";
    if (!objects || usable <= 0 || !g_own_elem_2) return 0;

    for (i = 0; i < usable; i++) {
        if (objects[i].object != g_own_elem_2) continue;
        if (objects[i].gid < TNX_GID_FLOOR || objects[i].gid >= TNX_PLAYER_GID_MAX) return 0;
        if (objects[i].teamOld < 0 || objects[i].teamOld > TNX_TEAM_MAX_2) return 0;

        if (indexOut) *indexOut = i;
        if (fromOut) *fromOut = "latched";

        if (g_latch_logs < 6) {
            g_latch_logs++;

            TNX_LOGX("own latched idx=%d gid=%d pos=(%d,%d) - the character the dodge used last tick "
                     "is still in the container with a plausible gid and team, so it is taken again "
                     "before any of the heuristics run; the smallest gid rule below can pick another "
                     "player and did, in the 18:44 run, where own resolved to a fixed (2550,9750) that "
                     "the character never occupied",
                     i, objects[i].gid, objects[i].x, objects[i].y);
        }

        return 1;
    }

    return 0;
}

int tnx_take_own(const tnx_obj_t *objects, int usable, int *indexOut,
                             const char **fromOut) {
    int i;

    if (!objects || usable <= 0) return 0;
    if (!g_own_ptr_2) return 0;

    for (i = 0; i < usable; i++) {
        if (objects[i].object == g_own_ptr_2) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = g_own_from_2;

            return 1;
        }
    }

    if (g_inject_logs < 8) {
        g_inject_logs++;
        TNX_LOGX("own=%p slot=%d is neither in the collected list nor measurable - every "
                 "field read off it failed the collector test, so the element is not a battle "
                 "object at all",
                 (void *)g_own_ptr_2, g_own_index_2);
    }

    return 0;
}

uintptr_t g_own_elem = 0;

uint64_t g_own_stamp = 0;

uintptr_t tnx_own_obj(void) {
    uintptr_t vt = 0;
    const char *why = "?";

    if (g_own_elem) {
        if (tnx_cand_ok(g_own_elem, &why, &vt)) {
            g_own_from_3 = (g_own_stamp == g_tick_stamp) ? "published" : "published-old";

            return g_own_elem;
        }

        if (g_stale_logs < 6) {
            g_stale_logs++;

            TNX_LOGX("own not used elem=%p stamp=%llu tick=%llu reason=%s - an element from "
                     "another tick is not accepted even though the address is a live heap object, "
                     "so the engine chain is tried instead and may legitimately resolve to 0",
                     (void *)g_own_elem, (unsigned long long)g_own_stamp,
                     (unsigned long long)g_tick_stamp, why);
        }
    }

    {
        uintptr_t cand = tnx_hop((uintptr_t)g_scene_object, NULL);

        if (cand && tnx_cand_ok(cand, NULL, &vt)) {
            g_own_from_3 = "engine-chain";

            return cand;
        }

        cand = tnx_hop((uintptr_t)g_players_object, NULL);

        if (cand && tnx_cand_ok(cand, NULL, &vt)) {
            g_own_from_3 = "players-chain";

            return cand;
        }
    }

    g_own_from_3 = "none";

    return 0;
}

int32_t g_own_gid = 0;

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
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team)) continue;
        if (team < 0 || team > TNX_TEAM_MAX_2) continue;

        if (!best || gid < bestGid) {
            best = (uintptr_t)element;
            bestGid = gid;
        }
    }

    if (!best) {
        if (g_own_logs_4 < TNX_OWN_LOGS_3) {
            g_own_logs_4++;

            TNX_LOGX("own-min-gid array=%p count=%d none - no element passed the id window "
                     "[%d,%d) and the team window 0..%d at the same time, so own cannot be named by "
                     "the smallest id this tick; the id at +%#llx and the team at +%#llx are the two "
                     "fields the census accepts on",
                     (void *)array, count, TNX_GID_FLOOR, TNX_GID_MAX, TNX_TEAM_MAX_2,
                     (unsigned long long)TNX_OBJ_GLOBALID_OFF,
                     (unsigned long long)TNX_OBJ_TEAM_OFF);
        }

        return 0;
    }

    if (g_own_logs_4 < TNX_OWN_LOGS_3) {
        g_own_logs_4++;

        TNX_LOGX("own-min-gid array=%p count=%d own=%p gid=%d - own is the accepted element "
                 "carrying the smallest id, which the three battles of the v132 run agree on: the "
                 "element with gid 1000000 was the local player in the 3v3, in the solo training "
                 "and in the third battle, while the team field moved between 1, 0 and 1 and the "
                 "own slot at +%#llx of a hop container did not name it at all",
                 (void *)array, count, (void *)best, bestGid,
                 (unsigned long long)TNX_OWNIDX_OFF_2);
    }

    g_own_ptr_3 = best;
    g_own_gid = bestGid;

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

    if (g_own_logs_5 < TNX_OWN_LOGS_4) {
        g_own_logs_5++;

        TNX_LOGX("own-list usable=%d accepted=%d best=%d bestGid=%d floor=%d max=%d teamMax=%d - "
                 "own is chosen out of the SAME list the walk collected, so the index it returns is "
                 "always valid for that list; the v134 run resolved own out of the container globals "
                 "and then looked the element up in the collected list, which let the +%#llx slot "
                 "path run when the two disagreed and returned a heap pointer as an index",
                 usable, accepted, best, bestGid, TNX_GID_FLOOR, TNX_GID_MAX,
                 TNX_TEAM_MAX_2, (unsigned long long)TNX_OWNIDX_OFF_2);
    }

    if (best < 0) return 0;

    if (indexOut) *indexOut = best;
    if (fromOut) *fromOut = "v135-list";

    return 1;
}

int tnx_own_scan(void) {
    uintptr_t bases[TNX_SCAN_BASES];
    const char *names[TNX_SCAN_BASES] = { "mode", "client", "inputMgr" };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    uintptr_t client = 0;
    uintptr_t inputMgr = 0;
    void *chain = NULL;
    void *input = NULL;
    int found = 0;

    if (!g_scene_object) return 0;
    if (!array || count <= 0) return 0;

    bases[0] = g_scene_object;

    if (tnx_read_ptr(g_scene_object + TNX_MODE_MANAGER_OFF, &chain) && chain) {
        client = (uintptr_t)chain;
    }

    if (tnx_read_ptr(g_scene_object + TNX_MODE_INPUTMGR_OFF, &input) && input) {
        inputMgr = (uintptr_t)input;
    }

    bases[1] = client;
    bases[2] = inputMgr;

    tnx_own_index_probe();

    tnx_own_probe();
    tnx_audit_all();

    g_tick_2++;
    tnx_queue_line();

    if (!g_setpred) g_setpred = tnx_entry(TNX_MODEPAIRSET_RVA);

    if (!g_setpred && g_own_logs < 2) {
        TNX_LOGX("setter candidate rva=%#llx is not an entry point on this build - the leaf "
                 "setter the audit names starts with a store and carries no frame, so its call "
                 "cannot be armed and the actuator has to go through the input manager instead",
                 (unsigned long long)TNX_MODEPAIRSET_RVA);
    }

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
                g_own_ptr_4 = value;
                g_own_index_3 = (int)index;
                g_own_src = b;
                g_own_off = off;
                g_own_from_4 = names[b];
                found = 1;
            }

            if (g_scan_logs < 8) {
                g_scan_logs++;

                TNX_LOGX("ownscan %s+%#llx = %p is element[%llu] of array=%p count=%d - a word "
                         "that points into the container names the local player, which is the "
                         "operation no single field of the mode performed",
                         names[b], (unsigned long long)off, (void *)value,
                         (unsigned long long)index, (void *)array, count);
            }
        }
    }

    if (!found && g_scan_container != (uintptr_t)array) {
        g_scan_container = (uintptr_t)array;

        TNX_LOGX("ownscan found nothing in mode(%p)+0x00..+0x%x, client(%p)+0x00..+0x%x or "
                 "inputMgr(%p)+0x00..+0x%x that points into array=%p count=%d - none of the three "
                 "objects holds the own element, so the window is %#x on each and not the 0x300 "
                 "the v98 run covered",
                 (void *)bases[0], (unsigned)(TNX_SCAN_QWORDS * 8), (void *)client,
                 (unsigned)(TNX_SCAN_QWORDS * 8), (void *)inputMgr,
                 (unsigned)(TNX_SCAN_QWORDS * 8), (void *)array, count,
                 (unsigned)(TNX_SCAN_QWORDS * 8));
    }

    if (!g_find_joy_done) {
        g_find_joy_done = 1;

    }

    return found;
}

int tnx_resolve_own_2(const tnx_obj_t *objects, int usable, int *indexOut,
                               const char **fromOut) {
    if (indexOut) *indexOut = -1;
    if (fromOut) *fromOut = "none";

    if (!objects || usable <= 0) return 0;

    if (g_own_index >= 0 && g_own_ptr) {
        int seen = 0;
        int i;

        for (i = 0; i < usable; i++) {
            if (objects[i].object == g_own_ptr) {
                seen = 1;
                break;
            }
        }

        if (seen) {
            if (indexOut) *indexOut = i;
            if (fromOut) *fromOut = g_own_from;

            return 1;
        }

        if (g_miss_logs < 4) {
            g_miss_logs++;

            TNX_LOGX("own-index element %p, slot %d of %d, is not in the collected list of "
                     "%d objects - the index names an object the collector drops or reorders, so "
                     "the slot number from the container cannot be used as an index into this "
                     "list and the element has to be matched by pointer or by global id",
                     (void *)g_own_ptr, g_own_index, g_players_count, usable);
        }
    }

    if (g_own_index_3 >= 0 && g_own_index_3 < usable &&
        objects[g_own_index_3].object == g_own_ptr_4) {
        if (indexOut) *indexOut = g_own_index_3;
        if (fromOut) *fromOut = "scan";

        return 1;
    }

    return 0;
}

int tnx_own(int32_t *xOut, int32_t *yOut) {
    uintptr_t own = g_own_elem_2;

    if (!own) own = (uintptr_t)g_own_elem;
    if (!own) return 0;
    if (!tnx_read_i32(own + TNX_OBJ_X_OFF, xOut)) return 0;
    if (!tnx_read_i32(own + TNX_OBJ_Y_OFF, yOut)) return 0;

    return 1;
}
