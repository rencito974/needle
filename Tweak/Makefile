TARGET := iphone:clang:13.7:13.0
INSTALL_TARGET_PROCESSES = Spotify

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Needle

Needle_FILES = Prefs.x Premium.x Shuffle.x Artwork.x Theme.x Lockscreen.x Scrobble.x Sleep.x Accents.x Update.x Ads.x AutoSkip.x History.x Wrapped.x Icons.x FullLyrics.x MiniPlayer.x LockMotion.x Themes.x Audio.x Waveform.x Blocker.x Mood.x Recognize.x Discover.x FreeUnlock.x Local.x NowPlaying.x More.x Settings.x Turntable.x AlbumWall.x Rating.x Dormant.x
Needle_CFLAGS = -fobjc-arc -fno-threadsafe-statics -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-arc-performSelector-leaks -Wno-unused-value -Wno-objc-method-access
Needle_FRAMEWORKS = UIKit MediaPlayer AVFoundation CoreGraphics ImageIO Foundation CoreImage
Needle_WEAK_FRAMEWORKS = ShazamKit
Needle_LDFLAGS = -framework Security

ifeq ($(NEEDLE_PROBE),1)
Needle_FILES += Probe.x
Needle_CFLAGS += -DNEEDLE_PROBE
endif

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
