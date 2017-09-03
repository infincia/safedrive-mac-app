
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class ValidateAccountViewController: NSViewController {
    
    var sdk = SafeDriveSDK.sharedSDK
        
    fileprivate weak var delegate: WelcomeStateDelegate?
    
    fileprivate weak var viewDelegate: WelcomeViewDelegate?

    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!
    
    @IBOutlet fileprivate weak var signInButton: NSButton!
    
    @IBOutlet fileprivate weak var createAccountButton: NSButton!
    
    @IBOutlet fileprivate weak var emailField: NSTextField!
    @IBOutlet fileprivate weak var passwordField: NSTextField!
    
    var email: String?
    var password: String?
        
    fileprivate var isInteractiveLogin = false
    
    fileprivate var prompted = false
    
    fileprivate let signingInQueue = DispatchQueue(label: "signingInQueue")

    @objc
    var signingIn: NSNumber {
        get {
            var s = NSNumber(value: 0) // sane default
            signingInQueue.sync {
                s = self._signingIn
            }
            return s
        }
        set (newValue) {
            signingInQueue.sync(flags: .barrier, execute: {
                self._signingIn = newValue
            })
        }
    }
    
    fileprivate var _signingIn: NSNumber = NSNumber(value: 0)

    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: WelcomeStateDelegate, viewDelegate: WelcomeViewDelegate) {
        self.init(nibName: NSNib.Name(rawValue: "ValidateAccountView"), bundle: nil)

        self.delegate = delegate
        
        self.viewDelegate = viewDelegate
    }
    
    func reset() {
        self.email = nil
        self.password = nil
        self.emailField.stringValue = ""
        self.passwordField.stringValue = ""
        self.prompted = false
        self.spinner.stopAnimation(self)
        self.signingIn = false
        validateForm()
    }
    
    func check() {
        self.reset()
        SDLog("checking account")
        
        
        background {
            if let currentUser = try? self.sdk.getKeychainItem(withUser: "currentuser", service: currentUserDomain()),
                let password = try? self.sdk.getKeychainItem(withUser: currentUser, service: accountCredentialDomain()) {
                DispatchQueue.main.async {
                    
                    self.email = currentUser
                    self.emailField.stringValue = currentUser
                    self.password = password
                    self.passwordField.stringValue = password
                    self.validateForm()
                    self.signIn(nil)
                }
                return
            }
            
            while true {
                if !self.prompted {
                    self.prompted = true
                    DispatchQueue.main.async {
                       self.isInteractiveLogin = true
                        self.delegate?.needsAccount()
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
    
    @IBAction func signIn(_ sender: AnyObject?) {
        SDLog("signing in")
        
        guard let email = self.email,
              let password = self.password else {
                let alert = NSAlert()
                alert.addButton(withTitle: NSLocalizedString("OK", comment: "Button title"))
                alert.alertStyle = .warning
                
                
                alert.messageText = NSLocalizedString("SafeDrive requires an account", comment: "String informing the user that an account is required")
                
                alert.informativeText = NSLocalizedString("No email or password entered", comment: "String informing the user that an email or password was not entered")
                
                self.viewDelegate?.showAlert(alert) { (response) in
                    switch response {
                    case NSApplication.ModalResponse.alertFirstButtonReturn:
                        break
                    default:
                        return
                    }
                }
                return
        }

        self.signingIn = true
        
        SDLog("starting login for account \(email)")

        do {
            try SafeDriveSDK.sharedSDK.setKeychainItem(withUser: "currentuser", service: currentUserDomain(), secret: email)
            SDLog("set current user: \(email)")

        } catch let error as NSError {
            SDLog("failed to set current user: \(email)")
            self.signingIn = false
            self.delegate?.didFail(error: error, uniqueClientID: nil)
        }

        self.spinner.startAnimation(self)
        
        self.sdk.getClients(withUser: email, password: password, completionQueue: DispatchQueue.main, success: { (clients) in
            do {
                self.signingIn = false

                try SafeDriveSDK.sharedSDK.setKeychainItem(withUser: email, service: accountCredentialDomain(), secret: password)
                self.spinner.stopAnimation(self)
                self.delegate?.didValidateAccount(withEmail: email, password: password, clients: clients)
            } catch let keychainError as NSError {
                self.spinner.stopAnimation(self)
                self.delegate?.didFail(error: keychainError, uniqueClientID: nil)
                return
            }
        }) { (error) in
            self.signingIn = false

            self.spinner.stopAnimation(self)
            SDLog("login error: \(error) (\(error.kind))")
            if error.kind == .Authentication {
                if !self.isInteractiveLogin {
                    self.delegate?.needsAccount()
                } else {
                    let alert = NSAlert()
                    alert.addButton(withTitle: NSLocalizedString("OK", comment: "Button title"))
                    alert.alertStyle = .warning
                    
                    
                    alert.messageText = NSLocalizedString("Login failed", comment: "String informing the user that an account is required")
                    
                    alert.informativeText = error.message
                    
                    self.viewDelegate?.showAlert(alert) { (response) in
                        switch response {
                        case NSApplication.ModalResponse.alertFirstButtonReturn:
                            break
                        default:
                            return
                        }
                    }
                }
            } else {
                self.delegate?.didFail(error: error, uniqueClientID: nil)
            }

        }
    }
    
    @IBAction func createAccount(_ sender: AnyObject?) {
        // Open the safedrive page in users default browser
        let url = URL(string: "https://\(webDomain())/")
        // swiftlint:disable force_unwrapping
        NSWorkspace.shared.open(url!)
        // swiftlint:enable force_unwrapping

    }
    
    @IBAction func resetPassword(_ sender: AnyObject) {
        // Open the safedrive reset password page in users default browser
        let url = URL(string: "https://\(webDomain())/#!/en/reset-password")
        // swiftlint:disable force_unwrapping
        NSWorkspace.shared.open(url!)
        // swiftlint:enable force_unwrapping

    }
    
    func validateForm() {
        guard let email = self.email, let password = self.password, password.characters.count >= 1, email.characters.count >= 1 else {
            self.signInButton.isEnabled = false
            return
        }
        if password.characters.count >= 1 && email.characters.count >= 1 {
            self.signInButton.isEnabled = true
        } else {
            self.signInButton.isEnabled = false
        }
    }
}


extension ValidateAccountViewController: NSTextFieldDelegate {
    
    override func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else {
            return
        }
        
        if field == self.emailField {
            if field.stringValue.characters.count >= 1 {
                self.email = field.stringValue
            } else {
                self.email = nil
            }
        } else if field == self.passwordField {
            if field.stringValue.characters.count >= 1 {
                self.password = field.stringValue
            } else {
                self.password = nil
            }
        } else {
            // there are no more in the window
        }
        self.validateForm()
    }
}
