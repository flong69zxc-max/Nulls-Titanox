#include "titanox.h"

#define TNX_LAYOUT_OBJ_MAX 5
#define TNX_LAYOUT_SLOT_MAX 320

static uintptr_t t_layout_seen[TNX_LAYOUT_OBJ_MAX] = {0};
static uint8_t t_layout_ready[TNX_LAYOUT_OBJ_MAX] = {0};
static float t_layout_prev[TNX_LAYOUT_OBJ_MAX][TNX_LAYOUT_SLOT_MAX];
static uint64_t t_layout_logs = 0;

static uintptr_t t_layout_slot_addr(uintptr_t base, int slot) {
    if (slot < 160) return base + 0x880 + (uintptr_t)slot * 4;

    return base + 0xe00 + (uintptr_t)(slot - 160) * 4;
}

static const char *t_layout_band(int slot) {
    if (slot < 160) return "joystick";

    return "inputtail";
}

void tnx_layout_probe_2(int dodging) {
    uintptr_t list[TNX_LAYOUT_OBJ_MAX];
    uintptr_t bs = tnx_bs();
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t hop = bs ? tnx_hop(bs, NULL) : 0;
    uintptr_t hop2 = 0;
    uintptr_t tail = 0;
    int i;
    int slot;

    if (!TNX_LAYOUT_ON_2) return;

    if (bs) tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&hop2);
    if (scene) tnx_read_ptr(scene + TNX_OFF_BATTLE_SCREEN, (void **)&tail);

    list[0] = bs;
    list[1] = scene;
    list[2] = hop;
    list[3] = hop2;
    list[4] = tail;

    for (i = 0; i < TNX_LAYOUT_OBJ_MAX; i++) {
        uintptr_t base = list[i];
        int moved = 0;

        if (!base) continue;

        if (t_layout_seen[i] != base) {
            t_layout_seen[i] = base;
            t_layout_ready[i] = 0;
        }

        for (slot = 0; slot < TNX_LAYOUT_SLOT_MAX; slot++) {
            uintptr_t addr = t_layout_slot_addr(base, slot);
            float now = 0.0f;

            if (!tnx_read_f32(addr, &now)) continue;

            if (!t_layout_ready[i]) {
                t_layout_prev[i][slot] = now;
                continue;
            }

            if (t_layout_prev[i][slot] != now) {
                if (t_layout_logs < TNX_LAYOUT_LOGS_2 && moved < 6) {
                    TNX_LOGX("layout obj=%d base=%p off=+0x%llx band=%s prev=%.4f now=%.4f "
                             "dodging=%d - a float that moved: at dodging=0 the only writer is the "
                             "game own touch path and at dodging=1 it is this build, so an offset "
                             "that moves in both is the channel the walk cycle reads",
                             i, (void *)base, (unsigned long long)(addr - base),
                             t_layout_band(slot), (double)t_layout_prev[i][slot], (double)now, dodging);
                    t_layout_logs++;
                    moved++;
                }

                t_layout_prev[i][slot] = now;
            }
        }

        t_layout_ready[i] = 1;
    }
}
