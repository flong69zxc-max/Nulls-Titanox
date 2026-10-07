#include "titanox.h"

int t_match_tick_3 = 0;

int t_match_dumps_3 = 0;

static int t_match_seen_own_3 = -1;

static const char *t_match_class_3(int32_t gid) {
    if (gid < TNX_PLAYER_GID) return "cast";

    if (gid < TNX_SHOT_GID) return "player";

    return "shot";
}

void tnx_match_dump_3(const tnx_obj_t *objects, int usable, int ownIndex, int ownX, int ownY, int ownTeam) {
    int i = 0;
    int mates = 0;
    int foes = 0;
    int unknown = 0;
    int shots = 0;
    int myShots = 0;
    int32_t ownGid = -1;
    int32_t ownOld = -1;
    int32_t ownNew = -1;

    if (!TNX_MATCH_ON_3) return;
    if (!objects) return;
    if (usable <= 0) return;

    t_match_tick_3++;

    if (t_match_tick_3 < TNX_MATCH_EVERY_3) return;

    t_match_tick_3 = 0;

    if (t_match_dumps_3 >= TNX_MATCH_LOGS_3) return;

    t_match_dumps_3++;

    if (ownIndex >= 0 && ownIndex < usable) {
        tnx_read_i32(objects[ownIndex].object + (uintptr_t)TNX_OBJ_TEAM_OFF, &ownOld);
        tnx_read_i32(objects[ownIndex].object + (uintptr_t)TNX_TEAM_OFF, &ownNew);
        ownGid = objects[ownIndex].gid;
    } else if (ownTeam >= 0) {
        ownOld = ownTeam;
        ownNew = ownTeam;
    }

    for (i = 0; i < usable; i++) {
        int32_t oldTeam = 0;
        int32_t newTeam = 0;

        tnx_read_i32(objects[i].object + (uintptr_t)TNX_OBJ_TEAM_OFF, &oldTeam);
        tnx_read_i32(objects[i].object + (uintptr_t)TNX_TEAM_OFF, &newTeam);

        if (ownTeam >= 0 && (oldTeam == ownTeam || newTeam == ownTeam)) mates++;
        else if (oldTeam == 0 || oldTeam == 1 || newTeam == 0 || newTeam == 1) foes++;
        else unknown++;

        if (objects[i].gid >= TNX_SHOT_GID) {
            shots++;

            if (ownTeam >= 0 && (oldTeam == ownTeam || newTeam == ownTeam)) myShots++;
        }
    }

    TNX_LOGX("match own i=%d ptr=%p gid=%d pos=(%d,%d) team=%d tOld+%#llx=%d tNew+%#llx=%d mates=%d foes=%d "
             "unknown=%d shots=%d myShots=%d usable=%d - the same raw fields the server rule uses, read before "
             "any filter of ours runs, so a shot that carries my team value is mine and one that carries the "
             "other value is not",
             ownIndex,
             (ownIndex >= 0 && ownIndex < usable) ? (void *)objects[ownIndex].object : (void *)0,
             ownGid, ownX, ownY, ownTeam,
             (unsigned long long)TNX_OBJ_TEAM_OFF, ownOld,
             (unsigned long long)TNX_TEAM_OFF, ownNew,
             mates, foes, unknown, shots, myShots, usable);

    if (t_match_seen_own_3 != ownIndex) {
        t_match_seen_own_3 = ownIndex;

        TNX_LOGX("match ownchange ownIndex=%d ptr=%p gid=%d - my element changed, every side label below is "
                 "relative to the element in this line",
                 ownIndex,
                 (ownIndex >= 0 && ownIndex < usable) ? (void *)objects[ownIndex].object : (void *)0,
                 ownGid);
    }

    for (i = 0; i < usable; i++) {
        uintptr_t vt = 0;
        int32_t oldTeam = 0;
        int32_t newTeam = 0;
        const char *side = "unknown";

        tnx_read_ptr(objects[i].object, (void **)&vt);
        tnx_read_i32(objects[i].object + (uintptr_t)TNX_OBJ_TEAM_OFF, &oldTeam);
        tnx_read_i32(objects[i].object + (uintptr_t)TNX_TEAM_OFF, &newTeam);

        if (i == ownIndex) side = "me";
        else if (ownTeam >= 0 && (oldTeam == ownTeam || newTeam == ownTeam)) side = "mate";
        else if (oldTeam == 0 || oldTeam == 1 || newTeam == 0 || newTeam == 1) side = "foe";

        TNX_LOGX("match el i=%d ptr=%p vtRva=%#llx gid=%d cls=%s pos=(%d,%d) d=(%d,%d) tOld+%#llx=%d "
                 "tNew+%#llx=%d ownerIdx=%d dead=%d active=%d side=%s",
                 i, (void *)objects[i].object,
                 (unsigned long long)((vt >= t_base) ? (vt - t_base) : 0ULL),
                 objects[i].gid, t_match_class_3(objects[i].gid),
                 objects[i].x, objects[i].y,
                 objects[i].x - ownX, objects[i].y - ownY,
                 (unsigned long long)TNX_OBJ_TEAM_OFF, oldTeam,
                 (unsigned long long)TNX_TEAM_OFF, newTeam,
                 objects[i].ownerIndex, (int)objects[i].dead, (int)objects[i].activeFlag, side);
    }
}
