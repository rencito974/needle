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
    self.bgLayer = [CAGradientLayer layer];
    UIColor *top = NeedleCurrentColor();
    UIColor *bot = [UIColor colorWithWhite:0.02 alpha:1.0];
    self.bgLayer.colors = @[(id)top.CGColor, (id)bot.CGColor];
    self.bgLayer.locations = @[@0.0, @0.6];
    self.bgLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bgLayer.endPoint = CGPointMake(0.5, 1.0);
    self.bgLayer.frame = root.bounds;
    [root.layer insertSublayer:self.bgLayer atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildModel];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 88)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 44, 200, 36)];
    title.text = @"Needle";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    [header addSubview:title];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(self.view.bounds.size.width - 60, 48, 40, 28);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [close setTitle:@"Done" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];
    [self.view addSubview:header];

    self.table = [[UITableView alloc] initWithFrame:
        CGRectMake(0, 88, self.view.bounds.size.width, self.view.bounds.size.height - 88)
        style:UITableViewStyleInsetGrouped];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.table.dataSource = self;
    self.table.delegate = self;
    [self.view addSubview:self.table];
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
        [NeedleRow button:@"Needle on Discord" action:^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/4Fk34R76tt"] options:@{} completionHandler:nil];
        } symbol:@"bubble.left.and.bubble.right"],
    ];
    about.footer = @"Needle v1.1 by Renzo. Discord @renzoo7646.";

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
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.75];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.text = row.label;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.imageView.tintColor = NeedleCurrentColor();
    if (row.symbol) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        UIImage *icon = [UIImage systemImageNamed:row.symbol withConfiguration:cfg];
        cell.imageView.image = icon;
    }

    if (row.kind == NeedleRowSwitch) {
        UISwitch *sw = [UISwitch new];
        sw.on = NeedlePrefBool(row.prefKey, row.defaultBool);
        sw.onTintColor = NeedleCurrentColor();
        objc_setAssociatedObject(sw, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(switchFlipped:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (row.kind == NeedleRowText) {
        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 32)];
        tf.text = NeedlePrefString(row.prefKey);
        tf.placeholder = row.placeholder;
        tf.textColor = [UIColor whiteColor];
        tf.textAlignment = NSTextAlignmentRight;
        tf.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.returnKeyType = UIReturnKeyDone;
        tf.delegate = self;
        objc_setAssociatedObject(tf, "_needleKey", row.prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        cell.accessoryView = tf;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (row.kind == NeedleRowButton) {
        cell.textLabel.textColor = NeedleCurrentColor();
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
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
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(20, 28, 3, 14)];
    bar.backgroundColor = NeedleCurrentColor();
    bar.layer.cornerRadius = 1.5;
    [header addSubview:bar];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(32, 22, t.bounds.size.width - 60, 20)];
    lbl.text = sec.title.uppercaseString;
    lbl.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [header addSubview:lbl];
    return header;
}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s {
    return self.sections[s].title.length ? 44 : 10;
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

static void NeedleInstallFloatingButton(void) {
    UIWindow *key = nil;
    NSArray *scenes = [[UIApplication sharedApplication].connectedScenes allObjects];
    for (UIScene *s in scenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w.isKeyWindow) { key = w; break; }
            }
            if (key) break;
        }
    }
    if (!key) return;
    if (_needleFloatingHost && _needleFloatingHost.window == key) return;
    if (_needleFloatingHost) {
        [_needleFloatingHost removeFromSuperview];
        _needleFloatingHost = nil;
    }

    CGFloat btnSize = 44;
    CGRect frame = CGRectMake(key.bounds.size.width - btnSize - 12, 70, btnSize, btnSize);
    _needleFloatingHost = [[UIView alloc] initWithFrame:frame];
    _needleFloatingHost.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    _needleFloatingHost.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    _needleFloatingHost.layer.cornerRadius = btnSize / 2;
    _needleFloatingHost.layer.shadowColor = [UIColor blackColor].CGColor;
    _needleFloatingHost.layer.shadowOffset = CGSizeMake(0, 2);
    _needleFloatingHost.layer.shadowRadius = 6;
    _needleFloatingHost.layer.shadowOpacity = 0.4;
    _needleFloatingHost.alpha = 0.78;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightBold];
    UIImage *icon = [UIImage systemImageNamed:@"gearshape.fill" withConfiguration:cfg];
    UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = _needleFloatingHost.bounds;
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_needleFloatingHost addSubview:iv];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleGearTap:)];
    [_needleFloatingHost addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleGearPan:)];
    [_needleFloatingHost addGestureRecognizer:pan];

    [key addSubview:_needleFloatingHost];
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NeedleInstallFloatingButton();
        });
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
    static BOOL announced = NO;
    if (!announced && !NeedlePrefBool(@"HasSeenWelcome", NO)) {
        announced = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIViewController *top = _NeedleTopVC();
            if (!top) return;
            UIAlertController *a = [UIAlertController
                alertControllerWithTitle:@"Needle installed"
                message:@"Open settings by: long-pressing the mini player, shaking the phone, or three-finger-triple-tap anywhere."
                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Got it" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
                NeedlePrefSetBool(@"HasSeenWelcome", YES);
            }]];
            [top presentViewController:a animated:YES completion:nil];
        });
    }
}
