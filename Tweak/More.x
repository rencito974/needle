#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

extern UIColor *NeedleCurrentColor(void);
extern NSArray *NeedleReadHistory(void);
extern NSString *NeedlePrefString(NSString *key);
extern void NeedlePrefSetString(NSString *key, NSString *val);

extern NSMutableDictionary *_needleCurrentTrackCache;

static NSString *NeedleCurrentTrackURI(void) {
    return _needleCurrentTrackCache[@"uri"];
}

static NSDictionary *NeedleCurrentTrackInfo(void) {
    if (_needleCurrentTrackCache && [_needleCurrentTrackCache[@"name"] length] > 0) {
        return [_needleCurrentTrackCache copy];
    }
    NSDictionary *np = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
    id name = np[MPMediaItemPropertyTitle];
    if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
        NSMutableDictionary *m = [NSMutableDictionary new];
        m[@"name"] = name;
        id artist = np[MPMediaItemPropertyArtist];
        id album = np[MPMediaItemPropertyAlbumTitle];
        if ([artist isKindOfClass:[NSString class]]) m[@"artist"] = artist;
        if ([album isKindOfClass:[NSString class]]) m[@"album"] = album;
        return m;
    }
    return nil;
}

static UIImage *NeedleQRFor(NSString *payload) {
    CIFilter *f = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [f setValue:[payload dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [f setValue:@"H" forKey:@"inputCorrectionLevel"];
    CIImage *img = f.outputImage;
    if (!img) return nil;
    CGAffineTransform t = CGAffineTransformMakeScale(16, 16);
    img = [img imageByApplyingTransform:t];
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cg = [ctx createCGImage:img fromRect:img.extent];
    UIImage *out = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return out;
}

@interface NeedleQRShareViewController : UIViewController
@end

@implementation NeedleQRShareViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.35].CGColor, (id)[UIColor blackColor].CGColor];
    bg.locations = @[@0.0, @0.5];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;

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
    title.text = @"Share song";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    NSString *uri = NeedleCurrentTrackURI();
    NSDictionary *info = NeedleCurrentTrackInfo();

    NSString *url = uri.length ? [NSString stringWithFormat:@"https://open.spotify.com/track/%@", [uri stringByReplacingOccurrencesOfString:@"spotify:track:" withString:@""]] : @"https://open.spotify.com";
    UIImage *qr = NeedleQRFor(url);

    CGFloat side = w - 80;
    UIImageView *qrView = [[UIImageView alloc] initWithFrame:CGRectMake(40, 150, side, side)];
    qrView.image = qr;
    qrView.backgroundColor = [UIColor whiteColor];
    qrView.contentMode = UIViewContentModeScaleAspectFit;
    qrView.layer.cornerRadius = 24;
    qrView.layer.masksToBounds = YES;
    [self.view addSubview:qrView];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(24, 150 + side + 20, w - 48, 30)];
    name.text = info[@"name"] ?: @"No track playing";
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    name.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:name];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(24, 150 + side + 50, w - 48, 24)];
    artist.text = info[@"artist"] ?: @"";
    artist.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    artist.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    artist.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:artist];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void NeedleOpenQRShare(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleQRShareViewController *vc = [NeedleQRShareViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}

@interface NeedleQRActivity : UIActivity
@property (nonatomic, copy) NSString *shareURL;
@end

@implementation NeedleQRActivity
- (NSString *)activityType { return @"com.needle.qrshare"; }
- (NSString *)activityTitle { return @"QR code"; }
- (UIImage *)activityImage {
    return [UIImage systemImageNamed:@"qrcode" withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightRegular]];
}
+ (UIActivityCategory)activityCategory { return UIActivityCategoryShare; }
- (BOOL)canPerformWithActivityItems:(NSArray *)items {
    return YES;
}
- (void)prepareWithActivityItems:(NSArray *)items {
    for (id it in items) {
        if ([it isKindOfClass:[NSURL class]]) { self.shareURL = [it absoluteString]; return; }
        if ([it isKindOfClass:[NSString class]]) {
            NSString *s = it;
            if ([s hasPrefix:@"http"] || [s hasPrefix:@"spotify:"]) { self.shareURL = s; return; }
        }
    }
    NSString *uri = _needleCurrentTrackCache[@"uri"];
    if (uri.length) self.shareURL = uri;
}
- (void)performActivity {
    NSString *url = self.shareURL;
    if ([url hasPrefix:@"spotify:track:"]) {
        url = [NSString stringWithFormat:@"https://open.spotify.com/track/%@",
            [url stringByReplacingOccurrencesOfString:@"spotify:track:" withString:@""]];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
                if (win) break;
            }
        }
        UIViewController *top = win.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        NeedleQRShareViewController *vc = [NeedleQRShareViewController new];
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        [top presentViewController:vc animated:YES completion:nil];
        [self activityDidFinish:YES];
    });
}
@end

%hook UIActivityViewController
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)apps {
    NSMutableArray *all = [apps mutableCopy] ?: [NSMutableArray new];
    BOOL present = NO;
    for (id a in all) if ([a isKindOfClass:[NeedleQRActivity class]]) { present = YES; break; }
    if (!present) {
        NeedleQRActivity *qr = [[NeedleQRActivity alloc] init];
        [all insertObject:qr atIndex:0];
    }
    return %orig(items, all);
}
- (void)setExcludedActivityTypes:(NSArray *)types {
    NSMutableArray *filtered = [NSMutableArray new];
    for (NSString *t in types) {
        if (![t isEqualToString:@"com.needle.qrshare"]) [filtered addObject:t];
    }
    %orig(filtered);
}
%end

@interface NeedleStreakViewController : UIViewController
@end

@implementation NeedleStreakViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;

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
    title.text = @"Streaks";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    NSArray *hist = NeedleReadHistory();
    NSMutableDictionary *trackDays = [NSMutableDictionary new];
    NSCalendar *cal = [NSCalendar currentCalendar];
    for (NSDictionary *e in hist) {
        NSString *key = [NSString stringWithFormat:@"%@|%@", e[@"name"], e[@"artist"]];
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:[e[@"when"] doubleValue]];
        NSInteger day = (NSInteger)([cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:d]);
        NSMutableSet *days = trackDays[key];
        if (!days) { days = [NSMutableSet new]; trackDays[key] = days; }
        [days addObject:@(day)];
    }
    NSMutableArray *streaks = [NSMutableArray new];
    NSInteger today = (NSInteger)[cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitEra forDate:[NSDate date]];
    for (NSString *k in trackDays) {
        NSSet *days = trackDays[k];
        NSInteger streak = 0;
        for (NSInteger d = today; d > 0; d--) {
            if ([days containsObject:@(d)]) streak++;
            else break;
        }
        if (streak >= 2) {
            NSArray *parts = [k componentsSeparatedByString:@"|"];
            [streaks addObject:@{@"name": parts.firstObject, @"artist": parts.count > 1 ? parts[1] : @"", @"days": @(streak)}];
        }
    }
    [streaks sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"days"] compare:a[@"days"]];
    }];

    CGFloat y = 120;
    if (streaks.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(24, y + 80, w - 48, 24)];
        empty.text = @"No streaks yet. Play the same song two days in a row to start one.";
        empty.textColor = [UIColor colorWithWhite:1 alpha:0.5];
        empty.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        empty.textAlignment = NSTextAlignmentCenter;
        empty.numberOfLines = 0;
        [self.view addSubview:empty];
        return;
    }
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, w, self.view.bounds.size.height - y)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    CGFloat ry = 10;
    for (NSDictionary *s in streaks) {
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, ry, w - 40, 72)];
        card.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
        card.layer.cornerRadius = 16;
        UILabel *n = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, card.bounds.size.width - 100, 24)];
        n.text = s[@"name"];
        n.textColor = [UIColor whiteColor];
        n.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        [card addSubview:n];
        UILabel *a = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, card.bounds.size.width - 100, 20)];
        a.text = s[@"artist"];
        a.textColor = [UIColor colorWithWhite:1 alpha:0.55];
        a.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [card addSubview:a];
        UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(card.bounds.size.width - 90, 18, 74, 36)];
        d.text = [NSString stringWithFormat:@"%@🔥", s[@"days"]];
        d.textColor = NeedleCurrentColor();
        d.font = [UIFont systemFontOfSize:28 weight:UIFontWeightHeavy];
        d.textAlignment = NSTextAlignmentRight;
        [card addSubview:d];
        [scroll addSubview:card];
        ry += 84;
    }
    scroll.contentSize = CGSizeMake(w, ry + 20);
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void NeedleOpenStreaks(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleStreakViewController *vc = [NeedleStreakViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}

@interface NeedleGuiltyViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@end

static NSString *const NeedleGuiltyKey = @"GuiltyList";

@implementation NeedleGuiltyViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor blackColor];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;

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
    title.text = @"Guilty pleasures";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(24, 100, w - 48, 20)];
    sub.text = @"Plays logged here stay out of Wrapped and history.";
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.view addSubview:sub];

    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    add.frame = CGRectMake(24, 130, w - 48, 44);
    add.backgroundColor = NeedleCurrentColor();
    add.layer.cornerRadius = 14;
    [add setTitle:@"Add currently playing" forState:UIControlStateNormal];
    [add setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    add.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [add addTarget:self action:@selector(addCurrent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:add];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 190, w, self.view.bounds.size.height - 190) style:UITableViewStylePlain];
    self.table.backgroundColor = [UIColor blackColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 56;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.table];
}

- (NSMutableArray *)loadList {
    NSString *s = NeedlePrefString(NeedleGuiltyKey);
    if (!s.length) return [NSMutableArray new];
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [arr mutableCopy] ?: [NSMutableArray new];
}

- (void)saveList:(NSArray *)list {
    NSData *d = [NSJSONSerialization dataWithJSONObject:list options:0 error:nil];
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NeedlePrefSetString(NeedleGuiltyKey, s);
}

- (void)addCurrent {
    NSDictionary *info = NeedleCurrentTrackInfo();
    if (!info[@"name"] || [info[@"name"] length] == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"No track" message:@"Play something first then tap + Current." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NSMutableArray *list = [self loadList];
    for (NSDictionary *e in list) {
        if ([e[@"name"] isEqualToString:info[@"name"]] && [e[@"artist"] isEqualToString:info[@"artist"]]) return;
    }
    [list addObject:info];
    [self saveList:list];
    [self.table reloadData];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [self loadList].count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor blackColor];
    NSDictionary *e = [self loadList][ip.row];
    cell.textLabel.text = e[@"name"];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = e[@"artist"];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)s forRowAtIndexPath:(NSIndexPath *)ip {
    if (s == UITableViewCellEditingStyleDelete) {
        NSMutableArray *list = [self loadList];
        [list removeObjectAtIndex:ip.row];
        [self saveList:list];
        [t reloadData];
    }
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void NeedleOpenGuilty(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleGuiltyViewController *vc = [NeedleGuiltyViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}

BOOL NeedleIsGuiltyTrack(NSString *name, NSString *artist) {
    NSString *s = NeedlePrefString(NeedleGuiltyKey);
    if (!s.length) return NO;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    for (NSDictionary *e in arr) {
        if ([e[@"name"] isEqualToString:name] && [e[@"artist"] isEqualToString:artist]) return YES;
    }
    return NO;
}
