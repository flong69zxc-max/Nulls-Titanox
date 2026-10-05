TARGET := iphone:clang:latest:15.0
ARCHS := arm64

TITANOX := deps/Titanox/libtitanox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox

Titanox_FILES = $(wildcard src/core/*.mm)
Titanox_FILES += $(wildcard src/utils/*.mm)
Titanox_FILES += $(wildcard src/helpers/*.mm)
Titanox_FILES += $(wildcard src/features/*.mm)
Titanox_FILES += $(wildcard src/*.mm)
Titanox_FILES += $(TITANOX)/brk_hook/Hook/hook.c
Titanox_FILES += $(TITANOX)/brk_hook/Hook/mach_excServer.c

COMMON_INCLUDES = \
	-Isrc \
	-Iinclude \
	-I$(TITANOX) \
	-I$(TITANOX)/libtitanox \
	-I$(TITANOX)/brk_hook \
	-I$(TITANOX)/brk_hook/Hook

Titanox_CFLAGS = -Iinclude -Isrc -I$(TITANOX)/brk_hook/Hook

Titanox_OBJCFLAGS = -fobjc-arc -std=c++17 $(COMMON_INCLUDES) \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter \
	-Wno-everything

Titanox_LDFLAGS = -Wl,-undefined,dynamic_lookup

Titanox_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
