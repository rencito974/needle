#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

@interface SPTPlayerTrack : NSObject
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) BOOL isExplicit;
@property (nonatomic, readonly) NSString *name;
@end

@interface SPTPlayerImpl : NSObject
- (void)skipNext;
@end

%hook SPTPlayerImpl
- (void)setCurrentTrack:(SPTPlayerTrack *)track {
    %orig;
    if (!track) return;
    BOOL skipShort = NeedlePrefBool(@"SkipInterludes", NO);
    BOOL skipExplicit = NeedlePrefBool(@"SkipExplicit", NO);

    NSTimeInterval dur = 0;
    @try { dur = [[track valueForKey:@"duration"] doubleValue] / 1000.0; } @catch (NSException *e) {}
    if (dur == 0) {
        @try { dur = track.duration / 1000.0; } @catch (NSException *e) {}
    }

    BOOL explicit = NO;
    @try { explicit = [[track valueForKey:@"isExplicit"] boolValue]; } @catch (NSException *e) {}

    NSString *name = nil;
    @try { name = [track valueForKey:@"name"]; } @catch (NSException *e) {}

    BOOL shouldSkip = NO;
    if (skipShort && dur > 0 && dur < 35) shouldSkip = YES;
    if (skipExplicit && explicit) shouldSkip = YES;
    if (skipShort && name.length && (
        [name.lowercaseString containsString:@"interlude"] ||
        [name.lowercaseString containsString:@"intro"] ||
        [name.lowercaseString containsString:@"outro"] ||
        [name.lowercaseString containsString:@"skit"])) {
        shouldSkip = YES;
    }

    if (shouldSkip) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try { [self skipNext]; } @catch (NSException *e) {}
            @try { [self performSelector:NSSelectorFromString(@"skipToNextTrack")]; } @catch (NSException *e) {}
        });
    }
}
%end
