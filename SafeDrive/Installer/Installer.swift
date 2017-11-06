
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Foundation
import SystemConfiguration


protocol InstallerDelegate: class {
    func needsDependencies()
    func didValidateDependencies()
    func didFail(error: Error)
}

class Installer: NSObject {
    
    weak var delegate: InstallerDelegate?
    
    fileprivate var prompted = false
    
    fileprivate var isDirectoryOK: Bool {
        let usrlocalbin = URL(fileURLWithPath: "/usr/local/bin")

        var isDirectory: ObjCBool = false
        let directoryExists = FileManager.default.fileExists(atPath: usrlocalbin.path, isDirectory: &isDirectory) && isDirectory.boolValue == true
        
        // check if the directory is actually writable and readable
        let directoryIsWritable = FileManager.default.isWritableFile(atPath: usrlocalbin.path)
        return directoryExists && directoryIsWritable
    }
    
    fileprivate var isCLIAppInstalled: Bool {
        let destination = URL(fileURLWithPath: "/usr/local/bin/safedrive")
        
        if FileManager.default.fileExists(atPath: destination.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
                let type = attributes[FileAttributeKey.type] as! FileAttributeType
                let isSymlink = (type == FileAttributeType.typeSymbolicLink)
                return isSymlink
            } catch {
                return false
            }
        }

        return false
    }
    
    fileprivate var isCLIAppCurrent: Bool {
        let pipe: Pipe = Pipe()
        let task: Process = Process()
        task.launchPath = "/usr/local/bin/safedrive"
        task.arguments = ["version"]
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let cs = CharacterSet(charactersIn: "\n ")
            if let output = String(data: data, encoding: .utf8) {
                let version = output.trimmingCharacters(in: cs)
                return version == SafeDriveSDK.sddk_version
            }
        }
        return false
    }
    
    var dependenciesValidated: Bool {
        return self.isCLIAppInstalled && self.isDirectoryOK
    }
    
    init(delegate: InstallerDelegate?) {
        self.delegate = delegate
    }
    
    func check() {
        background {
            while !self.dependenciesValidated {
                if !self.prompted {
                    self.prompted = true
                    DispatchQueue.main.async {
                        self.delegate?.needsDependencies()
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }
            DispatchQueue.main.async {
                self.delegate?.didValidateDependencies()
            }
        }
    }
    
    func installDependencies() {
        background {
            do {
                if !self.isDirectoryOK {
                    try self.setupDirectories()
                }
                if !self.isCLIAppInstalled {
                    try self.installCLI()
                }
            } catch let error as NSError {
                DispatchQueue.main.async {
                    self.delegate?.didFail(error: error)
                }
            }
        }
    }
    
    func installCLI() throws {
        
        guard let cli = Bundle.main.url(forAuxiliaryExecutable: "io.safedrive.SafeDrive.cli") else {
            let message = NSLocalizedString("CLI app missing, contact SafeDrive support", comment: "")
            SDLogError(message)
            let error = SDError(message: message, kind: .cliMissing)
            throw error
        }
        
        SDLogDebug("CLI location: \(cli.path)")

        let usrlocalbin = URL(fileURLWithPath: "/usr/local/bin")

        let destination = usrlocalbin.appendingPathComponent("safedrive")
        
        let fileManager: FileManager = FileManager.default
        
        do {
            try FileManager.default.removeItem(at: destination)
        } catch let error as NSError {
            SDLogError("Error removing old CLI app: \(error)")
        }
        
        do {
            try fileManager.createSymbolicLink(at: destination, withDestinationURL: cli)
        } catch let error as NSError {
            let message = NSLocalizedString("Error installing CLI app symlink: \(error)", comment: "")
            SDLogError(message)
            let error = SDError(message: message, kind: .cliDeployment)
            throw error
        }
    }
    
    func setupDirectories() throws {
        
        guard let cli = Bundle.main.url(forAuxiliaryExecutable: "io.safedrive.SafeDrive.cli") else {
            let message = NSLocalizedString("CLI app missing, contact SafeDrive support", comment: "")
            SDLogError(message)
            let error = SDError(message: message, kind: .cliMissing)
            throw error
        }
                
        var uid: uid_t = 0
        var gid: gid_t = 0
        
        guard let cfname = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) else {
            let message = NSLocalizedString("Failed to get user information from system", comment: "")
            SDLogError(message)
            let error = SDError(message: message, kind: .setupDirectories)
            throw error
        }
        
        let name = cfname as String
        
        SDLogDebug("name = \(name), uid = \(uid), gid = \(gid)")

        let privilegedTask = STPrivilegedTask()

        privilegedTask.launchPath = cli.path
        privilegedTask.arguments = ["doctor", "--uid", String(uid), "--gid", String(gid)]
        
        let err = privilegedTask.launch()
        
        if err != errAuthorizationSuccess {
            if err == errAuthorizationCanceled {
                let message = NSLocalizedString("Directory setup cancelled by user", comment: "")
                SDLogError(message)
                let error = SDError(message: message, kind: .setupDirectories)
                throw error
            } else {
                let message = NSLocalizedString("Setup could not be completed", comment: "")
                SDLogError(message)
                let error = SDError(message: message, kind: .setupDirectories)
                throw error
            }
        } else {
            SDLogDebug("Directory setup launched")
        }
        
        privilegedTask.waitUntilExit()

        let exitCode = privilegedTask.terminationStatus
        
        if exitCode != 0 {
            let data = privilegedTask.outputFileHandle.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                SDLogError("Directory setup failed: \(output)")
                let error = SDError(message: "Directory setup failed: \(output)", kind: .setupDirectories)
                throw error
            } else {
                SDLogError("Directory setup failed")
                let error = SDError(message: "Directory setup failed", kind: .setupDirectories)
                throw error
            }
        }
    }
}
