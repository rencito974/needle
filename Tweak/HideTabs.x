#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static BOOL _NeedleShouldHideTitle(NSString *title) {
    if (!title.length) return NO;
    NSString *lower = title.lowercaseString;
    if (NeedlePrefBool(@"HidePodcasts", NO) && [lower containsString:@"podcast"]) return YES;
    if (NeedlePrefBool(@"HideAudiobooks", NO) && [lower containsString:@"audiobook"]) return YES;
    if (NeedlePrefBool(@"HidePremiumNag", NO) &&
        ([lower containsString:@"premium"] || [lower containsString:@"upgrade"])) return YES;
    return NO;
}

static NSArray<UITabBarItem *> *_NeedleFilterItems(NSArray<UITabBarItem *> *items) {
    if (!NeedlePrefBool(@"HidePodcasts", NO) &&
        !NeedlePrefBool(@"HideAudiobooks", NO) &&
        !NeedlePrefBool(@"HidePremiumNag", NO)) return items;
    NSMutableArray *filtered = [NSMutableArray new];
    for (UITabBarItem *item in items) {
        if (_NeedleShouldHideTitle(item.title ?: @"")) continue;
        [filtered addObject:item];
    }
    return filtered;
}

static NSArray<UIViewController *> *_NeedleFilterVCs(NSArray<UIViewController *> *vcs) {
    if (!NeedlePrefBool(@"HidePodcasts", NO) &&
        !NeedlePrefBool(@"HideAudiobooks", NO) &&
        !NeedlePrefBool(@"HidePremiumNag", NO)) return vcs;
    NSMutableArray *filtered = [NSMutableArray new];
    for (UIViewController *vc in vcs) {
        NSString *title = vc.tabBarItem.title ?: vc.title ?: @"";
        if (_NeedleShouldHideTitle(title)) continue;
        [filtered addObject:vc];
    }
    return filtered;
}

%hook UITabBar
- (void)setItems:(NSArray<UITabBarItem *> *)items animated:(BOOL)animated {
    %orig(_NeedleFilterItems(items), animated);
}
- (void)setItems:(NSArray<UITabBarItem *> *)items {
    %orig(_NeedleFilterItems(items));
}
%end

%hook UITabBarController
- (void)setViewControllers:(NSArray<UIViewController *> *)vcs animated:(BOOL)animated {
    %orig(_NeedleFilterVCs(vcs), animated);
}
- (void)setViewControllers:(NSArray<UIViewController *> *)vcs {
    %orig(_NeedleFilterVCs(vcs));
}
%end
