
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_try

import Foundation

import Crashlytics

import Realm
import RealmSwift
import SafeDriveSDK

enum SyncDirection {
    case forward
    case reverse
}

enum SyncType {
    case encrypted
    case unencrypted
}

struct SyncEvent {
    let uniqueClientID: String
    let folderID: UInt64
    let direction: SyncDirection
    let type: SyncType
    let name: String
    let destination: URL?
}

class SyncScheduler {
    
    static let sharedSyncScheduler = SyncScheduler()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var syncControllers = [SyncController]()
    
    fileprivate var _running = false
    
    fileprivate let runQueue = DispatchQueue(label: "io.safedrive.runQueue")
    
    var email: String?
    var internalUserName: String?
    var password: String?
    var uniqueClientID: String?
    
    var remoteHost: String?
    var remotePort: UInt16?
    
    var running: Bool {
        get {
            var r: Bool?
            runQueue.sync {
                r = self._running
            }
            return r!
        }
        set (newValue) {
            runQueue.sync(flags: .barrier, execute: {
                self._running = newValue
            })
        }
    }
    
    fileprivate var syncQueue = [SyncEvent]()
    
    fileprivate var syncDispatchQueue = DispatchQueue(label: "io.safedrive.SyncScheduler.SyncQueue", attributes: [])
    
    let dbURL: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db")!.appendingPathComponent("sync.realm")
    
    var realm: Realm?
    
    init() {
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureRealm), name: Notification.Name.applicationDidConfigureRealm, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func syncSchedulerLoop() throws {

        SDLog("Sync scheduler running")
        
        while self.running {
            guard let uniqueClientID = self.uniqueClientID, let realm = self.realm else {
                Thread.sleep(forTimeInterval: 1)
                continue
            }
        
            if !SafeDriveSDK.sharedSDK.ready {
                Thread.sleep(forTimeInterval: 1)
                continue
            }
            
            autoreleasepool {
                realm.refresh()
                realm.invalidate()
                
                let currentDate = Date()
                
                let unitFlags: NSCalendar.Unit = [.second, .minute, .hour, .day, .month, .year]
                let currentDateComponents = (Calendar.current as NSCalendar).components(unitFlags, from: currentDate)
                
                
                var components = DateComponents()
                components.hour = currentDateComponents.hour
                components.minute = currentDateComponents.minute
                let calendar = Calendar.current
                let syncDate = calendar.date(from: components)!
                
                var folders = [SyncFolder]()
                
                // only trigger in the first minute of each hour
                // this would run twice per hour if we did not sleep thread for 60 seconds
                
                
                if currentDateComponents.minute == 0 {
                    // first minute of each hour for hourly syncs
                    // NOTE: this scheduler ignores syncTime on purpose, hourly syncs always run at xx:00
                    let hourlyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'hourly' AND syncing == false AND uniqueClientID == '\(uniqueClientID)'")
                    folders.append(contentsOf: hourlyFolders)
                }
                
                
                if currentDateComponents.day == 1 {
                    // first of the month for monthly syncs
                    let monthlyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'monthly' AND syncing == false AND uniqueClientID == '\(uniqueClientID)' AND syncTime == %@", syncDate)
                    folders.append(contentsOf: monthlyFolders)
                }
                
                
                if currentDateComponents.weekday == 1 {
                    // first day of the week for weekly syncs
                    let weeklyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'weekly' AND syncing == false AND uniqueClientID == '\(uniqueClientID)' AND syncTime == %@", syncDate)
                    folders.append(contentsOf: weeklyFolders)
                }
                
                
                // daily syncs at arbitrary times based on syncTime property
                let dailyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'daily' AND syncing == false AND uniqueClientID == '\(uniqueClientID)' AND syncTime == %@", syncDate)
                folders.append(contentsOf: dailyFolders)
                
                
                
                for folder in folders {
                    let folderID = folder.uniqueID
                    let type: SyncType = folder.encrypted ? .encrypted : .unencrypted
                    self.queueSyncJob(uniqueClientID, folderID: UInt64(folderID), direction: .forward, type: type, name: UUID().uuidString.lowercased(), destination: nil)
                }
                
                // keep loop in sync with clock time to the next minute
                let sleepSeconds = 60 - currentDateComponents.second!
                Thread.sleep(forTimeInterval: Double(sleepSeconds))
                
            }
        }
    }
    
    func restartRestore(_ uniqueClientID: String) throws {
        guard let realm = self.realm else {
            SDLog("failed to get realm!!!")
            Crashlytics.sharedInstance().crash()
            return
        }
        
        /*
         Check for folders that are supposedly restoring, which means SafeDrive was killed or crashed while a restore
         was in progress.
         
         We have no other option but to display a warning when this happens, rsync will have exited in a half-synced state.
         
         */
        
        for folder in realm.objects(SyncFolder.self).filter("restoring == true AND uniqueClientID == '\(uniqueClientID)'") {
            let type: SyncType = folder.encrypted ? .encrypted : .unencrypted
            guard let currentSyncUUID = folder.currentSyncUUID else {
                    let message = "warning: found restoring folder but no uuid: \(folder.name!)"
                    SDLog(message)
                    let e = NSError(domain: SDErrorSyncDomain, code: SDSyncError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    SDErrorHandlerReport(e)
                    continue
            }
            
            
            
            let alert = NSAlert()
            alert.addButton(withTitle: "No")
            alert.addButton(withTitle: "Yes")
            
            alert.messageText = "Continue restore?"
            alert.informativeText = "SafeDrive could not finish restoring the \(folder.name!) folder, would you like to continue now? \n\nWarning: If you decline, the folder will resume syncing to the server, which may result in data loss"
            alert.alertStyle = .informational
            
            alert.beginSheetModal(for: NSApp.mainWindow!) { (response) in
                
                switch response {
                case NSAlertFirstButtonReturn:
                    try! realm.write {
                        folder.syncing = false
                        folder.restoring = false
                    }
                    return
                case NSAlertSecondButtonReturn:
                    try! realm.write {
                        folder.syncing = false
                        folder.restoring = false
                    }
                    self.queueSyncJob(uniqueClientID, folderID: UInt64(folder.uniqueID), direction: .reverse, type: type, name: currentSyncUUID, destination: nil)
                    break
                default:
                    return
                }
            }
        }
    }
    
    func queueSyncJob(_ uniqueClientID: String, folderID: UInt64, direction: SyncDirection, type: SyncType, name: String, destination: URL?) {
        syncDispatchQueue.sync(execute: {() -> Void in
            let syncEvent = SyncEvent(uniqueClientID: uniqueClientID, folderID: folderID, direction: direction, type: type, name: name, destination: destination)
            self.sync(syncEvent)
        })
    }
    
    func stop() {
        self.running = false
    }
    
    func cancel(_ uniqueID: UInt64, completion: @escaping () -> Void) {
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
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            SDLog("Queued sync job \(syncEvent)")

            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            guard let _ = self.email,
                  let localPassword = self.password,
                  let localInternalUserName = self.internalUserName,
                  let localPort = self.remotePort,
                  let localHost = self.remoteHost else {
                SDLog("credentials unavailable, cancelling sync")
                return
            }
            
            let uniqueClientID = syncEvent.uniqueClientID
            let folderID = syncEvent.folderID
            var isRestore: Bool = false
            if syncEvent.direction == .reverse {
                isRestore = true
            }
            
            let syncController = SyncController()


            let name = syncEvent.name.lowercased()
            
            guard let folder = realm.objects(SyncFolder.self).filter("uniqueID == \(folderID) AND uniqueClientID == '\(uniqueClientID)'").first else {
                SDLog("failed to get sync folder for machine from realm!!!")
                return
            }
            
            let folderName: String = folder.name!
            
            let localFolder: URL = folder.url! as URL
            
            if folder.syncing {
                SDLog("Sync for \(folder.name!) already in progress, cancelling")
                //NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSyncAlreadyRunning userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
                return
            }
            

            if folder.encrypted {
                if isRestore {
                    guard let session = realm.objects(PersistedSyncSession.self).filter("name == \"\(name)\"").first else {
                        SDLog("failed to get sync session from realm!!!")
                        return
                    }
                
                    syncController.spaceNeeded = UInt64(session.size)
                }
                
            } else {
                let host = Host()
                let machineName = host.localizedName!
                
                let defaultFolder: URL = URL(string: SDDefaultServerPath)!
                let machineFolder: URL = defaultFolder.appendingPathComponent(machineName, isDirectory: true)
                let remoteFolder: URL = machineFolder.appendingPathComponent(folderName, isDirectory: true)
                var urlComponents: URLComponents = URLComponents()
                urlComponents.user = localInternalUserName
                urlComponents.host = localHost
                urlComponents.path = remoteFolder.path
                urlComponents.port = Int(localPort)
                let remote: URL = urlComponents.url!
                
                syncController.serverURL = remote
                syncController.password = localPassword

                syncController.spaceNeeded = 0

            }
            
            
            let syncDate = Date()
            
            try! realm.write {
                realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": true, "restoring": isRestore, "currentSyncUUID": name, "lastSyncUUID": name], update: true)
                realm.create(SyncTask.self, value: ["syncFolder": folder, "syncDate": syncDate, "uuid": name], update: true)
            }

            syncController.uniqueID = UInt64(folder.uniqueID)
            syncController.encrypted = folder.encrypted
            syncController.uuid = name
            syncController.localURL = localFolder
            if let destination = syncEvent.destination {
                syncController.destination = destination
            }
            
            syncController.restore = isRestore
            
            DispatchQueue.main.sync(execute: {() -> Void in
                self.syncControllers.append(syncController)
            })
            
            syncController.startSyncTask(progress: { (_, _, _, percent, bandwidth) in
                // use for updating sync progress
                // WARNING: this block may be called more often than once per second on a background serial queue, DO NOT block it for long
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                try! realm.write {
                    realm.create(SyncTask.self, value: ["uuid": name, "progress": percent, "bandwidth": bandwidth], update: true)
                }
            }, issue: { (message) in
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                guard let task = realm.objects(SyncTask.self).filter("uuid == '\(name)'").last else {
                    SDLog("failed to get sync folder for machine from realm!!!")
                    return
                }
                var oldMessages = task.message != nil ? task.message! : ""
                
                oldMessages.append(message)
                oldMessages.append("\n")
                try! realm.write {
                    realm.create(SyncTask.self, value: ["uuid": name, "message": oldMessages], update: true)
                }
            }, success: { (_: URL) -> Void in
                SDLog("Sync finished for \(folderName)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "restoring": false, "currentSyncUUID": NSNull(), "lastSyncUUID": name], update: true)
                    let duration = NSDate().timeIntervalSince(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": name, "success": true, "duration": duration, "progress": 0.0, "bandwidth": ""], update: true)
                }
                if let index = self.syncControllers.index(of: syncController) {
                    self.syncControllers.remove(at: index)
                }
            }, failure: { (_: URL, error: Swift.Error?) -> Void in
                SDErrorHandlerReport(error)
                SDLog("Sync failed for \(folderName): \(error!.localizedDescription)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "restoring": false, "currentSyncUUID": NSNull(), "lastSyncUUID": name], update: true)
                    let duration = NSDate().timeIntervalSince(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": name, "success": false, "duration": duration, "message": error!.localizedDescription, "progress": 0.0, "bandwidth": ""], update: true)
                }
                if let index = self.syncControllers.index(of: syncController) {
                    self.syncControllers.remove(at: index)
                }
                
            })
        })
    }
}

extension SyncScheduler: SDAccountProtocol {
    
    func didSignIn(notification: Foundation.Notification) {
        guard let currentUser = notification.object as? User else {
            SDLog("API contract invalid: didSignIn in SyncScheduler")
            return
        }
        self.email = currentUser.email
        self.password = currentUser.password
    }
    
    func didSignOut(notification: Foundation.Notification) {
        for syncController in self.syncControllers {
            syncController.stopSyncTask {
                return
            }
        }
        
        self.email = nil
        self.password = nil
        self.uniqueClientID = nil
        self.internalUserName = nil
        self.remoteHost = nil
        self.remotePort = nil
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        guard let accountStatus = notification.object as? AccountStatus else {
            SDLog("API contract invalid: didReceiveAccountStatus in SyncScheduler")
            return
        }
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        guard let _ = notification.object as? AccountDetails else {
            SDLog("API contract invalid: didReceiveAccountDetails in SyncScheduler")
            return
        }
    }
}

extension SyncScheduler: SDApplicationEventProtocol {
    func applicationDidConfigureRealm(notification: Notification) {
        
        guard let realm = try? Realm() else {
            //let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open Realm database, this is a fatal error", comment: "")]
            //throw NSError(domain: SDErrorSyncDomain, code: SDDatabaseError.openFailed.rawValue, userInfo: errorInfo)
            return
        }
        
        self.realm = realm
    }
    
    func applicationDidConfigureClient(notification: Notification) {
        guard let uniqueClientID = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in SyncScheduler")
            
            return
        }
        
        self.uniqueClientID = uniqueClientID
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        guard let _ = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in SyncScheduler")
            
            return
        }
    }
}
