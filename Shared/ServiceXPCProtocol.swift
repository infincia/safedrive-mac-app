//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

let kServiceXPCProtocolVersion: Int = 5

@objc protocol ServiceXPCProtocol {
    func sendMessage(_ message: String, reply replyBlock: @escaping (_ reply: String) -> Void)
    func ping(_ replyBlock: @escaping (_ reply: String) -> Void)
    func protocolVersion(_ replyBlock: @escaping (_ version: Int) -> Void)
}
