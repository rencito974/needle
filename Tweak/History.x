#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);
extern UIColor *NeedleCurrentColor(void);

static NSString *NeedleHistoryPath(void) {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"NeedleHistory.plist"];
}

static NSMutableArray *_cache = nil;

static NSMutableArray *NeedleLoadHistory(void) {
    if (_cache) return _cache;
    NSArray *disk = [NSArray arrayWithContentsOfFile:NeedleHistoryPath()];
    _cache = disk ? [disk mutableCopy] : [NSMutableArray new];
    return _cache;
}

static void NeedleSaveHistory(void) {
    [_cache writeToFile:NeedleHistoryPath() atomically:YES];
}

void NeedleLogPlay(NSString *name, NSString *artist, NSString *album, NSTimeInterval dur) {
    if (!name.length) return;
    NSMutableArray *hist = NeedleLoadHistory();
    NSDictionary *last = hist.lastObject;
    if (last && [last[@"name"] isEqualToString:name] && [last[@"artist"] isEqualToString:artist ?: @""]) {
        NSTimeInterval t = [last[@"when"] doubleValue];
        if ([[NSDate date] timeIntervalSince1970] - t < 30) return;
    }
    NSDictionary *entry = @{
        @"name": name ?: @"",
        @"artist": artist ?: @"",
        @"album": album ?: @"",
        @"when": @([[NSDate date] timeIntervalSince1970]),
        @"duration": @(dur),
    };
    [hist addObject:entry];
    if (hist.count > 20000) [hist removeObjectsInRange:NSMakeRange(0, hist.count - 20000)];
    NeedleSaveHistory();
}

NSArray *NeedleReadHistory(void) {
    return [NeedleLoadHistory() copy];
}

void NeedleClearHistory(void) {
    [_cache removeAllObjects];
    NeedleSaveHistory();
}

@interface SPTPlayerTrack : NSObject
@end

%hook SPTPlayerImpl
- (void)setCurrentTrack:(id)track {
    %orig;
    if (!track) return;
    NSString *name = nil, *artist = nil, *album = nil;
    NSTimeInterval dur = 0;
    @try { name = [track valueForKey:@"name"]; } @catch (NSException *e) {}
    @try { artist = [track valueForKey:@"artistName"]; } @catch (NSException *e) {}
    if (!artist.length) { @try { artist = [track valueForKey:@"artist"]; } @catch (NSException *e) {} }
    @try { album = [track valueForKey:@"albumName"]; } @catch (NSException *e) {}
    if (!album.length) { @try { album = [track valueForKey:@"album"]; } @catch (NSException *e) {} }
    @try { dur = [[track valueForKey:@"duration"] doubleValue] / 1000.0; } @catch (NSException *e) {}

    [[NSUserDefaults standardUserDefaults] setDouble:dur forKey:@"NeedleLastTrackDuration"];
    NeedleLogPlay(name ?: @"Unknown", artist ?: @"Unknown", album ?: @"", dur);
}
%end

static __weak id _needleSeekPlayer = nil;

%hook SPTPlayerImpl
- (void)positionChanged:(NSTimeInterval)pos {
    %orig;
    _needleSeekPlayer = self;
}
%end

void NeedleSeekPlayerTo(NSTimeInterval seconds) {
    id player = _needleSeekPlayer;
    if (!player) return;
    SEL sels[] = {
        @selector(seekToPosition:),
        @selector(seekTo:),
        @selector(setPosition:),
    };
    double posMs = seconds * 1000.0;
    for (NSUInteger i = 0; i < sizeof(sels) / sizeof(SEL); i++) {
        if ([player respondsToSelector:sels[i]]) {
            @try {
                NSMethodSignature *sig = [[player class] instanceMethodSignatureForSelector:sels[i]];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                inv.selector = sels[i];
                [inv setTarget:player];
                [inv setArgument:&posMs atIndex:2];
                [inv invoke];
                return;
            } @catch (NSException *e) {}
        }
    }
}
