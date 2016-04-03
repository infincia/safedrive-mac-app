
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Crashlytics

class InstallerWindowController: NSWindowController, NSOpenSavePanelDelegate {

    @IBOutlet var spinner: NSProgressIndicator!
    
    @IBOutlet var next: NSButton!
    
    private var installer = Installer()
    
    private var osxfuseIsInstalled = false
    
    private var promptedForInstall = false
    
    private var osxfuseDispatchQueue = dispatch_queue_create("io.safedrive.Installer.OSXFUSEQueue", DISPATCH_QUEUE_SERIAL);

    
    // MARK: Initializers
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init() {
        self.init(windowNibName: "InstallerWindow")
    }
    
    override func windowDidLoad() {
        self.checkDependencies()
    }

    private func checkDependencies() {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
            while !self.installer.isOSXFUSEInstalled() {
                if !self.promptedForInstall {
                    self.promptedForInstall = true
                    dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                        self.showWindow(self)
                    })
                }
                NSThread.sleepForTimeInterval(1)
            }
            dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldFinishConfiguration, object: nil)
                self.osxfuseIsInstalled = true
                self.spinner.stopAnimation(self)
                self.next.enabled = true
                self.close()
            })
        })
    }
    
    
    // MARK: UI Actions
    
    @IBAction func next(sender: AnyObject) {
        if self.osxfuseIsInstalled {
            NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldFinishConfiguration, object: nil)
        }
        else {
            self.installer.installOSXFUSE()
            self.spinner.startAnimation(self)
            self.next.enabled = false
        }
    }
    
}