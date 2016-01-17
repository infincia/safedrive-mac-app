
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDSyncManagerWindowController : NSWindowController  <NSOpenSavePanelDelegate, SDAccountProtocol>
@property IBOutlet NSOutlineView *syncListView;
@property IBOutlet NSProgressIndicator *spinner;

-(IBAction)addSyncFolder:(id)sender;
-(IBAction)removeSyncFolder:(id)sender;

-(IBAction)startSyncItemNow:(id)sender;

@end
