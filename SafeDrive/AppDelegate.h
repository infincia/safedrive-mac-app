
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@class SDAccountWindow;
@class SDPreferencesWindow;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property NSStatusItem *statusItem;
@property IBOutlet NSMenu *statusItemMenu;

@property SDAccountWindow *accountWindow;
@property SDPreferencesWindow *preferencesWindow;



@end

