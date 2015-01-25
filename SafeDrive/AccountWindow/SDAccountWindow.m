
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountWindow.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import <dispatch/dispatch.h>

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"



@interface SDAccountWindow ()
@property IBOutlet NSTextField *emailField;
@property IBOutlet NSTextField *passwordField;
@property IBOutlet NSTextField *volumeNameField;
@property IBOutlet NSTextField *errorField;
@property IBOutlet NSProgressIndicator *spinner;

@property SDAPI *safeDriveAPI;
@property SDMountController *mountController;
@property SDSystemAPI *sharedSystemAPI;

-(void)resetErrorDisplay;
-(void)displayError:(NSError *)error forDuration:(NSTimeInterval)duration;
-(void)connectVolume;
-(void)disconnectVolume;

@end

@implementation SDAccountWindow



# pragma mark
# pragma mark Framework callbacks

- (void)windowDidLoad {
    [super windowDidLoad];

    self.safeDriveAPI = [SDAPI sharedAPI];
    self.mountController = [SDMountController sharedAPI];
    self.sharedSystemAPI = [SDSystemAPI sharedAPI];

    self.passwordField.focusRingType = NSFocusRingTypeNone;

    // grab credentials from keychain if they exist
    NSDictionary *credentials = [self.sharedSystemAPI retrieveCredentialsFromKeychain];
    if (credentials) {
        self.emailField.stringValue = credentials[@"account"];
        self.passwordField.stringValue = credentials[@"password"];
    }
    // reset error field to empty before display
    [self resetErrorDisplay];

    INAppStoreWindow *aWindow = (INAppStoreWindow*)[self window];
    aWindow.titleBarHeight = 24.0;
    aWindow.showsBaselineSeparator = NO;
    
    NSColor *topColor = [NSColor whiteColor];
    aWindow.titleBarStartColor     = topColor;
    aWindow.titleBarEndColor       = topColor;
    aWindow.baselineSeparatorColor = topColor;

    aWindow.inactiveTitleBarEndColor       = topColor;
    aWindow.inactiveTitleBarStartColor     = topColor;
    aWindow.inactiveBaselineSeparatorColor = topColor;




    // register SDVolumeEventProtocol notifications
    #warning Keep track of these SDVolumeEventProtocol requirements!!!
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountSubprocessDidTerminate:) name:SDMountSubprocessDidTerminateNotification object:nil];

}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}





# pragma mark
# pragma mark Public API

-(IBAction)toggleMount:(id)sender {
    switch (self.mountController.mountState) {
        case SDMountStateMounted: {
            [self disconnectVolume];
            break;
        }
        case SDMountStateUnmounted: {
            [self connectVolume];
        }
        case SDMountStateUnknown: {
            //
        }
        default: {
            break;
        }
    }
}
#pragma mark - SDMountStatusProtocol methods

-(void)volumeDidMount:(NSNotification*)notification {

}

-(void)volumeDidUnmount:(NSNotification*)notification {

}

-(void)mountSubprocessDidTerminate:(NSNotification *)notification {

}

@end
