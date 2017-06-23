
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

class SyncTask: Object {
    dynamic var syncFolder: SyncFolder?
    
    dynamic var uuid: String?
    
    // start of sync
    dynamic var syncDate: Date?
    
    // set to true only if sync finishes without error
    dynamic var success: Bool = false
    
    // will be NSDate() - syncDate, calculated at time of success or failure
    dynamic var duration: TimeInterval = 0
    
    // use for error messages if sync fails
    dynamic var message: String?
    
    // sync progress in percentage
    dynamic var progress: Double = 0.0
    
    // sync bandwidth
    dynamic var bandwidth: String = "0.00kB/s"
    
    convenience required init(syncFolder: SyncFolder, syncDate: Date, uuid: String) {
        self.init()
        self.syncFolder = syncFolder
        self.syncDate = syncDate
        self.uuid = uuid
    }
    
    override static func primaryKey() -> String? {
        return "uuid"
    }
}
