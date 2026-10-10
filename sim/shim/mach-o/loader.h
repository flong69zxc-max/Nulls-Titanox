#ifndef SIM_LOADER_H
#define SIM_LOADER_H
#include <stdint.h>
#define MH_MAGIC_64 0xfeedfacfu
#define CPU_TYPE_ARM64 0x0100000cu
#define LC_SEGMENT_64 0x19u
#define LC_SYMTAB 0x2u
#define LC_FUNCTION_STARTS 0x26u
#define LC_DYLD_CHAINED_FIXUPS 0x80000034u
#define LC_DYLD_EXPORTS_TRIE 0x80000033u
#define S_ATTR_PURE_INSTRUCTIONS 0x80000000u
#define S_ATTR_SOME_INSTRUCTIONS 0x00000400u
struct mach_header_64 { uint32_t magic; int32_t cputype; int32_t cpusubtype; uint32_t filetype; uint32_t ncmds; uint32_t sizeofcmds; uint32_t flags; uint32_t reserved; };
struct load_command { uint32_t cmd; uint32_t cmdsize; };
struct segment_command_64 { uint32_t cmd; uint32_t cmdsize; char segname[16]; uint64_t vmaddr; uint64_t vmsize; uint64_t fileoff; uint64_t filesize; int32_t maxprot; int32_t initprot; uint32_t nsects; uint32_t flags; };
struct section_64 { char sectname[16]; char segname[16]; uint64_t addr; uint64_t size; uint32_t offset; uint32_t align; uint32_t reloff; uint32_t nreloc; uint32_t flags; uint32_t reserved1; uint32_t reserved2; uint32_t reserved3; };
struct symtab_command { uint32_t cmd; uint32_t cmdsize; uint32_t symoff; uint32_t nsyms; uint32_t stroff; uint32_t strsize; };
struct nlist_64 { union { uint32_t n_strx; } n_un; uint8_t n_type; uint8_t n_sect; uint16_t n_desc; uint64_t n_value; };
struct linkedit_data_command { uint32_t cmd; uint32_t cmdsize; uint32_t dataoff; uint32_t datasize; };
#endif
