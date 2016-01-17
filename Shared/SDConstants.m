
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDConstants.h"

#pragma mark - General constants

NSString *const SDDefaultVolumeName = @"SafeDrive";
NSString *const SDDefaultServerPath = @"/storage";
NSInteger const SDDefaultServerPort = 22;

#pragma mark - NSUserDefaults keys

NSString *const SDCurrentVolumeNameKey = @"currentVolumeName";
NSString *const SDMountAtLaunchKey = @"mountAtLaunch";

#pragma mark - SafeDrive API constants

NSString *const SDAPIDomainTesting = @"testing.safedrive.io";
NSString *const SDAPIDomain = @"safedrive.io";
NSString *const SDWebDomain = @"safedrive.io";

#pragma mark - Common paths

NSString *const SDDefaultSSHFSPath = @"/usr/local/bin/sshfs";
NSString *const SDDefaultOSXFUSEFSPath = @"/Library/Filesystems/osxfusefs.fs";

NSString *const SDDefaultRsyncPath = @"/usr/bin/rsync";

#pragma mark - Keychain constants


NSString *const SDServiceName = @"safedrive.io";
NSString *const SDServiceNameTesting = @"testing.safedrive.io";
NSString *const SDSSHServiceName = @"ssh.safedrive.io";
NSString *const SDSessionServiceName = @"session.safedrive.io";

#pragma mark - Custom NSNotifications

NSString *const SDMountStateMountedNotification          = @"SDMountStateMountedNotification";
NSString *const SDMountStateUnmountedNotification        = @"SDMountStateUnmountedNotification";
NSString *const SDMountStateDetailsNotification          = @"SDMountDetailsNotification";

NSString *const SDVolumeDidMountNotification              = @"SDVolumeDidMountNotification";
NSString *const SDVolumeDidUnmountNotification            = @"SDVolumeDidUnmountNotification";
NSString *const SDVolumeShouldUnmountNotification         = @"SDVolumeShouldUnmountNotification";
NSString *const SDVolumeSubprocessDidTerminateNotification = @"SDVolumeSubprocessDidTerminateNotification";

NSString *const SDApplicationShouldOpenPreferencesWindow  = @"SDApplicationShouldOpenPreferencesWindow";
NSString *const SDApplicationShouldOpenAccountWindow      = @"SDApplicationShouldOpenAccountWindow";
NSString *const SDApplicationShouldOpenAboutWindow        = @"SDApplicationShouldOpenAboutWindow";
NSString *const SDApplicationShouldOpenSyncWindow        = @"SDApplicationShouldOpenSyncWindow";


NSString *const SDAPIDidEnterMaintenancePeriod            = @"SDAPIDidEnterMaintenancePeriod";
NSString *const SDAPIDidBecomeReachable                   = @"SDAPIDidBecomeReachable";
NSString *const SDAPIDidBecomeUnreachable                 = @"SDAPIDidBecomeUnreachable";

NSString *const SDAccountSignInNotification               = @"SDAccountSignInNotification";
NSString *const SDAccountStatusNotification               = @"SDAccountStatusNotification";
NSString *const SDAccountDetailsNotification              = @"SDAccountDetailsNotification";

NSString *const SDServiceStatusNotification               = @"SDServiceStatusNotification";

#pragma mark - Errors

NSString *const SDErrorDomain = @"io.safedrive";
NSString *const SDErrorSyncDomain = @"io.safedrive.sync";
NSString *const SDErrorSSHFSDomain = @"io.safedrive.sshfs";
NSString *const SDErrorAccountDomain = @"io.safedrive.account";
NSString *const SDErrorAPIDomain = @"io.safedrive.api";

NSUInteger const SDErrorNone = 0;

 NSString * _Nullable SDErrorToString(NSError *error) {
    switch (error.code) {
        case SDSSHErrorUnknown:
            return @"SDSSHErrorUnknown";
        case SDSSHErrorAuthorization:
            return @"SDSSHErrorAuthorization";
        case SDSSHErrorTimeout:
            return @"SDSSHErrorTimeout";
        case SDSSHErrorMountFailed:
            return @"SDSSHErrorMountFailed";
        case SDSSHErrorUnmountFailed:
            return @"SDSSHErrorUnmountFailed";
        case SDSSHErrorAlreadyMounted:
            return @"SDSSHErrorAlreadyMounted";
        case SDSSHErrorAskpassMissing:
            return @"SDSSHErrorAskpassMissing";
        case SDSSHErrorHostFingerprintChanged:
            return @"SDSSHErrorHostFingerprintChanged";
        case SDSSHErrorHostKeyVerificationFailed:
            return @"SDSSHErrorHostKeyVerificationFailed";
        case SDSSHErrorOSXFUSEMissing:
            return @"SDSSHErrorOSXFUSEMissing";
        case SDSSHErrorSSHFSMissing:
            return @"SDSSHErrorSSHFSMissing";
        case SDSSHErrorDirectoryMissing:
            return @"SDSSHErrorDirectoryMissing";
        case SDSSHErrorSyncFailed:
            return @"SDSSHErrorSyncFailed";
        case SDSSHErrorSyncAlreadyRunning:
            return @"SDSSHErrorSyncAlreadyRunning";
            
        case SDSystemErrorUnknown:
            return @"SDSystemErrorUnknown";
        case SDSystemErrorAddLoginItemFailed:
            return @"SDSystemErrorAddLoginItemFailed";
        case SDSystemErrorRemoveLoginItemFailed:
            return @"SDSystemErrorRemoveLoginItemFailed";
        case SDSystemErrorAddKeychainItemFailed:
            return @"SDSystemErrorAddKeychainItemFailed";
        case SDSystemErrorRemoveKeychainItemFailed:
            return @"SDSystemErrorRemoveKeychainItemFailed";
        case SDSystemErrorFilePermissionDenied:
            return @"SDSystemErrorFilePermissionDenied";

        case SDAPIErrorUnknown:
            return @"SDAPIErrorUnknown";
        case SDAPIErrorAuthorization:
            return @"SDAPIErrorAuthorization";
        case SDAPIErrorMaintenance:
            return @"SDAPIErrorMaintenance";
            
        default:
            return [NSString stringWithFormat:@"Unknown: %ld", error.code];
    }
    return nil;
}