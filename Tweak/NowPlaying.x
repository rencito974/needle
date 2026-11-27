#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

UIImage *_needleCurrentArtwork = nil;
extern NSMutableDictionary *_needleCurrentTrackCache;

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    NSMutableDictionary *m = [info mutableCopy] ?: [NSMutableDictionary new];
    NSString *selfBundle = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.spotify.client";
    if (!m[@"ExternalContentIdentifier"]) {
        m[@"ExternalContentIdentifier"] = selfBundle;
    }
    if (!m[@"MPNowPlayingInfoPropertyExternalUserProfileIdentifier"]) {
        m[@"MPNowPlayingInfoPropertyExternalUserProfileIdentifier"] = selfBundle;
    }
    if (!m[MPNowPlayingInfoPropertyAssetURL]) {
        m[MPNowPlayingInfoPropertyAssetURL] = [NSURL URLWithString:@"spotify://"];
    }
    id artwork = info[MPMediaItemPropertyArtwork];
    if ([artwork isKindOfClass:NSClassFromString(@"MPMediaItemArtwork")]) {
        @try {
            UIImage *img = [(MPMediaItemArtwork *)artwork imageWithSize:CGSizeMake(500, 500)];
            if (img) _needleCurrentArtwork = img;
        } @catch (NSException *e) {}
    }
    id name = info[MPMediaItemPropertyTitle];
    id artist = info[MPMediaItemPropertyArtist];
    id album = info[MPMediaItemPropertyAlbumTitle];
    if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
        if (!_needleCurrentTrackCache) _needleCurrentTrackCache = [NSMutableDictionary new];
        NSString *existingName = _needleCurrentTrackCache[@"name"];
        if (!existingName.length) {
            _needleCurrentTrackCache[@"name"] = name;
            if ([artist isKindOfClass:[NSString class]]) _needleCurrentTrackCache[@"artist"] = artist;
            if ([album isKindOfClass:[NSString class]]) _needleCurrentTrackCache[@"album"] = album;
        } else if (![existingName isEqualToString:name]) {
            _needleCurrentTrackCache[@"name"] = name;
            if ([artist isKindOfClass:[NSString class]]) _needleCurrentTrackCache[@"artist"] = artist;
            if ([album isKindOfClass:[NSString class]]) _needleCurrentTrackCache[@"album"] = album;
            [_needleCurrentTrackCache removeObjectForKey:@"uri"];
        }
        extern void NeedlePersistTrackCache(void);
        NeedlePersistTrackCache();
    }
    %orig(m);
}
%end
