
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import ServiceManagement

class ServiceManager: NSObject {
    static let sharedServiceManager = ServiceManager()
    
    static let serviceName = "G738Z89QKM.io.safedrive.IPCService"
    static let appName = "SafeDrive"
    
    fileprivate var serviceConnection: NSXPCConnection?
    fileprivate var appListener: NSXPCListener
    fileprivate var currentServiceVersion: Int?
    // swiftlint:disable weak_delegate
    // disabling lint because this isn't a delegate but an XPC exported 
    // object owned by this class
    fileprivate var appXPCDelegate: AppXPCDelegate?
    // swiftlint:enable weak_delegate

    fileprivate var updateNotificationSent = false
    
    override init() {
        
        
        appXPCDelegate = AppXPCDelegate()
        appListener = NSXPCListener.anonymous()
        
        super.init()
        
        appListener.delegate = self
        appListener.resume()
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDApplicationEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        // register SDSyncEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDSyncEventProtocol.syncEvent), name: Notification.Name.syncEvent, object: nil)
        
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
        
        background {
            self.serviceLoop()
        }
        
        background {
            self.serviceReconnectionLoop()
        }
    }
    
    func enableLoginItem(_ state: Bool) -> Bool {
        
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/IPCService.app", isDirectory: false)
        
        if LSRegisterURL(helper as CFURL, state) != noErr {
            print("Failed to LSRegisterURL \(helper)")
        }
        
        if (SMLoginItemSetEnabled((ServiceManager.serviceName as CFString), state)) {
            return true
        } else {
            print("Failed to SMLoginItemSetEnabled \(helper)")
            return false
        }
    }

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    var isServiceRunning: Bool {
        guard let _ = SMJobCopyDictionary(kSMDomainUserLaunchd, (ServiceManager.serviceName as CFString)) else {
            return false
        }
        return true
        
    }
    
    fileprivate func serviceLoop() {
        background {
            while true {
                let running: Bool = self.isServiceRunning
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.serviceStatus, object: running)
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
}

extension ServiceManager: SDSyncEventProtocol {
    func syncEvent(notification: Notification) {
        guard let folderID = notification.object as? UInt64 else {
            SDLog("API contract invalid: syncEvent in ServiceManager")
            return
        }
        
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("syncEvent connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.syncEvent(folderID)
        }
    }
}

extension ServiceManager: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in ServiceManager")
            
            return
        }
        
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("applicationDidConfigureClient connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.applicationDidConfigureClient(uniqueClientID)
        }
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let user = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in ServiceManager")
            
            return
        }
        
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("applicationDidConfigureUser connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.applicationDidConfigureUser(user.email)
        }
    }
}

extension ServiceManager: SDAccountProtocol {
    
    func didSignIn(notification: Notification) {
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("didSignIn connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.didSignIn()
        }
    }
    
    func didSignOut(notification: Notification) {
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("didSignOut connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.didSignOut()
        }
    }
    
    func didReceiveAccountDetails(notification: Notification) {
    }
    
    func didReceiveAccountStatus(notification: Notification) {
    }
    
}

extension ServiceManager: SDMountStateProtocol {
    
    func mountStateMounted(notification: Notification) {
        
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.mountStateMounted()
        }
    }
    
    func mountStateUnmounted(notification: Notification) {
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.mountStateUnmounted()
        }
    }
    
    func mountStateDetails(notification: Notification) {
        
    }
}

extension ServiceManager: NSXPCListenerDelegate {
    
    func createServiceConnection() -> NSXPCConnection {
        //let newConnection = NSXPCConnection(serviceName: ServiceManager.serviceName)
        
        let newConnection = NSXPCConnection(machServiceName: ServiceManager.serviceName, options: NSXPCConnection.Options.init(rawValue: 0))
        
        let serviceInterface = NSXPCInterface(with: IPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        newConnection.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.serviceConnection = nil

            }
        }
        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.serviceConnection = nil
            }
        }
        newConnection.resume()
        return newConnection
    }
    
    func ensureServiceIsRunning() {
        if isProduction() {
            // ask the service to stop any important operations first.
            // there aren't any at the moment, so this is a placeholder
        }
        // temporary kill/restart for background service until proper calls are implemented
        background {
            if !self.enableLoginItem(false) {
                SDLogError("failed to unload login item")
            } else {
                SDLog("unloaded login item")
            }
            
            if !self.enableLoginItem(true) {
                SDLogError("failed to load login item")
            } else {
                SDLog("loaded login item")
            }
        }
    }
    
    func serviceReconnectionLoop() {
        while true {
            if self.serviceConnection == nil {
                
                self.updateNotificationSent = false
                
                self.serviceConnection = self.createServiceConnection()
                
                if let s = self.serviceConnection {
                    let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                        SDLogError("Connecting to service failed: \(error.localizedDescription)")
                    }) as! IPCProtocol
                    
                    proxy.setAppEndpoint(self.appListener.endpoint, reply: { (state) in
                        SDLog("App endpoint response: \(state)")
                    })
                }
                Thread.sleep(forTimeInterval: 1)
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
