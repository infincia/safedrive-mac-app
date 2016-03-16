
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Cocoa

class PreferencesWindowController: NSWindowController, SDMountStateProtocol, SDAccountProtocol, SDServiceStatusProtocol  {
    
    var sharedSystemAPI = SDSystemAPI.sharedAPI()
    private var sharedServiceManager = ServiceManager.sharedServiceManager
    
    @IBOutlet var tabView: NSTabView!
    
    // MARK: Tab selections
    @IBOutlet var generalButton: NSButton!
    @IBOutlet var accountButton: NSButton!
    @IBOutlet var bandwidthButton: NSButton!
    @IBOutlet var statusButton: NSButton!
    
    // MARK: General Tab
    
    // MARK: Account tab
    @IBOutlet var assignedStorageField: NSTextField!
    @IBOutlet var usedStorageField: NSTextField!
    @IBOutlet var availableStorageField: NSTextField!

    @IBOutlet var accountStatusField: NSTextField!
    @IBOutlet var accountExpirationField: NSTextField!
    
    // MARK: Bandwidth Tab
    
    // MARK: Status Tab
    @IBOutlet var serviceStatusField: NSTextField!
    @IBOutlet var mountStatusField: NSTextField!
    @IBOutlet var volumeSizeField: NSTextField!
    
    @IBOutlet var volumeFreespaceField: NSTextField!
    
    @IBOutlet var volumeUsageBar: NSProgressIndicator!
    
    var autostart: Bool {
        get {
            return self.sharedSystemAPI.autostart()
        }
        set(newValue) {
            var autostartError: NSError?
            if newValue == true {
                autostartError = self.sharedSystemAPI.enableAutostart()
            }
            else {
                autostartError = self.sharedSystemAPI.disableAutostart()
            }
            if (autostartError != nil) {
                SDErrorHandlerReport(autostartError)
            }
        }
    }
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindow")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.level = Int(CGWindowLevelForKey(CGWindowLevelKey.StatusWindowLevelKey))

        self.window?.backgroundColor = NSColor.whiteColor()
        
        let aWindow: INAppStoreWindow = self.window as! INAppStoreWindow
        aWindow.titleBarHeight = 24.0
        aWindow.showsBaselineSeparator = false
        let topColor: NSColor = NSColor.whiteColor()
        aWindow.titleBarStartColor = topColor
        aWindow.titleBarEndColor = topColor
        aWindow.baselineSeparatorColor = topColor
        aWindow.inactiveTitleBarEndColor = topColor
        aWindow.inactiveTitleBarStartColor = topColor
        aWindow.inactiveBaselineSeparatorColor = topColor
        

        
        // register SDVolumeEventProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "volumeDidMount:", name: SDVolumeDidMountNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "volumeDidUnmount:", name: SDVolumeDidUnmountNotification, object: nil)
        // register SDMountStateProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mountStateMounted:", name: SDMountStateMountedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mountStateUnmounted:", name: SDMountStateUnmountedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mountStateDetails:", name: SDMountStateDetailsNotification, object: nil)

    
        // register SDAccountProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didSignIn:", name: SDAccountSignInNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveAccountStatus:", name: SDAccountStatusNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveAccountDetails:", name: SDAccountDetailsNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveServiceStatus:", name: SDServiceStatusNotification, object: nil)

        
    }

    @IBAction func selectTab(sender: AnyObject) {
        if let button = sender as? NSButton {
            self.tabView.selectTabViewItemAtIndex(button.tag)
            self.resetButtons()
            //button.highlighted = true
        }
    }
    
    private func resetButtons() {
        //self.generalButton.highlighted = false
        //self.accountButton.highlighted = false
        //self.bandwidthButton.highlighted = false
        //self.statusButton.highlighted = false
    }
    
    
    // MARK: SDMountStatusProtocol
    
    func volumeDidMount(notification: NSNotification) {
    }
    
    func volumeDidUnmount(notification: NSNotification) {
    }
    
    func mountSubprocessDidTerminate(notification: NSNotification) {
    }
    
    // MARK: SDMountStateProtocol
    
    func mountStateMounted(notification: NSNotification) {
        self.mountStatusField.stringValue = NSLocalizedString("Mounted", comment: "String for volume mount status of mounted")
    }
    
    func mountStateUnmounted(notification: NSNotification) {
        self.mountStatusField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of unmounted")
    }
    
    func mountStateDetails(notification: NSNotification) {
        if let mountDetails = notification.object as? [String: AnyObject],
               volumeTotalSpace = mountDetails[NSFileSystemSize] as? Int,
               volumeFreeSpace = mountDetails[NSFileSystemFreeSize] as? Int {
            self.volumeSizeField.stringValue = NSByteCountFormatter.stringFromByteCount(Int64(volumeTotalSpace), countStyle: .File)
            self.volumeFreespaceField.stringValue = NSByteCountFormatter.stringFromByteCount(Int64(volumeFreeSpace), countStyle: .File)
            let volumeUsedSpace = volumeTotalSpace - volumeFreeSpace
            self.volumeUsageBar.maxValue = Double(volumeTotalSpace)
            self.volumeUsageBar.minValue = 0
            self.volumeUsageBar.doubleValue = Double(volumeUsedSpace)
                
        }
        else {
            self.volumeSizeField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of mounted")
            self.volumeFreespaceField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of unmounted")
            self.volumeUsageBar.maxValue = 1
            self.volumeUsageBar.minValue = 0
            self.volumeUsageBar.doubleValue = 0
        }
    }
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: NSNotification) {
        
    }
    
    func didSignOut(notification: NSNotification) {
        
    }
    
    func didReceiveAccountStatus(notification: NSNotification) {
        if let accountStatus = notification.object as? [String: AnyObject],
               status = accountStatus["status"] as? String {
            self.accountStatusField.stringValue = status.capitalizedString
        }
        else {
            self.accountStatusField.stringValue = NSLocalizedString("Unknown", comment:"")

        }
    }
    
    func didReceiveAccountDetails(notification: NSNotification) {
        if let accountDetails = notification.object as? [String: AnyObject],
               assignedStorage = accountDetails["assignedStorage"] as? Int,
               usedStorage = accountDetails["usedStorage"] as? Int,
               expirationDate = accountDetails["expirationDate"] as? Double {
                self.assignedStorageField.stringValue = NSByteCountFormatter.stringFromByteCount(Int64(assignedStorage), countStyle: .File)
                self.usedStorageField.stringValue = NSByteCountFormatter.stringFromByteCount(Int64(usedStorage), countStyle: .File)
                
                let date: NSDate = NSDate(timeIntervalSince1970: expirationDate / 1000)
                let dateFormatter: NSDateFormatter = NSDateFormatter()
                dateFormatter.locale = NSLocale.currentLocale()
                dateFormatter.timeStyle = .NoStyle
                dateFormatter.dateStyle = .ShortStyle
                self.accountExpirationField.stringValue = dateFormatter.stringFromDate(date)
        }
        else {
            SDLog("Validation failed: didReceiveAccountDetails")
        }
    }
 
    // MARK: SDServiceStatusProtocol
    
    func didReceiveServiceStatus(notification: NSNotification) {
        if let status = notification.object as? Int {
            self.serviceStatusField.stringValue = status == 1 ? "Running" : "Stopped"
        }
        else {
            SDLog("Validation failed: didReceiveServiceStatus")
        }
    }
}
