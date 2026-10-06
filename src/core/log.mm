#include "titanox.h"

void tnx_log_purge_legacy_3(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSFileManager *fm = nil;
    NSArray *names = nil;
    NSUInteger i = 0;

    if (paths.count == 0) return;

    fm = [NSFileManager defaultManager];
    names = @[ @"Titanox.log", @"Titanox.txt", @"Titanox.battle.log", @"Titanox.battle.txt" ];

    for (i = 0; i < names.count; i++) {
        NSString *p = [paths[0] stringByAppendingPathComponent:names[i]];

        if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:NULL];
    }
}

FILE *tnx_log_handle(void) {
    if (!t_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"Titanox_logs.txt"];
            t_log = fopen(logPath.UTF8String, "a");
        }

        if (t_log) tnx_log_purge_legacy_3();
    }

    return t_log;
}

const char *t_log_drop[64] = {
    "players", "walk", "hopdump", "teamdump", "membership",
    "man ", "gid", "coords", "coord", "off",
    "clip", "ownscan", "chain", "player[", "element",
    "classdump", "trail", "state", "modeslot", "hooks",
    "scene", "heap", "fields", "write", "slot",
    "setprediction", "scan", "route", "modesig", "hop",
    "battle", "named", "offsets", "recon", "dodgeProj", "dodgeSet",
    NULL
};

#ifndef TNX_LOG_WHITELIST
#define TNX_LOG_WHITELIST 1
#endif

const char *t_log_keep[64] = {
    "=== ", "plan v", "slot ", "logfilter",
    "hb ", "publish", "live ", "hook",
    "census", "roster", "render", "dodge ",
    "drive ", "engage running", "controller ", "predSet",
    "predMiss", "clamp ", "snap ", "build ",
    "shot ", "crit ",
    "stat ", "advise ",
    "queuePush", "queueSkip", "enqueueStop", "msgProbe",
    "window ", "predict", "predSkip", "stick ",
    "route ", "input ", "body ", "chain-only",
    "summary", "test ", "setter-before", "setter-after",
    NULL
};

uint64_t t_drop_counts[64];

uint64_t t_dropped = 0;

uint64_t t_kept_3 = 0;

uint64_t t_log_rolls = 0;

int tnx_keep_line(const char *text) {
    int i = 0;

    if (!TNX_LOG_FILTER) return 1;
    if (!text) return 0;

    for (i = 0; t_log_keep[i]; i++) {
        if (!t_log_keep[i][0]) continue;
        if (strncmp(text, t_log_keep[i], strlen(t_log_keep[i])) == 0) {
            t_kept_3++;

            return 1;
        }
    }

    if (TNX_LOG_WHITELIST) {
        t_dropped++;

        return 0;
    }

    for (i = 0; t_log_drop[i] && i < 64; i++) {
        if (!t_log_drop[i][0]) continue;
        if (strncmp(text, t_log_drop[i], strlen(t_log_drop[i])) == 0) {
            t_drop_counts[i]++;
            t_dropped++;

            return 0;
        }
    }

    t_kept_3++;

    return 1;
}

void tnx_log_census(void) {
    const char *worst = NULL;
    uint64_t worstN = 0;
    int i = 0;

    for (i = 0; t_log_drop[i] && i < 64; i++) {
        if (t_drop_counts[i] > worstN) {
            worstN = t_drop_counts[i];
            worst = t_log_drop[i];
        }
    }

    tnx_logf("logfilter kept=%llu dropped=%llu rolls=%llu worst=%s:%llu - a line is written "
             "unless its start matches the drop list, so anything unlisted, including every line "
             "added after this build, is kept by default; a dropped prefix that should not be here "
             "is removed from the list and comes back without a rebuild",
             (unsigned long long)t_kept_3, (unsigned long long)t_dropped,
             (unsigned long long)t_log_rolls, worst ? worst : "-",
             (unsigned long long)worstN);
}

void tnx_log_roll(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDateFormatter *df = NULL;
    NSString *ts = nil;
    NSString *fmt = @"[%@] === drop=26 log rolled over #%llu, the earlier window is dropped here ===\n";
    NSString *marker = nil;

    if (t_log) {
        fclose(t_log);
        t_log = NULL;
    }

    if (paths.count == 0) return;

    t_log = fopen([paths[0] stringByAppendingPathComponent:@"Titanox_logs.txt"].UTF8String, "w");

    if (!t_log) return;

    t_log_written = 0;
    t_log_rolls++;

    df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    ts = [df stringFromDate:[NSDate date]];
    marker = [NSString stringWithFormat:fmt, ts, (unsigned long long)t_log_rolls];
    t_log_written += (long)fwrite(marker.UTF8String, 1, strlen(marker.UTF8String), t_log);
    fflush(t_log);
}

void tnx_write_line(const char *text) {
    FILE *handle = NULL;

    if (!text) return;
    if (!tnx_keep_line(text)) return;

    if (t_log_written >= LOG_MAX_BYTES) {
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

    t_log_written += (long)len;
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

int t_hb_sig_prev = 0;

int t_image_count = 0;

uintptr_t t_image_top_mgr = 0;

int32_t t_image_top_count = 0;

int t_chain_vtchanged = 0;

int t_chain_stable_logged = 0;

int t_stringy_logs = 0;

int t_battle_active = 0;

int t_battle_last_tick = 0;

const char *t_battle_reason = "none";

void tnx_slot_note(int index, void *self, uint64_t arg1) {
    uint32_t bit = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    t_slot_hits[index]++;

    if (!t_slot_first_tick[index]) t_slot_first_tick[index] = t_ticks_4;

    if (!t_slot_object[index] && self) t_slot_object[index] = (uintptr_t)self;

    if (!t_slot_arg1[index] && arg1) t_slot_arg1[index] = (uintptr_t)arg1;

    bit = (uint32_t)(1u << (unsigned)index);

}

void tnx_slot_fired_report(void) {
    static const char *last[TNX_SLOT_COUNT];
    uint64_t total = 0;
    int armedCount = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        const char *state = "not-attempted";
        void *current = NULL;
        int armed = 0;

        if (t_slot_installed[i] == 1) {
            armed = 1;
            armedCount++;
            state = (t_slot_slots[i] > 0) ? "armed-pointer" : "armed-noslot";

            if (t_slot_specs[i].slotRva &&
                tnx_read_ptr(t_base + t_slot_specs[i].slotRva, &current)) {
                if ((uintptr_t)current != (uintptr_t)t_slot_specs[i].replacement) {
                    state = "armed-REVERTED";
                }
            }
        } else if (t_slot_installed[i] == TNX_STATE_DROPPED) {
            state = "dropped";
        } else if (t_slot_installed[i] == 0) {
            state = (t_slot_slots[i] > 0) ? "install-failed" : "not-found";
        }

        total += t_slot_hits[i];

        if (last[i] == state) continue;

        last[i] = state;

        tnx_logf("hook %s %s armed=%d slots=%d slotRva=%#llx this=%p arg1=%p firstCallTick=%llu "
                 "hits=%llu tick=%llu - printed on a state change only, the ten tick cadence "
                 "used to write this line thirty four times over and the dump was two thirds "
                 "of the whole file",
                 t_slot_specs[i].shortTag, state, armed, t_slot_slots[i],
                 (unsigned long long)t_slot_specs[i].slotRva, (void *)t_slot_object[i],
                 (void *)t_slot_arg1[i], (unsigned long long)t_slot_first_tick[i],
                 (unsigned long long)t_slot_hits[i], (unsigned long long)t_ticks_4);

        if (i == 6 && t_slot_installed[i] == 1 && t_slot_slots[i] < 100) {
            tnx_logf("hook C2 weak: slots=%d where the 22:36 run had 443 - the target moved or "
                     "the table was rebuilt", t_slot_slots[i]);
        }

        if (i == 12 && t_setpred_calls) {
            tnx_logf("setprediction seen: calls=%llu this=%p target=(%.2f,%.2f)",
                     (unsigned long long)t_setpred_calls, (void *)t_setpred_this,
                     t_setpred_x, t_setpred_y);
        }

        if (t_slot_hits[i] == 0 && t_ticks_4 >= 30 && t_slot_installed[i] == 1) {
            if (!(t_never_dispatched_mask & (1u << (unsigned)i))) {
                if (t_slot_slots[i] > TNX_SLOT_WIDE && t_ticks_4 <= TNX_DROP_TICKS) {
                    continue;
                }

                t_never_dispatched_mask |= (1u << (unsigned)i);

            }
        }
    }

    tnx_logf("hooks total fired=%llu armed=%d of %d slots at tick=%llu", (unsigned long long)total,
             armedCount, TNX_SLOT_COUNT, (unsigned long long)t_ticks_4);

    tnx_logf("trail refusals: stringy=%d image-resident=%d - the two counters replace the line "
             "that printed on every tenth refusal and flooded the v72 log with 964 of them; the "
             "denominator is the candidate count already printed on the trail line",
             t_stringy_logs, t_trail_refusals);
}

void tnx_flush_buckets(void) {
    if (t_image_count > 0) {
        tnx_logf("image-resident: %d rejections in last %ds (top mgr=%p count=%d)",
                 t_image_count, TNX_BUCKET_TICKS_2, (void *)t_image_top_mgr,
                 t_image_top_count);

        t_image_count = 0;
        t_image_top_mgr = 0;
        t_image_top_count = 0;
    }

    tnx_logf("chain: hits=%d vtableChanged=%d classPass=%d", t_chain_hits,
             t_chain_vtchanged, t_class_pass);

    t_chain_vtchanged = 0;
    t_chain_stable_logged = 0;
}

int tnx_battle_gate(int scene) {
    unsigned long long objFired = tnx_object_dispatches();
    int objGrew = objFired > t_obj_prev;
    int sigGrew = t_modesig_hits > t_hb_sig_prev;
    int sceneGrew = scene ? 1 : 0;

    t_obj_prev = objFired;

    if (sigGrew || objGrew || sceneGrew) {
        t_battle_last_tick = (int)t_ticks_4;

        if (!t_battle_active) {
            t_battle_active = 1;
            t_battle_reason = sceneGrew ? "scene" : (objGrew ? "objslot" : "modesig");

            tnx_logf("battle state: inactive -> active reason=%s state=%d objFired=%llu "
                     "sigHits=%d", t_battle_reason, t_state_2, objFired, t_modesig_hits);
        }
    } else if (t_battle_active &&
               ((int)t_ticks_4 - t_battle_last_tick) >= TNX_QUIET_SECS) {
        t_battle_active = 0;

        tnx_logf("battle state: active -> inactive reason=quiet-10s");
    }

    return t_battle_active;
}

extern int t_enq_stop_1;

extern int t_enq_stop_2;

extern int t_enq_stop_3;

extern int t_enq_stop_5;

void tnx_log_heartbeat(void) {
    int sigDelta = t_modesig_hits - t_hb_sig_prev;

    tnx_logf("hb tick=%llu battle=%d reason=%s slot=%p state=%d objFired=%llu "
             "modesigHits=%d sigLast=%d chainHits=%d classesPass=%d g_mode=%p src=%s mgr=%p "
             "count=%d fb=%d liveObjs=%d liveTeams=%d parked=%d drop=26 ctrlPick=%d "
             "clampMax=(%d,%d) enqOk=%llu enqBlocked=%llu predCalls=%llu signOn=%d tokens=%u "
             "signFails=%u",
             (unsigned long long)t_ticks_4,
             t_battle_active, t_battle_reason, (void *)t_site, t_state_2,
             (unsigned long long)tnx_object_dispatches(), t_modesig_hits, sigDelta,
             t_chain_hits, t_class_pass,
             (void *)t_scene_object, t_mode_source_2, (void *)t_players_object, t_manager_count,
             t_fb_on, t_live_objs, t_live_teams, t_idle_on, t_ctrl_pick,
             (int)t_max_x, (int)t_max_y, (unsigned long long)t_enq_ok,
             (unsigned long long)(t_enq_stop_1 + t_enq_stop_2 + t_enq_stop_3 + t_enq_stop_5),
             (unsigned long long)t_pred_calls, t_ci_sign_on, (unsigned)t_ci_tokens,
             (unsigned)t_ci_sign_fails);

    tnx_log_census();

    t_hb_sig_prev = t_modesig_hits;

    if ((t_ticks_4 % TNX_BUCKET_TICKS_2) == 0) tnx_flush_buckets();

    if (t_modesig_hits == 0 && t_ticks_4 >= TNX_D6_WAIT_SECS &&
        !t_modesig_notfound) {
        t_modesig_notfound = 1;

        tnx_logf("modesig not-found at t=%ds - the mode signature did not match, while the "
                 "%d object-class slots have fired %llu times", TNX_D6_WAIT_SECS,
                 TNX_OBJ_SLOTS, (unsigned long long)tnx_object_dispatches());
    }
}

int tnx_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int live = 0;

    t_manager_last_capacity = 0;
    t_manager_last_live = 0;
    t_manager_last_nonempty = 0;

    if (!tnx_pointer_plausible(manager)) return 0;
    if (!tnx_heap_contains(manager)) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;

    t_manager_last_capacity = capacity;
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

        uintptr_t elementRva = (uintptr_t)vtable - t_base;
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

    t_manager_last_live = live;
    t_manager_last_nonempty = nonEmpty;

    if (live < TNX_MANAGER_MIN_OBJECTS || live * 4 < nonEmpty * 3) {
        t_manager_last_live = live;
        t_manager_last_nonempty = nonEmpty;
        t_manager_last_capacity = capacity;
        return 0;
    }

    t_manager_last_live = live;
    t_manager_last_nonempty = nonEmpty;
    t_manager_last_capacity = capacity;

    return live;
}

uint32_t t_mode_hist[TNX_HIST_MODES];

int64_t t_last_mode = -1;

int32_t t_interp_prev_x = 0;

int32_t t_interp_prev_y = 0;

int t_interp_have = 0;

uint64_t t_interp_moves = 0;

uint64_t t_interp_checks = 0;

uint64_t t_interp_tick = 0;

int t_hist_logs = 0;

uint64_t t_applied_match = 0;

uint64_t t_applied_miss = 0;

int32_t t_prev_x_2 = 0;

int32_t t_prev_y_2 = 0;

int t_engaged = 0;

int t_prev_valid_2 = 0;

int t_logs_6 = 0;

uint64_t t_lifetime = 0;

uint64_t t_applied_idle = 0;
