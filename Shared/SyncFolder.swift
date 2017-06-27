
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable sorted_imports

import Foundation
import Realm
import RealmSwift

class SyncFolder: Object {
    
    dynamic var name: String?
    dynamic var path: String?
    dynamic var uniqueID: Int32 = 0
    
    // whether the folder should be allowed to sync, is it disabled/missing etc
    dynamic var active: Bool = true
    
    // whether the folder is currently syncing
    dynamic var syncing: Bool = false

    // whether the folder is currently restoring
    dynamic var restoring: Bool = false
    
    dynamic var currentSyncUUID: String?
    dynamic var lastSyncUUID: String?

    dynamic var syncFrequency: String = "daily"
    
    dynamic var added: Date?
    
    dynamic var syncTime: Date?
    
    dynamic var uniqueClientID: String?
    
    dynamic var encrypted: Bool = false

    
    var url: URL? {
        if let path = self.path {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }

    convenience required init(name: String, url: URL, uniqueID: Int32, encrypted: Bool) {
        self.init()
        self.name = name
        self.path = url.path
        self.uniqueID = uniqueID
        
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        let calendar = Calendar.current
        self.syncTime = calendar.date(from: components)
        
        self.encrypted = encrypted
    }
    
    convenience required init(name: String, path: String, uniqueID: Int32, encrypted: Bool) {
        self.init()
        self.name = name
        self.path = path
        self.uniqueID = uniqueID
        
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        let calendar = Calendar.current
        self.syncTime = calendar.date(from: components)
        
        self.encrypted = encrypted
    }
    
    override static func primaryKey() -> String? {
        return "uniqueID"
    }
    
    public func exists() -> Bool {
        guard let folderPath = self.path else {
            return false
        }
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: folderPath, isDirectory:&isDirectory) {
            if isDirectory.boolValue {
                return true
            }
        }
        return false
    }
    
// Specify properties to ignore (Realm won't persist these)
    
//  override static func ignoredProperties() -> [String] {
//    return []
//  }
}
