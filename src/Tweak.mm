#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libgen.h>
#import <dlfcn.h>
#import <pthread.h>

#define RVA_MM_RECEIVEMESSAGE 0x75cce0
#define RVA_MM_CTOR           0x75bb1c
#define VT_MM                 0xfd57e8

static NSString *gImageName = nil;
static uint64_t gRuntimeAddr = 0;
static uint64_t gCtorAddr = 0;
static uint64_t gVtableAddr = 0;

static void *gMMInstance = NULL;
static void (*orig_receiveMessage)(void *self, void *msg) = nullptr;
static void (*orig_ctor)(void *self) = nullptr;

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
        if (strstr(n, "/Documents/Tweaks/")) continue;
        if (strstr(n, "/Tweaks/")) continue;

        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;
        if (hdr->filetype != MH_EXECUTE) continue;

        return [NSString stringWithUTF8String:basename((char *)n)];
    }
    return nil;
}

static uint64_t OXResolveRuntimeAddr(NSString *imageName, uint64_t rva) {
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

static BOOL OXSafRead64(uint64_t addr, uint64_t *out) {
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)addr, 8, (vm_address_t)out, &outSize);
    return (kr == KERN_SUCCESS && outSize == 8);
}

static BOOL OXSafRead32(uint64_t addr, uint32_t *out) {
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)addr, 4, (vm_address_t)out, &outSize);
    return (kr == KERN_SUCCESS && outSize == 4);
}

static void hook_receiveMessage(void *self, void *msg) {
    if (msg) {
        uint32_t vt = 0;
        if (OXSafRead32((uint64_t)msg, &vt) && vt) {
            uint64_t getTypeAddr = 0;
            if (OXSafRead64((uint64_t)vt + 40, &getTypeAddr) && getTypeAddr) {
                typedef int (*GetTypeFn)(void *);
                GetTypeFn getType = (GetTypeFn)getTypeAddr;
                int type = getType(msg);
                if (type == 20103) {
                    int subtype = 0;
                    OXSafRead32((uint64_t)msg + 144, (uint32_t *)&subtype);
                    if (subtype == 8) {
                        NSLog(@"[Tale] news popup caught");
                    }
                }
            }
        }
    }
    if (orig_receiveMessage) orig_receiveMessage(self, msg);
}

static void hook_ctor(void *self) {
    if (!gMMInstance && self) {
        gMMInstance = self;
        NSLog(@"[Tale] MessageManager instance = %p", self);
    }
    if (orig_ctor) orig_ctor(self);
}

static void OXDumpVtable(void) {
    if (!gVtableAddr) return;
    NSLog(@"=== VTABLE 0x%llx ===", gVtableAddr);
    for (int i = 0; i < 4; i++) {
        uint64_t slot = 0;
        if (OXSafRead64(gVtableAddr + i * 8, &slot)) {
            NSLog(@"[vt] slot[%d] = 0x%llx", i, slot);
        } else {
            NSLog(@"[vt] slot[%d] = <unreadable>", i);
            break;
        }
    }
}

static void OXInstallHooks(void) {
    void *sym = dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (!sym) {
        NSLog(@"[hook] MSHookFunction not found");
        return;
    }
    typedef void (*MSHookFunction_t)(void *, void *, void **);
    MSHookFunction_t mshook = (MSHookFunction_t)sym;

    if (gCtorAddr) {
        NSLog(@"[hook] hooking ctor at 0x%llx", gCtorAddr);
        mshook((void *)gCtorAddr, (void *)hook_ctor, (void **)&orig_ctor);
        NSLog(@"[hook] ctor done");
    }
    if (gRuntimeAddr) {
        NSLog(@"[hook] hooking receiveMessage at 0x%llx", gRuntimeAddr);
        mshook((void *)gRuntimeAddr, (void *)hook_receiveMessage, (void **)&orig_receiveMessage);
        NSLog(@"[hook] receiveMessage done");
    }
}

__attribute__((constructor))
static void initMod(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gImageName = OXDetectGameImageName();
        if (!gImageName) {
            NSLog(@"[Tale] game image not found");
            return;
        }
        NSLog(@"[Tale] image=%@", gImageName);

        gRuntimeAddr = OXResolveRuntimeAddr(gImageName, RVA_MM_RECEIVEMESSAGE);
        gCtorAddr    = OXResolveRuntimeAddr(gImageName, RVA_MM_CTOR);
        gVtableAddr  = OXResolveRuntimeAddr(gImageName, VT_MM);

        NSLog(@"[Tale] receiveMessage=0x%llx ctor=0x%llx vtable=0x%llx",
              gRuntimeAddr, gCtorAddr, gVtableAddr);

        OXDumpVtable();
        OXInstallHooks();

        NSLog(@"[Tale] === Done ===");
    });
}