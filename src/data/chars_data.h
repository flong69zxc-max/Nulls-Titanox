#ifndef TNX_CHARS_DATA_H
#define TNX_CHARS_DATA_H

typedef struct {
    const char *name;
    const char *title;
    int hp;
    int speed;
    int radius;
    int wSpeed;
    int wRadius;
    int wCast;
    int wBullets;
    int wBetween;
    int wSpread;
    int wCd;
    int wRecharge;
    int wCharge;
    int uSpeed;
    int uRadius;
    int uBullets;
    int uSpread;
    int uRecharge;
    int flags;
} tnx_hero_t;

#define TNX_HF_MELEE 1
#define TNX_HF_BEAM 2
#define TNX_HF_PIERCE_CHAR 4
#define TNX_HF_PIERCE_WALL 8
#define TNX_HF_BOUNCE 16
#define TNX_HF_CHAIN 32
#define TNX_HF_GRAVITY 64
#define TNX_HF_IGNORE_CLOSE_WALL 128

extern const tnx_hero_t g_heroes[];

extern const int g_hero_count;

int tnx_hero_find(const char *name);

const tnx_hero_t *tnx_hero_row(int index);

const tnx_hero_t *tnx_hero_by_hash(uint32_t hash);

int tnx_hero_speed(void);

int tnx_hero_radius(void);

int tnx_hero_hp_max(void);

int tnx_hero_inflated(int projectile_radius, int fallback);

int tnx_hero_melee(int index);

void tnx_hero_own(int index);

void tnx_hero_identify(int hp_max, int speed_units);

void tnx_hero_report(void);

#endif
