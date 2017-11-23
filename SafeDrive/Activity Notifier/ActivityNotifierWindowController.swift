
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

protocol ActivityNotifierWindowControllerDelegate: class {

}


class ActivityNotifierWindowController: NSWindowController {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate let counterQueue = DispatchQueue(label: "io.safedrive.counterQueue")
    fileprivate let runQueue = DispatchQueue(label: "io.safedrive.runQueue")

    @IBOutlet fileprivate weak var messageField: NSTextField!
    @IBOutlet fileprivate weak var counterField: NSTextField!
    
    var _run = false
    
    var _startDate = Date()

    var message: String {
        get {
            return messageField.stringValue
        }
        set {
            messageField.stringValue = newValue
        }
    }
    
    var run: Bool {
        get {
            var r = false
            runQueue.sync {
                r = _run
            }
            return r
        }
        set {
            runQueue.sync {
                _run = newValue
            }
        }
    }
    
    var startDate: Date {
        get {
            var d = Date()
            runQueue.sync {
                d = _startDate
            }
            return d
        }
        set {
            runQueue.sync {
                _startDate = newValue
            }
        }
    }
    
    weak var activityDelegate: ActivityNotifierWindowControllerDelegate?
    
    convenience init() {
        self.init(windowNibName: NSNib.Name("ActivityNotifierWindow"))
        
        _ = window!
    }
    
    
    convenience init?(delegate: ActivityNotifierWindowControllerDelegate) {
        self.init(windowNibName: NSNib.Name("ActivityNotifierWindow"))
        
        activityDelegate = delegate
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        message = ""
        window?.title = "SafeDrive"
    }
    
    func startCounter() {
        self.run = true

        main {
            self.counterField.textColor = NSColor.green
            self.counterField.stringValue = ""
        }
        background {
            while self.run {
                let now = Date()
                let d = now.timeIntervalSince(self.startDate)
                let s: Int = Int(d) % 60
                let m: Int = Int(d) / 60
                
                let formattedDuration = String(format: "%0d:%02d", m, s)
                
                main {
                    self.counterField.stringValue = formattedDuration
                    if d >= 10 {
                        self.counterField.textColor = NSColor.red
                    } else {
                        self.counterField.textColor = NSColor.green
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
    
    func stopCounter() {
        self.run = false
        main {
            self.counterField.stringValue = ""
        }
    }
    
    func display(message: String) {
        main {
            guard let _ = self.window else {
                SDLogError("ActivityNotifierWindowController", "API contract invalid: window not found")
                return
            }

            self.message = message
            self.startCounter()
            self.showWindow(self)
        }
    }
    
    @IBAction func dismiss(sender: AnyObject?) {
        main {
            guard let _ = self.window else {
                SDLogError("ActivityNotifierWindowController", "API contract invalid: window not found")
                return
            }

            self.message = ""
            self.stopCounter()
            self.close()
        }
    }
}
