#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

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
    return %orig;
}
%end

%hook AVAudioEngine
- (BOOL)startAndReturnError:(NSError **)err {
    BOOL ok = %orig;
    if (ok && NeedlePrefBool(@"VolumeBoost", NO)) {
        self.mainMixerNode.outputVolume = 1.5;
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
