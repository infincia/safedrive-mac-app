
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length

import SafeDriveSDK

class SyncController: Equatable {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var syncTask: Process!
    fileprivate var syncFailure = false
    fileprivate var syncTerminated = false
    fileprivate let syncProgressQueue = DispatchQueue(label: "io.safedrive.SafeDrive.syncprogress", attributes: [])
    fileprivate let syncResultQueue = DispatchQueue.main

    var uniqueID: UInt64!
    
    var encrypted: Bool = false
    
    var restore: Bool = false
    
    var localURL: URL!
    
    var serverURL: URL!
    
    var password: String!
    
    var uuid: String!
    
    var spaceNeeded: UInt64?
    
    var destination: URL?
    
    
    static func == (left: SyncController, right: SyncController) -> Bool {
        return (left.uniqueID == right.uniqueID)
    }
    
    func sftpOperation(_ operation: SDSFTPOperation, remoteDirectory serverURL: URL, password: String, success successBlock: @escaping () -> Void, failure failureBlock: @escaping (_ error: Error) -> Void) {
        if let l = NMSSHLogger.shared() {
            l.logLevel = NMSSHLogLevel.error
            l.logBlock = { (level, format) in
                //SDLog("\(format)")
            }
        }
        
        guard let host  = serverURL.host,
            let port  = serverURL.port,
            let user = serverURL.user else {
                let error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: "failed to unpack user information"])
                
                DispatchQueue.main.async(execute: {
                    failureBlock(error)
                })
                return
        }
        let machineDirectory = serverURL.deletingLastPathComponent()
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            guard let session = NMSSHSession.connect(toHost: host, port:port, withUsername:user),
                let channel = session.channel else {
                    let error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: "failed to create SSH session"])
                    
                    DispatchQueue.main.async(execute: {
                        failureBlock(error)
                    })
                    return
            }
            
            
            if session.isConnected {
                // this can be swapped out for a key method as needed
                session.authenticate(byPassword: password)
                
                if session.isAuthorized {
                    let sftp: NMSFTP! = NMSFTP.connect(with: session)
                    switch operation {
                    case SDSFTPOperation.moveFolder:
                        let storageDir = URL(string: "/storage/Storage/")!
                        let now = Date()
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd@HH-mm-ss"
                        dateFormatter.locale = Locale.current
                        let dateString = dateFormatter.string(from: now)
                        let newName = String(format:"%@ - %@", serverURL.lastPathComponent, dateString)
                        let destinationDir = storageDir.appendingPathComponent(newName, isDirectory:true)
                        SDLog("Moving SyncFolder %@ to %@", serverURL.path, destinationDir.path)
                        // we do a remote SSH command instead of SFTP, mv is more reliable apparently
                        
                        let command = "mv \"\(serverURL.path)\" \"\(destinationDir.path)\""
                        do {
                            try channel.execute(command) //, timeout:30)
                            DispatchQueue.main.async(execute: {
                                successBlock()
                            })
                        } catch let moveError as NSError {
                            let msg = "SSH: failed to move path: \(serverURL.path). \(moveError.localizedDescription)"
                            SDLog(msg)
                            let error: NSError! = NSError(domain: SDErrorSyncDomain, code: SDSSHError.sftpOperationFailure.rawValue, userInfo: [NSLocalizedDescriptionKey: msg])
                            
                            DispatchQueue.main.async(execute: {
                                failureBlock(error)
                            })
                        }
                        break
                        
                    case SDSFTPOperation.createFolder:
                        if sftp.directoryExists(atPath: machineDirectory.path) {
                            DispatchQueue.main.async(execute: {
                                successBlock()
                            })
                        } else if sftp.createDirectory(atPath: machineDirectory.path) {
                            DispatchQueue.main.async(execute: {
                                successBlock()
                            })
                        } else {
                            let msg = "SFTP: failed to create path: \(machineDirectory.path)"
                            SDLog(msg)
                            let error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.sftpOperationFailure.rawValue, userInfo:[NSLocalizedDescriptionKey: msg])
                            
                            DispatchQueue.main.async(execute: {
                                self.syncFailure = true
                                failureBlock(error)
                            })
                        }
                        break
                    case SDSFTPOperation.deleteFolder:
                        // we do a remote SSH command instead of SFTP, as there is no "rm -rf" command in SFTP
                        
                        let command = "rm -rf \"\(serverURL.path)\""
                        do {
                            try channel.execute(command) //, timeout:30)
                            DispatchQueue.main.async(execute: {
                                successBlock()
                            })
                        } catch let removeError as NSError {
                            let msg = "SSH: failed to remove path: \(serverURL.path). \(removeError.localizedDescription)"
                            SDLog(msg)
                            let error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.sftpOperationFailure.rawValue, userInfo:[NSLocalizedDescriptionKey: msg])
                            
                            DispatchQueue.main.async(execute: {
                                failureBlock(error)
                            })
                        }
                        break
                    }
                    sftp.disconnect()
                } else {
                    let error = NSError(domain: SDErrorUIDomain, code:SDSSHError.authorization.rawValue, userInfo:[NSLocalizedDescriptionKey: "SFTP: authorization failed"])
                    DispatchQueue.main.async(execute: {
                        self.syncFailure = true
                        failureBlock(error)
                    })
                }
            } else {
                let error = NSError(domain: SDErrorUIDomain, code:SDSSHError.timeout.rawValue, userInfo:[NSLocalizedDescriptionKey: "SFTP: failed to connect"])
                DispatchQueue.main.async(execute: {
                    self.syncFailure = true
                    failureBlock(error)
                })
            }
            // all cases should end up disconnecting the session and channel
            channel.closeShell()
            session.disconnect()
        })
    }
    
    // MARK:
    // MARK: Public API
    
    func stopSyncTask(_ completion: @escaping () -> Void) {
        self.syncTerminated = true
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high).async(execute: {
            if self.encrypted {
                // just ask the SDK to cancel it
                SafeDriveSDK.sharedSDK.cancelSyncTask(sessionName: self.uuid, completionQueue: DispatchQueue.main, success: { 
                    completion()
                }, failure: { (error) in
                    SDLog("unable to stop sync task for \(self.uuid): \(error)")
                })
            } else {
                // unencrypted sync has to stop the subprocess
                while  self.syncTask.isRunning {
                    self.syncTask.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                }
                DispatchQueue.main.async(execute: {
                    completion()
                })
            }
        })
        
    }
    
    func startSyncTask(progress progressBlock: @escaping (_ total: UInt64, _ current: UInt64, _ new: UInt64, _ percent: Double, _ bandwidth: String) -> Void,
                       issue issueBlock: @escaping (_ message: String) -> Void,
                       success successBlock: @escaping (_ local: URL) -> Void,
                       failure failureBlock: @escaping (_ local: URL, _ error: Error) -> Void) {
        if self.encrypted {
            startEncryptedSyncTask(progress: { (total, current, new, percent, bandwidth) in
                progressBlock(total, current, new, percent, bandwidth)
            }, issue: { (message) in
                issueBlock(message)
            }, success: { (url) in
                successBlock(url)
            }, failure: { (url, error) in
                failureBlock(url, error)
            })
        } else {
            startUnencryptedSyncTask(progress: { (total, current, new, percent, bandwidth) in
                progressBlock(total, current, new, percent, bandwidth)
            }, issue: { (message) in
                issueBlock(message)
            }, success: { (url) in
                successBlock(url)
            }, failure: { (url, error) in
                failureBlock(url, error)
            })
        }
        
    }
    
    fileprivate func startEncryptedSyncTask(progress progressBlock: @escaping (_ total: UInt64, _ current: UInt64, _ new: UInt64, _ percent: Double, _ bandwidth: String) -> Void,
                                            issue issueBlock: @escaping (_ message: String) -> Void,
                                            success successBlock: @escaping (_ local: URL) -> Void,
                                            failure failureBlock: @escaping (_ local: URL, _ error: Error) -> Void) {
        if self.restore {
            let sessionSize = self.spaceNeeded != nil ? self.spaceNeeded! : 0
            let selectedDestination = self.destination != nil ? self.destination! : self.localURL
            
            self.sdk.restoreFolder(folderID: UInt64(self.uniqueID), sessionName: self.uuid, destination: selectedDestination!, sessionSize: sessionSize, completionQueue: syncResultQueue, progress: { (total, current, new, percent) in
                progressBlock(total, current, new, percent, "0KB/s")
            }, issue: { (message) in
                issueBlock(message)
            }, success: {
                successBlock(self.localURL)
            }, failure: { (error) in
                failureBlock(self.localURL, error)
            })
        } else {
            self.sdk.syncFolder(folderID: UInt64(self.uniqueID), sessionName: self.uuid, completionQueue: syncResultQueue, progress: { (total, current, new, percent) in
                progressBlock(total, current, new, percent, "0KB/s")
            }, issue: { (message) in
                issueBlock(message)
            }, success: {
                successBlock(self.localURL)
            }, failure: { (error) in
                failureBlock(self.localURL, error)
            })
        }
    }
    
    fileprivate func startUnencryptedSyncTask(progress progressBlock: @escaping (_ total: UInt64, _ current: UInt64, _ new: UInt64, _ percent: Double, _ bandwidth: String) -> Void,
                                              issue issueBlock: @escaping (_ message: String) -> Void,
                                              success successBlock: @escaping (_ local: URL) -> Void,
                                              failure failureBlock: @escaping (_ local: URL, _ error: Error) -> Void) {
        assert(Thread.current != Thread.main, "Sync task started from main thread")
        
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: localURL.path, isDirectory:&isDirectory) {
            if !isDirectory.boolValue == true {
                let error = NSError(domain: SDErrorUIDomain, code:SDSyncError.directoryMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: "Local directory not found"])
                DispatchQueue.main.async(execute: {
                    self.syncFailure = true
                    failureBlock(self.localURL, error)
                })
            }
        }
        
        
        // MARK: - Retrieve necessary parameters from ssh url
        
        
        
        
        var serverPath = serverURL.path
        
        serverPath.remove(at: serverPath.startIndex)
        
        let localPath = localURL.path
        
        guard let host  = serverURL.host,
            let port  = serverURL.port,
            let user = serverURL.user else {
                let error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: "failed to unpack user information"])
                
                DispatchQueue.main.async(execute: {
                    failureBlock(self.localURL, error)
                })
                return
        }
        
        // MARK: - Create the subprocess to be configured below
        
        self.syncTask = Process()
        
        let rsyncPath = Bundle.main.path(forAuxiliaryExecutable: "rsync-3.1.2")
        
        if rsyncPath != nil {
            self.syncTask.launchPath = rsyncPath
        } else {
            let message = NSLocalizedString("Rsync missing, contact SafeDrive support", comment: "")
            let rsyncError = NSError(domain: SDMountErrorDomain, code:SDSystemError.rsyncMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: message])
            DispatchQueue.main.async(execute: {
                failureBlock(self.localURL, rsyncError)
            })
            return
        }
        
        // MARK: - Set custom environment variables for sshfs subprocess
        
        var rsyncEnvironment = ProcessInfo.processInfo.environment
        
        /* path of our custom askpass helper so ssh can use it */
        guard let safeDriveAskpassPath = Bundle.main.path(forAuxiliaryExecutable: "safedriveaskpass") else {
            let askpassError = NSError(domain: SDErrorSyncDomain, code:SDSystemError.askpassMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: "Askpass helper missing"])
            DispatchQueue.main.async(execute: {
                self.syncFailure = true
                failureBlock(self.localURL, askpassError)
            })
            return
        }
        rsyncEnvironment["SSH_ASKPASS"] = safeDriveAskpassPath
        
        
        /* pass the account name to the safedriveaskpass environment */
        rsyncEnvironment["SSH_ACCOUNT"] = user
        
        /* pass the current keychain ssh credential domain to the askpass environment */
        rsyncEnvironment["SDSSHServiceName"] = sshCredentialDomain()
        
        /*
         remove any existing SSH agent socket in the subprocess environment so we
         have full control over auth behavior
         */
        rsyncEnvironment.removeValue(forKey: "SSH_AUTH_SOCK")
        
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
        
        rsyncEnvironment["DISPLAY"] = ""
        
        self.syncTask.environment = rsyncEnvironment
        
        
        // MARK: - Set Rsync subprocess arguments
        let sshCommand = "ssh -o StrictHostKeyChecking=no -p \(port)"
        
        var taskArguments = ["-e", sshCommand, "--delete", "-rlptX", "--info=progress2", "--no-inc-recursive"]
        
        let remote = "\(user)@\(host):\"\(serverPath)/\""
        
        let local = "\(localPath)/"
        
        // restore just reverses the local and remote path arguments to the rsync command,
        // is not as well tested as normal sync
        if restore {
            taskArguments.append(remote)
            taskArguments.append(local)
        } else {
            taskArguments.append(local)
            taskArguments.append(remote)
        }
        self.syncTask.arguments = taskArguments
        
        
        // MARK: - Set asynchronous block to handle subprocess stdout
        
        let outputPipe = Pipe()
        let outputPipeHandle = outputPipe.fileHandleForReading
        
        outputPipeHandle.readabilityHandler = { (handle) in
            
            let outputString: String! = String(data:handle.availableData, encoding:String.Encoding.utf8)
            let whitespaceRegex = "^\\s+$"
            let fullRegex = "^\\s*([0-9,]+)\\s+([0-9]+)%\\s+([0-9\\.A-Za-z/]+)"
            // example: "              0   0%    0.00kB/s    0:00:00 (xfr#0, to-chk=0/11)"
            if outputString.isMatched(byRegex: fullRegex) {
                if let matches = outputString.arrayOfCaptureComponentsMatched(byRegex: fullRegex) as [AnyObject]! {
                    if matches.count == 1 {
                        let capturedValues = matches[0] as! [String]
                        if capturedValues.count >= 3 {
                            let percent = capturedValues[2]
                            let bandwidth = capturedValues[3]
                            
                            (self.syncProgressQueue).async(execute: {
                                progressBlock(0, 0, 0, Double(percent)!, bandwidth)
                            })
                        }
                    }
                }
            } else if outputString.isMatched(byRegex: whitespaceRegex) {
                // skip all whitespace lines
            } else {
                SDLog("Rsync Task stdout output: %@", outputString)
            }
            
        }
        self.syncTask.standardOutput = outputPipe
        
        // MARK: - Set asynchronous block to handle subprocess stderr
        
        let errorPipe = Pipe()
        let errorPipeHandle = errorPipe.fileHandleForReading
        errorPipeHandle.readabilityHandler = { (handle: FileHandle!) in
            let errorString: String! = String(data: handle.availableData, encoding: String.Encoding.utf8)
            var error: NSError!
            if errorString.contains("Could not chdir to home directory") {
                /*
                 NSString *msg = [NSString stringWithFormat:@"Could not chdir to home directory"];
                 
                 error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorRemoteEnvironment userInfo:@{NSLocalizedDescriptionKey: msg}];
                 */
            } else if errorString.contains("connection unexpectedly closed") {
                error = NSError(domain: SDErrorSyncDomain, code:SDSyncError.syncFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server closed connection unexpectedly"])
            } else if errorString.contains("No such file or directory") {
                let msg: String! = String(format: "That path does not exist on the server: %@", serverPath)
                
                error = NSError(domain: SDErrorSyncDomain, code:SDSyncError.directoryMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: msg])
            } else if errorString.contains("Not a directory") {
                let msg: String! = String(format: "That path does not exist on the server: %@", serverPath)
                
                error = NSError(domain: SDErrorSyncDomain, code:SDSyncError.directoryMissing.rawValue, userInfo:[NSLocalizedDescriptionKey: msg])
            } else if errorString.contains("Permission denied") {
                error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.authorization.rawValue, userInfo:[NSLocalizedDescriptionKey: "Permission denied"])
            } else if errorString.contains("Error resolving hostname") {
                error = NSError(domain: SDErrorSyncDomain, code:SDSyncError.syncFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Error resolving hostname, contact support"])
            } else if errorString.contains("remote host has disconnected") {
                error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.authorization.rawValue, userInfo:[NSLocalizedDescriptionKey: "Sync failed, check username and password"])
            } else if errorString.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") {
                error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.hostFingerprintChanged.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server fingerprint changed!"])
            } else if errorString.contains("Host key verification failed") {
                error = NSError(domain: SDErrorSyncDomain, code:SDSSHError.hostKeyVerificationFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Warning: server key verification failed!"])
            } else if errorString.contains("differs from the key for the IP address") {
                
                // silence host key mismatch for now
                // example: Warning: the ECDSA host key for 'sftp-client.safedrive.io' differs from the key for the IP address '185.104.180.61'
                //NSString *msg = [NSString stringWithFormat:@"Host key mismatch"];
                
                //error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorHostFingerprintChanged userInfo:@{NSLocalizedDescriptionKey: msg}];
            } else if errorString.contains("received SIGINT, SIGTERM, or SIGHUP") {
                // silence signals
            } else {
                error = NSError(domain: SDErrorSyncDomain, code:SDSyncError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: "An unknown error occurred, contact support"])
                /*
                 for the moment we don't want to call the failure block here, as
                 not everything that comes through stderr indicates a sync
                 failure.
                 
                 testing is required to discover and handle the stderr output that
                 we actually need to handle and ignore the rest.
                 
                 */
                // failureBlock(localURL, mountError);
                SDLog("Rsync: \(errorString)")
                return
            }
            if error != nil {
                DispatchQueue.main.async(execute: {
                    self.syncFailure = true
                    failureBlock(self.localURL, error)
                })
                SDLog("Rsync: \(SDErrorToString(error)), \(error.localizedDescription)")
            }
        }
        self.syncTask.standardError = errorPipe
        
        // MARK: - Set asynchronous block to handle subprocess termination
        
        
        /*
         clear the read and write blocks once the subprocess terminates, and then
         call the success block if no error occurred.
         
         */
        weak var weakSelf: SyncController? = self
        self.syncTask.terminationHandler = { (task) in
            outputPipeHandle.readabilityHandler = nil
            errorPipeHandle.readabilityHandler = nil
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async(execute: {
                    guard let s = weakSelf else {
                        return
                    }
                    // need to explicitly check if a sync failure occurred as the return value of 0 doesn't indicate success
                    if !s.syncFailure {
                        successBlock(self.localURL)
                    }
                })
            } else {
                DispatchQueue.main.async(execute: {
                    guard let s = weakSelf else {
                        return
                    }
                    if s.syncFailure {
                        // do nothing, failureBlock already called elsewhere
                    } else if s.syncTerminated {
                        // rsync returned a non-zero exit code because cancel/terminate was called by the user
                        
                        let error = NSError(domain: SDErrorUIDomain, code:SDSyncError.cancelled.rawValue, userInfo:[NSLocalizedDescriptionKey: "Sync cancelled"])
                        failureBlock(self.localURL, error)
                    } else {
                        // since rsync returned a non-zero exit code AND we have not yet called failureBlock,
                        // we must call it as a catch-all.
                        
                        // This codepath should rarely if ever be used, if it does we'll need to log the entire
                        // output of rsync and report it to the telemetry API to be examined
                        let error = NSError(domain: SDErrorSyncDomain, code:SDSyncError.unknown.rawValue, userInfo:[NSLocalizedDescriptionKey: "An unknown error occurred, contact support"])
                        failureBlock(self.localURL, error)
                    }
                })
            }
        }
        
        
        // MARK: - Launch subprocess and return
        
        self.sftpOperation(SDSFTPOperation.createFolder, remoteDirectory:serverURL, password:password, success: {
            self.syncTask.launch()
            
        }, failure: { (apiError) in
            DispatchQueue.main.async(execute: { 
                self.syncFailure = true
                failureBlock(self.localURL, apiError)
            })
        })
    }
}
