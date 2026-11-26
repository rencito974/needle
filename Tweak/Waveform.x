#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);

@interface SPTProgressView : UIView
@end

static char _kNeedleWaveLayer;

static void NeedleRedrawWave(UIView *host, CGFloat progress) {
    CAShapeLayer *wave = objc_getAssociatedObject(host, &_kNeedleWaveLayer);
    if (!wave) {
        wave = [CAShapeLayer layer];
        wave.frame = host.bounds;
        wave.fillColor = NeedleCurrentColor().CGColor;
        [host.layer addSublayer:wave];
        objc_setAssociatedObject(host, &_kNeedleWaveLayer, wave, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    wave.frame = host.bounds;
    UIBezierPath *p = [UIBezierPath bezierPath];
    CGFloat w = host.bounds.size.width;
    CGFloat h = host.bounds.size.height;
    if (w < 10 || h < 2) return;
    CGFloat barW = 2.5;
    CGFloat gap = 2.0;
    CGFloat step = barW + gap;
    NSInteger bars = (NSInteger)(w / step);
    for (NSInteger i = 0; i < bars; i++) {
        CGFloat frac = (CGFloat)i / (CGFloat)bars;
        CGFloat phase = frac * 10.0;
        CGFloat amp = 0.35 + 0.65 * fabs(sinf(phase + frac * 7.0) * cosf(phase * 1.7));
        CGFloat bH = h * amp;
        CGFloat x = i * step;
        CGFloat y = (h - bH) / 2;
        BOOL played = frac <= progress;
        CGFloat alpha = played ? 1.0 : 0.3;
        CGRect r = CGRectMake(x, y, barW, bH);
        UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:barW / 2];
        CAShapeLayer *bl = [CAShapeLayer layer];
        bl.path = bar.CGPath;
        bl.fillColor = [NeedleCurrentColor() colorWithAlphaComponent:alpha].CGColor;
        [p appendPath:bar];
        (void)bl;
    }
    wave.path = p.CGPath;
    wave.fillColor = NeedleCurrentColor().CGColor;
}

%hook SPTProgressView
- (void)layoutSubviews {
    %orig;
    if (!NeedlePrefBool(@"WaveformScrubber", NO)) {
        CAShapeLayer *wave = objc_getAssociatedObject(self, &_kNeedleWaveLayer);
        if (wave) {
            [wave removeFromSuperlayer];
            objc_setAssociatedObject(self, &_kNeedleWaveLayer, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    CGFloat progress = 0;
    @try {
        if ([self respondsToSelector:@selector(progress)]) {
            progress = [[self valueForKey:@"progress"] floatValue];
        }
    } @catch (NSException *e) {}
    NeedleRedrawWave(self, progress);

    for (UIView *sub in self.subviews) {
        sub.hidden = YES;
    }
}
%end
