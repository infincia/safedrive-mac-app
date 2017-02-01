
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable type_body_length
// swiftlint:disable file_length

import Cocoa

import Crashlytics

import Realm
import RealmSwift

import SafeDriveSDK

enum ViewType: Int {
    case general
    case account
    case sync
    case encryption
    case status
}


class PreferencesWindowController: NSWindowController, NSOpenSavePanelDelegate, NSPopoverDelegate, SDMountStateProtocol, SDAccountProtocol, SDServiceStatusProtocol {
        
    fileprivate var accountController = AccountController.sharedAccountController
    
    fileprivate var syncScheduler = SyncScheduler.sharedSyncScheduler
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    
    var sharedSystemAPI = SDSystemAPI.shared()
    fileprivate var sharedServiceManager = ServiceManager.sharedServiceManager
    
    
    // ********************************************************
    // MARK: View management
    
    @IBOutlet var containerView: NSView!
    
    // MARK: Tab selections
    @IBOutlet var generalButton: NSButton!
    @IBOutlet var accountButton: NSButton!
    @IBOutlet var encryptionButton: NSButton!
    @IBOutlet var statusButton: NSButton!
    @IBOutlet var syncButton: NSButton!
    
    // MARK: Tab views
    
    @IBOutlet var generalView: NSView!
    @IBOutlet var accountView: NSView!
    @IBOutlet var encryptionView: NSView!
    @IBOutlet var statusView: NSView!
    @IBOutlet var syncView: NSView!
    
    
    // MARK: General Tab
    
    // MARK: Account tab
    @IBOutlet var assignedStorageField: NSTextField!
    @IBOutlet var usedStorageField: NSTextField!
    @IBOutlet var availableStorageField: NSTextField!
    
    @IBOutlet var accountStatusField: NSTextField!
    @IBOutlet var accountExpirationField: NSTextField!
    
    // MARK: Encryption Tab
    @IBOutlet var copyRecoveryPhraseButton: NSButton!
    
    @IBOutlet var recoveryPhraseField: NSTextField!
    
    // MARK: Status Tab
    @IBOutlet var serviceStatusField: NSTextField!
    @IBOutlet var mountStatusField: NSTextField!
    @IBOutlet var volumeSizeField: NSTextField!
    
    @IBOutlet var volumeFreespaceField: NSTextField!
    
    @IBOutlet var volumeUsageBar: NSProgressIndicator!
    
    
    // ********************************************************
    
    
    var autostart: Bool {
        get {
            return self.sharedSystemAPI.autostart()
        }
        set(newValue) {
            var autostartError: NSError?
            if newValue == true {
                autostartError = self.sharedSystemAPI.enableAutostart() as NSError?
            } else {
                autostartError = self.sharedSystemAPI.disableAutostart() as NSError?
            }
            if autostartError != nil {
                SDErrorHandlerReport(autostartError)
            }
        }
    }
    
    // Sync handling
    // TODO: move these and associated logic inside an NSView subclass
    
    @IBOutlet var syncListView: NSOutlineView!
    @IBOutlet var spinner: NSProgressIndicator!
    
    @IBOutlet var progress: NSProgressIndicator!
    
    //@IBOutlet var pathIndicator: NSPathControl!
    
    //@IBOutlet var lastSyncField: NSTextField!
    
    //@IBOutlet var nextSyncField: NSTextField!
    
    @IBOutlet var syncProgressField: NSTextField!
    
    @IBOutlet var syncFailureInfoButton: NSButton!
    
    @IBOutlet var syncStatus: NSTextField!
    
    @IBOutlet var syncTimePicker: NSDatePicker!
    
    @IBOutlet var scheduleSelection: NSPopUpButton!
    
    @IBOutlet var failurePopover: NSPopover!
    
    
    
    fileprivate var syncFolderToken: RealmSwift.NotificationToken?
    
    fileprivate var syncTaskToken: RealmSwift.NotificationToken?
    
    fileprivate var mac: Machine!
    
    fileprivate var uniqueClientID: String!
    
    fileprivate let dbURL: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db")!.appendingPathComponent("sync.realm")
    
    
    
    // Initialization
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindow")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init(uniqueClientID: String) {
        self.init(windowNibName: "PreferencesWindow")
        self.uniqueClientID = uniqueClientID
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
            SDLog("failed to get current machine in realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.mac = currentMachine
        
    }
    
    // Window handling
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        // register SDVolumeEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidMount(_:)), name: Notification.Name.volumeDidMount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidUnmount(_:)), name: Notification.Name.volumeDidUnmount, object: nil)
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted(_:)), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted(_:)), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails(_:)), name: Notification.Name.mountDetails, object: nil)
        
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didAuthenticate(_:)), name: Notification.Name.accountAuthenticated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut(_:)), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus(_:)), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails(_:)), name: Notification.Name.accountDetails, object: nil)
        
        // register SDServiceStatusProtcol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDServiceStatusProtocol.didReceiveServiceStatus(_:)), name: Notification.Name.serviceStatus, object: nil)
        
        
        
        
        self.syncFolderToken = realm.objects(SyncFolder.self).addNotificationBlock { [weak self] (_: RealmCollectionChange) in
            self?.reload()
        }
        
        self.syncTaskToken = realm.objects(SyncTask.self).addNotificationBlock { [weak self] (_: RealmCollectionChange) in
            self?.reload()
        }
        
        self.scheduleSelection.selectItem(at: -1)
        
        self.readSyncFolders(self)
        
        self.setTab(0)        
    }
    
    @IBAction func selectTab(_ sender: AnyObject) {
        
        if let button = sender as? NSButton {
            setTab(button.tag)
        }
    }
    
    func setTab(_ index: NSInteger) {
        guard let newView = viewForIndex(index) else {
            return
        }
        for view in containerView.subviews {
            view.removeFromSuperview()
        }
        containerView.addSubview(newView)
        self.resetButtons()
        //button.highlighted = true
        
    }
    
    fileprivate func resetButtons() {
        //self.generalButton.highlighted = false
        //self.accountButton.highlighted = false
        //self.encryptionButton.highlighted = false
        //self.statusButton.highlighted = false
    }
    
    fileprivate func viewForIndex(_ index: Int) -> NSView? {
        guard let viewType = ViewType(rawValue: index) else {
            return nil
        }
        switch viewType {
        case .general:
            return generalView
        case .account:
            return accountView
        case .encryption:
            return encryptionView
        case .status:
            return statusView
        case .sync:
            return syncView
        }
    }
    
    
    // MARK: SDMountStatusProtocol
    
    func volumeDidMount(_ notification: Foundation.Notification) {
    }
    
    func volumeDidUnmount(_ notification: Foundation.Notification) {
    }
    
    func mountSubprocessDidTerminate(_ notification: Foundation.Notification) {
    }
    
    // MARK: SDMountStateProtocol
    
    func mountStateMounted(_ notification: Foundation.Notification) {
        self.mountStatusField.stringValue = NSLocalizedString("Yes", comment: "String for volume mount status of mounted")
    }
    
    func mountStateUnmounted(_ notification: Foundation.Notification) {
        self.mountStatusField.stringValue = NSLocalizedString("No", comment: "String for volume mount status of unmounted")
    }
    
    func mountStateDetails(_ notification: Foundation.Notification) {
        if let mountDetails = notification.object as? [FileAttributeKey: AnyObject],
            let volumeTotalSpace = mountDetails[FileAttributeKey.systemSize] as? Int,
            let volumeFreeSpace = mountDetails[FileAttributeKey.systemFreeSize] as? Int {
            self.volumeSizeField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(volumeTotalSpace), countStyle: .file)
            self.volumeFreespaceField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(volumeFreeSpace), countStyle: .file)
            let volumeUsedSpace = volumeTotalSpace - volumeFreeSpace
            self.volumeUsageBar.maxValue = Double(volumeTotalSpace)
            self.volumeUsageBar.minValue = 0
            self.volumeUsageBar.doubleValue = Double(volumeUsedSpace)
            
        } else {
            self.volumeSizeField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of mounted")
            self.volumeFreespaceField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of unmounted")
            self.volumeUsageBar.maxValue = 1
            self.volumeUsageBar.minValue = 0
            self.volumeUsageBar.doubleValue = 0
        }
    }
    
    // MARK: SDAccountProtocol
    
    func didAuthenticate(_ notification: Foundation.Notification) {
        guard let email = self.accountController.email else {
            return
        }
        // get recovery phrase from keychain
        
        let recoveryCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: recoveryKeyDomain())
        let recoveryPhrase = recoveryCredentials?["password"]

        
        self.sdk.loadKeys(recoveryPhrase, completionQueue: DispatchQueue.main, storePhrase: { (newPhrase) in
            
            print("New recovery phrase: \(newPhrase)")
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            
            alert.messageText = "New recovery phrase"
            alert.informativeText = "A recovery phrase has been generated for your account, please write it down and keep it in a safe place:\n\n\(newPhrase)"
            alert.alertStyle = .informational
            
            alert.beginSheetModal(for: self.window!, completionHandler: { (_) in
                
            })
            
            let keychainError = SDSystemAPI.shared().insertCredentialsInKeychain(forService: recoveryKeyDomain(), account: email, password: newPhrase)
            
            if let keychainError = keychainError {
                SDErrorHandlerReport(keychainError)
                return
            }
            
        }, success: {
            let recoveryCredentials = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: recoveryKeyDomain())

            if let recoveryPhrase = recoveryCredentials?["password"] {
                self.recoveryPhraseField.stringValue = recoveryPhrase
                self.copyRecoveryPhraseButton.isEnabled = true
            } else {
                self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
                self.copyRecoveryPhraseButton.isEnabled = false
            }
        }, failure: { (error) in
            SDLog("failed to load keys with sdk: \(error.message)")
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
                self.setTab(3)
                self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
                self.copyRecoveryPhraseButton.isEnabled = false
                
                self.window?.makeKeyAndOrderFront(self)
                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                
                alert.messageText = "Recovery phrase incorrect"
                alert.informativeText = "A recovery phrase is set for your account, but this computer does not have it"
                alert.alertStyle = .critical
                
                alert.beginSheetModal(for: self.window!, completionHandler: { (_) in
                    
                })
            
            case .InsufficientFreeSpace:
                break
            case .Authentication:
                self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
                self.copyRecoveryPhraseButton.isEnabled = false
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
            }
        })
    }
    
    func didSignOut(_ notification: Foundation.Notification) {
        
    }
    
    func didReceiveAccountStatus(_ notification: Foundation.Notification) {
        if let accountStatus = notification.object as? AccountStatus,
            let status = accountStatus.status {
            self.accountStatusField.stringValue = status.capitalized
        } else {
            self.accountStatusField.stringValue = NSLocalizedString("Unknown", comment:"")
            SDLog("Validation failed: didReceiveAccountStatus")
   
        }
    }
    
    func didReceiveAccountDetails(_ notification: Foundation.Notification) {
        if let accountDetails = notification.object as? AccountDetails {
        
            let assignedStorage = accountDetails.assignedStorage
            let usedStorage = accountDetails.usedStorage
            let expirationDate = accountDetails.expirationDate
            
            self.assignedStorageField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(assignedStorage), countStyle: .file)
            self.usedStorageField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(usedStorage), countStyle: .file)
            
            let date: Date = Date(timeIntervalSince1970: Double(expirationDate) / 1000)
            let dateFormatter: DateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            dateFormatter.timeStyle = .none
            dateFormatter.dateStyle = .short
            self.accountExpirationField.stringValue = dateFormatter.string(from: date)
        } else {
            SDLog("Validation failed: didReceiveAccountDetails")
        }
    }
    
    // MARK: SDServiceStatusProtocol
    
    func didReceiveServiceStatus(_ notification: Foundation.Notification) {
        if let status = notification.object as? Bool {
            self.serviceStatusField.stringValue = (status == true ? "Running" : "Stopped")
        } else {
            SDLog("Validation failed: didReceiveServiceStatus")
        }
    }
    
    // MARK: UI Actions
    
    @IBAction func copyRecoveryPhrase(_ sender: AnyObject) {
        let pasteBoard = NSPasteboard.general()
        pasteBoard.clearContents()
        pasteBoard.writeObjects([recoveryPhraseField.stringValue as NSString])
    }
    
    @IBAction func loadAccountPage(_ sender: AnyObject) {
        // Open the safedrive account page in users default browser
        if let _ = self.accountController.email,
            let url = URL(string: "https://\(webDomain())/#/en/dashboard/account/details") {
            NSWorkspace.shared().open(url)
        }
    }
    
    @IBAction func addSyncFolder(_ sender: AnyObject) {
        let panel: NSOpenPanel = NSOpenPanel()
        
        let encryptedCheckbox = NSButton()
        let encryptedCheckboxTitle: String = NSLocalizedString("Encrypted", comment: "Option in select folder panel")
        encryptedCheckbox.title = encryptedCheckboxTitle
        encryptedCheckbox.setButtonType(.switch)
        encryptedCheckbox.state = 1 //true
        panel.accessoryView = encryptedCheckbox
        
        panel.delegate = self
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        let panelTitle: String = NSLocalizedString("Select a folder", comment: "Title of window")
        panel.title = panelTitle
        let promptString: String = NSLocalizedString("Select", comment: "Button title")
        panel.prompt = promptString
        
        panel.beginSheetModal(for: self.window!) { (result)  in
            if result == NSFileHandlingPanelOKButton {
                self.spinner.startAnimation(self)
                let isEncrypted = (encryptedCheckbox.state == 1)
                
                let folderName = panel.url!.lastPathComponent.lowercased()
                let folderPath = panel.url!.path
                
                self.sdk.addFolder(folderName, path: folderPath, completionQueue: DispatchQueue.main, success: { (folderID) in
                    guard let realm = try? Realm() else {
                        SDLog("failed to create realm!!!")
                        Crashlytics.sharedInstance().crash()
                        return
                    }
                    
                    let syncFolder = SyncFolder(name: panel.url!.lastPathComponent, url: panel.url!, uniqueID: Int32(folderID), encrypted: isEncrypted)
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder.added = Date()
                    
                    syncFolder.machine = self.mac
                    
                    // swiftlint:disable force_try
                    try! realm.write {
                        realm.add(syncFolder, update: true)
                    }
                    // swiftlint:enable force_try

                    self.readSyncFolders(self)
                    
                    self.startSync(folderID, encrypted: syncFolder.encrypted)
                }, failure: { (error) in
                    SDErrorHandlerReport(error)
                    self.spinner.stopAnimation(self)
                    let alert: NSAlert = NSAlert()
                    alert.messageText = NSLocalizedString("Error adding folder to your account", comment: "")
                    alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                    alert.runModal()
                })
            }
        }
    }
    
    @IBAction func removeSyncFolder(_ sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let uniqueID: UInt64 = UInt64(button.tag)
        SDLog("Deleting sync folder ID: %lu", uniqueID)
        let alert = NSAlert()
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Move to Storage folder")
        alert.addButton(withTitle: "Delete")
        
        alert.messageText = "Stop syncing this folder?"
        alert.informativeText = "The synced files will be deleted from SafeDrive or moved to your Storage folder.\n\nWhich one would you like to do?"
        alert.alertStyle = .informational
        
        alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
            
            var op: SDSFTPOperation
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                op = .moveFolder
                break
            case NSAlertThirdButtonReturn:
                op = .deleteFolder
                break
            default:
                return
            }
            self.spinner.startAnimation(self)
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
                return
            }
            let syncFolders = realm.objects(SyncFolder.self)
            
            let syncFolder = syncFolders.filter("machine == %@ AND uniqueID == %@", currentMachine, uniqueID).last!
            
            let defaultFolder: URL = URL(string: SDDefaultServerPath)!
            let machineFolder: URL = defaultFolder.appendingPathComponent(syncFolder.machine!.name!, isDirectory: true)
            let remoteFolder: URL = machineFolder.appendingPathComponent(syncFolder.name!, isDirectory: true)
            var urlComponents: URLComponents = URLComponents()
            urlComponents.user = self.accountController.internalUserName
            urlComponents.password = self.accountController.password
            urlComponents.host = self.accountController.remoteHost
            urlComponents.path = remoteFolder.path
            urlComponents.port = Int(self.accountController.remotePort!)
            let remote: URL = urlComponents.url!
            
            self.syncScheduler.cancel(uniqueID) {
                let syncController = SyncController()
                syncController.uniqueID = uniqueID
                syncController.sftpOperation(op, remoteDirectory: remote, password: self.accountController.password!, success: {
                    
                    self.sdk.removeFolder(uniqueID, completionQueue: DispatchQueue.main, success: { 
                        guard let realm = try? Realm() else {
                            SDLog("failed to create realm!!!")
                            Crashlytics.sharedInstance().crash()
                            return
                        }
                        
                        let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last!
                        
                        let syncTasks = realm.objects(SyncTask.self).filter("syncFolder.uniqueID == %@", uniqueID)
                        
                        do {
                            try realm.write {
                                realm.delete(syncTasks)
                            }
                        } catch {
                            print("failed to delete sync tasks associated with \(uniqueID)")
                        }
                        
                        let syncFolder = realm.objects(SyncFolder.self).filter("machine == %@ AND uniqueID == %@", currentMachine, uniqueID).last!
                        
                        do {
                            try realm.write {
                                realm.delete(syncFolder)
                            }
                        } catch {
                            print("failed to delete sync folder \(uniqueID)")
                        }
                        self.reload()
                        self.spinner.stopAnimation(self)
                    }, failure: { (error) in
                        SDErrorHandlerReport(error)
                        self.spinner.stopAnimation(self)
                        let alert: NSAlert = NSAlert()
                        alert.messageText = NSLocalizedString("Error removing folder from your account", comment: "")
                        alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                        alert.runModal()
                    })
                }, failure: { (error) in
                    SDErrorHandlerReport(error)
                    self.spinner.stopAnimation(self)
                    let alert: NSAlert = NSAlert()
                    alert.messageText = NSLocalizedString("Error moving folder to Storage", comment: "")
                    alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help:\n\n \(error.localizedDescription)", comment: "")
                    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                    alert.runModal()
                })
            }
        })
    }
    
    @IBAction func readSyncFolders(_ sender: AnyObject) {
        self.spinner.startAnimation(self)
        
        self.sdk.getFolders(completionQueue: DispatchQueue.main, success: { (folders: [Folder]) in
            for folder in folders {
                /*
                 Current sync folder model:
                 
                 "id" : 1,
                 "folderName" : "Music",
                 "folderPath" : /Volumes/MacOS/Music,
                 "addedDate"  : 1435864769463,
                 "encrypted"  : false
                 */
                
                let folderName = folder.name
                let folderPath = folder.path
                let folderId = folder.id
                
                let addedUnixDate = Double(folder.date)
                
                let addedDate: Date = Date(timeIntervalSince1970: addedUnixDate/1000)
                
                let encrypted = folder.encrypted
                
                
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
                    SDLog("failed to get machine from realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                // try to retrieve and modify existing record if possible, avoids overwriting preferences only stored in entity
                // while still ensuring entities will have a default set on them for things like sync time
                var syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderId).last
                
                if syncFolder == nil {
                    syncFolder = SyncFolder(name: folderName, path: folderPath, uniqueID: Int32(folderId), encrypted: encrypted)
                }
                
                // swiftlint:disable force_try
                try! realm.write {
                    
                    syncFolder!.machine = currentMachine
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder!.added = addedDate
                    
                    realm.add(syncFolder!, update: true)
                }
                // swiftlint:enable force_try

            }
            self.reload()
            
            self.spinner.stopAnimation(self)
            
            // select the first row automatically
            let count = self.syncListView!.numberOfRows
            if count >= 1 {
                let indexSet = IndexSet(integer: 1)
                self.syncListView!.selectRowIndexes(indexSet, byExtendingSelection: false)
                self.syncListView!.becomeFirstResponder()
            }
            
        }, failure: { (error) in
            SDErrorHandlerReport(error)
            self.spinner.stopAnimation(self)
            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error reading folders from your account", comment: "")
            alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.runModal()
        })
    }
    
    @IBAction func startSyncNow(_ sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let folderID: UInt64 = UInt64(button.tag)
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
            SDLog("failed to get machine from realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        let folder = realm.objects(SyncFolder.self).filter("machine == %@ AND uniqueID == %@", currentMachine, folderID).last!
        
        startSync(folderID, encrypted: folder.encrypted)
    }
    
    @IBAction func startRestoreNow(_ sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let folderID: UInt64 = UInt64(button.tag)
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
            SDLog("failed to get machine from realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        let folder = realm.objects(SyncFolder.self).filter("machine == %@ AND uniqueID == %@", currentMachine, folderID).last!
        
        var name: UUID
        if folder.encrypted {
            name = UUID()
            // TODO: show a window asking the user to pick from the list of available sessions and grab the name
            let message = "Restoring encrypted folders is not implemented in mac app yet\n\nWe still need to add a session selection screen to allow a specific version to be restored"
            
            DispatchQueue.main.async(execute: {() -> Void in
                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                alert.messageText = "Not implemented yet"
                alert.informativeText = message
                alert.alertStyle = NSAlertStyle.critical
                alert.runModal()
            })
            return
        } else {
            // unencrypted folders have no versioning, so the name is arbitrary
            name = UUID()
        }
        startRestore(folderID, encrypted: folder.encrypted, name: name)
    }
    
    @IBAction func stopSyncNow(_ sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let folderID: UInt64 = UInt64(button.tag)
        stopSync(folderID)
    }
    
    
    // MARK: Sync control
    
    func startSync(_ folderID: UInt64, encrypted: Bool) {
        let type: SyncType = encrypted ? .encrypted : .unencrypted
        self.syncScheduler.queueSyncJob(self.uniqueClientID, folderID: folderID, direction: .forward, type: type, name: UUID())
    }
    
    func startRestore(_ folderID: UInt64, encrypted: Bool, name: UUID) {
        let type: SyncType = encrypted ? .encrypted : .unencrypted
        
        let alert = NSAlert()
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")
        
        alert.messageText = "Restore folder?"
        alert.informativeText = "This will restore the selected folder contents from your SafeDrive.\n\nWarning: Any local files that have not been previously synced to SafeDrive may be lost."
        alert.alertStyle = .informational
        
        alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
            
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                // cancel any sync in progress so we don't have two rsync processes overwriting each other
                self.syncScheduler.cancel(folderID) {
                    self.syncScheduler.queueSyncJob(self.uniqueClientID, folderID: folderID, direction: .reverse, type: type, name: name)
                }
                break
            default:
                return
            }
        })
    }
    
    func stopSync(_ folderID: UInt64) {
        
        let alert = NSAlert()
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")
        
        alert.messageText = "Cancel sync?"
        alert.informativeText = "This folder is currently syncing, do you want to cancel?"
        alert.alertStyle = .informational
        
        alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
            
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                self.syncScheduler.cancel(folderID) {
                    
                }
                break
            default:
                return
            }
        })
    }
    
    // MARK: NSOpenSavePanelDelegate
    
    func panel(_ sender: Any, validate url: URL) throws {
        let fileManager: FileManager = FileManager.default
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFile(atPath: url.path) {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSystemError.filePermissionDenied.rawValue, userInfo: errorInfo)
        }
        
        // check if the candidate sync path is a parent or subdirectory of an existing registered sync folder
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open local database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorSyncDomain, code: SDDatabaseError.openFailed.rawValue, userInfo: errorInfo)
        }
        
        let syncFolders = realm.objects(SyncFolder.self)
        if SyncFolder.hasConflictingFolderRegistered(url.path, syncFolders: syncFolders) {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSyncError.folderConflict.rawValue, userInfo: errorInfo)
        }
    }
    
    // MARK: NSOutlineViewDelegate/Datasource
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.reload()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if item is Machine {
            return true
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item is Machine {
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return 0
            }
            guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", uniqueClientID).last else {
                return 0
            }
            let syncFolders = realm.objects(SyncFolder.self).filter("machine == %@", currentMachine)
            return syncFolders.count
        } else if item is SyncFolder {
            return 0
        }
        // Root
        return 1
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return "" as AnyObject
        }
        if item is Machine {
            let syncFolders = realm.objects(SyncFolder.self).filter("machine == %@", self.mac).sorted(byKeyPath: "name")
            let syncFolder = syncFolders[index]
            let detached = SyncFolder(value: syncFolder)
            return detached
        }
        return self.mac
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        if item is Machine {
            return true
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        return !self.outlineView(outlineView, isGroupItem: item)
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowCellExpansionForTableColumn tableColumn: NSTableColumn, item: AnyObject) -> Bool {
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: AnyObject) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: AnyObject) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: AnyObject) -> NSTableRowView {
        let v: SyncManagerTableRowView = SyncManagerTableRowView()
        return v
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn, item: AnyObject) -> NSView {
        var tableCellView: SyncManagerTableCellView
        if item is Machine {
            tableCellView = outlineView.make(withIdentifier: "MachineView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = self.mac.name!
            let cellImage: NSImage = NSImage(named: NSImageNameComputer)!
            cellImage.size = CGSize(width: 15.0, height: 15.0)
            tableCellView.imageView!.image = cellImage
        } else if item is SyncFolder {
            let syncFolder = item as! SyncFolder
            tableCellView = outlineView.make(withIdentifier: "FolderView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = syncFolder.name!.capitalized
            let cellImage: NSImage = NSWorkspace.shared().icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            cellImage.size = CGSize(width: 15.0, height: 15.0)
            tableCellView.imageView!.image = cellImage
            tableCellView.removeButton.tag = Int(syncFolder.uniqueID)
            tableCellView.syncNowButton.tag = Int(syncFolder.uniqueID)
            tableCellView.restoreNowButton.tag = Int(syncFolder.uniqueID)
            
            if syncFolder.syncing || syncFolder.restoring {
                tableCellView.restoreNowButton.isEnabled = false
                tableCellView.restoreNowButton.target = self
                tableCellView.restoreNowButton.action = #selector(self.stopSyncNow(_:))
                
                tableCellView.syncNowButton.isEnabled = true
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.stopSyncNow(_:))
            }
            
            if syncFolder.encrypted {
                tableCellView.lockButton.image = NSImage(named: NSImageNameLockLockedTemplate)
            } else {
                tableCellView.lockButton.image = NSImage(named: NSImageNameLockUnlockedTemplate)
            }
            
            if syncFolder.syncing {
                tableCellView.syncStatus.startAnimation(self)
                tableCellView.restoreNowButton.image = NSImage(named: NSImageNameInvalidDataFreestandingTemplate)
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameStopProgressFreestandingTemplate)
            } else if syncFolder.restoring {
                tableCellView.syncStatus.startAnimation(self)
                tableCellView.restoreNowButton.image = NSImage(named: NSImageNameStopProgressFreestandingTemplate)
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameRefreshFreestandingTemplate)
            } else {
                tableCellView.syncStatus.stopAnimation(self)
                
                tableCellView.restoreNowButton.isEnabled = true
                tableCellView.restoreNowButton.target = self
                tableCellView.restoreNowButton.action = #selector(self.startRestoreNow(_:))
                tableCellView.restoreNowButton.image = NSImage(named: NSImageNameInvalidDataFreestandingTemplate)
                
                tableCellView.syncNowButton.isEnabled = true
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.startSyncNow(_:))
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameRefreshFreestandingTemplate)
                
            }
        } else {
            tableCellView = outlineView.make(withIdentifier: "FolderView", owner: self) as! SyncManagerTableCellView
        }
        tableCellView.representedSyncItem = item
        
        return tableCellView
        
    }
    
    
    //--------------------------
    // Selection tracking
    //--------------------------
    // NOTE: This really needs to be refactored into a view to limite how massive this VC is becoming
    func outlineViewSelectionDidChange(_ notification: Foundation.Notification) {
        if self.syncListView.selectedRow != -1 {
            guard let syncItem: SyncFolder = self.syncListView.item(atRow: self.syncListView.selectedRow) as? SyncFolder else {
                SDLog("no item at \(self.syncListView.selectedRow)")
                return
            }
            
            if let syncTime = syncItem.syncTime {
                self.syncTimePicker.dateValue = syncTime as Date
            } else {
                SDLog("Failed to load date in sync manager")
            }
            
            /*if let syncURL = syncItem.url {
             self.pathIndicator.URL = syncURL
             }
             else {
             SDLog("Failed to load path in sync manager")
             }*/
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            self.progress.maxValue = 100.0
            self.progress.minValue = 0.0
            let syncTasks = realm.objects(SyncTask.self)
            
            if let syncTask = syncTasks.filter("syncFolder.machine.uniqueClientID == %@ AND syncFolder == %@", self.mac.uniqueClientID!, syncItem).sorted(byKeyPath: "syncDate").last {
                
                if syncItem.restoring {
                    self.syncStatus.stringValue = "Restoring"
                    self.syncFailureInfoButton.action = nil
                    self.syncFailureInfoButton.isHidden = true
                    self.syncFailureInfoButton.isEnabled = false
                    self.syncFailureInfoButton.toolTip = ""
                    self.progress.startAnimation(nil)
                    
                    self.progress.doubleValue = syncTask.progress
                    self.syncProgressField.stringValue = "\(syncTask.progress)% @ \(syncTask.bandwidth)"
                } else if syncItem.syncing {
                    self.syncStatus.stringValue = "Syncing"
                    self.syncFailureInfoButton.action = nil
                    self.syncFailureInfoButton.isHidden = true
                    self.syncFailureInfoButton.isEnabled = false
                    self.syncFailureInfoButton.toolTip = ""
                    self.progress.startAnimation(nil)
                    
                    self.progress.doubleValue = syncTask.progress
                    self.syncProgressField.stringValue = "\(syncTask.progress)% @ \(syncTask.bandwidth)"
                } else if syncTask.success {
                    self.syncStatus.stringValue = "Waiting"
                    self.syncFailureInfoButton.action = nil
                    self.syncFailureInfoButton.isHidden = true
                    self.syncFailureInfoButton.isEnabled = false
                    self.syncFailureInfoButton.toolTip = ""
                    self.progress.stopAnimation(nil)
                    
                    self.progress.doubleValue = 100.0
                    self.syncProgressField.stringValue = ""
                    
                } else {
                    self.syncStatus.stringValue = "Failed"
                    self.syncFailureInfoButton.action = #selector(self.showFailurePopover)
                    self.syncFailureInfoButton.isHidden = false
                    self.syncFailureInfoButton.isEnabled = true
                    self.syncFailureInfoButton.toolTip = NSLocalizedString("Last sync failed, click here for details", comment: "")
                    self.progress.stopAnimation(nil)
                    
                    self.progress.doubleValue = 0.0
                    self.syncProgressField.stringValue = ""
                    
                }
                let failureView = self.failurePopover.contentViewController!.view as! SyncFailurePopoverView
                failureView.message.stringValue = syncTask.message ?? ""
            } else {
                self.syncStatus.stringValue = "Unknown"
                self.syncFailureInfoButton.action = nil
                self.syncFailureInfoButton.isHidden = true
                self.syncFailureInfoButton.isEnabled = false
                self.syncFailureInfoButton.toolTip = nil
                self.progress.stopAnimation(nil)
                
                self.progress.doubleValue = 0.0
                
                self.syncProgressField.stringValue = ""
            }
            
            /*if let syncTask = syncTasks.filter("syncFolder.machine.uniqueClientID == '\(self.mac.uniqueClientID!)' AND syncFolder == %@ AND success == true", syncItem).sorted("syncDate").last,
             lastSync = syncTask.syncDate {
             self.lastSyncField.stringValue = lastSync.toMediumString()
             }
             else {
             self.lastSyncField.stringValue = ""
             }*/
            
            switch syncItem.syncFrequency {
            case "hourly":
                self.scheduleSelection.selectItem(at: 0)
                //self.nextSyncField.stringValue = NSDate().nextHour()?.toMediumString() ?? ""
                self.syncTimePicker.isEnabled = false
                self.syncTimePicker.isHidden = true
                var components = DateComponents()
                components.hour = 0
                components.minute = 0
                let calendar = Calendar.current
                self.syncTimePicker.dateValue = calendar.date(from: components)!
            case "daily":
                self.scheduleSelection.selectItem(at: 1)
                //self.nextSyncField.stringValue = NSDate().nextDayAt((syncItem.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.isEnabled = true
                self.syncTimePicker.isHidden = false
            case "weekly":
                self.scheduleSelection.selectItem(at: 2)
                //self.nextSyncField.stringValue = NSDate().nextWeekAt((syncItem.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.isEnabled = true
                self.syncTimePicker.isHidden = false
            case "monthly":
                self.scheduleSelection.selectItem(at: 3)
                //self.nextSyncField.stringValue = NSDate().nextMonthAt((syncItem.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.isEnabled = true
                self.syncTimePicker.isHidden = false
            default:
                self.scheduleSelection.selectItem(at: -1)
                //self.nextSyncField.stringValue = ""
                self.syncTimePicker.isEnabled = false
                self.syncTimePicker.isHidden = false
            }
            self.scheduleSelection.isEnabled = true
        } else {
            //self.lastSyncField.stringValue = ""
            //self.nextSyncField.stringValue = ""
            self.scheduleSelection.selectItem(at: -1)
            self.scheduleSelection.isEnabled = false
            self.syncStatus.stringValue = "Unknown"
            self.syncFailureInfoButton.action = nil
            self.syncFailureInfoButton.isHidden = true
            self.syncFailureInfoButton.isEnabled = false
            self.syncFailureInfoButton.toolTip = nil
            self.syncTimePicker.isEnabled = false
            self.syncTimePicker.isHidden = true
            var components = DateComponents()
            components.hour = 0
            components.minute = 0
            let calendar = Calendar.current
            self.syncTimePicker.dateValue = calendar.date(from: components)!
            //self.pathIndicator.URL = nil
            self.progress.doubleValue = 0.0
            self.syncProgressField.stringValue = ""
            
        }
    }
    
    @IBAction func setSyncFrequencyForFolder(_ sender: AnyObject) {
        if self.syncListView.selectedRow != -1 {
            let syncItem: SyncFolder = self.syncListView.item(atRow: self.syncListView.selectedRow) as! SyncFolder
            let uniqueID = syncItem.uniqueID
            
            var syncFrequency: String
            
            switch self.scheduleSelection.indexOfSelectedItem {
            case 0:
                syncFrequency = "hourly"
            case 1:
                syncFrequency = "daily"
            case 2:
                syncFrequency = "weekly"
            case 3:
                syncFrequency = "monthly"
            default:
                syncFrequency = "daily"
            }
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
                SDLog("failed to get current machine in realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            let syncFolders = realm.objects(SyncFolder.self)
            
            let realSyncFolder = syncFolders.filter("machine == %@ AND uniqueID == %@", currentMachine, uniqueID).last!
            // swiftlint:disable force_try
            try! realm.write {
                realSyncFolder.syncFrequency = syncFrequency
            }
            // swiftlint:enable force_try
        }
    }
    
    
    fileprivate func reload() {
        assert(Thread.isMainThread, "Not main thread!!!")
        let oldFirstResponder = self.window?.firstResponder
        let selectedIndexes = self.syncListView.selectedRowIndexes
        self.syncListView.reloadItem(self.mac, reloadChildren: true)
        self.syncListView.expandItem(self.mac, expandChildren: true)
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: true)
        self.window?.makeFirstResponder(oldFirstResponder)
    }
    
    @objc
    fileprivate func showFailurePopover() {
        self.failurePopover.show(relativeTo: self.syncFailureInfoButton.bounds, of: self.syncFailureInfoButton, preferredEdge: .minY)
    }
    
    @IBAction
    func setSyncTime(_ sender: AnyObject) {
        if self.syncListView.selectedRow != -1 {
            let syncItem: SyncFolder = self.syncListView.item(atRow: self.syncListView.selectedRow) as! SyncFolder
            let uniqueID = syncItem.uniqueID
            
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == %@", self.uniqueClientID).last else {
                SDLog("failed to get current machine in realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            let syncFolders = realm.objects(SyncFolder.self)
            
            let realSyncFolder = syncFolders.filter("machine == %@ AND uniqueID == %@", currentMachine, uniqueID).last!
            // swiftlint:disable force_try
            try! realm.write {
                realSyncFolder.syncTime = self.syncTimePicker.dateValue
            }
            // swiftlint:enable force_try
        }
    }
    
    
}
