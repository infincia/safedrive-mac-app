
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import SafeDriveSDK

class ValidateAccountViewController: NSViewController {
    
    var sdk = SafeDriveSDK.sharedSDK
        
    fileprivate weak var delegate: StateDelegate?
    
    @IBOutlet var spinner: NSProgressIndicator!
    
    @IBOutlet weak var emailField: NSTextField!
    
    @IBOutlet weak var passwordField: NSTextField!
    
    @IBOutlet weak var signInButton: NSButton!
    
    @IBOutlet weak var createAccountButton: NSButton!
    
    @IBOutlet var email: String?
    @IBOutlet var password: String?
    
    fileprivate var prompted = false

    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: StateDelegate) {
        self.init(nibName: "ValidateAccountView", bundle: nil)!
        self.delegate = delegate
    }
    
    func reset() {
        self.email = nil
        self.password = nil
        self.prompted = false
        self.spinner.stopAnimation(self)
    }
    
    func check() {
        self.reset()
        SDLog("checking account")
        
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            while true {
                if let currentUser = try? self.sdk.getKeychainItem(withUser: "currentuser", service: currentUserDomain()),
                    let password = try? self.sdk.getKeychainItem(withUser: currentUser, service: accountCredentialDomain()) {
                    DispatchQueue.main.sync {
                        self.email = currentUser
                        self.password = password
                    }
                    break
                }
                if !self.prompted {
                    self.prompted = true
                    DispatchQueue.main.sync {
                        self.delegate?.needsAccount()
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }

            DispatchQueue.main.sync {
                self.signIn(nil)
            }
        }
    }
    
    @IBAction func signIn(_ sender: AnyObject?) {
        SDLog("signing in")
        
        guard let email = self.email,
              let password = self.password else {
            return
        }
        
        SDLog("starting login for account \(email)")

        do {
            try SafeDriveSDK.sharedSDK.setKeychainItem(withUser: "currentuser", service: currentUserDomain(), secret: email)
            SDLog("set current user: \(email)")

        } catch let error as NSError {
            SDLog("failed to set current user: \(email)")
            self.delegate?.didFail(error: error, uniqueClientID: nil)
        }

        self.spinner.startAnimation(self)
        
        self.sdk.getClients(withUser: email, password: password, completionQueue: DispatchQueue.main, success: { (clients) in
            do {
                try SafeDriveSDK.sharedSDK.setKeychainItem(withUser: email, service: accountCredentialDomain(), secret: password)
                self.spinner.stopAnimation(self)
                self.delegate?.didValidateAccount(withEmail: email, password: password, clients: clients)
            } catch let keychainError as NSError {
                self.spinner.stopAnimation(self)
                self.delegate?.didFail(error: keychainError, uniqueClientID: nil)
                return
            }
        }) { (error) in
            self.spinner.stopAnimation(self)
            self.delegate?.didFail(error: error, uniqueClientID: nil)
            self.delegate?.needsAccount()
        }
    }
    
    @IBAction func createAccount(_ sender: AnyObject?) {
        // Open the safedrive page in users default browser
        let url = URL(string: "https://\(webDomain())/")
        NSWorkspace.shared().open(url!)
    }
}
