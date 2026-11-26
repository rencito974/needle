#import <Foundation/Foundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

@interface SPTFreeTierFeature : NSObject
@end
@interface SPTProductState : NSObject
@end

%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)key {
    if (NeedlePrefBool(@"FreeUnlocks", NO)) {
        if ([key isEqualToString:@"on-demand-enabled"]) return YES;
        if ([key isEqualToString:@"skip-limit-reached"]) return NO;
        if ([key isEqualToString:@"shuffle-only"]) return NO;
        if ([key isEqualToString:@"show-upsell"]) return NO;
        if ([key isEqualToString:@"premium-required"]) return NO;
    }
    return %orig;
}
- (id)stringForKey:(NSString *)key {
    if (NeedlePrefBool(@"FreeUnlocks", NO)) {
        if ([key isEqualToString:@"product-type"]) return @"premium";
        if ([key isEqualToString:@"account-type"]) return @"premium";
    }
    return %orig;
}
%end

%hook SPTFreeTierFeature
- (BOOL)isShuffleOnly { return NeedlePrefBool(@"FreeUnlocks", NO) ? NO : %orig; }
- (BOOL)isOnDemandAllowed { return NeedlePrefBool(@"FreeUnlocks", NO) ? YES : %orig; }
- (BOOL)isUserSubjectToSkipLimits { return NeedlePrefBool(@"FreeUnlocks", NO) ? NO : %orig; }
- (NSInteger)skipsRemaining { return NeedlePrefBool(@"FreeUnlocks", NO) ? 9999 : %orig; }
%end

%hook SPTProductState
- (NSString *)productType { return NeedlePrefBool(@"FreeUnlocks", NO) ? @"premium" : %orig; }
- (BOOL)isPremium { return NeedlePrefBool(@"FreeUnlocks", NO) ? YES : %orig; }
%end
