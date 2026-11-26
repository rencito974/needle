#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static NSDictionary *_NeedlePremiumOverrides(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            @"type": @"premium",
            @"catalogue": @"premium",
            @"player-license": @"premium",
            @"name": @"Spotify Premium",
            @"streaming": @"1",
            @"streaming-rules": @"",
            @"ads": @"0",
            @"shuffle": @"1",
            @"offline": @"1",
            @"nft-disabled": @"1",
            @"nft-enabled": @"0",
            @"high-bitrate": @"1",
            @"lossless": @"1",
            @"hifi": @"1",
            @"hifi-lossless-enabled": @"1",
            @"multiuser-playlists-enabled": @"1",
            @"skip-limits-enabled": @"0",
            @"download-limit": @"999999",
            @"offline-number-of-tracks-limit": @"999999",
            @"offline-number-of-devices-limit": @"999999",
            @"radio-recent-artists-limit": @"999999",
            @"on-demand": @"1",
            @"any-tier-upsell-eligible": @"1",
            @"collection-allowed": @"1",
            @"collection-max-limit": @"999999",
            @"iap-trial-upsell": @"0",
            @"base-url": @"https://spclient.wg.spotify.com",
        };
    });
    return d;
}

@interface SPTCoreProductState : NSObject
@end
@interface SPTProductState : NSObject
@end
@interface SPTNowPlayingProductState : NSObject
@end
@interface SPTPlayerRestrictions : NSObject
@end
@interface SPTPlayerSuppressions : NSObject
@end
@interface SPTAdsActionHandler : NSObject
@end
@interface SPTAccountProductInformationController : NSObject
@end

%hook SPTCoreProductState
- (NSString *)productStateValueForKey:(NSString *)key {
    if (!NeedlePrefBool(@"PremiumOn", YES)) return %orig;
    NSString *v = _NeedlePremiumOverrides()[key];
    return v ?: %orig;
}
- (NSDictionary *)productStateDictionary {
    NSDictionary *orig = %orig ?: @{};
    if (!NeedlePrefBool(@"PremiumOn", YES)) return orig;
    NSMutableDictionary *m = [orig mutableCopy];
    [m addEntriesFromDictionary:_NeedlePremiumOverrides()];
    return [m copy];
}
%end

%hook SPTProductState
- (NSString *)productStateValueForKey:(NSString *)key {
    if (!NeedlePrefBool(@"PremiumOn", YES)) return %orig;
    NSString *v = _NeedlePremiumOverrides()[key];
    return v ?: %orig;
}
%end

%hook SPTNowPlayingProductState
- (NSString *)productStateValueForKey:(NSString *)key {
    if (!NeedlePrefBool(@"PremiumOn", YES)) return %orig;
    NSString *v = _NeedlePremiumOverrides()[key];
    return v ?: %orig;
}
%end

%hook SPTPlayerRestrictions
- (NSSet *)disallowPausingReasons { return [NSSet set]; }
- (NSSet *)disallowResumingReasons { return [NSSet set]; }
- (NSSet *)disallowSeekingReasons { return [NSSet set]; }
- (NSSet *)disallowSkippingPrevReasons { return [NSSet set]; }
- (NSSet *)disallowSkippingNextReasons { return [NSSet set]; }
- (NSSet *)disallowPeekingPrevReasons { return [NSSet set]; }
- (NSSet *)disallowPeekingNextReasons { return [NSSet set]; }
- (NSSet *)disallowTogglingShuffleReasons { return [NSSet set]; }
- (NSSet *)disallowTogglingRepeatContextReasons { return [NSSet set]; }
- (NSSet *)disallowTogglingRepeatTrackReasons { return [NSSet set]; }
- (NSSet *)disallowSetQueueReasons { return [NSSet set]; }
- (NSSet *)disallowInterruptingPlaybackReasons { return [NSSet set]; }
- (NSSet *)disallowTransferringPlaybackReasons { return [NSSet set]; }
- (NSSet *)disallowInsertingIntoNextTracksReasons { return [NSSet set]; }
- (NSSet *)disallowInsertingIntoContextTracksReasons { return [NSSet set]; }
- (NSSet *)disallowRemovingFromNextTracksReasons { return [NSSet set]; }
- (NSSet *)disallowRemovingFromContextTracksReasons { return [NSSet set]; }
- (NSSet *)disallowReorderingInNextTracksReasons { return [NSSet set]; }
- (NSSet *)disallowReorderingInContextTracksReasons { return [NSSet set]; }
- (NSSet *)disallowUpdatingContextReasons { return [NSSet set]; }
- (NSSet *)disallowSettingPlaybackSpeedReasons { return [NSSet set]; }
%end

%hook SPTPlayerSuppressions
- (NSSet *)suppressions { return [NSSet set]; }
%end

%hook SPTAdsActionHandler
- (void)showAd:(id)ad { }
- (BOOL)shouldShowAd { return NO; }
- (BOOL)isAdPlaying { return NO; }
%end

%hook SPTAccountProductInformationController
- (NSString *)productType { return @"premium"; }
- (BOOL)isPremium { return YES; }
- (BOOL)isFree { return NO; }
%end
