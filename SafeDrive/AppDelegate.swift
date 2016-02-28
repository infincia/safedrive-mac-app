
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Cocoa

import Fabric
import Crashlytics


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SDApplicationControlProtocol {
    private var dropdownMenuController: SDDropdownMenuController!
    private var accountWindowController: SDAccountWindowController!
    private var preferencesWindowController: SDPreferencesWindowController!
    
    private var aboutWindowController: DCOAboutWindowController!
    private var serviceRouter: SDServiceXPCRouter!
    private var serviceManager: SDServiceManager!
    private var syncManagerWindowController: SyncManagerWindowController!
    
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
        
        
        PFMoveToApplicationsFolderIfNecessary()
        self.serviceManager = SDServiceManager.sharedServiceManager()
        self.serviceManager.deployService()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
            self.serviceManager.unloadService()
            NSThread.sleepForTimeInterval(1)
            self.serviceManager.loadService()
            NSThread.sleepForTimeInterval(2)
            self.serviceRouter = SDServiceXPCRouter()
        })
        
        self.dropdownMenuController = SDDropdownMenuController()
        
        self.accountWindowController = SDAccountWindowController(windowNibName: "SDAccountWindow")
        _ = self.accountWindowController.window!
        
        self.preferencesWindowController = SDPreferencesWindowController(windowNibName: "SDPreferencesWindow")
        _ = self.preferencesWindowController.window!
        
    
        //self.aboutWindowController =
        //self.aboutWindowController.useTextViewForAcknowledgments = true
        //var websiteURLPath: String = "https://\(SDWebDomain)"
        //self.aboutWindowController.appWebsiteURL = NSURL(string: websiteURLPath)!
        
        self.syncManagerWindowController = SyncManagerWindowController()
        _ = syncManagerWindowController.window!

        // register SDApplicationControlProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenAccountWindow:", name: SDApplicationShouldOpenAccountWindow, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenPreferencesWindow:", name: SDApplicationShouldOpenPreferencesWindow, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenAboutWindow:", name: SDApplicationShouldOpenAboutWindow, object: nil)
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenAboutWindow, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationShouldOpenSyncWindow:", name: SDApplicationShouldOpenSyncWindow, object: nil)

        
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
            //self.aboutWindowController.showWindow(nil)
        })
    }
    
    func applicationShouldOpenSyncWindow(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {() -> Void in
            NSApp.activateIgnoringOtherApps(true)
            self.syncManagerWindowController.showWindow(nil)
        })
    }
    
}