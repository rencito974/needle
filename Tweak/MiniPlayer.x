#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern UIColor *NeedleCurrentColor(void);
extern BOOL NeedlePrefBool(NSString *key, BOOL def);

@interface SPTNowPlayingBar : UIView
@end

static char _kNeedleMiniProgress;

static char _kNeedleBTBadge;

static NSString *NeedleBTRouteBadge(void) {
    AVAudioSessionRouteDescription *rd = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription *p in rd.outputs) {
        NSString *type = p.portType;
        if ([type isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [type isEqualToString:AVAudioSessionPortBluetoothLE] ||
            [type isEqualToString:AVAudioSessionPortBluetoothHFP] ||
            [type isEqualToString:AVAudioSessionPortAirPlay]) {
            NSString *name = p.portName ?: @"BT";
            if (name.length > 12) name = [[name substringToIndex:12] stringByAppendingString:@"…"];
            return [NSString stringWithFormat:@"🎧 %@", name];
        }
    }
    return nil;
}

extern void NeedleOpenLocalPreviewFromMiniPlayer(UIView *v);

%hook SPTNowPlayingBar

- (void)layoutSubviews {
    %orig;
    if (!NeedlePrefBool(@"MiniPlayerRedesign", YES)) return;
    if (!self.superview) return;

    UIView *progress = objc_getAssociatedObject(self, &_kNeedleMiniProgress);
    if (!progress) {
        CGFloat h = 2;
        progress = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - h, 0, h)];
        progress.backgroundColor = NeedleCurrentColor();
        progress.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        progress.layer.cornerRadius = 1;
        progress.userInteractionEnabled = NO;
        [self addSubview:progress];
        objc_setAssociatedObject(self, &_kNeedleMiniProgress, progress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePaletteChanged" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            UIView *p = objc_getAssociatedObject(self, &_kNeedleMiniProgress);
            p.backgroundColor = NeedleCurrentColor();
        }];
    }
    CGRect pf = progress.frame;
    pf.origin.y = self.bounds.size.height - pf.size.height;
    progress.frame = pf;

    if (NeedlePrefBool(@"BTBadge", YES)) {
        UILabel *badge = objc_getAssociatedObject(self, &_kNeedleBTBadge);
        if (!badge) {
            badge = [[UILabel alloc] init];
            badge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            badge.textColor = [UIColor colorWithWhite:1 alpha:0.9];
            badge.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
            badge.layer.cornerRadius = 8;
            badge.layer.masksToBounds = YES;
            badge.textAlignment = NSTextAlignmentCenter;
            badge.userInteractionEnabled = NO;
            [self addSubview:badge];
            objc_setAssociatedObject(self, &_kNeedleBTBadge, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSString *txt = NeedleBTRouteBadge();
        if (txt) {
            badge.hidden = NO;
            badge.text = [NSString stringWithFormat:@" %@ ", txt];
            [badge sizeToFit];
            CGRect bf = badge.frame;
            bf.size.width += 8;
            bf.size.height = 16;
            bf.origin.x = self.bounds.size.width - bf.size.width - 10;
            bf.origin.y = 4;
            badge.frame = bf;
        } else {
            badge.hidden = YES;
        }
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

void NeedleOnPositionChanged(id player, NSTimeInterval pos) {
    static NSTimeInterval lastUpdate = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastUpdate < 0.4) return;
    lastUpdate = now;
    NSTimeInterval dur = 0;
    @try { dur = [[[player valueForKey:@"currentTrack"] valueForKey:@"duration"] doubleValue] / 1000.0; } @catch (NSException *e) {}
    if (dur > 0) {
        float frac = pos / dur;
        dispatch_async(dispatch_get_main_queue(), ^{ NeedleUpdateMiniProgress(frac); });
    }
}
