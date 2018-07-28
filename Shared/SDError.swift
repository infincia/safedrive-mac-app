//
//  Util.swift
//  SafeDrive
//
//  Created by steve on 1/17/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//


import Foundation

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
    
    public init(message: String, kind: SDKErrorType) {
        self.message = message
        switch kind {
        case .StateMissing:
            self.kind = .internalFailure
        case .Internal:
            self.kind = .internalFailure
        case .RequestFailure:
            self.kind = .apiContractInvalid
        case .NetworkFailure:
            self.kind = .networkUnavailable
        case .Conflict:
            self.kind = .folderConflict
        case .BlockMissing:
            self.kind = .internalFailure
        case .SessionMissing:
            self.kind = .internalFailure
        case .RecoveryPhraseIncorrect:
            self.kind = .recoveryPhraseIncorrect
        case .InsufficientFreeSpace:
            self.kind = .freeSpace
        case .Authentication:
            self.kind = .authorization
        case .UnicodeError:
            self.kind = .internalFailure
        case .TokenExpired:
            self.kind = .authorization
        case .CryptoError:
            self.kind = .internalFailure
        case .IO:
            self.kind = .internalFailure
        case .SyncAlreadyInProgress:
            self.kind = .alreadyRunning
        case .RestoreAlreadyInProgress:
            self.kind = .alreadyRunning
        case .ExceededRetries:
            self.kind = .timeout
        case .KeychainError:
            self.kind = .addKeychainItemFailed
        case .BlockUnreadable:
            self.kind = .internalFailure
        case .SessionUnreadable:
            self.kind = .internalFailure
        case .ServiceUnavailable:
            self.kind = .internalFailure
        case .Cancelled:
            self.kind = .cancelled
        case .FolderMissing:
            self.kind = .directoryMissing
        case .KeyCorrupted:
            self.kind = .keyCorrupted
        }
    }
    
    public static func == (left: SDError, right: SDError) -> Bool {
        return (left.kind == right.kind)
    }
    
    public static func != (left: SDError, right: SDError) -> Bool {
        return (left.kind != right.kind)
    }
}

extension SDError: LocalizedError {
    public var errorDescription: String? {
        return self.message
    }
}

extension SDError: CustomNSError {
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
        case .kextLoading:
            return SDErrorDomainNotReported
        case .networkUnavailable:
            return SDErrorDomainNotReported
        case .internalFailure:
            return SDErrorDomainReported
        case .freeSpace:
            return SDErrorDomainNotReported
        case .recoveryPhraseIncorrect:
            return SDErrorDomainNotReported
        case .keyCorrupted:
            return SDErrorDomainReported
        case .cryptoError:
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
    case kextLoading = 7006
    case networkUnavailable = 8000
    case internalFailure = 9000
    case freeSpace = 10000
    case recoveryPhraseIncorrect = 11000
    case keyCorrupted = 12000
    case cryptoError = 12001
}

