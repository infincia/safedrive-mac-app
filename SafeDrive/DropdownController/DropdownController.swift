
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa


class DropdownController: NSObject {
    fileprivate var statusItem: NSStatusItem?
    @IBOutlet fileprivate var statusItemMenu: NSMenu!
    @IBOutlet fileprivate var toggleMenuItem: NSMenuItem!
    @IBOutlet fileprivate var preferencesMenuItem: NSMenuItem!
    @IBOutlet fileprivate var forceToggleMenuItem: NSMenuItem!

    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var mounted = false

    @objc
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
        Bundle.main.loadNibNamed(NSNib.Name("DropdownMenu"), owner: self, topLevelObjects: nil)
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // menu loaded from SDDropdownMenu.xib
        self.statusItem?.menu = self.statusItemMenu
        
        let mask = NSEvent.ModifierFlags.shift

        self.forceToggleMenuItem.keyEquivalentModifierMask = mask
        self.forceToggleMenuItem.isAlternate = true

        // this sets the tooltip of the menu bar item using a localized string from SafeDrive.strings
        self.statusItem?.toolTip = NSLocalizedString("SafeDriveAppName", comment: "Safe Drive Application Name")
        self.menuBarImage = NSImage(named: NSImage.Name.lockLockedTemplate)
        self.enableMenuItems(false)
    }
    
    @IBAction func toggleMount(_ sender: AnyObject) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldToggleMountState, object: nil)
    }
    
    @IBAction func forceToggleMount(_ sender: AnyObject) {
        if self.mounted {
            let driveURL = MountController.shared.currentMountURL
            ServiceManager.sharedServiceManager.forceUnmountSafeDrive(driveURL.path, {
                NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object: nil)
            }, { (error) in
                let notification = NSUserNotification()
                
                notification.identifier = "drive-force-unmount-failed"
                
                notification.title = "SafeDrive force unmount failed"
                
                notification.informativeText = error.localizedDescription
                
                notification.soundName = NSUserNotificationDefaultSoundName
                
                NSUserNotificationCenter.default.deliver(notification)
            })
        } else {
           NotificationCenter.default.post(name: Notification.Name.applicationShouldToggleMountState, object: nil)
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
        self.toggleMenuItem.isEnabled = enabled
        self.forceToggleMenuItem.isEnabled = enabled
    }
}

extension DropdownController: SDAccountProtocol {
    
    func didSignIn(notification: Notification) {
        self.enableMenuItems(true)
    }
    
    func didSignOut(notification: Notification) {
        self.enableMenuItems(false)
    }
    
    func didReceiveAccountDetails(notification: Notification) {
    }
    
    func didReceiveAccountStatus(notification: Notification) {
    }
    
}

extension DropdownController: SDMountStateProtocol {
    
    func mountStateMounted(notification: Notification) {
        self.mounted = true
        self.toggleMenuItem.title = NSLocalizedString("Disconnect", comment: "Menu title for disconnecting the volume")
        self.forceToggleMenuItem.title = NSLocalizedString("Force Disconnect", comment: "Menu title for forcefully disconnecting the volume")
        self.menuBarImage = NSImage(named: NSImage.Name.lockUnlockedTemplate)
    }
    
    func mountStateUnmounted(notification: Notification) {
        self.mounted = false
        self.toggleMenuItem.title = NSLocalizedString("Connect", comment: "Menu title for connecting the volume")
        self.forceToggleMenuItem.title = NSLocalizedString("Force Connect", comment: "Menu title for forcefully connecting the volume")
        self.menuBarImage = NSImage(named: NSImage.Name.lockLockedTemplate)
    }
    
    func mountStateDetails(notification: Notification) {
        
    }
}

extension DropdownController: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let _ = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in DropdownController")
            
            return
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let _ = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in DropdownController")
            
            return
        }
    }
}
