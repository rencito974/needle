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
        @{@"name": @"Midnight", @"key": @"Midnight", @"colors": @[
            [UIColor colorWithRed:0.25 green:0.22 blue:0.75 alpha:1],
            [UIColor colorWithRed:0.1 green:0.08 blue:0.4 alpha:1]]},
        @{@"name": @"Aurora", @"key": @"Aurora", @"colors": @[
            [UIColor colorWithRed:0.0 green:0.85 blue:0.65 alpha:1],
            [UIColor colorWithRed:0.35 green:0.3 blue:0.85 alpha:1]]},
        @{@"name": @"Ember", @"key": @"Ember", @"colors": @[
            [UIColor colorWithRed:0.95 green:0.3 blue:0.15 alpha:1],
            [UIColor colorWithRed:0.75 green:0.1 blue:0.0 alpha:1]]},
        @{@"name": @"Mint", @"key": @"Mint", @"colors": @[[UIColor colorWithRed:0.35 green:0.9 blue:0.65 alpha:1]]},
        @{@"name": @"Lavender", @"key": @"Lavender", @"colors": @[[UIColor colorWithRed:0.7 green:0.55 blue:0.95 alpha:1]]},
        @{@"name": @"Rose", @"key": @"Rose", @"colors": @[
            [UIColor colorWithRed:0.95 green:0.35 blue:0.55 alpha:1],
            [UIColor colorWithRed:0.75 green:0.15 blue:0.35 alpha:1]]},
        @{@"name": @"Sky", @"key": @"Sky", @"colors": @[[UIColor colorWithRed:0.35 green:0.7 blue:0.95 alpha:1]]},
        @{@"name": @"Iris", @"key": @"Iris", @"colors": @[
            [UIColor colorWithRed:0.45 green:0.35 blue:0.95 alpha:1],
            [UIColor colorWithRed:0.25 green:0.4 blue:0.85 alpha:1]]},
        @{@"name": @"Terracotta", @"key": @"Terracotta", @"colors": @[[UIColor colorWithRed:0.8 green:0.42 blue:0.25 alpha:1]]},
        @{@"name": @"Emerald", @"key": @"Emerald", @"colors": @[[UIColor colorWithRed:0.0 green:0.68 blue:0.4 alpha:1]]},
        @{@"name": @"Coral", @"key": @"Coral", @"colors": @[[UIColor colorWithRed:1.0 green:0.5 blue:0.45 alpha:1]]},
        @{@"name": @"Teal", @"key": @"Teal", @"colors": @[[UIColor colorWithRed:0.1 green:0.6 blue:0.65 alpha:1]]},
        @{@"name": @"Peach", @"key": @"Peach", @"colors": @[[UIColor colorWithRed:1.0 green:0.7 blue:0.5 alpha:1]]},
        @{@"name": @"Lime", @"key": @"Lime", @"colors": @[[UIColor colorWithRed:0.7 green:0.9 blue:0.25 alpha:1]]},
        @{@"name": @"Charcoal", @"key": @"Charcoal", @"colors": @[[UIColor colorWithWhite:0.35 alpha:1]]},
        @{@"name": @"Platinum", @"key": @"Platinum", @"colors": @[[UIColor colorWithWhite:0.88 alpha:1]]},
        @{@"name": @"Mono", @"key": @"Mono", @"colors": @[[UIColor colorWithWhite:0.75 alpha:1]]},
        @{@"name": @"Ocean", @"key": @"Ocean", @"colors": @[
            [UIColor colorWithRed:0.0 green:0.5 blue:0.85 alpha:1],
            [UIColor colorWithRed:0.0 green:0.3 blue:0.65 alpha:1]]},
        @{@"name": @"Forest", @"key": @"Forest", @"colors": @[[UIColor colorWithRed:0.15 green:0.55 blue:0.35 alpha:1]]},
        @{@"name": @"Candy", @"key": @"Candy", @"colors": @[
            [UIColor colorWithRed:0.95 green:0.45 blue:0.75 alpha:1],
            [UIColor colorWithRed:0.75 green:0.25 blue:0.85 alpha:1]]},
        @{@"name": @"Gold", @"key": @"Gold", @"colors": @[[UIColor colorWithRed:0.95 green:0.75 blue:0.25 alpha:1]]},
        @{@"name": @"Blood", @"key": @"Blood", @"colors": @[[UIColor colorWithRed:0.85 green:0.1 blue:0.15 alpha:1]]},
        @{@"name": @"Neon", @"key": @"Neon", @"colors": @[
            [UIColor colorWithRed:0.15 green:1.0 blue:0.75 alpha:1],
            [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1]]},
        @{@"name": @"Vinyl", @"key": @"Vinyl", @"colors": @[[UIColor colorWithWhite:0.18 alpha:1]]},
        @{@"name": @"Fire", @"key": @"Fire", @"colors": @[
            [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1],
            [UIColor colorWithRed:0.95 green:0.15 blue:0.1 alpha:1]]},
        @{@"name": @"Grape", @"key": @"Grape", @"colors": @[[UIColor colorWithRed:0.55 green:0.2 blue:0.75 alpha:1]]},
        @{@"name": @"Moss", @"key": @"Moss", @"colors": @[[UIColor colorWithRed:0.4 green:0.55 blue:0.25 alpha:1]]},
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
    CGFloat side = 24;
    CGFloat gap = 18;
    CGFloat cellW = (w - side * 2 - gap) / 2;
    layout.itemSize = CGSizeMake(cellW, cellW * 0.78);
    layout.minimumInteritemSpacing = gap;
    layout.minimumLineSpacing = gap;
    layout.sectionInset = UIEdgeInsetsMake(20, side, 60, side);

    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 130, w, self.view.bounds.size.height - 130) collectionViewLayout:layout];
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.showsVerticalScrollIndicator = NO;
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"t"];
    [self.view addSubview:self.grid];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)collectionView:(UICollectionView *)v numberOfItemsInSection:(NSInteger)s { return NeedleThemeCatalog().count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)v cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [v dequeueReusableCellWithReuseIdentifier:@"t" forIndexPath:ip];
    for (UIView *sub in [cell.contentView.subviews copy]) [sub removeFromSuperview];
    for (CALayer *l in [cell.contentView.layer.sublayers copy]) [l removeFromSuperlayer];
    NSDictionary *theme = NeedleThemeCatalog()[ip.item];
    CGFloat cellW = cell.bounds.size.width;
    CGFloat cellH = cell.bounds.size.height;

    NSArray *cols = theme[@"colors"];
    UIColor *primary = cols.firstObject ?: [UIColor whiteColor];
    UIColor *secondary = cols.count > 1 ? cols[1] : [primary colorWithAlphaComponent:0.6];

    UIView *card = [[UIView alloc] initWithFrame:cell.bounds];
    card.layer.cornerRadius = 22;
    card.layer.masksToBounds = NO;
    card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    card.layer.shadowColor = primary.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 10);
    card.layer.shadowRadius = 22;
    card.layer.shadowOpacity = 0.35;
    [cell.contentView addSubview:card];

    UIView *clip = [[UIView alloc] initWithFrame:card.bounds];
    clip.layer.cornerRadius = 22;
    clip.layer.masksToBounds = YES;
    clip.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    [card addSubview:clip];

    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = clip.bounds;
    g.colors = @[(id)primary.CGColor, (id)secondary.CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    [clip.layer addSublayer:g];

    for (NSInteger i = 0; i < 4; i++) {
        CAShapeLayer *ring = [CAShapeLayer layer];
        CGFloat radius = 24 + i * 22;
        CGPoint c = CGPointMake(cellW - 36, cellH - 22);
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:c radius:radius startAngle:0 endAngle:2 * M_PI clockwise:YES];
        ring.path = p.CGPath;
        ring.fillColor = [UIColor clearColor].CGColor;
        ring.strokeColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
        ring.lineWidth = 1.0;
        [clip.layer addSublayer:ring];
    }

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(cellW - 40, cellH - 26, 8, 8)];
    dot.backgroundColor = [UIColor whiteColor];
    dot.layer.cornerRadius = 4;
    [clip addSubview:dot];

    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(16, cellH - 50, cellW - 32, 24)];
    name.text = theme[@"name"];
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [clip addSubview:name];

    NSString *tag;
    if (cols.count > 1) tag = @"Gradient";
    else if ([theme[@"key"] isEqualToString:@""]) tag = @"From album";
    else tag = @"Solid";
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(16, cellH - 28, cellW - 32, 14)];
    NSMutableAttributedString *a = [[NSMutableAttributedString alloc] initWithString:[tag uppercaseString]];
    [a addAttribute:NSKernAttributeName value:@1.4 range:NSMakeRange(0, a.length)];
    [a addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:1 alpha:0.7] range:NSMakeRange(0, a.length)];
    [a addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:9 weight:UIFontWeightHeavy] range:NSMakeRange(0, a.length)];
    sub.attributedText = a;
    [clip addSubview:sub];

    NSString *currentKey = NeedlePrefString(@"ThemeKey") ?: @"";
    if ([currentKey isEqualToString:theme[@"key"]]) {
        card.layer.borderWidth = 2;
        card.layer.borderColor = [UIColor whiteColor].CGColor;
        card.layer.shadowOpacity = 0.8;
        card.layer.shadowRadius = 28;

        UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(cellW - 40, 16, 28, 28)];
        badge.backgroundColor = [UIColor whiteColor];
        badge.layer.cornerRadius = 14;
        UIImageView *check = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"checkmark" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightHeavy]]];
        check.tintColor = primary;
        check.contentMode = UIViewContentModeCenter;
        check.frame = badge.bounds;
        [badge addSubview:check];
        [clip addSubview:badge];
    }

    cell.contentView.transform = CGAffineTransformMakeScale(0.94, 0.94);
    cell.contentView.alpha = 0;
    [UIView animateWithDuration:0.4 delay:ip.item * 0.03 usingSpringWithDamping:0.85 initialSpringVelocity:0.6 options:0 animations:^{
        cell.contentView.transform = CGAffineTransformIdentity;
        cell.contentView.alpha = 1;
    } completion:nil];

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
