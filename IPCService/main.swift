
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

import Cocoa
import os.log

let bundleId = "G738Z89QKM.io.safedrive.IPCService"

if #available(OSX 10.12, *) {
    os_log("%@ will start", bundleId)
} else {
    NSLog("%@ will start", bundleId)
}

ProcessInfo.processInfo.disableSuddenTermination()


let listenerDelegate = IPCListenerDelegate()

let listener = NSXPCListener.service()

listener.delegate = listenerDelegate
listener.resume()

if #available(OSX 10.12, *) {
    os_log("%@ listening", bundleId)
} else {
    NSLog("%@ listening", bundleId)
}

RunLoop.current.run()


if #available(OSX 10.12, *) {
    os_log("%@ will exit", bundleId)
} else {
    NSLog("%@ will exit", bundleId)
}
exit(EXIT_FAILURE)

