#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libgen.h>
#import <string.h>
#import <stdio.h>
#import <stdarg.h>

#define RVA_MM_RECEIVEMESSAGE 0x75cce0

#define BRK_GAME_INTERNAL  0x81f
#define BRK_JIT_UNIVERSAL  0xf00d
#define BRK_JIT_LEGACY     0x69

static FILE *g_logf = NULL;

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    NSLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static void TaleLogOpen(void) {
    if (g_logf) return;
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"talemod.log"];
    g_logf = fopen(path.UTF8String, "w");
}

static void TaleLog(const char *fmt, ...) {
    if (!g_logf) TaleLogOpen();
    if (!g_logf) return;
    va_list ap; va_start(ap, fmt); vfprintf(g_logf, fmt, ap); fputc('\n', g_logf); va_end(ap); fflush(g_logf);
}

static uint32_t readInsn(uint64_t addr) {
    vm_size_t size = 0;
    uint32_t insn = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)addr, 4, (vm_address_t)&insn, &size);
    return (kr == KERN_SUCCESS && size == 4) ? insn : 0;
}

static BOOL isBrk(uint32_t insn, uint32_t *immOut) {
    if ((insn & 0xFFE0001F) == 0xD4200000) {
        *immOut = (insn >> 5) & 0xFFFF;
        return YES;
    }
    return NO;
}

static int patchBrkInRange(uint64_t startAddr, uint64_t endAddr) {
    int count = 0;
    uint64_t addr = startAddr;
    while (addr + 4 <= endAddr) {
        uint32_t insn = readInsn(addr);
        uint32_t imm = 0;
        if (isBrk(insn, &imm) && imm == BRK_GAME_INTERNAL) {
            uint32_t newInsn = 0xD4200000 | (BRK_JIT_UNIVERSAL << 5);
            kern_return_t kr = vm_write(mach_task_self(), (vm_address_t)addr, (vm_offset_t)&newInsn, 4);
            if (kr == KERN_SUCCESS) {
                count++;
                TaleLog("[BRKPatch] 0x%llx: 0x%08x -> 0x%08x (imm %u -> %u)",
                        addr, insn, newInsn, imm, BRK_JIT_UNIVERSAL);
            } else {
                TaleLog("[BRKPatch] FAIL 0x%llx kr=0x%x", addr, kr);
            }
        }
        addr += 4;
    }
    return count;
}

static void patchGameBrk(void) {
    TaleLog("[BRKPatch] === scan BRK #0x%x ===", BRK_GAME_INTERNAL);
    const char *target = "Nulls Brawl";
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (strcmp(basename((char *)n), target) != 0) continue;

        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;

        uint64_t base = (uint64_t)hdr;
        TaleLog("[BRKPatch] image base=0x%llx", base);

        const struct load_command *lc = (const struct load_command *)((uint8_t *)hdr + sizeof(struct mach_header_64));
        for (uint32_t j = 0; j < hdr->ncmds; j++) {
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
                if (strcmp(seg->segname, "__TEXT") == 0) {
                    uint64_t segStart = base + (seg->vmaddr - 0x100000000ULL);
                    uint64_t segEnd = segStart + seg->vmsize;
                    TaleLog("[BRKPatch] __TEXT 0x%llx - 0x%llx", segStart, segEnd);
                    int patched = patchBrkInRange(segStart, segEnd);
                    TaleLog("[BRKPatch] total patched=%d", patched);
                    return;
                }
            }
            lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
        }
    }
    TaleLog("[BRKPatch] game image not found");
}

__attribute__((constructor))
static void tweak_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        TaleLog("[TaleMod] init");
        TaleLog("[TaleMod] BRK JIT Helper v1.0");
        patchGameBrk();
        TaleLog("[TaleMod] === done ===");
    });
}