#include "titanox.h"

char g_v146_phase[48] = "boot";

char g_v146_hist[8][48];

volatile int g_v146_hist_n = 0;

volatile int g_v146_fd = -1;

volatile uint64_t g_v146_stage_ticks = 0;

int g_v146_installed = 0;

void tnx_v146_phase(const char *p) {
    int n;

    if (!p) return;

    strncpy(g_v146_phase, p, sizeof(g_v146_phase) - 1);
    g_v146_phase[sizeof(g_v146_phase) - 1] = '\0';

    n = g_v146_hist_n;

    if (n < 0) n = 0;
    if (n > 7) n = 7;

    strncpy(g_v146_hist[n], p, sizeof(g_v146_hist[0]) - 1);
    g_v146_hist[n][sizeof(g_v146_hist[0]) - 1] = '\0';

    g_v146_hist_n = (n + 1) & 7;
    g_v146_stage_ticks++;

    if (g_v146_fd < 0) {
        FILE *h = tnx_log_handle();

        if (h) g_v146_fd = fileno(h);
    }
}

void tnx_v146_crash(int sig, siginfo_t *info, void *ctx) {
    char buf[768];
    void *fault = (info && info->si_addr) ? info->si_addr : (void *)0;
    int n;

    (void)ctx;

    n = snprintf(buf, sizeof(buf),
                 "\n[CRASH] sig=%d fault=%p phase=%s stages=%llu h0=%s h1=%s h2=%s h3=%s "
                 "h4=%s h5=%s h6=%s h7=%s - phase is the stage that was running when the "
                 "signal arrived, the rest are the stages before it in arrival order, and this "
                 "line is written with write(2) so the log cap cannot drop it\n",
                 sig, fault, g_v146_phase, (unsigned long long)g_v146_stage_ticks,
                 g_v146_hist[0], g_v146_hist[1], g_v146_hist[2], g_v146_hist[3],
                 g_v146_hist[4], g_v146_hist[5], g_v146_hist[6], g_v146_hist[7]);

    if (n > 0 && g_v146_fd >= 0) {
        ssize_t ignored = write((int)g_v146_fd, buf, (size_t)n);

        (void)ignored;
    }

    {
        int i = 0;

        n = snprintf(buf, sizeof(buf),
                     "\n[JOURNAL] writes=%llu stale=%llu of %d slots, newest first:\n",
                     (unsigned long long)g_v245_writes, (unsigned long long)g_v245_stale,
                     (int)TNX_V245_JOURNAL);

        if (n > 0 && g_v146_fd >= 0) {
            ssize_t ignored = write((int)g_v146_fd, buf, (size_t)n);

            (void)ignored;
        }

        for (i = 0; i < TNX_V245_JOURNAL_LINES; i++) {
            int slot = (g_v245_at - 1 - i + TNX_V245_JOURNAL * 2) % TNX_V245_JOURNAL;

            n = snprintf(buf, sizeof(buf),
                         "[JOURNAL] #%d addr=%p value=%#x len=%u denied=%u tick=%llu phase=%s\n",
                         i, (void *)g_v245_addr[slot], g_v245_value[slot], (unsigned)g_v245_size[slot],
                         (unsigned)g_v245_denied[slot], (unsigned long long)g_v245_tick[slot],
                         g_v245_phase[slot] ? g_v245_phase[slot] : "?");

            if (n > 0 && g_v146_fd >= 0) {
                ssize_t ignored = write((int)g_v146_fd, buf, (size_t)n);

                (void)ignored;
            }
        }
    }

    signal(sig, SIG_DFL);
    raise(sig);
}

void tnx_v146_install(void) {
    struct sigaction sa;
    int sigs[5] = { SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE };
    FILE *h = tnx_log_handle();
    int i;

    if (g_v146_installed) return;

    g_v146_installed = 1;

    if (h) g_v146_fd = fileno(h);

    memset(&sa, 0, sizeof(sa));

    sa.sa_sigaction = tnx_v146_crash;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;

    sigemptyset(&sa.sa_mask);

    for (i = 0; i < 5; i++) sigaction(sigs[i], &sa, NULL);

    tnx_logf("v146 crash locator armed fd=%d sigs=5 - the next signal writes the running stage "
             "and the eight before it to that descriptor, so a crash names itself instead of "
             "ending the log", (int)g_v146_fd);
}

__attribute__((constructor))
void start(void) {

    tnx_v146_install();

    dispatch_async(dispatch_get_main_queue(), ^{
        tlog(@"=== titanox started (zero latency mode) ===");
        poll_for_game(0);
    });
}
