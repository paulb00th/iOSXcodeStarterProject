//
//  AppDelegate.m
//

#import "AppDelegate.h"
#import "AnalyticsKitDebugProvider.h"
#import "AnalyticsKitTestFlightProvider.h"
#import "MagicalRecord.h"

@implementation AppDelegate

@synthesize window = _window;

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [MagicalRecord setupAutoMigratingCoreDataStack];
    [self configureAnalyticsWithOptions:launchOptions];
    [self configureCache];
    [self addLowMemoryWarningsToSimulatorBuilds];
    return YES;
}

-(void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

-(void)applicationWillTerminate:(UIApplication *)application {
    [MagicalRecord cleanUp];
}

#pragma mark -
#pragma mark Cache

- (void)configureCache {
    // Create a new NSURLCache with 4MB RAM to reduce memory utilization
    int cacheSizeMemory = 4*1024*1024; // 4MB
    int cacheSizeDisk = 40*1024*1024; // 40MB
    NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:cacheSizeMemory diskCapacity:cacheSizeDisk diskPath:@"nsurlcache"];
    [NSURLCache setSharedURLCache:sharedCache];
}

#pragma mark -
#pragma mark Enable Memory Warngins in Simulator

- (void)addLowMemoryWarningsToSimulatorBuilds {
#if (TARGET_IPHONE_SIMULATOR) 
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:[UIApplication sharedApplication]];
    // Manually call applicationDidReceiveMemoryWarning
    [[[UIApplication sharedApplication] delegate] applicationDidReceiveMemoryWarning:[UIApplication sharedApplication]];
    [self performSelector:@selector(addLowMemoryWarningsToSimulatorBuilds) withObject:nil afterDelay:10];    
#endif
}

#pragma mark -
#pragma mark User Agent

-(void)configureUserAgent {
    // Append app name and version information to User Agent string
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *secretAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    if (secretAgent == nil || [secretAgent length] == 0) return;
    NSString *newAgent = [NSString stringWithFormat: @"%@%@%@%@%@%@%@",
                          secretAgent, 
                          [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                          (TARGETED_DEVICE_IS_IPHONE) ? @" (iPhone " : @" (iPad ",
                          [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                          @" ",
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                          @")"];
    NSDictionary *agentDictionary = [NSDictionary dictionaryWithObjectsAndKeys: newAgent, @"UserAgent", nil];    
    [[NSUserDefaults standardUserDefaults] registerDefaults:agentDictionary];
    NSLog(@"UA: %@", newAgent);    
}
	
#pragma mark -
#pragma mark Analytics

void analyticsExceptionHandler(NSException *exception) {
    [AnalyticsKit uncaughtException:exception];    
}

-(void)configureAnalyticsWithOptions:(NSDictionary *)launchOptions {
    NSMutableArray *providers = [NSMutableArray array];
    #ifdef DEBUG
        // Debug provider pops a UIAlertView when an error is logged
        [providers addObject:[[AnalyticsKitDebugProvider alloc] init]];
    #endif
    
    #if (!TARGET_IPHONE_SIMULATOR)
        #ifdef DEBUG
            // Debug provider pops a UIAlertView when an error is logged
            [providers addObject:[[AnalyticsKitDebugProvider alloc] init]];
            // Setup TestFlight provider
            NSString *testFlightKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:TESTFLIGHT_KEY];
            [providers addObject:[[AnalyticsKitTestFlightProvider alloc] initWithAPIKey:testFlightKey]];
        #endif
//    NSString *flurryKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:FLURRY_KEY];
//    [providers addObject:[[AnalyticsKitFlurryProvider alloc] initWithAPIKey:flurryKey]];
    
//    NSString *apsalarKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:APSALAR_KEY];
//    NSString *apsalarSecret = [[NSBundle mainBundle] objectForInfoDictionaryKey:APSALAR_SECRET];
//    [providers addObject:[[AnalyticsKitApsalarProvider alloc] initWithAPIKey:apsalarKey andSecret:apsalarSecret andLaunchOptions:launchOptions]]; 
    
//    NSString *localyticsKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:LOCALYTICS_KEY];
//    [providers addObject:[[AnalyticsKitLocalyitcsProvider alloc] initWithAPIKey:localyticsKey]];
    #endif
    [AnalyticsKit initializeLoggers:providers];

    //initialize AnalyticsKit to send messages to Flurry and TestFlight
    NSSetUncaughtExceptionHandler(&analyticsExceptionHandler);
    
    // Track iOS version so we know when we can drop support for older versions
    NSDictionary *versDict = [NSDictionary dictionaryWithObject:[[UIDevice currentDevice] systemVersion] forKey:@"version"];
    [AnalyticsKit logEvent:@"App Started" withProperties:versDict];
}

#pragma mark -
#pragma mark Activity Indicator

- (void)setNetworkActivityIndicatorVisible:(BOOL)setVisible {
    // http://oleb.net/blog/2009/09/managing-the-network-activity-indicator/
    static NSInteger numberOfCallsToSetVisible = 0;
    if (setVisible) 
        numberOfCallsToSetVisible++;
    else 
        numberOfCallsToSetVisible--;
    
    // The assertion helps to find programmer errors in activity indicator management.
#ifdef DEBUG
    NSAssert(numberOfCallsToSetVisible >= 0, @"Network Activity Indicator was asked to hide more often than shown");
#endif        
    // Display the indicator as long as our static counter is > 0.
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(numberOfCallsToSetVisible > 0)];
}

@end
