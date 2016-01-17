
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@class SDSyncItem;

@interface SDSyncTableCellView : NSTableCellView
@property IBOutlet NSButton *addButton;
@property IBOutlet NSButton *removeButton;
@property IBOutlet NSButton *syncNowButton;
@property IBOutlet NSProgressIndicator *syncStatus;

@property SDSyncItem *representedSyncItem;

@end
