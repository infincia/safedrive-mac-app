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


fileprivate let SDServiceNameProduction = "safedrive.io"
fileprivate let SDServiceNameStaging = "staging.safedrive.io"

fileprivate let SDSSHServiceNameProduction = "ssh.safedrive.io"
fileprivate let SDSSHServiceNameStaging = "staging.ssh.safedrive.io"

fileprivate let SDSessionServiceNameProduction = "session.safedrive.io"
fileprivate let SDSessionServiceNameStaging = "staging.session.safedrive.io"

fileprivate let SDRecoveryKeyServiceNameProduction = "recovery.safedrive.io"
fileprivate let SDRecoveryKeyServiceNameStaging = "staging.recovery.safedrive.io"



func storageURL() -> URL {
    guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.safedrive.db") else {
        exit(1)
    }
    
    #if DEBUG
    return groupURL.appendingPathComponent("staging", isDirectory: true)
    #else
    return groupURL
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
    return SDSessionServiceNameStaging
    #else
    return SDSessionServiceNameProduction
    #endif
}

func sshCredentialDomain() -> String {
    #if DEBUG
    return SDSSHServiceNameStaging
    #else
    return SDSSHServiceNameProduction
    #endif
}

func accountCredentialDomain() -> String {
    #if DEBUG
    return SDServiceNameStaging
    #else
    return SDServiceNameProduction
    #endif
}

func recoveryKeyDomain() -> String {
    #if DEBUG
    return SDServiceNameStaging
    #else
    return SDServiceNameProduction
    #endif
}
