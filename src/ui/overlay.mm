#include "titanox.h"

void tnx_overlay_attach(NSString *text) {
    UIWindow *window = nil;

    for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
        if (candidate.isKeyWindow) {
            window = candidate;
            break;
        }
    }

    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;

    if (g_overlay && g_overlay.superview != window) {
        [g_overlay removeFromSuperview];
        g_overlay = nil;
    }

    if (!g_overlay) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 44.0, 520.0, 36.0)];

        label.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightBold];
        label.textColor = [UIColor colorWithRed:1.0 green:0.32 blue:0.32 alpha:1.0];
        label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
        label.userInteractionEnabled = NO;
        label.numberOfLines = 2;

        g_overlay = label;
    }

    g_overlay.text = text;

    if (!g_overlay.superview) [window addSubview:g_overlay];

    [g_overlay.superview bringSubviewToFront:g_overlay];
}

void tnx_overlay_update(void) {
    char text[192];
    double now = CFAbsoluteTimeGetCurrent();

    if (g_overlay) {
        UILabel *stale = g_overlay;

        g_overlay = NULL;

        dispatch_async(dispatch_get_main_queue(), ^{
            [stale removeFromSuperview];
        });
    }

    return;

    if (now - g_overlay_last < 0.4) return;

    g_overlay_last = now;

    uint64_t slotHits = 0;
    uint64_t slotControl = 0;
    int slotInstalled = 0;

    for (int i = 0; i < TNX_SLOT_COUNT; i++) {
        if (g_slot_specs[i].control) slotControl += g_slot_hits[i];
        else slotHits += g_slot_hits[i];

        if (g_slot_installed[i] == 1) slotInstalled++;
    }

    snprintf(text, sizeof(text), "%sTNX %s t=%d a=%d/%d hp=%d\nmx=%d ty=%d sl=%llu/%d ctl=%llu obj=%d",
             g_slot_adopted ? "*** BATTLE FOUND ***\n" : "", TNX_BUILD_TAG,
             g_scan_ticks, g_votescan_attempts, TNX_VOTESCAN_ATTEMPTS, g_heap_passes,
             g_mode_best_objects, g_mode_last_types, (unsigned long long)slotHits,
             slotInstalled, (unsigned long long)slotControl, g_scene_object ? 1 : 0);

    NSString *string = [NSString stringWithUTF8String:text];

    dispatch_async(dispatch_get_main_queue(), ^{
        tnx_overlay_attach(string);
    });
}

void tnx_alert_battle_check(void) {
    uintptr_t candidate = 0;
    tnx_facts_t facts;
    uint64_t now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);
    int armed = 0;
    int withheld = 0;
    int counted = 0;
    const char *why = "no candidate";

    memset(&facts, 0, sizeof(facts));

    g_alert_calls++;

    if (g_scene_object) candidate = g_scene_object;
    else if (g_players_object) candidate = g_players_object;

    if (!candidate) {
        why = "mode=0 and manager=0 (the scanner's hit is not a container)";
    } else {

        if (facts.live < 2) {
            why = "live<2";
        } else if (facts.teamCount < 2) {
            why = "teamCount<2";
        } else {

            if (g_alert_streak_ptr == candidate) g_alert_streak++;
            else {
                g_alert_streak_ptr = candidate;
                g_alert_streak = 1;
            }

            counted = 1;

            if (g_alert_streak < TNX_ALERT_SIGHTINGS) {
                why = "sightings<3";
            } else {
                armed = 1;
            }
        }
    }

    if (!counted) {
        g_alert_streak = 0;
        g_alert_streak_ptr = 0;
    }

    if (!armed) withheld = 1;

    if (withheld) {

        if (g_alert_shown) {
            if (g_alert_cleared_ms == 0) g_alert_cleared_ms = now;
            else if (now > g_alert_cleared_ms + 5000) {
                g_alert_shown = 0;
                g_alert_cleared_ms = 0;
            }
        }

        return;
    }

    g_alert_cleared_ms = 0;

    if (!g_alert_shown && now > 3000) {
        g_alert_shown = 1;

        tnx_logf("battle entry: live=%d teamCount=%d distinctGids=%d deadOk=%d vt0=%#llx "
                 "sightings=%d bestLive=%d bestCount=%d mode=%p manager=%p candidate=%p -- showing "
                 "alert",
                 facts.live, facts.teamCount, facts.distinctGids, facts.deadOk,
                 (unsigned long long)facts.vt0, g_alert_streak, g_manager_best_live,
                 g_manager_best_count, (void *)g_scene_object, (void *)g_players_object,
                 (void *)candidate);

        tnx_battle_alert(g_scene_object, 0);
    }
}

void tnx_render_watermark(void) {
    if (!g_base || g_wm_failed) return;

    if (!g_wm_ready) {
        if (!g_addr_getclip || !g_addr_gettf || !g_addr_settext || !g_addr_setxy || !g_addr_addchild) {
            g_wm_failed = YES;
            tlog(@"watermark disabled: unresolved address");
            return;
        }

        void *stage = tnx_read_global_ptr(OFF_STAGEINSTANCEGLOBALPTR);
        if (!tnx_object_plausible(stage)) return;

        void *scFile = tnx_sc_string(TNX_CLIP_FILE);
        void *scName = tnx_sc_string(TNX_CLIP_NAME);
        void *scText = tnx_sc_string(TNX_CLIP_TEXT);

        if (!scFile || !scName || !scText) return;

        void *clip = ((fn_ptr_2_t)g_addr_getclip)(scFile, scName);
        if (!tnx_object_plausible(clip)) return;

        void *tf = ((fn_ptr_2_t)g_addr_gettf)(clip, scText);
        if (!tnx_object_plausible(tf)) return;

        ((fn_setxy_t)g_addr_setxy)(clip, 60536.0f, 60536.0f);
        ((fn_void_2_t)g_addr_addchild)(stage, clip);

        g_label_clip = clip;
        g_label_tf = tf;
        g_wm_ready = YES;

        tlog([NSString stringWithFormat:@"watermark ready stage=%p clip=%p tf=%p", stage, clip, tf]);
    }

    if (!g_label_clip || !g_label_tf) return;

    {
        char want[64];
        int n = snprintf(want, sizeof(want), "%s [%s]", TNX_BUILD_TAG, tnx_state_name());

        if (n > 0 && (size_t)n < sizeof(want) && strcmp(g_label_text, want) != 0) {
            void *sc = tnx_sc_string(want);

            if (sc) {
                g_label_sc = sc;
                snprintf(g_label_text, sizeof(g_label_text), "%s", want);
                g_label_builds++;
            }
        }
    }

    if (!g_label_sc) return;

    ((fn_settext_t)g_addr_settext)(g_label_tf, g_label_sc, 4, 0);
    g_label_updates++;
}

int g_alerts_off = 0;

UILabel *g_overlay = NULL;

void tnx_alert_menu(NSString *info) {
    NSString *text = [info copy];

    if (g_alerts_off) return;

    TNX_LOGX("scene-mode alert shown - the latch that made the alert a once-per-process event "
             "is gone, the edge on the scene pointer is what limits it now");

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        UIViewController *host = nil;

        for (UIWindow *candidate in [UIApplication sharedApplication].windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }

        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;

        host = window.rootViewController;
        if (!host) return;

        while (host.presentedViewController) host = host.presentedViewController;

        UIAlertController *menu =
            [UIAlertController alertControllerWithTitle:@"Titanox"
                                                message:text
                                         preferredStyle:UIAlertControllerStyleAlert];

        [menu addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Состояние"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            tnx_alert_menu(tnx_status_text());
        }]];

        [menu addAction:[UIAlertAction actionWithTitle:@"Скрыть алерты"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
            g_alerts_off = 1;
        }]];

        [host presentViewController:menu animated:YES completion:nil];
    });
}

void tnx_battle_alert(uintptr_t scene, uintptr_t scenePrev) {
    uint64_t now = 0;

    if (!scene) return;
    if (g_alerts_off) return;
    if (scene == g_alert_scene) return;

    now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

    if (g_alert_ms && now - g_alert_ms < TNX_ALERT_GAP_MS) {
        TNX_LOGX("alert withheld prev=%p now=%p sinceMs=%llu nowMs=%llu gapMs=%d - the alert "
                 "call moved off the container change and onto the scene edge, because the v134 run "
                 "showed the menu ten times in ten seconds while the scene pointer in the heartbeat "
                 "never moved: the call sat in the container-change block, so every hop flip looked "
                 "like a battle entry; prev and now are printed so a real repeat is distinguishable "
                 "from the old misfire",
                 (void *)scenePrev, (void *)scene, (unsigned long long)g_alert_ms,
                 (unsigned long long)now, TNX_ALERT_GAP_MS);

        return;
    }

    g_alert_scene = scene;
    g_alert_ms = now;

    TNX_LOGX("alert shown prev=%p now=%p edgePrev=%p sinceMs=%llu gapMs=%d - printed after both "
             "gates, so the menu line that follows cannot be mistaken for a call that skipped them; "
             "edgePrev is the scene the edge detector itself last held, so a repeat that reaches this "
             "line with edgePrev equal to now is an edge misfire and not a real battle entry, which is "
             "exactly what the v137 run could not be asked",
             (void *)scenePrev, (void *)scene, (void *)g_prev_scene,
             (unsigned long long)g_alert_ms, TNX_ALERT_GAP_MS);

    g_prev_scene = scene;

    tnx_alert_menu([NSString stringWithFormat:
        @"Вход в бой\nscene=%p (было %p)\ncontainer=%p count=%d\ngid=%d..%d\nown=min gid",
        (void *)scene, (void *)scenePrev, (void *)g_players_object, g_players_count,
        g_gid_lo, g_gid_hi]);
}
