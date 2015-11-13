
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;
@import XCTest;

#import "SDConstants.h"
#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"
#import "SDTestCredentials.h"

#import "NSURL+SFTP.h"


@interface SafeDriveTests : XCTestCase
@property SDMountController *sharedMountController;
@property SDAPI *sharedSafedriveAPI;
@property SDSystemAPI *sharedSystemAPI;
@end

@implementation SafeDriveTests

- (void)setUp {
    [super setUp];
    self.sharedMountController = [SDMountController sharedAPI];
    self.sharedSafedriveAPI = [SDAPI sharedAPI];
    self.sharedSystemAPI = [SDSystemAPI sharedAPI];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)test_SDSystemAPI_machineID {
    XCTAssertNotNil(self.sharedSystemAPI);
    NSString *identifier = [self.sharedSystemAPI machineID];
    XCTAssertNotNil(identifier);
    NSLog(@"ID: %@", identifier);
}

-(void)test_SDSystemAPI_en0MAC {
    XCTAssertNotNil(self.sharedSystemAPI);
    NSString *mac = [self.sharedSystemAPI en0MAC];
    XCTAssertNotNil(mac);
    NSLog(@"MAC en0: %@", mac);
}

-(void)test_SDAPI_registerMachine {
    XCTAssertNotNil(self.sharedSafedriveAPI);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDAPI_registerMachine"];
    
    [self.sharedSafedriveAPI registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
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
    XCTAssertNotNil(self.sharedSafedriveAPI);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDAPI_accountStatusForUser"];
    [self.sharedSafedriveAPI registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [self.sharedSafedriveAPI accountStatusForUser:SDTestCredentialsUser success:^(NSDictionary *accountStatus) {
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
    XCTAssertNotNil(self.sharedSafedriveAPI);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDAPI_accountDetailsForUser"];
    [self.sharedSafedriveAPI registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [self.sharedSafedriveAPI accountDetailsForUser:SDTestCredentialsUser success:^(NSDictionary *accountDetails) {
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
    XCTAssertNotNil(self.sharedMountController);
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_SDMountController_startMountTaskWithVolumeName"];

    [self.sharedSafedriveAPI registerMachineWithUser:SDTestCredentialsUser password:SDTestCredentialsPassword success:^(NSString *sessionToken) {
        XCTAssertNotNil(sessionToken);
        [self.sharedSafedriveAPI accountStatusForUser:SDTestCredentialsUser success:^(NSDictionary *accountStatus) {
            XCTAssertNotNil(accountStatus);
            XCTAssertNotNil(accountStatus[@"host"]);
            XCTAssertNotNil(accountStatus[@"port"]);
            XCTAssertNotNil(accountStatus[@"status"]);
            XCTAssertNotNil(accountStatus[@"userName"]);
            
            NSLog(@"Account status: %@", accountStatus);
            
            NSURL *url = [NSURL SFTPURLForAccount:accountStatus[@"userName"] host:accountStatus[@"host"] port:accountStatus[@"port"] path:SDDefaultServerPath];

            [self.sharedMountController startMountTaskWithVolumeName:@"SafeDrive" sshURL:url success:^(NSURL *mountURL, NSError *mountError) {
                /*  
                 now check for a successful mount. if after 30 seconds there is no volume
                 mounted, it is a fair bet that an error occurred in the meantime
                 
                 */
                XCTAssertNotNil(mountURL);
                XCTAssertNotNil(mountError);
                
                [self.sharedSystemAPI checkForMountedVolume:mountURL withTimeout:30 success:^{
                    NSDictionary *mountDetails = [self.sharedSystemAPI detailsForMount:mountURL];
                    XCTAssertNotNil(mountDetails);
                    XCTAssertTrue(mountDetails[NSFileSystemSize]);
                    XCTAssertTrue(mountDetails[NSFileSystemFreeSize]);
                    [expectation fulfill];
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
    XCTAssertNotNil(self.sharedSystemAPI);
    // test root since it should always work as a URL
    NSDictionary *mountDetails = [self.sharedSystemAPI detailsForMount:[NSURL fileURLWithFileSystemRepresentation:"/\0" isDirectory:YES relativeToURL:nil]];
    XCTAssertNotNil(mountDetails);
    XCTAssertTrue(mountDetails[NSFileSystemSize]);
    XCTAssertTrue(mountDetails[NSFileSystemFreeSize]);
    NSLog(@"test_SDSystemAPI_statusForMountpoint: %@", mountDetails);
}

- (void)test_SDSystemAPI_insertCredentialsInKeychainForService {
    XCTAssertNotNil(self.sharedSystemAPI);
    NSError *keychainInsertError = [self.sharedSystemAPI insertCredentialsInKeychainForService:SDServiceName account:SDTestCredentialsUser password:SDTestCredentialsPassword];
    if (keychainInsertError) {
        XCTFail(@"%@", keychainInsertError.localizedDescription);
        NSLog(@"test_SDSystemAPI_insertCredentialsInKeychainForService: %@", keychainInsertError.localizedDescription);
    }
    NSError *keychainRemoveError = [self.sharedSystemAPI removeCredentialsInKeychainForService:SDServiceName account:SDTestCredentialsUser];
    if (keychainRemoveError) {
        XCTFail(@"%@", keychainRemoveError.localizedDescription);
        NSLog(@"test_SDSystemAPI_insertCredentialsInKeychainForService: %@", keychainRemoveError.localizedDescription);
    }
}


@end
