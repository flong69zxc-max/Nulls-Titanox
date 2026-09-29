TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Nulls Brawl

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox
Titanox_FILES = src/Tweak.mm $(shell find deps/Titanox/libtitanox -type f \( -name '*.mm' -o -name '*.m' -o -name '*.cpp' -o -name '*.cc' -o -name '*.c' -o -name '*.S' \))
Titanox_CFLAGS = -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox
Titanox_CCFLAGS = -std=c++17 -Wno-everything -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox
Titanox_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox
Titanox_FRAMEWORKS = Foundation UIKit
Titanox_LIBRARIES = c++

include $(THEOS_MAKE_PATH)/tweak.mk
