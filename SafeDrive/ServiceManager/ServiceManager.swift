
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import ServiceManagement

protocol ServiceManagerDelegate: class {
    func needsService()
    func didValidateService()
    func didValidateSDFS()
    func needsKext()
    func didValidateKext()
    func didFail(error: Error)
}


class ServiceManager: NSObject {
    static let sharedServiceManager = ServiceManager()
    static var delegate: ServiceManagerDelegate!
    
    public let loadKextQueue = DispatchQueue(label: "io.safedrive.loadKextQueue")

    static let ipcServiceName = "G738Z89QKM.io.safedrive.IPCService"
    static let serviceName = "io.safedrive.SafeDrive.d"

    static let appName = "SafeDrive"
    
    fileprivate var ipcConnection: NSXPCConnection?
    fileprivate var appListener: NSXPCListener
    fileprivate var currentIPCServiceVersion: Int?
    // swiftlint:disable weak_delegate
    // disabling lint because this isn't a delegate but an XPC exported 
    // object owned by this class
    fileprivate var appXPCDelegate: AppXPCDelegate?
    // swiftlint:enable weak_delegate

    fileprivate var updateNotificationSent = false
    
    fileprivate var _loadedKext = false
    
    var loadedKext: Bool {
        get {
            var l: Bool = false
            loadKextQueue.sync {
                l = self._loadedKext
            }
            return l
        }
        set (newValue) {
            loadKextQueue.sync(flags: .barrier, execute: {
                self._loadedKext = newValue
            })
        }
    }
    
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
            self.serviceReconnectionLoop()
        }
    }
    
    func enableLoginItem(_ state: Bool) -> Bool {
        
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/IPCService.app", isDirectory: false)
        
        if LSRegisterURL(helper as CFURL, state) != noErr {
            print("Failed to LSRegisterURL \(helper)")
        }
        
        if (SMLoginItemSetEnabled((ServiceManager.ipcServiceName as CFString), state)) {
            return true
        } else {
            print("Failed to SMLoginItemSetEnabled \(helper)")
            return false
        }
    }

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ServiceManager: SDSyncEventProtocol {
    func syncEvent(notification: Notification) {
        guard let folderID = notification.object as? UInt64 else {
            SDLog("API contract invalid: syncEvent in ServiceManager")
            return
        }
        
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("syncEvent connecting to IPC service failed: \(error.localizedDescription)")
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
        
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("applicationDidConfigureClient connecting to IPC service failed: \(error.localizedDescription)")
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
        
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("applicationDidConfigureUser connecting to IPC service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.applicationDidConfigureUser(user.email)
        }
    }
}

extension ServiceManager: SDAccountProtocol {
    
    func didSignIn(notification: Notification) {
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("didSignIn connecting to IPC service failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.didSignIn()
        }
    }
    
    func didSignOut(notification: Notification) {
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("didSignOut connecting to IPC service failed: \(error.localizedDescription)")
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
        
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service IPC failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.mountStateMounted()
        }
    }
    
    func mountStateUnmounted(notification: Notification) {
        if let s = self.ipcConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service IPC failed: \(error.localizedDescription)")
            }) as! IPCProtocol
            
            proxy.mountStateUnmounted()
        }
    }
    
    func mountStateDetails(notification: Notification) {
        
    }
}

extension ServiceManager: NSXPCListenerDelegate {
    
    func createIPCServiceConnection() -> NSXPCConnection {
        //let newConnection = NSXPCConnection(serviceName: ServiceManager.serviceName)
        
        let newConnection = NSXPCConnection(machServiceName: ServiceManager.ipcServiceName, options: NSXPCConnection.Options.init(rawValue: 0))
        
        let serviceInterface = NSXPCInterface(with: IPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        newConnection.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.ipcConnection = nil

            }
        }
        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.ipcConnection = nil
            }
        }
        newConnection.resume()
        return newConnection
    }
    
    func ensureIPCServiceIsRunning() {
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
    
    func createServiceConnection() -> NSXPCConnection {
        SDLog("creating connection to service")

        let newConnection = NSXPCConnection(machServiceName: ServiceManager.serviceName, options: .privileged)
        
        let serviceInterface = NSXPCInterface(with: ServiceXPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        newConnection.interruptionHandler = { [weak self] in
            SDLog("service connection interrupted")
            
            DispatchQueue.main.async {
                //newConnection = nil
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
            SDLog("service connection invalidated")

            DispatchQueue.main.async {
                //newConnection = nil
            }
        }
        newConnection.resume()
        return newConnection
    }
    
    func updateService() {
        SDLog("Updating service")

        if isProduction() {
            // ask the service to stop any important operations first.
            // there aren't any at the moment, so this is a placeholder
        }

        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        
        var authRights: AuthorizationRights = AuthorizationRights(count: 1, items: &authItem)
        
        let authFlags: AuthorizationFlags = [[], .extendRights, .interactionAllowed, .preAuthorize ]
        
        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        
        if status != errAuthorizationSuccess {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            
            SDLogError("Service authorization error: \(error)")
            let authError = SDError(message: "Authorization error: \(error)", kind: .serviceDeployment)
            
            ServiceManager.delegate.didFail(error: authError)
        } else {
            var cfError: Unmanaged<CFError>? = nil
            
            if !SMJobBless(kSMDomainSystemLaunchd, ServiceManager.serviceName as CFString, authRef, &cfError) {
                // swiftlint:disable force_unwrapping
                let error = cfError!.takeRetainedValue() as Error
                // swiftlint:enable force_unwrapping

                SDLogError("Service installation error: \(error)")
                let blessError = SDError(message: "\(error)", kind: .serviceDeployment)
                ServiceManager.delegate.didFail(error: blessError)
            } else {
                SDLog("\(ServiceManager.serviceName) installed")
                background {
                    ServiceManager.delegate.didValidateService()
                }
            }
        }
    }
    
    func serviceReconnectionLoop() {
        while true {
            if self.ipcConnection == nil {
                
                self.updateNotificationSent = false
                
                self.ipcConnection = self.createIPCServiceConnection()
                
                if let s = self.ipcConnection {
                    let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                        SDLogError("Connecting to IPC service failed: \(error.localizedDescription)")
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
    
    func updateSDFS() {
        
        let s = self.createServiceConnection()
        
        let sdfs = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Filesystems/sdfs.bundle", isDirectory: false)

        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
            SDLogError("Cannot update SDFS, connecting to service failed: \(error.localizedDescription)")
            let error = SDError(message: "Cannot update SDFS, connecting to service failed: \(error.localizedDescription)", kind: .fuseDeployment)
            ServiceManager.delegate.didFail(error: error)
        }) as! ServiceXPCProtocol
        
        proxy.updateSDFS(sdfs.path) { (state, status) in
            if state {
                SDLog("SDFS updated, new version: \(status)")
                ServiceManager.delegate.didValidateSDFS()
            } else {
                SDLogError("Cannot update SDFS, installation failed: \(status)")
                let error = SDError(message: "Cannot update SDFS, installation failed: \(status)", kind: .fuseDeployment)
                ServiceManager.delegate.didFail(error: error)
            }
        }
    }
    
    func loadKext() {
        let s = self.createServiceConnection()
        
        background {
            outer: while !self.loadedKext {
                SDLog("SDFS kext loading attempt")

                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("Cannot load SDFS kext: \(error.localizedDescription)")
                    let error = SDError(message: "Cannot load SDFS kext: \(error.localizedDescription)", kind: .kextLoading)
                    main {
                        ServiceManager.delegate.didFail(error: error)
                    }
                    
                    // not actually loaded, but this breaks the loop for the
                    // failure case
                    self.loadedKext = true
                }) as! ServiceXPCProtocol
                
                proxy.loadKext { (state, status) in
                    if state {
                        SDLog("SDFS kext loaded")
                        main {
                            ServiceManager.delegate.didValidateKext()
                        }
                        self.loadedKext = true
                    } else {
                        SDLogError("Cannot load SDFS kext: \(status)")
                        main {
                            ServiceManager.delegate.needsKext()
                        }
                        self.loadedKext = false
                    }
                }
                Thread.sleep(forTimeInterval: 30)
            }
        }
    }
    
    func checkServiceVersion() {
        
        let s = self.createServiceConnection()

        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            SDLogError("Cannot determine app version, this should never happen")
            ServiceManager.delegate.needsService()
            return
        }
        
        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
            SDLogError("Cannot communicate with service, connection failed: \(error.localizedDescription)")
            ServiceManager.delegate.needsService()
        }) as! ServiceXPCProtocol
        
        proxy.currentServiceVersion { (version) in
            guard let currentServiceVersion = version else {
                ServiceManager.delegate.needsService()
                return
            }
            if Semver.gte(currentServiceVersion, appVersion) {
                SDLog("Service up to date")
                ServiceManager.delegate.didValidateService()
            } else {
                SDLogWarn("Service update needed")
                ServiceManager.delegate.needsService()
            }
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
