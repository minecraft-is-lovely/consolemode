# Pin the patched SDK; "latest" can select Xcode's SDK without private frameworks.
TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ConsoleMode
ConsoleMode_FILES = Tweak.xm ConsoleMode/CMPreferences.m ConsoleMode/CMUI.m
ConsoleMode_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ConsoleMode_FRAMEWORKS = Foundation UIKit WebKit
ConsoleMode_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += ConsoleModePrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
