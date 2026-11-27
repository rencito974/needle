#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIImage *_needleCurrentArtwork;

static char _kLyricBgView;

static BOOL _NeedleIsLyricVC(Class c) {
    NSString *name = NSStringFromClass(c);
    if (!name.length) return NO;
    NSString *lower = name.lowercaseString;
    if (![lower containsString:@"lyric"]) return NO;
    if ([lower containsString:@"cell"]) return NO;
    if ([lower containsString:@"view"] && ![lower containsString:@"viewcontroller"]) return NO;
    return YES;
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!NeedlePrefBool(@"LyricArtworkBg", YES)) return;
    if (!_needleCurrentArtwork) return;
    if (!_NeedleIsLyricVC([self class])) return;
    if (objc_getAssociatedObject(self, &_kLyricBgView)) return;

    UIImageView *bg = [[UIImageView alloc] initWithImage:_needleCurrentArtwork];
    bg.frame = self.view.bounds;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bg.contentMode = UIViewContentModeScaleAspectFill;
    bg.alpha = 0.18;
    bg.userInteractionEnabled = NO;
    bg.clipsToBounds = YES;
    [self.view insertSubview:bg atIndex:0];

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.13;
    pulse.toValue = @0.24;
    pulse.duration = 1.4;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [bg.layer addAnimation:pulse forKey:@"pulse"];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @1.0;
    scale.toValue = @1.05;
    scale.duration = 4.5;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    [bg.layer addAnimation:scale forKey:@"scale"];

    objc_setAssociatedObject(self, &_kLyricBgView, bg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end
