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

typedef void (*recv_t)(void*, void*, void*, void*, void*, void*);
static recv_t orig_recv = NULL;

typedef void (*ctor_t)(void*, void*, void*, void*, void*, void*);
static ctor_t orig_ctor = NULL;

static int g_recv_count = 0;
static int g_ctor_count = 0;
static void *g_mm_instance = NULL;

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    NSLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static void TaleLog(const char *fmt, ...) {
    const char *path = getenv("TALEMOD_LOG");
    if (!path) path = "/tmp/talemod.log";
    FILE *f = fopen(path, "a");
    if (!f) return;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    fputc('\n', f);
    va_end(ap);
    fclose(f);
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

static void my_recv(void *a, void *b, void *c, void *d, void *e, void *f) {
    static __thread int guard = 0;
    if (guard) {
        if (orig_recv) orig_recv(a, b, c, d, e, f);
        return;
    }
    guard = 1;

    if (g_recv_count < 20) {
        g_recv_count++;
        TaleLog("[TaleMod] recv #%d self=%p msg=%p", g_recv_count, a, b);
    }

    if (orig_recv) orig_recv(a, b, c, d, e, f);
    guard = 0;
}

static void my_ctor(void *a, void *b, void *c, void *d, void *e, void *f) {
    static __thread int guard = 0;
    if (guard) {
        if (orig_ctor) orig_ctor(a, b, c, d, e, f);
        return;
    }
    guard = 1;

    if (!g_mm_instance && a) {
        g_mm_instance = a;
        TaleLog("[TaleMod] MessageManager instance = %p", a);
    }

    if (orig_ctor) orig_ctor(a, b, c, d, e, f);
    guard = 0;
}

static void install_hooks(void) {
    TaleLog("[TaleMod] === install hooks ===");

    MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (!MSHookFunction_p) {
        TaleLog("[TaleMod] MSHookFunction not found");
        return;
    }
    TaleLog("[TaleMod] MSHookFunction = %p", MSHookFunction_p);

    NSString *img = OXDetectGameImageName();
    if (!img) {
        TaleLog("[TaleMod] game image not found");
        return;
    }
    TaleLog("[TaleMod] image=%s", img.UTF8String);

    uint64_t recvAddr = OXResolve(img, RVA_MM_RECEIVEMESSAGE);
    uint64_t ctorAddr = OXResolve(img, RVA_MM_CTOR);
    TaleLog("[TaleMod] recv=0x%llx ctor=0x%llx", recvAddr, ctorAddr);

#if HOOK_RECEIVE
    if (recvAddr) {
        MSHookFunction_p((void *)recvAddr, (void *)my_recv, (void **)&orig_recv);
        TaleLog("[TaleMod] recv hooked, orig=%p", orig_recv);
    }
#endif

#if HOOK_CTOR
    if (ctorAddr) {
        MSHookFunction_p((void *)ctorAddr, (void *)my_ctor, (void **)&orig_ctor);
        TaleLog("[TaleMod] ctor hooked, orig=%p", orig_ctor);
    }
#endif

    TaleLog("[TaleMod] === install done ===");
}

__attribute__((constructor))
static void tweak_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        TaleLog("[TaleMod] init");
        install_hooks();
        TaleLog("[TaleMod] === done ===");
    });
}