
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;
@class SDAccountController;

@interface SDAccountWindowController : NSWindowController <SDMountStateProtocol, SDVolumeEventProtocol>

-(IBAction)signIn:(id)sender;
@property SDAccountController *accountController;
@end
