#ifndef TITANOX_UI_OVERLAY_H
#define TITANOX_UI_OVERLAY_H

#include "core/types.h"

/* the on screen readout and the alerts */

extern int g_alerts_off;
extern UILabel * g_overlay;
void tnx_alert_battle_check(void);
void tnx_alert_menu(NSString *info);
void tnx_battle_alert(uintptr_t scene, uintptr_t scenePrev);
void tnx_overlay_attach(NSString *text);
void tnx_overlay_update(void);
void tnx_render_watermark(void);

#endif
