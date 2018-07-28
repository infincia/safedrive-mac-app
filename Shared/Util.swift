//
//  Util.swift
//  SafeDrive
//
//  Created by steve on 1/17/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation

// http://stackoverflow.com/a/30593673/255309
extension Collection {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


func background(_ block: @escaping () -> Void) {
    if #available(OSX 10.10, *) {
        DispatchQueue.global(qos: .default).async {
            block()
        }
    } else {
        DispatchQueue.global(priority: .default).async {
            block()
        }
    }
}

func main(_ block: @escaping () -> Void) {
    DispatchQueue.main.async {
        block()
    }
}

func currentOSVersion() -> String {
    let systemVersionPlist = "/System/Library/CoreServices/SystemVersion.plist"
    guard let dict = NSDictionary(contentsOfFile: systemVersionPlist) as? [String: Any],
          let systemVersion = dict["ProductVersion"] as? String else {
        return "macOS 10.x"
    }

    return systemVersion
}

func storageURL() -> URL {
    guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "G738Z89QKM.io.safedrive") else {
        exit(1)
    }
    let u: URL
    if isProduction() {
        u = groupURL
    } else {
        u = groupURL.appendingPathComponent("staging", isDirectory: true)
    }

    do {
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true, attributes: nil)
    } catch let directoryError as NSError {
        print("Error creating support directory: \(directoryError.localizedDescription)")
    }
    return u
}

func isProduction() -> Bool {
    #if DEBUG
    return false
    #else
    return true
    #endif
}

