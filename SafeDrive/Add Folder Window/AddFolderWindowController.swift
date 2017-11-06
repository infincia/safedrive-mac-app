
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

protocol AddFolderDelegate: class {
    func add(_ folderName: String, folderPath: URL, encrypted: Bool, success: @escaping SDKAddSyncFolderSuccess, failure: @escaping SDKFailure)
}


extension AddFolderWindowController: NSOpenSavePanelDelegate {
    func panel(_ sender: Any, validate url: URL) throws {
        let fileManager: FileManager = FileManager.default
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFile(atPath: url.path) {
            let message = NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")
            SDLogWarn(message)
            let error = SDError(message: message, kind: .filePermissionDenied)
            throw error
        }
    }
}

class AddFolderWindowController: NSWindowController {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!
    @IBOutlet fileprivate weak var source: NSPathControl!
    @IBOutlet fileprivate weak var changeSource: NSButton!
    @IBOutlet fileprivate weak var nameField: NSTextField!

    @IBOutlet fileprivate weak var encryptedBox: NSButton!

    weak var addFolderDelegate: AddFolderDelegate?
    
    convenience init() {
        self.init(windowNibName: NSNib.Name("AddFolderWindow"))
    }
    
    
    convenience init?(delegate: AddFolderDelegate) {
        self.init(windowNibName: NSNib.Name("AddFolderWindow"))

        self.addFolderDelegate = delegate
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.spinner.stopAnimation(self)
        
        let desktop = NSString(string: "~/Desktop").expandingTildeInPath
        
        let url = URL(fileURLWithPath: desktop, isDirectory: true)
        
        let name = url.lastPathComponent.lowercased()
            
        self.source.url = url
            
        self.nameField.stringValue = name
        
    }
    
    @IBAction func cancel(sender: AnyObject?) {
        guard let window = self.window else {
            SDLogError("API contract invalid: window not found in AddFolderWindowController")
            return
        }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.close()
        }
    }
    
    @IBAction func changeSource(sender: AnyObject?) {
        guard let window = self.window else {
            return
        }

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
        
        panel.beginSheetModal(for: window) { (result)  in
            if result == NSApplication.ModalResponse.OK {
                if let new = panel.url {
                    self.source.url = new
                    self.nameField.stringValue = new.lastPathComponent.lowercased()

                }
            }
        }
    }
    
    @IBAction func add(sender: AnyObject?) {
        guard let url = self.source.url, let encrypted = self.encryptedBox.state.rawValue.toBool() else {
            return
        }
        
        let name = self.nameField.stringValue
        
        self.spinner.startAnimation(self)
        
        self.sdk.hasConflictingFolder(folderPath: url.path, completionQueue: DispatchQueue.main, success: { (conflict) in
            
            if conflict {
                self.spinner.stopAnimation(self)
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error adding folder to your account", comment: "")
                alert.informativeText = NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.runModal()
            } else {
                self.addFolderDelegate?.add(name as String, folderPath: url as URL, encrypted: encrypted, success: { (_) in
                    self.spinner.stopAnimation(self)
                    
                    self.close()
                    
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
