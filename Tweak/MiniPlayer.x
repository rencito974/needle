#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern UIColor *NeedleCurrentColor(void);
extern BOOL NeedlePrefBool(NSString *key, BOOL def);

@interface SPTNowPlayingBar : UIView
@end

static char _kNeedleMiniProgress;

%hook SPTNowPlayingBar

- (void)layoutSubviews {
    %orig;
    if (!NeedlePrefBool(@"MiniPlayerRedesign", YES)) return;
    if (!self.superview) return;

    UIView *artwork = nil;
    for (UIView *sub in self.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"Image"] || [cls containsString:@"Cover"] || [cls containsString:@"Artwork"]) {
            artwork = sub;
            break;
        }
    }
    if (artwork) {
        CGRect f = artwork.frame;
        CGFloat target = MIN(self.bounds.size.height - 10, 56);
        if (ABS(f.size.height - target) > 1) {
            f.size.height = target;
            f.size.width = target;
            f.origin.y = (self.bounds.size.height - target) / 2;
            f.origin.x = MAX(f.origin.x, 10);
            artwork.frame = f;
        }
        artwork.layer.cornerRadius = 10;
        artwork.layer.masksToBounds = YES;
        artwork.layer.shadowColor = [UIColor blackColor].CGColor;
        artwork.layer.shadowOffset = CGSizeMake(0, 2);
        artwork.layer.shadowRadius = 6;
        artwork.layer.shadowOpacity = 0.4;
    }

    UIView *progress = objc_getAssociatedObject(self, &_kNeedleMiniProgress);
    if (!progress) {
        progress = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 2, 0, 2)];
        progress.backgroundColor = NeedleCurrentColor();
        progress.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        progress.layer.cornerRadius = 1;
        [self addSubview:progress];
        objc_setAssociatedObject(self, &_kNeedleMiniProgress, progress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePaletteChanged" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            UIView *p = objc_getAssociatedObject(self, &_kNeedleMiniProgress);
            p.backgroundColor = NeedleCurrentColor();
        }];
    }
}

%end

static void NeedleUpdateMiniProgress(float frac) {
    NSArray *scenes = [[UIApplication sharedApplication].connectedScenes allObjects];
    for (UIScene *s in scenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)s).windows) {
            __block __weak void (^weakWalk)(UIView *) = nil;
            void (^walk)(UIView *) = ^(UIView *v) {
                if ([NSStringFromClass([v class]) isEqualToString:@"SPTNowPlayingBar"]) {
                    UIView *p = objc_getAssociatedObject(v, &_kNeedleMiniProgress);
                    if (p) {
                        CGRect f = p.frame;
                        f.size.width = v.bounds.size.width * MAX(0, MIN(1, frac));
                        [UIView animateWithDuration:0.4 animations:^{ p.frame = f; }];
                    }
                }
                void (^strongWalk)(UIView *) = weakWalk;
                for (UIView *c in v.subviews) if (strongWalk) strongWalk(c);
            };
            weakWalk = walk;
            walk(w);
        }
    }
}

@interface SPTPlayerImpl : NSObject
@end

%hook SPTPlayerImpl
- (void)positionChanged:(NSTimeInterval)pos {
    %orig;
    static NSTimeInterval lastUpdate = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastUpdate < 0.4) return;
    lastUpdate = now;
    NSTimeInterval dur = 0;
    @try { dur = [[[self valueForKey:@"currentTrack"] valueForKey:@"duration"] doubleValue] / 1000.0; } @catch (NSException *e) {}
    if (dur > 0) {
        float frac = pos / dur;
        dispatch_async(dispatch_get_main_queue(), ^{ NeedleUpdateMiniProgress(frac); });
    }
}
%end
