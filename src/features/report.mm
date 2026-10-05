#include "titanox.h"

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

void tnx_stats(void) {
    uintptr_t own = g_own_elem_2;
    int32_t hp = 0;
    int32_t hpmax = 0;
    int threat = 0;

    if (!own) own = (uintptr_t)g_own_elem;
    if (!own) return;
    if (!tnx_read_i32(own + TNX_HP_OFF, &hp)) return;
    if (!tnx_read_i32(own + TNX_HPMAX_OFF, &hpmax)) return;
    if (hpmax <= 0) return;

    if (g_hp < 0) g_hp = hp;
    if (g_hpmax < 0) g_hpmax = hpmax;
    if (hpmax != g_hpmax) g_hpmax = hpmax;

    if (hp < g_hp) {
        g_hits++;
        g_ep_dirty = 1;

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
