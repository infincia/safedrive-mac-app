
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

import Cocoa
import os.log

let bundleId = "io.safedrive.SafeDrive.d"


if #available(OSX 10.12, *) {
    os_log("%@ will start", bundleId)
} else {
    NSLog("%@ will start", bundleId)
}

let listenerDelegate = ServiceListenerDelegate()

let listener = NSXPCListener(machServiceName: bundleId)

listener.delegate = listenerDelegate
listener.resume()

if #available(OSX 10.12, *) {
    os_log("%@ listening", bundleId)
} else {
    NSLog("%@ listening", bundleId)
}

autoreleasepool {
    RunLoop.current.run()
}

if #available(OSX 10.12, *) {
    os_log("%@ will exit", bundleId)
} else {
    NSLog("%@ will exit", bundleId)
}
exit(EXIT_FAILURE)

