
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
            let syncFolders = realm.objects(SyncFolder.self).filter("machine == %@", currentMachine)
            syncFolders.setValue(false, forKey: "syncing")
            syncFolders.setValue(false, forKey: "restoring")
            syncFolders.setValue(nil, forKey: "currentSyncUUID")
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
                    self.queueSyncJob(uniqueClientID, folderID: UInt64(folderID), direction: .forward, type: type, name: UUID().uuidString.lowercased(), destination: nil)
                }
                
                // keep loop in sync with clock time to the next minute
                let sleepSeconds = 60 - currentDateComponents.second!
                Thread.sleep(forTimeInterval: Double(sleepSeconds))
                
            }
        }
    }
    
    func restartRestore(_ uniqueClientID: String) throws {
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
            
            let uniqueClientID = syncEvent.uniqueClientID
            let folderID = syncEvent.folderID
            var isRestore: Bool = false
            if syncEvent.direction == .reverse {
                isRestore = true
            }
            
            let syncController = SyncController()


            let name = syncEvent.name.lowercased()
            
            guard let currentMachine = realm.objects(Machine.self).filter("uniqueClientID == '\(uniqueClientID)'").last else {
                SDLog("failed to get current machine from realm!!!")
                return
            }
            
            guard let folder = realm.objects(SyncFolder.self).filter("uniqueID == \(folderID) AND machine == %@", currentMachine).first else {
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
                
                let defaultFolder: URL = URL(string: SDDefaultServerPath)!
                let machineFolder: URL = defaultFolder.appendingPathComponent(folder.machine!.name!, isDirectory: true)
                let remoteFolder: URL = machineFolder.appendingPathComponent(folderName, isDirectory: true)
                var urlComponents: URLComponents = URLComponents()
                urlComponents.user = self.accountController.internalUserName
                urlComponents.host = self.accountController.remoteHost
                urlComponents.path = remoteFolder.path
                urlComponents.port = Int(self.accountController.remotePort!)
                let remote: URL = urlComponents.url!
                
                syncController.serverURL = remote
                syncController.password = self.accountController.password!

                syncController.spaceNeeded = 0

            }
            
            
            let syncDate = Date()
            
            try! realm.write {
                realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": true, "restoring": isRestore, "currentSyncUUID": name], update: true)
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
            
            syncController.startSyncTask(progress: { (total, current, new, percent, bandwidth) in
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
                SDLog("Sync issue: \(message)")
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
