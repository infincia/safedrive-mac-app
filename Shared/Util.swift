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

// UserDefaults keys

fileprivate let SDBuildVersionLastKey = "SDBuildVersionLastKey"

fileprivate let SDUseSFTPFSKey = "useSFTPFS"
fileprivate let SDKeepMountedKey = "keepMounted"
fileprivate let SDCurrentVolumeNameKey = "currentVolumeName"
fileprivate let SDMountAtLaunchKey = "mountAtLaunch"
fileprivate let SDWelcomeShownKey = "welcomeShown"


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

func useSFTPFSKey() -> String {
    return SDUseSFTPFSKey
}

func keepMountedKey() -> String {
    return SDKeepMountedKey
}

func userDefaultsMountAtLaunchKey() -> String {
    return SDMountAtLaunchKey
}

func userDefaultsWelcomeShownKey() -> String {
    return SDWelcomeShownKey
}

// SSH related errors

public struct SDError {
    public var message: String
    public var kind: SDErrorType
    
    public var code: Int {
        return self.kind.rawValue
    }
    
    public init(message: String, kind: SDErrorType) {
        self.message = message
        self.kind = kind
    }
}

extension SDError: LocalizedError {
    public var errorDescription: String? {
        return self.message
    }
}

public let SDErrorDomainNotReported = "io.safedrive.notreported"
public let SDErrorDomainReported = "io.safedrive.reported"
public let SDErrorDomainInternal = "io.safedrive.internal"

extension SDError:  CustomNSError {
    var errorDomain: String {
        switch self.kind {
        case .unknown:
            return SDErrorDomainReported
        case .apiContractInvalid:
            return SDErrorDomainInternal
        case .authorization:
            return SDErrorDomainNotReported
        case .hostFingerprintChanged:
            return SDErrorDomainReported
        case .hostKeyVerificationFailed:
            return SDErrorDomainReported
        case .directoryMissing:
            return SDErrorDomainReported
        case .remoteEnvironment:
            return SDErrorDomainReported
        case .sftpOperationFailure:
            return SDErrorDomainReported
        case .sftpOperationFolderConflict:
            return SDErrorDomainNotReported
        case .addLoginItemFailed:
            return SDErrorDomainReported
        case .removeLoginItemFailed:
            return SDErrorDomainReported
        case .addKeychainItemFailed:
            return SDErrorDomainReported
        case .removeKeychainItemFailed:
            return SDErrorDomainReported
        case .filePermissionDenied:
            return SDErrorDomainNotReported
        case .fuseMissing:
            return SDErrorDomainInternal
        case .sshfsMissing:
            return SDErrorDomainInternal
        case .askpassMissing:
            return SDErrorDomainInternal
        case .rsyncMissing:
            return SDErrorDomainInternal
        case .cliMissing:
            return SDErrorDomainInternal
        case .sshMissing:
            return SDErrorDomainInternal
        case .configMissing:
            return SDErrorDomainInternal
        case .temporaryFile:
            return SDErrorDomainNotReported
         case .timeout:
            return SDErrorDomainNotReported
         case .syncFailed:
            return SDErrorDomainNotReported
         case .alreadyRunning:
            return SDErrorDomainNotReported
         case .folderConflict:
            return SDErrorDomainNotReported
         case .cancelled:
            return SDErrorDomainNotReported
         case .mountFailed:
            return SDErrorDomainNotReported
         case .unmountFailed:
            return SDErrorDomainNotReported
         case .alreadyMounted:
            return SDErrorDomainNotReported
         case .openFailed:
            return SDErrorDomainNotReported
         case .migrationFailed:
            return SDErrorDomainReported
         case .writeFailed:
            return SDErrorDomainReported
         case .serviceDeployment:
            return SDErrorDomainReported
         case .cliDeployment:
            return SDErrorDomainReported
         case .fuseDeployment:
            return SDErrorDomainReported
         case .setupDirectories:
            return SDErrorDomainReported
        }
    }
    
    public var errorCode: Int {
        return self.kind.rawValue
    }
}


public enum SDErrorType: Int {
    case unknown = -1000
    case authorization = 1001
    case apiContractInvalid = 1002
    case hostFingerprintChanged = 1003
    case hostKeyVerificationFailed = 1004
    case directoryMissing = 1005
    case remoteEnvironment = 1016
    case sftpOperationFailure = 1017
    case sftpOperationFolderConflict = 1018
    case addLoginItemFailed = 2001
    case removeLoginItemFailed = 2002
    case addKeychainItemFailed = 2003
    case removeKeychainItemFailed = 2004
    case filePermissionDenied = 2005
    case fuseMissing = 2006
    case sshfsMissing = 2007
    case askpassMissing = 2008
    case rsyncMissing = 2009
    case temporaryFile = 2010
    case sshMissing = 2011
    case configMissing = 2012
    case timeout = 4001
    case syncFailed = 4003
    case alreadyRunning = 4004
    case folderConflict = 4006
    case cancelled = 4007
    case mountFailed = 5001
    case unmountFailed = 5002
    case alreadyMounted = 5003
    case openFailed = 6001
    case migrationFailed = 6002
    case writeFailed = 6003
    case serviceDeployment = 7001
    case cliDeployment = 7002
    case fuseDeployment = 7003
    case cliMissing = 7004
    case setupDirectories = 7005
}
