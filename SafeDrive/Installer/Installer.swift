
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Foundation

protocol InstallerDelegate: class {
    func needsDependencies()
    func didValidateDependencies()
    func didFail(error: NSError)
}

class Installer: NSObject {
    
    weak var delegate: InstallerDelegate?
    
    var needsUpdate: Bool = false
    
    fileprivate var prompted = false
    
        
    fileprivate var isOSXFUSEInstalled: Bool {
        let pipe: Pipe = Pipe()
        let task: Process = Process()
        task.launchPath = "/usr/sbin/pkgutil"
        task.arguments = ["--pkgs=com.github.osxfuse.pkg.Core"]
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            return true
        }
        return false
    }
    
    var dependenciesValidated: Bool {
        return self.isOSXFUSEInstalled
    }
    
    init(delegate: InstallerDelegate?) {
        self.delegate = delegate
    }
    
    func check() {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            while !self.dependenciesValidated {
                if !self.prompted {
                    self.prompted = true
                    DispatchQueue.main.sync {
                        self.delegate?.needsDependencies()
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }
            DispatchQueue.main.sync {
                self.delegate?.didValidateDependencies()
            }
        }
    }
    
    func installDependencies() {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            do {
                try self.installOSXFUSE()
                try self.deployService()
                //try self.installCLI()
            } catch let error as NSError {
                DispatchQueue.main.async {
                    self.delegate?.didFail(error: error)
                }
            }
        }
        
    }
    
    func deployService() throws {
        let fileManager: FileManager = FileManager.default
        // swiftlint:disable force_try

        let libraryURL = try! fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let launchAgentsURL = libraryURL.appendingPathComponent("LaunchAgents", isDirectory: true)
        
        let applicationSupportURL = try! fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        // swiftlint:enable force_try

        let safeDriveApplicationSupportURL = applicationSupportURL.appendingPathComponent("SafeDrive", isDirectory: true)
        
        let serviceDestinationURL = safeDriveApplicationSupportURL.appendingPathComponent("SafeDriveService.app", isDirectory: true)
        
        let serviceSourceURL = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/SafeDriveService.app", isDirectory: true)
        
        // copy launch agent to ~/Library/LaunchAgents/
        let launchAgentDestinationURL = launchAgentsURL.appendingPathComponent("io.safedrive.SafeDrive.Service.plist", isDirectory: false)
        let launchAgentSourceURL: URL = Bundle.main.url(forResource: "io.safedrive.SafeDrive.Service", withExtension: "plist")!
        if FileManager.default.fileExists(atPath: launchAgentDestinationURL.path) {
            do {
                try FileManager.default.removeItem(at: launchAgentDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old launch agent: \(error)")
            }
        }
        do {
            try fileManager.copyItem(at: launchAgentSourceURL, to: launchAgentDestinationURL)
        } catch let error as NSError {
            SDLog("Error copying launch agent: \(error)")
            throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.serviceDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "Error copying launch agent: \(error)"])
        }
        
        // copy background service to ~/Library/Application Support/SafeDrive/
        do {
            try fileManager.createDirectory(at: safeDriveApplicationSupportURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            SDLog("Error creating support directory: \(error)")
            throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.serviceDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "Error creating support directory: \(error)"])
        }
        
        if fileManager.fileExists(atPath: serviceDestinationURL.path) {
            do {
                try fileManager.removeItem(at: serviceDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old service: \(error)")
            }
        }
        do {
            try fileManager.copyItem(at: serviceSourceURL, to: serviceDestinationURL)
        } catch let error as NSError {
            SDLog("Error copying service: \(error)")
            throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.serviceDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "Error copying service: \(error)"])
        }
        
    }
    
    func installOSXFUSE() throws {
        let osxfuseURL = Bundle.main.url(forResource: "FUSE for macOS 3.5.4", withExtension: "pkg", subdirectory: nil)
        let privilegedTask = STPrivilegedTask()
        privilegedTask.setLaunchPath("/usr/sbin/installer")
        privilegedTask.setArguments(["-pkg", (osxfuseURL?.path)!, "-target", "/"])
        let err = privilegedTask.launch()
        
        if err != errAuthorizationSuccess {
            if err == errAuthorizationCanceled {
                SDLog("User cancelled installer")
                throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.fuseDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "FUSE installation cancelled by user"])
            } else {
                SDLog("Installer could not be launched")
                throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.fuseDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "Installer could not be launched"])
            }
        } else {
            SDLog("Installer launched")
        }
    }
    
    func installCLI() throws {
        let cli = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/safedrive", isDirectory: false)
        let destination = URL(string: "file://usr/local/bin/safedrive")
        
        let fileManager: FileManager = FileManager.default
        if FileManager.default.fileExists(atPath: cli.path) {
            do {
                try FileManager.default.removeItem(at: cli)
            } catch let error as NSError {
                SDLog("Error removing old CLI app: \(error)")
                throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.cliDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "Error removing old CLI app: \(error)"])
            }
        }
        do {
            try fileManager.copyItem(at: cli, to: destination!)
        } catch let error as NSError {
            SDLog("Error copying CLI app: \(error)")
            throw NSError(domain: SDErrorInstallationDomain, code: SDInstallationError.fuseDeployment.rawValue, userInfo: [NSLocalizedDescriptionKey: "Error copying CLI app: \(error)"])
        }
    }
}
