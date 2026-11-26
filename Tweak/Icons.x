#import <UIKit/UIKit.h>

extern UIColor *NeedleCurrentColor(void);

@interface NeedleIconPickerViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) NSArray<NSDictionary *> *icons;
@end

@implementation NeedleIconPickerViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = [UIColor colorWithWhite:0.04 alpha:1.0];
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)[NeedleCurrentColor() colorWithAlphaComponent:0.35].CGColor, (id)[UIColor colorWithWhite:0.04 alpha:1.0].CGColor];
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
    title.text = @"App icon";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];

    self.icons = @[
        @{@"name": @"Default", @"key": @"", @"color": [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1]},
        @{@"name": @"Noir", @"key": @"NeedleNoir", @"color": [UIColor colorWithWhite:0.08 alpha:1]},
        @{@"name": @"Blood", @"key": @"NeedleBlood", @"color": [UIColor colorWithRed:0.85 green:0.1 blue:0.15 alpha:1]},
        @{@"name": @"Synth", @"key": @"NeedleSynth", @"color": [UIColor colorWithRed:0.95 green:0.1 blue:0.6 alpha:1]},
        @{@"name": @"Cream", @"key": @"NeedleCream", @"color": [UIColor colorWithRed:0.95 green:0.88 blue:0.78 alpha:1]},
        @{@"name": @"Deep Sea", @"key": @"NeedleOcean", @"color": [UIColor colorWithRed:0.05 green:0.35 blue:0.75 alpha:1]},
    ];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat cellW = (w - 24 * 2 - 20 * 2) / 3;
    layout.itemSize = CGSizeMake(cellW, cellW + 30);
    layout.minimumInteritemSpacing = 20;
    layout.minimumLineSpacing = 24;
    layout.sectionInset = UIEdgeInsetsMake(20, 24, 40, 24);

    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 112, w, self.view.bounds.size.height - 112) collectionViewLayout:layout];
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
    [self.view addSubview:self.grid];
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)collectionView:(UICollectionView *)v numberOfItemsInSection:(NSInteger)s { return self.icons.count; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)v cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [v dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:ip];
    for (UIView *sub in [cell.contentView.subviews copy]) [sub removeFromSuperview];
    NSDictionary *icon = self.icons[ip.item];
    CGFloat cellW = cell.bounds.size.width;

    UIView *tile = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cellW, cellW)];
    tile.backgroundColor = icon[@"color"];
    tile.layer.cornerRadius = cellW * 0.22;
    tile.layer.shadowColor = ((UIColor *)icon[@"color"]).CGColor;
    tile.layer.shadowOffset = CGSizeMake(0, 6);
    tile.layer.shadowRadius = 14;
    tile.layer.shadowOpacity = 0.5;

    UIColor *tileColor = icon[@"color"];
    CGFloat rr, gg, bb;
    [tileColor getRed:&rr green:&gg blue:&bb alpha:NULL];
    BOOL dark = (rr + gg + bb) < 1.5;
    UIColor *mark = dark ? [UIColor whiteColor] : [UIColor blackColor];

    CGFloat cx = cellW / 2;
    CGFloat cy = cellW / 2;
    CGFloat lineW = cellW * 0.075;

    for (NSInteger i = 0; i < 3; i++) {
        CGFloat radius = cellW * (0.17 + i * 0.09);
        CAShapeLayer *arc = [CAShapeLayer layer];
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:CGPointMake(cx, cy + radius * 0.3)
            radius:radius
            startAngle:-M_PI * 0.85
            endAngle:-M_PI * 0.15
            clockwise:YES];
        arc.path = p.CGPath;
        arc.strokeColor = mark.CGColor;
        arc.fillColor = [UIColor clearColor].CGColor;
        arc.lineWidth = lineW;
        arc.lineCap = kCALineCapRound;
        [tile.layer addSublayer:arc];
    }
    CAShapeLayer *dot = [CAShapeLayer layer];
    UIBezierPath *d = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - lineW * 0.75, cy + cellW * 0.12, lineW * 1.5, lineW * 1.5)];
    dot.path = d.CGPath;
    dot.fillColor = mark.CGColor;
    [tile.layer addSublayer:dot];

    [cell.contentView addSubview:tile];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, cellW + 8, cellW, 20)];
    lbl.text = icon[@"name"];
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    lbl.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:lbl];

    NSString *current = [[UIApplication sharedApplication] alternateIconName] ?: @"";
    if ([current isEqualToString:icon[@"key"]]) {
        tile.layer.borderWidth = 3;
        tile.layer.borderColor = [UIColor whiteColor].CGColor;
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)v didSelectItemAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *icon = self.icons[ip.item];
    NSString *key = icon[@"key"];
    NSString *name = key.length ? key : nil;
    UIApplication *app = [UIApplication sharedApplication];
    if (![app supportsAlternateIcons]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Not supported" message:@"This build doesn't allow alternate icons. Cyan needs to be passed --icons on the next build." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    [app setAlternateIconName:name completionHandler:^(NSError *err) {
        if (err) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Can't switch icon" message:err.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:a animated:YES completion:nil];
            });
            return;
        }
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
        [v reloadData];
    }];
}

@end

void NeedleOpenIconPicker(void) {
    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    NeedleIconPickerViewController *vc = [NeedleIconPickerViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}
