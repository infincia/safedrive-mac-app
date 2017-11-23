
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

protocol RestoreSelectionDelegate: class {
    func selectedSession(_ sessionName: String, folderID: UInt64, destination: URL, session: SDKSyncSession?)
}

extension RestoreSelectionWindowController: NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 else {
            return nil
        }
        
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "RestoreSelectionCellView"), owner: self) as! RestoreSelectionTableCellView
        
        let session = self.sessions[row]
        
        view.size.stringValue = ByteCountFormatter.string(fromByteCount: Int64(session.size), countStyle: .file)
        
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short
        view.date.stringValue = dateFormatter.string(from: session.date)
        
        view.session = session
        
        return view
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.sessions.count
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int {
        return 1
    }
}

extension RestoreSelectionWindowController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let sessionIndex = restoreSelectionList.selectedRow
        
        guard sessionIndex >= 0 else {
            return
        }
        
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
            let message = NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")
            SDLogWarn("RestoreSelectionWindowController", message)
            let error = SDError(message: message, kind: .filePermissionDenied)
            throw error
        }
        
        // check that enough space is available in the selected location
        let sessionIndex = self.restoreSelectionList.selectedRow
        
        guard sessionIndex != -1, let sessionView = restoreSelectionList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? RestoreSelectionTableCellView else {
            let message = NSLocalizedString("Please select a session to restore so that SafeDrive can ensure there is enough free space available", comment: "String informing the user that a session must be selected so that we can check for available space")
            SDLogWarn("RestoreSelectionWindowController", message)
            let error = SDError(message: message, kind: .folderConflict)
            throw error
        }
        
    
        if let attr = try? fileManager.attributesOfFileSystem(forPath: url.path),
           let freeSpace = attr[FileAttributeKey.systemFreeSize] as? UInt64 {
            
            if sessionView.session.size > freeSpace {
                let message = NSLocalizedString("The selected location does not have enough free space to restore the session", comment: "String informing the user that the restore folder location doesn't have enough free space")
                SDLogWarn("RestoreSelectionWindowController", message)
                let error = SDError(message: message, kind: .folderConflict)
                throw error
            }
        
        }
    }
}

class RestoreSelectionWindowController: NSWindowController {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK

    fileprivate var sessions = [SDKSyncSession]()

    fileprivate var uniqueClientID: String!
    fileprivate var folder: SDKSyncFolder!
    
    @IBOutlet fileprivate weak var restoreSelectionList: NSTableView!
    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!
    @IBOutlet fileprivate weak var errorField: NSTextField!
    @IBOutlet fileprivate weak var destination: NSPathControl!
    @IBOutlet fileprivate weak var destinationButton: NSButton!

    weak var restoreSelectionDelegate: RestoreSelectionDelegate?
    
    convenience init() {
        self.init(windowNibName: NSNib.Name(rawValue: "RestoreSelectionWindow"))
    }
    
    
    convenience init?(delegate: RestoreSelectionDelegate, uniqueClientID: String, folder: SDKSyncFolder) {
        self.init(windowNibName: NSNib.Name(rawValue: "RestoreSelectionWindow"))

        self.restoreSelectionDelegate = delegate
        
        self.uniqueClientID = uniqueClientID
        
        self.folder = folder
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.spinner.stopAnimation(self)
        self.errorField.stringValue = ""
        
        if let url = folder.url {
            self.destination.url = url
        } else {
            SDLogWarn("RestoreSelectionWindowController", "failed to set default destination url")
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
            SDLogError("RestoreSelectionWindowController", "API contract invalid: window not found")
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
            if result.rawValue == NSFileHandlingPanelOKButton {
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
            SDLogError("RestoreSelectionWindowController", "failed to get session view")

            return
        }
        
        guard let destination = self.destination.url else {
            SDLogError("RestoreSelectionWindowController", "no destination selected")
            return
        }
        
        let sessionName = v.session.name
        
        self.sdk.hasConflictingFolder(folderPath: destination.path, completionQueue: DispatchQueue.main, success: { (conflict) in
            
            if conflict {
                self.spinner.stopAnimation(self)

                let alert: NSAlert = NSAlert()
                alert.informativeText = NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.runModal()
            } else {
                self.spinner.stopAnimation(self)

                self.restoreSelectionDelegate?.selectedSession(sessionName, folderID: self.folder.id, destination: destination, session: v.session)
                
                self.close()
            }
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
    
    @IBAction func readSyncSessions(_ sender: AnyObject) {
        guard let _ = self.uniqueClientID else {
            return
        }
        
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        self.sdk.getSessions(completionQueue: DispatchQueue.main, success: { (sessions: [SDKSyncSession]) in
            self.errorField.stringValue = ""
            
            // swiftlint:enable force_try
            self.sessions.removeAll()
            for session in sessions {
                if session.folder_id == self.folder.id {
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
            SDLogError("RestoreSelectionWindowController", "failed to get session view")

            return
        }
        
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        
        self.sdk.removeSession(v.session.session_id, completionQueue: DispatchQueue.main, success: {
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
