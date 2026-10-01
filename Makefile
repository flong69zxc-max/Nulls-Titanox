TARGET := iphone:clang:latest:15.0
ARCHS := arm64

TITANOX := deps/Titanox/libtitanox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox

Titanox_FILES = src/Titanox.mm
Titanox_FILES += $(TITANOX)/brk_hook/Hook/hook.c
Titanox_FILES += $(TITANOX)/brk_hook/Hook/mach_excServer.c
Titanox_FILES += src/resolve_targets.mm

COMMON_INCLUDES = \
	-Iinclude \
	-I$(TITANOX)/brk_hook/Hook \
	-I$(TITANOX)/libtitanox

Titanox_CFLAGS = $(COMMON_INCLUDES)

Titanox_OBJCFLAGS = -fobjc-arc -std=c++17 $(COMMON_INCLUDES) \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter \
	-Wno-everything

Titanox_LDFLAGS = -Wl,-undefined,dynamic_lookup

Titanox_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk