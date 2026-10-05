#include "titanox.h"
#include "data/chars_data.h"

uint64_t g_applied_writes = 0;

uint64_t g_applied_live = 0;

uint64_t g_applied_stale = 0;

int32_t g_hp = -1;

int32_t g_hpmax = -1;

uint64_t g_hits = 0;

uint64_t g_hit_engaged = 0;

uint64_t g_hit_idle = 0;

uint64_t g_hp_lost = 0;

uint64_t g_episodes = 0;

uint64_t g_clean = 0;

uint64_t g_eaten = 0;

uint64_t g_engaged_frames = 0;

uint64_t g_threat_frames = 0;

int g_ep_open = 0;

int g_ep_dirty = 0;

int g_logs_12 = 0;

int g_clean_seen = 0;

void tnx_log(const char *event) {
    if (g_logs_12 >= TNX_LOGS_8) return;

    g_logs_12++;

    tnx_logf("dodge %s hp=%d/%d hits=%llu engagedHits=%llu idleHits=%llu lost=%llu episodes=%llu "
             "clean=%llu eaten=%llu threatFrames=%llu engagedFrames=%llu - clean is a threat window "
             "that closed with the health untouched, which is a dodge that worked, eaten is one that "
             "closed after the health dropped, and the hit split says whether this build was driving "
             "at the moment the health dropped, so a high idleHits means the dodge was not even "
             "engaged when the shot landed",
             event, g_hp, g_hpmax, (unsigned long long)g_hits,
             (unsigned long long)g_hit_engaged, (unsigned long long)g_hit_idle,
             (unsigned long long)g_hp_lost, (unsigned long long)g_episodes,
             (unsigned long long)g_clean, (unsigned long long)g_eaten,
             (unsigned long long)g_threat_frames, (unsigned long long)g_engaged_frames);
}

#ifndef TNX_HP_AUTO
#define TNX_HP_AUTO 1
#endif

#ifndef TNX_HP_MAX
#define TNX_HP_MAX 200000
#endif

#ifndef TNX_HP_BAD_MAX
#define TNX_HP_BAD_MAX 5
#endif

#ifndef TNX_HP_TICKS
#define TNX_HP_TICKS 30
#endif

#ifndef TNX_HP_LOGS
#define TNX_HP_LOGS 8
#endif

#ifndef TNX_HP_CAND
#define TNX_HP_CAND 12
#endif

extern float g_rad_est;

extern void tnx_contact_note(float dist, float projR);

static const uintptr_t g_hp_cand[TNX_HP_CAND] = {
    0x9c, 0xa0, 0xa4, 0xa8, 0xac, 0xb0, 0xb4, 0xb8, 0xbc, 0xc0, 0xc4, 0xc8
};

int g_hp_off = -1;

int g_hp_lock_n = 0;

uintptr_t g_hp_seen = 0;

int32_t g_hp_seen_max = 0;

int g_hp_bad = 0;

int g_hp_logs = 0;

int tnx_hp_read(uintptr_t own, int32_t *hp, int32_t *hpmax) {
    int i = 0;
    int32_t v = 0;
    int32_t m = 0;

    *hp = 0;
    *hpmax = 0;

    if (!own) return 0;

    if (g_hp_off >= 0) {
        if (!tnx_read_i32(own + (uintptr_t)g_hp_off, &v)) return 0;
        if (!tnx_read_i32(own + (uintptr_t)g_hp_off + 4, &m)) return 0;

        if (v > 0 && v <= m && m <= TNX_HP_MAX) {
            g_hp_bad = 0;
            *hp = v;
            *hpmax = m;

            return 1;
        }

        g_hp_bad++;

        if (g_hp_bad > TNX_HP_BAD_MAX) {
            if (g_hp_logs < TNX_HP_LOGS) {
                g_hp_logs++;

                TNX_LOGX("hplock off=%#x lost hp=%d max=%d bad=%d - the locked pair stopped reading "
                         "as a sane health pair, so the offset is dropped and searched again, which "
                         "is what keeps a wrong field out of the hit count",
                         g_hp_off, v, m, g_hp_bad);
            }

            g_hp_off = -1;
            g_hp_lock_n = 0;
            g_hp_seen = 0;
            g_hp_bad = 0;
        }

        return 0;
    }

    for (i = 0; i < TNX_HP_CAND; i++) {
        uintptr_t off = g_hp_cand[i];

        if (!tnx_read_i32(own + off, &v)) continue;
        if (!tnx_read_i32(own + off + 4, &m)) continue;
        if (v <= 0 || v > m || m > TNX_HP_MAX) continue;

        if (g_hp_seen == off && g_hp_seen_max == m) {
            g_hp_lock_n++;
        } else {
            g_hp_seen = off;
            g_hp_seen_max = m;
            g_hp_lock_n = 1;
        }

        if (g_hp_lock_n >= TNX_HP_TICKS) {
            g_hp_off = (int)off;

            if (g_hp_logs < TNX_HP_LOGS) {
                g_hp_logs++;

                TNX_LOGX("hplock off=%#x hp=%d max=%d held=%d bound=%d - this pair read as "
                         "0 < hp <= max <= %d for %d frames running, so it is the health pair; the "
                         "old read took whatever sat at the first field and reported 6553600, which "
                         "is why a sanity bound and a stability count are both required before a "
                         "hit is allowed to be counted",
                         g_hp_off, v, m, g_hp_lock_n, (int)TNX_HP_MAX, (int)TNX_HP_MAX,
                         (int)TNX_HP_TICKS);
            }

            *hp = v;
            *hpmax = m;

            return 1;
        }

        return 0;
    }

    return 0;
}

int tnx_contact_scan(void) {
    int k = 0;
    float bx = (float)g_own_x;
    float by = (float)g_own_y;
    float bd = 1.0e9f;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        float dx = 0.0f;
        float dy = 0.0f;
        float d = 0.0f;

        if (!g_projs[k].elem) continue;
        if (tnx_proj_mine(&g_projs[k])) continue;

        dx = (float)g_projs[k].x - bx;
        dy = (float)g_projs[k].y - by;
        d = sqrtf(dx * dx + dy * dy);

        if (d < bd) bd = d;
    }

    if (bd > 1.0e8f) return 0;

    tnx_contact_note(bd, g_rad_est);

    return 1;
}

void tnx_stats(void) {
    uintptr_t own = g_own_elem_2;
    int32_t hp = 0;
    int32_t hpmax = 0;
    int threat = 0;

    if (!own) own = (uintptr_t)g_own_elem;
    if (!own) own = tnx_own_obj();
    if (!own) return;

    if (!TNX_HP_AUTO) {
        if (!tnx_read_i32(own + TNX_HP_OFF, &hp)) return;
        if (!tnx_read_i32(own + TNX_HPMAX_OFF, &hpmax)) return;
    } else if (!tnx_hp_read(own, &hp, &hpmax)) {
        return;
    }

    if (hpmax <= 0 || hp <= 0 || hp > hpmax) return;

    tnx_hero_identify(hpmax, 0);

    if (g_hp < 0) g_hp = hp;
    if (g_hpmax < 0) g_hpmax = hpmax;
    if (hpmax != g_hpmax) g_hpmax = hpmax;

    if (hp < g_hp) {
        g_hits++;
        g_ep_dirty = 1;

        tnx_contact_scan();

        if (g_drove) g_hit_engaged++;
        else g_hit_idle++;

        g_hp_lost += (uint64_t)(g_hp - hp);
        g_hp = hp;
        tnx_log("hit");

        return;
    }

    g_hp = hp;

    threat = g_active_2 ? 1 : 0;

    if (threat) g_threat_frames++;
    if (threat && g_drove) g_engaged_frames++;

    if (threat && !g_ep_open) {
        g_ep_open = 1;
        g_ep_dirty = 0;
        g_episodes++;

        return;
    }

    if (!threat && g_ep_open) {
        g_ep_open = 0;

        if (g_ep_dirty) {
            g_eaten++;
            tnx_log("eaten");

            return;
        }

        g_clean++;
        g_clean_seen++;

        if (g_clean_seen >= TNX_CLEAN_LOGS) {
            g_clean_seen = 0;
            tnx_log("clean");
        }
    }
}
