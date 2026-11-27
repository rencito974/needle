#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);

static NSString *_NeedlePlaylistURIFromVC(UIViewController *vc) {
    if (!vc) return nil;
    NSString *cls = NSStringFromClass([vc class]);
    if (![cls containsString:@"Playlist"]) return nil;

    for (NSString *key in @[@"playlistURI", @"playlistUri", @"URI", @"uri", @"contextURI", @"entityURI"]) {
        @try {
            id v = [vc valueForKey:key];
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v hasPrefix:@"spotify:"]) return v;
            if (v && [v respondsToSelector:@selector(absoluteString)]) {
                NSString *s = [v performSelector:@selector(absoluteString)];
                if ([s hasPrefix:@"spotify:"]) return s;
            }
        } @catch (NSException *e) {}
    }
    return nil;
}

static NSString *_NeedlePlaylistNameFromVC(UIViewController *vc) {
    for (NSString *key in @[@"playlistName", @"title", @"name", @"displayName"]) {
        @try {
            id v = [vc valueForKey:key];
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) return v;
        } @catch (NSException *e) {}
    }
    return vc.title ?: @"this playlist";
}

@interface NeedleCloneChip : UIView
@property (nonatomic, weak) UIViewController *owner;
@end

@implementation NeedleCloneChip
- (instancetype)initWithVC:(UIViewController *)vc {
    CGFloat w = 136, h = 44;
    CGFloat x = (UIScreen.mainScreen.bounds.size.width - w) / 2;
    CGFloat y = UIScreen.mainScreen.bounds.size.height - 140;
    self = [super initWithFrame:CGRectMake(x, y, w, h)];
    if (!self) return nil;
    _owner = vc;
    self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.92];
    self.layer.cornerRadius = 22;
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = [NeedleCurrentColor() colorWithAlphaComponent:0.55].CGColor;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 6);
    self.layer.shadowRadius = 18;
    self.layer.shadowOpacity = 0.35;

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"square.on.square" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold]]];
    icon.tintColor = NeedleCurrentColor();
    icon.frame = CGRectMake(16, 12, 20, 20);
    [self addSubview:icon];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(42, 0, w - 50, h)];
    lbl.text = @"Clone playlist";
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [self addSubview:lbl];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
    [self addGestureRecognizer:tap];

    self.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ self.alpha = 1; }];
    return self;
}

- (void)tapped {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    NSString *uri = _NeedlePlaylistURIFromVC(self.owner);
    NSString *name = _NeedlePlaylistNameFromVC(self.owner);

    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"Clone playlist"
        message:[NSString stringWithFormat:@"Open \"%@\" in a share sheet so you can add every track to a new playlist of yours?", name]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Share to Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
        if (!uri) return;
        NSString *https = [uri stringByReplacingOccurrencesOfString:@"spotify:playlist:" withString:@"https://open.spotify.com/playlist/"];
        NSURL *url = [NSURL URLWithString:https];
        UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        [self.owner presentViewController:av animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Copy URI" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
        if (uri) [[UIPasteboard generalPasteboard] setString:uri];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self.owner presentViewController:a animated:YES completion:nil];
}
@end

static const char *kNeedleCloneChipKey = "_needleCloneChip";

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!NeedlePrefBool(@"PlaylistCloner", YES)) return;
    NSString *cls = NSStringFromClass([self class]);
    if (![cls containsString:@"Playlist"]) return;
    if ([cls containsString:@"Create"] || [cls containsString:@"Edit"] || [cls containsString:@"Picker"]) return;
    NSString *uri = _NeedlePlaylistURIFromVC(self);
    if (!uri) return;
    if (objc_getAssociatedObject(self, kNeedleCloneChipKey)) return;

    NeedleCloneChip *chip = [[NeedleCloneChip alloc] initWithVC:self];
    objc_setAssociatedObject(self, kNeedleCloneChipKey, chip, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.view addSubview:chip];
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    NeedleCloneChip *chip = objc_getAssociatedObject(self, kNeedleCloneChipKey);
    if (chip) {
        [chip removeFromSuperview];
        objc_setAssociatedObject(self, kNeedleCloneChipKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end
