#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>

typedef struct {
    uintptr_t base;
    const struct mach_header_64 *hdr;
} image_ref_t;

static const struct segment_command_64 *seg_find(const struct mach_header_64 *hdr,
                                                const char *name)
{
    const uint8_t *p = (const uint8_t *)hdr + sizeof(*hdr);
    for (uint32_t i = 0; i < hdr->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sg = (const struct segment_command_64 *)lc;
            if (strncmp(sg->segname, name, 16) == 0) {
                return sg;
            }
        }
        p += lc->cmdsize;
    }
    return NULL;
}

static uintptr_t seg_scan(const struct segment_command_64 *sg, uintptr_t slide,
                          const void *needle, size_t nlen)
{
    const uint8_t *begin = (const uint8_t *)(sg->vmaddr + slide);
    const uint8_t *end = begin + sg->vmsize;
    if (nlen == 0) {
        return 0;
    }
    for (const uint8_t *p = begin; p + nlen <= end; p++) {
        if (p[0] == ((const uint8_t *)needle)[0] && memcmp(p, needle, nlen) == 0) {
            return (uintptr_t)p;
        }
    }
    return 0;
}

uintptr_t rt_find_method_string(image_ref_t img, const char *cls, const char *meth,
                               uintptr_t *declared_pc)
{
    char needle[256];
    snprintf(needle, sizeof(needle), "%s::%s", cls, meth);
    size_t nlen = strlen(needle);

    static const char *segs[] = { "__TEXT", "__DATA", "__DATA_CONST", "__RODATA" };
    for (int i = 0; i < 4; i++) {
        const struct segment_command_64 *sg = seg_find(img.hdr, segs[i]);
        if (!sg) {
            continue;
        }
        uintptr_t hit = seg_scan(sg, img.base - (uintptr_t)img.hdr, needle, nlen);
        if (hit) {
            return hit;
        }
    }
    (void)declared_pc;
    return 0;
}

static uintptr_t find_first_xref(image_ref_t img, uintptr_t str_addr, uintptr_t *out_pc)
{
    static const char *segs[] = { "__TEXT", "__TEXT_EXEC" };

    for (int s = 0; s < 2; s++) {
        const struct segment_command_64 *sg = seg_find(img.hdr, segs[s]);
        if (!sg) {
            continue;
        }
        uintptr_t slide = img.base - (uintptr_t)img.hdr;
        const uint32_t *code = (const uint32_t *)(sg->vmaddr + slide);
        uint64_t nwords = sg->vmsize / 4;

        for (uint64_t i = 0; i + 1 < nwords; i++) {
            uint32_t op = code[i];
            if ((op & 0x9F000000u) != 0x90000000u) {
                continue;
            }
            uint32_t rd = op & 0x1Fu;
            int64_t immhi = (int64_t)((op >> 5) & 0x7FFFF);
            int64_t immlo = (int64_t)((op >> 29) & 0x3);
            int64_t imm = (immhi << 2) | immlo;
            if (imm & (1LL << 20)) {
                imm |= ~((1LL << 21) - 1);
            }
            uintptr_t pc = (uintptr_t)&code[i];
            uintptr_t page = (pc & ~0xFFFULL) + ((uintptr_t)imm << 12);

            uint32_t op2 = code[i + 1];
            if ((op2 & 0xFF800000u) != 0x91000000u) {
                continue;
            }
            if (((op2 >> 5) & 0x1Fu) != rd) {
                continue;
            }
            uint32_t sh = (op2 >> 22) & 0x3u;
            uint32_t imm12 = (op2 >> 10) & 0xFFFu;
            if (sh == 1u) {
                imm12 <<= 12;
            } else if (sh != 0u) {
                continue;
            }
            if (page + imm12 == str_addr) {
                if (out_pc) {
                    *out_pc = pc;
                }
                return pc;
            }
        }
    }
    return 0;
}

static uintptr_t func_start_from_starts(image_ref_t img, uintptr_t pc, uintptr_t *table, size_t n)
{
    uintptr_t best = 0;
    for (size_t i = 0; i < n; i++) {
        if (table[i] <= pc && table[i] > best) {
            best = table[i];
        }
    }
    return best;
}

static inline int arm64_is_prologue(uint32_t w)
{
    if (w == 0xD503233Fu) {
        return 1;
    }
    if ((w & 0xFFC003E0u) == 0xA98003E0u) {
        return 1;
    }
    if ((w & 0xFFC003FFu) == 0xD10003FFu) {
        return 1;
    }
    if ((w & 0xFF8003FFu) == 0x910003FDu) {
        return 1;
    }
    return 0;
}

static inline int arm64_is_boundary(uint32_t w)
{
    return w == 0xD65F03C0u ||
           w == 0xD503201Fu ||
           w == 0xD4200000u;
}

static uintptr_t func_start_by_prologue(image_ref_t img, uintptr_t pc)
{
    static const char *segs[] = { "__TEXT", "__TEXT_EXEC" };
    for (int s = 0; s < 2; s++) {
        const struct segment_command_64 *sg = seg_find(img.hdr, segs[s]);
        if (!sg) {
            continue;
        }
        uintptr_t slide = img.base - (uintptr_t)img.hdr;
        uintptr_t lo = sg->vmaddr + slide;
        uintptr_t hi = lo + sg->vmsize;
        if (pc < lo + 4 || pc >= hi) {
            continue;
        }
        for (uintptr_t p = pc; p >= lo + 4; p -= 4) {
            if (arm64_is_prologue(*(const uint32_t *)p) &&
                arm64_is_boundary(*(const uint32_t *)(p - 4))) {
                return p;
            }
            if (p == lo + 4) {
                break;
            }
        }
    }
    return 0;
}

uintptr_t rt_resolve_method(image_ref_t img, const char *cls, const char *meth,
                           uintptr_t func_starts[], size_t starts_n,
                           uintptr_t *xref_pc_out)
{
    uintptr_t str_addr = rt_find_method_string(img, cls, meth, NULL);
    if (!str_addr) {
        return 0;
    }
    uintptr_t xref = find_first_xref(img, str_addr, xref_pc_out);
    if (!xref) {
        return 0;
    }
    uintptr_t fs = starts_n ? func_start_from_starts(img, xref, func_starts, starts_n)
                            : 0;
    if (!fs) {
        fs = func_start_by_prologue(img, xref);
    }
    return fs;
}