
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class GeneralViewController: NSViewController {

    fileprivate var sharedSystemAPI = SDSystemAPI.shared()
    
    @IBOutlet var volumeNameField: NSTextField!
    @IBOutlet var volumeNameWarningField: NSTextField!
    
    
    var autostart: Bool {
        get {
            return self.sharedSystemAPI.autostart()
        }
        set(newValue) {
            if newValue == true {
                do {
                    try self.sharedSystemAPI.enableAutostart()
                } catch let error as NSError {
                    SDErrorHandlerReport(error)
                }
            } else {
                do {
                    try self.sharedSystemAPI.disableAutostart()
                } catch let error as NSError {
                    SDErrorHandlerReport(error)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init() {
        // swiftlint:disable force_unwrapping
        self.init(nibName: "GeneralView", bundle: nil)!
        // swiftlint:enable force_unwrapping

        
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
    }
    
}

extension GeneralViewController: SDMountStateProtocol {
    
    func mountStateMounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateMounted called on background thread")
        
        self.volumeNameField.isEnabled = false
        self.volumeNameWarningField.isHidden = false
    }
    
    func mountStateUnmounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateUnmounted called on background thread")
    
        self.volumeNameField.isEnabled = true
        self.volumeNameWarningField.isHidden = true
        
    }
    
    func mountStateDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateDetails called on background thread")

    }
}
