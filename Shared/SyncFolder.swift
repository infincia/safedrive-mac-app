
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
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
    
    dynamic var syncTime: NSDate? = nil
    
    dynamic var machine: Machine? = nil
    
    var url: NSURL? {
        if let path = self.path {
            return NSURL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }

    convenience required init(name: String, url: NSURL, uniqueID: Int) {
        self.init()
        self.name = name
        self.path = url.path
        self.uniqueID = uniqueID
        
        let components = NSDateComponents()
        components.hour = 0
        components.minute = 0
        let calendar = NSCalendar.currentCalendar()
        self.syncTime = calendar.dateFromComponents(components)
    }
    
    convenience required init(name: String, path: String, uniqueID: Int) {
        self.init()
        self.name = name
        self.path = path
        self.uniqueID = uniqueID
        
        let components = NSDateComponents()
        components.hour = 0
        components.minute = 0
        let calendar = NSCalendar.currentCalendar()
        self.syncTime = calendar.dateFromComponents(components)
    }
    
    override static func primaryKey() -> String? {
        return "uniqueID"
    }
    
    class func hasConflictingFolderRegistered<S : SequenceType where S.Generator.Element == SyncFolder>(testFolder: String, syncFolders: S) -> Bool {
        let testURL = NSURL(fileURLWithPath: testFolder, isDirectory: true)
        for folder in syncFolders  {
            let registeredPath: String = folder.url!.absoluteString
            let options: NSStringCompareOptions = [.AnchoredSearch, .CaseInsensitiveSearch]
            // check if testFolder is a parent or subdirectory of an existing folder
            if testURL.absoluteString.rangeOfString(registeredPath, options: options) != nil {
                return true
            }
            if registeredPath.rangeOfString(testURL.absoluteString, options: options) != nil {
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
