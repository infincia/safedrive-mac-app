
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import SafeDriveSDK

class FailedViewController: NSViewController {
    fileprivate weak var delegate: WelcomeStateDelegate?
    
    fileprivate weak var viewDelegate: WelcomeViewDelegate?
    
    var sdk = SafeDriveSDK.sharedSDK
    
    @IBOutlet fileprivate var spinner: NSProgressIndicator!
    
    @IBOutlet fileprivate var scrollView: NSScrollView!
    
    var errorMessage: NSTextView {
        return scrollView.contentView.documentView as! NSTextView
    }

    @IBOutlet fileprivate weak var panelMessage: NSTextField!

    @IBOutlet fileprivate weak var reportButton: NSButton!
    
    @IBOutlet fileprivate weak var okButton: NSButton!
    
    fileprivate var uniqueClientId = String()
    
    fileprivate var log = [String]()
    
    fileprivate var error: Error?

    var reported: Bool = false

    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: WelcomeStateDelegate, viewDelegate: WelcomeViewDelegate) {
        // swiftlint:disable force_unwrapping
        self.init(nibName: "FailedView", bundle: nil)!
        // swiftlint:enable force_unwrapping

        self.delegate = delegate
        
        self.viewDelegate = viewDelegate
    }
    
    func reset() {
        self.spinner.stopAnimation(self)
        self.uniqueClientId = String()
        self.log = [String]()
        self.error = nil
        self.reported = false
        self.panelMessage.stringValue = ""
        let att = NSAttributedString(string: "")
        self.errorMessage.textStorage?.setAttributedString(att)
    }
    
    func fail(error: Error, uniqueClientId: String?) {
        self.reset()
        self.error = error
        let att = NSAttributedString(string: error.localizedDescription)
        self.errorMessage.textStorage?.setAttributedString(att)
        if let ucid = uniqueClientId {
            self.uniqueClientId = ucid
        }
    }
    
    @IBAction func report(_ sender: AnyObject?) {
        self.reported = true
        self.panelMessage.stringValue = NSLocalizedString("Sending error report to SafeDrive", comment: "")
        self.spinner.startAnimation(self)
        
        var e: Error
        if let error = self.error as? SDKError {
            e = error
        } else if let error = self.error as? SDError {
            e = error
        } else if let error = self.error as NSError? {
            e = NSError(domain: SDErrorDomainReported, code: error.code, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
        } else {
            e = SDError(message: "An unknown error occurred, contact support", kind: .unknown)
        }
        
        let os: String = "OS X \(currentOSVersion())"
        let clientVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String

        self.sdk.reportError(e, forUniqueClientId: self.uniqueClientId, os: os, clientVersion: clientVersion, completionQueue: DispatchQueue.main, success: {
            self.spinner.stopAnimation(self)

            self.panelMessage.stringValue = NSLocalizedString("Thank you for your report", comment: "")
        }, failure: { (error) in
            SDLog("Error submitting report: \(error)")
            let att = NSAttributedString(string: error.localizedDescription)
            self.errorMessage.textStorage?.setAttributedString(att)
            
            self.spinner.stopAnimation(self)
            self.reported = false
            self.panelMessage.stringValue = NSLocalizedString("Uh oh! It looks like the error report could not be sent, would you like to try again?", comment: "")
        })
    }
    
    @IBAction func close(_ sender: AnyObject?) {
        NSApp.terminate(self)
    }
}
