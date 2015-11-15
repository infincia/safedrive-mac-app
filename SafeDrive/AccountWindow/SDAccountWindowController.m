
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountWindowController.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import <dispatch/dispatch.h>

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"
#import "SDAccountController.h"

#import "NSURL+SFTP.h"

#define SSHFS_TEST_MODE

#define CUSTOM_NSURL

@interface SDAccountWindowController ()
@property IBOutlet NSTextField *emailField;
@property IBOutlet NSTextField *passwordField;
@property IBOutlet NSTextField *volumeNameField;
@property IBOutlet NSTextField *errorField;
@property IBOutlet NSProgressIndicator *spinner;

@property SDAPI *safeDriveAPI;
@property SDMountController *mountController;
@property SDSystemAPI *sharedSystemAPI;

@property NSError *currentlyDisplayedError;

-(void)resetErrorDisplay;
-(void)displayError:(NSError *)error forDuration:(NSTimeInterval)duration;
-(void)connectVolume;

@end

@implementation SDAccountWindowController



# pragma mark
# pragma mark Framework callbacks

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setLevel:NSStatusWindowLevel];
    
    self.safeDriveAPI = [SDAPI sharedAPI];
    self.mountController = [SDMountController sharedAPI];
    self.sharedSystemAPI = [SDSystemAPI sharedAPI];
    self.accountController = [SDAccountController sharedAccountController];

    self.passwordField.focusRingType = NSFocusRingTypeNone;

    [self.volumeNameField.cell setPlaceholderString:SDDefaultVolumeName];

    // grab credentials from keychain if they exist
    NSDictionary *credentials = [self.sharedSystemAPI retrieveCredentialsFromKeychainForService:SDServiceName];
    if (credentials) {
        self.accountController.email = credentials[@"account"];
        self.accountController.password = credentials[@"password"];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateDetails:) name:SDMountStateDetailsNotification object:nil];

    // register SDVolumeEventProtocol notifications
    #warning Keep track of these SDVolumeEventProtocol requirements!!!
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeShouldUnmount:) name:SDVolumeShouldUnmountNotification object:nil];
    if (self.sharedSystemAPI.mountAtLaunch) {
        NSURL *mountURL = [self.mountController getMountURLForVolumeName:self.sharedSystemAPI.currentVolumeName];
        BOOL mounted = [self.sharedSystemAPI checkForMountedVolume:mountURL];
        if (!mounted) {
            [self showWindow:nil];
            [self connectVolume];
        }
    }
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
    [self resetErrorDisplay];
    self.mountController.mounting = YES;
    NSError *e = [NSError errorWithDomain:SDErrorDomain code:SDErrorNone userInfo:@{NSLocalizedDescriptionKey:  NSLocalizedString(@"Mounting SafeDrive", @"String informing the user their safedrive is being mounted")}];
    [self displayError:e forDuration:120];
    [self.spinner startAnimation:self];
    
    NSError *keychainError = [self.sharedSystemAPI insertCredentialsInKeychainForService:SDServiceName account:self.accountController.email password:self.accountController.password];
    if (keychainError) {
        [self displayError:keychainError forDuration:10];
        [self.spinner stopAnimation:self];
        self.mountController.mounting = NO;
        return;
    }
    [self.safeDriveAPI registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        //
        [self.safeDriveAPI accountStatusForUser:self.accountController.email success:^(NSDictionary *accountStatus) {            
            NSLog(@"SafeDrive accountStatusForUser success in account window");
            NSError *keychainError = [self.sharedSystemAPI insertCredentialsInKeychainForService:SDSSHServiceName account:accountStatus[@"userName"] password:self.accountController.password];
            if (keychainError) {
                [self displayError:keychainError forDuration:10];
                [self.spinner stopAnimation:self];
                self.mountController.mounting = NO;
                return;
            }
            /* 
             Using NSURL here provides some validation of the parameters since we are
             passing a standard RFC3986 URL string to SSHFS.
             
             A custom NSURL category is being used because NSURLComponents isn't
             available in OS X 10.8 (see below)
             
             */
            NSURL *sshURL;
#ifdef CUSTOM_NSURL
            sshURL = [NSURL SFTPURLForAccount:accountStatus[@"userName"] host:accountStatus[@"host"] port:accountStatus[@"port"] path:SDDefaultServerPath];
#else
            /*
             This is the modern way to create an NSURL, but it is only available on
             OS X 10.9+
             
             Things to keep in mind:
             
             * The NSComponents URL property will just return nil if the parameters 
             don't conform to RFC3986 (fragile if you don't check for that and handle it)
             
             * The user and password properties are only provided for compatibility
             purposes and are technically deprecated in RFC3986. We're not giving
             the password property directly to SSHFS (it's just used internally, 
             an askpass helper binary is used for giving the password to SSHFS). We
             ARE passing the user property though because that's how SSH logins work.
             
             * It isn't compatible with OS X 10.8, so we're not using it at the moment
             
             Whenever 10.8 support is dropped, THIS code should be used instead of
             the custom NSURL category above
             
             */
            NSURLComponents *urlComponents = [NSURLComponents new];
            urlComponents.user      = self.email;
            urlComponents.host      = SDTestCredentialsHost;
            urlComponents.path      = [NSString stringWithFormat:@"/%@", self.volumeNameField.stringValue];
            urlComponents.port      = @(SDTestCredentialsPort);
            sshURL = urlComponents.URL;
#endif
            [self.mountController startMountTaskWithVolumeName:@"SafeDrive" sshURL:sshURL success:^(NSURL *mountURL, NSError *mountError) {
                NSLog(@"SafeDrive startMountTaskWithVolumeName success in account window");
                /*
                 now check for a successful mount. if after 30 seconds there is no volume
                 mounted, it is a fair bet that an error occurred in the meantime
                 */
                [self.sharedSystemAPI checkForMountedVolume:mountURL withTimeout:30 success:^{
                    NSLog(@"SafeDrive checkForMountedVolume success in account window");
                    [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeDidMountNotification object:nil];
                    [self displayError:nil forDuration:10];
                    [self.spinner stopAnimation:self];
                    self.mountController.mounting = NO;
                } failure:^(NSError *error) {
                    NSLog(@"SafeDrive checkForMountedVolume  failure in account window");
                    [self displayError:error forDuration:10];
                    [self.spinner stopAnimation:self];
                    self.mountController.mounting = NO;
                    
                }];
            } failure:^(NSURL *mountURL, NSError *mountError) {
                NSLog(@"SafeDrive startMountTaskWithVolumeName failure in account window");
                [self displayError:mountError forDuration:10];
                [self.spinner stopAnimation:self];
                self.mountController.mounting = NO;
            }];
        } failure:^(NSError *apiError) {
            NSLog(@"SafeDrive accountStatusForUser failure in account window");
            [self displayError:apiError forDuration:10];
            [self.spinner stopAnimation:self];
            self.mountController.mounting = NO;
        }];
        
    } failure:^(NSError *apiError) {
        [self displayError:apiError forDuration:10];
        [self.spinner stopAnimation:self];
        self.mountController.mounting = NO;
    }];
}




#pragma mark - Error display

-(void)resetErrorDisplay {
    self.errorField.stringValue = @"";
}

-(void)displayError:(NSError *)error forDuration:(NSTimeInterval)duration {
    NSAssert([NSThread currentThread] == [NSThread mainThread], @"Error display called on background thread");
    self.currentlyDisplayedError = error;
    [NSApp activateIgnoringOtherApps:YES];
    self.errorField.stringValue = error ? error.localizedDescription : @"";
    NSColor *fadedRed = [NSColor colorWithCalibratedRed:1.0f green:0.25098f blue:0.25098f alpha:0.73f];
    NSColor *fadedBlue = [NSColor colorWithCalibratedRed:0.25098f green:0.25098f blue:1.0f alpha:0.73f];
    if (error.code > 0) {
        self.errorField.textColor = fadedRed;
    }
    else {
        self.errorField.textColor = fadedBlue;
    }
    __weak SDAccountWindowController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        /* 
            Only reset the error display if this block is the most recent to be 
            scheduled. If another error has been displayed since this block was
            scheduled, we don't want to reset the display early, and should simply
            return.
            
            On OS X 10.10 there is a dispatch_clear_block() method but for now,
            using the NSError object as a context works.
            
        */
        if (self.currentlyDisplayedError == error) {
            [weakSelf resetErrorDisplay];
        }
    });

}

#pragma mark - SDVolumeEventProtocol methods

-(void)volumeDidMount:(NSNotification *)notification {
    [self close];
    [[NSWorkspace sharedWorkspace] openURL:self.mountController.mountURL];
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

-(void)mountStateDetails:(NSNotification *)notification {

}

@end
