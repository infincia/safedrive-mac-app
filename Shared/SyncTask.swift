
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class SyncTask: Object {
    dynamic var syncFolder: SyncFolder?
    dynamic var syncDate: NSDate?
}