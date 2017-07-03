
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable type_body_length
// swiftlint:disable file_length

import Cocoa
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

    fileprivate var folders = [SDKSyncFolder]()
    
    fileprivate var uniqueClientID: String?

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
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        // register SDSyncEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDSyncEventProtocol.syncEvent), name: Notification.Name.syncEvent, object: nil)
    }
    
    @IBAction func addSyncFolder(_ sender: AnyObject) {
        guard let _ = self.uniqueClientID else {
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
                    self.readSyncFolders(self)
                    self.sync(folderID, encrypted: isEncrypted)
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
        
        guard let folder = folders.first(where: { $0.id == uniqueID }),
            let folderIndex = folders.index(of: folder) else {
                return
        }
        
        let encrypted = folder.encrypted
        
        
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
            
            let host = Host()
            // swiftlint:disable force_unwrapping
            let machineName = host.localizedName!
            // swiftlint:enable force_unwrapping
            
            // swiftlint:disable force_unwrapping
            let defaultFolder: URL = URL(string: defaultServerPath())!
            // swiftlint:enable force_unwrapping

            let machineFolder: URL = defaultFolder.appendingPathComponent(machineName, isDirectory: true)
            let remoteFolder: URL = machineFolder.appendingPathComponent(folder.name, isDirectory: true)
            
            
            let serverCancel: () -> Void = {
                self.sdk.removeFolder(uniqueID, completionQueue: DispatchQueue.main, success: {
                    
                    self.folders.remove(at: folderIndex)
                    
                    self.syncScheduler.removeTaskForFolderID(folder.id)
                    
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
        guard let _ = self.uniqueClientID else {
                return
        }
        self.spinner.startAnimation(self)
        
        self.sdk.getFolders(completionQueue: DispatchQueue.main, success: { (folders: [SDKSyncFolder]) in
            
            self.folders = folders
            
            self.syncScheduler.folders = folders
            
            self.scheduleSelection.selectItem(at: -1)

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
            let folder = folders.first(where: { $0.id == UInt64(button.tag) }) else {
            return
        }
        
        let folderID = folder.id
        
        if folder.active {
            if !folder.exists() {
                self.verifyFolder(folder)
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
                        
                        self.sdk.updateFolder(folder.name, path: folder.path, syncing: true, uniqueID: folderID, syncFrequency: folder.syncFrequency, syncTime: folder.syncTime, completionQueue: completionQueue, success: { (_) in

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
                        self.verifyFolder(folder)
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
        guard let folder = folders.first(where: { $0.id == uniqueID }),
            let uniqueClientID = self.uniqueClientID else {
                return
        }
        
        if folder.active {
            if !folder.exists() {
                self.verifyFolder(folder)
            } else {
                if folder.encrypted {
                    
                    self.restoreSelection = RestoreSelectionWindowController(delegate: self, uniqueClientID: uniqueClientID, folder: folder)
                    
                    guard let w = self.restoreSelection?.window else {
                        SDLog("no recovery phrase window available")
                        return
                    }
                    self.delegate.showModalWindow(w) { (_) in
                        
                    }
                } else {
                    // unencrypted folders have no versioning, so the name is arbitrary
                    let name = UUID().uuidString.lowercased()
                    restore(uniqueID, encrypted: folder.encrypted, name: name, destination: nil, session: nil)
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
                        
                        self.sdk.updateFolder(folder.name, path: folder.path, syncing: true, uniqueID: uniqueID, syncFrequency: folder.syncFrequency, syncTime: folder.syncTime, completionQueue: completionQueue, success: { (_) in

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
                        self.verifyFolder(folder)
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
        self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .forward, name: UUID().uuidString.lowercased(), destination: nil, session: nil)
    }
    
    func restore(_ folderID: UInt64, encrypted: Bool, name: String, destination: URL?, session: SDKSyncSession?) {
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
        
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
                    self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .reverse, name: name, destination: destination, session: session)
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
            let folder = folders[safe: self.syncListView.selectedRow - 1],
            let dropdown = sender as? NSPopUpButton else {
                return
        }
        
        dropdown.isEnabled = false

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
        
        self.sdk.updateFolder(folder.name, path: folder.path, syncing: folder.active, uniqueID: folder.id, syncFrequency: syncFrequency, syncTime: folder.syncTime, completionQueue: DispatchQueue.main, success: {
            dropdown.isEnabled = true

            self.readSyncFolders(self)
        }, failure: { (error) in
            SDErrorHandlerReport(error)
            self.spinner.stopAnimation(self)
            dropdown.isEnabled = true

            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
            alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.runModal()
        })
    }
    
    
    fileprivate func reload() {
        assert(Thread.isMainThread, "Not main thread!!!")
        let oldFirstResponder = self.view.window?.firstResponder
        let selectedIndexes = self.syncListView.selectedRowIndexes
        self.syncListView.reloadData()
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        self.view.window?.makeFirstResponder(oldFirstResponder)
        
        guard self.syncListView.selectedRow != -1,
            let _ = self.uniqueClientID,
            let syncFolder = folders[safe: self.syncListView.selectedRow - 1] else {
                return
        }
        
        self.updateSyncDetailsPanel(folder: syncFolder)
    }
    
    @objc
    @IBAction func showFailurePopover(_ sender: AnyObject?) {
        self.failurePopover.show(relativeTo: self.syncFailureInfoButton.bounds, of: self.syncFailureInfoButton, preferredEdge: .minY)
    }
    
    @IBAction func setSyncTime(_ sender: AnyObject) {
        guard let _ = self.uniqueClientID,
            let folder = folders[safe: self.syncListView.selectedRow - 1],
            let timePicker = sender as? NSDatePicker else {
                return
        }
        
        self.spinner.startAnimation(self)

        timePicker.isEnabled = false
                
        self.sdk.updateFolder(folder.name, path: folder.path, syncing: folder.active, uniqueID: folder.id, syncFrequency: folder.syncFrequency, syncTime: self.syncTimePicker.dateValue, completionQueue: DispatchQueue.main, success: {
            self.spinner.stopAnimation(self)

            self.readSyncFolders(self)
            timePicker.isEnabled = true

        }, failure: { (error) in
            SDErrorHandlerReport(error)
            self.spinner.stopAnimation(self)
            timePicker.isEnabled = true

            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
            alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.runModal()
        })
    }

    fileprivate func updateSyncDetailsPanel(folder: SDKSyncFolder) {
        
        self.syncTimePicker.dateValue = folder.syncTime as Date
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumSignificantDigits = 2
        numberFormatter.maximumSignificantDigits = 2
        numberFormatter.locale = Locale.current
        
        self.progress.maxValue = 100.0
        self.progress.minValue = 0.0
        
        // swiftlint:disable force_unwrapping
        let failureView = self.failurePopover.contentViewController!.view as! SyncFailurePopoverView
        // swiftlint:enable force_unwrapping
        
        
        if !folder.active {
            self.syncStatus.stringValue = "Paused"
            failureView.message.textStorage?.setAttributedString(NSAttributedString(string: ""))
            self.syncFailureInfoButton.action = nil
            self.syncFailureInfoButton.isHidden = true
            self.syncFailureInfoButton.isEnabled = false
            self.syncFailureInfoButton.toolTip = nil
            self.progress.stopAnimation(nil)
            
            self.progress.doubleValue = 0.0
            
            self.syncProgressField.stringValue = ""
            
        } else if let syncTask = self.syncScheduler.taskForFolderID(folder.id) {
            
            if syncTask.restoring {
                // swiftlint:disable force_unwrapping
                let progress = numberFormatter.string(from: NSNumber(value: syncTask.progress))!
                // swiftlint:enable force_unwrapping

                self.syncStatus.stringValue = "Restoring"
                
                self.progress.startAnimation(nil)
                self.progress.doubleValue = syncTask.progress
                self.syncProgressField.stringValue = "\(progress)% @ \(syncTask.bandwidth)"
                
            } else if syncTask.syncing {
                // swiftlint:disable force_unwrapping
                let progress = numberFormatter.string(from: NSNumber(value: syncTask.progress))!
                // swiftlint:enable force_unwrapping

                self.syncStatus.stringValue = "Syncing"

                self.progress.startAnimation(nil)
                self.progress.doubleValue = syncTask.progress
                self.syncProgressField.stringValue = "\(progress)% @ \(syncTask.bandwidth)"

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
            
            if syncTask.message.characters.count > 0 {
                failureView.message.textStorage?.setAttributedString(NSAttributedString(string: syncTask.message))
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
        
        
        switch folder.syncFrequency {
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
        
        self.readSyncFolders(self)
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")

        self.folders = [SDKSyncFolder]()
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
        
        if try sdk.hasConflictingFolder(folderPath: url.path) {
            let message = NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")
            SDLog(message)
            let error = SDError(message: message, kind: .folderConflict)
            throw error
        }
    }
    
}


extension SyncViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let _ = self.uniqueClientID else {
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

            guard let folder = folders[safe: row - 1] else {
                    return nil
            }

            // swiftlint:disable force_unwrapping
            tableCellView = tableView.make(withIdentifier: "FolderView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = folder.name.capitalized
            let cellImage: NSImage = NSWorkspace.shared().icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            cellImage.size = CGSize(width: 15.0, height: 15.0)
            tableCellView.imageView!.image = cellImage
            // swiftlint:enable force_unwrapping

            tableCellView.removeButton.tag = Int(folder.id)
            tableCellView.syncNowButton.tag = Int(folder.id)
            tableCellView.restoreNowButton.tag = Int(folder.id)
            
            if folder.encrypted {
                tableCellView.lockButton.image = NSImage(named: NSImageNameLockLockedTemplate)
                tableCellView.lockButton.toolTip = NSLocalizedString("Encrypted", comment: "")
            } else {
                tableCellView.lockButton.image = NSImage(named: NSImageNameLockUnlockedTemplate)
                tableCellView.lockButton.toolTip = NSLocalizedString("Unencrypted", comment: "")
            }
            
            
            guard let task = self.syncScheduler.taskForFolderID(folder.id) else {
                tableCellView.syncStatus.stopAnimation(self)
                
                tableCellView.restoreNowButton.isEnabled = true && SafeDriveSDK.sharedSDK.ready
                tableCellView.restoreNowButton.target = self
                tableCellView.restoreNowButton.action = #selector(self.startRestoreNow(_:))
                tableCellView.restoreNowButton.image = NSImage(named: NSImageNameInvalidDataFreestandingTemplate)
                
                tableCellView.syncNowButton.isEnabled = true && SafeDriveSDK.sharedSDK.ready
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.startSyncNow(_:))
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameRefreshFreestandingTemplate)
                
                return tableCellView
            }
            
            
            
            //tableCellView.removeButton.action = #selector(self.removeSyncFolder(_:))
            
            if task.syncing || task.restoring {
                tableCellView.restoreNowButton.isEnabled = false
                tableCellView.restoreNowButton.target = self
                tableCellView.restoreNowButton.action = #selector(self.stopSyncNow(_:))
                
                tableCellView.syncNowButton.isEnabled = true && SafeDriveSDK.sharedSDK.ready
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.stopSyncNow(_:))
            }
            
            if task.syncing {
                tableCellView.syncStatus.startAnimation(self)
                tableCellView.restoreNowButton.image = NSImage(named: NSImageNameInvalidDataFreestandingTemplate)
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameStopProgressFreestandingTemplate)
            } else if task.restoring {
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
        guard self.syncListView.selectedRow != -1,
            let _ = self.uniqueClientID,
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
        
        self.updateSyncDetailsPanel(folder: syncFolder)
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return (row >= 1)
    }
    
}

extension SyncViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        // make room for the machine row at the top
        return 1 + folders.count
    }
    
}

extension SyncViewController: RestoreSelectionDelegate {
    func selectedSession(_ sessionName: String, folderID: UInt64, destination: URL, session: SDKSyncSession?) {
        assert(Thread.current == Thread.main, "selectedSession called on background thread")
        
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
        
        self.syncScheduler.cancel(folderID) {
            self.syncScheduler.queueSyncJob(uniqueClientID, folderID: folderID, direction: .reverse, name: sessionName, destination: destination, session: session)
        }
    }
}


extension SyncViewController: SDApplicationEventProtocol {
    
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

extension SyncViewController: SDSyncEventProtocol {
    
    func syncEvent(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "syncEvent called on main thread")
        
        let oldFirstResponder = self.view.window?.firstResponder
        let selectedIndexes = self.syncListView.selectedRowIndexes
        self.syncListView.reloadData()
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        self.view.window?.makeFirstResponder(oldFirstResponder)
        
        guard self.syncListView.selectedRow != -1,
            let _ = self.uniqueClientID,
            let syncFolder = self.folders[safe: self.syncListView.selectedRow - 1] else {
                return
        }
        
        guard let folderID = notification.object as? UInt64 else {
            SDLog("API contract invalid: syncEvent in SyncViewController")
            return
        }
        
        // don't update the panel unless the event was for the selected folder
        if syncFolder.id == folderID {
            self.updateSyncDetailsPanel(folder: syncFolder)
        }
    }
}

extension SyncViewController {
    @IBAction func verifyFolders(_ sender: AnyObject?) {
        
        for folder in folders {
            if !folder.exists() && folder.active {
                self.verifyFolder(folder)
            }
        }
    }
    
    func verifyFolder(_ folder: SDKSyncFolder) {
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.addButton(withTitle: "Find")
            alert.addButton(withTitle: "Restore")
            alert.addButton(withTitle: "Pause")
            
            alert.messageText = "SafeDrive cannot locate the \(folder.name) folder"
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
                    let panelTitle: String = NSLocalizedString("find the \(folder.name) folder", comment: "Title of window")
                    panel.title = panelTitle
                    let promptString: String = NSLocalizedString("Select", comment: "Button title")
                    panel.prompt = promptString
                    
                    self.delegate.showPanel(panel) { (result) in
            
                        if result == NSFileHandlingPanelOKButton {
                            guard let folderPath = panel.url?.path else {
                                return
                            }
                            
                            let completionQueue = DispatchQueue.main
                            
                            self.sdk.updateFolder(folder.name, path: folderPath, syncing: true, uniqueID: folder.id, syncFrequency: folder.syncFrequency, syncTime: folder.syncTime, completionQueue: completionQueue, success: { (_) in
                                self.readSyncFolders(self)
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
                                self.verifyFolder(folder)
                            }
                        }
                    }
                case NSAlertSecondButtonReturn:
                    self.startRestore(folder.id)
                case NSAlertThirdButtonReturn:
                    self.sdk.updateFolder(folder.name, path: folder.path, syncing: false, uniqueID: folder.id, syncFrequency: folder.syncFrequency, syncTime: folder.syncTime, completionQueue: DispatchQueue.main, success: {
                        self.readSyncFolders(self)
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
