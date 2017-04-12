//
//  Util.swift
//  SafeDrive
//
//  Created by steve on 1/17/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//
// swiftlint:disable sorted_imports


import Crashlytics
import Foundation

// http://stackoverflow.com/a/30593673/255309
extension Collection where Indices.Iterator.Element == Index {
    subscript (safe index: Index) -> Generator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// SafeDrive API constants

fileprivate let SDAPIDomainStaging = "staging.safedrive.io"
fileprivate let SDAPIDomainProduction = "safedrive.io"
fileprivate let SDWebDomainStaging = "staging.safedrive.io"
fileprivate let SDWebDomainProduction = "safedrive.io"

// Keychain constants


fileprivate let SDAccountCredentialDomain = "safedrive.io"
fileprivate let SDAuthTokenDomain = "session.safedrive.io"
fileprivate let SDRecoveryKeyDomain = "recovery.safedrive.io"
fileprivate let SDUniqueClientIDDomain = "ucid.safedrive.io"
fileprivate let SDCurrentUserDomain = "currentuser.safedrive.io"

func currentOSVersion() -> String {
    let systemVersionPlist = "/System/Library/CoreServices/SystemVersion.plist"
    guard let dict = NSDictionary(contentsOfFile: systemVersionPlist) as? [String: Any],
          let systemVersion = dict["ProductVersion"] as? String else {
        return "Unknowwn"
    }

    return systemVersion
}

func storageURL() -> URL {
    guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db") else {
        Crashlytics.sharedInstance().crash()
        exit(1)
    }
    let u: URL
    if isProduction() {
        u = groupURL
    } else {
        u = groupURL.appendingPathComponent("staging", isDirectory: true)
    }

    do {
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories:true, attributes:nil)
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

func webDomain() -> String {
    if isProduction() {
        return SDWebDomainProduction
    } else {
        return SDWebDomainStaging
    }
}

func apiDomain() -> String {
    if isProduction() {
        return SDAPIDomainProduction
    } else {
        return SDAPIDomainStaging
    }
}

func tokenDomain() -> String {
    return SDAuthTokenDomain
    
}

func accountCredentialDomain() -> String {
    return SDAccountCredentialDomain
}

func recoveryKeyDomain() -> String {
    return SDRecoveryKeyDomain
}

func UCIDDomain() -> String {
    return SDUniqueClientIDDomain
    
}

func currentUserDomain() -> String {
    return SDCurrentUserDomain
}
