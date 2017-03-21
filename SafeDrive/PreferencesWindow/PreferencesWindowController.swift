
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


class PreferencesWindowController: NSWindowController, NSPopoverDelegate {

    fileprivate var syncScheduler = SyncScheduler.sharedSyncScheduler
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var recoveryPhraseEntry: RecoveryPhraseWindowController!
    
    fileprivate var restoreSelection: RestoreSelectionWindowController!

    
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
    
    @IBOutlet var volumeNameField: NSTextField!
    @IBOutlet var volumeNameWarningField: NSTextField!
    
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
            if newValue == true {
                do {
                    try self.sharedSystemAPI.enableAutostart()
                } catch let error as NSError {
                    SDErrorHandlerReport(error)
                }
            } else {
                do {
                    try self.sharedSystemAPI.disableAutostart()
                } catch let error as NSError {
                    SDErrorHandlerReport(error)
                }
            }
        }
    }
    
    // Sync handling
    // TODO: move these and associated logic inside an NSView subclass
    
    @IBOutlet var syncListView: NSTableView!
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
    
    fileprivate var folders: Results<SyncFolder>?
    
    fileprivate var realm: Realm?
    
    fileprivate var uniqueClientID: String?
    
    fileprivate let dbURL: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db")!.appendingPathComponent("sync.realm")
    
    
    var email: String?
    var internalUserName: String?
    var password: String?
    
    var remoteHost: String?
    var remotePort: UInt16?
    
    // Initialization
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindow")
        self.recoveryPhraseEntry = RecoveryPhraseWindowController(delegate: self)
    }
    
    // Window handling
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
        
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDServiceStatusProtcol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDServiceStatusProtocol.didReceiveServiceStatus), name: Notification.Name.serviceStatus, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureRealm), name: Notification.Name.applicationDidConfigureRealm, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        self.scheduleSelection.selectItem(at: -1)
        
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

    
    // MARK: UI Actions
    
    @IBAction func copyRecoveryPhrase(_ sender: AnyObject) {
        let pasteBoard = NSPasteboard.general()
        pasteBoard.clearContents()
        pasteBoard.writeObjects([recoveryPhraseField.stringValue as NSString])
    }
    
    @IBAction func signOut(_ sender: AnyObject) {
        AccountController.sharedAccountController.signOut()
    }
    
    @IBAction func loadAccountPage(_ sender: AnyObject) {
        // Open the safedrive account page in users default browser
        let url = URL(string: "https://\(webDomain())/#/en/dashboard/account/details")
        NSWorkspace.shared().open(url!)
    }
    
    @IBAction func addSyncFolder(_ sender: AnyObject) {
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
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
                    guard let realm = self.realm else {
                        SDLog("failed to get realm!!!")
                        Crashlytics.sharedInstance().crash()
                        return
                    }
                    
                    let syncFolder = SyncFolder(name: panel.url!.lastPathComponent, url: panel.url!, uniqueID: Int32(folderID), encrypted: isEncrypted)
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder.added = Date()
                    
                    syncFolder.uniqueClientID = uniqueClientID
                    
                    // swiftlint:disable force_try
                    try! realm.write {
                        realm.add(syncFolder, update: true)
                    }
                    // swiftlint:enable force_try

                    self.readSyncFolders(self)
                    
                    self.sync(folderID, encrypted: syncFolder.encrypted)
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
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
        guard let _ = self.email,
            let localPassword = self.password,
            let localInternalUserName = self.internalUserName,
            let localPort = self.remotePort,
            let localHost = self.remoteHost else {
            SDLog("credentials unavailable, cancelling remove sync folder")
            return
        }
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
            guard let realm = self.realm else {
                SDLog("failed to get realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }

            let syncFolders = realm.objects(SyncFolder.self)
            
            let syncFolder = syncFolders.filter("uniqueID == %@", uniqueID).last!
            
            let host = Host()
            let machineName = host.localizedName!
            
            let defaultFolder: URL = URL(string: SDDefaultServerPath)!
            let machineFolder: URL = defaultFolder.appendingPathComponent(machineName, isDirectory: true)
            let remoteFolder: URL = machineFolder.appendingPathComponent(syncFolder.name!, isDirectory: true)
            var urlComponents: URLComponents = URLComponents()
            urlComponents.user = localInternalUserName
            urlComponents.password = localPassword
            urlComponents.host = localHost
            urlComponents.path = remoteFolder.path
            urlComponents.port = Int(localPort)
            let remote: URL = urlComponents.url!
            
            self.syncScheduler.cancel(uniqueID) {
                let syncController = SyncController()
                syncController.uniqueID = uniqueID
                syncController.sftpOperation(op, remoteDirectory: remote, password: localPassword, success: {
                    
                    self.sdk.removeFolder(uniqueID, completionQueue: DispatchQueue.main, success: { 
                        guard let realm = self.realm else {
                            SDLog("failed to get realm!!!")
                            Crashlytics.sharedInstance().crash()
                            return
                        }
                        
                        let syncTasks = realm.objects(SyncTask.self).filter("syncFolder.uniqueID == %@", uniqueID)
                        
                        do {
                            try realm.write {
                                realm.delete(syncTasks)
                            }
                        } catch {
                            print("failed to delete sync tasks associated with \(uniqueID)")
                        }
                        
                        let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", uniqueID).last!
                        
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
        guard let uniqueClientID = self.uniqueClientID,
        let realm = self.realm else {
            return
        }
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
                 "syncing"    : false
                 */
                
                let folderName = folder.name
                let folderPath = folder.path
                let folderId = folder.id
                let syncing = folder.syncing
                
                let addedUnixDate = Double(folder.date)
                
                let addedDate: Date = Date(timeIntervalSince1970: addedUnixDate/1000)
                
                let encrypted = folder.encrypted
                
                // try to retrieve and modify existing record if possible, avoids overwriting preferences only stored in entity
                // while still ensuring entities will have a default set on them for things like sync time
                var syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderId).last
                
                if syncFolder == nil {
                    syncFolder = SyncFolder(name: folderName, path: folderPath, uniqueID: Int32(folderId), encrypted: encrypted)
                }
                
                // swiftlint:disable force_try
                try! realm.write {
                    
                    syncFolder!.uniqueClientID = uniqueClientID
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder!.added = addedDate
                    
                    // what the server calls 'syncing', we call 'active' to avoid confusion with syncing/restoring states
                    syncFolder!.active = syncing
                    
                    syncFolder!.path = folderPath
                    
                    syncFolder!.name = folderName
                    
                    realm.add(syncFolder!, update: true)
                }
                // swiftlint:enable force_try

            }
            realm.refresh()
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
        guard let _ = self.uniqueClientID else {
            return
        }
        
        let button: NSButton = sender as! NSButton
        let folderID: UInt64 = UInt64(button.tag)
        
        if let folders = self.folders,
            let folder = folders.filter("uniqueID == %@", folderID).last {
            sync(folderID, encrypted: folder.encrypted)
        }
    }
    
    @IBAction func startRestoreNow(_ sender: AnyObject) {
        guard let _ = self.uniqueClientID else {
            return
        }
        guard let button = sender as? NSButton else {
            return
        }
        
        let folderID: UInt64 = UInt64(button.tag)
        startRestore(folderID)
        
    }
    
    func startRestore(_ uniqueID: UInt64) {
        guard let folders = self.folders,
            let folder = folders.filter("uniqueID == %@", uniqueID).last,
             let uniqueClientID = self.uniqueClientID else {
                return
        }
        
        if folder.encrypted {
            
            self.restoreSelection = RestoreSelectionWindowController(delegate: self, uniqueClientID: uniqueClientID, folderID: uniqueID)
            
            guard let w = self.restoreSelection?.window else {
                    SDLog("no recovery phrase window available")
                    return
                }
            self.window?.beginSheet(w, completionHandler: nil)
        } else {
            // unencrypted folders have no versioning, so the name is arbitrary
            let name = UUID().uuidString.lowercased()
            restore(uniqueID, encrypted: folder.encrypted, name: name, destination: nil)
        }
    }
    
    @IBAction func stopSyncNow(_ sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let folderID: UInt64 = UInt64(button.tag)
        stopSync(folderID)
    }
    
    
    // MARK: Sync control
    
    func sync(_ folderID: UInt64, encrypted: Bool) {
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
        let type: SyncType = encrypted ? .encrypted : .unencrypted
        self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .forward, type: type, name: UUID().uuidString.lowercased(), destination: nil)
    }
    
    func restore(_ folderID: UInt64, encrypted: Bool, name: String, destination: URL?) {
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
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
                    self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .reverse, type: type, name: name, destination: destination)
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
    
    @IBAction func setSyncFrequencyForFolder(_ sender: AnyObject) {
        guard let uniqueClientID = self.uniqueClientID,
              let folders = self.folders,
               let realm = self.realm else {
            return
        }
        
        if self.syncListView.selectedRow != -1 {
        
            let syncFolder = folders[self.syncListView.selectedRow - 1]

            let uniqueID = syncFolder.uniqueID
            
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
            
            let realSyncFolder = folders.filter("uniqueID == %@", uniqueID).last!
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
        self.syncListView.reloadData()
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        self.window?.makeFirstResponder(oldFirstResponder)
    }
    
    @objc
    fileprivate func showFailurePopover() {
        self.failurePopover.show(relativeTo: self.syncFailureInfoButton.bounds, of: self.syncFailureInfoButton, preferredEdge: .minY)
    }
    
    @IBAction func setSyncTime(_ sender: AnyObject) {
        guard let uniqueClientID = self.uniqueClientID,
              let folders = self.folders,
              let realm = self.realm else {
            return
        }
        
        if self.syncListView.selectedRow != -1 {
            let syncFolder = folders[self.syncListView.selectedRow]
            
            let uniqueID = syncFolder.uniqueID
            
            let realSyncFolder = folders.filter("uniqueID == %@", uniqueID).last!
            // swiftlint:disable force_try
            try! realm.write {
                realSyncFolder.syncTime = self.syncTimePicker.dateValue
            }
            // swiftlint:enable force_try
        }
    }
}

extension PreferencesWindowController: SDMountStateProtocol {

    func mountStateMounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateMounted called on background thread")

        self.mountStatusField.stringValue = NSLocalizedString("Yes", comment: "String for volume mount status of mounted")
        self.volumeNameField.isEnabled = false
        self.volumeNameWarningField.isHidden = false
    }
    
    func mountStateUnmounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateUnmounted called on background thread")

        self.mountStatusField.stringValue = NSLocalizedString("No", comment: "String for volume mount status of unmounted")
        self.volumeNameField.isEnabled = true
        self.volumeNameWarningField.isHidden = true

    }
    
    func mountStateDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateDetails called on background thread")

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
}

extension PreferencesWindowController: SDAccountProtocol {
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")

        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        guard let uniqueClientID = self.uniqueClientID else {
            SDLog("API contract invalid: didSignIn in PreferencesWindowController")
            return
        }
        
        guard let currentUser = notification.object as? User else {
            SDLog("API contract invalid: didSignIn in PreferencesWindowController")
            return
        }
        
        self.email = currentUser.email
        self.password = currentUser.password
        
        let folders = realm.objects(SyncFolder.self)
        
        self.folders = folders
        
        self.readSyncFolders(self)
        
        let recoveryPhrase = try? self.sdk.getKeychainItem(withUser: currentUser.email, service: recoveryKeyDomain())
                
        self.checkRecoveryPhrase(recoveryPhrase, success: {
            self.syncListView.reloadData()
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
                self.setTab(3)
                self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
                self.copyRecoveryPhraseButton.isEnabled = false
                
                self.window?.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)

                guard let w = self.recoveryPhraseEntry?.window else {
                    SDLog("no recovery phrase window available")
                    return
                }
                self.window?.beginSheet(w, completionHandler: nil)
                
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
            }
        })
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")

        self.syncFolderToken = nil
        self.syncTaskToken = nil
        self.folders = nil
        self.realm = nil
        self.email = nil
        self.password = nil
        self.internalUserName = nil
        self.remoteHost = nil
        self.remotePort = nil
        self.close()
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")

        guard let accountStatus = notification.object as? AccountStatus,
              let status = accountStatus.status else {
            self.accountStatusField.stringValue = NSLocalizedString("Unknown", comment:"")
            SDLog("API contract invalid: didReceiveAccountStatus in PreferencesWindowController")
            return
        }
        self.accountStatusField.stringValue = status.capitalized
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")

        guard let accountDetails = notification.object as? AccountDetails else {
            SDLog("API contract invalid: didReceiveAccountDetails in PreferencesWindowController")
            return
        }
        
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
    }
}

extension PreferencesWindowController: SDServiceStatusProtocol {
    
    func didReceiveServiceStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveServiceStatus called on background thread")

        guard let status = notification.object as? Bool else {
            SDLog("Validation failed: didReceiveServiceStatus")
            return
        }
        
        self.serviceStatusField.stringValue = (status == true ? "Running" : "Stopped")
    }
}

extension PreferencesWindowController: NSOpenSavePanelDelegate {
        
    func panel(_ sender: Any, validate url: URL) throws {
        let fileManager: FileManager = FileManager.default
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFile(atPath: url.path) {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSystemError.filePermissionDenied.rawValue, userInfo: errorInfo)
        }
        
        // check if the candidate sync path is a parent or subdirectory of an existing registered sync folder
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open local database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorSyncDomain, code: SDDatabaseError.openFailed.rawValue, userInfo: errorInfo)
        }
        
        let syncFolders = realm.objects(SyncFolder.self)
        if SyncFolder.hasConflictingFolderRegistered(url.path, syncFolders: syncFolders) {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSyncError.folderConflict.rawValue, userInfo: errorInfo)
        }
    }
    
}


extension PreferencesWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let _ = self.uniqueClientID,
              let folders = self.folders else {
            return nil
        }
        
        var tableCellView: SyncManagerTableCellView
        if row == 0 {
            let host = Host()
            let machineName = host.localizedName!
            
            tableCellView = tableView.make(withIdentifier: "MachineView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = machineName
            let cellImage: NSImage = NSImage(named: NSImageNameComputer)!
            cellImage.size = CGSize(width: 15.0, height: 15.0)
            tableCellView.imageView!.image = cellImage
        } else {
            // this would normally require zero-indexing, but we're bumping the folder list down one row to make
            // room for the machine row
            let syncFolder = folders[row - 1]

            tableCellView = tableView.make(withIdentifier: "FolderView", owner: self) as! SyncManagerTableCellView
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
                
                tableCellView.syncNowButton.isEnabled = true && SafeDriveSDK.sharedSDK.ready
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.stopSyncNow(_:))
            }
            
            if syncFolder.encrypted {
                tableCellView.lockButton.image = NSImage(named: NSImageNameLockLockedTemplate)
                tableCellView.lockButton.toolTip = NSLocalizedString("Encrypted", comment: "")
            } else {
                tableCellView.lockButton.image = NSImage(named: NSImageNameLockUnlockedTemplate)
                tableCellView.lockButton.toolTip = NSLocalizedString("Unencrypted", comment: "")
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
                
                tableCellView.restoreNowButton.isEnabled = true && SafeDriveSDK.sharedSDK.ready
                tableCellView.restoreNowButton.target = self
                tableCellView.restoreNowButton.action = #selector(self.startRestoreNow(_:))
                tableCellView.restoreNowButton.image = NSImage(named: NSImageNameInvalidDataFreestandingTemplate)
                
                tableCellView.syncNowButton.isEnabled = true && SafeDriveSDK.sharedSDK.ready
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.startSyncNow(_:))
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameRefreshFreestandingTemplate)
                
            }
        }
        
        return tableCellView
    }
    
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        rowView.isGroupRowStyle = false
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let folders = self.folders,
              let uniqueClientID = self.uniqueClientID,
              let realm = self.realm else {
            return
        }
        
        if self.syncListView.selectedRow != -1 {
            // normally this would be one-indexed, but we're bumping the folder rows down to make room for
            // the machine row
            let syncFolder = folders[self.syncListView.selectedRow - 1]
            

            if let syncTime = syncFolder.syncTime {
                self.syncTimePicker.dateValue = syncTime as Date
            } else {
                SDLog("Failed to load date in sync manager")
            }
            
            /*if let syncURL = realSyncFolder.url {
             self.pathIndicator.URL = syncURL
             }
             else {
             SDLog("Failed to load path in sync manager")
             }*/
            
            let numberFormatter = NumberFormatter()
            numberFormatter.minimumSignificantDigits = 2
            numberFormatter.maximumSignificantDigits = 2
            numberFormatter.locale = Locale.current
            
            self.progress.maxValue = 100.0
            self.progress.minValue = 0.0
            let syncTasks = realm.objects(SyncTask.self)
            
            let failureView = self.failurePopover.contentViewController!.view as! SyncFailurePopoverView

            if let syncTask = syncTasks.filter("syncFolder == %@ AND uuid == syncFolder.lastSyncUUID", syncFolder).sorted(byKeyPath: "syncDate").last {
                
                if syncFolder.restoring {
                    let progress = numberFormatter.string(from: NSNumber(value: syncTask.progress))!
                    self.syncStatus.stringValue = "Restoring"
                    if syncFolder.currentSyncUUID == syncTask.uuid {
                        self.progress.startAnimation(nil)
                        self.progress.doubleValue = syncTask.progress
                        self.syncProgressField.stringValue = "\(progress)% @ \(syncTask.bandwidth)"
                    } else {
                        self.progress.stopAnimation(nil)
                        self.progress.doubleValue = 0.0
                        self.syncProgressField.stringValue = ""
                    }
                } else if syncFolder.syncing {
                    let progress = numberFormatter.string(from: NSNumber(value: syncTask.progress))!
                    self.syncStatus.stringValue = "Syncing"
                    if syncFolder.currentSyncUUID == syncTask.uuid {
                        self.progress.startAnimation(nil)
                        self.progress.doubleValue = syncTask.progress
                        self.syncProgressField.stringValue = "\(progress)% @ \(syncTask.bandwidth)"
                    } else {
                        self.progress.stopAnimation(nil)
                        self.progress.doubleValue = 0.0
                        self.syncProgressField.stringValue = ""
                    }
                } else if syncTask.success {
                    self.syncStatus.stringValue = "Success"
                    self.progress.stopAnimation(nil)
                    
                    self.progress.doubleValue = 0.0
                    self.syncProgressField.stringValue = ""
                    
                } else {
                    self.syncStatus.stringValue = "Failed"
                    self.progress.stopAnimation(nil)
                    
                    self.progress.doubleValue = 0.0
                    self.syncProgressField.stringValue = ""
                    
                }

                if let messages = syncTask.message {
                    failureView.message.textStorage?.setAttributedString(NSAttributedString(string: messages))
                    self.syncFailureInfoButton.action = #selector(self.showFailurePopover)
                    self.syncFailureInfoButton.isHidden = false
                    self.syncFailureInfoButton.isEnabled = true
                    self.syncFailureInfoButton.toolTip = NSLocalizedString("Some issues detected, click here for details", comment: "")
                } else {
                    failureView.message.textStorage?.setAttributedString(NSAttributedString(string: ""))
                    self.syncFailureInfoButton.action = nil
                    self.syncFailureInfoButton.isHidden = true
                    self.syncFailureInfoButton.isEnabled = false
                    self.syncFailureInfoButton.toolTip = ""
                }
            } else {
                self.syncStatus.stringValue = "Waiting"
                failureView.message.textStorage?.setAttributedString(NSAttributedString(string: ""))
                self.syncFailureInfoButton.action = nil
                self.syncFailureInfoButton.isHidden = true
                self.syncFailureInfoButton.isEnabled = false
                self.syncFailureInfoButton.toolTip = nil
                self.progress.stopAnimation(nil)
                
                self.progress.doubleValue = 0.0
                
                self.syncProgressField.stringValue = ""
            }
            
            /*if let syncTask = syncTasks.filter("syncFolder == %@ AND success == true", syncItem).sorted("syncDate").last,
             lastSync = syncTask.syncDate {
             self.lastSyncField.stringValue = lastSync.toMediumString()
             }
             else {
             self.lastSyncField.stringValue = ""
             }*/
            
            switch syncFolder.syncFrequency {
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
                //self.nextSyncField.stringValue = NSDate().nextDayAt((realSyncFolder.syncTime?.hour)!, minute: (realSyncFolder.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.isEnabled = true
                self.syncTimePicker.isHidden = false
            case "weekly":
                self.scheduleSelection.selectItem(at: 2)
                //self.nextSyncField.stringValue = NSDate().nextWeekAt((realSyncFolder.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.isEnabled = true
                self.syncTimePicker.isHidden = false
            case "monthly":
                self.scheduleSelection.selectItem(at: 3)
                //self.nextSyncField.stringValue = NSDate().nextMonthAt((realSyncFolder.syncTime?.hour)!, minute: (realSyncFolder.syncTime?.minute)!)?.toMediumString() ?? ""
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
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return (row >= 1)
    }

}

extension PreferencesWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let folders = self.folders else {
            return 0
        }
        // make room for the machine row at the top
        return 1 + folders.count
    }

}

extension PreferencesWindowController: RecoveryPhraseEntryDelegate {
    func checkRecoveryPhrase(_ phrase: String?, success: @escaping () -> Void, failure: @escaping (_ error: SDKError) -> Void) {
        assert(Thread.current == Thread.main, "checkRecoveryPhrase called on background thread")

        guard let email = self.email else {
            return
        }
        self.syncListView.reloadData()
        
        self.sdk.loadKeys(phrase, completionQueue: DispatchQueue.main, storePhrase: { (newPhrase) in
            
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            
            alert.messageText = "New recovery phrase"
            alert.informativeText = "A recovery phrase has been generated for your account, please write it down and keep it in a safe place:\n\n\(newPhrase)"
            alert.alertStyle = .informational
            
            alert.beginSheetModal(for: self.window!, completionHandler: { (_) in
                
            })
            
            self.storeRecoveryPhrase(newPhrase, success: { 

            }, failure: { (error) in
                let se = SDKError(message: error.localizedDescription, kind: SDKErrorType.KeychainError)
                failure(se)
            })
            
        }, success: {
            if let recoveryPhrase = try? self.sdk.getKeychainItem(withUser: email, service: recoveryKeyDomain()) {
                self.recoveryPhraseField.stringValue = recoveryPhrase
                self.copyRecoveryPhraseButton.isEnabled = true
            } else {
                self.recoveryPhraseField.stringValue = NSLocalizedString("Missing", comment: "")
                self.copyRecoveryPhraseButton.isEnabled = false
            }
            self.syncListView.reloadData()
            success()
            
        }, failure: { (error) in
            self.syncListView.reloadData()
            SDLog("failed to load keys with sdk: \(error.message)")
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

extension PreferencesWindowController: RestoreSelectionDelegate {
    func selectedSession(_ sessionName: String, folderID: UInt64, destination: URL) {
        assert(Thread.current == Thread.main, "selectedSession called on background thread")

        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
        let type: SyncType = .encrypted
        
        self.syncScheduler.cancel(folderID) {
            self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .reverse, type: type, name: sessionName, destination: destination)
        }
    }
}

extension PreferencesWindowController: SDApplicationEventProtocol {
    func applicationDidConfigureRealm(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureRealm called on background thread")

        guard let realm = try? Realm() else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.realm = realm

        self.syncFolderToken = realm.objects(SyncFolder.self).addNotificationBlock { [weak self] (_: RealmCollectionChange) in
            self?.reload()
        }
        
        self.syncTaskToken = realm.objects(SyncTask.self).addNotificationBlock { [weak self] (_: RealmCollectionChange) in
            self?.reload()
        }
}
    
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
        self.password = currentUser.password
        
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: Any) -> Bool {
        return true
    }
}
