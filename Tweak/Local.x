#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

extern UIColor *NeedleCurrentColor(void);

@interface NeedleLocalPlayerViewController : UIViewController <UIDocumentPickerDelegate, AVAudioPlayerDelegate>
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) UILabel *nowPlaying;
@property (nonatomic, strong) UIProgressView *progress;
@property (nonatomic, strong) UIButton *playPause;
@property (nonatomic, strong) NSTimer *ticker;
@end

@implementation NeedleLocalPlayerViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.3].CGColor, (id)[UIColor blackColor].CGColor];
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
    title.text = @"Local music";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    self.nowPlaying = [[UILabel alloc] initWithFrame:CGRectMake(20, h / 2 - 60, w - 40, 60)];
    self.nowPlaying.text = @"Nothing loaded";
    self.nowPlaying.textColor = [UIColor whiteColor];
    self.nowPlaying.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    self.nowPlaying.textAlignment = NSTextAlignmentCenter;
    self.nowPlaying.numberOfLines = 2;
    [self.view addSubview:self.nowPlaying];

    self.progress = [[UIProgressView alloc] initWithFrame:CGRectMake(40, h / 2 + 20, w - 80, 4)];
    self.progress.progressTintColor = NeedleCurrentColor();
    self.progress.trackTintColor = [UIColor colorWithWhite:1 alpha:0.15];
    [self.view addSubview:self.progress];

    self.playPause = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playPause.frame = CGRectMake(w / 2 - 36, h / 2 + 50, 72, 72);
    self.playPause.backgroundColor = [UIColor whiteColor];
    self.playPause.layer.cornerRadius = 36;
    [self.playPause setImage:[UIImage systemImageNamed:@"play.fill"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.playPause.tintColor = [UIColor blackColor];
    [self.playPause addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playPause];

    UIButton *pick = [UIButton buttonWithType:UIButtonTypeSystem];
    pick.frame = CGRectMake(40, h - 120, w - 80, 54);
    pick.backgroundColor = NeedleCurrentColor();
    pick.layer.cornerRadius = 16;
    [pick setTitle:@"Pick an audio file" forState:UIControlStateNormal];
    [pick setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    pick.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [pick addTarget:self action:@selector(pickFile) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pick];
}

- (void)pickFile {
    UIDocumentPickerViewController *dp = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:@[@"public.audio"] inMode:UIDocumentPickerModeImport];
    dp.delegate = self;
    [self presentViewController:dp animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)c didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *u = urls.firstObject;
    if (!u) return;
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:u error:&err];
    if (err) {
        self.nowPlaying.text = err.localizedDescription;
        return;
    }
    self.player.delegate = self;
    [self.player prepareToPlay];
    [self.player play];
    self.nowPlaying.text = u.lastPathComponent;
    [self.playPause setImage:[UIImage systemImageNamed:@"pause.fill"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    [self.ticker invalidate];
    __weak typeof(self) weak = self;
    self.ticker = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        if (!weak.player.duration) return;
        weak.progress.progress = weak.player.currentTime / weak.player.duration;
    }];
}

- (void)togglePlay {
    if (!self.player) return;
    if (self.player.isPlaying) {
        [self.player pause];
        [self.playPause setImage:[UIImage systemImageNamed:@"play.fill"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    } else {
        [self.player play];
        [self.playPause setImage:[UIImage systemImageNamed:@"pause.fill"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    }
}

- (void)dismissSelf {
    [self.player stop];
    [self.ticker invalidate];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

void NeedleOpenLocalPlayer(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleLocalPlayerViewController *vc = [NeedleLocalPlayerViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
