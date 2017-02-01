
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Cocoa

import SafeDriveSDK

class AccountWindowController: NSWindowController, SDMountStateProtocol, SDVolumeEventProtocol {
    
    var sdk = SafeDriveSDK.sharedSDK
    var mountController = MountController.shared
    var sharedSystemAPI = SDSystemAPI.shared()
    
    var accountController = AccountController.sharedAccountController
    
    @IBOutlet var emailField: NSTextField!
    @IBOutlet var passwordField: NSTextField!
    @IBOutlet var volumeNameField: NSTextField!
    
    @IBOutlet var errorField: NSTextField!
    
    @IBOutlet var spinner: NSProgressIndicator!
    
    var currentlyDisplayedError: NSError?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init() {
        self.init(windowNibName: "AccountWindow")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let window = self.window as! FlatWindow
        
        window.keepOnTop = true
        
        self.passwordField.focusRingType = .none
        
        // reset error field to empty before display
        self.resetErrorDisplay()
        
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted(_:)), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted(_:)), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails(_:)), name: Notification.Name.mountDetails, object: nil)
        // register SDVolumeEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidMount(_:)), name: Notification.Name.volumeDidMount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidUnmount(_:)), name: Notification.Name.volumeDidUnmount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeShouldUnmount(_:)), name: Notification.Name.volumeShouldUnmount, object: nil)
    }
    
    @IBAction func signIn(_ sender: AnyObject) {
        self.resetErrorDisplay()
        
        let e: NSError = NSError(domain: SDErrorDomain, code: SDErrorNone, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Signing in to SafeDrive", comment: "String informing the user that they are being signed in to SafeDrive")])
        
        
        self.displayError(e, forDuration: 120)
        self.spinner.startAnimation(self)
        
        self.accountController.signInWithSuccess({() -> Void in
            NotificationCenter.default.post(name: Notification.Name.accountAuthenticated, object: nil)
            self.resetErrorDisplay()
            self.spinner.stopAnimation(self)
            
            // only mount SSHFS automatically if the user set it to automount or clicked the button, in which case sender will
            // be the NSButton in the account window labeled "next"
            
            if self.sharedSystemAPI.mountAtLaunch || sender is NSButton {
                let mountURL = self.mountController.mountURL(forVolumeName: self.sharedSystemAPI.currentVolumeName)
                if !self.sharedSystemAPI.check(forMountedVolume: mountURL) {
                    self.showWindow(nil)
                    self.connectVolume()
                }
            }
        }, failure: {(apiError: Swift.Error) -> Void in
            SDErrorHandlerReport(apiError)
            self.displayError(apiError, forDuration: 10)
            self.spinner.stopAnimation(self)
            self.showWindow(nil)
        })
    }
    
    // MARK: Internal API
    
    func connectVolume() {
        self.resetErrorDisplay()
        self.mountController.mounting = true
        let displayMessage = NSError(domain: SDErrorDomain, code: SDErrorNone, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Mounting SafeDrive", comment: "String informing the user their safedrive is being mounted")])
        self.displayError(displayMessage, forDuration: 120)
        self.spinner.startAnimation(self)
        let volumeName: String = UserDefaults.standard.object(forKey: SDCurrentVolumeNameKey) as? String ?? SDDefaultVolumeName
        
        var urlComponents = URLComponents()
        urlComponents.user = self.accountController.internalUserName
        urlComponents.host = self.accountController.remoteHost
        urlComponents.path = SDDefaultServerPath
        urlComponents.port = Int(self.accountController.remotePort!)
        let sshURL: URL = urlComponents.url!
        
        self.mountController.startMountTask(volumeName: volumeName, sshURL: sshURL, success: { mountURL in
            
            /*
             now check for a successful mount. if after 30 seconds there is no volume
             mounted, it is a fair bet that an error occurred in the meantime
             */
            
            self.sharedSystemAPI.check(forMountedVolume: mountURL, withTimeout: 30, success: {() -> Void in
                NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
                self.resetErrorDisplay()
                self.spinner.stopAnimation(self)
                self.mountController.mounting = false
            }, failure: {(error) -> Void in
                SDLog("SafeDrive checkForMountedVolume  failure in account window")
                self.displayError(error as NSError, forDuration: 10)
                self.spinner.stopAnimation(self)
                self.mountController.mounting = false
            })
            
            
        }, failure: { (_, mountError) in
            SDLog("SafeDrive startMountTaskWithVolumeName failure in account window")
            SDErrorHandlerReport(mountError)
            self.displayError(mountError as NSError, forDuration: 10)
            self.spinner.stopAnimation(self)
            self.mountController.mounting = false
            // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
            self.mountController.unmountVolume(name: volumeName, success: { _ in
                //
            }, failure: { (_, _) in
                //
            })
        })
    }
    
    // MARK: Error display
    
    func resetErrorDisplay() {
        self.currentlyDisplayedError = nil
        self.errorField.stringValue = ""
    }
    
    func displayError(_ error: Swift.Error, forDuration duration: TimeInterval) {
        assert(Thread.isMainThread, "Error display called on background thread")
        self.currentlyDisplayedError = error as NSError
        NSApp.activate(ignoringOtherApps: true)
        self.errorField.stringValue = error.localizedDescription
        let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
        let fadedBlue: NSColor = NSColor(calibratedRed: 0.25098, green: 0.25098, blue: 1.0, alpha: 0.73)
        if error._code > 0 {
            self.errorField.textColor = fadedRed
        } else {
            self.errorField.textColor = fadedBlue
        }
        weak var weakSelf: AccountWindowController? = self
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(duration) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {() -> Void in
            if self.currentlyDisplayedError == error as NSError {
                weakSelf?.resetErrorDisplay()
            }
        })
    }
    
    // MARK: SDVolumeEventProtocol methods
    
    
    func volumeDidMount(_ notification: Notification) {
        self.close()
        NSWorkspace.shared().open((self.mountController.mountURL)!)
        //var mountSuccess: NSError = NSError(domain: SDErrorDomain, code: SDErrorNone, userInfo: [NSLocalizedDescriptionKey: "Volume mounted"])
        //self.displayError(mountSuccess, forDuration: 10)
        
    }
    
    func volumeDidUnmount(_ notification: Notification) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenAccountWindow, object: nil)
    }
    
    func volumeSubprocessDidTerminate(_ notification: Notification) {
    }
    
    func volumeShouldUnmount(_ notification: Notification) {
    }
    
    // MARK: SDMountStateProtocol methods
    
    
    func mountStateMounted(_ notification: Notification) {
    }
    
    func mountStateUnmounted(_ notification: Notification) {
    }
    
    func mountStateDetails(_ notification: Notification) {
    }
}
