TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Nulls Brawl

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Titanox
Titanox_FILES = src/Tweak.mm $(wildcard $(THEOS_PROJECT_DIR)/deps/Titanox/*.mm $(THEOS_PROJECT_DIR)/deps/Titanox/*.m $(THEOS_PROJECT_DIR)/deps/Titanox/*.xm)
Titanox_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/deps/Titanox -I$(THEOS_PROJECT_DIR)/deps/Titanox/include
Titanox_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
