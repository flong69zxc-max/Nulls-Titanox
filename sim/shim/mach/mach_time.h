#ifndef SIM_MACH_TIME_H
#define SIM_MACH_TIME_H
#include <stdint.h>
typedef uint64_t mach_timebase_info_data_t;
typedef unsigned int mach_timebase_info_t;
extern "C" uint64_t mach_absolute_time(void);
extern "C" int mach_timebase_info(mach_timebase_info_t info);
#endif
