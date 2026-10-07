#include "recoil.h"

const char *rcl_prologue_rule(uintptr_t address) {
    uint32_t first = 0;

    if (!rcl_read_word(address, &first)) return "unreadable";

    if (first == 0xD503233F) return "paciasp";
    if (first == 0xD503237F) return "pacibsp";
    if ((first & 0xFFFFFF1F) == 0xD503241F) return "bti";

    if ((first & 0xFF800000u) == 0xA9800000u && ((first >> 5) & 31u) == 31u) return "stppre";
    if ((first & 0xFF8003FFu) == 0xD10003FFu) return "subsp";

    if (address >= 4) {
        uint32_t previous = 0;
        if (rcl_read_word(address - 4, &previous) && previous == 0xD65F03C0) return "afterret";
    }

    return "none";
}

BOOL rcl_looks_like_start(uintptr_t address) {
    const char *rule = rcl_prologue_rule(address);

    if (!rule) return NO;

    return strcmp(rule, "none") != 0 && strcmp(rule, "unreadable") != 0;
}

size_t rcl_start_index(uintptr_t address, BOOL *exact) {
    size_t index = (size_t)-1;

    if (exact) *exact = NO;
    if (!rcl_starts || !rcl_starts_count) return index;

    size_t low = 0;
    size_t high = rcl_starts_count;

    while (low < high) {
        size_t mid = low + (high - low) / 2;

        if (rcl_starts[mid] <= address) low = mid + 1;
        else high = mid;
    }

    if (low == 0) return index;

    index = low - 1;

    if (exact) *exact = (rcl_starts[index] == address);

    return index;
}

BOOL rcl_start_word(uint32_t word) {
    if (word == 0xD503233F || word == 0xD503237F) return YES;
    if ((word & 0xFFFFFF1Fu) == 0xD503241Fu) return YES;
    if ((word & 0xFF800000u) == 0xA9800000u && ((word >> 5) & 31u) == 31u) return YES;
    if ((word & 0xFF8003FFu) == 0xD10003FFu) return YES;

    return NO;
}

BOOL rcl_start_boundary(const uint8_t *bytes, size_t offset) {
    if (offset < 4) return NO;

    for (size_t back = 4, seen = 0; back <= offset && seen < 8; back += 4, seen++) {
        uint32_t word = 0;

        memcpy(&word, bytes + offset - back, 4);

        if (word == 0xD65F03C0) return YES;

        if (word == 0xD503201F) continue;
        if ((word & 0xFFFFFF1Fu) == 0xD503241Fu) continue;

        return NO;
    }

    return NO;
}

void rcl_load_function_starts(void) {
    if (rcl_starts || !rcl_base) return;

    uintptr_t textAddress = 0;
    uint64_t textSize = 0;

    if (!rcl_text_section(&textAddress, &textSize)) {
        return;
    }

    if (textSize < 64 || textSize > (64ull * 1024ull * 1024ull)) {
        return;
    }

    uint8_t *bytes = (uint8_t *)malloc((size_t)textSize);

    if (!bytes) {
        return;
    }

    if (!rcl_copy(textAddress, bytes, (size_t)textSize)) {
        free(bytes);
        return;
    }

    size_t capacity = 32768;
    uintptr_t *starts = (uintptr_t *)malloc(capacity * sizeof(uintptr_t));

    if (!starts) {
        free(bytes);
        return;
    }

    size_t count = 0;

    for (size_t offset = 4; offset + 4 <= (size_t)textSize; offset += 4) {
        uint32_t word = 0;

        memcpy(&word, bytes + offset, 4);

        if (!rcl_start_word(word)) continue;
        if (!rcl_start_boundary(bytes, offset)) continue;

        if (count >= capacity) {
            size_t grown = capacity * 2;
            uintptr_t *larger = (uintptr_t *)realloc(starts, grown * sizeof(uintptr_t));

            if (!larger) break;

            starts = larger;
            capacity = grown;
        }

        starts[count++] = textAddress + offset;
    }

    free(bytes);

    if (!count) {
        free(starts);
        return;
    }

    rcl_starts = starts;
    rcl_starts_count = count;

}
int rcl_word(uintptr_t address, uint32_t *out) {
    if (!out) return 0;
    if (address & 3ULL) return 0;

    return rcl_read_bytes(address, out, sizeof(*out)) ? 1 : 0;
}

int rcl_is_term(uint32_t w) {
    if ((w & 0xFFFFFC1Fu) == 0xD65F0000u) return 1;
    if ((w & 0xFFFFFC1Fu) == 0xD61F0000u) return 1;
    if (w == 0xD69F03E0u) return 1;
    if ((w & 0xFC000000u) == 0x14000000u) return 1;

    return 0;
}

int rcl_is_prologue(uint32_t w) {
    if (w == 0xD503237Fu || w == 0xD503233Fu) return 1;
    if ((w & 0xFFFFFF1Fu) == 0xD503241Fu) return 1;
    if ((w & 0xFF800000u) == 0xA9800000u && ((w >> 5) & 31u) == 31u) return 1;
    if ((w & 0xFF8003FFu) == 0xD10003FFu) return 1;

    return 0;
}

uintptr_t rcl_entry(uintptr_t rva) {
    uint32_t self = 0;
    uint32_t prev = 0;

    if (!rcl_base || !rva) return 0;
    if (!rcl_word(rcl_base + rva, &self)) return 0;
    if (self == 0) return 0;

    if (rcl_is_prologue(self)) return rcl_base + rva;
    if (!rcl_word(rcl_base + rva - 4, &prev)) return 0;
    if (rcl_is_term(prev)) return rcl_base + rva;

    return 0;
}

uintptr_t *rcl_starts = NULL;

size_t rcl_starts_count = 0;
