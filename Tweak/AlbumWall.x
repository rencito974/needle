#import <UIKit/UIKit.h>

extern NSArray *NeedleReadHistory(void);
extern UIColor *NeedleCurrentColor(void);

@interface NeedleAlbumWallVC : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) NSArray<NSDictionary *> *albums;
@end

static UIColor *_NeedleColorForString(NSString *s) {
    if (!s.length) return [UIColor colorWithWhite:0.3 alpha:1];
    unsigned long hash = 5381;
    for (NSUInteger i = 0; i < s.length; i++) {
        hash = ((hash << 5) + hash) + [s characterAtIndex:i];
    }
    CGFloat h = (hash % 360) / 360.0;
    CGFloat s2 = 0.50 + ((hash / 360) % 30) / 100.0;
    CGFloat b = 0.55 + ((hash / 1000) % 20) / 100.0;
    return [UIColor colorWithHue:h saturation:s2 brightness:b alpha:1];
}

@implementation NeedleAlbumWallVC

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1];

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

    NSMutableDictionary *albumMap = [NSMutableDictionary new];
    NSArray *hist = NeedleReadHistory();
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger thisYear = [cal component:NSCalendarUnitYear fromDate:[NSDate date]];
    for (NSDictionary *e in hist) {
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:[e[@"when"] doubleValue]];
        NSInteger year = [cal component:NSCalendarUnitYear fromDate:d];
        if (year != thisYear) continue;
        NSString *album = e[@"album"] ?: @"";
        NSString *artist = e[@"artist"] ?: @"";
        if (!album.length) continue;
        NSString *key = [NSString stringWithFormat:@"%@|%@", album, artist];
        NSMutableDictionary *agg = albumMap[key];
        if (!agg) {
            agg = [@{@"album": album, @"artist": artist, @"plays": @0} mutableCopy];
            albumMap[key] = agg;
        }
        agg[@"plays"] = @([agg[@"plays"] integerValue] + 1);
    }
    self.albums = [[albumMap allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"plays"] compare:a[@"plays"]];
    }];

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

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(22, 60, w - 80, 44)];
    title.text = @"Album wall";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBlack];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(22, 102, w - 44, 20)];
    NSInteger n = self.albums.count;
    sub.text = n == 0 ? @"No history yet. Play something first." : [NSString stringWithFormat:@"%ld album%@ this year, sorted by plays", (long)n, n == 1 ? @"" : @"s"];
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.view addSubview:sub];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    CGFloat cellW = (w - 44 - 24) / 3.0;
    layout.itemSize = CGSizeMake(cellW, cellW + 40);
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 18;
    layout.sectionInset = UIEdgeInsetsMake(0, 22, 60, 22);
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 140, w, self.view.bounds.size.height - 140) collectionViewLayout:layout];
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.grid.dataSource = self;
    self.grid.delegate = self;
    [self.grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
    [self.view addSubview:self.grid];
}

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s {
    return self.albums.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:ip];
    for (UIView *sv in cell.contentView.subviews) [sv removeFromSuperview];
    cell.contentView.backgroundColor = [UIColor clearColor];

    NSDictionary *album = self.albums[ip.row];
    CGFloat w = cell.contentView.bounds.size.width;

    UIView *art = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, w)];
    art.backgroundColor = _NeedleColorForString(album[@"album"]);
    art.layer.cornerRadius = 10;
    art.clipsToBounds = YES;
    [cell.contentView addSubview:art];

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = CGRectMake(0, 0, w, w);
    grad.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.15].CGColor, (id)[UIColor clearColor].CGColor];
    grad.locations = @[@0.0, @0.5];
    [art.layer addSublayer:grad];

    NSString *alb = album[@"album"];
    UILabel *initial = [[UILabel alloc] initWithFrame:art.bounds];
    initial.text = alb.length ? [[alb substringToIndex:1] uppercaseString] : @"?";
    initial.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    initial.font = [UIFont systemFontOfSize:w * 0.48 weight:UIFontWeightBlack];
    initial.textAlignment = NSTextAlignmentCenter;
    [art addSubview:initial];

    UILabel *plays = [[UILabel alloc] initWithFrame:CGRectMake(8, w - 22, w - 16, 16)];
    plays.text = [NSString stringWithFormat:@"%@ plays", album[@"plays"]];
    plays.textColor = [UIColor colorWithWhite:1 alpha:0.75];
    plays.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightBold];
    [art addSubview:plays];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, w + 6, w, 16)];
    name.text = album[@"album"];
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    name.textAlignment = NSTextAlignmentCenter;
    name.lineBreakMode = NSLineBreakByTruncatingTail;
    [cell.contentView addSubview:name];

    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(0, w + 22, w, 14)];
    artist.text = album[@"artist"];
    artist.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    artist.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    artist.textAlignment = NSTextAlignmentCenter;
    artist.lineBreakMode = NSLineBreakByTruncatingTail;
    [cell.contentView addSubview:artist];

    return cell;
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

void NeedleOpenAlbumWall(void) {
    UIWindow *w = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in ((UIWindowScene *)s).windows) if (win.isKeyWindow) { w = win; break; }
            if (w) break;
        }
    }
    UIViewController *top = w.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleAlbumWallVC *vc = [NeedleAlbumWallVC new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
