
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
            dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                self.delegate.didValidateDependencies()
            })
        })
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
