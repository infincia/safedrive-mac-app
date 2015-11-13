
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDConstants.h"

#pragma mark - General constants

NSString *const SDDefaultVolumeName = @"SafeDrive";
NSString *const SDDefaultServerPath = @"storage";
NSString *const SDDefaultServerHostname = @"93.113.136.95";
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

#pragma mark - Keychain constants


NSString *const SDServiceName = @"safedrive.io";
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


NSString *const SDAPIDidEnterMaintenancePeriod            = @"SDAPIDidEnterMaintenancePeriod";
NSString *const SDAPIDidBecomeReachable                   = @"SDAPIDidBecomeReachable";
NSString *const SDAPIDidBecomeUnreachable                 = @"SDAPIDidBecomeUnreachable";

NSString *const SDAccountStatusNotification               = @"SDAccountStatusNotification";
NSString *const SDAccountDetailsNotification              = @"SDAccountDetailsNotification";


#pragma mark - Errors

NSString *const SDErrorDomain = @"io.safedrive";

NSUInteger const SDErrorNone = 0;
