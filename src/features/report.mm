#include "titanox.h"

uint64_t g_v211_applied_writes = 0;

uint64_t g_v211_applied_live = 0;

uint64_t g_v211_applied_stale = 0;

int32_t g_v246_hp = -1;

int32_t g_v246_hpmax = -1;

uint64_t g_v246_hits = 0;

uint64_t g_v246_hit_engaged = 0;

uint64_t g_v246_hit_idle = 0;

uint64_t g_v246_hp_lost = 0;

uint64_t g_v246_episodes = 0;

uint64_t g_v246_clean = 0;

uint64_t g_v246_eaten = 0;

uint64_t g_v246_engaged_frames = 0;

uint64_t g_v246_threat_frames = 0;

int g_v246_ep_open = 0;

int g_v246_ep_dirty = 0;

int g_v246_logs = 0;

int g_v246_clean_seen = 0;

void tnx_v246_log(const char *event) {
    if (g_v246_logs >= TNX_V246_LOGS) return;

    g_v246_logs++;

    tnx_logf("v246 dodge %s hp=%d/%d hits=%llu engagedHits=%llu idleHits=%llu lost=%llu episodes=%llu "
             "clean=%llu eaten=%llu threatFrames=%llu engagedFrames=%llu - clean is a threat window "
             "that closed with the health untouched, which is a dodge that worked, eaten is one that "
             "closed after the health dropped, and the hit split says whether this build was driving "
             "at the moment the health dropped, so a high idleHits means the dodge was not even "
             "engaged when the shot landed",
             event, g_v246_hp, g_v246_hpmax, (unsigned long long)g_v246_hits,
             (unsigned long long)g_v246_hit_engaged, (unsigned long long)g_v246_hit_idle,
             (unsigned long long)g_v246_hp_lost, (unsigned long long)g_v246_episodes,
             (unsigned long long)g_v246_clean, (unsigned long long)g_v246_eaten,
             (unsigned long long)g_v246_threat_frames, (unsigned long long)g_v246_engaged_frames);
}

void tnx_v246_stats(void) {
    uintptr_t own = g_v182_own_elem;
    int32_t hp = 0;
    int32_t hpmax = 0;
    int threat = 0;

    if (!own) own = (uintptr_t)g_v144_own_elem;
    if (!own) return;
    if (!tnx_read_i32(own + TNX_V246_HP_OFF, &hp)) return;
    if (!tnx_read_i32(own + TNX_V246_HPMAX_OFF, &hpmax)) return;
    if (hpmax <= 0) return;

    if (g_v246_hp < 0) g_v246_hp = hp;
    if (g_v246_hpmax < 0) g_v246_hpmax = hpmax;
    if (hpmax != g_v246_hpmax) g_v246_hpmax = hpmax;

    if (hp < g_v246_hp) {
        g_v246_hits++;
        g_v246_ep_dirty = 1;

        if (g_v243_drove) g_v246_hit_engaged++;
        else g_v246_hit_idle++;

        g_v246_hp_lost += (uint64_t)(g_v246_hp - hp);
        g_v246_hp = hp;
        tnx_v246_log("hit");

        return;
    }

    g_v246_hp = hp;

    threat = g_v160_active ? 1 : 0;

    if (threat) g_v246_threat_frames++;
    if (threat && g_v243_drove) g_v246_engaged_frames++;

    if (threat && !g_v246_ep_open) {
        g_v246_ep_open = 1;
        g_v246_ep_dirty = 0;
        g_v246_episodes++;

        return;
    }

    if (!threat && g_v246_ep_open) {
        g_v246_ep_open = 0;

        if (g_v246_ep_dirty) {
            g_v246_eaten++;
            tnx_v246_log("eaten");

            return;
        }

        g_v246_clean++;
        g_v246_clean_seen++;

        if (g_v246_clean_seen >= TNX_V246_CLEAN_LOGS) {
            g_v246_clean_seen = 0;
            tnx_v246_log("clean");
        }
    }
}
