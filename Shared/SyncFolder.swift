
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class SyncFolder: Object {
    
    dynamic var name: String?
    dynamic var path: String?
    dynamic var uniqueID: Int = 0
    dynamic var syncing: Bool = false
    dynamic var syncFrequency: String = "daily"
    
    dynamic var added: NSDate? = nil
    dynamic var lastSync: NSDate? = nil
    
    dynamic var machine: Machine? = nil
    
    var url: NSURL? {
        if let path = self.path {
            return NSURL(fileURLWithPath: path)
        }
        return nil
    }

    convenience required init(name: String, url: NSURL, uniqueID: Int) {
        self.init()
        self.name = name
        self.path = url.absoluteString
        self.uniqueID = uniqueID
    }
    
    convenience required init(name: String, path: String, uniqueID: Int) {
        self.init()
        self.name = name
        self.path = path
        self.uniqueID = uniqueID
    }
    
    override static func primaryKey() -> String? {
        return "uniqueID"
    }
    
    class func hasConflictingFolderRegistered(testFolder: String, syncFolders: Results<SyncFolder>) -> Bool {
        for item: SyncFolder in syncFolders {
            let registeredPath: String = item.path!
            let options: NSStringCompareOptions = [.AnchoredSearch, .CaseInsensitiveSearch]
            // check if testFolder is a parent or subdirectory of an existing folder
            if testFolder.rangeOfString(registeredPath, options: options) != nil {
                return true
            }
            if registeredPath.rangeOfString(testFolder, options: options) != nil {
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
