
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class SFTPFSDelegate: NSObject, NSXPCListenerDelegate, SFTPFSXPCProtocol {
    fileprivate let controlQueue = DispatchQueue(label: "io.safedrive.SafeDrive.SFTPFS.controlQueue", attributes: [])
    
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        let serviceInterface = NSXPCInterface(with: SFTPFSXPCProtocol.self)
        newConnection.exportedInterface = serviceInterface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func create(_ mountpoint: String, label: String, user: String, password: String, host: String, port: UInt16, reply replyBlock: @escaping (Bool) -> Void) {
        
    }
    
    func connect() {
        
    }
    
    func disconnect() {
        
    }
    
    func useCache(reply replyBlock: @escaping (Bool)-> Void) {
        
    }
    
    func setUseCache(_ state: Bool) {
        
    }
    
    func connected(reply replyBlock: @escaping (Bool)-> Void) {
        
    }
    
    func connecting(reply replyBlock: @escaping (Bool)-> Void) {
        
    }

    func setMountpoint(_ mountpoint: String) {
        
    }
}
