
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

#import <Foundation/Foundation.h>

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

#pragma mark - Block definitions

typedef void(^SDSuccessBlock)();
typedef void(^SDFailureBlock)(NSError * _Nonnull apiError);

#pragma mark - Global functions

NSString * _Nonnull SDErrorToString(NSError * _Nonnull error);
