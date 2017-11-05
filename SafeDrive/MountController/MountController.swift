
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length


import Foundation

class MountController: NSObject {
    
    fileprivate var sftpfs: ManagedSFTPFS?
    
    fileprivate var sftpfsConnection: NSXPCConnection?
    
    fileprivate let sftpfsQueue = DispatchQueue(label: "io.safedrive.sftpfsQueue")

    fileprivate var _mounted = false
    
    fileprivate let mountStateQueue = DispatchQueue(label: "io.safedrive.mountStateQueue")
    
    fileprivate var _mounting = false
    
    fileprivate let mountingQueue = DispatchQueue(label: "io.safedrive.mountingQueue")
    
    fileprivate var _signedIn = false
    
    fileprivate let signedInQueue = DispatchQueue(label: "io.safedrive.signedInQueue")
    
    fileprivate var _lastMountAttempt: Date?
    
    fileprivate let lastMountAttemptQueue = DispatchQueue(label: "io.safedrive.lastMountAttemptQueue")
    
    
    fileprivate var mountURL: URL?
    
    static let shared = MountController()
    
    fileprivate var openFileWarning: OpenFileWarningWindowController!
    
    fileprivate var email: String?
    fileprivate var internalUserName: String?
    fileprivate var password: String?
    
    fileprivate var remoteHost: String?
    fileprivate var remotePort: UInt16?
    
    var currentVolumeName: String {
        if let volumeName = UserDefaults.standard.string(forKey: userDefaultsCurrentVolumeNameKey()) {
            return volumeName
        }
        return defaultVolumeName()
    }
    
    var keepMounted: Bool {
        return UserDefaults.standard.bool(forKey: keepMountedKey())
    }
    
    var useCache = true
    
    var useXPC = false

    var currentMountURL: URL {
        let home = NSHomeDirectory()
        let volumesDirectoryURL = URL(fileURLWithPath: home, isDirectory: true)
        let mountURL = volumesDirectoryURL.appendingPathComponent(self.currentVolumeName)
        return mountURL
    }
    
    var mountDetails: [FileAttributeKey: Any]? {
        do {
            return try FileManager.default.attributesOfFileSystem(forPath: self.currentMountURL.path)
        } catch {
            return nil
        }
    }
    
    var automount: Bool {
        get {
            return UserDefaults.standard.bool(forKey: userDefaultsMountAtLaunchKey())
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: userDefaultsMountAtLaunchKey())
        }
    }
    
    var mounted: Bool {
        get {
            var r: Bool = false
            mountStateQueue.sync {
                r = self._mounted
            }
            return r
        }
        set (newValue) {
            mountStateQueue.sync(flags: .barrier, execute: {
                self._mounted = newValue
            })
        }
    }
    
    var mounting: Bool {
        get {
            var r: Bool = false
            mountingQueue.sync {
                r = self._mounting
            }
            return r
        }
        set (newValue) {
            mountingQueue.sync(flags: .barrier, execute: {
                self._mounting = newValue
            })
        }
    }
    
    var signedIn: Bool {
        get {
            var r: Bool = false
            signedInQueue.sync {
                r = self._signedIn
            }
            return r
        }
        set (newValue) {
            signedInQueue.sync(flags: .barrier, execute: {
                self._signedIn = newValue
            })
        }
    }
    
    var lastMountAttempt: Date? {
        get {
            var r: Date? = nil
            signedInQueue.sync {
                r = self._lastMountAttempt
            }
            return r
        }
        set (newValue) {
            signedInQueue.sync(flags: .barrier, execute: {
                self._lastMountAttempt = newValue
            })
        }
    }
    
    override init() {
        super.init()
        self.mounted = false
        self.mounting = false
        self.signedIn = false
        self.lastMountAttempt = nil
        
        self.openFileWarning = OpenFileWarningWindowController(delegate: self)
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDVolumeEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidMount), name: Notification.Name.volumeDidMount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeDidUnmount), name: Notification.Name.volumeDidUnmount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeShouldUnmount), name: Notification.Name.volumeShouldUnmount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeShouldMount), name: Notification.Name.volumeShouldMount, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        
        let connection = NSXPCConnection(serviceName: "io.safedrive.SafeDrive.SFTPFS")
        
        let serviceInterface = NSXPCInterface(with: SFTPFSXPCProtocol.self)
        
        connection.remoteObjectInterface = serviceInterface
        
        weak var weakSelf: MountController? = self
        
        connection.interruptionHandler = {
            if let weakSelf = weakSelf {
                weakSelf.sftpfsQueue.async {
                    weakSelf.sftpfsConnection = nil
                }
            }
        }
        connection.invalidationHandler = {
            if let weakSelf = weakSelf {
                weakSelf.sftpfsQueue.async {
                    weakSelf.sftpfsConnection = nil
                }
            }
        }
        connection.resume()
        
        self.sftpfsConnection = connection
        
        mountStateLoop()
        mountLoop()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func checkMount(at url: URL) -> Bool {
        if let mountedVolumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: .skipHiddenVolumes) {
            for mountedVolumeURL in mountedVolumes {
                if mountedVolumeURL.path == url.path {
                    return true
                }
            }
        }
        return false
    }

    func checkMount(at url: URL, timeout: TimeInterval, mounted mountedBlock: @escaping () -> Void, notMounted notMountedBlock: @escaping () -> Void) {
        background {
            let start_time = Date()
            
            while Date().timeIntervalSince(start_time) < timeout {
                if self.checkMount(at: url) {
                    DispatchQueue.main.async {
                        mountedBlock()
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 1)
            }
            DispatchQueue.main.async {
                notMountedBlock()
            }
        }
    }
    
    func unmount(success successBlock: @escaping (_ mount: URL) -> Void, failure failureBlock: @escaping (_ mount: URL, _ error: Error) -> Void) {
        
        background {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: self.currentMountURL)
                main {
                    self.mountURL = nil
                    NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object: nil)
                    successBlock(self.currentMountURL)
                }
            } catch let error as NSError {
                main {
                    failureBlock(self.currentMountURL, error)
                }
            }
        }
    }
    
    // MARK: warning Needs slight refactoring
    func mountStateLoop() {
        background {
            while true {
                self.mounted = self.checkMount(at: self.currentMountURL)
                
                if self.mounted {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object: self.mountDetails)
                        NotificationCenter.default.post(name: Notification.Name.mounted, object: nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object: nil)
                        NotificationCenter.default.post(name: Notification.Name.unmounted, object: nil)
                    }
                }
                
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
    
    func mountLoop() {
        
        background {
            
            while true {
                
                Thread.sleep(forTimeInterval: 1)
                // this aligns the loop with initial sign in so there isn't
                // a delay before mounting starts
                if !self.signedIn {
                    self.lastMountAttempt = nil
                    continue
                }
                
                
                if !self.mounted && self.keepMounted {
                    var attemptMount = false
                    
                    if let lastMountAttempt = self.lastMountAttempt {
                        let now = Date()
                        
                        let d = now.timeIntervalSince(lastMountAttempt)
                        
                        if d > 60 {
                            attemptMount = true
                        }
                    } else {
                        attemptMount = true
                    }
                    
                    if attemptMount {
                        SDLogDebug("Attempting to mount drive")
                        
                        self.lastMountAttempt = Date()
                        
                        NotificationCenter.default.post(name: NSNotification.Name.applicationShouldToggleMountState, object: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - High level API
    
    func connectVolume() {
        
        guard let user = self.internalUserName,
            let password = self.password,
            let host = self.remoteHost,
            let port = self.remotePort else {
                SDLog("API contract invalid: connectVolume in MountController")
                Crashlytics.sharedInstance().crash()
                return
        }
        guard let volicon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            let message = NSLocalizedString("Volume icon missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .configMissing)
            SDLog("\(error)")
            let notification = NSUserNotification()

            var userInfo = [String: Any]()
            
            userInfo["identifier"] = SDNotificationType.driveMountFailed.rawValue
            
            notification.userInfo = userInfo
            
            notification.informativeText = error.localizedDescription
            notification.title = "SafeDrive mount error"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
            
            return
        }
        
    
        self.mounting = true
    
        var urlComponents = URLComponents()
        urlComponents.user = user
        urlComponents.host = host
        urlComponents.path = defaultServerPath()
        urlComponents.port = Int(port)

        let notification = NSUserNotification()
        
        let mountURL = self.currentMountURL
        let volumeName = self.currentVolumeName

        sftpfsQueue.async {
            if self.useXPC {
                if let s = self.sftpfsConnection {
                    let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                        SDLogError("Connecting to sftpfs failed: \(error.localizedDescription)")
                    }) as! SFTPFSXPCProtocol
                    
                    proxy.create(mountURL.path, label: volumeName, user: user, password: password, host: host, port: port)
                    
                    proxy.setUseCache(self.useCache)
                    
                    proxy.setIcon(volicon)
                    
                    proxy.connect()
                    
                    /*
                     now check for a successful mount. if after 30 seconds there is no volume
                     mounted, it is a fair bet that an error occurred in the meantime
                     */
                    
                    self.checkMount(at: mountURL, timeout: 30, mounted: {
                        NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
                        self.mounting = false
                    }, notMounted: {
                        let message = NSLocalizedString("SafeDrive did not mount within 30 seconds, please check your network connection", comment: "")
                        let error = SDError(message: message, kind: .timeout)
                        SDLog("SafeDrive checkForMountedVolume failure in mount controller: \(error)")
                        
                        var userInfo = [String: Any]()
                        
                        userInfo["identifier"] = SDNotificationType.driveMountFailed.rawValue

                        notification.userInfo = userInfo
                        
                        notification.informativeText = error.localizedDescription
                        notification.title = "SafeDrive mount error"
                        notification.soundName = NSUserNotificationDefaultSoundName
                        NSUserNotificationCenter.default.deliver(notification)
                        
                        self.mounting = false
                        
                        // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
                        
                        self.unmount(success: { _ in
                            //
                        }, failure: { (_, _) in
                            //
                        })
                    })
                } else {
                    self.mounting = false
                    
                    let message = NSLocalizedString("Connecting to sftpfs not possible", comment: "")
                    let error = SDError(message: message, kind: .serviceDeployment)
                    SDLogError("\(message)")
                    
                    main {
                        notification.informativeText = error.localizedDescription
                        
                        var userInfo = [String: Any]()
                        
                        userInfo["identifier"] = SDNotificationType.driveMountFailed.rawValue

                        notification.userInfo = userInfo
                        
                        notification.title = "SafeDrive mount error"
                        notification.soundName = NSUserNotificationDefaultSoundName
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                }
            } else {
                let newConnection = ManagedSFTPFS.withMountpoint(mountURL.path,
                                                                 label: volumeName,
                                                                 user: user,
                                                                 password: password,
                                                                 host: host,
                                                                 port: port as NSNumber)
                
                
                newConnection.setUseCache(self.useCache)
                
                newConnection.setIcon(volicon)
                
                newConnection.connect()
                
                self.sftpfs = newConnection
                
                /*
                 now check for a successful mount. if after 30 seconds there is no volume
                 mounted, it is a fair bet that an error occurred in the meantime
                 */
                
                self.checkMount(at: mountURL, timeout: 30, mounted: {
                    NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
                    self.mounting = false
                }, notMounted: {
                    let message = NSLocalizedString("SafeDrive did not mount within 30 seconds, please check your network connection", comment: "")
                    let error = SDError(message: message, kind: .timeout)
                    SDLog("SafeDrive checkForMountedVolume failure in mount controller: \(error)")
                    
                    var userInfo = [String: Any]()
                    
                    userInfo["identifier"] = SDNotificationType.driveMountFailed.rawValue

                    notification.userInfo = userInfo
                    
                    notification.informativeText = error.localizedDescription
                    notification.title = "SafeDrive mount error"
                    notification.soundName = NSUserNotificationDefaultSoundName
                    NSUserNotificationCenter.default.deliver(notification)
                    
                    self.mounting = false
                    
                    // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
                    
                    self.unmount(success: { _ in
                        //
                    }, failure: { (_, _) in
                        //
                    })
                })
            }
        }
    }
    
    func disconnectVolume(askForOpenApps: Bool) {
    
        let volumeName: String = self.currentVolumeName
        
        SDLog("Dismounting volume: %@", volumeName)
        
        background {
            self.unmount(success: { _ -> Void in
                //
            }, failure: { (url, error) -> Void in
                
                let message = "SafeDrive could not be unmounted\n\n \(error.localizedDescription)"
                
                SDLog(message)
                
                let notification = NSUserNotification()
                
                let e = error as NSError
                let code = e.code
                if code == fBsyErr {
                    notification.informativeText = NSLocalizedString("Please close any open files on your SafeDrive", comment: "")

                    if askForOpenApps {
                        let c = OpenFileCheck()
                        
                        let processes = c.check(volume: url)
                        
                        if processes.count <= 0 {
                            return
                        }
                        DispatchQueue.main.async {
                            NSApp.activate(ignoringOtherApps: true)
                            
                            self.openFileWarning.check(url: url)
                        }
                    }
                } else if code == fnfErr {
                    notification.informativeText = NSLocalizedString("This is a bug in OS X, reboot may help", comment: "")
                } else {
                    notification.informativeText = NSLocalizedString("Unknown error occurred (\(code))", comment: "")
                }
                
                var userInfo = [String: Any]()
                
                userInfo["identifier"] = SDNotificationType.driveUnmountFailed.rawValue

                notification.userInfo = userInfo
                
                notification.title = "SafeDrive unmount failed"
                
                notification.soundName = NSUserNotificationDefaultSoundName
                
                NSUserNotificationCenter.default.deliver(notification)
                
            })
        }
    }
    
}

extension MountController: SleepReactor {
    @objc func willSleep(_ notification: Notification) {
        if self.mounted {
            SDLog("machine going to sleep, unmounting SSHFS")
            self.disconnectVolume(askForOpenApps: true)
        }
    }
}

extension MountController: SDAccountProtocol {
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")
        guard let accountStatus = notification.object as? SDKAccountStatus else {
            SDLog("API contract invalid: didSignIn in MountController")
            return
        }
        
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
        
        self.signedIn = true
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")

        self.signedIn = false
        
        self.email = nil
        self.internalUserName = nil
        self.password = nil
        
        self.remoteHost = nil
        self.remotePort = nil
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")

        guard let accountStatus = notification.object as? SDKAccountStatus else {
            SDLog("API contract invalid: didReceiveAccountStatus in MountController")
            return
        }
        
        self.internalUserName = accountStatus.userName
        self.remoteHost = accountStatus.host
        self.remotePort = accountStatus.port
    }
    
    func didReceiveAccountDetails(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountDetails called on background thread")


    }
}

extension MountController: SDVolumeEventProtocol {

    func volumeDidMount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeDidMount called on background thread")
        
        let notification = NSUserNotification()
        
        var userInfo = [String: Any]()
        
        userInfo["identifier"] = SDNotificationType.driveMounted.rawValue

        notification.userInfo = userInfo
        
        notification.informativeText = NSLocalizedString("click here to show the drive in Finder", comment: "")
        
        notification.title = "SafeDrive connected"
        
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func volumeDidUnmount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeDidMount called on background thread")

        self.openFileWarning.stop()

        let notification = NSUserNotification()
                
        var userInfo = [String: Any]()
        
        userInfo["identifier"] = SDNotificationType.driveUnmounted.rawValue

        notification.userInfo = userInfo
                
        notification.title = "SafeDrive disconnected"
        
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
        
    }
    
    func volumeSubprocessDidTerminate(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeSubprocessDidTerminate called on background thread")

    
    }
    
    func volumeShouldMount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeShouldMount called on background thread")

        self.connectVolume()
    }
    
    func volumeShouldUnmount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeShouldUnmount called on background thread")

        guard let askForOpenApps = notification.object as? Bool else {
            SDLog("API contract invalid in Mount Controller.volumeShouldUnmount()")
            return
        }
        self.disconnectVolume(askForOpenApps: askForOpenApps)
    }
}


extension MountController: OpenFileWarningDelegate {
    func closeApplication(_ process: RunningProcess) {
        SDLog("attempting to close \(process.command) (\(process.pid))")
        
        if process.isUserApplication {
            for app in NSWorkspace.shared.runningApplications {
                if process.pid == Int(app.processIdentifier) {
                    SDLog("found \(process.pid), terminating")
                    app.terminate()
                }
            }
        } else {
            let r = RunningProcessCheck()
            r.close(pid: process.pid)
        }
    }
    
    func runningProcesses() -> [RunningProcess] {
        SDLog("checking running processes")
        let r = RunningProcessCheck()

        return r.runningProcesses()
    }
    
    func blockingProcesses(_ url: URL) -> [RunningProcess] {
        SDLog("checking blocking processes")
        let c = OpenFileCheck()

        return c.check(volume: url)
    }
    
    func tryAgain() {
        self.disconnectVolume(askForOpenApps: false)
    }
    
    func finished() {
        self.openFileWarning.stop()
    }
}

extension MountController: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let _ = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in MountController")
            
            return
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let currentUser = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in MountController")
            
            return
        }
        
        self.email = currentUser.email
        self.password = currentUser.password
    }
}
