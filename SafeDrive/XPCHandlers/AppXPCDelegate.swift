
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

class AppXPCDelegate: NSObject, SDAppXPCProtocol {
    func sendMessage(message: String, reply replyBlock: (String) -> Void) -> Void {
    
    }
    
    func ping(replyBlock: (String) -> Void) {
        replyBlock("ack")
    }
    
    func protocolVersion(replyBlock: (NSNumber) -> Void) -> Void {
        replyBlock(kSDAppXPCProtocolVersion)
    }
    
    func displayPreferencesWindow() {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenPreferencesWindow, object: nil)
    }
    
    func displayRestoreWindowForURLs(urls: [AnyObject]) {
        NSNotificationCenter.defaultCenter().postNotificationName(SDApplicationShouldOpenSyncWindow, object: nil)
    }
}