#ifndef SIM_MACH_H
#define SIM_MACH_H
#include <stdint.h>
#include <stddef.h>
typedef int kern_return_t;
typedef unsigned int mach_port_t;
typedef uintptr_t vm_address_t;
typedef uintptr_t vm_size_t;
typedef uint64_t mach_vm_address_t;
typedef uint64_t mach_vm_size_t;
typedef uint32_t vm_prot_t;
typedef int vm_region_flavor_t;
typedef int *vm_region_info_t;
typedef unsigned int mach_msg_type_number_t;
typedef unsigned int vm_object_id_t;
typedef struct { mach_vm_address_t address; mach_vm_size_t size; } mach_vm_region_probe_t;
extern "C" mach_port_t mach_task_self(void);
extern "C" kern_return_t mach_port_deallocate(mach_port_t task, mach_port_t name);
extern "C" kern_return_t vm_region_64(mach_port_t task, vm_address_t *address, vm_size_t *size, int flavor, vm_region_info_t info, mach_msg_type_number_t *count, mach_port_t *object_name);
extern "C" kern_return_t vm_read_overwrite(mach_port_t task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *out_size);
#define KERN_SUCCESS 0
#define KERN_INVALID_ADDRESS 1
#define VM_PROT_READ 1
#define VM_PROT_WRITE 2
#define VM_PROT_EXECUTE 4
#define VM_REGION_BASIC_INFO_64 9
#define VM_REGION_BASIC_INFO_COUNT_64 10
#define MACH_PORT_NULL ((mach_port_t)0)
#define VM_REGION_EXTENDED_INFO 11
#define VM_REGION_TOP_INFO 12
#endif
