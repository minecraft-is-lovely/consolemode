#import "CMPreferences.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>

NSString * const CMPreferencesDomain = @"com.cubik.consolemode";
NSString * const CMPreferenceEnabled = @"enabled";
NSString * const CMPreferenceOrientation = @"orientation";
NSString * const CMPreferenceAutoLaunchURL = @"autoLaunchURL";

static NSDictionary *CMCachedPreferences;
static NSTimeInterval CMPreferencesExpiry;

static NSDictionary<NSString *, id> *CMDefaultPreferences(void) {
    return @{
        CMPreferenceEnabled: @NO,
        CMPreferenceOrientation: @"landscapeLeft",
        CMPreferenceAutoLaunchURL: @"",
        @"gameURL0": @"https://cubik-game.replit.app",
        @"gameURL1": @"https://bloo.watch",
        @"gameURL2": @"https://kintic.site",
        @"gameURL3": @"https://xp-os.replit.app"
    };
}

static NSString *CMValidWebURL(id candidate, NSString *fallback) {
    if (![candidate isKindOfClass:NSString.class] || [candidate length] == 0) {
        return fallback;
    }
    NSURLComponents *parts = [NSURLComponents componentsWithString:candidate];
    NSString *scheme = parts.scheme.lowercaseString;
    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) {
        return fallback;
    }
    if (parts.host.length == 0) {
        return fallback;
    }
    return parts.URL.absoluteString ?: fallback;
}

NSDictionary<NSString *, id> *CMPreferencesSnapshot(void) {
    @synchronized(CMPreferencesDomain) {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (CMCachedPreferences && now < CMPreferencesExpiry) {
        return CMCachedPreferences;
    }
    CFPreferencesAppSynchronize((__bridge CFStringRef)CMPreferencesDomain);
    CFDictionaryRef stored = CFPreferencesCopyMultiple(
        NULL,
        (__bridge CFStringRef)CMPreferencesDomain,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost);
    NSDictionary *storedValues = stored ? CFBridgingRelease(stored) : @{};

    NSMutableDictionary *result = [CMDefaultPreferences() mutableCopy];
    if ([storedValues isKindOfClass:NSDictionary.class]) {
        [result addEntriesFromDictionary:storedValues];
    }

    NSDictionary *defaults = CMDefaultPreferences();
    for (NSUInteger index = 0; index < 4; index++) {
        NSString *key = [NSString stringWithFormat:@"gameURL%lu", (unsigned long)index];
        result[key] = CMValidWebURL(result[key], defaults[key]);
    }

    result[CMPreferenceAutoLaunchURL] = CMValidWebURL(result[CMPreferenceAutoLaunchURL], @"");
    id orientation = result[CMPreferenceOrientation];
    result[CMPreferenceOrientation] =
        [orientation isKindOfClass:NSString.class] && [orientation isEqualToString:@"landscapeRight"]
            ? @"landscapeRight" : @"landscapeLeft";
    id enabled = result[CMPreferenceEnabled];
    result[CMPreferenceEnabled] = [enabled respondsToSelector:@selector(boolValue)]
        ? @([enabled boolValue]) : @NO;
    CMCachedPreferences = [result copy];
    CMPreferencesExpiry = now + 0.5;
    return CMCachedPreferences;
    }
}

NSArray<NSString *> *CMGameNames(void) {
    return @[ @"Cubik Game", @"Bloo", @"Kintic", @"XP-OS" ];
}

NSArray<NSString *> *CMGameURLs(void) {
    NSDictionary *preferences = CMPreferencesSnapshot();
    return @[
        preferences[@"gameURL0"],
        preferences[@"gameURL1"],
        preferences[@"gameURL2"],
        preferences[@"gameURL3"]
    ];
}

BOOL CMConsoleModeEnabled(void) {
    return [CMPreferencesSnapshot()[CMPreferenceEnabled] boolValue];
}

NSString *CMConfiguredOrientation(void) {
    return CMPreferencesSnapshot()[CMPreferenceOrientation];
}

NSString * _Nullable CMAutoLaunchURL(void) {
    NSString *value = CMPreferencesSnapshot()[CMPreferenceAutoLaunchURL];
    return value.length ? value : nil;
}

void CMSetPreference(NSString *key, id value) {
    if (key.length == 0 || !value) {
        return;
    }
    @synchronized(CMPreferencesDomain) {
    CFPreferencesSetAppValue(
        (__bridge CFStringRef)key,
        (__bridge CFPropertyListRef)value,
        (__bridge CFStringRef)CMPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)CMPreferencesDomain);
    CMCachedPreferences = nil;
    }
}

void CMApplyConfiguredOrientation(void) {
    if (!CMConsoleModeEnabled()) {
        return;
    }
    NSInteger orientation = [CMConfiguredOrientation() isEqualToString:@"landscapeRight"]
        ? UIInterfaceOrientationLandscapeRight
        : UIInterfaceOrientationLandscapeLeft;

    UIApplication *application = UIApplication.sharedApplication;
    if (@available(iOS 16.0, *)) {
        UIInterfaceOrientationMask mask = orientation == UIInterfaceOrientationLandscapeRight
            ? UIInterfaceOrientationMaskLandscapeRight : UIInterfaceOrientationMaskLandscapeLeft;
        for (UIScene *scene in application.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowSceneGeometryPreferencesIOS *geometry =
                    [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
                [(UIWindowScene *)scene requestGeometryUpdateWithPreferences:geometry
                    errorHandler:^(NSError *error) {
                        // No URLs or browsing information are logged.
                        NSLog(@"[ConsoleMode] Scene rejected orientation request (%ld).",
                              (long)error.code);
                    }];
            }
        }
    }

    // Deprecated public API retained for compatibility with SpringBoard's
    // existing orientation coordinator. It is not a guaranteed device-wide lock.
    SEL statusBarSelector = NSSelectorFromString(@"setStatusBarOrientation:animated:");
    if ([application respondsToSelector:statusBarSelector]) {
        ((void (*)(id, SEL, NSInteger, BOOL))objc_msgSend)(
            application, statusBarSelector, orientation, YES);
    }

    // Private UIDevice setter. Availability and effect vary by iOS build and
    // jailbreak; the launcher UI itself still supports landscape layout.
    UIDevice *device = UIDevice.currentDevice;
    SEL privateSetter = NSSelectorFromString(@"setOrientation:");
    if ([device respondsToSelector:privateSetter]) {
        // Device and interface landscape enums describe opposite directions.
        UIDeviceOrientation deviceOrientation = orientation == UIInterfaceOrientationLandscapeRight
            ? UIDeviceOrientationLandscapeLeft : UIDeviceOrientationLandscapeRight;
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(device, privateSetter, deviceOrientation);
    }
}

void CMRestoreOrientationBehavior(void) {
    // The hooks return their original values once enabled is false. We never
    // change the user's system rotation-lock setting.
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIViewController attemptRotationToDeviceOrientation];
        if (@available(iOS 16.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:UIWindowScene.class]) {
                    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                        [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
                    }
                }
            }
        }
    });
}
