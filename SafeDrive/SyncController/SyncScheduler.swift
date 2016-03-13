
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

import Crashlytics

import Realm
import RealmSwift

import SwiftDate

import Alamofire

class SyncScheduler {
    
    static let sharedSyncScheduler = SyncScheduler()
    
    private let accountController = AccountController.sharedAccountController

    private var syncControllers = [SDSyncController]()
    
    private var reachabilityManager = NetworkReachabilityManager(host: SDAPIDomainTesting)

    private var running: Bool = true
    
    private var syncQueue = [Int]()
    
    private var syncDispatchQueue = dispatch_queue_create("io.safedrive.SyncScheduler.SyncQueue", DISPATCH_QUEUE_SERIAL);
    
    let dbURL: NSURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db")!.URLByAppendingPathComponent("sync.realm")
    
    init() {
        self.reachabilityManager?.listener = { status in
            switch status {
            case .Unknown:
                print("ReachabilityStatusUnknown")
            case .NotReachable:
                print("ReachabilityStatusNotReachable")
            case .Reachable(.WWAN):
                print("ReachabilityStatusWWAN")
            case .Reachable(.EthernetOrWiFi):
                print("ReachabilityStatusEthernetOrWiFi")
            }
        }
        
        self.reachabilityManager?.startListening()
    }

    
    func syncSchedulerLoop() throws {
        
        guard let realm = try? Realm() else {
            let errorInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: NSLocalizedString("Cannot open Realm database, this is a fatal error", comment: "")]
            throw NSError(domain: SDErrorSyncDomain, code: SDSystemError.Unknown.rawValue, userInfo: errorInfo)
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
            let syncFolders = realm.objects(SyncFolder)
            syncFolders.setValue(false, forKey: "syncing")
        }
        SDLog("Sync scheduler starting")

        while self.running {
            if !self.accountController.signedIn {
                NSThread.sleepForTimeInterval(1)
                continue
            }
            autoreleasepool {
                realm.refresh()
                
                let currentDate = NSDate()
                //let folders = realm.objects(SyncFolder).filter("syncing == false")
                //print("Checking \(folders.count) for sync: \(folders)")
                
                var folders = [SyncFolder]()
                
                // only trigger in the first minute of each hour
                // this would run twice per hour if we did not sleep thread for 60 seconds
                if currentDate.minute == 0 {
                    
                    if currentDate.hour == 0 {
                        if currentDate.day == 1 {
                            // first of the month for monthly syncs
                            //print("Monthly sync")
                            let monthlyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'monthly' AND syncing == false")
                            folders.appendContentsOf(monthlyFolders)
                        }
                        if currentDate.weekday == 1 {
                            //print("Weekly sync")
                            // first day of the week for weekly syncs
                            let weeklyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'weekly' AND syncing == false")
                            folders.appendContentsOf(weeklyFolders)
                        }
                        //print("Daily sync")
                        // first hour of the day for daily syncs
                        let dailyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'daily' AND syncing == false")
                        folders.appendContentsOf(dailyFolders)
                    }
                    // default, check for hourly syncs
                    //print("Hourly sync")
                    let hourlyFolders = realm.objects(SyncFolder).filter("syncFrequency == 'hourly' AND syncing == false")
                    folders.appendContentsOf(hourlyFolders)
                    
                }
                else {
                    // check for minute syncs
                    let minuteFolders = realm.objects(SyncFolder).filter("syncFrequency == 'minute' AND syncing == false")
                    folders.appendContentsOf(minuteFolders)
                }
                if self.reachabilityManager!.isReachableOnEthernetOrWiFi {
                    for folder in folders {
                        let uniqueID = folder.uniqueID
                        SDLog("Sync job added to queue for folder: \(folder.name)")
                        self.queueSyncJob(uniqueID)
                    }
                }
                else {
                    //SDLog("No WiFi/Ethernet connectivity, deferring \(folders.count) folders")
                }
                
                NSThread.sleepForTimeInterval(60)
                
            }
        }
    }
    
    func queueSyncJob(uniqueID: Int) {
        dispatch_sync(syncDispatchQueue, {() -> Void in
            self.syncQueue.insert(uniqueID, atIndex: 0)
        })
    }
    
    private func dequeueSyncJob() -> Int? {
        var uniqueID: Int?
        dispatch_sync(syncDispatchQueue, {() -> Void in
            uniqueID = self.syncQueue.popLast()
        })
        return uniqueID
    }
    
    func syncRunLoop() {
        while self.running {
            if self.accountController.signedIn {
                guard let uniqueID = self.dequeueSyncJob() else {
                    NSThread.sleepForTimeInterval(1)
                    continue
                }
                self.sync(uniqueID)
            }
            else {
                //SDLog("Sync deferred until sign-in")
            }
            NSThread.sleepForTimeInterval(1)
        }
    }
    
    
    private func sync(folderID: Int) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
            
            guard let realm = try? Realm() else {
                SDLog("failed to create realm!!!")
                Crashlytics.sharedInstance().crash()
                return
            }
            
            guard let folder = realm.objects(SyncFolder).filter("uniqueID == \(folderID)").first else {
                return
            }
            
            if folder.syncing {
                SDLog("Sync for \(folder.name) already in progress, cancelling")
                //NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSyncAlreadyRunning userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
                return
            }
            let uuid = NSUUID()
            let syncDate = NSDate()
            try! realm.write {
                realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": true], update: true)
                let syncTask = SyncTask(syncFolder: folder, syncDate: syncDate, uuid: uuid.UUIDString)
                realm.add(syncTask)
            }
            let folderName: String = folder.name!
            
            let localFolder: NSURL = folder.url!
            SDLog("Sync started for \(localFolder)")

            let defaultFolder: NSURL = NSURL(string: SDDefaultServerPath)!
            let machineFolder: NSURL = defaultFolder.URLByAppendingPathComponent(NSHost.currentHost().localizedName!, isDirectory: true)
            let remoteFolder: NSURL = machineFolder.URLByAppendingPathComponent(folderName, isDirectory: true)
            let urlComponents: NSURLComponents = NSURLComponents()
            urlComponents.user = self.accountController.internalUserName
            urlComponents.host = self.accountController.remoteHost
            urlComponents.path = remoteFolder.path
            urlComponents.port = self.accountController.remotePort
            let remote: NSURL = urlComponents.URL!
            
            let syncController = SDSyncController()
            dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                self.syncControllers.append(syncController)
            })
            syncController.startSyncTaskWithLocalURL(localFolder, serverURL: remote, password: self.accountController.password, restore: false, success: { (syncURL: NSURL, error: NSError?) -> Void in
                SDLog("Sync finished for \(localFolder)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false], update: true)
                    let duration = NSDate().timeIntervalSinceDate(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": uuid.UUIDString, "success": true, "duration": duration], update: true)
                }
                
                self.syncControllers.removeAtIndex(self.syncControllers.indexOf(syncController)!)
            }, failure: { (syncURL: NSURL, error: NSError?) -> Void in
                SDErrorHandlerReport(error)
                SDLog("Sync failed for \(localFolder): \(error!.localizedDescription)")
                guard let realm = try? Realm() else {
                    SDLog("failed to create realm!!!")
                    Crashlytics.sharedInstance().crash()
                    return
                }
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false], update: true)
                    let duration = NSDate().timeIntervalSinceDate(syncDate)
                    realm.create(SyncTask.self, value: ["uuid": uuid.UUIDString, "success": false, "duration": duration, "message": error!.localizedDescription], update: true)
                }
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error syncing folder", comment: "")
                alert.informativeText = NSLocalizedString("This error has been reported to SafeDrive, please contact support for further help", comment: "")
                alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
                alert.runModal()
                    
                self.syncControllers.removeAtIndex(self.syncControllers.indexOf(syncController)!)
                    
            })
        })
    }
}