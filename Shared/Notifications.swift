
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let mountState = Notification.Name("mountStateNotification")
    static let mountDetails = Notification.Name("mountDetailsNotification")

    static let volumeDidMountDesktopNotification = Notification.Name("volumeDidMountDesktopNotification")
    static let volumeDidUnmountDesktopNotification = Notification.Name("volumeDidUnmountDesktopNotification")
    static let volumeMountingDesktopNotification = Notification.Name("volumeMountingDesktopNotification")
    static let volumeUnmountingDesktopNotification = Notification.Name("volumeUnmountingDesktopNotification")
    static let volumeMountFailedDesktopNotification = Notification.Name("volumeMountFailedDesktopNotification")
    static let volumeUnmountFailedDesktopNotification = Notification.Name("volumeUnmountFailedDesktopNotification")
    static let volumeIsFullDesktopNotification = Notification.Name("volumeIsFullDesktopNotification")

    static let volumeDidMount = Notification.Name("volumeDidMountNotification")
    static let volumeDidUnmount = Notification.Name("volumeDidUnmountNotification")
    static let volumeShouldMount = Notification.Name("volumeShouldMountNotification")
    static let volumeShouldUnmount = Notification.Name("volumeShouldUnmountNotification")

    static let volumeSubprocessDidTerminate = Notification.Name("volumeSubprocessDidTerminateNotification")
    static let volumeMounting = Notification.Name("volumeMountingNotification")
    static let volumeUnmounting = Notification.Name("volumeUnmountingNotification")
    static let volumeMountFailed = Notification.Name("volumeMountFailed")
    static let volumeUnmountFailed = Notification.Name("volumeUnmountFailed")


    static let applicationShouldOpenPreferencesWindow = Notification.Name("applicationShouldOpenPreferencesWindowNotification")
    static let applicationShouldOpenAccountWindow = Notification.Name("applicationShouldOpenAccountWindowNotification")
    static let applicationShouldOpenAboutWindow = Notification.Name("applicationShouldOpenAboutWindowNotification")
    static let applicationShouldOpenSyncWindow = Notification.Name("applicationShouldOpenSyncWindowNotification")
    static let applicationShouldFinishConfiguration = Notification.Name("applicationShouldFinishConfigurationNotification")
    
    
    static let applicationDidConfigureClient = Notification.Name("applicationDidConfigureClient")
    static let applicationDidConfigureUser = Notification.Name("applicationDidConfigureUser")

    static let apiDidEnterMaintenancePeriod = Notification.Name("apiDidEnterMaintenancePeriodNotification")
    static let apiDidBecomeReachable = Notification.Name("apiDidBecomeReachableNotification")
    static let apiDidBecomeUnreachable = Notification.Name("apiDidBecomeUnreachableNotification")

    static let accountSignIn = Notification.Name("accountSignInNotification")
    static let accountSignOut = Notification.Name("accountSignOutNotification")
    static let accountStatus = Notification.Name("accountStatusNotification")
    static let accountDetails = Notification.Name("accountDetailsNotification")
    static let accountLoadedRecoveryPhrase = Notification.Name("accountLoadedRecoveryPhraseNotification")
    static let accountCreatedRecoveryPhrase = Notification.Name("accountCreatedRecoveryPhraseNotification")
    static let accountNeedsRecoveryPhrase = Notification.Name("accountNeedsRecoveryPhraseNotification")

    static let syncEvent = Notification.Name("syncEventNotification")

}

class MountEvent {
    var userInitiated: Bool = false
    
    init(userInitiated: Bool) {
        self.userInitiated = userInitiated
    }
}

class UnmountEvent {
    var askForOpenApps: Bool = false
    var force: Bool = false
    
    init(askForOpenApps: Bool, force: Bool) {
        self.askForOpenApps = askForOpenApps
        self.force = force
    }
}
