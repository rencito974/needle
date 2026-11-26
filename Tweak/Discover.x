#import <UIKit/UIKit.h>

extern NSArray *NeedleReadHistory(void);
extern UIColor *NeedleCurrentColor(void);

@interface NeedleListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, copy) NSArray<NSDictionary *> *items;
@property (nonatomic, strong) UITableView *table;
@end

@implementation NeedleListViewController

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
    title.text = self.titleText;
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(24, 100, w - 48, 20)];
    sub.text = self.subtitleText;
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.view addSubview:sub];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 130, w, self.view.bounds.size.height - 130) style:UITableViewStylePlain];
    self.table.backgroundColor = [UIColor blackColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 56;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.table];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor blackColor];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSDictionary *it = self.items[ip.row];
    cell.textLabel.text = it[@"name"];
    cell.detailTextLabel.text = it[@"artist"];
    return cell;
}

@end

static void _NeedlePresent(NeedleListViewController *vc) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}

void NeedleOpenSimilarSongs(void) {
    NSArray *hist = NeedleReadHistory();
    NSDictionary *last = hist.lastObject;
    NSString *baseArtist = last[@"artist"] ?: @"";
    NSMutableArray *same = [NSMutableArray new];
    NSMutableSet *seen = [NSMutableSet new];
    for (NSDictionary *e in [hist reverseObjectEnumerator]) {
        if (same.count >= 25) break;
        if (![e[@"artist"] isEqualToString:baseArtist]) continue;
        NSString *k = e[@"name"];
        if ([seen containsObject:k]) continue;
        [seen addObject:k];
        [same addObject:e];
    }
    NeedleListViewController *vc = [NeedleListViewController new];
    vc.titleText = @"Similar songs";
    vc.subtitleText = baseArtist.length ? [NSString stringWithFormat:@"More from %@ in your history", baseArtist] : @"Play something first.";
    vc.items = same;
    _NeedlePresent(vc);
}

void NeedleOpenMixer(void) {
    NSArray *hist = NeedleReadHistory();
    NSMutableDictionary *byArtist = [NSMutableDictionary new];
    for (NSDictionary *e in hist) {
        NSString *a = e[@"artist"];
        if (!a.length) continue;
        NSMutableArray *bucket = byArtist[a];
        if (!bucket) { bucket = [NSMutableArray new]; byArtist[a] = bucket; }
        [bucket addObject:e];
    }
    NSArray *topArtists = [[byArtist allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [@([byArtist[b] count]) compare:@([byArtist[a] count])];
    }];
    NSMutableArray *interleaved = [NSMutableArray new];
    NSInteger take = MIN(topArtists.count, 4);
    for (NSInteger i = 0; i < 10 && interleaved.count < 30; i++) {
        for (NSInteger a = 0; a < take; a++) {
            NSArray *bucket = byArtist[topArtists[a]];
            if (i < bucket.count) [interleaved addObject:bucket[i]];
        }
    }
    NeedleListViewController *vc = [NeedleListViewController new];
    vc.titleText = @"Mixed queue";
    vc.subtitleText = @"Interleaved from your top 4 artists";
    vc.items = interleaved;
    _NeedlePresent(vc);
}

void NeedleOpenSessionMosaic(void) {
    NSArray *hist = NeedleReadHistory();
    NSTimeInterval cutoff = [[NSDate date] timeIntervalSince1970] - 6 * 3600;
    NSMutableArray *session = [NSMutableArray new];
    NSMutableSet *seen = [NSMutableSet new];
    for (NSDictionary *e in [hist reverseObjectEnumerator]) {
        if ([e[@"when"] doubleValue] < cutoff) break;
        NSString *k = [NSString stringWithFormat:@"%@|%@", e[@"name"], e[@"artist"]];
        if ([seen containsObject:k]) continue;
        [seen addObject:k];
        [session addObject:e];
    }
    NeedleListViewController *vc = [NeedleListViewController new];
    vc.titleText = @"Session";
    vc.subtitleText = [NSString stringWithFormat:@"%lu tracks in the last 6 hours", (unsigned long)session.count];
    vc.items = session;
    _NeedlePresent(vc);
}
