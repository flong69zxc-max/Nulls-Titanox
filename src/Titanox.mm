#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <libgen.h>
#import "libtitanox.h"
#import "offsets.h"

static uintptr_t g_base = 0;
static char g_base_path[512] = {0};
static uintptr_t g_recv_target = 0;
static uintptr_t g_stage_target = 0;
static volatile int g_recv_hits = 0;
static volatile int g_stage_hits = 0;
static FILE *g_log = NULL;

typedef void (*recv_fn)(void *, void *, void *, void *, void *, void *);
static recv_fn g_orig_recv = NULL;

static void log_line(NSString *s) {
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Diag.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (!g_log) return;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    if (d.length) {
        fwrite(d.bytes, 1, d.length, g_log);
        fputc('\n', g_log);
        fflush(g_log);
    }
}

static NSString *hex4(uint32_t v) {
    return [NSString stringWithFormat:@"%08x", v];
}

static NSString *decode_arm64(uint32_t op) {
    if (op == 0x00000000) return @"ZERO";
    if ((op & 0xFC000000) == 0x94000000) return @"BL";
    if ((op & 0xFC000000) == 0x14000000) return @"B";
    if ((op & 0x9F000000) == 0x90000000) return @"ADRP";
    if ((op & 0xFFFFFC1F) == 0xD65F0000) return @"RET";
    if ((op & 0xFFC00000) == 0xA9BF0000) return @"STP-pre";
    if ((op & 0xFFC00000) == 0xA9000000) return @"STP-post";
    if ((op & 0xFFC00000) == 0xF9000000) return @"STR";
    if ((op & 0xFFC00000) == 0xB9000000) return @"STR-w";
    if ((op & 0xFF800000) == 0xD1000000) return @"SUB-sp";
    if ((op & 0xFF000000) == 0x71000000) return @"SUBS";
    if ((op & 0xFF000000) == 0xAA000000) return @"ORR/MOV";
    if ((op & 0xFFE00000) == 0x52800000) return @"MOVZ";
    if ((op & 0xFFE00000) == 0x72800000) return @"MOVK";
    if ((op & 0xFF000000) == 0x91000000) return @"ADD";
    return @"?";
}

static BOOL find_game_image(uintptr_t *out_base, char *out_path, size_t cap) {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *path = _dyld_get_image_name(i);
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!path || !hdr || hdr->magic != MH_MAGIC_64) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "LiveContainer")) continue;
        if (strstr(path, "TweakLoader")) continue;
        if (strstr(path, "CydiaSubstrate")) continue;
        if (strstr(path, "libellekit")) continue;

        NSString *ns = [NSString stringWithUTF8String:path];
        if (![ns containsString:@".app/"]) continue;

        *out_base = (uintptr_t)hdr;
        strncpy(out_path, path, cap - 1);
        return YES;
    }
    return NO;
}

static uint32_t read_u32(uintptr_t addr) {
    if (!addr) return 0;
    return *(volatile uint32_t *)addr;
}

static BOOL rva_in_exec_seg(uintptr_t base, uint64_t rva, char *seg_name, size_t cap) {
    const struct mach_header_64 *hdr = (const struct mach_header_64 *)base;
    uint32_t nc = hdr->ncmds > 1024 ? 1024 : hdr->ncmds;
    const struct load_command *cmd =
        (const struct load_command *)((const uint8_t *)hdr + sizeof(struct mach_header_64));

    for (uint32_t c = 0; c < nc; c++) {
        if (cmd->cmdsize < sizeof(struct load_command)) break;
        if (cmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)cmd;
            uint64_t seg_off = rva - 0; // rva считается от __TEXT vmaddr
            if ((seg->initprot & VM_PROT_EXECUTE) &&
                seg_off >= seg->vmaddr &&
                seg_off < seg->vmaddr + seg->vmsize) {
                if (seg_name && cap) {
                    strncpy(seg_name, seg->segname, cap - 1);
                }
                return YES;
            }
        }
        cmd = (const struct load_command *)((const uint8_t *)cmd + cmd->cmdsize);
    }
    return NO;
}

static NSString *probe_rva(uintptr_t base, const char *name, uint64_t rva) {
    NSMutableString *s = [NSMutableString string];
    uintptr_t addr = base + rva;

    [s appendFormat:@"%-32s rva=0x%-8llx abs=%p", name, rva, (void *)addr];

    char seg[32] = {0};
    BOOL inExec = rva_in_exec_seg(base, rva, seg, sizeof(seg));
    [s appendFormat:@"  exec=%s", inExec ? "YES" : "NO"];
    if (inExec) [s appendFormat:@" seg=%s", seg];

    uint32_t op0 = read_u32(addr);
    uint32_t op1 = read_u32(addr + 4);
    uint32_t op2 = read_u32(addr + 8);
    uint32_t op3 = read_u32(addr + 12);

    [s appendFormat:@"\n    ops: %@ %@ %@ %@",
     hex4(op0), hex4(op1), hex4(op2), hex4(op3)];

    [s appendFormat:@"\n    dec: %@ / %@ / %@ / %@",
     decode_arm64(op0), decode_arm64(op1),
     decode_arm64(op2), decode_arm64(op3)];

    if (op0 == 0x00000000) {
        [s appendString:@"\n    VERDICT: BAD (zero) — RVA указывает в пустоту"];
    } else if (!inExec) {
        [s appendString:@"\n    VERDICT: BAD (not in exec) — RVA не в .text"];
    } else if ((op0 & 0xFC000000) == 0x14000000) {
        [s appendString:@"\n    VERDICT: thunk (B) — не сама функция, а стаб"];
    } else if ((op0 & 0xFC000000) == 0x94000000) {
        [s appendString:@"\n    VERDICT: thunk (BL) — не сама функция"];
    } else if ((op0 & 0xFFC00000) == 0xA9BF0000 ||
               (op0 & 0xFFC00000) == 0xA9000000 ||
               (op0 & 0xFF800000) == 0xD1000000) {
        [s appendString:@"\n    VERDICT: OK — похоже на пролог функции"];
    } else {
        [s appendString:@"\n    VERDICT: SUSPECT — нестандартный пролог"];
    }

    return s;
}

static void recv_hook(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_recv_hits++;
    if (g_recv_hits <= 10) {
        log_line([NSString stringWithFormat:@"RECV #%d msg=%p", g_recv_hits, msg]);
    }
    if (g_orig_recv) {
        brk_suspend_self();
        g_orig_recv(self, msg, a, b, c, d);
        brk_resume_self();
    }
}

static void stage_hook(void *self, void *a2, void *a3, void *a4) {
    g_stage_hits++;
    if (g_stage_hits <= 5 || (g_stage_hits % 300 == 0)) {
        log_line([NSString stringWithFormat:@"STAGE #%d", g_stage_hits]);
    }
}

static void run_diag(void) {
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:@"=== diag ===\n"];
    [out appendFormat:@"slots=%d selftest=%d\n",
     brk_slot_limit(), brk_selftest()];

    if (!find_game_image(&g_base, g_base_path, sizeof(g_base_path))) {
        log_line(@"game image not found");
        return;
    }

    [out appendFormat:@"game base=%p\n", (void *)g_base];
    [out appendFormat:@"game path=%s\n", g_base_path];
    [out appendFormat:@"\n"];

    struct { const char *name; uint64_t rva; } probes[] = {
        {"MessageManager::receiveMessage", RVA_MESSAGEMANAGER_RECEIVEMESSAGE},
        {"MessageManager::ctor",           RVA_MESSAGEMANAGER_CTOR},
        {"GameButton::ctor",               RVA_GAMEBUTTON_CTOR},
        {"Character::ctor",                RVA_CHARACTER_CTOR},
        {"Stage::setViewport",             RVA_STAGE_SETVIEWPORT},
        {"Stage::ctor",                    RVA_STAGE_CTOR},
        {"HomePage::ctor",                 RVA_HOMEPAGE_CTOR},
        {"MovieClip::ctor",                RVA_MOVIECLIP_CTOR},
        {"NativeFont::ctor",               RVA_NATIVEFONT_CTOR},
        {"NativeFont::formatString",       RVA_NATIVEFONT_FORMATSTRING},
        {"LogicDataTables::ctor",          RVA_LOGICDATATABLES_CTOR},
        {"LogicDataTables::initDataTable", RVA_LOGICDATATABLES_INITDATATABLE},
        {"LogicProjectileData::ctor",      RVA_LOGICPROJECTILEDATA_CTOR},
        {NULL, 0}
    };

    for (int i = 0; probes[i].name; i++) {
        [out appendFormat:@"%@\n", probe_rva(g_base, probes[i].name, probes[i].rva)];
        [out appendString:@"\n"];
    }

    g_recv_target = g_base + RVA_MESSAGEMANAGER_RECEIVEMESSAGE;
    g_stage_target = g_base + RVA_STAGE_SETVIEWPORT;

    g_orig_recv = (recv_fn)brk_original_ptr((void *)g_recv_target);

    BOOL r1 = brk_install((void *)g_recv_target, (void *)&recv_hook);
    BOOL r2 = brk_install((void *)g_stage_target, (void *)&stage_hook);

    [out appendFormat:@"install recv=%d stage=%d\n", r1, r2];
    [out appendFormat:@"recv target=%p\n", (void *)g_recv_target];
    [out appendFormat:@"stage target=%p\n", (void *)g_stage_target];
    [out appendString:@"\nwatch counters: STAGE должен расти сразу, RECV — при пакетах"];

    log_line(out);
}

static UIViewController *top_vc(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindow *w = ((UIWindowScene *)scene).keyWindow;
        if (w.rootViewController) return w.rootViewController;
    }
    return nil;
}

static void show_alert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = top_vc();
        if (!root) return;

        NSString *msg = [NSString stringWithFormat:
            @"base: %p\npath: %s\n\nrecv: %p\nstage: %p\n\n"
            @"recv hits: %d\nstage hits: %d\n\n"
            @"full log: Documents/Diag.log",
            (void *)g_base, basename(g_base_path),
            (void *)g_recv_target, (void *)g_stage_target,
            g_recv_hits, g_stage_hits];

        UIAlertController *a = [UIAlertController
            alertControllerWithTitle:@"Titanox diag" message:msg
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:a animated:YES completion:nil];
    });
}

__attribute__((constructor))
static void start(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        run_diag();
        show_alert();
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}