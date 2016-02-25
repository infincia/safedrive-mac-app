
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "AppDelegate.h"

#import "SDServiceListenerDelegate.h"
#import "SDServiceXPCProtocol.h"

#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

static NSString *CFBundleVersion;

@interface AppDelegate ()
@property SDServiceListenerDelegate *listenerDelegate;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
    [Fabric with:@[[Crashlytics class]]];
    
    NSDictionary *bundleInfo = [[NSBundle mainBundle]  infoDictionary];
    CFBundleVersion = bundleInfo[@"CFBundleVersion"];    
    NSLog(@"SafeDriveService build %@, protocol version %ld starting", CFBundleVersion, kSDServiceXPCProtocolVersion);
    
    self.listenerDelegate = [[SDServiceListenerDelegate alloc] init];
    
    
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:[[NSBundle mainBundle] bundleIdentifier]];
    listener.delegate = self.listenerDelegate;
    
    [listener resume];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    NSLog(@"SafeDriveService build %@, protocol version %ld exiting", CFBundleVersion, kSDServiceXPCProtocolVersion);
}

@end
