//
//  Constants.swift
//  SafeDriveSDK
//
//  Created by steve on 3/21/17.
//  Copyright © 2017 SafeDrive. All rights reserved.
//
// swiftlint:disable private_over_fileprivate

import Foundation

public let SDKErrorDomainNotReported = "io.safedrive.notreported"
public let SDKErrorDomainReported = "io.safedrive.reported"
public let SDKErrorDomainInternal = "io.safedrive.internal"

public let SDErrorDomainNotReported = "io.safedrive.notreported"
public let SDErrorDomainReported = "io.safedrive.reported"
public let SDErrorDomainInternal = "io.safedrive.internal"

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

fileprivate let SDUseServiceKey = "useService"
fileprivate let SDUseSFTPFSKey = "useSFTPFS"
fileprivate let SDUseCacheKey = "useCache"
fileprivate let SDKeepMountedKey = "keepMounted"
fileprivate let SDKeepInFinderSidebarKey = "keepInFinderSidebar"
fileprivate let SDCurrentVolumeNameKey = "currentVolumeName"
fileprivate let SDMountAtLaunchKey = "mountAtLaunch"
fileprivate let SDWelcomeShownKey = "welcomeShown"


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

func useServiceKey() -> String {
    return SDUseServiceKey
}

func useSFTPFSKey() -> String {
    return SDUseSFTPFSKey
}

func useCacheKey() -> String {
    return SDUseCacheKey
}

func keepMountedKey() -> String {
    return SDKeepMountedKey
}

func keepInFinderSidebarKey() -> String {
    return SDKeepInFinderSidebarKey
}

func userDefaultsMountAtLaunchKey() -> String {
    return SDMountAtLaunchKey
}

func userDefaultsWelcomeShownKey() -> String {
    return SDWelcomeShownKey
}


public enum SDKLogLevel: UInt8 {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3
    case trace = 4
}

public enum SFTPFSErrorType: Int32 {
    case NoError = 0
    case InternalError = 1
    case UnknownError = 2
    case AlreadyConnected = 3
    case NotConnected = 4
    case DiskFull = 5
    case PermissionDenied = 6
    case AccessForbidden = 7
    case ConnectionLost = 8
    case ConnectionFailed = 9
    case ConnectionCancelled = 10
    case FileNotFound = 11
    case MountFailed = 12
    case UnmountFailed = 13
}

public enum SDNotificationType: String {
    case signInFailed = "sign-in-failed"
    case driveMounting = "drive-mounting"
    case driveUnmounting = "drive-unmounting"
    case driveMountFailed = "drive-mount-failed"
    case driveUnmountFailed = "drive-unmount-failed"
    case recoveryPhrase = "recovery-phrase"
    case openPreferences = "open-preferences"
    case driveMounted = "drive-mounted"
    case driveUnmounted = "drive-unmounted"
    case driveFull = "drive-full"
}


// MARK: RemoteFS operations

public enum SDKRemoteFSOperation {
    case createFolder
    case deleteFolder
    case deletePath(recursive: Bool)
    case moveFolder
}
