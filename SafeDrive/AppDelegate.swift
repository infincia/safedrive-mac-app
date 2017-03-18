
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Cocoa

import Fabric
import Crashlytics

import RealmSwift
import Realm
import Sparkle

import SafeDriveSDK

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SDApplicationControlProtocol, SDAccountProtocol, CrashlyticsDelegate {
    fileprivate var dropdownMenuController: DropdownController!
    fileprivate var accountWindowController: AccountWindowController!
    fileprivate var preferencesWindowController: PreferencesWindowController?
    
    fileprivate var accountController: AccountController!
    
    
    fileprivate var aboutWindowController: DCOAboutWindowController!
    fileprivate var serviceRouter: ServiceXPCRouter!
    fileprivate var serviceManager: ServiceManager!
    
    fileprivate var syncScheduler: SyncScheduler?
    fileprivate var welcomeWindowController: WelcomeWindowController?
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    var CFBundleVersion = Int((Bundle.main.infoDictionary!["CFBundleVersion"])! as! String)!
    
    var CFBundleShortVersionString = (Bundle.main.infoDictionary!["CFBundleShortVersionString"])! as! String
    
    let SDBuildVersionLast = UserDefaults.standard.integer(forKey: SDBuildVersionLastKey)
    
    let SDRealmSchemaVersionLast = UserDefaults.standard.integer(forKey: SDRealmSchemaVersionLastKey)
    
    var environment: String = "STAGING"
    
    func applicationDidFinishLaunching(_ aNotification: Foundation.Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
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
        
        // swiftlint:disable force_try
        try! self.sdk.setUp(client_version: CFBundleShortVersionString, operating_system: "Mac OS X", language_code: languageCode, config: config, local_storage_path: groupURL.path)
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
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldFinishConfiguration), name: Notification.Name.applicationShouldFinishConfiguration, object: nil)
        
        
        // register SDApplicationControlProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAccountWindow), name: Notification.Name.applicationShouldOpenAccountWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenPreferencesWindow), name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAboutWindow), name: Notification.Name.applicationShouldOpenAboutWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.applicationShouldOpenSyncWindow(_:)), name: Notification.Name.applicationShouldOpenSyncWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldToggleMountState), name: Notification.Name.applicationShouldToggleMountState, object: nil)
        
        // register SDAccountProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        
        self.welcomeWindowController = WelcomeWindowController()
        _ = self.welcomeWindowController!.window!
        
        self.syncScheduler = SyncScheduler.sharedSyncScheduler

        self.dropdownMenuController = DropdownController()
        
    }
    
    
    func applicationWillTerminate(_ aNotification: Foundation.Notification) {
        SDLog("SafeDrive build \(CFBundleVersion), protocol version \(kAppXPCProtocolVersion) exiting")
        NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: nil)
        
    }
    
    // MARK: SDApplicationControlProtocol methods
    
    
    func applicationShouldOpenAccountWindow(notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)
            self.accountWindowController.showWindow(nil)
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
            if MountController.shared.mounted {
                NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: nil)
            } else {
                NotificationCenter.default.post(name: Notification.Name.volumeShouldMount, object: nil)
            }
        })
    }
    
    func applicationShouldFinishConfiguration(notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            
            let groupURL = storageURL()
            
            self.serviceManager = ServiceManager.sharedServiceManager
            self.serviceManager.unloadService()
            
            let dbURL = groupURL.appendingPathComponent("sync.realm")
            let newdbURL = dbURL.appendingPathExtension("new")
            
            let config = Realm.Configuration(
                fileURL: dbURL,
                // Set the new schema version. This must be greater than the previously used
                // version (if you've never set a schema version before, the version is 0).
                schemaVersion: UInt64(SDCurrentRealmSchema),
                migrationBlock: { migration, oldSchemaVersion in
                    SDLog("Migrating db version \(oldSchemaVersion) to \(SDCurrentRealmSchema)")
                    migration.enumerateObjects(ofType: Machine.className()) { _, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerateObjects(ofType: SyncFolder.className()) { _, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerateObjects(ofType: SyncTask.className()) { _, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    
                    // update for encrypted bool field
                    migration.enumerateObjects(ofType: SyncFolder.className()) { _, newObject in
                        if oldSchemaVersion < 10 {
                            newObject!["encrypted"] = false
                        }
                    }
                    
                    // update for current sync UUID field
                    migration.enumerateObjects(ofType: SyncFolder.className()) { _, newObject in
                        if oldSchemaVersion < 11 {
                            newObject!["currentSyncUUID"] = nil
                        }
                    }
                    
                    // update for sync sessions
                    migration.enumerateObjects(ofType: SyncFolder.className()) { _, newObject in
                        if oldSchemaVersion < 12 {
                            migration.delete(newObject!)
                        }
                    }
                    
                    // update for last sync task storage in folders
                    migration.enumerateObjects(ofType: SyncFolder.className()) { _, newObject in
                        if oldSchemaVersion < 12 {
                            newObject!["lastSyncUUID"] = nil
                        }
                    }
            })
            
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
            
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
                self.serviceManager.loadService()
                self.serviceRouter = ServiceXPCRouter()
            })
            
            
            self.accountController = AccountController.sharedAccountController
            
            self.accountWindowController = AccountWindowController()
            _ = self.accountWindowController.window!
            
            self.preferencesWindowController = PreferencesWindowController()
            _ = self.preferencesWindowController!.window!
            
            let markdownURL = Bundle.main.url(forResource: "Changelog.md", withExtension: nil)
            
            let data = FileManager.default.contents(atPath: markdownURL!.path)
            
            let markdown = String(data: data!, encoding: String.Encoding.utf8)!
            
            
            self.aboutWindowController = DCOAboutWindowController()
            self.aboutWindowController.useTextViewForAcknowledgments = true
            self.aboutWindowController.appCredits = TSMarkdownParser.standard().attributedString(fromMarkdown: markdown)
            let sddk = "\(SafeDriveSDK.sddk_version)-\(SafeDriveSDK.sddk_channel)"

            let version = "\(self.CFBundleShortVersionString)-\(self.environment) (SDDK \(sddk))"

            self.aboutWindowController.appVersion = version
            let websiteURLPath: String = "https://\(webDomain())"
            self.aboutWindowController.appWebsiteURL = URL(string: websiteURLPath)!
            
            if self.accountController.hasCredentials {
                // we need to sign in automatically if at all possible, even if we don't need to automount
                // we need a session token and account details in order to support sync
                self.accountWindowController.signIn(self)
            }
            NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenAboutWindow, object: nil)
        })
    }
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: Foundation.Notification) {
        guard let currentUser = notification.object as? User else {
            return
        }
        
        let uniqueClientID = currentUser.uniqueClientId
        
        assert(Thread.isMainThread, "Not main thread!!!")
        self.syncScheduler!.running = true
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async { () -> Void in
            do {
                try self.syncScheduler?.syncSchedulerLoop(uniqueClientID)
            } catch {
                SDLog("Error starting scheduler: \(error)")
                Crashlytics.sharedInstance().crash()
            }
        }
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.isMainThread, "Not main thread!!!")
        self.syncScheduler?.stop()
        self.preferencesWindowController?.close()
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        
    }
    
    // MARK: CrashlyticsDelegate
    
    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        //
        // always submit the report to Crashlytics
        completionHandler(true)
        
        // show an alert telling the user a crash report was generated, allow them to opt out of seeing more alerts
        CrashAlert.show()
        
    }
    
}
