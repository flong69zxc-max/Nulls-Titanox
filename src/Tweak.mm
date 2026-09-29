#import <Foundation/Foundation.h>
#import <syslog.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "libtitanox.h"
#include "TitanoxOffsets.h"
#include "offsets.h"

#define OFX_LOG_LIMIT 24
#define OFX_ALLOW_LOW 0

typedef struct {
    const char *tag;
    void *fn;
    int allow_low;
} OfxHookSpec;

static void logcap(int *c, const char *fmt, ...)
{
    (*c)++;
    if (*c > OFX_LOG_LIMIT) return;
    char buf[192];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    syslog(LOG_ERR, "Titanox: %s", buf);
}

static bool hook_getBool(void *self, const char *key)
{
    static int n;
    if (key) {
        size_t klen = strlen(key);
        if (klen > 0 && klen < 128) {
            logcap(&n, "getBool(%s)", key);
            if (strstr(key, "isDev") || strstr(key, "isDeveloper") ||
                strstr(key, "Disable") || strstr(key, "debug") ||
                strstr(key, "Debug") || strstr(key, "cheat") ||
                strstr(key, "Cheat")) {
                return true;
            }
        }
    }
    return false;
}

static bool hook_isDev(void *self)
{
    static int n;
    logcap(&n, "isDev");
    return true;
}

static bool hook_isDevBuild(void *self)
{
    static int n;
    logcap(&n, "isDevBuild");
    return true;
}

static bool hook_isDeveloperBuild(void *self)
{
    static int n;
    logcap(&n, "isDeveloperBuild");
    return true;
}

static void hook_GameButton_buttonPressed(void *self, int32_t buttonId)
{
    static int n;
    logcap(&n, "GameButton_buttonPressed id=%d", buttonId);
}

static void hook_GameButton_setText(void *self)
{
    static int n;
    logcap(&n, "GameButton_setText");
}

static void hook_MessageManager_receiveMessage(void *self)
{
    static int n;
    logcap(&n, "MessageManager_receiveMessage");
}

static void hook_GenericPopup_setTitle(void *self)
{
    static int n;
    logcap(&n, "GenericPopup_setTitle");
}

static void hook_ClientInputManager_addInput(void *self)
{
    static int n;
    logcap(&n, "ClientInputManager_addInput");
}

static void hook_LogicTileData_blocksMovement(void *self)
{
    static int n;
    logcap(&n, "LogicTileData_blocksMovement");
}

static void hook_Screen_getDpiClass(void *self)
{
    static int n;
    logcap(&n, "Screen_getDpiClass");
}

static void hook_GlobalID_getInstanceID(void *self)
{
    static int n;
    logcap(&n, "GlobalID_getInstanceID");
}

static void hook_Projectile_ctor(void *self)
{
    static int n;
    logcap(&n, "Projectile_ctor");
}

static void hook_AnalyticEvent_ctor(void *self)
{
    static int n;
    logcap(&n, "AnalyticEvent_ctor");
}

static void hook_AnalyticEvent_setString(void *self)
{
    static int n;
    logcap(&n, "AnalyticEvent_setString");
}

static void hook_String_ctor(void *self)
{
    static int n;
    logcap(&n, "String_ctor");
}

static const OfxHookSpec g_hooks[] = {
    { "GameButton_buttonPressed",      (void *)hook_GameButton_buttonPressed,      0 },
    { "GameButton_setText",            (void *)hook_GameButton_setText,            0 },
    { "MessageManager_receiveMessage", (void *)hook_MessageManager_receiveMessage, 0 },
    { "GenericPopup_setTitle",         (void *)hook_GenericPopup_setTitle,         0 },
    { "ClientInputManager_addInput",   (void *)hook_ClientInputManager_addInput,   0 },
    { "LogicTileData_blocksMovement",  (void *)hook_LogicTileData_blocksMovement,  0 },
    { "Screen_getDpiClass",            (void *)hook_Screen_getDpiClass,            0 },
    { "GlobalID_getInstanceID",        (void *)hook_GlobalID_getInstanceID,        0 },
    { "Projectile_ctor",               (void *)hook_Projectile_ctor,               1 },
    { "AnalyticEvent_ctor",            (void *)hook_AnalyticEvent_ctor,            1 },
    { "AnalyticEvent_setString",       (void *)hook_AnalyticEvent_setString,       0 },
    { "String_ctor",                   (void *)hook_String_ctor,                   1 },
    { NULL, NULL, 0 }
};

static void feed_known(void)
{
#ifdef RVA_GETBOOL
    OfxSetKnownRVA("", "getBool", RVA_GETBOOL);
#endif
#ifdef RVA_ISDEV
    OfxSetKnownRVA("", "isDev", RVA_ISDEV);
#endif
#ifdef RVA_ISDEVBUILD
    OfxSetKnownRVA("", "isDevBuild", RVA_ISDEVBUILD);
#endif
#ifdef RVA_ISDEVELOPERBUILD
    OfxSetKnownRVA("", "isDeveloperBuild", RVA_ISDEVELOPERBUILD);
#endif
#ifdef RVA_ANALYTICEVENT_CTOR
    OfxSetKnown("AnalyticEvent_ctor", RVA_ANALYTICEVENT_CTOR);
#endif
#ifdef RVA_ANALYTICEVENT_SETSTRING
    OfxSetKnown("AnalyticEvent_setString", RVA_ANALYTICEVENT_SETSTRING);
#endif
#ifdef RVA_CLIENTINPUTMANAGER_ADDINPUT
    OfxSetKnown("ClientInputManager_addInput", RVA_CLIENTINPUTMANAGER_ADDINPUT);
#endif
#ifdef RVA_GAMEBUTTON_BUTTONPRESSED
    OfxSetKnown("GameButton_buttonPressed", RVA_GAMEBUTTON_BUTTONPRESSED);
#endif
#ifdef RVA_GAMEBUTTON_SETTEXT
    OfxSetKnown("GameButton_setText", RVA_GAMEBUTTON_SETTEXT);
#endif
#ifdef RVA_GENERICPOPUP_SETTITLE
    OfxSetKnown("GenericPopup_setTitle", RVA_GENERICPOPUP_SETTITLE);
#endif
#ifdef RVA_GLOBALID_GETINSTANCEID
    OfxSetKnown("GlobalID_getInstanceID", RVA_GLOBALID_GETINSTANCEID);
#endif
#ifdef RVA_LOGIC_TILEDATA_BLOCKSMOVEMENT
    OfxSetKnown("LogicTileData_blocksMovement", RVA_LOGIC_TILEDATA_BLOCKSMOVEMENT);
#endif
#ifdef RVA_MESSAGEMANAGER_RECEIVEMESSAGE
    OfxSetKnown("MessageManager_receiveMessage", RVA_MESSAGEMANAGER_RECEIVEMESSAGE);
#endif
#ifdef RVA_PROJECTILE_CTOR
    OfxSetKnown("Projectile_ctor", RVA_PROJECTILE_CTOR);
#endif
#ifdef RVA_SCREEN_GETDPICLASS
    OfxSetKnown("Screen_getDpiClass", RVA_SCREEN_GETDPICLASS);
#endif
#ifdef RVA_SCREEN_WIDTH
    OfxSetKnown("Screen_widthGlobal", RVA_SCREEN_WIDTH);
#endif
#ifdef RVA_STAGE_INSTANCE
    OfxSetKnown("StageInstanceGlobalPtr", RVA_STAGE_INSTANCE);
#endif
#ifdef RVA_STRING_CTOR
    OfxSetKnown("String_ctor", RVA_STRING_CTOR);
#endif
}

static int install_hooks(const OfxHookSpec *specs)
{
    int done = 0;
    for (int i = 0; specs[i].tag; i++) {
        uint64_t a = OfxAddr(specs[i].tag);
        if (!a) {
            syslog(LOG_ERR, "Titanox: %s not found, hook skipped", specs[i].tag);
            continue;
        }
        if (OfxConfOf(specs[i].tag) == OFX_C_LOW && !specs[i].allow_low && !OFX_ALLOW_LOW) {
            syslog(LOG_ERR, "Titanox: %s 0x%llx low confidence, hook skipped",
                   specs[i].tag, (unsigned long long)a);
            continue;
        }
        [TitanoxHook addBreakpointAtAddress:(void *)a withHook:specs[i].fn];
        syslog(LOG_ERR, "Titanox: %s 0x%llx %s hooked", specs[i].tag,
               (unsigned long long)a, OfxSourceName(OfxSourceOf(specs[i].tag)));
        done++;
    }
    return done;
}

static void install_settings(uint64_t base)
{
    struct {
        const char *m;
        void *fn;
    } st[] = {
        { "getBool",          (void *)hook_getBool },
        { "isDev",            (void *)hook_isDev },
        { "isDevBuild",       (void *)hook_isDevBuild },
        { "isDeveloperBuild", (void *)hook_isDeveloperBuild },
        { NULL, NULL }
    };
    for (int i = 0; st[i].m; i++) {
        uint64_t r = OfxFindRVA("", st[i].m);
        if (!r) {
            syslog(LOG_ERR, "Titanox: settings %s not found", st[i].m);
            continue;
        }
        [TitanoxHook addBreakpointAtAddress:(void *)(base + r) withHook:st[i].fn];
        syslog(LOG_ERR, "Titanox: settings %s 0x%llx hooked", st[i].m,
               (unsigned long long)(base + r));
    }
}

__attribute__((constructor))
static void titanox_init(void)
{
    @autoreleasepool {
        uint64_t base = (uint64_t)[TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        if (!base) {
            syslog(LOG_ERR, "Titanox: base not found");
            return;
        }
        syslog(LOG_ERR, "Titanox: base=0x%llx", (unsigned long long)base);

        feed_known();
        OfxInit(base);

        syslog(LOG_ERR, "Titanox: hooks installed %d", install_hooks(g_hooks));
        install_settings(base);

        OfxDumpReport();
        syslog(LOG_ERR, "Titanox: resolved %d/%d", OfxResolved(), g_ofx_target_count);
    }
}
