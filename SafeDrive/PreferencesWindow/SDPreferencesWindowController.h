
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

@import Cocoa;

@interface SDPreferencesWindowController : NSWindowController <SDMountStateProtocol, SDAccountProtocol, SDServiceStatusProtocol>

@property IBOutlet NSTabView *tabView;

@property IBOutlet NSButton *generalButton;
@property IBOutlet NSButton *accountButton;
@property IBOutlet NSButton *bandwidthButton;
@property IBOutlet NSButton *statusButton;


@property NSString *volumeMountState;
@property NSNumber *volumeTotalSpace;
@property NSNumber *volumeFreeSpace;
@property NSNumber *volumeUsedSpace;

@property (nonatomic) BOOL autostart;

@property NSString *accountStatus;
@property NSString *expirationDate;
@property NSNumber *assignedStorage;
@property NSNumber *usedStorage;

-(IBAction)selectTab:(id)sender;

@end
