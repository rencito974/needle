#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);
extern NSMutableDictionary *_needleCurrentTrackCache;
extern UIImage *_needleCurrentArtwork;
extern void NeedlePlayerTogglePlay(void);
extern void NeedlePlayerNext(void);
extern void NeedlePlayerPrevious(void);

static UIView *_needleCarModeOverlay = nil;

@interface NeedleCarModeView : UIView
@property (nonatomic, strong) UIImageView *bgArt;
@property (nonatomic, strong) UIImageView *art;
@property (nonatomic, strong) UILabel *trackLbl;
@property (nonatomic, strong) UILabel *artistLbl;
@property (nonatomic, strong) UILabel *clockLbl;
@property (nonatomic, strong) UILabel *dateLbl;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *prevBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) NSTimer *clockTick;
@property (nonatomic, assign) BOOL paused;
@end

@implementation NeedleCarModeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return self;
    self.backgroundColor = [UIColor colorWithWhite:0.02 alpha:1];
    CGFloat W = frame.size.width;
    CGFloat H = frame.size.height;

    if (_needleCurrentArtwork) {
        self.bgArt = [[UIImageView alloc] initWithImage:_needleCurrentArtwork];
        self.bgArt.frame = self.bounds;
        self.bgArt.contentMode = UIViewContentModeScaleAspectFill;
        self.bgArt.clipsToBounds = YES;
        [self addSubview:self.bgArt];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        blur.frame = self.bounds;
        [self addSubview:blur];

        UIView *dim = [[UIView alloc] initWithFrame:self.bounds];
        dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        [self addSubview:dim];
    }

    CGFloat artSize = H * 0.7;
    self.art = [[UIImageView alloc] initWithImage:_needleCurrentArtwork];
    self.art.frame = CGRectMake(44, (H - artSize) / 2, artSize, artSize);
    self.art.contentMode = UIViewContentModeScaleAspectFill;
    self.art.layer.cornerRadius = 22;
    self.art.clipsToBounds = YES;
    self.art.backgroundColor = [NeedleCurrentColor() colorWithAlphaComponent:0.25];
    self.art.layer.shadowColor = [UIColor blackColor].CGColor;
    self.art.layer.shadowOffset = CGSizeMake(0, 10);
    self.art.layer.shadowRadius = 24;
    self.art.layer.shadowOpacity = 0.5;
    [self addSubview:self.art];

    CGFloat textX = 44 + artSize + 48;
    CGFloat textW = W - textX - 60;

    self.trackLbl = [[UILabel alloc] initWithFrame:CGRectMake(textX, H * 0.22, textW, 56)];
    self.trackLbl.text = _needleCurrentTrackCache[@"name"] ?: @"";
    self.trackLbl.textColor = [UIColor whiteColor];
    self.trackLbl.font = [UIFont systemFontOfSize:40 weight:UIFontWeightBlack];
    self.trackLbl.adjustsFontSizeToFitWidth = YES;
    self.trackLbl.minimumScaleFactor = 0.6;
    [self addSubview:self.trackLbl];

    self.artistLbl = [[UILabel alloc] initWithFrame:CGRectMake(textX, H * 0.22 + 56, textW, 30)];
    self.artistLbl.text = _needleCurrentTrackCache[@"artist"] ?: @"";
    self.artistLbl.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    self.artistLbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
    [self addSubview:self.artistLbl];

    self.clockLbl = [[UILabel alloc] initWithFrame:CGRectMake(W - 240, 32, 200, 60)];
    self.clockLbl.textColor = [UIColor whiteColor];
    self.clockLbl.font = [UIFont monospacedDigitSystemFontOfSize:52 weight:UIFontWeightHeavy];
    self.clockLbl.textAlignment = NSTextAlignmentRight;
    [self addSubview:self.clockLbl];

    self.dateLbl = [[UILabel alloc] initWithFrame:CGRectMake(W - 240, 94, 200, 20)];
    self.dateLbl.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    self.dateLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    self.dateLbl.textAlignment = NSTextAlignmentRight;
    [self addSubview:self.dateLbl];

    [self updateClock];
    self.clockTick = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(updateClock) userInfo:nil repeats:YES];

    CGFloat btnY = H * 0.6;
    CGFloat playSize = 76;
    CGFloat smSize = 52;
    CGFloat spacing = 26;

    self.prevBtn = [self makeControl:@"backward.fill" size:smSize];
    self.prevBtn.frame = CGRectMake(textX, btnY + (playSize - smSize) / 2, smSize, smSize);
    [self.prevBtn addTarget:self action:@selector(tapPrev) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.prevBtn];

    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake(textX + smSize + spacing, btnY, playSize, playSize);
    self.playBtn.backgroundColor = [UIColor whiteColor];
    self.playBtn.layer.cornerRadius = playSize / 2;
    [self.playBtn setImage:[UIImage systemImageNamed:@"pause.fill"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    self.playBtn.tintColor = [UIColor blackColor];
    [self.playBtn addTarget:self action:@selector(tapPlay) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.playBtn];

    self.nextBtn = [self makeControl:@"forward.fill" size:smSize];
    self.nextBtn.frame = CGRectMake(textX + smSize + spacing + playSize + spacing, btnY + (playSize - smSize) / 2, smSize, smSize);
    [self.nextBtn addTarget:self action:@selector(tapNext) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.nextBtn];

    self.closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeBtn.frame = CGRectMake(W - 60, H - 60, 44, 44);
    self.closeBtn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.closeBtn.layer.cornerRadius = 22;
    self.closeBtn.layer.borderWidth = 0.5;
    self.closeBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [self.closeBtn setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    self.closeBtn.tintColor = [UIColor whiteColor];
    [self.closeBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.closeBtn];

    UILabel *brand = [[UILabel alloc] initWithFrame:CGRectMake(44, H - 48, 200, 20)];
    brand.text = @"Needle Car Mode";
    brand.textColor = [UIColor colorWithWhite:1 alpha:0.3];
    brand.font = [UIFont systemFontOfSize:11 weight:UIFontWeightHeavy];
    [self addSubview:brand];

    return self;
}

- (UIButton *)makeControl:(NSString *)sym size:(CGFloat)size {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:size * 0.42 weight:UIImageSymbolWeightBold];
    [b setImage:[UIImage systemImageNamed:sym withConfiguration:cfg] forState:UIControlStateNormal];
    b.tintColor = [UIColor whiteColor];
    return b;
}

- (void)updateClock {
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm";
    self.clockLbl.text = [df stringFromDate:[NSDate date]];
    NSDateFormatter *df2 = [NSDateFormatter new];
    df2.dateFormat = @"EEEE · MMM d";
    self.dateLbl.text = [[df2 stringFromDate:[NSDate date]] uppercaseString];
}

- (void)tapPlay {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    self.paused = !self.paused;
    [self.playBtn setImage:[UIImage systemImageNamed:self.paused ? @"play.fill" : @"pause.fill"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    NeedlePlayerTogglePlay();
}

- (void)tapNext {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    NeedlePlayerNext();
}

- (void)tapPrev {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    NeedlePlayerPrevious();
}

- (void)dismiss {
    [self.clockTick invalidate];
    self.clockTick = nil;
    [self removeFromSuperview];
    if (_needleCarModeOverlay == self) _needleCarModeOverlay = nil;
}

- (void)dealloc {
    [_clockTick invalidate];
}

@end

void NeedleOpenCarMode(void) {
    if (_needleCarModeOverlay) return;
    UIWindow *w = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in ((UIWindowScene *)s).windows) if (win.isKeyWindow) { w = win; break; }
            if (w) break;
        }
    }
    if (!w) return;
    CGRect bounds = w.bounds;
    CGRect landscapeBounds = CGRectMake(0, 0, bounds.size.height, bounds.size.width);
    NeedleCarModeView *view = [[NeedleCarModeView alloc] initWithFrame:landscapeBounds];
    UIDeviceOrientation o = [UIDevice currentDevice].orientation;
    CGFloat rot = (o == UIDeviceOrientationLandscapeRight) ? -M_PI_2 : M_PI_2;
    view.transform = CGAffineTransformMakeRotation(rot);
    view.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
    view.alpha = 0;
    [w addSubview:view];
    [UIView animateWithDuration:0.3 animations:^{ view.alpha = 1; }];
    _needleCarModeOverlay = view;
}

void NeedleCloseCarMode(void) {
    if (!_needleCarModeOverlay) return;
    UIView *v = _needleCarModeOverlay;
    [UIView animateWithDuration:0.2 animations:^{ v.alpha = 0; } completion:^(BOOL f){
        if ([v isKindOfClass:[NeedleCarModeView class]]) [(NeedleCarModeView *)v dismiss];
        else [v removeFromSuperview];
    }];
    _needleCarModeOverlay = nil;
}
