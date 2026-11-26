#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static NSArray *NeedleFisherYates(NSArray *input) {
    if (input.count < 2) return input;
    NSMutableArray *a = [input mutableCopy];
    for (NSInteger i = (NSInteger)a.count - 1; i > 0; i--) {
        uint32_t j = arc4random_uniform((uint32_t)(i + 1));
        [a exchangeObjectAtIndex:(NSUInteger)i withObjectAtIndex:(NSUInteger)j];
    }
    return [a copy];
}

@interface SPTPlayerContext : NSObject
@end
@interface SPTPlayerQueueImplementation : NSObject
@end
@interface SPTPlayerQueueWrapperImpl : NSObject
@end
@interface SPTContextualShuffle_ShuffleToggleModelImpl : NSObject
@end

static BOOL NeedleReadShuffleState(id target) {
    @try {
        id state = [target valueForKey:@"shuffle"];
        if ([state respondsToSelector:@selector(boolValue)]) return [state boolValue];
    } @catch (NSException *e) {
    }
    return NO;
}

%hook SPTPlayerContext
- (NSArray *)tracks {
    NSArray *orig = %orig;
    if (!NeedlePrefBool(@"RealShuffle", YES)) return orig;
    if (![orig isKindOfClass:[NSArray class]]) return orig;
    if (NeedleReadShuffleState(self)) return NeedleFisherYates(orig);
    return orig;
}
%end

%hook SPTPlayerQueueImplementation
- (void)setNextTracks:(NSArray *)tracks {
    if (!NeedlePrefBool(@"RealShuffle", YES)) { %orig; return; }
    if (NeedleReadShuffleState(self) && tracks.count > 1) {
        %orig(NeedleFisherYates(tracks));
        return;
    }
    %orig;
}
%end

%hook SPTPlayerQueueWrapperImpl
- (NSArray *)nextTracks {
    NSArray *orig = %orig;
    if (!NeedlePrefBool(@"RealShuffle", YES) || orig.count < 2) return orig;
    if (NeedleReadShuffleState(self)) return NeedleFisherYates(orig);
    return orig;
}
%end

%hook SPTContextualShuffle_ShuffleToggleModelImpl
- (BOOL)isSmartShuffleEnabled { return NO; }
- (BOOL)isSmartShuffleAvailable { return NO; }
%end

@interface SPTPlayerImpl : NSObject
@end

%hook SPTPlayerImpl
- (void)setShuffleEnabled:(BOOL)on {
    if (NeedlePrefBool(@"ShuffleLock", NO) && !on) return;
    %orig;
}
- (void)setShuffle:(BOOL)on {
    if (NeedlePrefBool(@"ShuffleLock", NO) && !on) return;
    %orig;
}
%end
