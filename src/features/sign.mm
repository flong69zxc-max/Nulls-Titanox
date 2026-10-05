#include "titanox.h"

#if TNX_CI_HASH_INNER_MASK_RVA && TNX_CI_HASH_OUTER_MASK_RVA && TNX_BM_HASH_ENABLED_OFF && TNX_BM_HASH_KEY_OFF
#define TNX_CI_SIGNING_ON 1
#else
#define TNX_CI_SIGNING_ON 0
#endif

int g_ci_sign_on = TNX_CI_SIGNING_ON;

uint32_t g_ci_tokens = 0;

uint32_t g_ci_sign_fails = 0;

static uint32_t g_ci_table[TNX_CI_TABLE_TYPES];

static uint8_t g_ci_inner[TNX_CI_HASH_MASK_SIZE];

static uint8_t g_ci_outer[TNX_CI_HASH_MASK_SIZE];

static int g_ci_ready = 0;

int tnx_ci_load_constants(void) {
    int i = 0;

    if (g_ci_ready) return 1;
    if (!g_base) return 0;

    for (i = 0; i < (int)TNX_CI_TABLE_TYPES; i++) {
        if (!tnx_read_bytes(g_base + TNX_CI_TYPE_TABLE_RVA + (uintptr_t)i * 4ULL,
                            &g_ci_table[i], sizeof(uint32_t))) {
            return 0;
        }
    }

    if (!tnx_read_bytes(g_base + TNX_CI_HASH_INNER_MASK_RVA, g_ci_inner, TNX_CI_HASH_MASK_SIZE)) return 0;
    if (!tnx_read_bytes(g_base + TNX_CI_HASH_OUTER_MASK_RVA, g_ci_outer, TNX_CI_HASH_MASK_SIZE)) return 0;

    g_ci_ready = 1;

    return 1;
}

void *tnx_ci_new(int cmdType) {
    uintptr_t allocFn = tnx_entry_2(TNX_ALLOC_RVA);
    uintptr_t ctorFn = tnx_entry_2(TNX_MSGCTOR_RVA);
    void *ci = NULL;

    if (!allocFn || !ctorFn) return NULL;

    ci = ((void *(*)(size_t))allocFn)((size_t)TNX_CI_CMD_BUF_SIZE);
    if (!ci) return NULL;

    memset(ci, 0, (size_t)TNX_CI_CMD_BUF_SIZE);
    ((void (*)(void *, int))ctorFn)(ci, cmdType);

    return ci;
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

    token = tnx_ci_compute_token(key, cmd, g_ci_table, g_ci_inner, g_ci_outer);

    if (!tnx_write_bytes((uintptr_t)ci + TNX_CI_TOKEN_OFF, &token, sizeof(token))) {
        g_ci_sign_fails++;

        return 0;
    }

    g_ci_tokens++;

    return token;
#else
    (void)ci;
    (void)battle;

    return 0;
#endif
}

int tnx_ci_push(void *ci) {
    uintptr_t battleFn = tnx_entry_2(TNX_GETBATTLE_RVA);
    uintptr_t inputFn = tnx_entry_2(TNX_ADDINPUT_RVA);
    void *battle = NULL;
    void *mgr = NULL;

    if (!ci || !battleFn || !inputFn) return 0;

    battle = ((void *(*)(void))battleFn)();
    if (!battle) return 0;
    if (!tnx_read_ptr((uintptr_t)battle + TNX_MGR_OFF, &mgr) || !mgr) return 0;

    tnx_ci_sign(ci, battle);

    ((void (*)(void *, void *))inputFn)(mgr, ci);

    return 1;
}

int tnx_ci_send(int cmdType) {
    void *ci = tnx_ci_new(cmdType);

    if (!ci) return 0;

    return tnx_ci_push(ci);
}
