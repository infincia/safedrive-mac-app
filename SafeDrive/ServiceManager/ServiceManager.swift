
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class ServiceManager: NSObject {
    static let sharedServiceManager = ServiceManager()

    override init() {
        super.init()
        self.serviceLoop()
    }


    var serviceStatus: Bool {
        get {
            guard let _ = SMJobCopyDictionary(kSMDomainUserLaunchd, ("io.safedrive.SafeDrive.Service" as CFString)) else {
                return false
            }
            return true
        }
    }

    private func serviceLoop() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in
            while true {
                let serviceStatus: Bool = self.serviceStatus
                dispatch_async(dispatch_get_main_queue(), {() -> Void in
                    NSNotificationCenter.defaultCenter().postNotificationName(SDServiceStatusNotification, object: serviceStatus)
                })
                NSThread.sleepForTimeInterval(1)
            }
        })
    }

    func loadService() {
        let servicePlist: NSURL = NSBundle.mainBundle().URLForResource("io.safedrive.SafeDrive.Service", withExtension: "plist")!
        let jobDict = NSDictionary(contentsOfFile: servicePlist.path!)
        var jobError: Unmanaged<CFError>? = nil

        if !SMJobSubmit(kSMDomainUserLaunchd, jobDict!, nil, &jobError) {
            if let error = jobError?.takeRetainedValue() as NSError? {
                SDLog("Load service error: \(error)")
                SDErrorHandlerReport(error)
            }
        }
    }

    func unloadService() {
        var jobError: Unmanaged<CFError>? = nil
        if !SMJobRemove(kSMDomainUserLaunchd, ("io.safedrive.SafeDrive.Service" as CFString), nil, true, &jobError) {
            if let error = jobError?.takeRetainedValue() as NSError? {
                SDLog("Unload service error: \(error)")
                SDErrorHandlerReport(error)
            }
        }
    }
}
