#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>
#import <Foundation/Foundation.h>

#include "libtitanox.h"
#if __has_include("offsets.h")
#include "offsets.h"
#elif __has_include("o.h")
#include "o.h"
#endif

#define OFX_LOG_LIMIT 24
#define OFX_ALLOW_LOW 0

static int g_nresolved;
static int g_by_src[8];

static char  g_dir[512];
static FILE *g_log;

static int ofx_try_dir(const char *d)
{
    mkdir(d, 0755);
    char p[640];
    snprintf(p, sizeof(p), "%s/.ofx", d);
    FILE *f = fopen(p, "w");
    if (!f) return 0;
    fclose(f);
    unlink(p);
    return 1;
}

static const char *ofx_dir(void)
{
    if (g_dir[0]) return g_dir;
    const char *home = getenv("HOME");
    char p[640];
    if (home) {
        snprintf(p, sizeof(p), "%s/Documents", home);
        if (ofx_try_dir(p)) { strlcpy(g_dir, p, sizeof(g_dir)); return g_dir; }
        snprintf(p, sizeof(p), "%s/titanox", home);
        if (ofx_try_dir(p)) { strlcpy(g_dir, p, sizeof(g_dir)); return g_dir; }
    }
    if (ofx_try_dir("/var/mobile/Library/Titanox")) {
        strlcpy(g_dir, "/var/mobile/Library/Titanox", sizeof(g_dir));
        return g_dir;
    }
    strlcpy(g_dir, "/tmp", sizeof(g_dir));
    return g_dir;
}

static FILE *ofx_logf(void)
{
    if (g_log) return g_log;
    char p[700];
    snprintf(p, sizeof(p), "%s/titanox.log", ofx_dir());
    g_log = fopen(p, "w");
    return g_log;
}

static void plog(const char *fmt, ...)
{
    FILE *f = ofx_logf();
    if (!f) return;
    time_t now = time(NULL);
    struct tm tmv;
    localtime_r(&now, &tmv);
    char ts[16];
    strftime(ts, sizeof(ts), "%H:%M:%S", &tmv);
    fprintf(f, "[%s] ", ts);
    va_list ap;
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    va_end(ap);
    fputc('\n', f);
    fflush(f);
}

typedef enum {
    OFX_K_FUNC   = 0,
    OFX_K_CTOR   = 1,
    OFX_K_GLOBAL = 2,
    OFX_K_VTABLE = 3
} OfxKind;

typedef enum {
    OFX_S_NONE = 0,
    OFX_S_HEADER,
    OFX_S_SYMTAB,
    OFX_S_LOGSTR,
    OFX_S_OBJC,
    OFX_S_BARESTR,
    OFX_S_GETINST,
    OFX_S_VTABLE
} OfxSource;

typedef enum { OFX_C_LOW = 0, OFX_C_MED = 1, OFX_C_HIGH = 2 } OfxConf;

typedef struct {
    const char *name;
    const char *cls;
    const char *method;
    uint8_t     kind;
} OfxTarget;

static const OfxTarget g_targets[] = {
    { "LogicBattleModeClient_update", "LogicBattleModeClient", "update", OFX_K_FUNC },
    { "LogicBattleModeClient_getOwnCharacter", "LogicBattleModeClient", "getOwnCharacter", OFX_K_FUNC },
    { "LogicBattleModeClient_getOwnPlayerTeam", "LogicBattleModeClient", "getOwnPlayerTeam", OFX_K_FUNC },
    { "LogicBattleModeClient_setClientPredictionMoveTo", "LogicBattleModeClient", "setClientPredictionMoveTo", OFX_K_FUNC },
    { "LogicBattleModeClient_getOwnPlayerIndex", "LogicBattleModeClient", "getOwnPlayerIndex", OFX_K_FUNC },
    { "LogicBattleModeClient_getTileMap", "LogicBattleModeClient", "getTileMap", OFX_K_FUNC },
    { "LogicBattleModeClient_setRandomSeed", "LogicBattleModeClient", "setRandomSeed", OFX_K_FUNC },
    { "LogicBattleModeClient_setPlayerAvatar", "LogicBattleModeClient", "setPlayerAvatar", OFX_K_FUNC },
    { "BattleMode_getInstance", "BattleMode", "getInstance", OFX_K_FUNC },
    { "BattleMode_enter", "BattleMode", "enter", OFX_K_FUNC },
    { "BattleMode_addResourcesToLoad", "BattleMode", "addResourcesToLoad", OFX_K_FUNC },
    { "LogicGameObjectClient_getX", "LogicGameObjectClient", "getX", OFX_K_FUNC },
    { "LogicGameObjectClient_getY", "LogicGameObjectClient", "getY", OFX_K_FUNC },
    { "LogicGameObjectClient_getZ", "LogicGameObjectClient", "getZ", OFX_K_FUNC },
    { "LogicGameObjectClient_getGlobalID", "LogicGameObjectClient", "getGlobalID", OFX_K_FUNC },
    { "LogicGameObjectClient_getData", "LogicGameObjectClient", "getData", OFX_K_FUNC },
    { "BattleScreen_activateSkill", "BattleScreen", "activateSkill", OFX_K_FUNC },
    { "BattleScreen_updateCameraParameters", "BattleScreen", "updateCameraParameters", OFX_K_FUNC },
    { "BattleScreen_stopWithStick", "BattleScreen", "stopWithStick", OFX_K_FUNC },
    { "BattleScreen_handleTouchReleased", "BattleScreen", "handleTouchReleased", OFX_K_FUNC },
    { "BattleScreen_updateAutoshoot", "BattleScreen", "updateAutoshoot", OFX_K_FUNC },
    { "BattleScreen_getClosestTargetForAutoshoot", "BattleScreen", "getClosestTargetForAutoshoot", OFX_K_FUNC },
    { "BattleScreen_updateMovement", "BattleScreen", "updateMovement", OFX_K_FUNC },
    { "BattleScreen_tryToActivateSkill", "BattleScreen", "tryToActivateSkill", OFX_K_FUNC },
    { "BattleScreen_shouldShowAccessoryButton", "BattleScreen", "shouldShowAccessoryButton", OFX_K_FUNC },
    { "BattleScreen_calculateProjectilePath", "BattleScreen", "calculateProjectilePath", OFX_K_FUNC },
    { "BattleScreen_joystickToWorld", "BattleScreen", "joystickToWorld", OFX_K_FUNC },
    { "Gui_showFloaterTextAtDefaultPos", "Gui", "showFloaterTextAtDefaultPos", OFX_K_FUNC },
    { "GUI_showFloaterTextAt", "GUI", "showFloaterTextAt", OFX_K_FUNC },
    { "GUI_showPopup", "GUI", "showPopup", OFX_K_FUNC },
    { "GUI_getDefaultFloaterPos", "GUI", "getDefaultFloaterPos", OFX_K_FUNC },
    { "Gui_getInstance", "Gui", "getInstance", OFX_K_FUNC },
    { "PopupBase_ctor", "PopupBase", "PopupBase", OFX_K_CTOR },
    { "GenericPopup_ctor", "GenericPopup", "GenericPopup", OFX_K_CTOR },
    { "GenericPopup_addButton", "GenericPopup", "addButton", OFX_K_FUNC },
    { "GenericPopup_addButton2", "GenericPopup", "addButton2", OFX_K_FUNC },
    { "GenericPopup_setTitle", "GenericPopup", "setTitle", OFX_K_FUNC },
    { "GameButton_ctor", "GameButton", "GameButton", OFX_K_CTOR },
    { "GameButton_buttonPressed", "GameButton", "buttonPressed", OFX_K_FUNC },
    { "GameButton_setText", "GameButton", "setText", OFX_K_FUNC },
    { "CustomButton_onButtonPressed", "CustomButton", "onButtonPressed", OFX_K_FUNC },
    { "Sprite_ctor", "Sprite", "Sprite", OFX_K_CTOR },
    { "Sprite_addChild", "Sprite", "addChild", OFX_K_FUNC },
    { "Sprite_addChildAt", "Sprite", "addChildAt", OFX_K_FUNC },
    { "Sprite_removeChild", "Sprite", "removeChild", OFX_K_FUNC },
    { "Stage_addChild", "Stage", "addChild", OFX_K_FUNC },
    { "DisplayObject_setXY", "DisplayObject", "setXY", OFX_K_FUNC },
    { "DisplayObject_removeFromParent", "DisplayObject", "removeFromParent", OFX_K_FUNC },
    { "MovieClip_getTextFieldByName", "MovieClip", "getTextFieldByName", OFX_K_FUNC },
    { "MovieClip_getChildClipByName", "MovieClip", "getChildClipByName", OFX_K_FUNC },
    { "MovieClip_setChildVisible", "MovieClip", "setChildVisible", OFX_K_FUNC },
    { "MovieClip_gotoAndStopFrameIndex", "MovieClip", "gotoAndStopFrameIndex", OFX_K_FUNC },
    { "MovieClipHelper_setTextAndScaleIfNecessary", "MovieClipHelper", "setTextAndScaleIfNecessary", OFX_K_FUNC },
    { "TextField_setText", "TextField", "setText", OFX_K_FUNC },
    { "TextField_fetchFont", "TextField", "fetchFont", OFX_K_FUNC },
    { "String_ctor", "String", "String", OFX_K_CTOR },
    { "String_format", "String", "format", OFX_K_FUNC },
    { "Application_copyString", "Application", "copyString", OFX_K_FUNC },
    { "decoratedTextFieldSetPlayerName", "", "setPlayerName", OFX_K_FUNC },
    { "Name_setupDecorated", "Name", "setupDecorated", OFX_K_FUNC },
    { "Name_applyDecoration", "Name", "applyDecoration", OFX_K_FUNC },
    { "ClientInput_ctor", "ClientInput", "ClientInput", OFX_K_CTOR },
    { "ClientInputManager_addInput", "ClientInputManager", "addInput", OFX_K_FUNC },
    { "ClientInputMessage_sendMovement", "ClientInputMessage", "sendMovement", OFX_K_FUNC },
    { "handleJoystick", "", "handleJoystick", OFX_K_FUNC },
    { "LogicSkillData_getActiveTime", "LogicSkillData", "getActiveTime", OFX_K_FUNC },
    { "LogicSkillData_getRechargeTime", "LogicSkillData", "getRechargeTime", OFX_K_FUNC },
    { "LogicSkillData_getMaxCharge", "LogicSkillData", "getMaxCharge", OFX_K_FUNC },
    { "LogicSkillData_getMsBetweenAttacks", "LogicSkillData", "getMsBetweenAttacks", OFX_K_FUNC },
    { "LogicSkillData_getCastingRange", "LogicSkillData", "getCastingRange", OFX_K_FUNC },
    { "LogicSkillData_getBehaviour", "LogicSkillData", "getBehaviour", OFX_K_FUNC },
    { "LogicSkillData_getLinkedSkill", "LogicSkillData", "getLinkedSkill", OFX_K_FUNC },
    { "LogicSkillData_getProjectileData", "LogicSkillData", "getProjectileData", OFX_K_FUNC },
    { "LogicSkillClient_getData", "LogicSkillClient", "getData", OFX_K_FUNC },
    { "LogicSkillClient_canActivate", "LogicSkillClient", "canActivate", OFX_K_FUNC },
    { "LogicCharacterData_getSpeed", "LogicCharacterData", "getSpeed", OFX_K_FUNC },
    { "LogicCharacterData_getCollisionRadius", "LogicCharacterData", "getCollisionRadius", OFX_K_FUNC },
    { "LogicProjectileData_getRadius", "LogicProjectileData", "getRadius", OFX_K_FUNC },
    { "LogicProjectileData_getSpeed", "LogicProjectileData", "getSpeed", OFX_K_FUNC },
    { "LogicProjectileData_getRendering", "LogicProjectileData", "getRendering", OFX_K_FUNC },
    { "LogicProjectileData_isBeam", "LogicProjectileData", "isBeam", OFX_K_FUNC },
    { "LogicProjectileData_getNumEarlyTicks", "LogicProjectileData", "getNumEarlyTicks", OFX_K_FUNC },
    { "LogicProjectileData_getSpawnAreaEffect", "LogicProjectileData", "getSpawnAreaEffect", OFX_K_FUNC },
    { "LogicProjectileData_IsOwnTeamProjectile", "LogicProjectileData", "IsOwnTeamProjectile", OFX_K_FUNC },
    { "LogicTileData_blocksMovement", "LogicTileData", "blocksMovement", OFX_K_FUNC },
    { "LogicTileData_blocksProjectiles", "LogicTileData", "blocksProjectiles", OFX_K_FUNC },
    { "LogicTile_setData", "LogicTile", "setData", OFX_K_FUNC },
    { "LogicTileMap_isPlayerLineOfSightClear", "LogicTileMap", "isPlayerLineOfSightClear", OFX_K_FUNC },
    { "LogicTileMap_getTile", "LogicTileMap", "getTile", OFX_K_FUNC },
    { "LogicDataTables_getOpenTileData", "LogicDataTables", "getOpenTileData", OFX_K_FUNC },
    { "LogicDataTables_getBaseTileData", "LogicDataTables", "getBaseTileData", OFX_K_FUNC },
    { "LogicDataTables_getSiegeBoltTileData", "LogicDataTables", "getSiegeBoltTileData", OFX_K_FUNC },
    { "LogicCharacterClient_getCarryableData", "LogicCharacterClient", "getCarryableData", OFX_K_FUNC },
    { "LogicCharacterClient_getWeaponSkill", "LogicCharacterClient", "getWeaponSkill", OFX_K_FUNC },
    { "LogicCharacterClient_getLinkedCarryable", "LogicCharacterClient", "getLinkedCarryable", OFX_K_FUNC },
    { "LogicCharacterClient_getCurrentActiveOrCastingSkill", "LogicCharacterClient", "getCurrentActiveOrCastingSkill", OFX_K_FUNC },
    { "LogicCharacterClient_getSkillAt", "LogicCharacterClient", "getSkillAt", OFX_K_FUNC },
    { "LogicCharacterClient_canMoveAndUseThisSkillSimultaneously", "LogicCharacterClient", "canMoveAndUseThisSkillSimultaneously", OFX_K_FUNC },
    { "LogicCharacterClient_isImmuneOrUntargetable", "LogicCharacterClient", "isImmuneOrUntargetable", OFX_K_FUNC },
    { "LogicCharacterClientOwn_clientPredictionPauseMovementForSkillCasting", "LogicCharacterClientOwn", "clientPredictionPauseMovementForSkillCasting", OFX_K_FUNC },
    { "LogicCharacterClientOwn_clientPredictionUpdateAttackDirection", "LogicCharacterClientOwn", "clientPredictionUpdateAttackDirection", OFX_K_FUNC },
    { "LogicGameObjectManagerClient_getGameObjects", "LogicGameObjectManagerClient", "getGameObjects", OFX_K_FUNC },
    { "LogicGameObjectManagerClient_findGameObject", "LogicGameObjectManagerClient", "findGameObject", OFX_K_FUNC },
    { "LogicGameObjectServer_getData", "LogicGameObjectServer", "getData", OFX_K_FUNC },
    { "LogicProjectileServer_shootProjectile", "LogicProjectileServer", "shootProjectile", OFX_K_FUNC },
    { "LogicProjectileServer_runEarlyTicks", "LogicProjectileServer", "runEarlyTicks", OFX_K_FUNC },
    { "LogicProjectileClient_destruct", "LogicProjectileClient", "destruct", OFX_K_FUNC },
    { "LogicProjectileClient_getData", "LogicProjectileClient", "getData", OFX_K_FUNC },
    { "LogicProjectileClient_getTargetX", "LogicProjectileClient", "getTargetX", OFX_K_FUNC },
    { "LogicProjectileClient_getTargetY", "LogicProjectileClient", "getTargetY", OFX_K_FUNC },
    { "LogicGameModeUtil_isTileOnPoisonArea", "LogicGameModeUtil", "isTileOnPoisonArea", OFX_K_FUNC },
    { "Projectile_ctor", "Projectile", "Projectile", OFX_K_CTOR },
    { "Projectile_update", "Projectile", "update", OFX_K_FUNC },
    { "GameMain_update", "GameMain", "update", OFX_K_FUNC },
    { "DecalManager_ctor", "DecalManager", "DecalManager", OFX_K_CTOR },
    { "GameObjectManager_ctor", "GameObjectManager", "GameObjectManager", OFX_K_CTOR },
    { "RenderSystem_ctor", "RenderSystem", "RenderSystem", OFX_K_CTOR },
    { "ResourceManager_getCSV", "ResourceManager", "getCSV", OFX_K_FUNC },
    { "ResourceManager_isResourceLoaded", "ResourceManager", "isResourceLoaded", OFX_K_FUNC },
    { "StringTable_getMovieClip", "StringTable", "getMovieClip", OFX_K_FUNC },
    { "FramerateManager_setSegment", "FramerateManager", "setSegment", OFX_K_FUNC },
    { "FramerateManager_setLimit", "FramerateManager", "setLimit", OFX_K_FUNC },
    { "MessageManager_receiveMessage", "MessageManager", "receiveMessage", OFX_K_FUNC },
    { "MessageManager_sendMessage", "MessageManager", "sendMessage", OFX_K_FUNC },
    { "AllianceManager_startSpectate", "AllianceManager", "startSpectate", OFX_K_FUNC },
    { "CombatHUD_toggleEditing", "CombatHUD", "toggleEditing", OFX_K_FUNC },
    { "CombatHUD_setShootStickState", "CombatHUD", "setShootStickState", OFX_K_FUNC },
    { "CombatHUD_setMoveStickState", "CombatHUD", "setMoveStickState", OFX_K_FUNC },
    { "CombatHUD_update", "CombatHUD", "update", OFX_K_FUNC },
    { "CombatHUD_sendPinCommand", "CombatHUD", "sendPinCommand", OFX_K_FUNC },
    { "CombatHUD_sendSprayCommand", "CombatHUD", "sendSprayCommand", OFX_K_FUNC },
    { "Character_updateHealthBar", "Character", "updateHealthBar", OFX_K_FUNC },
    { "GameScreen_getLogicBattle", "GameScreen", "getLogicBattle", OFX_K_FUNC },
    { "MapEditorScreen_initRenderSystem", "MapEditorScreen", "initRenderSystem", OFX_K_FUNC },
    { "MapEditorScreen_initItems", "MapEditorScreen", "initItems", OFX_K_FUNC },
    { "MapEditorScreen_initCharacters", "MapEditorScreen", "initCharacters", OFX_K_FUNC },
    { "GameSettings_isFixedJoystickEnabled", "GameSettings", "isFixedJoystickEnabled", OFX_K_FUNC },
    { "GameStateManager_getInstance", "GameStateManager", "getInstance", OFX_K_FUNC },
    { "GameStateManager_isState", "GameStateManager", "isState", OFX_K_FUNC },
    { "HomeMode_getInstance", "HomeMode", "getInstance", OFX_K_FUNC },
    { "GameSliderComponent_ctor", "GameSliderComponent", "GameSliderComponent", OFX_K_CTOR },
    { "GameSliderComponent_setValueBounds", "GameSliderComponent", "setValueBounds", OFX_K_FUNC },
    { "DropGUIContainer_ctorFromExport", "DropGUIContainer", "ctorFromExport", OFX_K_FUNC },
    { "MapEditorModifierItem_ctor", "MapEditorModifierItem", "MapEditorModifierItem", OFX_K_CTOR },
    { "MapEditorModifierPopup_ctor", "MapEditorModifierPopup", "MapEditorModifierPopup", OFX_K_CTOR },
    { "MapEditorModifierPopup_addModifierItem", "MapEditorModifierPopup", "addModifierItem", OFX_K_FUNC },
    { "CSVRow_getIntegerValueAt", "CSVRow", "getIntegerValueAt", OFX_K_FUNC },
    { "CSVRow_getName", "CSVRow", "getName", OFX_K_FUNC },
    { "CSVRow_getValueAt", "CSVRow", "getValueAt", OFX_K_FUNC },
    { "CSVRow_getBooleanValueAt", "CSVRow", "getBooleanValueAt", OFX_K_FUNC },
    { "CSVTable_getColumnIndexByName", "CSVTable", "getColumnIndexByName", OFX_K_FUNC },
    { "TeamChatMessage_ctor", "TeamChatMessage", "TeamChatMessage", OFX_K_CTOR },
    { "TeamSetMemberReadyMessage_ctor", "TeamSetMemberReadyMessage", "TeamSetMemberReadyMessage", OFX_K_CTOR },
    { "StartSpectateMessage_ctor", "StartSpectateMessage", "StartSpectateMessage", OFX_K_CTOR },
    { "PiranhaMessage_ctor", "PiranhaMessage", "PiranhaMessage", OFX_K_CTOR },
    { "HashTagCodeGenerator_ctor", "HashTagCodeGenerator", "HashTagCodeGenerator", OFX_K_CTOR },
    { "HashTagCodeGenerator_toId", "HashTagCodeGenerator", "toId", OFX_K_FUNC },
    { "HashTagCodeGenerator_isValid", "HashTagCodeGenerator", "isValid", OFX_K_FUNC },
    { "LogicLongToCodeConverterUtil_convert", "LogicLongToCodeConverterUtil", "convert", OFX_K_FUNC },
    { "LogicLongToCodeConverterUtil_toCode", "LogicLongToCodeConverterUtil", "toCode", OFX_K_FUNC },
    { "LogicRandom_setIteratedRandomSeed", "LogicRandom", "setIteratedRandomSeed", OFX_K_FUNC },
    { "LogicJSONObject_put", "LogicJSONObject", "put", OFX_K_FUNC },
    { "Screen_getDpiClass", "Screen", "getDpiClass", OFX_K_FUNC },
    { "Screen_getHeight", "Screen", "getHeight", OFX_K_FUNC },
    { "Screen_getWidth", "Screen", "getWidth", OFX_K_FUNC },
    { "nativeCopyToClipboard", "", "copyToClipboard", OFX_K_FUNC },
    { "SetClientPrediction", "", "setClientPrediction", OFX_K_FUNC },
    { "ScrollArea_scrollTo", "ScrollArea", "scrollTo", OFX_K_FUNC },
    { "ScrollArea_updateBounds", "ScrollArea", "updateBounds", OFX_K_FUNC },
    { "ScrollArea_addContent", "ScrollArea", "addContent", OFX_K_FUNC },
    { "ScrollArea_removeAllContent", "ScrollArea", "removeAllContent", OFX_K_FUNC },
    { "GlobalID_getInstanceID", "GlobalID", "getInstanceID", OFX_K_FUNC },
    { "LogicPlayerMap_save", "LogicPlayerMap", "save", OFX_K_FUNC },
    { "LogicPlayerMapUtil_tileDataToTileCode", "LogicPlayerMapUtil", "tileDataToTileCode", OFX_K_FUNC },
    { "AnalyticEvent_ctor", "AnalyticEvent", "AnalyticEvent", OFX_K_CTOR },
    { "AnalyticEvent_setString", "AnalyticEvent", "setString", OFX_K_FUNC },
    { "LogicCompressedString_ctor", "LogicCompressedString", "LogicCompressedString", OFX_K_CTOR },
    { "ResourceListener_addFile", "ResourceListener", "addFile", OFX_K_FUNC },
    { "AreaEffectData_getRadius", "AreaEffectData", "getRadius", OFX_K_FUNC },
    { "AreaEffectData_getActiveTimeMs", "AreaEffectData", "getActiveTimeMs", OFX_K_FUNC },
    { "LogicData_getName", "LogicData", "getName", OFX_K_FUNC },

    { "MessageManager_instance", "MessageManager", "", OFX_K_GLOBAL },
    { "AllianceManager_instance", "AllianceManager", "", OFX_K_GLOBAL },
    { "StageInstanceGlobalPtr", "Stage", "", OFX_K_GLOBAL },
    { "Screen_widthGlobal", "Screen", "", OFX_K_GLOBAL },
    { "Screen_heightGlobal", "Screen", "", OFX_K_GLOBAL },
    { "FramerateManager_targetFps", "FramerateManager", "", OFX_K_GLOBAL },
    { "LogicDataTables_tableArray", "LogicDataTables", "", OFX_K_GLOBAL },
    { "VTABLE_PROJECTILE_DATA", "LogicProjectileData", "", OFX_K_VTABLE },
    { "VTABLE_CHARACTER_DATA", "LogicCharacterData", "", OFX_K_VTABLE },
    { "VTABLE_TEXT_FIELD", "TextField", "", OFX_K_VTABLE },
    { "VTABLE_DECORATED_TEXT_FIELD", "DecoratedTextField", "", OFX_K_VTABLE },
    { "ClientInput_typeConstantTable", "ClientInput", "", OFX_K_GLOBAL },
    { "SkillCommandTypeTable", "SkillCommand", "", OFX_K_GLOBAL },
    { "ClientInput_hashInnerMask", "ClientInput", "", OFX_K_GLOBAL },
    { "ClientInput_hashOuterMask", "ClientInput", "", OFX_K_GLOBAL },
};
static const int g_target_count = (int)(sizeof(g_targets) / sizeof(g_targets[0]));

static struct {
    int      inited;
    uint64_t base, slide, vmbase;
    uint64_t text_vm, text_size;
    uint64_t cstr_vm, cstr_size;
    uint64_t meth_vm, meth_size;
    uint64_t clsn_vm, clsn_size;
    uint64_t const_vm, const_size;
    uint64_t data_vm, data_size;
    uint64_t sym_addr; uint32_t nsyms; uint64_t str_addr; uint32_t strsize;
    uint64_t fs_addr, fs_size;
    uint64_t *fstarts; int nfstarts;
    int      ntargets;
} g;

typedef struct {
    uint64_t vmaddr, vmsize, fileoff, filesize, initprot;
    int      is_data_like;
    char     name[20];
} OfxSeg;
static OfxSeg g_segs[64]; static int g_nsegs;

typedef struct { char sect[20], seg[20]; uint64_t vmaddr, size; } OfxSec;
static OfxSec g_secs[400]; static int g_nsecs;

typedef struct {
    uint8_t  src, conf;
    uint64_t rva;
    uint64_t str_vm;
    char     ev[120];
} OfxRes;
static OfxRes g_res[256];
static uint64_t g_known[256];

static uint64_t g_slots[256][64];
static int      g_nslots[256];
static uint64_t g_vtable[256];

static uint64_t ofx_rva(uint64_t vm) { return vm - g.vmbase; }
static const uint8_t *ofx_mem(uint64_t vm) { return (const uint8_t *)(uintptr_t)(g.slide + vm); }

static int ofx_parse_macho(void)
{
    const struct mach_header_64 *mh = (const struct mach_header_64 *)(uintptr_t)g.base;
    if (mh->magic != MH_MAGIC_64) { plog("Titanox[ofx]: bad magic"); return 0; }
    uint32_t nimg = _dyld_image_count();
    for (uint32_t k = 0; k < nimg; k++) {
        if ((uint64_t)(uintptr_t)_dyld_get_image_header(k) == g.base) {
            g.slide = (uint64_t)(intptr_t)_dyld_get_image_vmaddr_slide(k);
            break;
        }
    }
    const uint8_t *p = (const uint8_t *)mh + sizeof(struct mach_header_64);
    const uint8_t *lend = p + 0x10000;
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (p + sizeof(struct load_command) > lend) break;
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command)) break;
        if (p + lc->cmdsize > lend) break;
        if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *sc = (const struct segment_command_64 *)lc;
            if (g.vmbase == 0 && sc->filesize) {
                g.vmbase = sc->vmaddr;
                if (!g.slide) g.slide = g.base - g.vmbase;
            }
            if (g_nsegs < 64) {
                OfxSeg *s = &g_segs[g_nsegs++];
                s->vmaddr = sc->vmaddr; s->vmsize = sc->vmsize;
                s->fileoff = sc->fileoff; s->filesize = sc->filesize; s->initprot = sc->initprot;
                s->is_data_like = (sc->initprot & VM_PROT_WRITE) && (sc->initprot & VM_PROT_READ);
                strlcpy(s->name, sc->segname, sizeof(s->name));
            }
            const struct section_64 *sec = (const struct section_64 *)((const uint8_t *)sc + sizeof(struct segment_command_64));
            for (uint32_t j = 0; j < sc->nsects && g_nsecs < 400; j++) {
                OfxSec *d = &g_secs[g_nsecs++];
                strlcpy(d->sect, sec[j].sectname, sizeof(d->sect));
                strlcpy(d->seg, sec[j].segname, sizeof(d->seg));
                d->vmaddr = sec[j].addr; d->size = sec[j].size;
            }
        } else if (lc->cmd == LC_SYMTAB) {
            const struct symtab_command *st = (const struct symtab_command *)lc;
            if (st->nsyms) {
                g.sym_addr = g.slide;
                g.nsyms = st->nsyms;
                g.str_addr = g.slide + st->stroff;
                g.strsize = st->strsize;
            }
        } else if (lc->cmd == LC_FUNCTION_STARTS) {
            const struct linkedit_data_command *ld = (const struct linkedit_data_command *)lc;
            if (ld->datasize) {
                g.fs_addr = g.slide + ld->dataoff;
                g.fs_size = ld->datasize;
            }
        }
        p += lc->cmdsize;
    }
    g.clsn_vm = 0; g.clsn_size = 0;
    for (int i = 0; i < g_nsecs; i++) {
        OfxSec *d = &g_secs[i];
        if (!strcmp(d->sect, "__text") && d->size > g.text_size) { g.text_vm = d->vmaddr; g.text_size = d->size; }
        if (!strcmp(d->sect, "__cstring")) { g.cstr_vm = d->vmaddr; g.cstr_size = d->size; }
        if (!strcmp(d->sect, "__objc_methname")) { g.meth_vm = d->vmaddr; g.meth_size = d->size; }
        if (!strcmp(d->sect, "__objc_classname")) { g.clsn_vm = d->vmaddr; g.clsn_size = d->size; }
        if (!strcmp(d->sect, "__const")) { g.const_vm = d->vmaddr; g.const_size = d->size; }
        if (!strcmp(d->sect, "__data")) { g.data_vm = d->vmaddr; g.data_size = d->size; }
    }
    plog("Titanox[ofx]: slide=0x%llx vmbase=0x%llx text=0x%llx/%llu cstr=%llu clsn=%llu meth=%llu const=%llu data=%llu",
           (unsigned long long)g.slide, (unsigned long long)g.vmbase,
           (unsigned long long)g.text_vm, (unsigned long long)g.text_size,
           (unsigned long long)g.cstr_size, (unsigned long long)g.clsn_size,
           (unsigned long long)g.meth_size, (unsigned long long)g.const_size,
           (unsigned long long)g.data_size);
    return (g.text_vm && (g.cstr_vm || g.clsn_vm || g.meth_vm || g.const_vm || g.data_vm));
}

static uint64_t ofx_find_substr_in(uint64_t vm, uint64_t size, const char *s, int *count)
{
    if (!vm || !size) return 0;
    size_t want = strlen(s);
    if (!want || want > 200) return 0;
    const uint8_t *p = (const uint8_t *)ofx_mem(vm);
    const uint8_t *end = p + size;
    uint64_t first = 0;
    while (p + want < end) {
        if (!memcmp(p, s, want)) {
            if (count) (*count)++;
            if (!first) first = vm + (uint64_t)(p - (const uint8_t *)ofx_mem(vm));
        }
        p++;
    }
    return first;
}

static uint64_t ofx_find_any(const char *s, int *total_count)
{
    int c = 0;
    uint64_t first = 0;
    uint64_t r = ofx_find_substr_in(g.cstr_vm, g.cstr_size, s, &c);
    if (r && !first) first = r;
    r = ofx_find_substr_in(g.const_vm, g.const_size, s, &c);
    if (r && !first) first = r;
    r = ofx_find_substr_in(g.data_vm, g.data_size, s, &c);
    if (r && !first) first = r;
    r = ofx_find_substr_in(g.meth_vm, g.meth_size, s, &c);
    if (r && !first) first = r;
    if (total_count) *total_count = c;
    return first;
}

static uint64_t ofx_typeinfo_for_name(uint64_t str_vm)
{
    uint64_t secs[2][2] = { { g.const_vm, g.const_size }, { g.data_vm, g.data_size } };
    for (int k = 0; k < 2; k++) {
        if (!secs[k][0] || !secs[k][1]) continue;
        const uint64_t *p = (const uint64_t *)ofx_mem(secs[k][0]);
        uint64_t n = secs[k][1] / 8;
        for (uint64_t i = 1; i + 1 < n; i++) {
            if (p[i] == g.slide + str_vm && p[i - 1] == 0) return secs[k][0] + i * 8;
        }
    }
    return 0;
}

static int ofx_is_code_vm(uint64_t vm) { return vm >= g.text_vm && vm < g.text_vm + g.text_size; }

static void ofx_vtable_scan(int ti)
{
    const OfxTarget *t = &g_targets[ti];
    if (!t->cls[0]) return;
    int cnt = 0;
    uint64_t sv = ofx_find_any(t->cls, &cnt);
    if (!sv) { plog("Titanox[ofx][vt]: no string '%s'", t->cls); return; }
    plog("Titanox[ofx][vt]: '%s' found %d times, first at 0x%llx", t->cls, cnt, (unsigned long long)(sv - g.vmbase));
    uint64_t tiname = ofx_typeinfo_for_name(sv);
    if (!tiname) { plog("Titanox[ofx][vt]: no typeinfo for '%s'", t->cls); return; }
    uint64_t vt_ptr = 0;
    memcpy(&vt_ptr, ofx_mem(tiname - 8), 8);
    uint64_t vt_vm = vt_ptr & 0x0000FFFFFFFFFFFFULL;
    if (!vt_vm || (int64_t)vt_vm > 0) {
        vt_vm = vt_ptr - g.slide;
    }
    if (!vt_vm) { plog("Titanox[ofx][vt]: null vtable for '%s'", t->cls); return; }

    g_vtable[ti] = vt_vm;
    int n = 0;
    const uint64_t *slots = (const uint64_t *)ofx_mem(vt_vm + 16);
    for (int i = 0; i < 64; i++) {
        uint64_t v = slots[i];
        if (!v) break;
        uint64_t fn = v & 0x0000FFFFFFFFFFFFULL;
        if (!fn || (int64_t)fn < 0) fn = (v - g.slide) & 0x0000FFFFFFFFFFFFULL;
        uint64_t rva;
        if (fn >= g.text_vm && fn < g.text_vm + g.text_size) rva = fn;
        else if ((v - g.slide) >= g.text_vm && (v - g.slide) < g.text_vm + g.text_size) rva = v - g.slide;
        else break;
        g_slots[ti][n++] = rva;
    }
    g_nslots[ti] = n;
    plog("Titanox[ofx][vt]: %s vtable=0x%llx slots=%d", t->cls, (unsigned long long)ofx_rva(vt_vm), n);
}

static void ofx_vtable_all(void)
{
    for (int i = 0; i < g.ntargets; i++) ofx_vtable_scan(i);
}

static void ofx_vtable_dump(void)
{
    if (g_nresolved == 0 && g_vtable[0] == 0) return;
    char path[700];
    snprintf(path, sizeof(path), "%s/titanox_vtables.txt", ofx_dir());
    FILE *f = fopen(path, "w");
    if (!f) return;
    for (int i = 0; i < g.ntargets; i++) {
        if (!g_vtable[i]) continue;
        fprintf(f, "=== %s (vtable=0x%llx, slots=%d) ===\n",
                g_targets[i].cls, (unsigned long long)ofx_rva(g_vtable[i]), g_nslots[i]);
        for (int k = 0; k < g_nslots[i]; k++)
            fprintf(f, "  slot[%2d] = 0x%llx\n", k, (unsigned long long)g_slots[i][k]);
        fprintf(f, "\n");
    }
    fclose(f);
    plog("Titanox[ofx][vt]: dump written %s", path);
}

static void ofx_ctor_from_vtable(int ti)
{
    const OfxTarget *t = &g_targets[ti];
    if (t->kind != OFX_K_CTOR || !g_vtable[ti]) return;
    uint64_t vt = g_vtable[ti];
    for (int i = 0; i < g_nsegs; i++) {
        if (!g_segs[i].is_data_like) continue;
        const uint64_t *p = (const uint64_t *)ofx_mem(g_segs[i].vmaddr);
        uint64_t n = g_segs[i].vmsize / 8;
        for (uint64_t k = 0; k < n; k++) {
            uint64_t v = p[k];
            if (v != g.slide + vt) continue;
            uint64_t ref_vm = g_segs[i].vmaddr + k * 8;
            const uint32_t *code = (const uint32_t *)ofx_mem(g.text_vm);
            uint64_t cn = g.text_size / 4;
            for (uint64_t j = 0; j < cn; j++) {
                uint64_t pc = g.text_vm + j * 4;
                uint64_t page = pc & ~0xFFFULL;
                uint32_t ins = code[j];
                if ((ins & 0x9F000000) != 0x90000000) continue;
                int64_t immlo = (ins >> 29) & 3;
                int64_t immhi = (ins >> 5) & 0x7FFFF;
                int64_t imm = (immhi << 2) | immlo;
                if (imm & (1LL << 20)) imm -= (1LL << 21);
                uint64_t tgt_page = page + (imm << 12);
                if ((tgt_page & 0xFFFFF000) != (ref_vm & 0xFFFFF000)) continue;
                for (int m = 1; m <= 3; m++) {
                    uint32_t i2 = code[j + m];
                    if ((i2 & 0xFF000000) == 0x91000000) {
                        int64_t add = (i2 >> 10) & 0xFFF;
                        if (i2 & (1 << 22)) add <<= 12;
                        int rn = (i2 >> 5) & 0x1F;
                        int rd = i2 & 0x1F;
                        (void)rn; (void)rd;
                        if (tgt_page + add == ref_vm) {
                            uint64_t fn = 0;
                            for (int s = 0; s < g.nfstarts; s++)
                                if (g.fstarts[s] <= pc) fn = g.fstarts[s];
                                else break;
                            if (fn) {
                                g_res[ti].rva = ofx_rva(fn);
                                g_res[ti].src = OFX_S_VTABLE;
                                g_res[ti].conf = OFX_C_HIGH;
                                snprintf(g_res[ti].ev, sizeof(g_res[ti].ev), "ctor пишет vtable");
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
}

static int ofx_index(const char *name)
{
    if (!name) return -1;
    for (int i = 0; i < g.ntargets; i++)
        if (!strcmp(g_targets[i].name, name)) return i;
    return -1;
}

static void OfxSetKnown(const char *name, uint64_t rva)
{
    int i = ofx_index(name);
    if (i < 0 || !rva) return;
    g_known[i] = rva;
    g_res[i].rva = rva;
    g_res[i].src = OFX_S_HEADER;
    g_res[i].conf = OFX_C_HIGH;
    snprintf(g_res[i].ev, sizeof(g_res[i].ev), "offsets.h");
}

static uint64_t OfxRVA(const char *name) { int i = ofx_index(name); return i < 0 ? 0 : g_res[i].rva; }
static uint64_t OfxAddr(const char *name) { int i = ofx_index(name); return i < 0 || !g_res[i].rva ? 0 : g.base + g_res[i].rva; }
static OfxSource OfxSourceOf(const char *name) { int i = ofx_index(name); return i < 0 ? OFX_S_NONE : (OfxSource)g_res[i].src; }
static OfxConf   OfxConfOf(const char *name) { int i = ofx_index(name); return i < 0 ? OFX_C_LOW : (OfxConf)g_res[i].conf; }

static const char *ofx_src_name(uint8_t s)
{
    switch (s) {
    case OFX_S_HEADER:  return "header";
    case OFX_S_SYMTAB:  return "symtab";
    case OFX_S_LOGSTR:  return "logstr";
    case OFX_S_OBJC:    return "objc";
    case OFX_S_BARESTR: return "bare";
    case OFX_S_GETINST: return "getinst";
    case OFX_S_VTABLE:  return "vtable";
    default:            return "none";
    }
}

static void ofx_summary(void)
{
    g_nresolved = 0;
    memset(g_by_src, 0, sizeof(g_by_src));
    for (int i = 0; i < g.ntargets; i++)
        if (g_res[i].rva) { g_nresolved++; if (g_res[i].src < 8) g_by_src[g_res[i].src]++; }
    plog("Titanox[ofx]: === ИТОГО %d/%d === header=%d symtab=%d logstr=%d objc=%d bare=%d getinst=%d vtable=%d",
           g_nresolved, g.ntargets, g_by_src[OFX_S_HEADER], g_by_src[OFX_S_SYMTAB], g_by_src[OFX_S_LOGSTR],
           g_by_src[OFX_S_OBJC], g_by_src[OFX_S_BARESTR], g_by_src[OFX_S_GETINST], g_by_src[OFX_S_VTABLE]);
    for (int i = 0; i < g.ntargets; i++) {
        if (g_res[i].rva)
            plog("  %-58s 0x%-9llx %-8s %s", g_targets[i].name,
                   (unsigned long long)g_res[i].rva, ofx_src_name(g_res[i].src), g_res[i].ev);
        else
            plog("  %-58s НЕ НАЙДЕН  %s", g_targets[i].name, g_res[i].ev);
    }
}

static FILE *ofx_open_out(const char *name)
{
    char path[700];
    snprintf(path, sizeof(path), "%s/%s", ofx_dir(), name);
    FILE *f = fopen(path, "w");
    if (f) plog("Titanox[ofx]: пишу %s", path);
    return f;
}

static void ofx_dump(void)
{
    if (g_nresolved == 0) {
        plog("Titanox[ofx]: 0 оффсетов, создаю диагностический файл.");
        FILE *d = ofx_open_out("titanox_diagnostic.txt");
        if (d) {
            fprintf(d, "cstring_vm=0x%llx size=%llu\n", (unsigned long long)g.cstr_vm, (unsigned long long)g.cstr_size);
            fprintf(d, "const_vm=0x%llx size=%llu\n", (unsigned long long)g.const_vm, (unsigned long long)g.const_size);
            fprintf(d, "data_vm=0x%llx size=%llu\n", (unsigned long long)g.data_vm, (unsigned long long)g.data_size);
            fprintf(d, "clsn_vm=0x%llx size=%llu\n", (unsigned long long)g.clsn_vm, (unsigned long long)g.clsn_size);
            fprintf(d, "meth_vm=0x%llx size=%llu\n", (unsigned long long)g.meth_vm, (unsigned long long)g.meth_size);
            for (int i = 0; i < g.ntargets; i++) {
                if (!g_targets[i].cls[0]) continue;
                int cnt = 0;
                uint64_t sv = ofx_find_any(g_targets[i].cls, &cnt);
                fprintf(d, "%s : %s : found=%d : first=0x%llx\n",
                        g_targets[i].name, g_targets[i].cls, cnt,
                        (unsigned long long)(sv ? sv - g.vmbase : 0));
            }
            fclose(d);
        }
        return;
    }
    FILE *h = ofx_open_out("titanox_offsets.h");
    if (h) {
        fprintf(h, "// titanox_offsets.h\n");
        fprintf(h, "// всего %d из %d\n", g_nresolved, g.ntargets);
        for (int i = 0; i < g.ntargets; i++) {
            char macro[128];
            size_t k = 0;
            macro[k++] = 'R'; macro[k++] = 'V'; macro[k++] = 'A'; macro[k++] = '_';
            for (const char *q = g_targets[i].name; *q && k < sizeof(macro) - 1; q++)
                macro[k++] = (char)((*q >= 'a' && *q <= 'z') ? *q - 32 : *q);
            macro[k] = 0;
            if (g_res[i].rva)
                fprintf(h, "#define %-70s 0x%llxULL  // %s %s\n", macro,
                        (unsigned long long)g_res[i].rva, ofx_src_name(g_res[i].src), g_res[i].ev);
            else
                fprintf(h, "// #define %-68s ?          // %s\n", macro, g_res[i].ev);
        }
        fclose(h);
    }
    FILE *t = ofx_open_out("titanox_offsets.txt");
    if (t) {
        fprintf(t, "# imageBase=0x%llx slide=0x%llx vmbase=0x%llx\n",
                (unsigned long long)g.base, (unsigned long long)g.slide, (unsigned long long)g.vmbase);
        fprintf(t, "# найдено %d / %d\n\n", g_nresolved, g.ntargets);
        for (int i = 0; i < g.ntargets; i++) {
            if (g_res[i].rva)
                fprintf(t, "%s = 0x%llx  # %s %s\n", g_targets[i].name,
                        (unsigned long long)g_res[i].rva, ofx_src_name(g_res[i].src), g_res[i].ev);
            else
                fprintf(t, "%s = NOT_FOUND  # %s\n", g_targets[i].name, g_res[i].ev);
        }
        fclose(t);
    }
}

static pthread_once_t g_once = PTHREAD_ONCE_INIT;
static uint64_t       g_init_base;

static void ofx_once_body(void)
{
    memset(g_res, 0, sizeof(g_res));
    memset(g_known, 0, sizeof(g_known));
    memset(g_vtable, 0, sizeof(g_vtable));
    memset(g_nslots, 0, sizeof(g_nslots));
    g.base = g_init_base;
    if (!g.base) return;
    g.ntargets = g_target_count;
    if (!ofx_parse_macho()) { plog("Titanox[ofx]: parse_macho failed"); return; }

    ofx_vtable_all();
    ofx_vtable_dump();

    for (int i = 0; i < g.ntargets; i++)
        if (g_targets[i].kind == OFX_K_CTOR)
            ofx_ctor_from_vtable(i);

    for (int i = 0; i < g.ntargets; i++) {
        if (g_known[i] && g_res[i].src != OFX_S_HEADER) {
            g_res[i].rva = g_known[i];
            g_res[i].src = OFX_S_HEADER;
            g_res[i].conf = OFX_C_HIGH;
            snprintf(g_res[i].ev, sizeof(g_res[i].ev), "offsets.h");
        }
    }
    g.inited = 1;
    ofx_summary();
}

static void Of_setxInit(uint64_t base)
String{
    g_init_base = base;
    pthread_once(&g_once, ofx_once_body);
}

static void OfxDumpReport(void) { if (g.inited) ofx_dump(); }

static void logcap(int *c, const char *fmt, ...)
{
    (*c)++;
    if (*c > OFX_LOG_L(void *selfIMIT) return;
    char buf[192)];
    va_list ap;
    va_start(ap, { fmt);
    vsnprintf(buf, sizeof(buf), static fmt, ap);
    int va_end(ap);
    plog("Titan nox: %s", buf);
;}

static bool hook_getBool(void * logself, const char *keycap)
{
    static int n;
    if (key(& && strlen(key) < 128n) {
        logcap(&n, ",getBool(%s)", key);
        if (strstr(key, " "isDev") || strstr(key,Anal "isDeveloper") ||
            strstr(key, "Disable") || strstr(key, "debug") ||
            strstr(key, "Debug") || strstr(key, "cheat"))
            return true;
    }
    return false;
}

static bool hook_isDev(void *self) { static int n; logcap(&n, "isDev"); return true; }
static bool hook_isDevBuild(void *self) { static int n; logcap(&n, "isDevBuild"); return true; }
static bool hook_isDeveloperBuild(void *self) { static int n; logcap(&n, "isDeveloperBuild"); return true; }
static void hook_GameButton_buttonPressed(void *self, int32_t buttonId) { static int n; logcap(&n, "GameButton_buttonPressed id=%d", buttonId); }
static void hook_GameButton_setText(void *self) { static int n; logcap(&n, "GameButton_setText"); }
static void hook_MessageManager_receiveMessage(void *self) { static int n; logcap(&n, "MessageManager_receiveMessage"); }
static void hook_GenericPopup_setTitle(void *self) { static int n; logcap(&n, "GenericPopup_setTitle"); }
static void hook_ClientInputManager_addInput(void *self) { static int n; logcap(&n, "ClientInputManager_addInput"); }
static void hook_LogicTileData_blocksMovement(void *self) { static int n; logcap(&n, "LogicTileData_blocksMovement"); }
static void hook_Screen_getDpiClass(void *self) { static int n; logcap(&n, "Screen_getDpiClass"); }
static void hook_GlobalID_getInstanceID(void *self) { static int n; logcap(&n, "GlobalID_getInstanceID"); }
static void hook_Projectile_ctor(void *self) { static int n; logcap(&n, "Projectile_ctor"); }
static void hook_AnalyticEvent_ctor(void *self) { static int n; logcap(&n, "AnalyticEvent_ctor"); }
static void hook_AnalyticEventyticEvent_setString"); }
static void hook_String_ctor(void *self) { static int n; logcap(&n, "String_ctor"); }

typedef struct {
    const char *tag;
    void *fn;
    int allow_low;
} OfxHookSpec;

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
    OfxSetKnown("__settings_getBool", 0);
#endif
#ifdef RVA_GAMEBUTTON_SETTEXT
    OfxSetKnown("GameButton_setText", RVA_GAMEBUTTON_SETTEXT);
#endif
#ifdef RVA_MESSAGEMANAGER_RECEIVEMESSAGE
    OfxSetKnown("MessageManager_receiveMessage", RVA_MESSAGEMANAGER_RECEIVEMESSAGE);
#endif
#ifdef RVA_LOGICPLAYERMAP_SAVE
    OfxSetKnown("LogicPlayerMap_save", RVA_LOGICPLAYERMAP_SAVE);
#endif
#ifdef RVA_STRING_FORMAT
    OfxSetKnown("String_format", RVA_STRING_FORMAT);
#endif
#ifdef RVA_SCREEN_WIDTH
    OfxSetKnown("Screen_widthGlobal", RVA_SCREEN_WIDTH);
#endif
#ifdef RVA_STAGE_INSTANCE
    OfxSetKnown("StageInstanceGlobalPtr", RVA_STAGE_INSTANCE);
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
#ifdef RVA_GENERICPOPUP_SETTITLE
    OfxSetKnown("GenericPopup_setTitle", RVA_GENERICPOPUP_SETTITLE);
#endif
#ifdef RVA_GLOBALID_GETINSTANCEID
    OfxSetKnown("GlobalID_getInstanceID", RVA_GLOBALID_GETINSTANCEID);
#endif
#ifdef RVA_LOGIC_TILEDATA_BLOCKSMOVEMENT
    OfxSetKnown("LogicTileData_blocksMovement", RVA_LOGIC_TILEDATA_BLOCKSMOVEMENT);
#endif
#ifdef RVA_PROJECTILE_CTOR
    OfxSetKnown("Projectile_ctor", RVA_PROJECTILE_CTOR);
#endif
#ifdef RVA_SCREEN_GETDPICLASS
    OfxSetKnown("Screen_getDpiClass", RVA_SCREEN_GETDPICLASS);
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
        if (!a) { plog("Titanox: %s not found, hook skipped", specs[i].tag); continue; }
        if (OfxConfOf(specs[i].tag) == OFX_C_LOW && !specs[i].allow_low && !OFX_ALLOW_LOW) {
            plog("Titanox: %s low confidence, hook skipped", specs[i].tag);
            continue;
        }
        [TitanoxHook addBreakpointAtAddress:(void *)a withHook:specs[i].fn];
        plog("Titanox: %s 0x%llx %s hooked", specs[i].tag,
               (unsigned long long)a, ofx_src_name(OfxSourceOf(specs[i].tag)));
        done++;
    }
    return done;
}

static void install_settings(uint64_t base)
{
    struct { const char *m; void *fn; } st[] = {
        { "getBool",          (void *)hook_getBool },
        { "isDev",            (void *)hook_isDev },
        { "isDevBuild",       (void *)hook_isDevBuild },
        { "isDeveloperBuild", (void *)hook_isDeveloperBuild },
        { NULL, NULL }
    };
#ifdef RVA_GETBOOL
    [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_GETBOOL) withHook:st[0].fn];
    plog("Titanox: settings getBool 0x%llx hooked", (unsigned long long)(base + RVA_GETBOOL));
#endif
#ifdef RVA_ISDEV
    [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_ISDEV) withHook:st[1].fn];
    plog("Titanox: settings isDev 0x%llx hooked", (unsigned long long)(base + RVA_ISDEV));
#endif
#ifdef RVA_ISDEVBUILD
    [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_ISDEVBUILD) withHook:st[2].fn];
    plog("Titanox: settings isDevBuild 0x%llx hooked", (unsigned long long)(base + RVA_ISDEVBUILD));
#endif
#ifdef RVA_ISDEVELOPERBUILD
    [TitanoxHook addBreakpointAtAddress:(void *)(base + RVA_ISDEVELOPERBUILD) withHook:st[3].fn];
    plog("Titanox: settings isDeveloperBuild 0x%llx hooked", (unsigned long long)(base + RVA_ISDEVELOPERBUILD));
#endif
}

__attribute__((constructor))
static void titanox_init(void)
{
    @autoreleasepool {
        uint64_t base = (uint64_t)[TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        if (!base) { plog("Titanox: base not found"); return; }
        plog("Titanox: base=0x%llx", (unsigned long long)base);

        feed_known();
        OfxInit(base);

        plog("Titanox: hooks installed %d", install_hooks(g_hooks));
        install_settings(base);

        OfxDumpReport();
        plog("Titanox: resolved %d/%d", g_nresolved, g_target_count);
    }
}