//
//  ServiceListenerDelegate.swift
//  SafeDrive
//
//  Created by steve on 2/25/16.
//  Copyright © 2016 Infincia LLC. All rights reserved.
//

import Foundation

class ServiceListenerDelegate : NSObject, NSXPCListenerDelegate, SDServiceXPCProtocol {
    
    var appEndpoint: NSXPCListenerEndpoint?
    
    func listener(listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        //let serviceInterface: NSXPCInterface = NSXPCInterface(SDServiceXPCProtocol)
        let serviceInterface = NSXPCInterface(withProtocol: SDServiceXPCProtocol.self)
        newConnection.exportedInterface = serviceInterface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func sendMessage(message: String, reply replyBlock: (String) -> Void) {
        replyBlock("Got message: \(message)")

    }
    
    func ping(replyBlock: (String) -> Void) {
        replyBlock("ack")

    }
    
    func protocolVersion(replyBlock: (NSNumber) -> Void) {
        replyBlock(kSDServiceXPCProtocolVersion)

    }
    
    func getAppEndpoint(replyBlock: (NSXPCListenerEndpoint) -> Void) {
        guard let endpoint = self.appEndpoint else {
            return
        }
        replyBlock(endpoint)
    }
    
    func sendAppEndpoint(endpoint: NSXPCListenerEndpoint, reply replyBlock: (Bool) -> Void) {
        self.appEndpoint = endpoint
        replyBlock(true)
    }
    
}


