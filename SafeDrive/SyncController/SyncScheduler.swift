
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

import Crashlytics

import Realm
import RealmSwift

import SwiftDate

enum SyncDirection {
    case Forward
    case Reverse
}

struct SyncEvent {
    let uniqueClientID: String
    let folderID: Int
    let direction: SyncDirection
}

class SyncScheduler {

    static let sharedSyncScheduler = SyncScheduler()

    private let accountController = AccountController.sharedAccountController

    private var syncControllers = [SDSyncController]()

    private var _running = false

    private let runQueue = dispatch_queue_create("io.safedrive.runQueue", DISPATCH_QUEUE_CONCURRENT)

    var running: Bool {
        get {
            var r: Bool?
            dispatch_sync(runQueue) {
                r = self._running
            }
            return r!
        }
        set (newValue) {
            dispatch_barrier_sync(runQueue) {
                self._running = newValue
            }
        }
    }

    private var syncQueue = [SyncEvent]()

    private var syncDispatchQueue = dispatch_queue_create("io.safedrive.SyncScheduler.SyncQueue", DISPATCH_QUEUE_SERIAL)

    let dbURL: NSURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db")!.URLByAppendingPathComponent("sync.realm")!

    func syncSchedulerLoop(uniqueClientID: String) throws {

        guard let realm = try? Realm() else {
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open Realm database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorSyncDomain, code: SDDatabaseError.OpenFailed.rawValue, userInfo: errorInfo)
        }

        guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(uniqueClientID)'").last else {
            return
        }

        /*
            Check for folders that are supposedly restoring, which means SafeDrive was killed or crashed while a restore
            was in progress.

            We have no other option but to display a warning when this happens, rsync will have exited in a half-synced state.

        */

        for folder in realm.objects(SyncFolder).filter("restoring == true AND machine == %@", currentMachine) {
            let alert = NSAlert()
            alert.addButtonWithTitle("No")
            alert.addButtonWithTitle("Yes")

            alert.messageText = "Continue restore?"
            alert.informativeText = "SafeDrive could not finish restoring the \(folder.name!) folder, would you like to continue now? \n\nWarning: If you decline, the folder will resume syncing to the server, which may result in data loss"
            alert.alertStyle = .Informational

            alert.beginSheetModalForWindow(NSApp.mainWindow!) { (response) in

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
                    self.queueSyncJob(uniqueClientID, folderID: folder.uniqueID, direction: .Reverse)
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
            let syncFolders = realm.objects(SyncFolder).filter("restoring == false AND machine == %@", currentMachine)
            syncFolders.setValue(false, forKey: "syncing")
        }
        SDLog("Sync scheduler running")

        while self.running {

            autoreleasepool {
                realm.refresh()
                realm.invalidate()

                guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(uniqueClientID)'").last else {
                    NSThread.sleepForTimeInterval(1)
                    // NOTE: this returns from the autoreleasepool closure and functions as a "continue" statement
                    //       it does NOT return from syncSchedulerLoop()
                    return
                }

                let currentDate = NSDate()

                let components = NSDateComponents()
                components.hour = currentDate.hour
                components.minute = currentDate.minute
                let calendar = NSCalendar.currentCalendar()
                let syncDate = calendar.dateFromComponents(components)!

                var folders = [SyncFolder]()

                // only trigger in the first minute of each hour
                // this would run twice per hour if we did not sleep thread for 60 seconds


                if currentDate.minute == 0 {
                    // first minute of each hour for hourly syncs
                    // NOTE: this scheduler ignores syncTime on purpose, hourly syncs always run at xx:00
                    let hourlyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'hourly' AND syncing == false AND machine == %@", currentMachine)
                    folders.appendContentsOf(hourlyFolders)
                }


                if currentDate.day == 1 {
                    // first of the month for monthly syncs
                    let monthlyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'monthly' AND syncing == false AND machine == %@ AND syncTime == %@", currentMachine, syncDate)
                    folders.appendContentsOf(monthlyFolders)
                }


                if currentDate.weekday == 1 {
                    // first day of the week for weekly syncs
                    let weeklyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'weekly' AND syncing == false AND machine == %@ AND syncTime == %@", currentMachine, syncDate)
                    folders.appendContentsOf(weeklyFolders)
                }


                // daily syncs at arbitrary times based on syncTime property
                let dailyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'daily' AND syncing == false AND machine == %@ AND syncTime == %@", currentMachine, syncDate)
                folders.appendContentsOf(dailyFolders)



                for folder in folders {
                    let folderID = folder.uniqueID
                    self.queueSyncJob(uniqueClientID, folderID: folderID, direction: .Forward)
                }

                // keep loop in sync with clock time to the next minute
                let sleepSeconds = 60 - currentDate.second
                NSThread.sleepForTimeInterval(Double(sleepSeconds))

            }
        }
    }

    func queueSyncJob(uniqueClientID: String, folderID: Int, direction: SyncDirection) {
        dispatch_sync(syncDispatchQueue, {() -> Void in
            let syncEvent = SyncEvent(uniqueClientID: uniqueClientID, folderID: folderID, direction: direction)
            self.sync(syncEvent)
        })
    }

    func stop() {
        self.running = false
    }

    func cancel(uniqueID: Int, completion: SDSuccessBlock) {
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

    private func sync(syncEvent: SyncEvent) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in

            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }

            let uniqueClientID = syncEvent.uniqueClientID
            let folderID = syncEvent.folderID
            var isRestore: Bool = false
            if syncEvent.direction == .Reverse {
                isRestore = true
            }

            guard let currentMachine = realm.objects(Machine).filter("uniqueClientID == '\(uniqueClientID)'").last else {
                SDLog("failed to get current machine from realm!!!")
                return
            }

            guard let folder = realm.objects(SyncFolder).filter("uniqueID == \(folderID) AND machine == %@", currentMachine).first else {
                SDLog("failed to get sync folder for machine from realm!!!")
                return
            }

            if folder.syncing {
                SDLog("Sync for \(folder.name!) already in progress, cancelling")
                //NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSyncAlreadyRunning userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
                return
            }
            let uuid = NSUUID()
            let syncDate = NSDate()
            try! realm.write {
                realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": true, "restoring": isRestore], update: true)
                let syncTask = SyncTask(syncFolder: folder, syncDate: syncDate, uuid: uuid.UUIDString)
                realm.add(syncTask)
            }
            let folderName: String = folder.name!

            let localFolder: NSURL = folder.url!

            let defaultFolder: NSURL = NSURL(string: SDDefaultServerPath)!
            let machineFolder: NSURL = defaultFolder.URLByAppendingPathComponent(folder.machine!.name!, isDirectory: true)!
            let remoteFolder: NSURL = machineFolder.URLByAppendingPathComponent(folderName, isDirectory: true)!
            let urlComponents: NSURLComponents = NSURLComponents()
            urlComponents.user = self.accountController.internalUserName
            urlComponents.host = self.accountController.remoteHost
            urlComponents.path = remoteFolder.path
            urlComponents.port = self.accountController.remotePort
            let remote: NSURL = urlComponents.URL!

            let syncController = SDSyncController()
            syncController.uniqueID = folder.uniqueID

            dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                self.syncControllers.append(syncController)
            })
            SDLog("Syncing from \(localFolder.path!)/ to \(remote.path!)/")
            syncController.startSyncTaskWithLocalURL(localFolder, serverURL: remote, password: self.accountController.password, restore: isRestore, progress: { (percent, bandwidth) in
                // use for updating sync progress
                // WARNING: this block may be called more often than once per second on a background serial queue, DO NOT block it for long
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }

                try! realm.write {
                    realm.create(SyncTask.self, value: ["uuid": uuid.UUIDString, "progress": percent, "bandwidth": bandwidth], update: true)
                }
            }, success: { (syncURL: NSURL, error: NSError?) -> Void in
                SDLog("Sync finished for \(localFolder.path!)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }

                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "restoring": false], update: true)
                    let duration = NSDate().timeIntervalSinceDate(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": uuid.UUIDString, "success": true, "duration": duration], update: true)
                }
                if let index = self.syncControllers.indexOf(syncController) {
                    self.syncControllers.removeAtIndex(index)
                }
            }, failure: { (syncURL: NSURL, error: NSError?) -> Void in
                SDErrorHandlerReport(error)
                SDLog("Sync failed for \(localFolder.path!): \(error!.localizedDescription)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "restoring": false], update: true)
                    let duration = NSDate().timeIntervalSinceDate(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": uuid.UUIDString, "success": false, "duration": duration, "message": error!.localizedDescription], update: true)
                }
                if let index = self.syncControllers.indexOf(syncController) {
                    self.syncControllers.removeAtIndex(index)
                }

            })
        })
    }
}
