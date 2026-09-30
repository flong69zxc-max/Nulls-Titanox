#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <libgen.h>
#import <string.h>
#import <stdio.h>
#import <stdarg.h>

#define RVA_MM_RECEIVEMESSAGE 0x75cce0
#define RVA_MM_CTOR           0x75bb1c
#define HOOK_RECEIVE 1
#define HOOK_CTOR    0

typedef void (*MSHookFunction_t)(void *symbol, void *hook, void **old);
static MSHookFunction_t MSHookFunction_p = nullptr;

typedef kern_return_t (*vm_protect_t)(vm_map_t, vm_address_t, vm_size_t, boolean_t, vm_prot_t);
static vm_protect_t builtin_vm_protect = nullptr;

typedef void (*recv_t)(void*, void*, void*, void*, void*, void*);
static recv_t orig_recv = NULL;

static int g_recv_count = 0;
static FILE *g_logf = NULL;

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    NSLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static void TaleLogOpen(void) {
    if (g_logf) return;
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"talemod.log"];
    g_logf = fopen(path.UTF8String, "w");
}

static void TaleLog(const char *fmt, ...) {
    if (!g_logf) TaleLogOpen();
    if (!g_logf) return;
    va_list ap; va_start(ap, fmt); vfprintf(g_logf, fmt, ap); fputc('\n', g_logf); va_end(ap); fflush(g_logf);
}

static NSString *OXDetectGameImageName(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "/NB.app/") && !strstr(n, "/Frameworks/")) return [NSString stringWithUTF8String:basename((char *)n)];
    }
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n) continue;
        if (strstr(n, "LiveContainer") || strstr(n, "SideStore") || strstr(n, "/Frameworks/") || strstr(n, "/System/") || strstr(n, "/usr/") || strstr(n, "/private/preboot/") || strstr(n, "/Tweaks/")) continue;
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr || (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64) || hdr->filetype != MH_EXECUTE) continue;
        return [NSString stringWithUTF8String:basename((char *)n)];
    }
    return nil;
}

static uint64_t OXResolve(NSString *imageName, uint64_t rva) {
    if (!imageName) return 0;
    const char *target = imageName.UTF8String;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n || strcmp(basename((char *)n), target) != 0) continue;
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr || (hdr->magic != MH_MAGIC_64 && hdr->magic != MH_CIGAM_64)) continue;
        return (uint64_t)hdr + rva;
    }
    return 0;
}

// Улучшенная проверка JIT
static BOOL OXCheckJIT(uint64_t addr) {
    TaleLog("[TaleMod] Checking JIT for addr 0x%llx", addr);
    
    // Проверка 1: Текущие права
    vm_address_t region = (vm_address_t)addr;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t obj = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj);
    
    if (kr != KERN_SUCCESS) {
        TaleLog("[TaleMod] vm_region failed: 0x%x", kr);
        return NO;
    }
    
    vm_prot_t prot = info.protection;
    TaleLog("[TaleMod] Current protection: %c%c%c (0x%x)", 
            (prot & VM_PROT_READ) ? 'r' : '-', 
            (prot & VM_PROT_WRITE) ? 'w' : '-', 
            (prot & VM_PROT_EXECUTE) ? 'x' : '-', prot);

    // Проверка 2: Пытаемся сделать страницу RW
    if (!builtin_vm_protect) {
        builtin_vm_protect = (vm_protect_t)dlsym(RTLD_DEFAULT, "builtin_vm_protect");
    }
    
    kern_return_t krw = KERN_FAILURE;
    if (builtin_vm_protect) {
        TaleLog("[TaleMod] Trying builtin_vm_protect...");
        krw = builtin_vm_protect(mach_task_self(), (vm_address_t)addr, 4, TRUE, VM_PROT_READ | VM_PROT_WRITE);
    } else {
        TaleLog("[TaleMod] builtin_vm_protect not found, trying vm_protect...");
        krw = vm_protect(mach_task_self(), (vm_address_t)addr, 4, TRUE, VM_PROT_READ | VM_PROT_WRITE);
    }
    
    TaleLog("[TaleMod] vm_protect RW -> 0x%x", krw);

    // Проверка 3: Проверяем, что права реально изменились
    region = (vm_address_t)addr;
    size = 0; cnt = VM_REGION_BASIC_INFO_COUNT_64; obj = MACH_PORT_NULL;
    kr = vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj);
    
    if (kr == KERN_SUCCESS) {
        vm_prot_t new_prot = info.protection;
        TaleLog("[TaleMod] After protect: %c%c%c (0x%x)", 
                (new_prot & VM_PROT_READ) ? 'r' : '-', 
                (new_prot & VM_PROT_WRITE) ? 'w' : '-', 
                (new_prot & VM_PROT_EXECUTE) ? 'x' : '-', new_prot);
        
        // Восстанавливаем права
        if (builtin_vm_protect) builtin_vm_protect(mach_task_self(), (vm_address_t)addr, 4, TRUE, VM_PROT_READ | VM_PROT_EXECUTE);
        else vm_protect(mach_task_self(), (vm_address_t)addr, 4, TRUE, VM_PROT_READ | VM_PROT_EXECUTE);

        if (new_prot & VM_PROT_WRITE) {
            TaleLog("[TaleMod] JIT is available (RW works)");
            return YES;
        } else {
            TaleLog("[TaleMod] JIT NOT available (RW failed, page stayed r-x)");
            return NO;
        }
    }
    
    return NO;
}

static void my_recv(void *a, void *b, void *c, void *d, void *e, void *f) {
    static __thread int guard = 0;
    if (guard) { if (orig_recv) orig_recv(a,b,c,d,e,f); return; }
    guard = 1;
    if (g_recv_count < 20) {
        g_recv_count++;
        TaleLog("[TaleMod] recv #%d self=%p msg=%p", g_recv_count, a, b);
    }
    if (orig_recv) orig_recv(a,b,c,d,e,f);
    guard = 0;
}

static void install_hooks(void) {
    TaleLog("[TaleMod] === install hooks ===");

    MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (!MSHookFunction_p) { TaleLog("[TaleMod] MSHookFunction NOT FOUND"); return; }

    NSString *img = OXDetectGameImageName();
    if (!img) { TaleLog("[TaleMod] game image not found"); return; }
    TaleLog("[TaleMod] image=%s", img.UTF8String);

    uint64_t recvAddr = OXResolve(img, RVA_MM_RECEIVEMESSAGE);
    if (!recvAddr) { TaleLog("[TaleMod] recv addr is 0"); return; }

    if (!OXCheckJIT(recvAddr)) {
        TaleLog("[TaleMod] ABORT: JIT not available, skipping hook");
        return;
    }

    TaleLog("[TaleMod] Installing recv hook...");
    MSHookFunction_p((void *)recvAddr, (void *)my_recv, (void **)&orig_recv);
    TaleLog("[TaleMod] recv hooked, orig=%p", orig_recv);
    TaleLog("[TaleMod] === install done ===");
}

__attribute__((constructor))
static void tweak_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TaleLog("[TaleMod] init");
        install_hooks();
        TaleLog("[TaleMod] === done ===");
    });
}