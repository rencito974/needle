#import <UIKit/UIKit.h>

extern NSString *NeedlePrefString(NSString *key);
extern void NeedlePrefSetString(NSString *key, NSString *val);
extern UIColor *NeedleCurrentColor(void);

static NSString *const NeedleCurrentVersion = @"2.20.0";
static NSString *const NeedleReleasesAPI = @"https://api.github.com/repos/rencito974/needle/releases/latest";
static NSString *const NeedleIPADownload = @"https://github.com/rencito974/needle/releases/download/latest/Needle-Spotify.ipa";

static NSString *NeedleBundledChangelog(void) {
    return @"Volume boost reworked: Needle now hooks every AVFoundation volume setter (AVAudioMixerNode, AVPlayer, AVAudioPlayer) so whichever audio path Spotify uses, the slider actually applies.\n"
           "Moving the slider now re-applies the boost to the already playing session, no song skip needed.\n"
           "If a track still sounds unchanged at 2x+, your system volume is at the cap already; raise the phone volume to 100 percent and the boost has room to grow.\n"
           "Consolidated build: cache persistence, Car mode, hide tabs, lyric artwork pulse, floating gear + QR + Rating all in one place.";
}

static UIViewController *_NeedleTopVisibleVC(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w.isKeyWindow) { win = w; break; }
            }
            if (win) break;
        }
    }
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

@interface NeedleChangelogSheet : UIViewController
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSString *version;
@end

@implementation NeedleChangelogSheet
- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1.0];
    self.view = root;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;

    CAGradientLayer *bg = [CAGradientLayer layer];
    UIColor *accent = NeedleCurrentColor();
    bg.colors = @[(id)[accent colorWithAlphaComponent:0.35].CGColor, (id)[UIColor colorWithWhite:0.04 alpha:1.0].CGColor];
    bg.locations = @[@0.0, @0.55];
    bg.frame = self.view.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];

    UIView *logo = [[UIView alloc] initWithFrame:CGRectMake(24, 68, 64, 64)];
    logo.backgroundColor = NeedleCurrentColor();
    logo.layer.cornerRadius = 16;
    logo.layer.shadowColor = NeedleCurrentColor().CGColor;
    logo.layer.shadowOffset = CGSizeMake(0, 6);
    logo.layer.shadowRadius = 18;
    logo.layer.shadowOpacity = 0.6;
    UIImageView *logoIcon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"sparkles" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]]];
    logoIcon.tintColor = [UIColor whiteColor];
    logoIcon.contentMode = UIViewContentModeCenter;
    logoIcon.frame = logo.bounds;
    [logo addSubview:logoIcon];
    [self.view addSubview:logo];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 150, w - 48, 36)];
    title.text = @"What's new";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(24, 188, w - 48, 20)];
    ver.text = [NSString stringWithFormat:@"Needle %@", self.version];
    ver.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    ver.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [self.view addSubview:ver];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, 230, w, self.view.bounds.size.height - 310)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    NSArray *lines = [self.body componentsSeparatedByString:@"\n"];
    CGFloat y = 8;
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!line.length) continue;

        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(24, y, w - 48, 44)];

        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 10, 6, 6)];
        dot.backgroundColor = NeedleCurrentColor();
        dot.layer.cornerRadius = 3;
        [row addSubview:dot];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(18, 0, w - 48 - 18, 44)];
        lbl.text = line;
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];
        lbl.numberOfLines = 0;
        [lbl sizeToFit];
        CGRect f = lbl.frame;
        f.size.width = w - 48 - 18;
        f.origin.x = 18;
        f.origin.y = 0;
        lbl.frame = f;
        [row addSubview:lbl];

        CGFloat rowH = MAX(24, lbl.frame.size.height) + 14;
        row.frame = CGRectMake(24, y, w - 48, rowH);
        [scroll addSubview:row];
        y += rowH;
    }
    scroll.contentSize = CGSizeMake(w, y + 20);

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.frame = CGRectMake(24, self.view.bounds.size.height - 72, w - 48, 54);
    done.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    done.backgroundColor = NeedleCurrentColor();
    done.layer.cornerRadius = 16;
    [done setTitle:@"Continue" forState:UIControlStateNormal];
    [done setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [done addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:done];
}
- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

static void NeedleShowChangelogSheet(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = _NeedleTopVisibleVC();
        if (!top) return;
        NeedleChangelogSheet *sheet = [NeedleChangelogSheet new];
        sheet.version = NeedleCurrentVersion;
        sheet.body = NeedleBundledChangelog();
        sheet.modalPresentationStyle = UIModalPresentationFullScreen;
        [top presentViewController:sheet animated:YES completion:^{
            NeedlePrefSetString(@"ChangelogSeenVersion", NeedleCurrentVersion);
        }];
    });
}

static void NeedleFetchAndShowChangelog(BOOL force) {
    NSString *lastSeen = NeedlePrefString(@"ChangelogSeenVersion");
    if (!force && [lastSeen isEqualToString:NeedleCurrentVersion]) return;
    NeedleShowChangelogSheet();
}

void NeedleShowChangelogNow(void) {
    NeedleShowChangelogSheet();
}

static void NeedleCheckForNewerBuild(void) {
    NSURL *url = [NSURL URLWithString:NeedleReleasesAPI];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
            if (!data) return;
            NSError *jerr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jerr];
            if (!json || jerr) return;
            NSArray *assets = json[@"assets"];
            if (![assets isKindOfClass:[NSArray class]]) return;
            NSNumber *size = nil;
            NSString *updatedAt = nil;
            for (NSDictionary *a in assets) {
                NSString *name = a[@"name"];
                if ([name isEqualToString:@"Needle-Spotify.ipa"]) {
                    size = a[@"size"];
                    updatedAt = a[@"updated_at"];
                    break;
                }
            }
            if (!updatedAt) return;
            NSString *lastSeen = NeedlePrefString(@"LatestBuildTimestamp");
            if ([lastSeen isEqualToString:updatedAt]) return;
            NSString *firstSeen = NeedlePrefString(@"CurrentBuildTimestamp");
            if (!firstSeen.length) {
                NeedlePrefSetString(@"CurrentBuildTimestamp", updatedAt);
                return;
            }
            if ([updatedAt compare:firstSeen] != NSOrderedDescending) return;

            dispatch_async(dispatch_get_main_queue(), ^{
                UIViewController *top = _NeedleTopVisibleVC();
                if (!top) return;
                NSString *msg = [NSString stringWithFormat:@"A newer Needle build is up on GitHub (%@). Open it in Gbox to update in place.", updatedAt];
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Needle update ready" message:msg preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"Download" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NeedleIPADownload] options:@{} completionHandler:nil];
                    NeedlePrefSetString(@"LatestBuildTimestamp", updatedAt);
                }]];
                [a addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:^(UIAlertAction *_){
                    NeedlePrefSetString(@"LatestBuildTimestamp", updatedAt);
                }]];
                [top presentViewController:a animated:YES completion:nil];
            });
        }];
    [t resume];
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleFetchAndShowChangelog(NO);
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleCheckForNewerBuild();
            });
        }];
}
