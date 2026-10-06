#include "titanox.h"

uint64_t t_sd_logs = 0;

uint64_t t_sd_no_mgr = 0;

uint64_t t_sd_no_enable = 0;

uint64_t t_sd_no_cooldown = 0;

uint64_t t_sd_ack_eq_seq = 0;

void tnx_sd_log(void) {
    void *mgr = NULL;
    void *client = NULL;
    void *queue = NULL;
    uint8_t enabled = 0;
    float cooldown = 0.0f;
    int32_t seqA = 0;
    int32_t seqB = 0;
    int32_t ack = 0;
    int32_t clientAck = 0;
    int32_t qNow = 0;

    if (!t_scene_object) return;

    if (!tnx_read_ptr((uintptr_t)t_scene_object + TNX_MGR_OFF, &mgr) || !mgr) {
        t_sd_no_mgr++;

        return;
    }

    tnx_read_bytes((uintptr_t)mgr + TNX_MGR_ENABLE_OFF, &enabled, sizeof(enabled));
    tnx_read_bytes((uintptr_t)mgr + TNX_MGR_COOLDOWN_OFF, &cooldown, sizeof(cooldown));
    tnx_read_bytes((uintptr_t)mgr + TNX_MGR_SEQ_A_OFF, &seqA, sizeof(seqA));
    tnx_read_bytes((uintptr_t)mgr + TNX_MGR_SEQ_B_OFF, &seqB, sizeof(seqB));
    tnx_read_bytes((uintptr_t)mgr + TNX_MGR_ACK_OFF, &ack, sizeof(ack));

    if (tnx_read_ptr((uintptr_t)t_scene_object + TNX_CLIENT_HOP_OFF, &client) && client) {
        tnx_read_bytes((uintptr_t)client + TNX_CLIENT_ACK_SRC_OFF, &clientAck, sizeof(clientAck));
    }

    if (tnx_read_ptr((uintptr_t)mgr + TNX_MGR_QUEUE_OFF, &queue) && queue) {
        tnx_read_bytes((uintptr_t)queue + TNX_MGR_COUNT_OFF, &qNow, sizeof(qNow));
    }

    if (enabled != 1) t_sd_no_enable++;
    if (cooldown > TNX_MGR_COOLDOWN_MIN) t_sd_no_cooldown++;
    if (ack == seqB) t_sd_ack_eq_seq++;

    t_sd_logs++;

    TNX_LOGX("sd mgr=%p en=%d cd=%g m10=%d m14=%d ack=%d client48=%d qNow=%d "
             "noMgr=%llu noEn=%llu noCd=%llu ackEq=%llu",
             mgr, (int)enabled, (double)cooldown, seqA, seqB, ack, clientAck, qNow,
             (unsigned long long)t_sd_no_mgr, (unsigned long long)t_sd_no_enable,
             (unsigned long long)t_sd_no_cooldown, (unsigned long long)t_sd_ack_eq_seq);
}
