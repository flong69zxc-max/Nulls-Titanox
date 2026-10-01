TARGET := iphone:clang:latest:15.0
ARCHS := arm64

TITANOX := deps/Titanox/libtitanox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox

Titanox_FILES = src/Titanox.mm
Titanox_FILES += src/resolve_targets.mm
Titanox_FILES += $(TITANOX)/brk_hook/Hook/hook.c
Titanox_FILES += $(TITANOX)/brk_hook/Hook/mach_excServer.c

COMMON_INCLUDES = \
	-Iinclude \
	-I$(TITANOX) \
	-I$(TITANOX)/libtitanox \
	-I$(TITANOX)/brk_hook \
	-I$(TITANOX)/brk_hook/Hook

Titanox_CFLAGS = -Iinclude -I$(TITANOX)/brk_hook/Hook

Titanox_OBJCFLAGS = -fobjc-arc -std=c++17 $(COMMON_INCLUDES) \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter \
	-Wno-everything

Titanox_LDFLAGS = -Wl,-undefined,dynamic_lookup

Titanox_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk