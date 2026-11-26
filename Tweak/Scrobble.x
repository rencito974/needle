#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern NSString *NeedlePrefString(NSString *key);

static NSString *const kLastFmURL = @"https://ws.audioscrobbler.com/2.0/";

static NSString *NeedleMD5(NSString *s) {
    const char *c = s.UTF8String;
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(c, (CC_LONG)strlen(c), r);
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [out appendFormat:@"%02x", r[i]];
    return out;
}

static NSString *NeedleURLEncode(NSString *s) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

static void NeedleScrobble(NSString *artist, NSString *track, NSString *album, NSTimeInterval ts) {
    if (!NeedlePrefBool(@"ScrobbleOn", NO)) return;
    NSString *apiKey = NeedlePrefString(@"LastFmApiKey");
    NSString *secret = NeedlePrefString(@"LastFmSecret");
    NSString *sk = NeedlePrefString(@"LastFmSession");
    if (!apiKey.length || !secret.length || !sk.length) return;
    if (!artist.length || !track.length) return;

    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    p[@"method"] = @"track.scrobble";
    p[@"api_key"] = apiKey;
    p[@"sk"] = sk;
    p[@"artist"] = artist;
    p[@"track"] = track;
    p[@"timestamp"] = [NSString stringWithFormat:@"%.0f", ts];
    if (album.length) p[@"album"] = album;

    NSArray *keys = [p.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *sig = [NSMutableString string];
    for (NSString *k in keys) [sig appendFormat:@"%@%@", k, p[k]];
    [sig appendString:secret];
    p[@"api_sig"] = NeedleMD5(sig);
    p[@"format"] = @"json";

    NSMutableString *body = [NSMutableString string];
    for (NSString *k in p.allKeys) {
        if (body.length) [body appendString:@"&"];
        [body appendFormat:@"%@=%@", k, NeedleURLEncode(p[k])];
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kLastFmURL]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
            NSLog(@"[Needle] scrobble %@ - %@ code=%ld err=%@", artist, track, (long)code, err);
        }] resume];
}

static NSString *_curArtist = nil;
static NSString *_curTrack = nil;
static NSString *_curAlbum = nil;
static NSTimeInterval _curStart = 0;
static NSTimeInterval _curDuration = 0;
static BOOL _curScrobbled = NO;

static NSString *_StringFromTrack(id track, SEL sel) {
    if (!track || ![track respondsToSelector:sel]) return nil;
    NSString *s = [track performSelector:sel];
    return [s isKindOfClass:[NSString class]] ? s : nil;
}

static NSTimeInterval _DurationFromTrack(id track) {
    SEL sel = @selector(duration);
    if (!track || ![track respondsToSelector:sel]) return 0;
    NSMethodSignature *sig = [[track class] instanceMethodSignatureForSelector:sel];
    if (!sig) return 0;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    [inv invokeWithTarget:track];
    const char *ret = sig.methodReturnType;
    if (ret[0] == 'd') {
        double d = 0; [inv getReturnValue:&d]; return d;
    } else if (ret[0] == 'q' || ret[0] == 'Q') {
        long long ll = 0; [inv getReturnValue:&ll]; return ll > 1000000 ? ll / 1000.0 : ll;
    }
    return 0;
}

static void NeedleTrackStart(id track) {
    if (!track) return;
    NSString *title = _StringFromTrack(track, @selector(trackName))
        ?: _StringFromTrack(track, @selector(title))
        ?: _StringFromTrack(track, @selector(name));
    NSString *artist = _StringFromTrack(track, @selector(artistName))
        ?: _StringFromTrack(track, @selector(artist))
        ?: _StringFromTrack(track, @selector(artistTitle));
    NSString *album = _StringFromTrack(track, @selector(albumName))
        ?: _StringFromTrack(track, @selector(album))
        ?: _StringFromTrack(track, @selector(albumTitle));
    NSTimeInterval dur = _DurationFromTrack(track);

    if (!title.length || !artist.length) return;
    if ([title isEqualToString:_curTrack] && [artist isEqualToString:_curArtist]) return;

    _curArtist = [artist copy];
    _curTrack = [title copy];
    _curAlbum = [album copy];
    _curDuration = dur;
    _curStart = [NSDate date].timeIntervalSince1970;
    _curScrobbled = NO;
    NSLog(@"[Needle] track open %@ - %@ dur=%.0fs", artist, title, dur);
}

static void NeedleTrackTick(NSTimeInterval elapsed) {
    if (_curScrobbled || !_curTrack) return;
    BOOL threshold = elapsed >= 30.0 && (elapsed >= _curDuration * 0.5 || elapsed >= 240.0);
    if (!threshold) return;
    _curScrobbled = YES;
    NeedleScrobble(_curArtist, _curTrack, _curAlbum, _curStart);
}

%hook SPTPlayer
- (void)setCurrentTrack:(id)track {
    %orig;
    NeedleTrackStart(track);
}
%end

%hook SPTPlayerTrack
%end

%hook SPTPlayerState
- (void)setPositionMs:(long long)ms {
    %orig;
    NeedleTrackTick((NSTimeInterval)ms / 1000.0);
}
%end

%hook SPTPlayerPositionStateImplementation
- (void)setPositionMs:(long long)ms {
    %orig;
    NeedleTrackTick((NSTimeInterval)ms / 1000.0);
}
%end
