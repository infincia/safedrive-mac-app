
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import Realm
import RealmSwift
import SafeDriveSDK

protocol RestoreSelectionDelegate: class {
    func selectedSession(_ sessionName: String, folderID: UInt64, destination: URL)
}

extension RestoreSelectionWindowController: NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 else {
            return nil
        }
        
        let view = tableView.make(withIdentifier: "RestoreSelectionCellView", owner: self) as! RestoreSelectionTableCellView
        
        let session = self.sessions[row]
        
        view.size.stringValue = ByteCountFormatter.string(fromByteCount: Int64(session.size), countStyle: .file)
        
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short
        view.date.stringValue = dateFormatter.string(from: session.date)
        
        view.sessionName = session.name
        
        view.sessionID = session.session_id
        
        view.sessionSize = session.size
        
        return view
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.sessions.count
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int {
        return 1
    }
}

extension RestoreSelectionWindowController:  NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let sessionIndex = restoreSelectionList.selectedRow
        
        guard let _ = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            return
        }
        
    }
}

extension RestoreSelectionWindowController: NSOpenSavePanelDelegate {
    func panel(_ sender: Any, validate url: URL) throws {
        let fileManager: FileManager = FileManager.default
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFile(atPath: url.path) {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")]
            throw NSError(domain: SDErrorDomainNotReported, code: SDSystemError.filePermissionDenied.rawValue, userInfo: errorInfo)
        }
        
        // check if the candidate sync path is a parent or subdirectory of an existing registered sync folder
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open local database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorDomainReported, code: SDDatabaseError.openFailed.rawValue, userInfo: errorInfo)
        }
        
        let syncFolders = realm.objects(SyncFolder.self)
        if SyncFolder.hasConflictingFolderRegistered(url.path, syncFolders: syncFolders) {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")]
            throw NSError(domain: SDErrorDomainNotReported, code: SDSyncError.folderConflict.rawValue, userInfo: errorInfo)
        }
        
        // check that enough space is available in the selected location
        let sessionIndex = self.restoreSelectionList.selectedRow
        
        guard sessionIndex != -1, let sessionView = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Please select a session to restore so that SafeDrive can ensure there is enough free space available", comment: "String informing the user that a session must be selected so that we can check for available space")]
            throw NSError(domain: SDErrorDomainNotReported, code: SDSyncError.folderConflict.rawValue, userInfo: errorInfo)
        }
        
    
        if let attr = try? fileManager.attributesOfFileSystem(forPath: url.path),
           let freeSpace = attr[FileAttributeKey.systemFreeSize] as? UInt64 {
            
            if sessionView.sessionSize > freeSpace {
                let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("The selected location does not have enough free space to restore the session", comment: "String informing the user that the restore folder location doesn't have enough free space")]
                throw NSError(domain: SDErrorDomainNotReported, code: SDSyncError.folderConflict.rawValue, userInfo: errorInfo)
            }
        
        }
    }
}

class RestoreSelectionWindowController: NSWindowController {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK

    fileprivate var sessions = [SDSyncSession]()

    fileprivate var uniqueClientID: String!
    fileprivate var folderID: UInt64!
    
    @IBOutlet weak var restoreSelectionList: NSTableView!
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var errorField: NSTextField!
    @IBOutlet weak var destination: NSPathControl!
    @IBOutlet weak var destinationButton: NSButton!

    weak var restoreSelectionDelegate: RestoreSelectionDelegate?
    
    var realm: Realm?
    
    convenience init() {
        self.init(windowNibName: "RestoreSelectionWindow")
    }
    
    
    convenience init?(delegate: RestoreSelectionDelegate, uniqueClientID: String, folderID: UInt64) {
        self.init(windowNibName: "RestoreSelectionWindow")

        self.restoreSelectionDelegate = delegate
        
        self.uniqueClientID = uniqueClientID
        
        self.folderID = folderID
        
        guard let realm = try? Realm() else {
            SDLog("failed to create realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        self.realm = realm
        
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.spinner.stopAnimation(self)
        self.errorField.stringValue = ""
        
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }

        guard let syncFolder = realm.objects(SyncFolder.self).filter("uniqueID == %@", self.folderID).last else {
            SDLog("failed to get folder from realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        if let path = syncFolder.path,
            let url = URL(string: path) {
            self.destination.url = url
        } else {
            SDLog("failed to set default destination url: \(syncFolder.path)")
        }
        
        self.readSyncSessions(self)
    }
    
        
    fileprivate func reload() {
        assert(Thread.isMainThread, "Not main thread!!!")
        self.restoreSelectionList.reloadData()
        let oldFirstResponder = self.window?.firstResponder
        let selectedIndexes = self.restoreSelectionList.selectedRowIndexes
        self.restoreSelectionList.selectRowIndexes(selectedIndexes, byExtendingSelection: true)
        self.window?.makeFirstResponder(oldFirstResponder)
    }
    
    @IBAction func cancel(sender: AnyObject?) {
        guard let window = self.window else {
            SDLog("API contract invalid: window not found in RestoreSelectionWindowController")
            return
        }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.close()
        }
    }
    
    @IBAction func changeDestination(sender: AnyObject?) {
        
        let panel: NSOpenPanel = NSOpenPanel()
        
        panel.delegate = self

        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        let panelTitle: String = NSLocalizedString("Select a destination folder", comment: "Title of window")
        panel.title = panelTitle
        let promptString: String = NSLocalizedString("Select", comment: "Button title")
        panel.prompt = promptString
        
        // swiftlint:disable force_unwrapping
        panel.beginSheetModal(for: self.window!) { (result)  in
            if result == NSFileHandlingPanelOKButton {
                if let new = panel.url {
                    self.destination.url = new
                }
            }
        }
        // swiftlint:enable force_unwrapping

    }
    
    @IBAction func startRestore(sender: AnyObject?) {
        guard let _ = self.uniqueClientID else {
            return
        }

        self.spinner.startAnimation(self)
        
        let sessionIndex = restoreSelectionList.selectedRow
        guard let v = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            SDLog("failed to get session view")

            return
        }
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            
            return
        }
        
        guard let destination = self.destination.url else {
            SDLog("no destination selected")
            return
        }

        
        if let syncSession = realm.objects(PersistedSyncSession.self).filter("name == %@", v.sessionName).last,
            let name = syncSession.name {
            self.restoreSelectionDelegate?.selectedSession(name, folderID: self.folderID, destination: destination)
            self.close()
        } else {
            SDLog("failed to get session from realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
    }
    
    @IBAction func readSyncSessions(_ sender: AnyObject) {
        guard let uniqueClientID = self.uniqueClientID else {
            return
        }
        
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        self.sdk.getSessions(completionQueue: DispatchQueue.main, success: { (sessions: [SDSyncSession]) in
            self.errorField.stringValue = ""
            guard let realm = self.realm else {
                SDLog("failed to get realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            // try to delete all existing local records for this folder for consistency
            let syncSessions = realm.objects(PersistedSyncSession.self).filter("folderId == %@", Int64(self.folderID))
            
            // swiftlint:disable force_try
            try! realm.write {
                realm.delete(syncSessions)
            }
            // swiftlint:enable force_try
            self.sessions.removeAll()
            for session in sessions {
                /*
                 Current sync session model:
                 
                 "id" : 1,
                 "name" : <UUID>,
                 "size" : 9000,
                 "date"  : 1435864769463,
                 */
                
                let name = session.name

                let sessionId = session.session_id
                
                let folderId = session.folder_id
                
                let date = session.date
                
                let size = session.size
                

                let syncSession = PersistedSyncSession(syncDate: date, size: Int64(size), name: name, folderId: Int64(folderId), sessionId: Int64(sessionId))
                
                
                // swiftlint:disable force_try
                try! realm.write {
                    
                    syncSession.uniqueClientID = uniqueClientID
                    
                    realm.add(syncSession, update: true)
                }
                // swiftlint:enable force_try
                
                if session.folder_id == self.folderID {
                    self.sessions.append(session)
                }

            }
            self.reload()
            
            self.spinner.stopAnimation(self)
            
            // select the first row automatically
            let count = self.restoreSelectionList.numberOfRows
            if count >= 1 {
                let indexSet = IndexSet(integer: 0)
                self.restoreSelectionList.selectRowIndexes(indexSet, byExtendingSelection: false)
                self.restoreSelectionList.becomeFirstResponder()
            }
            
        }, failure: { (error) in
            let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
                
            self.errorField.textColor = fadedRed
                
            self.errorField.stringValue = error.message
            
            SDErrorHandlerReport(error)
            
            self.spinner.stopAnimation(self)
        })
    }
    
    @IBAction func removeSyncSession(_ sender: AnyObject) {
        
        let sessionIndex = restoreSelectionList.selectedRow
        guard let v = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            SDLog("failed to get session view")

            return
        }
        
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        
        self.sdk.removeSession(v.sessionID, completionQueue: DispatchQueue.main, success: {
            self.errorField.stringValue = ""
            self.readSyncSessions(self)
        }, failure: { (error) in
            let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
                
            self.errorField.textColor = fadedRed
                
            self.errorField.stringValue = error.message
            
            SDErrorHandlerReport(error)
            
            self.spinner.stopAnimation(self)
        })
    }

    
}
