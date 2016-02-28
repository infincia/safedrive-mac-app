
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Cocoa

class SyncManagerWindowController: NSWindowController, NSOpenSavePanelDelegate, SDAccountProtocol {
    @IBOutlet var syncListView: NSOutlineView!
    @IBOutlet var spinner: NSProgressIndicator!
    
    var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
    var sharedSafedriveAPI = SDAPI.sharedAPI()
    
    var accountController = SDAccountController.sharedAccountController()
    
    var syncController = SDSyncController.sharedAPI()
    
    // MARK: Initializers
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init() {
        self.init(windowNibName: "SyncManagerWindow")
        self.syncController.mac = SDSyncItem(label: NSHost.currentHost().localizedName, localFolder: nil, isMachine: true, uniqueID: -1)
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
            let folder: SDSyncItem = self.syncController.mac.syncFolderForUniqueId(uniqueID)
            self.syncController.mac.removeSyncFolder(folder)
            self.syncListView.reloadItem(self.syncController.mac, reloadChildren: true)
            self.syncListView.expandItem(self.syncController.mac, expandChildren: true)
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
            self.syncController.mac.syncFolders.removeAllObjects()
            for folder in folders {
                /*
                Current sync folder model:
                
                "id" : 1,
                "folderName" : "Music",
                "folderPath" : /Volumes/MacOS/Music,
                "addedDate" : 1435864769463
                */
                
                if let folder = folder as? [String: AnyObject] {
                    let folderName = folder["folderName"] as? String
                    let folderPath = folder["folderPath"]  as? String
                    let folderId = folder["id"] as? Int
                    // unused: let addedDate: Int = folder[@"addedDate"] as? Int
                    let localFolder: NSURL = NSURL.fileURLWithPath(folderPath!, isDirectory: true)
                    let syncItem: SDSyncItem = SDSyncItem(label: folderName, localFolder: localFolder, isMachine: false, uniqueID: folderId!)
                    self.syncController.mac.appendSyncFolder(syncItem)
                }

            }
            
            self.syncListView.reloadItem(self.syncController.mac, reloadChildren: true)
            self.syncListView.expandItem(self.syncController.mac, expandChildren: true)
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
        let folder: SDSyncItem = self.syncController.mac.syncFolderForUniqueId(uniqueID)
        folder.syncing = true
        let folderName: String = folder.label
        let localFolder: NSURL = folder.url
        let defaultFolder: NSURL = NSURL(string: SDDefaultServerPath)!
        let machineFolder: NSURL = defaultFolder.URLByAppendingPathComponent(NSHost.currentHost().localizedName!, isDirectory: true)
        let remoteFolder: NSURL = machineFolder.URLByAppendingPathComponent(folderName, isDirectory: true)
        let urlComponents: NSURLComponents = NSURLComponents()
        urlComponents.user = self.accountController.internalUserName
        urlComponents.host = self.accountController.remoteHost
        urlComponents.path = remoteFolder.path
        urlComponents.port = self.accountController.remotePort
        let remote: NSURL = urlComponents.URL!
        
        self.syncListView.reloadItem(self.syncController.mac, reloadChildren: true)
        
        self.syncController.startSyncTaskWithLocalURL(localFolder, serverURL: remote, password: self.accountController.password, restore: false, success: { (syncURL: NSURL, error: NSError?) -> Void in
            SDLog("Sync finished for local URL: %@", localFolder)
            folder.syncing = false
            self.syncListView.reloadItem(self.syncController.mac, reloadChildren: true)

        }, failure: { (syncURL: NSURL, error: NSError?) -> Void in
            SDErrorHandlerReport(error)
            SDLog("Sync failed for local URL: %@", localFolder)
            SDLog("Sync error: %@", error!.localizedDescription)
            folder.syncing = false
            self.syncListView.reloadItem(self.syncController.mac, reloadChildren: true)
            let alert: NSAlert = NSAlert()
            alert.messageText = NSLocalizedString("Error", comment: "")
            alert.informativeText = error!.localizedDescription
            alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
            alert.runModal()

        })
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
        if self.syncController.mac.hasConflictingFolderRegistered(url) {
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSystemError.FolderConflict.rawValue, userInfo: errorInfo)
        }
    }
    
    // MARK: NSOutlineViewDelegate/Datasource
    
    func outlineView(outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.syncListView.reloadItem(self.syncController.mac, reloadChildren: true)
        self.syncListView.expandItem(self.syncController.mac, expandChildren: true)
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        let syncItem: SDSyncItem = item as! SDSyncItem
        return syncItem.isMachine
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item == nil {
            // Root
            return 1
        }
        let syncItem: SDSyncItem = item as! SDSyncItem
        if syncItem.isMachine {
            return syncItem.syncFolders.count
        }
        else {
            return 0
        }
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if item == nil {
            // Root
            return self.syncController.mac
        }
        let syncItem: SDSyncItem = item as! SDSyncItem
        if syncItem.isMachine {
            return syncItem.syncFolders[index]
        }
        else {
            return self.syncController.mac
        }
    }

    func outlineView(outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        let syncItem: SDSyncItem = item as! SDSyncItem
        if syncItem.isMachine {
            return true
        }
        else {
            return false
        }
    }
    
    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        if self.outlineView(outlineView, isGroupItem: item) {
            return false
        }
        else {
            return true
        }
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
        let syncItem: SDSyncItem = (item as! SDSyncItem)
        if self.outlineView(outlineView, isGroupItem: item) {
            tableCellView = outlineView.makeViewWithIdentifier("MachineView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = syncItem.label
            let cellImage: NSImage = NSImage(named: NSImageNameComputer)!
            cellImage.size = NSMakeSize(15.0, 15.0)
            tableCellView.imageView!.image = cellImage
        }
        else {
            tableCellView = outlineView.makeViewWithIdentifier("FolderView", owner: self) as! SyncManagerTableCellView
            tableCellView.textField!.stringValue = syncItem.label
            let cellImage: NSImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            cellImage.size = NSMakeSize(15.0, 15.0)
            tableCellView.imageView!.image = cellImage
            tableCellView.removeButton.tag = syncItem.uniqueID
            tableCellView.syncNowButton.tag = syncItem.uniqueID
            if syncItem.syncing {
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
        tableCellView.representedSyncItem = syncItem

        return tableCellView;
        
    }
    
    
    //--------------------------
    // Selection tracking
    //--------------------------
    
    func outlineViewSelectionDidChange(notification: NSNotification) {
        if self.syncListView.selectedRow != -1 {
            let syncItem: SDSyncItem = self.syncListView.itemAtRow(self.syncListView.selectedRow) as! SDSyncItem
            // visually selecting specific sync folders in the list is disabled for now but this would be the place to
            // do something with them, like display recent sync info or folder stats in the lower window pane
        }
    }
    
}