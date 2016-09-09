
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Crashlytics
import Realm
import RealmSwift

class WelcomeWindowController: NSWindowController, NSOpenSavePanelDelegate, InstallerDelegate {

    @IBOutlet var spinner: NSProgressIndicator!

    @IBOutlet var next: NSButton!

    private var installer: Installer!

    private var osxfuseIsInstalled = false

    private var osxfuseDispatchQueue = dispatch_queue_create("io.safedrive.Installer.OSXFUSEQueue", DISPATCH_QUEUE_SERIAL)


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

    @IBAction func next(sender: AnyObject) {
        if self.installer.isOSXFUSEInstalled() {
            NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldFinishConfiguration, object: nil)
        } else {
            self.installer.installOSXFUSE()
            self.spinner.startAnimation(self)
            self.next.enabled = false
        }
    }

    // MARK: Installer Delegate
    
    func needsDependencies() {
        self.showWindow(self)
    }
    
    func didValidateDependencies() {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldFinishConfiguration, object: nil)
        self.spinner.stopAnimation(self)
        self.next.enabled = true
        self.close()
    }
}
