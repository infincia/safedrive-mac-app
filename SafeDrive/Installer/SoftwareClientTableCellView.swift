
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable private_outlet

import Cocoa
import SafeDriveSDK

class SoftwareClientTableCellView: NSTableCellView {

    fileprivate var _softwareClient: SoftwareClient!
    
    var softwareClient: SoftwareClient {
        get {
            return self._softwareClient
        }
        set (newValue) {
            self._softwareClient = newValue
            self.uniqueClientID.stringValue = newValue.uniqueClientID
            if self._softwareClient.operatingSystem.lowercased().contains("linux") {
                self.icon.image = NSImage(named: NSImageNameComputer)
            } else if self._softwareClient.operatingSystem.lowercased().contains("windows") {
                self.icon.image = NSImage(named: NSImageNameComputer)
            } else if self._softwareClient.operatingSystem.lowercased().contains("mac") ||
                      self._softwareClient.operatingSystem.lowercased().contains("osx") ||
                      self._softwareClient.operatingSystem.lowercased().contains("os x") {
                self.icon.image = NSImage(named: NSImageNameComputer)
            } else {
                self.icon.image = NSImage(named: NSImageNameComputer)
            }
            
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    @IBOutlet var name: NSTextField!
    @IBOutlet var icon: NSImageView!
    @IBOutlet var uniqueClientID: NSTextField!
    @IBOutlet var replace: NSButton!
}
