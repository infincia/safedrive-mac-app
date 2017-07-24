//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

let kFinderXPCProtocolVersion: Int = 7

@objc protocol FinderXPCProtocol {
    func protocolVersion(_ replyBlock: @escaping (_ version: Int) -> Void)
    
    func didSignIn()
    func didSignOut()
    
    func applicationDidConfigureClient(_ uniqueClientID: String)
    func applicationDidConfigureUser(_ email: String)
    
    func syncEvent(_ folderID: UInt64)
    
    func mountStateMounted()
    func mountStateUnmounted()

}
