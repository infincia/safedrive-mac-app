
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Cocoa;
@import XCTest;

#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"
#import "SDTestCredentials.h"


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

- (void)test_SDMountController_startMountTaskWithVolumeName {
    XCTAssertNotNil(self.sharedMountController);

    // As this is only used for testing, we can use NSURLComponents which isn't available in OS X 10.8
    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.user = SDTestCredentialsUser;
    urlComponents.password = SDTestCredentialsPassword;
    urlComponents.host = SDTestCredentialsHost;
    urlComponents.path = SDTestCredentialsPath;
    urlComponents.port = @(SDTestCredentialsPort);

    NSURL *url = urlComponents.URL;

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
            XCTAssertTrue(mountDetails[NSURLVolumeTotalCapacityKey]);
            XCTAssertTrue(mountDetails[NSURLVolumeAvailableCapacityKey]);
        } failure:^(NSError *error) {
            XCTFail(@"%@", error.localizedDescription);
        }];
    } failure:^(NSURL *mountURL, NSError *mountError) {
        XCTFail(@"%@", mountError.localizedDescription);
    }];
}

- (void)test_SDSystemAPI_statusForMountpoint {
    XCTAssertNotNil(self.sharedSystemAPI);
    // test root since it should always work as a URL
    NSDictionary *mountDetails = [self.sharedSystemAPI detailsForMount:[NSURL fileURLWithFileSystemRepresentation:"/\0" isDirectory:YES relativeToURL:nil]];
    XCTAssertNotNil(mountDetails);
    XCTAssertTrue(mountDetails[NSURLVolumeTotalCapacityKey]);
    XCTAssertTrue(mountDetails[NSURLVolumeAvailableCapacityKey]);
    NSLog(@"test_SDSystemAPI_statusForMountpoint: %@", mountDetails);
}

- (void)test_SDSystemAPI_insertCredentialsInKeychain {
    XCTAssertNotNil(self.sharedSystemAPI);
    NSError *keychainError = [self.sharedSystemAPI insertCredentialsInKeychain:SDTestCredentialsUser password:SDTestCredentialsPassword];
    if (keychainError) {
        NSLog(@"test_SDSystemAPI_insertCredentialsInKeychain: %@", keychainError.localizedDescription);
    }
}


/*
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
*/


@end
