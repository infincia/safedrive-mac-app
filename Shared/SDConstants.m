
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
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
NSString *const SDApplicationShouldFinishLaunch          = @"SDApplicationShouldFinishLaunch";

NSString *const SDAPIDidEnterMaintenancePeriod            = @"SDAPIDidEnterMaintenancePeriod";
NSString *const SDAPIDidBecomeReachable                   = @"SDAPIDidBecomeReachable";
NSString *const SDAPIDidBecomeUnreachable                 = @"SDAPIDidBecomeUnreachable";

NSString *const SDAccountSignInNotification               = @"SDAccountSignInNotification";
NSString *const SDAccountSignOutNotification              = @"SDAccountSignOutNotification";
NSString *const SDAccountStatusNotification               = @"SDAccountStatusNotification";
NSString *const SDAccountDetailsNotification              = @"SDAccountDetailsNotification";

NSString *const SDServiceStatusNotification               = @"SDServiceStatusNotification";

#pragma mark - Errors

NSString *const SDErrorDomain = @"io.safedrive";
NSString *const SDErrorUIDomain = @"io.safedrive.ui";
NSString *const SDErrorSyncDomain = @"io.safedrive.sync";
NSString *const SDErrorSSHFSDomain = @"io.safedrive.sshfs";
NSString *const SDErrorAccountDomain = @"io.safedrive.account";
NSString *const SDErrorAPIDomain = @"io.safedrive.api";
NSString *const SDMountErrorDomain = @"io.safedrive.mount";



NSUInteger const SDErrorNone = 0;

// This will be unnecessary once SDError enums are Swift w/String values, but it's safe as long as error.code is cast
// as a specific kind of SDError enum, the compiler will warn if any cases are missing
NSString * _Nullable SDErrorToString(NSError *error) {
     switch ((enum SDSSHError)error.code) {
         case SDSSHErrorUnknown:
             return @"SDSSHErrorUnknown";
         case SDSSHErrorAuthorization:
             return @"SDSSHErrorAuthorization";
         case SDSSHErrorTimeout:
             return @"SDSSHErrorTimeout";
         case SDSSHErrorHostFingerprintChanged:
             return @"SDSSHErrorHostFingerprintChanged";
         case SDSSHErrorHostKeyVerificationFailed:
             return @"SDSSHErrorHostKeyVerificationFailed";
         case SDSSHErrorDirectoryMissing:
             return @"SDSSHErrorDirectoryMissing";
         case SDSSHErrorRemoteEnvironment:
             return @"SDSSHErrorRemoteEnvironment";
     }
     
     
     switch ((enum SDSystemError)error.code) {
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
         case SDSystemErrorOSXFUSEMissing:
             return @"SDSystemErrorOSXFUSEMissing";
         case SDSystemErrorSSHFSMissing:
             return @"SDSystemErrorSSHFSMissing";
         case SDSystemErrorAskpassMissing:
             return @"SDSystemErrorAskpassMissing";
     }
     
     
     switch ((enum SDAPIError)error.code) {
         case SDAPIErrorUnknown:
             return @"SDAPIErrorUnknown";
         case SDAPIErrorAuthorization:
             return @"SDAPIErrorAuthorization";
         case SDAPIErrorMaintenance:
             return @"SDAPIErrorMaintenance";
     }
     
     
     switch ((enum SDSyncError)error.code) {
         case SDSyncErrorUnknown:
             return @"SDSyncErrorUnknown";
         case SDSyncErrorTimeout:
             return @"SDSyncErrorTimeout";
         case SDSyncErrorDirectoryMissing:
             return @"SDSyncErrorDirectoryMissing";
         case SDSyncErrorSyncFailed:
             return @"SDSyncErrorSyncFailed";
         case SDSyncErrorAlreadyRunning:
             return @"SDSyncErrorAlreadyRunning";
         case SDSyncErrorRemoteEnvironment:
             return @"SDSyncErrorRemoteEnvironment";
         case SDSyncErrorFolderConflict:
             return @"SDSyncErrorFolderConflict";
     }
     
     
     switch ((enum SDMountError)error.code) {
         case SDMountErrorUnknown:
             return @"SDMountErrorUnknown";
         case SDMountErrorMountFailed:
             return @"SDMountErrorMountFailed";
         case SDMountErrorAlreadyMounted:
             return @"SDMountErrorAlreadyMounted";
         case SDMountErrorUnmountFailed:
             return @"SDMountErrorUnmountFailed";
     }
     return nil;
}