#ifndef SIM_FOUNDATION_H
#define SIM_FOUNDATION_H
#include <stdint.h>
#include <stddef.h>
typedef signed char BOOL;
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef double NSTimeInterval;
typedef double CFAbsoluteTime;
typedef struct objc_object *id;
typedef struct objc_selector *SEL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#define nil ((id)0)
extern "C" double CFAbsoluteTimeGetCurrent(void);
#endif
