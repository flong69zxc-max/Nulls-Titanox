#include "offsets.h"
#include "hook.h"

#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <dlfcn.h>
#include <cxxabi.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <set>
#include <string>
#include <vector>

namespace {

struct Range {
    uintptr_t addr;
    size_t size;
    bool code;
    bool strings;
};

struct Image {
    image_ref_t ref{};
    intptr_t slide = 0;
    uintptr_t text = 0;
    std::vector<uint8_t> commands;
    std::vector<Range> ranges;
    std::vector<segment_command_64> segments;
    linkedit_data_command starts{};
    symtab_command symtab{};
    bool hasStarts = false;
    bool hasSymbols = false;
    uint8_t uuid[16]{};
    bool hasUUID = false;
};

static bool read_memory(uintptr_t address, void *out, size_t size)
{
    if (!size) return true;
    if (address > UINTPTR_MAX - size) return false;

    mach_vm_size_t copied = 0;
    kern_return_t kr = mach_vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)address,
        (mach_vm_size_t)size,
        (mach_vm_address_t)out,
        &copied
    );

    return kr == KERN_SUCCESS && copied == size;
}

static bool add_slide(uint64_t value, intptr_t slide, uintptr_t &out)
{
    if (value > UINTPTR_MAX) return false;

    uintptr_t v = (uintptr_t)value;

    if (slide >= 0) {
        uintptr_t s = (uintptr_t)slide;
        if (v > UINTPTR_MAX - s) return false;
        out = v + s;
    } else {
        uintptr_t s = (uintptr_t)(-(slide + 1)) + 1;
        if (v < s) return false;
        out = v - s;
    }

    return true;
}

static bool contains(const Range &r, uintptr_t address, size_t size)
{
    if (address < r.addr) return false;
    uintptr_t delta = address - r.addr;
    return delta <= r.size && size <= r.size - delta;
}

static bool code_address(const Image &img, uintptr_t address)
{
    if (address & 3) return false;

    for (const auto &r : img.ranges) {
        if (r.code && contains(r, address, 4)) return true;
    }

    return false;
}

static bool load_image(image_ref_t ref, Image &img)
{
    mach_header_64 header{};

    if (!ref.hdr || ref.base != (uintptr_t)ref.hdr) return false;
    if (!read_memory(ref.base, &header, sizeof(header))) return false;
    if (header.magic != MH_MAGIC_64) return false;
    if (header.sizeofcmds > 4U * 1024U * 1024U) return false;
    if (ref.base > UINTPTR_MAX - sizeof(header)) return false;

    bool found = false;

    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        if (_dyld_get_image_header(i) == (const mach_header *)ref.hdr) {
            img.slide = _dyld_get_image_vmaddr_slide(i);
            found = true;
            break;
        }
    }

    if (!found) return false;

    img.ref = ref;
    img.commands.resize(header.sizeofcmds);

    if (!read_memory(
            ref.base + sizeof(header),
            img.commands.data(),
            img.commands.size())) return false;

    size_t offset = 0;

    for (uint32_t i = 0; i < header.ncmds; ++i) {
        if (offset > img.commands.size()) return false;
        if (img.commands.size() - offset < sizeof(load_command)) return false;

        load_command lc{};
        memcpy(&lc, img.commands.data() + offset, sizeof(lc));

        if (lc.cmdsize < sizeof(lc)) return false;
        if (lc.cmdsize > img.commands.size() - offset) return false;

        const uint8_t *p = img.commands.data() + offset;

        if (lc.cmd == LC_SEGMENT_64) {
            if (lc.cmdsize < sizeof(segment_command_64)) return false;

            segment_command_64 sg{};
            memcpy(&sg, p, sizeof(sg));

            size_t available = lc.cmdsize - sizeof(sg);

            if (sg.nsects > available / sizeof(section_64)) return false;

            img.segments.push_back(sg);

            if (strncmp(sg.segname, "__TEXT", 16) == 0) {
                if (!add_slide(sg.vmaddr, img.slide, img.text)) return false;
            }

            for (uint32_t j = 0; j < sg.nsects; ++j) {
                section_64 sc{};

                memcpy(
                    &sc,
                    p + sizeof(sg) + j * sizeof(sc),
                    sizeof(sc)
                );

                if (sc.addr < sg.vmaddr) return false;

                uint64_t delta = sc.addr - sg.vmaddr;

                if (delta > sg.vmsize || sc.size > sg.vmsize - delta) {
                    return false;
                }

                if (!(sg.initprot & VM_PROT_READ)) continue;
                if (sc.size > SIZE_MAX) return false;

                uintptr_t runtime = 0;

                if (!add_slide(sc.addr, img.slide, runtime)) return false;
                if (runtime > UINTPTR_MAX - (size_t)sc.size) return false;

                bool executable = (sg.initprot & VM_PROT_EXECUTE) != 0;
                bool instructions = (sc.flags &
                    (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS)) != 0;

                bool code = executable && instructions &&
                    strncmp(sc.sectname, "__text", 16) == 0;

                bool strings = (sc.flags & SECTION_TYPE) == S_CSTRING_LITERALS;

                if (code || strings) {
                    img.ranges.push_back({
                        runtime,
                        (size_t)sc.size,
                        code,
                        strings
                    });
                }
            }
        } else if (lc.cmd == LC_FUNCTION_STARTS) {
            if (lc.cmdsize < sizeof(linkedit_data_command)) return false;
            memcpy(&img.starts, p, sizeof(img.starts));
            img.hasStarts = true;
        } else if (lc.cmd == LC_SYMTAB) {
            if (lc.cmdsize < sizeof(symtab_command)) return false;
            memcpy(&img.symtab, p, sizeof(img.symtab));
            img.hasSymbols = true;
        } else if (lc.cmd == LC_UUID) {
            if (lc.cmdsize < sizeof(uuid_command)) return false;

            uuid_command uc{};