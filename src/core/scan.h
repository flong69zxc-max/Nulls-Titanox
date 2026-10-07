#ifndef RECOIL_SCAN_SCAN_H
#define RECOIL_SCAN_SCAN_H

#include "./types.h"

extern uintptr_t rcl_scene_object;

extern int rcl_prev_state;
extern uintptr_t rcl_own_ptr_a;
extern int rcl_hop_chosen;
extern int rcl_hop_sticky;
extern int rcl_modesig_hits;
extern int rcl_floor_logged;
extern int rcl_fallback_logged;
extern uintptr_t rcl_own_ptr_b;
extern int rcl_own_index_3;
extern uintptr_t rcl_scan_container;
extern int rcl_own_logged;
extern uint64_t rcl_wrote_tick;
extern int rcl_wrote_valid;
extern int rcl_check_done;
extern uint64_t rcl_pred_miss;
extern uintptr_t rcl_hop_scene;
extern int rcl_coord_logs;
extern int rcl_last_choice;
extern int rcl_hop_logs;
extern int rcl_setpred_state;
extern int rcl_probe_done;
extern uintptr_t rcl_probe_object;
extern uint64_t rcl_probe_last_ms;
extern int rcl_coord_ok;
extern int rcl_coord_usable;
extern int rcl_team_off;
extern uint64_t rcl_last_write_ms;
extern rcl_obj_t rcl_dodge_probe_list[RCL_OBJECT_MAX];
extern int rcl_gidless;
extern int rcl_stage;
extern int32_t rcl_last_x;
extern int32_t rcl_last_y;
extern int rcl_dead;
extern int rcl_own_team_a;
extern int rcl_proj_other;
extern int rcl_own_team_seen;
extern int rcl_team_other_seen;
extern uintptr_t rcl_proj_addr;
extern uint8_t rcl_proj_bytes[RCL_DIFF_BYTES];
extern int rcl_proj_have;
extern int rcl_proj_dumps;
extern uint64_t rcl_proj_diff_logs;
extern uintptr_t rcl_own_elem;
extern uint64_t rcl_own_stamp;
extern int rcl_own_logs_b;
extern int32_t rcl_own_gid;
extern rcl_proj_t rcl_projs[RCL_PROJ_MAX];
extern int rcl_side_hits;
extern int rcl_side_projs;
extern int rcl_signal_logs;
extern float rcl_walk_step;
extern int32_t rcl_prev_x_3;
extern int32_t rcl_prev_y_3;
extern int rcl_prev_ok;

int rcl_modesig_hit(uintptr_t at);
void rcl_modesig_tick(void);
int rcl_element_type(uintptr_t vt, uintptr_t *wordOut);
int rcl_container_header(uintptr_t object, uintptr_t *arrayOut, int32_t *countOut, int32_t *capOut);
int32_t rcl_gid_at(uintptr_t element, uintptr_t off);
int32_t rcl_gid(uintptr_t element, int32_t *offOut);
int rcl_container_score(uintptr_t container);
int rcl_own_verdict(uintptr_t element);
int rcl_scan_ready(int battle);
void rcl_resolve_addresses(void);
void rcl_locate_battle_mode(void);
int rcl_verify_setprediction(void);
void rcl_read_map(uintptr_t mode);
void rcl_gidless_scan(uintptr_t manager);
uintptr_t rcl_list_gid_off(uintptr_t array, int32_t count);
void rcl_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team);
int rcl_mode_real(uintptr_t mode, uintptr_t *vtOut, uintptr_t *chainOut, uintptr_t *innerOut);
void rcl_own_probe(void);
int rcl_own_latch(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_vt_ok(uintptr_t obj, uintptr_t *vtOut);
int rcl_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut);
uintptr_t rcl_hop(uintptr_t base, int *whyOut);
uintptr_t rcl_own_obj(void);
uintptr_t rcl_client(void);
int rcl_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut, int32_t *gidOut);
int rcl_own_from_list(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
void rcl_state_note(int state);
int rcl_own_scan(void);
int rcl_resolve_own_2(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_proj_scan(uintptr_t manager, int32_t count);

uintptr_t rcl_controller(void);
void rcl_watch(int32_t ownX, int32_t ownY);
void rcl_death_signals(uintptr_t ownElem, int32_t ownX, int32_t ownY);
void rcl_alive(int32_t ownX, int32_t ownY);
int rcl_own(int32_t *xOut, int32_t *yOut);
float rcl_step(void);
void rcl_measure(void);
int rcl_proj_mine(const rcl_proj_t *p);
void rcl_state(void);
uint64_t rcl_word_2(uintptr_t address);
const char *rcl_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut);
uintptr_t rcl_coord_x_off(void);
uintptr_t rcl_coord_y_off(void);

extern const uintptr_t rcl_mode_vtables[36];
extern rcl_trail_t rcl_trail[RCL_TRAIL_MAX];
int rcl_ctrl_bounds(uintptr_t base, int32_t *wOut, int32_t *hOut);
void rcl_paircal(void);
void rcl_probe(uintptr_t manager, uintptr_t mode, int verbose);




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
int rcl_own_verdict(uintptr_t element);
void rcl_publish_own(uintptr_t elem, const char *from);
int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_resolve_own_2(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
void rcl_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
void rcl_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const rcl_obj_t *objects, int usable);
int rcl_team_at(const rcl_obj_t *objects, int index);

int rcl_object_live(uintptr_t object);

#define RCL_ENEMY_HARD 150.0f
#define RCL_ENEMY_FAR 400.0f
#define RCL_ENEMY_MARGIN 60.0f
#define RCL_PROJ_OWNER 1
#define RCL_SPAWN_R 520.0f
#define RCL_WALK_MIN 1.0f
#define RCL_WALK_MAX 60.0f
#define RCL_WALK_EMA 0.12f
#define RCL_CLUSTER 700.0f
#define RCL_DEAD_ONCE 1
#define RCL_GIDLESS 1
#define RCL_POS_BONUS 8
#define RCL_DIST_BONUS 6
#define RCL_SOFT_BASE 2
#define RCL_SOFT_MIN_POS 2
#define RCL_SOFT_MIN_DIST 2
#define RCL_LOGS_a 12
#define RCL_MATE_CLEAR 240.0f
#define RCL_ATTRIB_R (700.0f * 700.0f)
#define RCL_ATTRIB_MARGIN 1.5f
#define RCL_RESPAWN_JUMP 1200
#define RCL_RESPAWN_VISIBLE 90
#define RCL_HOLD_FRAMES 10
#define RCL_STATE_INIT 0
#define RCL_STATE_ALIVE 1
#define RCL_STATE_DEAD 2
#define RCL_STATE_RESPAWN 3
#define RCL_PUB_LOGS 10
#define RCL_MIN_OBJ_BYTES 0x118ULL
#define RCL_DUMPS 3
#define RCL_DIFF_LOGS 48
#define RCL_MAP_MAX 512
#define RCL_COUNT_MAX 96
#define RCL_SCAN_QWORDS 512
#define RCL_SCAN_BASES 3
#define RCL_BUCKET_TICKS_2 10
#define RCL_SCAN_FLOOR_TICKS 12
#define RCL_SCAN_FALLBACK_TICKS 20
#define RCL_MODESIG_TICKS 3
#define RCL_ASCII_RATIO 30
#define RCL_GID_MAX 10000000
#define RCL_GID_FLOOR 1000000
#define RCL_COORD_MAX 100000
#define RCL_VOTESCAN_GLOBAL_EVERY 10
#define RCL_VOTESCAN_INTERVAL 1.0
#define RCL_VOTESCAN_ATTEMPTS 600

int rcl_ascii_word(uintptr_t address);
int rcl_word_ascii(uint64_t value);
int rcl_element_ascii(uintptr_t element);

#define SCAN_MAX 256

#endif
