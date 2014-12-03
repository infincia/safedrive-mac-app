
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@class SDAccountWindow;
@class SDPreferencesWindow;
@class SDDropdownMenuController;

@interface AppDelegate : NSObject <NSApplicationDelegate, SDApplicationControlProtocol>

@property SDDropdownMenuController *dropdownMenuController;
@property SDAccountWindow *accountWindow;
@property SDPreferencesWindow *preferencesWindow;

@end

