#import <UIKit/UIKit.h>

extern UIColor *NeedleCurrentColor(void);
extern NSMutableDictionary *_needleCurrentTrackCache;

static NSString *NeedleRatingPath(void) {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"NeedleRatings.plist"];
}

static NSMutableDictionary *NeedleReadRatings(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:NeedleRatingPath()];
    return d ? [d mutableCopy] : [NSMutableDictionary new];
}

static void NeedleSaveRating(NSString *uri, NSInteger rating, NSString *name, NSString *artist) {
    if (!uri.length) return;
    NSMutableDictionary *all = NeedleReadRatings();
    all[uri] = @{
        @"rating": @(rating),
        @"name": name ?: @"",
        @"artist": artist ?: @"",
        @"when": @([[NSDate date] timeIntervalSince1970]),
    };
    [all writeToFile:NeedleRatingPath() atomically:YES];
}

NSInteger NeedleRatingFor(NSString *uri) {
    if (!uri.length) return 0;
    NSMutableDictionary *all = NeedleReadRatings();
    return [all[uri][@"rating"] integerValue];
}

@interface NeedleRatingVC : UIViewController
@property (nonatomic, strong) NSMutableArray *padButtons;
@property (nonatomic, strong) UILabel *summaryLbl;
@end

@implementation NeedleRatingVC

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.3].CGColor, (id)[UIColor blackColor].CGColor];
    bg.locations = @[@0.0, @0.55];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(w - 60, 60, 42, 42);
    close.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    close.layer.cornerRadius = 21;
    close.layer.borderWidth = 0.5;
    close.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(22, 60, w - 80, 36)];
    title.text = @"Rate";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBlack];
    [self.view addSubview:title];

    UILabel *song = [[UILabel alloc] initWithFrame:CGRectMake(22, 108, w - 44, 28)];
    song.text = _needleCurrentTrackCache[@"name"] ?: @"Nothing playing";
    song.textColor = [UIColor whiteColor];
    song.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.view addSubview:song];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(22, 138, w - 44, 20)];
    artist.text = _needleCurrentTrackCache[@"artist"] ?: @"";
    artist.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    artist.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.view addSubview:artist];

    NSString *uri = _needleCurrentTrackCache[@"uri"];
    NSInteger cur = NeedleRatingFor(uri);

    self.padButtons = [NSMutableArray new];
    CGFloat pad = 12;
    CGFloat cellSize = (w - 44 - pad * 4) / 5.0;
    CGFloat gridY = 200;
    for (NSInteger i = 1; i <= 10; i++) {
        NSInteger row = (i - 1) / 5;
        NSInteger ccol = (i - 1) % 5;
        CGFloat x = 22 + ccol * (cellSize + pad);
        CGFloat y = gridY + row * (cellSize + pad);
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, cellSize, cellSize);
        BOOL isCur = (i == cur);
        btn.backgroundColor = isCur ? NeedleCurrentColor() : [UIColor colorWithWhite:0.08 alpha:1];
        btn.layer.cornerRadius = cellSize * 0.24;
        btn.layer.borderWidth = isCur ? 0 : 0.5;
        btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
        [btn setTitle:[NSString stringWithFormat:@"%ld", (long)i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:cellSize * 0.42 weight:UIFontWeightBlack];
        btn.tag = i;
        [btn addTarget:self action:@selector(didRate:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
        [self.padButtons addObject:btn];
    }

    NSInteger total = NeedleReadRatings().count;
    self.summaryLbl = [[UILabel alloc] initWithFrame:CGRectMake(22, h - 140, w - 44, 60)];
    self.summaryLbl.text = [NSString stringWithFormat:@"%ld song%@ rated so far. Tap fast, rate often. Needle weighs ratings when building Discover mixes.",
        (long)total, total == 1 ? @"" : @"s"];
    self.summaryLbl.textColor = [UIColor colorWithWhite:1 alpha:0.42];
    self.summaryLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.summaryLbl.numberOfLines = 0;
    [self.view addSubview:self.summaryLbl];
}

- (void)didRate:(UIButton *)btn {
    NSInteger r = btn.tag;
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
    NSString *uri = _needleCurrentTrackCache[@"uri"];
    NSString *name = _needleCurrentTrackCache[@"name"];
    NSString *artist = _needleCurrentTrackCache[@"artist"];
    if (!uri.length) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"No track" message:@"Play something first to rate it." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NeedleSaveRating(uri, r, name, artist);
    for (UIButton *b in self.padButtons) {
        BOOL isCur = (b.tag == r);
        [UIView animateWithDuration:0.15 animations:^{
            b.backgroundColor = isCur ? NeedleCurrentColor() : [UIColor colorWithWhite:0.08 alpha:1];
            b.layer.borderWidth = isCur ? 0 : 0.5;
            b.transform = isCur ? CGAffineTransformMakeScale(1.08, 1.08) : CGAffineTransformIdentity;
        } completion:^(BOOL f) {
            if (isCur) {
                [UIView animateWithDuration:0.15 animations:^{
                    b.transform = CGAffineTransformIdentity;
                }];
            }
        }];
    }
    NSInteger total = NeedleReadRatings().count;
    self.summaryLbl.text = [NSString stringWithFormat:@"%ld song%@ rated so far. Tap fast, rate often. Needle weighs ratings when building Discover mixes.",
        (long)total, total == 1 ? @"" : @"s"];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void NeedleOpenRating(void) {
    UIWindow *w = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in ((UIWindowScene *)s).windows) if (win.isKeyWindow) { w = win; break; }
            if (w) break;
        }
    }
    UIViewController *top = w.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleRatingVC *vc = [NeedleRatingVC new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
