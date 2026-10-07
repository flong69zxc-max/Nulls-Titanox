#include "../recoil.h"



uintptr_t rcl_setpred = 0;



int rcl_live_objs = 0;

int rcl_live_teams = 0;

int rcl_fb_on = 0;

int rcl_fb_logged = 0;

int rcl_bar_logged = 0;


unsigned long long rcl_obj_prev = 0;

uintptr_t rcl_site = 0;

int rcl_state_2 = -1;

int rcl_scan_armed = -1;

volatile uint32_t rcl_seq = 0;

uintptr_t rcl_pub_object = 0;

uintptr_t rcl_pub_array = 0;

int32_t rcl_pub_count = 0;



uintptr_t rcl_tick_object = 0;

uintptr_t rcl_tick_array = 0;

int32_t rcl_tick_count = 0;




void rcl_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap,
                             const char *why) {
    __sync_synchronize();

    rcl_seq++;

    __sync_synchronize();

    rcl_pub_object = object;
    rcl_pub_array = array;
    rcl_pub_count = count;

    rcl_players_object = object;
    rcl_players_array = array;
    rcl_players_count = count;

    __sync_synchronize();

    rcl_seq++;

    __sync_synchronize();

}

int rcl_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut) {
    int tries;

    for (tries = 0; tries < 8; tries++) {
        uint32_t s1 = rcl_seq;
        uintptr_t o;
        uintptr_t a;
        int32_t c;

        if (s1 & 1u) continue;

        o = rcl_pub_object;
        a = rcl_pub_array;
        c = rcl_pub_count;

        __sync_synchronize();

        if (rcl_seq != s1) continue;

        if (objectOut) *objectOut = o;
        if (arrayOut) *arrayOut = a;
        if (countOut) *countOut = c;

        return 1;
    }

    return 0;
}

void rcl_tick_begin(void) {
    uintptr_t o = 0;
    uintptr_t a = 0;
    int32_t c = 0;

    if (!rcl_snapshot(&o, &a, &c)) return;

    rcl_tick_object = o;
    rcl_tick_array = a;
    rcl_tick_count = c;
    rcl_tick_stamp++;
}

uint64_t rcl_idle_start = 0;


int rcl_idle_logged = 0;


void rcl_slot_hooks_install(void) {
    if (!rcl_base) return;

    rcl_hooks_install(rcl_base, rcl_slot_specs, RCL_SLOT_COUNT, (void **)rcl_slot_orig);
}


const int rcl_object_slots[RCL_OBJ_SLOTS] = { 2, 3, 4 };

uint64_t rcl_slot_hits[RCL_SLOT_COUNT] = { 0 };





int rcl_pub_logs = 0;

















void rcl_slot_pump(void) {
    int first = -1;

    for (int i = 0; i < RCL_SLOT_COUNT; i++) {
        if (!rcl_slot_object[i]) continue;

        if (!rcl_slot_specs[i].control && first < 0) first = i;
    }

    if (first < 0) return;

    uintptr_t object = rcl_slot_object[first];

    if (rcl_slot_adopted == object) return;

    rcl_slot_adopted = object;

    {
        void *vtable = NULL;

        if (!(rcl_read_ptr(object, &vtable) && vtable &&
              rcl_vtable_in_image((uintptr_t)vtable)) &&
            !rcl_pointer_plausible((uintptr_t)vtable)) {
            return;
        }
    }

    void *ownerField = NULL;

    rcl_read_ptr(object + RCL_SLOT_OWNER_OFF, &ownerField);

    {
        uintptr_t plan = rcl_slot_arg[first] ? rcl_slot_arg[first] : (uintptr_t)ownerField;

        if (plan && rcl_manager_live_count(plan) >= RCL_MANAGER_MIN_OBJECTS) {
            rcl_dodge_all_teams(plan);
        }
    }
}

rcl_slot_fn_t rcl_slot_orig[RCL_SLOT_COUNT] = { NULL };

uint64_t rcl_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(0, a0, a1);

    if (rcl_slot_orig[0]) return rcl_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(1, a0, a1);

    if (rcl_slot_orig[1]) return rcl_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(2, a0, a1);

    if (rcl_slot_orig[2]) return rcl_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(3, a0, a1);

    if (rcl_slot_orig[3]) return rcl_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(4, a0, a1);

    if (rcl_slot_orig[4]) return rcl_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(5, a0, a1);

    if (rcl_slot_orig[5]) return rcl_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(6, a0, a1);

    if (rcl_slot_orig[6]) return rcl_slot_orig[6](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(7, a0, a1);

    if (rcl_slot_orig[7]) return rcl_slot_orig[7](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(8, a0, a1);

    if (rcl_slot_orig[8]) return rcl_slot_orig[8](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(9, a0, a1);

    if (rcl_slot_orig[9]) return rcl_slot_orig[9](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(10, a0, a1);

    if (rcl_slot_orig[10]) return rcl_slot_orig[10](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(11, a0, a1);

    if (rcl_slot_orig[11]) return rcl_slot_orig[11](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(12, a0, a1);

    if (rcl_slot_orig[12]) return rcl_slot_orig[12](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(13, a0, a1);

    if (rcl_slot_orig[13]) return rcl_slot_orig[13](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(14, a0, a1);

    if (rcl_slot_orig[14]) return rcl_slot_orig[14](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(15, a0, a1);

    if (rcl_slot_orig[15]) return rcl_slot_orig[15](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(16, a0, a1);

    if (rcl_slot_orig[16]) return rcl_slot_orig[16](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(17, a0, a1);

    if (rcl_slot_orig[17]) return rcl_slot_orig[17](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(18, a0, a1);

    if (rcl_slot_orig[18]) return rcl_slot_orig[18](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(19, a0, a1);

    if (rcl_slot_orig[19]) return rcl_slot_orig[19](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(20, a0, a1);

    if (rcl_slot_orig[20]) return rcl_slot_orig[20](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(21, a0, a1);

    if (rcl_slot_orig[21]) return rcl_slot_orig[21](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(22, a0, a1);

    if (rcl_slot_orig[22]) return rcl_slot_orig[22](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(23, a0, a1);

    if (rcl_slot_orig[23]) return rcl_slot_orig[23](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(24, a0, a1);

    if (rcl_slot_orig[24]) return rcl_slot_orig[24](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(25, a0, a1);

    if (rcl_slot_orig[25]) return rcl_slot_orig[25](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(26, a0, a1);

    if (rcl_slot_orig[26]) return rcl_slot_orig[26](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(27, a0, a1);

    if (rcl_slot_orig[27]) return rcl_slot_orig[27](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(28, a0, a1);

    if (rcl_slot_orig[28]) return rcl_slot_orig[28](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(29, a0, a1);

    if (rcl_slot_orig[29]) return rcl_slot_orig[29](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(30, a0, a1);

    if (rcl_slot_orig[30]) return rcl_slot_orig[30](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    rcl_slot_note(31, a0, a1);

    if (rcl_slot_orig[31]) return rcl_slot_orig[31](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t rcl_slot_repl_32(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;


    if (rcl_slot_orig[32]) r = rcl_slot_orig[32](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

uint64_t rcl_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;


    if (rcl_slot_orig[33]) r = rcl_slot_orig[33](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

const rcl_hook_t rcl_slot_specs[RCL_SLOT_COUNT] = {

    { 0x00ad4ed0ULL, (void *)rcl_slot_repl_0, 0 },
    { 0x00ad521cULL, (void *)rcl_slot_repl_1, 0 },

    { 0, (void *)rcl_slot_repl_2, 0 },

    { 0, (void *)rcl_slot_repl_3, 0 },
    { 0, (void *)rcl_slot_repl_4, 0 },

    { 0x00c33690ULL, (void *)rcl_slot_repl_5, 1 },
    { 0x00b9dc24ULL, (void *)rcl_slot_repl_6, 1 },

    { 0, (void *)rcl_slot_repl_7, 0 },
    { 0, (void *)rcl_slot_repl_8, 0 },
    { 0, (void *)rcl_slot_repl_9, 0 },
    { 0, (void *)rcl_slot_repl_10, 0 },
    { 0x008c7fbcULL, (void *)rcl_slot_repl_11, 0 },
    { 0x00000000ULL, (void *)rcl_slot_repl_12, 1 },

    { 0x00bcfbe8ULL, (void *)rcl_slot_repl_13, 0 },
    { 0x00bcfc28ULL, (void *)rcl_slot_repl_14, 0 },
    { 0, (void *)rcl_slot_repl_15, 0 },
    { 0x008c6150ULL, (void *)rcl_slot_repl_16, 0 },
    { 0x00ac3f20ULL, (void *)rcl_slot_repl_17, 1 },
    { 0x00746898ULL, (void *)rcl_slot_repl_18, 1 },

    { 0x00b8ae88ULL, (void *)rcl_slot_repl_19, 0 },
    { 0x00b8ac7cULL, (void *)rcl_slot_repl_20, 0 },
    { 0, (void *)rcl_slot_repl_21, 0 },
    { 0, (void *)rcl_slot_repl_22, 0 },
    { 0x00b85fe0ULL, (void *)rcl_slot_repl_23, 0 },
    { 0x00b867d8ULL, (void *)rcl_slot_repl_24, 0 },
    { 0x00b9e188ULL, (void *)rcl_slot_repl_25, 0 },
    { 0x00b9dc8cULL, (void *)rcl_slot_repl_26, 0 },

    { 0, (void *)rcl_slot_repl_27, 0 },
    { 0x008c7f9cULL, (void *)rcl_slot_repl_28, 0 },
    { 0x008c7facULL, (void *)rcl_slot_repl_29, 0 },
    { 0x00b898e8ULL, (void *)rcl_slot_repl_30, 0 },
    { 0x00b89c10ULL, (void *)rcl_slot_repl_31, 0 },

    { RVA_LOGICBATTLEMODECLIENT_UPDATE, (void *)rcl_slot_repl_32, 0 },
    { RVA_BATTLESCREEN__UPDATEMOVEMENT, (void *)rcl_slot_repl_33, 0 },
};

void rcl_slot_note(int index, void *self, uint64_t arg1) {
    if (index < 0 || index >= RCL_SLOT_COUNT) return;

    rcl_slot_hits[index]++;

    if (!rcl_slot_object[index] && self) rcl_slot_object[index] = (uintptr_t)self;

    if (!rcl_slot_arg[index] && arg1) rcl_slot_arg[index] = (uintptr_t)arg1;
}

uint64_t rcl_hook_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < RCL_SLOT_COUNT; i++) total += rcl_slot_hits[i];

    return total;
}

uint64_t rcl_object_dispatches(void) {
    uint64_t total = 0;

    for (int i = 0; i < RCL_OBJ_SLOTS; i++) total += rcl_slot_hits[rcl_object_slots[i]];

    return total;
}

int rcl_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int live = 0;

    if (!rcl_pointer_plausible(manager)) return 0;
    if (!rcl_heap_contains(manager)) return 0;
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array)) return 0;
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count)) return 0;
    if (!rcl_read_int(manager + RCL_MGR_CAP_OFF, &capacity)) return 0;

    if (count < RCL_MANAGER_MIN_OBJECTS || count > RCL_MANAGER_MAX_OBJECTS) return 0;
    if (!array) return 0;
    if (!rcl_heap_contains((uintptr_t)array)) return 0;
    if ((uintptr_t)array & 0xf) return 0;

    if (capacity < count || capacity > RCL_MGR_CAP_MAX) return 0;

    uintptr_t types[RCL_MODE_TYPE_MAX] = {0};
    int typeCount = 0;
    int nonEmpty = 0;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;

        if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        nonEmpty++;

        if (!rcl_heap_resident((uintptr_t)element)) continue;
        if (!rcl_read_ptr((uintptr_t)element, &vtable)) continue;
        if (!vtable) continue;
        if (!rcl_vtable_shaped((uintptr_t)vtable)) continue;

        if (!rcl_object_live((uintptr_t)element)) continue;

        live++;

        uintptr_t elementRva = (uintptr_t)vtable - rcl_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < RCL_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    if (typeCount < RCL_MODE_MIN_TYPES) return 0;

    if (live < RCL_MANAGER_MIN_OBJECTS || live * 4 < nonEmpty * 3) return 0;

    return live;
}
