
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
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted(_:)), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted(_:)), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails(_:)), name: Notification.Name.mountDetails, object: nil)
        // register SDVolumeEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidMount(_:)), name: Notification.Name.volumeDidMount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidUnmount(_:)), name: Notification.Name.volumeDidUnmount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeShouldUnmount(_:)), name: Notification.Name.volumeShouldUnmount, object: nil)
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didAuthenticate(_:)), name: Notification.Name.accountAuthenticated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut(_:)), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus(_:)), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails(_:)), name: Notification.Name.accountDetails, object: nil)
        
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
        if self.mountController.mounted {
            self.disconnectVolume()
        } else {
            NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenAccountWindow, object: nil)
        }
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
            }, failure: { (_, error) -> Void in
                DispatchQueue.main.async(execute: {() -> Void in
                    let message = "SafeDrive could not be unmounted\n\n \(error.localizedDescription)"
                    SDLog(message)
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
    
    func didAuthenticate(_ notification: Notification) {
        self.enableMenuItems(true)
    }
    
    func didSignOut(_ notification: Notification) {
        self.enableMenuItems(false)
    }
    
    func didReceiveAccountDetails(_ notification: Notification) {
    }
    
    func didReceiveAccountStatus(_ notification: Notification) {
    }
    
    // MARK: SDVolumeEventProtocol methods
    
    func volumeDidMount(_ notification: Notification) {
    }
    
    func volumeDidUnmount(_ notification: Notification) {
    }
    
    func volumeSubprocessDidTerminate(_ notification: Notification) {
    }
    
    func volumeShouldUnmount(_ notification: Notification) {
        self.disconnectVolume()
    }
    
    // MARK: SDMountStateProtocol methods
    
    func mountStateMounted(_ notification: Notification) {
        self.connectMenuItem.title = NSLocalizedString("Disconnect", comment: "Menu title for disconnecting the volume")
        self.menuBarImage = NSImage(named: NSImageNameLockUnlockedTemplate)
    }
    
    func mountStateUnmounted(_ notification: Notification) {
        self.connectMenuItem.title = NSLocalizedString("Connect", comment: "Menu title for connecting the volume")
        self.menuBarImage = NSImage(named: NSImageNameLockLockedTemplate)
    }
    
    func mountStateDetails(_ notification: Notification) {
        
    }
}
