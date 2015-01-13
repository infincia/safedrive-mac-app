
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDDropdownMenuController.h"

@interface SDDropdownMenuController ()
-(void)setMenuBarImage:(NSImage *)image;
@end

@implementation SDDropdownMenuController

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"SDDropdownMenu" owner:self topLevelObjects:nil];

        // register SDMountStatusProtocol notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountSubprocessDidTerminate:) name:SDMountSubprocessDidTerminateNotification object:nil];

    }
    return self;
}

-(void)awakeFromNib {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];

    // menu loaded from SDDropdownMenu.xib
    self.statusItem.menu = self.statusItemMenu;

    // this sets the tooltip of the menu bar item using a localized string from SafeDrive.strings
    self.statusItem.toolTip = NSLocalizedString(@"SafeDriveAppName", @"Safe Drive Application Name");

    #warning This icon needs to be replaced!
    [self setMenuBarImage:[NSImage imageNamed:NSImageNameLockLockedTemplate]];

}




#pragma mark - Internal methods

-(void)setMenuBarImage:(NSImage *)image {
    // needed for OS X 10.10's dark mode
    [image setTemplate:YES];

    [self.statusItem setImage:image];
}




#pragma mark - IBActions

-(IBAction)openAccountWindow:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenAccountWindow object:nil];
}


-(IBAction)openPreferencesWindow:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenPreferencesWindow object:nil];
}





#pragma mark - SDMountStatusProtocol methods

-(void)volumeDidMount:(NSNotification*)notification {
    self.connectMenuItem.title = NSLocalizedString(@"Disconnect", @"Menu title for disconnecting the volume");

    #warning These icons need to be replaced!
    [self setMenuBarImage:[NSImage imageNamed:NSImageNameLockUnlockedTemplate]];
}

-(void)volumeDidUnmount:(NSNotification*)notification {
    self.connectMenuItem.title = NSLocalizedString(@"Connect", @"Menu title for connecting the volume");

    #warning These icons need to be replaced!
    [self setMenuBarImage:[NSImage imageNamed:NSImageNameLockLockedTemplate]];
}

-(void)mountSubprocessDidTerminate:(NSNotification *)notification {

}


@end
