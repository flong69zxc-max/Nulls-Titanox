#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <libgen.h>
#import "libtitanox.h"

#define IMAGE_BASE          0x100000000ULL
#define RVA_RECEIVE_MESSAGE 0x75cce0
#define LOG_LIMIT           50

extern __thread int g_in_hook;

static intptr_t  gSlide = 0;
static NSString *gMainBinaryName = nil;

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

typedef void (*orig_receiveMessage_t)(void *self, void *msg);
static orig_receiveMessage_t orig_receiveMessage = NULL;
static int cnt_receiveMessage = 0;

static void my_receiveMessage(void *self, void *msg) {
    g_in_hook = 1;
    if (cnt_receiveMessage < LOG_LIMIT) {
        cnt_receiveMessage++;
        THLog(@"[BRK] MessageManager::receiveMessage #%d self=%p msg=%p",
              cnt_receiveMessage, self, msg);
    }
    if (orig_receiveMessage) {
        orig_receiveMessage(self, msg);
    }
    g_in_hook = 0;
}

static void OXInstallHooks(void) {
    THLog(@"=== INSTALLING MESSAGE HOOK ===");
    THLog(@"main=%@ slide=0x%lx", gMainBinaryName, (long)gSlide);

    uint64_t rt = IMAGE_BASE + RVA_RECEIVE_MESSAGE + gSlide;
    THLog(@"[brk] target rt=0x%llx file=0x%llx", rt,
          (uint64_t)RVA_RECEIVE_MESSAGE);

    orig_receiveMessage = (orig_receiveMessage_t)rt;

    BOOL ok = [TitanoxHook addBreakpointAtAddress:(void *)rt
                                         withHook:(void *)&my_receiveMessage];
    THLog(@"[brk] MessageManager::receiveMessage -> %s", ok ? "OK" : "FAIL");

    THLog(@"=== HOOK INSTALLED ===");
}

__attribute__((constructor))
static void initMod(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        gSlide = OXFindSlide(gMainBinaryName);
        OXInstallHooks();
        THLog(@"=== DONE ===");
    });
}