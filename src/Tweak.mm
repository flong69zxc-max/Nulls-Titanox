#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <libgen.h>
#import "libtitanox.h"

#define FILE_LO   0x100000000ULL
#define FILE_HI   0x101170000ULL
#define TEXT_LO   0x100004000ULL
#define TEXT_HI   0x100D8AF60ULL

static intptr_t  gSlide = 0;
static NSString *gMainBinaryName = nil;

static NSString *OXDetectMainBinary(void) {
    NSString *exePath = [[NSBundle mainBundle] executablePath];
    if (exePath) {
        NSString *base = [exePath lastPathComponent];
        if (base.length) return base;
    }
    NSString *found = [TitanoxHook findExecInBundle:nil];
    return found.length ? found : nil;
}

/* Собираем ВСЕ image с таким basename и находим тот, у которого magic MH_MAGIC_64 */
static void OXFindAllCandidates(NSString *name, intptr_t *outSlide, uint64_t *outRuntimeBase) {
    const char *target = name.UTF8String;
    int found = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        const char *base = basename((char *)imgName);
        if (strcmp(base, target) != 0) continue;
        
        const struct mach_header *hdr = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        uint32_t magic = 0;
        if (hdr) memcpy(&magic, hdr, 4);
        
        THLog(@"[cand] image[%u] hdr=%p slide=0x%lx magic=0x%08x",
              i, hdr, (long)slide, magic);
        
        // Verify by reading magic
        if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) {
            *outSlide = slide;
            *outRuntimeBase = (uint64_t)hdr;
            found++;
            THLog(@"[cand] -> MATCH (magic MH_MAGIC_64)");
        }
    }
    if (!found) {
        THLog(@"[cand] no valid image found for %@, dumping all:", name);
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *imgName = _dyld_get_image_name(i);
            if (imgName && strstr(imgName, target)) {
                THLog(@"  [%u] %s hdr=%p slide=0x%lx", i, imgName,
                      _dyld_get_image_header(i),
                      (long)_dyld_get_image_vmaddr_slide(i));
            }
        }
    }
}

/* Три способа чтения, чтобы понять какой работает */
static BOOL OXReadBytes(uint64_t fileVaddr, void *buf, size_t size) {
    if (fileVaddr < FILE_LO) return NO;
    if (fileVaddr + size < fileVaddr) return NO;
    if (fileVaddr + size > FILE_HI) return NO;
    uint64_t runtime = fileVaddr + gSlide;

    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)runtime,
                                         (vm_size_t)size,
                                         (vm_address_t)buf,
                                         &outSize);
    if (kr == KERN_SUCCESS && outSize == size) return YES;

    if ([TitanoxHook MemXreadMemory:(uintptr_t)runtime buffer:buf length:size]) return YES;

    memcpy(buf, (void *)runtime, size);
    return YES;
}

static uint64_t OXReadPtr(uint64_t fileVaddr) {
    uint64_t v = 0;
    if (!OXReadBytes(fileVaddr, &v, 8)) return 0;
    return v;
}

static NSString *OXReadCString(uint64_t fileVaddr, int maxLen) {
    if (!fileVaddr) return nil;
    char buf[256];
    memset(buf, 0, sizeof(buf));
    size_t n = (maxLen < 255) ? maxLen : 255;
    if (!OXReadBytes(fileVaddr, buf, n)) return nil;
    if (buf[0] == 0) return nil;
    return [NSString stringWithUTF8String:buf];
}

static uint64_t OXDecodeFixup(uint64_t raw) {
    uint64_t t43   = raw & 0x7FFFFFFFFFFULL;
    uint64_t high8 = (raw >> 43) & 0xFFULL;
    if (high8) return (high8 << 56) | t43;
    return t43;
}

static NSArray<NSString *> *OXSplitMangled(NSString *raw) {
    if (!raw || raw.length < 2) return nil;
    if ([raw hasPrefix:@"N"] && [raw hasSuffix:@"E"]) {
        NSString *inner = [raw substringWithRange:NSMakeRange(1, raw.length - 2)];
        NSMutableArray *parts = [NSMutableArray array];
        NSUInteger i = 0;
        while (i < inner.length) {
            NSUInteger j = i;
            while (j < inner.length && isdigit([inner characterAtIndex:j])) j++;
            if (j == i) break;
            int len = [[inner substringWithRange:NSMakeRange(i, j - i)] intValue];
            if (len <= 0 || j + len > inner.length) break;
            [parts addObject:[inner substringWithRange:NSMakeRange(j, len)]];
            i = j + len;
        }
        if (parts.count) return parts;
    }
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger i = 0;
    while (i < raw.length && isdigit([raw characterAtIndex:i])) {
        NSUInteger j = i;
        while (j < raw.length && isdigit([raw characterAtIndex:j])) j++;
        if (j == i) break;
        int len = [[raw substringWithRange:NSMakeRange(i, j - i)] intValue];
        if (len <= 0 || j + len > raw.length) break;
        [parts addObject:[raw substringWithRange:NSMakeRange(j, len)]];
        i = j + len;
    }
    if (parts.count) return parts;
    return nil;
}

static NSDictionary *OXGetTypeInfo(uint64_t vtVaddr) {
    if (vtVaddr < 8) return nil;
    uint64_t raw = OXReadPtr(vtVaddr - 8);
    if (!raw) return nil;
    uint64_t tiVaddr = OXDecodeFixup(raw);
    if (!tiVaddr || tiVaddr < FILE_LO || tiVaddr >= FILE_HI) return nil;
    uint64_t nameRaw = OXReadPtr(tiVaddr + 8);
    if (!nameRaw) return nil;
    uint64_t nameVaddr = OXDecodeFixup(nameRaw);
    if (!nameVaddr || nameVaddr < FILE_LO || nameVaddr >= FILE_HI) return nil;
    NSString *rawStr = OXReadCString(nameVaddr, 160);
    if (!rawStr || rawStr.length == 0) return nil;
    NSArray *parts = OXSplitMangled(rawStr);
    if (!parts || parts.count == 0) return nil;
    return @{@"class": parts.lastObject, @"raw": rawStr};
}

static void OXDumpVtable(uint64_t vtFileVaddr, NSString *label) {
    NSDictionary *ti = OXGetTypeInfo(vtFileVaddr);
    NSString *cls = ti ? ti[@"class"] : @"unknown";
    THLog(@"=== VT %@ @ 0x%llx class=%@ ===", label, vtFileVaddr, cls);
    for (int i = 0; i < 256; i++) {
        uint64_t slotVaddr = vtFileVaddr + i * 8;
        uint64_t raw = OXReadPtr(slotVaddr);
        if (!raw) break;
        uint64_t fn = OXDecodeFixup(raw);
        if (fn < TEXT_LO || fn >= TEXT_HI) break;
        THLog(@"  [%3d] 0x%llx", i, fn);
    }
}

static void OXDiagnose(void) {
    THLog(@"=== DIAGNOSTICS ===");

    // 1. Какие image называются "Nulls Brawl"
    THLog(@"[diag] searching for main image...");
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "Nulls") || strstr(name, "nt.nb")) {
            const struct mach_header *hdr = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            uint32_t magic = 0;
            if (hdr) memcpy(&magic, hdr, 4);
            THLog(@"[diag] [%u] %s", i, name);
            THLog(@"[diag]     hdr=%p slide=0x%lx magic=0x%08x", hdr, (long)slide, magic);
        }
    }

    // 2. Читаем magic по runtime base
    if (gSlide) {
        uint64_t runtimeBase = FILE_LO + gSlide;
        uint32_t magic = 0;
        OXReadBytes(FILE_LO, &magic, 4);
        THLog(@"[diag] read magic at runtime 0x%llx -> 0x%08x (expect 0xfeedfacf)",
              runtimeBase, magic);
    }

    // 3. Читаем содержимое нашей известной vtable
    uint64_t vt = FILE_LO + 0x00F9B0F8;
    THLog(@"[diag] reading GameButton vt at file 0x%llx runtime 0x%llx",
          vt, vt + gSlide);
    for (int i = -2; i < 6; i++) {
        uint64_t slot = vt + i * 8;
        uint64_t v = OXReadPtr(slot);
        THLog(@"[diag]   slot[%d] @file 0x%llx = 0x%016llx", i, slot, v);
    }

    THLog(@"=== DIAG END ===");
}

__attribute__((constructor))
static void initTitanoxTrace(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gMainBinaryName = OXDetectMainBinary();
        THLog(@"main binary detected: %@", gMainBinaryName);

        intptr_t slide = 0;
        uint64_t runtimeBase = 0;
        OXFindAllCandidates(gMainBinaryName, &slide, &runtimeBase);

        gSlide = slide;
        THLog(@"FINAL slide=0x%lx runtimeBase=0x%llx", (long)gSlide, runtimeBase);

        OXDiagnose();
    });
}