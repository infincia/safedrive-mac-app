

//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "AppDelegate.h"

#import "SDAccountWindow.h"
#import "SDPreferencesWindow.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.menu = self.statusItemMenu;

    // this sets the tooltip of the menu bar item using a localized string from SafeDrive.strings
    self.statusItem.toolTip = NSLocalizedString(@"SafeDriveAppName", @"Safe Drive Name");

#warning This needs to be replaced!
    // Use a system image of a lock for the menu bar item for now, will need to replace this
    NSImage *barImage = [NSImage imageNamed:NSImageNameLockLockedTemplate];

    // needed for OS X 10.10 dark mode
    [barImage setTemplate:YES];

    [self.statusItem setImage:barImage];



    self.accountWindow = [[SDAccountWindow alloc] initWithWindowNibName:@"SDAccountWindow"];
    self.preferencesWindow = [[SDPreferencesWindow alloc] initWithWindowNibName:@"SDPreferencesWindow"];


}


-(IBAction)showAccountWindow:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [self.accountWindow.window makeKeyAndOrderFront:self];
}


-(IBAction)showPreferencesWindow:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [self.preferencesWindow.window makeKeyAndOrderFront:self];
}




- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
