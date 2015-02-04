
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDConstants.h"

#pragma mark - SafeDrive API constants

NSString *const SDAPIDomain = @"safedrive.io";
NSString *const SDWebDomain = @"safedrive.io";

#pragma mark - Common paths

NSString *const SDDefaultSSHFSPath = @"/usr/local/bin/sshfs";
NSString *const SDDefaultOSXFUSEFSPath = @"/Library/Filesystems/osxfusefs.fs";

#pragma mark - Keychain constants


NSString *const SDServiceName = @"safedrive.io";


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


NSString *const SDAPIDidEnterMaintenancePeriod            = @"SDAPIDidEnterMaintenancePeriod";
NSString *const SDAPIDidBecomeReachable                   = @"SDAPIDidBecomeReachable";
NSString *const SDAPIDidBecomeUnreachable                 = @"SDAPIDidBecomeUnreachable";



#pragma mark - Errors

NSString *const SDErrorDomain = @"io.safedrive";

NSUInteger const SDErrorNone = 0;
