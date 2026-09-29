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
    OFX_S_DISPTAB
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

typedef struct {
    uint64_t page;
    int      rd;
    int      ok;
} OfxAdrp;

static inline OfxAdrp ofx_adrp(uint32_t ins, uint64_t pc)
{
    OfxAdrp r = { 0, 0, 0 };

    if ((ins & 0x9F000000u) != 0x90000000u) return r;
    int64_t immlo = (int64_t)((ins >> 29) & 3u);
    int64_t immhi = (int64_t)((ins >> 5) & 0x7FFFFu);
    int64_t imm = (immhi << 2) | immlo;
    if (imm & (1LL << 20)) imm -= (1LL << 21);
    r.page = (pc & ~0xFFFULL) + (uint64_t)(imm << 12);
    r.rd = (int)(ins & 0x1Fu);
    r.ok = 1;
    return r;
}

typedef struct {
    uint64_t value;
    int      rd;
    int      rn;
    int      ok;
} OfxAddImm;

static inline OfxAddImm ofx_add_imm(uint32_t ins, uint64_t base_page)
{
    OfxAddImm r = { 0, 0, 0, 0 };
    if ((ins & 0xFF000000u) != 0x91000000u) return r;
    uint64_t imm = (ins >> 10) & 0xFFFu;
    if (ins & (1u << 22)) imm <<= 12;
    r.rn = (int)((ins >> 5) & 0x1Fu);
    r.rd = (int)(ins & 0x1Fu);
    r.value = base_page + imm;
    r.ok = 1;
    return r;
}

typedef struct {
    uint64_t value;
    int      rt;
    int      rn;
    int      ok;
} OfxLdrImm;

static inline OfxLdrImm ofx_ldr_imm(uint32_t ins, uint64_t base_page)
{
    OfxLdrImm r = { 0, 0, 0, 0 };
    if ((ins & 0xFFC00000u) != 0xF9400000u) return r;
    uint64_t off = ((ins >> 10) & 0xFFFu) * 8u;
    r.rn = (int)((ins >> 5) & 0x1Fu);
    r.rt = (int)(ins & 0x1Fu);
    r.value = base_page + off;
    r.ok = 1;
    return r;
}

static inline int ofx_uleb128_next(const uint8_t *p, const uint8_t *end, uint64_t *out, size_t *used)
{
    uint64_t v = 0;
    int sh = 0;
    size_t i = 0;
    while (p + i < end) {
        uint8_t b = p[i++];
        v |= (uint64_t)(b & 0x7Fu) << sh;
        sh += 7;
        if (!(b & 0x80u)) { *out = v; *used = i; return 1; }
        if (sh > 63) return 0;
    }
    return 0;
}

static inline uint64_t ofx_find_func(uint64_t addr, const uint64_t *starts, int n)
{
    if (!starts || n <= 0 || addr < starts[0]) return 0;
    int lo = 0, hi = n - 1, best = -1;
    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;
        if (starts[mid] <= addr) { best = mid; lo = mid + 1; }
        else hi = mid - 1;
    }
    return best < 0 ? 0 : starts[best];
}

#define OFX_CHAIN_MASK 0xFFFFFFFFFULL
#define OFX_PTR_MASK   0x00FFFFFFFFFFFFFFULL

static inline int ofx_ptr_candidates(uint64_t v, uint64_t image_base, uint64_t out[4])
{
    int n = 0;
    if (!v) return 0;
    out[n++] = v & OFX_PTR_MASK;
    out[n++] = v & OFX_CHAIN_MASK;
    out[n++] = image_base + (v & OFX_CHAIN_MASK);
    uint64_t h8 = (v >> 56) & 0xFFu;
    if (h8) out[n++] = (h8 << 56) | (v & OFX_CHAIN_MASK);
    return n;
}

static inline int ofx_is_ident_start(char c) { return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_'; }
static inline int ofx_is_ident_char(char c)  { return ofx_is_ident_start(c) || (c >= '0' && c <= '9'); }

typedef struct {
    const char *cls;
    size_t      cls_len;
    const char *method;
    size_t      method_len;
    int         ok;
} OfxPair;

static inline OfxPair ofx_parse_leading_pair(const char *s, size_t maxlen)
{
    OfxPair r = { 0, 0, 0, 0, 0 };
    size_t i = 0;
    if (!s || maxlen < 4) return r;
    if (!ofx_is_ident_start(s[0])) return r;

    const char *cls = 0;
    size_t      cls_len = 0;
    for (;;) {
        const char *start = s + i;
        size_t len = 0;
        while (i < maxlen && ofx_is_ident_char(s[i])) { i++; len++; }
        if (len == 0) return r;
        if (i + 1 < maxlen && s[i] == ':' && s[i + 1] == ':') {
            cls = start;
            cls_len = len;
            i += 2;
            continue;
        }
        if (i < maxlen && ofx_is_ident_char(s[i])) return r;
        if (cls == 0) return r;
        r.cls = cls;
        r.cls_len = cls_len;
        r.method = start;
        r.method_len = len;
        r.ok = 1;
        return r;
    }
}

static inline int ofx_is_word_char(char c)
{
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
}

static inline int ofx_lower(char c) { return (c >= 'A' && c <= 'Z') ? c + 32 : c; }

static inline const char *ofx_find_ci(const char *s, const char *w)
{
    size_t wl = strlen(w);
    for (const char *q = s; *q; q++) {
        size_t k = 0;
        while (k < wl && q[k] && ofx_lower(q[k]) == ofx_lower(w[k])) k++;
        if (k == wl) return q;
    }
    return 0;
}

static inline int ofx_camel_match(const char *s, const char *w, int cs)
{
    size_t wl = strlen(w);
    if (!s || !wl) return 0;
    const char *p = s;
    for (;;) {
        const char *hit = cs ? strstr(p, w) : ofx_find_ci(p, w);
        if (!hit) return 0;
        int left_ok = (hit == s) || !ofx_is_word_char(hit[-1]);
        int right_ok = !ofx_is_word_char(hit[wl]);
        if (!right_ok && hit[wl])
            right_ok = (ofx_lower(hit[wl - 1]) == hit[wl - 1]) && (hit[wl] >= 'A' && hit[wl] <= 'Z');
        if (left_ok && right_ok) return 1;
        p = hit + 1;
    }
}

#define OFX_MAX_SEG      64
#define OFX_MAX_SEC      400
#define OFX_MAX_FSTARTS  400000
#define OFX_MAX_HARVEST  8192
#define OFX_STR_MAXLEN   512
#define OFX_MAX_TARGETS  256
#define OFX_PAIRHASH_SZ  1024
#define OFX_HARVHASH_SZ  32768
#define OFX_PAIRMAP_SZ   8192

typedef struct { uint64_t vmaddr, vmsize, fileoff, filesize, initprot; int is_data_like; char name[20]; } OfxSeg;
typedef struct { char sect[20], seg[20]; uint64_t vmaddr, size; } OfxSec;

typedef struct {
    const char *cls; size_t cls_len;
    const char *method; size_t m_len;
    uint64_t str_vm;
    uint64_t fn_vm;
    const char *full;
} OfxHarv;

typedef struct {
    uint32_t h; int idx; int cnt;
    const char *k; size_t klen;
} OfxKey;

typedef struct {
    const char *k; const char *m; size_t klen, mlen; int idx;
} OfxHarvKey;

typedef struct {
    uint64_t a; int idx;
} OfxAddrEnt;

typedef struct {
    uint8_t  src, conf;
    uint64_t rva;
    uint64_t str_vm;
    char     ev[120];
} OfxRes;

static struct {
    int      inited;
    uint64_t base, slide, vmbase;
    OfxSeg   segs[OFX_MAX_SEG];  int nsegs;
    OfxSec   secs[OFX_MAX_SEC];  int nsecs;
    uint64_t text_vm, text_size;
    uint64_t cstr_vm, cstr_size;
    uint64_t meth_vm, meth_size;
    uint64_t sym_addr; uint32_t nsyms; uint64_t str_addr; uint32_t strsize;
    uint64_t fs_addr, fs_size;
    uint64_t *fstarts; int nfstarts;
    int      fs_fallback;
    int      ntargets;
} g;

static OfxRes   g_res[OFX_MAX_TARGETS];
static uint64_t g_known[OFX_MAX_TARGETS];
static char     g_pkey[OFX_MAX_TARGETS][80];
static OfxKey   g_pairhash[OFX_PAIRHASH_SZ];
static OfxKey   g_namehash[OFX_PAIRHASH_SZ];
static OfxHarv  g_harv[OFX_MAX_HARVEST];
static int      g_nharv;
static OfxHarvKey g_hkey[OFX_MAX_HARVEST];
static OfxAddrEnt g_haddr[OFX_HARVHASH_SZ];
static uint32_t g_hmap[OFX_PAIRMAP_SZ];
static int      g_nohash;

static uint32_t ofx_fnv(const char *s, size_t n)
{
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < n; i++) { h ^= (uint8_t)s[i]; h *= 16777619u; }
    return h;
}

static int ofx_printable(const char *s, size_t n)
{
    if (n == 0) return 0;
    for (size_t i = 0; i < n; i++) {
        unsigned char c = (unsigned char)s[i];
        if (c == '\t') continue;
        if (c < 0x20 || c > 0x7e) return 0;
    }
    return 1;
}

static const uint8_t *ofx_mem(uint64_t vm)
{
    return (const uint8_t *)(uintptr_t)(g.slide + vm);
}

static inline uint64_t ofx_rva(uint64_t vm) { return vm - g.vmbase; }

static const OfxTarget *ofx_target(int i) { return &g_targets[i]; }

static uint64_t ofx_fileoff_to_vm(uint64_t fileoff)
{
    for (int i = 0; i < g.nsegs; i++)
        if (g.segs[i].filesize && fileoff >= g.segs[i].fileoff &&
            fileoff < g.segs[i].fileoff + g.segs[i].filesize)
            return g.segs[i].vmaddr + (fileoff - g.segs[i].fileoff);
    for (int i = 0; i < g.nsegs; i++)
        if (fileoff >= g.segs[i].fileoff && fileoff < g.segs[i].fileoff + g.segs[i].vmsize)
            return g.segs[i].vmaddr + (fileoff - g.segs[i].fileoff);
    return 0;
}

static int ofx_parse_macho(void)
{
    const struct mach_header_64 *mh = (const struct mach_header_64 *)(uintptr_t)g.base;
    if (mh->magic != MH_MAGIC_64) {
        plog("Titanox[ofx]: bad magic 0x%08x (нужен arm64 Mach-O)", mh->magic);
        return 0;
    }
    g.vmbase = 0;
    g.slide = 0;
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
            if (g.nsegs < OFX_MAX_SEG) {
                OfxSeg *s = &g.segs[g.nsegs++];
                memset(s, 0, sizeof(*s));
                s->vmaddr = sc->vmaddr; s->vmsize = sc->vmsize;
                s->fileoff = sc->fileoff; s->filesize = sc->filesize; s->initprot = sc->initprot;
                s->is_data_like = (sc->initprot & VM_PROT_WRITE) && (sc->initprot & VM_PROT_READ);
                strlcpy(s->name, sc->segname, sizeof(s->name));
            }
            const struct section_64 *sec = (const struct section_64 *)((const uint8_t *)sc + sizeof(struct segment_command_64));
            for (uint32_t j = 0; j < sc->nsects && g.nsecs < OFX_MAX_SEC; j++) {
                OfxSec *d = &g.secs[g.nsecs++];
                strlcpy(d->sect, sec[j].sectname, sizeof(d->sect));
                strlcpy(d->seg, sec[j].segname, sizeof(d->seg));
                d->vmaddr = sec[j].addr; d->size = sec[j].size;
            }
        } else if (lc->cmd == LC_SYMTAB) {
            const struct symtab_command *st = (const struct symtab_command *)lc;
            if (st->nsyms && st->stroff && st->strsize) {
                g.sym_addr = g.slide + ofx_fileoff_to_vm(st->symoff);
                g.nsyms    = st->nsyms;
                g.str_addr = g.slide + ofx_fileoff_to_vm(st->stroff);
                g.strsize  = st->strsize;
            }
        } else if (lc->cmd == LC_FUNCTION_STARTS) {
            const struct linkedit_data_command *ld = (const struct linkedit_data_command *)lc;
            if (ld->datasize) {
                g.fs_addr = g.slide + ofx_fileoff_to_vm(ld->dataoff);
                g.fs_size = ld->datasize;
            }
        }
        p += lc->cmdsize;
    }
    for (int i = 0; i < g.nsecs; i++) {
        OfxSec *d = &g.secs[i];
        if (!strcmp(d->sect, "__text") && d->size > g.text_size) { g.text_vm = d->vmaddr; g.text_size = d->size; }
        if (!strcmp(d->sect, "__cstring"))                           { g.cstr_vm = d->vmaddr; g.cstr_size = d->size; }
        if (!strcmp(d->sect, "__objc_methname"))                     { g.meth_vm = d->vmaddr; g.meth_size = d->size; }
    }
    plog("Titanox[ofx]: slide=0x%llx vmbase=0x%llx text=0x%llx/%llu cstr=%llu syms=%u fs=%llu",
           (unsigned long long)g.slide, (unsigned long long)g.vmbase,
           (unsigned long long)g.text_vm, (unsigned long long)g.text_size,
           (unsigned long long)g.cstr_size, g.nsyms, (unsigned long long)g.fs_size);
    return (g.text_vm && g.cstr_vm);
}

static int ofx_is_prologue(uint32_t ins)
{
    if (ins == 0xD503237F) return 1;
    if (ins == 0xD503233F) return 1;
    if ((ins & 0xFFC07FFF) == 0xA9807BFD) return 1;
    if ((ins & 0xFF8003FF) == 0xD10003FF) return 1;
    return 0;
}

static int ofx_is_pad_or_end(uint32_t ins)
{
    if (ins == 0xD503201F) return 1;
    if (ins == 0xD65F03C0) return 1;
    if (ins == 0xD65F0FFF) return 1;
    if ((ins & 0xFF000000) == 0xD4000000) return 1;
    if (ins == 0x00000000) return 1;
    return 0;
}

static void ofx_scan_prologues(void)
{
    if (!g.text_vm || !g.text_size) return;
    const uint32_t *code = (const uint32_t *)ofx_mem(g.text_vm);
    uint64_t n = g.text_size / 4;
    for (uint64_t i = 0; i < n && g.nfstarts < OFX_MAX_FSTARTS; i++) {
        if (!ofx_is_prologue(code[i])) continue;
        if (i > 0 && !ofx_is_pad_or_end(code[i - 1])) continue;
        g.fstarts[g.nfstarts++] = g.text_vm + i * 4;
    }
    g.fs_fallback = 1;
    plog("Titanox[ofx]: function starts (prologue fallback): %d", g.nfstarts);
}

static void ofx_load_fstarts(void)
{
    g.fstarts = (uint64_t *)malloc(sizeof(uint64_t) * OFX_MAX_FSTARTS);
    if (!g.fstarts) return;
    if (g.fs_addr && g.fs_size > 8) {
        const uint8_t *p = (const uint8_t *)(uintptr_t)g.fs_addr;
        const uint8_t *end = p + g.fs_size;
        uint64_t acc = g.vmbase;
        while (p < end && g.nfstarts < OFX_MAX_FSTARTS) {
            uint64_t d = 0; size_t used = 0;
            if (!ofx_uleb128_next(p, end, &d, &used)) break;
            p += used;
            if (d == 0) break;
            acc += d;
            g.fstarts[g.nfstarts++] = acc;
        }
    }
    if (g.nfstarts == 0) {
        plog("Titanox[ofx]: LC_FUNCTION_STARTS пуст (fs=%llu) -- сканирую прологи", (unsigned long long)g.fs_size);
        ofx_scan_prologues();
    } else {
        plog("Titanox[ofx]: function starts (LC_FUNCTION_STARTS): %d", g.nfstarts);
    }
}

static void ofx_hinsert(OfxKey *t, int sz, const char *k, size_t klen, int idx)
{
    uint32_t h = ofx_fnv(k, klen);
    uint32_t i = h & (uint32_t)(sz - 1);
    for (int n = 0; n < sz; n++) {
        uint32_t j = (i + n) & (uint32_t)(sz - 1);
        if (t[j].k == 0) { t[j].h = h; t[j].k = k; t[j].klen = klen; t[j].idx = idx; t[j].cnt = 1; return; }
        if (t[j].h == h && t[j].klen == klen && !memcmp(t[j].k, k, klen)) { t[j].cnt++; return; }
    }
}

static int ofx_hfind(OfxKey *t, int sz, const char *k, size_t klen, int *cnt)
{
    uint32_t h = ofx_fnv(k, klen);
    uint32_t i = h & (uint32_t)(sz - 1);
    for (int n = 0; n < sz; n++) {
        uint32_t j = (i + n) & (uint32_t)(sz - 1);
        if (t[j].k == 0) return -1;
        if (t[j].h == h && t[j].klen == klen && !memcmp(t[j].k, k, klen)) {
            if (cnt) *cnt = t[j].cnt;
            return t[j].idx;
        }
    }
    return -1;
}

static void ofx_addr_put(uint64_t vm, int idx)
{
    uint32_t h = (uint32_t)((vm * 0x9E3779B97F4A7C15ULL) >> 40);
    uint32_t i = h & (uint32_t)(OFX_HARVHASH_SZ - 1);
    for (int n = 0; n < OFX_HARVHASH_SZ; n++) {
        uint32_t j = (i + n) & (uint32_t)(OFX_HARVHASH_SZ - 1);
        if (g_haddr[j].a == 0) { g_haddr[j].a = vm; g_haddr[j].idx = idx; return; }
        if (g_haddr[j].a == vm) return;
    }
}

static int ofx_addr_get(uint64_t vm)
{
    if (!vm) return -1;
    uint32_t h = (uint32_t)((vm * 0x9E3779B97F4A7C15ULL) >> 40);
    uint32_t i = h & (uint32_t)(OFX_HARVHASH_SZ - 1);
    for (int n = 0; n < OFX_HARVHASH_SZ; n++) {
        uint32_t j = (i + n) & (uint32_t)(OFX_HARVHASH_SZ - 1);
        if (g_haddr[j].a == 0) return -1;
        if (g_haddr[j].a == vm) return g_haddr[j].idx;
    }
    return -1;
}

static int ofx_harv_add(const OfxPair *pr, uint64_t str_vm, const char *full)
{
    if (g_nharv >= OFX_MAX_HARVEST) return -1;
    uint32_t h = ofx_fnv(pr->cls, pr->cls_len) ^ ofx_fnv(pr->method, pr->method_len);
    uint32_t i = h & (OFX_PAIRMAP_SZ - 1);
    for (int n = 0; n < OFX_PAIRMAP_SZ; n++) {
        uint32_t j = (i + n) & (OFX_PAIRMAP_SZ - 1);
        int idx = (int)g_hmap[j];
        if (idx == 0) {
            g_hmap[j] = (uint32_t)(g_nharv + 1);
            OfxHarv *e = &g_harv[g_nharv];
            e->cls = pr->cls; e->cls_len = pr->cls_len;
            e->method = pr->method; e->m_len = pr->method_len;
            e->str_vm = str_vm; e->fn_vm = 0; e->full = full;
            g_hkey[g_nharv].k = pr->cls; g_hkey[g_nharv].klen = pr->cls_len;
            g_hkey[g_nharv].m = pr->method; g_hkey[g_nharv].mlen = pr->method_len;
            g_nharv++;
            return g_nharv - 1;
        }
        OfxHarvKey *k = &g_hkey[idx - 1];
        if (k->klen == pr->cls_len && k->mlen == pr->method_len &&
            !memcmp(k->k, pr->cls, pr->cls_len) && !memcmp(k->m, pr->method, pr->method_len))
            return idx - 1;
    }
    g_nohash++;
    return -1;
}

static int ofx_is_ctor(const OfxTarget *t) { return t->kind == OFX_K_CTOR; }

static void ofx_hints_of(const OfxTarget *t, char hints[4][32], int *nh)
{
    *nh = 0;
    if (t->kind != OFX_K_GLOBAL) return;
    const char *rest = t->name;
    const char *cls = t->cls;
    size_t cl = strlen(cls);
    if (cl && !strncmp(rest, cls, cl)) rest += cl;

    char buf[64]; size_t bl = 0;
    for (const char *q = rest; *q && bl < sizeof(buf) - 1; q++) {
        if ((*q >= 'A' && *q <= 'Z') && bl > 0 && buf[bl - 1] >= 'a' && buf[bl - 1] <= 'z') buf[bl++] = ' ';
        buf[bl++] = *q;
    }
    buf[bl] = 0;
    char *save = 0;
    for (char *w = strtok_r(buf, "_ ", &save); w && *nh < 4; w = strtok_r(0, "_ ", &save)) {
        char low[32]; size_t i = 0;
        for (; w[i] && i < sizeof(low) - 1; i++) low[i] = (char)((w[i] >= 'A' && w[i] <= 'Z') ? w[i] + 32 : w[i]);
        low[i] = 0;
        if (!low[0] || !strcmp(low, "global") || !strcmp(low, "ptr") || !strcmp(low, "instance")) continue;
        int dup = 0;
        for (int k = 0; k < *nh; k++) if (!strcmp(hints[k], w)) dup = 1;
        if (!dup) strlcpy(hints[(*nh)++], w, 32);
    }
}

static void ofx_build_keymaps(void)
{
    memset(g_pairhash, 0, sizeof(g_pairhash));
    memset(g_namehash, 0, sizeof(g_namehash));
    g.ntargets = g_target_count;
    if (g.ntargets > OFX_MAX_TARGETS) g.ntargets = OFX_MAX_TARGETS;

    for (int i = 0; i < g.ntargets; i++) {
        const OfxTarget *t = ofx_target(i);
        if (t->kind == OFX_K_GLOBAL || t->kind == OFX_K_VTABLE) continue;
        const char *m = ofx_is_ctor(t) ? t->cls : t->method;
        snprintf(g_pkey[i], sizeof(g_pkey[i]), "%s::%s", t->cls, m);
        ofx_hinsert(g_pairhash, OFX_PAIRHASH_SZ, g_pkey[i], strlen(g_pkey[i]), i);

        ofx_hinsert(g_namehash, OFX_PAIRHASH_SZ, t->method, strlen(t->method), i);
    }
}

static int ofx_shared_method(const char *m)
{
    int cnt = 0;
    ofx_hfind(g_namehash, OFX_PAIRHASH_SZ, m, strlen(m), &cnt);
    return cnt > 1;
}

static void ofx_set_ev(int tgt, uint64_t str_vm, const char *fmt, const char *arg, int tier)
{
    OfxRes *r = &g_res[tgt];
    if (r->src == OFX_S_HEADER) return;
    if (r->src != OFX_S_NONE && !(r->src == OFX_S_LOGSTR && tier == 0 && r->conf < OFX_C_HIGH)) return;
    r->str_vm = str_vm;
    if (arg) snprintf(r->ev, sizeof(r->ev), fmt, arg);
    else     snprintf(r->ev, sizeof(r->ev), "%s", fmt);
    r->src = OFX_S_LOGSTR;
    r->conf = (tier == 0) ? OFX_C_HIGH : OFX_C_MED;
}

static void ofx_scan_pairs_inside(const char *s, size_t n, uint64_t str_vm)
{
    for (size_t i = 0; i + 2 < n; i++) {
        if (s[i] != ':' || s[i + 1] != ':') continue;

        size_t a = i;
        while (a > 0 && ofx_is_ident_char(s[a - 1])) a--;
        if (a == i) continue;
        const char *cs = s + a;
        size_t cl = i - a;

        size_t b = i + 2;
        size_t ms = b;
        while (b < n && ofx_is_ident_char(s[b])) b++;
        size_t ml = b - ms;
        if (!ml) continue;
        if (b < n && ofx_is_ident_char(s[b])) continue;
        char key[80];
        if (cl + ml + 2 >= sizeof(key)) continue;
        memcpy(key, cs, cl); key[cl] = 0;
        key[cl] = ':'; key[cl + 1] = ':';
        memcpy(key + cl + 2, s + ms, ml); key[cl + 2 + ml] = 0;
        int idx = ofx_hfind(g_pairhash, OFX_PAIRHASH_SZ, key, cl + 2 + ml, 0);
        if (idx >= 0 && g_res[idx].src != OFX_S_HEADER) {
            char ev[128];
            snprintf(ev, sizeof(ev), "'%.*s'", (int)(cl + 2 + ml), key);
            ofx_set_ev(idx, str_vm, "", ev, 1);
        }
    }
}

static void ofx_note_string(const char *s, size_t n, uint64_t str_vm)
{
    OfxPair pr = ofx_parse_leading_pair(s, n);
    if (pr.ok) {
        int hi = ofx_harv_add(&pr, str_vm, s);
        (void)hi;
    }

    char key[80];
    if (pr.ok && pr.cls_len + pr.method_len + 2 < sizeof(key)) {
        memcpy(key, pr.cls, pr.cls_len);
        key[pr.cls_len] = ':'; key[pr.cls_len + 1] = ':';
        memcpy(key + pr.cls_len + 2, pr.method, pr.method_len);
        key[pr.cls_len + 2 + pr.method_len] = 0;
        size_t kl = pr.cls_len + 2 + pr.method_len;
        int idx = ofx_hfind(g_pairhash, OFX_PAIRHASH_SZ, key, kl, 0);
        if (idx >= 0) {
            char ev[128];
            snprintf(ev, sizeof(ev), "'%.*s'", (int)(n > 60 ? 60 : n), s);
            ofx_set_ev(idx, str_vm, "", ev, 0);
        }
    }
    if (n == 0 || n >= 64) return;

    char name[64];
    memcpy(name, s, n); name[n] = 0;
    if (!ofx_is_ident_start(name[0])) return;
    for (size_t i = 0; i < n; i++) if (!ofx_is_ident_char(name[i])) return;
    int cnt = 0;
    int idx = ofx_hfind(g_namehash, OFX_PAIRHASH_SZ, name, n, &cnt);
    if (idx >= 0 && cnt == 1 && g_res[idx].src == OFX_S_NONE && !ofx_is_ctor(ofx_target(idx)) && !ofx_shared_method(name)) {
        g_res[idx].str_vm = str_vm;
        snprintf(g_res[idx].ev, sizeof(g_res[idx].ev), "'%s'", name);
        ofx_addr_put(str_vm, OFX_MAX_HARVEST + idx);
    }
    ofx_scan_pairs_inside(s, n, str_vm);
}

static void ofx_scan_strings(void)
{
    uint64_t secs[2][2] = { { g.cstr_vm, g.cstr_size }, { g.meth_vm, g.meth_size } };
    for (int k = 0; k < 2; k++) {
        if (!secs[k][0] || !secs[k][1]) continue;
        const char *p = (const char *)ofx_mem(secs[k][0]);
        const char *end = p + secs[k][1];
        while (p < end) {
            size_t n = 0;
            while (p + n < end && p[n]) n++;
            if (n >= 3 && n <= OFX_STR_MAXLEN && ofx_printable(p, n))
                ofx_note_string(p, n, secs[k][0] + (uint64_t)(p - (const char *)ofx_mem(secs[k][0])));
            p += n + 1;
        }
    }
    for (int i = 0; i < g_nharv; i++) ofx_addr_put(g_harv[i].str_vm, i);
    plog("Titanox[ofx]: harvest pairs=%d (не влезло %d)", g_nharv, g_nohash);
}

static void ofx_note_bare_xref(int tgt, uint64_t fn_vm)
{
    if (tgt < 0 || tgt >= g.ntargets) return;
    if (g_res[tgt].src == OFX_S_NONE) {
        g_res[tgt].src = OFX_S_BARESTR;
        g_res[tgt].conf = OFX_C_MED;
    }
    if (!g_res[tgt].rva) g_res[tgt].rva = ofx_rva(fn_vm);
}

static void ofx_scan_xrefs(void)
{
    if (!g.text_vm || !g.nfstarts) { plog("Titanox[ofx]: нет __text или function starts"); return; }
    const uint32_t *code = (const uint32_t *)ofx_mem(g.text_vm);
    uint64_t n = g.text_size / 4;
    int hit = 0;
    for (uint64_t i = 0; i + 6 < n; i++) {
        OfxAdrp a = ofx_adrp(code[i], g.text_vm + i * 4);
        if (!a.ok) continue;
        uint64_t tgt = 0;
        for (int k = 1; k <= 6; k++) {
            uint32_t n2 = code[i + k];
            OfxAddImm ad = ofx_add_imm(n2, a.page);
            if (ad.ok && ad.rn == a.rd) { tgt = ad.value; break; }
            OfxLdrImm ld = ofx_ldr_imm(n2, a.page);
            if (ld.ok && ld.rn == a.rd) { tgt = ld.value; break; }
        }
        if (!tgt) continue;
        int hi = ofx_addr_get(tgt);
        if (hi < 0) continue;
        uint64_t fn = ofx_find_func(g.text_vm + i * 4, g.fstarts, g.nfstarts);
        if (!fn) continue;
        if (hi < OFX_MAX_HARVEST) {
            if (!g_harv[hi].fn_vm) { g_harv[hi].fn_vm = fn; hit++; }
        } else {
            ofx_note_bare_xref(hi - OFX_MAX_HARVEST, fn);
            hit++;
        }
    }
    plog("Titanox[ofx]: xref найдено %d", hit);
}

static void ofx_finalize_logstr(void)
{
    for (int i = 0; i < g.ntargets; i++) {
        OfxRes *r = &g_res[i];
        if (r->src != OFX_S_LOGSTR || r->rva) continue;
        if (g.fs_fallback) r->conf = OFX_C_MED;
        int hi = ofx_addr_get(r->str_vm);
        if (hi >= 0 && hi < OFX_MAX_HARVEST && g_harv[hi].fn_vm) {
            r->rva = ofx_rva(g_harv[hi].fn_vm);
        } else {
            snprintf(r->ev, sizeof(r->ev), "строка есть, но ссылок из кода нет");
            r->src = OFX_S_NONE;
            r->str_vm = 0;
        }
    }
}

static int ofx_bad_symbol(const char *n)
{
    static const char *bad[] = { "s_", "s__", "_t", "_$s", "_objc_", "objc_", "$s", "__", "___" };
    char low[24];
    size_t i = 0;
    for (; n[i] && i < sizeof(low) - 1; i++) low[i] = (char)((n[i] >= 'A' && n[i] <= 'Z') ? n[i] + 32 : n[i]);
    low[i] = 0;
    for (unsigned k = 0; k < sizeof(bad) / sizeof(bad[0]); k++)
        if (!strncmp(low, bad[k], strlen(bad[k]))) return 1;
    if (strstr(low, "typeinfo") || strstr(low, "vftable") || strstr(low, "vtable")) return 1;
    return 0;
}

static int ofx_itanium_pair(const char *m, const char **cls, size_t *cl, const char **method, size_t *ml)
{
    if (!m || m[0] != '_' || m[1] != 'Z' || m[2] != 'N') return 0;
    const char *seen[16];
    size_t seenl[16];
    int n = 0;
    size_t i = 3;
    while (n < 16 && m[i] >= '0' && m[i] <= '9') {
        size_t len = 0;
        while (m[i] >= '0' && m[i] <= '9') { len = len * 10 + (size_t)(m[i] - '0'); i++; }
        if (!len) break;
        seen[n] = m + i;
        seenl[n] = len;
        n++;
        i += len;
    }
    if (n == 0) return 0;
    if (n == 1) {
        if (m[i] != 'C' && m[i] != 'D') return 0;
        *cls = seen[0]; *cl = seenl[0];
        *method = seen[0]; *ml = seenl[0];
        return 1;
    }
    *cls = seen[n - 2]; *cl = seenl[n - 2];
    *method = seen[n - 1]; *ml = seenl[n - 1];
    return 1;
}

static void ofx_symtab_funcs(void)
{
    if (!g.sym_addr || !g.nsyms) return;
    const struct nlist_64 *nl = (const struct nlist_64 *)(uintptr_t)g.sym_addr;
    const char *str = (const char *)(uintptr_t)g.str_addr;
    int found = 0, mangled = 0;
    for (uint32_t i = 0; i < g.nsyms; i++) {
        if ((nl[i].n_type & N_STAB) || (nl[i].n_type & N_TYPE) != N_SECT) continue;
        if (!nl[i].n_value || nl[i].n_un.n_strx >= g.strsize) continue;
        const char *nm = str + nl[i].n_un.n_strx;
        if (!nm[0]) continue;

        if (!strncmp(nm, "_Z", 2)) {
            mangled++;
            OfxPair mp;
            const char *mc = 0, *mm = 0;
            size_t mcl = 0, mml = 0;
            if (ofx_itanium_pair(nm, &mc, &mcl, &mm, &mml)) {
                mp.cls = mc; mp.cls_len = mcl; mp.method = mm; mp.method_len = mml;
            } else {
                mp = ofx_parse_leading_pair(nm, strlen(nm));
            }
            if (mp.cls && mp.cls_len && mp.method && mp.method_len) {
                char key[96];
                size_t kl = mp.cls_len + 2 + mp.method_len;
                if (kl < sizeof(key)) {
                    memcpy(key, mp.cls, mp.cls_len);
                    key[mp.cls_len] = ':';
                    key[mp.cls_len + 1] = ':';
                    memcpy(key + mp.cls_len + 2, mp.method, mp.method_len);
                    key[kl] = 0;
                    int idx = ofx_hfind(g_pairhash, OFX_PAIRHASH_SZ, key, kl, 0);
                    if (idx >= 0 && g_res[idx].src == OFX_S_NONE) {
                        g_res[idx].rva = ofx_rva(nl[i].n_value);
                        g_res[idx].src = OFX_S_SYMTAB;
                        g_res[idx].conf = OFX_C_HIGH;
                        snprintf(g_res[idx].ev, sizeof(g_res[idx].ev), "mangled %s", key);
                        found++;
                    }
                }
            }
            continue;
        }
        const char *canon = nm;
        if (canon[0] == '_') canon++;
        OfxPair pr = ofx_parse_leading_pair(canon, strlen(canon));
        if (!pr.ok) continue;
        char key[96];
        size_t kl = pr.cls_len + 2 + pr.method_len;
        if (kl >= sizeof(key)) continue;
        memcpy(key, pr.cls, pr.cls_len); key[pr.cls_len] = ':'; key[pr.cls_len + 1] = ':';
        memcpy(key + pr.cls_len + 2, pr.method, pr.method_len); key[kl] = 0;
        int idx = ofx_hfind(g_pairhash, OFX_PAIRHASH_SZ, key, kl, 0);
        if (idx >= 0 && g_res[idx].src == OFX_S_NONE) {
            g_res[idx].rva = ofx_rva(nl[i].n_value);
            g_res[idx].src = OFX_S_SYMTAB;
            g_res[idx].conf = OFX_C_HIGH;
            snprintf(g_res[idx].ev, sizeof(g_res[idx].ev), "sym %s", nm);
            found++;
        }
    }
    plog("Titanox[ofx]: symtab функций=%d ( mangled видели %d )", found, mangled);
}

static int ofx_sym_in_data(uint64_t vm)
{
    for (int i = 0; i < g.nsegs; i++)
        if (vm >= g.segs[i].vmaddr && vm < g.segs[i].vmaddr + g.segs[i].vmsize)
            return g.segs[i].is_data_like;
    return 0;
}

static int ofx_global_score(const char *name, const char *needle)
{
    char low[128], ln[64];
    size_t i = 0;
    for (; name[i] && i < sizeof(low) - 1; i++) low[i] = (char)((name[i] >= 'A' && name[i] <= 'Z') ? name[i] + 32 : name[i]);
    low[i] = 0;
    i = 0;
    for (; needle[i] && i < sizeof(ln) - 1; i++) ln[i] = (char)((needle[i] >= 'A' && needle[i] <= 'Z') ? needle[i] + 32 : needle[i]);
    ln[i] = 0;
    const char *n = low;
    if (n[0] == '_') n++;
    if (!strcmp(n, ln)) return 0;
    if (!strncmp(n, ln, strlen(ln)) && (n[strlen(ln)] == '_' || !strncmp(n + strlen(ln), "::", 2))) return 1;
    size_t nl = strlen(n), ll = strlen(ln);
    if (nl > ll && !strcmp(n + nl - ll, ln) && n[nl - ll - 1] == '_') return 2;
    if (ofx_camel_match(n, needle, 0)) return 3;
    return -1;
}

static void ofx_symtab_globals(void)
{
    if (!g.sym_addr || !g.nsyms) return;
    const struct nlist_64 *nl = (const struct nlist_64 *)(uintptr_t)g.sym_addr;
    const char *str = (const char *)(uintptr_t)g.str_addr;
    for (int t = 0; t < g.ntargets; t++) {
        const OfxTarget *tg = ofx_target(t);
        if (tg->kind != OFX_K_GLOBAL || g_res[t].src != OFX_S_NONE) continue;
        char hints[4][32]; int nh = 0;
        ofx_hints_of(tg, hints, &nh);
        int bs = 99, bh = -1, tie = 0;
        const char *bn = 0;
        for (uint32_t i = 0; i < g.nsyms; i++) {
            if ((nl[i].n_type & N_STAB) || (nl[i].n_type & N_TYPE) != N_SECT) continue;
            if (!nl[i].n_value || nl[i].n_un.n_strx >= g.strsize) continue;
            const char *nm = str + nl[i].n_un.n_strx;
            if (!nm[0] || ofx_bad_symbol(nm)) continue;
            if (!ofx_sym_in_data(nl[i].n_value)) continue;
            int sc = ofx_global_score(nm, tg->cls);
            if (sc < 0) continue;
            int hh = 0;
            for (int k = 0; k < nh; k++) if (ofx_camel_match(nm, hints[k], 0)) hh++;
            if (nh && hh == 0 && sc != 0) continue;
            if (sc < bs || (sc == bs && hh > bh)) { bs = sc; bh = hh; bn = nm; tie = 0; }
            else if (sc == bs && hh == bh) tie = 1;
        }
        if (bn && !tie) {
            uint64_t vm = 0;
            for (uint32_t i = 0; i < g.nsyms; i++)
                if (str + nl[i].n_un.n_strx == bn) { vm = nl[i].n_value; break; }
            if (vm) {
                g_res[t].rva = ofx_rva(vm);
                g_res[t].src = OFX_S_SYMTAB;
                g_res[t].conf = OFX_C_HIGH;
                snprintf(g_res[t].ev, sizeof(g_res[t].ev), "sym %s", bn);
            }
        }
    }
}

static void ofx_objc_pass(void)
{
    for (int t = 0; t < g.ntargets; t++) {
        const OfxTarget *tg = ofx_target(t);
        if (tg->kind == OFX_K_GLOBAL || tg->kind == OFX_K_VTABLE) continue;
        if (g_res[t].src != OFX_S_NONE || !tg->cls[0]) continue;
        Class c = objc_getClass(tg->cls);
        if (!c) continue;
        Method m = class_getInstanceMethod(c, sel_registerName(tg->method));
        if (!m) {
            char sel[128];
            snprintf(sel, sizeof(sel), "%s:", tg->method);
            m = class_getInstanceMethod(c, sel_registerName(sel));
        }
        if (!m) m = class_getClassMethod(c, sel_registerName(tg->method));
        if (!m) continue;
        void *imp = (void *)method_getImplementation(m);
        if (!imp) continue;
        uint64_t a = (uint64_t)(uintptr_t)imp;
        if (a < g.base || a > g.base + 0x40000000ULL) continue;
        g_res[t].rva = a - g.base;
        g_res[t].src = OFX_S_OBJC;
        g_res[t].conf = OFX_C_MED;
        snprintf(g_res[t].ev, sizeof(g_res[t].ev), "objc %s %s", tg->cls, tg->method);
    }
}

static uint64_t ofx_fn_for_pair(const char *cls, const char *method)
{
    size_t cl = strlen(cls), ml = strlen(method);
    for (int i = 0; i < g_nharv; i++) {
        if (g_harv[i].cls_len != cl || g_harv[i].m_len != ml) continue;
        if (!memcmp(g_harv[i].cls, cls, cl) && !memcmp(g_harv[i].method, method, ml))
            return g_harv[i].fn_vm;
    }
    return 0;
}

static int ofx_func_data_refs(uint64_t fn_vm, uint64_t *out, int cap)
{
    if (!fn_vm || !g.nfstarts) return 0;
    uint64_t end = fn_vm + 4096;
    for (int i = 0; i < g.nfstarts; i++)
        if (g.fstarts[i] > fn_vm) { end = g.fstarts[i]; break; }
    uint64_t tmax = g.text_vm + g.text_size;
    if (end > tmax) end = tmax;
    if (end > fn_vm + 16384) end = fn_vm + 16384;
    if (end <= fn_vm + 4) return 0;
    const uint32_t *code = (const uint32_t *)ofx_mem(fn_vm);
    uint64_t n = (end - fn_vm) / 4;
    int cnt = 0;
    for (uint64_t i = 0; i + 6 < n && cnt < cap; i++) {
        OfxAdrp a = ofx_adrp(code[i], fn_vm + i * 4);
        if (!a.ok) continue;
        for (int k = 1; k <= 4; k++) {
            OfxAddImm ad = ofx_add_imm(code[i + k], a.page);
            uint64_t tgt = 0; int is_ldr = 0;
            if (ad.ok && ad.rn == a.rd) tgt = ad.value;
            else {
                OfxLdrImm ld = ofx_ldr_imm(code[i + k], a.page);
                if (ld.ok && ld.rn == a.rd) { tgt = ld.value; is_ldr = 1; }
            }
            if (!tgt) continue;
            for (int s = 0; s < g.nsegs; s++) {
                if (tgt < g.segs[s].vmaddr || tgt >= g.segs[s].vmaddr + g.segs[s].vmsize) continue;
                if (!g.segs[s].is_data_like) break;
                int dup = 0;
                for (int q = 0; q < cnt; q++) if (out[q] == tgt) dup = 1;
                if (!dup && !is_ldr) out[cnt++] = tgt;
                break;
            }
            break;
        }
    }
    return cnt;
}

static void ofx_globals_getinst(void)
{
    for (int t = 0; t < g.ntargets; t++) {
        const OfxTarget *tg = ofx_target(t);
        if (tg->kind != OFX_K_GLOBAL || g_res[t].src != OFX_S_NONE) continue;
        uint64_t fn = ofx_fn_for_pair(tg->cls, "getInstance");
        if (!fn) continue;
        uint64_t cands[16];
        int n = ofx_func_data_refs(fn, cands, 16);
        uint64_t best = 0;
        for (int i = 0; i < n; i++) {
            if (cands[i] & 7) continue;
            uint64_t v = 0;
            memcpy(&v, ofx_mem(cands[i]), 8);
            uint64_t c[4];
            int nc = ofx_ptr_candidates(v, g.base, c);
            int ok = (v == 0);
            for (int k = 0; k < nc; k++)
                if (c[k] >= g.base && c[k] < g.base + 0x80000000ULL) {
                    for (int s = 0; s < g.nsegs; s++)
                        if (c[k] >= g.slide + g.segs[s].vmaddr && c[k] < g.slide + g.segs[s].vmaddr + g.segs[s].vmsize)
                            ok = 1;
                }
            if (ok) { best = cands[i]; break; }
        }
        if (best) {
            g_res[t].rva = ofx_rva(best);
            g_res[t].src = OFX_S_GETINST;
            g_res[t].conf = OFX_C_MED;
            snprintf(g_res[t].ev, sizeof(g_res[t].ev), "getInstance slot refs=%d", n);
        }
    }
}

static void ofx_disptab_pass(void)
{
    int found = 0;
    for (int t = 0; t < g.ntargets; t++) {
        OfxRes *r = &g_res[t];
        if (r->src != OFX_S_NONE && r->src != OFX_S_BARESTR) continue;
        if (!r->str_vm || r->rva) continue;
        for (int s = 0; s < g.nsegs; s++) {
            if (!g.segs[s].is_data_like) continue;
            uint64_t n = g.segs[s].vmsize / 8;
            const uint64_t *w = (const uint64_t *)ofx_mem(g.segs[s].vmaddr);
            for (uint64_t i = 0; i < n; i++) {
                uint64_t c[4];
                int nc = ofx_ptr_candidates(w[i], g.base, c);
                int hit = 0;
                for (int k = 0; k < nc; k++) if (c[k] == r->str_vm) hit = 1;
                if (!hit) continue;
                uint64_t wv = g.segs[s].vmaddr + i * 8;
                for (int d = -8; d <= 64; d += 8) {
                    uint64_t v2 = 0;
                    memcpy(&v2, ofx_mem(wv + d), 8);
                    uint64_t c2[4];
                    int n2 = ofx_ptr_candidates(v2, g.base, c2);
                    for (int k = 0; k < n2; k++) {
                        if (c2[k] < g.slide + g.text_vm || c2[k] > g.slide + g.text_vm + g.text_size) continue;
                        uint64_t vmv = c2[k] - g.slide;
                        if (!ofx_find_func(vmv, g.fstarts, g.nfstarts)) continue;
                        r->rva = ofx_rva(vmv);
                        r->src = OFX_S_DISPTAB;
                        r->conf = OFX_C_LOW;
                        snprintf(r->ev, sizeof(r->ev), "dispatch table + %d", d);
                        found++;
                        goto next_target;
                    }
                }
            }
        }
next_target: ;
    }
    plog("Titanox[ofx]: dispatch-table дал %d", found);
}

static int ofx_is_code_ptr(uint64_t vm)
{
    return vm >= g.text_vm && vm < g.text_vm + g.text_size;
}

static void ofx_vtable_tables(void)
{
    for (int t = 0; t < g.ntargets; t++) {
        const OfxTarget *tg = ofx_target(t);
        if (tg->kind != OFX_K_VTABLE || g_res[t].rva) continue;
        size_t cl = strlen(tg->cls);
        uint64_t m[8]; int nm = 0;
        for (int j = 0; j < g.ntargets && nm < 8; j++) {
            const OfxTarget *o = ofx_target(j);
            if (o->kind == OFX_K_VTABLE || !g_res[j].rva) continue;
            if (strncmp(o->cls, tg->cls, cl) || (o->cls[cl] && o->cls[cl] != '_')) continue;
            m[nm++] = g.vmbase + g_res[j].rva;
        }
        if (!nm) continue;
        for (int sidx = 0; sidx < g.nsegs && !g_res[t].rva; sidx++) {
            if (!g.segs[sidx].is_data_like) continue;
            uint64_t n = g.segs[sidx].vmsize / 8;
            const uint64_t *w = (const uint64_t *)ofx_mem(g.segs[sidx].vmaddr);
            for (uint64_t i = 0; i < n; i++) {
                int hit = 0;
                uint64_t c[4];
                int nc = ofx_ptr_candidates(w[i], g.base, c);
                for (int k = 0; k < nc && !hit; k++)
                    for (int q = 0; q < nm; q++)
                        if (c[k] == g.slide + m[q]) hit = 1;
                if (!hit) continue;
                uint64_t slot_vm = g.segs[sidx].vmaddr + i * 8;
                uint64_t base_vm = slot_vm;
                for (int back = 0; back < 64; back++) {
                    uint64_t prev = 0;
                    memcpy(&prev, ofx_mem(base_vm - 8), 8);
                    uint64_t c2[4];
                    int n2 = ofx_ptr_candidates(prev, g.base, c2);
                    int ok = 0;
                    for (int k = 0; k < n2; k++) if (ofx_is_code_ptr(c2[k] - g.slide)) ok = 1;
                    if (!ok) break;
                    base_vm -= 8;
                }
                g_res[t].rva = ofx_rva(base_vm);
                g_res[t].src = OFX_S_DISPTAB;
                g_res[t].conf = OFX_C_LOW;
                snprintf(g_res[t].ev, sizeof(g_res[t].ev), "таблица класса, слот %llu (по методам)",
                         (unsigned long long)((slot_vm - base_vm) / 8));
                break;
            }
        }
    }
}

static void ofx_guards(void)
{
    for (int i = 0; i < g.ntargets; i++) {
        if (!g_res[i].rva) continue;
        int same[OFX_MAX_TARGETS], ns = 0;
        for (int j = 0; j < g.ntargets; j++)
            if (g_res[j].rva == g_res[i].rva) same[ns++] = j;
        if (ns < 2) continue;
        if (ns >= 3) {
            for (int k = 0; k < ns; k++) {
                int t = same[k];
                snprintf(g_res[t].ev, sizeof(g_res[t].ev),
                         "адрес 0x%llx делят %d целей (общий хелпер)", (unsigned long long)g_res[t].rva, ns);
                g_res[t].rva = 0;
                g_res[t].src = OFX_S_NONE;
            }
        } else {
            int t0 = same[0], t1 = same[1];
            if (g_res[t0].src == OFX_S_BARESTR && g_res[t1].src == OFX_S_BARESTR) {

                g_res[t0].conf = OFX_C_LOW;
                g_res[t1].conf = OFX_C_LOW;
                if (!strstr(g_res[t0].ev, "ICF")) strlcat(g_res[t0].ev, " [ICF?]", sizeof(g_res[t0].ev));
                if (!strstr(g_res[t1].ev, "ICF")) strlcat(g_res[t1].ev, " [ICF?]", sizeof(g_res[t1].ev));
            } else {
                int keep = (g_res[t0].conf >= g_res[t1].conf) ? t0 : t1;
                int drop = (keep == t0) ? t1 : t0;
                snprintf(g_res[drop].ev, sizeof(g_res[drop].ev), "DUP: адрес занят %s", ofx_target(keep)->name);
                g_res[drop].rva = 0;
                g_res[drop].src = OFX_S_NONE;
            }
        }
    }
}

static const char *ofx_src_name(uint8_t s)
{
    switch (s) {
    case OFX_S_HEADER:  return "header";
    case OFX_S_SYMTAB:  return "symtab";
    case OFX_S_LOGSTR:  return "logstr";
    case OFX_S_OBJC:    return "objc";
    case OFX_S_BARESTR: return "bare";
    case OFX_S_GETINST: return "getinst";
    case OFX_S_DISPTAB: return "disptab";
    default:            return "none";
    }
}

static const char *OfxSourceName(OfxSource s) { return ofx_src_name((uint8_t)s); }

static int  g_nresolved;
static int  g_by_src[8];

static void ofx_summary(void)
{
    g_nresolved = 0;
    memset(g_by_src, 0, sizeof(g_by_src));
    for (int i = 0; i < g.ntargets; i++)
        if (g_res[i].rva) { g_nresolved++; if (g_res[i].src < 8) g_by_src[g_res[i].src]++; }
    plog("Titanox[ofx]: === ИТОГО %d/%d === header=%d symtab=%d logstr=%d objc=%d bare=%d getinst=%d disptab=%d",
           g_nresolved, g.ntargets, g_by_src[OFX_S_HEADER], g_by_src[OFX_S_SYMTAB], g_by_src[OFX_S_LOGSTR],
           g_by_src[OFX_S_OBJC], g_by_src[OFX_S_BARESTR], g_by_src[OFX_S_GETINST], g_by_src[OFX_S_DISPTAB]);
    for (int i = 0; i < g.ntargets; i++) {
        if (g_res[i].rva)
            plog("  %-58s 0x%-9llx %-8s %s", ofx_target(i)->name,
                   (unsigned long long)g_res[i].rva, ofx_src_name(g_res[i].src), g_res[i].ev);
        else
            plog("  %-58s НЕ НАЙДЕН  %s", ofx_target(i)->name, g_res[i].ev);
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
    FILE *h = ofx_open_out("titanox_offsets.h");
    if (h) {
        fprintf(h, "// titanox_offsets.h -- снято НА УСТРОЙСТВЕ (Titanox tweak)\n");
        fprintf(h, "// Вставляется вместо ручных RVA_* или как резерв, если Ghidra не нашла.\n");
        fprintf(h, "// источник: header=offsets.h symtab=LC_SYMTAB logstr='Class::method' objc=ObjC\n");
        fprintf(h, "//           bare=точная строка getinst=getInstance-слот disptab=dispatch-таблица\n");
        fprintf(h, "// всего %d из %d\n", g_nresolved, g.ntargets);
        for (int i = 0; i < g.ntargets; i++) {
            char macro[128];
            size_t k = 0;
            macro[k++] = 'R'; macro[k++] = 'V'; macro[k++] = 'A'; macro[k++] = '_';
            for (const char *q = ofx_target(i)->name; *q && k < sizeof(macro) - 1; q++)
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
        fprintf(t, "# offsets dump: imageBase=0x%llx slide=0x%llx vmbase=0x%llx\n",
                (unsigned long long)g.base, (unsigned long long)g.slide, (unsigned long long)g.vmbase);
        fprintf(t, "# text=0x%llx/%llu cstring=%llu function_starts=%d harvest=%d\n",
                (unsigned long long)g.text_vm, (unsigned long long)g.text_size,
                (unsigned long long)g.cstr_size, g.nfstarts, g_nharv);
        fprintf(t, "# найдено %d / %d\n\n", g_nresolved, g.ntargets);
        for (int i = 0; i < g.ntargets; i++) {
            if (g_res[i].rva)
                fprintf(t, "%s = 0x%llx  # %s %s\n", ofx_target(i)->name,
                        (unsigned long long)g_res[i].rva, ofx_src_name(g_res[i].src), g_res[i].ev);
            else
                fprintf(t, "%s = NOT_FOUND  # %s\n", ofx_target(i)->name, g_res[i].ev);
        }

        fprintf(t, "\n# === Class::method -> функция (весь harvest) ===\n");
        int printed = 0;
        for (int i = 0; i < g_nharv; i++) {
            if (!g_harv[i].fn_vm) continue;
            fprintf(t, "%.*s::%.*s = 0x%llx\n",
                    (int)g_harv[i].cls_len, g_harv[i].cls,
                    (int)g_harv[i].m_len, g_harv[i].method,
                    (unsigned long long)ofx_rva(g_harv[i].fn_vm));
            printed++;
        }
        fprintf(t, "\n# всего со ссылкой из кода: %d из %d пар\n", printed, g_nharv);
        fprintf(t, "# ВАЖНО: оффсет = RVA от imageBase; в твике base.add(RVA_*)\n");
        fclose(t);
    }
}

static uint64_t ofx_xref_func_for(uint64_t str_vm)
{
    if (!str_vm || !g.text_vm) return 0;
    const uint32_t *code = (const uint32_t *)ofx_mem(g.text_vm);
    uint64_t n = g.text_size / 4;
    for (uint64_t i = 0; i + 6 < n; i++) {
        OfxAdrp a = ofx_adrp(code[i], g.text_vm + i * 4);
        if (!a.ok) continue;
        for (int k = 1; k <= 4; k++) {
            OfxAddImm ad = ofx_add_imm(code[i + k], a.page);
            uint64_t tgt = 0;
            if (ad.ok && ad.rn == a.rd) tgt = ad.value;
            else {
                OfxLdrImm ld = ofx_ldr_imm(code[i + k], a.page);
                if (ld.ok && ld.rn == a.rd) tgt = ld.value;
            }
            if (tgt == str_vm) return ofx_find_func(g.text_vm + i * 4, g.fstarts, g.nfstarts);
            if (tgt) break;
        }
    }
    return 0;
}

static uint64_t ofx_str_vm_exact(const char *s)
{
    size_t want = strlen(s);
    uint64_t secs[2][2] = { { g.cstr_vm, g.cstr_size }, { g.meth_vm, g.meth_size } };
    for (int k = 0; k < 2; k++) {
        if (!secs[k][0] || !secs[k][1]) continue;
        const char *p = (const char *)ofx_mem(secs[k][0]);
        const char *end = p + secs[k][1];
        while (p < end) {
            size_t n = 0;
            while (p + n < end && p[n]) n++;
            if (n == want && !memcmp(p, s, n)) return secs[k][0] + (uint64_t)(p - (const char *)ofx_mem(secs[k][0]));
            p += n + 1;
        }
    }
    return 0;
}

static struct { char key[96]; uint64_t rva; } g_adhoc[32];
static int g_nadhoc;

static void OfxSetKnownRVA(const char *cls, const char *method, uint64_t rva)
{
    if (!method) return;
    char key[96];
    if (cls && cls[0]) snprintf(key, sizeof(key), "%s::%s", cls, method);
    else               snprintf(key, sizeof(key), "%s", method);
    for (int i = 0; i < g_nadhoc; i++)
        if (!strcmp(g_adhoc[i].key, key)) { g_adhoc[i].rva = rva; return; }
    if (g_nadhoc < 32) {
        strlcpy(g_adhoc[g_nadhoc].key, key, sizeof(g_adhoc[0].key));
        g_adhoc[g_nadhoc].rva = rva;
        g_nadhoc++;
    }
}

static uint64_t OfxFindRVA(const char *cls, const char *method)
{
    if (!method || !g.inited) return 0;
    char key[96];
    if (cls && cls[0]) snprintf(key, sizeof(key), "%s::%s", cls, method);
    else               snprintf(key, sizeof(key), "%s", method);

    for (int i = 0; i < g_nadhoc; i++)
        if (!strcmp(g_adhoc[i].key, key)) return g_adhoc[i].rva;

    uint64_t fn = 0;

    for (int i = 0; i < g_nharv && !fn; i++) {
        if (!g_harv[i].fn_vm) continue;
        if (cls && cls[0]) {
            size_t cl = strlen(cls), ml = strlen(method);
            if (g_harv[i].cls_len == cl && g_harv[i].m_len == ml &&
                !memcmp(g_harv[i].cls, cls, cl) && !memcmp(g_harv[i].method, method, ml))
                fn = g_harv[i].fn_vm;
        } else {
            size_t ml = strlen(method);
            if (g_harv[i].m_len == ml && !memcmp(g_harv[i].method, method, ml))
                fn = g_harv[i].fn_vm;
        }
    }

    if (!fn) {
        uint64_t sv = ofx_str_vm_exact(key);
        if (!sv) sv = ofx_str_vm_exact(method);
        if (sv) fn = ofx_xref_func_for(sv);
    }
    uint64_t r = fn ? ofx_rva(fn) : 0;
    if (g_nadhoc < 32) { strlcpy(g_adhoc[g_nadhoc].key, key, sizeof(g_adhoc[0].key)); g_adhoc[g_nadhoc].rva = r; g_nadhoc++; }
    return r;
}

static int ofx_index(const char *name)
{
    if (!name) return -1;
    for (int i = 0; i < g.ntargets; i++)
        if (!strcmp(ofx_target(i)->name, name)) return i;
    return -1;
}

static void OfxSetKnown(const char *name, uint64_t rva)
{
    int i = ofx_index(name);
    if (i < 0) return;
    g_known[i] = rva;
    if (rva) {
        g_res[i].rva = rva;
        g_res[i].src = OFX_S_HEADER;
        g_res[i].conf = OFX_C_HIGH;
        snprintf(g_res[i].ev, sizeof(g_res[i].ev), "offsets.h");
    }
}

static uint64_t OfxRVA(const char *name)
{
    int i = ofx_index(name);
    return (i < 0) ? 0 : g_res[i].rva;
}

static uint64_t OfxAddr(const char *name)
{
    int i = ofx_index(name);
    if (i < 0 || !g_res[i].rva) return 0;
    return g.base + g_res[i].rva;
}

static OfxSource OfxSourceOf(const char *name) { int i = ofx_index(name); return (i < 0) ? OFX_S_NONE : (OfxSource)g_res[i].src; }
static OfxConf   OfxConfOf(const char *name)   { int i = ofx_index(name); return (i < 0) ? OFX_C_LOW : (OfxConf)g_res[i].conf; }
static int       OfxResolved(void)             { return g_nresolved; }

static pthread_once_t g_once = PTHREAD_ONCE_INIT;
static uint64_t       g_init_base;

static void ofx_once_body(void)
{
    memset(g_res, 0, sizeof(g_res));
    memset(g_haddr, 0, sizeof(g_haddr));
    memset(g_hmap, 0, sizeof(g_hmap));
    g.base = g_init_base;
    if (!g.base) {
        plog("Titanox[ofx]: base == 0 -- резолвер не запущен");
        return;
    }
    if (!ofx_parse_macho()) return;
    ofx_load_fstarts();
    ofx_build_keymaps();
    ofx_scan_strings();
    ofx_scan_xrefs();
    ofx_finalize_logstr();
    ofx_symtab_funcs();
    ofx_symtab_globals();
    ofx_objc_pass();
    ofx_globals_getinst();
    ofx_disptab_pass();
    ofx_vtable_tables();
    for (int i = 0; i < g.ntargets; i++) {
        if (g_known[i] && g_res[i].src != OFX_S_HEADER) {
            g_res[i].rva = g_known[i];
            g_res[i].src = OFX_S_HEADER;
            g_res[i].conf = OFX_C_HIGH;
            snprintf(g_res[i].ev, sizeof(g_res[i].ev), "offsets.h");
        }
    }
    ofx_guards();
    g.inited = 1;
    ofx_summary();
}

static void OfxInit(uint64_t base)
{
    g_init_base = base;
    pthread_once(&g_once, ofx_once_body);
}

static void OfxDumpReport(void)
{
    if (!g.inited) { plog("Titanox[ofx]: dump до OfxInit"); return; }
    ofx_dump();
}

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
    plog("Titanox: %s", buf);
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
            plog("Titanox: %s not found, hook skipped", specs[i].tag);
            continue;
        }
        if (OfxConfOf(specs[i].tag) == OFX_C_LOW && !specs[i].allow_low && !OFX_ALLOW_LOW) {
            plog("Titanox: %s 0x%llx low confidence, hook skipped",
                   specs[i].tag, (unsigned long long)a);
            continue;
        }
        [TitanoxHook addBreakpointAtAddress:(void *)a withHook:specs[i].fn];
        plog("Titanox: %s 0x%llx %s hooked", specs[i].tag,
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
            plog("Titanox: settings %s not found", st[i].m);
            continue;
        }
        [TitanoxHook addBreakpointAtAddress:(void *)(base + r) withHook:st[i].fn];
        plog("Titanox: settings %s 0x%llx hooked", st[i].m,
               (unsigned long long)(base + r));
    }
}

__attribute__((constructor))
static void titanox_init(void)
{
    @autoreleasepool {
        uint64_t base = (uint64_t)[TitanoxHook getBaseAddressOfLibrary:"Nulls Brawl"];
        if (!base) {
            plog("Titanox: base not found");
            return;
        }
        plog("Titanox: base=0x%llx", (unsigned long long)base);

        feed_known();
        OfxInit(base);

        plog("Titanox: hooks installed %d", install_hooks(g_hooks));
        install_settings(base);

        const char *vt[] = { "VTABLE_CHARACTER_DATA", "VTABLE_PROJECTILE_DATA",
                             "VTABLE_TEXT_FIELD", "VTABLE_DECORATED_TEXT_FIELD", NULL };
        for (int i = 0; vt[i]; i++) {
            uint64_t r = OfxRVA(vt[i]);
            if (r) plog("Titanox: %s table 0x%llx", vt[i], (unsigned long long)r);
        }

        OfxDumpReport();
        plog("Titanox: resolved %d/%d", OfxResolved(), g_target_count);
    }
}
