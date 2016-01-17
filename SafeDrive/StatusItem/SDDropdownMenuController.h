
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDDropdownMenuController : NSObject <SDMountStateProtocol, SDVolumeEventProtocol, SDAccountProtocol>

@property NSStatusItem *statusItem;

@property (strong) IBOutlet NSMenu *statusItemMenu;
@property IBOutlet NSMenuItem *connectMenuItem;
@property IBOutlet NSMenuItem *preferencesMenuItem;
@property IBOutlet NSMenuItem *syncPreferencesMenuItem;


-(IBAction)toggleMount:(id)sender;
-(IBAction)openPreferencesWindow:(id)sender;
-(IBAction)openAboutWindow:(id)sender;
-(IBAction)openSyncWindow:(id)sender;

@end
