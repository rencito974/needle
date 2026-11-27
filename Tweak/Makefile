TARGET := iphone:clang:13.7:13.0
INSTALL_TARGET_PROCESSES = Spotify

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Needle

Needle_FILES = Minimal.x
Needle_CFLAGS = -fobjc-arc -fno-threadsafe-statics -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-arc-performSelector-leaks -Wno-unused-value -Wno-objc-method-access
Needle_FRAMEWORKS = UIKit MediaPlayer AVFoundation CoreGraphics ImageIO Foundation CoreImage AudioToolbox
Needle_WEAK_FRAMEWORKS = ShazamKit
Needle_LDFLAGS = -framework Security

ifeq ($(NEEDLE_PROBE),1)
Needle_FILES += Probe.x
Needle_CFLAGS += -DNEEDLE_PROBE
endif

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
