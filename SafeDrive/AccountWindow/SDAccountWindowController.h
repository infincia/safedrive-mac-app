
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;

@class AccountController;

@interface SDAccountWindowController : NSWindowController <SDMountStateProtocol, SDVolumeEventProtocol>

-(IBAction)signIn:(id)sender;
@property AccountController *accountController;
@end
