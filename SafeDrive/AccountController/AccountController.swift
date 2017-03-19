
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
    let uniqueClientId: String
}

class AccountController: NSObject {
    static let sharedAccountController = AccountController()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    var accountStatus: SDAccountStatus = .unknown
    
    var email: String?
    var password: String?
    fileprivate let userQueue = DispatchQueue(label: "io.safedrive.accountQueue")

    var _currentUser: User?
    
    var currentUser: User? {
        get {
            var user: User?
            userQueue.sync {
                user = self._currentUser
            }
            return user
        }
        set (newValue) {
            userQueue.sync(flags: .barrier, execute: {
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
        guard let email = self.email, let password = self.password else {
            return
        }
        
        self.signOut()
        
        /*
         
         This is a workaround for SyncFolders not having a truly unique primary key on the server side,
         we have to clear the table before allowing a different account to sign in and store SyncFolders,
         or things will get into an inconsistent state.
         
         A better solution would likely be to use separate realm files for each username, but that greatly
         complicates things and will take some planning to do.
         
         */
        if let currentUser = try? self.sdk.getKeychainItem(withUser: "currentuser", service: currentUserDomain()),
            let _ = try? self.sdk.getKeychainItem(withUser: currentUser, service: accountCredentialDomain()) {
            if currentUser != email {
                // reset SyncFolder and SyncTask in database, user has changed since last sign-in
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                do {
                    try realm.write {
                        realm.delete(realm.objects(SyncFolder.self))
                        realm.delete(realm.objects(SyncTask.self))
                    }
                } catch {
                    SDLog("failed to delete old data in realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
            }
            
        }
        
        Crashlytics.sharedInstance().setUserEmail(email)

        
        do {
            try self.sdk.setKeychainItem(withUser: email, service: accountCredentialDomain(), secret: password)
        } catch let keychainError as NSError {
            let e = SDKError(message: keychainError.localizedDescription, kind: .KeychainError)
            
            SDErrorHandlerReport(keychainError)
            failureBlock(e)
            return
        }
        Crashlytics.sharedInstance().setUserEmail(email)
        
        let macAddress: String = SDSystemAPI.shared().en0MAC()!
        let machineIdConcatenation: String = macAddress + email
        let ucid: String = HKTHashProvider.sha256(machineIdConcatenation.data(using: String.Encoding.utf8))
        
        SDErrorHandlerSetUniqueClientId(ucid)
        Crashlytics.sharedInstance().setUserIdentifier(ucid)

        
        
        self.sdk.login(email, password: password, unique_client_id: ucid, completionQueue: self.sdkCompletionQueue, success: { (status) -> Void in
            self.signedIn = true
            
            DispatchQueue.main.async(execute: {() -> Void in
                NotificationCenter.default.post(name: Notification.Name.accountStatus, object: status)
            })
            let internalUserName = status.userName
            
            do {
                try self.sdk.setKeychainItem(withUser: email, service: sshCredentialDomain(), secret: internalUserName)
            } catch let keychainError as NSError {
                let e = SDKError(message: keychainError.localizedDescription, kind: .KeychainError)

                SDErrorHandlerReport(keychainError)
                failureBlock(e)
                return
            }
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            do {
                /*
                 Once a Machine entity is created for this uniqueClientID, we never modify it without special handling.
                 
                 The Machine.name property is used to decide which path on the server to sync to, so we cannot allow
                 it to be overwritten every time the local hostname changes.
                 
                 
                 
                 */
                var currentMachine = realm.objects(Machine.self).filter("uniqueClientID == '\(ucid)'").last
                
                if currentMachine == nil {
                    let machineName = Host.current().localizedName!
                    
                    currentMachine = Machine(name: machineName, uniqueClientID: ucid)
                    
                    try realm.write {
                        realm.add(currentMachine!, update: true)
                    }
                }
            } catch {
                SDLog("failed to update machine in realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
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
            
            let currentUser = User(email: email, password: password, uniqueClientId: ucid)
            
            NotificationCenter.default.post(name: Notification.Name.accountSignIn, object: currentUser)
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
        
        do {
            try self.sdk.deleteKeychainItem(withUser: user.email, service: tokenDomain())
        } catch let error as SDKError {
            SDLog("warning: failed to remove auth token from keychain: \(error.message)")
        } catch {
            fatalError("cannot reach this point")
        }
        
        do {
            try self.sdk.deleteKeychainItem(withUser: user.email, service: sshCredentialDomain())
        } catch let error as SDKError {
            SDLog("warning: failed to remove ssh username from keychain: \(error.message)")
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
                guard let _ = self.email else {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                if !self.signedIn {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                Thread.sleep(forTimeInterval: 60 * 5) // 5 minutes
                
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
        
    }
    
    func applicationDidConfigureClient(notification: Notification) {
        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in AppDelegate")
            
            return
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        guard let user = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in AppDelegate")
            
            return
        }
    }
}
