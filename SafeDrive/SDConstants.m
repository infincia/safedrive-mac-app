
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDConstants.h"

#pragma mark - SafeDrive API constants

NSString *const SDAPIDomain = @"safedrive.io";


#pragma mark - Keychain constants


NSString *const SDServiceName = @"safedrive.io";


#pragma mark - Custom NSNotifications

NSString *const SDVolumeDidMountNotification              = @"SDVolumeDidMountNotification";
NSString *const SDVolumeDidUnmountNotification            = @"SDVolumeDidUnmountNotification";

NSString *const SDMountSubprocessDidTerminateNotification = @"SDMountSubprocessDidTerminateNotification";

NSString *const SDApplicationShouldOpenPreferencesWindow  = @"SDApplicationShouldOpenPreferencesWindow";
NSString *const SDApplicationShouldOpenAccountWindow      = @"SDApplicationShouldOpenAccountWindow";

NSString *const SDAPIDidEnterMaintenancePeriod            = @"SDAPIDidEnterMaintenancePeriod";
NSString *const SDAPIDidBecomeReachable                   = @"SDAPIDidBecomeReachable";
NSString *const SDAPIDidBecomeUnreachable                 = @"SDAPIDidBecomeUnreachable";



#pragma mark - Errors

NSString *const SDErrorDomain = @"io.safedrive";

#pragma mark - Mount related errors

NSUInteger const SDMountErrorUnknown                   = 1001;
NSUInteger const SDMountErrorAuthorization             = 1002;
NSUInteger const SDMountErrorTimeout                   = 1003;
NSUInteger const SDMountErrorMountFailed               = 1004;
NSUInteger const SDMountErrorUnmountFailed             = 1005;
NSUInteger const SDMountErrorAlreadyMounted            = 1006;
NSUInteger const SDMountErrorAskpassMissing            = 1007;
NSUInteger const SDMountErrorHostFingerprintChanged    = 1008;
NSUInteger const SDMountErrorHostKeyVerificationFailed = 1009;


#pragma mark - System API related errors

NSUInteger const SDSystemErrorUnknown               = 2001;
NSUInteger const SDSystemErrorAddLoginItemFailed    = 2002;
NSUInteger const SDSystemErrorRemoveLoginItemFailed = 2003;

#pragma mark - SafeDrive API related errors

NSUInteger const SDAPIErrorAuthorization = 3001;
NSUInteger const SDAPIErrorMaintenance   = 3002;
