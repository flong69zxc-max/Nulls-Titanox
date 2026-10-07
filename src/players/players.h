#ifndef RECOIL_PLAYERS_PLAYERS_H
#define RECOIL_PLAYERS_PLAYERS_H

#include "core/types.h"

extern int rcl_own_x;
extern int rcl_own_y;

extern int rcl_cand_changes[RCL_CAND];
extern int rcl_cand_frame[RCL_CAND];
extern int rcl_dead_slot;
extern int rcl_dead_value;
extern int rcl_enemy_n;
extern int32_t rcl_enemy_x[RCL_PLAYER_MAX];
extern int32_t rcl_enemy_y[RCL_PLAYER_MAX];
extern int rcl_mate_n;
extern int32_t rcl_mate_x[RCL_MATE_MAX];
extern int32_t rcl_mate_y[RCL_MATE_MAX];
extern uintptr_t rcl_own_elem;
extern uintptr_t rcl_own_elem_2;
extern const char * rcl_own_from;
extern const char * rcl_own_from_a;
extern const char * rcl_own_from_b;
extern int32_t rcl_own_gid;
extern int rcl_own_index;
extern int rcl_own_index_3;
extern uintptr_t rcl_own_ptr;
extern uintptr_t rcl_own_ptr_a;
extern uintptr_t rcl_own_ptr_b;
extern uint64_t rcl_own_stamp;
extern int rcl_own_team_b;
extern int rcl_pending;
extern int rcl_pending_tick;
extern int rcl_pl_n;
extern int32_t rcl_pl_team[RCL_PLAYER_MAX];
extern int32_t rcl_pl_x[RCL_PLAYER_MAX];
extern int32_t rcl_pl_y[RCL_PLAYER_MAX];
extern uintptr_t rcl_players_array;
extern int rcl_players_count;
extern uintptr_t rcl_players_object;
extern int rcl_pre[RCL_CAND];
extern int rcl_prev_valid;
extern int rcl_respawn_tick;
extern int rcl_state_code;
extern int rcl_team_trust;
extern uint64_t rcl_tick_stamp;
void rcl_clear_life(void);
int rcl_enemy_blocked(float x, float y, float ownX, float ownY);
int rcl_life(uintptr_t ownElem, int32_t ownX, int32_t ownY);
int rcl_mate_blocked(float x, float y);
int rcl_own(int32_t *xOut, int32_t *yOut);
int rcl_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut, int32_t *gidOut);
void rcl_own_dump(uintptr_t element);
int rcl_own_from_list(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_own_from_slot(uintptr_t *objectOut, int32_t *gidOut);
void rcl_own_index_probe(void);
int rcl_own_latch(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
uintptr_t rcl_own_obj(void);
int rcl_own_ok(int32_t x, int32_t y);
void rcl_own_probe(void);
float rcl_own_radius(void);
int rcl_own_scan(void);
int rcl_own_side_spawn(int32_t sx, int32_t sy);
int rcl_own_verdict(uintptr_t element, char *why, size_t whyLen);
void rcl_publish_own(uintptr_t elem, const char *from);
int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_resolve_own_2(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
void rcl_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
void rcl_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const rcl_obj_t *objects, int usable);
int rcl_team_at(const rcl_obj_t *objects, int index);

int rcl_object_live(uintptr_t object);

#endif
