
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length

import Crashlytics
import Foundation
import PromiseKit

struct User {
    let email: String
    let password: String
}

struct Client {
    let uniqueClientId: String
    let uniqueClientName: String
}

class AccountController: NSObject {
    static let sharedAccountController = AccountController()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    var accountState: SDKAccountState = .unknown
    
    fileprivate var _uniqueClientID: String?
    fileprivate var _uniqueClientName: String?

    fileprivate var _email: String?
    fileprivate var _password: String?
    
    var email: String? {
        get {
            var e: String?
            accountQueue.sync {
                e = self._email
            }
            return e
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._email = newValue
            })
        }
    }
    
    var password: String? {
        get {
            var p: String?
            accountQueue.sync {
                p = self._password
            }
            return p
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._password = newValue
            })
        }
    }
    
    var uniqueClientID: String? {
        get {
            var u: String?
            accountQueue.sync {
                u = self._uniqueClientID
            }
            return u
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._uniqueClientID = newValue
            })
        }
    }
    
    var uniqueClientName: String? {
        get {
            var u: String?
            accountQueue.sync {
                u = self._uniqueClientName
            }
            return u
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._uniqueClientName = newValue
            })
        }
    }
    
    fileprivate let accountQueue = DispatchQueue(label: "io.safedrive.accountQueue")
    fileprivate let accountCompletionQueue = DispatchQueue(label: "io.safedrive.accountCompletionQueue")

    // swiftlint:disable variable_name
    var _currentUser: User?
    fileprivate var _signedIn: Bool = false
    fileprivate var _signingIn: Bool = false
    fileprivate var _lastAccountStatusCheck: Date?
    fileprivate var _lastAccountDetailsCheck: Date?
    
    fileprivate var _lastAccountDetailsError: SDKError?
    fileprivate var _lastAccountStatusError: SDKError?
    fileprivate var _lastAccountSignInError: SDKError?

    fileprivate var _checkingStatus: Bool = false
    fileprivate var _checkingDetails: Bool = false
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
    

    @objc
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
    
    
    fileprivate var sharedSystemAPI = SDSystemAPI.shared()    
    var lastAccountStatusCheck: Date? {
        get {
            var s: Date?
            accountQueue.sync {
                s = self._lastAccountStatusCheck
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._lastAccountStatusCheck = newValue
            })
        }
    }
    
    
    var lastAccountDetailsCheck: Date? {
        get {
            var s: Date?
            accountQueue.sync {
                s = self._lastAccountDetailsCheck
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._lastAccountDetailsCheck = newValue
            })
        }
    }
    
    
    var lastAccountDetailsError: SDKError? {
        get {
            var s: SDKError?
            accountQueue.sync {
                s = self._lastAccountDetailsError
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._lastAccountDetailsError = newValue
            })
        }
    }
    
    var lastAccountStatusError: SDKError? {
        get {
            var s: SDKError?
            accountQueue.sync {
                s = self._lastAccountStatusError
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._lastAccountStatusError = newValue
            })
        }
    }
    
    var lastAccountSignInError: SDKError? {
        get {
            var s: SDKError?
            accountQueue.sync {
                s = self._lastAccountSignInError
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._lastAccountSignInError = newValue
            })
        }
    }
    
    
    var checkingStatus: Bool {
        get {
            var s: Bool = false
            accountQueue.sync {
                s = self._checkingStatus
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._checkingStatus = newValue
            })
        }
    }
    
    
    var checkingDetails: Bool {
        get {
            var s: Bool = false
            accountQueue.sync {
                s = self._checkingDetails
            }
            return s
        }
        set (newValue) {
            accountQueue.sync(flags: .barrier, execute: {
                self._checkingDetails = newValue
            })
        }
    }

    override init() {
        super.init()
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        self.accountLoop()
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func signOut() {
        guard let user = self.currentUser else {
            return
        }
        
        do {
            try self.sdk.deleteKeychainItem(withUser: user.email, service: tokenDomain())
        } catch let error as SDKError {
            SDLogWarn("AccountController", "warning: failed to remove auth token from keychain: \(error.message)")
        } catch {
            fatalError("cannot reach this point")
        }
        
        do {
            try self.sdk.deleteKeychainItem(withUser: user.email, service: accountCredentialDomain())
        } catch let error as SDKError {
            SDLogWarn("AccountController", "warning: failed to remove password from keychain: \(error.message)")
        } catch {
            fatalError("cannot reach this point")
        }
        
        
        self.signedIn = false
        self.signingIn = false
        self.currentUser = nil
        self.email = nil
        self.password = nil
        self.accountState = .unknown
        self.uniqueClientID = nil
        self.uniqueClientName = nil
        
        self.lastAccountStatusCheck = nil
        self.lastAccountDetailsCheck = nil
        
        self.lastAccountStatusError = nil
        self.lastAccountDetailsError = nil
        self.lastAccountSignInError = nil
        
        // reset crashlytics email and telemetry API username
        Crashlytics.sharedInstance().setUserEmail(nil)
        SDErrorHandlerSetUniqueClientId(nil)
        NotificationCenter.default.post(name: Notification.Name.accountSignOut, object: nil)
        
    }
    
    fileprivate func accountLoop() {
        background {
            while true {
                guard let email = self.email, let password = self.password, let uniqueClientID = self.uniqueClientID else {
                    Thread.sleep(forTimeInterval: 1)

                    continue
                }

                if !self.signedIn && !self.signingIn {
                    self.signingIn = true
                    
                    firstly {
                        self.sdk.login(email, password: password, unique_client_id: uniqueClientID)
                    }.then { (status) -> Void in
                        SDErrorHandlerSetUniqueClientId(uniqueClientID)
                        
                        Crashlytics.sharedInstance().setUserEmail(email)
                        Crashlytics.sharedInstance().setUserIdentifier(uniqueClientID)
                        
                        self.signingIn = false
                        self.signedIn = true
                        self.lastAccountStatusCheck = Date()
                        
                        self.lastAccountSignInError = nil
                            
                        DispatchQueue.main.async {
                            SDLogDebug("AccountController", "Account status: \(status)")

                            NotificationCenter.default.post(name: Notification.Name.accountSignIn, object: status)
                        }
                    }.catch { (error) in
                        guard let error = error as? SDKError else {
                            return
                        }
                        self.signingIn = false
                        self.signedIn = false
                        
                        var reportError = false
                        var showError = false
                        
                        // ignore authentication errors and only show the user an error message
                        // if this is the first error and we have not shown this exact error already
                        switch error.kind {
                        case .Authentication:
                            break
                        default:
                            if let existingError = self.lastAccountSignInError {
                                if existingError != error {
                                    self.lastAccountSignInError = error
                                    showError = true
                                    reportError = true
                                }
                            } else {
                                self.lastAccountSignInError = error
                                showError = true
                                reportError = true
                            }
                        }
                        
                        if showError {
                            let title = NSLocalizedString("SafeDrive unavailable", comment: "")
                            
                            SDLogError("AccountController", "signIn() failure (this message will only appear once): \(error.message)")
                            
                            let notification = NSUserNotification()
                                                        
                            var userInfo = [String: Any]()
                            
                            userInfo["identifier"] = SDNotificationType.signInFailed.rawValue
                            
                            notification.userInfo = userInfo
                            
                            notification.informativeText = error.message
                            notification.title = title
                            notification.soundName = NSUserNotificationDefaultSoundName
                            NSUserNotificationCenter.default.deliver(notification)
                        }
                        
                        if reportError && error.kind != .NetworkFailure {
                            SDErrorHandlerReport(error)
                        }
                    }
                    Thread.sleep(forTimeInterval: 1)

                    continue
                    
                }
                
                if !self.signedIn {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                var checkStatus = false
                
                if let lastStatusCheck = self.lastAccountStatusCheck {
                    let now = Date()
                    let d = now.timeIntervalSince(lastStatusCheck)
                    if d > 60 * 5 {
                        checkStatus = true
                    }
                } else {
                    checkStatus = true
                }
                
                
                if checkStatus && !self.checkingStatus {
                    self.checkingStatus = true
                    self.sdk.getAccountStatus(completionQueue: DispatchQueue.main, success: { (status) in
                        self.checkingStatus = false
                        self.lastAccountStatusCheck = Date()
                        self.lastAccountStatusError = nil
                        
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: Notification.Name.accountStatus, object: status)
                        }
                        
                    }, failure: { (error) in
                        self.checkingStatus = false
                        
                        var reportError = false
                        
                        switch error.kind {
                        case .Authentication:
                            break
                        default:
                            if let existingError = self.lastAccountStatusError {
                                if existingError != error {
                                    self.lastAccountStatusError = error
                                    reportError = true
                                }
                            } else {
                                self.lastAccountStatusError = error
                                reportError = true
                            }
                        }
                        
                        if reportError && error.kind != .NetworkFailure {
                            SDLogWarn("AccountController", "Account status retrieval failed (this message will only appear once): \(error.message)")
                            
                            SDErrorHandlerReport(error)
                        }
                    })
                }
                
                var checkDetails = false
                
                if let lastDetailsCheck = self.lastAccountDetailsCheck {
                    let now = Date()
                    let d = now.timeIntervalSince(lastDetailsCheck)
                    if d > 60 * 5 {
                        checkDetails = true
                    }
                } else {
                    checkDetails = true
                }
                if checkDetails && !self.checkingDetails {
                    self.checkingDetails = true
                    
                    self.sdk.getAccountDetails(completionQueue: DispatchQueue.main, success: { (details) in
                        self.checkingDetails = false
                        self.lastAccountDetailsCheck = Date()
                        self.lastAccountDetailsError = nil

                        DispatchQueue.main.async {
                            SDLogDebug("AccountController", "Account details: \(details)")

                            NotificationCenter.default.post(name: Notification.Name.accountDetails, object: details)
                        }
                        
                    }, failure: { (error) in
                        self.checkingDetails = false
                        
                        var reportError = false
                        
                        switch error.kind {
                        case .Authentication:
                            break
                        default:
                            if let existingError = self.lastAccountDetailsError {
                                if existingError != error {
                                    self.lastAccountDetailsError = error
                                    reportError = true
                                }
                            } else {
                                self.lastAccountDetailsError = error
                                reportError = true
                            }
                        }
                        
                        if reportError && error.kind != .NetworkFailure {
                            SDLogWarn("AccountController", "Account details retrieval failed (this message will only appear once): \(error.message)")
                            
                            SDErrorHandlerReport(error)
                        }
                    })
                }

                Thread.sleep(forTimeInterval: 1)

            }
        }
    }
    
}

extension AccountController: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let uniqueClient = notification.object as? Client else {
            SDLogError("AccountController", "API contract invalid: applicationDidConfigureClient()")
            
            return
        }
        
        self.uniqueClientID = uniqueClient.uniqueClientId
        self.uniqueClientName = uniqueClient.uniqueClientName
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let user = notification.object as? User else {
            SDLogError("AccountController", "API contract invalid: applicationDidConfigureUser()")
            
            return
        }
        
        self.currentUser = user
        self.email = user.email
        self.password = user.password
        
        self.lastAccountStatusCheck = nil
        self.lastAccountDetailsCheck = nil
        
        self.lastAccountStatusError = nil
        self.lastAccountDetailsError = nil
        self.lastAccountSignInError = nil
    }
}
