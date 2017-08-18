
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable file_length

import Foundation

class SyncController: Equatable {
    
    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate var syncTask: Process!
    fileprivate var syncFailure = false
    fileprivate var syncTerminated = false
    fileprivate let syncProgressQueue = DispatchQueue(label: "io.safedrive.SafeDrive.syncprogress", attributes: [])

    var uniqueID: UInt64!
    
    var encrypted: Bool = false
    
    var restore: Bool = false
    
    var folderName: String!
    
    var localURL: URL!
    
    var serverURL: URL!
    
    var password: String!
    
    var uuid: String!
    
    var spaceNeeded: UInt64 = 0
    
    var destination: URL!
    
    
    static func == (left: SyncController, right: SyncController) -> Bool {
        return (left.uniqueID == right.uniqueID)
    }
    
    func sftpOperation(_ operation: SDKRemoteFSOperation, remoteDirectory serverURL: URL, success successBlock: @escaping () -> Void, failure failureBlock: @escaping (_ error: Error) -> Void) {
        
        background {

            switch operation {
            case SDKRemoteFSOperation.moveFolder:

                let storageDir = URL(fileURLWithPath: "/storage/Storage/")

                
                let now = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd@HH-mm-ss"
                dateFormatter.locale = Locale.current
                let dateString = dateFormatter.string(from: now)
                let newName = String(format:"%@ - %@", serverURL.lastPathComponent, dateString)
                let destinationDir = storageDir.appendingPathComponent(newName, isDirectory:true)
                SDLog("Moving SyncFolder %@ to %@", serverURL.path, destinationDir.path)

                self.sdk.remoteFSMoveDirectory(path: serverURL.path, newPath: destinationDir.path, completionQueue: DispatchQueue.main, success: {
                    successBlock()
                }, failure: { (error) in
                    let msg = "SSH: failed to move path: \(serverURL.path). \(error.localizedDescription)"
                    SDLog(msg)
                    let error = SDError(message: msg, kind: .sftpOperationFailure)
                    failureBlock(error)
                })
                break
                
            case SDKRemoteFSOperation.createFolder:
                self.sdk.remoteFSCreateDirectory(path: serverURL.path, completionQueue: DispatchQueue.main, success: {
                    successBlock()
                }, failure: { (error) in
                    let msg = "SSH: failed to create path: \(serverURL.path). \(error.localizedDescription)"
                    SDLog(msg)
                    let error = SDError(message: msg, kind: .sftpOperationFailure)
                    failureBlock(error)
                })
                break
            case SDKRemoteFSOperation.deleteFolder:
                self.sdk.remoteFSDeleteDirectory(path: serverURL.path, completionQueue: DispatchQueue.main, success: {
                    successBlock()
                }, failure: { (error) in
                    let msg = "SSH: failed to remove directory: \(serverURL.path). \(error.localizedDescription)"
                    SDLog(msg)
                    let error = SDError(message: msg, kind: .sftpOperationFailure)
                    failureBlock(error)
                })
                break
            case SDKRemoteFSOperation.deletePath(let recursive):
                self.sdk.remoteFSDeletePath(path: serverURL.path, recursive: recursive, completionQueue: DispatchQueue.main, success: {
                    successBlock()
                }, failure: { (error) in
                    let msg = "SSH: failed to remove path: \(serverURL.path). \(error.localizedDescription)"
                    SDLog(msg)
                    let error = SDError(message: msg, kind: .sftpOperationFailure)
                    failureBlock(error)
                })
                break
            }
        }
    }
    
    // MARK:
    // MARK: Public API
    
    func stopSyncTask(_ completion: @escaping () -> Void) {
        self.syncTerminated = true
        DispatchQueue.global(priority: .high).async {
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
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    func startSyncTask(progress progressBlock: @escaping (_ total: UInt64, _ current: UInt64, _ new: UInt64, _ percent: Double) -> Void,
                       bandwidth bandwidthBlock: @escaping (_ bandwidth: String) -> Void,
                       issue issueBlock: @escaping (_ message: String) -> Void,
                       success successBlock: @escaping (_ local: URL) -> Void,
                       failure failureBlock: @escaping (_ local: URL, _ error: Error) -> Void) {
        if self.encrypted {
            startEncryptedSyncTask(progress: { (total, current, new, percent) in
                progressBlock(total, current, new, percent)
            }, bandwidth: { (speed) in
                bandwidthBlock(speed)
            }, issue: { (message) in
                issueBlock(message)
            }, success: { (url) in
                successBlock(url)
            }, failure: { (url, error) in
                failureBlock(url, error)
            })
        } else {
            startUnencryptedSyncTask(progress: { (total, current, new, percent, speed) in
                progressBlock(total, current, new, percent)
                bandwidthBlock(speed)
            }, issue: { (message) in
                issueBlock(message)
            }, success: { (url) in
                successBlock(url)
            }, failure: { (url, error) in
                failureBlock(url, error)
            })
        }
        
    }
    
    fileprivate func startEncryptedSyncTask(progress progressBlock: @escaping (_ total: UInt64, _ current: UInt64, _ new: UInt64, _ percent: Double) -> Void,
                                            bandwidth bandwidthBlock: @escaping (_ bandwidth: String) -> Void,
                                            issue issueBlock: @escaping (_ message: String) -> Void,
                                            success successBlock: @escaping (_ local: URL) -> Void,
                                            failure failureBlock: @escaping (_ local: URL, _ error: Error) -> Void) {
        var last_update = Date()

        if self.restore {            
            self.sdk.restoreFolder(folderID: UInt64(self.uniqueID), sessionName: self.uuid, destination: self.destination, sessionSize: self.spaceNeeded, completionQueue: syncProgressQueue, progress: { (total, current, new) in
                let now = Date()
                let d = now.timeIntervalSince(last_update)
                if d > 1 {
                    last_update = Date()
                    let percent = Double(current / total) * 100.0
                    (self.syncProgressQueue).async {
                        progressBlock(total, current, new, percent)
                    }
                }
            }, bandwidth: { (speed) in
                let average_bandwidth = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: ByteCountFormatter.CountStyle.decimal)
                let bandwidth = "\(average_bandwidth)/s"
                bandwidthBlock(bandwidth)
            }, issue: { (message) in
                (self.syncProgressQueue).async {
                    issueBlock(message)
                }
            }, success: {
                successBlock(self.localURL)
            }, failure: { (error) in
                failureBlock(self.localURL, error)
            })
        } else {
            self.sdk.syncFolder(folderID: UInt64(self.uniqueID), sessionName: self.uuid, completionQueue: syncProgressQueue, progress: { (total, current, new) in
                let now = Date()
                let d = now.timeIntervalSince(last_update)
                if d > 1 {
                    last_update = Date()
                    let percent = Double(current / total) * 100.0
                    (self.syncProgressQueue).async {
                        progressBlock(total, current, new, percent)
                    }
                }
            }, bandwidth: { (speed) in
                let average_bandwidth = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: ByteCountFormatter.CountStyle.decimal)
                let bandwidth = "\(average_bandwidth)/s"
                bandwidthBlock(bandwidth)
            }, issue: { (message) in
                (self.syncProgressQueue).async {
                    issueBlock(message)
                }
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
                let error = SDKError(message: "Folder missing", kind: SDKErrorType.FolderMissing)
                (self.syncProgressQueue).async {
                    self.syncFailure = true
                    failureBlock(self.localURL, error)
                }
            }
        }
        
        
        // MARK: - Retrieve necessary parameters from ssh url
        
        
        
        
        var serverPath = serverURL.path
        
        serverPath.remove(at: serverPath.startIndex)
        
        let localPath = localURL.path
        
        guard let host = serverURL.host,
            let port = serverURL.port,
            let user = serverURL.user else {
                let error = SDError(message: "failed to unwrap user information", kind: .apiContractInvalid)
                (self.syncProgressQueue).async {
                    failureBlock(self.localURL, error)
                }
                return
        }
        
        // MARK: - Create the subprocess to be configured below
        
        self.syncTask = Process()
        
        guard let rsyncPath = Bundle.main.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.rsync") else {
            let message = NSLocalizedString("Rsync missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .rsyncMissing)
            (self.syncProgressQueue).async {
                failureBlock(self.localURL, error)
            }
            return
        }
        
        self.syncTask.launchPath = rsyncPath

        // MARK: - Set custom environment variables for sshfs subprocess
        
        var rsyncEnvironment = [String: String]()
        
        /* path of our custom askpass helper so ssh can use it */
        guard let safeDriveAskpassPath = Bundle.main.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.askpass") else {
            let error = SDError(message: "Askpass helper missing", kind: .askpassMissing)
            (self.syncProgressQueue).async {
                self.syncFailure = true
                failureBlock(self.localURL, error)
            }
            return
        }
        rsyncEnvironment["SSH_ASKPASS"] = safeDriveAskpassPath
        
        /* pass the account password to the safedriveaskpass environment */
        //rsyncEnvironment["SSH_PASSWORD"] = self.password
        
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
        
        if isProduction() {
            rsyncEnvironment["SAFEDRIVE_ENVIRONMENT_PRODUCTION"] = "1"
        }
        
        self.syncTask.environment = rsyncEnvironment
        
        
        // MARK: - Set Rsync subprocess arguments
        
        
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
            (self.syncProgressQueue).async {
                failureBlock(self.localURL, error)
            }
            return
        }
        
        let tempHostsFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: knownHostsFile, to: tempHostsFile)
        } catch {
            let message = NSLocalizedString("Cannot create temporary file, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .temporaryFile)
            (self.syncProgressQueue).async {
                failureBlock(self.localURL, error)
            }
            return
        }
        
        /* bundled config file to avoid environment differences */
        guard let configFile = Bundle.main.url(forResource: "ssh_config", withExtension: nil) else {
            let message = NSLocalizedString("SSH config missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .configMissing)
            (self.syncProgressQueue).async {
                failureBlock(self.localURL, error)
            }
            return
        }
        
        let tempConfigFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: configFile, to: tempConfigFile)
        } catch {
            let message = NSLocalizedString("Cannot create temporary file, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .temporaryFile)
            (self.syncProgressQueue).async {
                failureBlock(self.localURL, error)
            }
            return
        }
        
        /* our own ssh binary */
        guard let _ = Bundle.main.path(forAuxiliaryExecutable: "io.safedrive.SafeDrive.ssh") else {
            let message = NSLocalizedString("SSH missing, contact SafeDrive support", comment: "")
            let error = SDError(message: message, kind: .sshMissing)
            (self.syncProgressQueue).async {
                failureBlock(self.localURL, error)
            }
            return
        }
        
        let sshCommand = "ssh -F\(tempConfigFile.path) -oUserKnownHostsFile=\"\(tempHostsFile.path)\" -p \(port)"

        //let sshCommand = "\(sshPath) -F\(tempConfigFile.path) -oUserKnownHostsFile=\"\(tempHostsFile.path)\" -p \(port)"
        
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
            
            let outputString: String! = String(data: handle.availableData, encoding: String.Encoding.utf8)
            //let whitespaceRegex = "^\\s+$"
            
            let pattern = "^\\s*([0-9,]+)\\s+([0-9]+)%\\s+([0-9\\.A-Za-z/]+)"
            // example: "              0   0%    0.00kB/s    0:00:00 (xfr#0, to-chk=0/11)"

            if let regex = try? NSRegularExpression(pattern: pattern) {
                let s = outputString as NSString

                
                let result: [NSTextCheckingResult] = regex.matches(in: outputString, range: NSRange(location: 0, length: s.length))
                
                if result.count == 0 {
                    return
                }
                
                if result[0].numberOfRanges < 4 {
                    return
                }
                
                let percentRange = result[0].range(at: 2) // <-- !!
                let bandwidthRange = result[0].range(at: 3) // <-- !!
                
                let percent = s.substring(with: percentRange)
                let bandwidth = s.substring(with: bandwidthRange)
                
                (self.syncProgressQueue).async {
                    guard let d = Double(percent) else {
                        return
                    }
                    progressBlock(0, 0, 0, d, bandwidth)
                }
            }
            
        }
        self.syncTask.standardOutput = outputPipe
        
        // MARK: - Set asynchronous block to handle subprocess stderr
        
        let errorPipe = Pipe()
        let errorPipeHandle = errorPipe.fileHandleForReading
        errorPipeHandle.readabilityHandler = { (handle: FileHandle!) in
            let errorString: String! = String(data: handle.availableData, encoding: String.Encoding.utf8)
            var error: Error?
            if errorString.contains("Could not chdir to home directory") {
                /*
                 NSString *msg = [NSString stringWithFormat:@"Could not chdir to home directory"];
                 
                 error = [NSError errorWithDomain:SDErrorSyncDomain code: SSHErrorRemoteEnvironment userInfo:@{NSLocalizedDescriptionKey: msg}];
                 */
            } else if errorString.contains("connection unexpectedly closed") {
                error = SDError(message: "Warning: server closed connection unexpectedly", kind: .syncFailed)
            } else if errorString.contains("No such file or directory") {
                let message = NSLocalizedString("An unknown error occurred, contact support", comment: "")
                error = SDError(message: message, kind: .directoryMissing)
            } else if errorString.contains("Not a directory") {
                let message = NSLocalizedString("An unknown error occurred, contact support", comment: "")
                error = SDError(message: message, kind: .directoryMissing)
            } else if errorString.contains("Permission denied") {
                error = SDError(message: "Permission denied, check username and password", kind: .authorization)
            } else if errorString.contains("Error resolving hostname") {
                error = SDError(message: "SafeDrive service unavailable", kind: .syncFailed)
            } else if errorString.contains("remote host has disconnected") {
                error = SDError(message: "Permission denied, check username and password", kind: .authorization)
            } else if errorString.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") {
                error = SDError(message: "Warning: server fingerprint changed!", kind: .hostFingerprintChanged)
            } else if errorString.contains("Host key verification failed") {
                error = SDError(message: "Warning: server key verification failed!", kind: .hostKeyVerificationFailed)
            } else if errorString.contains("differs from the key for the IP address") {
                // silence host key mismatch for now
                // example: Warning: the ECDSA host key for 'sftp-client.safedrive.io' differs from the key for the IP address '185.104.180.61'
                // error = SDError(message: "Warning: server key verification failed!", kind: .hostKeyVerificationFailed)
            } else if errorString.contains("received SIGINT, SIGTERM, or SIGHUP") {
                // silence signals
            } else {
                error = SDError(message: "An unknown error occurred, contact support", kind: .unknown)
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
            if let e = error {
                (self.syncProgressQueue).async {
                    self.syncFailure = true
                    failureBlock(self.localURL, e)
                }
                SDLog("Rsync: \(e), \(e.localizedDescription)")
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
                (self.syncProgressQueue).async {
                    guard let s = weakSelf else {
                        return
                    }
                    // need to explicitly check if a sync failure occurred as the return value of 0 doesn't indicate success
                    if !s.syncFailure {
                        successBlock(self.localURL)
                    }
                }
            } else {
                (self.syncProgressQueue).async {
                    guard let s = weakSelf else {
                        return
                    }
                    if s.syncFailure {
                        // do nothing, failureBlock already called elsewhere
                    } else if s.syncTerminated {
                        // rsync returned a non-zero exit code because cancel/terminate was called by the user
                        let error = SDError(message: "Sync cancelled", kind: .cancelled)
                        failureBlock(self.localURL, error)
                    } else {
                        // since rsync returned a non-zero exit code AND we have not yet called failureBlock,
                        // we must call it as a catch-all.
                        
                        // This codepath should rarely if ever be used, if it does we'll need to log the entire
                        // output of rsync and report it to the telemetry API to be examined
                        let error = SDError(message: "An unknown error occurred, contact support", kind: .unknown)
                        failureBlock(self.localURL, error)
                    }
                }
            }
        }
        
        
        // MARK: - Launch subprocess and return
        
        self.sftpOperation(SDKRemoteFSOperation.createFolder, remoteDirectory:serverURL, success: {
            self.syncTask.launch()
            
        }, failure: { (apiError) in
            (self.syncProgressQueue).async {
                self.syncFailure = true
                failureBlock(self.localURL, apiError)
            }
        })
    }
}
