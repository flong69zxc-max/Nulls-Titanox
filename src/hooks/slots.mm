#include "titanox.h"

int t_own_team = 0;

int t_own_idhit = 0;

uintptr_t t_setpred = 0;

int t_wide_runs = 0;

int t_miss_logs = 0;

int t_live_objs = 0;

int t_live_teams = 0;

int t_fb_on = 0;

int t_fb_logged = 0;

int t_bar_logged = 0;

unsigned t_vt_text_rejects = 0;

unsigned long long t_obj_prev = 0;

uintptr_t t_site = 0;

int t_state_2 = -1;

int t_scan_armed = -1;

volatile uint32_t t_seq = 0;

uintptr_t t_pub_object = 0;

uintptr_t t_pub_array = 0;

int32_t t_pub_count = 0;

int32_t t_pub_cap = 0;

int t_pub_logs = 0;

uintptr_t t_tick_object = 0;

uintptr_t t_tick_array = 0;

int32_t t_tick_count = 0;

uint64_t t_tick_logs = 0;

int t_score_logs_2 = 0;

uint64_t t_walk_aborts = 0;

void tnx_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap,
                             const char *why) {
    __sync_synchronize();

    t_seq++;

    __sync_synchronize();

    t_pub_object = object;
    t_pub_array = array;
    t_pub_count = count;
    t_pub_cap = cap;

    t_players_object = object;
    t_players_array = array;
    t_players_count = count;
    t_players_cap = cap;

    __sync_synchronize();

    t_seq++;

    __sync_synchronize();

    if (t_pub_logs < 12) {
        t_pub_logs++;

        tnx_logf("publish why=%s object=%p array=%p count=%d cap=%d seq=%u - the whole triple "
                 "moves under one sequence, so no reader can take the new array with the old "
                 "count", why ? why : "?", (void *)object, (void *)array, count, cap,
                 (unsigned)t_seq);
    }
}

int tnx_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut) {
    int tries;

    for (tries = 0; tries < 8; tries++) {
        uint32_t s1 = t_seq;
        uintptr_t o;
        uintptr_t a;
        int32_t c;

        if (s1 & 1u) continue;

        o = t_pub_object;
        a = t_pub_array;
        c = t_pub_count;

        __sync_synchronize();

        if (t_seq != s1) continue;

        if (objectOut) *objectOut = o;
        if (arrayOut) *arrayOut = a;
        if (countOut) *countOut = c;

        return 1;
    }

    return 0;
}

void tnx_tick_begin(const char *phase) {
    uintptr_t o = 0;
    uintptr_t a = 0;
    int32_t c = 0;

    if (!tnx_snapshot(&o, &a, &c)) return;

    t_tick_object = o;
    t_tick_array = a;
    t_tick_count = c;
    t_tick_stamp++;

    if (t_tick_logs < 12) {
        t_tick_logs++;

        tnx_logf("tick enter phase=%s object=%p array=%p count=%d stamp=%llu - the snapshot is "
                 "taken before any stage reads it and is what the walk, the census and the "
                 "resolver all use, so a publish from the scan timer cannot split them",
                 phase ? phase : "?", (void *)o, (void *)a, c,
                 (unsigned long long)t_tick_stamp);
    }
}

uint64_t t_idle_start = 0;

int t_idle_on = 0;

int t_idle_logged = 0;

int t_idle_skips = 0;

void tnx_slot_install_one(int index) {
    uintptr_t target = 0;
    int slots = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    t_slot_installed[index] = 0;
    t_slot_slots[index] = 0;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    if (!t_slot_specs[index].rva && !t_slot_specs[index].slotRva) return;

    target = t_base + t_slot_specs[index].rva;

    if (!target) return;

    slots = hook_probe(target);

    if (slots > TNX_MAX_SLOTS) {
        tnx_logf("slot %s: reject-bulk target=%p slots=%d - that many identical copies means the address is "
                 "a shared constant duplicated across class tables and not a vtable entry, so redirecting "
                 "it would send every original caller into a stub with the wrong arguments",
                 t_slot_specs[index].tag, (void *)target, slots);

        return;
    }

    {
        uint32_t w = 0;
        int prologue = 0;

        if (tnx_read_u32(target, &w)) {
            if ((w & 0xFFC003FFu) == 0xD10003FFu) prologue = 1;
            if ((w & 0xFF4003E0u) == 0xA90003E0u) prologue = 1;
            if ((w & 0xFF4003E0u) == 0xA80003E0u) prologue = 1;
            if (w == 0xD503237Fu) prologue = 1;
            if (w == 0xD503245Fu) prologue = 1;
            if (w == 0xD65F03C0u) prologue = 1;
            if (w == 0x910003FDu) prologue = 1;
            if ((w & 0xFF000000u) == 0x14000000u) prologue = 1;
            if ((w & 0x9F000000u) == 0x10000000u) prologue = 1;
        }

        if (!prologue) {
            tnx_logf("slot %s: reject-nonfunc target=%p firstWord=%#x - the first instruction is not a "
                     "prologue, a leaf return, a branch or an adrp, so this is not a function entry and a "
                     "stub placed here would be entered with the caller's scratch registers intact",
                     t_slot_specs[index].tag, (void *)target, (unsigned)w);

            return;
        }
    }

    if (slots <= 0) {
        tnx_logf("slot %s: not-found target=%p slots=0 in __DATA_CONST/__DATA - runtime inline "
                 "patching is not supported, so this target needs a data slot (%s)",
                 t_slot_specs[index].tag, (void *)target,
                 hook_last_error() ? hook_last_error() : "-");

        return;
    }

    if (!brk_install((void *)target, (void *)t_slot_specs[index].replacement)) {
        tnx_logf("slot %s: install failed target=%p (%s)", t_slot_specs[index].tag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    t_slot_orig[index] = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    t_slot_installed[index] = 1;
    t_slot_slots[index] = slots;

    tnx_logf("slot %s: installed target=%p original=%p mode=pointer slots=%d liveSlots=%d",
             t_slot_specs[index].tag, (void *)target, (void *)t_slot_orig[index], slots,
             brk_live_slot_count());
}

void tnx_slot_hooks_install(void) {
    const char *flag = NULL;

    if (!t_base) return;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    flag = getenv("TITANOX_ALLOW_CODE_PATCH");

    tnx_logf("slot hooks: codePatch=%d flag=%s pointerSlots=%d limit=%d live=%d",
             hook_code_patch_allowed() ? 1 : 0, flag ? flag : "-",
             hook_pointer_count(), brk_slot_limit(), brk_live_slot_count());

    for (int i = 0; i < TNX_SLOT_COUNT; i++) tnx_slot_install_one(i);

    tnx_slot_diag("install");
}

int t_ascii_logs = 0;

const int tnx_object_slots[TNX_OBJ_SLOTS] = { 2, 3, 4 };

int t_walk_aborted = 0;

int t_walk_abort_i = -1;

uintptr_t t_walk_arr = 0;

int32_t t_walk_n = 0;

int t_pub_logs_2 = 0;

int t_stale_logs = 0;

int t_actuate_logs = 0;

uintptr_t t_own_slot = 0;

int32_t t_own_slot_gid = 0;

int t_own_slot_ok = 0;

int t_own_slot_logs = 0;

int32_t t_src30_prev_x = 0;

int32_t t_src30_prev_y = 0;

int32_t t_src38_prev_x = 0;

int32_t t_src38_prev_y = 0;

int t_src30_have = 0;

int t_src38_have = 0;

uint64_t t_src30_moves = 0;

uint64_t t_src38_moves = 0;

int t_w_eq_x = 0;

int t_w_eq_y = 0;

void tnx_slot_pump(void) {
    int first = -1;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        uint32_t bit = (uint32_t)(1u << i);

        if (!t_slot_object[i]) continue;

        if (!t_slot_specs[i].control && first < 0) first = i;

        if (t_slot_reported_mask & bit) continue;

        t_slot_reported_mask |= bit;

        tnx_logf("slot %s: captured this=%p arg1=%p hits=%llu%s", t_slot_specs[i].tag,
                 (void *)t_slot_object[i], (void *)t_slot_arg1[i],
                 (unsigned long long)t_slot_hits[i],
                 t_slot_specs[i].control ? " CONTROL" : "");
    }

    if (first < 0) return;

    uintptr_t object = t_slot_object[first];

    if (t_slot_adopted == object) return;

    t_slot_adopted = object;

    int installed = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (t_slot_installed[i] == 1) installed++;
    }

    tnx_logf("slot pump object=%p source=%s installed=%d/%d",
             (void *)object, t_slot_specs[first].tag, installed, TNX_SLOT_COUNT);

    {
        void *vtable = NULL;
        void *manager = NULL;
        const char *reason = "vtable-not-in-image";

        if (tnx_read_ptr(object, &vtable) && vtable &&
            tnx_vtable_in_image((uintptr_t)vtable)) {
            reason = (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &manager) && manager)
                         ? "adopt-from-slot-banned"
                         : "no-manager-at-0x28";
        } else if (!tnx_pointer_plausible((uintptr_t)vtable)) {
            reason = "vtable-garbage";
        }

        tnx_logf("slot %s reject reason=%s this=%p vt=%p", t_slot_specs[first].shortTag, reason,
                 (void *)object, vtable);

        if (strcmp(reason, "vtable-garbage") == 0) return;
    }

    void *bridge = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_BRIDGE_OFF, &bridge) && bridge) {
        void *bridgeManager = NULL;

        tnx_logf("slot +08 bridge=%p vt=%#llx", bridge,
                 (unsigned long long)tnx_vtable_rva(bridge));

        if (tnx_read_ptr((uintptr_t)bridge + TNX_MGR_ARRAY_OFF, &bridgeManager) && bridgeManager) {
            tnx_logf("slot bridgeMgr=%p vt=%#llx", bridgeManager,
                     (unsigned long long)tnx_vtable_rva(bridgeManager));

        }
    }

    void *list = NULL;
    int32_t listCount = 0;

    if (tnx_read_ptr(object + TNX_SLOT_LIST_OFF, &list) &&
        tnx_read_i32(object + TNX_SLOT_LISTCOUNT_OFF, &listCount)) {
        tnx_logf("slot +80 list=%p count=%d", list, listCount);
    }

    void *modeManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &modeManager) && modeManager) {
        void *modeArray = NULL;
        int32_t modeCount = 0;

        tnx_logf("slot +28 mgr=%p vt=%#llx", modeManager,
                 (unsigned long long)tnx_vtable_rva(modeManager));

        if (tnx_read_ptr((uintptr_t)modeManager + TNX_MGR_ARRAY_OFF, &modeArray) &&
            tnx_read_i32((uintptr_t)modeManager + TNX_MGR_COUNT_OFF, &modeCount)) {
            tnx_logf("slot +28 arr=%p count=%d live=%d", modeArray, modeCount,
                     tnx_manager_live_count((uintptr_t)modeManager));
        }

    }

    void *inputManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_INPUTMGR_OFF, &inputManager) && inputManager) {
        tnx_logf("slot +58 inputMgr=%p vt=%#llx", inputManager,
                 (unsigned long long)tnx_vtable_rva(inputManager));

    }

    if (t_slot_arg1[first]) {
        tnx_report_manager("slot arg1", t_slot_arg1[first]);
    }

    void *ownerField = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_OWNER_OFF, &ownerField) && ownerField &&
        (uintptr_t)ownerField != t_slot_arg1[first]) {
        tnx_report_manager("slot +20", (uintptr_t)ownerField);
    }

    {
        uintptr_t plan = t_slot_arg1[first] ? t_slot_arg1[first] : (uintptr_t)ownerField;

        if (plan && tnx_manager_live_count(plan) >= TNX_MANAGER_MIN_OBJECTS) {
            int detailed = tnx_object_detail(plan, TNX_OBJECT_DETAIL_MAX);

            if (detailed > 0) tnx_dodge_all_teams(plan);
        }
    }

    void *slotTable = NULL;

    if (tnx_read_ptr(object, &slotTable) && slotTable) {
        tnx_logf("slot vtable=%p", slotTable);

        for (int k = 0; k < 40; k += 4) {
            void *entry[4] = { NULL, NULL, NULL, NULL };

            for (int j = 0; j < 4; j++) {
                tnx_read_ptr((uintptr_t)slotTable + (uintptr_t)(k + j) * sizeof(void *), &entry[j]);
            }

            tnx_logf("slot vt[%02d..%02d] %#llx %#llx %#llx %#llx", k, k + 3,
                     (unsigned long long)(uintptr_t)entry[0],
                     (unsigned long long)(uintptr_t)entry[1],
                     (unsigned long long)(uintptr_t)entry[2],
                     (unsigned long long)(uintptr_t)entry[3]);
        }
    }

}
tnx_slot_fn_t t_slot_orig[TNX_SLOT_COUNT] = { NULL };

int t_slot_installed[TNX_SLOT_COUNT] = { -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1 };

uint64_t tnx_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(0, a0, a1);

    if (t_slot_orig[0]) return t_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(1, a0, a1);

    if (t_slot_orig[1]) return t_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(2, a0, a1);

    if (t_slot_orig[2]) return t_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(3, a0, a1);

    if (t_slot_orig[3]) return t_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(4, a0, a1);

    if (t_slot_orig[4]) return t_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(5, a0, a1);

    if (t_slot_orig[5]) return t_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(6, a0, a1);

    if (t_slot_orig[6]) return t_slot_orig[6](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(7, a0, a1);

    if (t_slot_orig[7]) return t_slot_orig[7](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(8, a0, a1);

    if (t_slot_orig[8]) return t_slot_orig[8](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(9, a0, a1);

    if (t_slot_orig[9]) return t_slot_orig[9](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(10, a0, a1);

    if (t_slot_orig[10]) return t_slot_orig[10](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(11, a0, a1);

    if (t_slot_orig[11]) return t_slot_orig[11](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(12, a0, a1);

    if (t_slot_orig[12]) return t_slot_orig[12](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(13, a0, a1);

    if (t_slot_orig[13]) return t_slot_orig[13](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(14, a0, a1);

    if (t_slot_orig[14]) return t_slot_orig[14](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(15, a0, a1);

    if (t_slot_orig[15]) return t_slot_orig[15](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(16, a0, a1);

    if (t_slot_orig[16]) return t_slot_orig[16](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(17, a0, a1);

    if (t_slot_orig[17]) return t_slot_orig[17](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(18, a0, a1);

    if (t_slot_orig[18]) return t_slot_orig[18](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(19, a0, a1);

    if (t_slot_orig[19]) return t_slot_orig[19](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(20, a0, a1);

    if (t_slot_orig[20]) return t_slot_orig[20](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(21, a0, a1);

    if (t_slot_orig[21]) return t_slot_orig[21](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(22, a0, a1);

    if (t_slot_orig[22]) return t_slot_orig[22](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(23, a0, a1);

    if (t_slot_orig[23]) return t_slot_orig[23](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(24, a0, a1);

    if (t_slot_orig[24]) return t_slot_orig[24](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(25, a0, a1);

    if (t_slot_orig[25]) return t_slot_orig[25](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(26, a0, a1);

    if (t_slot_orig[26]) return t_slot_orig[26](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(27, a0, a1);

    if (t_slot_orig[27]) return t_slot_orig[27](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(28, a0, a1);

    if (t_slot_orig[28]) return t_slot_orig[28](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(29, a0, a1);

    if (t_slot_orig[29]) return t_slot_orig[29](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(30, a0, a1);

    if (t_slot_orig[30]) return t_slot_orig[30](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(31, a0, a1);

    if (t_slot_orig[31]) return t_slot_orig[31](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_32(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;

    t_update_hits++;

    if (t_slot_orig[32]) r = t_slot_orig[32](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

uint64_t tnx_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;

    t_move_hits++;

    if (t_slot_orig[33]) r = t_slot_orig[33](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

const struct tnx_t_g_slot_specs t_slot_specs[TNX_SLOT_COUNT] = {

    { "A1/vt1002548+10/ad4ed0", "A1", 0x00ad4ed0ULL, 0x01002598ULL, tnx_slot_repl_0, 0 },
    { "A2/vt1002548+07/ad521c", "A2", 0x00ad521cULL, 0x01002580ULL, tnx_slot_repl_1, 0 },

    { "B1/off-vt0ff5720-no-data-slot", "B1", 0, 0, tnx_slot_repl_2, 0 },

    { "B2/off-vt0ff5720-no-data-slot", "B2", 0, 0, tnx_slot_repl_3, 0 },
    { "B3/off-vt0ff5720-no-data-slot", "B3", 0, 0, tnx_slot_repl_4, 0 },

    { "C1/Stage::addChild @c33690", "C1", 0x00c33690ULL, 0x01011f50ULL, tnx_slot_repl_5, 1 },
    { "C2/hotflag @b9dc24", "C2", 0x00b9dc24ULL, 0, tnx_slot_repl_6, 1 },

    { "P1/disabled-no-data-slot", "P1", 0, 0, tnx_slot_repl_7, 0 },
    { "D2/disabled-fewer-noisy-slots", "D2", 0, 0, tnx_slot_repl_8, 0 },
    { "P2/disabled-no-data-slot", "P2", 0, 0, tnx_slot_repl_9, 0 },
    { "D4/disabled-fewer-noisy-slots", "D4", 0, 0, tnx_slot_repl_10, 0 },
    { "V6/vt0fe9d00+68/8c7fbc", "V6", 0x008c7fbcULL, 0x00fe9d68ULL, tnx_slot_repl_11, 0 },
    { "D6/table1009290 slot1 @bad4ec", "D6", 0x00000000ULL, 0, tnx_slot_repl_12, 1 },

    { "E1/table100a770 slot0 @bcfbe8", "E1", 0x00bcfbe8ULL, 0, tnx_slot_repl_13, 0 },
    { "E2/table100a770 slot1 @bcfc28", "E2", 0x00bcfc28ULL, 0, tnx_slot_repl_14, 0 },
    { "V1/disabled-fewer-noisy-slots", "V1", 0, 0, tnx_slot_repl_15, 0 },
    { "V2/vt0fe9d00+40/8c6150", "V2", 0x008c6150ULL, 0x00fe9d40ULL, tnx_slot_repl_16, 0 },
    { "E5/logicPredictMoveSet @ac3f20", "E5", 0x00ac3f20ULL, 0, tnx_slot_repl_17, 1 },
    { "E6/clientInputManagerUpdate @746898", "E6", 0x00746898ULL, 0, tnx_slot_repl_18, 1 },

    { "D7/table10086c0 slot2 @b8ae88", "D7", 0x00b8ae88ULL, 0, tnx_slot_repl_19, 0 },
    { "D8/table10086c0 slot3 @b8ac7c", "D8", 0x00b8ac7cULL, 0, tnx_slot_repl_20, 0 },
    { "D9/disabled-fewer-noisy-slots", "D9", 0, 0, tnx_slot_repl_21, 0 },
    { "D10/disabled-fewer-noisy-slots", "D10", 0, 0, tnx_slot_repl_22, 0 },
    { "D11/table10086c0 slot8 @b85fe0", "D11", 0x00b85fe0ULL, 0, tnx_slot_repl_23, 0 },
    { "D12/table10086c0 slot9 @b867d8", "D12", 0x00b867d8ULL, 0, tnx_slot_repl_24, 0 },
    { "D13/table10086c0 slot10 @b9e188", "D13", 0x00b9e188ULL, 0, tnx_slot_repl_25, 0 },
    { "D14/table10086c0 slot11 @b9dc8c", "D14", 0x00b9dc8cULL, 0, tnx_slot_repl_26, 0 },

    { "V3/disabled-fewer-noisy-slots", "V3", 0, 0, tnx_slot_repl_27, 0 },
    { "V4/vt0fe9d00+50/8c7f9c", "V4", 0x008c7f9cULL, 0x00fe9d50ULL, tnx_slot_repl_28, 0 },
    { "V5/vt0fe9d00+58/8c7fac", "V5", 0x008c7facULL, 0x00fe9d58ULL, tnx_slot_repl_29, 0 },
    { "D15/table10086c0 slot21 @b898e8", "D15", 0x00b898e8ULL, 0, tnx_slot_repl_30, 0 },
    { "D16/table10086c0 slot23 @b89c10", "D16", 0x00b89c10ULL, 0, tnx_slot_repl_31, 0 },

    { "U1/LogicBattleModeClient::update", "U1", RVA_LOGICBATTLEMODECLIENT_UPDATE, 0,
      tnx_slot_repl_32, 0 },
    { "U2/BattleScreen::updateMovement", "U2", RVA_BATTLESCREEN__UPDATEMOVEMENT, 0,
      tnx_slot_repl_33, 0 },
};
