
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - Custom NSNotifications

FOUNDATION_EXPORT NSString *const SDVolumeDidMountNotification;
FOUNDATION_EXPORT NSString *const SDVolumeDidUnmountNotification;

FOUNDATION_EXPORT NSString *const SDMountSubprocessDidTerminateNotification;

FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenPreferencesWindow;
FOUNDATION_EXPORT NSString *const SDApplicationShouldOpenAccountWindow;

#pragma mark - Errors

FOUNDATION_EXPORT NSString *const SDErrorDomain;

#pragma mark - Mount related errors

FOUNDATION_EXPORT NSUInteger const SDMountErrorAuthorization;
FOUNDATION_EXPORT NSUInteger const SDMountErrorTimeout;
FOUNDATION_EXPORT NSUInteger const SDMountErrorMountFailed;
FOUNDATION_EXPORT NSUInteger const SDMountErrorUnmountFailed;
FOUNDATION_EXPORT NSUInteger const SDMountErrorAlreadyMounted;
FOUNDATION_EXPORT NSUInteger const SDMountErrorAskpassMissing;
FOUNDATION_EXPORT NSUInteger const SDMountErrorUnknown;

#pragma mark - System API related errors

FOUNDATION_EXPORT NSUInteger const SDSystemErrorUnknown;
FOUNDATION_EXPORT NSUInteger const SDSystemErrorAddLoginItemFailed;
FOUNDATION_EXPORT NSUInteger const SDSystemErrorRemoveLoginItemFailed;