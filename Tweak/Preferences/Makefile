ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = NeedlePrefs
NeedlePrefs_FILES = NeedlePrefs.m
NeedlePrefs_INSTALL_PATH = /Library/PreferenceBundles
NeedlePrefs_FRAMEWORKS = UIKit
NeedlePrefs_PRIVATE_FRAMEWORKS = Preferences
NeedlePrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
