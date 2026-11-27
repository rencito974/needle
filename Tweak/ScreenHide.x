#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern void NeedleHideFloatingButton(void);
extern void NeedleShowFloatingButton(void);

static void _NeedleSyncHideForCapture(void) {
    BOOL isCaptured = [UIScreen mainScreen].isCaptured;
    BOOL enabled = NeedlePrefBool(@"HideInCapture", NO);

    if (isCaptured && enabled) {
        NeedleHideFloatingButton();
    } else {
        NeedleShowFloatingButton();
    }
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            _NeedleSyncHideForCapture();
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NeedlePrefsChanged"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            if ([n.object isKindOfClass:[NSString class]] &&
                ([n.object isEqualToString:@"HideInCapture"])) {
                _NeedleSyncHideForCapture();
                extern void NeedleInstallFloatingButton(void);
                NeedleInstallFloatingButton();
            }
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *n) {
            _NeedleSyncHideForCapture();
        }];
}
