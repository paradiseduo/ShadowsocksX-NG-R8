//
//  AppDelegate.m
//  LaunchAtLoginHelper
//
//  Created by Jovi on 12/23/15.
//  Copyright © 2015 Jovi. All rights reserved.
//

#import "AppDelegate.h"
#define mainAppBundleIdentifier @"com.qiuyuzhou.ShadowsocksX-NG"
#define mainAppName @"ShadowsocksX-NG"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Check if main app is already running;
    // If yes, do nothing and terminate helper app
    BOOL alreadyRunning = NO;
    NSArray *running = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication *app in running) {
        if ([[app bundleIdentifier] isEqualToString:mainAppBundleIdentifier]) {
            alreadyRunning = YES;
        }
    }
    
    if (!alreadyRunning) {
        [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"ShadowsocksX_NG_R8_KILL_LAUNCHER" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [NSApp terminate:nil];
        }];
        // Launch main app
        NSString *path = [[NSBundle mainBundle] bundlePath];
        NSArray *p = [path pathComponents];
        NSMutableArray *pathComponents = [NSMutableArray arrayWithArray:p];
        [pathComponents removeLastObject];
        [pathComponents removeLastObject];
        [pathComponents removeLastObject];
        [pathComponents addObject:@"MacOS"];
        [pathComponents addObject:mainAppName];
        NSString *mainAppPath = [NSString pathWithComponents:pathComponents];
        [[NSWorkspace sharedWorkspace] launchApplication:mainAppPath];
    } else {
        [NSApp terminate:nil];
    }
}

@end
