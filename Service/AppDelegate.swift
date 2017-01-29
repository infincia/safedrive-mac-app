
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

import Fabric
import Crashlytics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    weak var listenerDelegate: ServiceListenerDelegate?
    
    var CFBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        Fabric.with([Crashlytics.self])
        
        print("SafeDriveService build \(CFBundleVersion), protocol version \(kServiceXPCProtocolVersion) starting")
        
        self.listenerDelegate = ServiceListenerDelegate()
        
        let listener: NSXPCListener = NSXPCListener(machServiceName: Bundle.main.bundleIdentifier!)
        listener.delegate = self.listenerDelegate
        listener.resume()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("SafeDriveService build \(CFBundleVersion), protocol version \(kServiceXPCProtocolVersion) exiting")
    }
    
}
