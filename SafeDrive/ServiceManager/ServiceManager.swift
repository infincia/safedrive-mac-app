
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class ServiceManager: NSObject {
    static let sharedServiceManager = ServiceManager()
    
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
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        

        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            self.serviceReconnectionLoop()
        }
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            self.serviceLoop()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    var isServiceRunning: Bool {
        guard let _ = SMJobCopyDictionary(kSMDomainUserLaunchd, ("io.safedrive.SafeDrive.Service" as CFString)) else {
            return false
        }
        return true
        
    }
    
    fileprivate func serviceLoop() {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            while true {
                let running: Bool = self.isServiceRunning
                DispatchQueue.main.async(execute: {() -> Void in
                    NotificationCenter.default.post(name: Notification.Name.serviceStatus, object: running)
                })
                Thread.sleep(forTimeInterval: 1)
            }
        })
    }
    
    // swiftlint:disable force_unwrapping
    func loadService() {
        do {
            try deployService()
            
            let servicePlist: URL = Bundle.main.url(forResource: "io.safedrive.SafeDrive.Service", withExtension: "plist")!
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
        if !SMJobRemove(kSMDomainUserLaunchd, ("io.safedrive.SafeDrive.Service" as CFString), nil, true, &jobError) {
            if let error = jobError?.takeRetainedValue() {
                SDLog("Unload service error: \(error)")
                SDErrorHandlerReport(error)
            }
        }
    }
    
    func deployService() throws {
        let fileManager: FileManager = FileManager.default
        // swiftlint:disable force_try
        
        let libraryURL = try! fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let launchAgentsURL = libraryURL.appendingPathComponent("LaunchAgents", isDirectory: true)
        do {
            try fileManager.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            let message = NSLocalizedString("Error creating launch agents directory: \(error)", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .serviceDeployment)
            throw error
        }
        
        let applicationSupportURL = try! fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        // swiftlint:enable force_try
        
        let safeDriveApplicationSupportURL = applicationSupportURL.appendingPathComponent("SafeDrive", isDirectory: true)
        
        let serviceDestinationURL = safeDriveApplicationSupportURL.appendingPathComponent("SafeDriveService.app", isDirectory: true)
        
        let serviceSourceURL = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/SafeDriveService.app", isDirectory: true)
        
        // copy launch agent to ~/Library/LaunchAgents/
        let launchAgentDestinationURL = launchAgentsURL.appendingPathComponent("io.safedrive.SafeDrive.Service.plist", isDirectory: false)
        // swiftlint:disable force_unwrapping
        let launchAgentSourceURL: URL = Bundle.main.url(forResource: "io.safedrive.SafeDrive.Service", withExtension: "plist")!
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
        
        // copy background service to ~/Library/Application Support/SafeDrive/
        do {
            try fileManager.createDirectory(at: safeDriveApplicationSupportURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            let message = NSLocalizedString("Error creating support directory: \(error)", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .serviceDeployment)
            throw error
        }
        
        if fileManager.fileExists(atPath: serviceDestinationURL.path) {
            do {
                try fileManager.removeItem(at: serviceDestinationURL)
            } catch let error as NSError {
                SDLog("Error removing old service: \(error)")
            }
        }
        do {
            try fileManager.copyItem(at: serviceSourceURL, to: serviceDestinationURL)
        } catch let error as NSError {
            let message = NSLocalizedString("Error copying service: \(error)", comment: "")
            SDLog(message)
            let error = SDError(message: message, kind: .serviceDeployment)
            throw error
        }
        
    }
}

extension ServiceManager: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let _ = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in ServiceManager")
            
            return
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let _ = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in ServiceManager")
            
            return
        }
    }
}

extension ServiceManager: NSXPCListenerDelegate {
    
    func createServiceConnection() -> NSXPCConnection {
        let newConnection = NSXPCConnection(machServiceName:"io.safedrive.SafeDrive.Service", options:NSXPCConnection.Options(rawValue: UInt(0)))
        
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
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            self.unloadService()
            
            // wait for service to exit before reloading it
            while self.isServiceRunning {
                Thread.sleep(forTimeInterval: 1)
            }
            
            self.loadService()
        })
    }
    
    func serviceReconnectionLoop() {
        while true {
            if self.serviceConnection == nil {
                
                self.updateNotificationSent = false
                
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
