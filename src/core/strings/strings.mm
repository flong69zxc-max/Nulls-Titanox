#include "../../recoil.h"











int rcl_ascii_word(uintptr_t address) {
    uint8_t bytes[8];
    int printable = 0;

    if (!rcl_read_bytes(address, bytes, sizeof(bytes))) return 0;

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable == 8 ? 1 : 0;
}

int rcl_word_ascii(uint64_t value) {
    uint8_t bytes[8];
    int printable = 0;

    memcpy(bytes, &value, sizeof(bytes));

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable;
}

int rcl_element_ascii(uintptr_t element) {
    if (rcl_ascii_word(element)) return 1;

    return rcl_word_ascii((uint64_t)element) == 8 ? 1 : 0;
}
