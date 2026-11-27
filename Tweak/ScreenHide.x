#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);

static UIView *_needleCaptureOverlay = nil;

static UIWindow *_NeedleKeyWindow(void) {
    NSArray *scenes = [[UIApplication sharedApplication].connectedScenes allObjects];
    for (UIScene *s in scenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            UIWindowScene *ws = (UIWindowScene *)s;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
            if (ws.windows.count) return ws.windows.firstObject;
        }
    }
    return nil;
}

static void _NeedleSyncCapture(void) {
    BOOL isCaptured = [UIScreen mainScreen].isCaptured;
    BOOL enabled = NeedlePrefBool(@"HideInCapture", NO);

    if (isCaptured && enabled) {
        UIWindow *win = _NeedleKeyWindow();
        if (!win) return;
        if (!_needleCaptureOverlay) {
            _needleCaptureOverlay = [[UIView alloc] initWithFrame:win.bounds];
            _needleCaptureOverlay.backgroundColor = [UIColor blackColor];
            _needleCaptureOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _needleCaptureOverlay.userInteractionEnabled = NO;

            UIImageView *icon = [[UIImageView alloc] initWithImage:
                [UIImage systemImageNamed:@"eye.slash.fill"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold]]];
            icon.tintColor = [NeedleCurrentColor() colorWithAlphaComponent:0.6];
            icon.contentMode = UIViewContentModeCenter;
            icon.frame = CGRectMake((win.bounds.size.width - 60) / 2, win.bounds.size.height / 2 - 50, 60, 60);
            icon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            [_needleCaptureOverlay addSubview:icon];

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, win.bounds.size.height / 2 + 20, win.bounds.size.width, 24)];
            lbl.text = @"Hidden by Needle";
            lbl.textColor = [UIColor colorWithWhite:1 alpha:0.5];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            [_needleCaptureOverlay addSubview:lbl];
        }
        if (_needleCaptureOverlay.superview != win) {
            [_needleCaptureOverlay removeFromSuperview];
            _needleCaptureOverlay.frame = win.bounds;
            _needleCaptureOverlay.alpha = 0;
            [win addSubview:_needleCaptureOverlay];
        }
        [win bringSubviewToFront:_needleCaptureOverlay];
        [UIView animateWithDuration:0.2 animations:^{ _needleCaptureOverlay.alpha = 1; }];
    } else {
        if (_needleCaptureOverlay) {
            UIView *v = _needleCaptureOverlay;
            [UIView animateWithDuration:0.2 animations:^{ v.alpha = 0; } completion:^(BOOL f) {
                [v removeFromSuperview];
            }];
            _needleCaptureOverlay = nil;
        }
    }
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            _NeedleSyncCapture();
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePrefsChanged"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            NSString *key = n.object;
            if ([key isEqualToString:@"HideInCapture"]) {
                _NeedleSyncCapture();
            }
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            _NeedleSyncCapture();
        }];
}
