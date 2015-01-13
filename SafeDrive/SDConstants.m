
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDConstants.h"

#pragma mark - SafeDrive API constants

NSString *const SDAPIDomain = @"safedrive.io";


NSString *const SDVolumeDidMountNotification              = @"SDVolumeDidMountNotification";
NSString *const SDVolumeDidUnmountNotification            = @"SDVolumeDidUnmountNotification";

NSString *const SDMountSubprocessDidTerminateNotification = @"SDMountSubprocessDidTerminateNotification";

NSString *const SDApplicationShouldOpenPreferencesWindow  = @"SDApplicationShouldOpenPreferencesWindow";
NSString *const SDApplicationShouldOpenAccountWindow      = @"SDApplicationShouldOpenAccountWindow";

NSString *const SDErrorDomain                             = @"com.safedrive";

NSUInteger const SDMountErrorUnknown                      = 0x1001;
NSUInteger const SDMountErrorAuthorization                = 0x1002;
NSUInteger const SDMountErrorTimeout                      = 0x1003;
NSUInteger const SDMountErrorMountFailed                  = 0x1004;
NSUInteger const SDMountErrorUnmountFailed                = 0x1005;
NSUInteger const SDMountErrorAlreadyMounted               = 0x1006;
NSUInteger const SDMountErrorAskpassMissing               = 0x1007;


NSUInteger const SDSystemErrorUnknown                     = 0x2001;
NSUInteger const SDSystemErrorAddLoginItemFailed          = 0x2002;
NSUInteger const SDSystemErrorRemoveLoginItemFailed       = 0x2003;