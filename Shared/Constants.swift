//
//  Constants.swift
//  SafeDriveSDK
//
//  Created by steve on 3/21/17.
//  Copyright © 2017 SafeDrive. All rights reserved.
//

import Foundation

public let SDKErrorDomainNotReported = "io.safedrive.notreported"
public let SDKErrorDomainReported = "io.safedrive.reported"
public let SDKErrorDomainInternal = "io.safedrive.internal"

public enum SDKLogLevel: UInt8 {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3
    case trace = 4
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
}


// MARK: RemoteFS operations

public enum SDKRemoteFSOperation {
    case createFolder
    case deleteFolder
    case deletePath(recursive: Bool)
    case moveFolder
}
