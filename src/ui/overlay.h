#ifndef TITANOX_UI_OVERLAY_H
#define TITANOX_UI_OVERLAY_H

#include "core/types.h"

extern int t_alerts_off;
extern UILabel * t_overlay;
void tnx_alert_battle_check(void);
void tnx_alert_menu(NSString *info);
void tnx_battle_alert(uintptr_t scene, uintptr_t scenePrev);
void tnx_overlay_update(void);
void tnx_render_watermark(void);

#endif
