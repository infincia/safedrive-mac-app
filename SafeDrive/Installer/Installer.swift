
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Foundation

protocol InstallerDelegate {
    func needsDependencies()
    func didValidateDependencies()
}

class Installer {
    
    var delegate: InstallerDelegate
    
    var needsUpdate: Bool = false
    
    fileprivate var promptedForInstall = false
    
    init(delegate: InstallerDelegate) {
        self.delegate = delegate
    }
    
    func checkRequirements() {
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            while !self.isOSXFUSEInstalled() {
                if !self.promptedForInstall {
                    self.promptedForInstall = true
                    DispatchQueue.main.sync(execute: {() -> Void in
                        self.delegate.needsDependencies()
                    })
                }
                Thread.sleep(forTimeInterval: 1)
            }
            self.deployService()
            DispatchQueue.main.sync(execute: {() -> Void in
                self.delegate.didValidateDependencies()
            })
        })
    }
    
    func deployService() {
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
                SDErrorHandlerReport(error)
            }
        }
        do {
            try fileManager.copyItem(at: launchAgentSourceURL, to: launchAgentDestinationURL)
        } catch let error as NSError {
            SDLog("Error copying launch agent: \(error)")
            SDErrorHandlerReport(error)
        }
        
        // copy background service to ~/Library/Application Support/SafeDrive/
        do {
            try fileManager.createDirectory(at: safeDriveApplicationSupportURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            SDLog("Error creating support directory: \(error)")
            SDErrorHandlerReport(error)
        }
        
        if fileManager.fileExists(atPath: serviceDestinationURL.path) {
            do {
                try fileManager.removeItem(at: serviceDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old service: \(error)")
                SDErrorHandlerReport(error)
            }
        }
        do {
            try fileManager.copyItem(at: serviceSourceURL, to: serviceDestinationURL)
        } catch let error as NSError {
            SDLog("Error copying service: \(error)")
            SDErrorHandlerReport(error)
        }
        
    }
    
    func installOSXFUSE() {
        let osxfuseURL = Bundle.main.url(forResource: "FUSE for macOS 3.5.4", withExtension: "pkg", subdirectory: nil)
        let privilegedTask = STPrivilegedTask()
        privilegedTask.setLaunchPath("/usr/sbin/installer")
        privilegedTask.setArguments(["-pkg", (osxfuseURL?.path)!, "-target", "/"])
        let err = privilegedTask.launch()
        
        if (err != errAuthorizationSuccess) {
            if (err == errAuthorizationCanceled) {
                SDLog("User cancelled installer")
            } else {
                SDLog("Installer could not be launched")
            }
        } else {
            SDLog("Installer launched")
        }
    }
    
    func isOSXFUSEInstalled() -> Bool {
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
}
