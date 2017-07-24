
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable file_length


import Cocoa

import Crashlytics
import SafeDriveSDK

class WelcomeWindowController: NSWindowController {
    
    fileprivate var installer = Installer(delegate: nil)
    
    fileprivate var welcomeViewController: WelcomeViewController!

    fileprivate var validateDependenciesViewController: ValidateDependenciesViewController!
    fileprivate var validateAccountViewController: ValidateAccountViewController!
    fileprivate var validateClientViewController: ValidateClientViewController!
    fileprivate var readyViewController: ReadyViewController!
    fileprivate var failedViewController: FailedViewController!

    fileprivate var stateQueue = DispatchQueue(label: "io.safedrive.Installer.stateQueue")
    
    fileprivate var state = WelcomeState.welcome
    
    @IBOutlet fileprivate weak var pageController: NSPageController!
    
    // MARK: Initializers
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init() {
        self.init(windowNibName: "WelcomeWindow")
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
    }
    
    override func windowDidLoad() {
        
        let window = self.window as! FlatWindow
        
        window.keepOnTop = true
    
        window.delegate = self

        let pageIdentifiers = ["WelcomeViewController", "ValidateDependenciesViewController", "ValidateAccountViewController", "ValidateClientViewController", "ReadyViewController", "FailedViewController"]
        
        self.welcomeViewController = WelcomeViewController(delegate: self, viewDelegate: self)
        _ = self.welcomeViewController.view

        self.validateDependenciesViewController = ValidateDependenciesViewController(installer: self.installer, delegate: self, viewDelegate: self)
        _ = self.validateDependenciesViewController.view
        
        self.validateAccountViewController = ValidateAccountViewController(delegate: self, viewDelegate: self)
        _ = self.validateAccountViewController.view

        self.validateClientViewController = ValidateClientViewController(delegate: self, viewDelegate: self)
        _ = self.validateClientViewController.view
        
        self.readyViewController = ReadyViewController(delegate: self, viewDelegate: self)
        _ = self.readyViewController.view
        
        self.failedViewController = FailedViewController(delegate: self, viewDelegate: self)
        _ = self.failedViewController.view

        self.pageController.arrangedObjects = pageIdentifiers
        
        self.setWelcomeState(.welcome)
        
    }
    
    func setWelcomeState(_ state: WelcomeState) {
        assert(Thread.current == Thread.main, "NOT MAIN THREAD")
        self.state = state
        SDLog("welcome state changed: \(state)")

        switch state {
        case .welcome:
            self.welcomeViewController.check()
            self.configureMainWindow()
        case .validateDependencies:
            self.validateDependenciesViewController.check()
            self.pageController.navigateForward(to: "ValidateDependenciesViewController")
            self.configureMainWindow()
        case .validateAccount:
            self.validateAccountViewController.check()
            self.pageController.navigateForward(to: "ValidateAccountViewController")
            self.configureMainWindow()
        case .validateClient(let email, let password, let clients):
            self.validateClientViewController.check(email: email, password: password, clients: clients)
            self.pageController.navigateForward(to: "ValidateClientViewController")
            self.configureMainWindow()
        case .ready:
            self.configureMainWindow()
            self.pageController.navigateForward(to: "ReadyViewController")
        case .failed(let error, let uniqueClientID):
            self.configureMainWindow()
            self.pageController.navigateForward(to: "FailedViewController")
            self.failedViewController.fail(error: error, uniqueClientId: uniqueClientID)
        }
    }
    
    func configureMainWindow() {
        assert(Thread.current == Thread.main, "NOT MAIN THREAD")
        switch self.state {
        case .welcome:
            break
        case .validateDependencies:
            break
        case .validateAccount:
            break
        case .validateClient:
            break
        case .ready:
            break
        case .failed:
            break
        }
    }
}



extension WelcomeWindowController: WelcomeStateDelegate {

    func needsWelcome() {
        SDLog("needs welcome")
        self.showWindow(self)
    }
    
    func needsDependencies() {
        SDLog("needs dependencies")
        self.showWindow(self)
    }
    
    func needsAccount() {
        SDLog("needs account")
        self.showWindow(self)
    }
    
    func needsClient() {
        SDLog("needs client configuration")
        self.showWindow(self)
    }
    
    func didWelcomeUser() {
        SDLog("welcomed user")
        self.setWelcomeState(.validateDependencies)
    }

    func didValidateDependencies() {
        SDLog("validated dependencies")
        self.setWelcomeState(.validateAccount)
    }
    
    func didValidateAccount(withEmail email: String, password: String, clients: [SDKSoftwareClient]) {
        SDLog("validated account: \(email)")
        self.setWelcomeState(.validateClient(email: email, password: password, clients: clients))
        let user = User(email: email, password: password)
        NotificationCenter.default.post(name: Notification.Name.applicationDidConfigureUser, object: user)
    }
    
    func didValidateClient(withEmail email: String, password: String, name: String, uniqueClientID: String) {
        SDLog("validated client: \(name) (\(uniqueClientID))")
        do {
            try SafeDriveSDK.sharedSDK.setKeychainItem(withUser: email, service: UCIDDomain(), secret: uniqueClientID)
            self.setWelcomeState(.ready)
            NotificationCenter.default.post(name: Notification.Name.applicationDidConfigureClient, object: uniqueClientID)

        } catch let keychainError as NSError {
            SDLog("failed to insert unique client ID in keychain: \(keychainError)")
            self.setWelcomeState(.failed(error: keychainError, uniqueClientID: uniqueClientID))
        }
    }
    
    func didFail(error: Error, uniqueClientID: String?) {
        SDLog("install failed: \(error)")
        self.setWelcomeState(.failed(error: error, uniqueClientID: uniqueClientID))
    }
    
    func didFinish() {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldFinishConfiguration, object: nil)
        self.close()
    }
}



extension WelcomeWindowController: NSPageControllerDelegate {

    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> String {
        return object as! String
    }

    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: String) -> NSViewController {
    
        if identifier == "WelcomeViewController" {
            return self.welcomeViewController
        } else if identifier == "ValidateDependenciesViewController" {
            return self.validateDependenciesViewController
        } else if identifier == "ValidateAccountViewController" {
            return self.validateAccountViewController
        } else if identifier == "ValidateClientViewController" {
            return self.validateClientViewController
        } else if identifier == "ReadyViewController" {
            return self.readyViewController
        } else if identifier == "FailedViewController" {
            return self.failedViewController
        }
        return NSViewController() // should never reach this point, silencing compiler
    }

    func pageController(_ pageController: NSPageController, prepare viewController: NSViewController, with object: Any?) {
        viewController.representedObject = object
    }

    func pageControllerDidEndLiveTransition(_ pageController: NSPageController) {
        self.pageController.completeTransition()
    }
    
    func pageController(_ pageController: NSPageController, didTransitionTo object: Any) {
        self.configureMainWindow()
    }
}

extension WelcomeWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: Any) -> Bool {
        let alert = NSAlert()
        alert.addButton(withTitle: NSLocalizedString("Yes", comment: "Button title"))
        alert.addButton(withTitle: NSLocalizedString("No", comment: "Button title"))
        alert.alertStyle = .warning
        
        switch state {
        case .welcome:
            alert.messageText = NSLocalizedString("Installation in progress", comment: "String informing the user that an installation is in progress")
            
            alert.informativeText = NSLocalizedString("Are you sure you want to cancel?", comment: "String asking the user if they want to cancel the installation")
            // swiftlint:disable force_unwrapping

            alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    NSApp.terminate(self)
                    break
                default:
                    return
                }
            })
            // swiftlint:enable force_unwrapping

            break
        case .validateDependencies:
            alert.messageText = NSLocalizedString("Installation in progress", comment: "String informing the user that an installation is in progress")
            
            alert.informativeText = NSLocalizedString("Are you sure you want to cancel?", comment: "String asking the user if they want to cancel the installation")
            
            // swiftlint:disable force_unwrapping
            alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    NSApp.terminate(self)
                    break
                default:
                    return
                }
            })
            // swiftlint:enable force_unwrapping

            break
            
        case .validateAccount:
            alert.messageText = NSLocalizedString("SafeDrive requires an account", comment: "String informing the user that safedrive requires an account")
            
            alert.informativeText = NSLocalizedString("Closing this window will close SafeDrive, do you want to do that?", comment: "String asking the user if they want to close safedrive")
            
            // swiftlint:disable force_unwrapping
            alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    NSApp.terminate(self)
                    break
                default:
                    return
                }
            })
            // swiftlint:enable force_unwrapping

            break

        case .validateClient:
            alert.messageText = NSLocalizedString("SafeDrive requires a registered client", comment: "String informing the user that safedrive requires an account")
            
            alert.informativeText = NSLocalizedString("Closing this window will close SafeDrive, do you want to do that?", comment: "String asking the user if they want to close safedrive")
            
            // swiftlint:disable force_unwrapping
            alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    NSApp.terminate(self)
                    break
                default:
                    return
                }
            })
            // swiftlint:enable force_unwrapping

            break
        case .ready:
            return true
        case .failed:
            return true
        }
        return false
    }
}

enum WelcomeState {
    case welcome
    case validateDependencies
    case validateAccount
    case validateClient(email: String, password: String, clients: [SDKSoftwareClient])
    case ready
    case failed(error: Error, uniqueClientID: String?)
}

extension WelcomeState : CustomStringConvertible {
    var description: String {
        switch self {
        case .welcome:
            return "welcome"
        case .validateDependencies:
            return "validating dependencies"
        case .validateAccount:
            return "validating account"
        case .validateClient:
            return "validating client"
        case .ready:
            return "ready"
        case .failed:
            return "failed"
        }
    }
}

extension WelcomeState: RawRepresentable {
    typealias RawValue = Int
    
    init?(rawValue: RawValue) {
        switch rawValue {
        case 0:
            self = .welcome
        case 1:
            self = .validateDependencies
        case 2:
            self = .validateAccount
        case 3:
            self = .validateClient(email: "", password: "", clients: [SDKSoftwareClient]())
        case 4:
            self = .ready
        default:
            return nil
        }
    }
    
    var rawValue: RawValue {
        switch self {
        case .welcome:
            return 0
        case .validateDependencies:
            return 1
        case .validateAccount:
            return 2
        case .validateClient:
            return 3
        case .ready:
            return 4
        case .failed:
            return 5
        }
    }
}

func == (lhs: WelcomeState, rhs: WelcomeState) -> Bool {
    switch (lhs, rhs) {
    case (.welcome, .welcome):
        return true
    case (.validateDependencies, .validateDependencies):
        return true
    case (.validateAccount, .validateAccount):
        return true
    case (let .validateClient(lhs_email, lhs_password, _), let .validateClient(rhs_email, rhs_password, _)):
        return lhs_email == rhs_email && lhs_password == rhs_password
    case (.ready, .ready):
        return true
    case (.failed, .failed):
        return true
    default:
        return false
    }
}

protocol WelcomeStateDelegate: class {
    func needsWelcome()
    func needsDependencies()
    func needsAccount()
    func needsClient()
    func didWelcomeUser()
    func didValidateDependencies()
    func didValidateAccount(withEmail email: String, password: String, clients: [SDKSoftwareClient])
    func didValidateClient(withEmail email: String, password: String, name: String, uniqueClientID: String)
    func didFail(error: Error, uniqueClientID: String?)
    func didFinish()
}

protocol WelcomeViewDelegate: class {
    func showModalWindow(_ window: NSWindow, completionHandler handler: @escaping ((NSModalResponse) -> Void))
    func dismissModalWindow(_ window: NSWindow)
    func showAlert(_ alert: NSAlert, completionHandler handler: @escaping ((NSModalResponse) -> Void))
}

// swiftlint:disable force_unwrapping
extension WelcomeWindowController: WelcomeViewDelegate {
    func showModalWindow(_ window: NSWindow, completionHandler handler: @escaping ((NSModalResponse) -> Void)) {
        self.window!.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window!.beginSheet(window, completionHandler: handler)
    }
    
    
    func dismissModalWindow(_ window: NSWindow) {
        self.window!.endSheet(window)
    }
    
    func showAlert(_ alert: NSAlert, completionHandler handler: @escaping ((NSModalResponse) -> Void)) {
        self.window!.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        
        alert.beginSheetModal(for: self.window!, completionHandler: handler)
    }
}
// swiftlint:enable force_unwrapping

extension WelcomeWindowController: SDAccountProtocol {
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")

    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")

        self.setWelcomeState(.welcome)
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")


    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")


    }
}
