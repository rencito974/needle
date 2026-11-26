#import <UIKit/UIKit.h>

extern NSArray *NeedleReadHistory(void);
extern void NeedleClearHistory(void);
extern UIColor *NeedleCurrentColor(void);

typedef NS_ENUM(NSInteger, NeedleWrappedRange) {
    NeedleWrappedWeek,
    NeedleWrappedMonth,
    NeedleWrappedAllTime,
};

@interface NeedleWrappedViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, assign) NeedleWrappedRange range;
@property (nonatomic, strong) UISegmentedControl *segment;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<NSDictionary *> *topTracks;
@property (nonatomic, strong) NSArray<NSDictionary *> *topArtists;
@property (nonatomic, assign) NSTimeInterval totalMinutes;
@property (nonatomic, assign) NSInteger totalPlays;
@end

@implementation NeedleWrappedViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1.0];
    CAGradientLayer *bg = [CAGradientLayer layer];
    UIColor *accent = NeedleCurrentColor();
    bg.colors = @[(id)[accent colorWithAlphaComponent:0.4].CGColor, (id)[UIColor colorWithWhite:0.03 alpha:1.0].CGColor];
    bg.locations = @[@0.0, @0.5];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.range = NeedleWrappedWeek;
    [self rebuild];

    CGFloat w = self.view.bounds.size.width;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 56, 58, 36, 36);
    close.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    close.layer.cornerRadius = 18;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UIButton *share = [UIButton buttonWithType:UIButtonTypeSystem];
    share.frame = CGRectMake(w - 100, 58, 36, 36);
    share.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    share.layer.cornerRadius = 18;
    [share setImage:[UIImage systemImageNamed:@"square.and.arrow.up"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    share.tintColor = [UIColor whiteColor];
    [share addTarget:self action:@selector(shareSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:share];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 60, w - 100, 40)];
    title.text = @"Wrapped";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    self.segment = [[UISegmentedControl alloc] initWithItems:@[@"Week", @"Month", @"All time"]];
    self.segment.frame = CGRectMake(20, 112, w - 40, 36);
    self.segment.selectedSegmentIndex = 0;
    self.segment.selectedSegmentTintColor = NeedleCurrentColor();
    self.segment.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [self.segment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
    [self.segment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightBold]} forState:UIControlStateSelected];
    [self.segment addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segment];

    UIView *stats = [[UIView alloc] initWithFrame:CGRectMake(20, 164, w - 40, 86)];
    stats.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    stats.layer.cornerRadius = 18;

    UILabel *plays = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, (w - 80) / 2, 30)];
    plays.text = [NSString stringWithFormat:@"%ld", (long)self.totalPlays];
    plays.textColor = [UIColor whiteColor];
    plays.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    [stats addSubview:plays];
    UILabel *playsSub = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, (w - 80) / 2, 20)];
    playsSub.text = @"plays";
    playsSub.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    playsSub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [stats addSubview:playsSub];

    UILabel *mins = [[UILabel alloc] initWithFrame:CGRectMake(20 + (w - 80) / 2 + 20, 16, (w - 80) / 2, 30)];
    mins.text = [NSString stringWithFormat:@"%ld", (long)self.totalMinutes];
    mins.textColor = [UIColor whiteColor];
    mins.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    [stats addSubview:mins];
    UILabel *minsSub = [[UILabel alloc] initWithFrame:CGRectMake(20 + (w - 80) / 2 + 20, 50, (w - 80) / 2, 20)];
    minsSub.text = @"minutes listened";
    minsSub.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    minsSub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [stats addSubview:minsSub];

    [self.view addSubview:stats];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 268, w, self.view.bounds.size.height - 268) style:UITableViewStyleGrouped];
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 60;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.table];
}

- (void)segmentChanged {
    self.range = (NeedleWrappedRange)self.segment.selectedSegmentIndex;
    [self rebuild];
    [self.table reloadData];
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[UIView class]] && v.layer.cornerRadius == 18) {
            [v removeFromSuperview];
            break;
        }
    }
    [self viewDidLoad];
}

- (void)rebuild {
    NSArray *hist = NeedleReadHistory();
    NSTimeInterval cutoff = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (self.range == NeedleWrappedWeek) cutoff = now - 7 * 86400;
    else if (self.range == NeedleWrappedMonth) cutoff = now - 30 * 86400;

    NSMutableDictionary *trackCounts = [NSMutableDictionary new];
    NSMutableDictionary *artistCounts = [NSMutableDictionary new];
    NSTimeInterval seconds = 0;
    NSInteger plays = 0;

    for (NSDictionary *e in hist) {
        NSTimeInterval t = [e[@"when"] doubleValue];
        if (t < cutoff) continue;
        plays++;
        seconds += [e[@"duration"] doubleValue];
        NSString *trackKey = [NSString stringWithFormat:@"%@\n%@", e[@"name"], e[@"artist"]];
        trackCounts[trackKey] = @([trackCounts[trackKey] integerValue] + 1);
        NSString *artist = e[@"artist"];
        if (artist.length) artistCounts[artist] = @([artistCounts[artist] integerValue] + 1);
    }

    self.totalPlays = plays;
    self.totalMinutes = seconds / 60.0;

    NSMutableArray *tracks = [NSMutableArray new];
    for (NSString *k in trackCounts) {
        NSArray *parts = [k componentsSeparatedByString:@"\n"];
        [tracks addObject:@{@"name": parts.firstObject, @"artist": parts.count > 1 ? parts[1] : @"", @"count": trackCounts[k]}];
    }
    [tracks sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"count"] compare:a[@"count"]];
    }];
    if (tracks.count > 25) [tracks removeObjectsInRange:NSMakeRange(25, tracks.count - 25)];
    self.topTracks = tracks;

    NSMutableArray *artists = [NSMutableArray new];
    for (NSString *k in artistCounts) {
        [artists addObject:@{@"name": k, @"count": artistCounts[k]}];
    }
    [artists sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"count"] compare:a[@"count"]];
    }];
    if (artists.count > 25) [artists removeObjectsInRange:NSMakeRange(25, artists.count - 25)];
    self.topArtists = artists;
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)shareSelf {
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 2.0;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:self.view.bounds.size format:fmt];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];
        NSString *stamp = @"Made with Needle";
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.5],
        };
        CGSize sz = [stamp sizeWithAttributes:attrs];
        [stamp drawAtPoint:CGPointMake(self.view.bounds.size.width - sz.width - 20, self.view.bounds.size.height - sz.height - 30) withAttributes:attrs];
    }];
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[img] applicationActivities:nil];
    if (a.popoverPresentationController) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width - 80, 76, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return s == 0 ? self.topTracks.count : self.topArtists.count;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 44; }
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, t.bounds.size.width, 44)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(28, 16, t.bounds.size.width - 56, 22)];
    l.text = s == 0 ? @"Top tracks" : @"Top artists";
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [h addSubview:l];
    return h;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSDictionary *item = ip.section == 0 ? self.topTracks[ip.row] : self.topArtists[ip.row];
    NSInteger rank = ip.row + 1;

    UILabel *num = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 32, 30)];
    num.text = [NSString stringWithFormat:@"%ld", (long)rank];
    num.textColor = rank <= 3 ? NeedleCurrentColor() : [UIColor colorWithWhite:1 alpha:0.4];
    num.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBlack];
    [cell.contentView addSubview:num];

    cell.textLabel.text = item[@"name"];
    NSString *right = [NSString stringWithFormat:@"%@ plays", item[@"count"]];
    if (ip.section == 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@", item[@"artist"], right];
    } else {
        cell.detailTextLabel.text = right;
    }
    cell.indentationLevel = 2;
    cell.indentationWidth = 20;
    return cell;
}

@end

void NeedleOpenWrapped(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleWrappedViewController *vc = [NeedleWrappedViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
