
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Crashlytics

import Realm
import RealmSwift

class SyncManagerWindowController: NSWindowController, NSOpenSavePanelDelegate, NSPopoverDelegate {
    @IBOutlet var syncListView: NSOutlineView!
    @IBOutlet var spinner: NSProgressIndicator!
    
    @IBOutlet var pathIndicator: NSPathControl!

    @IBOutlet var lastSyncField: NSTextField!
    
    @IBOutlet var nextSyncField: NSTextField!
    
    @IBOutlet var syncFailureInfoButton: NSButton!

    @IBOutlet var syncStatusButton: NSButton!
    
    @IBOutlet var syncTimePicker: NSDatePicker!

    @IBOutlet var scheduleSelection: NSPopUpButton!
    
    @IBOutlet var failurePopover: NSPopover!

    private var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
    private var sharedSafedriveAPI = API.sharedAPI
    
    private var accountController = AccountController.sharedAccountController
    
    private var syncScheduler = SyncScheduler.sharedSyncScheduler
    
    private var token: RealmSwift.NotificationToken?
    
    private var mac: Machine!
    
    private var uniqueClientID: String!
    
    private let dbURL: NSURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db")!.URLByAppendingPathComponent("sync.realm")
    
    // MARK: Initializers
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(uniqueClientID: String) {
        self.init(windowNibName: "SyncManagerWindow")
        self.uniqueClientID = uniqueClientID
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(self.uniqueClientID)'").last else {
            SDLog("failed to get current machine in realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.mac = currentMachine

    }
    
    override func windowDidLoad() {
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.token = realm.objects(SyncFolder).addNotificationBlock { results, error in
            assert(NSThread.isMainThread(), "Not main thread!!!")
            self.reload()
        }
        
        self.scheduleSelection.selectItemAtIndex(-1)

        self.readSyncFolders(self)
    }
    
    // MARK: UI Actions
    
    @IBAction func addSyncFolder(sender: AnyObject) {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.delegate = self
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        let panelTitle: String = NSLocalizedString("Select a folder", comment: "Title of window")
        panel.title = panelTitle
        let promptString: String = NSLocalizedString("Select", comment: "Button title")
        panel.prompt = promptString
        
        panel.beginWithCompletionHandler({(result: Int) -> Void in
            if result == NSFileHandlingPanelOKButton {
                self.spinner.startAnimation(self)
                
                self.sharedSafedriveAPI.createSyncFolder(panel.URL!, success: { (folderID: Int) -> Void in
                    guard let realm = try? Realm() else {
                        SDLog("failed to create realm!!!")
                        Crashlytics.sharedInstance().crash()
                        return
                    }
                    
                    let syncFolder = SyncFolder(name: panel.URL!.lastPathComponent!, url: panel.URL!, uniqueID: folderID)
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder.added = NSDate()
                    
                    syncFolder.machine = self.mac
                    
                    try! realm.write {
                        realm.add(syncFolder, update: true)
                    }
                    
                    self.readSyncFolders(self)
                    self.syncScheduler.queueSyncJob(self.uniqueClientID, folderID: folderID)

                }, failure: { (apiError: NSError) -> Void in
                    SDErrorHandlerReport(apiError)
                    self.spinner.stopAnimation(self)
                    let alert: NSAlert = NSAlert()
                    alert.messageText = NSLocalizedString("Error adding folder to your account", comment: "")
                    alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                    alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
                    alert.runModal()
                })
            }
        })
    }
    
    @IBAction func removeSyncFolder(sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let uniqueID: Int = button.tag
        SDLog("Deleting sync folder ID: %lu", uniqueID)
        let alert = NSAlert()
        alert.addButtonWithTitle("Cancel")
        alert.addButtonWithTitle("Move to Storage folder")
        // built on SFTP's rmdir command, but that doesn't work unless the dir is empty. Disabled for now.
        //alert.addButtonWithTitle("Delete")

        alert.messageText = "Stop syncing this folder?"
        alert.informativeText = "If you remove a sync folder from your account, the remote files will be moved to your Storage folder"
        alert.alertStyle = .InformationalAlertStyle
        
        alert.beginSheetModalForWindow(self.window!) { (response) in
            
            var op: SDSFTPOperation
            switch response {
            case NSAlertFirstButtonReturn:
                print("Cancel")
                return
            case NSAlertSecondButtonReturn:
                op = .MoveFolder
                print("Move")
                break
            case NSAlertThirdButtonReturn:
                op = .DeleteFolder
                print("Delete")
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
            guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(self.uniqueClientID)'").last else {
                return
            }
            let syncFolders = realm.objects(SyncFolder)
            
            let syncFolder = syncFolders.filter("machine == %@ AND uniqueID == \(uniqueID)", currentMachine).last!
            
            let defaultFolder: NSURL = NSURL(string: SDDefaultServerPath)!
            let machineFolder: NSURL = defaultFolder.URLByAppendingPathComponent(syncFolder.machine!.name!, isDirectory: true)
            let remoteFolder: NSURL = machineFolder.URLByAppendingPathComponent(syncFolder.name!, isDirectory: true)
            let urlComponents: NSURLComponents = NSURLComponents()
            urlComponents.user = self.accountController.internalUserName
            urlComponents.password = self.accountController.password
            urlComponents.host = self.accountController.remoteHost
            urlComponents.path = remoteFolder.path
            urlComponents.port = self.accountController.remotePort
            let remote: NSURL = urlComponents.URL!
            
            
            let syncController = SDSyncController()
            syncController.uniqueID = uniqueID
            syncController.SFTPOperation(op, remoteDirectory: remote, password: self.accountController.password, success: { 
                self.sharedSafedriveAPI.deleteSyncFolder(uniqueID, success: {() -> Void in
                    
                    guard let realm = try? Realm() else {
                        SDLog("failed to create realm!!!")
                        Crashlytics.sharedInstance().crash()
                        return
                    }
                    
                    let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(self.uniqueClientID)'").last!
                    
                    let syncFolder = realm.objects(SyncFolder).filter("machine == %@ AND uniqueID == \(uniqueID)", currentMachine).last!
                    let syncTasks = realm.objects(SyncTask).filter("syncFolder == %@", syncFolder)
                    
                    try! realm.write {
                        realm.delete(syncFolder)
                        realm.delete(syncTasks)
                    }
                    self.reload()
                    self.spinner.stopAnimation(self)
                    }, failure: {(apiError: NSError) -> Void in
                        SDErrorHandlerReport(apiError)
                        self.spinner.stopAnimation(self)
                        let alert: NSAlert = NSAlert()
                        alert.messageText = NSLocalizedString("Error removing folder from your account", comment: "")
                        alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                        alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
                        alert.runModal()
                })
            }, failure: { (error) in
                SDErrorHandlerReport(error)
                self.spinner.stopAnimation(self)
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error moving folder to Storage", comment: "")
                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help:\n\n \(error.localizedDescription)", comment: "")
                alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
                alert.runModal()
            })
        }
    }
    
    @IBAction func readSyncFolders(sender: AnyObject) {
        self.spinner.startAnimation(self)
        
        self.sharedSafedriveAPI.readSyncFoldersWithSuccess({ (folders: [[String : NSObject]]) -> Void in
            for folder in folders {
                /*
                Current sync folder model:
                
                "id" : 1,
                "folderName" : "Music",
                "folderPath" : /Volumes/MacOS/Music,
                "addedDate" : 1435864769463
                */
                
                let folderName = folder["folderName"] as! String
                let folderPath = folder["folderPath"]  as! String
                let folderId = folder["id"] as! Int
                
                let addedUnixDate: Double = folder["addedDate"] as! Double
                
                let addedDate: NSDate = NSDate(timeIntervalSince1970: addedUnixDate/1000)
                
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(self.uniqueClientID)'").last else {
                    SDLog("failed to get machine from realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                // try to retrieve and modify existing record if possible, avoids overwriting preferences only stored in entity
                // while still ensuring entities will have a default set on them for things like sync time
                var syncFolder = realm.objects(SyncFolder).filter("uniqueID == \(folderId)").last
                
                if syncFolder == nil {
                    syncFolder = SyncFolder(name: folderName, path: folderPath, uniqueID: folderId)
                }
                
                try! realm.write {
                    
                    syncFolder!.machine = currentMachine
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder!.added = addedDate
                    
                    realm.add(syncFolder!, update: true)
                }
            }
            self.reload()
            
            self.spinner.stopAnimation(self)

            
        }, failure: { (error: NSError) -> Void in
            SDErrorHandlerReport(error)
            self.spinner.stopAnimation(self)
            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error reading folders from your account", comment: "")
            alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.runModal()
        })
    }
    
    @IBAction func startSyncItemNow(sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let folderID: Int = button.tag
        self.syncScheduler.queueSyncJob(self.uniqueClientID, folderID: folderID)
    }
    
    @IBAction func stopSyncItemNow(sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let folderID: Int = button.tag
        let alert = NSAlert()
        alert.addButtonWithTitle("No")
        alert.addButtonWithTitle("Yes")
        
        alert.messageText = "Cancel sync?"
        alert.informativeText = "This folder is currently syncing, do you want to cancel?"
        alert.alertStyle = .InformationalAlertStyle
        
        alert.beginSheetModalForWindow(self.window!) { (response) in
            
            switch response {
            case NSAlertFirstButtonReturn:
                return
            case NSAlertSecondButtonReturn:
                self.syncScheduler.cancel(folderID)
                break
            default:
                return
            }
        }
    }
    
    // MARK: NSOpenSavePanelDelegate
    
    func panel(sender: AnyObject, validateURL url: NSURL) throws {
        let fileManager: NSFileManager = NSFileManager.defaultManager()
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFileAtPath(url.path!) {
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSystemError.FilePermissionDenied.rawValue, userInfo: errorInfo)
        }
        
        // check if the candidate sync path is a parent or subdirectory of an existing registered sync folder
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open local database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorSyncDomain, code: SDDatabaseError.OpenFailed.rawValue, userInfo: errorInfo)
        }
        
        let syncFolders = realm.objects(SyncFolder)
        if SyncFolder.hasConflictingFolderRegistered(url.path!, syncFolders: syncFolders) {
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSyncError.FolderConflict.rawValue, userInfo: errorInfo)
        }
    }
    
    // MARK: NSOutlineViewDelegate/Datasource
    
    func outlineView(outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.reload()
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if item is Machine {
            return true
        }
        return false
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item is Machine {
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return 0
            }
            guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(uniqueClientID)'").last else {
                return 0
            }
            let syncFolders = realm.objects(SyncFolder).filter("machine == %@", currentMachine)
            return syncFolders.count
        }
        else if item is SyncFolder {
            return 0
        }
        // Root
        return 1
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return ""
        }
        if item is Machine {
            let syncFolders = realm.objects(SyncFolder).filter("machine == %@", self.mac).sorted("name")
            return syncFolders[index]
        }
        return self.mac
    }

    func outlineView(outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        if item is Machine {
            return true
        }
        return false
    }
    
    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        return !self.outlineView(outlineView, isGroupItem: item)
    }
    
    func outlineView(outlineView: NSOutlineView, shouldShowCellExpansionForTableColumn tableColumn: NSTableColumn, item: AnyObject) -> Bool {
        return true
    }
    
    func outlineView(outlineView: NSOutlineView, shouldShowOutlineCellForItem item: AnyObject) -> Bool {
        return false
    }
    
    func outlineView(outlineView: NSOutlineView, shouldCollapseItem item: AnyObject) -> Bool {
        return false
    }
    
    func outlineView(outlineView: NSOutlineView, rowViewForItem item: AnyObject) -> NSTableRowView {
        let v: SyncManagerTableRowView = SyncManagerTableRowView()
        return v
    }
    
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn, item: AnyObject) -> NSView {
        var tableCellView: SyncManagerTableCellView
        if item is Machine {
            tableCellView = outlineView.makeViewWithIdentifier("MachineView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = self.mac.name!
            let cellImage: NSImage = NSImage(named: NSImageNameComputer)!
            cellImage.size = NSMakeSize(15.0, 15.0)
            tableCellView.imageView!.image = cellImage
        }
        else if item is SyncFolder {
            let syncFolder = item as! SyncFolder
            tableCellView = outlineView.makeViewWithIdentifier("FolderView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = syncFolder.name!.capitalizedString
            let cellImage: NSImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            cellImage.size = NSMakeSize(15.0, 15.0)
            tableCellView.imageView!.image = cellImage
            tableCellView.removeButton.tag = syncFolder.uniqueID
            tableCellView.syncNowButton.tag = syncFolder.uniqueID
            if syncFolder.syncing {
                tableCellView.syncStatus.startAnimation(self)
                tableCellView.syncNowButton.enabled = true
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.stopSyncItemNow(_:))
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameStopProgressFreestandingTemplate)

            }
            else {
                tableCellView.syncStatus.stopAnimation(self)
                tableCellView.syncNowButton.enabled = true
                tableCellView.syncNowButton.target = self
                tableCellView.syncNowButton.action = #selector(self.startSyncItemNow(_:))
                tableCellView.syncNowButton.image = NSImage(named: NSImageNameRefreshFreestandingTemplate)

            }
        }
        else {
            tableCellView = outlineView.makeViewWithIdentifier("FolderView", owner: self) as! SyncManagerTableCellView
        }
        tableCellView.representedSyncItem = item

        return tableCellView;
        
    }
    
    
    //--------------------------
    // Selection tracking
    //--------------------------
    // NOTE: This really needs to be refactored into a view to limite how massive this VC is becoming
    func outlineViewSelectionDidChange(notification: NSNotification) {
        if self.syncListView.selectedRow != -1 {
            guard let syncItem: SyncFolder = self.syncListView.itemAtRow(self.syncListView.selectedRow) as? SyncFolder else {
                SDLog("no item at \(self.syncListView.selectedRow)")
                return
            }
            
            if let syncTime = syncItem.syncTime {
                self.syncTimePicker.dateValue = syncTime
            }
            else {
                SDLog("Failed to load date in sync manager")
            }
            
            if let syncURL = syncItem.url {
                self.pathIndicator.URL = syncURL
            }
            else {
                SDLog("Failed to load path in sync manager")
            }
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            let syncTasks = realm.objects(SyncTask)

            if let syncTask = syncTasks.filter("syncFolder.machine.uniqueClientID == '\(self.mac.uniqueClientID!)' AND syncFolder == %@", syncItem).sorted("syncDate").last {
                if syncItem.syncing {
                    self.syncStatusButton.image = NSImage(named: NSImageNameStatusPartiallyAvailable)
                    self.syncFailureInfoButton.action = nil
                    self.syncFailureInfoButton.hidden = true
                    self.syncFailureInfoButton.enabled = false
                    self.syncFailureInfoButton.toolTip = ""
                }
                else if syncTask.success {
                    self.syncStatusButton.image = NSImage(named: NSImageNameStatusAvailable)
                    self.syncFailureInfoButton.action = nil
                    self.syncFailureInfoButton.hidden = true
                    self.syncFailureInfoButton.enabled = false
                    self.syncFailureInfoButton.toolTip = ""
                }
                else {
                    self.syncStatusButton.image = NSImage(named: NSImageNameStatusUnavailable)
                    self.syncFailureInfoButton.action = #selector(self.showFailurePopover)
                    self.syncFailureInfoButton.hidden = false
                    self.syncFailureInfoButton.enabled = true
                    self.syncFailureInfoButton.toolTip = NSLocalizedString("Last sync failed, click here for details", comment: "")
                }
                let failureView = self.failurePopover.contentViewController!.view as! SyncFailurePopoverView
                failureView.message.stringValue = syncTask.message ?? ""
            }
            else {
                self.syncStatusButton.image = NSImage(named: NSImageNameStatusPartiallyAvailable)
                self.syncFailureInfoButton.action = nil
                self.syncFailureInfoButton.hidden = true
                self.syncFailureInfoButton.enabled = false
                self.syncFailureInfoButton.toolTip = nil
            }
            
            if let syncTask = syncTasks.filter("syncFolder.machine.uniqueClientID == '\(self.mac.uniqueClientID!)' AND syncFolder == %@ AND success == true", syncItem).sorted("syncDate").last,
                lastSync = syncTask.syncDate {
                    self.lastSyncField.stringValue = lastSync.toMediumString()
            }
            else {
                self.lastSyncField.stringValue = ""
            }
            
            switch syncItem.syncFrequency {
            case "hourly":
                self.scheduleSelection.selectItemAtIndex(0)
                self.nextSyncField.stringValue = NSDate().nextHour()?.toMediumString() ?? ""
                self.syncTimePicker.enabled = false
                self.syncTimePicker.hidden = true
                let components = NSDateComponents()
                components.hour = 0
                components.minute = 0
                let calendar = NSCalendar.currentCalendar()
                self.syncTimePicker.dateValue = calendar.dateFromComponents(components)!
            case "daily":
                self.scheduleSelection.selectItemAtIndex(1)
                self.nextSyncField.stringValue = NSDate().nextDayAt((syncItem.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.enabled = true
                self.syncTimePicker.hidden = false
            case "weekly":
                self.scheduleSelection.selectItemAtIndex(2)
                self.nextSyncField.stringValue = NSDate().nextWeekAt((syncItem.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.enabled = true
                self.syncTimePicker.hidden = false
            case "monthly":
                self.scheduleSelection.selectItemAtIndex(3)
                self.nextSyncField.stringValue = NSDate().nextMonthAt((syncItem.syncTime?.hour)!, minute: (syncItem.syncTime?.minute)!)?.toMediumString() ?? ""
                self.syncTimePicker.enabled = true
                self.syncTimePicker.hidden = false
            default:
                self.scheduleSelection.selectItemAtIndex(-1)
                self.nextSyncField.stringValue = ""
                self.syncTimePicker.enabled = false
                self.syncTimePicker.hidden = false
            }
            self.scheduleSelection.enabled = true
        }
        else {
            self.lastSyncField.stringValue = ""
            self.nextSyncField.stringValue = ""
            self.scheduleSelection.selectItemAtIndex(-1)
            self.scheduleSelection.enabled = false
            self.syncStatusButton.image = NSImage(named: NSImageNameStatusNone)
            self.syncFailureInfoButton.action = nil
            self.syncFailureInfoButton.hidden = true
            self.syncFailureInfoButton.enabled = false
            self.syncFailureInfoButton.toolTip = nil
            self.syncTimePicker.enabled = false
            self.syncTimePicker.hidden = true
            let components = NSDateComponents()
            components.hour = 0
            components.minute = 0
            let calendar = NSCalendar.currentCalendar()
            self.syncTimePicker.dateValue = calendar.dateFromComponents(components)!

        }
    }
    
    @IBAction func setSyncFrequencyForFolder(sender: AnyObject) {
        if self.syncListView.selectedRow != -1 {
            let syncItem: SyncFolder = self.syncListView.itemAtRow(self.syncListView.selectedRow) as! SyncFolder
            
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

            try! realm.write {
                syncItem.syncFrequency = syncFrequency
            }
        }
    }
    
    
    private func reload() {
        assert(NSThread.isMainThread(), "Not main thread!!!")
        let oldFirstResponder = self.window?.firstResponder
        let selectedIndexes = self.syncListView.selectedRowIndexes
        self.syncListView.reloadItem(self.mac, reloadChildren: true)
        self.syncListView.expandItem(self.mac, expandChildren: true)
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: true)
        self.window?.makeFirstResponder(oldFirstResponder)
    }
    
    @objc
    private func showFailurePopover() {
        self.failurePopover.showRelativeToRect(self.syncFailureInfoButton.bounds, ofView: self.syncFailureInfoButton, preferredEdge: .MinY)
    }
    
    @IBAction
    func setSyncTime(sender: AnyObject) {
        if self.syncListView.selectedRow != -1 {
            let syncItem: SyncFolder = self.syncListView.itemAtRow(self.syncListView.selectedRow) as! SyncFolder
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            try! realm.write {
                syncItem.syncTime = self.syncTimePicker.dateValue
            }
        }
    }
}