//
//  main.swift
//  SafeDrive.Helper
//
//  Created by steve on 7/5/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation

import Cocoa
import os.log


if #available(OSX 10.12, *) {
    os_log("SafeDrive.d will start")
} else {
    NSLog("SafeDrive.d will start")
}
let listenerDelegate = ServiceListenerDelegate()
// swiftlint:disable force_unwrapping
let listener: NSXPCListener = NSXPCListener(machServiceName: "io.safedrive.SafeDrive.Service")
// swiftlint:enable force_unwrapping

listener.delegate = listenerDelegate
listener.resume()

if #available(OSX 10.12, *) {
    os_log("SafeDrive.d listening")
} else {
    NSLog("SafeDrive.d listening")
}

RunLoop.current.run()


if #available(OSX 10.12, *) {
    os_log("SafeDrive.Service will exit")
} else {
    NSLog("SafeDrive.Service will exit")
}
exit(EXIT_FAILURE)

