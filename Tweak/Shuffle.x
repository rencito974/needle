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

%hook SPTPlayerContext
- (NSArray *)tracks {
    NSArray *orig = %orig;
    if (!NeedlePrefBool(@"RealShuffle", YES)) return orig;
    id ctx = [self valueForKey:@"shuffle"];
    if ([ctx respondsToSelector:@selector(boolValue)] && [ctx boolValue]) {
        return NeedleFisherYates(orig);
    }
    return orig;
}
%end

%hook SPTPlayerQueueImplementation
- (void)setNextTracks:(NSArray *)tracks {
    if (!NeedlePrefBool(@"RealShuffle", YES)) { %orig; return; }
    id shuffleState = [self valueForKey:@"shuffle"];
    BOOL shuffling = [shuffleState respondsToSelector:@selector(boolValue)] && [shuffleState boolValue];
    if (shuffling && tracks.count > 1) {
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
    id shuffleState = [self valueForKey:@"shuffle"];
    if ([shuffleState respondsToSelector:@selector(boolValue)] && [shuffleState boolValue]) {
        return NeedleFisherYates(orig);
    }
    return orig;
}
%end

%hook SPTContextualShuffle_ShuffleToggleModelImpl
- (BOOL)isSmartShuffleEnabled { return NO; }
- (BOOL)isSmartShuffleAvailable { return NO; }
%end
