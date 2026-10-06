#include "titanox.h"

int32_t t_state_prev_x = 0;

int32_t t_state_prev_y = 0;

uintptr_t t_mgr = 0;

int t_mgr_logs = 0;

int t_test_state = 0;

int t_test_after_x = 0;

int t_test_after_y = 0;

int t_moved = 0;

int t_moved2 = 0;

int t_kept = 0;

int t_tested = 0;

int t_ok = 0;

uint64_t t_writes = 0;

int t_attempt = 0;

int t_prev_state = -1;

int t_other_logs = 0;

int t_other_detail = 0;

int t_own_team_2 = -1;

int t_own_base = -1;

int t_own_logs_2 = 0;

int t_audited = 0;

uint64_t t_tick = 0;

uint64_t t_write_last = 0;

int t_write_phase = 0;

int t_write_count = 0;

int t_write_base_ok = 0;

int t_write_base_x = 0;

int t_write_base_y = 0;

int t_trace_logs = 0;

int t_trace_n = 0;

uintptr_t t_trace_obj[TNX_OBJECT_MAX];

int t_trace_x[TNX_OBJECT_MAX];

int t_trace_y[TNX_OBJECT_MAX];

int t_hop_chosen = -1;

int t_hop_sticky = 0;

int t_coord_off = -1;

int t_modesig_hits = 0;

int t_modesig_notfound = 0;

int t_floor_logged = 0;

int t_fallback_logged = 0;

int t_census_logs = 0;

int t_elem_dumps = 0;

int t_hop2_census = 0;

int t_type3_floats = 0;

uintptr_t t_census_container = 0;

int32_t t_census_count = 0;

uintptr_t t_census_array = 0;

uintptr_t t_census_first = 0;

uint64_t t_census_ms = 0;

int t_slot_dumped = 0;

int t_gate_calls = 0;

int t_own_src = -1;

uintptr_t t_own_off = 0;

uintptr_t t_scan_container = 0;

int t_scan_logs = 0;

int t_own_logged = 0;

int32_t t_wrote_x = 0;

int32_t t_wrote_y = 0;

int32_t t_own_pos_x = 0;

int32_t t_own_pos_y = 0;

uint64_t t_wrote_tick = 0;

int t_wrote_valid = 0;

int t_check_done = 0;

uint64_t t_test_writes = 0;

int t_class_dumps = 0;

const char *t_own_from_4 = "none";

int t_players_dumps = 0;

int t_hop_dumps = 0;

int t_modehit_dump = 0;

uint64_t t_prev_upd = 0;

uint64_t t_prev_rend = 0;

uint64_t t_pred_took = 0;

uint64_t t_pred_miss = 0;

int t_pred_logs = 0;

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
        if (t_vt_text_rejects < 12) {
            t_vt_text_rejects++;

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

    if (t_scene_object) return;
    if (!t_battle_active && (t_ticks_4 % TNX_BUCKET_TICKS_2) != 0) return;

    for (int i = 0; i < t_objhit_count && !found; i++) {
        if (tnx_modesig_hit(t_objhits[i].at)) found = t_objhits[i].at;
    }

    if (!found) return;

    if (t_sig_last == found) {
        t_sig_ticks++;
    } else {
        t_sig_last = found;
        t_sig_ticks = 1;

        if (t_sig_logs < 12) {
            t_sig_logs++;

            TNX_LOGX("modesig hit obj=%p sighting=1/%d - a new address, the stability counter "
                     "restarts", (void *)found, TNX_MODESIG_TICKS);
        }
    }

    if (t_sig_ticks < TNX_MODESIG_TICKS) return;

    {
        void *vt = NULL;
        void *mgr = NULL;
        int32_t ec = 0;
        int32_t m124 = 0;
        int32_t count = 0;
        int32_t cap = 0;

        t_modesig_hits++;
        t_scene_object = found;
        t_mode_source_2 = "modesig";
        t_battle_last_tick = (int)t_ticks_4;

        tnx_read_ptr(found, &vt);
        tnx_read_ptr(found + TNX_MODE_MANAGER_OFF, &mgr);
        tnx_read_i32(found + 0xecULL, &ec);
        tnx_read_i32(found + 0x124ULL, &m124);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_COUNT_OFF, &count);
        tnx_read_i32((uintptr_t)mgr + TNX_MGR_CAP_OFF, &cap);

        TNX_LOGX("modesig accepted obj=%p vt=%#llx ec=%d m124=%#x mgr=%p count=%d ticks=%d "
                 "src=SIG", (void *)found, (unsigned long long)(uintptr_t)vt, ec, (unsigned)m124,
                 mgr, count, t_sig_ticks);

        if (count >= 2 && cap >= count && cap <= TNX_MGR_CAP_MAX) {
            void *mgrArray = NULL;

            t_manager_count = count;

            if (tnx_read_ptr((uintptr_t)mgr + TNX_MGR_ARRAY_OFF, &mgrArray) && mgrArray) {
                tnx_publish((uintptr_t)mgr, (uintptr_t)mgrArray, count, cap, "modesig");
            }

            TNX_LOGX("modesig container obj=%p mgr=%p array=%p count=%d cap=%d src=SIG - read "
                     "and published as one tuple under the seqlock, or not at all",
                     (void *)found, mgr, mgrArray, count, cap);
        }
    }
}

int tnx_element_type(uintptr_t vt, uintptr_t *wordOut) {
    void *slotPtr = NULL;
    uintptr_t slot = 0;

    if (wordOut) *wordOut = 0;

    if (!vt) return -1;
    if (!tnx_read_ptr(vt + TNX_TYPE_SLOT_OFF, &slotPtr) || !slotPtr) return -1;

    slot = tnx_strip_ptr((uintptr_t)slotPtr) - t_base;

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
        int same = (container == t_census_container &&
                    (uintptr_t)array == t_census_array);
        int firstChanged = 0;

        if (tnx_read_ptr(array, &firstPtr) && firstPtr) first = (uintptr_t)firstPtr;
        firstChanged = (first != t_census_first);

        if (same && !firstChanged && t_census_ms &&
            nowMs - t_census_ms < TNX_CENSUS_MS) {
            return;
        }

        if (same) {
            TNX_LOGX("census rearmed container=%p array=%p count=%d lastCount=%d first=%p "
                     "lastFirst=%p firstChanged=%d sinceMs=%llu - the count delta rule of v135 fired "
                     "on every second of the battle because this vector is the object registry and "
                     "it grows and shrinks with projectiles, so the census printed twenty times and "
                     "the log drowned; it is now taken when the first element changes or after %d ms",
                     (void *)container, (void *)array, count, t_census_count, (void *)first,
                     (void *)t_census_first, firstChanged,
                     (unsigned long long)(t_census_ms ? nowMs - t_census_ms : 0),
                     TNX_CENSUS_MS);
        }

        t_census_container = container;
        t_census_count = count;
        t_census_array = (uintptr_t)array;
        t_census_first = (uintptr_t)first;
        t_census_ms = nowMs;
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

        classRva = tnx_strip_ptr((uintptr_t)vt) - t_base;

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
                if (t_gid_lo == 0 || gid < t_gid_lo) t_gid_lo = gid;
                if (gid > t_gid_hi) t_gid_hi = gid;
            }
        }

        if (i == 0 && type == TNX_TYPE3_CODE) t_type3_floats = 1;

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

        if (t_elem_dumps < TNX_ELEM_DUMPS_2) {
            t_elem_dumps++;

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

        if (classRva == TNX_ELEMCLASS_RVA && t_elem_full_dumps < TNX_ELEM_DUMPS_3) {
            t_elem_full_dumps++;

        }
    }

    t_census_logs++;
    t_census_container = container;

    histText[0] = 0;

    for (h = 0; h < histN; h++) {
        char one[96];
        const char *seg = tnx_image_segment_name(t_base + histRva[h]);

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
             "very container", t_hop_chosen, (void *)container, typed, count, types,
             (unsigned)typeMask, teams, gidSeen, back, count, accepted,
             (unsigned long long)(classSeen < 0 ? 0 : classSeen),
             (unsigned long long)TNX_TYPE_SLOT_OFF,
             (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_ELEM_BACK_OFF);
}

uintptr_t t_hop_scene = 0;

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

int t_gid_logs = 0;

int t_coord_logs = 0;

int t_dump_done = 0;

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

        if (t_gid_logs < 6) {
            void *vtable = NULL;
            uintptr_t vtRva = 0;

            t_gid_logs++;

            if (tnx_read_ptr(element, &vtable) && vtable) vtRva = (uintptr_t)vtable - t_base;

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

int t_score_logs = 0;

int t_last_choice = -2;

int t_hop_logs = 0;

int t_start_logged = 0;

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
        if (t_ascii_logs < TNX_ASCII_LOGS) {
            t_ascii_logs++;

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
            if (t_score_logs < 12) {
                t_score_logs++;

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

    if (t_score_logs < 12) {
        t_score_logs++;

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

NSString *tnx_status_text(void) {
    return [NSString stringWithFormat:
        @"scene=%p\ncontainer=%p count=%d hop=%d\narray=%p cap=%d\ngid=%d..%d live=%d\n"
        @"slots=%d alerts=%s\nlife=%s own=(%d,%d) team=%d mates=%d",
        (void *)t_scene_object, (void *)t_players_object, t_players_count, t_last_choice,
        (void *)t_players_array, t_players_cap, t_gid_lo, t_gid_hi, t_manager_last_live,
        TNX_SLOT_COUNT, t_alerts_off ? @"выкл" : @"вкл", tnx_state_name(),
        t_own_x, t_own_y, t_own_team_4, t_mate_n];
}

int tnx_scan_ready(int battle) {
    if (t_ticks_4 < TNX_SCAN_FLOOR_TICKS) {
        if (!t_floor_logged) {
            t_floor_logged = 1;

            TNX_LOGX("scan held to tick=%d battle=%d mode=%p - the lobby scan is what "
                     "raised the TID_SHOP trail candidate", TNX_SCAN_FLOOR_TICKS, battle,
                     (void *)t_scene_object);
        }

        return 0;
    }

    if (battle || t_scene_object) return 1;

    if (t_ticks_4 < TNX_SCAN_FALLBACK_TICKS) return 0;

    if (!t_fallback_logged) {
        t_fallback_logged = 1;

        TNX_LOGX("scan fallback at tick=%llu battle=%d mode=%p - no battle seen, resuming "
                 "on the %ds bucket", (unsigned long long)t_ticks_4, battle,
                 (void *)t_scene_object, TNX_BUCKET_TICKS_2);
    }

    return (t_ticks_4 % TNX_BUCKET_TICKS_2) == 0;
}

void tnx_resolve_addresses(void) {
    if (!t_base) return;

    t_addr_getinstance = tnx_callable(RVA_BATTLEMODE_GETINSTANCE);
    t_addr_getownchar = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    t_addr_getteam = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    t_addr_getx = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    t_addr_gety = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);

    t_addr_setprediction = tnx_callable(TNX_RVA_SETPREDICTION);

    if (!t_addr_setprediction) {
        TNX_LOGX("prediction NOT resolvable rva=%#llx - without it the body is carried by the "
                 "input queue instead of walked by the engine's own movement, which is the slide",
                 (unsigned long long)TNX_RVA_SETPREDICTION);
    }
    t_addr_sendmovement = tnx_callable(RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT);
    t_addr_getclip = tnx_callable(RVA_STRINGTABLE_GETMOVIECLIP);
    t_addr_addchild = tnx_callable(RVA_STAGE_ADDCHILD);

    t_addr_gettf = tnx_pick(TNX_RVA_GETTEXTFIELDBYNAME_A, TNX_RVA_GETTEXTFIELDBYNAME_B);
    t_addr_settext = tnx_pick(TNX_RVA_SETTEXT_A, TNX_RVA_SETTEXT_B);
    t_addr_setxy = tnx_pick(TNX_RVA_SETXY_A, TNX_RVA_SETXY_B);

    t_addr_battlescreen = t_base + RVA_BATTLESCREEN__BATTLESCREEN;
    if (!tnx_addr_readable(t_addr_battlescreen, sizeof(void *))) t_addr_battlescreen = 0;

    tlog([NSString stringWithFormat:
          @"resolve aim=%d input=%d dodge=%d wm=%d screen=%d",
          (t_addr_getinstance && t_addr_getownchar && t_addr_getx && t_addr_gety && t_addr_getteam) ? 1 : 0,
          t_addr_sendmovement ? 1 : 0,
          t_addr_setprediction ? 1 : 0,
          (t_addr_getclip && t_addr_gettf && t_addr_settext && t_addr_setxy && t_addr_addchild) ? 1 : 0,
          t_addr_battlescreen ? 1 : 0]);
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

    if (count > t_mode_best_objects) t_mode_best_objects = count;

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
        if ((uintptr_t)elementVtable <= t_base) continue;

        uintptr_t elementRva = (uintptr_t)elementVtable - t_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    t_mode_last_types = typeCount;

    if (live < TNX_MODE_MIN_OBJECTS) return 0;
    if (verified < TNX_MODE_MIN_OBJECTS) return 1;

    return (typeCount >= TNX_MODE_MIN_TYPES) ? 2 : 1;
}

BOOL tnx_is_mode_vtable(uintptr_t value, uintptr_t *rvaOut) {
    if (!t_base || !value) return NO;

    for (int i = 0; t_mode_vtables[i]; i++) {
        if (value != (t_base + t_mode_vtables[i])) continue;

        if (rvaOut) *rvaOut = t_mode_vtables[i];

        return YES;
    }

    return NO;
}

void tnx_locate_battle_mode(void) {
    if (t_mode_strong) return;

    if (t_votescan_attempts >= TNX_VOTESCAN_ATTEMPTS) {

        tnx_diag_report("exhausted");

        return;
    }

    double now = CFAbsoluteTimeGetCurrent();

    if (t_votescan_last > 0.0 && (now - t_votescan_last) < TNX_VOTESCAN_INTERVAL) return;

    t_votescan_last = now;
    t_votescan_attempts++;

    if (t_votescan_attempts == 1) {
        tnx_heap_regions_refresh();

    TNX_LOGX("heapwin regions=%d lo=%p hi=%p winSpan=%lluMB capped=%d",
             t_heap_region_count, (void *)t_heap_window_low, (void *)t_heap_window_high,
             (unsigned long long)((t_heap_window_high - t_heap_window_low) / (1024ull * 1024ull)),
             t_heap_region_capped);

    TNX_LOGX("votescan candidates=%d interval=%.1f attempts=%d heapEvery=%d",
                 (int)(sizeof(t_mode_vtables) / sizeof(t_mode_vtables[0]) - 1),
                 (double)TNX_VOTESCAN_INTERVAL, TNX_VOTESCAN_ATTEMPTS, TNX_VOTESCAN_HEAP_EVERY);
    }

    if ((t_votescan_attempts % TNX_VOTESCAN_GLOBAL_EVERY) == 1) {

        tnx_heap_regions_refresh();

    }

    if (t_mode_strong) {
        TNX_LOGX("votescan SUCCESS attempt=%d object=%p global=%p",
                 t_votescan_attempts, (void *)t_scene_object, (void *)t_mode_source);
        tnx_report_mode_hit("found", t_mode_source, t_scene_object);
    } else if ((t_votescan_attempts % TNX_VOTESCAN_HEARTBEAT) == 0) {
        tnx_diag_report("heartbeat");
    }
}

int tnx_trail_beats_slot(int live, int nonEmpty, int32_t count, int slot) {
    if (live != t_trail[slot].live) return live > t_trail[slot].live;
    if (nonEmpty != t_trail[slot].nonEmpty) return nonEmpty > t_trail[slot].nonEmpty;

    return count > t_trail[slot].count;
}

int tnx_trail_ranked(int *out, int max) {
    uint8_t used[TNX_TRAIL_MAX];
    int count = 0;

    memset(used, 0, sizeof(used));

    for (int k = 0; k < max; k++) {
        int best = -1;

        for (int i = 0; i < t_trail_count; i++) {
            if (used[i]) continue;
            if (best < 0) {
                best = i;

                continue;
            }

            if (tnx_trail_beats_slot(t_trail[i].live, t_trail[i].nonEmpty, t_trail[i].count, best)) {
                best = i;
            }
        }

        if (best < 0) break;

        used[best] = 1;
        out[count++] = best;
    }

    return count;
}

uintptr_t t_setpred_2 = 0;

int t_setpred_state = -1;

int t_probe_done_2 = 0;

uintptr_t t_probe_object = 0;

uint64_t t_probe_last_ms = 0;

int t_coord_ok = 0;

int t_coord_usable = 0;

int t_coord_distinct = 0;

int t_team_off = (int)TNX_OBJ_TEAM_OFF;

int t_map_w = 0;

int t_map_h = 0;

int t_map_ok = 0;

uint64_t t_ticks_2 = 0;

uint64_t t_threat_ticks = 0;

uint64_t t_writes_3 = 0;

uint64_t t_last_write_ms = 0;

int t_giveup_logs = 0;

uint64_t t_probe_tick = 0;

tnx_obj_t t_dodge_probe_list[TNX_OBJECT_MAX];

int tnx_verify_setprediction(void) {
    static const uint32_t expected[3] = { 0xb901d401u, 0xb901d802u, 0xd65f03c0u };
    uint32_t words[3] = { 0, 0, 0 };
    uintptr_t address = 0;

    if (!t_base) return 0;

    address = t_base + TNX_RVA_SETPREDICTION;

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

    t_map_ok = 0;
    t_map_w = 0;
    t_map_h = 0;

    if (!mode) return;

    tileMap = (void *)tnx_map_object();
    if (!tileMap) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_MAP_WIDTH_OFF, &width)) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_MAP_HEIGHT_OFF, &height)) return;

    t_map_w = width;
    t_map_h = height;
    t_map_ok = (width >= TNX_MAP_MIN && width <= TNX_MAP_MAX &&
                    height >= TNX_MAP_MIN && height <= TNX_MAP_MAX) ? 1 : 0;
}

int t_gidless = 0;

int t_gidless_logs = 0;

void tnx_gidless_scan(uintptr_t manager) {
    void *data = NULL;
    int32_t count = 0;
    int32_t i = 0;
    int seen = 0;
    int withGid = 0;

    t_gidless = 0;

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
        t_gidless = 1;

        if (t_gidless_logs < 2) {
            t_gidless_logs++;

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

int t_gidoff_logs = 0;

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

    if (t_gidoff_logs < TNX_GIDOFF_LOGS) {
        t_gidoff_logs++;

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

int t_stage = 0;

int t_stuck = 0;

int32_t t_last_x = 0;

int32_t t_last_y = 0;

int t_logs_3 = 0;

int t_dead = 0;

int t_revive_logs = 0;

int t_own_team_3 = -1;

int t_proj_own = 0;

int t_proj_other = 0;

int t_own_team_seen = 0;

int t_filter_logs = 0;

int t_drop_along = 0;

int t_drop_reach = 0;

int t_live_threats = 0;

int t_team_other_seen = 0;

int t_stick_cleared = 0;

uintptr_t t_proj_addr = 0;

uint8_t t_proj_bytes[TNX_DIFF_BYTES];

int t_proj_have = 0;

int t_proj_dumps = 0;

uint64_t t_proj_diff_logs = 0;

uint64_t t_proj_firsts = 0;

void tnx_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team) {
    uint8_t now[TNX_DIFF_BYTES];
    int i;

    if (!elem) return;
    if (!tnx_read_bytes(elem, now, sizeof(now))) return;

    if (elem != t_proj_addr) {
        t_proj_firsts++;
        t_proj_addr = elem;
        memcpy(t_proj_bytes, now, sizeof(now));
        t_proj_have = 1;

        if (t_proj_dumps < TNX_DUMPS) {
            t_proj_dumps++;

            TNX_LOGX("proj FIRST elem=%p classRva=%#llx gid=%d team=%d firsts=%llu - the element "
                     "id changed, so this is either a fresh spawn or the same slot reused; the whole "
                     "first %#x bytes follow one qword per line",
                     (void *)elem, (unsigned long long)classRva, gid, team,
                     (unsigned long long)t_proj_firsts, TNX_DIFF_BYTES);

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

    if (!t_proj_have) {
        memcpy(t_proj_bytes, now, sizeof(now));
        t_proj_have = 1;

        return;
    }

    for (i = 0; i < TNX_DIFF_BYTES; i++) {
        if (t_proj_bytes[i] == now[i]) continue;

        t_proj_diff_logs++;

        if (t_proj_diff_logs <= TNX_DIFF_LOGS) {
            uint64_t oldQ = 0;
            uint64_t newQ = 0;
            int base = i & ~7;

            memcpy(&oldQ, t_proj_bytes + base, 8);
            memcpy(&newQ, now + base, 8);

            TNX_LOGX("proj DIFF +%02x old=%02x new=%02x gid=%d q_old=%#018llx q_new=%#018llx - "
                     "a byte that changes between two ticks while the address stays the same is a "
                     "field of the moving object; a position pair is the first int32/int32 or "
                     "float/float that walks",
                     i, t_proj_bytes[i], now[i], gid, (unsigned long long)oldQ,
                     (unsigned long long)newQ);
        }
    }

    memcpy(t_proj_bytes, now, sizeof(now));
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

    rva = (uintptr_t)vtable - t_base;

    if (vtOut) *vtOut = rva;
    if (rva < TNX_DC_RVA_LO || rva >= TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &chain) || !chain) return 0;
    if (chainOut) *chainOut = (uintptr_t)chain;

    if (!t_players_object) return 0;
    if ((uintptr_t)chain == t_players_object) return 1;

    if (!tnx_read_ptr((uintptr_t)chain + TNX_CLIENT_HOP_OFF, &inner) || !inner) return 0;
    if (innerOut) *innerOut = (uintptr_t)inner;

    if ((uintptr_t)inner == t_players_object) return 1;

    return 0;
}

int t_latch_logs = 0;

int tnx_read_flag(void) {
    uint8_t b = 0;

    if (!t_scene_object) return -1;
    if (!tnx_read_u8((uintptr_t)t_scene_object + TNX_FLAG_OFF, &b)) return -1;

    return (int)b;
}

int t_mode_seen7 = 0;

int t_mode_max = 0;

int t_gate_seen = 0;

uintptr_t t_own_obj = 0;

uintptr_t t_elem = 0;

int32_t t_elem_x0 = 0;

int32_t t_elem_y0 = 0;

int32_t t_own_before_x = 0;

int32_t t_own_before_y = 0;

int t_setter_called = 0;

int t_elem_called = 0;

int t_rb_logs = 0;

int t_own_logs_6 = 0;

int tnx_vt_ok(uintptr_t obj, uintptr_t *vtOut) {
    void *vt = NULL;
    uintptr_t vtRva = 0;

    if (vtOut) *vtOut = 0;
    if (!obj) return 0;
    if (obj & 7) return 0;
    if (!tnx_read_ptr(obj, &vt) || !vt) return 0;
    if ((uintptr_t)vt < t_base) return 0;

    vtRva = (uintptr_t)vt - t_base;

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

void tnx_setter(int32_t vx, int32_t vy) {
    uintptr_t fn = tnx_entry_2(TNX_SETPRED4_RVA);
    uintptr_t own = tnx_own_obj();
    int32_t alive = 0;

    t_setter_called = 0;

    if (!TNX_ACT_SETTER) return;
    if (!fn || !own) return;
    if (!tnx_read_i32(own + TNX_GATE_X_OFF, &t_own_before_x)) return;
    if (!tnx_read_i32(own + TNX_GATE_Y_OFF, &t_own_before_y)) return;
    if (!tnx_read_i32(own + TNX_OWN_ALIVE_OFF, &alive)) return;

    t_own_obj = own;

    ((void (*)(void *, int, int, int))fn)((void *)own, vx, vy, TNX_SETFLAG);

    t_setter_called = 1;

    TNX_LOGX("setter own=%p x=%d y=%d flag=%d in10c was=%d in110 was=%d alive140=%d - this is the "
             "exact call the engine makes for itself at %#llx, where it passes the getOwnCharacter "
             "result and the clamped stick pair; the receiver is read the same way here (%#llx then its "
             "+%#llx) and never guessed, and the pair is never (0,0) because the apply path has to see a "
             "movement and not a release",
             (void *)own, vx, vy, TNX_SETFLAG, t_own_before_x, t_own_before_y, alive,
             (unsigned long long)0x79de14ULL, (unsigned long long)TNX_OWN_OFF,
             (unsigned long long)TNX_OWN_INNER_OFF);
}

void tnx_elem_write(uintptr_t element, int32_t vx, int32_t vy) {
    int32_t was = 0;

    t_elem_called = 0;

    if (!TNX_ACT_ELEM) return;
    if (!element) return;
    if (!tnx_read_i32(element + TNX_OBJ_X_OFF, &t_elem_x0)) return;
    if (!tnx_read_i32(element + TNX_OBJ_Y_OFF, &t_elem_y0)) return;

    t_elem = element;
    was = t_elem_x0;

    if (!tnx_write_bytes(element + TNX_OBJ_X_OFF, &vx, sizeof(vx))) return;
    if (!tnx_write_bytes(element + TNX_OBJ_Y_OFF, &vy, sizeof(vy))) return;

    t_elem_called = 1;

    TNX_LOGX("elemwrite elem=%p x=%d y=%d was=(%d,%d) - the int pair at +%#llx/+%#llx of the walked "
             "element is written directly and read back a whole second later, because the v123 probe read "
             "through four frames and a server that reconciles on a 50 ms cadence would still look "
             "successful there; the difference between a local shadow and an authoritative position is "
             "exactly whether the pair is still ours a second later",
             (void *)element, vx, vy, was, t_elem_y0, (unsigned long long)TNX_OBJ_X_OFF,
             (unsigned long long)TNX_OBJ_Y_OFF);
}

int tnx_mode(void) {
    int32_t mode = -1;

    if (!t_scene_object) return -1;
    if (!tnx_read_i32((uintptr_t)t_scene_object + TNX_MODE_OFF, &mode)) return -1;

    return (int)mode;
}

int tnx_inner(void) {
    void *holder = NULL;
    uint8_t b = 0;

    if (!t_scene_object) return -1;
    if (!tnx_read_ptr((uintptr_t)t_scene_object + TNX_GATE_PTR_OFF, &holder) || !holder) return -1;
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

    if (!t_scene_object) return 0;
    if (!tnx_read_ptr((uintptr_t)t_scene_object + TNX_CLIENT_OFF, &client)) return 0;

    return (uintptr_t)client;
}

uintptr_t t_own_ptr_3 = 0;

int t_own_logs_4 = 0;

int t_own_logs_5 = 0;

void tnx_state_note(int state) {
    if (t_prev_state == 5 && state != 5) {
        t_ok = 0;
        t_tested = 0;
        t_test_state = 0;
        t_moved = 0;
        t_moved2 = 0;
        t_kept = 0;
        t_test_after_x = 0;
        t_test_after_y = 0;
        t_mgr = 0;
        t_mgr_logs = 0;
        t_other_logs = 0;
        t_other_detail = 0;
        t_wide_runs = 0;
        t_own_index = -1;
        t_own_ptr = 0;
        t_own_ptr_2 = 0;
        t_own_index_2 = -1;
        t_own_from_2 = "v103-reset";

        TNX_LOGX("chain reset reason=state-left-5 prev=%d state=%d writes=%llu tested=%d - every "
                 "pointer cached from the finished battle is dropped so the next battle resolves "
                 "scene, manager, own and the containers again from scratch",
                 t_prev_state, state, (unsigned long long)t_writes, t_tested);
    }

    if (state == 5 && t_prev_state != 5) {
        t_attempt++;

        t_start_logged = 0;
        t_dump_done = 0;
        t_coord_logs = 0;
        t_done = 0;
        t_owner = 0;
        t_owner_2 = 0;
        t_wired = 0;
    }

    t_prev_state = state;
}

tnx_proj_t t_projs[TNX_PROJ_MAX];

int t_side_hits = 0;

int t_side_projs = 0;

int t_proj_skipped = 0;

int tnx_proj_scan(uintptr_t manager, int32_t count) {
    void *array = NULL;
    int found = 0;
    int k;
    int32_t i;

    if (!manager || count <= 0) return 0;
    if (count > TNX_COUNT_MAX) count = TNX_COUNT_MAX;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        t_projs[k].classRva = (uintptr_t)-1;
    }

    t_proj_own = 0;
    t_proj_other = 0;

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

        vtRva = (uintptr_t)vtable - t_base;

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
            t_proj_skipped++;

            continue;
        }

        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_X_OFF, &px)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_Y_OFF, &py)) continue;

        for (k = 0; k < TNX_PROJ_MAX; k++) {
            if (t_projs[k].elem != (uintptr_t)element) continue;

            slot = k;

            break;
        }

        if (slot < 0) {
            for (k = 0; k < TNX_PROJ_MAX; k++) {
                if (t_projs[k].classRva != (uintptr_t)-1) continue;

                slot = k;

                break;
            }
        }

        if (slot < 0) continue;

        if (t_projs[slot].elem == (uintptr_t)element) {
            if (px != t_projs[slot].x || py != t_projs[slot].y) {
                t_projs[slot].px = t_projs[slot].x;
                t_projs[slot].py = t_projs[slot].y;
                t_projs[slot].ptick = t_projs[slot].qtick;
                t_projs[slot].hasPrev = 1;
            }
        } else {
            t_projs[slot].elem = (uintptr_t)element;
            t_projs[slot].px = px;
            t_projs[slot].py = py;
            t_projs[slot].spawnX = px;
            t_projs[slot].spawnY = py;
            t_projs[slot].ptick = t_ticks_3;
            t_projs[slot].hasPrev = 0;
        }

        {
            uintptr_t teamOff = (t_team_off == (int)TNX_OBJ_TEAM_OFF) ? TNX_OBJ_TEAM_OFF
                                                                         : TNX_TEAM_OFF;
            int32_t pteam = -1;
            int attributed = 0;

            if (tnx_read_i32((uintptr_t)element + teamOff, &pteam) && pteam >= 0 &&
                pteam <= TNX_OBJ_TEAM_MAX) {
                t_projs[slot].team = pteam;
            } else {
                int side = tnx_own_side_spawn(px, py);

                if (side == 1 && t_own_team_4 >= 0) {
                    t_projs[slot].team = t_own_team_4;
                    t_attrib_hits++;
                    attributed = 1;
                } else {
                    t_projs[slot].team = -1;
                    t_attrib_miss++;
                }
            }

            if (t_projs[slot].team >= 0) {
                if (t_projs[slot].team == t_own_team_3) t_proj_own++;
                else t_proj_other++;
            }

            if (attributed && t_attrib_logs < TNX_ATTRIB_LOGS) {
                t_attrib_logs++;

                TNX_LOGX("own shot by spawn gid=%d side=%d ownTeam=%d spawn=(%d,%d) own=(%d,%d)"
                         " hits=%d miss=%d - the team byte on this element is unreadable, so the "
                         "side comes from the spot the shot started on: a projectile leaves its "
                         "owner's body, so the nearest player to the first position that was seen "
                         "names the side, and an ambiguous or distant spawn stays unknown and stays "
                         "a threat, because calling an enemy shot ours opens a hole, not closes one",
                         gid, t_projs[slot].team, t_own_team_3, px, py, t_own_x,
                         t_own_y, t_attrib_hits, t_attrib_miss);
            }
        }

        t_projs[slot].classRva = vtRva;
        t_projs[slot].x = px;
        t_projs[slot].y = py;
        t_projs[slot].gid = gid;
        t_projs[slot].qtick = t_ticks_3;

        found++;
    }

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        if (t_projs[k].classRva != (uintptr_t)-1) continue;

        t_projs[k].elem = 0;
        t_projs[k].hasPrev = 0;
    }

    if (t_proj_other > 0 && !t_team_other_seen) {
        t_team_other_seen = 1;

        if (t_filter_logs < 6) {
            t_filter_logs++;

            TNX_LOGX("threat filter armed on the first shot of another team: own team %d against %d "
                     "tracked shots that are not ours, and the latch stays closed for the rest of the "
                     "battle - the v173 run never printed this line because the arming test asked for "
                     "both teams inside one scan, and with the filter off the ring spends itself on our "
                     "own bullets, which is the 'it only dodges while I shoot' the user reports",
                     t_own_team_3, t_proj_other);
        }
    }

    if (t_team_other_seen) t_own_team_seen = 1;

    return found;
}

static int t_ctrl_logs = 0;

int t_ctrl_pick = 0;

static int tnx_bounds_try_2(uintptr_t receiver, int32_t *wOut, int32_t *hOut) {
    uintptr_t bounds = 0;
    int32_t w = 0;
    int32_t h = 0;

    if (!receiver) return 0;
    if (!tnx_pointer_plausible(receiver)) return 0;

    {
        void *box = NULL;

        if (!tnx_read_ptr(receiver + (uintptr_t)TNX_BOX_PTR_OFF, &box)) return 0;

        bounds = (uintptr_t)box;
    }

    if (!bounds || (bounds & 7)) return 0;
    if (!tnx_addr_readable(bounds, 0x100)) return 0;
    if (!tnx_read_i32(bounds + TNX_BOUNDS_X_OFF, &w)) return 0;
    if (!tnx_read_i32(bounds + TNX_BOUNDS_Y_OFF, &h)) return 0;
    if (w <= 3 || h <= 3 || w > 200000 || h > 200000) return 0;

    if (wOut) *wOut = w;
    if (hOut) *hOut = h;

    return 1;
}

int tnx_ctrl_bounds_2(uintptr_t base, int32_t *wOut, int32_t *hOut) {
    if (!base) return 0;
    if (!tnx_pointer_plausible(base)) return 0;

    return tnx_bounds_try_2(base, wOut, hOut);
}

uintptr_t tnx_controller(void) {
    uintptr_t client = tnx_client();
    int32_t cw = 0;
    int32_t ch = 0;

    if (client && tnx_ctrl_bounds_2(client, &cw, &ch)) {
        t_ctrl_pick = 1;

        return client;
    }

    t_ctrl_pick = 0;

    if (!t_ctrl_logs) {
        t_ctrl_logs = 1;

        TNX_LOGX("controller client=%p resolved=0 bounds=(%d,%d) - the logic client is [scene+0x28], "
                 "the object the engine reaches through a hop of its own update screen before "
                 "setClientPredictionMoveTo, and it is the same object the map accessor resolves on "
                 "and the same one the element container walks, so a miss here means the scene "
                 "pointer is stale rather than that the object is wrong",
                 (void *)client, cw, ch);
    }

    return client;
}

void tnx_watch(int32_t ownX, int32_t ownY) {
    if (ownX == t_last_x && ownY == t_last_y) {
        t_stuck++;

        return;
    }

    t_stuck = 0;
    t_last_x = ownX;
    t_last_y = ownY;
}

int t_tnx_verbose = TNX_VERBOSE_DEFAULT;

int t_signal_logs = 0;

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

    if (t_signal_logs >= 12) return;

    t_signal_logs++;

    TNX_LOGX("death signals own=%p (%d,%d) deadByte@+%#llx=%d own+0x140=%d ctrl+0xf80=%d - the "
             "guard used the walk's dead byte at +%#llx and held the dodge while the player was "
             "alive, because that byte reads %d on a live object; whichever of these three moves on a "
             "real death is the one to guard on", (void *)ownElem, ownX, ownY,
             (unsigned long long)TNX_DEAD_OFF, dead, ownAlive, ctrlAlive,
             (unsigned long long)TNX_DEAD_OFF, dead);
}

void tnx_alive(int32_t ownX, int32_t ownY) {
    if (!t_dead) return;

    t_dead = 0;
    t_stick_cleared = 0;

    if (t_revive_logs < 4) {
        t_revive_logs++;

        TNX_LOGX("own is alive again at (%d,%d): the dodge resumes from stage %d with a cleared "
                 "heading and a cleared write clock, which is what the last life's state would "
                 "otherwise keep frozen", ownX, ownY, t_stage);
    }
}

int t_map_dumps = 0;

int32_t t_prev_x_3 = 0;

int32_t t_prev_y_3 = 0;

int t_prev_ok = 0;

uint64_t t_measured = 0;

float tnx_step(void) {

    return TNX_STEP_3;
}

void tnx_measure(void) {
    int32_t x = 0;
    int32_t y = 0;
    float d = 0.0f;

    if (!tnx_own(&x, &y)) return;

    if (t_prev_ok && !t_hold) {
        float ddx = (float)(x - t_prev_x_3);
        float ddy = (float)(y - t_prev_y_3);

        d = sqrtf(ddx * ddx + ddy * ddy);

        if (d > 0.5f) {
            float inv = 1.0f / d;

            t_last_x_3 = ddx * inv;
            t_last_y_3 = ddy * inv;
            t_last_ok = 1;
            t_hseed++;
        }

        if (d > 0.5f && d < TNX_WALK_MAX * 3.0f) {
            t_walk_step = t_walk_step * (1.0f - TNX_WALK_EMA) + d * TNX_WALK_EMA;
            t_measured++;

            if (t_walk_step < TNX_WALK_MIN) t_walk_step = TNX_WALK_MIN;
            if (t_walk_step > TNX_WALK_MAX) t_walk_step = TNX_WALK_MAX;
        }
    }

    t_prev_x_3 = x;
    t_prev_y_3 = y;
    t_prev_ok = 1;
}

const char *const t_names[TNX_BASES] = { "scene", "mgr", "ctrl", "char", "enemy" };

int t_owner_logs = 0;

uint64_t t_dropped_2 = 0;

int tnx_proj_mine(const tnx_proj_t *p) {
    int i = 0;
    int bestMine = 0;
    float best = 1.0e18f;
    float sx = 0.0f;
    float sy = 0.0f;

    if (!TNX_PROJ_OWNER) return 0;
    if (!t_team_trust) return 0;
    if (t_pl_n <= 0) return 0;
    if (t_own_team_4 >= 0 && p->team == t_own_team_4) return 1;
    if (!p->spawnX && !p->spawnY) return 0;

    sx = (float)p->spawnX;
    sy = (float)p->spawnY;

    for (i = 0; i < t_pl_n; i++) {
        float dx = sx - (float)t_pl_x[i];
        float dy = sy - (float)t_pl_y[i];
        float d = dx * dx + dy * dy;

        if (d < best) {
            best = d;
            bestMine = t_pl_mine[i];
        }
    }

    if (best > TNX_SPAWN_R * TNX_SPAWN_R) return 0;

    if (bestMine) {
        t_dropped_2++;

        if (t_owner_logs < TNX_OWNER_LOGS) {
            t_owner_logs++;

            TNX_LOGX("owner gid-less team=%d spawn=(%d,%d) nearest=%.0f mine=1 dropped=%llu - "
                     "the shot starts on an own-side body, so it belongs to own side whatever its "
                     "team byte says and it is not a threat",
                     p->team, p->spawnX, p->spawnY, (double)sqrtf(best),
                     (unsigned long long)t_dropped_2);
        }
    }

    return bestMine;
}

void tnx_state(void) {
    t_census_container = 0;
    t_census_array = 0;
    t_census_first = 0;
    t_census_ms = 0;

    t_mgr = (uintptr_t)tnx_manager();

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
             (void *)t_joystick, (unsigned long long)t_joystick_writes,
             (unsigned long long)t_joystick_took, (unsigned long long)t_escapes,
             (unsigned long long)t_lookahead, (unsigned long long)t_applied_writes,
             (unsigned long long)t_applied_live, (unsigned long long)t_applied_stale,
             (unsigned long long)t_rage_frames, (unsigned long long)t_flees,
             (unsigned long long)t_dead_replaced, (unsigned long long)t_clamped,
             (unsigned long long)t_drain,
             (unsigned long long)t_q_max, (unsigned long long)t_q_before_2,
             (unsigned long long)t_stuck_3, (unsigned long long)t_mask_before, (unsigned long long)t_drag_writes,
             (unsigned long long)t_drag_back, (unsigned long long)t_mate_turns,
             (unsigned long long)t_mate_stuck, (unsigned long long)t_keeps,
             (unsigned long long)t_engage, (unsigned long long)t_hseed, (unsigned long long)t_evals, (unsigned long long)t_pos_skips, (unsigned long long)t_reentry,
             (unsigned long long)t_render_skip, (unsigned long long)t_update_skip,
             (void *)t_slot_orig[32], (void *)t_slot_orig[33], (unsigned long long)t_update_hits,
             (unsigned long long)t_move_hits, (unsigned long long)t_ticks,
             (unsigned long long)tnx_upd_delta(), (unsigned long long)tnx_rend_delta(),
             (int)tnx_gate(), (unsigned long long)t_dec_us,
             (unsigned long long)t_dec_us_max, (unsigned long long)t_slow,
             (unsigned long long)t_diag_max_us, (unsigned long long)t_gate_writes_2,
             (unsigned long long)t_gate_held, (unsigned long long)t_drop_slow,
             (unsigned long long)t_drop_fast, (unsigned long long)t_drop_blink,
             (double)t_spd_min, (double)t_spd_max,
             (unsigned long long)t_ctrl_dead, (unsigned long long)t_write_denied,
             (unsigned long long)t_pred_took, (unsigned long long)t_pred_miss,
             (void *)(uintptr_t)t_scene_object, (void *)t_own_elem_2, (void *)t_pred_last,
             (int)TNX_STEP_4, (int)TNX_TYPE_MOVE, (int)TNX_SLOW_US,
             (unsigned long long)TNX_GATE_OFF, (double)t_walk_step);

    {
        uint16_t charState = 0;
        uint16_t sceneState = 0;
        int32_t charMode = 0;

        if (t_own_elem_2) {
            tnx_read_bytes(t_own_elem_2 + TNX_JOYSTATE_OFF, &charState, sizeof(charState));
            tnx_read_i32(t_own_elem_2 + TNX_BS_MODE, &charMode);
        }

        if (t_scene_object) {
            tnx_read_bytes((uintptr_t)t_scene_object + TNX_JOYSTATE_OFF, &sceneState,
                           sizeof(sceneState));
        }

        uint8_t gate70 = 0;

        if (t_pred_last) {
            tnx_read_bytes(t_pred_last + TNX_GATE_OFF, &gate70, sizeof(gate70));
        }

        uint16_t enState[2] = { 0, 0 };
        int32_t enMode[2] = { 0, 0 };
        int seen = 0;
        int k = 0;

        for (k = 0; k < t_dodge_probe_usable && seen < 2; k++) {
            const tnx_obj_t *o = &t_dodge_probe_list[k];
            uint16_t st = 0;
            int32_t md = 0;

            if (!o->object) continue;
            if (o->gid < TNX_PLAYER_GID) continue;
            if (o->gid >= TNX_SHOT_GID) continue;
            if (t_own_elem_2 && o->object == t_own_elem_2) continue;
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
                 (void *)t_own_elem_2, (unsigned)charState, charMode,
                 (void *)(uintptr_t)t_scene_object, (unsigned)sceneState,
                 (void *)(uintptr_t)t_joystick, (int)gate70,
                 (unsigned)enState[0], enMode[0], (unsigned)enState[1], enMode[1], seen,
                 (unsigned long long)TNX_JOYSTATE_OFF);
    }

    {
        uintptr_t st = 0;

        if (tnx_read_ptr(tnx_client() + TNX_MGR_OFF, (void **)&st) && st) {
            int32_t stx = 0;
            int32_t sty = 0;
            int32_t stk = 0;
            int32_t sta = 0;
            uintptr_t stv = 0;

            tnx_read_i32(st + TNX_MOVE_X_OFF, &stx);
            tnx_read_i32(st + TNX_MOVE_Y_OFF, &sty);
            tnx_read_i32(st + TNX_MOVE_KEY_OFF, &stk);
            tnx_read_i32(st + TNX_MOVE_ARM_OFF, &sta);
            if (tnx_read_ptr(st, (void **)&stv) && stv >= t_base) stv -= t_base;

            TNX_LOGX("inputstate obj=%p vtRva=%#llx x+%#llx=%d y+%#llx=%d key+%#llx=%d arm+%#llx=%d "
                     "prev=(%d,%d) moved=%d qLast=%p - the pair the engine holds for the input read from [scene+%#llx], "
                     "and it is the same pair the engine setter writes, so while the player walks it has to track the "
                     "walk and then writing there steers the body instead of corrupting a pointer",
                     (void *)st, (unsigned long long)stv,
                     (unsigned long long)TNX_MOVE_X_OFF, stx, (unsigned long long)TNX_MOVE_Y_OFF, sty,
                     (unsigned long long)TNX_MOVE_KEY_OFF, stk, (unsigned long long)TNX_MOVE_ARM_OFF, sta,
                     t_state_prev_x, t_state_prev_y,
                     (stx != t_state_prev_x || sty != t_state_prev_y) ? 1 : 0,
                     tnx_q_last(),
                     (unsigned long long)TNX_MGR_OFF);

            t_state_prev_x = stx;
            t_state_prev_y = sty;
        }
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

int32_t t_gid_lo = 0;

int32_t t_gid_hi = 0;

const uintptr_t t_mode_vtables[36] = {
    0x10012c8, 0x1001318, 0x1001368, 0x10013b8,
    0x1001408, 0x1001458, 0x10014a8, 0x10014f8, 0x1001548, 0x1001598, 0x10015e8, 0x10016e0,
    0x10017d8, 0x10018c0, 0x1001908, 0x10019d0, 0x1001ac8, 0x1001bc0, 0x1001cb8, 0x1001d80,
    0x1001e48, 0x1001f10, 0x10022f0, 0x10023b8, 0x1002480, 0x1002548, 0x1002610,
    0x10026d8, 0x10027a0, 0x1002868, 0x1002930, 0x10029f8, 0x1002ac0, 0x1002b88, 0x1002d18,
    0,
};

tnx_trail_t t_trail[TNX_TRAIL_MAX];

void tnx_probe_3(uintptr_t manager, uintptr_t mode, int verbose) {
    tnx_obj_t objects[TNX_OBJECT_MAX];
    int rejected = 0;
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int teamsNew[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int distinctOld = 0;
    int distinctNew = 0;

    memset(objects, 0, sizeof(objects));

    t_probe_done_2 = 1;

    if (mode) tnx_read_map(mode);

    {
        static int v142_walk_logs = 0;

        if (v142_walk_logs < 12 || (v142_walk_logs % 128) == 0) {
            v142_walk_logs++;

            tnx_logf("walk enter arr=%p n=%d g_arr=%p g_n=%d tick_arr=%p tick_n=%d manager=%p", (void *)t_tick_array,
                     t_tick_count, (void *)t_players_array, t_players_count,
                     (void *)t_tick_array, t_tick_count, (void *)manager);
        }
    }

    usable = tnx_collect(manager, objects, TNX_OBJECT_MAX, &rejected);

    {
        static int v142_leave_logs = 0;

        if (v142_leave_logs < 12 || (v142_leave_logs % 128) == 0) {
            v142_leave_logs++;

            tnx_logf("walk leave arr=%p n=%d g_arr=%p g_n=%d aborted=%d abortI=%d usable=%d rejected=%d", (void *)t_walk_arr, t_walk_n,
                     (void *)t_pub_array, t_pub_count, t_walk_aborted,
                     t_walk_abort_i, usable, rejected);
        }
    }

    for (int i = 0; i < usable; i++) {
        if (objects[i].x > -TNX_COORD_ABS_MAX && objects[i].x < TNX_COORD_ABS_MAX &&
            objects[i].y > -TNX_COORD_ABS_MAX && objects[i].y < TNX_COORD_ABS_MAX) {
            inRange++;
        }

        if (objects[i].teamOld >= 0 && objects[i].teamOld < 8) teamsOld[objects[i].teamOld] = 1;
        if (objects[i].teamNew >= 0 && objects[i].teamNew < 8) teamsNew[objects[i].teamNew] = 1;

        {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].x == objects[i].x && objects[j].y == objects[i].y) { seen = 1; break; }
            }

            if (!seen) distinct++;
        }
    }

    for (int i = 0; i < 8; i++) {
        if (teamsOld[i]) distinctOld++;
        if (teamsNew[i]) distinctNew++;
    }

    t_team_off = (int)TNX_OBJ_TEAM_OFF;

    {
        char reasons[320];

        tnx_logf("man walk mode=%p manager=%p usable=%d rejected=%d (%s) mapOk=%d mapW=%d "
                 "mapH=%d inRange=%d distinct=%d teamsOld=%d teamsNew=%d teamOff=0x%x",
                 (void *)mode, (void *)manager, usable, rejected,
                 tnx_reject_text(reasons, sizeof(reasons)), t_map_ok, t_map_w,
                 t_map_h, inRange, distinct, distinctOld, distinctNew, t_team_off);
    }

    tnx_logf("walk team reverted to +0x%x with distinct(+0x40)=%d distinct(+0x4c)=%d",
             t_team_off, distinctOld, distinctNew);

    tnx_logf("walk offsets team=+0x%x distinctOld=%d distinctNew=%d coord=+0x%llx/+0x%llx usable=%d distinct=%d inRange=%d",
             t_team_off, distinctOld, distinctNew,
             (unsigned long long)tnx_coord_x_off(), (unsigned long long)tnx_coord_y_off(),
             usable, distinct, inRange);

    if (!TNX_DEAD_ONCE || !t_dead_probe_done) {
        t_dead_probe_done = 1;
    }

    if (verbose) {
        tnx_logf("offsets obj off=0x%llx/0x%llx x=0x%llx y=0x%llx teamOld=0x%llx teamNew=0x%llx "
                 "owner=0x%llx dead=0x%llx active=0x%llx tilemap=0x%llx w=0x%llx",
                 TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF, TNX_OBJ_X_OFF, TNX_OBJ_Y_OFF,
                 TNX_OBJ_TEAM_OFF, TNX_OBJ_TEAMENGINE_OFF, TNX_OBJ_OWNERINDEX_OFF,
                 TNX_OBJ_DEADFLAG_OFF, TNX_OBJ_ACTIVEFLAG_OFF,
                 TNX_MODE_TILEMAP_OFF, TNX_TILEMAP_WIDTH_OFF);

        for (int i = 0; i < usable && i < 16; i++) {
            tnx_logf("player[%02d] at=%p gid=%d pos=(%d,%d) team40=%d own=%d dead=%d active=%d",
                     i, (void *)objects[i].object, objects[i].gid, objects[i].x, objects[i].y,
                     objects[i].teamOld, objects[i].ownerIndex, objects[i].dead,
                     objects[i].activeFlag & 1, (unsigned long long)TNX_OBJ_X_OFF,
                     (unsigned long long)TNX_OBJ_Y_OFF, (unsigned long long)TNX_OBJ_TEAM_OFF);
        }
    }

    t_coord_usable = usable;
    t_coord_distinct = distinct;

    {
        int unique = 0;

        for (int i = 0; i < usable; i++) {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].gid == objects[i].gid) {
                    seen = 1;
                    break;
                }
            }

            if (!seen) unique++;
        }

        tnx_logf("gid unique=%d of usable=%d distinct=%d",
                 unique, usable, distinct);
    }

    tnx_team_dump(objects, usable);
    tnx_class_dump(objects, usable);

    t_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;

    tnx_logf("coords ok=%d (need >=2 objects, all in range, >=2 distinct positions, "
             "and a team field that splits them)",
             t_coord_ok);

    {
        int back = 0;
        int backRead = 0;

        for (int i = 0; i < usable; i++) {
            void *backPtr = NULL;

            if (!tnx_read_ptr(objects[i].object + TNX_ELEM_BACK_OFF, &backPtr)) continue;

            backRead++;

            if ((uintptr_t)backPtr == manager) back++;
        }

        tnx_logf("membership manager=%p usable=%d back=%d read=%d",
                 (void *)manager, usable, back, backRead,
                 (unsigned long long)TNX_ELEM_BACK_OFF,
                 (unsigned long long)TNX_MODE_MANAGER_OFF);
    }
}

void tnx_paircal(void) {
    uintptr_t ctrl = tnx_pair_base();
    int32_t ownX = 0;
    int32_t ownY = 0;
    int32_t px = 0;
    int32_t py = 0;
    int dx = 0;
    int dy = 0;
    float pLen = 0.0f;
    float mLen = 0.0f;
    float dot = 0.0f;
    float angPair = 0.0f;
    float angMove = 0.0f;

    if ((t_ticks_3 % 60) != 0) return;
    if (t_logs_5 >= TNX_LOGS_3) return;
    if (t_stick_hold) return;
    if (!ctrl) return;
    if (!tnx_own(&ownX, &ownY)) return;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_X_OFF, &px)) return;
    if (!tnx_read_i32(ctrl + TNX_CTRL_RAW_Y_OFF, &py)) return;

    if (t_seeded) {
        dx = (int)(ownX - t_last_x_2);
        dy = (int)(ownY - t_last_y_2);
    }

    t_seeded = 1;
    t_last_x_2 = ownX;
    t_last_y_2 = ownY;

    pLen = sqrtf((float)(px * px + py * py));
    mLen = sqrtf((float)(dx * dx + dy * dy));

    if (pLen < 1.0f || mLen < 1.0f) return;

    t_logs_5++;

    dot = ((float)px / pLen) * ((float)dx / mLen) + ((float)py / pLen) * ((float)dy / mLen);
    angPair = atan2f((float)py, (float)px) * 57.2958f;
    angMove = atan2f((float)dy, (float)dx) * 57.2958f;

    tnx_logf("paircal pair=(%d,%d) len=%.0f move=(%d,%d) len=%.0f dot=%+.2f angPair=%.1f angMove=%.1f angDelta=%.1f own=(%d,%d)",
             px, py, (double)pLen, dx, dy, (double)mLen, (double)dot, (double)angPair, (double)angMove,
             (double)(angMove - angPair), ownX, ownY,
             (unsigned long long)TNX_CTRL_RAW_X_OFF);
}
