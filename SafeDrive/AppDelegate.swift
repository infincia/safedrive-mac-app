
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
    private var dropdownMenuController: DropdownController!
    private var accountWindowController: AccountWindowController!
    private var preferencesWindowController: PreferencesWindowController!

    private var aboutWindowController: DCOAboutWindowController!
    private var serviceRouter: SDServiceXPCRouter!
    private var serviceManager: ServiceManager!

    private var syncScheduler: SyncScheduler?
    private var installWindowController: InstallerWindowController?


    var CFBundleVersion = Int((NSBundle.mainBundle().infoDictionary?["CFBundleVersion"]) as! String)!

    var CFBundleShortVersionString = (NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"]) as! String!

    let SDBuildVersionLast = NSUserDefaults.standardUserDefaults().integerForKey(SDBuildVersionLastKey)

    var environment: String = "STAGING"


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        NSUserDefaults.standardUserDefaults().registerDefaults(["NSApplicationCrashOnExceptions": true])
        Crashlytics.sharedInstance().delegate = self
        Fabric.with([Crashlytics.self])

        // initialize error handler, from this point on SDLog() and SDErrorHandlerReport() should be safe to use
        SDErrorHandlerInitialize()
        let updater = SUUpdater.sharedUpdater()

        #if DEBUG
        SDLog("SafeDrive staging build \(CFBundleVersion)")
        environment = "STAGING"
        updater.feedURL = NSURL(string: "https://cdn.infincia.com/safedrive/appcast.xml")

        #else
        SDLog("SafeDrive release build \(CFBundleVersion)")
        environment = "RELEASE"
        updater.feedURL = NSURL(string: "https://cdn.infincia.com/safedrive-release/appcast.xml")
        #endif



        if CFBundleVersion < SDBuildVersionLast {
            let alert: NSAlert = NSAlert()
            alert.messageText = "Unsupported downgrade"
            alert.addButtonWithTitle("Quit")
            alert.informativeText = "Your currently installed version of SafeDrive is older than the previously installed version.\n\nThis is unsupported and can cause data loss or crashes.\n\nPlease reinstall the newest version available."

            alert.runModal()
            NSApp.terminate(nil)
        }
        NSUserDefaults.standardUserDefaults().setInteger(CFBundleVersion, forKey: SDBuildVersionLastKey)

        PFMoveToApplicationsFolderIfNecessary()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldFinishConfiguration(_:)), name: SDApplicationShouldFinishConfiguration, object: nil)

        self.installWindowController = InstallerWindowController()
        _ = self.installWindowController!.window!

    }


    func applicationWillTerminate(aNotification: NSNotification) {
        SDLog("SafeDrive build \(CFBundleVersion), protocol version \(kSDAppXPCProtocolVersion) exiting")
        NSNotificationCenter.defaultCenter().postNotificationName(SDVolumeShouldUnmountNotification, object: nil)

    }

    // MARK: SDApplicationControlProtocol methods


    func applicationShouldOpenAccountWindow(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            NSApp.activateIgnoringOtherApps(true)
            self.accountWindowController.showWindow(nil)
        })
    }

    func applicationShouldOpenPreferencesWindow(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            NSApp.activateIgnoringOtherApps(true)
            self.preferencesWindowController.showWindow(nil)
        })
    }

    func applicationShouldOpenAboutWindow(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            NSApp.activateIgnoringOtherApps(true)
            self.aboutWindowController.showWindow(nil)
        })
    }

    func applicationShouldOpenSyncWindow(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            NSApp.activateIgnoringOtherApps(true)
            self.preferencesWindowController?.showWindow(nil)
        })
    }

    func applicationShouldFinishConfiguration(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in

            guard let groupURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db") else {
                SDLog("Failed to obtain group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
                return
            }

            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(groupURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SDLog("Failed to create group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
            }

            self.serviceManager = ServiceManager.sharedServiceManager
            self.serviceManager.unloadService()

            let dbURL = groupURL.URLByAppendingPathComponent("sync.realm")
            let newdbURL = dbURL.URLByAppendingPathExtension("new")

            let config = Realm.Configuration(
                fileURL: dbURL,
                // Set the new schema version. This must be greater than the previously used
                // version (if you've never set a schema version before, the version is 0).
                schemaVersion: 9,
                migrationBlock: { migration, oldSchemaVersion in
                    SDLog("Migrating db version \(oldSchemaVersion) to 9")
                    migration.enumerate(Machine.className()) { oldObject, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerate(SyncFolder.className()) { oldObject, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
                    migration.enumerate(SyncTask.className()) { oldObject, newObject in
                        if oldSchemaVersion < 6 {
                            migration.delete(newObject!)
                        }
                    }
            })

            Realm.Configuration.defaultConfiguration = config

            autoreleasepool {
                let fileManager = NSFileManager.defaultManager()

                do {
                    try fileManager.removeItemAtURL(newdbURL)
                } catch {
                    // ignored, file may not exist at all, but if it does and we can't remove it we'll crash next and get a report
                }
                let realm = try! Realm(fileURL: dbURL)
                try! realm.writeCopyToURL(newdbURL)
                try! fileManager.removeItemAtURL(dbURL)
                try! fileManager.moveItemAtURL(newdbURL, toURL: dbURL)
            }

            self.serviceManager.deployService()
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
                self.serviceManager.loadService()
                self.serviceRouter = SDServiceXPCRouter()
            })
            self.syncScheduler = SyncScheduler.sharedSyncScheduler

            self.dropdownMenuController = DropdownController()

            self.accountWindowController = AccountWindowController()
            _ = self.accountWindowController.window!

            let markdownURL = NSBundle.mainBundle().URLForResource("Changelog.md", withExtension: nil)

            let data = NSFileManager.defaultManager().contentsAtPath(markdownURL!.path!)

            let markdown = String(data: data!, encoding: NSUTF8StringEncoding)!


            self.aboutWindowController = DCOAboutWindowController()
            self.aboutWindowController.useTextViewForAcknowledgments = true
            self.aboutWindowController.appCredits = TSMarkdownParser.standardParser().attributedStringFromMarkdown(markdown)
            let version = "Version \(self.CFBundleShortVersionString)-\(self.environment) (Build \(self.CFBundleVersion))"
            self.aboutWindowController.appVersion = version
            let websiteURLPath: String = "https://\(SDWebDomain)"
            self.aboutWindowController.appWebsiteURL = NSURL(string: websiteURLPath)!


            // register SDApplicationControlProtocol notifications
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAccountWindow(_:)), name: SDApplicationShouldOpenAccountWindow, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenPreferencesWindow(_:)), name: SDApplicationShouldOpenPreferencesWindow, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDApplicationControlProtocol.applicationShouldOpenAboutWindow(_:)), name: SDApplicationShouldOpenAboutWindow, object: nil)
            NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenAboutWindow, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.applicationShouldOpenSyncWindow(_:)), name: SDApplicationShouldOpenSyncWindow, object: nil)

            // register SDAccountProtocol notifications

            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDAccountProtocol.didSignIn(_:)), name: SDAccountSignInNotification, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDAccountProtocol.didSignOut(_:)), name: SDAccountSignOutNotification, object: nil)
        })
    }

    // MARK: SDAccountProtocol

    func didSignIn(notification: NSNotification) {
        guard let uniqueClientID = notification.object as? String else {
            return
        }
        assert(NSThread.isMainThread(), "Not main thread!!!")
        self.syncScheduler!.running = true
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
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

    func didSignOut(notification: NSNotification) {
        assert(NSThread.isMainThread(), "Not main thread!!!")
        self.syncScheduler?.stop()
        self.preferencesWindowController?.close()
        self.preferencesWindowController = nil
    }

    func didReceiveAccountDetails(notification: NSNotification) {
    }

    func didReceiveAccountStatus(notification: NSNotification) {
    }

    // MARK: CrashlyticsDelegate

    func crashlyticsDidDetectReportForLastExecution(report: CLSReport, completionHandler: (Bool) -> Void) {
        //
        // always submit the report to Crashlytics
        completionHandler(true)

        // show an alert telling the user a crash report was generated, allow them to opt out of seeing more alerts
        CrashAlert.show()

    }

}
