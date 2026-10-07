#include "titanox.h"

#define TNX_BP_OBJ_MAX 8
#define TNX_BP_SLOT_MAX 320

static uintptr_t t_bp_seen[TNX_BP_OBJ_MAX];
static int32_t t_bp_prev[TNX_BP_OBJ_MAX][TNX_BP_SLOT_MAX];
static uint32_t t_bp_n0[TNX_BP_OBJ_MAX][TNX_BP_SLOT_MAX];
static uint32_t t_bp_n1[TNX_BP_OBJ_MAX][TNX_BP_SLOT_MAX];
static uint8_t t_bp_ready[TNX_BP_OBJ_MAX];
static int t_bp_rr = 0;
static int t_bp_ticks = 0;
static int t_bp_dumps = 0;
static int t_bp_elems = 0;

int t_bp_logs_2 = 0;

static unsigned long long t_bp_off(int slot) {
    if (slot < 160) return 0x880 + (unsigned long long)slot * 4;

    return 0xe00 + (unsigned long long)(slot - 160) * 4;
}

static float t_bp_f(int32_t v) {
    float f;

    __builtin_memcpy(&f, &v, sizeof(f));

    return f;
}

static const char *t_bp_name(int i) {
    static const char *n[TNX_BP_OBJ_MAX] = {
        "bs", "scene", "ctrl", "hopBs", "mgr", "stick", "hopCtrl", "screen"
    };

    return n[i];
}

static void t_bp_elements(uintptr_t mgr) {
    uintptr_t base = mgr;
    int32_t cnt = 0;
    int i;

    if (!base) return;

    tnx_read_i32(base + 0xc, &cnt);

    if (cnt > 6) cnt = 6;

    for (i = 0; i < cnt; i++) {
        uintptr_t el = 0;
        uintptr_t vt = 0;
        int32_t c30 = 0;
        int32_t c34 = 0;
        int32_t w40 = 0;
        int32_t w48 = 0;
        int32_t w4c = 0;
        int32_t w50 = 0;
        int32_t w58 = 0;

        tnx_read_ptr(base + i * 8, (void **)&el);

        if (!el) continue;

        tnx_read_ptr(el, (void **)&vt);
        tnx_read_i32(el + 0x30, &c30);
        tnx_read_i32(el + 0x34, &c34);
        tnx_read_i32(el + 0x40, &w40);
        tnx_read_i32(el + 0x48, &w48);
        tnx_read_i32(el + 0x4c, &w4c);
        tnx_read_i32(el + 0x50, &w50);
        tnx_read_i32(el + 0x58, &w58);

        TNX_LOGX("bp el #%d ptr=%p vt=%#llx pos=%d,%d w40=%d w48=%d w4c=%d w50=%d w58=%d",
                 i, (void *)el,
                 (unsigned long long)(vt ? (uintptr_t)vt - t_base : 0),
                 c30, c34, w40, w48, w4c, w50, w58);

        t_bp_logs_2++;
    }

    {
        uintptr_t bs = tnx_bs();
        uintptr_t vt = 0;

        if (bs) {
            tnx_read_ptr(bs, (void **)&vt);

            TNX_LOGX("bp own bs=%p vt=%#llx", (void *)bs,
                     (unsigned long long)(vt ? (uintptr_t)vt - t_base : 0));
        }
    }
}

void tnx_battle_probe_2(int dodging) {
    uintptr_t list[TNX_BP_OBJ_MAX];
    uintptr_t bs = tnx_bs();
    uintptr_t scene = (uintptr_t)t_scene_object;
    uintptr_t ctrl = tnx_controller();
    uintptr_t mgr = 0;
    uintptr_t stick = 0;
    uintptr_t screen = 0;
    int i;
    int slot;

    if (!TNX_BP_ON_2) return;

    if (bs) tnx_read_ptr(bs + 0x28, (void **)&mgr);
    if (bs) tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&stick);
    if (scene) tnx_read_ptr(scene + TNX_OFF_BATTLE_SCREEN, (void **)&screen);

    list[0] = bs;
    list[1] = scene;
    list[2] = ctrl;
    list[3] = bs ? tnx_hop(bs, NULL) : 0;
    list[4] = mgr;
    list[5] = stick;
    list[6] = ctrl ? tnx_hop(ctrl, NULL) : 0;
    list[7] = screen;

    i = t_bp_rr;
    t_bp_rr = (t_bp_rr + 1) % TNX_BP_OBJ_MAX;

    if (list[i]) {
        uintptr_t base = list[i];

        if (t_bp_seen[i] != base) {
            t_bp_seen[i] = base;
            t_bp_ready[i] = 0;
            __builtin_memset(t_bp_n0[i], 0, sizeof(t_bp_n0[i]));
            __builtin_memset(t_bp_n1[i], 0, sizeof(t_bp_n1[i]));
        }

        for (slot = 0; slot < TNX_BP_SLOT_MAX; slot++) {
            int32_t now = 0;

            if (!tnx_read_i32(base + t_bp_off(slot), &now)) continue;

            if (!t_bp_ready[i]) {
                t_bp_prev[i][slot] = now;
                continue;
            }

            if (t_bp_prev[i][slot] != now) {
                t_bp_prev[i][slot] = now;

                if (dodging) t_bp_n1[i][slot]++;
                else t_bp_n0[i][slot]++;
            }
        }

        t_bp_ready[i] = 1;
    }

    if (t_bp_elems < 12 && mgr && t_bp_ready[4]) {
        t_bp_elems++;
        t_bp_elements(mgr);
    }

    t_bp_ticks++;

    if (t_bp_ticks >= 90 && t_bp_dumps < 60) {
        int rank;

        t_bp_ticks = 0;
        t_bp_dumps++;

        for (rank = 0; rank < 10; rank++) {
            int bi = -1;
            int bslot = -1;
            uint32_t bv = 0;
            int k;

            for (k = 0; k < TNX_BP_OBJ_MAX; k++) {
                int sl;

                for (sl = 0; sl < TNX_BP_SLOT_MAX; sl++) {
                    uint32_t v = t_bp_n0[k][sl] + t_bp_n1[k][sl];

                    if (v > bv) {
                        bv = v;
                        bi = k;
                        bslot = sl;
                    }
                }
            }

            if (bi < 0 || bv < 3) break;

            {
                int32_t cur = 0;

                if (!tnx_read_i32(t_bp_seen[bi] + t_bp_off(bslot), &cur)) cur = 0;

                TNX_LOGX("bp top #%d obj=%s off=+0x%llx val=%d/%.4f d0=%u d1=%u",
                         rank, t_bp_name(bi), t_bp_off(bslot), cur, (double)t_bp_f(cur),
                         t_bp_n0[bi][bslot], t_bp_n1[bi][bslot]);
            }

            t_bp_n0[bi][bslot] = 0;
            t_bp_n1[bi][bslot] = 0;
        }

        if (stick) {
            float cx = 0.0f;
            float cy = 0.0f;
            float ox = 0.0f;
            float oy = 0.0f;
            float ix = 0.0f;
            float iy = 0.0f;
            uint8_t h78 = 0;
            uint8_t h80 = 0;
            uint8_t h9c = 0;
            uint8_t h9e = 0;
            uint8_t h8ac = 0;
            uint8_t hee8 = 0;
            uint8_t hf48 = 0;
            int32_t appx = 0;
            int32_t appy = 0;
            int32_t rawx = 0;
            int32_t rawy = 0;

            tnx_read_f32(stick + 0xa40, &cx);
            tnx_read_f32(stick + 0xa44, &cy);
            tnx_read_f32(stick + 0xa48, &ox);
            tnx_read_f32(stick + 0xa4c, &oy);
            tnx_read_f32(stick + 0x9d0, &ix);
            tnx_read_f32(stick + 0x9d4, &iy);
            tnx_read_u8(stick + 0xf78, &h78);
            tnx_read_u8(stick + 0xf80, &h80);
            tnx_read_u8(stick + 0xf9c, &h9c);
            tnx_read_u8(stick + 0xf9e, &h9e);
            tnx_read_u8(stick + 0x8ac, &h8ac);
            tnx_read_u8(stick + 0xee8, &hee8);
            tnx_read_u8(stick + 0xf48, &hf48);
            tnx_read_i32(stick + 0xfcc, &appx);
            tnx_read_i32(stick + 0xfd0, &appy);
            tnx_read_i32(stick + 0xfa4, &rawx);
            tnx_read_i32(stick + 0xfa8, &rawy);

            TNX_LOGX("bp stick ptr=%p cur=%.1f,%.1f org=%.1f,%.1f held=%d,%d,%d,%d in=%.2f,%.2f "
                     "drag=%d,%d,%d applied=%d,%d raw=%d,%d dodging=%d",
                     (void *)stick,
                     (double)cx, (double)cy, (double)ox, (double)oy,
                     (int)h78, (int)h80, (int)h9c, (int)h9e,
                     (double)ix, (double)iy,
                     (int)h8ac, (int)hee8, (int)hf48,
                     appx, appy, rawx, rawy, dodging);
        }
    }
}
