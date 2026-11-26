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
@property (nonatomic, assign) BOOL defaultBool;
@property (nonatomic, copy) void (^action)(void);
@end

@implementation NeedleRow
+ (instancetype)sw:(NSString *)label key:(NSString *)key def:(BOOL)def {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowSwitch;
    r.label = label;
    r.prefKey = key;
    r.defaultBool = def;
    return r;
}
+ (instancetype)text:(NSString *)label key:(NSString *)key placeholder:(NSString *)ph {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowText;
    r.label = label;
    r.prefKey = key;
    r.placeholder = ph;
    return r;
}
+ (instancetype)button:(NSString *)label action:(void (^)(void))action {
    NeedleRow *r = [NeedleRow new];
    r.kind = NeedleRowButton;
    r.label = label;
    r.action = action;
    return r;
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
    NeedleSection *premium = [NeedleSection new];
    premium.title = @"Premium flags";
    premium.rows = @[
        [NeedleRow sw:@"Premium flags on" key:@"PremiumOn" def:YES],
        [NeedleRow sw:@"Block ads" key:@"AdsBlocked" def:YES],
        [NeedleRow sw:@"Block telemetry" key:@"TelemetryBlocked" def:YES],
    ];
    premium.footer = @"Hooks the entitlement predicates Spotify checks before enabling paid features.";

    NeedleSection *playback = [NeedleSection new];
    playback.title = @"Playback";
    playback.rows = @[
        [NeedleRow sw:@"Fisher Yates shuffle" key:@"RealShuffle" def:YES],
        [NeedleRow sw:@"Disable Canvas video" key:@"CanvasOff" def:NO],
    ];

    NeedleSection *look = [NeedleSection new];
    look.title = @"Look";
    look.rows = @[
        [NeedleRow sw:@"Album colored Now Playing" key:@"AlbumColorUI" def:YES],
        [NeedleRow sw:@"Apple Music lockscreen art" key:@"BigLockscreenArt" def:YES],
    ];

    __weak typeof(self) weak = self;
    NeedleSection *scrobble = [NeedleSection new];
    scrobble.title = @"Last.fm scrobble";
    scrobble.rows = @[
        [NeedleRow sw:@"Scrobble plays" key:@"ScrobbleOn" def:NO],
        [NeedleRow text:@"API key" key:@"LastFmApiKey" placeholder:@"paste here"],
        [NeedleRow text:@"Shared secret" key:@"LastFmSecret" placeholder:@"paste here"],
        [NeedleRow text:@"Session key" key:@"LastFmSession" placeholder:@"paste from auth"],
        [NeedleRow button:@"Open Last.fm sign in" action:^{
            NSString *apiKey = NeedlePrefString(@"LastFmApiKey");
            if (!apiKey.length) {
                [weak alert:@"API key missing" message:@"Paste your Last.fm API key first."];
                return;
            }
            NSString *url = [NSString stringWithFormat:@"https://www.last.fm/api/auth/?api_key=%@", apiKey];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
        }],
    ];
    scrobble.footer = @"Register at last.fm/api/account/create, paste the key and secret, tap Open Last.fm sign in, approve, then paste the session token out of the redirect URL into Session key.";

    NeedleSection *about = [NeedleSection new];
    about.rows = @[
        [NeedleRow button:@"Needle on Discord" action:^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/4Fk34R76tt"] options:@{} completionHandler:nil];
        }],
    ];
    about.footer = @"Needle v1.0 by Renzo. Discord @renzoo7646.";

    self.sections = @[premium, playback, look, scrobble, about];
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
    cell.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.6];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.text = row.label;

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
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    return cell;
}

- (void)switchFlipped:(UISwitch *)sw {
    NSString *key = objc_getAssociatedObject(sw, "_needleKey");
    if (key) NeedlePrefSetBool(key, sw.on);
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
    if (row.kind == NeedleRowButton && row.action) row.action();
}

+ (void)_needleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
        extern void NeedleOpenSettings(void);
        NeedleOpenSettings();
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

%hook SPTNowPlayingBar
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    static char _lpKey;
    if (objc_getAssociatedObject(self, &_lpKey)) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[NeedleSettingsViewController class]
        action:@selector(_needleLongPress:)];
    lp.minimumPressDuration = 0.6;
    [self addGestureRecognizer:lp];
    objc_setAssociatedObject(self, &_lpKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
                message:@"Long press the Now Playing bar at the bottom to open settings."
                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Got it" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
                NeedlePrefSetBool(@"HasSeenWelcome", YES);
            }]];
            [top presentViewController:a animated:YES completion:nil];
        });
    }
}
