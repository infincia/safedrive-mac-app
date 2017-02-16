
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class PersistedSyncSession: Object {
    dynamic var name: String?
    
	dynamic var size: Int64 = 0
    
	dynamic var syncDate: Date?
    
	dynamic var folderId: Int64 = 0
    
    dynamic var sessionId: Int64 = 0
    
    convenience required init(syncDate: Date, size: Int64, name: String, folderId: Int64, sessionId: Int64) {
        self.init()
        self.syncDate = syncDate
        self.name = name
        self.size = size
        self.folderId = folderId
        self.sessionId = sessionId
    }
    
    override static func primaryKey() -> String? {
        return "sessionId"
    }
}
