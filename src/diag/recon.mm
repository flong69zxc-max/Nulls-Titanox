#include "titanox.h"

int t_recon_runs = 0;

uintptr_t t_recon_seen_3[96];
int t_recon_seen_n = 0;

int tnx_recon_seen_3(uintptr_t rva) {
    int i = 0;

    for (i = 0; i < t_recon_seen_n; i++) {
        if (t_recon_seen_3[i] == rva) return 1;
    }

    if (t_recon_seen_n < 96) t_recon_seen_3[t_recon_seen_n++] = rva;

    return 0;
}

void tnx_recon_vtable_3(const char *tag, uintptr_t vtRva, int slots) {
    uintptr_t vt = 0;
    int i = 0;

    if (!t_base || !vtRva) return;

    vt = t_base + vtRva;

    tnx_logf("recon vt %s rva=%#llx slots=%d", tag, (unsigned long long)vtRva, slots);

    for (i = 0; i < slots; i++) {
        void *e = NULL;
        int32_t i0 = 0;
        int32_t i1 = 0;
        int32_t i2 = 0;
        int32_t i3 = 0;

        if (!tnx_read_ptr(vt + (uintptr_t)(i * 8), &e)) break;
        if (!e) continue;

        tnx_read_i32((uintptr_t)e, &i0);
        tnx_read_i32((uintptr_t)e + 4, &i1);
        tnx_read_i32((uintptr_t)e + 8, &i2);
        tnx_read_i32((uintptr_t)e + 12, &i3);

        tnx_logf("recon vtslot %s +%#04x rva=%#llx i0=%#010x i1=%#010x i2=%#010x i3=%#010x",
                 tag, i * 8, (unsigned long long)((uintptr_t)e - t_base),
                 (unsigned int)i0, (unsigned int)i1, (unsigned int)i2, (unsigned int)i3);
    }
}

void tnx_recon_words_3(const char *tag, uintptr_t obj, int from, int to) {
    int off = 0;

    if (!obj || from >= to) return;

    tnx_logf("recon words %s obj=%#llx from=%#x to=%#x", tag, (unsigned long long)obj, from, to);

    for (off = from; off < to; off += 4) {
        int32_t v = 0;
        float f = 0.0f;

        if (!tnx_read_i32(obj + (uintptr_t)off, &v)) break;

        tnx_read_f32(obj + (uintptr_t)off, &f);

        tnx_logf("recon word %s +%#04x i=%d u=%#010x f=%g", tag, off, v, (unsigned int)v, (double)f);
    }
}

void tnx_recon_calls_3(const char *tag, uintptr_t fnRva, int bytes) {
    uintptr_t fn = 0;
    int off = 0;

    if (!t_base || !fnRva) return;

    fn = t_base + fnRva;

    tnx_logf("recon calls %s rva=%#llx bytes=%d", tag, (unsigned long long)fnRva, bytes);

    for (off = 0; (off + 4) <= bytes; off += 4) {
        int32_t w = 0;
        unsigned int op = 0;
        int32_t imm = 0;

        if (!tnx_read_i32(fn + (uintptr_t)off, &w)) break;

        op = (unsigned int)w;

        if ((op & 0xfc000000u) == 0x94000000u) {
            imm = (int32_t)(op & 0x03ffffffu);
            if (imm & 0x02000000) imm |= (int32_t)0xfc000000;

            tnx_logf("recon call %s at=+%#x kind=bl rva=%#llx", tag, off,
                     (unsigned long long)(fnRva + (uintptr_t)(imm * 4)));
        } else if ((op & 0xfc000000u) == 0x14000000u) {
            imm = (int32_t)(op & 0x03ffffffu);
            if (imm & 0x02000000) imm |= (int32_t)0xfc000000;

            tnx_logf("recon call %s at=+%#x kind=b rva=%#llx", tag, off,
                     (unsigned long long)(fnRva + (uintptr_t)(imm * 4)));
        }
    }
}

void tnx_recon_seeds_3(void) {
    static const uintptr_t seeds[16] = {
        0x807668, 0x8072c8, 0x8c6150, 0x8c7ef0, 0x8c8050, 0x8cc57c, 0x8cc6dc,
        0x8ce3b0, 0x8cf4c4, 0x8c53fc, 0x8c7fbc, 0x8cc514, 0x8ce3f8, 0x8ce27c,
        0x8c5130, 0x9a9dac
    };
    uintptr_t level[64];
    int levelN = 0;
    int i = 0;
    int k = 0;

    for (i = 0; i < 8; i++) {
        level[levelN++] = seeds[i];
        tnx_recon_calls_3("seed", seeds[i], 0x200);
    }

    for (k = 0; k < levelN && k < 64; k++) {
        uintptr_t fn = t_base + level[k];
        int off = 0;

        for (off = 0; (off + 4) <= 0x1c0; off += 4) {
            int32_t w = 0;
            unsigned int op = 0;
            int32_t imm = 0;
            uintptr_t tgt = 0;

            if (!tnx_read_i32(fn + (uintptr_t)off, &w)) break;

            op = (unsigned int)w;
            if ((op & 0xfc000000u) != 0x94000000u) continue;

            imm = (int32_t)(op & 0x03ffffffu);
            if (imm & 0x02000000) imm |= (int32_t)0xfc000000;

            tgt = level[k] + (uintptr_t)(imm * 4);

            if (tgt == 0 || tgt > 0x2000000) continue;
            if (tnx_recon_seen_3(tgt)) continue;
            if (levelN >= 24) break;

            level[levelN++] = tgt;
        }
    }

    for (i = 8; i < levelN; i++) {
        tnx_recon_calls_3("lvl2", level[i], 0x140);
    }
}

void tnx_recon_live_3(void) {
    tnx_obj_t objects[TNX_OBJECT_MAX];
    int rejected = 0;
    int usable = 0;
    int dumpedVt = 0;
    int dumpedWords = 0;
    int i = 0;

    tnx_logf("recon manager=%#llx array=%#llx count=%d ownElem=%#llx scene=%#llx",
             (unsigned long long)t_manager, 0ULL, t_manager_count,
             (unsigned long long)t_own_elem, (unsigned long long)t_scene_object);

    tnx_recon_words_3("manager", t_manager, 0x0, 0x30);
    tnx_recon_words_3("scene", t_scene_object, 0x0, 0x90);
    tnx_recon_words_3("ctrl", tnx_controller(), 0x0, 0x90);
    tnx_recon_words_3("joy", tnx_controller(), 0x960, 0xa20);
    tnx_recon_words_3("joy2", tnx_controller(), 0xed0, 0xf30);

    if (t_own_elem) {
        void *data = NULL;

        tnx_recon_words_3("ownElem", t_own_elem, 0x0, 0x60);

        if (tnx_read_ptr(t_own_elem + (uintptr_t)TNX_ELEM_DEF_OFF, &data) && data) {
            tnx_recon_words_3("ownData", (uintptr_t)data, 0x0, 0x240);
        }
    }

    if (t_own_elem) {
        int32_t rawTeam = 0;

        tnx_read_i32(t_own_elem + (uintptr_t)TNX_OBJ_TEAM_OFF, &rawTeam);

        tnx_logf("recon ownteam elem=%#llx raw=%d t3=%d t4=%d ownX=%d ownY=%d ownObj=%#llx",
                 (unsigned long long)t_own_elem, rawTeam, t_own_team_3, t_own_team_4,
                 t_own_x, t_own_y, (unsigned long long)t_own_obj);
    }

    for (i = 0; i < TNX_PROJ_MAX && i < 6; i++) {
        int32_t f40 = 0;
        int32_t f8 = 0;

        if (!t_projs[i].elem) continue;

        tnx_read_i32(t_projs[i].elem + (uintptr_t)TNX_OBJ_TEAM_OFF, &f40);
        tnx_read_i32(t_projs[i].elem + 8, &f8);

        tnx_logf("recon projteam i=%d elem=%#llx t40=%d gid8=%d pteam=%d", i,
                 (unsigned long long)t_projs[i].elem, f40, f8, t_projs[i].team);

        tnx_recon_words_3("projHead", t_projs[i].elem, 0x0, 0x60);
    }

    memset(objects, 0, sizeof(objects));

    usable = tnx_collect(t_manager, objects, TNX_OBJECT_MAX, &rejected);

    tnx_logf("recon collect usable=%d rejected=%d", usable, rejected);

    for (i = 0; i < usable && i < TNX_OBJECT_MAX; i++) {
        void *vt = NULL;
        uintptr_t vtRva = 0;

        if (!objects[i].object) continue;

        if (tnx_read_ptr(objects[i].object, &vt) && vt) vtRva = (uintptr_t)vt - t_base;

        tnx_logf("recon live i=%d gid=%d pos=(%d,%d) teamOld=%d teamNew=%d type=%#x dead=%d active=%d vtRva=%#llx",
                 i, objects[i].gid, objects[i].x, objects[i].y, objects[i].teamOld,
                 objects[i].teamNew, (unsigned int)objects[i].typeWord,
                 objects[i].dead, objects[i].activeFlag, (unsigned long long)vtRva);

        if (vtRva && !tnx_recon_seen_3(vtRva) && dumpedVt < 6) {
            dumpedVt++;
            tnx_recon_vtable_3("live", vtRva, 24);
        }

        if (dumpedWords < 2) {
            dumpedWords++;
            tnx_recon_words_3("live", objects[i].object, 0x0, 0x120);
        }
    }

    for (i = 0; i < TNX_PROJ_MAX && i < 2; i++) {
        void *data = NULL;

        if (!t_projs[i].elem) continue;

        tnx_logf("recon proj i=%d gid=%d pos=(%d,%d) prev=(%d,%d) team=%d hasPrev=%d ptick=%llu",
                 i, t_projs[i].gid, t_projs[i].x, t_projs[i].y, t_projs[i].px, t_projs[i].py,
                 t_projs[i].team, t_projs[i].hasPrev, (unsigned long long)t_projs[i].ptick);

        tnx_recon_words_3("proj", t_projs[i].elem, 0x0, 0x120);

        if (tnx_read_ptr(t_projs[i].elem + (uintptr_t)TNX_ELEM_DEF_OFF, &data) && data) {
            tnx_recon_words_3("projData", (uintptr_t)data, 0x0, 0x240);
        }
    }
}

void tnx_recon_3(void) {
    if (t_recon_runs >= 2) return;
    if (t_ticks_3 < 90) return;
    if (t_recon_runs == 1 && t_ticks_3 < 600) return;

    t_recon_runs++;

    tnx_logf("recon begin run=%d tick=%llu base=%#llx slide=%#llx", t_recon_runs,
             (unsigned long long)t_ticks_3, (unsigned long long)t_base, 0ULL);

    tnx_recon_vtable_3("mode", 0xfe9d00, 24);
    tnx_recon_vtable_3("player", 0xf9e248, 24);
    tnx_recon_vtable_3("player2", 0xff54a0, 24);
    tnx_recon_vtable_3("proj", 0xff57b0, 24);

    tnx_recon_live_3();
    tnx_recon_seeds_3();

    tnx_logf("recon end run=%d tick=%llu", t_recon_runs, (unsigned long long)t_ticks_3);
}
