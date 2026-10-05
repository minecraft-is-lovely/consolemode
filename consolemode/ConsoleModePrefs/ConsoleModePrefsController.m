#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Minimal declarations for the PRIVATE Preferences framework. These are not
// public SDK classes. PreferenceLoader supplies this integration at runtime.
@interface PSSpecifier : NSObject
- (id)propertyForKey:(NSString *)key;
@end

@interface PSListController : UIViewController
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end

@interface ConsoleModePrefsController : PSListController
@property(nonatomic, strong) NSArray *cachedSpecifiers;
@end

@implementation ConsoleModePrefsController

- (NSArray *)specifiers {
    if (!self.cachedSpecifiers) {
        self.cachedSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return self.cachedSpecifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSString *domain = [specifier propertyForKey:@"defaults"];
    CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key, (__bridge CFStringRef)domain);
    return value ? CFBridgingRelease(value) : [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSString *domain = [specifier propertyForKey:@"defaults"];
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)domain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
}

@end
