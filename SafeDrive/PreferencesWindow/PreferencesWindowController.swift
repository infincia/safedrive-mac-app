
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

enum Tab: Int {
    case general
    case account
    case sync
    case encryption
    case status
}

protocol PreferencesViewDelegate: class {
    func setTab(_ tab: Tab)
    func showModalWindow(_ window: NSWindow, completionHandler handler: @escaping ((NSModalResponse) -> Void))
    func dismissModalWindow(_ window: NSWindow)
    func showAlert(_ alert: NSAlert, completionHandler handler: @escaping ((NSModalResponse) -> Void))
}


class PreferencesWindowController: NSWindowController, NSPopoverDelegate {

    fileprivate var sdk = SafeDriveSDK.sharedSDK

    fileprivate var sharedServiceManager = ServiceManager.sharedServiceManager
    
    
    // ********************************************************
    // MARK: View management
    
    @IBOutlet fileprivate var containerView: NSView!
    
    var generalViewController: GeneralViewController!
    var accountViewController: AccountViewController!
    var syncViewController: SyncViewController!
    var encryptionViewController: EncryptionViewController!
    var statusViewController: StatusViewController!
    
    // MARK: Tab selections
    @IBOutlet fileprivate var generalButton: NSButton!
    @IBOutlet fileprivate var accountButton: NSButton!
    @IBOutlet fileprivate var encryptionButton: NSButton!
    @IBOutlet fileprivate var statusButton: NSButton!
    @IBOutlet fileprivate var syncButton: NSButton!
    
    // Initialization
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindow")
        self.generalViewController = GeneralViewController(delegate: self)
        self.accountViewController = AccountViewController(delegate: self)
        self.syncViewController = SyncViewController(delegate: self)
        self.encryptionViewController = EncryptionViewController(delegate: self)
        self.statusViewController = StatusViewController(delegate: self)
        
        let _ = self.generalViewController.view
        let _ = self.accountViewController.view
        let _ = self.syncViewController.view
        let _ = self.encryptionViewController.view
        let _ = self.statusViewController.view
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
    }
    
    // Window handling
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.setTab(Tab.general)
    }
    
    @IBAction func selectTab(_ sender: AnyObject) {
        
        if let button = sender as? NSButton {
            guard let tab = Tab(rawValue: button.tag) else {
                return
            }
            setTab(tab)
        }
    }
    
    fileprivate func resetButtons() {
        //self.generalButton.highlighted = false
        //self.accountButton.highlighted = false
        //self.encryptionButton.highlighted = false
        //self.statusButton.highlighted = false
    }
    
    fileprivate func viewControllerForTab(_ tab: Tab) -> NSViewController? {
        switch tab {
        case .general:
            return generalViewController
        case .account:
            return accountViewController
        case .sync:
            return syncViewController
        case .encryption:
            return encryptionViewController
        case .status:
            return statusViewController
        }
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: Any) -> Bool {
        return true
    }
}

extension PreferencesWindowController: SDAccountProtocol {
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")
        self.setTab(Tab.general)
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")
        self.setTab(Tab.general)
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")
    }
    
    func didLoadRecoveryPhrase(notification: Notification) {
        assert(Thread.current == Thread.main, "didLoadRecoveryPhrase called on background thread")
        
    }
    
    func didRequireRecoveryPhrase(notification: Notification) {
        assert(Thread.current == Thread.main, "didRequireRecoveryPhrase called on background thread")
        self.setTab(Tab.encryption)
    }
}

// swiftlint:disable force_unwrapping

extension PreferencesWindowController: PreferencesViewDelegate {
    func setTab(_ tab: Tab) {
        guard let newViewController = viewControllerForTab(tab) else {
            return
        }
        for view in containerView.subviews {
            view.removeFromSuperview()
        }
        containerView.addSubview(newViewController.view)
        self.resetButtons()
        //button.highlighted = true
        
    }
    
    func showModalWindow(_ window: NSWindow, completionHandler handler: @escaping ((NSModalResponse) -> Void)) {
        self.window!.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window!.beginSheet(window, completionHandler: handler)
    }
    

    func dismissModalWindow(_ window: NSWindow) {
        self.window!.endSheet(window)
    }
    
    func showAlert(_ alert: NSAlert, completionHandler handler: @escaping ((NSModalResponse) -> Void)) {
        self.window!.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        
        alert.beginSheetModal(for: self.window!, completionHandler: handler)
    }
}
// swiftlint:enable force_unwrapping
