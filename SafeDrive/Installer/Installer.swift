
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

protocol InstallerDelegate {
    func needsDependencies()
    func didValidateDependencies()
}

class Installer {

    var delegate: InstallerDelegate
    
    var needsUpdate: Bool = false
    
    private var promptedForInstall = false
    
    init(delegate: InstallerDelegate) {
        self.delegate = delegate
    }

    func checkRequirements() {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
            while !self.isOSXFUSEInstalled() {
                if !self.promptedForInstall {
                    self.promptedForInstall = true
                    dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                        self.delegate.needsDependencies()
                    })
                }
                NSThread.sleepForTimeInterval(1)
            }
            self.deployService()
            dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                self.delegate.didValidateDependencies()
            })
        })
    }
    
    func deployService() {
        let fileManager: NSFileManager = NSFileManager.defaultManager()

        let libraryURL = try! fileManager.URLForDirectory(.LibraryDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)

        let launchAgentsURL = libraryURL.URLByAppendingPathComponent("LaunchAgents", isDirectory: true)

        let applicationSupportURL = try! fileManager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)

        let safeDriveApplicationSupportURL = applicationSupportURL.URLByAppendingPathComponent("SafeDrive", isDirectory: true)

        let serviceDestinationURL = safeDriveApplicationSupportURL!.URLByAppendingPathComponent("SafeDriveService.app", isDirectory: true)

        let serviceSourceURL = NSBundle.mainBundle().bundleURL.URLByAppendingPathComponent("Contents/PlugIns/SafeDriveService.app", isDirectory: true)!

        // copy launch agent to ~/Library/LaunchAgents/
        let launchAgentDestinationURL = launchAgentsURL!.URLByAppendingPathComponent("io.safedrive.SafeDrive.Service.plist", isDirectory: false)!
        let launchAgentSourceURL: NSURL = NSBundle.mainBundle().URLForResource("io.safedrive.SafeDrive.Service", withExtension: "plist")!
        if NSFileManager.defaultManager().fileExistsAtPath(launchAgentDestinationURL.path!) {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(launchAgentDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old launch agent: \(error)")
                SDErrorHandlerReport(error)
            }
        }
        do {
            try fileManager.copyItemAtURL(launchAgentSourceURL, toURL: launchAgentDestinationURL)
        } catch let error as NSError {
            SDLog("Error copying launch agent: \(error)")
            SDErrorHandlerReport(error)
        }

        // copy background service to ~/Library/Application Support/SafeDrive/
        do {
            try fileManager.createDirectoryAtURL(safeDriveApplicationSupportURL!, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            SDLog("Error creating support directory: \(error)")
            SDErrorHandlerReport(error)
        }

        if fileManager.fileExistsAtPath(serviceDestinationURL!.path!) {
            do {
                try fileManager.removeItemAtURL(serviceDestinationURL!)
            } catch let error as NSError {
                SDLog("Error removing old service: \(error)")
                SDErrorHandlerReport(error)
            }
        }
        do {
            try fileManager.copyItemAtURL(serviceSourceURL, toURL: serviceDestinationURL!)
        } catch let error as NSError {
            SDLog("Error copying service: \(error)")
            SDErrorHandlerReport(error)
        }

    }

    func installOSXFUSE() {
        let osxfuseURL = NSBundle.mainBundle().URLForResource("Install OSXFUSE 2.8", withExtension: "pkg", subdirectory: nil)
        let privilegedTask = STPrivilegedTask()
        privilegedTask.setLaunchPath("/usr/sbin/installer")
        privilegedTask.setArguments(["-store", "-pkg", (osxfuseURL?.path)!, "-target", "/"])
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
        let pipe: NSPipe = NSPipe()
        let task: NSTask = NSTask()
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
