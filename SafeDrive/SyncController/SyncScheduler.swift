
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length

import Crashlytics
import Foundation

struct SyncEvent {
    let uniqueClientID: String
    let folderID: UInt64
    let direction: SDKSyncDirection
    let name: String
    let session: SDKSyncSession?
    let destination: URL?
}

class SyncScheduler {
    
    static let sharedSyncScheduler = SyncScheduler()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var syncControllers = [SyncController]()
    
    public var folders = [SDKSyncFolder]()
    
    public let foldersQueue = DispatchQueue(label: "io.safedrive.foldersQueue")
    
    public var tasks = [SDKSyncTask]()

    fileprivate let tasksQueue = DispatchQueue(label: "io.safedrive.tasksQueue")

    fileprivate var _running = false

    fileprivate let runQueue = DispatchQueue(label: "io.safedrive.runQueue")
    
    fileprivate let syncControllerQueue = DispatchQueue(label: "syncControllerQueue")

    var email: String?
    var internalUserName: String?
    var password: String?
    var uniqueClientID: String?
    var uniqueClientName: String?

    var remoteHost: String?
    var remotePort: UInt16?
    
    var running: Bool {
        get {
            var r: Bool = false
            runQueue.sync {
                r = self._running
            }
            return r
        }
        set (newValue) {
            runQueue.sync(flags: .barrier, execute: {
                self._running = newValue
            })
        }
    }
    
    fileprivate var syncQueue = [SyncEvent]()
    
    init() {
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func syncSchedulerLoop() throws {

        SDLogInfo("SyncScheduler", "Sync scheduler running")
        
        while self.running {
            guard let uniqueClientID = self.uniqueClientID,
                  let _ = self.uniqueClientName else {
                Thread.sleep(forTimeInterval: 1)
                continue
            }
        
            if !SafeDriveSDK.sharedSDK.ready {
                Thread.sleep(forTimeInterval: 1)
                continue
            }
            
            autoreleasepool {
                
                let currentDate = Date()
                
                let unitFlags: NSCalendar.Unit = [.second, .minute, .hour, .day, .month, .year]
                let currentDateComponents = (Calendar.current as NSCalendar).components(unitFlags, from: currentDate)
                
                
                var components = DateComponents()
                components.hour = currentDateComponents.hour
                components.minute = currentDateComponents.minute
                let calendar = Calendar.current
                // swiftlint:disable force_unwrapping
                let syncDate = calendar.date(from: components)!
                // swiftlint:enable force_unwrapping
                
                var nfolders = [SDKSyncFolder]()
                
                // only trigger in the first minute of each hour
                // this would run twice per hour if we did not sleep thread for 60 seconds
                
                
                if currentDateComponents.minute == 0 {
                    // first minute of each hour for hourly syncs
                    // NOTE: this scheduler ignores syncTime on purpose, hourly syncs always run at xx:00
                    foldersQueue.sync {
                        let hourlyFolders = folders.filter { (folder) -> Bool in
                            return folder.syncFrequency == "hourly" && folder.active == true
                        }
                        nfolders.append(contentsOf: hourlyFolders)
                    }
                }
                
                
                if currentDateComponents.day == 1 {
                    // first of the month for monthly syncs
                    foldersQueue.sync {
                        let monthlyFolders = folders.filter { (folder) -> Bool in
                            return folder.syncFrequency == "monthly" && folder.active == true && folder.syncTime == syncDate
                        }
                    
                        nfolders.append(contentsOf: monthlyFolders)
                    }
                }
                
                
                if currentDateComponents.weekday == 1 {
                    // first day of the week for weekly syncs
                    foldersQueue.sync {
                        let weeklyFolders = folders.filter { (folder) -> Bool in
                            return folder.syncFrequency == "weekly" && folder.active == true && folder.syncTime == syncDate
                        }
                    
                        nfolders.append(contentsOf: weeklyFolders)
                    }
                }
                
                
                // daily syncs at arbitrary times based on syncTime property
                foldersQueue.sync {
                    let dailyFolders = folders.filter { (folder) -> Bool in
                        return folder.syncFrequency == "daily" && folder.active == true && folder.syncTime == syncDate
                    }
                
                    nfolders.append(contentsOf: dailyFolders)
                }
                
                for folder in nfolders {
                    self.queueSyncJob(uniqueClientID, folderID: folder.id, direction: .forward, name: UUID().uuidString.lowercased(), destination: nil, session: nil)
                }
                
                // keep loop in sync with clock time to the next minute
                // swiftlint:disable force_unwrapping
                let sleepSeconds = 60 - currentDateComponents.second!
                // swiftlint:enable force_unwrapping

                Thread.sleep(forTimeInterval: Double(sleepSeconds))
                
            }
        }
    }
    
    public func taskForFolderID(_ folderID: UInt64) -> SDKSyncTask? {
        var task: SDKSyncTask?
        
        self.tasksQueue.sync {
            if let storedTask = self.tasks.first(where: { $0.folderID == folderID }) {
               task = storedTask
            }
        }
        
        return task
    }
    
    public func removeTaskForFolderID(_ folderID: UInt64) {
        self.tasksQueue.sync {
            if let storedTaskIndex = self.tasks.index(where: { $0.folderID == folderID }) {
                self.tasks.remove(at: storedTaskIndex)
            }
        }
    }
    
    func queueSyncJob(_ uniqueClientID: String, folderID: UInt64, direction: SDKSyncDirection, name: String, destination: URL?, session: SDKSyncSession?) {
        let syncEvent = SyncEvent(uniqueClientID: uniqueClientID, folderID: folderID, direction: direction, name: name, session: session, destination: destination)
        self.sync(syncEvent)
    }
    
    func stop() {
        self.running = false
    }
    
    func cancel(_ uniqueID: UInt64, completion: @escaping () -> Void) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")

        for syncController in self.syncControllers {
            if syncController.uniqueID == uniqueID {
                syncController.stopSyncTask {
                    completion()
                    return
                }
            }
        }
        completion()
    }
    
    fileprivate func sync(_ syncEvent: SyncEvent) {
        background {
            SDLogInfo("SyncScheduler", "Queued sync job \(syncEvent)")

            guard let _ = self.email,
                  let localPassword = self.password,
                  let localInternalUserName = self.internalUserName,
                  let localPort = self.remotePort,
                  let localHost = self.remoteHost else {
                SDLogWarn("SyncScheduler", "credentials unavailable, cancelling sync")
                return
            }
            
            let folderID = syncEvent.folderID
            var isRestore: Bool = false
            if syncEvent.direction == .reverse {
                isRestore = true
            }

            let name = syncEvent.name.lowercased()
            let syncDate = Date()
            
            var tempTask: SDKSyncTask?
            
            if let storedTask = self.taskForFolderID(folderID) {
                tempTask = storedTask
            } else {
                let newTask = SDKSyncTask(folderID: folderID, syncDate: syncDate, name: name)
                
                self.tasksQueue.sync {
                    self.tasks.append(newTask)
                }
                
                tempTask = newTask
            }
            
            
            guard let task = tempTask else {
                SDLogWarn("SyncScheduler", "no sync task available")
                return
            }
            
            let syncController = SyncController()


            
            guard let folder = self.folders.first(where: { (folder) -> Bool in
                return folder.id == folderID
            }) else {
                SDLogWarn("SyncScheduler", "failed to get sync folder from list")
                return
            }
            
            let localFolder = URL(fileURLWithPath: folder.path, isDirectory: true)
            
            if task.syncing {
                SDLogInfo("SyncScheduler", "Sync for \(folder.name) already in progress, cancelling")
                //NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSyncAlreadyRunning userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
                return
            }
            
            
            if folder.encrypted {
                if isRestore {
                    guard let session = syncEvent.session else {
                        SDLogWarn("SyncScheduler", "failed to get sync session from list")
                        return
                    }
                    
                    syncController.spaceNeeded = UInt64(session.size)
                }
                
            } else {
                let host = Host()
                // swiftlint:disable force_unwrapping
                let machineName = host.localizedName!
                // swiftlint:enable force_unwrapping
                
                let defaultFolder: URL = URL(fileURLWithPath: defaultServerPath())
                
                let machineFolder: URL = defaultFolder.appendingPathComponent(machineName, isDirectory: true)
                let remoteFolder: URL = machineFolder.appendingPathComponent(folder.name, isDirectory: true)
                var urlComponents: URLComponents = URLComponents()
                urlComponents.user = localInternalUserName
                urlComponents.host = localHost
                urlComponents.path = remoteFolder.path
                urlComponents.port = Int(localPort)
                // swiftlint:disable force_unwrapping
                let remote: URL = urlComponents.url!
                // swiftlint:enable force_unwrapping
                
                syncController.serverURL = remote
                syncController.password = localPassword
                
                syncController.spaceNeeded = 0
                
            }
            
            
            
            task.syncDate = syncDate
            task.name = name
            task.message = ""
            task.syncing = true
            task.restoring = isRestore
            
            
            syncController.uniqueID = folder.id
            syncController.encrypted = folder.encrypted
            syncController.uuid = name
            syncController.localURL = localFolder
            if let destination = syncEvent.destination {
                syncController.destination = destination
            }
            
            syncController.restore = isRestore
            syncController.folderName = folder.name
            
            self.syncControllerQueue.sync {
                self.syncControllers.append(syncController)
            }
            
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
            }

            syncController.startSyncTask(progress: { (_, _, _, percent) in
                // use for updating sync progress
                // WARNING: this block may be called more often than once per second on a background serial queue, DO NOT block it for long
                
                task.progress = percent
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
                }
            }, bandwidth: { (speed) in
                
                task.bandwidth = speed
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
                }
            }, issue: { (message) in

                task.log(message: message + "\n")
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
                }
                
            }, success: { (_: URL) -> Void in
                SDLogInfo("SyncScheduler", "Sync finished for \(String(describing: syncController.folderName))")
                
                let duration = NSDate().timeIntervalSince(syncDate)
                
                task.success = true
                task.duration = duration
                task.progress = 0.0
                task.bandwidth = ""
                task.syncing = false
                task.restoring = false
                
                self.syncControllerQueue.sync {
                    if let index = self.syncControllers.index(of: syncController) {
                        self.syncControllers.remove(at: index)
                    }
                }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
                }
                
            }, failure: { (_: URL, error: Error) -> Void in
                SDErrorHandlerReport(error)
                SDLogInfo("SyncScheduler", "Sync failed for \(String(describing: syncController.folderName)): \(error.localizedDescription)")

                let duration = NSDate().timeIntervalSince(syncDate)

                task.syncing = false
                task.restoring = false
                task.bandwidth = ""
                task.success = false
                task.duration = duration
                task.message = error.localizedDescription
                task.progress = 0.0
                
                
                self.syncControllerQueue.async {
                    if let index = self.syncControllers.index(of: syncController) {
                        self.syncControllers.remove(at: index)
                    }
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name.syncEvent, object: folderID)
                }
            })
        }
    }
}

extension SyncScheduler: SDAccountProtocol {
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn() called on background thread")
        
        guard let accountStatus = notification.object as? SDKAccountStatus else {
            SDLogError("SyncScheduler", "API contract invalid: didSignIn()")
            return
        }
        
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut() called on background thread")
        syncControllerQueue.sync {
            for syncController in self.syncControllers {
                syncController.stopSyncTask {
                    return
                }
            }
        }
        
        self.sdk.ready = false

        self.email = nil
        self.password = nil
        self.uniqueClientID = nil
        self.uniqueClientName = nil
        self.internalUserName = nil
        self.remoteHost = nil
        self.remotePort = nil
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")

        guard let accountStatus = notification.object as? SDKAccountStatus else {
            SDLogError("SyncScheduler", "API contract invalid: didReceiveAccountStatus()")
            return
        }
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")

        guard let _ = notification.object as? SDKAccountDetails else {
            SDLogError("SyncScheduler", "API contract invalid: didReceiveAccountDetails()")
            return
        }
    }
}

extension SyncScheduler: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let uniqueClient = notification.object as? Client else {
            SDLogError("SyncScheduler", "API contract invalid: applicationDidConfigureClient()")
            
            return
        }
        
        self.uniqueClientID = uniqueClient.uniqueClientId
        self.uniqueClientName = uniqueClient.uniqueClientName
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let currentUser = notification.object as? User else {
            SDLogError("SyncScheduler", "API contract invalid: applicationDidConfigureUser()")
            
            return
        }
        self.email = currentUser.email
        self.password = currentUser.password
    }
}
