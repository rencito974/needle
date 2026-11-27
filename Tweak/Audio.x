#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern float NeedlePrefFloat(NSString *key, float def);

static float _NeedleBoost(void) {
    float b = NeedlePrefFloat(@"VolumeBoostAmount", 1.0f);
    if (b < 0.5f) b = 0.5f;
    if (b > 4.0f) b = 4.0f;
    return b;
}

static NSHashTable *_NeedleTrackedMixers(void) {
    static NSHashTable *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

static NSHashTable *_NeedleTrackedAVPlayers(void) {
    static NSHashTable *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

static NSHashTable *_NeedleTrackedAudioPlayers(void) {
    static NSHashTable *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = [NSHashTable weakObjectsHashTable];
    });
    return t;
}

@interface SPTCrossfadeImplementation : NSObject
@end

@interface SPTCrossfadeSettings : NSObject
@end

%hook NSUserDefaults
- (double)doubleForKey:(NSString *)key {
    if (NeedlePrefBool(@"CrossfadeMax", NO)) {
        if ([key isEqualToString:@"crossfade-time"] ||
            [key isEqualToString:@"crossfade-duration"] ||
            [key isEqualToString:@"crossfade-max-seconds"]) {
            return 20.0;
        }
    }
    return %orig;
}
- (NSInteger)integerForKey:(NSString *)key {
    if (NeedlePrefBool(@"CrossfadeMax", NO)) {
        if ([key isEqualToString:@"crossfade-time"] ||
            [key isEqualToString:@"crossfade-max"]) {
            return 20;
        }
    }
    if (NeedlePrefBool(@"HighBitrate", NO)) {
        if ([key isEqualToString:@"stream-quality"] ||
            [key isEqualToString:@"streaming-quality"] ||
            [key isEqualToString:@"audio-quality"] ||
            [key isEqualToString:@"playback-bitrate"]) {
            return 4;
        }
    }
    return %orig;
}
%end

@interface SPTCrossfadeImpl : NSObject
@end
@interface SPTGaplessController : NSObject
@end

%hook SPTGaplessController
- (BOOL)isGaplessEnabled {
    if (NeedlePrefBool(@"GaplessAlbum", YES)) return YES;
    return %orig;
}
%end

static const char *kNeedleNaturalVolKey = "_needleNaturalVol";

%hook AVAudioMixerNode

- (void)setOutputVolume:(float)volume {
    objc_setAssociatedObject(self, kNeedleNaturalVolKey, @(volume), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_NeedleTrackedMixers() addObject:self];
    float b = _NeedleBoost();
    float applied = volume;
    if (b > 1.01f && volume > 0.001f) {
        applied = volume * b;
    } else if (b < 0.99f && volume > 0.001f) {
        applied = volume * b;
    }
    %orig(applied);
}

%end

%hook AVAudioEngine

- (BOOL)startAndReturnError:(NSError **)err {
    BOOL ok = %orig;
    if (ok) {
        @try {
            AVAudioMixerNode *mix = self.mainMixerNode;
            if (mix) {
                NSNumber *existing = objc_getAssociatedObject(mix, kNeedleNaturalVolKey);
                if (!existing) {
                    mix.outputVolume = 1.0f;
                }
            }
        } @catch (NSException *e) {}
    }
    return ok;
}

%end

%hook AVPlayer

- (void)setVolume:(float)volume {
    [_NeedleTrackedAVPlayers() addObject:self];
    objc_setAssociatedObject(self, kNeedleNaturalVolKey, @(volume), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    float b = _NeedleBoost();
    float applied = volume;
    if (b > 1.01f && volume > 0.001f) {
        applied = MIN(1.0f, volume * b);
    } else if (b < 0.99f && volume > 0.001f) {
        applied = volume * b;
    }
    %orig(applied);
}

%end

%hook AVAudioPlayer

- (void)setVolume:(float)volume {
    [_NeedleTrackedAudioPlayers() addObject:self];
    objc_setAssociatedObject(self, kNeedleNaturalVolKey, @(volume), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    float b = _NeedleBoost();
    float applied = volume;
    if (b > 1.01f && volume > 0.001f) {
        applied = volume * b;
    } else if (b < 0.99f && volume > 0.001f) {
        applied = volume * b;
    }
    %orig(applied);
}

%end

static void _NeedleReapplyBoost(void) {
    float b = _NeedleBoost();
    for (AVAudioMixerNode *m in [_NeedleTrackedMixers() allObjects]) {
        @try {
            NSNumber *orig = objc_getAssociatedObject(m, kNeedleNaturalVolKey);
            float v = orig ? [orig floatValue] : 1.0f;
            if (v < 0.001f) v = 1.0f;
            m.outputVolume = v * b;
        } @catch (NSException *e) {}
    }
    for (AVPlayer *p in [_NeedleTrackedAVPlayers() allObjects]) {
        @try {
            NSNumber *orig = objc_getAssociatedObject(p, kNeedleNaturalVolKey);
            float v = orig ? [orig floatValue] : 1.0f;
            if (v < 0.001f) v = 1.0f;
            p.volume = MIN(1.0f, v * b);
        } @catch (NSException *e) {}
    }
    for (AVAudioPlayer *p in [_NeedleTrackedAudioPlayers() allObjects]) {
        @try {
            NSNumber *orig = objc_getAssociatedObject(p, kNeedleNaturalVolKey);
            float v = orig ? [orig floatValue] : 1.0f;
            if (v < 0.001f) v = 1.0f;
            p.volume = v * b;
        } @catch (NSException *e) {}
    }
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePrefsChanged"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            NSString *key = n.object;
            if (![key isKindOfClass:[NSString class]]) return;
            if ([key isEqualToString:@"VolumeBoostAmount"]) {
                _NeedleReapplyBoost();
            }
        }];
}
