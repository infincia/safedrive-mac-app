
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountWindow.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import <dispatch/dispatch.h>

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"

#import "NSURL+SSH.h"

#define SSHFS_TEST_MODE

#define CUSTOM_NSURL

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeShouldUnmount:) name:SDVolumeShouldUnmountNotification object:nil];


}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}





# pragma mark
# pragma mark Public API

-(IBAction)mount:(id)sender {
    [self connectVolume];
}

# pragma mark
# pragma mark Internal API

-(void)connectVolume {
    [self.spinner startAnimation:self];
    /* 
        This is somewhat fragile (the volume name must start with a slash) and 
        in general it must be replaced before shipping because it isn't available 
        in OS X 10.8 anyway
        
        A custom method for creating new NSURLs safely could be used, or just
        skip NSURL entirely and use NSDictionary with constants for keys
    */

    NSURL *sshURL;
    #ifdef CUSTOM_NSURL
    sshURL = [NSURL SSHURLForAccount:self.emailField.stringValue password:self.passwordField.stringValue host:SDTestCredentialsHost port:@(SDTestCredentialsPort) path:self.volumeNameField.stringValue];
    #else
    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.user      = self.emailField.stringValue;
    urlComponents.password  = self.passwordField.stringValue;
    urlComponents.host      = SDTestCredentialsHost;
    urlComponents.path      = [NSString stringWithFormat:@"/%@", self.volumeNameField.stringValue];
    urlComponents.port      = @(SDTestCredentialsPort);
    sshURL = urlComponents.URL;
    #endif

    //NSLog(@"Account window mounting URL: %@", sshURL);
    NSError *keychainError = [self.sharedSystemAPI insertCredentialsInKeychain:sshURL.user password:sshURL.password];
    if (keychainError) {
        [self displayError:keychainError forDuration:10];
        [self.spinner stopAnimation:self];
        return;
    }
    
    #ifdef SSHFS_TEST_MODE
    [self.mountController startMountTaskWithVolumeName:self.volumeNameField.stringValue sshURL:sshURL success:^(NSURL *mountURL, NSError *mountError) {
        NSLog(@"SSHFS subprocess start success in account window");

        /*
            now check for a successful mount. if after 30 seconds there is no volume
            mounted, it is a fair bet that an error occurred in the meantime
        */
        [self.sharedSystemAPI checkForMountedVolume:mountURL withTimeout:30 success:^{

            NSLog(@"Mount volume success in account window");
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeDidMountNotification object:nil];
            });
            [self.spinner stopAnimation:self];

        } failure:^(NSError *error) {

            NSLog(@"Mount volume failure in account window");
            [self displayError:error forDuration:10];
            [self.spinner stopAnimation:self];

        }];


    } failure:^(NSURL *mountURL, NSError *mountError) {

        NSLog(@"SSHFS subprocess start failure in account window");
        [self displayError:mountError forDuration:10];
        [self.spinner stopAnimation:self];

    }];

    #else

    [self.safeDriveAPI authenticateUser:self.emailField.stringValue password:self.passwordField.stringValue success:^(NSString *sessionToken) {

        NSLog(@"SafeDrive auth API success in account window");

        [self.safeDriveAPI volumeURLForUser:self.emailField.stringValue sessionToken:sessionToken volume:self.volumeNameField.stringValue success:^(NSURL *sshURL) {

            NSLog(@"SafeDrive volume URL API success in account window");


            [self.mountController startMountTaskWithVolumeName:self.volumeNameField.stringValue sshURL:sshURL success:^(NSURL *mountURL, NSError *mountError) {
                NSLog(@"SSHFS subprocess start success in account window");

                /*
                    now check for a successful mount. if after 30 seconds there is no volume
                    mounted, it is a fair bet that an error occurred in the meantime
                 */
                [self.sharedSystemAPI checkForMountedVolume:mountURL withTimeout:30 success:^{

                    NSLog(@"Mount volume success in account window");
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeDidMountNotification object:nil];
                    });
                    [self.spinner stopAnimation:self];

                } failure:^(NSError *error) {

                    NSLog(@"Mount volume failure in account window");
                    [self displayError:error forDuration:10];
                    [self.spinner stopAnimation:self];

                }];


            } failure:^(NSURL *mountURL, NSError *mountError) {

                NSLog(@"SSHFS subprocess start failure in account window");
                [self displayError:mountError forDuration:10];
                [self.spinner stopAnimation:self];

            }];

        } failure:^(NSError *volumeAPIError) {

            NSLog(@"Safedrive volume URL API failure in account window");
            [self displayError:volumeAPIError forDuration:10];
            [self.spinner stopAnimation:self];
            
        }];

    } failure:^(NSError *authError) {

        NSLog(@"SafeDrive auth API failure in account window");
        [self displayError:authError forDuration:10];
        [self.spinner stopAnimation:self];

    }];

    #endif


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
    self.errorField.stringValue = error.localizedDescription;
    NSColor *fadedRed = [NSColor colorWithCalibratedRed:1.0f green:0.25098f blue:0.25098f alpha:0.73f];
    NSColor *fadedBlue = [NSColor colorWithCalibratedRed:0.25098f green:0.25098f blue:1.0f alpha:0.73f];
    if (error.code > 0) {
        self.errorField.textColor = fadedRed;
    }
    else {
        self.errorField.textColor = fadedBlue;
    }
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
    //NSError *mountSuccess = [NSError errorWithDomain:SDErrorDomain code:SDErrorNone userInfo:@{NSLocalizedDescriptionKey: @"Volume mounted"}];
    //[self displayError:mountSuccess forDuration:10];
}

-(void)volumeDidUnmount:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenAccountWindow object:nil];
}

-(void)volumeSubprocessDidTerminate:(NSNotification *)notification {

}

-(void)volumeShouldUnmount:(NSNotification *)notification {

}

#pragma mark - SDMountStateProtocol methods

-(void)mountStateMounted:(NSNotification*)notification {

}

-(void)mountStateUnmounted:(NSNotification*)notification {

}


@end
