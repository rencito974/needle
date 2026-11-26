#import <UIKit/UIKit.h>

extern NSArray *NeedleReadHistory(void);
extern UIColor *NeedleCurrentColor(void);

@interface NeedleDormantVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray *tracks;
@end

@implementation NeedleDormantVC

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1];

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.22].CGColor, (id)[UIColor blackColor].CGColor];
    bg.locations = @[@0.0, @0.5];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];

    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval d30 = now - (30 * 86400);

    NSMutableDictionary *agg = [NSMutableDictionary new];
    for (NSDictionary *e in NeedleReadHistory()) {
        NSString *name = e[@"name"] ?: @"";
        NSString *artist = e[@"artist"] ?: @"";
        if (!name.length) continue;
        NSString *key = [NSString stringWithFormat:@"%@|%@", name, artist];
        NSTimeInterval when = [e[@"when"] doubleValue];
        NSMutableDictionary *a = agg[key];
        if (!a) {
            a = [@{@"name": name, @"artist": artist, @"plays": @0, @"last": @0} mutableCopy];
            agg[key] = a;
        }
        a[@"plays"] = @([a[@"plays"] integerValue] + 1);
        if (when > [a[@"last"] doubleValue]) a[@"last"] = @(when);
    }

    NSMutableArray *dormant = [NSMutableArray new];
    for (NSDictionary *a in agg.allValues) {
        if ([a[@"plays"] integerValue] < 3) continue;
        if ([a[@"last"] doubleValue] > d30) continue;
        NSInteger daysAgo = (NSInteger)((now - [a[@"last"] doubleValue]) / 86400);
        NSMutableDictionary *m = [a mutableCopy];
        m[@"daysAgo"] = @(daysAgo);
        [dormant addObject:m];
    }
    [dormant sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSInteger pa = [a[@"plays"] integerValue];
        NSInteger pb = [b[@"plays"] integerValue];
        if (pa != pb) return pb > pa ? NSOrderedDescending : NSOrderedAscending;
        return [a[@"daysAgo"] compare:b[@"daysAgo"]];
    }];
    self.tracks = dormant;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(w - 60, 60, 42, 42);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    close.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    close.layer.cornerRadius = 21;
    close.layer.borderWidth = 0.5;
    close.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold]]
        forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(22, 60, w - 80, 40)];
    title.text = @"Forgotten";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBlack];
    [self.view addSubview:title];

    NSInteger n = self.tracks.count;
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(22, 102, w - 44, 20)];
    sub.text = n == 0 ? @"Nothing dormant yet. Keep listening." : [NSString stringWithFormat:@"%ld track%@ you loved then dropped (3+ plays, silent 30+ days)",
        (long)n, n == 1 ? @"" : @"s"];
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    sub.numberOfLines = 2;
    [self.view addSubview:sub];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 148, w, self.view.bounds.size.height - 148) style:UITableViewStylePlain];
    self.table.backgroundColor = [UIColor clearColor];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = 70;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.table];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.tracks.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.hidden = YES;

    NSDictionary *track = self.tracks[ip.row];
    CGFloat w = self.view.bounds.size.width;

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(22, 10, w - 130, 22)];
    name.text = track[@"name"];
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [cell.contentView addSubview:name];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(22, 34, w - 130, 20)];
    artist.text = track[@"artist"];
    artist.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    artist.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [cell.contentView addSubview:artist];

    UILabel *meta = [[UILabel alloc] initWithFrame:CGRectMake(w - 110, 20, 90, 18)];
    meta.text = [NSString stringWithFormat:@"%@× · %@d ago", track[@"plays"], track[@"daysAgo"]];
    meta.textColor = NeedleCurrentColor();
    meta.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
    meta.textAlignment = NSTextAlignmentRight;
    [cell.contentView addSubview:meta];

    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(22, 69, w - 44, 0.5)];
    sep.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [cell.contentView addSubview:sep];

    return cell;
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void NeedleOpenDormant(void) {
    UIWindow *w = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in ((UIWindowScene *)s).windows) if (win.isKeyWindow) { w = win; break; }
            if (w) break;
        }
    }
    UIViewController *top = w.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleDormantVC *vc = [NeedleDormantVC new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
