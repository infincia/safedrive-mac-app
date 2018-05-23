
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable private_outlet

import Cocoa
import FontAwesomeIconFactory


class SoftwareClientTableCellView: NSTableCellView {

    fileprivate var _softwareClient: SDKSoftwareClient!
    
    var softwareClient: SDKSoftwareClient {
        get {
            return self._softwareClient
        }
        set (newValue) {
            self._softwareClient = newValue
            self.uniqueClientName.stringValue = newValue.uniqueClientName
            if self._softwareClient.operatingSystem.lowercased().contains("linux") {
                self.icon.icon = NIKFontAwesomeIcon.linux
            } else if self._softwareClient.operatingSystem.lowercased().contains("windows") {
                self.icon.icon = NIKFontAwesomeIcon.windows
            } else if self._softwareClient.operatingSystem.lowercased().contains("mac") ||
                      self._softwareClient.operatingSystem.lowercased().contains("osx") ||
                      self._softwareClient.operatingSystem.lowercased().contains("os x") {
                self.icon.icon = NIKFontAwesomeIcon.apple
            } else {
                self.icon.icon = NIKFontAwesomeIcon.desktop
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    @IBOutlet var uniqueClientName: NSTextField!
    @IBOutlet var icon: FontAwesomeImageView!
    @IBOutlet var uniqueClientID: NSTextField!
    @IBOutlet var replace: NSButton!
}
