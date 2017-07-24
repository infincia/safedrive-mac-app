
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import ServiceManagement

class ServiceManager: NSObject {
    static let sharedServiceManager = ServiceManager()
    
    static let serviceName = "io.safedrive.SafeDrive.d"
    static let appName = "SafeDrive"
    
    fileprivate var useLaunchAgent = true
    
    fileprivate var serviceConnection: NSXPCConnection?
    fileprivate var appListener: NSXPCListener
    fileprivate var currentServiceVersion: Int?
    fileprivate weak var appXPCDelegate: AppXPCDelegate?
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

        DispatchQueue.global(priority: .default).async {
            self.serviceReconnectionLoop()
        }
        DispatchQueue.global(priority: .default).async {
            self.serviceLoop()
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
        DispatchQueue.global(priority: .default).async {
            while true {
                let running: Bool = self.isServiceRunning
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.serviceStatus, object: running)
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
    
    func enableLoginItem(_ state: Bool) -> Bool {
        
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/" + ServiceManager.serviceName, isDirectory: false)
        
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
    
    // swiftlint:disable force_unwrapping
    func loadService() {
        do {
            try deployLaunchAgent()
            
            try deployService()
            
            let servicePlist: URL = Bundle.main.url(forResource: ServiceManager.serviceName, withExtension: "plist")!
            let jobDict = NSDictionary(contentsOfFile: servicePlist.path)
            var jobError: Unmanaged<CFError>? = nil
            
            if !SMJobSubmit(kSMDomainUserLaunchd, jobDict!, nil, &jobError) {
                if let error = jobError?.takeRetainedValue() {
                    SDLog("Load service error: \(error)")
                    SDErrorHandlerReport(error)
                    
                }
            }
        } catch {
            SDLog("Deploying service failed: \(error)")
            SDErrorHandlerReport(error)
        }
    }
    // swiftlint:enable force_unwrapping

    func unloadService() {
        var jobError: Unmanaged<CFError>? = nil
        if !SMJobRemove(kSMDomainUserLaunchd, (ServiceManager.serviceName as CFString), nil, true, &jobError) {
            if let error = jobError?.takeRetainedValue() {
                SDLog("Unload service error: \(error)")
                SDErrorHandlerReport(error)
            }
        }
    }
    
    func launchAgentURL() throws -> URL {
        let fileManager: FileManager = FileManager.default

        let libraryURL = try fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let launchAgentsURL = libraryURL.appendingPathComponent("LaunchAgents", isDirectory: true)

        do {
            try fileManager.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            let message = NSLocalizedString("Error creating launch agents directory: \(error)", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .serviceDeployment)
            throw error
        }
        
        return launchAgentsURL
    }
    
    func serviceURL() -> URL {
        
        let serviceSourceURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/" + ServiceManager.serviceName, isDirectory: false)
        
        return serviceSourceURL
    }
    
    func serviceDestinationURL() throws -> URL {
        let launchAgentsURL = try launchAgentURL()
        
        let serviceDestinationURL = launchAgentsURL.appendingPathComponent(ServiceManager.serviceName, isDirectory: false)
        
        return serviceDestinationURL
    }
    
    func deployLaunchAgent() throws {
        let fileManager: FileManager = FileManager.default

        let launchAgentsURL = try launchAgentURL()

        // copy launch agent to ~/Library/LaunchAgents/
        let launchAgentDestinationURL = launchAgentsURL.appendingPathComponent(ServiceManager.serviceName + ".plist", isDirectory: false)
        // swiftlint:disable force_unwrapping
        let launchAgentSourceURL: URL = Bundle.main.url(forResource: ServiceManager.serviceName, withExtension: "plist")!
        // swiftlint:enable force_unwrapping
        
        if FileManager.default.fileExists(atPath: launchAgentDestinationURL.path) {
            do {
                try FileManager.default.removeItem(at: launchAgentDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old launch agent: \(error)")
            }
        }
        do {
            try fileManager.copyItem(at: launchAgentSourceURL, to: launchAgentDestinationURL)
        } catch let error as NSError {
            let message = NSLocalizedString("Error copying launch agent: \(error)", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .serviceDeployment)
            throw error
        }
    }
    
    func deployService() throws {
        let fileManager: FileManager = FileManager.default
        
        let serviceURL = self.serviceURL()
        
        let serviceDestinationURL = try self.serviceDestinationURL()

        // copy background service to ~/Library/Application Support/SafeDrive/
        
        if fileManager.fileExists(atPath: serviceDestinationURL.path) {
            do {
                try fileManager.removeItem(at: serviceDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old service: \(error)")
            }
        }
        do {
            try fileManager.copyItem(at: serviceURL, to: serviceDestinationURL)
        } catch let error as NSError {
            let message = NSLocalizedString("Error copying service: \(error)", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .serviceDeployment)
            throw error
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
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! ServiceXPCProtocol
            
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
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! ServiceXPCProtocol
            
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
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! ServiceXPCProtocol
            
            proxy.applicationDidConfigureUser(user.email)
        }
    }
}

extension ServiceManager: SDAccountProtocol {
    
    func didSignIn(notification: Notification) {
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! ServiceXPCProtocol
            
            proxy.didSignIn()
        }
    }
    
    func didSignOut(notification: Notification) {
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! ServiceXPCProtocol
            
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
            }) as! ServiceXPCProtocol
            
            proxy.mountStateMounted()
        }
    }
    
    func mountStateUnmounted(notification: Notification) {
        if let s = self.serviceConnection {
            let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                SDLogError("Connecting to service failed: \(error.localizedDescription)")
            }) as! ServiceXPCProtocol
            
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
        
        let serviceInterface = NSXPCInterface(with: ServiceXPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        weak var weakSelf: ServiceManager? = self
        
        newConnection.interruptionHandler = {
            DispatchQueue.main.async {
                if let weakSelf = weakSelf {
                    weakSelf.serviceConnection = nil
                }
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
    
    func ensureServiceIsRunning() {
        if isProduction() {
            // ask the service to stop any important operations first.
            // there aren't any at the moment, so this is a placeholder
        }
        // temporary kill/restart for background service until proper calls are implemented
        DispatchQueue.global(priority: .default).async {
            if self.useLaunchAgent {
                // disable the login item if we're using the launch agent
                //if !self.enableLoginItem(false) {
                //    SDLogError("failed to unload login item")
                //} else {
                //    SDLog("unloaded login item")
                //}
                
                self.unloadService()
                
                // wait for service to exit before reloading it
                while self.isServiceRunning {
                    Thread.sleep(forTimeInterval: 1)
                }
                
                self.loadService()
            } else {
                // forcefully unload the launch agent if we're using a login item
                //self.unloadService()
                
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
    }
    
    func serviceReconnectionLoop() {
        while true {
            if self.serviceConnection == nil {
                
                self.updateNotificationSent = false
                
                self.serviceConnection = self.createServiceConnection()
                
                if let s = self.serviceConnection {
                    let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                        SDLogError("Connecting to service failed: \(error.localizedDescription)")
                    }) as! ServiceXPCProtocol
                    
                    proxy.sendAppEndpoint(self.appListener.endpoint, reply: { (state) in
                        SDLog("App endpoint response: \(state)")
                    })
                }
                Thread.sleep(forTimeInterval: 1)
            }
            if let s = self.serviceConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLog("error connecting to service \(error.localizedDescription)")
                }) as! ServiceXPCProtocol
                
                proxy.protocolVersion({ (version: Int!) in
                    self.currentServiceVersion = version

                    if let runningVersion = self.currentServiceVersion {
                        if runningVersion != kServiceXPCProtocolVersion {
                            if !self.updateNotificationSent {
                                self.updateNotificationSent = true
                                SDLogWarn("Service needs to be updated (running: \(runningVersion), current \(kServiceXPCProtocolVersion))")
                            }
                            if let s = self.serviceConnection {
                                s.invalidate()
                            }
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
