
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Cocoa

import Crashlytics
import Realm
import RealmSwift

class WelcomeWindowController: NSWindowController, NSOpenSavePanelDelegate, InstallerDelegate {
    
    @IBOutlet var spinner: NSProgressIndicator!
    
    @IBOutlet var next: NSButton!
    
    fileprivate var installer: Installer!
    
    fileprivate var osxfuseIsInstalled = false
    
    fileprivate var osxfuseDispatchQueue = DispatchQueue(label: "io.safedrive.Installer.OSXFUSEQueue", attributes: [])
    
    
    // MARK: Initializers
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init() {
        self.init(windowNibName: "WelcomeWindow")
    }
    
    override func windowDidLoad() {
        
        let window = self.window as! FlatWindow
        
        window.keepOnTop = true
        
        self.installer = Installer(delegate: self)
        
        self.installer.checkRequirements()
    }
    
    
    // MARK: UI Actions
    
    @IBAction func next(_ sender: AnyObject) {
        if self.installer.isOSXFUSEInstalled() {
            NotificationCenter.default.post(name: Notification.Name.applicationShouldFinishConfiguration, object: nil)
        } else {
            self.installer.installOSXFUSE()
            self.spinner.startAnimation(self)
            self.next.isEnabled = false
        }
    }
    
    // MARK: Installer Delegate
    
    func needsDependencies() {
        self.showWindow(self)
    }
    
    func didValidateDependencies() {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldFinishConfiguration, object: nil)
        self.spinner.stopAnimation(self)
        self.next.isEnabled = true
        self.close()
    }
}
