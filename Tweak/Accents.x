#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);
extern UIColor *NeedleContrastColor(void);

@interface SPTNowPlayingPlayButton : UIControl
@end
@interface SPTNowPlayingPlayButtonV2 : UIControl
@end
@interface SPTProgressView : UIView
@end

static void _NeedleTintButton(UIView *v) {
    if (!NeedlePrefBool(@"AccentColors", YES)) return;
    if (!v) return;
    v.tintColor = NeedleCurrentColor();
    for (UIView *sub in v.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)sub).tintColor = NeedleContrastColor();
        }
        if ([sub isKindOfClass:[UIButton class]]) {
            ((UIButton *)sub).tintColor = NeedleContrastColor();
        }
    }
    v.backgroundColor = NeedleCurrentColor();
    v.layer.cornerRadius = MIN(v.bounds.size.width, v.bounds.size.height) / 2.0;
}

static void _NeedleHookAccentObserver(UIView *v) {
    static char _key;
    if (objc_getAssociatedObject(v, &_key)) return;
    objc_setAssociatedObject(v, &_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakV = v;
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePaletteChanged"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            UIView *strong = weakV;
            if (!strong) return;
            [UIView animateWithDuration:0.5 animations:^{
                _NeedleTintButton(strong);
            }];
        }];
}

%hook SPTNowPlayingPlayButton
- (void)layoutSubviews {
    %orig;
    _NeedleTintButton(self);
    _NeedleHookAccentObserver(self);
}
%end

%hook SPTNowPlayingPlayButtonV2
- (void)layoutSubviews {
    %orig;
    _NeedleTintButton(self);
    _NeedleHookAccentObserver(self);
}
%end

%hook SPTProgressView
- (void)layoutSubviews {
    %orig;
    if (!NeedlePrefBool(@"AccentColors", YES)) return;
    self.tintColor = NeedleCurrentColor();
    _NeedleHookAccentObserver(self);
}
%end

%hook UIProgressView
- (void)didMoveToWindow {
    %orig;
    if (!NeedlePrefBool(@"AccentColors", YES)) return;
    if (!self.window) return;
    UIView *anc = self.superview;
    while (anc) {
        NSString *cls = NSStringFromClass([anc class]);
        if ([cls hasPrefix:@"SPTNowPlaying"] || [cls containsString:@"Player"]) {
            self.progressTintColor = NeedleCurrentColor();
            self.trackTintColor = [NeedleCurrentColor() colorWithAlphaComponent:0.25];
            _NeedleHookAccentObserver(self);
            return;
        }
        anc = anc.superview;
    }
}
%end
