
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class FlatWindowView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

class FlatWindowBackgroundView: NSImageView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}


class FlatWindow: NSWindow {
    var closeButton = NSButton(frame: NSRect.zero)

    var keepOnTop: Bool {
        get {
            return self.level == Int(CGWindowLevelForKey(CGWindowLevelKey.statusWindow))
        }
        set (newValue) {
            self.level = Int(CGWindowLevelForKey(CGWindowLevelKey.statusWindow))
        }
    }
    
    override func awakeFromNib() {
        self.isOpaque = false
        self.closeButton.image = NSImage(named: NSImageNameStopProgressTemplate)
        self.closeButton.isBordered = false
        self.closeButton.setButtonType(.momentaryChange)
        self.closeButton.target = self
        self.closeButton.action = #selector(self.close(_:))
        self.backgroundColor = NSColor.clear
        let offset = 8
        let size = 9
        self.closeButton.frame = NSRect(x: offset + 4, y: Int(self.frame.height) - size - offset, width: size, height: size)
        self.contentView?.addSubview(self.closeButton)
        
    }
    
    override var isMovableByWindowBackground: Bool {
        get {
            return true
        }
        set {
            
        }
    }
    
    override var canBecomeKey: Bool {
        get {
            return true
        }
        set {
            
        }
    }
    
    override var canBecomeMain: Bool {
        get {
            return true
        }
        set {
            
        }
    }
    
    func close(_ sender: AnyObject?) {
        if let delegate = self.delegate {
            if delegate.responds(to: #selector(delegate.windowShouldClose(_:))) {
                if delegate.windowShouldClose!(self) {
                    self.windowController!.close()
                }
            }
        }
    }
}
