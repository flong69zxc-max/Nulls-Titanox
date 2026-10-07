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

static unsigned long long t_mirror_off_2(int slot) {
    if (slot < 160) return 0x880 + (unsigned long long)slot * 4;

    return 0xe00 + (unsigned long long)(slot - 160) * 4;
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

    if (t_ticks_2 >= 60 && t_dumps_2 < 500) {
        int k;
        int rank;

        t_ticks_2 = 0;
        t_dumps_2++;

        {
            uintptr_t bsm = 0;
            float v[16];
            float w[20];
            uint8_t dr[3];
            int q;

            for (q = 0; q < 16; q++) v[q] = 0.0f;
            for (q = 0; q < 20; q++) w[q] = 0.0f;
            for (q = 0; q < 3; q++) dr[q] = 0;

            if (bs) tnx_read_ptr(bs + TNX_JOY_TARGET_OFF, (void **)&bsm);

            if (bsm) {
                tnx_read_f32(bsm + 0x9b8, &v[0]);
                tnx_read_f32(bsm + 0x9bc, &v[1]);
                tnx_read_f32(bsm + 0x9c0, &v[2]);
                tnx_read_f32(bsm + 0x9c4, &v[3]);
                tnx_read_f32(bsm + 0x9d0, &v[4]);
                tnx_read_f32(bsm + 0x9d4, &v[5]);
                tnx_read_f32(bsm + 0x9d8, &v[6]);
                tnx_read_f32(bsm + 0x9dc, &v[7]);
                tnx_read_f32(bsm + 0xa20, &v[8]);
                tnx_read_f32(bsm + 0xa24, &v[9]);
                tnx_read_f32(bsm + 0xa40, &v[10]);
                tnx_read_f32(bsm + 0xa44, &v[11]);
                tnx_read_f32(bsm + 0xa48, &v[12]);
                tnx_read_f32(bsm + 0xa4c, &v[13]);
                tnx_read_f32(bsm + 0xa28, &v[14]);
                tnx_read_f32(bsm + 0xa2c, &v[15]);

                tnx_read_u8(bsm + 0x8ac, &dr[0]);
                tnx_read_u8(bsm + 0xee8, &dr[1]);
                tnx_read_u8(bsm + 0xf48, &dr[2]);

                tnx_read_f32(bsm + 0x9a0, &w[0]);
                tnx_read_f32(bsm + 0x9a4, &w[1]);
                tnx_read_f32(bsm + 0x9a8, &w[2]);
                tnx_read_f32(bsm + 0x9ac, &w[3]);
                tnx_read_f32(bsm + 0x9b0, &w[4]);
                tnx_read_f32(bsm + 0x9b4, &w[5]);
                tnx_read_f32(bsm + 0xa30, &w[6]);
                tnx_read_f32(bsm + 0xa34, &w[7]);
                tnx_read_f32(bsm + 0xa38, &w[8]);
                tnx_read_f32(bsm + 0xa3c, &w[9]);
                tnx_read_f32(bsm + 0xa50, &w[10]);
                tnx_read_f32(bsm + 0xa54, &w[11]);
                tnx_read_f32(bsm + 0xa58, &w[12]);
                tnx_read_f32(bsm + 0xa5c, &w[13]);
                tnx_read_f32(bsm + 0x880, &w[14]);
                tnx_read_f32(bsm + 0x884, &w[15]);
                tnx_read_f32(bsm + 0x888, &w[16]);
                tnx_read_f32(bsm + 0x88c, &w[17]);
                tnx_read_f32(bsm + 0x800, &w[18]);
                tnx_read_f32(bsm + 0x804, &w[19]);
            }

            TNX_LOGX("mirror pairs bsm=%p p1=%.2f,%.2f cen1=%.2f,%.2f p2=%.2f,%.2f cen2=%.2f,%.2f "
                     "p3=%.2f,%.2f cur3=%.2f,%.2f org3=%.2f,%.2f cen3=%.2f,%.2f drag=%d,%d,%d "
                     "dodging=%d - three stick records on the game own input object, each as "
                     "current,centre pairs plus its own drag byte, so the record that tracks the "
                     "hand while the player walks is the move stick and the one that tracks the hand "
                     "while the player aims is the aim stick",
                     (void *)bsm,
                     (double)v[0], (double)v[1], (double)v[2], (double)v[3],
                     (double)v[4], (double)v[5], (double)v[6], (double)v[7],
                     (double)v[8], (double)v[9], (double)v[10], (double)v[11],
                     (double)v[12], (double)v[13], (double)v[14], (double)v[15],
                     (int)dr[0], (int)dr[1], (int)dr[2], dodging);

            TNX_LOGX("mirror rec bsm=%p a0=%.1f,%.1f,%.1f,%.1f a8=%.1f,%.1f,%.1f,%.1f b0=%.1f,%.1f "
                     "c0=%.1f,%.1f,%.1f,%.1f d0=%.1f,%.1f,%.1f,%.1f e0=%.1f,%.1f,%.1f,%.1f d=%d - the "
                     "rest of the stick record, read as floats: a normalised direction sits inside "
                     "-1..1 and tracks the hand every frame, a screen coordinate sits in the hundreds, "
                     "and a weight sits still until the hand moves",
                     (void *)bsm,
                     (double)w[0], (double)w[1], (double)w[2], (double)w[3],
                     (double)w[4], (double)w[5], (double)w[6], (double)w[7],
                     (double)w[8], (double)w[9], (double)w[10], (double)w[11],
                     (double)w[12], (double)w[13], (double)w[14], (double)w[15],
                     (double)w[16], (double)w[17], (double)w[18], (double)w[19], dodging);

            if (bsm) {
                float pcx = 0.0f;
                float pcy = 0.0f;
                float pox = 0.0f;
                float poy = 0.0f;
                uint8_t f[18];
                int fi;

                for (fi = 0; fi < 18; fi++) f[fi] = 0;

                tnx_read_f32(bsm + 0xa40, &pcx);
                tnx_read_f32(bsm + 0xa44, &pcy);
                tnx_read_f32(bsm + 0xa48, &pox);
                tnx_read_f32(bsm + 0xa4c, &poy);

                tnx_read_u8(bsm + 0x8ac, &f[0]);
                tnx_read_u8(bsm + 0x8ad, &f[1]);
                tnx_read_u8(bsm + 0xee8, &f[2]);
                tnx_read_u8(bsm + 0xee9, &f[3]);
                tnx_read_u8(bsm + 0xf48, &f[4]);
                tnx_read_u8(bsm + 0xf49, &f[5]);
                tnx_read_u8(bsm + 0xf78, &f[6]);
                tnx_read_u8(bsm + 0xf80, &f[7]);
                tnx_read_u8(bsm + 0xf9c, &f[8]);
                tnx_read_u8(bsm + 0xf9e, &f[9]);
                tnx_read_u8(bsm + 0xfa0, &f[10]);
                tnx_read_u8(bsm + 0xfb0, &f[11]);
                tnx_read_u8(bsm + 0xfb1, &f[12]);
                tnx_read_u8(bsm + 0xfac, &f[13]);
                tnx_read_u8(bsm + 0xfad, &f[14]);
                tnx_read_u8(bsm + 0x1050, &f[15]);
                tnx_read_u8(bsm + 0x1051, &f[16]);
                tnx_read_u8(bsm + 0xfec, &f[17]);

                TNX_LOGX("mirror flags bsm=%p playerDrag=%d dodging=%d cur=(%.1f,%.1f) org=(%.1f,%.1f) "
                         "b[18]=%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d - the byte that "
                         "reads 1 only on the frames the player is the one holding the stick is the "
                         "flag the engine gates the whole stick read on, so it is the one the write "
                         "has to raise together with cur",
                         (void *)bsm,
                         (dodging == 0 && (pcx != pox || pcy != poy)) ? 1 : 0, dodging,
                         (double)pcx, (double)pcy, (double)pox, (double)poy,
                         (int)f[0], (int)f[1], (int)f[2], (int)f[3], (int)f[4], (int)f[5],
                         (int)f[6], (int)f[7], (int)f[8], (int)f[9], (int)f[10], (int)f[11],
                         (int)f[12], (int)f[13], (int)f[14], (int)f[15], (int)f[16], (int)f[17]);
            }
        }

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

            {
                int32_t cur = 0;

                if (!tnx_read_i32(t_mirror_seen[bi] + t_mirror_off_2(bslot), &cur)) cur = 0;

                TNX_LOGX("mirror top #%d obj=%s off=+0x%llx val=%d/%.4f moves=%u whileDodging=0 "
                         "moves=%u whileDodging=1 - the value says what the field is: a small float "
                         "inside -1..1 is a normalised stick, a large float is a screen or world "
                         "coordinate, and a small integer is a flag or an index",
                         rank, t_mirror_name(bi), (unsigned long long)t_mirror_off_2(bslot),
                         cur, (double)t_mirror_f(cur), t_n0_2[bi][bslot], t_n1_2[bi][bslot]);
            }

            t_n0_2[bi][bslot] = 0;
            t_n1_2[bi][bslot] = 0;
        }
    }
}
