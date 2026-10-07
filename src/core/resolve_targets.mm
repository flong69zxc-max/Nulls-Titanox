#include "core/offsets.h"
#include "core/config.h"
#include "hook.h"

#ifndef TNX_HOOK_DIAG
#define TNX_HOOK_DIAG 0
#endif

#define TNX_HOOKLOG(...) do { if (TNX_HOOK_DIAG) brk_diag_log(__VA_ARGS__); } while (0)

#include <mach/mach.h>
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
#include <utility>
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

    vm_size_t copied = 0;
    kern_return_t kr = vm_read_overwrite(
        mach_task_self(),
        (vm_address_t)address,
        (vm_size_t)size,
        (vm_address_t)out,
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
            memcpy(&uc, p, sizeof(uc));
            memcpy(img.uuid, uc.uuid, sizeof(img.uuid));
            img.hasUUID = true;
        }

        offset += lc.cmdsize;
    }

    return img.text != 0 && offset == img.commands.size();
}

static bool linkedit_address(
    const Image &img,
    uint64_t fileOffset,
    uint64_t size,
    uintptr_t &out)
{
    for (const auto &sg : img.segments) {
        if (strncmp(sg.segname, "__LINKEDIT", 16) != 0) continue;
        if (fileOffset < sg.fileoff) return false;

        uint64_t delta = fileOffset - sg.fileoff;

        if (delta > sg.filesize || size > sg.filesize - delta) return false;
        if (delta > sg.vmsize || size > sg.vmsize - delta) return false;
        if (sg.vmaddr > UINT64_MAX - delta) return false;
        if (!add_slide(sg.vmaddr + delta, img.slide, out)) return false;
        if (size > UINTPTR_MAX - out) return false;

        return true;
    }

    return false;
}

static bool read_uleb(
    const std::vector<uint8_t> &bytes,
    size_t &offset,
    uint64_t &value)
{
    value = 0;

    for (unsigned shift = 0; shift <= 63; shift += 7) {
        if (offset >= bytes.size()) return false;

        uint8_t b = bytes[offset++];
        uint64_t payload = b & 0x7f;

        if (shift == 63 && payload > 1) return false;

        value |= payload << shift;

        if (!(b & 0x80)) return true;
    }

    return false;
}

static std::vector<uintptr_t> function_starts(const Image &img)
{
    std::vector<uintptr_t> result;

    TNX_HOOKLOG(
        "function_starts hasStarts=%d dataoff=0x%llx datasize=0x%llx",
        img.hasStarts ? 1 : 0,
        (unsigned long long)img.starts.dataoff,
        (unsigned long long)img.starts.datasize
    );

    if (!img.hasStarts || !img.starts.datasize) return result;
    if (img.starts.datasize > 16U * 1024U * 1024U) return result;

    uintptr_t address = 0;

    if (!linkedit_address(
            img,
            img.starts.dataoff,
            img.starts.datasize,
            address)) {
        TNX_HOOKLOG("function_starts linkedit_address_failed");
        return result;
    }

    TNX_HOOKLOG("function_starts linkedit=%p", (void *)address);

    std::vector<uint8_t> bytes(img.starts.datasize);

    if (!read_memory(address, bytes.data(), bytes.size())) {
        TNX_HOOKLOG("function_starts read_memory_failed size=%zu", bytes.size());
        return result;
    }

    size_t offset = 0;
    uint64_t cumulative = 0;
    bool terminated = false;

    while (offset < bytes.size()) {
        uint64_t delta = 0;

        if (!read_uleb(bytes, offset, delta)) {
            TNX_HOOKLOG("function_starts uleb_failed offset=%zu", offset);
            return {};
        }

        if (!delta) {
            terminated = true;
            break;
        }

        if (cumulative > UINT64_MAX - delta) return {};
        cumulative += delta;

        if (cumulative > UINTPTR_MAX - img.text) return {};

        uintptr_t pc = img.text + (uintptr_t)cumulative;

        if (!code_address(img, pc)) {
            TNX_HOOKLOG(
                "function_starts code_address_failed pc=%p",
                (void *)pc
            );
            continue;
        }

        result.push_back(pc);
    }

    TNX_HOOKLOG(
        "function_starts parsed=%zu terminated=%d",
        result.size(),
        terminated
    );

    if (!terminated) return {};

    return result;
}

static bool method_name(
    const std::string &name,
    const std::string &wanted)
{
    if (name == wanted) return true;

    size_t open = name.find('(');

    if (open == std::string::npos) {
        return name == wanted;
    }

    if (open == wanted.size() &&
        name.compare(0, wanted.size(), wanted) == 0) {
        return true;
    }

    if (open < wanted.size()) return false;

    size_t start = open - wanted.size();

    if (name.compare(start, wanted.size(), wanted) != 0) return false;
    if (!start) return true;

    char previous = name[start - 1];

    return previous == ':' || previous == ' ';
}



static int64_t signed_imm21(uint32_t op)
{
    uint32_t value =
        (((op >> 5) & 0x7ffffU) << 2) |
        ((op >> 29) & 3U);

    return (value & 0x100000U)
        ? (int64_t)value - 0x200000LL
        : (int64_t)value;
}




}
extern "C" void rt_dump_image(image_ref_t ref)
{
    Image img;

    if (!load_image(ref, img)) {
        TNX_HOOKLOG("image invalid base=%p", (void *)ref.base);
        return;
    }

    char uuid[33]{};

    if (img.hasUUID) {
        for (size_t i = 0; i < 16; ++i) {
            snprintf(uuid + i * 2, 3, "%02x", img.uuid[i]);
        }
    }

    TNX_HOOKLOG(
        "image base=%p slide=0x%llx text=%p uuid=%s starts=%d symtab=%d",
        (void *)ref.base,
        (unsigned long long)(uintptr_t)img.slide,
        (void *)img.text,
        img.hasUUID ? uuid : "missing",
        img.hasStarts,
        img.hasSymbols
    );

    for (const auto &sg : img.segments) {
        uintptr_t runtime = 0;
        add_slide(sg.vmaddr, img.slide, runtime);

        TNX_HOOKLOG(
            "segment name=%.16s runtime=%p vmaddr=0x%llx size=0x%llx prot=%x",
            sg.segname,
            (void *)runtime,
            (unsigned long long)sg.vmaddr,
            (unsigned long long)sg.vmsize,
            sg.initprot
        );
    }
}

extern "C" void rt_dump_target(const char *name, uintptr_t target)
{
    if (!target) return;

    uint32_t words[8]{};

    if (!read_memory(target, words, sizeof(words))) {
        TNX_HOOKLOG(
            "target name=%s pc=%p unreadable",
            name ? name : "?",
            (void *)target
        );

        return;
    }

    Dl_info info{};
    dladdr((void *)target, &info);

    TNX_HOOKLOG(
        "target name=%s pc=%p image=%s symbol=%s symbol_start=%p",
        name ? name : "?",
        (void *)target,
        info.dli_fname ? info.dli_fname : "?",
        info.dli_sname ? info.dli_sname : "?",
        info.dli_saddr
    );

    TNX_HOOKLOG(
        "opcodes %08x %08x %08x %08x %08x %08x %08x %08x",
        words[0], words[1], words[2], words[3],
        words[4], words[5], words[6], words[7]
    );
}
