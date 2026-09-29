TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Nulls Brawl

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox
Titanox_FILES = src/Tweak.mm $(filter-out %/main.mm, $(shell find deps/Titanox \( -name '*.mm' -o -name '*.m' -o -name '*.cpp' -o -name '*.cc' \) -not -path '*/examples/*'))
Titanox_CFLAGS = -fobjc-arc -std=c++17 -Wno-everything -I$(THEOS_PROJECT_DIR)/deps/Titanox/libtitanox/libtitanox
Titanox_FRAMEWORKS = Foundation UIKit
Titanox_LIBRARIES = c++

include $(THEOS_MAKE_PATH)/tweak.mk
