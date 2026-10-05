#include "titanox.h"

uint64_t g_v52_setpred_calls = 0;

uintptr_t g_v52_setpred_this = 0;

float g_v52_setpred_x = 0.0f;

float g_v52_setpred_y = 0.0f;

uint64_t g_v52_ascii_rejected = 0;

uint32_t g_v50_never_dispatched_mask = 0;

uint64_t g_v50_ticks = 0;

int g_v75_ascii_refused = 0;

int g_v75_best_wait_logs = 0;

int g_v50_alert_streak = 0;

uintptr_t g_v50_alert_streak_ptr = 0;

uint64_t g_v50_alert_calls = 0;

int g_v50_alert_withheld_logs = 0;

int tnx_v52_ascii_word(uintptr_t address) {
    uint8_t bytes[8];
    int printable = 0;

    if (!tnx_read_bytes(address, bytes, sizeof(bytes))) return 0;

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable == 8 ? 1 : 0;
}

int tnx_v75_word_ascii(uint64_t value) {
    uint8_t bytes[8];
    int printable = 0;

    memcpy(bytes, &value, sizeof(bytes));

    for (int i = 0; i < 8; i++) {
        if (bytes[i] >= 0x20 && bytes[i] <= 0x7e) printable++;
    }

    return printable;
}

int tnx_v75_element_ascii(uintptr_t element) {
    if (tnx_v52_ascii_word(element)) return 1;

    return tnx_v75_word_ascii((uint64_t)element) == 8 ? 1 : 0;
}

int tnx_v75_object_live(uintptr_t object) {
    int32_t gid = 0;
    int32_t team = 0;
    int32_t x = 0;
    int32_t y = 0;

    if (!tnx_gameobject_shape(object)) return 0;
    if (!tnx_read_i32(object + TNX_OBJ_GLOBALID_OFF, &gid)) return 0;
    if (gid <= 0 || gid >= TNX_V75_GID_MAX) return 0;
    if (!tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team)) return 0;
    if (team < 0 || team > TNX_V75_TEAM_MAX) return 0;
    if (!tnx_read_i32(object + tnx_v57_coord_x_off(), &x)) return 0;
    if (!tnx_read_i32(object + tnx_v57_coord_y_off(), &y)) return 0;
    if (x <= -TNX_V75_COORD_MAX || x >= TNX_V75_COORD_MAX) return 0;
    if (y <= -TNX_V75_COORD_MAX || y >= TNX_V75_COORD_MAX) return 0;

    return 1;
}

void tnx_v75_measure(uintptr_t manager, int32_t count, tnx_v75_measure_t *out) {
    void *array = NULL;
    uint32_t teams = 0;
    int32_t posX[TNX_V75_ASCII_WINDOW];
    int32_t posY[TNX_V75_ASCII_WINDOW];
    int posCount = 0;

    memset(out, 0, sizeof(*out));

    if (!manager || count <= 0) return;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) return;

    if (count > TNX_V75_ASCII_WINDOW) count = TNX_V75_ASCII_WINDOW;

    for (int32_t i = 0; i < count; i++) {
        void *element = NULL;
        int32_t team = 0;
        int32_t x = 0;
        int32_t y = 0;
        int seen = 0;

        if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)i * sizeof(void *), &element)) break;
        if (!element) continue;

        out->sampled++;

        if (tnx_v75_element_ascii((uintptr_t)element)) out->ascii++;

        {
            void *elementVt = NULL;

            if (!tnx_read_ptr((uintptr_t)element, &elementVt) || !elementVt ||
                !tnx_v77_vtable_is_data((uintptr_t)elementVt)) {
                out->noVt++;
            }
        }

        if (!tnx_v75_object_live((uintptr_t)element)) continue;

        tnx_read_i32((uintptr_t)element + TNX_OBJ_TEAM_OFF, &team);

        teams |= (uint32_t)(1u << (unsigned)team);

        tnx_read_i32((uintptr_t)element + tnx_v57_coord_x_off(), &x);
        tnx_read_i32((uintptr_t)element + tnx_v57_coord_y_off(), &y);

        for (int k = 0; k < posCount; k++) {
            if (posX[k] == x && posY[k] == y) {
                seen = 1;

                break;
            }
        }

        if (!seen && posCount < TNX_V75_ASCII_WINDOW) {
            posX[posCount] = x;
            posY[posCount] = y;
            posCount++;
        }
    }

    for (int t = 0; t <= TNX_V75_TEAM_MAX; t++) {
        if (teams & (uint32_t)(1u << (unsigned)t)) out->teamDistinct++;
    }

    out->posDistinct = posCount;
}

void tnx_v75_append(char *buf, size_t size, size_t *used, const char *token) {
    size_t len = strlen(token);

    if (*used && *used + 1 < size) buf[(*used)++] = '+';

    if (*used + len >= size) len = (*used + 1 < size) ? size - *used - 1 : 0;

    memcpy(buf + *used, token, len);

    *used += len;
    buf[*used] = 0;
}

int tnx_v75_trail_verdict(const tnx_trail_t *entry, char *buf, size_t size) {
    char parts[64];
    size_t used = 0;

    parts[0] = 0;

    if (!entry->rawOk) tnx_v75_append(parts, sizeof(parts), &used, "image");
    if (entry->refused == 1) tnx_v75_append(parts, sizeof(parts), &used, "ascii");
    if (entry->refused == 2) tnx_v75_append(parts, sizeof(parts), &used, "weak");
    if (entry->refused == 3) tnx_v75_append(parts, sizeof(parts), &used, "noVt");
    if (entry->teamDistinct < 2) tnx_v75_append(parts, sizeof(parts), &used, "noTeam");
    if (entry->posDistinct < 2) tnx_v75_append(parts, sizeof(parts), &used, "noPos");

    if (!used) return 1;

    snprintf(buf, size, "%s", parts);

    return 0;
}

tnx_v50_reject_t g_v50_reject;

const char *tnx_v50_reject_text(char *buf, size_t size) {
    snprintf(buf, size,
             "elements=%d rejNull=%d rejUnreadable=%d rejAscii=%d rejNoVt=%d rejGidZero=%d "
             "rejNonPlayer=%d rejOutOfRange=%d rejTeamMissing=%d deadSeen=%d",
             g_v50_reject.elementsRead, g_v50_reject.rejNull, g_v50_reject.rejUnreadable,
             g_v50_reject.rejAscii, g_v50_reject.rejNoVt, g_v50_reject.rejGidZero,
             g_v50_reject.rejNonPlayer,
             g_v50_reject.rejOutOfRange, g_v50_reject.rejTeamMissing, g_v50_reject.deadSeen);

    return buf;
}

int g_v50_setpred_blocked_logs = 0;
