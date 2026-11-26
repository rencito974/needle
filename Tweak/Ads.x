#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static BOOL NeedleAdBlock(void) { return NeedlePrefBool(@"BlockAds", YES); }

@interface SPTAdsManager : NSObject
@end
@interface SPTAdsPlayer : NSObject
@end
@interface SPTConnectivityPolicyFeature : NSObject
@end
@interface SPTAdFreeTierHomeHubRequestCustomizer : NSObject
@end
@interface SPTNextUpCarouselEntity : NSObject
@end

%hook SPTAdsManager
- (BOOL)isPlayingAd { return NeedleAdBlock() ? NO : %orig; }
- (void)fetchNextAd { if (NeedleAdBlock()) return; %orig; }
- (void)fetchAd { if (NeedleAdBlock()) return; %orig; }
- (void)playAd { if (NeedleAdBlock()) return; %orig; }
- (void)startPollingForAds { if (NeedleAdBlock()) return; %orig; }
- (void)displayAd { if (NeedleAdBlock()) return; %orig; }
%end

%hook SPTConnectivityPolicyFeature
- (BOOL)isAdPlaybackEnabled { return NeedleAdBlock() ? NO : %orig; }
- (BOOL)isAdFreeAccount { return NeedleAdBlock() ? YES : %orig; }
%end

%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)key {
    if (NeedleAdBlock()) {
        if ([key isEqualToString:@"audio-ads-enabled"]) return NO;
        if ([key isEqualToString:@"video-ads-enabled"]) return NO;
        if ([key isEqualToString:@"display-ads-enabled"]) return NO;
        if ([key isEqualToString:@"audio-skip-enabled"]) return YES;
    }
    return %orig;
}
%end

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if (!NeedleAdBlock()) return;
    NSString *cls = NSStringFromClass([self class]);
    if (!cls) return;
    if ([cls containsString:@"Advert"] ||
        [cls containsString:@"AdUnit"] ||
        [cls containsString:@"HomeAds"] ||
        [cls containsString:@"Marquee"] ||
        [cls containsString:@"Upsell"] ||
        [cls containsString:@"Promo"] ||
        [cls containsString:@"Sponsor"]) {
        self.hidden = YES;
        for (NSLayoutConstraint *c in self.constraints) {
            if (c.firstAttribute == NSLayoutAttributeHeight && c.firstItem == self) {
                c.constant = 0;
            }
        }
        CGRect f = self.frame;
        f.size.height = 0;
        self.frame = f;
    }
}
%end
