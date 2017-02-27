
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class OpenFileWarningTableCellView: NSTableCellView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    @IBOutlet var name: NSTextField!
    @IBOutlet var icon: NSImageView!
    @IBOutlet var pid: NSTextField!
    @IBOutlet var closeApp: NSButton!
    
    var processPID: Int!
    var processName: String!
    
}
