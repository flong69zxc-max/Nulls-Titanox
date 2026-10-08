#include "../recoil.h"

static const rcl_fit_t rcl_fits[RCL_FIT_COUNT] = {
    { 0.65f, 120.0f }, { 0.55f, 90.0f }, { 0.6f, 100.0f }, { 0.45f, 70.0f }, { 0.4f, 50.0f },
    { 0.45f, 60.0f },  { 0.5f, 80.0f },  { 0.35f, 40.0f }, { 0.45f, 60.0f },
};

static const rcl_kind_t rcl_kinds[RCL_KIND_COUNT] = {
    { "GunslingerProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "GunslingerOverchargedProjectile", 7, 0, 0, 2600, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperProjectile", 7, 0, 0, 3000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperCirclingProjectile", 0, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperChargedProjectile", 1, 32, 0, 2200, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeeSniperUltiProjectile", 0, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "PiperHandgunProjectile", 4, 0, 0, 2200, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SniperProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BeamerProjectile", 6, 32, 0, 0, 3900, 0, 1.15f, 0.0f, 0.0f },
    { "BulletstormLastShotProjectile", 1, 0, 0, 3300, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BulletstormOnShellPickedUpProjectile", 5, 0, 0, 3300, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperMutantProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperUltiProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperOverchargedUltiProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperBounceProjectile", 4, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ElectroSniperSecondaryProjectile_001", 4, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "HookProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SnakeOilProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SnakeOilUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SnakeOilHyperUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "HookProjectile2", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SoulCollectorProjectile", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SoulCollectorUlti", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MosquitoProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MosquitoProjectilePoison", 1, 32, 0, 3300, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpeedyProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpeedyOverchargedProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RollerProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RollerGadgetProjectile", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeProjectile", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeOverchargedProjectile", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeProjectileTripWire", 1, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeProjectileTripWireBuddy", 1, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeGadgetSkillProjectile", -1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeGadgetSkillProjectileBuddy", -1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeSpawnMineProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "BowDudeSpawnOverchargedMineProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RocketGirlProjectile", 2, 66, 0, 0, 0, 280, 0.0f, 0.0f, 0.0f },
    { "RocketGirlGadgetProjectile", 3, 0, 0, 3000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "RocketGirlUltiProjectile", 2, 64, 0, 0, 0, 280, 0.0f, 0.0f, 0.0f },
    { "RocketGirlUltiOverchargedProjectile", 2, 64, 0, 0, 0, 280, 0.0f, 0.0f, 0.0f },
    { "CannonGirlProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CannonGirlSmallProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CannonGirlChainProjectile", 4, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CannonGirlExplosionProjectileOvercharged", 1, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightProjectile1", 2, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightProjectile2", 2, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightProjectile3", 2, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KnightUltiProjectile", 2, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DuplicatorProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "OverchargedDuplicatorProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DuplicatorUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "OverchargedDuplicatorUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeProjectile", 1, 32, 0, 0, 0, 250, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeMutantProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeIndirectProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SpawnerDudeOverchargedUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CocoonerProjectile", 1, 32, -150, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "CocoonerProjectile2", 1, 16, 0, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "CocoonerUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CocoonerOverchargedUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherProjectile", 2, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherUltiProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherUltiProjectile2", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AmbusherOverchargedUltiProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabUltiProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabOverchargedUltiProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CrabOverchargedUltiReturnProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "FishTankUltiProjectile", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "FishTankUltiProjectileSmall", 3, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CookerProjectile", 1, 32, -450, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MaisieProjectile", 1, 42, 900, 0, 0, 0, 0.0f, 786.63f, 0.001231f },
    { "TrickShotDudeProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "TrickShotDudeUltiProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "TrickShotDudeOverchargedProjectile", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerProjectile", 3, 0, 600, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "ControllerArchetypeCollabProjectileLvl1", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerArchetypeCollabProjectileLvl2", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerArchetypeCollabProjectileLvl3", 5, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerUltiProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ControllerUltiOverchargedProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AxeJugglerProjectile", 3, 0, 200, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AxeJugglerProjectile2", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AxeJugglerOverchargedProjectile2", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SplitterProjectile", 1, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeProjectile", 3, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeProjectile2", 7, 0, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeOverchargedUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeTurretProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ArtilleryDudeOverchargedTurretProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "PercenterProjectile", 1, 34, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "PercenterOverchargedProjectile", 1, 34, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MeepleProjectile", 5, 0, 200, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "MeepleUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MeepleOverchargedUltiProjectile", 3, 1, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MeepleWallProjectile", -1, 4, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "ShamanProjectile", 1, 32, 0, 0, 0, 0, 0.0f, 0.0f, 0.0f },
    { "CoopRangedEnemyProjectile", -1, 0, 0, 2500, 0, 0, 0.0f, 0.0f, 0.0f },
    { "SniperHomingProjectile", 1, 32, 0, 3500, 0, 100, 0.0f, 0.0f, 0.0f },
    { "MechanicProjectile2", 8, 0, 0, 2000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MechanicProjectile3", 8, 0, 0, 2000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DoorManCaneGadgetProjectile", 8, 0, 0, 3000, 0, 0, 0.0f, 0.0f, 0.0f },
    { "MummyProjectile", 1, 8, -750, 0, 0, 150, 0.0f, 4461.04f, -0.000971f },
    { "WhirlwindProjectile", 1, 2, -250, 0, 0, 250, 0.0f, 0.0f, 0.0f },
    { "WhirlwindProjectile2", -1, 16, 0, 0, 0, 250, 0.0f, 0.0f, 0.0f },
    { "MorningstarProjectile", -1, 0, 0, 2700, 0, 150, 0.0f, 0.0f, 0.0f },
    { "MorningstarProjectileRecall", -1, 16, 0, 0, 0, 150, 0.0f, 0.0f, 0.0f },
    { "AlternatorHealProjectile", 8, 0, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "AlternatorDamageProjectile", 8, 0, 0, 2800, 0, 0, 0.0f, 0.0f, 0.0f },
    { "KickerDudeProjectile2", 8, 0, 0, 2200, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DancerProjectileSingle", 8, 0, 0, 2700, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DancerProjectileDouble", 8, 0, 0, 2500, 0, 0, 0.0f, 0.0f, 0.0f },
    { "DancerProjectileTriple", 8, 0, 0, 1700, 0, 0, 0.0f, 0.0f, 0.0f },
};

int rcl_kind_index(const char *name)
{
    int i = 0;

    if (!name || !name[0]) return -1;

    for (i = 0; i < RCL_KIND_COUNT; i++)
    {
        if (strcmp(rcl_kinds[i].name, name) == 0) return i;
    }

    return -1;
}

const rcl_kind_t *rcl_kind_of(const char *name)
{
    int i = rcl_kind_index(name);

    return i < 0 ? nullptr : &rcl_kinds[i];
}

const rcl_fit_t *rcl_fit_of(const char *name)
{
    const rcl_kind_t *kind = rcl_kind_of(name);

    if (kind && kind->fit >= 0 && kind->fit < RCL_FIT_COUNT) return &rcl_fits[kind->fit];

    return &rcl_fits[RCL_FIT_FALLBACK];
}

float rcl_proj_radius(const rcl_proj_t *p, float speed)
{
    uintptr_t base = 0;
    int off = 0;

    if (!RCL_GEOM) return 0.0f;
    if (!p) return 0.0f;
    if (speed < 1.0f) return 0.0f;

    base = p->elem;

    {
        void *def = nullptr;

        if (rcl_read_ptr(p->elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) && def) base = (uintptr_t)def;
    }

    if (rcl_rad_off >= 0)
    {
        float r = 0.0f;

        if (base && rcl_read_float(base + (uintptr_t)rcl_rad_off, &r) &&
            rcl_ok(r, RCL_RADIUS_MIN, RCL_RADIUS_MAX))
        {
            rcl_rad_est = r;

            return r;
        }

        return rcl_ok(rcl_rad_est, RCL_RADIUS_MIN, RCL_RADIUS_MAX) ? rcl_rad_est : 0.0f;
    }

    if (!base) return 0.0f;

    for (off = RCL_CAL_OFF_LO; off <= RCL_CAL_OFF_HI; off += RCL_CAL_STEP)
    {
        float v = 0.0f;
        float r = 0.0f;
        float d = 0.0f;

        if (!rcl_read_float(base + (uintptr_t)off, &v)) continue;
        if (!rcl_ok(v, 1.0f, 1.0e6f)) continue;

        d = v - speed;
        if (d < 0.0f) d = -d;
        if (d > speed * RCL_CAL_TOL) continue;

        if (!rcl_read_float(base + (uintptr_t)off + 4, &r)) continue;
        if (!rcl_ok(r, RCL_RADIUS_MIN, RCL_RADIUS_MAX)) continue;

        if (rcl_cal_off_seen == off && rcl_ok(rcl_cal_rad_seen - r, -1.0f, 1.0f))
        {
            rcl_cal_n++;
        }
        else
        {
            rcl_cal_off_seen = off;
            rcl_cal_rad_seen = r;
            rcl_cal_n = 1;
        }

        if (rcl_cal_n < RCL_CAL_TICKS) return 0.0f;

        rcl_rad_off = off + 4;
        rcl_rad_est = r;

        return r;
    }

    return RCL_DATA_PROJ_R;
}
