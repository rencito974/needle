#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern NSString *NeedlePrefString(NSString *key);
extern void NeedlePrefSetBool(NSString *key, BOOL val);
extern void NeedlePrefSetString(NSString *key, NSString *val);
extern UIColor *NeedleCurrentColor(void);
extern NSMutableDictionary *_needleCurrentTrackCache;

typedef NS_ENUM(NSInteger, NeedleRowKind) {
    NeedleRowSwitch,
    NeedleRowText,
    NeedleRowButton,
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
+ (instancetype)text:(NSString *)label key:(NSString *)key placeholder:(NSString *)ph symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowText;
    r.label = label;
    r.prefKey = key;
    r.placeholder = ph;
    r.symbol = sym;
    return r;
}
+ (instancetype)button:(NSString *)label action:(void (^)(void))action symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowButton;
    r.label = label;
    r.action = action;
    r.symbol = sym;
    return r;
}
@end

@interface NeedleSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSArray<NeedleRow *> *rows;
@end
@implementation NeedleSection
@end

@interface NeedleHeroView : UIView
@property (nonatomic, strong) UILabel *trackLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *qrButton;
@property (nonatomic, strong) UIView *playingStrip;
@end
@implementation NeedleHeroView
@end

@interface NeedleSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<NeedleSection *> *sections;
@property (nonatomic, strong) CAGradientLayer *bgLayer;
@property (nonatomic, strong) NeedleHeroView *hero;
@end

static NSString *_NeedleVersionTag(void) {
    return @"2.13";
}

@implementation NeedleSettingsViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];

    self.bgLayer = [CAGradientLayer layer];
    UIColor *accent = NeedleCurrentColor();
    self.bgLayer.colors = @[
        (id)[accent colorWithAlphaComponent:0.28].CGColor,
        (id)[accent colorWithAlphaComponent:0.05].CGColor,
        (id)[UIColor blackColor].CGColor,
    ];
    self.bgLayer.locations = @[@0.0, @0.12, @0.42];
    self.bgLayer.frame = root.bounds;
    [root.layer insertSublayer:self.bgLayer atIndex:0];

    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildModel];

    CGFloat w = self.view.bounds.size.width;

    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = 54;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, 80, 0);
    self.table.showsVerticalScrollIndicator = NO;
    self.table.dataSource = self;
    self.table.delegate = self;
    [self.view addSubview:self.table];

    self.hero = [self buildHero:w];
    self.table.tableHeaderView = self.hero;
}

- (NeedleHeroView *)buildHero:(CGFloat)w {
    BOOL playing = (_needleCurrentTrackCache[@"name"] != nil) && [_needleCurrentTrackCache[@"name"] length] > 0;
    CGFloat heroH = playing ? 242 : 176;
    NeedleHeroView *hero = [[NeedleHeroView alloc] initWithFrame:CGRectMake(0, 0, w, heroH)];
    hero.backgroundColor = [UIColor clearColor];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 60, 60, 42, 42);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.frame = close.bounds;
    blur.layer.cornerRadius = 21;
    blur.layer.masksToBounds = YES;
    blur.userInteractionEnabled = NO;
    [close insertSubview:blur atIndex:0];
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [hero addSubview:close];

    UILabel *wordmark = [[UILabel alloc] initWithFrame:CGRectMake(22, 60, w - 90, 46)];
    wordmark.text = @"Needle";
    wordmark.textColor = [UIColor whiteColor];
    wordmark.font = [UIFont systemFontOfSize:42 weight:UIFontWeightBlack];
    [hero addSubview:wordmark];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(22, 108, w - 44, 18)];
    sub.text = [NSString stringWithFormat:@"v%@", _NeedleVersionTag()];
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.42];
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [hero addSubview:sub];

    if (playing) {
        UIView *strip = [[UIView alloc] initWithFrame:CGRectMake(22, 152, w - 44, 72)];
        strip.backgroundColor = [NeedleCurrentColor() colorWithAlphaComponent:0.14];
        strip.layer.cornerRadius = 20;
        strip.layer.borderWidth = 0.5;
        strip.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
        [hero addSubview:strip];

        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(18, 24, 10, 10)];
        dot.backgroundColor = NeedleCurrentColor();
        dot.layer.cornerRadius = 5;
        [strip addSubview:dot];
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @0.4;
        pulse.toValue = @1.0;
        pulse.duration = 0.9;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        [dot.layer addAnimation:pulse forKey:@"pulse"];

        UILabel *trackLbl = [[UILabel alloc] initWithFrame:CGRectMake(36, 10, strip.frame.size.width - 86, 24)];
        trackLbl.text = _needleCurrentTrackCache[@"name"] ?: @"";
        trackLbl.textColor = [UIColor whiteColor];
        trackLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [strip addSubview:trackLbl];

        UILabel *artistLbl = [[UILabel alloc] initWithFrame:CGRectMake(36, 34, strip.frame.size.width - 86, 20)];
        artistLbl.text = _needleCurrentTrackCache[@"artist"] ?: @"";
        artistLbl.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        artistLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [strip addSubview:artistLbl];

        UIButton *qr = [UIButton buttonWithType:UIButtonTypeSystem];
        qr.frame = CGRectMake(strip.frame.size.width - 54, 14, 44, 44);
        qr.backgroundColor = NeedleCurrentColor();
        qr.layer.cornerRadius = 14;
        [qr setImage:[UIImage systemImageNamed:@"qrcode"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]]
            forState:UIControlStateNormal];
        qr.tintColor = [UIColor whiteColor];
        [qr addTarget:self action:@selector(openQR) forControlEvents:UIControlEventTouchUpInside];
        [strip addSubview:qr];
        hero.qrButton = qr;
    }

    return hero;
}

- (void)openQR {
    extern void NeedleOpenQRShare(void);
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    [self dismissViewControllerAnimated:YES completion:^{ NeedleOpenQRShare(); }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.bgLayer) self.bgLayer.frame = self.view.bounds;
    if (self.hero && self.table.tableHeaderView != self.hero) self.table.tableHeaderView = self.hero;
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

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildModel {
    __weak typeof(self) weak = self;

    NeedleSection *playback = [NeedleSection new];
    playback.title = @"Playback";
    playback.rows = @[
        [NeedleRow sw:@"Fisher Yates shuffle" key:@"RealShuffle" def:YES symbol:@"shuffle"],
        [NeedleRow sw:@"Shuffle lock" key:@"ShuffleLock" def:NO symbol:@"lock.shield"],
        [NeedleRow sw:@"Crossfade 20 s" key:@"CrossfadeMax" def:NO symbol:@"waveform.path.ecg"],
        [NeedleRow sw:@"Gapless within album" key:@"GaplessAlbum" def:YES symbol:@"forward.end"],
        [NeedleRow sw:@"Force 320 kbps" key:@"HighBitrate" def:NO symbol:@"4k.tv"],
        [NeedleRow sw:@"Volume boost" key:@"VolumeBoost" def:NO symbol:@"speaker.wave.3.fill"],
        [NeedleRow sw:@"Free-tier unlocks" key:@"FreeUnlocks" def:NO symbol:@"crown.fill"],
    ];

    extern void NeedleStartSleepTimer(NSInteger minutes);
    extern void NeedleCancelSleepTimer(void);

    NeedleSection *sleep = [NeedleSection new];
    sleep.title = @"Sleep timer";
    sleep.rows = @[
        [NeedleRow button:@"10 minutes" action:^{
            NeedleStartSleepTimer(10);
            [weak toast:@"Sleep timer on in 10 min"];
        } symbol:@"moon"],
        [NeedleRow button:@"30 minutes" action:^{
            NeedleStartSleepTimer(30);
            [weak toast:@"Sleep timer on in 30 min"];
        } symbol:@"moon.stars"],
        [NeedleRow button:@"1 hour" action:^{
            NeedleStartSleepTimer(60);
            [weak toast:@"Sleep timer on in 1 h"];
        } symbol:@"moon.zzz"],
        [NeedleRow button:@"Cancel timer" action:^{
            NeedleCancelSleepTimer();
            [weak toast:@"Sleep timer off"];
        } symbol:@"xmark.circle"],
        [NeedleRow sw:@"Fade last 60 s" key:@"SleepFade" def:YES symbol:@"speaker.slash"],
    ];

    NeedleSection *look = [NeedleSection new];
    look.title = @"Look";
    look.rows = @[
        [NeedleRow sw:@"Album colored UI" key:@"AlbumColorUI" def:YES symbol:@"paintpalette"],
        [NeedleRow sw:@"Artwork breathing" key:@"ArtworkBreathing" def:YES symbol:@"waveform.path"],
        [NeedleRow sw:@"Accent on controls" key:@"AccentColors" def:YES symbol:@"circle.hexagongrid.fill"],
        [NeedleRow sw:@"Lockscreen Ken Burns" key:@"LockMotion" def:NO symbol:@"lock.iphone"],
        [NeedleRow sw:@"Mini player redesign" key:@"MiniPlayerRedesign" def:YES symbol:@"rectangle.bottomthird.inset.filled"],
        [NeedleRow sw:@"Waveform scrubber" key:@"WaveformScrubber" def:NO symbol:@"waveform"],
        [NeedleRow sw:@"Bluetooth badge" key:@"BTBadge" def:YES symbol:@"airpods"],
    ];

    NeedleSection *content = [NeedleSection new];
    content.title = @"Content";
    content.rows = @[
        [NeedleRow sw:@"Block all ads" key:@"BlockAds" def:YES symbol:@"nosign"],
        [NeedleRow sw:@"DNS analytics block" key:@"DNSBlock" def:YES symbol:@"shield.lefthalf.filled"],
        [NeedleRow sw:@"Skip interludes" key:@"SkipInterludes" def:NO symbol:@"forward.end.alt"],
        [NeedleRow sw:@"Skip explicit tracks" key:@"SkipExplicit" def:NO symbol:@"e.square"],
        [NeedleRow sw:@"Tap lyric opens full" key:@"LyricsTapOpensFull" def:YES symbol:@"text.quote"],
    ];

    NeedleSection *discover = [NeedleSection new];
    discover.title = @"Discover";
    discover.rows = @[
        [NeedleRow button:@"Share song (QR)" action:^{
            extern void NeedleOpenQRShare(void);
            NeedleOpenQRShare();
        } symbol:@"qrcode"],
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
        [NeedleRow button:@"Streaks" action:^{
            extern void NeedleOpenStreaks(void);
            NeedleOpenStreaks();
        } symbol:@"flame.fill"],
        [NeedleRow button:@"Guilty pleasures" action:^{
            extern void NeedleOpenGuilty(void);
            NeedleOpenGuilty();
        } symbol:@"eye.slash.fill"],
    ];

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

    self.sections = @[discover, playback, look, content, sleep, you];
}

- (void)toast:(NSString *)text {
    CGFloat w = self.view.bounds.size.width;
    UIView *toast = [[UIView alloc] initWithFrame:CGRectMake(32, self.view.bounds.size.height - 160, w - 64, 52)];
    toast.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    toast.layer.cornerRadius = 18;
    toast.layer.borderWidth = 0.5;
    toast.layer.borderColor = [NeedleCurrentColor() colorWithAlphaComponent:0.4].CGColor;
    toast.alpha = 0;
    UILabel *lbl = [[UILabel alloc] initWithFrame:toast.bounds];
    lbl.text = text;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    lbl.textAlignment = NSTextAlignmentCenter;
    [toast addSubview:lbl];
    [self.view addSubview:toast];
    [UIView animateWithDuration:0.22 animations:^{ toast.alpha = 1; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.4 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.sections[s].rows.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    NeedleRow *row = self.sections[ip.section].rows[ip.row];
    NSInteger count = self.sections[ip.section].rows.count;
    BOOL last = ip.row == count - 1;

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.hidden = YES;
    cell.imageView.hidden = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIView *content = cell.contentView;

    if (row.symbol) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightMedium];
        UIImageView *iv = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:row.symbol withConfiguration:cfg]];
        iv.tintColor = NeedleCurrentColor();
        iv.contentMode = UIViewContentModeCenter;
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:iv];
        [NSLayoutConstraint activateConstraints:@[
            [iv.widthAnchor constraintEqualToConstant:28],
            [iv.heightAnchor constraintEqualToConstant:28],
            [iv.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:22],
            [iv.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        ]];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = row.label;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:row.symbol ? 62 : 22],
        [label.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
    ]];

    if (row.kind == NeedleRowSwitch) {
        UISwitch *sw = [UISwitch new];
        sw.on = NeedlePrefBool(row.prefKey, row.defaultBool);
        sw.onTintColor = NeedleCurrentColor();
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        objc_setAssociatedObject(sw, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(switchFlipped:) forControlEvents:UIControlEventValueChanged];
        [content addSubview:sw];
        [NSLayoutConstraint activateConstraints:@[
            [sw.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
            [sw.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-10],
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
        [content addSubview:tf];
        [NSLayoutConstraint activateConstraints:@[
            [tf.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
            [tf.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
            [tf.widthAnchor constraintGreaterThanOrEqualToConstant:140],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:tf.leadingAnchor constant:-8],
        ]];
    } else if (row.kind == NeedleRowButton) {
        UIImageView *chev = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"chevron.right" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightBold]]];
        chev.tintColor = [UIColor colorWithWhite:1 alpha:0.28];
        chev.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:chev];
        [NSLayoutConstraint activateConstraints:@[
            [chev.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-22],
            [chev.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        ]];
    }

    if (!last) {
        UIView *sep = [[UIView alloc] init];
        sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.055];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:sep];
        [NSLayoutConstraint activateConstraints:@[
            [sep.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:row.symbol ? 62 : 22],
            [sep.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
            [sep.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
            [sep.heightAnchor constraintEqualToConstant:0.5],
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
    CGFloat w = t.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 54)];
    header.backgroundColor = [UIColor clearColor];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(22, 34, 14, 2)];
    bar.backgroundColor = NeedleCurrentColor();
    bar.layer.cornerRadius = 1;
    [header addSubview:bar];

    UILabel *lbl = [[UILabel alloc] init];
    NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:[sec.title uppercaseString]];
    [a addAttribute:NSKernAttributeName value:@2.0 range:NSMakeRange(0, a.length)];
    [a addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:11 weight:UIFontWeightHeavy] range:NSMakeRange(0, a.length)];
    [a addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:1 alpha:0.52] range:NSMakeRange(0, a.length)];
    lbl.attributedText = a;
    lbl.frame = CGRectMake(44, 24, w - 60, 22);
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:lbl];
    return header;
}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s {
    return 54;
}

- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s {
    return 12;
}

- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    return nil;
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

- (void)tableView:(UITableView *)t willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
    NeedleRow *row = self.sections[ip.section].rows[ip.row];
    if (row.kind == NeedleRowButton) {
        UIView *flash = [[UIView alloc] initWithFrame:cell.contentView.bounds];
        flash.backgroundColor = [UIColor clearColor];
        flash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        flash.userInteractionEnabled = NO;
        flash.tag = 9988;
        [cell.contentView insertSubview:flash atIndex:0];
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

void _NeedleSyncGearVisibility(void) {
    if (!_needleFloatingHost) return;
    _needleFloatingHost.hidden = _needleFloatingHidden;
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
        _NeedleSyncGearVisibility();
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
