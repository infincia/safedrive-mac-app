
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountWindow.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import <dispatch/dispatch.h>

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"

#define SSHFS_TEST_MODE

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



    // register SDMountStateProtocol notifications
    #warning Keep track of these SDMountStateProtocol requirements!!!
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateMounted:) name:SDMountStateMountedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateUnmounted:) name:SDMountStateUnmountedNotification object:nil];

    // register SDVolumeEventProtocol notifications
    #warning Keep track of these SDVolumeEventProtocol requirements!!!
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];


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




#pragma mark - Error display

-(void)resetErrorDisplay {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3f;
        self.errorField.animator.alphaValue = 0.0f;
    } completionHandler:^{
        self.errorField.stringValue = @"";
    }];
}

-(void)displayError:(NSError *)error forDuration:(NSTimeInterval)duration {
    self.errorField.stringValue = [error localizedDescription];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.5f;
        self.errorField.animator.alphaValue = 1.0f;
    } completionHandler:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3f;
                self.errorField.animator.alphaValue = 0.0f;
            } completionHandler:^{
                [self resetErrorDisplay];
            }];
        });
    }];

}

#pragma mark - SDVolumeEventProtocol methods

-(void)volumeDidMount:(NSNotification *)notification {
    [self close];
}

-(void)volumeDidUnmount:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenAccountWindow object:nil];
}

-(void)volumeSubprocessDidTerminate:(NSNotification *)notification {

}

#pragma mark - SDMountStateProtocol methods

-(void)mountStateMounted:(NSNotification*)notification {

}

-(void)mountStateUnmounted:(NSNotification*)notification {

}


@end
