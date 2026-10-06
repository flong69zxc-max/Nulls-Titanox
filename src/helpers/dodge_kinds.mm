#include "titanox.h"

static const tnx_fit_t g_kinds_fit[TNX_FIT_COUNT] = {
    { 0.65f, 120.0f },
    { 0.55f, 90.0f },
    { 0.6f, 100.0f },
    { 0.45f, 70.0f },
    { 0.4f, 50.0f },
    { 0.45f, 60.0f },
    { 0.5f, 80.0f },
    { 0.35f, 40.0f },
    { 0.45f, 60.0f },
};

static const tnx_kind_t g_kinds[TNX_KIND_COUNT] = {
    { "GunslingerProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "GunslingerOverchargedProjectile", TNX_FIT_THIN, 0, 0, 2600, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperProjectile", TNX_FIT_THIN, 0, 0, 3000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperCirclingProjectile", TNX_FIT_ORBIT, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperChargedProjectile", TNX_FIT_LONG, 32, 0, 2200, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperUltiProjectile", TNX_FIT_ORBIT, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "PiperHandgunProjectile", TNX_FIT_HALF, 0, 0, 2200, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SniperProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeamerProjectile", TNX_FIT_RAY, 32, 0, 0, 3900, 0, 1.15f, 0.0f, 0.0f },
    { "BulletstormLastShotProjectile", TNX_FIT_LONG, 0, 0, 3300, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BulletstormOnShellPickedUpProjectile", TNX_FIT_PLAIN, 0, 0, 3300, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperMutantProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperUltiProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperOverchargedUltiProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperBounceProjectile", TNX_FIT_HALF, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperSecondaryProjectile_001", TNX_FIT_HALF, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "HookProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SnakeOilProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SnakeOilUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SnakeOilHyperUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "HookProjectile2", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SoulCollectorProjectile", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SoulCollectorUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MosquitoProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MosquitoProjectilePoison", TNX_FIT_LONG, 32, 0, 3300, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpeedyProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpeedyOverchargedProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RollerProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RollerGadgetProjectile", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeProjectile", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeOverchargedProjectile", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeProjectileTripWire", TNX_FIT_LONG, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeProjectileTripWireBuddy", TNX_FIT_LONG, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeGadgetSkillProjectile", TNX_FIT_FALLBACK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeGadgetSkillProjectileBuddy", TNX_FIT_FALLBACK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeSpawnMineProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeSpawnOverchargedMineProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RocketGirlProjectile", TNX_FIT_THICK, 66, 0, 0, 0, 280, 0.0f, 0.0f, 0.0f },
    { "RocketGirlGadgetProjectile", TNX_FIT_BROAD, 0, 0, 3000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RocketGirlUltiProjectile", TNX_FIT_THICK, 64, 0, 0, 0, 280, 0.0f, 0.0f, 0.0f },
    { "RocketGirlUltiOverchargedProjectile", TNX_FIT_THICK, 64, 0, 0, 0, 280, 0.0f, 0.0f, 0.0f },
    { "CannonGirlProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CannonGirlSmallProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CannonGirlChainProjectile", TNX_FIT_HALF, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CannonGirlExplosionProjectileOvercharged", TNX_FIT_LONG, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightProjectile1", TNX_FIT_THICK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightProjectile2", TNX_FIT_THICK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightProjectile3", TNX_FIT_THICK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightUltiProjectile", TNX_FIT_THICK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DuplicatorProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "OverchargedDuplicatorProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DuplicatorUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "OverchargedDuplicatorUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 250, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeMutantProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeIndirectProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeOverchargedUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CocoonerProjectile", TNX_FIT_LONG, 32, -150, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "CocoonerProjectile2", TNX_FIT_LONG, 16, 0, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "CocoonerUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CocoonerOverchargedUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherProjectile", TNX_FIT_THICK, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherUltiProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherUltiProjectile2", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherOverchargedUltiProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabUltiProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabOverchargedUltiProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabOverchargedUltiReturnProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "FishTankUltiProjectile", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "FishTankUltiProjectileSmall", TNX_FIT_BROAD, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CookerProjectile", TNX_FIT_LONG, 32, -450, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MaisieProjectile", TNX_FIT_LONG, 42, 900, 0, 0, 0, 0.0f, 786.63f, 0.001231f },
    { "TrickshotDudeProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "TrickshotDudeUltiProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "TrickshotDudeUltiOverchargedProjectile", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerProjectile", TNX_FIT_BROAD, 0, 600, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "ControllerArchetypeCollabProjectileLvl1", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerArchetypeCollabProjectileLvl2", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerArchetypeCollabProjectileLvl3", TNX_FIT_PLAIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerUltiProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerUltiOverchargedProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AxeJugglerProjectile", TNX_FIT_BROAD, 0, 200, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AxeJugglerProjectile2", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AxeJugglerOverchargedProjectile2", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SplitterProjectile", TNX_FIT_LONG, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeProjectile", TNX_FIT_BROAD, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeProjectile2", TNX_FIT_THIN, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeOverchargedUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeTurretProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeOverchargedTurretProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "PercenterProjectile", TNX_FIT_LONG, 34, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "PercenterOverchargedProjectile", TNX_FIT_LONG, 34, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MeepleProjectile", TNX_FIT_PLAIN, 0, 200, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "MeepleUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MeepleOverchargedUltiProjectile", TNX_FIT_BROAD, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MeepleWallProjectile", TNX_FIT_FALLBACK, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ShamanProjectile", TNX_FIT_LONG, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CoopRangedEnemyProjectile", TNX_FIT_FALLBACK, 0, 0, 2500, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SniperHomingProjectile", TNX_FIT_LONG, 32, 0, 3500, 0, 100, 0.0f, 0.0f, 0.0f },
    { "MechanicProjectile2", TNX_FIT_FALLBACK, 0, 0, 2000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MechanicProjectile3", TNX_FIT_FALLBACK, 0, 0, 2000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DoorManCaneGadgetProjectile", TNX_FIT_FALLBACK, 0, 0, 3000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MummyProjectile", TNX_FIT_LONG, 8, -750, 0, 0, 150, 0.0f, 4461.04f, -0.000971f },
    { "WhirlwindProjectile", TNX_FIT_LONG, 2, -250, 0, 0, 250, 0.0f, 0.0f, 0.0f },
    { "WhirlwindProjectile2", TNX_FIT_FALLBACK, 16, 0, 0, 0, 250, 0.0f, 0.0f, 0.0f },
    { "MorningstarProjectile", TNX_FIT_FALLBACK, 0, 0, 2700, 0, 150, 0.0f, 0.0f, 0.0f },
    { "MorningstarProjectileRecall", TNX_FIT_FALLBACK, 16, 0, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "AlternatorHealProjectile", TNX_FIT_FALLBACK, 0, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AlternatorDamageProjectile", TNX_FIT_FALLBACK, 0, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KickerDudeProjectile2", TNX_FIT_FALLBACK, 0, 0, 2200, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DancerProjectileSingle", TNX_FIT_FALLBACK, 0, 0, 2700, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DancerProjectileDouble", TNX_FIT_FALLBACK, 0, 0, 2500, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DancerProjectileTriple", TNX_FIT_FALLBACK, 0, 0, 1700, 0, 0, 0.0f, 0.0f, 0.0f },
};

int tnx_kind_index(const char *name) {
    int i;

    if (!name || !name[0]) return -1;

    for (i = 0; i < TNX_KIND_COUNT; i++) {
        if (strcmp(g_kinds[i].name, name) == 0) return i;
    }

    return -1;
}

const tnx_kind_t *tnx_kind(const char *name) {
    int i = tnx_kind_index(name);

    return i < 0 ? NULL : &g_kinds[i];
}

const tnx_fit_t *tnx_kind_fit(const char *name) {
    const tnx_kind_t *kind = tnx_kind(name);

    if (kind && kind->fit >= 0 && kind->fit < TNX_FIT_COUNT) return &g_kinds_fit[kind->fit];

    return &g_kinds_fit[TNX_FIT_FALLBACK];
}
