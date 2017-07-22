
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable private_outlet

import Cocoa
import FontAwesomeIconFactory

class SyncManagerTableCellView: NSTableCellView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    @IBOutlet var lockButton: NIKFontAwesomeButton!
    @IBOutlet var addButton: NSButton!
    @IBOutlet var removeButton: NSButton!
    @IBOutlet var syncNowButton: NIKFontAwesomeButton!
    @IBOutlet var restoreNowButton: NIKFontAwesomeButton!
    @IBOutlet var syncStatus: NSProgressIndicator!
    var representedSyncItem: AnyObject?
}
