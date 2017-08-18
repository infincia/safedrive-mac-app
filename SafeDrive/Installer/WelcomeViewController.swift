
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class WelcomeViewController: NSViewController {
    fileprivate weak var delegate: WelcomeStateDelegate?
    
    fileprivate weak var viewDelegate: WelcomeViewDelegate?
    
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

        self.init(nibName: NSNib.Name(rawValue: "WelcomeView"), bundle: nil)

        
        self.delegate = delegate
        
        self.viewDelegate = viewDelegate
    }
    
    func check() {
        let welcomeShown = UserDefaults.standard.bool(forKey: userDefaultsWelcomeShownKey())
        if !welcomeShown {
            self.delegate?.needsWelcome()
        } else {
            self.next(nil)
        }
    }
    
    @IBAction func next(_ sender: AnyObject?) {
        UserDefaults.standard.set(true, forKey: userDefaultsWelcomeShownKey())
        self.delegate?.didWelcomeUser()
    }
}
