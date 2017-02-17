
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

@objc
protocol SDVolumeEventProtocol: class {
    func volumeDidMount(notification: Notification)
    func volumeDidUnmount(notification: Notification)
    func volumeShouldUnmount(notification: Notification)
    func volumeShouldMount(notification: Notification)
    func volumeSubprocessDidTerminate(notification: Notification)
}

@objc
protocol SDMountStateProtocol: class {
    func mountStateMounted(notification: Notification)
    func mountStateUnmounted(notification: Notification)
    func mountStateDetails(notification: Notification)
}

@objc
protocol SDAccountProtocol: class {
    func didAuthenticate(notification: Notification)
    func didSignOut(notification: Notification)
    func didReceiveAccountStatus(notification: Notification)
    func didReceiveAccountDetails(notification: Notification)
}

@objc
protocol SDServiceStatusProtocol: class {
    func didReceiveServiceStatus(notification: Notification)
}

@objc
protocol SDApplicationControlProtocol: class {
    func applicationShouldOpenPreferencesWindow(notification: Notification)
    func applicationShouldOpenAccountWindow(notification: Notification)
    func applicationShouldOpenAboutWindow(notification: Notification)
    func applicationShouldFinishConfiguration(notification: Notification)
    func applicationShouldToggleMountState(notification: Notification)
}

@objc
protocol SDAPIAvailabilityProtocol: class {
    func apiDidEnterMaintenancePeriod(notification: Notification)
    func apiDidBecomeReachable(notification: Notification)
    func apiDidBecomeUnreachable(notification: Notification)
}
