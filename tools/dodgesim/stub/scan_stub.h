#ifndef SIM_SCAN_STUB
#define SIM_SCAN_STUB
typedef unsigned int vm_prot_t;


typedef struct
{
    uintptr_t at;
    uintptr_t vt;
    int32_t gid;
    int32_t team;
    int dead;
} rcl_objhit_t;

typedef uint64_t (*rcl_slot_fn_t)(void *a0, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5,
                                  uint64_t a6, uint64_t a7);

typedef struct
{
    uintptr_t low;
    uintptr_t high;
} rcl_region_t;

typedef struct
{
    uintptr_t manager;
    int32_t count;
    int32_t capacity;
    int posDistinct;
} rcl_trail_t;

typedef struct
{
    uintptr_t object;
    int32_t gid;
    int32_t x;
    int32_t y;
    int32_t ownerIndex;
    int32_t teamOld;
    int32_t teamNew;
    int32_t typeWord;
    uint8_t dead;
    uint8_t activeFlag;
} rcl_obj_t;

extern uintptr_t rcl_base;
extern const char *rcl_image_names[4];
extern uintptr_t *rcl_starts;
extern size_t rcl_starts_count;
extern BOOL rcl_setup_done;
extern BOOL rcl_aim_rejected;
extern int rcl_dump_np;
extern BOOL rcl_mode_strong;
extern uintptr_t rcl_players_object;
extern int rcl_manager_count;
extern uintptr_t rcl_objvote_best_owner;
extern int rcl_objvote_best_teamcount;
extern rcl_objhit_t rcl_objhits[64];
extern int rcl_objhit_count;
extern int rcl_objvote_max_votes;
extern int rcl_trail_best;
extern int rcl_votescan_attempts;
extern double rcl_votescan_last;
extern BOOL rcl_snapshot_first;
extern BOOL rcl_snapshot_second;
extern double rcl_snapshot_start;
extern uintptr_t rcl_addr_getinstance;
extern uintptr_t rcl_addr_getownchar;
extern uintptr_t rcl_addr_getteam;
extern uintptr_t rcl_addr_getx;
extern uintptr_t rcl_addr_gety;
extern uintptr_t rcl_addr_battlescreen;
extern int rcl_no_source_passes;
extern int rcl_sig_ticks;
extern uintptr_t rcl_sig_last;
extern uintptr_t rcl_players_array;
extern int rcl_players_count;
extern uint64_t rcl_walk_tick;
extern int rcl_walk_count;
extern int rcl_coord_fixed_logged;
extern uint64_t rcl_time;
extern uint64_t rcl_q_max;
extern uintptr_t rcl_owner;
extern int rcl_wired;
extern rcl_region_t rcl_heap_regions[512];
extern int rcl_heap_region_count;
extern uintptr_t rcl_heap_window_low;
extern uintptr_t rcl_heap_window_high;
extern rcl_trail_t rcl_trail[8];
extern int rcl_trail_count;
extern int rcl_dodge_probe_usable;
extern int rcl_issued;
extern uintptr_t rcl_own_elem_2;
extern uint64_t rcl_hold;
BOOL rcl_addr_writable(uintptr_t address, size_t length);
BOOL rcl_read_bytes(uintptr_t address, void *out, size_t length);
BOOL rcl_pointer_plausible(uintptr_t value);
BOOL rcl_read_byte(uintptr_t address, uint8_t *out);
BOOL rcl_read_int(uintptr_t address, int32_t *out);
BOOL rcl_read_float(uintptr_t address, float *out);
BOOL rcl_writable(uintptr_t address, size_t length);
void rcl_note(uintptr_t address, const void *src, size_t length, int denied);
BOOL rcl_write_bytes(uintptr_t address, const void *src, size_t length);
BOOL rcl_read_ptr(uintptr_t address, void **out);
void *rcl_read_global_ptr(uintptr_t rva);
uintptr_t rcl_callable(uintptr_t rva);
BOOL rcl_copy(uintptr_t source, void *destination, size_t length);
BOOL rcl_text_section(uintptr_t *address, uint64_t *size);
BOOL rcl_valid_header(uintptr_t base);
BOOL rcl_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi);
void rcl_image_span_refresh(void);
const char *rcl_image_segment_name(uintptr_t value);
void rcl_heap_regions_refresh(void);
BOOL rcl_vtable_shaped(uintptr_t value);
BOOL rcl_heap_resident(uintptr_t value);
BOOL rcl_instance_shaped(uintptr_t object);
BOOL rcl_manager_shape(uintptr_t manager);
BOOL rcl_vtable_in_image(uintptr_t vtable);
uintptr_t rcl_strip_ptr(uintptr_t value);
extern uint64_t rcl_ticks_a;
extern uintptr_t rcl_manager_ptr;
extern int rcl_logs_a;
extern int rcl_seeded;
extern int32_t rcl_last_x_a;
extern int32_t rcl_last_y_a;
int rcl_collect(uintptr_t manager, rcl_obj_t *out, int capacity);
int rcl_small(long value);
float rcl_as_float(uint32_t bits);
void rcl_discriminate(uintptr_t manager);
void rcl_probe(uintptr_t manager, uintptr_t mode, int verbose);
uint64_t rcl_us(void);
void rcl_paircal(void);
uintptr_t rcl_pair_base(void);
#define RCL_COORD_SOFT 0
#define RCL_NP_DUMPS 8
#define RCL_ELEMS 8
#define RCL_WORDS_2 24
#define RCL_VALUE_MAX 1000000
#define RCL_FLOAT_MAX 10000.0f
#define RCL_TEAM_MAX 8
uintptr_t rcl_entry(uintptr_t rva);
int rcl_is_prologue(uint32_t w);
int rcl_is_term(uint32_t w);
void rcl_load_function_starts(void);
BOOL rcl_looks_like_start(uintptr_t address);
const char *rcl_prologue_rule(uintptr_t address);
BOOL rcl_start_boundary(const uint8_t *bytes, size_t offset);
size_t rcl_start_index(uintptr_t address, BOOL *exact);
BOOL rcl_start_word(uint32_t word);
int rcl_word(uintptr_t address, uint32_t *out);
void rcl_slot_note(int index, void *self, uint64_t arg1);
uint64_t rcl_hook_dispatches(void);
uint64_t rcl_object_dispatches(void);
extern int rcl_bar_logged;
extern int rcl_fb_logged;
extern int rcl_fb_on;
extern int rcl_idle_logged;
extern uint64_t rcl_idle_start;
extern int rcl_live_objs;
extern int rcl_live_teams;
extern uintptr_t rcl_pub_array;
extern int32_t rcl_pub_count;
extern int rcl_pub_logs;
extern uintptr_t rcl_pub_object;
extern int rcl_scan_armed;
extern uintptr_t rcl_setpred;
extern uintptr_t rcl_site;
extern rcl_slot_fn_t rcl_slot_orig[34];
extern int rcl_state_2;
extern uintptr_t rcl_tick_array;
extern int32_t rcl_tick_count;
extern uintptr_t rcl_tick_object;
extern const int rcl_object_slots[3];
void rcl_publish(uintptr_t object, uintptr_t array, int32_t count, int32_t cap, const char *why);
void rcl_slot_hooks_install(void);
void rcl_slot_pump(void);
int rcl_snapshot(uintptr_t *objectOut, uintptr_t *arrayOut, int32_t *countOut);
void rcl_tick_begin(void);
extern uintptr_t rcl_slot_object[34];
extern uintptr_t rcl_slot_arg[34];
extern uint64_t rcl_slot_hits[34];
extern uintptr_t rcl_slot_adopted;
extern int rcl_battle_active;
extern int rcl_battle_last_tick;
extern int rcl_hb_sig_prev;
int rcl_battle_gate(int scene);
extern uint64_t rcl_ticks_b;
int rcl_battle_gate_2(int v63);
int rcl_scan_allowed(uint64_t fired, uint64_t total);
void rcl_start_timer(void);
int rcl_state_tick(void);
int rcl_vtable_is_data(uintptr_t vtable);
void rcl_run_workload(void);
void rcl_run_autododge(int from_update);
#define RCL_WIRE_OWNER 1
#define RCL_HOPCHOSEN_DIRECT 2
#define RCL_DRIVE_FROM_UPDATE 0
#define RCL_ARRAY_VOTE_LOGS 8
#define RCL_HB_TICKS 5
#define RCL_QUIET_SECS 10
#define RCL_LIVE_OBJ_MIN 3
#define RCL_LIVE_TEAM_MIN 2
#define RCL_BAR_TICKS 30
#define RCL_IDLE_TICKS 15
#define RCL_IDLE_RETRY_TICKS 300
#define RCL_SNAPSHOT_DELAY 1.2
#define RCL_LOGS_ON 0
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
extern uintptr_t rcl_hop_scene;
extern int rcl_last_choice;
extern int rcl_hop_logs;
extern int rcl_probe_done;
extern uintptr_t rcl_probe_object;
extern uint64_t rcl_probe_last_ms;
extern int rcl_coord_ok;
extern int rcl_coord_usable;
extern int rcl_team_off;
extern uint64_t rcl_last_write_ms;
extern rcl_obj_t rcl_dodge_probe_list[64];
extern int rcl_gidless;
extern int rcl_stage;
extern int rcl_dead;
extern int rcl_own_team_a;
extern int rcl_proj_other;
extern int rcl_own_team_seen;
extern uintptr_t rcl_proj_addr;
extern uint8_t rcl_proj_bytes[0x100];
extern int rcl_proj_have;
extern int rcl_proj_dumps;
extern uint64_t rcl_proj_diff_logs;
extern uintptr_t rcl_own_elem;
extern int32_t rcl_own_gid;
extern rcl_proj_t rcl_projs[16];
extern rcl_proj_death_t rcl_proj_deaths[16];
extern int rcl_proj_death_n;
extern int rcl_signal_logs;
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
void rcl_read_map(uintptr_t mode);
void rcl_gidless_scan(uintptr_t manager);
uintptr_t rcl_list_gid_off(uintptr_t array, int32_t count);
void rcl_proj_track(uintptr_t elem, uintptr_t classRva, int32_t gid, int32_t team);
void rcl_own_probe(void);
int rcl_own_latch(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_vt_ok(uintptr_t obj, uintptr_t *vtOut);
int rcl_cand_ok(uintptr_t cand, const char **why, uintptr_t *vtOut);
uintptr_t rcl_hop(uintptr_t base, int *whyOut);
uintptr_t rcl_client(void);
int rcl_own_by_min_gid(uintptr_t array, int32_t count, uintptr_t *elemOut, int32_t *gidOut);
int rcl_own_from_list(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
void rcl_state_note(int state);
int rcl_own_scan(void);
int rcl_resolve_own_2(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
int rcl_proj_scan(uintptr_t manager, int32_t count);
uintptr_t rcl_controller(void);
void rcl_death_signals(uintptr_t ownElem, int32_t ownX, int32_t ownY);
void rcl_alive(int32_t ownX, int32_t ownY);
int rcl_own(int32_t *xOut, int32_t *yOut);
uint64_t rcl_word_2(uintptr_t address);
const char *rcl_header_reason(uintptr_t manager, int32_t *countOut, int32_t *capOut);
uintptr_t rcl_coord_x_off(void);
uintptr_t rcl_coord_y_off(void);
int rcl_ctrl_bounds(uintptr_t base, int32_t *wOut, int32_t *hOut);
extern int rcl_own_x;
extern int rcl_own_y;
extern int rcl_cand_changes[3];
extern int rcl_cand_frame[3];
extern int rcl_dead_slot;
extern int rcl_dead_value;
extern int rcl_enemy_n;
extern int32_t rcl_enemy_x[12];
extern int32_t rcl_enemy_y[12];
extern int rcl_mate_n;
extern int32_t rcl_mate_x[8];
extern int32_t rcl_mate_y[8];
extern const char *rcl_own_from;
extern int rcl_own_index;
extern uintptr_t rcl_own_ptr;
extern int rcl_own_team_b;
extern int rcl_pending;
extern int rcl_pending_tick;
extern int rcl_pl_n;
extern int32_t rcl_pl_team[12];
extern int32_t rcl_pl_x[12];
extern int32_t rcl_pl_y[12];
extern int rcl_pre[3];
extern int rcl_prev_valid;
extern int rcl_respawn_tick;
extern int rcl_state_code;
extern int rcl_team_trust;
extern uint64_t rcl_tick_stamp;
void rcl_clear_life(void);
int rcl_life(uintptr_t ownElem, int32_t ownX, int32_t ownY);
int rcl_own_from_slot(uintptr_t *objectOut, int32_t *gidOut);
void rcl_own_index_probe(void);
int rcl_own_ok(int32_t x, int32_t y);
float rcl_own_radius(void);
int rcl_own_side_spawn(int32_t sx, int32_t sy);
void rcl_publish_own(uintptr_t elem, const char *from);
int rcl_resolve_own(const rcl_obj_t *objects, int usable, int *indexOut, const char **fromOut);
void rcl_respawn_event(int32_t x, int32_t y, int32_t px, int32_t py);
void rcl_roster(uintptr_t ownElem, int ownIndex, int ownTeam, const rcl_obj_t *objects, int usable);
int rcl_team_at(const rcl_obj_t *objects, int index);
#define RCL_CLUSTER 700.0f
#define RCL_DEAD_ONCE 1
#define RCL_GIDLESS 1
#define RCL_POS_BONUS 8
#define RCL_DIST_BONUS 6
#define RCL_SOFT_BASE 2
#define RCL_SOFT_MIN_POS 2
#define RCL_SOFT_MIN_DIST 2
#define RCL_LOGS_a 12
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
int rcl_witness(int32_t *x, int32_t *y);
extern uintptr_t rcl_own_elem;
extern int rcl_team_off;
extern int rcl_mate_n;
extern int32_t rcl_mate_x[8];
extern int32_t rcl_mate_y[8];
extern int rcl_proj_death_n;
extern rcl_proj_death_t rcl_proj_deaths[16];
extern rcl_proj_t rcl_projs[16];
extern int rcl_ok(float v, float lo, float hi);

extern int rcl_rad_off;
extern float rcl_rad_est;
extern int rcl_cal_off_seen;
extern float rcl_cal_rad_seen;
extern uintptr_t rcl_tiles;
extern int rcl_tile_w;
extern int rcl_tile_h;
int rcl_proj_vel(const rcl_proj_t *p, float *vxOut, float *vyOut);
extern int rcl_cal_n;
extern float rcl_cal_rad[64];
extern int rcl_cal_off[64];
extern int32_t rcl_enemy_x[12];
extern int32_t rcl_enemy_y[12];
extern int rcl_enemy_n;
#endif
