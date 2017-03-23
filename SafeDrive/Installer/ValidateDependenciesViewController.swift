
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class ValidateDependenciesViewController: NSViewController {
    var installer: Installer!

    fileprivate weak var delegate: StateDelegate?
    
    fileprivate weak var viewDelegate: WelcomeViewDelegate?

    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!

    @IBOutlet fileprivate weak var installDependenciesButton: NSButton!

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
    
    convenience init(installer: Installer, delegate: StateDelegate, viewDelegate: WelcomeViewDelegate) {
        // swiftlint:disable force_unwrapping
        self.init(nibName: "ValidateDependenciesView", bundle: nil)!
        // swiftlint:enable force_unwrapping

        self.installer = installer
        self.installer.delegate = self
        self.delegate = delegate
        
        self.viewDelegate = viewDelegate
    }
    
    func reset() {
        self.spinner.stopAnimation(self)
    }
    
    func check() {
        self.reset()
        
        SDLog("checking dependencies")
        self.installer.check()
    }
        
    @IBAction func installDependencies(_ sender: AnyObject?) {
        self.spinner.startAnimation(self)
        self.installer.installDependencies()
    }
}


extension ValidateDependenciesViewController: InstallerDelegate {
    func needsDependencies() {
        self.delegate?.needsDependencies()
    }
    
    func didValidateDependencies() {
        self.spinner.stopAnimation(self)

        self.delegate?.didValidateDependencies()
    }
    
    func didFail(error: NSError) {
        self.spinner.stopAnimation(self)

        self.delegate?.didFail(error: error, uniqueClientID: nil)
    }
}
