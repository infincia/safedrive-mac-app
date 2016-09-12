
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import Crashlytics
import Realm
import RealmSwift

class AccountController: NSObject {
    static let sharedAccountController = AccountController()

    var accountStatus: SDAccountStatus = .unknown

    var email: String?
    var internalUserName: String?
    var password: String?

    var remoteHost: String?
    var remotePort: NSNumber?

    var hasCredentials: Bool = false
    var signedIn: Bool = false

    fileprivate var sharedSystemAPI = SDSystemAPI.shared()
    fileprivate var sharedSafedriveAPI = API.sharedAPI


    override init() {
        super.init()
        if let credentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: SDServiceName) {
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
        if let storedCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: SDServiceName),
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
                        realm.delete(realm.allObjects(ofType: SyncFolder.self))
                        realm.delete(realm.allObjects(ofType: SyncTask.self))
                    }
                } catch {
                    SDLog("failed to delete old data in realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
            }

        }


        let keychainError: NSError? = self.sharedSystemAPI.insertCredentialsInKeychain(forService: SDServiceName, account: email, password: password) as NSError?

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
                        NotificationCenter.default.post(name: NSNotification.Name.SDAccountStatus, object: accountStatus)
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
                        var currentMachine = realm.allObjects(ofType: Machine.self).filter(using: "uniqueClientID == '\(clientID)'").last

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
                    NotificationCenter.default.post(name: NSNotification.Name.SDAccountSignIn, object: clientID)
                    successBlock()
                }
            }, failure: { (error: Swift.Error) -> Void in
                failureBlock(error)

            })

            self.sharedSafedriveAPI.accountDetailsForUser(email, success: {(accountDetails: [String : NSObject]?) -> Void in
                if let accountDetails = accountDetails {
                    DispatchQueue.main.async(execute: {() -> Void in
                        NotificationCenter.default.post(name: NSNotification.Name.SDAccountDetails, object: accountDetails)
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
        self.sharedSystemAPI.removeCredentialsInKeychain(forService: SDServiceName)

        self.signedIn = false

        // reset crashlytics email and telemetry API username
        Crashlytics.sharedInstance().setUserEmail(nil)
        SDErrorHandlerSetUser(nil)
        NotificationCenter.default.post(name: NSNotification.Name.SDAccountSignOut, object: nil)
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
                            NotificationCenter.default.post(name: NSNotification.Name.SDAccountStatus, object: accountStatus)
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
                            NotificationCenter.default.post(name: NSNotification.Name.SDAccountDetails, object: accountDetails)
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
