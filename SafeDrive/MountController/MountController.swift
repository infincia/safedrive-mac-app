
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length


import Foundation
import SafeDriveSDK

class MountController: NSObject {
    fileprivate var _mounted = false
    
    fileprivate let mountStateQueue = DispatchQueue(label: "io.safedrive.mountStateQueue")
    
    fileprivate var _mounting = false
    
    fileprivate let mountingQueue = DispatchQueue(label: "io.safedrive.mountingQueue")
    
    fileprivate var _signedIn = false
    
    fileprivate let signedInQueue = DispatchQueue(label: "io.safedrive.signedInQueue")
    
    fileprivate var _lastMountAttempt: Date? = nil
    
    fileprivate let lastMountAttemptQueue = DispatchQueue(label: "io.safedrive.lastMountAttemptQueue")
    
    
    fileprivate var mountURL: URL?
    
    fileprivate var sshfsTask: Process!
        
    static let shared = MountController()
    
    fileprivate var openFileWarning: OpenFileWarningWindowController?
    
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
    
    var currentMountURL: URL {
        let home = NSHomeDirectory()
        let volumesDirectoryURL = URL(fileURLWithPath: home, isDirectory:true)
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
        
        
        let nc = NSWorkspace.shared().notificationCenter
        nc.addObserver(self, selector: #selector(willSleep(_:)), name: Notification.Name.NSWorkspaceWillSleep, object: nil)
        
        
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
        assert(Thread.current == Thread.main, "Mount check called on background thread")
        DispatchQueue.global(priority: .default).async {
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
        
        DispatchQueue.global(priority: .default).async {
            do {
                try NSWorkspace.shared().unmountAndEjectDevice(at: self.currentMountURL)
                DispatchQueue.main.async {
                    self.mountURL = nil
                    NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object:nil)
                    successBlock(self.currentMountURL)
                }
            } catch let error as NSError {
                DispatchQueue.main.async {
                    failureBlock(self.currentMountURL, error)
                }
            }
        }

    }
    
    // MARK: warning Needs slight refactoring
    func mountStateLoop() {
        DispatchQueue.global(priority: .default).async {
            while true {
                let mountCheck = self.checkMount(at: self.currentMountURL)
                
                DispatchQueue.main.sync(execute: {() -> Void in
                    self.mounted = mountCheck
                })
                
                if self.mounted {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object:self.mountDetails)
                        NotificationCenter.default.post(name: Notification.Name.mounted, object:nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object:nil)
                        NotificationCenter.default.post(name: Notification.Name.unmounted, object:nil)
                    }
                }
                
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
    
    func mountLoop() {
        
        DispatchQueue.global(priority: .default).async {
            
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
                        var now = Date()
                        
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
    
    func startMountTask(sshURL: URL, success successBlock: @escaping (_ mount: URL) -> Void, failure failureBlock: @escaping (_ mount: URL, _ error: Error) -> Void) {
        assert(Thread.current == Thread.main, "SSHFS task started from background thread")
        
        let mountURL = self.currentMountURL
        let volumeName = self.currentVolumeName

        /*
         This is mostly insurance against running 2 sshfs processes at once, or
         double-mounting. Disabling the login button when a mount succeeds should
         prevent the code from ever running.
         */
        if self.mounted {
            successBlock(mountURL)
            return
        }
        
        
        // MARK: - Create the mount path directory if it doesn't exist
        
        
        let fileManager = FileManager.default
        
        
        do {
            try fileManager.createDirectory(at: mountURL, withIntermediateDirectories:true, attributes:nil)
        } catch let error as NSError {
            failureBlock(mountURL, error)
            return
        }
        
        
        // MARK: - Retrieve necessary parameters from ssh url
        let serverPath = sshURL.path
        guard let host = sshURL.host,
            let port = sshURL.port,
            let user = sshURL.user else {
                let message = NSLocalizedString("Credentials missing, contact SafeDrive support", comment: "")
                let error = SDError(message: message, kind: .apiContractInvalid)
                failureBlock(mountURL, error)
                return
        }
        SDLog("Mounting ssh URL: \(sshURL)")
        
        
        // MARK: - Create the subprocess to be configured below
        
        self.sshfsTask = Process()
        
        guard let componentsURL = Bundle.main.url(forResource: "Components", withExtension: "bundle"),
            let components = Bundle.init(url: componentsURL) else {
            let message = NSLocalizedString("Components missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .configMissing)
            DispatchQueue.main.async {
                failureBlock(mountURL, error)
            }
            return
        }
        
        guard let sshfsPath = components.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.sshfs") else {
            let message = NSLocalizedString("SSHFS missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .sshfsMissing)
            failureBlock(mountURL, error)
            return
        }
        self.sshfsTask.launchPath = sshfsPath
        
        // MARK: - Set custom environment variables for sshfs subprocess
        
        var sshfsEnvironment = [String: String]()

        /* path of our custom askpass helper so ssh can use it */
        guard let safeDriveAskpassPath = components.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.askpass") else {
            let message = NSLocalizedString("Askpass helper missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .askpassMissing)
            failureBlock(mountURL, error)
            return
        }
        
        sshfsEnvironment["SSH_ASKPASS"] = safeDriveAskpassPath
        
        /* pass the account password to the safedriveaskpass environment */
        //sshfsEnvironment["SSH_PASSWORD"] = self.password
        
        /*
         remove any existing SSH agent socket in the subprocess environment so we
         have full control over auth behavior
         */
        sshfsEnvironment.removeValue(forKey: "SSH_AUTH_SOCK")
        
        /*
         Set a blank DISPLAY environment variable. This is critical for making
         sure that OpenSSH actually runs our custom askpass binary, even though
         X11 isn't being used at all.
         
         If you're reading this code or working on it, just be aware that SSH auth
         relying on an askpass will *fail* 100% of the time without this variable
         set, even though it's blank.
         
         For the reason, see below.
         
         ------------------------------------------------------------------------
         
         OpenSSH will only run an askpass binary if a DISPLAY environment variable
         is set. On OS X, that variable isn't present unless XQuartz is installed.
         
         Given that the original purpose of askpass was to display a GUI password
         prompt using X11, this behavior makes some sense. If DISPLAY isn't set,
         OpenSSH assumes the askpass won't be able to function because it won't
         have access to X11, so it doesn't even try to run the askpass.
         
         It's a flawed assumption now, particularly on systems that don't rely on
         X11 for native display, but Apple's version of OpenSSH doesn't patch it
         out (likely because they don't use or even ship an askpass with OS X).
         
         Lastly, this only overrides the variable for the SSHFS process environment,
         it won't interfere with use of XQuartz at all.
         
         */
        
        //MARK: warning DO NOT REMOVE THIS. See above comment for the reason.
        sshfsEnvironment["DISPLAY"] = ""
        
        if isProduction() {
            sshfsEnvironment["SAFEDRIVE_ENVIRONMENT_PRODUCTION"] = "1"
        }

        //SDLog("Subprocess environment: \(sshfsEnvironment)")
        self.sshfsTask.environment = sshfsEnvironment
        
        
        // MARK: - Set SSHFS subprocess arguments
        
        var taskArguments = [String]()
        
        /* server connection */
        taskArguments.append("\(user)@\(host):\(serverPath)")
        
        /* mount location */
        taskArguments.append(mountURL.path)
        
        /* our own ssh binary */
        guard let _ = components.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.ssh") else {
            let message = NSLocalizedString("SSH missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .sshMissing)
            failureBlock(mountURL, error)
            return
        }
        //taskArguments.append("-ossh_command=\(sshPath)")

        /* basic sshfs options */
        taskArguments.append("-oauto_cache")
        taskArguments.append("-oreconnect")
        taskArguments.append("-odefer_permissions")
        taskArguments.append("-onoappledouble")
        taskArguments.append("-onegative_vncache")
        
        /*
         Use a bundled known_hosts file as static root of trust.
         
         This serves two purposes:
         
         1. Users never have to click through fingerprint verification
         prompts, or manually verify the fingerprint (most people won't).
         We don't currently have code for scripting that part of an initial
         ssh connection anyway, and it's not clear if we can even get sshfs
         to put ssh in the right mode to print the fingerprint prompt on
         stdout while running as a background process using SSH_ASKPASS
         for authentication.
         
         2. Users are never going to be subject to man-in-the-middle attacks
         as the fingerprint is preconfigured in the app
         */
        
        
        guard let knownHostsFile = Bundle.main.url(forResource: "known_hosts", withExtension: nil) else {
            let message = NSLocalizedString("SSH hosts file missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .configMissing)
            failureBlock(mountURL, error)
            return
        }
        
        let tempHostsFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: knownHostsFile, to: tempHostsFile)
        } catch {
            let message = NSLocalizedString("Cannot create temporary file, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .temporaryFile)
            failureBlock(mountURL, error)
            return
        }
        
        taskArguments.append("-oUserKnownHostsFile=\"\(tempHostsFile.path)\"")

        
        
        /* bundled config file to avoid environment differences */
        guard let configFile = Bundle.main.url(forResource: "ssh_config", withExtension: nil) else {
            let message = NSLocalizedString("SSH config missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .askpassMissing)
            failureBlock(mountURL, error)
            return
        }
        
        let tempConfigFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: configFile, to: tempConfigFile)
        } catch {
            let message = NSLocalizedString("Cannot create temporary file, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .temporaryFile)
            failureBlock(mountURL, error)
            return
        }
        taskArguments.append("-F\(tempConfigFile.path)")
        
        
        /* custom volume name */
        taskArguments.append("-ovolname=\(volumeName)")
        
        /* custom port if needed */
        taskArguments.append("-p\(port)")
        
        self.sshfsTask.arguments = taskArguments
        
        
        // MARK: - Set asynchronous block to handle subprocess stderr and stdout
        
        let outputPipe = Pipe()
        
        let outputPipeHandle = outputPipe.fileHandleForReading
        
        outputPipeHandle.readabilityHandler = { (handle) in
            var error: SDError?

            // swiftlint:disable force_unwrapping
            let outputString = String(data: handle.availableData, encoding: String.Encoding.utf8)!
            // swiftlint:enable force_unwrapping

            if outputString.contains("key_load_public: No such file or directory") {
                // refers to searching for ssh keys in debug1 mode
            } else if outputString.contains("Not a directory") {
                let message = NSLocalizedString("Server could not find that volume name", comment: "")
                error = SDError(message: message, kind: .mountFailed)
            } else if outputString.contains("Permission denied (publickey,password)") {
                let message = NSLocalizedString("Check username/password", comment: "")
                error = SDError(message: message, kind: .authorization)
            } else if outputString.contains("is itself on a OSXFUSE volume") {
                let message = NSLocalizedString("Volume already mounted", comment: "")
                error = SDError(message: message, kind: .alreadyMounted)
                /*
                 no need to run the successblock again since the volume is already mounted
                 
                 this is unlikely to happen in practice, we shouldn't even get to this
                 point if the mount status code is reacting quickly
                 
                 this case may occur if the SafeDrive app quits/crashes but the sshfs process
                 remains running and mounted. We'll deal with that at startup time
                 since we'll be constantly watching for mount/unmount anyway
                 */
                //successBlock();
            } else if outputString.contains("Error resolving hostname") {
                let message = NSLocalizedString("SafeDrive service unavailable", comment: "")
                error = SDError(message: message, kind: .mountFailed)
            } else if outputString.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") {
                let message = NSLocalizedString("Warning: server fingerprint changed!", comment: "")
                error = SDError(message: message, kind: .hostFingerprintChanged)
            } else if outputString.contains("Host key verification failed") {
                let message = NSLocalizedString("Warning: server key verification failed!", comment: "")
                error = SDError(message: message, kind: .hostKeyVerificationFailed)
            } else if outputString.contains("failed to mount") {
                let message = NSLocalizedString("An unknown error occurred, contact support", comment: "")
                error = SDError(message: message, kind: .mountFailed)
            } else if outputString.contains("g_slice_set_config: assertion") {
                /*
                 Ignore this, minor bug in sshfs use of glib
                 
                 */
            } else if outputString.contains("No such file or directory") {
                let message = NSLocalizedString("An unknown error occurred, contact support", comment: "")
                error = SDError(message: message, kind: .directoryMissing)
            } else {
                let message = NSLocalizedString("An unknown error occurred, contact support", comment: "")
                error = SDError(message: message, kind: .unknown)
                /*
                 for the moment we don't want to call the failure block here, as
                 not everything that comes through stderr indicates a mount
                 failure.
                 
                 testing is required to discover and handle the stderr output that
                 we actually need to handle and ignore the rest.
                 
                 */
                SDLog("SSHFS Task output: %@", outputString)
                // failureBlock(mountURL, mountError);
                return
            }
            if let e = error {
                DispatchQueue.main.async {
                    failureBlock(mountURL, e)
                }
                SDLog("SSHFS Task error: \(e), \(e.localizedDescription)")
            }
        }
        self.sshfsTask.standardError = outputPipe
        self.sshfsTask.standardOutput = outputPipe
        
        
        // MARK: - Set asynchronous block to handle subprocess termination
        
        
        /*
         clear the read and write blocks once the subprocess terminates, and then
         call the success block if no error occurred.
         
         */
        weak var weakSelf: MountController? = self
        self.sshfsTask.terminationHandler = { (task: Process) in
            outputPipeHandle.readabilityHandler = nil
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    weakSelf?.mountURL = mountURL
                    successBlock(mountURL)
                }
            }
        }
        
        
        // MARK: - Launch subprocess and return
        
        
        //SDLog(@"Launching SSHFS with arguments: %@", taskArguments);
        self.sshfsTask.launch()
    }
    
    // MARK: - High level API
    
    func connectVolume() {
        
        guard let user = self.internalUserName,
            let host = self.remoteHost,
            let port = self.remotePort else {
                SDLog("API contract invalid: connectVolume in MountController")
                Crashlytics.sharedInstance().crash()
                return
        }
        
        
    
        self.mounting = true
    
        var urlComponents = URLComponents()
        urlComponents.user = user
        urlComponents.host = host
        urlComponents.path = defaultServerPath()
        urlComponents.port = Int(port)
        
        // swiftlint:disable force_unwrapping
        let sshURL: URL = urlComponents.url!
        // swiftlint:enable force_unwrapping
        let notification = NSUserNotification()
        
        self.startMountTask(sshURL: sshURL, success: { mountURL in
            
            /*
             now check for a successful mount. if after 30 seconds there is no volume
             mounted, it is a fair bet that an error occurred in the meantime
             */
            
            self.checkMount(at: mountURL, timeout: 30, mounted: {
                NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
                self.mounting = false
            }, notMounted: {
                let message = NSLocalizedString("Volume mount timeout", comment: "")
                let error = SDError(message: message, kind: .timeout)
                SDLog("SafeDrive checkForMountedVolume failure in mount controller: \(error)")
                notification.informativeText = error.localizedDescription
                notification.title = "SafeDrive mount error"
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
                
                self.mounting = false
            })
            
            
        }, failure: { (_, error) in
            self.mounting = false
            // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
            if let e = error as? SDError, e.kind == .alreadyMounted {
                NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
            } else {
                SDLog("SafeDrive startMountTaskWithVolumeName failure in mount controller: \(error)")
                notification.informativeText = error.localizedDescription
                notification.title = "SafeDrive mount error"
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
                SDErrorHandlerReport(error)
                self.unmount(success: { _ in
                    //
                }, failure: { (_, _) in
                    //
                })
            }
        })
    }
    
    func disconnectVolume(askForOpenApps: Bool) {
    
        let volumeName: String = self.currentVolumeName
        
        SDLog("Dismounting volume: %@", volumeName)
        
        DispatchQueue.global(priority: .high).async {
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
                            self.openFileWarning = OpenFileWarningWindowController(delegate: self, url: url, processes: processes)
                            
                            NSApp.activate(ignoringOtherApps: true)
                            
                            // swiftlint:disable force_unwrapping
                            self.openFileWarning!.showWindow(self)
                            // swiftlint:enable force_unwrapping

                        }
                    }
                } else if code == fnfErr {
                    notification.informativeText = NSLocalizedString("This is a bug in OS X, reboot may help", comment: "")
                } else {
                    notification.informativeText = NSLocalizedString("Unknown error occurred (\(code))", comment: "")
                }

                notification.title = "SafeDrive unmount failed"
                
                notification.soundName = NSUserNotificationDefaultSoundName
                
                NSUserNotificationCenter.default.deliver(notification)
                
            })
        }
    }
    
}

extension MountController: SleepReactor {
    func willSleep(_ notification: Notification) {
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

        if let u = self.mountURL {
            NSWorkspace.shared().open(u)
        }
    }
    
    func volumeDidUnmount(notification: Notification) {
        assert(Thread.current == Thread.main, "volumeDidMount called on background thread")

        //self.openFileWarning?.window?.close()
        //self.openFileWarning = nil
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
            for app in NSWorkspace.shared().runningApplications {
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
        //self.openFileWarning?.window?.close()
        //self.openFileWarning = nil
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
