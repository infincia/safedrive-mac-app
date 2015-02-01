
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@class SDAccountWindowController;
@class SDPreferencesWindow;
@class SDDropdownMenuController;

@interface AppDelegate : NSObject <NSApplicationDelegate, SDApplicationControlProtocol>

@property SDDropdownMenuController *dropdownMenuController;
@property SDAccountWindowController *accountWindow;
@property SDPreferencesWindow *preferencesWindow;

@end

