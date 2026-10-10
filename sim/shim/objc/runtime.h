#ifndef SIM_OBJC_RUNTIME_H
#define SIM_OBJC_RUNTIME_H
#include <stdint.h>
#include <stddef.h>
typedef struct objc_object *id;
typedef struct objc_selector *SEL;
typedef struct objc_class *Class;
typedef struct objc_method *Method;
typedef struct objc_ivar *Ivar;
typedef struct objc_property *objc_property_t;
Class objc_getClass(const char *name);
SEL sel_registerName(const char *name);
const char *sel_getName(SEL sel);
Method class_getInstanceMethod(Class cls, SEL name);
Method class_getClassMethod(Class cls, SEL name);
void method_setImplementation(Method m, void (*imp)(void));
void *method_getImplementation(Method m);
#endif
