#include "titanox.h"

FILE *tnx_log_handle(void) {
    if (!g_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"Titanox.log"];
            g_log = fopen(logPath.UTF8String, "a");
        }

        if (g_log) g_battle_capture = YES;
    }

    return g_log;
}

const char *g_log_drop[34] = {
    "players", "walk", "hopdump", "teamdump", "membership",
    "man ", "gid", "coords", "coord", "off",
    "clip", "ownscan", "chain", "player[", "element",
    "classdump", "trail", "state", "modeslot", "hooks",
    "scene", "heap", "fields", "write", "slot",
    "setprediction", "scan", "route", "modesig", "hop",
    "battle", "named", "offsets",
    NULL
};

const char *g_log_keep[8] = {
    "=== ", "plan v", "slot ", "hook",
    "live", "census", "publish",
    NULL
};

uint64_t g_drop_counts[64];

uint64_t g_dropped = 0;

uint64_t g_kept_3 = 0;

uint64_t g_log_rolls = 0;

int tnx_keep_line(const char *text) {
    int i = 0;

    if (!TNX_LOG_FILTER) return 1;
    if (!text) return 0;

    for (i = 0; g_log_keep[i]; i++) {
        if (!g_log_keep[i][0]) continue;
        if (strncmp(text, g_log_keep[i], strlen(g_log_keep[i])) == 0) {
            g_kept_3++;

            return 1;
        }
    }

    for (i = 0; g_log_drop[i] && i < 64; i++) {
        if (!g_log_drop[i][0]) continue;
        if (strncmp(text, g_log_drop[i], strlen(g_log_drop[i])) == 0) {
            g_drop_counts[i]++;
            g_dropped++;

            return 0;
        }
    }

    g_kept_3++;

    return 1;
}

void tnx_log_census(void) {
    const char *worst = NULL;
    uint64_t worstN = 0;
    int i = 0;

    for (i = 0; g_log_drop[i] && i < 64; i++) {
        if (g_drop_counts[i] > worstN) {
            worstN = g_drop_counts[i];
            worst = g_log_drop[i];
        }
    }

    tnx_logf("logfilter kept=%llu dropped=%llu rolls=%llu worst=%s:%llu - a line is written "
             "unless its start matches the drop list, so anything unlisted, including every line "
             "added after this build, is kept by default; a dropped prefix that should not be here "
             "is removed from the list and comes back without a rebuild",
             (unsigned long long)g_kept_3, (unsigned long long)g_dropped,
             (unsigned long long)g_log_rolls, worst ? worst : "-",
             (unsigned long long)worstN);
}

void tnx_log_roll(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDateFormatter *df = NULL;
    NSString *ts = nil;
    NSString *fmt = @"[%@] === drop=20 log rolled over #%llu, the earlier window is dropped here ===\n";
    NSString *marker = nil;

    if (g_log) {
        fclose(g_log);
        g_log = NULL;
    }

    if (paths.count == 0) return;

    g_log = fopen([paths[0] stringByAppendingPathComponent:@"Titanox.log"].UTF8String, "w");

    if (!g_log) return;

    g_log_written = 0;
    g_log_rolls++;

    df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    ts = [df stringFromDate:[NSDate date]];
    marker = [NSString stringWithFormat:fmt, ts, (unsigned long long)g_log_rolls];
    g_log_written += (long)fwrite(marker.UTF8String, 1, strlen(marker.UTF8String), g_log);
    fflush(g_log);
}

void tnx_write_line(const char *text) {
    FILE *handle = NULL;

    if (!text) return;
    if (!tnx_keep_line(text)) return;

    if (g_log_written >= LOG_MAX_BYTES) {
        if (!TNX_LOG_ROLL) return;

        tnx_log_roll();
    }

    handle = tnx_log_handle();

    if (!handle) return;

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *ts = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %s\n", ts, text];
    const char *utf8 = line.UTF8String;
    size_t len = strlen(utf8);

    fwrite(utf8, 1, len, handle);
    fflush(handle);

    g_log_written += (long)len;

    if (g_battle_capture && g_log_written < LOG_MAX_BYTES) {
        tnx_battle_write(utf8, len);
    }
}

void tlog(NSString *msg) {
    if (!msg) return;

    tnx_write_line(msg.UTF8String);
}

void tnx_logf(const char *format, ...) {
    if (!format) return;

    char buffer[2048];
    va_list args;

    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    tnx_write_line(buffer);
}

int g_hb_sig_prev = 0;

int g_image_count = 0;

uintptr_t g_image_top_mgr = 0;

int32_t g_image_top_count = 0;

int g_chain_vtchanged = 0;

int g_chain_stable_logged = 0;

int g_stringy_logs = 0;

int g_battle_active = 0;

int g_battle_last_tick = 0;

const char *g_battle_reason = "none";

void tnx_slot_note(int index, void *self, uint64_t arg1) {
    uint32_t bit = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_first_tick[index]) g_slot_first_tick[index] = g_ticks_4;

    if (!g_slot_object[index] && self) g_slot_object[index] = (uintptr_t)self;

    if (!g_slot_arg1[index] && arg1) g_slot_arg1[index] = (uintptr_t)arg1;

    bit = (uint32_t)(1u << (unsigned)index);

}

void tnx_slot_fired_report(void) {
    uint64_t total = 0;
    int armedCount = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        const char *state = "not-attempted";
        void *current = NULL;
        int armed = 0;

        if (g_slot_installed[i] == 1) {
            armed = 1;
            armedCount++;
            state = (g_slot_slots[i] > 0) ? "armed-pointer" : "armed-noslot";

            if (g_slot_specs[i].slotRva &&
                tnx_read_ptr(g_base + g_slot_specs[i].slotRva, &current)) {
                if ((uintptr_t)current != (uintptr_t)g_slot_specs[i].replacement) {
                    state = "armed-REVERTED";
                }
            }
        } else if (g_slot_installed[i] == TNX_STATE_DROPPED) {
            state = "dropped";
        } else if (g_slot_installed[i] == 0) {
            state = (g_slot_slots[i] > 0) ? "install-failed" : "not-found";
        }

        total += g_slot_hits[i];

        tnx_logf("hook %s %s armed=%d slots=%d slotRva=%#llx this=%p arg1=%p firstCallTick=%llu "
                 "hits=%llu tick=%llu",
                 g_slot_specs[i].shortTag, state, armed, g_slot_slots[i],
                 (unsigned long long)g_slot_specs[i].slotRva, (void *)g_slot_object[i],
                 (void *)g_slot_arg1[i], (unsigned long long)g_slot_first_tick[i],
                 (unsigned long long)g_slot_hits[i], (unsigned long long)g_ticks_4);

        if (i == 6 && g_slot_installed[i] == 1 && g_slot_slots[i] < 100) {
            tnx_logf("hook C2 weak: slots=%d where the 22:36 run had 443 - the target moved or "
                     "the table was rebuilt", g_slot_slots[i]);
        }

        if (i == 12 && g_setpred_calls) {
            tnx_logf("setprediction seen: calls=%llu this=%p target=(%.2f,%.2f)",
                     (unsigned long long)g_setpred_calls, (void *)g_setpred_this,
                     g_setpred_x, g_setpred_y);
        }

        if (g_slot_hits[i] == 0 && g_ticks_4 >= 30 && g_slot_installed[i] == 1) {
            if (!(g_never_dispatched_mask & (1u << (unsigned)i))) {
                if (g_slot_slots[i] > TNX_SLOT_WIDE && g_ticks_4 <= TNX_DROP_TICKS) {
                    continue;
                }

                g_never_dispatched_mask |= (1u << (unsigned)i);

            }
        }
    }

    tnx_logf("hooks total fired=%llu armed=%d of %d slots at tick=%llu", (unsigned long long)total,
             armedCount, TNX_SLOT_COUNT, (unsigned long long)g_ticks_4);

    tnx_logf("trail refusals: stringy=%d image-resident=%d - the two counters replace the line "
             "that printed on every tenth refusal and flooded the v72 log with 964 of them; the "
             "denominator is the candidate count already printed on the trail line",
             g_stringy_logs, g_trail_refusals);
}

void tnx_flush_buckets(void) {
    if (g_image_count > 0) {
        tnx_logf("image-resident: %d rejections in last %ds (top mgr=%p count=%d)",
                 g_image_count, TNX_BUCKET_TICKS_2, (void *)g_image_top_mgr,
                 g_image_top_count);

        g_image_count = 0;
        g_image_top_mgr = 0;
        g_image_top_count = 0;
    }

    tnx_logf("chain: hits=%d vtableChanged=%d classPass=%d", g_chain_hits,
             g_chain_vtchanged, g_class_pass);

    g_chain_vtchanged = 0;
    g_chain_stable_logged = 0;
}

int tnx_battle_gate(int scene) {
    unsigned long long objFired = tnx_object_dispatches();
    int objGrew = objFired > g_obj_prev;
    int sigGrew = g_modesig_hits > g_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;

    g_obj_prev = objFired;

    if (sigGrew || objGrew || sceneGrew) {
        g_battle_last_tick = (int)g_ticks_4;

        if (!g_battle_active) {
            g_battle_active = 1;
            g_battle_reason = sceneGrew ? "scene" : (objGrew ? "objslot" : "modesig");

            tnx_logf("battle state: inactive -> active reason=%s state=%d objFired=%llu "
                     "sigHits=%d", g_battle_reason, g_state_2, objFired, g_modesig_hits);
        }
    } else if (g_battle_active &&
               ((int)g_ticks_4 - g_battle_last_tick) >= TNX_QUIET_SECS) {
        g_battle_active = 0;

        tnx_logf("battle state: active -> inactive reason=quiet-10s");
    }

    return g_battle_active;
}

extern int g_enq_stop_1;

extern int g_enq_stop_2;

extern int g_enq_stop_3;

void tnx_log_heartbeat(void) {
    int sigDelta = g_modesig_hits - g_hb_sig_prev;

    tnx_logf("hb tick=%llu battle=%d reason=%s slot=%p state=%d objFired=%llu "
             "modesigHits=%d sigLast=%d chainHits=%d classesPass=%d g_mode=%p src=%s mgr=%p "
             "count=%d fb=%d liveObjs=%d liveTeams=%d parked=%d drop=20 ctrlPick=%d "
             "clampMax=(%d,%d) enqOk=%llu enqBlocked=%llu predCalls=%llu",
             (unsigned long long)g_ticks_4,
             g_battle_active, g_battle_reason, (void *)g_site, g_state_2,
             (unsigned long long)tnx_object_dispatches(), g_modesig_hits, sigDelta,
             g_chain_hits, g_class_pass,
             (void *)g_scene_object, g_mode_source_2, (void *)g_players_object, g_manager_count,
             g_fb_on, g_live_objs, g_live_teams, g_idle_on, g_ctrl_pick,
             (int)g_max_x, (int)g_max_y, (unsigned long long)g_enq_ok,
             (unsigned long long)(g_enq_stop_1 + g_enq_stop_2 + g_enq_stop_3),
             (unsigned long long)g_pred_calls);

    tnx_log_census();

    g_hb_sig_prev = g_modesig_hits;

    if ((g_ticks_4 % TNX_BUCKET_TICKS_2) == 0) tnx_flush_buckets();

    if (g_modesig_hits == 0 && g_ticks_4 >= TNX_D6_WAIT_SECS &&
        !g_modesig_notfound) {
        g_modesig_notfound = 1;

        tnx_logf("modesig not-found at t=%ds - the mode signature did not match, while the "
                 "%d object-class slots have fired %llu times", TNX_D6_WAIT_SECS,
                 TNX_OBJ_SLOTS, (unsigned long long)tnx_object_dispatches());
    }
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

int tnx_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int live = 0;

    g_manager_last_capacity = 0;
    g_manager_last_live = 0;
    g_manager_last_nonempty = 0;

    if (!tnx_pointer_plausible(manager)) return 0;
    if (!tnx_heap_contains(manager)) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;

    g_manager_last_capacity = capacity;
    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;
    if (!array) return 0;
    if (!tnx_heap_contains((uintptr_t)array)) return 0;
    if ((uintptr_t)array & 0xf) return 0;

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return 0;

    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;
    int nonEmpty = 0;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        nonEmpty++;

        if (!tnx_heap_resident((uintptr_t)element)) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;
        if (!vtable) continue;
        if (!tnx_vtable_shaped((uintptr_t)vtable)) continue;

        if (!tnx_object_live((uintptr_t)element)) continue;

        live++;

        uintptr_t elementRva = (uintptr_t)vtable - g_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    if (typeCount < TNX_MODE_MIN_TYPES) return 0;

    g_manager_last_live = live;
    g_manager_last_nonempty = nonEmpty;

    if (live < TNX_MANAGER_MIN_OBJECTS || live * 4 < nonEmpty * 3) {
        g_manager_last_live = live;
        g_manager_last_nonempty = nonEmpty;
        g_manager_last_capacity = capacity;
        return 0;
    }

    g_manager_last_live = live;
    g_manager_last_nonempty = nonEmpty;
    g_manager_last_capacity = capacity;

    return live;
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
        tnx_read_ptr((uintptr_t)vtable + 0x28, &slotAlive);
        tnx_read_ptr((uintptr_t)vtable + 0x48, &slotKind);

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

uint32_t g_mode_hist[TNX_HIST_MODES];

int64_t g_last_mode = -1;

int32_t g_interp_prev_x = 0;

int32_t g_interp_prev_y = 0;

int g_interp_have = 0;

uint64_t g_interp_moves = 0;

uint64_t g_interp_checks = 0;

uint64_t g_interp_tick = 0;

int g_hist_logs = 0;

int tnx_interp(int32_t *x, int32_t *y) {
    uintptr_t client = tnx_client();
    int32_t cx = 0;
    int32_t cy = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (!client) return 0;
    if (!tnx_read_i32(client + TNX_CLIENT_POS_X_OFF, &cx)) return 0;
    if (!tnx_read_i32(client + TNX_CLIENT_POS_Y_OFF, &cy)) return 0;

    if (x) *x = cx;
    if (y) *y = cy;

    return 1;
}

void tnx_frame(void) {
    int mode = tnx_mode();

    if (mode >= 0 && mode < TNX_HIST_MODES) g_mode_hist[mode]++;

    if (tnx_inner() == 1 && mode == TNX_MODE_TARGET) g_gate2_seen++;
    if (tnx_src(TNX_GATE3_PTR_OFF, NULL, NULL, NULL)) g_gate3_seen++;

    if (mode != g_last_mode) {
        if (g_hist_logs < TNX_HIST_LOGS) {
            g_hist_logs++;

            {
                int32_t e0 = -1;

                if (g_scene_object) {
                    tnx_read_i32((uintptr_t)g_scene_object + 0xe0, &e0);
                }

                tnx_logf("mode change tick=%llu frames=%llu mode: %lld -> %d e0=%d from=unavail - "
                         "this line fires the moment setMode ran, so a momentary 7 in a transition frame "
                         "is caught instead of being averaged away by mode_max; the caller cannot be "
                         "named because setMode %#llx and its two sites %#llx and %#llx have no data slot "
                         "in __DATA_CONST or __DATA, so only the +0xe0 side effect is left as a "
                         "discriminator and e0=0 right at a change points at the %#llx site",
                         (unsigned long long)g_tick_2, (unsigned long long)g_ticks_3,
                         (long long)g_last_mode, mode, e0, (unsigned long long)0xac3a70ULL,
                         (unsigned long long)0x760cdcULL, (unsigned long long)0x764350ULL,
                         (unsigned long long)0x764350ULL);
            }
        }

        g_last_mode = mode;
    }
}

void tnx_interp_line(void) {
    int32_t x = 0;
    int32_t y = 0;
    int moved = 0;

    if (!tnx_interp(&x, &y)) return;
    if (g_tick_2 - g_interp_tick < TNX_INTERP_TICKS) return;

    g_interp_tick = g_tick_2;
    g_interp_checks++;

    if (g_interp_have) moved = (x != g_interp_prev_x || y != g_interp_prev_y) ? 1 : 0;
    if (moved) g_interp_moves++;

    {
        int32_t s30x = 0;
        int32_t s30y = 0;
        int f30 = -1;
        int32_t s38x = 0;
        int32_t s38y = 0;
        int f38 = -1;

        tnx_src(TNX_GATE_PTR_OFF, &s30x, &s30y, &f30);
        tnx_src(TNX_GATE3_PTR_OFF, &s38x, &s38y, &f38);

        uintptr_t p30 = tnx_mode_ptr(TNX_GATE_PTR_OFF);
        uintptr_t p38 = tnx_mode_ptr(TNX_GATE3_PTR_OFF);
        int32_t dx = s30x - s38x;
        int32_t dy = s30y - s38y;
        int s30moved = 0;
        int s38moved = 0;

        if (g_src30_have) s30moved = (s30x != g_src30_prev_x || s30y != g_src30_prev_y) ? 1 : 0;
        if (g_src38_have) s38moved = (s38x != g_src38_prev_x || s38y != g_src38_prev_y) ? 1 : 0;
        if (s30moved) g_src30_moves++;
        if (s38moved) g_src38_moves++;

        if (dx < 0) dx = -dx;
        if (dy < 0) dy = -dy;

        g_w_eq_x = (dx < TNX_DENOM_MIN) ? -999 : tnx_weq(s30x, s38x, x, (s30x - s38x));
        g_w_eq_y = (dy < TNX_DENOM_MIN) ? -999 : tnx_weq(s30y, s38y, y, (s30y - s38y));

        tnx_logf("src30=(%d,%d) f30=%d src38=(%d,%d) f38=%d srcEq=%d denomX=%d denomY=%d dCX=%d dCY=%d d38X=%d "
                 "d38Y=%d wEqX=%d wEqY=%d "
                 "s30moved=%d s38moved=%d src30Moves=%llu src38Moves=%llu client=(%d,%d) gate2Seen=%d "
                 "gate3Seen=%d - w28 itself is a register inside the mode update and no hook can reach it "
                 "because %#llx has no data slot, but the effective weight is recoverable from the three "
                 "pairs: wEq~1000 means the client sits on src30, wEq~0 means it sits on src38, wEq=-999 means denom "
                 "was under %d so no weight is claimed at all, and the raw dC/d38 columns are printed so "
                 "a real 500 cannot be mistaken for rounding noise; srcEq=1 makes the lerp meaningless "
                 "because both ends are one pointer",
                 s30x, s30y, f30, s38x, s38y, f38, (p30 == p38) ? 1 : 0, dx, dy, x - s30x, y - s30y,
                 x - s38x, y - s38y, g_w_eq_x, g_w_eq_y, s30moved, s38moved,
                 (unsigned long long)g_src30_moves, (unsigned long long)g_src38_moves, x, y,
                 g_gate2_seen, g_gate3_seen, (unsigned long long)0xa26890ULL,
                 TNX_DENOM_MIN);

        g_src30_prev_x = s30x;
        g_src30_prev_y = s30y;
        g_src38_prev_x = s38x;
        g_src38_prev_y = s38y;
        g_src30_have = 1;
        g_src38_have = 1;
    }

    tnx_logf("ownInterp prev=(%d,%d) now=(%d,%d) delta=%d moves=%llu checks=%llu mode=%d gate=%d - "
             "the pair at client+%#llx/+%#llx is written every frame by %#llx inside the mode gate, so it "
             "is the live own position: delta=1 with no test at all already means the engine moves own and "
             "the walk pair at +%#llx/+%#llx was never the position",
             g_interp_prev_x, g_interp_prev_y, x, y, moved,
             (unsigned long long)g_interp_moves, (unsigned long long)g_interp_checks,
             tnx_mode(), tnx_gate(), (unsigned long long)TNX_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_CLIENT_POS_Y_OFF, (unsigned long long)0xa26890ULL,
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

    g_interp_prev_x = x;
    g_interp_prev_y = y;
    g_interp_have = 1;
}

uint64_t g_engage_start = 0;

uint64_t g_engage_last = 0;

uint64_t g_engage_writes = 0;

uint64_t g_move_tick = 0;

uint64_t g_applied_match = 0;

uint64_t g_applied_miss = 0;

int32_t g_own_x_2 = 0;

int32_t g_own_y_2 = 0;

int32_t g_prev_x_2 = 0;

int32_t g_prev_y_2 = 0;

int32_t g_pick_x = 0;

int32_t g_pick_y = 0;

int g_engaged = 0;

int g_prev_valid_2 = 0;

int g_logs_6 = 0;

uint64_t g_lifetime = 0;

uint64_t g_applied_idle = 0;

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

void tnx_drive_note(int32_t ownX, int32_t ownY, int32_t tx, int32_t ty, int32_t appX,
                                int32_t appY, int32_t pairX, int32_t pairY) {
    int64_t dx = 0;
    int64_t dy = 0;

    if (g_engaged && (g_ticks_3 - g_engage_last) > 30) {
        tnx_engage_report("engage end");

        g_engaged = 0;
    }

    if (!g_engaged) {
        g_engaged = 1;
        g_engage_start = g_ticks_3;
        g_engage_writes = 0;
        g_move_tick = 0;
        g_applied_match = 0;
        g_applied_miss = 0;
        g_prev_valid_2 = 0;
        g_lifetime = 0;
        g_max_frame = 0;
        g_traveled = 0;
        g_pair_dot_sum = 0.0f;
        g_pair_dot_n = 0;
        g_human_live = 0;
    }

    g_engage_last = g_ticks_3;
    g_engage_writes++;
    g_lifetime++;
    g_own_x_2 = ownX;
    g_own_y_2 = ownY;
    g_pick_x = tx;
    g_pick_y = ty;

    if (g_prev_valid_2) {
        int64_t d2 = 0;

        dx = (int64_t)ownX - (int64_t)g_prev_x_2;
        dy = (int64_t)ownY - (int64_t)g_prev_y_2;
        d2 = dx * dx + dy * dy;

        if (!g_move_tick && d2 >= (int64_t)(TNX_MOVE_MIN * TNX_MOVE_MIN)) {
            g_move_tick = g_ticks_3;
        }

        if ((uint64_t)sqrtf((float)d2) > g_max_frame) {
            g_max_frame = (uint64_t)sqrtf((float)d2);
        }

        g_traveled += (uint64_t)sqrtf((float)d2);

        if (pairX || pairY) {
            float dot = 0.0f;
            float plen = sqrtf((float)(pairX * pairX + pairY * pairY));
            float mlen = sqrtf((float)d2);

            if (plen > 1.0f && mlen > 0.5f) {
                dot = (float)(pairX * dx + pairY * dy) / (plen * mlen);
            }

            g_pair_dot_sum += dot;
            g_pair_dot_n++;
        }
    }

    g_prev_x_2 = ownX;
    g_prev_y_2 = ownY;
    g_prev_valid_2 = 1;

    if (appX == tx && appY == ty) g_applied_match++;
    else g_applied_miss++;

    if ((pairX || pairY) && !(pairX == g_stick_x && pairY == g_stick_y)) {
        g_human_live++;
    }

    if (appX == TNX_APPLIED_IDLE && appY == TNX_APPLIED_IDLE) g_applied_idle++;

    if ((g_lifetime % 30) == 0) {
        tnx_logf("engage running frames=%llu writes=%llu movedAfter=%llu traveled=%llu pairDot=%+.2f "
                 "sent=(%d,%d) pair=(%d,%d) own=(%d,%d) applied=(%d,%d) appliedIdle=%llu appliedWrite=%d - "
                 "pairDot is the angle between the frame's own displacement and the stick this build "
                 "wrote, so +1.00 is the body walking the way it was told and a value near zero on a "
                 "frame that moved is the slide; applied is printed beside it because the 20:46 run "
                 "walked at 1157 units a second on frames where applied was still the engine's no "
                 "touch sentinel, which is what retired that field as a lead",
                 (unsigned long long)(g_ticks_3 - g_engage_start),
                 (unsigned long long)g_engage_writes,
                 (unsigned long long)(g_move_tick ? g_move_tick - g_engage_start : 0),
                 (unsigned long long)g_traveled,
                 (double)(g_pair_dot_n ? g_pair_dot_sum / (float)g_pair_dot_n : 0.0f),
                 tx, ty, pairX, pairY, ownX, ownY, appX, appY,
                 (unsigned long long)g_applied_idle, TNX_APPLIED);
    }
}
