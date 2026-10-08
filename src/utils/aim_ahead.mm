#include "../recoil.h"

static const rcl_aim_ahead_t rcl_aim_ahead_table[] = {
    {"8BIT", 4500, 3000, 667, 17, 0},
    {"ALLI", 0, 800, 0, 0, 4},
    {"AMBER", 3500, 2500, 714, 18, 0},
    {"ANGELO", 4000, 3000, 750, 19, 0},
    {"ARTIE", 4500, 3000, 667, 17, 0},
    {"ASH", 5000, 1400, 280, 7, 0},
    {"BARLEY", 0, 2200, 0, 0, 1},
    {"BARRELBOT", 4000, 1800, 450, 11, 0},
    {"BEA", 3255, 3000, 922, 23, 0},
    {"BELLE", 4000, 3000, 750, 19, 0},
    {"BERRY", 0, 1900, 0, 0, 1},
    {"BIBI", 0, 1100, 0, 0, 4},
    {"BO", 2800, 2600, 929, 23, 0},
    {"BOLDER", 0, 0, 0, 0, 4},
    {"BONNIE", 3800, 2700, 711, 18, 0},
    {"BROCK", 2700, 2700, 1000, 25, 0},
    {"BRONSON", 5000, 900, 180, 4, 0},
    {"BULL", 2853, 1600, 561, 14, 0},
    {"BUSTER", 4200, 1600, 381, 10, 0},
    {"BUZZ", 4000, 800, 200, 5, 0},
    {"BYRON", 4000, 3000, 750, 19, 0},
    {"CARL", 3000, 2500, 833, 21, 0},
    {"CHARLIE", 4200, 2700, 643, 16, 0},
    {"CHESTER", 3300, 2500, 758, 19, 0},
    {"CHUCK", 2700, 1800, 667, 17, 0},
    {"CLANCY", 3500, 2300, 657, 16, 0},
    {"COLETTE", 4000, 2600, 650, 16, 0},
    {"COLT", 4000, 2700, 675, 17, 0},
    {"CORDELIUS", 3800, 1600, 421, 11, 0},
    {"COSMO", 1600, 2700, 1688, 42, 0},
    {"CROW", 3261, 2600, 797, 20, 0},
    {"DAMIAN", 5000, 800, 160, 4, 0},
    {"DIGGER", 2800, 1500, 536, 13, 0},
    {"DOUG", 0, 1000, 0, 0, 4},
    {"DRACO", 3800, 1200, 316, 8, 0},
    {"EDGAR", 3500, 600, 171, 4, 0},
    {"EMZ", 1500, 2000, 1333, 33, 0},
    {"EVE", 3500, 2800, 800, 20, 0},
    {"FANG", 3200, 800, 250, 6, 0},
    {"FINX", 3000, 2500, 833, 21, 0},
    {"FISHTANK", 0, 1000, 0, 0, 4},
    {"FRANK", 5000, 1800, 360, 9, 0},
    {"GALE", 3000, 2500, 833, 21, 0},
    {"GENE", 3200, 1700, 531, 13, 0},
    {"GIGI", 0, 1000, 0, 0, 4},
    {"GLOWBERT", 5000, 2200, 440, 11, 0},
    {"GODZILLA", 0, 1300, 0, 0, 4},
    {"GRAY", 3804, 2700, 710, 18, 0},
    {"GRIFF", 3100, 2500, 806, 20, 0},
    {"GROM", 0, 2300, 0, 0, 1},
    {"GUS", 4000, 2800, 700, 18, 0},
    {"JACKY", 0, 1000, 0, 0, 4},
    {"JAE", 3700, 2500, 676, 17, 0},
    {"JANET", 3650, 1200, 329, 8, 0},
    {"JESS", 3050, 2700, 885, 22, 0},
    {"JUJU", 0, 1900, 0, 0, 1},
    {"KAZE", 0, 800, 0, 0, 4},
    {"KIT", 0, 1100, 0, 0, 1},
    {"LEON", 3500, 2900, 829, 21, 0},
    {"LILY", 3500, 600, 171, 4, 0},
    {"LOLLA", 4500, 2700, 600, 15, 0},
    {"LOU", 4000, 2800, 700, 18, 0},
    {"LUMI", 3500, 2400, 686, 17, 0},
    {"MAISIE", 3200, 2600, 812, 20, 0},
    {"MANDY", 3800, 2700, 711, 18, 0},
    {"MAX", 4000, 2500, 625, 16, 0},
    {"MEEPLE", 3000, 2300, 767, 19, 0},
    {"MEG", 4000, 2700, 675, 17, 0},
    {"MELODY", 4500, 2400, 533, 13, 0},
    {"MICO", 0, 1200, 0, 0, 4},
    {"MIKE", 0, 2200, 0, 0, 1},
    {"MINA", 3000, 2400, 800, 20, 0},
    {"MJ", 4130, 2700, 654, 16, 0},
    {"MORTIS", 0, 800, 0, 0, 4},
    {"MRP", 3000, 2100, 700, 18, 0},
    {"NAJIA", 1700, 1800, 1059, 26, 0},
    {"NANI", 4000, 2600, 650, 16, 0},
    {"NITA", 2718, 1800, 662, 17, 0},
    {"NORI", 4000, 1100, 275, 7, 0},
    {"OLLIE", 3000, 1900, 633, 16, 0},
    {"OTIS", 3600, 2700, 750, 19, 0},
    {"PEARL", 4000, 2700, 675, 17, 0},
    {"PENNY", 3400, 2600, 765, 19, 0},
    {"PIERCE", 4000, 3000, 750, 19, 0},
    {"PIPER", 4000, 3000, 750, 19, 0},
    {"POCO", 2500, 2100, 840, 21, 0},
    {"PRIMO", 3261, 900, 276, 7, 0},
    {"RICK", 3478, 2900, 834, 21, 0},
    {"ROSA", 5000, 1100, 220, 6, 0},
    {"RUFFS", 3800, 2700, 711, 18, 0},
    {"SAMURAI", 0, 800, 0, 0, 4},
    {"SANDY", 3500, 1800, 514, 13, 0},
    {"SHADE", 0, 1100, 0, 0, 4},
    {"SHELLY", 3100, 2300, 742, 19, 0},
    {"SIRIUS", 0, 2200, 0, 0, 1},
    {"SPIKE", 2174, 2300, 1058, 26, 0},
    {"SPROUT", 0, 1500, 0, 0, 1},
    {"SQUEAK", 4000, 2300, 575, 14, 0},
    {"STELLA", 0, 1700, 0, 0, 2},
    {"STU", 3300, 2300, 697, 17, 0},
    {"SUPERNOVABEESNIPER", 2800, 2800, 1000, 25, 0},
    {"SUPERNOVACACTUS", 2174, 1100, 506, 13, 0},
    {"SUPERNOVAFIREDUDE", 2800, 1700, 607, 15, 0},
    {"SUPERNOVAMAGICALGIRL", 0, 1100, 0, 0, 4},
    {"SUPERNOVAVOODOO", 0, 1000, 0, 0, 1},
    {"SURGE", 3500, 2000, 571, 14, 0},
    {"TARO", 3152, 2400, 761, 19, 0},
    {"TICK", 0, 2600, 0, 0, 1},
    {"TRUNK", 0, 1000, 0, 0, 4},
    {"TWINS", 0, 2200, 0, 0, 1},
    {"VINCE", 4000, 2500, 625, 16, 0},
    {"WENDY", 3500, 2400, 686, 17, 0},
    {"WILLOW", 0, 2200, 0, 0, 1},
    {"ZIGGY", 0, 2200, 0, 0, 1},
};

#define RCL_AIM_AHEAD_COUNT ((int)(sizeof(rcl_aim_ahead_table) / sizeof(rcl_aim_ahead_table[0])))

typedef struct
{
    const char *proj;
    int16_t row;
} rcl_aim_ahead_proj_t;

static const rcl_aim_ahead_proj_t rcl_aim_ahead_projs[] = {
    {"AlternatorSpeedProjectile", 52},
    {"AmbusherProjectile", 59},
    {"ArcadeProjectile", 0},
    {"ArtilleryDudeProjectile", 82},
    {"AssaultShotgunProjectile", 48},
    {"AttacherProjectile", 57},
    {"AttractorCarrierProjectile", 29},
    {"AxeJugglerProjectile", 68},
    {"BarkeepProjectile", 6},
    {"BarrelBotProjectile", 7},
    {"BeamerProjectile", 64},
    {"BeeSniperProjectile", 8},
    {"BlackHoleProjectile", 106},
    {"BlowerProjectile", 42},
    {"BowDudeProjectile", 12},
    {"BullDudeProjectile", 17},
    {"BulletstormProjectile", 83},
    {"CactusProjectile", 95},
    {"CannonGirlProjectile", 14},
    {"ChronomancerProjectile", 39},
    {"ClusterBombProjectile", 107},
    {"CocoonerProjectile", 22},
    {"ConductorProjectile", 24},
    {"ControllerProjectile", 76},
    {"CookerProjectile", 81},
    {"CrabProjectile", 25},
    {"CrossBomberProjectile", 49},
    {"CrowProjectile", 30},
    {"DancerProjectileSingle", 71},
    {"DeadMariachiProjectile", 85},
    {"DiggerProjectile", 32},
    {"DoorManProjectile", 47},
    {"DragonRiderProjectile", 34},
    {"DuelistProjectile", 28},
    {"DuplicatorProjectile", 60},
    {"ElectroSniperProjectile", 9},
    {"EnragerProjectile", 35},
    {"FireDudeProjectile", 2},
    {"FleaProjectile1", 37},
    {"FuryProjectile", 113},
    {"FutureGirlProjectile", 111},
    {"GladiatorProjectile", 31},
    {"GunslingerProjectile", 27},
    {"HammerDudeProjectile", 41},
    {"HookProjectile", 43},
    {"IceDudeProjectile", 61},
    {"JesterProjectile", 23},
    {"JetpackGirlProjectile", 53},
    {"KatanaKidProjectile", 78},
    {"KickerDudeProjectile", 38},
    {"KnightProjectile1", 5},
    {"LeonDefProjectile", 58},
    {"MagicalGirlProjectile", 98},
    {"MaisieProjectile", 63},
    {"MechaDudeProjectile", 67},
    {"MechanicProjectile1", 54},
    {"MeepleProjectile", 66},
    {"MenderProjectile", 45},
    {"MinigunDudeProjectile", 72},
    {"MorningstarProjectile", 62},
    {"MosquitoProjectile", 3},
    {"MummyProjectile", 36},
    {"PainterProjectile", 10},
    {"PercenterProjectile", 26},
    {"PowerLevelerProjectile", 105},
    {"PrimoDefProjectile", 86},
    {"PuppeteerProjectile", 112},
    {"RedirecterProjectile", 75},
    {"RocketGirlProjectile", 15},
    {"RollerProjectile", 99},
    {"RopeDudeProjectile", 19},
    {"RosaProjectile", 88},
    {"RuffsProjectile", 89},
    {"SandstormProjectile", 91},
    {"ShadowdemonProjectileIndirect", 94},
    {"ShamanProjectile", 77},
    {"ShieldTankProjectile", 18},
    {"ShotgunGirlProjectile", 93},
    {"SilencerProjectile", 80},
    {"SkaterProjectile", 79},
    {"SnakeOilProjectile", 20},
    {"SniperProjectile", 84},
    {"SoulCollectorProjectile", 50},
    {"SpawnerDudeProjectile", 74},
    {"SpeedyProjectile", 65},
    {"SplitterProjectile", 4},
    {"StackerProjectile", 110},
    {"StickyBombProjectile", 97},
    {"SuperNovaBeeSniperProjectile", 100},
    {"SuperNovaCactusProjectile", 101},
    {"SuperNovaFireDudeProjectile", 102},
    {"SuperNovaVoodooProjectileEarth", 104},
    {"TntDudeProjectile", 70},
    {"TrickshotDudeProjectile", 87},
    {"TwinsThrowerProjectile", 109},
    {"VoodooProjectileEarth", 55},
    {"WallyProjectile", 96},
    {"WeaponThrowerProjectile", 16},
    {"WhirlwindProjectile", 21},
};

#define RCL_AIM_AHEAD_PROJ_COUNT ((int)(sizeof(rcl_aim_ahead_projs) / sizeof(rcl_aim_ahead_projs[0])))

const rcl_aim_ahead_t *rcl_aim_ahead_by_projectile(const char *projName)
{
    int lo = 0;
    int hi = RCL_AIM_AHEAD_PROJ_COUNT - 1;
    if (!projName || !projName[0])
    {
        return nullptr;
    }
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        int cmp = strcmp(projName, rcl_aim_ahead_projs[mid].proj);
        if (cmp == 0)
        {
            return &rcl_aim_ahead_table[rcl_aim_ahead_projs[mid].row];
        }
        if (cmp < 0)
        {
            hi = mid - 1;
            continue;
        }
        lo = mid + 1;
    }
    return nullptr;
}

const rcl_aim_ahead_t *rcl_aim_ahead_of(const char *name)
{
    const char *code = nullptr;
    int lo = 0;
    int hi = RCL_AIM_AHEAD_COUNT - 1;
    if (!name || !name[0])
    {
        return nullptr;
    }
    code = rcl_brawler_canon(name);
    if (!code || !code[0])
    {
        return nullptr;
    }
    while (lo <= hi)
    {
        int mid = lo + (hi - lo) / 2;
        int cmp = strcmp(code, rcl_aim_ahead_table[mid].code);
        if (cmp == 0)
        {
            return &rcl_aim_ahead_table[mid];
        }
        if (cmp < 0)
        {
            hi = mid - 1;
            continue;
        }
        lo = mid + 1;
    }
    return nullptr;
}

int rcl_aim_ahead_tiles10(const char *name)
{
    const rcl_aim_ahead_t *row = rcl_aim_ahead_of(name);
    if (!row)
    {
        return RCL_AIM_AHEAD_DEFAULT;
    }
    return row->ahead10;
}

int rcl_aim_ahead_speed(const char *name)
{
    const rcl_aim_ahead_t *row = rcl_aim_ahead_of(name);
    if (!row)
    {
        return 0;
    }
    return row->shotSpeed;
}
