
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

class AppXPCDelegate: NSObject, SDAppXPCProtocol {

    func sendMessage(_ message: String, reply replyBlock: @escaping (String) -> Void) -> Void {

    }

    func ping(_ replyBlock: @escaping (String) -> Void) {
        replyBlock("ack")
    }

    func protocolVersion(_ replyBlock: @escaping (NSNumber) -> Void) -> Void {
        replyBlock(NSNumber(integerLiteral: kSDAppXPCProtocolVersion))
    }

    func displayPreferencesWindow() {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
    }

    func displayRestoreWindow(forURLs urls: [Any]) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenSyncWindow, object: nil)
    }
}
