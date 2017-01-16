
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

    fileprivate var signedIn: Bool {
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
        if let credentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: SDServiceNameProduction) {
            self.email = credentials["account"]
            self.password = credentials["password"]

            Crashlytics.sharedInstance().setUserEmail(self.email)

            SDErrorHandlerSetUser(self.email)
            self.hasCredentials = true
        }
        self.accountLoop()

    }

    func signInWithSuccess(_ successBlock: @escaping SDSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
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
        if let storedCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: SDServiceNameProduction),
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
        
        let recoveryCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: SDRecoveryKeyServiceName)
        
        let recoveryPhrase = recoveryCredentials?["password"]


        let keychainError: NSError? = self.sharedSystemAPI.insertCredentialsInKeychain(forService: SDServiceNameProduction, account: email, password: password) as NSError?

        if let keychainError = keychainError {
            SDErrorHandlerReport(keychainError)
            failureBlock(keychainError)
            return
        }
        Crashlytics.sharedInstance().setUserEmail(email)
        SDErrorHandlerSetUser(email)

        self.sharedSafedriveAPI.registerMachineWithUser(email, password: password, success: { (sessionToken: String, clientID: String) -> Void in
            self.sharedSafedriveAPI.accountStatusForUser(email, success: { (accountStatus: [String : NSObject]?) -> Void in
                self.signedIn = true
                Crashlytics.sharedInstance().setUserIdentifier(clientID)

                if let accountStatus = accountStatus {
                    DispatchQueue.main.async(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.accountStatus, object: accountStatus)
                    })
                    self.internalUserName = accountStatus["userName"] as? String

                    self.remotePort = accountStatus["port"] as? NSNumber

                    self.remoteHost = accountStatus["host"] as? String

                    let keychainError = self.sharedSystemAPI.insertCredentialsInKeychain(forService: SDSSHServiceName, account: self.internalUserName!, password: self.password!)
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
                    guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db") else {
                        SDLog("Failed to obtain group container, this is a fatal error")
                        Crashlytics.sharedInstance().crash()
                        return
                    }
                    
                    self.sdk.setUp(local_storage_path: groupURL.path, unique_client_id: clientID)
                    
                    do {
                        try self.sdk.login(email, password: password)
                    }
                    catch {
                        print("failed to login with sdk")
                    }
                    
                    
                    do {
                        try self.sdk.loadKeys(recoveryPhrase, storePhrase: { (newPhrase) in
                            print("New recovery phrase: \(newPhrase)")
                            let keychainError = self.sharedSystemAPI.insertCredentialsInKeychain(forService: SDRecoveryKeyServiceName, account: email, password: newPhrase)
                            if let keychainError = keychainError {
                                SDErrorHandlerReport(keychainError)
                                failureBlock(keychainError)
                                return
                            }
                        })
                    }
                    catch {
                        print("failed to load keys")
                    }
        
                    NotificationCenter.default.post(name: Notification.Name.sdkReady, object: nil)

                    NotificationCenter.default.post(name: Notification.Name.accountAuthenticated, object: clientID)
                    successBlock()
                }
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

    func signOutWithSuccess(_ successBlock: SDSuccessBlock, failure failureBlock: SDFailureBlock) {
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: SDSessionServiceName)
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: SDSSHServiceName)
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: SDServiceNameProduction)

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
