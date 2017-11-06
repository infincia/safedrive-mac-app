
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class ValidateServiceViewController: NSViewController {
    var serviceManager = ServiceManager.sharedServiceManager

    fileprivate weak var delegate: WelcomeStateDelegate?
    
    fileprivate weak var viewDelegate: WelcomeViewDelegate?

    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!

    @IBOutlet fileprivate weak var installServiceButton: NSButton!

    @IBOutlet fileprivate weak var needServiceMessage: NSTextField!

    @IBOutlet fileprivate weak var needKextMessage: NSTextField!
    
    fileprivate var promptedForKext = false

    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: WelcomeStateDelegate, viewDelegate: WelcomeViewDelegate) {

        self.init(nibName: NSNib.Name(rawValue: "ValidateServiceView"), bundle: nil)

        
        ServiceManager.delegate = self
        self.delegate = delegate
        
        self.viewDelegate = viewDelegate
    }
    
    func reset() {
        self.spinner.stopAnimation(self)
        self.installServiceButton.isEnabled = true
    }
    
    func check() {
        self.reset()
        
        SDLogDebug("checking service")
        self.serviceManager.checkServiceVersion()
    }
        
    @IBAction func installService(_ sender: AnyObject?) {
        self.spinner.startAnimation(self)
        self.installServiceButton.isEnabled = false

        self.serviceManager.updateService()
    }
}


extension ValidateServiceViewController: ServiceManagerDelegate {
    func needsService() {
        main {
            self.needServiceMessage.isHidden = false
            self.needKextMessage.isHidden = true
            self.delegate?.needsService()
        }
    }
    
    func didValidateService() {
        main {
            self.serviceManager.updateSDFS()
        }
    }
    
    func didValidateSDFS() {
        main {
            self.serviceManager.loadKext()
        }
    }
    
    func needsKext() {
        if !self.promptedForKext {
            self.promptedForKext = true
           
            main {
                self.delegate?.needsKext()
                
                self.needServiceMessage.isHidden = true
                self.needKextMessage.isHidden = false
            }
        }
    }
    
    func didValidateKext() {
        main {
            self.needServiceMessage.isHidden = true
            self.needKextMessage.isHidden = true
            
            self.spinner.stopAnimation(self)
            self.delegate?.didValidateService()
        }
    }
    
    func didFail(error: Error) {
        main {
            self.spinner.stopAnimation(self)
            self.delegate?.didFail(error: error, uniqueClientID: nil)
        }
    }
}
