#include "titanox.h"

const char *t_image_names[4] = {
    "Nulls Brawl",
    "Laser",
    "NB.app",
    NULL
};

const tnx_rva_entry_t t_rvas[32] = {
    { "RVA_BATTLEMODE_GETINSTANCE", RVA_BATTLEMODE_GETINSTANCE },
    { "RVA_BATTLESCREEN__BATTLESCREEN", RVA_BATTLESCREEN__BATTLESCREEN },
    { "RVA_BATTLESCREEN__UPDATEMOVEMENT", RVA_BATTLESCREEN__UPDATEMOVEMENT },
    { "RVA_BATTLESCREEN__UPDATEAUTOSHOOT", RVA_BATTLESCREEN__UPDATEAUTOSHOOT },
    { "RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT", RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT },
    { "RVA_BATTLESCREEN__TRYTOACTIVATESKILL", RVA_BATTLESCREEN__TRYTOACTIVATESKILL },
    { "RVA_LOGICBATTLEMODECLIENT_UPDATE", RVA_LOGICBATTLEMODECLIENT_UPDATE },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER", RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM", RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM },
    { "RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO", RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETDATA", RVA_LOGICGAMEOBJECTCLIENT_GETDATA },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID", RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETX", RVA_LOGICGAMEOBJECTCLIENT_GETX },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETY", RVA_LOGICGAMEOBJECTCLIENT_GETY },
    { "RVA_LOGICPROJECTILEDATA_GETSPEED", RVA_LOGICPROJECTILEDATA_GETSPEED },
    { "RVA_LOGICPROJECTILEDATA_GETRADIUS", RVA_LOGICPROJECTILEDATA_GETRADIUS },
    { "RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR", RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR },
    { "RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION", RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION },
    { "RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT", RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT },
    { "RVA_STAGE_ADDCHILD", RVA_STAGE_ADDCHILD },
    { "RVA_STRINGTABLE_GETMOVIECLIP", RVA_STRINGTABLE_GETMOVIECLIP },
    { "RVA_MOVIECLIP__GETTEXTFIELDBYNAME", RVA_MOVIECLIP__GETTEXTFIELDBYNAME },
    { "RVA_TEXTFIELD_SETTEXT", RVA_TEXTFIELD_SETTEXT },
    { "RVA_DISPLAYOBJECT__SETXY", RVA_DISPLAYOBJECT__SETXY },
    { "RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS", RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS },
    { "RVA_BATTLESCREEN_FIREWRAPPERFN", RVA_BATTLESCREEN_FIREWRAPPERFN },
    { "RVA_BATTLESCREEN_ACTIVATESKILL", RVA_BATTLESCREEN_ACTIVATESKILL },
    { "RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS", RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS },
    { "RVA_MESSAGEMANAGER__RECEIVEMESSAGE", RVA_MESSAGEMANAGER__RECEIVEMESSAGE },
    { "RVA_COMBATHUD__SETMOVESTICKSTATE", RVA_COMBATHUD__SETMOVESTICKSTATE },
    { "RVA_COMBATHUD__SETSHOOTSTICKSTATE", RVA_COMBATHUD__SETSHOOTSTICKSTATE },
    { NULL, 0 }
};

FILE *t_log = NULL;

long t_log_written = 0;

BOOL t_setup_done = NO;

BOOL t_wm_failed = NO;

BOOL t_wm_ready = NO;

BOOL t_aim_rejected = NO;

__thread BOOL t_inside_hook = NO;

uint64_t t_dodge_calls = 0;

uint64_t t_render_calls = 0;

int t_dump_np = 0;

uintptr_t t_prev_scene = 0;

const uintptr_t t_mode_vtables_verified[3] = { 0x1002548, 0xff5720, 0 };

int tnx_verified_vtable(uintptr_t vtable) {
    if (!t_base || vtable <= t_base) return -1;

    uintptr_t rva = vtable - t_base;

    for (int i = 0; t_mode_vtables_verified[i]; i++) {
        if (rva == t_mode_vtables_verified[i]) return i;
    }

    return -1;
}

BOOL t_mode_strong = NO;

int t_mode_best_objects = 0;

int t_mode_last_types = 0;

int t_mode_verified_hits = 0;

int t_manager_count = 0;

int t_manager_probes = 0;

int t_manager_probes_total = 0;

int t_manager_skipped = 0;

int t_manager_last_live = 0;

int t_manager_last_nonempty = 0;

int t_manager_last_capacity = 0;

int t_manager_saw_cap = 0;

int t_manager_loose_count = 0;

int t_chain_checks = 0;

int t_chain_probes = 0;

int t_chain_skipped = 0;

int t_chain_best_own = 0;

int t_chain_best_gid = 0;

int t_seen_stable = 0;

int t_owner_vote_count = 0;

unsigned long long t_objvote_hits = 0;

unsigned long long t_objvote_skipped = 0;

int t_objvote_dead_seen = 0;

uintptr_t t_objvote_best_owner = 0;

int t_objvote_best_gids = 0;

int t_objvote_confirm = 0;

BOOL t_objvote_owner_ok = NO;

unsigned long long t_objvote_owner_img = 0;

unsigned long long t_objvote_obj_img = 0;

int t_objvote_best_teamcount = 0;

int t_objvote_best_gids_full = 0;

tnx_objhit_t t_objhits[TNX_OBJ_HIT_DUMP_MAX];

int t_objhit_count = 0;

unsigned long long t_objvote_owner_reg = 0;

unsigned long long t_objvote_owner_above_win = 0;

int t_objvote_max_votes = 0;

unsigned long long t_objvote_shaped = 0;

unsigned long long t_vtcensus_total = 0;

int t_heap_big_skip = 0;

int t_heap_region_capped = 0;

uintptr_t t_img_span_lo = 0;

uintptr_t t_img_span_hi = 0;

int t_img_span_ok = 0;

int t_trail_best = 0;

int t_manager_cap_rejects = 0;

int t_manager_best_count = 0;

int t_manager_best_live = 0;

int t_heap_passes = 0;

unsigned long long t_heap_covered = 0;

uintptr_t t_mode_source = 0;

int t_votescan_attempts = 0;

double t_votescan_last = 0.0;

BOOL t_snapshot_first = NO;

BOOL t_snapshot_second = NO;

double t_snapshot_start = 0.0;

int t_objc_armed = 0;

uintptr_t t_addr_getinstance = 0;

uintptr_t t_addr_getownchar = 0;

uintptr_t t_addr_getteam = 0;

uintptr_t t_addr_getx = 0;

uintptr_t t_addr_gety = 0;

uintptr_t t_addr_setprediction = 0;

uintptr_t t_addr_sendmovement = 0;

uintptr_t t_addr_getclip = 0;

uintptr_t t_addr_gettf = 0;

uintptr_t t_addr_settext = 0;

uintptr_t t_addr_setxy = 0;

uintptr_t t_addr_addchild = 0;

uintptr_t t_addr_battlescreen = 0;

void *t_label_clip = NULL;

void *t_label_tf = NULL;

void *t_label_sc = NULL;

char t_label_text[64] = {0};

int t_label_updates = 0;

uintptr_t tnx_strip_imp(IMP imp) {
#if defined(__has_feature)
#if __has_feature(ptrauth_calls)
    return (uintptr_t)ptrauth_strip((void *)imp, ptrauth_key_function_pointer);
#endif
#endif
    return (uintptr_t)imp;
}

uintptr_t t_addr[TNX_JOURNAL];

uint32_t t_value[TNX_JOURNAL];

uint64_t t_tick_3[TNX_JOURNAL];

const char *t_phase_2[TNX_JOURNAL];

uint8_t t_size[TNX_JOURNAL];

uint8_t t_denied[TNX_JOURNAL];

volatile int t_at = 0;

volatile uint64_t t_writes_2 = 0;

uint64_t t_stale = 0;

uintptr_t t_slot_object[TNX_SLOT_COUNT] = { 0 };

uintptr_t t_slot_arg1[TNX_SLOT_COUNT] = { 0 };

uint64_t t_slot_hits_total = 0;

int t_slot_slots[TNX_SLOT_COUNT] = { 0 };

int t_chain_rej[20] = { 0 };

int t_chain_probes_pass = 0;

int t_layout_logs = 0;

int t_no_source_passes = 0;

int t_route_logged = 0;

uint32_t t_slot_reported_mask = 0;

uint64_t t_slot_first_tick[TNX_SLOT_COUNT] = { 0 };

uintptr_t t_slot_adopted = 0;

int t_ag_adopted = 0;

int t_chain_hits = 0;

int t_mode_from_chain = 0;

int t_idle_probe_logged = 0;

uintptr_t t_last_cand = 0;

uintptr_t t_last_vt = 0;

char t_last_why[96] = { 0 };

int t_sig_ticks = 0;

int t_sig_logs = 0;

uintptr_t t_sig_last = 0;

int t_trail_refusals = 0;

int t_players_cap = 0;

int t_field_scans = 0;

int t_elem_full_dumps = 0;

int t_walk_relogs = 0;

uint64_t t_walk_tick = 0;

uint64_t t_enter_tick = 0;

int t_walk_count = -1;

int t_coord_fixed_logged = 0;

int t_class_pass = 0;

const char *t_mode_source_2 = "none";

uint64_t t_t0 = 0;

uint64_t t_slow = 0;

int t_ag_installed = -1;

uint64_t t_ag_hits = 0;

uintptr_t t_ag_objects[TNX_AG_OBJECT_MAX] = { 0 };

BOOL tnx_query_region(uintptr_t address,
                             vm_prot_t *protection,
                             vm_prot_t *maxProtection,
                             mach_vm_size_t *regionSize,
                             uintptr_t *regionStart) {
    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;

    kern_return_t result = vm_region_64(
        mach_task_self(),
        &regionAddress,
        &size,
        VM_REGION_BASIC_INFO_64,
        (vm_region_info_t)&info,
        &infoCount,
        &objectName
    );

    if (objectName != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), objectName);
    }

    if (result != KERN_SUCCESS || size == 0) return NO;
    if ((uintptr_t)regionAddress > address) return NO;
    if ((uintptr_t)regionAddress + (uintptr_t)size <= address) return NO;

    if (protection) *protection = info.protection;
    if (maxProtection) *maxProtection = info.max_protection;
    if (regionSize) *regionSize = (mach_vm_size_t)size;
    if (regionStart) *regionStart = (uintptr_t)regionAddress;

    return YES;
}

BOOL tnx_addr_writable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if (size == 0) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;

        uintptr_t next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

BOOL tnx_read_bytes(uintptr_t address, void *out, size_t length) {
    if (!out || !length) return NO;
    if (!address) return NO;

    vm_size_t got = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)address,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)out,
        &got
    );

    return result == KERN_SUCCESS && got == (vm_size_t)length;
}

BOOL tnx_pointer_plausible(uintptr_t value) {
    if (value < 0x10000) return NO;
    if (value & 7) return NO;

    return YES;
}

BOOL tnx_read_u8(uintptr_t address, uint8_t *out) {
    return tnx_read_bytes(address, out, 1);
}

BOOL tnx_read_i32(uintptr_t address, int32_t *out) {
    if (!out) return NO;
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

BOOL tnx_read_f32(uintptr_t address, float *out) {
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

uint64_t t_write_denied = 0;

int t_deny_logs = 0;

BOOL tnx_writable(uintptr_t address, size_t length) {
    uintptr_t end = address + length;
    uintptr_t cursor = address;

    if (!address || !length) return NO;
    if (end < address) return NO;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;
        if (size == 0) return NO;

        next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

void tnx_note(uintptr_t address, const void *src, size_t length, int denied) {
    int n = t_at;
    uint32_t value = 0;

    if (n < 0) n = 0;
    if (n >= TNX_JOURNAL) n = 0;

    if (src && length) {
        size_t take = length < sizeof(value) ? length : sizeof(value);

        memcpy(&value, src, take);
    }

    t_addr[n] = address;
    t_value[n] = value;
    t_tick_3[n] = t_stage_ticks;
    t_phase_2[n] = t_phase;
    t_size[n] = (uint8_t)(length > 255 ? 255 : length);
    t_denied[n] = (uint8_t)(denied ? 1 : 0);
    t_writes_2++;
    t_at = (n + 1) % TNX_JOURNAL;
}

BOOL tnx_write_bytes(uintptr_t address, const void *src, size_t length) {
    if (!src || !length) return NO;
    if (!address) return NO;

    if (TNX_WRITE_GUARD && !tnx_writable(address, length)) {
        t_write_denied++;
        tnx_note(address, src, length, 1);

        if (t_deny_logs < TNX_DENY_LOGS) {
            t_deny_logs++;

            tnx_logf("write denied at %p len=%zu total=%llu - the target is not inside a "
                     "writable region of this process, so the store is dropped instead of taking "
                     "the process down with it",
                     (void *)address, length, (unsigned long long)t_write_denied);
        }

        return NO;
    }

    tnx_note(address, src, length, 0);

    memcpy((void *)address, src, length);

    return YES;
}

BOOL tnx_write_f32(uintptr_t address, float value) {
    if (address & 3) return NO;

    return tnx_write_bytes(address, &value, sizeof(value));
}

BOOL tnx_read_ptr(uintptr_t address, void **out) {
    if (!out) return NO;
    if (address & 7) return NO;

    return tnx_read_bytes(address, out, sizeof(void *));
}

void *tnx_read_global_ptr(uintptr_t rva) {
    if (!t_base || !rva) return NULL;

    void *value = NULL;

    if (!tnx_read_ptr(t_base + rva, &value)) return NULL;

    return value;
}

uintptr_t tnx_callable(uintptr_t rva) {
    if (!t_base || !rva) return 0;

    uintptr_t address = t_base + rva;

    if (!tnx_addr_executable(address)) return 0;
    if (!tnx_image_text_contains(t_base, address)) return 0;

    BOOL exact = NO;

    tnx_start_index(address, &exact);

    if (exact) return address;
    if (tnx_looks_like_start(address)) return address;

    return 0;
}

uintptr_t tnx_pick(uintptr_t rvaA, uintptr_t rvaB) {
    uintptr_t a = tnx_callable(rvaA);
    if (a) return a;

    return tnx_callable(rvaB);
}

BOOL tnx_copy(uintptr_t source, void *destination, size_t length) {
    if (!source || !destination || !length) return NO;
    if (!tnx_addr_readable(source, length)) return NO;

    vm_size_t copied = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)source,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)destination,
        &copied
    );

    return result == KERN_SUCCESS && copied == (vm_size_t)length;
}

BOOL tnx_text_section(uintptr_t *address, uint64_t *size) {
    if (!t_base) return NO;
    if (!tnx_addr_readable(t_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)t_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(t_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__TEXT") == 0) {
                uint64_t room = (uint64_t)command->cmdsize - sizeof(struct segment_command_64);
                uint64_t count = room / sizeof(struct section_64);

                if (count > segment->nsects) count = segment->nsects;

                const struct section_64 *sections = (const struct section_64 *)(segment + 1);

                for (uint64_t s = 0; s < count; s++) {
                    if (strcmp(sections[s].sectname, "__text") != 0) continue;
                    if (!sections[s].size) continue;

                    if (address) *address = slide + (uintptr_t)sections[s].addr;
                    if (size) *size = sections[s].size;

                    return YES;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

BOOL tnx_valid_header(uintptr_t base) {
    if (!base) return NO;
    struct mach_header_64 header;

    if (!tnx_pointer_plausible(base)) return NO;
    if (!tnx_read_bytes(base, &header, sizeof(header))) return NO;

    if (header.magic != MH_MAGIC_64) return NO;
    if (header.ncmds == 0 || header.ncmds > 4096) return NO;
    if (header.sizeofcmds == 0) return NO;
    if (header.sizeofcmds > (4u * 1024u * 1024u)) return NO;
    if (!tnx_image_text_contains(base, base + TNX_IMAGE_TEXT_WINDOW)) return NO;

    return YES;
}

BOOL find_game_image(uintptr_t *out_base) {
    if (!out_base) return NO;

    uint32_t count = _dyld_image_count();
    if (count > 8192) count = 8192;

    uintptr_t fallback = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        uintptr_t base = (uintptr_t)_dyld_get_image_header(i);

        if (!path || !base) continue;
        if (!strstr(path, ".app/")) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "/usr/lib/")) continue;
        if (strstr(path, ".framework/")) continue;
        if (strstr(path, ".dylib")) continue;
        if (tnx_name_marks_host_runtime(path)) continue;
        if (!tnx_valid_header(base)) continue;

        BOOL matched = NO;

        for (int n = 0; t_image_names[n]; n++) {
            if (strstr(path, t_image_names[n])) {
                matched = YES;
                break;
            }
        }

        if (matched) {
            *out_base = base;
            return YES;
        }

        if (!fallback) fallback = base;
    }

    if (fallback) {
        *out_base = fallback;
        return YES;
    }

    return NO;
}

int t_scan_ticks = 0;

uint64_t t_drain = 0;

uint64_t t_q_max = 0;

uint64_t t_drag_writes = 0;

uint64_t t_drag_back = 0;

int t_alert_shown = 0;

uint64_t t_alert_cleared_ms = 0;

uintptr_t t_alert_scene = 0;

uint64_t t_alert_ms = 0;

uintptr_t t_owner = 0;

int t_done = 0;

uintptr_t t_owner_2 = 0;

int t_wired = 0;

dispatch_source_t t_scan_timer = NULL;

BOOL tnx_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi) {
    if (!t_base || !name) return NO;
    if (!tnx_addr_readable(t_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)t_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(t_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, name) == 0) {
                if (lo) *lo = slide + (uintptr_t)segment->vmaddr;
                if (hi) *hi = slide + (uintptr_t)segment->vmaddr + (uintptr_t)segment->vmsize;

                return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

BOOL tnx_image_contains(uintptr_t value) {
    if (!t_base || !value) return NO;
    if (!tnx_addr_readable(t_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)t_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(t_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

void tnx_image_span_refresh(void) {
    t_img_span_lo = 0;
    t_img_span_hi = 0;
    t_img_span_ok = 0;

    if (!t_base || !tnx_addr_readable(t_base, sizeof(struct mach_header_64))) return;

    const struct mach_header_64 *header = (const struct mach_header_64 *)t_base;

    if (header->magic != MH_MAGIC_64) return;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(t_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) break;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) break;
        if (cursor + command->cmdsize > limit) break;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;
                uintptr_t end = start + (uintptr_t)segment->vmsize;

                if (!t_img_span_lo || start < t_img_span_lo) t_img_span_lo = start;
                if (end > t_img_span_hi) t_img_span_hi = end;
            }
        }

        cursor += command->cmdsize;
    }

    t_img_span_ok = (t_img_span_hi > t_img_span_lo) ? 1 : 0;
}

BOOL tnx_in_image_span(uintptr_t value) {
    if (!value) return NO;
    if (!t_img_span_ok) return tnx_image_contains(value);

    return (value >= t_img_span_lo && value < t_img_span_hi) ? YES : NO;
}

const char *tnx_image_segment_name(uintptr_t value) {
    if (!t_base || !value) return NULL;
    if (!tnx_addr_readable(t_base, sizeof(struct mach_header_64))) return NULL;

    const struct mach_header_64 *header = (const struct mach_header_64 *)t_base;

    if (header->magic != MH_MAGIC_64) return NULL;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(t_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NULL;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NULL;
        if (cursor + command->cmdsize > limit) return NULL;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) {
                    return segment->segname;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NULL;
}

tnx_region_t t_heap_regions[TNX_HEAP_REGION_MAX];

int t_heap_region_count = 0;

uintptr_t t_heap_window_low = 0;

uintptr_t t_heap_window_high = 0;

int t_heap_window_ok = 0;

void tnx_heap_regions_refresh(void) {
    uintptr_t cursor = 0x10000;
    uintptr_t lowest = 0;
    uintptr_t highest = 0;
    int count = 0;

    for (int guard = 0; guard < 8192 && count < TNX_HEAP_REGION_MAX; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) break;
        if (size == 0) break;

        next = start + (uintptr_t)size;
        if (next <= cursor) break;

        if ((protection & VM_PROT_WRITE) &&
            size <= TNX_HEAP_REGION_MAX_SIZE &&
            start >= 0x10000 &&
            !tnx_image_segment_name(start)) {
            t_heap_regions[count].low = start;
            t_heap_regions[count].high = next;
            count++;

            if (!lowest || start < lowest) lowest = start;
            if (next > highest) highest = next;
        }

        cursor = next;
    }

    t_heap_region_count = count;
    t_heap_window_low = lowest;
    t_heap_window_high = highest;
    t_heap_window_ok = count > 0 ? 1 : 0;

    t_heap_region_capped = (count >= TNX_HEAP_REGION_MAX) ? 1 : 0;

    tnx_image_span_refresh();
}

BOOL tnx_heap_contains(uintptr_t value) {
    int lo = 0;
    int hi = t_heap_region_count - 1;

    if (!value) return NO;

    if (!t_heap_region_count) return tnx_image_segment_name(value) ? NO : YES;

    if (value < t_heap_window_low || value >= t_heap_window_high) return NO;

    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;

        if (value < t_heap_regions[mid].low) {
            hi = mid - 1;
        } else if (value >= t_heap_regions[mid].high) {
            lo = mid + 1;
        } else {
            return YES;
        }
    }

    return NO;
}

BOOL tnx_vtable_shaped(uintptr_t value) {
    const char *segment = tnx_image_segment_name(value);

    if (!segment) return NO;
    if (value % 8) return NO;

    if (strcmp(segment, TNX_VTABLE_SEGMENT) == 0) return YES;
    if (strcmp(segment, TNX_VTABLE_SEGMENT_ALT) == 0) return YES;

    return NO;
}

BOOL tnx_heap_resident(uintptr_t value) {
    if (!value) return NO;

    return tnx_image_segment_name(value) ? NO : YES;
}

BOOL tnx_owner_is_heap(uintptr_t owner) {
    if (!owner) return NO;
    if (tnx_in_image_span(owner)) return NO;
    if (!tnx_heap_resident(owner)) return NO;

    return tnx_heap_contains(owner);
}

BOOL tnx_gameobject_shape(uintptr_t object) {
    void *vtable = NULL;
    int32_t team = 0;
    uint8_t dead = 0;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;
    if (!tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team)) return NO;
    if (team < 0 || team > TNX_OBJ_TEAM_MAX) return NO;
    if (!tnx_read_u8(object + TNX_OBJ_DEADFLAG_OFF, &dead)) return NO;
    if (dead > 1) return NO;

    return YES;
}

BOOL tnx_instance_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;
    if ((uintptr_t)vtable == object) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;

    return YES;
}

BOOL tnx_manager_shape(uintptr_t manager) {
    void *array = NULL;
    void *probe = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!tnx_heap_resident(manager)) return NO;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return NO;
    if (count < 0 || count > TNX_MANAGER_MAX_OBJECTS) return NO;

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return NO;

    if (array && !tnx_heap_resident((uintptr_t)array)) return NO;

    if (count > 0) {
        if (!array) return NO;
        if (!tnx_read_ptr((uintptr_t)array, &probe)) return NO;
        if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        if (count > 1) {
            if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return NO;
            if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        }
    }

    return YES;
}

uintptr_t tnx_vtable_rva(void *object) {
    void *vtable = NULL;

    if (!object) return 0;
    if (!tnx_read_ptr((uintptr_t)object, &vtable)) return 0;
    if (!vtable) return 0;
    if ((uintptr_t)vtable < t_base) return 0;

    return (uintptr_t)vtable - t_base;
}

int t_trail_count = 0;

uint64_t t_trail_total = 0;

int t_gate_last = -1;

int t_gate_logs = 0;

int t_step_logs = 0;

int t_elem_logs = 0;

uintptr_t t_last_own = 0;

int t_logs = 0;

int32_t t_last_tx = 0;

int32_t t_last_ty = 0;

int t_issued = 0;

int tnx_write_i32(uintptr_t address, int32_t value) {
    if (address & 3) return 0;

    return tnx_write_bytes(address, &value, sizeof(value)) ? 1 : 0;
}

uintptr_t t_enemy_elem = 0;

uint64_t t_push_logs = 0;

uint64_t t_reloads = 0;

uint64_t t_pre_reloads = 0;

uint64_t t_pre_frames = 0;

uint64_t t_push_frame_2 = 0;

uint64_t t_win_reloads = 0;

int t_win_stage = 0;

float t_dir_x = 0.0f;

float t_dir_y = 0.0f;

int t_human_2 = 0;

int t_touch = 0;

int t_moved_3 = 0;

uint64_t t_stops = 0;

uint64_t t_queue_skips_2 = 0;

float t_org_x = 0.0f;

float t_org_y = 0.0f;

float t_cur_x = 0.0f;

float t_cur_y = 0.0f;

int32_t t_tx_3 = 0;

int32_t t_ty_3 = 0;

uint64_t t_hold = 0;

BOOL tnx_vtable_in_image(uintptr_t vtable) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;

    if (!vtable) return NO;
    if (vtable >= t_base + TNX_DC_RVA_LO && vtable < t_base + TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        return YES;
    }

    if (tnx_segment_range(TNX_VTABLE_SEGMENT_ALT, &lo, &hi) && vtable >= lo && vtable < hi) {
        return YES;
    }

    return NO;
}

uintptr_t tnx_strip_ptr(uintptr_t value) {
    uintptr_t stripped = value;

#if __has_feature(ptrauth_calls)
    stripped = (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_function_pointer);
#endif

    if (stripped >= t_base && stripped < t_base + TNX_IMAGE_SPAN) return stripped;

    if ((stripped & 0xffffffffULL) < TNX_IMAGE_SPAN) {
        uintptr_t viaLow = t_base + (stripped & 0xffffffffULL);

        if (viaLow >= t_base && viaLow < t_base + TNX_IMAGE_SPAN) return viaLow;
    }

    return stripped;
}

void poll_for_game(int tick) {
    if (t_setup_done) return;
    if (tick > 1200) return;

    uintptr_t base = 0;

    if (find_game_image(&base)) {
        t_base = base;
        setup();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(tick + 1);
    });
}
