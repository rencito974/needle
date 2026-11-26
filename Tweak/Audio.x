#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern float NeedlePrefFloat(NSString *key, float def);

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

%hook AVAudioEngine
- (BOOL)startAndReturnError:(NSError **)err {
    BOOL ok = %orig;
    if (ok) {
        float boost = NeedlePrefFloat(@"VolumeBoostAmount", 1.0);
        if (boost < 0.5) boost = 0.5;
        if (boost > 4.0) boost = 4.0;
        if (fabsf(boost - 1.0f) > 0.01f) {
            self.mainMixerNode.outputVolume = boost;
        }
    }
    return ok;
}
%end

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePrefsChanged"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            NSString *key = n.object;
            if (![key isKindOfClass:[NSString class]]) return;
            if ([key isEqualToString:@"VolumeBoost"]) {
                BOOL boost = NeedlePrefBool(@"VolumeBoost", NO);
                NSError *err = nil;
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&err];
                (void)boost;
            }
        }];
}
