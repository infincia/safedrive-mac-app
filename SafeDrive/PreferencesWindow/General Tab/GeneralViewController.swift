
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class GeneralViewController: NSViewController {

    fileprivate var sharedSystemAPI = SDSystemAPI.shared()
    
    @IBOutlet fileprivate var volumeNameField: NSTextField!
    @IBOutlet fileprivate var volumeNameWarningField: NSTextField!
    @IBOutlet fileprivate var useSFTPFSCheckbox: NSButton!
    @IBOutlet fileprivate var useCacheCheckbox: NSButton!
    @IBOutlet fileprivate var useServiceCheckbox: NSButton!

    fileprivate weak var delegate: PreferencesViewDelegate!
    
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
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: PreferencesViewDelegate) {

        self.init(nibName: NSNib.Name(rawValue: "GeneralView"), bundle: nil)

        
        self.delegate = delegate
        
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
        self.useSFTPFSCheckbox.isEnabled = false
        self.useCacheCheckbox.isEnabled = false
        self.useServiceCheckbox.isEnabled = false
    }
    
    func mountStateUnmounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateUnmounted called on background thread")
    
        self.volumeNameField.isEnabled = true
        self.volumeNameWarningField.isHidden = true
        self.useSFTPFSCheckbox.isEnabled = true
        self.useCacheCheckbox.isEnabled = true
        self.useServiceCheckbox.isEnabled = true
    }
    
    func mountStateDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateDetails called on background thread")

    }
}
