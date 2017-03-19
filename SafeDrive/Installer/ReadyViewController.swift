
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class ReadyViewController: NSViewController {
    fileprivate weak var delegate: StateDelegate?

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
    
    convenience init(delegate: StateDelegate) {
        self.init(nibName: "ReadyView", bundle: nil)!
        self.delegate = delegate
    }

    
    @IBAction func ok(_ sender: AnyObject?) {
        self.delegate?.didFinish()
    }
}
