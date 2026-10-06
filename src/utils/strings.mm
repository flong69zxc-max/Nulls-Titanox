#include "titanox.h"

uint64_t t_setpred_calls = 0;

uintptr_t t_setpred_this = 0;

float t_setpred_x = 0.0f;

float t_setpred_y = 0.0f;

uint64_t t_ascii_rejected = 0;

uint32_t t_never_dispatched_mask = 0;

int t_ascii_refused = 0;

int t_alert_streak = 0;

uintptr_t t_alert_streak_ptr = 0;

uint64_t t_alert_calls = 0;

int tnx_ascii_word(uintptr_t address) {
    uint8_t bytes[8];
    int printable = 0;

    if (!tnx_read_bytes(address, bytes, sizeof(bytes))) return 0;

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable == 8 ? 1 : 0;
}

int tnx_word_ascii(uint64_t value) {
    uint8_t bytes[8];
    int printable = 0;

    memcpy(bytes, &value, sizeof(bytes));

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable;
}

int tnx_element_ascii(uintptr_t element) {
    if (tnx_ascii_word(element)) return 1;

    return tnx_word_ascii((uint64_t)element) == 8 ? 1 : 0;
}

void tnx_append(char *buf, size_t size, size_t *used, const char *token) {
    size_t len = strlen(token);

    if (*used && *used + 1 < size) buf[(*used)++] = '+';

    if (*used + len >= size) len = (*used + 1 < size) ? size - *used - 1 : 0;

    memcpy(buf + *used, token, len);

    *used += len;
    buf[*used] = 0;
}

tnx_reject_t t_reject;

const char *tnx_reject_text(char *buf, size_t size) {
    snprintf(buf, size,
             "elements=%d rejNull=%d rejUnreadable=%d rejAscii=%d rejNoVt=%d rejGidZero=%d "
             "rejNonPlayer=%d rejOutOfRange=%d rejTeamMissing=%d deadSeen=%d",
             t_reject.elementsRead, t_reject.rejNull, t_reject.rejUnreadable,
             t_reject.rejAscii, t_reject.rejNoVt, t_reject.rejGidZero,
             t_reject.rejNonPlayer,
             t_reject.rejOutOfRange, t_reject.rejTeamMissing, t_reject.deadSeen);

    return buf;
}

int t_setpred_blocked_logs = 0;
