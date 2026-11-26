#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface NeedlePrefsListController : PSListController
@end

@implementation NeedlePrefsListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)openLastFmAuth:(PSSpecifier *)spec {
    NSString *apiKey = (NSString *)CFBridgingRelease(CFPreferencesCopyValue(
        CFSTR("LastFmApiKey"),
        CFSTR("com.renn.needle"),
        kCFPreferencesAnyUser,
        kCFPreferencesAnyHost));
    if (!apiKey.length) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"API key missing"
            message:@"Paste your Last.fm API key in the field above first. Create one at last.fm/api/account/create."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSString *url = [NSString stringWithFormat:
        @"https://www.last.fm/api/auth/?api_key=%@", apiKey];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}

- (void)openSupport:(PSSpecifier *)spec {
    [[UIApplication sharedApplication]
        openURL:[NSURL URLWithString:@"https://discord.gg/4Fk34R76tt"]
        options:@{}
        completionHandler:nil];
}

- (void)respring:(PSSpecifier *)spec {
    NSTask *task = [[NSClassFromString(@"NSTask") alloc] init];
    if (task) {
        [task setValue:@"/usr/bin/killall" forKey:@"launchPath"];
        [task setValue:@[@"-9", @"SpringBoard"] forKey:@"arguments"];
        [task performSelector:@selector(launch)];
    }
}

@end
