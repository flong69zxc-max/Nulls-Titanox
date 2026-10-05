#include "titanox.h"

#ifndef TNX_DODGE_PROJ_ONLY
#define TNX_DODGE_PROJ_ONLY 1
#endif

#ifndef TNX_CLASS_PLAYER2_RVA
#define TNX_CLASS_PLAYER2_RVA 0x000ff54a0ULL
#endif

#ifndef TNX_PROJ_ACTIVE_BYPASS
#define TNX_PROJ_ACTIVE_BYPASS 1
#endif

uintptr_t g_mgr = 0;

int g_mgr_logs = 0;

int g_test_state = 0;

int g_test_after_x = 0;

int g_test_after_y = 0;

int g_moved = 0;

int g_moved2 = 0;

int g_kept = 0;

int g_tested = 0;

int g_ok = 0;

uint64_t g_writes = 0;

uint64_t g_tick_2 = 0;

int g_attempt = 0;

int g_prev_state = -1;

int g_other_logs = 0;

int g_other_detail = 0;

uintptr_t g_own_ptr_2 = 0;

int g_own_index_2 = -1;

int g_own_team_2 = -1;

int g_own_base = -1;

int g_own_logs_2 = 0;

int g_audited = 0;

int g_inject_logs = 0;

const char *g_own_from_2 = "none";

uint64_t g_tick = 0;

uint64_t g_write_last = 0;

int g_write_phase = 0;

int g_write_count = 0;

int g_write_base_ok = 0;

int g_write_base_x = 0;

int g_write_base_y = 0;

int g_trace_logs = 0;

int g_trace_n = 0;

uintptr_t g_trace_obj[TNX_OBJECT_MAX];

int g_trace_x[TNX_OBJECT_MAX];

int g_trace_y[TNX_OBJECT_MAX];

int g_hop_chosen = -1;

int g_hop_sticky = 0;

int g_coord_off = -1;

int g_modesig_hits = 0;

int g_modesig_notfound = 0;

int g_floor_logged = 0;

int g_fallback_logged = 0;

int g_census_logs = 0;

int g_elem_dumps = 0;

int g_hop2_census = 0;

int g_type3_floats = 0;

uintptr_t g_census_container = 0;

int32_t g_census_count = 0;

uintptr_t g_census_array = 0;

uintptr_t g_census_first = 0;

uint64_t g_census_ms = 0;

int g_slot_dumped = 0;

int g_gate_calls = 0;

uintptr_t g_own_ptr_4 = 0;

int g_own_index_3 = -1;

int g_own_src = -1;

uintptr_t g_own_off = 0;

uintptr_t g_scan_container = 0;

int g_scan_logs = 0;

int g_own_logged = 0;

int32_t g_wrote_x = 0;

int32_t g_wrote_y = 0;

int32_t g_own_pos_x = 0;

int32_t g_own_pos_y = 0;

uint64_t g_wrote_tick = 0;

int g_wrote_valid = 0;

int g_check_done = 0;

uint64_t g_test_writes = 0;

int g_class_dumps = 0;

const char *g_own_from_4 = "none";

int g_players_dumps = 0;

int g_hop_dumps = 0;

int g_modehit_dump = 0;

uint64_t g_prev_upd = 0;

uint64_t g_prev_rend = 0;

uint64_t g_pred_took = 0;

uint64_t g_pred_miss = 0;

int g_pred_logs = 0;

void tnx_alert_menu(NSString *info) {
    NSString *text = [info copy];

    if (g_alerts_off) return;

    TNX_LOGX("scene-mode alert shown - the latch that made the alert a once-per-process event "
             "is gone, the edge on the scene pointer is what limits it now");

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        UIViewController *host = nil;

        for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }

        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;

        host = window.rootViewController;
        if (!host) return;

        while (host.presentedViewController) host = host.presentedViewController;

        UIAlertController *menu =
            [UIAlertController alertControllerWithTitle:@"Titanox"
                                                message:text
                                         preferredStyle:UIAlertControllerStyleAlert];

        [menu addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Состояние"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            tnx_alert_menu(tnx_status_text());
        }]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Скрыть алерты"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
            g_alerts_off = 1;
        }]];

        [host presentViewController:menu animated:YES completion:nil];
    });
}

int tnx_modesig_hit(uintptr_t at) {
    void *vt = NULL;
    void *mgr = NULL;
    int32_t ec = 0;
    int32_t m124 = 0;
    int32_t count = 0;

    if (!at) return 0;
    if (!tnx_read_ptr(at, &vt) || !vt) return 0;
    if (!tnx_vtable_in_image((uintptr_t)vt)) return 0;
    if (!tnx_vtable_is_data((uintptr_t)vt)) {
        if (g_vt_text_rejects < 12) {
            g_vt_text_rejects++;

            TNX_LOGX("modesig reject at=%p vt=%p vtSeg=%s - a class table lives in "
                     "__DATA_CONST, and an in-image word outside the data segments is code",
                     (void *)at, vt, tnx_image_segment_name((uintptr_t)vt));
        }

        return 0;
    }
    if (!tnx_read_i32(at + 0x124ULL, &m124) || m124 < 0x01 || m124 > 0x80) return 0;
    if (!tnx_read_i32(at + 0xecULL, &ec) || ec < -1024 || ec > 1024) return 0;
    if (!tnx_read_ptr(at + TNX_MODE_MANAGER_OFF, &mgr) || !mgr) return 0;
    if (!tnx_pointer_plausible((uintptr_t)mgr)) return 0;
    if (!tnx_read_i32((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count < 2 || count > TNX_MANAGER_MAX_OBJECTS) return 0;

    return 1;
}

void tnx_modesig_tick(void) {
    uintptr_t found = 0;

    if (g_scene_object) return;
    if (!g_battle_active && (g_ticks_4 % TNX_BUCKET_TICKS_2) != 0) return;

    for (int i = 0; i < g_objhit_count && !found; i++) {
        if (tnx_modesig_hit(g_objhits[i].at)) found = g_objhits[i].at;
    }

    if (!found) return;

    if (g_sig_last == found) {
        g_sig_ticks++;
    } else {
        g_sig_last = found;
        g_sig_ticks = 1;

        if (g_sig_logs < 12) {
            g_sig_logs++;

            TNX_LOGX("modesig hit obj=%p sighting=1/%d - a new address, the stability counter "
                     "restarts", (void *)found, TNX_MODESIG_TICKS);
        }
    }

    if (g_sig_ticks < TNX_MODESIG_TICKS) return;

    {
        void *vt = NULL;
        void *mgr = NULL;
        int32_t ec = 0;
        int32_t m124 = 0;
        int32_t count = 0;
        int32_t cap = 0;

        g_modesig_hits++;
        g_scene_object = found;
        g_mode_source_2 = "modesig";
        g_battle_last_tick = (int)g_ticks_4;

        tnx_read_ptr(found, &vt);
        tnx_read_ptr(found + TNX_MODE_MANAGER_OFF, &mgr);
        tnx_read_i32(found + 0xecULL, &ec);
        tnx_read_i32(found + 0x124ULL, &m124);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_CAP_OFF, &cap);

        TNX_LOGX("modesig accepted obj=%p vt=%#llx ec=%d m124=%#x mgr=%p count=%d ticks=%d "
                 "src=SIG", (void *)found, (unsigned long long)(uintptr_t)vt, ec, (unsigned)m124,
                 mgr, count, g_sig_ticks);

        if (count >= 2 && cap >= count && cap <= TNX_MGR_CAP_MAX) {
            void *mgrArray = NULL;

            g_manager_count = count;

            if (tnx_read_ptr((uintptr_t)mgr + TNX_MGR_ARRAY_OFF, &mgrArray) && mgrArray) {
                tnx_publish((uintptr_t)mgr, (uintptr_t)mgrArray, count, cap, "modesig");
            }

            TNX_LOGX("modesig container obj=%p mgr=%p array=%p count=%d cap=%d src=SIG - read "
                     "and published as one tuple under the seqlock, or not at all",
                     (void *)found, mgr, mgrArray, count, cap);
        }
    }
}

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

void tnx_battle_alert(uintptr_t scene, uintptr_t scenePrev) {
    uint64_t now = 0;

    if (!scene) return;
    if (g_alerts_off) return;
    if (scene == g_alert_scene) return;

    now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

    if (g_alert_ms && now - g_alert_ms < TNX_ALERT_GAP_MS) {
        TNX_LOGX("alert withheld prev=%p now=%p sinceMs=%llu nowMs=%llu gapMs=%d - the alert "
                 "call moved off the container change and onto the scene edge, because the v134 run "
                 "showed the menu ten times in ten seconds while the scene pointer in the heartbeat "
                 "never moved: the call sat in the container-change block, so every hop flip looked "
                 "like a battle entry; prev and now are printed so a real repeat is distinguishable "
                 "from the old misfire",
                 (void *)scenePrev, (void *)scene, (unsigned long long)g_alert_ms,
                 (unsigned long long)now, TNX_ALERT_GAP_MS);

        return;
    }

    g_alert_scene = scene;
    g_alert_ms = now;

    TNX_LOGX("alert shown prev=%p now=%p edgePrev=%p sinceMs=%llu gapMs=%d - printed after both "
             "gates, so the menu line that follows cannot be mistaken for a call that skipped them; "
             "edgePrev is the scene the edge detector itself last held, so a repeat that reaches this "
             "line with edgePrev equal to now is an edge misfire and not a real battle entry, which is "
             "exactly what the v137 run could not be asked",
             (void *)scenePrev, (void *)scene, (void *)g_prev_scene,
             (unsigned long long)g_alert_ms, TNX_ALERT_GAP_MS);

    g_prev_scene = scene;

    tnx_alert_menu([NSString stringWithFormat:
        @"Вход в бой\nscene=%p (было %p)\ncontainer=%p count=%d\ngid=%d..%d\nown=min gid",
        (void *)scene, (void *)scenePrev, (void *)g_players_object, g_players_count,
        g_gid_lo, g_gid_hi]);
}

int tnx_element_type(uintptr_t vt, uintptr_t *wordOut) {
    void *slotPtr = NULL;
    uintptr_t slot = 0;

    if (wordOut) *wordOut = 0;

    if (!vt) return -1;
    if (!tnx_read_ptr(vt + TNX_TYPE_SLOT_OFF, &slotPtr) || !slotPtr) return -1;

    slot = tnx_strip_ptr((uintptr_t)slotPtr) - g_base;

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

void tnx_container_census(uintptr_t array, int32_t count, uintptr_t container) {
    int accepted = 0;
    int typed = 0;
    int types = 0;
    int typeMask = 0;
    int teams = 0;
    int teamMask = 0;
    int gidSeen = 0;
    int classSeen = -1;
    int back = 0;
    uintptr_t histRva[TNX_HIST_MAX];
    uintptr_t histWord[TNX_HIST_MAX];
    int histCount[TNX_HIST_MAX];
    int histN = 0;
    int32_t v70lo = 0;
    int32_t v70hi = 0;
    int v70n = 0;
    char histText[768];
    int h = 0;

    if (!array || count <= 0) return;

    {
        void *firstPtr = NULL;
        uintptr_t first = 0;
        uint64_t nowMs = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        int same = (container == g_census_container &&
                    (uintptr_t)array == g_census_array);
        int firstChanged = 0;

        if (tnx_read_ptr(array, &firstPtr) && firstPtr) first = (uintptr_t)firstPtr;
        firstChanged = (first != g_census_first);

        if (same && !firstChanged && g_census_ms &&
            nowMs - g_census_ms < TNX_CENSUS_MS) {
            return;
        }

        if (same) {
            TNX_LOGX("census rearmed container=%p array=%p count=%d lastCount=%d first=%p "
                     "lastFirst=%p firstChanged=%d sinceMs=%llu - the count delta rule of v135 fired "
                     "on every second of the battle because this vector is the object registry and "
                     "it grows and shrinks with projectiles, so the census printed twenty times and "
                     "the log drowned; it is now taken when the first element changes or after %d ms",
                     (void *)container, (void *)array, count, g_census_count, (void *)first,
                     (void *)g_census_first, firstChanged,
                     (unsigned long long)(g_census_ms ? nowMs - g_census_ms : 0),
                     TNX_CENSUS_MS);
        }

        g_census_container = container;
        g_census_count = count;
        g_census_array = (uintptr_t)array;
        g_census_first = (uintptr_t)first;
        g_census_ms = nowMs;
    }

    if (count > TNX_DUMP_QWORDS) count = TNX_DUMP_QWORDS;

    for (h = 0; h < TNX_HIST_MAX; h++) {
        histRva[h] = 0;
        histWord[h] = 0;
        histCount[h] = 0;
    }

    for (int32_t i = 0; i < count; i++) {
        uintptr_t at = array + (uintptr_t)i * sizeof(void *);
        void *element = NULL;
        void *vt = NULL;
        void *def = NULL;
        char why[160] = { 0 };
        char typeText[16] = { 0 };
        uintptr_t classRva = 0;
        uintptr_t typeWord = 0;
        int32_t team = 0;
        int32_t gid = 0;
        int32_t kind = 0;
        int32_t kind68 = 0;
        int32_t teamHyp = 0;
        int32_t byte48 = 0;
        void *backPtr = NULL;
        int elementBack = 0;
        int type = -1;
        int ok = 0;

        if (!tnx_read_ptr(at, &element) || !element) {
            TNX_LOGX("container elem[%d] at %p unreadable - no verdict from this slot", i,
                     (void *)at);
            continue;
        }

        tnx_read_ptr((uintptr_t)element, &vt);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid);

        if (gid >= TNX_GID_FLOOR && gid < TNX_PLAYER_GID_MAX &&
            team >= 0 && team <= TNX_TEAM_MAX_2) {
            ok = 1;
            snprintf(why, sizeof(why), "gid=%d in [%d,%d) and team=%d in range - accepted on the id "
                     "the engine itself assigns, with no definition pointer read at all",
                     gid, TNX_GID_FLOOR, TNX_GID_MAX, team);
        } else {
            ok = 0;
            snprintf(why, sizeof(why), "gid=%d outside [%d,%d) or team=%d outside 0..%d - refused "
                     "with no definition pointer read at all, because the v127 run showed the def "
                     "field empty at the moment the census looks at it and every element was called "
                     "unaccepted on that empty field while carrying a real id",
                     gid, TNX_GID_FLOOR, TNX_GID_MAX, team, TNX_TEAM_MAX_2);
        }
        tnx_read_i32((uintptr_t)element + TNX_HYP_TEAM_OFF, &teamHyp);
        tnx_read_i32((uintptr_t)element + TNX_HYP_BYTE_OFF, &byte48);
        if (tnx_read_ptr((uintptr_t)element + TNX_ELEM_BACK_OFF, &backPtr) &&
            (uintptr_t)backPtr == container) {
            elementBack = 1;
            back++;
        }
        if (tnx_read_ptr((uintptr_t)element + TNX_ELEM_DEF_OFF, &def) && def) {
            tnx_read_i32((uintptr_t)def + TNX_KIND_OFF, &kind);
            tnx_read_i32((uintptr_t)def + TNX_DEF_68_OFF, &kind68);
        }

        type = tnx_element_type((uintptr_t)vt, &typeWord);

        if (type < 0) snprintf(typeText, sizeof(typeText), "unknown");
        else snprintf(typeText, sizeof(typeText), "%d", type);

        classRva = tnx_strip_ptr((uintptr_t)vt) - g_base;

        if (classSeen < 0) classSeen = (int)classRva;
        else if (classSeen != (int)classRva) classSeen = -2;

        for (h = 0; h < histN; h++) {
            if (histRva[h] == classRva) break;
        }

        if (h < histN) {
            histCount[h]++;
        } else if (histN < TNX_HIST_MAX) {
            histRva[histN] = classRva;
            histWord[histN] = typeWord;
            histCount[histN] = 1;
            histN++;
        }

        if (ok) {
            int32_t v70 = 0;

            if (tnx_read_i32((uintptr_t)element + TNX_OFF, &v70)) {
                if (v70 != 0 && v70 > -TNX_COORD_MAX && v70 < TNX_COORD_MAX) {
                    if (v70n == 0 || v70 < v70lo) v70lo = v70;
                    if (v70n == 0 || v70 > v70hi) v70hi = v70;
                    v70n++;
                }
            }

            if (gid > 0) {
                if (g_gid_lo == 0 || gid < g_gid_lo) g_gid_lo = gid;
                if (gid > g_gid_hi) g_gid_hi = gid;
            }
        }

        if (i == 0 && type == TNX_TYPE3_CODE) g_type3_floats = 1;

        if (ok) accepted++;

        if (type >= 0) {
            typed++;

            if (type < 32 && !(typeMask & (1 << type))) {
                typeMask |= (1 << type);
                types++;
            }
        }

        if (teamHyp >= 0 && teamHyp < TNX_TEAM_SLOTS && !(teamMask & (1 << teamHyp))) {
            teamMask |= (1 << teamHyp);
            teams++;
        }

        if (gid > 0) gidSeen++;

        TNX_LOGX("container elem[%d] at %p vt=%p classRva=%#llx type=%s typeWord=%#llx def=%p "
                 "def35c=%d def68=%d | gid8=%d team40=%d team4c=%d byte48=%d | back=%d accept=%d "
                 "(%s)", i, (void *)element, vt, (unsigned long long)classRva, typeText,
                 (unsigned long long)typeWord, def, kind, kind68, gid, team, teamHyp, byte48,
                 elementBack, ok, why);

        if (type == TNX_TYPE3_CODE) {
            float f10 = 0.0f;
            float f1c = 0.0f;
            float f100 = 0.0f;
            float f104 = 0.0f;

            tnx_read_f32((uintptr_t)element + TNX_FLOAT_LO, &f10);
            tnx_read_f32((uintptr_t)element + TNX_FLOAT_LO2, &f1c);
            tnx_read_f32((uintptr_t)element + TNX_FLOAT_HI, &f100);
            tnx_read_f32((uintptr_t)element + TNX_FLOAT_HI2, &f104);

            TNX_LOGX("container elem[%d] as floats +%#llx=%.4f +%#llx=%.4f +%#llx=%.4f "
                     "+%#llx=%.4f - classRva is %#llx, whose own table exposes exactly these four "
                     "as float getters in slots 0x1b0/0x1b8 and 0x1c8/0x1d0, so a pair among them "
                     "is the coordinate pair", i, (unsigned long long)TNX_FLOAT_LO, f10,
                     (unsigned long long)TNX_FLOAT_LO2, f1c,
                     (unsigned long long)TNX_FLOAT_HI, f100,
                     (unsigned long long)TNX_FLOAT_HI2, f104,
                     (unsigned long long)TNX_TYPE3_CLASS_RVA);
        }

        if (g_elem_dumps < TNX_ELEM_DUMPS_2) {
            g_elem_dumps++;

            TNX_LOGX("element head dump elem=%p vt=%p type=%s - +0x00..+0x%x, so the log shows "
                     "whether +%#llx holds a definition pointer that makes def35c and def68 "
                     "readable, or a float pair that means this is not a game object at all",
                     (void *)element, vt, typeText, (unsigned)(TNX_ELEM_QWORDS_2 * 8),
                     (unsigned long long)TNX_ELEM_DEF_OFF);

            if (type == TNX_TYPE3_CODE) {
                float h10 = 0.0f;
                float h1c = 0.0f;
                float h100 = 0.0f;
                float h104 = 0.0f;

                tnx_read_f32((uintptr_t)element + TNX_FLOAT_LO, &h10);
                tnx_read_f32((uintptr_t)element + TNX_FLOAT_LO2, &h1c);
                tnx_read_f32((uintptr_t)element + TNX_FLOAT_HI, &h100);
                tnx_read_f32((uintptr_t)element + TNX_FLOAT_HI2, &h104);

                TNX_LOGX("element head floats elem=%p +%#llx=%.4f +%#llx=%.4f +%#llx=%.4f "
                         "+%#llx=%.4f - the same element as the qwords above, read as single "
                         "precision, which is the form type %d's own getters use; this line is "
                         "printed for type %d only, because for any other type +%#llx is the "
                         "definition pointer and not a float", (void *)element,
                         (unsigned long long)TNX_FLOAT_LO, h10,
                         (unsigned long long)TNX_FLOAT_LO2, h1c,
                         (unsigned long long)TNX_FLOAT_HI, h100,
                         (unsigned long long)TNX_FLOAT_HI2, h104, TNX_TYPE3_CODE,
                         TNX_TYPE3_CODE, (unsigned long long)TNX_ELEM_DEF_OFF);
            }
        }

        if (classRva == TNX_ELEMCLASS_RVA && g_elem_full_dumps < TNX_ELEM_DUMPS_3) {
            g_elem_full_dumps++;

        }
    }

    g_census_logs++;
    g_census_container = container;

    histText[0] = 0;

    for (h = 0; h < histN; h++) {
        char one[96];
        const char *seg = tnx_image_segment_name(g_base + histRva[h]);

        snprintf(one, sizeof(one), "%s%#llx(%s)x%d word=%#llx", h ? " " : "",
                 (unsigned long long)histRva[h], seg ? seg : "-", histCount[h],
                 (unsigned long long)histWord[h]);

        strncat(histText, one, sizeof(histText) - strlen(histText) - 1);
    }

    TNX_LOGX("classHist container=%p n=%d %s | v70=%d..%d n=%d - every class table the "
             "container holds is listed with how many elements carry it and the word its own slot "
             "+%#llx returns, because the v132 run put four elements of class 0xff56d8 with "
             "typeWord 0xa2e094 inside the player container and a single classRva of the first "
             "element could not separate them; the class is the discriminator and the team is only "
             "the second one, since the projectile class carries team -1 as well. The v70 pair is "
             "the one live offset left in the window after +%#llx/+%#llx took the coordinates: it "
             "is printed as a range over the accepted elements and is a candidate for velocity or "
             "facing, not a position",
             (void *)container, histN, histText, v70n ? v70lo : 0, v70n ? v70hi : 0, v70n,
             (unsigned long long)TNX_TYPE_SLOT_OFF, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF);

    TNX_LOGX("container census hop=%d container=%p typed=%d of %d types=%d typeMask=%#x "
             "teamsHyp=%d gidSeen=%d back=%d of %d oldAccept=%d classRva=%#llx - the type is the "
             "engine's own discriminator, the word at [vt+%#llx] matched against the getters "
             "0x14c81c/0xa31768/0x9f4ec8/0x314ca0/0x490b54/0x86f494/0x370688/0x490d94, so an "
             "element whose slot is not in that list is printed as type=unknown with its raw word "
             "instead of being rejected; the id is read at +%#llx and the +0x50 word is gone from "
             "the code and from this line, and back counts the elements whose +%#llx names this "
             "very container", g_hop_chosen, (void *)container, typed, count, types,
             (unsigned)typeMask, teams, gidSeen, back, count, accepted,
             (unsigned long long)(classSeen < 0 ? 0 : classSeen),
             (unsigned long long)TNX_TYPE_SLOT_OFF,
             (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_ELEM_BACK_OFF);
}

uintptr_t g_hop_scene = 0;

int tnx_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut,
                                    int32_t *capOut, char *why, size_t whyLen) {
    const char *reason = NULL;
    void *array = NULL;

    if (arrayOut) *arrayOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;

    if (!object) {
        snprintf(why, whyLen, "null");
        return 0;
    }

    reason = tnx_header_reason(object, countOut, capOut);

    if (reason) {
        snprintf(why, whyLen, "%s", reason);
        return 0;
    }

    if (!tnx_read_ptr(object + TNX_MGR_ARRAY_OFF, &array) || !array) {
        snprintf(why, whyLen, "array-null");
        return 0;
    }

    if (!tnx_heap_resident((uintptr_t)array)) {
        snprintf(why, whyLen, "array-not-heap");
        return 0;
    }

    if (arrayOut) *arrayOut = (uintptr_t)array;

    snprintf(why, whyLen, "ok array=%p count=%d cap=%d", array,
             countOut ? *countOut : 0, capOut ? *capOut : 0);

    return 1;
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

int g_gid_logs = 0;

int g_coord_logs = 0;

int g_dump_done = 0;

int32_t tnx_gid_at(uintptr_t element, uintptr_t off) {
    int32_t gid = 0;

    if (off && tnx_read_i32(element + off, &gid)) return gid;

    return 0;
}

int32_t tnx_gid(uintptr_t element, int32_t *offOut) {
    int32_t gid = 0;
    int32_t alt = 0;

    if (offOut) *offOut = 0;
    if (!element) return 0;

    if (tnx_read_i32(element + TNX_OBJ_GLOBALID_OFF, &gid) && gid) {
        if (offOut) *offOut = (int32_t)TNX_OBJ_GLOBALID_OFF;

        return gid;
    }

    if (tnx_read_i32(element + TNX_GID_FALLBACK_OFF, &alt) && alt) {
        if (offOut) *offOut = (int32_t)TNX_GID_FALLBACK_OFF;

        if (g_gid_logs < 6) {
            void *vtable = NULL;
            uintptr_t vtRva = 0;

            g_gid_logs++;

            if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - g_base;

            TNX_LOGX("gid fallback element=%p vtRva=%#llx +%#llx=0 +%#llx=%d - the walk used to "
                     "reject this row as rejGidZero by reading the wrong field, so every usable count "
                     "came out short",
                     (void *)element, (unsigned long long)vtRva,
                     (unsigned long long)TNX_OBJ_GLOBALID_OFF,
                     (unsigned long long)TNX_GID_FALLBACK_OFF, alt);
        }

        return alt;
    }

    return 0;
}

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

int g_score_logs = 0;

int g_last_choice = -2;

int g_hop_logs = 0;

int g_start_logged = 0;

int tnx_container_score(uintptr_t container) {
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
    if (!tnx_read_ptr(container + TNX_MGR_ARRAY_OFF, &array) || !array) return -1;
    if (!tnx_read_i32(container + TNX_MGR_COUNT_OFF, &count)) return -1;
    if (count <= 0 || count > TNX_COUNT_MAX) return -1;

    if (own < 0 || own >= count) soft = 1;

    for (i = 0; i < count && samples < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;

        samples++;
        team = 0;
        px = 0;
        py = 0;

        if (tnx_element_ascii((uintptr_t)element)) asciiCount++;

        gid = tnx_gid((uintptr_t)element, NULL);
        tnx_read_i32((uintptr_t)element + TNX_TEAM_OFF, &team);

        if (tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px) &&
            tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py) &&
            px > -TNX_COORD_MAX && px < TNX_COORD_MAX &&
            py > -TNX_COORD_MAX && py < TNX_COORD_MAX && (px != 0 || py != 0)) {
            int dup = 0;

            posOk++;

            for (j = 0; j < i; j++) {
                void *other = NULL;

                if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)j * 8ULL, &other) || !other) continue;
                if (!tnx_read_i32((uintptr_t)other + TNX_OBJ_X_OFF, &qx)) continue;
                if (!tnx_read_i32((uintptr_t)other + TNX_OBJ_Y_OFF, &qy)) continue;

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

    if (samples > 0 && (asciiCount * 100) / samples > TNX_ASCII_RATIO) {
        if (g_ascii_logs < TNX_ASCII_LOGS) {
            g_ascii_logs++;

            TNX_LOGX("ascii-reject container=%p array=%p count=%d own=%d ascii=%d/%d(%d%%) "
                     "posOk=%d posDistinct=%d - the same rule the trail path applies at %#llx is "
                     "applied here before any weight, because a text container whose bytes read as an "
                     "in-range int pair at +%#llx/+%#llx would otherwise be counted as coordinates and "
                     "the soft own slot added in v128 would let it take the hop off a real list",
                     (void *)container, array, count, own, asciiCount, samples,
                     (asciiCount * 100) / samples, posOk, posDistinct,
                     (int)TNX_ASCII_RATIO, (unsigned long long)TNX_OBJ_X_OFF,
                     (unsigned long long)TNX_OBJ_Y_OFF);
        }

        return -1;
    }

    if (soft) {
        if (posOk < TNX_SOFT_MIN_POS || posDistinct < TNX_SOFT_MIN_DIST) {
            if (g_score_logs < 12) {
                g_score_logs++;

                TNX_LOGX("score-reject container=%p array=%p count=%d own=%d posOk=%d "
                         "posDistinct=%d samples=%d - a list whose own slot at +%#llx is not an index "
                         "into its own array is refused unless it proves itself by carrying at least "
                         "%d in-range non-zero coordinate pairs of which at least %d differ; the v127 "
                         "run lost the hop exactly here, where the id list won on ids and the brawler "
                         "list that carries every real position was returned as -1 before its pairs "
                         "were ever counted",
                         (void *)container, array, count, own, posOk, posDistinct, samples,
                         (unsigned long long)TNX_OWNIDX_OFF_2, TNX_SOFT_MIN_POS,
                         TNX_SOFT_MIN_DIST);
            }

            return -1;
        }

        score = TNX_SOFT_BASE;
    } else {
        score = 6;

        if (ownTeam >= 0 && ownTeam <= 15) score += 2;
    }

    if (gidOk) score += 1;
    if (teamOk) score += 1;
    if (count >= 3) score += 2;
    if (count >= 6) score += 1;

    score += posOk * TNX_POS_BONUS + posDistinct * TNX_DIST_BONUS;

    if (g_score_logs < 12) {
        g_score_logs++;

        TNX_LOGX("score container=%p array=%p count=%d own=%d ownTeam=%d soft=%d gidOk=%d "
                 "teamOk=%d posOk=%d posDistinct=%d ascii=%d/%d samples=%d score=%d - posOk counts sampled "
                 "elements whose int pair at +%#llx/+%#llx is in range and not both zero, posDistinct "
                 "counts how many of those pairs differ from every earlier one, and the pair is "
                 "weighted %d plus %d per distinct value while an id is still worth one, so a list "
                 "that carries twelve different positions cannot lose to a list that carries four "
                 "ids and reads (0,0) everywhere, which is the exact tie the v127 run lost",
                 (void *)container, array, count, own, ownTeam, soft, gidOk, teamOk, posOk, posDistinct,
                 asciiCount, samples, samples, score, (unsigned long long)TNX_OBJ_X_OFF,
                 (unsigned long long)TNX_OBJ_Y_OFF, TNX_POS_BONUS, TNX_DIST_BONUS);
    }

    return score;
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

NSString *tnx_status_text(void) {
    return [NSString stringWithFormat:
        @"scene=%p\ncontainer=%p count=%d hop=%d\narray=%p cap=%d\ngid=%d..%d live=%d\n"
        @"slots=%d alerts=%s\nlife=%s own=(%d,%d) team=%d mates=%d",
        (void *)g_scene_object, (void *)g_players_object, g_players_count, g_last_choice,
        (void *)g_players_array, g_players_cap, g_gid_lo, g_gid_hi, g_manager_last_live,
        TNX_SLOT_COUNT, g_alerts_off ? @"выкл" : @"вкл", tnx_state_name(),
        g_own_x, g_own_y, g_own_team_4, g_mate_n];
}

int tnx_scan_ready(int battle) {
    if (g_ticks_4 < TNX_SCAN_FLOOR_TICKS) {
        if (!g_floor_logged) {
            g_floor_logged = 1;

            TNX_LOGX("scan held to tick=%d battle=%d mode=%p - the lobby scan is what "
                     "raised the TID_SHOP trail candidate", TNX_SCAN_FLOOR_TICKS, battle,
                     (void *)g_scene_object);
        }

        return 0;
    }

    if (battle || g_scene_object) return 1;

    if (g_ticks_4 < TNX_SCAN_FALLBACK_TICKS) return 0;

    if (!g_fallback_logged) {
        g_fallback_logged = 1;

        TNX_LOGX("scan fallback at tick=%llu battle=%d mode=%p - no battle seen, resuming "
                 "on the %ds bucket", (unsigned long long)g_ticks_4, battle,
                 (void *)g_scene_object, TNX_BUCKET_TICKS_2);
    }

    return (g_ticks_4 % TNX_BUCKET_TICKS_2) == 0;
}

void tnx_resolve_addresses(void) {
    if (!g_base) return;

    g_addr_getinstance = tnx_callable(RVA_BATTLEMODE_GETINSTANCE);
    g_addr_getownchar = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    g_addr_getteam = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    g_addr_getx = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    g_addr_gety = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);

    g_addr_setprediction = tnx_callable(TNX_RVA_SETPREDICTION);

    if (!g_addr_setprediction) {
        TNX_LOGX("prediction NOT resolvable rva=%#llx - without it the body is carried by the "
                 "input queue instead of walked by the engine's own movement, which is the slide",
                 (unsigned long long)TNX_RVA_SETPREDICTION);
    }
    g_addr_sendmovement = tnx_callable(RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT);
    g_addr_getclip = tnx_callable(RVA_STRINGTABLE_GETMOVIECLIP);
    g_addr_addchild = tnx_callable(RVA_STAGE_ADDCHILD);

    g_addr_gettf = tnx_pick(TNX_RVA_GETTEXTFIELDBYNAME_A, TNX_RVA_GETTEXTFIELDBYNAME_B);
    g_addr_settext = tnx_pick(TNX_RVA_SETTEXT_A, TNX_RVA_SETTEXT_B);
    g_addr_setxy = tnx_pick(TNX_RVA_SETXY_A, TNX_RVA_SETXY_B);

    g_addr_battlescreen = g_base + RVA_BATTLESCREEN__BATTLESCREEN;
    if (!tnx_addr_readable(g_addr_battlescreen, sizeof(void *))) g_addr_battlescreen = 0;

    tlog([NSString stringWithFormat:
          @"resolve aim=%d input=%d dodge=%d wm=%d screen=%d",
          (g_addr_getinstance && g_addr_getownchar && g_addr_getx && g_addr_gety && g_addr_getteam) ? 1 : 0,
          g_addr_sendmovement ? 1 : 0,
          g_addr_setprediction ? 1 : 0,
          (g_addr_getclip && g_addr_gettf && g_addr_settext && g_addr_setxy && g_addr_addchild) ? 1 : 0,
          g_addr_battlescreen ? 1 : 0]);
}

int tnx_mode_score(uintptr_t mode) {
    void *manager = NULL;
    void *array = NULL;
    int32_t variation = 0;
    int32_t count = 0;

    if (!tnx_instance_shaped(mode)) return 0;

    if (!tnx_read_i32(mode + TNX_MODE_MODEVAR_OFF, &variation)) return 0;
    if (variation < 0 || variation > 400) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &manager)) return 0;
    if (!manager) return 0;
    if (!tnx_manager_shape((uintptr_t)manager)) return 0;

    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;

    if (count > g_mode_best_objects) g_mode_best_objects = count;

    if (count < TNX_MODE_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;
    if (!array || !tnx_heap_resident((uintptr_t)array)) return 0;

    int verified = 0;
    int live = 0;
    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_heap_resident((uintptr_t)element)) continue;

        live++;

        if (tnx_gameobject_shape((uintptr_t)element)) verified++;

        void *elementVtable = NULL;

        if (!tnx_read_ptr((uintptr_t)element, &elementVtable)) continue;
        if ((uintptr_t)elementVtable <= g_base) continue;

        uintptr_t elementRva = (uintptr_t)elementVtable - g_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    g_mode_last_types = typeCount;

    if (live < TNX_MODE_MIN_OBJECTS) return 0;
    if (verified < TNX_MODE_MIN_OBJECTS) return 1;

    return (typeCount >= TNX_MODE_MIN_TYPES) ? 2 : 1;
}

BOOL tnx_is_mode_vtable(uintptr_t value, uintptr_t *rvaOut) {
    if (!g_base || !value) return NO;

    for (int i = 0; g_mode_vtables[i]; i++) {
        if (value != (g_base + g_mode_vtables[i])) continue;

        if (rvaOut) *rvaOut = g_mode_vtables[i];

        return YES;
    }

    return NO;
}

void tnx_locate_battle_mode(void) {
    if (g_mode_strong) return;

    if (g_votescan_attempts >= TNX_VOTESCAN_ATTEMPTS) {

        tnx_diag_report("exhausted");

        return;
    }

    double now = CFAbsoluteTimeGetCurrent();

    if (g_votescan_last > 0.0 && (now - g_votescan_last) < TNX_VOTESCAN_INTERVAL) return;

    g_votescan_last = now;
    g_votescan_attempts++;

    if (g_votescan_attempts == 1) {
        tnx_heap_regions_refresh();

    TNX_LOGX("heapwin regions=%d lo=%p hi=%p winSpan=%lluMB capped=%d",
             g_heap_region_count, (void *)g_heap_window_low, (void *)g_heap_window_high,
             (unsigned long long)((g_heap_window_high - g_heap_window_low) / (1024ull * 1024ull)),
             g_heap_region_capped);

    TNX_LOGX("votescan candidates=%d interval=%.1f attempts=%d heapEvery=%d",
                 (int)(sizeof(g_mode_vtables) / sizeof(g_mode_vtables[0]) - 1),
                 (double)TNX_VOTESCAN_INTERVAL, TNX_VOTESCAN_ATTEMPTS, TNX_VOTESCAN_HEAP_EVERY);
    }

    if ((g_votescan_attempts % TNX_VOTESCAN_GLOBAL_EVERY) == 1) {

        tnx_heap_regions_refresh();

    }

    if (g_mode_strong) {
        TNX_LOGX("votescan SUCCESS attempt=%d object=%p global=%p",
                 g_votescan_attempts, (void *)g_scene_object, (void *)g_mode_source);
        tnx_report_mode_hit("found", g_mode_source, g_scene_object);
    } else if ((g_votescan_attempts % TNX_VOTESCAN_HEARTBEAT) == 0) {
        tnx_diag_report("heartbeat");
    }
}

int tnx_trail_beats_slot(int live, int nonEmpty, int32_t count, int slot) {
    if (live != g_trail[slot].live) return live > g_trail[slot].live;
    if (nonEmpty != g_trail[slot].nonEmpty) return nonEmpty > g_trail[slot].nonEmpty;

    return count > g_trail[slot].count;
}

int tnx_trail_ranked(int *out, int max) {
    uint8_t used[TNX_TRAIL_MAX];
    int count = 0;

    memset(used, 0, sizeof(used));

    for (int k = 0; k < max; k++) {
        int best = -1;

        for (int i = 0; i < g_trail_count; i++) {
            if (used[i]) continue;
            if (best < 0) {
                best = i;

                continue;
            }

            if (tnx_trail_beats_slot(g_trail[i].live, g_trail[i].nonEmpty, g_trail[i].count, best)) {
                best = i;
            }
        }

        if (best < 0) break;

        used[best] = 1;
        out[count++] = best;
    }

    return count;
}

uintptr_t g_setpred_2 = 0;

int g_setpred_state = -1;

int g_probe_done_2 = 0;

uintptr_t g_probe_object = 0;

uint64_t g_probe_last_ms = 0;

int g_coord_ok = 0;

int g_coord_usable = 0;

int g_coord_distinct = 0;

int g_team_off = (int)TNX_OBJ_TEAM_OFF;

int g_map_w = 0;

int g_map_h = 0;

int g_map_ok = 0;

uint64_t g_ticks_2 = 0;

uint64_t g_threat_ticks = 0;

uint64_t g_writes_3 = 0;

uint64_t g_last_write_ms = 0;

int g_giveup_logs = 0;

uint64_t g_probe_tick = 0;

tnx_obj_t g_dodge_probe_list[TNX_OBJECT_MAX];

int tnx_verify_setprediction(void) {
    static const uint32_t expected[3] = { 0xb901d401u, 0xb901d802u, 0xd65f03c0u };
    uint32_t words[3] = { 0, 0, 0 };
    uintptr_t address = 0;

    if (!g_base) return 0;

    address = g_base + TNX_RVA_SETPREDICTION;

    if (!tnx_addr_readable(address, sizeof(words))) return 0;
    if (!tnx_read_bytes(address, words, sizeof(words))) return 0;

    for (int i = 0; i < 3; i++) {
        if (words[i] != expected[i]) {
            TNX_LOGX("setprediction fingerprint MISMATCH word[%d]=%08x expected=%08x at %#llx",
                     i, words[i], expected[i], (unsigned long long)TNX_RVA_SETPREDICTION);
            return 0;
        }
    }

    TNX_LOGX("setprediction fingerprint verified at %#llx (str w1,[x0,#0x1d4]; str w2,[x0,#0x1d8]; "
             "ret) - the BYTES match; nothing has been written yet",
             (unsigned long long)TNX_RVA_SETPREDICTION);

    return 1;
}

void tnx_read_map(uintptr_t mode) {
    void *tileMap = NULL;
    int32_t width = 0;
    int32_t height = 0;

    g_map_ok = 0;
    g_map_w = 0;
    g_map_h = 0;

    if (!mode) return;

    tileMap = (void *)tnx_map_object();
    if (!tileMap) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_MAP_WIDTH_OFF, &width)) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_MAP_HEIGHT_OFF, &height)) return;

    g_map_w = width;
    g_map_h = height;
    g_map_ok = (width >= TNX_MAP_MIN && width <= TNX_MAP_MAX &&
                    height >= TNX_MAP_MIN && height <= TNX_MAP_MAX) ? 1 : 0;
}

int g_gidless = 0;

int g_gidless_logs = 0;

void tnx_gidless_scan(uintptr_t manager) {
    void *data = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int seen = 0;
    int withGid = 0;

    g_gidless = 0;

    if (!TNX_GIDLESS) return;
    if (!manager) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &data) || !data) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;

    for (i = 0; i < count && i < 8; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * 8ULL, &element) || !element) continue;

        seen++;

        if (tnx_gid((uintptr_t)element, NULL) != 0) withGid++;
    }

    if (seen > 0 && withGid == 0) {
        g_gidless = 1;

        if (g_gidless_logs < 2) {
            g_gidless_logs++;

            TNX_LOGX("gidless container=%p seen=%d withGid=0 - every sampled element of this list "
                     "has no global id at either +%#llx or +%#llx, which is the brawler class %#llx and "
                     "not the roster class %#llx, so rejGidZero is switched off for this container and "
                     "an element with gid 0 is kept: the id is what made the hop prefer the roster, and "
                     "the roster is the list that carries no coordinates at all",
                     (void *)manager, seen, (unsigned long long)TNX_OBJ_GLOBALID_OFF,
                     (unsigned long long)TNX_GID_FALLBACK_OFF, (unsigned long long)0xff5440ULL,
                     (unsigned long long)0xf9e248ULL);
        }

        return;
    }
}

int g_gidoff_logs = 0;

uintptr_t tnx_list_gid_off(uintptr_t array, int32_t count) {
    uintptr_t off = TNX_OBJ_GLOBALID_OFF;
    int sawAt8 = 0;
    int sawAt50 = 0;
    int i = 0;
    int32_t v = 0;

    if (!array || count <= 0) return off;

    for (i = 0; i < count && i < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr(array + (uintptr_t)i * sizeof(void *), &element) || !element) continue;

        if (tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &v) && v != 0) sawAt8++;
        if (tnx_read_i32((uintptr_t)element + TNX_GID_FALLBACK_OFF, &v) && v != 0) sawAt50++;
    }

    if (sawAt8 > 0) {
        off = TNX_OBJ_GLOBALID_OFF;
    } else if (sawAt50 > 0) {
        off = TNX_GID_FALLBACK_OFF;
    }

    if (g_gidoff_logs < TNX_GIDOFF_LOGS) {
        g_gidoff_logs++;

        TNX_LOGX("gid-off array=%p count=%d chosen=+%#llx sawAt+%#llx=%d sawAt+%#llx=%d - the id "
                 "offset is chosen ONCE for the whole list from its first four elements and not per "
                 "element, because a per-element choice would read the roster class (id at +%#llx) "
                 "and the player class (id at +%#llx) with different offsets inside one list and the "
                 "smallest id would then be meaningless",
                 (void *)array, count, (unsigned long long)off,
                 (unsigned long long)TNX_OBJ_GLOBALID_OFF, sawAt8,
                 (unsigned long long)TNX_GID_FALLBACK_OFF, sawAt50,
                 (unsigned long long)TNX_GID_FALLBACK_OFF,
                 (unsigned long long)TNX_OBJ_GLOBALID_OFF);
    }

    return off;
}

int g_stage = 0;

int g_stuck = 0;

int32_t g_last_x = 0;

int32_t g_last_y = 0;

int g_logs_3 = 0;

int g_moves_logs = 0;

int g_dead = 0;

int g_revive_logs = 0;

int g_own_team_3 = -1;

int g_proj_own = 0;

int g_proj_other = 0;

int g_own_team_seen = 0;

int g_filter_logs = 0;

int g_drop_along = 0;

int g_drop_reach = 0;

int g_live_threats = 0;

int g_team_other_seen = 0;

int g_stick_cleared = 0;

uintptr_t g_proj_addr = 0;

uint8_t g_proj_bytes[TNX_DIFF_BYTES];

int g_proj_have = 0;

int g_proj_dumps = 0;

uint64_t g_proj_diff_logs = 0;

uint64_t g_proj_firsts = 0;

void tnx_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team) {
    uint8_t now[TNX_DIFF_BYTES];
    int i;

    if (!elem) return;
    if (!tnx_read_bytes(elem, now, sizeof(now))) return;

    if (elem != g_proj_addr) {
        g_proj_firsts++;
        g_proj_addr = elem;
        memcpy(g_proj_bytes, now, sizeof(now));
        g_proj_have = 1;

        if (g_proj_dumps < TNX_DUMPS) {
            g_proj_dumps++;

            TNX_LOGX("proj FIRST elem=%p classRva=%#llx gid=%d team=%d firsts=%llu - the element "
                     "id changed, so this is either a fresh spawn or the same slot reused; the whole "
                     "first %#x bytes follow one qword per line",
                     (void *)elem, (unsigned long long)classRva, gid, team,
                     (unsigned long long)g_proj_firsts, TNX_DIFF_BYTES);

            for (i = 0; i < TNX_DIFF_BYTES; i += 8) {
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

                TNX_LOGX("proj FIRST +%02x = %#018llx lo=%d hi=%d loF=%.3f hiF=%.3f",
                         i, (unsigned long long)q, lo, hi, (double)loF, (double)hiF);
            }
        }

        return;
    }

    if (!g_proj_have) {
        memcpy(g_proj_bytes, now, sizeof(now));
        g_proj_have = 1;

        return;
    }

    for (i = 0; i < TNX_DIFF_BYTES; i++) {
        if (g_proj_bytes[i] == now[i]) continue;

        g_proj_diff_logs++;

        if (g_proj_diff_logs <= TNX_DIFF_LOGS) {
            uint64_t oldQ = 0;
            uint64_t newQ = 0;
            int base = i & ~7;

            memcpy(&oldQ, g_proj_bytes + base, 8);
            memcpy(&newQ, now + base, 8);

            TNX_LOGX("proj DIFF +%02x old=%02x new=%02x gid=%d q_old=%#018llx q_new=%#018llx - "
                     "a byte that changes between two ticks while the address stays the same is a "
                     "field of the moving object; a position pair is the first int32/int32 or "
                     "float/float that walks",
                     i, g_proj_bytes[i], now[i], gid, (unsigned long long)oldQ,
                     (unsigned long long)newQ);
        }
    }

    memcpy(g_proj_bytes, now, sizeof(now));
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

int tnx_mode_real(uintptr_t mode, uintptr_t *vtOut, uintptr_t *chainOut,
                             uintptr_t *innerOut) {
    void *vtable = NULL;
    void *chain = NULL;
    void *inner = NULL;
    uintptr_t rva = 0;

    if (vtOut) *vtOut = 0;
    if (chainOut) *chainOut = 0;
    if (innerOut) *innerOut = 0;

    if (!mode) return 0;
    if (!tnx_read_ptr(mode, &vtable) || !vtable) return 0;

    rva = (uintptr_t)vtable - g_base;

    if (vtOut) *vtOut = rva;
    if (rva < TNX_DC_RVA_LO || rva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &chain) || !chain) return 0;
    if (chainOut) *chainOut = (uintptr_t)chain;

    if (!g_players_object) return 0;
    if ((uintptr_t)chain == g_players_object) return 1;

    if (!tnx_read_ptr((uintptr_t)chain + TNX_CLIENT_HOP_OFF, &inner) || !inner) return 0;
    if (innerOut) *innerOut = (uintptr_t)inner;

    if ((uintptr_t)inner == g_players_object) return 1;

    return 0;
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

int g_latch_logs = 0;

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

int tnx_read_flag(void) {
    uint8_t b = 0;

    if (!g_scene_object) return -1;
    if (!tnx_read_u8((uintptr_t)g_scene_object + TNX_FLAG_OFF, &b)) return -1;

    return (int)b;
}

int g_mode_seen7 = 0;

int g_mode_max = 0;

int g_gate_seen = 0;

uintptr_t g_own_obj = 0;

uintptr_t g_elem = 0;

int32_t g_elem_x0 = 0;

int32_t g_elem_y0 = 0;

int32_t g_own_before_x = 0;

int32_t g_own_before_y = 0;

int g_setter_called = 0;

int g_elem_called = 0;

int g_rb_logs = 0;

uintptr_t g_own_elem = 0;

uint64_t g_own_stamp = 0;

int g_own_logs_6 = 0;

int tnx_vt_ok(uintptr_t obj, uintptr_t *vtOut) {
    void *vt = NULL;
    uintptr_t vtRva = 0;

    if (vtOut) *vtOut = 0;
    if (!obj) return 0;
    if (obj & 7) return 0;
    if (!tnx_read_ptr(obj, &vt) || !vt) return 0;
    if ((uintptr_t)vt < g_base) return 0;

    vtRva = (uintptr_t)vt - g_base;

    if (vtRva < TNX_DC_RVA_LO || vtRva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (vtOut) *vtOut = (uintptr_t)vt;

    return 1;
}

int tnx_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut) {
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

    if (!tnx_addr_readable(cand, TNX_MIN_OBJ_BYTES)) {
        if (why) *why = "not-readable";

        return 0;
    }

    if (!tnx_vt_ok(cand, &vt)) {
        if (why) *why = "vtable-not-in-data-const";

        return 0;
    }

    if (!tnx_read_i32(cand + TNX_GATE_FLAG_OFF, &gate)) {
        if (why) *why = "gate-unreadable";

        return 0;
    }

    if (why) *why = "ok";
    if (vtOut) *vtOut = vt;

    return 1;
}

uintptr_t tnx_hop(uintptr_t base, int *whyOut) {
    void *p = NULL;
    void *q = NULL;

    if (whyOut) *whyOut = 0;
    if (!base) {
        if (whyOut) *whyOut = 1;

        return 0;
    }

    if (!tnx_read_ptr(base + TNX_CTRL_MODE_OFF, &p) || !p) {
        if (whyOut) *whyOut = 2;

        return 0;
    }

    if (!tnx_read_ptr((uintptr_t)p + TNX_OWN_INNER_OFF, &q) || !q) {
        if (whyOut) *whyOut = 3;

        return 0;
    }

    return (uintptr_t)q;
}

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

void tnx_setter(int32_t vx, int32_t vy) {
    uintptr_t fn = tnx_entry_2(TNX_SETPRED4_RVA);
    uintptr_t own = tnx_own_obj();
    int32_t alive = 0;

    g_setter_called = 0;

    if (!TNX_ACT_SETTER) return;
    if (!fn || !own) return;
    if (!tnx_read_i32(own + TNX_GATE_X_OFF, &g_own_before_x)) return;
    if (!tnx_read_i32(own + TNX_GATE_Y_OFF, &g_own_before_y)) return;
    if (!tnx_read_i32(own + TNX_OWN_ALIVE_OFF, &alive)) return;

    g_own_obj = own;

    ((void (*)(void *, int, int, int))fn)((void *)own, vx, vy, TNX_SETFLAG);

    g_setter_called = 1;

    TNX_LOGX("setter own=%p x=%d y=%d flag=%d in10c was=%d in110 was=%d alive140=%d - this is the "
             "exact call the engine makes for itself at %#llx, where it passes the getOwnCharacter "
             "result and the clamped stick pair; the receiver is read the same way here (%#llx then its "
             "+%#llx) and never guessed, and the pair is never (0,0) because the apply path has to see a "
             "movement and not a release",
             (void *)own, vx, vy, TNX_SETFLAG, g_own_before_x, g_own_before_y, alive,
             (unsigned long long)0x79de14ULL, (unsigned long long)TNX_OWN_OFF,
             (unsigned long long)TNX_OWN_INNER_OFF);
}

void tnx_elem_write(uintptr_t element, int32_t vx, int32_t vy) {
    int32_t was = 0;

    g_elem_called = 0;

    if (!TNX_ACT_ELEM) return;
    if (!element) return;
    if (!tnx_read_i32(element + TNX_OBJ_X_OFF, &g_elem_x0)) return;
    if (!tnx_read_i32(element + TNX_OBJ_Y_OFF, &g_elem_y0)) return;

    g_elem = element;
    was = g_elem_x0;

    if (!tnx_write_bytes(element + TNX_OBJ_X_OFF, &vx, sizeof(vx))) return;
    if (!tnx_write_bytes(element + TNX_OBJ_Y_OFF, &vy, sizeof(vy))) return;

    g_elem_called = 1;

    TNX_LOGX("elemwrite elem=%p x=%d y=%d was=(%d,%d) - the int pair at +%#llx/+%#llx of the walked "
             "element is written directly and read back a whole second later, because the v123 probe read "
             "through four frames and a server that reconciles on a 50 ms cadence would still look "
             "successful there; the difference between a local shadow and an authoritative position is "
             "exactly whether the pair is still ours a second later",
             (void *)element, vx, vy, was, g_elem_y0, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF);
}

int tnx_mode(void) {
    int32_t mode = -1;

    if (!g_scene_object) return -1;
    if (!tnx_read_i32((uintptr_t)g_scene_object + TNX_MODE_OFF, &mode)) return -1;

    return (int)mode;
}

int tnx_inner(void) {
    void *holder = NULL;
    uint8_t b = 0;

    if (!g_scene_object) return -1;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_GATE_PTR_OFF, &holder) || !holder) return -1;
    if (!tnx_read_u8((uintptr_t)holder + TNX_GATE_BYTE_OFF, &b)) return -1;

    return (int)b;
}

int tnx_gate(void) {
    int mode = tnx_mode();

    if (mode < 0) return -1;
    if (mode != TNX_MODE_TARGET) return 0;
    if (tnx_inner() != 1) return 0;

    return 1;
}

uintptr_t tnx_client(void) {
    void *client = NULL;

    if (!g_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)g_scene_object + TNX_CLIENT_OFF, &client)) return 0;

    return (uintptr_t)client;
}

uintptr_t g_own_ptr_3 = 0;

int32_t g_own_gid = 0;

int g_own_logs_4 = 0;

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

int g_own_logs_5 = 0;

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

void tnx_state_note(int state) {
    if (g_prev_state == 5 && state != 5) {
        g_ok = 0;
        g_tested = 0;
        g_test_state = 0;
        g_moved = 0;
        g_moved2 = 0;
        g_kept = 0;
        g_test_after_x = 0;
        g_test_after_y = 0;
        g_mgr = 0;
        g_mgr_logs = 0;
        g_other_logs = 0;
        g_other_detail = 0;
        g_wide_runs = 0;
        g_own_index = -1;
        g_own_ptr = 0;
        g_own_ptr_2 = 0;
        g_own_index_2 = -1;
        g_own_from_2 = "v103-reset";

        TNX_LOGX("chain reset reason=state-left-5 prev=%d state=%d writes=%llu tested=%d - every "
                 "pointer cached from the finished battle is dropped so the next battle resolves "
                 "scene, manager, own and the containers again from scratch",
                 g_prev_state, state, (unsigned long long)g_writes, g_tested);
    }

    if (state == 5 && g_prev_state != 5) {
        g_attempt++;

        g_start_logged = 0;
        g_dump_done = 0;
        g_coord_logs = 0;
        g_done = 0;
        g_owner = 0;
        g_owner_2 = 0;
        g_wired = 0;
    }

    g_prev_state = state;
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

tnx_proj_t g_projs[TNX_PROJ_MAX];

int g_side_hits = 0;

int g_side_projs = 0;

int g_proj_skipped = 0;

int tnx_proj_scan(uintptr_t manager, int32_t count) {
    void *array = NULL;
    int found = 0;
    int k;
    int32_t i;

    if (!manager || count <= 0) return 0;
    if (count > TNX_COUNT_MAX) count = TNX_COUNT_MAX;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        g_projs[k].classRva = (uintptr_t)-1;
    }

    g_proj_own = 0;
    g_proj_other = 0;

    for (i = 0; i < count && found < TNX_PROJ_MAX; i++) {
        void *element = NULL;
        void *vtable = NULL;
        uintptr_t vtRva = 0;
        int32_t gid = 0;
        int32_t px = 0;
        int32_t py = 0;
        int slot = -1;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8ULL, &element) || !element) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable) || !vtable) continue;

        vtRva = (uintptr_t)vtable - g_base;

        gid = tnx_gid((uintptr_t)element, NULL);

        if (gid < TNX_PLAYER_GID_MAX) continue;

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

                TNX_LOGX("proj class seen classRva=%#llx gid=%d classes=%d/4 - every class "
                         "named here is fed to the threat test, and one whose pair at +%#llx/+%#llx "
                         "does not move drops out on its own",
                         (unsigned long long)vtRva, gid, seenClsN,
                         (unsigned long long)TNX_OBJ_X_OFF, (unsigned long long)TNX_OBJ_Y_OFF);
            }
        }

        if (TNX_PROJ_CLASS_ONLY && vtRva != (uintptr_t)TNX_CLASS_PROJ_RVA) {
            g_proj_skipped++;

            continue;
        }

        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py)) continue;

        for (k = 0; k < TNX_PROJ_MAX; k++) {
            if (g_projs[k].elem != (uintptr_t)element) continue;

            slot = k;

            break;
        }

        if (slot < 0) {
            for (k = 0; k < TNX_PROJ_MAX; k++) {
                if (g_projs[k].classRva != (uintptr_t)-1) continue;

                slot = k;

                break;
            }
        }

        if (slot < 0) continue;

        if (g_projs[slot].elem == (uintptr_t)element) {
            if (px != g_projs[slot].x || py != g_projs[slot].y) {
                g_projs[slot].px = g_projs[slot].x;
                g_projs[slot].py = g_projs[slot].y;
                g_projs[slot].ptick = g_projs[slot].qtick;
                g_projs[slot].hasPrev = 1;
            }
        } else {
            g_projs[slot].elem = (uintptr_t)element;
            g_projs[slot].px = px;
            g_projs[slot].py = py;
            g_projs[slot].spawnX = px;
            g_projs[slot].spawnY = py;
            g_projs[slot].ptick = g_ticks_3;
            g_projs[slot].hasPrev = 0;
        }

        {
            uintptr_t teamOff = (g_team_off == (int)TNX_OBJ_TEAM_OFF) ? TNX_OBJ_TEAM_OFF
                                                                         : TNX_TEAM_OFF;
            int32_t pteam = -1;
            int attributed = 0;

            if (tnx_read_i32((uintptr_t)element + teamOff, &pteam) && pteam >= 0 &&
                pteam <= TNX_OBJ_TEAM_MAX) {
                g_projs[slot].team = pteam;
            } else {
                int side = tnx_own_side_spawn(px, py);

                if (side == 1 && g_own_team_4 >= 0) {
                    g_projs[slot].team = g_own_team_4;
                    g_attrib_hits++;
                    attributed = 1;
                } else {
                    g_projs[slot].team = -1;
                    g_attrib_miss++;
                }
            }

            if (g_projs[slot].team >= 0) {
                if (g_projs[slot].team == g_own_team_3) g_proj_own++;
                else g_proj_other++;
            }

            if (attributed && g_attrib_logs < TNX_ATTRIB_LOGS) {
                g_attrib_logs++;

                TNX_LOGX("own shot by spawn gid=%d side=%d ownTeam=%d spawn=(%d,%d) own=(%d,%d)"
                         " hits=%d miss=%d - the team byte on this element is unreadable, so the "
                         "side comes from the spot the shot started on: a projectile leaves its "
                         "owner's body, so the nearest player to the first position that was seen "
                         "names the side, and an ambiguous or distant spawn stays unknown and stays "
                         "a threat, because calling an enemy shot ours opens a hole, not closes one",
                         gid, g_projs[slot].team, g_own_team_3, px, py, g_own_x,
                         g_own_y, g_attrib_hits, g_attrib_miss);
            }
        }

        g_projs[slot].classRva = vtRva;
        g_projs[slot].x = px;
        g_projs[slot].y = py;
        g_projs[slot].gid = gid;
        g_projs[slot].qtick = g_ticks_3;

        found++;
    }

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        if (g_projs[k].classRva != (uintptr_t)-1) continue;

        g_projs[k].elem = 0;
        g_projs[k].hasPrev = 0;
    }

    if (g_proj_other > 0 && !g_team_other_seen) {
        g_team_other_seen = 1;

        if (g_filter_logs < 6) {
            g_filter_logs++;

            TNX_LOGX("threat filter armed on the first shot of another team: own team %d against %d "
                     "tracked shots that are not ours, and the latch stays closed for the rest of the "
                     "battle - the v173 run never printed this line because the arming test asked for "
                     "both teams inside one scan, and with the filter off the ring spends itself on our "
                     "own bullets, which is the 'it only dodges while I shoot' the user reports",
                     g_own_team_3, g_proj_other);
        }
    }

    if (g_team_other_seen) g_own_team_seen = 1;

    return found;
}

uintptr_t tnx_controller(void) {
    uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
    void *obj = NULL;

    if (!battleFn) return 0;

    obj = ((void *(*)(void))battleFn)();

    if (!obj) return 0;
    if (((uintptr_t)obj & 7) != 0) return 0;
    if (!tnx_addr_readable((uintptr_t)obj, 0x1000)) return 0;

    return (uintptr_t)obj;
}

void tnx_watch(int32_t ownX, int32_t ownY) {
    if (ownX == g_last_x && ownY == g_last_y) {
        g_stuck++;

        return;
    }

    g_stuck = 0;
    g_last_x = ownX;
    g_last_y = ownY;
}

int g_tnx_verbose = TNX_VERBOSE_DEFAULT;

int g_signal_logs = 0;

void tnx_death_signals(uintptr_t ownElem, int32_t ownX, int32_t ownY) {
    static int lastDead = -999;
    static int lastOwnAlive = -999;
    static int lastCtrlAlive = -999;
    uintptr_t ctrl = 0;
    uint8_t deadByte = 0;
    int dead = -1;
    int ownAlive = -1;
    int ctrlAlive = -1;

    if (!ownElem) return;

    if (tnx_read_bytes(ownElem + TNX_DEAD_OFF, &deadByte, sizeof(deadByte))) dead = (int)deadByte;

    if (!tnx_read_i32(ownElem + TNX_OWN_ALIVE_OFF, &ownAlive)) ownAlive = -1;

    ctrl = tnx_controller();

    if (ctrl && !tnx_read_i32(ctrl + TNX_CTRL_ALIVE_OFF, &ctrlAlive)) ctrlAlive = -1;

    if (dead == lastDead && ownAlive == lastOwnAlive && ctrlAlive == lastCtrlAlive) return;

    lastDead = dead;
    lastOwnAlive = ownAlive;
    lastCtrlAlive = ctrlAlive;

    if (g_signal_logs >= 12) return;

    g_signal_logs++;

    TNX_LOGX("death signals own=%p (%d,%d) deadByte@+%#llx=%d own+0x140=%d ctrl+0xf80=%d - the "
             "guard used the walk's dead byte at +%#llx and held the dodge while the player was "
             "alive, because that byte reads %d on a live object; whichever of these three moves on a "
             "real death is the one to guard on", (void *)ownElem, ownX, ownY,
             (unsigned long long)TNX_DEAD_OFF, dead, ownAlive, ctrlAlive,
             (unsigned long long)TNX_DEAD_OFF, dead);
}

void tnx_alive(int32_t ownX, int32_t ownY) {
    if (!g_dead) return;

    g_dead = 0;
    g_stick_cleared = 0;

    if (g_revive_logs < 4) {
        g_revive_logs++;

        TNX_LOGX("own is alive again at (%d,%d): the dodge resumes from stage %d with a cleared "
                 "heading and a cleared write clock, which is what the last life's state would "
                 "otherwise keep frozen", ownX, ownY, g_stage);
    }
}

int g_map_dumps = 0;

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

void tnx_census(void) {
    void *array = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int players = 0;
    int shots = 0;
    int other = 0;
    int projClass = 0;

    if ((g_ticks_3 % 60) != 0) return;
    if (!g_manager) return;
    if (!tnx_read_i32(g_manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0 || count > TNX_COUNT_MAX) return;
    if (!tnx_read_ptr(g_manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;

    for (i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * 8, &element) || !element) continue;

        gid = tnx_gid((uintptr_t)element, NULL);

        {
            void *vtx = NULL;

            if (tnx_read_ptr((uintptr_t)element, &vtx) && vtx &&
                ((uintptr_t)vtx - g_base) == (uintptr_t)TNX_CLASS_PROJ_RVA) projClass++;
        }

        if (gid >= TNX_SHOT_GID && gid < TNX_SHOT_GID_MAX) shots++;
        else if (gid >= TNX_PLAYER_GID && gid < TNX_SHOT_GID) players++;
        else other++;
    }

    TNX_LOGX("census count=%d players=%d shots=%d other=%d projClass=%d skipped=%d manager=%p - one line a second with "
             "the container split by gid band, so a dodge that reports segs=0 says whether there was "
             "anything to dodge at all: the 17:53 run held only players and two objects in the four "
             "million band, one of them standing still and one moving at two units a frame, while the "
             "projectiles that were recognised in the 17:12 and 17:45 runs carry gids in the %d band",
             count, players, shots, other, projClass, g_proj_skipped, (void *)g_manager,
             TNX_SHOT_GID);
}

int tnx_own(int32_t *xOut, int32_t *yOut) {
    uintptr_t own = g_own_elem_2;

    if (!own) own = (uintptr_t)g_own_elem;
    if (!own) return 0;
    if (!tnx_read_i32(own + TNX_OBJ_X_OFF, xOut)) return 0;
    if (!tnx_read_i32(own + TNX_OBJ_Y_OFF, yOut)) return 0;

    return 1;
}

float g_walk_step = TNX_STEP_3;

int32_t g_prev_x_3 = 0;

int32_t g_prev_y_3 = 0;

int g_prev_ok = 0;

uint64_t g_measured = 0;

float tnx_step(void) {

    return TNX_STEP_3;
}

void tnx_measure(void) {
    int32_t x = 0;
    int32_t y = 0;
    float d = 0.0f;

    if (!tnx_own(&x, &y)) return;

    if (g_prev_ok && !g_hold) {
        float ddx = (float)(x - g_prev_x_3);
        float ddy = (float)(y - g_prev_y_3);

        d = sqrtf(ddx * ddx + ddy * ddy);

        if (d > 0.5f) {
            float inv = 1.0f / d;

            g_last_x_3 = ddx * inv;
            g_last_y_3 = ddy * inv;
            g_last_ok = 1;
            g_hseed++;
        }

        if (d > 0.5f && d < TNX_WALK_MAX * 3.0f) {
            g_walk_step = g_walk_step * (1.0f - TNX_WALK_EMA) + d * TNX_WALK_EMA;
            g_measured++;

            if (g_walk_step < TNX_WALK_MIN) g_walk_step = TNX_WALK_MIN;
            if (g_walk_step > TNX_WALK_MAX) g_walk_step = TNX_WALK_MAX;
        }
    }

    g_prev_x_3 = x;
    g_prev_y_3 = y;
    g_prev_ok = 1;
}

const char *const g_names[TNX_BASES] = { "scene", "mgr", "ctrl", "char", "enemy" };

tnx_win_t g_win[TNX_BASES];

uintptr_t tnx_hop_2(uintptr_t base, uintptr_t off) {
    void *raw = NULL;

    if (!base) return 0;
    if (!tnx_read_ptr(base + off, &raw) || !raw) return 0;
    if (((uintptr_t)raw & 7) != 0) return 0;
    if (!tnx_addr_readable((uintptr_t)raw, 8)) return 0;

    return (uintptr_t)raw;
}

int tnx_snapshot_2(uintptr_t base, uint32_t *out) {
    int i = 0;

    for (i = 0; i < TNX_WORDS; i++) {
        int32_t word = 0;

        if (!tnx_read_i32(base + (uintptr_t)i * 4, &word)) return 0;

        out[i] = (uint32_t)word;
    }

    return 1;
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

void tnx_scan(void) {
    int b = 0;

    if ((g_ticks_3 % TNX_BUCKET_TICKS) != 0) return;

    for (b = 0; b < TNX_BASES; b++) {
        tnx_win_t *w = &g_win[b];
        const char *name = g_names[b];
        uint32_t cur[TNX_WORDS];
        int picked[TNX_MAX_LINES];
        uintptr_t base = 0;
        int changed = 0;
        int shown = 0;
        int hotMax = 0;
        int i = 0;
        int p = 0;

        if (b == 0) base = (uintptr_t)g_scene_object;
        else if (b == 1) base = tnx_hop_2((uintptr_t)g_scene_object, TNX_MODE_MANAGER_OFF);
        else if (b == 2) base = tnx_controller();
        else if (b == 3) base = g_own_elem_2;
        else base = g_enemy_elem;

        if (!base) {
            if (w->have) {
                TNX_LOGX("%s gone: the base was %p and is not there now, so the window and its "
                         "hot counts are dropped and reseeded when it returns", name, (void *)w->base);
            }

            w->base = 0;
            w->have = 0;

            continue;
        }

        if (w->base != base) {
            w->base = base;
            w->have = 0;

            for (i = 0; i < TNX_WORDS; i++) w->hot[i] = 0;
        }

        if (!tnx_snapshot_2(base, cur)) {
            if (w->have) {
                TNX_LOGX("%s window unreadable at %p - the snapshot is dropped instead of being "
                         "compared against a stale one", name, (void *)base);
            }

            w->have = 0;

            continue;
        }

        if (!w->have) {
            memcpy(w->prev, cur, sizeof(cur));

            w->have = 1;

            continue;
        }

        for (i = 0; i < TNX_WORDS; i++) {
            if (cur[i] == w->prev[i]) continue;

            changed++;

            if (w->hot[i] < 65000) w->hot[i]++;
            if ((int)w->hot[i] > hotMax) hotMax = (int)w->hot[i];
        }

        for (p = 0; p < TNX_MAX_LINES; p++) {
            int best = -1;
            int pickHot = -1;
            int k = 0;
            int seen = 0;

            for (i = 0; i < TNX_WORDS; i++) {
                seen = 0;

                if (cur[i] == w->prev[i]) continue;

                for (k = 0; k < p; k++) {
                    if (picked[k] == i) {
                        seen = 1;

                        break;
                    }
                }

                if (seen) continue;

                if ((int)w->hot[i] > pickHot) {
                    pickHot = (int)w->hot[i];
                    best = i;
                }
            }

            if (best < 0) break;

            picked[p] = best;
            shown++;
        }

        if (changed > 0) {
            TNX_LOGX("%s base=%p changed=%d shown=%d hotMax=%d - the window is %#x bytes of the "
                     "base, the slots below are the changed ones with the highest hot count, capped at "
                     "%d, and hotMax is the best any slot in the window has ever reached, so a window "
                     "whose whole hot column is still zero is reported as such",
                     name, (void *)base, changed, shown, hotMax, (unsigned)TNX_WIN,
                     TNX_MAX_LINES);
        }

        for (p = 0; p < shown; p++) {
            tnx_slot_line(name, w, picked[p], w->prev[picked[p]], cur[picked[p]]);
        }

        memcpy(w->prev, cur, sizeof(cur));
    }
}

int g_owner_logs = 0;

uint64_t g_dropped_2 = 0;

int tnx_proj_mine(const tnx_proj_t *p) {
    int i = 0;
    int bestMine = 0;
    float best = 1.0e18f;
    float sx = 0.0f;
    float sy = 0.0f;

    if (!TNX_PROJ_OWNER) return 0;
    if (!g_team_trust) return 0;
    if (g_pl_n <= 0) return 0;
    if (g_own_team_4 >= 0 && p->team == g_own_team_4) return 1;
    if (!p->spawnX && !p->spawnY) return 0;

    sx = (float)p->spawnX;
    sy = (float)p->spawnY;

    for (i = 0; i < g_pl_n; i++) {
        float dx = sx - (float)g_pl_x[i];
        float dy = sy - (float)g_pl_y[i];
        float d = dx * dx + dy * dy;

        if (d < best) {
            best = d;
            bestMine = g_pl_mine[i];
        }
    }

    if (best > TNX_SPAWN_R * TNX_SPAWN_R) return 0;

    if (bestMine) {
        g_dropped_2++;

        if (g_owner_logs < TNX_OWNER_LOGS) {
            g_owner_logs++;

            TNX_LOGX("owner gid-less team=%d spawn=(%d,%d) nearest=%.0f mine=1 dropped=%llu - "
                     "the shot starts on an own-side body, so it belongs to own side whatever its "
                     "team byte says and it is not a threat",
                     p->team, p->spawnX, p->spawnY, (double)sqrtf(best),
                     (unsigned long long)g_dropped_2);
        }
    }

    return bestMine;
}

uint64_t tnx_upd_delta(void) {
    uint64_t now = g_update_hits;
    uint64_t d = now - g_prev_upd;

    g_prev_upd = now;

    return d;
}

uint64_t tnx_rend_delta(void) {
    uint64_t now = (uint64_t)g_render_calls;
    uint64_t d = now - g_prev_rend;

    g_prev_rend = now;

    return d;
}

void tnx_state(void) {
    g_census_container = 0;
    g_census_array = 0;
    g_census_first = 0;
    g_census_ms = 0;

    g_mgr = (uintptr_t)tnx_manager();

    TNX_LOGX("state joystick=%p writes=%llu took=%llu escapes=%llu lookahead=%llu appliedW=%llu "
             "appliedLive=%llu appliedStale=%llu rage=%llu flees=%llu deadRep=%llu clamped=%llu qDrain=%llu qMax=%llu qNow=%llu qStuck=%llu qMask=%#llx dragW=%llu dragLive=%llu mateTurn=%llu mateStuck=%llu keep=%llu engage=%llu hseed=%llu clearEval=%llu stickOnly=%llu reentry=%llu rSkip=%llu uSkip=%llu U1orig=%p U2orig=%p upd=%llu updMove=%llu ticks=%llu updD=%llu rendD=%llu gateNow=%d decUs=%llu maxUs=%llu slow=%llu diagMax=%llu g70w=%llu g70h=%llu dropS=%llu dropF=%llu dropB=%llu spd=(%.0f..%.0f) "
             "dead=%llu denied=%llu "
             "predTook=%llu predMiss=%llu objects scene=%p character=%p battle=%p - writes counts the "
             "frames the drag block was written, took counts the frames the engine still held it with "
             "mode 2, escapes counts the frames the dodge moved on the clearance pick instead of "
             "standing still, lookahead counts the frames the dodge engaged on time to impact instead "
             "of waiting for contact, appliedW counts the frames the push tail of the engine was replayed, "
             "appliedLive how many the movement code kept and appliedStale how many it overwrote, rage "
             "counts the frames rage mode forced the pick, flees and deadRep count the picks taken by the "
             "flee fallback and the ones it had to replace because the pick sat on own, clamped counts the "
             "steps cut down to the reference step of %d units, qDrain counts the "
             "pushes the engine emptied within the same frame and qMax the deepest the queue ever got, qNow "
             "the depth seen just before the push, qStuck the pushes that found the previous input of "
             "type %d still sitting there unconsumed, and qMask the types pending at that moment, so "
             "a qMax that climbs while qDrain stays zero means the input is never consumed, dragW counts the drag "
             "writes in screen space and dragLive how many still showed a non zero drag when read "
             "back, mateTurn and mateStuck count the steps rotated "
             "off a player body, own side or enemy and the ones no rotation could free, keep counts the frames the "
             "previous heading was kept because no turn beat it by the keep band, engage the frames the threat "
             "was close enough to act on, hseed the frames the momentum heading was taken from the own "
             "movement of the player so the dodge leans the way they already walk, clearEval the number of swept "
             "clearance samples taken, stickOnly the frames the position channels were suppressed so the pair at "
             "the control object is the only thing driving the body, upd and updMove the times the game own update "
             "and movement update ran through this build, ticks the times the drive ran from inside that tick, "
             "and decUs is the microseconds from the "
             "hook entry to the stick write with maxUs the worst of them, slow the frames above %d us and "
             "diagMax the worst time the throttled diagnostic block took, g70w the frames the state byte "
             "at %#llx was forced to 1 and g70h how many of them the engine kept it, dropS dropF dropB the "
             "shots thrown away as too slow, too fast and too short lived and spd the speed range seen, "
             "dead counts the frames the control object failed the alive check so every store into it was "
             "skipped, and denied counts the stores the region guard dropped, walkMeas is the per push own displacement measured while the player walked %.0f",
             (void *)g_joystick, (unsigned long long)g_joystick_writes,
             (unsigned long long)g_joystick_took, (unsigned long long)g_escapes,
             (unsigned long long)g_lookahead, (unsigned long long)g_applied_writes,
             (unsigned long long)g_applied_live, (unsigned long long)g_applied_stale,
             (unsigned long long)g_rage_frames, (unsigned long long)g_flees,
             (unsigned long long)g_dead_replaced, (unsigned long long)g_clamped,
             (unsigned long long)g_drain,
             (unsigned long long)g_q_max, (unsigned long long)g_q_before_2,
             (unsigned long long)g_stuck_3, (unsigned long long)g_mask_before, (unsigned long long)g_drag_writes,
             (unsigned long long)g_drag_back, (unsigned long long)g_mate_turns,
             (unsigned long long)g_mate_stuck, (unsigned long long)g_keeps,
             (unsigned long long)g_engage, (unsigned long long)g_hseed, (unsigned long long)g_evals, (unsigned long long)g_pos_skips, (unsigned long long)g_reentry,
             (unsigned long long)g_render_skip, (unsigned long long)g_update_skip,
             (void *)g_slot_orig[32], (void *)g_slot_orig[33], (unsigned long long)g_update_hits,
             (unsigned long long)g_move_hits, (unsigned long long)g_ticks,
             (unsigned long long)tnx_upd_delta(), (unsigned long long)tnx_rend_delta(),
             (int)tnx_gate(), (unsigned long long)g_dec_us,
             (unsigned long long)g_dec_us_max, (unsigned long long)g_slow,
             (unsigned long long)g_diag_max_us, (unsigned long long)g_gate_writes_2,
             (unsigned long long)g_gate_held, (unsigned long long)g_drop_slow,
             (unsigned long long)g_drop_fast, (unsigned long long)g_drop_blink,
             (double)g_spd_min, (double)g_spd_max,
             (unsigned long long)g_ctrl_dead, (unsigned long long)g_write_denied,
             (unsigned long long)g_pred_took, (unsigned long long)g_pred_miss,
             (void *)(uintptr_t)g_scene_object, (void *)g_own_elem_2, (void *)g_pred_last,
             (int)TNX_STEP_4, (int)TNX_TYPE_MOVE, (int)TNX_SLOW_US,
             (unsigned long long)TNX_GATE_OFF, (double)g_walk_step);

    {
        uint16_t charState = 0;
        uint16_t sceneState = 0;
        int32_t charMode = 0;

        if (g_own_elem_2) {
            tnx_read_bytes(g_own_elem_2 + TNX_JOYSTATE_OFF, &charState, sizeof(charState));
            tnx_read_i32(g_own_elem_2 + TNX_BS_MODE, &charMode);
        }

        if (g_scene_object) {
            tnx_read_bytes((uintptr_t)g_scene_object + TNX_JOYSTATE_OFF, &sceneState,
                           sizeof(sceneState));
        }

        uint8_t gate70 = 0;

        if (g_pred_last) {
            tnx_read_bytes(g_pred_last + TNX_GATE_OFF, &gate70, sizeof(gate70));
        }

        uint16_t enState[2] = { 0, 0 };
        int32_t enMode[2] = { 0, 0 };
        int seen = 0;
        int k = 0;

        for (k = 0; k < g_dodge_probe_usable && seen < 2; k++) {
            const tnx_obj_t *o = &g_dodge_probe_list[k];
            uint16_t st = 0;
            int32_t md = 0;

            if (!o->object) continue;
            if (o->gid < TNX_PLAYER_GID) continue;
            if (o->gid >= TNX_SHOT_GID) continue;
            if (g_own_elem_2 && o->object == g_own_elem_2) continue;
            if (!tnx_read_bytes((uintptr_t)o->object + TNX_JOYSTATE_OFF, &st, sizeof(st))) continue;

            tnx_read_i32((uintptr_t)o->object + TNX_BS_MODE, &md);
            enState[seen] = st;
            enMode[seen] = md;
            seen++;
        }

        TNX_LOGX("joy char=%p state=%u mode=%d scene=%p state=%u ctrl=%p gate=%d en0=%u/%d en1=%u/%d seen=%d - the joystick on "
                 "bitfield the reference reads to decide the walk cycle is at %#llx, so the object "
                 "whose state goes non zero while the body walks is the one that owns the cycle, and en0 and en1 "
                 "are the same two fields read from two other players, so a walking enemy holding a value "
                 "the own character does not is the flag to copy",
                 (void *)g_own_elem_2, (unsigned)charState, charMode,
                 (void *)(uintptr_t)g_scene_object, (unsigned)sceneState,
                 (void *)(uintptr_t)g_joystick, (int)gate70,
                 (unsigned)enState[0], enMode[0], (unsigned)enState[1], enMode[1], seen,
                 (unsigned long long)TNX_JOYSTATE_OFF);
    }

    tnx_sd_log();

}

uint64_t tnx_word_2(uintptr_t address) {
    uint64_t value = 0;

    if (!tnx_read_bytes(address, &value, sizeof(value))) return 0;

    return value;
}

const char *tnx_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (!manager) return "no-manager";
    if (manager & 7ULL) return "manager-unaligned";
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return "array-unreadable";
    if (!array) return "array-null";
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return "count-unreadable";
    if (count <= 0) return "count-zero";
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return "cap-unreadable";
    if (count > capacity) return "count-above-cap";
    if (capacity > TNX_MGR_CAP_MAX) return "cap-above-ceiling";
    if (count > TNX_MANAGER_MAX_OBJECTS) return "count-above-ceiling";

    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return NULL;
}

uintptr_t tnx_coord_x_off(void) {
    return TNX_OBJ_X_OFF;
}

uintptr_t tnx_coord_y_off(void) {
    return TNX_OBJ_Y_OFF;
}
