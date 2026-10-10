#ifndef RECOIL_H
#define RECOIL_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

typedef int BOOL;

double CFAbsoluteTimeGetCurrent(void);

#include "./core/offsets.h"
#include "./helpers/dodge_kinds.h"
#include "./helpers/dodge_profiles.h"
#include "./core/commands.h"
#include "./utils/walls.h"
#include "./core/scan_stub.h"
#include "../../sim_world.h"

#endif
