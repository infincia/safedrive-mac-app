
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class SyncManagerTableCellView: NSTableCellView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @IBOutlet var lockButton: NSButton!
    @IBOutlet var addButton: NSButton!
    @IBOutlet var removeButton: NSButton!
    @IBOutlet var syncNowButton: NSButton!
    @IBOutlet var restoreNowButton: NSButton!
    @IBOutlet var syncStatus: NSProgressIndicator!
    var representedSyncItem: AnyObject?
}
