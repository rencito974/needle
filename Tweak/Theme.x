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

@interface _NeedleGradientView : UIView
@end

@implementation _NeedleGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (void)apply:(UIColor *)top {
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
    _NeedleGradientView *bg = objc_getAssociatedObject(vc, "_needleBg");
    if (!bg) {
        bg = [[_NeedleGradientView alloc] initWithFrame:vc.view.bounds];
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [vc.view insertSubview:bg atIndex:0];
        objc_setAssociatedObject(vc, "_needleBg", bg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePaletteChanged"
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *n) {
                _NeedleGradientView *v = objc_getAssociatedObject(vc, "_needleBg");
                [UIView animateWithDuration:0.6 animations:^{
                    [v apply:(UIColor *)n.object];
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

%hook SPTNowPlayingContentCoverArtCell
- (void)setArtworkImage:(UIImage *)img {
    %orig;
    if (!img || !NeedlePrefBool(@"AlbumColorUI", YES)) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIColor *c = NeedleDominantColor(img);
        dispatch_async(dispatch_get_main_queue(), ^{
            NeedleSetPalette(c);
        });
    });
}
- (void)setImage:(UIImage *)img {
    %orig;
    if (!img || !NeedlePrefBool(@"AlbumColorUI", YES)) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIColor *c = NeedleDominantColor(img);
        dispatch_async(dispatch_get_main_queue(), ^{
            NeedleSetPalette(c);
        });
    });
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
