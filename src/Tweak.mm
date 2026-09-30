#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Titanox.h"
#import "MemX.h"

#define LOG_PATH [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"TITANOX_OFFSETS.txt"]

static NSMutableString *gLog = nil;
static NSLock *gLock = nil;

static void OXLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [gLock lock];
    [gLog appendFormat:@"%@\n", s];
    [gLock unlock];
}

static void OXFlush(void) {
    [gLock lock];
    [gLog writeToFile:LOG_PATH atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [gLock unlock];
}

static uint64_t gBase = 0;
static uint64_t gSlide = 0;

static uint64_t OXOff(uint64_t vaddr) {
    return vaddr;
}

static uint64_t OXReadPtr(uint64_t addr) {
    uint64_t v = 0;
    MemX *mx = [MemX sharedInstance];
    [mx readMemoryAtAddress:addr intoBuffer:&v size:8];
    return v;
}

static void OXWritePtr(uint64_t addr, uint64_t val) {
    MemX *mx = [MemX sharedInstance];
    [mx writeMemoryAtAddress:addr fromBuffer:&val size:8];
}

static uint64_t OXSlideFix(uint64_t raw) {
    uint64_t t43 = raw & 0x7FFFFFFFFFFULL;
    uint64_t high8 = (raw >> 43) & 0xFFULL;
    if (high8) return (high8 << 56) | t43;
    return t43;
}

static BOOL OXIsInText(uint64_t addr) {
    return addr >= 0x100000000ULL && addr < 0x100E00000ULL;
}

static NSString *OXReadCString(uint64_t addr, int maxLen) {
    if (!addr) return nil;
    char buf[256];
    memset(buf, 0, sizeof(buf));
    MemX *mx = [MemX sharedInstance];
    [mx readMemoryAtAddress:addr intoBuffer:buf size:maxLen < 255 ? maxLen : 255];
    if (buf[0] == 0) return nil;
    return [NSString stringWithUTF8String:buf];
}

static NSString *OXDemangleItanium(NSString *s) {
    if (![s hasPrefix:@"_ZN"]) return nil;
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger i = 3;
    while (i < s.length) {
        NSUInteger j = i;
        while (j < s.length && isdigit([s characterAtIndex:j])) j++;
        if (j == i) break;
        int len = [[s substringWithRange:NSMakeRange(i, j - i)] intValue];
        if (len <= 0 || j + len > s.length) break;
        [parts addObject:[s substringWithRange:NSMakeRange(j, len)]];
        i = j + len;
    }
    if (parts.count >= 2) return [NSString stringWithFormat:@"%@::%@", parts[parts.count - 2], parts[parts.count - 1]];
    if (parts.count == 1) return parts[0];
    return nil;
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

static NSDictionary *OXGetTypeInfoForVtable(uint64_t vtStart) {
    uint64_t raw = OXReadPtr(vtStart - 8);
    if (!raw) return nil;
    uint64_t tiCand = OXSlideFix(raw);
    if (!tiCand || tiCand < 0x100000000ULL) return nil;
    uint64_t nameRaw = OXReadPtr(tiCand + 8);
    if (!nameRaw) return nil;
    uint64_t nameCand = OXSlideFix(nameRaw);
    if (!nameCand || nameCand < 0x100000000ULL) return nil;
    NSString *rawStr = OXReadCString(nameCand, 160);
    if (!rawStr || rawStr.length == 0) return nil;
    NSArray *parts = OXSplitMangled(rawStr);
    if (!parts || parts.count == 0) return nil;
    NSString *cls = parts.lastObject;
    return @{@"class": cls, @"raw": rawStr, @"ti": @(tiCand), @"name": @(nameCand)};
}

static NSArray<NSDictionary *> *OXEnumerateVtables(uint64_t *textStart, uint64_t *textEnd) {
    NSMutableArray *runs = [NSMutableArray array];
    uint64_t ts = 0x100004000ULL;
    uint64_t te = 0x100D8AF60ULL;
    *textStart = ts;
    *textEnd = te;

    MemX *mx = [MemX sharedInstance];
    uint64_t dataStart = 0x100F74000ULL;
    uint64_t dataEnd = 0x101170000ULL;
    uint64_t size = dataEnd - dataStart;
    uint8_t *buf = malloc(size);
    if (!buf) return runs;
    [mx readMemoryAtAddress:dataStart intoBuffer:buf size:size];

    uint64_t runStart = 0;
    uint64_t prevSlot = 0;
    int runCount = 0;

    for (uint64_t off = 0; off + 8 <= size; off += 8) {
        uint64_t slot = dataStart + off;
        uint64_t raw = *(uint64_t *)(buf + off);
        uint64_t tgt = OXSlideFix(raw);
        BOOL valid = (tgt >= ts && tgt < te && (tgt & 3) == 0);
        if (valid) {
            if (runStart == 0) {
                runStart = slot;
                runCount = 1;
            } else if (slot == prevSlot + 8) {
                runCount++;
            } else {
                if (runCount >= 4) {
                    [runs addObject:@{@"start": @(runStart), @"end": @(prevSlot), @"count": @(runCount)}];
                }
                runStart = slot;
                runCount = 1;
            }
            prevSlot = slot;
        } else {
            if (runCount >= 4) {
                [runs addObject:@{@"start": @(runStart), @"end": @(prevSlot), @"count": @(runCount)}];
            }
            runStart = 0;
            runCount = 0;
        }
    }
    if (runCount >= 4) {
        [runs addObject:@{@"start": @(runStart), @"end": @(prevSlot), @"count": @(runCount)}];
    }
    free(buf);
    return runs;
}

static void OXDumpAllVtables(void) {
    uint64_t ts = 0, te = 0;
    NSArray *runs = OXEnumerateVtables(&ts, &te);
    OXLog(@"=== VTABLE RUNS: %lu ===", (unsigned long)runs.count);

    for (NSDictionary *r in runs) {
        uint64_t start = [r[@"start"] unsignedLongLongValue];
        uint64_t count = [r[@"count"] unsignedLongLongValue];
        NSDictionary *ti = OXGetTypeInfoForVtable(start);
        if (ti) {
            OXLog(@"VT 0x%llx slots=%llu class=%@ raw=%@", start, count, ti[@"class"], ti[@"raw"]);
            for (uint64_t i = 0; i < count; i++) {
                uint64_t slot = start + i * 8;
                uint64_t raw = OXReadPtr(slot);
                uint64_t tgt = OXSlideFix(raw);
                OXLog(@"  [%2llu] 0x%llx", i, tgt);
            }
        } else {
            OXLog(@"VT 0x%llx slots=%llu (no typeinfo)", start, count);
        }
    }
}

static void OXHookKnownVtables(void) {
    NSDictionary *known = @{
        @"Character":          @(0x00FF45C0),
        @"GameButton":         @(0x00F9B0F8),
        @"HomePage":           @(0x00FE4008),
        @"LogicDataTables":    @(0x00FF2478),
        @"LogicProjectileData": @(0x00FF3AA0),
        @"MessageManager":     @(0x00FD57E8),
        @"MovieClip":          @(0x01006150),
        @"NativeFont":         @(0x01005858),
        @"Stage":              @(0x010091B0),
    };

    Titanox *tx = [Titanox sharedInstance];

    for (NSString *cls in known) {
        uint64_t vtOff = [known[cls] unsignedLongLongValue];
        uint64_t vtAddr = gBase + vtOff;
        OXLog(@"HOOK %@ vt=0x%llx", cls, vtAddr);

        for (int i = 0; i < 128; i++) {
            uint64_t slot = vtAddr + i * 8;
            uint64_t raw = OXReadPtr(slot);
            uint64_t fn = OXSlideFix(raw);
            if (fn < 0x100000000ULL || fn >= 0x100E00000ULL) continue;

            __block int slotIdx = i;
            __block NSString *clsName = cls;

            void *orig = [tx hookFunctionAtVaddr:fn - gSlide withReplacement:^(void) {
                OXLog(@"CALL %@::slot[%d] fn=0x%llx", clsName, slotIdx, fn);
            }];
            if (orig) {
                OXLog(@"  hooked %@ slot[%d] fn=0x%llx", cls, i, fn);
            }
        }
    }
}

static void OXScanAllFunctionPrologues(void) {
    uint64_t ts = 0x100004000ULL;
    uint64_t te = 0x100D8AF60ULL;
    MemX *mx = [MemX sharedInstance];
    uint64_t size = te - ts;
    uint8_t *buf = malloc(size);
    if (!buf) return;
    [mx readMemoryAtAddress:ts intoBuffer:buf size:size];

    int prologCount = 0;
    NSMutableArray *prologs = [NSMutableArray array];

    for (uint64_t off = 0; off + 4 <= size; off += 4) {
        uint32_t w = *(uint32_t *)(buf + off);
        if ((w & 0xFFC07FFF) == 0xA9807BFD) {
            prologs[@(ts + off)] = @YES;
            prologCount++;
        } else if (w == 0xD503237F || w == 0xD503233F || w == 0xD503245F || w == 0xD503249F) {
            prologs[@(ts + off)] = @YES;
            prologCount++;
        }
    }
    free(buf);
    OXLog(@"=== PROLOGUES: %d ===", prologCount);
}

static void OXHookMessageManager(void) {
    Titanox *tx = [Titanox sharedInstance];
    uint64_t fnAddr = gBase + 0x0075CCE0;
    OXLog(@"Hooking MessageManager::receiveMessage @ 0x%llx", fnAddr);
    void *orig = [tx hookFunctionAtVaddr:fnAddr - gSlide withReplacement:^(void *self, void *msg) {
        OXLog(@"MessageManager::receiveMessage self=%p msg=%p", self, msg);
    }];
    if (orig) {
        OXLog(@"  hooked MessageManager::receiveMessage");
    }
}

static void OXHookNativeFont(void) {
    Titanox *tx = [Titanox sharedInstance];
    uint64_t fnAddr = gBase + 0x00B3FDE8;
    OXLog(@"Hooking NativeFont::formatString @ 0x%llx", fnAddr);
    void *orig = [tx hookFunctionAtVaddr:fnAddr - gSlide withReplacement:^(void *self, void *str) {
        OXLog(@"NativeFont::formatString self=%p str=%p", self, str);
    }];
    if (orig) {
        OXLog(@"  hooked NativeFont::formatString");
    }
}

static void OXHookGameButtonCtor(void) {
    Titanox *tx = [Titanox sharedInstance];
    uint64_t fnAddr = gBase + 0x005425B0;
    OXLog(@"Hooking GameButton::ctor @ 0x%llx", fnAddr);
    void *orig = [tx hookFunctionAtVaddr:fnAddr - gSlide withReplacement:^(void *self) {
        OXLog(@"GameButton::ctor self=%p", self);
        uint64_t vt = OXReadPtr((uint64_t)self);
        OXLog(@"  vtable=0x%llx", vt);
    }];
    if (orig) {
        OXLog(@"  hooked GameButton::ctor");
    }
}

static void OXRunDump(void) {
    OXLog(@"=== TITANOX OFFSETS DUMP v19 ===");
    OXLog(@"base=0x%llx slide=0x%llx", gBase, gSlide);

    OXScanAllFunctionPrologues();
    OXDumpAllVtables();

    OXHookMessageManager();
    OXHookNativeFont();
    OXHookGameButtonCtor();
    OXHookKnownVtables();

    OXFlush();
    OXLog(@"=== DUMP COMPLETE ===");
    OXFlush();
}

__attribute__((constructor))
static void initTitanox(void) {
    gLog = [NSMutableString new];
    gLock = [NSLock new];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Titanox *tx = [Titanox sharedInstance];
        gBase = [tx getBaseAddress];
        gSlide = [tx getVMAddressSlide];
        OXLog(@"Titanox ready base=0x%llx slide=0x%llx", gBase, gSlide);
        OXRunDump();
    });
}