#ifndef TITANOX_CORE_OBJC_H
#define TITANOX_CORE_OBJC_H

#include "core/types.h"

/* the Objective-C side of the hook set */

extern tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];
BOOL tnx_class_owns_method(Class cls, SEL sel);
int tnx_objc_arg_types(const char *types, char *out, size_t capacity);
int tnx_objc_arm(const char *clsName, const char *selName);
tnx_objc_hook_t *tnx_objc_find(id self, SEL _cmd);
void tnx_objc_rep0(id self, SEL _cmd);
void tnx_objc_rep1(id self, SEL _cmd, id a1);
void tnx_objc_rep1b(id self, SEL _cmd, BOOL a1);
void tnx_objc_rep2(id self, SEL _cmd, id a1, id a2);
BOOL tnx_objc_targets(id self, tnx_objc_hook_t *hook);
Class tnx_owner_class(Class cls, SEL sel);

#endif
