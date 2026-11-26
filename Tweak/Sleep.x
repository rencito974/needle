#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static NSTimer *_sleepTimer = nil;
static NSDate *_sleepFireDate = nil;
static __weak id _currentSptPlayer = nil;

@interface SPTPlayer : NSObject
@end

%hook SPTPlayer
- (void)setCurrentTrack:(id)track {
    %orig;
    _currentSptPlayer = self;
}
%end

static void NeedleAttemptPause(void) {
    id player = _currentSptPlayer;
    if (!player) return;
    SEL sels[] = {
        @selector(pause),
        @selector(pausePlayback),
        @selector(setPaused:),
    };
    for (NSUInteger i = 0; i < sizeof(sels) / sizeof(SEL); i++) {
        if ([player respondsToSelector:sels[i]]) {
            @try {
                NSMethodSignature *sig = [[player class] instanceMethodSignatureForSelector:sels[i]];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                inv.selector = sels[i];
                [inv setTarget:player];
                if (sels[i] == @selector(setPaused:)) {
                    BOOL yes = YES;
                    [inv setArgument:&yes atIndex:2];
                }
                [inv invoke];
                return;
            } @catch (NSException *e) {
            }
        }
    }
}

void NeedleCancelSleepTimer(void) {
    if (_sleepTimer) {
        [_sleepTimer invalidate];
        _sleepTimer = nil;
    }
    _sleepFireDate = nil;
}

void NeedleStartSleepTimer(NSInteger minutes) {
    NeedleCancelSleepTimer();
    if (minutes <= 0) return;
    NSTimeInterval interval = minutes * 60.0;
    _sleepFireDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    _sleepTimer = [NSTimer scheduledTimerWithTimeInterval:interval
        repeats:NO
        block:^(NSTimer *t) {
            NeedleAttemptPause();
            _sleepTimer = nil;
            _sleepFireDate = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedleSleepTimerFired" object:nil];
        }];
}

NSTimeInterval NeedleSleepTimerRemaining(void) {
    if (!_sleepFireDate) return 0;
    NSTimeInterval r = [_sleepFireDate timeIntervalSinceNow];
    return r > 0 ? r : 0;
}

BOOL NeedleSleepTimerActive(void) {
    return _sleepTimer != nil;
}
