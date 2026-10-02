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

/* Capacity. Not a guess: the engine's own Array<T> append routine at RVA 0x46aefc reads the
   header as `ldp w9, w8, [x0, #8]` -- w9 = capacity (+0x8), w8 = count (+0xc) -- grows when the
   two are equal, then stores with `ldr x9,[x19]` / `str x20,[x9, w8, sxtw #3]`. So the header is
   {T** data @0x0; uint32 capacity @0x8; uint32 count @0xc}, stride 8, and count <= capacity
   always holds. A fresh array is grown to at least 5.

   This invariant is what finally kills the string family. The 18:16 candidate held 0xffffffff at
   +0x8 and 21 at +0xc -- a capacity of four billion. No real array has that, and the check costs
   nothing: it is a plain word compare inside the buffer, before any syscall. */
#define TNX_MGR_CAP_OFF 0x8ULL
#define TNX_MGR_CAP_MAX 4096

/* The input queue the working implementation hands its dodge to: BattleMode_clientInputManager
   = 0x58, and a ClientInput carries x at 0xc and y at 0x10. Nothing is written here yet; the
   pointer is printed on capture so the movement side has a target to aim at next. */
#define TNX_MODE_INPUTMGR_OFF 0x58ULL
#define TNX_INPUT_X_OFF 0xcULL
#define TNX_INPUT_Y_OFF 0x10ULL

/* A battle manager holds several live objects; every lobby container observed so far
   held 0 or 1. Used by the vtable-free manager probe. */
#define TNX_MANAGER_MIN_OBJECTS 3

/* A real battle holds tens of entities, not hundreds. The previous band was 3..512 and the device
   log shows exactly what that cost: bestCount=512 and probes=2048 -- the entire probe budget --
   consumed before the pass had covered more than a few percent, after which every remaining
   candidate was rejected without being looked at at all. The scan was blind for ~98% of the heap.
   The band is now the one a battle actually occupies. */
#define TNX_MANAGER_MAX_OBJECTS 96

/* Raised from 2048. With the narrower band plus the alignment and residency pre-filters, a probe
   is spent only on a candidate that could plausibly be a manager, so this budget is not expected
   to be reached. It is a safety valve, and g_manager_skipped reports if it ever is. */
#define TNX_MANAGER_PROBE_LIMIT 65536

/* THE CHAIN PROBE. titanox_41 and every version before it looked for the battle mode by its
   vtable -- 37 hardcoded RVAs plus two verified ones -- and never found it, because the live
   mode's class is in neither list. The vtable does not have to be known: the mode is
   recognisable by its CHAIN, [mode+0x28] is the manager and that manager holds an array of
   game objects, which is the layout our own disassembly of 0xac3dcc..0xac3f44 reads and which
   no config table satisfies.

   The limit below is only a safety valve for the render thread. The free tests in front of it
   (first word inside __DATA_CONST, +0x28 a heap pointer, +0x124 a small integer,
   +0x1d4/+0x1d8 plausible) are what keep the syscall-heavy part rare, and g_chain_skipped
   reports if the valve is ever reached -- a probe limit that goes quiet is how the previous
   scanner went blind without saying so.

   MEASURED, 2026-10-02 19:34, with a real battle running: pass 1 made 515110 chain checks, 97179
   of them reached `ready`, and the old limit of 8192 let only 8.4% of those through -- skip=88987.
   Pass 3 was worse still: ready=222999, skip=214807. The free tests are plainly not selective
   enough to justify a valve this small, so it was throttling the only remaining sensor to a tenth
   of its candidates. Raised to 65536. g_chain_skipped still reports every time it is reached, so
   this stays a measurement instead of an assumption. */
#define TNX_CHAIN_PROBE_LIMIT 65536

/* Range of __DATA_CONST at runtime, measured on the device: __TEXT is 0xf74000 long and the
   segment list in every log reports __DATA_CONST with size 0xd4000 straight after it. A mode's
   first word is its vtable and every vtable the engine uses lives here, so this one range test
   is what replaces the hardcoded vtable list. */
#define TNX_DC_RVA_LO 0xf74000ULL
#define TNX_DC_RVA_SIZE 0xd4000ULL

/* The vtables of the classes whose slots are hooked. Counting how many live heap objects carry
   each of these addresses answers the question the previous runs could not: does
   `hooks fired=0` mean the class is never instantiated, or that it exists and the slot we
   rewrote is never dispatched? The two are indistinguishable in a log without this.

   THE NINTH ENTRY IS THE ONE THE 19:51 RUN PRODUCED, and it is the most interesting number in
   this table. The object vote reported `vtCount=1 vt0=0x1008d30` for every candidate it accepted,
   i.e. the battle's object-shaped words all carry the class table at RVA 0x1008d30 -- a table
   that is NOT one of the eight above, which is the direct explanation of `hooks fired=0 of 7
   slots`. That sighting came from a candidate family that turned out to be static image data, so
   this entry is recorded as a CANDIDATE, not as a fact: if the next run's pass lines show a
   non-zero ninth counter in a pass that covered real heap, the table is real and is the one to
    hook next. A zero there says the sighting belonged to the false positive alone.

   ANSWERED, 20:06-20:07, titanox_44, on a COMPLETE sweep. All nine counters read zero, and this
   time that is a statement about the whole writable heap rather than about a fraction of it: pass
   1 started at 0x0 and walked to the top of the address space (scanned=519 MB, next=0x2e6000000),
   pass 2 finished the last 16 MB and wrapped to the window low. The process's entire writable,
   non-image memory is ~536 MB, and every aligned word of it whose value lands in __DATA_CONST was
   fed to this table. So `hooks fired=0 of 7 slots` is now explained and needs no further
   experiment: NONE of the seven hooked classes has a single live instance anywhere, and the
   learned candidate 0x1008d30 belonged to the 19:51 false positive alone. The class to hook is
   not in this table -- it is whatever the real objects carry, and from v45 on the per-hit dump
   names it directly. */
#define TNX_VTPROBE_COUNT 9

static const uintptr_t g_vtprobe_rva[TNX_VTPROBE_COUNT] = {
    0x1002548,                                                            /* class A, A1 and A2 */
    0xff5148, 0xff51f8, 0xff5500, 0xff5648, 0xff5720, 0xff57f8, 0xff58c8, /* class B, B1 to B3 */
    0x1008d30,                                    /* LEARNED CANDIDATE, v43 object vote, vt0 */
};

/* THE OBJECT VOTE -- the selector that replaces "guess the manager by its array header".

   Why the old selector had to go. The 19:34 run walked 542 MB of heap and the manager probe
   reached its budget inside that one pass: 4710812 words survived the capacity test, 3571612
   then passed the alignment, window and residency tests, and `skipped=3506076` says almost none
   of them was ever probed. The reason is that the test was `a pointer followed by two small
   integers`, and on a real heap that is not a signature: it is what ordinary field data looks
   like. Three passes, 65536 probes each, `mgr=0x0`.

   What IS a signature, and what this selector uses, are the three fields the engine itself
   writes when it creates a game object -- each one taken from the engine's own code, not from an
   offsets table:

     +0x00  vtable, must land inside __DATA_CONST (every engine class table does)
     +0x08  a fresh global id, written by addGameObject at 0xa278e4
     +0x20  the owning manager, written by setOwner = `str x1,[x0,#0x20]` at 0xa2d250
     +0x40  team, an int
     +0x3c  owner index, an int

   No single one of those is distinctive. Together they are, because they are the record layout
   of one specific class and no other allocation reproduces it.

   And the vote is what turns the objects into the manager: `setOwner` writes the SAME manager
   into +0x20 of every object the manager creates, so the owning manager is simply the pointer
   that turns up at +0x20 of the most object-shaped words -- and it has to carry several
   DIFFERENT global ids, because addGameObject hands every object a fresh one. That last
   requirement is exactly the invariant the 19:19 false positive failed: a config table whose
   four entries all read id 1 and 0 at +0x20. Distinct ids at one shared owner is the one test
   that table cannot pass.

   The whole test is buffer-local (all five fields sit inside the same 8 MB chunk), so unlike the
   array-header probe it costs no syscall and can be run on every aligned word of a full pass.

   WHAT THE FIRST RUN OF THIS SELECTOR PROVED, AND WHAT IT GOT WRONG (19:51, titanox_43).

   The selector fires: 50 / 217 / 433 / 219 / 155 object-shaped words per pass, several owners per
   pass, and a winner that repeated across passes -- `confirm=2`. The dead flag at +0xd0 held on
   96 of its 109 votes, so that offset is right for this build. The cursor fix worked too: coverage
   went 504 -> 1017 -> 1530 -> 2044 MB instead of being pinned to the same first 542 MB.

   The winner itself was a false positive, and the log says so arithmetically. Image base is
   0x108fd0000 and the "owner" was 0x109fd8d30. An owner is only ever tested against
   `tnx_heap_window_shaped`, whose low edge (0x10447c000) sits BELOW the image base, so an address
   inside __DATA_CONST (0x109f44000..0x10a018000) passes it. And 0x109fd8d30 - 0x108fd0000 =
   0x1008d30, which is exactly the `vt0` printed on the same line: the word at +0x00 and the word
   at +0x20 of that candidate family hold the SAME static image address. The result was
   `objvote mgr=0x109fd8d30 array=0x109b6b85c count=1 cap=162969880 live=0 CAP-VIOLATION` -- a
   "battle container" with a four-billion-entry array, which is the signature of reading a
   non-manager.

   v44 therefore adds the test v43 was missing: the owner must pass the POSITIVE residency test
   (inside a region the kernel handed this process as ordinary writable memory, and outside every
   segment of the image), the candidate word itself must not be static image data, and a confirmed
   owner must carry at least two teams. Each rejection is counted and printed, so a future
   `owners=0` is a measurement instead of a mystery.

   WHAT THE v44 RUN SHOWED (20:06-20:07), and what v45 does about it.

   Every gate worked and is visible in the log. `imgSkip=44` regions dropped, `objImg=0` (the walker
   really did stop seeing static data), `ownerImg=45` candidates rejected for an owner that is not
   positive heap, `teamsMin=2` printed. The result was `hits=9 skipped=0 owners=8 deadOk=6 best=0x0
   gids=0 confirm=0`. Two conclusions follow from those numbers alone.

   FIRST, the shape test cannot be matching noise. A random 8-byte word lands inside the 868 KB
   __DATA_CONST window with probability ~1e-13, and the two small-int fields at +0x3c and +0x40
   make it worse again; over ~68 million aligned words that is an expected count far below one. So
   the ~54 words the test matched are genuine C++ objects of an engine class. 45 of them carry a
   non-heap pointer at +0x20 and 9 carry a heap pointer.

   SECOND, and this is the finding: `hits=9 owners=8`. If +0x20 were the shared owning manager
   there would be ONE owner behind those nine objects, because setOwner stores the same pointer in
   every object it creates. Eight distinct owners for nine objects means the field at +0x20 does
   NOT repeat on this build, so either it is not the owner here or these objects do not belong to
   one manager. Under the old report this fact was invisible: with gids below the minimum the vote
   prints `best=0x0` and NOT ONE class table was ever named, which is the whole reason
   `hooks fired=0` has been unexplained for so long -- the objects that DO exist were in the log
   only as a count.

   v45 therefore stops trying to name the winner and starts naming the OBJECTS. Every word that
   passes the record layout is recorded with the class table it carries, its id, its team, its
   owner index, its dead byte and its owner classified (heap / image span / outside every kernel
   region), and the first of them are printed after each pass, heap-owned ones first. That single
   line per object is the answer to `hooks fired=0`: the RVA printed as `vt=` is the table the live
   objects actually carry, and it is not in the vtprobe list. The top owner by votes is also
   reported regardless of the distinct-id minimum, so `best=0x0` can no longer mean "nothing was
   learned".

   The two owner rejections are also separated. v44 counted both "the owner is inside the image"
   and "the owner is outside the image but inside no region the kernel reported" into one number;
   the second of those is not static data at all, it is a heap pointer the region list failed to
   cover, and folding it into `ownerImg` would hide a region-enumeration bug behind a correct
   looking number. */
#define TNX_OWNER_VOTE_MAX 128
#define TNX_OWNER_VOTE_MIN 3
#define TNX_OWNER_VOTE_GID_MAX 64
#define TNX_OWNER_VOTE_VT_MAX 4
/* v44. A battle container holds BOTH teams. The v43 winner held exactly one (`teams=0x1`), and a
   static table that merely looks like a container will always do the same thing, because its
   "team" field is one constant repeated. Requiring two distinct team values is therefore the
   second filter that the 19:51 false positive cannot pass. An owner that clears the id count but
   not this one is NOT silently dropped: `objvote singleTeam` says so, so the next log can tell
   "the vote found nothing" apart from "the vote found heap owners and rejected them for a reason
   that may itself be wrong". */
#define TNX_OWNER_VOTE_TEAMS_MIN 2
#define TNX_OBJ_OWNERIDX_MAX 0xff
/* An owner has to win two passes in a row before anything is reported, for the same reason the
   trail needs two passes: one sighting of a shared pointer in a heap that is being rewritten
   continuously is not evidence of a manager. 1 means "on the second consecutive pass". */
#define TNX_OWNER_VOTE_CONFIRM 1
/* How many objects of a confirmed owner are printed. Same value as TNX_BEST_DETAIL_MAX, declared
   separately because the vote report sits 450 lines above that define and a use-before-declaration
   is a compile error in C++ (and did break the build of this file once already). */
#define TNX_OWNER_VOTE_DETAIL_MAX 12

/* v45. THE PER-HIT DUMP. Bounded on purpose: a pass that matched a thousand words must not turn
   the log into a megabyte of hex, and the first records of a pass are as good as any because the
   walk is over the whole address space rather than over one region. `TNX_OBJ_HIT_DUMP_MAX` is how
   many are remembered (the rest are only counted, and the count is printed as a floor), and
   `TNX_OBJ_HIT_PRINT_MAX` how many lines come out. Heap-owned hits are printed first -- they are
   the ones that can become a capture -- and only then the rejected ones, so a truncated dump still
   contains the objects that matter. */
#define TNX_OBJ_HIT_DUMP_MAX 64
#define TNX_OBJ_HIT_PRINT_MAX 24

/* v46. THE VTABLE CENSUS -- and the reason the nine-entry list above stops being the question.

   The 20:22 run answered what v45 was built for, in one dump. The live objects carry class tables
   of their OWN and not one of them is in the probe list:

       vt=0xf923e0   vt=0xf92468   vt=0x100a770   vt=0x1014f70   vt=0x1008be0   vt=0x1009290

   and 0x100a770 alone appears under three separate heap-owned objects. The vote still could not
   name an owner: `maxVotes=1` in all three passes, with a DIFFERENT topOwner in each, i.e. no
   pointer at +0x20 ever collected a second vote. So the next hook cannot come from a list written
   by hand -- the classes that exist have to be counted first, and that is all this does.

   Every 16-byte aligned word of the pass whose value lands inside __DATA_CONST or __DATA is one
   INSTANCE of the class table at that RVA, and the census counts them per table:

     - random words cannot pollute it. __DATA_CONST is 868 KB and __DATA 1.1 MB, so an arbitrary
       8-byte value lands in either with probability ~2e-13 -- far below one hit over the ~34
       million aligned words of a pass;
     - `count=` is the number of live instances of that class in the bytes this pass scanned, which
       is the number that decides whether a class is worth hooking: tens of thousands is a leaf
       object, five to fifty is a battle entity;
     - `shaped=` counts how many of those instances ALSO passed the full object record layout (id,
       team, owner index, 16-byte-aligned owner). Those are the instances that look like game
       objects and not merely like C++ objects, and that column is the bridge from "a class exists"
       to "a class is worth hooking";
     - `ownerEqVt=` counts instances whose word at +0x20 is the SAME value as the word at +0x00.
       That is the arithmetic signature of the 19:51 false-positive family, which until now existed
       only as one hand-written equation in a comment. Here it is a count.

   __DATA is included on purpose: the 20:22 log's `modehit[near]` lines show three __DATA slots
   holding pointers into __TEXT (RVA 0x1b076c, 0x1b0920, 0x1b0a34), i.e. tables that live in
   __DATA on this build. Counting only __DATA_CONST would have made them invisible.

   The table is reset per pass for the same reason the vote table is: so the pass line and the dump
   describe one pass and two passes can be compared. `spill=` means the entry table filled up,
   which makes `distinct=` a floor rather than a count. */
#define TNX_VTCENSUS_MAX 384
#define TNX_VTCENSUS_PRINT 16
#define TNX_VTCENSUS_SLOTS 12

/* v46. THE READ BUDGET BECOMES A FUNCTION OF THE WINDOW.

   The 20:22 log settles a question four versions got wrong. Both heap passes read ~540 MB and both
   were cut off by the fixed 512 MB budget: pass 1 from 0x0 (which is ~520 MB of memory BELOW the
   window plus a few MB of the window itself) and pass 3 from the window low. The two passes
   therefore did not scan the same memory, and that is why the ninth vtprobe counter read 0 in
   pass 1 and 92502 in pass 3 over two "identical" 540 MB sweeps. `next=0x2e6000000` on pass 1 was
   never evidence of reaching the top of anything.

   So the budget now follows the window: window span plus 64 MB, never below the old constant and
   never above the cap. The window on this build is ~567 MB once the region list has been rebuilt,
   so from then on one pass covers the whole of it -- which is the only condition under which
   `vtprobe=0` means anything at all. The cap keeps a bogus 7776 MB window from turning one pass
   into a minute of scanning, and `budget=`/`budgetHit=` in the pass line say which of the two
   happened instead of leaving it to be inferred from `scanned=`. */
#define TNX_HEAP_SCAN_BUDGET_MAX (768ull * 1024ull * 1024ull)

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

/* The two object slots titanox_37..41 treated as getX and getY, and what they really are.

   REvengeBS has getX/getY/getZ at 0xb5e44c / 0xb5e454 / 0xb5e45c, eight bytes apart, and on that
   reference they are slots 0x88/0x90/0x98. That mapping does not hold on THIS build, and the
   proof is the engine's own call site at RVA 0xae48f0 -- the very code the earlier claim rested
   on. It loads an argument before every call:

       ldr w1, [x20, #8] ; ldr x8, [x19] ; ldr x8, [x8, #0x88] ; mov x0, x19 ; blr x8

   and repeats that five times with [x20+0x18], [x20+0x1c], [x20+0x20] and [x20+0x34]. A getter
   takes no argument, so on this build the entry is setter-like, not getX.

   The names stay because the offsets are still what matter, but nothing is called through them
   any more: the reader only reports the RVA of the function found in the slot. A coordinate
   source has to be found again, and the mode's own plain fields +0x1d4/+0x1d8 are the candidate
   that needs no vtable at all. */
#define TNX_OBJ_GETX_SLOT 0x88ULL
#define TNX_OBJ_GETY_SLOT 0x90ULL
#define TNX_MODE_MODEVAR_OFF 0x124ULL

/* The mode's own predicted position, as a plain field pair: the only setter of +0x1d4/+0x1d8 in
   the whole image is 0xac3f20, a void(pointer,int,int), and the offsets come from REvengeBS.
   They are read directly out of the scan buffer in the chain probe, which is why the mode is
   worth having: the dodge then needs no vtable call at all. */
#define TNX_MODE_PREDICTX_OFF 0x1d4ULL
#define TNX_MODE_PREDICTY_OFF 0x1d8ULL
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
/* setOwner(object, manager) is `str x1,[x0,#0x20]` at 0xa2d250, so a captured class-B object
   carries the manager at +0x20. Class A reaches it as [[this+0x8]+0x0] instead. */
#define TNX_SLOT_OWNER_OFF 0x20ULL
#define TNX_SLOT_LIST_OFF 0x80ULL
#define TNX_SLOT_LISTCOUNT_OFF 0x8cULL

/* Printed as the first line after "setup", so every log identifies the build that produced
   it. Two device logs were once spent comparing a new binary against an old one. */
#define TNX_BUILD_TAG "titanox_47"

/* ---------------------------------------------------------------------------
   v47. THE OBJECT LAYOUT STOPS BEING A GUESS, BECAUSE THE ENGINE STATES IT.

   genebrawl-public -- a Frida mod for Brawl Stars 62.250/62.258, read 2026-10-02 --
   publishes its STRUCT offsets unredacted: tools/remove_offsets.py rewrites only
   `Libg.offset(a, b)` call sites, so every plain field offset in its classes survived.
   Two of its claims were then checked against OUR binary, instruction by instruction,
   and both hold:

     0xac3d80   the engine's own findByTeam walk
                ldrsw x10, [x0, #0xc]        count  is at +0xc
                ldr   x11, [x0]              array  is at +0x0
                ldr   x11, [x11, x9, lsl #3] element = array[i]
                ldr   w12, [x11, #0x4c]      TEAM   is at +0x4c
                ldrb  w11, [x11, #0x1e8]     active flag, bit 0
     0xac3f48   ldr w8,[x0,#0x1fc] / ldr x8,[x0,#0xf8] / ldr w8,[x8,#0xc4]
                madd w8, w8, w2, w1          tileIndex = y * mapWidth + x
                (0xac3f2c reads [x0+0x28] then +0x8c/+0x90 -- the same manager)

   Both sit in the LogicBattleModeClient region around 0xac3xxx and both read the very
   offsets this file has used since v42, so three things are now settled by the engine
   rather than by a shape test: `[mode+0x28]` IS the object manager, `[mgr+0x0]` IS its
   element array with the count at `[mgr+0xc]`, and `[mode+0xf8]` IS the tile map with
   the map width at `+0xc4`. The mode object we carry is therefore the LOGIC battle mode
   client -- not the display one -- which is why the repository's `BattleMode` numbers
   never fitted it.

   What the repository adds on top:

       LogicGameObjectClient   X = int32 @ +0x30      Y = int32 @ +0x34

   v46 read the team from +0x40; the engine reads it from +0x4c. v47 prints BOTH for
   every object instead of picking one, because exactly one of them is the team and the
   log is what decides which.

   THE ACTUATOR. 0xac3f20 is a complete function of three instructions:

       str w1, [x0, #0x1d4]
       str w2, [x0, #0x1d8]
       ret

   i.e. setPredictionXY(this, x, y) -- the only writer of those two fields anywhere in
   the image, and the same destination the repository knows as
   setClientPredictionMoveTo. It is called only after its three words are matched at
   runtime, so a build that moves the function disables the dodge instead of landing in
   the middle of whatever now lives there. The dodge itself is gated twice: the
   fingerprint must match AND the coordinate probe below must have found real, distinct,
   in-range positions on live objects. Nothing is written until both are true.
   --------------------------------------------------------------------------- */
#define TNX_RVA_SETPREDICTION 0x00ac3f20ULL
#define TNX_OBJ_X_OFF 0x30ULL
#define TNX_OBJ_Y_OFF 0x34ULL
#define TNX_OBJ_TEAMENGINE_OFF 0x4cULL
#define TNX_OBJ_ACTIVEFLAG_OFF 0x1e8ULL
#define TNX_MODE_TILEMAP_OFF 0xf8ULL
#define TNX_TILEMAP_WIDTH_OFF 0xc4ULL
#define TNX_TILEMAP_HEIGHT_OFF 0xc8ULL
/* The engine's own reads are trusted only up to a point: a coordinate that is not a
   small number is not a coordinate. Map sizes seen so far are two-digit. */
#define TNX_V47_COORD_ABS_MAX 1000000
#define TNX_V47_MAP_MIN 4
#define TNX_V47_MAP_MAX 512
#define TNX_V47_OBJECT_MAX 64
#define TNX_V47_DODGE_MIN_MS 100
#define TNX_V47_LOG_FIRST 12
#define TNX_V47_LOG_EVERY 64
/* While the coordinate verdict is still failing the probe retries on this period, so a
   battle that starts after the verdict was formed on a lobby object is still picked up. */
#define TNX_V47_REPROBE_MS 5000
/* The prediction pair has to land ON an object. 10000 units is far looser than any real
   client prediction should be, and the point is exactly to reject the case where the two
   fields are not a position at all: then the nearest object is arbitrarily far away. */
#define TNX_V47_OWN_MAX_SQ 100000000LL

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
static int g_manager_skipped = 0;
static int g_manager_last_live = 0;
static int g_manager_last_nonempty = 0;
static int g_manager_last_capacity = 0;
static int g_manager_saw_cap = 0;
static int g_manager_loose_count = 0;
static int g_manager_window_rejects = 0;

/* The chain probe and the vtable probe. Every one of these is printed, so that "nothing was
   found" can always be told apart from "nothing was looked at". */
static int g_chain_checks = 0;    /* words whose first field points into __DATA_CONST */
static int g_chain_ready = 0;     /* ... and that passed every free test before the syscalls */
static int g_chain_probes = 0;    /* expensive manager tests actually run */
static int g_chain_skipped = 0;   /* safety valve reached -- blindness has to be visible */
static int g_chain_best_live = 0;
static int g_chain_best_own = 0;
static int g_chain_best_gid = 0;
static int g_seen_stable = 0;     /* candidates that held the same count in two passes */
static uintptr_t g_chain_vtable = 0;
static unsigned long long g_vtprobe_hits[TNX_VTPROBE_COUNT];

/* The object vote. `g_objvote_hits` is the count of words that looked like a game object,
   `g_objvote_skipped` the ones dropped because the vote table was full -- printed so a silent
   cap can never be mistaken for an absence of objects. */
typedef struct {
    uintptr_t owner;                           /* the pointer the objects carry at +0x20 */
    int votes;                                 /* object-shaped words that named this owner */
    int teamMask;                              /* teams seen, one bit per team value */
    int deadOk;                                /* of its objects, how many had a 0/1 byte at +0xd0 */
    int vtCount;
    uintptr_t vt[TNX_OWNER_VOTE_VT_MAX];       /* the class tables seen on its objects */
    uint32_t gidSeen[TNX_OWNER_VOTE_GID_MAX];  /* the DISTINCT global ids seen at this owner */
    int gidSeenCount;                          /* number of distinct ids, capped at GID_MAX */
    int gidFull;                               /* the id list is full -> the count printed is a floor */
} tnx_owner_vote_t;

static tnx_owner_vote_t g_owner_votes[TNX_OWNER_VOTE_MAX];
static int g_owner_vote_count = 0;
static unsigned long long g_objvote_hits = 0;
static unsigned long long g_objvote_skipped = 0;
static int g_objvote_dead_seen = 0;            /* hits whose +0xd0 really was a 0/1 byte */
static uintptr_t g_objvote_best_owner = 0;
static int g_objvote_best_gids = 0;
static uintptr_t g_objvote_prev_owner = 0;     /* the same owner winning two passes in a row */
static int g_objvote_confirm = 0;
static BOOL g_objvote_owner_ok = NO;           /* confirmed owner -> the verdict may say so */

/* v44 reject counters. Every one of these is printed, because the failure mode being fixed here
   was precisely a candidate that was ACCEPTED for a reason nobody could see in the log. */
static unsigned long long g_objvote_owner_img = 0;   /* +0x20 pointed into a mapped image segment */
static unsigned long long g_objvote_obj_img = 0;     /* the word itself was static image data */
static int g_objvote_best_teamcount = 0;             /* distinct teams of the current gid winner */
static int g_objvote_best_gids_full = 0;             /* that winner's id list was full (floor) */
static int g_objvote_single_team_logs = 0;           /* held back owners reported, rate limited */
static int g_heap_img_skip = 0;                      /* writable regions belonging to the image */

/* v45. One record per object-shaped word, kept so the pass can NAME what it found instead of only
   counting it. `ownerClass` is the reason the word did or did not reach the vote, and it is
   recorded for every word so the three groups can be compared: 0 = the owner is positive heap (the
   word voted), 1 = the owner sits inside the image span (static data), 2 = the owner is a pointer
   outside the image but inside no region the kernel reported -- not static data at all, and the
   one group whose size would reveal a region-enumeration bug. */
typedef struct {
    uintptr_t at;          /* the word's own address */
    uintptr_t vt;          /* the raw value at +0x00, i.e. the class table */
    uintptr_t owner;       /* the raw value at +0x20 */
    int32_t gid;
    int32_t team;
    int32_t ownerIdx;
    int dead;
    int ownerClass;
} tnx_objhit_t;

static tnx_objhit_t g_objhits[TNX_OBJ_HIT_DUMP_MAX];
static int g_objhit_count = 0;
static int g_objhit_full = 0;                        /* more shaped words than the dump can hold */
static unsigned long long g_objvote_owner_reg = 0;   /* +0x20 outside the image, in no kernel region */
/* v46. ...and a fourth bucket, because the 20:22 run put 398 of its 597 shaped words in
   `ownerNoRegion` and that number has two completely different explanations. The window is rebuilt
   from the region list every tenth attempt and it SHRANK during that run -- 7776 MB at pass 1,
   567 MB at pass 3 -- and one owner test rejects anything at or above the window high. An owner
   above a window that moved is a WINDOW problem (the list is fine and the test's idea of "the heap"
   is too narrow); an owner in no region at all is a REGION problem. Folding them together is the
   same mistake v44 made with ownerImg, one level down. */
static unsigned long long g_objvote_owner_above_win = 0;
static int g_objvote_max_votes = 0;                  /* most votes any owner collected this pass */
static uintptr_t g_objvote_top_owner = 0;            /* the owner behind that number */

/* v46. Uncapped, and that is the point. `g_objhit_count` stops at the dump table's size, so the
   identity `hits + skipped + ownerImg + ownerNoRegion = objShaped` could not be checked against it:
   on the 20:22 run the left side came to 597 while the right side printed `64+`. A counter that is
   allowed to stop counting turns the completeness check into decoration. */
static unsigned long long g_objvote_shaped = 0;

/* v46. The census. One entry per distinct class table seen at a 16-byte-aligned word of the pass,
   in either data segment, with the three numbers that decide whether that class is interesting:
   how many instances exist, how many of them passed the full object record layout, and how many
   carry the same value at +0x00 and +0x20 (the 19:51 false-positive signature, now counted rather
   than reasoned about). */
typedef struct {
    uintptr_t rva;
    int seg;                                  /* 0 = __DATA_CONST, 1 = __DATA */
    unsigned long long count;                 /* instances in the bytes this pass scanned */
    unsigned long long shaped;                /* of those, how many passed the record layout */
    unsigned long long ownerEqVt;             /* of those, how many read the same at +0x00 and +0x20 */
    uintptr_t first;                          /* where the first instance was seen */
} tnx_vtcensus_t;

static tnx_vtcensus_t g_vtcensus[TNX_VTCENSUS_MAX];
static int g_vtcensus_used = 0;
static unsigned long long g_vtcensus_total = 0;
static unsigned long long g_vtcensus_spill = 0;
static uintptr_t g_vtcensus_dc_lo = 0;
static uintptr_t g_vtcensus_dc_hi = 0;
static uintptr_t g_vtcensus_d_lo = 0;
static uintptr_t g_vtcensus_d_hi = 0;

/* v46. The vtprobe counters accumulate across passes (that is what the pass line's `vtprobeAll=`
   prints), so no single pass line can say what THAT pass counted. This snapshot turns the
   difference into a printed number. The 20:22 run is exactly why it is needed: pass 1 printed nine
   zeros and pass 3 printed 92502 on the ninth entry, over two passes that both reported ~540 MB
   scanned, and nothing in the log said which pass produced which. `vtprobeFirst=` is the same idea
   applied to the address: it names the first word that ever incremented each counter. */
static unsigned long long g_vtprobe_pass[TNX_VTPROBE_COUNT];
static uintptr_t g_vtprobe_first[TNX_VTPROBE_COUNT];

/* v45. Why the pass line needs these. The walker drops any region larger than 1 GB (the process
   maps a ~385 GB guard) and its `continue` never touched a counter, so an arena hidden in one
   region that large would have been invisible in a log that otherwise looks complete. The window
   enumerator is capped at 512 regions for the same reason. Both are now counted and printed.

   The oversize counter is split, because the two halves mean opposite things: an oversize region
   that is WRITABLE is memory this scan cannot see and could hold the battle (`bigSkip`/`bigBytes`),
   while an oversize region that is not writable is the guard and means nothing (`hugeSkip`). A
   single merged number would have reported ~385 GB of alarm on every run and been ignored by the
   second log. With the split, `regions=` is closed exactly: regions (counted after the guard) =
   imgSkip + roSkip + the ones actually walked, and bigSkip + hugeSkip are the ones the guard
   removed before they were counted. */
static int g_heap_ro_skip = 0;                       /* counted, not writable or under one page */
static int g_heap_big_skip = 0;                      /* WRITABLE and over 1 GB: memory we cannot see */
static unsigned long long g_heap_big_bytes = 0;      /* how much address space that was */
static int g_heap_huge_skip = 0;                     /* over 1 GB and not writable: the guard */
static int g_heap_region_capped = 0;                 /* the 512-entry region list was truncated */

/* The image's own address span, cached once per region refresh. The per-call walker
   (tnx_image_contains / tnx_image_segment_name) reads the Mach-O header on every call, which is
   fine for a candidate but not for a test that runs on every aligned word of every pass. */
static uintptr_t g_img_span_lo = 0;
static uintptr_t g_img_span_hi = 0;
static int g_img_span_ok = 0;

/* Declared here because the heap pass line reports it long before the trail itself exists. */
static int g_trail_best = 0;
static int g_manager_cap_rejects = 0;
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

/* The second register argument, kept from the very first hit. This is the one value the whole
   exercise has been missing. Disassembly of LogicGameObjectManager::addGameObject at 0xa27930:

        ldr x0, [sp, #0x28]        ; the object being added
        ldr x8, [x0]; ldr x8, [x8, #0x18]
        mov x1, x19                ; x19 = the manager (x0 on entry to addGameObject)
        blr x8

   and the slot it calls is byte RVA 0xff5738 -- exactly our B2, whose target 0xa2d250 is
   `str x1, [x0, #0x20]`, i.e. setOwner(object, manager). So on the first game object created in
   a match the forwarder is handed the manager itself in a1, and until now it threw that away. */
static uintptr_t g_slot_arg1[TNX_SLOT_COUNT] = { 0 };
static uint64_t g_slot_hits[TNX_SLOT_COUNT] = { 0 };
static uint64_t g_slot_hits_total = 0;
static int g_slot_installed[TNX_SLOT_COUNT] = { -1, -1, -1, -1, -1, -1, -1 };
static uint32_t g_slot_reported_mask = 0;
static uintptr_t g_slot_adopted = 0;
static int g_ag_adopted = 0;

static void tnx_slot_diag(const char *why);

/* Defined next to the object dump, but needed earlier by the manager dump too. */
static BOOL tnx_obj_slot_fn(uintptr_t object, uintptr_t slot, uintptr_t *rvaOut);
static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty);
static void tnx_trail_dump(void);
static void tnx_best_candidate_dump(void);
/* Declared here because the heap pass, which runs long before either is defined, reports a
   confirmed owner by name. */
static void tnx_report_manager(const char *tag, uintptr_t manager);
static int tnx_object_detail_readonly(uintptr_t manager, int limit);
/* v47. The verified dodge is defined next to the object readers at the bottom of the
   file, but the workload that drives it is far above, so it is declared here. */
static void tnx_autododge_v47(void);

/* Runs inside the game's thread. Two stores and a bounds check, nothing else. */
static void tnx_slot_note(int index, void *self, uint64_t arg1) {
    if (index < 0 || index >= TNX_SLOT_COUNT) return;

    g_slot_hits[index]++;

    if (!g_slot_object[index] && self) g_slot_object[index] = (uintptr_t)self;

    /* Kept separately and never overwritten: the manager set by setOwner is the same pointer for
       every object in the match, so the first one is the one worth having. */
    if (!g_slot_arg1[index] && arg1) g_slot_arg1[index] = (uintptr_t)arg1;
}

/* One replacement per slot: a rewritten vtable entry cannot tell which slot invoked it, so
   each target gets its own tiny forwarder. All five were checked offline to return void or
   a plain integer in w0/x0 and to take no floating-point arguments, which is what makes
   forwarding the eight incoming integer registers safe. */
static uint64_t tnx_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(0, a0, a1);

    if (g_slot_orig[0]) return g_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(1, a0, a1);

    if (g_slot_orig[1]) return g_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(2, a0, a1);

    if (g_slot_orig[2]) return g_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(3, a0, a1);

    if (g_slot_orig[3]) return g_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(4, a0, a1);

    if (g_slot_orig[4]) return g_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(5, a0, a1);

    if (g_slot_orig[5]) return g_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

static uint64_t tnx_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(6, a0, a1);

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
    /* B2 is setOwner: 0xa2d250 is `str x1,[x0,#0x20]`, and addGameObject calls it with the
       manager in x1. This is the slot that hands us the manager. */
    { "B2/vt0ff5720+03/a2d250 setOwner", "B2", 0x00a2d250ULL, 0x00ff5738ULL, tnx_slot_repl_3, 0 },
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

/* v47 RETIRES this body without deleting the record of it. It was driven by RVA_*
   constants taken from the community offsets table, 130 of whose 146 entries are
   mid-function addresses; `tnx_callable` rejects those, so every pointer below stayed
   zero and the function returned on its own first line in EVERY version that carried
   it. That is why nothing ever dodged -- not because the layout was unknown. It is
   renamed and kept compiled rather than called, so the numbers it used stay checkable
   against a future build. */
static void tnx_run_autododge_legacy(void) {
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

/* v47. The only dodge entry point the workload calls. The reasoning lives in
   tnx_autododge_v47, next to the object readers, where every helper it needs is already
   defined. */
static void tnx_run_autododge(void) {
    tnx_autododge_v47();
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
    { "LogicBattleModeClient::findOwningTeam (mgr+0x28,team@0x40)", 0xac3ddc },
    { "LogicBattleModeClient::findOwningTeam2 (mgr+0x28)", 0xac3e74 },
    { "LogicBattleModeClient::managerProgress (mgr+0x8c/0x90)", 0xac3f2c },
    { "GameObj::setOwner (this+0x20 = manager) [slot 0xff5738]", 0xa2d250 },
    { "LogicBattleModeClient::setPredictionXY (this+0x1d4/0x1d8)", 0xac3f20 },
    { "LogicGameObjectManager::findByTeam (mgr+0x0/+0xc)", 0xac3d80 },
    { "LogicGameObjectManager::addGameObject", 0xa278a8 },
    { "LogicGameObjectManager::generateGameObjectGlobalID", 0xa27b98 },
    { "LogicProjectileData::getColumnValue", 0x9cd5e0 },
    { "GameObj::setOwner (this+0x20 = manager)", 0xa2d250 },
    { "Array<T>::append (header layout source)", 0x46aefc },
    { "LogicGameObjectClient data accessor", 0x382cc8 },
    { "LogicBattleModeClient::getInt (+0xec)", 0xac3500 },
    { "LogicBattleModeClient::get 0x218", 0xac40d8 },
    { "LogicBattleModeClient::get 0x220", 0xac40e8 },
    { "LogicBattleModeClient::get 0x228", 0xac40f8 },
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

/* v44: the image's own span, computed once, so the test "is this word part of the loaded
   program" costs two compares instead of a Mach-O header walk. Segments of one image are
   contiguous at runtime (__TEXT ends exactly where __DATA_CONST begins, and so on), so a single
   interval is exact here and the interior of the interval is never something a game object can
   live in. */
static void tnx_image_span_refresh(void) {
    g_img_span_lo = 0;
    g_img_span_hi = 0;
    g_img_span_ok = 0;

    if (!g_base || !tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) break;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) break;
        if (cursor + command->cmdsize > limit) break;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;
                uintptr_t end = start + (uintptr_t)segment->vmsize;

                if (!g_img_span_lo || start < g_img_span_lo) g_img_span_lo = start;
                if (end > g_img_span_hi) g_img_span_hi = end;
            }
        }

        cursor += command->cmdsize;
    }

    g_img_span_ok = (g_img_span_hi > g_img_span_lo) ? 1 : 0;
}

/* The O(1) form. Falls back to the exact walker if the span was never computed, so a caller that
   runs before the first region refresh still gets a correct answer. */
static BOOL tnx_in_image_span(uintptr_t value) {
    if (!value) return NO;
    if (!g_img_span_ok) return tnx_image_contains(value);

    return (value >= g_img_span_lo && value < g_img_span_hi) ? YES : NO;
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


/* ======================================================================================
   THE HEAP WINDOW. This is the filter that the previous four versions were missing, and
   the numbers on the device say exactly why it was needed.

   titanox_38 pre-filtered a candidate on: the 32-bit word at +0xc looks like a count, the
   word at +0x8 looks like a capacity, and the pointer at +0x0 is above 0x10000, eight byte
   aligned, sixteen byte aligned, and not inside the image. On the device that let
   loose=616976 candidates through the tight bound and 1217701 through every free check,
   against a probe budget of 65536 -- so the budget was gone inside the first pass and the
   remaining heap was never examined at all.

   The missing observation is embarrassingly simple: every heap pointer this process has ever
   been seen to hold -- 0x1040cffa8, 0x1049c5710, 0x1054e5280, 0x12a41c140, 0x12a6765f8 --
   and every heap pointer in every log across four different image slides, has its top thirty
   two bits equal to 1. The process heap lives in one 4 GB window and the image and the guard
   regions do not. Testing that costs one shift and one compare, no syscall, and it removes
   the overwhelming majority of what was being probed.

   The region list is the second half: built once from the kernel, it answers positively --
   this address is inside a writable, non-image, ordinary sized region -- instead of the old
   negative test, which only ever said "not in the image" and therefore accepted everything
   else in a 385 GB address space.
   ====================================================================================== */

#define TNX_HEAP_REGION_MAX 512
#define TNX_HEAP_REGION_MAX_SIZE 0x100000000ULL

typedef struct {
    uintptr_t low;
    uintptr_t high;
} tnx_region_t;

static tnx_region_t g_heap_regions[TNX_HEAP_REGION_MAX];
static int g_heap_region_count = 0;
static uintptr_t g_heap_window_low = 0;
static uintptr_t g_heap_window_high = 0;
static int g_heap_window_ok = 0;

static void tnx_heap_regions_refresh(void) {
    uintptr_t cursor = 0x10000;
    uintptr_t lowest = 0;
    uintptr_t highest = 0;
    int count = 0;

    for (int guard = 0; guard < 8192 && count < TNX_HEAP_REGION_MAX; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) break;
        if (size == 0) break;

        next = start + (uintptr_t)size;
        if (next <= cursor) break;

        if ((protection & VM_PROT_WRITE) &&
            size <= TNX_HEAP_REGION_MAX_SIZE &&
            start >= 0x10000 &&
            !tnx_image_segment_name(start)) {
            g_heap_regions[count].low = start;
            g_heap_regions[count].high = next;
            count++;

            if (!lowest || start < lowest) lowest = start;
            if (next > highest) highest = next;
        }

        cursor = next;
    }

    g_heap_region_count = count;
    g_heap_window_low = lowest;
    g_heap_window_high = highest;
    g_heap_window_ok = count > 0 ? 1 : 0;

    /* v45: the list is capped at TNX_HEAP_REGION_MAX. A truncated list would make
       tnx_heap_contains answer "no" for every owner past the cut, and those owners would be counted
       as rejected for not being heap -- the exact shape of a correct-looking number hiding a broken
       enumeration. Reported on the heapwin line so it can never be silently true. */
    g_heap_region_capped = (count >= TNX_HEAP_REGION_MAX) ? 1 : 0;

    /* Paired with the region list because they answer the same question from opposite sides:
       the list says what the kernel gave us as heap, the span says what belongs to the loaded
       program. v43 had only the first, and it was the second that the 19:51 false positive needed
       -- a window test alone cannot exclude the image, because the image sits INSIDE the window. */
    tnx_image_span_refresh();
}

/* The cheap half: no syscall, one shift. The window is derived from the regions rather than
   hard coded, so a build that puts its heap somewhere else still works. */
static BOOL tnx_heap_window_shaped(uintptr_t value) {
    if (!value) return NO;
    if (!g_heap_window_ok) return YES;          /* nothing to compare against yet */
    if (value < g_heap_window_low) return NO;
    if (value >= g_heap_window_high) return NO;

    return YES;
}

/* The positive half: is this address inside one of the regions the kernel actually gave this
   process as writable, non-image memory of ordinary size. Regions come back in ascending
   order, so the filtered copy stays sorted and a binary search is enough. */
static BOOL tnx_heap_contains(uintptr_t value) {
    int lo = 0;
    int hi = g_heap_region_count - 1;

    if (!value) return NO;

    /* Fail open. If the kernel enumeration produced nothing, fall back to the weaker test the
       earlier versions used rather than rejecting every candidate: a filter that silently
       answers "no" to everything would look exactly like an absence of battles. */
    if (!g_heap_region_count) return tnx_image_segment_name(value) ? NO : YES;

    if (value < g_heap_window_low || value >= g_heap_window_high) return NO;

    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;

        if (value < g_heap_regions[mid].low) {
            hi = mid - 1;
        } else if (value >= g_heap_regions[mid].high) {
            lo = mid + 1;
        } else {
            return YES;
        }
    }

    return NO;
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

/* v44: THE test the object vote was missing, and the whole reason the 19:51 run captured a
   static table. `tnx_heap_window_shaped` is a NEGATIVE test over an interval whose low edge
   (0x10447c000) sits below the image base (0x108fd0000), so every address of the loaded program
   passes it. A manager has to be positively identified as heap:

     1. it must not sit anywhere inside the image's own span (one interval compare, cached), and
     2. it must sit inside a region the kernel actually reported as ordinary writable memory.

   The observed false positive fails both: 0x109fd8d30 is inside __DATA_CONST with the span test,
   and it is not in the region list because the list drops regions whose start is an image
   segment. Failing either one is enough; keeping both means no single enumeration quirk can let
   static data through again. */
static BOOL tnx_owner_is_heap(uintptr_t owner) {
    if (!owner) return NO;
    if (tnx_in_image_span(owner)) return NO;
    if (!tnx_heap_resident(owner)) return NO;

    /* tnx_heap_contains fails open when the region list is empty, which is the behaviour wanted:
       it then reduces to the residency test above instead of rejecting everything. */
    return tnx_heap_contains(owner);
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
    int32_t capacity = 0;

    /* No vtable check on the manager: per the verified disassembly of
       LogicGameObjectManager its word at +0x0 is the object array, not a vtable.
       Only residency plus array/count shape is required here. */
    if (!tnx_heap_resident(manager)) return NO;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return NO;
    if (count < 0 || count > TNX_MANAGER_MAX_OBJECTS) return NO;

    /* The header invariant from the engine's own append routine. */
    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return NO;

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
    if (count < TNX_MODE_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;
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

        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETY_SLOT, &s90);

        tnx_logf("mgr[%d] element=%p gameobj=%d gid=%d team=%d own=%d dead=%d "
                 "s88=%#llx s90=%#llx",
                 i, element, tnx_gameobject_shape((uintptr_t)element) ? 1 : 0,
                 globalId, team, owner, dead,
                 (unsigned long long)s88, (unsigned long long)s90);

        tnx_dump_hex("mgrObj", (uintptr_t)element, 0x100);
    }
}

/* How many of the first entries of a manager-shaped object are heap objects that
   themselves look like C++ instances. This single number is what separates a battle
   manager from a lobby container, and it is also what the verdict below reports. */
static int tnx_manager_live_count(uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int live = 0;

    /* Cleared up front. Every early return below leaves these at the values for THIS
       candidate instead of the previous one -- which is why titanox_38 printed 65536 trail
       entries that all read count/cap/live 27/27/6 and hid the real closest miss. */
    g_manager_last_capacity = 0;
    g_manager_last_live = 0;
    g_manager_last_nonempty = 0;

    if (!tnx_pointer_plausible(manager)) return 0;
    if (!tnx_heap_contains(manager)) return 0;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;

    g_manager_last_capacity = capacity;
    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return 0;
    if (!array) return 0;
    if (!tnx_heap_contains((uintptr_t)array)) return 0;
    if ((uintptr_t)array & 0xf) return 0;

    /* Header invariant taken from the engine's own append routine: count <= capacity, and a
       capacity of four billion is not a capacity. */
    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return 0;

    uintptr_t types[TNX_MODE_TYPE_MAX] = {0};
    int typeCount = 0;
    int nonEmpty = 0;

    /* Every entry, not just the first eight. A real object array holds objects in every slot;
       the string containers that keep fooling the scanner hold text in all of them. */
    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        nonEmpty++;

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

    /* Three quarters of the occupied slots have to be real instances. A real object array is
       exactly that; a string or resource table decodes as instances in only a couple of slots,
       which is how the 18:16 run reached live=4 out of count=21 and then locked the scan. */
    g_manager_last_live = live;
    g_manager_last_nonempty = nonEmpty;

    if (live < TNX_MANAGER_MIN_OBJECTS || live * 4 < nonEmpty * 3) {
        g_manager_last_live = live;
        g_manager_last_nonempty = nonEmpty;
        g_manager_last_capacity = capacity;
        return 0;
    }

    g_manager_last_live = live;
    g_manager_last_nonempty = nonEmpty;
    g_manager_last_capacity = capacity;

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

    /* titanox_41 bailed out here the moment a container had been adopted. On the 19:19 run that
       happened 1.1 s after launch, and every later pass line then reported `probes=0/65536` --
       passes 2 and 3 looked at nothing at all -- so a single false positive ended the scan
       before the lobby had finished loading. The scan now stops only once the chain has
       confirmed a mode, which is three levels of evidence instead of one. */
    if (g_mode_strong) return;
    if (offset + 0x10 > chunk) return;

    uint32_t capacity = 0;

    memcpy(&arrayValue, buffer + offset, sizeof(arrayValue));
    memcpy(&capacity, buffer + offset + TNX_MGR_CAP_OFF, sizeof(capacity));
    memcpy(&count, buffer + offset + 0xc, sizeof(count));

    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return;

    /* Free, straight out of the engine's own append routine: count never exceeds capacity, and
       no real object array is ever allocated four billion entries. The 18:16 candidate is
       rejected right here -- 0xffffffff capacity -- which is why it needs no syscall at all. */
    if (capacity < count || capacity > TNX_MGR_CAP_MAX) {
        g_manager_saw_cap++;
        g_manager_cap_rejects++;
        return;
    }

    /* And the tight bound, which is the one that actually matters. The append routine at
       0x46aefc grows with `lsl w9, w8, #1` -- new capacity is exactly twice the old count, with
       a floor of 5 -- so for any array holding three or more entries `capacity` can never
       exceed `count * 2`. titanox_37 accepted only `capacity <= 4096`, and on the device that
       let 2,031,646 words through: 1,454,207 of them passed every free check, so the 65536
       probe budget was gone inside the first pass and the rest of the heap was never looked at.
       This bound costs nothing and removes almost all of them. */
    if (capacity > count * 2) {
        g_manager_saw_cap++;
        g_manager_cap_rejects++;
        return;
    }

    g_manager_saw_cap++;

    if (!tnx_pointer_plausible((uintptr_t)arrayValue)) return;

    /* A heap allocation is 16-byte aligned. A word that is only 8-byte aligned is a field
       pointer or plain garbage, and rejecting it here costs nothing -- no syscall. */
    if ((uintptr_t)arrayValue & 0xf) return;

    /* The window test first: free, and it alone removes most of the flood. */
    if (!tnx_heap_window_shaped((uintptr_t)arrayValue)) {
        g_manager_window_rejects++;
        return;
    }

    /* Then the positive test, which the previous versions did not have at all. */
    if (!tnx_heap_contains((uintptr_t)arrayValue)) {
        g_manager_window_rejects++;
        return;
    }

    /* Counted, not silently dropped: if this ever fires the pass line says so instead of the
       scan quietly going blind the way it did on the previous run. */
    g_manager_loose_count++;

    if (g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) {
        g_manager_skipped++;
        return;
    }

    g_manager_probes++;
    g_manager_probes_total++;

    candidate = cursor + offset;
    live = tnx_manager_live_count(candidate);

    /* Record the closest miss too: this is what says whether the shape is absent or
       merely never complete. */
    if ((int)count > g_manager_best_count) g_manager_best_count = (int)count;
    if (live > g_manager_best_live) g_manager_best_live = live;

    /* The closest miss, recorded BEFORE the rejection -- in titanox_37 this sat after it and
       was therefore unreachable, which is why every run printed "trail: 0 candidates" while
       simultaneously reporting bestCount=96. A diagnostic that can never fire is worse than no
       diagnostic: it looks like evidence of absence. */
    if (live < TNX_MANAGER_MIN_OBJECTS) {
        tnx_trail_note(candidate, (int32_t)count, g_manager_last_capacity,
                       g_manager_last_live, g_manager_last_nonempty);
        return;
    }

    /* A CONTAINER THAT PASSED THE ARRAY TEST IS NOT A CAPTURE, and titanox_41 treated it as one.

       The 19:19 run adopted 0x112844d28 as the manager on the strength of count=4 live=4 and
       capacity 7 -- every free test passed. Its four elements are config records, not game
       objects: their fields from +0x0c to +0x9c are the float constants 1.0, 20.0, 100.0, 60.0,
       0.075, 0.02, 0.15, 0.01, 2.0, 18.0, 3.0, 90.0 and 45.0, their +0x20 is 0 on all four, and
       their global id is 1 on all four -- a value no two objects created by addGameObject can
       share. One array test cannot tell such a table from a manager, so on this path the
       candidate is recorded and reported but never adopted; adoption belongs to the chain, where
       the mode, its [mode+0x28] manager and that manager's array have to agree at once. */
    if (!g_manager_object && !g_objvote_owner_ok) {
        g_manager_object = candidate;
        g_manager_count = (int)count;

        tnx_logf("MANAGER candidate object=%p count=%u live=%d recorded, NOT adopted",
                 (void *)candidate, count, live);

        tnx_dump_manager(candidate, (int)count);
    }
}

/* THE CHAIN PROBE: the missing link between everything already known and a live battle.

   Every earlier version looked for the mode by its vtable -- 37 hardcoded RVAs plus the two
   verified ones -- and never found it: all 194 candidates that `votescan __DATA` reports have
   their first word in __TEXT, so they are not objects at all. Meanwhile the layout was already
   known exactly: [mode+0x28] is the manager, the manager's [+0x0] is the array and its [+0xc]
   the count. The mode can therefore be recognised by its CHAIN instead of by its identity, and
   no vtable list is needed to find it.

   The first two tests carry the meaning and are free: the first word has to point into
   __DATA_CONST and +0x28 has to be a plausible heap pointer. The next two (+0x124 small,
   +0x1d4/+0x1d8 plausible) are also read straight out of the buffer, so the syscall-heavy
   manager test runs on very few words per pass. */
static void tnx_probe_mode_chain(uintptr_t cursor, size_t offset, const uint8_t *buffer,
                                 size_t chunk, uintptr_t dcLo, uintptr_t dcHi) {
    uintptr_t vtable = 0;
    uintptr_t manager = 0;
    uintptr_t input = 0;
    int32_t variation = 0;
    int32_t px = 0;
    int32_t py = 0;
    int32_t count = 0;
    void *array = NULL;

    if (g_mode_strong) return;

    /* One bound for every read below, decided by the largest of them: +0x1d8 plus four bytes is
       the furthest word this function looks at, so +0x1dc is the guard. The buffer is exactly
       `chunk` bytes -- the last chunk of a region is usually the short one -- and reading past
       the end of it would be an out-of-bounds read on the render thread. */
    if (offset + TNX_MODE_PREDICTY_OFF + 4 > chunk) return;

    memcpy(&vtable, buffer + offset, sizeof(vtable));

    if (!vtable || (vtable & 0x7)) return;
    if (vtable < dcLo || vtable >= dcHi) return;

    g_chain_checks++;

    memcpy(&manager, buffer + offset + TNX_MODE_MANAGER_OFF, sizeof(manager));

    if (!manager || (manager & 0xf)) return;
    if (!tnx_pointer_plausible(manager)) return;
    if (!tnx_heap_window_shaped(manager)) return;

    /* The engine itself compares this field against 0x29 at 0xac3cfc, so it is a small integer
       and requiring that costs nothing. */
    memcpy(&variation, buffer + offset + TNX_MODE_MODEVAR_OFF, sizeof(variation));

    if (variation < 0 || variation > 400) return;

    memcpy(&px, buffer + offset + TNX_MODE_PREDICTX_OFF, sizeof(px));
    memcpy(&py, buffer + offset + TNX_MODE_PREDICTY_OFF, sizeof(py));

    if (px < -0x100000 || px > 0x100000) return;
    if (py < -0x100000 || py > 0x100000) return;

    memcpy(&input, buffer + offset + TNX_MODE_INPUTMGR_OFF, sizeof(input));

    if (input && !tnx_heap_window_shaped(input)) return;

    g_chain_ready++;

    if (g_chain_probes >= TNX_CHAIN_PROBE_LIMIT) {
        g_chain_skipped++;
        return;
    }

    g_chain_probes++;

    if (!tnx_manager_shape(manager)) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (!array) return;
    if (count < TNX_MODE_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return;

    /* The two identity tests that the observed false positive fails outright. addGameObject
       hands every object a fresh global id at +0x8 (0xa278e4) and setOwner writes the manager
       into +0x20 (str x1,[x0,#0x20]); that config table had id 1 on all four entries and 0 in
       +0x20 on all four. Both are counted and printed BEFORE the decision, so a rejection is
       visible in the log instead of silent. */
    int live = 0;
    int ownMatch = 0;
    int gidDistinct = 0;
    int32_t gids[TNX_MODE_TYPE_MAX];

    for (int i = 0; i < TNX_MODE_TYPE_MAX; i++) gids[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *owner = NULL;
        int32_t gid = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_gameobject_shape((uintptr_t)element)) continue;

        live++;

        if (tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid)) {
            BOOL known = NO;

            for (int k = 0; k < gidDistinct; k++) {
                if (gids[k] == gid) {
                    known = YES;
                    break;
                }
            }

            if (!known && gidDistinct < TNX_MODE_TYPE_MAX) gids[gidDistinct++] = gid;
        }

        if (tnx_read_ptr((uintptr_t)element + TNX_SLOT_OWNER_OFF, &owner)) {
            if ((uintptr_t)owner == manager) ownMatch++;
        }
    }

    if (live > g_chain_best_live) g_chain_best_live = live;
    if (ownMatch > g_chain_best_own) g_chain_best_own = ownMatch;
    if (gidDistinct > g_chain_best_gid) g_chain_best_gid = gidDistinct;

    uintptr_t object = cursor + offset;

    tnx_logf("chain cand mode=%p vt=%#llx mgr=%p count=%d live=%d ownMatch=%d gidDistinct=%d "
             "var=%d input=%p",
             (void *)object, (unsigned long long)(vtable - g_base), (void *)manager, count,
             live, ownMatch, gidDistinct, variation, (void *)input);

    if (live < TNX_MODE_MIN_OBJECTS) return;
    if (ownMatch < 1) return;
    if (gidDistinct < 2) return;

    g_chain_vtable = vtable;

    tnx_adopt_mode(object, YES, "chain");
}

/* How many live heap objects carry the vtable of each hooked class.

   This is the measurement that separates the two readings of `hooks fired=0`, which look
   identical in every log so far: either no instance of those seven classes is ever created, or
   instances exist and the slot we rewrote is never dispatched. Only a word at an object's own
   start counts, i.e. one at a 16-byte aligned offset, because a stored pointer to some other
   object's vtable would otherwise be counted as an instance.

   The alignment test is on the ABSOLUTE address, not on the offset inside the chunk. The chunk
   walker advances by `chunk - 8` so that a word straddling two chunks is still seen, which means
   the chunk base drifts 8 bytes out of phase on every step; `offset & 0xf` therefore answered a
   different question on every second chunk, and half of the 16-byte aligned objects were
   invisible to this probe. */
static void tnx_vtprobe_note(uintptr_t vtable, uintptr_t absolute) {
    uintptr_t rva = 0;

    if (!vtable || !g_base) return;
    if (absolute & 0xf) return;
    if (vtable < g_base + TNX_DC_RVA_LO) return;
    if (vtable >= g_base + TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) return;

    rva = vtable - g_base;

    for (int k = 0; k < TNX_VTPROBE_COUNT; k++) {
        if (rva == g_vtprobe_rva[k]) {
            g_vtprobe_hits[k]++;

            /* v46. Kept for the same reason the per-pass delta is kept: a running total that jumps
               between two passes has to be attributable to an address, or the jump cannot be told
               apart from a counter that is incrementing for the wrong reason. */
            if (!g_vtprobe_first[k]) g_vtprobe_first[k] = absolute;

            return;
        }
    }
}

/* ---------------------------------------------------------------------------
   v46. THE VTABLE CENSUS.

   Why this replaces guessing. `hooks fired=0 of 7` had one candidate explanation left -- the hooked
   classes are simply not instantiated -- and the vtprobe list could only test the nine tables
   somebody had already named. The 20:22 run's objhit dump named six tables that DO exist and are
   not in that list, and named them one instance at a time. The census counts every table instead:
   whatever the live heap points at, in either data segment, ranked by how many instances carry it.

   The cost is one range test per 16-byte aligned word of the pass and a linear scan only when a
   word prints. The linear scan is over `g_vtcensus_used` entries, which is the number of DISTINCT
   class tables, not the number of instances: 92502 instances of one table cost 92502 comparisons
   against a list that stays a few dozen long.
   --------------------------------------------------------------------------- */

/* 0 = __DATA_CONST, 1 = __DATA, -1 = not a class table. Both ranges are captured once per pass from
   the image's own Mach-O segments, never hard coded, so a different slide or a rebuilt image moves
   them with it. */
static int tnx_vtcensus_seg(uintptr_t value) {
    if (!value || !g_base) return -1;
    if (g_vtcensus_dc_lo && value >= g_vtcensus_dc_lo && value < g_vtcensus_dc_hi) return 0;
    if (g_vtcensus_d_lo && value >= g_vtcensus_d_lo && value < g_vtcensus_d_hi) return 1;

    return -1;
}

static void tnx_vtcensus_reset(void) {
    g_vtcensus_used = 0;
    g_vtcensus_total = 0;
    g_vtcensus_spill = 0;

    memset(g_vtcensus, 0, sizeof(g_vtcensus));
}

/* Found or, when asked, created. A NULL return with `create` set means the table is full, and that
   is counted by the caller as spill -- an entry that cannot be created must never be silently
   merged into another one. */
static tnx_vtcensus_t *tnx_vtcensus_entry(uintptr_t rva, int seg, int create) {
    for (int i = 0; i < g_vtcensus_used; i++) {
        if (g_vtcensus[i].rva == rva && g_vtcensus[i].seg == seg) return &g_vtcensus[i];
    }

    if (!create) return NULL;
    if (g_vtcensus_used >= TNX_VTCENSUS_MAX) {
        g_vtcensus_spill++;

        return NULL;
    }

    tnx_vtcensus_t *entry = &g_vtcensus[g_vtcensus_used++];

    memset(entry, 0, sizeof(*entry));
    entry->rva = rva;
    entry->seg = seg;

    return entry;
}

static void tnx_vtcensus_note(uintptr_t vtable, uintptr_t absolute, const uint8_t *buffer,
                              size_t offset, size_t chunk) {
    if (absolute & 0xf) return;
    if (vtable & 7) return;

    int seg = tnx_vtcensus_seg(vtable);

    if (seg < 0) return;

    tnx_vtcensus_t *entry = tnx_vtcensus_entry(vtable - g_base, seg, 1);

    if (!entry) return;

    entry->count++;
    g_vtcensus_total++;

    if (!entry->first) entry->first = absolute;

    /* The +0x20 word is read only where the buffer really holds it. `w20 != vtable` is not an
       error, it is the normal case; counting how often the two fields agree is what turns the
       19:51 signature from an observation about one run into a number about every run. */
    if (offset + TNX_SLOT_OWNER_OFF + sizeof(uintptr_t) <= chunk) {
        uintptr_t w20 = 0;

        memcpy(&w20, buffer + offset + TNX_SLOT_OWNER_OFF, sizeof(w20));

        if (w20 == vtable) entry->ownerEqVt++;
    }
}

/* Called from the object vote for every word that passed the WHOLE record layout. Looks up, never
   creates: the word was already counted by the walk (the vote only ever runs on a word whose value
   is a table in __DATA_CONST), so a missing entry would mean the two callers disagree, and creating
   one here would hide exactly that. */
static void tnx_vtcensus_shaped(uintptr_t vtable) {
    int seg = tnx_vtcensus_seg(vtable);

    if (seg < 0) return;

    tnx_vtcensus_t *entry = tnx_vtcensus_entry(vtable - g_base, seg, 0);

    if (entry) entry->shaped++;
}

/* The best entry by a chosen column. Used twice per pass: once for the most INSTANCES and once for
   the most SHAPED instances. They answer different questions -- the first is the most common object
   in the heap, the second is the class that most looks like a game object -- and on a build where
   the two differ, the second is the one to hook. */
static int tnx_vtcensus_top(int byShaped) {
    int best = -1;

    for (int i = 0; i < g_vtcensus_used; i++) {
        unsigned long long here = byShaped ? g_vtcensus[i].shaped : g_vtcensus[i].count;

        if (!here) continue;

        if (best < 0) {
            best = i;

            continue;
        }

        unsigned long long there = byShaped ? g_vtcensus[best].shaped : g_vtcensus[best].count;

        if (here > there) best = i;
    }

    return best;
}

/* The first slots of one class table, as RVAs. This is the line the NEXT version needs: a table
   whose slots all resolve into __TEXT is a vtable and its slot RVAs are the hook targets, which is
   how every hook in this file was chosen. Printed for at most two tables per pass, because the
   interesting thing is not the volume but the first table that has instances and looks like a game
   object. */
static void tnx_vtcensus_slots(const tnx_vtcensus_t *entry) {
    uint8_t bytes[TNX_VTCENSUS_SLOTS * sizeof(uintptr_t)];
    char listed[512];
    int used = 0;

    if (!entry) return;
    if (!tnx_copy(g_base + entry->rva, bytes, sizeof(bytes))) {
        tnx_logf("vtslots rva=%#llx seg=%c unreadable - the table moved or is not mapped",
                 (unsigned long long)entry->rva, entry->seg ? 'D' : 'C');

        return;
    }

    for (int i = 0; i < TNX_VTCENSUS_SLOTS; i++) {
        uintptr_t slot = 0;

        memcpy(&slot, bytes + (size_t)i * sizeof(uintptr_t), sizeof(slot));

        if (used > (int)sizeof(listed) - 24) break;

        used += snprintf(listed + used, sizeof(listed) - (size_t)used, "%s%#llx", i ? "," : "",
                         (unsigned long long)(slot > g_base ? slot - g_base : 0));
    }

    tnx_logf("vtslots rva=%#llx seg=%c count=%llu shaped=%llu slotRvas=%s",
             (unsigned long long)entry->rva, entry->seg ? 'D' : 'C', entry->count, entry->shaped,
             listed);
}

static void tnx_vtcensus_dump(void) {
    int chosen[TNX_VTCENSUS_PRINT];
    int nchosen = 0;

    /* Printed even when empty: `vtcensus empty` and no vtcensus line at all are different facts,
       and the 20:22 run's whole problem was a number that could not be told apart from its absence. */
    tnx_logf("vtcensus pass=%d distinct=%d%s total=%llu spill=%llu dc=%p..%p data=%p..%p",
             g_heap_passes, g_vtcensus_used, g_vtcensus_spill ? "+" : "", g_vtcensus_total,
             g_vtcensus_spill, (void *)g_vtcensus_dc_lo, (void *)g_vtcensus_dc_hi,
             (void *)g_vtcensus_d_lo, (void *)g_vtcensus_d_hi);

    for (int k = 0; k < TNX_VTCENSUS_PRINT; k++) {
        int best = -1;

        for (int i = 0; i < g_vtcensus_used; i++) {
            int taken = 0;

            for (int j = 0; j < nchosen; j++) {
                if (chosen[j] == i) {
                    taken = 1;

                    break;
                }
            }

            if (taken) continue;
            if (best < 0 || g_vtcensus[i].count > g_vtcensus[best].count) best = i;
        }

        if (best < 0) break;

        chosen[nchosen++] = best;

        const tnx_vtcensus_t *entry = &g_vtcensus[best];

        tnx_logf("vtcensus #%d rva=%#llx seg=%c count=%llu shaped=%llu ownerEqVt=%llu first=%p", k,
                 (unsigned long long)entry->rva, entry->seg ? 'D' : 'C', entry->count,
                 entry->shaped, entry->ownerEqVt, (void *)entry->first);
    }

    int most = tnx_vtcensus_top(0);
    int mostShaped = tnx_vtcensus_top(1);

    if (most >= 0) tnx_vtcensus_slots(&g_vtcensus[most]);
    if (mostShaped >= 0 && mostShaped != most) tnx_vtcensus_slots(&g_vtcensus[mostShaped]);
}

/* ---------------------------------------------------------------------------
   THE OBJECT VOTE.

   One entry per owner pointer seen at +0x20 of an object-shaped word. The table is cleared at
   the start of every heap pass, so a winner is always this pass's winner and two passes can be
   compared.
   --------------------------------------------------------------------------- */
static tnx_owner_vote_t *tnx_owner_vote_slot(uintptr_t owner) {
    for (int i = 0; i < g_owner_vote_count; i++) {
        if (g_owner_votes[i].owner == owner) return &g_owner_votes[i];
    }

    if (g_owner_vote_count >= TNX_OWNER_VOTE_MAX) return NULL;

    tnx_owner_vote_t *entry = &g_owner_votes[g_owner_vote_count++];

    memset(entry, 0, sizeof(*entry));
    entry->owner = owner;

    return entry;
}

static void tnx_owner_vote_note(tnx_owner_vote_t *entry, int32_t gid, int32_t team, int deadOk,
                                uintptr_t vtable) {
    BOOL known = NO;

    entry->votes++;

    /* Distinct ids only. This is the number the whole vote rests on: setOwner writes the same
       manager into every object, but addGameObject gives every object its own id, so a real
       manager accumulates MANY ids while the 19:19 config table -- four entries, all id 1 --
       accumulates exactly one. */
    for (int i = 0; i < entry->gidSeenCount; i++) {
        if (entry->gidSeen[i] == (uint32_t)gid) {
            known = YES;
            break;
        }
    }

    if (!known) {
        if (entry->gidSeenCount < TNX_OWNER_VOTE_GID_MAX) {
            entry->gidSeen[entry->gidSeenCount++] = (uint32_t)gid;
        } else {
            /* v43 printed `distinctGids=16` for a winner that saturated its 16-entry list, so the
               number the whole selector rests on could not be read as a quantity at all. The list
               is 64 long now and a full list is reported as a floor (`64+`) rather than as an
               exact count -- an id count that is silently capped is the same class of error as a
               probe limit that goes quiet. */
            entry->gidFull = 1;
        }
    }

    if (team >= 0 && team < 32) entry->teamMask |= (1 << team);
    if (deadOk) entry->deadOk++;

    if (vtable) {
        BOOL have = NO;

        for (int i = 0; i < entry->vtCount; i++) {
            if (entry->vt[i] == vtable) {
                have = YES;
                break;
            }
        }

        /* The class tables this owner's objects carry. Reported, because a table that is not
           one of the seven already hooked is the direct explanation of `hooks fired=0`. */
        if (!have && entry->vtCount < TNX_OWNER_VOTE_VT_MAX) entry->vt[entry->vtCount++] = vtable;
    }
}

/* v45. Keep one record per object-shaped word, so that a pass which found objects but no winner can
   still say WHAT it found. This is the gap the 20:06 run exposed: `hits=9 owners=8 best=0x0` names
   nothing at all, and the class table of the live objects -- the one number that explains
   `hooks fired=0` -- was in the log only as an absence. */
static void tnx_objhit_note(uintptr_t at, uintptr_t vt, uintptr_t owner, int32_t gid, int32_t team,
                            int32_t ownerIdx, int dead, int ownerClass) {
    if (g_objhit_count >= TNX_OBJ_HIT_DUMP_MAX) {
        g_objhit_full = 1;

        return;
    }

    tnx_objhit_t *hit = &g_objhits[g_objhit_count++];

    hit->at = at;
    hit->vt = vt;
    hit->owner = owner;
    hit->gid = gid;
    hit->team = team;
    hit->ownerIdx = ownerIdx;
    hit->dead = dead;
    hit->ownerClass = ownerClass;
}

/* Heap-owned first (class 0), then image, then noRegion. A dump that has to be cut short must still
   contain the words that could become a capture, so the order is not the scan order. `vt=` is the
   class table as an RVA, the only form in which it can be compared with the vtprobe list. */
static void tnx_objhit_dump(void) {
    static const char *const names[4] = { "heap", "image", "noRegion", "aboveWin" };
    int printed = 0;

    if (!g_objhit_count) return;

    for (int want = 0; want < 4 && printed < TNX_OBJ_HIT_PRINT_MAX; want++) {
        for (int i = 0; i < g_objhit_count && printed < TNX_OBJ_HIT_PRINT_MAX; i++) {
            const tnx_objhit_t *hit = &g_objhits[i];

            if (hit->ownerClass != want) continue;

            tnx_logf("objhit pass=%d #%d at=%p vt=%#llx gid=%d team=%d own=%d dead=%d owner=%p "
                     "ownerClass=%s",
                     g_heap_passes, printed, (void *)hit->at,
                     (unsigned long long)(hit->vt > g_base ? hit->vt - g_base : 0), hit->gid,
                     hit->team, hit->ownerIdx, hit->dead, (void *)hit->owner, names[want]);

            printed++;
        }
    }

    if (g_objhit_full || printed < g_objhit_count) {
        tnx_logf("objhit truncated: shown=%d recorded=%d%s - the real number of shaped words is the "
                 "objvote line's hits+skipped+ownerImg+ownerNoRegion+ownerAboveWin", printed,
                 g_objhit_count,
                 g_objhit_full ? "+" : "");
    }
}

/* Runs for every aligned word of a chunk, entirely out of the buffer: not one syscall until a
   word has already satisfied the whole record layout. `absolute` is the word's real address --
   the 16-byte start test has to be on that, because the chunk walker steps by `chunk - 8` and
   the chunk base is therefore out of phase with the 16-byte grid on every second chunk. */
static void tnx_probe_object_vote(uintptr_t cursor, size_t offset, const uint8_t *buffer,
                                  size_t chunk, uintptr_t dcLo, uintptr_t dcHi) {
    uintptr_t absolute = cursor + offset;
    uintptr_t vtable = 0;
    uintptr_t owner = 0;
    int32_t gid = 0;
    int32_t team = 0;
    int32_t ownerIdx = 0;
    int deadOk = 0;
    int ownerClass = 0;

    if (g_mode_strong) return;

    /* Objects are heap allocations and heap allocations are 16-byte aligned; a stored pointer
       to some other object's table is not an object. */
    if (absolute & 0xf) return;
    if (offset + TNX_OBJ_DEADFLAG_OFF + 1 > chunk) return;

    /* v44: and the word itself must not be part of the loaded program. The pass walker reaches the
       image's writable segments too (it only checks VM_PROT_WRITE), and that is where the whole
       candidate family of the 19:51 run came from. The scan now skips those regions outright
       (see g_heap_img_skip in the pass line), so this counter reading zero is itself a check that
       the skip is doing its job. */
    if (tnx_in_image_span(absolute)) {
        g_objvote_obj_img++;
        return;
    }

    memcpy(&vtable, buffer + offset, sizeof(vtable));

    /* Field 1: the class table, inside __DATA_CONST. Every engine object has one, and this is
       the reason the scan needs no list of class names at all. */
    if (vtable < dcLo || vtable >= dcHi) return;
    if (vtable & 7) return;

    /* Field 2: the global id addGameObject writes at 0xa278e4. Zero is not an id it produces. */
    memcpy(&gid, buffer + offset + TNX_OBJ_GLOBALID_OFF, sizeof(gid));

    if (gid <= 0) return;

    /* Field 3: team, a small non-negative int. */
    memcpy(&team, buffer + offset + TNX_OBJ_TEAM_OFF, sizeof(team));

    if (team < 0 || team > TNX_OBJ_TEAM_MAX) return;

    /* Field 4: owner index, an int. Wide bound on purpose -- this one is a sanity filter, not a
       layout claim. */
    memcpy(&ownerIdx, buffer + offset + TNX_OBJ_OWNERINDEX_OFF, sizeof(ownerIdx));

    if (ownerIdx < 0 || ownerIdx > TNX_OBJ_OWNERIDX_MAX) return;

    /* Field 5: the owning manager, which setOwner stores with `str x1,[x0,#0x20]`. */
    memcpy(&owner, buffer + offset + TNX_SLOT_OWNER_OFF, sizeof(owner));

    if (!owner || (owner & 0xf)) return;

    /* The dead flag at +0xd0 is COUNTED, not required. It is the one field here whose offset
       comes only from the reference implementation, and gating the selector on an unverified
       constant is exactly how one wrong offset blinds a whole search: `objvote deadOk=` reports
       how often it really is a 0/1 byte, so the next log says whether it holds on this build.

       v45 reads it here, before the owner is judged, because the per-hit dump reports the dead
       byte of every shaped word and not only of the ones that reached the vote. */
    deadOk = (buffer[offset + TNX_OBJ_DEADFLAG_OFF] <= 1) ? 1 : 0;

    /* v43 tested only this: `tnx_heap_window_shaped(owner)`. The window's low edge is below the
       image base, so static image data passed and the winner of the 19:51 run was
       owner=0x109fd8d30 -- __DATA_CONST -- with `vt0` equal to owner minus base. The positive
       residency test replaces it.

        v45 counts the ways that test can fail SEPARATELY, and v46 finds one more of them. An owner
        inside the image span is static data; an owner outside the image but inside no region the
        kernel reported is a heap pointer the region list failed to cover; and an owner above the
        window high, on a run whose window was rebuilt halfway through and got 7200 MB smaller, is
        neither -- it is a real pointer outside a window that is too small. v44 folded all of this
        into `ownerImg`, which is exactly the kind of merged counter that lets a broken enumeration
        hide behind a correct-looking number -- the 20:06 run printed `ownerImg=45` and no log could
        tell which of the causes it was. */
    /* Judged once and kept: tnx_owner_is_heap walks to the Mach-O header through
       tnx_heap_resident, and doing that three times per shaped word would cost more than the whole
       buffer-local test it belongs to. */
    ownerClass = tnx_owner_is_heap(owner) ? 0 : (tnx_in_image_span(owner) ? 1 : 2);

    /* The image span is tested before the window on purpose: an address inside the loaded program
       is static data whether or not it is also above the window high, and reporting it as "above
       the window" would turn the one case that is a real false positive into an arithmetic quirk.
       Only what is left -- outside the image, above the window, in no region -- gets the new
       bucket, and that combination points at the window rather than at the region list. */
    if (ownerClass == 2 && g_heap_window_high && owner >= g_heap_window_high) ownerClass = 3;

    if (ownerClass == 1) g_objvote_owner_img++;
    else if (ownerClass == 2) g_objvote_owner_reg++;
    else if (ownerClass == 3) g_objvote_owner_above_win++;

    /* Recorded whether or not it goes on to vote: the dump's job is to say what the word IS, and
       the rejected ones are what a truncated dump is allowed to drop first. */
    tnx_objhit_note(absolute, vtable, owner, gid, team, ownerIdx, deadOk, ownerClass);

    /* v46. Counted here, where the word has passed EVERY field, so `objShaped=` in the objvote line
       is the true number and the identity hits + skipped + ownerImg + ownerNoRegion + ownerAboveWin
       = objShaped can actually be checked. The dump's own count stays capped, and says so
       separately as objhitRec=. */
    g_objvote_shaped++;

    /* And the class table is credited with one game-object-shaped instance. The census entry already
       exists -- this word was counted by the walk one line earlier, and the vote only runs on values
       inside __DATA_CONST -- so this lookup never creates. */
    tnx_vtcensus_shaped(vtable);

    if (ownerClass != 0) return;

    tnx_owner_vote_t *entry = tnx_owner_vote_slot(owner);

    if (!entry) {
        g_objvote_skipped++;
        return;
    }

    if (deadOk) g_objvote_dead_seen++;

    g_objvote_hits++;
    tnx_owner_vote_note(entry, gid, team, deadOk, vtable);
}

/* Distinct team values behind the bitmask. v43 printed the mask alone (`teams=0x1`), and a mask
   is not readable as "one team" versus "five teams" without doing the arithmetic by hand. */
static int tnx_team_count(int mask) {
    int n = 0;

    for (int i = 0; i < 32; i++) {
        if (mask & (1 << i)) n++;
    }

    return n;
}

/* Called once at the end of every heap pass, BEFORE that pass's summary line. v43 called it
   after, which is why the pass line reported the previous pass's winner: on the 19:51 run the
   pass line said `best=0x0` while the `objvote owner=` line right below it named 0x109fda770,
   and one pass later the roles swapped. Everything below is computed and only then printed, so
   no field of either line can describe a different pass from the other. */
static void tnx_object_vote_finish(void) {
    int best = -1;
    int top = -1;

    for (int i = 0; i < g_owner_vote_count; i++) {
        if (g_owner_votes[i].gidSeenCount < TNX_OWNER_VOTE_MIN) continue;
        if (best < 0 || g_owner_votes[i].gidSeenCount > g_owner_votes[best].gidSeenCount) best = i;
    }

    /* v45. The owner with the most votes, regardless of the distinct-id minimum. `best=0x0` used to
       mean the log had learned nothing at all, which is what the 20:06 run printed while holding
       eight heap owners and nine real objects in hand. Whether the winner is the winner is a
       separate question from what the vote actually saw; this number answers the second one. */
    for (int i = 0; i < g_owner_vote_count; i++) {
        if (top < 0 || g_owner_votes[i].votes > g_owner_votes[top].votes) top = i;
    }

    g_objvote_max_votes = top >= 0 ? g_owner_votes[top].votes : 0;
    g_objvote_top_owner = top >= 0 ? g_owner_votes[top].owner : 0;

    tnx_owner_vote_t *entry = NULL;

    if (best < 0) {
        g_objvote_confirm = 0;
        g_objvote_best_teamcount = 0;
        g_objvote_best_gids_full = 0;
    } else {
        entry = &g_owner_votes[best];

        if (entry->owner == g_objvote_prev_owner) g_objvote_confirm++;
        else g_objvote_confirm = 0;

        g_objvote_prev_owner = entry->owner;
        g_objvote_best_owner = entry->owner;
        g_objvote_best_gids = entry->gidSeenCount;
        g_objvote_best_gids_full = entry->gidFull;
        g_objvote_best_teamcount = tnx_team_count(entry->teamMask);
    }

    /* Always printed, even at zero. `objvote hits=0` and `objvote hits=4000` mean completely
       different things and no log should be able to confuse the two. The reject counters are here
       for the same purpose -- ownerImg / ownerNoRegion / ownerAboveWin are three different reasons
       for a word not to vote, and each has a different fix -- and `objShaped=` is their sum with
       `hits=` and `skipped=`, which is what turns a small `owners=` from a mystery into a
       measurement. `gids=64+` means the distinct-id list was full, so the printed number is a
       floor, not a count. */
    tnx_logf("objvote pass=%d hits=%llu skipped=%llu owners=%d deadOk=%d best=%p gids=%d%s "
             "confirm=%d teamCount=%d ownerImg=%llu ownerNoRegion=%llu ownerAboveWin=%llu "
             "objImg=%llu objShaped=%llu "
             "objhitRec=%d%s "
             "maxVotes=%d topOwner=%p teamsMin=%d",
             g_heap_passes, g_objvote_hits, g_objvote_skipped, g_owner_vote_count,
             g_objvote_dead_seen, (void *)g_objvote_best_owner, g_objvote_best_gids,
             g_objvote_best_gids_full ? "+" : "", g_objvote_confirm, g_objvote_best_teamcount,
             g_objvote_owner_img, g_objvote_owner_reg, g_objvote_owner_above_win, g_objvote_obj_img,
             g_objvote_shaped,
             g_objhit_count, g_objhit_full ? "+" : "", g_objvote_max_votes, (void *)g_objvote_top_owner,
             TNX_OWNER_VOTE_TEAMS_MIN);

    /* The objects themselves, not just how many there were. Printed before the pass line so the two
       lines can never describe different passes, and after the summary so a reader who stops at the
       summary still gets the counts. */
    tnx_objhit_dump();

    if (!entry) return;

    /* The class tables of a real game object, LEARNED rather than assumed. If vt0 is not one of
       the seven tables that are already hooked, that single number is the answer to
       `hooks fired=0`, and it is also the table to hook next -- which is exactly what the 19:51
       run produced (vt0=0x1008d30) and why the ninth vtprobe entry exists. */
    tnx_logf("objvote owner=%p distinctGids=%d%s votes=%d teams=%#x teamCount=%d deadOk=%d "
             "vtCount=%d vt0=%#llx vt1=%#llx vt2=%#llx vt3=%#llx",
             (void *)entry->owner, entry->gidSeenCount, entry->gidFull ? "+" : "", entry->votes,
             entry->teamMask, g_objvote_best_teamcount, entry->deadOk, entry->vtCount,
             (unsigned long long)(entry->vt[0] > g_base ? entry->vt[0] - g_base : 0),
             (unsigned long long)(entry->vt[1] > g_base ? entry->vt[1] - g_base : 0),
             (unsigned long long)(entry->vt[2] > g_base ? entry->vt[2] - g_base : 0),
             (unsigned long long)(entry->vt[3] > g_base ? entry->vt[3] - g_base : 0));

    if (g_objvote_confirm < TNX_OWNER_VOTE_CONFIRM) return;
    /* NOT `if (g_manager_object) return;`. That variable is also written by the array-shaped
       path, which records candidates it explicitly does not trust; letting an untrusted
       candidate veto the vote is the same "one false positive kills the run" defect that made
       titanox_41's passes 2 and 3 do zero probes. Only a confirmed owner stops this. */
    if (g_objvote_owner_ok) return;

    /* v44: THE SECOND FILTER. The distinct-id test alone accepted the 19:51 winner, which held
       exactly one team value on all of its objects -- `teams=0x1` -- while a battle container
       holds both teams. Static data can satisfy "many distinct ids at one pointer" (it is a
       lookup table; every row has a different key), and it always fails "two teams", because its
       team column is one constant. The owner is NOT discarded silently: it is named, with its
       reason, up to four times per run, so a log that never captures anything still says which
       gate stopped it. The confirmation streak is reset because an owner that just failed a gate
       must not be one pass away from being reported. */
    if (g_objvote_best_teamcount < TNX_OWNER_VOTE_TEAMS_MIN) {
        g_objvote_confirm = 0;

        if (g_objvote_single_team_logs < 4) {
            g_objvote_single_team_logs++;

            tnx_logf("objvote singleTeam owner=%p teamCount=%d teams=%#x distinctGids=%d%s votes=%d "
                     "deadOk=%d vt0=%#llx - held back: a battle container carries both teams, and a "
                     "table that merely looks like one repeats a single team value",
                     (void *)entry->owner, g_objvote_best_teamcount, entry->teamMask,
                     entry->gidSeenCount, entry->gidFull ? "+" : "", entry->votes, entry->deadOk,
                     (unsigned long long)(entry->vt[0] > g_base ? entry->vt[0] - g_base : 0));
        }

        return;
    }

    /* Confirmed the same way the trail demands it: the same owner, with several different ids
       on its objects and more than one team, in two consecutive passes. Only then is it worth a
       full dump. */
    tnx_battle_begin("objvote");

    g_objvote_owner_ok = YES;
    g_manager_object = entry->owner;
    g_manager_count = entry->gidSeenCount;

    tnx_report_manager("objvote", entry->owner);
    tnx_object_detail_readonly(entry->owner, TNX_OWNER_VOTE_DETAIL_MAX);
}

/* The line that has to be read first in every future log: how often each hook was entered, and
   whether the rewritten slot still holds our replacement. A slot that silently reverted would
   make every other number meaningless, and "no capture" on its own could not tell the two
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
    /* agmgr, not mgr: this value is g_ag_manager, the in-line capture, and the 19:19 log printed
       `slotdiag ... mgr=0x0` in the same heartbeat as `DIAG ... mgr=0x112844d28`. Two different
       variables under one label is what made the log look self-contradictory. */
    tnx_logf("slotdiag(%s) %s AG=%llu/i%d agmgr=%p objs=%d", why ? why : "?", buf,
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

    /* v46. One branch below names the measured class instead of describing the shape of a vote, and
       a verdict built from numbers has to live somewhere that outlives the call. */
    char verdictBuf[512] = {0};

    /* Ordered by what the run established, strongest conclusion first, and the overrides below
       no longer contradict it.

       titanox_41 printed "NO HOOK EVER FIRED and no manager found" as the final override, so the
       19:19 log announced that no manager existed in the same heartbeat whose own DIAG line read
       `mgr=0x112844d28`. A verdict that contradicts the numbers printed beside it is worse than
       no verdict at all, because it is the line that gets read first. */
    /* POSITIVE RESULTS FIRST. titanox_42 put the two blindness branches second and third, which
       meant `SCANNER BLIND` still outranked `MODE ADOPTED` four lines below it -- the same
       contradiction the comment above says was fixed, only one level down. A verdict may not
       deny a capture that the numbers printed beside it report. Blindness is now reported in the
       branches that come after every positive one, and in the terms of the channel it applies to:
       the array test running out of budget says nothing about the object vote, which has no
       budget and did cover the pass. */
    if (g_heap_passes == 0) {
        verdict = "no heap pass completed yet";
    } else if (g_mode_strong) {
        verdict = "MODE ADOPTED through the mode -> manager -> array chain, fields only, nothing called";
    } else if (g_objvote_owner_ok) {
        verdict = "OWNER CAPTURED - a game-object owner was confirmed by the object vote; this is a real battle container";
    } else if (g_objvote_best_gids >= TNX_OWNER_VOTE_MIN &&
               g_objvote_best_teamcount < TNX_OWNER_VOTE_TEAMS_MIN) {
        /* v44. This is the branch the 19:51 run would have taken if the residency test had been
           in place, and it is a genuinely informative state: the selector DID find heap owners
           carrying many distinct ids, and it held them back for a reason that is visible. */
        verdict = "OBJECT VOTE found a heap owner with many distinct ids but ONE team only - a battle container carries both teams, so it is held back, not adopted";
    } else if (g_objvote_best_gids >= TNX_OWNER_VOTE_MIN) {
        verdict = "OBJECT VOTE sees game objects under one owner, but it has not won two passes in a row yet";
    } else if (g_objvote_hits > 0 && g_objvote_max_votes <= 1) {
        /* v45. The state the 20:06 run was in, named instead of left as "partly recognised": nine
           genuine objects behind EIGHT distinct owners. setOwner stores the same pointer in +0x20 of
           every object a manager creates, so a field that never repeats is not that field -- either
           +0x20 is not the owner here, or those objects are not one manager's. Whichever it is, the
           per-hit dump printed above carries the class tables and the ids, and is the line to read
           next. */
        /* The numbers are not hard coded into this sentence: it has to be true for any run that
           lands here, and a verdict that quotes the shape of one old log is a verdict that lies on
           the next one. The counts are in the objvote line printed beside it.

           v46 goes one step further and NAMES the class, because v45's version of this sentence
           ended with "read the objhit dump and work it out". The census already worked it out: the
           table with the most game-object-shaped instances is a measured fact by the time this line
           is built, and its slot RVAs are on the vtslots line. */
        int cidx = tnx_vtcensus_top(1);

        if (cidx < 0) cidx = tnx_vtcensus_top(0);

        if (cidx >= 0) {
            snprintf(verdictBuf, sizeof(verdictBuf),
                     "OBJECT VOTE matched real objects but +0x20 never repeated (%d owners for %llu "
                     "objects), so +0x20 is not the shared owning manager on this build. The class "
                     "tables the live heap really carries are in the vtcensus lines; the one with the "
                     "most game-object-shaped instances is RVA %#llx (%llu instances, %llu shaped) "
                     "and its first slot RVAs are on the vtslots line - that is where the next hook "
                     "goes",
                     g_owner_vote_count, g_objvote_hits,
                     (unsigned long long)g_vtcensus[cidx].rva, g_vtcensus[cidx].count,
                     g_vtcensus[cidx].shaped);
            verdict = verdictBuf;
        } else {
            verdict = "OBJECT VOTE matched real objects but +0x20 never repeated - almost as many owners as objects, so +0x20 is not the shared owning manager on this build; and no table of theirs survived in the census, which is itself the finding - read the objhit dump for the class tables the live objects carry";
        }
    } else if (g_objvote_hits > 0) {
        verdict = "OBJECT VOTE matched object-shaped words but no owner reached the distinct-id minimum - the layout is partly recognised";
    } else if (g_mode_object) {
        verdict = "an object was adopted but the chain is not fully confirmed";
    } else if (g_manager_loose_count == 0 && g_manager_saw_cap == 0) {
        verdict = "NO ARRAY-SHAPED WORD ANYWHERE - the header test itself matched nothing";
    } else if (g_manager_skipped > 0 || g_manager_probes >= TNX_MANAGER_PROBE_LIMIT) {
        verdict = "ARRAY TEST BLIND - its probe budget was exhausted; the object vote is the channel that still covered the whole pass";
    } else if (g_chain_skipped > 0 && !g_mode_object && !g_manager_object) {
        verdict = "CHAIN BLIND - the chain probe hit its limit before the heap was covered, and it found nothing before that; this run proves nothing about the mode";
    } else if (g_manager_best_live >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "a container passed the array test and was recorded, NOT adopted - the chain never matched";
    } else if (g_manager_best_live >= 1) {
        verdict = "manager-shaped array seen, but too few live instances -> not a battle";
    } else if (g_manager_best_count >= TNX_MANAGER_MIN_OBJECTS) {
        verdict = "count at +0xc is in range but entries are not C++ instances -> wrong layout";
    } else if (g_manager_skipped > 0) {
        verdict = "probe budget exhausted -> the pass was blind after that point, raise the limit";
    } else if (g_manager_probes_total == 0 && g_heap_passes > 0) {
        verdict = "no manager-like count at +0xc anywhere -> layout @+0xc wrong, or coverage short";
    } else if (!g_manager_object && g_mode_best_objects < TNX_MANAGER_MIN_OBJECTS &&
               g_heap_passes > 0) {
        verdict = "NO BATTLE IN WINDOW - nothing battle-shaped existed, this says nothing about the layout";
    }

    /* The second, overriding chain that used to sit here is gone, and that is the point.

       It existed so a blind scanner would outrank the other conclusions. That part was right --
       titanox_37 printed "NO BATTLE IN WINDOW" for a run whose probe budget died at 65536 with
       749,337 candidates skipped. What was wrong is that it also overrode a POSITIVE result: the
       19:19 log announced "NO HOOK EVER FIRED and no manager found" in the very heartbeat whose
       DIAG line read `mgr=0x112844d28`, and it is the overridden text that gets read first.

       Blindness and "the header test matched nothing" are now the first two branches of the chain
       above, where they outrank everything as intended. The hook count is reported as its own
       line, because it is a fact about the mechanism, not about the layout -- the layout only
       gets blamed for an absent battle when the battle really is absent. */

    g_slot_hits_total = 0;
    for (int i = 0; i < TNX_SLOT_COUNT; i++) g_slot_hits_total += (uint64_t)g_slot_hits[i];

    tnx_logf("hooks fired=%llu of %d slots (A1=%llu A2=%llu B1=%llu B2=%llu B3=%llu C1=%llu C2=%llu)",
             (unsigned long long)g_slot_hits_total, TNX_SLOT_COUNT,
             (unsigned long long)g_slot_hits[0], (unsigned long long)g_slot_hits[1],
             (unsigned long long)g_slot_hits[2], (unsigned long long)g_slot_hits[3],
             (unsigned long long)g_slot_hits[4], (unsigned long long)g_slot_hits[5],
             (unsigned long long)g_slot_hits[6]);

    /* Said separately and without a claim about the battle, because the two are different
       facts: the hooks were not dispatched, and that says nothing yet about whether a match
       ran. The vtprobe numbers in the pass line decide whether the class even exists. */
    if (g_slot_hits_total == 0 && g_heap_passes > 0) {
        /* v46 RETRACTS the sentence that stood here. v45 announced that the 20:06 run had made
           `vtprobe=0` an answered question by covering the address space completely, and the 20:22
           run refutes it with two numbers from one build: the ninth counter read 0 on a pass that
           scanned 540 MB from 0x0 and 92502 on a pass that scanned 539 MB from the window low. Both
           were cut off by the same fixed 512 MB budget, and because the two passes started in
           different places they were cut off over DIFFERENT memory. Neither was complete, so
           `vtprobe=0` was never the statement it was advertised as -- and the same applies to the
           20:06 conclusion this project has been carrying since.

           The counters accumulate, so a zero is only readable next to its per-pass delta and its
           budget flag: it means something once a pass with budgetHit=0 has covered the window. What
           does answer the question directly is the census, which counts every table the live heap
           points at rather than testing nine names somebody chose by hand. */
        tnx_logf("DIAG note: none of the seven slots was ever dispatched - which is NOT the same as "
                 "the seven classes being absent. The 20:22 run measured a pass from 0x0 and a pass "
                 "from the window low, both cut off by the same byte budget, and the ninth vtprobe "
                 "counter read 0 on the first and 92502 on the second. A zero counts only when that "
                 "pass reports budgetHit=0, which is why the pass line now carries budget=, "
                 "budgetHit= and readTo= beside scanned= and winSpan=. `vtprobePass=` is this pass, "
                 "`vtprobeAll=` the running total, `vtprobeFirst=` the address behind each non-zero "
                 "counter. The classes that DO exist are enumerated by the `vtcensus` lines: "
                 "`count=` is live instances, `shaped=` how many of them also passed the full object "
                 "record layout, and `vtslots` gives the first slot RVAs of the two most interesting "
                 "tables - that is where the next hook goes");
    }

    tnx_trail_dump();

    tnx_best_candidate_dump();

    tnx_logf("DIAG(%s) attempts=%d/%d heapPasses=%d covered=%lluMB probes=%d/%d skipped=%d "
             "capRej=%d/%d bestCount=%d bestLive=%d mgr=%p adopted=%d vfx=%d mx=%d "
             "chain=%d/%d chainSkip=%d stable=%d own=%d gid=%d "
             "objvote=%llu skipped=%llu owners=%d best=%p gids=%d%s confirm=%d teamCount=%d "
             "deadOk=%d ownerImg=%llu ownerNoRegion=%llu ownerAboveWin=%llu objImg=%llu "
             "objShaped=%llu maxVotes=%d "
             "bigSkip=%d vtcensus=%d/%llu",
             why ? why : "?", g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_heap_covered / (1024ull * 1024ull), g_manager_probes_total, TNX_MANAGER_PROBE_LIMIT,
             g_manager_skipped, g_manager_cap_rejects, g_manager_saw_cap,
             g_manager_best_count, g_manager_best_live, (void *)g_manager_object,
             g_mode_strong ? 1 : 0, g_mode_verified_hits, g_mode_best_objects,
             g_chain_checks, g_chain_probes, g_chain_skipped, g_seen_stable,
             g_chain_best_own, g_chain_best_gid,
             g_objvote_hits, g_objvote_skipped, g_owner_vote_count,
             (void *)g_objvote_best_owner, g_objvote_best_gids,
             g_objvote_best_gids_full ? "+" : "", g_objvote_confirm, g_objvote_best_teamcount,
              g_objvote_dead_seen, g_objvote_owner_img, g_objvote_owner_reg,
              g_objvote_owner_above_win, g_objvote_obj_img,
              g_objvote_shaped, g_objvote_max_votes, g_heap_big_skip,
              g_vtcensus_used, g_vtcensus_total);

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

    /* A fresh vote table per pass: the winner then belongs to one pass, and two passes can be
       compared, which is what makes the confirmation below mean something. */
    g_owner_vote_count = 0;
    g_objvote_hits = 0;
    g_objvote_skipped = 0;
    g_objvote_dead_seen = 0;
    g_objvote_owner_img = 0;
    g_objvote_owner_reg = 0;
    g_objvote_owner_above_win = 0;
    g_objvote_obj_img = 0;
    g_objvote_max_votes = 0;
    g_objvote_top_owner = 0;
    g_objhit_count = 0;
    g_objhit_full = 0;
    g_objvote_shaped = 0;
    g_heap_img_skip = 0;
    g_heap_ro_skip = 0;
    g_heap_big_skip = 0;
    g_heap_big_bytes = 0;
    g_heap_huge_skip = 0;

    /* v46. The census is per pass for the same reason the vote table is, and the vtprobe snapshot is
       what separates this pass's contribution from the running total. Both are reset/snapshotted
       here, before a single byte is read, so neither can describe a different pass from the line
       that prints it. */
    tnx_vtcensus_reset();

    for (int k = 0; k < TNX_VTPROBE_COUNT; k++) g_vtprobe_pass[k] = g_vtprobe_hits[k];

    /* The window is captured here and printed with the pass, instead of being read at print time.
       tnx_heap_regions_refresh runs again every tenth attempt, so v43's `span` changed between
       passes that had covered the same address space -- 7723 MB on pass 1, then 655, 657, 678,
       678 MB -- and read like a bug in the walker. Pinned this way it is a fact about the pass. */
    uintptr_t winLo = g_heap_window_low;
    uintptr_t winHi = g_heap_window_high;

    /* v46. THE READ BUDGET, pinned to the pass. The fixed 512 MB constant cut both 20:22 passes
       short, and because the two passes started at different addresses they were cut short on
       DIFFERENT memory -- pass 1 from 0x0, which is mostly memory below the window, and pass 3 from
       the window low. The two `scanned=` values agreed to within 1 MB and the two vtprobe readings
       did not, which is what that disagreement looks like from the outside. Following the window
       makes one pass cover the whole of it, and `budget=`/`budgetHit=` say whether it did. */
    uint64_t budgetNow = (winHi > winLo ? (uint64_t)(winHi - winLo) : 0) + (64ull << 20);

    if (budgetNow < TNX_HEAP_SCAN_BUDGET) budgetNow = TNX_HEAP_SCAN_BUDGET;
    if (budgetNow > TNX_HEAP_SCAN_BUDGET_MAX) budgetNow = TNX_HEAP_SCAN_BUDGET_MAX;

    /* The chain probe needs the runtime bounds of __DATA_CONST, because the test it replaces was
       a hardcoded list of 37 vtable RVAs that the live mode's class is not in. v46 uses the same
       call to give the census its two ranges, so a census entry and an object-vote field-1 test can
       never disagree about what "a table in const data" means. */
    uintptr_t dcLo = 0;
    uintptr_t dcHi = 0;
    BOOL haveDC = tnx_segment_range("__DATA_CONST", &dcLo, &dcHi);

    g_vtcensus_dc_lo = dcLo;
    g_vtcensus_dc_hi = dcHi;
    g_vtcensus_d_lo = 0;
    g_vtcensus_d_hi = 0;
    tnx_segment_range("__DATA", &g_vtcensus_d_lo, &g_vtcensus_d_hi);

    g_heap_passes++;
    int regions = 0;
    int hits = 0;
    int shapeHits = 0;
    int strongHits = 0;
    int verifiedHits = 0;

    /* v46. Where the reading actually stopped, and how many words that was. `scanned=` alone could
       not distinguish "read the whole window" from "read 540 MB of something", which is the exact
       confusion the 20:22 run produced. `readStop` is only set when the budget cut a region short;
       when it is set the cursor resumes THERE, so the unread tail of a region is no longer thrown
       away with it -- the old code advanced to the end of the region and lost that tail forever. */
    uintptr_t readStop = 0;
    size_t words = 0;

    while (regions < 8192 && scanned < budgetNow) {
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

            /* v45: counted instead of swallowed, and split by protection. Skipping is right -- the
               process maps a ~385 GB guard -- but an uncounted skip is the same silent cap that has
               already cost this project several runs. A WRITABLE region this large would be heap
               the scan can never read, so it is reported as bigSkip/bigBytes on the pass line; the
               read-only ones are only counted (hugeSkip), because merging the two would print ~385 GB
               of alarm on every run and be ignored by the second log. */
            if ((info.protection & VM_PROT_WRITE) != 0) {
                g_heap_big_skip++;
                g_heap_big_bytes += (unsigned long long)size;
            } else {
                g_heap_huge_skip++;
            }

            address = (vm_address_t)beyond;

            continue;
        }

        regions++;

        /* v44: the image's own writable segments are neither heap nor a battle, and the walker
           reaches them because it only asks for VM_PROT_WRITE. On the 19:51 run that is exactly
           where every accepted "game object" came from -- the confirmed owner was inside
           __DATA_CONST. Skipping those regions removes the static noise from all four channels at
           once (array test, chain probe, vtprobe, object vote), and `imgSkip=` in the pass line
           reports how many regions were dropped so the skip itself stays measurable. */
        if (tnx_image_segment_name((uintptr_t)address)) {
            g_heap_img_skip++;
        } else if ((info.protection & VM_PROT_WRITE) != 0 && size >= 0x1000) {
            uint64_t remaining = (uint64_t)size;
            uintptr_t cursor = (uintptr_t)address;

            while (remaining >= 16 && scanned < budgetNow) {
                size_t chunk = (size_t)(remaining < TNX_HEAP_CHUNK ? remaining : (uint64_t)TNX_HEAP_CHUNK);
                uint8_t *buffer = (uint8_t *)malloc(chunk);

                if (!buffer) break;

                if (tnx_copy(cursor, buffer, chunk)) {
                    for (size_t offset = 0; offset + sizeof(uintptr_t) <= chunk; offset += sizeof(uintptr_t)) {
                        uintptr_t vtable = 0;

                        memcpy(&vtable, buffer + offset, sizeof(vtable));

                        tnx_probe_manager(cursor, offset, buffer, chunk);

                        /* Absolute address, not the offset: see tnx_vtprobe_note. */
                        tnx_vtprobe_note(vtable, cursor + offset);

                        /* v46. The same word, counted by class instead of matched against nine
                           names. Runs for every 16-byte aligned word of the pass, next to the probe
                           it generalises, so the two can never disagree about which words they saw. */
                        tnx_vtcensus_note(vtable, cursor + offset, buffer, offset, chunk);

                        if (haveDC) {
                            tnx_probe_mode_chain(cursor, offset, buffer, chunk, dcLo, dcHi);

                            /* The selector that needs no vtable list and no array-shape guess:
                               it recognises game objects by the record layout the engine itself
                               writes, and turns them into their manager by voting. */
                            tnx_probe_object_vote(cursor, offset, buffer, chunk, dcLo, dcHi);
                        }

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
                words += chunk / sizeof(uintptr_t);
            }

            /* The budget cut this region short: remember exactly where, because the tail of the
               region is memory this pass did not read and the next pass has to start here rather
               than past the whole region. Only set when the region was NOT consumed, so a pass that
               ends on a region boundary keeps the plain cursor. */
            if (scanned >= budgetNow && remaining >= 16) readStop = cursor;
        } else {
            /* Counted, not skipped-in-silence: regions that are neither the image, nor writable, nor
               at least one page. With this the pass line closes exactly -- regions = imgSkip + roSkip
               + the ones walked -- and a region that vanished into no counter at all would mean the
               walker is dropping memory the log claims to have covered. */
            g_heap_ro_skip++;
        }

        uintptr_t next = (uintptr_t)address + (uintptr_t)size;
        if (next <= (uintptr_t)address) break;

        address = (vm_address_t)next;
    }

    /* WHERE THE NEXT PASS STARTS -- and the reason the previous version never got past 7% of the
       heap.

       titanox_42 reset this to zero whenever a pass ended without exhausting the byte budget, and
       a pass ends that way the moment the region walk runs out of mapped memory in that
       direction. On the 19:34 run that happened in pass 2 after 15 regions and 30 MB, so pass 3
       restarted from 0x0 and re-scanned exactly the same 542 MB:

           pass=1 from=0x0          scanned=541979872
           pass=2 from=0x288000000  scanned=30605288
           pass=3 from=0x0          scanned=542273600

       against a window span of 7760 MB. The scan was pinned to the first 7% of the heap, and
       every conclusion read off it -- `vtprobe=0` most of all -- was really a statement about
       that 7%.

        The cursor now only ever moves forward, and wraps to the low end of the WINDOW (never to
        address zero) once it has passed the top. Budget exhaustion is no longer a special case:
        the pass resumes exactly where it stopped.

        v46 closes the last hole in that sentence. `next=` was the end of the region the budget
        died in, so the unread TAIL of that region was skipped by every future pass as well -- the
        resume point was past memory nobody had looked at. When the budget cuts a region short the
        cursor is now the address where reading stopped, and `readTo=` in the pass line is that
        same address, so the claim and the number cannot drift apart. */
    uintptr_t nextAddress = readStop ? readStop : (uintptr_t)address;

    if (regions >= 8192 || (g_heap_window_high && nextAddress >= g_heap_window_high)) {
        g_heap_scan_next = g_heap_window_low;
    } else if (nextAddress <= startAddress) {
        /* The region walk could not advance at all. Jumping forward is safe exactly here,
           because the kernel has just said there is no region at or after `startAddress`; the
           only wrong outcome this avoids is spinning on the same address every pass forever,
           which is what "cannot advance" would otherwise cost an entire run. */
        uintptr_t jump = startAddress + (1ull << 30);

        g_heap_scan_next = (g_heap_window_high && jump >= g_heap_window_high) ? g_heap_window_low
                                                                             : jump;
    } else {
        g_heap_scan_next = nextAddress;
    }

    g_heap_covered += (unsigned long long)scanned;

    char vtbuf[160];
    char vtpass[160];
    int vused = 0;
    int pused = 0;

    for (int k = 0; k < TNX_VTPROBE_COUNT; k++) {
        if (vused > (int)sizeof(vtbuf) - 24 || pused > (int)sizeof(vtpass) - 24) break;

        vused += snprintf(vtbuf + vused, sizeof(vtbuf) - (size_t)vused, "%s%llu", k ? "," : "",
                          g_vtprobe_hits[k]);
        pused += snprintf(vtpass + pused, sizeof(vtpass) - (size_t)pused, "%s%llu", k ? "," : "",
                          g_vtprobe_hits[k] - g_vtprobe_pass[k]);
    }

    /* Runs BEFORE the summary line, so every field of that line belongs to the pass being
       reported. v43 ran it after, which is why the pass line printed the previous pass's winner:
       on the 19:51 run it said `best=0x0` while the `objvote owner=` line directly below it named
       0x109fda770, and on the next pass the two swapped. Same rule for the census, which is dumped
       here and not after: its `shaped=` column is filled in by the vote that just ran. */
    tnx_object_vote_finish();
    tnx_vtcensus_dump();

    tnx_logf("votescan heap pass=%d from=%p scanned=%zu words=%zu regions=%d imgSkip=%d roSkip=%d "
             "bigSkip=%d "
             "bigBytes=%lluMB hugeSkip=%d budget=%lluMB budgetHit=%d readTo=%p hits=%d vfx=%d mgr=%p "
             "probes=%d/%d skipped=%d cap=%d/%d loose=%d window=%d bestCount=%d bestLive=%d "
             "trailBest=%d stable=%d chain=%d/%d ready=%d skip=%d live=%d own=%d gid=%d "
             "vtprobePass=%s vtprobeAll=%s vtcensus=%d/%llu vtSpill=%llu "
             "next=%p win=%p..%p winSpan=%lluMB",
             g_heap_passes, (void *)startAddress, scanned, words, regions, g_heap_img_skip,
             g_heap_ro_skip,
             g_heap_big_skip, g_heap_big_bytes / (1024ull * 1024ull), g_heap_huge_skip,
             budgetNow / (1024ull * 1024ull), readStop ? 1 : 0, (void *)readStop, hits,
             verifiedHits,
             (void *)g_manager_object, g_manager_probes, TNX_MANAGER_PROBE_LIMIT,
             g_manager_skipped, g_manager_cap_rejects, g_manager_saw_cap,
             g_manager_loose_count, g_manager_window_rejects,
             g_manager_best_count, g_manager_best_live, g_trail_best, g_seen_stable,
             g_chain_checks, g_chain_probes, g_chain_ready, g_chain_skipped,
             g_chain_best_live, g_chain_best_own, g_chain_best_gid, vtpass, vtbuf,
             g_vtcensus_used, g_vtcensus_total, g_vtcensus_spill,
             (void *)g_heap_scan_next, (void *)winLo, (void *)winHi,
             (unsigned long long)(winHi > winLo ? (winHi - winLo) / (1024ull * 1024ull) : 0));

    /* v46. The first word that ever incremented each non-zero counter, on its own line and only
       when there is something to name. This is the line that makes a jump between two passes
       auditable: `vtprobeAll=...92502` says a number, this says which address produced it. */
    {
        char firsts[320];
        int fused = 0;

        for (int k = 0; k < TNX_VTPROBE_COUNT; k++) {
            if (!g_vtprobe_first[k]) continue;
            if (fused > (int)sizeof(firsts) - 40) break;

            fused += snprintf(firsts + fused, sizeof(firsts) - (size_t)fused, "%s%d@%p",
                              fused ? " " : "", k, (void *)g_vtprobe_first[k]);
        }

        if (fused) tnx_logf("vtprobeFirst pass=%d %s", g_heap_passes, firsts);
    }
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
        tnx_heap_regions_refresh();

    /* `winSpan=` is hi minus lo of the WINDOW, and it is deliberately not called `span` any more:
       on the 20:06 run it read 7720 MB while the process's entire writable non-image memory was
       ~536 MB, and the whole writable heap was covered in one and a bit passes. The number that
       says how much was looked at is `scanned=` in the pass line. `capped=` says the 512-entry
       region list was truncated, in which case tnx_heap_contains answers "no" for owners past the
       cut -- a rejection that would look exactly like static data. */
    tnx_logf("heapwin regions=%d lo=%p hi=%p winSpan=%lluMB capped=%d",
             g_heap_region_count, (void *)g_heap_window_low, (void *)g_heap_window_high,
             (unsigned long long)((g_heap_window_high - g_heap_window_low) / (1024ull * 1024ull)),
             g_heap_region_capped);

    tnx_logf("votescan candidates=%d interval=%.1f attempts=%d heapEvery=%d",
                 (int)(sizeof(g_mode_vtables) / sizeof(g_mode_vtables[0]) - 1),
                 (double)TNX_VOTESCAN_INTERVAL, TNX_VOTESCAN_ATTEMPTS, TNX_VOTESCAN_HEAP_EVERY);
    }

    /* The segment scans are the expensive part of a tick (a 2 MB copy plus a probe for every
       candidate pointer). They now run on one attempt in TNX_VOTESCAN_GLOBAL_EVERY, which
       keeps the game responsive without giving up the fallback entirely. */
    if ((g_votescan_attempts % TNX_VOTESCAN_GLOBAL_EVERY) == 1) {
        /* The heap grows as the app runs, so the region list is rebuilt on this cadence
           instead of being frozen at startup. */
        tnx_heap_regions_refresh();

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

/* The slot reader, read-only. That is a correction, not a style choice.

   titanox_41 CALLED the function it found in the slot. The justification was "slot 0x88 is
   getX", and the call site that claim rested on has now been disassembled properly. At RVA
   0xae48f0 the engine loads an ARGUMENT before every one of five consecutive calls:

       ldr w1, [x20, #8]
       ldr x8, [x19]
       ldr x8, [x8, #0x88]
       mov x0, x19
       blr x8

   and repeats it with [x20+0x18], [x20+0x1c], [x20+0x20] and [x20+0x34]. A getter takes no
   argument, so on this build slot 0x88 is not getX, and invoking it with a single register as
   if it were is exactly the "execute unknown code" hazard the read-only dump exists to avoid.
   The 19:19 log records what came back: element=0x118943918 printed x=0 y=412367128, and
   412367128 is 0x18943918 -- the low half of the element's own address, not a position.

   What this returns instead is the RVA of the function sitting in the slot. That identifies the
   class which actually defines it, and it executes nothing. */
static BOOL tnx_obj_slot_fn(uintptr_t object, uintptr_t slot, uintptr_t *rvaOut) {
    void *vtable = NULL;
    void *function = NULL;

    if (rvaOut) *rvaOut = 0;

    if (!object) return NO;
    if (!tnx_read_ptr(object, &vtable) || !vtable) return NO;
    if (!tnx_read_ptr((uintptr_t)vtable + slot, &function) || !function) return NO;
    if ((uintptr_t)function < g_base) return NO;
    if ((uintptr_t)function >= g_base + 0xf74000) return NO;

    if (rvaOut) *rvaOut = (uintptr_t)function - g_base;

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
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_read_i32((uintptr_t)object + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)object + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)object + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)object + TNX_OBJ_DEADFLAG_OFF, &dead);

        tnx_obj_slot_fn((uintptr_t)object, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)object, TNX_OBJ_GETY_SLOT, &s90);

        tnx_logf("obj[%s][%d] %p vt=%#llx gid=%d team=%d own=%d dead=%d s88=%#llx s90=%#llx",
                 tag, i, object, (unsigned long long)tnx_vtable_rva(object), globalId, team,
                 owner, dead, (unsigned long long)s88, (unsigned long long)s90);

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
/* Reports one candidate manager pointer in full, whether it came from a1 or from an object
   field. The header counts, the capacity invariant the engine's append routine guarantees, and
   the entries themselves -- every number a dodge needs, from one call. */
static void tnx_report_manager(const char *tag, uintptr_t manager) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!tnx_pointer_plausible(manager)) return;

    /* v44. The only "manager" line of the 19:51 run came from a __DATA_CONST address and read
       `objvote mgr=0x109fd8d30 array=0x109b6b85c count=1 cap=162969880 live=0 CAP-VIOLATION` --
       a four-billion-entry array, which is simply what dereferencing a non-manager produces. The
       guard belongs here, at the printer, so that no caller can print a manager line for
       something that is not a heap allocation. */
    if (!tnx_owner_is_heap(manager)) {
        tnx_logf("%s mgr=%p rejected: not a heap allocation", tag, (void *)manager);
        return;
    }

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) {
        tnx_logf("%s mgr=%p unreadable", tag, (void *)manager);
        return;
    }
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return;

    tnx_logf("%s mgr=%p array=%p count=%d cap=%d live=%d%s", tag, (void *)manager, array,
             count, capacity, tnx_manager_live_count(manager),
             (capacity >= count && capacity <= TNX_MGR_CAP_MAX) ? "" : " CAP-VIOLATION");

    if (count < TNX_MANAGER_MIN_OBJECTS || count > TNX_MANAGER_MAX_OBJECTS) return;
    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return;

    tnx_dump_manager(manager, (int)count);
}

/* ======================================================================================
   HOW TO READ THE LOG

   The banner. First line after the build tag is `build=<tag>`, and any log without it comes
   from titanox_25 or earlier and should be thrown away. Then `slots=`, `control=` and
   `types>=` restate the hooking plan.

   The contract. `contract ...` lines print every offset in use with the evidence behind it,
   so a log can be checked without opening the source: `mode+0x28`, the array header, the
   object fields and the slot numbers, each with where it was measured.

   The hook state. `slotdiag` carries a counter and a read-back per slot. `N/held` means the
   table entry still points at our forwarder, so the slot is armed and simply has not been
   called. `N/LOST` means something rewrote it and the hook is gone. Nothing else in the log
   matters until one of the seven is non-zero.

   The capture. As soon as any slot fires, the pump prints four things, in this order:

       slot <name>: captured this=<object> arg1=<manager> hits=<n>
       slot arg1 mgr=<manager> array=<array> count=<n> cap=<n> live=<n>
       objtable array=... count=... cap=...
       obj[00] ... gid= team= own= dead= s88= s90= s18= s28= s48= shape=1

   `arg1` is the whole point. For B2 it is the object manager, handed over by the engine at
   the moment the first game object is created, and it costs nothing to get. `CAP-VIOLATION`
   on the third line means the header invariant was broken and the candidate is not an array.

   The dodge. `dodge team=<t> own=(x,y) threats=<n> nearest=<d> raw=(x,y) step=(x,y)
   action=<move|hold>` is computed read-only, once per team present. It is the two numbers to
   hand to the movement entry point the moment that entry point is known; until then it is
   the proof that the geometry is right.

   v47 supersedes that with the real thing, and says so in its own lines:

       v47 setprediction verified|MISMATCH ...   the three instructions of 0xac3f20
       v47 man walk manager=... usable=... mapW=... teamsOld=... teamsNew=... teamOff=...
       v47 obj[00] at=... pos=(x,y) teamOld=... teamNew=... dead=... active=...
       v47 coords ok=<0|1> (...)
       v47 write #<n> own=(x,y) team=... step=(..) target=(x,y)
       v47 live ticks=... own=(..) pred=(..) hostilesAlive=.. enemiesActive=.. enemiesInRange=0

   `ok=0` means nothing is ever written, and the line above it carries the numbers that
   decided it: how many objects were readable, whether their positions were distinct and in
   range, and which of the two candidate team offsets actually split them into sides. The
   probe is not one-shot -- it re-runs whenever the battle object changes and every five
   seconds while it is still failing, so a verdict formed on a lobby object cannot outlive
   the lobby. `hostilesAlive >= enemiesActive >= enemiesInRange` is strictly nested, and
   that is the point: a zero in the middle names which test failed. An inverted +0x1e8 bit
   on this build shows as `hostilesAlive` non-zero with `enemiesActive` zero, which is a
   fact about the layout rather than an unexplained empty dodge.

   The verdict. `DIAG` ends with `capRej=<n>/<n>`, `bestCount/bestLive`, `mgr=` and `mx=`.
   `mx` is the largest object count ever seen in a battle-shaped container. `mx` of zero or
   one means no battle existed in the window and the run says nothing about the layout.

   The near-miss trail. Every candidate that satisfies the header invariant but fails the
   instance test is recorded with its numbers and the worst eight are printed at the
   heartbeat. That is what turns "nothing found" into an actionable statement about what the
   scanner was looking at.

   -- What each slot is, and why --------------------------------------------------------

     A1  0xad4ed0  a class that owns a manager through [[this+0x8]+0x0]
     A2  0xad521c  its sibling, same vtable, slot 7
     B1  0xa2e5b8  from the same family as B2, slot 5
     B2  0xa2d250  setOwner: str x1,[x0,#0x20]. The one that hands over the manager.
     B3  0xa2d6ac  sibling of B2, slot 7, also installed across all seven relatives
     C1  0xc33690  Stage addChild, a control: fires when the scene graph grows
     C2  0xb9dc24  a flag getter present in 443 tables, a control for the hook mechanism

    B2 is the working leg. It is called by addGameObject on every object the match creates,
    with the manager in x1, and the byte address of that slot is 0xff5738. If B2 stays at zero
    while a match is running, the next thing to try is C2's answer: whether any pointer table
    hook fires at all during a battle.

    THE OBJECT VOTE, AND HOW TO READ IT (added in v44, first run in v43).

    Two lines per pass, printed immediately before `votescan heap pass=`:

        objvote pass=3 hits=433 skipped=0 owners=33 deadOk=157 best=0x... gids=6+ confirm=1
                teamCount=2 ownerImg=0 objImg=0 teamsMin=2
        objvote owner=0x... distinctGids=6+ votes=15 teams=0x3 teamCount=2 deadOk=14
                vtCount=1 vt0=0x1008d30 vt1=0 ...

    Read them in this order:

      hits=      words that matched the whole object record layout. Zero here with a large
                 `scanned=` means the layout is not being produced by anything in the window.
      owners=    distinct pointers found at +0x20 of those words. `skipped=` counts owners the
                 table could not hold; a non-zero `skipped` means the winner is not necessarily
                 the real one.
      gids=      distinct global ids behind the PASS line's winner. This is the number the selector
                 rests on, and `gids=64+` means the list was full so the printed value is a FLOOR,
                 not a count.
      confirm=   consecutive passes with the same winner. Capture needs 1.
      teamCount= distinct team values. Below teamsMin the owner is held back and named in an
                 `objvote singleTeam` line; a battle container carries both teams.
      ownerImg=  candidates dropped because +0x20 pointed into the image. A large value with
                 small `owners=` means the vote is looking at a table, not at a battle.
      objImg=    words dropped for being image data themselves. This must stay 0 because the
                 pass walker now skips the image's writable regions entirely (`imgSkip=` in the
                 pass line); anything else means that skip is not working.
      vt0..vt3=  the class tables the winner's objects carry, as RVAs. If vt0 is not one of the
                 nine entries of the vtprobe list, that number is where the next hook goes -- it
                 is the direct answer to `hooks fired=0`. These are printed for the WINNER only, so
                 below the id minimum the line does not exist at all; use `objhit` instead.

      ownerNoRegion/ownerAboveWin= the two ways the positive owner test can fail without the owner
                 being static data, and v46 keeps them apart because their fixes are opposite. An
                 owner ABOVE the window high is a window problem: the window is rebuilt from the
                 region list every tenth attempt and it SHRANK during the 20:22 run, from 7776 MB to
                 567 MB, so owners of real objects fell outside it. An owner in no region at all is a
                 REGION problem (`capped=` on the heapwin line, or regions wider than
                 TNX_HEAP_REGION_MAX_SIZE, which the list drops). v45 merged both into one number,
                 which is the same mistake v44 made with ownerImg.
      objShaped= how many shaped words there were, counted UNCAPPED. The identity to check is
                 hits + skipped + ownerImg + ownerNoRegion + ownerAboveWin = objShaped; if it does
                 not hold, a filter dropped a word without printing why. objhitRec= is only how many
                 of them the dump table could remember, so it is a floor and by design not the
                 number the identity uses -- v45 printed the capped count as objShaped, which made
                 the check impossible exactly when there was something to check.
      maxVotes/topOwner= the owner with the most votes REGARDLESS of the id minimum, so a `best=0x0`
                 line still names the strongest candidate the pass had instead of nothing.

    v45: THE PER-HIT DUMP -- the lines to read when the vote says `best=0x0`.

        objhit pass=1 #0 at=0x12a41c140 vt=0xff5720 gid=17 team=0 own=3 dead=1 owner=0x12a6765f8 ownerClass=heap
        objhit pass=1 #1 at=0x12a41c2b0 vt=0x1008d30 gid=1 team=0 own=0 dead=0 owner=0x109fd8d30 ownerClass=image
        objhit truncated: shown=24 recorded=64+ - ...

    One line per object-shaped word, heap-owned first, then `image`, `noRegion` and `aboveWin`.
    `vt=` is the
    class table as an RVA, and it is the number that ends the `hooks fired=0` question: it is what
    the LIVE objects carry, and it is none of the nine entries of the vtprobe list. `dead=` is the
    byte at +0xd0 -- counted, never required, because its offset is the one that comes only from the
    reference implementation. `ownerClass` is the reason the word did or did not vote. If the
    heap-owned hits all name DIFFERENT owners, then +0x20 is not the shared manager on this build and
    the vote can never win however many objects exist: that is a conclusion the dump reaches at a
    glance and the vote report could not reach at all.

    v46: THE CENSUS -- the lines that replace the question "which class should be hooked".

        vtcensus pass=1 distinct=23 total=140233 spill=0 dc=0x106744000..0x106818000 data=...
        vtcensus #0 rva=0x1008d30 seg=C count=92502 shaped=7 ownerEqVt=92502 first=0x102178390
        vtslots rva=0x100a770 seg=C count=41 shaped=3 slotRvas=0x1b076c,0x1b0818,...

    Every 16-byte aligned word of the pass whose value lands in __DATA_CONST or __DATA is one
    instance of the class table at that RVA. `count=` is how many instances exist in the bytes this
    pass read, `shaped=` how many of them also passed the full object record layout (so they look
    like game objects and not merely like C++ objects), and `ownerEqVt=` how many read the same value
    at +0x00 and +0x20 -- the arithmetic signature of the 19:51 false positive, as a count. `seg=D`
    entries are tables in __DATA, which this build has: the 20:22 run's modehit lines show __DATA
    slots holding pointers into __TEXT. `vtslots` resolves the first slots of the two most
    interesting tables into RVAs, and a table whose slots all land in __TEXT is a vtable whose slot
    RVAs are the hook targets -- which is how every hook in this file was chosen.

    THE PASS LINE, in the terms v45 fixed and v46 corrected:

        scanned=   bytes actually read this pass. This is the coverage number.
        words=     the same figure counted rather than multiplied: aligned words examined. Printed
                   because `scanned=` alone could not tell "read the whole window" from "read 540 MB
                   of something", which is exactly what the 20:22 run confused.
        budget=    the byte budget this pass was allowed, now derived from the window instead of
                   being a fixed 512 MB. budgetHit=1 means the pass stopped early, so every zero on
                   the line describes only the part it reached; readTo= is the address it stopped at,
                   and the next pass resumes there -- including the tail of the region it was in,
                   which the old code skipped for good.
        winSpan=   hi minus lo of the heap WINDOW -- not coverage, and not the size of writable
                   memory either (7776 MB on a run whose whole writable heap was under 600 MB).
        regions=   regions walked, closed exactly by imgSkip= + roSkip= + the ones actually read.
        roSkip=    neither the image, nor writable, nor one page long.
        bigSkip=   WRITABLE regions over 1 GB, with bigBytes= saying how much that was. These are
                   heap this scan can never read, so if bigBytes is large the sweep is partial no
                   matter how complete the rest of the line looks. hugeSkip= is the same test for
                   regions that are not writable -- the ~385 GB guard -- and means nothing.
        vtprobePass= instances of the nine class tables found BY THIS PASS, and the number to read.
        vtprobeAll=  the same counters accumulated over every pass since launch. It is cumulative
                   on purpose (the class census has to be able to see a class that only exists
                   during a match), which is precisely why the per-pass delta exists: on the 20:22
                   run `vtprobeAll` read 0 after pass 1 and 92502 after pass 3, and nothing said
                   which pass produced it. Read them as a pair, with budgetHit= for the coverage.
        vtSpill=   census entries that could not be created because the table was full. Non-zero
                   makes vtcensus distinct= a floor.
        vtcensus=  distinct class tables seen this pass / total instances counted. Full report on
                   the `vtcensus` and `vtslots` lines.
    ====================================================================================== */

#define TNX_DODGE_RADIUS 320
#define TNX_DODGE_STEP 600
#define TNX_DODGE_SCALE 4096
#define TNX_OBJECT_DETAIL_MAX 8
#define TNX_TRAIL_MAX 8
#define TNX_BEST_DETAIL_MAX 12

/* Candidates that passed the header invariant but failed the instance test. The scanner used
   to swallow these silently; without them a run that finds nothing cannot be told apart from
   a run in which the wrong thing was being measured. */
typedef struct {
    uintptr_t manager;
    int32_t count;
    int32_t capacity;
    int live;
    int nonEmpty;
} tnx_trail_t;

static tnx_trail_t g_trail[TNX_TRAIL_MAX];
static int g_trail_count = 0;
static uint64_t g_trail_total = 0;

/* Seen-address memory, one table per pass.

   The 19:13 run made the need for this plain. The trail recorded a candidate as
   `count=52 cap=52 live=10 nonEmpty=46`, and twenty-five seconds later the read-only dump of
   the very same address reported `count=12` and an array pointer that could not even be read
   -- `shown=0`. The same thing happened in the 19:03 run with 48 turning into 12. Whatever the
   scanner is finding, it is scratch memory that is rewritten as the game runs, not a container
   that lives for the length of a match.

   A real object manager is stable, so stability is the requirement: an address is only worth
   reporting once it has held the same count in two different passes.

   titanox_41 implemented that with two 64-entry lists and copied one into the other whenever the
   pass number changed. It could therefore only ever compare the first 64 probed candidates of
   two adjacent passes -- and because each pass continues where the previous one ran out
   (`from=0x0`, then `from=0x2da000000`, then `from=0x0`), those two windows cover different
   memory. That is exactly why the 19:19 and 19:20 runs printed the trail header with 10546
   candidates and not one entry: the gate could not fire, and a gate that cannot fire is
   indistinguishable from scratch memory not existing.

   This is a 512-entry table stamped with the pass number instead, so a candidate is stable when
   the same address is seen again with the same count in a LATER pass. g_seen_stable counts the
   hits and is printed in every pass line, so the requirement is measurable rather than assumed. */
#define TNX_SEEN_MAX 512

typedef struct {
    uintptr_t address;
    int32_t count;
    int pass;
} tnx_seen_t;

static tnx_seen_t g_seen[TNX_SEEN_MAX];

static BOOL tnx_candidate_is_stable(uintptr_t address, int32_t count) {
    size_t slot = (size_t)((address >> 4) % (uintptr_t)TNX_SEEN_MAX);
    tnx_seen_t *entry = &g_seen[slot];

    if (entry->address && entry->address == address) {
        BOOL stable = (entry->count == count && entry->pass != g_heap_passes);

        entry->count = count;
        entry->pass = g_heap_passes;

        if (stable) g_seen_stable++;

        return stable;
    }

    /* While a different address from this same pass occupies the slot the first one keeps it, so
       the table holds a deterministic sample of every pass instead of the last few words scanned.
       An entry left over from an earlier pass is replaced: that is what keeps the sample aligned
       with the current pass. */
    if (!entry->address || entry->pass != g_heap_passes) {
        entry->address = address;
        entry->count = count;
        entry->pass = g_heap_passes;
    }

    return NO;
}

static void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty) {
    int slot = -1;
    int worst = 0;

    g_trail_total++;

    if (live > g_manager_best_live) g_manager_best_live = live;

    /* Scratch memory is rewritten as the game runs, so a single sighting proves nothing.
       Only structures that have held the same count across two passes are reported. */
    if (!tnx_candidate_is_stable(manager, count)) return;

    /* One entry per address. Without this the same structure was recorded over and over and
       filled all eight slots -- on the 18:55 run every slot held 0x108846678, so the list that
       exists to show the best candidates could only ever show one of them. */
    for (int i = 0; i < g_trail_count; i++) {
        if (g_trail[i].manager == manager) {
            g_trail[i].count = count;
            g_trail[i].capacity = capacity;
            g_trail[i].live = live;
            g_trail[i].nonEmpty = nonEmpty;
            slot = i;
            goto best;
        }
    }

    if (g_trail_count < TNX_TRAIL_MAX) {
        slot = g_trail_count++;
    } else {
        for (int i = 0; i < TNX_TRAIL_MAX; i++) {
            if (i == 0 || g_trail[i].live < worst) {
                worst = g_trail[i].live;
                slot = i;
            }
        }
        if (live <= g_trail[slot].live) return;
    }

    g_trail[slot].manager = manager;
    g_trail[slot].count = count;
    g_trail[slot].capacity = capacity;
    g_trail[slot].live = live;
    g_trail[slot].nonEmpty = nonEmpty;

best:
    g_trail_best = 0;
    for (int i = 1; i < g_trail_count; i++) {
        if (g_trail[i].live > g_trail[g_trail_best].live) g_trail_best = i;
    }
}

static void tnx_trail_dump(void) {
    tnx_logf("trail: %llu candidates passed the array header, worst eight by live count",
             (unsigned long long)g_trail_total);

    for (int i = 0; i < g_trail_count; i++) {
        tnx_logf("trail[%d] mgr=%p count=%d cap=%d live=%d nonEmpty=%d",
                 i, (void *)g_trail[i].manager, g_trail[i].count, g_trail[i].capacity,
                 g_trail[i].live, g_trail[i].nonEmpty);
    }
}

/* The seven hooks restated from the table itself, so the log always agrees with what was
   actually installed rather than with what the comments claim. */
static void tnx_slot_table_dump(void) {
    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        tnx_logf("hook[%d] %-4s target=%#llx slotRva=%#llx repl=%p control=%d",
                 i, g_slot_specs[i].shortTag,
                 (unsigned long long)g_slot_specs[i].rva,
                 (unsigned long long)g_slot_specs[i].slotRva,
                 (void *)g_slot_specs[i].replacement,
                 g_slot_specs[i].control ? 1 : 0);
    }
}

/* Raw bytes of the first objects, so an unexpected layout can be diagnosed from the log
   alone instead of costing another run. */
static void tnx_raw_object_hex(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > limit) count = limit;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        tnx_dump_hex("rawObj", (uintptr_t)element, 0x40);
        tnx_dump_hex("rawObjB", (uintptr_t)element + 0xc0, 0x20);
    }
}

/* ======================================================================================
   THE COMPLETE MAP. Everything on this page was established either by disassembling
   src_data/Nulls_Brawl.txt or by reading a device log, and each line says which. Nothing
   here is inherited from another build: dozens of versions burned on addresses taken from
   the shipped offsets.h before that table was measured and found to be worthless for calls
   (only 16 of its 146 RVA defines land on a function entry point at all, and one of them,
   receiveMessage, points at a completely different function than the name claims).

   -- Structures, all confirmed twice: from REvengeBS and from our own disassembly --------

     LogicBattleModeClient, minimum 0x260 bytes
       +0x028  object manager           proven: the game's own code loads it here
       +0x058  client input manager     from REvengeBS, not yet confirmed here
       +0x0ec  int accessor             getInt reads it directly
       +0x124  game mode variation      getTeamStars compares it against 0x29 and asserts
       +0x1d4  prediction target X      the only place in the image that writes it
       +0x1d8  prediction target Y      written by the same six instructions
       +0x1e8  stars, low half          from REvengeBS
       +0x1ec  stars, high half         from REvengeBS
       +0x218  pointer, getter and setter sit next to each other every 0x10 bytes
       +0x220  pointer
       +0x228  pointer
       +0x248  array header
       +0x258  array header
       +0x28..+0xa8  per-type Array headers, nine of them, written by addGameObject

     Array<T>, header 16 bytes, stride 8 -- this layout is taken from the engine's own
     append routine at 0x46aefc, which does ldp w9, w8, [x0, #8] and grows when the two are
     equal, so:
       +0x000  T**   data
       +0x008  u32   capacity
       +0x00c  u32   count
       invariant: count <= capacity, always. This single check is what finally rejected the
       string tables that kept being mistaken for the object manager.

     Game object, minimum 0x1e8 bytes
       +0x008  u32   global id          written by addGameObject through the generator
       +0x020  ptr   owning manager     written by setOwner, which is exactly this field
       +0x03c  int   owner index        from REvengeBS
       +0x040  int   team               confirmed by two independent loops in the class code
       +0x04c  int   a second team-like field, read by the manager's own finder
       +0x0d0  u8    dead flag          0 or 1; the reference reads it as a single byte
       +0x140  int   kind on the data object returned by 0x100382cc8

     Object virtual table, confirmed by the engine's own code paths
       +0x018  setOwner, called by addGameObject with the manager in x1
       +0x028  int getter, used both as an aliveness test and as a type discriminator
       +0x048  int getter used to pick the per-type list inside addGameObject
        +0x088  setter-like slot -- the engine's call site at 0xae48f0 passes it an int
                argument, so it is NOT getX on this build, as titanox_37..41 assumed
        +0x090  the neighbouring slot, same correction; both are read-only RVA probes now
       +0x098  getZ, int32, fixed point

   -- Addresses, each one verified on the device, not guessed ------------------------------

     0xa278a8  LogicGameObjectManager addGameObject      device resolver, assert string
     0xa27b98  LogicGameObjectManager id generator       device resolver, assert string
     0x9cd5e0  LogicProjectileData getColumnValue        device resolver, assert string
     0xac3cfc  LogicBattleModeClient getTeamStars        device resolver, assert string
     0x75d20c  MessageManager receiveMessage             device resolver, assert string
     0xd5646c  MetalView render                          device resolver
     0xa2d250  the setOwner slot target                  found by disassembling addGameObject
     0xac3ddc  finder over the manager by team            our disassembly, reads +0x28 and +0x40
     0xac3e74  second finder, same shape                  our disassembly
     0xac3d80  manager-side finder by team                our disassembly, reads +0x0 and +0xc
     0xac3f2c  manager progress accessor                  our disassembly, reads +0x28 then +0x8c
     0xac3f20  the pair setter for +0x1d4 and +0x1d8      our disassembly, unique in the image
     0xac3500  getInt, leaf getter for +0xec             device resolver
     0xac40d8  leaf getter for +0x218                    device resolver
     0xac40e8  leaf getter for +0x220                    device resolver
     0xac40f8  leaf getter for +0x228                    device resolver
     0x46aefc  Array<T> append, the source of the header layout above
     0x100382cc8  non-virtual data accessor used by addGameObject

   -- The one lever that matters ----------------------------------------------------------

     addGameObject, at 0xa27930, does this:

         ldr x0, [sp, #0x28]      the object
         ldr x8, [x0]
         ldr x8, [x8, #0x18]
         mov x1, x19              the manager
         blr x8

     The slot it calls is byte RVA 0xff5738, which is B2 in the table below. So the first
     game object created in a match hands us both the object and the manager, in x0 and x1,
     with no scan, no threshold and no guessing. Until titanox_36 the forwarder read x0
     only, which is why thirty-five versions never saw a live battle object.

   -- Still unknown ------------------------------------------------------------------------

     The movement entry point. Neither setClientPredictionMoveTo nor updateMovement nor
     handleJoystick exists as a string anywhere in the image, so no name resolver can find
     them, and every address the shipped table gives for them lands in the middle of an
     unrelated function. What is known: the only code in the whole image that writes both
     +0x1d4 and +0x1d8 is the three instructions at 0xac3f20, and its single caller is a
     spawn path. The captured object's own table is therefore dumped in full, which is the
     one place a callable movement slot can be read from.
   ====================================================================================== */

/* The invariant table, printed at startup so that a log can be audited against it without
   anyone having to read the source again. */
typedef struct {
    const char *label;
    const char *value;
    const char *provenance;
} tnx_fact_t;

static const tnx_fact_t g_tnx_facts[] = {
    { "mode+0x28 = object manager", "0x28", "engine code at 0xac3ddc loads it here" },
    { "manager+0x0 = object array", "0x0", "engine append routine 0x46aefc" },
    { "manager+0x8 = capacity", "0x8", "engine append routine 0x46aefc" },
    { "manager+0xc = count", "0xc", "engine append routine 0x46aefc" },
    { "array stride", "8", "64-bit targets" },
    { "object+0x8 = global id", "0x8", "addGameObject writes it at 0xa278e4" },
    { "object+0x20 = owning manager", "0x20", "setOwner is str x1,[x0,#0x20]" },
    { "object+0x3c = owner index", "0x3c", "REvengeBS" },
    { "object+0x40 = team", "0x40", "two independent loops in the class code" },
    { "object+0xd0 = dead flag, byte", "0xd0", "REvengeBS reads uint8_t" },
    { "slot +0x18 = setOwner", "0x18", "addGameObject calls it with the manager in x1" },
    { "slot +0x88 = not getX", "0x88", "call site 0xae48f0 loads an int argument before blr" },
    { "slot +0x90 = getY", "0x90", "eight bytes after getX" },
    { "count ceiling", "96", "a real battle holds tens of entities" },
    { "capacity ceiling", "4096", "no real array is allocated four billion entries" },
    { "live ratio", "3/4", "string tables decode as instances in a couple of slots" },
    { "manager probe budget", "65536", "the 2048 of titanox_35 went blind in seconds" },
    { NULL, NULL, NULL }
};

static void tnx_struct_map_dump(void) {
    tnx_logf("contract: %d invariants, offsets below are the ones actually in use",
             (int)(sizeof(g_tnx_facts) / sizeof(g_tnx_facts[0])) - 1);

    for (int i = 0; g_tnx_facts[i].label; i++) {
        tnx_logf("contract %-30s %-6s %s", g_tnx_facts[i].label, g_tnx_facts[i].value,
                 g_tnx_facts[i].provenance);
    }

    tnx_logf("contract numbers mode+0x28=%#llx mgr array=%#llx cap=%#llx count=%#llx "
             "obj team=%#llx dead=%#llx gid=%#llx own=%#llx",
             (unsigned long long)TNX_MODE_MANAGER_OFF,
             (unsigned long long)TNX_MGR_ARRAY_OFF,
             (unsigned long long)TNX_MGR_CAP_OFF,
             (unsigned long long)TNX_MGR_COUNT_OFF,
             (unsigned long long)TNX_OBJ_TEAM_OFF,
             (unsigned long long)TNX_OBJ_DEADFLAG_OFF,
             (unsigned long long)TNX_OBJ_GLOBALID_OFF,
             (unsigned long long)TNX_OBJ_OWNERINDEX_OFF);

    tnx_logf("contract slots s88=%#llx s90=%#llx owner=%#llx list=%#llx listCount=%#llx",
             (unsigned long long)TNX_OBJ_GETX_SLOT,
             (unsigned long long)TNX_OBJ_GETY_SLOT,
             (unsigned long long)TNX_SLOT_OWNER_OFF,
             (unsigned long long)TNX_SLOT_LIST_OFF,
             (unsigned long long)TNX_SLOT_LISTCOUNT_OFF);
}

/* Integer square root. The engine's coordinates are fixed point integers and there is no
   floating point anywhere else in this file, so the dodge arithmetic stays integral too. */
static int64_t tnx_isqrt(int64_t value) {
    int64_t guess = 0;

    if (value <= 0) return 0;
    if (value > (int64_t)1 << 62) return (int64_t)1 << 31;

    guess = value;

    for (int i = 0; i < 64; i++) {
        int64_t next = (guess + value / (guess > 0 ? guess : 1)) / 2;

        if (next >= guess) break;
        guess = next;
    }

    return guess;
}

/* One line per object: everything a dodge needs, including the two table slots that decide
   what the object actually is. */
static int tnx_object_detail(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int shown = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;
    if (count <= 0) return 0;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;
    if (limit > 0 && count > limit) count = limit;

    tnx_logf("objtable array=%p count=%d cap=%d", array, count, capacity);

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;
        void *slotOwner = NULL;
        void *slotAlive = NULL;
        void *slotKind = NULL;
        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        int32_t x = 0;
        int32_t y = 0;
        uint8_t dead = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        shown++;

        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;

        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_OWNER_OFF, &slotOwner);
        tnx_read_ptr((uintptr_t)vtable + 0x28, &slotAlive);
        tnx_read_ptr((uintptr_t)vtable + 0x48, &slotKind);

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETY_SLOT, &s90);

        tnx_logf("obj[%02d] %p vt=%#llx gid=%d team=%d own=%d dead=%d s88=%#llx s90=%#llx "
                 "s18=%#llx s28=%#llx s48=%#llx shape=%d",
                 i, element, (unsigned long long)tnx_vtable_rva(element), globalId, team, owner,
                 dead, (unsigned long long)s88, (unsigned long long)s90,
                 (unsigned long long)(slotOwner ? (uintptr_t)slotOwner - g_base : 0),
                 (unsigned long long)(slotAlive ? (uintptr_t)slotAlive - g_base : 0),
                 (unsigned long long)(slotKind ? (uintptr_t)slotKind - g_base : 0),
                 tnx_gameobject_shape((uintptr_t)element) ? 1 : 0);
    }

    return shown;
}

/* The same table, but read only.

   Nothing here calls into the game, and that is a change from titanox_41: that version invoked
   the slot it believed to be getY, which is dangerous before an object is even known to be a
   game object -- and what came back was not a position anyway, as the 19:19 log shows. The
   distinction is still worth keeping, though: a candidate that is really a
   scene list or a resource table would be made to execute whatever sits at slot 0x88. This
   variant reads the fields and the slot values and executes nothing, so it can be pointed at
   any candidate at all -- which is exactly what is needed to find out what the closest miss
   actually holds. */
static int tnx_object_detail_readonly(uintptr_t manager, int limit) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    int shown = 0;
    int instances = 0;
    int teams[TNX_OBJ_TEAM_MAX + 1];

    for (int i = 0; i <= TNX_OBJ_TEAM_MAX; i++) teams[i] = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return 0;
    if (count <= 0) return 0;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;
    if (limit > 0 && count > limit) count = limit;

    tnx_logf("best array=%p count=%d cap=%d", array, count, capacity);

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        void *vtable = NULL;
        void *slotOwner = NULL;
        void *slotAlive = NULL;
        void *slotKind = NULL;
        void *slotX = NULL;
        void *slotY = NULL;
        int32_t globalId = 0;
        int32_t team = 0;
        int32_t owner = 0;
        uint8_t dead = 0;
        int shaped = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        if (!tnx_read_ptr((uintptr_t)element, &vtable)) continue;

        shaped = tnx_gameobject_shape((uintptr_t)element) ? 1 : 0;
        if (shaped) instances++;

        tnx_read_ptr((uintptr_t)vtable + TNX_SLOT_OWNER_OFF, &slotOwner);
        tnx_read_ptr((uintptr_t)vtable + 0x28, &slotAlive);
        tnx_read_ptr((uintptr_t)vtable + 0x48, &slotKind);
        tnx_read_ptr((uintptr_t)vtable + TNX_OBJ_GETX_SLOT, &slotX);
        tnx_read_ptr((uintptr_t)vtable + TNX_OBJ_GETY_SLOT, &slotY);

        tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &globalId);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);
        tnx_read_i32((uintptr_t)element + TNX_OBJ_OWNERINDEX_OFF, &owner);
        tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead);

        if (team >= 0 && team <= TNX_OBJ_TEAM_MAX) teams[team]++;

        tnx_logf("best[%02d] %p vt=%#llx gid=%d team=%d own=%d dead=%d shape=%d "
                 "s18=%#llx s28=%#llx s48=%#llx s88=%#llx s90=%#llx",
                 i, element, (unsigned long long)tnx_vtable_rva(element), globalId, team, owner,
                 dead, shaped,
                 (unsigned long long)(slotOwner ? (uintptr_t)slotOwner - g_base : 0),
                 (unsigned long long)(slotAlive ? (uintptr_t)slotAlive - g_base : 0),
                 (unsigned long long)(slotKind ? (uintptr_t)slotKind - g_base : 0),
                 (unsigned long long)(slotX ? (uintptr_t)slotX - g_base : 0),
                 (unsigned long long)(slotY ? (uintptr_t)slotY - g_base : 0));

        shown++;
    }

    tnx_logf("best summary shown=%d instances=%d teams=%d/%d/%d/%d",
             shown, instances, teams[0], teams[1], teams[2], teams[3]);

    return shown;
}

/* What the closest miss actually holds. Until now the log could only say "live 18 of 30"; it
   could not say whether those eighteen things are game objects with a team and a position or,
   say, a scene list. This answers that without executing anything. */
static void tnx_best_candidate_dump(void) {
    if (g_trail_count <= 0) return;
    if (g_trail_best < 0 || g_trail_best >= g_trail_count) return;

    tnx_logf("best candidate index=%d mgr=%p count=%d cap=%d live=%d nonEmpty=%d",
             g_trail_best, (void *)g_trail[g_trail_best].manager,
             g_trail[g_trail_best].count, g_trail[g_trail_best].capacity,
             g_trail[g_trail_best].live, g_trail[g_trail_best].nonEmpty);

    tnx_object_detail_readonly(g_trail[g_trail_best].manager, TNX_BEST_DETAIL_MAX);
}

/* The dodge is DISABLED, and this says exactly why.

   titanox_37 through titanox_41 computed a dodge vector from the values returned by the
   functions found in vtable slots 0x88 and 0x90. Two measurements now invalidate that, and the
   second is the serious one:

     1. slot 0x88 is not getX on this build. The engine's own call site at RVA 0xae48f0 loads an
        argument before every call -- ldr w1,[x20,#8]; ldr x8,[x19]; ldr x8,[x8,#0x88];
        mov x0,x19; blr x8 -- and repeats it five times with [x20+0x18], [x20+0x1c], [x20+0x20]
        and [x20+0x34]. A getter takes no argument. What the 19:19 log shows is what calling it
        produced: element=0x118943918 was reported as x=0 y=412367128, and 412367128 is
        0x18943918 -- the low half of that element's own address, not a position.

     2. the reader that produced those values CALLED the function. Executing a function pointer
        lifted out of a heap object's table and chosen by a heuristic is the one thing the
        read-only dump was introduced to avoid, and it has no place in the release path.

   So no vector is computed here any more. What the log gets instead is what is needed to find
   the real coordinate source: for every live element on this team, the RVA of the function in
   slot 0x88 and the RVA in slot 0x90. Those RVAs are what identify the class defining them, and
   the class has to be identified before a position can be read. It executes nothing.

   The coordinates themselves need no vtable at all once the mode is adopted: the mode keeps its
   own predicted position in the plain fields +0x1d4/+0x1d8 -- the only writer of that pair in
   the image is 0xac3f20, a void(pointer,int,int) -- and the input manager at +0x58. Both are
   read straight out of memory. */
/* ===========================================================================
   v47. THE DODGE, ON OFFSETS THE ENGINE STATES RATHER THAN ON A SHAPE TEST.
   ===========================================================================

   Three claims, each of which the log can falsify on its own:

     1. `[mode + 0x28]` is the object manager and `[mgr + 0x0]` / `[mgr + 0xc]` are its
        element array and count. Not a hypothesis any more -- 0xac3d80 and 0xac3ddc walk
        the manager exactly that way.
     2. A live game object carries X at +0x30 and Y at +0x34, and its team at +0x4c.
        +0x4c comes from the engine's own findByTeam; +0x30/+0x34 come from
        genebrawl-public and are the one part of this that is still only a claim, so
        both team offsets are printed and the coordinate verdict is printed with the
        numbers it came from.
     3. 0xac3f20 is setPredictionXY(this, x, y) -- three instructions, pinned to the word.

   The dodge writes nothing unless (3) matches AND (2) produced at least two live objects
   with distinct, in-range positions. That ordering matters: this is the first version
   that can move the character, so the checks that decide it also have to be the checks
   that fail closed. */

typedef void (*tnx_v47_setpred_t)(void *self, int x, int y);

typedef struct {
    uintptr_t object;
    int32_t   gid;        /* +0x8  */
    int32_t   x;          /* +0x30 */
    int32_t   y;          /* +0x34 */
    int32_t   ownerIndex; /* +0x3c */
    int32_t   teamOld;    /* +0x40  the offset this file used until v46 */
    int32_t   teamNew;    /* +0x4c  the offset the engine's findByTeam reads */
    uint8_t   dead;       /* +0xd0  */
    uint8_t   activeFlag; /* +0x1e8, bit 0 */
} tnx_v47_obj_t;

static uintptr_t g_v47_setpred = 0;
static int g_v47_setpred_state = -1;    /* -1 untested, 0 mismatch, 1 verified */
static int g_v47_probe_done = 0;
/* The probe is NOT a one-shot. A candidate adopted in the lobby is a different object
   from the one a battle produces, and a verdict reached on the wrong object would be
   permanent: `coord_ok=0` forever while a real battle runs. So the probe re-runs
   whenever the mode object changes, and keeps retrying quietly while it fails. */
static uintptr_t g_v47_probe_object = 0;
static uint64_t g_v47_probe_last_ms = 0;
static int g_v47_coord_ok = 0;
static int g_v47_coord_usable = 0;
static int g_v47_coord_distinct = 0;
static int g_v47_team_off = 0x4c;
static int g_v47_map_w = 0;
static int g_v47_map_h = 0;
static int g_v47_map_ok = 0;
static uint64_t g_v47_ticks = 0;
static uint64_t g_v47_threat_ticks = 0;
static uint64_t g_v47_writes = 0;
static uint64_t g_v47_last_write_ms = 0;
static int g_v47_giveup_logs = 0;

/* The whole of 0xac3f20 as the image holds it today:

       b901d401   str w1, [x0, #0x1d4]
       b901d802   str w2, [x0, #0x1d8]
       d65f03c0   ret

   A function three instructions long has no prologue to pattern-match, which is the
   point: every one of its words is checkable, so "is this really the setter" has an
   exact answer instead of a heuristic one. */
static int tnx_v47_verify_setprediction(void) {
    static const uint32_t expected[3] = { 0xb901d401u, 0xb901d802u, 0xd65f03c0u };
    uint32_t words[3] = { 0, 0, 0 };
    uintptr_t address = 0;

    if (!g_base) return 0;

    address = g_base + TNX_RVA_SETPREDICTION;

    if (!tnx_addr_readable(address, sizeof(words))) return 0;
    if (!tnx_read_bytes(address, words, sizeof(words))) return 0;

    for (int i = 0; i < 3; i++) {
        if (words[i] != expected[i]) {
            tnx_logf("v47 setprediction MISMATCH word[%d]=%08x expected=%08x at %#llx",
                     i, words[i], expected[i], (unsigned long long)TNX_RVA_SETPREDICTION);
            return 0;
        }
    }

    tnx_logf("v47 setprediction verified at %#llx (str w1,[x0,#0x1d4]; str w2,[x0,#0x1d8]; ret)",
             (unsigned long long)TNX_RVA_SETPREDICTION);

    return 1;
}

/* The tile map, whose two numbers are the only independent scale reference available:
   if the object coordinates are real, they have to fit inside a map the engine
   describes. Read through the same `[mode+0xf8]` path 0xac3f48 uses. */
static void tnx_v47_read_map(uintptr_t mode) {
    void *tileMap = NULL;
    int32_t width = 0;
    int32_t height = 0;

    g_v47_map_ok = 0;
    g_v47_map_w = 0;
    g_v47_map_h = 0;

    if (!tnx_read_ptr(mode + TNX_MODE_TILEMAP_OFF, &tileMap) || !tileMap) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_WIDTH_OFF, &width)) return;
    if (!tnx_read_i32((uintptr_t)tileMap + TNX_TILEMAP_HEIGHT_OFF, &height)) return;

    g_v47_map_w = width;
    g_v47_map_h = height;
    g_v47_map_ok = (width >= TNX_V47_MAP_MIN && width <= TNX_V47_MAP_MAX &&
                    height >= TNX_V47_MAP_MIN && height <= TNX_V47_MAP_MAX) ? 1 : 0;
}

/* Walks the object manager the engine's own code walks. Returns how many elements were
   readable; elements that fail are counted, not silently dropped, so a manager that has
   moved shows up as `usable=0` rather than as an absent table. */
static int tnx_v47_collect(uintptr_t mode, tnx_v47_obj_t *out, int capacity, int *rejected) {
    void *manager = NULL;
    void *data = NULL;
    int32_t count = 0;
    int usable = 0;
    int bad = 0;

    if (rejected) *rejected = 0;

    if (!tnx_read_ptr(mode + TNX_MODE_MANAGER_OFF, &manager) || !manager) return 0;
    if (!tnx_read_ptr((uintptr_t)manager + TNX_MGR_ARRAY_OFF, &data) || !data) return 0;
    if (!tnx_read_i32((uintptr_t)manager + TNX_MGR_COUNT_OFF, &count)) return 0;
    if (count <= 0) return 0;

    if (count > capacity) count = capacity;

    for (int32_t i = 0; i < count && usable < capacity; i++) {
        void *element = NULL;
        tnx_v47_obj_t entry;

        memset(&entry, 0, sizeof(entry));

        if (!tnx_read_ptr((uintptr_t)data + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) { bad++; continue; }

        entry.object = (uintptr_t)element;

        if (!tnx_read_i32(entry.object + TNX_OBJ_GLOBALID_OFF, &entry.gid)) { bad++; continue; }
        if (!tnx_read_i32(entry.object + TNX_OBJ_X_OFF, &entry.x)) { bad++; continue; }
        if (!tnx_read_i32(entry.object + TNX_OBJ_Y_OFF, &entry.y)) { bad++; continue; }
        if (!tnx_read_i32(entry.object + TNX_OBJ_OWNERINDEX_OFF, &entry.ownerIndex)) { bad++; continue; }
        if (!tnx_read_i32(entry.object + TNX_OBJ_TEAM_OFF, &entry.teamOld)) { bad++; continue; }
        if (!tnx_read_i32(entry.object + TNX_OBJ_TEAMENGINE_OFF, &entry.teamNew)) { bad++; continue; }
        if (!tnx_read_u8(entry.object + TNX_OBJ_DEADFLAG_OFF, &entry.dead)) { bad++; continue; }
        if (!tnx_read_u8(entry.object + TNX_OBJ_ACTIVEFLAG_OFF, &entry.activeFlag)) { bad++; continue; }

        out[usable++] = entry;
    }

    if (rejected) *rejected = bad;

    return usable;
}

/* One read-only pass that prints the table and then says, in one line, whether the
   coordinates are real. The verdict needs all of: at least two objects, every position
   inside the guard, at least two distinct positions, and a team field that actually
   separates them. */
static void tnx_v47_probe(uintptr_t mode, int verbose) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    int rejected = 0;
    int usable = 0;
    int inRange = 0;
    int distinct = 0;
    int teamsOld[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int teamsNew[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    int distinctOld = 0;
    int distinctNew = 0;

    memset(objects, 0, sizeof(objects));

    g_v47_probe_done = 1;

    tnx_v47_read_map(mode);

    usable = tnx_v47_collect(mode, objects, TNX_V47_OBJECT_MAX, &rejected);

    for (int i = 0; i < usable; i++) {
        if (objects[i].x > -TNX_V47_COORD_ABS_MAX && objects[i].x < TNX_V47_COORD_ABS_MAX &&
            objects[i].y > -TNX_V47_COORD_ABS_MAX && objects[i].y < TNX_V47_COORD_ABS_MAX) {
            inRange++;
        }

        if (objects[i].teamOld >= 0 && objects[i].teamOld < 8) teamsOld[objects[i].teamOld] = 1;
        if (objects[i].teamNew >= 0 && objects[i].teamNew < 8) teamsNew[objects[i].teamNew] = 1;

        /* Distinct positions: an object is "new" if no earlier one shares its pair. */
        {
            int seen = 0;

            for (int j = 0; j < i; j++) {
                if (objects[j].x == objects[i].x && objects[j].y == objects[i].y) { seen = 1; break; }
            }

            if (!seen) distinct++;
        }
    }

    for (int i = 0; i < 8; i++) {
        if (teamsOld[i]) distinctOld++;
        if (teamsNew[i]) distinctNew++;
    }

    /* Whichever field actually separates objects into sides wins; a tie keeps the
       engine's own offset, because that one is not a guess. */
    g_v47_team_off = (distinctOld > distinctNew) ? (int)TNX_OBJ_TEAM_OFF : (int)TNX_OBJ_TEAMENGINE_OFF;

    tnx_logf("v47 man walk manager=%p usable=%d rejected=%d mapOk=%d mapW=%d mapH=%d "
             "inRange=%d distinct=%d teamsOld=%d teamsNew=%d teamOff=0x%x",
             (void *)mode, usable, rejected, g_v47_map_ok, g_v47_map_w, g_v47_map_h,
             inRange, distinct, distinctOld, distinctNew, g_v47_team_off);

    /* The long form is printed when the battle object changes -- i.e. once per match --
       and the short form while the verdict is still failing, so a re-probe does not
       spend the log budget restating offsets that did not move. */
    if (verbose) {
        tnx_logf("v47 offsets obj off=0x%llx/0x%llx x=0x%llx y=0x%llx teamOld=0x%llx teamNew=0x%llx "
                 "owner=0x%llx dead=0x%llx active=0x%llx tilemap=0x%llx w=0x%llx",
                 TNX_MGR_ARRAY_OFF, TNX_MGR_COUNT_OFF, TNX_OBJ_X_OFF, TNX_OBJ_Y_OFF,
                 TNX_OBJ_TEAM_OFF, TNX_OBJ_TEAMENGINE_OFF, TNX_OBJ_OWNERINDEX_OFF,
                 TNX_OBJ_DEADFLAG_OFF, TNX_OBJ_ACTIVEFLAG_OFF,
                 TNX_MODE_TILEMAP_OFF, TNX_TILEMAP_WIDTH_OFF);

        for (int i = 0; i < usable && i < 16; i++) {
            tnx_logf("v47 obj[%02d] at=%p gid=%d pos=(%d,%d) own=%d teamOld=%d teamNew=%d "
                     "dead=%d active=%d",
                     i, (void *)objects[i].object, objects[i].gid, objects[i].x, objects[i].y,
                     objects[i].ownerIndex, objects[i].teamOld, objects[i].teamNew,
                     objects[i].dead, objects[i].activeFlag & 1);
        }
    }

    g_v47_coord_usable = usable;
    g_v47_coord_distinct = distinct;

    g_v47_coord_ok = (usable >= 2 && inRange == usable && distinct >= 2 &&
                      (distinctOld >= 2 || distinctNew >= 2)) ? 1 : 0;

    tnx_logf("v47 coords ok=%d (need >=2 objects, all in range, >=2 distinct positions, "
             "and a team field that splits them)",
             g_v47_coord_ok);
}

static void tnx_autododge_v47(void) {
    tnx_v47_obj_t objects[TNX_V47_OBJECT_MAX];
    int32_t predictX = 0;
    int32_t predictY = 0;
    int rejected = 0;
    int usable = 0;
    int ownIndex = -1;
    int32_t ownTeam = 0;
    int ownX = 0;
    int ownY = 0;
    int64_t ownBest = 0;
    float escapeX = 0.0f;
    float escapeY = 0.0f;
    int threats = 0;
    int threatsAlive = 0;

    if (!g_mode_object || !g_base) return;

    if (g_v47_setpred_state < 0) {
        g_v47_setpred_state = tnx_v47_verify_setprediction();
        g_v47_setpred = g_v47_setpred_state ? (g_base + TNX_RVA_SETPREDICTION) : 0;
    }

    {
        uint64_t probeNow = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
        int changed = (g_v47_probe_object != g_mode_object);

        if (!g_v47_probe_done || changed ||
            (!g_v47_coord_ok && probeNow > g_v47_probe_last_ms + TNX_V47_REPROBE_MS)) {
            g_v47_probe_object = g_mode_object;
            g_v47_probe_last_ms = probeNow;
            tnx_v47_probe(g_mode_object, changed || !g_v47_probe_done);
        }
    }

    g_v47_ticks++;

    if (!g_v47_setpred_state) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v47 dodge idle: no verified actuator (setprediction state=%d)",
                     g_v47_setpred_state);
        }
        return;
    }

    if (!g_v47_coord_ok) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v47 dodge idle: coordinates not confirmed (usable=%d distinct=%d) -- "
                     "read-only until they are", g_v47_coord_usable, g_v47_coord_distinct);
        }
        return;
    }

    memset(objects, 0, sizeof(objects));

    usable = tnx_v47_collect(g_mode_object, objects, TNX_V47_OBJECT_MAX, &rejected);

    if (usable < 2) return;

    /* The prediction pair is where this client believes it is going. The object nearest
       to it is our own character -- which is how "own" gets an identity without a
       getter whose only known reference is for another build. */
    if (!tnx_read_i32(g_mode_object + TNX_MODE_PREDICTX_OFF, &predictX)) return;
    if (!tnx_read_i32(g_mode_object + TNX_MODE_PREDICTY_OFF, &predictY)) return;

    if (predictX <= -TNX_V47_COORD_ABS_MAX || predictX >= TNX_V47_COORD_ABS_MAX) return;
    if (predictY <= -TNX_V47_COORD_ABS_MAX || predictY >= TNX_V47_COORD_ABS_MAX) return;
    if (predictX == 0 && predictY == 0) return;

    for (int i = 0; i < usable; i++) {
        int64_t dx = (int64_t)objects[i].x - (int64_t)predictX;
        int64_t dy = (int64_t)objects[i].y - (int64_t)predictY;
        int64_t distance = dx * dx + dy * dy;

        if (ownIndex < 0 || distance < ownBest) {
            ownIndex = i;
            ownBest = distance;
        }
    }

    if (ownIndex < 0) return;

    /* The prediction has to land ON an object. If the nearest one is arbitrarily far,
       then +0x30/+0x34 are not a position and the prediction is not a position either;
       adding a step to that arithmetic and handing it to the setter would be steering by
       noise. Failing here is the whole reason the actuator is safe to have at all. */
    if (ownBest > TNX_V47_OWN_MAX_SQ) {
        if (g_v47_giveup_logs < 3) {
            g_v47_giveup_logs++;
            tnx_logf("v47 dodge idle: prediction (%d,%d) is not near any object -- nearest "
                     "squared distance %lld -- so +0x30/+0x34 are not positions",
                     predictX, predictY, (long long)ownBest);
        }
        return;
    }

    /* A dead character has nowhere to dodge to. */
    if (objects[ownIndex].dead) return;

    ownTeam = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[ownIndex].teamOld
                                                        : objects[ownIndex].teamNew;
    ownX = objects[ownIndex].x;
    ownY = objects[ownIndex].y;

    for (int i = 0; i < usable; i++) {
        int32_t team = 0;
        float dx = 0.0f;
        float dy = 0.0f;
        float distance = 0.0f;
        float weight = 0.0f;

        if (i == ownIndex) continue;
        if (objects[i].dead) continue;

        team = (g_v47_team_off == (int)TNX_OBJ_TEAM_OFF) ? objects[i].teamOld
                                                         : objects[i].teamNew;
        if (team == ownTeam) continue;

        /* Hostiles counted here, before the activity bit and before the range test, so
           the three numbers in the log are strictly nested: hostilesAlive >=
           enemiesActive >= enemiesInRange. A zero somewhere in that chain names which
           test is wrong -- an inverted +0x1e8 bit shows as hostilesAlive non-zero with
           enemiesActive zero, rather than as an unexplained empty dodge. */
        threatsAlive++;

        if ((objects[i].activeFlag & 1) == 0) continue;

        dx = (float)(ownX - objects[i].x);
        dy = (float)(ownY - objects[i].y);
        distance = dx * dx + dy * dy;

        if (distance > DODGE_RANGE_SQ || distance < 1.0f) continue;

        /* Push directly away, weighted so the closest threat dominates the sum. */
        weight = 1.0f / (sqrtf(distance) + 1.0f);
        escapeX += dx * weight;
        escapeY += dy * weight;
        threats++;
    }

    if (threats == 0) {
        if (g_v47_ticks % 256 == 0) {
            tnx_logf("v47 live ticks=%llu own=(%d,%d) team=%d pred=(%d,%d) hostilesAlive=%d "
                     "enemiesActive=%d enemiesInRange=0 writes=%llu threatsTotal=%llu",
                     (unsigned long long)g_v47_ticks, ownX, ownY, ownTeam, predictX, predictY,
                     threatsAlive, threats, (unsigned long long)g_v47_writes,
                     (unsigned long long)g_v47_threat_ticks);
        }
        return;
    }

    g_v47_threat_ticks++;

    {
        float length = sqrtf(escapeX * escapeX + escapeY * escapeY);
        uint64_t now = 0;
        int targetX = 0;
        int targetY = 0;

        if (length <= 0.0001f) return;

        escapeX /= length;
        escapeY /= length;

        now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

        if (now < g_v47_last_write_ms + (uint64_t)TNX_V47_DODGE_MIN_MS) return;

        g_v47_last_write_ms = now;

        targetX = ownX + (int)(escapeX * DODGE_STEP);
        targetY = ownY + (int)(escapeY * DODGE_STEP);

        if (targetX > TNX_V47_COORD_ABS_MAX) targetX = TNX_V47_COORD_ABS_MAX;
        if (targetX < -TNX_V47_COORD_ABS_MAX) targetX = -TNX_V47_COORD_ABS_MAX;
        if (targetY > TNX_V47_COORD_ABS_MAX) targetY = TNX_V47_COORD_ABS_MAX;
        if (targetY < -TNX_V47_COORD_ABS_MAX) targetY = -TNX_V47_COORD_ABS_MAX;

        ((tnx_v47_setpred_t)g_v47_setpred)((void *)g_mode_object, targetX, targetY);

        g_v47_writes++;

        if (g_v47_writes <= TNX_V47_LOG_FIRST || (g_v47_writes % TNX_V47_LOG_EVERY) == 0) {
            tnx_logf("v47 write #%llu own=(%d,%d) team=%d hostilesAlive=%d enemiesInRange=%d "
                     "step=(%d,%d) target=(%d,%d) predBefore=(%d,%d)",
                     (unsigned long long)g_v47_writes, ownX, ownY, ownTeam,
                     threatsAlive, threats, (int)(escapeX * DODGE_STEP),
                     (int)(escapeY * DODGE_STEP), targetX, targetY, predictX, predictY);
        }
    }
}

static void tnx_dodge_plan(uintptr_t manager, int32_t team) {
    void *array = NULL;
    int32_t count = 0;
    int live = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t gid = 0;
        int32_t t = 0;
        uint8_t dead = 0;
        uintptr_t s88 = 0;
        uintptr_t s90 = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_gameobject_shape((uintptr_t)element)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_GLOBALID_OFF, &gid)) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (!tnx_read_u8((uintptr_t)element + TNX_OBJ_DEADFLAG_OFF, &dead)) continue;

        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETX_SLOT, &s88);
        tnx_obj_slot_fn((uintptr_t)element, TNX_OBJ_GETY_SLOT, &s90);

        live++;

        tnx_logf("dodge team=%d i=%d obj=%p gid=%d team=%d dead=%d s88=%#llx s90=%#llx",
                 team, i, element, gid, t, dead,
                 (unsigned long long)s88, (unsigned long long)s90);
    }

    tnx_logf("dodge team=%d live=%d DISABLED - no coordinate source: slot 0x88 takes an "
             "argument at 0xae48f0, so it is not getX; the RVAs above identify the class",
             team, live);
}
static void tnx_dodge_all_teams(uintptr_t manager) {
    int32_t teams[TNX_OBJ_TEAM_MAX + 1];
    int teamCount = 0;
    void *array = NULL;
    int32_t count = 0;

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return;
    if (count <= 0) return;
    if (count > TNX_MANAGER_MAX_OBJECTS) count = TNX_MANAGER_MAX_OBJECTS;

    for (int i = 0; i <= TNX_OBJ_TEAM_MAX; i++) teams[i] = -1;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t t = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;
        if (!tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &t)) continue;
        if (t < 0 || t > TNX_OBJ_TEAM_MAX) continue;
        if (teams[t] >= 0) continue;

        teams[t] = t;
        teamCount++;
    }

    if (teamCount == 0) return;

    /* Two teams is the whole of a real match. The plan calls into the game's own getters, so
       the number of runs per capture is bounded rather than left to whatever the array holds. */
    {
        int planned = 0;

        for (int t = 0; t <= TNX_OBJ_TEAM_MAX && planned < 2; t++) {
            if (teams[t] < 0) continue;

            tnx_dodge_plan(manager, t);
            planned++;
        }
    }
}

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

        tnx_logf("slot %s: captured this=%p arg1=%p hits=%llu%s", g_slot_specs[i].tag,
                 (void *)g_slot_object[i], (void *)g_slot_arg1[i],
                 (unsigned long long)g_slot_hits[i],
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

    /* THE shot. If this slot was setOwner, a1 IS the manager the engine just stored into the
       object -- no hunting, no scan, no threshold. It is reported before anything else. */
    if (g_slot_arg1[first]) {
        tnx_report_manager("slot arg1", g_slot_arg1[first]);
    }

    /* Class B stores it at +0x20 (setOwner), class A reaches it through +0x8. */
    void *ownerField = NULL;

    if (tnx_read_ptr(object + TNX_SLOT_OWNER_OFF, &ownerField) && ownerField &&
        (uintptr_t)ownerField != g_slot_arg1[first]) {
        tnx_report_manager("slot +20", (uintptr_t)ownerField);
    }

    /* The plan itself, from whichever manager the capture produced. Read-only: it computes and
       logs the two numbers a movement call would need, so the geometry can be verified from a
       log before the entry point is known. */
    {
        uintptr_t plan = g_slot_arg1[first] ? g_slot_arg1[first] : (uintptr_t)ownerField;

        if (plan && tnx_manager_live_count(plan) >= TNX_MANAGER_MIN_OBJECTS) {
            int detailed = tnx_object_detail(plan, TNX_OBJECT_DETAIL_MAX);

            tnx_raw_object_hex(plan, 2);

            if (detailed > 0) tnx_dodge_all_teams(plan);
        }
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

    tnx_slot_table_dump();
    tnx_struct_map_dump();

    tnx_logf("build=%s slots=%d control=%d types>=%d scanEvery=%d heapEvery=%d attempts=%d "
             "arrayProbeLimit=%d chainProbeLimit=%d voteMin=%d voteConfirm=%d voteTeamsMin=%d "
             "ownerVoteMax=%d gidMax=%d objhitDump=%d censusMax=%d censusPrint=%d censusSlots=%d "
             "budgetMin=%lluMB budgetMax=%lluMB",
             TNX_BUILD_TAG, TNX_SLOT_COUNT - buildControls, buildControls, TNX_MODE_MIN_TYPES,
             TNX_VOTESCAN_GLOBAL_EVERY, TNX_VOTESCAN_HEAP_EVERY, TNX_VOTESCAN_ATTEMPTS,
             TNX_MANAGER_PROBE_LIMIT, TNX_CHAIN_PROBE_LIMIT, TNX_OWNER_VOTE_MIN,
             TNX_OWNER_VOTE_CONFIRM, TNX_OWNER_VOTE_TEAMS_MIN, TNX_OWNER_VOTE_MAX,
             TNX_OWNER_VOTE_GID_MAX, TNX_OBJ_HIT_PRINT_MAX, TNX_VTCENSUS_MAX, TNX_VTCENSUS_PRINT,
             TNX_VTCENSUS_SLOTS, TNX_HEAP_SCAN_BUDGET / (1024ull * 1024ull),
             TNX_HEAP_SCAN_BUDGET_MAX / (1024ull * 1024ull));

    /* Stated up front because it is the measurement this build is built on: the 20:22 run's own
       pass lines prove that the "complete sweep" this project has been quoting since 20:06 never
       happened, and the objhit dump names classes that the nine-entry probe list does not contain. */
    tnx_logf("plan: the v45 log answered the question v45 was built for and broke one assumption "
             "underneath it. ANSWERED, from the objhit dump: the live objects carry class tables of "
             "their own - 0x100a770 under three heap-owned objects, plus 0xf923e0, 0xf92468, "
             "0x1014f70, 0x1008be0, 0x1009290 - and none of them is in the nine-entry vtprobe list, "
             "which is the whole explanation of hooks fired=0 of 7. Also answered: +0x20 never "
             "repeats (maxVotes=1 in all three passes, a different topOwner each time), so no vote "
             "can ever name the manager through that field, and the 0x1008d30 family that fooled the "
             "19:51 run is now correctly classified image instead of becoming a capture. BROKEN: the "
             "20:06 conclusion that vtprobe=0 was measured over a COMPLETE sweep. Both 20:22 passes "
             "scanned ~540 MB and both were cut off by the fixed 512 MB budget, but pass 1 started "
             "at 0x0 (mostly memory BELOW the window) and pass 3 at the window low, so they were cut "
             "off over different memory - and the ninth counter duly read 0 on the first and 92502 "
             "on the second. So v46 (1) makes the budget follow the window and prints budget=/"
             "budgetHit=/readTo=, (2) resumes a budget-cut pass at the exact address it stopped "
             "instead of past the whole region, (3) splits the accumulated vtprobe= into "
             "vtprobePass=/vtprobeAll= and names the first address behind each non-zero counter, and "
             "(4) replaces the nine-name list with a census: every 16-byte aligned word pointing into "
             "__DATA_CONST or __DATA is counted per class table, with the number of instances, how "
             "many of them passed the full object record layout (shaped=), and how many read the same "
             "at +0x00 and +0x20 (ownerEqVt=, the 19:51 signature as a count). vtslots then prints "
             "the first slot RVAs of the two most interesting tables - the hook targets for v47. And "
             "(5) one more split, because the 20:22 run put 398 of its 597 shaped words in "
             "ownerNoRegion and that number has two opposite explanations: the window is rebuilt "
             "every tenth attempt and it SHRANK during that run from 7776 MB to 567 MB, so an owner "
             "above the window high is a WINDOW problem while an owner in no region at all is a "
             "REGION problem. They are now ownerAboveWin= and ownerNoRegion=, and objShaped= is "
             "counted uncapped so the identity hits+skipped+ownerImg+ownerNoRegion+ownerAboveWin = "
             "objShaped can actually be checked - v45 printed the dump's capped count there, which "
             "made the check impossible exactly when there was something to check");

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
