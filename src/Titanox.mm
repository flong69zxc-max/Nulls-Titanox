#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <math.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import "offsets.h"
#import "lc_detect.h"

#define LOG_MAX_BYTES (512 * 1024)
#define OBJC_HOOK_MAX 64

typedef void (*fn_send_movement_t)(void *, float, float);
typedef void (*fn_set_prediction_t)(void *, int, int);
typedef void *(*fn_get_inst_t)(void);
typedef void *(*fn_get_own_char_t)(void *);
typedef int   (*fn_get_team_t)(void *);
typedef void *(*fn_get_data_t)(void *);
typedef int   (*fn_get_coord_t)(void *);
typedef void *(*fn_get_movieclip_t)(uintptr_t);
typedef void *(*fn_get_textfield_t)(void *, uintptr_t);
typedef void  (*fn_set_text_t)(void *, void *, int, int);
typedef void  (*fn_set_xy_t)(void *, float, float);
typedef void  (*fn_add_child_t)(void *, void *);

typedef struct {
    Class cls;
    SEL sel;
    IMP original;
    IMP replacement;
    const char *clsName;
    const char *selName;
    const char *signature;
    int hits;
    bool used;
} tnx_objc_hook_t;

static uintptr_t g_base = 0;
static FILE *g_log = NULL;
static long g_log_written = 0;
static BOOL g_setup_done = NO;

static tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];
static volatile int g_objc_armed = 0;

static void *g_label_tf = NULL;
static void *g_label_clip = NULL;
static int g_label_state = 0;
static int g_label_updates = 0;

static const char *TITANOX_OBJC_CLASSES[] = {
    "MetalView",
    "NullView",
    "AppController",
    NULL
};

static const char *TITANOX_OBJC_SELECTORS[] = {
    "render",
    NULL
};

static void tlog(NSString *msg) {
    if (!g_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"Titanox.log"];
            g_log = fopen([logPath UTF8String], "a");
        }
    }

    if (g_log && g_log_written < LOG_MAX_BYTES) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        NSString *ts = [df stringFromDate:[NSDate date]];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", ts, msg];
        const char *utf8 = [line UTF8String];
        size_t len = strlen(utf8);
        fwrite(utf8, 1, len, g_log);
        fflush(g_log);
        g_log_written += len;
    }
}

static BOOL find_game_image(uintptr_t *outBase) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "Nulls Brawl") || strstr(name, "Laser") || strstr(name, "NB.app")) {
            const struct mach_header *h = _dyld_get_image_header(i);
            if (h && h->magic == MH_MAGIC_64) {
                if (outBase) *outBase = (uintptr_t)h;
                return YES;
            }
        }
    }
    return NO;
}

static void *tnx_read_global_ptr(uintptr_t rva) {
    if (!g_base || !rva) return NULL;
    uintptr_t slot = g_base + rva;
    void **ptr = reinterpret_cast<void **>(slot);
    return *ptr;
}

static void tnx_run_autododge(void) {
    if (!g_base) return;

    fn_get_inst_t fn_get_battle = reinterpret_cast<fn_get_inst_t>(g_base + RVA_BATTLEMODE_GETINSTANCE);
    void *battleMode = fn_get_battle ? fn_get_battle() : NULL;
    if (!battleMode) return;

    fn_get_own_char_t fn_get_own = reinterpret_cast<fn_get_own_char_t>(g_base + RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    void *ownChar = fn_get_own ? fn_get_own(battleMode) : NULL;
    if (!ownChar) return;

    uint8_t dead = *reinterpret_cast<uint8_t *>(reinterpret_cast<uintptr_t>(ownChar) + OFF_GAMEOBJ_DEADFLAG);
    if (dead) return;

    fn_get_coord_t fn_get_x = reinterpret_cast<fn_get_coord_t>(g_base + RVA_LOGICGAMEOBJECTCLIENT_GETX);
    fn_get_coord_t fn_get_y = reinterpret_cast<fn_get_coord_t>(g_base + RVA_LOGICGAMEOBJECTCLIENT_GETY);
    fn_get_team_t fn_get_team = reinterpret_cast<fn_get_team_t>(g_base + RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);

    int ownX = fn_get_x ? fn_get_x(ownChar) : 0;
    int ownY = fn_get_y ? fn_get_y(ownChar) : 0;
    int ownTeam = fn_get_team ? fn_get_team(battleMode) : 0;

    void *objMgr = *reinterpret_cast<void **>(reinterpret_cast<uintptr_t>(battleMode) + OFF_BATTLEMODE_OBJECTMANAGERPTR);
    if (!objMgr) return;

    void **objects = *reinterpret_cast<void ***>(reinterpret_cast<uintptr_t>(objMgr) + OFF_OBJECTMANAGER_OBJECTSARRAY);
    int count = *reinterpret_cast<int *>(reinterpret_cast<uintptr_t>(objMgr) + OFF_OBJECTMANAGER_COUNT);
    if (!objects || count <= 0) return;

    fn_get_data_t fn_get_data = reinterpret_cast<fn_get_data_t>(g_base + RVA_LOGICGAMEOBJECTCLIENT_GETDATA);

    float dodgeX = 0.0f;
    float dodgeY = 0.0f;
    bool danger = false;

    int maxScan = (count < 256) ? count : 256;
    for (int i = 0; i < maxScan; i++) {
        void *obj = objects[i];
        if (!obj || obj == ownChar) continue;

        uint8_t objDead = *reinterpret_cast<uint8_t *>(reinterpret_cast<uintptr_t>(obj) + OFF_GAMEOBJ_DEADFLAG);
        if (objDead) continue;

        int team = *reinterpret_cast<int *>(reinterpret_cast<uintptr_t>(obj) + OFF_GAMEOBJ_TEAM);
        if (team == ownTeam) continue;

        void *data = fn_get_data ? fn_get_data(obj) : NULL;
        if (!data) continue;

        int px = fn_get_x ? fn_get_x(obj) : 0;
        int py = fn_get_y ? fn_get_y(obj) : 0;

        float dx = static_cast<float>(ownX - px);
        float dy = static_cast<float>(ownY - py);
        float distSq = dx * dx + dy * dy;

        if (distSq > (1800.0f * 1800.0f) || distSq < 1.0f) continue;

        float angle = *reinterpret_cast<float *>(reinterpret_cast<uintptr_t>(obj) + OFF_PROJECTILE_SPAWNANGLE);
        float vx = cosf(angle);
        float vy = sinf(angle);

        float dot = dx * vx + dy * vy;
        if (dot <= 0.0f) continue;

        float perpDist = fabsf(dx * vy - dy * vx);
        float threatRadius = 320.0f;

        if (perpDist < threatRadius) {
            float nx = -vy;
            float ny = vx;

            if ((dx * nx + dy * ny) < 0.0f) {
                nx = -nx;
                ny = -ny;
            }

            float weight = 1.0f / (perpDist + 1.0f);
            dodgeX += nx * weight;
            dodgeY += ny * weight;
            danger = true;
        }
    }

    if (danger) {
        float len = sqrtf(dodgeX * dodgeX + dodgeY * dodgeY);
        if (len > 0.0001f) {
            dodgeX /= len;
            dodgeY /= len;
        }

        fn_set_prediction_t fn_pred = reinterpret_cast<fn_set_prediction_t>(g_base + RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO);
        if (fn_pred) {
            int targetX = ownX + static_cast<int>(dodgeX * 600.0f);
            int targetY = ownY + static_cast<int>(dodgeY * 600.0f);
            fn_pred(battleMode, targetX, targetY);
        }

        void *inputMgr = *reinterpret_cast<void **>(reinterpret_cast<uintptr_t>(battleMode) + OFF_BATTLEMODE_CLIENTINPUTMANAGER);
        if (inputMgr) {
            fn_send_movement_t fn_move = reinterpret_cast<fn_send_movement_t>(g_base + RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT);
            if (fn_move) {
                fn_move(inputMgr, dodgeX, dodgeY);
            }
        }
    }
}

static void tnx_run_autoaim(void) {
    if (!g_base) return;

    fn_get_inst_t fn_get_battle = reinterpret_cast<fn_get_inst_t>(g_base + RVA_BATTLEMODE_GETINSTANCE);
    void *battleMode = fn_get_battle ? fn_get_battle() : NULL;
    if (!battleMode) return;

    fn_get_own_char_t fn_get_own = reinterpret_cast<fn_get_own_char_t>(g_base + RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER);
    void *ownChar = fn_get_own ? fn_get_own(battleMode) : NULL;
    if (!ownChar) return;

    fn_get_coord_t fn_get_x = reinterpret_cast<fn_get_coord_t>(g_base + RVA_LOGICGAMEOBJECTCLIENT_GETX);
    fn_get_coord_t fn_get_y = reinterpret_cast<fn_get_coord_t>(g_base + RVA_LOGICGAMEOBJECTCLIENT_GETY);
    fn_get_team_t fn_get_team = reinterpret_cast<fn_get_team_t>(g_base + RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM);

    int ownX = fn_get_x ? fn_get_x(ownChar) : 0;
    int ownY = fn_get_y ? fn_get_y(ownChar) : 0;
    int ownTeam = fn_get_team ? fn_get_team(battleMode) : 0;

    void *objMgr = *reinterpret_cast<void **>(reinterpret_cast<uintptr_t>(battleMode) + OFF_BATTLEMODE_OBJECTMANAGERPTR);
    if (!objMgr) return;

    void **objects = *reinterpret_cast<void ***>(reinterpret_cast<uintptr_t>(objMgr) + OFF_OBJECTMANAGER_OBJECTSARRAY);
    int count = *reinterpret_cast<int *>(reinterpret_cast<uintptr_t>(objMgr) + OFF_OBJECTMANAGER_COUNT);
    if (!objects || count <= 0) return;

    float closestDistSq = 999999999.0f;
    int targetX = 0;
    int targetY = 0;
    bool foundTarget = false;

    int maxScan = (count < 256) ? count : 256;
    for (int i = 0; i < maxScan; i++) {
        void *obj = objects[i];
        if (!obj || obj == ownChar) continue;

        uint8_t dead = *reinterpret_cast<uint8_t *>(reinterpret_cast<uintptr_t>(obj) + OFF_GAMEOBJ_DEADFLAG);
        if (dead) continue;

        int team = *reinterpret_cast<int *>(reinterpret_cast<uintptr_t>(obj) + OFF_GAMEOBJ_TEAM);
        if (team == ownTeam) continue;

        int ex = fn_get_x ? fn_get_x(obj) : 0;
        int ey = fn_get_y ? fn_get_y(obj) : 0;

        float dx = static_cast<float>(ex - ownX);
        float dy = static_cast<float>(ey - ownY);
        float distSq = dx * dx + dy * dy;

        if (distSq < closestDistSq && distSq > 1.0f) {
            closestDistSq = distSq;
            targetX = ex;
            targetY = ey;
            foundTarget = true;
        }
    }

    if (foundTarget) {
        uintptr_t battleScreen = g_base + RVA_BATTLESCREEN__BATTLESCREEN;
        if (battleScreen) {
            *reinterpret_cast<int *>(battleScreen + OFF_BATTLESCREEN_AUTOFIREX) = targetX;
            *reinterpret_cast<int *>(battleScreen + OFF_BATTLESCREEN_AUTOFIREY) = targetY;
        }
    }
}

static void tnx_render_watermark(void) {
    if (!g_base) return;

    if (!g_label_clip) {
        fn_get_movieclip_t fn_get_mc = reinterpret_cast<fn_get_movieclip_t>(g_base + RVA_STRINGTABLE_GETMOVIECLIP);
        fn_get_textfield_t fn_get_tf = reinterpret_cast<fn_get_textfield_t>(g_base + RVA_MOVIECLIP__GETTEXTFIELDBYNAME);
        fn_set_xy_t fn_set_xy = reinterpret_cast<fn_set_xy_t>(g_base + RVA_DISPLAYOBJECT__SETXY);
        fn_add_child_t fn_add_child = reinterpret_cast<fn_add_child_t>(g_base + RVA_STAGE_ADDCHILD);

        if (!fn_get_mc || !fn_get_tf || !fn_set_xy || !fn_add_child) return;

        void *mc = fn_get_mc(0x1a);
        if (!mc) return;

        void *tf = fn_get_tf(mc, 0x16);
        if (!tf) return;

        void *stage = tnx_read_global_ptr(OFF_STAGEINSTANCEGLOBALPTR);
        if (!stage) return;

        fn_set_xy(mc, 40.0f, 30.0f);
        fn_add_child(stage, mc);

        g_label_clip = mc;
        g_label_tf = tf;
    }

    if (g_label_tf) {
        fn_set_text_t fn_set_text = reinterpret_cast<fn_set_text_t>(g_base + RVA_TEXTFIELD_SETTEXT);
        if (fn_set_text) {
            NSString *label = [NSString stringWithFormat:@"Titanox v1.0 [Zero-Latency]"];
            void *sc = reinterpret_cast<void *>([label UTF8String]);
            fn_set_text(g_label_tf, sc, 4, 0);
            g_label_updates++;
        }
    }
}

static tnx_objc_hook_t *tnx_objc_find(id self, SEL _cmd) {
    Class cls = object_getClass(self);
    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        if (g_objc_hooks[i].cls == cls && g_objc_hooks[i].sel == _cmd) {
            return &g_objc_hooks[i];
        }
    }
    return NULL;
}

static void tnx_objc_rep_render(id self, SEL _cmd) {
    tnx_objc_hook_t *hook = tnx_objc_find(self, _cmd);

    tnx_run_autododge();
    tnx_run_autoaim();
    tnx_render_watermark();

    if (hook && hook->original) {
        reinterpret_cast<void (*)(id, SEL)>(hook->original)(self, _cmd);
    }
}

static int tnx_objc_arm(const char *clsName, const char *selName, IMP replacement) {
    Class cls = objc_getClass(clsName);
    if (!cls) return 0;

    SEL sel = sel_registerName(selName);
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return 0;

    const char *types = method_getTypeEncoding(method);
    if (!types) return 0;

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (!g_objc_hooks[i].used) continue;
        if (g_objc_hooks[i].cls == cls && g_objc_hooks[i].sel == sel) return 0;
    }

    for (int i = 0; i < OBJC_HOOK_MAX; i++) {
        if (g_objc_hooks[i].used) continue;

        IMP previous = method_setImplementation(method, replacement);
        if (!previous) return 0;

        g_objc_hooks[i].used = true;
        g_objc_hooks[i].cls = cls;
        g_objc_hooks[i].sel = sel;
        g_objc_hooks[i].original = previous;
        g_objc_hooks[i].replacement = replacement;
        g_objc_hooks[i].clsName = clsName;
        g_objc_hooks[i].selName = selName;
        g_objc_hooks[i].signature = types;

        g_objc_armed++;
        tlog([NSString stringWithFormat:@"objc hook %s -%s armed", clsName, selName]);
        return 1;
    }
    return 0;
}

static void setup(void) {
    if (g_setup_done) return;
    g_setup_done = YES;

    tlog([NSString stringWithFormat:@"setup base=%p", (void *)g_base]);

    tnx_objc_arm("MetalView", "render", reinterpret_cast<IMP>(tnx_objc_rep_render));
    tnx_objc_arm("NullView", "render", reinterpret_cast<IMP>(tnx_objc_rep_render));

    tlog(@"setup completed successfully");
}

static void poll_for_game(int tick) {
    if (g_setup_done) return;
    if (tick > 1200) return;

    uintptr_t base = 0;
    BOOL found = find_game_image(&base);

    if (found) {
        g_base = base;
        setup();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(0.5 * NSEC_PER_SEC)),
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
