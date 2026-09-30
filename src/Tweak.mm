#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libgen.h>
#import <dlfcn.h>
#import "libtitanox.h"

#define RVA_MM_RECEIVEMESSAGE 0x75cce0
#define RVA_MM_CTOR           0x75bb1c

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    THLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static NSString *gImageName = nil;
static uint64_t gRuntimeAddr = 0;
static uint64_t gCtorAddr = 0;

static void (*orig_receiveMessage)(void *self, void *msg) = NULL;
static void (*orig_ctor)(void *self) = NULL;

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
        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;
        if (hdr->filetype != MH_EXECUTE && hdr->filetype != MH_DYLIB) continue;
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
        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        if (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) continue;
        return (uint64_t)hdr + rva;
    }
    return 0;
}

static vm_prot_t OXProt(uint64_t addr) {
    vm_address_t region = (vm_address_t)addr;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t obj = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(), &region, &size,
                                     VM_REGION_BASIC_INFO_64,
                                     (vm_region_info_t)&info, &cnt, &obj);
    if (kr != KERN_SUCCESS) return 0;
    return info.protection;
}

static BOOL OXIsExecutable(uint64_t addr) {
    return (OXProt(addr) & VM_PROT_EXECUTE) != 0;
}

static void OXLogProt(const char *tag, uint64_t addr) {
    vm_prot_t p = OXProt(addr);
    THLog(@"[prot] %s 0x%llx = %c%c%c (0x%x)",
          tag, addr,
          (p & VM_PROT_READ)    ? 'r' : '-',
          (p & VM_PROT_WRITE)   ? 'w' : '-',
          (p & VM_PROT_EXECUTE) ? 'x' : '-',
          p);
}

typedef void (*MSHookFunction_t)(void *, void *, void **);

static MSHookFunction_t OXFindMSHook(void) {
    const char *names[] = {
        "MSHookFunction",
        "MSHookFunction_ptr",
        "_MSHookFunction",
    };
    for (int i = 0; i < 3; i++) {
        void *sym = dlsym(RTLD_DEFAULT, names[i]);
        if (sym) {
            THLog(@"[mshook] found %s -> %p", names[i], sym);
            return (MSHookFunction_t)sym;
        }
    }

    const char *libs[] = {
        "/var/jb/usr/lib/libsubstrate.dylib",
        "/var/jb/usr/lib/libellekit.dylib",
        "/usr/lib/libsubstrate.dylib",
        "/usr/lib/libellekit.dylib",
        "/var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
        "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
    };
    for (int i = 0; i < 6; i++) {
        void *h = dlopen(libs[i], RTLD_NOW | RTLD_NOLOAD);
        if (!h) continue;
        void *sym = dlsym(h, "MSHookFunction");
        if (sym) {
            THLog(@"[mshook] loaded %s -> %p", libs[i], sym);
            return (MSHookFunction_t)sym;
        }
    }

    THLog(@"[mshook] MSHookFunction NOT FOUND anywhere");
    return NULL;
}

static void hook_receiveMessage(void *self, void *msg) {
    THLog(@"[Tale] receiveMessage called self=%p msg=%p", self, msg);
    if (orig_receiveMessage) orig_receiveMessage(self, msg);
}

static void hook_ctor(void *self) {
    THLog(@"[Tale] MessageManager::ctor called self=%p", self);
    if (orig_ctor) orig_ctor(self);
}

static void OXHookOne(MSHookFunction_t mshook,
                      const char *name,
                      uint64_t addr,
                      void *hook,
                      void **orig)
{
    THLog(@"[hook] %s addr=0x%llx", name, addr);
    if (!addr) {
        THLog(@"[hook] %s SKIP — addr=0", name);
        return;
    }
    OXLogProt(name, addr);

    if (!OXIsExecutable(addr)) {
        THLog(@"[hook] %s SKIP — not executable region", name);
        return;
    }

    mshook((void *)addr, hook, orig);
    THLog(@"[hook] %s installed, orig=%p", name, orig ? *orig : NULL);
}

__attribute__((constructor))
static void initMod(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        THLog(@"=== TALE MOD v1 ===");

        gImageName = OXDetectGameImageName();
        if (!gImageName) {
            THLog(@"[Tale] image not found");
            for (uint32_t i = 0; i < _dyld_image_count(); i++) {
                const char *n = _dyld_get_image_name(i);
                if (n) THLog(@"[img] %s", n);
            }
            return;
        }
        THLog(@"[Tale] image=%@", gImageName);

        gRuntimeAddr = OXResolve(gImageName, RVA_MM_RECEIVEMESSAGE);
        gCtorAddr    = OXResolve(gImageName, RVA_MM_CTOR);

        THLog(@"[Tale] rcv=0x%llx ctor=0x%llx", gRuntimeAddr, gCtorAddr);

        MSHookFunction_t mshook = OXFindMSHook();
        if (!mshook) {
            THLog(@"[Tale] MSHookFunction not available — cannot hook");
            return;
        }

        OXHookOne(mshook, "ctor", gCtorAddr,
                  (void *)hook_ctor, (void **)&orig_ctor);
        OXHookOne(mshook, "receiveMessage", gRuntimeAddr,
                  (void *)hook_receiveMessage, (void **)&orig_receiveMessage);

        THLog(@"[Tale] === Done ===");
    });
}