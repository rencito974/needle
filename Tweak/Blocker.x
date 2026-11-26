#import <Foundation/Foundation.h>

extern BOOL NeedlePrefBool(NSString *key, BOOL def);

static NSArray *NeedleBlockedHosts(void) {
    return @[
        @"pixel.spotify.com",
        @"adeventtracker.spotify.com",
        @"ads-fa.spotify.com",
        @"analytics.scdn.co",
        @"log.spotify.com",
        @"logs.spotify.com",
        @"doubleclick.net",
        @"googleadservices.com",
        @"googletagmanager.com",
    ];
}

static BOOL NeedleShouldBlockURL(NSURL *url) {
    if (!NeedlePrefBool(@"DNSBlock", YES)) return NO;
    NSString *host = url.host;
    if (!host.length) return NO;
    for (NSString *h in NeedleBlockedHosts()) {
        if ([host containsString:h] || [host hasSuffix:h]) return YES;
    }
    return NO;
}

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))h {
    NSURLSessionDataTask *task = %orig;
    if (task && NeedleShouldBlockURL(req.URL)) {
        [task cancel];
    }
    return task;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))h {
    NSURLSessionDataTask *task = %orig;
    if (task && NeedleShouldBlockURL(url)) {
        [task cancel];
    }
    return task;
}
%end
