TARGET := iphone:clang:latest:15.0
ARCHS := arm64

RECOIL := deps/Recoil/librecoil

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Recoil

Recoil_FILES = $(shell find src -name "*.mm")
Recoil_FILES += $(RECOIL)/brk_hook/Hook/hook.c
Recoil_FILES += $(RECOIL)/brk_hook/Hook/mach_excServer.c

COMMON_INCLUDES = \
	-Isrc \
	-Iinclude \
	-I$(RECOIL) \
	-I$(RECOIL)/librecoil \
	-I$(RECOIL)/brk_hook \
	-I$(RECOIL)/brk_hook/Hook

Recoil_CFLAGS = -Iinclude -Isrc -I$(RECOIL)/brk_hook/Hook

Recoil_OBJCFLAGS = -fobjc-arc -std=c++17 $(COMMON_INCLUDES) \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter \
	-Wno-everything

Recoil_LDFLAGS = -Wl,-undefined,dynamic_lookup

Recoil_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
