#ifndef SIM_DISPATCH_H
#define SIM_DISPATCH_H
#include <stddef.h>
typedef struct dispatch_object_s *dispatch_object_t;
typedef dispatch_object_t dispatch_queue_t;
typedef dispatch_object_t dispatch_source_t;
typedef void (*dispatch_source_handler_t)(void *);
typedef void (*dispatch_block_t)(void);
typedef void (*dispatch_function_t)(void *);
#define DISPATCH_QUEUE_SERIAL ((dispatch_queue_t)0)
extern "C" dispatch_queue_t dispatch_get_main_queue(void);
extern "C" dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
extern "C" dispatch_queue_t dispatch_queue_create(const char *label, void *attr);
extern "C" void dispatch_async(dispatch_queue_t q, dispatch_block_t b);
extern "C" void dispatch_sync(dispatch_queue_t q, dispatch_block_t b);
extern "C" void dispatch_after(unsigned long long when, dispatch_queue_t q, dispatch_block_t b);
extern "C" void dispatch_async_f(dispatch_queue_t q, void *ctx, dispatch_function_t f);
#endif
