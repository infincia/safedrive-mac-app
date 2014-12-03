
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDDropdownMenuController : NSObject <SDMountStatusProtocol>

@property NSStatusItem *statusItem;

@property (strong) IBOutlet NSMenu *statusItemMenu;
@property IBOutlet NSMenuItem *connectMenuItem;
@property IBOutlet NSMenuItem *preferencesMenuItem;


-(IBAction)openAccountWindow:(id)sender;
-(IBAction)openPreferencesWindow:(id)sender;

@end
