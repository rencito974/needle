#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);

static const char *kNeedleQueueLongPressKey = "_needleQueueLongPress";

static UIViewController *_NeedleParentVC(UIView *v) {
    UIResponder *r = v;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

static void _NeedleShowQueueMenu(UIView *row) {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    UIViewController *host = _NeedleParentVC(row);
    if (!host) return;

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:nil
        message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Move to top" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_){
        UITableView *tbl = nil;
        UIView *v = row;
        while (v && !tbl) {
            if ([v isKindOfClass:[UITableView class]]) tbl = (UITableView *)v;
            v = v.superview;
        }
        if (!tbl) return;
        NSIndexPath *ip = [tbl indexPathForCell:(UITableViewCell *)row];
        if (!ip) return;
        @try {
            if ([tbl.dataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)]) {
                NSIndexPath *top = [NSIndexPath indexPathForRow:0 inSection:ip.section];
                [tbl.dataSource tableView:tbl moveRowAtIndexPath:ip toIndexPath:top];
                [tbl moveRowAtIndexPath:ip toIndexPath:top];
            }
        } @catch (NSException *e) {}
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Remove from queue" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_){
        UITableView *tbl = nil;
        UIView *v = row;
        while (v && !tbl) {
            if ([v isKindOfClass:[UITableView class]]) tbl = (UITableView *)v;
            v = v.superview;
        }
        if (!tbl) return;
        NSIndexPath *ip = [tbl indexPathForCell:(UITableViewCell *)row];
        if (!ip) return;
        @try {
            if ([tbl.dataSource respondsToSelector:@selector(tableView:commitEditingStyle:forRowAtIndexPath:)]) {
                [tbl.dataSource tableView:tbl commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:ip];
            }
        } @catch (NSException *e) {}
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = row;
        sheet.popoverPresentationController.sourceRect = row.bounds;
    }
    [host presentViewController:sheet animated:YES completion:nil];
}

static void _NeedleHandleQueueLongPress(UILongPressGestureRecognizer *gr) {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    _NeedleShowQueueMenu(gr.view);
}

%hook UITableViewCell

- (void)didMoveToWindow {
    %orig;
    if (!NeedlePrefBool(@"QueueGestures", YES)) return;
    if (!self.window) return;

    UIViewController *host = _NeedleParentVC(self);
    if (!host) return;
    NSString *hostCls = NSStringFromClass([host class]);
    if (![hostCls containsString:@"Queue"] && ![hostCls containsString:@"NowPlaying"]) return;

    if (objc_getAssociatedObject(self, kNeedleQueueLongPressKey)) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[self class]
        action:@selector(_needleQueueCellLongPress:)];
    lp.minimumPressDuration = 0.45;
    lp.cancelsTouchesInView = NO;
    [self addGestureRecognizer:lp];
    objc_setAssociatedObject(self, kNeedleQueueLongPressKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
+ (void)_needleQueueCellLongPress:(UILongPressGestureRecognizer *)gr {
    _NeedleHandleQueueLongPress(gr);
}

%end
