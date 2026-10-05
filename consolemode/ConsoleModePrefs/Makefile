TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ConsoleModePrefs
ConsoleModePrefs_FILES = ConsoleModePrefsController.m
ConsoleModePrefs_CFLAGS = -fobjc-arc
ConsoleModePrefs_FRAMEWORKS = UIKit Foundation
ConsoleModePrefs_PRIVATE_FRAMEWORKS = Preferences
ConsoleModePrefs_INSTALL_PATH = /Library/PreferenceBundles
ConsoleModePrefs_RESOURCE_FILES = Resources/Info.plist Resources/Root.plist

include $(THEOS_MAKE_PATH)/bundle.mk
