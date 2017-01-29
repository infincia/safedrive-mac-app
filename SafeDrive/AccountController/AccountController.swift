
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import Crashlytics
import Realm
import RealmSwift

import SafeDriveSDK

class AccountController: NSObject {
    static let sharedAccountController = AccountController()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    var accountStatus: SDAccountStatus = .unknown
    
    var email: String?
    var internalUserName: String?
    var password: String?
    
    var remoteHost: String?
    var remotePort: NSNumber?
    
    var hasCredentials: Bool = false
    
    fileprivate let accountQueue = DispatchQueue(label: "io.safedrive.accountQueue", attributes: DispatchQueue.Attributes.concurrent)
    
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
    
    fileprivate var sharedSystemAPI = SDSystemAPI.shared()
    fileprivate var sharedSafedriveAPI = API.sharedAPI
    
    
    override init() {
        super.init()
        if let credentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: accountCredentialDomain()) {
            self.email = credentials["account"]
            self.password = credentials["password"]
            
            Crashlytics.sharedInstance().setUserEmail(self.email)
            
            SDErrorHandlerSetUser(self.email)
            self.hasCredentials = true
        }
        self.accountLoop()
        
    }
    
    func signInWithSuccess(_ successBlock: @escaping () -> Void, failure failureBlock: @escaping (_ error: Error) -> Void) {
        guard let email = self.email, let password = self.password else {
            return
        }
        
        self.signOutWithSuccess({ () -> Void in
            //
        }, failure: { (error) -> Void in
            //
        })
        
        /*
         
         This is a workaround for SyncFolders not having a truly unique primary key on the server side,
         we have to clear the table before allowing a different account to sign in and store SyncFolders,
         or things will get into an inconsistent state.
         
         A better solution would likely be to use separate realm files for each username, but that greatly
         complicates things and will take some planning to do.
         
         */
        if let storedCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: accountCredentialDomain()),
            let storedEmail = storedCredentials["account"] {
            if storedEmail != email {
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
        
        let recoveryCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: recoveryKeyDomain())
        
        let recoveryPhrase = recoveryCredentials?["password"]
        
        
        let keychainError: NSError? = self.sharedSystemAPI.insertCredentialsInKeychain(forService: accountCredentialDomain(), account: email, password: password) as NSError?
        
        if let keychainError = keychainError {
            SDErrorHandlerReport(keychainError)
            failureBlock(keychainError)
            return
        }
        Crashlytics.sharedInstance().setUserEmail(email)
        SDErrorHandlerSetUser(email)
        
        self.sharedSafedriveAPI.registerMachineWithUser(email, password: password, success: { (sessionToken: String, clientID: String) -> Void in
            self.sharedSafedriveAPI.accountStatusForUser(email, success: { (accountStatus: [String : NSObject]) -> Void in
                self.signedIn = true
                Crashlytics.sharedInstance().setUserIdentifier(clientID)
                
                
                DispatchQueue.main.async(execute: {() -> Void in
                    NotificationCenter.default.post(name: Notification.Name.accountStatus, object: accountStatus)
                })
                self.internalUserName = accountStatus["userName"] as? String
                
                self.remotePort = accountStatus["port"] as? NSNumber
                
                self.remoteHost = accountStatus["host"] as? String
                
                let keychainError = self.sharedSystemAPI.insertCredentialsInKeychain(forService: sshCredentialDomain(), account: self.internalUserName!, password: self.password!)
                if let keychainError = keychainError {
                    SDErrorHandlerReport(keychainError)
                    failureBlock(keychainError)
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
                    var currentMachine = realm.objects(Machine.self).filter("uniqueClientID == '\(clientID)'").last
                    
                    if currentMachine == nil {
                        let machineName = Host.current().localizedName!
                        
                        currentMachine = Machine(name: machineName, uniqueClientID: clientID)
                        
                        try realm.write {
                            realm.add(currentMachine!, update: true)
                        }
                    }
                } catch {
                    SDLog("failed to update machine in realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                let groupURL = storageURL()
                
                var config: SDKConfiguration
                if isProduction() {
                    config = SDKConfiguration.Production
                }
                else {
                    config = SDKConfiguration.Staging
                }
                do {
                    try self.sdk.setUp(local_storage_path: groupURL.path, unique_client_id: clientID, config: config)
                }
                catch let error as SDKError {
                    SDLog("failed to initialize the sdk: \(error.message)")
                    Crashlytics.sharedInstance().crash()
                }
                catch {}
                
                do {
                    try self.sdk.login(email, password: password)
                }
                catch let error as SDKError {
                    SDLog("failed to login with sdk: \(error.message)")
                }
                catch {}
                
                do {
                    try self.sdk.loadKeys(recoveryPhrase, storePhrase: { (newPhrase) in
                        print("New recovery phrase: \(newPhrase)")
                        let keychainError = self.sharedSystemAPI.insertCredentialsInKeychain(forService: recoveryKeyDomain(), account: email, password: newPhrase)
                        if let keychainError = keychainError {
                            SDErrorHandlerReport(keychainError)
                            failureBlock(keychainError)
                            return
                        }
                    })
                }
                catch let error as SDKError {
                    SDLog("failed to load keys: \(error.message)")
                }
                catch {}
                
                NotificationCenter.default.post(name: Notification.Name.sdkReady, object: nil)
                
                NotificationCenter.default.post(name: Notification.Name.accountAuthenticated, object: clientID)
                successBlock()
                
            }, failure: { (error: Swift.Error) -> Void in
                failureBlock(error)
                
            })
            
            self.sharedSafedriveAPI.accountDetailsForUser(email, success: {(accountDetails: [String : NSObject]?) -> Void in
                if let accountDetails = accountDetails {
                    DispatchQueue.main.async(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.accountDetails, object: accountDetails)
                    })
                }
                
            }, failure: {(apiError: Swift.Error) -> Void in
                #if DEBUG
                    SDLog("Account details retrieval failed: %@", apiError.localizedDescription)
                    // don't report these for now, they're almost always going to be network failures
                    // SDErrorHandlerReport(apiError);
                #endif
            })
        }, failure: { (error: Swift.Error) -> Void in
            failureBlock(error)
        })
    }
    
    func signOutWithSuccess(_ successBlock: () -> Void, failure failureBlock: (_ error: Error) -> Void) {
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: tokenDomain())
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: sshCredentialDomain())
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: accountCredentialDomain())
        
        self.signedIn = false
        
        // reset crashlytics email and telemetry API username
        Crashlytics.sharedInstance().setUserEmail(nil)
        SDErrorHandlerSetUser(nil)
        NotificationCenter.default.post(name: Notification.Name.accountSignOut, object: nil)
        successBlock()
        
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
                guard let email = self.email else {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                if !self.signedIn {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                Thread.sleep(forTimeInterval: 60 * 5) // 5 minutes
                
                self.sharedSafedriveAPI.accountStatusForUser(email, success: {(accountStatus: [String : NSObject]?) -> Void in
                    
                    if let accountStatus = accountStatus {
                        DispatchQueue.main.async(execute: {() -> Void in
                            NotificationCenter.default.post(name: Notification.Name.accountStatus, object: accountStatus)
                        })
                        
                        self.internalUserName = accountStatus["userName"] as? String
                        
                        self.remotePort = accountStatus["port"] as? NSNumber
                        
                        self.remoteHost = accountStatus["host"] as? String
                    }
                    
                }, failure: {(apiError: Swift.Error) -> Void in
                    #if DEBUG
                        SDLog("Account status retrieval failed: %@", apiError.localizedDescription)
                        // don't report these for now, they're almost always going to be network failures
                        // SDErrorHandlerReport(apiError);
                    #endif
                })
                
                self.sharedSafedriveAPI.accountDetailsForUser(email, success: {(accountDetails: [String : NSObject]?) -> Void in
                    if let accountDetails = accountDetails {
                        DispatchQueue.main.async(execute: {() -> Void in
                            NotificationCenter.default.post(name: Notification.Name.accountDetails, object: accountDetails)
                        })
                    }
                    
                }, failure: {(apiError: Swift.Error) -> Void in
                    #if DEBUG
                        SDLog("Account details retrieval failed: %@", apiError.localizedDescription)
                        // don't report these for now, they're almost always going to be network failures
                        // SDErrorHandlerReport(apiError);
                    #endif
                })
            }
        })
    }
    
}
