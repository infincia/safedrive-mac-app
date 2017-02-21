
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import SafeDriveSDK

class DropdownController: NSObject, SDMountStateProtocol, SDVolumeEventProtocol, SDAccountProtocol {
    var statusItem: NSStatusItem?
    @IBOutlet var statusItemMenu: NSMenu!
    @IBOutlet var connectMenuItem: NSMenuItem!
    @IBOutlet var preferencesMenuItem: NSMenuItem!

    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var mountController = MountController.shared
    fileprivate var sharedSystemAPI = SDSystemAPI.shared()


    var sharedAccountController = AccountController.sharedAccountController

    fileprivate var menuBarImage: NSImage? {
        get {
            return self.statusItem?.image
        }

        set(image) {
            // needed for OS X 10.10's dark mode
            image?.isTemplate = true
            self.statusItem?.image = image
        }
    }

    override init() {
        super.init()
        Bundle.main.loadNibNamed("DropdownMenu", owner: self, topLevelObjects: nil)
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
        // register SDVolumeEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidMount), name: Notification.Name.volumeDidMount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidUnmount), name: Notification.Name.volumeDidUnmount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeShouldUnmount), name: Notification.Name.volumeShouldUnmount, object: nil)
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didAuthenticate), name: Notification.Name.accountAuthenticated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
    }
    
    override func awakeFromNib() {
        self.statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
        // menu loaded from SDDropdownMenu.xib
        self.statusItem?.menu = self.statusItemMenu
        // this sets the tooltip of the menu bar item using a localized string from SafeDrive.strings
        self.statusItem?.toolTip = NSLocalizedString("SafeDriveAppName", comment: "Safe Drive Application Name")
        self.menuBarImage = NSImage(named: NSImageNameLockLockedTemplate)
        self.enableMenuItems(false)
    }
    
    @IBAction func toggleMount(_ sender: AnyObject) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldToggleMountState, object: nil)
    }
    
    @IBAction func openPreferencesWindow(_ sender: AnyObject) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
    }
    
    @IBAction func openAboutWindow(_ sender: AnyObject) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenAboutWindow, object: nil)
    }
    
    fileprivate func enableMenuItems(_ enabled: Bool) {
        self.preferencesMenuItem.isEnabled = enabled
    }
    
    fileprivate func disconnectVolume() {
        let volumeName: String = self.sharedSystemAPI.currentVolumeName
        SDLog("Dismounting volume: %@", volumeName)
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high).async {
            self.mountController.unmountVolume(name: volumeName, success: { _ -> Void in
                //
            }, failure: { (_, error, processes) -> Void in
                DispatchQueue.main.async(execute: {() -> Void in
                    let message = "SafeDrive could not be unmounted\n\n \(error.localizedDescription)"
                    SDLog(message)
                    if let processes = processes {
                        for process in processes {
                            SDLog("process still has open files: \(process.command) (\(process.pid))")
                        }
                    }
                    let notification = NSUserNotification()

                    notification.title = "SafeDrive unmount failed"
                    notification.informativeText = NSLocalizedString("Please close any open files on your SafeDrive", comment: "")
                  
                    notification.soundName = NSUserNotificationDefaultSoundName
                    
                    NSUserNotificationCenter.default.deliver(notification)
                })
            })
        }
        
    }
    
    // MARK: SDAccountProtocol
    
    func didAuthenticate(notification: Notification) {
        self.enableMenuItems(true)
    }
    
    func didSignOut(notification: Notification) {
        self.enableMenuItems(false)
    }
    
    func didReceiveAccountDetails(notification: Notification) {
    }
    
    func didReceiveAccountStatus(notification: Notification) {
    }
    
    // MARK: SDVolumeEventProtocol methods
    
    func volumeDidMount(notification: Notification) {
    }
    
    func volumeDidUnmount(notification: Notification) {
    }
    
    func volumeSubprocessDidTerminate(notification: Notification) {
    
    }
    
    func volumeShouldMount(notification: Notification) {
        
    }
    
    func volumeShouldUnmount(notification: Notification) {
        self.disconnectVolume()
    }
    
    // MARK: SDMountStateProtocol methods
    
    func mountStateMounted(notification: Notification) {
        self.connectMenuItem.title = NSLocalizedString("Disconnect", comment: "Menu title for disconnecting the volume")
        self.menuBarImage = NSImage(named: NSImageNameLockUnlockedTemplate)
    }
    
    func mountStateUnmounted(notification: Notification) {
        self.connectMenuItem.title = NSLocalizedString("Connect", comment: "Menu title for connecting the volume")
        self.menuBarImage = NSImage(named: NSImageNameLockLockedTemplate)
    }
    
    func mountStateDetails(notification: Notification) {
        
    }
}
