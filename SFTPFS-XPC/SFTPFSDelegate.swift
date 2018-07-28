
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class SFTPFSDelegate: NSObject {
    fileprivate let controlQueue = DispatchQueue(label: "io.safedrive.SafeDrive.SFTPFS.controlQueue", attributes: [])
    
    fileprivate var sftpfs: ManagedSFTPFS?
    
    func create(_ mountpoint: String, label: String, user: String, password: String, host: String, port: UInt16) {
        ProcessInfo.processInfo.disableSuddenTermination()
        
        self.sftpfs = ManagedSFTPFS.withMountpoint(mountpoint,
                                                   label: label,
                                                   user: user,
                                                   password: password,
                                                   host: host,
                                                   port: port as NSNumber,
                                                   xpc: true)
    }
    


extension SFTPFSDelegate: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        let serviceInterface = NSXPCInterface(with: SFTPFSXPCProtocol.self)
        newConnection.exportedInterface = serviceInterface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}


extension SFTPFSDelegate: SFTPFSXPCProtocol {
    func connect(reply replyBlock: @escaping (_ success: Bool, _ message: String?, _ error_type: sftpfs_error_type) -> Void) {
        self.sftpfs?.connect({
            replyBlock(true, nil, sftpfs_error_type.init(0))
        }, error: { (message, error_type) in
            replyBlock(false, message, error_type)
        })
    }
    
    func disconnect(reply replyBlock: @escaping (_ success: Bool, _ message: String?, _ error_type: sftpfs_error_type) -> Void) {
        self.sftpfs?.disconnect({
            replyBlock(true, nil, sftpfs_error_type.init(0))
        }, error: { (message, error_type) in
            replyBlock(false, message, error_type)
        })
        ProcessInfo.processInfo.enableSuddenTermination()
    }
    
    func setIcon(_ url: URL) {
        self.sftpfs?.setIcon(url)
    }

    func useCache(reply replyBlock: @escaping (Bool)-> Void) {
        if let state = self.sftpfs?.useCache() {
            replyBlock(state)
        } else {
            replyBlock(false)
        }
    }
    
    func setUseCache(_ state: Bool) {
        self.sftpfs?.setUseCache(state)
    }
    
    func connected(reply replyBlock: @escaping (Bool)-> Void) {
        if let connected = self.sftpfs?.connected() {
            replyBlock(connected)
        } else {
            replyBlock(false)
        }
    }
    
    func connecting(reply replyBlock: @escaping (Bool)-> Void) {
        if let connecting = self.sftpfs?.connecting() {
            replyBlock(connecting)
        } else {
            replyBlock(false)
        }
    }

    func setMountpoint(_ mountpoint: String) {
        self.sftpfs?.setMountpoint(mountpoint)
    }
    
    func setSFTPFingerprints(_ fingerprints: [String]) {
        self.sftpfs?.setSFTPFingerprints(fingerprints)
    }

}
