#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <libgen.h>
#import "libtitanox.h"

#define IMAGE_BASE          0x100000000ULL
#define RVA_RECEIVE_MESSAGE 0x75cce0
#define NOP_INSN            0xd503201f

static intptr_t  gSlide = 0;
static NSString *gMainBinaryName = nil;

extern "C" void OXLogC(const char *tag, uint64_t a, uint64_t b) {
    THLog(@"[C] %s a=0x%llx b=0x%llx", tag, a, b);
}

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        if (base.length) return base;
    }
    return [TitanoxHook findExecInBundle:nil];
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

static uint32_t OXReadU32(uint64_t addr) {
    uint32_t v = 0;
    vm_size_t out = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)addr,
                                         sizeof(v), (vm_address_t)&v, &out);
    if (kr != KERN_SUCCESS || out != sizeof(v)) return 0xDEADBEEF;
    return v;
}

static void OXTestPatch(void) {
    uint64_t rt = IMAGE_BASE + RVA_RECEIVE_MESSAGE + gSlide;
    THLog(@"=== IN-MEMORY PATCH TEST ===");
    THLog(@"[test] target rt=0x%llx file=0x%llx", rt,
          (uint64_t)RVA_RECEIVE_MESSAGE);

    uint32_t orig = OXReadU32(rt);
    THLog(@"[test] before: %08x", orig);
    if (orig == 0xDEADBEEF) {
        THLog(@"[test] cannot read target");
        return;
    }

    uint32_t nop = NOP_INSN;
    THLog(@"[test] writing NOP (%08x)", nop);

    [TitanoxHook patchMemoryAtAddress:(void *)rt
                            withPatch:(uint8_t *)&nop
                                 size:4];

    uint32_t after = OXReadU32(rt);
    THLog(@"[test] after:  %08x  (want %08x)", after, nop);

    if (after == nop) {
        THLog(@"[test] *** WRITE WORKS: MSHook-style is possible ***");

        [TitanoxHook patchMemoryAtAddress:(void *)rt
                                withPatch:(uint8_t *)&orig
                                     size:4];
        uint32_t restored = OXReadU32(rt);
        THLog(@"[test] restored: %08x", restored);
    } else {
        THLog(@"[test] *** WRITE BLOCKED: code page is signed ***");
        THLog(@"[test] MSHookFunction will fail the same way");
    }
}

__attribute__((constructor))
static void initMod(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        gSlide = OXFindSlide(gMainBinaryName);
        THLog(@"main=%@ slide=0x%lx", gMainBinaryName, (long)gSlide);
        OXTestPatch();
        THLog(@"=== DONE ===");
    });
}