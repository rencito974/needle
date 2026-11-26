#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static UIImage *_needleLockSource = nil;
static NSTimer *_needleLockTimer = nil;
static CGFloat _needleLockPhase = 0.0;
static BOOL _needleLockReentryGuard = NO;

static UIImage *NeedleRenderLockFrame(UIImage *src, CGFloat phase) {
    if (!src || !src.CGImage) return src;
    CGFloat w = src.size.width;
    CGFloat h = src.size.height;
    if (w < 16 || h < 16) return src;
    CGFloat zoom = 1.06 + 0.04 * sinf(phase);
    CGFloat panX = 0.02 * cosf(phase * 0.7);
    CGFloat panY = 0.02 * sinf(phase * 0.5);

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = src.scale ?: 1.0;
    fmt.opaque = YES;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h) format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat drawW = w * zoom;
        CGFloat drawH = h * zoom;
        CGFloat dx = (w - drawW) / 2 + w * panX;
        CGFloat dy = (h - drawH) / 2 + h * panY;
        [src drawInRect:CGRectMake(dx, dy, drawW, drawH)];
    }];
}

static void NeedleStartLockMotion(void) {
    if (!NeedlePrefBool(@"LockMotion", NO)) return;
    if (_needleLockTimer) return;
    _needleLockPhase = 0;
    _needleLockTimer = [NSTimer scheduledTimerWithTimeInterval:0.6 repeats:YES block:^(NSTimer *t) {
        if (!_needleLockSource) return;
        _needleLockPhase += 0.08;
        UIImage *frame = NeedleRenderLockFrame(_needleLockSource, _needleLockPhase);
        if (!frame) return;
        NSMutableDictionary *info = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy] ?: [NSMutableDictionary new];
        MPMediaItemArtwork *art = [[MPMediaItemArtwork alloc] initWithBoundsSize:frame.size requestHandler:^UIImage *(CGSize s) {
            return frame;
        }];
        info[MPMediaItemPropertyArtwork] = art;
        _needleLockReentryGuard = YES;
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
        _needleLockReentryGuard = NO;
    }];
}

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    if (!_needleLockReentryGuard && NeedlePrefBool(@"LockMotion", NO)) {
        MPMediaItemArtwork *art = info[MPMediaItemPropertyArtwork];
        if (art && [art respondsToSelector:@selector(imageWithSize:)]) {
            UIImage *img = [art imageWithSize:CGSizeMake(640, 640)];
            if (img && img.CGImage) {
                _needleLockSource = img;
                NeedleStartLockMotion();
            }
        }
    }
    %orig;
}
%end
