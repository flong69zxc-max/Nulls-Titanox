TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Nulls Brawl
_THEOS_TARGET_CODESIGN = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox
Titanox_FILES = $(wildcard src/*.mm) $(shell find deps/Titanox/libtitanox -type f \( -name '*.mm' -o -name '*.m' -o -name '*.cpp' -o -name '*.cc' -o -name '*.c' -o -name '*.S' \))
Titanox_CFLAGS = -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox -I$(THEOS_PROJECT_DIR)/src
Titanox_CCFLAGS = -std=c++17 -Wno-everything -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox -I$(THEOS_PROJECT_DIR)/src
Titanox_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox -I$(THEOS_PROJECT_DIR)/src
Titanox_FRAMEWORKS = Foundation UIKit
Titanox_LIBRARIES = c++

include $(THEOS_MAKE_PATH)/tweak.mk
