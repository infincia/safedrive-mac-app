//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import ServiceManagement

class ServiceXPCRouter: NSObject, NSXPCListenerDelegate {
    
    private var serviceConnection: NSXPCConnection?
    private var appListener: NSXPCListener
    private var currentServiceVersion = NSDecimalNumber(string: "0")
    private weak var appXPCDelegate: AppXPCDelegate?
    
    override init() {
        
        appXPCDelegate = AppXPCDelegate()
        appListener = NSXPCListener.anonymous()
        super.init()
        
        appListener.delegate = self
        appListener.resume()
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            self.serviceReconnectionLoop()
        }
    }
    
    func createServiceConnection() -> NSXPCConnection {
        let newConnection = NSXPCConnection(machServiceName:"io.safedrive.SafeDrive.Service", options:NSXPCConnection.Options(rawValue: UInt(0)))
        
        let serviceInterface = NSXPCInterface(with: ServiceXPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        weak var weakSelf: ServiceXPCRouter? = self
        
        newConnection.interruptionHandler = {
            DispatchQueue.main.async {
                
            }
        }
        newConnection.invalidationHandler = {
            DispatchQueue.main.async {
                if let weakSelf = weakSelf {
                    weakSelf.serviceConnection = nil
                }
            }
        }
        newConnection.resume()
        return newConnection
    }
    
    func ensureServiceIsRunning() -> Bool {
        #if DEBUG
            // temporary kill/restart for background service until proper calls are implemented
            // NOTE: This should not happen in production! Background service should NOT be killed arbitrarily.
            //
            //[NSThread sleepForTimeInterval:5];
        #endif
        //CFDictionaryRef diref = SMJobCopyDictionary( kSMDomainUserLaunchd, (CFStringRef)@"io.safedrive.SafeDrive.Service");
        //NSLog(@"Job status: %@", (NSDictionary *)CFBridgingRelease(diref));
        //CFRelease(diref);
        return true
        //return
    }
    
    func serviceReconnectionLoop() {
        while true {
            //[self ensureServiceIsRunning];
            if self.serviceConnection == nil {
                
                self.serviceConnection = self.createServiceConnection()
                
                if let s = self.serviceConnection {
                    let proxy = s.remoteObjectProxyWithErrorHandler({ (_) in
                        //
                    }) as! ServiceXPCProtocol
                    
                    proxy.sendAppEndpoint(self.appListener.endpoint, reply: { (_) in
                        
                    })
                    
                }
                Thread.sleep(forTimeInterval: 1)
            }
            if let s = self.serviceConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (_) in
                    //
                }) as! ServiceXPCProtocol
                
                proxy.protocolVersion({ (version: Int!) in
                    
                    if version != kServiceXPCProtocolVersion {
                        SDLog("Service needs to be updated!!!!!")
                        if let s = self.serviceConnection {
                            s.invalidate()
                        }
                    }
                })
            }
            Thread.sleep(forTimeInterval: 5)
        }
    }
    
    
    // MARK: - App Listener Delegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        let serviceInterface = NSXPCInterface(with: AppXPCProtocol.self)
        newConnection.exportedInterface = serviceInterface
        newConnection.exportedObject = self.appXPCDelegate
        
        newConnection.resume()
        return true
        
    }
}
