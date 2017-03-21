
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import SafeDriveSDK

class MountController: NSObject {
    fileprivate var _mounted = false
    
    fileprivate let mountStateQueue = DispatchQueue(label: "io.safedrive.mountStateQueue")
    
    fileprivate var _mounting = false
    
    fileprivate let mountingQueue = DispatchQueue(label: "io.safedrive.mountingQueue")
    
    var mountURL: URL?
    
    var sshfsTask: Process!
        
    static let shared = MountController()
    
    fileprivate var openFileWarning: OpenFileWarningWindowController?
    
    var email: String?
    var internalUserName: String?
    var password: String?
    
    var remoteHost: String?
    var remotePort: UInt16?
    
    var currentVolumeName: String {
        if let volumeName = UserDefaults.standard.string(forKey: SDCurrentVolumeNameKey) {
            return volumeName
        }
        return SDDefaultVolumeName
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
            return UserDefaults.standard.bool(forKey: SDMountAtLaunchKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: SDMountAtLaunchKey)
        }
    }
    
    var mounted: Bool {
        get {
            var r: Bool?
            mountStateQueue.sync {
                r = self._mounted
            }
            return r!
        }
        set (newValue) {
            mountStateQueue.sync(flags: .barrier, execute: {
                self._mounted = newValue
            })
        }
    }
    
    var mounting: Bool {
        get {
            var r: Bool?
            mountingQueue.sync {
                r = self._mounting
            }
            return r!
        }
        set (newValue) {
            mountingQueue.sync(flags: .barrier, execute: {
                self._mounting = newValue
            })
        }
    }
    
    override init() {
        super.init()
        self.mounted = false
        self.mounting = false
        
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureRealm), name: Notification.Name.applicationDidConfigureRealm, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        
        let nc = NSWorkspace.shared().notificationCenter
        nc.addObserver(self, selector: #selector(willSleep(_:)), name: Notification.Name.NSWorkspaceWillSleep, object: nil)
        
        
        mountStateLoop()
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
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
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
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
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
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            while true {
                let mountCheck = self.checkMount(at: self.currentMountURL)
                
                DispatchQueue.main.sync(execute: {() -> Void in
                    self.mounted = mountCheck
                })
                
                if self.mounted {
                    DispatchQueue.main.async(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object:self.mountDetails)
                        NotificationCenter.default.post(name: Notification.Name.mounted, object:nil)
                    })
                } else {
                    DispatchQueue.main.async(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object:nil)
                        NotificationCenter.default.post(name: Notification.Name.unmounted, object:nil)
                    })
                }
                
                Thread.sleep(forTimeInterval: 1)
            }
        })
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
            let mountError: NSError! = NSError(domain: SDErrorUIDomain, code: SDMountError.alreadyMounted.rawValue, userInfo: [NSLocalizedDescriptionKey: "Volume already mounted"])
            failureBlock(mountURL, mountError)
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
                let sshfsError = NSError(domain: SDMountErrorDomain, code:SDSystemError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: message])
                failureBlock(mountURL, sshfsError)
                return
        }
        SDLog("Mounting ssh URL: \(sshURL)")
        
        
        // MARK: - Create the subprocess to be configured below
        
        self.sshfsTask = Process()
        
        guard let sshfsPath = Bundle.main.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.sshfs") else {
            let message = NSLocalizedString("SSHFS missing, contact SafeDrive support", comment: "")
            let sshfsError = NSError(domain: SDMountErrorDomain, code:SDSystemError.sshfsMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: message])
            failureBlock(mountURL, sshfsError)
            return
        }
        self.sshfsTask.launchPath = sshfsPath
        
        // MARK: - Set custom environment variables for sshfs subprocess
        
        var sshfsEnvironment = ProcessInfo.processInfo.environment
        
        /* path of our custom askpass helper so ssh can use it */
        guard let safeDriveAskpassPath = Bundle.main.path(forAuxiliaryExecutable: "safedriveaskpass") else {
            let askpassError = NSError(domain: SDMountErrorDomain, code:SDSystemError.askpassMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: "Askpass helper missing"])
            failureBlock(mountURL, askpassError)
            return
        }
        
        sshfsEnvironment["SSH_ASKPASS"] = safeDriveAskpassPath
        
        
        /* pass the account password to the safedriveaskpass environment */
        sshfsEnvironment["SSH_PASSWORD"] = self.password
        
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
        
        //SDLog("Subprocess environment: \(sshfsEnvironment)")
        self.sshfsTask.environment = sshfsEnvironment
        
        
        // MARK: - Set SSHFS subprocess arguments
        
        var taskArguments = [String]()
        
        /* server connection */
        taskArguments.append("\(user)@\(host):\(serverPath)")
        
        /* mount location */
        taskArguments.append(mountURL.path)
        
        /* basic sshfs options */
        taskArguments.append("-oauto_cache")
        taskArguments.append("-oreconnect")
        taskArguments.append("-odefer_permissions")
        taskArguments.append("-onoappledouble")
        taskArguments.append("-onegative_vncache")
        taskArguments.append("-oNumberOfPasswordPrompts=1")
        
        /*
         This shouldn't be necessary and I don't like it, but it'll work for
         testing purposes until we can implement a UI and code for displaying
         server fingerprints and allowing users to check and accept them or use
         the bundled known_hosts file to preapprove server fingerprints
         */
        taskArguments.append("-oCheckHostIP=no")
        taskArguments.append("-oStrictHostKeyChecking=no")
        
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
        //NSString *knownHostsFile = [[NSBundle mainBundle] pathForResource:@"known_hosts" ofType:nil];
        //SDLog(@"Known hosts file: %@", knownHostsFile);
        //[taskArguments addObject:[NSString stringWithFormat:@"-oUserKnownHostsFile=%@", knownHostsFile]];
        
        /* custom volume name */
        taskArguments.append("-ovolname=\(volumeName)")
        
        /* custom port if needed */
        taskArguments.append("-p\(port)")
        
        self.sshfsTask.arguments = taskArguments
        
        
        // MARK: - Set asynchronous block to handle subprocess stderr and stdout
        
        let outputPipe = Pipe()
        
        let outputPipeHandle = outputPipe.fileHandleForReading
        
        outputPipeHandle.readabilityHandler = { (handle) in
            let outputString: String! = String(data: handle.availableData, encoding: String.Encoding.utf8)
            var mountError: NSError!
            
            if outputString.contains("No such file or directory") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Server could not find that volume name"])
            } else if outputString.contains("Not a directory") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Server could not find that volume name"])
            } else if outputString.contains("Permission denied") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDSSHError.authorization.rawValue, userInfo:[NSLocalizedDescriptionKey: "Permission denied"])
            } else if outputString.contains("is itself on a OSXFUSE volume") {
                mountError = NSError(domain: SDErrorUIDomain, code:SDMountError.alreadyMounted.rawValue, userInfo:[NSLocalizedDescriptionKey: "Volume already mounted"])
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
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Error resolving hostname, contact support"])
            } else if outputString.contains("remote host has disconnected") {
                mountError = NSError(domain: SDErrorUIDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Mount failed, check username and password"])
            } else if outputString.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDSSHError.hostFingerprintChanged.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server fingerprint changed!"])
            } else if outputString.contains("Host key verification failed") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDSSHError.hostKeyVerificationFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server key verification failed!"])
            } else if outputString.contains("failed to mount") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "An unknown error occurred, contact support"])
            } else if outputString.contains("g_slice_set_config: assertion") {
                /*
                 Ignore this, minor bug in sshfs use of glib
                 
                 */
            } else {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: "An unknown error occurred, contact support"])
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
            if mountError != nil {
                DispatchQueue.main.async(execute: {() -> Void in
                    failureBlock(mountURL, mountError)
                })
                SDLog("SSHFS Task error: %lu, %@", mountError.code, mountError.localizedDescription)
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
                DispatchQueue.main.async(execute: {() -> Void in
                    weakSelf?.mountURL = mountURL
                    successBlock(mountURL)
                })
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
        urlComponents.path = SDDefaultServerPath
        urlComponents.port = Int(port)
        let sshURL: URL = urlComponents.url!
        
        self.startMountTask(sshURL: sshURL, success: { mountURL in
            
            /*
             now check for a successful mount. if after 30 seconds there is no volume
             mounted, it is a fair bet that an error occurred in the meantime
             */
            
            self.checkMount(at: mountURL, timeout: 30, mounted: {
                NotificationCenter.default.post(name: Notification.Name.volumeDidMount, object: nil)
                self.mounting = false
            }, notMounted: {
                let error = NSError(domain:SDErrorDomain, code:SDSSHError.timeout.rawValue, userInfo:[NSLocalizedDescriptionKey: "Volume mount timeout"])
                SDLog("SafeDrive checkForMountedVolume failure in mount controller: \(error)")
                self.mounting = false
            })
            
            
        }, failure: { (_, mountError) in
            SDLog("SafeDrive startMountTaskWithVolumeName failure in mount controller: \(mountError)")
            SDErrorHandlerReport(mountError)
            self.mounting = false
            // NOTE: This is a workaround for an issue in SSHFS where a volume can both fail to mount but still end up in the mount table
            self.unmount(success: { _ in
                //
            }, failure: { (_, _) in
                //
            })
        })
    }
    
    func disconnectVolume(askForOpenApps: Bool) {
    
        let volumeName: String = self.currentVolumeName
        
        SDLog("Dismounting volume: %@", volumeName)
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high).async {
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
                        DispatchQueue.main.async(execute: {() -> Void in
                            self.openFileWarning = OpenFileWarningWindowController(delegate: self, url: url, processes: processes)
                            
                            NSApp.activate(ignoringOtherApps: true)
                            
                            self.openFileWarning!.showWindow(self)
                        })
                    }
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

        guard let currentUser = notification.object as? User else {
            return
        }
        
        self.email = currentUser.email
        self.password = currentUser.password
        
        // only mount SSHFS automatically if the user set it to automount
        if self.automount {
            self.checkMount(at: self.currentMountURL, timeout: 30, mounted: {

            }, notMounted: {
                self.connectVolume()
            })
        }
    }
    
    func didSignOut(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didSignOut called on background thread")

        self.email = nil
        self.internalUserName = nil
        self.password = nil
        
        self.remoteHost = nil
        self.remotePort = nil
    }
    
    func didReceiveAccountStatus(notification: Foundation.Notification) {
        assert(Thread.current == Thread.main, "didReceiveAccountStatus called on background thread")

        guard let accountStatus = notification.object as? AccountStatus else {
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

        NSWorkspace.shared().open((self.mountURL)!)
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
    func applicationDidConfigureRealm(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureRealm called on background thread")

    }
    
    func applicationDidConfigureClient(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureClient called on background thread")

        guard let _ = notification.object as? String else {
            SDLog("API contract invalid: applicationDidConfigureClient in MountController")
            
            return
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        assert(Thread.current == Thread.main, "applicationDidConfigureUser called on background thread")

        guard let _ = notification.object as? User else {
            SDLog("API contract invalid: applicationDidConfigureUser in MountController")
            
            return
        }
    }
}
