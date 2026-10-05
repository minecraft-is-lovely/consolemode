#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const CMPreferencesDomain;
FOUNDATION_EXPORT NSString * const CMPreferenceEnabled;
FOUNDATION_EXPORT NSString * const CMPreferenceOrientation;
FOUNDATION_EXPORT NSString * const CMPreferenceAutoLaunchURL;

FOUNDATION_EXPORT NSArray<NSString *> *CMGameNames(void);
FOUNDATION_EXPORT NSArray<NSString *> *CMGameURLs(void);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *CMPreferencesSnapshot(void);
FOUNDATION_EXPORT BOOL CMConsoleModeEnabled(void);
FOUNDATION_EXPORT NSString *CMConfiguredOrientation(void);
FOUNDATION_EXPORT NSString * _Nullable CMAutoLaunchURL(void);
FOUNDATION_EXPORT void CMSetPreference(NSString *key, id value);
FOUNDATION_EXPORT void CMApplyConfiguredOrientation(void);
FOUNDATION_EXPORT void CMRestoreOrientationBehavior(void);

NS_ASSUME_NONNULL_END
