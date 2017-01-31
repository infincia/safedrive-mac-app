//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Crashlytics

var logBuffer = [String]()
var errors = [[AnyHashable: Any]]()
let errorQueue = DispatchQueue(label: "io.safedrive.errorQueue", attributes: [])

var serializedErrorLocation: URL!

var serializedLogLocation: URL!

var currentUniqueClientId = ""

let reporterInterval: TimeInterval = 60

let maxLogSize = 100


// MARK:
// MARK: Public API

func SDErrorHandlerInitialize() {
    let localURL = storageURL()
    
    /*
     Set serializedErrorLocation to an NSURL corresponding to:
     ~/Library/Application Support/SafeDrive/SafeDrive-Errors.plist
     */
    serializedErrorLocation = localURL.appendingPathComponent("SafeDrive-Errors.plist", isDirectory:false)
    
    /*
     Set serializedErrorLocation to an NSURL corresponding to:
     ~/Library/Application Support/SafeDrive/SafeDrive-Log.plist
     */
    serializedLogLocation = localURL.appendingPathComponent("SafeDrive-Log.plist", isDirectory:false)
    
    
    // restore any saved error reports from previous sessions
    if let archivedLogBuffer = NSKeyedUnarchiver.unarchiveObject(withFile: serializedLogLocation.path) as? [String] {
        logBuffer = archivedLogBuffer
    }
    
    if let archivedErrors = NSKeyedUnarchiver.unarchiveObject(withFile: serializedErrorLocation.path) as? [[AnyHashable: Any]] {
        errors = archivedErrors
    }
    // start the reporter loop now that any possible saved error reports are loaded
    startReportQueue()
}

func SDErrorHandlerSetUniqueClientId(_ uniqueClientId: String?) {
    guard let ucid = uniqueClientId else {
        currentUniqueClientId = ""
        return
    }
    currentUniqueClientId = ucid
}

func SDLog(_ line: String, _ arguments: CVarArg...) {
    return withVaList(arguments) {
        let st = String(format: line, arguments: arguments)
        // pass through to Crashlytics
        #if DEBUG
            CLSNSLogv(line, $0)
        #else
            CLSLogv(line, $0)
        #endif
        // for RELEASE builds, redirect logs to the buffer in case there is an error
        errorQueue.sync {
            logBuffer.append(st)
            shiftLog()
            saveLog()
        }
        
    }
}

func SDErrorHandlerReport(_ error: Error?) {
    guard let error = error as? NSError else {
        return
    }
    // always report errors to crashlytics
    Crashlytics.sharedInstance().recordError(error)
    #if DEBUG
        
    #else
        // don't even add error reports to the SD telemetry log unless we're in a RELEASE build
        
        // using archived NSError so the array can be serialized as a plist
        errorQueue.sync {
            let whitelistErrorDomains = [SDErrorDomain, SDErrorSyncDomain, SDErrorSSHFSDomain, SDErrorAccountDomain, SDErrorAPIDomain, SDMountErrorDomain]
            
            if whitelistErrorDomains.contains(error._domain) {
                let os: String = "OS X \(SDSystemAPI.shared().currentOSVersion()!)"

                let clientVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
                let report: [String : Any] = [  "error": NSKeyedArchiver.archivedData(withRootObject: error),
                                                "log": NSKeyedArchiver.archivedData(withRootObject: logBuffer),
                                                "uniqueClientId": currentUniqueClientId,
                                                "os": os,
                                                "clientVersion": clientVersion ]
                errors.insert(report, at:0)
                saveErrors()
            }
        }
    #endif
}

func SDUncaughtExceptionHandler(exception: NSException!) {
    let stack = exception.callStackReturnAddresses
    print("Stack trace: %@", stack)
    
    errorQueue.sync {
        let report: [String : Any] = [ "stack": stack,
                                       "log": logBuffer,
                                       "uniqueClientId": currentUniqueClientId ]
        errors.insert(report, at:0)
        saveErrors()
    }
}

// MARK:
// MARK: Private APIs

func startReportQueue() {
    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
        while true {
            errorQueue.sync {
                
                // get the oldest report and pop it off the end of the array temporarily
                let report = errors.popLast()
                //errors.removeObject(report)
                
                if let report = report {
                    
                    let reportUniqueClientId = report["uniqueClientId"] as! String

                    let reportOS = report["os"] as? String

                    let reportClientVersion = report["clientVersion"] as? String

                    let reportLogArchive = report["log"] as! Data
                    
                    let archivedError = report["error"] as! Data
                    
                    // Logs are stored as NSData in the log buffer so they can be transparently serialized to disk,
                    // so we must unarchive them before use
                    let reportLog = NSKeyedUnarchiver.unarchiveObject(with: reportLogArchive) as! [String]
                    
                    
                    // Errors are stored as NSData in the error array so they can be transparently serialized to disk,
                    // so we must unarchive them before use
                    let error = NSKeyedUnarchiver.unarchiveObject(with: archivedError) as! NSError
                    
                    //note: passing the same queue we're in here is only OK because the called method uses it
                    //      with dispatch_async, if that were not the case this would deadlock forever
                    
                    API.sharedAPI.reportError(error, forUniqueClientId: reportUniqueClientId, operatingSystem: reportOS, clientVersion: reportClientVersion, withLog:reportLog, completionQueue:errorQueue, success: {
                        
                        saveErrors()
                        
                    }, failure: { (_) in
                        
                        // put the report back in the queue and save it since this attempt failed
                        errors.insert(report, at:0)
                        
                        saveErrors()
                    })
                }
            }
            Thread.sleep(forTimeInterval: reporterInterval)
        }
    }
}

// NOTE: These MUST NOT be called outside of the errorQueue

private func shiftLog() {
    if logBuffer.count > maxLogSize {
        logBuffer.remove(at: 0)
    }
}

private func saveLog() {
    
    if !NSKeyedArchiver.archiveRootObject(logBuffer, toFile: serializedLogLocation.path) {
        SDLog("WARNING: log database could not be saved!!!")
    }
}

private func saveErrors() {
    if !NSKeyedArchiver.archiveRootObject(errors, toFile: serializedErrorLocation.path) {
        SDLog("WARNING: error report database could not be saved!!!")
    }
}
