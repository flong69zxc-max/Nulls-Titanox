TARGET := iphone:clang:latest:15.0
ARCHS := arm64

TITANOX := deps/Titanox/libtitanox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := Titanox

Titanox_FILES := \
	src/Titanox.mm \
	src/resolve_targets.mm \
	$(TITANOX)/brk_hook/Hook/hook.c \
	$(TITANOX)/brk_hook/Hook/mach_excServer.c

COMMON_INCLUDES := \
	-Iinclude \
	-I$(TITANOX)/brk_hook/Hook

Titanox_CFLAGS := \
	$(COMMON_INCLUDES) \
	-Wall \
	-Wextra \
	-Wno-unused-parameter

Titanox_CCFLAGS := -std=c++17
Titanox_OBJCFLAGS := -fobjc-arc

Titanox_FRAMEWORKS := Foundation UIKit
Titanox_LIBRARIES := c++

include $(THEOS_MAKE_PATH)/tweak.mk