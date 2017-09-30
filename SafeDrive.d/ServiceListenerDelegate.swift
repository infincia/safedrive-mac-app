
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class ServiceListenerDelegate: NSObject {
    fileprivate func getSDFSVersion() -> String? {
        guard let sdfs = Bundle.init(path: "/Library/Filesystems/sdfs.fs"),
            let version = sdfs.infoDictionary?["CFBundleVersion"] as? String else {
                return nil
        }
        return version
    }
    
    fileprivate func getServiceVersion() -> String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                return nil
        }
        return version
    }
    
    fileprivate func unloadKext() throws {
        let pipe: Pipe = Pipe()
        let task: Process = Process()
        task.launchPath = "/sbin/kextunload"
        task.arguments = ["-b", "io.safedrive.sdfs"]
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw NSError(domain: "io.safedrive.SafeDrive.d", code: 0x0001, userInfo: [NSLocalizedDescriptionKey: "Unloading sdfs.kext failed"])
        }
    }
    
    fileprivate func loadNewKext() throws {
        let pipe: Pipe = Pipe()
        let task: Process = Process()
        task.launchPath = "/Library/Filesystems/sdfs.fs/Contents/Resources/load_sdfs"
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw NSError(domain: "io.safedrive.SafeDrive.d", code: 0x0002, userInfo: [NSLocalizedDescriptionKey: "Loading sdfs.kext failed"])
        }
    }
    
    fileprivate func fixSDFSPermissions() throws {
        
        let kextRoot = "/Library/Filesystems/sdfs.fs"
        
        let p = Process()
        p.launchPath = "/bin/chmod"
        p.arguments = ["-R", "755", kextRoot]
        p.launch()
        p.waitUntilExit()
        
        if p.terminationStatus != 0 {
            throw NSError(domain: "io.safedrive.SafeDrive.d", code: 0x0003, userInfo: [NSLocalizedDescriptionKey: "SDFS kext permissions could not be set"])
        }
        
        let p2 = Process()
        p2.launchPath = "/usr/sbin/chown"
        p2.arguments = ["-R", "root:wheel", kextRoot]
        p2.launch()
        p2.waitUntilExit()
        
        if p2.terminationStatus != 0 {
            throw NSError(domain: "io.safedrive.SafeDrive.d", code: 0x0004, userInfo: [NSLocalizedDescriptionKey: "SDFS kext owner could not be set"])
        }
        
        let p3 = Process()
        p3.launchPath = "/bin/chmod"
        p3.arguments = ["+s", "\(kextRoot)/Contents/Resources/load_sdfs"]
        p3.launch()
        p3.waitUntilExit()
        
        if p3.terminationStatus != 0 {
            throw NSError(domain: "io.safedrive.SafeDrive.d", code: 0x0005, userInfo: [NSLocalizedDescriptionKey: "SDFS kext loader binary could not be setuid"])
        }
    }
}

extension ServiceListenerDelegate: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        let serviceInterface = NSXPCInterface(with: ServiceXPCProtocol.self)
        newConnection.exportedInterface = serviceInterface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}

extension ServiceListenerDelegate: ServiceXPCProtocol {
    func sendMessage(_ message: String, reply replyBlock: @escaping (String) -> Void) {
        replyBlock("Got message: \(message)")
        
    }
    
    func ping(_ replyBlock: @escaping (String) -> Void) {
        replyBlock("ack")
        
    }
    
    func protocolVersion(_ replyBlock: @escaping (Int) -> Void) {
        replyBlock(kServiceXPCProtocolVersion)
    }
    
    func updateSDFS(_ source: String, _ replyBlock: @escaping (_ state: Bool, _ status: String) -> Void) {
        do {
            try unloadKext()
        } catch {
            // ignore, not fatal
        }
        
        do {
            try FileManager.default.removeItem(atPath: "/Library/Filesystems/sdfs.fs")
        } catch {
            // ignore, not fatal
        }
        
        do {
            try FileManager.default.copyItem(atPath: source, toPath: "/Library/Filesystems/sdfs.fs")
        } catch let error as NSError {
            replyBlock(false, "\(error.localizedDescription)")
            return
        }
        
        guard let version = getSDFSVersion() else {
            replyBlock(false, "Could not determine SDFS version")
            return
        }
        
        do {
            try fixSDFSPermissions()
        } catch let e as NSError {
            replyBlock(false, "SDFS kext permissions could not be fixed: \(e.localizedDescription)")
            return
        }
        
        replyBlock(true, version)
    }
    
    func loadKext(_ replyBlock: @escaping (_ state: Bool, _ status: String) -> Void) {
        do {
            try loadNewKext()
            replyBlock(true, "")
        } catch let e as NSError {
            replyBlock(false, "\(e.localizedDescription)")
        }
    }

    func currentSDFSVersion(_ replyBlock: @escaping (_ state: Bool, _ status: String) -> Void) {
        guard let version = getSDFSVersion() else {
            replyBlock(false, "N/A")
            return
        }
        replyBlock(true, version)
    }
    
    func currentServiceVersion(_ replyBlock: @escaping (_ version: String?) -> Void) {
        guard let version = getServiceVersion() else {
            replyBlock(nil)
            return
        }
        replyBlock(version)
    }
}
