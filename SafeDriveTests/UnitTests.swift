
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation
import XCTest

@testable import SafeDrive

class UnitTests: XCTestCase {
    
    func test_SyncFolder_hasConflictingFolderRegistered_otherUser() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertFalse(SyncFolder.hasConflictingFolderRegistered("/Users/otheruser", syncFolders: [homeSyncFolder]));
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_subDirectory() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertTrue(SyncFolder.hasConflictingFolderRegistered("/Users/user/Documents", syncFolders: [homeSyncFolder]));
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_trailingSlash() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertTrue(SyncFolder.hasConflictingFolderRegistered("/Users/user/Documents/", syncFolders: [homeSyncFolder]));
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_parentDirectory() {
        let homeSyncFolder = SyncFolder(name: "Home", path: "/Users/user", uniqueID: -1)
        XCTAssertTrue(SyncFolder.hasConflictingFolderRegistered("/", syncFolders: [homeSyncFolder]));
    }
    
    func test_SyncFolder_hasConflictingFolderRegistered_substring() {
        let testFolder = SyncFolder(name: "Home", path: "/Users/user/test", uniqueID: -1)
        XCTAssertFalse(SyncFolder.hasConflictingFolderRegistered("/Users/user/test2", syncFolders: [testFolder]));
    }
    
    func test_SDSystemAPI_en0MAC() {
        let mac = SDSystemAPI.sharedAPI().en0MAC()
        XCTAssertNotNil(mac);
        NSLog("MAC en0: \(mac)")
    }

}