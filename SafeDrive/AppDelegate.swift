
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Fabric
import Crashlytics

import RealmSwift
import Realm


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SDApplicationControlProtocol {
    private var dropdownMenuController: DropdownController!
    private var accountWindowController: SDAccountWindowController!
    private var preferencesWindowController: PreferencesWindowController!
    
    private var aboutWindowController: DCOAboutWindowController!
    private var serviceRouter: SDServiceXPCRouter!
    private var serviceManager: ServiceManager!
    private var syncManagerWindowController: SyncManagerWindowController!
    
    private var syncScheduler: SyncScheduler?
    private var installWindowController: InstallerWindowController?

    
    var CFBundleVersion = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String

    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        NSUserDefaults.standardUserDefaults().registerDefaults(["NSApplicationCrashOnExceptions": true])
        Fabric.with([Crashlytics.self])
        
        /*
        var dateFormatter: NSDateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MMM d yyyy"
        var localeUS: NSLocale = NSLocale(localeIdentifier: "en_US")
        dateFormatter.locale = localeUS
        var compileDate: NSDate = dateFormatter.dateFromString(String.stringWithUTF8String(__DATE__))
        var components: NSDateComponents = NSCalendar.currentCalendar().components(NSWeekCalendarUnit, fromDate: compileDate, toDate: NSDate(), options: 0)

        // Expired after 4 weeks
        if components.week() > 4 {
            var alert: NSAlert = NSAlert()
            alert.messageText = "This beta of SafeDrive has expired."
            alert.addButtonWithTitle("OK")
            alert.informativeText = "Please obtain a new version from safedrive.io"
            if alert.runModal() {
                NSApp.terminate(nil)
            }
        }
        else {
            var alert: NSAlert = NSAlert()
            alert.messageText = "This is a beta build of SafeDrive."
            alert.addButtonWithTitle("OK")
            var weekComponent: NSDateComponents = NSDateComponents()
            weekComponent.week = 4
            var theCalendar: NSCalendar = NSCalendar.currentCalendar()
            var expirationDate: NSDate = theCalendar.dateByAddingComponents(weekComponent, toDate: compileDate, options: 0)
            alert.informativeText = "It will expire on \(expirationDate)"
            if alert.runModal() {
                
            }
        }

        */
        
        
        
        // initialize error handler, from this point on SDLog() and SDErrorHandlerReport() should be safe to use
        SDErrorHandlerInitialize()
        SDLog("SafeDrive build \(CFBundleVersion) starting")

        
        PFMoveToApplicationsFolderIfNecessary()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldFinishLaunch:", name: SDApplicationShouldFinishLaunch, object: nil)

        self.installWindowController = InstallerWindowController()
        _ = self.installWindowController!.window!

    }

    
    func applicationWillTerminate(aNotification: NSNotification) {
        print("SafeDrive build \(CFBundleVersion), protocol version \(kSDAppXPCProtocolVersion) exiting")
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
            self.syncManagerWindowController.showWindow(nil)
        })
    }
    
    func applicationShouldFinishLaunch(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            
            guard let groupURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db") else {
                SDLog("Failed to obtain group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(groupURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                SDLog("Failed to create group container, this is a fatal error")
                Crashlytics.sharedInstance().crash()
            }
            
            let dbURL: NSURL = groupURL.URLByAppendingPathComponent("sync.realm")
            let config = Realm.Configuration(
                path: dbURL.path,
                // Set the new schema version. This must be greater than the previously used
                // version (if you've never set a schema version before, the version is 0).
                schemaVersion: 2,
                migrationBlock: { migration, oldSchemaVersion in

                    if (oldSchemaVersion < 1) {
                        // No changes, just new properties
                    }
                    if (oldSchemaVersion < 2) {
                        // No changes, just new properties
                    }
            })
            
            Realm.Configuration.defaultConfiguration = config
            
            guard let realm = try? Realm() else {
                SDLog("failed to create migrated realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            self.serviceManager = ServiceManager.sharedServiceManager
            self.serviceManager.deployService()
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
                self.serviceManager.unloadService()
                NSThread.sleepForTimeInterval(1)
                self.serviceManager.loadService()
                NSThread.sleepForTimeInterval(2)
                self.serviceRouter = SDServiceXPCRouter()
            })
            self.syncScheduler = SyncScheduler.sharedSyncScheduler
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                do {
                    try self.syncScheduler?.syncSchedulerLoop()
                }
                catch {
                    print("Error starting scheduler: \(error)")
                    Crashlytics.sharedInstance().crash()
                }
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                self.syncScheduler?.syncRunLoop()
            }
            self.dropdownMenuController = DropdownController()
            
            self.accountWindowController = SDAccountWindowController(windowNibName: "SDAccountWindow")
            _ = self.accountWindowController.window!
            
            self.preferencesWindowController = PreferencesWindowController()
            _ = self.preferencesWindowController.window!
            
            
            self.aboutWindowController = DCOAboutWindowController()
            self.aboutWindowController.useTextViewForAcknowledgments = true
            let websiteURLPath: String = "https://\(SDWebDomain)"
            self.aboutWindowController.appWebsiteURL = NSURL(string: websiteURLPath)!
            
            self.syncManagerWindowController = SyncManagerWindowController()
            _ = self.syncManagerWindowController.window!
            
            // register SDApplicationControlProtocol notifications
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenAccountWindow:", name: SDApplicationShouldOpenAccountWindow, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenPreferencesWindow:", name: SDApplicationShouldOpenPreferencesWindow, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenAboutWindow:", name: SDApplicationShouldOpenAboutWindow, object: nil)
            NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenAboutWindow, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenSyncWindow:", name: SDApplicationShouldOpenSyncWindow, object: nil)
        })
    }
    
}