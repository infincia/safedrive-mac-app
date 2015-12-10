
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;
@import XCTest;

#import "SDConstants.h"
#import "SDTestConstants.h"

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"

#import "NSURL+SFTP.h"


@interface SafeDriveTests : XCTestCase

@end

@implementation SafeDriveTests

+ (void)setUp {
    NSError *keychainInsertError = [[SDSystemAPI sharedAPI] insertCredentialsInKeychainForService:SDServiceName account:SDTestCredentialsUser password:SDTestCredentialsPassword];
    if (keychainInsertError) {
        NSLog(@"+setUp failed: %@", keychainInsertError.localizedDescription);
    }
    else {
        NSLog(@"+setUp succeeded");
    }
}



- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)test_SDSystemAPI_machineID {
    XCTAssertNotNil([SDSystemAPI sharedAPI]);
    NSString *identifier = [[SDSystemAPI sharedAPI] machineID];
    XCTAssertNotNil(identifier);
    NSLog(@"ID: %@", identifier);
}

-(void)test_SDSystemAPI_en0MAC {
    XCTAssertNotNil([SDSystemAPI sharedAPI]);
    NSString *mac = [[SDSystemAPI sharedAPI] en0MAC];
    XCTAssertNotNil(mac);
    NSLog(@"MAC en0: %@", mac);
}

-(void)test_SDAPI_registerMachine {
    XCTAssertNotNil([SDAPI sharedAPI]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDAPI_registerMachine"];
    
    [[SDAPI sharedAPI] registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [expectation fulfill];
    } failure:^(NSError *apiError) {
        XCTFail(@"%@", apiError.localizedDescription);
    }];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"test_SDAPI_registerMachine error: %@", error.localizedDescription);    
        }
    }];
}

-(void)test_SDAPI_accountStatusForUser {
    XCTAssertNotNil([SDAPI sharedAPI]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDAPI_accountStatusForUser"];
    [[SDAPI sharedAPI] registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [[SDAPI sharedAPI] accountStatusForUser:SDTestCredentialsUser success:^(NSDictionary *accountStatus) {
            XCTAssertNotNil(accountStatus);
            XCTAssertNotNil(accountStatus[@"host"]);
            XCTAssertNotNil(accountStatus[@"port"]);
            XCTAssertNotNil(accountStatus[@"status"]);
            XCTAssertNotNil(accountStatus[@"userName"]);
            NSLog(@"Account status: %@", accountStatus);
            [expectation fulfill];
        } failure:^(NSError *apiError) {
            XCTFail(@"%@", apiError.localizedDescription);
        }];
    } failure:^(NSError *apiError) {
        XCTFail(@"%@", apiError.localizedDescription);
    }];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"test_SDAPI_accountStatusForUser error: %@", error.localizedDescription);    
        }
    }];
}

-(void)test_SDAPI_accountDetailsForUser {
    XCTAssertNotNil([SDAPI sharedAPI]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDAPI_accountDetailsForUser"];
    [[SDAPI sharedAPI] registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [[SDAPI sharedAPI] accountDetailsForUser:SDTestCredentialsUser success:^(NSDictionary *accountDetails) {
            XCTAssertNotNil(accountDetails);

            NSLog(@"Account details: %@", accountDetails);
            [expectation fulfill];
        } failure:^(NSError *apiError) {
            XCTFail(@"%@", apiError.localizedDescription);
        }];
    } failure:^(NSError *apiError) {
        XCTFail(@"%@", apiError.localizedDescription);
    }];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"test_SDAPI_accountDetailsForUser error: %@", error.localizedDescription);    
        }
    }];
}


- (void)test_SDMountController_startMountTaskWithVolumeName {
    XCTAssertNotNil([SDMountController sharedAPI]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDMountController_startMountTaskWithVolumeName"];

    [[SDAPI sharedAPI] registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [[SDAPI sharedAPI] accountStatusForUser:SDTestCredentialsUser success:^(NSDictionary *accountStatus) {
            XCTAssertNotNil(accountStatus);
            XCTAssertNotNil(accountStatus[@"host"]);
            XCTAssertNotNil(accountStatus[@"port"]);
            XCTAssertNotNil(accountStatus[@"status"]);
            XCTAssertNotNil(accountStatus[@"userName"]);
            
            NSLog(@"Account status: %@", accountStatus);
            
            NSURL *url = [NSURL SFTPURLForAccount:accountStatus[@"userName"] host:accountStatus[@"host"] port:accountStatus[@"port"] path:SDDefaultServerPath];

            [[SDMountController sharedAPI] startMountTaskWithVolumeName:@"SafeDrive" sshURL:url success:^(NSURL *mountURL, NSError *mountError) {
                /*  
                 now check for a successful mount. if after 30 seconds there is no volume
                 mounted, it is a fair bet that an error occurred in the meantime
                 
                 */
                XCTAssertNotNil(mountURL);
                
                [[SDSystemAPI sharedAPI] checkForMountedVolume:mountURL withTimeout:30 success:^{
                    NSDictionary *mountDetails = [[SDSystemAPI sharedAPI] detailsForMount:mountURL];
                    XCTAssertNotNil(mountDetails);
                    XCTAssertTrue(mountDetails[NSFileSystemSize]);
                    XCTAssertTrue(mountDetails[NSFileSystemFreeSize]);
                    [[SDMountController sharedAPI] unmountVolumeWithName:@"SafeDrive" success:^(NSURL *mountURL, NSError *mountError) {
                        [expectation fulfill];
                    } failure:^(NSURL *mountURL, NSError *mountError) {
                        XCTFail(@"%@", mountError.localizedDescription);
                    }];
                    
                } failure:^(NSError *error) {
                    XCTFail(@"%@", error.localizedDescription);
                }];
            } failure:^(NSURL *mountURL, NSError *mountError) {
                XCTFail(@"%@", mountError.localizedDescription);
            }];
        } failure:^(NSError *apiError) {
            XCTFail(@"%@", apiError.localizedDescription);
        }];
    } failure:^(NSError *apiError) {
        XCTFail(@"%@", apiError.localizedDescription);
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"test_SDAPI_registerMachine error: %@", error.localizedDescription);    
        }
    }];
}

- (void)test_SDSystemAPI_statusForMountpoint {
    XCTAssertNotNil([SDSystemAPI sharedAPI]);
    // test root since it should always work as a URL
    NSDictionary *mountDetails = [[SDSystemAPI sharedAPI] detailsForMount:[NSURL fileURLWithFileSystemRepresentation:"/\0" isDirectory:YES relativeToURL:nil]];
    XCTAssertNotNil(mountDetails);
    XCTAssertTrue(mountDetails[NSFileSystemSize]);
    XCTAssertTrue(mountDetails[NSFileSystemFreeSize]);
    NSLog(@"test_SDSystemAPI_statusForMountpoint: %@", mountDetails);
}

- (void)test_SDSystemAPI_insertCredentialsInKeychainForService {
    XCTAssertNotNil([SDSystemAPI sharedAPI]);
    NSError *keychainInsertError = [[SDSystemAPI sharedAPI] insertCredentialsInKeychainForService:SDServiceNameTesting account:SDTestCredentialsUser password:SDTestCredentialsPassword];
    if (keychainInsertError) {
        XCTFail(@"%@", keychainInsertError.localizedDescription);
        NSLog(@"test_SDSystemAPI_insertCredentialsInKeychainForService: %@", keychainInsertError.localizedDescription);
    }
    NSError *keychainRemoveError = [[SDSystemAPI sharedAPI] removeCredentialsInKeychainForService:SDServiceNameTesting account:SDTestCredentialsUser];
    if (keychainRemoveError) {
        XCTFail(@"%@", keychainRemoveError.localizedDescription);
        NSLog(@"test_SDSystemAPI_insertCredentialsInKeychainForService: %@", keychainRemoveError.localizedDescription);
    }
}


@end
