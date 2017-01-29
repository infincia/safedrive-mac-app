
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class SyncManagerTableRowView: NSTableRowView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        // no background
    }
}
