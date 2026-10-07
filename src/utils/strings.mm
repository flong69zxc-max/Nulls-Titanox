#include "titanox.h"











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
tnx_reject_t t_reject;
int t_setpred_blocked_logs = 0;
