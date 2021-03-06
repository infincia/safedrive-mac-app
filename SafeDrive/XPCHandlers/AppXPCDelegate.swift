
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
    
    func getMountState(_ replyBlock: @escaping (_ mounted: Bool) -> Void) {
        replyBlock(MountController.shared.mounted)
    }

    
    func displayPreferencesWindow() {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenPreferencesWindow, object: nil)
    }
    
    func displayRestoreWindow(forURLs urls: [URL]) {
        NotificationCenter.default.post(name: Notification.Name.applicationShouldOpenSyncWindow, object: nil)
    }
    
    func toggleMountState() {
        print("finder extension requesting mount state change")
        if MountController.shared.mounted {
            let unmountEvent = UnmountEvent(askForOpenApps: true, force: false)
            NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: unmountEvent)
        } else {
            NotificationCenter.default.post(name: Notification.Name.volumeShouldMount, object: nil)
        }
    }
    
    func getUniqueClientID(_ replyBlock: @escaping (_ uniqueClientID: String?) -> Void) {
        replyBlock(AccountController.sharedAccountController.uniqueClientID)
    }
}
