
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable todo


import Cocoa

protocol VerifyFolderDelegate: class {
    func verified(_ folder: SDKSyncFolder, solution: VerificationSolution, success: @escaping SDKSuccess, failure: @escaping SDKFailure)
}

enum VerificationState {
    case find
    case pause
    case restore
    case remove
}

enum VerificationSolution {
    case find
    case pause
    case restore
    case remove
}

extension VerificationState : CustomStringConvertible {
    var description: String {
        switch self {
        case .find:
            return "find"
        case .pause:
            return "pause syncing"
        case .restore:
            return "restore folder"
        case .remove:
            return "remove folder"
        }
    }
}

extension VerificationState: RawRepresentable {
    typealias RawValue = Int
    
    init?(rawValue: RawValue) {
        switch rawValue {
        case 0:
            self = .find
        case 1:
            self = .pause
        case 2:
            self = .restore
        case 3:
            self = .remove
        default:
            return nil
        }
    }
    
    var rawValue: RawValue {
        switch self {
        case .find:
            return 0
        case .pause:
            return 1
        case .restore:
            return 2
        case .remove:
            return 3
        }
    }
}




class VerifyFolderWindowController: NSWindowController {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!
    @IBOutlet fileprivate weak var source: NSPathControl!
    @IBOutlet fileprivate weak var changeSource: NSButton!
    @IBOutlet fileprivate weak var resolve: NSButton!

    @IBOutlet fileprivate weak var nameField: NSTextField!

    @IBOutlet fileprivate weak var findBox: NSButton!
    @IBOutlet fileprivate weak var pauseBox: NSButton!
    @IBOutlet fileprivate weak var restoreBox: NSButton!
    @IBOutlet fileprivate weak var removeBox: NSButton!

    @IBOutlet fileprivate weak var findText: NSTextField!
    @IBOutlet fileprivate weak var pauseText: NSTextField!
    @IBOutlet fileprivate weak var restoreText: NSTextField!
    @IBOutlet fileprivate weak var removeText: NSTextField!
    
    weak var verifyFolderDelegate: VerifyFolderDelegate?
    
    fileprivate var state: VerificationState = .find
    
    var folder: SDKSyncFolder!
    
    convenience init() {
        self.init(windowNibName: NSNib.Name(rawValue: "VerifyFolderWindow"))
    }
    
    
    convenience init?(delegate: VerifyFolderDelegate, folder: SDKSyncFolder) {
        self.init(windowNibName: NSNib.Name(rawValue: "VerifyFolderWindow"))

        self.verifyFolderDelegate = delegate
        
        self.folder = folder
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.spinner.stopAnimation(self)
        
        self.source.url = self.folder.url
        
        updateWindowConfiguration()
    }
    
    @IBAction func changeState(sender: AnyObject) {
        guard let button = sender as? NSButton,
              let newState = VerificationState(rawValue: button.tag) else {
            return
        }
        self.state = newState
        
        updateWindowConfiguration()
    }
    
    fileprivate func updateWindowConfiguration() {
        self.findText.isHidden = true
        self.pauseText.isHidden = true
        self.restoreText.isHidden = true
        self.removeText.isHidden = true
        
        switch self.state {
        case .find:
            self.findText.isHidden = false
            break
        case .pause:
            self.pauseText.isHidden = false
            break
        case .restore:
            self.restoreText.isHidden = false
            break
        case .remove:
            self.removeText.isHidden = false
            break
        }
    }
    
    @IBAction func cancel(sender: AnyObject?) {
        guard let window = self.window else {
            SDLog("API contract invalid: window not found in VerifyFolderWindowController")
            return
        }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.close()
        }
    }
    
    @IBAction func changeSource(sender: AnyObject?) {
        
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
        
        // swiftlint:disable force_unwrapping
        panel.beginSheetModal(for: self.window!) { (result)  in
            if result.rawValue == NSFileHandlingPanelOKButton {
                if let new = panel.url {
                    self.source.url = new
                }
            }
        }
        // swiftlint:enable force_unwrapping

    }
    
    @IBAction func resolve(sender: AnyObject?) {
        guard let window = self.window else {
            return
        }
        self.spinner.startAnimation(self)

        
        switch self.state {
        case .find:
            let panel: NSOpenPanel = NSOpenPanel()
            panel.delegate = self
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            let panelTitle: String = NSLocalizedString("find the \(self.folder.name) folder", comment: "Title of window")
            panel.title = panelTitle
            let promptString: String = NSLocalizedString("Select", comment: "Button title")
            panel.prompt = promptString
            
            panel.beginSheetModal(for: window) { (result) in
                
                if result.rawValue == NSFileHandlingPanelOKButton {
                    guard let folderPath = panel.url?.path else {
                        self.spinner.stopAnimation(self)

                        return
                    }
                    
                    self.sdk.hasConflictingFolder(folderPath: folderPath, completionQueue: DispatchQueue.main, success: { (conflict) in
                        
                        if conflict {
                            // TODO: determine if the conflict is caused by the folder we're updating,
                            // in which case it isn't a conflict so we should allow it
                            // 
                            // the best way to handle that is to return a folder ID from the sdk conflict checker instead of
                            // a boolean
                            self.spinner.stopAnimation(self)
                            
                            let alert: NSAlert = NSAlert()
                            alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                            alert.informativeText = NSLocalizedString("Cannot select this directory, it is a parent or subdirectory of an existing sync folder", comment: "String informing the user that the selected folder is a parent or subdirectory of an existing sync folder")
                            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                            alert.runModal()
                            
                        } else {
                            self.folder.path = folderPath
                            
                            self.verifyFolderDelegate?.verified(self.folder, solution: .find, success: { 
                                self.spinner.stopAnimation(self)
                                
                                self.close()
                                
                            }, failure: { (error) in
                                SDErrorHandlerReport(error)
                                
                                self.spinner.stopAnimation(self)
                                
                                let alert: NSAlert = NSAlert()
                                alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help\n\n\(error)", comment: "")
                                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                                alert.runModal()
                            })
                        }
                    }, failure: { (error) in
                        SDErrorHandlerReport(error)
                        
                        self.spinner.stopAnimation(self)

                        let alert: NSAlert = NSAlert()
                        alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                        alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help\n\n\(error)", comment: "")
                        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                        alert.runModal()
                    })
                }
            }
        case .restore:
            self.verifyFolderDelegate?.verified(self.folder, solution: .restore, success: { 
                self.spinner.stopAnimation(self)
                
                self.close()
                
            }, failure: { (error) in
                SDErrorHandlerReport(error)
                
                self.spinner.stopAnimation(self)
                
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help\n\n\(error)", comment: "")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.runModal()
            })
        case .remove:
            self.verifyFolderDelegate?.verified(self.folder, solution: .remove, success: { 
                self.spinner.stopAnimation(self)
                
                self.close()
                
            }, failure: { (error) in
                SDErrorHandlerReport(error)
                
                self.spinner.stopAnimation(self)
                
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error removing folder from your account", comment: "")
                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help\n\n\(error)", comment: "")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.runModal()
            })
        case .pause:
            self.verifyFolderDelegate?.verified(self.folder, solution: .pause, success: { 
                self.spinner.stopAnimation(self)
                
                self.close()
                
            }, failure: { (error) in
                SDErrorHandlerReport(error)
                
                self.spinner.stopAnimation(self)
                
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error updating folder in your account", comment: "")
                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help\n\n\(error)", comment: "")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.runModal()
            })
        }
    }
}

extension VerifyFolderWindowController: NSOpenSavePanelDelegate {
    
    func panel(_ sender: Any, validate url: URL) throws {
        let fileManager: FileManager = FileManager.default
        
        // check if the candidate sync path is actually writable and readable
        if !fileManager.isWritableFile(atPath: url.path) {
            let message = NSLocalizedString("Cannot select this directory, read/write permission denied", comment: "String informing the user that they do not have permission to read/write to the selected directory")
            SDLog(message)
            let error = SDError(message: message, kind: .filePermissionDenied)
            throw error
        }
    }
}
