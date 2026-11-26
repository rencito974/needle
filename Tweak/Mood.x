#import <UIKit/UIKit.h>

extern NSArray *NeedleReadHistory(void);
extern UIColor *NeedleCurrentColor(void);
extern void NeedleSeekPlayerTo(NSTimeInterval seconds);

@interface NeedleMoodViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) NSArray *moods;
@property (nonatomic, strong) UICollectionView *grid;
@end

@implementation NeedleMoodViewController

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
    title.text = @"Mood jumper";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(24, 100, w - 48, 20)];
    sub.text = @"Instant playlists from your history.";
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    sub.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.view addSubview:sub];

    self.moods = @[
        @{@"name": @"Late night", @"color": [UIColor colorWithRed:0.1 green:0.2 blue:0.5 alpha:1], @"symbol": @"moon.stars.fill"},
        @{@"name": @"Hype", @"color": [UIColor colorWithRed:0.95 green:0.3 blue:0.2 alpha:1], @"symbol": @"flame.fill"},
        @{@"name": @"Chill", @"color": [UIColor colorWithRed:0.3 green:0.65 blue:0.8 alpha:1], @"symbol": @"wind"},
        @{@"name": @"Nostalgia", @"color": [UIColor colorWithRed:0.75 green:0.55 blue:0.3 alpha:1], @"symbol": @"photo.stack"},
        @{@"name": @"Workout", @"color": [UIColor colorWithRed:0.85 green:0.15 blue:0.45 alpha:1], @"symbol": @"figure.run"},
        @{@"name": @"Focus", @"color": [UIColor colorWithRed:0.25 green:0.55 blue:0.4 alpha:1], @"symbol": @"brain"},
    ];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat cw = (w - 20 * 2 - 14) / 2;
    layout.itemSize = CGSizeMake(cw, 120);
    layout.minimumInteritemSpacing = 14;
    layout.minimumLineSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(20, 20, 40, 20);

    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 130, w, self.view.bounds.size.height - 130) collectionViewLayout:layout];
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"m"];
    [self.view addSubview:self.grid];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)collectionView:(UICollectionView *)v numberOfItemsInSection:(NSInteger)s { return self.moods.count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)v cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [v dequeueReusableCellWithReuseIdentifier:@"m" forIndexPath:ip];
    for (UIView *sub in [cell.contentView.subviews copy]) [sub removeFromSuperview];
    NSDictionary *m = self.moods[ip.item];
    cell.contentView.backgroundColor = m[@"color"];
    cell.contentView.layer.cornerRadius = 18;
    cell.contentView.layer.masksToBounds = YES;

    UIImageView *iv = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:m[@"symbol"] withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold]]];
    iv.tintColor = [UIColor whiteColor];
    iv.frame = CGRectMake(16, 16, 32, 32);
    [cell.contentView addSubview:iv];

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, cell.bounds.size.height - 36, cell.bounds.size.width - 32, 24)];
    l.text = m[@"name"];
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [cell.contentView addSubview:l];
    return cell;
}

- (void)collectionView:(UICollectionView *)v didSelectItemAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *m = self.moods[ip.item];
    NSString *name = m[@"name"];
    NSArray *hist = NeedleReadHistory();
    NSMutableSet *picked = [NSMutableSet new];
    NSMutableArray *out = [NSMutableArray new];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSDictionary *e in [hist reverseObjectEnumerator]) {
        if (out.count >= 20) break;
        NSString *key = [NSString stringWithFormat:@"%@|%@", e[@"name"], e[@"artist"]];
        if ([picked containsObject:key]) continue;
        NSTimeInterval when = [e[@"when"] doubleValue];
        NSInteger hour = ((NSInteger)((now - when) / 3600)) % 24;
        BOOL fits = YES;
        if ([name isEqualToString:@"Late night"]) fits = hour >= 22 || hour <= 4;
        else if ([name isEqualToString:@"Workout"] || [name isEqualToString:@"Hype"]) fits = [e[@"duration"] doubleValue] >= 150 && [e[@"duration"] doubleValue] <= 260;
        else if ([name isEqualToString:@"Chill"] || [name isEqualToString:@"Focus"]) fits = [e[@"duration"] doubleValue] >= 180;
        else if ([name isEqualToString:@"Nostalgia"]) fits = (now - when) > 30 * 86400;
        if (!fits) continue;
        [picked addObject:key];
        [out addObject:e];
    }
    NSString *msg = out.count == 0
        ? [NSString stringWithFormat:@"No tracks in your history match %@ yet. Play more songs and come back.", name]
        : [NSString stringWithFormat:@"Found %lu tracks matching %@. Open a track from your history to start.", (unsigned long)out.count, name];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ mood", name] message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

void NeedleOpenMoodJumper(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleMoodViewController *vc = [NeedleMoodViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
