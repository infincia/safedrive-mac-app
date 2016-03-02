
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class Installer {
    var promptedForOSXFUSE = false
    
    func dependencyCheck() {
        // check for OSXFUSE first
        while !isOSXFUSEInstalled() {
            if !promptedForOSXFUSE {
                promptedForOSXFUSE = true
                installOSXFUSE()
            }
            NSThread.sleepForTimeInterval(1)
        }
    }
    
    func installOSXFUSE() {
        let osxfuseURL = NSBundle.mainBundle().URLForResource("osxfuse", withExtension: "pkg", subdirectory: nil)
        NSWorkspace.sharedWorkspace().openURL(osxfuseURL!)
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

