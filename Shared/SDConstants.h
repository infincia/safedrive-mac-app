
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - General constants

FOUNDATION_EXPORT NSString *const SDDefaultVolumeName;
FOUNDATION_EXPORT NSString *const SDDefaultServerPath;
FOUNDATION_EXPORT NSInteger const SDDefaultServerPort;

FOUNDATION_EXPORT NSString *const SDBuildVersionLastKey;
FOUNDATION_EXPORT NSString *const SDRealmSchemaVersionLastKey;

#pragma mark - Realm constants

FOUNDATION_EXPORT NSUInteger const SDCurrentRealmSchema;

#pragma mark - NSUserDefaults keys

FOUNDATION_EXPORT NSString *const SDCurrentVolumeNameKey;
FOUNDATION_EXPORT NSString *const SDMountAtLaunchKey;
FOUNDATION_EXPORT NSString *const SDWelcomeShownKey;

NS_ASSUME_NONNULL_END

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

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSInteger const SDErrorNone;

NS_ASSUME_NONNULL_END

#pragma mark - SFTP operations

typedef NS_ENUM(NSInteger, SDSFTPOperation) {
    SDSFTPOperationCreateFolder,
    SDSFTPOperationDeleteFolder,
    SDSFTPOperationMoveFolder
};

#pragma mark - SSH related errors

typedef NS_ENUM(NSInteger, SDSSHError) {
    SDSSHErrorUnknown                   = -1000,
    SDSSHErrorAuthorization             = 1001,
    SDSSHErrorTimeout                   = 1002,
    SDSSHErrorHostFingerprintChanged    = 1003,
    SDSSHErrorHostKeyVerificationFailed = 1004,
    SDSSHErrorDirectoryMissing          = 1005,
    SDSSHErrorRemoteEnvironment         = 1016,
    SDSSHErrorSFTPOperationFailure      = 1017,
    SDSSHErrorSFTPOperationFolderConflict = 1018

};

#pragma mark - System API related errors

typedef NS_ENUM(NSInteger, SDSystemError) {
    SDSystemErrorUnknown                  = -2000,
    SDSystemErrorAddLoginItemFailed       = 2001,
    SDSystemErrorRemoveLoginItemFailed    = 2002,
    SDSystemErrorAddKeychainItemFailed    = 2003,
    SDSystemErrorRemoveKeychainItemFailed = 2004,
    SDSystemErrorFilePermissionDenied     = 2005,
    SDSystemErrorOSXFUSEMissing           = 2006,
    SDSystemErrorSSHFSMissing             = 2007,
    SDSystemErrorAskpassMissing           = 2008,
    SDSystemErrorRsyncMissing             = 2009
};

#pragma mark - SafeDrive API related errors

typedef NS_ENUM(NSInteger, SDAPIError) {
    // Client errors
    SDAPIErrorUnknown                       = -1,
    SDAPIErrorBadRequest                    = 400,
    SDAPIErrorUnauthorized                  = 401,
    SDAPIErrorPaymentRequired               = 402,
    SDAPIErrorForbidden                     = 403,
    SDAPIErrorNotFound                      = 404,
    SDAPIErrorMethodNotAllowed              = 406,
    SDAPIErrorProxyAuthenticationRequired   = 407,
    SDAPIErrorRequestTimeout                = 408,
    SDAPIErrorConflict                      = 409,
    SDAPIErrorGone                          = 410,
    SDAPIErrorLengthRequired                = 411,
    SDAPIErrorPreconditionFailed            = 412,
    SDAPIErrorPayloadTooLarge               = 413,
    SDAPIErrorURITooLong                    = 414,
    SDAPIErrorUnsupportedMediaType          = 415,
    SDAPIErrorRangeNotSatisfiable           = 416,
    SDAPIErrorExpectationFailed             = 417,
    SDAPIErrorImATeapot                     = 418, // yes, really...
    SDAPIErrorMisdirectedRequest            = 421,
    SDAPIErrorUnprocessableEntity           = 422,
    SDAPIErrorLocked                        = 423,
    SDAPIErrorFailedDependency              = 424,
    SDAPIErrorUpgradeRequired               = 426,
    SDAPIErrorPreconditionRequired          = 428,
    SDAPIErrorTooManyRequests               = 429,
    SDAPIErrorRequestHeaderFieldsTooLarge   = 431,
    SDAPIErrorUnavailableForLegalReasons    = 451,
    
    // Server errors
    SDAPIErrorInternalServerError           = 500,
    SDAPIErrorNotImplemented                = 501,
    SDAPIErrorBadGateway                    = 502,
    SDAPIErrorServiceUnavailable            = 503,
    SDAPIErrorGatewayTimeout                = 504,
    SDAPIErrorHTTPVersionNotSupported       = 505,
    SDAPIErrorVariantAlsoNegotiates         = 506,
    SDAPIErrorInsufficientStorage           = 507,
    SDAPIErrorLoopDetected                  = 508,
    SDAPIErrorNotExtended                   = 510,
    SDAPIErrorNetworkAuthenticationRequired = 511
};

#pragma mark - Sync errors

typedef NS_ENUM(NSInteger, SDSyncError) {
    SDSyncErrorUnknown                   = -4000,
    SDSyncErrorTimeout                   = 4001,
    SDSyncErrorDirectoryMissing          = 4002,
    SDSyncErrorSyncFailed                = 4003,
    SDSyncErrorAlreadyRunning            = 4004,
    SDSyncErrorRemoteEnvironment         = 4005,
    SDSyncErrorFolderConflict            = 4006,
    SDSyncErrorCancelled                 = 4007

};


typedef NS_ENUM(NSInteger, SDMountError) {
    SDMountErrorUnknown                  = -5000,
    SDMountErrorMountFailed              = 5001,
    SDMountErrorUnmountFailed            = 5002,
    SDMountErrorAlreadyMounted           = 5003
};

#pragma mark - Database errors

typedef NS_ENUM(NSInteger, SDDatabaseError) {
    SDDatabaseErrorUnknown                  = -6000,
    SDDatabaseErrorOpenFailed               = 6001,
    SDDatabaseErrorMigrationFailed          = 6002,
    SDDatabaseErrorWriteFailed              = 6003
};

#pragma mark - Installation related errors

typedef NS_ENUM(NSInteger, SDInstallationError) {
    SDInstallationErrorUnknown                   = -7000,
    SDInstallationErrorServiceDeployment         = 7001,
    SDInstallationErrorCLIDeployment             = 7002,
    SDInstallationErrorFuseDeployment            = 7003,
    SDInstallationErrorCLIMissing                = 7004,
};

#pragma mark - Sync state

typedef NS_ENUM(NSInteger, SDSyncState) {
    SDSyncStateUnknown = -1,
    SDSyncStateRunning =  0,
    SDSyncStateIdle    =  1
};

#pragma mark - Block definitions

typedef void(^SDSuccessBlock)();
typedef void(^SDFailureBlock)(NSError * _Nonnull apiError);

#pragma mark - Global functions

NSString * _Nonnull SDErrorToString(NSError * _Nonnull error);
