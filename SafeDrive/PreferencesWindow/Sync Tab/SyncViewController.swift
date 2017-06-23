
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable type_body_length
// swiftlint:disable file_length

import Cocoa
import Realm
import RealmSwift
import SafeDriveSDK

class SyncViewController: NSViewController {
    
    fileprivate let sdk = SafeDriveSDK.sharedSDK

    fileprivate var syncScheduler = SyncScheduler.sharedSyncScheduler
    
    fileprivate weak var delegate: PreferencesViewDelegate!
    
    @IBOutlet fileprivate weak var syncListView: NSTableView!
    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!
    
    @IBOutlet fileprivate weak   var progress: NSProgressIndicator!
    
    //@IBOutlet var pathIndicator: NSPathControl!
    
    //@IBOutlet var lastSyncField: NSTextField!
    
    //@IBOutlet var nextSyncField: NSTextField!
    
    @IBOutlet fileprivate weak var syncProgressField: NSTextField!
    
    @IBOutlet fileprivate weak var syncFailureInfoButton: NSButton!
    
    @IBOutlet fileprivate weak var syncStatus: NSTextField!
    
    @IBOutlet fileprivate weak var syncTimePicker: NSDatePicker!
    
    @IBOutlet fileprivate weak var scheduleSelection: NSPopUpButton!
    
    @IBOutlet fileprivate weak var failurePopover: NSPopover!
    
    fileprivate var restoreSelection: RestoreSelectionWindowController!

    
    fileprivate var syncFolderToken: RealmSwift.NotificationToken?
    
    fileprivate var syncTaskToken: RealmSwift.NotificationToken?
    
    fileprivate var folders: Results<SyncFolder>?
    
    fileprivate var realm: Realm?
    
    fileprivate var uniqueClientID: String?
    
    // swiftlint:disable force_unwrapping
    fileprivate let dbURL: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db")!.appendingPathComponent("sync.realm")
    // swiftlint:enable force_unwrapping

    var email: String?
    var internalUserName: String?
    var password: String?
    
    var remoteHost: String?
    var remotePort: UInt16?
    
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
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: PreferencesViewDelegate) {
        // swiftlint:disable force_unwrapping
        self.init(nibName: "SyncView", bundle: nil)!
        // swiftlint:enable force_unwrapping

        self.delegate = delegate

        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureRealm), name: Notification.Name.applicationDidConfigureRealm, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
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
        
        self.delegate.showPanel(panel) { (response) in
            if response == NSFileHandlingPanelOKButton {
                guard let url = panel.url else {
                    return
                }

                self.spinner.startAnimation(self)
                let isEncrypted = (encryptedCheckbox.state == 1)
                
                let folderName = url.lastPathComponent.lowercased()
                let folderPath = url.path
                
                self.sdk.addFolder(folderName, path: folderPath, encrypted: isEncrypted, completionQueue: DispatchQueue.main, success: { (folderID) in
                    guard let realm = self.realm else {
                        SDLog("failed to get realm!!!")
                        Crashlytics.sharedInstance().crash()
                        return
                    }
                    
                    let syncFolder = SyncFolder(name: url.lastPathComponent, url: url, uniqueID: Int32(folderID), encrypted: isEncrypted)
                    
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
        guard let _ = self.uniqueClientID else {
            SDLog("ucid unavailable, cancelling remove sync folder")
            return
        }
        guard let _ = self.email else {
                SDLog("credentials unavailable, cancelling remove sync folder")
                return
        }
        let button: NSButton = sender as! NSButton
        let uniqueID: UInt64 = UInt64(button.tag)
        SDLog("Deleting sync folder ID: %lu", uniqueID)
        
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        let syncFolders = realm.objects(SyncFolder.self)
        
        guard let syncFolder = syncFolders.filter("uniqueID == %@", uniqueID).last else {
                return
        }
        
        let encrypted = syncFolder.encrypted
        
        
        let alert = NSAlert()
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        if !encrypted {
            alert.addButton(withTitle: "Move to Storage folder")
        }
        
        
        alert.messageText = "Stop syncing this folder?"
        
        var unencryptedOption = ""
        if !encrypted {
            unencryptedOption = " or moved to your Storage folder"
        }
        alert.informativeText = "The synced files will be deleted from SafeDrive\(unencryptedOption).\n\nWhich one would you like to do?"
        alert.alertStyle = .informational
        
        self.delegate.showAlert(alert) { (response) in
            
            var op: SDKRemoteFSOperation
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                op = .deletePath(recursive: true)
            case NSAlertThirdButtonReturn:
                op = .moveFolder
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
            
            guard let syncFolder = syncFolders.filter("uniqueID == %@", uniqueID).last,
                  let folderName = syncFolder.name else {
                return
            }
            
            let host = Host()
            // swiftlint:disable force_unwrapping
            let machineName = host.localizedName!
            // swiftlint:enable force_unwrapping
            
            // swiftlint:disable force_unwrapping
            let defaultFolder: URL = URL(string: defaultServerPath())!
            // swiftlint:enable force_unwrapping

            let machineFolder: URL = defaultFolder.appendingPathComponent(machineName, isDirectory: true)
            let remoteFolder: URL = machineFolder.appendingPathComponent(folderName, isDirectory: true)
            
            
            let serverCancel: () -> Void = {
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
                    
                    let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", uniqueID)
                    
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
            }
            
            self.syncScheduler.cancel(uniqueID) {
                if encrypted {
                    serverCancel()
                } else {
                    let syncController = SyncController()
                    syncController.uniqueID = uniqueID
                    syncController.sftpOperation(op, remoteDirectory: remoteFolder, success: {
                        serverCancel()
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
            }
        }
    }
    
    @IBAction func readSyncFolders(_ sender: AnyObject) {
        guard let uniqueClientID = self.uniqueClientID,
            let realm = self.realm else {
                return
        }
        self.spinner.startAnimation(self)
        
        self.sdk.getFolders(completionQueue: DispatchQueue.main, success: { (folders: [SDKSyncFolder]) in
            self.scheduleSelection.selectItem(at: -1)

            var currentFolderIDs = [Int32]()
            
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
                
                currentFolderIDs.append(Int32(folderId))
                
                let addedDate = folder.date
                
                let encrypted = folder.encrypted
                
                // try to retrieve and modify existing record if possible, avoids overwriting preferences only stored in entity
                // while still ensuring entities will have a default set on them for things like sync time
                var syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderId).last
                
                if syncFolder == nil {
                    syncFolder = SyncFolder(name: folderName, path: folderPath, uniqueID: Int32(folderId), encrypted: encrypted)
                }
                
                // swiftlint:disable force_try
                // swiftlint:disable force_unwrapping

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
                // swiftlint:enable force_unwrapping

                // swiftlint:enable force_try
                
            }
            
            // clean up any sync folders in the realm file that are not in the server's folder list
            let folders = realm.objects(SyncFolder.self)
            for storedFolder in folders {
                if !currentFolderIDs.contains(storedFolder.uniqueID) {
                    let syncTasks = realm.objects(SyncTask.self).filter("syncFolder.uniqueID == %@", storedFolder.uniqueID)
                    
                    do {
                        try realm.write {
                            realm.delete(syncTasks)
                        }
                    } catch {
                        print("failed to delete sync tasks associated with \(storedFolder.uniqueID)")
                    }
                    
                    do {
                        try realm.write {
                            realm.delete(storedFolder)
                        }
                    } catch {
                        print("failed to delete sync folder \(storedFolder.uniqueID)")
                    }
                }
            }
            
            realm.refresh()
            self.reload()
            
            self.spinner.stopAnimation(self)
            
            self.verifyFolders(nil)
            
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
        guard let _ = self.uniqueClientID,
            let button: NSButton = sender as? NSButton,
            let folders = self.folders,
            let folder = folders.filter("uniqueID == %@", UInt64(button.tag)).last,
            let folderName = folder.name,
            let folderPath = folder.path else {
            return
        }
        
        let folderID: UInt64 = UInt64(button.tag)
        
        if folder.active {
            if !folder.exists() {
                self.verifyFolder(folderName, folderPath: folderPath, folderID: Int32(folderID))
            } else {
                sync(folderID, encrypted: folder.encrypted)
            }
        } else {
            let alert = NSAlert()
            alert.addButton(withTitle: "No")
            alert.addButton(withTitle: "Yes")
            
            alert.messageText = "Folder paused"
            alert.informativeText = "This folder is currently paused, do you want to set it to active again?"
            alert.alertStyle = .informational
            self.delegate.showAlert(alert) { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    return
                case NSAlertSecondButtonReturn:
                    if folder.exists() {
                        let completionQueue = DispatchQueue.main
                        
                        self.sdk.updateFolder(folderName, path: folderPath, syncing: true, uniqueID: UInt64(folderID), completionQueue: completionQueue, success: { (folderID) in
                            guard let realm = self.realm,
                                  let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderID).last else {
                                SDLog("failed to get realm!!!")
                                return
                            }
                            
                            
                            // swiftlint:disable force_try
                            try! realm.write {
                                syncFolder.path = folderPath
                            }
                            // swiftlint:enable force_try
                        }, failure: { (error) in
                            SDErrorHandlerReport(error)
                            self.spinner.stopAnimation(self)
                            let alert: NSAlert = NSAlert()
                            alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                            alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                            alert.runModal()
                        })
                    } else {
                        self.verifyFolder(folderName, folderPath: folderPath, folderID: Int32(folderID))
                    }
                default:
                    return
                }
            }
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
            let folderName = folder.name,
            let folderPath = folder.path,
            let uniqueClientID = self.uniqueClientID else {
                return
        }
        
        if folder.active {
            if !folder.exists() {
                self.verifyFolder(folderName, folderPath: folderPath, folderID: Int32(uniqueID))
            } else {
                if folder.encrypted {
                    
                    self.restoreSelection = RestoreSelectionWindowController(delegate: self, uniqueClientID: uniqueClientID, folderID: uniqueID)
                    
                    guard let w = self.restoreSelection?.window else {
                        SDLog("no recovery phrase window available")
                        return
                    }
                    self.delegate.showModalWindow(w) { (_) in
                        
                    }
                } else {
                    // unencrypted folders have no versioning, so the name is arbitrary
                    let name = UUID().uuidString.lowercased()
                    restore(uniqueID, encrypted: folder.encrypted, name: name, destination: nil)
                }
            }
            
        } else {
            let alert = NSAlert()
            alert.addButton(withTitle: "No")
            alert.addButton(withTitle: "Yes")
            
            alert.messageText = "Folder paused"
            alert.informativeText = "This folder is currently paused, do you want to set it to active again?"
            alert.alertStyle = .informational
            self.delegate.showAlert(alert) { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    return
                case NSAlertSecondButtonReturn:
                    
                    if folder.exists() {
                        let completionQueue = DispatchQueue.main
                        
                        self.sdk.updateFolder(folderName, path: folderPath, syncing: true, uniqueID: UInt64(uniqueID), completionQueue: completionQueue, success: { (folderID) in
                            guard let realm = self.realm,
                            let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderID).last else {
                                SDLog("failed to get realm!!!")
                                return
                            }
                            
                            // swiftlint:disable force_try
                            try! realm.write {
                                syncFolder.path = folderPath
                            }
                            // swiftlint:enable force_try
                        }, failure: { (error) in
                            SDErrorHandlerReport(error)
                            self.spinner.stopAnimation(self)
                            let alert: NSAlert = NSAlert()
                            alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                            alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                            alert.runModal()
                        })
                    } else {
                        self.verifyFolder(folderName, folderPath: folderPath, folderID: Int32(uniqueID))
                    }
                default:
                    return
                }
            }
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
        self.delegate.showAlert(alert) { (response) in
            
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                // cancel any sync in progress so we don't have two rsync processes overwriting each other
                self.syncScheduler.cancel(folderID) {
                    self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .reverse, type: type, name: name, destination: destination)
                }
            default:
                return
            }
        }
    }
    
    func stopSync(_ folderID: UInt64) {
        
        let alert = NSAlert()
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")
        
        alert.messageText = "Cancel sync?"
        alert.informativeText = "This folder is currently syncing, do you want to cancel?"
        alert.alertStyle = .informational
        
        self.delegate.showAlert(alert) { (response) in
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                self.syncScheduler.cancel(folderID) {
                    
                }
            default:
                return
            }
        }
    }
    
    @IBAction func setSyncFrequencyForFolder(_ sender: AnyObject) {
        guard let _ = self.uniqueClientID,
            let folders = self.folders,
            let realm = self.realm,
            let syncFolder = folders[safe: self.syncListView.selectedRow - 1] else {
                return
        }

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
        
        // swiftlint:disable force_try
        try! realm.write {
            syncFolder.syncFrequency = syncFrequency
        }
        // swiftlint:enable force_try
    }
    
    
    fileprivate func reload() {
        assert(Thread.isMainThread, "Not main thread!!!")
        let oldFirstResponder = self.view.window?.firstResponder
        let selectedIndexes = self.syncListView.selectedRowIndexes
        self.syncListView.reloadData()
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        self.view.window?.makeFirstResponder(oldFirstResponder)
        self.updateSyncDetailsPanel()
    }
    
    @objc
    @IBAction func showFailurePopover(_ sender: AnyObject?) {
        self.failurePopover.show(relativeTo: self.syncFailureInfoButton.bounds, of: self.syncFailureInfoButton, preferredEdge: .minY)
    }
    
    @IBAction func setSyncTime(_ sender: AnyObject) {
        guard let _ = self.uniqueClientID,
            let folders = self.folders,
            let realm = self.realm,
            let syncFolder = folders[safe: self.syncListView.selectedRow - 1] else {
                return
        }
        
        // swiftlint:disable force_try
        try! realm.write {
            syncFolder.syncTime = self.syncTimePicker.dateValue
        }
        // swiftlint:enable force_try
    }

    fileprivate func updateSyncDetailsPanel() {
        guard self.syncListView.selectedRow != -1,
            let folders = self.folders,
            let _ = self.uniqueClientID,
            let realm = self.realm,
            let syncFolder = folders[safe: self.syncListView.selectedRow - 1] else {
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
                // swiftlint:disable force_unwrapping
                self.syncTimePicker.dateValue = calendar.date(from: components)!
                // swiftlint:enable force_unwrapping
                
                //self.pathIndicator.URL = nil
                self.progress.doubleValue = 0.0
                self.syncProgressField.stringValue = ""
                return
        }
        
        
        if let syncTime = syncFolder.syncTime {
            self.syncTimePicker.dateValue = syncTime as Date
        } else {
            SDLog("Failed to load date in sync manager")
        }
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumSignificantDigits = 2
        numberFormatter.maximumSignificantDigits = 2
        numberFormatter.locale = Locale.current
        
        self.progress.maxValue = 100.0
        self.progress.minValue = 0.0
        let syncTasks = realm.objects(SyncTask.self)
        
        // swiftlint:disable force_unwrapping
        let failureView = self.failurePopover.contentViewController!.view as! SyncFailurePopoverView
        // swiftlint:enable force_unwrapping
        
        
        if !syncFolder.active {
            self.syncStatus.stringValue = "Paused"
            failureView.message.textStorage?.setAttributedString(NSAttributedString(string: ""))
            self.syncFailureInfoButton.action = nil
            self.syncFailureInfoButton.isHidden = true
            self.syncFailureInfoButton.isEnabled = false
            self.syncFailureInfoButton.toolTip = nil
            self.progress.stopAnimation(nil)
            
            self.progress.doubleValue = 0.0
            
            self.syncProgressField.stringValue = ""
        } else if let syncTask = syncTasks.filter("syncFolder == %@ AND uuid == syncFolder.lastSyncUUID", syncFolder).sorted(byKeyPath: "syncDate").last {
            
            if syncFolder.restoring {
                // swiftlint:disable force_unwrapping
                let progress = numberFormatter.string(from: NSNumber(value: syncTask.progress))!
                // swiftlint:enable force_unwrapping

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
                // swiftlint:disable force_unwrapping
                let progress = numberFormatter.string(from: NSNumber(value: syncTask.progress))!
                // swiftlint:enable force_unwrapping

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
                self.syncFailureInfoButton.isHidden = false
                self.syncFailureInfoButton.isEnabled = true
                self.syncFailureInfoButton.toolTip = NSLocalizedString("Some issues detected, click here for details", comment: "")
                self.syncFailureInfoButton.action = #selector(self.showFailurePopover(_:))
            } else {
                failureView.message.textStorage?.setAttributedString(NSAttributedString(string: ""))
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
            // swiftlint:disable force_unwrapping
            self.syncTimePicker.dateValue = calendar.date(from: components)!
            // swiftlint:enable force_unwrapping
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
    }
    
}

extension SyncViewController: SDAccountProtocol {
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")
        
        guard let accountStatus = notification.object as? SDKAccountStatus else {
            SDLog("API contract invalid: didSignIn in MountController")
            return
        }
        
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
        
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        let folders = realm.objects(SyncFolder.self)
        
        self.folders = folders
        
        self.readSyncFolders(self)
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
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")
        
        guard let accountStatus = notification.object as? SDKAccountStatus else {
                SDLog("API contract invalid: didReceiveAccountStatus in PreferencesWindowController")
                return
        }
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")
    }
}

extension SyncViewController: NSOpenSavePanelDelegate {
    
    func panel(_ sender: Any, validate url: URL) throws {
        let fileManager: FileManager = FileManager.default
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFile(atPath: url.path) {
            let message = NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")
            SDLog(message)
            let error = SDError(message: message, kind: .filePermissionDenied)
            throw error
        }
        
        // check if the candidate sync path is a parent or subdirectory of an existing registered sync folder
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            let message = NSLocalizedString("Cannot open local database, this is a fatal error", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .openFailed)
            throw error
        }
        
        let syncFolders = realm.objects(SyncFolder.self)
        if SyncFolder.hasConflictingFolderRegistered(url.path, syncFolders: syncFolders) {
            let message = NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")
            SDLog(message)
            let error = SDError(message: message, kind: .folderConflict)
            throw error            
        }
    }
    
}


extension SyncViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let _ = self.uniqueClientID,
            let folders = self.folders else {
                return nil
        }
        
        var tableCellView: SyncManagerTableCellView
        if row == 0 {
            let host = Host()
            // swiftlint:disable force_unwrapping
            let machineName = host.localizedName!
            // swiftlint:enable force_unwrapping
            
            // swiftlint:disable force_unwrapping
            tableCellView = tableView.make(withIdentifier: "MachineView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = machineName
            let cellImage: NSImage = NSImage(named: NSImageNameComputer)!
            cellImage.size = CGSize(width: 15.0, height: 15.0)
            tableCellView.imageView!.image = cellImage
            // swiftlint:enable force_unwrapping

            //tableCellView.addButton.action = #selector(self.addSyncFolder(_:))

        } else {
            // this would normally require zero-indexing, but we're bumping the folder list down one row to make
            // room for the machine row
            let syncFolder = folders[row - 1]
            // swiftlint:disable force_unwrapping
            tableCellView = tableView.make(withIdentifier: "FolderView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = syncFolder.name!.capitalized
            let cellImage: NSImage = NSWorkspace.shared().icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            cellImage.size = CGSize(width: 15.0, height: 15.0)
            tableCellView.imageView!.image = cellImage
            // swiftlint:enable force_unwrapping

            tableCellView.removeButton.tag = Int(syncFolder.uniqueID)
            tableCellView.syncNowButton.tag = Int(syncFolder.uniqueID)
            tableCellView.restoreNowButton.tag = Int(syncFolder.uniqueID)
            
            //tableCellView.removeButton.action = #selector(self.removeSyncFolder(_:))

            
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
        self.updateSyncDetailsPanel()
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return (row >= 1)
    }
    
}

extension SyncViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let folders = self.folders else {
            return 0
        }
        // make room for the machine row at the top
        return 1 + folders.count
    }
    
}

extension SyncViewController: RestoreSelectionDelegate {
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


extension SyncViewController: SDApplicationEventProtocol {
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

extension SyncViewController {
    @IBAction func verifyFolders(_ sender: AnyObject?) {
        
        guard let realm = self.realm else {
            return
        }
        
        let syncFolders = realm.objects(SyncFolder.self)
        
        for folder in syncFolders {
            
            guard let folderName = folder.name,
                  let folderPath = folder.path else {
                    continue
            }
            let folderID = folder.uniqueID
            
            if !folder.exists() && folder.active {
                self.verifyFolder(folderName, folderPath: folderPath, folderID: folderID)
            }
        }
        
    }
    
    func verifyFolder(_ folderName: String, folderPath: String, folderID: Int32) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.addButton(withTitle: "Find")
            alert.addButton(withTitle: "Restore")
            alert.addButton(withTitle: "Pause")
            
            alert.messageText = "SafeDrive cannot locate the \(folderName) folder"
            alert.informativeText = "The folder may have been moved or deleted, would you like to find it, restore it from the server, or remove it from your account?"
            alert.alertStyle = .warning
            
            self.delegate.showAlert(alert) { (response) in
                switch response {
                case NSAlertFirstButtonReturn:
                    let panel: NSOpenPanel = NSOpenPanel()
                    panel.delegate = self
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    let panelTitle: String = NSLocalizedString("find the \(folderName) folder", comment: "Title of window")
                    panel.title = panelTitle
                    let promptString: String = NSLocalizedString("Select", comment: "Button title")
                    panel.prompt = promptString
                    
                    self.delegate.showPanel(panel) { (result) in
            
                        if result == NSFileHandlingPanelOKButton {
                            guard let folderPath = panel.url?.path else {
                                return
                            }
                            
                            let completionQueue = DispatchQueue.main
                            
                            self.sdk.updateFolder(folderName, path: folderPath, syncing: true, uniqueID: UInt64(folderID), completionQueue: completionQueue, success: { (folderID) in
                                guard let realm = self.realm,
                                      let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderID).last else {
                                    SDLog("failed to get realm!!!")
                                    return
                                }
                                
                                // swiftlint:disable force_try
                                try! realm.write {
                                    syncFolder.path = folderPath
                                }
                                // swiftlint:enable force_try
                            }, failure: { (error) in
                                SDErrorHandlerReport(error)
                                self.spinner.stopAnimation(self)
                                let alert: NSAlert = NSAlert()
                                alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                                alert.runModal()
                            })
                        } else {
                            DispatchQueue.main.async {
                                self.verifyFolder(folderName, folderPath: folderPath, folderID: folderID)
                            }
                        }
                    }
                case NSAlertSecondButtonReturn:
                    self.startRestore(UInt64(folderID))
                case NSAlertThirdButtonReturn:
                    self.sdk.updateFolder(folderName, path: folderPath, syncing: false, uniqueID: UInt64(folderID), completionQueue: DispatchQueue.main, success: {
                        guard let realm = self.realm,
                              let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", folderID).last else {
                            SDLog("failed to get realm!!!")
                            return
                        }
                        
                        // swiftlint:disable force_try
                        try! realm.write {
                            syncFolder.active = false
                            syncFolder.path = folderPath
                        }
                        // swiftlint:enable force_try
                    }, failure: { (error) in
                        SDErrorHandlerReport(error)
                        self.spinner.stopAnimation(self)
                        let alert: NSAlert = NSAlert()
                        alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                        alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                        alert.runModal()
                    })
                default:
                    return
                }
            }
        }
    }

}
