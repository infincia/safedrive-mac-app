
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class SyncFolder: Object {
    
    dynamic var name: String?
    dynamic var path: String?
    dynamic var uniqueID: Int32 = 0
    dynamic var syncing: Bool = false
    dynamic var restoring: Bool = false
    
    dynamic var currentSyncUUID: String?

    dynamic var syncFrequency: String = "daily"
    
    dynamic var added: Date?
    
    dynamic var syncTime: Date?
    
    dynamic var machine: Machine?
    
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
    
    class func hasConflictingFolderRegistered<S: Sequence>(_ testFolder: String, syncFolders: S) -> Bool where S.Iterator.Element == SyncFolder {
        let testURL = URL(fileURLWithPath: testFolder, isDirectory: true)
        for folder in syncFolders {
            let registeredPath: String = folder.url!.absoluteString
            let options: NSString.CompareOptions = [.anchored, .caseInsensitive]
            // check if testFolder is a parent or subdirectory of an existing folder
            if testURL.absoluteString.range(of: registeredPath, options: options) != nil {
                return true
            }
            if registeredPath.range(of: testURL.absoluteString, options: options) != nil {
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
