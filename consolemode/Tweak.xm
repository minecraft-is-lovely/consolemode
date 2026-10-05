// ConsoleMode is injected into SpringBoard. The unlock-state lookup below is
// deliberately dynamic because SBLockScreenManager is private and its selectors
// can change between iOS versions and jailbreak environments.
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "ConsoleMode/CMPreferences.h"
#import "ConsoleMode/CMUI.h"

static BOOL CMWasLocked = YES;
static dispatch_source_t CMUnlockPoller = nil;

static BOOL CMReadPrivateLockState(BOOL *didReadState) {
    NSArray<NSString *> *classNames = @[
        @"SBLockScreenManager",
        @"CSLockScreenManager"
    ];
    NSArray<NSString *> *stateSelectors = @[
        @"isUILocked",
        @"isLocked",
        @"isLockScreenVisible"
    ];

    for (NSString *className in classNames) {
        Class managerClass = NSClassFromString(className);
        SEL sharedSelector = NSSelectorFromString(@"sharedInstance");
        if (!managerClass || ![managerClass respondsToSelector:sharedSelector]) {
            continue;
        }

        id manager = ((id (*)(id, SEL))objc_msgSend)(managerClass, sharedSelector);
        for (NSString *selectorName in stateSelectors) {
            SEL selector = NSSelectorFromString(selectorName);
            if ([manager respondsToSelector:selector]) {
                *didReadState = YES;
                return ((BOOL (*)(id, SEL))objc_msgSend)(manager, selector);
            }
        }
    }

    *didReadState = NO;
    return NO;
}

static BOOL CMIsDeviceLocked(void) {
    BOOL didReadPrivateState = NO;
    BOOL locked = CMReadPrivateLockState(&didReadPrivateState);
    if (didReadPrivateState) {
        return locked;
    }

    // Public fallback. Protected-data notifications are not a perfect
    // substitute for lock-state APIs, especially on devices without a passcode.
    return !UIApplication.sharedApplication.isProtectedDataAvailable;
}

BOOL CMCanPresentConsole(void) {
    return CMConsoleModeEnabled() && !CMIsDeviceLocked();
}

static void CMHandleUnlockState(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ CMHandleUnlockState(); });
        return;
    }

    static BOOL previousEnabled = NO;
    static NSString *previousOrientation = nil;
    BOOL enabled = CMConsoleModeEnabled();
    BOOL locked = CMIsDeviceLocked();
    if (!enabled && previousEnabled) {
        CMHideConsole();
    }
    if (enabled && !locked && ![previousOrientation isEqualToString:CMConfiguredOrientation()]) {
        CMApplyConfiguredOrientation();
    }
    previousEnabled = enabled;
    previousOrientation = CMConfiguredOrientation();

    if (locked) {
        previousOrientation = nil;
        CMWasLocked = YES;
        CMHideConsole();
        return;
    }

    if (CMWasLocked) {
        CMWasLocked = NO;
        if (enabled) {
            NSString *autoURL = CMAutoLaunchURL();
            CMShowConsole(autoURL.length > 0 ? autoURL : nil);
        }
    }
}

static void CMStartUnlockMonitor(void) {
    if (CMUnlockPoller) {
        return;
    }

    CMUnlockPoller = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(
        CMUnlockPoller,
        dispatch_time(DISPATCH_TIME_NOW, 0),
        NSEC_PER_SEC,
        NSEC_PER_SEC / 10);
    dispatch_source_set_event_handler(CMUnlockPoller, ^{ CMHandleUnlockState(); });
    dispatch_resume(CMUnlockPoller);

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) {
        CMHandleUnlockState();
    }];
    [center addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) {
        CMWasLocked = YES;
        CMHideConsole();
    }];
    [center addObserverForName:UIApplicationProtectedDataDidBecomeAvailable
                        object:nil
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) {
        CMHandleUnlockState();
    }];
}

// These hooks affect only this injected process, not arbitrary third-party
// applications. UIKit and SpringBoard's scene policy still have the final say.
%group ConsoleModeOrientation
%hook UIDevice
- (UIDeviceOrientation)orientation {
    if (CMConsoleModeEnabled() && !CMWasLocked) {
        return [CMConfiguredOrientation() isEqualToString:@"landscapeRight"]
            ? UIDeviceOrientationLandscapeLeft : UIDeviceOrientationLandscapeRight;
    }
    return %orig;
}
%end

%hook UIApplication
- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    if (CMConsoleModeEnabled() && !CMWasLocked) {
        return [CMConfiguredOrientation() isEqualToString:@"landscapeRight"]
            ? UIInterfaceOrientationMaskLandscapeRight : UIInterfaceOrientationMaskLandscapeLeft;
    }
    return %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            return;
        }
        %init(ConsoleModeOrientation);
        dispatch_async(dispatch_get_main_queue(), ^{
            CMStartUnlockMonitor();
            CMHandleUnlockState();
        });
    }
}
