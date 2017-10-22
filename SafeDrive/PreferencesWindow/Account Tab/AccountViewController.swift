
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class AccountViewController: NSViewController {
    
    @IBOutlet fileprivate var assignedStorageField: NSTextField!
    @IBOutlet fileprivate var usedStorageField: NSTextField!
    @IBOutlet fileprivate var availableStorageField: NSTextField!
    
    @IBOutlet fileprivate var accountStatusField: NSTextField!
    @IBOutlet fileprivate var accountExpirationField: NSTextField!
    
    fileprivate weak var delegate: PreferencesViewDelegate!

    
    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: PreferencesViewDelegate) {
        self.init(nibName: NSNib.Name("AccountView"), bundle: nil)
        
        self.delegate = delegate

        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
    }
    
    @IBAction func signOut(_ sender: AnyObject) {
        AccountController.sharedAccountController.signOut()
    }
    
    @IBAction func loadAccountPage(_ sender: AnyObject) {
        // Open the safedrive account page in users default browser
        let url = URL(string: "https://\(webDomain())/#/en/dashboard/account/details")
        // swiftlint:disable force_unwrapping
        NSWorkspace.shared.open(url!)
        // swiftlint:enable force_unwrapping

    }
    
}

extension AccountViewController: SDAccountProtocol {
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")
        
        guard let accountStatus = notification.object as? SDKAccountStatus else {
                self.accountStatusField.stringValue = NSLocalizedString("Unknown", comment: "")
                SDLog("API contract invalid: didSignIn in PreferencesWindowController")
                return
        }
        self.accountStatusField.stringValue = String(describing: accountStatus.state)
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")
        
        guard let accountStatus = notification.object as? SDKAccountStatus else {
                self.accountStatusField.stringValue = NSLocalizedString("Unknown", comment: "")
                SDLog("API contract invalid: didReceiveAccountStatus in PreferencesWindowController")
                return
        }
        self.accountStatusField.stringValue = String(describing: accountStatus.state)
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")
        
        guard let accountDetails = notification.object as? SDKAccountDetails else {
            SDLog("API contract invalid: didReceiveAccountDetails in PreferencesWindowController")
            return
        }
        
        let assignedStorage = accountDetails.assignedStorage
        let usedStorage = accountDetails.usedStorage
        let expirationDate = accountDetails.expirationDate
        
        self.assignedStorageField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(assignedStorage), countStyle: .file)
        self.usedStorageField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(usedStorage), countStyle: .file)
        
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .short
        self.accountExpirationField.stringValue = dateFormatter.string(from: expirationDate)
    }
}
