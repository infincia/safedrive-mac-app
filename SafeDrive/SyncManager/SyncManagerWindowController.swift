
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Cocoa

import Realm
import RealmSwift

class SyncManagerWindowController: NSWindowController, NSOpenSavePanelDelegate, SDAccountProtocol {
    @IBOutlet var syncListView: NSOutlineView!
    @IBOutlet var spinner: NSProgressIndicator!
    
    private var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
    private var sharedSafedriveAPI = SDAPI.sharedAPI()
    
    private var accountController = AccountController.sharedAccountController
    
    private var syncScheduler = SyncScheduler.sharedSyncScheduler
    
    
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
        var config = Realm.Configuration()
        
        config.path = dbURL.path
        
        Realm.Configuration.defaultConfiguration = config
        
        guard let realm = try? Realm() else {
            print("failed to create realm!!!")
            return
        }
        
        do {
            try realm.write {
                let machineName = NSHost.currentHost().localizedName!
                realm.create(Machine.self, value: ["uniqueClientID": "-1", "name": machineName], update: true)
            }
        }
        catch {
            print("failed to write machine to realm!!!")
            
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didSignIn:", name: SDAccountSignInNotification, object: nil)
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
                    let realm = try! Realm()
                    
                    let syncFolder = SyncFolder(name: panel.URL!.lastPathComponent!, url: panel.URL!, uniqueID: folderID)
                    
                    // this is the only place where the `added` property should be set on SyncFolders
                    syncFolder.added = NSDate()
                    
                    syncFolder.machine = self.mac
                    
                    try! realm.write {
                        realm.add(syncFolder, update: true)
                    }
                    
                    self.readSyncFolders(self)

                }, failure: { (apiError: NSError) -> Void in
                    SDErrorHandlerReport(apiError)
                    self.spinner.stopAnimation(self)
                    let alert: NSAlert = NSAlert()
                    alert.messageText = NSLocalizedString("Error", comment: "")
                    alert.informativeText = apiError.localizedDescription
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
            
            let syncFolders = try! Realm().objects(SyncFolder)
            
            let syncFolder = syncFolders.filter("uniqueID == \(uniqueID)")
            
            let realm = try! Realm()
            try! realm.write {
                realm.delete(syncFolder)
            }
            
            self.syncListView.reloadItem(self.mac, reloadChildren: true)
            self.syncListView.expandItem(self.mac, expandChildren: true)
            self.spinner.stopAnimation(self)
        }, failure: {(apiError: NSError) -> Void in
            SDErrorHandlerReport(apiError)
            self.spinner.stopAnimation(self)
            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error", comment: "")
            alert.informativeText = apiError.localizedDescription
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.runModal()
        })
    }
    
    @IBAction func readSyncFolders(sender: AnyObject) {
        self.spinner.startAnimation(self)
        
        self.sharedSafedriveAPI.readSyncFoldersWithSuccess({ (folders: [[NSObject : AnyObject]]) -> Void in
            for folder in folders {
                /*
                Current sync folder model:
                
                "id" : 1,
                "folderName" : "Music",
                "folderPath" : /Volumes/MacOS/Music,
                "addedDate" : 1435864769463
                */
                
                if let folder = folder as? [String: AnyObject] {
                    let folderName = folder["folderName"] as! String
                    let folderPath = folder["folderPath"]  as! String
                    let folderId = folder["id"] as! Int
                    
                    let addedUnixDate: Double = folder["addedDate"] as! Double
                    
                    let addedDate: NSDate = NSDate(timeIntervalSince1970: addedUnixDate/1000)
                    
                    let realm = try! Realm()
                    
                    try! realm.write {
                        // we update the local database with any info the server has to ensure they're in sync
                        // because the local database is storing things the remote server does not, we need to ensure
                        // that we don't blow away any of those local properties on existing objects, so
                        // we use Realm.create() instead of Realm.add()
                        realm.create(SyncFolder.self, value: ["uniqueID": folderId, "name": folderName, "path": folderPath, "machine": self.mac, "added": addedDate], update: true)
                    }
                }

            }
            
            self.syncListView.reloadItem(self.mac, reloadChildren: true)
            self.syncListView.expandItem(self.mac, expandChildren: true)
            self.spinner.stopAnimation(self)

            
        }, failure: { (error: NSError) -> Void in
            SDErrorHandlerReport(error)
            self.spinner.stopAnimation(self)
            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error", comment: "")
            alert.informativeText = error.localizedDescription
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.runModal()
        })
    }
    
    @IBAction func startSyncItemNow(sender: AnyObject) {
        let button: NSButton = sender as! NSButton
        let uniqueID: Int = button.tag
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            self.syncScheduler.sync(uniqueID)
        }
    }
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: NSNotification) {
        self.readSyncFolders(self)
    }
    
    func didReceiveAccountDetails(notification: NSNotification) {
    }
    
    func didReceiveAccountStatus(notification: NSNotification) {
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
        let syncFolders = try! Realm().objects(SyncFolder)
        if SyncFolder.hasConflictingFolderRegistered(url.path!, syncFolders: syncFolders) {
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSystemError.FolderConflict.rawValue, userInfo: errorInfo)
        }
    }
    
    // MARK: NSOutlineViewDelegate/Datasource
    
    func outlineView(outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.syncListView.reloadItem(self.mac, reloadChildren: true)
        self.syncListView.expandItem(self.mac, expandChildren: true)
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if item is Machine {
            return true
        }
        return false
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item is Machine {
            let syncFolders = try! Realm().objects(SyncFolder)
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
            let syncFolders = try! Realm().objects(SyncFolder)
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
        if self.outlineView(outlineView, isGroupItem: item) {
            let machine = item as! Machine
            tableCellView = outlineView.makeViewWithIdentifier("MachineView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = machine.name!
            let cellImage: NSImage = NSImage(named: NSImageNameComputer)!
            cellImage.size = NSMakeSize(15.0, 15.0)
            tableCellView.imageView!.image = cellImage
        }
        else {
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
                tableCellView.syncNowButton.hidden = true
            }
            else {
                tableCellView.syncStatus.stopAnimation(self)
                tableCellView.syncNowButton.enabled = true
                tableCellView.syncNowButton.hidden = false
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
            let syncItem: SyncFolder = self.syncListView.itemAtRow(self.syncListView.selectedRow) as! SyncFolder
            // visually selecting specific sync folders in the list is disabled for now but this would be the place to
            // do something with them, like display recent sync info or folder stats in the lower window pane
        }
    }
    
}