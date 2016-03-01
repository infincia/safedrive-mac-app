
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class Machine: Object {
    
    dynamic var name: String?
    dynamic var uniqueClientID: String?

    convenience required init(name: String, uniqueClientID: String) {
        self.init()
        self.name = name
        self.uniqueClientID = uniqueClientID
    }
    
    override static func primaryKey() -> String? {
        return "uniqueClientID"
    }
}
