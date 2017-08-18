
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable force_unwrapping

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
            return self.level == NSWindow.Level.modalPanel// Int(CGWindowLevelForKey(CGWindowLevelKey.statusWindow))
        }
        set (newValue) {
            if newValue {
                self.level = NSWindow.Level.modalPanel
            } else {
                self.level = NSWindow.Level.normal
            }
        }
    }
    
    override func awakeFromNib() {
        self.isOpaque = false
        self.closeButton.image = NSImage(named: NSImage.Name.stopProgressTemplate)
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
    
    @objc func close(_ sender: AnyObject?) {
        if let delegate = self.delegate {
            if delegate.responds(to: #selector(delegate.windowShouldClose(_:))) {
                if delegate.windowShouldClose!(self) {
                    self.windowController!.close()
                }
            }
        }
    }
}
