#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern NSString *NeedlePrefString(NSString *key);
extern void NeedlePrefSetBool(NSString *key, BOOL val);
extern void NeedlePrefSetString(NSString *key, NSString *val);
extern UIColor *NeedleCurrentColor(void);

typedef NS_ENUM(NSInteger, NeedleRowKind) {
    NeedleRowSwitch,
    NeedleRowText,
    NeedleRowButton,
    NeedleRowFooter,
};

@interface NeedleRow : NSObject
@property (nonatomic, assign) NeedleRowKind kind;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, assign) BOOL defaultBool;
@property (nonatomic, copy) void (^action)(void);
@end

@implementation NeedleRow
+ (instancetype)sw:(NSString *)label key:(NSString *)key def:(BOOL)def symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowSwitch;
    r.label = label;
    r.prefKey = key;
    r.defaultBool = def;
    r.symbol = sym;
    return r;
}
+ (instancetype)sw:(NSString *)label key:(NSString *)key def:(BOOL)def {
    return [self sw:label key:key def:def symbol:nil];
}
+ (instancetype)text:(NSString *)label key:(NSString *)key placeholder:(NSString *)ph symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowText;
    r.label = label;
    r.prefKey = key;
    r.placeholder = ph;
    r.symbol = sym;
    return r;
}
+ (instancetype)text:(NSString *)label key:(NSString *)key placeholder:(NSString *)ph {
    return [self text:label key:key placeholder:ph symbol:nil];
}
+ (instancetype)button:(NSString *)label action:(void (^)(void))action symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowButton;
    r.label = label;
    r.action = action;
    r.symbol = sym;
    return r;
}
+ (instancetype)button:(NSString *)label action:(void (^)(void))action {
    return [self button:label action:action symbol:nil];
}
+ (instancetype)footer:(NSString *)text {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowFooter;
    r.label = text;
    return r;
}
@end

@interface NeedleSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSArray<NeedleRow *> *rows;
@property (nonatomic, copy) NSString *footer;
@end
@implementation NeedleSection
@end

@interface NeedleSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<NeedleSection *> *sections;
@property (nonatomic, strong) CAGradientLayer *bgLayer;
@end

@implementation NeedleSettingsViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1.0];
    self.bgLayer = [CAGradientLayer layer];
    UIColor *accent = NeedleCurrentColor();
    UIColor *top = [accent colorWithAlphaComponent:0.45];
    UIColor *mid = [accent colorWithAlphaComponent:0.12];
    UIColor *bot = [UIColor colorWithWhite:0.03 alpha:1.0];
    self.bgLayer.colors = @[(id)top.CGColor, (id)mid.CGColor, (id)bot.CGColor];
    self.bgLayer.locations = @[@0.0, @0.25, @0.55];
    self.bgLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bgLayer.endPoint = CGPointMake(0.5, 1.0);
    self.bgLayer.frame = root.bounds;
    [root.layer insertSublayer:self.bgLayer atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildModel];

    CGFloat w = self.view.bounds.size.width;
    CGFloat headerH = 180;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, headerH)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 56, 58, 36, 36);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    close.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    close.layer.cornerRadius = 18;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];

    UIView *logo = [[UIView alloc] initWithFrame:CGRectMake(24, 68, 72, 72)];
    logo.backgroundColor = NeedleCurrentColor();
    logo.layer.cornerRadius = 18;
    logo.layer.shadowColor = NeedleCurrentColor().CGColor;
    logo.layer.shadowOffset = CGSizeMake(0, 8);
    logo.layer.shadowRadius = 22;
    logo.layer.shadowOpacity = 0.55;
    UIImageView *logoIcon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"waveform" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightBold]]];
    logoIcon.tintColor = [UIColor whiteColor];
    logoIcon.contentMode = UIViewContentModeCenter;
    logoIcon.frame = logo.bounds;
    [logo addSubview:logoIcon];
    [header addSubview:logo];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 150, w - 48, 32)];
    title.text = @"Needle";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:title];

    [self.view addSubview:header];

    self.table = [[UITableView alloc] initWithFrame:
        CGRectMake(0, headerH, w, self.view.bounds.size.height - headerH)
        style:UITableViewStyleGrouped];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = 56;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, 40, 0);
    if ([self.table respondsToSelector:NSSelectorFromString(@"setSectionHeaderTopPadding:")]) {
        [self.table setValue:@0 forKey:@"sectionHeaderTopPadding"];
    }
    self.table.dataSource = self;
    self.table.delegate = self;
    [self.view addSubview:self.table];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    extern void NeedleHideFloatingButton(void);
    NeedleHideFloatingButton();
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    extern void NeedleShowFloatingButton(void);
    NeedleShowFloatingButton();
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bgLayer.frame = self.view.bounds;
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildModel {
    __weak typeof(self) weak = self;

    NeedleSection *playback = [NeedleSection new];
    playback.title = @"Playback";
    playback.rows = @[
        [NeedleRow sw:@"Fisher Yates shuffle" key:@"RealShuffle" def:YES symbol:@"shuffle"],
    ];
    playback.footer = @"Real random shuffle instead of Spotify's balanced algorithm.";

    extern void NeedleStartSleepTimer(NSInteger minutes);
    extern void NeedleCancelSleepTimer(void);
    extern NSTimeInterval NeedleSleepTimerRemaining(void);
    extern BOOL NeedleSleepTimerActive(void);

    NeedleSection *sleep = [NeedleSection new];
    sleep.title = @"Sleep timer";
    sleep.rows = @[
        [NeedleRow button:@"10 minutes" action:^{
            NeedleStartSleepTimer(10);
            [weak alert:@"Sleep timer on" message:@"Playback will pause in 10 minutes."];
        } symbol:@"moon"],
        [NeedleRow button:@"30 minutes" action:^{
            NeedleStartSleepTimer(30);
            [weak alert:@"Sleep timer on" message:@"Playback will pause in 30 minutes."];
        } symbol:@"moon.stars"],
        [NeedleRow button:@"1 hour" action:^{
            NeedleStartSleepTimer(60);
            [weak alert:@"Sleep timer on" message:@"Playback will pause in 1 hour."];
        } symbol:@"moon.zzz"],
        [NeedleRow button:@"Cancel timer" action:^{
            NeedleCancelSleepTimer();
            [weak alert:@"Sleep timer off" message:@"Timer cleared."];
        } symbol:@"xmark.circle"],
    ];
    sleep.footer = @"Pauses playback after the chosen interval.";

    NeedleSection *look = [NeedleSection new];
    look.title = @"Look";
    look.rows = @[
        [NeedleRow sw:@"Album colored UI" key:@"AlbumColorUI" def:YES symbol:@"paintpalette"],
        [NeedleRow sw:@"Artwork breathing" key:@"ArtworkBreathing" def:YES symbol:@"waveform.path"],
        [NeedleRow sw:@"Accent colors on controls" key:@"AccentColors" def:YES symbol:@"circle.hexagongrid.fill"],
        [NeedleRow sw:@"Apple Music lockscreen art" key:@"BigLockscreenArt" def:YES symbol:@"lock.iphone"],
    ];
    look.footer = @"Theme the Now Playing screen, mini player, play button and progress bar with the current album's palette.";

    NeedleSection *scrobble = [NeedleSection new];
    scrobble.title = @"Last.fm scrobble";
    scrobble.rows = @[
        [NeedleRow sw:@"Scrobble plays" key:@"ScrobbleOn" def:NO symbol:@"waveform.badge.plus"],
        [NeedleRow text:@"API key" key:@"LastFmApiKey" placeholder:@"paste here" symbol:@"key"],
        [NeedleRow text:@"Shared secret" key:@"LastFmSecret" placeholder:@"paste here" symbol:@"lock.shield"],
        [NeedleRow text:@"Session key" key:@"LastFmSession" placeholder:@"paste from auth" symbol:@"person.badge.key"],
        [NeedleRow button:@"Open Last.fm sign in" action:^{
            NSString *apiKey = NeedlePrefString(@"LastFmApiKey");
            if (!apiKey.length) {
                [weak alert:@"API key missing" message:@"Paste your Last.fm API key first."];
                return;
            }
            NSString *url = [NSString stringWithFormat:@"https://www.last.fm/api/auth/?api_key=%@", apiKey];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
        } symbol:@"safari"],
    ];
    scrobble.footer = @"Register at last.fm/api/account/create, paste the key and secret, tap Open Last.fm sign in, approve, then paste the session token out of the redirect URL into Session key.";

    NeedleSection *about = [NeedleSection new];
    about.title = @"About";
    about.rows = @[
        [NeedleRow button:@"Join the Discord" action:^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/4Fk34R76tt"] options:@{} completionHandler:nil];
        } symbol:@"bubble.left.and.bubble.right.fill"],
    ];
    about.footer = @"Needle v1.1";

    self.sections = @[playback, sleep, look, scrobble, about];
}

- (void)alert:(NSString *)title message:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.sections[s].rows.count; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return self.sections[s].title; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return self.sections[s].footer; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    NeedleRow *row = self.sections[ip.section].rows[ip.row];
    NSInteger rowCount = self.sections[ip.section].rows.count;
    BOOL first = ip.row == 0;
    BOOL last = ip.row == rowCount - 1;

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.textLabel.hidden = YES;
    cell.imageView.hidden = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor colorWithWhite:0.11 alpha:1.0];
    card.layer.cornerRadius = 16;
    card.layer.maskedCorners = 0;
    if (first) card.layer.maskedCorners |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (last)  card.layer.maskedCorners |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
        [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20],
        [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
    ]];

    if (!last) {
        UIView *sep = [[UIView alloc] init];
        sep.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:sep];
        [NSLayoutConstraint activateConstraints:@[
            [sep.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:64],
            [sep.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
            [sep.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
            [sep.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }

    UIView *iconCircle = [[UIView alloc] init];
    iconCircle.backgroundColor = NeedleCurrentColor();
    iconCircle.layer.cornerRadius = 15;
    iconCircle.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:iconCircle];
    [NSLayoutConstraint activateConstraints:@[
        [iconCircle.widthAnchor constraintEqualToConstant:30],
        [iconCircle.heightAnchor constraintEqualToConstant:30],
        [iconCircle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [iconCircle.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];
    if (row.symbol) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
        UIImageView *iv = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:row.symbol withConfiguration:cfg]];
        iv.tintColor = [UIColor whiteColor];
        iv.contentMode = UIViewContentModeCenter;
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        [iconCircle addSubview:iv];
        [NSLayoutConstraint activateConstraints:@[
            [iv.centerXAnchor constraintEqualToAnchor:iconCircle.centerXAnchor],
            [iv.centerYAnchor constraintEqualToAnchor:iconCircle.centerYAnchor],
        ]];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = row.label;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:iconCircle.trailingAnchor constant:14],
        [label.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];

    if (row.kind == NeedleRowSwitch) {
        UISwitch *sw = [UISwitch new];
        sw.on = NeedlePrefBool(row.prefKey, row.defaultBool);
        sw.onTintColor = NeedleCurrentColor();
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        objc_setAssociatedObject(sw, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(switchFlipped:) forControlEvents:UIControlEventValueChanged];
        [card addSubview:sw];
        [NSLayoutConstraint activateConstraints:@[
            [sw.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
            [sw.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-8],
        ]];
    } else if (row.kind == NeedleRowText) {
        UITextField *tf = [[UITextField alloc] init];
        tf.text = NeedlePrefString(row.prefKey);
        tf.placeholder = row.placeholder;
        tf.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        tf.textAlignment = NSTextAlignmentRight;
        tf.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.returnKeyType = UIReturnKeyDone;
        tf.delegate = self;
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        objc_setAssociatedObject(tf, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [card addSubview:tf];
        [NSLayoutConstraint activateConstraints:@[
            [tf.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
            [tf.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [tf.widthAnchor constraintGreaterThanOrEqualToConstant:140],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:tf.leadingAnchor constant:-8],
        ]];
    } else if (row.kind == NeedleRowButton) {
        label.textColor = NeedleCurrentColor();
        UIImageView *chev = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"arrow.up.right" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]]];
        chev.tintColor = [NeedleCurrentColor() colorWithAlphaComponent:0.55];
        chev.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:chev];
        [NSLayoutConstraint activateConstraints:@[
            [chev.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
            [chev.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        ]];
    }
    return cell;
}

- (void)switchFlipped:(UISwitch *)sw {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    NSString *key = objc_getAssociatedObject(sw, "_needleKey");
    if (key) NeedlePrefSetBool(key, sw.on);
}

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    NeedleSection *sec = self.sections[s];
    if (!sec.title.length) return nil;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 44)];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(28, 20, t.bounds.size.width - 56, 22)];
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    lbl.text = sec.title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [header addSubview:lbl];
    return header;
}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s {
    return self.sections[s].title.length ? 44 : 12;
}

- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    NeedleSection *sec = self.sections[s];
    if (!sec.footer.length) return nil;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 60)];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(28, 10, t.bounds.size.width - 56, 60)];
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    lbl.text = sec.footer;
    lbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.4];
    lbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    lbl.numberOfLines = 0;
    [footer addSubview:lbl];
    return footer;
}

- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s {
    NSString *f = self.sections[s].footer;
    if (!f.length) return 4;
    CGFloat w = t.bounds.size.width - 56;
    CGRect r = [f boundingRectWithSize:CGSizeMake(w, 999)
        options:NSStringDrawingUsesLineFragmentOrigin
        attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12.5]}
        context:nil];
    return ceil(r.size.height) + 22;
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)tf {
    NSString *key = objc_getAssociatedObject(tf, "_needleKey");
    if (key) NeedlePrefSetString(key, tf.text);
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NeedleRow *row = self.sections[ip.section].rows[ip.row];
    if (row.kind == NeedleRowButton && row.action) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
        row.action();
    }
}

+ (void)_needleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
        extern void NeedleOpenSettings(void);
        NeedleOpenSettings();
    }
}

+ (void)_needleTripleTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateRecognized) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [fb impactOccurred];
        extern void NeedleOpenSettings(void);
        NeedleOpenSettings();
    }
}

+ (void)_needleGearTap:(UITapGestureRecognizer *)g {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    extern void NeedleOpenSettings(void);
    NeedleOpenSettings();
}

+ (void)_needleGearPan:(UIPanGestureRecognizer *)g {
    UIView *host = g.view;
    if (!host || !host.superview) return;
    CGPoint t = [g translationInView:host.superview];
    host.center = CGPointMake(host.center.x + t.x, host.center.y + t.y);
    [g setTranslation:CGPointZero inView:host.superview];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGRect bounds = host.superview.bounds;
        CGFloat x = host.center.x < bounds.size.width / 2 ? host.frame.size.width / 2 + 12 : bounds.size.width - host.frame.size.width / 2 - 12;
        [UIView animateWithDuration:0.25 animations:^{
            host.center = CGPointMake(x, host.center.y);
        }];
    }
}

@end

static UIViewController *_NeedleTopVC(void) {
    UIWindow *win = nil;
    NSArray *scenes = [[UIApplication sharedApplication].connectedScenes allObjects];
    for (UIScene *s in scenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w.isKeyWindow) { win = w; break; }
            }
        }
    }
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

void NeedleOpenSettings(void) {
    UIViewController *top = _NeedleTopVC();
    if (!top) return;
    NeedleSettingsViewController *vc = [NeedleSettingsViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}

@interface SPTNowPlayingBar : UIView
@end

static void _NeedleAttachLongPress(UIView *view) {
    if (!view) return;
    static char _lpKey;
    if (objc_getAssociatedObject(view, &_lpKey)) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleLongPress:)];
    lp.minimumPressDuration = 0.6;
    lp.cancelsTouchesInView = NO;
    [view addGestureRecognizer:lp];
    objc_setAssociatedObject(view, &_lpKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook SPTNowPlayingBar
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    _NeedleAttachLongPress(self);
}
%end

static UIView *_needleFloatingHost = nil;
static BOOL _needleFloatingHidden = NO;

void NeedleHideFloatingButton(void) {
    _needleFloatingHidden = YES;
    if (_needleFloatingHost) _needleFloatingHost.hidden = YES;
}

void NeedleShowFloatingButton(void) {
    _needleFloatingHidden = NO;
    if (_needleFloatingHost) _needleFloatingHost.hidden = NO;
}

static UIView *_NeedleBuildButton(CGRect frame) {
    UIView *host = [[UIView alloc] initWithFrame:frame];
    host.backgroundColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:0.95];
    host.layer.cornerRadius = frame.size.width / 2;
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOffset = CGSizeMake(0, 3);
    host.layer.shadowRadius = 10;
    host.layer.shadowOpacity = 0.6;
    host.layer.borderWidth = 2;
    host.layer.borderColor = [UIColor whiteColor].CGColor;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    UIImage *icon = [UIImage systemImageNamed:@"gearshape.fill" withConfiguration:cfg];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = host.bounds;
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:iv];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleGearTap:)];
    [host addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleGearPan:)];
    [host addGestureRecognizer:pan];
    return host;
}

static void NeedleInstallFloatingButton(void) {
    UIWindow *target = nil;
    NSArray *scenes = [[UIApplication sharedApplication].connectedScenes allObjects];
    for (UIScene *s in scenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            UIWindowScene *ws = (UIWindowScene *)s;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { target = w; break; }
            }
            if (!target && ws.windows.count) target = ws.windows.firstObject;
            if (target) break;
        }
    }
    if (!target) return;

    if (_needleFloatingHost && _needleFloatingHost.superview == target) {
        [target bringSubviewToFront:_needleFloatingHost];
        return;
    }
    if (_needleFloatingHost) [_needleFloatingHost removeFromSuperview];

    CGFloat btnSize = 52;
    CGRect frame = CGRectMake(target.bounds.size.width - btnSize - 14, 72, btnSize, btnSize);
    _needleFloatingHost = _NeedleBuildButton(frame);
    _needleFloatingHost.hidden = _needleFloatingHidden;
    [target addSubview:_needleFloatingHost];
    [target bringSubviewToFront:_needleFloatingHost];

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @0.3;
    pulse.toValue = @1.0;
    pulse.duration = 0.4;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [_needleFloatingHost.layer addAnimation:pulse forKey:@"spawn"];
}

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.isKeyWindow && self.windowLevel <= UIWindowLevelNormal + 10) {
        if (!_needleFloatingHost || _needleFloatingHost.superview != self) {
            NeedleInstallFloatingButton();
        } else {
            [self bringSubviewToFront:_needleFloatingHost];
        }
    }
}
%end

static NSTimer *_needleInstallTimer = nil;

static void NeedleStartInstallWatchdog(void) {
    if (_needleInstallTimer) return;
    _needleInstallTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *t) {
        NeedleInstallFloatingButton();
    }];
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
    });
}
%end

%hook UIWindow
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake) {
        extern void NeedleOpenSettings(void);
        NeedleOpenSettings();
    }
}
%end

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleInstallFloatingButton();
                NeedleStartInstallWatchdog();
            });
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleInstallFloatingButton();
                NeedleStartInstallWatchdog();
            });
        }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
        NeedleStartInstallWatchdog();
    });
}
