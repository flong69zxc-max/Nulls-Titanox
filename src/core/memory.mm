#include "titanox.h"

const char *g_image_names[4] = {
    "Nulls Brawl",
    "Laser",
    "NB.app",
    NULL
};

const tnx_rva_entry_t g_rvas[32] = {
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

uint64_t g_dodge_calls = 0;

uint64_t g_render_calls = 0;

int g_dump_np = 0;

uintptr_t g_prev_scene = 0;

const uintptr_t g_mode_vtables_verified[3] = { 0x1002548, 0xff5720, 0 };

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

tnx_objhit_t g_objhits[TNX_OBJ_HIT_DUMP_MAX];

int g_objhit_count = 0;

unsigned long long g_objvote_owner_reg = 0;

unsigned long long g_objvote_owner_above_win = 0;

int g_objvote_max_votes = 0;

unsigned long long g_objvote_shaped = 0;

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

uintptr_t g_addr[TNX_JOURNAL];

uint32_t g_value[TNX_JOURNAL];

uint64_t g_tick_3[TNX_JOURNAL];

const char *g_phase_2[TNX_JOURNAL];

uint8_t g_size[TNX_JOURNAL];

uint8_t g_denied[TNX_JOURNAL];

volatile int g_at = 0;

volatile uint64_t g_writes_2 = 0;

uint64_t g_stale = 0;

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

int g_chain_rej[20] = { 0 };

int g_chain_probes_pass = 0;

int g_layout_logs = 0;

int g_no_source_passes = 0;

int g_route_logged = 0;

uint32_t g_slot_reported_mask = 0;

uint64_t g_slot_first_tick[TNX_SLOT_COUNT] = { 0 };

uintptr_t g_slot_adopted = 0;

int g_ag_adopted = 0;

int g_chain_hits = 0;

int g_mode_from_chain = 0;

int g_idle_probe_logged = 0;

uintptr_t g_last_cand = 0;

uintptr_t g_last_vt = 0;

char g_last_why[96] = { 0 };

int g_sig_ticks = 0;

int g_sig_logs = 0;

uintptr_t g_sig_last = 0;

int g_trail_refusals = 0;

uintptr_t g_players_array = 0;

int g_players_count = 0;

int g_players_cap = 0;

int g_field_scans = 0;

int g_elem_full_dumps = 0;

int g_walk_relogs = 0;

uint64_t g_walk_tick = 0;

uint64_t g_enter_tick = 0;

int g_walk_count = -1;

int g_coord_fixed_logged = 0;

int g_class_pass = 0;

int g_alerts_off = 0;

const char *g_mode_source_2 = "none";

uint64_t g_t0 = 0;

uint64_t g_slow = 0;

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

    g_update_hits++;

    if (g_slot_orig[32]) r = g_slot_orig[32](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

uint64_t tnx_slot_repl_33(void *a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    uint64_t r = 0;

    g_move_hits++;

    if (g_slot_orig[33]) r = g_slot_orig[33](a0, a1, a2, a3, a4, a5, a6, a7);

    return r;
}

const struct tnx_t_g_slot_specs g_slot_specs[TNX_SLOT_COUNT] = {

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

uint64_t g_write_denied = 0;

int g_deny_logs = 0;

BOOL tnx_writable(uintptr_t address, size_t length) {
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

void tnx_note(uintptr_t address, const void *src, size_t length, int denied) {
    int n = g_at;
    uint32_t value = 0;

    if (n < 0) n = 0;
    if (n >= TNX_JOURNAL) n = 0;

    if (src && length) {
        size_t take = length < sizeof(value) ? length : sizeof(value);

        memcpy(&value, src, take);
    }

    g_addr[n] = address;
    g_value[n] = value;
    g_tick_3[n] = g_stage_ticks;
    g_phase_2[n] = g_phase;
    g_size[n] = (uint8_t)(length > 255 ? 255 : length);
    g_denied[n] = (uint8_t)(denied ? 1 : 0);
    g_writes_2++;
    g_at = (n + 1) % TNX_JOURNAL;
}

BOOL tnx_write_bytes(uintptr_t address, const void *src, size_t length) {
    if (!src || !length) return NO;
    if (!address) return NO;

    if (TNX_WRITE_GUARD && !tnx_writable(address, length)) {
        g_write_denied++;
        tnx_note(address, src, length, 1);

        if (g_deny_logs < TNX_DENY_LOGS) {
            g_deny_logs++;

            tnx_logf("write denied at %p len=%zu total=%llu - the target is not inside a "
                     "writable region of this process, so the store is dropped instead of taking "
                     "the process down with it",
                     (void *)address, length, (unsigned long long)g_write_denied);
        }

        return NO;
    }

    tnx_note(address, src, length, 0);

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

uint64_t g_drain = 0;

uint64_t g_q_max = 0;

uint64_t g_drag_writes = 0;

uint64_t g_drag_back = 0;

int g_alert_shown = 0;

uint64_t g_alert_cleared_ms = 0;

int32_t g_gid_lo = 0;

int32_t g_gid_hi = 0;

uintptr_t g_alert_scene = 0;

uint64_t g_alert_ms = 0;

uintptr_t g_owner = 0;

int g_done = 0;

uintptr_t g_owner_2 = 0;

int g_wired = 0;

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

const uintptr_t g_mode_vtables[36] = {
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

tnx_trail_t g_trail[TNX_TRAIL_MAX];

int g_trail_count = 0;

uint64_t g_trail_total = 0;

int g_gate_last = -1;

int g_gate_logs = 0;

int g_dodge_probe_usable = 0;

int g_step_logs = 0;

int g_elem_logs = 0;

uintptr_t g_last_own = 0;

int g_logs = 0;

int32_t g_last_tx = 0;

int32_t g_last_ty = 0;

int g_issued = 0;

int tnx_write_i32(uintptr_t address, int32_t value) {
    if (address & 3) return 0;

    return tnx_write_bytes(address, &value, sizeof(value)) ? 1 : 0;
}

uintptr_t g_own_elem_2 = 0;

uintptr_t g_enemy_elem = 0;

uint64_t g_push_logs = 0;

uint64_t g_reloads = 0;

uint64_t g_pre_reloads = 0;

uint64_t g_pre_frames = 0;

uint64_t g_push_frame_2 = 0;

uint64_t g_win_reloads = 0;

int g_win_stage = 0;

float g_dir_x = 0.0f;

float g_dir_y = 0.0f;

int g_human_2 = 0;

int g_touch = 0;

int g_moved_3 = 0;

uint64_t g_stops = 0;

uint64_t g_queue_skips_2 = 0;

int g_logs_11 = 0;

float g_org_x = 0.0f;

float g_org_y = 0.0f;

float g_cur_x = 0.0f;

float g_cur_y = 0.0f;

int32_t g_tx_3 = 0;

int32_t g_ty_3 = 0;

uint64_t g_hold = 0;

BOOL tnx_vtable_in_image(uintptr_t vtable) {
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

uintptr_t tnx_strip_ptr(uintptr_t value) {
    uintptr_t stripped = value;

#if __has_feature(ptrauth_calls)
    stripped = (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_function_pointer);
#endif

    if (stripped >= g_base && stripped < g_base + TNX_IMAGE_SPAN) return stripped;

    if ((stripped & 0xffffffffULL) < TNX_IMAGE_SPAN) {
        uintptr_t viaLow = g_base + (stripped & 0xffffffffULL);

        if (viaLow >= g_base && viaLow < g_base + TNX_IMAGE_SPAN) return viaLow;
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
