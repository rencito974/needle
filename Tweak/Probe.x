#ifdef NEEDLE_PROBE
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *NeedleProbePath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:@"needle-probe.txt"];
}

static BOOL NeedleProbeInteresting(const char *name) {
    if (!name) return NO;
    if (strncmp(name, "SPT", 3) == 0) return YES;
    if (strncmp(name, "Spotify", 7) == 0) return YES;
    if (strstr(name, "FreeTier")) return YES;
    if (strstr(name, "NowPlaying")) return YES;
    if (strstr(name, "Shuffle")) return YES;
    if (strstr(name, "Entitlement")) return YES;
    if (strstr(name, "Premium")) return YES;
    if (strstr(name, "AdsManager") || strstr(name, "AdSlot")) return YES;
    if (strstr(name, "Artwork")) return YES;
    if (strstr(name, "Playback")) return YES;
    if (strstr(name, "PlayerContext")) return YES;
    return NO;
}

static void NeedleProbeDump(NSString *stage) {
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"\n===== STAGE: %@ at %@ =====\n", stage, [NSDate date]];

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSUInteger matched = 0;

    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        const char *name = class_getName(cls);
        if (!NeedleProbeInteresting(name)) continue;
        matched++;

        Class super = class_getSuperclass(cls);
        [out appendFormat:@"\n@interface %s : %s\n", name, super ? class_getName(super) : "nil"];

        unsigned int mcount = 0;
        Method *methods = class_copyMethodList(cls, &mcount);
        for (unsigned int j = 0; j < mcount; j++) {
            SEL sel = method_getName(methods[j]);
            char *ret = method_copyReturnType(methods[j]);
            unsigned int argc = method_getNumberOfArguments(methods[j]);
            [out appendFormat:@"  - (%s)%s // argc=%u\n", ret ?: "?", sel_getName(sel), argc];
            if (ret) free(ret);
        }
        if (methods) free(methods);

        Method *cmethods = class_copyMethodList(object_getClass(cls), &mcount);
        for (unsigned int j = 0; j < mcount; j++) {
            SEL sel = method_getName(cmethods[j]);
            char *ret = method_copyReturnType(cmethods[j]);
            [out appendFormat:@"  + (%s)%s\n", ret ?: "?", sel_getName(sel)];
            if (ret) free(ret);
        }
        if (cmethods) free(cmethods);

        unsigned int pcount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &pcount);
        for (unsigned int j = 0; j < pcount; j++) {
            [out appendFormat:@"  @property %s %s\n",
                property_getAttributes(props[j]) ?: "",
                property_getName(props[j])];
        }
        if (props) free(props);

        [out appendString:@"@end\n"];
    }
    free(classes);

    [out insertString:[NSString stringWithFormat:@"total_classes=%u matched=%lu\n", count, (unsigned long)matched] atIndex:0];

    NSString *path = NeedleProbePath();
    NSString *existing = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSString *combined = [existing stringByAppendingString:out];
    [combined writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"[Needle] probe stage=%@ matched=%lu path=%@", stage, (unsigned long)matched, path);
}

%ctor {
    NSLog(@"[Needle] probe build loaded, dumping in 5s/30s/120s to Documents/needle-probe.txt");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleProbeDump(@"launch+5s");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleProbeDump(@"launch+30s");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NeedleProbeDump(@"launch+120s_after_playing_a_song");
    });
}
#endif
