#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern NSString *NeedlePrefString(NSString *key);
extern float NeedlePrefFloat(NSString *key, float def);
extern void NeedlePrefSetBool(NSString *key, BOOL val);
extern void NeedlePrefSetString(NSString *key, NSString *val);
extern void NeedlePrefSetFloat(NSString *key, float val);
extern UIColor *NeedleCurrentColor(void);
extern NSMutableDictionary *_needleCurrentTrackCache;

static UIViewController *_NeedleTopVC(void);

typedef NS_ENUM(NSInteger, NeedleRowKind) {
    NeedleRowSwitch,
    NeedleRowText,
    NeedleRowButton,
    NeedleRowSlider,
    NeedleRowInfo,
};

@interface NeedleRow : NSObject
@property (nonatomic, assign) NeedleRowKind kind;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *detailValue;
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, assign) BOOL defaultBool;
@property (nonatomic, assign) float defaultFloat;
@property (nonatomic, assign) float minFloat;
@property (nonatomic, assign) float maxFloat;
@property (nonatomic, copy) NSString *suffix;
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
+ (instancetype)slider:(NSString *)label key:(NSString *)key def:(float)def min:(float)minV max:(float)maxV suffix:(NSString *)sfx symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowSlider;
    r.label = label;
    r.prefKey = key;
    r.defaultFloat = def;
    r.minFloat = minV;
    r.maxFloat = maxV;
    r.suffix = sfx;
    r.symbol = sym;
    return r;
}
+ (instancetype)info:(NSString *)label value:(NSString *)value symbol:(NSString *)sym {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowInfo;
    r.label = label;
    r.detailValue = value;
    r.symbol = sym;
    return r;
}
@end

@interface NeedleSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, strong) NSArray<NeedleRow *> *rows;
@end
@implementation NeedleSection
@end

static NeedleRow *_NeedleRowWithSubtitle(NeedleRow *r, NSString *sub) {
    r.subtitle = sub;
    return r;
}
#define WITHSUB(row, sub) _NeedleRowWithSubtitle((row), (sub))

@interface NeedleHeroView : UIView
@property (nonatomic, strong) UILabel *trackLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *qrButton;
@property (nonatomic, strong) UIView *playingStrip;
@end
@implementation NeedleHeroView
@end

@interface NeedleSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<NeedleSection *> *sections;
@property (nonatomic, strong) NSArray<NeedleSection *> *allSections;
@property (nonatomic, strong) CAGradientLayer *bgLayer;
@property (nonatomic, strong) NeedleHeroView *hero;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

static NSString *_NeedleVersionTag(void) {
    return @"2.32";
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

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStyleInsetGrouped;
    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = UITableViewAutomaticDimension;
    self.table.estimatedRowHeight = 64;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.contentInset = UIEdgeInsetsMake(0, 0, 80, 0);
    self.table.showsVerticalScrollIndicator = NO;
    if ([self.table respondsToSelector:@selector(setSectionHeaderTopPadding:)]) {
        [self.table setValue:@0 forKey:@"sectionHeaderTopPadding"];
    }
    self.table.dataSource = self;
    self.table.delegate = self;
    [self.view addSubview:self.table];

    self.hero = [self buildHero:w];

    CGFloat searchH = 54;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, self.hero.frame.size.height + searchH + 10)];
    [header addSubview:self.hero];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(10, self.hero.frame.size.height + 4, w - 20, searchH)];
    self.searchBar.placeholder = @"Search Needle";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.tintColor = NeedleCurrentColor();
    self.searchBar.delegate = self;
    self.searchBar.backgroundColor = [UIColor clearColor];
    UITextField *searchField = [self.searchBar valueForKey:@"searchField"];
    if ([searchField isKindOfClass:[UITextField class]]) {
        searchField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.09];
        searchField.textColor = [UIColor whiteColor];
        searchField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        searchField.layer.cornerRadius = 14;
        searchField.layer.masksToBounds = YES;
        searchField.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:@"Search Needle"
            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.42]}];
        UIImageView *leftIcon = (UIImageView *)searchField.leftView;
        if ([leftIcon isKindOfClass:[UIImageView class]]) leftIcon.tintColor = [UIColor colorWithWhite:1 alpha:0.42];
    }
    [header addSubview:self.searchBar];

    self.table.tableHeaderView = header;
}

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    NSString *q = [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    if (!q.length) {
        self.sections = self.allSections;
        [self.table reloadData];
        return;
    }
    NSMutableArray *filtered = [NSMutableArray new];
    for (NeedleSection *s in self.allSections) {
        NSMutableArray *keep = [NSMutableArray new];
        NSString *stitle = s.title.lowercaseString ?: @"";
        BOOL titleMatch = [stitle containsString:q];
        for (NeedleRow *r in s.rows) {
            NSString *l = r.label.lowercaseString ?: @"";
            NSString *sub = r.subtitle.lowercaseString ?: @"";
            if (titleMatch || [l containsString:q] || [sub containsString:q]) [keep addObject:r];
        }
        if (keep.count) {
            NeedleSection *copy = [NeedleSection new];
            copy.title = s.title;
            copy.footer = s.footer;
            copy.rows = keep;
            [filtered addObject:copy];
        }
    }
    self.sections = filtered;
    [self.table reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb { [sb resignFirstResponder]; }
- (void)searchBarCancelButtonClicked:(UISearchBar *)sb {
    sb.text = @"";
    [self searchBar:sb textDidChange:@""];
    [sb resignFirstResponder];
}

- (NeedleHeroView *)buildHero:(CGFloat)w {
    extern NSArray *NeedleReadHistory(void);

    BOOL playing = (_needleCurrentTrackCache[@"name"] != nil) && [_needleCurrentTrackCache[@"name"] length] > 0;
    CGFloat heroH = playing ? 312 : 222;
    NeedleHeroView *hero = [[NeedleHeroView alloc] initWithFrame:CGRectMake(0, 0, w, heroH)];
    hero.backgroundColor = [UIColor clearColor];
    hero.clipsToBounds = YES;

    UIColor *accent = NeedleCurrentColor();

    CGPoint vCenter = CGPointMake(w + 28, -14);
    for (CGFloat r = 44; r <= 158; r += 22) {
        CAShapeLayer *circle = [CAShapeLayer layer];
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:vCenter radius:r startAngle:0 endAngle:2 * M_PI clockwise:YES];
        circle.path = path.CGPath;
        circle.strokeColor = [[accent colorWithAlphaComponent:0.28] CGColor];
        circle.fillColor = [UIColor clearColor].CGColor;
        circle.lineWidth = 1.2;
        [hero.layer addSublayer:circle];
    }
    CAShapeLayer *vinylCore = [CAShapeLayer layer];
    UIBezierPath *coreP = [UIBezierPath bezierPathWithArcCenter:vCenter radius:9 startAngle:0 endAngle:2 * M_PI clockwise:YES];
    vinylCore.path = coreP.CGPath;
    vinylCore.fillColor = [[accent colorWithAlphaComponent:0.75] CGColor];
    [hero.layer addSublayer:vinylCore];

    CAShapeLayer *needle = [CAShapeLayer layer];
    UIBezierPath *npath = [UIBezierPath bezierPath];
    [npath moveToPoint:CGPointMake(w - 56, -22)];
    [npath addLineToPoint:CGPointMake(w + 30, 82)];
    needle.path = npath.CGPath;
    needle.strokeColor = [[accent colorWithAlphaComponent:0.55] CGColor];
    needle.lineWidth = 2.5;
    needle.lineCap = kCALineCapRound;
    [hero.layer addSublayer:needle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(w - 60, 60, 42, 42);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    close.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    close.layer.cornerRadius = 21;
    close.layer.borderWidth = 0.5;
    close.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    close.layer.shadowColor = [UIColor blackColor].CGColor;
    close.layer.shadowOffset = CGSizeMake(0, 2);
    close.layer.shadowRadius = 8;
    close.layer.shadowOpacity = 0.35;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    close.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [hero addSubview:close];

    UILabel *wordmark = [[UILabel alloc] initWithFrame:CGRectMake(22, 54, w - 90, 46)];
    wordmark.text = @"Needle";
    wordmark.textColor = [UIColor whiteColor];
    wordmark.font = [UIFont systemFontOfSize:40 weight:UIFontWeightBlack];
    [hero addSubview:wordmark];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(22, 100, w - 44, 16)];
    sub.text = [NSString stringWithFormat:@"v%@", _NeedleVersionTag()];
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.4];
    sub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [hero addSubview:sub];

    NSArray *hist = NeedleReadHistory();
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger today = [cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:[NSDate date]];
    NSInteger songsToday = 0;
    NSTimeInterval minutesToday = 0;
    NSMutableSet *activeDays = [NSMutableSet new];
    for (NSDictionary *e in hist) {
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:[e[@"when"] doubleValue]];
        NSInteger day = [cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:d];
        [activeDays addObject:@(day)];
        if (day == today) {
            songsToday++;
            minutesToday += [e[@"duration"] doubleValue];
        }
    }
    NSInteger streak = 0;
    for (NSInteger d = today; d > 0; d--) {
        if ([activeDays containsObject:@(d)]) streak++;
        else break;
    }
    NSInteger mins = (NSInteger)round(minutesToday / 60.0);

    NSArray *kpis = @[
        @{@"n": [NSString stringWithFormat:@"%ld", (long)songsToday], @"l": @"SONGS TODAY"},
        @{@"n": [NSString stringWithFormat:@"%ld", (long)streak], @"l": @"DAY STREAK"},
        @{@"n": [NSString stringWithFormat:@"%ld", (long)mins], @"l": @"MINUTES"},
    ];
    CGFloat col = (w - 44) / 3.0;
    for (NSInteger i = 0; i < kpis.count; i++) {
        NSDictionary *k = kpis[i];
        CGFloat x = 22 + i * col;
        UILabel *num = [[UILabel alloc] initWithFrame:CGRectMake(x, 138, col - 8, 40)];
        num.text = k[@"n"];
        num.textColor = [UIColor whiteColor];
        num.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBlack];
        [hero addSubview:num];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, 180, col - 8, 14)];
        NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:k[@"l"]];
        [a addAttribute:NSKernAttributeName value:@1.4 range:NSMakeRange(0, a.length)];
        [a addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:9 weight:UIFontWeightHeavy] range:NSMakeRange(0, a.length)];
        [a addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:1 alpha:0.5] range:NSMakeRange(0, a.length)];
        lbl.attributedText = a;
        [hero addSubview:lbl];
    }

    if (playing) {
        UIView *strip = [[UIView alloc] initWithFrame:CGRectMake(22, 220, w - 44, 76)];
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

        UILabel *trackLbl = [[UILabel alloc] initWithFrame:CGRectMake(36, 12, strip.frame.size.width - 86, 24)];
        trackLbl.text = _needleCurrentTrackCache[@"name"] ?: @"";
        trackLbl.textColor = [UIColor whiteColor];
        trackLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [strip addSubview:trackLbl];

        UILabel *artistLbl = [[UILabel alloc] initWithFrame:CGRectMake(36, 36, strip.frame.size.width - 86, 20)];
        artistLbl.text = _needleCurrentTrackCache[@"artist"] ?: @"";
        artistLbl.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        artistLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [strip addSubview:artistLbl];

        UIButton *qr = [UIButton buttonWithType:UIButtonTypeSystem];
        qr.frame = CGRectMake(strip.frame.size.width - 56, 16, 44, 44);
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
    extern void NeedleShowFloatingButton(void);
    extern void NeedleInstallFloatingButton(void);
    extern void NeedleInstallFloatingQR(void);
    extern void NeedleInstallFloatingRating(void);
    NeedleShowFloatingButton();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
        NeedleInstallFloatingQR();
        NeedleInstallFloatingRating();
        extern void _NeedleSyncGearVisibility(void);
        _NeedleSyncGearVisibility();
    });
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildModel {
    __weak typeof(self) weak = self;

    NeedleSection *playback = [NeedleSection new];
    playback.title = @"Playback";
    playback.rows = @[
        WITHSUB([NeedleRow sw:@"Fisher Yates shuffle" key:@"RealShuffle" def:YES symbol:@"shuffle"], @"Genuinely random instead of the usual Spotify sort."),
        WITHSUB([NeedleRow sw:@"Shuffle lock" key:@"ShuffleLock" def:NO symbol:@"lock.shield"], @"Never auto-disable shuffle between plays."),
        WITHSUB([NeedleRow sw:@"Crossfade 20 s" key:@"CrossfadeMax" def:NO symbol:@"waveform.path.ecg"], @"Lifts the hidden 12 s cap on Spotify's crossfade."),
        WITHSUB([NeedleRow sw:@"Gapless within album" key:@"GaplessAlbum" def:YES symbol:@"forward.end"], @"No silent gap between tracks of the same album."),
        WITHSUB([NeedleRow sw:@"Force 320 kbps" key:@"HighBitrate" def:NO symbol:@"4k.tv"], @"Pretend you're Premium so streaming goes to highest quality."),
        WITHSUB([NeedleRow sw:@"Free-tier unlocks" key:@"FreeUnlocks" def:NO symbol:@"crown.fill"], @"Flips client flags to pretend you're Premium (unlimited skips, on-demand play)."),
        WITHSUB([NeedleRow sw:@"Queue long-press menu" key:@"QueueGestures" def:YES symbol:@"hand.tap"], @"Long-press any queue row for Move to top / Remove."),
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
        [NeedleRow sw:@"Turntable in landscape" key:@"TurntableLandscape" def:YES symbol:@"opticaldisc"],
        [NeedleRow sw:@"Car mode in landscape" key:@"CarModeLandscape" def:NO symbol:@"car.fill"],
        [NeedleRow sw:@"Lyric artwork pulse" key:@"LyricArtworkBg" def:YES symbol:@"music.note.list"],
        WITHSUB([NeedleRow sw:@"Hide floating button" key:@"HideFloatingGear" def:NO symbol:@"circle.slash"], @"Removes the top-right gear. Long-press the now-playing bar to open Needle."),
    ];

    NeedleSection *content = [NeedleSection new];
    content.title = @"Content";
    content.rows = @[
        WITHSUB([NeedleRow sw:@"Block all ads" key:@"BlockAds" def:YES symbol:@"nosign"], @"Mutes and skips both audio and visual ads."),
        WITHSUB([NeedleRow sw:@"DNS analytics block" key:@"DNSBlock" def:YES symbol:@"shield.lefthalf.filled"], @"Drops requests to pixel.spotify.com, adeventtracker, scdn analytics."),
        WITHSUB([NeedleRow sw:@"Skip interludes" key:@"SkipInterludes" def:NO symbol:@"forward.end.alt"], @"Auto-skips tracks under 45 seconds."),
        WITHSUB([NeedleRow sw:@"Skip explicit tracks" key:@"SkipExplicit" def:NO symbol:@"e.square"], @"Auto-skips anything marked explicit."),
        WITHSUB([NeedleRow sw:@"Tap lyric opens full" key:@"LyricsTapOpensFull" def:YES symbol:@"text.quote"], @"Single lyric tap goes straight to full lyrics."),
        WITHSUB([NeedleRow sw:@"Hide Podcasts tab" key:@"HidePodcasts" def:NO symbol:@"mic.slash"], @"Removes Podcasts items from the tab bar."),
        WITHSUB([NeedleRow sw:@"Hide Audiobooks tab" key:@"HideAudiobooks" def:NO symbol:@"book.closed"], @"Removes Audiobooks items from the tab bar."),
        WITHSUB([NeedleRow sw:@"Hide premium nag" key:@"HidePremiumNag" def:NO symbol:@"nosign.app"], @"Hides the 'Upgrade to Premium' tab entries."),
        WITHSUB([NeedleRow sw:@"Playlist cloner chip" key:@"PlaylistCloner" def:YES symbol:@"square.on.square"], @"Floating Clone button on any playlist page. Opens share-to-add or copies URI."),
    ];

    NeedleSection *privacy = [NeedleSection new];
    privacy.title = @"Privacy";
    privacy.rows = @[
        WITHSUB([NeedleRow sw:@"Hide in screen recording" key:@"HideInCapture" def:NO symbol:@"eye.slash.fill"], @"Covers Spotify with a black screen whenever the phone is recording or mirrored."),
        WITHSUB([NeedleRow sw:@"Private listening" key:@"PrivateListening" def:NO symbol:@"theatermasks"], @"Stops this session from feeding into history, streaks, Wrapped."),
    ];

    NeedleSection *discover = [NeedleSection new];
    discover.title = @"Discover";
    discover.rows = @[
        [NeedleRow button:@"Share song (QR)" action:^{
            extern void NeedleOpenQRShare(void);
            NeedleOpenQRShare();
        } symbol:@"qrcode"],
        [NeedleRow button:@"Rate this song" action:^{
            extern void NeedleOpenRating(void);
            NeedleOpenRating();
        } symbol:@"star.leadinghalf.filled"],
        [NeedleRow button:@"Forgotten favorites" action:^{
            extern void NeedleOpenDormant(void);
            NeedleOpenDormant();
        } symbol:@"clock.arrow.circlepath"],
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
        WITHSUB([NeedleRow button:@"Live Wrapped" action:^{
            extern void NeedleOpenWrapped(void);
            NeedleOpenWrapped();
        } symbol:@"chart.bar.fill"], @"Up-to-date Wrapped built from your real history."),
        WITHSUB([NeedleRow button:@"Album wall" action:^{
            extern void NeedleOpenAlbumWall(void);
            NeedleOpenAlbumWall();
        } symbol:@"square.grid.2x2.fill"], @"Every album you played this year as a mosaic."),
        WITHSUB([NeedleRow button:@"Themes" action:^{
            extern void NeedleOpenThemeStore(void);
            NeedleOpenThemeStore();
        } symbol:@"paintpalette.fill"], @"Override the album-extracted palette with a fixed one."),
        WITHSUB([NeedleRow button:@"Change app icon" action:^{
            extern void NeedleOpenIconPicker(void);
            NeedleOpenIconPicker();
        } symbol:@"app.fill"], @"Six themed Spotify silhouettes you can swap on the home screen."),
    ];

    NeedleSection *about = [NeedleSection new];
    about.title = @"About";
    NSString *spotifyVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.spotify.client";
    about.rows = @[
        [NeedleRow info:@"Needle version" value:[NSString stringWithFormat:@"v%@", _NeedleVersionTag()] symbol:@"info.circle.fill"],
        [NeedleRow info:@"Spotify version" value:spotifyVer symbol:@"music.note"],
        [NeedleRow info:@"Bundle" value:bundleId symbol:@"number"],
        WITHSUB([NeedleRow button:@"What's new" action:^{
            extern void NeedleShowChangelogNow(void);
            NeedleShowChangelogNow();
        } symbol:@"sparkles"], @"Recent changelog for this build."),
        WITHSUB([NeedleRow button:@"GitHub repo" action:^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/rencito974/needle"] options:@{} completionHandler:nil];
        } symbol:@"chevron.left.forwardslash.chevron.right"], @"Source, issues, release notes."),
        WITHSUB([NeedleRow button:@"Check for updates" action:^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/rencito974/needle/releases/latest"] options:@{} completionHandler:nil];
        } symbol:@"arrow.down.circle.fill"], @"Jump to the latest release page."),
    ];
    about.footer = [NSString stringWithFormat:@"Needle v%@ running on Spotify %@. Built by Renzo.", _NeedleVersionTag(), spotifyVer];

    self.sections = @[discover, playback, look, content, privacy, sleep, you, about];
    self.allSections = self.sections;
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
    cell.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1];
    cell.textLabel.hidden = YES;
    cell.imageView.hidden = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIView *content = cell.contentView;
    BOOL isSlider = row.kind == NeedleRowSlider;
    BOOL hasSubtitle = row.subtitle.length > 0;

    if (row.symbol) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        UIImageView *iv = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:row.symbol withConfiguration:cfg]];
        iv.tintColor = [UIColor colorWithWhite:1 alpha:0.75];
        iv.contentMode = UIViewContentModeCenter;
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:iv];
        [NSLayoutConstraint activateConstraints:@[
            [iv.widthAnchor constraintEqualToConstant:26],
            [iv.heightAnchor constraintEqualToConstant:26],
            [iv.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:18],
        ]];
        if (isSlider || hasSubtitle) {
            [iv.topAnchor constraintEqualToAnchor:content.topAnchor constant:14].active = YES;
        } else {
            [iv.centerYAnchor constraintEqualToAnchor:content.centerYAnchor].active = YES;
        }
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = row.label;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:row.symbol ? 56 : 18],
    ]];
    if (isSlider || hasSubtitle) {
        [label.topAnchor constraintEqualToAnchor:content.topAnchor constant:12].active = YES;
    } else {
        [label.centerYAnchor constraintEqualToAnchor:content.centerYAnchor].active = YES;
    }

    UILabel *subLbl = nil;
    if (hasSubtitle) {
        subLbl = [[UILabel alloc] init];
        subLbl.text = row.subtitle;
        subLbl.textColor = [UIColor colorWithWhite:1 alpha:0.52];
        subLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        subLbl.numberOfLines = 0;
        subLbl.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:subLbl];
        [NSLayoutConstraint activateConstraints:@[
            [subLbl.leadingAnchor constraintEqualToAnchor:label.leadingAnchor],
            [subLbl.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:3],
            [subLbl.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-70],
            [subLbl.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
        ]];
    }

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
            [chev.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
            [chev.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        ]];
    } else if (row.kind == NeedleRowInfo) {
        UILabel *val = [[UILabel alloc] init];
        val.text = row.detailValue;
        val.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        val.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
        val.textAlignment = NSTextAlignmentRight;
        val.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:val];
        [NSLayoutConstraint activateConstraints:@[
            [val.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
            [val.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
            [val.widthAnchor constraintLessThanOrEqualToConstant:200],
        ]];
    } else if (row.kind == NeedleRowSlider) {
        float cur = NeedlePrefFloat(row.prefKey, row.defaultFloat);
        if (cur < row.minFloat) cur = row.minFloat;
        if (cur > row.maxFloat) cur = row.maxFloat;

        UILabel *val = [[UILabel alloc] init];
        val.text = [NSString stringWithFormat:@"%.2f%@", cur, row.suffix ?: @""];
        val.textColor = NeedleCurrentColor();
        val.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightBold];
        val.textAlignment = NSTextAlignmentRight;
        val.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:val];
        [NSLayoutConstraint activateConstraints:@[
            [val.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-22],
            [val.topAnchor constraintEqualToAnchor:content.topAnchor constant:14],
            [val.widthAnchor constraintGreaterThanOrEqualToConstant:60],
        ]];

        UISlider *slider = [[UISlider alloc] init];
        slider.minimumValue = row.minFloat;
        slider.maximumValue = row.maxFloat;
        slider.value = cur;
        slider.continuous = YES;
        slider.minimumTrackTintColor = NeedleCurrentColor();
        slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.14];
        slider.translatesAutoresizingMaskIntoConstraints = NO;
        objc_setAssociatedObject(slider, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(slider, "_needleValLbl", val, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(slider, "_needleSuffix", row.suffix ?: @"", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [content addSubview:slider];
        [NSLayoutConstraint activateConstraints:@[
            [slider.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:row.symbol ? 62 : 22],
            [slider.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-22],
            [slider.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-14],
        ]];
    }

    if (!last) {
        UIView *sep = [[UIView alloc] init];
        sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:sep];
        [NSLayoutConstraint activateConstraints:@[
            [sep.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:row.symbol ? 56 : 18],
            [sep.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
            [sep.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
            [sep.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    NeedleRow *row = self.sections[ip.section].rows[ip.row];
    if (row.kind == NeedleRowSlider) return 80;
    return UITableViewAutomaticDimension;
}

- (void)switchFlipped:(UISwitch *)sw {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    NSString *key = objc_getAssociatedObject(sw, "_needleKey");
    if (key) NeedlePrefSetBool(key, sw.on);
}

- (void)sliderChanged:(UISlider *)slider {
    NSString *key = objc_getAssociatedObject(slider, "_needleKey");
    UILabel *val = objc_getAssociatedObject(slider, "_needleValLbl");
    NSString *sfx = objc_getAssociatedObject(slider, "_needleSuffix");
    float v = slider.value;
    val.text = [NSString stringWithFormat:@"%.2f%@", v, sfx ?: @""];
    if (key) NeedlePrefSetFloat(key, v);
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return self.sections[s].title;
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    return self.sections[s].footer;
}

- (void)tableView:(UITableView *)t willDisplayHeaderView:(UIView *)view forSection:(NSInteger)s {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *h = (UITableViewHeaderFooterView *)view;
        h.textLabel.textColor = [UIColor colorWithWhite:1 alpha:0.5];
        h.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        h.textLabel.text = self.sections[s].title;
    }
}

- (void)tableView:(UITableView *)t willDisplayFooterView:(UIView *)view forSection:(NSInteger)s {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *f = (UITableViewHeaderFooterView *)view;
        f.textLabel.textColor = [UIColor colorWithWhite:1 alpha:0.38];
        f.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        f.textLabel.numberOfLines = 0;
    }
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

    UIView *anchor = g.view;
    if (!anchor || !anchor.superview) return;
    UIWindow *win = (UIWindow *)anchor.superview;
    if (![win isKindOfClass:[UIWindow class]]) win = anchor.window;
    if (!win) return;

    for (UIView *v in [win.subviews copy]) {
        if (v.tag == 0x4E474D54) [v removeFromSuperview];
    }

    BOOL trackCached = (_needleCurrentTrackCache[@"name"] != nil) && [_needleCurrentTrackCache[@"name"] length] > 0;

    NSMutableArray *items = [NSMutableArray new];
    if (trackCached) {
        [items addObject:@{@"t": @"QR share", @"s": @"qrcode", @"a": @"qr"}];
        [items addObject:@{@"t": @"Rate song", @"s": @"star.fill", @"a": @"rate"}];
    }
    [items addObject:@{@"t": @"Settings", @"s": @"slider.horizontal.3", @"a": @"settings"}];

    UIView *dim = [[UIView alloc] initWithFrame:win.bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.0];
    dim.tag = 0x4E474D54;
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [win addSubview:dim];

    CGFloat itemSize = 72;
    CGFloat gap = 10;
    CGFloat pad = 14;
    NSInteger n = items.count;
    CGFloat popW = n * itemSize + (n - 1) * gap + pad * 2;
    CGFloat popH = itemSize + 42 + pad * 2;

    CGPoint anchorCenter = [anchor convertPoint:CGPointMake(anchor.bounds.size.width / 2, anchor.bounds.size.height) toView:win];
    CGFloat popX = anchorCenter.x - popW + anchor.bounds.size.width / 2 + 10;
    if (popX < 14) popX = 14;
    if (popX + popW > win.bounds.size.width - 14) popX = win.bounds.size.width - 14 - popW;
    CGFloat popY = anchorCenter.y + 10;

    UIView *pop = [[UIView alloc] initWithFrame:CGRectMake(popX, popY, popW, popH)];
    pop.layer.cornerRadius = 22;
    pop.layer.borderWidth = 0.5;
    pop.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    pop.layer.shadowColor = [UIColor blackColor].CGColor;
    pop.layer.shadowOffset = CGSizeMake(0, 10);
    pop.layer.shadowRadius = 22;
    pop.layer.shadowOpacity = 0.45;
    pop.clipsToBounds = NO;
    [dim addSubview:pop];

    UIVisualEffectView *vfx = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    vfx.frame = pop.bounds;
    vfx.layer.cornerRadius = 22;
    vfx.layer.masksToBounds = YES;
    vfx.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [pop addSubview:vfx];

    UIView *accentWash = [[UIView alloc] initWithFrame:pop.bounds];
    accentWash.backgroundColor = [NeedleCurrentColor() colorWithAlphaComponent:0.10];
    accentWash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vfx.contentView addSubview:accentWash];

    for (NSInteger i = 0; i < n; i++) {
        NSDictionary *it = items[i];
        CGFloat x = pad + i * (itemSize + gap);
        UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(x, pad, itemSize, itemSize + 42)];

        UIView *circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, itemSize, itemSize)];
        circle.backgroundColor = [NeedleCurrentColor() colorWithAlphaComponent:0.18];
        circle.layer.cornerRadius = itemSize / 2;
        circle.layer.borderWidth = 0.5;
        circle.layer.borderColor = [NeedleCurrentColor() colorWithAlphaComponent:0.55].CGColor;
        [cell addSubview:circle];

        UIImageView *iv = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:it[@"s"] withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightBold]]];
        iv.tintColor = [UIColor whiteColor];
        iv.contentMode = UIViewContentModeCenter;
        iv.frame = circle.bounds;
        [circle addSubview:iv];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-8, itemSize + 6, itemSize + 16, 24)];
        lbl.text = it[@"t"];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        lbl.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:lbl];

        cell.tag = i + 1;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
            initWithTarget:[NeedleSettingsViewController class] action:@selector(_needleMenuCellTap:)];
        [cell addGestureRecognizer:tap];
        objc_setAssociatedObject(cell, "_needleAction", it[@"a"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, "_needleDim", dim, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [vfx.contentView addSubview:cell];
    }

    pop.transform = CGAffineTransformMakeScale(0.4, 0.4);
    pop.alpha = 0;
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.9 options:0 animations:^{
        pop.transform = CGAffineTransformIdentity;
        pop.alpha = 1;
        dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.18];
    } completion:nil];

    UITapGestureRecognizer *outTap = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class] action:@selector(_needleMenuDismiss:)];
    [dim addGestureRecognizer:outTap];
    objc_setAssociatedObject(outTap, "_needleDim", dim, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)_needleMenuCellTap:(UITapGestureRecognizer *)g {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    NSString *action = objc_getAssociatedObject(g.view, "_needleAction");
    UIView *dim = objc_getAssociatedObject(g.view, "_needleDim");
    [UIView animateWithDuration:0.18 animations:^{
        g.view.transform = CGAffineTransformMakeScale(0.9, 0.9);
        dim.alpha = 0;
    } completion:^(BOOL _){
        [dim removeFromSuperview];
        if ([action isEqualToString:@"qr"]) { extern void NeedleOpenQRShare(void); NeedleOpenQRShare(); }
        else if ([action isEqualToString:@"rate"]) { extern void NeedleOpenRating(void); NeedleOpenRating(); }
        else if ([action isEqualToString:@"settings"]) { extern void NeedleOpenSettings(void); NeedleOpenSettings(); }
    }];
}

+ (void)_needleMenuDismiss:(UITapGestureRecognizer *)g {
    UIView *dim = g.view;
    CGPoint loc = [g locationInView:dim];
    for (UIView *sub in dim.subviews) {
        if (CGRectContainsPoint(sub.frame, loc)) return;
    }
    [UIView animateWithDuration:0.18 animations:^{ dim.alpha = 0; } completion:^(BOOL _){ [dim removeFromSuperview]; }];
}

+ (void)_needleQRFloatTap:(UITapGestureRecognizer *)g {
    extern void NeedleOpenQRShare(void);
    NeedleOpenQRShare();
}

+ (void)_needleRatingFloatTap:(UITapGestureRecognizer *)g {
    extern void NeedleOpenRating(void);
    NeedleOpenRating();
}

+ (void)_needleGearPan:(UIPanGestureRecognizer *)g {
    UIView *host = g.view;
    if (!host || !host.superview) return;
    CGPoint t = [g translationInView:host.superview];
    host.center = CGPointMake(host.center.x + t.x, host.center.y + t.y);
    [g setTranslation:CGPointZero inView:host.superview];
    extern void _NeedleReflowFloatsIfNeeded(void);
    _NeedleReflowFloatsIfNeeded();
    if (g.state == UIGestureRecognizerStateEnded) {
        CGRect bounds = host.superview.bounds;
        CGFloat edge = host.frame.size.width;
        CGFloat x = host.center.x < bounds.size.width / 2 ? edge / 2 + 12 + edge * 2 + 20 : bounds.size.width - edge / 2 - 12;
        [UIView animateWithDuration:0.25 animations:^{
            host.center = CGPointMake(x, host.center.y);
            _NeedleReflowFloatsIfNeeded();
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

@interface _NeedleGestureBridge : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
@end
@implementation _NeedleGestureBridge
+ (instancetype)shared {
    static _NeedleGestureBridge *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    return YES;
}
@end

static void _NeedleAttachLongPress(UIView *view) {
    if (!view) return;
    static char _lpKey;
    if (objc_getAssociatedObject(view, &_lpKey)) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleLongPress:)];
    lp.minimumPressDuration = 0.45;
    lp.cancelsTouchesInView = NO;
    lp.delaysTouchesBegan = NO;
    lp.delaysTouchesEnded = NO;
    lp.delegate = [_NeedleGestureBridge shared];
    [view addGestureRecognizer:lp];
    objc_setAssociatedObject(view, &_lpKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    static char _tpKey;
    if (objc_getAssociatedObject(view, &_tpKey)) return;
    UITapGestureRecognizer *triple = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleTripleTap:)];
    triple.numberOfTapsRequired = 3;
    triple.cancelsTouchesInView = NO;
    triple.delegate = [_NeedleGestureBridge shared];
    [view addGestureRecognizer:triple];
    objc_setAssociatedObject(view, &_tpKey, triple, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface SPTNowPlayingView : UIView
@end

%hook SPTNowPlayingBar
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    _NeedleAttachLongPress(self);
}
%end

%hook SPTNowPlayingView
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    _NeedleAttachLongPress(self);
}
%end

static UIView *_needleFloatingHost = nil;
static UIView *_needleFloatingQR = nil;
static UIView *_needleFloatingRating = nil;
static BOOL _needleFloatingHidden = NO;

__attribute__((unused))
static BOOL _NeedleTrackIsCached(void) {
    return (_needleCurrentTrackCache[@"name"] != nil) && [_needleCurrentTrackCache[@"name"] length] > 0;
}

void NeedleHideFloatingButton(void) {
    _needleFloatingHidden = YES;
    if (_needleFloatingHost) _needleFloatingHost.hidden = YES;
    if (_needleFloatingQR) _needleFloatingQR.hidden = YES;
    if (_needleFloatingRating) _needleFloatingRating.hidden = YES;
}

void NeedleShowFloatingButton(void) {
    _needleFloatingHidden = NO;
    if (_needleFloatingHost) _needleFloatingHost.hidden = NO;
    if (_needleFloatingQR) _needleFloatingQR.hidden = YES;
    if (_needleFloatingRating) _needleFloatingRating.hidden = YES;
}

void _NeedleSyncGearVisibility(void) {
    if (_needleFloatingHost) _needleFloatingHost.hidden = _needleFloatingHidden;
    if (_needleFloatingQR) _needleFloatingQR.hidden = YES;
    if (_needleFloatingRating) _needleFloatingRating.hidden = YES;
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

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
    UIImage *icon = [UIImage systemImageNamed:@"waveform.circle.fill" withConfiguration:cfg];
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

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleLongPress:)];
    lp.minimumPressDuration = 0.4;
    [host addGestureRecognizer:lp];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleGearPan:)];
    [host addGestureRecognizer:pan];
    return host;
}

static void _NeedleInstallWindowLongPress(UIWindow *w);

void NeedleInstallFloatingButton(void) {
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

    _NeedleInstallWindowLongPress(target);

    if (NeedlePrefBool(@"HideFloatingGear", NO)) {
        if (_needleFloatingHost) {
            [_needleFloatingHost removeFromSuperview];
            _needleFloatingHost = nil;
        }
        return;
    }

    if (_needleFloatingHost && _needleFloatingHost.superview == target) {
        [target bringSubviewToFront:_needleFloatingHost];
        return;
    }
    if (_needleFloatingHost) [_needleFloatingHost removeFromSuperview];

    CGFloat btnSize = 36;
    CGFloat topInset = target.safeAreaInsets.top > 0 ? target.safeAreaInsets.top : 60;
    CGFloat y = topInset + 80;
    CGRect frame = CGRectMake(target.bounds.size.width - btnSize - 14, y, btnSize, btnSize);
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

__attribute__((unused))
static UIView *_NeedleBuildQRFloat(CGRect frame) {
    UIView *host = [[UIView alloc] initWithFrame:frame];
    host.backgroundColor = [UIColor clearColor];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOffset = CGSizeMake(0, 4);
    host.layer.shadowRadius = 10;
    host.layer.shadowOpacity = 0.4;

    UIView *bg = [[UIView alloc] initWithFrame:host.bounds];
    bg.backgroundColor = NeedleCurrentColor();
    bg.layer.cornerRadius = frame.size.width / 2;
    bg.layer.borderWidth = 0.5;
    bg.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.32].CGColor;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:bg];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightBold];
    UIImage *icon = [UIImage systemImageNamed:@"qrcode" withConfiguration:cfg];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = host.bounds;
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:iv];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleQRFloatTap:)];
    [host addGestureRecognizer:tap];
    return host;
}

void NeedleInstallFloatingQR(void) {
    if (_needleFloatingQR) {
        [_needleFloatingQR removeFromSuperview];
        _needleFloatingQR = nil;
    }
}

__attribute__((unused))
static UIView *_NeedleBuildRatingFloat(CGRect frame) {
    UIView *host = [[UIView alloc] initWithFrame:frame];
    host.backgroundColor = [UIColor clearColor];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOffset = CGSizeMake(0, 4);
    host.layer.shadowRadius = 10;
    host.layer.shadowOpacity = 0.4;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
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
    tint.backgroundColor = [[NeedleCurrentColor() colorWithAlphaComponent:0.22] copy];
    tint.layer.cornerRadius = frame.size.width / 2;
    [vfx.contentView addSubview:tint];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightBold];
    UIImage *icon = [UIImage systemImageNamed:@"star.fill" withConfiguration:cfg];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = NeedleCurrentColor();
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = host.bounds;
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vfx.contentView addSubview:iv];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleRatingFloatTap:)];
    [host addGestureRecognizer:tap];
    return host;
}

void NeedleInstallFloatingRating(void) {
    if (_needleFloatingRating) {
        [_needleFloatingRating removeFromSuperview];
        _needleFloatingRating = nil;
    }
}

void _NeedleReflowFloatsImpl(UIWindow *w) {
    if (!_needleFloatingHost || _needleFloatingHost.superview != w) return;
    CGPoint gearCenter = _needleFloatingHost.center;
    CGFloat btnSize = _needleFloatingHost.frame.size.width;
    CGFloat gap = 10;
    BOOL leftSide = gearCenter.x < w.bounds.size.width / 2.0;
    CGFloat direction = leftSide ? 1.0 : -1.0;
    if (_needleFloatingQR && _needleFloatingQR.superview == w) {
        CGFloat x = gearCenter.x + direction * (btnSize + gap);
        _needleFloatingQR.center = CGPointMake(x, gearCenter.y);
    }
    if (_needleFloatingRating && _needleFloatingRating.superview == w) {
        CGFloat x = gearCenter.x + direction * (btnSize + gap) * 2.0;
        _needleFloatingRating.center = CGPointMake(x, gearCenter.y);
    }
}

void _NeedleReflowFloatsIfNeeded(void) {
    if (!_needleFloatingHost) return;
    UIWindow *w = (UIWindow *)_needleFloatingHost.superview;
    if (![w isKindOfClass:[UIWindow class]]) return;
    _NeedleReflowFloatsImpl(w);
}

static void _NeedleReflowFloats(UIWindow *w) {
    _NeedleReflowFloatsImpl(w);
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
        if (!_needleFloatingQR || _needleFloatingQR.superview != self) {
            NeedleInstallFloatingQR();
        } else {
            [self bringSubviewToFront:_needleFloatingQR];
        }
        if (!_needleFloatingRating || _needleFloatingRating.superview != self) {
            NeedleInstallFloatingRating();
        } else {
            [self bringSubviewToFront:_needleFloatingRating];
        }
        _NeedleReflowFloats(self);
    }
}
%end

static NSTimer *_needleInstallTimer = nil;

static void NeedleStartInstallWatchdog(void) {
    if (_needleInstallTimer) return;
    _needleInstallTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *t) {
        NeedleInstallFloatingButton();
        NeedleInstallFloatingQR();
        NeedleInstallFloatingRating();
    }];
}

static NSInteger _needleActiveNeedleVCCount = 0;

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls hasPrefix:@"Needle"]) {
        _needleActiveNeedleVCCount++;
        NeedleHideFloatingButton();
        return;
    }
    if (_needleActiveNeedleVCCount <= 0) {
        NeedleShowFloatingButton();
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
        NeedleInstallFloatingQR();
        NeedleInstallFloatingRating();
        _NeedleSyncGearVisibility();
    });
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls hasPrefix:@"Needle"]) {
        _needleActiveNeedleVCCount--;
        if (_needleActiveNeedleVCCount < 0) _needleActiveNeedleVCCount = 0;
        if (_needleActiveNeedleVCCount == 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleShowFloatingButton();
                NeedleInstallFloatingButton();
            });
        }
    }
}
%end

static UILongPressGestureRecognizer *_needleWindowLP = nil;

@interface NeedleSettingsViewController (WindowLP)
+ (void)_needleWindowLongPress:(UILongPressGestureRecognizer *)g;
@end

@implementation NeedleSettingsViewController (WindowLP)
+ (void)_needleWindowLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIWindow *w = (UIWindow *)g.view;
    CGPoint pt = [g locationInView:w];
    CGFloat h = w.bounds.size.height;
    if (pt.y < h - 160) return;
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    extern void NeedleOpenSettings(void);
    NeedleOpenSettings();
}
@end

static void _NeedleInstallWindowLongPress(UIWindow *w) {
    if (!w) return;
    static char _wlpKey;
    if (objc_getAssociatedObject(w, &_wlpKey)) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleWindowLongPress:)];
    lp.minimumPressDuration = 0.6;
    lp.cancelsTouchesInView = NO;
    lp.delaysTouchesBegan = NO;
    lp.delaysTouchesEnded = NO;
    lp.delegate = [_NeedleGestureBridge shared];
    [w addGestureRecognizer:lp];
    objc_setAssociatedObject(w, &_wlpKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _needleWindowLP = lp;
}

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
            _needleActiveNeedleVCCount = 0;
            _needleFloatingHidden = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleInstallFloatingButton();
                NeedleInstallFloatingQR();
                NeedleInstallFloatingRating();
                NeedleStartInstallWatchdog();
            });
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NeedleInstallFloatingButton();
                NeedleInstallFloatingQR();
                NeedleInstallFloatingRating();
                NeedleStartInstallWatchdog();
            });
        }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleInstallFloatingButton();
        NeedleInstallFloatingQR();
        NeedleInstallFloatingRating();
        NeedleStartInstallWatchdog();
    });
}
