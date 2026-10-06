#include "titanox.h"

uint64_t t_applied_writes = 0;

uint64_t t_applied_live = 0;

uint64_t t_applied_stale = 0;

int32_t t_hp = -1;

int32_t t_hpmax = -1;

uint64_t t_hits = 0;

uint64_t t_hit_engaged = 0;

uint64_t t_hit_idle = 0;

uint64_t t_hp_lost = 0;

uint64_t t_episodes = 0;

uint64_t t_clean = 0;

uint64_t t_eaten = 0;

uint64_t t_engaged_frames = 0;

uint64_t t_threat_frames = 0;

int t_ep_open = 0;

int t_ep_dirty = 0;

int t_logs_12 = 0;

int t_clean_seen = 0;

void tnx_log(const char *event) {
    if (t_logs_12 >= TNX_LOGS_8) return;

    t_logs_12++;

    tnx_logf("dodge %s hp=%d/%d hits=%llu engagedHits=%llu idleHits=%llu lost=%llu episodes=%llu "
             "clean=%llu eaten=%llu threatFrames=%llu engagedFrames=%llu - clean is a threat window "
             "that closed with the health untouched, which is a dodge that worked, eaten is one that "
             "closed after the health dropped, and the hit split says whether this build was driving "
             "at the moment the health dropped, so a high idleHits means the dodge was not even "
             "engaged when the shot landed",
             event, t_hp, t_hpmax, (unsigned long long)t_hits,
             (unsigned long long)t_hit_engaged, (unsigned long long)t_hit_idle,
             (unsigned long long)t_hp_lost, (unsigned long long)t_episodes,
             (unsigned long long)t_clean, (unsigned long long)t_eaten,
             (unsigned long long)t_threat_frames, (unsigned long long)t_engaged_frames);
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

extern float t_rad_est;

extern void tnx_contact_note(float dist, float projR);

static const uintptr_t t_hp_cand[TNX_HP_CAND] = {
    0x9c, 0xa0, 0xa4, 0xa8, 0xac, 0xb0, 0xb4, 0xb8, 0xbc, 0xc0, 0xc4, 0xc8
};

int t_hp_off = -1;

int t_hp_lock_n = 0;

uintptr_t t_hp_seen = 0;

int32_t t_hp_seen_max = 0;

int t_hp_bad = 0;

int t_hp_logs = 0;

int tnx_hp_read(uintptr_t own, int32_t *hp, int32_t *hpmax) {
    int i = 0;
    int32_t v = 0;
    int32_t m = 0;

    *hp = 0;
    *hpmax = 0;

    if (!own) return 0;

    if (t_hp_off >= 0) {
        if (!tnx_read_i32(own + (uintptr_t)t_hp_off, &v)) return 0;
        if (!tnx_read_i32(own + (uintptr_t)t_hp_off + 4, &m)) return 0;

        if (v > 0 && v <= m && m <= TNX_HP_MAX) {
            t_hp_bad = 0;
            *hp = v;
            *hpmax = m;

            return 1;
        }

        t_hp_bad++;

        if (t_hp_bad > TNX_HP_BAD_MAX) {
            if (t_hp_logs < TNX_HP_LOGS) {
                t_hp_logs++;

                TNX_LOGX("hplock off=%#x lost hp=%d max=%d bad=%d - the locked pair stopped reading "
                         "as a sane health pair, so the offset is dropped and searched again, which "
                         "is what keeps a wrong field out of the hit count",
                         t_hp_off, v, m, t_hp_bad);
            }

            t_hp_off = -1;
            t_hp_lock_n = 0;
            t_hp_seen = 0;
            t_hp_bad = 0;
        }

        return 0;
    }

    for (i = 0; i < TNX_HP_CAND; i++) {
        uintptr_t off = t_hp_cand[i];

        if (!tnx_read_i32(own + off, &v)) continue;
        if (!tnx_read_i32(own + off + 4, &m)) continue;
        if (v <= 0 || v > m || m > TNX_HP_MAX) continue;

        if (t_hp_seen == off && t_hp_seen_max == m) {
            t_hp_lock_n++;
        } else {
            t_hp_seen = off;
            t_hp_seen_max = m;
            t_hp_lock_n = 1;
        }

        if (t_hp_lock_n >= TNX_HP_TICKS) {
            t_hp_off = (int)off;

            if (t_hp_logs < TNX_HP_LOGS) {
                t_hp_logs++;

                TNX_LOGX("hplock off=%#x hp=%d max=%d held=%d bound=%d - this pair read as "
                         "0 < hp <= max <= %d for %d frames running, so it is the health pair; the "
                         "old read took whatever sat at the first field and reported 6553600, which "
                         "is why a sanity bound and a stability count are both required before a "
                         "hit is allowed to be counted",
                         t_hp_off, v, m, t_hp_lock_n, (int)TNX_HP_MAX, (int)TNX_HP_MAX,
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
    float bx = (float)t_own_x;
    float by = (float)t_own_y;
    float bd = 1.0e9f;

    for (k = 0; k < TNX_PROJ_MAX; k++) {
        float dx = 0.0f;
        float dy = 0.0f;
        float d = 0.0f;

        if (!t_projs[k].elem) continue;
        if (tnx_proj_mine(&t_projs[k])) continue;

        dx = (float)t_projs[k].x - bx;
        dy = (float)t_projs[k].y - by;
        d = sqrtf(dx * dx + dy * dy);

        if (d < bd) bd = d;
    }

    if (bd > 1.0e8f) return 0;

    tnx_contact_note(bd, t_rad_est);

    return 1;
}

void tnx_stats(void) {
    uintptr_t own = t_own_elem_2;
    int32_t hp = 0;
    int32_t hpmax = 0;
    int threat = 0;

    if (!own) own = (uintptr_t)t_own_elem;
    if (!own) own = tnx_own_obj();
    if (!own) return;

    if (!TNX_HP_AUTO) {
        if (!tnx_read_i32(own + TNX_HP_OFF, &hp)) return;
        if (!tnx_read_i32(own + TNX_HPMAX_OFF, &hpmax)) return;
    } else if (!tnx_hp_read(own, &hp, &hpmax)) {
        return;
    }

    if (hpmax <= 0 || hp <= 0 || hp > hpmax) return;

    if (t_hp < 0) t_hp = hp;
    if (t_hpmax < 0) t_hpmax = hpmax;
    if (hpmax != t_hpmax) t_hpmax = hpmax;

    if (hp < t_hp) {
        t_hits++;
        t_ep_dirty = 1;

        tnx_contact_scan();

        if (t_drove) t_hit_engaged++;
        else t_hit_idle++;

        t_hp_lost += (uint64_t)(t_hp - hp);
        t_hp = hp;
        tnx_log("hit");

        return;
    }

    t_hp = hp;

    threat = t_active_2 ? 1 : 0;

    if (threat) t_threat_frames++;
    if (threat && t_drove) t_engaged_frames++;

    if (threat && !t_ep_open) {
        t_ep_open = 1;
        t_ep_dirty = 0;
        t_episodes++;

        return;
    }

    if (!threat && t_ep_open) {
        t_ep_open = 0;

        if (t_ep_dirty) {
            t_eaten++;
            tnx_log("eaten");

            return;
        }

        t_clean++;
        t_clean_seen++;

        if (t_clean_seen >= TNX_CLEAN_LOGS) {
            t_clean_seen = 0;
            tnx_log("clean");
        }
    }
}
