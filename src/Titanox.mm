#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>

static FILE *g_rt_log = NULL;
static long g_rt_log_written = 0;
#define RT_LOG_MAX (100 * 1024)

static void rt_log(const char *fmt, ...) {
    if (!g_rt_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/RtResolve.log"];
        g_rt_log = fopen(p.UTF8String, "a");
    }
    if (!g_rt_log) return;
    if (g_rt_log_written >= RT_LOG_MAX) return;

    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (n <= 0) return;

    fwrite(buf, 1, n, g_rt_log);
    fputc('\n', g_rt_log);
    fflush(g_rt_log);
    g_rt_log_written += n + 1;
}

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
                rt_log("seg_find: %s vmaddr=%p vmsize=0x%llx",
                       name, (void *)sg->vmaddr, sg->vmsize);
                return sg;
            }
        }
        p += lc->cmdsize;
    }
    rt_log("seg_find: %s NOT FOUND", name);
    return NULL;
}

static uintptr_t seg_scan(const struct segment_command_64 *sg, uintptr_t slide,
                          const void *needle, size_t nlen)
{
    const uint8_t *begin = (const uint8_t *)(sg->vmaddr + slide);
    const uint8_t *end = begin + sg->vmsize;
    if (nlen == 0) return 0;

    for (const uint8_t *p = begin; p + nlen <= end; p++) {
        if (p[0] == ((const uint8_t *)needle)[0] && memcmp(p, needle, nlen) == 0) {
            rt_log("seg_scan: found '%.*s' at %p (seg %s)",
                   (int)nlen, (const char *)needle, (void *)p, sg->segname);
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

    rt_log("=== rt_find_method_string: %s ===", needle);

    static const char *segs[] = { "__TEXT", "__DATA", "__DATA_CONST", "__RODATA" };
    for (int i = 0; i < 4; i++) {
        const struct segment_command_64 *sg = seg_find(img.hdr, segs[i]);
        if (!sg) continue;
        uintptr_t hit = seg_scan(sg, img.base - (uintptr_t)img.hdr, needle, nlen);
        if (hit) {
            rt_log("rt_find_method_string: hit=%p in %s", (void *)hit, segs[i]);
            return hit;
        }
    }
    rt_log("rt_find_method_string: '%s' NOT FOUND in any segment", needle);
    (void)declared_pc;
    return 0;
}

static uintptr_t find_first_xref(image_ref_t img, uintptr_t str_addr, uintptr_t *out_pc)
{
    static const char *segs[] = { "__TEXT", "__TEXT_EXEC" };

    rt_log("find_first_xref: searching xref to %p", (void *)str_addr);

    for (int s = 0; s < 2; s++) {
        const struct segment_command_64 *sg = seg_find(img.hdr, segs[s]);
        if (!sg) continue;
        uintptr_t slide = img.base - (uintptr_t)img.hdr;
        const uint32_t *code = (const uint32_t *)(sg->vmaddr + slide);
        uint64_t nwords = sg->vmsize / 4;

        rt_log("find_first_xref: scanning %s, %llu words", segs[s], nwords);

        int hits_logged = 0;
        for (uint64_t i = 0; i + 1 < nwords; i++) {
            uint32_t op = code[i];
            if ((op & 0x9F000000u) != 0x90000000u) continue;

            uint32_t rd = op & 0x1Fu;
            int64_t immhi = (int64_t)((op >> 5) & 0x7FFFF);
            int64_t immlo = (int64_t)((op >> 29) & 0x3);
            int64_t imm = (immhi << 2) | immlo;
            if (imm & (1LL << 20)) imm |= ~((1LL << 21) - 1);

            uintptr_t pc = (uintptr_t)&code[i];
            uintptr_t page = (pc & ~0xFFFULL) + ((uintptr_t)imm << 12);

            uint32_t op2 = code[i + 1];
            if ((op2 & 0xFF800000u) != 0x91000000u) continue;
            if (((op2 >> 5) & 0x1Fu) != rd) continue;

            uint32_t sh = (op2 >> 22) & 0x3u;
            uint32_t imm12 = (op2 >> 10) & 0xFFFu;
            if (sh == 1u) imm12 <<= 12;
            else if (sh != 0u) continue;

            uintptr_t resolved = page + imm12;
            if (resolved == str_addr) {
                rt_log("find_first_xref: HIT at pc=%p (seg %s)", (void *)pc, segs[s]);
                if (out_pc) *out_pc = pc;
                return pc;
            }
            if (resolved > str_addr - 0x200 && resolved < str_addr + 0x200 && hits_logged < 5) {
                rt_log("find_first_xref: near-miss pc=%p resolved=%p (target %p, diff %ld)",
                       (void *)pc, (void *)resolved, (void *)str_addr,
                       (long)(resolved - str_addr));
                hits_logged++;
            }
        }
    }
    rt_log("find_first_xref: NO xref found to %p", (void *)str_addr);
    return 0;
}

static uintptr_t func_start_from_starts(image_ref_t img, uintptr_t pc, uintptr_t *table, size_t n)
{
    uintptr_t best = 0;
    for (size_t i = 0; i < n; i++) {
        if (table[i] <= pc && table[i] > best) best = table[i];
    }
    if (best) rt_log("func_start_from_starts: pc=%p -> start=%p", (void *)pc, (void *)best);
    else rt_log("func_start_from_starts: no match for pc=%p", (void *)pc);
    return best;
}

static inline int arm64_is_prologue(uint32_t w)
{
    if (w == 0xD503233Fu) return 1;
    if ((w & 0xFFC003E0u) == 0xA98003E0u) return 1;
    if ((w & 0xFFC003FFu) == 0xD10003FFu) return 1;
    if ((w & 0xFF8003FFu) == 0x910003FDu) return 1;
    return 0;
}

static inline int arm64_is_boundary(uint32_t w)
{
    return w == 0xD65F03C0u || w == 0xD503201Fu || w == 0xD4200000u;
}

static uintptr_t func_start_by_prologue(image_ref_t img, uintptr_t pc)
{
    static const char *segs[] = { "__TEXT", "__TEXT_EXEC" };
    rt_log("func_start_by_prologue: pc=%p", (void *)pc);

    for (int s = 0; s < 2; s++) {
        const struct segment_command_64 *sg = seg_find(img.hdr, segs[s]);
        if (!sg) continue;
        uintptr_t slide = img.base - (uintptr_t)img.hdr;
        uintptr_t lo = sg->vmaddr + slide;
        uintptr_t hi = lo + sg->vmsize;
        if (pc < lo + 4 || pc >= hi) continue;

        int steps = 0;
        for (uintptr_t p = pc; p >= lo + 4; p -= 4) {
            uint32_t w = *(const uint32_t *)p;
            steps++;
            if (steps > 4096) {
                rt_log("func_start_by_prologue: gave up after 4096 steps (pc=%p)", (void *)pc);
                break;
            }
            if (arm64_is_prologue(w) && arm64_is_boundary(*(const uint32_t *)(p - 4))) {
                rt_log("func_start_by_prologue: found start=%p (steps=%d, seg=%s)",
                       (void *)p, steps, segs[s]);
                return p;
            }
            if (p == lo + 4) break;
        }
        rt_log("func_start_by_prologue: no prologue found in %s", segs[s]);
    }
    rt_log("func_start_by_prologue: FAILED for pc=%p", (void *)pc);
    return 0;
}

uintptr_t rt_resolve_method(image_ref_t img, const char *cls, const char *meth,
                           uintptr_t func_starts[], size_t starts_n,
                           uintptr_t *xref_pc_out)
{
    rt_log("=== rt_resolve_method: %s::%s ===", cls, meth);

    uintptr_t str_addr = rt_find_method_string(img, cls, meth, NULL);
    if (!str_addr) {
        rt_log("rt_resolve_method: string not found");
        return 0;
    }
    rt_log("rt_resolve_method: string at %p", (void *)str_addr);

    uintptr_t xref = find_first_xref(img, str_addr, xref_pc_out);
    if (!xref) {
        rt_log("rt_resolve_method: xref not found");
        return 0;
    }
    rt_log("rt_resolve_method: xref at %p", (void *)xref);

    uintptr_t fs = starts_n ? func_start_from_starts(img, xref, func_starts, starts_n) : 0;
    if (!fs) {
        rt_log("rt_resolve_method: fallback to prologue scan");
        fs = func_start_by_prologue(img, xref);
    }

    if (fs) rt_log("rt_resolve_method: RESOLVED %s::%s -> %p", cls, meth, (void *)fs);
    else rt_log("rt_resolve_method: FAILED to resolve %s::%s", cls, meth);

    return fs;
}