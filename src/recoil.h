#ifndef RECOIL_H
#define RECOIL_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach/mach_time.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import <stdarg.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>
#import <signal.h>
#import "./offsets.h"
#include "hook.h"
#if __has_include(<ptrauth.h>)
#import <ptrauth.h>
#endif

#include "./core/rcl_types.h"

#include "./helpers/aim_lead.h"
#include "./helpers/dodge_kinds.h"
#include "./helpers/dodge_profiles.h"
#include "./utils/crypto.h"
#include "./utils/log.h"
#include "./utils/walls.h"
#include "./utils/flags.h"

#include "objc.h"
#include "./core/scan.h"

#include "./features/autoaim.h"
#include "./features/autododge.h"

#include "./core/commands.h"

#endif
