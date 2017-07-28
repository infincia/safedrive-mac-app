
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Cocoa
import Crashlytics
import Fabric
import PromiseKit
import Sparkle

extension Promise {
    static var void: Promise<Void> {
        return Promise<Void>(value: ())
    }
}

@NSApplicationMain
class AppDelegate: NSObject {
    fileprivate var dropdownMenuController: DropdownController!
    fileprivate var preferencesWindowController: PreferencesWindowController!
    
    fileprivate var accountController: AccountController!
    
    fileprivate var mountController: MountController!
    
    fileprivate var aboutWindowController: DCOAboutWindowController!
    fileprivate var serviceManager: ServiceManager!
    
    fileprivate var syncScheduler: SyncScheduler!
    fileprivate var welcomeWindowController: WelcomeWindowController!
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    // swiftlint:disable force_unwrapping
    var CFBundleVersion = Int((Bundle.main.infoDictionary!["CFBundleVersion"])! as! String)!
    
    var CFBundleShortVersionString = (Bundle.main.infoDictionary!["CFBundleShortVersionString"])! as! String
    // swiftlint:enable force_unwrapping

    let SDBuildVersionLast = UserDefaults.standard.integer(forKey: userDefaultsBuildVersionLastKey())
    
    var environment: String = "STAGING"
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Foundation.Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true, userDefaultsCurrentVolumeNameKey(): defaultVolumeName(), keepMountedKey(): true, useSFTPFSKey(): false])
        Crashlytics.sharedInstance().delegate = self
        Fabric.with([Crashlytics.self])
        
        // initialize safedrive SDK
                        
        var config: SDKConfiguration
        if isProduction() {
            config = SDKConfiguration.Production
        } else {
            config = SDKConfiguration.Staging
        }
        
        let languageCode: String = Locale.preferredLanguages[0]

        let groupURL = storageURL()
        
        let currentOS = "macOS \(currentOSVersion())"
        
        let logLevel = SDKLogLevel.debug
        
        // swiftlint:disable force_try
        try! self.sdk.setUp(client_version: CFBundleShortVersionString, operating_system: currentOS, language_code: languageCode, config: config, local_storage_path: groupURL.path, log_level: logLevel)
        // swiftlint:enable force_try
        
        // initialize error handler, from this point on SDLog() and SDErrorHandlerReport() should be safe to use
        SDErrorHandlerInitialize()
        if let updater = SUUpdater.shared() {
            if isProduction() {
                SDLog("SafeDrive release build \(CFBundleVersion)")
                environment = "RELEASE"
                updater.feedURL = URL(string: "https://cdn.infincia.com/safedrive/release.xml")
            } else {
                SDLog("SafeDrive staging build \(CFBundleVersion)")
                environment = "STAGING"
                updater.feedURL = URL(string: "https://cdn.infincia.com/safedrive/staging.xml")
            }
        }
        
        SDLog("SDDK \(SafeDriveSDK.sddk_version)-\(SafeDriveSDK.sddk_channel)")

        UserDefaults.standard.set(CFBundleVersion, forKey: userDefaultsBuildVersionLastKey())
        
        PFMoveToApplicationsFolderIfNecessary()
        
        
        do {
            try FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            SDLog("Failed to create group container, this is a fatal error")
            Crashlytics.sharedInstance().crash()
        }
        
        NSUserNotificationCenter.default.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldFinishConfiguration), name: Notification.Name.applicationShouldFinishConfiguration, object: nil)
        
        
        // register SDApplicationControlProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAccountWindow), name: Notification.Name.applicationShouldOpenAccountWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenPreferencesWindow), name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAboutWindow), name: Notification.Name.applicationShouldOpenAboutWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.applicationShouldOpenSyncWindow(_:)), name: Notification.Name.applicationShouldOpenSyncWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldToggleMountState), name: Notification.Name.applicationShouldToggleMountState, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        // register SDAccountProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        
        self.welcomeWindowController = WelcomeWindowController()
        // swiftlint:disable force_unwrapping
        _ = self.welcomeWindowController.window!
        // swiftlint:enable force_unwrapping

        self.syncScheduler = SyncScheduler.sharedSyncScheduler
        
        self.mountController = MountController.shared

        self.dropdownMenuController = DropdownController()
        
        self.serviceManager = ServiceManager.sharedServiceManager
        self.serviceManager.ensureServiceIsRunning()
        
        self.accountController = AccountController.sharedAccountController
        
        self.preferencesWindowController = PreferencesWindowController()
        // swiftlint:disable force_unwrapping
        _ = self.preferencesWindowController.window!
        // swiftlint:enable force_unwrapping
        
        let markdownURL = Bundle.main.url(forResource: "Changelog.md", withExtension: nil)
        
        // swiftlint:disable force_unwrapping
        let data = FileManager.default.contents(atPath: markdownURL!.path)
        
        let markdown = String(data: data!, encoding: String.Encoding.utf8)!
        // swiftlint:enable force_unwrapping
        
        self.aboutWindowController = DCOAboutWindowController()
        self.aboutWindowController.useTextViewForAcknowledgments = true
        self.aboutWindowController.appCredits = TSMarkdownParser.standard().attributedString(fromMarkdown: markdown)
        let sddk = "\(SafeDriveSDK.sddk_version)-\(SafeDriveSDK.sddk_channel)"
        
        let version = "\(self.CFBundleShortVersionString)-\(self.environment) (SDDK \(sddk))"
        
        self.aboutWindowController.appVersion = version
        let websiteURLPath: String = "https://\(webDomain())"
        // swiftlint:disable force_unwrapping
        self.aboutWindowController.appWebsiteURL = URL(string: websiteURLPath)!
        // swiftlint:enable force_unwrapping

    }
    
    
    func applicationWillTerminate(_ aNotification: Foundation.Notification) {
        SDLog("SafeDrive build \(CFBundleVersion), protocol version \(kAppXPCProtocolVersion) exiting")
        NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: false)
        
    }
}

extension AppDelegate: SDApplicationControlProtocol {
    func applicationShouldOpenAccountWindow(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // TODO: move to preferences window controller
    func applicationShouldOpenPreferencesWindow(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindowController?.showWindow(nil)
        }
    }
    
    // TODO: move to about window controller
    func applicationShouldOpenAboutWindow(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.aboutWindowController.showWindow(nil)
        }
    }
    
    // TODO: move to preferences window controller
    func applicationShouldOpenSyncWindow(_ notification: Foundation.Notification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindowController?.showWindow(nil)
        }
    }
    
    // TODO: move to mount controller
    func applicationShouldToggleMountState(notification: Foundation.Notification) {
        DispatchQueue.main.async {
            if self.mountController.mounted {
                NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: true)
            } else {
                NotificationCenter.default.post(name: Notification.Name.volumeShouldMount, object: nil)
            }
        }
    }
    
    func applicationShouldFinishConfiguration(notification: Foundation.Notification) {

    }
}

extension AppDelegate: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in AppDelegate")

            return
        }
        background {
            
            let groupURL = storageURL()

            
            let uniqueClientURL = groupURL.appendingPathComponent(uniqueClientID)
            
            do {
                try FileManager.default.createDirectory(at: uniqueClientURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SDLog("Failed to create group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
            }
        }
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        guard let _ = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in AppDelegate")

            return
        }
    }
}

extension AppDelegate: SDAccountProtocol {
    
    func didSignIn(notification: Foundation.Notification) {
        guard let _ = notification.object as? User else {
            return
        }
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.isMainThread, "Not main thread!!!")
        self.preferencesWindowController?.close()
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        
    }
}

extension AppDelegate: CrashlyticsDelegate {
    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        //
        // always submit the report to Crashlytics
        completionHandler(true)
        
        // show an alert telling the user a crash report was generated, allow them to opt out of seeing more alerts
        //CrashAlert.show()
    }
    
}

extension AppDelegate: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindowController?.showWindow(nil)
        }
        center.removeAllDeliveredNotifications()
    }
}
