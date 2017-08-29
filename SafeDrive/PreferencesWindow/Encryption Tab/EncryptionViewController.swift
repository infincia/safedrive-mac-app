
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class EncryptionViewController: NSViewController {
    
    fileprivate let sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var recoveryPhraseEntry: RecoveryPhraseWindowController!
    
    fileprivate weak var delegate: PreferencesViewDelegate!

    fileprivate var uniqueClientID: String?

    @IBOutlet fileprivate var copyRecoveryPhraseButton: NSButton!
    
    @IBOutlet fileprivate var recoveryPhraseField: NSTextField!
    
    var email: String?

    fileprivate let loadKeysQueue = DispatchQueue(label: "io.safedrive.loadKeysQueue")

    var _lastLoadKeysError: SDKError?
    
    var lastLoadKeysError: SDKError? {
        get {
            var s: SDKError?
            loadKeysQueue.sync {
                s = self._lastLoadKeysError
            }
            return s
        }
        set (newValue) {
            loadKeysQueue.sync(flags: .barrier, execute: {
                self._lastLoadKeysError = newValue
            })
        }
    }
    
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

        self.init(nibName: NSNib.Name(rawValue: "EncryptionView"), bundle: nil)

            
        self.recoveryPhraseEntry = RecoveryPhraseWindowController(delegate: self)

        self.delegate = delegate

        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didRequireRecoveryPhrase), name: Notification.Name.accountNeedsRecoveryPhrase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didLoadRecoveryPhrase), name: Notification.Name.accountLoadedRecoveryPhrase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didCreateRecoveryPhrase), name: Notification.Name.accountCreatedRecoveryPhrase, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
    }
    
    @IBAction func copyRecoveryPhrase(_ sender: AnyObject) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.writeObjects([recoveryPhraseField.stringValue as NSString])
    }
}

extension EncryptionViewController: RecoveryPhraseEntryDelegate {
    func checkRecoveryPhrase(_ phrase: String?, success: @escaping () -> Void, failure: @escaping (_ error: SDKError) -> Void) {
        assert(Thread.current == Thread.main, "checkRecoveryPhrase called on background thread")
        
        guard let email = self.email else {
            return
        }
        
        self.sdk.loadKeys(phrase, completionQueue: DispatchQueue.main, storePhrase: { (newPhrase) in
            
            self.storeRecoveryPhrase(newPhrase, success: {
                
                NotificationCenter.default.post(name: Notification.Name.accountCreatedRecoveryPhrase, object: newPhrase)

            }, failure: { (error) in
                let se = SDKError(message: error.localizedDescription, kind: SDKErrorType.KeychainError)
                failure(se)
            })
            
        }, issue: { (message) in
            SDLog("\(message)")
            
            let notification = NSUserNotification()
            notification.informativeText = message
            notification.title = NSLocalizedString("Account issue", comment: "")
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)

        }, success: {
            if let recoveryPhrase = try? self.sdk.getKeychainItem(withUser: email, service: recoveryKeyDomain()) {
                self.recoveryPhraseField.stringValue = recoveryPhrase
                self.copyRecoveryPhraseButton.isEnabled = true
            } else {
                self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
                self.copyRecoveryPhraseButton.isEnabled = false
            }
            success()
            
        }, failure: { (error) in
            var reportError = false
            var showError = false

            switch error.kind {
            case .Authentication:
                break
            default:
                if let existingError = self.lastLoadKeysError {
                    if existingError != error {
                        self.lastLoadKeysError = error
                        reportError = true
                        showError = true
                    }
                } else {
                    self.lastLoadKeysError = error
                    reportError = true
                    showError = true
                }
                break
            }
            
            if showError {
                SDLog("SafeDrive loadKeys failure in encryption view controller (this message will only appear once): \(error.message)")

                let title = NSLocalizedString("SafeDrive keys unavailable", comment: "")
                
                let notification = NSUserNotification()
                
                notification.informativeText = error.message
                notification.title = title
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
            }
            
            if reportError && error.kind != .NetworkFailure {
                SDErrorHandlerReport(error)
            }
            
            failure(error)
            
        })
    }
    
    func storeRecoveryPhrase(_ phrase: String, success: @escaping () -> Void, failure: @escaping (_ error: Error) -> Void) {
        assert(Thread.current == Thread.main, "storeRecoveryPhrase called on background thread")
        
        guard let email = self.email else {
            return
        }
        do {
            try self.sdk.setKeychainItem(withUser: email, service: recoveryKeyDomain(), secret: phrase)
        } catch let keychainError as NSError {
            SDErrorHandlerReport(keychainError)
            failure(keychainError)
            return
        }
        success()
    }
}


extension EncryptionViewController: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")
        
        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in PreferencesWindowController")
            
            return
        }
        
        self.uniqueClientID = uniqueClientID
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")
        
        guard let currentUser = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in PreferencesWindowController")
            
            return
        }
        
        self.email = currentUser.email
    }
}

extension EncryptionViewController: SDAccountProtocol {

    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")

        guard let _ = self.uniqueClientID,
              let email = self.email else {
            SDLog("API contract invalid: didSignIn in PreferencesWindowController")
            return
        }
        
        let recoveryPhrase = try? self.sdk.getKeychainItem(withUser: email, service: recoveryKeyDomain())
        
        self.checkRecoveryPhrase(recoveryPhrase, success: {
            NotificationCenter.default.post(name: Notification.Name.accountLoadedRecoveryPhrase, object: nil)
        }, failure: { (error) in
            switch error.kind {
            case .StateMissing:
                break
            case .Internal:
                break
            case .RequestFailure:
                break
            case .NetworkFailure:
                break
            case .Conflict:
                break
            case .BlockMissing:
                break
            case .SessionMissing:
                break
            case .RecoveryPhraseIncorrect:
                NotificationCenter.default.post(name: Notification.Name.accountNeedsRecoveryPhrase, object: nil)
            case .InsufficientFreeSpace:
                break
            case .Authentication:
                break
            case .UnicodeError:
                break
            case .TokenExpired:
                break
            case .CryptoError:
                NotificationCenter.default.post(name: Notification.Name.accountNeedsRecoveryPhrase, object: nil)
                break
            case .IO:
                break
            case .SyncAlreadyInProgress:
                break
            case .RestoreAlreadyInProgress:
                break
            case .ExceededRetries:
                break
            case .KeychainError:
                break
            case .BlockUnreadable:
                break
            case .SessionUnreadable:
                break
            case .ServiceUnavailable:
                break
            case .Cancelled:
                break
            case .FolderMissing:
                break
            case .KeyCorrupted:
                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                
                alert.messageText = "Warning: keys corrupted"
                alert.informativeText = "The keys in your account are corrupted, please restore the from backup or contact SafeDrive support for help"
                alert.alertStyle = .critical
                
                
                self.delegate.setTab(Tab.encryption)
                self.delegate.showAlert(alert) { (_) in
                    //
                }
            }
        })
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")
        self.email = nil
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
    
    func didCreateRecoveryPhrase(notification: Notification) {
        assert(Thread.current == Thread.main, "didCreateRecoveryPhrase called on background thread")
        
        guard let newPhrase = notification.object as? String else {
            SDLog("API contract invalid: didSignIn in PreferencesWindowController")
            return
        }
        
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        
        alert.messageText = "New recovery phrase"
        alert.informativeText = "A recovery phrase has been generated for your account, please write it down and keep it in a safe place:\n\n\(newPhrase)"
        alert.alertStyle = .informational
        
        
        self.delegate.setTab(Tab.encryption)
        self.delegate.showAlert(alert) { (_) in
            //
        }
    }
    
    func didRequireRecoveryPhrase(notification: Notification) {
        assert(Thread.current == Thread.main, "didRequireRecoveryPhrase called on background thread")

        self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
        self.copyRecoveryPhraseButton.isEnabled = false
        
        guard let w = self.recoveryPhraseEntry?.window else {
            SDLog("no recovery phrase window available")
            return
        }
        self.delegate.setTab(Tab.encryption)
        self.delegate.showModalWindow(w) { (_) in
            //
        }
    }
}
