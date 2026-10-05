#include "titanox.h"

    uintptr_t rva;

} tnx_rva_entry_t;

const char *g_image_names[] = {
    "Nulls Brawl",
    "Laser",
    "NB.app",
    NULL
};

const tnx_rva_entry_t g_rvas[] = {
    { "RVA_BATTLEMODE_GETINSTANCE", RVA_BATTLEMODE_GETINSTANCE },
    { "RVA_BATTLESCREEN__BATTLESCREEN", RVA_BATTLESCREEN__BATTLESCREEN },
    { "RVA_BATTLESCREEN__UPDATEMOVEMENT", RVA_BATTLESCREEN__UPDATEMOVEMENT },
    { "RVA_BATTLESCREEN__UPDATEAUTOSHOOT", RVA_BATTLESCREEN__UPDATEAUTOSHOOT },
    { "RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT", RVA_BATTLESCREEN_GETCLOSESTTARGETFORAUTOSHOOT },
    { "RVA_BATTLESCREEN__TRYTOACTIVATESKILL", RVA_BATTLESCREEN__TRYTOACTIVATESKILL },
    { "RVA_LOGICBATTLEMODECLIENT_UPDATE", RVA_LOGICBATTLEMODECLIENT_UPDATE },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER", RVA_LOGICBATTLEMODECLIENT_GETOWNCHARACTER },
    { "RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM", RVA_LOGICBATTLEMODECLIENT_GETOWNPLAYERTEAM },
    { "RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO", RVA_LOGICBATTLEMODECLIENT_SETCLIENTPREDICTIONMOVETO },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETDATA", RVA_LOGICGAMEOBJECTCLIENT_GETDATA },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID", RVA_LOGICGAMEOBJECTCLIENT_GETGLOBALID },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETX", RVA_LOGICGAMEOBJECTCLIENT_GETX },
    { "RVA_LOGICGAMEOBJECTCLIENT_GETY", RVA_LOGICGAMEOBJECTCLIENT_GETY },
    { "RVA_LOGICPROJECTILEDATA_GETSPEED", RVA_LOGICPROJECTILEDATA_GETSPEED },
    { "RVA_LOGICPROJECTILEDATA_GETRADIUS", RVA_LOGICPROJECTILEDATA_GETRADIUS },
    { "RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR", RVA_LOGICTILEMAP__ISPLAYERLINEOFSIGHTCLEAR },
    { "RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION", RVA_LOGICGAMEPLAYUTIL__GETCLOSESTANYCOLLISION },
    { "RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT", RVA_CLIENTINPUTMESSAGE_SENDMOVEMENT },
    { "RVA_STAGE_ADDCHILD", RVA_STAGE_ADDCHILD },
    { "RVA_STRINGTABLE_GETMOVIECLIP", RVA_STRINGTABLE_GETMOVIECLIP },
    { "RVA_MOVIECLIP__GETTEXTFIELDBYNAME", RVA_MOVIECLIP__GETTEXTFIELDBYNAME },
    { "RVA_TEXTFIELD_SETTEXT", RVA_TEXTFIELD_SETTEXT },
    { "RVA_DISPLAYOBJECT__SETXY", RVA_DISPLAYOBJECT__SETXY },
    { "RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS", RVA_LOGICGAMEOBJECTMANAGERCLIENT__GETGAMEOBJECTS },
    { "RVA_BATTLESCREEN_FIREWRAPPERFN", RVA_BATTLESCREEN_FIREWRAPPERFN },
    { "RVA_BATTLESCREEN_ACTIVATESKILL", RVA_BATTLESCREEN_ACTIVATESKILL },
    { "RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS", RVA_LOGICCHARACTERDATA_GETCOLLISIONRADIUS },
    { "RVA_MESSAGEMANAGER__RECEIVEMESSAGE", RVA_MESSAGEMANAGER__RECEIVEMESSAGE },
    { "RVA_COMBATHUD__SETMOVESTICKSTATE", RVA_COMBATHUD__SETMOVESTICKSTATE },
    { "RVA_COMBATHUD__SETSHOOTSTICKSTATE", RVA_COMBATHUD__SETSHOOTSTICKSTATE },
    { NULL, 0 }
};

    __unsafe_unretained Class wanted[WANTED_MAX];

    int wantedCount;

    SEL sel;

    IMP original;

    IMP replacement;

    const char *selName;

    const char *signature;

    int hits;

    BOOL used;

} tnx_objc_hook_t;

uintptr_t g_base = 0;

uintptr_t *g_starts = NULL;

size_t g_starts_count = 0;

FILE *g_log = NULL;

long g_log_written = 0;

BOOL g_setup_done = NO;

BOOL g_wm_failed = NO;

BOOL g_wm_ready = NO;

BOOL g_aim_rejected = NO;

__thread BOOL g_inside_hook = NO;

int g_v123_defer_logs = 0;

uint64_t g_v138_dodge_calls = 0;

uint64_t g_v138_render_calls = 0;

int g_v138_dump_np = 0;

uintptr_t g_v138_prev_scene = 0;

const uintptr_t g_mode_vtables_verified[] = { 0x1002548, 0xff5720, 0 };

int tnx_verified_vtable(uintptr_t vtable) {
    if (!g_base || vtable <= g_base) return -1;

    uintptr_t rva = vtable - g_base;

    for (int i = 0; g_mode_vtables_verified[i]; i++) {
        if (rva == g_mode_vtables_verified[i]) return i;
    }

    return -1;
}

uintptr_t g_scene_object = 0;

BOOL g_mode_strong = NO;

int g_mode_best_objects = 0;

int g_mode_last_types = 0;

int g_mode_verified_hits = 0;

uintptr_t g_players_object = 0;

int g_manager_count = 0;

int g_manager_probes = 0;

int g_manager_probes_total = 0;

int g_manager_skipped = 0;

int g_manager_last_live = 0;

int g_manager_last_nonempty = 0;

int g_manager_last_capacity = 0;

int g_manager_saw_cap = 0;

int g_manager_loose_count = 0;

int g_chain_checks = 0;

int g_chain_probes = 0;

int g_chain_skipped = 0;

int g_chain_best_own = 0;

int g_chain_best_gid = 0;

int g_seen_stable = 0;

int g_owner_vote_count = 0;

unsigned long long g_objvote_hits = 0;

unsigned long long g_objvote_skipped = 0;

int g_objvote_dead_seen = 0;

uintptr_t g_objvote_best_owner = 0;

int g_objvote_best_gids = 0;

int g_objvote_confirm = 0;

BOOL g_objvote_owner_ok = NO;

unsigned long long g_objvote_owner_img = 0;

unsigned long long g_objvote_obj_img = 0;

int g_objvote_best_teamcount = 0;

int g_objvote_best_gids_full = 0;

    uintptr_t vt;

    uintptr_t owner;

    int32_t gid;

    int32_t team;

    int32_t ownerIdx;

    int dead;

    int ownerClass;

} tnx_objhit_t;

tnx_objhit_t g_objhits[TNX_OBJ_HIT_DUMP_MAX];

int g_objhit_count = 0;

unsigned long long g_objvote_owner_reg = 0;

unsigned long long g_objvote_owner_above_win = 0;

int g_objvote_max_votes = 0;

unsigned long long g_objvote_shaped = 0;

    int seg;

    unsigned long long count;

    unsigned long long shaped;

    unsigned long long ownerEqVt;

    uintptr_t first;

    uintptr_t inst[TNX_VTCENSUS_INST];

    int instCount;

} tnx_vtcensus_t;

tnx_vtcensus_t g_vtcensus[TNX_VTCENSUS_MAX];

int g_vtcensus_used = 0;

unsigned long long g_vtcensus_total = 0;

int g_heap_big_skip = 0;

int g_heap_region_capped = 0;

uintptr_t g_img_span_lo = 0;

uintptr_t g_img_span_hi = 0;

int g_img_span_ok = 0;

int g_trail_best = 0;

int g_manager_cap_rejects = 0;

int g_manager_best_count = 0;

int g_manager_best_live = 0;

int g_heap_passes = 0;

unsigned long long g_heap_covered = 0;

uintptr_t g_mode_source = 0;

int g_votescan_attempts = 0;

double g_votescan_last = 0.0;

BOOL g_snapshot_first = NO;

BOOL g_snapshot_second = NO;

double g_snapshot_start = 0.0;

tnx_objc_hook_t g_objc_hooks[OBJC_HOOK_MAX];

int g_objc_armed = 0;

uintptr_t g_addr_getinstance = 0;

uintptr_t g_addr_getownchar = 0;

uintptr_t g_addr_getteam = 0;

uintptr_t g_addr_getx = 0;

uintptr_t g_addr_gety = 0;

uintptr_t g_addr_setprediction = 0;

uintptr_t g_addr_sendmovement = 0;

uintptr_t g_addr_getclip = 0;

uintptr_t g_addr_gettf = 0;

uintptr_t g_addr_settext = 0;

uintptr_t g_addr_setxy = 0;

uintptr_t g_addr_addchild = 0;

uintptr_t g_addr_battlescreen = 0;

void *g_label_clip = NULL;

void *g_label_tf = NULL;

void *g_label_sc = NULL;

char g_label_text[64] = {0};

int g_label_updates = 0;

uintptr_t tnx_strip_imp(IMP imp) {
#if defined(__has_feature)
#if __has_feature(ptrauth_calls)
    return (uintptr_t)ptrauth_strip((void *)imp, ptrauth_key_function_pointer);
#endif
#endif
    return (uintptr_t)imp;
}

FILE *g_battle_log = NULL;

BOOL g_battle_capture = NO;

BOOL g_battle_header = NO;

void tnx_battle_write(const char *utf8, size_t len) {
    if (!g_battle_log) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

        if (paths.count == 0) return;

        NSString *path = [paths[0] stringByAppendingPathComponent:@"Titanox.battle.log"];
        g_battle_log = fopen(path.UTF8String, "a");
    }

    if (!g_battle_log) return;

    if (!g_battle_header) {
        g_battle_header = YES;

        const char *header = "---- battle capture started ----\n";
        fwrite(header, 1, strlen(header), g_battle_log);
    }

    fwrite(utf8, 1, len, g_battle_log);
    fflush(g_battle_log);
}

uintptr_t g_v245_addr[TNX_V245_JOURNAL];

uint32_t g_v245_value[TNX_V245_JOURNAL];

uint64_t g_v245_tick[TNX_V245_JOURNAL];

const char *g_v245_phase[TNX_V245_JOURNAL];

uint8_t g_v245_size[TNX_V245_JOURNAL];

uint8_t g_v245_denied[TNX_V245_JOURNAL];

volatile int g_v245_at = 0;

volatile uint64_t g_v245_writes = 0;

uint64_t g_v245_stale = 0;

tnx_slot_fn_t g_slot_orig[TNX_SLOT_COUNT] = { NULL };

uintptr_t g_slot_object[TNX_SLOT_COUNT] = { 0 };

uintptr_t g_slot_arg1[TNX_SLOT_COUNT] = { 0 };

uint64_t g_slot_hits[TNX_SLOT_COUNT] = { 0 };

uint64_t g_slot_hits_total = 0;

int g_slot_installed[TNX_SLOT_COUNT] = { -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1, -1, -1, -1,
                                               -1, -1, -1, -1 };

int g_slot_slots[TNX_SLOT_COUNT] = { 0 };

int g_v55_chain_rej[20] = { 0 };

int g_v55_chain_probes_pass = 0;

int g_v55_layout_logs = 0;

int g_v54_no_source_passes = 0;

int g_v54_route_logged = 0;

uint32_t g_slot_reported_mask = 0;

uint64_t g_slot_first_tick[TNX_SLOT_COUNT] = { 0 };

uintptr_t g_slot_adopted = 0;

int g_ag_adopted = 0;

int g_v59_chain_hits = 0;

int g_v59_mode_from_chain = 0;

int g_v59_idle_probe_logged = 0;

uintptr_t g_v59_last_cand = 0;

uintptr_t g_v59_last_vt = 0;

char g_v59_last_why[96] = { 0 };

char g_v59_drop_tags[TNX_V59_TAG_MAX][8];

char g_v59_keep_tags[TNX_V59_TAG_MAX][8];

int g_v65_sig_ticks = 0;

int g_v65_sig_logs = 0;

uintptr_t g_v65_sig_last = 0;

int g_v67_layout_used = 0xc;

int g_v67_layout_logs = 0;

int g_v72_trail_refusals = 0;

uintptr_t g_players_array = 0;

int g_players_count = 0;

int g_players_cap = 0;

int g_v85_field_scans = 0;

int g_v88_elem_full_dumps = 0;

int g_v88_walk_relogs = 0;

uint64_t g_v89_walk_tick = 0;

uint64_t g_v89_enter_tick = 0;

int g_v89_walk_count = -1;

int g_v89_coord_fixed_logged = 0;

    int used;

    int have;

    uint32_t prev[TNX_V99_FLOATS];

int g_v62_class_pass = 0;

int g_v62_alerts_off = 0;

const char *g_v62_mode_source = "none";

    int ascii;

    int noVt;

    int teamDistinct;

    int posDistinct;

uint64_t g_v224_t0 = 0;

uint64_t g_v224_slow = 0;

uint64_t tnx_slot_repl_0(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(0, a0, a1);

    if (g_slot_orig[0]) return g_slot_orig[0](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_1(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(1, a0, a1);

    if (g_slot_orig[1]) return g_slot_orig[1](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_2(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(2, a0, a1);

    if (g_slot_orig[2]) return g_slot_orig[2](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_3(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(3, a0, a1);

    if (g_slot_orig[3]) return g_slot_orig[3](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_4(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(4, a0, a1);

    if (g_slot_orig[4]) return g_slot_orig[4](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_5(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(5, a0, a1);

    if (g_slot_orig[5]) return g_slot_orig[5](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_6(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(6, a0, a1);

    if (g_slot_orig[6]) return g_slot_orig[6](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_7(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(7, a0, a1);

    if (g_slot_orig[7]) return g_slot_orig[7](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_8(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(8, a0, a1);

    if (g_slot_orig[8]) return g_slot_orig[8](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_9(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(9, a0, a1);

    if (g_slot_orig[9]) return g_slot_orig[9](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_10(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(10, a0, a1);

    if (g_slot_orig[10]) return g_slot_orig[10](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_11(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(11, a0, a1);

    if (g_slot_orig[11]) return g_slot_orig[11](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_12(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(12, a0, a1);

    if (g_slot_orig[12]) return g_slot_orig[12](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_13(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(13, a0, a1);

    if (g_slot_orig[13]) return g_slot_orig[13](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_14(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(14, a0, a1);

    if (g_slot_orig[14]) return g_slot_orig[14](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_15(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(15, a0, a1);

    if (g_slot_orig[15]) return g_slot_orig[15](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_16(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(16, a0, a1);

    if (g_slot_orig[16]) return g_slot_orig[16](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_17(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(17, a0, a1);

    if (g_slot_orig[17]) return g_slot_orig[17](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_18(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(18, a0, a1);

    if (g_slot_orig[18]) return g_slot_orig[18](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_19(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(19, a0, a1);

    if (g_slot_orig[19]) return g_slot_orig[19](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_20(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(20, a0, a1);

    if (g_slot_orig[20]) return g_slot_orig[20](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_21(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(21, a0, a1);

    if (g_slot_orig[21]) return g_slot_orig[21](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_22(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(22, a0, a1);

    if (g_slot_orig[22]) return g_slot_orig[22](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_23(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(23, a0, a1);

    if (g_slot_orig[23]) return g_slot_orig[23](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_24(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(24, a0, a1);

    if (g_slot_orig[24]) return g_slot_orig[24](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_25(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(25, a0, a1);

    if (g_slot_orig[25]) return g_slot_orig[25](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_26(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(26, a0, a1);

    if (g_slot_orig[26]) return g_slot_orig[26](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_27(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(27, a0, a1);

    if (g_slot_orig[27]) return g_slot_orig[27](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_28(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(28, a0, a1);

    if (g_slot_orig[28]) return g_slot_orig[28](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_29(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(29, a0, a1);

    if (g_slot_orig[29]) return g_slot_orig[29](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_30(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(30, a0, a1);

    if (g_slot_orig[30]) return g_slot_orig[30](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_31(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    tnx_slot_note(31, a0, a1);

    if (g_slot_orig[31]) return g_slot_orig[31](a0, a1, a2, a3, a4, a5, a6, a7);

    return 0;
}

uint64_t tnx_slot_repl_32(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;

    g_v237_update_hits++;

    if (g_slot_orig[32]) r = g_slot_orig[32](a0, a1, a2, a3, a4, a5, a6, a7);

    if (TNX_V237_DRIVE_FROM_UPDATE) {
        g_v237_ticks++;
        tnx_run_autododge(1);
    }

    return r;
}

uint64_t tnx_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;

    g_v237_move_hits++;

    if (g_slot_orig[33]) r = g_slot_orig[33](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

const struct {
    const char *tag;
    const char *shortTag;
    uintptr_t rva;
    uintptr_t slotRva;
    tnx_slot_fn_t replacement;
    int control;
} g_slot_specs[TNX_SLOT_COUNT] = {

    { "A1/vt1002548+10/ad4ed0", "A1", 0x00ad4ed0ULL, 0x01002598ULL, tnx_slot_repl_0, 0 },
    { "A2/vt1002548+07/ad521c", "A2", 0x00ad521cULL, 0x01002580ULL, tnx_slot_repl_1, 0 },

    { "B1/off-vt0ff5720-no-data-slot", "B1", 0, 0, tnx_slot_repl_2, 0 },

    { "B2/off-vt0ff5720-no-data-slot", "B2", 0, 0, tnx_slot_repl_3, 0 },
    { "B3/off-vt0ff5720-no-data-slot", "B3", 0, 0, tnx_slot_repl_4, 0 },

    { "C1/Stage::addChild @c33690", "C1", 0x00c33690ULL, 0x01011f50ULL, tnx_slot_repl_5, 1 },
    { "C2/hotflag @b9dc24", "C2", 0x00b9dc24ULL, 0, tnx_slot_repl_6, 1 },

    { "P1/disabled-no-data-slot", "P1", 0, 0, tnx_slot_repl_7, 0 },
    { "D2/disabled-fewer-noisy-slots", "D2", 0, 0, tnx_slot_repl_8, 0 },
    { "P2/disabled-no-data-slot", "P2", 0, 0, tnx_slot_repl_9, 0 },
    { "D4/disabled-fewer-noisy-slots", "D4", 0, 0, tnx_slot_repl_10, 0 },
    { "V6/vt0fe9d00+68/8c7fbc", "V6", 0x008c7fbcULL, 0x00fe9d68ULL, tnx_slot_repl_11, 0 },
    { "D6/table1009290 slot1 @bad4ec", "D6", 0x00000000ULL, 0, tnx_slot_repl_12, 1 },

    { "E1/table100a770 slot0 @bcfbe8", "E1", 0x00bcfbe8ULL, 0, tnx_slot_repl_13, 0 },
    { "E2/table100a770 slot1 @bcfc28", "E2", 0x00bcfc28ULL, 0, tnx_slot_repl_14, 0 },
    { "V1/disabled-fewer-noisy-slots", "V1", 0, 0, tnx_slot_repl_15, 0 },
    { "V2/vt0fe9d00+40/8c6150", "V2", 0x008c6150ULL, 0x00fe9d40ULL, tnx_slot_repl_16, 0 },
    { "E5/setClientPredictionMoveTo @b90b8c", "E5", 0x00b90b8cULL, 0, tnx_slot_repl_17, 1 },
    { "E6/sendMovement @7c13dc", "E6", 0x007c13dcULL, 0, tnx_slot_repl_18, 1 },

    { "D7/table10086c0 slot2 @b8ae88", "D7", 0x00b8ae88ULL, 0, tnx_slot_repl_19, 0 },
    { "D8/table10086c0 slot3 @b8ac7c", "D8", 0x00b8ac7cULL, 0, tnx_slot_repl_20, 0 },
    { "D9/disabled-fewer-noisy-slots", "D9", 0, 0, tnx_slot_repl_21, 0 },
    { "D10/disabled-fewer-noisy-slots", "D10", 0, 0, tnx_slot_repl_22, 0 },
    { "D11/table10086c0 slot8 @b85fe0", "D11", 0x00b85fe0ULL, 0, tnx_slot_repl_23, 0 },
    { "D12/table10086c0 slot9 @b867d8", "D12", 0x00b867d8ULL, 0, tnx_slot_repl_24, 0 },
    { "D13/table10086c0 slot10 @b9e188", "D13", 0x00b9e188ULL, 0, tnx_slot_repl_25, 0 },
    { "D14/table10086c0 slot11 @b9dc8c", "D14", 0x00b9dc8cULL, 0, tnx_slot_repl_26, 0 },

    { "V3/disabled-fewer-noisy-slots", "V3", 0, 0, tnx_slot_repl_27, 0 },
    { "V4/vt0fe9d00+50/8c7f9c", "V4", 0x008c7f9cULL, 0x00fe9d50ULL, tnx_slot_repl_28, 0 },
    { "V5/vt0fe9d00+58/8c7fac", "V5", 0x008c7facULL, 0x00fe9d58ULL, tnx_slot_repl_29, 0 },
    { "D15/table10086c0 slot21 @b898e8", "D15", 0x00b898e8ULL, 0, tnx_slot_repl_30, 0 },
    { "D16/table10086c0 slot23 @b89c10", "D16", 0x00b89c10ULL, 0, tnx_slot_repl_31, 0 },

    { "U1/LogicBattleModeClient::update", "U1", RVA_LOGICBATTLEMODECLIENT_UPDATE, 0,
      tnx_slot_repl_32, 0 },
    { "U2/BattleScreen::updateMovement", "U2", RVA_BATTLESCREEN__UPDATEMOVEMENT, 0,
      tnx_slot_repl_33, 0 },
};

int g_ag_installed = -1;

uint64_t g_ag_hits = 0;

uintptr_t g_ag_manager = 0;

uintptr_t g_ag_objects[TNX_AG_OBJECT_MAX] = { 0 };

int g_ag_objectCount = 0;

BOOL tnx_query_region(uintptr_t address,
                             vm_prot_t *protection,
                             vm_prot_t *maxProtection,
                             mach_vm_size_t *regionSize,
                             uintptr_t *regionStart) {
    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;

    kern_return_t result = vm_region_64(
        mach_task_self(),
        &regionAddress,
        &size,
        VM_REGION_BASIC_INFO_64,
        (vm_region_info_t)&info,
        &infoCount,
        &objectName
    );

    if (objectName != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), objectName);
    }

    if (result != KERN_SUCCESS || size == 0) return NO;
    if ((uintptr_t)regionAddress + (uintptr_t)size <= address) return NO;

    if (protection) *protection = info.protection;
    if (maxProtection) *maxProtection = info.max_protection;
    if (regionSize) *regionSize = (mach_vm_size_t)size;
    if (regionStart) *regionStart = (uintptr_t)regionAddress;

    return YES;
}

BOOL tnx_addr_writable(uintptr_t address, size_t length) {
    if (!address || !length) return NO;

    uintptr_t end = address + length;
    if (end < address) return NO;

    uintptr_t cursor = address;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if (size == 0 || size > 0x10000000ULL) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;

        uintptr_t next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

BOOL tnx_read_bytes(uintptr_t address, void *out, size_t length) {
    if (!out || !length) return NO;
    if (!address) return NO;

    vm_size_t got = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)address,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)out,
        &got
    );

    return result == KERN_SUCCESS && got == (vm_size_t)length;
}

BOOL tnx_pointer_plausible(uintptr_t value) {
    if (value < 0x10000) return NO;
    if (value & 7) return NO;

    return YES;
}

BOOL tnx_read_u8(uintptr_t address, uint8_t *out) {
    return tnx_read_bytes(address, out, 1);
}

BOOL tnx_read_i32(uintptr_t address, int32_t *out) {
    if (!out) return NO;
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

BOOL tnx_read_f32(uintptr_t address, float *out) {
    if (address & 3) return NO;

    return tnx_read_bytes(address, out, 4);
}

uint64_t g_v201_write_denied = 0;

int g_v201_deny_logs = 0;

BOOL tnx_v201_writable(uintptr_t address, size_t length) {
    uintptr_t end = address + length;
    uintptr_t cursor = address;

    if (!address || !length) return NO;
    if (end < address) return NO;

    for (int guard = 0; cursor < end && guard < 64; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) return NO;
        if ((protection & VM_PROT_WRITE) == 0) return NO;
        if (size == 0) return NO;

        next = start + (uintptr_t)size;
        if (next <= cursor) return NO;

        cursor = next;
    }

    return cursor >= end;
}

void tnx_v245_note(uintptr_t address, const void *src, size_t length, int denied) {
    int n = g_v245_at;
    uint32_t value = 0;

    if (n < 0) n = 0;
    if (n >= TNX_V245_JOURNAL) n = 0;

    if (src && length) {
        size_t take = length < sizeof(value) ? length : sizeof(value);

        memcpy(&value, src, take);
    }

    g_v245_addr[n] = address;
    g_v245_value[n] = value;
    g_v245_tick[n] = g_v146_stage_ticks;
    g_v245_phase[n] = g_v146_phase;
    g_v245_size[n] = (uint8_t)(length > 255 ? 255 : length);
    g_v245_denied[n] = (uint8_t)(denied ? 1 : 0);
    g_v245_writes++;
    g_v245_at = (n + 1) % TNX_V245_JOURNAL;
}

BOOL tnx_write_bytes(uintptr_t address, const void *src, size_t length) {
    if (!src || !length) return NO;
    if (!address) return NO;

    if (TNX_V201_WRITE_GUARD && !tnx_v201_writable(address, length)) {
        g_v201_write_denied++;
        tnx_v245_note(address, src, length, 1);

        if (g_v201_deny_logs < TNX_V201_DENY_LOGS) {
            g_v201_deny_logs++;

            tnx_logf("v201 write denied at %p len=%zu total=%llu - the target is not inside a "
                     "writable region of this process, so the store is dropped instead of taking "
                     "the process down with it",
                     (void *)address, length, (unsigned long long)g_v201_write_denied);
        }

        return NO;
    }

    tnx_v245_note(address, src, length, 0);

    memcpy((void *)address, src, length);

    return YES;
}

BOOL tnx_write_f32(uintptr_t address, float value) {
    if (address & 3) return NO;

    return tnx_write_bytes(address, &value, sizeof(value));
}

BOOL tnx_read_ptr(uintptr_t address, void **out) {
    if (!out) return NO;
    if (address & 7) return NO;

    return tnx_read_bytes(address, out, sizeof(void *));
}

void *tnx_read_global_ptr(uintptr_t rva) {
    if (!g_base || !rva) return NULL;

    void *value = NULL;

    if (!tnx_read_ptr(g_base + rva, &value)) return NULL;

    return value;
}

uintptr_t tnx_callable(uintptr_t rva) {
    if (!g_base || !rva) return 0;

    uintptr_t address = g_base + rva;

    if (!tnx_addr_executable(address)) return 0;
    if (!tnx_image_text_contains(g_base, address)) return 0;

    BOOL exact = NO;

    tnx_start_index(address, &exact);

    if (exact) return address;
    if (tnx_looks_like_start(address)) return address;

    return 0;
}

uintptr_t tnx_pick(uintptr_t rvaA, uintptr_t rvaB) {
    uintptr_t a = tnx_callable(rvaA);
    if (a) return a;

    return tnx_callable(rvaB);
}

BOOL tnx_copy(uintptr_t source, void *destination, size_t length) {
    if (!source || !destination || !length) return NO;
    if (!tnx_addr_readable(source, length)) return NO;

    vm_size_t copied = 0;

    kern_return_t result = vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)source,
        (mach_vm_size_t)length,
        (mach_vm_address_t)(uintptr_t)destination,
        &copied
    );

    return result == KERN_SUCCESS && copied == (vm_size_t)length;
}

BOOL tnx_text_section(uintptr_t *address, uint64_t *size) {
    if (!g_base) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, "__TEXT") == 0) {
                uint64_t room = (uint64_t)command->cmdsize - sizeof(struct segment_command_64);
                uint64_t count = room / sizeof(struct section_64);

                if (count > segment->nsects) count = segment->nsects;

                const struct section_64 *sections = (const struct section_64 *)(segment + 1);

                for (uint64_t s = 0; s < count; s++) {
                    if (strcmp(sections[s].sectname, "__text") != 0) continue;
                    if (!sections[s].size) continue;

                    if (address) *address = slide + (uintptr_t)sections[s].addr;
                    if (size) *size = sections[s].size;

                    return YES;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

BOOL tnx_valid_header(uintptr_t base) {
    if (!base) return NO;
    struct mach_header_64 header;

    if (!tnx_pointer_plausible(base)) return NO;
    if (!tnx_read_bytes(base, &header, sizeof(header))) return NO;

    if (header.magic != MH_MAGIC_64) return NO;
    if (header.ncmds == 0 || header.ncmds > 4096) return NO;
    if (header.sizeofcmds == 0) return NO;
    if (header.sizeofcmds > (4u * 1024u * 1024u)) return NO;
    if (!tnx_image_text_contains(base, base + 0x4000)) return NO;

    return YES;
}

BOOL find_game_image(uintptr_t *out_base) {
    if (!out_base) return NO;

    uint32_t count = _dyld_image_count();
    if (count > 8192) count = 8192;

    uintptr_t fallback = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        uintptr_t base = (uintptr_t)_dyld_get_image_header(i);

        if (!path || !base) continue;
        if (!strstr(path, ".app/")) continue;
        if (strstr(path, "/System/")) continue;
        if (strstr(path, "/usr/lib/")) continue;
        if (strstr(path, ".framework/")) continue;
        if (strstr(path, ".dylib")) continue;
        if (tnx_name_marks_host_runtime(path)) continue;
        if (!tnx_valid_header(base)) continue;

        BOOL matched = NO;

        for (int n = 0; g_image_names[n]; n++) {
            if (strstr(path, g_image_names[n])) {
                matched = YES;
                break;
            }
        }

        if (matched) {
            *out_base = base;
            return YES;
        }

        if (!fallback) fallback = base;
    }

    if (fallback) {
        *out_base = fallback;
        return YES;
    }

    return NO;
}

UILabel *g_overlay = NULL;

double g_overlay_last = 0.0;

int g_scan_ticks = 0;

uint64_t g_v219_drain = 0;

uint64_t g_v219_q_max = 0;

uint64_t g_v217_drag_writes = 0;

uint64_t g_v217_drag_back = 0;

int g_alert_shown = 0;

uint64_t g_alert_cleared_ms = 0;

int32_t g_v132_gid_lo = 0;

int32_t g_v132_gid_hi = 0;

uintptr_t g_v132_alert_scene = 0;

uint64_t g_v132_alert_ms = 0;

uintptr_t g_v108_owner = 0;

int g_v109_done = 0;

uintptr_t g_v110_owner = 0;

int g_v110_wired = 0;

    int live;

    int teamCount;

    int distinctGids;

    int deadOk;

    uintptr_t vt0;

dispatch_source_t g_scan_timer = NULL;

BOOL tnx_segment_range(const char *name, uintptr_t *lo, uintptr_t *hi) {
    if (!g_base || !name) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (strcmp(segment->segname, name) == 0) {
                if (lo) *lo = slide + (uintptr_t)segment->vmaddr;
                if (hi) *hi = slide + (uintptr_t)segment->vmaddr + (uintptr_t)segment->vmsize;

                return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

BOOL tnx_image_contains(uintptr_t value) {
    if (!g_base || !value) return NO;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NO;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NO;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NO;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NO;
        if (cursor + command->cmdsize > limit) return NO;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) return YES;
            }
        }

        cursor += command->cmdsize;
    }

    return NO;
}

void tnx_image_span_refresh(void) {
    g_img_span_lo = 0;
    g_img_span_hi = 0;
    g_img_span_ok = 0;

    if (!g_base || !tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) break;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) break;
        if (cursor + command->cmdsize > limit) break;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;
                uintptr_t end = start + (uintptr_t)segment->vmsize;

                if (!g_img_span_lo || start < g_img_span_lo) g_img_span_lo = start;
                if (end > g_img_span_hi) g_img_span_hi = end;
            }
        }

        cursor += command->cmdsize;
    }

    g_img_span_ok = (g_img_span_hi > g_img_span_lo) ? 1 : 0;
}

BOOL tnx_in_image_span(uintptr_t value) {
    if (!value) return NO;
    if (!g_img_span_ok) return tnx_image_contains(value);

    return (value >= g_img_span_lo && value < g_img_span_hi) ? YES : NO;
}

const char *tnx_image_segment_name(uintptr_t value) {
    if (!g_base || !value) return NULL;
    if (!tnx_addr_readable(g_base, sizeof(struct mach_header_64))) return NULL;

    const struct mach_header_64 *header = (const struct mach_header_64 *)g_base;

    if (header->magic != MH_MAGIC_64) return NULL;

    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *limit = cursor + header->sizeofcmds;
    uintptr_t slide = tnx_image_slide(g_base);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cursor + sizeof(struct load_command) > limit) return NULL;

        const struct load_command *command = (const struct load_command *)cursor;

        if (command->cmdsize < sizeof(struct load_command)) return NULL;
        if (cursor + command->cmdsize > limit) return NULL;

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;

            if (segment->vmsize) {
                uintptr_t start = slide + (uintptr_t)segment->vmaddr;

                if (value >= start && value < (start + (uintptr_t)segment->vmsize)) {
                    return segment->segname;
                }
            }
        }

        cursor += command->cmdsize;
    }

    return NULL;
}

    uintptr_t high;

} tnx_region_t;

tnx_region_t g_heap_regions[TNX_HEAP_REGION_MAX];

int g_heap_region_count = 0;

uintptr_t g_heap_window_low = 0;

uintptr_t g_heap_window_high = 0;

int g_heap_window_ok = 0;

void tnx_heap_regions_refresh(void) {
    uintptr_t cursor = 0x10000;
    uintptr_t lowest = 0;
    uintptr_t highest = 0;
    int count = 0;

    for (int guard = 0; guard < 8192 && count < TNX_HEAP_REGION_MAX; guard++) {
        vm_prot_t protection = 0;
        mach_vm_size_t size = 0;
        uintptr_t start = 0;
        uintptr_t next = 0;

        if (!tnx_query_region(cursor, &protection, NULL, &size, &start)) break;
        if (size == 0) break;

        next = start + (uintptr_t)size;
        if (next <= cursor) break;

        if ((protection & VM_PROT_WRITE) &&
            size <= TNX_HEAP_REGION_MAX_SIZE &&
            start >= 0x10000 &&
            !tnx_image_segment_name(start)) {
            g_heap_regions[count].low = start;
            g_heap_regions[count].high = next;
            count++;

            if (!lowest || start < lowest) lowest = start;
            if (next > highest) highest = next;
        }

        cursor = next;
    }

    g_heap_region_count = count;
    g_heap_window_low = lowest;
    g_heap_window_high = highest;
    g_heap_window_ok = count > 0 ? 1 : 0;

    g_heap_region_capped = (count >= TNX_HEAP_REGION_MAX) ? 1 : 0;

    tnx_image_span_refresh();
}

BOOL tnx_heap_window_shaped(uintptr_t value) {
    if (!value) return NO;
    if (!g_heap_window_ok) return YES;
    if (value < g_heap_window_low) return NO;
    if (value >= g_heap_window_high) return NO;

    return YES;
}

BOOL tnx_heap_contains(uintptr_t value) {
    int lo = 0;
    int hi = g_heap_region_count - 1;

    if (!value) return NO;

    if (!g_heap_region_count) return tnx_image_segment_name(value) ? NO : YES;

    if (value < g_heap_window_low || value >= g_heap_window_high) return NO;

    while (lo <= hi) {
        int mid = lo + (hi - lo) / 2;

        if (value < g_heap_regions[mid].low) {
            hi = mid - 1;
        } else if (value >= g_heap_regions[mid].high) {
            lo = mid + 1;
        } else {
            return YES;
        }
    }

    return NO;
}

BOOL tnx_vtable_shaped(uintptr_t value) {
    const char *segment = tnx_image_segment_name(value);

    if (!segment) return NO;
    if (value % 8) return NO;

    if (strcmp(segment, TNX_VTABLE_SEGMENT) == 0) return YES;
    if (strcmp(segment, TNX_VTABLE_SEGMENT_ALT) == 0) return YES;

    return NO;
}

BOOL tnx_heap_resident(uintptr_t value) {
    if (!value) return NO;

    return tnx_image_segment_name(value) ? NO : YES;
}

BOOL tnx_owner_is_heap(uintptr_t owner) {
    if (!owner) return NO;
    if (tnx_in_image_span(owner)) return NO;
    if (!tnx_heap_resident(owner)) return NO;

    return tnx_heap_contains(owner);
}

char tnx_v72_seg_code(uintptr_t value) {
    const char *segment = NULL;

    if (!value) return '.';

    segment = tnx_image_segment_name(value);

    if (segment) {
        if (strcmp(segment, "__TEXT") == 0) return 'T';
        if (strcmp(segment, "__DATA_CONST") == 0) return 'C';
        if (strcmp(segment, "__DATA") == 0) return 'D';

        return 'I';
    }

    if (tnx_heap_contains(value)) return 'H';

    return 'W';
}

BOOL tnx_v72_image_resident(uintptr_t value) {
    char code = tnx_v72_seg_code(value);

    return (code == 'T' || code == 'C' || code == 'D' || code == 'I') ? YES : NO;
}

BOOL tnx_gameobject_shape(uintptr_t object) {
    void *vtable = NULL;
    int32_t team = 0;
    uint8_t dead = 0;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;
    if (!tnx_read_i32(object + TNX_OBJ_TEAM_OFF, &team)) return NO;
    if (team < 0 || team > TNX_OBJ_TEAM_MAX) return NO;
    if (!tnx_read_u8(object + TNX_OBJ_DEADFLAG_OFF, &dead)) return NO;
    if (dead > 1) return NO;

    return YES;
}

BOOL tnx_instance_shaped(uintptr_t object) {
    void *vtable = NULL;

    if (!tnx_pointer_plausible(object)) return NO;
    if (!tnx_heap_resident(object)) return NO;
    if (!tnx_read_ptr(object, &vtable)) return NO;
    if (!vtable) return NO;
    if ((uintptr_t)vtable == object) return NO;
    if (!tnx_vtable_shaped((uintptr_t)vtable)) return NO;

    return YES;
}

BOOL tnx_manager_shape(uintptr_t manager) {
    void *array = NULL;
    void *probe = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (!tnx_heap_resident(manager)) return NO;
    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) return NO;
    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) return NO;
    if (count < 0 || count > TNX_MANAGER_MAX_OBJECTS) return NO;

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) return NO;

    if (array && !tnx_heap_resident((uintptr_t)array)) return NO;

    if (count > 0) {
        if (!array) return NO;
        if (!tnx_read_ptr((uintptr_t)array, &probe)) return NO;
        if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        if (count > 1) {
            if (!tnx_read_ptr((uintptr_t)array + (uintptr_t)(count - 1) * sizeof(void *), &probe)) return NO;
            if (!tnx_heap_resident((uintptr_t)probe)) return NO;
        }
    }

    return YES;
}

const uintptr_t g_mode_vtables[] = {
    0x10012c8, 0x1001318, 0x1001368, 0x10013b8,
    0x1001408, 0x1001458, 0x10014a8, 0x10014f8, 0x1001548, 0x1001598, 0x10015e8, 0x10016e0,
    0x10017d8, 0x10018c0, 0x1001908, 0x10019d0, 0x1001ac8, 0x1001bc0, 0x1001cb8, 0x1001d80,
    0x1001e48, 0x1001f10, 0x10022f0, 0x10023b8, 0x1002480, 0x1002548, 0x1002610,
    0x10026d8, 0x10027a0, 0x1002868, 0x1002930, 0x10029f8, 0x1002ac0, 0x1002b88, 0x1002d18,
    0,
};

uintptr_t tnx_vtable_rva(void *object) {
    void *vtable = NULL;

    if (!object) return 0;
    if (!tnx_read_ptr((uintptr_t)object, &vtable)) return 0;
    if (!vtable) return 0;
    if ((uintptr_t)vtable < g_base) return 0;

    return (uintptr_t)vtable - g_base;
}

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

} tnx_trail_t;

tnx_trail_t g_trail[TNX_TRAIL_MAX];

int g_trail_count = 0;

uint64_t g_trail_total = 0;

    int32_t count;

    int pass;

} tnx_seen_t;

tnx_seen_t g_seen[TNX_SEEN_MAX];

void tnx_trail_note(uintptr_t manager, int32_t count, int32_t capacity, int live,
                           int nonEmpty, int ascii, int sampled, int noVt, int teamDistinct,
                           int posDistinct, int refused) {
    int slot = -1;
    int stable = tnx_candidate_is_stable(manager, count) ? 1 : 0;
    void *raw = NULL;
    char rawSeg = '.';
    int rawOk = 1;

    tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &raw);

    rawSeg = tnx_v72_seg_code((uintptr_t)raw);
    rawOk = tnx_v72_image_resident((uintptr_t)raw) ? 0 : 1;

    g_trail_total++;

    if (live > g_manager_best_live) g_manager_best_live = live;

    for (int i = 0; i < g_trail_count; i++) {
        if (g_trail[i].manager == manager) {
            g_trail[i].count = count;
            g_trail[i].capacity = capacity;
            g_trail[i].live = live;
            g_trail[i].nonEmpty = nonEmpty;
            g_trail[i].stable = stable;
            g_trail[i].rawOk = rawOk;
            g_trail[i].rawSeg = rawSeg;
            g_trail[i].ascii = ascii;
            g_trail[i].sampled = sampled;
            g_trail[i].noVt = noVt;
            g_trail[i].teamDistinct = teamDistinct;
            g_trail[i].posDistinct = posDistinct;
            g_trail[i].refused = refused;
            slot = i;

            goto ranked;
        }
    }

    if (g_trail_count < TNX_TRAIL_MAX) {
        slot = g_trail_count++;
    } else {
        int worst = -1;

        for (int i = 0; i < TNX_TRAIL_MAX; i++) {
            if (!tnx_trail_qualifies(i)) {
                worst = i;

                break;
            }
        }

        if (worst < 0) {
            if (!rawOk || refused) return;

            worst = 0;

            for (int i = 1; i < TNX_TRAIL_MAX; i++) {
                if (tnx_trail_beats_slot(g_trail[worst].live, g_trail[worst].nonEmpty,
                                         g_trail[worst].count, i)) {
                    worst = i;
                }
            }

            if (!tnx_trail_beats_slot(live, nonEmpty, count, worst)) return;
        }

        slot = worst;
    }

    g_trail[slot].manager = manager;
    g_trail[slot].count = count;
    g_trail[slot].capacity = capacity;
    g_trail[slot].live = live;
    g_trail[slot].nonEmpty = nonEmpty;
    g_trail[slot].stable = stable;
    g_trail[slot].rawOk = rawOk;
    g_trail[slot].rawSeg = rawSeg;
    g_trail[slot].ascii = ascii;
    g_trail[slot].sampled = sampled;
    g_trail[slot].noVt = noVt;
    g_trail[slot].teamDistinct = teamDistinct;
    g_trail[slot].posDistinct = posDistinct;
    g_trail[slot].refused = refused;

    if (!rawOk && g_v72_trail_refusals < 6) {
        g_v72_trail_refusals++;

        tnx_logf("v100 trail: image-resident container refused raw=%c mgr=%p count=%d live=%d - "
                 "raw[0] sits in the image, so this is a text table and never a battle container",
                 rawSeg, (void *)manager, count, live);
    }

ranked:
    tnx_trail_rebest();
}

    const char *value;

    const char *provenance;

} tnx_fact_t;

    int32_t   gid;

    int32_t   x;

    int32_t   y;

    int32_t   ownerIndex;

    int32_t   teamOld;

    int32_t   teamNew;

    int32_t   typeWord;

    uint8_t   dead;

    uint8_t   activeFlag;

int g_v176_gate_last = -1;

int g_v176_gate_logs = 0;

int g_dodge_probe_usable = 0;

    int rejNull;

    int rejUnreadable;

    int rejAscii;

    int rejNoVt;

    int rejGidZero;

    int rejNonPlayer;

    int rejOutOfRange;

    int rejTeamMissing;

    int deadSeen;

int g_v170_step_logs = 0;

int g_v170_elem_logs = 0;

uintptr_t g_v170_last_own = 0;

int g_v151_logs = 0;

int32_t g_v152_last_tx = 0;

int32_t g_v152_last_ty = 0;

int g_v152_issued = 0;

int tnx_write_i32(uintptr_t address, int32_t value) {
    if (address & 3) return 0;

    return tnx_write_bytes(address, &value, sizeof(value)) ? 1 : 0;
}

uintptr_t g_v182_own_elem = 0;

uintptr_t g_v185_enemy_elem = 0;

uint64_t g_v156_push_logs = 0;

uint64_t g_v120_reloads = 0;

uint64_t g_v122_pre_reloads = 0;

uint64_t g_v122_pre_frames = 0;

uint64_t g_v121_push_frame = 0;

uint64_t g_v121_win_reloads = 0;

int g_v121_win_stage = 0;

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

float g_v165_dir_x = 0.0f;

float g_v165_dir_y = 0.0f;

    float ay;

    float bx;

    float by;

    float speed;

    float dirX;

    float dirY;

    float inflatedR;

    float remaining;

    int32_t gid;

int g_v244_human = 0;

int g_v244_touch = 0;

int g_v244_moved = 0;

uint64_t g_v244_stops = 0;

uint64_t g_v244_queue_skips = 0;

int g_v244_logs = 0;

float g_v244_org_x = 0.0f;

float g_v244_org_y = 0.0f;

float g_v244_cur_x = 0.0f;

float g_v244_cur_y = 0.0f;

int32_t g_v180_tx = 0;

int32_t g_v180_ty = 0;

uint64_t g_v180_hold = 0;

    int have;

    uint32_t prev[TNX_V173_WORDS];

    uint16_t hot[TNX_V173_WORDS];

BOOL tnx_v56_vtable_in_image(uintptr_t vtable) {
    uintptr_t lo = 0;
    uintptr_t hi = 0;

    if (!vtable) return NO;
    if (vtable >= g_base + TNX_DC_RVA_LO && vtable < g_base + TNX_DC_RVA_LO + TNX_DC_RVA_SIZE) {
        return YES;
    }

    if (tnx_segment_range(TNX_VTABLE_SEGMENT_ALT, &lo, &hi) && vtable >= lo && vtable < hi) {
        return YES;
    }

    return NO;
}

int tnx_v59_container_at(uintptr_t object, int32_t *countOut, int32_t *capOut, char *why,
                                size_t whyLen) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;

    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (why && whyLen) why[0] = 0;

    if (!object) {
        if (why) snprintf(why, whyLen, "object-null");

        return 0;
    }

    if (!tnx_read_ptr(object + TNX_MGR_ARRAY_OFF, &array) || !array) {
        if (why) snprintf(why, whyLen, "array-null-or-unreadable");

        return 0;
    }

    if (!tnx_read_i32(object + TNX_MGR_COUNT_OFF, &count)) {
        if (why) snprintf(why, whyLen, "count-unreadable");

        return 0;
    }

    if (count <= 0 || count > TNX_MANAGER_MAX_OBJECTS) {
        if (why) snprintf(why, whyLen, "count=%d-out-of-range", count);

        return 0;
    }

    if (!tnx_read_i32(object + TNX_MGR_CAP_OFF, &capacity)) {
        if (why) snprintf(why, whyLen, "cap-unreadable");

        return 0;
    }

    if (capacity < count || capacity > TNX_MGR_CAP_MAX) {
        if (why) snprintf(why, whyLen, "cap=%d-against-count=%d", capacity, count);

        return 0;
    }

    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return 1;
}

int tnx_v60_container_resolve(uintptr_t manager, uintptr_t *containerOut, int32_t *countOut,
                                     int32_t *capOut, char *why, size_t whyLen) {
    void *array = NULL;
    int32_t count = 0;
    int32_t capacity = 0;
    uintptr_t arrayBase = 0;

    if (containerOut) *containerOut = 0;
    if (countOut) *countOut = 0;
    if (capOut) *capOut = 0;
    if (why && whyLen) why[0] = 0;

    if (!manager) {
        if (why) snprintf(why, whyLen, "manager-null");

        return 0;
    }

    if (!tnx_read_ptr(manager + TNX_MGR_ARRAY_OFF, &array) || !array) {
        if (why) snprintf(why, whyLen, "array-null-src=A+B");

        return 0;
    }

    arrayBase = (uintptr_t)array;

    if (!tnx_read_i32(manager + TNX_MGR_COUNT_OFF, &count)) {
        if (why) snprintf(why, whyLen, "count-unreadable-src=B");

        return 0;
    }

    if (count > TNX_MANAGER_MAX_OBJECTS) {
        if (why) {
            snprintf(why, whyLen, "count=%d-above-%d-src=B", count, TNX_MANAGER_MAX_OBJECTS);
        }

        return 0;
    }

    g_v67_layout_used = 0xc;

    if (count < 2) {
        int32_t alt = 0;
        int32_t at8 = 0;
        int32_t at10 = 0;

        tnx_read_i32(manager + 0x8ULL, &at8);
        tnx_read_i32(manager + 0x10ULL, &at10);

        if (at8 >= 2 && at8 <= TNX_MANAGER_MAX_OBJECTS) {
            alt = at8;
            g_v67_layout_used = 0x8;
        } else if (at10 >= 2 && at10 <= TNX_MANAGER_MAX_OBJECTS) {
            alt = at10;
            g_v67_layout_used = 0x10;
        }

        if (alt >= 2) {
            count = alt;
            capacity = alt;

            if (g_v67_layout_logs < 8) {
                g_v67_layout_logs++;

                tnx_logf("v100 container alt layout count=%d at +0x%x (the primary +0xc read %d) "
                         "mgr=%p array=%p src=B", count, g_v67_layout_used, at8 == count ? at8 : 0,
                         (void *)manager, (void *)arrayBase);
            }

            if (containerOut) *containerOut = manager;
            if (countOut) *countOut = count;
            if (capOut) *capOut = capacity;

            return 1;
        }

        if (arrayBase >= g_base && arrayBase < g_base + TNX_V60_IMAGE_SPAN) {
            g_v63_image_count++;

            if (!g_v63_image_first) {
                g_v63_image_first = 1;

                tnx_logf("v100 container image-resident count=%d reject-as-static-array mgr=%p "
                         "array=%p src=B", count, (void *)manager, (void *)arrayBase);
            }

            g_v63_image_top_mgr = (uintptr_t)manager;
            g_v63_image_top_count = count;
        }

        if (why) {
            snprintf(why, whyLen, "count=%d-tried+0x8=%d,+0x10=%d-src=B", count, at8, at10);
        }

        return 0;
    }

    if (!tnx_read_i32(manager + TNX_MGR_CAP_OFF, &capacity)) {
        if (why) snprintf(why, whyLen, "cap-unreadable-src=B");

        return 0;
    }

    if (capacity < count) {
        if (why) snprintf(why, whyLen, "cap=%d-against-count=%d-src=B", capacity, count);

        return 0;
    }

    if (containerOut) *containerOut = manager;
    if (countOut) *countOut = count;
    if (capOut) *capOut = capacity;

    return 1;
}

uintptr_t tnx_v60_strip_ptr(uintptr_t value) {
    uintptr_t stripped = value;

#if __has_feature(ptrauth_calls)
    stripped = (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_function_pointer);
#endif

    if (stripped >= g_base && stripped < g_base + TNX_V60_IMAGE_SPAN) return stripped;

    if ((stripped & 0xffffffffULL) < TNX_V60_IMAGE_SPAN) {
        uintptr_t viaLow = g_base + (stripped & 0xffffffffULL);

        if (viaLow >= g_base && viaLow < g_base + TNX_V60_IMAGE_SPAN) return viaLow;
    }

    return stripped;
}

void poll_for_game(int tick) {
    if (g_setup_done) return;
    if (tick > 1200) return;

    uintptr_t base = 0;

    if (find_game_image(&base)) {
        g_base = base;
        setup();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        poll_for_game(tick + 1);
    });
}
