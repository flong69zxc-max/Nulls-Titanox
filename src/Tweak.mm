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

// Оффсет функции receiveMessage из offsets.h
#define RVA_MM_RECEIVEMESSAGE 0x75cce0

// Номера BRK, которые использует игра и которые ждёт JIT-энabler
#define BRK_GAME_INTERNAL  0x81f   // внутренняя проверка игры (из твоего лога)
#define BRK_JIT_UNIVERSAL  0xf00d  // универсальный JIT-триггер StikDebug
#define BRK_JIT_LEGACY     0x69    // старый JIT-триггер (UTM/Dolphin)

static FILE *g_logf = NULL;

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

// Определяем тип BRK по номеру
static const char* brkName(uint32_t imm) {
    switch (imm) {
        case BRK_GAME_INTERNAL:  return "BRK_GAME_INTERNAL (0x81f)";
        case BRK_JIT_UNIVERSAL:  return "BRK_JIT_UNIVERSAL (0xf00d)";
        case BRK_JIT_LEGACY:     return "BRK_JIT_LEGACY (0x69)";
        default:                 return "BRK_UNKNOWN";
    }
}

// Читаем инструкцию по адресу
static uint32_t readInsn(uint64_t addr) {
    vm_size_t size = 0;
    uint32_t insn = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)addr, 4, (vm_address_t)&insn, &size);
    return (kr == KERN_SUCCESS && size == 4) ? insn : 0;
}

// Проверяем, является ли инструкция BRK, и получаем номер
static BOOL isBrk(uint32_t insn, uint32_t *immOut) {
    // ARM64 BRK: 1101 0100 001 imm16
    if ((insn & 0xFFE0001F) == 0xD4200000) {
        *immOut = (insn >> 5) & 0xFFFF;
        return YES;
    }
    return NO;
}

// Находим и патчим все BRK #0x81f на BRK #0xf00d в указанном регионе
static int patchBrkInstructions(uint64_t startAddr, uint64_t endAddr) {
    int count = 0;
    for (uint64_t addr = startAddr; addr < endAddr; addr += 4) {
        uint32_t insn = readInsn(addr);
        uint32_t imm = 0;
        if (isBrk(insn, &imm) && imm == BRK_GAME_INTERNAL) {
            // Заменяем 0x81f на 0xf00d
            // BRK #imm16 в ARM64: 0xD4200000 | (imm16 << 5)
            uint32_t newInsn = 0xD4200000 | (BRK_JIT_UNIVERSAL << 5);
            kern_return_t kr = vm_write(mach_task_self(), (vm_address_t)addr, (vm_offset_t)&newInsn, 4);
            if (kr == KERN_SUCCESS) {
                count++;
                TaleLog("[BRKPatch] Patched BRK at 0x%llx: 0x%08x -> 0x%08x (imm %u -> %u)",
                        addr, insn, newInsn, imm, BRK_JIT_UNIVERSAL);
            } else {
                TaleLog("[BRKPatch] Failed to patch at 0x%llx: kr=0x%x", addr, kr);
            }
        }
    }
    return count;
}

// Ищем секцию __text в главном образе игры
static void patchGameBrk(void) {
    TaleLog("[BRKPatch] === Scanning for BRK #0x%x ===", BRK_GAME_INTERNAL);

    // Находим образ игры
    const char *target = "Nulls Brawl";
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (strcmp(basename((char *)n), target) != 0) continue;

        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;

        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        uint64_t base = (uint64_t)hdr;

        TaleLog("[BRKPatch] Found image at base=0x%llx slide=0x%lx", base, (long)slide);

        // Проходим по всем load-командам в поисках __TEXT
        const struct load_command *lc = (const struct load_command *)((uint8_t *)hdr + sizeof(struct mach_header_64));
        for (uint32_t j = 0; j < hdr->ncmds; j++) {
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
                if (strcmp(seg->segname, "__TEXT") == 0) {
                    uint64_t segStart = base + seg->vmaddr - 0x100000000ULL;
                    uint64_t segEnd = segStart + seg->vmsize;
                    TaleLog("[BRKPatch] __TEXT: 0x%llx - 0x%llx", segStart, segEnd);

                    int patched = patchBrkInstructions(segStart, segEnd);
                    TaleLog("[BRKPatch] Total patched: %d", patched);
                    return;
                }
            }
            lc = (const struct load_command *)((uint8_t *)lc + lc->cmdsize);
        }
    }
    TaleLog("[BRKPatch] Game image not found");
}

// Перехват исключений BRK (альтернативный путь, если патчинг не сработал)
static void installBrkHandler(void) {
    // Этот путь сложнее и требует Mach exception port
    // Пока оставим только патчинг
    TaleLog("[BRKHandler] BRK handler not implemented (use patching instead)");
}

__attribute__((constructor))
static void tweak_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        TaleLog("[TaleMod] init");
        TaleLog("[TaleMod] BRK JIT Helper v1.0");
        TaleLog("[TaleMod] Target: patch BRK #0x%x -> BRK #0x%x", BRK_GAME_INTERNAL, BRK_JIT_UNIVERSAL);

        // Патчим BRK-инструкции в игре
        patchGameBrk();

        // Устанавливаем обработчик (на будущее)
        installBrkHandler();

        TaleLog("[TaleMod] === done ===");
        TaleLog("[TaleMod] Теперь запусти StikDebug и нажми Enable JIT");
    });
}