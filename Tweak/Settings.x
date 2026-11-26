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
    root.backgroundColor = [UIColor blackColor];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildModel];

    CGFloat w = self.view.bounds.size.width;
    CGFloat headerH = 100;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, headerH)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(16, 58, 32, 32);
    close.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [close setImage:[UIImage systemImageNamed:@"chevron.down"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 56, w, 36)];
    title.text = @"Needle";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:title];

    UIView *hairline = [[UIView alloc] initWithFrame:CGRectMake(0, headerH - 0.5, w, 0.5)];
    hairline.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [header addSubview:hairline];

    [self.view addSubview:header];

    self.table = [[UITableView alloc] initWithFrame:
        CGRectMake(0, headerH, w, self.view.bounds.size.height - headerH)
        style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = [UIColor blackColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = 54;
    self.table.contentInset = UIEdgeInsetsMake(8, 0, 60, 0);
    if ([self.table respondsToSelector:NSSelectorFromString(@"setSectionHeaderTopPadding:")]) {
        [self.table setValue:@16 forKey:@"sectionHeaderTopPadding"];
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
    extern void _NeedleSyncGearVisibility(void);
    _NeedleSyncGearVisibility();
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
        [NeedleRow sw:@"Shuffle lock (no auto-off)" key:@"ShuffleLock" def:NO symbol:@"lock.shield"],
        [NeedleRow sw:@"Enhanced crossfade (20 s)" key:@"CrossfadeMax" def:NO symbol:@"waveform.path.ecg"],
        [NeedleRow sw:@"Gapless within album" key:@"GaplessAlbum" def:YES symbol:@"forward.end"],
        [NeedleRow sw:@"Force 320 kbps" key:@"HighBitrate" def:NO symbol:@"4k.tv"],
        [NeedleRow sw:@"Volume boost (1.5×)" key:@"VolumeBoost" def:NO symbol:@"speaker.wave.3.fill"],
        [NeedleRow sw:@"Free-tier unlocks" key:@"FreeUnlocks" def:NO symbol:@"crown.fill"],
    ];
    playback.footer = @"Free-tier unlocks flip Spotify client flags to pretend you're premium (unlimited skips, on-demand play). Server may still refuse; use at your own risk.";

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
        [NeedleRow sw:@"Fade out last 60 s" key:@"SleepFade" def:YES symbol:@"speaker.slash"],
    ];
    sleep.footer = @"Fade drops the volume gradually over the last minute before pausing.";

    NeedleSection *look = [NeedleSection new];
    look.title = @"Look";
    look.rows = @[
        [NeedleRow sw:@"Album colored UI" key:@"AlbumColorUI" def:YES symbol:@"paintpalette"],
        [NeedleRow sw:@"Artwork breathing" key:@"ArtworkBreathing" def:YES symbol:@"waveform.path"],
        [NeedleRow sw:@"Accent colors on controls" key:@"AccentColors" def:YES symbol:@"circle.hexagongrid.fill"],
        [NeedleRow sw:@"Lockscreen Ken Burns (beta)" key:@"LockMotion" def:NO symbol:@"lock.iphone"],
        [NeedleRow sw:@"Mini player redesign" key:@"MiniPlayerRedesign" def:YES symbol:@"rectangle.bottomthird.inset.filled"],
        [NeedleRow sw:@"Waveform scrubber" key:@"WaveformScrubber" def:NO symbol:@"waveform"],
    ];
    look.footer = @"Theme and animate the Now Playing surfaces with the current album's palette.";

    NeedleSection *content = [NeedleSection new];
    content.title = @"Content";
    content.rows = @[
        [NeedleRow sw:@"Block all ads" key:@"BlockAds" def:YES symbol:@"nosign"],
        [NeedleRow sw:@"DNS-level analytics block" key:@"DNSBlock" def:YES symbol:@"shield.lefthalf.filled"],
        [NeedleRow sw:@"Skip short interludes" key:@"SkipInterludes" def:NO symbol:@"forward.end.alt"],
        [NeedleRow sw:@"Skip explicit tracks" key:@"SkipExplicit" def:NO symbol:@"e.square"],
        [NeedleRow sw:@"Tap lyric → full view" key:@"LyricsTapOpensFull" def:YES symbol:@"text.quote"],
    ];
    content.footer = @"DNS block drops requests to pixel.spotify.com, adeventtracker, analytics.scdn.co and known ad hosts.";

    NeedleSection *discover = [NeedleSection new];
    discover.title = @"Discover";
    discover.rows = @[
        [NeedleRow button:@"Similar songs" action:^{
            extern void NeedleOpenSimilarSongs(void);
            NeedleOpenSimilarSongs();
        } symbol:@"sparkles.rectangle.stack"],
        [NeedleRow button:@"Mood jumper" action:^{
            extern void NeedleOpenMoodJumper(void);
            NeedleOpenMoodJumper();
        } symbol:@"face.smiling"],
        [NeedleRow button:@"Playlist mixer" action:^{
            extern void NeedleOpenMixer(void);
            NeedleOpenMixer();
        } symbol:@"shuffle.circle"],
        [NeedleRow button:@"Session mosaic" action:^{
            extern void NeedleOpenSessionMosaic(void);
            NeedleOpenSessionMosaic();
        } symbol:@"square.grid.3x3.fill"],
        [NeedleRow button:@"Recognize song" action:^{
            extern void NeedleOpenRecognize(void);
            NeedleOpenRecognize();
        } symbol:@"waveform.badge.magnifyingglass"],
        [NeedleRow button:@"Local music" action:^{
            extern void NeedleOpenLocalPlayer(void);
            NeedleOpenLocalPlayer();
        } symbol:@"folder.fill"],
    ];
    discover.footer = @"Similar / mood / mixer / session all read your local listening history. Twin playback was requested but iOS can't route one app's audio to two outputs, so it is not built.";

    NeedleSection *you = [NeedleSection new];
    you.title = @"You";
    you.rows = @[
        [NeedleRow button:@"Live Wrapped" action:^{
            extern void NeedleOpenWrapped(void);
            NeedleOpenWrapped();
        } symbol:@"chart.bar.fill"],
        [NeedleRow button:@"Themes" action:^{
            extern void NeedleOpenThemeStore(void);
            NeedleOpenThemeStore();
        } symbol:@"paintpalette.fill"],
        [NeedleRow button:@"Change app icon" action:^{
            extern void NeedleOpenIconPicker(void);
            NeedleOpenIconPicker();
        } symbol:@"app.fill"],
        [NeedleRow button:@"What's new" action:^{
            extern void NeedleShowChangelogNow(void);
            NeedleShowChangelogNow();
        } symbol:@"sparkles"],
    ];
    you.footer = @"Themes override the album-extracted palette with a fixed one.";

    self.sections = @[playback, sleep, look, content, discover, you];
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

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor blackColor];
    cell.textLabel.hidden = YES;
    cell.imageView.hidden = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (row.symbol) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular];
        UIImageView *iv = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:row.symbol withConfiguration:cfg]];
        iv.tintColor = [UIColor colorWithWhite:1 alpha:0.9];
        iv.contentMode = UIViewContentModeCenter;
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:iv];
        [NSLayoutConstraint activateConstraints:@[
            [iv.widthAnchor constraintEqualToConstant:28],
            [iv.heightAnchor constraintEqualToConstant:28],
            [iv.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
            [iv.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        ]];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = row.label;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:row.symbol ? 62 : 20],
        [label.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
    ]];

    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:sep];
    [NSLayoutConstraint activateConstraints:@[
        [sep.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:62],
        [sep.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [sep.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],
    ]];

    if (row.kind == NeedleRowSwitch) {
        UISwitch *sw = [UISwitch new];
        sw.on = NeedlePrefBool(row.prefKey, row.defaultBool);
        sw.onTintColor = NeedleCurrentColor();
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        objc_setAssociatedObject(sw, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(switchFlipped:) forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:sw];
        [NSLayoutConstraint activateConstraints:@[
            [sw.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [sw.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-8],
        ]];
    } else if (row.kind == NeedleRowText) {
        UITextField *tf = [[UITextField alloc] init];
        tf.text = NeedlePrefString(row.prefKey);
        tf.placeholder = row.placeholder;
        tf.textColor = [UIColor colorWithWhite:1 alpha:0.7];
        tf.textAlignment = NSTextAlignmentRight;
        tf.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.returnKeyType = UIReturnKeyDone;
        tf.delegate = self;
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        objc_setAssociatedObject(tf, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell.contentView addSubview:tf];
        [NSLayoutConstraint activateConstraints:@[
            [tf.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [tf.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [tf.widthAnchor constraintGreaterThanOrEqualToConstant:140],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:tf.leadingAnchor constant:-8],
        ]];
    } else if (row.kind == NeedleRowButton) {
        UIImageView *chev = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"chevron.right" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold]]];
        chev.tintColor = [UIColor colorWithWhite:1 alpha:0.35];
        chev.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:chev];
        [NSLayoutConstraint activateConstraints:@[
            [chev.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20],
            [chev.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
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
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 36)];
    header.backgroundColor = [UIColor blackColor];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, t.bounds.size.width - 40, 20)];
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    lbl.text = sec.title.uppercaseString;
    lbl.textColor = [UIColor colorWithWhite:1 alpha:0.45];
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [header addSubview:lbl];
    return header;
}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s {
    return self.sections[s].title.length ? 36 : 8;
}

- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    NeedleSection *sec = self.sections[s];
    if (!sec.footer.length) return nil;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 60)];
    footer.backgroundColor = [UIColor blackColor];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, t.bounds.size.width - 40, 60)];
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    lbl.text = sec.footer;
    lbl.textColor = [UIColor colorWithWhite:1 alpha:0.35];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    lbl.numberOfLines = 0;
    [footer addSubview:lbl];
    return footer;
}

- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s {
    NSString *f = self.sections[s].footer;
    if (!f.length) return 4;
    CGFloat w = t.bounds.size.width - 40;
    CGRect r = [f boundingRectWithSize:CGSizeMake(w, 999)
        options:NSStringDrawingUsesLineFragmentOrigin
        attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12]}
        context:nil];
    return ceil(r.size.height) + 20;
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
static BOOL _needleFloatingHidden = YES;
static BOOL _needleProfileOnScreen = NO;

void NeedleHideFloatingButton(void) {
    _needleFloatingHidden = YES;
    if (_needleFloatingHost) _needleFloatingHost.hidden = YES;
}

void NeedleShowFloatingButton(void) {
    _needleFloatingHidden = NO;
    if (_needleFloatingHost) _needleFloatingHost.hidden = NO;
}

void _NeedleSyncGearVisibility(void) {
    if (!_needleFloatingHost) return;
    _needleFloatingHost.hidden = !_needleProfileOnScreen;
}

static UIView *_NeedleBuildButton(CGRect frame) {
    UIView *host = [[UIView alloc] initWithFrame:frame];
    host.backgroundColor = [UIColor clearColor];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOffset = CGSizeMake(0, 4);
    host.layer.shadowRadius = 10;
    host.layer.shadowOpacity = 0.35;

    UIBlurEffect *blur = nil;
    if (@available(iOS 13.0, *)) {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    } else {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    UIVisualEffectView *vfx = [[UIVisualEffectView alloc] initWithEffect:blur];
    vfx.frame = host.bounds;
    vfx.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vfx.layer.cornerRadius = frame.size.width / 2;
    vfx.layer.masksToBounds = YES;
    vfx.layer.borderWidth = 0.5;
    vfx.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    [host addSubview:vfx];

    UIView *tint = [[UIView alloc] initWithFrame:host.bounds];
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    tint.layer.cornerRadius = frame.size.width / 2;
    [vfx.contentView addSubview:tint];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
    UIImage *icon = [UIImage systemImageNamed:@"gearshape.fill" withConfiguration:cfg];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = host.bounds;
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vfx.contentView addSubview:iv];

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

    CGFloat btnSize = 42;
    CGRect frame = CGRectMake(target.bounds.size.width - btnSize - 16, 68, btnSize, btnSize);
    _needleFloatingHost = _NeedleBuildButton(frame);
    _needleFloatingHost.hidden = !_needleProfileOnScreen;
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

static BOOL _NeedleIsProfileVCClass(Class c) {
    NSString *name = NSStringFromClass(c);
    if (!name.length) return NO;
    if ([name containsString:@"Profile"]) return YES;
    if ([name containsString:@"YourLibrary"] && [name containsString:@"Account"]) return YES;
    if ([name hasPrefix:@"SPTAccount"]) return YES;
    return NO;
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (_NeedleIsProfileVCClass([self class])) {
        _needleProfileOnScreen = YES;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
        _NeedleSyncGearVisibility();
    });
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (_NeedleIsProfileVCClass([self class])) {
        _needleProfileOnScreen = NO;
        _NeedleSyncGearVisibility();
    }
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
