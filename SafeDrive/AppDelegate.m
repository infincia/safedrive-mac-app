

//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "AppDelegate.h"

#import "SDDropdownMenuController.h"
#import "SDAccountWindowController.h"
#import "SDPreferencesWindowController.h"
#import <DCOAboutWindow/DCOAboutWindowController.h>
#import <PFMoveApplication.h>

#import "SDServiceXPCRouter.h"
#import "SDServiceManager.h"

#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

#import "SDSyncManagerWindowController.h"


@interface AppDelegate ()
@property DCOAboutWindowController *aboutWindow;
@property SDServiceXPCRouter *serviceRouter;
@property SDServiceManager *serviceManager;
@property SDSyncManagerWindowController *syncManager;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
    [Fabric with:@[[Crashlytics class]]];
    
    // initialize error handler, from this point on SDLog() and SDErrorHandlerReport() should be safe to use
    SDErrorHandlerInitialize();

#if RELEASE    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMM d yyyy"];
    NSLocale *localeUS = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:localeUS];

    NSDate *compileDate = [dateFormatter dateFromString:[NSString stringWithUTF8String:__DATE__]];
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSWeekCalendarUnit 
                                                                   fromDate:compileDate 
                                                                     toDate:[NSDate date] 
                                                                    options:0];
    // Expired after 4 weeks
    if ([components week] > 4) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"This beta of SafeDrive has expired.";
        [alert addButtonWithTitle:@"OK"];
        alert.informativeText = @"Please obtain a new version from safedrive.io";
        if ([alert runModal]) {
            [NSApp terminate:nil];
        }
    }   
    else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"This is a beta build of SafeDrive.";
        [alert addButtonWithTitle:@"OK"];
        NSDateComponents *weekComponent = [[NSDateComponents alloc] init];
        weekComponent.week = 4;
        
        NSCalendar *theCalendar = [NSCalendar currentCalendar];
        NSDate *expirationDate = [theCalendar dateByAddingComponents:weekComponent toDate:compileDate options:0];

        alert.informativeText = [NSString stringWithFormat:@"It will expire on %@", expirationDate];
        if ([alert runModal]) {

        }
    }
#endif

    PFMoveToApplicationsFolderIfNecessary();
    self.serviceManager = [SDServiceManager sharedServiceManager];
    [self.serviceManager deployService];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.serviceManager unloadService];
         [NSThread sleepForTimeInterval:1];
        [self.serviceManager loadService];
        [NSThread sleepForTimeInterval:2];
        self.serviceRouter = [[SDServiceXPCRouter alloc] init];
    });
    
    self.dropdownMenuController = [[SDDropdownMenuController alloc] init];
    
    self.accountWindow = [[SDAccountWindowController alloc] initWithWindowNibName:@"SDAccountWindow"];
    [self.accountWindow window];
    
    self.preferencesWindow = [[SDPreferencesWindowController alloc] initWithWindowNibName:@"SDPreferencesWindow"];
    [self.preferencesWindow window];

    self.aboutWindow = [[DCOAboutWindowController alloc] init];
    self.aboutWindow.useTextViewForAcknowledgments = YES;
    NSString *websiteURLPath = [NSString stringWithFormat:@"https://%@", SDWebDomain];
    self.aboutWindow.appWebsiteURL = [NSURL URLWithString:websiteURLPath];
    
    self.syncManager = [[SDSyncManagerWindowController alloc] initWithWindowNibName:@"SDSyncManagerWindow"];
    [self.syncManager window];

    // register SDApplicationControlProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenAccountWindow:) name:SDApplicationShouldOpenAccountWindow object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenPreferencesWindow:) name:SDApplicationShouldOpenPreferencesWindow object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenAboutWindow:) name:SDApplicationShouldOpenAboutWindow object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenAboutWindow object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenSyncWindow:) name:SDApplicationShouldOpenSyncWindow object:nil];
    NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.io.safedrive.db"];
    NSLog(@"Group: %@", groupURL);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeShouldUnmountNotification object:nil];
}

#pragma mark - SDApplicationControlProtocol methods

-(void)applicationShouldOpenAccountWindow:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp activateIgnoringOtherApps:YES];
        [self.accountWindow showWindow:nil];
    });
}

-(void)applicationShouldOpenPreferencesWindow:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp activateIgnoringOtherApps:YES];
        [self.preferencesWindow showWindow:nil];
    });

}

-(void)applicationShouldOpenAboutWindow:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp activateIgnoringOtherApps:YES];
        [self.aboutWindow showWindow:nil];
    });
}

-(void)applicationShouldOpenSyncWindow:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp activateIgnoringOtherApps:YES];
        [self.syncManager showWindow:nil];
    });
}

@end
