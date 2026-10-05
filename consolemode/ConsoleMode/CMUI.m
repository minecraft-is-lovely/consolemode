#import "CMUI.h"
#import "CMPreferences.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>

static UIColor *CMColor(NSInteger red, NSInteger green, NSInteger blue) {
    return [UIColor colorWithRed:red / 255.0
                           green:green / 255.0
                            blue:blue / 255.0
                           alpha:1.0];
}

static UIColor *CMBackground(void) { return CMColor(10, 15, 25); }
static UIColor *CMPanel(void) { return CMColor(20, 29, 42); }
static UIColor *CMAccent(void) { return CMColor(84, 229, 178); }
static UIColor *CMText(void) { return CMColor(239, 245, 249); }
static UIColor *CMSecondaryText(void) { return CMColor(154, 170, 183); }

@class CMGameViewController;
@class CMConsoleViewController;

@interface CMConsoleWindowController : NSObject
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIWindow *previousKeyWindow;
- (void)showWithURL:(nullable NSString *)url;
- (void)hide;
@end

@interface CMConsoleViewController : UIViewController
@end

@interface CMGameViewController : UIViewController <WKNavigationDelegate, WKUIDelegate>
- (instancetype)initWithURL:(NSString *)url;
@end

@interface CMSettingsViewController : UIViewController
@end

@interface CMNavigationController : UINavigationController
@end
@implementation CMNavigationController
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [CMConfiguredOrientation() isEqualToString:@"landscapeRight"]
        ? UIInterfaceOrientationMaskLandscapeRight : UIInterfaceOrientationMaskLandscapeLeft;
}
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [CMConfiguredOrientation() isEqualToString:@"landscapeRight"]
        ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationLandscapeLeft;
}
@end

@implementation CMConsoleWindowController

- (UIWindowScene *)activeWindowScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

- (void)showWithURL:(NSString *)url {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showWithURL:url]; });
        return;
    }
    // Re-check immediately before presentation, rather than relying on the
    // monitor's earlier result across the asynchronous dispatch boundary.
    if (!CMCanPresentConsole()) {
        return;
    }

    CMApplyConfiguredOrientation();
    if (!self.window) {
        self.previousKeyWindow = UIApplication.sharedApplication.keyWindow;
        UIWindowScene *scene = [self activeWindowScene];
        self.window = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                            : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.windowLevel = UIWindowLevelAlert + 1;
        self.window.backgroundColor = CMBackground();
    }

    if (!self.window.rootViewController) {
        self.window.rootViewController =
            [[CMNavigationController alloc] initWithRootViewController:
                [CMConsoleViewController new]];
    }
    if (url.length > 0) {
        UINavigationController *navigation = (UINavigationController *)self.window.rootViewController;
        [navigation setViewControllers:@[
            [CMConsoleViewController new],
            [[CMGameViewController alloc] initWithURL:url]
        ] animated:NO];
    }

    self.window.hidden = NO;
    [self.window makeKeyAndVisible];
}

- (void)hide {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self hide]; });
        return;
    }
    self.window.hidden = YES;
    if (self.previousKeyWindow && !self.previousKeyWindow.hidden) {
        [self.previousKeyWindow makeKeyWindow];
    }
    self.window.rootViewController = nil;
    self.window = nil;
    self.previousKeyWindow = nil;
    if (!CMConsoleModeEnabled()) {
        CMRestoreOrientationBehavior();
    }
}

@end

static CMConsoleWindowController *CMWindowController(void) {
    static CMConsoleWindowController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [CMConsoleWindowController new];
    });
    return controller;
}

void CMShowConsole(NSString *initialURL) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [CMWindowController() showWithURL:initialURL];
    });
}

void CMHideConsole(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [CMWindowController() hide];
    });
}

@implementation CMConsoleViewController

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UIButton *)buttonWithTitle:(NSString *)title
                  configuration:(UIButtonConfiguration *)configuration
                         action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = configuration;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButtonConfiguration *)tileConfiguration {
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.baseBackgroundColor = CMPanel();
    configuration.baseForegroundColor = CMText();
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(18, 20, 18, 20);
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    return configuration;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CMBackground();
    self.navigationController.navigationBarHidden = YES;

    UILabel *eyebrow = [UILabel new];
    eyebrow.attributedText = [[NSAttributedString alloc]
        initWithString:@"PORTABLE GAME SYSTEM"
            attributes:@{NSKernAttributeName: @1.5}];
    eyebrow.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    eyebrow.textColor = CMAccent();

    UILabel *title = [UILabel new];
    title.text = @"ConsoleMode";
    title.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    title.textColor = CMText();

    UILabel *subtitle = [UILabel new];
    subtitle.text = @"Choose a game";
    subtitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    subtitle.textColor = CMSecondaryText();

    UIButtonConfiguration *settingsConfiguration = [UIButtonConfiguration plainButtonConfiguration];
    settingsConfiguration.baseForegroundColor = CMAccent();
    settingsConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(10, 16, 10, 16);
    UIButton *settingsButton =
        [self buttonWithTitle:@"Settings" configuration:settingsConfiguration action:@selector(openSettings)];

    UIStackView *headingText = [[UIStackView alloc] initWithArrangedSubviews:@[
        eyebrow, title, subtitle
    ]];
    headingText.axis = UILayoutConstraintAxisVertical;
    headingText.spacing = 3;

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[
        headingText, settingsButton
    ]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.alignment = UIStackViewAlignmentCenter;
    heading.distribution = UIStackViewDistributionEqualSpacing;

    NSArray<NSString *> *names = CMGameNames();
    NSMutableArray<UIButton *> *tiles = [NSMutableArray arrayWithCapacity:names.count];
    for (NSUInteger index = 0; index < names.count; index++) {
        NSString *name = names[index];
        NSString *number = [NSString stringWithFormat:@"%02lu", (unsigned long)(index + 1)];
        UIButtonConfiguration *configuration = [self tileConfiguration];
        configuration.title = [NSString stringWithFormat:@"%@\n%@", number, name];
        configuration.subtitle = @"Open game";
        UIButton *tile = [UIButton buttonWithType:UIButtonTypeSystem];
        tile.configuration = configuration;
        tile.tag = index;
        [tile addTarget:self action:@selector(openGame:) forControlEvents:UIControlEventTouchUpInside];
        [tiles addObject:tile];
    }

    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:
        [tiles subarrayWithRange:NSMakeRange(0, 2)]];
    UIStackView *bottomRow = [[UIStackView alloc] initWithArrangedSubviews:
        [tiles subarrayWithRange:NSMakeRange(2, 2)]];
    for (UIStackView *row in @[topRow, bottomRow]) {
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 14;
        row.distribution = UIStackViewDistributionFillEqually;
    }

    UIStackView *tileGrid = [[UIStackView alloc] initWithArrangedSubviews:@[topRow, bottomRow]];
    tileGrid.axis = UILayoutConstraintAxisVertical;
    tileGrid.spacing = 14;
    tileGrid.distribution = UIStackViewDistributionFillEqually;

    UIButtonConfiguration *disableConfiguration =
        [UIButtonConfiguration filledButtonConfiguration];
    disableConfiguration.baseBackgroundColor = CMColor(63, 38, 48);
    disableConfiguration.baseForegroundColor = CMText();
    disableConfiguration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    disableConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(13, 20, 13, 20);
    UIButton *disableButton = [UIButton buttonWithType:UIButtonTypeSystem];
    disableButton.configuration = disableConfiguration;
    [disableButton setTitle:@"Disable ConsoleMode" forState:UIControlStateNormal];
    [disableButton addTarget:self
                      action:@selector(disableConsoleMode)
            forControlEvents:UIControlEventTouchUpInside];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[
        heading, tileGrid, disableButton
    ]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 20;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:34],
        [content.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-34],
        [content.centerYAnchor constraintEqualToAnchor:safeArea.centerYAnchor],
        [tileGrid.heightAnchor constraintEqualToConstant:190],
        [disableButton.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)openSettings {
    [self.navigationController pushViewController:[CMSettingsViewController new] animated:YES];
}

- (void)openGame:(UIButton *)sender {
    NSArray<NSString *> *urls = CMGameURLs();
    if (sender.tag >= urls.count) {
        return;
    }
    CMGameViewController *controller = [[CMGameViewController alloc] initWithURL:urls[sender.tag]];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)disableConsoleMode {
    CMSetPreference(CMPreferenceEnabled, @NO);
    CMHideConsole();
}

@end

@implementation CMGameViewController {
    NSString *_initialURL;
    WKWebView *_webView;
    UIButton *_backButton;
}

- (instancetype)initWithURL:(NSString *)url {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _initialURL = [url copy];
    }
    return self;
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CMBackground();
    self.navigationController.navigationBarHidden = YES;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.allowsInlineMediaPlayback = YES;
    configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    SEL fullscreenSelector = NSSelectorFromString(@"setElementFullscreenEnabled:");
    if ([configuration.preferences respondsToSelector:fullscreenSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(configuration.preferences,
                                               fullscreenSelector,
                                               YES);
    }
    WKWebpagePreferences *pagePreferences = [WKWebpagePreferences new];
    pagePreferences.allowsContentJavaScript = YES;
    configuration.defaultWebpagePreferences = pagePreferences;

    _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
    _webView.backgroundColor = CMBackground();
    _webView.opaque = YES;
    [self.view addSubview:_webView];

    UIVisualEffectView *controlBackground =
        [[UIVisualEffectView alloc] initWithEffect:
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    controlBackground.translatesAutoresizingMaskIntoConstraints = NO;
    controlBackground.layer.cornerRadius = 14;
    controlBackground.clipsToBounds = YES;
    [self.view addSubview:controlBackground];

    UIButtonConfiguration *controlConfiguration = [UIButtonConfiguration plainButtonConfiguration];
    controlConfiguration.baseForegroundColor = CMText();
    controlConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(8, 13, 8, 13);
    _backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _backButton.configuration = controlConfiguration;
    [_backButton setTitle:@"Console" forState:UIControlStateNormal];
    [_backButton addTarget:self action:@selector(returnToConsole) forControlEvents:UIControlEventTouchUpInside];
    [controlBackground.contentView addSubview:_backButton];
    _backButton.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *historyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    historyButton.configuration = controlConfiguration;
    [historyButton setTitle:@"Back" forState:UIControlStateNormal];
    [historyButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [controlBackground.contentView addSubview:historyButton];
    historyButton.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [controlBackground.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [controlBackground.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6],
        [controlBackground.heightAnchor constraintEqualToConstant:44],
        [_backButton.leadingAnchor constraintEqualToAnchor:controlBackground.contentView.leadingAnchor],
        [_backButton.topAnchor constraintEqualToAnchor:controlBackground.contentView.topAnchor],
        [_backButton.bottomAnchor constraintEqualToAnchor:controlBackground.contentView.bottomAnchor],
        [historyButton.leadingAnchor constraintEqualToAnchor:_backButton.trailingAnchor constant:2],
        [historyButton.trailingAnchor constraintEqualToAnchor:controlBackground.contentView.trailingAnchor],
        [historyButton.topAnchor constraintEqualToAnchor:controlBackground.contentView.topAnchor],
        [historyButton.bottomAnchor constraintEqualToAnchor:controlBackground.contentView.bottomAnchor]
    ]];

    NSURL *url = [NSURL URLWithString:_initialURL];
    if (url) {
        [_webView loadRequest:[NSURLRequest requestWithURL:url
                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                          timeoutInterval:30]];
    }
}

- (void)returnToConsole {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)goBack {
    if (_webView.canGoBack) {
        [_webView goBack];
    } else {
        [self returnToConsole];
    }
}

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    BOOL allowed = [scheme isEqualToString:@"https"] ||
                   [scheme isEqualToString:@"http"] ||
                   [scheme isEqualToString:@"about"];
    decisionHandler(allowed ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

- (WKWebView *)webView:(WKWebView *)webView
createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
forNavigationAction:(WKNavigationAction *)navigationAction
     windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // Console must remain available even when browser history is empty.
    _backButton.enabled = YES;
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) { return; }
    [self showWebError:error];
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code != NSURLErrorCancelled) { [self showWebError:error]; }
}

- (void)showWebError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not load game"
        message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) { [self->_webView reload]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Console" style:UIAlertActionStyleCancel
        handler:^(__unused UIAlertAction *action) { [self returnToConsole]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message
    initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) { completionHandler(); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message
    initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
        handler:^(__unused UIAlertAction *action) { completionHandler(NO); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) { completionHandler(YES); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
    defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame
    completionHandler:(void (^)(NSString *))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:prompt
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = defaultText; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
        handler:^(__unused UIAlertAction *action) { completionHandler(nil); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) { completionHandler(alert.textFields.firstObject.text); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@implementation CMSettingsViewController {
    UISwitch *_enabledSwitch;
    UISegmentedControl *_orientationControl;
    UISegmentedControl *_autoLaunchControl;
    NSArray<UITextField *> *_urlFields;
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UILabel *)label:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.textColor = CMText();
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CMBackground();
    self.title = @"Settings";
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = CMAccent();

    NSDictionary *values = CMPreferencesSnapshot();
    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIStackView *form = [UIStackView new];
    form.axis = UILayoutConstraintAxisVertical;
    form.spacing = 15;
    form.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:form];
    [NSLayoutConstraint activateConstraints:@[
        [form.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:32],
        [form.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-32],
        [form.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:18],
        [form.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [form.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-64]
    ]];

    UIStackView *enableRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self label:@"ConsoleMode enabled"]
    ]];
    _enabledSwitch = [UISwitch new];
    _enabledSwitch.on = [values[CMPreferenceEnabled] boolValue];
    [_enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
    [enableRow addArrangedSubview:_enabledSwitch];
    enableRow.axis = UILayoutConstraintAxisHorizontal;
    enableRow.alignment = UIStackViewAlignmentCenter;
    enableRow.distribution = UIStackViewDistributionEqualSpacing;
    [form addArrangedSubview:enableRow];

    [form addArrangedSubview:[self label:@"Landscape direction"]];
    _orientationControl = [[UISegmentedControl alloc] initWithItems:@[@"Left", @"Right"]];
    _orientationControl.selectedSegmentIndex =
        [values[CMPreferenceOrientation] isEqualToString:@"landscapeRight"] ? 1 : 0;
    [_orientationControl addTarget:self
                            action:@selector(orientationChanged:)
                  forControlEvents:UIControlEventValueChanged];
    [form addArrangedSubview:_orientationControl];

    [form addArrangedSubview:[self label:@"Open automatically after unlock"]];
    _autoLaunchControl = [[UISegmentedControl alloc] initWithItems:
        @[@"Launcher", @"Cubik", @"Bloo", @"Kintic", @"XP-OS"]];
    _autoLaunchControl.selectedSegmentIndex = 0;
    NSArray<NSString *> *urls = CMGameURLs();
    NSString *autoURL = values[CMPreferenceAutoLaunchURL];
    for (NSUInteger index = 0; index < urls.count; index++) {
        if ([autoURL isEqualToString:urls[index]]) {
            _autoLaunchControl.selectedSegmentIndex = (NSInteger)index + 1;
            break;
        }
    }
    [form addArrangedSubview:_autoLaunchControl];

    [form addArrangedSubview:[self label:@"Game destinations"]];
    NSArray<NSString *> *names = CMGameNames();
    NSMutableArray<UITextField *> *fields = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSUInteger index = 0; index < urls.count; index++) {
        UILabel *name = [self label:names[index]];
        name.textColor = CMSecondaryText();
        UITextField *field = [UITextField new];
        field.text = urls[index];
        field.placeholder = @"https://example.com";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.textColor = CMText();
        field.backgroundColor = CMPanel();
        field.layer.cornerRadius = 9;
        field.borderStyle = UITextBorderStyleNone;
        field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
        field.leftViewMode = UITextFieldViewModeAlways;
        field.translatesAutoresizingMaskIntoConstraints = NO;
        [field.heightAnchor constraintEqualToConstant:42].active = YES;
        [form addArrangedSubview:name];
        [form addArrangedSubview:field];
        [fields addObject:field];
    }
    _urlFields = fields;

    UIButtonConfiguration *saveConfiguration = [UIButtonConfiguration filledButtonConfiguration];
    saveConfiguration.baseBackgroundColor = CMAccent();
    saveConfiguration.baseForegroundColor = CMBackground();
    saveConfiguration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.configuration = saveConfiguration;
    [saveButton setTitle:@"Save settings" forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveSettings) forControlEvents:UIControlEventTouchUpInside];
    [form addArrangedSubview:saveButton];

    UILabel *note = [self label:@"If ConsoleMode is disabled, re-enable it in Settings > ConsoleMode."];
    note.textColor = CMSecondaryText();
    note.font = [UIFont systemFontOfSize:12];
    note.numberOfLines = 0;
    [form addArrangedSubview:note];
}

- (void)enabledChanged:(UISwitch *)sender {
    CMSetPreference(CMPreferenceEnabled, @(sender.isOn));
    if (!sender.isOn) {
        CMHideConsole();
    }
}

- (void)orientationChanged:(UISegmentedControl *)sender {
    CMSetPreference(CMPreferenceOrientation,
                    sender.selectedSegmentIndex == 1 ? @"landscapeRight" : @"landscapeLeft");
    CMApplyConfiguredOrientation();
}

- (void)saveSettings {
    NSMutableArray<NSString *> *validatedURLs = [NSMutableArray new];
    for (NSUInteger index = 0; index < _urlFields.count; index++) {
        NSString *value = [_urlFields[index].text stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSURLComponents *parts = [NSURLComponents componentsWithString:value];
        if (![parts.scheme.lowercaseString isEqualToString:@"https"] &&
            ![parts.scheme.lowercaseString isEqualToString:@"http"]) {
            [self showMessage:@"Each destination must use http:// or https://."];
            return;
        }
        if (parts.host.length == 0 || !parts.URL) {
            [self showMessage:@"One of the destination URLs is not valid."];
            return;
        }
        [validatedURLs addObject:parts.URL.absoluteString];
    }
    // Validate the entire form before saving any URL.
    for (NSUInteger index = 0; index < validatedURLs.count; index++) {
        CMSetPreference([NSString stringWithFormat:@"gameURL%lu", (unsigned long)index],
                        validatedURLs[index]);
    }

    NSInteger selected = _autoLaunchControl.selectedSegmentIndex;
    if (selected <= 0) {
        CMSetPreference(CMPreferenceAutoLaunchURL, @"");
    } else {
        NSArray<NSString *> *updatedURLs = CMGameURLs();
        NSUInteger index = (NSUInteger)selected - 1;
        if (index < updatedURLs.count) {
            CMSetPreference(CMPreferenceAutoLaunchURL, updatedURLs[index]);
        }
    }
    [self.view endEditing:YES];
    [self showMessage:@"Settings saved."];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ConsoleMode"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
