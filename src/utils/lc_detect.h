#pragma once

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdio.h>
#import <unistd.h>
#import <stdint.h>

static inline BOOL tnx_name_marks_host_runtime(const char *name) {
    if (!name) return NO;
    static const char *marks[] = {
        "TweakLoader",
        "LiveContainer",
        "LiveContainerShared",
        "CydiaSubstrate",
        "libellekit",
        "SubstrateLoader",
        NULL
    };
    for (int i = 0; marks[i]; i++) {
        if (strstr(name, marks[i])) return YES;
    }
    return NO;
}

static inline BOOL tnx_host_is_livecontainer(void) {
    static int cached = -1;
    if (cached >= 0) return cached ? YES : NO;

    int found = 0;

    uint32_t count = _dyld_image_count();
    if (count > 8192) count = 8192;

    for (uint32_t i = 0; i < count && !found; i++) {
        if (tnx_name_marks_host_runtime(_dyld_get_image_name(i))) found = 1;
    }

    if (!found) {
        NSString *identifier = [NSBundle mainBundle].bundleIdentifier;
        if (identifier &&
            [identifier rangeOfString:@"livecontainer"
                              options:NSCaseInsensitiveSearch].location != NSNotFound) {
            found = 1;
        }
    }

    if (!found && dlsym(RTLD_DEFAULT, "LiveContainerMain") != NULL) found = 1;

    if (!found) {
        const char *home = getenv("HOME");
        if (home) {
            char probe[1024];
            snprintf(probe, sizeof(probe), "%s/Documents/Tweaks", home);
            if (access(probe, F_OK) == 0) found = 1;
        }
    }

    if (!found) {
        const char *injected = getenv("DYLD_INSERT_LIBRARIES");
        if (injected && strstr(injected, "TweakLoader")) found = 1;
    }

    cached = found;
    return found ? YES : NO;
}

static inline BOOL tnx_region_flags(uintptr_t address, vm_prot_t *outFlags) {
    if (!address) return NO;

    vm_address_t region = (vm_address_t)address;
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
    if ((uintptr_t)region > address) return NO;
    if ((uintptr_t)region + (uintptr_t)size <= address) return NO;

    if (outFlags) *outFlags = info.protection;
    return YES;
}

static inline BOOL tnx_addr_readable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t flags = 0;
        if (!tnx_region_flags(cursor, &flags)) return NO;
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

static inline BOOL tnx_read_u32(uintptr_t address, uint32_t *out) {
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

static inline BOOL tnx_read_pointer(uintptr_t address, uintptr_t *out) {
    if (!address || (address & 7) || !out) return NO;

    uintptr_t value = 0;
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

static inline BOOL tnx_addr_executable(uintptr_t address) {
    vm_prot_t flags = 0;
    if (!tnx_region_flags(address, &flags)) return NO;
    return (flags & VM_PROT_EXECUTE) ? YES : NO;
}

static inline uintptr_t tnx_image_slide(uintptr_t imageBase) {
    if (!imageBase) return 0;

    const struct mach_header_64 *header = (const struct mach_header_64 *)imageBase;

    if (!tnx_addr_readable(imageBase, sizeof(struct mach_header_64))) return 0;
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

static inline BOOL tnx_image_segment_contains(uintptr_t imageBase,
                                              uintptr_t address,
                                              BOOL requireExec,
                                              uintptr_t *outStart,
                                              uintptr_t *outEnd,
                                              uint32_t *outProt) {
    if (!imageBase || !address) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)imageBase;

    if (!tnx_addr_readable(imageBase, sizeof(struct mach_header_64))) return NO;
    if (header->magic != MH_MAGIC_64) return NO;
    if (header->ncmds == 0 || header->ncmds > 4096) return NO;
    if (header->sizeofcmds == 0 || header->sizeofcmds > (4u * 1024u * 1024u)) return NO;

    uintptr_t slide = tnx_image_slide(imageBase);

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

static inline BOOL tnx_image_text_contains(uintptr_t imageBase, uintptr_t address) {
    uintptr_t start = 0;
    uintptr_t end = 0;
    uint32_t prot = 0;

    if (!tnx_image_segment_contains(imageBase, address, NO, &start, &end, &prot)) return NO;

    return (prot & VM_PROT_EXECUTE) ? YES : NO;
}

static inline BOOL tnx_looks_like_function(uintptr_t address) {
    uint32_t first = 0;

    if (!tnx_read_u32(address, &first)) return NO;

    if (first == 0xD503233F) return YES;
    if (first == 0xD503237F) return YES;

    if ((first & 0xFFFFFF1F) == 0xD503241F) return YES;

    uint32_t pairBase = first & 0xFFC00000u;

    if ((pairBase == 0xA9800000u ||
         pairBase == 0xA9000000u ||
         pairBase == 0xA8C00000u) &&
        (first & 0x7C00u) == 0x7800u &&
        (first & 0x1Fu) == 29u) {
        return YES;
    }

    if ((first & 0xFF8003FFu) == 0xD10003FFu) return YES;

    if (address >= 4) {
        uint32_t previous = 0;
        if (tnx_read_u32(address - 4, &previous) && previous == 0xD65F03C0) {
            return YES;
        }
    }

    return NO;
}

static inline BOOL tnx_callable_target(uintptr_t imageBase, uintptr_t address) {
    if (!address) return NO;
    if (!tnx_addr_executable(address)) return NO;
    if (!tnx_image_text_contains(imageBase, address)) return NO;
    return tnx_looks_like_function(address);
}

static inline BOOL tnx_patchable_target(uintptr_t imageBase, uintptr_t address) {
    if (!imageBase || !address) return NO;
    if (address & 3) return NO;

    uintptr_t start = 0;
    uintptr_t end = 0;
    uint32_t prot = 0;

    if (!tnx_image_segment_contains(imageBase, address, YES, &start, &end, &prot)) return NO;
    if ((address + 16) > end) return NO;

    uint32_t word = 0;
    if (!tnx_read_u32(address, &word)) return NO;

    return YES;
}

static inline BOOL tnx_object_plausible(void *object) {
    if (!object) return NO;

    uintptr_t address = (uintptr_t)object;

    if (address < 0x100000000ULL) return NO;
    if (address & 7) return NO;
    if (!tnx_addr_readable(address, sizeof(void *))) return NO;

    uintptr_t vtable = 0;
    if (!tnx_read_pointer(address, &vtable)) return NO;
    if (!vtable) return NO;
    if (!tnx_addr_readable(vtable, sizeof(void *))) return NO;

    uintptr_t firstEntry = 0;
    if (!tnx_read_pointer(vtable, &firstEntry)) return NO;
    if (!firstEntry) return NO;

    return tnx_addr_executable(firstEntry);
}

static inline NSString *tnx_host_description(void) {
    return tnx_host_is_livecontainer() ? @"livecontainer" : @"native";
}

static inline BOOL tnx_image_owns_address(uintptr_t imageBase, uintptr_t address) {
    return tnx_image_segment_contains(imageBase, address, NO, NULL, NULL, NULL);
}

static inline BOOL tnx_isa_in_image_data(uintptr_t imageBase, uintptr_t isa) {
    if (!imageBase || !isa) return NO;

    uintptr_t start = 0;
    uintptr_t end = 0;
    uint32_t prot = 0;

    if (!tnx_image_segment_contains(imageBase, isa, NO, &start, &end, &prot)) return NO;
    if (prot & VM_PROT_EXECUTE) return NO;

    return YES;
}

static inline Class tnx_object_class(void *object) {
    if (!object) return Nil;

    uintptr_t address = (uintptr_t)object;
    if (address < 0x100000000ULL) return Nil;
    if (address & 7) return Nil;
    if (!tnx_addr_readable(address, sizeof(void *))) return Nil;

#if __has_feature(objc_arc)
    return object_getClass((__bridge id)object);
#else
    return object_getClass((id)object);
#endif
}

static inline NSString *tnx_object_class_name(void *object) {
    Class cls = tnx_object_class(object);
    if (!cls) return nil;

    const char *name = class_getName(cls);
    if (!name) return nil;

    return [NSString stringWithUTF8String:name];
}

static inline BOOL tnx_object_is_class_named(void *object, const char *expected) {
    if (!expected) return NO;

    Class cls = tnx_object_class(object);
    if (!cls) return NO;

    const char *name = class_getName(cls);
    if (!name) return NO;

    return strcmp(name, expected) == 0 ? YES : NO;
}

static inline NSString *tnx_isa_owner_description(uintptr_t imageBase, void *object) {
    Class cls = tnx_object_class(object);
    if (!cls) return @"no-class";

    if (tnx_image_owns_address(imageBase, (uintptr_t)cls)) return @"game-image";
    if (tnx_isa_in_image_data(imageBase, (uintptr_t)cls)) return @"game-data";

    return @"foreign";
}
