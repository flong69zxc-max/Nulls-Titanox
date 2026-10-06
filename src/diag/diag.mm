#include "titanox.h"

uint64_t tnx_hook_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) total += g_slot_hits[i];

    return total;
}

uint64_t tnx_object_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < TNX_OBJ_SLOTS; i++) total += g_slot_hits[tnx_object_slots[i]];

    return total;
}

void tnx_receiver_line(const char *name, uintptr_t holder) {
    void *wrap = NULL;
    void *inner = NULL;
    int32_t rawX = -1;
    int32_t rawY = -1;
    int32_t dirty = -1;
    int32_t appX = -1;
    int32_t appY = -1;
    int32_t gate = -1;
    int32_t gx = -1;
    int32_t gy = -1;
    int32_t gk = -1;
    int innerOk = 0;

    if (holder) {
        tnx_read_i32(holder + TNX_CTRL_RAW_X_OFF, &rawX);
        tnx_read_i32(holder + TNX_CTRL_RAW_Y_OFF, &rawY);
        tnx_read_i32(holder + TNX_CTRL_DIRTY_OFF, &dirty);
        tnx_read_i32(holder + TNX_CTRL_APPLIED_X_OFF, &appX);
        tnx_read_i32(holder + TNX_CTRL_APPLIED_Y_OFF, &appY);
        tnx_read_ptr(holder + TNX_CTRL_MODE_OFF, &wrap);
    }

    if (wrap) tnx_read_ptr((uintptr_t)wrap + TNX_OWN_INNER_OFF, &inner);

    if (inner) {
        innerOk = tnx_vt_ok((uintptr_t)inner, NULL);
        tnx_read_i32((uintptr_t)inner + TNX_GATE_FLAG_OFF, &gate);
        tnx_read_i32((uintptr_t)inner + TNX_GATE_X_OFF, &gx);
        tnx_read_i32((uintptr_t)inner + TNX_GATE_Y_OFF, &gy);
        tnx_read_i32((uintptr_t)inner + TNX_INPUT_K_OFF, &gk);
    }

    tnx_logf("receiver %s holder=%p holderCls=%#llx raw=(%d,%d) dirty=%d applied=(%d,%d) "
             "wrap=[+%#llx]=%p wrapCls=%#llx inner=[wrap+%#llx]=%p innerCls=%#llx innerOk=%d "
             "gate=%d pair=(%d,%d,%d) - the engine reaches the actuator receiver by dereferencing "
             "the hop field of one holder and taking the inner slot of the result, so the holder "
             "whose inner is non null with a class in __DATA_CONST is the one to call and every "
             "other holder is named here to be excluded; battle-global comes from %#llx",
             name, (void *)holder, (unsigned long long)tnx_cls(holder), rawX, rawY, dirty,
             appX, appY, (unsigned long long)TNX_CTRL_MODE_OFF, (void *)wrap,
             (unsigned long long)tnx_cls((uintptr_t)wrap),
             (unsigned long long)TNX_OWN_INNER_OFF, (void *)inner,
             (unsigned long long)tnx_cls((uintptr_t)inner), innerOk, gate, gx, gy, gk,
             (unsigned long long)TNX_BATTLE_RVA);
}

void tnx_receiver_probe(void) {
    uintptr_t battle = 0;
    void *battleRaw = NULL;

    if (g_probe_logs >= TNX_PROBE_LOGS) return;

    g_probe_logs++;

    tnx_receiver_line("scene", (uintptr_t)g_scene_object);
    tnx_receiver_line("players", g_players_object);

    if (g_base && tnx_read_ptr(g_base + TNX_BATTLE_RVA, &battleRaw)) {
        battle = (uintptr_t)battleRaw;
    }

    tnx_receiver_line("battle-global", battle);
}

void tnx_report_mode_hit(const char *tag, uintptr_t slot, uintptr_t object) {
    uintptr_t vtableRva = 0;
    uintptr_t managerVtableRva = 0;
    uintptr_t vtableOff = 0;
    const char *modeSeg = NULL;
    const char *vtableSeg = NULL;
    int score = 0;
    void *vtable = NULL;
    void *manager = NULL;
    void *managerVtable = NULL;
    void *array = NULL;
    void *entry = NULL;
    int32_t variation = 0;
    int32_t count = 0;

    tnx_read_ptr(object, &vtable);
    tnx_is_mode_vtable((uintptr_t)vtable, &vtableRva);

    if (g_base && (uintptr_t)vtable > g_base) vtableOff = (uintptr_t)vtable - g_base;

    modeSeg = tnx_image_segment_name(object);
    vtableSeg = tnx_image_segment_name((uintptr_t)vtable);
    score = tnx_mode_score(object);

    tnx_read_i32(object + TNX_MODE_MODEVAR_OFF, &variation);
    tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &manager);
    tnx_read_ptr((uintptr_t)manager, &managerVtable);
    tnx_is_mode_vtable((uintptr_t)managerVtable, &managerVtableRva);
    tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count);
    tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array);
    tnx_read_ptr((uintptr_t)array, &entry);

    tnx_logf("modehit[%s] slot=%p mode=%p mdSeg=%s vt=%p vtSeg=%s vtOff=%#llx inList=%d primary=%d score=%d types=%d var=%d mgr=%p mgr0Rva=%#llx mgrShape=%d array=%p entry0=%p count=%d",
             tag, (void *)slot, (void *)object, modeSeg ? modeSeg : "-",
             vtable, vtableSeg ? vtableSeg : "-", (unsigned long long)vtableOff,
             tnx_is_mode_vtable((uintptr_t)vtable, NULL) ? 1 : 0,
             tnx_verified_vtable((uintptr_t)vtable) >= 0 ? 1 : 0,
             score, g_mode_last_types, variation,
             manager, (unsigned long long)managerVtableRva,
             tnx_manager_shape((uintptr_t)manager) ? 1 : 0, array, entry, count);

    if (g_modehit_dump >= 8) return;

    g_modehit_dump++;

    for (int i = 0; i < 5; i++) {
        uint32_t w4[4] = { 0, 0, 0, 0 };

        tnx_read_bytes((uintptr_t)object - 0x10ULL + (uintptr_t)i * 16ULL, w4, sizeof(w4));

        tnx_logf("modehit[%s] off=%+d %08x %08x %08x %08x", tag, i * 16 - 16, w4[0], w4[1], w4[2],
                 w4[3]);
    }

    {
        void *before = NULL;
        void *tableHead = NULL;
        uintptr_t tableRva = 0;

        tnx_read_ptr((uintptr_t)object - 0x8ULL, &before);

        if (before && tnx_vtable_in_image((uintptr_t)before) &&
            tnx_read_ptr((uintptr_t)before, &tableHead) && tableHead) {
            if ((uintptr_t)tableHead > g_base) tableRva = (uintptr_t)tableHead - g_base;

            tnx_logf("modehit[%s] classtable m-08=%p inImage=1 vt0=%p vt0rva=%#llx", tag,
                     before, tableHead, (unsigned long long)tableRva);
        } else {
            tnx_logf("modehit[%s] classtable m-08=%p not-a-class-table", tag, before);
        }
    }
}

int tnx_vtcensus_top(int byShaped) {
    int best = -1;

    for (int i = 0; i < g_vtcensus_used; i++) {
        unsigned long long here = byShaped ? g_vtcensus[i].shaped : g_vtcensus[i].count;

        if (!here) continue;

        if (best < 0) {
            best = i;

            continue;
        }

        unsigned long long there = byShaped ? g_vtcensus[best].shaped : g_vtcensus[best].count;

        if (here > there) best = i;
    }

    return best;
}

void tnx_slot_diag(const char *why) {
    char buf[1024];
    int used = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        const char *state = "n/a";
        void *current = NULL;

        if (g_slot_specs[i].slotRva && g_slot_installed[i] == 1) {
            state = "unreadable";

            if (tnx_read_ptr(g_base + g_slot_specs[i].slotRva, &current)) {
                state = ((uintptr_t)current == (uintptr_t)g_slot_specs[i].replacement)
                            ? "held" : "LOST";
            }
        }

        if (used > (int)sizeof(buf) - 40) break;

        used += snprintf(buf + used, sizeof(buf) - (size_t)used, "%s=%llu/%s ",
                         g_slot_specs[i].shortTag, (unsigned long long)g_slot_hits[i], state);
    }

    tnx_logf("slotdiag(%s) %s AG=%llu/i%d agmgr=%p objs=%d", why ? why : "?", buf,
             (unsigned long long)g_ag_hits, g_ag_installed, (void *)g_ag_manager,
             g_ag_objectCount);

    if (g_ag_objectCount > 0 && !g_ag_adopted) {
        g_ag_adopted = 1;

        tnx_logf("AG dump manager=%p objects=%d", (void *)g_ag_manager, g_ag_objectCount);

        for (int i = 0; i < g_ag_objectCount; i++) {
            tnx_logf("AG obj[%d]=%p", i, (void *)g_ag_objects[i]);
        }
    }
}

void tnx_diag_report(const char *why) {
    const char *verdict = "no battle-shaped structure in the memory scanned so far";

    char verdictBuf[512] = {0};

    if (g_heap_passes == 0) {
        verdict = "no heap pass completed yet";
    } else if (g_mode_strong) {
        verdict = "MODE ADOPTED through the mode -> manager -> array chain, fields only, nothing called";
    } else if (g_objvote_owner_ok && g_players_object && g_ag_manager && g_ag_objectCount > 0) {
        verdict = "OWNER CAPTURED - the vote adopted an owner and the manager walk holds objects";
    } else if (g_objvote_owner_ok) {
        verdict = "OWNER CANDIDATE, not adopted - the vote named an owner but the manager walk "
                  "holds no objects";
    } else if (g_objvote_best_gids >= TNX_OWNER_VOTE_MIN &&
               g_objvote_best_teamcount < TNX_OWNER_VOTE_TEAMS_MIN) {

        verdict = "OBJECT VOTE found a heap owner with many distinct ids but ONE team only - a battle container carries both teams, so it is held back, not adopted";
    } else if (g_objvote_best_gids >= TNX_OWNER_VOTE_MIN) {
        verdict = "OBJECT VOTE sees game objects under one owner, but it has not won two passes in a row yet";
    } else if (g_objvote_hits > 0 && g_objvote_max_votes <= 1) {

        int cidx = tnx_vtcensus_top(1);

        if (cidx < 0) cidx = tnx_vtcensus_top(0);

        if (cidx >= 0) {
            snprintf(verdictBuf, sizeof(verdictBuf),
                     "OBJECT VOTE matched real objects but +0x20 never repeated (%d owners for %llu "
                     "objects), so +0x20 is not the shared owning manager on this build. The class "
                     "tables the live heap really carries are in the vtcensus lines; the one with the "
                     "most game-object-shaped instances is RVA %#llx (%llu instances, %llu shaped) "
                     "and its first slot RVAs are on the vtslots line - that is where the next hook "
                     "goes",
                     g_owner_vote_count, g_objvote_hits,
                     (unsigned long long)g_vtcensus[cidx].rva, g_vtcensus[cidx].count,
                     g_vtcensus[cidx].shaped);
            verdict = verdictBuf;
        } else {
            verdict = "OBJECT VOTE matched real objects but +0x20 never repeated - almost as many owners as objects, so +0x20 is not the shared owning manager on this build; and no table of theirs survived in the census, which is itself the finding - read the objhit dump for the class tables the live objects carry";
        }
    } else if (g_objvote_hits > 0) {
        verdict = "OBJECT VOTE matched object-shaped words but no owner reached the distinct-id minimum - the layout is partly recognised";
    } else if (g_scene_object) {
        verdict = "an object was adopted but the chain is not fully confirmed";
    } else if (g_manager_loose_count == 0 && g_manager_saw_cap == 0) {
        verdict = "NO ARRAY-SHAPED WORD ANYWHERE - the header test itself matched nothing";
    } else if (g_manager_skipped > 0 || g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) {
        verdict = "ARRAY TEST BLIND - its probe budget was exhausted; the object vote is the channel that still covered the whole pass";
    } else if (g_chain_skipped > 0 && !g_scene_object && !g_players_object) {
        verdict = "CHAIN BLIND - the chain probe hit its limit before the heap was covered, and it found nothing before that; this run proves nothing about the mode";
    } else if (g_manager_best_live >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "a container passed the array test and was recorded, NOT adopted - the chain never matched";
    } else if (g_manager_best_live >= 1) {
        verdict = "manager-shaped array seen, but too few live instances -> not a battle";
    } else if (g_manager_best_count >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "count at +0xc is in range but entries are not C++ instances -> wrong layout";
    } else if (g_manager_skipped > 0) {
        verdict = "probe budget exhausted -> the pass was blind after that point, raise the limit";
    } else if (g_manager_probes_total == 0 && g_heap_passes > 0) {
        verdict = "no manager-like count at +0xc anywhere -> layout @+0xc wrong, or coverage short";
    } else if (!g_players_object && g_mode_best_objects < TNX_MANAGER_MIN_OBJECTS &&
               g_heap_passes > 0) {
        verdict = "NO BATTLE IN WINDOW - nothing battle-shaped existed, this says nothing about the layout";
    }

    g_slot_hits_total = 0;
    for (int i = 0; i < TNX_SLOT_COUNT; i++) g_slot_hits_total += (uint64_t)g_slot_hits[i];

    tnx_logf("hooks fired=%llu of %d slots (A1=%llu A2=%llu B1=%llu B2=%llu B3=%llu C1=%llu C2=%llu)",
             (unsigned long long)g_slot_hits_total, TNX_SLOT_COUNT,
             (unsigned long long)g_slot_hits[0], (unsigned long long)g_slot_hits[1],
             (unsigned long long)g_slot_hits[2], (unsigned long long)g_slot_hits[3],
             (unsigned long long)g_slot_hits[4], (unsigned long long)g_slot_hits[5],
             (unsigned long long)g_slot_hits[6]);

    if (g_slot_hits_total == 0 && g_heap_passes > 0) {

        tnx_logf("DIAG note: none of the seven slots was ever dispatched - which is NOT the same as "
                 "the seven classes being absent. The 20:22 run measured a pass from 0x0 and a pass "
                 "from the window low, both cut off by the same byte budget, and the ninth vtprobe "
                 "counter read 0 on the first and 92502 on the second. A zero counts only when that "
                 "pass reports budgetHit=0, which is why the pass line now carries budget=, "
                 "budgetHit= and readTo= beside scanned= and winSpan=. `vtprobePass=` is this pass, "
                 "`vtprobeAll=` the running total, `vtprobeFirst=` the address behind each non-zero "
                 "counter. The classes that DO exist are enumerated by the `vtcensus` lines: "
                 "`count=` is live instances, `shaped=` how many of them also passed the full object "
                 "record layout, and `vtslots` gives the first slot RVAs of the two most interesting "
                 "tables - that is where the next hook goes");
    }

    tnx_trail_dump();

    tnx_logf("chain gates: vtBad=%d vtNotDC=%d mgrBad=%d mgrNotPlausible=%d mgrNotHeap=%d "
             "varBad=%d pxBad=%d pyBad=%d inputBad=%d shapeBad=%d arrayRead=%d countRead=%d "
             "arrayNull=%d countRange=%d live=%d own=%d gid=%d tested=%d logged=%d",
             g_chain_rej[0], g_chain_rej[1], g_chain_rej[2], g_chain_rej[3],
             g_chain_rej[4], g_chain_rej[5], g_chain_rej[6], g_chain_rej[7],
             g_chain_rej[8], g_chain_rej[9], g_chain_rej[10], g_chain_rej[11],
             g_chain_rej[12], g_chain_rej[13], g_chain_rej[14], g_chain_rej[15],
             g_chain_rej[16], g_chain_probes, g_layout_logs);

    tnx_logf("DIAG(%s) attempts=%d/%d heapPasses=%d covered=%lluMB probes=%d/%d skipped=%d "
             "capRej=%d/%d bestCount=%d bestLive=%d mgr=%p adopted=%d vfx=%d mx=%d "
             "chain=%d/%d chainPass=%d chainSkip=%d stable=%d own=%d gid=%d "
             "objvote=%llu skipped=%llu owners=%d best=%p gids=%d%s confirm=%d teamCount=%d "
             "deadOk=%d ownerImg=%llu ownerNoRegion=%llu ownerAboveWin=%llu objImg=%llu "
             "objShaped=%llu maxVotes=%d "
             "bigSkip=%d vtcensus=%d/%llu",
             why ? why : "?", g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_heap_covered / (1024ull * 1024ull), g_manager_probes_total, TNX_MANAGER_PROBE_LIMIT,
             g_manager_skipped, g_manager_cap_rejects, g_manager_saw_cap,
             g_manager_best_count, g_manager_best_live, (void *)g_players_object,
             g_mode_strong ? 1 : 0, g_mode_verified_hits, g_mode_best_objects,
             g_chain_checks, g_chain_probes, g_chain_probes_pass, g_chain_skipped,
             g_seen_stable,
             g_chain_best_own, g_chain_best_gid,
             g_objvote_hits, g_objvote_skipped, g_owner_vote_count,
             (void *)g_objvote_best_owner, g_objvote_best_gids,
             g_objvote_best_gids_full ? "+" : "", g_objvote_confirm, g_objvote_best_teamcount,
              g_objvote_dead_seen, g_objvote_owner_img, g_objvote_owner_reg,
              g_objvote_owner_above_win, g_objvote_obj_img,
              g_objvote_shaped, g_objvote_max_votes, g_heap_big_skip,
              g_vtcensus_used, g_vtcensus_total);

    tnx_logf("DIAG verdict: %s", verdict);

    tnx_slot_diag(why);
}

void tnx_report_manager(const char *tag, uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!tnx_pointer_plausible(manager)) return;

    if (!tnx_owner_is_heap(manager)) {
        tnx_logf("%s mgr=%p rejected: not a heap allocation", tag, (void *)manager);
        return;
    }

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) {
        tnx_logf("%s mgr=%p unreadable", tag, (void *)manager);
        return;
    }
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return;

    tnx_logf("%s mgr=%p array=%p count=%d cap=%d live=%d%s", tag, (void *)manager, array,
             count, capacity, tnx_manager_live_count(manager),
             (capacity >= count && capacity <= TNX_MGR_CAP_MAX) ? "" : " CAP-VIOLATION");

    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return;
    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return;

}

void tnx_trail_dump(void) {
    int rank[TNX_TRAIL_MAX];
    int n = tnx_trail_ranked(rank, TNX_TRAIL_MAX);

    tnx_logf("trail: %llu candidates passed the array header, %d recorded, %d refused as inline "
             "text, ordered by (live, nonEmpty, count); the best needs teamDistinct>=2 and "
             "posDistinct>=2", (unsigned long long)g_trail_total, g_trail_count, g_ascii_refused);

    for (int k = 0; k < n; k++) {
        int i = rank[k];
        char reason[64] = { 0 };
        int accepted = tnx_trail_verdict(&g_trail[i], reason, sizeof(reason));

        tnx_logf("trail[%d] rank=%d mgr=%p count=%d cap=%d live=%d nonEmpty=%d ascii=%d/%d(%d%%) "
                 "teamDistinct=%d posDistinct=%d stable=%d raw=%c -> %s%s%s",
                 i, k, (void *)g_trail[i].manager, g_trail[i].count, g_trail[i].capacity,
                 g_trail[i].live, g_trail[i].nonEmpty, g_trail[i].ascii, g_trail[i].sampled,
                 g_trail[i].sampled > 0 ? (g_trail[i].ascii * 100) / g_trail[i].sampled : 0,
                 g_trail[i].teamDistinct, g_trail[i].posDistinct, g_trail[i].stable,
                 g_trail[i].rawSeg, accepted ? "ACCEPTED" : "REFUSED reason=",
                 accepted ? "" : reason, (i == g_trail_best) ? " <- best" : "");
    }
}

void tnx_slot_table_dump(void) {
    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        tnx_logf("hook[%d] %-4s target=%#llx slotRva=%#llx repl=%p control=%d",
                 i, g_slot_specs[i].shortTag,
                 (unsigned long long)g_slot_specs[i].rva,
                 (unsigned long long)g_slot_specs[i].slotRva,
                 (void *)g_slot_specs[i].replacement,
                 g_slot_specs[i].control ? 1 : 0);
    }
}

int tnx_object_detail(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int shown = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;
    if (count <= 0) return 0;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;
    if (limit > 0 && count > limit) count = limit;

    tnx_logf("objtable array=%p count=%d cap=%d", array, count, capacity);

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;
        void *slotOwner = NULL;
        void *slotAlive = NULL;
        void *slotKind = NULL;
        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        int32_t x = 0;
        int32_t y = 0;
        uint8_t dead = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        shown++;

        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;

        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_OWNER_OFF, &slotOwner);
        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_ALIVE_OFF, &slotAlive);
        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_KIND_OFF, &slotKind);

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_logf("obj[%02d] %p vt=%#llx gid=%d team=%d own=%d dead=%d s88=%#llx s90=%#llx "
                 "s18=%#llx s28=%#llx s48=%#llx shape=%d",
                 i, element, (unsigned long long)tnx_vtable_rva(element), globalId, team, owner,
                 dead, (unsigned long long)s88, (unsigned long long)s90,
                 (unsigned long long)(slotOwner ? (uintptr_t)slotOwner - g_base : 0),
                 (unsigned long long)(slotAlive ? (uintptr_t)slotAlive - g_base : 0),
                 (unsigned long long)(slotKind ? (uintptr_t)slotKind - g_base : 0),
                 tnx_gameobject_shape((uintptr_t)element) ? 1 : 0);
    }

    return shown;
}

uint64_t g_engage_writes = 0;

void tnx_engage_report(const char *why) {
    if (g_logs_6 >= TNX_DRIVE_LOGS_2) return;
    if (g_engage_writes == 0) return;

    g_logs_6++;

    tnx_logf("%s first=%llu last=%llu frames=%llu writes=%llu movedAfter=%llu maxFrame=%llu "
             "traveled=%llu own=(%d,%d) pick=(%d,%d) - movedAfter is the delay: the frames from the "
             "first write of this run to the first frame own's position moved by at least %d units, "
             "which is a walk of 180 units a second and no longer the twenty a frame that only a "
             "teleport reaches; traveled is the whole path own covered during the run against 780 "
             "units a second for a walk, which is the number that says whether the body follows the "
             "writes at all; human=%llu counts the frames the player's own finger was on the stick, so a "
             "run with human at its maximum and traveled at a walk speed is the dodge working while "
             "the stick is held, and the prediction went out %llu times with %llu refusals", why,
             (unsigned long long)g_engage_start,
             (unsigned long long)g_engage_last,
             (unsigned long long)(g_engage_last - g_engage_start),
             (unsigned long long)g_engage_writes,
             (unsigned long long)(g_move_tick ? g_move_tick - g_engage_start : 0),
             (unsigned long long)g_max_frame, (unsigned long long)g_traveled,
             g_own_x_2, g_own_y_2, g_pick_x, g_pick_y, TNX_MOVE_MIN,
             (unsigned long long)g_human_live, (unsigned long long)g_pred_calls,
             (unsigned long long)g_pred_fails);
}

uintptr_t g_base = 0;

uintptr_t g_scene_object = 0;

tnx_vtcensus_t g_vtcensus[TNX_VTCENSUS_MAX];

int g_vtcensus_used = 0;

uint64_t g_slot_hits[TNX_SLOT_COUNT] = { 0 };

uintptr_t g_ag_manager = 0;

int g_ag_objectCount = 0;

int g_own_x = 0;

int g_own_y = 0;

int32_t g_own_team_5 = -1;

uint64_t g_gate_writes = 0;

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

    if (ownElem && tnx_read_i32(ownElem + TNX_OWN_ALIVE_OFF, &ownAlive)) out[1] = (int)ownAlive;

    if (ctrl && tnx_read_i32(ctrl + TNX_CTRL_ALIVE_OFF, &ctrlAlive)) out[2] = (int)ctrlAlive;
}

const char *tnx_cand_name(int slot) {
    if (slot == 0) return "own+d4";
    if (slot == 1) return "own+140";
    if (slot == 2) return "ctrl+f80";

    return "none";
}

void tnx_drift(void) {
    int32_t ownX = 0;
    int32_t ownY = 0;

    if (!g_last_decision) return;
    if (g_drift_done == g_last_decision) return;
    if ((g_ticks_3 - g_last_decision) < 60) return;
    if ((g_ticks_3 - g_last_decision) > 240) return;
    if (!tnx_own(&ownX, &ownY)) return;
    if (g_drift_logs >= TNX_DRIVE_LOGS_2) return;

    g_drift_logs++;
    g_drift_done = g_last_decision;

    TNX_LOGX("drift after the last decision: frames=%d traveled=%d from=(%d,%d) own=(%d,%d) "
             "lastSent=(%d,%d) sentStep=%.0f holdTicks=%d - this is the distance covered in the "
             "second after the dodge stopped choosing, so a traveled distance near the walk speed of "
             "780 means the body is still riding the last target, and one near zero means the writes "
             "and not the engine were pacing it",
             (int)(g_ticks_3 - g_last_decision),
             (int)sqrtf((float)((ownX - g_decide_x) * (ownX - g_decide_x) +
                                (ownY - g_decide_y) * (ownY - g_decide_y))),
             (int)g_decide_x, (int)g_decide_y, ownX, ownY, g_last_tx_2,
             g_last_ty_2, (double)TNX_STEP_3, TNX_DATA_HOLD);
}

void tnx_dump(void) {
    int i = 0;

    if (!TNX_DUMP) return;
    if ((g_ticks_3 % TNX_DUMP_EVERY) != 0) return;
    if (g_dump_logs >= TNX_DUMP_LOGS) return;

    g_dump_logs++;

    TNX_LOGX("dump own pos=(%d,%d) ok=%d team=%d trust=%d mates=%d enemies=%d cluster=%d/%d "
             "agree=%d players=%d segs=%d engaged=%d pick=(%d,%d) bodyMine=%d bodyEnemy=%d freest=%llu "
             "gate=%llu pred=%llu/%llu",
             g_own_x, g_own_y, tnx_own_ok(g_own_x, g_own_y),
             g_own_team_5, g_team_trust, g_mate_n, g_enemy_n, g_mates,
             g_enemies, g_agree, g_pl_n, g_seg_count, g_active_2,
             g_tx, g_ty, g_body_mine, g_body_enemy,
             (unsigned long long)g_freest_used, (unsigned long long)g_gate_writes,
             (unsigned long long)g_pred_calls, (unsigned long long)g_pred_fails);

    for (i = 0; i < g_pl_n && i < 6; i++) {
        TNX_LOGX("dump p%d gid=%d pos=(%d,%d) spawn=(%d,%d) team=%d mine=%d",
                 i, g_pl_gid[i], g_pl_x[i], g_pl_y[i], g_pl_sx[i],
                 g_pl_sy[i], g_pl_team[i], g_pl_mine[i]);
    }

    for (i = 0; i < TNX_PROJ_MAX; i++) {
        tnx_proj_t *p = &g_projs[i];
        uint64_t age = 0;

        if (p->classRva == (uintptr_t)-1) continue;
        if (!p->hasPrev) age = 0;
        else age = (p->qtick > p->ptick) ? (p->qtick - p->ptick) : 0;

        TNX_LOGX("dump j%d gid=%d pos=(%d,%d) prev=(%d,%d) spawn=(%d,%d) team=%d dt=%llu",
                 i, p->gid, p->x, p->y, p->px, p->py, p->spawnX, p->spawnY, p->team,
                 (unsigned long long)age);
    }
}

void tnx_core(void) {
    if ((g_ticks_3 % 60) != 0) return;

    TNX_LOGX("core tick=%llu own=(%d,%d) ownOk=%d team=%d mates=%d enemies=%d trust=%d "
             "players=%d segs=%d trackedOwn=%d trackedOther=%d oneshot=%d body=%d enemyBlock=%d "
             "mateBlock=%d gate=%llu pred=%llu/%llu deadPick=%llu human=%llu driveWrites=%llu "
             "stickSkips=%llu stuck=%llu",
             (unsigned long long)g_ticks_3, g_own_x, g_own_y,
             tnx_own_ok(g_own_x, g_own_y), g_own_team_5, g_mate_n,
             g_enemy_n, g_team_trust, g_pl_n, g_seg_count, g_proj_own,
             g_proj_other, g_oneshot_segs, g_body_blocks, g_enemy_blocks,
             g_block_hits, (unsigned long long)g_gate_writes,
             (unsigned long long)g_pred_calls, (unsigned long long)g_pred_fails,
             (unsigned long long)g_dead_picks, (unsigned long long)g_human_live,
             (unsigned long long)g_engage_writes, (unsigned long long)g_stick_skips,
             (unsigned long long)g_stuck_2);
}

void tnx_probe_2(void) {
    uintptr_t bs = tnx_bs();
    void *vt = NULL;
    float ax = 0.0f;
    float ay = 0.0f;
    float bx = 0.0f;
    float by = 0.0f;
    float cs = 0.0f;
    float sn = 0.0f;
    uint32_t mode = 0;
    unsigned long long vtRva = 0;

    tnx_scan();

    if (!bs) return;

    if (g_probe_logs_2 < 1) {
        g_probe_logs_2++;

        if (tnx_read_ptr(bs, &vt) && (uintptr_t)vt > g_base) {
            vtRva = (unsigned long long)((uintptr_t)vt - g_base);
        }

        TNX_LOGX("bs live scene=%p bs=%p ctrl=%p classRva=%#llx - the one-shot waits for a live "
                 "scene now, so the class word is read from the object the dodge really uses and not "
                 "from a null pointer, which is what the previous run printed as scene=0x0 and "
                 "classRva=0; updateMovement cannot be hooked on this target - a scan of every "
                 "eight-byte word of __DATA_CONST and __DATA found no slot pointing at it and inline "
                 "patching is not supported - so the BattleScreen object is the scene this file "
                 "already resolves and the joystick is searched in its window by the v173 scanner. "
                 "The class word 0xfe9d00 is the identity the earlier note names",
                 (void *)g_scene_object, (void *)bs, (void *)tnx_controller(), vtRva);
    }

    if (g_own_logs_7 < 20 && (g_ticks_3 % 60) == 0) {
        g_own_logs_7++;

        TNX_LOGX("own check ownElem=%p ownFrom=%s - the same object the dodge reads its position "
                 "from, printed next to the element lines so the two own sources in the log can be "
                 "told apart instead of being read as a disagreement",
                 (void *)g_own_elem, g_own_from_3);
    }

    if (g_probe_logs_2 < 22 && (g_ticks_3 % 60) == 0) {
        g_probe_logs_2++;

        if (!tnx_joy_read(bs, &ax, &ay, &bx, &by, &mode, &cs, &sn)) return;

        TNX_LOGX("joyprobe bs=%p ax=%+.4f ay=%+.4f bx=%+.4f by=%+.4f mode=%u cos=%+.4f sin=%+.4f "
                 "- read only, nothing is written in this build; move the stick by hand and if these "
                 "move and mode reads 2 or 3 this is the joystick, otherwise this class keeps the "
                 "stick elsewhere and the window diff below is the way to it",
                 (void *)bs, (double)ax, (double)ay, (double)bx, (double)by, mode, (double)cs,
                 (double)sn);
    }
}

uint64_t g_human_live = 0;

int g_test_state_2 = 0;

int g_tested_2 = 0;

int g_enq_x = 0;

int g_enq_y = 0;

int g_readback = -1;

uint64_t g_pred_calls = 0;

uint64_t g_pred_fails = 0;

uintptr_t g_wit_elem = 0;

int32_t g_wit_x0 = 0;

int32_t g_wit_y0 = 0;

int32_t g_wit_x1 = 0;

int32_t g_wit_y1 = 0;

int g_active = 0;

int64_t g_moves = 0;

int64_t g_elem_moves = 0;

int tnx_witness(int32_t *x, int32_t *y) {
    int32_t wx = 0;
    int32_t wy = 0;

    if (x) *x = 0;
    if (y) *y = 0;

    if (!tnx_interp(&wx, &wy)) return 0;

    if (x) *x = wx;
    if (y) *y = wy;

    return 1;
}

void tnx_witness_line(int plus) {
    int32_t wx = 0;
    int32_t wy = 0;
    int32_t ex = -1;
    int32_t ey = -1;
    int32_t app_x = -1;
    int32_t app_y = -1;
    int32_t raw_x = 0;
    int32_t raw_y = 0;
    uintptr_t ctrl = tnx_client();
    int moved = 0;
    int elemMoved = 0;

    if (!g_active) return;
    if (g_wit_logs >= TNX_WIT_LOGS) return;

    g_wit_logs++;

    tnx_witness(&wx, &wy);

    if (g_wit_elem) {
        if (!tnx_read_i32(g_wit_elem + TNX_OBJ_X_OFF, &ex)) ex = -1;
        if (!tnx_read_i32(g_wit_elem + TNX_OBJ_Y_OFF, &ey)) ey = -1;
    }

    if (ctrl) {
        if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &raw_x)) raw_x = 0;
        if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &raw_y)) raw_y = 0;
        if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_X_OFF, &app_x)) app_x = -1;
        if (!tnx_read_i32(ctrl + TNX_CTRL_APPLIED_Y_OFF, &app_y)) app_y = -1;
    }

    moved = (wx != g_wit_x0 || wy != g_wit_y0) ? 1 : 0;
    elemMoved = (ex != g_wit_x1 || ey != g_wit_y1) ? 1 : 0;

    if (moved) g_moves++;
    if (elemMoved) g_elem_moves++;

    TNX_LOGX("witness +%d interp=(%d,%d) was=(%d,%d) moved=%d moves=%lld | elem=%p pos=(%d,%d) was=(%d,%d) elemMoved=%d elemMoves=%lld | scene raw+%#llx=(%d,%d) applied+%#llx=(%d,%d)",
             plus, wx, wy, g_wit_x0, g_wit_y0, moved, (long long)g_moves,
             (void *)g_wit_elem, ex, ey, g_wit_x1, g_wit_y1, elemMoved,
             (long long)g_elem_moves, (unsigned long long)TNX_CTRL_RAW_X_OFF, raw_x, raw_y,
             (unsigned long long)TNX_CTRL_APPLIED_X_OFF, app_x, app_y,
             (unsigned long long)TNX_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_CLIENT_POS_Y_OFF);

    g_wit_x0 = wx;
    g_wit_y0 = wy;
    g_wit_x1 = ex;
    g_wit_y1 = ey;
}

int tnx_fields_pair(uintptr_t *srcOut, int32_t *xOut, int32_t *yOut) {
    uintptr_t own = tnx_own_obj();
    uintptr_t src = own ? own : (uintptr_t)g_scene_object;
    int32_t x = 0;
    int32_t y = 0;

    if (srcOut) *srcOut = 0;
    if (xOut) *xOut = 0;
    if (yOut) *yOut = 0;

    if (!src) return 0;
    if (!tnx_read_i32(src + TNX_INPUT_X_OFF, &x)) return 0;
    if (!tnx_read_i32(src + TNX_INPUT_Y_OFF, &y)) return 0;

    if (srcOut) *srcOut = src;
    if (xOut) *xOut = x;
    if (yOut) *yOut = y;

    return 1;
}

int tnx_fields(void) {
    uintptr_t src = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_fields_pair(&src, &x, &y)) return -1;

    return (x == g_enq_x && y == g_enq_y) ? 1 : 0;
}

void tnx_frame_window(void) {
    uint64_t d = 0;
    int32_t inX = 0;
    int32_t inY = 0;

    if (!g_push_frame) return;

    d = g_ticks_3 - g_push_frame;

    if (d > TNX_FRAME_WINDOW) return;
    if (g_frame_logs >= 40) return;

    g_frame_logs++;

    if (g_scene_object) {
        tnx_read_i32(tnx_client() + TNX_INPUT_X_OFF, &inX);
        tnx_read_i32(tnx_client() + TNX_INPUT_Y_OFF, &inY);
    }

    {
        uintptr_t client = tnx_client();
        int32_t cx = 0;
        int32_t cy = 0;
        int32_t ck = 0;

        if (client) {
            tnx_read_i32(client + TNX_CLIENT_POS_X_OFF, &cx);
            tnx_read_i32(client + TNX_CLIENT_POS_Y_OFF, &cy);
        }

        tnx_read_i32(tnx_client() + TNX_INPUT_K_OFF, &ck);

        TNX_LOGX("frame tick=%llu frame=+%llu qcount=%d mode=%d gate=%d inner=%d in10c=%d(%s) in110=%d(%s) in114=%d client80=%d client84=%d",
                 (unsigned long long)g_tick_2, (unsigned long long)d, tnx_queue_count(NULL),
                 tnx_mode(), tnx_gate(), tnx_inner(), inX, tnx_state_x(inX),
                 inY, tnx_state_y(inY), ck, cx, cy, (unsigned long long)TNX_READER_RVA,
                 TNX_MODE_TARGET, (unsigned long long)TNX_INPUT_X_OFF, TNX_MODE_TARGET,
                 (unsigned long long)TNX_GATE_PTR_OFF, (unsigned)TNX_GATE_BYTE_OFF,
                 (unsigned long long)0xa26890ULL, (unsigned long long)TNX_CLIENT_POS_X_OFF);
    }
}

void tnx_window(int plus) {
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (plus % TNX_FRAME_EVERY) return;
    if (g_window_logs >= 12) return;

    g_window_logs++;

    if (g_scene_object) {
        tnx_read_i32(tnx_client() + TNX_INPUT_X_OFF, &inX);
        tnx_read_i32(tnx_client() + TNX_INPUT_Y_OFF, &inY);
        tnx_read_i32(tnx_client() + TNX_INPUT_K_OFF, &inK);
    }

    TNX_LOGX("window tick=+%d qcount=%d in10c=%d in110=%d in114=%d want=(%d,%d) match=%d",
             plus, tnx_queue_count(NULL), inX, inY, inK, g_enq_x, g_enq_y,
             tnx_fields(), TNX_FRAME_EVERY);
}

void tnx_test(const tnx_obj_t *objects, int usable, int ownIndex) {
    int32_t x = 0;
    int32_t y = 0;
    int qnow = -1;
    const char *verdict = "readback-unreadable";

    if (!objects || usable <= 0) return;
    if (g_test_state_2 >= 4) return;
    if (!g_scene_object) return;

    if (ownIndex < 0 || ownIndex >= usable) ownIndex = 0;

    if (!g_test_tickbase) g_test_tickbase = g_tick_2;

    {
        int mode = tnx_mode();

        if (mode > g_mode_max) g_mode_max = mode;
        if (mode == TNX_MODE_TARGET) g_mode_seen7 = 1;
        if (tnx_gate() == 1) g_gate_seen = 1;
    }

    if (!TNX_TEST_ENABLE) {
        if (g_test_state_2 == 0 && (g_tick_2 - g_test_tickbase) >= TNX_MODE_WAIT) {
            g_test_state_2 = 4;
            g_tested_2 = 1;

            TNX_LOGX("notest mode_max=%d saw7=%d gateSeen=%d gate=%d",
                     g_mode_max, g_mode_seen7, g_gate_seen, tnx_gate(),
                     (unsigned long long)TNX_READER_RVA, TNX_MODE_TARGET,
                     (unsigned long long)0xa26890ULL);
        }

        return;
    }

    if (g_test_state_2 == 0) {

        g_test_state_2 = 1;
        g_test_tick = g_tick_2;
        g_test_before_x = objects[ownIndex].x;
        g_test_before_y = objects[ownIndex].y;

        tnx_chain();

        if (!tnx_witness(&g_wit_x0, &g_wit_y0)) {
            g_wit_x0 = objects[ownIndex].x;
            g_wit_y0 = objects[ownIndex].y;
        } else {
            g_have_wit = 1;
        }

        g_wit_elem = objects[ownIndex].object;
        g_wit_x1 = objects[ownIndex].x;
        g_wit_y1 = objects[ownIndex].y;
        g_calls = 0;
        g_moves = 0;
        g_elem_moves = 0;

        g_enq_x = g_wit_x0 + TNX_DX;
        g_enq_y = g_wit_y0 + TNX_DY;

        if (TNX_MODE == TNX_MODE_CHAIN) {
            g_test_state_2 = 4;
            g_tested_2 = 1;

            TNX_LOGX("chain-only mode=%d own=%p ownFromWitness=(%d,%d) elem=%p elemPos=(%d,%d) slotOwn=%p slotIdx=%d slotGid=%d expect=%d queue=%d",
                     TNX_MODE, (void *)tnx_own_obj(), g_wit_x0, g_wit_y0,
                     (void *)g_wit_elem, g_wit_x1, g_wit_y1, (void *)g_own_slot,
                     g_own_slot_idx, g_own_slot_gid, TNX_OWN_EXPECT_GID,
                     tnx_queue_count(NULL), (unsigned long long)TNX_CTRL_RAW_X_OFF);

            return;
        }

        g_active = 1;

        g_scene_before_x = 0;
        g_scene_before_y = 0;

        if (g_scene_object) {
            tnx_read_i32(tnx_client() + TNX_INPUT_X_OFF, &g_scene_before_x);
            tnx_read_i32(tnx_client() + TNX_INPUT_Y_OFF, &g_scene_before_y);
        }

        g_watch_from = 0;
        g_watch_logs = 0;

        g_pre_reloads = g_reloads;
        g_pre_frames = g_ticks_3;

        g_push_frame_2 = g_ticks_3;
        g_win_stage = 0;
        g_win_reloads = g_reloads;

        if (TNX_MODE == TNX_MODE_BOTH) {
            tnx_enqueue(g_enq_x, g_enq_y);

            g_q_before = g_q_before_2;
            g_q_after = g_q_after_2;
        }

        tnx_setter(g_enq_x + TNX_DX_SETTER, g_enq_y + TNX_DY_SETTER);
        tnx_elem_write(objects[ownIndex].object,
                            g_enq_x + TNX_DX_ELEM, g_enq_y + TNX_DY_ELEM);

        tnx_probe();
        tnx_actuate();

        TNX_LOGX("test mode=%d pair=(%d,%d) enum dest=(%d,%d) enq=%d seq %d->%d q %d->%d qLast=%p | write=%d setter=%d scene=%p rawOff=%#llx setterFn=%#llx own=%p | witnesses elem=%p (%d,%d) interp=(%d,%d)",
                 TNX_MODE, g_enq_x, g_enq_y, g_wit_x0, g_wit_y0,
                 g_wit_x0 + TNX_DX, g_wit_y0 + TNX_DY,
                 g_enq_ok, g_seq_before, g_seq_after, g_q_before_2, g_q_after_2,
                 g_q_last, (void *)g_scene_object,
                 (unsigned long long)TNX_CTRL_RAW_X_OFF,
                 (unsigned long long)TNX_SETPRED4_RVA, (void *)tnx_own_obj(),
                 (void *)g_wit_elem, g_wit_x1, g_wit_y1, g_wit_x0, g_wit_y0,
                 TNX_MODE_WRITE, TNX_MODE_SETTER, TNX_MODE_BOTH);

        tnx_window(0);

        return;
    }

    if (g_test_state_2 == 1) {
        int plus = (int)(g_tick_2 - g_test_tick);

        tnx_actuate();
        tnx_witness_line(plus);

        if (g_readback < 0 && tnx_fields() == 1) {
            g_readback = 1;
            g_readback_tick = plus;
        }

        if (plus < TNX_READBACK_TICKS) {
            tnx_window(plus);

            return;
        }

        tnx_readback(plus);

        g_test_state_2 = 2;

        if (g_readback < 0) g_readback = 0;

        qnow = tnx_queue_count(NULL);

        TNX_LOGX("test short before=(%d,%d) after=(%d,%d) qAfter=%d qNow=%d readback=%d atTick=%d",
                 g_test_before_x, g_test_before_y, objects[ownIndex].x, objects[ownIndex].y,
                 g_q_after, qnow, g_readback, g_readback_tick,
                 (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

        return;
    }

    if (g_tick_2 - g_test_tick < TNX_LONG_TICKS) {
        tnx_actuate();
        tnx_witness_line((int)(g_tick_2 - g_test_tick));

        return;
    }

    g_test_state_2 = 4;
    g_tested_2 = 1;
    g_active = 0;

    x = objects[ownIndex].x;
    y = objects[ownIndex].y;
    g_test_after_x_2 = x;
    g_test_after_y_2 = y;
    g_moved_2 = (x != g_test_before_x || y != g_test_before_y) ? 1 : 0;
    g_moved2_2 = g_moved_2;
    g_kept_2 = (g_readback == 1 && tnx_fields() == 1) ? 1 : 0;

    if (tnx_fields() < 0) {
        verdict = "readback-unreadable";
    } else if (g_q_before >= 0 && g_q_after >= 0 && g_q_after <= g_q_before) {
        verdict = "enqueue-failed";
    } else if (g_readback == 0 && g_gate_seen == 0) {
        verdict = "reader-gated";
    } else if (g_readback == 0) {
        verdict = "enqueue-ok-not-consumed";
    } else if (g_readback == 1 && !g_kept_2) {
        verdict = "client-only";
    } else if (g_readback == 1 && g_kept_2) {
        verdict = "real";
    }

    TNX_LOGX("summary calls=%d haveWit=%d interp=(%d,%d) interpMoves=%lld elem=%p elemPos=(%d,%d) elemMoves=%lld ownFlag=%d ownPair=(%d,%d)",
             g_calls, g_have_wit, g_wit_x0, g_wit_y0, (long long)g_moves,
             (void *)g_wit_elem, g_wit_x1, g_wit_y1, (long long)g_elem_moves,
             g_own_flag, g_own_held_x, g_own_held_y,
             (unsigned long long)TNX_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_CLIENT_POS_Y_OFF,
             (unsigned long long)TNX_SETPRED4_RVA);

    TNX_LOGX("test long before=(%d,%d) after2=(%d,%d) moved=%d kept=%d verdict=%s mode_max=%d saw7=%d gateSeen=%d gate1=%d gate2=%d qBefore=%d qAfter=%d qNow=%d readback=%d atTick=%d rowCount=%d",
             g_test_before_x, g_test_before_y, x, y, g_moved_2, g_kept_2, verdict,
             g_mode_max, g_mode_seen7, g_gate_seen,
             (tnx_mode() == TNX_MODE_TARGET) ? 1 : 0, (tnx_inner() == 1) ? 1 : 0,
             g_q_before, g_q_after, tnx_queue_count(NULL), g_readback,
             g_readback_tick, usable);
}

void tnx_queue_line(void) {
    uintptr_t mgr = 0;
    int count = tnx_queue_count(&mgr);
    int32_t inX = 0;
    int32_t inY = 0;
    int32_t inK = 0;

    if (g_tick_2 % TNX_QUEUE_EVERY) return;
    if (g_queue_logs >= 240) return;

    g_queue_logs++;

    if (g_queue_logs == 1) {
        TNX_LOGX("statics: reader branch %#llx sits in the mode update %#llx which is a per frame "
                 "update called from exactly one site %#llx as mode->update(dt, elapsed) with x0 = "
                 "[obj+0x28], so the +0xac branch is not dead code and consumed=0 can only mean the "
                 "branch gates closed on this object; the object forwarded to %#llx is the loop body at "
                 "0xac277c stored to the local [sp+0x40] and reloaded into x22 and then x25, so it is the "
                 "iterated battle entity and not a fixed offset on the scene",
                 (unsigned long long)TNX_READER_RVA,
                 (unsigned long long)TNX_READER_ENTRY_RVA,
                 (unsigned long long)TNX_READER_CALLER_RVA,
                 (unsigned long long)0x9fe350ULL);
    }

    if (g_scene_object) {
        tnx_read_i32(tnx_client() + TNX_INPUT_X_OFF, &inX);
        tnx_read_i32(tnx_client() + TNX_INPUT_Y_OFF, &inY);
        tnx_read_i32(tnx_client() + TNX_INPUT_K_OFF, &inK);
    }

    TNX_LOGX("queue tick=%llu count=%d mode=%d gate=%d mgr=%p sceneState=%d flags=%llu ac=%d in10c=%d in110=%d in114=%d resetSentinel=%d",
             (unsigned long long)g_tick_2, count, tnx_mode(), tnx_gate(), (void *)mgr,
             g_prev_state, (unsigned long long)g_enqueues, tnx_read_flag(), inX, inY, inK,
             (inY == -1) ? 1 : 0, (unsigned long long)TNX_READER_RVA,
             (unsigned long long)TNX_ADDINPUT_RVA, (unsigned)0x528);
}

uint64_t g_tick_2 = 0;

void tnx_players_dump(uintptr_t players, uintptr_t array, int32_t count,
                                 int32_t capacity) {
    if (!players) return;

    TNX_LOGX("players dump players=%p array=%p count=%d cap=%d - this is the object the engine "
             "passes to 0x991440 after reading scene+%#llx", (void *)players, (void *)array, count,
             capacity, (unsigned long long)TNX_MODE_MANAGER_OFF);

    for (int i = 0; i < TNX_DUMP_QWORDS; i++) {
        uintptr_t at = players + (uintptr_t)i * 8;
        uint64_t word = tnx_word_2(at);
        const char *seg = tnx_image_segment_name((uintptr_t)word);

        TNX_LOGX("players +%02x = %#018llx seg=%s", i * 8, (unsigned long long)word,
                 seg ? seg : "-");
    }

    TNX_LOGX("players+%#llx is not followed any more - the chain through 0x991440 (ldr "
             "x0,[x0,%#llx]) and then +%#llx dead-ends in a block whose first word is itself and "
             "whose rest is zero, so the object container is players+%#llx and nothing is read "
             "past it", (unsigned long long)TNX_PLAYERS_NEXT_OFF,
             (unsigned long long)TNX_PLAYERS_NEXT_OFF,
             (unsigned long long)TNX_NEXT_MEMBER_OFF, (unsigned long long)TNX_MGR_ARRAY_OFF);
}

void tnx_hop_dump(uintptr_t client, uintptr_t inner) {
    struct {
        const char *what;
        uintptr_t object;
    } hop[TNX_HOPS] = { { 0, 0 }, { 0, 0 } };

    if (g_hop_dumps >= TNX_HOP_DUMPS) return;

    g_hop_dumps++;

    hop[0].what = "client scene+0x28";
    hop[0].object = client;
    hop[1].what = "inner client+0x28";
    hop[1].object = inner;

    for (int h = 0; h < TNX_HOPS; h++) {
        void *vt = NULL;
        int32_t count = 0;
        int32_t cap = 0;
        const char *reason = NULL;

        if (!hop[h].object) continue;

        tnx_read_ptr(hop[h].object, &vt);

        reason = tnx_header_reason(hop[h].object, &count, &cap);

        TNX_LOGX("hopdump %s object=%p vt=%p seg=%s header=%s count=%d cap=%d - the two hops "
                 "differ by exactly one +%#llx dereference, so the vt tells which of them is a "
                 "heterogeneous client and which is a container",
                 hop[h].what, (void *)hop[h].object, vt,
                 tnx_image_segment_name((uintptr_t)vt), reason ? reason : "ok", count, cap,
                 (unsigned long long)TNX_CLIENT_HOP_OFF);

        for (int i = 0; i < 16; i++) {
            uintptr_t at = hop[h].object + (uintptr_t)i * 8;
            uint64_t word = tnx_word_2(at);
            const char *seg = tnx_image_segment_name((uintptr_t)word);

            TNX_LOGX("hopdump %s +%02x = %#018llx seg=%s", hop[h].what, i * 8,
                     (unsigned long long)word, seg ? seg : "-");
        }
    }
}

void tnx_team_dump(const tnx_obj_t *objects, int usable) {
    int limit = usable < TNX_TEAM_DUMPS ? usable : TNX_TEAM_DUMPS;

    for (int i = 0; i < limit; i++) {
        uint8_t bytes[16];
        int32_t i32_40 = 0;
        int32_t i32_44 = 0;
        int32_t i32_48 = 0;
        int32_t i32_4c = 0;

        if (!tnx_read_bytes(objects[i].object + TNX_OBJ_TEAM_OFF, bytes, sizeof(bytes))) continue;

        memcpy(&i32_40, bytes + 0, 4);
        memcpy(&i32_44, bytes + 4, 4);
        memcpy(&i32_48, bytes + 8, 4);
        memcpy(&i32_4c, bytes + 12, 4);

        TNX_LOGX("teamdump elem[%d] +40..+50 = %02x %02x %02x %02x | %02x %02x %02x %02x | "
                 "%02x %02x %02x %02x | %02x %02x %02x %02x  i32: 40=%d 44=%d 48=%d 4c=%d  "
                 "byte@40=%u byte@48=%u byte@4c=%u byte@4d=%u",
                 i, bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14],
                 bytes[15], i32_40, i32_44, i32_48, i32_4c, (unsigned)bytes[0], (unsigned)bytes[8],
                 (unsigned)bytes[12], (unsigned)bytes[13]);
    }
}

void tnx_class_dump(const tnx_obj_t *objects, int usable) {
    uintptr_t classes[TNX_CLASS_DUMPS];
    int classCount = 0;

    if (g_class_dumps >= TNX_CLASS_DUMPS) return;

    for (int i = 0; i < usable && classCount < TNX_CLASS_DUMPS; i++) {
        void *vt = NULL;
        uintptr_t rva = 0;
        int known = 0;

        if (!tnx_read_ptr(objects[i].object, &vt) || !vt) continue;
        if ((uintptr_t)vt < g_base) continue;

        rva = (uintptr_t)vt - g_base;

        for (int k = 0; k < classCount; k++) {
            if (classes[k] == rva) known = 1;
        }

        if (!known) classes[classCount++] = rva;
    }

    for (int c = 0; c < classCount; c++) {
        int shown = 0;

        g_class_dumps++;

        for (int i = 0; i < usable && shown < 4; i++) {
            void *vt = NULL;
            uint64_t words[TNX_CLASS_QWORDS];

            if (!tnx_read_ptr(objects[i].object, &vt) || !vt) continue;
            if ((uintptr_t)vt < g_base) continue;
            if ((uintptr_t)vt - g_base != classes[c]) continue;
            if (!tnx_read_bytes(objects[i].object + 0xc0ULL, words, sizeof(words))) continue;

            shown++;

            TNX_LOGX("classdump class=%#llx elem[%d] gid=%d +c0=%#llx +c8=%#llx +d0=%#llx "
                     "+d8=%#llx - each class is dumped on its own line, so a projectile cannot "
                     "supply the value that decides whether a player is dead",
                     (unsigned long long)classes[c], i, objects[i].gid,
                     (unsigned long long)words[0], (unsigned long long)words[1],
                     (unsigned long long)words[2], (unsigned long long)words[3]);
        }

        if (!shown) {
            TNX_LOGX("classdump class=%#llx has no element readable in this container",
                     (unsigned long long)classes[c]);
        }
    }
}

int tnx_slot_probe(void) {
    static const uintptr_t slots[TNX_SLOTS] = { TNX_MODE_SLOT_A, TNX_MODE_SLOT_B,
                                                    TNX_MODE_SLOT_C };
    uintptr_t array = g_players_array;
    int32_t count = g_players_count;
    int hit = -1;

    if (!g_scene_object) return -1;
    if (!array || count <= 0) return -1;

    for (int i = 0; i < TNX_SLOTS; i++) {
        void *value = NULL;
        void *vt = NULL;
        uintptr_t rva = 0;
        int inArray = 0;

        if (!tnx_read_ptr(g_scene_object + slots[i], &value) || !value) {
            if (!g_slot_dumped) {
                TNX_LOGX("modeslot +%#llx=null array=%p count=%d - the three words the mode "
                         "carries at +%#llx/+%#llx/+%#llx are tested against the container on "
                         "every tick until one of them points at an element",
                         (unsigned long long)slots[i], (void *)array, count,
                         (unsigned long long)TNX_MODE_SLOT_A, (unsigned long long)TNX_MODE_SLOT_B,
                         (unsigned long long)TNX_MODE_SLOT_C);
            }

            continue;
        }

        if ((uintptr_t)value > array && (uintptr_t)value < array + (uintptr_t)count * 8ULL) {
            inArray = 1;
            hit = i;
        }

        if (g_base && tnx_read_ptr((uintptr_t)value, &vt) && (uintptr_t)vt > g_base) {
            rva = (uintptr_t)vt - g_base;
        }

        if (!g_slot_dumped) {
            TNX_LOGX("modeslot +%#llx=%p vt=%#llx inArray=%d array=%p count=%d - inArray=1 "
                     "means this word is one of the container's own elements and so is the local "
                     "player, which is the own element the dodge has been unable to name",
                     (unsigned long long)slots[i], (void *)value, (unsigned long long)rva, inArray,
                     (void *)array, count);
        }
    }

    g_slot_dumped = 1;

    return hit;
}

void tnx_pos_trace(const tnx_obj_t *objects, int usable) {
    int i;

    if (!objects || usable <= 0) return;
    if (usable > TNX_OBJECT_MAX) usable = TNX_OBJECT_MAX;

    for (i = 0; i < g_trace_n && i < usable; i++) {
        if (g_trace_obj[i] != objects[i].object) continue;
        if (g_trace_x[i] == objects[i].x && g_trace_y[i] == objects[i].y) continue;

        if (g_trace_logs < TNX_TRACE_MAX) {
            g_trace_logs++;
            TNX_LOGX("pos gid=%d d=(%+d,%+d) from=(%d,%d) to=(%d,%d) own=%d",
                     objects[i].gid, objects[i].x - g_trace_x[i],
                     objects[i].y - g_trace_y[i], g_trace_x[i], g_trace_y[i],
                     objects[i].x, objects[i].y,
                     (objects[i].object == g_own_ptr_2) ? 1 : 0);
        }
    }

    g_trace_n = usable;

    for (i = 0; i < usable; i++) {
        g_trace_obj[i] = objects[i].object;
        g_trace_x[i] = objects[i].x;
        g_trace_y[i] = objects[i].y;
    }
}

void tnx_write_test(const tnx_obj_t *objects, int usable, int ownIndex) {
    int32_t curX = 0;
    int32_t curY = 0;
    int wantX = 0;
    int wantY = 0;

    g_tick++;

    if (!TNX_WRITE_TEST) return;
    if (!g_scene_object) return;

    tnx_pos_trace(objects, usable);

    if (g_write_count >= TNX_WRITE_TICKS) return;
    if (g_tick - g_write_last < TNX_WRITE_EVERY) return;

    g_write_last = g_tick;

    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTX_OFF, &curX) ||
        !tnx_read_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTY_OFF, &curY)) {
        TNX_LOGX("wtest cannot read mode+%#llx/+%#llx",
                 (unsigned long long)TNX_MODE_PREDICTX_OFF,
                 (unsigned long long)TNX_MODE_PREDICTY_OFF);
        return;
    }

    if (!g_write_base_ok && curX != 0 && curY != 0) {
        g_write_base_ok = 1;
        g_write_base_x = curX;
        g_write_base_y = curY;
    }

    g_write_phase = g_write_phase ? 0 : 1;
    wantX = (g_write_base_ok ? g_write_base_x : curX) +
            (g_write_phase ? TNX_WRITE_STEP : 0);
    wantY = (g_write_base_ok ? g_write_base_y : curY) +
            (g_write_phase ? TNX_WRITE_STEP : 0);

    if (g_setpred_2) {
        ((void (*)(void *, int, int))g_setpred_2)((void *)g_scene_object, wantX, wantY);
    } else {
        tnx_write_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTX_OFF, wantX);
        tnx_write_i32((uintptr_t)g_scene_object + TNX_MODE_PREDICTY_OFF, wantY);
    }

    g_write_count++;

    TNX_LOGX("wtest #%d mode=%p phase=%d base=(%d,%d) read=(%d,%d) wrote=(%d,%d) own=%d "
             "setpred=%p - the write goes through the verified leaf setter at rva %#llx that "
             "stores straight into +%#llx and +%#llx",
             g_write_count, (void *)g_scene_object, g_write_phase,
             g_write_base_x, g_write_base_y, curX, curY, wantX, wantY, ownIndex,
             (void *)g_setpred_2, (unsigned long long)TNX_SETPRED_RVA,
             (unsigned long long)TNX_MODE_PREDICTX_OFF,
             (unsigned long long)TNX_MODE_PREDICTY_OFF);
}

void tnx_audit_all(void) {
    int i;

    if (g_audited || !g_base) return;

    g_audited = 1;

    TNX_LOGX("audit tag=%s entries=%d - every row of the rva table the engine can reach is "
             "tested here, entry means the four bytes at the rva open a frame or the word before "
             "them is a return, callable is the engine test that a call site needs",
             TNX_BUILD_TAG, (int)(sizeof(g_rvas) / sizeof(g_rvas[0])) - 1);

    for (i = 0; g_rvas[i].name; i++) {
        uintptr_t a = g_base + g_rvas[i].rva;
        uint32_t w = 0;
        uint32_t wm = 0;
        const char *rule = tnx_prologue_rule(a);

        tnx_word(a, &w);
        tnx_word(a - 4, &wm);

        TNX_LOGX("audit %-52s rva=%#llx word=%#x prev=%#x rule=%-9s entry=%s callable=%s",
                 g_rvas[i].name, (unsigned long long)g_rvas[i].rva, (unsigned)w, (unsigned)wm,
                 rule ? rule : "?", tnx_entry(g_rvas[i].rva) ? "yes" : "no",
                 (tnx_callable(g_rvas[i].rva) && tnx_looks_like_start(a)) ? "yes" : "no");
    }

    TNX_LOGX("anchors getTeamStars=%#llx setpred=%#llx modePairSet=%#llx tileLookup=%#llx "
             "subGetter=%#llx - these five are the ones the disassembly of this build confirmed",
             (unsigned long long)TNX_GETTEAMSTARS_RVA,
             (unsigned long long)TNX_SETPRED_RVA,
             (unsigned long long)TNX_MODEPAIRSET_RVA_2,
             (unsigned long long)TNX_TILELOOKUP_RVA,
             (unsigned long long)TNX_SUBGETTER_RVA);
}

void tnx_statics(void) {
    static int done = 0;

    if (done) return;

    done = 1;

    TNX_LOGX("statics, read out of the binary instead of assumed: the apply gate the queue feeds is "
             "NOT a mode id - %#llx is 'ldrb w8,[rcv+%#llx]; cmp w8,#1; b.ne' and the flag it tests is "
             "written by the setter %#llx itself as 'strb 1', so path (b) opens that door by construction "
             "while a queue message never reaches it; the applier behind the gate is %#llx, which reads "
             "the pair from +%#llx/+%#llx, takes the target from [rcv+%#llx] and calls %#llx; the "
             "cmp-against-7 that the plan hunted lives in the SCENE class %#llx slots +0x50 and +0x68 "
             "(%#llx and %#llx read [this+%#llx] against 7) and has nothing to do with the input path; "
             "the queue drain %#llx pops the tail while msg[+%#llx] <= manager+%#llx and then frees the "
             "message through %#llx without applying it, so the queue is the buffer that goes out to the "
             "server and never the local apply path; the second setter %#llx has exactly one caller, "
             "%#llx, which is the resource loader, so it is construction state and not an actuator",
             (unsigned long long)TNX_READER_RVA, (unsigned long long)TNX_GATE_FLAG_OFF,
             (unsigned long long)TNX_SETPRED4_RVA, (unsigned long long)0x9fe350ULL,
             (unsigned long long)TNX_GATE_X_OFF, (unsigned long long)TNX_GATE_Y_OFF,
             (unsigned long long)TNX_BOX_PTR_OFF, (unsigned long long)0x9fe4a4ULL,
             (unsigned long long)0xfe9d00ULL, (unsigned long long)0x8c7f9cULL,
             (unsigned long long)0x8c7fbcULL, (unsigned long long)0xcULL,
             (unsigned long long)0x746d18ULL, (unsigned long long)TNX_SEQ_OFF,
             (unsigned long long)0x10ULL, (unsigned long long)0xd8d9f0ULL,
             (unsigned long long)0xac3f20ULL, (unsigned long long)0xa26520ULL);
}

void tnx_readback(int plus) {
    uintptr_t elem = g_elem;
    int32_t elemX = -1;
    int32_t elemY = -1;
    int32_t ownX = -1;
    int32_t ownY = -1;
    int32_t ownF = -1;
    int32_t sceneX = -1;
    int32_t sceneY = -1;
    int32_t gate = -1;
    int elemHeld = 0;
    int ownHeld = 0;
    int fldHeld = 0;

    if (g_rb_logs >= TNX_READBACK_LOGS) return;

    g_rb_logs++;

    if (elem && tnx_read_i32(elem + TNX_OBJ_X_OFF, &elemX) &&
        tnx_read_i32(elem + TNX_OBJ_Y_OFF, &elemY)) {
        elemHeld = (elemX == g_enq_x + TNX_DX_ELEM &&
                    elemY == g_enq_y + TNX_DY_ELEM) ? 1 : 0;
    }

    if (g_own_obj) {
        tnx_read_i32(g_own_obj + TNX_GATE_X_OFF, &ownX);
        tnx_read_i32(g_own_obj + TNX_GATE_Y_OFF, &ownY);
        tnx_read_i32(g_own_obj + TNX_GATE_FLAG_OFF, &gate);
        tnx_read_i32(g_own_obj + TNX_OWN_OFF, &ownF);
        ownHeld = (ownX == g_enq_x + TNX_DX_SETTER &&
                   ownY == g_enq_y + TNX_DY_SETTER) ? 1 : 0;
    }

    if (g_scene_object) {
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_X_OFF, &sceneX);
        tnx_read_i32((uintptr_t)g_scene_object + TNX_INPUT_Y_OFF, &sceneY);
    }

    fldHeld = tnx_fields();

    if (g_readback < 0) g_readback = 0;

    TNX_LOGX("readback +%d elem=%p held=%d now=(%d,%d) want=(%d,%d) was=(%d,%d) | own=%p "
             "in10c=%d in110=%d held=%d flag%#llx=%d | scene10c=%d scene110=%d fld=%d | q=%d - read a "
             "whole second after the three writes and not four frames later, because a server that "
             "reconciles the position on a short cadence turns a four frame probe into a false success: "
             "elemHeld names path (c) the direct element pair, ownHeld names path (b) the setter %#llx "
             "store on the getOwnCharacter receiver, and the queue count together with the seq counter "
             "names path (a) the message; whichever of the three holds after a second is the actuator",
             plus, (void *)elem, elemHeld, elemX, elemY, g_enq_x + TNX_DX_ELEM,
             g_enq_y + TNX_DY_ELEM, g_elem_x0, g_elem_y0, (void *)g_own_obj,
             ownX, ownY, ownHeld, (unsigned long long)TNX_GATE_FLAG_OFF, gate, sceneX, sceneY,
             fldHeld, tnx_queue_count(NULL), (unsigned long long)TNX_SETPRED4_RVA);

    (void)ownF;
}

void tnx_gate_report(int slotHit) {
    tnx_obj_t objects[TNX_OBJECT_MAX];
    uintptr_t manager = (uintptr_t)g_players_object;
    int rejected = 0;
    int usable = 0;
    int ownIndex = -1;
    int targetIndex = -1;
    int32_t predictX = 0;
    int32_t predictY = 0;
    int ownX = 0;
    int ownY = 0;
    int targetX = 0;
    int targetY = 0;
    int vectorX = 0;
    int vectorY = 0;
    int stepX = 0;
    int stepY = 0;
    int ownTeam = -1;
    int64_t ownBest = 0;
    int64_t targetBest = 0;
    int ownFound = 0;
    int targetFound = 0;
    int threats = 0;
    int inRange = 0;
    int distinct = 0;
    int degenerate = 0;
    int contributors = 0;
    int actPass = 0;
    int actFail = 0;
    int clsProj = 0;
    int clsPlayer = 0;
    int clsOther = 0;
    int modeReal = 0;
    int predictZero = 0;
    int vectorZero = 0;
    uintptr_t modeVt = 0;
    uintptr_t modeChain = 0;
    uintptr_t modeInner = 0;
    const char *ownFrom = "none";
    const char *reason = "none";

    memset(objects, 0, sizeof(objects));

    g_gate_calls++;

    if (g_scene_object) {
        modeReal = tnx_mode_real((uintptr_t)g_scene_object, &modeVt, &modeChain, &modeInner);
    }

    tnx_own_scan();
    tnx_chain();

    if (TNX_MODE == TNX_MODE_CHAIN) {
        g_test_state_2 = 4;
        g_tested_2 = 1;
    }

    if (!g_scene_object) {
        reason = "noScene";
    } else if (!manager || !g_players_array || g_players_count <= 0) {
        reason = "noContainer";
    } else {
        usable = tnx_collect(manager, objects, TNX_OBJECT_MAX, &rejected);
        usable = tnx_inject_own(objects, usable, TNX_OBJECT_MAX);

        if (usable < 2) {
            reason = "usableBelowTwo";
        } else {
            for (int i = 0; i < usable; i++) {
                int seen = 0;

                if (objects[i].x > -TNX_COORD_MAX && objects[i].x < TNX_COORD_MAX &&
                    objects[i].y > -TNX_COORD_MAX && objects[i].y < TNX_COORD_MAX) {
                    inRange++;
                }

                for (int j = 0; j < i; j++) {
                    if (objects[j].x == objects[i].x && objects[j].y == objects[i].y) {
                        seen = 1;
                        break;
                    }
                }

                if (!seen) distinct++;
            }

            degenerate = (distinct < inRange) ? 1 : 0;

            if (!tnx_read_i32(g_scene_object + TNX_MODE_PREDICTX_OFF, &predictX) ||
                !tnx_read_i32(g_scene_object + TNX_MODE_PREDICTY_OFF, &predictY)) {
                predictZero = 0;
            } else if (predictX == 0 && predictY == 0) {
                predictZero = 1;
            }

            ownFound = tnx_own_latch(objects, usable, &ownIndex, &ownFrom);

            if (!ownFound) ownFound = tnx_resolve_own(objects, usable, &ownIndex, &ownFrom);

            if (!ownFound) ownFound = tnx_resolve_own_2(objects, usable, &ownIndex, &ownFrom);

            if (!ownFound) ownFound = tnx_take_own(objects, usable, &ownIndex, &ownFrom);

            if (ownFound && ownIndex >= 0 && ownIndex < usable) {
                tnx_phase("own");

        tnx_publish_own(objects[ownIndex].object, ownFrom);
            }

            tnx_write_test(objects, usable, ownFound ? ownIndex : -1);

            tnx_hop2();
            tnx_test(objects, usable, ownFound ? ownIndex : -1);
            tnx_statics();
        }
    }

    if (ownFound) {
        ownX = objects[ownIndex].x;
        ownY = objects[ownIndex].y;
        ownTeam = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                           : objects[ownIndex].teamNew;

        for (int i = 0; i < usable; i++) {
            int team = 0;
            int64_t edx = 0;
            int64_t edy = 0;
            int64_t ed = 0;

            if (i == ownIndex) continue;

            team = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                            : objects[i].teamNew;
            if (team == ownTeam) continue;

            edx = (int64_t)objects[i].x - (int64_t)ownX;
            edy = (int64_t)objects[i].y - (int64_t)ownY;
            ed = edx * edx + edy * edy;
            threats++;

            if (!targetFound || ed < targetBest) {
                targetFound = 1;
                targetBest = ed;
                targetIndex = i;
            }
        }

        if (targetFound) {
            float escapeX = 0.0f;
            float escapeY = 0.0f;

            targetX = objects[targetIndex].x;
            targetY = objects[targetIndex].y;
            vectorX = targetX - ownX;
            vectorY = targetY - ownY;

            for (int i = 0; i < usable; i++) {
                int team = 0;
                float fdx = 0.0f;
                float fdy = 0.0f;
                float fd = 0.0f;

                if (i == ownIndex) continue;

                team = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                                : objects[i].teamNew;
                if (team == ownTeam) continue;

                {
                    void *pvt = NULL;
                    int isProj = (tnx_read_ptr((uintptr_t)objects[i].object, &pvt) && pvt &&
                                  ((uintptr_t)pvt - g_base) == (uintptr_t)TNX_CLASS_PROJ_RVA);

#if TNX_PROJ_ACTIVE_BYPASS
                    if (isProj) {
                        actPass++;
                    } else if (objects[i].dead) {
                        actFail++;

                        continue;
                    } else {
                        actPass++;
                    }
#else
                    (void)isProj;

                    if ((objects[i].activeFlag & 1) == 0) {
                        actFail++;

                        continue;
                    }

                    actPass++;
#endif
                }

                {
                    void *cvt = NULL;
                    intptr_t cls = 0;

                    if (tnx_read_ptr((uintptr_t)objects[i].object, &cvt) && cvt) {
                        cls = (intptr_t)((uintptr_t)cvt - g_base);
                    }

                    if (cls == (intptr_t)TNX_CLASS_PROJ_RVA) clsProj++;
                    else if (cls == (intptr_t)TNX_CLASS_PLAYER_RVA || cls == (intptr_t)TNX_CLASS_PLAYER2_RVA) clsPlayer++;
                    else clsOther++;

#if TNX_DODGE_PROJ_ONLY
                    if (cls != (intptr_t)TNX_CLASS_PROJ_RVA) continue;
#endif
                }

                fdx = (float)(ownX - objects[i].x);
                fdy = (float)(ownY - objects[i].y);
                fd = fdx * fdx + fdy * fdy;

                if (fd < 1.0f) continue;

                escapeX += fdx / (sqrtf(fd) + 1.0f);
                escapeY += fdy / (sqrtf(fd) + 1.0f);
                contributors++;
            }

            if (contributors > 0) {
                float length = sqrtf(escapeX * escapeX + escapeY * escapeY);

                if (length <= 0.0001f) {
                    vectorZero = 1;
                } else {
                    escapeX /= length;
                    escapeY /= length;

                    stepX = ownX + (int)(escapeX * DODGE_STEP);
                    stepY = ownY + (int)(escapeY * DODGE_STEP);
                }
            }
        }
    }

    if (strcmp(reason, "none") == 0 && !g_mgr) {
        reason = "noInputMgr";
    } else if (strcmp(reason, "none") == 0 && !ownFound) {
        reason = "noOwn";
    } else if (strcmp(reason, "none") == 0 && !g_tested_2) {
        reason = "actuatorNotTested";
    } else if (strcmp(reason, "none") == 0 && !targetFound) {
        reason = "noTarget";
    } else if (strcmp(reason, "none") == 0 && !modeReal) {
        reason = "modeGuard";
    } else if (strcmp(reason, "none") == 0 && !g_coord_ok) {
        reason = "noCoords";
    } else if (strcmp(reason, "none") == 0 && !g_setpred_state) {
        reason = "noActuator";
    } else if (strcmp(reason, "none") == 0 && predictZero) {
        reason = "predictionZero";
    } else if (strcmp(reason, "none") == 0 && contributors <= 0) {
        reason = "noThreat";
    } else if (strcmp(reason, "none") == 0 && vectorZero) {
        reason = "degenerateVector";
    } else if (strcmp(reason, "none") == 0) {
        reason = "ready";
    }

    {
        void *mgr = NULL;
        void *arr = NULL;
        void *firstE = NULL;
        void *tm = NULL;

        if (tnx_read_ptr((uintptr_t)g_scene_object + TNX_MGR_OFF, &mgr) && mgr) {
            if (tnx_read_ptr((uintptr_t)mgr + TNX_MGR_ARRAY_OFF, &arr) && arr) {
                tnx_read_ptr((uintptr_t)arr, &firstE);
            }

            tnx_read_ptr((uintptr_t)mgr + TNX_MODE_TILEMAP_OFF, &tm);
        }

        TNX_LOGX("own check: elem=%p latched=%p elem1=%p tilemap=%p mgr=%p",
                 (void *)(ownFound ? objects[ownIndex].object : 0), (void *)g_own_ptr_2, firstE, tm, mgr);
    }

    TNX_LOGX("dodge gates: ownFound=%d own=%p ownFrom=%s ownOff=%#llx ownTeam=%d "
             "targetFound=%d target=%p selfPos=(%d,%d) targetPos=(%d,%d) vector=(%d,%d) "
             "clamped=(%d,%d) actuatorReached=%d reason=%s usable=%d rejected=%d threats=%d "
             "contributors=%d actPass=%d actFail=%d clsProj=%d clsPlayer=%d clsOther=%d "
             "inRange=%d distinct=%d degenerate=%d slotHit=%d hop=%d "
             "modeReal=%d modeVt=%#llx modeChain=%p modeInner=%p deadF=%d teamOff=%#llx "
             "testWrites=%llu writes=%llu - the reason is assigned in the order own, target, "
             "guard, coords, actuator, prediction, so a writes=0 names the first gate that is "
             "closed instead of reporting the last one, and deadF tells whether the dead filter is "
             "applied at all",
             ownFound, (void *)(ownFound ? objects[ownIndex].object : 0), ownFrom,
             (unsigned long long)g_own_off, ownTeam, targetFound,
             (void *)(targetFound ? objects[targetIndex].object : 0), ownX, ownY, targetX, targetY,
             vectorX, vectorY, stepX, stepY, g_setpred_state == 1 ? 1 : 0, reason, usable,
             rejected, threats, contributors, actPass, actFail, clsProj, clsPlayer, clsOther,
             inRange, distinct,
             degenerate, slotHit,
             g_hop_chosen, modeReal, (unsigned long long)modeVt, (void *)modeChain,
             (void *)modeInner, TNX_DEAD_FILTER, (unsigned long long)g_team_off,
             (unsigned long long)g_test_writes, (unsigned long long)g_writes_3);
}

void tnx_map_dump(uintptr_t bounds) {
    int32_t v[12];
    uintptr_t q[8];
    char line[256];
    int i;
    int used = 0;
    int r;

    if (g_map_dumps >= TNX_MAP_DUMPS) return;
    if (!bounds) return;

    g_map_dumps++;

    for (i = 0; i < 12; i++) {
        v[i] = -1;
        tnx_read_i32(bounds + (uintptr_t)i * 4ULL, &v[i]);
    }

    for (i = 0; i < 8; i++) {
        void *p = NULL;

        q[i] = 0;

        if (tnx_read_ptr(bounds + 0x30ULL + (uintptr_t)i * 8ULL, &p) && p) q[i] = (uintptr_t)p;
    }

    r = snprintf(line, sizeof(line),
                 "map obj=%p i32[0..0x2c]=%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
                 (void *)bounds, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10],
                 v[11]);

    if (r > 0) {
        line[sizeof(line) - 1] = '\0';
        tnx_write_line(line);
    }

    used = snprintf(line, sizeof(line),
                    "map obj=%p q[0x30..0x68]=%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx,%#llx",
                    (void *)bounds, (unsigned long long)q[0], (unsigned long long)q[1],
                    (unsigned long long)q[2], (unsigned long long)q[3], (unsigned long long)q[4],
                    (unsigned long long)q[5], (unsigned long long)q[6], (unsigned long long)q[7]);

    if (used > 0) {
        line[sizeof(line) - 1] = '\0';
        tnx_write_line(line);
    }
}

void tnx_slot_line(const char *name, const tnx_win_t *w, int slot,
                               uint32_t before, uint32_t after) {
    float was = 0.0f;
    float now = 0.0f;

    memcpy(&was, &before, sizeof(was));
    memcpy(&now, &after, sizeof(now));

    TNX_LOGX("%s +%#x float %+.4f -> %+.4f int %d -> %d hot=%u - one slot of the %#x byte "
             "window that differs from the previous second; hot is how many snapshots this slot has "
             "moved in while the base stayed the same, so a field that follows a dragged stick "
             "outranks scenery and is printed first",
             name, (unsigned)(slot * 4), (double)was, (double)now, (int32_t)before, (int32_t)after,
             (unsigned)w->hot[slot], (unsigned)TNX_WIN);
}

int tnx_trail_verdict(const tnx_trail_t *entry, char *buf, size_t size) {
    char parts[64];
    size_t used = 0;

    parts[0] = 0;

    if (!entry->rawOk) tnx_append(parts, sizeof(parts), &used, "image");
    if (entry->refused == 1) tnx_append(parts, sizeof(parts), &used, "ascii");
    if (entry->refused == 2) tnx_append(parts, sizeof(parts), &used, "weak");
    if (entry->refused == 3) tnx_append(parts, sizeof(parts), &used, "noVt");
    if (entry->teamDistinct < 2) tnx_append(parts, sizeof(parts), &used, "noTeam");
    if (entry->posDistinct < 2) tnx_append(parts, sizeof(parts), &used, "noPos");

    if (!used) return 1;

    snprintf(buf, size, "%s", parts);

    return 0;
}
