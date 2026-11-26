#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern UIColor *NeedleCurrentColor(void);
extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static __weak UIView *_needleLyricsContainer = nil;

@interface NeedleFullLyricsViewController : UIViewController
@property (nonatomic, copy) NSArray<NSString *> *lines;
@property (nonatomic, assign) NSInteger current;
@property (nonatomic, copy) NSString *trackName;
@property (nonatomic, copy) NSString *artistName;
@end

extern void NeedleSeekPlayerTo(NSTimeInterval seconds);

@implementation NeedleFullLyricsViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = NeedleCurrentColor() ?: [UIColor blackColor];
    self.view = root;

    CAGradientLayer *bg = [CAGradientLayer layer];
    UIColor *accent = NeedleCurrentColor();
    bg.colors = @[(id)accent.CGColor, (id)[accent colorWithAlphaComponent:0.4].CGColor, (id)[UIColor blackColor].CGColor];
    bg.locations = @[@0.0, @0.5, @1.0];
    bg.frame = root.bounds;
    [root.layer insertSublayer:bg atIndex:0];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat w = self.view.bounds.size.width;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 56, 58, 36, 36);
    close.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    close.layer.cornerRadius = 18;
    [close setImage:[UIImage systemImageNamed:@"xmark"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 60, w - 100, 30)];
    title.text = self.trackName ?: @"Lyrics";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    [self.view addSubview:title];

    if (self.artistName.length) {
        UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(24, 90, w - 100, 20)];
        artist.text = self.artistName;
        artist.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        artist.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [self.view addSubview:artist];
    }

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 130, w, self.view.bounds.size.height - 130)];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.contentInset = UIEdgeInsetsMake(20, 0, 60, 0);
    [self.view addSubview:scroll];

    CGFloat y = 0;
    for (NSInteger i = 0; i < self.lines.count; i++) {
        NSString *line = self.lines[i];
        BOOL isCurrent = (i == self.current);
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(28, y, w - 56, 0)];
        l.text = line;
        l.numberOfLines = 0;
        l.textColor = isCurrent ? [UIColor whiteColor] : [UIColor colorWithWhite:1 alpha:0.45];
        l.font = [UIFont systemFontOfSize:isCurrent ? 26 : 22 weight:isCurrent ? UIFontWeightHeavy : UIFontWeightSemibold];
        l.userInteractionEnabled = YES;
        l.tag = i;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_lineTapped:)];
        [l addGestureRecognizer:tap];
        [l sizeToFit];
        CGRect f = l.frame;
        f.origin.x = 28;
        f.origin.y = y;
        f.size.width = w - 56;
        l.frame = f;
        [scroll addSubview:l];
        y += f.size.height + 20;
    }
    scroll.contentSize = CGSizeMake(w, y);
    if (self.current > 2 && self.current < self.lines.count) {
        [scroll setContentOffset:CGPointMake(0, MAX(0, (self.current - 2) * 50)) animated:NO];
    }
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)_lineTapped:(UITapGestureRecognizer *)g {
    NSInteger idx = g.view.tag;
    if (self.lines.count < 2) return;
    NSTimeInterval dur = [[NSUserDefaults standardUserDefaults] doubleForKey:@"NeedleLastTrackDuration"];
    if (dur <= 0) dur = 210;
    NSTimeInterval frac = (NSTimeInterval)idx / (NSTimeInterval)self.lines.count;
    NeedleSeekPlayerTo(dur * frac);
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

static NSArray *NeedleHarvestLyricsFromContainer(UIView *container, NSInteger *currentOut) {
    NSMutableArray *lines = [NSMutableArray new];
    NSInteger current = -1;
    NSArray *subs = [container subviews];
    for (UIView *v in subs) {
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *l = (UILabel *)v;
            if (l.text.length) [lines addObject:l.text];
        } else {
            NSMutableArray *nested = [NeedleHarvestLyricsFromContainer(v, NULL) mutableCopy];
            if (nested.count) [lines addObjectsFromArray:nested];
        }
    }
    for (NSInteger i = 0; i < lines.count && current < 0; i++) {
        UIView *l = [[container subviews] count] > i ? [container subviews][i] : nil;
        (void)l;
    }
    if (currentOut) *currentOut = MAX(0, current);
    return lines;
}

static void NeedleOpenLyricsOverlay(UIView *tappedLabel) {
    UIView *walker = tappedLabel;
    UIView *container = nil;
    while (walker) {
        NSString *cls = NSStringFromClass([walker class]);
        if ([cls containsString:@"Lyric"] && walker.subviews.count > 3) {
            container = walker;
            break;
        }
        walker = walker.superview;
    }
    if (!container) container = tappedLabel.superview.superview;

    NSInteger current = 0;
    NSArray *lines = NeedleHarvestLyricsFromContainer(container, &current);

    if (lines.count < 2) {
        NSMutableArray *fallback = [NSMutableArray new];
        if ([tappedLabel isKindOfClass:[UILabel class]]) {
            [fallback addObject:((UILabel *)tappedLabel).text ?: @""];
        }
        [fallback addObject:@""];
        [fallback addObject:@"Tap the mini player and open Lyrics to see the full set."];
        lines = fallback;
    }

    UIWindow *win = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
            if (win) break;
        }
    }
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;

    NeedleFullLyricsViewController *vc = [NeedleFullLyricsViewController new];
    vc.lines = lines;
    vc.current = current;
    vc.trackName = @"Now playing";
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:vc animated:YES completion:nil];
}

@interface NeedleLyricsTapRouter : NSObject
+ (void)_needleLyricTap:(UITapGestureRecognizer *)g;
@end
@implementation NeedleLyricsTapRouter
+ (void)_needleLyricTap:(UITapGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateEnded) return;
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    NeedleOpenLyricsOverlay(g.view);
}
@end

static void NeedleAttachLyricTap(UIView *v) {
    static char _k;
    if (!v || objc_getAssociatedObject(v, &_k)) return;
    objc_setAssociatedObject(v, &_k, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    v.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:[NeedleLyricsTapRouter class]
        action:@selector(_needleLyricTap:)];
    [v addGestureRecognizer:tap];
}

%hook UILabel
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    if (!NeedlePrefBool(@"LyricsTapOpensFull", YES)) return;
    UIView *anc = self.superview;
    while (anc) {
        NSString *cls = NSStringFromClass([anc class]);
        if ([cls containsString:@"Lyric"]) {
            NeedleAttachLyricTap(self);
            _needleLyricsContainer = anc;
            return;
        }
        anc = anc.superview;
    }
}
%end
