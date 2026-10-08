#include "../recoil.h"

float rcl_proj_radius(const rcl_proj_t *p, float speed) {
    uintptr_t base = 0;
    int off = 0;

    if (!RCL_GEOM) return 0.0f;
    if (!p) return 0.0f;
    if (speed < 1.0f) return 0.0f;

    base = p->elem;

    {
        void *def = NULL;

        if (rcl_read_ptr(p->elem + (uintptr_t)RCL_ELEM_DEF_OFF, &def) && def)
            base = (uintptr_t)def;
    }

    if (rcl_rad_off >= 0) {
        float r = 0.0f;

        if (base && rcl_read_float(base + (uintptr_t)rcl_rad_off, &r) &&
            rcl_ok(r, RCL_RADIUS_MIN, RCL_RADIUS_MAX)) {
            rcl_rad_est = r;

            return r;
        }

        return rcl_ok(rcl_rad_est, RCL_RADIUS_MIN, RCL_RADIUS_MAX) ? rcl_rad_est : 0.0f;
    }

    if (!base) return 0.0f;

    for (off = RCL_CAL_OFF_LO; off <= RCL_CAL_OFF_HI; off += RCL_CAL_STEP) {
        float v = 0.0f;
        float r = 0.0f;
        float d = 0.0f;

        if (!rcl_read_float(base + (uintptr_t)off, &v)) continue;
        if (!rcl_ok(v, 1.0f, 1.0e6f)) continue;

        d = v - speed;
        if (d < 0.0f) d = -d;
        if (d > speed * RCL_CAL_TOL) continue;

        if (!rcl_read_float(base + (uintptr_t)off + 4, &r)) continue;
        if (!rcl_ok(r, RCL_RADIUS_MIN, RCL_RADIUS_MAX)) continue;

        if (rcl_cal_off_seen == off && rcl_ok(rcl_cal_rad_seen - r, -1.0f, 1.0f)) {
            rcl_cal_n++;
        } else {
            rcl_cal_off_seen = off;
            rcl_cal_rad_seen = r;
            rcl_cal_n = 1;
        }

        if (rcl_cal_n < RCL_CAL_TICKS) return 0.0f;

        rcl_rad_off = off + 4;
        rcl_rad_est = r;

        return r;
    }

    return RCL_DATA_PROJ_R;
}
