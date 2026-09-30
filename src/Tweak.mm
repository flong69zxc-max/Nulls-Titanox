#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <libgen.h>
#import "libtitanox.h"

#define IMAGE_BASE 0x100000000ULL
#define LOG_LIMIT 5

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

static uint64_t OXReadPtr(uint64_t runtimeAddr) {
    uint64_t v = 0;
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)runtimeAddr,
                                         sizeof(v), (vm_address_t)&v, &outSize);
    if (kr != KERN_SUCCESS || outSize != sizeof(v)) return 0;
    return v;
}

typedef void (*orig_GameButton_ctor_t)(void *self);
static orig_GameButton_ctor_t orig_GameButton_ctor = NULL;
static int cnt_GameButton_ctor = 0;

static void hook_GameButton_ctor(void *self) {
    g_in_hook = 1;
    if (cnt_GameButton_ctor < LOG_LIMIT) {
        cnt_GameButton_ctor++;
        uint64_t vt = self ? OXReadPtr((uint64_t)self) : 0;
        THLog(@"[BRK] GameButton::ctor #%d self=%p vt=0x%llx file=0x%llx",
              cnt_GameButton_ctor, self, vt, vt ? (vt - gSlide - IMAGE_BASE) : 0);
    }
    if (orig_GameButton_ctor) orig_GameButton_ctor(self);
    g_in_hook = 0;
}

typedef void (*orig_HomePage_ctor_t)(void *self);
static orig_HomePage_ctor_t orig_HomePage_ctor = NULL;
static int cnt_HomePage_ctor = 0;

static void hook_HomePage_ctor(void *self) {
    g_in_hook = 1;
    if (cnt_HomePage_ctor < LOG_LIMIT) {
        cnt_HomePage_ctor++;
        uint64_t vt = self ? OXReadPtr((uint64_t)self) : 0;
        THLog(@"[BRK] HomePage::ctor #%d self=%p vt=0x%llx file=0x%llx",
              cnt_HomePage_ctor, self, vt, vt ? (vt - gSlide - IMAGE_BASE) : 0);
    }
    if (orig_HomePage_ctor) orig_HomePage_ctor(self);
    g_in_hook = 0;
}

typedef void (*orig_Character_ctor_t)(void *self);
static orig_Character_ctor_t orig_Character_ctor = NULL;
static int cnt_Character_ctor = 0;

static void hook_Character_ctor(void *self) {
    g_in_hook = 1;
    if (cnt_Character_ctor < LOG_LIMIT) {
        cnt_Character_ctor++;
        uint64_t vt = self ? OXReadPtr((uint64_t)self) : 0;
        THLog(@"[BRK] Character::ctor #%d self=%p vt=0x%llx file=0x%llx",
              cnt_Character_ctor, self, vt, vt ? (vt - gSlide - IMAGE_BASE) : 0);
    }
    if (orig_Character_ctor) orig_Character_ctor(self);
    g_in_hook = 0;
}

typedef void (*orig_MessageManager_receiveMessage_t)(void *self, void *msg);
static orig_MessageManager_receiveMessage_t orig_MessageManager_receiveMessage = NULL;
static int cnt_MessageManager_receiveMessage = 0;

static void hook_MessageManager_receiveMessage(void *self, void *msg) {
    g_in_hook = 1;
    if (cnt_MessageManager_receiveMessage < LOG_LIMIT) {
        cnt_MessageManager_receiveMessage++;
        THLog(@"[BRK] MessageManager::receiveMessage #%d self=%p msg=%p",
              cnt_MessageManager_receiveMessage, self, msg);
    }
    if (orig_MessageManager_receiveMessage) orig_MessageManager_receiveMessage(self, msg);
    g_in_hook = 0;
}

typedef void (*orig_NativeFont_formatString_t)(void *self, void *str);
static orig_NativeFont_formatString_t orig_NativeFont_formatString = NULL;
static int cnt_NativeFont_formatString = 0;

static void hook_NativeFont_formatString(void *self, void *str) {
    g_in_hook = 1;
    if (cnt_NativeFont_formatString < LOG_LIMIT) {
        cnt_NativeFont_formatString++;
        THLog(@"[BRK] NativeFont::formatString #%d self=%p str=%p",
              cnt_NativeFont_formatString, self, str);
    }
    if (orig_NativeFont_formatString) orig_NativeFont_formatString(self, str);
    g_in_hook = 0;
}

typedef void (*orig_LogicDataTables_initDataTable_t)(void *self, void *a);
static orig_LogicDataTables_initDataTable_t orig_LogicDataTables_initDataTable = NULL;
static int cnt_LogicDataTables_initDataTable = 0;

static void hook_LogicDataTables_initDataTable(void *self, void *a) {
    g_in_hook = 1;
    if (cnt_LogicDataTables_initDataTable < LOG_LIMIT) {
        cnt_LogicDataTables_initDataTable++;
        THLog(@"[BRK] LogicDataTables::initDataTable #%d self=%p a=%p",
              cnt_LogicDataTables_initDataTable, self, a);
    }
    if (orig_LogicDataTables_initDataTable) orig_LogicDataTables_initDataTable(self, a);
    g_in_hook = 0;
}

static void OXInstallHooks(void) {
    THLog(@"=== INSTALLING 6 BRK HOOKS ===");

    uint64_t offs[] = {
        0x5425b0,
        0x86eb80,
        0x9e3100,
        0x75cce0,
        0xb3fde8,
        0x9a8f3c,
    };
    void *hooks[] = {
        (void *)&hook_GameButton_ctor,
        (void *)&hook_HomePage_ctor,
        (void *)&hook_Character_ctor,
        (void *)&hook_MessageManager_receiveMessage,
        (void *)&hook_NativeFont_formatString,
        (void *)&hook_LogicDataTables_initDataTable,
    };

    orig_GameButton_ctor = (orig_GameButton_ctor_t)(IMAGE_BASE + 0x5425b0 + gSlide);
    orig_HomePage_ctor = (orig_HomePage_ctor_t)(IMAGE_BASE + 0x86eb80 + gSlide);
    orig_Character_ctor = (orig_Character_ctor_t)(IMAGE_BASE + 0x9e3100 + gSlide);
    orig_MessageManager_receiveMessage = (orig_MessageManager_receiveMessage_t)(IMAGE_BASE + 0x75cce0 + gSlide);
    orig_NativeFont_formatString = (orig_NativeFont_formatString_t)(IMAGE_BASE + 0xb3fde8 + gSlide);
    orig_LogicDataTables_initDataTable = (orig_LogicDataTables_initDataTable_t)(IMAGE_BASE + 0x9a8f3c + gSlide);

    for (int i = 0; i < 6; i++) {
        uint64_t rt = IMAGE_BASE + offs[i] + gSlide;
        BOOL ok = [TitanoxHook addBreakpointAtAddress:(void *)rt
                                             withHook:hooks[i]];
        THLog(@"[brk] 0x%llx -> %s", offs[i], ok ? "OK" : "FAIL");
    }

    THLog(@"=== HOOKS INSTALLED ===");
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        gSlide = OXFindSlide(gMainBinaryName);
        THLog(@"=== BRK TRACER v19 ===");
        THLog(@"main=%@ slide=0x%lx", gMainBinaryName, (long)gSlide);
        OXInstallHooks();
        THLog(@"=== DONE ===");
    });
}