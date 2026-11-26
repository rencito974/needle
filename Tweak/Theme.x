#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern UIColor *NeedleDominantColor(UIImage *);
extern void NeedleSetPalette(UIColor *);
extern UIColor *NeedleCurrentColor(void);
extern UIColor *NeedleContrastColor(void);
extern BOOL NeedlePrefBool(NSString *key, BOOL def);

@interface SPTNowPlayingContainedViewController : UIViewController
@end
@interface SPTNowPlayingContainingViewController : UIViewController
@end
@interface SPTNowPlayingViewContainerViewController : UIViewController
@end
@interface SPTNowPlayingBackgroundViewModel : NSObject
@end
@interface SPTNowPlayingContentCoverArtCell : UIView
@end
@interface SPTTabBarContainer : UIViewController
@end
@interface SPTNowPlayingBar : UIView
@end

@interface _NeedleGradientView : UIView
@end

@implementation _NeedleGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (void)apply:(UIColor *)top {
    if (!top) top = [UIColor colorWithWhite:0.08 alpha:1.0];
    CAGradientLayer *l = (CAGradientLayer *)self.layer;
    UIColor *bottom = [UIColor colorWithWhite:0.03 alpha:1.0];
    l.colors = @[(id)top.CGColor, (id)bottom.CGColor];
    l.locations = @[@0.0, @0.75];
    l.startPoint = CGPointMake(0.5, 0.0);
    l.endPoint = CGPointMake(0.5, 1.0);
}
@end

static void _NeedleInstallBackground(UIViewController *vc) {
    if (!NeedlePrefBool(@"AlbumColorUI", YES)) return;
    if (!vc || !vc.view) return;
    _NeedleGradientView *bg = objc_getAssociatedObject(vc, "_needleBg");
    if (!bg) {
        bg = [[_NeedleGradientView alloc] initWithFrame:vc.view.bounds];
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [vc.view insertSubview:bg atIndex:0];
        objc_setAssociatedObject(vc, "_needleBg", bg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak _NeedleGradientView *weakBg = bg;
        [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePaletteChanged"
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *n) {
                _NeedleGradientView *strong = weakBg;
                if (!strong) return;
                UIColor *c = [n.object isKindOfClass:[UIColor class]] ? (UIColor *)n.object : nil;
                [UIView animateWithDuration:0.6 animations:^{
                    [strong apply:c];
                }];
            }];
    }
    [bg apply:NeedleCurrentColor()];
}

%hook SPTNowPlayingContainedViewController
- (void)viewDidLoad { %orig; _NeedleInstallBackground(self); }
%end

%hook SPTNowPlayingContainingViewController
- (void)viewDidLoad { %orig; _NeedleInstallBackground(self); }
%end

%hook SPTNowPlayingViewContainerViewController
- (void)viewDidLoad { %orig; _NeedleInstallBackground(self); }
%end

%hook SPTNowPlayingBackgroundViewModel
- (UIColor *)backgroundColor {
    if (!NeedlePrefBool(@"AlbumColorUI", YES)) return %orig;
    return NeedleCurrentColor();
}
- (UIColor *)primaryColor {
    if (!NeedlePrefBool(@"AlbumColorUI", YES)) return %orig;
    return NeedleCurrentColor();
}
%end

static void _NeedleStartBreathing(UIView *view) {
    if (!view) return;
    if (!NeedlePrefBool(@"ArtworkBreathing", YES)) return;
    if (objc_getAssociatedObject(view, "_needleBreathing")) return;
    objc_setAssociatedObject(view, "_needleBreathing", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    a.fromValue = @1.0;
    a.toValue = @1.03;
    a.duration = 3.5;
    a.autoreverses = YES;
    a.repeatCount = HUGE_VALF;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:a forKey:@"needleBreathing"];
}

%hook SPTNowPlayingContentCoverArtCell
- (void)setArtworkImage:(UIImage *)img {
    %orig;
    if (!img || !NeedlePrefBool(@"AlbumColorUI", YES)) return;
    UIImage *retained = img;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIColor *c = NeedleDominantColor(retained);
        NeedleSetPalette(c);
    });
}
- (void)setImage:(UIImage *)img {
    %orig;
    if (!img || !NeedlePrefBool(@"AlbumColorUI", YES)) return;
    UIImage *retained = img;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIColor *c = NeedleDominantColor(retained);
        NeedleSetPalette(c);
    });
}
- (void)didMoveToWindow {
    %orig;
    if (self.window) _NeedleStartBreathing(self);
}
%end

%hook SPTNowPlayingBar
- (void)didMoveToSuperview {
    %orig;
    if (!NeedlePrefBool(@"AlbumColorUI", YES)) return;
    if (!self.superview) return;
    _NeedleGradientView *bg = objc_getAssociatedObject(self, "_needleMiniBg");
    if (!bg) {
        bg = [[_NeedleGradientView alloc] initWithFrame:self.bounds];
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        bg.layer.cornerRadius = 12;
        bg.layer.masksToBounds = YES;
        bg.alpha = 0.9;
        [self insertSubview:bg atIndex:0];
        objc_setAssociatedObject(self, "_needleMiniBg", bg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak _NeedleGradientView *weakBg = bg;
        [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePaletteChanged"
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *n) {
                _NeedleGradientView *strong = weakBg;
                if (!strong) return;
                UIColor *c = [n.object isKindOfClass:[UIColor class]] ? (UIColor *)n.object : nil;
                [UIView animateWithDuration:0.6 animations:^{
                    [strong apply:c];
                }];
            }];
    }
    [bg apply:NeedleCurrentColor()];
}
%end

%hook SPTTabBarContainer
- (void)viewDidLoad {
    %orig;
    if (!NeedlePrefBool(@"AlbumColorUI", YES)) return;
    UITabBar *tb = nil;
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[UITabBar class]]) { tb = (UITabBar *)v; break; }
    }
    if (!tb) return;
    tb.tintColor = [UIColor whiteColor];
    tb.unselectedItemTintColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *vfx = [[UIVisualEffectView alloc] initWithEffect:blur];
    vfx.frame = tb.bounds;
    vfx.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [tb insertSubview:vfx atIndex:0];
}
%end
