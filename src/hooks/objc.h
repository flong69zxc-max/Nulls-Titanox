#ifndef RECOIL_HOOKS_OBJC_H
#define RECOIL_HOOKS_OBJC_H

#include "core/types.h"

extern rcl_objc_hook_t rcl_objc_hooks[OBJC_HOOK_MAX];
BOOL rcl_class_owns_method(Class cls, SEL sel);
int rcl_objc_arg_types(const char *types, char *out, size_t capacity);
int rcl_objc_arm(const char *clsName, const char *selName);
rcl_objc_hook_t *rcl_objc_find(id self, SEL _cmd);
void rcl_objc_rep_a(id self, SEL _cmd);
void rcl_objc_rep_b(id self, SEL _cmd, id a1);
void rcl_objc_rep1b(id self, SEL _cmd, BOOL a1);
void rcl_objc_rep_c(id self, SEL _cmd, id a1, id a2);
BOOL rcl_objc_targets(id self, rcl_objc_hook_t *hook);
Class rcl_owner_class(Class cls, SEL sel);

#endif
