
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class SFTPFSDelegate: NSObject {
    fileprivate let controlQueue = DispatchQueue(label: "io.safedrive.SafeDrive.SFTPFS.controlQueue", attributes: [])
    
    fileprivate var sftpfs: ManagedSFTPFS?
    
    fileprivate static var loggerCallback: ((String, String, Int32) -> Void)?
    fileprivate static var errorCallback: ((String, Int32) -> Void)?

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
    
    static func log(_ message: String, _ module: String, _ level: Int32) {
        if let cb = SFTPFSDelegate.loggerCallback {
            cb(message, module, level)
        }
    }
    
    static func error(_ message: String, _ error_type: Int32) {
        if let cb = SFTPFSDelegate.errorCallback {
            cb(message, error_type)
        }
    }
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
    
    func killMount() {
        exit(1)
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

    func setErrorHandler( _ callback: @escaping (String, Int32) -> Void) {
        SFTPFSDelegate.errorCallback = callback

        set_sftpfs_error_handler { (cmsg, error_type) in
            guard let cmessage = cmsg else {
                    return
            }
            
            let message = String(cString: cmessage)
            
            SFTPFSDelegate.error(message, error_type)
        }
    }
    func setLogger(_ callback: @escaping (String, String, Int32) -> Void) {
        SFTPFSDelegate.loggerCallback = callback
        
        set_sftpfs_logger { (clog, cmod, level) in
            guard let cmessage = clog,
                let cmodule = cmod else {
                    return
            }
            
            let message = String(cString: cmessage)
            let module = String(cString: cmodule)
            
            SFTPFSDelegate.log(message, module, level)

        }
    }
}
