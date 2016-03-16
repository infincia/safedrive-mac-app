
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class DropdownController: NSObject, SDMountStateProtocol, SDVolumeEventProtocol, SDAccountProtocol {
    var statusItem: NSStatusItem?
    @IBOutlet var statusItemMenu: NSMenu!
    @IBOutlet var connectMenuItem: NSMenuItem!
    @IBOutlet var preferencesMenuItem: NSMenuItem!
    @IBOutlet var syncPreferencesMenuItem: NSMenuItem!
    
    
    private var safeDriveAPI = API.sharedAPI
    private var mountController = SDMountController.sharedAPI()
    private var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
    
    var sharedAccountController = AccountController.sharedAccountController
    
    private var menuBarImage : NSImage? {
        get {
            return self.statusItem?.image
        }
        
        set(image) {
            // needed for OS X 10.10's dark mode
            image?.template = true
            self.statusItem?.image = image
        }
    }
    
    override init() {
        super.init()
        NSBundle.mainBundle().loadNibNamed("DropdownMenu", owner: self, topLevelObjects: nil)
        // register SDMountStateProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mountStateMounted:", name: SDMountStateMountedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mountStateUnmounted:", name: SDMountStateUnmountedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mountStateDetails:", name: SDMountStateDetailsNotification, object: nil)
        // register SDVolumeEventProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "volumeDidMount:", name: SDVolumeDidMountNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "volumeDidUnmount:", name: SDVolumeDidUnmountNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "volumeShouldUnmount:", name: SDVolumeShouldUnmountNotification, object: nil)
        
        // register SDAccountProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didSignIn:", name: SDAccountSignInNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didSignOut:", name: SDAccountSignOutNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveAccountStatus:", name: SDAccountStatusNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveAccountDetails:", name: SDAccountDetailsNotification, object: nil)

    }
    
    override func awakeFromNib() {
        self.statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
        // menu loaded from SDDropdownMenu.xib
        self.statusItem?.menu = self.statusItemMenu
        // this sets the tooltip of the menu bar item using a localized string from SafeDrive.strings
        self.statusItem?.toolTip = NSLocalizedString("SafeDriveAppName", comment: "Safe Drive Application Name")
        self.menuBarImage = NSImage(named: NSImageNameLockLockedTemplate)
        self.enableMenuItems(false)
    }
    
    @IBAction func toggleMount(sender: AnyObject) {
        if self.mountController.mounted {
            self.disconnectVolume()
        }
        else {
            NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenAccountWindow, object: nil)
        }
    }
    
    @IBAction func openPreferencesWindow(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenPreferencesWindow, object: nil)
    }
    
    @IBAction func openAboutWindow(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenAboutWindow, object: nil)
    }
    
    @IBAction func openSyncWindow(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenSyncWindow, object: nil)
    }
    
    private func enableMenuItems(enabled: Bool) {
        self.preferencesMenuItem.enabled = enabled
        self.syncPreferencesMenuItem.enabled = enabled
    }
    
    private func disconnectVolume() {
        let volumeName: String = self.sharedSystemAPI.currentVolumeName
        SDLog("Dismounting volume: %@", volumeName)
        self.mountController.unmountVolumeWithName(volumeName, success: { (mountURL: NSURL?, mountError: NSError?) -> Void in
            //
        }, failure: { (mountURL: NSURL, mountError: NSError) -> Void in
            //
        })
    }
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: NSNotification) {
        self.enableMenuItems(true)
    }
    
    func didSignOut(notification: NSNotification) {
        self.enableMenuItems(false)
    }
    
    func didReceiveAccountDetails(notification: NSNotification) {
    }
    
    func didReceiveAccountStatus(notification: NSNotification) {
    }
    
    // MARK: SDVolumeEventProtocol methods

    func volumeDidMount(notification: NSNotification) {
    }
    
    func volumeDidUnmount(notification: NSNotification) {
    }
    
    func volumeSubprocessDidTerminate(notification: NSNotification) {
    }
    
    func volumeShouldUnmount(notification: NSNotification) {
        self.disconnectVolume()
    }
    
    // MARK: SDMountStateProtocol methods

    func mountStateMounted(notification: NSNotification) {
        self.connectMenuItem.title = NSLocalizedString("Disconnect", comment: "Menu title for disconnecting the volume")
        self.menuBarImage = NSImage(named: NSImageNameLockUnlockedTemplate)
    }
    
    func mountStateUnmounted(notification: NSNotification) {
        self.connectMenuItem.title = NSLocalizedString("Connect", comment: "Menu title for connecting the volume")
        self.menuBarImage = NSImage(named: NSImageNameLockLockedTemplate)
    }
    
    func mountStateDetails(notification: NSNotification) {
    
    }
}