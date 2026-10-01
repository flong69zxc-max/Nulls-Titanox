#ifndef OFFSETS_H
#define OFFSETS_H

#include <stddef.h>
#include <stdint.h>
#include <mach-o/loader.h>

#define RVA_NATIVEFONT_FORMATSTRING 0ULL
#define RVA_MESSAGEMANAGER_RECEIVEMESSAGE 0ULL
#define RVA_LOGICDATATABLES_INITDATATABLE 0ULL
#define RVA_LOGICPROJECTILEDATA_GETINTVALUEFROMCOLUMN 0ULL
#define RVA_STAGE_SETVIEWPORT 0ULL

#define RVA_GAMEBUTTON_CTOR 0ULL
#define RVA_HOMEPAGE_CTOR 0ULL
#define RVA_CHARACTER_CTOR 0ULL
#define RVA_LOGICDATATABLES_CTOR 0ULL
#define RVA_LOGICPROJECTILEDATA_CTOR 0ULL
#define RVA_MESSAGEMANAGER_CTOR 0ULL
#define RVA_MOVIECLIP_CTOR 0ULL
#define RVA_NATIVEFONT_CTOR 0ULL
#define RVA_STAGE_CTOR 0ULL

#define VT_GAMEBUTTON 0ULL
#define VT_HOMEPAGE 0ULL
#define VT_CHARACTER 0ULL
#define VT_LOGICDATATABLES 0ULL
#define VT_LOGICPROJECTILEDATA 0ULL
#define VT_MESSAGEMANAGER 0ULL
#define VT_MOVIECLIP 0ULL
#define VT_NATIVEFONT 0ULL
#define VT_STAGE 0ULL

typedef struct {
    uintptr_t base;
    const struct mach_header_64 *hdr;
} image_ref_t;

#ifdef __cplusplus
extern "C" {
#endif

uintptr_t rt_resolve_method(
    image_ref_t img,
    const char *cls,
    const char *meth,
    uintptr_t *func_starts,
    size_t starts_n,
    uintptr_t *xref_pc_out
);

void rt_dump_image(image_ref_t img);
void rt_dump_target(const char *name, uintptr_t target);
int rt_is_code(image_ref_t img, uintptr_t target);

#ifdef __cplusplus
}
#endif

#endif