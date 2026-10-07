#ifndef RECOIL_RUNTIME_SETUP_H
#define RECOIL_RUNTIME_SETUP_H

#include "../../core/types/types.h"

void setup(void);
void rcl_run_autododge(int from_update);

#define RCL_MANAGER_MIN_OBJECTS 3
#define RCL_WIRE_OWNER 1
#define RCL_HOPCHOSEN_DIRECT 2
#define RCL_DRIVE_FROM_UPDATE 0
#define RCL_ARRAY_VOTE_LOGS 8
#define RCL_HB_TICKS 5
#define RCL_QUIET_SECS 10
#define RCL_LIVE_OBJ_MIN 3
#define RCL_LIVE_TEAM_MIN 2
#define RCL_BAR_TICKS 30
#define RCL_IDLE_TICKS 15
#define RCL_IDLE_RETRY_TICKS 300
#define RCL_STATE_BATTLE 5
#define RCL_MODE_MIN_TYPES 2
#define RCL_MODE_TYPE_MAX 16
#define RCL_SNAPSHOT_DELAY 1.2
#define RCL_LOGS_ON 0

#endif
