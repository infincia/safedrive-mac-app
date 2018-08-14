//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

let kAppXPCProtocolVersion: Int = 7

@objc protocol AppXPCProtocol {
    func protocolVersion(_ replyBlock: @escaping (_ version: Int) -> Void)
    func getMountState(_ replyBlock: @escaping (_ mounted: Bool) -> Void)

    func displayPreferencesWindow()
    func displayRestoreWindow(forURLs urls: [URL])
    func toggleMountState()
    
    func getUniqueClientID(_ replyBlock: @escaping (_ uniqueClientID: String?) -> Void)


}
