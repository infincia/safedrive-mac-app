//
//  SyncFailurePopoverView.swift
//  SafeDrive
//
//  Created by steve on 3/23/16.
//  Copyright © 2016 Infincia LLC. All rights reserved.
//
// swiftlint:disable private_outlet

import Cocoa

class SyncFailurePopoverView: NSView {
    
    @IBOutlet var message: NSTextView!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
    }
    
}
