#include "../recoil.h"

#if RCL_CI_HASH_INNER_MASK_RVA && RCL_CI_HASH_OUTER_MASK_RVA && RCL_BM_HASH_ENABLED_OFF && RCL_BM_HASH_KEY_OFF
#define RCL_CI_SIGNING_ON 1
#else
#define RCL_CI_SIGNING_ON 0
#endif




static uint32_t rcl_ci_table[RCL_CI_TABLE_TYPES];

static uint8_t rcl_ci_inner[RCL_CI_HASH_MASK_SIZE];

static uint8_t rcl_ci_outer[RCL_CI_HASH_MASK_SIZE];

static int rcl_ci_ready = 0;

int rcl_ci_load_constants(void) {
    int i = 0;

    if (rcl_ci_ready) return 1;
    if (!rcl_base) return 0;

    for (i = 0; i < (int)RCL_CI_TABLE_TYPES; i++) {
        if (!rcl_read_bytes(rcl_base + RCL_CI_TYPE_TABLE_RVA + (uintptr_t)i * 4ULL,
                            &rcl_ci_table[i], sizeof(uint32_t))) {
            return 0;
        }
    }

    if (!rcl_read_bytes(rcl_base + RCL_CI_HASH_INNER_MASK_RVA, rcl_ci_inner, RCL_CI_HASH_MASK_SIZE)) return 0;
    if (!rcl_read_bytes(rcl_base + RCL_CI_HASH_OUTER_MASK_RVA, rcl_ci_outer, RCL_CI_HASH_MASK_SIZE)) return 0;

    rcl_ci_ready = 1;

    return 1;
}

uint32_t rcl_ci_sign(void *ci, void *battle) {
#if RCL_CI_SIGNING_ON
    uint8_t key[RCL_CI_HASH_MASK_SIZE];
    uint8_t cmd[RCL_CI_TOKEN_READ_LEN];
    uint8_t enabled = 0;
    uint32_t token = 0;

    if (!ci || !battle) return 0;
    if (!rcl_read_bytes((uintptr_t)battle + RCL_BM_HASH_ENABLED_OFF, &enabled, 1)) return 0;
    if (enabled == 0) return 0;
    if (!rcl_ci_load_constants()) return 0;
    if (!rcl_read_bytes((uintptr_t)battle + RCL_BM_HASH_KEY_OFF, key, RCL_CI_HASH_MASK_SIZE)) return 0;
    if (!rcl_read_bytes((uintptr_t)ci + RCL_CI_TOKEN_READ_OFF, cmd, RCL_CI_TOKEN_READ_LEN)) return 0;

    token = rcl_ci_compute_token(key, cmd, rcl_ci_table, rcl_ci_inner, rcl_ci_outer);

    if (!rcl_write_bytes((uintptr_t)ci + RCL_CI_TOKEN_OFF, &token, sizeof(token))) {

        return 0;
    }


    return token;
#else
    (void)ci;
    (void)battle;

    return 0;
#endif
}
