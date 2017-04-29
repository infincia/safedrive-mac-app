
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Cocoa
import Crashlytics
import Fabric
import Realm
import RealmSwift
import SafeDriveSDK
import Sparkle


@NSApplicationMain
class AppDelegate: NSObject {
    fileprivate var dropdownMenuController: DropdownController!
    fileprivate var preferencesWindowController: PreferencesWindowController!
    
    fileprivate var accountController: AccountController!
    
    fileprivate var mountController: MountController!
    
    fileprivate var aboutWindowController: DCOAboutWindowController!
    fileprivate var serviceRouter: ServiceXPCRouter!
    fileprivate var serviceManager: ServiceManager!
    
    fileprivate var syncScheduler: SyncScheduler!
    fileprivate var welcomeWindowController: WelcomeWindowController!
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    // swiftlint:disable force_unwrapping
    var CFBundleVersion = Int((Bundle.main.infoDictionary!["CFBundleVersion"])! as! String)!
    
    var CFBundleShortVersionString = (Bundle.main.infoDictionary!["CFBundleShortVersionString"])! as! String
    // swiftlint:enable force_unwrapping

    let SDBuildVersionLast = UserDefaults.standard.integer(forKey: SDBuildVersionLastKey)
    
    let SDRealmSchemaVersionLast = UserDefaults.standard.integer(forKey: SDRealmSchemaVersionLastKey)
    
    var environment: String = "STAGING"
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Foundation.Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true, SDCurrentVolumeNameKey: SDDefaultVolumeName, SDMountAtLaunchKey: true])
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
        
        let currentOS = currentOSVersion()
        
        // swiftlint:disable force_try
        try! self.sdk.setUp(client_version: CFBundleShortVersionString, operating_system: currentOS, language_code: languageCode, config: config, local_storage_path: groupURL.path)
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

        
        if SDRealmSchemaVersionLast > Int(SDCurrentRealmSchema) {
            let alert: NSAlert = NSAlert()
            alert.messageText = "Unsupported downgrade"
            alert.addButton(withTitle: "Quit")
            alert.informativeText = "Your currently installed version of SafeDrive is older than the previously installed version.\n\nThis is unsupported and can cause data loss or crashes.\n\nPlease reinstall the newest version available."
            
            alert.runModal()
            NSApp.terminate(nil)
        }
        
        UserDefaults.standard.set(SDCurrentRealmSchema, forKey: SDRealmSchemaVersionLastKey)
        
        UserDefaults.standard.set(CFBundleVersion, forKey: SDBuildVersionLastKey)
        
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureRealm), name: Notification.Name.applicationDidConfigureRealm, object: nil)
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
        self.serviceManager.unloadService()
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            self.serviceManager.loadService()
            self.serviceRouter = ServiceXPCRouter()
        })
        
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
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)

        })
    }
    
    func applicationShouldOpenPreferencesWindow(notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindowController?.showWindow(nil)
        })
    }
    
    func applicationShouldOpenAboutWindow(notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)
            self.aboutWindowController.showWindow(nil)
        })
    }
    
    func applicationShouldOpenSyncWindow(_ notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindowController?.showWindow(nil)
        })
    }
    
    func applicationShouldToggleMountState(notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            if self.mountController.mounted {
                NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: true)
            } else {
                NotificationCenter.default.post(name: Notification.Name.volumeShouldMount, object: nil)
            }
        })
    }
    
    func applicationShouldFinishConfiguration(notification: Foundation.Notification) {

    }
}

extension AppDelegate: SDApplicationEventProtocol {
    func applicationDidConfigureRealm(notification: Notification) {
        
    }
    
    func applicationDidConfigureClient(notification: Notification) {
        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in AppDelegate")

            return
        }
        DispatchQueue.global(priority: .default).async {
            
            let groupURL = storageURL()

            
            let uniqueClientURL = groupURL.appendingPathComponent(uniqueClientID)
            
            do {
                try FileManager.default.createDirectory(at: uniqueClientURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SDLog("Failed to create group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
            }
            
            let dbURL = uniqueClientURL.appendingPathComponent("sync.realm")
            
            let newdbURL = dbURL.appendingPathExtension("new")
            // swiftlint:disable force_unwrapping

            let config = Realm.Configuration(
                fileURL: dbURL,
                // Set the new schema version. This must be greater than the previously used
                // version (if you've never set a schema version before, the version is 0).
                schemaVersion: UInt64(SDCurrentRealmSchema),
                migrationBlock: { migration, oldSchemaVersion in
                    SDLog("Migrating db version \(oldSchemaVersion) to \(SDCurrentRealmSchema)")
                    migration.enumerateObjects(ofType: SyncFolder.className()) { _, newObject in
                        if oldSchemaVersion < 15 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerateObjects(ofType: SyncTask.className()) { _, newObject in
                        if oldSchemaVersion < 15 {
                            migration.delete(newObject!)
                        }
                    }
            })
            // swiftlint:enable force_unwrapping

            Realm.Configuration.defaultConfiguration = config
            
            autoreleasepool {
                let fileManager = FileManager.default
                
                do {
                    try fileManager.removeItem(at: newdbURL)
                } catch {
                    // ignored, file may not exist at all, but if it does and we can't remove it we'll crash next and get a report
                }
                // swiftlint:disable force_try
                let realm = try! Realm(fileURL: dbURL)
                try! realm.writeCopy(toFile: newdbURL)
                try! fileManager.removeItem(at: dbURL)
                try! fileManager.moveItem(at: newdbURL, to: dbURL)
                // swiftlint:enable force_try
            }
            
            autoreleasepool {
                /*
                 Reset all sync folders at startup.
                 
                 Prevents the following issue:
                 
                 1) App starts syncing FolderA, sets its "syncing" field to true in the database
                 2) App exits/crashes during sync
                 3) App starts again
                 4) App refuses to sync folderA again because the "syncing" field is still set to true
                 
                 We can do this because sync tasks ALWAYS exit when the app does, so it is not possible for a sync to have been
                 running if the app wasn't.
                 
                 */
                // swiftlint:disable force_try
                let realm = try! Realm(fileURL: dbURL)

                try! realm.write {
                    let syncFolders = realm.objects(SyncFolder.self)
                    syncFolders.setValue(false, forKey: "syncing")
                    syncFolders.setValue(false, forKey: "restoring")
                    syncFolders.setValue(nil, forKey: "currentSyncUUID")
                }
                // swiftlint:enable force_try
                
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.applicationDidConfigureRealm, object: nil)
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
