

//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "AppDelegate.h"

#import "SDDropdownMenuController.h"
#import "SDAccountWindow.h"
#import "SDPreferencesWindow.h"


@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    self.dropdownMenuController = [[SDDropdownMenuController alloc] init];
    
    self.accountWindow = [[SDAccountWindow alloc] initWithWindowNibName:@"SDAccountWindow"];
    self.preferencesWindow = [[SDPreferencesWindow alloc] initWithWindowNibName:@"SDPreferencesWindow"];

    // register SDApplicationControlProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenAccountWindow:) name:SDApplicationShouldOpenAccountWindow object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationShouldOpenPreferencesWindow:) name:SDApplicationShouldOpenPreferencesWindow object:nil];

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeShouldUnmountNotification object:nil];
}

#pragma mark - SDApplicationControlProtocol methods

-(void)applicationShouldOpenAccountWindow:(NSNotification*)notification {
    [NSApp activateIgnoringOtherApps:YES];
    [self.accountWindow.window makeKeyAndOrderFront:self];
}

-(void)applicationShouldOpenPreferencesWindow:(NSNotification*)notification {
    [NSApp activateIgnoringOtherApps:YES];
    [self.preferencesWindow.window makeKeyAndOrderFront:self];
}



@end
