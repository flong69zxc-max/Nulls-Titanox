TARGET := iphone:clang:latest:15.0
ARCHS := arm64

TITANOX := deps/Titanox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox

Titanox_FILES = src/Titanox.mm
Titanox_FILES += $(shell find $(TITANOX) -type f \( -name '*.m' -o -name '*.mm' -o -name '*.c' \) ! -path '*/build/*' ! -path '*/.git/*' ! -path '*/Tests/*' 2>/dev/null)

Titanox_CFLAGS = \
	-Iinclude \
	-I$(TITANOX) \
	-I$(TITANOX)/libtitanox \
	-I$(TITANOX)/libtitanox/libtitanox \
	-I$(TITANOX)/libtitanox/brk_hook \
	-I$(TITANOX)/libtitanox/brk_hook/Hook \
	-I$(TITANOX)/libtitanox/MemX \
	-I$(TITANOX)/libtitanox/fishhook \
	-I$(TITANOX)/libtitanox/mempatch \
	-I$(TITANOX)/libtitanox/static-inline-hook \
	-I$(TITANOX)/libtitanox/utils \
	-I$(TITANOX)/libtitanox/vm_funcs

Titanox_OBJCFLAGS = -fobjc-arc -std=c++17 $(Titanox_CFLAGS) \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter \
	-Wno-everything

Titanox_LDFLAGS = -Wl,-undefined,dynamic_lookup

Titanox_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk