
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class ServiceListenerDelegate: NSObject, NSXPCListenerDelegate, ServiceXPCProtocol {
    
    var appEndpoint: NSXPCListenerEndpoint?
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        let serviceInterface = NSXPCInterface(with: ServiceXPCProtocol.self)
        newConnection.exportedInterface = serviceInterface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func sendMessage(_ message: String, reply replyBlock: @escaping (String) -> Void) {
        replyBlock("Got message: \(message)")
        
    }
    
    func ping(_ replyBlock: @escaping (String) -> Void) {
        replyBlock("ack")
        
    }
    
    func protocolVersion(_ replyBlock: @escaping (NSNumber) -> Void) {
        replyBlock(NSNumber(integerLiteral: kServiceXPCProtocolVersion))
        
    }
    
    func getAppEndpoint(_ replyBlock: @escaping (NSXPCListenerEndpoint) -> Void) {
        guard let endpoint = self.appEndpoint else {
            return
        }
        replyBlock(endpoint)
    }
    
    func sendAppEndpoint(_ endpoint: NSXPCListenerEndpoint, reply replyBlock: @escaping (Bool) -> Void) {
        self.appEndpoint = endpoint
        replyBlock(true)
    }
    
}
