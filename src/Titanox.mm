#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/arm/thread_status.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <unistd.h>
#import <libgen.h>
#import <ptrauth.h>
#import "mach_excServer.h"
#import "libtitanox.h"
#import "offsets.h"

#define BCR_ON 0x1e5ULL
#define LOG_MAX_BYTES (100 * 1024)

static uintptr_t g_base = 0;
static char g_path[512] = {0};
static FILE *g_log = NULL;
static long g_log_written = 0;

static uintptr_t g_stage_real = 0;
static uintptr_t g_recv_real = 0;
static uintptr_t g_ldt_init_real = 0;
static uintptr_t g_char_ctor_real = 0;
static uintptr_t g_font_fmt_real = 0;
static uintptr_t g_mc_ctor_real = 0;

static volatile int g_hits_stage = 0;
static volatile int g_hits_recv = 0;
static volatile int g_hits_ldt_init = 0;
static volatile int g_hits_char_ctor = 0;
static volatile int g_hits_font_fmt = 0;
static volatile int g_hits_mc_ctor = 0;

static mach_port_t g_orig_bp_port = MACH_PORT_NULL;
static mach_port_t g_my_bp_port = MACH_PORT_NULL;

typedef struct {
    uintptr_t target;
    uintptr_t replacement;
} bp_entry_t;

static bp_entry_t g_entries[6];
static int g_entry_count = 0;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

static void log_line(NSString *s);

static uintptr_t decode_bl(uintptr_t thunk_addr, uint32_t opcode) {
    if ((opcode & 0xFC000000) != 0x94000000) return 0;
    int32_t imm26 = opcode & 0x03FFFFFF;
    int64_t offset = (int64_t)(imm26 << 2);
    if (offset & (1LL << 27)) offset |= ~((1LL << 28) - 1);
    return (uintptr_t)((int64_t)thunk_addr + offset);
}

static uintptr_t resolve_thunk(uintptr_t base, uint64_t rva, const char *name) {
    uintptr_t thunk = base + rva;
    uint32_t op2 = *(volatile uint32_t *)(thunk + 8);
    uintptr_t real = decode_bl(thunk + 8, op2);
    if (real) {
        log_line([NSString stringWithFormat:@"%s thunk=%p real=%p",
                  name, (void *)thunk, (void *)real]);
        return real;
    }
    log_line([NSString stringWithFormat:@"%s rva=0x%llx not a thunk", name, rva]);
    return thunk;
}

static void log_line(NSString *s) {
    if (!g_log) {
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Titanox.log"];
        g_log = fopen(p.UTF8String, "a");
    }
    if (!g_log) return;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    if (!d.length) return;
    if (g_log_written >= LOG_MAX_BYTES) return;
    fwrite(d.bytes, 1, d.length, g_log);
    fputc('\n', g_log);
    fflush(g_log);
    g_log_written += (long)d.length + 1;
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

// --- Обработчик исключений ---

static uintptr_t lookup_target(uintptr_t pc) {
    pthread_mutex_lock(&g_lock);
    for (int i = 0; i < g_entry_count; i++) {
        if (g_entries[i].target == pc) {
            uintptr_t repl = g_entries[i].replacement;
            pthread_mutex_unlock(&g_lock);
            return repl;
        }
    }
    pthread_mutex_unlock(&g_lock);
    return 0;
}

kern_return_t catch_mach_exception_raise_state(
    mach_port_t exception_port, exception_type_t exception,
    const mach_exception_data_t code, mach_msg_type_number_t codeCnt,
    int *flavor, const thread_state_t old_state,
    mach_msg_type_number_t old_stateCnt, thread_state_t new_state,
    mach_msg_type_number_t *new_stateCnt) {

    arm_thread_state64_t *old = (arm_thread_state64_t *)old_state;
    arm_thread_state64_t *new = (arm_thread_state64_t *)new_state;

    uint64_t pc = arm_thread_state64_get_pc(*old);
    uintptr_t repl = lookup_target((uintptr_t)pc);

    if (repl) {
        *new = *old;
        *new_stateCnt = old_stateCnt;
        arm_thread_state64_set_pc_fptr(*new, (void *)repl);
        return KERN_SUCCESS;
    }

    // Неизвестный breakpoint — форвардим в оригинальный порт
    if (g_orig_bp_port != MACH_PORT_NULL) {
        return mach_msg_server(mach_exc_server,
                               sizeof(union __RequestUnion__catch_mach_exc_subsystem),
                               g_orig_bp_port, MACH_MSG_OPTION_NONE);
    }
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise(
    mach_port_t exception_port, mach_port_t thread, mach_port_t task,
    exception_type_t exception, mach_exception_data_t code,
    mach_msg_type_number_t codeCnt) {
    (void)exception_port; (void)thread; (void)task; (void)exception;
    (void)code; (void)codeCnt;
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise_state_identity(
    mach_port_t exception_port, mach_port_t thread, mach_port_t task,
    exception_type_t exception, mach_exception_data_t code,
    mach_msg_type_number_t codeCnt, int *flavor,
    thread_state_t old_state, mach_msg_type_number_t old_stateCnt,
    thread_state_t new_state, mach_msg_type_number_t *new_stateCnt) {
    (void)exception_port; (void)thread; (void)task; (void)exception;
    (void)code; (void)codeCnt; (void)flavor; (void)old_state;
    (void)old_stateCnt; (void)new_state; (void)new_stateCnt;
    return KERN_FAILURE;
}

static void *exception_thread(void *unused) {
    (void)unused;
    mach_msg_server(mach_exc_server,
                    sizeof(union __RequestUnion__catch_mach_exc_subsystem),
                    g_my_bp_port, MACH_MSG_OPTION_NONE);
    return NULL;
}

static void setup_exception_port(void) {
    // Сохраняем оригинальный порт
    mach_port_t ports[EXC_TYPES_COUNT];
    mach_msg_type_number_t cnt = EXC_TYPES_COUNT;
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    memset(ports, 0, sizeof(ports));

    if (task_get_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT,
                                 masks, &cnt, ports, behaviors, flavors) == KERN_SUCCESS
        && cnt > 0) {
        g_orig_bp_port = ports[0];
        log_line([NSString stringWithFormat:@"original bp port=%u", g_orig_bp_port]);
    }

    // Создаём свой порт
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &g_my_bp_port);
    mach_port_insert_right(mach_task_self(), g_my_bp_port, g_my_bp_port,
                           MACH_MSG_TYPE_MAKE_SEND);

    // Перехватываем порт
    task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, g_my_bp_port,
                             EXCEPTION_STATE | MACH_EXCEPTION_CODES,
                             ARM_THREAD_STATE64);

    // Запускаем обработчик
    pthread_t th;
    pthread_create(&th, NULL, exception_thread, NULL);
    pthread_detach(th);

    log_line(@"exception port captured");
}

static void manual_arm(void) {
    task_t task = mach_task_self();
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(task, &threads, &count) != KERN_SUCCESS) return;

    int ok = 0, fail = 0;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        arm_debug_state64_t st;
        mach_msg_type_number_t cnt = ARM_DEBUG_STATE64_COUNT;
        memset(&st, 0, sizeof(st));

        int slot = 0;
        uintptr_t targets[6] = {
            g_stage_real, g_recv_real, g_ldt_init_real,
            g_char_ctor_real, g_font_fmt_real, g_mc_ctor_real
        };
        for (int s = 0; s < 6 && slot < 6; s++) {
            if (targets[s]) {
                st.__bvr[slot] = targets[s];
                st.__bcr[slot] = (uint32_t)BCR_ON;
                slot++;
            }
        }

        kern_return_t kr = thread_set_state(threads[i], ARM_DEBUG_STATE64,
                                            (thread_state_t)&st, cnt);
        if (kr == KERN_SUCCESS) ok++;
        else fail++;

        mach_port_deallocate(task, threads[i]);
    }
    vm_deallocate(task, (vm_address_t)threads, count * sizeof(thread_act_t));

    if (ok + fail > 0) {
        // Не логируем каждый раз, только при изменении
        static int last_ok = -1;
        if (ok != last_ok) {
            log_line([NSString stringWithFormat:@"armed ok=%d fail=%d", ok, fail]);
            last_ok = ok;
        }
    }
}

// --- Хуки ---

static void h_stage(void *a, void *b, void *c, void *d) {
    g_hits_stage++;
    log_line([NSString stringWithFormat:@"STAGE #%d self=%p", g_hits_stage, a]);
}
static void h_ldt_init(void *a, int b, void *c) {
    g_hits_ldt_init++;
    log_line([NSString stringWithFormat:@"LDT_INIT #%d idx=%d", g_hits_ldt_init, b]);
}
static void h_char_ctor(void *a, void *b, void *c, void *d) {
    g_hits_char_ctor++;
    log_line([NSString stringWithFormat:@"CHAR #%d self=%p", g_hits_char_ctor, a]);
}
static void h_font_fmt(void *a, void *b, void *c) {
    g_hits_font_fmt++;
    log_line([NSString stringWithFormat:@"FMT #%d self=%p", g_hits_font_fmt, a]);
}
static void h_mc_ctor(void *a, void *b) {
    g_hits_mc_ctor++;
    log_line([NSString stringWithFormat:@"MC #%d self=%p", g_hits_mc_ctor, a]);
}
static void h_recv(void *self, void *msg, void *a, void *b, void *c, void *d) {
    g_hits_recv++;
    uint32_t msgId = 0;
    if (msg) memcpy(&msgId, msg, 4);
    log_line([NSString stringWithFormat:@"RECV #%d msg=%p id=0x%x",
              g_hits_recv, msg, msgId]);
}

static void add_entry(uintptr_t target, uintptr_t replacement) {
    if (g_entry_count >= 6) return;
    pthread_mutex_lock(&g_lock);
    g_entries[g_entry_count].target = target;
    g_entries[g_entry_count].replacement = replacement;
    g_entry_count++;
    pthread_mutex_unlock(&g_lock);
}

static void setup(void) {
    log_line(@"=== setup ===");
    log_line([NSString stringWithFormat:@"slots=%d selftest=%d",
              brk_slot_limit(), brk_selftest()]);

    if (!find_game_image(&g_base, g_path, sizeof(g_path))) {
        log_line(@"game not found");
        return;
    }
    log_line([NSString stringWithFormat:@"base=%p path=%s", (void *)g_base, g_path]);

    // Перехватываем порт исключений
    setup_exception_port();

    g_stage_real     = resolve_thunk(g_base, RVA_STAGE_SETVIEWPORT, "stage");
    g_recv_real      = resolve_thunk(g_base, RVA_MESSAGEMANAGER_RECEIVEMESSAGE, "recv");
    g_ldt_init_real  = resolve_thunk(g_base, RVA_LOGICDATATABLES_INITDATATABLE, "ldt_init");
    g_char_ctor_real = resolve_thunk(g_base, RVA_CHARACTER_CTOR, "char_ctor");
    g_font_fmt_real  = resolve_thunk(g_base, RVA_NATIVEFONT_FORMATSTRING, "font_fmt");
    g_mc_ctor_real   = resolve_thunk(g_base, RVA_MOVIECLIP_CTOR, "mc_ctor");

    add_entry(g_stage_real, (uintptr_t)&h_stage);
    add_entry(g_recv_real, (uintptr_t)&h_recv);
    add_entry(g_ldt_init_real, (uintptr_t)&h_ldt_init);
    add_entry(g_char_ctor_real, (uintptr_t)&h_char_ctor);
    add_entry(g_font_fmt_real, (uintptr_t)&h_font_fmt);
    add_entry(g_mc_ctor_real, (uintptr_t)&h_mc_ctor);

    manual_arm();
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
            @"stage:    %d\nrecv:     %d\nldt_init: %d\nchar:     %d\nfmt:      %d\nmc:       %d\n\n"
            @"log: Documents/Titanox.log",
            g_hits_stage, g_hits_recv, g_hits_ldt_init,
            g_hits_char_ctor, g_hits_font_fmt, g_hits_mc_ctor];

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
        setup();
        [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *t) {
            manual_arm();
        }];
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
            show_alert();
        }];
    });
}