#ifndef RECOIL_CORE_COMMANDS_H
#define RECOIL_CORE_COMMANDS_H

#include "./offsets.h"

#define RCL_MSG_SIZE 0x48
#define RCL_TYPE_MOVE 0x2
#define RCL_QUEUE 1
#define RCL_QUEUE_GUARD_MGR 0
#define RCL_QGUARD_LOGS 3
#define RCL_PRED_SET 1
#define RCL_PRED_FLAG 1
#define RCL_PREDICT 1
#define RCL_PREDICT_FLAG 1
#define RCL_MOVE_ON 1

uintptr_t rcl_entry_2(uintptr_t rva);
void *rcl_msg_alloc(void);
void *rcl_manager(void);
int rcl_queue_count(uintptr_t *mgrOut);
int rcl_pred_set(int x, int y);
int rcl_move_to(int32_t x, int32_t y, float ox, float oy);
extern uintptr_t rcl_pred_last;
int rcl_predict(int32_t x, int32_t y);

int rcl_ci_load_constants(void);
uint32_t rcl_ci_sign(void *ci, void *battle);
int rcl_enqueue(int x, int y);
int rcl_enqueue_type(int x, int y, int type);

#endif
