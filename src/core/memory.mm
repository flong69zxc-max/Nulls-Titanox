#include "../recoil.h"

const char *rcl_image_names[4] = {
    "Nulls Brawl",
    "Laser",
    "NB.app",
    NULL
};

const rcl_rva_entry_t rcl_rvas[32] = {
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



BOOL rcl_setup_done = NO;



BOOL rcl_aim_rejected = NO;

__thread BOOL rcl_inside_hook = NO;

uint64_t rcl_dodge_calls = 0;


int rcl_dump_np = 0;


BOOL rcl_mode_strong = NO;




int rcl_manager_count = 0;



















uintptr_t rcl_objvote_best_owner = 0;






int rcl_objvote_best_teamcount = 0;


rcl_objhit_t rcl_objhits[RCL_OBJ_HIT_DUMP_MAX];

int rcl_objhit_count = 0;



int rcl_objvote_max_votes = 0;




int rcl_heap_region_capped = 0;

uintptr_t rcl_img_span_lo = 0;

uintptr_t rcl_img_span_hi = 0;


int rcl_trail_best = 0;







int rcl_votescan_attempts = 0;

double rcl_votescan_last = 0.0;

BOOL rcl_snapshot_first = NO;

BOOL rcl_snapshot_second = NO;

double rcl_snapshot_start = 0.0;


uintptr_t rcl_addr_getinstance = 0;

uintptr_t rcl_addr_getownchar = 0;

uintptr_t rcl_addr_getteam = 0;

uintptr_t rcl_addr_getx = 0;

uintptr_t rcl_addr_gety = 0;

uintptr_t rcl_addr_setprediction = 0;







uintptr_t rcl_addr_battlescreen = 0;












volatile int rcl_at = 0;


uint64_t rcl_stale = 0;

uintptr_t rcl_slot_object[RCL_SLOT_COUNT] = { 0 };

uintptr_t rcl_slot_arg[RCL_SLOT_COUNT] = { 0 };






int rcl_no_source_passes = 0;

int rcl_route_logged = 0;



uintptr_t rcl_slot_adopted = 0;








int rcl_sig_ticks = 0;


uintptr_t rcl_sig_last = 0;






uint64_t rcl_walk_tick = 0;


int rcl_walk_count = -1;

int rcl_coord_fixed_logged = 0;



uint64_t rcl_time = 0;

uint64_t rcl_slow = 0;




BOOL rcl_query_region(uintptr_t address,
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

BOOL rcl_addr_writable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;

        if (!rcl_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if (size == 0) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;

        uintptr_t next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

BOOL rcl_read_bytes(uintptr_t address, void *out, size_t length) {
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

BOOL rcl_pointer_plausible(uintptr_t value) {
    if (value < 0x10000) return NO;
    if (value & 7) return NO;

    return YES;
}

BOOL rcl_read_byte(uintptr_t address, uint8_t *out) {
    return rcl_read_bytes(address, out, 1);
}

BOOL rcl_read_int(uintptr_t address, int32_t *out) {
    if (!out) return NO;
    if (address & 3) return NO;

    return rcl_read_bytes(address, out, 4);
}

BOOL rcl_read_float(uintptr_t address, float *out) {
    if (address & 3) return NO;

    return rcl_read_bytes(address, out, 4);
}



BOOL rcl_writable(uintptr_t address, size_t length) {
    uintptr_t end = address + length;
    uintptr_t cursor = address;

    if (!address || !length) return NO;
    if (end < address) return NO;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!rcl_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;
        if (size == 0) return NO;

        next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

void rcl_note(uintptr_t address, const void *src, size_t length, int denied) {
    int n = rcl_at;
    uint32_t value = 0;

    if (n < 0) n = 0;
    if (n >= RCL_JOURNAL) n = 0;

    if (src && length) {
        size_t take = length < sizeof(value) ? length : sizeof(value);

        memcpy(&value, src, take);
    }

    rcl_at = (n + 1) % RCL_JOURNAL;
}

BOOL rcl_write_bytes(uintptr_t address, const void *src, size_t length) {
    if (!src || !length) return NO;
    if (!address) return NO;

    if (RCL_WRITE_GUARD && !rcl_writable(address, length)) {
        rcl_note(address, src, length, 1);


        return NO;
    }

    rcl_note(address, src, length, 0);

    memcpy((void *)address, src, length);

    return YES;
}

BOOL rcl_write_float(uintptr_t address, float value) {
    if (address & 3) return NO;

    return rcl_write_bytes(address, &value, sizeof(value));
}

BOOL rcl_read_ptr(uintptr_t address, void **out) {
    if (!out) return NO;
    if (address & 7) return NO;

    return rcl_read_bytes(address, out, sizeof(void *));
}

void *rcl_read_global_ptr(uintptr_t rva) {
    if (!rcl_base || !rva) return NULL;

    void *value = NULL;

    if (!rcl_read_ptr(rcl_base + rva, &value)) return NULL;

    return value;
}

uintptr_t rcl_callable(uintptr_t rva) {
    if (!rcl_base || !rva) return 0;

    uintptr_t address = rcl_base + rva;

    if (!rcl_addr_executable(address)) return 0;
    if (!rcl_image_text_contains(rcl_base, address)) return 0;

    BOOL exact = NO;

    rcl_start_index(address, &exact);

    if (exact) return address;
    if (rcl_looks_like_start(address)) return address;

    return 0;
}
BOOL rcl_copy(uintptr_t source, void *destination, size_t length) {
    if (!source || !destination || !length) return NO;
    if (!rcl_addr_readable(source, length)) return NO;

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

BOOL rcl_text_section(uintptr_t *address, uint64_t *size) {
    if (!rcl_base) return NO;
    if (!rcl_addr_readable(rcl_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);

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

BOOL rcl_valid_header(uintptr_t base) {
    if (!base) return NO;
    struct mach_header_64 header;

    if (!rcl_pointer_plausible(base)) return NO;
    if (!rcl_read_bytes(base, &header, sizeof(header))) return NO;

    if (header.magic != MH_MAGIC_64) return NO;
    if (header.ncmds == 0 || header.ncmds > 4096) return NO;
    if (header.sizeofcmds == 0) return NO;
    if (header.sizeofcmds > (4u * 1024u * 1024u)) return NO;
    if (!rcl_image_text_contains(base, base + RCL_IMAGE_TEXT_WINDOW)) return NO;

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
        if (!rcl_valid_header(base)) continue;

        BOOL matched = NO;

        for (int n = 0; rcl_image_names[n]; n++) {
            if (strstr(path, rcl_image_names[n])) {
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


uint64_t rcl_drain = 0;

uint64_t rcl_q_max = 0;









uintptr_t rcl_owner = 0;

int rcl_wired = 0;

dispatch_source_t rcl_scan_timer = NULL;

BOOL rcl_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi) {
    if (!rcl_base || !name) return NO;
    if (!rcl_addr_readable(rcl_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);

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
void rcl_image_span_refresh(void) {
    rcl_img_span_lo = 0;
    rcl_img_span_hi = 0;

    if (!rcl_base || !rcl_addr_readable(rcl_base, sizeof(struct mach_header_64))) return;

    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;

    if (header->magic != MH_MAGIC_64) return;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);

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

                if (!rcl_img_span_lo || start < rcl_img_span_lo) rcl_img_span_lo = start;
                if (end > rcl_img_span_hi) rcl_img_span_hi = end;
            }
        }

        cursor += command->cmdsize;
    }

}
const char *rcl_image_segment_name(uintptr_t value) {
    if (!rcl_base || !value) return NULL;
    if (!rcl_addr_readable(rcl_base, sizeof(struct mach_header_64))) return NULL;

    const struct mach_header_64 *header = (const struct mach_header_64 *)rcl_base;

    if (header->magic != MH_MAGIC_64) return NULL;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = rcl_image_slide(rcl_base);

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

rcl_region_t rcl_heap_regions[RCL_HEAP_REGION_MAX];

int rcl_heap_region_count = 0;

uintptr_t rcl_heap_window_low = 0;

uintptr_t rcl_heap_window_high = 0;


void rcl_heap_regions_refresh(void) {
    uintptr_t cursor = 0x10000;
    uintptr_t lowest = 0;
    uintptr_t highest = 0;
    int count = 0;

    for (int guard = 0; guard < 8192 && count < RCL_HEAP_REGION_MAX; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!rcl_query_region(cursor, &protection, NULL, &size, &start)) break;
        if (size == 0) break;

        next = start + (uintptr_t)size;
        if (next <= cursor) break;

        if ((protection & VM_PROT_WRITE) &&
            size <= RCL_HEAP_REGION_MAX_SIZE &&
            start >= 0x10000 &&
            !rcl_image_segment_name(start)) {
            rcl_heap_regions[count].low = start;
            rcl_heap_regions[count].high = next;
            count++;

            if (!lowest || start < lowest) lowest = start;
            if (next > highest) highest = next;
        }

        cursor = next;
    }

    rcl_heap_region_count = count;
    rcl_heap_window_low = lowest;
    rcl_heap_window_high = highest;

    rcl_heap_region_capped = (count >= RCL_HEAP_REGION_MAX) ? 1 : 0;

    rcl_image_span_refresh();
}

BOOL rcl_heap_contains(uintptr_t value) {
    int lo = 0;
    int hi = rcl_heap_region_count - 1;

    if (!value) return NO;

    if (!rcl_heap_region_count) return rcl_image_segment_name(value) ? NO : YES;

    if (value < rcl_heap_window_low || value >= rcl_heap_window_high) return NO;

    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;

        if (value < rcl_heap_regions[mid].low) {
            hi = mid - 1;
        } else if (value >= rcl_heap_regions[mid].high) {
            lo = mid + 1;
        } else {
            return YES;
        }
    }

    return NO;
}

BOOL rcl_vtable_shaped(uintptr_t value) {
    const char *segment = rcl_image_segment_name(value);

    if (!segment) return NO;
    if (value % 8) return NO;

    if (strcmp(segment, RCL_VTABLE_SEGMENT) == 0) return YES;
    if (strcmp(segment, RCL_VTABLE_SEGMENT_ALT) == 0) return YES;

    return NO;
}

BOOL rcl_heap_resident(uintptr_t value) {
    if (!value) return NO;

    return rcl_image_segment_name(value) ? NO : YES;
}
BOOL rcl_gameobject_shape(uintptr_t object) {
    void *vtable = NULL;
    int32_t team = 0;
    uint8_t dead = 0;

    if (!rcl_pointer_plausible(object)) return NO;
    if (!rcl_heap_resident(object)) return NO;
    if (!rcl_read_ptr(object, &vtable)) return NO;
    if (!rcl_vtable_shaped((uintptr_t)vtable)) return NO;
    if (!rcl_read_int(object + RCL_OBJ_TEAM_OFF, &team)) return NO;
    if (team < 0 || team > RCL_OBJ_TEAM_MAX) return NO;
    if (!rcl_read_byte(object + RCL_OBJ_DEADFLAG_OFF, &dead)) return NO;
    if (dead > 1) return NO;

    return YES;
}

BOOL rcl_instance_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!rcl_pointer_plausible(object)) return NO;
    if (!rcl_heap_resident(object)) return NO;
    if (!rcl_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;
    if ((uintptr_t)vtable == object) return NO;
    if (!rcl_vtable_shaped((uintptr_t)vtable)) return NO;

    return YES;
}

BOOL rcl_manager_shape(uintptr_t manager) {
    void *array = NULL;
    void *probe = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!rcl_heap_resident(manager)) return NO;
    if (!rcl_read_ptr(manager + RCL_MGR_ARRAY_OFF, &array)) return NO;
    if (!rcl_read_int(manager + RCL_MGR_COUNT_OFF, &count)) return NO;
    if (!rcl_read_int(manager + RCL_MGR_CAP_OFF, &capacity)) return NO;
    if (count < 0 || count > RCL_MANAGER_MAX_OBJECTS) return NO;

    if (capacity < count || capacity > RCL_MGR_CAP_MAX) return NO;

    if (array && !rcl_heap_resident((uintptr_t)array)) return NO;

    if (count > 0) {
        if (!array) return NO;
        if (!rcl_read_ptr((uintptr_t)array, &probe)) return NO;
        if (!rcl_heap_resident((uintptr_t)probe)) return NO;
        if (count > 1) {
            if (!rcl_read_ptr((uintptr_t)array + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return NO;
            if (!rcl_heap_resident((uintptr_t)probe)) return NO;
        }
    }

    return YES;
}
int rcl_trail_count = 0;


int rcl_gate_last = -1;




uintptr_t rcl_last_own = 0;


int32_t rcl_last_tx = 0;

int32_t rcl_last_ty = 0;

int rcl_issued = 0;
int rcl_human_2 = 0;




uint64_t rcl_queue_skips = 0;





int32_t rcl_tx_b = 0;

int32_t rcl_ty_b = 0;

uint64_t rcl_hold = 0;

BOOL rcl_vtable_in_image(uintptr_t vtable) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;

    if (!vtable) return NO;
    if (vtable >= rcl_base + RCL_DC_RVA_LO && vtable < rcl_base + RCL_DC_RVA_LO + RCL_DC_RVA_SIZE) {
        return YES;
    }

    if (rcl_segment_range(RCL_VTABLE_SEGMENT_ALT, &lo, &hi) && vtable >= lo && vtable < hi) {
        return YES;
    }

    return NO;
}

uintptr_t rcl_strip_ptr(uintptr_t value) {
    uintptr_t stripped = value;

#if __has_feature(ptrauth_calls)
    stripped = (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_function_pointer);
#endif

    if (stripped >= rcl_base && stripped < rcl_base + RCL_IMAGE_SPAN) return stripped;

    if ((stripped & 0xffffffffULL) < RCL_IMAGE_SPAN) {
        uintptr_t viaLow = rcl_base + (stripped & 0xffffffffULL);

        if (viaLow >= rcl_base && viaLow < rcl_base + RCL_IMAGE_SPAN) return viaLow;
    }

    return stripped;
}

void poll_for_game(int tick) {
    if (rcl_setup_done) return;
    if (tick > 1200) return;

    uintptr_t base = 0;

    if (find_game_image(&base)) {
        rcl_base = base;
        setup();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(tick + 1);
    });
}

uintptr_t rcl_base = 0;
