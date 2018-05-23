
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
    
    public let ipcServiceQueue = DispatchQueue(label: "io.safedrive.ipcServiceQueue")

    
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
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountState), name: Notification.Name.mountState, object: nil)
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
            SDLogError("ServiceManager", "API contract invalid: syncEvent()")
            return
        }
        
        ipcServiceQueue.async {
            if let s = self.ipcConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "syncEvent connecting to IPC service failed: \(error.localizedDescription)")
                }) as! IPCProtocol
                
                proxy.syncEvent(folderID)
            }
        }
    }
}

extension ServiceManager: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let uniqueClient = notification.object as? Client else {
            SDLogError("ServiceManager", "API contract invalid: applicationDidConfigureClient()")
            
            return
        }
        
        ipcServiceQueue.async {
            if let s = self.ipcConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "applicationDidConfigureClient(): connecting to IPC service failed: \(error.localizedDescription)")
                }) as! IPCProtocol
                
                // Note: this is intentionally breaking the implicit API for applicationDidConfigureClient
                //       but *only* when crossing the IPC boundary. The service and finder extension don't
                //       need anything but the unique client id.
                proxy.applicationDidConfigureClient(uniqueClient.uniqueClientId)
            }
        }
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let user = notification.object as? User else {
            SDLogError("ServiceManager", "API contract invalid: applicationDidConfigureUser()")
            
            return
        }
        
        ipcServiceQueue.async {
            if let s = self.ipcConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "applicationDidConfigureUser() connecting to IPC service failed: \(error.localizedDescription)")
                }) as! IPCProtocol
                
                proxy.applicationDidConfigureUser(user.email)
            }
        }
    }
}

extension ServiceManager: SDAccountProtocol {
    
    func didSignIn(notification: Notification) {
        ipcServiceQueue.async {
            if let s = self.ipcConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "didSignIn() connecting to IPC service failed: \(error.localizedDescription)")
                }) as! IPCProtocol
                
                proxy.didSignIn()
            }
        }
    }
    
    func didSignOut(notification: Notification) {
        ipcServiceQueue.async {
            if let s = self.ipcConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "didSignOut() connecting to IPC service failed: \(error.localizedDescription)")
                }) as! IPCProtocol
                
                proxy.didSignOut()
            }
        }
    }
    
    func didReceiveAccountDetails(notification: Notification) {
    }
    
    func didReceiveAccountStatus(notification: Notification) {
    }
    
}

extension ServiceManager: SDMountStateProtocol {
    
    func mountState(notification: Notification) {
        guard let mounted = notification.object as? Bool else {
            return
        }

        ipcServiceQueue.async {
            if let s = self.ipcConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "Connecting to service IPC failed: \(error.localizedDescription)")
                }) as! IPCProtocol
                
                proxy.mountState(mounted)
            }
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
            self?.ipcServiceQueue.async {
                self?.ipcConnection = nil

            }
        }
        newConnection.invalidationHandler = { [weak self] in
            self?.ipcServiceQueue.async {
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
                SDLogError("ServiceManager", "failed to unload login item")
            } else {
                SDLogInfo("ServiceManager", "unloaded login item")
            }
            
            if !self.enableLoginItem(true) {
                SDLogError("ServiceManager", "failed to load login item")
            } else {
                SDLogInfo("ServiceManager", "loaded login item")
            }
        }
    }
    
    func createServiceConnection() -> NSXPCConnection {
        SDLogDebug("ServiceManager", "creating connection to service")

        let newConnection = NSXPCConnection(machServiceName: ServiceManager.serviceName, options: .privileged)
        
        let serviceInterface = NSXPCInterface(with: ServiceXPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        newConnection.interruptionHandler = { [weak self] in
            SDLogWarn("ServiceManager", "service connection interrupted")
            
            DispatchQueue.main.async {
                //newConnection = nil
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
            SDLogWarn("ServiceManager", "service connection invalidated")

            DispatchQueue.main.async {
                //newConnection = nil
            }
        }
        newConnection.resume()
        return newConnection
    }
    
    func updateService() {
        SDLogWarn("ServiceManager", "Updating service")

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
            
            SDLogError("ServiceManager", "Service authorization error: \(error)")
            let authError = SDError(message: "Authorization error: \(error)", kind: .serviceDeployment)
            
            ServiceManager.delegate.didFail(error: authError)
        } else {
            var cfError: Unmanaged<CFError>? = nil
            
            if !SMJobBless(kSMDomainSystemLaunchd, ServiceManager.serviceName as CFString, authRef, &cfError) {
                // swiftlint:disable force_unwrapping
                let error = cfError!.takeRetainedValue() as Error
                // swiftlint:enable force_unwrapping

                SDLogError("ServiceManager", "Service installation error: \(error)")
                let blessError = SDError(message: "\(error)", kind: .serviceDeployment)
                ServiceManager.delegate.didFail(error: blessError)
            } else {
                SDLogInfo("ServiceManager", "\(ServiceManager.serviceName) installed")
                background {
                    ServiceManager.delegate.didValidateService()
                }
            }
        }
    }
    
    func serviceReconnectionLoop() {
        while true {
            ipcServiceQueue.async {
                if self.ipcConnection == nil {
                    
                    self.updateNotificationSent = false
                    
                    self.ipcConnection = self.createIPCServiceConnection()
                    
                    if let s = self.ipcConnection {
                        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                            SDLogError("ServiceManager", "Connecting to IPC service failed: \(error.localizedDescription)")
                        }) as! IPCProtocol
                        
                        proxy.setAppEndpoint(self.appListener.endpoint, reply: { (state) in
                            SDLogDebug("ServiceManager", "App endpoint response: \(state)")
                        })
                    }
                    Thread.sleep(forTimeInterval: 1)
                }
            }
            Thread.sleep(forTimeInterval: 5)
        }
    }
    
    func updateSDFS() {
        
        let s = self.createServiceConnection()
        
        let sdfs = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Filesystems/sdfs.bundle", isDirectory: false)

        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
            SDLogError("ServiceManager", "Cannot update SDFS, connecting to service failed: \(error.localizedDescription)")
            let error = SDError(message: "Cannot update SDFS, connecting to service failed: \(error.localizedDescription)", kind: .fuseDeployment)
            ServiceManager.delegate.didFail(error: error)
        }) as! ServiceXPCProtocol
        
        proxy.updateSDFS(sdfs.path) { (state, status) in
            if state {
                SDLogInfo("ServiceManager", "SDFS updated, new version: \(status)")
                ServiceManager.delegate.didValidateSDFS()
            } else {
                SDLogError("ServiceManager", "Cannot update SDFS, installation failed: \(status)")
                let error = SDError(message: "Cannot update SDFS, installation failed: \(status)", kind: .fuseDeployment)
                ServiceManager.delegate.didFail(error: error)
            }
        }
    }
    
    func loadKext() {
        let s = self.createServiceConnection()
        
        background {
            outer: while !self.loadedKext {
                SDLogInfo("ServiceManager", "SDFS kext loading attempt")

                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("ServiceManager", "Cannot load SDFS kext: \(error.localizedDescription)")
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
                        SDLogInfo("ServiceManager", "SDFS kext loaded")
                        main {
                            ServiceManager.delegate.didValidateKext()
                        }
                        self.loadedKext = true
                    } else {
                        SDLogError("ServiceManager", "Cannot load SDFS kext: \(status)")
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
            SDLogError("ServiceManager", "Cannot determine app version, this should never happen")
            ServiceManager.delegate.needsService()
            return
        }
        
        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
            SDLogError("ServiceManager", "Cannot communicate with service, connection failed: \(error.localizedDescription)")
            ServiceManager.delegate.needsService()
        }) as! ServiceXPCProtocol
        
        proxy.currentServiceVersion { (version) in
            guard let currentServiceVersion = version else {
                ServiceManager.delegate.needsService()
                return
            }
            if Semver.gte(currentServiceVersion, appVersion) {
                SDLogInfo("ServiceManager", "Service up to date")
                ServiceManager.delegate.didValidateService()
            } else {
                SDLogWarn("ServiceManager", "Service update needed")
                ServiceManager.delegate.needsService()
            }
        }
    }
    
    public func forceUnmountSafeDrive(_ path: String, _ successBlock: @escaping () -> Void, _ failureBlock: @escaping (_ error: SDError) -> Void) {
        
        let s = self.createServiceConnection()
        
        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
            SDLogError("ServiceManager", "Cannot communicate with service, connection failed: \(error.localizedDescription)")
            let error = SDError(message: "Force unmount failed: \(error)", kind: .unmountFailed)
            
            main {
                failureBlock(error)
            }
            
        }) as! ServiceXPCProtocol
        
        
        proxy.forceUnmountSafeDrive(path) { (success, status) in
            if success {
                SDLogInfo("ServiceManager", "Force unmount succeeded")
                
                main {
                    successBlock()
                }
            } else {
                SDLogError("ServiceManager", "Force unmount failed: \(status)")
                
                let error = SDError(message: "Force unmount failed: \(status)", kind: .unmountFailed)

                main {
                    failureBlock(error)
                }
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
