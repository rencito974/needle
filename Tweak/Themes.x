#import <UIKit/UIKit.h>

extern NSString *NeedlePrefString(NSString *key);
extern void NeedlePrefSetString(NSString *key, NSString *val);
extern void NeedleSetPalette(UIColor *);

static NSArray *NeedleThemeCatalog(void) {
    return @[
        @{@"name": @"Album", @"key": @"", @"colors": @[[UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1]]},
        @{@"name": @"Synthwave", @"key": @"Synthwave", @"colors": @[
            [UIColor colorWithRed:0.95 green:0.1 blue:0.6 alpha:1],
            [UIColor colorWithRed:0.4 green:0.1 blue:0.8 alpha:1]]},
        @{@"name": @"Sunset", @"key": @"Sunset", @"colors": @[
            [UIColor colorWithRed:1.0 green:0.45 blue:0.2 alpha:1],
            [UIColor colorWithRed:0.95 green:0.2 blue:0.4 alpha:1]]},
        @{@"name": @"Mono", @"key": @"Mono", @"colors": @[[UIColor colorWithWhite:0.75 alpha:1]]},
        @{@"name": @"Ocean", @"key": @"Ocean", @"colors": @[[UIColor colorWithRed:0.0 green:0.5 blue:0.85 alpha:1]]},
        @{@"name": @"Forest", @"key": @"Forest", @"colors": @[[UIColor colorWithRed:0.15 green:0.55 blue:0.35 alpha:1]]},
        @{@"name": @"Candy", @"key": @"Candy", @"colors": @[[UIColor colorWithRed:0.95 green:0.45 blue:0.75 alpha:1]]},
        @{@"name": @"Gold", @"key": @"Gold", @"colors": @[[UIColor colorWithRed:0.95 green:0.75 blue:0.25 alpha:1]]},
        @{@"name": @"Blood", @"key": @"Blood", @"colors": @[[UIColor colorWithRed:0.85 green:0.1 blue:0.15 alpha:1]]},
    ];
}

UIColor *NeedleThemeOverrideColor(void) {
    NSString *key = NeedlePrefString(@"ThemeKey");
    if (!key.length) return nil;
    for (NSDictionary *t in NeedleThemeCatalog()) {
        if ([t[@"key"] isEqualToString:key]) return [t[@"colors"] firstObject];
    }
    return nil;
}

@interface NeedleThemeStoreViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *grid;
@end

@implementation NeedleThemeStoreViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1];
    CAGradientLayer *bg = [CAGradientLayer layer];
    UIColor *accent = NeedleThemeOverrideColor() ?: [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1];
    bg.colors = @[(id)[accent colorWithAlphaComponent:0.35].CGColor, (id)[UIColor colorWithWhite:0.04 alpha:1].CGColor];
    bg.locations = @[@0.0, @0.55];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
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

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 60, w - 100, 40)];
    title.text = @"Themes";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(24, 100, w - 48, 20)];
    sub.text = @"Override the album-extracted color.";
    sub.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    sub.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.view addSubview:sub];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat cellW = (w - 24 * 2 - 16 * 2) / 3;
    layout.itemSize = CGSizeMake(cellW, cellW + 28);
    layout.minimumInteritemSpacing = 16;
    layout.minimumLineSpacing = 20;
    layout.sectionInset = UIEdgeInsetsMake(20, 24, 40, 24);

    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 130, w, self.view.bounds.size.height - 130) collectionViewLayout:layout];
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"t"];
    [self.view addSubview:self.grid];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)collectionView:(UICollectionView *)v numberOfItemsInSection:(NSInteger)s { return NeedleThemeCatalog().count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)v cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [v dequeueReusableCellWithReuseIdentifier:@"t" forIndexPath:ip];
    for (UIView *sub in [cell.contentView.subviews copy]) [sub removeFromSuperview];
    NSDictionary *theme = NeedleThemeCatalog()[ip.item];
    CGFloat cellW = cell.bounds.size.width;

    UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cellW, cellW)];
    swatch.layer.cornerRadius = 20;
    swatch.layer.masksToBounds = YES;
    NSArray *cols = theme[@"colors"];
    if (cols.count == 1) {
        swatch.backgroundColor = cols[0];
    } else {
        CAGradientLayer *g = [CAGradientLayer layer];
        NSMutableArray *cgs = [NSMutableArray new];
        for (UIColor *c in cols) [cgs addObject:(id)c.CGColor];
        g.colors = cgs;
        g.startPoint = CGPointMake(0, 0);
        g.endPoint = CGPointMake(1, 1);
        g.frame = swatch.bounds;
        [swatch.layer addSublayer:g];
    }
    swatch.layer.shadowColor = ((UIColor *)cols.firstObject).CGColor;
    swatch.layer.shadowOffset = CGSizeMake(0, 6);
    swatch.layer.shadowRadius = 14;
    swatch.layer.shadowOpacity = 0.4;
    swatch.layer.masksToBounds = NO;

    NSString *currentKey = NeedlePrefString(@"ThemeKey") ?: @"";
    if ([currentKey isEqualToString:theme[@"key"]]) {
        swatch.layer.borderWidth = 3;
        swatch.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    [cell.contentView addSubview:swatch];

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, cellW + 8, cellW, 20)];
    l.text = theme[@"name"];
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    l.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:l];
    return cell;
}

- (void)collectionView:(UICollectionView *)v didSelectItemAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *theme = NeedleThemeCatalog()[ip.item];
    NeedlePrefSetString(@"ThemeKey", theme[@"key"]);
    UIColor *c = [theme[@"colors"] firstObject];
    if ([theme[@"key"] length]) NeedleSetPalette(c);
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    [v reloadData];
}

@end

void NeedleOpenThemeStore(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleThemeStoreViewController *vc = [NeedleThemeStoreViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
