#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libgen.h>

#define RVA_MM_RECEIVEMESSAGE 0x75cce0

typedef void (*MSHookMessageEx_t)(Class _class, SEL message, IMP hook, IMP *old);
static MSHookMessageEx_t MSHookMessageEx_p = nullptr;

typedef void (*litehook_hook_function_t)(void *target, void *replacement, void **original);
static litehook_hook_function_t litehook_hook_function_p = nullptr;

static int g_receiveMessage_count = 0;
static IMP g_original_receiveMessage = NULL;

static void (*g_original_receiveMessage_cpp)(void *self, void *msg) = NULL;
static int g_receiveMessage_cpp_count = 0;

static uint64_t gRuntimeAddr = 0;
static NSString *gImageName = nil;

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    NSLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static NSString *OXDetectGameImageName(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (strstr(n, "/NB.app/") && !strstr(n, "/Frameworks/")) {
            return [NSString stringWithUTF8String:basename((char *)n)];
        }
    }
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (strstr(n, "LiveContainer")) continue;
        if (strstr(n, "SideStore")) continue;
        if (strstr(n, "/Frameworks/")) continue;
        if (strstr(n, "/System/")) continue;
        if (strstr(n, "/usr/")) continue;
        if (strstr(n, "/private/preboot/")) continue;
        if (strstr(n, "/Tweaks/")) continue;
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;
        if (hdr->filetype != MH_EXECUTE) continue;
        return [NSString stringWithUTF8String:basename((char *)n)];
    }
    return nil;
}

static uint64_t OXResolve(NSString *imageName, uint64_t rva) {
    if (!imageName) return 0;
    const char *target = imageName.UTF8String;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (strcmp(basename((char *)n), target) != 0) continue;
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;
        return (uint64_t)hdr + rva;
    }
    return 0;
}

static void my_receiveMessage_objc(id self, SEL _cmd, id msg) {
    g_receiveMessage_count++;
    NSLog(@"[TaleMod] objc receiveMessage #%d self=%p msg=%p",
          g_receiveMessage_count, self, msg);
    if (g_original_receiveMessage) {
        ((void (*)(id, SEL, id))g_original_receiveMessage)(self, _cmd, msg);
    }
}

static void my_receiveMessage_cpp(void *self, void *msg) {
    g_receiveMessage_cpp_count++;
    NSLog(@"[TaleMod] cpp receiveMessage #%d self=%p msg=%p",
          g_receiveMessage_cpp_count, self, msg);
    if (g_original_receiveMessage_cpp) {
        g_original_receiveMessage_cpp(self, msg);
    }
}

static BOOL OXIsExecutable(uint64_t addr) {
    vm_address_t region = (vm_address_t)addr;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t obj = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(), &region, &size,
                                     VM_REGION_BASIC_INFO_64,
                                     (vm_region_info_t)&info, &cnt, &obj);
    if (kr != KERN_SUCCESS) return NO;
    return (info.protection & VM_PROT_EXECUTE) != 0;
}

static void OXLogProt(const char *tag, uint64_t addr) {
    vm_address_t region = (vm_address_t)addr;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t obj = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(), &region, &size,
                                     VM_REGION_BASIC_INFO_64,
                                     (vm_region_info_t)&info, &cnt, &obj);
    if (kr != KERN_SUCCESS) {
        NSLog(@"[prot] %s 0x%llx = <unreadable>", tag, addr);
        return;
    }
    vm_prot_t p = info.protection;
    NSLog(@"[prot] %s 0x%llx = %c%c%c (0x%x)",
          tag, addr,
          (p & VM_PROT_READ)    ? 'r' : '-',
          (p & VM_PROT_WRITE)   ? 'w' : '-',
          (p & VM_PROT_EXECUTE) ? 'x' : '-',
          p);
}

static void install_hooks(void) {
    NSLog(@"[TaleMod] === install hooks ===");

    MSHookMessageEx_p = (MSHookMessageEx_t)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (MSHookMessageEx_p) {
        NSLog(@"[TaleMod] MSHookMessageEx = %p", MSHookMessageEx_p);
    } else {
        NSLog(@"[TaleMod] MSHookMessageEx not found");
    }

    litehook_hook_function_p = (litehook_hook_function_t)dlsym(RTLD_DEFAULT, "litehook_hook_function");
    if (litehook_hook_function_p) {
        NSLog(@"[TaleMod] litehook_hook_function = %p", litehook_hook_function_p);
    } else {
        NSLog(@"[TaleMod] litehook_hook_function not found");
    }

    gImageName = OXDetectGameImageName();
    if (!gImageName) {
        NSLog(@"[TaleMod] game image not found");
        return;
    }
    NSLog(@"[TaleMod] image=%@", gImageName);

    gRuntimeAddr = OXResolve(gImageName, RVA_MM_RECEIVEMESSAGE);
    NSLog(@"[TaleMod] receiveMessage cpp addr = 0x%llx", gRuntimeAddr);
    OXLogProt("receiveMessage", gRuntimeAddr);

    Class messageManagerClass = objc_getClass("MessageManager");
    if (messageManagerClass && MSHookMessageEx_p) {
        NSLog(@"[TaleMod] MessageManager ObjC class found, hooking via MSHookMessageEx");
        MSHookMessageEx_p(messageManagerClass,
                          @selector(receiveMessage:),
                          (IMP)my_receiveMessage_objc,
                          &g_original_receiveMessage);
        NSLog(@"[TaleMod] objc hook installed");
    } else {
        NSLog(@"[TaleMod] MessageManager not an ObjC class, trying C++ path");
        if (!litehook_hook_function_p) {
            NSLog(@"[TaleMod] litehook not available, cannot hook C++");
        } else if (!gRuntimeAddr) {
            NSLog(@"[TaleMod] runtime addr is 0");
        } else if (!OXIsExecutable(gRuntimeAddr)) {
            NSLog(@"[TaleMod] target not in executable region, skip");
        } else {
            litehook_hook_function_p((void *)gRuntimeAddr,
                                     (void *)my_receiveMessage_cpp,
                                     (void **)&g_original_receiveMessage_cpp);
            NSLog(@"[TaleMod] cpp hook installed at 0x%llx", gRuntimeAddr);
        }
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