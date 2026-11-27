#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static UIImage *NeedleUpscale(UIImage *src, CGFloat target) {
    if (!src) return nil;
    if (src.size.width >= target && src.size.height >= target) return src;
    CGSize out = CGSizeMake(target, target);
    UIGraphicsBeginImageContextWithOptions(out, YES, 1);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, target, target));
    CGFloat aspect = src.size.width / src.size.height;
    CGRect r;
    if (aspect >= 1.0) {
        CGFloat w = target;
        CGFloat h = target / aspect;
        r = CGRectMake(0, (target - h) / 2.0, w, h);
    } else {
        CGFloat h = target;
        CGFloat w = target * aspect;
        r = CGRectMake((target - w) / 2.0, 0, w, h);
    }
    [src drawInRect:r blendMode:kCGBlendModeNormal alpha:1.0];
    UIImage *big = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return big;
}

static NSDictionary *NeedleEnrichNowPlaying(NSDictionary *info) {
    if (!info || info.count == 0) return info;
    NSMutableDictionary *mut = [info mutableCopy];
    MPMediaItemArtwork *existing = mut[MPMediaItemPropertyArtwork];
    if (existing) {
        UIImage *src = [existing imageWithSize:CGSizeMake(1024, 1024)];
        UIImage *big = NeedleUpscale(src, 3000.0);
        if (big) {
            CGSize size = big.size;
            MPMediaItemArtwork *fresh = [[MPMediaItemArtwork alloc] initWithBoundsSize:size
                requestHandler:^UIImage *(CGSize s) { return big; }];
            mut[MPMediaItemPropertyArtwork] = fresh;
        }
    }
    mut[@"artworkDataWidth"] = @3000;
    mut[@"artworkDataHeight"] = @3000;
    return [mut copy];
}

@interface SPTNowPlayingInfoCenterArtworkDecorator : NSObject
@end

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    if (!NeedlePrefBool(@"BigLockscreenArt", YES)) { %orig; return; }
    %orig(NeedleEnrichNowPlaying(info));
}
%end

%hook SPTNowPlayingInfoCenterArtworkDecorator
- (NSDictionary *)decorateNowPlayingInfo:(NSDictionary *)info withArtwork:(id)artwork {
    NSDictionary *orig = %orig;
    if (!NeedlePrefBool(@"BigLockscreenArt", YES)) return orig;
    return NeedleEnrichNowPlaying(orig);
}
- (NSDictionary *)enrichNowPlayingInfo:(NSDictionary *)info {
    NSDictionary *orig = %orig;
    if (!NeedlePrefBool(@"BigLockscreenArt", YES)) return orig;
    return NeedleEnrichNowPlaying(orig);
}
%end
