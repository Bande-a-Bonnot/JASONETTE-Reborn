#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

@interface Probe : NSObject <WKNavigationDelegate>
@property (nonatomic) BOOL loaded;
@property (nonatomic, strong) NSError *failure;
@end
@implementation Probe
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { self.loaded = YES; fprintf(stderr, "Navigation finished\n"); }
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { self.failure = error; fprintf(stderr, "Navigation error: %s\n", error.localizedDescription.UTF8String); }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { self.failure = error; fprintf(stderr, "Navigation error: %s\n", error.localizedDescription.UTF8String); }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView { fprintf(stderr, "WebContent process terminated\n"); }
@end

int main(void) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600) configuration:config];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.contentView = webView;
    [window orderFront:nil];
    Probe *probe = [Probe new];
    webView.navigationDelegate = probe;
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8765/index.html"]]];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:60];
    __block NSDictionary *snapshot = nil;
    __block NSString *lastError = nil;
    while ([deadline timeIntervalSinceNow] > 0 && !probe.failure) {
      __block BOOL received = NO;
      [webView evaluateJavaScript:@"JSON.stringify(window.snapshot ? window.snapshot() : null)" completionHandler:^(id result, NSError *error) {
        if (error) lastError = error.localizedDescription;
        else if ([result isKindOfClass:NSString.class]) {
          NSData *json = [result dataUsingEncoding:NSUTF8StringEncoding];
          snapshot = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
        }
        received = YES;
      }];
      NSDate *pollDeadline = [NSDate dateWithTimeIntervalSinceNow:0.3];
      while (!received && [pollDeadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
      }
      if ([snapshot[@"results"] count] == 4) break;
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
    }
    if (probe.failure) { fprintf(stderr, "Navigation failed: %s\n", probe.failure.localizedDescription.UTF8String); return 2; }
    if (!snapshot) { fprintf(stderr, "No snapshot: %s\n", lastError.UTF8String ?: "unknown"); return 2; }
    NSData *pretty = [NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];
    puts([[NSString alloc] initWithData:pretty encoding:NSUTF8StringEncoding].UTF8String);
    BOOL ok = YES;
    NSArray *ids = @[@"component-inline", @"component-url", @"background-inline", @"background-url"];
    NSDictionary *results = snapshot[@"results"];
    NSArray *frames = snapshot[@"frames"];
    if ([results count] != 4 || [frames count] != 4) { fprintf(stderr, "INCONCLUSIVE: expected four reports and frames\n"); return 2; }
    if (![snapshot[@"href"] isEqualToString:@"http://127.0.0.1:8765/index.html"]) { fprintf(stderr, "Top-level navigation occurred\n"); ok = NO; }
    if (![snapshot[@"parentStorage"] isEqualToString:@"parent-storage-secret"]) { fprintf(stderr, "Parent storage setup failed\n"); ok = NO; }
    for (NSString *name in ids) {
      NSDictionary *item = results[name];
      if (![item[@"ran"] boolValue] || ![item[@"eventOrigin"] isEqualToString:@"null"] ||
          ![item[@"parentDOM"] isEqualToString:@"SecurityError"] ||
          ![item[@"parentStorage"] isEqualToString:@"SecurityError"] ||
          ![item[@"childStorage"] isEqualToString:@"SecurityError"] ||
          ![item[@"topNavigation"] isEqualToString:@"SecurityError"]) {
        fprintf(stderr, "Isolation assertion failed: %s\n", name.UTF8String); ok = NO;
      }
    }
    for (NSDictionary *frame in frames) {
      if (![frame[@"sandbox"] isEqualToString:@"allow-scripts"]) { fprintf(stderr, "Sandbox mismatch\n"); ok = NO; }
    }
    if (ok) fprintf(stderr, "PASS: four renderer iframes executed scripts and remained isolated\n");
    return ok ? 0 : 1;
  }
}
