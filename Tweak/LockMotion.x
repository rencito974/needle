#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static UIImage *_needleLockSource = nil;
static NSTimer *_needleLockTimer = nil;
static CGFloat _needleLockPhase = 0.0;

static UIImage *NeedleRenderLockFrame(UIImage *src, CGFloat phase) {
    if (!src) return nil;
    CGFloat w = src.size.width;
    CGFloat h = src.size.height;
    CGFloat zoom = 1.08 + 0.06 * sinf(phase);
    CGFloat panX = 0.025 * cosf(phase * 0.7);
    CGFloat panY = 0.025 * sinf(phase * 0.5);

    CGSize outSize = CGSizeMake(w, h);
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = src.scale;
    fmt.opaque = YES;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:outSize format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat cropW = w / zoom;
        CGFloat cropH = h / zoom;
        CGFloat cropX = (w - cropW) / 2 + w * panX;
        CGFloat cropY = (h - cropH) / 2 + h * panY;
        CGRect srcRect = CGRectMake(cropX, cropY, cropW, cropH);
        CGImageRef sub = CGImageCreateWithImageInRect(src.CGImage, srcRect);
        if (!sub) return;
        [[UIImage imageWithCGImage:sub scale:src.scale orientation:src.imageOrientation] drawInRect:CGRectMake(0, 0, w, h)];
        CGImageRelease(sub);
    }];
}

static void NeedleStartLockMotion(void) {
    if (!NeedlePrefBool(@"LockMotion", YES)) return;
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
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
    }];
}

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    if (NeedlePrefBool(@"LockMotion", YES)) {
        MPMediaItemArtwork *art = info[MPMediaItemPropertyArtwork];
        if (art && [art respondsToSelector:@selector(imageWithSize:)]) {
            UIImage *img = [art imageWithSize:CGSizeMake(1024, 1024)];
            if (img && img != _needleLockSource) {
                _needleLockSource = img;
                NeedleStartLockMotion();
            }
        }
    }
    %orig;
}
%end
