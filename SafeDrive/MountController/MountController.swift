
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length

import Cocoa
import Foundation

class MountController: NSObject {

    static let shared = MountController()
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var openFileWarning: OpenFileWarningWindowController!
    
    fileprivate var sftpfs: ManagedSFTPFS?
    
    fileprivate var sftpfsConnection: NSXPCConnection?
    
    fileprivate let sftpfsQueue = DispatchQueue(label: "io.safedrive.sftpfsQueue")
    fileprivate let propertyQueue = DispatchQueue(label: "io.safedrive.mountController.propertyQueue")

    fileprivate var _mounted = false
    fileprivate var _mounting = false
    
    fileprivate var _signedIn = false
    
    fileprivate var _lastMountAttempt: Date?
    
    fileprivate var _mountDelay: TimeInterval = mountDelayInterval()
    
    fileprivate var _remainingMountAttempts: Int8 = 0

    fileprivate var mountURL: URL?
    
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
    
    var useCache = false
    
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
    
    var mountDelay: TimeInterval {
        get {
            return propertyQueue.sync {
                return self._mountDelay
            }
        }
        set (newValue) {
            propertyQueue.sync(flags: .barrier, execute: {
                self._mountDelay = newValue
            })
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
            propertyQueue.sync {
                r = self._mounted
            }
            return r
        }
        set (newValue) {
            propertyQueue.sync(flags: .barrier, execute: {
                self._mounted = newValue
            })
        }
    }
    
    var mounting: Bool {
        get {
            var r: Bool = false
            propertyQueue.sync {
                r = self._mounting
            }
            return r
        }
        set (newValue) {
            propertyQueue.sync(flags: .barrier, execute: {
                self._mounting = newValue
            })
        }
    }
    
    var signedIn: Bool {
        get {
            var r: Bool = false
            propertyQueue.sync {
                r = self._signedIn
            }
            return r
        }
        set (newValue) {
            propertyQueue.sync(flags: .barrier, execute: {
                self._signedIn = newValue
            })
        }
    }
    
    var lastMountAttempt: Date? {
        get {
            var r: Date?
            propertyQueue.sync {
                r = self._lastMountAttempt
            }
            return r
        }
        set (newValue) {
            propertyQueue.sync(flags: .barrier, execute: {
                self._lastMountAttempt = newValue
            })
        }
    }
    
    var remainingMountAttempts: Int8 {
        get {
            return propertyQueue.sync {
                return self._remainingMountAttempts
            }
        }
        set (newValue) {
            propertyQueue.sync(flags: .barrier, execute: {
                self._remainingMountAttempts = newValue
            })
        }
    }
    
    override init() {
        super.init()
        self.mounted = false
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
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeMounting), name: Notification.Name.volumeMounting, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeUnmounting), name: Notification.Name.volumeUnmounting, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeMountFailed), name: Notification.Name.volumeMountFailed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDVolumeEventProtocol.volumeUnmountFailed), name: Notification.Name.volumeUnmountFailed, object: nil)

        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)

        let connection = NSXPCConnection(serviceName: "io.safedrive.SafeDrive.SFTPFS")
        
        let serviceInterface = NSXPCInterface(with: SFTPFSXPCProtocol.self)
        
        connection.remoteObjectInterface = serviceInterface
        
        weak var weakSelf: MountController? = self
        
        connection.interruptionHandler = {
            /*if let weakSelf = weakSelf {
                weakSelf.sftpfsQueue.async {
                    weakSelf.sftpfsConnection = nil
                }
            }*/
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
        
        finderSidebarLoop()
        mountStateLoop()
        mountDetailsLoop()
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
    
    func finderSidebarLoop() {
        background {
            while true {
                /**
                 * Always sleep at the top of the loop, guards against future
                 * changes that may accidentally cause uncontrolled CPU
                 * spinning due to break/continue statements that don't sleep
                 * first
                 **/
                Thread.sleep(forTimeInterval: 5)
                let u = self.currentMountURL as NSURL

                if self.mounted {
                    // add to the Finder sidebar if preference is enabled
                    
                    if UserDefaults.standard.bool(forKey: keepInFinderSidebarKey()) {
                        let u = self.currentMountURL as NSURL
                        if !u.isFavoriteItemPresent() {
                            if !u.addFavoriteItem() {
                                SDLogError("MountController", "Failed to add mountpoint to Finder sidebar favorites list")
                            }
                        }
                    }
                } else {
                    if !u.removeFavoriteItem() {
                        // ignore
                    }
                    
                    if !u.removeFavoriteVolume() {
                        // ignore
                    }
                }
            }
        }
    }

    func mountStateLoop() {
        background {
            while true {
                /**
                 * Always sleep at the top of the loop, guards against future
                 * changes that may accidentally cause uncontrolled CPU
                 * spinning due to break/continue statements that don't sleep
                 * first
                 **/
                
                Thread.sleep(forTimeInterval: 1)

                self.sftpfsQueue.sync {
                    if let s = self.sftpfsConnection {
                        let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                            SDLogError("MountController", "Connecting to sftpfs failed: \(error.localizedDescription)")
                        }) as! SFTPFSXPCProtocol
                        
                        proxy.mounted(reply: { (isMounted) in
                            self.mounted = isMounted
                            
                            main {
                                NotificationCenter.default.post(name: Notification.Name.mountState, object: self.mounted)
                            }
                        })
                    } else {
                        self.mounted = false
                        
                        main {
                            NotificationCenter.default.post(name: Notification.Name.mountState, object: self.mounted)
                        }
                    }
                }
            }
        }
    }
    
    func mountDetailsLoop() {
        background {
            while true {
                 /**
                   * Always sleep at the top of the loop, guards against future
                   * changes that may accidentally cause uncontrolled CPU
                   * spinning due to break/continue statements that don't sleep
                   * first
                  **/
                Thread.sleep(forTimeInterval: 1)

                if self.mounted {
                    /**
                     * needs to run on background thread or it will
                     * block the UI if the network stops responding
                     **/
                    let _mountDetails = self.mountDetails
                    
                    main {
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object: _mountDetails)
                    }
                    
                    /**
                      * after a successful stats check, we can sleep for much
                      * longer than one second, this will lighten the load on
                      * the drive and network.
                     **/
                    var lastState = self.mounted
                    let startDate = Date()

                    while true {
                        /**
                          * However we still want to quickly update the stats if the
                          * mount state changes, so we have an 'escape hatch' to
                          * break early and update immediately, when needed
                         **/
                        if lastState != self.mounted {
                            break
                        }
                        lastState = self.mounted

                        let now = Date()
                        let d = now.timeIntervalSince(startDate)
                        if d > 30 {
                            break
                        }
                        
                        Thread.sleep(forTimeInterval: 1)
                    }

                } else {
                    /**
                     * if the drive isn't mounted we shouldn't run stats updates
                     * at all, just clear them
                     **/
                    main {
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object: nil)
                    }
                }
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
                
                
                /**
                 *
                 * If there are remainingMountAttempts left, the mount controller
                 * is in the middle of handling a user initiated mount, so we
                 * should temporarily call connectVolume() automatically if needed,
                 * even though keepMounted may not be enabled.
                 *
                 * This is part of the mount retry system, we reuse the same loop
                 * and time keeping logic that keeps the drive mounted if the
                 * user wants it to stay mounted, but instead of trying every
                 * 60s we lower the mountDelay to 5s, giving us a free retry
                 * system without introducing races and extra state tracking.
                 *
                **/
                if !self.mounted && !self.mounting && (self.keepMounted || self.remainingMountAttempts > 0) {
                    var attemptMount = false
                    
                    if let lastMountAttempt = self.lastMountAttempt {
                        let now = Date()
                        
                        let d = now.timeIntervalSince(lastMountAttempt)
                        
                        if d > self.mountDelay {
                            attemptMount = true
                        }
                    } else {
                        attemptMount = true
                    }
                    
                    if attemptMount {
                        SDLogDebug("MountController", "Attempting to mount drive")
                        
                        self.lastMountAttempt = Date()
                        
                        let mountEvent = MountEvent(userInitiated: false)
                        
                        NotificationCenter.default.post(name: NSNotification.Name.volumeShouldMount, object: mountEvent)
                    }
                }
            }
        }
    }
    
    // MARK: - High level API
    
    func connectVolume() {
        /**
         * We want to "lock" the mounting system as soon as this method is
         * called, so that nothing else tries to call it until the current
         * method has finished and either failed or succeeded.
        **/
        self.mounting = true

        
        main {
            NotificationCenter.default.post(name: Notification.Name.volumeMounting, object: nil)
        }
        
        self.sdk.getSFTPFingerprints(completionQueue: DispatchQueue.main, success: { (fingerprints) in
            let fingerprintStrings = fingerprints.map({ (fingerprint) -> String in
                return fingerprint.fingerprint
            })
            self._connectVolume(withFingerprints: fingerprintStrings)
        }, failure: { (error) in
            let error = SDError(message: error.message, kind: error.kind)
            SDLogError("MountController", "\(error)")
            
            main {
                NotificationCenter.default.post(name: Notification.Name.volumeMountFailed, object: error)
            }

            self.mounting = false
        })
    }
    
    fileprivate func _connectVolume(withFingerprints fingerprints: [String]) {
        guard let user = self.internalUserName,
            let password = self.password,
            let host = self.remoteHost,
            let port = self.remotePort else {
                SDLogError("MountController", "API contract invalid: connectVolume()")
                Crashlytics.sharedInstance().crash()
                return
        }
        guard let volicon = Bundle.main.url(forResource: "sd", withExtension: "icns") else {
            let message = NSLocalizedString("Volume icon missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .configMissing)
            SDLogError("MountController", "\(error)")
            
            main {
                NotificationCenter.default.post(name: Notification.Name.volumeMountFailed, object: error)
            }
            return
        }

        let mountURL = self.currentMountURL
        let volumeName = self.currentVolumeName

        sftpfsQueue.async {

            if let s = self.sftpfsConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("MountController", "Connecting to sftpfs failed: \(error.localizedDescription)")
                    self.mounting = false
                }) as! SFTPFSXPCProtocol
                
                
                proxy.setLogger({ (message, module, level) in
                    guard let logLevel = SDKLogLevel(rawValue: UInt8(level)) else {
                        return
                    }
                    
                    switch logLevel {
                    case .error:
                        SDLogError(module, "%@", message)
                    case .warn:
                        SDLogWarn(module, "%@", message)
                    case .info:
                        SDLogInfo(module, "%@", message)
                    case .debug:
                        SDLogDebug(module, "%@", message)
                    case .trace:
                        SDLogTrace(module, "%@", message)
                    }
                })
                
                proxy.setErrorHandler({ (message, error_type) in
                    background {
                        guard let errorType = SFTPFSErrorType(rawValue: error_type) else {
                            return
                        }
                        
                        SDLogError("SFTPFS", "\(errorType): %s", message)
                        
                        switch errorType {
                        case .AccessForbidden:
                            break
                        case .AlreadyConnected:
                            break
                        case .ConnectionCancelled:
                            let unmountEvent = UnmountEvent(askForOpenApps: false, force: true)
                            NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: unmountEvent)
                        case .ConnectionFailed:
                            let unmountEvent = UnmountEvent(askForOpenApps: false, force: true)
                            NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: unmountEvent)
                        case .ConnectionLost:
                            let unmountEvent = UnmountEvent(askForOpenApps: false, force: true)
                            NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: unmountEvent)
                        case .DiskFull:
                            break
                        case .FileNotFound:
                            break
                        case .InternalError:
                            break
                        case .MountFailed:
                            break
                        case .NoError:
                            break
                        case .NotConnected:
                            break
                        case .PermissionDenied:
                            break
                        case .UnknownError:
                            break
                        case .UnmountFailed:
                            break
                        }
                    }
                })
                
                proxy.create(mountURL.path, label: volumeName, user: user, password: password, host: host, port: port)
                
                proxy.setUseCache(self.useCache)
                
                proxy.setIcon(volicon)
                
                proxy.setSFTPFingerprints(fingerprints)
                
                proxy.connect(reply: { (success, message, _) in
                    if success {
                        main {
                            NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
                        }
                    } else {
                        // swiftlint:disable force_unwrapping
                        let error = SDError(message: message!, kind: .mountFailed)
                        // swiftlint:enable force_unwrapping
                        SDLogError("MountController", "_connectVolume() failure: \(error)")

                        proxy.killMount()

                        main {
                            NotificationCenter.default.post(name: Notification.Name.volumeMountFailed, object: error)
                        }

                        // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
                        do {
                            try NSWorkspace.shared.unmountAndEjectDevice(at: self.currentMountURL)
                        } catch {
                            
                        }
                    }
                    
                    self.mounting = false
                })
            } else {
                let message = NSLocalizedString("Connecting to sftpfs not possible", comment: "")
                let error = SDError(message: message, kind: .serviceDeployment)
                
                NotificationCenter.default.post(name: Notification.Name.volumeMountFailed, object: error)

                SDLogError("MountController", "\(message)")
                
                self.mounting = false
            }
            
        }
    }
    
    func disconnectVolume(askForOpenApps: Bool, force: Bool) {
    
        func errorHandler(url: URL, error: NSError) {
            let message = "SafeDrive could not be unmounted\n\n \(error.localizedDescription)"

            SDLogError("MountController", message)
            
            var userMessage: String

            let code = error.code
            if code == fBsyErr {
                userMessage = NSLocalizedString("Please close any open files on your SafeDrive", comment: "")
                
                if askForOpenApps {
                    let c = OpenFileCheck()
                    
                    let processes = c.check(volume: url)
                    
                    if processes.count <= 0 {
                        return
                    }
                    main {
                        NSApp.activate(ignoringOtherApps: true)
                        
                        self.openFileWarning.check(url: url)
                    }
                }
            } else if code == fnfErr {
                userMessage = NSLocalizedString("This is a bug in OS X, reboot may help", comment: "")
            } else {
                userMessage = NSLocalizedString("Unknown error occurred (\(code))", comment: "")
            }
            
            let _error = SDError(message: userMessage, kind: .unmountFailed)

            main {
                NotificationCenter.default.post(name: Notification.Name.volumeUnmountFailed, object: _error)
            }
        }
        
        let volumeName: String = self.currentVolumeName
        
        SDLogInfo("MountController", "Dismounting volume: %@", volumeName)
        
        main {
            NotificationCenter.default.post(name: Notification.Name.volumeUnmounting, object: nil)
        }
        
        let u = self.currentMountURL as NSURL
        if !u.removeFavoriteItem() {
            SDLogWarn("MountController", "Failed to remove mountpoint from Finder sidebar favorites list")
        }
        
        if !u.removeFavoriteVolume() {
            SDLogWarn("MountController", "Failed to remove mountpoint from Finder sidebar volumes list")
        }
        
        // if the force flag is set, we skip the rest of the unmount handling for now
        // we may want to retry the force unmounting as well, but it will have to be
        // done in a different way due to the differences in how XPC and NSWorkspace APIs work
        if force {
            if let s = self.sftpfsConnection {
                let proxy = s.remoteObjectProxyWithErrorHandler({ (error) in
                    SDLogError("MountController", "Killing sftpfs failed: \(error.localizedDescription)")
                }) as! SFTPFSXPCProtocol
                
                proxy.killMount()
                
                main {
                    self.mountURL = nil
                    NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object: nil)
                }
            }
            return
        }

        background {
            let retries = 5
            var retries_left = retries
            
            repeat {
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: self.currentMountURL)
                    main {
                        self.mountURL = nil
                        NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object: nil)
                    }
                    
                    return
                    
                } catch let error as NSError {
                    retries_left -= 1

                    if retries_left <= 0 {
                        SDLogWarn("MountController", "Unmount retries exceeded")

                        main {
                            errorHandler(url: self.currentMountURL, error: error)
                        }
                        return
                    }
                    
                    let failed_count = retries - retries_left

                    if failed_count >= 1 {
                        let backoff_multiplier = drand48()

                        let backoff_time = backoff_multiplier * Double(failed_count * failed_count)
                        
                        SDLogWarn("MountController", "Unmount retrying after \(backoff_time)s")

                        Thread.sleep(forTimeInterval: TimeInterval(backoff_time))
                    }
                }
            } while retries_left > 0
        }
    }
    
}

extension MountController: SleepReactor {
    @objc func willSleep(_ notification: Notification) {
        if self.mounted {
            SDLogWarn("MountController", "machine going to sleep, unmounting SFTPFS")
            background {
                let unmountEvent = UnmountEvent(askForOpenApps: false, force: true)
                NotificationCenter.default.post(name: Notification.Name.volumeShouldUnmount, object: unmountEvent)
            }
            // force this call stack to block to prevent the machine from
            // sleeping. the system is supposed to allow up to 30 seconds if we
            // delay this notification from returning, so we issue an async force
            // unmount notification and then sleep as long as possible
            var limit: TimeInterval = 24
            repeat {
                if limit <= 0 {
                    break
                }
                limit -= 1
                Thread.sleep(forTimeInterval: 1)
            } while self.mounted
            
            Thread.sleep(forTimeInterval: 5)

            SDLogInfo("MountController", "asking machine to sleep")

            // now tell the machine to sleep again
            let source = "tell application \"Finder\"\nsleep\nend tell"
            let script = NSAppleScript(source: source)
            script?.executeAndReturnError(nil)
        }
    }
    
    @objc func didWake(_ notification: Notification) {
        if self.mounted {
            SDLogWarn("MountController", "machine woke up, re-mounting SFTPFS")
            main {
                // This should cause a remount if the drive isn't mounted anymore
                //
                // TODO: will need to ensure the drive actually unmounts before
                //       sleep, otherwise this won't really help anything
                self.lastMountAttempt = nil
            }
        }
    }
}

extension MountController: SDAccountProtocol {
    
    // MARK: SDAccountProtocol
    
    func didSignIn(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignIn called on background thread")
        guard let accountStatus = notification.object as? SDKAccountStatus else {
            SDLogError("MountController", "API contract invalid: didSignIn()")
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
            SDLogError("MountController", "API contract invalid: didReceiveAccountStatus()")
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
    }
    
    func volumeDidUnmount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeDidMount called on background thread")

        self.openFileWarning.stop()
        
        let u = self.currentMountURL as NSURL
        if !u.removeFavoriteItem() {
            SDLogWarn("MountController", "Failed to remove mountpoint from Finder sidebar favorites list")
        }
        
        if !u.removeFavoriteVolume() {
            SDLogWarn("MountController", "Failed to remove mountpoint from Finder sidebar volumes list")
        }
    }
    
    func volumeSubprocessDidTerminate(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeSubprocessDidTerminate called on background thread")

    
    }
    
    func volumeShouldMount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeShouldMount called on background thread")

        self.connectVolume()
    }
    
    func volumeShouldUnmount(notification: Notification) {
        guard let unmountEvent = notification.object as? UnmountEvent else {
            SDLogError("MountController", "API contract invalid: volumeShouldUnmount()")
            return
        }
        self.disconnectVolume(askForOpenApps: unmountEvent.askForOpenApps, force: unmountEvent.force)
    }

    func volumeMounting(notification: Notification) {
        
    }
    
    func volumeUnmounting(notification: Notification) {
        
    }
    
    func volumeMountFailed(notification: Notification) {
        guard let _ = notification.object as? SDError else {
            SDLogError("MountController", "API contract invalid: volumeMountFailed()")
            return
        }
    }
    
    func volumeUnmountFailed(notification: Notification) {
        guard let _ = notification.object as? SDError else {
            SDLogError("MountController", "API contract invalid: volumeUnmountFailed()")
            return
        }
    }
}


extension MountController: OpenFileWarningDelegate {
    func closeApplication(_ process: RunningProcess) {
        SDLogDebug("MountController", "attempting to close \(process.command) (\(process.pid))")
        
        if process.isUserApplication {
            for app in NSWorkspace.shared.runningApplications {
                if process.pid == Int(app.processIdentifier) {
                    SDLogDebug("MountController", "found \(process.pid), terminating")
                    app.terminate()
                }
            }
        } else {
            let r = RunningProcessCheck()
            r.close(pid: process.pid)
        }
    }
    
    func runningProcesses() -> [RunningProcess] {
        SDLogDebug("MountController", "checking running processes")
        let r = RunningProcessCheck()

        return r.runningProcesses()
    }
    
    func blockingProcesses(_ url: URL) -> [RunningProcess] {
        SDLogDebug("MountController", "checking blocking processes")
        let c = OpenFileCheck()

        return c.check(volume: url)
    }
    
    func tryAgain() {
        self.disconnectVolume(askForOpenApps: false, force: false)
    }
    
    func finished() {
        self.openFileWarning.stop()
    }
}

extension MountController: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let _ = notification.object as? Client else {
            SDLogError("MountController", "API contract invalid: applicationDidConfigureClient()")
            
            return
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let currentUser = notification.object as? User else {
            SDLogError("MountController", "API contract invalid: applicationDidConfigureUser()")
            
            return
        }
        
        self.email = currentUser.email
        self.password = currentUser.password
    }
}
