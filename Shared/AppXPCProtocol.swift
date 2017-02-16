//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

let kAppXPCProtocolVersion: Int = 6

@objc protocol AppXPCProtocol {
    func sendMessage(_ message: String, reply replyBlock: @escaping (_ reply: String) -> Void)
    func ping(_ replyBlock: @escaping (_ reply: String) -> Void)
    func protocolVersion(_ replyBlock: @escaping (_ version: Int) -> Void)
    func getMountState(_ replyBlock: @escaping (_ mounted: Bool) -> Void)

    func displayPreferencesWindow()
    func displayRestoreWindow(forURLs urls: [URL])
    func toggleMountState()

}
