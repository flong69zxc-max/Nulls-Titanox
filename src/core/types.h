#ifndef RECOIL_TYPES_H
#define RECOIL_TYPES_H

#include "config.h"

typedef void (*fn_void_2_t)(void *, void *);

typedef void *(*fn_ptr_2_t)(void *, void *);

typedef void (*fn_settext_t)(void *, void *, int, int);

typedef void (*fn_setxy_t)(void *, float, float);

typedef void (*fn_send_movement_t)(void *, float, float);

typedef void (*fn_set_prediction_t)(void *, int, int);

typedef void *(*fn_get_inst_t)(void);

typedef void *(*fn_get_own_char_t)(void *);

typedef int (*fn_get_team_t)(void *);

typedef int (*fn_get_coord_t)(void *);

typedef struct {
    const char *name;
    uintptr_t rva;
} rcl_rva_entry_t;

typedef struct {
    __unsafe_unretained Class cls;
    __unsafe_unretained Class wanted[WANTED_MAX];
    int wantedCount;
    SEL sel;
    IMP original;
    IMP replacement;
    const char *selName;
    const char *signature;
    int hits;
    BOOL used;
} rcl_objc_hook_t;

typedef struct {
    uintptr_t at;
    uintptr_t vt;
    uintptr_t owner;
    int32_t gid;
    int32_t team;
    int32_t ownerIdx;
    int dead;
    int ownerClass;
} rcl_objhit_t;

typedef struct {
    uintptr_t rva;
    int seg;
    unsigned long long count;
    unsigned long long shaped;
    unsigned long long ownerEqVt;
    uintptr_t first;
    uintptr_t inst[RCL_VTCENSUS_INST];
    int instCount;
} rcl_vtcensus_t;

typedef uint64_t (*rcl_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                  uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

typedef struct {
    uintptr_t base;
    int used;
    int have;
    uint32_t prev[RCL_FLOATS];
} rcl_slot_t;

typedef struct {
    int sampled;
    int ascii;
    int noVt;
    int teamDistinct;
    int posDistinct;
} rcl_measure_t;

typedef struct {
    int elements;
    int live;
    int teamCount;
    int distinctGids;
    int deadOk;
    uintptr_t vt0;
} rcl_facts_t;

typedef struct {
    uintptr_t low;
    uintptr_t high;
} rcl_region_t;

typedef struct {
    uintptr_t manager;
    int32_t count;
    int32_t capacity;
    int live;
    int nonEmpty;
    int stable;
    int rawOk;
    char rawSeg;
    int ascii;
    int sampled;
    int noVt;
    int teamDistinct;
    int posDistinct;
    int refused;
} rcl_trail_t;

typedef struct {
    uintptr_t address;
    int32_t count;
    int pass;
} rcl_seen_t;

typedef struct {
    const char *label;
    const char *value;
    const char *provenance;
} rcl_fact_t;

typedef void (*rcl_setpred_t)(void *self, int x, int y);

typedef struct {
    uintptr_t object;
    int32_t   gid;
    int32_t   x;
    int32_t   y;
    int32_t   ownerIndex;
    int32_t   teamOld;
    int32_t   teamNew;
    int32_t   typeWord;
    uint8_t   dead;
    uint8_t   activeFlag;
} rcl_obj_t;

typedef struct {
    int elementsRead;
    int rejNull;
    int rejUnreadable;
    int rejAscii;
    int rejNoVt;
    int rejGidZero;
    int rejNonPlayer;
    int rejOutOfRange;
    int rejTeamMissing;
    int deadSeen;
} rcl_reject_t;

typedef struct {
    uintptr_t elem;
    uintptr_t classRva;
    int32_t x;
    int32_t y;
    int32_t px;
    int32_t py;
    int32_t team;
    int32_t spawnX;
    int32_t spawnY;
    int32_t gid;
    uint64_t ptick;
    uint64_t qtick;
    int hasPrev;
} rcl_proj_t;

typedef struct {
    float ax;
    float ay;
    float bx;
    float by;
    float speed;
    float dirX;
    float dirY;
    float inflatedR;
    float remaining;
    int32_t gid;
} rcl_seg_t;

typedef struct {
    uintptr_t base;
    int have;
    uint32_t prev[RCL_WORDS];
    uint16_t hot[RCL_WORDS];
} rcl_win_t;

#endif
