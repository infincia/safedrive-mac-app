
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - General constants

FOUNDATION_EXPORT NSString *const SDDefaultVolumeName;
FOUNDATION_EXPORT NSString *const SDDefaultServerPath;
FOUNDATION_EXPORT NSString *const SDDefaultServerHostname;
FOUNDATION_EXPORT NSInteger const SDDefaultServerPort;

#pragma mark - NSUserDefaults keys

FOUNDATION_EXPORT NSString *const SDCurrentVolumeNameKey;
FOUNDATION_EXPORT NSString *const SDMountAtLaunchKey;


#pragma mark - SafeDrive API constants

FOUNDATION_EXPORT NSString *const SDAPIDomainTesting;
FOUNDATION_EXPORT NSString *const SDAPIDomain;
FOUNDATION_EXPORT NSString *const SDWebDomain;

#pragma mark - Common paths

FOUNDATION_EXPORT NSString *const SDDefaultSSHFSPath;
FOUNDATION_EXPORT NSString *const SDDefaultOSXFUSEFSPath;

#pragma mark - Keychain constants


FOUNDATION_EXPORT NSString *const SDServiceName;
FOUNDATION_EXPORT NSString *const SDSSHServiceName;
FOUNDATION_EXPORT NSString *const SDSessionServiceName;


#pragma mark - Custom NSNotifications

FOUNDATION_EXPORT NSString *const SDMountStateMountedNotification;
FOUNDATION_EXPORT NSString *const SDMountStateUnmountedNotification;
FOUNDATION_EXPORT NSString *const SDMountStateDetailsNotification;


FOUNDATION_EXPORT NSString *const SDVolumeDidMountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeDidUnmountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeShouldUnmountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeSubprocessDidTerminateNotification;

FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenPreferencesWindow;
FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenAccountWindow;
FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenAboutWindow;

FOUNDATION_EXPORT NSString *const SDAPIDidEnterMaintenancePeriod;
FOUNDATION_EXPORT NSString *const SDAPIDidBecomeReachable;
FOUNDATION_EXPORT NSString *const SDAPIDidBecomeUnreachable;


#pragma mark - Status Enums

typedef NS_ENUM(NSUInteger, SDAccountStatus) {
    SDAccountStatusUnknown          = -1,   // invalid state, display error or halt
    SDAccountStatusActive           =  1,	// the SFTP connection will be continued by the client
    SDAccountStatusTrial            =  2,	// the SFTP connection will be continued by the client
    SDAccountStatusTrialExpired     =  3,	// trial expired, trial expiration date will be returned from the server and formatted with the user's locale format
    SDAccountStatusExpired          =  4,	// account expired, expiration date will be returned from the server and formatted with the user's locale format
    SDAccountStatusLocked           =  5,	// account locked, date will be returned from the server and formatted with the user's locale format
    SDAccountStatusResetPassword    =  6,	// password being reset
    SDAccountStatusPendingCreation  =  7,	// account not ready yet
};


#pragma mark - Errors

FOUNDATION_EXPORT NSString *const SDErrorDomain;

FOUNDATION_EXPORT NSUInteger const SDErrorNone;

#pragma mark - Mount related errors

typedef NS_ENUM(NSInteger, SDMountError) {
    SDMountErrorUnknown                   =   -1,
    SDMountErrorAuthorization             = 1002,
    SDMountErrorTimeout                   = 1003,
    SDMountErrorMountFailed               = 1004,
    SDMountErrorUnmountFailed             = 1005,
    SDMountErrorAlreadyMounted            = 1006,
    SDMountErrorAskpassMissing            = 1007,
    SDMountErrorHostFingerprintChanged    = 1008,
    SDMountErrorHostKeyVerificationFailed = 1009,
    SDMountErrorOSXFUSEMissing            = 1010,
    SDMountErrorSSHFSMissing              = 1011
};

#pragma mark - System API related errors

typedef NS_ENUM(NSInteger, SDSystemError) {
    SDSystemErrorUnknown                  =   -1,
    SDSystemErrorAddLoginItemFailed       = 2002,
    SDSystemErrorRemoveLoginItemFailed    = 2003,
    SDSystemErrorAddKeychainItemFailed    = 2004,
    SDSystemErrorRemoveKeychainItemFailed = 2005
};

#pragma mark - SafeDrive API related errors

typedef NS_ENUM(NSInteger, SDAPIError) {
    SDAPIErrorUnknown       =   -1,
    SDAPIErrorAuthorization = 3001,
    SDAPIErrorMaintenance   = 3002
};

#pragma mark - Mount state

typedef NS_ENUM(NSInteger, SDMountState) {
    SDMountStateUnknown   = -1,
    SDMountStateUnmounted =  0,
    SDMountStateMounted   =  1
};

