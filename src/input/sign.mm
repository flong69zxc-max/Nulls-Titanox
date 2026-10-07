#include "titanox.h"

#if TNX_CI_HASH_INNER_MASK_RVA && TNX_CI_HASH_OUTER_MASK_RVA && TNX_BM_HASH_ENABLED_OFF && TNX_BM_HASH_KEY_OFF
#define TNX_CI_SIGNING_ON 1
#else
#define TNX_CI_SIGNING_ON 0
#endif




static uint32_t t_ci_table[TNX_CI_TABLE_TYPES];

static uint8_t t_ci_inner[TNX_CI_HASH_MASK_SIZE];

static uint8_t t_ci_outer[TNX_CI_HASH_MASK_SIZE];

static int t_ci_ready = 0;

int tnx_ci_load_constants(void) {
    int i = 0;

    if (t_ci_ready) return 1;
    if (!t_base) return 0;

    for (i = 0; i < (int)TNX_CI_TABLE_TYPES; i++) {
        if (!tnx_read_bytes(t_base + TNX_CI_TYPE_TABLE_RVA + (uintptr_t)i * 4ULL,
                            &t_ci_table[i], sizeof(uint32_t))) {
            return 0;
        }
    }

    if (!tnx_read_bytes(t_base + TNX_CI_HASH_INNER_MASK_RVA, t_ci_inner, TNX_CI_HASH_MASK_SIZE)) return 0;
    if (!tnx_read_bytes(t_base + TNX_CI_HASH_OUTER_MASK_RVA, t_ci_outer, TNX_CI_HASH_MASK_SIZE)) return 0;

    t_ci_ready = 1;

    return 1;
}

uint32_t tnx_ci_sign(void *ci, void *battle) {
#if TNX_CI_SIGNING_ON
    uint8_t key[TNX_CI_HASH_MASK_SIZE];
    uint8_t cmd[TNX_CI_TOKEN_READ_LEN];
    uint8_t enabled = 0;
    uint32_t token = 0;

    if (!ci || !battle) return 0;
    if (!tnx_read_bytes((uintptr_t)battle + TNX_BM_HASH_ENABLED_OFF, &enabled, 1)) return 0;
    if (enabled == 0) return 0;
    if (!tnx_ci_load_constants()) return 0;
    if (!tnx_read_bytes((uintptr_t)battle + TNX_BM_HASH_KEY_OFF, key, TNX_CI_HASH_MASK_SIZE)) return 0;
    if (!tnx_read_bytes((uintptr_t)ci + TNX_CI_TOKEN_READ_OFF, cmd, TNX_CI_TOKEN_READ_LEN)) return 0;

    token = tnx_ci_compute_token(key, cmd, t_ci_table, t_ci_inner, t_ci_outer);

    if (!tnx_write_bytes((uintptr_t)ci + TNX_CI_TOKEN_OFF, &token, sizeof(token))) {

        return 0;
    }


    return token;
#else
    (void)ci;
    (void)battle;

    return 0;
#endif
}
