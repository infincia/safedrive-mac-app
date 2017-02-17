
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import SafeDriveSDK
import Realm
import RealmSwift

protocol RestoreSelectionDelegate: class {
    func selectedSession(_ sessionName: String, folderID: UInt64, destination: URL)
}

extension RestoreSelectionWindowController: NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
        
        SDLog("setting session list view for \(session.name)")

        return view
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        SDLog("found \(self.sessions.count) sessions")

        return self.sessions.count
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int {
        SDLog("setting 1 session list section")
        return 1
    }
}

extension RestoreSelectionWindowController:  NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let sessionIndex = restoreSelectionList.selectedRow
        
        guard let _ = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            SDLog("failed to get session view")

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
    
    convenience init() {
        self.init(windowNibName: "RestoreSelectionWindow")
    }
    
    
    convenience init?(delegate: RestoreSelectionDelegate, uniqueClientID: String, folderID: UInt64) {
        self.init(windowNibName: "RestoreSelectionWindow")

        self.restoreSelectionDelegate = delegate
        
        self.uniqueClientID = uniqueClientID
        
        self.folderID = folderID
        
        
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.spinner.stopAnimation(self)
        self.errorField.stringValue = ""
        
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
        
        guard let syncFolder = realm.objects(SyncFolder.self).filter("machine == %@ AND uniqueID == %@", currentMachine, self.folderID).last else {
            SDLog("failed to get machine from realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        if let url = URL(string: syncFolder.path!) {
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
        self.close()
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
        
        panel.beginSheetModal(for: self.window!) { (result)  in
            if result == NSFileHandlingPanelOKButton {
                if let new = panel.url {
                    self.destination.url = new
                }
            }
        }

    }
    
    @IBAction func startRestore(sender: AnyObject?) {
        self.spinner.startAnimation(self)
        
        let sessionIndex = restoreSelectionList.selectedRow
        SDLog("selecting row at \(sessionIndex)")
        guard let v = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            SDLog("failed to get session view")

            return
        }
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
        
        if let syncSession = realm.objects(PersistedSyncSession.self).filter("machine == %@ AND name == %@", currentMachine, v.sessionName).last {
            self.restoreSelectionDelegate?.selectedSession(syncSession.name!, folderID: self.folderID, destination: self.destination.url!)
            self.close()
        } else {
            SDLog("failed to get session from realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
    }
    
    @IBAction func readSyncSessions(_ sender: AnyObject) {
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        SDLog("getting sessions")
        self.sdk.getSessions(completionQueue: DispatchQueue.main, success: { (sessions: [SDSyncSession]) in
            self.errorField.stringValue = ""
            SDLog("got sessions")
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
            
            // try to delete all existing local records for this folder for consistency
            let syncSessions = realm.objects(PersistedSyncSession.self).filter("machine == %@ AND folderId == %@", currentMachine, Int64(self.folderID))
            
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
                    
                    syncSession.machine = currentMachine
                    
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
            let count = self.restoreSelectionList!.numberOfRows
            if count >= 1 {
                let indexSet = IndexSet(integer: 1)
                self.restoreSelectionList!.selectRowIndexes(indexSet, byExtendingSelection: false)
                self.restoreSelectionList!.becomeFirstResponder()
            }
            
        }, failure: { (error) in
            SDLog("failed to get sessions")
            let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
                
            self.errorField.textColor = fadedRed
                
            self.errorField.stringValue = error.message
            
            SDErrorHandlerReport(error)
            
            self.spinner.stopAnimation(self)
        })
    }
    
    @IBAction func removeSyncSession(_ sender: AnyObject) {
        
        let sessionIndex = restoreSelectionList.selectedRow
        SDLog("selecting row at \(sessionIndex)")
        guard let v = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            SDLog("failed to get session view")

            return
        }
        
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        SDLog("deleting session \(v.sessionID) (\(v.sessionName))")
        
        self.sdk.removeSession(v.sessionID, completionQueue: DispatchQueue.main, success: {
            self.errorField.stringValue = ""
            self.readSyncSessions(self)
        }, failure: { (error) in
            SDLog("failed to delete session")
            let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
                
            self.errorField.textColor = fadedRed
                
            self.errorField.stringValue = error.message
            
            SDErrorHandlerReport(error)
            
            self.spinner.stopAnimation(self)
        })
    }

    
}
