
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDPreferencesWindow : NSWindowController <SDMountStateProtocol>

@property NSString *volumeMountState;
@property NSString *volumeTotalSpace;
@property NSString *volumeFreeSpace;

@property BOOL autostart;

@end
