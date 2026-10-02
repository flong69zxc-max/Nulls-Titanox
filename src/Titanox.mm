#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import <stdarg.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import "offsets.h"
#import "lc_detect.h"

/* The engine's hook library is compiled into this tweak (see the Makefile). brk_install
   first tries an inline code patch and, when __TEXT cannot be written, falls back to
   rewriting every pointer slot that holds the target address -- which is exactly what a
   C++ vtable entry in __DATA_CONST is. A virtual method can therefore be intercepted
   even though the text segment is read-only. */
#include "hook.h"

#if __has_include(<ptrauth.h>)
#import <ptrauth.h>
#endif

#define LOG_MAX_BYTES (512 * 1024)
#define OBJC_HOOK_MAX 32
#define WANTED_MAX 4
#define SCAN_MAX 256

#define TNX_RVA_GETTEXTFIELDBYNAME_A 0xc1d7b0ULL
#define TNX_RVA_GETTEXTFIELDBYNAME_B 0xc1d550ULL
#define TNX_RVA_SETTEXT_A 0x990c20ULL
#define TNX_RVA_SETTEXT_B 0xc4a978ULL
#define TNX_RVA_SETXY_A 0xc16b54ULL
#define TNX_RVA_SETXY_B 0xc16b4cULL

#define TNX_LABEL "Titanox v1.0 [Zero-Latency]"
#define TNX_CLIP_FILE "sc/ui.sc"
#define TNX_CLIP_NAME "textbox_1"
#define TNX_CLIP_TEXT "txt"

#define DODGE_RANGE_SQ (1800.0f * 1800.0f)
#define DODGE_THREAT 320.0f
#define DODGE_STEP 600.0f

typedef void (*fn_void_2_t)(void *, void *);
typedef void *(*fn_ptr_2_t)(void *, void *);
typedef void (*fn_settext_t)(void *, void *, int, int);
typedef void (*fn_setxy_t)(void *, float, float);
typedef void (*fn_send_movement_t)(void *, float, float);
typedef void (*fn_set_prediction_t)(void *, int, int);
typedef void *(*fn_get_inst_t)(void);
typedef void *(*fn_get_own_char_t)(void *);
typedef int (*fn_get_team_t)(void *);
typedef int (*fn_get_coord_t)(void *);

typedef struct {
    const char *name;
    uintptr_t rva;
} tnx_rva_entry_t;

static const char *g_image_names[] = {
    "Nulls Brawl",
    "Laser",
    "NB.app",
    NULL
};

static const char *g_probe_classes[] = {
    "MetalView",
    "NullView",
    "AppController",
    NULL
};

static const tnx_rva_entry_t g_rvas[] = {
    { "RVA_BATTLEMODE_GETINSTANCE", RVA_BATTLEMODE_GETINSTANCE },
    { "RVA_BATTLESCREEN__BATTLESCREEN", RVA_BATTLESCREEN__BATTLESCREEN },
    { "RVA_BATTLESCREEN__UPDATEMOVEMENT", RVA_BATTLESCREEN__UPDATEMOVEMENT },
    { "RVA_BATTLESCREEN__UPDATEAUTOSHOOT", RVA_BATTLESCREEN__UPDATEAUTOSHOOT },
    { "RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT", RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT },
    { "RVA_BATTLESCREEN__TRYTOACTIVATESKILL", RVA_BATTLESCREEN__TRYTOACTIVATESKILL },
    { "RVA_LOGICBATTLEMODECLIENT_UPDATE", RVA_LOGICBATTLEMODECLIENT_UPDATE },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER", RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM", RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM },
    { "RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO", RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETDATA", RVA_LOGICGAMEOBJECTCLIENT_GETDATA },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID", RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETX", RVA_LOGICGAMEOBJECTCLIENT_GETX },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETY", RVA_LOGICGAMEOBJECTCLIENT_GETY },
    { "RVA_LOGICPROJECTILEDATA_GETSPEED", RVA_LOGICPROJECTILEDATA_GETSPEED },
    { "RVA_LOGICPROJECTILEDATA_GETRADIUS", RVA_LOGICPROJECTILEDATA_GETRADIUS },
    { "RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR", RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR },
    { "RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION", RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION },
    { "RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT", RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT },
    { "RVA_STAGE_ADDCHILD", RVA_STAGE_ADDCHILD },
    { "RVA_STRINGTABLE_GETMOVIECLIP", RVA_STRINGTABLE_GETMOVIECLIP },
    { "RVA_MOVIECLIP__GETTEXTFIELDBYNAME", RVA_MOVIECLIP__GETTEXTFIELDBYNAME },
    { "RVA_TEXTFIELD_SETTEXT", RVA_TEXTFIELD_SETTEXT },
    { "RVA_DISPLAYOBJECT__SETXY", RVA_DISPLAYOBJECT__SETXY },
    { "RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS", RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS },
    { "RVA_BATTLESCREEN_FIREWRAPPERFN", RVA_BATTLESCREEN_FIREWRAPPERFN },
    { "RVA_BATTLESCREEN_ACTIVATESKILL", RVA_BATTLESCREEN_ACTIVATESKILL },
    { "RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS", RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS },
    { "RVA_MESSAGEMANAGER__RECEIVEMESSAGE", RVA_MESSAGEMANAGER__RECEIVEMESSAGE },
    { "RVA_COMBATHUD__SETMOVESTICKSTATE", RVA_COMBATHUD__SETMOVESTICKSTATE },
    { "RVA_COMBATHUD__SETSHOOTSTICKSTATE", RVA_COMBATHUD__SETSHOOTSTICKSTATE },
    { NULL, 0 }
};

typedef struct {
    __unsafe_unretained Class cls;
    __unsafe_unretained Class wanted[WANTED_MAX];
    int wantedCount;
    SEL sel;
    IMP original;
    IMP replacement;
    const char *selName;
    const char *signature;
    int hits;
    BOOL used;
} tnx_objc_hook_t;

static uintptr_t g_base = 0;
static uintptr_t *g_starts = NULL;
static size_t g_starts_count = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;
static BOOL g_setup_done = NO;
static BOOL g_wm_failed = NO;
static BOOL g_wm_ready = NO;
static BOOL g_aim_rejected = NO;

static __thread BOOL g_inside_hook = NO;

/* Corrected against a working implementation of the same game (sonREvenge/REvengeBS,
   Brawl Stars v68.250): BattleMode_objectManagerPtr = 0x28, ObjectManager_objectsArray = 0x0,
   ObjectManager_count = 0xc, ObjectManager_ptrStride = 8. The manager slot is 0x28, not 0x20 --
   the 0x20 came from one disassembled code path and never matched a real battle container. */
#define TNX_MODE_MANAGER_OFF 0x28ULL
#define TNX_MGR_ARRAY_OFF 0x0ULL
#define TNX_MGR_COUNT_OFF 0xcULL

/* The input queue the working implementation hands its dodge to: BattleMode_clientInputManager
   = 0x58, and a ClientInput carries x at 0xc and y at 0x10. Nothing is written here yet; the
   pointer is printed on capture so the movement side has a target to aim at next. */
#define TNX_MODE_INPUTMGR_OFF 0x58ULL
#define TNX_INPUT_X_OFF 0xcULL
#define TNX_INPUT_Y_OFF 0x10ULL

/* A battle manager holds several live objects; every lobby container observed so far
   held 0 or 1. Used by the vtable-free manager probe. */
#define TNX_MANAGER_MIN_OBJECTS 3
#define TNX_MANAGER_PROBE_LIMIT 2048
#define TNX_OBJ_GLOBALID_OFF 0x8ULL

/* THE correction that matters. REvengeBS: GameObj_team = 0x40, LogicGameObjectClient_ownerIndex
   = 0x3c, GameObj_deadFlag = 0xd0. We read team at 0x4c, which is why every "is this a game
   object" shape test failed and why the one container that was accepted had 71 entries all
   reading team 0 -- we were reading a different field entirely.

   Widths, taken from the working implementation rather than guessed: team is read as a plain
   int at +0x40 and compared against the own-player team, ownerIndex is an int, and DEADFLAG IS
   A SINGLE BYTE -- the reference reads it as uint8_t. Reading it as an int was our own
   invention and would have accepted garbage; a byte that must be 0 or 1 is a real filter. */
#define TNX_OBJ_TEAM_OFF 0x40ULL
#define TNX_OBJ_OWNERINDEX_OFF 0x3cULL
#define TNX_OBJ_DEADFLAG_OFF 0xd0ULL

/* The reference never bounds team: it compares it to the own-player team and moves on. Teams in
   this game are small, so a wide sanity bound is kept -- the real filter is the dead flag, which
   has to be a 0/1 byte. */
#define TNX_OBJ_TEAM_MAX 7

/* getX/getY/getZ are consecutive virtual slots: REvengeBS has them at 0xb5e44c / 0xb5e454 /
   0xb5e45c, i.e. 8 apart, and our own call site does ldr x8,[x8,#0x88] before blr. So slot
   0x88 = getX, 0x90 = getY, 0x98 = getZ, and coordinates are int32 (fixed point). */
#define TNX_OBJ_GETX_SLOT 0x88ULL
#define TNX_OBJ_GETY_SLOT 0x90ULL
#define TNX_MODE_MODEVAR_OFF 0x124ULL
#define TNX_MODE_STARS0_OFF 0x1e8ULL
#define TNX_MODE_STARS1_OFF 0x1ecULL
#define TNX_MODE_SLOT_A 0x218ULL
#define TNX_MODE_SLOT_B 0x220ULL
#define TNX_MODE_SLOT_C 0x228ULL

/* The virtual methods intercepted for battle capture. Every one of them was identified from
   the binary itself, not from the offsets table, and every one is reachable ONLY through a
   vtable slot -- 0 direct bl callers anywhere in the 16 MB of code, so a pointer-slot hook
   catches 100% of their invocations. Each ends in a bare epilogue that writes neither x0
   nor s0 (verified with capstone), hence the forwarding replacement is ABI safe.

     class A = vtable RVA 0x1002548 (only vtable whose method calls addGameObject):
       0xad4ed0  slot 10, byte RVA 0x1002598. Walks [this+0x80] with count [this+0x8c],
                 creates each object and pushes it with
                 ldr x8,[this+8]; ldr x0,[x8]; mov x1,obj; bl addGameObject   (0xa278a8)
                 => the manager is [[this+0x8]+0x0].
       0xad521c  slot  7, byte RVA 0x1002580. Small bool getter (w0), no arguments.

     class B = vtable RVA 0xff5720:
       0xa2e5b8  slot  5, byte RVA 0xff5748. Entry increments [this+0x2e8], i.e. a per-update
                 counter, and the body reads [this+0x20] and [this+0xf4]
                 => the manager is [this+0x20].
       0xa2d250  slot  3, byte RVA 0xff5738. Walks a collection (subs/b.ne loop).
       0xa2d6ac  slot  7, byte RVA 0xff5758. Stashes a vector into [this+0x38].

   The slot byte addresses are listed because the 2026-10-02 05:52 device log confirmed them
   to the byte: a probe reported 0x1075e6598 = base+0x1002598 and 0x1075d9748 = base+0xff5748. */

/* Slot A's object reaches the manager as [[this+0x8]+0x0]; its source list is [this+0x80]
   with count [this+0x8c]. Slot B's object uses the familiar [this+0x20] path. Both
   layouts are printed on capture so neither has to be guessed again. */
#define TNX_SLOT_BRIDGE_OFF 0x8ULL
#define TNX_SLOT_LIST_OFF 0x80ULL
#define TNX_SLOT_LISTCOUNT_OFF 0x8cULL

/* Printed as the first line after "setup", so every log identifies the build that produced
   it. Two device logs were once spent comparing a new binary against an old one. */
#define TNX_BUILD_TAG "titanox_34"

/* IN-LINE HOOKING IS IMPOSSIBLE ON THIS PROCESS -- measured, not assumed. The 17:38 log caught
   it directly:

       rwx 0x1081f4000..0x1081fc000 kr=0                  <- vm_protect(R|W|X) returned SUCCESS
       [hook] install: target 0x1081f78a8 not executable (prot=3)

   prot=3 is READ|WRITE: the kernel accepted the call but granted WRITE only and silently
   dropped EXECUTE, and EXECUTE can never be added back to a writable page (every attempt
   returns kr=2). A page here is therefore writable or executable, never both:

     - patching live code needs a writable code page, and that page then stops executing, so
       the process dies: arming the page holding addGameObject crashed the 17:38 run while it
       was still loading, at 50%; arming all 971 __text pages killed the 17:30 run outright.
     - a trampoline in a data page needs an executable data page, which cannot exist.
     - the engine's own mmap fallback hits the same wall, and says so: its trampoline page
       ends up "cur=rw- ... executable=0" after "exec: vm_protect RX failed kr=2".

   v32 therefore touches no code page at all: code patching is off and the in-line target is
   gone. The pointer-slot hooks stay, because those write to __DATA_CONST -- data -- and the
   readback already showed they hold. The open question remains the one the C2 control was
   built for: whether a rewritten vtable entry is ever dispatched to. */

/* Arming the WHOLE __text as RWX kills the process: the 17:32 run ends right after
   "slot hooks: codePatch=1 flag=1 ..." and before the arming line itself could be printed,
   with no crash report at all -- which is what an integrity kill looks like, not a fault.
   Arming eight pages at a time (the 17:28 run) was survivable, so the footprint has to stay
   small and precise.

   The engine's cave finder wants a run of zeros or NOPs inside __text, so the only pages that
   can ever host the trampoline are the pages that CONTAIN such a run. Those are found here at
   runtime rather than from the file, because the two differ: the file holds method-list data
   at byte RVA 0xdcea48 where the 05:52 run had zeros. Each such page is armed on its own and
   logged, so even a truncated log shows exactly how far this got. */
#define TNX_CAVE_MIN_RUN 96
#define TNX_CAVE_PAGE_LIMIT 64

/* The whole __text region, pre-armed READ|WRITE|EXECUTE before the first install. The engine's
   trampoline cave finder searches this region and its choice is NOT stable between runs: byte
   RVA 0xdcea48 on the 05:52 / 16:31 / 16:59 / 17:19 runs, but 0xd73648 on the 17:28 run -- and
   the engine keeps the address it found first, so arming a fixed window around one of them is
   useless. Arming the whole region is not, and the early-out in hook_page_writable() then
   makes every cave and every patched prologue writable without EXECUTE ever being dropped. */
#define TNX_TEXT_RVA_LO 0x4000ULL
#define TNX_TEXT_RVA_SIZE 0xf70000U

/* Inline (non-virtual) hook target. LogicGameObjectManager::addGameObject is non-virtual: it
   has no vtable slot at all, so a pointer-slot hook can never reach it. It is called only
   when the battle creates game objects, so patching its prologue once catches all 38 of its
   direct bl callers and hands us the manager in x0 and the new object in x1 -- both a battle
   oracle and the object graph, from a single patch. The address was confirmed independently
   by its own assert string "LogicGameObjectManager::addGameObject(null)" via tools/strmap.py. */
#define TNX_RVA_ADDGAMEOBJECT 0x00a278a8ULL
#define TNX_AG_OBJECT_MAX 16

/* The engine's trampoline cave finder walks __TEXT from the start and has landed on byte RVA
   0xdcea48 on every run so far, so that window is pre-armed as well. */
#define TNX_RVA_CAVE_WINDOW 0x00dc0000ULL
#define TNX_CAVE_WINDOW_SIZE 0x10000U

/* The per-attempt global segment scan walks 2 MB and then probes every candidate pointer in
   it. On the device that made one tick take ~4 s, which is why the game felt stuck and the
   run never got to a battle. Only one attempt in this many does the expensive work; the slot
   hooks, which cost nothing, cover the time in between. */
#define TNX_VOTESCAN_GLOBAL_EVERY 10

/* A real battle manager holds several DIFFERENT classes -- brawlers, projectiles, walls --
   while the static container that produced the last false positive held 71 objects of one
   single class. Type diversity is therefore what raises a candidate to score 2. */
#define TNX_MODE_MIN_TYPES 2
#define TNX_MODE_TYPE_MAX 16

#define TNX_SNAPSHOT_OBJECTS 12
#define TNX_SNAPSHOT_BYTES 0x140
#define TNX_SNAPSHOT_DELAY 1.2
#define TNX_VOTESCAN_INTERVAL 1.0
#define TNX_VOTESCAN_ATTEMPTS 600

/* Bytes per heap pass. The pass is not allowed to grow (it runs on the render thread),
   so coverage of the whole address space comes from starting each pass where the
   previous one ran out of budget -- see g_heap_scan_next. */
#define TNX_HEAP_SCAN_BUDGET (512ull * 1024ull * 1024ull)
#define TNX_VOTESCAN_HEAP_EVERY 30

/* A battle is a container holding several live entities. Lobby look-alikes hold 0 or 1.
   This is the anchor now: not a vtable list, but a verifiable battle-shaped structure. */
#define TNX_MODE_MIN_OBJECTS 3
#define TNX_VOTESCAN_HEARTBEAT 30
#define TNX_HEAP_CHUNK (8u * 1024u * 1024u)

/* Engine vtables live in const data. The 35 candidates sit at 0x10012c8-0x1002d18
   inside __DATA_CONST, but the mode family is identified by vtable RVA, not by segment,
   so __DATA is accepted too -- otherwise an object whose table was placed in __DATA is
   dropped before its entry count is ever looked at, and maxObj would lie. */
#define TNX_VTABLE_SEGMENT "__DATA_CONST"
#define TNX_VTABLE_SEGMENT_ALT "__DATA"

/* Vtables verified offline as classes that OWN the game-object manager: a method of
   each one does [this+0x20]->addGameObject(obj), so [this+0x20] is the manager. An
   instance found through one of these is accepted no matter what the layout
   heuristics say -- that is exactly how the layout is going to be learned.
     rva 0x1002548 - 33 slots, methods 0xad4xxx-0xad5xxx, inherits the 0xac14cc base
     rva 0xff5720  - 21 slots, methods 0xa2exxx-0xa31xxx
   The second one is important: it is NOT in the 35-entry heuristic list, so the heap
   scan used to be physically unable to see an object of that class. */
static const uintptr_t g_mode_vtables_verified[] = { 0x1002548, 0xff5720, 0 };

#define TNX_MODE_VTABLE_PRIMARY 0x1002548ULL

static int tnx_verified_vtable(uintptr_t vtable) {
    if (!g_base || vtable <= g_base) return -1;

    uintptr_t rva = vtable - g_base;

    for (int i = 0; g_mode_vtables_verified[i]; i++) {
        if (rva == g_mode_vtables_verified[i]) return i;
    }

    return -1;
}

static uintptr_t g_mode_object = 0;
static BOOL g_mode_strong = NO;
static int g_mode_best_objects = 0;
static int g_mode_last_types = 0;
static int g_mode_verified_hits = 0;
static uintptr_t g_manager_object = 0;
static int g_manager_count = 0;
static int g_manager_probes = 0;
static int g_manager_probes_total = 0;
static int g_manager_best_count = 0;
static int g_manager_best_live = 0;
static int g_heap_passes = 0;
static unsigned long long g_heap_covered = 0;
static uintptr_t g_heap_scan_next = 0;
static int g_scan_sig[2] = { -1, -1 };
static uintptr_t g_mode_source = 0;
static int g_mode_matches = 0;
static BOOL g_mode_scanned = NO;
static int g_mode_relaxed = 0;
static int g_mode_strict_logs = 0;
static int g_mode_near_logs = 0;
static int g_mode_relaxed_logs = 0;
static int g_votescan_attempts = 0;
static double g_votescan_last = 0.0;
static BOOL g_snapshot_first = NO;
static BOOL g_snapshot_second = NO;
static double g_snapshot_start = 0.0;

static tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];
static int g_objc_armed = 0;

static uintptr_t g_addr_getinstance = 0;
static uintptr_t g_addr_getownchar = 0;
static uintptr_t g_addr_getteam = 0;
static uintptr_t g_addr_getx = 0;
static uintptr_t g_addr_gety = 0;
static uintptr_t g_addr_setprediction = 0;
static uintptr_t g_addr_sendmovement = 0;
static uintptr_t g_addr_getclip = 0;
static uintptr_t g_addr_gettf = 0;
static uintptr_t g_addr_settext = 0;
static uintptr_t g_addr_setxy = 0;
static uintptr_t g_addr_addchild = 0;
static uintptr_t g_addr_battlescreen = 0;

static void *g_label_clip = NULL;
static void *g_label_tf = NULL;
static void *g_label_sc = NULL;
static char g_label_text[64] = {0};
static int g_label_updates = 0;

static uintptr_t tnx_strip_imp(IMP imp) {
#if defined(__has_feature)
#if __has_feature(ptrauth_calls)
    return (uintptr_t)ptrauth_strip((void *)imp, ptrauth_key_function_pointer);
#endif
#endif
    return (uintptr_t)imp;
}

static FILE *g_battle_log = NULL;
static BOOL g_battle_capture = NO;
static BOOL g_battle_header = NO;

static void tnx_battle_write(const char *utf8, size_t len) {
    if (!g_battle_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

        if (paths.count == 0) return;

        NSString *path = [paths[0] stringByAppendingPathComponent:@"Titanox.battle.log"];
        g_battle_log = fopen(path.UTF8String, "a");
    }

    if (!g_battle_log) return;

    if (!g_battle_header) {
        g_battle_header = YES;

        const char *header = "---- battle capture started ----\n";
        fwrite(header, 1, strlen(header), g_battle_log);
    }

    fwrite(utf8, 1, len, g_battle_log);
    fflush(g_battle_log);
}

static FILE *tnx_log_handle(void) {
    if (!g_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"Titanox.log"];
            g_log = fopen(logPath.UTF8String, "a");
        }
    }

    return g_log;
}

static void tnx_write_line(const char *text) {
    FILE *handle = tnx_log_handle();

    if (!handle || !text) return;
    if (g_log_written >= LOG_MAX_BYTES) return;

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *ts = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %s\n", ts, text];
    const char *utf8 = line.UTF8String;
    size_t len = strlen(utf8);

    fwrite(utf8, 1, len, handle);
    fflush(handle);

    g_log_written += (long)len;

    /* Second, deliberately tiny file. Every report so far was truncated before the
       battle, so the lines that matter got lost; once the first battle-shaped hit
       appears everything is mirrored here, which keeps this file small enough to
       always be sent whole. */
    if (g_battle_capture && g_log_written < LOG_MAX_BYTES) {
        tnx_battle_write(utf8, len);
    }
}

static void tlog(NSString *msg) {
    if (!msg) return;

    tnx_write_line(msg.UTF8String);
}

static void tnx_logf(const char *format, ...) {
    if (!format) return;

    char buffer[2048];
    va_list args;

    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    tnx_write_line(buffer);
}

/* Mirroring starts here and stays on: from the first battle-shaped hit every line also
   lands in the small Titanox.battle.log. Defined after tnx_logf because it logs. */
static void tnx_battle_begin(const char *why) {
    if (g_battle_capture) return;

    g_battle_capture = YES;

    tnx_logf("battle capture ON (%s) -> Documents/Titanox.battle.log", why ? why : "?");
}

/* ---------------------------------------------------------------------------
   Direct battle-object capture through a vtable pointer slot.

   Five confirmed virtual methods of the two classes that own the game-object manager are
   intercepted through their single __DATA_CONST vtable entry each, so the replacement runs
   on the game's own thread with the battle object in x0. Nothing is scanned on this path.
   A sixth, unrelated slot is hooked as a control (see its entry in g_slot_specs below).

   The hook body is deliberately reduced to two stores -- no logging, no memory reads, no
   file I/O -- because it runs on the game's thread. Everything else happens on the 1 Hz
   timer in the slot pump below, so a slow hook can never stall a frame.

   Several slots rather than one, because the guarantee we need is "the object exists and is
   alive", not "this particular method is on the hot path". Slot B1 increments [this+0x2e8]
   on entry, which reads as a per-update counter, and slot B2 walks a collection -- between
   them they should fire for any live battle instance. Two further slots are controls whose
   only job is to answer whether this kind of hook is dispatched to at all.
   --------------------------------------------------------------------------- */

#define TNX_SLOT_COUNT 7

typedef uint64_t (*tnx_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                  uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

static tnx_slot_fn_t g_slot_orig[TNX_SLOT_COUNT] = { NULL };
static uintptr_t g_slot_object[TNX_SLOT_COUNT] = { 0 };
static uint64_t g_slot_hits[TNX_SLOT_COUNT] = { 0 };
static int g_slot_installed[TNX_SLOT_COUNT] = { -1, -1, -1, -1, -1, -1, -1 };
static uint32_t g_slot_reported_mask = 0;
static uintptr_t g_slot_adopted = 0;
static int g_ag_adopted = 0;

static void tnx_slot_diag(const char *why);

/* Defined next to the object dump, but needed earlier by the manager dump too. */
static BOOL tnx_obj_coord(uintptr_t object, uintptr_t slot, int32_t *value);

/* Runs inside the game's thread. Two stores and a bounds check, nothing else. */
static void tnx_slot_note(int index, void *self) {
    if (!self) return;
    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_object[index]) g_slot_object[index] = (uintptr_t)self;
}

/* One replacement per slot: a rewritten vtable entry cannot tell which slot invoked it, so
   each target gets its own tiny forwarder. All five were checked offline to return void or
   a plain integer in w0/x0 and to take no floating-point arguments, which is what makes
   forwarding the eight incoming integer registers safe. */
static uint64_t tnx_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(0, a0);

    if (g_slot_orig[0]) return g_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(1, a0);

    if (g_slot_orig[1]) return g_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(2, a0);

    if (g_slot_orig[2]) return g_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(3, a0);

    if (g_slot_orig[3]) return g_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(4, a0);

    if (g_slot_orig[4]) return g_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(5, a0);

    if (g_slot_orig[5]) return g_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(6, a0);

    if (g_slot_orig[6]) return g_slot_orig[6](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

/* slotRva is the byte address of the single rewritten entry inside the vtable, relative to the
   image. It is only filled in where the device log has confirmed the exact address; the
   readback in the diagnostics needs it, and a slot that silently reverted would make every
   other number in the log meaningless. */
static const struct {
    const char *tag;
    const char *shortTag;
    uintptr_t rva;
    uintptr_t slotRva;
    tnx_slot_fn_t replacement;
    int control;
} g_slot_specs[TNX_SLOT_COUNT] = {
    /* class A: vtable 0x1002548, manager reached as [[this+0x8]+0x0] */
    { "A1/vt1002548+10/ad4ed0", "A1", 0x00ad4ed0ULL, 0x01002598ULL, tnx_slot_repl_0, 0 },
    { "A2/vt1002548+07/ad521c", "A2", 0x00ad521cULL, 0x01002580ULL, tnx_slot_repl_1, 0 },
    /* class B: vtable 0xff5720, manager reached as [this+0x20]. B2 and B3 each resolved to
       SEVEN slots, i.e. seven sibling vtables around 0xff5xxx share them, so those two hooks
       cover a whole family of derived classes, not one class. */
    { "B1/vt0ff5720+05/a2e5b8", "B1", 0x00a2e5b8ULL, 0x00ff5748ULL, tnx_slot_repl_2, 0 },
    { "B2/vt0ff5720+03/a2d250", "B2", 0x00a2d250ULL, 0x00ff5738ULL, tnx_slot_repl_3, 0 },
    { "B3/vt0ff5720+07/a2d6ac", "B3", 0x00a2d6acULL, 0x00ff5758ULL, tnx_slot_repl_4, 0 },
    /* CONTROLS, never adopted.
       C1 Stage::addChild is the only anchor resolved out of the offsets table that turned out
       to be virtual at all (one vtable slot, byte RVA 0x1011f50). C2 is a flag getter that
       occupies offset 0x88 of 443 vtables, i.e. a base-class virtual that the logic must call
       constantly. C1 stayed at zero for ten minutes on 2026-10-02 16:59, which proves nothing
       about the mechanism because that method is only called when display objects are added.
       C2 exists so the question "is a rewritten pointer slot ever dispatched to at all" gets a
       real answer. Both return an integer or void and never touch s0/q0. */
    { "C1/Stage::addChild @c33690", "C1", 0x00c33690ULL, 0x01011f50ULL, tnx_slot_repl_5, 1 },
    { "C2/hotflag @b9dc24", "C2", 0x00b9dc24ULL, 0, tnx_slot_repl_6, 1 },
};

/* Installs one slot hook. The dry-run probe runs first: it reports whether a writable slot
   really holds this address, so a failed install is a logged fact rather than a silent one.
   The original address is kept so the forwarders can call it; nothing is ever patched in
   place, so the original code bytes stay untouched. */
/* ---------------------------------------------------------------------------
   In-line hook on a NON-VIRTUAL function, with EXECUTE kept the whole time.
   --------------------------------------------------------------------------- */

static tnx_slot_fn_t g_ag_orig = NULL;
static int g_ag_installed = -1;
static uint64_t g_ag_hits = 0;
static uintptr_t g_ag_manager = 0;
static uintptr_t g_ag_objects[TNX_AG_OBJECT_MAX] = { 0 };
static int g_ag_objectCount = 0;

/* Adds WRITE without giving up EXECUTE. Dropping EXECUTE cannot be undone on this process
   (mprotect back to r-x returns kr=2), which is precisely why the engine's own writable step
   is a dead end; adding WRITE to a page whose maxprot already allows it succeeds. */
static void tnx_make_rwx(uintptr_t address, size_t length) {
    uintptr_t page = address & ~(uintptr_t)0x3fff;
    uintptr_t last = (address + length + 0x3fff) & ~(uintptr_t)0x3fff;
    kern_return_t result = vm_protect(mach_task_self(), (vm_address_t)page,
                                      (vm_size_t)(last - page), FALSE,
                                      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    tnx_logf("rwx %p..%p kr=%d", (void *)page, (void *)last, (int)result);
}

/* Arms only the pages of __text that could host the trampoline cave: the ones holding a run of
   at least TNX_CAVE_MIN_RUN bytes that are all zero or all NOP. Page-local detection is enough
   because the first byte of the run -- where the engine would put the cave -- lies inside the
   page that reports it. Every page is logged before it is armed, so a truncated log still
   shows how far this got. */
static int tnx_arm_cave_pages(void) {
    static uint8_t buffer[0x4000];
    uintptr_t first = g_base + TNX_TEXT_RVA_LO;
    uintptr_t last = first + TNX_TEXT_RVA_SIZE;
    int armed = 0;

    for (uintptr_t page = first; page + 0x4000 <= last; page += 0x4000) {
        vm_size_t got = 0;
        int best = 0;
        int run = 0;

        if (armed >= TNX_CAVE_PAGE_LIMIT) break;

        if (vm_read_overwrite(mach_task_self(), (vm_address_t)page, 0x4000,
                              (vm_address_t)buffer, &got) != KERN_SUCCESS) continue;

        if (got != 0x4000) continue;

        for (int i = 0; i + 4 <= 0x4000; i += 4) {
            uint32_t word = (uint32_t)buffer[i] | ((uint32_t)buffer[i + 1] << 8) |
                            ((uint32_t)buffer[i + 2] << 16) | ((uint32_t)buffer[i + 3] << 24);

            if (word == 0x00000000 || word == 0xd503201f) {
                run += 4;

                if (run > best) best = run;
            } else {
                run = 0;
            }
        }

        if (best < TNX_CAVE_MIN_RUN) continue;

        tnx_logf("cave page rva=%#llx run=%d", (unsigned long long)(page - g_base), best);

        tnx_make_rwx(page, 0x4000);

        armed++;
    }

    tnx_logf("cave pages armed=%d of limit=%d", armed, TNX_CAVE_PAGE_LIMIT);

    return armed;
}

/* Runs on the game's thread: record only, never log or read memory here. */
static uint64_t tnx_ag_repl(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                            uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    g_ag_hits++;

    if (a0 && !g_ag_manager) g_ag_manager = (uintptr_t)a0;

    if (a1 && g_ag_objectCount < TNX_AG_OBJECT_MAX) {
        uintptr_t object = (uintptr_t)a1;
        BOOL known = NO;

        for (int i = 0; i < g_ag_objectCount; i++) {
            if (g_ag_objects[i] == object) {
                known = YES;
                break;
            }
        }

        if (!known) g_ag_objects[g_ag_objectCount++] = object;
    }

    if (g_ag_orig) return g_ag_orig(a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

/* Pre-arms the pages as RWX, then lets the engine patch in line: it finds a trampoline cave,
   writes the trampoline, and redirects the prologue. brk_original_ptr then returns that
   trampoline, which is the only way to reach the original body of an in-line hook. */
static void tnx_inline_install(uintptr_t rva, const char *tag, void *replacement,
                               tnx_slot_fn_t *original, int *status) {
    uintptr_t target = g_base + rva;

    *status = 0;

    if (!target) return;

    tnx_make_rwx(target, 0x4000);
    tnx_make_rwx(g_base + TNX_RVA_CAVE_WINDOW, TNX_CAVE_WINDOW_SIZE);

    if (!brk_install((void *)target, replacement)) {
        tnx_logf("inline %s: install failed target=%p (%s)", tag, (void *)target,
                 hook_last_error() ? hook_last_error() : "-");

        return;
    }

    *original = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    *status = 1;

    tnx_logf("inline %s: installed target=%p trampoline=%p", tag, (void *)target,
             (void *)*original);
}

static void tnx_slot_install_one(int index) {
    uintptr_t target = 0;
    int slots = 0;

    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_installed[index] = 0;

    target = g_base + g_slot_specs[index].rva;

    if (!target) return;

    slots = hook_probe(target);

    if (slots <= 0) {
        tnx_logf("slot %s: no writable slot holds %p (%s)", g_slot_specs[index].tag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    if (!brk_install((void *)target, (void *)g_slot_specs[index].replacement)) {
        tnx_logf("slot %s: install failed target=%p (%s)", g_slot_specs[index].tag,
                 (void *)target, hook_last_error() ? hook_last_error() : "-");

        return;
    }

    g_slot_orig[index] = (tnx_slot_fn_t)brk_original_ptr((void *)target);
    g_slot_installed[index] = 1;

    tnx_logf("slot %s: installed target=%p original=%p slots=%d liveSlots=%d",
             g_slot_specs[index].tag, (void *)target, (void *)g_slot_orig[index],
             slots, brk_live_slot_count());
}

/* brk_install first tries an inline trampoline and carves it out of __TEXT. That path
   cannot restore EXECUTE on this process (it reports kr=2 and then "lost EXECUTE"), so it
    leaves a writable, non-executable page behind and writes into whichever section the cave
   finder picked -- on the 2026-10-02 05:52 run that was __TEXT,__objc_methlist.

   v29 turns that around instead of avoiding it. hook_page_writable() starts with

       if (prot & VM_PROT_WRITE) return true;

   so if the page is ALREADY writable the engine never touches the protection itself, and the
    protection it later restores to is the one it found -- ours. That was the theory, and the
   device disproved it: vm_protect(R|W|X) reports success while actually granting READ|WRITE and
   dropping EXECUTE, so "arming" a code page makes it stop executing. See the note by
   TNX_BUILD_TAG. Code patching is switched back OFF and no page of __TEXT is touched: every
   install goes straight to the pointer slot, which writes into __DATA_CONST and is proven to
   hold. The in-line helper and the cave-page arming below are kept only as the record of what
   was tried and measured -- neither is called. */
static void tnx_slot_hooks_install(void) {
    const char *flag = NULL;

    if (!g_base) return;

    setenv("TITANOX_ALLOW_CODE_PATCH", "0", 1);

    flag = getenv("TITANOX_ALLOW_CODE_PATCH");

    tnx_logf("slot hooks: codePatch=%d flag=%s pointerSlots=%d limit=%d live=%d",
             hook_code_patch_allowed() ? 1 : 0, flag ? flag : "-",
             hook_pointer_count(), brk_slot_limit(), brk_live_slot_count());

    for (int i = 0; i < TNX_SLOT_COUNT; i++) tnx_slot_install_one(i);

    /* Read every rewritable slot straight back out of memory: this is what proves the write
       took, separately from whether the game ever calls through it. */
    tnx_slot_diag("install");
}

static BOOL tnx_query_region(uintptr_t address,
                             vm_prot_t *protection,
                             vm_prot_t *maxProtection,
                             mach_vm_size_t *regionSize,
                             uintptr_t *regionStart) {
    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;

    kern_return_t result = vm_region_64(
        mach_task_self(),
        &regionAddress,
        &size,
        VM_REGION_BASIC_INFO_64,
        (vm_region_info_t)&info,
        &infoCount,
        &objectName
    );

    if (objectName != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), objectName);
    }

    if (result != KERN_SUCCESS || size == 0) return NO;
    if ((uintptr_t)regionAddress + (uintptr_t)size <= address) return NO;

    if (protection) *protection = info.protection;
    if (maxProtection) *maxProtection = info.max_protection;
    if (regionSize) *regionSize = (mach_vm_size_t)size;
    if (regionStart) *regionStart = (uintptr_t)regionAddress;

    return YES;
}

static BOOL tnx_addr_writable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if (size == 0 || size > 0x10000000ULL) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;

        uintptr_t next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

static BOOL tnx_read_bytes(uintptr_t address, void *out, size_t length) {
    if (!out || !length) return NO;
    if (!address) return NO;

    vm_size_t got = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)address,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)out,
        &got
    );

    return result == KERN_SUCCESS && got == (vm_size_t)length;
}

static BOOL tnx_pointer_plausible(uintptr_t value) {
    if (value < 0x10000) return NO;
    if (value & 7) return NO;

    return YES;
}

static BOOL tnx_read_u8(uintptr_t address, uint8_t *out) {
    return tnx_read_bytes(address, out, 1);
}

static BOOL tnx_read_i32(uintptr_t address, int32_t *out) {
    if (!out) return NO;
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

static BOOL tnx_read_f32(uintptr_t address, float *out) {
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

static BOOL tnx_read_ptr(uintptr_t address, void **out) {
    if (!out) return NO;
    if (address & 7) return NO;

    return tnx_read_bytes(address, out, sizeof(void *));
}

static void *tnx_read_global_ptr(uintptr_t rva) {
    if (!g_base || !rva) return NULL;

    void *value = NULL;

    if (!tnx_read_ptr(g_base + rva, &value)) return NULL;

    return value;
}

static const char *tnx_prologue_rule(uintptr_t address) {
    uint32_t first = 0;

    if (!tnx_read_u32(address, &first)) return "unreadable";

    if (first == 0xD503233F) return "paciasp";
    if (first == 0xD503237F) return "pacibsp";
    if ((first & 0xFFFFFF1F) == 0xD503241F) return "bti";

    if ((first & 0xFF800000u) == 0xA9800000u && ((first >> 5) & 31u) == 31u) return "stppre";
    if ((first & 0xFF8003FFu) == 0xD10003FFu) return "subsp";

    if (address >= 4) {
        uint32_t previous = 0;
        if (tnx_read_u32(address - 4, &previous) && previous == 0xD65F03C0) return "afterret";
    }

    return "none";
}

static BOOL tnx_looks_like_start(uintptr_t address) {
    const char *rule = tnx_prologue_rule(address);

    if (!rule) return NO;

    return strcmp(rule, "none") != 0 && strcmp(rule, "unreadable") != 0;
}

static size_t tnx_start_index(uintptr_t address, BOOL *exact) {
    size_t index = (size_t)-1;

    if (exact) *exact = NO;
    if (!g_starts || !g_starts_count) return index;

    size_t low = 0;
    size_t high = g_starts_count;

    while (low < high) {
        size_t mid = low + (high - low) / 2;

        if (g_starts[mid] <= address) low = mid + 1;
        else high = mid;
    }

    if (low == 0) return index;

    index = low - 1;

    if (exact) *exact = (g_starts[index] == address);

    return index;
}

static uintptr_t tnx_callable(uintptr_t rva) {
    if (!g_base || !rva) return 0;

    uintptr_t address = g_base + rva;

    if (!tnx_addr_executable(address)) return 0;
    if (!tnx_image_text_contains(g_base, address)) return 0;

    BOOL exact = NO;

    tnx_start_index(address, &exact);

    if (exact) return address;
    if (tnx_looks_like_start(address)) return address;

    return 0;
}

static uintptr_t tnx_pick(uintptr_t rvaA, uintptr_t rvaB) {
    uintptr_t a = tnx_callable(rvaA);
    if (a) return a;

    return tnx_callable(rvaB);
}

static void tnx_log_words(uintptr_t address, uint32_t *out, size_t count) {
    if (!out || !count) return;

    size_t bytes = count * sizeof(uint32_t);

    if (!tnx_read_bytes(address, out, bytes)) {
        memset(out, 0, bytes);
        return;
    }
}

static uintptr_t tnx_linkedit(uintptr_t fileOffset, uint64_t size) {
    if (!g_base) return 0;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return 0;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return 0;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return 0;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return 0;
        if (cursor + command->cmdsize > limit) return 0;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__LINKEDIT") == 0) {
                if (fileOffset < segment->fileoff) return 0;

                uint64_t delta = (uint64_t)fileOffset - segment->fileoff;

                if (delta > segment->filesize) return 0;
                if (size > segment->filesize - delta) return 0;
                if (delta > segment->vmsize) return 0;
                if (size > segment->vmsize - delta) return 0;

                return slide + (uintptr_t)segment->vmaddr + (uintptr_t)delta;
            }
        }

        cursor += command->cmdsize;
    }

    return 0;
}

static BOOL tnx_read_uleb(const uint8_t *bytes, size_t size, size_t *offset, uint64_t *value) {
    if (!bytes || !offset || !value) return NO;

    *value = 0;

    for (unsigned shift = 0; shift <= 63; shift += 7) {
        if (*offset >= size) return NO;

        uint8_t byte = bytes[(*offset)++];
        uint64_t payload = byte & 0x7f;

        if (shift == 63 && payload > 1) return NO;

        *value |= payload << shift;

        if (!(byte & 0x80)) return YES;
    }

    return NO;
}

static BOOL tnx_copy(uintptr_t source, void *destination, size_t length) {
    if (!source || !destination || !length) return NO;
    if (!tnx_addr_readable(source, length)) return NO;

    vm_size_t copied = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)source,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)destination,
        &copied
    );

    return result == KERN_SUCCESS && copied == (vm_size_t)length;
}

static BOOL tnx_text_section(uintptr_t *address, uint64_t *size) {
    if (!g_base) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__TEXT") == 0) {
                uint64_t room = (uint64_t)command->cmdsize - sizeof(struct segment_command_64);
                uint64_t count = room / sizeof(struct section_64);

                if (count > segment->nsects) count = segment->nsects;

                const struct section_64 *sections = (const struct section_64 *)(segment + 1);

                for (uint64_t s = 0; s < count; s++) {
                    if (strcmp(sections[s].sectname, "__text") != 0) continue;
                    if (!sections[s].size) continue;

                    if (address) *address = slide + (uintptr_t)sections[s].addr;
                    if (size) *size = sections[s].size;

                    return YES;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static BOOL tnx_start_word(uint32_t word) {
    if (word == 0xD503233F || word == 0xD503237F) return YES;
    if ((word & 0xFFFFFF1Fu) == 0xD503241Fu) return YES;
    if ((word & 0xFF800000u) == 0xA9800000u && ((word >> 5) & 31u) == 31u) return YES;
    if ((word & 0xFF8003FFu) == 0xD10003FFu) return YES;

    return NO;
}

static BOOL tnx_start_boundary(const uint8_t *bytes, size_t offset) {
    if (offset < 4) return NO;

    for (size_t back = 4, seen = 0; back <= offset && seen < 8; back += 4, seen++) {
        uint32_t word = 0;

        memcpy(&word, bytes + offset - back, 4);

        if (word == 0xD65F03C0) return YES;

        if (word == 0xD503201F) continue;
        if ((word & 0xFFFFFF1Fu) == 0xD503241Fu) continue;

        return NO;
    }

    return NO;
}

static void tnx_load_function_starts(void) {
    if (g_starts || !g_base) return;

    uintptr_t textAddress = 0;
    uint64_t textSize = 0;

    if (!tnx_text_section(&textAddress, &textSize)) {
        tnx_logf("starts no text section");
        return;
    }

    if (textSize < 64 || textSize > (64ull * 1024ull * 1024ull)) {
        tnx_logf("starts bad text size=%llu", (unsigned long long)textSize);
        return;
    }

    uint8_t *bytes = (uint8_t *)malloc((size_t)textSize);

    if (!bytes) {
        tnx_logf("starts alloc failed size=%llu", (unsigned long long)textSize);
        return;
    }

    if (!tnx_copy(textAddress, bytes, (size_t)textSize)) {
        free(bytes);
        tnx_logf("starts read failed");
        return;
    }

    size_t capacity = 32768;
    uintptr_t *starts = (uintptr_t *)malloc(capacity * sizeof(uintptr_t));

    if (!starts) {
        free(bytes);
        return;
    }

    size_t count = 0;

    for (size_t offset = 4; offset + 4 <= (size_t)textSize; offset += 4) {
        uint32_t word = 0;

        memcpy(&word, bytes + offset, 4);

        if (!tnx_start_word(word)) continue;
        if (!tnx_start_boundary(bytes, offset)) continue;

        if (count >= capacity) {
            size_t grown = capacity * 2;
            uintptr_t *larger = (uintptr_t *)realloc(starts, grown * sizeof(uintptr_t));

            if (!larger) break;

            starts = larger;
            capacity = grown;
        }

        starts[count++] = textAddress + offset;
    }

    free(bytes);

    if (!count) {
        free(starts);
        tnx_logf("starts scan empty");
        return;
    }

    g_starts = starts;
    g_starts_count = count;

    tnx_logf("starts scanned=%zu text=%p size=%llu first=%p last=%p",
             count, (void *)textAddress, (unsigned long long)textSize,
             (void *)starts[0], (void *)starts[count - 1]);
}

static BOOL tnx_valid_header(uintptr_t base) {
    if (!base) return NO;
    struct mach_header_64 header;

    if (!tnx_pointer_plausible(base)) return NO;
    if (!tnx_read_bytes(base, &header, sizeof(header))) return NO;

    if (header.magic != MH_MAGIC_64) return NO;
    if (header.ncmds == 0 || header.ncmds > 4096) return NO;
    if (header.sizeofcmds == 0) return NO;
    if (header.sizeofcmds > (4u * 1024u * 1024u)) return NO;
    if (!tnx_image_text_contains(base, base + 0x4000)) return NO;

    return YES;
}

static BOOL find_game_image(uintptr_t *out_base) {
    if (!out_base) return NO;

    uint32_t count = _dyld_image_count();
    if (count > 8192) count = 8192;

    uintptr_t fallback = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        uintptr_t base = (uintptr_t)_dyld_get_image_header(i);

        if (!path || !base) continue;
        if (!strstr(path, ".app/")) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "/usr/lib/")) continue;
        if (strstr(path, ".framework/")) continue;
        if (strstr(path, ".dylib")) continue;
        if (tnx_name_marks_host_runtime(path)) continue;
        if (!tnx_valid_header(base)) continue;

        BOOL matched = NO;

        for (int n = 0; g_image_names[n]; n++) {
            if (strstr(path, g_image_names[n])) {
                matched = YES;
                break;
            }
        }

        if (matched) {
            *out_base = base;
            return YES;
        }

        if (!fallback) fallback = base;
    }

    if (fallback) {
        *out_base = fallback;
        return YES;
    }

    return NO;
}

static void *tnx_sc_string(const char *utf8) {
    if (!utf8) return NULL;

    size_t blen = strlen(utf8);

    uint8_t *buf = (uint8_t *)malloc(16);
    if (!buf) return NULL;

    memset(buf, 0, 16);

    *(uint32_t *)(buf + 0) = (uint32_t)blen;
    *(uint32_t *)(buf + 4) = (uint32_t)blen;

    if (blen > 7) {
        uint8_t *data = (uint8_t *)malloc(blen + 1);
        if (!data) {
            free(buf);
            return NULL;
        }

        memcpy(data, utf8, blen);
        data[blen] = 0;

        *(void **)(buf + 8) = data;
    } else {
        memcpy(buf + 8, utf8, blen);
    }

    return buf;
}

static const char *tnx_skip_compound(const char *p) {
    char open = *p;
    char close = (open == '{') ? '}' : ((open == '(') ? ')' : ']');
    int depth = 0;

    while (*p) {
        if (*p == open) {
            depth++;
        } else if (*p == close) {
            depth--;
            if (depth == 0) {
                p++;
                break;
            }
        }

        p++;
    }

    return p;
}

static int tnx_objc_arg_types(const char *types, char *out, size_t capacity) {
    if (!types || !out || capacity < 8) return -1;

    size_t used = 0;
    const char *p = types;

    while (*p && (used + 1) < capacity) {
        while (*p >= '0' && *p <= '9') p++;
        if (!*p) break;

        char c = *p;

        if (c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V') {
            p++;
            continue;
        }

        if (c == '^') {
            p++;
            if (*p == '{' || *p == '(' || *p == '[') p = tnx_skip_compound(p);
            out[used++] = '^';
            continue;
        }

        if (c == '{' || c == '(' || c == '[') {
            p = tnx_skip_compound(p);
            out[used++] = 'X';
            continue;
        }

        out[used++] = c;
        p++;
    }

    out[used] = 0;

    return (int)used;
}

static BOOL tnx_class_owns_method(Class cls, SEL sel) {
    if (!cls || !sel) return NO;

    unsigned count = 0;
    Method *list = class_copyMethodList(cls, &count);

    if (!list) return NO;

    BOOL found = NO;

    for (unsigned i = 0; i < count; i++) {
        if (method_getName(list[i]) == sel) {
            found = YES;
            break;
        }
    }

    free(list);

    return found;
}

static Class tnx_owner_class(Class cls, SEL sel) {
    if (!cls || !sel) return Nil;

    for (Class c = cls; c; c = class_getSuperclass(c)) {
        if (tnx_class_owns_method(c, sel)) return c;
    }

    return Nil;
}

static tnx_objc_hook_t *tnx_objc_find(id self, SEL _cmd) {
    Class start = object_getClass(self);

    if (!start) return NULL;

    tnx_objc_hook_t *bySelector = NULL;
    int bySelectorCount = 0;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        tnx_objc_hook_t *hook = &g_objc_hooks[i];

        if (!hook->used || hook->sel != _cmd) continue;

        bySelector = hook;
        bySelectorCount++;

        for (Class c = start; c; c = class_getSuperclass(c)) {
            if (c == hook->cls) return hook;
        }
    }

    if (bySelectorCount == 1) return bySelector;

    return NULL;
}

static BOOL tnx_objc_targets(id self, tnx_objc_hook_t *hook) {
    if (!hook || hook->wantedCount <= 0) return NO;

    Class start = object_getClass(self);

    if (!start) return NO;

    for (int i = 0; i < hook->wantedCount; i++) {
        Class wanted = hook->wanted[i];

        if (!wanted) continue;

        for (Class c = start; c; c = class_getSuperclass(c)) {
            if (c == wanted) return YES;
        }
    }

    return NO;
}

static void tnx_objc_add_wanted(tnx_objc_hook_t *hook, Class cls) {
    if (!hook || !cls) return;

    for (int i = 0; i < hook->wantedCount; i++) {
        if (hook->wanted[i] == cls) return;
    }

    if (hook->wantedCount >= WANTED_MAX) return;

    hook->wanted[hook->wantedCount++] = cls;
}

static void tnx_run_autododge(void) {
    if (!g_addr_getinstance || !g_addr_getownchar) return;

    void *battleMode = ((fn_get_inst_t)g_addr_getinstance)();
    if (!tnx_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)g_addr_getownchar)(battleMode);
    if (!tnx_object_plausible(ownChar)) return;

    uint8_t ownDead = 0;
    if (!tnx_read_u8((uintptr_t)ownChar + OFF_GAMEOBJ_DEADFLAG, &ownDead)) return;
    if (ownDead) return;

    int ownX = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(ownChar) : 0;
    int ownY = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(ownChar) : 0;
    int ownTeam = g_addr_getteam ? ((fn_get_team_t)g_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!tnx_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!tnx_read_i32((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0) return;

    if (count > SCAN_MAX) count = SCAN_MAX;
    void *probe = NULL;

    if (!tnx_read_ptr((uintptr_t)objects, &probe)) return;
    if (count > 1 && !tnx_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return;

    float dodgeX = 0.0f;
    float dodgeY = 0.0f;
    BOOL danger = NO;

    for (int i = 0; i < count; i++) {
        void *obj = objects[i];

        if (!obj || obj == ownChar) continue;
        if (!tnx_object_plausible(obj)) continue;

        uint8_t objDead = 0;
        if (!tnx_read_u8((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!tnx_read_i32((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(obj) : 0;
        int ey = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(obj) : 0;

        float dx = (float)(ownX - ex);
        float dy = (float)(ownY - ey);
        float distSq = dx * dx + dy * dy;

        if (distSq > DODGE_RANGE_SQ || distSq < 1.0f) continue;

        float angle = 0.0f;
        if (!tnx_read_f32((uintptr_t)obj + OFF_PROJECTILE_SPAWNANGLE, &angle)) continue;
        if (!isfinite(angle)) continue;

        float vx = cosf(angle);
        float vy = sinf(angle);

        float dot = dx * vx + dy * vy;
        if (dot <= 0.0f) continue;

        float perpDist = fabsf(dx * vy - dy * vx);

        if (perpDist < DODGE_THREAT) {
            float nx = -vy;
            float ny = vx;

            if ((dx * nx + dy * ny) < 0.0f) {
                nx = -nx;
                ny = -ny;
            }

            float weight = 1.0f / (perpDist + 1.0f);
            dodgeX += nx * weight;
            dodgeY += ny * weight;
            danger = YES;
        }
    }

    if (!danger) return;

    float len = sqrtf(dodgeX * dodgeX + dodgeY * dodgeY);
    if (len <= 0.0001f) return;

    dodgeX /= len;
    dodgeY /= len;

    if (g_addr_setprediction) {
        int targetX = ownX + (int)(dodgeX * DODGE_STEP);
        int targetY = ownY + (int)(dodgeY * DODGE_STEP);
        ((fn_set_prediction_t)g_addr_setprediction)(battleMode, targetX, targetY);
    }

    if (!g_addr_sendmovement) return;

    void *inputMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_CLIENTINPUTMANAGER, &inputMgr)) return;
    if (!inputMgr) return;

    ((fn_send_movement_t)g_addr_sendmovement)(inputMgr, dodgeX, dodgeY);
}

static void tnx_run_autoaim(void) {
    if (!g_addr_getinstance || !g_addr_getownchar || !g_addr_battlescreen) return;

    void *battleMode = ((fn_get_inst_t)g_addr_getinstance)();
    if (!tnx_object_plausible(battleMode)) return;

    void *ownChar = ((fn_get_own_char_t)g_addr_getownchar)(battleMode);
    if (!tnx_object_plausible(ownChar)) return;

    int ownX = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(ownChar) : 0;
    int ownY = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(ownChar) : 0;
    int ownTeam = g_addr_getteam ? ((fn_get_team_t)g_addr_getteam)(battleMode) : 0;

    void *objMgr = NULL;
    if (!tnx_read_ptr((uintptr_t)battleMode + OFF_BATTLEMODE_OBJECTMANAGERPTR, &objMgr)) return;
    if (!tnx_object_plausible(objMgr)) return;

    void *rawObjects = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr((uintptr_t)objMgr + OFF_OBJECTMANAGER_OBJECTSARRAY, &rawObjects)) return;
    if (!tnx_read_i32((uintptr_t)objMgr + OFF_OBJECTMANAGER_COUNT, &count)) return;

    void **objects = (void **)rawObjects;

    if (!objects || count <= 0) return;

    if (count > SCAN_MAX) count = SCAN_MAX;
    void *probe = NULL;

    if (!tnx_read_ptr((uintptr_t)objects, &probe)) return;
    if (count > 1 && !tnx_read_ptr((uintptr_t)objects + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return;

    float closestDistSq = 1.0e18f;
    int targetX = 0;
    int targetY = 0;
    BOOL found = NO;

    for (int i = 0; i < count; i++) {
        void *obj = objects[i];

        if (!obj || obj == ownChar) continue;
        if (!tnx_object_plausible(obj)) continue;

        uint8_t objDead = 0;
        if (!tnx_read_u8((uintptr_t)obj + OFF_GAMEOBJ_DEADFLAG, &objDead)) continue;
        if (objDead) continue;

        int32_t team = 0;
        if (!tnx_read_i32((uintptr_t)obj + OFF_GAMEOBJ_TEAM, &team)) continue;
        if (team == ownTeam) continue;

        int ex = g_addr_getx ? ((fn_get_coord_t)g_addr_getx)(obj) : 0;
        int ey = g_addr_gety ? ((fn_get_coord_t)g_addr_gety)(obj) : 0;

        float dx = (float)(ex - ownX);
        float dy = (float)(ey - ownY);
        float distSq = dx * dx + dy * dy;

        if (distSq > 1.0f && distSq < closestDistSq) {
            closestDistSq = distSq;
            targetX = ex;
            targetY = ey;
            found = YES;
        }
    }

    if (!found) return;

    void *screen = NULL;
    if (!tnx_read_ptr(g_addr_battlescreen, &screen)) return;

    if (!tnx_object_plausible(screen)) {
        if (!g_aim_rejected) {
            g_aim_rejected = YES;
            tlog(@"autofire disabled: RVA_BATTLESCREEN__BATTLESCREEN is not a valid instance slot");
        }
        return;
    }

    uintptr_t fireX = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREX;
    uintptr_t fireY = (uintptr_t)screen + OFF_BATTLESCREEN_AUTOFIREY;

    if (!tnx_addr_writable(fireX, 4) || !tnx_addr_writable(fireY, 4)) {
        if (!g_aim_rejected) {
            g_aim_rejected = YES;
            tlog(@"autofire disabled: target offsets are not writable");
        }
        return;
    }

    *(int32_t *)fireX = targetX;
    *(int32_t *)fireY = targetY;
}

/* ---------------------------------------------------------------------------
   On-screen status overlay.

   Every report so far ended 30-90 s after launch, before a battle was covered:
   the log stops being written as soon as the app is no longer in the foreground,
   and the render hook is the only driver we have -- so reading the log always
   costs the exact window we need. A plain UILabel needs no engine offsets, keeps
   working while the game runs, and can simply be photographed mid-battle.
   --------------------------------------------------------------------------- */

static UILabel *g_overlay = NULL;
static double g_overlay_last = 0.0;
static int g_scan_ticks = 0;

static void tnx_overlay_attach(NSString *text) {
    UIWindow *window = nil;

    for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
        if (candidate.isKeyWindow) {
            window = candidate;
            break;
        }
    }

    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;

    if (g_overlay && g_overlay.superview != window) {
        [g_overlay removeFromSuperview];
        g_overlay = nil;
    }

    if (!g_overlay) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 44.0, 520.0, 36.0)];

        label.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightBold];
        label.textColor = [UIColor colorWithRed:1.0 green:0.32 blue:0.32 alpha:1.0];
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
        label.userInteractionEnabled = NO;
        label.numberOfLines = 2;

        g_overlay = label;
    }

    g_overlay.text = text;

    if (!g_overlay.superview) [window addSubview:g_overlay];

    [g_overlay.superview bringSubviewToFront:g_overlay];
}

static void tnx_overlay_update(void) {
    char text[192];
    double now = CFAbsoluteTimeGetCurrent();

    if (now - g_overlay_last < 0.4) return;

    g_overlay_last = now;

    uint64_t slotHits = 0;
    uint64_t slotControl = 0;
    int slotInstalled = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) slotControl += g_slot_hits[i];
        else slotHits += g_slot_hits[i];

        if (g_slot_installed[i] == 1) slotInstalled++;
    }

    /* sl= is the battle-hook hit count / how many hooks installed, ctl= is the control hook:
       these have to be readable on screen, because together they say whether a hook of this
       kind is dispatched to at all and whether a battle object existed. */
    snprintf(text, sizeof(text), "%sTNX %s t=%d a=%d/%d hp=%d\nmx=%d ty=%d sl=%llu/%d ctl=%llu obj=%d",
             g_slot_adopted ? "*** BATTLE FOUND ***\n" : "", TNX_BUILD_TAG,
             g_scan_ticks, g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_mode_best_objects, g_mode_last_types, (unsigned long long)slotHits,
             slotInstalled, (unsigned long long)slotControl, g_mode_object ? 1 : 0);

    NSString *string = [NSString stringWithUTF8String:text];

    dispatch_async(dispatch_get_main_queue(), ^{
        tnx_overlay_attach(string);
    });
}

static dispatch_source_t g_scan_timer = NULL;

/* The scan must not depend on the render hook.

   Every log so far stops ~30 s after launch -- right when a battle starts -- and the
   last line is usually a heap-pass summary, so "nothing grows" could equally mean
   "nothing runs". A plain 1 Hz timer keeps ticking as long as the process is alive,
   independent of which view the engine renders through, and its tick count is shown
   on screen: if t= and a= advance while the game is in a battle, the scan really ran
   and the anchor is what is wrong. If they freeze, the app is gone (crash/suspend) and
   the problem is stability, not offsets. */
static void tnx_render_watermark(void) {
    if (!g_base || g_wm_failed) return;

    if (!g_wm_ready) {
        if (!g_addr_getclip || !g_addr_gettf || !g_addr_settext || !g_addr_setxy || !g_addr_addchild) {
            g_wm_failed = YES;
            tlog(@"watermark disabled: unresolved address");
            return;
        }

        void *stage = tnx_read_global_ptr(OFF_STAGEINSTANCEGLOBALPTR);
        if (!tnx_object_plausible(stage)) return;

        void *scFile = tnx_sc_string(TNX_CLIP_FILE);
        void *scName = tnx_sc_string(TNX_CLIP_NAME);
        void *scText = tnx_sc_string(TNX_CLIP_TEXT);

        if (!scFile || !scName || !scText) return;

        void *clip = ((fn_ptr_2_t)g_addr_getclip)(scFile, scName);
        if (!tnx_object_plausible(clip)) return;

        void *tf = ((fn_ptr_2_t)g_addr_gettf)(clip, scText);
        if (!tnx_object_plausible(tf)) return;

        ((fn_setxy_t)g_addr_setxy)(clip, 60536.0f, 60536.0f);
        ((fn_void_2_t)g_addr_addchild)(stage, clip);

        g_label_clip = clip;
        g_label_tf = tf;
        g_wm_ready = YES;

        tlog([NSString stringWithFormat:@"watermark ready stage=%p clip=%p tf=%p", stage, clip, tf]);
    }

    if (!g_label_clip || !g_label_tf) return;

    if (strcmp(g_label_text, TNX_LABEL) != 0) {
        void *sc = tnx_sc_string(TNX_LABEL);
        if (!sc) return;

        g_label_sc = sc;
        snprintf(g_label_text, sizeof(g_label_text), "%s", TNX_LABEL);
    }

    if (!g_label_sc) return;

    ((fn_settext_t)g_addr_settext)(g_label_tf, g_label_sc, 4, 0);
    g_label_updates++;
}

static void tnx_locate_battle_mode(void);
static void tnx_slot_pump(void);

/* Defined here, right after the declaration above, so the call inside the timer block
   is not a use-before-declaration. The scan must not depend on the render hook: every
   log so far stops ~30 s after launch -- right when a battle starts -- and its last
   line is usually a heap-pass summary, so "nothing grows" could equally mean "nothing
   runs". A 1 Hz timer keeps ticking as long as the process is alive, whatever view the
   engine renders through, and its tick count is printed on screen: if t= and a= advance
   during a battle then the scan really ran and the anchor is what is wrong; if they
   freeze, the app is gone (crash or suspend) and the problem is stability, not offsets. */
static void tnx_start_timer(void) {
    if (g_scan_timer) return;

    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    if (!timer) return;

    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);

    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval),
                              interval, (uint64_t)(0.25 * NSEC_PER_SEC));

    dispatch_source_set_event_handler(timer, ^{
        tnx_slot_pump();
        tnx_locate_battle_mode();

        g_scan_ticks++;

        tnx_overlay_update();
    });

    dispatch_resume(timer);

    g_scan_timer = timer;

    tnx_logf("scan timer started (1 Hz, render hook no longer drives the scan)");
}
static void tnx_dump_mode_objects(const char *tag);

static void tnx_run_workload(void) {
    tnx_locate_battle_mode();

    if (g_mode_object) {
        if (!g_snapshot_first) {
            g_snapshot_first = YES;
            g_snapshot_start = CFAbsoluteTimeGetCurrent();
            tnx_dump_mode_objects("a");
        } else if (!g_snapshot_second) {
            if (CFAbsoluteTimeGetCurrent() > (g_snapshot_start + TNX_SNAPSHOT_DELAY)) {
                g_snapshot_second = YES;
                tnx_dump_mode_objects("b");
            }
        }
    }

    tnx_run_autododge();
    tnx_run_autoaim();
    tnx_render_watermark();
    tnx_overlay_update();
}

static void tnx_objc_rep0(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook) hook->hits++;

    if (hook && !g_inside_hook && tnx_objc_targets(self, hook)) {
        g_inside_hook = YES;
        tnx_run_workload();
        g_inside_hook = NO;
    }

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL)>(hook->original)(self, _cmd);
    }
}

static void tnx_objc_rep1(id self, SEL _cmd, id a1) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, id)>(hook->original)(self, _cmd, a1);
    }
}

static void tnx_objc_rep1b(id self, SEL _cmd, BOOL a1) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, BOOL)>(hook->original)(self, _cmd, a1);
    }
}

static void tnx_objc_rep2(id self, SEL _cmd, id a1, id a2) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL, id, id)>(hook->original)(self, _cmd, a1, a2);
    }
}

static int tnx_objc_arm(const char *clsName, const char *selName) {
    Class wanted = objc_getClass(clsName);

    if (!wanted) return 0;
    if (!tnx_image_owns_address(g_base, (uintptr_t)wanted)) return 0;

    SEL sel = sel_registerName(selName);

    Class owner = tnx_owner_class(wanted, sel);

    if (!owner) return 0;
    if (!tnx_image_owns_address(g_base, (uintptr_t)owner)) return 0;

    Method method = class_getInstanceMethod(owner, sel);

    if (!method) return 0;
    if (!sel_isEqual(method_getName(method), sel)) return 0;

    const char *types = method_getTypeEncoding(method);

    if (!types) return 0;

    char args[10];
    int argc = tnx_objc_arg_types(types, args, sizeof(args));

    if (argc < 3) return 0;
    if (args[0] != 'v') return 0;

    IMP replacement = NULL;

    if (argc == 3) {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep0);
    } else if (argc == 4 && args[3] == '@') {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep1);
    } else if (argc == 4 && args[3] == 'B') {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep1b);
    } else if (argc == 5 && args[3] == '@' && args[4] == '@') {
        replacement = reinterpret_cast<IMP>(tnx_objc_rep2);
    } else {
        return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        if (g_objc_hooks[i].cls != owner || g_objc_hooks[i].sel != sel) continue;

        tnx_objc_add_wanted(&g_objc_hooks[i], wanted);
        tlog([NSString stringWithFormat:@"objc hook %s -%s joined via %s", clsName, selName, class_getName(owner)]);
        return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (g_objc_hooks[i].used) continue;

        IMP previous = method_setImplementation(method, replacement);

        if (!previous) return 0;

        if (tnx_strip_imp(previous) == tnx_strip_imp(replacement)) {
            method_setImplementation(method, previous);
            tlog([NSString stringWithFormat:@"objc hook %s -%s rejected: original is self", clsName, selName]);
            return 0;
        }

        g_objc_hooks[i].used = YES;
        g_objc_hooks[i].cls = owner;
        g_objc_hooks[i].sel = sel;
        g_objc_hooks[i].original = previous;
        g_objc_hooks[i].replacement = replacement;
        g_objc_hooks[i].selName = selName;
        g_objc_hooks[i].signature = types;
        g_objc_hooks[i].hits = 0;
        g_objc_hooks[i].wantedCount = 0;

        tnx_objc_add_wanted(&g_objc_hooks[i], wanted);

        g_objc_armed++;

        tlog([NSString stringWithFormat:@"objc hook %s -%s armed via %s sig=%s orig=%p repl=%p",
              clsName, selName, class_getName(owner), types, (void *)previous, (void *)replacement]);

        uintptr_t originalRaw = tnx_strip_imp(previous);

        rt_dump_target(clsName, originalRaw);

        BOOL originalExact = NO;
        size_t originalIndex = tnx_start_index(originalRaw, &originalExact);

        tnx_logf("origCheck %s prologue=%s start=%d index=%d exec=%d text=%d",
                 clsName,
                 tnx_prologue_rule(originalRaw),
                 originalExact ? 1 : 0,
                 originalIndex == (size_t)-1 ? -1 : (int)originalIndex,
                 tnx_addr_executable(originalRaw) ? 1 : 0,
                 tnx_image_text_contains(g_base, originalRaw) ? 1 : 0);

        return 1;
    }

    return 0;
}

static void tnx_resolve_addresses(void) {
    if (!g_base) return;

    g_addr_getinstance = tnx_callable(RVA_BATTLEMODE_GETINSTANCE);
    g_addr_getownchar = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    g_addr_getteam = tnx_callable(RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);
    g_addr_getx = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETX);
    g_addr_gety = tnx_callable(RVA_LOGICGAMEOBJECTCLIENT_GETY);
    g_addr_setprediction = tnx_callable(RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO);
    g_addr_sendmovement = tnx_callable(RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT);
    g_addr_getclip = tnx_callable(RVA_STRINGTABLE_GETMOVIECLIP);
    g_addr_addchild = tnx_callable(RVA_STAGE_ADDCHILD);

    g_addr_gettf = tnx_pick(TNX_RVA_GETTEXTFIELDBYNAME_A, TNX_RVA_GETTEXTFIELDBYNAME_B);
    g_addr_settext = tnx_pick(TNX_RVA_SETTEXT_A, TNX_RVA_SETTEXT_B);
    g_addr_setxy = tnx_pick(TNX_RVA_SETXY_A, TNX_RVA_SETXY_B);

    g_addr_battlescreen = g_base + RVA_BATTLESCREEN__BATTLESCREEN;
    if (!tnx_addr_readable(g_addr_battlescreen, sizeof(void *))) g_addr_battlescreen = 0;

    tlog([NSString stringWithFormat:
          @"resolve aim=%d input=%d dodge=%d wm=%d screen=%d",
          (g_addr_getinstance && g_addr_getownchar && g_addr_getx && g_addr_gety && g_addr_getteam) ? 1 : 0,
          g_addr_sendmovement ? 1 : 0,
          g_addr_setprediction ? 1 : 0,
          (g_addr_getclip && g_addr_gettf && g_addr_settext && g_addr_setxy && g_addr_addchild) ? 1 : 0,
          g_addr_battlescreen ? 1 : 0]);
}

static void tnx_dump_rvas(void) {
    if (!g_base) return;

    tnx_logf("rva table image=%p", (void *)g_base);

    for (int i = 0; g_rvas[i].name; i++) {
        uintptr_t address = g_base + g_rvas[i].rva;
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uint32_t words[4] = {0, 0, 0, 0};

        BOOL region = tnx_query_region(address, &protection, NULL, &size, NULL);
        BOOL exact = NO;
        size_t index = tnx_start_index(address, &exact);
        uintptr_t nearest = (index != (size_t)-1) ? g_starts[index] : 0;
        uintptr_t next = (index != (size_t)-1 && (index + 1) < g_starts_count) ? g_starts[index + 1] : 0;
        unsigned long long into = nearest ? (unsigned long long)(address - nearest) : 0;

        tnx_log_words(address, words, 4);

        tnx_logf("rva %-48s off=0x%08llx addr=%p start=%d into=0x%llx near=%p next=%p prologue=%-8s callable=%d prot=%d words=%08x %08x %08x %08x",
                 g_rvas[i].name,
                 (unsigned long long)g_rvas[i].rva,
                 (void *)address,
                 exact ? 1 : 0,
                 into,
                 (void *)nearest,
                 (void *)next,
                 tnx_prologue_rule(address),
                 tnx_callable_target(g_base, address) ? 1 : 0,
                 region ? (int)protection : -1,
                 words[0], words[1], words[2], words[3]);
    }
}

static void tnx_probe_classes(void) {
    SEL sel = sel_registerName("render");

    for (int i = 0; g_probe_classes[i]; i++) {
        Class cls = objc_getClass(g_probe_classes[i]);

        if (!cls) {
            tnx_logf("probe class %-14s missing", g_probe_classes[i]);
            continue;
        }

        Method method = class_getInstanceMethod(cls, sel);
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        Class owner = tnx_owner_class(cls, sel);

        tnx_logf("probe class %-14s inImage=%d owns=%d method=%d owner=%s types=%s",
                 g_probe_classes[i],
                 tnx_image_owns_address(g_base, (uintptr_t)cls) ? 1 : 0,
                 tnx_class_owns_method(cls, sel) ? 1 : 0,
                 method ? 1 : 0,
                 owner ? class_getName(owner) : "-",
                 types ? types : "-");
    }
}

static const tnx_rva_entry_t g_verified[] = {
    { "-[MetalView render]", 0xd5646c },
    { "MessageManager::receiveMessage", 0x75d20c },
    { "LogicGameObjectManager::addGameObject", 0xa278a8 },
    { "LogicGameObjectManager::generateGameObjectGlobalID", 0xa27b98 },
    { "LogicBattleModeClient::getTeamStars", 0xac3cfc },
    { "LogicProjectileData::getColumnValue", 0x9cd5e0 },
    { "LogicBattleModeClient::slotA (this+0x218)", 0xac40d8 },
    { "LogicBattleModeClient::slotB (this+0x220)", 0xac40e8 },
    { "LogicBattleModeClient::slotC (this+0x228)", 0xac40f8 },
    { "LogicBattleModeClient::getInt (this+0xec)", 0xac3500 },
    { "TABLE_RVA_MESSAGEMANAGER__RECEIVEMESSAGE", 0x7bace8 },
    { NULL, 0 }
};

static void tnx_dump_structs(void) {
    tnx_logf("structs mode+0x%llx=manager mgr+0x%llx=array mgr+0x%llx=count obj+0x%llx=gid obj+0x%llx=team mode+0x%llx=modeVar mode+0x%llx/0x%llx=stars slots=0x%llx/0x%llx/0x%llx",
             TNX_MODE_MANAGER_OFF, TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF,
             TNX_OBJ_GLOBALID_OFF, TNX_OBJ_TEAM_OFF, TNX_MODE_MODEVAR_OFF,
             TNX_MODE_STARS0_OFF, TNX_MODE_STARS1_OFF,
             TNX_MODE_SLOT_A, TNX_MODE_SLOT_B, TNX_MODE_SLOT_C);
}

static void tnx_dump_verified(void) {
    if (!g_base) return;

    tnx_logf("verified anchors image=%p", (void *)g_base);

    for (int i = 0; g_verified[i].name; i++) {
        uintptr_t address = g_base + g_verified[i].rva;
        uint32_t words[4] = {0, 0, 0, 0};
        BOOL exact = NO;

        tnx_start_index(address, &exact);
        tnx_log_words(address, words, 4);

        tnx_logf("verified %-52s off=0x%08llx start=%d prologue=%-8s callable=%d words=%08x %08x %08x %08x",
                 g_verified[i].name,
                 (unsigned long long)g_verified[i].rva,
                 exact ? 1 : 0,
                 tnx_prologue_rule(address),
                 tnx_callable_target(g_base, address) ? 1 : 0,
                 words[0], words[1], words[2], words[3]);
    }
}

static BOOL tnx_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi) {
    if (!g_base || !name) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, name) == 0) {
                if (lo) *lo = slide + (uintptr_t)segment->vmaddr;
                if (hi) *hi = slide + (uintptr_t)segment->vmaddr + (uintptr_t)segment->vmsize;

                return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static BOOL tnx_image_contains(uintptr_t value) {
    if (!g_base || !value) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

static const char *tnx_image_segment_name(uintptr_t value) {
    if (!g_base || !value) return NULL;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NULL;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NULL;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NULL;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NULL;
        if (cursor + command->cmdsize > limit) return NULL;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) {
                    return segment->segname;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NULL;
}

/* Engine vtables are const data: they sit in __DATA_CONST, not in __DATA. */
static BOOL tnx_vtable_shaped(uintptr_t value) {
    const char *segment = tnx_image_segment_name(value);

    if (!segment) return NO;
    if (value % 8) return NO;

    if (strcmp(segment, TNX_VTABLE_SEGMENT) == 0) return YES;
    if (strcmp(segment, TNX_VTABLE_SEGMENT_ALT) == 0) return YES;

    return NO;
}

/* A real engine instance is heap allocated: its address can never be inside a
   mapped image segment. This is what rejects the static tables in __DATA. */
static BOOL tnx_heap_resident(uintptr_t value) {
    if (!value) return NO;

    return tnx_image_segment_name(value) ? NO : YES;
}

/* Re-verified against the working implementation, and two of the old tests are gone.

   Dropped: "globalId > 0". The reference never tests the global id when it decides whether an
   array entry is a live entity; it just walks the array. Requiring a positive id could have
   thrown away a perfectly real object, which is the one failure mode that costs a whole run.

   Dropped: "team <= 3". That bound was mine, not the reference's -- the reference compares team
   to the own-player team and never bounds it. It is replaced by a wide sanity range so that a
   garbage read is still caught, without any chance of rejecting a real team value.

   Kept, because they are the two tests that actually killed the recorded false positives: the
   object must live on the heap (never inside a mapped image segment) and its first word must be
   a table in const data. Added: the dead flag at +0xd0 has to read as a 0/1 BYTE, which is how
   the reference reads it. That byte is what a C string or a version vector can never produce. */
static BOOL tnx_gameobject_shape(uintptr_t object) {
    void *vtable = NULL;
    int32_t team = 0;
    uint8_t dead = 0;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;
    if (!tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team)) return NO;
    if (team < 0 || team > TNX_OBJ_TEAM_MAX) return NO;
    if (!tnx_read_u8(object + TNX_OBJ_DEADFLAG_OFF, &dead)) return NO;
    if (dead > 1) return NO;

    return YES;
}

static BOOL tnx_instance_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;
    if ((uintptr_t)vtable == object) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;

    return YES;
}

static BOOL tnx_object_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;

    return tnx_image_contains((uintptr_t)vtable);
}

static BOOL tnx_manager_shape(uintptr_t manager) {
    void *array = NULL;
    void *probe = NULL;
    int32_t count = 0;

    /* No vtable check on the manager: per the verified disassembly of
       LogicGameObjectManager its word at +0x0 is the object array, not a vtable.
       Only residency plus array/count shape is required here. */
    if (!tnx_heap_resident(manager)) return NO;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return NO;
    if (count < 0 || count > 512) return NO;

    /* The array field is checked for residency even when the count is zero: the lobby
       false positives all had an image-resident array with count 0. */
    if (array && !tnx_heap_resident((uintptr_t)array)) return NO;

    if (count > 0) {
        if (!array) return NO;
        if (!tnx_read_ptr((uintptr_t)array, &probe)) return NO;
        if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        if (count > 1) {
            if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return NO;
            if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        }
    }

    return YES;
}

/* 0 = not a battle mode, 1 = structure plausible, 2 = confirmed by game-object layout. */
static int tnx_mode_score(uintptr_t mode) {
    void *manager = NULL;
    void *array = NULL;
    int32_t variation = 0;
    int32_t count = 0;

    if (!tnx_instance_shaped(mode)) return 0;

    if (!tnx_read_i32(mode + TNX_MODE_MODEVAR_OFF, &variation)) return 0;
    if (variation < 0 || variation > 400) return 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &manager)) return 0;
    if (!manager) return 0;
    if (!tnx_manager_shape((uintptr_t)manager)) return 0;

    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;

    /* Highest entry count seen on any structurally plausible candidate: the heartbeat
       prints it so a lobby run can be told apart from a run that simply found nothing. */
    if (count > g_mode_best_objects) g_mode_best_objects = count;

    /* Every lobby look-alike observed so far held 0 or 1 entries. A battle holds several. */
    if (count < TNX_MODE_MIN_OBJECTS || count > 512) return 0;
    if (!array || !tnx_heap_resident((uintptr_t)array)) return 0;

    int verified = 0;
    int live = 0;
    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_heap_resident((uintptr_t)element)) continue;

        live++;

        if (tnx_gameobject_shape((uintptr_t)element)) verified++;

        /* Distinct vtables, not distinct objects. A battle holds several classes, while
           the container that ended the previous run held 71 objects of a single class and
           was accepted anyway -- that is the false positive this count removes. */
        void *elementVtable = NULL;

        if (!tnx_read_ptr((uintptr_t)element, &elementVtable)) continue;
        if ((uintptr_t)elementVtable <= g_base) continue;

        uintptr_t elementRva = (uintptr_t)elementVtable - g_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    /* Kept in a global so the hit line and the on-screen overlay can report it. */
    g_mode_last_types = typeCount;

    /* score 1: a real container of live C++ objects. score 2: the game-object fields
       matched too AND the container is heterogeneous, i.e. it really holds a battle.
       Either way this is worth dumping; only score 2 stops the scan. */
    if (live < TNX_MODE_MIN_OBJECTS) return 0;
    if (verified < TNX_MODE_MIN_OBJECTS) return 1;

    return (typeCount >= TNX_MODE_MIN_TYPES) ? 2 : 1;
}

static const uintptr_t g_mode_vtables[] = {
    0x10012c8, 0x1001318, 0x1001368, 0x10013b8,
    0x1001408, 0x1001458, 0x10014a8, 0x10014f8, 0x1001548, 0x1001598, 0x10015e8, 0x10016e0,
    0x10017d8, 0x10018c0, 0x1001908, 0x10019d0, 0x1001ac8, 0x1001bc0, 0x1001cb8, 0x1001d80,
    0x1001e48, 0x1001f10, 0x10022f0, 0x10023b8, 0x1002480, 0x1002548, 0x1002610,
    0x10026d8, 0x10027a0, 0x1002868, 0x1002930, 0x10029f8, 0x1002ac0, 0x1002b88, 0x1002d18,
    0,
};

static BOOL tnx_is_mode_vtable(uintptr_t value, uintptr_t *rvaOut) {
    if (!g_base || !value) return NO;

    for (int i = 0; g_mode_vtables[i]; i++) {
        if (value != (g_base + g_mode_vtables[i])) continue;

        if (rvaOut) *rvaOut = g_mode_vtables[i];

        return YES;
    }

    return NO;
}

static void tnx_report_mode_hit(const char *tag, uintptr_t slot, uintptr_t object) {
    uint32_t words[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    uintptr_t vtableRva = 0;
    uintptr_t managerVtableRva = 0;
    uintptr_t vtableOff = 0;
    const char *modeSeg = NULL;
    const char *vtableSeg = NULL;
    int score = 0;
    void *vtable = NULL;
    void *manager = NULL;
    void *managerVtable = NULL;
    void *array = NULL;
    void *entry = NULL;
    int32_t variation = 0;
    int32_t count = 0;

    tnx_read_ptr(object, &vtable);
    tnx_is_mode_vtable((uintptr_t)vtable, &vtableRva);

    if (g_base && (uintptr_t)vtable > g_base) vtableOff = (uintptr_t)vtable - g_base;

    modeSeg = tnx_image_segment_name(object);
    vtableSeg = tnx_image_segment_name((uintptr_t)vtable);
    score = tnx_mode_score(object);

    tnx_read_i32(object + TNX_MODE_MODEVAR_OFF, &variation);
    tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &manager);
    tnx_read_ptr((uintptr_t)manager, &managerVtable);
    tnx_is_mode_vtable((uintptr_t)managerVtable, &managerVtableRva);
    tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count);
    tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array);
    tnx_read_ptr((uintptr_t)array, &entry);
    tnx_read_bytes(object, words, sizeof(words));

    tnx_logf("modehit[%s] slot=%p mode=%p mdSeg=%s vt=%p vtSeg=%s vtOff=%#llx inList=%d primary=%d score=%d types=%d var=%d mgr=%p mgr0Rva=%#llx mgrShape=%d array=%p entry0=%p count=%d",
             tag, (void *)slot, (void *)object, modeSeg ? modeSeg : "-",
             vtable, vtableSeg ? vtableSeg : "-", (unsigned long long)vtableOff,
             tnx_is_mode_vtable((uintptr_t)vtable, NULL) ? 1 : 0,
             tnx_verified_vtable((uintptr_t)vtable) >= 0 ? 1 : 0,
             score, g_mode_last_types, variation,
             manager, (unsigned long long)managerVtableRva,
             tnx_manager_shape((uintptr_t)manager) ? 1 : 0, array, entry, count);

    for (int i = 0; i < 2; i++) {
        tnx_logf("modehit[%s] +%02x %08x %08x %08x %08x", tag, i * 16,
                 words[i * 4], words[i * 4 + 1], words[i * 4 + 2], words[i * 4 + 3]);
    }
}

/* Adopt a candidate so the a/b snapshot dumps fire for it. A "container" hit (score 1) is
   kept for diagnostics only and does NOT stop the scan; a confirmed hit (score 2) replaces
   it and stops it. Replacing a candidate re-arms the snapshot pair. */
static void tnx_adopt_mode(uintptr_t object, BOOL strong, const char *tag) {
    if (!object) return;
    if (g_mode_strong) return;
    if (g_mode_object == object && strong == g_mode_strong) return;
    if (g_mode_object && !strong) return;

    if (g_mode_object != object) {
        g_snapshot_first = NO;
        g_snapshot_second = NO;
        g_snapshot_start = 0.0;
    }

    g_mode_object = object;
    g_mode_source = 0;

    if (strong) g_mode_strong = YES;

    tnx_battle_begin(tag);

    tnx_logf("mode adopt tag=%s object=%p strong=%d maxObj=%d",
             tag, (void *)object, strong ? 1 : 0, g_mode_best_objects);

    tnx_report_mode_hit(tag, 0, object);
}

/* ---------------------------------------------------------------------------
   Protocol discovery.

   The engine's native-facing callback channel is an ObjC protocol: MetalView and
   NullView both carry a `titanDelegate` property, and the binary contains the
   protocol name TitanViewDelegate plus scTitanApplication / scTitanHookRegistry.
   A delegate protocol is the supported way to learn when a battle starts and ends
   -- far better than guessing structure in memory. Read the runtime instead of the
   binary so the names are exact.
   --------------------------------------------------------------------------- */

static void tnx_dump_protocol_methods(const char *name) {
    Protocol *protocol = objc_getProtocol(name);

    if (!protocol) {
        tnx_logf("proto %s absent", name);
        return;
    }

    unsigned required = 0;
    unsigned optional = 0;
    struct objc_method_description *req = protocol_copyMethodDescriptionList(protocol, YES, YES, &required);
    struct objc_method_description *opt = protocol_copyMethodDescriptionList(protocol, NO, YES, &optional);

    tnx_logf("proto %s required=%u optional=%u", name, required, optional);

    for (unsigned i = 0; req && i < required && i < 48; i++) {
        tnx_logf("proto %s req -%s types=%s", name, sel_getName(req[i].name),
                 req[i].types ? req[i].types : "-");
    }

    for (unsigned i = 0; opt && i < optional && i < 48; i++) {
        tnx_logf("proto %s opt -%s types=%s", name, sel_getName(opt[i].name),
                 opt[i].types ? opt[i].types : "-");
    }

    if (req) free(req);
    if (opt) free(opt);
}

static void tnx_dump_protocols(void) {
    unsigned total = 0;
    Protocol *__unsafe_unretained *list = objc_copyProtocolList(&total);
    int named = 0;

    for (unsigned i = 0; list && i < total; i++) {
        const char *name = protocol_getName(list[i]);

        if (!name) continue;

        if (strstr(name, "itan") || strstr(name, "attle") || strstr(name, "Titan") ||
            strstr(name, "Hook") || strstr(name, "View") || strstr(name, "Game")) {
            if (named++ < 60) tnx_logf("proto found %s", name);
        }
    }

    tnx_logf("proto total=%u interesting=%d", total, named);

    if (list) free(list);

    /* Property attributes name the delegate's protocol exactly, e.g.
       T@"<TitanViewDelegate>", so no name guessing is needed. */
    static const char *const classes[] = { "MetalView", "NullView", NULL };

    for (int i = 0; classes[i]; i++) {
        Class cls = objc_getClass(classes[i]);

        if (!cls) continue;

        objc_property_t property = class_getProperty(cls, "titanDelegate");

        tnx_logf("prop %s titanDelegate attrs=%s", classes[i],
                 property ? (property_getAttributes(property) ? property_getAttributes(property) : "-") : "absent");
    }

    static const char *const protocols[] = { "TitanViewDelegate", NULL };

    for (int i = 0; protocols[i]; i++) tnx_dump_protocol_methods(protocols[i]);
}

static void tnx_dump_hex(const char *tag, uintptr_t address, size_t bytes) {
    uint8_t buffer[0x100];

    if (bytes > sizeof(buffer)) bytes = sizeof(buffer);

    for (size_t offset = 0; offset + 16 <= bytes; offset += 16) {
        uint32_t words[4] = { 0, 0, 0, 0 };

        if (!tnx_copy(address + offset, buffer, 16)) break;

        memcpy(words, buffer, sizeof(words));

        tnx_logf("%s +%02zx %08x %08x %08x %08x", tag, offset, words[0], words[1], words[2], words[3]);
    }
}

/* Vtable-free manager shape.

   This is the anchor that needs no vtable guess at all. The layout of the manager was
   established from the 38 call sites of addGameObject, not from an offsets table:
   [manager+0x0] is the array, [manager+0xc] is the live count. Every lobby container
   seen so far held 0 or 1 entries; a battle manager holds several, and those entries
   are heap objects that themselves look like C++ instances.

   Score 2 = at least TNX_MANAGER_MIN_OBJECTS entries look like instances. */

static void tnx_dump_manager(uintptr_t manager, int count) {
    void *array = NULL;

    tnx_logf("mgr[dump] manager=%p count=%d", (void *)manager, count);
    tnx_dump_hex("mgr", manager, 0x40);

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return;
    if (!array) return;

    tnx_dump_hex("mgrArr", (uintptr_t)array, 0x40);

    for (int i = 0; i < count && i < 4; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) return;
        if (!element) continue;

        /* Reads the element the same way the mode path does, so a real battle container gives
           real coordinates here instead of only a hex blob. This is the input a dodge needs. */
        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        uint8_t dead = 0;
        int32_t x = 0;
        int32_t y = 0;

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        tnx_obj_coord((uintptr_t)element, TNX_OBJ_GETX_SLOT, &x);
        tnx_obj_coord((uintptr_t)element, TNX_OBJ_GETY_SLOT, &y);

        tnx_logf("mgr[%d] element=%p gameobj=%d gid=%d team=%d own=%d dead=%d x=%d y=%d",
                 i, element, tnx_gameobject_shape((uintptr_t)element) ? 1 : 0,
                 globalId, team, owner, dead, x, y);

        tnx_dump_hex("mgrObj", (uintptr_t)element, 0x100);
    }
}

/* How many of the first entries of a manager-shaped object are heap objects that
   themselves look like C++ instances. This single number is what separates a battle
   manager from a lobby container, and it is also what the verdict below reports. */
static int tnx_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int live = 0;

    if (!tnx_pointer_plausible(manager)) return 0;
    if (!tnx_heap_resident(manager)) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count < TNX_MANAGER_MIN_OBJECTS || count > 512) return 0;
    if (!array) return 0;
    if (!tnx_heap_resident((uintptr_t)array)) return 0;

    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;

    for (int32_t i = 0; i < count && i < 8; i++) {
        void *element = NULL;
        void *vtable = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_heap_resident((uintptr_t)element)) continue;
        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;
        if (!vtable) continue;
        if (!tnx_vtable_shaped((uintptr_t)vtable)) continue;

        /* The test that was missing, and it only has a chance of working now that team is read
           at 0x40: a game object carries a team in range and a 0/1 byte dead flag at 0xd0.
           Everything else can be faked -- the 17:51 run accepted a vector of version strings
           (its dump spells out "Nulls Brawl" and "NB v69.225") because it had the right count,
           live heap pointers and even two distinct vtables. */
        if (!tnx_gameobject_shape((uintptr_t)element)) continue;

        live++;

        /* Distinct element classes, the same rule the mode path already uses. Without it a
           struct whose first field is a string passes: the 2026-10-02 16:59 run adopted
           0x12c48b8e0 exactly that way -- [mgr+0] pointed at "gacha_vfx_epic", and the string
           bytes happened to decode as three live pointers. It then locked the scan for the
           remaining seven minutes. */
        uintptr_t elementRva = (uintptr_t)vtable - g_base;
        BOOL known = NO;

        for (int k = 0; k < typeCount; k++) {
            if (types[k] == elementRva) {
                known = YES;
                break;
            }
        }

        if (!known && typeCount < TNX_MODE_TYPE_MAX) types[typeCount++] = elementRva;
    }

    if (typeCount < TNX_MODE_MIN_TYPES) return 0;

    return live;
}

/* Called for every aligned word of the chunk. The first tests are pure register work, so
   the cost over a 500 MB pass stays negligible; the syscall-heavy part runs only for
   words whose [+0xc] already looks like a live count. */
static void tnx_probe_manager(uintptr_t cursor, size_t offset, const uint8_t *buffer, size_t chunk) {
    uint64_t arrayValue = 0;
    uint32_t count = 0;
    uintptr_t candidate = 0;
    int live = 0;

    if (g_manager_object) return;
    if (g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) return;
    if (offset + 0x10 > chunk) return;

    memcpy(&arrayValue, buffer + offset, sizeof(arrayValue));
    memcpy(&count, buffer + offset + 0xc, sizeof(count));

    if (count < TNX_MANAGER_MIN_OBJECTS || count > 512) return;
    if (!tnx_pointer_plausible((uintptr_t)arrayValue)) return;

    g_manager_probes++;
    g_manager_probes_total++;

    candidate = cursor + offset;
    live = tnx_manager_live_count(candidate);

    /* Record the closest miss too: this is what says whether the shape is absent or
       merely never complete. */
    if ((int)count > g_manager_best_count) g_manager_best_count = (int)count;
    if (live > g_manager_best_live) g_manager_best_live = live;

    if (live < TNX_MANAGER_MIN_OBJECTS) return;

    g_manager_object = candidate;
    g_manager_count = (int)count;

    tnx_logf("MANAGER found object=%p count=%u live=%d", (void *)candidate, count, live);

    tnx_dump_manager(candidate, (int)count);
}

/* The line that has to be read first in every future log: how often each hook was entered, and
   whether the rewritten slot still holds our replacement. A slot that silently reverted would
   make every other number meaningless, and "no capture" on its own could never tell the two
   cases apart. */
static void tnx_slot_diag(const char *why) {
    char buf[320];
    int used = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        const char *state = "n/a";
        void *current = NULL;

        if (g_slot_specs[i].slotRva && g_slot_installed[i] == 1) {
            state = "unreadable";

            if (tnx_read_ptr(g_base + g_slot_specs[i].slotRva, &current)) {
                state = ((uintptr_t)current == (uintptr_t)g_slot_specs[i].replacement)
                            ? "held" : "LOST";
            }
        }

        if (used > (int)sizeof(buf) - 40) break;

        used += snprintf(buf + used, sizeof(buf) - (size_t)used, "%s=%llu/%s ",
                         g_slot_specs[i].shortTag, (unsigned long long)g_slot_hits[i], state);
    }

    /* addGameObject is the one signal that cannot be faked: it is in-line hooked, it is
       non-virtual, and the battle calls it only when it creates objects. */
    tnx_logf("slotdiag(%s) %s AG=%llu/i%d mgr=%p objs=%d", why ? why : "?", buf,
             (unsigned long long)g_ag_hits, g_ag_installed, (void *)g_ag_manager,
             g_ag_objectCount);

    if (g_ag_objectCount > 0 && !g_ag_adopted) {
        g_ag_adopted = 1;

        tnx_logf("AG dump manager=%p objects=%d", (void *)g_ag_manager, g_ag_objectCount);

        for (int i = 0; i < g_ag_objectCount; i++) {
            tnx_logf("AG obj[%d]=%p", i, (void *)g_ag_objects[i]);
            tnx_dump_hex("AGobj", g_ag_objects[i], 0x80);
        }
    }
}

/* Prints the conclusion, not the raw numbers: this is the line that has to be read. */
static void tnx_diag_report(const char *why) {
    const char *verdict = "no battle-shaped structure in the memory scanned so far";

    if (g_manager_object) {
        verdict = "MANAGER FOUND - the objects exist, coordinates come from the mgrObj dump";
    } else if (g_mode_object) {
        verdict = "an object was adopted but no battle-shaped manager around it";
    } else if (g_manager_best_live >= 1) {
        verdict = "manager-shaped array seen, but too few live instances -> not a battle";
    } else if (g_manager_best_count >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "count at +0xc is in rage but entries are not C++ instances -> wrong layout";
    } else if (g_manager_probes_total == 0 && g_heap_passes > 0) {
        verdict = "no manager-like count at +0xc anywhere -> layout @+0xc wrong, or coverage short";
    } else if (g_heap_passes == 0) {
        verdict = "no heap pass completed yet";
    }

    tnx_logf("DIAG(%s) attempts=%d/%d heapPasses=%d covered=%lluMB probes=%d "
             "bestCount=%d bestLive=%d mgr=%p vfx=%d mx=%d",
             why ? why : "?", g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_heap_covered / (1024ull * 1024ull), g_manager_probes_total,
             g_manager_best_count, g_manager_best_live, (void *)g_manager_object,
             g_mode_verified_hits, g_mode_best_objects);

    tnx_logf("DIAG verdict: %s", verdict);

    tnx_slot_diag(why);
}

static void tnx_scan_globals_for_mode(const char *name) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;

    if (!tnx_segment_range(name, &lo, &hi)) {
        tnx_logf("votescan %s missing", name);
        return;
    }

    size_t span = (size_t)(hi - lo);

    if (span < 0x1000 || span > (16u * 1024u * 1024u)) {
        tnx_logf("votescan %s bad span=%zu", name, span);
        return;
    }

    uint8_t *bytes = (uint8_t *)malloc(span);

    if (!bytes) {
        tnx_logf("votescan %s alloc failed", name);
        return;
    }

    if (!tnx_copy(lo, bytes, span)) {
        free(bytes);
        tnx_logf("votescan %s read failed", name);
        return;
    }

    int hits = 0;
    int vtHits = 0;
    int shapeHits = 0;
    int strongHits = 0;
    int nearMiss = 0;
    int verifiedHits = 0;

    for (size_t offset = 0; offset + sizeof(void *) <= span; offset += sizeof(void *)) {
        uintptr_t object = 0;
        void *vtable = NULL;
        BOOL vtMatch = NO;
        int score = 0;
        int vfx = -1;

        memcpy(&object, bytes + offset, sizeof(object));

        /* Cheap and decisive: a table entry inside __DATA is static storage, never a
           heap instance. This is what removed the 99 false hits in __DATA. */
        if (!tnx_pointer_plausible(object)) continue;
        if (!tnx_heap_resident(object)) continue;
        if (!tnx_read_ptr(object, &vtable)) continue;
        if (!vtable) continue;

        vtMatch = tnx_is_mode_vtable((uintptr_t)vtable, NULL);
        vfx = tnx_verified_vtable((uintptr_t)vtable);

        if (vfx >= 0 || vtMatch || tnx_vtable_shaped((uintptr_t)vtable)) score = tnx_mode_score(object);

        if (score == 0 && !vtMatch && vfx < 0) {
            /* Heap pointer whose first word is an image pointer: a plausible C++ instance
               that still failed the mode layout. Kept in the log so the next iteration
               does not have to guess which check is too strict. */
            if (tnx_object_shaped(object)) {
                nearMiss++;

                if (g_mode_near_logs < 3) {
                    g_mode_near_logs++;
                    tnx_report_mode_hit("near", lo + offset, object);
                }
            }

            continue;
        }

        hits++;
        g_mode_matches++;

        if (vfx >= 0) {
            g_mode_verified_hits++;
            verifiedHits++;

            tnx_battle_begin("globals");
        }
        if (vtMatch) vtHits++;
        if (score >= 1) shapeHits++;
        if (score >= 2) strongHits++;

        if (g_mode_strict_logs < 6 || vfx >= 0) {
            g_mode_strict_logs++;
            tnx_report_mode_hit(vfx >= 0 ? "cap" : (score >= 2 ? "strong" : (score == 1 ? "weak" : "vt")),
                                lo + offset, object);
        }

        if (vfx >= 0) {
            /* An instance of a class verified to own the game-object manager: accepted
               unconditionally, whatever the layout heuristics say. */
            tnx_adopt_mode(object, YES, "verified");
        } else if (score >= 2) {
            tnx_adopt_mode(object, YES, "strong");
        } else if (score == 1) {
            tnx_adopt_mode(object, NO, "container");
        }
    }

    free(bytes);

    /* Quiet by default: the two per-attempt lines used to bury the whole 240-attempt
       window in ~500 identical lines, which is exactly why every pasted log stopped
       before the interesting part. Log on change, and otherwise twice a minute. */
    {
        int index = (strcmp(name, "__DATA_CONST") == 0) ? 1 : 0;
        int sig = hits * 31 + shapeHits * 131 + strongHits * 1313 + verifiedHits * 131313;

        if (sig != g_scan_sig[index] || (g_votescan_attempts % 30) == 0) {
            g_scan_sig[index] = sig;

            tnx_logf("votescan %s hits=%d vt=%d shape=%d strong=%d near=%d vfx=%d",
                     name, hits, vtHits, shapeHits, strongHits, nearMiss, verifiedHits);
        }
    }
}

static void tnx_scan_heap_for_mode(void) {
    uintptr_t startAddress = g_heap_scan_next;
    vm_address_t address = (vm_address_t)startAddress;
    size_t scanned = 0;

    g_manager_probes = 0;

    g_heap_passes++;
    int regions = 0;
    int hits = 0;
    int shapeHits = 0;
    int strongHits = 0;
    int verifiedHits = 0;

    while (regions < 8192 && scanned < TNX_HEAP_SCAN_BUDGET) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t objectName = MACH_PORT_NULL;

        kern_return_t result = vm_region_64(
            mach_task_self(),
            &address,
            &size,
            VM_REGION_BASIC_INFO_64,
            (vm_region_info_t)&info,
            &infoCount,
            &objectName
        );

        if (objectName != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), objectName);
        if (result != KERN_SUCCESS || size == 0) break;

        /* The process maps a ~385 GB guard region; walking it is what produced the
           earlier crash (far=0x14c). Nothing we need lives in a region that large. */
        if (size > (1ull << 30)) {
            uintptr_t beyond = (uintptr_t)address + (uintptr_t)size;

            if (beyond <= (uintptr_t)address) break;

            address = (vm_address_t)beyond;

            continue;
        }

        regions++;

        if ((info.protection & VM_PROT_WRITE) != 0 && size >= 0x1000) {
            uint64_t remaining = (uint64_t)size;
            uintptr_t cursor = (uintptr_t)address;

            while (remaining >= 16 && scanned < TNX_HEAP_SCAN_BUDGET) {
                size_t chunk = (size_t)(remaining < TNX_HEAP_CHUNK ? remaining : (uint64_t)TNX_HEAP_CHUNK);
                uint8_t *buffer = (uint8_t *)malloc(chunk);

                if (!buffer) break;

                if (tnx_copy(cursor, buffer, chunk)) {
                    for (size_t offset = 0; offset + sizeof(uintptr_t) <= chunk; offset += sizeof(uintptr_t)) {
                        uintptr_t vtable = 0;

                        memcpy(&vtable, buffer + offset, sizeof(vtable));

                        tnx_probe_manager(cursor, offset, buffer, chunk);

                        /* Must also match the verified vtables: one of them (0xff5720) is
                           NOT in the 35-entry heuristic list, so looking only at that list
                           made an instance of that class invisible to this scan. */
                        if (!tnx_is_mode_vtable(vtable, NULL) && tnx_verified_vtable(vtable) < 0) continue;

                        hits++;
                        g_mode_matches++;

                        uintptr_t object = cursor + offset;
                        int vfx = tnx_verified_vtable(vtable);
                        int score = tnx_mode_score(object);

                        if (vfx >= 0) {
                            g_mode_verified_hits++;
                            verifiedHits++;

                            tnx_battle_begin("heap");
                        }

                        if (score == 0 && vfx < 0) continue;

                        shapeHits++;
                        if (score >= 2) strongHits++;

                        if (g_mode_relaxed_logs < 8 || vfx >= 0) {
                            g_mode_relaxed_logs++;
                            tnx_report_mode_hit(vfx >= 0 ? "heap-cap" : (score >= 2 ? "heap+" : "heapw"), 0, object);
                        }

                        if (vfx >= 0) {
                            tnx_adopt_mode(object, YES, "heap-verified");
                        } else if (score >= 2) {
                            tnx_adopt_mode(object, YES, "heap-strong");
                        } else if (score == 1) {
                            tnx_adopt_mode(object, NO, "heap-container");
                        }
                    }
                }

                free(buffer);

                size_t step = chunk - sizeof(uintptr_t);

                if (step == 0) break;

                scanned += step;
                cursor += step;
                remaining -= step;
            }
        }

        uintptr_t next = (uintptr_t)address + (uintptr_t)size;
        if (next <= (uintptr_t)address) break;

        address = (vm_address_t)next;
    }

    /* If the byte budget ran out, remember where: the next pass continues from there
       instead of re-scanning the same low part of the address space every time. */
    if (scanned >= TNX_HEAP_SCAN_BUDGET && regions >= 8192) {
        g_heap_scan_next = 0;
    } else if (scanned >= TNX_HEAP_SCAN_BUDGET) {
        g_heap_scan_next = (uintptr_t)address;
    } else {
        g_heap_scan_next = 0;
    }

    g_heap_covered += (unsigned long long)scanned;

    tnx_logf("votescan heap pass=%d from=%p scanned=%zu regions=%d hits=%d vfx=%d mgr=%p probes=%d best%d/%d",
             g_heap_passes, (void *)startAddress, scanned, regions, hits, verifiedHits,
             (void *)g_manager_object, g_manager_probes, g_manager_best_count, g_manager_best_live);
}

static void tnx_locate_battle_mode(void) {
    if (g_mode_strong) return;

    if (g_votescan_attempts >= TNX_VOTESCAN_ATTEMPTS) {
        /* Only a candidate whose vtable is one of the 35 anchors is ever promoted.
           Every lobby candidate had inList = 0, so nothing is promoted from noise. */
        tnx_diag_report("exhausted");

        return;
    }

    double now = CFAbsoluteTimeGetCurrent();

    if (g_votescan_last > 0.0 && (now - g_votescan_last) < TNX_VOTESCAN_INTERVAL) return;

    g_votescan_last = now;
    g_votescan_attempts++;

    if (g_votescan_attempts == 1) {
        tnx_logf("votescan candidates=%d interval=%.1f attempts=%d heapEvery=%d",
                 (int)(sizeof(g_mode_vtables) / sizeof(g_mode_vtables[0]) - 1),
                 (double)TNX_VOTESCAN_INTERVAL, TNX_VOTESCAN_ATTEMPTS, TNX_VOTESCAN_HEAP_EVERY);
    }

    /* The segment scans are the expensive part of a tick (a 2 MB copy plus a probe for every
       candidate pointer). They now run on one attempt in TNX_VOTESCAN_GLOBAL_EVERY, which
       keeps the game responsive without giving up the fallback entirely. */
    if ((g_votescan_attempts % TNX_VOTESCAN_GLOBAL_EVERY) == 1) {
        tnx_scan_globals_for_mode("__DATA");

        if (!g_mode_strong) tnx_scan_globals_for_mode("__DATA_CONST");
    }

    if (!g_mode_strong && (g_votescan_attempts % TNX_VOTESCAN_HEAP_EVERY) == 1) tnx_scan_heap_for_mode();

    if (g_mode_strong) {
        tnx_logf("votescan SUCCESS attempt=%d object=%p global=%p",
                 g_votescan_attempts, (void *)g_mode_object, (void *)g_mode_source);
        tnx_report_mode_hit("found", g_mode_source, g_mode_object);
    } else if ((g_votescan_attempts % TNX_VOTESCAN_HEARTBEAT) == 0) {
        tnx_diag_report("heartbeat");
    }
}

static uintptr_t tnx_vtable_rva(void *object) {
    void *vtable = NULL;

    if (!object) return 0;
    if (!tnx_read_ptr((uintptr_t)object, &vtable)) return 0;
    if (!vtable) return 0;
    if ((uintptr_t)vtable < g_base) return 0;

    return (uintptr_t)vtable - g_base;
}

static void tnx_dump_mode_refs(const char *tag) {
    if (!g_mode_object) return;

    tnx_logf("moderef[%s] mode=%p vt=%#llx", tag, (void *)g_mode_object,
             (unsigned long long)tnx_vtable_rva((void *)g_mode_object));

    for (uint32_t off = 0; off < 0x60; off += 8) {
        void *field = NULL;

        if (!tnx_read_ptr(g_mode_object + off, &field)) continue;
        if (!field) continue;
        if ((uintptr_t)field < 0x10000) continue;

        int32_t probe = 0;
        tnx_read_i32((uintptr_t)field + TNX_MODE_MODEVAR_OFF, &probe);

        tnx_logf("moderef[%s] +%02x -> %p vt=%#llx int124=%d",
                 tag, off, field, (unsigned long long)tnx_vtable_rva(field), probe);
    }

    for (int i = 0; i < 3; i++) {
        uint32_t off = (uint32_t)(TNX_MODE_SLOT_A + i * 8);
        void *slot = NULL;

        if (!tnx_read_ptr(g_mode_object + off, &slot)) continue;
        if (!slot) continue;

        tnx_logf("moderef[%s] sl%c +%x -> %p vt=%#llx",
                 tag, (char)('A' + i), off, slot, (unsigned long long)tnx_vtable_rva(slot));
    }
}

/* Coordinates are int32 and sit behind consecutive virtual slots (0x88 = getX, 0x90 = getY,
   proven by the call site ldr x8,[x8,#0x88] plus REvengeBS having getX/getY/getZ eight bytes
   apart). Nothing is hardcoded: the callee comes out of the object's own vtable, which is what
   the game itself does to read a position. This is the input every dodge calculation needs. */
typedef int32_t (*tnx_coord_fn_t)(void *self);

static BOOL tnx_obj_coord(uintptr_t object, uintptr_t slot, int32_t *value) {
    void *vtable = NULL;
    void *function = NULL;

    *value = 0;

    if (!object) return NO;
    if (!tnx_read_ptr(object, &vtable) || !vtable) return NO;
    if (!tnx_read_ptr((uintptr_t)vtable + slot, &function) || !function) return NO;
    if ((uintptr_t)function < g_base) return NO;
    if ((uintptr_t)function >= g_base + 0xf74000) return NO;

    *value = ((tnx_coord_fn_t)function)((void *)object);

    return YES;
}

static void tnx_dump_mode_objects(const char *tag) {
    if (!g_mode_object) return;

    tnx_dump_mode_refs(tag);

    void *manager = NULL;
    void *array = NULL;
    int32_t count = 0;
    int32_t variation = 0;

    if (!tnx_read_ptr(g_mode_object + TNX_MODE_MANAGER_OFF, &manager)) return;
    if (!tnx_read_i32(g_mode_object + TNX_MODE_MODEVAR_OFF, &variation)) return;
    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &array)) return;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return;

    tnx_logf("mode[%s] object=%p variation=%d manager=%p array=%p count=%d",
             tag, (void *)g_mode_object, variation, manager, array, count);

    if (!array || count <= 0) return;

    int limit = count < TNX_SNAPSHOT_OBJECTS ? count : TNX_SNAPSHOT_OBJECTS;

    for (int i = 0; i < limit; i++) {
        void *object = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &object)) continue;
        if (!object) continue;
        if (!tnx_pointer_plausible((uintptr_t)object)) continue;

        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        uint8_t dead = 0;
        int32_t x = 0;
        int32_t y = 0;

        tnx_read_i32((uintptr_t)object + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)object + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)object + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)object + TNX_OBJ_DEADFLAG_OFF, &dead);

        tnx_obj_coord((uintptr_t)object, TNX_OBJ_GETX_SLOT, &x);
        tnx_obj_coord((uintptr_t)object, TNX_OBJ_GETY_SLOT, &y);

        tnx_logf("obj[%s][%d] %p vt=%#llx gid=%d team=%d own=%d dead=%d x=%d y=%d",
                 tag, i, object, (unsigned long long)tnx_vtable_rva(object), globalId, team,
                 owner, dead, x, y);

        for (uint32_t off = 0; off + 32 <= TNX_SNAPSHOT_BYTES; off += 32) {
            uint32_t words[8] = {0, 0, 0, 0, 0, 0, 0, 0};

            if (!tnx_read_bytes((uintptr_t)object + off, words, sizeof(words))) break;

            tnx_logf("obj[%s][%d] +%03x %08x %08x %08x %08x %08x %08x %08x %08x",
                     tag, i, off, words[0], words[1], words[2], words[3],
                     words[4], words[5], words[6], words[7]);
        }
    }
}

/* Runs on the 1 Hz timer, never inside the hook: the replacement itself only stores a
   pointer, so the game thread is never asked to log, to read memory or to walk an array.
   The first object seen is dumped once, in both possible layouts. */
static void tnx_slot_pump(void) {
    int first = -1;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        uint32_t bit = (uint32_t)(1u << i);

        if (!g_slot_object[i]) continue;

        /* The control slot captures a display Stage, never a battle object. It is reported
           but never adopted, or it would overwrite the real candidate on every frame. */
        if (!g_slot_specs[i].control && first < 0) first = i;

        if (g_slot_reported_mask & bit) continue;

        g_slot_reported_mask |= bit;

        tnx_logf("slot %s: captured this=%p hits=%llu%s", g_slot_specs[i].tag,
                 (void *)g_slot_object[i], (unsigned long long)g_slot_hits[i],
                 g_slot_specs[i].control ? " CONTROL" : "");
    }

    if (first < 0) return;

    uintptr_t object = g_slot_object[first];

    if (g_slot_adopted == object) return;

    g_slot_adopted = object;

    int installed = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_installed[i] == 1) installed++;
    }

    tnx_logf("slot pump object=%p source=%s installed=%d/%d",
             (void *)object, g_slot_specs[first].tag, installed, TNX_SLOT_COUNT);

    tnx_battle_begin("slot");

    /* A slot capture outranks anything the scan produced: it IS the battle object. */
    if (g_mode_object != object) {
        g_mode_strong = NO;
        g_mode_object = 0;
    }

    tnx_adopt_mode(object, YES, "slot");

    /* The shot that was never available before: the real object with its own vtable,
       read straight out of the live process. */
    tnx_dump_hex("slotObj", object, 0x100);

    /* Slot A's object reaches the manager through [this+0x8]; slot B's through the
       familiar [this+0x20]. Both are printed, so neither has to be guessed again. */
    void *bridge = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_BRIDGE_OFF, &bridge) && bridge) {
        void *bridgeManager = NULL;

        tnx_logf("slot +08 bridge=%p vt=%#llx", bridge,
                 (unsigned long long)tnx_vtable_rva(bridge));

        if (tnx_read_ptr((uintptr_t)bridge + TNX_MGR_ARRAY_OFF, &bridgeManager) && bridgeManager) {
            tnx_logf("slot bridgeMgr=%p vt=%#llx", bridgeManager,
                     (unsigned long long)tnx_vtable_rva(bridgeManager));

            tnx_dump_hex("slotMgrA", (uintptr_t)bridgeManager, 0x40);
        }
    }

    void *list = NULL;
    int32_t listCount = 0;

    if (tnx_read_ptr(object + TNX_SLOT_LIST_OFF, &list) &&
        tnx_read_i32(object + TNX_SLOT_LISTCOUNT_OFF, &listCount)) {
        tnx_logf("slot +80 list=%p count=%d", list, listCount);
    }

    /* The chain the working implementation actually uses, printed for EVERY capture. It does
       not matter which class the slot hooks caught: if the object owns a manager at +0x28 that
       holds several live entities, that object is the battle mode and this line says so. Until
       now the +0x28 layout was only ever probed on the scan path, never on a captured object. */
    void *modeManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_MANAGER_OFF, &modeManager) && modeManager) {
        void *modeArray = NULL;
        int32_t modeCount = 0;

        tnx_logf("slot +28 mgr=%p vt=%#llx", modeManager,
                 (unsigned long long)tnx_vtable_rva(modeManager));

        if (tnx_read_ptr((uintptr_t)modeManager + TNX_MGR_ARRAY_OFF, &modeArray) &&
            tnx_read_i32((uintptr_t)modeManager + TNX_MGR_COUNT_OFF, &modeCount)) {
            tnx_logf("slot +28 arr=%p count=%d live=%d", modeArray, modeCount,
                     tnx_manager_live_count((uintptr_t)modeManager));
        }

        tnx_dump_hex("slotMgr28", (uintptr_t)modeManager, 0x40);
    }

    /* The other half of the working implementation: the input queue the dodge is handed to,
       [mode+0x58]. Printed on capture so the movement side has a real target next round. */
    void *inputManager = NULL;

    if (tnx_read_ptr(object + TNX_MODE_INPUTMGR_OFF, &inputManager) && inputManager) {
        tnx_logf("slot +58 inputMgr=%p vt=%#llx", inputManager,
                 (unsigned long long)tnx_vtable_rva(inputManager));

        tnx_dump_hex("slotInMgr", (uintptr_t)inputManager, 0x40);
    }

    /* The captured object's own table, forty entries of it. Issuing a dodge needs a callable
       entry point, and the only place one can be read from is here: the slot index of the
       movement method is the last unknown, and this prints every candidate with its address. */
    void *slotTable = NULL;

    if (tnx_read_ptr(object, &slotTable) && slotTable) {
        tnx_logf("slot vtable=%p", slotTable);

        for (int k = 0; k < 40; k += 4) {
            void *entry[4] = { NULL, NULL, NULL, NULL };

            for (int j = 0; j < 4; j++) {
                tnx_read_ptr((uintptr_t)slotTable + (uintptr_t)(k + j) * sizeof(void *), &entry[j]);
            }

            tnx_logf("slot vt[%02d..%02d] %#llx %#llx %#llx %#llx", k, k + 3,
                     (unsigned long long)(uintptr_t)entry[0],
                     (unsigned long long)(uintptr_t)entry[1],
                     (unsigned long long)(uintptr_t)entry[2],
                     (unsigned long long)(uintptr_t)entry[3]);
        }
    }

    tnx_dump_mode_objects("slot");
}

static void tnx_dump_objc_inventory(const char *tag) {
    int total = objc_getClassList(NULL, 0);

    if (total <= 0) {
        tnx_logf("objc[%s] no classes", tag ? tag : "?");
        return;
    }

    if (total > 200000) total = 200000;

    Class *classes = (Class *)malloc(sizeof(Class) * (size_t)total);

    if (!classes) return;

    static const char *noise[] = {
        "Sentry", "Firebase", "AppsFlyer", "GUL", "Zendesk", "sczendesk", "Helpshift",
        "SKAdNetwork", "GAD", "FIR", "nanopb", "GTM", "GSDK", "UI", "NS", "WK", "CA",
        "CL", "CN", "AV", "MTL", "LS", "__", NULL
    };

    static const char *gameplay[] = {
        "Joy", "Stick", "Input", "Touch", "Aim", "Target", "Fire", "Shoot", "Move",
        "Character", "Object", "Manager", "Battle", "Logic", "Player", "Unit",
        "Hud", "HUD", "Screen", "View", "Render", "Stage", "Sprite", "Scene",
        "Mode", "Game", "State", "Resource", "Text", "Label", "Button", "Node", NULL
    };

    int count = objc_getClassList(classes, total);
    int inImage = 0;
    int named = 0;
    int detailed = 0;

    tnx_logf("objc[%s] classes=%d", tag ? tag : "?", count);

    for (int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);

        if (!name) continue;
        if (!tnx_image_owns_address(g_base, (uintptr_t)classes[i])) continue;

        inImage++;

        BOOL skip = NO;

        for (int n = 0; noise[n]; n++) {
            if (strncmp(name, noise[n], strlen(noise[n])) == 0) {
                skip = YES;
                break;
            }
        }

        if (skip) continue;

        if (named < 800) {
            tnx_logf("objc[%s] cls %s", tag ? tag : "?", name);
            named++;
        }

        BOOL interesting = NO;

        for (int g = 0; gameplay[g]; g++) {
            if (strstr(name, gameplay[g])) {
                interesting = YES;
                break;
            }
        }

        if (!interesting || detailed >= 80) continue;

        detailed++;

        unsigned mcount = 0;
        Method *methods = class_copyMethodList(classes[i], &mcount);

        tnx_logf("objc[%s] == %s methods=%u", tag ? tag : "?", name, mcount);

        if (methods) {
            for (unsigned m = 0; m < mcount && m < 24; m++) {
                const char *sel = sel_getName(method_getName(methods[m]));
                const char *types = method_getTypeEncoding(methods[m]);

                tnx_logf("objc[%s]    -[%s %s] %s",
                         tag ? tag : "?", name, sel ? sel : "?", types ? types : "?");
            }

            if (mcount > 24) tnx_logf("objc[%s]    ... %u more", tag ? tag : "?", mcount - 24);

            free(methods);
        }
    }

    tnx_logf("objc[%s] total=%d inImage=%d named=%d detailed=%d",
             tag ? tag : "?", count, inImage, named, detailed);

    free(classes);
}

static void setup(void) {
    if (g_setup_done) return;
    g_setup_done = YES;

    tlog([NSString stringWithFormat:@"setup base=%p", (void *)g_base]);

    image_ref_t ref;
    ref.base = g_base;
    ref.hdr = (const struct mach_header_64 *)g_base;

    rt_dump_image(ref);

    tnx_load_function_starts();

    tnx_resolve_addresses();
    tnx_dump_structs();
    tnx_dump_verified();
    tnx_dump_rvas();
    tnx_probe_classes();
    tnx_dump_protocols();

    tnx_objc_arm("MetalView", "render");
    tnx_objc_arm("NullView", "render");

    /* Armed before the timer: the slot hooks are the primary detector, the memory scan
       below is only the fallback. */
    tnx_slot_hooks_install();

    int buildControls = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) buildControls++;
    }

    tnx_logf("build=%s slots=%d control=%d types>=%d scanEvery=%d heapEvery=%d attempts=%d",
             TNX_BUILD_TAG, TNX_SLOT_COUNT - buildControls, buildControls, TNX_MODE_MIN_TYPES,
             TNX_VOTESCAN_GLOBAL_EVERY, TNX_VOTESCAN_HEAP_EVERY, TNX_VOTESCAN_ATTEMPTS);

    tnx_start_timer();

    tlog([NSString stringWithFormat:@"setup completed successfully armed=%d", g_objc_armed]);
}

static void poll_for_game(int tick) {
    if (g_setup_done) return;
    if (tick > 1200) return;

    uintptr_t base = 0;

    if (find_game_image(&base)) {
        g_base = base;
        setup();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(tick + 1);
    });
}

__attribute__((constructor))
static void start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        tlog(@"=== titanox started (zero latency mode) ===");
        poll_for_game(0);
    });
}
