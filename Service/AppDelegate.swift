//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Cocoa

import Fabric
import Crashlytics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var listenerDelegate: ServiceListenerDelegate?
    
    var CFBundleVersion = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        NSUserDefaults.standardUserDefaults().registerDefaults(["NSApplicationCrashOnExceptions": true])
        Fabric.with([Crashlytics.self])
        
        print("SafeDriveService build \(CFBundleVersion), protocol version \(kSDServiceXPCProtocolVersion) starting")
      
        let groupURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db")!
        print("Group: \(groupURL)")
        
        self.listenerDelegate = ServiceListenerDelegate()
        
        let listener: NSXPCListener = NSXPCListener(machServiceName: NSBundle.mainBundle().bundleIdentifier!)
        listener.delegate = self.listenerDelegate
        listener.resume()
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        print("SafeDriveService build \(CFBundleVersion), protocol version \(kSDServiceXPCProtocolVersion) exiting")
    }
    
}


