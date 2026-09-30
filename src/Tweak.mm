#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <libgen.h>

typedef void (*MSHookMessageEx_t)(Class _class, SEL message, IMP hook, IMP *old);
static MSHookMessageEx_t MSHookMessageEx_p = nullptr;

typedef void (*litehook_hook_function_t)(void *target, void *replacement, void **original);
static litehook_hook_function_t litehook_hook_function_p = nullptr;

static int g_receiveMessage_count = 0;
static IMP g_original_receiveMessage = NULL;

static void my_receiveMessage(id self, SEL _cmd, id msg) {
    g_receiveMessage_count++;
    NSLog(@"[TaleMod] receiveMessage #%d self=%p msg=%p",
          g_receiveMessage_count, self, msg);
    if (g_original_receiveMessage) {
        ((void (*)(id, SEL, id))g_original_receiveMessage)(self, _cmd, msg);
    }
}

static void install_hooks(void) {
    NSLog(@"[TaleMod] === install hooks ===");

    MSHookMessageEx_p = (MSHookMessageEx_t)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (!MSHookMessageEx_p) {
        NSLog(@"[TaleMod] MSHookMessageEx not found");
        return;
    }
    NSLog(@"[TaleMod] MSHookMessageEx = %p", MSHookMessageEx_p);

    Class messageManagerClass = objc_getClass("MessageManager");
    if (messageManagerClass) {
        NSLog(@"[TaleMod] MessageManager class found");
        MSHookMessageEx_p(messageManagerClass,
                          @selector(receiveMessage:),
                          (IMP)my_receiveMessage,
                          &g_original_receiveMessage);
        NSLog(@"[TaleMod] hook installed on -[MessageManager receiveMessage:]");
    } else {
        NSLog(@"[TaleMod] MessageManager class not found");
    }

    litehook_hook_function_p = (litehook_hook_function_t)dlsym(RTLD_DEFAULT, "litehook_hook_function");
    if (litehook_hook_function_p) {
        NSLog(@"[TaleMod] litehook_hook_function = %p", litehook_hook_function_p);
    } else {
        NSLog(@"[TaleMod] litehook_hook_function not found");
    }

    NSLog(@"[TaleMod] === install done ===");
}

__attribute__((constructor))
static void tweak_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[TaleMod] init");
        install_hooks();
        NSLog(@"[TaleMod] === done ===");
    });
}