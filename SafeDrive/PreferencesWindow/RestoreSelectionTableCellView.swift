
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable private_outlet

import Cocoa
import FontAwesomeIconFactory
import SafeDriveSDK

class RestoreSelectionTableCellView: NSTableCellView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    @IBOutlet var date: NSTextField!
    @IBOutlet var size: NSTextField!
    @IBOutlet var folder: NIKFontAwesomeImageView!

    var session: SDKSyncSession!
}
