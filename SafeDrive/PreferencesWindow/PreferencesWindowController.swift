
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable type_body_length
// swiftlint:disable file_length

import Cocoa

import Crashlytics

import Realm
import RealmSwift

import SafeDriveSDK

enum ViewType: Int {
    case general
    case account
    case sync
    case encryption
    case status
}


class PreferencesWindowController: NSWindowController, NSPopoverDelegate {

    fileprivate var sdk = SafeDriveSDK.sharedSDK

    fileprivate var sharedServiceManager = ServiceManager.sharedServiceManager
    
    
    // ********************************************************
    // MARK: View management
    
    @IBOutlet var containerView: NSView!
    
    var generalViewController: GeneralViewController!
    var accountViewController: AccountViewController!
    var syncViewController: SyncViewController!
    var encryptionViewController: EncryptionViewController!
    var statusViewController: StatusViewController!
    
    // MARK: Tab selections
    @IBOutlet var generalButton: NSButton!
    @IBOutlet var accountButton: NSButton!
    @IBOutlet var encryptionButton: NSButton!
    @IBOutlet var statusButton: NSButton!
    @IBOutlet var syncButton: NSButton!
    
    // Initialization
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindow")
        self.generalViewController = GeneralViewController()
        self.accountViewController = AccountViewController()
        self.syncViewController = SyncViewController()
        self.encryptionViewController = EncryptionViewController()
        self.statusViewController = StatusViewController()
        
        let _ = self.generalViewController.view
        let _ = self.accountViewController.view
        let _ = self.syncViewController.view
        let _ = self.encryptionViewController.view
        let _ = self.statusViewController.view
    }
    
    // Window handling
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.setTab(0)        
    }
    
    @IBAction func selectTab(_ sender: AnyObject) {
        
        if let button = sender as? NSButton {
            setTab(button.tag)
        }
    }
    
    func setTab(_ index: NSInteger) {
        guard let newViewController = viewControllerForIndex(index) else {
            return
        }
        for view in containerView.subviews {
            view.removeFromSuperview()
        }
        containerView.addSubview(newViewController.view)
        self.resetButtons()
        //button.highlighted = true
        
    }
    
    fileprivate func resetButtons() {
        //self.generalButton.highlighted = false
        //self.accountButton.highlighted = false
        //self.encryptionButton.highlighted = false
        //self.statusButton.highlighted = false
    }
    
    fileprivate func viewControllerForIndex(_ index: Int) -> NSViewController? {
        guard let viewType = ViewType(rawValue: index) else {
            return nil
        }
        switch viewType {
        case .general:
            return generalViewController
        case .account:
            return accountViewController
        case .encryption:
            return encryptionViewController
        case .status:
            return statusViewController
        case .sync:
            return syncViewController
        }
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: Any) -> Bool {
        return true
    }
}
