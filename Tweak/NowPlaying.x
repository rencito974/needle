#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    NSMutableDictionary *m = [info mutableCopy] ?: [NSMutableDictionary new];
    if (!m[@"ExternalContentIdentifier"]) {
        m[@"ExternalContentIdentifier"] = @"com.spotify.client";
    }
    if (!m[@"MPNowPlayingInfoPropertyExternalUserProfileIdentifier"]) {
        m[@"MPNowPlayingInfoPropertyExternalUserProfileIdentifier"] = @"com.spotify.client";
    }
    %orig(m);
}
%end
