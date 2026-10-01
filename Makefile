TARGET := iphone:clang:latest:15.0
ARCHS := arm64

TITANOX := deps/Titanox/libtitanox

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox

Titanox_FILES = src/Titanox.mm
Titanox_FILES += $(shell find $(TITANOX) -type f \( -name '*.m' -o -name '*.mm' -o -name '*.c' \) ! -path '*/build/*' 2>/dev/null)

Titanox_CFLAGS = -fobjc-arc \
	-Iinclude \
	-I$(TITANOX) \
	-I$(TITANOX)/libtitanox \
	-I$(TITANOX)/brk_hook \
	-I$(TITANOX)/brk_hook/Hook \
	-I$(TITANOX)/MemX \
	-I$(TITANOX)/fishhook \
	-I$(TITANOX)/mempatch \
	-I$(TITANOX)/static-inline-hook \
	-I$(TITANOX)/utils \
	-I$(TITANOX)/vm_funcs \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -Wno-everything \
	-Wl,-undefined,dynamic_lookup

Titanox_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk