
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

import Realm
import RealmSwift

import SwiftDate

class SyncScheduler {
    
    static let sharedSyncScheduler = SyncScheduler()
    
    let accountController = AccountController.sharedAccountController

    var syncControllers = [SDSyncController]()
    
    var reachabilityManager: AFNetworkReachabilityManager
    
    var running: Bool = true
    
    var syncQueue = [Int]()
    
    let dbURL: NSURL = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.io.safedrive.db")!.URLByAppendingPathComponent("sync.realm")
    
    init() {
        self.reachabilityManager = AFNetworkReachabilityManager(forDomain: SDAPIDomainTesting)
        self.reachabilityManager.setReachabilityStatusChangeBlock { (status: AFNetworkReachabilityStatus) -> Void in
            switch status {
            case .Unknown:
                print("AFNetworkReachabilityStatusUnknown")
            case .NotReachable:
                print("AFNetworkReachabilityStatusNotReachable")
            case .ReachableViaWWAN:
                print("AFNetworkReachabilityStatusReachableViaWWAN")
            case .ReachableViaWiFi:
                print("AFNetworkReachabilityStatusReachableViaWiFi")
            }
        }
        self.reachabilityManager.startMonitoring()
    }

    
    func syncSchedulerLoop() throws {
        var config = Realm.Configuration()
        
        config.path = dbURL.path
        
        Realm.Configuration.defaultConfiguration = config
        
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
            realm.refresh()

            let currentDate = NSDate()
            //let folders = realm.objects(SyncFolder).filter("syncing == false")
            //print("Checking \(folders.count) for sync: \(folders)")
            
            var folders: Results<SyncFolder>
            
            // only trigger in the first minute of each hour
            // this would run twice per hour if we did not sleep thread for 60 seconds
            if currentDate.minute == 0 {
                if currentDate.day == 1 {
                    // first of the month for monthly syncs
                    folders = realm.objects(SyncFolder).filter("syncFrequency == 'monthly' AND syncing == false")
                }
                else if currentDate.weekday == 1 {
                    // first day of the week for weekly syncs
                    folders = realm.objects(SyncFolder).filter("syncFrequency == 'weekly' AND syncing == false")
                }
                else if currentDate.hour == 0 {
                    // first hour of the day for daily syncs
                    folders = realm.objects(SyncFolder).filter("syncFrequency == 'daily' AND syncing == false")
                }
                else {
                    // default, check for hourly syncs
                    folders = realm.objects(SyncFolder).filter("syncFrequency == 'hourly' AND syncing == false")
                }
            }
            else {
                // check for minute syncs
                folders = realm.objects(SyncFolder).filter("syncFrequency == 'minute' AND syncing == false")
            }
            if self.reachabilityManager.reachableViaWiFi {
                for folder in folders {
                    let uniqueID = folder.uniqueID
                    SDLog("Sync job added to queue for folder: \(folder.name)")
                    dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                        self.syncQueue.append(uniqueID)
                    })
                }
            }
            else {
                //SDLog("No WiFi/Ethernet connectivity, deferring \(folders.count) folders")
            }

            NSThread.sleepForTimeInterval(60)
        }
    }
    
    func syncRunLoop() {
        while self.running {
            if self.accountController.signedIn {
                var uniqueID: Int?
                dispatch_sync(dispatch_get_main_queue(), {() -> Void in
                    uniqueID = self.syncQueue.popLast()
                })
                guard let folderID = uniqueID else {
                    //SDLog("Sync failed to pop")
                    NSThread.sleepForTimeInterval(1)
                    continue
                }
                //SDLog("Sync started for \(uniqueID)")

                self.sync(folderID)
            }
            else {
                //SDLog("Sync deferred until sign-in")
            }
            NSThread.sleepForTimeInterval(1)
        }
    }
    
    
    func sync(folderID: Int) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
            
            let realm = try! Realm()
            
            guard let folder = realm.objects(SyncFolder).filter("uniqueID == \(folderID)").first else {
                return
            }
            
            if folder.syncing {
                SDLog("Sync for \(folder.name) already in progress, cancelling")
                //NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSyncAlreadyRunning userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
                return
            }
            
            try! realm.write {
                realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": true], update: true)
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
                let realm = try! Realm()
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false, "lastSync": NSDate()], update: true)
                }
                
                self.syncControllers.removeAtIndex(self.syncControllers.indexOf(syncController)!)
            }, failure: { (syncURL: NSURL, error: NSError?) -> Void in
                SDErrorHandlerReport(error)
                SDLog("Sync failed for \(localFolder): \(error!.localizedDescription)")
                let realm = try! Realm()
                try! realm.write {
                    realm.create(SyncFolder.self, value: ["uniqueID": folderID, "syncing": false], update: true)
                }
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("Error", comment: "")
                alert.informativeText = error!.localizedDescription
                alert.addButtonWithTitle(NSLocalizedString("OK", comment: ""))
                alert.runModal()
                    
                self.syncControllers.removeAtIndex(self.syncControllers.indexOf(syncController)!)
                    
            })
        })
    }
}