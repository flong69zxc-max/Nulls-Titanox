#ifndef RECOIL_CORE_MEMORY_H
#define RECOIL_CORE_MEMORY_H

#include "../types/types.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>

extern uintptr_t rcl_base;


extern const char *rcl_image_names[4];
extern const rcl_rva_entry_t rcl_rvas[32];
extern uintptr_t *rcl_starts;
extern size_t rcl_starts_count;
extern BOOL rcl_setup_done;
extern BOOL rcl_aim_rejected;
extern __thread BOOL rcl_inside_hook;
extern uint64_t rcl_dodge_calls;
extern int rcl_dump_np;
extern BOOL rcl_mode_strong;
extern uintptr_t rcl_players_object;
extern int rcl_manager_count;
extern uintptr_t rcl_objvote_best_owner;
extern int rcl_objvote_best_teamcount;
extern rcl_objhit_t rcl_objhits[RCL_OBJ_HIT_DUMP_MAX];
extern int rcl_objhit_count;
extern int rcl_objvote_max_votes;
extern int rcl_heap_region_capped;
extern uintptr_t rcl_img_span_lo;
extern uintptr_t rcl_img_span_hi;
extern int rcl_trail_best;
extern int rcl_votescan_attempts;
extern double rcl_votescan_last;
extern BOOL rcl_snapshot_first;
extern BOOL rcl_snapshot_second;
extern double rcl_snapshot_start;
extern uintptr_t rcl_addr_getinstance;
extern uintptr_t rcl_addr_getownchar;
extern uintptr_t rcl_addr_getteam;
extern uintptr_t rcl_addr_getx;
extern uintptr_t rcl_addr_gety;
extern uintptr_t rcl_addr_setprediction;
extern uintptr_t rcl_addr_battlescreen;
extern volatile int rcl_at;
extern uint64_t rcl_stale;
extern int rcl_no_source_passes;
extern int rcl_route_logged;
extern int rcl_sig_ticks;
extern uintptr_t rcl_sig_last;
extern uintptr_t rcl_players_array;
extern int rcl_players_count;
extern uint64_t rcl_walk_tick;
extern int rcl_walk_count;
extern int rcl_coord_fixed_logged;
extern uint64_t rcl_time;
extern uint64_t rcl_slow;
extern uint64_t rcl_drain;
extern uint64_t rcl_q_max;
extern uintptr_t rcl_owner;
extern int rcl_wired;
extern dispatch_source_t rcl_scan_timer;
extern rcl_region_t rcl_heap_regions[RCL_HEAP_REGION_MAX];
extern int rcl_heap_region_count;
extern uintptr_t rcl_heap_window_low;
extern uintptr_t rcl_heap_window_high;
extern const uintptr_t rcl_mode_vtables[36];
extern rcl_trail_t rcl_trail[RCL_TRAIL_MAX];
extern int rcl_trail_count;
extern int rcl_gate_last;
extern int rcl_dodge_probe_usable;
extern uintptr_t rcl_last_own;
extern int32_t rcl_last_tx;
extern int32_t rcl_last_ty;
extern int rcl_issued;
extern uintptr_t rcl_own_elem_2;
extern int rcl_human_2;
extern uint64_t rcl_queue_skips;
extern int32_t rcl_tx_b;
extern int32_t rcl_ty_b;
extern uint64_t rcl_hold;

BOOL rcl_query_region(uintptr_t address, vm_prot_t *protection, vm_prot_t *maxProtection, mach_vm_size_t *regionSize, uintptr_t *regionStart);
BOOL rcl_addr_writable(uintptr_t address, size_t length);
BOOL rcl_read_bytes(uintptr_t address, void *out, size_t length);
BOOL rcl_pointer_plausible(uintptr_t value);
BOOL rcl_read_byte(uintptr_t address, uint8_t *out);
BOOL rcl_read_int(uintptr_t address, int32_t *out);
BOOL rcl_read_float(uintptr_t address, float *out);
BOOL rcl_writable(uintptr_t address, size_t length);
void rcl_note(uintptr_t address, const void *src, size_t length, int denied);
BOOL rcl_write_bytes(uintptr_t address, const void *src, size_t length);
BOOL rcl_write_float(uintptr_t address, float value);
BOOL rcl_read_ptr(uintptr_t address, void **out);
void *rcl_read_global_ptr(uintptr_t rva);
uintptr_t rcl_callable(uintptr_t rva);
BOOL rcl_copy(uintptr_t source, void *destination, size_t length);
BOOL rcl_text_section(uintptr_t *address, uint64_t *size);
BOOL rcl_valid_header(uintptr_t base);
BOOL find_game_image(uintptr_t *out_base);
BOOL rcl_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi);
void rcl_image_span_refresh(void);
const char *rcl_image_segment_name(uintptr_t value);
void rcl_heap_regions_refresh(void);
BOOL rcl_heap_contains(uintptr_t value);
BOOL rcl_vtable_shaped(uintptr_t value);
BOOL rcl_heap_resident(uintptr_t value);
BOOL rcl_gameobject_shape(uintptr_t object);
BOOL rcl_instance_shaped(uintptr_t object);
BOOL rcl_manager_shape(uintptr_t manager);
BOOL rcl_vtable_in_image(uintptr_t vtable);
uintptr_t rcl_strip_ptr(uintptr_t value);
void poll_for_game(int tick);

static inline BOOL rcl_region_flags(uintptr_t address, vm_prot_t *flags) {
    vm_prot_t protection = 0;

    if (flags) *flags = 0;

    if (!rcl_query_region(address, &protection, NULL, NULL, NULL)) return NO;

    if (flags) *flags = protection;

    return YES;
}

static inline BOOL rcl_addr_readable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t flags = 0;
        if (!rcl_region_flags(cursor, &flags)) return NO;
        if ((flags & VM_PROT_READ) == 0) return NO;

        vm_address_t region = (vm_address_t)cursor;
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t objectName = MACH_PORT_NULL;

        kern_return_t kr = vm_region_64(
            mach_task_self(),
            &region,
            &size,
            VM_REGION_BASIC_INFO_64,
            (vm_region_info_t)&info,
            &infoCount,
            &objectName
        );

        if (objectName != MACH_PORT_NULL) {
            mach_port_deallocate(mach_task_self(), objectName);
        }

        if (kr != KERN_SUCCESS || size == 0) return NO;

        uintptr_t next = (uintptr_t)region + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

static inline BOOL rcl_read_word(uintptr_t address, uint32_t *out) {
    if (!address || (address & 3) || !out) return NO;

    uint32_t value = 0;
    vm_size_t got = 0;

    kern_return_t kr = vm_read_overwrite(
        mach_task_self(),
        (vm_address_t)address,
        sizeof(value),
        (vm_address_t)&value,
        &got
    );

    if (kr != KERN_SUCCESS || got != sizeof(value)) return NO;

    *out = value;
    return YES;
}

static inline BOOL rcl_addr_executable(uintptr_t address) {
    vm_prot_t flags = 0;
    if (!rcl_region_flags(address, &flags)) return NO;
    return (flags & VM_PROT_EXECUTE) ? YES : NO;
}

static inline uintptr_t rcl_image_slide(uintptr_t imageBase) {
    if (!imageBase) return 0;

    const struct mach_header_64 *header = (const struct mach_header_64 *)imageBase;

    if (!rcl_addr_readable(imageBase, sizeof(struct mach_header_64))) return 0;
    if (header->magic != MH_MAGIC_64) return 0;
    if (header->ncmds == 0 || header->ncmds > 4096) return 0;
    if (header->sizeofcmds == 0 || header->sizeofcmds > (4u * 1024u * 1024u)) return 0;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return 0;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return 0;
        if (cursor + command->cmdsize > limit) return 0;

        if (command->cmd == LC_SEGMENT_64) {
            if (command->cmdsize < sizeof(struct segment_command_64)) return 0;

            const struct segment_command_64 *segment =
                (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__TEXT") == 0) {
                return imageBase - (uintptr_t)segment->vmaddr;
            }
        }

        cursor += command->cmdsize;
    }

    return 0;
}

static inline BOOL rcl_image_segment_contains(uintptr_t imageBase,
                                              uintptr_t address,
                                              BOOL requireExec,
                                              uintptr_t *outStart,
                                              uintptr_t *outEnd,
                                              uint32_t *outProt) {
    if (!imageBase || !address) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)imageBase;

    if (!rcl_addr_readable(imageBase, sizeof(struct mach_header_64))) return NO;
    if (header->magic != MH_MAGIC_64) return NO;
    if (header->ncmds == 0 || header->ncmds > 4096) return NO;
    if (header->sizeofcmds == 0 || header->sizeofcmds > (4u * 1024u * 1024u)) return NO;

    uintptr_t slide = rcl_image_slide(imageBase);

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64) {
            if (command->cmdsize < sizeof(struct segment_command_64)) return NO;

            const struct segment_command_64 *segment =
                (const struct segment_command_64 *)command;

            uintptr_t start = (uintptr_t)segment->vmaddr + slide;
            uintptr_t end = start + (uintptr_t)segment->vmsize;

            if (address >= start && address < end) {
                BOOL executable = (segment->initprot & VM_PROT_EXECUTE) ? YES : NO;
                if (requireExec && !executable) return NO;
                if (outStart) *outStart = start;
                if (outEnd) *outEnd = end;
                if (outProt) *outProt = (uint32_t)segment->initprot;
                return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static inline BOOL rcl_image_text_contains(uintptr_t imageBase, uintptr_t address) {
    uintptr_t start = 0;
    uintptr_t end = 0;
    uint32_t prot = 0;

    if (!rcl_image_segment_contains(imageBase, address, NO, &start, &end, &prot)) return NO;

    return (prot & VM_PROT_EXECUTE) ? YES : NO;
}

static inline BOOL rcl_object_plausible(void *object) {
    if (!object) return NO;

    uintptr_t address = (uintptr_t)object;

    if (address < 0x100000000ULL) return NO;
    if (address & 7) return NO;
    if (!rcl_addr_readable(address, sizeof(void *))) return NO;

    uintptr_t vtable = 0;
    if (!rcl_read_bytes(address, &vtable, sizeof(vtable))) return NO;
    if (!vtable) return NO;
    if (!rcl_addr_readable(vtable, sizeof(void *))) return NO;

    uintptr_t firstEntry = 0;
    if (!rcl_read_bytes(vtable, &firstEntry, sizeof(firstEntry))) return NO;
    if (!firstEntry) return NO;

    return rcl_addr_executable(firstEntry);
}

#endif
