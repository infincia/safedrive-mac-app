
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

class MountController: NSObject {
    var mounted = false
    var mounting = false
    var mountURL: URL!
    
    var sshfsTask: Process!
    
    var sharedSystemAPI = SDSystemAPI.shared()

    static let shared = MountController()
    
    override init() {
        super.init()
        self.mounted = false
        self.mounting = false
        mountStateLoop()
    }

    func unmountVolume(name volumeName:String!, success successBlock: @escaping (_ mount: URL) -> Void, failure failureBlock: @escaping (_ mount: URL, _ error: Error) -> Void) {
        let mountURL = self.mountURL(forVolumeName: volumeName)
        weak var weakSelf: MountController? = self
        self.sharedSystemAPI.ejectMount(mountURL, success:{ 
            successBlock(mountURL)
            weakSelf?.mountURL = nil
            NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object:nil)
        }, failure:{ (error: Error) in
            failureBlock(mountURL, error)
        })
    }


    func mountURL(forVolumeName name: String) -> URL {
        let home = NSHomeDirectory()
        let volumesDirectoryURL = URL(fileURLWithPath: home, isDirectory:true)
        let mountURL = volumesDirectoryURL.appendingPathComponent(name)
        return mountURL
    }


// MARK: warning Needs slight refactoring
    func mountStateLoop() {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            while true {
                let volumeName = self.sharedSystemAPI.currentVolumeName
                let mountURL = self.mountURL(forVolumeName: volumeName)
                let mountCheck = self.sharedSystemAPI.check(forMountedVolume: mountURL)

                DispatchQueue.main.sync(execute: {() -> Void in
                    self.mounted = mountCheck
                })
                
                if self.mounted {
                    let mountDetails = self.sharedSystemAPI.details(forMount: mountURL)
                    DispatchQueue.main.sync(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object:mountDetails)
                        NotificationCenter.default.post(name: Notification.Name.mounted, object:nil)
                    })
                }
                else {
                    DispatchQueue.main.sync(execute: {() -> Void in
                        NotificationCenter.default.post(name: Notification.Name.mountDetails, object:nil)
                        NotificationCenter.default.post(name: Notification.Name.unmounted, object:nil)
                    })
                }
                
                Thread.sleep(forTimeInterval: 1)
             }
        })
    }

    func startMountTask(volumeName: String, sshURL: URL, success successBlock: @escaping (_ mount: URL) -> Void, failure failureBlock: @escaping (_ mount: URL, _ error: Error) -> Void) {
        assert(Thread.current == Thread.main, "SSHFS task started from background thread")

        let mountURL = self.mountURL(forVolumeName: volumeName)

        /* 
            This is mostly insurance against running 2 sshfs processes at once, or
            double-mounting. Disabling the login button when a mount succeeds should 
            prevent the code from ever running.
        */
        if self.mounted {
            let mountError:NSError! = NSError(domain: SDErrorUIDomain, code:SDMountError.alreadyMounted.rawValue, userInfo:[NSLocalizedDescriptionKey: "Volume already mounted"])
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
        
        guard let sshfsPath = Bundle.main.path(forAuxiliaryExecutable: "sshfs-2.7") else {
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


        /* pass the account name to the safedriveaskpass environment */
        sshfsEnvironment["SSH_ACCOUNT"] = user
        
        /* pass the current keychain ssh credential domain to the askpass environment */
        sshfsEnvironment["SDSSHServiceName"] = sshCredentialDomain()

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
            let outputString:String! = String(data:handle.availableData, encoding:String.Encoding.utf8)
            var mountError:NSError!

            if outputString.contains("No such file or directory") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Server could not find that volume name"])
            }
            else if outputString.contains("Not a directory") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Server could not find that volume name"])
            }
            else if outputString.contains("Permission denied") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDSSHError.authorization.rawValue, userInfo:[NSLocalizedDescriptionKey: "Permission denied"])
            }
            else if outputString.contains("is itself on a OSXFUSE volume") {
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
            }
            else if outputString.contains("Error resolving hostname") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Error resolving hostname, contact support"])
            }
            else if outputString.contains("remote host has disconnected") {
                mountError = NSError(domain: SDErrorUIDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Mount failed, check username and password"])
            }
            else if outputString.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDSSHError.hostFingerprintChanged.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server fingerprint changed!"])
            }
            else if outputString.contains("Host key verification failed") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDSSHError.hostKeyVerificationFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server key verification failed!"])
            }
            else if outputString.contains("failed to mount") {
                mountError = NSError(domain: SDMountErrorDomain, code:SDMountError.mountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "An unknown error occurred, contact support"])
            }
            else if outputString.contains("g_slice_set_config: assertion") {
                /*
                 Ignore this, minor bug in sshfs use of glib

                 */
            }
            else {
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
            if (mountError != nil) {
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
                DispatchQueue.main.sync(execute: {() -> Void in
                    weakSelf?.mountURL = mountURL
                    successBlock(mountURL)
                })
            }
        }


    // MARK: - Launch subprocess and return


        //SDLog(@"Launching SSHFS with arguments: %@", taskArguments);
        self.sshfsTask.launch()
    }

}
