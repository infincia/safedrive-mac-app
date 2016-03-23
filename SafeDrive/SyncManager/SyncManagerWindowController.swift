
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Crashlytics

import Realm
import RealmSwift

class SyncManagerWindowController: NSWindowController, NSOpenSavePanelDelegate {
    @IBOutlet var syncListView: NSOutlineView!
    @IBOutlet var spinner: NSProgressIndicator!
    
    @IBOutlet var addedField: NSTextField!

    @IBOutlet var lastSyncField: NSTextField!
    
    @IBOutlet var nextSyncField: NSTextField!
    
    @IBOutlet var failedSyncButton: NSButton!

    @IBOutlet var scheduleSelection: NSSegmentedControl!

    private var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
    private var sharedSafedriveAPI = API.sharedAPI
    
    private var accountController = AccountController.sharedAccountController
    
    private var syncScheduler = SyncScheduler.sharedSyncScheduler
    
    private var token: RealmSwift.NotificationToken?
    
    private var mac = Machine(name: NSHost.currentHost().localizedName!, uniqueClientID: "-1")
    
    private let dbURL: NSURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db")!.URLByAppendingPathComponent("sync.realm")
    
    // MARK: Initializers
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init() {
        self.init(windowNibName: "SyncManagerWindow")
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        do {
            try realm.write {
                let machineName = NSHost.currentHost().localizedName!
                realm.create(Machine.self, value: ["uniqueClientID": "-1", "name": machineName], update: true)
            }
        }
        catch {
            SDLog("failed to update machine in realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.token = realm.objects(SyncFolder).addNotificationBlock { results, error in
            
            guard let _ = results else {
                return
            }
            let selectedIndexes = self.syncListView.selectedRowIndexes
            self.syncListView.reloadItem(self.mac, reloadChildren: true)
            self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: true)
        }
        

    }
    
    override func windowDidLoad() {
        self.window?.backgroundColor = NSColor.whiteColor()
        
        let aWindow: INAppStoreWindow = self.window as! INAppStoreWindow
        aWindow.titleBarHeight = 24.0
        aWindow.showsBaselineSeparator = false
        let topColor: NSColor = NSColor.whiteColor()
        aWindow.titleBarStartColor = topColor
        aWindow.titleBarEndColor = topColor
        aWindow.baselineSeparatorColor = topColor
        aWindow.inactiveTitleBarEndColor = topColor
        aWindow.inactiveTitleBarStartColor = topColor
        aWindow.inactiveBaselineSeparatorColor = topColor

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
                    self.syncScheduler.queueSyncJob(folderID)

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
        self.spinner.startAnimation(self)
        self.sharedSafedriveAPI.deleteSyncFolder(uniqueID, success: {() -> Void in
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            let syncFolders = realm.objects(SyncFolder)
            
            let syncFolder = syncFolders.filter("uniqueID == \(uniqueID)")
            
            try! realm.write {
                realm.delete(syncFolder)
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
                
                try! realm.write {
                    // we update the local database with any info the server has to ensure they're in sync
                    // because the local database is storing things the remote server does not, we need to ensure
                    // that we don't blow away any of those local properties on existing objects, so
                    // we use Realm.create() instead of Realm.add()
                    realm.create(SyncFolder.self, value: ["uniqueID": folderId, "name": folderName, "path": folderPath, "machine": self.mac, "added": addedDate], update: true)
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
        let uniqueID: Int = button.tag
        self.syncScheduler.queueSyncJob(uniqueID)
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
            print("failed to create realm!!!")
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
                print("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return 0
            }
            let syncFolders = realm.objects(SyncFolder)
            return syncFolders.count
        }
        else if item is SyncFolder {
            return 0
        }
        // Root
        return 1
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if item is Machine {
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return ""
            }
            let syncFolders = realm.objects(SyncFolder)
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
            tableCellView.textField!.stringValue = syncFolder.name!
            let cellImage: NSImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            cellImage.size = NSMakeSize(15.0, 15.0)
            tableCellView.imageView!.image = cellImage
            tableCellView.removeButton.tag = syncFolder.uniqueID
            tableCellView.syncNowButton.tag = syncFolder.uniqueID
            if syncFolder.syncing {
                tableCellView.syncStatus.startAnimation(self)
                tableCellView.syncNowButton.enabled = false
            }
            else {
                tableCellView.syncStatus.stopAnimation(self)
                tableCellView.syncNowButton.enabled = true
            }

        }
        tableCellView.representedSyncItem = item

        return tableCellView;
        
    }
    
    
    //--------------------------
    // Selection tracking
    //--------------------------
    
    func outlineViewSelectionDidChange(notification: NSNotification) {
        if self.syncListView.selectedRow != -1 {
            guard let syncItem: SyncFolder = self.syncListView.itemAtRow(self.syncListView.selectedRow) as? SyncFolder else {
                print("no item at \(self.syncListView.selectedRow)")
                return
            }
            
            if let added = syncItem.added {
                self.addedField.stringValue = added.toMediumDateString()
            }
            else {
                self.addedField.stringValue = ""
            }
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            let syncTasks = realm.objects(SyncTask)
            
            if let syncTask = syncTasks.filter("syncFolder.uniqueID == \(syncItem.uniqueID)").sorted("syncDate").last {
                print(syncTask)
                self.failedSyncButton.enabled = !syncTask.success
                self.failedSyncButton.hidden = syncTask.success
                self.failedSyncButton.toolTip = syncTask.message
            }
            else {
                self.failedSyncButton.enabled = false
                self.failedSyncButton.hidden = true
            }
            
            if let syncTask = syncTasks.filter("syncFolder.uniqueID == \(syncItem.uniqueID) AND success == true").sorted("syncDate").last,
                lastSync = syncTask.syncDate {
                    self.lastSyncField.stringValue = lastSync.toMediumString()
            }
            else {
                self.lastSyncField.stringValue = ""
            }
            
            switch syncItem.syncFrequency {
            case "hourly":
                self.scheduleSelection.setSelected(true, forSegment: 0)
                self.nextSyncField.stringValue = NSDate().nextHour()?.toMediumString() ?? ""
            case "daily":
                self.scheduleSelection.setSelected(true, forSegment: 1)
                self.nextSyncField.stringValue = NSDate().nextDay()?.toMediumString() ?? ""
            case "weekly":
                self.scheduleSelection.setSelected(true, forSegment: 2)
                self.nextSyncField.stringValue = NSDate().nextWeek()?.toMediumString() ?? ""
            case "monthly":
                self.scheduleSelection.setSelected(true, forSegment: 3)
                self.nextSyncField.stringValue = NSDate().nextMonth()?.toMediumString() ?? ""
            default:
                self.scheduleSelection.selectedSegment = -1
                self.nextSyncField.stringValue = ""
            }
            self.scheduleSelection.enabled = true
        }
        else {
            self.addedField.stringValue = ""
            self.lastSyncField.stringValue = ""
            self.nextSyncField.stringValue = ""
            self.scheduleSelection.selectedSegment = -1
            self.scheduleSelection.enabled = false
            self.failedSyncButton.enabled = false
            self.failedSyncButton.hidden = true

        }
    }
    
    @IBAction func setSyncFrequencyForFolder(sender: AnyObject) {
        if self.syncListView.selectedRow != -1 {
            let syncItem: SyncFolder = self.syncListView.itemAtRow(self.syncListView.selectedRow) as! SyncFolder
            
            let control: NSSegmentedControl = sender as! NSSegmentedControl
            
            var syncFrequency: String
            
            switch control.selectedSegment {
            case 0:
                syncFrequency = "hourly"
            case 1:
                syncFrequency = "daily"
            case 2:
                syncFrequency = "weekly"
            case 3:
                syncFrequency = "monthly"
            default:
                syncFrequency = "minute"
            }
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            print("setting \(syncItem.name!) folder to \(syncFrequency) schedule")

            try! realm.write {
                syncItem.syncFrequency = syncFrequency
            }
        }

        
    }
    
    private func configureLowerPanel() {
        
    }
    
    
    private func reload() {
        assert(NSThread.isMainThread(), "Not main thread!!!")
        let selectedIndexes = self.syncListView.selectedRowIndexes
        self.syncListView.reloadItem(self.mac, reloadChildren: true)
        self.syncListView.expandItem(self.mac, expandChildren: true)
        self.syncListView.selectRowIndexes(selectedIndexes, byExtendingSelection: true)
    }
    
}