#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>

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

- (UIImage *)realSpotifyIcon {
    static UIImage *cached = nil;
    if (cached) return cached;
    NSArray *tryNames = @[@"AppIcon60x60", @"AppIcon60x60@3x", @"AppIcon", @"Icon", @"spotify-logo", @"SpotifyIcon"];
    for (NSString *name in tryNames) {
        UIImage *img = [UIImage imageNamed:name];
        if (img) { cached = img; return img; }
    }
    NSString *bp = [[NSBundle mainBundle] bundlePath];
    NSArray *tryFiles = @[@"AppIcon60x60@3x.png", @"AppIcon60x60@2x.png", @"icon.png"];
    for (NSString *f in tryFiles) {
        UIImage *img = [UIImage imageWithContentsOfFile:[bp stringByAppendingPathComponent:f]];
        if (img) { cached = img; return img; }
    }
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSArray *primary = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    for (NSString *f in primary) {
        UIImage *img = [UIImage imageNamed:f];
        if (img) { cached = img; return img; }
        NSString *path = [bp stringByAppendingPathComponent:[f stringByAppendingString:@"@3x.png"]];
        img = [UIImage imageWithContentsOfFile:path];
        if (img) { cached = img; return img; }
    }
    return nil;
}

- (UIImage *)recoloredIcon:(UIImage *)src withTint:(UIColor *)tint {
    if (!src || !tint) return src;
    CGSize size = src.size;
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = src.scale ?: 2.0;
    fmt.opaque = YES;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [tint setFill];
        UIRectFill(CGRectMake(0, 0, size.width, size.height));
        CIImage *input = [CIImage imageWithCGImage:src.CGImage];
        CIFilter *inv = [CIFilter filterWithName:@"CIColorInvert"];
        [inv setValue:input forKey:kCIInputImageKey];
        CIFilter *mono = [CIFilter filterWithName:@"CIColorMonochrome"];
        [mono setValue:inv.outputImage forKey:kCIInputImageKey];
        [mono setValue:[CIColor colorWithRed:1 green:1 blue:1] forKey:@"inputColor"];
        [mono setValue:@1.0 forKey:@"inputIntensity"];
        CIContext *cctx = [CIContext contextWithOptions:nil];
        CGImageRef mask = [cctx createCGImage:mono.outputImage fromRect:[mono.outputImage extent]];
        if (mask) {
            CGContextRef gctx = UIGraphicsGetCurrentContext();
            CGFloat inset = size.width * 0.18;
            CGRect d = CGRectMake(inset, inset, size.width - inset * 2, size.height - inset * 2);
            CGContextSaveGState(gctx);
            CGContextTranslateCTM(gctx, 0, size.height);
            CGContextScaleCTM(gctx, 1, -1);
            CGRect flipped = CGRectMake(d.origin.x, size.height - d.origin.y - d.size.height, d.size.width, d.size.height);
            CGContextClipToMask(gctx, flipped, mask);
            CGFloat r2, g2, b2;
            [tint getRed:&r2 green:&g2 blue:&b2 alpha:NULL];
            BOOL darkBg = (r2 + g2 + b2) < 1.5;
            CGContextSetFillColorWithColor(gctx, darkBg ? [UIColor whiteColor].CGColor : [UIColor blackColor].CGColor);
            CGContextFillRect(gctx, flipped);
            CGContextRestoreGState(gctx);
            CGImageRelease(mask);
        }
    }];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)v cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [v dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:ip];
    for (UIView *sub in [cell.contentView.subviews copy]) [sub removeFromSuperview];
    for (CALayer *layer in [cell.contentView.layer.sublayers copy]) [layer removeFromSuperlayer];
    NSDictionary *icon = self.icons[ip.item];
    CGFloat cellW = cell.bounds.size.width;

    UIImage *real = [self realSpotifyIcon];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cellW, cellW)];
    iv.layer.cornerRadius = cellW * 0.235;
    iv.layer.masksToBounds = YES;
    iv.contentMode = UIViewContentModeScaleAspectFill;

    if (real && ip.item == 0) {
        iv.image = real;
        iv.backgroundColor = [UIColor clearColor];
    } else if (real) {
        UIImage *recolored = [self recoloredIcon:real withTint:icon[@"color"]];
        iv.image = recolored;
    } else {
        iv.backgroundColor = icon[@"color"];
    }

    iv.layer.shadowColor = ((UIColor *)icon[@"color"]).CGColor;
    iv.layer.shadowOffset = CGSizeMake(0, 6);
    iv.layer.shadowRadius = 14;
    iv.layer.shadowOpacity = 0.5;
    iv.layer.masksToBounds = NO;

    UIView *content = iv;
    if (iv.layer.shadowRadius > 0) {
        UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cellW, cellW)];
        [wrap addSubview:iv];
        content = wrap;
    }
    [cell.contentView addSubview:content];

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:iv.bounds cornerRadius:cellW * 0.235];
    iv.layer.shadowPath = shadowPath.CGPath;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, cellW + 8, cellW, 20)];
    lbl.text = icon[@"name"];
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    lbl.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:lbl];

    NSString *current = [[UIApplication sharedApplication] alternateIconName] ?: @"";
    if ([current isEqualToString:icon[@"key"]]) {
        iv.layer.borderWidth = 3;
        iv.layer.borderColor = [UIColor whiteColor].CGColor;
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
