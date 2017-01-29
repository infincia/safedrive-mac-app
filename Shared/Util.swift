//
//  Util.swift
//  SafeDrive
//
//  Created by steve on 1/17/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation

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
        exit(1)
    }
        
    #if DEBUG
    let u = groupURL.appendingPathComponent("staging", isDirectory: true)
    #else
    let u = groupURL
    #endif
    do {
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories:true, attributes:nil)
    } catch let directoryError as NSError {
        print("Error creating support directory: \(directoryError.localizedDescription)")
    }
    return u
}

func currentConfiguration() -> Bool {
    #if DEBUG
    return false
    #else
    return true
    #endif
}

func isProduction() -> Bool {
    #if DEBUG
    return false
    #else
    return true
    #endif
}

func webDomain() -> String {
    #if DEBUG
    return SDWebDomainStaging
    #else
    return SDWebDomainProduction
    #endif
}

func apiDomain() -> String {
    #if DEBUG
    return SDAPIDomainStaging
    #else
    return SDAPIDomainProduction
    #endif
}

func tokenDomain() -> String {
    #if DEBUG
    return SDAuthTokenDomainStaging
    #else
    return SDAuthTokenDomainProduction
    #endif
}

func sshCredentialDomain() -> String {
    #if DEBUG
    return SDSSHCredentialDomainStaging
    #else
    return SDSSHCredentialDomainProduction
    #endif
}

func accountCredentialDomain() -> String {
    #if DEBUG
    return SDAccountCredentialDomainStaging
    #else
    return SDAccountCredentialDomainProduction
    #endif
}

func recoveryKeyDomain() -> String {
    #if DEBUG
    return SDRecoveryKeyDomainStaging
    #else
    return SDRecoveryKeyDomainProduction
    #endif
}
