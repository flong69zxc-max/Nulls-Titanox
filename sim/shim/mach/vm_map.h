#ifndef SIM_VM_MAP_H
#define SIM_VM_MAP_H
#include <mach/mach.h>
typedef struct { vm_address_t address; vm_size_t size; vm_prot_t protection; vm_prot_t max_protection; unsigned int inheritance; int shared; int reserved; unsigned int offset; int behavior; unsigned short user_wired_count; } vm_region_basic_info_data_64_t;
typedef vm_region_basic_info_data_64_t vm_region_basic_info_data_t;
typedef int vm_region_basic_info_t;
typedef struct { vm_address_t address; vm_size_t size; vm_prot_t protection; vm_prot_t max_protection; unsigned int inheritance; int shared; int reserved; unsigned int offset; int behavior; unsigned short user_wired_count; } vm_region_extended_info_data_t;
typedef int vm_region_extended_info_t;
#endif
