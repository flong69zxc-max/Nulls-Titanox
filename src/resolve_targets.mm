#include "offsets.h"
#include "hook.h"

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

    if (!img.hasStarts || !img.starts.datasize) return result;
    if (img.starts.datasize > 16U * 1024U * 1024U) return result;

    uintptr_t address = 0;

    if (!linkedit_address(
            img,
            img.starts.dataoff,
            img.starts.datasize,
            address)) return result;

    std::vector<uint8_t> bytes(img.starts.datasize);

    if (!read_memory(address, bytes.data(), bytes.size())) return result;

    size_t offset = 0;
    uint64_t cumulative = 0;
    bool terminated = false;

    while (offset < bytes.size()) {
        uint64_t delta = 0;

        if (!read_uleb(bytes, offset, delta)) return {};

        if (!delta) {
            terminated = true;
            break;
        }

        if (cumulative > UINT64_MAX - delta) return {};
        cumulative += delta;

        if (cumulative > UINTPTR_MAX - img.text) return {};

        uintptr_t pc = img.text + (uintptr_t)cumulative;

        if (!code_address(img, pc)) return {};

        result.push_back(pc);
    }

    if (!terminated) return {};

    return result;
}

static bool method_name(
    const std::string &name,
    const std::string &wanted)
{
    size_t open = name.find('(');

    if (open == std::string::npos || open < wanted.size()) return false;

    size_t start = open - wanted.size();

    if (name.compare(start, wanted.size(), wanted) != 0) return false;
    if (!start) return true;

    char previous = name[start - 1];

    return previous == ':' || previous == ' ';
}

static std::set<uintptr_t> symbol_candidates(
    const Image &img,
    const std::string &wanted)
{
    std::set<uintptr_t> result;

    if (!img.hasSymbols || !img.symtab.nsyms || !img.symtab.strsize) {
        return result;
    }

    uint64_t symbolBytes =
        (uint64_t)img.symtab.nsyms * sizeof(nlist_64);

    if (symbolBytes > 128ULL * 1024ULL * 1024ULL) return result;
    if (img.symtab.strsize > 128U * 1024U * 1024U) return result;

    uintptr_t symbolsAddress = 0;
    uintptr_t stringsAddress = 0;

    if (!linkedit_address(
            img,
            img.symtab.symoff,
            symbolBytes,
            symbolsAddress)) return result;

    if (!linkedit_address(
            img,
            img.symtab.stroff,
            img.symtab.strsize,
            stringsAddress)) return result;

    std::vector<nlist_64> symbols(img.symtab.nsyms);
    std::vector<char> strings(img.symtab.strsize);

    if (!read_memory(
            symbolsAddress,
            symbols.data(),
            (size_t)symbolBytes)) return result;

    if (!read_memory(
            stringsAddress,
            strings.data(),
            strings.size())) return result;

    for (const auto &symbol : symbols) {
        if (symbol.n_type & N_STAB) continue;
        if ((symbol.n_type & N_TYPE) != N_SECT) continue;
        if (symbol.n_un.n_strx >= strings.size()) continue;

        const char *raw = strings.data() + symbol.n_un.n_strx;
        size_t remaining = strings.size() - symbol.n_un.n_strx;

        if (!memchr(raw, 0, remaining)) continue;

        const char *abiName = raw;

        if (raw[0] == '_' && raw[1] == '_' && raw[2] == 'Z') {
            abiName = raw + 1;
        }

        int status = -1;
        char *demangled = abi::__cxa_demangle(
            abiName,
            nullptr,
            nullptr,
            &status
        );

        std::string name =
            status == 0 && demangled ? demangled : raw;

        free(demangled);

        if (!method_name(name, wanted)) continue;

        uintptr_t pc = 0;

        if (!add_slide(symbol.n_value, img.slide, pc)) continue;
        if (!code_address(img, pc)) continue;

        result.insert(pc);
    }

    return result;
}

static std::set<uintptr_t> string_addresses(
    const Image &img,
    const std::string &wanted)
{
    std::set<uintptr_t> result;

    for (const auto &r : img.ranges) {
        if (!r.strings || r.size > 64U * 1024U * 1024U) continue;

        std::vector<uint8_t> bytes(r.size);

        if (!read_memory(r.addr, bytes.data(), bytes.size())) continue;

        size_t start = 0;

        while (start < bytes.size()) {
            const void *endPointer = memchr(
                bytes.data() + start,
                0,
                bytes.size() - start
            );

            if (!endPointer) break;

            size_t end =
                (const uint8_t *)endPointer - bytes.data();

            auto first = bytes.begin() + start;
            auto last = bytes.begin() + end;
            auto cursor = first;

            while (cursor != last) {
                auto match = std::search(
                    cursor,
                    last,
                    wanted.begin(),
                    wanted.end()
                );

                if (match == last) break;

                size_t position = (size_t)(match - bytes.begin());

                result.insert(r.addr + start);
                result.insert(r.addr + position);

                cursor = match + 1;

                if (result.size() > 4096) return {};
            }

            start = end + 1;
        }
    }

    return result;
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

static std::set<uintptr_t> xrefs(
    const Image &img,
    const std::set<uintptr_t> &strings)
{
    std::set<uintptr_t> result;

    for (const auto &r : img.ranges) {
        if (!r.code || r.size > 256U * 1024U * 1024U) continue;

        std::vector<uint32_t> words(r.size / 4);

        if (!read_memory(
                r.addr,
                words.data(),
                words.size() * 4)) continue;

        for (size_t i = 0; i < words.size(); ++i) {
            uint32_t op = words[i];
            uintptr_t pc = r.addr + i * 4;
            uint32_t rd = op & 31U;

            if (rd == 31U) continue;

            if ((op & 0x9f000000U) == 0x10000000U) {
                uintptr_t address =
                    pc + (uintptr_t)signed_imm21(op);

                if (strings.count(address)) result.insert(pc);

                continue;
            }

            if ((op & 0x9f000000U) != 0x90000000U) continue;
            if (i + 1 >= words.size()) continue;

            uint32_t add = words[i + 1];

            if ((add & 0xff800000U) != 0x91000000U) continue;
            if (((add >> 5) & 31U) != rd) continue;
            if ((add & 31U) == 31U) continue;

            uintptr_t page =
                (pc & ~(uintptr_t)0xfffU) +
                ((uintptr_t)signed_imm21(op) << 12);

            uintptr_t immediate = (add >> 10) & 0xfffU;

            if ((add >> 22) & 1U) immediate <<= 12;

            uintptr_t address = page + immediate;

            if (strings.count(address)) result.insert(pc);
        }
    }

    return result;
}

static uintptr_t enclosing_function(
    const Image &img,
    const std::vector<uintptr_t> &starts,
    uintptr_t pc)
{
    auto it = std::upper_bound(starts.begin(), starts.end(), pc);

    if (it == starts.begin()) return 0;

    uintptr_t start = *std::prev(it);

    for (const auto &r : img.ranges) {
        if (r.code && contains(r, pc, 4) && contains(r, start, 4)) {
            return start;
        }
    }

    return 0;
}

}

extern "C" uintptr_t rt_resolve_method(
    image_ref_t ref,
    const char *cls,
    const char *meth,
    uintptr_t *providedStarts,
    size_t providedCount,
    uintptr_t *xrefOut)
{
    if (xrefOut) *xrefOut = 0;
    if (!cls || !meth) return 0;

    Image img;

    if (!load_image(ref, img)) {
        brk_diag_log("resolve image_invalid");
        return 0;
    }

    std::string wanted = std::string(cls) + "::" + meth;
    auto symbols = symbol_candidates(img, wanted);

    if (symbols.size() == 1) {
        uintptr_t pc = *symbols.begin();

        brk_diag_log(
            "resolve name=%s source=symtab pc=%p",
            wanted.c_str(),
            (void *)pc
        );

        return pc;
    }

    if (symbols.size() > 1) {
        for (uintptr_t pc : symbols) {
            brk_diag_log(
                "resolve name=%s ambiguous_symbol=%p",
                wanted.c_str(),
                (void *)pc
            );
        }

        return 0;
    }

    auto strings = string_addresses(img, wanted);

    if (strings.empty()) {
        brk_diag_log(
            "resolve name=%s strings=0",
            wanted.c_str()
        );

        return 0;
    }

    auto references = xrefs(img, strings);
    std::vector<uintptr_t> starts;

    if (providedStarts && providedCount) {
        for (size_t i = 0; i < providedCount; ++i) {
            if (!code_address(img, providedStarts[i])) return 0;
            starts.push_back(providedStarts[i]);
        }

        std::sort(starts.begin(), starts.end());
        starts.erase(
            std::unique(starts.begin(), starts.end()),
            starts.end()
        );
    } else {
        starts = function_starts(img);
    }

    brk_diag_log(
        "resolve name=%s strings=%zu xrefs=%zu starts=%zu",
        wanted.c_str(),
        strings.size(),
        references.size(),
        starts.size()
    );

    std::set<uintptr_t> candidates;
    uintptr_t selectedXref = 0;

    for (uintptr_t reference : references) {
        uintptr_t start =
            enclosing_function(img, starts, reference);

        brk_diag_log(
            "resolve name=%s xref=%p containing_function=%p",
            wanted.c_str(),
            (void *)reference,
            (void *)start
        );

        if (start) {
            candidates.insert(start);
            if (!selectedXref) selectedXref = reference;
        }
    }

    if (candidates.size() != 1) return 0;

    if (xrefOut) *xrefOut = selectedXref;

    return *candidates.begin();
}

extern "C" int rt_is_code(image_ref_t ref, uintptr_t target)
{
    Image img;
    return load_image(ref, img) && code_address(img, target);
}

extern "C" void rt_dump_image(image_ref_t ref)
{
    Image img;

    if (!load_image(ref, img)) {
        brk_diag_log("image invalid base=%p", (void *)ref.base);
        return;
    }

    char uuid[33]{};

    if (img.hasUUID) {
        for (size_t i = 0; i < 16; ++i) {
            snprintf(uuid + i * 2, 3, "%02x", img.uuid[i]);
        }
    }

    brk_diag_log(
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

        brk_diag_log(
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
        brk_diag_log(
            "target name=%s pc=%p unreadable",
            name ? name : "?",
            (void *)target
        );

        return;
    }

    Dl_info info{};
    dladdr((void *)target, &info);

    brk_diag_log(
        "target name=%s pc=%p image=%s symbol=%s symbol_start=%p",
        name ? name : "?",
        (void *)target,
        info.dli_fname ? info.dli_fname : "?",
        info.dli_sname ? info.dli_sname : "?",
        info.dli_saddr
    );

    brk_diag_log(
        "opcodes %08x %08x %08x %08x %08x %08x %08x %08x",
        words[0], words[1], words[2], words[3],
        words[4], words[5], words[6], words[7]
    );
}