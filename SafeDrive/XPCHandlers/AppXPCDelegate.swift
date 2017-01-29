
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

class AppXPCDelegate: NSObject, AppXPCProtocol {
    
    func sendMessage(_ message: String, reply replyBlock: @escaping (String) -> Void) {
        
    }
    
    func ping(_ replyBlock: @escaping (String) -> Void) {
        replyBlock("ack")
    }
    
    func protocolVersion(_ replyBlock: @escaping (Int) -> Void) {
        replyBlock(kAppXPCProtocolVersion)
    }
    
    func displayPreferencesWindow() {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
    }
    
    func displayRestoreWindow(forURLs urls: [URL]) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenSyncWindow, object: nil)
    }
}
