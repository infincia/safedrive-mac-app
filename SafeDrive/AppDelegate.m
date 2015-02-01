

//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "AppDelegate.h"

#import "SDDropdownMenuController.h"
#import "SDAccountWindowController.h"
#import "SDPreferencesWindowController.h"
#import <DCOAboutWindow/DCOAboutWindowController.h>

@interface AppDelegate ()
@property DCOAboutWindowController *aboutWindow;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    self.dropdownMenuController = [[SDDropdownMenuController alloc] init];
    
    self.accountWindow = [[SDAccountWindowController alloc] initWithWindowNibName:@"SDAccountWindow"];
    self.preferencesWindow = [[SDPreferencesWindowController alloc] initWithWindowNibName:@"SDPreferencesWindow"];

    self.aboutWindow = [[DCOAboutWindowController alloc] init];
    self.aboutWindow.useTextViewForAcknowledgments = YES;
    NSString *websiteURLPath = [NSString stringWithFormat:@"https://%@", SDWebDomain];
    self.aboutWindow.appWebsiteURL = [NSURL URLWithString:websiteURLPath];

    // register SDApplicationControlProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenAccountWindow:) name:SDApplicationShouldOpenAccountWindow object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenPreferencesWindow:) name:SDApplicationShouldOpenPreferencesWindow object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenAboutWindow:) name:SDApplicationShouldOpenAboutWindow object:nil];

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeShouldUnmountNotification object:nil];
}

#pragma mark - SDApplicationControlProtocol methods

-(void)applicationShouldOpenAccountWindow:(NSNotification*)notification {
    [NSApp activateIgnoringOtherApps:YES];
    [self.accountWindow showWindow:nil];
}

-(void)applicationShouldOpenPreferencesWindow:(NSNotification*)notification {
    [NSApp activateIgnoringOtherApps:YES];
    [self.preferencesWindow showWindow:nil];
}

-(void)applicationShouldOpenAboutWindow:(NSNotification*)notification {
    [NSApp activateIgnoringOtherApps:YES];
    [self.aboutWindow showWindow:nil];
}

@end
