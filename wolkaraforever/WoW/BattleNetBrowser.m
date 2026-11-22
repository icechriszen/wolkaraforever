#import "BattleNetBrowser.h"
#import "BattleNetSession.h"
#import "../App/WKLocalization.h"
#import "../App/WolkaraForeverLog.h"
#import <WebKit/WebKit.h>

@interface TKBattleNetBrowser () <WKNavigationDelegate>
@end

@implementation TKBattleNetBrowser {
    NSString *_region;
    NSString *_locale;
    WKWebView *_web;
    BOOL _finished;
    BOOL _trustedMainNavigation;
    WKNavigation *_navigation;
    NSTimer *_deadline;
    NSURL *_loginURL;
    UITextField *_returnField;
    UIScrollView *_returnScroll;
    UILabel *_returnHelp;
    BOOL _externalLoginActive;
}

+ (WKWebsiteDataStore *)signInDataStore {
    // Isolated from add-on browsing and kept in memory only (hardened local build):
    // the Battle.net web session can mint new launch tickets, so it is never written
    // to disk and ends with this process. WebKit owns the cookies; the launcher never
    // reads or exports their values. One store per process so a cancelled attempt
    // can be retried without signing in again.
    static WKWebsiteDataStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store=WKWebsiteDataStore.nonPersistentDataStore; });
    return store;
}
+ (void)clearSavedSignInWithCompletion:(void (^)(void))completion {
    [TKBattleNetSession clear];
    [[self signInDataStore] removeDataOfTypes:WKWebsiteDataStore.allWebsiteDataTypes
                              modifiedSince:NSDate.distantPast completionHandler:completion];
}

- (instancetype)initWithRegion:(NSString *)region locale:(NSString *)locale {
    if ((self=[super init])) {
        _region=[region.lowercaseString copy];
        _locale=[locale copy];
        _loginURL=TKBattleNetLoginURL(region);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=WKLocalized(@"login.title");
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:WKLocalized(@"login.external")
        style:UIBarButtonItemStylePlain target:self action:@selector(showExternalLogin)];
    self.navigationItem.rightBarButtonItem.accessibilityIdentifier=@"wow.login.external";
    WKWebViewConfiguration *configuration=[WKWebViewConfiguration new];
    // No injected scripts, password storage or JavaScript bridge.
    configuration.websiteDataStore=[TKBattleNetBrowser signInDataStore];
    _web=[[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    _web.navigationDelegate=self;
    _web.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:_web];
    [NSLayoutConstraint activateConstraints:@[
        [_web.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_web.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [_web.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_web.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
    if (!_loginURL) {
        WKLog("battle-login", @"browser refused: invalid selected region");
        [self cancel];
        return;
    }
    NSURL *url=_loginURL;
    self.navigationItem.prompt=url.host;
    WKLog("battle-login", @"browser opened: official sign-in page");
    [_web loadRequest:[NSURLRequest requestWithURL:url]];
    __weak typeof(self) weakSelf=self;
    _deadline=[NSTimer scheduledTimerWithTimeInterval:600 repeats:NO block:^(__unused NSTimer *timer) {
        [weakSelf cancel];
    }];
}

- (void)finish:(BOOL)received {
    if (_finished) return;
    _finished=YES;
    [_deadline invalidate];
    _deadline=nil;
    _navigation=nil;
    _returnField.text=@"";
    _web.navigationDelegate=nil;
    [_web stopLoading];
    [_web removeFromSuperview];
    _web=nil;
    if (!received) [TKBattleNetSession clear];
    WKLog("battle-login", @"browser closed: %@", received?@"accepted result":@"no result");
    void (^completion)(BOOL)=self.completion;
    self.completion=nil;
    // Dismiss the login sheet and any validation alert together. Dismissing self
    // while it presents an alert would dismiss only the alert on timeout.
    UIViewController *container=self.navigationController?:self;
    UIViewController *presenter=container.presentingViewController;
    void (^done)(void)=^{ if (completion) completion(received); };
    if (presenter) [presenter dismissViewControllerAnimated:YES completion:done];
    else done();
}

- (void)cancel { [self finish:NO]; }

- (void)webView:(__unused WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (_finished || _externalLoginActive) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    NSURL *url=action.request.URL;
    NSString *ticket=TKBattleNetCallbackTicket(url);
    if (ticket) {
        // A callback must originate in the main frame of an approved sign-in page.
        WKSecurityOrigin *origin=action.sourceFrame.securityOrigin;
        NSURLComponents *source=[NSURLComponents new];
        source.scheme=origin.protocol;
        source.host=origin.host;
        if (origin.port) source.port=@(origin.port);
        BOOL trusted=action.sourceFrame.mainFrame && action.targetFrame.mainFrame &&
                     TKBattleNetTrustedURL(source.URL);
        // A rejected navigation must never become an accepted failure callback.
        _trustedMainNavigation=NO;
        decisionHandler(WKNavigationActionPolicyCancel);
        if (trusted) [self finish:[TKBattleNetSession acceptTicket:ticket region:_region locale:_locale]];
        else WKLog("battle-login", @"callback refused: untrusted source");
        return;
    }
    // Federation leaves Blizzard's domains for the provider's own HTTPS page. This is allowed
    // only inside the acknowledged browser. The localhost result stays strict: only an official
    // Blizzard main frame may deliver the game ticket.
    if (action.targetFrame.mainFrame || !action.targetFrame) {
        BOOL blizzard=TKBattleNetTrustedURL(url);
        if (!blizzard && !TKBattleNetFederatedURL(url)) {
            WKLog("battle-login", @"navigation refused: untrusted top-level page");
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        _trustedMainNavigation=blizzard;
        if (!action.targetFrame) {
            decisionHandler(WKNavigationActionPolicyCancel);
            [_web loadRequest:action.request];
            return;
        }
        self.navigationItem.prompt=url.host;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(__unused WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    _navigation=navigation;
}

- (BOOL)acceptMainFrameRedirect:(NSURL *)url navigation:(WKNavigation *)navigation {
    // WebKit can reject port zero before a navigation action is delivered. Only
    // accept a redirect/error for the current, approved main-frame navigation.
    if (_finished || _externalLoginActive || !_trustedMainNavigation || !navigation || navigation!=_navigation) return NO;
    NSString *ticket=TKBattleNetCallbackTicket(url);
    if (!ticket) return NO;
    [self finish:[TKBattleNetSession acceptTicket:ticket region:_region locale:_locale]];
    return YES;
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    if ([self acceptMainFrameRedirect:webView.URL navigation:navigation]) [webView stopLoading];
}

- (void)webView:(__unused WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
    withError:(NSError *)error {
    if (_finished || _externalLoginActive || ([error.domain isEqual:NSURLErrorDomain] && error.code==NSURLErrorCancelled)) return;
    id failingURL=error.userInfo[NSURLErrorFailingURLErrorKey];
    if (![failingURL isKindOfClass:NSURL.class]) {
        id text=error.userInfo[NSURLErrorFailingURLStringErrorKey];
        if ([text isKindOfClass:NSString.class] && [text length]<=8192) failingURL=[NSURL URLWithString:text];
    }
    if ([failingURL isKindOfClass:NSURL.class] &&
        [self acceptMainFrameRedirect:failingURL navigation:navigation]) return;
    // NSError descriptions can contain credential-bearing URLs; never show/log them.
    self.navigationItem.prompt=WKLocalized(@"login.failed");
}

- (void)showExternalLogin {
    if (_finished || _externalLoginActive || !_loginURL) return;
    _externalLoginActive=YES;
    _trustedMainNavigation=NO; _navigation=nil;
    _web.navigationDelegate=nil; [_web stopLoading]; [_web removeFromSuperview]; _web=nil;
    self.navigationItem.rightBarButtonItem=nil;
    _returnHelp=[UILabel new]; _returnHelp.numberOfLines=0;
    _returnHelp.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _returnHelp.text=WKLocalized(@"login.externalHelp");
    UIButton *open=[UIButton buttonWithType:UIButtonTypeSystem];
    [open setTitle:WKLocalized(@"login.open") forState:UIControlStateNormal];
    open.accessibilityIdentifier=@"wow.login.openBrowser";
    [open addTarget:self action:@selector(openExternalBrowser) forControlEvents:UIControlEventTouchUpInside];
    _returnField=[UITextField new]; _returnField.secureTextEntry=YES;
    _returnField.borderStyle=UITextBorderStyleRoundedRect;
    _returnField.placeholder=WKLocalized(@"login.paste");
    _returnField.accessibilityIdentifier=@"wow.login.browserReturn";
    _returnField.accessibilityLabel=WKLocalized(@"login.privateAddress");
    _returnField.autocorrectionType=UITextAutocorrectionTypeNo;
    _returnField.spellCheckingType=UITextSpellCheckingTypeNo;
    _returnField.autocapitalizationType=UITextAutocapitalizationTypeNone;
    _returnField.smartQuotesType=UITextSmartQuotesTypeNo;
    _returnField.smartDashesType=UITextSmartDashesTypeNo;
    _returnField.keyboardType=UIKeyboardTypeURL;
    _returnField.returnKeyType=UIReturnKeyDone;
    [_returnField addTarget:self action:@selector(useBrowserReturn) forControlEvents:UIControlEventEditingDidEndOnExit];
    UIButton *use=[UIButton buttonWithType:UIButtonTypeSystem];
    [use setTitle:WKLocalized(@"login.continue") forState:UIControlStateNormal];
    use.accessibilityIdentifier=@"wow.login.useBrowserReturn";
    [use addTarget:self action:@selector(useBrowserReturn) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[_returnHelp,open,_returnField,use]];
    stack.axis=UILayoutConstraintAxisVertical; stack.spacing=16; stack.translatesAutoresizingMaskIntoConstraints=NO;
    _returnScroll=[UIScrollView new]; _returnScroll.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:_returnScroll]; [_returnScroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [_returnScroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_returnScroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [_returnScroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_returnScroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:_returnScroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:_returnScroll.contentLayoutGuide.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:_returnScroll.contentLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:_returnScroll.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:_returnScroll.frameLayoutGuide.widthAnchor constant:-40],
        [_returnField.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [open.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [use.heightAnchor constraintGreaterThanOrEqualToConstant:44]]];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_externalLoginActive && _returnField.isFirstResponder)
        [_returnScroll scrollRectToVisible:[_returnField convertRect:_returnField.bounds toView:_returnScroll] animated:NO];
}
- (void)openExternalBrowser {
    if (_finished || !_externalLoginActive || !_loginURL) return;
    [_returnField resignFirstResponder];
    __weak typeof(self) weakSelf=self;
    [UIApplication.sharedApplication openURL:_loginURL options:@{} completionHandler:^(BOOL success) {
        TKBattleNetBrowser *host=weakSelf;
        if (host && !success && !host->_finished) host->_returnHelp.text=WKLocalized(@"login.openFailed");
    }];
}
- (void)useBrowserReturn {
    if (_finished || !_externalLoginActive || self.presentedViewController) return;
    // Explicit user paste only: no pasteboard access or Safari credential extraction.
    NSString *problem=nil;
    NSString *ticket=TKBattleNetPastedCallbackTicket(_returnField.text?:@"",&problem);
    _returnField.text=@"";
    [_returnField resignFirstResponder];
    if (!ticket) {
        // Keep the visible result beside the action: the help label can be above
        // the viewport after the keyboard scrolls the private input into view.
        WKLog("battle-login", @"browser return refused: %@", problem?:@"endpoint");
        NSString *message=WKLocalized([@"login.returnError." stringByAppendingString:(problem?:@"endpoint")]);
        _returnHelp.text=message;
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:WKLocalized(@"login.returnError.title")
            message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:WKLocalized(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    WKLog("battle-login", @"browser return received: validated address");
    [self finish:[TKBattleNetSession acceptTicket:ticket region:_region locale:_locale]];
}

- (void)dealloc { [_deadline invalidate]; }
@end
