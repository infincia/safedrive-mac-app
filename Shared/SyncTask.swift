
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class SyncTask: Object {
    dynamic var syncFolder: SyncFolder?
    dynamic var syncDate: NSDate?
}