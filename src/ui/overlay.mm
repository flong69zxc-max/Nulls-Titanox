#include "titanox.h"

void tnx_overlay_update(void) {
    char text[192];
    double now = CFAbsoluteTimeGetCurrent();

    if (t_overlay) {
        UILabel *stale = t_overlay;

        t_overlay = NULL;

        dispatch_async(dispatch_get_main_queue(), ^{
            [stale removeFromSuperview];
        });
    }

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

    t_alert_calls++;

    if (t_scene_object) candidate = t_scene_object;
    else if (t_players_object) candidate = t_players_object;

    if (!candidate) {
        why = "mode=0 and manager=0 (the scanner's hit is not a container)";
    } else {

        if (facts.live < 2) {
            why = "live<2";
        } else if (facts.teamCount < 2) {
            why = "teamCount<2";
        } else {

            if (t_alert_streak_ptr == candidate) t_alert_streak++;
            else {
                t_alert_streak_ptr = candidate;
                t_alert_streak = 1;
            }

            counted = 1;

            if (t_alert_streak < TNX_ALERT_SIGHTINGS) {
                why = "sightings<3";
            } else {
                armed = 1;
            }
        }
    }

    if (!counted) {
        t_alert_streak = 0;
        t_alert_streak_ptr = 0;
    }

    if (!armed) withheld = 1;

    if (withheld) {

        if (t_alert_shown) {
            if (t_alert_cleared_ms == 0) t_alert_cleared_ms = now;
            else if (now > t_alert_cleared_ms + 5000) {
                t_alert_shown = 0;
                t_alert_cleared_ms = 0;
            }
        }

        return;
    }

    t_alert_cleared_ms = 0;

    if (!t_alert_shown && now > 3000) {
        t_alert_shown = 1;

        tnx_logf("battle entry: live=%d teamCount=%d distinctGids=%d deadOk=%d vt0=%#llx "
                 "sightings=%d bestLive=%d bestCount=%d mode=%p manager=%p candidate=%p -- showing "
                 "alert",
                 facts.live, facts.teamCount, facts.distinctGids, facts.deadOk,
                 (unsigned long long)facts.vt0, t_alert_streak, t_manager_best_live,
                 t_manager_best_count, (void *)t_scene_object, (void *)t_players_object,
                 (void *)candidate);

    }
}

void tnx_render_watermark(void) {
    if (!t_base || t_wm_failed) return;

    if (!t_wm_ready) {
        if (!t_addr_getclip || !t_addr_gettf || !t_addr_settext || !t_addr_setxy || !t_addr_addchild) {
            t_wm_failed = YES;
            tlog(@"watermark disabled: unresolved address");
            return;
        }

        void *stage = tnx_read_global_ptr(OFF_STAGEINSTANCEGLOBALPTR);
        if (!tnx_object_plausible(stage)) return;

        void *scFile = tnx_sc_string(TNX_CLIP_FILE);
        void *scName = tnx_sc_string(TNX_CLIP_NAME);
        void *scText = tnx_sc_string(TNX_CLIP_TEXT);

        if (!scFile || !scName || !scText) return;

        void *clip = ((fn_ptr_2_t)t_addr_getclip)(scFile, scName);
        if (!tnx_object_plausible(clip)) return;

        void *tf = ((fn_ptr_2_t)t_addr_gettf)(clip, scText);
        if (!tnx_object_plausible(tf)) return;

        ((fn_setxy_t)t_addr_setxy)(clip, 60536.0f, 60536.0f);
        ((fn_void_2_t)t_addr_addchild)(stage, clip);

        t_label_clip = clip;
        t_label_tf = tf;
        t_wm_ready = YES;

        tlog([NSString stringWithFormat:@"watermark ready stage=%p clip=%p tf=%p", stage, clip, tf]);
    }

    if (!t_label_clip || !t_label_tf) return;

    {
        char want[64];
        int n = snprintf(want, sizeof(want), "%s [%s]", TNX_BUILD_TAG, tnx_state_name());

        if (n > 0 && (size_t)n < sizeof(want) && strcmp(t_label_text, want) != 0) {
            void *sc = tnx_sc_string(want);

            if (sc) {
                t_label_sc = sc;
                snprintf(t_label_text, sizeof(t_label_text), "%s", want);
                t_label_builds++;
            }
        }
    }

    if (!t_label_sc) return;

    ((fn_settext_t)t_addr_settext)(t_label_tf, t_label_sc, 4, 0);
    t_label_updates++;
}

int t_alerts_off = 0;

UILabel *t_overlay = NULL;

void tnx_alert_menu(NSString *info) {
    NSString *text = [info copy];

    if (t_alerts_off) return;

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
            t_alerts_off = 1;
        }]];

        [host presentViewController:menu animated:YES completion:nil];
    });
}

void tnx_battle_alert(uintptr_t scene, uintptr_t scenePrev) {
    uint64_t now = 0;

    if (!scene) return;
    if (t_alerts_off) return;
    if (scene == t_alert_scene) return;

    now = (uint64_t)(CFAbsoluteTimeGetCurrent() * 1000.0);

    if (t_alert_ms && now - t_alert_ms < TNX_ALERT_GAP_MS) {
        TNX_LOGX("alert withheld prev=%p now=%p sinceMs=%llu nowMs=%llu gapMs=%d - the alert "
                 "call moved off the container change and onto the scene edge, because the v134 run "
                 "showed the menu ten times in ten seconds while the scene pointer in the heartbeat "
                 "never moved: the call sat in the container-change block, so every hop flip looked "
                 "like a battle entry; prev and now are printed so a real repeat is distinguishable "
                 "from the old misfire",
                 (void *)scenePrev, (void *)scene, (unsigned long long)t_alert_ms,
                 (unsigned long long)now, TNX_ALERT_GAP_MS);

        return;
    }

    t_alert_scene = scene;
    t_alert_ms = now;

    TNX_LOGX("alert shown prev=%p now=%p edgePrev=%p sinceMs=%llu gapMs=%d - printed after both "
             "gates, so the menu line that follows cannot be mistaken for a call that skipped them; "
             "edgePrev is the scene the edge detector itself last held, so a repeat that reaches this "
             "line with edgePrev equal to now is an edge misfire and not a real battle entry, which is "
             "exactly what the v137 run could not be asked",
             (void *)scenePrev, (void *)scene, (void *)t_prev_scene,
             (unsigned long long)t_alert_ms, TNX_ALERT_GAP_MS);

    t_prev_scene = scene;

    tnx_alert_menu([NSString stringWithFormat:
        @"Вход в бой\nscene=%p (было %p)\ncontainer=%p count=%d\ngid=%d..%d\nown=min gid",
        (void *)scene, (void *)scenePrev, (void *)t_players_object, t_players_count,
        t_gid_lo, t_gid_hi]);
}
