#include "titanox.h"

#include "data/chars_data.h"

static int g_own_row = -1;

static uint32_t tnx_hero_hash32(const char *s) {
    uint32_t h = 2166136261u;
    int i = 0;

    if (!s) return 0;

    for (i = 0; s[i]; i++) {
        h = (h ^ (uint8_t)s[i]) * 16777619u;
    }

    return h;
}

int tnx_hero_find(const char *name) {
    int i = 0;

    if (!name || !name[0]) return -1;

    for (i = 0; i < g_hero_count; i++) {
        if (strcmp(g_heroes[i].name, name) == 0) return i;
    }

    return -1;
}

const tnx_hero_t *tnx_hero_row(int index) {
    if (index < 0 || index >= g_hero_count) return NULL;

    return &g_heroes[index];
}

const tnx_hero_t *tnx_hero_by_hash(uint32_t hash) {
    int i = 0;

    for (i = 0; i < g_hero_count; i++) {
        if (tnx_hero_hash32(g_heroes[i].name) == hash) return &g_heroes[i];
    }

    return NULL;
}

void tnx_hero_own(int index) {
    if (index < 0 || index >= g_hero_count) return;

    if (g_own_row == index) return;

    g_own_row = index;

    TNX_LOGX("hero own=%s hp=%d speed=%d radius=%d weaponSpeed=%d cast=%d bullets=%d spread=%d "
             "melee=%d - the character row was taken from the game tables and the own movement "
             "constants now come from it instead of one value shared by every brawler: the speed "
             "field alone ranges from a few hundred to a thousand across the roster, so a single "
             "constant made the arithmetic wrong for almost everyone",
             g_heroes[index].name, g_heroes[index].hp, g_heroes[index].speed, g_heroes[index].radius,
             g_heroes[index].wSpeed, g_heroes[index].wCast, g_heroes[index].wBullets,
             g_heroes[index].wSpread, (g_heroes[index].flags & TNX_HF_MELEE) ? 1 : 0);
}

int tnx_hero_speed(void) {
    if (g_own_row < 0) return (int)TNX_PLAYER_SPEED;
    if (g_heroes[g_own_row].speed <= 0) return (int)TNX_PLAYER_SPEED;

    return g_heroes[g_own_row].speed;
}

int tnx_hero_radius(void) {
    if (g_own_row < 0) return (int)TNX_PLAYER_RADIUS;
    if (g_heroes[g_own_row].radius <= 0) return (int)TNX_PLAYER_RADIUS;

    return g_heroes[g_own_row].radius;
}

int tnx_hero_hp_max(void) {
    if (g_own_row < 0) return 0;

    return g_heroes[g_own_row].hp;
}

int tnx_hero_inflated(int projectile_radius, int fallback) {
    int own = tnx_hero_radius();
    int r = projectile_radius + own;

    if (r <= 0) return fallback;
    if (r < fallback) return fallback;

    return r;
}

int tnx_hero_melee(int index) {
    if (index < 0 || index >= g_hero_count) return 0;

    return (g_heroes[index].flags & TNX_HF_MELEE) ? 1 : 0;
}


int g_own_cand = 0;

void tnx_hero_identify(int hp_max, int speed_units) {
    int i = 0;
    int cand = 0;
    int picked = -1;

    if (g_own_row >= 0) return;
    if (hp_max <= 0) return;

    for (i = 0; i < g_hero_count; i++) {
        if (g_heroes[i].hp != hp_max) continue;

        cand++;

        if (picked < 0) picked = i;
        if (speed_units > 0 && g_heroes[i].speed == speed_units) picked = i;
    }

    g_own_cand = cand;

    if (cand <= 0) return;

    tnx_hero_own(picked);

    TNX_LOGX("heroid hp=%d cand=%d picked=%s speed=%d - the own character is identified by matching "
             "the health the game reports against the table, which needs no new offsets: cand is how "
             "many characters share that health, so a candidate count of one is an identification "
             "and a large count means health alone cannot tell them apart and the observed speed is "
             "needed to break the tie",
             hp_max, cand, g_heroes[picked].title,
             (speed_units > 0) ? speed_units : g_heroes[picked].speed);
}

void tnx_hero_report(void) {
    int i = 0;
    int melee = 0;
    int speeds[8];
    int counts[8];
    int n = 0;

    for (i = 0; i < g_hero_count; i++) {
        int k = 0;
        int seen = -1;

        if (g_heroes[i].flags & TNX_HF_MELEE) melee++;

        for (k = 0; k < n; k++) {
            if (speeds[k] == g_heroes[i].speed) seen = k;
        }

        if (seen >= 0) counts[seen]++;
        else if (n < 8) {
            speeds[n] = g_heroes[i].speed;
            counts[n] = 1;
            n++;
        }
    }

    TNX_LOGX("hero table rows=%d melee=%d own=%d - rows is how many character records the table "
             "carries and melee is how many of them have no projectile at all, which is the group "
             "the shot model cannot see and that has to be dodged by body distance instead",
             g_hero_count, melee, g_own_row);
}

const tnx_hero_t g_heroes[] = {
    { "037424c2385e031824f496c787e2ab8f473b70f8", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
    { "07220d24fa2e06c356cad4e7c6037d70b265010e", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
    { "4028aae4a6bbbdea17608222005fefc028ff7c45", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
    { "49c039b18c82880638cd3ba472dc5db3e8cc6f8b", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
    { "4f7b8a8fb970bd4cb356d59fd76bb5fb64e5797a", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
    { "Alternator", "JAE-YONG", 3700, 800, 145, 3700, 225, -1, 1, 250, -1, 300, 1500, 3, -1, -1, -1, -1, -1, 4 },
    { "Ambusher", "LILY", 4200, 855, 120, 3500, 300, -1, 1, 150, 0, 50, 800, 2, 3800, 200, 1, -1, -1, 4 },
    { "Arcade", "8-BIT", 5200, 600, 145, 4500, 50, -1, 1, 100, 18, 50, 1350, 3, 1196, 0, 1, -1, -1, 0 },
    { "ArtilleryDude", "PENNY", 3500, 750, 120, 3400, 150, -1, 1, 100, 0, 250, 2000, 3, 1196, 0, 1, -1, -1, 0 },
    { "AssaultShotgun", "GRIFF", 3700, 750, 120, 3100, 50, -1, 3, 200, 30, 50, 1600, 3, 3200, 150, 5, 150, -1, 0 },
    { "Attacher", "KIT", 3100, 855, 120, -1, -1, -1, 1, 100, 150, 100, 800, 3, -1, -1, -1, -1, -1, 1 },
    { "Attractor", "COSMO", 3400, 750, 120, 1600, 100, -1, 1, 100, -1, 100, 2000, 3, 4000, 175, 1, -1, -1, 4 },
    { "AxeJuggler", "MELODIE", 4000, 750, 120, 4500, 125, -1, 1, 150, -1, 250, 1500, 3, -1, -1, -1, -1, -1, 0 },
    { "Barkeep", "BARLEY", 2700, 750, 120, 1750, 0, -1, 1, 100, 0, 250, 2000, 3, 1700, 0, 1, 75, -1, 64 },
    { "BarrelBot", "DARRYL", 5500, 800, 145, 4000, 0, -1, 5, 250, 80, 50, 1800, 3, -1, -1, -1, -1, -1, 0 },
    { "Baseball", "BIBI", 5000, 855, 120, -1, -1, -1, 1, 600, 300, 50, 800, 3, 3000, 250, -1, -1, -1, 1 },
    { "Beamer", "MANDY", 3000, 750, 120, 3800, 100, -1, 1, 100, -1, 500, 1500, 3, 5000, 250, 1, -1, 100, 0 },
    { "BeeSniper", "BEA", 2800, 750, 120, 3255, 150, -1, 1, 100, -1, 50, 900, 1, 2500, 150, 7, 30, -1, 0 },
    { "BlackHole", "TARA", 3300, 750, 120, 3152, 100, -1, 3, 100, 50, 250, 1800, 3, 1522, 0, 1, 0, -1, 4 },
    { "Blower", "GALE", 4000, 750, 120, 3000, 50, -1, 6, 100, -1, 250, 1200, 3, 5000, 150, 4, -1, -1, 0 },
    { "BowDude", "BO", 3800, 750, 120, 2800, 70, -1, 1, 200, 30, 50, 1700, 3, 2391, 0, 1, -1, -1, 0 },
    { "BullDude", "BULL", 5000, 800, 145, 2853, 0, -1, 5, 100, 90, 250, 1600, 3, -1, -1, -1, -1, -1, 0 },
    { "Bulletstorm", "PIERCE", 3000, 750, 120, 4000, 100, -1, 1, 100, -1, 500, -1, 3, 29000, 0, 1, -1, -1, 0 },
    { "Cactus", "SPIKE", 3000, 750, 120, 2174, 150, -1, 1, 100, -1, 250, 2000, 3, 1739, 0, 1, 0, -1, 0 },
    { "CannonGirl", "BONNIE", 5000, 630, 120, 3800, 150, -1, 1, 200, -1, 50, 1000, 1, -1, -1, -1, -1, -1, 0 },
    { "CannonGirlSmall", "BONNIE", 3100, 855, 120, 3000, 100, -1, 1, 100, 40, 50, 2000, 3, -1, -1, -1, -1, -1, 64 },
    { "Chronomancer", "FINX", 3700, 800, 120, 3000, 100, -1, 3, 100, -1, 250, 1300, 3, 2000, 0, 1, 0, -1, 0 },
    { "ClusterBombDude", "TICK", 2400, 750, 120, 450, 0, -1, 1, 100, 0, 250, 2400, 3, 1196, 0, 1, -1, -1, 64 },
    { "Cocooner", "CHARLIE", 3700, 750, 120, 4200, 150, -1, 1, 100, 0, 500, 2000, 1, 3300, 200, 1, -1, -1, 0 },
    { "Conductor", "CHUCK", 4400, 800, 145, 2700, 200, -1, 1, 150, -1, 350, 2000, 3, 1500, 0, 1, -1, -1, 4 },
    { "Controller", "NANI", 2500, 750, 120, 4000, 40, -1, 3, 100, 50, 500, 1800, 3, 2500, 150, 1, 0, -1, 0 },
    { "Cooker", "PEARL", 4300, 750, 145, 4000, 100, -1, 1, 100, 40, 50, 1500, 3, -1, -1, -1, -1, -1, 0 },
    { "Crab", "CLANCY", 3800, 750, 120, 3500, 150, -1, 1, 200, 0, 200, 1800, 3, 3000, 150, 2, 220, -1, 0 },
    { "CrossBomber", "GROM", 3000, 750, 120, 840, 0, -1, 1, 300, 0, 75, 2000, 3, 800, 0, 1, 0, -1, 64 },
    { "Crow", "CROW", 2800, 855, 120, 3261, 50, -1, 3, 100, 45, 250, 1600, 3, -1, -1, -1, -1, -1, 0 },
    { "Dancer", "MINA", 3600, 800, 120, 3000, 150, -1, 1, 150, -1, 250, 1400, 3, 2200, 400, 1, -1, -1, 0 },
    { "Daredevil", "GIGI", 4100, 855, 120, -1, -1, -1, -1, 660, -1, -1, 220, 10, -1, -1, -1, -1, -1, 1 },
    { "DeadMariachi", "POCO", 4000, 750, 120, 2500, 150, -1, 4, 100, 130, 250, 1600, 3, 5000, 400, 3, 130, -1, 4 },
    { "Digger", "MOE", 3600, 800, 120, 2800, 150, -1, 1, 150, -1, 250, 1500, 3, -1, -1, -1, -1, -1, 64 },
    { "DiggerDrill", "DRILLER", 3500, 920, 120, 3500, 200, -1, 1, 100, -1, 50, 220, 40, -1, -1, -1, -1, -1, 4 },
    { "Domain", "TRUNK", 5200, 800, 145, -1, -1, 350, -1, 1000, -1, 250, 1500, 3, -1, -1, -1, -1, -1, 1 },
    { "DoorMan", "GRAY", 3400, 750, 120, 3804, 50, -1, 1, 100, 0, 500, 1400, 3, -1, -1, 1, -1, -1, 0 },
    { "DragonRider", "DRACO", 5600, 750, 120, 3800, 200, -1, 1, 500, -1, 250, 1000, 3, -1, -1, -1, -1, -1, 4 },
    { "Driller", "JACKY", 5200, 800, 145, -1, -1, -1, -1, 1000, -1, 250, 1800, 3, -1, -1, -1, -1, -1, 1 },
    { "Duelist", "CORDELIUS", 3500, 855, 120, 3800, 100, -1, 1, 200, -1, 100, 1200, 3, 3800, 200, 1, -1, -1, 0 },
    { "Duplicator", "LOLA", 4000, 750, 120, 4500, 100, -1, 1, 100, 30, 50, 1700, 3, 1196, 0, 1, -1, -1, 0 },
    { "ElectroSniper", "BELLE", 2900, 750, 120, 4000, 101, -1, 1, 100, -1, 500, 1400, 3, 4000, 150, 1, -1, -1, 0 },
    { "Enrager", "EDGAR", 3700, 855, 120, 3500, 300, -1, 1, 100, 0, 50, 700, 3, -1, -1, -1, -1, -1, 4 },
    { "FireDude", "AMBER", 3400, 750, 120, 3500, 200, -1, 1, 100, 30, 50, 235, 40, 1750, 0, 1, 0, -1, 4 },
    { "FishTank", "HANK", 5500, 750, 145, -1, -1, -1, -1, 150, -1, 250, 250, 1, -1, -1, -1, -1, -1, 1 },
    { "Flea", "EVE", 3100, 750, 120, 3500, 100, -1, 1, 150, -1, 500, 1600, 3, 1200, 0, 1, -1, -1, 0 },
    { "Fury", "ZIGGY", 3200, 800, 120, 29000, 0, -1, 1, 300, 0, 250, 1800, 3, 1000, 1500, 1, -1, 100, 64 },
    { "FutureGirl", "WENDY", 2000, 800, 120, 3500, 250, -1, 1, 100, -1, 500, 1450, 3, 1196, 0, 1, -1, -1, 0 },
    { "Geisha", "KAZE", 4100, 855, 120, -1, -1, -1, -1, -1, -1, 200, 1000, 3, 1000, 0, 1, -1, -1, 1 },
    { "GeishaTransformed", "GeishaTransformed", 4100, 750, 120, 3500, 100, -1, 1, 150, 0, 50, 1900, 3, -1, -1, -1, -1, -1, 0 },
    { "Ghost", "SHADE", 3700, 855, 120, -1, -1, 350, 1, 150, 300, 150, 800, 3, -1, -1, -1, -1, -1, 1 },
    { "Gladiator", "DAMIAN", 5600, 800, 120, 5000, 300, -1, 1, 200, 0, 200, 1200, 3, -1, -1, -1, -1, -1, 0 },
    { "Godzilla", "Godzilla", 19000, 600, 280, -1, -1, -1, 1, 700, 100, 50, 800, 1, -1, -1, 1, 180, -1, 1 },
    { "Gunslinger", "COLT", 3100, 750, 120, 4000, 50, -1, 1, 100, 0, 50, 1300, 3, 4891, 101, 1, 0, -1, 0 },
    { "HammerDude", "FRANK", 6800, 800, 145, 5000, 150, -1, 4, 600, 130, 50, 800, 3, 6000, 250, 4, 130, -1, 4 },
    { "HookDude", "GENE", 3800, 750, 120, 3200, 150, -1, 1, 100, 0, 250, 2000, 3, 3200, 200, 1, -1, -1, 0 },
    { "IceDude", "LOU", 3500, 750, 120, 4000, 60, -1, 1, 100, 0, 250, 1100, 3, 1739, 0, 1, 0, -1, 0 },
    { "InsectMan", "ANGELO", 3100, 855, 120, 4000, 100, -1, 1, 100, -1, 500, 100, 1, -1, -1, -1, -1, -1, 0 },
    { "Jester", "CHESTER", 3800, 800, 120, 3300, 100, -1, 4, 100, 30, 250, 1900, 3, 800, 0, 1, 0, -1, 0 },
    { "JetpackGirl", "JANET", 3400, 750, 120, 3650, 100, -1, 4, 100, 160, 200, 1500, 3, 1500, 0, 1, 0, -1, 4 },
    { "KatanaKid", "NORI", 3500, 855, 120, -1, -1, -1, 1, 150, 260, 300, 100, 1, -1, -1, -1, -1, -1, 1 },
    { "KickerDude", "FANG", 4800, 800, 145, 3200, 300, -1, 1, 500, -1, 250, 1000, 3, -1, -1, -1, -1, -1, 0 },
    { "Knight", "ASH", 5900, 750, 145, 5000, 250, -1, 1, 300, -1, 250, 1400, 3, 1196, 0, 1, -1, -1, 4 },
    { "Leaper", "MICO", 3500, 855, 120, -1, -1, -1, -1, -1, -1, 750, 2400, 3, -1, -1, -1, -1, -1, 1 },
    { "Lightyear", "BUZZ LIGHTYEAR", 3000, 720, 120, 4000, 101, -1, 1, 100, -1, 250, 1400, 3, 4000, 101, 1, 70, 1300, 0 },
    { "LightyearFlight", "LEON", 3600, 820, 120, 3500, 100, -1, 1, 150, 0, 50, 1900, 3, 3000, 0, 1, 0, -1, 0 },
    { "LightyearSword", "KENJI", 4200, 820, 120, -1, -1, -1, 1, 150, 300, 150, 1500, 3, -1, -1, -1, -1, -1, 1 },
    { "Luchador", "EL PRIMO", 6500, 800, 145, 3261, 150, -1, 1, 150, 0, 50, 800, 3, -1, -1, -1, -1, -1, 4 },
    { "MagicalGirl", "STARR NOVA", 3700, 855, 120, 15000, 250, -1, 1, 250, 0, 50, 1600, 3, -1, -1, -1, -1, -1, 4 },
    { "Maisie", "MAISIE", 4000, 750, 120, 3200, 101, -1, 1, 100, -1, 250, 1500, 3, -1, -1, -1, -1, 1800, 0 },
    { "MechaDude", "MEG", 2400, 855, 120, 4000, 150, -1, 1, 100, -1, 50, 1300, 3, -1, -1, -1, -1, -1, 0 },
    { "MechaDudeBig", "MEG", 3700, 750, 145, 4500, 100, -1, 2, 100, 20, 50, 1100, 3, -1, -1, 1, 300, -1, 128 },
    { "Mechanic", "JESSIE", 3300, 750, 120, 3050, 150, -1, 1, 100, 0, 250, 1800, 3, 1196, 0, 1, -1, -1, 0 },
    { "Meeple", "MEEPLE", 3300, 750, 120, 3000, 101, -1, 1, 100, -1, 500, 1700, 3, 1196, 0, 1, -1, -1, 0 },
    { "Mender", "GLOWY", 3900, 800, 120, 5000, 150, -1, 1, 100, -1, 200, 1700, 3, 5000, 300, 4, 220, -1, 0 },
    { "MinigunDude", "PAM", 5000, 750, 145, 4130, 50, -1, 1, 100, 60, 50, 1300, 3, 1196, 0, 1, -1, -1, 0 },
    { "Morningstar", "LUMI", 3500, 750, 120, 3500, 170, -1, 1, 250, -1, 150, -1, 2, 29000, 0, 1, -1, 100, 4 },
    { "Mummy", "EMZ", 3900, 750, 120, 1500, 200, -1, 5, 100, 80, 250, 2000, 3, -1, -1, -1, -1, -1, 4 },
    { "Ninja", "LEON", 3300, 855, 120, 3500, 100, -1, 1, 100, 35, 50, 1900, 3, -1, -1, -1, -1, -1, 0 },
    { "Painter", "BERRY", 2600, 750, 120, 2200, 0, -1, 1, 100, 0, 250, 2400, 3, -1, -1, -1, -1, -1, 64 },
    { "Percenter", "COLETTE", 3600, 750, 120, 4000, 150, -1, 1, 100, -1, 250, 1600, 3, -1, -1, -1, -1, -1, 0 },
    { "PowerLeveler", "SURGE", 3300, 705, 120, 3500, 150, -1, 1, 100, 0, 320, 2000, 3, -1, -1, -1, -1, -1, 0 },
    { "Puppeteer", "WILLOW", 3300, 750, 120, 1750, 0, -1, 1, 100, 0, 250, 2000, 3, 4130, 150, 1, -1, 1500, 64 },
    { "Redirecter", "NAJIA", 3400, 800, 120, 1700, 100, -1, 1, 100, -1, 100, 800, 1, 900, 0, 3, 270, -1, 4 },
    { "Reviver", "DOUG", 5200, 800, 145, -1, -1, -1, -1, 1000, -1, 250, 1500, 3, 4500, 200, 1, -1, 2000, 1 },
    { "Rock", "BOLT", 5000, 545, 120, -1, -1, -1, -1, -1, -1, 300, 2200, 2, -1, -1, -1, -1, -1, 1 },
    { "RocketGirl", "BROCK", 3000, 750, 120, 2700, 101, -1, 1, 100, -1, 250, 1950, 3, 900, 0, 1, 160, -1, 0 },
    { "Roller", "STU", 3500, 750, 120, 3300, 150, -1, 1, 100, 0, 100, 1500, 3, -1, -1, -1, -1, -1, 0 },
    { "RopeDude", "BUZZ", 5000, 800, 120, 4000, 250, -1, 3, 150, 165, 50, 1000, 3, 3800, 150, 1, -1, -1, 4 },
    { "Rosa", "ROSA", 5400, 800, 145, 5000, 150, -1, 3, 250, 130, 50, 1000, 3, -1, -1, -1, -1, -1, 4 },
    { "Ruffs", "RUFFS", 3000, 750, 120, 3800, 70, -1, 2, 100, -1, 250, 1400, 3, 1700, 0, 1, 0, -1, 0 },
    { "Samurai", "KENJI", 4000, 855, 120, -1, -1, -1, -1, -1, -1, 200, 1000, 3, 1000, 0, 1, -1, -1, 1 },
    { "Sandstorm", "SANDY", 4100, 800, 145, 3500, 200, -1, 3, 100, 80, 250, 1800, 3, 2000, 0, 1, 0, -1, 4 },
    { "Shadowdemon", "SIRIUS", 3400, 750, 120, 2500, 0, -1, 2, 250, -1, 300, 1600, 3, 29000, 0, 1, -1, -1, 64 },
    { "Shaman", "NITA", 4200, 750, 120, 2718, 250, -1, 1, 100, 0, 250, 1100, 3, 1196, 0, 1, -1, -1, 4 },
    { "ShieldTank", "BUSTER", 5000, 800, 120, 4200, 250, -1, 3, 200, 90, 350, 1800, 3, 4200, 50, -1, 120, -1, 4 },
    { "ShotgunGirl", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
    { "Silencer", "OTIS", 3600, 750, 120, 3600, 100, -1, 1, 120, 22, 250, 1500, 3, 3200, 200, 1, -1, 1000, 0 },
    { "Skater", "OLLIE", 5400, 800, 120, 3000, 100, -1, 2, 200, 27, 350, 1800, 3, -1, -1, -1, -1, -1, 4 },
    { "SnakeOil", "BYRON", 2600, 750, 120, 4000, 150, -1, 1, 100, -1, 500, 1450, 3, 2000, 0, 1, 0, -1, 0 },
    { "Sniper", "PIPER", 2800, 750, 120, 4000, 101, -1, 1, 100, -1, 500, 2300, 3, -1, -1, -1, -1, -1, 0 },
    { "SoulCollector", "GUS", 3300, 750, 120, 4000, 150, -1, 1, 100, -1, 500, 1500, 3, 3600, 200, 1, -1, -1, 0 },
    { "SpawnerDude", "MR. P", 3700, 750, 120, 3000, 200, -1, 1, 100, -1, 250, 1600, 3, 1196, 0, 1, -1, -1, 0 },
    { "Speedy", "MAX", 3500, 855, 120, 4000, 50, -1, 1, 100, 30, 50, 1300, 4, -1, -1, -1, -1, -1, 0 },
    { "Splitter", "R-T", 4100, 750, 145, 4500, 50, -1, 1, 100, 0, 500, 1500, 3, -1, -1, 1, -1, -1, 0 },
    { "Stacker", "VINCE", 3400, 750, 120, 4000, 150, -1, 1, 100, -1, 500, 1450, 3, 3200, 150, 1, -1, -1, 0 },
    { "Stalker", "ALLI", 3900, 800, 120, -1, -1, -1, -1, 100, -1, 100, 2100, 3, -1, -1, -1, -1, -1, 1 },
    { "StickyBomb", "SQUEAK", 3800, 750, 120, 4000, 50, -1, 1, 100, 0, 250, 2100, 3, 800, 0, 1, 0, -1, 0 },
    { "SuperNovaBeeSniper", "SuperNovaBeeSniper", 6500, 855, 140, 2800, 105, -1, 3, 100, 200, 50, 900, 1, 2500, 150, 15, 360, -1, 0 },
    { "SuperNovaCactus", "SuperNovaCactus", 8500, 750, 185, 2174, 150, -1, 1, 100, -1, 250, 1600, 3, 1739, 0, 1, 0, -1, 0 },
    { "SuperNovaFireDude", "SuperNovaFireDude", 7500, 855, 140, 2800, 200, -1, 3, 150, 150, 50, 300, 25, 2800, 0, 2, 0, -1, 4 },
    { "SuperNovaMagicalGirl", "SuperNovaMagicalGirl", 6000, 920, 160, -1, -1, -1, 1, 150, 300, 150, 700, 3, -1, -1, -1, -1, -1, 1 },
    { "SuperNovaVoodoo", "SuperNovaVoodoo", 7000, 750, 160, 1750, 40, -1, 1, 100, 0, 250, 1600, 3, 1196, 0, 1, -1, -1, 64 },
    { "TntDude", "DYNAMIKE", 3000, 800, 120, 1900, 0, -1, 2, 100, 30, 250, 1400, 3, 1600, 0, 1, 0, -1, 80 },
    { "TrickshotDude", "RICO", 3000, 750, 120, 3478, 101, -1, 1, 120, 15, 50, 1100, 3, 4891, 101, 1, 20, -1, 0 },
    { "Twins", "LARRY & LAWRIE", 3000, 800, 120, 2000, 0, -1, 1, 300, 0, 250, 2200, 3, 1196, 0, 1, -1, -1, 64 },
    { "Undertaker", "MORTIS", 4000, 855, 120, -1, -1, -1, -1, -1, -1, 0, 2400, 3, 3000, 400, 1, -1, -1, 1 },
    { "Voodoo", "JUJU", 3100, 750, 120, 1750, 0, -1, 1, 100, 0, 250, 1600, 3, 1196, 0, 1, -1, -1, 64 },
    { "Wally", "SPROUT", 3200, 750, 120, 1700, 50, -1, 1, 100, 30, 250, 1500, 3, 1739, 0, 1, 0, -1, 64 },
    { "WeaponThrower", "SAM", 5700, 800, 145, 5000, 150, -1, 1, 300, 100, 100, 1600, 3, 2900, 250, 1, -1, -1, 4 },
    { "Whirlwind", "CARL", 4200, 750, 120, 3000, 250, -1, 1, 100, 0, 500, 2000, 1, -1, -1, -1, -1, -1, 4 },
    { "f12191a373cbc743d1f7554b27999006a017d2eb", "SHELLY", 3900, 800, 120, 3100, 0, -1, 5, 100, 60, 250, 1500, 3, 4130, 50, 9, 100, -1, 0 },
};

const int g_hero_count = (int)(sizeof(g_heroes) / sizeof(g_heroes[0]));
