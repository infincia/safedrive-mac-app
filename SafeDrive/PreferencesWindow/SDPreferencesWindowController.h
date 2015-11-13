
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDPreferencesWindowController : NSWindowController <SDMountStateProtocol, SDAccountProtocol, SDServiceStatusProtocol>

@property NSString *volumeMountState;
@property NSNumber *volumeTotalSpace;
@property NSNumber *volumeFreeSpace;
@property NSNumber *volumeUsedSpace;

@property (nonatomic) BOOL autostart;

@property NSString *accountStatus;
@property NSString *expirationDate;
@property NSNumber *assignedStorage;
@property NSNumber *usedStorage;


@end
