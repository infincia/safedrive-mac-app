
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Crashlytics

class InstallerWindowController: NSWindowController, NSOpenSavePanelDelegate {

    @IBOutlet var spinner: NSProgressIndicator!
    
    private var installer = Installer()
    
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
        
    }
    
    // MARK: UI Actions
    
    @IBAction func installDependencies(sender: AnyObject) {
   
    }
    
    
}