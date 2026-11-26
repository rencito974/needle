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

static NSTimer *_sleepFadeTimer = nil;
static float _sleepFadeStartVolume = 1.0;

static void NeedleSetPlayerVolume(float v) {
    id player = _currentSptPlayer;
    if (!player) return;
    SEL sels[] = { @selector(setVolume:), @selector(setPlaybackVolume:) };
    for (NSUInteger i = 0; i < sizeof(sels) / sizeof(SEL); i++) {
        if ([player respondsToSelector:sels[i]]) {
            @try {
                NSMethodSignature *sig = [[player class] instanceMethodSignatureForSelector:sels[i]];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                inv.selector = sels[i];
                [inv setTarget:player];
                [inv setArgument:&v atIndex:2];
                [inv invoke];
                return;
            } @catch (NSException *e) {}
        }
    }
}

static float NeedleGetPlayerVolume(void) {
    id player = _currentSptPlayer;
    if (!player) return 1.0;
    @try {
        if ([player respondsToSelector:@selector(volume)]) {
            return [[player valueForKey:@"volume"] floatValue];
        }
    } @catch (NSException *e) {}
    return 1.0;
}

void NeedleStartSleepTimer(NSInteger minutes) {
    NeedleCancelSleepTimer();
    if (minutes <= 0) return;
    NSTimeInterval interval = minutes * 60.0;
    _sleepFireDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    BOOL fade = NeedlePrefBool(@"SleepFade", YES);
    NSTimeInterval fadeStartOffset = interval - 60.0;
    if (fade && fadeStartOffset < 0) fadeStartOffset = 0;

    _sleepTimer = [NSTimer scheduledTimerWithTimeInterval:interval
        repeats:NO
        block:^(NSTimer *t) {
            NeedleSetPlayerVolume(_sleepFadeStartVolume);
            NeedleAttemptPause();
            _sleepTimer = nil;
            _sleepFireDate = nil;
            [_sleepFadeTimer invalidate];
            _sleepFadeTimer = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedleSleepTimerFired" object:nil];
        }];

    if (fade) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(fadeStartOffset * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!_sleepTimer) return;
            _sleepFadeStartVolume = NeedleGetPlayerVolume();
            __block NSInteger step = 0;
            NSInteger totalSteps = 60;
            _sleepFadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *ft) {
                step++;
                float frac = 1.0 - ((float)step / (float)totalSteps);
                if (frac < 0) frac = 0;
                NeedleSetPlayerVolume(_sleepFadeStartVolume * frac);
                if (step >= totalSteps) {
                    [ft invalidate];
                    _sleepFadeTimer = nil;
                }
            }];
        });
    }
}

NSTimeInterval NeedleSleepTimerRemaining(void) {
    if (!_sleepFireDate) return 0;
    NSTimeInterval r = [_sleepFireDate timeIntervalSinceNow];
    return r > 0 ? r : 0;
}

BOOL NeedleSleepTimerActive(void) {
    return _sleepTimer != nil;
}
