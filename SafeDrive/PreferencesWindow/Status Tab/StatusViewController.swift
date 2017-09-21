
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {
    
    fileprivate weak var delegate: PreferencesViewDelegate!

    @IBOutlet fileprivate var mountStatusField: NSTextField!
    @IBOutlet fileprivate var volumeSizeField: NSTextField!
    
    @IBOutlet fileprivate var volumeFreespaceField: NSTextField!
    
    @IBOutlet fileprivate var volumeUsageBar: NSProgressIndicator!
    
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
        self.init(nibName: NSNib.Name(rawValue: "StatusView"), bundle: nil)

        
        self.delegate = delegate
        
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateMounted), name: Notification.Name.mounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateUnmounted), name: Notification.Name.unmounted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
    }
    
    
}


extension StatusViewController: SDMountStateProtocol {
    
    func mountStateMounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateMounted called on background thread")
        
        self.mountStatusField.stringValue = NSLocalizedString("Yes", comment: "String for volume mount status of mounted")
    }
    
    func mountStateUnmounted(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateUnmounted called on background thread")
        
        self.mountStatusField.stringValue = NSLocalizedString("No", comment: "String for volume mount status of unmounted")
    }
    
    func mountStateDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "mountStateDetails called on background thread")
        
        if let mountDetails = notification.object as? [FileAttributeKey: AnyObject],
            let volumeTotalSpace = mountDetails[FileAttributeKey.systemSize] as? Int,
            let volumeFreeSpace = mountDetails[FileAttributeKey.systemFreeSize] as? Int {
            self.volumeSizeField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(volumeTotalSpace), countStyle: .file)
            self.volumeFreespaceField.stringValue = ByteCountFormatter.string(fromByteCount: Int64(volumeFreeSpace), countStyle: .file)
            let volumeUsedSpace = volumeTotalSpace - volumeFreeSpace
            self.volumeUsageBar.maxValue = Double(volumeTotalSpace)
            self.volumeUsageBar.minValue = 0
            self.volumeUsageBar.doubleValue = Double(volumeUsedSpace)
            
        } else {
            self.volumeSizeField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of mounted")
            self.volumeFreespaceField.stringValue = NSLocalizedString("Unmounted", comment: "String for volume mount status of unmounted")
            self.volumeUsageBar.maxValue = 1
            self.volumeUsageBar.minValue = 0
            self.volumeUsageBar.doubleValue = 0
        }
    }
}

extension StatusViewController: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")
    }
}
