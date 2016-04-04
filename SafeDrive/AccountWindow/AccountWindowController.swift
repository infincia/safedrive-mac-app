
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class AccountWindowController: NSWindowController, SDMountStateProtocol, SDVolumeEventProtocol {
   
    var safeDriveAPI = API.sharedAPI
    var mountController = SDMountController.sharedAPI()
    var sharedSystemAPI = SDSystemAPI.sharedAPI()

    var accountController = AccountController.sharedAccountController

    @IBOutlet var emailField: NSTextField!
    @IBOutlet var passwordField: NSTextField!
    @IBOutlet var volumeNameField: NSTextField!
    
    @IBOutlet var errorField: NSTextField!
    
    @IBOutlet var spinner: NSProgressIndicator!
    
    var currentlyDisplayedError: NSError?
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    convenience init() {
        self.init(windowNibName: "AccountWindow")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let window = self.window as! FlatWindow
        
        window.keepOnTop = true
        
        self.passwordField.focusRingType = .None
        
        // reset error field to empty before display
        self.resetErrorDisplay()
        
        // register SDMountStateProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted(_:)), name: SDMountStateMountedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted(_:)), name: SDMountStateUnmountedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails(_:)), name: SDMountStateDetailsNotification, object: nil)
        // register SDVolumeEventProtocol notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidMount(_:)), name: SDVolumeDidMountNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidUnmount(_:)), name: SDVolumeDidUnmountNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeShouldUnmount(_:)), name: SDVolumeShouldUnmountNotification, object: nil)
        
        if self.accountController.hasCredentials {
            // we need to sign in automatically if at all possible, even if we don't need to automount we need a session token and
            // account details in order to support sync
            self.signIn(self)
        }

    }
    
    @IBAction func signIn(sender: AnyObject) {
        self.resetErrorDisplay()
        
        let e: NSError = NSError(domain: SDErrorDomain, code: SDErrorNone, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Signing in to SafeDrive", comment: "String informing the user that they are being signed in to SafeDrive")])
        
        
        self.displayError(e, forDuration: 120)
        self.spinner.startAnimation(self)

        self.accountController.signInWithSuccess({() -> Void in
            NSNotificationCenter.defaultCenter().postNotificationName(SDAccountSignInNotification, object: nil)
            self.resetErrorDisplay()
            self.spinner.stopAnimation(self)
            
            // only mount SSHFS automatically if the user set it to automount or clicked the button, in which case sender will
            // be the NSButton in the account window labeled "next"

            if self.sharedSystemAPI.mountAtLaunch || sender is NSButton {
                let mountURL: NSURL = self.mountController.getMountURLForVolumeName(self.sharedSystemAPI.currentVolumeName)
                if !self.sharedSystemAPI.checkForMountedVolume(mountURL) {
                    self.showWindow(nil)
                    self.connectVolume()
                }
            }
        }, failure: {(apiError: NSError) -> Void in
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
        let volumeName: String = NSUserDefaults.standardUserDefaults().objectForKey(SDCurrentVolumeNameKey) as? String ?? SDDefaultVolumeName

        let urlComponents = NSURLComponents()
        urlComponents.user = self.accountController.internalUserName
        urlComponents.host = self.accountController.remoteHost
        urlComponents.path = SDDefaultServerPath
        urlComponents.port = self.accountController.remotePort
        let sshURL: NSURL = urlComponents.URL!

        self.mountController.startMountTaskWithVolumeName(volumeName, sshURL: sshURL, success: { (mountURL, error) in
            /*
             now check for a successful mount. if after 30 seconds there is no volume
             mounted, it is a fair bet that an error occurred in the meantime
             */
            
            self.sharedSystemAPI.checkForMountedVolume(mountURL, withTimeout: 30, success: {() -> Void in
                NSNotificationCenter.defaultCenter().postNotificationName(SDVolumeDidMountNotification, object: nil)
                self.resetErrorDisplay()
                self.spinner.stopAnimation(self)
                self.mountController.mounting = false
                }, failure: {(error) -> Void in
                    SDLog("SafeDrive checkForMountedVolume  failure in account window")
                    self.displayError(error, forDuration: 10)
                    self.spinner.stopAnimation(self)
                    self.mountController.mounting = false
            })

            
        }, failure: { (url, mountError) in
            SDLog("SafeDrive startMountTaskWithVolumeName failure in account window")
            SDErrorHandlerReport(mountError)
            self.displayError(mountError, forDuration: 10)
            self.spinner.stopAnimation(self)
            self.mountController.mounting = false
            // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
            self.mountController.unmountVolumeWithName(volumeName, success: { (mountURL, mountError) in
                //
            }, failure: { (mountURL, mountError) in
                //
            })
        })
    }
    
    // MARK: Error display
    
    func resetErrorDisplay() {
        self.currentlyDisplayedError = nil
        self.errorField.stringValue = ""
    }
    
    func displayError(error: NSError, forDuration duration: NSTimeInterval) {
        assert(NSThread.isMainThread(), "Error display called on background thread")
        self.currentlyDisplayedError = error
        NSApp.activateIgnoringOtherApps(true)
        self.errorField.stringValue = error.localizedDescription
        let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
        let fadedBlue: NSColor = NSColor(calibratedRed: 0.25098, green: 0.25098, blue: 1.0, alpha: 0.73)
        if error.code > 0 {
            self.errorField.textColor = fadedRed
        }
        else {
            self.errorField.textColor = fadedBlue
        }
        weak var weakSelf: AccountWindowController? = self
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(duration) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {() -> Void in
            if self.currentlyDisplayedError == error {
                weakSelf?.resetErrorDisplay()
            }
        })
    }
    
    // MARK: SDVolumeEventProtocol methods

    
    func volumeDidMount(notification: NSNotification) {
        self.close()
        NSWorkspace.sharedWorkspace().openURL(self.mountController.mountURL)
        //var mountSuccess: NSError = NSError(domain: SDErrorDomain, code: SDErrorNone, userInfo: [NSLocalizedDescriptionKey: "Volume mounted"])
        //self.displayError(mountSuccess, forDuration: 10)

    }
    
    func volumeDidUnmount(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenAccountWindow, object: nil)
    }
    
    func volumeSubprocessDidTerminate(notification: NSNotification) {
    }
    
    func volumeShouldUnmount(notification: NSNotification) {
    }
    
    // MARK: SDMountStateProtocol methods

    
    func mountStateMounted(notification: NSNotification) {
    }
    
    func mountStateUnmounted(notification: NSNotification) {
    }
    
    func mountStateDetails(notification: NSNotification) {
    }
}
