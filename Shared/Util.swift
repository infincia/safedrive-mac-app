//
//  Util.swift
//  SafeDrive
//
//  Created by steve on 1/17/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation
import Crashlytics

// SafeDrive API constants

fileprivate let SDAPIDomainStaging = "staging.safedrive.io"
fileprivate let SDAPIDomainProduction = "safedrive.io"
fileprivate let SDWebDomainStaging = "staging.safedrive.io"
fileprivate let SDWebDomainProduction = "safedrive.io"

// Keychain constants


fileprivate let SDAccountCredentialDomainProduction = "safedrive.io"
fileprivate let SDAccountCredentialDomainStaging = "staging.safedrive.io"

fileprivate let SDSSHCredentialDomainProduction = "ssh.safedrive.io"
fileprivate let SDSSHCredentialDomainStaging = "staging.ssh.safedrive.io"

fileprivate let SDAuthTokenDomainProduction = "session.safedrive.io"
fileprivate let SDAuthTokenDomainStaging = "staging.session.safedrive.io"

fileprivate let SDRecoveryKeyDomainProduction = "recovery.safedrive.io"
fileprivate let SDRecoveryKeyDomainStaging = "staging.recovery.safedrive.io"



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

func sshCredentialDomain() -> String {
    if isProduction() {
        return SDSSHCredentialDomainProduction
    } else {
        return SDSSHCredentialDomainStaging
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
