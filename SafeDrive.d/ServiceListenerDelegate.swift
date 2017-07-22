
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class ServiceListenerDelegate: NSObject, NSXPCListenerDelegate, ServiceXPCProtocol {
    func mountStateMounted() {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.mountStateMounted()
            }
        }
    }
    
    func mountStateUnmounted() {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.mountStateUnmounted()
            }
        }
    }

    func didSignIn() {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.didSignIn()
            }
        }
    }
    
    func didSignOut() {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.didSignOut()
            }
        }
    }


    func syncEvent(_ folderID: UInt64) {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.syncEvent(folderID)
            }
        }
    }

    func applicationDidConfigureClient(_ uniqueClientID: String) {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.applicationDidConfigureClient(uniqueClientID)
            }
        }
    }

    func applicationDidConfigureUser(_ email: String) {
        finderConnectionsQueue.sync {
            for finder in self.finderConnections {
                let proxy = finder.remoteObjectProxyWithErrorHandler({ (error) in
                    print("Connecting to service failed: \(error.localizedDescription)")
                }) as! FinderXPCProtocol
                
                proxy.applicationDidConfigureUser(email)
            }
        }
    }

    
    var appEndpoint: NSXPCListenerEndpoint?
    var finderConnections = [NSXPCConnection]()
    fileprivate let finderConnectionsQueue = DispatchQueue(label: "io.safedrive.SafeDrive.Service.finderconnectionsqueue", attributes: [])


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
    
    func protocolVersion(_ replyBlock: @escaping (Int) -> Void) {
        replyBlock(kServiceXPCProtocolVersion)
        
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
    
    func addFinderConnection(_ endpoint: NSXPCListenerEndpoint, reply replyBlock: @escaping (_ success: Bool) -> Void) {
        
        let newConnection: NSXPCConnection = NSXPCConnection(listenerEndpoint: endpoint)
        
        let finderInterface: NSXPCInterface = NSXPCInterface(with: FinderXPCProtocol.self)
        
        newConnection.remoteObjectInterface = finderInterface
        
        finderConnectionsQueue.sync {
            self.finderConnections.append(newConnection)
        }
        
        newConnection.interruptionHandler = {() -> Void in
            self.finderConnectionsQueue.async {
                print("Finder connection interrupted")
            }
        }
        newConnection.invalidationHandler = {() -> Void in
            self.finderConnectionsQueue.async {
                print("Finder connection invalidated")

                if let index = self.finderConnections.index(of: newConnection) {
                    self.finderConnections.remove(at: index)
                }
            }
        }
        newConnection.resume()
        
        replyBlock(true)
    }
}
