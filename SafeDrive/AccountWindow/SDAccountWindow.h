
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@interface SDAccountWindow : NSWindowController <SDMountStateProtocol, SDVolumeEventProtocol>

-(IBAction)toggleMount:(id)sender;

@end
