
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDPreferencesWindowController : NSWindowController <SDMountStateProtocol>

@property NSString *volumeMountState;
@property NSString *volumeTotalSpace;
@property NSString *volumeFreeSpace;

@property BOOL autostart;

@end
