
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - SafeDrive API constants

FOUNDATION_EXPORT NSString *const SDAPIDomain;
FOUNDATION_EXPORT NSString *const SDWebDomain;

#pragma mark - Keychain constants


FOUNDATION_EXPORT NSString *const SDServiceName;


#pragma mark - Custom NSNotifications

FOUNDATION_EXPORT NSString *const SDMountStateMountedNotification;
FOUNDATION_EXPORT NSString *const SDMountStateUnmountedNotification;

FOUNDATION_EXPORT NSString *const SDVolumeDidMountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeDidUnmountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeShouldUnmountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeSubprocessDidTerminateNotification;

FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenPreferencesWindow;
FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenAccountWindow;

FOUNDATION_EXPORT NSString *const SDAPIDidEnterMaintenancePeriod;
FOUNDATION_EXPORT NSString *const SDAPIDidBecomeReachable;
FOUNDATION_EXPORT NSString *const SDAPIDidBecomeUnreachable;



#pragma mark - Errors

FOUNDATION_EXPORT NSString *const SDErrorDomain;

FOUNDATION_EXPORT NSUInteger const SDErrorNone;

#pragma mark - Mount related errors

FOUNDATION_EXPORT NSUInteger const SDMountErrorUnknown;
FOUNDATION_EXPORT NSUInteger const SDMountErrorAuthorization;
FOUNDATION_EXPORT NSUInteger const SDMountErrorTimeout;
FOUNDATION_EXPORT NSUInteger const SDMountErrorMountFailed;
FOUNDATION_EXPORT NSUInteger const SDMountErrorUnmountFailed;
FOUNDATION_EXPORT NSUInteger const SDMountErrorAlreadyMounted;
FOUNDATION_EXPORT NSUInteger const SDMountErrorAskpassMissing;
FOUNDATION_EXPORT NSUInteger const SDMountErrorHostFingerprintChanged;
FOUNDATION_EXPORT NSUInteger const SDMountErrorHostKeyVerificationFailed;


#pragma mark - System API related errors

FOUNDATION_EXPORT NSUInteger const SDSystemErrorUnknown;
FOUNDATION_EXPORT NSUInteger const SDSystemErrorAddLoginItemFailed;
FOUNDATION_EXPORT NSUInteger const SDSystemErrorRemoveLoginItemFailed;
FOUNDATION_EXPORT NSUInteger const SDSystemErrorAddKeychainItemFailed;
FOUNDATION_EXPORT NSUInteger const SDSystemErrorRemoveKeychainItemFailed;


#pragma mark - SafeDrive API related errors

FOUNDATION_EXPORT NSUInteger const SDAPIErrorAuthorization;
FOUNDATION_EXPORT NSUInteger const SDAPIErrorMaintenance;


#pragma mark - Mount state

typedef NS_ENUM(NSUInteger, SDMountState) {
    SDMountStateUnknown   = -1,
    SDMountStateUnmounted = 0,
    SDMountStateMounted   = 1
};

