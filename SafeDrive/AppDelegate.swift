
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Fabric
import Crashlytics

import RealmSwift
import Realm
import Sparkle

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


    var CFBundleVersion = Int((Bundle.main.infoDictionary!["CFBundleVersion"]) as! String)!

    var CFBundleShortVersionString = (Bundle.main.infoDictionary!["CFBundleShortVersionString"]) as! String!

    let SDBuildVersionLast = UserDefaults.standard.integer(forKey: SDBuildVersionLastKey)

    var environment: String = "STAGING"

    func applicationDidFinishLaunching(_ aNotification: Foundation.Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        Crashlytics.sharedInstance().delegate = self
        Fabric.with([Crashlytics.self])

        // initialize error handler, from this point on SDLog() and SDErrorHandlerReport() should be safe to use
        SDErrorHandlerInitialize()
        if let updater = SUUpdater.shared() {
            #if DEBUG
                SDLog("SafeDrive staging build \(CFBundleVersion)")
                environment = "STAGING"
                updater.feedURL = URL(string: "https://cdn.infincia.com/safedrive/appcast.xml")
                
            #else
                SDLog("SafeDrive release build \(CFBundleVersion)")
                environment = "RELEASE"
                updater.feedURL = URL(string: "https://cdn.infincia.com/safedrive-release/appcast.xml")
            #endif
        }

        if CFBundleVersion < SDBuildVersionLast {
            let alert: NSAlert = NSAlert()
            alert.messageText = "Unsupported downgrade"
            alert.addButton(withTitle: "Quit")
            alert.informativeText = "Your currently installed version of SafeDrive is older than the previously installed version.\n\nThis is unsupported and can cause data loss or crashes.\n\nPlease reinstall the newest version available."

            alert.runModal()
            NSApp.terminate(nil)
        }
        UserDefaults.standard.set(CFBundleVersion, forKey: SDBuildVersionLastKey)

        PFMoveToApplicationsFolderIfNecessary()
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldFinishConfiguration(_:)), name: Notification.Name.applicationShouldFinishConfiguration, object: nil)
        
        
        // register SDApplicationControlProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAccountWindow(_:)), name: Notification.Name.applicationShouldOpenAccountWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenPreferencesWindow(_:)), name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAboutWindow(_:)), name: Notification.Name.applicationShouldOpenAboutWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.applicationShouldOpenSyncWindow(_:)), name: Notification.Name.applicationShouldOpenSyncWindow, object: nil)
        
        // register SDAccountProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didAuthenticate(_:)), name: Notification.Name.accountAuthenticated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut(_:)), name: Notification.Name.accountSignOut, object: nil)
        
        self.welcomeWindowController = WelcomeWindowController()
        _ = self.welcomeWindowController!.window!
        
    }
    
    
    func applicationWillTerminate(_ aNotification: Foundation.Notification) {
        SDLog("SafeDrive build \(CFBundleVersion), protocol version \(kAppXPCProtocolVersion) exiting")
        NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: nil)

    }

    // MARK: SDApplicationControlProtocol methods


    func applicationShouldOpenAccountWindow(_ notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)
            self.accountWindowController.showWindow(nil)
        })
    }

    func applicationShouldOpenPreferencesWindow(_ notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in
            NSApp.activate(ignoringOtherApps: true)
            self.preferencesWindowController?.showWindow(nil)
        })
    }

    func applicationShouldOpenAboutWindow(_ notification: Foundation.Notification) {
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

    func applicationShouldFinishConfiguration(_ notification: Foundation.Notification) {
        DispatchQueue.main.async(execute: {() -> Void in

            guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db") else {
                SDLog("Failed to obtain group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
                return
            }

            do {
                try FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SDLog("Failed to create group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
            }

            self.serviceManager = ServiceManager.sharedServiceManager
            self.serviceManager.unloadService()

            let dbURL = groupURL.appendingPathComponent("sync.realm")
            let newdbURL = dbURL.appendingPathExtension("new")

            let config = Realm.Configuration(
                fileURL: dbURL,
                // Set the new schema version. This must be greater than the previously used
                // version (if you've never set a schema version before, the version is 0).
                schemaVersion: 9,
                migrationBlock: { migration, oldSchemaVersion in
                    SDLog("Migrating db version \(oldSchemaVersion) to 9")
                    migration.enumerateObjects(ofType: Machine.className()) { oldObject, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerateObjects(ofType: SyncFolder.className()) { oldObject, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerateObjects(ofType: SyncTask.className()) { oldObject, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
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
                let realm = try! Realm(fileURL: dbURL)
                try! realm.writeCopy(toFile: newdbURL)
                try! fileManager.removeItem(at: dbURL)
                try! fileManager.moveItem(at: newdbURL, to: dbURL)
            }

            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
                self.serviceManager.loadService()
                self.serviceRouter = ServiceXPCRouter()
            })
            self.syncScheduler = SyncScheduler.sharedSyncScheduler

            self.dropdownMenuController = DropdownController()

            self.accountController = AccountController.sharedAccountController

            self.accountWindowController = AccountWindowController()
            _ = self.accountWindowController.window!

            let markdownURL = Bundle.main.url(forResource: "Changelog.md", withExtension: nil)

            let data = FileManager.default.contents(atPath: markdownURL!.path)

            let markdown = String(data: data!, encoding: String.Encoding.utf8)!


            self.aboutWindowController = DCOAboutWindowController()
            self.aboutWindowController.useTextViewForAcknowledgments = true
            self.aboutWindowController.appCredits = TSMarkdownParser.standard().attributedString(fromMarkdown: markdown)
            let version = "Version \(self.CFBundleShortVersionString!)-\(self.environment) (Build \(self.CFBundleVersion))"
            self.aboutWindowController.appVersion = version
            let websiteURLPath: String = "https://\(SDWebDomain)"
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

    func didAuthenticate(_ notification: Foundation.Notification) {
        guard let uniqueClientID = notification.object as? String else {
            return
        }
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
        self.preferencesWindowController = PreferencesWindowController(uniqueClientID: uniqueClientID)
        _ = self.preferencesWindowController!.window!
    }

    func didSignOut(_ notification: Foundation.Notification) {
        assert(Thread.isMainThread, "Not main thread!!!")
        self.syncScheduler?.stop()
        self.preferencesWindowController?.close()
        self.preferencesWindowController = nil
    }

    func didReceiveAccountDetails(_ notification: Foundation.Notification) {
    
    }

    func didReceiveAccountStatus(_ notification: Foundation.Notification) {
    
    }

    // MARK: CrashlyticsDelegate
    
    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        //
        // always submit the report to Crashlytics
        completionHandler(true)

        // show an alert telling the user a crash report was generated, allow them to opt out of seeing more alerts
        //CrashAlert.show()

    }

}
