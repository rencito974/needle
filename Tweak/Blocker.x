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
    if (NeedleShouldBlockURL(req.URL)) {
        if (h) {
            dispatch_async(dispatch_get_main_queue(), ^{
                h(nil, nil, [NSError errorWithDomain:@"Needle" code:-1 userInfo:nil]);
            });
        }
        return %orig([NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]], nil);
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))h {
    if (NeedleShouldBlockURL(url)) {
        if (h) {
            dispatch_async(dispatch_get_main_queue(), ^{
                h(nil, nil, [NSError errorWithDomain:@"Needle" code:-1 userInfo:nil]);
            });
        }
        return %orig([NSURL URLWithString:@"about:blank"], nil);
    }
    return %orig;
}
%end
