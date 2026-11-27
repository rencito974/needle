#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);
extern NSMutableDictionary *_needleCurrentTrackCache;
extern UIImage *_needleCurrentArtwork;

static UIView *_needleTurntableOverlay = nil;

@interface NeedleTurntableView : UIView
@property (nonatomic, strong) UIView *disc;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UIView *centerLabel;
@property (nonatomic, strong) UILabel *trackLbl;
@property (nonatomic, strong) UILabel *artistLbl;
@property (nonatomic, strong) UILabel *rpmLbl;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UIView *tonearm;
@property (nonatomic, assign) CGFloat spinSpeed;
@property (nonatomic, strong) CADisplayLink *tick;
@property (nonatomic, assign) CGFloat angle;
@property (nonatomic, assign) CGFloat idleSpeed;
@end

@implementation NeedleTurntableView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return self;
    self.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1];

    CAGradientLayer *bg = [CAGradientLayer layer];
    UIColor *accent = NeedleCurrentColor();
    bg.colors = @[
        (id)[accent colorWithAlphaComponent:0.22].CGColor,
        (id)[UIColor colorWithWhite:0.02 alpha:1].CGColor,
    ];
    bg.locations = @[@0.0, @0.6];
    bg.frame = self.bounds;
    [self.layer insertSublayer:bg atIndex:0];

    CGFloat side = MIN(frame.size.width, frame.size.height) * 0.86;
    CGFloat cx = frame.size.width / 2;
    CGFloat cy = frame.size.height / 2;

    self.disc = [[UIView alloc] initWithFrame:CGRectMake(cx - side / 2, cy - side / 2, side, side)];
    self.disc.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1];
    self.disc.layer.cornerRadius = side / 2;
    self.disc.layer.shadowColor = [UIColor blackColor].CGColor;
    self.disc.layer.shadowOffset = CGSizeMake(0, 10);
    self.disc.layer.shadowRadius = 30;
    self.disc.layer.shadowOpacity = 0.6;
    [self addSubview:self.disc];

    for (CGFloat r = side / 2 - 6; r > side * 0.2; r -= 5) {
        CAShapeLayer *groove = [CAShapeLayer layer];
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:CGPointMake(side / 2, side / 2) radius:r startAngle:0 endAngle:2 * M_PI clockwise:YES];
        groove.path = p.CGPath;
        groove.fillColor = [UIColor clearColor].CGColor;
        groove.strokeColor = [UIColor colorWithWhite:0.12 alpha:1].CGColor;
        groove.lineWidth = 0.5;
        [self.disc.layer addSublayer:groove];
    }

    for (CGFloat r = side / 2 - 10; r > side * 0.22; r -= 24) {
        CAShapeLayer *highlight = [CAShapeLayer layer];
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:CGPointMake(side / 2, side / 2) radius:r startAngle:0 endAngle:2 * M_PI clockwise:YES];
        highlight.path = p.CGPath;
        highlight.fillColor = [UIColor clearColor].CGColor;
        highlight.strokeColor = [UIColor colorWithWhite:0.22 alpha:1].CGColor;
        highlight.lineWidth = 1.0;
        [self.disc.layer addSublayer:highlight];
    }

    CGFloat labelSide = side * 0.36;
    self.centerLabel = [[UIView alloc] initWithFrame:CGRectMake((side - labelSide) / 2, (side - labelSide) / 2, labelSide, labelSide)];
    self.centerLabel.backgroundColor = NeedleCurrentColor();
    self.centerLabel.layer.cornerRadius = labelSide / 2;
    self.centerLabel.clipsToBounds = YES;
    [self.disc addSubview:self.centerLabel];

    if (_needleCurrentArtwork) {
        self.artworkView = [[UIImageView alloc] initWithImage:_needleCurrentArtwork];
        self.artworkView.frame = CGRectMake(0, 0, labelSide, labelSide);
        self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
        self.artworkView.alpha = 0.95;
        [self.centerLabel addSubview:self.artworkView];
    }

    CGFloat holeSide = 11;
    UIView *hole = [[UIView alloc] initWithFrame:CGRectMake((labelSide - holeSide) / 2, (labelSide - holeSide) / 2, holeSide, holeSide)];
    hole.backgroundColor = [UIColor blackColor];
    hole.layer.cornerRadius = holeSide / 2;
    [self.centerLabel addSubview:hole];

    CGFloat leftPad = 44;
    self.trackLbl = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, 44, frame.size.width - 220, 30)];
    self.trackLbl.text = _needleCurrentTrackCache[@"name"] ?: @"";
    self.trackLbl.textColor = [UIColor whiteColor];
    self.trackLbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    [self addSubview:self.trackLbl];

    self.artistLbl = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, 78, frame.size.width - 220, 22)];
    self.artistLbl.text = _needleCurrentTrackCache[@"artist"] ?: @"";
    self.artistLbl.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    self.artistLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [self addSubview:self.artistLbl];

    self.rpmLbl = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, frame.size.height - 60, 120, 20)];
    self.rpmLbl.text = @"33⅓ RPM";
    self.rpmLbl.textColor = [UIColor colorWithWhite:1 alpha:0.35];
    self.rpmLbl.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightHeavy];
    [self addSubview:self.rpmLbl];

    self.closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeBtn.frame = CGRectMake(frame.size.width - 60, 40, 44, 44);
    self.closeBtn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.closeBtn.layer.cornerRadius = 22;
    self.closeBtn.layer.borderWidth = 0.5;
    self.closeBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [self.closeBtn setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    self.closeBtn.tintColor = [UIColor whiteColor];
    [self.closeBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.closeBtn];

    CGFloat armLen = side * 0.55;
    CGFloat armX = cx + side * 0.42;
    CGFloat armY = cy - side * 0.44;
    self.tonearm = [[UIView alloc] initWithFrame:CGRectMake(armX - 3, armY, 6, armLen)];
    self.tonearm.backgroundColor = [UIColor colorWithWhite:0.75 alpha:1];
    self.tonearm.layer.cornerRadius = 3;
    self.tonearm.layer.anchorPoint = CGPointMake(0.5, 0);
    self.tonearm.layer.position = CGPointMake(armX, armY);
    self.tonearm.transform = CGAffineTransformMakeRotation(-M_PI / 7);
    UIView *armBase = [[UIView alloc] initWithFrame:CGRectMake(armX - 10, armY - 10, 20, 20)];
    armBase.backgroundColor = [UIColor colorWithWhite:0.5 alpha:1];
    armBase.layer.cornerRadius = 10;
    [self addSubview:armBase];
    [self addSubview:self.tonearm];
    UIView *armTip = [[UIView alloc] initWithFrame:CGRectMake(0, armLen - 14, 6, 14)];
    armTip.backgroundColor = NeedleCurrentColor();
    armTip.layer.cornerRadius = 2;
    [self.tonearm addSubview:armTip];

    self.idleSpeed = 1.0;
    self.spinSpeed = 1.0;
    self.angle = 0;
    self.tick = [CADisplayLink displayLinkWithTarget:self selector:@selector(tickSpin)];
    [self.tick addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.disc addGestureRecognizer:pan];

    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(didPinch:)];
    [self.disc addGestureRecognizer:pinch];

    return self;
}

- (void)tickSpin {
    CGFloat baseStep = 0.0349;
    self.angle += baseStep * self.spinSpeed / 60.0;
    self.disc.transform = CGAffineTransformMakeRotation(self.angle);
    self.spinSpeed = self.spinSpeed * 0.94 + self.idleSpeed * 0.06;
    int rpm = (int)round(33.33 * self.spinSpeed);
    self.rpmLbl.text = [NSString stringWithFormat:@"%d RPM", rpm];
}

- (void)didPan:(UIPanGestureRecognizer *)g {
    CGPoint v = [g velocityInView:self.disc];
    CGFloat mag = sqrt(v.x * v.x + v.y * v.y);
    CGFloat delta = (v.x > 0 || v.y > 0) ? 1.0 : -1.0;
    if (g.state == UIGestureRecognizerStateChanged) {
        self.spinSpeed = MAX(-2.0, MIN(4.0, self.idleSpeed + delta * mag / 1200.0));
    }
    if (g.state == UIGestureRecognizerStateEnded) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
    }
}

- (void)didPinch:(UIPinchGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateChanged) {
        CGFloat s = g.scale;
        self.idleSpeed = MAX(0.4, MIN(2.5, 1.0 * s));
    }
    if (g.state == UIGestureRecognizerStateEnded) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
    }
}

- (void)dismiss {
    [self.tick invalidate];
    self.tick = nil;
    [self removeFromSuperview];
    if (_needleTurntableOverlay == self) _needleTurntableOverlay = nil;
}

- (void)dealloc {
    [_tick invalidate];
}

@end

void NeedleOpenTurntable(void) {
    if (_needleTurntableOverlay) return;
    UIWindow *w = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in ((UIWindowScene *)s).windows) {
                if (win.isKeyWindow) { w = win; break; }
            }
            if (w) break;
        }
    }
    if (!w) return;

    CGRect bounds = w.bounds;
    CGRect landscapeBounds = CGRectMake(0, 0, bounds.size.height, bounds.size.width);
    NeedleTurntableView *view = [[NeedleTurntableView alloc] initWithFrame:landscapeBounds];

    UIDeviceOrientation o = [UIDevice currentDevice].orientation;
    CGFloat rot = (o == UIDeviceOrientationLandscapeRight) ? -M_PI_2 : M_PI_2;
    view.transform = CGAffineTransformMakeRotation(rot);
    view.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
    view.alpha = 0;
    [w addSubview:view];
    [UIView animateWithDuration:0.3 animations:^{ view.alpha = 1; }];
    _needleTurntableOverlay = view;
}

void NeedleCloseTurntable(void) {
    if (!_needleTurntableOverlay) return;
    UIView *v = _needleTurntableOverlay;
    [UIView animateWithDuration:0.2 animations:^{ v.alpha = 0; } completion:^(BOOL f){
        if ([v isKindOfClass:[NeedleTurntableView class]]) [(NeedleTurntableView *)v dismiss];
        else [v removeFromSuperview];
    }];
    _needleTurntableOverlay = nil;
}

extern void NeedleOpenCarMode(void);
extern void NeedleCloseCarMode(void);

%ctor {
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            UIDeviceOrientation o = [UIDevice currentDevice].orientation;
            BOOL playing = (_needleCurrentTrackCache[@"name"] != nil) && [_needleCurrentTrackCache[@"name"] length] > 0;
            if (UIDeviceOrientationIsLandscape(o) && playing) {
                if (NeedlePrefBool(@"CarModeLandscape", NO)) {
                    NeedleCloseTurntable();
                    NeedleOpenCarMode();
                } else if (NeedlePrefBool(@"TurntableLandscape", YES)) {
                    NeedleCloseCarMode();
                    NeedleOpenTurntable();
                }
            } else if (UIDeviceOrientationIsPortrait(o) || o == UIDeviceOrientationPortraitUpsideDown) {
                NeedleCloseTurntable();
                NeedleCloseCarMode();
            }
        }];
}
