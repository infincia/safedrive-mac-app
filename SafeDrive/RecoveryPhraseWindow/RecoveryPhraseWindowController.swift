
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

protocol RecoveryPhraseEntryDelegate: class {
    func checkRecoveryPhrase(_ phrase: String?, success: @escaping () -> Void, failure: @escaping (_ error: SDKError) -> Void)
    
    func storeRecoveryPhrase(_ phrase: String, success: @escaping () -> Void, failure: @escaping (_ error: Error) -> Void)
}

class RecoveryPhraseWindowController: NSWindowController {
    
    @IBOutlet fileprivate weak var recoveryPhraseField: NSTextField!
    @IBOutlet fileprivate weak var errorField: NSTextField!
    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!

    weak var recoveryDelegate: RecoveryPhraseEntryDelegate?
    
    convenience init() {
        self.init(windowNibName: NSNib.Name(rawValue: "RecoveryPhraseWindow"))
    }
    
    
    convenience init?(delegate: RecoveryPhraseEntryDelegate) {
        self.init(windowNibName: NSNib.Name(rawValue: "RecoveryPhraseWindow"))

        self.recoveryDelegate = delegate
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.errorField.stringValue = ""
        self.spinner.stopAnimation(self)
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    @IBAction func closeWindow(_ sender: AnyObject?) {
        guard let window = self.window else {
            SDLog("API contract invalid: window not found in RecoveryPhraseWindowController")
            return
        }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.close()
        }
    }
    
    @IBAction func checkRecoveryPhrase(_ sender: AnyObject?) {
        self.spinner.startAnimation(self)
        self.errorField.stringValue = ""
        
        let phraseToCheck = recoveryPhraseField.stringValue
        
        self.recoveryDelegate?.storeRecoveryPhrase(phraseToCheck, success: {
            self.recoveryDelegate?.checkRecoveryPhrase(phraseToCheck, success: {
                self.spinner.stopAnimation(self)
                
                self.errorField.stringValue = ""
                
                self.closeWindow(nil)
            }, failure: { (error) in
                self.spinner.stopAnimation(self)
                
                let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
                
                self.errorField.textColor = fadedRed
                
                self.errorField.stringValue = error.message
                
            })
        }, failure: { (error) in
            self.spinner.stopAnimation(self)
                
            let fadedRed: NSColor = NSColor(calibratedRed: 1.0, green: 0.25098, blue: 0.25098, alpha: 0.73)
                
            self.errorField.textColor = fadedRed
                
            self.errorField.stringValue = error.localizedDescription
        })
        
        
        
    }
    
}
