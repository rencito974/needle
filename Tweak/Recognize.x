#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

extern UIColor *NeedleCurrentColor(void);

@class SHSession;

@interface NeedleRecognizeViewController : UIViewController
@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) id session;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UILabel *dots;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UILabel *result;
@property (nonatomic, strong) UIView *orbContainer;
@property (nonatomic, strong) NSArray<UIView *> *bars;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *ripples;
@property (nonatomic, assign) float smoothLevel;
@property (nonatomic, assign) BOOL stopped;
@property (nonatomic, assign) BOOL matched;
@property (nonatomic, assign) NSInteger dotPhase;
@property (nonatomic, strong) NSDate *startedAt;
@property (nonatomic, strong) NSTimer *tick;
@end

@implementation NeedleRecognizeViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.40].CGColor,
                  (id)[NeedleCurrentColor() colorWithAlphaComponent:0.08].CGColor,
                  (id)[UIColor blackColor].CGColor];
    bg.locations = @[@0.0, @0.35, @0.7];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 56, 58, 36, 36);
    close.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    close.layer.cornerRadius = 18;
    close.layer.borderWidth = 0.5;
    close.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 60, w - 100, 40)];
    title.text = @"Recognize";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(24, 100, w - 100, 20)];
    sub.text = @"Point your phone at the music";
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.view addSubview:sub];

    CGFloat orbSize = 220;
    CGFloat orbY = h / 2 - orbSize / 2 - 20;
    self.orbContainer = [[UIView alloc] initWithFrame:CGRectMake(w / 2 - orbSize / 2, orbY, orbSize, orbSize)];
    [self.view addSubview:self.orbContainer];

    NSMutableArray *ripArr = [NSMutableArray new];
    for (NSInteger i = 0; i < 3; i++) {
        CAShapeLayer *ring = [CAShapeLayer layer];
        UIBezierPath *p = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(orbSize / 2 - 50, orbSize / 2 - 50, 100, 100)];
        ring.path = p.CGPath;
        ring.fillColor = [UIColor clearColor].CGColor;
        ring.strokeColor = [NeedleCurrentColor() colorWithAlphaComponent:0.45].CGColor;
        ring.lineWidth = 2.0;
        ring.opacity = 0;
        [self.orbContainer.layer addSublayer:ring];
        [ripArr addObject:ring];

        CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scale.fromValue = @0.6;
        scale.toValue = @1.9;
        scale.duration = 2.4;
        scale.repeatCount = HUGE_VALF;
        scale.beginTime = CACurrentMediaTime() + i * 0.8;
        scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [ring addAnimation:scale forKey:@"scale"];

        CAKeyframeAnimation *op = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        op.values = @[@0.0, @0.9, @0.0];
        op.keyTimes = @[@0.0, @0.15, @1.0];
        op.duration = 2.4;
        op.repeatCount = HUGE_VALF;
        op.beginTime = CACurrentMediaTime() + i * 0.8;
        [ring addAnimation:op forKey:@"op"];
    }
    self.ripples = ripArr;

    UIView *coreGlow = [[UIView alloc] initWithFrame:CGRectMake(orbSize / 2 - 72, orbSize / 2 - 72, 144, 144)];
    coreGlow.backgroundColor = NeedleCurrentColor();
    coreGlow.layer.cornerRadius = 72;
    coreGlow.layer.shadowColor = NeedleCurrentColor().CGColor;
    coreGlow.layer.shadowOffset = CGSizeZero;
    coreGlow.layer.shadowRadius = 44;
    coreGlow.layer.shadowOpacity = 0.9;
    [self.orbContainer addSubview:coreGlow];

    CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breathe.fromValue = @0.94;
    breathe.toValue = @1.06;
    breathe.duration = 1.1;
    breathe.autoreverses = YES;
    breathe.repeatCount = HUGE_VALF;
    breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [coreGlow.layer addAnimation:breathe forKey:@"breathe"];

    NSMutableArray *barArr = [NSMutableArray new];
    CGFloat barW = 6, barGap = 6;
    NSInteger barCount = 7;
    CGFloat barTotalW = barCount * barW + (barCount - 1) * barGap;
    for (NSInteger i = 0; i < barCount; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(
            orbSize / 2 - barTotalW / 2 + i * (barW + barGap),
            orbSize / 2 - 8,
            barW, 16)];
        bar.backgroundColor = [UIColor whiteColor];
        bar.layer.cornerRadius = barW / 2;
        [coreGlow addSubview:bar];
        [barArr addObject:bar];
    }
    self.bars = barArr;

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(20, orbY + orbSize + 32, w - 40, 30)];
    self.status.text = @"Listening";
    self.status.textColor = [UIColor whiteColor];
    self.status.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.status.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.status];

    self.dots = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 40, 30)];
    self.dots.textColor = [UIColor whiteColor];
    self.dots.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.dots.text = @"";
    self.dots.textAlignment = NSTextAlignmentLeft;

    self.hint = [[UILabel alloc] initWithFrame:CGRectMake(20, orbY + orbSize + 70, w - 40, 20)];
    self.hint.text = @"Give it a few seconds";
    self.hint.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    self.hint.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.hint.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.hint];

    self.result = [[UILabel alloc] initWithFrame:CGRectMake(20, orbY + orbSize + 100, w - 40, 60)];
    self.result.textColor = [UIColor colorWithWhite:1 alpha:0.75];
    self.result.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.result.textAlignment = NSTextAlignmentCenter;
    self.result.numberOfLines = 0;
    [self.view addSubview:self.result];

    self.smoothLevel = 0.1f;
    self.startedAt = [NSDate date];
    self.tick = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
        target:self selector:@selector(onTick) userInfo:nil repeats:YES];
    [self start];
}

- (void)onTick {
    if (self.matched || self.stopped) return;
    float level = self.smoothLevel;
    for (NSInteger i = 0; i < self.bars.count; i++) {
        UIView *bar = self.bars[i];
        CGFloat phase = CACurrentMediaTime() * 4.0 + i * 0.7;
        CGFloat wobble = 0.6 + 0.4 * (sinf((float)phase) * 0.5f + 0.5f);
        CGFloat targetH = 6 + level * 46 * wobble;
        CGRect f = bar.frame;
        CGFloat midY = 110;
        f.size.height = targetH;
        f.origin.y = midY - targetH / 2;
        bar.frame = f;
    }
    self.smoothLevel *= 0.96f;
    if (self.smoothLevel < 0.08f) self.smoothLevel = 0.08f;

    NSTimeInterval elapsed = -[self.startedAt timeIntervalSinceNow];
    NSInteger phase = ((NSInteger)(elapsed * 2.5)) % 4;
    if (phase != self.dotPhase) {
        self.dotPhase = phase;
        NSArray *strings = @[@"", @".", @"..", @"..."];
        self.status.text = [NSString stringWithFormat:@"Listening%@", strings[phase]];
    }
    if (elapsed > 8 && elapsed < 9) {
        self.hint.text = @"Getting closer…";
    } else if (elapsed > 18 && elapsed < 19) {
        self.hint.text = @"Still searching, keep it steady";
    } else if (elapsed > 30 && elapsed < 31) {
        self.hint.text = @"Try getting closer to the speaker";
    }
}

- (void)start {
    Class SHSessionCls = NSClassFromString(@"SHSession");
    if (!SHSessionCls) {
        self.status.text = @"Not available";
        self.hint.text = @"";
        self.result.text = @"ShazamKit requires iOS 15 or newer.";
        return;
    }
    @try {
        self.session = [[SHSessionCls alloc] init];
        [self.session setValue:self forKey:@"delegate"];
    } @catch (NSException *e) {
        self.status.text = @"Can't start";
        self.hint.text = @"";
        self.result.text = e.reason ?: @"ShazamKit refused to start.";
        return;
    }

    self.engine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *input = self.engine.inputNode;
    AVAudioFormat *fmt = [input outputFormatForBus:0];
    __weak typeof(self) weak = self;
    [input installTapOnBus:0 bufferSize:2048 format:fmt block:^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
        @try {
            [weak.session performSelector:@selector(matchStreamingBuffer:atTime:) withObject:buf withObject:when];
        } @catch (NSException *e) {}

        float peak = 0;
        if (buf.floatChannelData && buf.frameLength > 0) {
            float *ch = buf.floatChannelData[0];
            AVAudioFrameCount len = buf.frameLength;
            float sq = 0;
            for (AVAudioFrameCount i = 0; i < len; i++) sq += ch[i] * ch[i];
            float rms = sqrtf(sq / (float)len);
            peak = fminf(1.0f, rms * 3.5f);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weak) return;
            weak.smoothLevel = MAX(weak.smoothLevel * 0.6f + peak * 0.4f, 0.08f);
        });
    }];
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionMixWithOthers error:&err];
    [self.engine prepare];
    [self.engine startAndReturnError:&err];
    if (err) {
        self.status.text = @"Mic denied";
        self.hint.text = @"";
        self.result.text = err.localizedDescription;
    }
}

- (void)session:(id)s didFindMatch:(id)match {
    NSArray *items = [match valueForKey:@"mediaItems"];
    id first = items.firstObject;
    NSString *title = [first valueForKey:@"title"];
    NSString *artist = [first valueForKey:@"artist"];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.matched = YES;
        UINotificationFeedbackGenerator *fb = [UINotificationFeedbackGenerator new];
        [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
        self.status.text = title ?: @"Match";
        self.hint.text = artist ?: @"";
        self.result.text = @"";
        for (CAShapeLayer *ring in self.ripples) [ring removeAllAnimations];
        for (UIView *bar in self.bars) {
            [UIView animateWithDuration:0.35 animations:^{
                CGRect f = bar.frame;
                f.size.height = 32;
                f.origin.y = 110 - 16;
                bar.frame = f;
            }];
        }
        [self stopEngine];
    });
}

- (void)session:(id)s didNotFindMatchForSignature:(id)sig error:(NSError *)err {}

- (void)stopEngine {
    self.stopped = YES;
    [self.tick invalidate];
    self.tick = nil;
    @try { [self.engine stop]; } @catch (NSException *e) {}
    @try { [self.engine.inputNode removeTapOnBus:0]; } @catch (NSException *e) {}
}

- (void)dismissSelf {
    [self stopEngine];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [self.tick invalidate];
}

@end

void NeedleOpenRecognize(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleRecognizeViewController *vc = [NeedleRecognizeViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
