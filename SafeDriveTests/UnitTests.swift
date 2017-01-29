
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation
import XCTest

@testable import SafeDrive

class UnitTests: XCTestCase {
    
    func test_SyncFolder_hasConflictingFolderRegistered_otherUser() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertFalse(SyncFolder.hasConflictingFolderRegistered("/Users/otheruser", syncFolders: [homeSyncFolder]))
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_subDirectory() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertTrue(SyncFolder.hasConflictingFolderRegistered("/Users/user/Documents", syncFolders: [homeSyncFolder]))
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_trailingSlash() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertTrue(SyncFolder.hasConflictingFolderRegistered("/Users/user/Documents/", syncFolders: [homeSyncFolder]))
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_parentDirectory() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertTrue(SyncFolder.hasConflictingFolderRegistered("/", syncFolders: [homeSyncFolder]))
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_substring() {
        let testFolder = SyncFolder(name: "Home", path: "/Users/user/test", uniqueID: -1)
        XCTAssertFalse(SyncFolder.hasConflictingFolderRegistered("/Users/user/test2", syncFolders: [testFolder]))
    }
    
    func test_SDSystemAPI_en0MAC() {
        let mac = SDSystemAPI.shared().en0MAC()
        XCTAssertNotNil(mac)
        NSLog("MAC en0: \(mac)")
    }

    func test_uniqueClientId() {
            let macAddress: String = SDSystemAPI.shared().en0MAC()!
            let machineIdConcatenation: String = macAddress + "stephen@safedrive.io"
            let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.data(using: String.Encoding.utf8))
            print("ID: \(identifier)")
            XCTAssert(identifier == "c19689af4055450b732a1e96400c6aa48d319e55239d66c84b2bdfcc48364faa")

    }
}
