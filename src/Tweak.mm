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

#define IMAGE_BASE          0x100000000ULL
#define RVA_RECEIVE_MESSAGE 0x75cce0

static intptr_t  gSlide = 0;
static NSString *gMainBinaryName = nil;
static BOOL      gRWXWorks = NO;
static BOOL      gRXRestoreWorks = NO;

typedef void (*MSHookFunction_t)(void *symbol, void *hook, void **old);
static MSHookFunction_t MSHookFunction_p = nullptr;

static void (*orig_receiveMessage)(void *self, void *msg) = nullptr;

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

static void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    NSLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        if (base.length) return base;
    }
    return nil;
}

static intptr_t OXFindSlide(NSString *name) {
    const char *target = name.UTF8String;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        const char *base = basename((char *)imgName);
        if (strcmp(base, target) != 0) continue;
        const struct mach_header *hdr = _dyld_get_image_header(i);
        uint32_t magic = 0;
        if (hdr) memcpy(&magic, hdr, 4);
        if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) {
            return _dyld_get_image_vmaddr_slide(i);
        }
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
    uint64_t rt = IMAGE_BASE + RVA_RECEIVE_MESSAGE + gSlide;
    NSLog(@"=== PERM TEST ===");
    NSLog(@"[test] target rt=0x%llx", rt);

    OXLogProt("initial", rt);

    kern_return_t kr = vm_protect(mach_task_self(),
                                  (vm_address_t)rt, 4, FALSE,
                                  VM_PROT_READ | VM_PROT_WRITE);
    NSLog(@"[test1] vm_protect RW -> kr=0x%x", kr);
    OXLogProt("after RW", rt);

    kr = vm_protect(mach_task_self(),
                    (vm_address_t)rt, 4, FALSE,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    NSLog(@"[test2] vm_protect RWX -> kr=0x%x", kr);
    OXLogProt("after RWX", rt);

    kr = vm_protect(mach_task_self(),
                    (vm_address_t)rt, 4, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    NSLog(@"[test3] vm_protect RX -> kr=0x%x", kr);
    OXLogProt("after RX", rt);

    uint32_t nop = 0xd503201f;
    uint32_t backup = 0xa9bf7bfd;
    kr = vm_write(mach_task_self(),
                  (vm_address_t)rt,
                  (vm_offset_t)&nop, 4);
    NSLog(@"[test4] vm_write NOP -> kr=0x%x", kr);

    uint32_t after = 0;
    vm_size_t out = 0;
    vm_read_overwrite(mach_task_self(), (vm_address_t)rt, 4,
                      (vm_address_t)&after, &out);
    NSLog(@"[test4] after write = %08x (want d503201f)", after);

    kr = vm_protect(mach_task_self(),
                    (vm_address_t)rt, 4, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    NSLog(@"[test5] vm_protect setMax=true RWX -> kr=0x%x", kr);
    OXLogProt("after setMax RWX", rt);

    vm_write(mach_task_self(), (vm_address_t)rt,
             (vm_offset_t)&backup, 4);
    vm_protect(mach_task_self(), (vm_address_t)rt, 4, FALSE,
               VM_PROT_READ | VM_PROT_EXECUTE);
    OXLogProt("final", rt);

    gRWXWorks = (OXGetProt(rt) & VM_PROT_EXECUTE) &&
                (OXGetProt(rt) & VM_PROT_WRITE);

    NSLog(@"=== PERM TEST DONE RWX=%d ===", gRWXWorks);
}

static BOOL OXTryPthreadJIT(void) {
    uint64_t rt = IMAGE_BASE + RVA_RECEIVE_MESSAGE + gSlide;
    void *fn = (void *)pthread_jit_write_protect_np;
    if (!fn) return NO;

    pthread_jit_write_protect_np(0);
    vm_prot_t p = OXGetProt(rt);
    pthread_jit_write_protect_np(1);

    NSLog(@"[pthread] prot=0x%x (RW? %d, RX? %d)",
          p, (p & VM_PROT_WRITE) ? 1 : 0, (p & VM_PROT_EXECUTE) ? 1 : 0);

    return (p & VM_PROT_WRITE) != 0;
}

static void OXInstallHook(void) {
    if (!MSHookFunction_p) {
        MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    }
    if (!MSHookFunction_p) {
        NSLog(@"[hook] MSHookFunction not found");
        return;
    }

    uint64_t rt = IMAGE_BASE + RVA_RECEIVE_MESSAGE + gSlide;
    NSLog(@"[hook] installing at 0x%llx", rt);

    if (gRWXWorks) {
        NSLog(@"[hook] path=RWX");
        MSHookFunction_p((void *)rt, (void *)hook_receiveMessage, (void **)&orig_receiveMessage);
        NSLog(@"[hook] MSHookFunction done");
        return;
    }

    if (OXTryPthreadJIT()) {
        NSLog(@"[hook] path=pthread_jit_write_protect_np");
        pthread_jit_write_protect_np(0);
        MSHookFunction_p((void *)rt, (void *)hook_receiveMessage, (void **)&orig_receiveMessage);
        pthread_jit_write_protect_np(1);
        NSLog(@"[hook] MSHookFunction done (pthread)");
        return;
    }

    NSLog(@"[hook] no writable+executable path available");
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

        gSlide = OXFindSlide(gMainBinaryName);
        NSLog(@"[Tale] main=%@ slide=0x%lx", gMainBinaryName, (long)gSlide);

        OXTestPermissions();

        if (gRWXWorks || OXTryPthreadJIT()) {
            OXInstallHook();
        }

        NSLog(@"[Tale] === DONE ===");
    });
}