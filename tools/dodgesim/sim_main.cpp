#include "build/src/recoil.h"
#include "build/src/features/autododge.mm"

#include <vector>

static void reset_dodge_state(void)
{
    rcl_bdc_have_last = 0;
    rcl_bdc_last_x = 0.0f;
    rcl_bdc_last_y = 0.0f;
    rcl_ad_mine_skipped = 0;
}

static int g_dodgeCalls = 0;
static int g_moveTicks = 0;
static int g_walked = 0;
static int g_phaseOneTicks = 0;

static void sim_advance(double dtMs)
{
    float before_x = g_sim.myX;
    float before_y = g_sim.myY;
    int moves = g_sim.moveCalls;
    float tx = g_sim.lastTx;
    float ty = g_sim.lastTy;
    sim_tick(dtMs);
    if (moves > 0)
    {
        float dx = tx - g_sim.myX;
        float dy = ty - g_sim.myY;
        float len = sqrtf(dx * dx + dy * dy);
        float stepLen = (float)SIM_CHAR_SPEED * (float)dtMs / 1000.0f;
        g_moveTicks++;
        if (len > 1.0f)
        {
            float k = stepLen / len;
            if (k > 1.0f)
            {
                k = 1.0f;
            }
            g_sim.myX += dx * k;
            g_sim.myY += dy * k;
        }
        g_walked += (int)(sqrtf((g_sim.myX - before_x) * (g_sim.myX - before_x) +
                                (g_sim.myY - before_y) * (g_sim.myY - before_y)));
    }
    else
    {
        g_sim.myX = before_x;
        g_sim.myY = before_y;
    }
}

static int sim_dodge_step(double dtMs)
{
    int r = rcl_ad_update_7(g_sim.myX, g_sim.myY);
    if (r)
    {
        g_dodgeCalls++;
    }
    sim_advance(dtMs);
    return r;
}

static void print_row(const char *name, int ticks, double seconds)
{
    printf("%-34s ticks=%4d  %5.2fs  dodge=%4d  move=%4d  walked=%5dpx  pos=(%.0f,%.0f)  threats=%d hazards=%d aimed=%d mineSkipped=%d\n",
           name, ticks, seconds, g_dodgeCalls, g_moveTicks, g_walked, g_sim.myX, g_sim.myY, rcl_bd_threat_n,
           rcl_ad_hazard_n, rcl_bdc_sel_n, rcl_ad_mine_skipped);
}

static void test_enemy_shot(void)
{
    int i;
    rcl_ad_mine_skipped = 0;
    g_dodgeCalls = 0;
    g_moveTicks = 0;
    g_walked = 0;
    sim_reset();
    reset_dodge_state();
    sim_set_own(4000, 4000);
    sim_set_teams(1, 1);
    sim_add_proj("ArcadeProjectile", 0, 4600, 4000, -2000.0f, 0.0f, 90.0f);
    for (i = 0; i < 60; i++)
    {
        sim_dodge_step(16.0);
    }
    print_row("enemy shot at me", 60, 0.96);
}

static void test_mate_shot(void)
{
    int i;
    rcl_ad_mine_skipped = 0;
    g_dodgeCalls = 0;
    g_moveTicks = 0;
    g_walked = 0;
    sim_reset();
    reset_dodge_state();
    sim_set_own(4000, 4000);
    sim_set_teams(1, 0);
    sim_add_mate(3900, 4000);
    sim_add_proj("ArcadeProjectile", 1, 3800, 4000, 2000.0f, 0.0f, 90.0f);
    for (i = 0; i < 40; i++)
    {
        sim_dodge_step(16.0);
    }
    print_row("mate shot, team=-1 at mate", 40, 0.64);
}

static void test_mate_shot_known_team(void)
{
    int i;
    rcl_ad_mine_skipped = 0;
    g_dodgeCalls = 0;
    g_moveTicks = 0;
    g_walked = 0;
    sim_reset();
    reset_dodge_state();
    sim_set_own(4000, 4000);
    sim_set_teams(1, 1);
    sim_add_mate(3800, 4000);
    sim_add_proj("ArcadeProjectile", 1, 3800, 4000, 2000.0f, 0.0f, 90.0f);
    for (i = 0; i < 40; i++)
    {
        sim_dodge_step(16.0);
    }
    print_row("mate shot, team readable", 40, 0.64);
}

static void test_own_shot_unknown_team(void)
{
    int i;
    rcl_ad_mine_skipped = 0;
    g_dodgeCalls = 0;
    g_moveTicks = 0;
    g_walked = 0;
    sim_reset();
    reset_dodge_state();
    sim_set_own(4000, 4000);
    sim_set_teams(1, 0);
    sim_add_proj("ArcadeProjectile", -1, 4000, 4000, -2200.0f, 0.0f, 90.0f);
    for (i = 0; i < 30; i++)
    {
        sim_dodge_step(16.0);
    }
    print_row("my own shot, team=-1", 30, 0.48);
}

static void test_corner_after_threat(void)
{
    int i;
    int phaseOneMoves = 0;
    int phaseTwoMoves = 0;
    g_dodgeCalls = 0;
    g_moveTicks = 0;
    g_walked = 0;
    sim_reset();
    reset_dodge_state();
    sim_set_own(11500, 11500);
    sim_set_teams(1, 1);
    sim_add_proj("ArcadeProjectile", 0, 10500, 11500, 1500.0f, 0.0f, 90.0f);
    for (i = 0; i < 40; i++)
    {
        int r = rcl_ad_update_7(g_sim.myX, g_sim.myY);
        if (i == 0)
        {
            rcl_hazard_t caps[16];
            int sc = rcl_shape_hazards(&rcl_projs[0], (uint64_t)g_sim.nowMs, caps, 16);
            printf("   dbg proj0 elem=%d x=%d y=%d vx=%.0f team=%d name=%s r=%.0f kind=%s shaped=%d\n",
                   rcl_projs[0].elem ? 1 : 0, rcl_projs[0].x, rcl_projs[0].y, rcl_projs[0].vx, rcl_projs[0].team,
                   rcl_projs[0].name ? rcl_projs[0].name : "null", rcl_projs[0].radius,
                   rcl_kind_of("ArcadeProjectile") ? "yes" : "no", sc);
        }
        if (i < 6 || r)
        {
            printf("   t%02d dodge=%d threats=%d hazards=%d aimed=%d pos=(%.0f,%.0f)", i, r, rcl_bd_threat_n,
                   rcl_ad_hazard_n, rcl_bdc_sel_n, g_sim.myX, g_sim.myY);
            printf("\n");
        }
        if (r)
        {
            phaseOneMoves++;
        }
        sim_advance(16.0);
    }
    g_sim.moveCalls = 0;
    g_moveTicks = 0;
    g_walked = 0;
    sim_clear_projs();
    for (i = 0; i < 300; i++)
    {
        if (sim_dodge_step(16.0))
        {
            phaseTwoMoves++;
        }
    }
    printf("%-34s phase1_dodge=%3d  phase2(no threat) dodge=%3d move=%4d walked=%5dpx  final=(%.0f,%.0f)\n",
           "corner: stale direction", phaseOneMoves, phaseTwoMoves, g_moveTicks, g_walked, g_sim.myX, g_sim.myY);
}

int main(void)
{
    printf("brawler kind lookup AmbusherProjectile: %s\n", rcl_kind_of("ArcadeProjectile") ? "ok" : "MISS");
    test_enemy_shot();
    test_mate_shot();
    test_mate_shot_known_team();
    test_own_shot_unknown_team();
    test_corner_after_threat();
    return 0;
}
