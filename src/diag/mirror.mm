#include "titanox.h"

#define TNX_MIRROR_OBJ_MAX 10
#define TNX_MIRROR_SLOT_MAX 320

static uintptr_t t_mirror_seen[TNX_MIRROR_OBJ_MAX] = {0};
static uint8_t t_mirror_ready[TNX_MIRROR_OBJ_MAX] = {0};
static uint8_t t_mirror_hit[TNX_MIRROR_OBJ_MAX][TNX_MIRROR_SLOT_MAX];
static int32_t t_mirror_prev[TNX_MIRROR_OBJ_MAX][TNX_MIRROR_SLOT_MAX];
static int t_mirror_rr = 0;

int t_mirror_logs_2 = 0;

static uintptr_t t_mirror_addr(uintptr_t base, int slot) {
    if (slot < 160) return base + 0x880 + (uintptr_t)slot * 4;

    return base + 0xe00 + (uintptr_t)(slot - 160) * 4;
}

static float t_mirror_f(int32_t v) {
    float f;

    __builtin_memcpy(&f, &v, sizeof(f));

    return f;
}

static const char *t_mirror_name(int i) {
    static const char *n[TNX_MIRROR_OBJ_MAX] = {
        "bs", "scene", "hopBs", "bsMgr", "sceneScreen",
        "sceneClient", "bsMode", "sceneState", "hopCtrl", "ctrlMode"
    };

    return n[i];
}

void tnx_mirror_probe_2(int dodging) {
    uintptr_t list[TNX_MIRROR_OBJ_MAX];
    static uint32_t t_n0_2[TNX_MIRROR_OBJ_MAX][TNX_MIRROR_SLOT_MAX];
    static uint32_t t_n1_2[TNX_MIRROR_OBJ_MAX][TNX_MIRROR_SLOT_MAX];
    static int t_ticks_2 = 0;
    static int t_dumps_2 = 0;
    uintptr_t bs = tnx_bs();
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t ctrl = tnx_controller();
    int i;
    int slot;

    if (!TNX_MIRROR_ON_2) return;

    list[0] = bs;
    list[1] = scene;
    list[2] = bs ? tnx_hop(bs, NULL) : 0;
    list[3] = 0;
    list[4] = 0;
    list[5] = ctrl;
    list[6] = 0;
    list[7] = 0;
    list[8] = ctrl ? tnx_hop(ctrl, NULL) : 0;
    list[9] = 0;

    if (bs) tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&list[3]);
    if (scene) tnx_read_ptr(scene + TNX_OFF_BATTLE_SCREEN, (void **)&list[4]);
    if (bs) tnx_read_ptr(bs + TNX_CTRL_MODE_OFF, (void **)&list[6]);
    if (scene) tnx_read_ptr(scene + TNX_OFF_BATTLE_STATE, (void **)&list[7]);
    if (ctrl) tnx_read_ptr(ctrl + TNX_CTRL_MODE_OFF, (void **)&list[9]);

    i = t_mirror_rr;
    t_mirror_rr = (t_mirror_rr + 1) % TNX_MIRROR_OBJ_MAX;

    {
        uintptr_t base = list[i];

        if (!base) return;

        if (t_mirror_seen[i] != base) {
            t_mirror_seen[i] = base;
            t_mirror_ready[i] = 0;
            __builtin_memset(t_mirror_hit[i], 0, sizeof(t_mirror_hit[i]));
        }

        for (slot = 0; slot < TNX_MIRROR_SLOT_MAX; slot++) {
            uintptr_t addr = t_mirror_addr(base, slot);
            int32_t now = 0;

            if (!tnx_read_i32(addr, &now)) continue;

            if (!t_mirror_ready[i]) {
                t_mirror_prev[i][slot] = now;
                continue;
            }

            if (t_mirror_prev[i][slot] != now) {
                int32_t prev = t_mirror_prev[i][slot];

                t_mirror_prev[i][slot] = now;

                if (dodging) t_n1_2[i][slot]++;
                else t_n0_2[i][slot]++;

                if (t_mirror_hit[i][slot]) continue;

                t_mirror_hit[i][slot] = 1;

                if (t_mirror_logs_2 < TNX_MIRROR_LOGS_2) {
                    TNX_LOGX("mirror obj=%s base=%p off=+0x%llx prev=%d/%.4f now=%d/%.4f dodging=%d - "
                             "hopCtrl is the receiver the engine own setter uses (hop of the logic "
                             "client), so the offset that moves on hopCtrl while dodging=0 is the "
                             "input record the game touch path writes and the one to drive",
                             t_mirror_name(i), (void *)base,
                             (unsigned long long)(addr - base),
                             prev, (double)t_mirror_f(prev), now, (double)t_mirror_f(now), dodging);

                    t_mirror_logs_2++;
                }
            }
        }

        t_mirror_ready[i] = 1;
    }

    t_ticks_2++;

    if (t_ticks_2 >= 300 && t_dumps_2 < 14) {
        int k;
        int rank;

        t_ticks_2 = 0;
        t_dumps_2++;

        for (rank = 0; rank < 8; rank++) {
            int bi = -1;
            int bslot = -1;
            uint32_t bv = 0;

            for (k = 0; k < TNX_MIRROR_OBJ_MAX; k++) {
                int sl;

                for (sl = 0; sl < TNX_MIRROR_SLOT_MAX; sl++) {
                    uint32_t v = t_n0_2[k][sl] + t_n1_2[k][sl];

                    if (v > bv) {
                        bv = v;
                        bi = k;
                        bslot = sl;
                    }
                }
            }

            if (bi < 0 || bv < 3) break;

            TNX_LOGX("mirror top #%d obj=%s off=+0x%llx moves=%u whileDodging=0 moves=%u whileDodging=1 "
                     "- counts over the whole battle, so an offset with a high count at dodging=0 is a "
                     "channel the game own touch path writes and a high count at dodging=1 means this "
                     "build reaches the same field",
                     rank, t_mirror_name(bi),
                     (unsigned long long)(bslot < 160 ? (0x880 + (unsigned long long)bslot * 4)
                                                      : (0xe00 + (unsigned long long)(bslot - 160) * 4)),
                     t_n0_2[bi][bslot], t_n1_2[bi][bslot]);

            t_n0_2[bi][bslot] = 0;
            t_n1_2[bi][bslot] = 0;
        }
    }
}
