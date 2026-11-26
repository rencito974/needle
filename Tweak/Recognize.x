#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

extern UIColor *NeedleCurrentColor(void);

@class SHSession;
@class SHMediaItem;
@class SHSignatureGenerator;
@protocol SHSessionDelegate;

@interface NeedleRecognizeViewController : UIViewController
@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) id session;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UILabel *result;
@end

@implementation NeedleRecognizeViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.35].CGColor, (id)[UIColor blackColor].CGColor];
    bg.locations = @[@0.0, @0.5];
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
    close.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    close.layer.cornerRadius = 18;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 60, w - 100, 40)];
    title.text = @"Recognize";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UIImageView *orb = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"waveform.circle.fill" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:140 weight:UIImageSymbolWeightThin]]];
    orb.tintColor = NeedleCurrentColor();
    orb.frame = CGRectMake(w / 2 - 70, h / 2 - 120, 140, 140);
    [self.view addSubview:orb];

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @0.9;
    pulse.toValue = @1.1;
    pulse.duration = 1.0;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [orb.layer addAnimation:pulse forKey:@"pulse"];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(20, h / 2 + 40, w - 40, 30)];
    self.status.text = @"Listening…";
    self.status.textColor = [UIColor whiteColor];
    self.status.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.status];

    self.result = [[UILabel alloc] initWithFrame:CGRectMake(20, h / 2 + 80, w - 40, 60)];
    self.result.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    self.result.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.result.textAlignment = NSTextAlignmentCenter;
    self.result.numberOfLines = 0;
    [self.view addSubview:self.result];

    [self start];
}

- (void)start {
    Class SHSessionCls = NSClassFromString(@"SHSession");
    if (!SHSessionCls) {
        self.status.text = @"Not available";
        self.result.text = @"ShazamKit requires iOS 15 or newer.";
        return;
    }
    @try {
        self.session = [[SHSessionCls alloc] init];
        [self.session setValue:self forKey:@"delegate"];
    } @catch (NSException *e) {
        self.status.text = @"Can't start";
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
    }];
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionMixWithOthers error:&err];
    [self.engine prepare];
    [self.engine startAndReturnError:&err];
    if (err) {
        self.status.text = @"Mic denied";
        self.result.text = err.localizedDescription;
    }
}

- (void)session:(id)s didFindMatch:(id)match {
    NSArray *items = [match valueForKey:@"mediaItems"];
    id first = items.firstObject;
    NSString *title = [first valueForKey:@"title"];
    NSString *artist = [first valueForKey:@"artist"];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.status.text = title ?: @"Unknown";
        self.result.text = artist ?: @"";
        [self stopEngine];
    });
}

- (void)session:(id)s didNotFindMatchForSignature:(id)sig error:(NSError *)err {}

- (void)stopEngine {
    [self.engine stop];
    [self.engine.inputNode removeTapOnBus:0];
}

- (void)dismissSelf {
    [self stopEngine];
    [self dismissViewControllerAnimated:YES completion:nil];
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
