#include "titanox.h"

#define TNX_LAYOUT_OBJ_MAX 8
#define TNX_LAYOUT_SLOT_MAX 320

static uintptr_t t_layout_seen[TNX_LAYOUT_OBJ_MAX] = {0};
static uint8_t t_layout_ready[TNX_LAYOUT_OBJ_MAX] = {0};
static uint8_t t_layout_hit[TNX_LAYOUT_OBJ_MAX][TNX_LAYOUT_SLOT_MAX];
static int32_t t_layout_prev[TNX_LAYOUT_OBJ_MAX][TNX_LAYOUT_SLOT_MAX];
static int t_layout_rr = 0;

static uintptr_t t_layout_slot_addr(uintptr_t base, int slot) {
    if (slot < 160) return base + 0x880 + (uintptr_t)slot * 4;

    return base + 0xe00 + (uintptr_t)(slot - 160) * 4;
}

static const char *t_layout_band(int slot) {
    if (slot < 160) return "joystick";

    return "inputtail";
}

static const char *t_layout_name(int i) {
    if (i == 0) return "bs";
    if (i == 1) return "scene";
    if (i == 2) return "hopBs";
    if (i == 3) return "bsMgr";
    if (i == 4) return "sceneScreen";
    if (i == 5) return "sceneClient";
    if (i == 6) return "bsMode";

    return "sceneState";
}

static float t_layout_as_f(int32_t v) {
    float f;

    __builtin_memcpy(&f, &v, sizeof(f));

    return f;
}

void tnx_layout_probe_3(int dodging) {
    uintptr_t list[TNX_LAYOUT_OBJ_MAX];
    uintptr_t bs = tnx_bs();
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t hop = bs ? tnx_hop(bs, NULL) : 0;
    uintptr_t bsMgr = 0;
    uintptr_t screen = 0;
    uintptr_t client = 0;
    uintptr_t mode = 0;
    uintptr_t state = 0;
    int i;
    int slot;

    if (!TNX_LAYOUT_ON_2) return;

    if (bs) tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&bsMgr);
    if (scene) tnx_read_ptr(scene + TNX_OFF_BATTLE_SCREEN, (void **)&screen);
    if (scene) tnx_read_ptr(scene + TNX_CLIENT_OFF, (void **)&client);
    if (bs) tnx_read_ptr(bs + TNX_CTRL_MODE_OFF, (void **)&mode);
    if (scene) tnx_read_ptr(scene + TNX_OFF_BATTLE_STATE, (void **)&state);

    list[0] = bs;
    list[1] = scene;
    list[2] = hop;
    list[3] = bsMgr;
    list[4] = screen;
    list[5] = client;
    list[6] = mode;
    list[7] = state;

    i = t_layout_rr;
    t_layout_rr = (t_layout_rr + 1) % TNX_LAYOUT_OBJ_MAX;

    {
        uintptr_t base = list[i];

        if (!base) return;

        if (t_layout_seen[i] != base) {
            t_layout_seen[i] = base;
            t_layout_ready[i] = 0;
            __builtin_memset(t_layout_hit[i], 0, sizeof(t_layout_hit[i]));
        }

        for (slot = 0; slot < TNX_LAYOUT_SLOT_MAX; slot++) {
            uintptr_t addr = t_layout_slot_addr(base, slot);
            int32_t now = 0;

            if (!tnx_read_i32(addr, &now)) continue;

            if (!t_layout_ready[i]) {
                t_layout_prev[i][slot] = now;
                continue;
            }

            if (t_layout_prev[i][slot] != now) {
                int32_t prev = t_layout_prev[i][slot];

                t_layout_prev[i][slot] = now;

                if (t_layout_hit[i][slot]) continue;

                t_layout_hit[i][slot] = 1;

                if (t_layout_logs < TNX_LAYOUT_LOGS_2) {
                    TNX_LOGX("layout first obj=%s base=%p off=+0x%llx band=%s prev=%d/%.4f "
                             "now=%d/%.4f dodging=%d - one line per object and offset, logged the "
                             "first time that word ever moves, so a run in which the player walks "
                             "the joystick himself names every offset the game touch path writes "
                             "and the same offset moving again at dodging=1 names the channel this "
                             "build can drive",
                             t_layout_name(i), (void *)base,
                             (unsigned long long)(addr - base), t_layout_band(slot),
                             prev, (double)t_layout_as_f(prev),
                             now, (double)t_layout_as_f(now), dodging);

                    t_layout_logs++;
                }
            }
        }

        t_layout_ready[i] = 1;
    }
}
