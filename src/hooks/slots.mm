#include "titanox.h"


int t_own_idhit = 0;

uintptr_t t_setpred = 0;



int t_live_objs = 0;

int t_live_teams = 0;

int t_fb_on = 0;

int t_fb_logged = 0;

int t_bar_logged = 0;


unsigned long long t_obj_prev = 0;

uintptr_t t_site = 0;

int t_state_2 = -1;

int t_scan_armed = -1;

volatile uint32_t t_seq = 0;

uintptr_t t_pub_object = 0;

uintptr_t t_pub_array = 0;

int32_t t_pub_count = 0;



uintptr_t t_tick_object = 0;

uintptr_t t_tick_array = 0;

int32_t t_tick_count = 0;




void tnx_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap,
                             const char *why) {
    __sync_synchronize();

    t_seq++;

    __sync_synchronize();

    t_pub_object = object;
    t_pub_array = array;
    t_pub_count = count;

    t_players_object = object;
    t_players_array = array;
    t_players_count = count;

    __sync_synchronize();

    t_seq++;

    __sync_synchronize();

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

void tnx_tick_begin(void) {
    uintptr_t o = 0;
    uintptr_t a = 0;
    int32_t c = 0;

    if (!tnx_snapshot(&o, &a, &c)) return;

    t_tick_object = o;
    t_tick_array = a;
    t_tick_count = c;
    t_tick_stamp++;
}

uint64_t t_idle_start = 0;


int t_idle_logged = 0;


void tnx_slot_install_one(int index) {
    uintptr_t target = 0;
    int slots = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    t_slot_installed[index] = 0;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    if (!t_slot_specs[index].rva && !t_slot_specs[index].slotRva) return;

    target = t_base + t_slot_specs[index].rva;

    if (!target) return;

    slots = hook_probe(target);

    if (slots > TNX_MAX_SLOTS) {

        return;
    }

    {
        uint32_t w = 0;
        int prologue = 0;

        if (tnx_read_word(target, &w)) {
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

            return;
        }
    }

    if (slots <= 0) {

        return;
    }

    if (!brk_install((void *)target, (void *)t_slot_specs[index].replacement)) {

        return;
    }

    t_slot_orig[index] = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    t_slot_installed[index] = 1;

}

void tnx_slot_hooks_install(void) {
    const char *flag = NULL;

    if (!t_base) return;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    flag = getenv("TITANOX_ALLOW_CODE_PATCH");


    for (int i = 0; i < TNX_SLOT_COUNT; i++) tnx_slot_install_one(i);

}


const int tnx_object_slots[TNX_OBJ_SLOTS] = { 2, 3, 4 };

uint64_t t_slot_hits[TNX_SLOT_COUNT] = { 0 };





int t_pub_logs = 0;

















void tnx_slot_pump(void) {
    int first = -1;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (!t_slot_object[i]) continue;

        if (!t_slot_specs[i].control && first < 0) first = i;
    }

    if (first < 0) return;

    uintptr_t object = t_slot_object[first];

    if (t_slot_adopted == object) return;

    t_slot_adopted = object;

    {
        void *vtable = NULL;

        if (!(tnx_read_ptr(object, &vtable) && vtable &&
              tnx_vtable_in_image((uintptr_t)vtable)) &&
            !tnx_pointer_plausible((uintptr_t)vtable)) {
            return;
        }
    }

    void *ownerField = NULL;

    tnx_read_ptr(object + TNX_SLOT_OWNER_OFF, &ownerField);

    {
        uintptr_t plan = t_slot_arg[first] ? t_slot_arg[first] : (uintptr_t)ownerField;

        if (plan && tnx_manager_live_count(plan) >= TNX_MANAGER_MIN_OBJECTS) {
            tnx_dodge_all_teams(plan);
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


    if (t_slot_orig[32]) r = t_slot_orig[32](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

uint64_t tnx_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;


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

void tnx_slot_note(int index, void *self, uint64_t arg1) {
    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    t_slot_hits[index]++;

    if (!t_slot_object[index] && self) t_slot_object[index] = (uintptr_t)self;

    if (!t_slot_arg[index] && arg1) t_slot_arg[index] = (uintptr_t)arg1;
}

uint64_t tnx_hook_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) total += t_slot_hits[i];

    return total;
}

uint64_t tnx_object_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < TNX_OBJ_SLOTS; i++) total += t_slot_hits[tnx_object_slots[i]];

    return total;
}

int tnx_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int live = 0;

    if (!tnx_pointer_plausible(manager)) return 0;
    if (!tnx_heap_contains(manager)) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_int(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_int(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;

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

    if (live < TNX_MANAGER_MIN_OBJECTS || live * 4 < nonEmpty * 3) return 0;

    return live;
}
