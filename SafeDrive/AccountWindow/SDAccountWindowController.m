
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountWindowController.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import <dispatch/dispatch.h>

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"

#import "SafeDrive-Swift.h"

#import <Crashlytics/Crashlytics.h>

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
    self.accountController = [AccountController sharedAccountController];

    self.passwordField.focusRingType = NSFocusRingTypeNone;

    [self.volumeNameField.cell setPlaceholderString:SDDefaultVolumeName];

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateMounted:) name:SDMountStateMountedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateUnmounted:) name:SDMountStateUnmountedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateDetails:) name:SDMountStateDetailsNotification object:nil];

    // register SDVolumeEventProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeShouldUnmount:) name:SDVolumeShouldUnmountNotification object:nil];
    
    
    if (self.accountController.hasCredentials) {
        // we need to sign in automatically if at all possible, even if we don't need to automount we need a session token and
        // account details in order to support sync
        [self signIn:nil];
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}





# pragma mark
# pragma mark Public API

-(IBAction)signIn:(id)sender {
    [self resetErrorDisplay];
    /*if (self.accountController.isSignedIn) {
        [self connectVolume];
        return;
    }*/
    NSError *e = [NSError errorWithDomain:SDErrorDomain code:SDErrorNone userInfo:@{NSLocalizedDescriptionKey:  NSLocalizedString(@"Signing in to SafeDrive", @"String informing the user that they are being signed in to SafeDrive")}];
    [self displayError:e forDuration:120];
    [self.spinner startAnimation:self];
    
    [self.accountController signInWithSuccess:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SDAccountSignInNotification object:nil];
        [self resetErrorDisplay];
        [self.spinner stopAnimation:self];
        
        // only mount SSHFS automatically if the user set it to automount or clicked the button, in which case sender will not be nil
        // but will be the NSButton in the account window labeled "next"
        if (self.sharedSystemAPI.mountAtLaunch || sender != nil) {
            NSURL *mountURL = [self.mountController getMountURLForVolumeName:self.sharedSystemAPI.currentVolumeName];
            BOOL mounted = [self.sharedSystemAPI checkForMountedVolume:mountURL];
            if (!mounted) {
                [self showWindow:nil];
                [self connectVolume];
            }
        }
    } failure:^(NSError * _Nonnull apiError) {
        SDErrorHandlerReport(apiError);
        [self displayError:apiError forDuration:10];
        [self.spinner stopAnimation:self];
    }];
    
}

# pragma mark
# pragma mark Internal API

-(void)connectVolume {
    [self resetErrorDisplay];
    self.mountController.mounting = YES;
    NSError *e = [NSError errorWithDomain:SDErrorDomain code:SDErrorNone userInfo:@{NSLocalizedDescriptionKey:  NSLocalizedString(@"Mounting SafeDrive", @"String informing the user their safedrive is being mounted")}];
    [self displayError:e forDuration:120];
    [self.spinner startAnimation:self];
    
    NSString *volumeName;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:SDCurrentVolumeNameKey]) {
        volumeName = [[NSUserDefaults standardUserDefaults] objectForKey:SDCurrentVolumeNameKey];
    }
    else {
        volumeName = SDDefaultVolumeName;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.user      = self.accountController.internalUserName;
    urlComponents.host      = self.accountController.remoteHost;
    urlComponents.path      = SDDefaultServerPath;
    urlComponents.port      = self.accountController.remotePort;
    NSURL *sshURL = urlComponents.URL;

    [self.mountController startMountTaskWithVolumeName:volumeName sshURL:sshURL success:^(NSURL *mountURL, NSError *mountError) {
        SDLog(@"SafeDrive startMountTaskWithVolumeName success in account window");
        /*
         now check for a successful mount. if after 30 seconds there is no volume
         mounted, it is a fair bet that an error occurred in the meantime
         */
        [self.sharedSystemAPI checkForMountedVolume:mountURL withTimeout:30 success:^{
            SDLog(@"SafeDrive checkForMountedVolume success in account window");
            [[NSNotificationCenter defaultCenter] postNotificationName:SDVolumeDidMountNotification object:nil];
            [self displayError:nil forDuration:10];
            [self.spinner stopAnimation:self];
            self.mountController.mounting = NO;
        } failure:^(NSError *error) {
            SDLog(@"SafeDrive checkForMountedVolume  failure in account window");
            [self displayError:error forDuration:10];
            [self.spinner stopAnimation:self];
            self.mountController.mounting = NO;
            
        }];
    } failure:^(NSURL *mountURL, NSError *mountError) {
        SDLog(@"SafeDrive startMountTaskWithVolumeName failure in account window");
        SDErrorHandlerReport(mountError);
        [self displayError:mountError forDuration:10];
        [self.spinner stopAnimation:self];
        self.mountController.mounting = NO;
        // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
        [self.mountController unmountVolumeWithName:volumeName success:^(NSURL *mountURL, NSError *mountError) {
            //
        } failure:^(NSURL *mountURL, NSError *mountError) {
            //
        }];
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
