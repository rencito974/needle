#import <UIKit/UIKit.h>

extern NSString *NeedlePrefString(NSString *key);
extern void NeedlePrefSetString(NSString *key, NSString *val);
extern UIColor *NeedleCurrentColor(void);

static NSString *const NeedleCurrentVersion = @"2.32.0";
static NSString *const NeedleReleasesAPI = @"https://api.github.com/repos/rencito974/needle/releases/latest";
static NSString *const NeedleIPADownload = @"https://github.com/rencito974/needle/releases/download/latest/Needle-Spotify.ipa";

static NSString *NeedleBundledChangelog(void) {
    return @"Lockscreen tap another attempt: stripped every Needle override of the Now Playing info identifiers. No ExternalContentIdentifier, no ExternalUserProfileIdentifier, no ServiceIdentifier, no AssetURL rewrite. Pair this with the OG bundle build and the real Spotify's own tap-to-open path should be untouched.";
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
    root.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1.0];
    self.view = root;
}

static NSString *_NeedleIconForLine(NSString *line) {
    NSString *l = [line lowercaseString];
    if ([l containsString:@"settings"] || [l containsString:@"regram"] || [l containsString:@"card"]) return @"slider.horizontal.3";
    if ([l containsString:@"about"]) return @"info.circle.fill";
    if ([l containsString:@"privacy"] || [l containsString:@"hide"] || [l containsString:@"captur"]) return @"eye.slash.fill";
    if ([l containsString:@"playlist"] || [l containsString:@"clone"]) return @"square.on.square";
    if ([l containsString:@"queue"]) return @"line.3.horizontal.decrease.circle.fill";
    if ([l containsString:@"volume"] || [l containsString:@"boost"]) return @"speaker.wave.2.fill";
    if ([l containsString:@"recognize"]) return @"waveform.badge.magnifyingglass";
    if ([l containsString:@"lyric"]) return @"text.quote";
    if ([l containsString:@"car"]) return @"car.fill";
    if ([l containsString:@"turntable"]) return @"opticaldisc";
    if ([l containsString:@"rate"] || [l containsString:@"rating"]) return @"star.fill";
    if ([l containsString:@"album"]) return @"square.grid.2x2.fill";
    return @"sparkle";
}

static NSString *_NeedleTitleForLine(NSString *line, NSString **outBody) {
    NSRange colonRange = [line rangeOfString:@":"];
    if (colonRange.location == NSNotFound) {
        if (outBody) *outBody = line;
        return @"New";
    }
    NSString *head = [[line substringToIndex:colonRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *tail = [[line substringFromIndex:colonRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (outBody) *outBody = tail.length ? tail : head;
    return head.length ? head : @"New";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    UIColor *accent = NeedleCurrentColor();

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[accent colorWithAlphaComponent:0.45].CGColor,
                  (id)[accent colorWithAlphaComponent:0.08].CGColor,
                  (id)[UIColor colorWithWhite:0.03 alpha:1.0].CGColor];
    bg.locations = @[@0.0, @0.28, @0.6];
    bg.frame = self.view.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];

    for (NSInteger i = 0; i < 5; i++) {
        CAShapeLayer *blob = [CAShapeLayer layer];
        CGFloat size = 160 + (i * 22);
        CGPoint c = CGPointMake(w - 60 + i * 6, 110 - i * 2);
        UIBezierPath *p = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(c.x - size/2, c.y - size/2, size, size)];
        blob.path = p.CGPath;
        blob.fillColor = [UIColor clearColor].CGColor;
        blob.strokeColor = [[accent colorWithAlphaComponent:0.18 - i * 0.03] CGColor];
        blob.lineWidth = 1.0;
        [self.view.layer addSublayer:blob];
    }

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 56, 58, 36, 36);
    close.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    close.layer.cornerRadius = 18;
    close.layer.borderWidth = 0.5;
    close.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UIView *logo = [[UIView alloc] initWithFrame:CGRectMake(24, 80, 72, 72)];
    logo.backgroundColor = accent;
    logo.layer.cornerRadius = 20;
    logo.layer.shadowColor = accent.CGColor;
    logo.layer.shadowOffset = CGSizeMake(0, 10);
    logo.layer.shadowRadius = 22;
    logo.layer.shadowOpacity = 0.75;
    UIImageView *logoIcon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"sparkles" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightBold]]];
    logoIcon.tintColor = [UIColor whiteColor];
    logoIcon.contentMode = UIViewContentModeCenter;
    logoIcon.frame = logo.bounds;
    [logo addSubview:logoIcon];
    [self.view addSubview:logo];

    CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    breathe.fromValue = @0.96;
    breathe.toValue = @1.04;
    breathe.duration = 2.0;
    breathe.autoreverses = YES;
    breathe.repeatCount = HUGE_VALF;
    breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [logo.layer addAnimation:breathe forKey:@"breathe"];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 170, w - 48, 44)];
    title.text = @"What's new";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:36 weight:UIFontWeightBlack];
    [self.view addSubview:title];

    UIView *verPill = [[UIView alloc] initWithFrame:CGRectMake(24, 220, 120, 26)];
    verPill.backgroundColor = [accent colorWithAlphaComponent:0.2];
    verPill.layer.cornerRadius = 13;
    verPill.layer.borderWidth = 0.5;
    verPill.layer.borderColor = [accent colorWithAlphaComponent:0.6].CGColor;
    UILabel *verLbl = [[UILabel alloc] initWithFrame:verPill.bounds];
    verLbl.text = [NSString stringWithFormat:@"Needle %@", self.version];
    verLbl.textColor = [UIColor whiteColor];
    verLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    verLbl.textAlignment = NSTextAlignmentCenter;
    [verPill addSubview:verLbl];
    CGSize sz = [verLbl.text sizeWithAttributes:@{NSFontAttributeName: verLbl.font}];
    CGRect vp = verPill.frame;
    vp.size.width = sz.width + 22;
    verPill.frame = vp;
    verLbl.frame = verPill.bounds;
    [self.view addSubview:verPill];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, 268, w, h - 268 - 96)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.contentInset = UIEdgeInsetsMake(8, 0, 20, 0);
    [self.view addSubview:scroll];

    NSArray *lines = [self.body componentsSeparatedByString:@"\n"];
    CGFloat y = 0;
    NSInteger idx = 0;
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!line.length) continue;

        NSString *body = nil;
        NSString *head = _NeedleTitleForLine(line, &body);
        NSString *sym = _NeedleIconForLine(line);

        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, y, w - 40, 88)];
        card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
        card.layer.cornerRadius = 18;
        card.layer.borderWidth = 0.5;
        card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;

        UIView *iconBg = [[UIView alloc] initWithFrame:CGRectMake(16, 16, 44, 44)];
        iconBg.backgroundColor = [accent colorWithAlphaComponent:0.22];
        iconBg.layer.cornerRadius = 12;
        iconBg.layer.borderWidth = 0.5;
        iconBg.layer.borderColor = [accent colorWithAlphaComponent:0.55].CGColor;
        UIImageView *iv = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:sym withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]]];
        iv.tintColor = [UIColor whiteColor];
        iv.contentMode = UIViewContentModeCenter;
        iv.frame = iconBg.bounds;
        [iconBg addSubview:iv];
        [card addSubview:iconBg];

        UILabel *headLbl = [[UILabel alloc] initWithFrame:CGRectMake(72, 12, w - 40 - 86, 22)];
        headLbl.text = head;
        headLbl.textColor = [UIColor whiteColor];
        headLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        [card addSubview:headLbl];

        UILabel *bodyLbl = [[UILabel alloc] initWithFrame:CGRectMake(72, 34, w - 40 - 86, 48)];
        bodyLbl.text = body ?: line;
        bodyLbl.textColor = [UIColor colorWithWhite:1 alpha:0.65];
        bodyLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        bodyLbl.numberOfLines = 0;
        [bodyLbl sizeToFit];
        CGRect bf = bodyLbl.frame;
        bf.size.width = w - 40 - 86;
        bf.origin.x = 72;
        bf.origin.y = 34;
        bodyLbl.frame = bf;
        [card addSubview:bodyLbl];

        CGFloat cardH = MAX(76, bodyLbl.frame.size.height + 50);
        card.frame = CGRectMake(20, y, w - 40, cardH);
        [scroll addSubview:card];

        card.alpha = 0;
        card.transform = CGAffineTransformMakeTranslation(0, 14);
        [UIView animateWithDuration:0.42 delay:0.08 + idx * 0.06 usingSpringWithDamping:0.9 initialSpringVelocity:0.7 options:0 animations:^{
            card.alpha = 1;
            card.transform = CGAffineTransformIdentity;
        } completion:nil];

        y += cardH + 10;
        idx++;
    }
    scroll.contentSize = CGSizeMake(w, y + 20);

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.frame = CGRectMake(24, h - 80, w - 48, 56);
    done.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    done.backgroundColor = accent;
    done.layer.cornerRadius = 18;
    done.layer.shadowColor = accent.CGColor;
    done.layer.shadowOffset = CGSizeMake(0, 8);
    done.layer.shadowRadius = 20;
    done.layer.shadowOpacity = 0.55;
    [done setTitle:@"Continue" forState:UIControlStateNormal];
    [done setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [done addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:done];
}
- (void)dismissSelf {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    [self dismissViewControllerAnimated:YES completion:nil];
}
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
