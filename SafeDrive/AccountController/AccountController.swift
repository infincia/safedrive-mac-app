
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import Crashlytics
import Realm
import RealmSwift

import SafeDriveSDK

struct User {
    let email: String
    let password: String
}

class AccountController: NSObject {
    static let sharedAccountController = AccountController()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    var accountStatus: SDAccountStatus = .unknown
    
    var uniqueClientID: String?
    
    var email: String?
    var password: String?
    

    // swiftlint:disable variable_name
    var _currentUser: User?
    // swiftlint:enable variable_name
    
    var currentUser: User? {
        get {
            var user: User?
            accountQueue.sync {
                user = self._currentUser
            }
            return user
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._currentUser = newValue
            })
        }
    }
    
    fileprivate let accountQueue = DispatchQueue(label: "io.safedrive.accountQueue")
    
    fileprivate let sdkCompletionQueue = DispatchQueue.main

    
    var signedIn: Bool {
        get {
            var s: Bool = false // sane default, signing in twice due to "false negative" doesn't hurt anything
            accountQueue.sync {
                s = self._signedIn
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._signedIn = newValue
            })
        }
    }
    
    fileprivate var _signedIn: Bool = false
    
    var signingIn: Bool {
        get {
            var s: Bool = false // sane default, signing in twice due to "false negative" doesn't hurt anything
            accountQueue.sync {
                s = self._signingIn
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._signingIn = newValue
            })
        }
    }
    
    fileprivate var _signingIn: Bool = false
    
    fileprivate var sharedSystemAPI = SDSystemAPI.shared()    
    
    fileprivate var realm: Realm?
    
    override init() {
        super.init()
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureRealm), name: Notification.Name.applicationDidConfigureRealm, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        self.accountLoop()
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func signIn(_ successBlock: @escaping () -> Void, failure failureBlock: @escaping (_ error: SDKError) -> Void) {
        guard let email = self.email, let password = self.password, let uniqueClientID = self.uniqueClientID else {
            return
        }

        SDErrorHandlerSetUniqueClientId(uniqueClientID)

        Crashlytics.sharedInstance().setUserEmail(email)
        Crashlytics.sharedInstance().setUserIdentifier(uniqueClientID)
        
        self.sdk.login(email, password: password, unique_client_id: uniqueClientID, completionQueue: self.sdkCompletionQueue, success: { (status) -> Void in
            self.signedIn = true
            
            DispatchQueue.main.async(execute: {() -> Void in
                NotificationCenter.default.post(name: Notification.Name.accountStatus, object: status)
            })
            
            self.sdk.getAccountDetails(completionQueue: DispatchQueue.main, success: { (details) in
                
                DispatchQueue.main.async(execute: {() -> Void in
                    NotificationCenter.default.post(name: Notification.Name.accountDetails, object: details)
                })
                
            }, failure: { (error) in
                if !isProduction() {
                    SDLog("Account details retrieval failed: \(error.message)")
                    // don't report these for now, they're almost always going to be network failures
                    // SDErrorHandlerReport(apiError);
                }
            })
            
            let currentUser = User(email: email, password: password)
            DispatchQueue.main.async(execute: {() -> Void in
                NotificationCenter.default.post(name: Notification.Name.accountSignIn, object: currentUser)
            })
            successBlock()
            
        }, failure: { (error) in
            SDLog("failed to login with sdk: \(error.message)")
            failureBlock(error)
        })
    }
    
    func signOut() {
        guard let user = self.currentUser else {
            return
        }
        
        self.realm = nil
        
        do {
            try self.sdk.deleteKeychainItem(withUser: user.email, service: tokenDomain())
        } catch let error as SDKError {
            SDLog("warning: failed to remove auth token from keychain: \(error.message)")
        } catch {
            fatalError("cannot reach this point")
        }
        
        do {
            try self.sdk.deleteKeychainItem(withUser: user.email, service: accountCredentialDomain())
        } catch let error as SDKError {
            SDLog("warning: failed to remove password from keychain: \(error.message)")
        } catch {
            fatalError("cannot reach this point")
        }
        
        
        self.signedIn = false
        self.signingIn = false
        self.currentUser = nil
        self.email = nil
        self.password = nil
        self.accountStatus = .unknown
        self.uniqueClientID = nil
        
        // reset crashlytics email and telemetry API username
        Crashlytics.sharedInstance().setUserEmail(nil)
        SDErrorHandlerSetUniqueClientId(nil)
        NotificationCenter.default.post(name: Notification.Name.accountSignOut, object: nil)
        
    }
    
    // MARK: Private
    
    fileprivate func accountStatusFromString(_ string: String) -> SDAccountStatus {
        switch string {
        case "active":
            return .active
        case "trial":
            return .trial
        case "trial-expired":
            return .trialExpired
        case "expired":
            return .expired
        case "locked":
            return .locked
        case "reset-password":
            return .resetPassword
        case "pending-creation":
            return .pendingCreation
        default:
            return .unknown
        }
    }
    
    fileprivate func accountLoop() {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            while true {
                guard let _ = self.email, let _ = self.password, let _ = self.uniqueClientID, let _ = self.realm else {
                    Thread.sleep(forTimeInterval: 1)

                    continue
                }

                if !self.signedIn && !self.signingIn {
                    self.signingIn = true
                    self.signIn({ 
                        self.signingIn = false
                        self.signedIn = true
                    }, failure: { (error) in
                        self.signingIn = false
                        self.signedIn = false
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
                            break
                        case .InsufficientFreeSpace:
                            break
                        case .Authentication:
                            break
                        case .UnicodeError:
                            break
                        case .TokenExpired:
                            break
                        case .CryptoError:
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
                        }
                    })
                    continue
                }
                
                if !self.signedIn {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                Thread.sleep(forTimeInterval: 60 * 5) // 5 minutes
                
                // reset the loop again if we aren't signed in for some reason
                if !self.signedIn {
                    continue
                }
                
                self.sdk.getAccountStatus(completionQueue: DispatchQueue.main, success: { (status) in
                        DispatchQueue.main.async(execute: {() -> Void in
                            NotificationCenter.default.post(name: Notification.Name.accountStatus, object: status)
                        })
                    
                }, failure: { (error) in
                    if !isProduction() {
                        SDLog("Account status retrieval failed: \(error.message)")
                        // don't report these for now, they're almost always going to be network failures
                        // SDErrorHandlerReport(apiError);
                    }
                })
                
                self.sdk.getAccountDetails(completionQueue: DispatchQueue.main, success: { (details) in
                    
                    DispatchQueue.main.async(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.accountDetails, object: details)
                    })
                    
                }, failure: { (error) in
                    if !isProduction() {
                        SDLog("Account details retrieval failed: \(error.message)")
                        // don't report these for now, they're almost always going to be network failures
                        // SDErrorHandlerReport(apiError);
                    }
                })
            }
        })
    }
    
}

extension AccountController: SDApplicationEventProtocol {
    func applicationDidConfigureRealm(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureRealm called on background thread")

        guard let realm = try? Realm() else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.realm = realm
    }
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in AppDelegate")
            
            return
        }
        
        self.uniqueClientID = uniqueClientID
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let user = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in AppDelegate")
            
            return
        }
        
        self.currentUser = user
        self.email = user.email
        self.password = user.password
    }
}
