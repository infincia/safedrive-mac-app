
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

class FinderXPCDelegate: NSObject, FinderXPCProtocol {
    
    func didSignIn() {
        NotificationCenter.default.post(name: Notification.Name.accountSignIn, object: nil)
    }
    
    func didSignOut() {
        NotificationCenter.default.post(name: Notification.Name.accountSignOut, object: nil)
    }
    
    func applicationDidConfigureClient(_ uniqueClientID: String) {
        NotificationCenter.default.post(name: Notification.Name.applicationDidConfigureClient, object: uniqueClientID)
    }
    
    func applicationDidConfigureUser(_ email: String) {
        NotificationCenter.default.post(name: Notification.Name.applicationDidConfigureUser, object: email)
    }
    
    func syncEvent(_ folderID: UInt64) {
        NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
    }
    
    func protocolVersion(_ replyBlock: @escaping (Int) -> Void) {
        replyBlock(kFinderXPCProtocolVersion)
    }
    
    func mountState(_ mounted: Bool) {
        NotificationCenter.default.post(name: Notification.Name.mountState, object: mounted)
    }
}
