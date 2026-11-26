#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

UIImage *_needleCurrentArtwork = nil;

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    NSMutableDictionary *m = [info mutableCopy] ?: [NSMutableDictionary new];
    if (!m[@"ExternalContentIdentifier"]) {
        m[@"ExternalContentIdentifier"] = @"com.spotify.client";
    }
    if (!m[@"MPNowPlayingInfoPropertyExternalUserProfileIdentifier"]) {
        m[@"MPNowPlayingInfoPropertyExternalUserProfileIdentifier"] = @"com.spotify.client";
    }
    id artwork = info[MPMediaItemPropertyArtwork];
    if ([artwork isKindOfClass:NSClassFromString(@"MPMediaItemArtwork")]) {
        @try {
            UIImage *img = [(MPMediaItemArtwork *)artwork imageWithSize:CGSizeMake(500, 500)];
            if (img) _needleCurrentArtwork = img;
        } @catch (NSException *e) {}
    }
    %orig(m);
}
%end
