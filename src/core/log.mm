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

const char *g_log_drop[64] = {
    "players", "walk", "hopdump", "teamdump", "membership",
    "man ", "gid", "coords", "coord", "off",
    "clip", "ownscan", "chain", "player[", "element",
    "classdump", "trail", "state", "modeslot", "hooks",
    "scene", "heap", "fields", "write", "slot",
    "setprediction", "scan", "route", "modesig", "hop",
    "battle", "named", "offsets",
    NULL
};

#ifndef TNX_LOG_WHITELIST
#define TNX_LOG_WHITELIST 1
#endif

const char *g_log_keep[64] = {
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

    if (TNX_LOG_WHITELIST) {
        g_dropped++;

        return 0;
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
    NSString *fmt = @"[%@] === drop=26 log rolled over #%llu, the earlier window is dropped here ===\n";
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

extern int g_enq_stop_5;

void tnx_log_heartbeat(void) {
    int sigDelta = g_modesig_hits - g_hb_sig_prev;

    tnx_logf("hb tick=%llu battle=%d reason=%s slot=%p state=%d objFired=%llu "
             "modesigHits=%d sigLast=%d chainHits=%d classesPass=%d g_mode=%p src=%s mgr=%p "
             "count=%d fb=%d liveObjs=%d liveTeams=%d parked=%d drop=26 ctrlPick=%d "
             "clampMax=(%d,%d) enqOk=%llu enqBlocked=%llu predCalls=%llu signOn=%d tokens=%u "
             "signFails=%u",
             (unsigned long long)g_ticks_4,
             g_battle_active, g_battle_reason, (void *)g_site, g_state_2,
             (unsigned long long)tnx_object_dispatches(), g_modesig_hits, sigDelta,
             g_chain_hits, g_class_pass,
             (void *)g_scene_object, g_mode_source_2, (void *)g_players_object, g_manager_count,
             g_fb_on, g_live_objs, g_live_teams, g_idle_on, g_ctrl_pick,
             (int)g_max_x, (int)g_max_y, (unsigned long long)g_enq_ok,
             (unsigned long long)(g_enq_stop_1 + g_enq_stop_2 + g_enq_stop_3 + g_enq_stop_5),
             (unsigned long long)g_pred_calls, g_ci_sign_on, (unsigned)g_ci_tokens,
             (unsigned)g_ci_sign_fails);

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
                    tnx_read_i32((uintptr_t)g_scene_object + TNX_SCENE_E0_OFF, &e0);
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
