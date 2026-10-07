#include "titanox.h"

#include <dlfcn.h>
#include <sys/ucontext.h>

char t_phase[48] = "boot";

char t_hist[8][48];

volatile int t_hist_n = 0;

volatile int t_fd = -1;

volatile uint64_t t_stage_ticks = 0;

int t_installed = 0;

void tnx_phase(const char *p) {
    int n;

    if (!p) return;

    strncpy(t_phase, p, sizeof(t_phase) - 1);
    t_phase[sizeof(t_phase) - 1] = '\0';

    n = t_hist_n;

    if (n < 0) n = 0;
    if (n > 7) n = 7;

    strncpy(t_hist[n], p, sizeof(t_hist[0]) - 1);
    t_hist[n][sizeof(t_hist[0]) - 1] = '\0';

    t_hist_n = (n + 1) & 7;
    t_stage_ticks++;

    if (t_fd < 0) {
        FILE *h = tnx_log_handle();

        if (h) t_fd = fileno(h);
    }
}

void tnx_where(uintptr_t addr, char *out, size_t n) {
    Dl_info info;

    if (!out || n == 0) return;

    out[0] = '\0';

    if (!addr) {
        snprintf(out, n, "(none)");
        return;
    }

    if (t_base && addr >= t_base && addr < (t_base + 0x40000000ULL)) {
        snprintf(out, n, "game+%#llx", (unsigned long long)(addr - t_base));
        return;
    }

    memset(&info, 0, sizeof(info));

    if (dladdr((void *)addr, &info) && info.dli_fname) {
        const char *slash = strrchr(info.dli_fname, '/');

        snprintf(out, n, "%s+%#llx", slash ? (slash + 1) : info.dli_fname,
                 (unsigned long long)(addr - (uintptr_t)info.dli_fbase));
        return;
    }

    snprintf(out, n, "unmapped");
}

void tnx_crash(int sig, siginfo_t *info, void *ctx) {
    char buf[768];
    void *fault = (info && info->si_addr) ? info->si_addr : (void *)0;
    int n;

    (void)ctx;

    n = snprintf(buf, sizeof(buf),
                 "\n[CRASH] sig=%d fault=%p phase=%s stages=%llu h0=%s h1=%s h2=%s h3=%s "
                 "h4=%s h5=%s h6=%s h7=%s - phase is the stage that was running when the "
                 "signal arrived, the rest are the stages before it in arrival order, and this "
                 "line is written with write(2) so the log cap cannot drop it\n",
                 sig, fault, t_phase, (unsigned long long)t_stage_ticks,
                 t_hist[0], t_hist[1], t_hist[2], t_hist[3],
                 t_hist[4], t_hist[5], t_hist[6], t_hist[7]);

    if (n > 0 && t_fd >= 0) {
        ssize_t ignored = write((int)t_fd, buf, (size_t)n);

        (void)ignored;
    }

    {
        ucontext_t *uc = (ucontext_t *)ctx;
        uintptr_t pc = 0;
        uintptr_t lr = 0;
        uintptr_t sp = 0;
        char pcs[80];
        char lrs[80];

#if defined(__arm64__) || defined(__aarch64__)
        if (uc) {
            pc = (uintptr_t)uc->uc_mcontext->__ss.__pc;
            lr = (uintptr_t)uc->uc_mcontext->__ss.__lr;
            sp = (uintptr_t)uc->uc_mcontext->__ss.__sp;
        }
#endif

        tnx_where(pc, pcs, sizeof(pcs));
        tnx_where(lr, lrs, sizeof(lrs));

        n = snprintf(buf, sizeof(buf),
                     "\n[CRASH] pc=%p %s lr=%p %s sp=%p far=%p - pc is the code that was running and lr "
                     "the call site it would return to, both resolved against the images, so a pc in the "
                     "game with an lr in titanox is a game function we called, while both in titanox is "
                     "our own code and far is the address the fault touched\n",
                     (void *)pc, pcs, (void *)lr, lrs, (void *)sp, fault);

        if (n > 0 && t_fd >= 0) {
            ssize_t ignored = write((int)t_fd, buf, (size_t)n);

            (void)ignored;
        }
    }

    {
        int i = 0;

        n = snprintf(buf, sizeof(buf),
                     "\n[JOURNAL] writes=%llu stale=%llu of %d slots, newest first:\n",
                     (unsigned long long)t_writes_2, (unsigned long long)t_stale,
                     (int)TNX_JOURNAL);

        if (n > 0 && t_fd >= 0) {
            ssize_t ignored = write((int)t_fd, buf, (size_t)n);

            (void)ignored;
        }

        for (i = 0; i < TNX_JOURNAL_LINES; i++) {
            int slot = (t_at - 1 - i + TNX_JOURNAL * 2) % TNX_JOURNAL;

            n = snprintf(buf, sizeof(buf),
                         "[JOURNAL] #%d addr=%p value=%#x len=%u denied=%u tick=%llu phase=%s\n",
                         i, (void *)t_addr[slot], t_value[slot], (unsigned)t_size[slot],
                         (unsigned)t_denied[slot], (unsigned long long)t_tick_3[slot],
                         t_phase_2[slot] ? t_phase_2[slot] : "?");

            if (n > 0 && t_fd >= 0) {
                ssize_t ignored = write((int)t_fd, buf, (size_t)n);

                (void)ignored;
            }
        }
    }

    signal(sig, SIG_DFL);
    raise(sig);
}

void tnx_install(void) {
    struct sigaction sa;
    int sigs[5] = { SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE };
    FILE *h = tnx_log_handle();
    int i;

    if (t_installed) return;

    t_installed = 1;

    if (h) t_fd = fileno(h);

    memset(&sa, 0, sizeof(sa));

    sa.sa_sigaction = tnx_crash;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;

    sigemptyset(&sa.sa_mask);

    for (i = 0; i < 5; i++) sigaction(sigs[i], &sa, NULL);

    tnx_logf("crash locator armed fd=%d sigs=5 - the next signal writes the running stage "
             "and the eight before it to that descriptor, so a crash names itself instead of "
             "ending the log", (int)t_fd);
}

__attribute__((constructor))
void start(void) {

    tnx_install();

    dispatch_async(dispatch_get_main_queue(), ^{
        tlog(@"=== titanox started v92 (no stick) ===");
        poll_for_game(0);
    });
}
