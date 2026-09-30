#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libgen.h>
#import <dlfcn.h>
#import <pthread.h>
#import <sys/mman.h>

#define RVA_MM_RECEIVEMESSAGE 0x75cce0
#define RVA_MM_CTOR           0x75bb1c
#define VT_MM                 0xfd57e8

static intptr_t  gSlide = 0;
static uint64_t  gRuntimeAddr = 0;
static uint64_t  gCtorAddr = 0;
static uint64_t  gVtableAddr = 0;
static NSString *gMainBinaryName = nil;
static BOOL      gRWXWorks = NO;

static void *gMessageManagerInstance = NULL;

typedef void (*MSHookFunction_t)(void *symbol, void *hook, void **old);
static MSHookFunction_t MSHookFunction_p = nullptr;

typedef void (*pthread_jit_write_protect_np_t)(int);
static pthread_jit_write_protect_np_t p_jit_wp = nullptr;

static void (*orig_receiveMessage)(void *self, void *msg) = nullptr;
static void (*orig_ctor)(void *self) = nullptr;

static void hook_receiveMessage(void *self, void *msg) {
    if (msg) {
        uint32_t vt = *(uint32_t *)((uintptr_t)msg);
        if (vt) {
            typedef int (*GetTypeFn)(void *);
            GetTypeFn getType = (GetTypeFn)(*(uintptr_t *)vt + 40);
            if (getType) {
                int type = getType(msg);
                if (type == 20103) {
                    int subtype = *(int *)((uintptr_t)msg + 144);
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
    if (!gMessageManagerInstance && self) {
        gMessageManagerInstance = self;
        NSLog(@"[Tale] MessageManager instance saved = %p", self);
    }
    if (orig_ctor) orig_ctor(self);
}

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        if (base.length) return base;
    }
    return nil;
}

static uint64_t OXResolveRuntimeAddr(NSString *imageName, uint64_t rva) {
    const char *target = imageName.UTF8String;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n || strcmp(basename((char *)n), target) != 0) continue;
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        return (uint64_t)hdr + slide + (rva - 0x100000000ULL);
    }
    return 0;
}

static vm_prot_t OXGetProt(uint64_t addr) {
    vm_address_t region = (vm_address_t)addr;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(), &region, &regionSize,
                                     VM_REGION_BASIC_INFO_64,
                                     (vm_region_info_t)&info, &infoCount,
                                     &objectName);
    if (kr != KERN_SUCCESS) return 0;
    return info.protection;
}

static void OXLogProt(const char *tag, uint64_t addr) {
    vm_prot_t p = OXGetProt(addr);
    const char *r = (p & VM_PROT_READ)    ? "r" : "-";
    const char *w = (p & VM_PROT_WRITE)   ? "w" : "-";
    const char *x = (p & VM_PROT_EXECUTE) ? "x" : "-";
    NSLog(@"[prot] %s: %s%s%s (0x%x)", tag, r, w, x, p);
}

static void OXTestPermissions(void) {
    uint64_t rt = gRuntimeAddr;
    NSLog(@"=== PERM TEST rt=0x%llx ===", rt);
    OXLogProt("initial", rt);

    kern_return_t kr;

    kr = vm_protect(mach_task_self(), (vm_address_t)rt, 4, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE);
    NSLog(@"[t1] RW setMax=1 -> 0x%x", kr);
    OXLogProt("after RW", rt);

    kr = vm_protect(mach_task_self(), (vm_address_t)rt, 4, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    NSLog(@"[t2] RWX setMax=1 -> 0x%x", kr);
    OXLogProt("after RWX", rt);

    kr = vm_protect(mach_task_self(), (vm_address_t)rt, 4, TRUE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    NSLog(@"[t3] RX setMax=1 -> 0x%x", kr);
    OXLogProt("after RX", rt);

    uint32_t nop = 0xd503201f;
    uint32_t backup = 0xa9bf7bfd;

    kr = vm_write(mach_task_self(), (vm_address_t)rt, (vm_offset_t)&nop, 4);
    NSLog(@"[t4] vm_write -> 0x%x", kr);

    uint32_t after = 0;
    vm_size_t out = 0;
    vm_read_overwrite(mach_task_self(), (vm_address_t)rt, 4,
                      (vm_address_t)&after, &out);
    NSLog(@"[t4] after=%08x want=d503201f", after);

    vm_write(mach_task_self(), (vm_address_t)rt, (vm_offset_t)&backup, 4);
    vm_protect(mach_task_self(), (vm_address_t)rt, 4, TRUE,
               VM_PROT_READ | VM_PROT_EXECUTE);
    OXLogProt("final", rt);

    vm_prot_t p = OXGetProt(rt);
    gRWXWorks = (p & VM_PROT_EXECUTE) && (p & VM_PROT_WRITE);
    NSLog(@"=== DONE RWX=%d ===", gRWXWorks);
}

static BOOL OXTryPthreadJIT(void) {
    if (!gRuntimeAddr) return NO;

    if (!p_jit_wp) {
        p_jit_wp = (pthread_jit_write_protect_np_t)dlsym(RTLD_DEFAULT, "pthread_jit_write_protect_np");
    }
    if (!p_jit_wp) {
        NSLog(@"[pthread] pthread_jit_write_protect_np not found");
        return NO;
    }

    p_jit_wp(0);
    vm_prot_t p = OXGetProt(gRuntimeAddr);
    p_jit_wp(1);

    NSLog(@"[pthread] prot=0x%x (RW? %d, RX? %d)",
          p, (p & VM_PROT_WRITE) ? 1 : 0, (p & VM_PROT_EXECUTE) ? 1 : 0);

    return (p & VM_PROT_WRITE) != 0;
}

static void OXInstallHooks(void) {
    if (!gRuntimeAddr || !gCtorAddr) {
        NSLog(@"[hook] addresses not resolved");
        return;
    }

    if (!MSHookFunction_p) {
        MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    }
    if (!MSHookFunction_p) {
        NSLog(@"[hook] MSHookFunction not found");
        return;
    }

    BOOL canWrite = gRWXWorks || OXTryPthreadJIT();
    if (!canWrite) {
        NSLog(@"[hook] no writable+executable path available");
        return;
    }

    NSLog(@"[hook] path=%s", gRWXWorks ? "RWX" : "pthread_jit");

    if (gRWXWorks) {
        MSHookFunction_p((void *)gCtorAddr, (void *)hook_ctor, (void **)&orig_ctor);
        NSLog(@"[hook] ctor done");
        MSHookFunction_p((void *)gRuntimeAddr, (void *)hook_receiveMessage, (void **)&orig_receiveMessage);
        NSLog(@"[hook] receiveMessage done");
    } else {
        p_jit_wp(0);
        MSHookFunction_p((void *)gCtorAddr, (void *)hook_ctor, (void **)&orig_ctor);
        MSHookFunction_p((void *)gRuntimeAddr, (void *)hook_receiveMessage, (void **)&orig_receiveMessage);
        p_jit_wp(1);
        NSLog(@"[hook] both done via pthread_jit");
    }
}

static void OXDumpVtable(void) {
    if (!gVtableAddr) return;
    NSLog(@"=== VTABLE 0x%llx ===", gVtableAddr);
    for (int i = 0; i < 4; i++) {
        uint64_t slot = *(uint64_t *)(gVtableAddr + i * 8);
        NSLog(@"[vt] slot[%d] = 0x%llx", i, slot);
    }
}

__attribute__((constructor))
static void initMod(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        if (!gMainBinaryName) {
            NSLog(@"[Tale] main binary not detected");
            return;
        }

        NSLog(@"[Tale] main=%@", gMainBinaryName);

        gRuntimeAddr = OXResolveRuntimeAddr(gMainBinaryName, RVA_MM_RECEIVEMESSAGE);
        gCtorAddr    = OXResolveRuntimeAddr(gMainBinaryName, RVA_MM_CTOR);
        gVtableAddr  = OXResolveRuntimeAddr(gMainBinaryName, VT_MM);

        NSLog(@"[Tale] receiveMessage=0x%llx ctor=0x%llx vtable=0x%llx",
              gRuntimeAddr, gCtorAddr, gVtableAddr);

        OXDumpVtable();
        OXTestPermissions();
        OXInstallHooks();

        NSLog(@"[Tale] === DONE ===");
    });
}