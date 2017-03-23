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


fileprivate let SDAccountCredentialDomainProduction = "safedrive.io"
fileprivate let SDAccountCredentialDomainStaging = "staging.safedrive.io"

fileprivate let SDAuthTokenDomainProduction = "session.safedrive.io"
fileprivate let SDAuthTokenDomainStaging = "staging.session.safedrive.io"

fileprivate let SDRecoveryKeyDomainProduction = "recovery.safedrive.io"
fileprivate let SDRecoveryKeyDomainStaging = "staging.recovery.safedrive.io"

// use the same UCID on production and staging until we have a reason not to
fileprivate let SDUniqueClientIDDomainProduction = "ucid.safedrive.io"
fileprivate let SDUniqueClientIDDomainStaging = "staging.ucid.safedrive.io"

fileprivate let SDCurrentUserDomainProduction = "currentuser.safedrive.io"
fileprivate let SDCurrentUserDomainStaging = "staging.currentuser.safedrive.io"


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
    if isProduction() {
        return SDAuthTokenDomainProduction
    } else {
        return SDAuthTokenDomainStaging
    }
}

func accountCredentialDomain() -> String {
    if isProduction() {
        return SDAccountCredentialDomainProduction
    } else {
        return SDAccountCredentialDomainStaging
    }
}

func recoveryKeyDomain() -> String {
    if isProduction() {
        return SDRecoveryKeyDomainProduction
    } else {
        return SDRecoveryKeyDomainStaging
    }
}

func UCIDDomain() -> String {
    if isProduction() {
        return SDUniqueClientIDDomainProduction
    } else {
        return SDUniqueClientIDDomainStaging
    }
}

func currentUserDomain() -> String {
    if isProduction() {
        return SDCurrentUserDomainProduction
    } else {
        return SDCurrentUserDomainStaging
    }
}
