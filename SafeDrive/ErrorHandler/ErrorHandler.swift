//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast


import Crashlytics

import SafeDriveSDK

var errors = [[AnyHashable: Any]]()
let errorQueue = DispatchQueue(label: "io.safedrive.errorQueue")

var serializedErrorLocation: URL!

var currentUniqueClientId = ""

let reporterInterval: TimeInterval = 60

// MARK:
// MARK: Public API

func SDErrorHandlerInitialize() {
    let localURL = storageURL()
    
    /*
     Set serializedErrorLocation to an NSURL corresponding to:
     ~/Library/Application Support/SafeDrive/SafeDrive-Errors.plist
     */
    serializedErrorLocation = localURL.appendingPathComponent("SafeDrive-Errors.plist", isDirectory:false)

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
    return withVaList(arguments) { argumentPointer in
        if !isProduction() {
            CLSNSLogv(line, argumentPointer)
        } else {
            CLSLogv(line, argumentPointer)
        }
    }
}

func SDLogError(_ line: String, _ arguments: CVarArg...) {
    return withVaList(arguments) { _ in
        let st = String(format: line, arguments: arguments)
        SafeDriveSDK.sharedSDK.log(st, .error)
        SDLog(line, arguments)
    }
}

func SDLogWarn(_ line: String, _ arguments: CVarArg...) {
    return withVaList(arguments) { _ in
        let st = String(format: line, arguments: arguments)
        SafeDriveSDK.sharedSDK.log(st, .warn)
        SDLog(line, arguments)
    }
}

func SDLogInfo(_ line: String, _ arguments: CVarArg...) {
    return withVaList(arguments) { _ in
        let st = String(format: line, arguments: arguments)
        SafeDriveSDK.sharedSDK.log(st, .info)
        SDLog(line, arguments)
    }
}

func SDLogDebug(_ line: String, _ arguments: CVarArg...) {
    return withVaList(arguments) { _ in
        let st = String(format: line, arguments: arguments)
        SafeDriveSDK.sharedSDK.log(st, .debug)
        SDLog(line, arguments)
    }
}

func SDLogTrace(_ line: String, _ arguments: CVarArg...) {
    return withVaList(arguments) { _ in
        let st = String(format: line, arguments: arguments)
        SafeDriveSDK.sharedSDK.log(st, .trace)
        SDLog(line, arguments)
    }
}

func SDErrorHandlerReport(_ error: Error?) {
    guard let error = error as NSError? else {
        fatalError()
    }

    // always report errors to crashlytics
    Crashlytics.sharedInstance().recordError(error)
    
    //if isProduction() {
        // don't even add error reports to the SD telemetry log unless we're in a RELEASE build
        
        // using archived NSError so the array can be serialized as a plist
        errorQueue.sync {
            let whitelistErrorDomains = [SDErrorDomainInternal, SDErrorDomainReported]
            
            if whitelistErrorDomains.contains(error._domain) {
                let os: String = "OS X \(currentOSVersion())"

                let clientVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
                let report: [String : Any] = [  "error": NSKeyedArchiver.archivedData(withRootObject: error),
                                                "uniqueClientId": currentUniqueClientId,
                                                "os": os,
                                                "clientVersion": clientVersion ]
                errors.insert(report, at:0)
                saveErrors()
            }
        }
    //}
}

func SDUncaughtExceptionHandler(exception: NSException!) {
    let stack = exception.callStackReturnAddresses
    print("Stack trace: %@", stack)
    
    errorQueue.sync {
        let report: [String : Any] = [ "stack": stack,
                                       "uniqueClientId": currentUniqueClientId ]
        errors.insert(report, at:0)
        saveErrors()
    }
}

// MARK:
// MARK: Private APIs

func startReportQueue() {
    background {
        while true {
            errorQueue.sync {
                
                // get the oldest report and pop it off the end of the array temporarily
                let report = errors.popLast()
                //errors.removeObject(report)
                
                if let report = report {
                    
                    let reportUniqueClientId = report["uniqueClientId"] as! String

                    let reportOS = report["os"] as? String

                    let reportClientVersion = report["clientVersion"] as? String
                    
                    let archivedError = report["error"] as! Data                    
                    
                    // Errors are stored as NSData in the error array so they can be transparently serialized to disk,
                    // so we must unarchive them before use
                    let error = NSKeyedUnarchiver.unarchiveObject(with: archivedError) as! NSError
                    
                    //note: passing the same queue we're in here is only OK because the called method uses it
                    //      with dispatch_async, if that were not the case this would deadlock forever
                    
                    SafeDriveSDK.sharedSDK.reportError(error, forUniqueClientId: reportUniqueClientId, os: reportOS, clientVersion: reportClientVersion, completionQueue: errorQueue, success: {
                        
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

private func saveErrors() {
    if !NSKeyedArchiver.archiveRootObject(errors, toFile: serializedErrorLocation.path) {
        SDLog("WARNING: error report database could not be saved!!!")
    }
}
