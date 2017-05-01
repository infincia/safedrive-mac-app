//
//  Util.swift
//  SafeDrive
//
//  Created by steve on 1/17/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//
// swiftlint:disable sorted_imports

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

// General constants

fileprivate let SDDefaultVolumeName = "SafeDrive"
fileprivate let SDDefaultServerPath = "/storage"
fileprivate let SDDefaultServerPort = 22

// Realm constants

fileprivate let SDCurrentRealmSchema = 15

// UserDefaults keys

fileprivate let SDBuildVersionLastKey = "SDBuildVersionLastKey"
fileprivate let SDRealmSchemaVersionLastKey = "SDRealmSchemaVersionLastKey"

fileprivate let SDCurrentVolumeNameKey = "currentVolumeName"
fileprivate let SDMountAtLaunchKey = "mountAtLaunch"
fileprivate let SDWelcomeShownKey = "welcomeShown"



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

func defaultVolumeName() -> String {
    return SDDefaultVolumeName
}

func defaultServerPath() -> String {
    return SDDefaultServerPath
}

func defaultServerPort() -> Int {
    return SDDefaultServerPort
}

func userDefaultsBuildVersionLastKey() -> String {
    return SDBuildVersionLastKey
}

func userDefaultsCurrentVolumeNameKey() -> String {
    return SDCurrentVolumeNameKey
}

func userDefaultsMountAtLaunchKey() -> String {
    return SDMountAtLaunchKey
}

func userDefaultsWelcomeShownKey() -> String {
    return SDWelcomeShownKey
}


func userDefaultsRealmSchemaVersionLastKey() -> String {
    return SDRealmSchemaVersionLastKey
}

func currentRealmSchemaVersion() -> Int {
    return SDCurrentRealmSchema
}

