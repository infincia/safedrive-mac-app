
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
    let folderID: Int32
    let direction: SyncDirection
    let type: SyncType
    let name: UUID
    
}

class SyncScheduler {
    
    static let sharedSyncScheduler = SyncScheduler()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate let accountController = AccountController.sharedAccountController
    
    fileprivate var syncControllers = [SyncController]()
    
    fileprivate var _running = false
    
    fileprivate let runQueue = DispatchQueue(label: "io.safedrive.runQueue", attributes: DispatchQueue.Attributes.concurrent)
    
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
    
    func syncSchedulerLoop(_ uniqueClientID: String) throws {
        
        guard let realm = try? Realm() else {
            let errorInfo: [AnyHashable: Any] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open Realm database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorSyncDomain, code: SDDatabaseError.openFailed.rawValue, userInfo: errorInfo)
        }
        
        guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == '\(uniqueClientID)'").last else {
            return
        }
        
        /*
         Check for folders that are supposedly restoring, which means SafeDrive was killed or crashed while a restore
         was in progress.
         
         We have no other option but to display a warning when this happens, rsync will have exited in a half-synced state.
         
         */
        
        for folder in realm.objects(SyncFolder.self).filter("restoring == true AND machine == %@", currentMachine) {
            let type: SyncType = folder.encrypted ? .encrypted : .unencrypted
            guard let currentSyncUUIDS = folder.currentSyncUUID,
                let currentSyncUUID = UUID(uuidString: currentSyncUUIDS) else {
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
                    self.queueSyncJob(uniqueClientID, folderID: folder.uniqueID, direction: .reverse, type: type, name: currentSyncUUID)
                    break
                default:
                    return
                }
            }
        }
        
        /*
         Reset all sync folders at startup.
         
         Prevents the following issue:
         
         1) App starts syncing FolderA, sets its "syncing" field to true in the database
         2) App exits/crashes during sync
         3) App starts again
         4) App refuses to sync folderA again because the "syncing" field is still set to true
         
         We can do this because sync tasks ALWAYS exit when the app does, so it is not possible for a sync to have been
         running if the app wasn't.
         
         */
        try! realm.write {
            let syncFolders = realm.objects(SyncFolder.self).filter("restoring == false AND machine == %@", currentMachine)
            syncFolders.setValue(false, forKey: "syncing")
        }
        SDLog("Sync scheduler running")
        
        while self.running {
            
            autoreleasepool {
                realm.refresh()
                realm.invalidate()
                
                guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == '\(uniqueClientID)'").last else {
                    Thread.sleep(forTimeInterval: 1)
                    // NOTE: this returns from the autoreleasepool closure and functions as a "continue" statement
                    //       it does NOT return from syncSchedulerLoop()
                    return
                }
                
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
                    let hourlyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'hourly' AND syncing == false AND machine == %@", currentMachine)
                    folders.append(contentsOf: hourlyFolders)
                }
                
                
                if currentDateComponents.day == 1 {
                    // first of the month for monthly syncs
                    let monthlyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'monthly' AND syncing == false AND machine == %@ AND syncTime == %@", currentMachine, syncDate)
                    folders.append(contentsOf: monthlyFolders)
                }
                
                
                if currentDateComponents.weekday == 1 {
                    // first day of the week for weekly syncs
                    let weeklyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'weekly' AND syncing == false AND machine == %@ AND syncTime == %@", currentMachine, syncDate)
                    folders.append(contentsOf: weeklyFolders)
                }
                
                
                // daily syncs at arbitrary times based on syncTime property
                let dailyFolders = realm.objects(SyncFolder.self).filter("syncFrequency == 'daily' AND syncing == false AND machine == %@ AND syncTime == %@", currentMachine, syncDate)
                folders.append(contentsOf: dailyFolders)
                
                
                
                for folder in folders {
                    let folderID = folder.uniqueID
                    let type: SyncType = folder.encrypted ? .encrypted : .unencrypted
                    self.queueSyncJob(uniqueClientID, folderID: folderID, direction: .forward, type: type, name: UUID())
                }
                
                // keep loop in sync with clock time to the next minute
                let sleepSeconds = 60 - currentDateComponents.second!
                Thread.sleep(forTimeInterval: Double(sleepSeconds))
                
            }
        }
    }
    
    func queueSyncJob(_ uniqueClientID: String, folderID: Int32, direction: SyncDirection, type: SyncType, name: UUID) {
        syncDispatchQueue.sync(execute: {() -> Void in
            let syncEvent = SyncEvent(uniqueClientID: uniqueClientID, folderID: folderID, direction: direction, type: type, name: name)
            self.sync(syncEvent)
        })
    }
    
    func stop() {
        self.running = false
    }
    
    func cancel(_ uniqueID: Int32, completion: @escaping () -> Void) {
        for syncController in self.syncControllers {
            if syncController.uniqueID == uniqueID {
                syncController.stopSyncTask() {
                    completion()
                    return
                }
            }
        }
        completion()
    }
    
    fileprivate func sync(_ syncEvent: SyncEvent) {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            let uniqueClientID = syncEvent.uniqueClientID
            let folderID = syncEvent.folderID
            var isRestore: Bool = false
            if syncEvent.direction == .reverse {
                isRestore = true
            }
            let name = syncEvent.name
            
            guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == '\(uniqueClientID)'").last else {
                SDLog("failed to get current machine from realm!!!")
                return
            }
            
            guard let folder = realm.objects(SyncFolder.self).filter("uniqueID == \(folderID) AND machine == %@", currentMachine).first else {
                SDLog("failed to get sync folder for machine from realm!!!")
                return
            }
            
            if folder.syncing {
                SDLog("Sync for \(folder.name!) already in progress, cancelling")
                //NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSyncAlreadyRunning userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
                return
            }
            
            let syncDate = Date()
            try! realm.write {
                realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": true, "restoring": isRestore, "currentSyncUUID": name.uuidString], update: true)
                let syncTask = SyncTask(syncFolder: folder, syncDate: syncDate, uuid: name.uuidString)
                realm.add(syncTask)
            }
            let folderName: String = folder.name!
            
            let localFolder: URL = folder.url! as URL
            
            let defaultFolder: URL = URL(string: SDDefaultServerPath)!
            let machineFolder: URL = defaultFolder.appendingPathComponent(folder.machine!.name!, isDirectory: true)
            let remoteFolder: URL = machineFolder.appendingPathComponent(folderName, isDirectory: true)
            var urlComponents: URLComponents = URLComponents()
            urlComponents.user = self.accountController.internalUserName
            urlComponents.host = self.accountController.remoteHost
            urlComponents.path = remoteFolder.path
            urlComponents.port = self.accountController.remotePort as Int?
            let remote: URL = urlComponents.url!
            
            let syncController = SyncController()
            syncController.uniqueID = folder.uniqueID
            syncController.encrypted = folder.encrypted
            syncController.uuid = name.uuidString
            syncController.localURL = localFolder
            syncController.serverURL = remote
            syncController.password = self.accountController.password!
            syncController.restore = isRestore
            
            DispatchQueue.main.sync(execute: {() -> Void in
                self.syncControllers.append(syncController)
            })
            SDLog("Syncing from \(localFolder.path)/ to \(remote.path)/")
            syncController.startSyncTask(progress: { (percent, bandwidth) in
                // use for updating sync progress
                // WARNING: this block may be called more often than once per second on a background serial queue, DO NOT block it for long
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                try! realm.write {
                    realm.create(SyncTask.self, value: ["uuid": name.uuidString, "progress": percent, "bandwidth": bandwidth], update: true)
                }
            }, success: { (local: URL) -> Void in
                SDLog("Sync finished for \(localFolder.path)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "restoring": false, "currentSyncUUID": NSNull()], update: true)
                    let duration = NSDate().timeIntervalSince(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": name.uuidString, "success": true, "duration": duration], update: true)
                }
                if let index = self.syncControllers.index(of: syncController) {
                    self.syncControllers.remove(at: index)
                }
            }, failure: { (syncURL: URL, error: Swift.Error?) -> Void in
                SDErrorHandlerReport(error)
                SDLog("Sync failed for \(localFolder.path): \(error!.localizedDescription)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "restoring": false, "currentSyncUUID": NSNull()], update: true)
                    let duration = NSDate().timeIntervalSince(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": name.uuidString, "success": false, "duration": duration, "message": error!.localizedDescription], update: true)
                }
                if let index = self.syncControllers.index(of: syncController) {
                    self.syncControllers.remove(at: index)
                }
                
            })
        })
    }
}
