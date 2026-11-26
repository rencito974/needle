#import <Foundation/Foundation.h>

static NSUserDefaults *_NeedleSandboxDefaults(void) {
    static NSUserDefaults *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [[NSUserDefaults alloc] initWithSuiteName:@"com.renn.needle"];
    });
    return d;
}

id NeedlePrefRaw(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyValue(
        (__bridge CFStringRef)key,
        CFSTR("com.renn.needle"),
        kCFPreferencesAnyUser,
        kCFPreferencesAnyHost);
    if (v) return (__bridge_transfer id)v;
    return [_NeedleSandboxDefaults() objectForKey:key];
}

BOOL NeedlePrefBool(NSString *key, BOOL def) {
    id v = NeedlePrefRaw(key);
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue];
    return def;
}

NSString *NeedlePrefString(NSString *key) {
    id v = NeedlePrefRaw(key);
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

void NeedlePrefSetBool(NSString *key, BOOL val) {
    [_NeedleSandboxDefaults() setBool:val forKey:key];
    CFPreferencesSetValue(
        (__bridge CFStringRef)key,
        (__bridge CFNumberRef)@(val),
        CFSTR("com.renn.needle"),
        kCFPreferencesAnyUser,
        kCFPreferencesAnyHost);
    CFPreferencesSynchronize(CFSTR("com.renn.needle"), kCFPreferencesAnyUser, kCFPreferencesAnyHost);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedlePrefsChanged" object:key];
}

void NeedlePrefSetString(NSString *key, NSString *val) {
    if (val) {
        [_NeedleSandboxDefaults() setObject:val forKey:key];
        CFPreferencesSetValue(
            (__bridge CFStringRef)key,
            (__bridge CFStringRef)val,
            CFSTR("com.renn.needle"),
            kCFPreferencesAnyUser,
            kCFPreferencesAnyHost);
    } else {
        [_NeedleSandboxDefaults() removeObjectForKey:key];
        CFPreferencesSetValue(
            (__bridge CFStringRef)key,
            NULL,
            CFSTR("com.renn.needle"),
            kCFPreferencesAnyUser,
            kCFPreferencesAnyHost);
    }
    CFPreferencesSynchronize(CFSTR("com.renn.needle"), kCFPreferencesAnyUser, kCFPreferencesAnyHost);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedlePrefsChanged" object:key];
}
