#include "titanox.h"

FILE *tnx_log_handle(void) {
    if (!g_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"Titanox.log"];
            g_log = fopen(logPath.UTF8String, "a");
        }
    }

    return g_log;
}

const char *g_v190_log_drop[67] = {
    "v100 players", "v100 walk", "v100 hopdump", "v100 teamdump", "v100 container",
    "v100 membership", "v100 man ", "v100 gid", "v100 coords", "v100 coord", "v100 off",
    "v100 dodge", "v100 hb", "v100 clip", "v100 ownscan", "v100 chain", "v100 player[",
    "v100 element", "v100 classdump", "v100 trail", "v100 state", "v100 modeslot", "v100 hooks",
    "v100 scene", "v100 heap", "v100 fields", "v100 write", "v100 slot", "v100 setprediction",
    "v100 scan", "v100 route", "v100 modesig", "v100 hop", "v100 battle", "v100 named",
    "v100 offsets",
    "v173 ", "v115 ", "v140 ", "v142 ", "v102 ", "v138 ", "v106 ", "v135 ", "v116 ", "v162 ",
    "v145 ", "v101 ", "v129 ", "v141 ", "v128 ", "v144 ", "v148 ", "v105 ", "v112 ", "v92 ",
    "v160 ", "v127 ", "v152 ",
    "v174 ", "v117 ", "v119 ", "v134 ", "v169 ", "v126 ", "v129 ",
    NULL
};

const char *g_v190_log_keep[19] = {
    "=== ", "plan v", "slot ", "v47 ", "v100 hook", "v100 live", "v100 census", "v126 ",
    "v142 publish", "v146 ", "v172 ", "v179 ", "v181 ", "v189 ", "v190 ", "v191 ", "v192 ",
    "v193 ",
    NULL
};

uint64_t g_v190_drop_counts[64];

uint64_t g_v190_dropped = 0;

uint64_t g_v190_kept = 0;

uint64_t g_v190_log_rolls = 0;

int tnx_v190_keep_line(const char *text) {
    int i = 0;

    if (!TNX_V190_LOG_FILTER) return 1;
    if (!text) return 0;

    for (i = 0; g_v190_log_keep[i]; i++) {
        if (strncmp(text, g_v190_log_keep[i], strlen(g_v190_log_keep[i])) == 0) {
            g_v190_kept++;

            return 1;
        }
    }

    for (i = 0; g_v190_log_drop[i] && i < 64; i++) {
        if (strncmp(text, g_v190_log_drop[i], strlen(g_v190_log_drop[i])) == 0) {
            g_v190_drop_counts[i]++;
            g_v190_dropped++;

            return 0;
        }
    }

    g_v190_kept++;

    return 1;
}

void tnx_v190_log_census(void) {
    const char *worst = NULL;
    uint64_t worstN = 0;
    int i = 0;

    for (i = 0; g_v190_log_drop[i] && i < 64; i++) {
        if (g_v190_drop_counts[i] > worstN) {
            worstN = g_v190_drop_counts[i];
            worst = g_v190_log_drop[i];
        }
    }

    tnx_logf("v190 logfilter kept=%llu dropped=%llu rolls=%llu worst=%s:%llu - a line is written "
             "unless its start matches the drop list, so anything unlisted, including every line "
             "added after this build, is kept by default; a dropped prefix that should not be here "
             "is removed from the list and comes back without a rebuild",
             (unsigned long long)g_v190_kept, (unsigned long long)g_v190_dropped,
             (unsigned long long)g_v190_log_rolls, worst ? worst : "-",
             (unsigned long long)worstN);
}

void tnx_v190_log_roll(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDateFormatter *df = NULL;
    NSString *ts = nil;
    NSString *fmt = @"[%@] === v190 log rolled over #%llu, the earlier window is dropped here ===\n";
    NSString *marker = nil;

    if (g_log) {
        fclose(g_log);
        g_log = NULL;
    }

    if (paths.count == 0) return;

    g_log = fopen([paths[0] stringByAppendingPathComponent:@"Titanox.log"].UTF8String, "w");

    if (!g_log) return;

    g_log_written = 0;
    g_v190_log_rolls++;

    df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    ts = [df stringFromDate:[NSDate date]];
    marker = [NSString stringWithFormat:fmt, ts, (unsigned long long)g_v190_log_rolls];
    g_log_written += (long)fwrite(marker.UTF8String, 1, strlen(marker.UTF8String), g_log);
    fflush(g_log);
}

void tnx_write_line(const char *text) {
    FILE *handle = NULL;

    if (!text) return;
    if (!tnx_v190_keep_line(text)) return;

    if (g_log_written >= LOG_MAX_BYTES) {
        if (!TNX_V190_LOG_ROLL) return;

        tnx_v190_log_roll();
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

int g_v63_hb_sig_prev = 0;

int g_v63_image_count = 0;

uintptr_t g_v63_image_top_mgr = 0;

int32_t g_v63_image_top_count = 0;

int g_v63_image_first = 0;

int g_v63_chain_vtchanged = 0;

int g_v63_chain_stable_logged = 0;

int g_v63_stringy_logs = 0;

int g_v63_battle_active = 0;

int g_v63_battle_last_tick = 0;

const char *g_v63_battle_reason = "none";

void tnx_slot_note(int index, void *self, uint64_t arg1) {
    uint32_t bit = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_first_tick[index]) g_slot_first_tick[index] = g_v50_ticks;

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
        } else if (g_slot_installed[i] == TNX_V73_STATE_DROPPED) {
            state = "dropped";
        } else if (g_slot_installed[i] == 0) {
            state = (g_slot_slots[i] > 0) ? "install-failed" : "not-found";
        }

        total += g_slot_hits[i];

        tnx_logf("v100 hook %s %s armed=%d slots=%d slotRva=%#llx this=%p arg1=%p firstCallTick=%llu "
                 "hits=%llu tick=%llu",
                 g_slot_specs[i].shortTag, state, armed, g_slot_slots[i],
                 (unsigned long long)g_slot_specs[i].slotRva, (void *)g_slot_object[i],
                 (void *)g_slot_arg1[i], (unsigned long long)g_slot_first_tick[i],
                 (unsigned long long)g_slot_hits[i], (unsigned long long)g_v50_ticks);

        if (i == 6 && g_slot_installed[i] == 1 && g_slot_slots[i] < 100) {
            tnx_logf("v100 hook C2 weak: slots=%d where the 22:36 run had 443 - the target moved or "
                     "the table was rebuilt", g_slot_slots[i]);
        }

        if (i == 12 && g_v52_setpred_calls) {
            tnx_logf("v100 setprediction seen: calls=%llu this=%p target=(%.2f,%.2f)",
                     (unsigned long long)g_v52_setpred_calls, (void *)g_v52_setpred_this,
                     g_v52_setpred_x, g_v52_setpred_y);
        }

        if (g_slot_hits[i] == 0 && g_v50_ticks >= 30 && g_slot_installed[i] == 1) {
            if (!(g_v50_never_dispatched_mask & (1u << (unsigned)i))) {
                if (g_slot_slots[i] > TNX_V59_SLOT_WIDE && g_v50_ticks <= TNX_V59_DROP_TICKS) {
                    continue;
                }

                g_v50_never_dispatched_mask |= (1u << (unsigned)i);

            }
        }
    }

    tnx_logf("v100 hooks total fired=%llu armed=%d of %d slots at tick=%llu", (unsigned long long)total,
             armedCount, TNX_SLOT_COUNT, (unsigned long long)g_v50_ticks);

    tnx_logf("v100 trail refusals: stringy=%d image-resident=%d - the two counters replace the line "
             "that printed on every tenth refusal and flooded the v72 log with 964 of them; the "
             "denominator is the candidate count already printed on the trail line",
             g_v63_stringy_logs, g_v72_trail_refusals);
}

void tnx_v63_flush_buckets(void) {
    if (g_v63_image_count > 0) {
        tnx_logf("v100 image-resident: %d rejections in last %ds (top mgr=%p count=%d)",
                 g_v63_image_count, TNX_V63_BUCKET_TICKS, (void *)g_v63_image_top_mgr,
                 g_v63_image_top_count);

        g_v63_image_count = 0;
        g_v63_image_top_mgr = 0;
        g_v63_image_top_count = 0;
    }

    tnx_logf("v100 chain: hits=%d vtableChanged=%d classPass=%d", g_v59_chain_hits,
             g_v63_chain_vtchanged, g_v62_class_pass);

    g_v63_chain_vtchanged = 0;
    g_v63_chain_stable_logged = 0;
}

int tnx_v63_battle_gate(int scene) {
    unsigned long long objFired = tnx_v79_object_dispatches();
    int objGrew = objFired > g_v79_obj_prev;
    int sigGrew = g_v64_modesig_hits > g_v63_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;

    g_v79_obj_prev = objFired;

    if (sigGrew || objGrew || sceneGrew) {
        g_v63_battle_last_tick = (int)g_v50_ticks;

        if (!g_v63_battle_active) {
            g_v63_battle_active = 1;
            g_v63_battle_reason = sceneGrew ? "scene" : (objGrew ? "objslot" : "modesig");

            tnx_logf("v100 battle state: inactive -> active reason=%s state=%d objFired=%llu "
                     "sigHits=%d", g_v63_battle_reason, g_v80_state, objFired, g_v64_modesig_hits);
        }
    } else if (g_v63_battle_active &&
               ((int)g_v50_ticks - g_v63_battle_last_tick) >= TNX_V63_QUIET_SECS) {
        g_v63_battle_active = 0;

        tnx_logf("v100 battle state: active -> inactive reason=quiet-10s");
    }

    return g_v63_battle_active;
}

void tnx_v63_log_heartbeat(void) {
    int sigDelta = g_v64_modesig_hits - g_v63_hb_sig_prev;

    tnx_logf("v100 hb tick=%llu battle=%d reason=%s slot=%p state=%d objFired=%llu "
             "modesigHits=%d sigLast=%d chainHits=%d classesPass=%d g_mode=%p src=%s mgr=%p "
             "count=%d fb=%d liveObjs=%d liveTeams=%d parked=%d",
             (unsigned long long)g_v50_ticks,
             g_v63_battle_active, g_v63_battle_reason, (void *)g_v80_site, g_v80_state,
             (unsigned long long)tnx_v79_object_dispatches(), g_v64_modesig_hits, sigDelta,
             g_v59_chain_hits, g_v62_class_pass,
             (void *)g_scene_object, g_v62_mode_source, (void *)g_players_object, g_manager_count,
             g_v77_fb_on, g_v77_live_objs, g_v77_live_teams, g_v78_idle_on);

    tnx_v190_log_census();

    g_v63_hb_sig_prev = g_v64_modesig_hits;

    if ((g_v50_ticks % TNX_V63_BUCKET_TICKS) == 0) tnx_v63_flush_buckets();

    if (g_v64_modesig_hits == 0 && g_v50_ticks >= TNX_V63_D6_WAIT_SECS &&
        !g_v64_modesig_notfound) {
        g_v64_modesig_notfound = 1;

        tnx_logf("v100 modesig not-found at t=%ds - the mode signature did not match, while the "
                 "%d object-class slots have fired %llu times", TNX_V63_D6_WAIT_SECS,
                 TNX_V79_OBJ_SLOTS, (unsigned long long)tnx_v79_object_dispatches());
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

    if (g_v71_modehit_dump >= 8) return;

    g_v71_modehit_dump++;

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

        if (before && tnx_v56_vtable_in_image((uintptr_t)before) &&
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

        if (!tnx_v75_object_live((uintptr_t)element)) continue;

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

    tnx_logf("v100 chain gates: vtBad=%d vtNotDC=%d mgrBad=%d mgrNotPlausible=%d mgrNotHeap=%d "
             "varBad=%d pxBad=%d pyBad=%d inputBad=%d shapeBad=%d arrayRead=%d countRead=%d "
             "arrayNull=%d countRange=%d live=%d own=%d gid=%d tested=%d logged=%d",
             g_v55_chain_rej[0], g_v55_chain_rej[1], g_v55_chain_rej[2], g_v55_chain_rej[3],
             g_v55_chain_rej[4], g_v55_chain_rej[5], g_v55_chain_rej[6], g_v55_chain_rej[7],
             g_v55_chain_rej[8], g_v55_chain_rej[9], g_v55_chain_rej[10], g_v55_chain_rej[11],
             g_v55_chain_rej[12], g_v55_chain_rej[13], g_v55_chain_rej[14], g_v55_chain_rej[15],
             g_v55_chain_rej[16], g_chain_probes, g_v55_layout_logs);

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
             g_chain_checks, g_chain_probes, g_v55_chain_probes_pass, g_chain_skipped,
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
             "posDistinct>=2", (unsigned long long)g_trail_total, g_trail_count, g_v75_ascii_refused);

    for (int k = 0; k < n; k++) {
        int i = rank[k];
        char reason[64] = { 0 };
        int accepted = tnx_v75_trail_verdict(&g_trail[i], reason, sizeof(reason));

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

uint32_t g_v116_mode_hist[TNX_V116_HIST_MODES];

int64_t g_v116_last_mode = -1;

int32_t g_v116_interp_prev_x = 0;

int32_t g_v116_interp_prev_y = 0;

int g_v116_interp_have = 0;

uint64_t g_v116_interp_moves = 0;

uint64_t g_v116_interp_checks = 0;

uint64_t g_v116_interp_tick = 0;

int g_v116_hist_logs = 0;

int tnx_v116_interp(int32_t *x, int32_t *y) {
    uintptr_t client = tnx_v115_client();
    int32_t cx = 0;
    int32_t cy = 0;

    if (x) *x = 0;
    if (y) *y = 0;
    if (!client) return 0;
    if (!tnx_read_i32(client + TNX_V115_CLIENT_POS_X_OFF, &cx)) return 0;
    if (!tnx_read_i32(client + TNX_V115_CLIENT_POS_Y_OFF, &cy)) return 0;

    if (x) *x = cx;
    if (y) *y = cy;

    return 1;
}

void tnx_v116_frame(void) {
    int mode = tnx_v115_mode();

    if (mode >= 0 && mode < TNX_V116_HIST_MODES) g_v116_mode_hist[mode]++;

    if (tnx_v115_inner() == 1 && mode == TNX_V115_MODE_TARGET) g_v117_gate2_seen++;
    if (tnx_v117_src(TNX_V117_GATE3_PTR_OFF, NULL, NULL, NULL)) g_v117_gate3_seen++;

    if (mode != g_v116_last_mode) {
        if (g_v116_hist_logs < TNX_V116_HIST_LOGS) {
            g_v116_hist_logs++;

            {
                int32_t e0 = -1;

                if (g_scene_object) {
                    tnx_read_i32((uintptr_t)g_scene_object + 0xe0, &e0);
                }

                tnx_logf("v117 mode change tick=%llu frames=%llu mode: %lld -> %d e0=%d from=unavail - "
                         "this line fires the moment setMode ran, so a momentary 7 in a transition frame "
                         "is caught instead of being averaged away by mode_max; the caller cannot be "
                         "named because setMode %#llx and its two sites %#llx and %#llx have no data slot "
                         "in __DATA_CONST or __DATA, so only the +0xe0 side effect is left as a "
                         "discriminator and e0=0 right at a change points at the %#llx site",
                         (unsigned long long)g_v103_tick, (unsigned long long)g_v48_ticks,
                         (long long)g_v116_last_mode, mode, e0, (unsigned long long)0xac3a70ULL,
                         (unsigned long long)0x760cdcULL, (unsigned long long)0x764350ULL,
                         (unsigned long long)0x764350ULL);
            }
        }

        g_v116_last_mode = mode;
    }
}

void tnx_v116_interp_line(void) {
    int32_t x = 0;
    int32_t y = 0;
    int moved = 0;

    if (!tnx_v116_interp(&x, &y)) return;
    if (g_v103_tick - g_v116_interp_tick < TNX_V116_INTERP_TICKS) return;

    g_v116_interp_tick = g_v103_tick;
    g_v116_interp_checks++;

    if (g_v116_interp_have) moved = (x != g_v116_interp_prev_x || y != g_v116_interp_prev_y) ? 1 : 0;
    if (moved) g_v116_interp_moves++;

    {
        int32_t s30x = 0;
        int32_t s30y = 0;
        int f30 = -1;
        int32_t s38x = 0;
        int32_t s38y = 0;
        int f38 = -1;

        tnx_v117_src(TNX_V115_GATE_PTR_OFF, &s30x, &s30y, &f30);
        tnx_v117_src(TNX_V117_GATE3_PTR_OFF, &s38x, &s38y, &f38);

        uintptr_t p30 = tnx_v118_mode_ptr(TNX_V115_GATE_PTR_OFF);
        uintptr_t p38 = tnx_v118_mode_ptr(TNX_V117_GATE3_PTR_OFF);
        int32_t dx = s30x - s38x;
        int32_t dy = s30y - s38y;
        int s30moved = 0;
        int s38moved = 0;

        if (g_v118_src30_have) s30moved = (s30x != g_v118_src30_prev_x || s30y != g_v118_src30_prev_y) ? 1 : 0;
        if (g_v118_src38_have) s38moved = (s38x != g_v118_src38_prev_x || s38y != g_v118_src38_prev_y) ? 1 : 0;
        if (s30moved) g_v118_src30_moves++;
        if (s38moved) g_v118_src38_moves++;

        if (dx < 0) dx = -dx;
        if (dy < 0) dy = -dy;

        g_v118_w_eq_x = (dx < TNX_V119_DENOM_MIN) ? -999 : tnx_v118_weq(s30x, s38x, x, (s30x - s38x));
        g_v118_w_eq_y = (dy < TNX_V119_DENOM_MIN) ? -999 : tnx_v118_weq(s30y, s38y, y, (s30y - s38y));

        tnx_logf("v119 src30=(%d,%d) f30=%d src38=(%d,%d) f38=%d srcEq=%d denomX=%d denomY=%d dCX=%d dCY=%d d38X=%d "
                 "d38Y=%d wEqX=%d wEqY=%d "
                 "s30moved=%d s38moved=%d src30Moves=%llu src38Moves=%llu client=(%d,%d) gate2Seen=%d "
                 "gate3Seen=%d - w28 itself is a register inside the mode update and no hook can reach it "
                 "because %#llx has no data slot, but the effective weight is recoverable from the three "
                 "pairs: wEq~1000 means the client sits on src30, wEq~0 means it sits on src38, wEq=-999 means denom "
                 "was under %d so no weight is claimed at all, and the raw dC/d38 columns are printed so "
                 "a real 500 cannot be mistaken for rounding noise; srcEq=1 makes the lerp meaningless "
                 "because both ends are one pointer",
                 s30x, s30y, f30, s38x, s38y, f38, (p30 == p38) ? 1 : 0, dx, dy, x - s30x, y - s30y,
                 x - s38x, y - s38y, g_v118_w_eq_x, g_v118_w_eq_y, s30moved, s38moved,
                 (unsigned long long)g_v118_src30_moves, (unsigned long long)g_v118_src38_moves, x, y,
                 g_v117_gate2_seen, g_v117_gate3_seen, (unsigned long long)0xa26890ULL,
                 TNX_V119_DENOM_MIN);

        g_v118_src30_prev_x = s30x;
        g_v118_src30_prev_y = s30y;
        g_v118_src38_prev_x = s38x;
        g_v118_src38_prev_y = s38y;
        g_v118_src30_have = 1;
        g_v118_src38_have = 1;
    }

    tnx_logf("v116 ownInterp prev=(%d,%d) now=(%d,%d) delta=%d moves=%llu checks=%llu mode=%d gate=%d - "
             "the pair at client+%#llx/+%#llx is written every frame by %#llx inside the mode gate, so it "
             "is the live own position: delta=1 with no test at all already means the engine moves own and "
             "the walk pair at +%#llx/+%#llx was never the position",
             g_v116_interp_prev_x, g_v116_interp_prev_y, x, y, moved,
             (unsigned long long)g_v116_interp_moves, (unsigned long long)g_v116_interp_checks,
             tnx_v115_mode(), tnx_v115_gate(), (unsigned long long)TNX_V115_CLIENT_POS_X_OFF,
             (unsigned long long)TNX_V115_CLIENT_POS_Y_OFF, (unsigned long long)0xa26890ULL,
             (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);

    g_v116_interp_prev_x = x;
    g_v116_interp_prev_y = y;
    g_v116_interp_have = 1;
}

uint64_t g_v190_engage_start = 0;

uint64_t g_v190_engage_last = 0;

uint64_t g_v190_engage_writes = 0;

uint64_t g_v190_move_tick = 0;

uint64_t g_v190_applied_match = 0;

uint64_t g_v190_applied_miss = 0;

int32_t g_v190_own_x = 0;

int32_t g_v190_own_y = 0;

int32_t g_v190_prev_x = 0;

int32_t g_v190_prev_y = 0;

int32_t g_v190_pick_x = 0;

int32_t g_v190_pick_y = 0;

int g_v190_engaged = 0;

int g_v190_prev_valid = 0;

int g_v190_logs = 0;

uint64_t g_v190_lifetime = 0;

uint64_t g_v190_applied_writes = 0;

uint64_t g_v190_applied_idle = 0;

void tnx_v190_engage_report(const char *why) {
    if (g_v190_logs >= TNX_V190_DRIVE_LOGS) return;
    if (g_v190_engage_writes == 0) return;

    g_v190_logs++;

    tnx_logf("v191 %s first=%llu last=%llu frames=%llu writes=%llu movedAfter=%llu maxFrame=%llu "
             "traveled=%llu own=(%d,%d) pick=(%d,%d) - movedAfter is the delay: the frames from the "
             "first write of this run to the first frame own's position moved by at least %d units, "
             "which is a walk of 180 units a second and no longer the twenty a frame that only a "
             "teleport reaches; traveled is the whole path own covered during the run against 780 "
             "units a second for a walk, which is the number that says whether the body follows the "
             "writes at all; human=%llu counts the frames the player's own finger was on the stick, so a "
             "run with human at its maximum and traveled at a walk speed is the dodge working while "
             "the stick is held, and the prediction went out %llu times with %llu refusals", why,
             (unsigned long long)g_v190_engage_start,
             (unsigned long long)g_v190_engage_last,
             (unsigned long long)(g_v190_engage_last - g_v190_engage_start),
             (unsigned long long)g_v190_engage_writes,
             (unsigned long long)(g_v190_move_tick ? g_v190_move_tick - g_v190_engage_start : 0),
             (unsigned long long)g_v191_max_frame, (unsigned long long)g_v191_traveled,
             g_v190_own_x, g_v190_own_y, g_v190_pick_x, g_v190_pick_y, TNX_V191_MOVE_MIN,
             (unsigned long long)g_v192_human_live, (unsigned long long)g_v192_pred_calls,
             (unsigned long long)g_v192_pred_fails);
}

void tnx_v190_drive_note(int32_t ownX, int32_t ownY, int32_t tx, int32_t ty, int32_t appX,
                                int32_t appY, int32_t pairX, int32_t pairY) {
    int64_t dx = 0;
    int64_t dy = 0;

    if (g_v190_engaged && (g_v48_ticks - g_v190_engage_last) > 30) {
        tnx_v190_engage_report("engage end");

        g_v190_engaged = 0;
    }

    if (!g_v190_engaged) {
        g_v190_engaged = 1;
        g_v190_engage_start = g_v48_ticks;
        g_v190_engage_writes = 0;
        g_v190_move_tick = 0;
        g_v190_applied_match = 0;
        g_v190_applied_miss = 0;
        g_v190_prev_valid = 0;
        g_v190_lifetime = 0;
        g_v191_max_frame = 0;
        g_v191_traveled = 0;
        g_v191_pair_dot_sum = 0.0f;
        g_v191_pair_dot_n = 0;
        g_v192_human_live = 0;
    }

    g_v190_engage_last = g_v48_ticks;
    g_v190_engage_writes++;
    g_v190_lifetime++;
    g_v190_own_x = ownX;
    g_v190_own_y = ownY;
    g_v190_pick_x = tx;
    g_v190_pick_y = ty;

    if (g_v190_prev_valid) {
        int64_t d2 = 0;

        dx = (int64_t)ownX - (int64_t)g_v190_prev_x;
        dy = (int64_t)ownY - (int64_t)g_v190_prev_y;
        d2 = dx * dx + dy * dy;

        if (!g_v190_move_tick && d2 >= (int64_t)(TNX_V191_MOVE_MIN * TNX_V191_MOVE_MIN)) {
            g_v190_move_tick = g_v48_ticks;
        }

        if ((uint64_t)sqrtf((float)d2) > g_v191_max_frame) {
            g_v191_max_frame = (uint64_t)sqrtf((float)d2);
        }

        g_v191_traveled += (uint64_t)sqrtf((float)d2);

        if (pairX || pairY) {
            float dot = 0.0f;
            float plen = sqrtf((float)(pairX * pairX + pairY * pairY));
            float mlen = sqrtf((float)d2);

            if (plen > 1.0f && mlen > 0.5f) {
                dot = (float)(pairX * dx + pairY * dy) / (plen * mlen);
            }

            g_v191_pair_dot_sum += dot;
            g_v191_pair_dot_n++;
        }
    }

    g_v190_prev_x = ownX;
    g_v190_prev_y = ownY;
    g_v190_prev_valid = 1;

    if (appX == tx && appY == ty) g_v190_applied_match++;
    else g_v190_applied_miss++;

    if ((pairX || pairY) && !(pairX == g_v174_stick_x && pairY == g_v174_stick_y)) {
        g_v192_human_live++;
    }

    if (appX == TNX_V128_APPLIED_IDLE && appY == TNX_V128_APPLIED_IDLE) g_v190_applied_idle++;

    if ((g_v190_lifetime % 30) == 0) {
        tnx_logf("v191 engage running frames=%llu writes=%llu movedAfter=%llu traveled=%llu pairDot=%+.2f "
                 "sent=(%d,%d) pair=(%d,%d) own=(%d,%d) applied=(%d,%d) appliedIdle=%llu appliedWrite=%d - "
                 "pairDot is the angle between the frame's own displacement and the stick this build "
                 "wrote, so +1.00 is the body walking the way it was told and a value near zero on a "
                 "frame that moved is the slide; applied is printed beside it because the 20:46 run "
                 "walked at 1157 units a second on frames where applied was still the engine's no "
                 "touch sentinel, which is what retired that field as a lead",
                 (unsigned long long)(g_v48_ticks - g_v190_engage_start),
                 (unsigned long long)g_v190_engage_writes,
                 (unsigned long long)(g_v190_move_tick ? g_v190_move_tick - g_v190_engage_start : 0),
                 (unsigned long long)g_v191_traveled,
                 (double)(g_v191_pair_dot_n ? g_v191_pair_dot_sum / (float)g_v191_pair_dot_n : 0.0f),
                 tx, ty, pairX, pairY, ownX, ownY, appX, appY,
                 (unsigned long long)g_v190_applied_idle, TNX_V190_APPLIED);
    }
}
